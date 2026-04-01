import SwiftUI

extension Color {
    // MARK: - Primary Scale

    /// CTA backgrounds, active tab icons, hero card background, selected states
    static let cadencePrimary = Color(cadenceHex: "#F88379")
    /// Pressed state on primary buttons, ovulation phase strip
    static let cadencePrimaryDark = Color(cadenceHex: "#E37383")
    /// Icon tile backgrounds, selected chip fills, tag fills
    static let cadencePrimaryLight = Color(cadenceHex: "#FDDBD8")
    /// Hover backgrounds, step pill backgrounds, subtle section tints
    static let cadencePrimaryFaint = Color(cadenceHex: "#FEF2F1")

    // MARK: - Backgrounds

    /// App root background, screen root
    static let cadenceBgBase = Color(cadenceHex: "#FFFFFF")
    /// Cards, bottom sheets, list group backgrounds
    static let cadenceBgWarm = Color(cadenceHex: "#FEF9F8")
    /// Grouped sections, picker rows, phase explanation cards
    static let cadenceBgTinted = Color(cadenceHex: "#FEF6F5")

    // MARK: - Text

    /// Headings, body copy, list titles
    static let cadenceTextPrimary = Color(cadenceHex: "#1A0F0E")
    /// Subtitles, supporting copy, list subtitles, form labels
    static let cadenceTextSecondary = Color(cadenceHex: "#7A5250")
    /// Hints, placeholders, inactive tab labels, muted dates
    static let cadenceTextTertiary = Color(cadenceHex: "#B89490")
    /// Text on cadencePrimaryLight backgrounds (chips, tiles, avatars)
    static let cadenceTextOnLight = Color(cadenceHex: "#C05A52")

    // MARK: - Borders

    /// Cards, inputs, list row separators, calendar cell separators
    static let cadenceBorderDefault = Color(cadenceHex: "#F2DDD8")
    /// Dividers, toggle track off state
    static let cadenceBorderStrong = Color(cadenceHex: "#E8C8C4")

    // MARK: - Utility

    static let cadenceSuccess = Color(cadenceHex: "#4CAF7D")
    static let cadenceWarning = Color(cadenceHex: "#F5A623")
    /// Destructive actions: disconnect, sign out, delete, error states
    static let cadenceError = Color(cadenceHex: "#E74C3C")

    // MARK: - Special Surfaces

    /// Partner hero card background ONLY. Used nowhere else in the app.
    static let cadenceSurfaceDark = Color(cadenceHex: "#1A0F0E")
    /// Luteal phase strip on the calendar grid
    static let cadencePhaseLuteal = Color(cadenceHex: "#F0E8E0")
}

// MARK: - Hex Initialiser (internal use only)

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
