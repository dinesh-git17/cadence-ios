# Cadence Tokens — Swift Reference

Copy these files into `Cadence/DesignSystem/` as separate `.swift` files.
Do not modify the token values — they are sourced directly from the design spec.

---

## Color+Cadence.swift

```swift
import SwiftUI

extension Color {
    // MARK: - Primary Scale
    /// CTA backgrounds, active tab icons, hero card background, selected states
    static let cadencePrimary      = Color(cadenceHex: "#F88379")
    /// Pressed state on primary buttons, ovulation phase strip
    static let cadencePrimaryDark  = Color(cadenceHex: "#E37383")
    /// Icon tile backgrounds, selected chip fills, tag fills
    static let cadencePrimaryLight = Color(cadenceHex: "#FDDBD8")
    /// Hover backgrounds, step pill backgrounds, subtle section tints
    static let cadencePrimaryFaint = Color(cadenceHex: "#FEF2F1")

    // MARK: - Backgrounds
    /// App root background, screen root — never use .white
    static let cadenceBgBase       = Color(cadenceHex: "#FFFFFF")
    /// Cards, bottom sheets, list group backgrounds
    static let cadenceBgWarm       = Color(cadenceHex: "#FEF9F8")
    /// Grouped sections, picker rows, phase explanation cards
    static let cadenceBgTinted     = Color(cadenceHex: "#FEF6F5")

    // MARK: - Text
    /// Headings, body copy, list titles — all primary readable text
    static let cadenceTextPrimary   = Color(cadenceHex: "#1A0F0E")
    /// Subtitles, supporting copy, list subtitles, form labels
    static let cadenceTextSecondary = Color(cadenceHex: "#7A5250")
    /// Hints, placeholders, inactive tab labels, muted dates
    static let cadenceTextTertiary  = Color(cadenceHex: "#B89490")
    /// Text sitting on cadencePrimaryLight backgrounds (chips, tiles, avatars)
    static let cadenceTextOnLight   = Color(cadenceHex: "#C05A52")

    // MARK: - Borders
    /// Cards, inputs, list row separators, calendar cell separators
    static let cadenceBorderDefault = Color(cadenceHex: "#F2DDD8")
    /// Dividers, toggle track off state
    static let cadenceBorderStrong  = Color(cadenceHex: "#E8C8C4")

    // MARK: - Utility
    static let cadenceSuccess = Color(cadenceHex: "#4CAF7D")
    static let cadenceWarning = Color(cadenceHex: "#F5A623")
    /// Destructive actions: disconnect, sign out, delete, error states
    static let cadenceError   = Color(cadenceHex: "#E74C3C")

    // MARK: - Special Surfaces
    /// Partner hero card background ONLY. Used nowhere else in the app.
    static let cadenceSurfaceDark  = Color(cadenceHex: "#1A0F0E")
    /// Luteal phase strip on the calendar grid
    static let cadencePhaseLuteal  = Color(cadenceHex: "#F0E8E0")
}

// MARK: - Hex Initialiser (internal use only — always call via cadence* tokens)
private extension Color {
    init(cadenceHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

---

## CadenceTokens.swift

```swift
import CoreGraphics

// MARK: - Spacing

/// 8pt base grid. All values are multiples of 4pt or 8pt.
enum CadenceSpacing {
    /// 4pt — tight internal gaps (chip gaps, icon-to-label)
    static let xs:  CGFloat = 4
    /// 8pt — row internal padding, small gaps
    static let sm:  CGFloat = 8
    /// 12pt — standard row vertical padding, card internal gaps
    static let md:  CGFloat = 12
    /// 16pt — screen horizontal margins, card padding, section gaps
    static let lg:  CGFloat = 16
    /// 24pt — between major sections
    static let xl:  CGFloat = 24
    /// 32pt — large vertical gaps, top padding on screens
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius

enum CadenceRadius {
    /// 8pt — icon tiles, chips, pills, flow/energy buttons
    static let sm:   CGFloat = 8
    /// 10pt — picker rows, insight cards, day summary cards
    static let md:   CGFloat = 10
    /// 12pt — settings groups, sharing cards, log entry cards
    static let lg:   CGFloat = 12
    /// 14pt — primary content cards (log card, partner activity card)
    static let xl:   CGFloat = 14
    /// 16pt — hero cards (Today hero, Partner hero)
    static let xxl:  CGFloat = 16
    /// 9999pt — pills, tags, toggles, avatar circles, capsule shapes
    static let full: CGFloat = 9999
}
```

---

## CyclePhase.swift

```swift
import SwiftUI

enum CyclePhase: String, CaseIterable {
    case period      = "Period"
    case ovulation   = "Ovulation"
    case fertile     = "Fertile Window"
    case luteal      = "Luteal"
    case follicular  = "Follicular"
}

extension CyclePhase {
    /// Colour used for the 3pt calendar phase strip below each date cell.
    /// Follicular returns .clear — no strip is rendered.
    var stripColor: Color {
        switch self {
        case .period:      return .cadencePrimary      // #F88379
        case .ovulation:   return .cadencePrimaryDark  // #E37383
        case .fertile:     return .cadencePrimaryLight // #FDDBD8
        case .luteal:      return .cadencePhaseLuteal  // #F0E8E0
        case .follicular:  return .clear
        }
    }

    /// Human-readable label for the phase explanation card and calendar legend.
    var displayName: String { rawValue }

    /// Short contextual description shown to the partner in the phase explanation card.
    /// Keep copy warm and plain-language — never clinical.
    var partnerExplanation: String {
        switch self {
        case .period:
            return "This is the start of a new cycle. Energy may be lower and comfort matters more right now."
        case .follicular:
            return "Energy is starting to build after the period ends. Things tend to feel more open and social."
        case .ovulation:
            return "Energy is typically at its highest during ovulation. This phase often feels more outgoing and confident."
        case .fertile:
            return "The fertile window surrounds ovulation. Energy and mood are often elevated during this time."
        case .luteal:
            return "The body is preparing for the next cycle. Energy may dip toward the end of this phase."
        }
    }
}
```
