#!/usr/bin/env bash
#
# bin/build.sh — Build Peach and produce a clean summary.
#
# Usage:
#   bin/build.sh                       # Peach (Debug) — pitch disciplines, no opt
#   bin/build.sh --research            # Peach (Debug, Research) — pitch + timing disciplines
#   bin/build.sh --release             # Peach (Release) — pitch disciplines, optimised
#   bin/build.sh --release --research  # Peach (Release, Research) — pitch + timing, optimised
#   bin/build.sh -p mac                # build for macOS
#   bin/build.sh -p ipad               # build for iPad Simulator
#   bin/build.sh -t                    # build for testing (compiles test target too)
#   bin/build.sh -v                    # verbose: show full xcodebuild output
#   bin/build.sh -w                    # treat warnings as errors (exit 1 if any)
#   bin/build.sh -r                    # raw: just run xcodebuild, no parsing
#   bin/build.sh -c                    # clean before building (useful when module
#                                        caches go stale across configurations)
#
# Platforms:
#   ios (default)  — iPhone 17 Pro Simulator
#   ipad           — iPad Pro 13-inch (M4) Simulator
#   mac            — native macOS
#
# Exit codes:
#   0  build succeeded (and no warnings if -w)
#   1  build failed or warnings found with -w
#

set -euo pipefail

# --- Configuration ---
PLATFORM="ios"

# --- Parse arguments ---
# Translate the long forms --research / --release into short forms before getopts
# so we don't need a separate parser.
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --research) ARGS+=("-R") ;;
        --release)  ARGS+=("-L") ;;
        --*) echo "Unknown option: $arg" >&2; exit 1 ;;
        *) ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]}"

VERBOSE=false
WARNINGS_AS_ERRORS=false
RAW=false
RESEARCH=false
RELEASE=false
CLEAN=false
FOR_TESTING=false

while getopts "vwrRLctp:" opt; do
    case $opt in
        v) VERBOSE=true ;;
        w) WARNINGS_AS_ERRORS=true ;;
        r) RAW=true ;;
        R) RESEARCH=true ;;
        L) RELEASE=true ;;
        c) CLEAN=true ;;
        t) FOR_TESTING=true ;;
        p) PLATFORM="$OPTARG" ;;
        *) echo "Usage: $0 [-v] [-w] [-r] [-c] [-t] [--research] [--release] [-p ios|ipad|mac]" >&2; exit 1 ;;
    esac
done

# --- Pick scheme from the 2×2 matrix ---
if $RELEASE && $RESEARCH; then
    SCHEME="Peach (Release, Research)"
elif $RELEASE; then
    SCHEME="Peach (Release)"
elif $RESEARCH; then
    SCHEME="Peach (Debug, Research)"
else
    SCHEME="Peach (Debug)"
fi

# --- Resolve destination from platform ---
case "$PLATFORM" in
    ios)  DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro" ;;
    ipad) DESTINATION="platform=iOS Simulator,name=iPad Pro 13-inch (M4)" ;;
    mac)  DESTINATION="platform=macOS" ;;
    *)    echo "Unknown platform: $PLATFORM (use ios, ipad, or mac)" >&2; exit 1 ;;
esac

# --- Build command ---
if $FOR_TESTING; then
    ACTION="build-for-testing"
else
    ACTION="build"
fi
if $CLEAN; then
    ACTION="clean $ACTION"
fi
# Word-split intentional so "clean build" becomes two arguments.
# shellcheck disable=SC2206
CMD=(xcodebuild $ACTION -scheme "$SCHEME" -destination "$DESTINATION")

# --- Raw mode ---
if $RAW; then
    "${CMD[@]}" 2>&1
    exit $?
fi

# --- Run build ---
mkdir -p "${TMPDIR:-/tmp}"
TMPFILE=$(mktemp "${TMPDIR:-/tmp}/peach-build-XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT

if $VERBOSE; then
    "${CMD[@]}" 2>&1 | tee "$TMPFILE"
else
    echo "Building $SCHEME..."
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
