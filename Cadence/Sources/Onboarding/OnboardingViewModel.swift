import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Navigation

    @Published var path = NavigationPath()

    // MARK: - Role

    enum RoleSelection { case tracker, partner }

    @Published var selectedRole: RoleSelection?

    // MARK: - Tracker seed data

    @Published var lastPeriodDate: Date = defaultLastPeriodDate
    @Published var cycleLength: Int = 28
    @Published var periodDuration: Int = 5

    // MARK: - Sharing (MUST all default false — privacy-by-design)

    @Published var sharePeriod: Bool = false
    @Published var shareMood: Bool = false
    @Published var shareSymptoms: Bool = false
    @Published var shareEnergy: Bool = false

    // MARK: - Notifications (sensible UX defaults — all on)

    @Published var notifyPeriodReminder: Bool = true
    @Published var notifyOvulation: Bool = true
    @Published var notifyDailyLog: Bool = true
    @Published var notifyPartnerActivity: Bool = true
    @Published var notifyPeriodLate: Bool = true
    @Published var notifyPhaseChange: Bool = true

    // MARK: - Invite / connection

    /// Injected at construction from deep link, if present.
    var inviteToken: String?
    /// Set by AcceptConnectionView after validation succeeds.
    var resolvedInviteToken: String?
    /// Tracker ID resolved from invite validation (partner path).
    var resolvedTrackerId: UUID?
    /// Token generated locally in InvitePartnerView for deferred DB write.
    var pendingInviteToken: String?

    // MARK: - Commit state

    @Published var commitState: CommitState = .idle

    enum CommitState: Equatable {
        case idle
        case loading
        case failed(String)
        case complete
    }

    // MARK: - Services

    private let userService = UserService()
    private let cycleProfileService = CycleProfileService()
    private let sharingSettingsService = SharingSettingsService()
    private let notificationPreferencesService = NotificationPreferencesService()
    private let inviteLinkService = InviteLinkService()

    // MARK: - Defaults

    private static var defaultLastPeriodDate: Date {
        Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
    }
}

// MARK: - Commit Sequence

extension OnboardingViewModel {
    /// Writes all onboarding data to Supabase in a single sequential pass.
    /// Idempotent — safe to retry on failure.
    func commitOnboarding() async {
        guard commitState != .loading, commitState != .complete else { return }
        commitState = .loading

        do {
            guard let session = await supabase.auth.currentSession else {
                commitState = .failed("No active session. Please sign in again.")
                return
            }

            let userId = session.user.id
            let email = session.user.email ?? ""
            let name = session.user.userMetadata["full_name"]?.stringValue ?? email

            let tracker = selectedRole == .tracker
            try await userService.upsertUser(
                id: userId, email: email, displayName: name, isTracker: tracker
            )
            try EncryptionService.shared.loadKey(
                forUserID: userId.uuidString, serverSecret: Secrets.encryptionSecret
            )

            if tracker { try await commitTrackerData(userId: userId) }
            try await commitNotificationPreferences(userId: userId)

            if !tracker, let token = resolvedInviteToken {
                try await inviteLinkService.acceptInvite(token: token, partnerUserId: userId)
            }

            try await userService.markOnboardingComplete(userId: userId)
            let localKey = "onboardingComplete.\(userId.uuidString)"
            UserDefaults.standard.set(true, forKey: localKey)
            commitState = .complete
        } catch {
            commitState = .failed("Something went wrong — try again. Your information is saved.")
        }
    }

    private func commitTrackerData(userId: UUID) async throws {
        let profile = InsertCycleProfile(
            userId: userId,
            lastPeriodDate: lastPeriodDate,
            seededCycleLength: cycleLength,
            seededPeriodDuration: periodDuration
        )
        try await cycleProfileService.upsertProfile(profile)

        try await sharingSettingsService.upsertSharingSettings(
            userId: userId,
            sharePeriod: sharePeriod,
            shareMood: shareMood,
            shareSymptoms: shareSymptoms,
            shareEnergy: shareEnergy
        )

        if let token = pendingInviteToken {
            try await writePendingInviteLink(trackerUserId: userId, token: token)
        }
    }

    private func commitNotificationPreferences(userId: UUID) async throws {
        let prefs = InsertNotificationPreferences(
            userId: userId,
            periodReminder: notifyPeriodReminder,
            ovulationAlert: notifyOvulation,
            dailyLogReminder: notifyDailyLog,
            partnerActivity: notifyPartnerActivity,
            phaseChange: notifyPhaseChange,
            periodLate: notifyPeriodLate
        )
        try await notificationPreferencesService.upsertNotificationPreferences(prefs)
    }

    /// Writes the invite link row that was deferred from InvitePartnerView.
    private func writePendingInviteLink(trackerUserId: UUID, token: String) async throws {
        let expiryDays = 7
        let expiresAt = Calendar.current.date(
            byAdding: .day,
            value: expiryDays,
            to: .now
        ) ?? Date(timeIntervalSinceNow: TimeInterval(expiryDays * 86400))

        try await supabase
            .from("invite_links")
            .upsert(InviteLinkInsert(
                trackerUserId: trackerUserId,
                token: token,
                expiresAt: expiresAt
            ))
            .execute()
    }
}

/// Encodable payload for deferred invite link insert.
private struct InviteLinkInsert: Encodable {
    let trackerUserId: UUID
    let token: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case trackerUserId = "tracker_user_id"
        case token
        case expiresAt = "expires_at"
    }
}
