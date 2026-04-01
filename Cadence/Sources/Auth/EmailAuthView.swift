import SwiftUI

struct EmailAuthView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            formContent
                .padding(.horizontal, CadenceSpacing.lg)
                .padding(.top, CadenceSpacing.xl)
                .background(Color.cadenceBgBase)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .font(.cadenceBodySmall)
                            .foregroundColor(.cadenceTextTertiary)
                    }
                }
                .onChange(of: authViewModel.isAuthenticated) { _, authenticated in
                    if authenticated { dismiss() }
                }
        }
    }

    private var formContent: some View {
        VStack(spacing: CadenceSpacing.xl) {
            header
            VStack(spacing: CadenceSpacing.md) {
                emailField
                passwordField
            }
            errorMessage
            submitButton
            toggleModeButton
            Spacer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            Text(isSignUp ? "Create account" : "Sign in")
                .font(.cadenceTitleMedium)
                .foregroundColor(.cadenceTextPrimary)
            Text(isSignUp
                ? "Enter your email and choose a password."
                : "Enter your email and password.")
                .font(.cadenceBodySmall)
                .foregroundColor(.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let error = authViewModel.error {
            Text(error.localizedDescription)
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
        Button(isSignUp ? "Create account" : "Sign in") {
            Task { await submit() }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(email.isEmpty || password.count < 6)
    }

    private var toggleModeLabel: String {
        isSignUp
            ? "Already have an account? Sign in"
            : "Don't have an account? Create one"
    }

    private var toggleModeButton: some View {
        Button(toggleModeLabel) {
            withAnimation { isSignUp.toggle() }
            authViewModel.error = nil
        }
        .font(.cadenceBodySmall)
        .foregroundColor(.cadencePrimary)
    }

    private var emailField: some View {
        TextField("Email", text: $email)
            .font(.cadenceBodyMedium)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, CadenceSpacing.md)
            .padding(.vertical, CadenceSpacing.md)
            .background(Color.cadenceBgWarm)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.md)
                    .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
            )
    }

    private var passwordField: some View {
        SecureField("Password", text: $password)
            .font(.cadenceBodyMedium)
            .textContentType(isSignUp ? .newPassword : .password)
            .padding(.horizontal, CadenceSpacing.md)
            .padding(.vertical, CadenceSpacing.md)
            .background(Color.cadenceBgWarm)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.md)
                    .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
            )
    }

    private func submit() async {
        if isSignUp {
            await authViewModel.signUpWithEmail(email: email, password: password)
        } else {
            await authViewModel.signInWithEmail(email: email, password: password)
        }
    }
}
