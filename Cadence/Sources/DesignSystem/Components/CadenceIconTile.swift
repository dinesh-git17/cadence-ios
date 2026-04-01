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
            .accessibilityHidden(true)
    }
}
