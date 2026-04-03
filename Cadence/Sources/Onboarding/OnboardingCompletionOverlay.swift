import SwiftUI

struct OnboardingCompletionOverlay: View {
    var body: some View {
        VStack(spacing: CadenceSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.cadenceSuccess)

            Text("You're all set")
                .font(.cadenceTitleMedium)
                .foregroundStyle(Color.cadenceTextPrimary)

            Text("Welcome to Cadence")
                .font(.cadenceBody)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cadenceBgBase)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            NotificationCenter.default.post(name: .onboardingDidComplete, object: nil)
        }
    }
}
