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

struct CadenceChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
