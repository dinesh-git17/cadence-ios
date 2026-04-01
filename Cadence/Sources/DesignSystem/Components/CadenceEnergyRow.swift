import SwiftUI

enum EnergyLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
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
