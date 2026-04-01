#!/usr/bin/env bash
# setup-hooks.sh — Bootstrap local git hooks for Cadence iOS.
#
# Run once after cloning:  ./tools/setup-hooks.sh
# Re-run after .pre-commit-config.yaml changes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Colour ────────────────────────────────────────────────────────────────

readonly _RESET='\033[0m'
readonly _BOLD='\033[1m'
readonly _DIM='\033[2m'
readonly _GREEN='\033[32m'
readonly _YELLOW='\033[33m'
readonly _CYAN='\033[36m'
readonly _BOLD_GREEN='\033[1;32m'
readonly _BOLD_RED='\033[1;31m'
readonly _BOLD_WHITE='\033[1;37m'

line() { printf '%b%s%b\n' "$_DIM" "$(printf '%68s' '' | tr ' ' '─')" "$_RESET"; }

ok()   { printf '  %b✓%b  %s\n' "$_BOLD_GREEN" "$_RESET" "$1"; }
warn() { printf '  %b▸%b  %s\n' "$_YELLOW" "$_RESET" "$1"; }
fail() { printf '  %b✗%b  %s\n' "$_BOLD_RED" "$_RESET" "$1"; }
info() { printf '  %b▸%b  %b%s%b\n' "$_CYAN" "$_RESET" "$_DIM" "$1" "$_RESET"; }

# ── Header ────────────────────────────────────────────────────────────────

printf '\n'
line
printf '%b  Cadence iOS%b  %bLocal Hook Setup%b\n' "$_BOLD_WHITE" "$_RESET" "$_BOLD" "$_RESET"
line
printf '\n'

# ── Check prerequisites ──────────────────────────────────────────────────

MISSING=0

check_tool() {
    local tool="$1"
    local install="$2"
    if command -v "$tool" &>/dev/null; then
        ok "$tool $(command "$tool" --version 2>/dev/null | head -1 || echo '')"
    else
        warn "$tool not found — install: $install"
        MISSING=$((MISSING + 1))
    fi
}

printf '  %bChecking tools%b\n\n' "$_BOLD" "$_RESET"

check_tool "pre-commit" "brew install pre-commit"
check_tool "swiftformat" "brew install swiftformat"
check_tool "swiftlint" "brew install swiftlint"
check_tool "gitleaks" "brew install gitleaks"

# Check Python venv for ghost_check.
if [[ -x "$REPO_ROOT/.venv/bin/python" ]]; then
    ok "python venv (.venv)"
else
    warn "python venv not found — run: python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
    MISSING=$((MISSING + 1))
fi

printf '\n'

if [[ $MISSING -gt 0 ]]; then
    warn "$MISSING optional tool(s) missing — hooks will skip those checks"
    printf '\n'
fi

# ── Git check ─────────────────────────────────────────────────────────────

if [[ ! -d "$REPO_ROOT/.git" ]]; then
    fail "Not a git repository. Run: git init"
    exit 1
fi

# ── Install pre-commit hooks ─────────────────────────────────────────────

printf '  %bInstalling hooks%b\n\n' "$_BOLD" "$_RESET"

cd "$REPO_ROOT"

pre-commit install --hook-type pre-commit 2>/dev/null && ok "pre-commit hook installed"
pre-commit install --hook-type commit-msg 2>/dev/null && ok "commit-msg hook installed"
pre-commit install --hook-type pre-push 2>/dev/null   && ok "pre-push hook installed"

printf '\n'

# ── Verify ────────────────────────────────────────────────────────────────

printf '  %bVerifying%b\n\n' "$_BOLD" "$_RESET"

if [[ -f "$REPO_ROOT/.git/hooks/pre-commit" ]]; then
    ok ".git/hooks/pre-commit exists"
else
    fail ".git/hooks/pre-commit not found"
fi

if [[ -f "$REPO_ROOT/.git/hooks/commit-msg" ]]; then
    ok ".git/hooks/commit-msg exists"
else
    fail ".git/hooks/commit-msg not found"
fi

if [[ -f "$REPO_ROOT/.git/hooks/pre-push" ]]; then
    ok ".git/hooks/pre-push exists"
else
    fail ".git/hooks/pre-push not found"
fi

# ── Done ──────────────────────────────────────────────────────────────────

printf '\n'
line
printf '  %b[DONE]%b  Local hooks are ready.\n' "$_BOLD_GREEN" "$_RESET"
info "See docs/LOCAL-HOOKS.md for details."
line
printf '\n'
