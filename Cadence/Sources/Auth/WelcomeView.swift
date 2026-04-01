import AuthenticationServices
import PhosphorSwift
import SwiftUI

struct WelcomeView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var showEmailAuth = false
    @State private var errorTrigger = 0

    var body: some View {
        ZStack {
            Color.cadenceBgBase.ignoresSafeArea()
            backgroundDecoration
            content
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(authViewModel: authViewModel)
        }
        .onChange(of: authViewModel.error?.errorDescription) { _, description in
            if description != nil { errorTrigger += 1 }
        }
        .sensoryFeedback(.error, trigger: errorTrigger)
        .sensoryFeedback(.success, trigger: authViewModel.isAuthenticated)
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
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            heroSection
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            Spacer().frame(minHeight: CadenceSpacing.md)
            authStack
        }
        .padding(.horizontal, CadenceSpacing.xl)
        .padding(.top, CadenceSpacing.xxl)
        .padding(.bottom, CadenceSpacing.lg)
        .ignoresSafeArea(.keyboard)
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
                .font(.custom("PlayfairDisplay-Regular", size: 28))
                .foregroundColor(.cadenceTextPrimary)
                + Text("shared")
                .font(.custom("PlayfairDisplay-Italic", size: 28))
                .foregroundColor(.cadencePrimary)
                + Text("\nwith someone who cares.")
                .font(.custom("PlayfairDisplay-Regular", size: 28))
                .foregroundColor(.cadenceTextPrimary))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Text("Track your cycle. Understand your body.\nLet your partner in — on your terms.")
                .font(.cadenceBodyMedium)
                .foregroundColor(.cadenceTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    // MARK: - Auth Stack

    private var authStack: some View {
        VStack(spacing: CadenceSpacing.md) {
            appleSignInButton
            divider
            emailButton

            if let error = authViewModel.error {
                Text(error.localizedDescription)
                    .font(.cadenceCaptionSmall)
                    .foregroundColor(.cadenceError)
                    .multilineTextAlignment(.center)
            }

            trustSignal
            footer
        }
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.continue) { _ in
        } onCompletion: { _ in
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
        .overlay {
            if authViewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.cadenceSurfaceDark.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
            } else {
                Button {
                    Task { await authViewModel.signInWithApple() }
                } label: {
                    Color.clear
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .accessibilityLabel("Continue with Apple")
            }
        }
    }

    private var emailButton: some View {
        Button("Continue with Email") {
            showEmailAuth = true
        }
        .buttonStyle(GhostButtonStyle())
        .disabled(authViewModel.isLoading)
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

    private var trustSignal: some View {
        HStack(spacing: CadenceSpacing.xs) {
            Ph.shieldCheck.regular
                .renderingMode(.template)
                .frame(width: 12, height: 12)
                .foregroundColor(.cadenceTextTertiary)
            Text("Your data is encrypted on-device.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceTextTertiary)
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
