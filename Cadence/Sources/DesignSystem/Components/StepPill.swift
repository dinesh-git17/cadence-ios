import SwiftUI

struct StepPill: View {
    enum Variant {
        case required
        case optional
    }

    let label: String
    let variant: Variant

    private var textColor: Color {
        switch variant {
            case .required: .cadenceTextOnLight
            case .optional: .cadenceTextTertiary
        }
    }

    private var backgroundColor: Color {
        switch variant {
            case .required: .cadencePrimaryFaint
            case .optional: .cadenceBgTinted
        }
    }

    private var borderColor: Color {
        switch variant {
            case .required: .cadenceBorderDefault
            case .optional: .cadenceBorderStrong
        }
    }

    var body: some View {
        Text(label)
            .font(.cadenceCaptionSmall)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 0.5))
            .accessibilityLabel("Step indicator: \(label)")
    }
}
