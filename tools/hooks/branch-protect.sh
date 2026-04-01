#!/usr/bin/env bash
# branch-protect.sh — Block direct pushes to main.
#
# Reads the pre-push stdin to detect pushes targeting the main branch
# on any remote. This is a local-only guardrail.
#
# Exit codes:
#   0  Push allowed
#   1  Push to main blocked

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

PROTECTED_BRANCH="main"

hook_header "pre-push" "Branch Protection"

# pre-push receives: <local ref> <local sha> <remote ref> <remote sha>
# on stdin, one line per ref being pushed.

BLOCKED=0

while read -r local_ref local_sha remote_ref remote_sha; do
    if [[ "$remote_ref" == *"refs/heads/${PROTECTED_BRANCH}"* ]]; then
        BLOCKED=1
    fi
done

if [[ $BLOCKED -eq 1 ]]; then
    hook_fail "Direct push to '${PROTECTED_BRANCH}' is blocked"
    hook_detail "All changes must reach main through a pull request."
    hook_detail "Create a feature branch: git checkout -b feat/your-change"
    hook_summary_fail "Push rejected"
    exit 1
fi

hook_pass "Push target is not a protected branch"
exit 0
