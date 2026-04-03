import SwiftUI
import UserNotifications

struct NotificationRowData {
    let icon: String
    let title: String
    let sub: String
}

private let trackerNotificationRows: [NotificationRowData] = [
    .init(icon: "calendar", title: "Period reminder", sub: "Day before your predicted period"),
    .init(icon: "sun.max", title: "Ovulation alert", sub: "When your fertile window opens"),
    .init(icon: "moon", title: "Daily log reminder", sub: "A nudge to log your day at 8:00 PM"),
    .init(icon: "heart", title: "Partner activity", sub: "When your partner logs their day"),
    .init(icon: "exclamationmark.circle", title: "Period is late", sub: "When your predicted period hasn't arrived"),
    .init(icon: "arrow.triangle.2.circlepath", title: "Phase change", sub: "When you enter a new cycle phase"),
]

struct NotificationsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var showCompletion = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                OnboardingBackButton()
                progressHeader
                titleSection
                toggleList
                Spacer()
                errorBanner
                enterCadenceButton
            }

            if showCompletion {
                OnboardingCompletionOverlay()
            }
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
        .sensoryFeedback(.success, trigger: showCompletion)
        .onChange(of: viewModel.commitState) { _, newState in
            if newState == .complete { showCompletion = true }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 6, currentStep: 5)
            StepPill(label: "Step 6 of 6", variant: .required)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stay in the loop")
                .font(.cadenceTitleMedium)
                .foregroundStyle(Color.cadenceTextPrimary)
            Text("Choose what you'd like to be notified about.")
                .font(.cadenceBody)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xxl)
    }

    private var toggleList: some View {
        VStack(spacing: 0) {
            notificationRow(index: 0, binding: $viewModel.notifyPeriodReminder)
            notificationRow(index: 1, binding: $viewModel.notifyOvulation)
            notificationRow(index: 2, binding: $viewModel.notifyDailyLog)
            notificationRow(index: 3, binding: $viewModel.notifyPartnerActivity)
            notificationRow(index: 4, binding: $viewModel.notifyPeriodLate)
            notificationRow(index: 5, binding: $viewModel.notifyPhaseChange)
        }
        .padding(.vertical, CadenceSpacing.xs)
        .padding(.horizontal, CadenceSpacing.md)
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.xl)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xl)
    }

    private func notificationRow(
        index: Int,
        binding: Binding<Bool>
    ) -> some View {
        VStack(spacing: 0) {
            notificationRowContent(index: index, binding: binding)
            if index < trackerNotificationRows.count - 1 {
                Divider().background(Color.cadenceBorderDefault)
            }
        }
    }

    private func notificationRowContent(
        index: Int,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: CadenceSpacing.md) {
            CadenceIconTile(size: 28) {
                Image(systemName: trackerNotificationRows[index].icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cadencePrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(trackerNotificationRows[index].title)
                    .font(.cadenceBodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cadenceTextPrimary)
                Text(trackerNotificationRows[index].sub)
                    .font(.cadenceCaption)
                    .foregroundStyle(Color.cadenceTextTertiary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(.cadencePrimary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trackerNotificationRows[index].title): \(trackerNotificationRows[index].sub)")
        .accessibilityValue(binding.wrappedValue ? "On" : "Off")
    }

    @ViewBuilder
    private var errorBanner: some View {
        if case let .failed(message) = viewModel.commitState {
            HStack(spacing: CadenceSpacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.cadenceError)
                Text(message)
                    .font(.cadenceCaptionSmall)
                    .foregroundStyle(Color.cadenceError)
            }
            .padding(10)
            .background(Color.cadenceBgWarm)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.sm)
                    .stroke(Color.cadenceError.opacity(0.4), lineWidth: 0.5)
            )
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.bottom, CadenceSpacing.sm)
        }
    }

    private var isLoading: Bool {
        viewModel.commitState == .loading
    }

    private var enterCadenceButton: some View {
        Button {
            Task { await requestNotificationsAndCommit() }
        } label: {
            Text(ctaLabel)
                .opacity(isLoading ? 0 : 1)
                .overlay {
                    if isLoading { ProgressView().tint(.white) }
                }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
        .disabled(isLoading)
    }

    private var ctaLabel: String {
        if case .failed = viewModel.commitState {
            return "Try again"
        }
        return "Enter Cadence"
    }

    private func requestNotificationsAndCommit() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await viewModel.commitOnboarding()
    }
}
