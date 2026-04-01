import SwiftUI

extension Font {
    // MARK: - Playfair Display

    /// 32pt — Cycle day number on the Today hero card.
    static let cadenceDisplay = Font.custom("PlayfairDisplay-Regular", size: 32)

    /// 22pt — Screen titles: Today, Calendar, Partner, Profile.
    static let cadenceTitleLarge = Font.custom("PlayfairDisplay-Regular", size: 22)

    /// 20pt — Section titles on onboarding, sheet headings.
    static let cadenceTitleMedium = Font.custom("PlayfairDisplay-Regular", size: 20)

    /// 18pt — Bottom sheet titles, card headings.
    static let cadenceTitleSmall = Font.custom("PlayfairDisplay-Regular", size: 18)

    /// Italic 22pt — Used only for the word "shared" in the welcome headline.
    static let cadenceTitleItalic = Font.custom("PlayfairDisplay-Italic", size: 22)

    // MARK: - DM Sans

    /// 15pt regular — Standard body copy.
    static let cadenceBody = Font.custom("DMSans-Regular", size: 15)

    /// 14pt regular — List row primary text, card body copy.
    static let cadenceBodyMedium = Font.custom("DMSans-Regular", size: 14)

    /// 13pt regular — Supporting text, sub-labels, button labels.
    static let cadenceBodySmall = Font.custom("DMSans-Regular", size: 13)

    /// 12pt regular — Card subtitles, timestamps.
    static let cadenceCaption = Font.custom("DMSans-Regular", size: 12)

    /// 11pt regular — Hints, placeholder text, footer links.
    static let cadenceCaptionSmall = Font.custom("DMSans-Regular", size: 11)

    /// 10pt medium — Section headers (via CadenceSectionHeader only).
    static let cadenceLabel = Font.custom("DMSans-Medium", size: 10)

    /// 9pt regular — Tab bar labels, calendar day-of-week headers.
    static let cadenceMicro = Font.custom("DMSans-Regular", size: 9)
}
