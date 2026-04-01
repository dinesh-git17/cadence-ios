# Invite Link Generation and Acceptance — Swift Reference

---

## Invite Link Generation

```swift
// MARK: - InviteService.swift

actor InviteService {
    private let supabase: SupabaseClient
    static let linkExpirySeconds: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    func generateInviteLink(for trackerUserId: UUID) async throws -> URL {
        // Generate a cryptographically random token
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            throw InviteError.tokenGenerationFailed
        }
        let token = bytes.map { String(format: "%02x", $0) }.joined()

        let expiresAt = Date().addingTimeInterval(Self.linkExpirySeconds)

        // Write to invite_links
        try await supabase
            .from("invite_links")
            .insert([
                "tracker_user_id": trackerUserId.uuidString,
                "token":           token,
                "expires_at":      ISO8601DateFormatter.shared.string(from: expiresAt),
                "used":            false
            ])
            .execute()

        // Construct deep link
        guard let url = URL(string: "cadenceapp://invite/\(token)") else {
            throw InviteError.urlConstructionFailed
        }
        return url
    }
}
```

---

## Presenting the Share Sheet (SwiftUI)

```swift
struct InvitePartnerView: View {
    @StateObject private var vm = InviteViewModel()

    var body: some View {
        // ...
        Button("Send invite link") {
            Task { await vm.generateAndShare() }
        }
        .sheet(isPresented: $vm.showingShareSheet) {
            if let url = vm.inviteURL {
                ShareSheet(items: [
                    "Join me on Cadence — track our cycle together:",
                    url
                ])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

---

## Generation Edge Cases

- Only one invite link should be active per tracker at a time. Before inserting,
  check for existing unexpired, unused rows and delete them, or mark them `used = true`.
- The tracker can revoke and regenerate from Profile/Settings. Regeneration creates
  a new token; the old link immediately becomes stale.

---

## Invite Link Acceptance

```swift
// MARK: - App entry point (App.swift or SceneDelegate)

// In your SwiftUI App:
.onOpenURL { url in
    Task {
        await inviteHandler.handle(url)
    }
}

// MARK: - InviteAcceptanceHandler.swift

@MainActor
final class InviteAcceptanceHandler: ObservableObject {
    @Published var pendingInvite: ValidatedInvite?
    @Published var inviteError: InviteAcceptanceError?

    private let supabase: SupabaseClient
    private let authService: AuthService

    func handle(_ url: URL) async {
        // Step 1 — Parse the URL
        guard url.scheme == "cadenceapp",
              url.host == "invite",
              let token = url.pathComponents.last,
              !token.isEmpty else {
            return // Not an invite URL — ignore
        }

        // Step 2 — Validate the token
        do {
            let nowString = ISO8601DateFormatter.shared.string(from: Date())
            let inviteResponse = try await supabase
                .from("invite_links")
                .select()
                .eq("token", token)
                .eq("used", false)
                .gt("expires_at", nowString)
                .maybeSingle()
                .execute()

            guard let invite = try? inviteResponse.value as InviteLink else {
                inviteError = .expiredOrInvalid
                return
            }

            pendingInvite = ValidatedInvite(inviteId: invite.id, trackerUserId: invite.trackerUserId, token: token)

        } catch {
            inviteError = .networkError(error)
        }
    }

    func acceptInvite(_ invite: ValidatedInvite) async {
        guard let currentUserId = authService.currentUserId else {
            inviteError = .notAuthenticated
            return
        }

        guard currentUserId != invite.trackerUserId else {
            inviteError = .cannotConnectToSelf
            return
        }

        do {
            // Step 3 — Create partner_connections row
            try await supabase
                .from("partner_connections")
                .insert([
                    "tracker_user_id": invite.trackerUserId.uuidString,
                    "partner_user_id": currentUserId.uuidString,
                    "status":          "active"
                ])
                .execute()

            // Step 4 — Mark invite_links row as used
            try await supabase
                .from("invite_links")
                .update(["used": true])
                .eq("id", invite.inviteId.uuidString)
                .execute()

            // Step 5 — Clear pending state and trigger navigation
            pendingInvite = nil
            NotificationCenter.default.post(name: .partnerConnected, object: nil)

        } catch {
            inviteError = .connectionFailed(error)
        }
    }
}
```

---

## Error Types

```swift
enum InviteAcceptanceError: LocalizedError {
    case expiredOrInvalid
    case networkError(Error)
    case notAuthenticated
    case cannotConnectToSelf
    case connectionFailed(Error)
}

struct ValidatedInvite {
    let inviteId: UUID
    let trackerUserId: UUID
    let token: String
}
```

---

## Acceptance Edge Cases

- If the user receiving the invite is not yet signed in, deep link into onboarding
  and resume acceptance after account creation. Store the token in `@AppStorage` or
  `UserDefaults` across the onboarding flow.
- A user cannot connect to themselves (`cannotConnectToSelf` guard).
- If a `partner_connections` row already exists for this pair (e.g. reconnecting
  after disconnect), check for and handle the duplicate before inserting.
- The token validation and connection creation are two separate Supabase calls.
  There is a TOCTOU window. Accept this as an acceptable race for MVP — the RLS
  policy on `invite_links` prevents malicious reuse.
