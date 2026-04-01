import SwiftUI

struct EmailAuthView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isForgotPassword = false
    @State private var passwordVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                formContent
                    .padding(.horizontal, CadenceSpacing.lg)
                    .padding(.top, CadenceSpacing.xl)
                    .padding(.bottom, CadenceSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
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
        .presentationDetents([.large])
        .presentationBackground(Color.cadenceBgBase)
    }

    private var formContent: some View {
        VStack(spacing: CadenceSpacing.xl) {
            header
            if isForgotPassword {
                emailField
            } else {
                VStack(spacing: CadenceSpacing.md) {
                    emailField
                    passwordField
                }
            }
            statusMessage
            submitButton
            bottomActions
        }
    }

    // MARK: - Header

    private var headerTitle: String {
        if isForgotPassword { return "Reset password" }
        return isSignUp ? "Create account" : "Sign in"
    }

    private var headerSubtitle: String {
        if isForgotPassword { return "Enter your email and we'll send you a reset link." }
        return isSignUp
            ? "Enter your email and choose a password."
            : "Enter your email and password."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            Text(headerTitle)
                .font(.cadenceTitleMedium)
                .foregroundColor(.cadenceTextPrimary)
            Text(headerSubtitle)
                .font(.cadenceBodySmall)
                .foregroundColor(.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Message

    @ViewBuilder
    private var statusMessage: some View {
        if authViewModel.confirmationPending {
            Text("Check your email to confirm your account.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadencePrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if authViewModel.resetEmailSent {
            Text("Check your email for a password reset link.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadencePrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = authViewModel.error {
            Text(error.localizedDescription)
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Submit

    private var submitButtonLabel: String {
        if isForgotPassword { return "Send reset link" }
        return isSignUp ? "Create account" : "Sign in"
    }

    private var submitDisabled: Bool {
        if isForgotPassword { return email.isEmpty }
        return email.isEmpty || password.count < 6
    }

    private var submitButton: some View {
        Button(submitButtonLabel) {
            Task { await submit() }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(submitDisabled)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: CadenceSpacing.sm) {
            if isForgotPassword {
                Button("Back to sign in") {
                    withAnimation {
                        isForgotPassword = false
                        clearStatus()
                    }
                }
                .font(.cadenceBodySmall)
                .foregroundColor(.cadencePrimary)
            } else {
                if !isSignUp {
                    Button("Forgot password?") {
                        withAnimation {
                            isForgotPassword = true
                            clearStatus()
                        }
                    }
                    .font(.cadenceBodySmall)
                    .foregroundColor(.cadenceTextTertiary)
                }

                Button(isSignUp
                    ? "Already have an account? Sign in"
                    : "Don't have an account? Create one"
                ) {
                    withAnimation { isSignUp.toggle() }
                    clearStatus()
                }
                .font(.cadenceBodySmall)
                .foregroundColor(.cadencePrimary)
            }
        }
    }

    // MARK: - Fields

    private var emailField: some View {
        TextField(
            "Email",
            text: $email,
            prompt: Text("Email").foregroundColor(.cadenceTextTertiary.opacity(0.6))
        )
        .font(.cadenceBodyMedium)
        .foregroundColor(.cadenceTextPrimary)
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
        HStack(spacing: CadenceSpacing.sm) {
            Group {
                if passwordVisible {
                    TextField(
                        "Password",
                        text: $password,
                        prompt: Text("Password").foregroundColor(.cadenceTextTertiary.opacity(0.6))
                    )
                } else {
                    SecureField(
                        "Password",
                        text: $password,
                        prompt: Text("Password").foregroundColor(.cadenceTextTertiary.opacity(0.6))
                    )
                }
            }
            .font(.cadenceBodyMedium)
            .foregroundColor(.cadenceTextPrimary)
            .textContentType(isSignUp ? .newPassword : .password)

            Button {
                passwordVisible.toggle()
            } label: {
                Image(systemName: passwordVisible ? "eye.slash" : "eye")
                    .font(.cadenceBodySmall)
                    .foregroundColor(.cadenceTextTertiary)
            }
        }
        .padding(.horizontal, CadenceSpacing.md)
        .padding(.vertical, CadenceSpacing.md)
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.md)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func submit() async {
        if isForgotPassword {
            await authViewModel.resetPassword(email: email)
            if authViewModel.resetEmailSent {
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    isForgotPassword = false
                }
            }
        } else if isSignUp {
            await authViewModel.signUpWithEmail(email: email, password: password)
            if authViewModel.confirmationPending {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { isSignUp = false }
            }
        } else {
            await authViewModel.signInWithEmail(email: email, password: password)
        }
    }

    private func clearStatus() {
        authViewModel.error = nil
        authViewModel.confirmationPending = false
        authViewModel.resetEmailSent = false
    }
}
