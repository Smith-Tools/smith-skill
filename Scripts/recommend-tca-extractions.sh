#!/bin/bash

# Smith TCA Feature Extraction Recommender
# Suggests which features to extract based on composition analysis
# Usage: ./recommend-tca-extractions.sh [path] [--json] [--effort-only]

set -e

# Arguments
SEARCH_PATH="${1:-.}"
JSON_OUTPUT=false
EFFORT_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --effort-only)
            EFFORT_ONLY=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Output header (unless JSON)
if [ "$JSON_OUTPUT" = false ]; then
    echo "🎯 TCA Feature Extraction Recommendations"
    echo "========================================"
    echo "Path: $SEARCH_PATH"
    echo ""
fi

# Arrays for recommendations
declare -a PRIORITY_1
declare -a PRIORITY_2
declare -a PRIORITY_3

# Find all TCA reducer files
REDUCER_FILES=$(find "$SEARCH_PATH" -name "*Feature.swift" -o -name "*Reducer.swift" | grep -v ".build" | grep -v "Pods" | sort)

while IFS= read -r reducer_file; do
    if [ -z "$reducer_file" ]; then
        continue
    fi

    filename=$(basename "$reducer_file" .swift)

    # Analyze for extraction candidates
    STATE_PROPS=$(grep "^\s*var " "$reducer_file" | wc -l)
    ACTION_CASES=$(grep "^\s*case " "$reducer_file" | wc -l)
    CLOSURES=$(grep -E "var\s+\w+:\s*\([^)]*\)\s*->\s*Effect" "$reducer_file" | wc -l)

    # Priority 1: Closures (blocks testing - highest priority)
    if [ "$CLOSURES" -gt 0 ]; then
        PRIORITY_1+=("EXTRACT: $filename - Replace $CLOSURES closure injection(s) with @Dependency|Effort: 2 hours|Impact: Unblocks unit testing")
    fi

    # Priority 2: Large features (> 15 props or > 40 cases)
    if [ "$STATE_PROPS" -gt 15 ] || [ "$ACTION_CASES" -gt 40 ]; then
        ESTIMATED_EFFORT="4-6 hours"
        if [ "$STATE_PROPS" -gt 25 ]; then
            ESTIMATED_EFFORT="8-12 hours"
        fi
        PRIORITY_2+=("EXTRACT: ${filename} - State has $STATE_PROPS properties, Actions: $ACTION_CASES|Effort: $ESTIMATED_EFFORT|Impact: +1000 testable lines")
    fi

    # Priority 3: Organization improvements (5+ helper methods)
    HELPER_METHODS=$(grep "^\s*private\s*func" "$reducer_file" | wc -l)
    if [ "$HELPER_METHODS" -gt 5 ]; then
        PRIORITY_3+=("CLARIFY: ${filename} - $HELPER_METHODS helper methods|Effort: 4-8 hours|Impact: Improved clarity")
    fi

done <<< "$REDUCER_FILES"

# JSON output
if [ "$JSON_OUTPUT" = true ]; then
    printf "{"
    printf "\"recommendations\":{"

    # Priority 1
    printf "\"p1\":["
    for i in "${!PRIORITY_1[@]}"; do
        IFS='|' read -r task effort impact <<< "${PRIORITY_1[$i]}"
        printf "{\"task\":\"%s\",\"effort\":\"%s\",\"impact\":\"%s\"}" "$task" "$effort" "$impact"
        if [ $i -lt $((${#PRIORITY_1[@]} - 1)) ]; then
            printf ","
        fi
    done
    printf "],"

    printf "\"p2\":["
    for i in "${!PRIORITY_2[@]}"; do
        IFS='|' read -r task effort impact <<< "${PRIORITY_2[$i]}"
        printf "{\"task\":\"%s\",\"effort\":\"%s\",\"impact\":\"%s\"}" "$task" "$effort" "$impact"
        if [ $i -lt $((${#PRIORITY_2[@]} - 1)) ]; then
            printf ","
        fi
    done
    printf "],"

    printf "\"p3\":["
    for i in "${!PRIORITY_3[@]}"; do
        IFS='|' read -r task effort impact <<< "${PRIORITY_3[$i]}"
        printf "{\"task\":\"%s\",\"effort\":\"%s\",\"impact\":\"%s\"}" "$task" "$effort" "$impact"
        if [ $i -lt $((${#PRIORITY_3[@]} - 1)) ]; then
            printf ","
        fi
    done
    printf "]"

    printf "}}"
    echo ""
else
    # Human-readable output
    echo "════════════════════════════════════════════════════════════"
    echo "📋 EXTRACTION RECOMMENDATIONS"
    echo "════════════════════════════════════════════════════════════"
    echo ""

    TOTAL_RECS=$((${#PRIORITY_1[@]} + ${#PRIORITY_2[@]} + ${#PRIORITY_3[@]}))

    if [ "$TOTAL_RECS" -eq 0 ]; then
        echo "✅ No extraction recommendations at this time"
        echo "   Keep monitoring composition metrics"
    else
        echo "Total recommendations: $TOTAL_RECS"
        echo ""

        if [ "${#PRIORITY_1[@]}" -gt 0 ]; then
            echo "🔴 PRIORITY 1 (Do First - Unblocks Testing)"
            echo "─────────────────────────────────────────"
            echo ""
            for rec in "${PRIORITY_1[@]}"; do
                IFS='|' read -r task effort impact <<< "$rec"
                echo "   $task"
                echo "   ⏱️  $effort"
                echo "   💡 $impact"
                echo ""
            done
        fi

        if [ "${#PRIORITY_2[@]}" -gt 0 ]; then
            echo "🟠 PRIORITY 2 (Next Sprint - Maintainability)"
            echo "──────────────────────────────────────────"
            echo ""
            for rec in "${PRIORITY_2[@]}"; do
                IFS='|' read -r task effort impact <<< "$rec"
                echo "   $task"
                echo "   ⏱️  $effort"
                echo "   💡 $impact"
                echo ""
            done
        fi

        if [ "${#PRIORITY_3[@]}" -gt 0 ] && [ "$EFFORT_ONLY" = false ]; then
            echo "🟡 PRIORITY 3 (Future - Clarity)"
            echo "───────────────────────────────"
            echo ""
            for rec in "${PRIORITY_3[@]}"; do
                IFS='|' read -r task effort impact <<< "$rec"
                echo "   $task"
                echo "   ⏱️  $effort"
                echo "   💡 $impact"
                echo ""
            done
        fi

        # Summary
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "📊 Effort Summary:"
        TOTAL_EFFORT=0
        if [ "${#PRIORITY_1[@]}" -gt 0 ]; then
            P1_EFFORT=$((${#PRIORITY_1[@]} * 2))
            TOTAL_EFFORT=$((TOTAL_EFFORT + P1_EFFORT))
            echo "   P1: ~${P1_EFFORT} hours (closure replacements)"
        fi
        if [ "${#PRIORITY_2[@]}" -gt 0 ]; then
            P2_EFFORT=$((${#PRIORITY_2[@]} * 5))
            TOTAL_EFFORT=$((TOTAL_EFFORT + P2_EFFORT))
            echo "   P2: ~${P2_EFFORT} hours (feature extractions)"
        fi
        if [ "${#PRIORITY_3[@]}" -gt 0 ] && [ "$EFFORT_ONLY" = false ]; then
            P3_EFFORT=$((${#PRIORITY_3[@]} * 6))
            TOTAL_EFFORT=$((TOTAL_EFFORT + P3_EFFORT))
            echo "   P3: ~${P3_EFFORT} hours (clarifications)"
        fi
        echo ""
        echo "   Total: ~${TOTAL_EFFORT} hours (phased approach recommended)"
        echo ""

        echo "🚀 Suggested Sprint Plan:"
        if [ "${#PRIORITY_1[@]}" -gt 0 ]; then
            P1_TIME=$((${#PRIORITY_1[@]} * 2))
            echo "   • Week 1: Priority 1 items (~${P1_TIME}h) - unblock testing"
        fi
        if [ "${#PRIORITY_2[@]}" -gt 0 ]; then
            P2_TIME=$((${#PRIORITY_2[@]} * 5))
            echo "   • Week 2-3: Priority 2 items (~${P2_TIME}h) - maintain code"
        fi
        if [ "${#PRIORITY_3[@]}" -gt 0 ] && [ "$EFFORT_ONLY" = false ]; then
            P3_TIME=$((${#PRIORITY_3[@]} * 6))
            echo "   • Week 4+: Priority 3 items (~${P3_TIME}h) - improve clarity"
        fi
        echo ""

        echo "📚 Reference:"
        echo "   AGENTS-TCA-PATTERNS.md - Pattern 3: Multiple Destinations"
        echo "   AGENTS-AGNOSTIC.md - Modularization Best Practices"
    fi
fi

exit 0
