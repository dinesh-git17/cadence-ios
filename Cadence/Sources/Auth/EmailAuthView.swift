import PhosphorSwift
import SwiftUI

struct EmailAuthView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var isForgotPassword = false
    @State private var passwordVisible = false
    @State private var confirmPasswordVisible = false
    @State private var errorTrigger = 0

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password, confirmPassword
    }

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
            .onChange(of: authViewModel.error?.errorDescription) { _, description in
                if description != nil { errorTrigger += 1 }
            }
            .sensoryFeedback(.error, trigger: errorTrigger)
            .sensoryFeedback(.success, trigger: authViewModel.isAuthenticated)
        }
        .presentationDetents(isSignUp ? [.large] : [.medium, .large])
        .presentationBackground(Color.cadenceBgBase)
        .task { focusedField = .email }
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(spacing: CadenceSpacing.xl) {
            header
            fieldStack
            statusMessage
            submitButton
            bottomActions
        }
    }

    private var fieldStack: some View {
        VStack(spacing: CadenceSpacing.md) {
            emailField
            emailHint
            if !isForgotPassword {
                passwordField
                passwordHint
                if isSignUp {
                    confirmPasswordField
                    confirmPasswordHint
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        let title = isForgotPassword ? "Reset password" : (isSignUp ? "Create account" : "Sign in")
        let subtitle = isForgotPassword
            ? "Enter your email and we'll send you a reset link."
            : (isSignUp ? "Enter your email and choose a password." : "Enter your email and password.")
        return VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            Text(title).font(.cadenceTitleMedium).foregroundColor(.cadenceTextPrimary)
            Text(subtitle).font(.cadenceBodySmall).foregroundColor(.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Validation

    private var submitDisabled: Bool {
        if authViewModel.isLoading { return true }
        if isForgotPassword { return !EmailValidator.isValid(email) }
        if isSignUp {
            return !EmailValidator.isValid(email)
                || password.count < 6
                || confirmPassword.isEmpty
                || password != confirmPassword
        }
        return !EmailValidator.isValid(email) || password.count < 6
    }

    // MARK: - Status Message

    @ViewBuilder
    private var statusMessage: some View {
        if authViewModel.confirmationPending {
            statusText("We sent a confirmation link to \(email). Check your inbox to get started.", isError: false)
        } else if authViewModel.resetEmailSent {
            statusText("We sent a reset link to \(email). Check your inbox.", isError: false)
        } else if let error = authViewModel.error {
            statusText(error.localizedDescription, isError: true)
        }
    }

    private func statusText(_ message: String, isError: Bool) -> some View {
        Text(message)
            .font(.cadenceCaptionSmall)
            .foregroundColor(isError ? .cadenceError : .cadencePrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            if authViewModel.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(isForgotPassword ? "Send reset link" : (isSignUp ? "Create account" : "Sign in"))
            }
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
                forgotAndToggleActions
            }
        }
        .disabled(authViewModel.isLoading)
    }

    private var forgotAndToggleActions: some View {
        Group {
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
        .submitLabel(.next)
        .focused($focusedField, equals: .email)
        .onSubmit { focusedField = .password }
        .modifier(FieldContainerStyle())
    }

    @ViewBuilder
    private var emailHint: some View {
        if !email.isEmpty, !EmailValidator.isValid(email) {
            Text("Enter a valid email address.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var passwordField: some View {
        HStack(spacing: CadenceSpacing.sm) {
            passwordInput
            revealToggle($passwordVisible)
        }
        .modifier(FieldContainerStyle())
    }

    private var passwordInput: some View {
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
        .submitLabel(isSignUp ? .next : .go)
        .focused($focusedField, equals: .password)
        .onSubmit {
            if isSignUp {
                focusedField = .confirmPassword
            } else {
                Task { await submit() }
            }
        }
    }

    private var passwordHint: some View {
        Text("At least 6 characters")
            .font(.cadenceCaptionSmall)
            .foregroundColor(password.count >= 6 ? .cadenceSuccess : .cadenceTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmPasswordField: some View {
        HStack(spacing: CadenceSpacing.sm) {
            confirmPasswordInput
            revealToggle($confirmPasswordVisible)
        }
        .modifier(FieldContainerStyle())
    }

    private var confirmPasswordInput: some View {
        Group {
            if confirmPasswordVisible {
                TextField(
                    "Confirm password",
                    text: $confirmPassword,
                    prompt: Text("Confirm password")
                        .foregroundColor(.cadenceTextTertiary.opacity(0.6))
                )
            } else {
                SecureField(
                    "Confirm password",
                    text: $confirmPassword,
                    prompt: Text("Confirm password")
                        .foregroundColor(.cadenceTextTertiary.opacity(0.6))
                )
            }
        }
        .font(.cadenceBodyMedium)
        .foregroundColor(.cadenceTextPrimary)
        .textContentType(.newPassword)
        .submitLabel(.go)
        .focused($focusedField, equals: .confirmPassword)
        .onSubmit { Task { await submit() } }
    }

    @ViewBuilder
    private var confirmPasswordHint: some View {
        if !confirmPassword.isEmpty, password != confirmPassword {
            Text("Passwords do not match.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Shared Helpers

    private func revealToggle(_ visible: Binding<Bool>) -> some View {
        Button {
            visible.wrappedValue.toggle()
        } label: {
            (visible.wrappedValue ? Ph.eyeSlash.regular : Ph.eye.regular)
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .foregroundColor(.cadenceTextTertiary)
        }
        .frame(minWidth: 44)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func submit() async {
        if isForgotPassword {
            await authViewModel.resetPassword(email: email)
        } else if isSignUp {
            await authViewModel.signUpWithEmail(email: email, password: password)
        } else {
            await authViewModel.signInWithEmail(email: email, password: password)
        }
    }

    private func clearStatus() {
        authViewModel.clearError()
        authViewModel.confirmationPending = false
        authViewModel.resetEmailSent = false
        confirmPassword = ""
    }
}

// MARK: - Field Container

private struct FieldContainerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CadenceSpacing.md)
            .padding(.vertical, CadenceSpacing.md)
            .background(Color.cadenceBgWarm)
            .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CadenceRadius.md)
                    .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
            )
    }
}
