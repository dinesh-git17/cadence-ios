#!/usr/bin/env bash
# sharing-invariant-guard.sh — Enforce Cadence privacy/sharing invariants.
#
# Core invariants from the Cadence PRD and partner-sharing architecture:
#
#   INV-1: A partner session must NEVER query cycle_logs.
#   INV-2: Sex/intimacy, sleep, and notes must NEVER appear in shared_logs.
#   INV-3: Nothing is shared by default — SharingSettings defaults must be false.
#   INV-4: Phase info (cycle_day, cycle_phase, predicted_next_period) is always
#           shared with a connected partner — never gated by sharing settings.
#   INV-5: Disconnect must delete all shared_logs for the connection.
#
# This guard scans staged Swift files for patterns that would violate
# these invariants.
#
# Exit codes:
#   0  Clean or no files to scan
#   1  Violations found

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "pre-commit" "Sharing Invariant Guard"

# ── Collect files ─────────────────────────────────────────────────────────

FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACM -- '*.swift' 2>/dev/null)

if [[ ${#FILES[@]} -eq 0 ]]; then
    hook_skip "No staged Swift files to scan"
    exit 0
fi

VIOLATIONS=0

for file in "${FILES[@]}"; do
    [[ -f "$file" ]] || continue

    content=$(cat "$file")
    line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip suppressed lines.
        [[ "$line" == *"sharing-guard: ignore"* ]] && continue

        # ── INV-1: Partner context must not query cycle_logs ──────────
        # Detect queries to "cycle_logs" that appear in partner-related files.
        case "$file" in
            *Partner*|*partner*|*Sharing*|*sharing*)
                if echo "$line" | grep -qE '(from|table)\s*[:=(]?\s*"?cycle_logs"?'; then
                    VIOLATIONS=$((VIOLATIONS + 1))
                    hook_fail "INV-1: cycle_logs query in partner/sharing context"
                    hook_detail "${file}:${line_num}"
                    hook_detail "Partner sessions must only access shared_logs."
                fi
                ;;
        esac

        # ── INV-2: Private fields must never appear in shared_logs writes ─
        # Detect intimacy/sleep/notes references in shared_logs context.
        if echo "$line" | grep -qE 'shared_logs|SharedLog|sharedLog'; then
            if echo "$line" | grep -qiE '(intimacy|sleep_quality|sleepQuality|\bnotes\b)'; then
                VIOLATIONS=$((VIOLATIONS + 1))
                hook_fail "INV-2: Always-private field referenced in shared_logs context"
                hook_detail "${file}:${line_num}"
                hook_detail "intimacy, sleep, and notes must never be in shared_logs."
            fi
        fi

        # ── INV-3: SharingSettings defaults must be false ─────────────
        # Detect SharingSettings initialization with true defaults.
        if echo "$line" | grep -qE '(sharePeriod|shareSymptoms|shareMood|shareEnergy)\s*[:=]\s*true'; then
            # Only flag in model/settings definitions, not in toggle handlers.
            case "$file" in
                *Model*|*model*|*Setting*|*setting*|*SharingSettings*)
                    VIOLATIONS=$((VIOLATIONS + 1))
                    hook_fail "INV-3: Sharing default must be false, found true"
                    hook_detail "${file}:${line_num}"
                    hook_detail "Nothing is shared by default."
                    ;;
            esac
        fi

    done < "$file"

    # ── INV-5: Disconnect must delete shared_logs ─────────────────────
    # If a file handles disconnection, verify it deletes shared_logs.
    case "$file" in
        *Disconnect*|*disconnect*)
            if echo "$content" | grep -qiE 'disconnect|removePartner|endConnection'; then
                if ! echo "$content" | grep -qE '(delete|remove).*shared_logs|shared_logs.*(delete|remove)'; then
                    VIOLATIONS=$((VIOLATIONS + 1))
                    hook_fail "INV-5: Disconnect handler without shared_logs deletion"
                    hook_detail "$file"
                    hook_detail "All shared_logs rows must be deleted on disconnect."
                fi
            fi
            ;;
    esac
done

# ── Result ────────────────────────────────────────────────────────────────

if [[ $VIOLATIONS -gt 0 ]]; then
    hook_summary_fail "${VIOLATIONS} sharing invariant violation(s)"
    hook_detail "Review: docs/cadence-prd.md Section 10.3, Section 12"
    exit 1
fi

hook_pass "Sharing invariants verified (${#FILES[@]} files)"
exit 0
