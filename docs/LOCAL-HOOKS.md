# Local Git Hooks

Local quality gates for the Cadence iOS repository. All hooks run on your
machine only — no CI dependency.

---

## Quick Start

```bash
./tools/setup-hooks.sh
```

This installs hooks for three Git stages: `pre-commit`, `commit-msg`, and
`pre-push`. Run it once after cloning, and again if
`.pre-commit-config.yaml` changes.

---

## Required Tools

| Tool         | Install                    | Used by                        |
| ------------ | -------------------------- | ------------------------------ |
| pre-commit   | `brew install pre-commit`  | Hook framework                 |
| swiftformat  | `brew install swiftformat` | Code formatting (auto-fix)     |
| swiftlint    | `brew install swiftlint`   | Linting (strict, check-only)   |
| gitleaks     | `brew install gitleaks`    | Secrets scanning               |
| python 3.11+ | System or `.venv`          | ghost-check (AI provenance)    |

Hooks degrade gracefully when a tool is missing. If the tool is relevant
to the staged files, the hook prints a warning with an install command and
continues. If no relevant files are staged, the hook is silent.

---

## Hook Inventory

### Pre-Commit Stage

| Hook                       | What it does                                                   | Graceful skip when             |
| -------------------------- | -------------------------------------------------------------- | ------------------------------ |
| trailing-whitespace        | Removes trailing whitespace                                    | No files staged                |
| end-of-file-fixer          | Ensures files end with a newline                               | No files staged                |
| check-yaml                 | Validates YAML syntax                                          | No YAML staged                 |
| check-json                 | Validates JSON syntax                                          | No JSON staged                 |
| check-merge-conflict       | Detects unresolved merge markers                               | No files staged                |
| no-commit-to-branch        | Blocks commits on `main`                                       | Not on main                    |
| gitleaks                   | Scans staged diffs for secrets, API keys, tokens               | No staged changes              |
| swiftformat                | Auto-formats staged Swift files, restages them                 | No Swift files or tool missing |
| swiftlint --strict         | Lints staged Swift files in strict mode                        | No Swift files or tool missing |
| ghost-check                | Scans for AI attribution markers and emoji in comments         | Script missing or no files     |
| privacy logging scan       | Catches logging of plaintext health data                       | No Swift files staged          |
| encryption path guard      | Verifies sensitive fields go through EncryptionService         | No Swift files staged          |
| rls / migration guard      | Checks SQL migrations for RLS safety                           | No SQL/migration files staged  |
| sharing invariant guard    | Enforces partner-sharing privacy invariants                    | No Swift files staged          |

### Commit-Msg Stage

| Hook               | What it does                                      | Failure example                       |
| ------------------- | ------------------------------------------------- | ------------------------------------- |
| commit message lint | Validates Conventional Commits format with scope   | `update stuff` (no type or scope)     |

**Required format:** `type(scope): description`

Allowed types: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `exp`

### Pre-Push Stage

| Hook              | What it does                               | Graceful skip when               |
| ----------------- | ------------------------------------------ | -------------------------------- |
| block push to main| Rejects pushes targeting `main`            | Not pushing to main              |
| build and test    | Runs `xcodebuild build` and `test`         | No Xcode project exists yet      |

---

## Greenfield Behaviour

This repo is early-stage. Many hooks are designed to activate progressively:

- **No Swift files:** SwiftFormat, SwiftLint, privacy scan, encryption guard,
  and sharing guard all skip silently.
- **No Xcode project:** Build and test hook skips with a message.
- **No SQL migrations:** RLS guard skips silently.
- **No files at all:** Ghost-check scans the repo and reports clean.

As the repo gains source files, migrations, and a build target, hooks
activate automatically. No configuration changes needed.

---

## Suppression

Each custom guard supports inline suppression for rare false positives:

| Guard              | Suppression comment            |
| ------------------ | ------------------------------ |
| Privacy logging    | `// privacy-scan: ignore`      |
| Encryption path    | `// encryption-guard: ignore`  |
| Sharing invariant  | `// sharing-guard: ignore`     |
| Ghost-check        | `// ghost-check: ignore`       |

Use sparingly. Each suppression should be justified in a code review.

---

## Troubleshooting

**Hook not running:**
```bash
pre-commit install --hook-type pre-commit
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

**Bypass a hook (emergency only):**
```bash
git commit --no-verify -m "type(scope): message"
```

**Run all hooks manually:**
```bash
pre-commit run --all-files
```

**Run a specific hook:**
```bash
pre-commit run swiftlint --all-files
pre-commit run ghost-check --all-files
```

**Update hook versions:**
```bash
pre-commit autoupdate
```

---

## Architecture

```
.pre-commit-config.yaml          Central hook configuration
.swiftformat                     SwiftFormat rules
.swiftlint.yml                   SwiftLint rules
.gitleaks.toml                   Gitleaks allowlist
tools/
  setup-hooks.sh                 Bootstrap script
  ghost_check.py                 AI provenance scanner
  hooks/
    swiftformat-hook.sh          SwiftFormat wrapper
    swiftlint-hook.sh            SwiftLint wrapper
    ghost-check-hook.sh          Ghost-check wrapper
    privacy-logging-scan.sh      Health data logging guard
    encryption-path-guard.sh     Encryption enforcement
    rls-migration-guard.sh       Database migration safety
    sharing-invariant-guard.sh   Partner sharing invariants
    commit-msg-lint.sh           Conventional commit validator
    branch-protect.sh            Push-to-main blocker
    build-and-test.sh            Pre-push build/test runner
  lib/
    hook-ui.sh                   Shared terminal output utilities
```

---

## Extending

To add a new hook:

1. Create the script in `tools/hooks/` — source `tools/lib/hook-ui.sh` for
   consistent output.
2. Add an entry to `.pre-commit-config.yaml` under the `local` repo section.
3. Run `pre-commit install` to pick up the change.
4. Update this document.
