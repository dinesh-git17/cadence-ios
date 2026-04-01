#!/usr/bin/env bash
# swiftformat-hook.sh — Auto-format staged Swift files.
#
# Runs SwiftFormat in auto-fix mode on staged .swift files, then restages them.
# Skips gracefully when SwiftFormat is not installed or no Swift files are staged.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "pre-commit" "SwiftFormat"

FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
done < <(staged_swift_files)

if [[ ${#FILES[@]} -eq 0 ]]; then
    hook_skip "No staged Swift files"
    exit 0
fi

if ! require_tool "swiftformat" "brew install swiftformat"; then
    exit 1
fi

hook_info "Formatting ${#FILES[@]} file(s)"

ERRORS=0
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        swiftformat --config .swiftformat "$file" 2>/dev/null || ERRORS=$((ERRORS + 1))
        git add "$file" 2>/dev/null
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    hook_summary_fail "SwiftFormat encountered errors"
    exit 1
fi

hook_pass "Formatted and restaged ${#FILES[@]} file(s)"
exit 0
