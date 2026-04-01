# Cadence Button Styles — Swift Reference

**File:** `Cadence/DesignSystem/ButtonStyles.swift`

Three button styles cover every CTA in the app. Pick the right one by intent:

| Style | Intent | Example usage |
|---|---|---|
| `PrimaryButtonStyle` | Primary action — one per screen | "Save log", "Enter Cadence", "Send invite link" |
| `GhostButtonStyle` | Secondary action | "Continue with Email", secondary onboarding options |
| `DestructiveTextButtonStyle` | Irreversible action | "Disconnect", "Sign out" |

There is no "medium" or "tertiary" button style. Skip / text-only CTAs ("Skip for now")
are plain `Button` views with `cadenceBodySmall` font and `cadenceTextSecondary` colour —
they do not get a button style.

---

## ButtonStyles.swift

```swift
import SwiftUI

// MARK: - Primary Button Style

/// Full-width coral button. One per screen. Used for the single primary action.
///
///     Button("Save log") { savelog() }
///         .buttonStyle(PrimaryButtonStyle())
///
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
///
///     Button("Continue with Email") { showEmailAuth() }
///         .buttonStyle(GhostButtonStyle())
///
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
/// Does NOT have a background or border — it sits inline in a list row or settings card.
///
///     Button("Disconnect") { disconnect() }
///         .buttonStyle(DestructiveTextButtonStyle())
///
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
```

---

## Apple Sign-In Button

The "Continue with Apple" button is a special case. Use `SignInWithAppleButton` from
`AuthenticationServices` — do not build it manually with `PrimaryButtonStyle`.

```swift
import AuthenticationServices
import SwiftUI

SignInWithAppleButton(.continue) { request in
    // configure request
} onCompletion: { result in
    // handle result
}
.frame(maxWidth: .infinity)
.frame(height: 44) // standard Apple button height
.clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
// Note: the Apple button handles its own dark background + Apple logo.
// Do not apply PrimaryButtonStyle here.
```

---

## Skip / Text-Only CTA

The "Skip for now" pattern on the optional invite step is NOT a named button style.
Build it inline:

```swift
Button("Skip for now") {
    skipAction()
}
.font(.cadenceBodySmall)
.foregroundColor(.cadenceTextSecondary)
// No frame, no background, no border — just the text
```

---

## Disabled State

All button styles check `@Environment(\.isEnabled)` and apply 50% opacity when disabled.
Set the disabled state via SwiftUI's standard `.disabled(condition)` modifier — never
change the button's colour manually to indicate disabled state.

```swift
Button("Continue") { advance() }
    .buttonStyle(PrimaryButtonStyle())
    .disabled(!formIsValid) // ✅ correct approach
```
