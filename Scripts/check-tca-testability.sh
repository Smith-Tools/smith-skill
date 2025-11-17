#!/bin/bash

# Smith TCA Testability Checker
# Scores testability based on anti-patterns that block testing
# Usage: ./check-tca-testability.sh [path] [--json] [--threshold SCORE]

set -e

# Arguments
SEARCH_PATH="${1:-.}"
JSON_OUTPUT=false
THRESHOLD=75

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --threshold)
            THRESHOLD=$2
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Output header (unless JSON)
if [ "$JSON_OUTPUT" = false ]; then
    echo "📋 TCA Testability Assessment"
    echo "============================="
    echo "Path: $SEARCH_PATH"
    echo "Target Score: ${THRESHOLD}+"
    echo ""
fi

# Testability scoring model
# Start at 100, subtract for each anti-pattern

BASE_SCORE=100
CLOSURE_INJECTIONS=0
UNTESTABLE_PATTERNS=0
REDUCERS_ANALYZED=0
PROPER_DEPENDENCIES=0

# Find all TCA reducer files
REDUCER_FILES=$(find "$SEARCH_PATH" -name "*Feature.swift" -o -name "*Reducer.swift" | grep -v ".build" | grep -v "Pods" | sort)

# Array for detailed findings
declare -a BLOCKERS
declare -a WARNINGS
declare -a IMPROVEMENTS

while IFS= read -r reducer_file; do
    if [ -z "$reducer_file" ]; then
        continue
    fi

    REDUCERS_ANALYZED=$((REDUCERS_ANALYZED + 1))
    filename=$(basename "$reducer_file")

    # Rule 1: Closure Injection (CRITICAL - blocks isolated testing)
    FILE_CLOSURES=$(grep -E "var\s+\w+:\s*\([^)]*\)\s*->\s*(Effect|some\s+Effect)" "$reducer_file" | wc -l)
    if [ "$FILE_CLOSURES" -gt 0 ]; then
        CLOSURE_INJECTIONS=$((CLOSURE_INJECTIONS + FILE_CLOSURES))
        BLOCKERS+=("$filename: $FILE_CLOSURES closure injection(s) - prevents isolated unit testing")
    fi

    # Rule 2: @Dependency usage (positive indicator)
    FILE_DEPENDENCIES=$(grep -c "@Dependency" "$reducer_file" || echo 0)
    if [ "$FILE_DEPENDENCIES" -gt 0 ]; then
        PROPER_DEPENDENCIES=$((PROPER_DEPENDENCIES + FILE_DEPENDENCIES))
    fi

    # Rule 3: Untestable state patterns
    # Look for complex initialization that can't be mocked
    COMPLEX_INIT=$(grep -c "\.run\s*{" "$reducer_file" || echo 0)
    if [ "$COMPLEX_INIT" -gt 5 ]; then
        UNTESTABLE_PATTERNS=$((UNTESTABLE_PATTERNS + 1))
        WARNINGS+=("$filename: $COMPLEX_INIT effect handlers - ensure comprehensive testing")
    fi

    # Rule 4: Code duplication reduces testability
    DUPLICATE_ACTIONS=$(grep -o "case \.[a-zA-Z_][a-zA-Z0-9_]*" "$reducer_file" | sort | uniq -d | wc -l)
    if [ "$DUPLICATE_ACTIONS" -gt 0 ]; then
        WARNINGS+=("$filename: $DUPLICATE_ACTIONS duplicate action handlers - consolidate for single test point")
    fi

    # Rule 5: @ObservableState usage (positive indicator)
    if grep -q "@ObservableState" "$reducer_file"; then
        :  # Good pattern, no penalty
    fi

done <<< "$REDUCER_FILES"

# Calculate testability score
SCORE=$BASE_SCORE
SCORE=$((SCORE - (CLOSURE_INJECTIONS * 10)))  # Each closure: -10
SCORE=$((SCORE - (UNTESTABLE_PATTERNS * 5)))   # Each complex pattern: -5
SCORE=$((SCORE + (PROPER_DEPENDENCIES * 2)))   # Bonus for @Dependency

# Floor score at 0
if [ "$SCORE" -lt 0 ]; then
    SCORE=0
fi

# Determine status
STATUS="✅ PASS"
if [ "$SCORE" -lt 50 ]; then
    STATUS="🔴 CRITICAL"
elif [ "$SCORE" -lt "$THRESHOLD" ]; then
    STATUS="🟠 NEEDS WORK"
fi

# JSON output
if [ "$JSON_OUTPUT" = true ]; then
    printf "{"
    printf "\"score\":%d," "$SCORE"
    printf "\"status\":\"%s\"," "${STATUS:0:1}"
    printf "\"reducers_analyzed\":%d," "$REDUCERS_ANALYZED"
    printf "\"closure_injections\":%d," "$CLOSURE_INJECTIONS"
    printf "\"proper_dependencies\":%d," "$PROPER_DEPENDENCIES"
    printf "\"blockers\":%d," "${#BLOCKERS[@]}"
    printf "\"warnings\":%d" "${#WARNINGS[@]}"
    printf "}"
    echo ""
else
    # Human-readable output
    echo "════════════════════════════════════════════════════════════"
    echo "📊 TESTABILITY SCORE"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Score: $SCORE/100  ($STATUS)"
    echo ""

    # Visual progress bar
    FILLED=$((SCORE / 10))
    EMPTY=$((10 - FILLED))
    printf "Progress: ["
    for ((i = 0; i < FILLED; i++)); do printf "█"; done
    for ((i = 0; i < EMPTY; i++)); do printf "░"; done
    printf "] $SCORE%%\n"
    echo ""

    # Summary statistics
    echo "📈 Statistics:"
    echo "   Reducers analyzed: $REDUCERS_ANALYZED"
    echo "   Closure injections found: $CLOSURE_INJECTIONS"
    echo "   Proper @Dependency uses: $PROPER_DEPENDENCIES"
    echo ""

    # Detailed findings
    if [ "${#BLOCKERS[@]}" -gt 0 ]; then
        echo "🔴 BLOCKERS (prevent isolated testing):"
        for blocker in "${BLOCKERS[@]}"; do
            echo "   • $blocker"
        done
        echo ""
    fi

    if [ "${#WARNINGS[@]}" -gt 0 ]; then
        echo "🟠 WARNINGS (increase test complexity):"
        for warning in "${WARNINGS[@]}"; do
            echo "   • $warning"
        done
        echo ""
    fi

    # Recommendations based on score
    echo "💡 Recommendations:"
    if [ "$SCORE" -lt 50 ]; then
        echo ""
        echo "   CRITICAL: Testability is severely limited"
        echo "   Priority 1: Replace $CLOSURE_INJECTIONS closure injection(s) with @Dependency"
        echo "   Priority 2: Consolidate duplicate action handlers"
        echo "   Priority 3: Extract overly complex reducers"
        echo ""
        echo "   Estimated effort: 8-16 hours"
        echo "   Expected improvement: +30-40 points"
    elif [ "$SCORE" -lt "$THRESHOLD" ]; then
        echo ""
        echo "   Priority: Fix blockers to reach ${THRESHOLD}+"
        if [ "$CLOSURE_INJECTIONS" -gt 0 ]; then
            echo "   • Replace closure injection with @Dependency (+10/closure)"
        fi
        echo "   • Consolidate duplicate logic (+2-5 points)"
        echo ""
        echo "   Estimated effort: 4-8 hours"
        echo "   Expected improvement: +$((THRESHOLD - SCORE)) points"
    else
        echo ""
        echo "   ✅ Testability is good!"
        echo "   • Continue using @Dependency pattern"
        echo "   • Maintain comprehensive test coverage"
        echo "   • Document complex reducer logic"
    fi

    echo ""
    echo "📚 Reference:"
    echo "   AGENTS-TCA-PATTERNS.md - Testing section"
    echo "   AGENTS-TCA-PATTERNS.md - Pattern 5: @Dependency Client"
    echo ""

    # Check threshold
    if [ "$SCORE" -lt "$THRESHOLD" ]; then
        echo "⚠️  Score ($SCORE) below threshold ($THRESHOLD)"
        exit 1
    fi
fi

exit 0
