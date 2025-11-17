#!/bin/bash

# Smith TCA Dependency Graph Analyzer
# Maps state property dependencies and identifies coupling complexity
# Usage: ./analyze-tca-dependency-graph.sh [path] [--json] [--detailed]

set -e

# Arguments
SEARCH_PATH="${1:-.}"
JSON_OUTPUT=false
DETAILED_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --detailed)
            DETAILED_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Output header (unless JSON)
if [ "$JSON_OUTPUT" = false ]; then
    echo "📊 TCA Dependency Graph Analysis"
    echo "================================="
    echo "Path: $SEARCH_PATH"
    echo ""
fi

# Find all TCA reducer files
REDUCER_FILES=$(find "$SEARCH_PATH" -name "*Feature.swift" -o -name "*Reducer.swift" | grep -v ".build" | grep -v "Pods" | sort)

# JSON output arrays
declare -a GRAPHS
TOTAL_SYNC_POINTS=0
HIGH_COMPLEXITY_COUNT=0

# Analyze each reducer
while IFS= read -r reducer_file; do
    if [ -z "$reducer_file" ]; then
        continue
    fi

    filename=$(basename "$reducer_file")

    # Extract state struct
    STATE_START=$(grep -n "@ObservableState\|struct State" "$reducer_file" | head -1 | cut -d: -f1)
    if [ -z "$STATE_START" ]; then
        continue
    fi

    # Count state properties
    STATE_PROPERTIES=$(sed -n "${STATE_START},/^}/p" "$reducer_file" | grep "^\s*var " | sed 's/.*var //' | sed 's/:.*//' | tr '\n' ' ')

    if [ -z "$STATE_PROPERTIES" ]; then
        continue
    fi

    # Analyze which reducers modify which properties
    # This is a simplified analysis - production version would be more sophisticated
    SYNC_COMPLEX=0

    # Count how many times each property is referenced in Reduce blocks
    SYNC_POINTS=$(grep -c "@ObservableState\|Reduce" "$reducer_file" | head -1)
    TOTAL_SYNC_POINTS=$((TOTAL_SYNC_POINTS + SYNC_POINTS))

    # Check for cascading updates (detect common patterns)
    # Look for methods that update multiple properties
    UPDATE_METHODS=$(grep -o "^\s*private\s*func.*{" "$reducer_file" | wc -l)

    if [ "$UPDATE_METHODS" -gt 3 ]; then
        HIGH_COMPLEXITY_COUNT=$((HIGH_COMPLEXITY_COUNT + 1))
        SYNC_COMPLEX=$((SYNC_COMPLEX + 10))
    fi

    # Count Reduce blocks
    REDUCE_COUNT=$(grep -c "Reduce {" "$reducer_file" || echo 0)

    # Estimate dependency complexity
    # Higher = more tightly coupled
    COMPLEXITY_SCORE=$((REDUCE_COUNT * 2 + UPDATE_METHODS))

    if [ "$JSON_OUTPUT" = true ]; then
        GRAPH="{\"file\":\"$filename\",\"path\":\"$reducer_file\",\"properties\":$(($(echo "$STATE_PROPERTIES" | wc -w)),\"reduce_blocks\":$REDUCE_COUNT,\"update_methods\":$UPDATE_METHODS,\"complexity_score\":$COMPLEXITY_SCORE,\"sync_points\":$SYNC_POINTS}"
        GRAPHS+=("$GRAPH")
    fi

    # Output analysis (unless JSON)
    if [ "$JSON_OUTPUT" = false ]; then
        echo "📄 $filename"
        echo "   Path: $reducer_file"
        echo "   State properties: $(echo "$STATE_PROPERTIES" | wc -w)"

        if [ "$DETAILED_MODE" = true ]; then
            echo "   Properties: $STATE_PROPERTIES"
        fi

        echo "   Reduce blocks: $REDUCE_COUNT"
        echo "   Update methods: $UPDATE_METHODS"
        echo "   Complexity score: $COMPLEXITY_SCORE"

        if [ "$COMPLEXITY_SCORE" -gt 15 ]; then
            echo "   ⚠️  HIGH COMPLEXITY: Consider decomposing"
        elif [ "$COMPLEXITY_SCORE" -gt 8 ]; then
            echo "   ⚠️  MEDIUM COMPLEXITY: Monitor for coupling"
        else
            echo "   ✅ ACCEPTABLE COMPLEXITY"
        fi
        echo ""
    fi

done <<< "$REDUCER_FILES"

# Output summary
if [ "$JSON_OUTPUT" = true ]; then
    printf "{"
    printf "\"files_analyzed\":%d," "$(echo "$REDUCER_FILES" | wc -l)"
    printf "\"total_sync_points\":%d," "$TOTAL_SYNC_POINTS"
    printf "\"high_complexity_reducers\":%d," "$HIGH_COMPLEXITY_COUNT"
    printf "\"graphs\":["

    for i in "${!GRAPHS[@]}"; do
        printf "%s" "${GRAPHS[$i]}"
        if [ $i -lt $((${#GRAPHS[@]} - 1)) ]; then
            printf ","
        fi
    done

    printf "]}"
    echo ""
else
    # Human-readable summary
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "📈 DEPENDENCY GRAPH SUMMARY"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Reducers analyzed: $(echo "$REDUCER_FILES" | wc -l)"
    echo "Total synchronization points: $TOTAL_SYNC_POINTS"
    echo "High-complexity reducers: $HIGH_COMPLEXITY_COUNT"
    echo ""

    if [ "$HIGH_COMPLEXITY_COUNT" -eq 0 ]; then
        echo "✅ No high-complexity patterns detected"
    else
        echo "⚠️  $HIGH_COMPLEXITY_COUNT reducer(s) have high complexity"
        echo "   Consider:"
        echo "   • Breaking into smaller, focused reducers"
        echo "   • Reducing the number of child features in state"
        echo "   • Simplifying state update logic"
    fi

    echo ""
    echo "💡 Guidance:"
    echo "   Complexity Score < 8:  ✅ Healthy composition"
    echo "   Complexity Score 8-15: ⚠️  Monitor for coupling"
    echo "   Complexity Score > 15: 🔴 Consider decomposition"
    echo ""
    echo "📚 Reference: AGENTS-TCA-PATTERNS.md - Pattern 3: Multiple Destinations"
fi

exit 0
