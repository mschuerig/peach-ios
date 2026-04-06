#!/bin/bash
# Enforces architectural dependency rules for the Peach project.
# Run before commits or in CI. Exit code 0 = clean, 1 = violations found.
#
# Rules enforced:
#   1. Core/ must not import SwiftUI, UIKit, or Charts
#   2. SwiftData only in Core/Data/, App/, and TrainingDiscipline chain
#   3. UIKit only in Training/PitchDiscrimination/HapticFeedbackManager.swift and App/
#   4. No Combine in production code (use async/await)
#   5. No cross-feature type references between feature directories
#   6. No print() in production code (use Logger)

set -euo pipefail
shopt -s nullglob

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

    # Catches bare imports, qualified imports (import struct M.Type), and
    # attributed imports (@testable import M, @_exported import M).
    local pattern="^(@[a-zA-Z_]+[[:space:]]+)?import[[:space:]]+(struct[[:space:]]+|class[[:space:]]+|enum[[:space:]]+|protocol[[:space:]]+|func[[:space:]]+)?${module}($|\.)"

    local matches
    if [[ -n "$exclude" ]]; then
        matches=$(grep -rEn "$pattern" "$dir" --include="*.swift" | grep -v "$exclude" || true)
    else
        matches=$(grep -rEn "$pattern" "$dir" --include="*.swift" || true)
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

# ─── Rule 2: SwiftData only in Core/Data/, App/, and TrainingDiscipline chain ─
# TrainingDiscipline protocol and its implementations need SwiftData because
# PersistentModel cannot be type-erased without losing compile-time safety.
# Accepted exception: TrainingDiscipline.swift, TrainingDisciplineRegistry.swift,
# TrainingRecordPersisting.swift, and *Discipline.swift in feature directories.

# Collect all feature directories (top-level + Training/ children).
# Any new top-level directory is treated as a feature by default — if it is
# infrastructure (not a feature), add it to the skip list below.
FEATURE_DIRS=()
for dir in "$SRC_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "App" ]] && continue
    [[ "$dirname" == "Resources" ]] && continue
    [[ "$dirname" == "Core" ]] && continue
    if [[ "$dirname" == "Training" ]]; then
        for subdir in "$dir"*/; do
            FEATURE_DIRS+=("$subdir")
        done
    else
        FEATURE_DIRS+=("$dir")
    fi
done

for dir in "$SRC_DIR/Core"/*/; do
    core_subdir=$(basename "$dir")
    [[ "$core_subdir" == "Data" ]] && continue
    if [[ "$core_subdir" == "Training" ]]; then
        check_import "$dir" "SwiftData" \
            "Core/Training/ must not import SwiftData (except TrainingDiscipline chain)" \
            "TrainingDiscipline\|TrainingDisciplineRegistry"
        continue
    fi
    if [[ "$core_subdir" == "Ports" ]]; then
        check_import "$dir" "SwiftData" \
            "Core/Ports/ must not import SwiftData (except TrainingRecordPersisting)" \
            "TrainingRecordPersisting"
        continue
    fi
    check_import "$dir" "SwiftData" \
        "Core/$core_subdir/ must not import SwiftData (only Core/Data/ and discipline chain may)"
done

for dir in "${FEATURE_DIRS[@]}"; do
    dirname=$(basename "$dir")
    check_import "$dir" "SwiftData" \
        "$dirname/ must not import SwiftData (access SwiftData through TrainingDataStore)" \
        "[A-Z][a-zA-Z]*Discipline\\.swift:"
done

# ─── Rule 3: UIKit only in allowed files ─────────────────────────────────
# Allowed: App/ (composition root), Training/PitchDiscrimination/HapticFeedbackManager.swift
for dir in "${FEATURE_DIRS[@]}"; do
    dirname=$(basename "$dir")

    if [[ "$dirname" == "PitchDiscrimination" ]]; then
        check_import "$dir" "UIKit" \
            "PitchDiscrimination/ must not import UIKit (except HapticFeedbackManager.swift)" \
            "HapticFeedbackManager.swift"
    else
        check_import "$dir" "UIKit" \
            "$dirname/ must not import UIKit (inject via protocol from composition root)"
    fi
done

# ─── Rule 4: No Combine in any production code ──────────────────────────
# Single recursive pass over all top-level dirs. Training/ is checked recursively,
# covering both loose files at the root and all feature subdirectories.
for dir in "$SRC_DIR"/*/; do
    dirname=$(basename "$dir")
    [[ "$dirname" == "Resources" ]] && continue
    check_import "$dir" "Combine" \
        "$dirname/ must not import Combine (use async/await)"
done

# ─── Rule 5: Cross-feature type references ───────────────────────────────
# Feature directories must not reference each other's Screen types.
# EXCEPT: Start/ is the navigation router and legitimately references all screens.
# Only App/, Start/ (router), and the feature's own directory may reference its Screen.

# Build parallel arrays in lockstep — screen type is derived by convention (${name}Screen).
FEATURE_NAMES=()
SCREEN_TYPES=()
FEATURE_PATHS=()

# Training feature directories
for name in PitchDiscrimination PitchMatching RhythmOffsetDetection ContinuousRhythmMatching; do
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

# ─── Rule 6: Feature types used in other features (known patterns) ───────
# PitchDiscriminationFeedbackIndicator should not be referenced from PitchMatching/.
# Path derived from FEATURE_PATHS to stay in sync with Rule 5 arrays.
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

# ─── Rule 7: No print() in production code ──────────────────────────────
# All logging should use os.Logger, not print()
matches=$(grep -rn 'print(' "$SRC_DIR" --include="*.swift" || true)
if [[ -n "$matches" ]]; then
    red "VIOLATION: print() found in production code (use Logger from os framework)"
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
