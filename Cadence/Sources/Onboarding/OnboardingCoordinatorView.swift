import SwiftUI

struct OnboardingCoordinatorView: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(inviteToken: String? = nil) {
        let vm = OnboardingViewModel()
        vm.inviteToken = inviteToken
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            RoleSelectionView()
                .navigationDestination(for: OnboardingRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .environmentObject(viewModel)
    }

    @ViewBuilder
    private func destinationView(for route: OnboardingRoute) -> some View {
        switch route {
            case .roleSelection:
                RoleSelectionView()
            case .lastPeriodDate:
                LastPeriodDateView()
            case .cycleLengths:
                CycleLengthsView()
            case .sharingPreferences:
                SharingPreferencesView()
            case .invitePartner:
                InvitePartnerView()
            case .notifications:
                NotificationsView()
            case let .acceptConnection(token):
                AcceptConnectionView(inviteToken: token)
            case .partnerNotifications:
                PartnerNotificationsView()
        }
    }
}
