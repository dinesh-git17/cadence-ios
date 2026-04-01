# Disconnect Flow — Swift Reference

Triggered by: Either user taps Disconnect in Profile/Settings.

Execute in this order, stop on first error:
1. Set `partner_connections.status` to `"inactive"`
2. Delete all `shared_logs` rows for this `(tracker_user_id, partner_user_id)` pair
3. Clear local state in `PartnerViewModel`
4. Navigate away from any partner-dependent screen

---

## Implementation

```swift
// MARK: - In PartnerViewModel

func disconnect() async {
    guard case .connected(_, let partnerUserId) = connectionStatus,
          let currentUserId = authService.currentUserId,
          let connectionId = activeConnectionId else { return }

    isLoading = true
    defer { isLoading = false }

    do {
        // Step 1 — Mark connection inactive
        try await supabase
            .from("partner_connections")
            .update(["status": "inactive"])
            .eq("id", connectionId.uuidString)
            .execute()

        // Step 2 — Delete all shared_logs for this connection
        try await supabase
            .from("shared_logs")
            .delete()
            .eq("tracker_user_id", trackerUserId.uuidString)
            .eq("partner_user_id", partnerUserId.uuidString)
            .execute()

        // Step 3 — Clear local state
        connectionStatus = .disconnected
        partnerTodayData = nil
        activeConnectionId = nil

        // Step 4 — Unsubscribe from realtime
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil

        // Navigation: post a notification for the owning view to handle
        NotificationCenter.default.post(name: .partnerDisconnected, object: nil)

    } catch {
        disconnectError = error
    }
}
```

---

## Edge Cases

- Either partner can disconnect. If the disconnecting user is the **partner** (not
  the tracker), they do not have write access to `shared_logs` (RLS). The app must
  identify the tracker's user ID from `partner_connections` to perform the delete —
  this must be done server-side via an Edge Function, or the tracker's row must be
  cleared when the connection row is marked inactive via a Supabase database trigger.
- After disconnect, do not attempt to re-subscribe to `shared_logs` realtime until
  a new connection is established.
- On disconnect, the app must navigate away from the Partner tab if it is currently
  showing partner-specific data to avoid a blank or broken state.
