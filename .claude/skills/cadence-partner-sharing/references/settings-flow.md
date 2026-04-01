# Sharing Settings Change Flow — Swift Reference

Triggered by: Tracker toggles a share category on or off.

- **When disabling:** Null out that field retroactively on all existing `shared_logs` rows.
- **When enabling:** Backfill from `cycle_logs` into `shared_logs` for the past 30 days.

---

## SharingService

```swift
// MARK: - SharingService.swift

actor SharingService {
    private let supabase: SupabaseClient
    private let encryption: EncryptionService
    static let backfillDays: Int = 30

    func updateSharingSetting(
        category: ShareCategory,
        enabled: Bool,
        trackerUserId: UUID,
        partnerUserId: UUID
    ) async throws {
        // Step 1 — Update sharing_settings row
        let columnName = category.columnName // e.g. "share_period"
        try await supabase
            .from("sharing_settings")
            .update([columnName: enabled])
            .eq("user_id", trackerUserId.uuidString)
            .execute()

        if enabled {
            // Step 2a — Backfill: pull cycle_logs data for past 30 days and write into shared_logs
            try await backfill(category: category, trackerUserId: trackerUserId, partnerUserId: partnerUserId)
        } else {
            // Step 2b — Retroactively null out this field on all shared_logs rows
            try await clearField(category: category, trackerUserId: trackerUserId, partnerUserId: partnerUserId)
        }
    }

    // MARK: Disable — null out field retroactively

    private func clearField(
        category: ShareCategory,
        trackerUserId: UUID,
        partnerUserId: UUID
    ) async throws {
        try await supabase
            .from("shared_logs")
            .update([category.sharedLogsField: AnyJSON.null])
            .eq("tracker_user_id", trackerUserId.uuidString)
            .eq("partner_user_id", partnerUserId.uuidString)
            .execute()
    }

    // MARK: Enable — backfill from cycle_logs

    private func backfill(
        category: ShareCategory,
        trackerUserId: UUID,
        partnerUserId: UUID
    ) async throws {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -Self.backfillDays, to: Date()
        )!
        let cutoffString = ISO8601DateFormatter.shared.string(from: cutoff)

        // Fetch recent cycle_logs (tracker's own session — this is safe)
        let logsResponse = try await supabase
            .from("cycle_logs")
            .select("log_date, \(category.cycleLogsField)")
            .eq("user_id", trackerUserId.uuidString)
            .gte("log_date", cutoffString)
            .execute()
        let logs = try logsResponse.value as [CycleLogPartial]

        guard !logs.isEmpty else { return }

        // For each day, update the single field on shared_logs if a row already exists.
        // We do NOT create shared_logs rows here — a row must already exist from log save.
        for log in logs {
            guard let rawValue = log.fieldValue(for: category) else { continue }
            let encrypted = try encryption.encryptField(rawValue, userId: trackerUserId)

            try await supabase
                .from("shared_logs")
                .update([category.sharedLogsField: encrypted])
                .eq("tracker_user_id", trackerUserId.uuidString)
                .eq("partner_user_id", partnerUserId.uuidString)
                .eq("log_date", log.logDate)
                .execute()
        }
    }
}
```

---

## Edge Cases

- Backfill only updates existing `shared_logs` rows — it does not insert new ones.
  If a day has no `shared_logs` row (tracker never saved a log for that day), that
  day is silently skipped.
- If the partner connection changes, all backfill/clear operations must use the
  correct `partner_user_id` for the active connection.
- Both-tracker scenario: each user has their own `sharing_settings` row. Toggling
  settings on User A has no effect on User B's settings.
