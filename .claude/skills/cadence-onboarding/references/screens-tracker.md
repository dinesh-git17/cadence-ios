# Cadence Onboarding — Tracker Screens (Steps 1–6)

All screens use `@EnvironmentObject var vm: OnboardingViewModel` and the
`CadenceProgressDots` / `StepPill` components defined in SKILL.md.

---

## Step 1 — Role Selection

```swift
struct RoleSelectionView: View {
    @EnvironmentObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: 0)
                StepPill(label: "Step 1 of 6", variant: .required)
            }.padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Will you be tracking\nyour own cycle?")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
                Text("This sets up your experience.")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color(hex: "#7A5250"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            VStack(spacing: 8) {
                RoleCard(
                    title: "Yes, I track my cycle",
                    subtitle: "Log your period, symptoms, moods, and more.",
                    isSelected: vm.isTracker
                ) { vm.isTracker = true }

                RoleCard(
                    title: "No, I'm a partner",
                    subtitle: "Stay informed about your partner's cycle.",
                    isSelected: !vm.isTracker
                ) { vm.isTracker = false }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()

            Button("Continue") {
                if vm.isTracker {
                    vm.path.append(OnboardingRoute.lastPeriodDate)
                } else {
                    vm.path.append(OnboardingRoute.acceptConnection(
                        inviteToken: vm.inviteToken))
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

struct RoleCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Color(hex: "#1A0F0E"))
                    Text(subtitle)
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Color(hex: "#7A5250"))
                }
                Spacer()
                Circle()
                    .strokeBorder(isSelected
                        ? Color(hex: "#F88379")
                        : Color(hex: "#F2DDD8"), lineWidth: 1.5)
                    .background(Circle().fill(isSelected
                        ? Color(hex: "#F88379")
                        : .clear))
                    .frame(width: 16, height: 16)
            }
            .padding(12)
            .background(isSelected
                ? Color(hex: "#FEF2F1")
                : Color(hex: "#FEF9F8"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                isSelected ? Color(hex: "#F88379") : Color(hex: "#F2DDD8"),
                lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
```

---

## Step 2 — Last Period Date

Implement as a SwiftUI grid calendar. Do NOT use UIDatePicker or
DatePicker(). Build a month grid manually.

```swift
struct LastPeriodDateView: View {
    @EnvironmentObject var vm: OnboardingViewModel
    @State private var displayedMonth: Date = .now

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["S","M","T","W","T","F","S"]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: 1)
                StepPill(label: "Step 2 of 6", variant: .required)
            }.padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("When did your last\nperiod start?")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            // Selected date display card
            HStack {
                Text("Last period")
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Color(hex: "#B89490"))
                    .textCase(.uppercase)
                Spacer()
                Text(vm.lastPeriodDate, style: .date)
                    .font(.custom("PlayfairDisplay-Regular", size: 18))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
            }
            .padding(12)
            .background(Color(hex: "#FEF6F5"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                Color(hex: "#F2DDD8"), lineWidth: 0.5))
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Mini calendar
            VStack(spacing: 8) {
                // Month nav
                HStack {
                    Button { shiftMonth(-1) } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color(hex: "#B89490"))
                    }
                    Spacer()
                    Text(displayedMonth, format: .dateTime.month().year())
                        .font(.custom("DMSans-Medium", size: 10))
                        .foregroundStyle(Color(hex: "#7A5250"))
                    Spacer()
                    Button { shiftMonth(1) } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color(hex: "#B89490"))
                    }
                }

                // Day of week headers
                HStack(spacing: 0) {
                    ForEach(dayLabels, id: \.self) { d in
                        Text(d)
                            .font(.custom("DMSans-Medium", size: 9))
                            .foregroundStyle(Color(hex: "#B89490"))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Date grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date {
                            let isSelected = calendar.isDate(
                                date, inSameDayAs: vm.lastPeriodDate)
                            let isFuture = date > .now
                            Text("\(calendar.component(.day, from: date))")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundStyle(isFuture
                                    ? Color(hex: "#B89490")
                                    : isSelected ? .white : Color(hex: "#7A5250"))
                                .frame(width: 28, height: 28)
                                .background(isSelected
                                    ? Circle().fill(Color(hex: "#F88379"))
                                    : Circle().fill(.clear))
                                .onTapGesture {
                                    guard !isFuture else { return }
                                    vm.lastPeriodDate = date
                                }
                        } else {
                            Color.clear.frame(width: 28, height: 28)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(hex: "#FEF9F8"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                Color(hex: "#F2DDD8"), lineWidth: 0.5))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            Button("Continue") {
                vm.path.append(OnboardingRoute.cycleLengths)
            }
            .buttonStyle(CadencePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
    }

    private func shiftMonth(_ delta: Int) {
        displayedMonth = calendar.date(
            byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }

    private func daysInMonth() -> [Date?] {
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)),
            let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }
        let weekdayOffset = (calendar.component(.weekday, from: monthStart) - 1)
        let padding: [Date?] = Array(repeating: nil, count: weekdayOffset)
        let dates: [Date?] = range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
        return padding + dates
    }
}
```

---

## Step 3 — Cycle Length + Period Duration

Picker rows that open a wheel picker sheet on tap. Defaults: 28 / 5.

```swift
struct CycleLengthsView: View {
    @EnvironmentObject var vm: OnboardingViewModel
    @State private var showCyclePicker = false
    @State private var showDurationPicker = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: 2)
                StepPill(label: "Step 3 of 6", variant: .required)
            }.padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tell us about\nyour cycle")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            VStack(spacing: 8) {
                PickerRow(label: "Cycle length",
                          value: "\(vm.cycleLength) days") {
                    showCyclePicker = true
                }
                PickerRow(label: "Period duration",
                          value: "\(vm.periodDuration) days") {
                    showDurationPicker = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            // Helper tip
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#B89490"))
                Text("Not sure? Use the defaults — they self-correct as you log.")
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Color(hex: "#7A5250"))
            }
            .padding(8)
            .background(Color(hex: "#FEF6F5"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            Button("Continue") {
                vm.path.append(OnboardingRoute.sharingPreferences)
            }
            .buttonStyle(CadencePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
        .sheet(isPresented: $showCyclePicker) {
            WheelPickerSheet(
                title: "Cycle length",
                range: 21...45,
                selection: $vm.cycleLength,
                unit: "days"
            )
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showDurationPicker) {
            WheelPickerSheet(
                title: "Period duration",
                range: 2...10,
                selection: $vm.periodDuration,
                unit: "days"
            )
            .presentationDetents([.height(280)])
        }
    }
}

struct PickerRow: View {
    let label: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color(hex: "#7A5250"))
                Spacer()
                Text(value)
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#B89490"))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(hex: "#FEF6F5"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                Color(hex: "#F2DDD8"), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

struct WheelPickerSheet: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var selection: Int
    let unit: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: "#E8C8C4"))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
            Text(title)
                .font(.custom("PlayfairDisplay-Regular", size: 18))
                .padding(.top, 12)
            Picker(title, selection: $selection) {
                ForEach(range, id: \.self) { n in
                    Text("\(n) \(unit)").tag(n)
                }
            }
            .pickerStyle(.wheel)
            Button("Done") { dismiss() }
                .buttonStyle(CadencePrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }
}
```

---

## Step 4 — Sharing Preferences

All toggles default to `false`. Never change this. Copy at top is mandatory.

```swift
struct SharingPreferencesView: View {
    @EnvironmentObject var vm: OnboardingViewModel

    private let categories: [(label: String, sublabel: String,
                               binding: WritableKeyPath<OnboardingViewModel, Bool>)] = [
        ("Period", "Flow and dates", \.sharePeriod),
        ("Mood", "How you're feeling", \.shareMood),
        ("Symptoms", "Cramps, headaches, and more", \.shareSymptoms),
        ("Energy", "Low, medium, or high", \.shareEnergy),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: 3)
                StepPill(label: "Step 4 of 6", variant: .required)
            }.padding(.top, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("What would you like\nto share?")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .foregroundStyle(Color(hex: "#1A0F0E"))
                Text("All off by default. You can change this anytime.")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Color(hex: "#7A5250"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 32)

            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.offset) { i, cat in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.label)
                                .font(.custom("DMSans-Medium", size: 12))
                                .foregroundStyle(Color(hex: "#1A0F0E"))
                            Text(cat.sublabel)
                                .font(.custom("DMSans-Regular", size: 10))
                                .foregroundStyle(Color(hex: "#B89490"))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm[keyPath: cat.binding] },
                            set: { vm[keyPath: cat.binding] = $0 }
                        ))
                        .labelsHidden()
                        .tint(Color(hex: "#F88379"))
                    }
                    .padding(.vertical, 10)
                    if i < categories.count - 1 {
                        Divider()
                            .background(Color(hex: "#F2DDD8"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()

            Button("Continue") {
                vm.path.append(OnboardingRoute.invitePartner)
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

---

## Step 5 — Invite Partner (Optional)

Generate invite link on appear. Never block advance on share action.

```swift
struct InvitePartnerView: View {
    @EnvironmentObject var vm: OnboardingViewModel
    @State private var inviteURL: URL? = nil
    @State private var isGenerating = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: 4)
                StepPill(label: "Optional", variant: .optional)
            }.padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                // Illustration
                ZStack {
                    Circle().fill(Color(hex: "#FEF2F1")).frame(width: 80, height: 80)
                    Circle().fill(Color(hex: "#FDDBD8")).frame(width: 48, height: 48)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#F88379"))
                }

                VStack(spacing: 8) {
                    Text("Invite your partner")
                        .font(.custom("PlayfairDisplay-Regular", size: 20))
                        .foregroundStyle(Color(hex: "#1A0F0E"))
                        .multilineTextAlignment(.center)
                    Text("Share your cycle with someone who cares —\non your terms.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Color(hex: "#7A5250"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                if let url = inviteURL {
                    ShareLink(item: url,
                              message: Text("Join me on Cadence")) {
                        Label("Send invite link",
                              systemImage: "square.and.arrow.up")
                            .font(.custom("DMSans-Medium", size: 13))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#F88379"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                } else {
                    ProgressView()
                        .tint(Color(hex: "#F88379"))
                }
            }

            Spacer()

            Button("Skip for now") {
                vm.path.append(OnboardingRoute.notifications)
            }
            .font(.custom("DMSans-Regular", size: 12))
            .foregroundStyle(Color(hex: "#7A5250"))
            .padding(.bottom, 12)

            Button("Continue") {
                vm.path.append(OnboardingRoute.notifications)
            }
            .buttonStyle(CadencePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
        .task { await generateInviteLink() }
    }

    private func generateInviteLink() async {
        isGenerating = true
        // Generate invite link via Supabase Edge Function or generate token
        // locally and store; deep link format: cadence://invite?token=<token>
        // Replace with real Supabase call:
        let token = UUID().uuidString
        vm.pendingInviteToken = token
        inviteURL = URL(string: "https://cadenceapp.com/invite/\(token)")
        isGenerating = false
    }
}
```

---

## Step 6 — Notifications

Request permission on "Enter Cadence" tap — NOT on screen appear.

```swift
struct NotificationsView: View {
    @EnvironmentObject var vm: OnboardingViewModel

    private let notificationRows: [(icon: String, title: String,
                                     sub: String,
                                     binding: WritableKeyPath<OnboardingViewModel, Bool>)] = [
        ("calendar", "Period reminder", "Day before your predicted period", \.notifyPeriodReminder),
        ("sun.max", "Ovulation alert", "When your fertile window opens", \.notifyOvulation),
        ("moon", "Daily log reminder", "A nudge to log your day at 8:00 PM", \.notifyDailyLog),
        ("heart", "Partner activity", "When your partner logs their day", \.notifyPartnerActivity),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                CadenceProgressDots(total: 6, current: 5)
                StepPill(label: "Step 6 of 6", variant: .required)
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
                ForEach(Array(notificationRows.enumerated()), id: \.offset) { i, row in
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
                    if i < notificationRows.count - 1 {
                        Divider().background(Color(hex: "#F2DDD8"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()

            Button("Enter Cadence") {
                Task {
                    await requestNotificationsAndCommit()
                }
            }
            .buttonStyle(CadencePrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .disabled(vm.commitState == .loading)
            .overlay(alignment: .center) {
                if vm.commitState == .loading {
                    ProgressView().tint(.white)
                }
            }
        }
        .background(Color(hex: "#FFFFFF"))
        .navigationBarHidden(true)
    }

    private func requestNotificationsAndCommit() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await vm.commitOnboarding()
        // AppRootView observes commitState == .complete and cross-fades to main tab
    }
}
```
