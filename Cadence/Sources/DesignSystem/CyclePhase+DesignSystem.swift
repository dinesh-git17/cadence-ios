import SwiftUI

extension CyclePhase {
    /// Colour used for the 3pt calendar phase strip below each date cell.
    /// Follicular returns .clear — no strip is rendered.
    var stripColor: Color {
        switch self {
            case .menstrual: .cadencePrimary
            case .ovulation: .cadencePrimaryDark
            case .luteal: .cadencePhaseLuteal
            case .follicular: .clear
        }
    }

    /// Plain-language description shown to the partner in the phase explanation card.
    var partnerExplanation: String {
        switch self {
            case .menstrual:
                "This is the start of a new cycle. Energy may be lower and comfort matters more right now."
            case .follicular:
                "Energy is starting to build after the period ends. Things tend to feel more open and social."
            case .ovulation:
                "Energy is typically highest during ovulation. This phase often feels outgoing and confident."
            case .luteal:
                "The body is preparing for the next cycle. Energy may dip toward the end of this phase."
        }
    }
}
