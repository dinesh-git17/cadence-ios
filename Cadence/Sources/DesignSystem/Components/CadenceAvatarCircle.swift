import SwiftUI

struct CadenceAvatarCircle: View {
    let initials: String
    /// 30pt for nav bar, 48pt for profile header
    var diameter: CGFloat = 30

    var body: some View {
        Circle()
            .fill(Color.cadencePrimaryLight)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initials.prefix(2).uppercased())
                    .font(.custom("DMSans-Medium", size: diameter * 0.37))
                    .foregroundColor(.cadenceTextOnLight)
            )
            .accessibilityLabel("Profile")
            .accessibilityAddTraits(.isButton)
    }
}
