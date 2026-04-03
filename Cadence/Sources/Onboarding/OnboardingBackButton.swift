import PhosphorSwift
import SwiftUI

struct OnboardingBackButton: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        Button {
            viewModel.path.removeLast()
        } label: {
            Ph.caretLeft.regular
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.cadencePrimary)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CadenceSpacing.lg)
        .accessibilityLabel("Back")
    }
}
