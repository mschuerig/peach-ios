#!/usr/bin/env bash
#
# bin/build.sh — Build Peach and produce a clean summary.
#
# Usage:
#   bin/build.sh            # build, show errors/warnings summary
#   bin/build.sh -v         # verbose: show full xcodebuild output
#   bin/build.sh -w         # treat warnings as errors (exit 1 if any)
#   bin/build.sh -r         # raw: just run xcodebuild, no parsing
#
# Exit codes:
#   0  build succeeded (and no warnings if -w)
#   1  build failed or warnings found with -w
#

set -euo pipefail

# --- Configuration ---
SCHEME="Peach"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

# --- Parse arguments ---
VERBOSE=false
WARNINGS_AS_ERRORS=false
RAW=false

while getopts "vwr" opt; do
    case $opt in
        v) VERBOSE=true ;;
        w) WARNINGS_AS_ERRORS=true ;;
        r) RAW=true ;;
        *) echo "Usage: $0 [-v] [-w] [-r]" >&2; exit 1 ;;
    esac
done

# --- Build command ---
CMD=(xcodebuild build -scheme "$SCHEME" -destination "$DESTINATION")

# --- Raw mode ---
if $RAW; then
    "${CMD[@]}" 2>&1
    exit $?
fi

# --- Run build ---
TMPFILE=$(mktemp /tmp/peach-build-XXXXXX)
trap 'rm -f "$TMPFILE"' EXIT

if $VERBOSE; then
    "${CMD[@]}" 2>&1 | tee "$TMPFILE"
else
    echo "Building..."
    "${CMD[@]}" > "$TMPFILE" 2>&1 || true
fi

# --- Parse results ---
# grep -c prints "0" but exits 1 on no match. Separate assignment from
# fallback so we don't capture both grep's "0" AND echo's "0".
ERRORS=$(grep -cE "error:" "$TMPFILE" 2>/dev/null) || ERRORS=0
WARNINGS=$(grep -cE "warning:" "$TMPFILE" 2>/dev/null) || WARNINGS=0

echo ""
echo "══════════════════════════════════════"

if grep -q "BUILD FAILED" "$TMPFILE"; then
    echo "  ❌ BUILD FAILED ($ERRORS errors, $WARNINGS warnings)"
    echo "══════════════════════════════════════"
    echo ""
    echo "Errors:"
    grep -E "error:" "$TMPFILE" | sed 's|^/Users/[^/]*/Projekte/peach/||' | head -20
    if [[ "$WARNINGS" -gt 0 ]]; then
        echo ""
        echo "Warnings:"
        grep -E "warning:" "$TMPFILE" | sed 's|^/Users/[^/]*/Projekte/peach/||' | head -10
    fi
    echo ""
    exit 1

elif grep -q "BUILD SUCCEEDED" "$TMPFILE"; then
    if [[ "$WARNINGS" -gt 0 ]]; then
        echo "  ⚠️  BUILD SUCCEEDED ($WARNINGS warnings)"
        echo "══════════════════════════════════════"
        echo ""
        echo "Warnings:"
        grep -E "warning:" "$TMPFILE" | sed 's|^/Users/[^/]*/Projekte/peach/||' | sort -u | head -20
        echo ""
        if $WARNINGS_AS_ERRORS; then
            exit 1
        fi
    else
        echo "  ✅ BUILD SUCCEEDED (0 warnings)"
        echo "══════════════════════════════════════"
        echo ""
    fi
    exit 0

else
    echo "  ⚠️  BUILD STATUS UNCLEAR"
    echo "══════════════════════════════════════"
    echo ""
    echo "Could not find BUILD SUCCEEDED or BUILD FAILED in output."
    echo "Last 10 lines:"
    tail -10 "$TMPFILE"
    echo ""
    echo "Full log: $TMPFILE"
    trap '' EXIT  # keep log
    exit 1
fi
