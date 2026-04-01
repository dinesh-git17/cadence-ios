---
name: universal-links
description: >
  Implement Universal Links and deep linking correctly in the Cadence iOS app.
  Use this skill before writing ANY code that touches Universal Links, the
  apple-app-site-association file, Associated Domains entitlements, onOpenURL
  handlers, invite link processing, or notification-tap routing. Triggers on:
  "implement deep linking", "set up Universal Links", "handle invite link",
  "partner invite flow", "onOpenURL", "AASA", "associated domains",
  "notification deep link", or any work on the partner connection URL flow.
---

# Universal Links & Deep Linking — Cadence

## How Universal Links Work

Universal Links let iOS open your app directly when the user taps an HTTPS link
to your domain — from Messages, Mail, WhatsApp, or any other app. They do NOT
fire from the Safari URL bar (that always opens the browser).

**The four-part contract iOS enforces:**

1. **AASA file** — you host a JSON file at
   `https://cadenceapp.com/.well-known/apple-app-site-association` that declares
   which URL paths belong to your app.

2. **Associated Domains entitlement** — your app's `.entitlements` declares it
   claims `cadenceapp.com`.

3. **Apple's CDN fetch** — iOS fetches the AASA via Apple's CDN
   (`app-site-association.cdn-apple.com`), not directly from your server. This
   means AASA changes propagate slowly (~24h CDN TTL). You cannot force a
   re-fetch on user devices.

4. **`onOpenURL` handler** — your SwiftUI app root receives and routes the URL.

If any part of this chain breaks, iOS silently falls back to opening Safari.
Universal Links never produce an error — they just stop working.

**Common failure modes:**

| Failure | Symptom | Fix |
|---|---|---|
| AASA not at `/.well-known/` path | Link opens Safari | Host file at exact path, return 200 (no redirect) |
| Wrong `Content-Type` header | iOS ignores AASA | Must be `application/json` |
| `appIDs` uses wrong Team ID | No match, opens Safari | Team ID is 10-char alphanumeric prefix, not Bundle ID prefix |
| CDN cached old AASA | New paths don't work | Wait 24h or test via `swcutil dl` on device |
| Entitlement domain mismatch | Xcode build warning, no UL | Domain in entitlement must exactly match AASA domain |
| Testing on simulator | Never works | Use physical device only |

---

## AASA File

See `references/aasa-spec.md` for the full file and hosting requirements.

**Quick reference — the exact path pattern for Cadence:**

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.cadenceapp.ios"],
        "components": [
          { "/": "/invite/*", "comment": "Partner invite deep links" }
        ]
      },
      {
        "appID": "ABCDE12345.com.cadenceapp.ios",
        "paths": ["/invite/*"]
      }
    ]
  }
}
```

The `components` block is iOS 14+. The `paths` block is the iOS 9–13 fallback.
Both live in the same `details` array. Replace `ABCDE12345` with the actual
Team ID from the Apple Developer portal (Settings → Membership).

---

## Associated Domains Entitlement

In Xcode: Target → Signing & Capabilities → + Capability → Associated Domains.

The entry in `Cadence.entitlements`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:cadenceapp.com</string>
</array>
```

**For local development on a physical device**, add the `?mode=developer` variant.
This tells iOS to fetch the AASA directly from your server, bypassing Apple's CDN:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:cadenceapp.com</string>
    <string>applinks:cadenceapp.com?mode=developer</string>
</array>
```

Developer mode requires the device to be registered to your development team and
have developer mode enabled in Settings → Privacy & Security. It only activates
on debug builds. It does not affect production or TestFlight behaviour.

---

## App Store / TestFlight / Local Differences

| Context | Bundle ID | AASA `appIDs` entry needed | Entitlement |
|---|---|---|---|
| App Store | `com.cadenceapp.ios` | `TEAMID.com.cadenceapp.ios` | `applinks:cadenceapp.com` |
| TestFlight | `com.cadenceapp.ios` (same) | Same — no change needed | Same |
| Debug (device) | `com.cadenceapp.ios` | Same — no change needed | Add `?mode=developer` variant |
| Simulator | n/a | Universal Links don't work | Use custom URL scheme for sim testing |

TestFlight uses the same bundle ID as the App Store build. There is no `.beta`
suffix unless you deliberately configure a separate scheme. If you do create a
separate beta bundle ID (e.g. `com.cadenceapp.ios.beta`), add it to the AASA
`appIDs` array alongside the production ID.

---

## SwiftUI App Root — `onOpenURL`

```swift
@main
struct CadenceApp: App {
    @StateObject private var deepLinkRouter = DeepLinkRouter()
    @StateObject private var authState = AuthStateManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(deepLinkRouter)
                .environmentObject(authState)
                .onOpenURL { url in
                    deepLinkRouter.handle(url: url)
                }
        }
    }
}
```

**Routing logic in `DeepLinkRouter`:**

```swift
@MainActor
final class DeepLinkRouter: ObservableObject {

    @Published var pendingInviteToken: String?
    @Published var alert: DeepLinkAlert?

    enum DeepLinkAlert: Identifiable {
        case invalidToken, expiredToken, alreadyConnected
        var id: String { String(describing: self) }
    }

    // Called by onOpenURL and by the notification delegate — same entry point.
    func handle(url: URL) {
        guard let deepLink = parse(url) else { return }
        switch deepLink {
        case .invite(let token):
            pendingInviteToken = token
        }
    }

    // Call this after auth completes (in onboarding completion handler or
    // in RootView's .task when auth transitions to .authenticated).
    func processStoredToken(
        isAuthenticated: Bool,
        existingConnection: PartnerConnection?
    ) async {
        guard isAuthenticated, let token = pendingInviteToken else { return }
        if existingConnection != nil {
            pendingInviteToken = nil
            alert = .alreadyConnected
            return
        }
        await validateAndConnect(token: token)
    }

    private enum DeepLink {
        case invite(token: String)
    }

    private func parse(_ url: URL) -> DeepLink? {
        guard url.host == "cadenceapp.com" else { return nil }
        let parts = url.pathComponents          // ["/" , "invite", "<token>"]
        guard parts.count == 3,
              parts[1] == "invite",
              !parts[2].isEmpty else { return nil }
        return .invite(token: parts[2])
    }
}
```

**Three entry-state scenarios:**

| User state when link tapped | Behaviour |
|---|---|
| Not logged in | `pendingInviteToken` stored. Onboarding runs. After auth, `processStoredToken` is called. |
| Logged in, no partner | `pendingInviteToken` stored. `processStoredToken` runs immediately. |
| Logged in, already has partner | Token cleared, `alreadyConnected` alert shown. |

---

## Invite Token Validation

> **RLS note:** The PRD's `invite_links` RLS policy restricts reads to the tracker
> who created the link. A partner cannot query that table directly. Validation
> MUST go through a Supabase Edge Function. This also makes the accept operation
> atomic (validate + create connection + mark used in one server-side transaction).

See `references/swift-implementations.md` for the full `InviteTokenService` Swift
code and the Edge Function contract.

**The Edge Function contract:**

```
POST /functions/v1/accept-invite
Authorization: Bearer <partner_supabase_jwt>
{ "token": "<invite_token>" }

200 → { "tracker_user_id": "uuid", "tracker_display_name": "string" }
400 → { "error": "invalid_token" | "expired_token" | "already_used" | "already_connected" }
```

**On 200:** Create `partner_connections` row, navigate to connected state.
**On 4xx:** Parse the `error` field, show appropriate user-facing message.
Do not expose the raw error string to the user — map it to friendly copy.

**Error copy mapping:**

| Error code | User-facing message |
|---|---|
| `invalid_token` | "This invite link isn't valid. Ask your partner to send a new one." |
| `expired_token` | "This invite link has expired (links are valid for 7 days). Ask your partner to send a new one." |
| `already_used` | "This invite link has already been used. Ask your partner to send a new one." |
| `already_connected` | "You're already connected to a partner in Cadence." |

---

## Notification Deep Links — Unified Handler

Notification taps and Universal Link taps must route through the same
`DeepLinkRouter`. Wire the notification delegate at app startup:

```swift
@main
struct CadenceApp: App {
    @StateObject private var deepLinkRouter = DeepLinkRouter()
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
                .onOpenURL { url in deepLinkRouter.handle(url: url) }
        }
    }
}
```

```swift
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: DeepLinkRouter

    init(router: DeepLinkRouter) { self.router = router }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let urlString = response.notification.request.content
                .userInfo["deep_link"] as? String,
              let url = URL(string: urlString) else { return }
        Task { @MainActor in self.router.handle(url: url) }
    }
}
```

The Edge Function APNs payload must include `deep_link` in the custom payload:

```json
{
  "aps": { "alert": { "title": "...", "body": "..." }, "sound": "default" },
  "deep_link": "https://cadenceapp.com/today"
}
```

For MVP, notification deep links route to the app root (Today screen). The
`parse()` function in `DeepLinkRouter` should return `nil` for any URL that
isn't an invite link — the app will simply open to its last state, which is
the correct behaviour for log reminders and phase change alerts.

---

## Pre-Submission Testing Checklist

Read `references/aasa-spec.md` → "Verification" section for full tool commands.

- [ ] AASA reachable: `curl -I https://cadenceapp.com/.well-known/apple-app-site-association`
      → HTTP 200, `Content-Type: application/json`, no redirects
- [ ] AASA JSON is valid and matches the spec in `references/aasa-spec.md`
- [ ] Validate with Apple's tool: `swcutil verify --domain cadenceapp.com` (run on
      a physical device via Xcode → Devices console, or use the AASA validator at
      https://yurl.chayev.com or branch.io/resources/aasa-validator)
- [ ] Physical device test: tap an `https://cadenceapp.com/invite/test123` link
      in iMessage — must open Cadence, not Safari
- [ ] Not-installed test: install nothing, tap link — must redirect to App Store
- [ ] TestFlight build test: install TestFlight build, tap link — same behaviour
- [ ] Auth-before-link test: tap invite link while logged out → complete onboarding
      → connection established (pending token was preserved)
- [ ] Already-connected test: tap invite link with existing partner → correct
      error message shown
- [ ] Expired token test: use a token with `expires_at` in the past → correct
      error message
- [ ] Simulator is NOT sufficient for any of the above — use a physical device

---

## Reference Files

| File | When to read |
|---|---|
| `references/aasa-spec.md` | Before writing or modifying the AASA file or its hosting config |
| `references/swift-implementations.md` | Before implementing `InviteTokenService`, `DeepLinkRouter.validateAndConnect`, or `PartnerConnectionService` |
