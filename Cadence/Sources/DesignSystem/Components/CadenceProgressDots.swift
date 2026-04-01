import SwiftUI

struct CadenceProgressDots: View {
    let totalSteps: Int
    /// 0-indexed current step. The dot at this index becomes the active pill.
    let currentStep: Int

    var body: some View {
        HStack(spacing: CadenceSpacing.xs) {
            ForEach(0 ..< totalSteps, id: \.self) { index in
                let isActive = index == currentStep
                RoundedRectangle(cornerRadius: CadenceRadius.full)
                    .fill(isActive ? Color.cadencePrimary : Color.cadenceBorderDefault)
                    .frame(width: isActive ? 16 : 6, height: 6)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: currentStep
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}
