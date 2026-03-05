# 04 - Dependency Tree Analysis

**Output**: `.migration-plan/analysis/dependency-tree.md`

## Purpose

Catalog every external dependency the project uses, what it does, and where it is imported. This directly feeds Phase 2's dependency mapping, where each source package gets a concrete Rust crate recommendation. Without knowing exactly which dependencies are used and how, the migration plan cannot estimate effort or identify ecosystem gaps.

Key concerns for Rust migration:
- Some dependencies have direct Rust equivalents (express -> axum, requests -> reqwest)
- Some have no equivalent and require significant reimplementation
- Dev dependencies (test frameworks, linters) are replaced by Rust's built-in tooling
- Transitive dependencies may pull in large ecosystems that simplify in Rust
- Native/C bindings dependencies may work better or worse in Rust

## Method

### Step 1: Read the dependency manifest

Read the primary dependency file to get the complete list.

**TypeScript/JavaScript** - Read `package.json`:
```json
{
  "dependencies": { ... },
  "devDependencies": { ... },
  "peerDependencies": { ... },
  "optionalDependencies": { ... }
}
```

Also check:
- `package-lock.json` or `yarn.lock` or `pnpm-lock.yaml` (for exact versions)
- Monorepo: read each workspace's `package.json`
- `.npmrc` for registry configuration

**Python** - Read dependency sources (check ALL that exist):
```
pyproject.toml:  [project.dependencies] and [project.optional-dependencies]
requirements.txt: direct pip format
requirements-dev.txt: dev dependencies
Pipfile: [packages] and [dev-packages]
setup.py: install_requires and extras_require
setup.cfg: [options] install_requires
poetry.lock: exact versions (if poetry)
```

**Go** - Read `go.mod`:
```
require (
    module/path v1.2.3
    module/path v0.4.5 // indirect
)

replace (
    module/path => ../local/path
    module/path => github.com/fork/path v1.2.3
)
```

Also read `go.sum` for the complete transitive dependency list.

### Step 2: Classify each dependency

For EACH dependency found in the manifest, determine its category:

| Category | Description | Examples |
|----------|-------------|---------|
| **Runtime-Core** | Essential for the app to function | express, fastapi, gin |
| **Runtime-Data** | Database, cache, message queue clients | pg, redis, sqlalchemy |
| **Runtime-HTTP** | HTTP clients, API integrations | axios, requests, net/http |
| **Runtime-Auth** | Authentication and authorization | passport, pyjwt, jwt-go |
| **Runtime-Util** | Utility libraries | lodash, pydantic, cobra |
| **Runtime-Logging** | Logging and observability | winston, structlog, zap |
| **Runtime-Validation** | Input validation | joi, zod, marshmallow |
| **Runtime-Serialization** | Data serialization | class-transformer, msgpack |
| **Dev-Testing** | Test frameworks and utilities | jest, pytest, testify |
| **Dev-Linting** | Code quality tools | eslint, flake8, golangci-lint |
| **Dev-Build** | Build and compilation tools | typescript, webpack, esbuild |
| **Dev-Types** | Type definitions only | @types/node, @types/express |
| **Dev-Other** | Other dev tools | nodemon, pre-commit, air |

### Step 3: Find usage sites for each dependency

For EACH dependency, grep for its imports to understand HOW it is used:

**TypeScript/JavaScript**:
```
Grep: import.*from\s+['"]<package_name>['"]
Grep: import.*from\s+['"]<package_name>/
Grep: require\(['"]<package_name>['"]\)
Grep: require\(['"]<package_name>/
```

**Python**:
```
Grep: ^import\s+<package_name>
Grep: ^from\s+<package_name>\s+import
Grep: ^from\s+<package_name>\.\w+\s+import
```

**Go**:
```
Grep: "<module_path>"
Grep: "<module_path>/
```

For each dependency, record:
- **Import count**: how many files import it
- **Import locations**: list every file that imports it
- **Specific imports**: what functions/classes/types are imported from it
- **Usage depth**: surface-level (1-2 functions) vs deep integration (throughout codebase)

### Step 4: Assess each dependency's migration impact

For EACH dependency, evaluate:

| Aspect | Assessment |
|--------|-----------|
| **Has Rust equivalent** | Yes (name it) / Partial / No |
| **API similarity** | High (drop-in) / Medium (some redesign) / Low (complete rewrite) |
| **Migration effort** | Low (swap import) / Medium (adapt API) / High (redesign integration) |
| **Blocks migration** | Yes (critical path) / No (can be done later) |

### Step 5: Identify dependency clusters

Group dependencies that work together (e.g., express + express-session + passport + cors form a "web server" cluster). These clusters often map to a single Rust crate or a small set of crates.

### Step 6: Check for native/C bindings

Identify dependencies that use native code:
```
Grep: node-gyp|napi|prebuild|binding.gyp    (Node.js native)
Grep: cffi|ctypes|pybind11|cython            (Python native)
Grep: #cgo|C\.|unsafe\.Pointer               (Go CGo)
```

These may be easier in Rust (if the C library has rust-sys bindings) or harder (if the binding is language-specific).

### Step 7: Organize output

## Template

```markdown
# Dependency Tree Analysis

Generated: {date}
Source: {project_path}

## Summary

| Metric | Count |
|--------|-------|
| Total dependencies | {N} |
| Runtime dependencies | {N} |
| Dev dependencies | {N} |
| Peer dependencies | {N} |
| Optional dependencies | {N} |
| Dependencies with Rust equivalent | {N} |
| Dependencies with no Rust equivalent | {N} |
| Dependencies with native/C bindings | {N} |

### Category Distribution

| Category | Count | Examples |
|----------|-------|---------|
| Runtime-Core | {N} | {dep1, dep2} |
| Runtime-Data | {N} | {dep1, dep2} |
| Runtime-HTTP | {N} | {dep1, dep2} |
| Runtime-Auth | {N} | {dep1, dep2} |
| Runtime-Util | {N} | {dep1, dep2} |
| Runtime-Logging | {N} | {dep1, dep2} |
| Runtime-Validation | {N} | {dep1, dep2} |
| Runtime-Serialization | {N} | {dep1, dep2} |
| Dev-Testing | {N} | {dep1, dep2} |
| Dev-Linting | {N} | {dep1, dep2} |
| Dev-Build | {N} | {dep1, dep2} |
| Dev-Types | {N} | {dep1, dep2} |
| Dev-Other | {N} | {dep1, dep2} |

## Runtime Dependencies

### D-{nnn}: {package_name}

- **Version**: {version_constraint}
- **Locked version**: {exact version from lockfile}
- **Category**: {Runtime-Core / Runtime-Data / ...}
- **Purpose**: {what it does in the project, e.g., "HTTP server framework, handles routing, middleware, request/response"}
- **Import count**: {N} files
- **Usage depth**: {Surface / Moderate / Deep}

**Import locations**:

| File | What's imported | How it's used |
|------|----------------|---------------|
| [src/app.ts:1](../src/app.ts#L1) | express, Router | Creates app instance, defines routes |
| [src/middleware/auth.ts:2](../src/middleware/auth.ts#L2) | Request, Response, NextFunction | Types for middleware signature |
| [src/routes/users.ts:1](../src/routes/users.ts#L1) | Router | Route definitions |
| ... | | |

**Specific APIs used**:
- `express()` -- app creation
- `app.use()` -- middleware registration
- `Router()` -- route grouping
- `req.body`, `req.params`, `req.query` -- request data access
- `res.json()`, `res.status()` -- response building

**Rust equivalent (initial)**: {crate_name} ({version})
**API similarity**: {High / Medium / Low}
**Migration effort**: {Low / Medium / High}
**Notes**: {any specific migration concerns}

---

{Repeat for EVERY runtime dependency. Do not skip any.}

### D-{nnn}: {package_name}
{Same structure as above}

## Dev Dependencies

### DD-{nnn}: {package_name}

- **Version**: {version_constraint}
- **Category**: {Dev-Testing / Dev-Linting / Dev-Build / Dev-Types / Dev-Other}
- **Purpose**: {what it does}
- **Rust replacement**: {cargo built-in / specific tool / not needed}
- **Notes**: {e.g., "ESLint is replaced by clippy, Prettier by rustfmt"}

---

{Repeat for EVERY dev dependency. These can be briefer since they don't carry into Rust.}

## Peer / Optional Dependencies

### PD-{nn}: {package_name}

- **Version**: {version_constraint}
- **Type**: {peer / optional}
- **Purpose**: {why it's peer/optional}
- **Used when**: {condition for usage}
- **Rust equivalent**: {crate or feature flag}

---

{Repeat for each.}

## Dependency Clusters

### Cluster {n}: {name, e.g., "Web Server Stack"}

| Dependency | Role in cluster |
|-----------|----------------|
| express | HTTP framework |
| cors | CORS middleware |
| helmet | Security headers |
| express-session | Session management |
| passport | Authentication |

**Rust equivalent cluster**: {e.g., "axum + tower-http (cors, headers) + axum-sessions + custom auth middleware"}
**Migration approach**: {migrate as a unit / split / redesign}

---

{Repeat for each cluster.}

## Native / C Binding Dependencies

| # | Dependency | Binding Type | What it wraps | Rust equivalent |
|---|-----------|-------------|---------------|-----------------|
| 1 | bcrypt | node-gyp | libcrypt | bcrypt crate (pure Rust) |
| 2 | sharp | prebuild | libvips | image crate |
| ... | | | | |

{Omit this section if no native dependencies found.}

## Replace Directives (Go only)

| # | Original Module | Replacement | Reason |
|---|----------------|-------------|---------|
| 1 | {module} | {replacement} | {why replaced} |

{Omit this section if not a Go project or no replace directives.}

## Transitive Dependency Highlights

List notable transitive dependencies that may affect migration decisions:

| Dependency | Pulled in by | Why it matters |
|-----------|-------------|----------------|
| {transitive_dep} | {parent_dep} | {e.g., "Pulls in OpenSSL, Rust can use rustls instead"} |

{Only include transitive deps that have migration implications. Not an exhaustive list.}

## Migration Risk by Dependency

| Risk Level | Dependencies | Reason |
|-----------|-------------|---------|
| **No Risk** | {dep1, dep2} | Direct Rust equivalent exists with similar API |
| **Low Risk** | {dep1, dep2} | Rust equivalent exists but API differs |
| **Medium Risk** | {dep1, dep2} | Partial Rust equivalent, some features missing |
| **High Risk** | {dep1, dep2} | No Rust equivalent, requires reimplementation |
| **Blocking** | {dep1, dep2} | Critical functionality with no Rust path identified |
```

## Completeness Check

- [ ] Every dependency from the manifest is listed (not "and 15 more utility packages")
- [ ] Every runtime dependency has import locations and specific APIs used
- [ ] Every dependency has a category classification
- [ ] Every runtime dependency has an initial Rust equivalent assessment
- [ ] Dev dependencies are listed (can be brief but must be complete)
- [ ] Dependency clusters are identified for related packages
- [ ] Native/C binding dependencies are flagged
- [ ] Usage depth (surface vs deep) is assessed for each runtime dependency
- [ ] Migration risk level is assigned to each dependency
- [ ] Replace directives are listed (Go projects)
- [ ] No dependencies are omitted or summarized as "similar packages"
