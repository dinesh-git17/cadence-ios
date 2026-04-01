#!/usr/bin/env bash
# rls-migration-guard.sh — Guard against unsafe database migration patterns.
#
# Cadence uses Supabase with RLS. This guard checks migration files for:
#
#   1. CREATE TABLE without ENABLE ROW LEVEL SECURITY
#   2. ALTER TABLE ... DISABLE ROW LEVEL SECURITY
#   3. CREATE POLICY with overly permissive patterns (e.g., USING (true))
#   4. DROP POLICY without replacement
#   5. Migrations touching cycle_logs, shared_logs, sharing_settings,
#      partner_connections, invite_links without RLS awareness
#
# Exit codes:
#   0  Clean or no migration files staged
#   1  Violations found

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "pre-commit" "RLS / Migration Guard"

# ── Locate migration files ────────────────────────────────────────────────
# Check common migration paths for Supabase projects.

MIGRATION_PATTERNS=(
    '*.sql'
    'supabase/migrations/*'
    'migrations/*'
    'db/*'
)

FILES=()
for pattern in "${MIGRATION_PATTERNS[@]}"; do
    while IFS= read -r f; do
        [[ -n "$f" ]] && FILES+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACM -- "$pattern" 2>/dev/null)
done

# Deduplicate.
if [[ ${#FILES[@]} -gt 0 ]]; then
    DEDUPED=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && DEDUPED+=("$f")
    done < <(printf '%s\n' "${FILES[@]}" | sort -u)
    FILES=("${DEDUPED[@]}")
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    hook_skip "No staged migration/SQL files"
    exit 0
fi

hook_info "Scanning ${#FILES[@]} migration file(s)"

# ── RLS-sensitive tables ──────────────────────────────────────────────────

RLS_TABLES=(
    'cycle_logs'
    'shared_logs'
    'sharing_settings'
    'partner_connections'
    'invite_links'
    'users'
    'cycle_profiles'
)

VIOLATIONS=0

for file in "${FILES[@]}"; do
    [[ -f "$file" ]] || continue

    content=$(cat "$file")
    filename=$(basename "$file")

    # Check 1: CREATE TABLE without RLS enablement in the same file.
    if echo "$content" | grep -qiE 'CREATE\s+TABLE'; then
        if ! echo "$content" | grep -qiE 'ENABLE\s+ROW\s+LEVEL\s+SECURITY'; then
            VIOLATIONS=$((VIOLATIONS + 1))
            hook_fail "CREATE TABLE without ENABLE ROW LEVEL SECURITY"
            hook_detail "$file"
            hook_detail "Every table must have RLS enabled."
        fi
    fi

    # Check 2: Disabling RLS.
    if echo "$content" | grep -qiE 'DISABLE\s+ROW\s+LEVEL\s+SECURITY'; then
        VIOLATIONS=$((VIOLATIONS + 1))
        hook_fail "DISABLE ROW LEVEL SECURITY detected"
        hook_detail "$file"
        hook_detail "RLS must never be disabled on any Cadence table."
    fi

    # Check 3: Overly permissive policies.
    if echo "$content" | grep -qiE 'USING\s*\(\s*true\s*\)'; then
        VIOLATIONS=$((VIOLATIONS + 1))
        hook_fail "Overly permissive RLS policy: USING (true)"
        hook_detail "$file"
        hook_detail "Policies must scope access to auth.uid()."
    fi

    # Check 4: DROP POLICY on RLS-sensitive tables.
    for table in "${RLS_TABLES[@]}"; do
        if echo "$content" | grep -qiE "DROP\s+POLICY.*${table}"; then
            VIOLATIONS=$((VIOLATIONS + 1))
            hook_warn "DROP POLICY on ${table} — verify replacement exists"
            hook_detail "$file"
        fi
    done

    # Check 5: Modifications to sensitive tables without RLS context.
    for table in "${RLS_TABLES[@]}"; do
        if echo "$content" | grep -qiE "ALTER\s+TABLE\s+.*${table}"; then
            if ! echo "$content" | grep -qiE '(ROW LEVEL SECURITY|CREATE POLICY|POLICY)'; then
                hook_warn "ALTER TABLE on ${table} without RLS policy update"
                hook_detail "$file"
                hook_detail "Verify RLS policies still cover new columns."
            fi
        fi
    done
done

# ── Result ────────────────────────────────────────────────────────────────

if [[ $VIOLATIONS -gt 0 ]]; then
    hook_summary_fail "${VIOLATIONS} RLS/migration issue(s) found"
    exit 1
fi

hook_pass "Migration safety verified (${#FILES[@]} files)"
exit 0
