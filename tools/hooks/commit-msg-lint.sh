#!/usr/bin/env bash
# commit-msg-lint.sh — Validate commit messages against Conventional Commits.
#
# Required format:  type(scope): description
#
# Allowed types: feat, fix, refactor, test, chore, docs, exp
# Scope: required, lowercase, alphanumeric + hyphens
# Description: imperative mood, 1-72 chars, no trailing period
#
# Exit codes:
#   0  Valid
#   1  Invalid

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "commit-msg" "Commit Message Lint"

MSG_FILE="$1"

if [[ -z "$MSG_FILE" || ! -f "$MSG_FILE" ]]; then
    hook_fail "No commit message file provided"
    exit 1
fi

# Read the first non-comment, non-empty line as the subject.
SUBJECT=""
while IFS= read -r line; do
    # Skip Git comment lines.
    [[ "$line" =~ ^# ]] && continue
    # Skip empty lines before the subject.
    [[ -z "$line" ]] && continue
    SUBJECT="$line"
    break
done < "$MSG_FILE"

if [[ -z "$SUBJECT" ]]; then
    hook_fail "Empty commit message"
    exit 1
fi

# ── Allowed types ─────────────────────────────────────────────────────────

TYPES="feat|fix|refactor|test|chore|docs|exp"

# ── Validation regex ──────────────────────────────────────────────────────
# type(scope): description
# - type: from allowed list
# - scope: lowercase alphanumeric + hyphens, non-empty
# - description: starts with lowercase letter, no trailing period

PATTERN="^(${TYPES})\([a-z0-9][a-z0-9-]*\): [a-z].*[^.]$"

# ── Checks ────────────────────────────────────────────────────────────────

ERRORS=0

# Length check.
SUBJECT_LEN=${#SUBJECT}
if [[ $SUBJECT_LEN -gt 72 ]]; then
    ERRORS=$((ERRORS + 1))
    hook_fail "Subject line too long (${SUBJECT_LEN}/72 chars)"
fi

# Format check.
if ! echo "$SUBJECT" | grep -qE "$PATTERN"; then
    ERRORS=$((ERRORS + 1))
    hook_fail "Does not match: type(scope): description"
    hook_detail "Got: ${SUBJECT}"
    printf '\n'
    hook_info "Expected format:"
    hook_detail "type(scope): imperative description"
    printf '\n'
    hook_info "Allowed types: feat, fix, refactor, test, chore, docs, exp"
    printf '\n'
    hook_info "Examples:"
    hook_detail "feat(auth): add Sign in with Apple flow"
    hook_detail "fix(prediction): correct ovulation window offset"
    hook_detail "chore(hooks): configure pre-commit framework"
fi

# ── Result ────────────────────────────────────────────────────────────────

if [[ $ERRORS -gt 0 ]]; then
    hook_summary_fail "Commit message rejected"
    exit 1
fi

hook_pass "Valid: ${SUBJECT}"
exit 0
