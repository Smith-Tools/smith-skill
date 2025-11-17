# smith-skill - Swift Architecture Validation & Guidance

> **Agentic guidance for Swift architecture, TCA composition, and modern best practices through Claude Code.**

Production-ready Claude Skill providing automated architectural validation, pattern libraries, and decision guidance for Swift development teams.

## 🎯 What is smith-skill?

smith-skill is the core component of Smith Tools, providing:

- **TCA Composition Validators** - Detect architectural violations (Rules 1.1-1.5)
- **Pattern Library** - 40+ validated TCA, concurrency, and testing patterns
- **Decision Trees** - Architectural guidance for common scenarios
- **Build Analysis** - Context-efficient compilation debugging
- **Platform Patterns** - visionOS, iOS, macOS best practices
- **Agentic Integration** - Seamless Claude Code workflow

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/Smith-Tools/smith-skill.git

# Install to Claude Code
ln -s $(pwd)/smith-skill ~/.claude/skills/smith

# Verify installation
ls ~/.claude/skills/smith/SKILL.md
```

### Usage in Claude Code

```
"Use Smith skill to analyze my TCA reducer"
"Is my reducer violating composition rules?"
"What should I extract from this monolithic feature?"
```

**Result:** Claude automatically detects your architecture question and provides guidance with optional WWDC context from sosumi-skill.

## 📦 Core Components

### TCA Composition Validators (4 Scripts)

Located in `Scripts/`:

1. **validate-tca-composition.sh** (9.6 KB)
   - Detects Rules 1.1-1.5 violations
   - Human-readable or JSON output
   - Strict mode for CI/CD gating

2. **check-tca-testability.sh** (6.7 KB)
   - Testability scoring (0-100)
   - Identifies testing blockers
   - Provides improvement guidance

3. **recommend-tca-extractions.sh** (7.8 KB)
   - Suggests features to extract
   - Prioritizes by value (P1/P2/P3)
   - Estimates effort (2h-12h)

4. **analyze-tca-dependency-graph.sh** (5.5 KB)
   - Maps state dependencies
   - Calculates coupling complexity
   - Suggests decomposition strategies

### Pattern Documentation

- **AGENTS-TCA-PATTERNS.md** - Canonical TCA patterns with examples
- **AGENTS-AGNOSTIC.md** - Universal Swift patterns (concurrency, testing, dependencies)
- **AGENTS-DECISION-TREES.md** - Architectural decision guidance
- **PLATFORM-VISIONOS.md** - visionOS-specific patterns
- **SKILL.md** - Complete skill documentation

## 🔄 Integration with Sosumi

smith-skill works seamlessly with **sosumi-skill** for comprehensive guidance:

- **Architecture questions** → smith-skill
- **API/documentation questions** → sosumi-skill (Apple docs + WWDC)
- **Both needed** → Combined response (optimal)

When integrated: **70% token efficiency vs WebSearch**, plus architectural validation unavailable elsewhere.

## 📊 Performance

- **Load time:** <10ms (warm start)
- **Installation size:** 1.0 MB (87 files)
- **Context efficiency:** 70% savings vs WebSearch for complex queries
- **WWDC coverage:** 2018-2025 (through sosumi integration)

## 🛠️ Development

### Building Locally

```bash
# No build needed—smith-skill is pure Markdown and bash scripts
# Just use directly from cloned directory

# Run validators
./Scripts/validate-tca-composition.sh Sources/
./Scripts/check-tca-testability.sh Sources/
./Scripts/recommend-tca-extractions.sh Sources/
./Scripts/analyze-tca-dependency-graph.sh Sources/
```

### Contributing

1. Read [AGENTS-TCA-PATTERNS.md](./AGENTS-TCA-PATTERNS.md) for pattern standards
2. Read [AGENTS-DECISION-TREES.md](./AGENTS-DECISION-TREES.md) for decision guidance
3. Test patterns on real codebases before submitting
4. Update relevant documentation files
5. Follow commit message guidelines (see main README)

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **SKILL.md** | How to use smith-skill in Claude Code |
| **AGENTS-TCA-PATTERNS.md** | TCA composition patterns and anti-patterns |
| **AGENTS-AGNOSTIC.md** | Universal Swift patterns (not TCA-specific) |
| **AGENTS-DECISION-TREES.md** | Decision guidance for architectural choices |
| **PLATFORM-VISIONOS.md** | visionOS-specific patterns and best practices |
| **Scripts/README-TCA-COMPOSITION.md** | Validators reference guide |

## 🔗 Related Components

- **[sosumi-skill](../sosumi-skill/)** - Apple documentation + WWDC transcripts
- **[smith-core](../smith-core/)** - Universal Swift patterns library
- **[smith-sbsift](../smith-sbsift/)** - Swift build analysis
- **[smith-spmsift](../smith-spmsift/)** - SPM analysis
- **[smith-xcsift](../smith-xcsift/)** - Xcode project analysis

## 🤝 Contributing

Contributions welcome! Please:

1. Discuss new patterns in GitHub issues first
2. Add real-world case studies when patterns emerge
3. Test on production codebases
4. Update SKILL.md version when merging

## 📄 License

MIT - See [LICENSE](LICENSE) for details

---

**smith-skill v1.2.0 - Production Ready**

Agentic validation, expert patterns, architectural guidance—all built for production Swift teams.

*Last updated: November 17, 2025*