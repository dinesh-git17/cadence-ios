# Cadence — UI Design Specification
**Version:** 1.0  
**Date:** March 31, 2026  
**Platform:** iOS (SwiftUI)

---

## 1. Design Principles

Before anything else — the rules that govern every decision in this document.

**Warmth through restraint.** The app is warm because of its colour palette and typography, not because of decorative elements. No flowers, no illustrated characters, no confetti. Warmth is in the colours and the copy.

**White space is a feature.** Every screen breathes. Don't fill space because it's there.

**Coral is earned.** The primary colour `#F88379` should feel special. It's used for CTAs, active states, key data points, and the hero card. Not for backgrounds, not for every heading.

**Dark text on white backgrounds, always.** No reversed text except on the coral hero card and the dark partner hero card. Those are the two intentional exceptions.

**One serif moment per screen.** Playfair Display is used for the single most important thing on a screen — the page title, the cycle day, the welcome headline. It doesn't compete with itself.

---

## 2. Colour System

### Primary Scale

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#F88379` | CTAs, active tab icons, hero card background, selected states, today circle |
| `primary-dark` | `#E37383` | Pressed state on buttons, ovulation phase strip |
| `primary-light` | `#FDDBD8` | Icon background tints, chip selected backgrounds, tag fills, illustration circles |
| `primary-faint` | `#FEF2F1` | Hover backgrounds, subtle section tints, step pill backgrounds |

### Backgrounds

| Token | Hex | Usage |
|---|---|---|
| `bg-base` | `#FFFFFF` | App background, screen root |
| `bg-warm` | `#FEF9F8` | Cards, bottom sheets, list group backgrounds |
| `bg-tinted` | `#FEF6F5` | Grouped sections, picker rows, phase explanation cards |

### Text

| Token | Hex | Usage |
|---|---|---|
| `text-primary` | `#1A0F0E` | Headings, body copy, list titles, all primary readable text |
| `text-secondary` | `#7A5250` | Subtitles, supporting copy, list subtitles, form labels |
| `text-tertiary` | `#B89490` | Hints, placeholders, inactive tab labels, section headers (uppercase), muted dates |

### Borders

| Token | Hex | Usage |
|---|---|---|
| `border-default` | `#F2DDD8` | Cards, inputs, list row separators, calendar cell separators |
| `border-strong` | `#E8C8C4` | Dividers, toggle track (off state) |

### Utility

| Token | Hex | Usage |
|---|---|---|
| `success` | `#4CAF7D` | Connection active dot, success states |
| `warning` | `#F5A623` | Alerts, reminders |
| `error` | `#E74C3C` | Destructive actions (disconnect, sign out, delete), error states |

### Special Surfaces

| Token | Hex | Usage |
|---|---|---|
| `surface-dark` | `#1A0F0E` | Partner hero card background only. This is the only dark surface in the app. |
| `phase-luteal` | `#F0E8E0` | Luteal phase strip on calendar |

---

## 3. Typography

### Typefaces

| Font | Source | Import |
|---|---|---|
| Playfair Display | Google Fonts | `https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,500;1,400` |
| DM Sans | Google Fonts | `https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500` |

In SwiftUI: register both as custom fonts via `CTFontManagerRegisterFontsForURL` or add to the bundle and declare in `Info.plist`.

### Type Scale

| Role | Font | Size | Weight | Colour | Usage |
|---|---|---|---|---|---|
| Display | Playfair Display | 32pt | 400 | `text-primary` | Cycle day number on hero card |
| Title Large | Playfair Display | 22pt | 400 | `text-primary` | Screen titles (Today, Calendar, Partner, Profile) |
| Title Medium | Playfair Display | 20pt | 400 | `text-primary` | Section titles, onboarding headings |
| Title Small | Playfair Display | 18pt | 400 | `text-primary` | Sheet titles, card headings |
| Title Italic | Playfair Display | varies | 400 italic | `primary` | Emphasis word in welcome headline only |
| Body | DM Sans | 15pt | 400 | `text-primary` | Standard body copy |
| Body Medium | DM Sans | 14pt | 400 | `text-primary` | List row primary text, card body |
| Body Small | DM Sans | 13pt | 400 | `text-secondary` | Supporting text, sub-labels, button labels |
| Caption | DM Sans | 12pt | 400 | `text-secondary` | Card subtitles, timestamps |
| Caption Small | DM Sans | 11pt | 400 | `text-tertiary` | Hints, placeholder text, footer links |
| Label | DM Sans | 10pt | 500 | `text-tertiary` | Section headers (UPPERCASE + letter-spacing), eyebrow labels |
| Micro | DM Sans | 9pt | 400 | `text-tertiary` | Tab bar labels, calendar day-of-week headers |

### Typography Rules

- Section headers are always DM Sans 10pt, weight 500, uppercase, letter-spacing 0.08em, `text-tertiary`
- Playfair Display italic is used in exactly one place: the word "shared" in the welcome headline. Do not use italic elsewhere.
- Never mix Playfair Display and DM Sans at the same visual weight on the same line.
- Buttons always use DM Sans 13pt weight 500.
- Tab bar labels always use DM Sans 9pt.

---

## 4. Spacing & Layout

### Base Grid

8pt base grid. All spacing values are multiples of 4pt or 8pt.

| Token | Value | Usage |
|---|---|---|
| `space-xs` | 4pt | Tight internal gaps (chip gaps, icon-to-label gaps) |
| `space-sm` | 8pt | Row internal padding, small gaps |
| `space-md` | 12pt | Standard row padding (vertical), card internal gaps |
| `space-lg` | 16pt | Screen horizontal margins, card padding, section gaps |
| `space-xl` | 24pt | Between major sections |
| `space-2xl` | 32pt | Large vertical gaps, top padding on screens |

### Screen Margins

- Horizontal margin: **16pt** from screen edge on all screens
- Cards and grouped sections inset 16pt from both sides
- Tab bar: 8pt internal horizontal padding

### Safe Areas

Respect iOS safe areas. Content should not extend into the home indicator area or behind the Dynamic Island / notch.

---

## 5. Corner Radius

| Token | Value | Usage |
|---|---|---|
| `radius-sm` | 8pt | Icon background tints, chips, pills |
| `radius-md` | 10pt | Picker rows, insight cards, day summary cards |
| `radius-lg` | 12pt | Settings groups, sharing cards, log entry cards |
| `radius-xl` | 14pt | Primary content cards (log card, partner card) |
| `radius-2xl` | 16pt | Hero cards (Today hero, Partner hero) |
| `radius-full` | 9999pt | Pills, tags, toggles, avatar circles, tab active dot |

---

## 6. Shadows & Elevation

No drop shadows anywhere in the app. Elevation is communicated entirely through background colour contrast and border strokes.

- **Cards on `bg-base`:** use `bg-warm` (`#FEF9F8`) + `border-default` (`#F2DDD8`) at 0.5pt
- **Bottom sheets:** use `bg-base` (`#FFFFFF`) with a handle bar
- **No box shadows, no blurs, no backdrop filters**

---

## 7. Icon System

### Library & Weight

- **Library:** Phosphor Icons — PhosphorSwift Swift package
- **Weight:** Regular only (2px stroke, rounded line caps and joins)
- **Do not mix weights.** Never use Bold or Thin Phosphor icons in this app.

### Sizing

| Context | Size |
|---|---|
| Tab bar icons | 22pt × 22pt |
| List row icons (in tinted bg) | 18pt × 18pt |
| Section/card icons | 14pt × 14pt |
| Log sheet section icons | 13pt × 13pt |
| Inline / button icons | 14pt × 14pt |
| Empty state hero icon | 24pt × 24pt |

### Colour Rules

| State | Colour |
|---|---|
| Tab bar — active | `primary` `#F88379` |
| Tab bar — inactive | `text-tertiary` `#B89490` |
| List row icon (on tinted bg) | `primary` `#F88379` |
| On coral hero card | `#FFFFFF` white |
| On dark partner hero card | `#F88379` coral |
| Destructive | `error` `#E74C3C` |

### Icon Background Tint (List Rows)

Icons in list rows sit on a tinted background square:
- Size: 28pt × 28pt (settings) or 30–32pt (log rows)
- Background: `primary-light` `#FDDBD8`
- Corner radius: `radius-sm` 8pt
- Icon centred within

---

## 8. Component Library

### 8.1 Buttons

#### Primary Button
```
Background:     #F88379 (primary)
Text:           #FFFFFF, DM Sans 13pt, weight 500
Corner radius:  12pt
Padding:        12pt vertical, 24pt horizontal (full width = 16pt horizontal margin)
Pressed state:  background #E37383 (primary-dark)
```

#### Secondary / Ghost Button
```
Background:     #FEF6F5 (bg-tinted)
Text:           #F88379 (primary), DM Sans 13pt, weight 500
Border:         0.5pt, #F2DDD8 (border-default)
Corner radius:  12pt
Padding:        12pt vertical
```

#### Destructive Text Button
```
Background:     none
Text:           #E74C3C (error), DM Sans 12pt, weight 500
Used for:       Disconnect, Sign out
```

#### Skip / Text-only CTA
```
Background:     none
Text:           #7A5250 (text-secondary), DM Sans 12pt, weight 400
Used for:       "Skip for now" on invite screen
```

### 8.2 Cards

#### Standard Card
```
Background:     #FEF9F8 (bg-warm)
Border:         0.5pt, #F2DDD8 (border-default)
Corner radius:  14pt (radius-xl)
Padding:        12pt vertical, 14pt horizontal
```

#### Grouped List Card (Settings style)
```
Background:     #FEF9F8 (bg-warm)
Border:         0.5pt, #F2DDD8 (border-default)
Corner radius:  12pt (radius-lg)
Row separator:  0.5pt, #FEF2F1 (primary-faint) — last row has no separator
Row padding:    11pt vertical, 12pt horizontal
```

#### Hero Card — Tracker (Today screen)
```
Background:     #F88379 (primary)
Corner radius:  16pt (radius-2xl)
Padding:        16pt all sides
Text colours:   All white (#FFFFFF)
Eyebrow:        DM Sans 10pt, weight 500, rgba(255,255,255,0.8), uppercase
Day number:     Playfair Display 32pt, weight 400, #FFFFFF
Phase label:    DM Sans 13pt, rgba(255,255,255,0.9)
Pills:          rgba(255,255,255,0.2) background, #FFFFFF text, 10pt, weight 500, radius-full
Decoration:     Two white semi-transparent circles (opacity 0.08–0.10), positioned top-right and bottom-right. Not interactive.
```

#### Hero Card — Partner (Partner tab)
```
Background:     #1A0F0E (surface-dark)
Corner radius:  16pt (radius-2xl)
Padding:        16pt all sides
Eyebrow:        DM Sans 10pt, weight 500, rgba(255,255,255,0.5), uppercase
Name/Day:       Playfair Display 22pt, weight 400, #FFFFFF
Phase label:    DM Sans 12pt, rgba(255,255,255,0.7)
Pills:          rgba(248,131,121,0.2) background, #F88379 text — coral on dark
Decoration:     Same circle decoration as tracker hero card
```

#### Dashed / Empty CTA Card (Log today prompt)
```
Background:     #FEF9F8 (bg-warm)
Border:         1pt dashed, #F2DDD8 (border-default)
Corner radius:  14pt (radius-xl)
Padding:        16pt all sides
Layout:         Centred vertically, icon circle above copy above button
```

### 8.3 Chips & Pills

#### Selectable Chip (Mood, Symptoms)
```
Default:
  Background:   #FEF6F5 (bg-tinted)
  Border:       0.5pt, #F2DDD8
  Text:         #7A5250 (text-secondary), DM Sans 11pt, weight 400
  Corner radius: radius-full

Selected:
  Background:   #FDDBD8 (primary-light)
  Border:       0.5pt, #F88379 (primary)
  Text:         #C05A52 (darker coral), DM Sans 11pt, weight 500
```

#### Flow / Energy Button Row
```
5-column row (flow) or 3-column row (energy), each cell flex-equal
Default:
  Background:   #FEF6F5
  Border:       0.5pt, #F2DDD8
  Text:         #7A5250, DM Sans 10–11pt
  Corner radius: 8pt (radius-sm)

Selected:
  Background:   #FDDBD8
  Border:       0.5pt, #F88379
  Text:         #C05A52, weight 500
```

#### Status / Phase Pill (read-only)
```
Background:     #FDDBD8 (primary-light)
Text:           #C05A52, DM Sans 12pt, weight 500
Corner radius:  radius-full
Padding:        3pt vertical, 10pt horizontal
Used for:       Phase labels on calendar day card, hero card supplementary info
```

#### Step Pill (Onboarding)
```
Required:
  Background:   #FEF2F1 (primary-faint)
  Text:         #C05A52, DM Sans 10pt, weight 500
  Border:       0.5pt, #F2DDD8

Skippable/Optional:
  Background:   #FEF6F5
  Text:         #B89490 (text-tertiary)
  Border:       0.5pt, #E8C8C4
```

#### Connection Status Pill
```
Layout:         Dot + text inline
Dot:            7pt circle, #4CAF7D (success)
Text:           #7A5250, DM Sans 11pt, weight 400
```

### 8.4 Toggle Switch

```
Track off:      #E8C8C4 (border-strong)
Track on:       #F88379 (primary)
Thumb:          #FFFFFF, 14pt circle
Track size:     32pt × 18pt
Corner radius:  radius-full on track
Transition:     Smooth spring animation
```

### 8.5 Avatar / Initials Circle

```
Size:           30pt (nav bar) or 48pt (profile header)
Shape:          Circle
Background:     #FDDBD8 (primary-light)
Text:           Initials, #C05A52, DM Sans weight 500
Font size:      11pt (30pt circle) or 16pt (48pt circle)
```

### 8.6 Progress Dots (Onboarding)

```
Inactive dot:   6pt circle, #F2DDD8 (border-default)
Active dot:     16pt × 6pt pill, #F88379 (primary), radius-full
Gap between:    4pt
Layout:         Centred horizontally, top of each onboarding screen
```

### 8.7 Bottom Sheet

```
Background:         #FFFFFF (bg-base)
Corner radius:      20pt top-left, 20pt top-right, 0 bottom
Handle bar:         36pt × 4pt, #E8C8C4, radius-full, centred, 12pt from top
Title:              Playfair Display 18pt, weight 400, text-primary
Subtitle:           DM Sans 11pt, text-tertiary, below title
Overlay (peek):     rgba(26,15,14,0.30) behind the sheet
Bottom padding:     20pt + safe area inset
```

### 8.8 Log Row (Logged State)

```
Container:          Standard Card (bg-warm, border-default, radius-xl)
Row padding:        10pt vertical, 12pt horizontal
Row separator:      0.5pt, #FEF2F1 (primary-faint)
Icon column:        32pt × 32pt tinted bg (primary-light, radius 9pt)
Title:              DM Sans 12pt, weight 500, text-primary
Subtitle:           DM Sans 11pt, text-tertiary
Right action:       "Edit" — DM Sans 11pt, primary colour
```

### 8.9 Partner Activity Card

```
Background:         #FEF6F5 (bg-tinted)
Border:             0.5pt, #F2DDD8
Corner radius:      14pt (radius-xl)
Padding:            12pt vertical, 14pt horizontal
Header row:         Connection dot (7pt, success green) + name (DM Sans 12pt, weight 500) + status right-aligned (DM Sans 10pt, text-tertiary)
Chips row:          Partner's shared data as read-only chips (white bg, border-default, 10pt DM Sans, text-secondary)
```

---

## 9. Navigation Bar

```
Height:             Standard iOS nav bar (44pt)
Title:              Playfair Display 20pt, weight 400, text-primary, left-aligned
Left item:          Back chevron (Phosphor, regular, primary colour) when applicable
Right item:         Avatar circle (30pt) OR gear icon (Phosphor, regular, text-tertiary)
Background:         Transparent, scrolls with content (no blur effect)
Separator:          None by default. Only add when content scrolls behind nav.
```

---

## 10. Tab Bar

```
Background:         #FFFFFF (bg-base)
Top border:         0.5pt, #F2DDD8 (border-default)
Height:             Standard iOS tab bar + safe area
Icon size:          22pt × 22pt
Label:              DM Sans 9pt
Active colour:      #F88379 (primary) — icon + label
Inactive colour:    #B89490 (text-tertiary) — icon + label
Label spacing:      3pt below icon
```

---

## 11. Calendar Component

### Grid

```
Day of week headers:    DM Sans 10pt, weight 500, text-tertiary, uppercase
Day cell:               Flex equal, 7 columns
Date number:            DM Sans 12pt, weight 400, text-primary
                        — in 34pt × 34pt tappable area minimum (accessibility)
```

### Date States

| State | Visual |
|---|---|
| Default | DM Sans 12pt, `text-primary` |
| Today | 26pt coral circle (`primary`), white text, weight 500 |
| Selected | 26pt dark circle (`#1A0F0E`), white text |
| Future / predicted | `text-tertiary` colour |
| Out of month | `text-tertiary`, visually muted |
| Logged | Small 4pt coral dot at bottom of date number (white dot on coral background for today) |

### Phase Strips

```
Position:       Below date number, 2pt gap
Size:           22pt wide × 3pt tall
Corner radius:  2pt

Phase colours:
  Period:           #F88379 (primary)
  Ovulation:        #E37383 (primary-dark)
  Fertile window:   #FDDBD8 (primary-light)
  Luteal:           #F0E8E0 (phase-luteal)
  Follicular:       transparent / none
```

### Phase Legend

```
Layout:         Horizontal row, wraps if needed
Item:           8pt × 3pt rounded rect + DM Sans 9pt label, text-tertiary
Gap:            10pt between items
Position:       Below calendar grid, above day summary card
```

---

## 12. Screen-by-Screen Layout Specs

### 12.1 Welcome Screen

```
Root background:        #FFFFFF
Background decoration:  Three Circle() shapes
  Circle 1:   320pt diameter, primary-light (#FDDBD8), top-right, offset -80pt top, -80pt right
  Circle 2:   200pt diameter, primary-faint (#FEF2F1), bottom-left area, offset -60pt left
  Circle 3:   120pt diameter, primary (#F88379) at 12% opacity, mid-left

Content layout (VStack, full screen):
  Wordmark:           Playfair Display 22pt, top-left, letter-spacing 0.04em
                      "Cadence" in text-primary + "." in primary colour
  Hero section:       Flex-grows to fill space between wordmark and auth CTAs
    Eyebrow:          DM Sans 11pt, 500, primary, uppercase, letter-spacing 0.12em
                      "Cycle tracking, together"
    Headline:         Playfair Display 32pt, text-primary, line-height 1.15
                      "Your rhythm, [italic primary]shared[/italic] with someone who cares."
    Sub-copy:         DM Sans 14pt, text-secondary, line-height 1.6, margin-top 14pt
  Auth stack:
    Apple CTA:        Full-width primary button, dark background (#1A0F0E), Apple logo 16pt
    Divider:          "or" — DM Sans 11pt, text-tertiary, centred between two 0.5pt lines
    Email CTA:        Full-width ghost button, border-default
    Footer:           DM Sans 11pt, text-tertiary, centred. Links in primary colour.

Side margins: 24pt (slightly wider than standard 16pt — this screen is more editorial)
```

### 12.2 Onboarding Screens

```
Top area (each screen):
  Progress dots:    Centred, 16pt from top content area
  Step pill:        12pt below dots

Screen structure:
  Title:            Playfair Display 20pt, text-primary
  Sub-copy:         DM Sans 12pt, text-secondary, 6pt below title
  Content:          Varies by step (see below)
  Spacer:           Flex-grows to push CTA to bottom
  Primary CTA:      Full-width primary button, always at bottom with 20pt bottom margin
```

**Role Selection (Step 1)**
```
Two selection cards, 8pt gap between them
Selected card:
  border: 1.5pt, #F88379
  background: #FEF2F1 (primary-faint)
Default card:
  border: 1.5pt, #F2DDD8
  background: #FEF9F8 (bg-warm)
Radio dot: 16pt circle, right-aligned in card header
  Selected: filled #F88379
  Default: border only, #F2DDD8
Card title: DM Sans 13pt, weight 500, text-primary
Card sub: DM Sans 11pt, text-secondary
Card padding: 12pt all sides
```

**Last Period Date (Step 2)**
```
Date display card:
  background: #FEF6F5, border-default, radius-md
  Label: DM Sans 10pt, text-tertiary
  Value: Playfair Display 18pt, text-primary
  Padding: 12pt

Mini calendar:
  background: #FEF9F8, border-default, radius-md, padding 10pt
  Month label: DM Sans 10pt, weight 500, text-secondary, centred
  Day of week: 9pt, text-tertiary
  Date cells: 14pt × 14pt circles
    Selected: #F88379 circle, white text
    Default: text-secondary
```

**Cycle + Duration (Step 3)**
```
Picker rows: bg-tinted background, border-default, radius-md (two rows, 8pt gap)
  Label: DM Sans 12pt, text-secondary
  Value + chevron: DM Sans 13pt, weight 500, text-primary, right-aligned
  Padding: 10pt vertical, 12pt horizontal
Helper tip: bg-tinted, radius-sm, 8pt padding, DM Sans 10pt, text-secondary
```

**Sharing Preferences (Step 4)**
```
Toggle list rows on transparent background (no card container)
  Row padding: 10pt vertical, 0pt horizontal
  Row separator: 0.5pt, border-default
  Label: DM Sans 12pt, weight 500, text-primary
  Sub-label: DM Sans 10pt, text-tertiary
  Toggle: right-aligned
```

**Invite Partner (Step 5 — Optional)**
```
Layout: centred VStack
Illustration: 80pt outer circle (primary-faint), 48pt inner circle (primary-light), heart icon centred
Title: Playfair Display 20pt, text-primary, centred, line-height 1.2
Sub-copy: DM Sans 13pt, text-secondary, centred, line-height 1.6
Primary CTA: "Send invite link" with share icon (14pt, white)
Skip: DM Sans 12pt, text-secondary, centred, 12pt above bottom
```

**Notifications (Step 6)**
```
Toggle list with icon rows (same as Settings notifications section)
Icon cell: 28pt × 28pt, primary-light background, radius-sm
Title: DM Sans 11pt, weight 500, text-primary
Sub: DM Sans 10pt, text-tertiary
Toggle: right-aligned
```

### 12.3 Today Screen

```
Nav bar: "Today" (Title Large), avatar right
Screen background: bg-base (#FFFFFF)

Hero card: full-width minus 16pt margins, radius-2xl, 16pt padding
  Top: eyebrow (DM Sans 10pt, 500, rgba white 0.8, uppercase)
  Middle: Day number (Display 32pt, white) + phase (Body Small, rgba white 0.9)
  Bottom: pills row

Log CTA card (unlogged): full-width minus 16pt margins
  Icon circle: 40pt, primary-light
  Text: DM Sans 13pt, text-secondary, centred
  Button: primary CTA, 10pt vertical padding, auto horizontal

Today's Log section (logged): full-width minus 16pt margins
  Section header: Label style + "Edit" right action
  Card: grouped list style, 3 rows visible

Partner section:
  Section header: Label style only
  Partner card: full-width minus 16pt margins

Spacing between sections: 12pt
```

### 12.4 Log Bottom Sheet

```
Sheet handle: 36pt × 4pt, #E8C8C4, centred, 12pt top margin
Sheet title: "Log today", Title Small (Playfair 18pt)
Sheet sub: date + cycle day, Caption Small (DM Sans 11pt, text-tertiary)

Section label: Label style (10pt, 500, uppercase, text-tertiary)
Section spacing: 12pt between sections

Period section: Flow chip row (5 equal buttons, 5pt gaps)
Mood section: Chip grid (flex-wrap, 5pt gaps)
Energy section: 3-button row (equal width, 5pt gaps)
Symptoms section: Chip grid + "more" chip

Scroll: sections below symptoms (sleep, sex, notes) require scrolling
Save button: full-width primary CTA, sticky at bottom, 12pt margin top
Sheet bottom padding: 20pt + safe area
```

### 12.5 Calendar Screen

```
Nav bar: "Calendar" (Title Large), month/year + chevron right-aligned
Screen scrolls as one continuous view

Calendar grid: 12pt horizontal margin (slightly tighter than standard for cell fitting)
Grid top margin: 4pt below day-of-week headers

Selected day card: 16pt margins, Standard Card, appears between grid and legend
  Day title: Playfair Display 14pt, text-primary
  Phase pill: right-aligned
  Log chips: HStack, flex-wrap, 5pt gaps

Legend: 16pt margins, 8pt top margin, horizontal HStack
  
Insights section:
  Section header: Label style
  2-column grid: 6pt gap
    Standard cards: bg-warm, border-default, radius-md, 8pt padding
    Label: DM Sans 9pt, text-tertiary
    Value: Playfair Display 18pt, text-primary (number) + DM Sans 10pt, text-secondary (unit)
    Sub: DM Sans 9pt, text-tertiary, below value
  Wide card (trend): spans 2 columns, flex row — label/sub left, bar chart right
    Bars: 10pt wide, radius-sm top only, primary-light fill (default), primary fill (current)
```

### 12.6 Partner Tab

```
Nav bar: "Partner" (Title Large), avatar right (if connected)

Empty state (centred VStack, vertically centred in remaining screen space):
  Outer circle: 80pt, primary-faint
  Inner circle: 48pt, primary-light
  Icon: heart, 24pt, primary
  Title: Playfair Display 20pt, text-primary, centred, "Invite your partner"
  Sub-copy: DM Sans 13pt, text-secondary, centred, line-height 1.6
  CTA: Primary button with share icon
  Hint: Caption Small, text-tertiary, centred, 12pt below CTA

Connected — tracker view:
  Connection badge: 8pt top margin, 16pt horizontal margin
    (success dot + "Connected with [name]")
  Partner hero card: standard hero card dark variant
  "Shared today" section header + shared data card
  "What [name] shares" section header + controls card with toggles

Connected — partner view:
  Connection badge
  Partner hero card (dark)
  Phase explanation card:
    Background: bg-warm, border-default, radius-xl, 14pt padding
    Eyebrow: Label style
    Title: Playfair Display 16pt, text-primary
    Body: DM Sans 12pt, text-secondary, line-height 1.6
  "Shared with you" section header + shared data card
```

### 12.7 Profile / Settings

```
Presentation: Modal sheet (not pushed)
Dismiss: "Done" button, top-right, DM Sans 12pt, text-tertiary

Profile header:
  Avatar: 48pt circle, primary-light, initials in primary-dark, 16pt DM Sans
  Name: Playfair Display 18pt, text-primary
  Email: DM Sans 11pt, text-tertiary
  Edit: DM Sans 11pt, primary, right-aligned
  Bottom separator: 0.5pt, border-default, full width
  Padding: 0 16pt 16pt

Four sections, each:
  Section label: Label style, 16pt horizontal margin
  Grouped card: standard grouped list card style

Destructive row styles:
  Disconnect text: DM Sans 11pt, error colour (#E74C3C)
  Sign out label: DM Sans 12pt, weight 500, error colour
  Sign out icon: error colour
```

---

## 13. Motion & Animation

**Philosophy:** Subtle and functional. Motion should communicate state changes, not entertain.

| Interaction | Animation |
|---|---|
| Bottom sheet present/dismiss | Default iOS sheet animation (spring, standard) |
| Toggle switch | Spring animation, 0.2s |
| Chip select/deselect | Scale 0.97 on tap down, spring back. Background crossfade 0.15s |
| Tab switch | Default iOS tab bar animation |
| Hero card pill update (unlogged → logged) | Crossfade 0.2s |
| Calendar date selection | Background circle fade 0.15s |
| Onboarding step advance | Horizontal slide, iOS NavigationStack default |
| Button tap | Scale 0.97 on press, spring release |
| Progress dot advance | Active dot width animates from 6pt to 16pt, spring 0.25s |

---

## 14. Accessibility

- All interactive elements: minimum 44pt × 44pt tap target
- Text: never below 11pt at default size. Support Dynamic Type on all DM Sans text.
- Playfair Display headings: fixed size (do not scale with Dynamic Type — too large and too decorative)
- Colour contrast: all text/background combinations must meet WCAG AA (4.5:1 for body, 3:1 for large text)
- Coral `#F88379` on white `#FFFFFF`: contrast ratio 2.9:1 — use only for large text (18pt+) or decorative elements. Never for small body copy.
- VoiceOver labels: all icons must have accessibility labels. Toggle state must be announced.
- Reduce Motion: disable scale animations if `UIAccessibility.isReduceMotionEnabled`. Use opacity crossfades instead.

---

## 15. Empty States

Every potentially empty section needs a designed empty state. No blank cards, no missing sections.

| Location | Empty state copy | Visual |
|---|---|---|
| Partner tab (no partner) | "Invite your partner" | Illustration + CTA |
| Partner card on Today (no partner) | "Invite your partner to see their updates here" | Subtle dashed card, small heart icon |
| Partner card (partner hasn't logged) | "[Name] hasn't logged today yet" | Dashed card, text-tertiary |
| Insights — awaiting data | "Log 1 more cycle to see your [insight name]" | Insight card with placeholder layout, dashed text |
| Calendar — no logs | Phase strips visible (from onboarding seed), no logged dots | Default calendar |

---

## 16. Copy Conventions

- All UI copy: sentence case. Never ALL CAPS except Label components (section headers).
- CTA copy: active verbs. "Log today", "Send invite link", "Save log", "Enter Cadence", "Continue"
- Never: "Submit", "OK", "Done" as primary CTAs
- Tone: warm and direct. Not clinical, not corporate, not overly cute.
- Error messages: blame the situation, not the user. "Something went wrong — try again" not "You made an error"
- Empty states: forward-looking. "Log 1 more cycle" not "No data yet"
- Onboarding: reassuring. "You can change this anytime", "They self-correct as you log"

---

*Cadence UI Design Specification v1.0 — use alongside the PRD for implementation.*
