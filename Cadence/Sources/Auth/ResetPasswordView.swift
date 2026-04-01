import SwiftUI

struct ResetPasswordView: View {
    @Bindable var authViewModel: AuthViewModel

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordVisible = false

    private var passwordsMatch: Bool {
        newPassword == confirmPassword
    }

    private var submitDisabled: Bool {
        newPassword.count < 6 || !passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CadenceSpacing.xl) {
                header
                VStack(spacing: CadenceSpacing.md) {
                    newPasswordField
                    confirmPasswordField
                }
                statusMessage
                submitButton
            }
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.top, CadenceSpacing.xxl)
            .padding(.bottom, CadenceSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.cadenceBgBase)
    }

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

    @ViewBuilder
    private var statusMessage: some View {
        if !confirmPassword.isEmpty, !passwordsMatch {
            Text("Passwords do not match.")
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = authViewModel.error {
            Text(error.localizedDescription)
                .font(.cadenceCaptionSmall)
                .foregroundColor(.cadenceError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var submitButton: some View {
        Button("Update password") {
            Task { await authViewModel.updatePassword(newPassword) }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(submitDisabled)
    }

    private var newPasswordField: some View {
        HStack(spacing: CadenceSpacing.sm) {
            Group {
                if passwordVisible {
                    TextField(
                        "New password",
                        text: $newPassword,
                        prompt: Text("New password").foregroundColor(.cadenceTextTertiary.opacity(0.6))
                    )
                } else {
                    SecureField(
                        "New password",
                        text: $newPassword,
                        prompt: Text("New password").foregroundColor(.cadenceTextTertiary.opacity(0.6))
                    )
                }
            }
            .font(.cadenceBodyMedium)
            .foregroundColor(.cadenceTextPrimary)
            .textContentType(.newPassword)

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

    private var confirmPasswordField: some View {
        SecureField(
            "Confirm password",
            text: $confirmPassword,
            prompt: Text("Confirm password").foregroundColor(.cadenceTextTertiary.opacity(0.6))
        )
        .font(.cadenceBodyMedium)
        .foregroundColor(.cadenceTextPrimary)
        .textContentType(.newPassword)
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
