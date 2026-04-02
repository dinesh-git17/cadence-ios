import SwiftUI

struct RoleCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                cardContent
                Spacer()
                radioDot
            }
            .padding(CadenceSpacing.md)
            .background(isSelected ? Color.cadencePrimaryFaint : Color.cadenceBgWarm)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.lg)
                    .stroke(
                        isSelected ? Color.cadencePrimary : Color.cadenceBorderDefault,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.xs) {
            Text(title)
                .font(.cadenceBody)
                .fontWeight(.medium)
                .foregroundStyle(Color.cadenceTextPrimary)
            Text(subtitle)
                .font(.cadenceBodySmall)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
    }

    private var radioDot: some View {
        Circle()
            .strokeBorder(
                isSelected ? Color.cadencePrimary : Color.cadenceBorderDefault,
                lineWidth: 1.5
            )
            .background(
                Circle().fill(isSelected ? Color.cadencePrimary : .clear)
            )
            .frame(width: 16, height: 16)
    }
}
