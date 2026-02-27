#!/bin/bash
# Enforces architectural dependency rules for the Peach project.
# Run before commits or in CI. Exit code 0 = clean, 1 = violations found.
#
# Rules enforced:
#   1. Core/ must not import SwiftUI, UIKit, or Charts
#   2. SwiftData imports only allowed in Core/Data/ and App/
#   3. UIKit imports only allowed in Comparison/HapticFeedbackManager.swift and App/
#   4. Feature views must not import SwiftData directly
#   5. No cross-feature type references between feature directories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/Peach"

ERRORS=0

red()   { printf '\033[1;31m%s\033[0m\n' "$1"; }
green() { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[1;33m%s\033[0m\n' "$1"; }

check_import() {
    local dir="$1"          # directory to scan
    local module="$2"       # forbidden import (e.g. SwiftUI)
    local rule_name="$3"    # human-readable rule description
    local exclude="${4:-}"  # optional grep -v pattern to exclude specific files

    local matches
    if [[ -n "$exclude" ]]; then
        matches=$(grep -rn "^import ${module}$" "$dir" --include="*.swift" | grep -v "$exclude" || true)
    else
        matches=$(grep -rn "^import ${module}$" "$dir" --include="*.swift" || true)
    fi

    if [[ -n "$matches" ]]; then
        red "VIOLATION: $rule_name"
        echo "$matches" | while IFS= read -r line; do
            echo "  $line"
        done
        echo
        ERRORS=$((ERRORS + 1))
    fi
}

echo "Checking dependency rules in $SRC_DIR ..."
echo

# ─── Rule 1: Core/ must not import SwiftUI, UIKit, or Charts ────────────
check_import "$SRC_DIR/Core" "SwiftUI" \
    "Core/ must not import SwiftUI (domain layer is framework-free)"

check_import "$SRC_DIR/Core" "UIKit" \
    "Core/ must not import UIKit (domain layer is framework-free)"

check_import "$SRC_DIR/Core" "Charts" \
    "Core/ must not import Charts (UI framework belongs in feature layer)"

# ─── Rule 2: SwiftData only in Core/Data/ and App/ ──────────────────────
# Check all of Peach/ except Core/Data/ and App/
for dir in "$SRC_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "App" ]] && continue
    [[ "$dirname" == "Resources" ]] && continue

    if [[ "$dirname" == "Core" ]]; then
        # Within Core, only Core/Data/ may import SwiftData
        for coredir in "$SRC_DIR/Core"/*/; do
            core_subdir=$(basename "$coredir")
            [[ "$core_subdir" == "Data" ]] && continue
            check_import "$coredir" "SwiftData" \
                "Core/$core_subdir/ must not import SwiftData (only Core/Data/ may)"
        done
    else
        check_import "$dir" "SwiftData" \
            "$dirname/ must not import SwiftData (access SwiftData through TrainingDataStore)"
    fi
done

# ─── Rule 3: UIKit only in allowed files ─────────────────────────────────
# Allowed: App/ (composition root), Comparison/HapticFeedbackManager.swift
for dir in "$SRC_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "App" ]] && continue
    [[ "$dirname" == "Core" ]] && continue
    [[ "$dirname" == "Resources" ]] && continue

    if [[ "$dirname" == "Comparison" ]]; then
        check_import "$dir" "UIKit" \
            "Comparison/ must not import UIKit (except HapticFeedbackManager.swift)" \
            "HapticFeedbackManager.swift"
    else
        check_import "$dir" "UIKit" \
            "$dirname/ must not import UIKit (inject via protocol from composition root)"
    fi
done

# ─── Rule 4: No Combine in any production code ──────────────────────────
for dir in "$SRC_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "Resources" ]] && continue
    check_import "$dir" "Combine" \
        "$dirname/ must not import Combine (use async/await)"
done

# ─── Rule 5: Cross-feature type references ───────────────────────────────
# Feature directories: Comparison, PitchMatching, Profile, Settings, Start, Info
# Each feature's Screen type should not be referenced from other features,
# EXCEPT: Start/ is the navigation router and legitimately references all screens.
# Only App/, Start/ (router), and the feature's own directory may reference its Screen.

FEATURES=("Comparison" "PitchMatching" "Profile" "Settings" "Start" "Info")
SCREEN_TYPES=("ComparisonScreen" "PitchMatchingScreen" "ProfileScreen" "SettingsScreen" "StartScreen" "InfoScreen")

for i in "${!FEATURES[@]}"; do
    feature="${FEATURES[$i]}"
    screen="${SCREEN_TYPES[$i]}"

    for j in "${!FEATURES[@]}"; do
        other="${FEATURES[$j]}"
        [[ "$feature" == "$other" ]] && continue
        # Start/ is the navigation router — it must reference all screens
        [[ "$other" == "Start" ]] && continue

        matches=$(grep -rn "\b${screen}\b" "$SRC_DIR/$other/" --include="*.swift" 2>/dev/null || true)
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

# ─── Rule 6: Feature types used in other features (known patterns) ───────
# ComparisonFeedbackIndicator should not be referenced from PitchMatching/
matches=$(grep -rn "ComparisonFeedbackIndicator" "$SRC_DIR/PitchMatching/" --include="*.swift" 2>/dev/null || true)
if [[ -n "$matches" ]]; then
    red "VIOLATION: PitchMatching/ references ComparisonFeedbackIndicator (cross-feature dependency)"
    echo "$matches" | while IFS= read -r line; do
        echo "  $line"
    done
    echo
    ERRORS=$((ERRORS + 1))
fi

# ─── Summary ─────────────────────────────────────────────────────────────
echo "─────────────────────────────────────"
if [[ $ERRORS -eq 0 ]]; then
    green "All dependency rules passed."
    exit 0
else
    red "$ERRORS violation(s) found."
    exit 1
fi
