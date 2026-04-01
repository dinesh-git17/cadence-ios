# Cadence Realtime Subscriptions — Swift Reference

Realtime requires that the `shared_logs` table has **Realtime replication enabled**
in the Supabase dashboard (`Database > Replication > supabase_realtime` publication
must include `shared_logs`). This is not enabled by default on new projects —
enable it before implementing the subscription.

Also required for seeing previous values on UPDATE/DELETE:

```sql
ALTER TABLE shared_logs REPLICA IDENTITY FULL;
```

Run this migration once in your Supabase project before shipping Realtime features.

---

## Subscription Pattern in SwiftUI

The partner-facing view subscribes to inserts and updates on `shared_logs` filtered
to rows where `partner_user_id` matches the current user. Use an `AsyncStream` inside
a `Task` stored on the `ViewModel`. Cancel it in `.onDisappear`.

```swift
import Supabase
import Observation

@Observable
final class PartnerViewModel {
    var sharedLog: SharedLog? = nil
    var isLoading: Bool = false
    var error: CadenceSupabaseError? = nil

    private var realtimeTask: Task<Void, Never>? = nil
    private var channel: RealtimeChannelV2? = nil

    // Call from .onAppear after confirming a partner connection exists.
    func startListening(partnerUserID: UUID) {
        realtimeTask?.cancel()

        realtimeTask = Task { [weak self] in
            let channel = supabase.channel("shared_logs:\(partnerUserID.uuidString)")
            self?.channel = channel

            // Subscribe to INSERT and UPDATE on shared_logs for this partner
            let changeStream = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "shared_logs",
                filter: "partner_user_id=eq.\(partnerUserID.uuidString)"
            )

            await channel.subscribe()

            for await change in changeStream {
                guard !Task.isCancelled else { break }
                switch change {
                case .insert(let action), .update(let action):
                    if let record = try? action.decodeRecord(as: SharedLog.self) {
                        await MainActor.run {
                            self?.sharedLog = record
                        }
                    }
                case .delete:
                    // shared_logs deletion means disconnection — clear the state
                    await MainActor.run {
                        self?.sharedLog = nil
                    }
                default:
                    break
                }
            }
        }
    }

    // Call from .onDisappear — do not leak channels.
    func stopListening() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel {
            Task { await supabase.removeChannel(channel) }
        }
        channel = nil
    }
}
```

**In the SwiftUI view:**

```swift
.onAppear {
    guard let partnerID = connectionState.partnerUserID else { return }
    viewModel.startListening(partnerUserID: partnerID)
}
.onDisappear {
    viewModel.stopListening()
}
```

---

## Subscription Cleanup Rules

- Always call `stopListening()` in `.onDisappear`.
- Always cancel the `Task` before starting a new subscription (guard against double-subscribe).
- Use `await supabase.removeAllChannels()` only during sign-out cleanup. Not in views.
- Channel names should be namespaced with a user ID to avoid collisions if multiple views
  subscribe to different filtered slices of the same table.
