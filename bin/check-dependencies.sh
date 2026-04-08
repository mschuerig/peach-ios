#!/bin/bash
# Enforces architectural rules that archlint cannot express.
# archlint handles all import-based rules (see archlint.yaml).
# This script covers type-reference and code-pattern rules only.
#
# Rules enforced:
#   1. No cross-feature Screen type references between feature directories
#   2. No PitchDiscriminationFeedbackIndicator in PitchMatching/
#   3. No print() in production code (use Logger)

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/Peach"

ERRORS=0

red()   { printf '\033[1;31m%s\033[0m\n' "$1"; }
green() { printf '\033[1;32m%s\033[0m\n' "$1"; }

echo "Checking non-import dependency rules in $SRC_DIR ..."
echo

# ─── Rule 1: Cross-feature Screen type references ─────────────────
# Feature directories must not reference each other's Screen types.
# EXCEPT: Start/ is the navigation router and legitimately references all screens.
# Only App/, Start/ (router), and the feature's own directory may reference its Screen.

FEATURE_NAMES=()
SCREEN_TYPES=()
FEATURE_PATHS=()

# Training feature directories
for name in PitchDiscrimination PitchMatching TimingOffsetDetection ContinuousRhythmMatching; do
    FEATURE_NAMES+=("$name")
    SCREEN_TYPES+=("${name}Screen")
    FEATURE_PATHS+=("$SRC_DIR/Training/$name")
done

# Top-level feature directories
for name in Profile Settings Start Info; do
    FEATURE_NAMES+=("$name")
    SCREEN_TYPES+=("${name}Screen")
    FEATURE_PATHS+=("$SRC_DIR/$name")
done

for i in "${!FEATURE_NAMES[@]}"; do
    feature="${FEATURE_NAMES[$i]}"
    screen="${SCREEN_TYPES[$i]}"

    for j in "${!FEATURE_NAMES[@]}"; do
        other="${FEATURE_NAMES[$j]}"
        other_path="${FEATURE_PATHS[$j]}"
        [[ "$feature" == "$other" ]] && continue
        # Start/ is the navigation router — it must reference all screens
        [[ "$other" == "Start" ]] && continue

        matches=$(grep -rn "\b${screen}\b" "$other_path/" --include="*.swift" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            red "VIOLATION: $other/ references $screen (cross-feature dependency)"
            echo "$matches" | while IFS= read -r line; do
                echo "  $line"
            done
            echo
            ERRORS=$((ERRORS + 1))
        fi
    done
done

# ─── Rule 2: Feature types used in other features (known patterns) ─
pm_path=""
for i in "${!FEATURE_NAMES[@]}"; do
    [[ "${FEATURE_NAMES[$i]}" == "PitchMatching" ]] && pm_path="${FEATURE_PATHS[$i]}" && break
done
if [[ -n "$pm_path" ]]; then
    matches=$(grep -rn "PitchDiscriminationFeedbackIndicator" "$pm_path/" --include="*.swift" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
        red "VIOLATION: PitchMatching/ references PitchDiscriminationFeedbackIndicator (cross-feature dependency)"
        echo "$matches" | while IFS= read -r line; do
            echo "  $line"
        done
        echo
        ERRORS=$((ERRORS + 1))
    fi
fi

# ─── Rule 3: No print() in production code ────────────────────────
matches=$(grep -rn 'print(' "$SRC_DIR" --include="*.swift" || true)
if [[ -n "$matches" ]]; then
    red "VIOLATION: print() found in production code (use Logger from os framework)"
    echo "$matches" | while IFS= read -r line; do
        echo "  $line"
    done
    echo
    ERRORS=$((ERRORS + 1))
fi

# ─── Summary ──────────────────────────────────────────────────────
echo "─────────────────────────────────────"
if [[ $ERRORS -eq 0 ]]; then
    green "All non-import dependency rules passed."
    exit 0
else
    red "$ERRORS violation(s) found."
    exit 1
fi
