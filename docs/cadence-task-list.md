# Cadence — Implementation Task List

**Format:** Each task is one Claude Code session. Complete tasks in order within each phase — later tasks depend on earlier ones.
**Skills:** Each task lists which SKILL.md files Claude Code should load before starting.
**Supabase MCP:** Available in Claude Code sessions. Use it to query, create tables, write migrations, and check RLS policies directly — no need to copy SQL manually.
**Branch naming:** `feature/task-{number}-{short-description}` e.g. `feature/task-0.7-xcode-setup`

---

## Phase 0 — Foundation ✓ COMPLETE

> Everything in this phase must exist before a single line of app code is written. Tasks 0.1–0.6 are manual (cannot be done by Claude Code). Tasks 0.7–0.15 are Claude Code sessions.

---

### ~~0.1 — Confirm and Register Domain Name~~

**Type:** Manual
**Owner:** You

Decide on and register the domain for Cadence. The domain is used for:

- Universal Links (`yourdomain.com/invite/{token}`)
- The `apple-app-site-association` file
- Privacy policy URL (required for App Store submission)

The placeholder throughout all docs is `cadence.dineshd.dev`. Register via Namecheap, Cloudflare, or equivalent.

**Done when:** Domain is registered and DNS is live.

---

### ~~0.2 — Apple Developer — Register App ID + Capabilities~~

**Type:** Manual
**Owner:** You

In the Apple Developer portal, create a new App ID with the following capabilities enabled:

- Push Notifications
- Associated Domains (required for Universal Links)
- Sign in with Apple

Bundle ID convention: `com.{yourname}.cadence` — decide this now, it cannot be changed later without re-creating the Xcode project.

**Done when:** App ID exists in the portal with all three capabilities enabled.

---

### ~~0.3 — Apple Developer — Create Push Notification Key (.p8)~~

**Type:** Manual
**Owner:** You

In the Apple Developer portal → Certificates, Identifiers & Profiles → Keys, create a new key with the Apple Push Notifications service (APNs) capability enabled. Download the `.p8` file immediately — it can only be downloaded once.

Store securely. You will need:

- The `.p8` file contents
- The Key ID
- Your Team ID

These are required for both the Supabase Auth configuration and the Supabase Edge Functions that send push notifications.

**Done when:** `.p8` key downloaded and stored securely.

---

### ~~0.4 — Apple Developer — Configure Sign in with Apple Service ID~~

**Type:** Manual
**Owner:** You

Create a Services ID in the Apple Developer portal for Sign in with Apple. This is a separate identifier from the App ID. Configure the return URL to point to your Supabase project's auth callback URL (`https://{your-supabase-project}.supabase.co/auth/v1/callback`).

You will need your Supabase project URL before completing this step — create the Supabase project first if you haven't already, then come back to this task.

**Done when:** Services ID created and return URL configured.

---

### ~~0.5 — Create Supabase Project + Configure Auth~~

**Type:** Manual (Supabase dashboard)
**Owner:** You

1. Create a new Supabase project in the US (us-east-1) region.
2. Note your project URL and anon key — you'll need these for task 0.9.
3. In Auth → Providers → Apple: configure with your Team ID, Services ID, Key ID, and `.p8` key contents from tasks 0.3 and 0.4.
4. In Auth → Providers → Email: enable email auth with email confirmation.
5. Set the site URL to your domain.

**Done when:** Supabase project exists, Apple auth and email auth are both configured and testable.

---

### ~~0.6 — Run Initial Schema Migration~~

**Type:** Claude Code (Supabase MCP)
**Skills:** `cadence-supabase`

Create all seven Cadence tables with the correct schema and Row Level Security policies. Use the Supabase MCP in Claude Code to execute these directly — no need to copy SQL manually.

Tables to create:

- `users` (id, email, display_name, is_tracker, created_at)
- `cycle_profiles` (user_id, last_period_date, avg_cycle_length, avg_period_duration, seeded_cycle_length, seeded_period_duration)
- `cycle_logs` (id, user_id, log_date, period_flow, mood, energy, symptoms, sleep_quality, intimacy_logged, intimacy_protected, notes — all health fields will store encrypted ciphertext)
- `sharing_settings` (user_id, share_period, share_symptoms, share_mood, share_energy — all default false)
- `partner_connections` (id, tracker_user_id, partner_user_id, connected_at, status)
- `invite_links` (id, tracker_user_id, token, expires_at, used)
- `shared_logs` (id, tracker_user_id, partner_user_id, log_date, period_flow, symptoms, mood, energy, cycle_day, cycle_phase, predicted_next_period)

RLS policies:

- `cycle_logs`: read/write by owning user only
- `shared_logs`: read by connected partner, write by tracker only
- `sharing_settings`: read by both connected users, write by tracker only
- `partner_connections`: read by both users in the connection
- `invite_links`: read/write by tracker who created it

Save migration file to `/supabase/migrations/001_initial_schema.sql` in the repo.

**Done when:** All tables exist in Supabase, RLS is active and tested, migration file committed.

---

### ~~0.7 — Create Xcode Project~~

**Type:** Manual
**Owner:** You

Create a new Xcode project with the following configuration:

- Template: App (SwiftUI, SwiftUI lifecycle)
- Product name: Cadence
- Bundle identifier: `com.{yourname}.cadence` (matches task 0.2)
- Language: Swift
- Minimum deployments: iOS 26.0
- Include tests: Yes (Unit Tests + UI Tests targets)

After creation, enable capabilities in Signing & Capabilities:

- Push Notifications
- Associated Domains (add `applinks:yourdomain.com`)
- Keychain Sharing (required for CryptoKit key storage)

Set the build scheme to a real device or simulator with iOS 26+.

**Done when:** Project builds cleanly on iOS 26 simulator with all three capabilities enabled.

---

### ~~0.8 — Add Swift Package Manager Dependencies~~

**Type:** Manual / Claude Code
**Skills:** None needed

Add three packages via File → Add Package Dependencies in Xcode:

| Package        | URL                                               | Version       |
| -------------- | ------------------------------------------------- | ------------- |
| supabase-swift | `https://github.com/supabase/supabase-swift`      | Latest stable |
| PhosphorSwift  | `https://github.com/phosphor-icons/PhosphorSwift` | Latest stable |
| danger-swift   | `https://github.com/danger/swift`                 | Latest stable |

After adding, verify each package resolves without conflicts and the project still builds.

**Done when:** All three packages resolve, project builds clean.

---

### ~~0.9 — Implement Secrets + Environment Config~~

**Type:** Claude Code
**Skills:** `cadence-supabase`

Implement the environment configuration pattern so Supabase credentials are never hardcoded. The standard SwiftUI approach:

1. Create `Config.xcconfig` (gitignored) with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
2. Create `Config.xcconfig.example` (committed) as a template with placeholder values
3. Wire both keys into `Info.plist` via build settings
4. Create a `Config.swift` file that reads them from the bundle at runtime
5. Create the `SupabaseClient` singleton using these values
6. Add `Config.xcconfig` to `.gitignore`

Every subsequent task that touches Supabase imports this singleton — it should never be re-created.

**Done when:** `SupabaseClient.shared` is accessible throughout the app, credentials are not in any committed file, project builds clean.

---

### ~~0.10 — Create GitHub Repo + Configure Settings~~

**Type:** Manual
**Owner:** You

Create the private GitHub repo and configure settings to match the locked decisions:

**General:**

- Visibility: Private
- Default branch: `main`
- Allow squash merging: On
- Allow merge commits: Off
- Allow rebase merging: Off
- Automatically delete head branches: On

**Branch protection on `main`:**

- Require PR before merging: On
- Required approving reviews: 0
- Dismiss stale reviews on new push: On
- Require status checks to pass: On (add checks after task 0.12)
- Require branches to be up to date: On
- Require linear history: On
- Allow force pushes: Off
- Allow deletions: Off
- Allow admin bypass: On

**Security:**

- Dependabot vulnerability alerts: On
- Dependabot security updates: On

Push the initial Xcode project commit to `main` after configuring.

**Done when:** Repo exists, settings configured, initial commit pushed to `main`.

---

### ~~0.11 — Add GitHub Actions Secrets~~

**Type:** Manual
**Owner:** You

In GitHub repo → Settings → Secrets and variables → Actions, add:

| Secret name         | Value                                                      |
| ------------------- | ---------------------------------------------------------- |
| `SUPABASE_URL`      | Your Supabase project URL                                  |
| `SUPABASE_ANON_KEY` | Your Supabase anon key                                     |
| `SUPABASE_DB_URL`   | Your Supabase DB connection string (for migration linting) |

For macOS build signing (add when CI build is first set up):
| Secret name | Value |
|---|---|
| `CERTIFICATES_P12` | Base64-encoded signing certificate |
| `CERTIFICATES_P12_PASSWORD` | Certificate password |
| `PROVISIONING_PROFILE` | Base64-encoded provisioning profile |

**Done when:** All secrets exist in GitHub Actions, accessible to workflows.

---

### ~~0.12 — Create CI Workflow Files + Dangerfile~~

**Type:** Claude Code
**Skills:** None needed

Create all CI configuration files. Reference the CI/CD Decisions doc for the full spec.

**Files to create:**

`.github/workflows/pr.yml` — runs on every PR:

- Build check (`xcodebuild build`) on macOS runner
- Unit test runner (`xcodebuild test`) on macOS runner
- SwiftLint on Linux runner
- Code coverage check (≥60% threshold) on macOS runner
- Supabase migration lint (`supabase db lint`) on Linux runner
- Danger PR comment table (aggregates all results) on Linux runner

`.github/workflows/main.yml` — runs on merge to main:

- Simulator smoke test (boots iOS 26 simulator, installs app, verifies launch)

`.github/workflows/scheduled.yml` — runs weekly on cron:

- SPM dependency vulnerability audit

`.github/labeler.yml` — file-based auto-label rules:

- `encryption` → `**/EncryptionService*`, `**/Crypto*`
- `partner-sharing` → `**/Partner*`, `**/SharedLog*`, `**/SharingSettings*`
- `prediction` → `**/Prediction*`, `**/CycleEngine*`
- `onboarding` → `**/Onboarding*`
- `supabase` → `supabase/**`, `**/migrations/**`
- `notifications` → `**/Notification*`
- `deep-links` → `**/DeepLink*`, `**/UniversalLink*`
- `design-system` → `**/Cadence+*`, `**/Theme*`, `**/Typography*`
- `ci` → `.github/**`
- Size labels based on lines changed (XS/S/M/L/XL)

`Dangerfile.swift` — aggregates CI results into the PR comment table:

```
| CI Check | Status | Comments |
```

**Done when:** All files committed, CI runs on a test PR, Danger posts the comment table.

---

### ~~0.13 — Register Custom Fonts in Info.plist~~

**Type:** Claude Code
**Skills:** `cadence-design-system`

Add Playfair Display and DM Sans font files to the Xcode project and register them in `Info.plist`.

Steps:

1. Download font files from Google Fonts: `PlayfairDisplay-Regular.ttf`, `PlayfairDisplay-Italic.ttf`, `PlayfairDisplay-Medium.ttf`, `DMSans-Regular.ttf`, `DMSans-Medium.ttf`
2. Add all five files to the Xcode project under a `Fonts/` group (ensure "Add to target: Cadence" is checked)
3. Add `UIAppFonts` key to `Info.plist` listing all five font filenames
4. Create a `Font+Cadence.swift` extension implementing the full type scale from the design spec
5. Write a simple test view to verify each font role renders correctly

**Done when:** `Font.cadence.titleLarge` and all other named roles resolve to the correct typefaces in a test view.

---

### ~~0.14 — Serve AASA File for Universal Links~~

**Type:** Manual + Claude Code
**Skills:** `cadence-deep-links`

Create and deploy the `apple-app-site-association` file to your domain so Universal Links can be established.

1. Use Claude Code to generate the correct AASA JSON for your bundle ID and the `/invite/{token}` path pattern
2. Deploy the file to `https://yourdomain.com/.well-known/apple-app-site-association`
3. Verify it's served over HTTPS with `Content-Type: application/json` (no redirect)
4. Validate using Apple's AASA validator tool

**Done when:** AASA file is live, validator passes, Associated Domains entitlement references the correct domain.

---

### ~~0.15 — Verify CI Passes on Empty PR~~

**Type:** Manual
**Owner:** You

Create a trivial test PR (e.g. add a comment to `README.md`) and verify:

- All CI checks run and pass
- Danger posts the PR comment table with correct format
- Auto-labeler applies the correct labels
- PR size label is applied
- Branch protection blocks merge if any check fails

Fix any issues before moving to Phase 1. A green CI pipeline on a trivial change is the proof that Phase 0 is complete.

**Done when:** All checks green, comment table posted, merge blocked by failing checks when tests are deliberately broken.

---

## Phase 1 — Core Infrastructure

> The shared layers that every feature depends on. Build these before any screen.

---

### 1.1 — Design System Tokens + Base Components

**Type:** Claude Code
**Skills:** `cadence-design-system`

Implement the complete Cadence design system as reusable SwiftUI primitives.

**Files to create:**

- `Theme/Color+Cadence.swift` — all colour tokens as `Color` extensions
- `Theme/Font+Cadence.swift` — full type scale as `Font` extensions
- `Theme/Spacing+Cadence.swift` — spacing and radius constants
- `Components/Buttons.swift` — `PrimaryButtonStyle`, `GhostButtonStyle`, `DestructiveTextButtonStyle`
- `Components/CadenceChip.swift` — selectable chip, default and selected states
- `Components/CadenceFlowRow.swift` — 5-button period flow selector
- `Components/CadenceEnergyRow.swift` — 3-button energy selector
- `Components/CadenceToggleRow.swift` — label + sub-label + toggle
- `Components/CadenceGroupedCard.swift` — grouped list card container
- `Components/CadenceIconTile.swift` — icon in tinted background square
- `Components/CadenceProgressDots.swift` — onboarding progress indicator with pill animation
- `Components/CadenceSectionHeader.swift` — uppercase label style section header
- `Components/CadenceAvatarCircle.swift` — initials circle
- `Components/HeroCard.swift` — tracker (coral) and partner (dark) variants
- `Theme/PhaseColor.swift` — maps `CyclePhase` enum to calendar strip colour

Write a `DesignSystemPreview.swift` file with SwiftUI previews for every component so the full system can be visually verified at a glance.

**Done when:** All components render correctly in previews, no hardcoded hex values anywhere.

---

### 1.2 — EncryptionService

**Type:** Claude Code
**Skills:** `cadence-encryption`

Implement the client-side AES-GCM encryption layer. This is the most critical infrastructure task — get it right before any data touches Supabase.

**Files to create:**

- `Services/EncryptionService.swift` — singleton with:
  - HKDF key derivation from server secret + user UUID
  - Keychain read/write for the derived key
  - `encrypt(_ plaintext: String) throws -> String`
  - `decrypt(_ ciphertext: String) throws -> String`
  - `EncryptionError` enum
- `Services/EncryptionService+Tests.swift` — unit tests:
  - Encrypt → decrypt round trip returns original value
  - Encrypted output is not equal to plaintext
  - Wrong key cannot decrypt ciphertext
  - Keychain persistence across service instantiations

**Important:** The server secret should be stored as a GitHub Actions secret and injected at build time via the same `.xcconfig` pattern as the Supabase credentials. Add `ENCRYPTION_SECRET` to task 0.11 if not already done.

**Done when:** All unit tests pass, Keychain read/write verified on simulator.

---

### 1.3 — Auth Flow (Sign in with Apple + Email)

**Type:** Claude Code
**Skills:** `cadence-supabase`

Implement authentication using Supabase Auth. This is the gate to the entire app.

**Files to create:**

- `Auth/AuthViewModel.swift` — ObservableObject with:
  - `@Published var authState: AuthState` (unauthenticated / authenticated / loading)
  - `func signInWithApple() async throws`
  - `func signInWithEmail(email: String, password: String) async throws`
  - `func signUp(email: String, password: String) async throws`
  - `func signOut() async throws`
  - Session restoration on app launch
- `Auth/WelcomeView.swift` — the welcome screen per the UI design spec:
  - Abstract coral circle geometry background (SwiftUI `Circle()` shapes, not images)
  - Wordmark in Playfair Display
  - Headline with italic "shared" in coral
  - "Continue with Apple" primary CTA (dark background)
  - "Continue with Email" ghost CTA
  - Terms and Privacy links in footer
- `Auth/EmailAuthView.swift` — email sign in / sign up form
- `App/RootView.swift` — route between WelcomeView, OnboardingView, and MainTabView based on auth state and onboarding completion flag

**Done when:** Can sign in with Apple and email on simulator, session persists across app restarts, root view routes correctly.

---

### 1.4 — Supabase Data Layer

**Type:** Claude Code
**Skills:** `cadence-supabase`, `cadence-encryption`

Implement all Supabase model structs and query functions. This is the data access layer that every feature will call.

**Files to create:**

- `Models/User.swift` — Codable struct
- `Models/CycleProfile.swift` — Codable struct
- `Models/CycleLog.swift` — Codable struct with encrypted field types
- `Models/SharingSettings.swift` — Codable struct
- `Models/PartnerConnection.swift` — Codable struct
- `Models/InviteLink.swift` — Codable struct
- `Models/SharedLog.swift` — Codable struct
- `Services/CycleLogService.swift` — async/await functions:
  - `func saveCycleLog(_ log: CycleLog) async throws` — encrypts all sensitive fields, writes to Supabase, then triggers shared_logs update
  - `func fetchTodayLog() async throws -> CycleLog?`
  - `func fetchLog(for date: Date) async throws -> CycleLog?`
  - `func fetchLogs(from: Date, to: Date) async throws -> [CycleLog]`
- `Services/UserService.swift` — create/fetch user record post-auth
- `Services/CycleProfileService.swift` — create/fetch/update cycle profile

**Done when:** Can write an encrypted CycleLog to Supabase and read it back, decrypted correctly, in a unit test.

---

## Phase 2 — Core Tracker Loop

> The daily habit. The thing a user does every single day.

---

### 2.1 — Onboarding Flow

**Type:** Claude Code
**Skills:** `cadence-onboarding`, `cadence-design-system`, `cadence-supabase`

Implement the complete onboarding flow for both tracker and partner paths. This is the first thing a new user sees after authentication.

**Files to create:**

- `Onboarding/OnboardingViewModel.swift` — NavigationPath coordinator accumulating all onboarding state
- `Onboarding/RoleSelectionView.swift` — two selection cards, branches to tracker or partner path
- `Onboarding/LastPeriodDateView.swift` — inline mini calendar (SwiftUI grid, not UIDatePicker), date display card
- `Onboarding/CycleLengthView.swift` — two picker rows (cycle length + period duration), defaults 28/5 days
- `Onboarding/SharingPreferencesView.swift` — toggle list, all off by default, note "All off by default. You can change this anytime."
- `Onboarding/InvitePartnerView.swift` — skippable, share sheet via `ShareLink`, "Skip for now" ghost text
- `Onboarding/NotificationsView.swift` — toggle list with sensible defaults, requests iOS permission on "Enter Cadence" tap
- `Onboarding/AcceptConnectionView.swift` — partner path only, shown when invite token is present

**Supabase writes at flow end (single async sequence):**

1. Create/update `users` record with `is_tracker` flag
2. Write `cycle_profiles` row with seed data (last period date, cycle length, period duration)
3. Write `sharing_settings` row with all defaults false
4. Register APNs device token if permission granted
5. If invite token present: validate and create `partner_connections`
6. Set `onboardingComplete = true` in UserDefaults

**Final CTA copy:** "Enter Cadence" — not "Done" or "Finish."

**Done when:** Complete tracker path and partner path navigable, all Supabase writes verified, onboarding complete flag gates re-entry correctly.

---

### 2.2 — Prediction Engine

**Type:** Claude Code
**Skills:** `cadence-prediction`

Implement the cycle prediction engine. Write this as a pure Swift module with no SwiftUI dependencies so it's fully unit-testable.

**Files to create:**

- `Engine/CyclePhase.swift` — enum: menstrual, follicular, ovulation, luteal
- `Engine/CycleRecord.swift` — struct: startDate, duration, cycleLength
- `Engine/PhaseInterval.swift` — struct: phase, startDate, endDate
- `Engine/PredictionEngine.swift`:
  - Input: `[CycleRecord]`
  - `var averageCycleLength: Double`
  - `var averagePeriodDuration: Double`
  - `func predictNextPeriodStart(from lastPeriodStart: Date) -> Date`
  - `func predictPhases(for cycleStartDate: Date) -> [PhaseInterval]`
  - `func fertileWindow(for cycleStartDate: Date) -> DateInterval`
  - `func confidenceTier(cycleCount: Int) -> ConfidenceTier`
  - Weighted rolling average — recent cycles weighted more heavily
- `Engine/CycleRecordBuilder.swift` — derives `[CycleRecord]` from raw `[CycleLog]` entries using the 14-day minimum gap rule
- `Engine/PredictionEngine+Tests.swift` — unit tests covering:
  - Standard 28-day cycle
  - Short cycle (21 days)
  - Long cycle (35 days)
  - Irregular cycles (varies 24–35 days)
  - 14-day spotting rule (new log within 14 days = continuation)
  - 60-day confidence flag
  - Cold start from onboarding seed data
  - Confidence tier transitions (0 / 1–2 / 3+ cycles)

**Done when:** All unit tests pass. This engine should have the highest test coverage of anything in the codebase.

---

### 2.3 — Today Screen

**Type:** Claude Code
**Skills:** `cadence-design-system`, `cadence-supabase`, `cadence-prediction`

Implement the Today screen — the screen users open every single day.

**Files to create:**

- `Features/Today/TodayViewModel.swift` — ObservableObject with:
  - `@Published var todayLog: CycleLog?`
  - `@Published var currentPhase: PhaseInterval?`
  - `@Published var cycleDay: Int`
  - `@Published var partnerData: SharedLog?`
  - `@Published var predictionConfidence: ConfidenceTier`
  - Loads today's log and partner's shared log on appear
- `Features/Today/TodayView.swift` — main screen:
  - Nav bar: "Today" (Playfair), avatar circle top-right (taps to Profile sheet)
  - Hero card (coral): cycle day in large Playfair, phase label, prediction pills. Updates to "✓ Logged today" pill once logged.
  - Unlogged state: dashed border log CTA card — "How are you feeling today?" + "Log today" button
  - Logged state: today's log summary card with "Edit" action
  - Partner card: always visible in both states
- `Features/Today/LogEntrySheet.swift` — bottom sheet:
  - Period flow: 5-button row (None / Spotting / Light / Medium / Heavy)
  - Mood: multi-select chips
  - Energy: 3-button row (Low / Medium / High)
  - Symptoms: multi-select chips + "more" to expand
  - Sleep, Sex/Intimacy, Notes: further down sheet via scroll
  - "Save log" coral button — encrypts and writes to Supabase, updates shared_logs
- `Features/Today/PartnerCard.swift` — shows partner's shared mood/energy chips, "hasn't logged yet" dashed state

**Done when:** Both unlogged and logged states render correctly, log entry saves encrypted data to Supabase, partner card shows live data.

---

### 2.4 — Calendar Screen

**Type:** Claude Code
**Skills:** `cadence-design-system`, `cadence-prediction`, `cadence-supabase`

Implement the Calendar screen including the custom calendar grid, phase visualisation, day tap detail, and insights section.

**Files to create:**

- `Features/Calendar/CalendarViewModel.swift` — ObservableObject with:
  - `@Published var selectedDate: Date`
  - `@Published var phases: [PhaseInterval]` — covering current + next 2 months
  - `@Published var loggedDates: Set<Date>`
  - `@Published var selectedDayLog: CycleLog?`
  - `@Published var insights: CycleInsights`
- `Features/Calendar/CalendarView.swift` — main screen with single scroll
- `Features/Calendar/CycleCalendarGrid.swift` — custom SwiftUI calendar grid (NOT `DatePicker` or UIKit):
  - 7-column grid, month navigation via chevron
  - Date states: default / today (coral circle) / selected (dark circle) / future (muted)
  - Logged dot: 4pt coral dot below date number
  - Phase strips: 3pt strips below each date (coral=period, dark coral=ovulation, tint=fertile, warm tint=luteal, none=follicular)
  - Future dates show predicted phase strips
  - Tapping a date updates `selectedDate`
- `Features/Calendar/DaySummaryCard.swift` — inline card below grid on tap:
  - Phase pill, date title, logged entry chips
  - "Edit" button opens `LogEntrySheet` pre-populated
- `Features/Calendar/InsightsSection.swift` — scrolls below calendar:
  - 2-column card grid
  - Average cycle length card
  - Average period duration card
  - Cycle length trend card (full-width, mini bar chart with SwiftUI Canvas or Path)
  - Most common symptoms card (chips)
  - Friendly empty states: "Log 1 more cycle to see your average length"

**Done when:** Calendar renders with correct phase strips for past and predicted dates, day tap shows summary, insights cards show real data.

---

## Phase 3 — Partner Feature

> The core differentiator. Build only after the tracker loop is solid.

---

### 3.1 — Partner Connection — Invite + Accept Flow

**Type:** Claude Code
**Skills:** `cadence-partner-sharing`, `cadence-deep-links`, `cadence-supabase`

Implement the invite link generation and acceptance flow — the moment a solo tracker becomes a couple on Cadence.

**Files to create:**

- `Features/Partner/InviteService.swift`:
  - `func generateInviteLink() async throws -> URL` — creates a cryptographically random token (SecRandomCopyBytes), writes to `invite_links` with 7-day expiry, returns `https://yourdomain.com/invite/{token}`
  - `func revokeInviteLink() async throws`
- `App/DeepLinkHandler.swift` — unified handler for Universal Links and notification taps:
  - `func handle(url: URL)` — extracts invite token, routes to accept flow
  - Auth state branching: not logged in → store token → complete auth → process; logged in → process immediately
- `Features/Partner/AcceptConnectionView.swift` — shown when app is opened via invite link:
  - Shows tracker's display name
  - "Connect with [name]" primary CTA
  - Validates token against `invite_links` (not expired, not used)
  - Creates `partner_connections` row
  - Marks invite token as used
  - Routes to partner onboarding or Partner tab

**Done when:** Tracker can generate invite link, partner can tap it (via Safari on simulator), app opens to accept screen, connection established in Supabase.

---

### 3.2 — Partner Sharing Write Flow

**Type:** Claude Code
**Skills:** `cadence-partner-sharing`, `cadence-supabase`, `cadence-encryption`

Implement the data pipeline that keeps `shared_logs` in sync with the tracker's `cycle_logs` and `sharing_settings`. This is the most architecturally important task in the partner feature.

**Files to create:**

- `Services/SharedLogService.swift`:
  - `func syncSharedLog(for date: Date) async throws` — reads today's `cycle_log`, checks `sharing_settings`, builds and upserts `shared_logs` row with only enabled categories + always-shared fields (cycle_day, cycle_phase, predicted_next_period)
  - `func updateSharingSetting(category: ShareCategory, enabled: Bool) async throws` — updates `sharing_settings`, then retroactively nulls/fills the corresponding field across all existing `shared_logs` rows for this connection
  - `func deleteAllSharedLogs(for connectionId: UUID) async throws` — called on disconnect
- `Models/ShareCategory.swift` — enum: period, symptoms, mood, energy (the four shareable categories). Explicitly not including: sex, sleep, notes.

**Critical invariant:** `SharedLogService` must NEVER read from `cycle_logs` on behalf of a partner session. This service is called only from tracker-owned code paths.

**Integration:** Call `syncSharedLog` at the end of `CycleLogService.saveCycleLog` and after every `updateSharingSetting` call.

**Done when:** Saving a log updates `shared_logs` correctly, toggling a category on/off retroactively updates all existing shared rows, verified via Supabase MCP inspection.

---

### 3.3 — Partner Tab — All Three States

**Type:** Claude Code
**Skills:** `cadence-design-system`, `cadence-partner-sharing`, `cadence-supabase`

Implement the Partner tab with all three states: empty (no partner connected), tracker's connected view, and partner's connected view.

**Files to create:**

- `Features/Partner/PartnerViewModel.swift` — ObservableObject:
  - `@Published var connectionStatus: ConnectionStatus` (none / connected / loading)
  - `@Published var partnerTodayData: SharedLog?`
  - `@Published var sharingSettings: SharingSettings`
  - `@Published var partnerName: String`
  - `func loadPartnerData() async`
  - `func updateSharingSetting(category: ShareCategory, enabled: Bool) async`
  - `func disconnect() async`
  - Realtime subscription to `shared_logs` for live updates
  - Cleanup on `deinit`
- `Features/Partner/PartnerView.swift` — routes between the three states
- `Features/Partner/PartnerEmptyView.swift` — empty state:
  - Centred nested circle illustration (outer: primary-faint, inner: primary-light, heart icon)
  - "Invite your partner" title (Playfair)
  - "Share your cycle with someone who cares — on your terms."
  - "Send invite link" primary CTA
  - "You can choose exactly what they see after connecting." hint
- `Features/Partner/PartnerConnectedTrackerView.swift` — tracker's view:
  - Green connection badge
  - Dark hero card (`#1A0F0E`): partner's cycle day, phase, shared mood/energy pills
  - "Shared today" section: partner's period status + symptoms card
  - "What [name] shares with you" section: category toggles inline with Edit action
- `Features/Partner/PartnerConnectedPartnerView.swift` — partner's (non-tracker) view:
  - Dark hero card with tracker's cycle day and phase
  - Phase explanation card: always shown for all phases, plain language (e.g. "Energy is typically higher during this phase.")
  - "Shared with you" section: only enabled categories
- `Features/Partner/PhaseExplanation.swift` — maps `CyclePhase` to plain-language partner-facing copy for all four phases

**Done when:** All three states render correctly, live Realtime updates work, sharing toggle changes reflect immediately in the view and in Supabase.

---

### 3.4 — Profile / Settings Screen

**Type:** Claude Code
**Skills:** `cadence-design-system`, `cadence-supabase`

Implement the Profile sheet — the settings hub accessible from the avatar in the top-right nav bar.

**Files to create:**

- `Features/Profile/ProfileViewModel.swift`:
  - `@Published var displayName: String`
  - `@Published var email: String`
  - `@Published var sharingSettings: SharingSettings`
  - `@Published var notificationPreferences: NotificationPreferences`
  - `@Published var connectionStatus: ConnectionStatus`
  - `func updateSharingSetting(category: ShareCategory, enabled: Bool) async`
  - `func updateNotificationPreference(type: NotificationType, enabled: Bool) async`
  - `func disconnect() async` — shows confirmation alert before executing
  - `func signOut() async`
- `Features/Profile/ProfileView.swift` — modal sheet with "Done" dismiss button:
  - Profile header: avatar circle, name (Playfair), email, Edit link
  - Partner section: connection dot + partner name/email, "Disconnect" destructive text
  - Sharing section: category toggles (mirrors Partner tab, same underlying state)
  - Notifications section: per-type toggles, daily reminder shows current time
  - Account section: Privacy Policy link, Terms link, Sign out (red icon)

**Note:** Sharing toggles here and on the Partner tab must stay in sync — they control the same `SharingSettings` object via the shared ViewModel or a shared service. Do not maintain duplicate state.

**Done when:** Profile sheet opens from avatar tap, all toggles update Supabase, disconnect shows confirmation and clears partner state, sign out returns to Welcome screen.

---

## Phase 4 — Notifications

> Retention infrastructure. Build after core features are solid.

---

### 4.1 — APNs Setup + Permission Flow

**Type:** Claude Code
**Skills:** `cadence-notifications`

Wire up APNs registration and device token storage. The actual notification sending is done in 4.2 — this task is just the iOS client setup.

**Files to create:**

- `Services/NotificationService.swift`:
  - `func requestPermission() async -> Bool`
  - `func registerForRemoteNotifications()`
  - `func storeDeviceToken(_ token: Data) async throws` — writes to Supabase `device_tokens` table (create this table in a new migration)
  - `func handleNotificationTap(userInfo: [AnyHashable: Any])` — routes to `DeepLinkHandler`
- `App/AppDelegate.swift` — implement `didRegisterForRemoteNotificationsWithDeviceToken` and `didReceiveRemoteNotification`
- Add a new migration: `device_tokens` table (user_id, token, platform, updated_at) with RLS (user reads/writes own tokens only)

Permission is requested at the end of onboarding step 6 — not before. See `NotificationsView.swift` from task 2.1.

**Done when:** App registers for push notifications, device token is stored in Supabase after onboarding completes.

---

### 4.2 — Supabase Edge Functions — Notification Triggers

**Type:** Claude Code
**Skills:** `cadence-notifications`, `cadence-supabase`

Implement all six notification Edge Functions in TypeScript/Deno. These run server-side and send APNs pushes.

**Files to create (in `/supabase/functions/`):**

- `period-reminder/index.ts` — daily cron: queries users whose predicted period start is tomorrow, sends APNs push
- `ovulation-alert/index.ts` — daily cron: queries users entering their fertile window today, sends push
- `daily-log-reminder/index.ts` — runs hourly: queries users whose configured reminder time is the current hour, sends push
- `partner-activity/index.ts` — database trigger on `shared_logs` INSERT: sends push to connected partner
- `period-late/index.ts` — daily cron: queries users whose predicted period start has passed with no log, sends push
- `phase-change/index.ts` — daily cron: queries users transitioning to a new phase today, sends push
- `_shared/apns.ts` — shared APNs HTTP/2 client helper used by all functions

**Notification preferences:** Each function must check the user's notification preferences in Supabase before sending. If the user has disabled a notification type, skip silently.

**Done when:** At least one Edge Function is deployed and fires correctly. Test with a manually triggered Supabase function call.

---

### 4.3 — Notification Deep Link Routing

**Type:** Claude Code
**Skills:** `cadence-notifications`, `cadence-deep-links`

Complete the notification tap → screen routing, extending the `DeepLinkHandler` from task 3.1.

**Routing spec:**
| Notification | Destination |
|---|---|
| Period reminder | Today tab |
| Ovulation alert | Today tab |
| Daily log reminder | Today tab + log sheet opens automatically |
| Partner activity | Partner tab |
| Period is late | Today tab |
| Phase change | Today tab |

**Files to update:**

- `App/DeepLinkHandler.swift` — add notification routing alongside Universal Link routing
- `App/RootView.swift` — handle tab selection and sheet presentation from DeepLinkHandler

**Done when:** Tapping each notification type in a test sends the user to the correct screen.

---

## Phase 5 — Polish + Pre-Launch

> The gap between "working" and "shippable."

---

### 5.1 — Empty States + Error States

**Type:** Claude Code
**Skills:** `cadence-design-system`

Implement all empty and error states throughout the app. No screen should ever show a blank card or a naked SwiftUI error.

**Empty states to implement:**

- Partner tab: no partner connected (already done in 3.3)
- Partner card on Today: partner hasn't logged yet (dashed card, "[Name] hasn't logged today yet")
- Partner card on Today: no partner connected ("Invite your partner to see their updates here")
- Insights section: each card before sufficient data ("Log 1 more cycle to see your average length")
- Calendar: first month with only seed data (phase strips visible, no logged dots)

**Error states to implement:**

- Supabase write failure on log save (alert with retry)
- Auth failure on sign in (inline error copy, not a system alert)
- Invite link expired or already used (friendly error with "Ask your partner to send a new link")
- No network connection (banner, not a blocking modal)

**Done when:** Every screen in the app handles its empty and error state gracefully. No `nil` force-unwraps, no unhandled throws.

---

### 5.2 — Editing Past Logs

**Type:** Claude Code
**Skills:** `cadence-design-system`, `cadence-supabase`, `cadence-partner-sharing`

Wire up the log editing flow from the Calendar screen. Users can edit any previously logged day to correct errors.

**Flow:**

1. User taps a past date on calendar → `DaySummaryCard` appears
2. User taps "Edit" → `LogEntrySheet` opens pre-populated with existing log data
3. User makes changes → taps "Save log"
4. `CycleLogService.saveCycleLog` updates the existing row (upsert by user_id + log_date)
5. `SharedLogService.syncSharedLog` re-runs for that date to update `shared_logs`

**Done when:** Editing a past log updates both `cycle_logs` and `shared_logs` correctly, calendar refreshes to show any changes.

---

### 5.3 — Irregular Cycle + Edge Case Handling

**Type:** Claude Code
**Skills:** `cadence-prediction`

Implement the UI-side handling for prediction engine edge cases. The engine logic is already in the `PredictionEngine` from task 2.2 — this task wires the confidence tiers and prompts into the UI.

**UI changes:**

- Confidence tier `estimated` (0 cycles): add "Estimated" label below phase name on hero card and calendar strips
- Confidence tier `low` (1–2 cycles): add a subtle indicator dot or muted phase strip opacity
- 60-day gap: surface a prompt card on the Today screen — "We've lost track of your cycle. When did your last period start?" with a date picker inline
- 14-day spotting: no UI change needed — handled silently by `CycleRecordBuilder`

**Done when:** Each confidence state is visually distinct, 60-day gap prompt appears correctly and updates the cycle profile when confirmed.

---

### 5.4 — Accessibility Pass

**Type:** Claude Code
**Skills:** `cadence-design-system`

Audit and fix accessibility across all screens.

**Checklist:**

- All interactive elements: minimum 44pt × 44pt tap target
- All icons: `accessibilityLabel` set
- All toggles: state announced by VoiceOver ("On" / "Off")
- All buttons: meaningful `accessibilityLabel` (not just the icon)
- Dynamic Type: DM Sans text scales with user's font size preference. Playfair Display headings are fixed size.
- Reduce Motion: replace scale animations with opacity crossfades when `UIAccessibility.isReduceMotionEnabled`
- Coral `#F88379` on white: only used for large text (18pt+) or decorative elements — never small body copy

Run the Accessibility Inspector in Xcode against every screen. Fix all critical issues.

**Done when:** Accessibility Inspector reports no critical issues on Welcome, Today, Calendar, and Partner screens.

---

### 5.5 — Privacy Policy + App Store Prep

**Type:** Manual + Claude Code
**Owner:** You (legal content) + Claude Code (technical metadata)

**Manual tasks:**

- Write and publish a privacy policy at your domain URL. Must cover: health data types collected, US data hosting, no sale to third parties, no advertiser sharing, right to data deletion (manual process for MVP), contact address for data requests. The post-2022 context matters — explicitly state that client-side encryption means Cadence cannot produce readable health data even under legal compulsion.
- Prepare App Store screenshots for required device sizes

**Claude Code tasks:**

- Update `Info.plist` with all required privacy usage description strings (even for APIs you link against but don't directly use)
- Configure the App Store privacy nutrition label in App Store Connect: Health & Fitness Data, Usage Data only. No advertising data, no third-party sharing.
- Write the App Store description copy drawing from the PRD problem statement and value prop

**Done when:** Privacy policy is live at a real URL, all Info.plist strings are set, App Store Connect metadata is complete.

---

### 5.6 — TestFlight Build + Pre-Submission Checklist

**Type:** Manual + Claude Code
**Owner:** You

**Pre-submission checklist:**

- [ ] AASA file live and validated (Apple AASA validator tool)
- [ ] Universal Links tested on a physical device (not simulator)
- [ ] Invite link flow tested end-to-end between two physical devices
- [ ] Push notifications tested on a physical device
- [ ] Encryption verified: inspect Supabase `cycle_logs` table directly — all health fields should be unreadable ciphertext
- [ ] RLS verified: attempt to read `cycle_logs` from a partner's Supabase session — should be rejected
- [ ] Onboarding completion flag tested: kill app mid-onboarding, reopen, verify it resumes at the correct step
- [ ] Cold start predictions verified: new account with only seed data shows predictions correctly
- [ ] 60-day gap prompt tested: manually set `last_period_date` 61 days ago and verify prompt appears
- [ ] Privacy policy URL accessible from the app footer link
- [ ] App Store reviewer notes written: include two test accounts (tracker + partner) with pre-seeded cycle data and an active connection

**Done when:** App submitted to TestFlight, all checklist items verified on physical device.

---

## Task Summary

| Phase   | Tasks      | Description                                                           |
| ------- | ---------- | --------------------------------------------------------------------- |
| Phase 0 | 0.1 – 0.15 | Foundation — manual setup and CI infrastructure                       |
| Phase 1 | 1.1 – 1.4  | Core infrastructure — design system, encryption, auth, data layer     |
| Phase 2 | 2.1 – 2.4  | Core tracker loop — onboarding, prediction, Today, Calendar           |
| Phase 3 | 3.1 – 3.4  | Partner feature — connections, sharing, Partner tab, Profile          |
| Phase 4 | 4.1 – 4.3  | Notifications — APNs, Edge Functions, routing                         |
| Phase 5 | 5.1 – 5.6  | Polish + pre-launch — empty states, editing, accessibility, App Store |

**Total:** ~38 tasks. Each task = one Claude Code session = one PR = one squash commit to `main`.
