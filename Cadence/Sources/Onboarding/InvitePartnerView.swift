import SwiftUI

struct InvitePartnerView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var inviteURL: URL?
    @State private var isGenerating = false

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            Spacer()
            illustration
            inviteCopy
            shareAction
            Spacer()
            skipButton
            continueButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
        .task { await generateLocalToken() }
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 6, currentStep: 4)
            StepPill(label: "Optional", variant: .optional)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(Color.cadencePrimaryFaint)
                .frame(width: 80, height: 80)
            Circle()
                .fill(Color.cadencePrimaryLight)
                .frame(width: 48, height: 48)
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.cadencePrimary)
        }
    }

    private var inviteCopy: some View {
        VStack(spacing: CadenceSpacing.sm) {
            Text("Invite your partner")
                .font(.cadenceTitleMedium)
                .foregroundStyle(Color.cadenceTextPrimary)
                .multilineTextAlignment(.center)
            Text("Share your cycle with someone who cares —\non your terms.")
                .font(.cadenceBody)
                .foregroundStyle(Color.cadenceTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var shareAction: some View {
        if let url = inviteURL {
            ShareLink(
                item: url,
                message: Text("Join me on Cadence")
            ) {
                Label("Send invite link", systemImage: "square.and.arrow.up")
                    .font(.cadenceBodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cadencePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
            }
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.top, CadenceSpacing.xl)
        } else if isGenerating {
            ProgressView()
                .tint(Color.cadencePrimary)
                .padding(.top, CadenceSpacing.xl)
        }
    }

    private var skipButton: some View {
        Button("Skip for now") {
            viewModel.path.append(OnboardingRoute.notifications)
        }
        .font(.cadenceCaption)
        .foregroundStyle(Color.cadenceTextSecondary)
        .padding(.bottom, CadenceSpacing.md)
    }

    private var continueButton: some View {
        Button("Continue") {
            viewModel.path.append(OnboardingRoute.notifications)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
    }

    private func generateLocalToken() async {
        isGenerating = true
        let token = UUID().uuidString
        viewModel.pendingInviteToken = token
        inviteURL = URL(string: "https://cadence.dineshd.dev/invite/\(token)")
        isGenerating = false
    }
}
