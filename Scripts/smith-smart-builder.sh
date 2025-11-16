#!/bin/bash

# Smith Smart Builder - Context-Efficient Progressive Building
# Auto-detects workspace, identifies hanging targets, uses sift tools optimally
# Usage: ./smith-smart-builder.sh [timeout-seconds] [--analyze-complexity]

TIMEOUT="${1:-120}"
ANALYZE_COMPLEXITY=false
if [[ "$1" == "--analyze-complexity" ]]; then
    ANALYZE_COMPLEXITY=true
    TIMEOUT="${2:-120}"
elif [[ "$2" == "--analyze-complexity" ]]; then
    ANALYZE_COMPLEXITY=true
fi

set -e

echo "🏗️ SMITH SMART BUILDER"
echo "===================="

# Auto-detect workspace/project (efficiency: no manual paths)
WORKSPACE=""
PROJECT=""
if [ -f "Package.swift" ]; then
    PROJECT_TYPE="SPM"
    echo "📦 Detected: SPM Package"
elif [ -n "$(find . -name "*.xcworkspace" 2>/dev/null | head -1)" ]; then
    WORKSPACE=$(find . -name "*.xcworkspace" | head -1)
    PROJECT_TYPE="XcodeWorkspace"
    echo "📱 Detected: Xcode Workspace - $(basename "$WORKSPACE")"
elif [ -n "$(find . -name "*.xcodeproj" 2>/dev/null | head -1)" ]; then
    PROJECT=$(find . -name "*.xcodeproj" | head -1)
    PROJECT_TYPE="XcodeProject"
    echo "📱 Detected: Xcode Project - $(basename "$PROJECT")"
else
    echo "❌ No Swift project detected"
    exit 1
fi

echo ""

# Complexity Analysis Mode (NEW: Enhanced diagnostics)
if [ "$ANALYZE_COMPLEXITY" = true ]; then
    echo "🔍 PROJECT COMPLEXITY ANALYSIS"
    echo "=============================="

    # Count targets and estimate complexity
    if [ "$PROJECT_TYPE" = "SPM" ]; then
        TARGET_COUNT=$(swift package dump-package | jq -r '.targets | length' 2>/dev/null || echo "unknown")
        DEPENDENCY_COUNT=$(swift package dump-package | jq -r '.dependencies | length' 2>/dev/null || echo "unknown")
        echo "📊 SPM Package Analysis:"
        echo "   Targets: $TARGET_COUNT"
        echo "   Dependencies: $DEPENDENCY_COUNT"

        # Complexity assessment
        if [[ "$TARGET_COUNT" =~ ^[0-9]+$ ]] && [ "$TARGET_COUNT" -gt 20 ]; then
            echo "   ⚠️  High target count (>$TARGET_COUNT) - may cause slow builds"
        fi

    elif [ -n "$WORKSPACE" ]; then
        echo "📊 Xcode Workspace Analysis:"
        # Try to get scheme information
        if command -v xcodebuild &> /dev/null; then
            SCHEME_COUNT=$(xcodebuild -list -workspace "$WORKSPACE" 2>/dev/null | grep -c "Scheme:" || echo "unknown")
            echo "   Schemes: $SCHEME_COUNT"
        fi

        # Check for SPM modules
        if [ -d "ScrollModules" ]; then
            echo "   📦 SPM Modules detected"
            if [ -f "ScrollModules/Package.swift" ]; then
                MODULE_TARGET_COUNT=$(swift package dump-package 2>/dev/null | jq -r '.targets | length' || echo "unknown")
                echo "   Module Targets: $MODULE_TARGET_COUNT"
            fi
        fi

        # Complexity indicators
        echo "   🔍 Complexity Indicators:"
        echo "      - Workspace structure (multiple modules)"
        echo "      - SPM integration detected"

        if [ -d ".build" ] || [ -d "build" ]; then
            echo "      - Build artifacts present (previous builds)"
        fi

    elif [ -n "$PROJECT" ]; then
        echo "📊 Xcode Project Analysis:"
        if command -v xcodebuild &> /dev/null; then
            SCHEME_COUNT=$(xcodebuild -list -project "$PROJECT" 2>/dev/null | grep -c "Scheme:" || echo "unknown")
            echo "   Schemes: $SCHEME_COUNT"
        fi
    fi

    echo ""
    echo "🎯 SMITH RECOMMENDATIONS:"

    # Based on analysis, provide recommendations
    if [ "$PROJECT_TYPE" != "SPM" ]; then
        echo "   📱 This is a complex Xcode project"
        echo "   💡 Recommended testing strategy:"
        echo "      1. Test foundation modules first"
        echo "      2. Use incremental builds"
        echo "      3. Monitor dependency resolution phase"

        if [[ "$SCHEME_COUNT" =~ ^[0-9]+$ ]] && [ "$SCHEME_COUNT" -gt 5 ]; then
            echo "   ⚠️  High scheme count - consider testing specific schemes"
            echo "   🚀 Use: smith-smart-builder.sh [scheme-name]"
        fi
    else
        if [[ "$TARGET_COUNT" =~ ^[0-9]+$ ]] && [ "$TARGET_COUNT" -gt 20 ]; then
            echo "   ⚠️  Large package - test core targets first"
            echo "   🚀 Use: smith-smart-builder.sh to auto-select optimal target"
        else
            echo "   ✅ Manageable package size"
        fi
    fi

    echo ""
    echo "📋 Next Steps:"
    echo "   • Run smith-smart-builder.sh for automated testing"
    echo "   • Use smith-build-hang-analyzer.sh if issues persist"
    echo "   • Consider dependency optimization for complex projects"

    echo ""
    echo "✅ Complexity Analysis Complete"
    exit 0
fi

# Phase 1: Quick validation (efficiency: fail fast)
echo "🔍 Phase 1: Quick Validation"
echo "============================="

if [ "$PROJECT_TYPE" = "SPM" ]; then
    if command -v spmsift &> /dev/null; then
        echo "1️⃣ Target-specific analysis (spmsift)..."
        # Analyze just the target we'll build first
        if [ -n "$TARGET" ]; then
            ANALYSIS=$(swift package dump-package 2>&1 | spmsift --target "$TARGET")
            echo "$ANALYSIS" | jq -r '.targets // empty | length // 0' | xargs -I {} echo "   Target '$TARGET': Available for build"
        else
            ANALYSIS=$(swift package dump-package 2>&1 | spmsift --compact)
            echo "$ANALYSIS" | jq -r '.package // empty' | xargs -I {} echo "   Package: {}"
        fi

        # Check for obvious issues
        if echo "$ANALYSIS" | jq -e '.issues // empty | length' | grep -q "0"; then
            echo "✅ Package structure valid"
        else
            echo "⚠️  Package issues detected"
            echo "$ANALYSIS" | jq '.issues'
        fi
    else
        echo "1️⃣ SPM quick check..."
        if swift package dump-package >/dev/null 2>&1; then
            echo "✅ Package structure valid"
        else
            echo "❌ Package structure invalid"
            exit 1
        fi
    fi
else
    echo "1️⃣ Project validation..."
    if [ -n "$WORKSPACE" ]; then
        xcodebuild -list -workspace "$WORKSPACE" >/dev/null 2>&1 || { echo "❌ Invalid workspace"; exit 1; }
    else
        xcodebuild -list -project "$PROJECT" >/dev/null 2>&1 || { echo "❌ Invalid project"; exit 1; }
    fi
    echo "✅ Project structure valid"
fi

echo ""

# Phase 2: Identify target to test (efficiency: test minimal)
echo "🎯 Phase 2: Target Selection"
echo "============================"

TARGET=""
SCHEME=""

if [ "$PROJECT_TYPE" = "SPM" ]; then
    # For SPM, try building just one target first
    TARGET=$(swift package dump-package | jq -r '.targets[0].name // empty' 2>/dev/null)
    echo "🎪 Target: $TARGET (minimal test)"
elif [ -n "$WORKSPACE" ]; then
    # For workspace, find the main scheme
    SCHEME=$(xcodebuild -list -workspace "$WORKSPACE" | grep -A5 "Schemes:" | grep -v "Schemes:" | head -1 | tr -d ' ')
    echo "🎯 Scheme: $SCHEME"
else
    # For project, find main scheme
    SCHEME=$(xcodebuild -list -project "$PROJECT" | grep -A5 "Schemes:" | grep -v "Schemes:" | head -1 | tr -d ' ')
    echo "🎯 Scheme: $SCHEME"
fi

echo ""

# Phase 3: Progressive build with sift tools (efficiency: context-aware)
echo "🔧 Phase 3: Smart Build"
echo "======================="

BUILD_COMMAND=""
ANALYSIS_TOOL=""

if [ "$PROJECT_TYPE" = "SPM" ]; then
    if command -v sbsift &> /dev/null; then
        echo "🏗️ Building target '$TARGET' with enhanced sbsift..."
        # Use minimal output for maximum efficiency
        BUILD_COMMAND="swift build -c debug --target $TARGET 2>&1 | sbsift --format json --minimal"
        ANALYSIS_TOOL="sbsift-enhanced"
    else
        echo "🏗️ Building target '$TARGET' (fallback)..."
        BUILD_COMMAND="swift build -c debug --target $TARGET"
        ANALYSIS_TOOL="none"
    fi
else
    if command -v xcsift &> /dev/null; then
        if [ -n "$WORKSPACE" ]; then
            echo "🏗️ Building scheme '$SCHEME' with xcsift..."
            BUILD_COMMAND="xcodebuild build -workspace \"$WORKSPACE\" -scheme \"$SCHEME\" -destination 'platform=macOS' 2>&1 | xcsift"
        else
            echo "🏗️ Building scheme '$SCHEME' with xcsift..."
            BUILD_COMMAND="xcodebuild build -project \"$PROJECT\" -scheme \"$SCHEME\" -destination 'platform=macOS' 2>&1 | xcsift"
        fi
        ANALYSIS_TOOL="xcsift"
    else
        echo "🏗️ Building scheme '$SCHEME' (fallback)..."
        if [ -n "$WORKSPACE" ]; then
            BUILD_COMMAND="xcodebuild build -workspace \"$WORKSPACE\" -scheme \"$SCHEME\" -destination 'platform=macOS'"
        else
            BUILD_COMMAND="xcodebuild build -project \"$PROJECT\" -scheme \"$SCHEME\" -destination 'platform=macOS'"
        fi
        ANALYSIS_TOOL="none"
    fi
fi

# Execute build with timeout monitoring
echo "⏱️ Timeout: ${TIMEOUT}s"
echo ""

BUILD_LOG="/tmp/smith-smart-build-$$.log"

# Function to monitor build progress
monitor_build() {
    local pid=$1
    local start_time=$(date +%s)

    while kill -0 $pid 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -gt $TIMEOUT ]; then
            echo "⏰ TIMEOUT: Build taking longer than ${TIMEOUT}s"
            echo "💡 This suggests a hang - run smith-build-hang-analyzer.sh"
            kill $pid 2>/dev/null
            return 124
        fi

        # Progress indicator (minimal output for efficiency)
        if [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            echo "⏳ Building... (${elapsed}s elapsed)"
        fi

        sleep 5
    done

    wait $pid
    return $?
}

# Start build in background
eval "$BUILD_COMMAND" > "$BUILD_LOG" 2>&1 &
BUILD_PID=$!

# Monitor progress
monitor_build $BUILD_PID
EXIT_CODE=$?

# Analyze results (context-efficient output)
echo ""
echo "📊 BUILD RESULT"
echo "==============="

if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ BUILD HUNG (timeout)"
    echo ""
    echo "🔧 RECOMMENDED ACTION:"
    echo "   smith-build-hang-analyzer.sh [problematic-file]"
    echo ""
    # Try to identify hanging file from log
    if [ -f "$BUILD_LOG" ]; then
        HANGING_FILE=$(grep "Compiling.*\.swift" "$BUILD_LOG" | tail -1 | sed 's/.*Compiling //' | sed 's/ (in target.*//')
        if [ -n "$HANGING_FILE" ]; then
            echo "🎯 Likely hanging file: $HANGING_FILE"
            echo "   smith-build-hang-analyzer.sh \"$HANGING_FILE\""
        fi
    fi
elif [ $EXIT_CODE -eq 0 ]; then
    if [ "$ANALYSIS_TOOL" = "sbsift-enhanced" ]; then
        # Parse enhanced sbsift minimal output
        if [ -f "$BUILD_LOG" ] && [ -s "$BUILD_LOG" ]; then
            # Expected format: {"c":"b","s":1,"e":0,"w":0,"t":2.3}
            BUILD_RESULT=$(cat "$BUILD_LOG" 2>/dev/null)
            if echo "$BUILD_RESULT" | jq -e '.s == 1' >/dev/null 2>&1; then
                BUILD_TIME=$(echo "$BUILD_RESULT" | jq -r '.t // "unknown"')
                BUILD_ERRORS=$(echo "$BUILD_RESULT" | jq -r '.e // 0')
                if [ "$BUILD_ERRORS" -eq 0 ]; then
                    echo "✅ BUILD SUCCEEDED (${BUILD_TIME}s)"
                else
                    echo "❌ BUILD FAILED ($BUILD_ERRORS errors)"
                fi
            else
                echo "⚠️  BUILD STATUS UNCLEAR"
                echo "📊 Raw result: $BUILD_RESULT"
            fi
        else
            echo "✅ BUILD SUCCEEDED"
        fi
    elif [ "$ANALYSIS_TOOL" = "sbsift" ] || [ "$ANALYSIS_TOOL" = "xcsift" ]; then
        # Parse regular sift tool output with enhanced context (NEW: Better diagnostics)
        if [ -f "$BUILD_LOG" ] && [ -s "$BUILD_LOG" ]; then
            BUILD_STATUS=$(cat "$BUILD_LOG" | jq -r '.status // "unknown"' 2>/dev/null)
            BUILD_ERRORS=$(cat "$BUILD_LOG" | jq -r '.summary.errors // 0' 2>/dev/null)
            BUILD_WARNINGS=$(cat "$BUILD_LOG" | jq -r '.summary.warnings // 0' 2>/dev/null)

            echo "📊 Enhanced Build Analysis:"
            echo "   Status: $BUILD_STATUS"
            echo "   Errors: $BUILD_ERRORS"
            echo "   Warnings: $BUILD_WARNINGS"

            if [ "$BUILD_STATUS" = "success" ] || [ "$BUILD_STATUS" = "passed" ]; then
                echo "✅ BUILD SUCCEEDED (xcsift filtered)"

                # NEW: Check for potential false positives in complex projects
                if [ "$PROJECT_TYPE" != "SPM" ]; then
                    echo ""
                    echo "🔍 Complex Project Note:"
                    echo "   ⚠️  xcsift reports success but this may be partial"
                    echo "   📱 Workspace projects can have dependency complexity"
                    echo "   💡 Verify by testing the full app functionality"

                    # NEW: Check if this was a scheme-specific build
                    if [ -n "$SCHEME" ]; then
                        echo "   🎯 Built scheme: $SCHEME"
                        echo "   🔍 For full project verification, test all schemes"
                    fi

                    echo "   🚀 Recommended: Run app to verify full build success"
                fi

            else
                echo "❌ BUILD FAILED"
                echo "🔍 Errors:"
                cat "$BUILD_LOG" | jq -r '.errors[]? // empty' 2>/dev/null | head -3
            fi
        else
            echo "✅ BUILD SUCCEEDED (no sift output)"
            echo "🔍 Note: No sift tool analysis available - build result may be incomplete"
        fi
    else
        echo "✅ BUILD SUCCEEDED"
    fi

    # If minimal target succeeded, suggest full build
    if [ "$PROJECT_TYPE" = "SPM" ] && [ -n "$TARGET" ]; then
        echo ""
        echo "🚀 Next step: Full package build"
        echo "   swift build"
    elif [ "$PROJECT_TYPE" != "SPM" ]; then
        echo ""
        echo "🚀 Next step: Test app launch"
        echo "   The build succeeded - try running the app"
    fi
else
    echo "❌ BUILD FAILED (exit code: $EXIT_CODE)"
    if [ -f "$BUILD_LOG" ] && [ -s "$BUILD_LOG" ]; then
        echo "🔍 Last 10 lines of build log:"
        tail -10 "$BUILD_LOG"
    fi
fi

# Cleanup
rm -f "$BUILD_LOG"

echo ""
echo "✅ Smith Smart Builder Complete"