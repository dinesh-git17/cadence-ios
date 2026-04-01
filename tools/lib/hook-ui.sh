#!/usr/bin/env bash
# hook-ui.sh — Shared terminal output utilities for Cadence git hooks.
#
# Source this file from any hook script:
#   source "$(dirname "$0")/../lib/hook-ui.sh"
#
# Provides consistent, colourful, professional terminal output.

set -euo pipefail

# ── ANSI colour codes ─────────────────────────────────────────────────────

readonly _RESET='\033[0m'
readonly _BOLD='\033[1m'
readonly _DIM='\033[2m'
readonly _RED='\033[31m'
readonly _GREEN='\033[32m'
readonly _YELLOW='\033[33m'
readonly _CYAN='\033[36m'
readonly _WHITE='\033[37m'
readonly _BOLD_RED='\033[1;31m'
readonly _BOLD_GREEN='\033[1;32m'
readonly _BOLD_YELLOW='\033[1;33m'
readonly _BOLD_CYAN='\033[1;36m'
readonly _BOLD_WHITE='\033[1;37m'

# ── Symbols (Unicode, no emoji) ───────────────────────────────────────────

readonly SYM_PASS='✓'
readonly SYM_FAIL='✗'
readonly SYM_WARN='▸'
readonly SYM_SKIP='–'
readonly SYM_INFO='▸'
readonly SYM_RULE='─'

# ── Layout constants ──────────────────────────────────────────────────────

readonly HOOK_LINE_WIDTH=68

# ── Output functions ──────────────────────────────────────────────────────

# Print a horizontal rule.
hook_rule() {
    local line
    line=$(printf '%*s' "$HOOK_LINE_WIDTH" '' | tr ' ' "$SYM_RULE")
    printf '%b%s%b\n' "$_DIM" "$line" "$_RESET"
}

# Print a section header with a rule above it.
#   hook_header "pre-commit" "Privacy Logging Scan"
hook_header() {
    local stage="$1"
    local title="$2"
    printf '\n'
    hook_rule
    printf '%b  %s%b  %b%s%b\n' \
        "$_BOLD_CYAN" "$stage" "$_RESET" \
        "$_BOLD_WHITE" "$title" "$_RESET"
    hook_rule
}

# Print a pass line.
#   hook_pass "No secrets detected"
hook_pass() {
    printf '  %b%s%b  %s\n' "$_BOLD_GREEN" "$SYM_PASS" "$_RESET" "$1"
}

# Print a fail line.
#   hook_fail "Plaintext secret found in Config.swift:42"
hook_fail() {
    printf '  %b%s%b  %s\n' "$_BOLD_RED" "$SYM_FAIL" "$_RESET" "$1"
}

# Print a warning line.
#   hook_warn "SwiftLint not installed"
hook_warn() {
    printf '  %b%s%b  %s\n' "$_BOLD_YELLOW" "$SYM_WARN" "$_RESET" "$1"
}

# Print a skip line (for graceful degradation).
#   hook_skip "No Swift files found"
hook_skip() {
    printf '  %b%s%b  %b%s%b\n' "$_YELLOW" "$SYM_SKIP" "$_RESET" "$_DIM" "$1" "$_RESET"
}

# Print an info line.
#   hook_info "Scanning 42 files"
hook_info() {
    printf '  %b%s%b  %b%s%b\n' "$_CYAN" "$SYM_INFO" "$_RESET" "$_DIM" "$1" "$_RESET"
}

# Print a summary line at the end of a hook.
#   hook_summary_pass "All checks passed"
hook_summary_pass() {
    printf '\n  %b[PASS]%b  %s\n\n' "$_BOLD_GREEN" "$_RESET" "$1"
}

# Print a summary failure line.
#   hook_summary_fail "2 violations found"
hook_summary_fail() {
    printf '\n  %b[FAIL]%b  %s\n\n' "$_BOLD_RED" "$_RESET" "$1"
}

# Print a detail line (indented, dim — for showing file:line context under a fail).
#   hook_detail "Services/LogService.swift:87"
hook_detail() {
    printf '         %b%s%b\n' "$_DIM" "$1" "$_RESET"
}

# ── Utility functions ─────────────────────────────────────────────────────

# Check whether a command exists.
#   require_tool "swiftformat" "brew install swiftformat" || return
require_tool() {
    local tool="$1"
    local install_hint="$2"
    if ! command -v "$tool" &>/dev/null; then
        hook_warn "$tool not installed"
        hook_detail "Install: $install_hint"
        return 1
    fi
    return 0
}

# Find staged Swift files (for pre-commit hooks).
# Outputs newline-separated paths. Returns 1 if none found.
staged_swift_files() {
    git diff --cached --name-only --diff-filter=ACM -- '*.swift' 2>/dev/null
}

# Find all tracked Swift files. Returns 1 if none found.
all_swift_files() {
    find . -name '*.swift' -not -path './.build/*' -not -path './DerivedData/*' \
        -not -path './Pods/*' -not -path './.venv/*' 2>/dev/null
}

# Check if any Swift files exist in the repo.
has_swift_files() {
    local files
    files=$(all_swift_files)
    [[ -n "$files" ]]
}

# Check if staged files match a pattern. Returns 0 if any match.
#   has_staged_files '*.sql'
has_staged_files() {
    local pattern="$1"
    git diff --cached --name-only --diff-filter=ACM -- "$pattern" 2>/dev/null | grep -q .
}

# Get list of staged files matching a pattern.
staged_files_matching() {
    local pattern="$1"
    git diff --cached --name-only --diff-filter=ACM -- "$pattern" 2>/dev/null
}
