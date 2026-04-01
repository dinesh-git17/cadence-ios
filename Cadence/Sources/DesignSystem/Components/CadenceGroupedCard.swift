import SwiftUI

/// Container for grouped list rows. Provides bg-warm background, border, and radius-lg.
struct CadenceGroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.lg)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
    }
}

/// A single row inside CadenceGroupedCard. Handles internal padding and separator.
/// Set showSeparator: false on the last row.
struct CadenceGroupedRow<Content: View>: View {
    var showSeparator: Bool = true
    let content: Content

    init(showSeparator: Bool = true, @ViewBuilder content: () -> Content) {
        self.showSeparator = showSeparator
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, CadenceSpacing.md)
            if showSeparator {
                Rectangle()
                    .fill(Color.cadencePrimaryFaint)
                    .frame(height: 0.5)
                    .padding(.leading, CadenceSpacing.md)
            }
        }
    }
}
