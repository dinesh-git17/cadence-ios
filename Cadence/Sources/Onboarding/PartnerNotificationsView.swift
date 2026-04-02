import SwiftUI
import UserNotifications

private let partnerNotificationRows: [NotificationRowData] = [
    .init(icon: "heart", title: "Partner activity", sub: "When your partner logs their day"),
    .init(icon: "calendar", title: "Upcoming phase", sub: "Heads up before a cycle phase change"),
]

struct PartnerNotificationsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            titleSection
            toggleList
            Spacer()
            errorBanner
            enterCadenceButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 3, currentStep: 2)
            StepPill(label: "Step 3 of 3", variant: .required)
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
            notificationRow(index: 0, binding: $viewModel.notifyPartnerActivity)
            notificationRow(index: 1, binding: $viewModel.notifyPhaseChange)
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
            if index < partnerNotificationRows.count - 1 {
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
                Image(systemName: partnerNotificationRows[index].icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cadencePrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(partnerNotificationRows[index].title)
                    .font(.cadenceBodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cadenceTextPrimary)
                Text(partnerNotificationRows[index].sub)
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
        .accessibilityLabel("\(partnerNotificationRows[index].title): \(partnerNotificationRows[index].sub)")
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

    private var enterCadenceButton: some View {
        Button(ctaLabel) {
            Task { await requestNotificationsAndCommit() }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
        .disabled(viewModel.commitState == .loading)
        .overlay(alignment: .center) {
            if viewModel.commitState == .loading {
                ProgressView().tint(.white)
            }
        }
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
