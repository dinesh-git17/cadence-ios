# SharedLog Write Flow — Swift Reference

Triggered by: Tracker saves or edits a cycle log entry.

---

## LogService

```swift
// MARK: - LogService.swift

actor LogService {
    private let supabase: SupabaseClient
    private let encryption: EncryptionService
    private let cycleEngine: CycleEngine

    init(supabase: SupabaseClient, encryption: EncryptionService, cycleEngine: CycleEngine) {
        self.supabase = supabase
        self.encryption = encryption
        self.cycleEngine = cycleEngine
    }

    func saveLog(_ input: CycleLogInput, for userId: UUID) async throws {
        // Step 1 — Write full encrypted log to cycle_logs
        let encryptedRow = try encryption.encryptLog(input, userId: userId)
        try await supabase
            .from("cycle_logs")
            .upsert(encryptedRow, onConflict: "user_id,log_date")
            .execute()

        // Step 2 — Fetch current sharing settings
        let settingsResponse = try await supabase
            .from("sharing_settings")
            .select()
            .eq("user_id", userId.uuidString)
            .single()
            .execute()
        let settings = try settingsResponse.value as SharingSettings

        // Step 3 — Check if there is an active partner connection
        guard let connection = try await fetchActiveConnection(for: userId) else {
            return // No partner connected — nothing to write to shared_logs
        }

        // Step 4 — Compute cycle context
        let cycleContext = cycleEngine.context(for: input.logDate, userId: userId)

        // Step 5 — Build shared_logs row (only enabled categories + always-present fields)
        var sharedRow: [String: AnyJSON] = [
            "tracker_user_id":        .string(userId.uuidString),
            "partner_user_id":        .string(connection.partnerUserId.uuidString),
            "log_date":               .string(ISO8601DateFormatter.shared.string(from: input.logDate)),
            "cycle_day":              .number(Double(cycleContext.day)),
            "cycle_phase":            .string(cycleContext.phase.rawValue),
            "predicted_next_period":  cycleContext.predictedNextPeriod.map { .string(ISO8601DateFormatter.shared.string(from: $0)) } ?? .null,
        ]

        if settings.sharePeriod, let flow = input.periodFlow {
            sharedRow["period_flow"] = .string(try encryption.encryptField(flow, userId: userId))
        } else {
            sharedRow["period_flow"] = .null
        }

        if settings.shareSymptoms, let symptoms = input.symptoms, !symptoms.isEmpty {
            let encrypted = try encryption.encryptField(symptoms.joined(separator: ","), userId: userId)
            sharedRow["symptoms"] = .string(encrypted)
        } else {
            sharedRow["symptoms"] = .null
        }

        if settings.shareMood, let mood = input.mood, !mood.isEmpty {
            let encrypted = try encryption.encryptField(mood.joined(separator: ","), userId: userId)
            sharedRow["mood"] = .string(encrypted)
        } else {
            sharedRow["mood"] = .null
        }

        if settings.shareEnergy, let energy = input.energy {
            sharedRow["energy"] = .string(try encryption.encryptField(energy, userId: userId))
        } else {
            sharedRow["energy"] = .null
        }

        // Step 6 — Upsert (one row per tracker_user_id + log_date)
        try await supabase
            .from("shared_logs")
            .upsert(sharedRow, onConflict: "tracker_user_id,log_date")
            .execute()
    }

    private func fetchActiveConnection(for userId: UUID) async throws -> PartnerConnection? {
        let response = try? await supabase
            .from("partner_connections")
            .select()
            .or("tracker_user_id.eq.\(userId),partner_user_id.eq.\(userId)")
            .eq("status", "active")
            .maybeSingle()
            .execute()
        return try? response?.value as PartnerConnection
    }
}
```

---

## Edge Cases

- If no active partner connection exists, skip writing to `shared_logs` entirely
- If a category is enabled but the tracker logged nothing for it today (e.g. no symptoms),
  write `null` — do not omit the field
- Always write `cycle_day`, `cycle_phase`, `predicted_next_period` even when all
  categories are off
