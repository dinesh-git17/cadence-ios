import SwiftUI

struct CadenceSectionHeader: View {
    let title: String
    var actionLabel: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.cadenceLabel)
                .foregroundColor(.cadenceTextTertiary)
                .kerning(0.8)
            Spacer()
            if let label = actionLabel, let action {
                Button(label, action: action)
                    .font(.cadenceCaptionSmall)
                    .foregroundColor(.cadencePrimary)
                    .accessibilityLabel("\(label) \(title)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
