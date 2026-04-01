import SwiftUI

enum PeriodFlow: String, CaseIterable {
    case none = "None"
    case spotting = "Spotting"
    case light = "Light"
    case medium = "Medium"
    case heavy = "Heavy"
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
