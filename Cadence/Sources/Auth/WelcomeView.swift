import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var showEmailAuth = false

    var body: some View {
        ZStack {
            Color.cadenceBgBase.ignoresSafeArea()
            backgroundDecoration
            content
        }
    }

    // MARK: - Background Decoration

    private var backgroundDecoration: some View {
        ZStack {
            Circle()
                .fill(Color.cadencePrimaryLight)
                .frame(width: 320, height: 320)
                .offset(x: 100, y: -300)
            Circle()
                .fill(Color.cadencePrimaryFaint)
                .frame(width: 200, height: 200)
                .offset(x: -120, y: 200)
            Circle()
                .fill(Color.cadencePrimary.opacity(0.12))
                .frame(width: 120, height: 120)
                .offset(x: -100, y: 20)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            wordmark
            Spacer()
            heroSection
            Spacer()
            authStack
        }
        .padding(.horizontal, CadenceSpacing.xl)
        .padding(.vertical, CadenceSpacing.xxl)
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("Cadence")
                .font(.cadenceTitleLarge)
                .foregroundColor(.cadenceTextPrimary)
                .kerning(0.88)
            Text(".")
                .font(.cadenceTitleLarge)
                .foregroundColor(.cadencePrimary)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.md) {
            Text("CYCLE TRACKING, TOGETHER")
                .font(.cadenceCaptionSmall)
                .fontWeight(.medium)
                .foregroundColor(.cadencePrimary)
                .kerning(1.32)

            (Text("Your rhythm, ")
                .font(.cadenceDisplay)
                .foregroundColor(.cadenceTextPrimary)
                + Text("shared")
                .font(.cadenceTitleItalic)
                .foregroundColor(.cadencePrimary)
                + Text(" with someone who cares.")
                .font(.cadenceDisplay)
                .foregroundColor(.cadenceTextPrimary))
                .lineSpacing(4)

            Text("Track your cycle. Understand your body. Let your partner in — on your terms.")
                .font(.cadenceBodyMedium)
                .foregroundColor(.cadenceTextSecondary)
                .lineSpacing(4)
                .padding(.top, 2)
        }
    }

    // MARK: - Auth Stack

    private var authStack: some View {
        VStack(spacing: CadenceSpacing.md) {
            SignInWithAppleButton(.continue) { _ in
                // Request configuration handled by the coordinator
            } onCompletion: { _ in
                // Completion handled by the coordinator via delegate
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
            .overlay {
                // Transparent button overlay that triggers the actual auth flow
                Button {
                    Task { await authViewModel.signInWithApple() }
                } label: {
                    Color.clear
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .accessibilityLabel("Continue with Apple")
            }

            divider

            Button("Continue with Email") {
                showEmailAuth = true
            }
            .buttonStyle(GhostButtonStyle())

            if let error = authViewModel.error {
                Text(error.localizedDescription)
                    .font(.cadenceCaptionSmall)
                    .foregroundColor(.cadenceError)
                    .multilineTextAlignment(.center)
            }

            footer
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(authViewModel: authViewModel)
        }
    }

    private var divider: some View {
        HStack(spacing: CadenceSpacing.sm) {
            Rectangle()
                .fill(Color.cadenceBorderDefault)
                .frame(height: 0.5)
            Text("or")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceTextTertiary)
            Rectangle()
                .fill(Color.cadenceBorderDefault)
                .frame(height: 0.5)
        }
    }

    private static let termsURL = URL(string: "https://cadence.dineshd.dev/terms")
    private static let privacyURL = URL(string: "https://cadence.dineshd.dev/privacy")

    private var footer: some View {
        HStack(spacing: CadenceSpacing.xs) {
            Spacer()
            if let url = Self.termsURL {
                Link("Terms", destination: url)
            }
            Text("&")
                .foregroundColor(.cadenceTextTertiary)
            if let url = Self.privacyURL {
                Link("Privacy Policy", destination: url)
            }
            Spacer()
        }
        .font(.cadenceCaptionSmall)
        .foregroundColor(.cadenceTextTertiary)
        .tint(.cadencePrimary)
    }
}
