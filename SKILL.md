---
name: codebase-rewriter
description: |
  Analyze codebases written in TypeScript, Python, or Go and generate ultra-detailed migration plans for rewriting to Rust.
  Every type, every dependency, every module gets a concrete Rust migration strategy.
  Use when users ask to: (1) rewrite/migrate code to Rust, (2) assess Rust migration feasibility,
  (3) plan a language migration, (4) map source code constructs to Rust equivalents,
  (5) generate detailed refactoring plans for Rust rewrite.
  Outputs migration plan files to .migration-plan/ folder with progress tracking.
  Keywords: rewrite, migrate, rust, migration plan, refactor to rust, convert to rust, port to rust.
  Not for: general codebase understanding (use codebase-explorer), Rust code review (use rust-skills),
  or execution of migration tasks (use dev-workflow).
user-invokable: true
---

# Codebase Rewriter

Generate ultra-detailed migration plans for rewriting codebases from TypeScript/Python/Go to Rust.

**Core principle**: Every type, every dependency, every module gets a concrete migration strategy. The output is detailed enough for dev-workflow to execute mechanically without additional design decisions.

## Workflow

1. **Check for existing plan**: Read `.migration-plan/plan.md` if it exists -- resume from last checkpoint
2. Create `.migration-plan/` folder in project root (if new)
3. **Detect source language**: Read package.json/tsconfig.json (TS), pyproject.toml/requirements.txt (Python), go.mod (Go), or mixed
4. **Check for codebase-explorer output**: If `.codebase-analysis/` exists, use it to skip redundant scanning
5. **Measure repo size**: Count project files (exclude node_modules, .git, build, dist, vendor, __pycache__, venv). If > 500 files, offer Quick Mode vs Full Mode
6. **Detect output language**: Match the language the user used to invoke this skill
7. **Scan directory tree**: depth 3-4, save as shared context
8. Generate `plan.md` with all analysis and mapping tasks
9. **Execute analysis** using Parallel Mode (default) or Serial Mode (fallback)
10. Mark completed tasks in `plan.md`

### Skip Rules

Mark a task `[-] N/A` when:
- **Language ref not needed**: Only load `ref/{language}.md` for the detected source language
- **Quick Mode**: Large repos skip detailed type/dependency mapping, produce summary-level plan only

## Output Structure

```
.migration-plan/
├── plan.md                           # Progress tracking (start here)
│
├── analysis/                         # Phase 1: Source codebase analysis
│   ├── source-inventory.md           # File/module inventory
│   ├── type-catalog.md               # Every type definition cataloged
│   ├── error-patterns.md             # Error handling pattern inventory
│   ├── async-model.md                # Async/concurrency model analysis
│   ├── dependency-tree.md            # Dependency tree with transitive deps
│   ├── architecture.md               # Architecture pattern analysis
│   └── testing-build.md              # Test structure and build system
│
├── mappings/                         # Phase 2: Concrete Rust mappings
│   ├── module-mapping.md             # Source module -> Rust module/crate
│   ├── type-mapping.md               # Source type -> Rust type (with code!)
│   ├── dependency-mapping.md         # Source package -> Rust crate
│   ├── error-hierarchy.md            # Rust Error type hierarchy design
│   ├── async-strategy.md             # Async runtime + pattern transforms
│   └── pattern-transforms.md         # Design pattern conversions
│
├── migration-plan.md                 # Executive summary
├── feasibility-report.md             # Should you rewrite? Assessment
├── risk-assessment.md                # Risk matrix
│
└── dev-workflow/                     # dev-workflow compatible output
    ├── requirements.md               # Migration requirements doc
    ├── solution.md                   # Migration architecture
    └── roadmap.md                    # Step-by-step roadmap
```

## Parallel Execution

Use the Agent tool to run analysis and mapping tasks concurrently.

### Why parallel works

Phase 1 tasks analyze different aspects of source code independently. Phase 2 mapping tasks each focus on a different dimension (types, deps, errors, async). No task reads another task's output file. Only Phase 3 (synthesis) needs all prior outputs.

### Execution Phases

#### Phase 0: Foundation (Main Agent, serial)

1. Scan directory tree (depth 3-4), store result
2. Detect source language(s) and framework(s)
3. Check for `.codebase-analysis/` (reuse if present)
4. Create `.migration-plan/` folder and `plan.md`
5. Prepare shared context for agent prompts

#### Phase 1: Source Analysis (2-3 Agents, parallel)

Spawn `general-purpose` agents **in a single response**:

| Agent | Tasks | Guides |
|-------|-------|--------|
| Analyzer-A | Source inventory + Type system + Architecture | 00, 01, 05 (~180 lines) |
| Analyzer-B | Error handling + Async model + Dependencies + Testing | 02, 03, 04, 06 (~240 lines) |

If `.codebase-analysis/` exists, Analyzer-A reads existing analysis and focuses only on migration-specific additions (type cataloging for migration, not general documentation).

Each agent writes to `.migration-plan/analysis/`.

#### Phase 2: Rust Mapping (2-3 Agents, parallel)

After Phase 1 completes, spawn mapping agents:

| Agent | Tasks | Guides | Ref Table |
|-------|-------|--------|-----------|
| Mapper-A | Type mapping + Module mapping + Pattern transforms | 10, 14, 15 (~240 lines) | ref/{lang}.md (Type + Pattern sections) |
| Mapper-B | Error hierarchy + Async strategy + Dependency mapping | 11, 12, 13 (~220 lines) | ref/{lang}.md (Error + Async + Crate sections) |
| Mapper-C | (multi-language only) Second language mappings | 10-15 | ref/{lang2}.md |

Each mapping agent:
1. Reads 2-3 method guides (~60-80 lines each)
2. Reads relevant sections from `ref/{language}.md` (lookup tables)
3. Reads the Phase 1 analysis output for its area
4. Produces CONCRETE mappings with Rust code examples
5. Writes to `.migration-plan/mappings/`

**Critical rule**: Enumerate EVERY item. Do not summarize. If there are 47 interfaces, list all 47 with their Rust equivalents. If there are 23 npm packages, map all 23 to crate equivalents.

#### Phase 3: Synthesis (Main Agent, serial)

After ALL Phase 2 agents complete:
1. Read all analysis and mapping files
2. Read `references/output/templates.md` for output format specs
3. Generate `migration-plan.md` (executive summary)
4. Generate `feasibility-report.md` (should you rewrite?)
5. Generate `risk-assessment.md`
6. Generate `dev-workflow/` directory:
   - `requirements.md` (each module migration = one requirement)
   - `solution.md` (migration architecture)
   - `roadmap.md` (step-by-step tasks in dev-workflow format)
7. Final update to `plan.md`

#### Phase 4: Scaffold (Optional, on request)

Only when user explicitly asks for scaffold generation:
1. Read `references/scaffold/scaffold.md`
2. Read `mappings/module-mapping.md`, `type-mapping.md`, `dependency-mapping.md`, `error-hierarchy.md`
3. Generate Cargo workspace, module skeletons, error types, CI config

### Agent Prompt Template

```
You are analyzing a codebase to plan its migration to Rust.
Your job is to explore the source code and produce DETAILED migration documents.

## Project Info
- Path: {project_root}
- Output directory: {project_root}/.migration-plan/
- Source Language: {language}
- Framework: {framework}
- Files: {count}

## Directory Tree
{tree_output from Phase 0}

## Existing Analysis (if available)
{summary from .codebase-analysis/ if present}

## Your Tasks

### Task: {task_name}
1. Read the method guide: {skill_dir}/references/{guide_path}
2. (Phase 2 only) Read lookup tables: {skill_dir}/references/ref/{language}.md
3. Follow the guide's Method section to explore the codebase
4. Write output to: {output_path}

(repeat for each assigned task)

## Rules
- Output language: {detected_language} (file names stay English)
- Source references: [file.ts:15](../src/file.ts#L15)
- CRITICAL: Enumerate EVERY item. Do not summarize.
  - Every type definition gets a concrete Rust mapping
  - Every dependency gets a crate recommendation
  - Every error pattern gets a Result<T, E> design
- File sampling: <=30 files read all, 31-100 read 30 + sample, >100 read 20 + stats
- For type mappings: include actual Rust code (struct/enum definitions)
- For dependency mappings: include crate name, version, and API comparison table
```

### Fallback to Serial Mode

Use Serial Mode when Agent tool is unavailable:

| Batch | Tasks | Guides |
|-------|-------|--------|
| 1 | Phase 0 + Analysis (00-03) | Foundation + guides 00, 01, 02, 03 |
| 2 | Analysis (04-06) + Mapping (10, 14) | Guides 04, 05, 06, 10, 14 + ref/{lang}.md |
| 3 | Mapping (11, 12, 13, 15) | Guides 11, 12, 13, 15 + ref/{lang}.md |
| 4 | Synthesis | output/templates.md + all prior outputs |

After each batch: update plan.md, prompt `/compact`, resume from next pending.

## Context Budget

### Rule 1: Load ONE Guide at a Time

For each task, load ONLY its reference guide. Never pre-load multiple guides.

### Rule 2: Enumerate, Don't Summarize

This is the most important rule. For every analysis and mapping task:
- List EVERY type/interface/class found, not "found N types"
- Map EVERY dependency, not "uses several HTTP libraries"
- Show EVERY error pattern, not "uses try-catch extensively"

When items exceed context budget, split into sub-files:
```
.migration-plan/mappings/
  type-mapping.md           # Summary + first 20 types
  type-mapping-continued.md # Types 21-47
```

### Rule 3: File Sampling

| Matches | Strategy |
|---------|----------|
| <= 30 files | Read all |
| 31-100 | Read first 30 + sample 3 per directory |
| > 100 | Read first 20 + directory stats, mark "(sampled)" |

### Rule 4: Quick Mode for Large Repos

When > 500 files detected:
```
Large repository detected (N files). Choose mode:
A) Full migration plan (all types/deps mapped individually)
B) Quick mode (module-level mapping only, skip individual type mapping)
```

## plan.md Template

```markdown
# Migration Plan

Project: {project-name}
Path: {project-path}
Started: {date}
Source Language: {TypeScript | Python | Go | Mixed}
Framework: {Express | FastAPI | Gin | ...}
Target: Rust
Output: {Chinese | English | ...}
Files: {count}
Mode: {Full | Quick}
Execution: {Parallel | Serial}

Legend: [x] Done | [x] (sampled) Sampled | [-] N/A | [ ] Pending

## Phase 1: Source Analysis
- [ ] A0. Source Inventory -> [analysis/source-inventory.md](./analysis/source-inventory.md)
- [ ] A1. Type Catalog -> [analysis/type-catalog.md](./analysis/type-catalog.md)
- [ ] A2. Error Patterns -> [analysis/error-patterns.md](./analysis/error-patterns.md)
- [ ] A3. Async Model -> [analysis/async-model.md](./analysis/async-model.md)
- [ ] A4. Dependency Tree -> [analysis/dependency-tree.md](./analysis/dependency-tree.md)
- [ ] A5. Architecture -> [analysis/architecture.md](./analysis/architecture.md)
- [ ] A6. Testing & Build -> [analysis/testing-build.md](./analysis/testing-build.md)

## Phase 2: Rust Mapping
- [ ] M0. Module Mapping -> [mappings/module-mapping.md](./mappings/module-mapping.md)
- [ ] M1. Type Mapping -> [mappings/type-mapping.md](./mappings/type-mapping.md)
- [ ] M2. Dependency Mapping -> [mappings/dependency-mapping.md](./mappings/dependency-mapping.md)
- [ ] M3. Error Hierarchy -> [mappings/error-hierarchy.md](./mappings/error-hierarchy.md)
- [ ] M4. Async Strategy -> [mappings/async-strategy.md](./mappings/async-strategy.md)
- [ ] M5. Pattern Transforms -> [mappings/pattern-transforms.md](./mappings/pattern-transforms.md)

## Phase 3: Synthesis
- [ ] S0. Migration Plan -> [migration-plan.md](./migration-plan.md)
- [ ] S1. Feasibility Report -> [feasibility-report.md](./feasibility-report.md)
- [ ] S2. Risk Assessment -> [risk-assessment.md](./risk-assessment.md)
- [ ] S3. dev-workflow Roadmap -> [dev-workflow/roadmap.md](./dev-workflow/roadmap.md)

## Phase 4: Scaffold (optional)
- [ ] X0. Cargo Workspace
- [ ] X1. Module Skeletons
```

## Source Language Detection

| Signal | Language |
|--------|----------|
| `package.json` + `tsconfig.json` | TypeScript |
| `package.json` (no tsconfig) | JavaScript |
| `pyproject.toml` / `requirements.txt` / `setup.py` / `Pipfile` | Python |
| `go.mod` / `go.sum` | Go |
| Multiple signals | Mixed (load guides for each detected language) |

## Mapping Detail Level

The core value of this tool is **exhaustive detail**. Every mapping document must meet these standards:

### Type Mapping Standard

For EACH source type, provide:
1. Source code (exact definition with file:line reference)
2. Target Rust code (compilable struct/enum/trait definition)
3. Conversion notes (derive macros, serde attributes, crate dependencies)
4. Impact scope (which files reference this type)
5. Migration order (dependency-sorted position)

### Dependency Mapping Standard

For EACH source dependency, provide:
1. Package name and version
2. Purpose in the project (what it's used for)
3. Rust crate equivalent (name + version)
4. Confidence level (HIGH / MEDIUM / LOW / NO_EQUIVALENT)
5. API comparison table (key functions/methods side by side)
6. Migration notes (behavioral differences, gotchas)

### Module Mapping Standard

For EACH source module/directory, provide:
1. Source path and file count
2. Target Rust module/crate name
3. Public API surface (exported functions/types)
4. Internal dependencies (which other modules it imports)
5. Migration complexity rating (Low / Medium / High / Very High)
6. Migration order (dependency-sorted)

## Link Format

```markdown
Source: [src/models/user.ts:15](../src/models/user.ts#L15)
Range: [handler.ts:10-25](../src/api/handler.ts#L10-L25)
```

## Output Language

Match the user's input language:
- Chinese input -> Chinese documents
- English input -> English documents
- File names always stay English
- Code identifiers unchanged

## Integration with codebase-explorer

If `.codebase-analysis/` exists in the project:
1. Read `05-dependencies.md` for pre-analyzed dependency list
2. Read `10-architecture.md` for architecture patterns
3. Read `03-modules/_index.md` for module structure
4. Read `01-structure.md` for directory tree
5. Skip redundant scanning in Phase 1 where data already exists
6. Focus Phase 1 agents on migration-specific analysis (type cataloging, error patterns)

This is NOT a hard dependency. Without codebase-analysis, the skill performs its own complete analysis.

## Integration with dev-workflow

The `dev-workflow/` subdirectory contains files that dev-workflow can consume directly:

```
Migration output:                    dev-workflow input:
=================                    ==================
dev-workflow/requirements.md  --->  doc/requirements.md (or doc/需求文档.md)
dev-workflow/solution.md      --->  doc/solution.md (or doc/解决方案.md)
dev-workflow/roadmap.md       --->  doc/roadmap.md
```

The roadmap uses dev-workflow's exact format:
```markdown
- [ ] #N Task name
  - Description: ...
  - Rounds: N (risk X.X, effective M)
  - Verification: ...
  - Dependencies: #M, #K
```

## Reference Guides

**Load ONLY the guide(s) for the current task.** Each guide is ~60-80 lines.

### Method Guides (Phase 1: Analysis)

| Task | Guide | ~Lines |
|------|-------|--------|
| A0. Source Inventory | [references/analysis/00-source-inventory.md](references/analysis/00-source-inventory.md) | 45 |
| A1. Type System | [references/analysis/01-type-system.md](references/analysis/01-type-system.md) | 60 |
| A2. Error Handling | [references/analysis/02-error-handling.md](references/analysis/02-error-handling.md) | 60 |
| A3. Async/Concurrency | [references/analysis/03-async-concurrency.md](references/analysis/03-async-concurrency.md) | 60 |
| A4. Dependencies | [references/analysis/04-dependency-graph.md](references/analysis/04-dependency-graph.md) | 60 |
| A5. Architecture | [references/analysis/05-architecture.md](references/analysis/05-architecture.md) | 55 |
| A6. Testing & Build | [references/analysis/06-testing-build.md](references/analysis/06-testing-build.md) | 55 |

### Method Guides (Phase 2: Mapping)

| Task | Guide | ~Lines |
|------|-------|--------|
| M1. Type Mapping | [references/mapping/10-type-mapping.md](references/mapping/10-type-mapping.md) | 85 |
| M3. Error Hierarchy | [references/mapping/11-error-mapping.md](references/mapping/11-error-mapping.md) | 75 |
| M4. Async Strategy | [references/mapping/12-async-mapping.md](references/mapping/12-async-mapping.md) | 70 |
| M2. Dependency Mapping | [references/mapping/13-dependency-mapping.md](references/mapping/13-dependency-mapping.md) | 70 |
| M0. Module Mapping | [references/mapping/14-module-mapping.md](references/mapping/14-module-mapping.md) | 75 |
| M5. Pattern Transforms | [references/mapping/15-pattern-mapping.md](references/mapping/15-pattern-mapping.md) | 65 |

### Language Reference Tables (Phase 2: lookup on demand)

| Language | Reference | ~Lines | Sections |
|----------|-----------|--------|----------|
| TypeScript | [references/ref/typescript.md](references/ref/typescript.md) | 324 | Types, NPM->Crate, Patterns |
| Python | [references/ref/python.md](references/ref/python.md) | 277 | Types, pip->Crate, Patterns |
| Go | [references/ref/go.md](references/ref/go.md) | 278 | Types, Module->Crate, Patterns |

### Output Templates (Phase 3)

| Document | Template |
|----------|----------|
| All synthesis docs | [references/output/templates.md](references/output/templates.md) |

Templates cover: migration-plan.md, feasibility-report.md, risk-assessment.md, dev-workflow/roadmap.md, dev-workflow/requirements.md, dev-workflow/solution.md.

### Scaffold (Phase 4, optional)

| Task | Guide |
|------|-------|
| Full scaffold | [references/scaffold/scaffold.md](references/scaffold/scaffold.md) |

Covers: Cargo workspace, module skeletons, error types, CI config, supporting files.
