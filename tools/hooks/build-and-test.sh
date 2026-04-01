#!/usr/bin/env bash
# build-and-test.sh — Pre-push build and test verification.
#
# Runs xcodebuild build and test only when an Xcode project/workspace exists.
# Skips gracefully when the repo does not yet have a buildable target.
#
# Exit codes:
#   0  Build/test passed or no project to build
#   1  Build or test failure

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/hook-ui.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

hook_header "pre-push" "Build and Test"

# ── Detect project ────────────────────────────────────────────────────────

WORKSPACE=$(find "$REPO_ROOT" -maxdepth 2 -name '*.xcworkspace' -not -path '*/Pods/*' -not -path '*/.build/*' 2>/dev/null | head -1)
PROJECT=$(find "$REPO_ROOT" -maxdepth 2 -name '*.xcodeproj' -not -path '*/.build/*' 2>/dev/null | head -1)
PACKAGE="$REPO_ROOT/Package.swift"

BUILD_TARGET=""
BUILD_CMD=""

if [[ -n "$WORKSPACE" ]]; then
    BUILD_TARGET="$WORKSPACE"
    BUILD_CMD="xcodebuild -workspace \"$WORKSPACE\" -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
elif [[ -n "$PROJECT" ]]; then
    BUILD_TARGET="$PROJECT"
    BUILD_CMD="xcodebuild -project \"$PROJECT\" -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
elif [[ -f "$PACKAGE" ]]; then
    BUILD_TARGET="$PACKAGE"
    BUILD_CMD="swift build --quiet"
else
    hook_skip "No Xcode project, workspace, or Package.swift found"
    hook_skip "Build and test will activate when the project is created"
    exit 0
fi

hook_info "Target: $(basename "$BUILD_TARGET")"

# ── Build ─────────────────────────────────────────────────────────────────

hook_info "Building..."

BUILD_OUTPUT=$(eval "$BUILD_CMD" build 2>&1) || {
    hook_fail "Build failed"
    # Show last 20 lines of build output for context.
    echo "$BUILD_OUTPUT" | tail -20 | while IFS= read -r line; do
        hook_detail "$line"
    done
    hook_summary_fail "Fix build errors before pushing"
    exit 1
}

hook_pass "Build succeeded"

# ── Test ──────────────────────────────────────────────────────────────────

# Check if test targets exist.
if [[ -f "$PACKAGE" ]]; then
    TEST_CMD="swift test --quiet"
elif [[ -n "$WORKSPACE" ]]; then
    TEST_CMD="xcodebuild -workspace \"$WORKSPACE\" -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet test"
elif [[ -n "$PROJECT" ]]; then
    TEST_CMD="xcodebuild -project \"$PROJECT\" -scheme Cadence -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet test"
else
    hook_skip "No test target detected"
    exit 0
fi

hook_info "Running tests..."

TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1) || {
    # Distinguish between "no tests" and "tests failed".
    if echo "$TEST_OUTPUT" | grep -qiE 'no tests|testing cancelled|scheme.*not found'; then
        hook_skip "No test targets found yet"
        exit 0
    fi

    hook_fail "Tests failed"
    echo "$TEST_OUTPUT" | tail -20 | while IFS= read -r line; do
        hook_detail "$line"
    done
    hook_summary_fail "Fix failing tests before pushing"
    exit 1
}

hook_pass "All tests passed"
exit 0
