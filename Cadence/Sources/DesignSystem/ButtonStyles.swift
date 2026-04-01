import SwiftUI

// MARK: - Primary Button Style

/// Full-width coral button. One per screen. Used for the single primary action.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cadenceBodySmall)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, CadenceSpacing.xl)
            .background(
                configuration.isPressed
                    ? Color.cadencePrimaryDark
                    : Color.cadencePrimary
            )
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.97 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Ghost Button Style

/// Full-width white/tinted button with a light border. Secondary action.
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cadenceBodySmall)
            .fontWeight(.medium)
            .foregroundColor(.cadencePrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, CadenceSpacing.xl)
            .background(Color.cadenceBgTinted)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.lg)
                    .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.97 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Destructive Text Button Style

/// Inline text-only button in error red. For irreversible actions only.
struct DestructiveTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cadenceCaption)
            .fontWeight(.medium)
            .foregroundColor(.cadenceError)
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
