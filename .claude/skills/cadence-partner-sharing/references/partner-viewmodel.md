# PartnerViewModel — Swift Reference

---

## Full Implementation

```swift
// MARK: - PartnerViewModel.swift

@MainActor
final class PartnerViewModel: ObservableObject {

    // MARK: Published State

    @Published var connectionStatus: ConnectionStatus = .loading
    @Published var partnerTodayData: SharedLog?
    @Published var sharingSettings: SharingSettings = .defaults
    @Published var isLoading: Bool = false
    @Published var disconnectError: Error?

    // MARK: Private

    private let supabase: SupabaseClient
    private let authService: AuthService
    private let sharingService: SharingService
    private var realtimeChannel: RealtimeChannelV2?
    private var activeConnectionId: UUID?
    private var trackerUserId: UUID?

    init(supabase: SupabaseClient, authService: AuthService, sharingService: SharingService) {
        self.supabase = supabase
        self.authService = authService
        self.sharingService = sharingService
    }

    // MARK: Load

    func loadPartnerData() async {
        guard let currentUserId = authService.currentUserId else {
            connectionStatus = .disconnected
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch active connection
            let connectionResponse = try await supabase
                .from("partner_connections")
                .select()
                .or("tracker_user_id.eq.\(currentUserId),partner_user_id.eq.\(currentUserId)")
                .eq("status", "active")
                .maybeSingle()
                .execute()

            guard let connection = try? connectionResponse.value as PartnerConnection else {
                connectionStatus = .disconnected
                return
            }

            activeConnectionId = connection.id
            trackerUserId = connection.trackerUserId

            // Determine partner user ID
            let partnerUserId = connection.trackerUserId == currentUserId
                ? connection.partnerUserId
                : connection.trackerUserId

            // Fetch partner display name
            let partnerResponse = try await supabase
                .from("users")
                .select("display_name")
                .eq("id", partnerUserId.uuidString)
                .single()
                .execute()
            let partnerName = (try? partnerResponse.value as UserSummary)?.displayName ?? "Partner"

            connectionStatus = .connected(partnerName: partnerName, partnerUserId: partnerUserId)

            // Fetch today's shared data (partner reads shared_logs only — NEVER cycle_logs)
            let todayString = ISO8601DateFormatter.dateOnly.string(from: Date())
            let sharedResponse = try await supabase
                .from("shared_logs")
                .select()
                .eq("tracker_user_id", connection.trackerUserId.uuidString)
                .eq("partner_user_id", partnerUserId.uuidString)
                .eq("log_date", todayString)
                .maybeSingle()
                .execute()
            partnerTodayData = try? sharedResponse.value as SharedLog

            // Fetch sharing settings (readable by both users in a connection)
            let settingsResponse = try await supabase
                .from("sharing_settings")
                .select()
                .eq("user_id", connection.trackerUserId.uuidString)
                .single()
                .execute()
            sharingSettings = (try? settingsResponse.value as SharingSettings) ?? .defaults

            // Subscribe to realtime updates
            await subscribeToSharedLogs(
                trackerUserId: connection.trackerUserId,
                partnerUserId: partnerUserId
            )

        } catch {
            connectionStatus = .disconnected
        }
    }

    // MARK: Update Sharing Setting

    func updateSharingSetting(category: ShareCategory, enabled: Bool) async {
        guard let currentUserId = authService.currentUserId,
              case .connected(_, let partnerUserId) = connectionStatus else { return }

        // Optimistic update
        switch category {
        case .period:   sharingSettings.sharePeriod   = enabled
        case .symptoms: sharingSettings.shareSymptoms = enabled
        case .mood:     sharingSettings.shareMood     = enabled
        case .energy:   sharingSettings.shareEnergy   = enabled
        }

        do {
            try await sharingService.updateSharingSetting(
                category: category,
                enabled: enabled,
                trackerUserId: currentUserId,
                partnerUserId: partnerUserId
            )
        } catch {
            // Revert optimistic update on failure
            switch category {
            case .period:   sharingSettings.sharePeriod   = !enabled
            case .symptoms: sharingSettings.shareSymptoms = !enabled
            case .mood:     sharingSettings.shareMood     = !enabled
            case .energy:   sharingSettings.shareEnergy   = !enabled
            }
        }
    }

    // MARK: Disconnect

    func disconnect() async {
        // See references/disconnect-flow.md for full implementation
    }

    // MARK: Realtime

    private func subscribeToSharedLogs(trackerUserId: UUID, partnerUserId: UUID) async {
        await realtimeChannel?.unsubscribe()

        let channel = await supabase.realtimeV2.channel("shared_logs:\(trackerUserId)")
        await channel.on(
            "postgres_changes",
            filter: ChannelFilter(
                event: "*",
                schema: "public",
                table: "shared_logs",
                filter: "tracker_user_id=eq.\(trackerUserId)&partner_user_id=eq.\(partnerUserId)"
            )
        ) { [weak self] message in
            guard let self else { return }
            Task { @MainActor in
                await self.loadPartnerData()
            }
        }

        await channel.subscribe()
        realtimeChannel = channel
    }

    // MARK: Cleanup

    deinit {
        let channel = realtimeChannel
        Task {
            await channel?.unsubscribe()
        }
    }
}
```

---

## Realtime Note

On receiving any `shared_logs` change, call `loadPartnerData()` rather than
attempting to merge incremental changes. The row count is small (one row per day)
and correctness is more important than avoiding a full reload.
