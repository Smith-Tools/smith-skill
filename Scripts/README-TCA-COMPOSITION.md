# Smith TCA Composition Validators

Comprehensive bash scripts for detecting architectural anti-patterns in TCA reducers before they become technical debt.

## Overview

These scripts enforce the patterns documented in `AGENTS-TCA-PATTERNS.md` by **automatically detecting violations** and providing **actionable recommendations**.

- **validate-tca-composition.sh** - Detects composition anti-patterns (Rules 1.1-1.5)
- **analyze-tca-dependency-graph.sh** - Maps state dependencies and coupling complexity
- **check-tca-testability.sh** - Scores testability (0-100) based on blockers
- **recommend-tca-extractions.sh** - Suggests specific features to extract with effort estimates

## Quick Start

### Run All Validators (Recommended)
```bash
cd smith-skill/Scripts

# Quick composition check
./validate-tca-composition.sh /path/to/Sources

# Full analysis suite
./validate-tca-composition.sh /path/to/Sources
./analyze-tca-dependency-graph.sh /path/to/Sources
./check-tca-testability.sh /path/to/Sources --threshold 75
./recommend-tca-extractions.sh /path/to/Sources
```

### Run Individual Scripts

```bash
# Show all violations (human-readable)
./validate-tca-composition.sh /path/to/Sources

# Export as JSON (for CI/CD)
./validate-tca-composition.sh /path/to/Sources --json > report.json

# Strict mode (fail if HIGH violations found)
./validate-tca-composition.sh /path/to/Sources --strict
```

## Script Details

### 1. validate-tca-composition.sh

Detects composition anti-patterns that violate TCA principles.

#### Rules

**Rule 1.1: Monolithic Features**
- Trigger: State struct > 15 properties OR Action enum > 40 cases
- Alert: 🔴 HIGH
- Fix: Extract features to separate reducers

**Rule 1.2: Closure Dependency Injection**
- Trigger: `var x: (...) -> Effect`
- Alert: 🔴 HIGH (CRITICAL)
- Fix: Replace with `@Dependency(\.client)`

**Rule 1.3: Code Duplication**
- Trigger: Same action case handled in multiple Reduce blocks
- Alert: 🟠 MEDIUM
- Fix: Consolidate into single handler

**Rule 1.4: Unclear Reducer Organization**
- Trigger: 5+ helper methods with vague names (`*Features()`, `*Reducers()`)
- Alert: 🟡 LOW
- Fix: Rename to reflect actual responsibility

**Rule 1.5: Tightly Coupled State**
- Trigger: 5+ child features in State
- Alert: 🟠 MEDIUM
- Fix: Reduce composition complexity

#### Usage

```bash
# Basic analysis
./validate-tca-composition.sh Sources/

# JSON output for CI/CD
./validate-tca-composition.sh Sources/ --json

# Fail build if violations found (strict mode)
./validate-tca-composition.sh Sources/ --strict
```

#### Example Output

```
🔍 TCA Composition Validation
=============================
Path: Sources/

🔴 HIGH: ReadingLibraryFeature.swift
   Rule 1.1: Monolithic Feature
   State properties: 20 (threshold: 15)
   Action cases: 42 (threshold: 40)

🔴 CRITICAL: LibraryLifecycleReducer.swift
   Rule 1.2: Closure Dependency Injection
   Found 3 closure(s) - blocks unit testing
     Line 74: var refreshArticles: (State, Bool, Date) -> Effect
     Line 81: var observeDatabaseNotifications: () -> Effect
     Line 88: var makeAlert: (String, String) -> AlertState

=====================================
📊 COMPOSITION VALIDATION SUMMARY
=====================================

Files analyzed: 24
Total violations: 6

🔴 HIGH (blocking): 5
🟠 MEDIUM (important): 1
🟡 LOW (guidance): 0

❌ Composition violations detected

💡 To fix violations:
   HIGH (1.1-1.2): These block testing and maintainability - fix immediately
   MEDIUM (1.3, 1.5): Important for clarity and reducing bugs
   LOW (1.4): Improve clarity for team understanding

📚 Reference: See AGENTS-TCA-PATTERNS.md for detailed guidance
```

### 2. analyze-tca-dependency-graph.sh

Maps state property dependencies and identifies coupling complexity.

#### What It Does

- Counts state properties per reducer
- Analyzes Reduce blocks and update methods
- Calculates complexity score
- Identifies high-coupling patterns
- Suggests decomposition when needed

#### Complexity Score

| Score | Status | Action |
|-------|--------|--------|
| < 8 | ✅ Healthy | Continue current approach |
| 8-15 | ⚠️ Monitor | Watch for increasing complexity |
| > 15 | 🔴 Refactor | Consider decomposing reducer |

#### Usage

```bash
# Basic dependency analysis
./analyze-tca-dependency-graph.sh Sources/

# Detailed property breakdown
./analyze-tca-dependency-graph.sh Sources/ --detailed

# JSON output
./analyze-tca-dependency-graph.sh Sources/ --json
```

#### Example Output

```
📊 TCA Dependency Graph Analysis
=================================
Path: Sources/

📄 ReadingLibraryFeature.swift
   State properties: 20
   Reduce blocks: 8
   Update methods: 12
   Complexity score: 28
   ⚠️  HIGH COMPLEXITY: Consider decomposing

📄 ArticleListFeature.swift
   State properties: 6
   Reduce blocks: 2
   Update methods: 3
   Complexity score: 7
   ✅ ACCEPTABLE COMPLEXITY

════════════════════════════════════════════════════════════
📈 DEPENDENCY GRAPH SUMMARY
════════════════════════════════════════════════════════════

Reducers analyzed: 12
High-complexity reducers: 3

⚠️  3 reducer(s) have high complexity
   Consider:
   • Breaking into smaller, focused reducers
   • Reducing the number of child features in state
   • Simplifying state update logic
```

### 3. check-tca-testability.sh

Scores testability (0-100) based on patterns that block testing.

#### Scoring Model

Starts at 100, subtracts points for:
- **Closure injection** -10 points each (CRITICAL)
- **Complex effect handlers** -5 points each
- **Duplicate action handlers** -2-5 points each
- **@Dependency usage** +2 points each (positive)

#### Default Threshold

Default is **75+** (≈ easily testable). Adjust with `--threshold`:
```bash
./check-tca-testability.sh Sources/ --threshold 80
```

#### Usage

```bash
# Basic testability check
./check-tca-testability.sh Sources/

# With custom threshold
./check-tca-testability.sh Sources/ --threshold 85

# JSON for CI/CD
./check-tca-testability.sh Sources/ --json
```

#### Example Output

```
📋 TCA Testability Assessment
=============================
Path: Sources/
Target Score: 75+

════════════════════════════════════════════════════════════
📊 TESTABILITY SCORE
════════════════════════════════════════════════════════════

Score: 65/100  (🟠 NEEDS WORK)

Progress: [██████░░░░░░░░░░] 65%

📈 Statistics:
   Reducers analyzed: 12
   Closure injections found: 3
   Proper @Dependency uses: 8

🔴 BLOCKERS (prevent isolated testing):
   • LibraryLifecycleReducer.swift: 3 closure injection(s)
   • ArticleSearchFeature.swift: 2 closure injection(s)

🟠 WARNINGS (increase test complexity):
   • ReadingLibraryFeature.swift: 8 effect handlers

💡 Recommendations:

   Priority: Fix blockers to reach 75+
   • Replace closure injection with @Dependency (+10/closure)
   • Consolidate duplicate logic (+2-5 points)

   Estimated effort: 4-8 hours
   Expected improvement: +10 points

⚠️  Score (65) below threshold (75)
```

### 4. recommend-tca-extractions.sh

Suggests specific features to extract based on composition analysis.

#### Priority Levels

**Priority 1 (Do First)** - 2 hours each
- Fix closure injection blockers
- Impact: Unblocks unit testing immediately

**Priority 2 (Next Sprint)** - 4-6 hours each
- Extract monolithic features
- Impact: +1000 testable lines per extraction

**Priority 3 (Future)** - 4-8 hours each
- Clarify reducer organization
- Impact: Improved maintainability and onboarding

#### Usage

```bash
# Show all recommendations
./recommend-tca-extractions.sh Sources/

# Just effort breakdown (no P3 details)
./recommend-tca-extractions.sh Sources/ --effort-only

# JSON for CI/CD pipeline
./recommend-tca-extractions.sh Sources/ --json
```

#### Example Output

```
════════════════════════════════════════════════════════════
📋 EXTRACTION RECOMMENDATIONS
════════════════════════════════════════════════════════════

Total recommendations: 6

🔴 PRIORITY 1 (Do First - Unblocks Testing)
─────────────────────────────────────────

   EXTRACT: LibraryLifecycleReducer - Replace 3 closure injection(s) with @Dependency
   ⏱️  Effort: 2 hours
   💡 Impact: Unblocks unit testing

   EXTRACT: ArticleSearchFeature - Replace 2 closure injection(s) with @Dependency
   ⏱️  Effort: 2 hours
   💡 Impact: Unblocks unit testing

🟠 PRIORITY 2 (Next Sprint - Maintainability)
──────────────────────────────────────────

   EXTRACT: ReadingLibraryFeature - State has 20 properties, Actions: 42
   ⏱️  Effort: 8-12 hours
   💡 Impact: +1000 testable lines

   EXTRACT: ArticleListFeature - State has 18 properties, Actions: 35
   ⏱️  Effort: 4-6 hours
   💡 Impact: +800 testable lines

════════════════════════════════════════════════════════════

📊 Effort Summary:
   P1: ~4 hours (closure replacements)
   P2: ~20 hours (feature extractions)

   Total: ~24 hours (phased approach recommended)

🚀 Suggested Sprint Plan:
   • Week 1: Priority 1 items (~4h) - unblock testing
   • Week 2-3: Priority 2 items (~20h) - maintain code
```

## Integration with smith-smart-builder.sh

These scripts should be run as part of Phase 0 (post-compilation validation):

```bash
# In smith-smart-builder.sh, after successful build:

if [ $EXIT_CODE -eq 0 ]; then
    echo "📊 TCA Composition Analysis"
    ./validate-tca-composition.sh "$TARGET_PATH" --json > composition-report.json
    ./check-tca-testability.sh "$TARGET_PATH" --json > testability-report.json
fi
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Validate TCA Composition
  run: |
    ./smith-skill/Scripts/validate-tca-composition.sh Sources/ --json > composition.json
    ./smith-skill/Scripts/check-tca-testability.sh Sources/ --json > testability.json

- name: Check Results
  run: |
    VIOLATIONS=$(jq '.violations' composition.json)
    if [ "$VIOLATIONS" -gt 0 ]; then
      echo "❌ Composition violations found"
      jq '.' composition.json
      exit 1
    fi
```

### Pull Request Comments

Generate reports on every PR:

```bash
#!/bin/bash
# In your CI script

REPORT=$(./smith-skill/Scripts/recommend-tca-extractions.sh Sources/)

gh pr comment -R $REPO -b "
## 🔍 TCA Analysis

$REPORT
"
```

## Configuration

### Severity Thresholds

Adjust in individual scripts:

```bash
# Fail if testability below 80
./check-tca-testability.sh Sources/ --threshold 80

# Strict mode - fail on any HIGH violations
./validate-tca-composition.sh Sources/ --strict
```

### Custom Paths

All scripts support custom search paths:

```bash
# Analyze specific module
./validate-tca-composition.sh Sources/ScrollModules/ReadingLibrary/

# Analyze entire project
./validate-tca-composition.sh . --strict
```

## Understanding the Output

### Alert Levels

- **🔴 HIGH/CRITICAL** - Blocks testing or violates core TCA principles
- **🟠 MEDIUM** - Important for maintainability
- **🟡 LOW** - Guidance for code clarity

### What Each Script Shows

| Script | Shows | Use For |
|--------|-------|---------|
| validate-tca-composition | Rule violations | PR reviews, code gates |
| analyze-tca-dependency-graph | Coupling complexity | Architecture review |
| check-tca-testability | Test blockers | Sprint planning |
| recommend-tca-extractions | Specific actions | Backlog grooming |

## Troubleshooting

### Script not found
```bash
chmod +x smith-skill/Scripts/*.sh
./smith-skill/Scripts/validate-tca-composition.sh Sources/
```

### No results
```bash
# Verify reducer files are named correctly
find Sources/ -name "*Feature.swift" -o -name "*Reducer.swift"

# Check paths are correct
./validate-tca-composition.sh ./Sources/
```

### JSON parsing fails
```bash
# Ensure jq is installed
brew install jq

# Or use without --json flag for human-readable output
./validate-tca-composition.sh Sources/
```

## References

- **AGENTS-TCA-PATTERNS.md** - Pattern documentation these scripts enforce
- **AGENTS-AGNOSTIC.md** - Universal Swift principles
- **TCA GitHub** - https://github.com/pointfreeco/swift-composable-architecture

## Next Steps

After running validators:

1. **Fix HIGH violations first** (1.1-1.2, blockers)
2. **Plan MEDIUM extractions** (1.3, 1.5)
3. **Schedule LOW improvements** (1.4)
4. **Re-run scripts** to verify improvements
5. **Integrate into CI/CD** for continuous monitoring

---

**Last Updated:** November 17, 2025
**For:** Smith Framework TCA Composition Validation
