# Cadence Components — Swift Reference

All components live in `Cadence/DesignSystem/Components/`.
Each component has its own file named to match the struct.

---

## CadenceHeroCard

**File:** `CadenceHeroCard.swift`
**Use for:** Today screen — tracker's cycle day, phase label, prediction pills, logged state.
**Not for:** Partner data (use `CadencePartnerHeroCard`).

```swift
import SwiftUI

struct CadenceHeroCard: View {
    let cycleDay: Int
    let phaseLabel: String
    /// Short read-only pills shown below the day+phase row (e.g. predicted dates, fertile window label)
    var pills: [String] = []
    var isLogged: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Decorative circles — not interactive, purely visual
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 160, y: -50)
                .allowsHitTesting(false)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 90, height: 90)
                .offset(x: 210, y: 60)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
                // Eyebrow
                Text("CYCLE DAY")
                    .font(.cadenceLabel)
                    .foregroundColor(.white.opacity(0.8))
                    .kerning(0.8)

                // Primary content row
                HStack(alignment: .bottom, spacing: CadenceSpacing.sm) {
                    Text("\(cycleDay)")
                        .font(.cadenceDisplay)
                        .foregroundColor(.white)
                    Text(phaseLabel)
                        .font(.cadenceBodySmall)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.bottom, 4)
                }

                // Pills row
                HStack(spacing: CadenceSpacing.xs) {
                    ForEach(pills, id: \.self) { pill in
                        Text(pill)
                            .font(.cadenceCaptionSmall)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    if isLogged {
                        Text("✓ Logged today")
                            .font(.cadenceCaptionSmall)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    }
                }
            }
            .padding(CadenceSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cadencePrimary)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.xxl))
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cycle day \(cycleDay), \(phaseLabel)\(isLogged ? ", logged today" : "")")
    }
}
```

---

## CadencePartnerHeroCard

**File:** `CadencePartnerHeroCard.swift`
**Use for:** Partner tab — partner's cycle data on the dark surface.
**Key differences from CadenceHeroCard:**
- Background is `cadenceSurfaceDark` (not coral)
- Pills use coral-on-dark (not white-on-coral)
- Eyebrow shows partner name (not "CYCLE DAY")
- Day number uses `cadenceTitleLarge` (22pt), not `cadenceDisplay` (32pt)

```swift
import SwiftUI

struct CadencePartnerHeroCard: View {
    let partnerName: String
    let cycleDay: Int
    let phaseLabel: String
    /// Shared data pills — mood, energy shown as coral pills on dark bg
    var pills: [String] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 160, y: -50)
                .allowsHitTesting(false)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 90, height: 90)
                .offset(x: 210, y: 60)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
                Text(partnerName.uppercased())
                    .font(.cadenceLabel)
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(0.8)

                HStack(alignment: .bottom, spacing: CadenceSpacing.sm) {
                    Text("Day \(cycleDay)")
                        .font(.cadenceTitleLarge)
                        .foregroundColor(.white)
                    Text(phaseLabel)
                        .font(.cadenceCaption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 3)
                }

                if !pills.isEmpty {
                    HStack(spacing: CadenceSpacing.xs) {
                        ForEach(pills, id: \.self) { pill in
                            Text(pill)
                                .font(.cadenceCaptionSmall)
                                .fontWeight(.medium)
                                .foregroundColor(.cadencePrimary) // coral on dark
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.cadencePrimary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(CadenceSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cadenceSurfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.xxl))
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(partnerName)'s cycle, day \(cycleDay), \(phaseLabel)")
    }
}
```

---

## CadenceChip

**File:** `CadenceChip.swift`
**Use for:** Multi-select mood and symptom selection in the log sheet.
**Not for:** Flow selection (use `CadenceFlowRow`) or energy (use `CadenceEnergyRow`).

```swift
import SwiftUI

struct CadenceChip: View {
    let label: String
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            Text(label)
                .font(.cadenceCaptionSmall)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundColor(isSelected ? .cadenceTextOnLight : .cadenceTextSecondary)
                .padding(.horizontal, CadenceSpacing.sm)
                .padding(.vertical, CadenceSpacing.xs)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.cadencePrimaryLight : Color.cadenceBgTinted)
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.cadencePrimary : Color.cadenceBorderDefault,
                            lineWidth: 0.5
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                )
        }
        .buttonStyle(CadenceChipButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Internal button style — not exported for other uses
struct CadenceChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
```

**Usage:**

```swift
// In a chip grid — use FlexLayout or LazyVGrid with adaptive columns
@State private var selectedMoods: Set<String> = []
let moods = ["Happy", "Calm", "Anxious", "Irritable", "Sad", "Energetic", "Tired"]

var body: some View {
    FlowLayout(spacing: CadenceSpacing.xs) {
        ForEach(moods, id: \.self) { mood in
            CadenceChip(
                label: mood,
                isSelected: Binding(
                    get: { selectedMoods.contains(mood) },
                    set: { if $0 { selectedMoods.insert(mood) } else { selectedMoods.remove(mood) } }
                )
            )
        }
    }
}
```

---

## CadenceFlowRow

**File:** `CadenceFlowRow.swift`
**Use for:** Period flow selection in the log sheet. Five equal-width buttons.

```swift
import SwiftUI

enum PeriodFlow: String, CaseIterable {
    case none     = "None"
    case spotting = "Spotting"
    case light    = "Light"
    case medium   = "Medium"
    case heavy    = "Heavy"
}

struct CadenceFlowRow: View {
    @Binding var selection: PeriodFlow?

    var body: some View {
        HStack(spacing: CadenceSpacing.xs) {
            ForEach(PeriodFlow.allCases, id: \.self) { flow in
                CadenceSegmentButton(
                    label: flow.rawValue,
                    isSelected: selection == flow,
                    action: { selection = selection == flow ? nil : flow }
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}
```

---

## CadenceEnergyRow

**File:** `CadenceEnergyRow.swift`
**Use for:** Energy level selection in the log sheet. Three equal-width buttons.

```swift
import SwiftUI

enum EnergyLevel: String, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"
}

struct CadenceEnergyRow: View {
    @Binding var selection: EnergyLevel?

    var body: some View {
        HStack(spacing: CadenceSpacing.xs) {
            ForEach(EnergyLevel.allCases, id: \.self) { level in
                CadenceSegmentButton(
                    label: level.rawValue,
                    isSelected: selection == level,
                    action: { selection = selection == level ? nil : level }
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}
```

**Shared segment button (internal):**

```swift
// Private — used by both CadenceFlowRow and CadenceEnergyRow
private struct CadenceSegmentButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.cadenceCaptionSmall)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundColor(isSelected ? .cadenceTextOnLight : .cadenceTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.cadencePrimaryLight : Color.cadenceBgTinted)
                .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CadenceRadius.sm)
                        .stroke(
                            isSelected ? Color.cadencePrimary : Color.cadenceBorderDefault,
                            lineWidth: 0.5
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

---

## CadenceToggleRow

**File:** `CadenceToggleRow.swift`
**Use for:** Sharing preferences toggles, notification settings rows, any label+subtitle+toggle row.
**Note:** Use inside a `CadenceGroupedCard` with `CadenceGroupedRow` wrapping. Do not float standalone.

```swift
import SwiftUI

struct CadenceToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: CadenceSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cadenceBodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.cadenceTextPrimary)
                Text(subtitle)
                    .font(.cadenceCaptionSmall)
                    .foregroundColor(.cadenceTextTertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.cadencePrimary)
        }
        .padding(.vertical, CadenceSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}
```

**Usage:**

```swift
CadenceGroupedCard {
    CadenceGroupedRow {
        CadenceToggleRow(title: "Period", subtitle: "Flow and dates", isOn: $sharePeriod)
    }
    CadenceGroupedRow {
        CadenceToggleRow(title: "Symptoms", subtitle: "What you're feeling physically", isOn: $shareSymptoms)
    }
    CadenceGroupedRow(showSeparator: false) {
        CadenceToggleRow(title: "Mood", subtitle: "Your emotional state", isOn: $shareMood)
    }
}
```

---

## CadenceGroupedCard + CadenceGroupedRow

**File:** `CadenceGroupedCard.swift`
**Use for:** Any grouped list of rows — settings sections, sharing controls, notification toggles.
**Not for:** Single-item cards (use a standard card manually) or hero content.

```swift
import SwiftUI

/// Container for grouped list rows. Provides bg-warm background, border, and radius-lg.
struct CadenceGroupedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.lg)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
    }
}

/// A single row inside CadenceGroupedCard. Handles internal padding and separator.
/// Set showSeparator: false on the last row — the card border handles the bottom edge.
struct CadenceGroupedRow<Content: View>: View {
    var showSeparator: Bool = true
    let content: Content

    init(showSeparator: Bool = true, @ViewBuilder content: () -> Content) {
        self.showSeparator = showSeparator
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, CadenceSpacing.md)
            if showSeparator {
                Rectangle()
                    .fill(Color.cadencePrimaryFaint)
                    .frame(height: 0.5)
                    .padding(.leading, CadenceSpacing.md)
            }
        }
    }
}
```

---

## CadenceIconTile

**File:** `CadenceIconTile.swift`
**Use for:** Icon displayed inside a tinted background square in list rows and log rows.
**Accepts any View as content** — pass a Phosphor icon, a system image, or any icon view.

```swift
import SwiftUI

struct CadenceIconTile<Icon: View>: View {
    /// 30pt for standard list rows, 32pt for log entry rows
    var size: CGFloat = 30
    let icon: Icon

    init(size: CGFloat = 30, @ViewBuilder icon: () -> Icon) {
        self.size = size
        self.icon = icon()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: CadenceRadius.sm)
            .fill(Color.cadencePrimaryLight)
            .frame(width: size, height: size)
            .overlay(icon)
            .accessibilityHidden(true) // icon label is on the parent row
    }
}
```

**Usage with PhosphorSwift:**

```swift
// PhosphorSwift Regular weight — never Bold or Thin
CadenceIconTile {
    Ph.heart.regular
        .image
        .resizable()
        .scaledToFit()
        .frame(width: 16, height: 16)
        .foregroundColor(.cadencePrimary)
}

// In a log row
HStack(spacing: CadenceSpacing.sm) {
    CadenceIconTile(size: 32) {
        Ph.smiley.regular
            .image
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundColor(.cadencePrimary)
    }
    VStack(alignment: .leading, spacing: 2) {
        Text("Mood")
            .font(.cadenceCaption)
            .fontWeight(.medium)
            .foregroundColor(.cadenceTextPrimary)
        Text("Happy, Calm")
            .font(.cadenceCaptionSmall)
            .foregroundColor(.cadenceTextTertiary)
    }
    Spacer()
}
```

---

## CadenceProgressDots

**File:** `CadenceProgressDots.swift`
**Use for:** Onboarding step indicator. Active dot animates to a pill shape.

```swift
import SwiftUI

struct CadenceProgressDots: View {
    let totalSteps: Int
    /// 0-indexed. The dot at this index becomes the active pill.
    let currentStep: Int

    var body: some View {
        HStack(spacing: CadenceSpacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                let isActive = index == currentStep
                RoundedRectangle(cornerRadius: CadenceRadius.full)
                    .fill(isActive ? Color.cadencePrimary : Color.cadenceBorderDefault)
                    .frame(width: isActive ? 16 : 6, height: 6)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: currentStep
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
    }
}
```

**Usage:**

```swift
// In an onboarding view
VStack(spacing: CadenceSpacing.md) {
    CadenceProgressDots(totalSteps: 6, currentStep: viewModel.currentStep)
    // step pill, screen content...
}
```

---

## CadenceSectionHeader

**File:** `CadenceSectionHeader.swift`
**Use for:** Section labels above card groups. Optionally includes a right-aligned action link.
**Never hand-roll** uppercase DM Sans 10pt headers — always use this component.

```swift
import SwiftUI

struct CadenceSectionHeader: View {
    let title: String
    /// Optional right-aligned label and action (e.g. "Edit" on the log section)
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .font(.cadenceLabel)
                .foregroundColor(.cadenceTextTertiary)
                .kerning(0.8)
            Spacer()
            if let label = actionLabel, let action = action {
                Button(label, action: action)
                    .font(.cadenceCaptionSmall)
                    .foregroundColor(.cadencePrimary)
                    .accessibilityLabel("\(label) \(title)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
```

**Usage:**

```swift
VStack(spacing: CadenceSpacing.sm) {
    CadenceSectionHeader(title: "Today's log", actionLabel: "Edit", action: { showLogSheet = true })
        .padding(.horizontal, CadenceSpacing.lg)
    CadenceGroupedCard { /* rows */ }
        .padding(.horizontal, CadenceSpacing.lg)
}
```

---

## CadenceAvatarCircle

**File:** `CadenceAvatarCircle.swift`
**Use for:** User's initials circle in the nav bar (30pt) and profile header (48pt).

```swift
import SwiftUI

struct CadenceAvatarCircle: View {
    let initials: String
    /// 30pt for nav bar, 48pt for profile header
    var diameter: CGFloat = 30

    var body: some View {
        Circle()
            .fill(Color.cadencePrimaryLight)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initials.prefix(2).uppercased())
                    .font(.custom("DMSans-Medium", size: diameter * 0.37))
                    .foregroundColor(.cadenceTextOnLight)
            )
            .accessibilityLabel("Profile")
            .accessibilityAddTraits(.isButton)
    }
}
```

**Usage:**

```swift
// Nav bar (30pt)
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button { showProfile = true } label: {
            CadenceAvatarCircle(initials: user.initials, diameter: 30)
        }
    }
}

// Profile header (48pt)
CadenceAvatarCircle(initials: user.initials, diameter: 48)
```

---

## Notes on PhosphorSwift Integration

Add the package via Swift Package Manager:
`https://github.com/phosphor-icons/PhosphorSwift`

**Always use `.regular` weight.** Never `.bold`, `.thin`, or `.fill`.

```swift
// ✅ Correct
Ph.calendar.regular.image

// ❌ Wrong — never use other weights
Ph.calendar.bold.image
Ph.calendar.thin.image
```

Icon sizing by context:
- Tab bar: 22×22pt
- List row inside `CadenceIconTile` (30pt tile): 16×16pt icon
- List row inside `CadenceIconTile` (32pt tile): 18×18pt icon
- Nav bar item: 18×18pt
- Empty state hero: 24×24pt
- Card/inline: 14×14pt
