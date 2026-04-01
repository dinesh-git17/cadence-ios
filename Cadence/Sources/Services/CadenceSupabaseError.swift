import Foundation
import Supabase

enum CadenceSupabaseError: LocalizedError {
    case notAuthenticated
    case authCredentialMissing
    case inviteTokenInvalidOrExpired
    case notFound
    case networkUnavailable
    case serverError(statusCode: Int, message: String)
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
            case let .serverError(_, message):
                "Something went wrong — \(message)"
            case .unknown:
                "Something went wrong. Please try again."
        }
    }

    static func from(_ error: Error) -> Self {
        if let cadenceError = error as? Self {
            return cadenceError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
                case "PGRST116":
                    return .notFound
                default:
                    return .serverError(
                        statusCode: Int(postgrestError.code ?? "0") ?? 0,
                        message: postgrestError.message
                    )
            }
        }

        let nsError = error as NSError
        let isOffline = nsError.code == NSURLErrorNotConnectedToInternet
            || nsError.code == NSURLErrorNetworkConnectionLost
        if nsError.domain == NSURLErrorDomain, isOffline {
            return .networkUnavailable
        }

        return .unknown(underlying: error)
    }
}
