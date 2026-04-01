---
name: cadence-onboarding
description: >
  Implement the complete Cadence iOS onboarding flow. Use this skill before
  writing ANY onboarding screen, coordinator, view model, or routing logic
  in the Cadence project. Covers NavigationStack architecture, role-branching,
  all screen implementations, state accumulation, final Supabase commit
  sequence, error handling, and app-root routing. Trigger on any mention of
  onboarding, welcome screen, role selection, invite partner flow, tracker
  setup, partner setup, or "Enter Cadence" CTA.
---

# Cadence Onboarding — Implementation Skill

## Read This First

This skill covers the full onboarding system. Before implementing any
individual screen, read the architecture section here. Then load the
reference file(s) relevant to your task:

| Task | Reference file |
|---|---|
| Tracker screens (Steps 1–6) | `references/screens-tracker.md` |
| Partner screens (Steps 1–3) | `references/screens-partner.md` |
| OnboardingViewModel + Supabase commit | `references/persistence.md` |
| App root routing + re-entry guard | `references/routing.md` |

---

## Architecture

### Route Enum

```swift
enum OnboardingRoute: Hashable {
    // Shared
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
```

### OnboardingCoordinator

The single NavigationStack owner. All screens receive `@EnvironmentObject
var vm: OnboardingViewModel` — no direct init injection.

```swift
struct OnboardingCoordinatorView: View {
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        NavigationStack(path: $vm.path) {
            RoleSelectionView()
                .navigationDestination(for: OnboardingRoute.self) { route in
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
                    case .acceptConnection(let token):
                        AcceptConnectionView(inviteToken: token)
                    case .partnerNotifications:
                        PartnerNotificationsView()
                    }
                }
        }
        .environmentObject(vm)
    }
}
```

### Role Branching

Role selection is Step 1 for both paths. After role is set, the
coordinator advances to the correct next screen:

```swift
// In RoleSelectionView CTA handler:
if vm.isTracker {
    vm.path.append(OnboardingRoute.lastPeriodDate)
} else {
    // inviteToken injected at launch if app was opened via deep link
    vm.path.append(OnboardingRoute.acceptConnection(inviteToken: vm.inviteToken))
}
```

### Screen Sequence

**Tracker path (6 steps):**
```
roleSelection → lastPeriodDate → cycleLengths →
sharingPreferences → invitePartner (optional) → notifications
```

**Partner path (3 steps):**
```
roleSelection → acceptConnection → partnerNotifications
```

---

## OnboardingViewModel — Shape

Full implementation in `references/persistence.md`. Key state:

```swift
@MainActor
final class OnboardingViewModel: ObservableObject {
    // NavigationPath
    @Published var path = NavigationPath()

    // Role
    @Published var isTracker: Bool = true

    // Tracker seed data
    @Published var lastPeriodDate: Date = Calendar.current.date(
        byAdding: .day, value: -14, to: .now)!
    @Published var cycleLength: Int = 28
    @Published var periodDuration: Int = 5

    // Sharing (all off by default — never change these defaults)
    @Published var sharePeriod: Bool = false
    @Published var shareMood: Bool = false
    @Published var shareSymptoms: Bool = false
    @Published var shareEnergy: Bool = false

    // Partner connection
    var inviteToken: String? = nil  // set at launch from deep link

    // Commit state
    @Published var commitState: CommitState = .idle

    enum CommitState {
        case idle, loading, failed(Error), complete
    }
}
```

---

## Progress Dots Component

All onboarding screens use this component at the top:

```swift
struct CadenceProgressDots: View {
    let total: Int
    let current: Int     // 0-indexed

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color(hex: "#F88379") : Color(hex: "#F2DDD8"))
                    .frame(width: i == current ? 16 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}
```

---

## Step Pill Component

```swift
struct StepPill: View {
    enum Variant { case required, optional }
    let label: String
    let variant: Variant

    var body: some View {
        Text(label)
            .font(.custom("DMSans-Medium", size: 10))
            .foregroundStyle(variant == .required
                ? Color(hex: "#C05A52")
                : Color(hex: "#B89490"))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(variant == .required
                ? Color(hex: "#FEF2F1")
                : Color(hex: "#FEF6F5"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(
                variant == .required
                    ? Color(hex: "#F2DDD8")
                    : Color(hex: "#E8C8C4"),
                lineWidth: 0.5))
    }
}
```

---

## Screen Template

Every onboarding screen follows this shell. Fill in `stepIndex`,
`totalSteps`, pill variant, and content:

```swift
struct _OnboardingScreenTemplate: View {
    @EnvironmentObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress + pill
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: /* stepIndex */)
                StepPill(label: "Step N of 6", variant: .required)
            }
            .padding(.top, 16)

            // Screen content (see reference files)
            Spacer()

            // Primary CTA always at bottom
            Button("Continue") { /* advance path */ }
                .buttonStyle(CadencePrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
    }
}
```

---

## Final "Enter Cadence" Transition

The notifications screen is the last step for both paths. After the user
taps "Enter Cadence":

1. Request UNUserNotificationCenter permission **here, not earlier**
2. Call `vm.commitOnboarding()` (see `references/persistence.md`)
3. On `.complete`: cross-fade to MainTabView — do **not** push it onto
   the NavigationStack. Use a state variable on AppRootView instead.

```swift
// In NotificationsView / PartnerNotificationsView final CTA:
Task {
    await requestNotificationPermission()
    await vm.commitOnboarding()
}

// AppRootView observes vm.commitState == .complete and
// swaps the root view with .transition(.opacity)
```

---

## Non-Negotiable Constraints

- **All sharing toggles default to `false`** — never ship with any toggle
  pre-enabled. This is a privacy-by-design requirement.
- **Sex/intimacy, sleep, and notes are always private** — never appear
  in sharing preferences UI.
- **Notification permission is requested exactly once**, at the final
  "Enter Cadence" tap. Not on the notifications toggle screen appear.
- **Invite partner step is skippable** — "Skip for now" advances the path
  identically to sending the link. No data is lost.
- **Do not use UIDatePicker** for the last period date step — implement
  as a SwiftUI grid calendar (see `references/screens-tracker.md`).
- **Playfair Display** for screen titles and the cycle day display.
  **DM Sans** for everything else. Never mix them on the same line.

---

## Reference Files

Load the file(s) you need before implementing:

- `references/screens-tracker.md` — Full SwiftUI for all 6 tracker steps
- `references/screens-partner.md` — Full SwiftUI for all 3 partner steps
- `references/persistence.md` — OnboardingViewModel.commitOnboarding(),
  Supabase write sequence, error recovery, re-entry guard
- `references/routing.md` — AppRootView auth + onboarding routing logic
