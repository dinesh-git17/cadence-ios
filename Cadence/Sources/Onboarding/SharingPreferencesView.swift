import SwiftUI

struct SharingPreferencesView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let categories: [(label: String, sublabel: String)] = [
        ("Period", "Flow and dates"),
        ("Mood", "How you're feeling"),
        ("Symptoms", "Cramps, headaches, and more"),
        ("Energy", "Low, medium, or high"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            titleSection
            toggleList
            Spacer()
            continueButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 6, currentStep: 3)
            StepPill(label: "Step 4 of 6", variant: .required)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What would you like\nto share?")
                .font(.cadenceTitleMedium)
                .foregroundStyle(Color.cadenceTextPrimary)
            Text("All off by default. You can change this anytime.")
                .font(.cadenceBody)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xxl)
    }

    private var toggleList: some View {
        VStack(spacing: 0) {
            toggleRow(index: 0, binding: $viewModel.sharePeriod)
            toggleRow(index: 1, binding: $viewModel.shareMood)
            toggleRow(index: 2, binding: $viewModel.shareSymptoms)
            toggleRow(index: 3, binding: $viewModel.shareEnergy)
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

    private func toggleRow(index: Int, binding: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(categories[index].label)
                        .font(.cadenceBody)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cadenceTextPrimary)
                    Text(categories[index].sublabel)
                        .font(.cadenceCaption)
                        .foregroundStyle(Color.cadenceTextTertiary)
                }
                Spacer()
                Toggle("", isOn: binding)
                    .labelsHidden()
                    .tint(.cadencePrimary)
            }
            .padding(.vertical, CadenceSpacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(categories[index].label): \(categories[index].sublabel)")
            .accessibilityValue(binding.wrappedValue ? "On" : "Off")

            if index < categories.count - 1 {
                Divider()
                    .background(Color.cadenceBorderDefault)
            }
        }
    }

    private var continueButton: some View {
        Button("Continue") {
            viewModel.path.append(OnboardingRoute.invitePartner)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
    }
}
