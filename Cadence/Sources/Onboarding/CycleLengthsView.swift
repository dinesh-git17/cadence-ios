import SwiftUI

struct CycleLengthsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showCyclePicker = false
    @State private var showDurationPicker = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingBackButton()
            progressHeader
            titleSection
            pickerRows
            helperTip
            Spacer()
            continueButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
        .sheet(isPresented: $showCyclePicker) {
            WheelPickerSheet(
                title: "Cycle length",
                range: 21 ... 45,
                selection: $viewModel.cycleLength,
                unit: "days"
            )
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showDurationPicker) {
            WheelPickerSheet(
                title: "Period duration",
                range: 2 ... 10,
                selection: $viewModel.periodDuration,
                unit: "days"
            )
            .presentationDetents([.height(280)])
        }
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 6, currentStep: 2)
            StepPill(label: "Step 3 of 6", variant: .required)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    private var titleSection: some View {
        Text("About your cycle")
            .font(.cadenceTitleMedium)
            .foregroundStyle(Color.cadenceTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.top, CadenceSpacing.xxl)
    }

    private var pickerRows: some View {
        VStack(spacing: CadenceSpacing.sm) {
            PickerRow(
                label: "Cycle length",
                value: "\(viewModel.cycleLength) days"
            ) {
                showCyclePicker = true
            }
            PickerRow(
                label: "Period duration",
                value: "\(viewModel.periodDuration) days"
            ) {
                showDurationPicker = true
            }
        }
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xl)
    }

    private var helperTip: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(Color.cadenceTextTertiary)
            Text("Not sure? Use the defaults — they self-correct as you log.")
                .font(.cadenceCaption)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .padding(CadenceSpacing.sm)
        .background(Color.cadenceBgTinted)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.sm))
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.sm)
    }

    private var continueButton: some View {
        Button("Continue") {
            viewModel.path.append(OnboardingRoute.sharingPreferences)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
    }
}
