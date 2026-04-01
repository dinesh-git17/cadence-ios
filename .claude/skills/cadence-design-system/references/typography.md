# Cadence Typography — Swift Reference

---

## Step 1 — Add Font Files to the Bundle

1. Download from Google Fonts:
   - **Playfair Display**: download the variable font or static files.
     Required weights: Regular (400), Italic (400 italic).
     File names in bundle: `PlayfairDisplay-Regular.ttf`, `PlayfairDisplay-Italic.ttf`
   - **DM Sans**: Required weights: Regular (400), Medium (500).
     File names in bundle: `DMSans-Regular.ttf`, `DMSans-Medium.ttf`

2. In Xcode, drag the four `.ttf` files into the project navigator.
   In the "Add to targets" dialog, check your app target.

3. Verify each file is listed under **Target → Build Phases → Copy Bundle Resources**.

---

## Step 2 — Declare in Info.plist

Add the key `UIAppFonts` (shown as "Fonts provided by application" in the plist editor)
as an Array with four String entries:

```xml
<key>UIAppFonts</key>
<array>
    <string>PlayfairDisplay-Regular.ttf</string>
    <string>PlayfairDisplay-Italic.ttf</string>
    <string>DMSans-Regular.ttf</string>
    <string>DMSans-Medium.ttf</string>
</array>
```

---

## Step 3 — Verify PostScript Names

If fonts fail to load, the PostScript name may differ from the file name.
Run this in a debug view to list registered font names and confirm:

```swift
// Temporary debug — remove before shipping
struct FontDebugView: View {
    var body: some View {
        List(UIFont.familyNames.sorted(), id: \.self) { family in
            Section(family) {
                ForEach(UIFont.fontNames(forFamilyName: family), id: \.self) { name in
                    Text(name).font(.system(size: 12))
                }
            }
        }
    }
}
```

Look for entries under "Playfair Display" and "DM Sans". Use the exact strings
you see there in `Font.custom(...)` calls below.

---

## Font+Cadence.swift

```swift
import SwiftUI

extension Font {
    // MARK: - Playfair Display

    /// 32pt — Cycle day number on the Today hero card. The single largest text in the app.
    static let cadenceDisplay = Font.custom("PlayfairDisplay-Regular", size: 32)

    /// 22pt — Screen titles: Today, Calendar, Partner, Profile nav bar titles.
    static let cadenceTitleLarge = Font.custom("PlayfairDisplay-Regular", size: 22)

    /// 20pt — Section titles on onboarding, sheet headings, card group titles.
    static let cadenceTitleMedium = Font.custom("PlayfairDisplay-Regular", size: 20)

    /// 18pt — Bottom sheet titles, card headings, date display on onboarding step 2.
    static let cadenceTitleSmall = Font.custom("PlayfairDisplay-Regular", size: 18)

    /// Italic 32pt — Used in EXACTLY ONE PLACE: the word "shared" in the welcome headline.
    /// Do not use for any other purpose.
    static let cadenceTitleItalic = Font.custom("PlayfairDisplay-Italic", size: 32)

    // MARK: - DM Sans

    /// 15pt regular — Standard body copy.
    static let cadenceBody = Font.custom("DMSans-Regular", size: 15)

    /// 14pt regular — List row primary text, card body copy.
    static let cadenceBodyMedium = Font.custom("DMSans-Regular", size: 14)

    /// 13pt regular — Supporting text, sub-labels, button labels.
    /// Buttons pair this with .fontWeight(.medium) explicitly.
    static let cadenceBodySmall = Font.custom("DMSans-Regular", size: 13)

    /// 12pt regular — Card subtitles, timestamps.
    static let cadenceCaption = Font.custom("DMSans-Regular", size: 12)

    /// 11pt regular — Hints, placeholder text, footer links.
    static let cadenceCaptionSmall = Font.custom("DMSans-Regular", size: 11)

    /// 10pt medium — Section headers (used with .uppercased() and kerning(0.8)).
    /// Always rendered via CadenceSectionHeader — do not call this directly for section headers.
    static let cadenceLabel = Font.custom("DMSans-Medium", size: 10)

    /// 9pt regular — Tab bar labels, calendar day-of-week headers.
    static let cadenceMicro = Font.custom("DMSans-Regular", size: 9)
}
```

---

## Typography Rules — Enforcement

These rules must hold on every screen.

**One serif moment per screen.**
Playfair Display appears on the single most important element — the screen title,
the cycle day number, or the welcome headline. It never appears twice at similar
visual weight on the same screen.

**Buttons are always `cadenceBodySmall` + `.fontWeight(.medium)`.**

```swift
// ✅ Correct button label typography
Text("Save log")
    .font(.cadenceBodySmall)
    .fontWeight(.medium)
```

**Tab bar labels are always `cadenceMicro`.**

**Section headers are always rendered via `CadenceSectionHeader`.**
Never construct the uppercase DM Sans 10pt label manually.

**Dynamic Type behaviour:**
- DM Sans text should support Dynamic Type where the layout allows.
  Use `.font(.cadenceBodyMedium)` (etc.) and let SwiftUI handle scaling.
- Playfair Display headings are fixed size — they are display/decorative and
  do not scale with Dynamic Type.

**Contrast reminder:**
Coral `#F88379` on white `#FFFFFF` achieves 2.9:1 contrast — below WCAG AA for body text.
Never put `cadencePrimary` on body copy or any text smaller than 18pt.
