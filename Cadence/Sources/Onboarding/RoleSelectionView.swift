import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            titleSection
            roleCards
            Spacer()
            continueButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 6, currentStep: 0)
            StepPill(label: "Step 1 of 6", variant: .required)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Will you be tracking\nyour own cycle?")
                .font(.cadenceTitleMedium)
                .foregroundStyle(Color.cadenceTextPrimary)
            Text("This sets up your experience.")
                .font(.cadenceBody)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xxl)
    }

    private var roleCards: some View {
        VStack(spacing: CadenceSpacing.sm) {
            RoleCard(
                title: "Yes, I track my cycle",
                subtitle: "Log your period, symptoms, moods, and more.",
                isSelected: viewModel.selectedRole == .tracker
            ) {
                viewModel.selectedRole = .tracker
            }

            RoleCard(
                title: "No, I'm a partner",
                subtitle: "Stay informed about your partner's cycle.",
                isSelected: viewModel.selectedRole == .partner
            ) {
                viewModel.selectedRole = .partner
            }
        }
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xl)
        .sensoryFeedback(.selection, trigger: viewModel.selectedRole)
    }

    private var continueButton: some View {
        Button("Continue") {
            if viewModel.selectedRole == .tracker {
                viewModel.path.append(OnboardingRoute.lastPeriodDate)
            } else {
                viewModel.path.append(
                    OnboardingRoute.acceptConnection(inviteToken: viewModel.inviteToken)
                )
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
        .disabled(viewModel.selectedRole == nil)
    }
}
