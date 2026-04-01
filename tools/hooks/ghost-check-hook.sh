#!/usr/bin/env bash
# ghost-check-hook.sh — Run ghost_check.py AI provenance scanner.
#
# Uses the project venv if available, falls back to system python3.
# Runs in --strict mode (warnings are failures).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SCRIPT="${REPO_ROOT}/tools/ghost_check.py"

hook_header "pre-commit" "Ghost Check (AI provenance)"

if [[ ! -f "$SCRIPT" ]]; then
    hook_skip "ghost_check.py not found"
    exit 0
fi

PYTHON="${REPO_ROOT}/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
    PYTHON=$(command -v python3 2>/dev/null || true)
fi

if [[ -z "$PYTHON" ]]; then
    hook_warn "python3 not found"
    hook_detail "Install Python 3.11+ or create a venv"
    exit 1
fi

# Verify rich is importable.
if ! "$PYTHON" -c "import rich" 2>/dev/null; then
    hook_warn "Python 'rich' package not installed"
    hook_detail "Run: .venv/bin/pip install rich"
    exit 1
fi

"$PYTHON" "$SCRIPT" --scan-files --repo-root "$REPO_ROOT" --strict
