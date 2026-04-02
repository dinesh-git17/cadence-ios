import SwiftUI

@main
struct CadenceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Rewrites `cadence://` custom scheme URLs to their HTTPS equivalent
/// so `supabase.auth.handle` can process the auth code.
func resolveAuthURL(_ url: URL) -> URL {
    guard url.scheme == "cadence" else { return url }
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = "https"
    components?.host = "cadence.dineshd.dev"
    return components?.url ?? url
}

/// Extracts an invite token from a deep link URL.
/// Supports both formats:
///   - `https://cadence.dineshd.dev/invite/<token>`
///   - `cadence://invite?token=<token>`
func extractInviteToken(from url: URL) -> String? {
    // Path-based: /invite/<token>
    let pathComponents = url.pathComponents
    if pathComponents.count >= 2, pathComponents[pathComponents.count - 2] == "invite" {
        let token = pathComponents[pathComponents.count - 1]
        if !token.isEmpty { return token }
    }

    // Query-based: ?token=<value>
    if url.path.contains("invite") {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value {
            return token
        }
    }

    return nil
}
