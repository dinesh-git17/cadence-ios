# Cadence Auth Patterns — Swift Reference

Auth lives in `Sources/Services/AuthService.swift` and a corresponding
`Sources/ViewModels/AuthViewModel.swift` that owns the session state for SwiftUI.

---

## AuthViewModel — Session State

```swift
import Supabase
import Observation

// iOS 17+ @Observable. For iOS 16 targets, replace with @ObservableObject + @Published.
@Observable
final class AuthViewModel {
    var session: Session? = nil
    var isLoading: Bool = false
    var error: CadenceSupabaseError? = nil

    private var authStateTask: Task<Void, Never>? = nil

    init() {
        // Restore session on launch — the Swift SDK persists to Keychain automatically.
        // Subscribe to future state changes.
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

    var isAuthenticated: Bool { session != nil }
    var currentUserID: UUID? { session?.user.id }
}
```

---

## Sign In with Apple

The native Apple Sign In flow requires:
1. Generate a random nonce locally.
2. Hash the nonce with SHA-256 and pass the *hashed* nonce to `ASAuthorizationAppleIDProvider`.
3. Apple returns an identity token signed against the hashed nonce.
4. Pass the identity token and the *raw* (unhashed) nonce to Supabase `signInWithIdToken`.

```swift
import AuthenticationServices
import CryptoKit
import Supabase

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    private var rawNonce: String = ""
    private var continuation: CheckedContinuation<Session, Error>? = nil

    // Call this from your sign-in button action.
    func signIn() async throws -> Session {
        rawNonce = generateNonce()
        let hashedNonce = sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = hashedNonce  // Apple receives the HASHED nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: CadenceSupabaseError.authCredentialMissing)
            return
        }

        Task {
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: rawNonce  // Supabase receives the RAW nonce — not hashed
                    )
                )
                continuation?.resume(returning: session)
            } catch {
                continuation?.resume(throwing: CadenceSupabaseError.from(error))
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: CadenceSupabaseError.from(error))
    }

    // MARK: - Helpers

    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

**Important:** Apple only returns the user's name and email on the *first* sign-in.
After account creation, call `supabase.from("users").update(...)` immediately within
the same auth flow to persist `display_name` using `credential.fullName` before
Apple stops providing it.

---

## Email Auth

```swift
// Sign up
func signUpWithEmail(email: String, password: String) async throws {
    do {
        try await supabase.auth.signUp(email: email, password: password)
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}

// Sign in
func signInWithEmail(email: String, password: String) async throws {
    do {
        try await supabase.auth.signInWithPassword(email: email, password: password)
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

---

## Sign Out

```swift
func signOut() async throws {
    do {
        try await supabase.auth.signOut()
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

Session is cleared from Keychain automatically by the SDK on sign out.

---

## Session Persistence

The Swift SDK persists the session to the iOS Keychain automatically. No additional
configuration is required. On next launch, `authStateChanges` will emit
`.initialSession` with the restored session if one exists and the token is still valid
(or successfully refreshed). The `AuthViewModel` handles this in `init()`.
