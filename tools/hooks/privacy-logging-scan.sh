#!/usr/bin/env bash
# privacy-logging-scan.sh — Detect unsafe logging of sensitive health data.
#
# Scans staged files for patterns that would log plaintext sensitive data
# (cycle logs, mood, symptoms, intimacy, sleep, notes, energy, period flow).
#
# Cadence encrypts all health data client-side. Logging plaintext health
# data — even in debug builds — is a privacy violation.
#
# Exit codes:
#   0  Clean or no files to scan
#   1  Violations found

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "pre-commit" "Privacy Logging Scan"

# ── Collect files to scan ─────────────────────────────────────────────────

FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACM -- '*.swift' 2>/dev/null)

if [[ ${#FILES[@]} -eq 0 ]]; then
    hook_skip "No staged Swift files to scan"
    exit 0
fi

# ── Sensitive field names ─────────────────────────────────────────────────
# These are the decrypted health data fields from cycle_logs and shared_logs.
# Any logging of these in plaintext is a violation.

SENSITIVE_FIELDS=(
    'periodFlow'
    'period_flow'
    'intimacyLogged'
    'intimacy_logged'
    'intimacyProtected'
    'intimacy_protected'
    'sleepQuality'
    'sleep_quality'
    'symptoms'
    'mood'
    'energy'
    'notes'
    'cycleLog'
    'cycle_log'
    'sharedLog'
    'shared_log'
)

# ── Dangerous logging patterns ────────────────────────────────────────────
# Build a combined regex for print/NSLog/os_log/Logger calls that
# interpolate or reference sensitive field names.

LOGGING_CALLS='(print|NSLog|os_log|logger\.\w+|Logger\.\w+|debugPrint|dump)'

# Build alternation of sensitive field names.
FIELD_PATTERN=""
for field in "${SENSITIVE_FIELDS[@]}"; do
    if [[ -n "$FIELD_PATTERN" ]]; then
        FIELD_PATTERN="${FIELD_PATTERN}|"
    fi
    FIELD_PATTERN="${FIELD_PATTERN}${field}"
done

# Pattern 1: logging call that references a sensitive field.
PATTERN_LOG_FIELD="${LOGGING_CALLS}.*\\b(${FIELD_PATTERN})\\b"

# Pattern 2: string interpolation of sensitive fields inside any string.
PATTERN_INTERPOLATION="\\\\\\((.*\\b(${FIELD_PATTERN})\\b.*)?\\)"

# ── Scan ──────────────────────────────────────────────────────────────────

VIOLATIONS=0
VIOLATION_LINES=()

for file in "${FILES[@]}"; do
    [[ -f "$file" ]] || continue

    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip lines with suppression marker.
        if [[ "$line" == *"privacy-scan: ignore"* ]]; then
            continue
        fi

        # Check for logging calls referencing sensitive fields.
        if echo "$line" | grep -qiE "$PATTERN_LOG_FIELD"; then
            VIOLATIONS=$((VIOLATIONS + 1))
            VIOLATION_LINES+=("${file}:${line_num}")
            hook_fail "Sensitive data in log statement"
            hook_detail "${file}:${line_num}"
            hook_detail "$(echo "$line" | sed 's/^[[:space:]]*//' | head -c 100)"
        fi
    done < "$file"
done

# ── Result ────────────────────────────────────────────────────────────────

if [[ $VIOLATIONS -gt 0 ]]; then
    hook_summary_fail "${VIOLATIONS} privacy violation(s) — do not log plaintext health data"
    hook_detail "Encrypt before logging or remove the log statement."
    hook_detail "Suppress with: // privacy-scan: ignore"
    exit 1
fi

hook_pass "No unsafe health data logging detected (${#FILES[@]} files)"
exit 0
