# Cadence Onboarding — Persistence & Commit

## OnboardingViewModel — Full Declaration

```swift
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Navigation
    @Published var path = NavigationPath()

    // MARK: - Role
    @Published var isTracker: Bool = true

    // MARK: - Tracker seed data
    @Published var lastPeriodDate: Date = Calendar.current.date(
        byAdding: .day, value: -14, to: .now)!
    @Published var cycleLength: Int = 28
    @Published var periodDuration: Int = 5

    // MARK: - Sharing (MUST all default false — privacy requirement)
    @Published var sharePeriod: Bool = false
    @Published var shareMood: Bool = false
    @Published var shareSymptoms: Bool = false
    @Published var shareEnergy: Bool = false

    // MARK: - Notifications
    @Published var notifyPeriodReminder: Bool = true
    @Published var notifyOvulation: Bool = true
    @Published var notifyDailyLog: Bool = true
    @Published var notifyPartnerActivity: Bool = true
    @Published var notifyPhaseChange: Bool = true

    // MARK: - Invite / connection
    var inviteToken: String? = nil           // from deep link at app launch
    var resolvedInviteToken: String? = nil   // set in AcceptConnectionView
    var pendingInviteToken: String? = nil    // set in InvitePartnerView

    // MARK: - Commit state
    @Published var commitState: CommitState = .idle

    enum CommitState: Equatable {
        case idle
        case loading
        case failed(String)   // user-facing error message
        case complete
    }
}
```

---

## commitOnboarding() — Sequential Supabase Writes

All writes happen in a single `Task`. If any step fails, `commitState`
is set to `.failed` and the user can retry from the notifications screen
without losing any data — the ViewModel is still populated.

```swift
extension OnboardingViewModel {
    func commitOnboarding() async {
        guard commitState != .loading, commitState != .complete else { return }
        commitState = .loading

        do {
            let client = SupabaseService.shared

            // Step a: Upsert user record (auth may have created it already)
            try await client.upsertUser(isTracker: isTracker)

            if isTracker {
                // Step b: Write cycle_profiles seed data
                try await client.writeCycleProfile(
                    lastPeriodDate: lastPeriodDate,
                    seededCycleLength: cycleLength,
                    seededPeriodDuration: periodDuration
                )

                // Step c: Write sharing_settings (all false unless user toggled)
                try await client.writeSharingSettings(
                    sharePeriod: sharePeriod,
                    shareMood: shareMood,
                    shareSymptoms: shareSymptoms,
                    shareEnergy: shareEnergy
                )
            }

            // Step d: Store notification preferences
            try await client.writeNotificationPreferences(
                periodReminder: notifyPeriodReminder,
                ovulation: notifyOvulation,
                dailyLog: notifyDailyLog,
                partnerActivity: notifyPartnerActivity,
                phaseChange: notifyPhaseChange
            )

            // Step e: If partner — validate and create partner_connections
            if !isTracker, let token = resolvedInviteToken {
                try await client.acceptInvite(token: token)
            }

            // Step f: Mark onboarding complete
            UserDefaults.standard.set(true, forKey: "cadence.onboardingComplete")
            try await client.markOnboardingComplete()

            commitState = .complete

        } catch {
            commitState = .failed(
                "Something went wrong — try again. Your information is saved."
            )
        }
    }
}
```

---

## Error Recovery UI

The notifications screen shows an inline error banner when
`commitState == .failed`. The "Enter Cadence" button re-triggers the
same `commitOnboarding()` call. No data is lost.

```swift
// Add inside NotificationsView / PartnerNotificationsView body,
// above the primary CTA:
if case .failed(let message) = vm.commitState {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle")
            .foregroundStyle(Color(hex: "#E74C3C"))
        Text(message)
            .font(.custom("DMSans-Regular", size: 11))
            .foregroundStyle(Color(hex: "#E74C3C"))
    }
    .padding(10)
    .background(Color(hex: "#FEF9F8"))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(
        Color(hex: "#E74C3C").opacity(0.4), lineWidth: 0.5))
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
}
```

The CTA copy changes to "Try again" when `commitState == .failed`:

```swift
Button(vm.commitState == .failed(.init()) ? "Try again" : "Enter Cadence") {
    Task { await requestNotificationsAndCommit() }
}
```

---

## Supabase Write Stubs

These are the function signatures expected on `SupabaseService`. Implement
them using the Supabase Swift SDK against the schema in the PRD (Section 12).

```swift
protocol SupabaseServiceProtocol {
    func upsertUser(isTracker: Bool) async throws
    func writeCycleProfile(
        lastPeriodDate: Date,
        seededCycleLength: Int,
        seededPeriodDuration: Int
    ) async throws
    func writeSharingSettings(
        sharePeriod: Bool,
        shareMood: Bool,
        shareSymptoms: Bool,
        shareEnergy: Bool
    ) async throws
    func writeNotificationPreferences(
        periodReminder: Bool,
        ovulation: Bool,
        dailyLog: Bool,
        partnerActivity: Bool,
        phaseChange: Bool
    ) async throws
    func validateInviteToken(_ token: String) async throws -> String
    func acceptInvite(token: String) async throws
    func markOnboardingComplete() async throws
}
```

All tables use Row Level Security as specified in PRD Section 12.3.
The `sharing_settings` row defaults all fields to `false` — verify in
your Supabase migration that column defaults match.
