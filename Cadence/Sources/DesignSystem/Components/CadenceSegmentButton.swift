import SwiftUI

/// Shared equal-width toggle button used by CadenceFlowRow and CadenceEnergyRow.
struct CadenceSegmentButton: View {
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
