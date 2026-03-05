# Codebase Rewriter

Ultra-detailed migration planning tool for rewriting codebases from TypeScript, Python, or Go to Rust.

A [Claude Code](https://claude.ai/code) Skill that analyzes source codebases and generates exhaustive migration plans where **every type, every dependency, every module** has a concrete Rust migration strategy. The output is detailed enough for [dev-workflow](https://github.com/nicepkg/dev-workflow-plugin) to execute mechanically.

## Pipeline

```
codebase-explorer     ->  codebase-rewriter     ->  dev-workflow
(understand code)         (plan Rust migration)     (execute rewrite)
```

## Supported Source Languages

| Language | Difficulty | Key Challenges |
|----------|-----------|----------------|
| Go | Medium | Implicit interfaces -> explicit traits; goroutine -> tokio; error -> Result |
| TypeScript | High | Dynamic types -> strict types; inheritance -> composition; Promise -> Future |
| Python | Very High | Duck typing -> traits; GIL -> true parallelism; metaclasses -> proc macros |

## Quick Start

```bash
# Install into your project
./install.sh /path/to/your/project

# Or install as symlink (for development)
./install.sh /path/to/your/project --symlink

# Then in Claude Code:
/codebase-rewriter
```

## Output

Generates `.migration-plan/` directory:

```
.migration-plan/
├── plan.md                     # Progress tracking (start here)
├── analysis/                   # Phase 1: Source analysis
│   ├── source-inventory.md     # Every file and module cataloged
│   ├── type-catalog.md         # Every type definition mapped
│   ├── error-patterns.md       # Error handling patterns
│   ├── async-model.md          # Async/concurrency analysis
│   ├── dependency-tree.md      # Full dependency graph
│   ├── architecture.md         # Architecture patterns
│   └── testing-build.md        # Test and build infrastructure
├── mappings/                   # Phase 2: Concrete Rust mappings
│   ├── module-mapping.md       # src/models/ -> models crate
│   ├── type-mapping.md         # interface User -> struct User
│   ├── dependency-mapping.md   # express -> axum, prisma -> sqlx
│   ├── error-hierarchy.md      # AppError enum design
│   ├── async-strategy.md       # tokio runtime + patterns
│   └── pattern-transforms.md   # Decorator -> proc macro, etc.
├── migration-plan.md           # Executive summary
├── feasibility-report.md       # Should you rewrite?
├── risk-assessment.md          # Risk matrix with mitigations
└── dev-workflow/               # Ready for dev-workflow
    ├── requirements.md
    ├── solution.md
    └── roadmap.md              # Step-by-step task list
```

## Detail Level

The core value is exhaustive detail. Every mapping includes actual Rust code:

```
Source (TypeScript -- src/models/user.ts:5-15):
  interface User {
    id: string;
    email: string | null;
    roles: Role[];
    createdAt: Date;
  }

Target (Rust):
  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct User {
      pub id: Uuid,
      pub email: Option<String>,
      pub roles: Vec<Role>,
      #[serde(rename = "createdAt")]
      pub created_at: DateTime<Utc>,
  }

Conversion Notes:
  - id: string -> Uuid (validate existing data)
  - email: string | null -> Option<String>
  - createdAt -> created_at with serde rename
  - Crates: uuid, chrono, serde
```

## How It Works

### Phase 0: Foundation (Main Agent)
Detect source language, scan directory tree, check for existing codebase-explorer output.

### Phase 1: Source Analysis (2-3 Agents, parallel)
Deep analysis of types, errors, async patterns, dependencies, architecture, and testing.

### Phase 2: Rust Mapping (2-4 Agents, parallel)
Concrete mappings for every type, dependency, error pattern, and async construct.

### Phase 3: Synthesis (Main Agent)
Generate executive summary, feasibility report, risk assessment, and dev-workflow roadmap.

### Phase 4: Scaffold (Optional)
Generate Cargo workspace, module skeletons, and CI configuration.

## Reference Guides

The skill includes 35 reference guides:

| Category | Count | Guides |
|----------|-------|--------|
| Source Analysis | 7 | Source inventory, types, errors, async, deps, architecture, testing |
| Common Mapping | 6 | Ownership, errors, async, generics, testing, crate recommendations |
| TypeScript -> Rust | 6 | Types, null/Option, classes, Promise/Future, npm->crates, patterns |
| Python -> Rust | 6 | Types, None/Option, classes, asyncio->tokio, pip->crates, patterns |
| Go -> Rust | 6 | Types, error->Result, goroutine->tokio, interfaces, go mod->crates, patterns |
| Output Templates | 8 | Migration plan, module/dep/type mapping, errors, roadmap, risk, feasibility |
| Scaffold | 3 | Cargo workspace, module skeletons, CI configuration |

## Installation

### Per-project (recommended)

```bash
./install.sh /path/to/project
```

### Global skill

```bash
mkdir -p ~/.claude/skills
ln -sfn /path/to/codebase-rewriter ~/.claude/skills/codebase-rewriter
```

### As submodule

```bash
cd your-project
git submodule add https://github.com/Adancurusul/codebase-rewriter.git
./codebase-rewriter/install.sh .
```

### Uninstall

```bash
./install.sh /path/to/project --uninstall
```

## Integration

### With codebase-explorer

If `.codebase-analysis/` exists, codebase-rewriter reuses it and focuses on migration-specific analysis.

### With dev-workflow

The output `dev-workflow/roadmap.md` uses dev-workflow's exact format:

```bash
/codebase-rewriter    # Generate migration plan
/roadmap              # Load the roadmap
/dev-execution        # Execute tasks
```

## Documentation

- [USAGE.md](USAGE.md) -- Detailed usage guide with real-world examples
- [SKILL.md](SKILL.md) -- Skill definition (for Claude Code)
