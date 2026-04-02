import Foundation

enum OnboardingRoute: Hashable {
    /// Shared
    case roleSelection

    // Tracker path
    case lastPeriodDate
    case cycleLengths
    case sharingPreferences
    case invitePartner
    case notifications

    // Partner path
    case acceptConnection(inviteToken: String?)
    case partnerNotifications
}
