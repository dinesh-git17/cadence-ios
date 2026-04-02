import SwiftUI

struct PickerRow: View {
    let label: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.cadenceBody)
                    .foregroundStyle(Color.cadenceTextSecondary)
                Spacer()
                Text(value)
                    .font(.cadenceBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cadenceTextPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.cadenceTextTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, CadenceSpacing.md)
            .background(Color.cadenceBgTinted)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.md)
                    .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
