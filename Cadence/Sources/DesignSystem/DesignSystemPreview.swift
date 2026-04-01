import SwiftUI

struct DesignSystemPreview: View {
    @State private var chipSelected = false
    @State private var chipUnselected = false
    @State private var flowSelection: PeriodFlow? = .medium
    @State private var energySelection: EnergyLevel? = .high
    @State private var toggleOn = true
    @State private var toggleOff = false
    @State private var progressStep = 2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CadenceSpacing.xl) {
                colourSwatches
                typographyScale
                buttonStyles
                heroCards
                chipSection
                flowAndEnergy
                togglesAndCards
                miscComponents
            }
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.vertical, CadenceSpacing.xxl)
        }
        .background(Color.cadenceBgBase)
    }

    // MARK: - Colour Swatches

    private var colourSwatches: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Colours")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: CadenceSpacing.sm) {
                colourSwatch("Primary", .cadencePrimary)
                colourSwatch("Pr Dark", .cadencePrimaryDark)
                colourSwatch("Pr Light", .cadencePrimaryLight)
                colourSwatch("Pr Faint", .cadencePrimaryFaint)
                colourSwatch("Bg Warm", .cadenceBgWarm)
                colourSwatch("Bg Tint", .cadenceBgTinted)
                colourSwatch("Success", .cadenceSuccess)
                colourSwatch("Warning", .cadenceWarning)
                colourSwatch("Error", .cadenceError)
                colourSwatch("Luteal", .cadencePhaseLuteal)
                colourSwatch("Dark", .cadenceSurfaceDark)
            }
        }
    }

    private func colourSwatch(_ label: String, _ colour: Color) -> some View {
        VStack(spacing: CadenceSpacing.xs) {
            RoundedRectangle(cornerRadius: CadenceRadius.sm)
                .fill(colour)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: CadenceRadius.sm)
                        .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
                )
            Text(label)
                .font(.cadenceMicro)
                .foregroundColor(.cadenceTextTertiary)
        }
    }

    // MARK: - Typography

    private var typographyScale: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Typography")
            VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
                Text("Display 32pt").font(.cadenceDisplay).foregroundColor(.cadenceTextPrimary)
                Text("Title Large 22pt").font(.cadenceTitleLarge).foregroundColor(.cadenceTextPrimary)
                Text("Title Medium 20pt").font(.cadenceTitleMedium).foregroundColor(.cadenceTextPrimary)
                Text("Title Small 18pt").font(.cadenceTitleSmall).foregroundColor(.cadenceTextPrimary)
                Text("Body 15pt").font(.cadenceBody).foregroundColor(.cadenceTextPrimary)
                Text("Body Medium 14pt").font(.cadenceBodyMedium).foregroundColor(.cadenceTextPrimary)
                Text("Body Small 13pt").font(.cadenceBodySmall).foregroundColor(.cadenceTextSecondary)
                Text("Caption 12pt").font(.cadenceCaption).foregroundColor(.cadenceTextSecondary)
                Text("Caption Small 11pt").font(.cadenceCaptionSmall).foregroundColor(.cadenceTextTertiary)
                Text("LABEL 10PT").font(.cadenceLabel).foregroundColor(.cadenceTextTertiary).kerning(0.8)
                Text("Micro 9pt").font(.cadenceMicro).foregroundColor(.cadenceTextTertiary)
            }
        }
    }

    // MARK: - Buttons

    private var buttonStyles: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Buttons")
            Button("Primary Button") {}
                .buttonStyle(PrimaryButtonStyle())
            Button("Ghost Button") {}
                .buttonStyle(GhostButtonStyle())
            Button("Primary (Disabled)") {}
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
            Button("Destructive Text") {}
                .buttonStyle(DestructiveTextButtonStyle())
            Button("Skip for now") {}
                .font(.cadenceBodySmall)
                .foregroundColor(.cadenceTextSecondary)
        }
    }

    // MARK: - Hero Cards

    private var heroCards: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Hero Cards")
            CadenceHeroCard(
                cycleDay: 14,
                phaseLabel: "Ovulation",
                pills: ["Fertile window"],
                isLogged: false
            )
            CadenceHeroCard(
                cycleDay: 5,
                phaseLabel: "Follicular",
                pills: ["Next period in 23 days"],
                isLogged: true
            )
            CadencePartnerHeroCard(
                partnerName: "Sarah",
                cycleDay: 14,
                phaseLabel: "Ovulation",
                pills: ["Energetic", "Happy"]
            )
        }
    }

    // MARK: - Chips

    private var chipSection: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Chips")
            HStack(spacing: CadenceSpacing.xs) {
                CadenceChip(label: "Selected", isSelected: $chipSelected)
                CadenceChip(label: "Default", isSelected: $chipUnselected)
            }
            .onAppear { chipSelected = true }
        }
    }

    // MARK: - Flow & Energy

    private var flowAndEnergy: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Flow & Energy")
            CadenceFlowRow(selection: $flowSelection)
            CadenceEnergyRow(selection: $energySelection)
        }
    }

    // MARK: - Toggles & Grouped Card

    private var togglesAndCards: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Toggles & Grouped Card")
            CadenceGroupedCard {
                CadenceGroupedRow {
                    CadenceToggleRow(title: "Period", subtitle: "Flow and dates", isOn: $toggleOn)
                }
                CadenceGroupedRow {
                    CadenceToggleRow(title: "Symptoms", subtitle: "What you're feeling", isOn: $toggleOff)
                }
                CadenceGroupedRow(showSeparator: false) {
                    CadenceToggleRow(title: "Mood", subtitle: "Your emotional state", isOn: $toggleOn)
                }
            }
        }
    }

    // MARK: - Misc Components

    private var miscComponents: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            CadenceSectionHeader(title: "Misc", actionLabel: "Edit") {}

            HStack(spacing: CadenceSpacing.md) {
                CadenceAvatarCircle(initials: "DD", diameter: 30)
                CadenceAvatarCircle(initials: "SK", diameter: 48)
                CadenceIconTile {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.cadencePrimary)
                }
            }

            CadenceProgressDots(totalSteps: 6, currentStep: progressStep)

            HStack(spacing: CadenceSpacing.sm) {
                ForEach(CyclePhase.allCases, id: \.self) { phase in
                    if phase.stripColor != .clear {
                        HStack(spacing: CadenceSpacing.xs) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(phase.stripColor)
                                .frame(width: 8, height: 3)
                            Text(phase.displayName)
                                .font(.cadenceMicro)
                                .foregroundColor(.cadenceTextTertiary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    DesignSystemPreview()
}
