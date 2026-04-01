import SwiftUI

struct CadenceToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: CadenceSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cadenceBodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.cadenceTextPrimary)
                Text(subtitle)
                    .font(.cadenceCaptionSmall)
                    .foregroundColor(.cadenceTextTertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.cadencePrimary)
        }
        .padding(.vertical, CadenceSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}
