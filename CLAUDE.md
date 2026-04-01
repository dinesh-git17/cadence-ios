# CLAUDE.md — Cadence iOS

**Enforcement:** STRICT / BLOCKING
**Scope:** All work within the `cadence-ios` repository

---

## 1. Authority

This file is the supreme governance document for all Claude Code behaviour in
this repository. It overrides any ancestor `CLAUDE.md` files loaded from parent
directories.

**Precedence (highest to lowest):**

1. This `CLAUDE.md`
2. Skill files under `.claude/skills/` (domain-specific, on-demand)
3. Inline task instructions from the user (scoped to one session)

**Refusal policy:** If a request would violate any section of this document:

1. HALT — do not proceed.
2. REJECT — state the violated rule and section number.
3. CITE — reference the exact section.

No silent deviations. No "best effort" workarounds.

---

## 2. Project Identity

Cadence is a cycle tracking iOS app for couples. SwiftUI frontend, Supabase
backend (us-east-1), client-side AES-GCM encryption on all health data.

| Layer      | Technology                                         |
| ---------- | -------------------------------------------------- |
| Platform   | iOS 26.0+ (SwiftUI)                                |
| Language   | Swift 5.9+                                         |
| Backend    | Supabase (PostgreSQL + PostgREST + Realtime)       |
| Auth       | Sign in with Apple, email (Supabase Auth)          |
| Encryption | AES-256-GCM via CryptoKit, per-user key derivation |
| Icons      | Phosphor Icons (PhosphorSwift)                     |
| Fonts      | Playfair Display (display), DM Sans (body)         |

**Privacy guarantee:** Supabase never holds plaintext health data. All
sensitive fields are encrypted on-device before writes and decrypted on-device
after reads. This is a security requirement, not a preference.

---

## 3. Execution Standard

All output must be production-ready and reviewable by a senior iOS engineer.

**Required:**

- Code that compiles, runs, and handles its error paths.
- Correct use of async/await, Combine, and SwiftUI lifecycle.
- Idiomatic Swift. Value types where appropriate. Protocol-oriented design
  where it reduces complexity, not as a default.
- Named constants for all thresholds, durations, and magic numbers.

**Forbidden:**

- Placeholder implementations, stub files, or skeleton code.
- `// TODO` comments unless the user explicitly authorises deferred work.
- Half-finished features. Every deliverable must function end-to-end.
- Speculative features or capabilities not requested.

---

## 4. Decision-Making Policy

**NEVER guess.** If requirements are uncertain, conflicting, incomplete, or
ambiguous, stop and ask the user before proceeding.

- Do not infer architectural decisions. Ask.
- Do not assume unstated requirements. Ask.
- Do not choose between valid alternatives without stating the tradeoff. Ask.
- Do not silently deviate from the PRD, design spec, or task list.

Use `askuserquestion` for all clarification. One precise question is better
than three vague assumptions.

---

## 5. Code Quality — Swift

### 5.1 Formatting and Linting

SwiftFormat and SwiftLint are configured at the repo root and enforced by
pre-commit hooks. Do not fight them.

- **SwiftFormat:** 4-space indent, max 120 columns, `--wraparguments before-first`,
  `--semicolons never`. Full config in `.swiftformat`.
- **SwiftLint strict mode:** `force_unwrapping` is an error. Line length warning
  at 120, error at 150. Function body max 50/100 lines. File max 500/1000 lines.
  Full config in `.swiftlint.yml`.

### 5.2 Banned Patterns

- `print()` or `NSLog()` in committed code. Use `os.Logger` gated behind `#if DEBUG`.
- Force unwraps (`!`) anywhere. Use `guard let`, `if let`, or `??` with a
  meaningful default.
- `try!` or `try?` on Supabase calls. Use `do/catch` and map to typed errors.
- Stringly-typed APIs. Use enums, constants, or typed identifiers.
- Inline hex colour values. All colours must come from `Color.cadence*` tokens.
- Inline font names. All fonts must come from `Font.cadence*` extensions.
- `Font.system(...)` for any Cadence UI element.
- `shadow()` modifier. Elevation uses background colour contrast and border strokes.
- Dead code, commented-out blocks, or `_unused` variables. Delete them.

### 5.3 Architecture Constraints

- One primary concern per file. File name reflects its content.
- ViewModels are `@Observable` or `ObservableObject`. Views do not contain
  business logic beyond binding.
- Services are singletons or injected. No service instantiation inside views.
- All Supabase calls go through service layer files, never called directly from views.
- Encrypted fields are opaque `String` ciphertext in model structs. Decrypt via
  `EncryptionService` after fetch, never decode directly into domain types.
- A partner session MUST NEVER query `cycle_logs`. Partners read `shared_logs` only.
  This is a security invariant, not a data modelling preference.

### 5.4 Python Code (tools/ directory)

Python files in `tools/` must pass:

```bash
ruff format --check tools/
ruff check tools/
mypy --strict tools/ghost_check.py
```

No `print()` — use `logging` or `rich` console. Complete type annotations.
`pathlib.Path` exclusively, no `os.path`.

---

## 6. Comments and Documentation

**Comments must explain WHY, not WHAT.** If the code needs a comment to
explain what it does, the code should be rewritten to be self-evident.

**Permitted:**

- Non-obvious invariants, safety constraints, or privacy guarantees.
- References to PRD sections or design spec decisions that motivated a choice.
- Doc comments on public interfaces (one line preferred, multi-line only when
  parameters or return values require explanation).

**Forbidden:**

- Restating what the code already expresses.
- Tutorial-style explanations.
- Section divider comments (`// MARK: -` is acceptable; `// ========` is not).
- Filler prose, motivational language, or narrative.
- Emojis in comments, documentation, or any committed file.

---

## 7. No AI Attribution

No AI attribution in any repository artifact. This rule is enforced by the
`ghost-check` pre-commit hook, but Claude must not produce content that
requires the hook to catch it.

**Forbidden in code, comments, commits, PR descriptions, and documentation:**

- "Generated by AI", "Written by Claude", "Co-authored-by: AI"
- "This code was created with the help of..."
- Any reference to LLM assistance, AI pair programming, or similar.
- Emojis (also caught by ghost-check).

All repository output must read as if authored by a human engineering team.

---

## 8. Security

These rules are BLOCKING regardless of task scope or urgency.

### 8.1 Secrets

- NEVER hardcode API keys, tokens, secrets, or credentials in source files.
- Supabase URL and anon key load from `.xcconfig` via `Info.plist` at runtime.
- Encryption secret loads from `.xcconfig` via the same pattern.
- `.env` and `.xcconfig` files containing real values are gitignored.
- `.xcconfig.example` files with placeholder values are committed.

### 8.2 Health Data Encryption

- All sensitive fields in `cycle_logs` and `shared_logs` MUST be encrypted
  via `EncryptionService` before any Supabase write.
- The `encryption-path-guard` hook blocks commits where sensitive fields are
  written without going through `EncryptionService`.
- The `privacy-logging-scan` hook blocks commits that log plaintext health data.
- Suppression comments (`// encryption-guard: ignore`, `// privacy-scan: ignore`)
  require justification in the PR description.

### 8.3 Row Level Security

- Every new Supabase migration MUST include RLS policies.
- The `rls-migration-guard` hook checks SQL migrations for RLS safety.
- The `sharing-invariant-guard` hook enforces partner-sharing privacy invariants
  in Swift code.

---

## 9. Skill Registry

Eight skills are available under `.claude/skills/`. Claude MUST load the
relevant skill BEFORE writing implementation code in the skill's domain.
Never write token values, query patterns, encryption logic, or component
structure from memory — always read the skill first.

### 9.1 cadence-design-system

**Use when:** implementing ANY SwiftUI screen, component, colour, font,
spacing value, or visual element.
**Not for:** backend logic, data models, services, or non-UI Swift code.
**Key rule:** never write a hex value or font name inline. All values come
from the design system tokens defined in this skill's references.

### 9.2 cadence-encryption

**Use when:** writing ANY code that touches `EncryptionService`, CryptoKit,
`SymmetricKey`, HKDF, AES-GCM, Keychain storage, or encrypted fields in
`cycle_logs` / `shared_logs`.
**Not for:** UI code, unrelated services, or Supabase queries that do not
involve encrypted fields.

### 9.3 cadence-notifications

**Use when:** implementing APNs setup, permission flow, device token
registration, Edge Functions for notifications, notification preferences,
or deep link routing from notification taps.
**Not for:** in-app UI state, unrelated Edge Functions, or general navigation.

### 9.4 cadence-onboarding

**Use when:** implementing onboarding screens, the coordinator, the view
model, route enum, or app-root routing that depends on onboarding state.
**Not for:** post-onboarding features or screens outside the onboarding flow.

### 9.5 cadence-partner-sharing

**Use when:** implementing partner connections, shared data visibility, sharing
settings toggles, invite links, disconnect flows, or any Supabase query
involving `shared_logs`, `sharing_settings`, `partner_connections`, or
`invite_links`.
**Not for:** tracker-only features that do not touch partner data.
**Key rule:** violations of the invariants in this skill are security bugs.

### 9.6 cadence-prediction

**Use when:** implementing cycle prediction, phase calculation, weighted
rolling average, `CycleRecord` derivation, confidence tiers, or edge cases
(14-day spotting rule, 60-day flag).
**Not for:** data persistence, UI rendering, or Supabase queries.
**Key rule:** all algorithm thresholds are fully specified in the skill.
Do not invent alternatives.

### 9.7 cadence-supabase

**Use when:** writing ANY Swift code that imports `Supabase` — client setup,
auth flows, PostgREST queries, realtime subscriptions, error handling, or
environment configuration.
**Not for:** pure UI code or pure Swift logic with no Supabase dependency.
**Key rule:** never write query patterns or model structs from memory. Read
the skill references first.

### 9.8 universal-links

**Use when:** implementing Universal Links, the AASA file, Associated Domains
entitlements, `onOpenURL` handlers, or invite link URL processing.
**Not for:** general in-app navigation or non-deep-link routing.

---

## 10. Git Workflow

### 10.1 Branch Protection

`main` is protected. All changes MUST reach `main` through a pull request.
The `no-commit-to-branch` and `branch-protect` hooks enforce this locally.

NEVER commit directly to `main`. If instructed to do so without explicit
user override: HALT, REJECT per S1, and offer to create a branch + PR.

### 10.2 Branching Convention

Task-driven work uses the task list convention:

```
feature/task-{number}-{short-description}
```

Examples: `feature/task-1.1-design-tokens`, `feature/task-2.3-today-screen`.

Non-task work uses descriptive prefixes:

- `fix/{description}` — bug fixes
- `refactor/{description}` — restructuring without behaviour change

### 10.3 Commit Format

Enforced by the `commit-msg-lint` hook:

```
type(scope): imperative description
```

| Type       | Purpose                              |
| ---------- | ------------------------------------ |
| `feat`     | New functionality                    |
| `fix`      | Bug fix                              |
| `refactor` | Restructure without behaviour change |
| `test`     | Test additions or modifications      |
| `chore`    | Config, tooling, build settings      |
| `docs`     | Documentation changes                |
| `exp`      | Experimental / exploratory code      |

Scope is required, lowercase, alphanumeric + hyphens.

### 10.4 Commit and PR Gating

NEVER commit or open a PR without explicitly asking the user for permission
first. Draft the commit message or PR description, present it, and wait for
approval.

### 10.5 PR Requirements

- Title: Conventional Commits format, under 70 characters, imperative mood.
- Body: summary of changes + test plan. No empty descriptions.
- Squash merge preferred. Delete branch after merge.

---

## 11. Change Management

- Read every file you intend to modify BEFORE editing it.
- Understand the surrounding context and existing patterns before changing code.
- Touch only what is requested. No silent refactors, no opportunistic cleanups.
- Call out risk before changing critical paths (encryption, auth, RLS, data writes).
- Validate changes compile and run before presenting them.
- Prefer editing existing files over creating new ones. Every new file must be
  justified by the task.

---

## 12. Build, Lint, and Test

### Local hooks (run automatically on commit/push)

```bash
# Install hooks (once after clone)
./tools/setup-hooks.sh

# Run all pre-commit hooks manually
pre-commit run --all-files

# Run specific hooks
pre-commit run swiftformat --all-files
pre-commit run swiftlint --all-files
pre-commit run ghost-check --all-files
```

### Xcode build and test (available once Xcode project exists)

```bash
xcodebuild build \
  -scheme Cadence \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0'

xcodebuild test \
  -scheme Cadence \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0'
```

### Python tooling

```bash
ruff format --check tools/
ruff check tools/
mypy --strict tools/ghost_check.py
```

---

## 13. Failure and Escalation

- If something fails, state exactly what failed, why, and what is needed.
- Do not hide errors, suppress warnings, or work around failures silently.
- Do not bypass hooks with `--no-verify` unless the user explicitly instructs it.
- If a hook fails, diagnose the root cause and fix the code — do not disable
  the hook.
- Use `askuserquestion` when human confirmation is required to proceed.

---

## 14. Output Behaviour

- Concise, decisive, professional.
- No emojis. No filler prose. No AI-slop phrasing.
- No trailing summaries of what was just done — the diff speaks for itself.
- No generic boilerplate or weak hedging when the repo context is clear.
- Reference file paths with `file_path:line_number` format.
- Reference docs and PRD sections by name when they inform a decision.

---

## 15. Definition of Done

A task is complete ONLY when ALL of the following hold:

- [ ] Requested functionality works as specified.
- [ ] Code compiles without errors or warnings.
- [ ] No hardcoded secrets, hex colours, font names, or magic numbers.
- [ ] No dead code, stubs, or placeholders.
- [ ] No force unwraps or `try!` without documented justification.
- [ ] No `print()` debugging statements.
- [ ] No AI attribution or emojis in any committed file.
- [ ] No unintended new files.
- [ ] Encrypted fields go through `EncryptionService`.
- [ ] Partner queries target `shared_logs`, never `cycle_logs`.
- [ ] Relevant skill was loaded before writing domain code.
- [ ] Conventional Commits format on all commits.
- [ ] All local hooks pass (`pre-commit run --all-files`).
- [ ] Tests pass (when Xcode project exists).
- [ ] Python files pass `ruff format --check`, `ruff check`, `mypy --strict`.
