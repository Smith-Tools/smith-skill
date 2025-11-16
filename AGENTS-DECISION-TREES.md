# Decision Trees for Common Questions

This document provides **decision trees** to answer the most common architectural questions agents and developers face.

---

## Pre-Tree: Should I Extract This Inline Reducer?

**Use this FIRST if you have a @Reducer defined inside another @Reducer.**

**Problem:** Inline nested reducers grow quickly. Without extraction guidance, they become 800+ line files mixing multiple concerns. See DISCOVERY-12 for real-world impact.

```
Do you have a @Reducer defined INSIDE another @Reducer?
├─ NO → Skip to Tree 1
│
└─ YES → Answer these questions:

    1. How many lines is the inline reducer?
    ├─ < 100 lines → Keep inline (for now)
    ├─ 100-200 lines → Check other criteria below
    └─ > 200 lines → EXTRACT IMMEDIATELY [CRITICAL]
       Why: 200+ lines is the hard threshold
       Action: Move to separate file, then to module

    2. How many distinct action cases? (count .case entries)
    ├─ < 3 cases → Keep inline
    └─ ≥ 3 cases → Check next criterion

    3. How many state properties?
    ├─ < 4 properties → Keep inline
    └─ ≥ 4 properties → Check next criterion

    4. Does it have its own Delegate actions?
    ├─ NO → Keep inline
    └─ YES → EXTRACT [STANDARD]
       Why: Delegates need clear parent-child boundary

    5. Is it used by 2+ parent reducers?
    ├─ NO → Keep inline if < 200 lines
    └─ YES → EXTRACT [STANDARD]
       Why: Reusable component shouldn't be nested

┌──────────────────────────────────────────┐
│ EXTRACTION THRESHOLD SUMMARY              │
├──────────────────────────────────────────┤
│ < 100 lines → Keep inline                │
│ 100-200 lines → Extract if 3+ criteria ✓ │
│ > 200 lines → Extract immediately [!]   │
└──────────────────────────────────────────┘

When you EXTRACT:
1. Create separate file: FeatureName.swift
2. Move @Reducer to new file
3. Update parent to import and compose
4. Later: Extract to Swift Package module (Tree 1)

Example Extraction:
// Before: GameEngine.swift (1200 lines with 850-line inline reducer)
@Reducer
struct GameEngine {
  @Reducer
  struct HintSystem { /* 850 lines */ }
}

// After: HintsFeature.swift (400 lines, separate)
@Reducer
struct HintsFeature { /* extracted logic */ }

// GameEngine.swift (800 lines, just game logic)
@Reducer
struct GameEngine {
  .ifLet(\.hints, action: \.hints) {
    HintsFeature()  // Clean composition
  }
}

See DISCOVERY-12 for complete extraction pattern.
```

**When in Doubt:** Extract. It's easier to keep simple things together later than to untangle complex things now.

---

## Tree 1: When Should I Create a Swift Package Module?

**Use this tree when deciding whether to extract a feature into a separate Swift Package module or keep it in the monolithic app target.**

```
Feature exists or is planned?
├─ YES → Continue
└─ NO → Not applicable yet

Will this feature be reused across 2+ parent features
or different platform combinations?
├─ YES → Extract to module
│  Why: Reusability is the strongest reason for modularization
│  Example: TaggingKit is used by ArticleReader, ImportExport, and ArticleSearch
│
└─ NO → Continue to next question

Does the reducer action enum have 20+ cases?
├─ YES → Extract to module (likely doing too much)
│  Why: Large action enums indicate feature complexity
│  Suggestion: Break into sub-features with Scope composition
│
└─ NO → Continue to next question

Does the feature have 3+ sub-reducers that need composition?
├─ YES → Extract to module
│  Why: Composition across multiple reducers is clearer in separate module
│  Example: ArticleReader has ReaderPreferences, ReaderCache, ReaderHistory
│
└─ NO → Continue to next question

Is there significant platform-specific code?
├─ YES (macOS-specific OR visionOS-specific) → Extract to module
│  Why: Platform-specific UI/logic is clearer in separate module
│  Structure: ModuleCore (shared) + ModuleUI + ModuleMac + ModuleVision
│
└─ NO → Continue to next question

Is the feature logic 1000+ lines?
├─ YES → Extract to module
│  Why: Monolithic files are harder to maintain
│  Note: This is the last-resort metric; earlier factors are better
│
└─ NO → Keep in monolithic target

Why? At this point:
- Feature is not reusable yet
- Action enum is manageable (< 20 cases)
- No significant sub-feature composition
- Platform-specific code is minimal
- Logic is still manageable in size

You can always extract later when requirements change.
```

### Quick Reference

**EXTRACT to module if ANY of these are true:**
1. ✅ Feature will be reused across 2+ parents OR platforms
2. ✅ Action enum has 20+ cases
3. ✅ Feature has 3+ sub-reducers
4. ✅ Significant platform-specific code exists
5. ✅ Feature logic is 1000+ lines

**KEEP in monolithic target if:**
- ❌ Feature is used in only one place (for now)
- ❌ Action enum is < 20 cases
- ❌ Sub-feature composition is minimal
- ❌ No platform-specific code
- ❌ Feature logic is < 1000 lines
- ✅ You can extract it later without breaking anything

---

## Tree 2: Should I Use @DependencyClient or Singleton?

**Use this tree when deciding whether to inject a service via @DependencyClient or use a direct singleton/static method.**

```
Is this service/capability used in a feature reducer (TCA)?
├─ YES → Continue
└─ NO → Likely singleton; check question 2 below

Does the service need different implementations for testing?
├─ YES → Use @DependencyClient
│  Why: Tests need to override behavior
│  Example: @DependencyClient APIClient (testValue = mock)
│
└─ NO → Continue to next question

Is the service used in multiple features/tests?
├─ YES → Use @DependencyClient
│  Why: Makes dependencies explicit and testable
│  Example: DatabaseService used across 5 features
│
└─ NO → Evaluate case-by-case

────────────────────────────────────────

NOT USED IN REDUCER? (Jump here if answer was NO above)

Is this an Apple framework integration?
├─ YES (AudioSession, URLSession, UserDefaults, etc.)
│  ├─ YES, lifecycle managed → Singleton is fine
│  │  Example: AudioSession.sharedInstance
│  │
│  └─ YES, but needs testing → @DependencyClient wrapper
│     Example: Wrap URLSession behind @DependencyClient for mocking
│
└─ NO → Continue to next question

Does this service have mutable state or lifecycle?
├─ YES → Use @DependencyClient
│  Why: Allows test isolation and state reset
│  Example: AudioService (volume, playback state)
│
└─ NO → Singleton is fine
   Why: Stateless utilities don't need injection
   Example: Logger, JSON decoder, UUID generator

────────────────────────────────────────

DECISION SUMMARY

Use @DependencyClient when:
✅ Service is used in feature reducers
✅ Service needs test overrides
✅ Service is used across multiple features
✅ Service has mutable state or lifecycle

Use singleton when:
✅ Service is a stateless utility
✅ Service is an Apple framework (direct access)
✅ Service has no test-specific implementations
✅ Service is truly static (UUID generator, Logger)

────────────────────────────────────────

CONTEXT: Why This Distinction?

@DependencyClient benefits:
- Explicit: Dependencies are visible in code
- Testable: Easy to mock for tests
- Flexible: Different implementations per context
- Swift 6 friendly: Works with strict concurrency

Singleton benefits:
- Simple: Less boilerplate
- Performance: Direct access, no indirection
- Appropriate: For stateless utilities

Cost of wrong choice:
- Over-injecting: Unnecessary boilerplate (use singleton instead)
- Under-injecting: Testing nightmares, hidden dependencies
  (use @DependencyClient instead)
```

---

## Tree 3: Should I Refactor This Into a Module?

**Use this tree when evaluating whether an existing piece of code in the monolithic target should be extracted into a separate Swift Package module.**

```
Is this feature causing problems RIGHT NOW?
├─ YES → Extract it
│  Why: Pain is a signal to modularize
│  Examples:
│   - Slow compilation? Extract module to parallelize builds.
│   - Hard to test? Extract module to focus testing.
│   - Tangled dependencies? Extract module to clarify boundaries.
│
└─ NO → Continue to next question

Is this feature preventing other work?
├─ YES → Extract it
│  Why: Unblocking other features is worth the effort
│  Example: Can't work on ArticleSearch until ArticleReader
│           is stable (extract ArticleReader to module)
│
└─ NO → Continue to next question

Are you planning to reuse this in a new project?
├─ YES → Extract it now
│  Why: Easier to extract proactively than retrofit later
│  Example: Planning visionOS reading experience; ArticleReader
│           module can be reused across platforms
│
└─ NO → Continue to next question

Is this feature mature and stable?
├─ YES → Extract it
│  Why: Stable features are safe to modularize
│       (Early-stage features change API; harder to modularize)
│
└─ NO → Wait
   Why: APIs will change; modularization can wait
   Plan: Revisit when feature stabilizes

────────────────────────────────────────

REFACTORING DECISION

Extract to module if ANY of these:
✅ Feature is causing problems (slow builds, hard to test)
✅ Feature is blocking other work
✅ Feature will be reused in new projects
✅ Feature is stable with mature API

Keep monolithic if:
❌ Feature is early-stage (API changing)
❌ Feature is causing no pain
❌ Feature is not blocking work
❌ Feature is not reusable

────────────────────────────────────────

EXTRACTION COST vs BENEFIT

Low extraction cost, high benefit:
- Small, well-defined features
- Stable APIs
- Test-driven development (tests exist)
→ Extract now

High extraction cost, low benefit:
- Large, tangled features
- Changing APIs
- No tests
→ Keep monolithic; improve first, extract later

Medium extraction cost, medium benefit:
- Moderate size, some stability
- Occasional reuse
- Partial test coverage
→ Extract if it unblocks work; otherwise keep for now
```

---

## Tree 4: Where Should This Logic Live?

**Use this tree when deciding whether logic belongs in Core module, UI module, or Platform-specific module.**

```
Does this logic reference SwiftUI views or SwiftUI-specific APIs?
├─ YES → UI module
│  Why: Requires SwiftUI framework
│  Example: View state, SwiftUI modifiers, @State
│
└─ NO → Continue to next question

Is this domain/business logic independent of UI?
├─ YES → Core module
│  Why: Domain logic is platform-agnostic
│  Examples: Article CRUD, Tag management, Analytics events
│
└─ NO → Continue to next question

Does this logic use platform-specific frameworks?
├─ YES (macOS-specific, visionOS-specific) → Platform module
│  Why: Platform frameworks vary (NSViewRepresentable vs RealityView)
│  Examples:
│   - macOS: NSViewRepresentable wrapper for WKWebView
│   - visionOS: RealityView rendering
│
└─ NO → Continue to next question

Does this reducer manage feature state?
├─ YES → Core module (reducer + state)
│        UI module (views that use @Bindable)
│  Why: Reducers are domain logic; views are UI presentation
│
└─ NO → Check if it's a helper/utility

Is this a helper function or utility?
├─ YES, used across multiple features → Core module
│  Example: Article formatting, tag validation
│
└─ YES, used only in one feature → Same module as feature
   Example: Internal helper for ArticleReader

────────────────────────────────────────

MODULE STRUCTURE DECISION

Structure your feature like this:

FeatureCore/
├── FeatureFeature.swift (reducer + @ObservableState)
├── FeatureService.swift (@DependencyClient for domain logic)
└── FeatureModels.swift (data structures)

FeatureUI/
├── FeatureView.swift (SwiftUI views with @Bindable)
└── FeatureComponents.swift (reusable UI components)

FeatureMac/ (only if macOS-specific UI)
├── FeatureViewMac.swift (macOS-specific views)
└── FeatureMacComponents.swift

FeatureVision/ (only if visionOS-specific UI)
├── FeatureViewVision.swift (visionOS-specific views)
└── FeatureRealityView.swift

────────────────────────────────────────

DECISION TABLE

| Logic Type | Module | Why |
|-----------|--------|-----|
| Reducer state/actions | Core | Domain logic, platform-agnostic |
| Feature services | Core | Domain logic, easy to mock/test |
| SwiftUI views | UI | Framework-dependent |
| Platform-specific UI | Platform | Can't share across platforms |
| Helpers (single feature) | Same module | Keep together |
| Helpers (multi-feature) | Core | Shared, reusable |
| Models/types | Core | Domain logic, no UI dependency |
| Design tokens | Core | Shared, reusable |
| Tests | Tests/ | Always separate test target |
```

---

---

## Tree 5: Feature Already Exists Under Different Name?

**Use this BEFORE implementing a "new" feature. Duplication creates maintenance burden and bugs.**

**Problem:** WatcherAssist + HintSystem = same thing, different names. Caused -850 lines of duplicate code and infinite loops. See DISCOVERY-12.

```
New feature request arrives
├─ YES, it's genuinely new → Proceed to Tree 1
│
└─ MAYBE, similar to something else?

    Search codebase for related functionality:
    ├─ rg "FeatureKeyword|AlternativeName" --type swift
    ├─ rg "SimilarState|SimilarAction" --type swift
    └─ rg "ButtonID.*feature" --type swift

    Check for DUPLICATE STATE TYPES
    ├─ Do similar state types exist?
    │  ├─ YES → Compare properties
    │  │  ├─ 80%+ overlap? → SAME FEATURE, different name [CONSOLIDATE]
    │  │  └─ < 50% overlap? → Separate features, proceed
    │  └─ NO → New feature, proceed
    │
    └─ Check for DUPLICATE ACTION ENUMS
       ├─ Do similar action enums exist?
       │  ├─ Same case names? → SAME FEATURE [CONSOLIDATE]
       │  ├─ Same effects? → SAME FEATURE [CONSOLIDATE]
       │  └─ Completely different? → Separate features, proceed
       │
       └─ Check for DUPLICATE BUTTON IDs / ENTITY KEYS
          ├─ Same UI element? → SAME FEATURE [CONSOLIDATE]
          ├─ Active simultaneously? → Separate features
          └─ Mutually exclusive? → SAME FEATURE [CONSOLIDATE]

RED FLAGS - Duplication Detected:
  ⚠️  Two button IDs for same visual UI element
  ⚠️  Two state types with identical/overlapping properties
  ⚠️  Two action enums with identical case names
  ⚠️  Two reducers handling same events differently
  ⚠️  Comments like "// TODO: Unify with X feature"
  ⚠️  Parallel code paths doing the same job

CONSOLIDATION PROCESS:
1. Pick ONE canonical name (most descriptive)
   ✓ Example: HintsFeature (not WatcherAssist, not HintSystem)

2. Rename all occurrences systematically
   rg "WatcherAssist|watcherAssist" --type swift
   # Use IDE refactor or sed to rename

3. Delete duplicate implementations
   - Remove redundant state types
   - Remove redundant action enums
   - Remove redundant reducers

4. Update button IDs / entity keys
   // Before:
   Button3DID.watcherAssist
   Button3DID.hintSystem

   // After:
   Button3DID.hints  // ✅ ONE canonical name

5. Merge unique functionality (if any)
   - If both had features the other didn't, merge into canonical

REAL-WORLD EXAMPLE (GreenSpurt):
Audit revealed:
  • WatcherAssistPopoverState ≈ HintSystemState (identical)
  • WatcherAssistAction ≈ HintSystemAction (identical)
  • Button3DID.watcherAssist ≈ Button3DID.hintSystem (same button)

Consolidation:
  1. Canonical name: HintsFeature
  2. Deleted: WatcherAssistPopoverState
  3. Renamed: hintSystem → hints
  4. Unified: Button3DID.hints (one button)
  5. Result: -450 lines of duplicate code
  6. Impact: Bugs resolved, architecture clearer
```

**Verification Checklist:**
- [ ] Searched for similar functionality in codebase
- [ ] Compared state type properties (checked for >80% overlap)
- [ ] Compared action enum cases (checked for duplicates)
- [ ] Checked button IDs / entity keys (verified not same element)
- [ ] If duplication found: Picked canonical name
- [ ] Renamed all occurrences consistently
- [ ] Deleted duplicate implementations
- [ ] Verified no parallel code paths doing same job

**Reference:** See DISCOVERY-12 for complete consolidation pattern and impact analysis.

---

## Tree 5: Build Monitoring Strategy

**Use this when you need to monitor builds, detect hangs, or optimize build performance.**

**Problem:** Builds taking 30+ minutes with no insight, hung builds, or unknown bottlenecks.

```
What type of project is this?
├─ Swift Package (Package.swift) → smith-sbsift
│   ├─ Need real-time monitoring?
│   │   ├─ YES → smith-sbsift monitor --monitor --eta
│   │   └─ NO → swift build | smith-sbsift parse
│   └─ Hung build?
│       ├─ YES → smith-sbsift monitor --hang-detection
│       └─ NO → smith-sbsift analyze
│
└─ Xcode Project (.xcodeproj/.xcworkspace) → smith-xcsift
    ├─ Need real-time progress tracking?
    │   ├─ YES → smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --eta
    │   └─ NO → xcodebuild | smith-xcsift parse
    └─ Build hanging or slow?
        ├─ YES → smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --hang-detection --timeout 300
        └─ NO → smith-xcsift analyze --workspace MyApp.xcworkspace --scheme MyApp
```

**Quick Commands:**
```bash
# Swift Package - Real-time monitoring
smith-sbsift monitor --monitor --eta

# Swift Package - Hang detection
smith-sbsift monitor --hang-detection

# Swift Package - Analysis
smith-sbsift analyze

# Xcode - Real-time monitoring with progress bar
smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --eta

# Xcode - Resource monitoring
smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --resources

# Xcode - Hang detection (30+ minute builds)
smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --hang-detection --timeout 600
```

**Expected Output Examples:**

**Real-time monitoring:**
```
🔨 [████████░░░░░░░] 60% - CoreFramework - Linking (12/20) - ETA: 8m - CPU: 75% MEM: 4.2GB - Files: 234/380
```

**Hang detection:**
```
🚨 BUILD HANG DETECTED!
📍 Suspected Phase: Package Resolution
📄 Suspected File: Package.swift
⏱️  Time Elapsed: 312.5s

💡 RECOVERY RECOMMENDATIONS:
   • Package resolution hang detected
   • Try: swift package reset
   • Or: rm -rf .build && swift package resolve
```

---

## Tree 6: Progressive Build Optimization

**Use this when builds are slow but not hanging. Apply optimizations incrementally.**

```
Is the build taking > 10 minutes?
├─ NO → Standard monitoring (Tree 5)
│
└─ YES → Apply optimizations in order:

    1. Enable real-time monitoring first
    ├─ Xcode: smith-xcsift monitor --workspace ... --eta --resources
    └─ Swift: smith-sbsift monitor --monitor --eta
    ↓
    2. After initial run, analyze bottlenecks
    ├─ Xcode: smith-xcsift analyze --workspace ... --verbose
    └─ Swift: smith-sbsift analyze
    ↓
    3. Apply easy wins first
    ├─ smith-xcsift rebuild --preserve-dependencies --parallel
    ├─ Clean DerivedData if > 2GB
    └─ Enable incremental compilation
    ↓
    4. Still slow? Advanced optimization
    ├─ smith-xcsift optimize --workspace ... --auto-apply
    └─ Review target structure for splitting
```

**Optimization Tiers:**

**Tier 1 - Quick Wins (5 min setup):**
```bash
# Enable monitoring
smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --eta

# Clean rebuild with optimizations
smith-xcsift rebuild --preserve-dependencies --parallel
```

**Tier 2 - Standard (15 min setup):**
```bash
# Full analysis
smith-xcsift analyze --workspace MyApp.xcworkspace --scheme MyApp --verbose

# Apply safe optimizations automatically
smith-xcsift optimize --workspace MyApp.xcworkspace --scheme MyApp --auto-apply
```

**Tier 3 - Advanced (1+ hour):**
```bash
# Generate detailed profile
smith-xcsift profile --workspace MyApp.xcworkspace --scheme MyApp --format json --memory

# Manual target restructuring based on analysis
```

---

## Tree 7: Emergency Build Recovery

**Use this when builds are completely stuck or failing.**

```
Is the build process responsive?
├─ YES → Normal monitoring (Tree 5)
│
└─ NO → Emergency recovery sequence:

    1. Quick diagnostics (30 seconds)
    ├─ Process check: ps aux | grep xcodebuild
    ├─ Memory check: top | head -5
    └─ Disk space: df -h
    ↓
    2. Force stop hanging processes
    ├─ killall xcodebuild
    ├─ killall swiftc
    └─ killall clang
    ↓
    3. Clean build state
    ├─ rm -rf ~/Library/Developer/Xcode/DerivedData
    ├─ swift package reset (if SPM)
    └─ xcodebuild clean (if Xcode)
    ↓
    4. Start with enhanced monitoring
    ├─ smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --hang-detection
    └─ OR smith-sbsift monitor --hang-detection (if SPM)
    ↓
    5. Monitor first 5 minutes closely
    ├─ Watch for immediate hang patterns
    ├─ Check resource usage trends
    └─ Abort if same pattern emerges → Go to deeper analysis
```

**Emergency Scripts:**
```bash
# Quick kill and clean
killall xcodebuild && killall swiftc
rm -rf ~/Library/Developer/Xcode/DerivedData

# Monitor with aggressive hang detection
smith-xcsift monitor --workspace MyApp.xcworkspace --scheme MyApp --hang-detection --timeout 120 --verbose

# If still hanging after 2 minutes
smith-xcsift analyze --workspace MyApp.xcworkspace --scheme MyApp --diagnose
```

---

## Quick Reference Card

Print this or bookmark it:

```
Q1: When to modularize?
→ Used in 2+ places? Reusable code? 20+ actions?
→ YES to any? Extract module.

Q2: @DependencyClient or singleton?
→ Used in reducer? Needs test mock? YES? Use @DependencyClient.
→ Stateless utility? Singleton is fine.

Q3: Should I refactor to module?
→ Causing pain? Blocking work? Will reuse? Stable?
→ YES to any? Extract. Otherwise wait.

Q4: Where should logic live?
→ SwiftUI views? → UI module
→ Domain logic? → Core module
→ Platform-specific? → Platform module

Q5: Build monitoring strategy?
→ Package.swift → smith-sbsift monitor
→ Xcode project → smith-xcsift monitor
→ Build hanging? → Add --hang-detection
→ Need progress bar? → Add --eta

Q6: Build optimization tier?
→ 10+ minutes? → Enable monitoring first
→ Still slow? → Apply optimizations progressively
→ 30+ minutes? → Emergency recovery
```

---

## Smith Tools Integration Matrix

| Situation | Primary Tool | Command Example | When to Use |
|----------|--------------|----------------|------------|
| **Basic monitoring** | smith-xcsift / smith-sbsift | `monitor --eta` | Need basic progress |
| **Real-time progress** | smith-xcsift / smith-sbsift | `monitor --monitor --eta` | Watch long builds |
| **Hang detection** | smith-xcsift / smith-sbsift | `monitor --hang-detection` | 30+ minute builds |
| **Resource monitoring** | smith-xcsift | `monitor --resources` | Memory/CPU issues |
| **Progressive optimization** | smith-xcsift | Tree 6 decision tree | Slow but working builds |
| **Emergency recovery** | smith-xcsift / shell | Tree 7 decision tree | Stuck/failing builds |

---

## References

- **Tree 1** references: [SPMModuleBoundaries.md](./Scroll/Docs/Architecture/SPMModuleBoundaries.md)
- **Tree 2** references: [AGENTS-AGNOSTIC.md - Dependency Injection](./AGENTS-AGNOSTIC.md#dependency-injection--modern-tca-patterns)
- **Tree 3-4** references: [AGENTS-AGNOSTIC.md - Modularization](./AGENTS-AGNOSTIC.md#modularization-best-practices)
