# 50 - Migration Plan (Executive Summary)

**Output**: `.migration-plan/migration-plan.md`

## Purpose

The migration plan is the top-level executive summary of the entire Rust rewrite effort. It synthesizes all Phase 1 analysis and Phase 2 mapping outputs into a single decision-making document. A technical lead should be able to read this document alone and understand: what is being migrated, why, how, how long it will take, what decisions have been made, and what must be true for the migration to succeed.

This document is generated during Phase 3 (Synthesis) after all analysis and mapping tasks are complete.

## Template

```markdown
# Migration Plan

Generated: {date}
Source: {project_path}

## 1. Project Overview

| Field | Value |
|-------|-------|
| Project Name | {project_name} |
| Source Language | {TypeScript / Python / Go / Mixed} |
| Language Version | {e.g., Node 20 / Python 3.12 / Go 1.22} |
| Framework | {e.g., Express + Prisma / FastAPI + SQLAlchemy / Gin + GORM} |
| Total Source Files | {N} |
| Total Lines of Code | {N} |
| Modules / Packages | {N} |
| Direct Dependencies | {N} |
| Entry Points | {N} ({list: N HTTP servers, N CLIs, N workers}) |
| Test Files | {N} |
| Test Coverage | {N% or "unknown"} |

### Architecture Summary

{2-3 paragraph description of the current architecture. What does the system do? What are its major components? How do they communicate? What databases/services does it depend on?}

### Module Inventory

| # | Module | Files | LOC | Responsibility |
|---|--------|-------|-----|----------------|
| 1 | {module_name} | {N} | {N} | {one-line description} |
| 2 | {module_name} | {N} | {N} | {one-line description} |
| ... | | | | |
| **Total** | | **{N}** | **{N}** | |

## 2. Migration Rationale

### Why Rust?

{Explain the specific reasons this project benefits from a Rust rewrite. Reference concrete problems in the current codebase that Rust solves. This is NOT a generic "Rust is fast" section -- it must be project-specific.}

### Expected Benefits

| Benefit | Current State | Expected After Migration | Measurement |
|---------|--------------|--------------------------|-------------|
| {e.g., Latency} | {e.g., p99 = 450ms} | {e.g., p99 < 50ms} | {e.g., load test benchmark} |
| {e.g., Memory} | {e.g., 2GB RSS} | {e.g., < 200MB RSS} | {e.g., production metrics} |
| {e.g., Type Safety} | {e.g., 12 runtime type errors/month} | {e.g., 0 (compile-time)} | {e.g., error tracker} |
| {e.g., Deployment} | {e.g., 800MB Docker image} | {e.g., < 30MB static binary} | {e.g., image size} |

### Risks of NOT Migrating

{What happens if the project stays in the current language? Growing maintenance burden? Performance ceiling? Hiring challenges?}

## 3. Migration Scope

### Included

{List every module, service, and component that WILL be migrated to Rust.}

- {module_name}: {reason for inclusion}
- {module_name}: {reason for inclusion}
- ...

### Excluded

{List anything that will NOT be migrated, and why.}

- {component}: {reason for exclusion, e.g., "frontend React app -- not applicable"}
- {component}: {reason for exclusion, e.g., "third-party SDK -- no Rust equivalent"}
- ...

### Boundaries

{Define the interface points between migrated and non-migrated components. How will they communicate during and after migration?}

## 4. High-Level Strategy

### Migration Approach: {Strangler Fig / Big Bang / Module-by-Module}

{Explain the chosen approach and why it fits this project.}

**{Approach Name}**: {One paragraph explanation of how this approach works for this specific project.}

### Migration Phases

```text
Phase 1: Foundation         ({N} rounds)
  - Cargo workspace setup
  - Core types and error hierarchy
  - Configuration and logging

Phase 2: Core Business Logic ({N} rounds)
  - {module_name}
  - {module_name}

Phase 3: API / Interface Layer ({N} rounds)
  - {module_name}
  - {module_name}

Phase 4: Integration & Testing ({N} rounds)
  - End-to-end tests
  - Performance benchmarks
  - Migration verification

Phase 5: Deployment           ({N} rounds)
  - CI/CD pipeline
  - Container setup
  - Production cutover
```

### Dependency Order

```text
{ASCII diagram showing the order modules must be migrated, based on dependency analysis}

  [core-types] --> [database] --> [business-logic] --> [api-layer]
       |                              |
       +--------> [auth] ------------+
       |
       +--------> [config]
```

## 5. Estimated Effort

### Rounds Summary

| Phase | Tasks | Base Rounds | Risk Factor | Effective Rounds |
|-------|-------|-------------|-------------|-----------------|
| Foundation | {N} | {N} | {1.0-1.5} | {N} |
| Core Types | {N} | {N} | {1.0-1.5} | {N} |
| Business Logic | {N} | {N} | {1.2-2.0} | {N} |
| API Layer | {N} | {N} | {1.0-1.5} | {N} |
| Testing | {N} | {N} | {1.0-1.3} | {N} |
| Deployment | {N} | {N} | {1.0-1.2} | {N} |
| **Total** | **{N}** | **{N}** | **avg {X}** | **{N}** |

### Risk Factors

| Factor | Impact | Applied To |
|--------|--------|------------|
| Complex async patterns | 1.3x | Business Logic |
| No direct crate equivalent | 1.5x | Modules using {dep_name} |
| Unsafe FFI required | 1.5x | {module_name} |
| High cyclomatic complexity | 1.2x | {module_name} |
| Weak test coverage in source | 1.3x | All phases |

### Effort Distribution

```text
Foundation:      {bar} {N}%
Core Types:      {bar} {N}%
Business Logic:  {bar} {N}%
API Layer:       {bar} {N}%
Testing:         {bar} {N}%
Deployment:      {bar} {N}%
```

## 6. Key Technical Decisions

### Runtime and Core Crates

| Decision | Choice | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Async Runtime | tokio 1.x | Industry standard, best ecosystem support | async-std (smaller ecosystem) |
| Error Handling | thiserror + anyhow | thiserror for library errors, anyhow for app-level | eyre (less common) |
| Web Framework | {axum 0.8 / actix-web 4} | {rationale} | {alternatives} |
| Database | {sqlx 0.8 / diesel 2 / sea-orm 1} | {rationale} | {alternatives} |
| Serialization | serde + serde_json | De facto standard, no real alternative | {none} |
| Logging | tracing + tracing-subscriber | Structured async-aware logging | log + env_logger (less capable) |
| HTTP Client | reqwest 0.12 | Most popular, async, good API | ureq (sync-only) |
| Configuration | {config / envy / dotenvy} | {rationale} | {alternatives} |
| Testing | cargo test + mockall | Built-in test framework + mock generation | {alternatives} |

### Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Workspace Layout | {single crate / workspace with N crates} | {rationale} |
| Module Boundaries | {same as source / reorganized} | {rationale} |
| API Compatibility | {exact same API / redesigned} | {rationale} |
| Database Migrations | {sqlx-migrate / refinery / manual} | {rationale} |
| Error Granularity | {per-module enums / single AppError} | {rationale} |

## 7. Prerequisites

### Team Skills

- [ ] Rust ownership and borrowing model
- [ ] Async/await with tokio
- [ ] Error handling with Result<T, E>
- [ ] serde serialization/deserialization
- [ ] {framework}-specific knowledge (e.g., axum extractors, tower middleware)
- [ ] SQL (if switching from ORM to raw queries)

### Infrastructure

- [ ] Rust toolchain installed (rustup, cargo, clippy, rustfmt)
- [ ] CI pipeline supports Rust (cargo build, cargo test, cargo clippy)
- [ ] Container build for Rust binary (multi-stage Dockerfile)
- [ ] Development environment configured (IDE with rust-analyzer)
- [ ] Database migration tooling selected and configured

### Data

- [ ] Database schema documented and accessible
- [ ] Test data available for validation
- [ ] Production traffic patterns documented (for performance testing)

## 8. Success Criteria

### Functional

- [ ] All existing API endpoints return identical responses
- [ ] All business logic produces identical results for identical inputs
- [ ] All background jobs execute with the same behavior
- [ ] Error responses match the existing error contract

### Non-Functional

- [ ] p99 latency <= {target}ms (current: {current}ms)
- [ ] Memory usage <= {target}MB (current: {current}MB)
- [ ] Binary size <= {target}MB
- [ ] Cold start time <= {target}ms
- [ ] All tests pass (unit, integration, end-to-end)
- [ ] cargo clippy produces zero warnings
- [ ] No unsafe code (unless documented and justified)

### Process

- [ ] Zero data loss during migration
- [ ] Rollback plan tested and documented
- [ ] Performance benchmarks automated in CI
- [ ] Migration completed within {N} rounds (+/- {N}% tolerance)

## 9. Reference Documents

| Document | Path | Description |
|----------|------|-------------|
| Module Mapping | [mappings/module-mapping.md](./mappings/module-mapping.md) | Source module -> Rust crate/module |
| Type Mapping | [mappings/type-mapping.md](./mappings/type-mapping.md) | Source type -> Rust struct/enum |
| Dependency Mapping | [mappings/dependency-mapping.md](./mappings/dependency-mapping.md) | Source package -> Rust crate |
| Error Hierarchy | [mappings/error-hierarchy.md](./mappings/error-hierarchy.md) | Rust error type design |
| Async Strategy | [mappings/async-strategy.md](./mappings/async-strategy.md) | Async pattern transforms |
| Pattern Transforms | [mappings/pattern-transforms.md](./mappings/pattern-transforms.md) | Design pattern conversions |
| Risk Assessment | [risk-assessment.md](./risk-assessment.md) | Risk matrix and mitigations |
| Feasibility Report | [feasibility-report.md](./feasibility-report.md) | GO/NO-GO recommendation |
| Roadmap | [dev-workflow/roadmap.md](./dev-workflow/roadmap.md) | Step-by-step execution plan |
```

## Instructions

When producing this document:

1. **Read ALL Phase 1 and Phase 2 outputs first.** This document synthesizes everything. Do not write it until all analysis and mapping files exist.
2. **Project Overview** must contain exact numbers from `analysis/source-inventory.md`. Do not estimate -- use the actual counts.
3. **Migration Rationale** must be project-specific. Reference concrete pain points discovered during analysis (e.g., "47 `any` casts found in type-catalog.md suggest type safety is a real problem").
4. **Key Technical Decisions** must reference the actual dependencies found in `mappings/dependency-mapping.md`. If the project uses Express, recommend axum. If it uses FastAPI, recommend axum + utoipa. Do not list decisions for frameworks the project does not use.
5. **Estimated Effort** must sum the rounds from `dev-workflow/roadmap.md`. The numbers here must match the roadmap exactly.
6. **Success Criteria** must include measurable targets. If performance data is not available from analysis, state "baseline to be established" rather than guessing.
7. **Migration Scope: Excluded** must list things found in the source that are intentionally NOT migrated (frontend code, scripts, generated code).
8. Write in the same language the user used to invoke the skill.

## Example

```markdown
# Migration Plan

Generated: 2026-03-05
Source: /home/dev/taskflow-api

## 1. Project Overview

| Field | Value |
|-------|-------|
| Project Name | taskflow-api |
| Source Language | TypeScript |
| Language Version | Node 20.11, TypeScript 5.3 |
| Framework | Express 4.18 + Prisma 5.8 + BullMQ 5.1 |
| Total Source Files | 87 |
| Total Lines of Code | 12,450 |
| Modules / Packages | 8 |
| Direct Dependencies | 34 |
| Entry Points | 3 (1 HTTP server, 1 CLI, 1 worker) |
| Test Files | 23 |
| Test Coverage | 64% |

### Architecture Summary

TaskFlow API is a project management REST API that provides task CRUD operations, team management, and real-time notifications. The system uses Express for HTTP handling, Prisma as an ORM over PostgreSQL, BullMQ for background job processing (email notifications, report generation), and Redis for caching and job queues. Authentication uses JWT tokens with refresh token rotation. The API serves a React frontend (not in scope) and a mobile app via the same REST endpoints.

### Module Inventory

| # | Module | Files | LOC | Responsibility |
|---|--------|-------|-----|----------------|
| 1 | api/routes | 12 | 1,850 | Express route handlers and middleware |
| 2 | api/middleware | 5 | 420 | Auth, validation, error handling, rate limiting |
| 3 | services | 10 | 2,680 | Business logic layer |
| 4 | models | 8 | 1,200 | Prisma schema and type definitions |
| 5 | jobs | 6 | 890 | BullMQ job processors |
| 6 | lib/auth | 4 | 560 | JWT, password hashing, session management |
| 7 | lib/cache | 3 | 340 | Redis cache wrapper |
| 8 | lib/email | 3 | 280 | Email templates and sending |
| **Total** | | **87** | **12,450** | |

## 2. Migration Rationale

### Why Rust?

TaskFlow API experiences p99 latency spikes of 800ms under moderate load (500 concurrent users) due to Node.js event loop blocking during JSON serialization of large task lists and Prisma query overhead. The 34 direct dependencies create a 280MB node_modules directory, and the Docker image is 1.2GB. Security audit found 8 high-severity vulnerabilities in transitive dependencies. The team spends approximately 15% of development time on type-related runtime errors that TypeScript's `any` escape hatches allow through (47 instances of `as any` found in the codebase).

### Expected Benefits

| Benefit | Current State | Expected After Migration | Measurement |
|---------|--------------|--------------------------|-------------|
| Latency | p99 = 800ms at 500 users | p99 < 50ms at 500 users | k6 load test |
| Memory | 512MB RSS baseline | < 50MB RSS baseline | Production metrics |
| Image Size | 1.2GB Docker image | < 30MB static binary | docker images |
| Type Safety | 47 `as any` casts, 12 runtime type errors/month | 0 runtime type errors | Error tracker |
| Dependencies | 34 direct, 847 transitive | ~20 direct, ~100 transitive | cargo tree |
| Cold Start | 3.2 seconds | < 100ms | Startup timer |

## 4. High-Level Strategy

### Migration Approach: Module-by-Module

TaskFlow API has clean module boundaries with well-defined interfaces between services, routes, and models. A module-by-module approach allows migrating the inner layers first (models, services) while keeping the Express API layer running, then swapping the API layer last. This minimizes risk because each module can be validated independently.

### Migration Phases

```text
Phase 1: Foundation         (4 rounds)
  - Cargo workspace setup
  - Core types (User, Task, Team, Project structs)
  - Error hierarchy (AppError, AuthError, DbError, ValidationError)
  - Configuration (AppConfig from env)

Phase 2: Core Business Logic (8 rounds)
  - Database layer (sqlx queries replacing Prisma)
  - Auth module (JWT + argon2)
  - Service layer (TaskService, TeamService, ProjectService)
  - Cache layer (Redis wrapper)

Phase 3: API Layer           (6 rounds)
  - Axum route handlers
  - Middleware (auth, validation, rate limiting)
  - Email service (lettre)
  - Background jobs (apalis replacing BullMQ)

Phase 4: Integration & Testing (4 rounds)
  - Unit tests for all services
  - Integration tests with test database
  - API contract tests (same responses as TypeScript version)

Phase 5: Deployment           (2 rounds)
  - Multi-stage Dockerfile
  - CI pipeline (cargo build, test, clippy, fmt)
  - Production deployment and monitoring
```

## 6. Key Technical Decisions

### Runtime and Core Crates

| Decision | Choice | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Async Runtime | tokio 1.x | Industry standard, required by axum and sqlx | async-std (smaller ecosystem) |
| Error Handling | thiserror + anyhow | thiserror for typed errors, anyhow for propagation | eyre (less common) |
| Web Framework | axum 0.8 | Tower-based, best async ecosystem integration | actix-web (less composable) |
| Database | sqlx 0.8 | Compile-time checked SQL, replaces Prisma | sea-orm (adds ORM overhead) |
| Serialization | serde + serde_json | De facto standard | none |
| Logging | tracing | Structured, async-aware | log (no structured fields) |
| HTTP Client | reqwest 0.12 | Async, widely used | ureq (sync only) |
| Password Hashing | argon2 0.5 | Replaces bcrypt, more secure | bcrypt (older algorithm) |
| JWT | jsonwebtoken 9 | Same name as TS package, similar API | none |
| Job Queue | apalis 0.6 | Redis-backed, replaces BullMQ | none mature |
```

## Quality Criteria

- [ ] Project Overview contains exact numbers (files, LOC, dependencies) from source-inventory.md
- [ ] Migration Rationale references specific findings from analysis documents
- [ ] Expected Benefits table has measurable current-state and target values
- [ ] Scope clearly separates included and excluded components
- [ ] Strategy names a specific approach (not "we will decide later")
- [ ] Estimated Effort rounds match the roadmap.md totals exactly
- [ ] Key Decisions reference only crates/frameworks actually needed by this project
- [ ] Prerequisites are actionable (not vague platitudes)
- [ ] Success Criteria are measurable with specific thresholds
- [ ] All reference document links are correct and point to existing files
- [ ] Document is written in the user's language (Chinese or English)
