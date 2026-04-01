import SwiftUI

struct RootView: View {
    @State private var authViewModel = AuthViewModel()

    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.passwordRecoveryActive {
                    ResetPasswordView(authViewModel: authViewModel)
                } else if onboardingComplete {
                    mainTabView
                } else {
                    onboardingPlaceholder
                }
            } else {
                WelcomeView(authViewModel: authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.passwordRecoveryActive)
        .animation(.easeInOut(duration: 0.3), value: onboardingComplete)
        .onOpenURL { url in
            let resolved = resolveAuthURL(url)
            let isReset = url.path.contains("/auth/reset")
                || (url.scheme == "cadence" && url.host == "auth" && url.path.contains("reset"))
            if isReset {
                authViewModel.passwordRecoveryActive = true
            }
            Task { try? await supabase.auth.handle(resolved) }
        }
    }

    /// Placeholder until the onboarding flow is implemented in Task 2.1.
    private var onboardingPlaceholder: some View {
        VStack(spacing: CadenceSpacing.xl) {
            Text("Onboarding")
                .font(.cadenceTitleLarge)
                .foregroundColor(.cadenceTextPrimary)
            Text("Coming in Task 2.1")
                .font(.cadenceBodySmall)
                .foregroundColor(.cadenceTextTertiary)
            Button("Skip (dev only)") {
                onboardingComplete = true
            }
            .buttonStyle(GhostButtonStyle())
            Button("Sign out") {
                Task { await authViewModel.signOut() }
            }
            .buttonStyle(DestructiveTextButtonStyle())
        }
        .padding(CadenceSpacing.lg)
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
                Task {
                    onboardingComplete = false
                    await authViewModel.signOut()
                }
            }
            .buttonStyle(DestructiveTextButtonStyle())
        }
        .padding(CadenceSpacing.lg)
    }
}
