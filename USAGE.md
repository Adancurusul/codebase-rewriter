# Codebase Rewriter - Usage Guide

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and configured
- A project written in TypeScript, Python, or Go that you want to rewrite in Rust
- (Optional) Run `codebase-explorer` first for faster analysis

## Installation

### Per-project (recommended)

```bash
# Copy to your project
./install.sh /path/to/your/project

# Or symlink for development
./install.sh /path/to/your/project --symlink
```

### Global

```bash
mkdir -p ~/.claude/skills
ln -sfn /path/to/codebase-rewriter ~/.claude/skills/codebase-rewriter
```

## Quick Start

```bash
cd /path/to/your/project
claude
# Then type:
/codebase-rewriter
```

That's it. The skill will:
1. Detect your source language (TypeScript, Python, Go, or mixed)
2. Analyze every file, type, dependency, and pattern
3. Generate a complete migration plan in `.migration-plan/`

## Output

After running, you'll find `.migration-plan/` in your project root:

```
.migration-plan/
├── plan.md                     # Progress tracking -- start here
├── analysis/                   # Deep source code analysis
│   ├── source-inventory.md     # Every file and module cataloged
│   ├── type-catalog.md         # Every type definition mapped
│   ├── error-patterns.md       # Error handling patterns
│   ├── async-model.md          # Async/concurrency analysis
│   ├── dependency-tree.md      # Full dependency graph
│   ├── architecture.md         # Architecture patterns
│   └── testing-build.md        # Test and build infrastructure
├── mappings/                   # Concrete Rust migration strategies
│   ├── module-mapping.md       # src/models/ -> models crate
│   ├── type-mapping.md         # interface User -> struct User
│   ├── dependency-mapping.md   # express -> axum, prisma -> sqlx
│   ├── error-hierarchy.md      # AppError enum design
│   ├── async-strategy.md       # tokio runtime + patterns
│   └── pattern-transforms.md   # Decorator -> proc macro, etc.
├── migration-plan.md           # Executive summary
├── feasibility-report.md       # Should you rewrite?
├── risk-assessment.md          # Risk matrix with mitigations
└── dev-workflow/               # Ready for dev-workflow execution
    ├── requirements.md         # Each module = one requirement
    ├── solution.md             # Migration architecture
    └── roadmap.md              # Step-by-step task list
```

## Modes

### Full Mode (default, < 500 files)

Analyzes every file, every type, every dependency. Produces the most detailed migration plan.

### Quick Mode (offered for > 500 files)

Samples representative files, focuses on architecture and high-risk areas. Produces a summary-level plan with pointers to deep-dive later.

## Integration with Other Tools

### Pipeline

```
codebase-explorer     ->  codebase-rewriter     ->  dev-workflow
(understand code)         (plan Rust migration)     (execute rewrite)
```

### With codebase-explorer

If you run `codebase-explorer` first (producing `.codebase-analysis/`), `codebase-rewriter` will:
- Skip redundant source scanning
- Reuse module structure, dependency list, and architecture analysis
- Focus exclusively on migration-specific analysis

```bash
# Step 1: Understand the codebase
/codebase-explorer

# Step 2: Plan the migration
/codebase-rewriter
```

### With dev-workflow

The output `dev-workflow/roadmap.md` is formatted for direct consumption:

```bash
# Step 1: Generate migration plan
/codebase-rewriter

# Step 2: Initialize the Rust project
/dev-start

# Step 3: Load the roadmap
/roadmap

# Step 4: Execute tasks
/dev-execution
```

## Real-World Example: Express.js API -> Rust axum

### Source Project

A typical Express.js REST API:
- 12 route handlers in `src/routes/`
- 8 TypeScript interfaces in `src/models/`
- 15 npm dependencies (express, prisma, zod, etc.)
- jest test suite with 45 tests
- ~3,200 lines of TypeScript

### Running codebase-rewriter

```
$ cd my-express-api
$ claude
> /codebase-rewriter
```

### What Gets Generated

#### type-mapping.md (excerpt)

```markdown
## Type #1: User -- src/models/user.ts:5-15

### Source (TypeScript)
interface User {
  id: string;
  email: string;
  name: string | null;
  role: "admin" | "user" | "viewer";
  createdAt: Date;
}

### Target (Rust)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub name: Option<String>,
    pub role: UserRole,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum UserRole {
    Admin,
    User,
    Viewer,
}

### Conversion Notes
- `id: string` -> `Uuid` -- validate existing data contains UUIDs
- `name: string | null` -> `Option<String>`
- `role` string union -> dedicated `UserRole` enum
- `createdAt` -> `created_at` with `#[serde(rename = "createdAt")]`
- Crates needed: uuid, chrono, serde
```

#### dependency-mapping.md (excerpt)

```markdown
## Dependency #1: express ^4.18

| Field | Value |
|-------|-------|
| Source Package | express ^4.18.2 |
| Usage | HTTP server, routing, middleware |
| Rust Crate | axum 0.8 |
| Confidence | HIGH |
| Migration Effort | Medium |

### API Mapping
| Express | axum |
|---------|------|
| `app.get('/path', handler)` | `Router::new().route("/path", get(handler))` |
| `req.body` | `Json<T>` extractor |
| `req.params.id` | `Path(id): Path<String>` |
| `res.json(data)` | return `Json(data)` |
| `app.use(middleware)` | `.layer(middleware)` |
```

#### roadmap.md (excerpt)

```markdown
## Milestone 1: Foundation

- [ ] #1 Initialize Cargo workspace
  - Description: Create workspace with crates: models, error, api, services
  - Rounds: 5 (risk 1.0, effective 5)
  - Verification: `cargo build` passes
  - Dependencies: none

- [ ] #2 Implement error types
  - Description: AppError enum with NotFound, Unauthorized, Validation, Internal
  - Rounds: 8 (risk 1.3, effective 10)
  - Verification: `cargo test -p error`, all variants have Display + IntoResponse
  - Dependencies: #1

- [ ] #3 Migrate 8 model types
  - Description: User, Post, Comment, Tag, Category, Session, ApiKey, Webhook
  - Rounds: 20 (risk 1.3, effective 26)
  - Verification: `cargo test -p models`, serde round-trip tests pass
  - Dependencies: #1
```

#### feasibility-report.md (excerpt)

```markdown
## Recommendation: GO

## Score: 7.4 / 10

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Performance Need | 6 | Current latency acceptable but scaling concerns |
| Safety Need | 8 | Production crashes from null references |
| Deployment Benefit | 9 | Docker image from 800MB to 15MB |
| Type System Benefit | 7 | Many runtime type errors would become compile errors |
| Ecosystem Maturity | 8 | axum + sqlx + serde covers all needs |
| Team Readiness | 5 | Team has 1 Rust developer, 3 need training |
| Codebase Complexity | 7 | Moderate complexity, clear module boundaries |
| Maintenance Burden | 8 | Frequent dependency updates, security patches |
```

## Tips

### Before Running

1. **Clean up your project first** -- remove dead code, unused dependencies
2. **Run codebase-explorer** -- the migration plan benefits from pre-existing analysis
3. **Have your requirements clear** -- know which parts you want to migrate first

### After Running

1. **Read feasibility-report.md first** -- it may recommend NOT migrating
2. **Review type-mapping.md carefully** -- this is where most design decisions live
3. **Check dependency-mapping.md** -- look for `NO_EQUIVALENT` entries
4. **Feed roadmap.md to dev-workflow** -- let it execute the migration step by step

### Common Adjustments

- **Partial migration**: Edit `migration-plan.md` scope to exclude modules you want to keep in the original language
- **FFI bridge**: If some modules can't be migrated, the plan includes FFI interop strategies
- **Different runtime**: Default is tokio; switch to async-std by updating `async-strategy.md`

## Supported Language Features

### TypeScript
- Interfaces, type aliases, enums, union types, intersection types
- Classes with inheritance, mixins, decorators
- Promise/async/await, event emitters
- npm dependency ecosystem
- Jest/Mocha test suites

### Python
- Type hints, dataclasses, TypedDict, NamedTuple, Protocol
- Classes with multiple inheritance, metaclasses, descriptors
- asyncio, generators, context managers
- pip/PyPI dependency ecosystem
- pytest/unittest test suites

### Go
- Structs, interfaces (implicit satisfaction), type assertions
- Goroutines, channels, sync primitives
- Error handling (multi-return)
- Go module ecosystem
- Table-driven tests

### Mixed Projects

If your project uses multiple languages, codebase-rewriter:
1. Detects all languages present
2. Loads the appropriate `ref/{language}.md` lookup tables for each
3. Produces unified migration plan with cross-language dependencies
4. Suggests migration order considering inter-service boundaries

## Troubleshooting

### "Too many files" warning

The skill limits analysis to prevent context overflow. For very large projects:
- Use Quick Mode first to get an overview
- Then run Full Mode on individual modules/services

### Missing `.codebase-analysis/`

Not required. The skill runs its own analysis. But having it speeds up Phase 1.

### Incorrect language detection

The skill auto-detects from config files. If it gets it wrong, tell Claude directly:
```
This is a TypeScript project, not JavaScript. Please re-analyze.
```

### Incomplete type mapping

If some types are missing from `type-mapping.md`, check:
- Were they in files excluded by the sampling rules?
- Run again with explicit file paths to include them
