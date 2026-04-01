# Cadence — App Root Routing & Re-entry Guard

## AppRootView

The app entry point. Owns auth state and onboarding completion state.
Routes to one of three destinations based on current state.

```swift
@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

struct AppRootView: View {
    @StateObject private var authState = AuthStateManager()
    @State private var showMain = false

    var body: some View {
        Group {
            if !authState.isAuthenticated {
                // Not authenticated → Welcome screen
                WelcomeView()
            } else if !authState.onboardingComplete {
                // Authenticated but onboarding incomplete → Onboarding
                OnboardingCoordinatorView()
                    .onReceive(NotificationCenter.default.publisher(
                        for: .onboardingDidComplete
                    )) { _ in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            authState.onboardingComplete = true
                        }
                    }
            } else {
                // Fully set up → Main app
                MainTabView()
                    .transition(.opacity)  // cross-fade only — no slide
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authState.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: authState.onboardingComplete)
    }
}
```

---

## AuthStateManager

```swift
@MainActor
final class AuthStateManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var onboardingComplete: Bool = false

    init() {
        // Check Supabase session
        isAuthenticated = SupabaseService.shared.currentSession != nil
        // Check local completion flag (fast path — avoids network on launch)
        onboardingComplete = UserDefaults.standard.bool(
            forKey: "cadence.onboardingComplete")
        // Subscribe to auth changes
        Task { await observeAuthChanges() }
    }

    private func observeAuthChanges() async {
        for await event in SupabaseService.shared.authStateStream {
            switch event {
            case .signedIn:
                isAuthenticated = true
                // Re-check onboarding in case user signed in on a new device
                onboardingComplete = await checkOnboardingCompleteRemotely()
            case .signedOut:
                isAuthenticated = false
                onboardingComplete = false
                UserDefaults.standard.removeObject(
                    forKey: "cadence.onboardingComplete")
            default:
                break
            }
        }
    }

    private func checkOnboardingCompleteRemotely() async -> Bool {
        // Query Supabase for user record; check onboarding_complete flag
        // Fall back to UserDefaults if network unavailable
        do {
            return try await SupabaseService.shared.fetchOnboardingComplete()
        } catch {
            return UserDefaults.standard.bool(forKey: "cadence.onboardingComplete")
        }
    }
}
```

---

## Notification to trigger the root transition

Post this from `OnboardingViewModel` when `commitState` becomes `.complete`:

```swift
// In commitOnboarding(), after commitState = .complete:
NotificationCenter.default.post(name: .onboardingDidComplete, object: nil)

// Extension:
extension Notification.Name {
    static let onboardingDidComplete = Notification.Name("cadence.onboardingDidComplete")
}
```

---

## Re-entry Guard — Incomplete Onboarding

If the user is authenticated but `onboardingComplete == false` (e.g. they
signed in then killed the app mid-onboarding), they re-enter the onboarding
flow at `OnboardingCoordinatorView`.

The flow always starts at `RoleSelectionView` — we do not attempt to
restore the exact step. This is intentional: onboarding is short (< 2
minutes) and partially-completed state is not worth the complexity of
serialising and restoring a `NavigationPath`.

If the user re-enters and they already have a `cycle_profiles` row in
Supabase (e.g. they completed up to Step 3 last time), the final
`commitOnboarding()` upserts idempotently — duplicate writes are safe.

---

## Deep Link Handling (Invite Token Extraction)

```swift
// In CadenceApp.swift — handle incoming deep link before onboarding starts:
.onOpenURL { url in
    // cadenceapp.com/invite/<token>  or  cadence://invite?token=<token>
    if let token = extractInviteToken(from: url) {
        // Inject into OnboardingViewModel before the flow renders
        // Use a shared AppEnvironment or a @AppStorage key as the hand-off:
        AppEnvironment.shared.pendingInviteToken = token
    }
}

// OnboardingViewModel.init() reads this:
init() {
    self.inviteToken = AppEnvironment.shared.pendingInviteToken
    AppEnvironment.shared.pendingInviteToken = nil  // consume
}
```

Deep link token must be consumed exactly once. Clearing it in `init()`
prevents stale tokens from being applied on subsequent launches.
