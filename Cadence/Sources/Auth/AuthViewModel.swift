import Foundation
import Observation
import Supabase

@Observable
final class AuthViewModel {
    var session: Session?
    var isLoading = false
    var error: CadenceSupabaseError?

    private var authStateTask: Task<Void, Never>?
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
        } catch {
            self.error = .unknown(underlying: error)
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
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.signUp(email: email, password: password)
        } catch {
            self.error = CadenceSupabaseError.from(error)
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
