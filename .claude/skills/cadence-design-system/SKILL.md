---
name: cadence-design-system
description: >
  Cadence iOS app design system implementation guide. Use this skill BEFORE
  implementing ANY SwiftUI screen, component, or visual element in the Cadence
  project. Covers colour tokens, typography, spacing, corner radius, reusable
  components, button styles, and phase colour mapping. Trigger whenever writing
  SwiftUI code for Cadence screens, building new components, adding colours or
  fonts, implementing the calendar, log sheet, partner view, onboarding, or any
  other UI work in this project. Do not write a single hex value or font name
  from memory — always read this skill first.
---

# Cadence Design System

Read this file **in full** before writing any SwiftUI code in the Cadence project.
Then load the specific reference files you need for the task at hand.

---

## Reference Files — Load Before Coding

| File                          | Load when…                                              |
| ----------------------------- | ------------------------------------------------------- |
| `references/tokens.md`        | Implementing colours, spacing, radius, or phase colours |
| `references/typography.md`    | Adding text, registering fonts, building type hierarchy |
| `references/components.md`    | Implementing any of the 11 reusable components          |
| `references/button-styles.md` | Implementing buttons or any tappable CTA                |

Always load the relevant reference file(s) before writing implementation code.
Never write token values, font names, or component structure from memory.

---

## The Non-Negotiable Rules

Violating these will produce a UI that does not match Cadence's design intent.
Check each one before committing any UI code.

### Colour

- **Never write a hex value inline.** Every colour must come from `Color.cadence*`.
  Define new tokens in `Color+Cadence.swift` if a colour isn't already there.
- **Coral (`cadencePrimary`) is earned.** It appears on: primary CTAs, active tab icons,
  the hero card background, selected chip/button states, today's calendar circle, and
  phase strips. It does not appear on section backgrounds, body text, or decorative borders.
- **No drop shadows, ever.** Elevation is communicated through background colour contrast
  and 0.5pt border strokes. `shadow()` is banned.
- **`cadenceSurfaceDark` (#1A0F0E) is used in exactly one place:** the partner hero card
  background. Nowhere else.
- **`cadencePrimaryFaint` is for hover/section tints.** Not cards, not backgrounds.

### Typography

- **Never call `Font.system(...)` for Cadence UI.** All text uses either
  `Font.cadence*` (see `references/typography.md`) or the precise custom font names
  `"PlayfairDisplay-Regular"`, `"PlayfairDisplay-Italic"`, `"DMSans-Regular"`,
  `"DMSans-Medium"`.
- **One Playfair moment per screen.** Playfair Display appears on the single most
  important element per screen — screen title, cycle day, or welcome headline.
  It never competes with itself on the same screen.
- **Playfair italic appears in one place only:** the word "shared" in the welcome
  headline. Do not use italic elsewhere.
- **Buttons always use DM Sans 13pt weight 500.** This is `cadenceBodySmall` +
  `.fontWeight(.medium)`.
- **Section headers are always:** DM Sans 10pt (`cadenceLabel`), weight 500, uppercase,
  kerning 0.8, `cadenceTextTertiary`. Use `CadenceSectionHeader` — never hand-roll this.

### Spacing & Layout

- **All spacing values come from `CadenceSpacing`.** No magic numbers.
  The scale: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32.
- **Horizontal screen margin is always 16pt (`CadenceSpacing.lg`).**
- **No padding value below 4pt except for internal chip/pill padding.**

### Corner Radius

- **All radius values come from `CadenceRadius`.**
  sm=8, md=10, lg=12, xl=14, xxl=16, full=9999.
- **Hero cards use `xxl` (16pt).** Standard cards use `xl` (14pt). Grouped list
  cards use `lg` (12pt). Chips, pills, and toggles use `full`.
- **Do not invent intermediate values.** If the design calls for 14pt, use
  `CadenceRadius.xl`. If it seems like it needs 15pt, it doesn't — use `xl`.

### Cards & Surfaces

- **Cards on `bg-base` use `bg-warm` background + `border-default` at 0.5pt.**
  No shadow. No backdrop filter. No `.background(.regularMaterial)`.
- **Bottom sheets use `bg-base` with a handle bar.** Never `.ultraThinMaterial`
  or any iOS material effect on Cadence sheets.
- **Do not wrap every piece of content in a card.** Cards group related content.
  Individual items that belong to a list go inside `CadenceGroupedCard` as rows.

### Icons

- **Phosphor Icons (PhosphorSwift) only.** Regular weight only (2px stroke).
  Never use Bold or Thin Phosphor icons. Never mix SF Symbols with Phosphor.
- **List row icons sit inside a `CadenceIconTile`.** Raw icons floating in list
  rows without a tinted background tile are wrong.
- **Tab bar icons:** active = `cadencePrimary`, inactive = `cadenceTextTertiary`.

### Motion

- **Spring animations only for state transitions** (chip select, button press,
  progress dots, toggles). Duration: 0.15–0.30s range.
- **Crossfade (0.15–0.20s) for background colour changes** (hero card pill update,
  chip background swap).
- **Respect `UIAccessibility.isReduceMotionEnabled`:** replace scale animations
  with opacity crossfades when active.

---

## What NOT to Do — Common Mistakes

```swift
// ❌ WRONG: Inline hex value
.background(Color(hex: "#F88379"))

// ✅ CORRECT: Named token
.background(Color.cadencePrimary)

// ❌ WRONG: System font
Text("Day 14").font(.system(size: 32, weight: .regular, design: .serif))

// ✅ CORRECT: Named scale
Text("Day 14").font(.cadenceDisplay)

// ❌ WRONG: Drop shadow
.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

// ✅ CORRECT: Border stroke for elevation
.overlay(RoundedRectangle(cornerRadius: CadenceRadius.xl)
    .stroke(Color.cadenceBorderDefault, lineWidth: 0.5))

// ❌ WRONG: Coral on body text
Text("How are you feeling today?")
    .foregroundColor(.cadencePrimary)

// ✅ CORRECT: Secondary text for body copy
Text("How are you feeling today?")
    .foregroundColor(.cadenceTextSecondary)

// ❌ WRONG: Magic spacing number
.padding(.vertical, 14)

// ✅ CORRECT: Token
.padding(.vertical, CadenceSpacing.md) // 12pt

// ❌ WRONG: cadenceSurfaceDark used outside partner hero card
.background(Color.cadenceSurfaceDark)  // on settings card or any other surface

// ✅ CORRECT: cadenceSurfaceDark only on CadencePartnerHeroCard background

// ❌ WRONG: Arbitrary corner radius
.cornerRadius(15)

// ✅ CORRECT: Token
.clipShape(RoundedRectangle(cornerRadius: CadenceRadius.xl)) // 14pt
```

---

## Component Catalog — At a Glance

Read `references/components.md` for full implementations. This table is a quick
reference for which component to reach for.

| Component                                  | Use for                                                    |
| ------------------------------------------ | ---------------------------------------------------------- |
| `CadenceHeroCard`                          | Today screen — tracker's cycle day, phase, logged state    |
| `CadencePartnerHeroCard`                   | Partner tab — partner's cycle data on dark background      |
| `CadenceChip`                              | Multi-select mood and symptom selection                    |
| `CadenceFlowRow`                           | Period flow selection (None/Spotting/Light/Medium/Heavy)   |
| `CadenceEnergyRow`                         | Energy level selection (Low/Medium/High)                   |
| `CadenceToggleRow`                         | Sharing preferences, notification settings rows            |
| `CadenceGroupedCard` + `CadenceGroupedRow` | Any grouped list card (settings, sharing)                  |
| `CadenceIconTile`                          | Icon in tinted background square (list rows, log rows)     |
| `CadenceProgressDots`                      | Onboarding step indicator with animated active pill        |
| `CadenceSectionHeader`                     | Section labels above card groups                           |
| `CadenceAvatarCircle`                      | Initials circle in nav bar (30pt) or profile header (48pt) |

---

## Phase Colour Mapping — At a Glance

Read `references/tokens.md` for the full `CyclePhase` enum and Swift code.

| Phase          | Strip Colour | Token                 |
| -------------- | ------------ | --------------------- |
| Period         | `#F88379`    | `cadencePrimary`      |
| Ovulation      | `#E37383`    | `cadencePrimaryDark`  |
| Fertile window | `#FDDBD8`    | `cadencePrimaryLight` |
| Luteal         | `#F0E8E0`    | `cadencePhaseLuteal`  |
| Follicular     | `clear`      | —                     |

---

## Colour Token Quick Reference

Read `references/tokens.md` for the complete Swift extension. Summary:

| Role                         | Token                  | Hex       |
| ---------------------------- | ---------------------- | --------- |
| Primary                      | `cadencePrimary`       | `#F88379` |
| Primary dark/pressed         | `cadencePrimaryDark`   | `#E37383` |
| Primary light (chips, tiles) | `cadencePrimaryLight`  | `#FDDBD8` |
| Primary faint (hover)        | `cadencePrimaryFaint`  | `#FEF2F1` |
| App background               | `cadenceBgBase`        | `#FFFFFF` |
| Cards, sheets                | `cadenceBgWarm`        | `#FEF9F8` |
| Grouped sections, pickers    | `cadenceBgTinted`      | `#FEF6F5` |
| Primary text                 | `cadenceTextPrimary`   | `#1A0F0E` |
| Secondary text               | `cadenceTextSecondary` | `#7A5250` |
| Tertiary text, hints         | `cadenceTextTertiary`  | `#B89490` |
| Text on primary-light bg     | `cadenceTextOnLight`   | `#C05A52` |
| Default border               | `cadenceBorderDefault` | `#F2DDD8` |
| Strong border                | `cadenceBorderStrong`  | `#E8C8C4` |
| Success                      | `cadenceSuccess`       | `#4CAF7D` |
| Warning                      | `cadenceWarning`       | `#F5A623` |
| Error/destructive            | `cadenceError`         | `#E74C3C` |
| Partner hero card bg         | `cadenceSurfaceDark`   | `#1A0F0E` |
| Luteal calendar strip        | `cadencePhaseLuteal`   | `#F0E8E0` |

---

## File Placement Convention

```
Cadence/
├── DesignSystem/
│   ├── Color+Cadence.swift       ← cadence* Color tokens + hex init
│   ├── Font+Cadence.swift        ← cadence* Font scale
│   ├── CadenceTokens.swift       ← CadenceSpacing + CadenceRadius enums
│   ├── CyclePhase.swift          ← CyclePhase enum + stripColor + displayName
│   └── Components/
│       ├── CadenceHeroCard.swift
│       ├── CadencePartnerHeroCard.swift
│       ├── CadenceChip.swift
│       ├── CadenceFlowRow.swift
│       ├── CadenceEnergyRow.swift
│       ├── CadenceToggleRow.swift
│       ├── CadenceGroupedCard.swift
│       ├── CadenceIconTile.swift
│       ├── CadenceProgressDots.swift
│       ├── CadenceSectionHeader.swift
│       └── CadenceAvatarCircle.swift
```

Button styles live with the component that uses them unless shared widely —
in which case create `DesignSystem/ButtonStyles.swift`.

---

## Accessibility Checklist

Before marking any screen complete, verify:

- [ ] All interactive elements have a minimum 44×44pt tap target
- [ ] All icons have `.accessibilityLabel(_:)`
- [ ] All toggles announce state: `.accessibilityValue(isOn ? "On" : "Off")`
- [ ] Coral `#F88379` on white `#FFFFFF` has a contrast ratio of 2.9:1 — only
      use for decorative elements or text ≥18pt. Never for body copy.
- [ ] `@Environment(\.accessibilityReduceMotion)` is respected: swap scale
      animations for `.animation(.easeInOut(duration: 0.2))` opacity changes
- [ ] Dynamic Type: DM Sans text scales with environment. Playfair Display
      headings are fixed size (too decorative to scale).
