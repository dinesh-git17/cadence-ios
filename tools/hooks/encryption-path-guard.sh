#!/usr/bin/env bash
# encryption-path-guard.sh — Enforce that sensitive fields use EncryptionService.
#
# Cadence requires all sensitive health data to be encrypted via
# EncryptionService before writes to Supabase. This guard catches:
#
#   1. Direct writes of plaintext sensitive fields to cycle_logs or shared_logs
#   2. Supabase insert/upsert calls that reference sensitive field names
#      without going through EncryptionService
#
# Exit codes:
#   0  Clean or no files to scan
#   1  Violations found

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "pre-commit" "Encryption Path Enforcement"

# ── Collect files ─────────────────────────────────────────────────────────

FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACM -- '*.swift' 2>/dev/null)

if [[ ${#FILES[@]} -eq 0 ]]; then
    hook_skip "No staged Swift files to scan"
    exit 0
fi

# ── Sensitive columns that must be encrypted before DB write ──────────────

ENCRYPTED_COLUMNS=(
    '"period_flow"'
    '"mood"'
    '"energy"'
    '"symptoms"'
    '"sleep_quality"'
    '"intimacy_logged"'
    '"intimacy_protected"'
    '"notes"'
)

# Build alternation.
COL_PATTERN=""
for col in "${ENCRYPTED_COLUMNS[@]}"; do
    escaped=$(echo "$col" | sed 's/"/\\"/g')
    if [[ -n "$COL_PATTERN" ]]; then
        COL_PATTERN="${COL_PATTERN}|"
    fi
    COL_PATTERN="${COL_PATTERN}${escaped}"
done

# Pattern: Supabase insert/upsert/update that directly sets a sensitive column.
# Catches: .insert(["period_flow": someValue]) and similar.
DB_WRITE_PATTERN='\.(insert|upsert|update)\s*\('

VIOLATIONS=0

for file in "${FILES[@]}"; do
    [[ -f "$file" ]] || continue

    # Skip the EncryptionService itself and its tests — they handle raw values by design.
    case "$file" in
        *EncryptionService*|*EncryptionTests*|*MockEncryption*) continue ;;
    esac

    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip suppressed lines.
        [[ "$line" == *"encryption-guard: ignore"* ]] && continue

        # Check for Supabase write calls.
        if echo "$line" | grep -qE "$DB_WRITE_PATTERN"; then
            # Check if the same line or the next few lines reference a sensitive column
            # without EncryptionService.encrypt nearby.
            context=$(sed -n "${line_num},$((line_num + 5))p" "$file" 2>/dev/null)

            for col in "${ENCRYPTED_COLUMNS[@]}"; do
                if echo "$context" | grep -qF "$col"; then
                    if ! echo "$context" | grep -qE '(encrypt|EncryptionService|\.sealed|\.encrypted)'; then
                        VIOLATIONS=$((VIOLATIONS + 1))
                        hook_fail "Possible plaintext write of ${col} to database"
                        hook_detail "${file}:${line_num}"
                        hook_detail "Use EncryptionService.encrypt() before writing."
                    fi
                fi
            done
        fi
    done < "$file"
done

# ── Result ────────────────────────────────────────────────────────────────

if [[ $VIOLATIONS -gt 0 ]]; then
    hook_summary_fail "${VIOLATIONS} encryption violation(s) — sensitive fields must be encrypted"
    hook_detail "All health data must pass through EncryptionService before DB writes."
    hook_detail "Suppress false positives with: // encryption-guard: ignore"
    exit 1
fi

hook_pass "Encryption paths verified (${#FILES[@]} files)"
exit 0
