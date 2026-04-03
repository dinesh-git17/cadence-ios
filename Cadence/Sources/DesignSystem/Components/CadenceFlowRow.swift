import SwiftUI

struct CadenceFlowRow: View {
    @Binding var selection: PeriodFlow?

    var body: some View {
        HStack(spacing: CadenceSpacing.xs) {
            ForEach(PeriodFlow.allCases, id: \.self) { flow in
                CadenceSegmentButton(
                    label: flow.displayName,
                    isSelected: selection == flow,
                    action: { selection = selection == flow ? nil : flow }
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}
