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
