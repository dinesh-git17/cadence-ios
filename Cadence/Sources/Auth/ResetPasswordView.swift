import PhosphorSwift
import SwiftUI

struct ResetPasswordView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordVisible = false
    @State private var errorTrigger = 0

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case newPassword, confirmPassword
    }

    private var passwordsMatch: Bool {
        newPassword == confirmPassword
    }

    private var submitDisabled: Bool {
        authViewModel.isLoading
            || newPassword.count < 6
            || !passwordsMatch
    }

    var body: some View {
        NavigationStack {
            scrollContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.cadenceBgBase, for: .navigationBar)
                .toolbar { cancelButton }
                .onChange(of: authViewModel.error?.errorDescription) { _, description in
                    if description != nil { errorTrigger += 1 }
                }
                .sensoryFeedback(.error, trigger: errorTrigger)
                .sensoryFeedback(.success, trigger: authViewModel.passwordRecoveryActive)
        }
        .task { focusedField = .newPassword }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: CadenceSpacing.xl) {
                header
                fieldStack
                statusMessage
                submitButton
            }
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.top, CadenceSpacing.xxl)
            .padding(.bottom, CadenceSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.cadenceBgBase.ignoresSafeArea())
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                authViewModel.passwordRecoveryActive = false
                Task { await authViewModel.signOut() }
            }
            .font(.cadenceBodySmall)
            .foregroundColor(.cadenceTextTertiary)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            Text("Set new password")
                .font(.cadenceTitleMedium)
                .foregroundColor(.cadenceTextPrimary)
            Text("Choose a new password for your account.")
                .font(.cadenceBodySmall)
                .foregroundColor(.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldStack: some View {
        VStack(spacing: CadenceSpacing.md) {
            newPasswordField
            passwordHint
            confirmPasswordField
            confirmPasswordHint
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let error = authViewModel.error {
            Text(error.localizedDescription)
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await authViewModel.updatePassword(newPassword) }
        } label: {
            if authViewModel.isLoading {
                ProgressView().tint(.white)
            } else {
                Text("Update password")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(submitDisabled)
    }

    // MARK: - Fields

    private var newPasswordField: some View {
        HStack(spacing: CadenceSpacing.sm) {
            newPasswordInput
            revealToggle
        }
        .modifier(ResetFieldContainerStyle())
    }

    private var newPasswordInput: some View {
        Group {
            if passwordVisible {
                TextField(
                    "New password",
                    text: $newPassword,
                    prompt: Text("New password")
                        .foregroundColor(.cadenceTextTertiary.opacity(0.6))
                )
            } else {
                SecureField(
                    "New password",
                    text: $newPassword,
                    prompt: Text("New password")
                        .foregroundColor(.cadenceTextTertiary.opacity(0.6))
                )
            }
        }
        .font(.cadenceBodyMedium)
        .foregroundColor(.cadenceTextPrimary)
        .textContentType(.newPassword)
        .submitLabel(.next)
        .focused($focusedField, equals: .newPassword)
        .onSubmit { focusedField = .confirmPassword }
    }

    private var revealToggle: some View {
        Button {
            passwordVisible.toggle()
        } label: {
            (passwordVisible ? Ph.eyeSlash.regular : Ph.eye.regular)
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .foregroundColor(.cadenceTextTertiary)
        }
        .frame(minWidth: 44)
        .contentShape(Rectangle())
    }

    private var passwordHint: some View {
        Text("At least 6 characters")
            .font(.cadenceCaptionSmall)
            .foregroundColor(newPassword.count >= 6 ? .cadenceSuccess : .cadenceTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmPasswordField: some View {
        SecureField(
            "Confirm password",
            text: $confirmPassword,
            prompt: Text("Confirm password")
                .foregroundColor(.cadenceTextTertiary.opacity(0.6))
        )
        .font(.cadenceBodyMedium)
        .foregroundColor(.cadenceTextPrimary)
        .textContentType(.newPassword)
        .submitLabel(.go)
        .focused($focusedField, equals: .confirmPassword)
        .onSubmit {
            guard !submitDisabled else { return }
            Task { await authViewModel.updatePassword(newPassword) }
        }
        .modifier(ResetFieldContainerStyle())
    }

    @ViewBuilder
    private var confirmPasswordHint: some View {
        if !confirmPassword.isEmpty, !passwordsMatch {
            Text("Passwords do not match.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Field Container

private struct ResetFieldContainerStyle: ViewModifier {
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
