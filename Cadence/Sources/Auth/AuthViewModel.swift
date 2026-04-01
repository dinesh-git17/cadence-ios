import Auth
import Foundation
import Observation
import Supabase

@Observable
final class AuthViewModel {
    var session: Session?
    var isLoading = false
    var error: CadenceSupabaseError?
    var confirmationPending = false
    var resetEmailSent = false
    var passwordRecoveryActive = false

    private var authStateTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private let appleCoordinator = AppleSignInCoordinator()

    var isAuthenticated: Bool {
        session != nil
    }

    var currentUserID: UUID? {
        session?.user.id
    }

    init() {
        authStateTask = Task { [weak self] in
            for await (event, session) in await supabase.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                        case .initialSession, .signedIn, .tokenRefreshed:
                            self?.session = session
                        case .passwordRecovery:
                            self?.session = session
                            self?.passwordRecoveryActive = true
                        case .signedOut:
                            self?.session = nil
                        default:
                            break
                    }
                }
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Sign In with Apple

    func signInWithApple() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let session = try await appleCoordinator.signIn()
            self.session = session
        } catch let err as CadenceSupabaseError {
            error = err
            scheduleDismiss()
        } catch {
            self.error = .unknown(underlying: error)
            scheduleDismiss()
        }
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            self.error = CadenceSupabaseError.from(error)
            scheduleDismiss()
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        confirmationPending = false
        defer { isLoading = false }
        do {
            let redirectURL = URL(string: "https://cadence.dineshd.dev/auth/confirm")
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                redirectTo: redirectURL
            )
            if response.session == nil {
                confirmationPending = true
                scheduleDismiss()
            }
        } catch {
            self.error = CadenceSupabaseError.from(error)
            scheduleDismiss()
        }
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async {
        isLoading = true
        error = nil
        resetEmailSent = false
        defer { isLoading = false }
        do {
            let redirectURL = URL(string: "https://cadence.dineshd.dev/auth/reset")
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: redirectURL
            )
            resetEmailSent = true
            scheduleDismiss()
        } catch {
            self.error = CadenceSupabaseError.from(error)
            scheduleDismiss()
        }
    }

    func updatePassword(_ newPassword: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            passwordRecoveryActive = false
        } catch {
            self.error = CadenceSupabaseError.from(error)
            scheduleDismiss()
        }
    }

    // MARK: - Status Dismiss

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.error = nil
            self?.confirmationPending = false
            self?.resetEmailSent = false
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            EncryptionService.shared.clearKey()
            try await supabase.auth.signOut()
        } catch {
            self.error = CadenceSupabaseError.from(error)
        }
    }
}
