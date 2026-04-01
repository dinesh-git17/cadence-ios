import Auth
import AuthenticationServices
import Foundation
import Supabase

enum CadenceSupabaseError: LocalizedError {
    case notAuthenticated
    case authCredentialMissing
    case inviteTokenInvalidOrExpired
    case notFound
    case networkUnavailable
    case invalidCredentials
    case emailAlreadyRegistered
    case emailNotConfirmed
    case rateLimited
    case weakPassword(reasons: [String])
    case serverError(statusCode: Int, message: String)
    case userCancelled
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
            case .notAuthenticated:
                "You're not signed in. Please sign in and try again."
            case .authCredentialMissing:
                "Sign-in credential is missing. Please try again."
            case .inviteTokenInvalidOrExpired:
                "This invite link has expired or has already been used."
            case .notFound:
                "The requested data was not found."
            case .networkUnavailable:
                "No network connection. Please check your connection and try again."
            case .invalidCredentials:
                "Invalid email or password."
            case .emailAlreadyRegistered:
                "An account with this email already exists. Try signing in instead."
            case .emailNotConfirmed:
                "Please confirm your email address before signing in."
            case .rateLimited:
                "Too many attempts. Please wait a moment and try again."
            case let .weakPassword(reasons):
                "Password is too weak: \(reasons.joined(separator: ", "))."
            case let .serverError(_, message):
                "Something went wrong — \(message)"
            case .userCancelled:
                nil
            case .unknown:
                "Something went wrong. Please try again."
        }
    }

    static func from(_ error: Error) -> Self {
        if let cadenceError = error as? Self {
            return cadenceError
        }
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            return .userCancelled
        }
        if let authError = error as? AuthError {
            return fromAuth(authError)
        }
        if let postgrestError = error as? PostgrestError {
            return fromPostgREST(postgrestError)
        }

        let nsError = error as NSError
        let isOffline = nsError.code == NSURLErrorNotConnectedToInternet
            || nsError.code == NSURLErrorNetworkConnectionLost
        if nsError.domain == NSURLErrorDomain, isOffline {
            return .networkUnavailable
        }

        return .unknown(underlying: error)
    }

    private static func fromAuth(_ error: AuthError) -> Self {
        switch error {
            case let .weakPassword(_, reasons):
                .weakPassword(reasons: reasons)
            case let .api(_, errorCode, _, _):
                fromAuthErrorCode(errorCode, message: error.message)
            default:
                .serverError(statusCode: 0, message: error.message)
        }
    }

    private static func fromAuthErrorCode(_ code: ErrorCode, message: String) -> Self {
        switch code {
            case .invalidCredentials:
                .invalidCredentials
            case .userAlreadyExists, .emailExists:
                .emailAlreadyRegistered
            case .emailNotConfirmed:
                .emailNotConfirmed
            case .overRequestRateLimit, .overEmailSendRateLimit:
                .rateLimited
            default:
                .serverError(statusCode: 0, message: message)
        }
    }

    private static func fromPostgREST(_ error: PostgrestError) -> Self {
        switch error.code {
            case "PGRST116":
                .notFound
            default:
                .serverError(
                    statusCode: Int(error.code ?? "0") ?? 0,
                    message: error.message
                )
        }
    }
}
