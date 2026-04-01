import SwiftUI

struct CadenceHeroCard: View {
    let cycleDay: Int
    let phaseLabel: String
    var pills: [String] = []
    var isLogged: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            decorativeCircles
            cardContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cadencePrimary)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.xxl))
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cycle day \(cycleDay), \(phaseLabel)\(isLogged ? ", logged today" : "")")
    }

    private var decorativeCircles: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: 160, y: -50)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 90, height: 90)
                .offset(x: 210, y: 60)
        }
        .allowsHitTesting(false)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            Text("CYCLE DAY")
                .font(.cadenceLabel)
                .foregroundColor(.white.opacity(0.8))
                .kerning(0.8)

            HStack(alignment: .bottom, spacing: CadenceSpacing.sm) {
                Text("\(cycleDay)")
                    .font(.cadenceDisplay)
                    .foregroundColor(.white)
                Text(phaseLabel)
                    .font(.cadenceBodySmall)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 4)
            }

            pillsRow
        }
        .padding(CadenceSpacing.lg)
    }

    private var pillsRow: some View {
        HStack(spacing: CadenceSpacing.xs) {
            ForEach(pills, id: \.self) { pill in
                heroPill(pill)
            }
            if isLogged {
                heroPill("Logged today")
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
    }

    private func heroPill(_ text: String) -> some View {
        Text(text)
            .font(.cadenceCaptionSmall)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
    }
}
