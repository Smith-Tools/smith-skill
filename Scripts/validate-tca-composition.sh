#!/bin/bash

# Smith TCA Composition Validator
# Detects composition anti-patterns in TCA reducers
# Usage: ./validate-tca-composition.sh [path] [--json] [--strict]
#
# Rules detected:
# Rule 1.1: Monolithic Features (15+ properties, 40+ actions)
# Rule 1.2: Closure Dependency Injection (untestable patterns)
# Rule 1.3: Code Duplication (duplicate action handling)
# Rule 1.4: Unclear Reducer Organization (vague method names)
# Rule 1.5: Tightly Coupled Child Features (cascading updates)

set -e

# Arguments
SEARCH_PATH="${1:-.}"
JSON_OUTPUT=false
STRICT_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Initialize counters and arrays
VIOLATIONS_FOUND=0
HIGH_ALERTS=0
MEDIUM_ALERTS=0
LOW_ALERTS=0

# JSON output arrays
declare -a HIGH_VIOLATIONS
declare -a MEDIUM_VIOLATIONS
declare -a LOW_VIOLATIONS

# Helper function to add violation
add_violation() {
    local level=$1
    local file=$2
    local rule=$3
    local message=$4
    local line=${5:-""}

    if [ "$JSON_OUTPUT" = true ]; then
        case $level in
            HIGH)
                HIGH_VIOLATIONS+=("{\"file\":\"$file\",\"rule\":\"$rule\",\"line\":\"$line\",\"message\":\"$message\"}")
                ;;
            MEDIUM)
                MEDIUM_VIOLATIONS+=("{\"file\":\"$file\",\"rule\":\"$rule\",\"line\":\"$line\",\"message\":\"$message\"}")
                ;;
            LOW)
                LOW_VIOLATIONS+=("{\"file\":\"$file\",\"rule\":\"$rule\",\"line\":\"$line\",\"message\":\"$message\"}")
                ;;
        esac
    fi

    VIOLATIONS_FOUND=$((VIOLATIONS_FOUND + 1))
    case $level in
        HIGH) HIGH_ALERTS=$((HIGH_ALERTS + 1)) ;;
        MEDIUM) MEDIUM_ALERTS=$((MEDIUM_ALERTS + 1)) ;;
        LOW) LOW_ALERTS=$((LOW_ALERTS + 1)) ;;
    esac
}

# Output header (unless JSON)
if [ "$JSON_OUTPUT" = false ]; then
    echo "🔍 TCA Composition Validation"
    echo "============================="
    echo "Path: $SEARCH_PATH"
    echo ""
fi

# Find all TCA reducer files
REDUCER_FILES=$(find "$SEARCH_PATH" -name "*Feature.swift" -o -name "*Reducer.swift" | grep -v ".build" | grep -v "Pods" | sort)

if [ -z "$REDUCER_FILES" ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo "{\"success\":true,\"violations\":0,\"high\":0,\"medium\":0,\"low\":0,\"files_analyzed\":0}"
    else
        echo "⚠️  No reducer files found in $SEARCH_PATH"
    fi
    exit 0
fi

FILE_COUNT=0

# Analyze each reducer file
while IFS= read -r reducer_file; do
    if [ -z "$reducer_file" ]; then
        continue
    fi

    FILE_COUNT=$((FILE_COUNT + 1))
    filename=$(basename "$reducer_file")

    # Rule 1.1: Detect monolithic features (15+ state properties, 40+ action cases)
    STATE_PROPERTY_COUNT=$(grep -c "^\s*var " "$reducer_file" | head -1 || echo 0)
    ACTION_CASE_COUNT=$(grep -c "^\s*case " "$reducer_file" | head -1 || echo 0)

    if [ "$STATE_PROPERTY_COUNT" -gt 15 ]; then
        add_violation "HIGH" "$reducer_file" "1.1" "State has $STATE_PROPERTY_COUNT properties (threshold: 15) - consider extracting features"
        if [ "$JSON_OUTPUT" = false ]; then
            echo "🔴 HIGH: $filename"
            echo "   Rule 1.1: Monolithic Feature"
            echo "   State properties: $STATE_PROPERTY_COUNT (threshold: 15)"
        fi
    fi

    if [ "$ACTION_CASE_COUNT" -gt 40 ]; then
        add_violation "HIGH" "$reducer_file" "1.1" "Action enum has $ACTION_CASE_COUNT cases (threshold: 40) - indicates multiple features"
        if [ "$JSON_OUTPUT" = false ]; then
            echo "🔴 HIGH: $filename"
            echo "   Rule 1.1: Monolithic Feature"
            echo "   Action cases: $ACTION_CASE_COUNT (threshold: 40)"
        fi
    fi

    # Rule 1.2: Detect closure dependency injection (var x: (...) -> Effect)
    CLOSURE_INJECTIONS=$(grep -E "var\s+\w+:\s*\([^)]*\)\s*->\s*(Effect|some\s+Effect)" "$reducer_file" | wc -l)

    if [ "$CLOSURE_INJECTIONS" -gt 0 ]; then
        add_violation "HIGH" "$reducer_file" "1.2" "Found $CLOSURE_INJECTIONS closure injection pattern(s) - use @Dependency instead"
        if [ "$JSON_OUTPUT" = false ]; then
            echo "🔴 CRITICAL: $filename"
            echo "   Rule 1.2: Closure Dependency Injection"
            echo "   Found $CLOSURE_INJECTIONS closure(s) - blocks unit testing"
            grep -n -E "var\s+\w+:\s*\([^)]*\)\s*->\s*(Effect|some\s+Effect)" "$reducer_file" | sed 's/^/     Line /'
        fi
    fi

    # Rule 1.3: Detect duplicate action handling (same case name in multiple Reduce blocks)
    DUPLICATE_CASES=$(grep -o "case \.[a-zA-Z_][a-zA-Z0-9_]*" "$reducer_file" | sort | uniq -d | wc -l)

    if [ "$DUPLICATE_CASES" -gt 0 ]; then
        add_violation "MEDIUM" "$reducer_file" "1.3" "Found $DUPLICATE_CASES duplicate action case(s) - consolidate into single handler"
        if [ "$JSON_OUTPUT" = false ]; then
            echo "🟠 MEDIUM: $filename"
            echo "   Rule 1.3: Code Duplication"
            echo "   Duplicate action cases: $DUPLICATE_CASES"
            echo "   Duplicate cases:"
            grep -o "case \.[a-zA-Z_][a-zA-Z0-9_]*" "$reducer_file" | sort | uniq -d | sed 's/^/     /'
        fi
    fi

    # Rule 1.4: Detect unclear reducer organization (vague method names)
    VAGUE_METHODS=$(grep -E "^\s*private\s+func\s+(.*Features|.*Reducers|utility|helper|misc)" "$reducer_file" | wc -l)

    if [ "$VAGUE_METHODS" -gt 3 ]; then
        add_violation "LOW" "$reducer_file" "1.4" "Found $VAGUE_METHODS vague reducer methods - clarify boundaries"
        if [ "$JSON_OUTPUT" = false ]; then
            echo "🟡 LOW: $filename"
            echo "   Rule 1.4: Unclear Organization"
            echo "   Vague method names: $VAGUE_METHODS"
            grep -n -E "^\s*private\s+func\s+(.*Features|.*Reducers|utility|helper|misc)" "$reducer_file" | sed 's/^/     Line /'
        fi
    fi

    # Rule 1.5: Detect tightly coupled state (multiple @Presents or child states)
    CHILD_STATES=$(grep -E "@Presents\s+var|var\s+\w+:\s*\w+Feature\.State\?" "$reducer_file" | wc -l)

    if [ "$CHILD_STATES" -gt 5 ]; then
        add_violation "MEDIUM" "$reducer_file" "1.5" "Found $CHILD_STATES child features - may have cascading update complexity"
        if [ "$JSON_OUTPUT" = false ]; then
            echo "🟠 MEDIUM: $filename"
            echo "   Rule 1.5: Tight Coupling"
            echo "   Child features in state: $CHILD_STATES"
        fi
    fi

    # Print detailed analysis if not JSON and violations found
    if [ "$JSON_OUTPUT" = false ] && [ "$VIOLATIONS_FOUND" -gt 0 ]; then
        echo ""
    fi

done <<< "$REDUCER_FILES"

# Output summary
if [ "$JSON_OUTPUT" = true ]; then
    # JSON output format
    printf "{"
    printf "\"success\":true,"
    printf "\"violations\":%d," "$VIOLATIONS_FOUND"
    printf "\"high\":%d," "$HIGH_ALERTS"
    printf "\"medium\":%d," "$MEDIUM_ALERTS"
    printf "\"low\":%d," "$LOW_ALERTS"
    printf "\"files_analyzed\":%d," "$FILE_COUNT"

    # Add violations arrays
    printf "\"high_violations\":["
    for i in "${!HIGH_VIOLATIONS[@]}"; do
        printf "%s" "${HIGH_VIOLATIONS[$i]}"
        if [ $i -lt $((${#HIGH_VIOLATIONS[@]} - 1)) ]; then
            printf ","
        fi
    done
    printf "],"

    printf "\"medium_violations\":["
    for i in "${!MEDIUM_VIOLATIONS[@]}"; do
        printf "%s" "${MEDIUM_VIOLATIONS[$i]}"
        if [ $i -lt $((${#MEDIUM_VIOLATIONS[@]} - 1)) ]; then
            printf ","
        fi
    done
    printf "],"

    printf "\"low_violations\":["
    for i in "${!LOW_VIOLATIONS[@]}"; do
        printf "%s" "${LOW_VIOLATIONS[$i]}"
        if [ $i -lt $((${#LOW_VIOLATIONS[@]} - 1)) ]; then
            printf ","
        fi
    done
    printf "]"
    printf "}"
    echo ""
else
    # Human-readable summary
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "📊 COMPOSITION VALIDATION SUMMARY"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Files analyzed: $FILE_COUNT"
    echo "Total violations: $VIOLATIONS_FOUND"
    echo ""
    echo "🔴 HIGH (blocking): $HIGH_ALERTS"
    echo "🟠 MEDIUM (important): $MEDIUM_ALERTS"
    echo "🟡 LOW (guidance): $LOW_ALERTS"
    echo ""

    if [ "$VIOLATIONS_FOUND" -eq 0 ]; then
        echo "✅ No composition violations found!"
        echo ""
        echo "📚 Reference: See AGENTS-TCA-PATTERNS.md for composition guidelines"
    else
        echo "❌ Composition violations detected"
        echo ""

        if [ "$STRICT_MODE" = true ] && [ "$HIGH_ALERTS" -gt 0 ]; then
            echo "🔴 STRICT MODE: HIGH violations found - failing build"
            echo ""
            echo "💡 To fix HIGH violations:"
            echo "   • Rule 1.1: Extract features when State > 15 props or Actions > 40"
            echo "   • Rule 1.2: Replace closure injection with @Dependency declarations"
            echo ""
            exit 1
        fi

        echo "💡 To fix violations:"
        echo "   HIGH (1.1-1.2): These block testing and maintainability - fix immediately"
        echo "   MEDIUM (1.3, 1.5): Important for clarity and reducing bugs"
        echo "   LOW (1.4): Improve clarity for team understanding"
        echo ""
        echo "📚 Reference: See AGENTS-TCA-PATTERNS.md for detailed guidance"
    fi
fi

exit 0
