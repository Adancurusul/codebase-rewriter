# 05 - Architecture Pattern Analysis

**Output**: `.migration-plan/analysis/architecture.md`

## Purpose

Analyze the source codebase's architectural patterns, module boundaries, internal dependency graph, and design patterns. This analysis determines how the Rust project should be structured:

- Should it be a single crate, a workspace, or a workspace with library + binary crates?
- Which modules map to Rust modules vs separate crates?
- Where are the boundaries that become Rust module visibility (`pub` vs `pub(crate)` vs private)?
- Which design patterns (DI, singletons, middleware chains) need Rust-idiomatic replacements?
- How does data flow through the system (request lifecycle, data pipeline)?

The architecture analysis directly feeds the module mapping in Phase 2.

## Method

### Step 1: Analyze directory structure

Read the project's directory tree (depth 3-4) and classify each directory:

```
Bash: find {project_root} -type d -maxdepth 4 \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/vendor/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/venv/*' \
  -not -path '*/.venv/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*'
```

For EACH directory:
- **Path**: directory path
- **File count**: number of source files
- **Purpose**: what this directory contains (inferred from name and contents)
- **Layer**: which architectural layer it belongs to

### Step 2: Identify the architectural pattern

Determine which high-level architecture the project follows:

| Pattern | Signals | Rust Mapping |
|---------|---------|-------------|
| **Layered (MVC/3-tier)** | `controllers/`, `services/`, `models/`, `routes/` directories | Module hierarchy with clear dependency direction |
| **Hexagonal / Clean** | `domain/`, `application/`, `infrastructure/`, `ports/`, `adapters/` | Trait-based boundaries, dependency inversion |
| **Modular / Feature-based** | `features/user/`, `features/order/`, `modules/` | Workspace crates per feature |
| **Microservices** | Multiple `cmd/`, `services/`, separate `main.go` per service | Workspace with binary crates |
| **Monolithic** | Everything in `src/` with minimal structure | Single crate with module tree |
| **Plugin / Extension** | `plugins/`, `extensions/`, dynamic loading | Trait objects + `libloading` or compile-time features |
| **Event-driven** | `events/`, `handlers/`, `listeners/`, message queue integration | Channel-based or actor model |
| **CQRS** | `commands/`, `queries/`, separate read/write models | Separate command/query module trees |

### Step 3: Map module boundaries

For EACH top-level module/directory, analyze:

#### A. Module Identity
- **Path**: directory path
- **Name**: module name as used in imports
- **Purpose**: what this module is responsible for (single-sentence)
- **File count**: number of source files
- **Lines of code**: approximate LoC

#### B. Public API Surface

List EVERY exported function, class, type, and constant from this module:

**TypeScript**: grep for `export` statements
```
Grep: ^export\s+(default\s+)?(function|class|interface|type|enum|const|let|var)\s+\w+
Grep: ^export\s+\{
Grep: ^module\.exports
```

**Python**: check `__init__.py` and `__all__`
```
Grep: ^__all__\s*=
Read: __init__.py for explicit imports
```

**Go**: exported symbols are capitalized
```
Grep: ^func\s+[A-Z]\w+\(           (exported functions)
Grep: ^type\s+[A-Z]\w+\s+          (exported types)
Grep: ^var\s+[A-Z]\w+|^const\s+[A-Z]\w+  (exported vars/consts)
```

For EACH exported item, record:
- Name
- Kind (function, class, type, constant)
- Used by (which other modules import it)

#### C. Internal Dependencies

For EACH module, list what other project modules it imports:

```
Grep: import.*from\s+['"]\.\.?/     (TypeScript relative imports)
Grep: from\s+\w+\.\w+\s+import      (Python intra-package imports)
Grep: "<module_path>/internal/"      (Go internal packages)
```

Record as directed edges: `ModuleA -> ModuleB` means A imports from B.

#### D. External Dependencies

List which third-party packages this module imports (reference dependency IDs from guide 04).

### Step 4: Build the module dependency graph

Create a directed graph of internal module dependencies:

```
Module A -> Module B (imports: TypeX, functionY)
Module A -> Module C (imports: ServiceZ)
Module B -> Module D (imports: ModelW)
Module C -> Module D (imports: ModelW, ModelV)
```

Identify:
- **Leaf modules**: modules with no internal dependencies (migrate first)
- **Root modules**: modules that nothing depends on (entry points, usually migrate last)
- **Highly coupled modules**: modules with many bidirectional dependencies (may need redesign)
- **Circular dependencies**: A -> B -> C -> A (must be broken for Rust)

### Step 5: Identify design patterns

Grep for and classify design patterns used in the codebase:

#### Dependency Injection
```
Grep: @Injectable|@Inject|constructor\(private\s+     (TS/NestJS)
Grep: Depends\(|dependency_injector|inject\.            (Python/FastAPI)
Grep: wire\.Build|fx\.New|dig\.                         (Go/Wire/Fx)
```

Rust mapping: Constructor injection with explicit parameters, or trait objects for runtime DI.

#### Singleton / Global State
```
Grep: getInstance|\.instance\b                          (singleton pattern)
Grep: global\s+\w+|module\.exports\.\w+\s*=             (global mutable state)
Grep: var\s+\w+\s+\*\w+\s*//.*singleton                 (Go package-level vars)
Grep: sync\.Once|once\.Do                               (Go once initialization)
```

Rust mapping: `OnceCell`/`LazyLock` for lazy statics, or pass state explicitly.

#### Factory Pattern
```
Grep: create\w+|make\w+|new\w+|Factory                  (factory functions/classes)
Grep: func\s+New\w+\(                                    (Go constructor convention)
```

Rust mapping: `::new()` constructor or builder pattern.

#### Observer / Event
```
Grep: EventEmitter|addEventListener|\.on\(|\.emit\(      (event pattern)
Grep: @EventHandler|@OnEvent                              (decorator-based events)
Grep: Signal|Slot|subscribe|publish                       (pub-sub)
```

Rust mapping: Channel-based pub-sub or callback traits.

#### Middleware / Chain of Responsibility
```
Grep: app\.use\(|router\.use\(                            (Express middleware)
Grep: @app\.middleware|middleware\s*=                      (Python middleware)
Grep: func.*Handler.*http\.Handler|Use\(                  (Go middleware)
```

Rust mapping: Tower layers/services, or axum middleware.

#### Repository / Data Access
```
Grep: Repository|DAO|DataAccess                           (repository pattern)
Grep: \.findOne|\.findMany|\.create|\.update|\.delete     (CRUD methods)
Grep: @Repository|@Entity                                 (ORM decorators)
```

Rust mapping: Trait-based repositories with sqlx/diesel implementations.

#### Builder Pattern
```
Grep: \.set\w+\(|\.with\w+\(|Builder\b                   (builder methods)
Grep: \.build\(\)                                         (build finalization)
```

Rust mapping: Direct builder pattern (Rust's builder pattern is similar).

#### Strategy / Policy
```
Grep: Strategy|Policy|interface\s+\w+Strategy              (strategy interfaces)
Grep: switch.*strategy|case.*strategy                      (strategy selection)
```

Rust mapping: Trait objects or enum dispatch.

### Step 6: Analyze data flow

Trace the primary data flow through the application (e.g., HTTP request lifecycle):

1. **Entry**: where does data enter the system?
2. **Validation**: where is input validated?
3. **Processing**: what business logic transforms it?
4. **Persistence**: where is it stored?
5. **Response**: where is the output constructed?

Document the flow for the 3-5 most important paths through the system.

### Step 7: Identify circular dependencies

Check for circular module dependencies that must be broken:

```
A -> B -> A                    (direct circular)
A -> B -> C -> A               (transitive circular)
```

For each cycle found:
- List the modules in the cycle
- What imports create the cycle
- Suggested approach to break it (extract shared types, use traits, reorganize modules)

### Step 8: Organize output

## Template

```markdown
# Architecture Pattern Analysis

Generated: {date}
Source: {project_path}

## Architecture Summary

| Aspect | Value |
|--------|-------|
| Primary pattern | {Layered / Hexagonal / Modular / Monolithic / ...} |
| Module count | {N} top-level modules |
| Entry points | {N} ({types}) |
| Dependency direction | {top-down / mixed / circular} |
| Rust project structure | {single crate / workspace with N crates} |

## Directory Structure (ASCII)

```
{project_name}/
├── src/                    # [{layer}] {purpose}
│   ├── controllers/        # [{layer}] {purpose} ({N} files)
│   ├── services/           # [{layer}] {purpose} ({N} files)
│   ├── models/             # [{layer}] {purpose} ({N} files)
│   ├── middleware/          # [{layer}] {purpose} ({N} files)
│   ├── utils/              # [{layer}] {purpose} ({N} files)
│   └── config/             # [{layer}] {purpose} ({N} files)
├── tests/                  # Test files ({N} files)
└── scripts/                # Build/deploy scripts ({N} files)
```

{Annotate each directory with its layer and purpose.}

## Module Inventory

### MOD-{nn}: {module_name}

- **Path**: `{directory_path}/`
- **Layer**: {Presentation / Application / Domain / Infrastructure / Utility}
- **Purpose**: {single-sentence description}
- **Files**: {N} source files
- **Lines**: ~{N} LoC

**Public API**:

| Export | Kind | Used by modules |
|--------|------|----------------|
| {UserController} | class | {routes} |
| {createUser} | function | {api, tests} |
| {UserDTO} | type | {controllers, services} |
| {USER_ROLES} | constant | {auth, services} |
| ... | | |

**Internal dependencies** (this module imports from):

| Module | What's imported | Import count |
|--------|----------------|-------------|
| models | User, UserDTO | 5 |
| services | UserService | 3 |
| utils | validateEmail | 1 |

**External dependencies** (third-party):

| Package | What's imported |
|---------|----------------|
| express | Router, Request, Response |
| zod | z |

**Rust module mapping (preliminary)**:
- **Crate**: {crate name, or "same workspace crate"}
- **Module path**: `src/{module_path}/mod.rs`
- **Visibility**: `pub` / `pub(crate)` / private

---

{Repeat for EVERY module. Include even small utility modules.}

## Module Dependency Graph (ASCII)

```
┌──────────────┐     ┌──────────────┐
│   routes     │────>│  controllers │
└──────────────┘     └──────┬───────┘
                            │
                            v
                     ┌──────────────┐
                     │   services   │
                     └──────┬───────┘
                            │
                     ┌──────┴───────┐
                     v              v
              ┌───────────┐  ┌───────────┐
              │   models  │  │   repos   │
              └───────────┘  └───────────┘
```

{Show the actual dependency relationships. Arrow means "imports from".}

## Module Dependency Matrix

| Module | routes | controllers | services | models | repos | utils | config |
|--------|--------|-------------|----------|--------|-------|-------|--------|
| routes | - | imports | - | - | - | - | - |
| controllers | - | - | imports | imports | - | imports | - |
| services | - | - | - | imports | imports | imports | imports |
| models | - | - | - | - | - | - | - |
| repos | - | - | - | imports | - | - | imports |
| utils | - | - | - | - | - | - | - |
| config | - | - | - | - | - | - | - |

{Leaf modules (no dependencies): models, utils, config -> migrate first.}

## Dependency Ordering (Migration Sequence)

1. **Tier 0 (leaf modules, no internal deps)**: {module1, module2, module3}
2. **Tier 1 (depends only on Tier 0)**: {module4, module5}
3. **Tier 2 (depends on Tier 0-1)**: {module6}
4. **Tier 3 (depends on Tier 0-2)**: {module7, module8}
5. **Tier N (entry points)**: {module9}

## Circular Dependencies

{If none found, state "No circular dependencies detected."}

### Cycle {n}: {module_a} <-> {module_b}

- **Path**: {module_a} -> {module_b} -> {module_a}
- **Cause**: {module_a imports TypeX from module_b, module_b imports FuncY from module_a}
- **Break strategy**: {extract shared types into new module / use trait abstraction / reorganize}

## Design Patterns

### DP-{nn}: {Pattern Name}

- **Pattern**: {Singleton / Factory / Observer / Middleware / Repository / DI / ...}
- **Locations**:
  | File | Line | Implementation |
  |------|------|----------------|
  | [{path}:{line}](../{path}#L{line}) | {line} | {brief description} |
  | ... | | |
- **Rust equivalent**: {how this pattern maps to idiomatic Rust}
- **Migration complexity**: {Low / Medium / High}

---

{Repeat for EVERY design pattern instance found.}

## Data Flow Paths

### Flow {n}: {description, e.g., "Create User Request"}

```
1. [routes/users.ts:15]     POST /api/users         -- Route handler
2. [middleware/auth.ts:8]    authenticate()           -- JWT verification
3. [middleware/validate.ts:5] validate(CreateUserDTO) -- Input validation
4. [controllers/user.ts:22]  UserController.create()  -- Controller logic
5. [services/user.ts:45]     UserService.create()     -- Business logic
6. [repos/user.ts:30]        UserRepo.save()          -- Database INSERT
7. [services/email.ts:12]    EmailService.sendWelcome() -- Side effect
8. [controllers/user.ts:35]  return 201 + UserDTO     -- Response
```

**Rust equivalent flow**: {how this maps to axum handler -> service -> repo pattern}

---

{Repeat for 3-5 primary data flow paths.}

## Shared State Analysis

| State | Location | Scope | Pattern | Rust Mapping |
|-------|----------|-------|---------|-------------|
| DB connection pool | app.ts:10 | Global | Singleton | `Arc<Pool>` in app state |
| Config | config/index.ts | Global | Module export | `OnceCell<Config>` or explicit passing |
| Cache client | cache.ts:5 | Global | Singleton | `Arc<RedisClient>` in app state |
| Request context | middleware | Per-request | Context/locals | Axum extractors |

## Rust Project Structure Recommendation

Based on the architecture analysis:

```
{project_name}/
├── Cargo.toml                    # Workspace root (if multi-crate)
├── crates/
│   ├── {crate1}/                # {purpose}
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       └── {modules}
│   ├── {crate2}/                # {purpose}
│   └── {crate3}/                # {purpose}
└── src/                          # Binary crate (if single entry point)
    └── main.rs
```

**Rationale**: {why this structure was chosen}
```

## Completeness Check

- [ ] Every directory with source files is classified by layer and purpose
- [ ] Every module's public API is enumerated (every export listed, not "exports N items")
- [ ] Every module's internal dependencies are listed as directed edges
- [ ] Every module's external dependencies are listed
- [ ] The module dependency graph is visualized (ASCII)
- [ ] Circular dependencies are identified with break strategies
- [ ] Every design pattern instance is cataloged with location and Rust mapping
- [ ] Data flow paths are traced for major operations
- [ ] Shared state instances are identified with Rust mapping
- [ ] Migration ordering (tier-based) is provided
- [ ] Rust project structure recommendation is given with rationale
- [ ] No modules are summarized as "and several utility modules"
