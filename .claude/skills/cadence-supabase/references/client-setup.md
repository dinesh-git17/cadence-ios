# Supabase Client Setup — Swift Reference

---

## Package Dependency

In `Package.swift` or Xcode SPM:

```
// URL: https://github.com/supabase/supabase-swift.git
// Version: from "2.0.0"
// Product: Supabase (includes Auth, Realtime, PostgREST, Functions)
```

Add `Supabase` as a dependency on the app target only (not on test targets unless
integration tests require it).

---

## Singleton — `Supabase.swift`

Create one file: `Sources/Services/Supabase.swift`. This is the only place in the
codebase that instantiates `SupabaseClient`.

```swift
import Supabase
import Foundation

// The shared client. Import this wherever Supabase is needed.
// Never instantiate SupabaseClient anywhere else in the codebase.
let supabase = SupabaseClient(
    supabaseURL: Secrets.supabaseURL,
    supabaseKey: Secrets.supabaseAnonKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            flowType: .pkce  // Required for native Apple Sign In + deep link safety
        )
    )
)

// Secrets reads credentials from Info.plist (populated via xcconfig).
// See env-config.md for xcconfig setup.
private enum Secrets {
    static var supabaseURL: URL {
        guard
            let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
            let url = URL(string: urlString)
        else {
            fatalError("SUPABASE_URL not found in Info.plist. Check xcconfig configuration.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist. Check xcconfig configuration.")
        }
        return key
    }
}
```

**Do not** pass `SupabaseClient` via SwiftUI environment or as an init parameter.
Import the module-level `supabase` constant directly in service types. This is intentional
for Cadence — the single client is a stable, session-managing singleton.
