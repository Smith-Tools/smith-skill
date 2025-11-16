# Smith Framework Skill for Claude Code

A comprehensive Claude Skill that provides modern Swift development discipline with beautiful build monitoring, TCA patterns, and progressive disclosure.

## 🚀 Quick Start

### Using with Claude Code

1. **Install the Skill:**
   ```bash
   # Add smith-skill to your Claude Code configuration
   claude skill add /path/to/smith-skill
   ```

2. **Use the Smith Skill:**
   ```
   Use Smith skill for my iOS app with TCA and visionOS
   ```

3. **Build Monitoring Examples:**
   ```
   My Xcode build is hanging, help debug with Smith
   My Swift Package build is stuck, use Smith monitoring
   ```

## 🎯 What the Smith Skill Provides

### **Core Modules**

| Module | Purpose | When Auto-Loaded |
|--------|---------|------------------|
| **smith-core** | Universal Swift patterns (DI, concurrency, testing) | "dependency injection", "async/await", "testing" |
| **smith-tca** | Swift Composable Architecture patterns | "@Reducer", "@ObservableState", "TCA compilation" |
| **smith-platforms** | Platform-specific patterns (iOS, visionOS) | "visionOS", "RealityKit", "UIKit" |
| **smith-xcsift** | Xcode build analysis & monitoring | "Xcode build hanging", "workspace builds" |
| **smith-sbsift** | Swift Package Manager build analysis | "Swift Package stuck", "SPM compilation" |

### **Beautiful Build Monitoring**

All Smith tools now provide unified, beautiful progress bars:

```
🔨 [████████░░░░░░░░] 60% - TargetName - Compilation (12/20) - ETA: 8m
📈 CPU: 45% | Memory: 2.1GB | Files: 156/234
```

### **Progressive Monitoring Strategy**

1. **Quick Wins:** `smith-[tool] monitor --eta`
2. **Standard:** `smith-[tool] monitor --eta --resources`
3. **Advanced:** `smith-[tool] monitor --eta --resources --hang-detection`

## 🔧 Usage Examples

### **Dependency Injection**
```
How do I add @Dependency to my Swift code?
Use Smith skill for dependency injection in my networking layer
```

### **TCA Patterns**
```
My TCA reducer won't compile, what's wrong?
Use Smith for @ObservableState and @Shared patterns
```

### **Build Monitoring**
```
My iOS app build is hanging, use Smith to debug
Monitor my Swift Package build with progress bars
```

### **Platform Development**
```
Create visionOS RealityView entities with Smith
Use Smith for UIKit navigation patterns
```

## 📊 Decision Trees

The Smith skill includes comprehensive decision trees:

- **Tree 5:** Build Monitoring Strategy (progressive disclosure)
- **Tree 6:** Progressive Build Optimization (quick wins → advanced)
- **Tree 7:** Emergency Build Recovery (hang detection and resolution)

## 🛠 Required Tools

For the skill to provide build monitoring capabilities, ensure these tools are in your PATH:

- `smith-xcsift` - Xcode build analysis and monitoring
- `smith-sbsift` - Swift Package Manager build analysis
- `smith-core` - Shared data models and utilities

## 📚 Documentation Structure

- **SKILL.md** - Main skill documentation and routing
- **AGENTS-AGNOSTIC.md** - Universal Swift patterns
- **AGENTS-TCA-PATTERNS.md** - TCA patterns (Point-Free validated)
- **AGENTS-DECISION-TREES.md** - Architectural decision trees
- **PLATFORM-*.md** - Platform-specific patterns

## 🎯 Smart Module Detection

The Smith skill automatically detects which modules to load based on your request:

```
"My TCA app has build issues" → smith-tca + smith-xcsift
"My Swift Package needs dependency injection" → smith-core + smith-sbsift
"My visionOS app needs monitoring" → smith-platforms + smith-xcsift
```

## 🔍 Case Studies Included

- **DISCOVERY-5:** Access control cascade failures
- **DISCOVERY-13:** Swift compiler crashes and resolution
- **DISCOVERY-14:** Nested @Reducer patterns (Point-Free validated)
- **DISCOVERY-15:** Print vs OSLog logging patterns

## 🚀 Benefits

- ✅ **Prevents over-engineering** - 2-minute fixes stay 2-minute fixes
- ✅ **Beautiful progress monitoring** - Unified progress bars across all tools
- ✅ **Progressive disclosure** - Start simple, advance when needed
- ✅ **Point-Free validated** - All TCA patterns verified
- ✅ **Reading budgets** - 80% of tasks need < 15 minutes reading
- ✅ **Anti-pattern detection** - Stops mistakes before implementation

## 📖 Skill Configuration

The skill is configured in `skill.json` with:
- Auto-detection triggers for each module
- Tool availability and command patterns
- Example queries and responses
- Documentation references
- Installation requirements

## 🎯 Integration with Claude Code

Once installed, the Smith skill provides:

1. **Automatic routing** to the right documentation
2. **Context-aware tool selection** (xcsift vs sbsift)
3. **Progressive disclosure guidance** for monitoring
4. **Pattern validation** before implementation
5. **Beautiful build monitoring** when needed

Use "Use Smith skill for..." to activate the full framework capabilities!