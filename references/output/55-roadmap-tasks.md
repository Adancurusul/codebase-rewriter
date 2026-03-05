# 55 - Roadmap Tasks

**Output**: `.migration-plan/dev-workflow/roadmap.md`

## Purpose

Generate a step-by-step migration roadmap in dev-workflow compatible format. Every task must be specific enough to execute without additional design decisions -- the developer (or AI agent) reads the task description, implements it, verifies it against the criteria, and moves on.

This is the bridge between the migration plan (what to do) and the execution (doing it). The roadmap is consumed directly by dev-workflow, which expects a specific markdown format with checkboxes, round estimates, verification criteria, and dependency tracking.

The roadmap must follow a strict milestone structure: Foundation -> Core Types -> Business Logic -> API Layer -> Testing -> Deployment. Each task within a milestone has a unique numeric ID, description, round estimate with risk multiplier, verification criteria, and dependency list.

## Template

```markdown
# Migration Roadmap

Source: {project_name}
Generated: {date}
Source Language: {TypeScript / Python / Go}
Target: Rust

## Effort Summary

| Milestone | Tasks | Base Rounds | Risk Factor | Effective Rounds |
|-----------|-------|-------------|-------------|-----------------|
| M1: Foundation | {N} | {N} | {X.X} | {N} |
| M2: Core Types | {N} | {N} | {X.X} | {N} |
| M3: Business Logic | {N} | {N} | {X.X} | {N} |
| M4: API Layer | {N} | {N} | {X.X} | {N} |
| M5: Testing | {N} | {N} | {X.X} | {N} |
| M6: Deployment | {N} | {N} | {X.X} | {N} |
| **Total** | **{N}** | **{N}** | **avg {X.X}** | **{N}** |

### Rounds Calculation

```text
Effective Rounds = Base Rounds * Risk Factor

Risk Factor Guidelines:
  1.0  = Straightforward, well-understood, high-confidence crate mapping
  1.2  = Some complexity, minor unknowns
  1.3  = Moderate complexity, async patterns, medium-confidence crate mapping
  1.5  = High complexity, no direct crate equivalent, requires custom implementation
  2.0  = Very high complexity, architectural redesign needed, no precedent
```

## Milestone 1: Foundation

Setup Cargo workspace, configuration, logging, and project scaffolding.

- [ ] #1 Initialize Cargo workspace
  - Description: Create workspace root `Cargo.toml` with all member crates listed. Create directory structure for each crate with empty `lib.rs` files. Configure workspace-level dependencies, edition, and shared metadata.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: `cargo check` passes on empty workspace. All crate directories exist with `Cargo.toml` and `src/lib.rs`.
  - Dependencies: none

- [ ] #2 Set up configuration module
  - Description: Implement `AppConfig` struct in `crates/{core}/src/config.rs` with all environment variables from the source project. Use `dotenvy` for `.env` loading and `envy` or manual `std::env::var` for deserialization. Include validation for required fields. Port `.env.example` file.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: `AppConfig::from_env()` loads all variables from `.env.example`. Missing required variables produce clear error messages. Unit test passes with test `.env` file.
  - Dependencies: #1

- [ ] #3 Set up logging and tracing
  - Description: Configure `tracing` and `tracing-subscriber` in the binary crate's `main.rs`. Support `LOG_LEVEL` environment variable. Use JSON format for production, pretty format for development. Add `#[instrument]` to one sample function to verify span propagation.
  - Rounds: 0.5 (risk 1.0, effective 0.5)
  - Verification: Application starts and emits structured log output. `LOG_LEVEL=debug` shows debug messages. `LOG_LEVEL=error` suppresses info messages.
  - Dependencies: #1, #2

- [ ] #4 Define error hierarchy
  - Description: Implement the complete error type hierarchy from `mappings/error-hierarchy.md`. Define `AppError` root enum, all per-module error enums (`AuthError`, `DbError`, `ValidationError`, etc.), all `From` implementations, and the `IntoResponse` implementation (if web service). Place in `crates/{core}/src/error.rs`.
  - Rounds: 1.5 (risk 1.2, effective 1.8)
  - Verification: All error types compile. `From` conversions work in unit tests (e.g., `AppError::from(AuthError::InvalidToken)` compiles). `IntoResponse` returns correct HTTP status codes in unit tests.
  - Dependencies: #1

{Add additional foundation tasks as needed: e.g., database connection pool setup, middleware scaffolding}

## Milestone 2: Core Types

Define all domain types, enums, and shared data structures.

- [ ] #{N} Define {domain} types
  - Description: Implement the following types from `mappings/type-mapping.md` in `crates/{crate}/src/types.rs`: {list specific type names, e.g., User, CreateUserInput, UpdateUserInput, UserRole}. Include all derive macros (`Serialize`, `Deserialize`, `sqlx::FromRow`, `Validate`), serde attributes (`rename_all`, `skip_serializing_if`), and field-level annotations. See type-mapping.md entries T-1 through T-{N}.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: `cargo check` passes. All types have correct derive macros. Serde round-trip test: serialize to JSON and deserialize back, verify field names match camelCase convention. Validate derive: invalid inputs are rejected.
  - Dependencies: #{error_task}

- [ ] #{N} Define {domain} types
  - Description: Implement {list types}. See type-mapping.md entries T-{N} through T-{N}.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Same as above. Cross-type references compile (e.g., `Task` references `User` id and `TaskStatus` enum).
  - Dependencies: #{previous_type_task}

- [ ] #{N} Define {enum_name} enums
  - Description: Implement the following enums from `mappings/type-mapping.md`: {list enums}. Include `serde(rename_all)` for wire format compatibility and `sqlx::Type` for database mapping. See type-mapping.md entries E-1 through E-{N}.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Enum serialization matches source wire format (e.g., `TaskStatus::InProgress` serializes as `"IN_PROGRESS"`). Database enum type mapping is correct.
  - Dependencies: #{workspace_task}

{Add tasks for each group of related types}

## Milestone 3: Business Logic

Implement database access layer, service layer, and core business operations.

- [ ] #{N} Implement database connection pool
  - Description: Set up `sqlx::PgPool` (or appropriate database pool) in `crates/{db}/src/pool.rs`. Configure pool size from `AppConfig`. Implement health check query. Add connection retry logic.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: Pool connects to test database. Health check query succeeds. Pool respects max_connections from config.
  - Dependencies: #{config_task}, #{type_tasks}

- [ ] #{N} Implement {entity} database queries
  - Description: Write all CRUD queries for {Entity} in `crates/{db}/src/{entity}.rs`. Replace {ORM} calls with `sqlx` compile-time checked queries. Implement: `find_by_id`, `find_all` (with pagination), `create`, `update`, `delete`. Use `sqlx::query_as!` for type-safe results. Handle `UniqueViolation` and `NotFound` via `DbError`.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Each query function compiles with `sqlx` compile-time checking. Integration test: create -> find -> update -> delete cycle passes against test database. Pagination returns correct `total` and `totalPages`.
  - Dependencies: #{pool_task}, #{type_tasks}, #{error_task}

- [ ] #{N} Implement {service_name} service
  - Description: Port {SourceServiceClass} from [{file}](../src/{file}) to `crates/{services}/src/{service}.rs`. Implement all public methods: {list methods}. Business logic must produce identical results to the source. Use database queries from `crates/{db}` and error types from `crates/{core}`.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Unit tests for each public method. Edge cases from source test suite are ported. Mock database layer using `mockall` traits.
  - Dependencies: #{db_queries_task}, #{type_tasks}, #{error_task}

{Repeat for each service}

- [ ] #{N} Implement {auth_module}
  - Description: Port authentication logic: JWT token generation/validation (using `jsonwebtoken` crate), password hashing (using `argon2`), session management. Replace {source_auth_package} with Rust equivalents. Token structure (claims) must match source format for backward compatibility.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Generated JWT tokens are valid and decodable. Password hash/verify round-trip works. Token expiration is enforced. Claims structure matches source format.
  - Dependencies: #{type_tasks}, #{error_task}, #{config_task}

{Add additional business logic tasks}

## Milestone 4: API Layer

Implement HTTP handlers, middleware, background jobs, and external integrations.

- [ ] #{N} Implement {resource} route handlers
  - Description: Port Express/FastAPI/Gin route handlers for `/{resource}` endpoints to axum handlers in `crates/{api}/src/routes/{resource}.rs`. Endpoints: {list all endpoints with HTTP methods, e.g., GET /tasks, POST /tasks, GET /tasks/:id, PUT /tasks/:id, DELETE /tasks/:id}. Use axum extractors (`Path`, `Query`, `Json`, `State`). Return types must match source API contract exactly.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: API contract test: each endpoint returns same JSON shape and status codes as source. Request validation rejects invalid input with 422.
  - Dependencies: #{service_task}, #{auth_task}, #{error_task}

- [ ] #{N} Implement auth middleware
  - Description: Create axum middleware layer that extracts JWT from `Authorization: Bearer <token>` header, validates it, and injects authenticated user into request extensions. Reject unauthenticated requests with 401. Port role-based authorization checks.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Protected routes return 401 without token. Valid token allows access. Expired token returns 401. Role-based routes return 403 for insufficient permissions.
  - Dependencies: #{auth_module_task}, #{error_task}

- [ ] #{N} Implement rate limiting middleware
  - Description: Add rate limiting using `tower-governor`. Configure rate limits from `AppConfig`. Apply to authentication endpoints and API routes with different limits.
  - Rounds: 0.5 (risk 1.0, effective 0.5)
  - Verification: Exceeding rate limit returns 429. Different endpoints have different limits. Rate limit headers are present in responses.
  - Dependencies: #{config_task}

- [ ] #{N} Implement background jobs
  - Description: Port {source_job_framework} job processors to `apalis` (or chosen Rust job framework). Jobs to port: {list jobs, e.g., email notification, report generation}. Each job must: deserialize payload, execute logic, handle errors with retries.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Job enqueue -> process cycle works. Failed jobs are retried. Job payload serialization matches source format.
  - Dependencies: #{service_tasks}, #{config_task}

{Add tasks for: email service, cache layer, WebSocket handlers, etc.}

## Milestone 5: Testing

Port test suite, add integration tests, and set up performance benchmarks.

- [ ] #{N} Port unit tests for {module}
  - Description: Rewrite unit tests from {source_test_files} as Rust `#[test]` and `#[tokio::test]` functions. Use `mockall` for mocking dependencies. Use `pretty_assertions` for readable test output. Cover all test cases from the source, plus any edge cases identified during migration.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: `cargo test -p {crate}` passes. Test count >= source test count for this module. Code coverage >= {N}% (measured with `cargo tarpaulin`).
  - Dependencies: #{implementation_task}

- [ ] #{N} Write API integration tests
  - Description: Create integration test suite using `axum-test` that tests every API endpoint with a real test database. Test complete request/response cycles including authentication, validation, error responses. Use test fixtures for database state.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: All API endpoints tested. Each status code (200, 201, 400, 401, 403, 404, 409, 422, 500) is covered. Tests run against a fresh database per test (use transactions with rollback).
  - Dependencies: all M4 tasks

- [ ] #{N} Set up performance benchmarks
  - Description: Create benchmark suite using `criterion` or k6 load tests. Benchmark critical paths: {list paths, e.g., "GET /tasks with 1000 records", "POST /tasks with validation"}. Establish baseline metrics for comparison with source implementation.
  - Rounds: {N} (risk {X.X}, effective {N})
  - Verification: Benchmarks run and produce reproducible results. p50, p95, p99 latency numbers are recorded. Memory usage is measured.
  - Dependencies: all M4 tasks

## Milestone 6: Deployment

CI/CD pipeline, containerization, and production readiness.

- [ ] #{N} Create Dockerfile
  - Description: Write multi-stage Dockerfile: stage 1 builds Rust binary with `cargo build --release`, stage 2 copies binary into minimal base image (distroless or alpine). Include health check endpoint. Configure for non-root user.
  - Rounds: 0.5 (risk 1.0, effective 0.5)
  - Verification: `docker build` succeeds. Image size < {N}MB. Container starts and responds to health check. Binary runs as non-root user.
  - Dependencies: all M4 tasks

- [ ] #{N} Set up CI pipeline
  - Description: Configure CI (GitHub Actions / GitLab CI) with: `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test`, `cargo build --release`. Add sqlx offline mode for CI (generate `sqlx-data.json`). Cache cargo registry and build artifacts.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: CI pipeline passes on a clean checkout. Clippy produces zero warnings. All tests pass. Build artifact is produced.
  - Dependencies: #{test_tasks}

- [ ] #{N} Database migration setup
  - Description: Set up database migration tooling ({sqlx-migrate / refinery}). Create migration files matching the current schema. Verify migrations produce identical schema to the source database.
  - Rounds: 1 (risk 1.2, effective 1.2)
  - Verification: `sqlx migrate run` creates all tables, indexes, and constraints. Schema diff between migrated and source database shows zero differences.
  - Dependencies: #{db_pool_task}

- [ ] #{N} Production deployment verification
  - Description: Deploy Rust version alongside source version (shadow mode or canary). Compare response bodies and status codes for identical requests. Verify no data loss or corruption. Monitor error rates and latency.
  - Rounds: 1 (risk 1.5, effective 1.5)
  - Verification: Zero response body differences for 1000+ request samples. Error rate <= source error rate. p99 latency <= target from migration plan.
  - Dependencies: all previous milestones
```

## Instructions

When producing this document:

1. **Read ALL mapping documents** (`module-mapping.md`, `type-mapping.md`, `dependency-mapping.md`, `error-hierarchy.md`) to understand every specific item that needs implementation.
2. **Task descriptions must be implementation-ready**: Name specific types, specific functions, specific files. "Implement User, Task, Team types" not "implement domain types".
3. **Every task references the mapping document** it draws from (e.g., "See type-mapping.md entries T-1 through T-8").
4. **Verification criteria must be testable**: "cargo check passes" or "unit test creates user and reads it back" -- not "code works correctly".
5. **Dependencies must use task IDs**: `Dependencies: #3, #7` -- not "depends on types being done".
6. **Risk factors must be justified**: Each task's risk factor should reflect the actual complexity discovered during analysis (async patterns, no-equivalent dependencies, high cyclomatic complexity).
7. **Rounds must be realistic**: A round is approximately one focused development session (2-4 hours for a human, 1 conversation for an AI agent). Database query porting is typically 1-2 rounds per entity. Service layer is 1-3 rounds per service. API handlers are 0.5-1 round per endpoint.
8. **The total effective rounds must match** the summary in `migration-plan.md`.
9. **Tasks must follow dev-workflow format exactly**: `- [ ] #N Task name` with indented sub-fields.
10. **Milestones must be ordered by dependency**: Foundation first, then types, then business logic, then API, then testing, then deployment. No milestone should depend on a later milestone.
11. Write in the same language the user used to invoke the skill.

## Example

```markdown
# Migration Roadmap

Source: taskflow-api
Generated: 2026-03-05
Source Language: TypeScript
Target: Rust

## Effort Summary

| Milestone | Tasks | Base Rounds | Risk Factor | Effective Rounds |
|-----------|-------|-------------|-------------|-----------------|
| M1: Foundation | 5 | 5.0 | 1.1 | 5.5 |
| M2: Core Types | 4 | 4.0 | 1.1 | 4.4 |
| M3: Business Logic | 8 | 10.0 | 1.3 | 13.0 |
| M4: API Layer | 7 | 7.5 | 1.2 | 9.0 |
| M5: Testing | 4 | 5.0 | 1.2 | 6.0 |
| M6: Deployment | 4 | 3.5 | 1.1 | 3.9 |
| **Total** | **32** | **35.0** | **avg 1.2** | **41.8** |

## Milestone 1: Foundation

- [ ] #1 Initialize Cargo workspace
  - Description: Create workspace root Cargo.toml with 6 member crates: core, db, auth, services, api, jobs. Create directory structure. Pin workspace dependencies: tokio 1, serde 1, axum 0.8, sqlx 0.8, thiserror 2, tracing 0.1, uuid 1, chrono 0.4.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: `cargo check` passes. 6 crate directories exist with Cargo.toml and src/lib.rs.
  - Dependencies: none

- [ ] #2 Set up AppConfig
  - Description: Implement AppConfig in crates/core/src/config.rs with fields: database_url (String), port (u16, default 3000), jwt_secret (String), jwt_expiration_hours (u64, default 24), redis_url (String), log_level (String, default "info"), rate_limit_rpm (u32, default 100). Use dotenvy for .env and envy for deserialization. Port .env.example.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: AppConfig::from_env() loads all 7 variables. Missing jwt_secret panics with clear message. Test with .env.example values passes.
  - Dependencies: #1

- [ ] #3 Set up tracing
  - Description: Configure tracing-subscriber in src/main.rs with EnvFilter from LOG_LEVEL. JSON format when LOG_LEVEL != "debug", pretty format for debug. Add request_id to all spans.
  - Rounds: 0.5 (risk 1.0, effective 0.5)
  - Verification: App starts with "info" log level. Setting LOG_LEVEL=debug shows debug output. JSON output is parseable.
  - Dependencies: #1, #2

- [ ] #4 Define error hierarchy
  - Description: Implement AppError, AuthError (4 variants), DbError (5 variants), ValidationError (4 variants), ExternalError (3 variants) from mappings/error-hierarchy.md. Implement 5 From conversions (sqlx::Error, serde_json::Error, std::io::Error, jsonwebtoken::Error, reqwest::Error). Implement IntoResponse for axum.
  - Rounds: 1.5 (risk 1.2, effective 1.8)
  - Verification: All From conversions compile. IntoResponse returns correct status codes (test: Auth->401, Validation->422, NotFound->404). Error display messages are human-readable.
  - Dependencies: #1

- [ ] #5 Set up database connection pool
  - Description: Create PgPool in crates/db/src/pool.rs. Configure max_connections=10 from AppConfig.database_url. Add connect_with_retry (3 attempts, 2s backoff). Health check: SELECT 1.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: Pool connects to PostgreSQL. Health check returns Ok. Retry logic handles transient failures (test with wrong URL, then correct URL).
  - Dependencies: #1, #2

## Milestone 2: Core Types

- [ ] #6 Define User types (T-1, T-2, T-3, T-8)
  - Description: Implement in crates/core/src/types.rs: User (11 fields, Serialize+Deserialize+FromRow), CreateUserInput (4 fields, Deserialize+Validate), UpdateUserInput (3 optional fields, Deserialize+Validate), Role enum (Admin/Manager/Member, Serialize+Deserialize+sqlx::Type). See type-mapping.md T-1, T-2, T-3, E-3.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: cargo check. Serde round-trip: User serializes to camelCase JSON and deserializes back. Role::Member serializes as "MEMBER". CreateUserInput validation rejects empty name, invalid email, short password.
  - Dependencies: #4

- [ ] #7 Define Task types (T-4, T-5, T-6, E-1, E-2)
  - Description: Implement: Task (12 fields including assigned_to: Option<Uuid>), CreateTaskInput (5 fields with validation), UpdateTaskInput (4 optional fields), TaskStatus enum (5 variants), Priority enum (4 variants: Low/Medium/High/Critical). See type-mapping.md T-4 through T-6, E-1, E-2.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: Task references User id (Uuid) and TaskStatus/Priority enums. TaskStatus::InProgress serializes as "IN_PROGRESS". Priority::High serializes as "HIGH". CreateTaskInput validates title length (1-200).
  - Dependencies: #6

- [ ] #8 Define Team and Project types (T-9 through T-14)
  - Description: Implement: Team (6 fields), CreateTeamInput (2 fields), Project (8 fields including team_id: Uuid), CreateProjectInput (3 fields), TeamMember (join table struct), ProjectStatus enum (4 variants). See type-mapping.md T-9 through T-14, E-4.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: Project references Team id. TeamMember references both User and Team ids. All serde round-trips pass.
  - Dependencies: #6

- [ ] #9 Define pagination and shared types (T-15, T-16, A-1 through A-4)
  - Description: Implement: PaginationParams (page: i64, page_size: i64 with defaults and validation), PaginatedResponse<T: Serialize> (with new() constructor that calculates total_pages), ApiResponse<T> wrapper, SortOrder enum. See type-mapping.md T-15, T-16, G-1.
  - Rounds: 1 (risk 1.0, effective 1)
  - Verification: PaginatedResponse::new(data, 100, 1, 10) produces total_pages=10. PaginationParams defaults to page=1, page_size=20. SortOrder serializes as "asc"/"desc".
  - Dependencies: #4
```

## Quality Criteria

- [ ] Every task has a unique numeric ID (#1, #2, ..., #N)
- [ ] Every task has Description, Rounds, Verification, and Dependencies fields
- [ ] Task descriptions name specific types, functions, and files (not generic placeholders)
- [ ] Task descriptions reference the mapping document they draw from
- [ ] Rounds include risk factor calculation (base * risk = effective)
- [ ] Verification criteria are testable (can be checked with a command or test)
- [ ] Dependencies reference task IDs (not milestone names)
- [ ] No circular dependencies between tasks
- [ ] Milestones are ordered by dependency (Foundation -> Types -> Logic -> API -> Testing -> Deploy)
- [ ] Total effective rounds match the migration-plan.md summary
- [ ] Every type from type-mapping.md is covered by a task
- [ ] Every database entity has a query implementation task
- [ ] Every API endpoint has a handler implementation task
- [ ] Testing tasks cover unit, integration, and performance
- [ ] Deployment tasks include CI, Docker, and migration setup
