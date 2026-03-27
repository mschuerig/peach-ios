#!/usr/bin/env bash
#
# bin/test.sh — Run Peach tests and produce a clean summary.
#
# Usage:
#   bin/test.sh                  # run all tests, show summary
#   bin/test.sh -f               # show only failures (quiet on success)
#   bin/test.sh -v               # verbose: show full xcodebuild output
#   bin/test.sh -s SuiteName     # filter: only run tests matching SuiteName
#   bin/test.sh -r               # raw: just run xcodebuild, no parsing
#                                  (useful when this script's parsing breaks)
#   bin/test.sh -S               # run ONLY stress tests (sets RUN_STRESS_TESTS=1)
#   bin/test.sh -a               # run ALL tests including stress tests
#
# Exit codes:
#   0  all tests passed
#   1  one or more tests failed
#   2  build failed (tests did not run)
#

set -euo pipefail

# --- Configuration (edit these if your project changes) ---
SCHEME="Peach"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"
SCHEME_PATH="Peach.xcodeproj/xcshareddata/xcschemes/Peach.xcscheme"

# --- Parse arguments ---
FAILURES_ONLY=false
VERBOSE=false
RAW=false
FILTER=""
STRESS_ONLY=false
ALL_TESTS=false

while getopts "fvrs:Sa" opt; do
    case $opt in
        f) FAILURES_ONLY=true ;;
        v) VERBOSE=true ;;
        r) RAW=true ;;
        s) FILTER="$OPTARG" ;;
        S) STRESS_ONLY=true ;;
        a) ALL_TESTS=true ;;
        *) echo "Usage: $0 [-f] [-v] [-r] [-s SuiteName] [-S] [-a]" >&2; exit 1 ;;
    esac
done

# --- Stress test env var injection ---
# xcodebuild does not forward shell env vars to the simulator test host.
# The only reliable way is to inject into the scheme's TestAction XML.
ENABLE_STRESS=false

if $STRESS_ONLY; then
    ENABLE_STRESS=true
    FILTER="PeachTests/SoundFontPresetStressTests"
fi

if $ALL_TESTS; then
    ENABLE_STRESS=true
fi

SCHEME_MODIFIED=false
if $ENABLE_STRESS; then
    cp "$SCHEME_PATH" "$SCHEME_PATH.bak"
    SCHEME_MODIFIED=true
    # Add RUN_STRESS_TESTS env var to TestAction and disable inheriting launch args
    sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES"/shouldUseLaunchSchemeArgsEnv = "NO"/' "$SCHEME_PATH"
    sed -i '' '/<Testables>/i\
      <EnvironmentVariables>\
         <EnvironmentVariable\
            key = "RUN_STRESS_TESTS"\
            value = "1"\
            isEnabled = "YES">\
         </EnvironmentVariable>\
      </EnvironmentVariables>' "$SCHEME_PATH"
fi

restore_scheme() {
    if $SCHEME_MODIFIED && [ -f "$SCHEME_PATH.bak" ]; then
        mv "$SCHEME_PATH.bak" "$SCHEME_PATH"
    fi
}
trap 'restore_scheme' EXIT INT TERM

# --- Build the xcodebuild command ---
# Note: do NOT use -quiet — it suppresses the per-test pass/fail lines
# we need for the summary.
CMD=(xcodebuild test -scheme "$SCHEME" -destination "$DESTINATION")

# Add filter if specified
if [[ -n "$FILTER" ]]; then
    CMD+=(-only-testing:"$FILTER")
fi

# --- Raw mode: just run xcodebuild ---
if $RAW; then
    "${CMD[@]}" 2>&1
    exit $?
fi

# --- Run tests, capture output ---
mkdir -p "${TMPDIR:-/tmp}"
TMPFILE=$(mktemp "${TMPDIR:-/tmp}/peach-test-XXXXXX")
trap 'rm -f "$TMPFILE"; restore_scheme' EXIT INT TERM

if $VERBOSE; then
    "${CMD[@]}" 2>&1 | tee "$TMPFILE"
    XCODE_EXIT=${PIPESTATUS[0]}
else
    echo "Running tests..."
    "${CMD[@]}" > "$TMPFILE" 2>&1 || true
fi

# --- Check for build failure ---
if grep -q "BUILD FAILED" "$TMPFILE"; then
    echo ""
    echo "══════════════════════════════════════"
    echo "  BUILD FAILED — tests did not run"
    echo "══════════════════════════════════════"
    echo ""
    grep -E "error:" "$TMPFILE" | sed 's|^/Users/[^/]*/Projekte/peach/||' | head -20
    echo ""
    echo "Full log: $TMPFILE"
    trap '' EXIT  # keep the log file
    exit 2
fi

# --- Parse results ---
# Match both XCTest and Swift Testing output formats:
#   XCTest:         Test Case '-[Suite test]' passed (0.001 seconds).
#   Swift Testing:  ✔ Test "name" passed after 0.001 seconds
#   Also:           ... passed on 'iPhone 17'
# grep -c prints "0" but exits 1 on no match — separate assignment from fallback.
PASSED=$(grep -cE "(Test .* passed|✔ Test|passed on)" "$TMPFILE" 2>/dev/null) || PASSED=0
FAILED=$(grep -cE "(Test .* failed|✘ Test)" "$TMPFILE" 2>/dev/null) || FAILED=0

# Extract failed test names
FAILED_TESTS=$(grep -E "(Test .* failed|✘ Test)" "$TMPFILE" 2>/dev/null || true)

# Overall result from xcodebuild's own marker
if grep -q "TEST SUCCEEDED" "$TMPFILE"; then
    TEST_RESULT="passed"
elif grep -q "TEST FAILED" "$TMPFILE"; then
    TEST_RESULT="failed"
else
    TEST_RESULT="unknown"
fi

# --- Output ---
echo ""
echo "══════════════════════════════════════"

if [[ "$TEST_RESULT" == "passed" ]]; then
    echo "  ✅ ALL TESTS PASSED ($PASSED passed)"
    echo "══════════════════════════════════════"
    if ! $FAILURES_ONLY; then
        echo ""
    fi
    exit 0

elif [[ "$TEST_RESULT" == "failed" ]]; then
    echo "  ❌ $FAILED FAILED, $PASSED passed"
    echo "══════════════════════════════════════"
    echo ""
    if [[ -n "$FAILED_TESTS" ]]; then
        echo "Failed tests:"
        echo "$FAILED_TESTS" | while IFS= read -r line; do
            # Trim to just the test identifier
            name=$(echo "$line" | sed 's/.*Test [Cc]ase.*\[//; s/\].*//; s/.*Test "//; s/" failed.*//; s/.*✘ Test //')
            [[ -n "$name" ]] && echo "  • $name"
        done
        echo ""
    fi

    echo "Failure details:"
    grep -B1 -A3 -E "(failed|✘ Test)" "$TMPFILE" | grep -v "^--$" | tail -30
    echo ""
    exit 1

else
    echo "  ⚠️  TEST RESULT UNCLEAR"
    echo "══════════════════════════════════════"
    echo ""
    echo "Could not find TEST SUCCEEDED or TEST FAILED in output."
    echo "Last 20 lines:"
    tail -20 "$TMPFILE"
    echo ""
    echo "Full log: $TMPFILE"
    trap '' EXIT  # keep log
    exit 1
fi
