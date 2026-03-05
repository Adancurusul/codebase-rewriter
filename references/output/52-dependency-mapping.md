# 52 - Dependency Mapping

**Output**: `.migration-plan/mappings/dependency-mapping.md`

## Purpose

Map every source language dependency (npm package, pip package, Go module) to its Rust crate equivalent. This is the ecosystem translation layer -- for each library the source project uses, this document identifies the Rust replacement, evaluates confidence in the mapping, documents API differences, and flags cases where no equivalent exists and custom implementation is required.

This document directly feeds the `Cargo.toml` generation. Every crate listed here becomes a dependency in the workspace or individual crate manifests.

## Template

```markdown
# Dependency Mapping

Source: {project_name}
Generated: {date}
Source Language: {TypeScript / Python / Go}

## Summary

| Metric | Count |
|--------|-------|
| Total Direct Dependencies | {N} |
| Total Dev Dependencies | {N} |
| Mapped (HIGH confidence) | {N} ({N}%) |
| Mapped (MEDIUM confidence) | {N} ({N}%) |
| Mapped (LOW confidence) | {N} ({N}%) |
| No Equivalent | {N} ({N}%) |
| Built-in (no crate needed) | {N} ({N}%) |

### Confidence Distribution

```text
HIGH:          {bar} {N}%
MEDIUM:        {bar} {N}%
LOW:           {bar} {N}%
NO_EQUIVALENT: {bar} {N}%
```

## Production Dependencies

### {Category: e.g., HTTP Server}

| # | Source Package | Version | Usage Locations | Purpose | Rust Crate | Crate Version | Confidence | Migration Effort |
|---|--------------|---------|-----------------|---------|------------|---------------|------------|-----------------|
| 1 | {package} | {ver} | [{file}:{line}](../src/{file}#L{line}), [{file}:{line}](../src/{file}#L{line}) | {purpose} | `{crate}` | {ver} | {HIGH/MEDIUM/LOW} | {Low/Medium/High} |
| 2 | {package} | {ver} | [{file}:{line}](../src/{file}#L{line}) | {purpose} | `{crate}` | {ver} | {HIGH/MEDIUM/LOW} | {Low/Medium/High} |

**API Mapping Notes**:

```
{source_package} -> {rust_crate}:
  - {source_api}  ->  {rust_api}
  - {source_api}  ->  {rust_api}
  - {source_api}  ->  {rust_api} (behavioral difference: {note})
```

---

### {Category: e.g., Database}

| # | Source Package | Version | Usage Locations | Purpose | Rust Crate | Crate Version | Confidence | Migration Effort |
|---|--------------|---------|-----------------|---------|------------|---------------|------------|-----------------|
| {N} | {package} | {ver} | [{file}:{line}](../src/{file}#L{line}) | {purpose} | `{crate}` | {ver} | {HIGH/MEDIUM/LOW} | {Low/Medium/High} |

**API Mapping Notes**:

```
{source_package} -> {rust_crate}:
  - {source_api}  ->  {rust_api}
```

---

{Repeat for each category: Serialization, Validation, Authentication, Logging, Testing, CLI, Date/Time, UUID, Crypto, Async, Config, File System, Email, Caching, WebSocket, Task Queue, etc.}

---

## Dev Dependencies

| # | Source Package | Version | Purpose | Rust Equivalent | Notes |
|---|--------------|---------|---------|-----------------|-------|
| 1 | {package} | {ver} | {purpose} | `{crate}` or Built-in | {notes} |
| 2 | {package} | {ver} | {purpose} | `{crate}` or Built-in | {notes} |
| ... | | | | | |

## No-Equivalent Dependencies

These source dependencies have no Rust crate equivalent and require custom implementation or architectural changes.

| # | Source Package | Version | Purpose | Usage Locations | Rust Strategy | Effort |
|---|--------------|---------|---------|-----------------|---------------|--------|
| 1 | {package} | {ver} | {purpose} | [{file}:{line}](../src/{file}#L{line}) | {strategy: manual implementation / architectural change / removal} | {High/Very High} |
| 2 | {package} | {ver} | {purpose} | [{file}:{line}](../src/{file}#L{line}) | {strategy} | {effort} |

### Detailed Strategies for No-Equivalent Dependencies

#### {package_name}: {purpose}

**Current usage**: {describe how the source project uses this dependency}

**Why no equivalent**: {explain why no Rust crate covers this functionality}

**Proposed Rust approach**:
```rust
// {Description of the custom implementation approach}
{code_sketch}
```

**Estimated effort**: {N rounds}

---

{Repeat for each no-equivalent dependency}

---

## Built-in Replacements

These source dependencies are replaced by Rust standard library features or language-level capabilities.

| # | Source Package | Purpose | Rust Built-in | Notes |
|---|--------------|---------|---------------|-------|
| 1 | {package} | {purpose} | `{std::module}` | {notes} |
| 2 | {package} | {purpose} | Language feature | {notes, e.g., "pattern matching replaces lodash.get"} |

## Transitive Dependency Risk

| Source Package | Transitive Count | Known Vulnerabilities | Rust Equivalent Transitive Count | Risk |
|---------------|-----------------|----------------------|----------------------------------|------|
| {package} | {N} | {N critical, N high} | {N} | {Low/Medium/High} |
| {package} | {N} | {N critical, N high} | {N} | {Low/Medium/High} |

## Generated Cargo.toml

### Workspace Dependencies

```toml
[workspace.dependencies]
# {Category}
{crate_name} = "{version}"
{crate_name} = { version = "{version}", features = ["{feature}"] }

# {Category}
{crate_name} = "{version}"

# ... grouped by category
```

### Per-Crate Dependencies

#### crates/{crate_name}/Cargo.toml

```toml
[dependencies]
{dep} = { workspace = true }
{dep} = { workspace = true }

[dev-dependencies]
{dep} = { workspace = true }
```

#### crates/{crate_name}/Cargo.toml

```toml
[dependencies]
{dep} = { workspace = true }
{other_crate} = { path = "../{other_crate}" }

[dev-dependencies]
{dep} = { workspace = true }
```

{Repeat for each crate in the workspace}

## Version Pinning Notes

| Crate | Pinned Version | Reason |
|-------|---------------|--------|
| {crate} | {version} | {e.g., "axum 0.8 requires tokio 1.x and tower 0.5"} |
| {crate} | {version} | {e.g., "sqlx 0.8 requires compile-time DB connection for query checking"} |
```

## Instructions

When producing this document:

1. **Read `analysis/dependency-tree.md`** for the complete list of source dependencies with versions and usage locations.
2. **Read the crate recommendation guide** (`references/mapping/common/15-crate-recommendations.md`) for standard mappings.
3. **Every direct dependency must be listed**. Do not skip dependencies. If a dependency is used in only one file, it still gets a full entry.
4. **Usage locations must be specific**: include file:line references showing where the dependency is imported/used. List up to 5 locations; if more, show 5 and note "(+N more)".
5. **Group dependencies by category** (HTTP, Database, Auth, Logging, etc.) for readability.
6. **API Mapping Notes** are required for any dependency rated MEDIUM or lower. Show the key API differences between the source package and the Rust crate.
7. **No-Equivalent Dependencies** must each have a detailed strategy section with a code sketch showing the Rust approach.
8. **Generated Cargo.toml** must be compilable. Use workspace dependencies for crates shared across multiple workspace members.
9. **Feature flags must be specified** where needed (e.g., `sqlx` features for database driver, UUID version, chrono serde support).
10. **Confidence levels must be accurate**: HIGH means the Rust crate is a near drop-in replacement. MEDIUM means significant API differences. LOW means partial coverage. NO_EQUIVALENT means custom code required.
11. Write in the same language the user used to invoke the skill.

## Example

```markdown
# Dependency Mapping

Source: taskflow-api
Generated: 2026-03-05
Source Language: TypeScript

## Summary

| Metric | Count |
|--------|-------|
| Total Direct Dependencies | 34 |
| Total Dev Dependencies | 12 |
| Mapped (HIGH confidence) | 22 (65%) |
| Mapped (MEDIUM confidence) | 7 (21%) |
| Mapped (LOW confidence) | 2 (6%) |
| No Equivalent | 1 (3%) |
| Built-in (no crate needed) | 2 (6%) |

## Production Dependencies

### HTTP Server

| # | Source Package | Version | Usage Locations | Purpose | Rust Crate | Crate Version | Confidence | Migration Effort |
|---|--------------|---------|-----------------|---------|------------|---------------|------------|-----------------|
| 1 | express | 4.18.2 | [app.ts:3](../src/app.ts#L3), [routes/index.ts:1](../src/routes/index.ts#L1) | HTTP server and routing | `axum` | 0.8 | HIGH | Medium |
| 2 | cors | 2.8.5 | [app.ts:12](../src/app.ts#L12) | CORS middleware | `tower-http` | 0.6 | HIGH | Low |
| 3 | helmet | 7.1.0 | [app.ts:14](../src/app.ts#L14) | Security headers | `tower-http` | 0.6 | MEDIUM | Low |
| 4 | express-rate-limit | 7.1.4 | [middleware/rate-limit.ts:1](../src/middleware/rate-limit.ts#L1) | Rate limiting | `tower-governor` | 0.5 | HIGH | Low |

**API Mapping Notes**:

```
express -> axum:
  - app.get("/path", handler)       ->  Router::new().route("/path", get(handler))
  - app.use(middleware)             ->  Router::new().layer(middleware)
  - req.params.id                   ->  Path(id): Path<Uuid>
  - req.body                        ->  Json(body): Json<T>
  - req.query                       ->  Query(params): Query<T>
  - res.status(200).json(data)      ->  Ok(Json(data))  (return type)
  - next()                          ->  Tower Service::call (behavioral difference: middleware is layered, not sequential)
```

### Database / ORM

| # | Source Package | Version | Usage Locations | Purpose | Rust Crate | Crate Version | Confidence | Migration Effort |
|---|--------------|---------|-----------------|---------|------------|---------------|------------|-----------------|
| 5 | @prisma/client | 5.8.1 | [db/prisma.ts:1](../src/db/prisma.ts#L1), [services/task-service.ts:2](../src/services/task-service.ts#L2), (+6 more) | ORM for PostgreSQL | `sqlx` | 0.8 | MEDIUM | High |

**API Mapping Notes**:

```
@prisma/client -> sqlx:
  - prisma.user.findUnique({ where: { id } })
      -> sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1").bind(id).fetch_optional(pool)
  - prisma.user.create({ data })
      -> sqlx::query("INSERT INTO users (id, name, email) VALUES ($1, $2, $3)").bind(...)
  - prisma.user.findMany({ where, orderBy, take, skip })
      -> Manual SQL with WHERE, ORDER BY, LIMIT, OFFSET
  - prisma.$transaction([...])
      -> pool.begin() / tx.commit()
  BEHAVIORAL DIFFERENCE: No auto-generated migrations. Use sqlx-migrate or refinery.
  BEHAVIORAL DIFFERENCE: No relation loading. Must write JOINs manually.
```

### Authentication

| # | Source Package | Version | Usage Locations | Purpose | Rust Crate | Crate Version | Confidence | Migration Effort |
|---|--------------|---------|-----------------|---------|------------|---------------|------------|-----------------|
| 6 | jsonwebtoken | 9.0.2 | [auth/jwt.ts:1](../src/lib/auth/jwt.ts#L1) | JWT sign/verify | `jsonwebtoken` | 9 | HIGH | Low |
| 7 | bcrypt | 5.1.1 | [auth/password.ts:1](../src/lib/auth/password.ts#L1) | Password hashing | `argon2` | 0.5 | HIGH | Low |

## No-Equivalent Dependencies

| # | Source Package | Version | Purpose | Usage Locations | Rust Strategy | Effort |
|---|--------------|---------|---------|-----------------|---------------|--------|
| 1 | prisma-generator | 5.8.1 | Schema-first ORM code generation | [schema.prisma](../prisma/schema.prisma) | Replace with sqlx compile-time checked queries + manual struct definitions | High |

### Detailed Strategies for No-Equivalent Dependencies

#### prisma-generator: Schema-first code generation

**Current usage**: Prisma reads `schema.prisma` to generate TypeScript types and a query client. The generated client provides type-safe queries with auto-completion for all models and relations.

**Why no equivalent**: No Rust ORM provides Prisma's level of schema-first code generation with relation auto-loading. sqlx provides compile-time SQL checking but requires manual struct definitions and raw SQL queries.

**Proposed Rust approach**:
```rust
// 1. Define structs manually (extracted from Prisma schema)
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
}

// 2. Write queries with compile-time checking
pub async fn find_user(pool: &PgPool, id: Uuid) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as!(User, "SELECT * FROM users WHERE id = $1", id)
        .fetch_optional(pool)
        .await
}

// 3. Use sqlx-migrate for schema migrations (replaces prisma migrate)
```

**Estimated effort**: 3 rounds (struct definitions + query rewrite + migration setup)

## Built-in Replacements

| # | Source Package | Purpose | Rust Built-in | Notes |
|---|--------------|---------|---------------|-------|
| 1 | lodash | Utility functions (map, filter, groupBy) | `Iterator` trait methods | `.map()`, `.filter()`, `.fold()`, `.group_by()` (itertools) |
| 2 | path (Node.js) | File path manipulation | `std::path::PathBuf` | Platform-aware path handling is built-in |

## Generated Cargo.toml

### Workspace Dependencies

```toml
[workspace.dependencies]
# Web
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace"] }
tower-governor = "0.5"

# Database
sqlx = { version = "0.8", features = ["runtime-tokio", "tls-rustls", "postgres", "uuid", "chrono"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Validation
validator = { version = "0.19", features = ["derive"] }

# Auth
jsonwebtoken = "9"
argon2 = "0.5"

# Error Handling
thiserror = "2"
anyhow = "1"

# Observability
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# Utilities
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
dotenvy = "0.15"
reqwest = { version = "0.12", features = ["json"] }
regex = "1"

# Background Jobs
apalis = { version = "0.6", features = ["redis"] }

# Email
lettre = { version = "0.11", features = ["tokio1-rustls-tls"] }

# Cache
redis = { version = "0.27", features = ["tokio-comp"] }
moka = { version = "0.12", features = ["future"] }

[workspace.dev-dependencies]
tokio = { version = "1", features = ["test-util", "macros", "rt-multi-thread"] }
mockall = "0.13"
wiremock = "0.6"
pretty_assertions = "1"
axum-test = "16"
```
```

## Quality Criteria

- [ ] Every direct source dependency has a mapping entry (no dependencies omitted)
- [ ] Usage locations include file:line references (not just "used in auth module")
- [ ] Dependencies are grouped by category (HTTP, DB, Auth, Logging, etc.)
- [ ] Confidence level is assigned and accurate for every mapping
- [ ] API Mapping Notes are provided for all MEDIUM and LOW confidence mappings
- [ ] No-Equivalent dependencies each have a detailed strategy with code sketch
- [ ] Built-in replacements are identified (stdlib features that replace packages)
- [ ] Generated Cargo.toml is syntactically correct with proper feature flags
- [ ] Workspace dependencies are used for crates shared across multiple workspace members
- [ ] Per-crate Cargo.toml files reference workspace dependencies correctly
- [ ] Version numbers are current and compatible with each other
- [ ] Dev dependencies are separated from production dependencies
- [ ] Summary statistics are accurate and percentages sum to 100%
