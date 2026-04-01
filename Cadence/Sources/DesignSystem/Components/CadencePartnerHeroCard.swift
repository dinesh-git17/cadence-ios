import SwiftUI

struct CadencePartnerHeroCard: View {
    let partnerName: String
    let cycleDay: Int
    let phaseLabel: String
    var pills: [String] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            decorativeCircles
            cardContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cadenceSurfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.xxl))
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(partnerName)'s cycle, day \(cycleDay), \(phaseLabel)")
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
            Text(partnerName.uppercased())
                .font(.cadenceLabel)
                .foregroundColor(.white.opacity(0.5))
                .kerning(0.8)

            HStack(alignment: .bottom, spacing: CadenceSpacing.sm) {
                Text("Day \(cycleDay)")
                    .font(.cadenceTitleLarge)
                    .foregroundColor(.white)
                Text(phaseLabel)
                    .font(.cadenceCaption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 3)
            }

            if !pills.isEmpty {
                HStack(spacing: CadenceSpacing.xs) {
                    ForEach(pills, id: \.self) { pill in
                        partnerPill(pill)
                    }
                }
            }
        }
        .padding(CadenceSpacing.lg)
    }

    private func partnerPill(_ text: String) -> some View {
        Text(text)
            .font(.cadenceCaptionSmall)
            .fontWeight(.medium)
            .foregroundColor(.cadencePrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.cadencePrimary.opacity(0.2))
            .clipShape(Capsule())
    }
}
