#!/usr/bin/env bash
# swiftlint-hook.sh — Lint staged Swift files in strict mode.
#
# Runs SwiftLint with --strict on staged .swift files.
# Skips gracefully when SwiftLint is not installed or no Swift files are staged.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

hook_header "pre-commit" "SwiftLint (strict)"

FILES=()
while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
done < <(staged_swift_files)

if [[ ${#FILES[@]} -eq 0 ]]; then
    hook_skip "No staged Swift files"
    exit 0
fi

if ! require_tool "swiftlint" "brew install swiftlint"; then
    exit 1
fi

hook_info "Linting ${#FILES[@]} file(s)"

LINT_OUTPUT=""
LINT_EXIT=0

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        OUTPUT=$(swiftlint lint --strict --quiet --config .swiftlint.yml "$file" 2>&1) || LINT_EXIT=1
        if [[ -n "$OUTPUT" ]]; then
            LINT_OUTPUT="${LINT_OUTPUT}${OUTPUT}\n"
        fi
    fi
done

if [[ $LINT_EXIT -ne 0 ]]; then
    echo -e "$LINT_OUTPUT" | head -20 | while IFS= read -r line; do
        [[ -n "$line" ]] && hook_detail "$line"
    done
    hook_summary_fail "SwiftLint violations found"
    exit 1
fi

hook_pass "No lint violations (${#FILES[@]} files)"
exit 0
