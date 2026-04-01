# Swift Implementations — Deep Linking

## DeepLinkRouter — Full Implementation

```swift
import Foundation
import Combine

@MainActor
final class DeepLinkRouter: ObservableObject {

    // Stored when a link arrives before auth is complete.
    // Cleared after processing (success or error).
    @Published var pendingInviteToken: String?
    @Published var alert: DeepLinkAlert?

    enum DeepLinkAlert: Identifiable {
        case invalidToken
        case expiredToken
        case alreadyUsed
        case alreadyConnected
        case networkError

        var id: String { String(describing: self) }

        var title: String {
            switch self {
            case .invalidToken:    return "Invalid Invite Link"
            case .expiredToken:    return "Invite Link Expired"
            case .alreadyUsed:    return "Link Already Used"
            case .alreadyConnected: return "Already Connected"
            case .networkError:   return "Something Went Wrong"
            }
        }

        var message: String {
            switch self {
            case .invalidToken:
                return "This invite link isn't valid. Ask your partner to send a new one."
            case .expiredToken:
                return "This invite link has expired — links are valid for 7 days. Ask your partner to send a new one."
            case .alreadyUsed:
                return "This invite link has already been used. Ask your partner to send a new one."
            case .alreadyConnected:
                return "You're already connected to a partner in Cadence."
            case .networkError:
                return "Something went wrong — check your connection and try again."
            }
        }
    }

    private let tokenService: InviteTokenService

    init(tokenService: InviteTokenService = InviteTokenService()) {
        self.tokenService = tokenService
    }

    // Primary entry point — called by onOpenURL and notification delegate.
    func handle(url: URL) {
        switch parse(url) {
        case .invite(let token):
            pendingInviteToken = token
        case .none:
            break   // Not a recognised deep link path — app opens to last state.
        }
    }

    // Call this when:
    // (a) auth state transitions to .authenticated (covers the pending token case), or
    // (b) onboarding completion handler runs.
    // Safe to call with no pending token — it's a no-op.
    func processStoredTokenIfNeeded(
        existingConnection: PartnerConnection?
    ) async {
        guard let token = pendingInviteToken else { return }
        if existingConnection != nil {
            pendingInviteToken = nil
            alert = .alreadyConnected
            return
        }
        await validateAndConnect(token: token)
    }

    private func validateAndConnect(token: String) async {
        do {
            _ = try await tokenService.acceptInvite(token: token)
            pendingInviteToken = nil
            // Post a notification so RootView/PartnerViewModel can refresh
            // connection state from Supabase.
            NotificationCenter.default.post(
                name: .partnerConnectionEstablished, object: nil
            )
        } catch InviteTokenError.invalidToken {
            pendingInviteToken = nil
            alert = .invalidToken
        } catch InviteTokenError.expiredToken {
            pendingInviteToken = nil
            alert = .expiredToken
        } catch InviteTokenError.alreadyUsed {
            pendingInviteToken = nil
            alert = .alreadyUsed
        } catch InviteTokenError.alreadyConnected {
            pendingInviteToken = nil
            alert = .alreadyConnected
        } catch {
            // Don't clear pendingInviteToken on network errors —
            // user can retry by tapping the link again.
            alert = .networkError
        }
    }

    // MARK: - URL Parsing

    private enum ParsedDeepLink {
        case invite(token: String)
    }

    private func parse(_ url: URL) -> ParsedDeepLink? {
        guard url.scheme == "https",
              url.host == "cadence.dineshd.dev" else { return nil }
        let parts = url.pathComponents   // Always starts with "/"
        // Expect: ["/" , "invite", "<token>"]
        guard parts.count == 3,
              parts[1] == "invite",
              !parts[2].isEmpty else { return nil }
        return .invite(token: parts[2])
    }
}

extension Notification.Name {
    static let partnerConnectionEstablished = Notification.Name(
        "com.cadenceapp.partnerConnectionEstablished"
    )
}
```

---

## InviteTokenService — Edge Function Client

The partner cannot query `invite_links` directly (RLS blocks it). All token
validation goes through the `accept-invite` Supabase Edge Function, which runs
the validate + create connection + mark used steps atomically.

```swift
import Foundation

enum InviteTokenError: Error {
    case invalidToken
    case expiredToken
    case alreadyUsed
    case alreadyConnected
    case httpError(Int)
    case decodingError
}

struct AcceptInviteResponse: Decodable {
    let trackerUserId: String
    let trackerDisplayName: String
}

struct AcceptInviteErrorResponse: Decodable {
    let error: String
}

final class InviteTokenService {

    private let supabaseURL: URL
    private let supabaseAnonKey: String

    init() {
        // Pull from your config layer (e.g. Info.plist keys or a Secrets enum).
        self.supabaseURL = URL(string: AppConfig.supabaseURL)!
        self.supabaseAnonKey = AppConfig.supabaseAnonKey
    }

    func acceptInvite(token: String) async throws -> AcceptInviteResponse {
        let url = supabaseURL
            .appendingPathComponent("functions/v1/accept-invite")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentSessionJWT())", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(["token": token])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw InviteTokenError.httpError(-1)
        }

        switch http.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let result = try? decoder.decode(AcceptInviteResponse.self, from: data) else {
                throw InviteTokenError.decodingError
            }
            return result
        case 400:
            guard let errBody = try? JSONDecoder().decode(
                AcceptInviteErrorResponse.self, from: data
            ) else { throw InviteTokenError.httpError(400) }
            switch errBody.error {
            case "invalid_token":    throw InviteTokenError.invalidToken
            case "expired_token":    throw InviteTokenError.expiredToken
            case "already_used":     throw InviteTokenError.alreadyUsed
            case "already_connected": throw InviteTokenError.alreadyConnected
            default:                 throw InviteTokenError.httpError(400)
            }
        default:
            throw InviteTokenError.httpError(http.statusCode)
        }
    }

    // Returns the current Supabase session JWT.
    // Replace with your actual Supabase auth client call.
    private func currentSessionJWT() -> String {
        SupabaseAuthManager.shared.currentSession?.accessToken ?? ""
    }
}
```

---

## Edge Function Contract (for backend implementation)

The Edge Function must:
1. Authenticate the calling user via the `Authorization` JWT
2. Verify `invite_links` row: `token = $1 AND used = false AND expires_at > now()`
3. Verify the caller is NOT already in `partner_connections`
4. In a single transaction: insert `partner_connections`, set `invite_links.used = true`
5. Return the tracker's `display_name` for the confirmation screen

**Success response (200):**
```json
{ "tracker_user_id": "uuid", "tracker_display_name": "Alex" }
```

**Error responses (400):**
```json
{ "error": "invalid_token" }
{ "error": "expired_token" }
{ "error": "already_used" }
{ "error": "already_connected" }
```

The Edge Function runs as a service-role client (bypasses RLS), so it can
read `invite_links` freely. The caller's JWT establishes who the partner is.

---

## AppNotificationDelegate — Full Implementation

```swift
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let router: DeepLinkRouter

    init(router: DeepLinkRouter) {
        self.router = router
    }

    // Called when user taps a notification while app is in background or closed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        guard let urlString = userInfo["deep_link"] as? String,
              let url = URL(string: urlString) else {
            // No deep link in payload — just open app to last state.
            return
        }

        Task { @MainActor in
            self.router.handle(url: url)
        }
    }

    // Called when a notification arrives while app is in foreground.
    // Show the banner anyway (default iOS behaviour suppresses it).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

**Wire in CadenceApp.init():**
```swift
@main
struct CadenceApp: App {
    @StateObject private var deepLinkRouter: DeepLinkRouter
    private let notificationDelegate: AppNotificationDelegate

    init() {
        let router = DeepLinkRouter()
        _deepLinkRouter = StateObject(wrappedValue: router)
        notificationDelegate = AppNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deepLinkRouter)
                .onOpenURL { url in
                    deepLinkRouter.handle(url: url)
                }
        }
    }
}
```

---

## Pending Token Processing in RootView

Call `processStoredTokenIfNeeded` in the appropriate place in `RootView` so
the token is processed as soon as the user is authenticated:

```swift
struct RootView: View {
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject var authState: AuthStateManager
    @StateObject var partnerVM = PartnerViewModel()

    var body: some View {
        Group {
            switch authState.state {
            case .unauthenticated:
                WelcomeView()
            case .authenticated:
                MainTabView()
                    .task(id: authState.state) {
                        // Process any pending invite token now that we're authed.
                        await deepLinkRouter.processStoredTokenIfNeeded(
                            existingConnection: partnerVM.currentConnection
                        )
                    }
            }
        }
        .alert(item: $deepLinkRouter.alert) { alertType in
            Alert(
                title: Text(alertType.title),
                message: Text(alertType.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
```
