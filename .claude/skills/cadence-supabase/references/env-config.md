# Cadence Environment Configuration — Reference

---

## xcconfig Setup

Create two xcconfig files (not committed to git — add to `.gitignore`):

```
Config/Debug.xcconfig
Config/Release.xcconfig
```

Each file contains:

```
// Debug.xcconfig
SUPABASE_URL = https://your-project-ref.supabase.co
SUPABASE_ANON_KEY = your-anon-key-here
```

For CI/CD, inject these as environment variables and write the xcconfig at build time.
Never commit credential files to the repository.

---

## xcconfig Linkage in Xcode

In Xcode:
1. Select the project in the Project Navigator.
2. Under **Project** (not Target), set **Configurations > Debug** to `Debug.xcconfig`
   and **Release** to `Release.xcconfig`.

---

## Info.plist Wiring

In `Info.plist`, add two keys that reference the build setting variables:

```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

At runtime, `Bundle.main.infoDictionary?["SUPABASE_URL"]` resolves to the value
from the active xcconfig. The `Secrets` enum in `Supabase.swift` reads these values.

---

## Multi-Environment Strategy

| Environment | xcconfig | Supabase project | Notes |
|---|---|---|---|
| Local development | `Debug.xcconfig` | Dev project | Use a throwaway Supabase project for dev |
| CI / TestFlight | `Staging.xcconfig` | Staging project | Injected via CI secrets (e.g., GitHub Actions) |
| App Store | `Release.xcconfig` | Production project | Production credentials never in repo |

Use separate Supabase projects for dev vs. production. Sharing a production database
with development traffic is unsafe.

---

## gitignore Entries

Add to `.gitignore`:

```
Config/Debug.xcconfig
Config/Release.xcconfig
Config/Staging.xcconfig
```

Provide a `Config/Debug.xcconfig.template` in the repo with placeholder values
so new team members know what to create:

```
// Debug.xcconfig.template — copy to Debug.xcconfig and fill in real values
SUPABASE_URL = https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY = YOUR_ANON_KEY
```
