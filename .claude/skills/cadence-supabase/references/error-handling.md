# Cadence Error Handling — Swift Reference

---

## CadenceSupabaseError

Define this in `Sources/Services/CadenceSupabaseError.swift`. It wraps all Supabase
errors into a Cadence-specific type that the SwiftUI layer can display safely.

```swift
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
            return "You're not signed in. Please sign in and try again."
        case .authCredentialMissing:
            return "Sign-in credential is missing. Please try again."
        case .inviteTokenInvalidOrExpired:
            return "This invite link has expired or has already been used."
        case .notFound:
            return "The requested data was not found."
        case .networkUnavailable:
            return "No network connection. Please check your connection and try again."
        case .serverError(_, let message):
            return "Something went wrong — \(message)"
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    // Map from any thrown error into a CadenceSupabaseError.
    static func from(_ error: Error) -> CadenceSupabaseError {
        if let cadenceError = error as? CadenceSupabaseError {
            return cadenceError
        }

        // Supabase PostgREST errors — check for status codes
        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "PGRST116":  // zero rows returned by .single()
                return .notFound
            default:
                return .serverError(
                    statusCode: Int(postgrestError.code ?? "0") ?? 0,
                    message: postgrestError.message
                )
            }
        }

        // Auth errors
        if (error as NSError).domain == NSURLErrorDomain {
            let code = (error as NSError).code
            if code == NSURLErrorNotConnectedToInternet || code == NSURLErrorNetworkConnectionLost {
                return .networkUnavailable
            }
        }

        return .unknown(underlying: error)
    }
}
```

---

## ViewModel Error Pattern

ViewModels display errors using `CadenceSupabaseError`. Never pass raw Supabase errors
or expose `PostgrestError` to the view layer.

```swift
// In a ViewModel action:
func saveLog(_ log: InsertCycleLog) async {
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
        try await CycleLogService().insertCycleLog(log)
    } catch let e as CadenceSupabaseError {
        error = e
    } catch {
        self.error = .unknown(underlying: error)
    }
}
```

---

## What Not to Do

- **Do not use `try?` on Supabase calls** unless you are intentionally discarding
  the error (e.g., teardown paths where you have already signed out).
- **Do not expose `PostgrestError` or `AuthError` to views** — these contain
  implementation details and server-internal messages not suitable for display.
- **Do not swallow errors silently** — even if you don't show a UI error, log them
  in debug builds with `#if DEBUG print(error) #endif`.
