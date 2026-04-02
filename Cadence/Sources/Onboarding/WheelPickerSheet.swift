import SwiftUI

struct WheelPickerSheet: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var selection: Int
    let unit: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            handleBar
            sheetTitle
            picker
            doneButton
        }
    }

    private var handleBar: some View {
        Capsule()
            .fill(Color.cadenceBorderStrong)
            .frame(width: 36, height: 4)
            .padding(.top, CadenceSpacing.md)
    }

    private var sheetTitle: some View {
        Text(title)
            .font(.cadenceTitleSmall)
            .foregroundStyle(Color.cadenceTextPrimary)
            .padding(.top, CadenceSpacing.md)
    }

    private var picker: some View {
        Picker(title, selection: $selection) {
            ForEach(range, id: \.self) { value in
                Text("\(value) \(unit)").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .accessibilityLabel("\(title) picker")
    }

    private var doneButton: some View {
        Button("Done") { dismiss() }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.bottom, 20)
    }
}
