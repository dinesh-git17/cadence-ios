import SwiftUI

struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @State private var pendingInviteToken: String?
    @State private var onboardingComplete = false
    @State private var isCheckingOnboarding = false

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.passwordRecoveryActive {
                    ResetPasswordView(authViewModel: authViewModel)
                } else if isCheckingOnboarding {
                    loadingView
                } else if onboardingComplete {
                    mainTabView
                } else {
                    OnboardingCoordinatorView(inviteToken: pendingInviteToken)
                }
            } else {
                WelcomeView(authViewModel: authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.passwordRecoveryActive)
        .animation(.easeInOut(duration: 0.3), value: onboardingComplete)
        .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
            if isAuth {
                Task { await checkOnboardingStatus() }
            } else {
                onboardingComplete = false
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .onboardingDidComplete)
        ) { _ in
            onboardingComplete = true
        }
    }

    private func checkOnboardingStatus() async {
        guard let userId = authViewModel.currentUserID else { return }

        // Fast path: check local cache first
        let localKey = "onboardingComplete.\(userId.uuidString)"
        if UserDefaults.standard.bool(forKey: localKey) {
            onboardingComplete = true
            return
        }

        // Slow path: check server
        isCheckingOnboarding = true
        do {
            let complete = try await UserService().fetchOnboardingComplete(userId: userId)
            if complete {
                UserDefaults.standard.set(true, forKey: localKey)
            }
            onboardingComplete = complete
        } catch {
            // Network failure — assume not complete, user will see onboarding
            onboardingComplete = false
        }
        isCheckingOnboarding = false
    }

    private func handleIncomingURL(_ url: URL) {
        if let token = extractInviteToken(from: url) {
            pendingInviteToken = token
        }

        let resolved = resolveAuthURL(url)
        let isReset = url.path.contains("/auth/reset")
            || (url.scheme == "cadence" && url.host == "auth" && url.path.contains("reset"))
        if isReset {
            authViewModel.passwordRecoveryActive = true
        }
        Task { try? await supabase.auth.handle(resolved) }
    }

    private var loadingView: some View {
        ProgressView()
            .tint(Color.cadencePrimary)
    }

    /// Placeholder until the main tab view is implemented in Task 2.3.
    private var mainTabView: some View {
        VStack(spacing: CadenceSpacing.xl) {
            Text("Cadence")
                .font(.cadenceTitleLarge)
                .foregroundColor(.cadenceTextPrimary)
            Text("Authenticated")
                .font(.cadenceBodySmall)
                .foregroundColor(.cadenceTextSecondary)
            Button("Sign out") {
                Task { await authViewModel.signOut() }
            }
            .buttonStyle(DestructiveTextButtonStyle())
        }
        .padding(CadenceSpacing.lg)
    }
}

extension Notification.Name {
    static let onboardingDidComplete = Notification.Name("cadence.onboardingDidComplete")
}
