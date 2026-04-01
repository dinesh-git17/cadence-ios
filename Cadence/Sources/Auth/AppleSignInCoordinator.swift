import AuthenticationServices
import CryptoKit
import Supabase

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    private var rawNonce = ""
    private var continuation: CheckedContinuation<Session, Error>?

    func signIn() async throws -> Session {
        rawNonce = Self.generateNonce()
        let hashedNonce = Self.sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = hashedNonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: CadenceSupabaseError.authCredentialMissing)
            continuation = nil
            return
        }

        let nonce = rawNonce
        let fullName = credential.fullName
        Task {
            do {
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )

                // Apple only returns name on first sign-in — persist immediately.
                if let givenName = fullName?.givenName {
                    let displayName = [givenName, fullName?.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    try? await supabase.from("users")
                        .update(["display_name": displayName])
                        .eq("id", value: session.user.id.uuidString)
                        .execute()
                }

                continuation?.resume(returning: session)
            } catch {
                continuation?.resume(throwing: CadenceSupabaseError.from(error))
            }
            continuation = nil
        }
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: CadenceSupabaseError.from(error))
        continuation = nil
    }

    // MARK: - Helpers

    private static func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            for random in randoms {
                if remaining == 0 { return result }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
