# Cadence Onboarding — Partner Screens (Steps 1–3)

Partner arrives via deep link. The invite token is extracted at app launch
and injected into `OnboardingViewModel.inviteToken` before the flow starts.

---

## Partner Onboarding Flow

```
roleSelection (shared Step 1)
  → acceptConnection (token pre-filled from invite link)
    → partnerNotifications ("Enter Cadence")
```

Partner path uses a 3-dot progress indicator, not 6.

---

## Step 1 — Role Selection (Shared)

Same `RoleSelectionView` as the tracker path. When the user selects
"No, I'm a partner" and taps Continue, the coordinator pushes:

```swift
vm.path.append(OnboardingRoute.acceptConnection(inviteToken: vm.inviteToken))
```

If `vm.inviteToken` is nil (partner opened the app without a deep link),
show a different empty state: a text field to paste an invite code, or a
message saying "Ask your partner to send you an invite link."

---

## Step 2 — Accept Connection

```swift
struct AcceptConnectionView: View {
    @EnvironmentObject var vm: OnboardingViewModel
    let inviteToken: String?

    @State private var trackerName: String = ""
    @State private var isValidating = false
    @State private var validationError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 3, current: 1)
                StepPill(label: "Step 2 of 3", variant: .required)
            }.padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Connect with\nyour partner")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
                Text("You'll only see what they choose to share.")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color(hex: "#7A5250"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            if let token = inviteToken {
                // Token present — show connection card
                VStack(spacing: 16) {
                    if !trackerName.isEmpty {
                        // Connection card after validation
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#FDDBD8"))
                                    .frame(width: 40, height: 40)
                                Text(String(trackerName.prefix(2)).uppercased())
                                    .font(.custom("DMSans-Medium", size: 14))
                                    .foregroundStyle(Color(hex: "#C05A52"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trackerName)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .foregroundStyle(Color(hex: "#1A0F0E"))
                                Text("Invited you to connect on Cadence")
                                    .font(.custom("DMSans-Regular", size: 11))
                                    .foregroundStyle(Color(hex: "#7A5250"))
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#4CAF7D"))
                                .font(.system(size: 18))
                        }
                        .padding(12)
                        .background(Color(hex: "#FEF9F8"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                            Color(hex: "#F2DDD8"), lineWidth: 0.5))
                    } else if isValidating {
                        ProgressView()
                            .tint(Color(hex: "#F88379"))
                            .frame(maxWidth: .infinity, minHeight: 60)
                    } else if let error = validationError {
                        Text(error)
                            .font(.custom("DMSans-Regular", size: 12))
                            .foregroundStyle(Color(hex: "#E74C3C"))
                            .padding(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .task(id: token) {
                    await validateToken(token)
                }
            } else {
                // No token — manual entry fallback
                VStack(alignment: .leading, spacing: 8) {
                    Text("No invite link found")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundStyle(Color(hex: "#1A0F0E"))
                    Text("Ask your partner to open Cadence and send you an invite link.")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Color(hex: "#7A5250"))
                }
                .padding(12)
                .background(Color(hex: "#FEF9F8"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                    Color(hex: "#F2DDD8"), lineWidth: 0.5))
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }

            Spacer()

            Button("Accept & connect") {
                vm.resolvedInviteToken = inviteToken
                vm.path.append(OnboardingRoute.partnerNotifications)
            }
            .buttonStyle(CadencePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .disabled(inviteToken != nil && trackerName.isEmpty)
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
    }

    private func validateToken(_ token: String) async {
        isValidating = true
        validationError = nil
        do {
            // Call Supabase to validate invite_links row:
            // SELECT users.display_name FROM invite_links
            //   JOIN users ON invite_links.tracker_user_id = users.id
            //   WHERE token = ? AND used = false AND expires_at > now()
            // On success, set trackerName
            // On failure or expired, set validationError
            let name = try await SupabaseService.shared.validateInviteToken(token)
            trackerName = name
        } catch {
            validationError = "This invite link has expired or is no longer valid."
        }
        isValidating = false
    }
}
```

---

## Step 3 — Partner Notifications

Identical in structure to the tracker `NotificationsView` but with
3-dot progress and only the relevant notifications for a partner:

```swift
struct PartnerNotificationsView: View {
    @EnvironmentObject var vm: OnboardingViewModel

    private let rows: [(icon: String, title: String,
                         sub: String,
                         binding: WritableKeyPath<OnboardingViewModel, Bool>)] = [
        ("heart", "Partner activity",
         "When your partner logs their day", \.notifyPartnerActivity),
        ("calendar", "Upcoming phase",
         "Heads up before a cycle phase change", \.notifyPhaseChange),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 3, current: 2)
                StepPill(label: "Step 3 of 3", variant: .required)
            }.padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Stay in the loop")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
                Text("Choose what you'd like to be notified about.")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color(hex: "#7A5250"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#FDDBD8"))
                                .frame(width: 28, height: 28)
                            Image(systemName: row.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#F88379"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.custom("DMSans-Medium", size: 11))
                                .foregroundStyle(Color(hex: "#1A0F0E"))
                            Text(row.sub)
                                .font(.custom("DMSans-Regular", size: 10))
                                .foregroundStyle(Color(hex: "#B89490"))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm[keyPath: row.binding] },
                            set: { vm[keyPath: row.binding] = $0 }
                        ))
                        .labelsHidden()
                        .tint(Color(hex: "#F88379"))
                    }
                    .padding(.vertical, 10)
                    if i < rows.count - 1 {
                        Divider().background(Color(hex: "#F2DDD8"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()

            Button("Enter Cadence") {
                Task {
                    let center = UNUserNotificationCenter.current()
                    _ = try? await center.requestAuthorization(
                        options: [.alert, .sound, .badge])
                    await vm.commitOnboarding()
                }
            }
            .buttonStyle(CadencePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
    }
}
```
