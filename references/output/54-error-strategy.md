# 54 - Error Strategy

**Output**: `.migration-plan/mappings/error-hierarchy.md`

## Purpose

Design the complete Rust error type hierarchy for the migrated project. This document takes every error condition discovered in the source codebase -- exceptions, error codes, sentinel values, panic conditions, HTTP error responses -- and maps them into a structured `Result<T, E>` system using `thiserror` for typed errors and `anyhow` for ad-hoc error propagation.

The error hierarchy is one of the most impactful architectural decisions in a Rust project. A well-designed error system enables precise error handling at call sites, clean error propagation with `?`, informative error messages for debugging, and correct HTTP status codes for API responses.

## Template

```markdown
# Error Hierarchy Design

Source: {project_name}
Generated: {date}

## Current Error Patterns (Source)

### Error Handling Style

| Pattern | Count | Locations |
|---------|-------|-----------|
| {e.g., try/catch with custom exceptions} | {N} | [{file}:{line}](../src/{file}#L{line}), ... |
| {e.g., Error codes as string constants} | {N} | [{file}:{line}](../src/{file}#L{line}), ... |
| {e.g., Thrown string literals} | {N} | [{file}:{line}](../src/{file}#L{line}), ... |
| {e.g., Process.exit / os.Exit} | {N} | [{file}:{line}](../src/{file}#L{line}), ... |
| {e.g., Callback error parameter} | {N} | [{file}:{line}](../src/{file}#L{line}), ... |
| {e.g., Unhandled promise rejection} | {N} | [{file}:{line}](../src/{file}#L{line}), ... |

### Source Error Classes / Types Inventory

| # | Source Error | File | Category | HTTP Status | Description |
|---|------------|------|----------|-------------|-------------|
| 1 | {ErrorClassName} | [{file}:{line}](../src/{file}#L{line}) | {Auth/Validation/NotFound/DB/External/Internal} | {status_code or N/A} | {what triggers this error} |
| 2 | {ErrorClassName} | [{file}:{line}](../src/{file}#L{line}) | {category} | {status} | {description} |
| ... | | | | | |

### Untyped Error Patterns

Locations where errors are thrown/raised without a typed error class:

| # | Pattern | File | What It Does | Proposed Handling |
|---|---------|------|-------------|-------------------|
| 1 | `throw new Error("{message}")` | [{file}:{line}](../src/{file}#L{line}) | {description} | {proposed Rust error variant} |
| 2 | `raise ValueError("{message}")` | [{file}:{line}](../src/{file}#L{line}) | {description} | {proposed Rust error variant} |
| ... | | | | |

## Proposed Rust Error Architecture

### Error Hierarchy Diagram

```text
                         AppError (root)
                        /    |    \      \
               AuthError  DbError  ApiError  ValidationError
                  |          |        |            |
              (variants) (variants) (variants) (variants)

Conversion chain:
  Module Error  --[From]-->  AppError  --[IntoResponse]-->  HTTP Response
    (thiserror)              (thiserror)                    (axum/actix)
```

### Root Error Type

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("authentication error: {0}")]
    Auth(#[from] AuthError),

    #[error("database error: {0}")]
    Database(#[from] DbError),

    #[error("validation error: {0}")]
    Validation(#[from] ValidationError),

    #[error("external service error: {0}")]
    External(#[from] ExternalError),

    #[error("not found: {resource} with id {id}")]
    NotFound { resource: &'static str, id: String },

    #[error("conflict: {0}")]
    Conflict(String),

    #[error("internal error: {0}")]
    Internal(String),

    #[error(transparent)]
    Unexpected(#[from] anyhow::Error),
}
```

## HTTP Status Code Mapping

{Include this section only if the source project is a web service.}

### Status Code Table

| AppError Variant | HTTP Status | Error Code | User-Facing Message |
|-----------------|-------------|------------|---------------------|
| Auth(InvalidToken) | 401 | INVALID_TOKEN | "Invalid or missing authentication token" |
| Auth(Expired) | 401 | TOKEN_EXPIRED | "Authentication token has expired" |
| Auth(Forbidden { .. }) | 403 | FORBIDDEN | "Insufficient permissions" |
| Auth(InvalidCredentials) | 401 | INVALID_CREDENTIALS | "Invalid email or password" |
| Validation(_) | 422 | VALIDATION_ERROR | "Validation failed: {details}" |
| NotFound { .. } | 404 | NOT_FOUND | "Resource not found" |
| Conflict(_) | 409 | CONFLICT | "Resource conflict" |
| Database(_) | 500 | INTERNAL_ERROR | "Internal error" |
| External(_) | 502 | EXTERNAL_ERROR | "Upstream service error" |
| Internal(_) | 500 | INTERNAL_ERROR | "Internal error" |
| Unexpected(_) | 500 | INTERNAL_ERROR | "Internal error" |

### IntoResponse Implementation

```rust
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde::Serialize;

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
    code: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    details: Option<Vec<FieldError>>,
}

#[derive(Serialize)]
struct FieldError {
    field: String,
    message: String,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code, message, details) = match &self {
            AppError::Auth(e) => match e {
                AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "INVALID_TOKEN", e.to_string(), None),
                AuthError::Expired => (StatusCode::UNAUTHORIZED, "TOKEN_EXPIRED", e.to_string(), None),
                AuthError::Forbidden { .. } => (StatusCode::FORBIDDEN, "FORBIDDEN", e.to_string(), None),
                AuthError::InvalidCredentials => (StatusCode::UNAUTHORIZED, "INVALID_CREDENTIALS", e.to_string(), None),
            },
            AppError::Validation(e) => {
                let details = match e {
                    ValidationError::Fields(fields) => Some(fields.clone()),
                    _ => None,
                };
                (StatusCode::UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", e.to_string(), details)
            }
            AppError::NotFound { .. } => (StatusCode::NOT_FOUND, "NOT_FOUND", self.to_string(), None),
            AppError::Conflict(_) => (StatusCode::CONFLICT, "CONFLICT", self.to_string(), None),
            AppError::Database(_) | AppError::Internal(_) | AppError::Unexpected(_) => {
                tracing::error!(error = ?self, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "internal error".into(), None)
            }
            AppError::External(_) => {
                tracing::error!(error = ?self, "external service error");
                (StatusCode::BAD_GATEWAY, "EXTERNAL_ERROR", "upstream service error".into(), None)
            }
        };

        let body = ErrorResponse {
            error: message,
            code,
            details,
        };

        (status, Json(body)).into_response()
    }
}
```

## Per-Module Error Enums

### {ModuleName} Module

**Source errors mapped**:

| Source Error | File | Rust Variant |
|-------------|------|-------------|
| {SourceError} | [{file}:{line}](../src/{file}#L{line}) | {EnumName}::{Variant} |
| {SourceError} | [{file}:{line}](../src/{file}#L{line}) | {EnumName}::{Variant} |

```rust
#[derive(Debug, Error)]
pub enum {ModuleError} {
    #[error("{display_message}")]
    {Variant} { {fields} },

    #[error("{display_message}")]
    {Variant}(#[source] {SourceType}),
}
```

---

{Repeat for each module that has 2+ error conditions}

---

## From Implementations

List all `From<ExternalCrateError>` conversions needed:

| # | External Error Type | Target | Conversion Logic |
|---|-------------------|--------|------------------|
| 1 | `{crate}::{Error}` | `{TargetEnum}` | {description of how to convert} |
| 2 | `{crate}::{Error}` | `{TargetEnum}` | {description of how to convert} |

### Implementation Code

```rust
// {ExternalError} -> {TargetEnum}
impl From<{ExternalError}> for {TargetEnum} {
    fn from(e: {ExternalError}) -> Self {
        {conversion_logic}
    }
}
```

{Repeat for each From implementation}

## Error Context Strategy

### When to use thiserror vs anyhow

| Scenario | Strategy | Example |
|----------|----------|---------|
| Library/domain error | `thiserror` enum | `AuthError::InvalidToken` |
| Caller needs to match | `thiserror` enum | `match err { DbError::NotFound => ..., }` |
| One-off context | `anyhow::Context` | `.context("failed to load user config")?` |
| Wrapping external error | `From` impl | `sqlx::Error -> DbError` |
| Unexpected/impossible | `anyhow::anyhow!()` | `anyhow!("invariant violated: {details}")` |

### Context Pattern

```rust
use anyhow::Context;

async fn load_user_settings(user_id: Uuid) -> Result<Settings, AppError> {
    let raw = db::get_settings(user_id)
        .await
        .context(format!("failed to load settings for user {user_id}"))?;

    let settings: Settings = serde_json::from_str(&raw)
        .context("failed to parse user settings JSON")?;

    Ok(settings)
}
```

## Logging Integration

### Error Logging Strategy

| Error Category | Log Level | Additional Context |
|---------------|-----------|-------------------|
| Auth errors | `warn!` | User ID, IP address |
| Validation errors | `debug!` | Field names, values (sanitized) |
| Not Found | `debug!` | Resource type, ID |
| Database errors | `error!` | Query context (no sensitive data) |
| External service errors | `error!` | Service name, timeout, status code |
| Internal errors | `error!` | Full error chain |
| Unexpected errors | `error!` | Full error chain with backtrace |

### Tracing Integration

```rust
use tracing::{error, warn, debug, instrument};

#[instrument(skip(pool), err)]
async fn get_user(pool: &PgPool, id: Uuid) -> Result<User, AppError> {
    // tracing automatically logs the error if this function returns Err
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await?
        .ok_or(AppError::NotFound { resource: "user", id: id.to_string() })?;

    Ok(user)
}
```

## Panic Inventory

Source patterns that should become panics (programming errors only):

| # | Source Pattern | File | Rust Equivalent | Rationale |
|---|--------------|------|-----------------|-----------|
| 1 | {pattern} | [{file}:{line}](../src/{file}#L{line}) | `{panic/assert/unreachable}` | {why this is a bug, not a recoverable error} |
| 2 | {pattern} | [{file}:{line}](../src/{file}#L{line}) | `{panic/assert/unreachable}` | {rationale} |

## Error Code Catalog

Complete list of error codes for API documentation:

| Code | HTTP Status | Description | When It Occurs |
|------|-------------|-------------|----------------|
| {ERROR_CODE} | {status} | {description} | {trigger condition} |
| {ERROR_CODE} | {status} | {description} | {trigger condition} |

## Crate Dependencies

```toml
[dependencies]
thiserror = "2"
anyhow = "1"
tracing = "0.1"
```
```

## Instructions

When producing this document:

1. **Read `analysis/error-patterns.md`** for the complete inventory of error handling patterns in the source.
2. **Read `analysis/type-catalog.md`** for custom error classes/types.
3. **Read `analysis/architecture.md`** for module boundaries that determine error scope.
4. **Every source error/exception class must map to a specific Rust enum variant**. Do not create a catch-all "Other" variant unless absolutely necessary.
5. **Per-module error enums should be created when a module has 3+ distinct error conditions**. Modules with fewer can use `AppError` directly.
6. **The `IntoResponse` implementation is required if the source is a web service**. Every error variant must map to a specific HTTP status code.
7. **Display messages must be human-readable** and include enough context for debugging (e.g., "not found: user with id 550e8400" not just "not found").
8. **From implementations** must handle every external crate error that can propagate through the `?` operator.
9. **The panic inventory must be conservative**. Only mark errors as panics if they represent genuine programming bugs (invariant violations), not recoverable conditions.
10. **Error codes** (string constants like "INVALID_TOKEN") must match the source project's existing error codes to maintain API compatibility.
11. Write in the same language the user used to invoke the skill.

## Example

```markdown
# Error Hierarchy Design

Source: taskflow-api
Generated: 2026-03-05

## Current Error Patterns (Source)

### Error Handling Style

| Pattern | Count | Locations |
|---------|-------|-----------|
| Custom exception classes extending Error | 6 | [errors.ts:3](../src/lib/errors.ts#L3), [errors.ts:12](../src/lib/errors.ts#L12), ... |
| try/catch in route handlers | 24 | [routes/users.ts:15](../src/routes/users.ts#L15), [routes/tasks.ts:22](../src/routes/tasks.ts#L22), ... |
| Express error middleware (next(error)) | 1 | [app.ts:45](../src/app.ts#L45) |
| Zod validation errors (ZodError) | 8 | [routes/users.ts:8](../src/routes/users.ts#L8), ... |
| Prisma known request errors | 12 | [services/user-service.ts:23](../src/services/user-service.ts#L23), ... |
| Unhandled promise rejection handler | 1 | [app.ts:62](../src/app.ts#L62) |

### Source Error Classes / Types Inventory

| # | Source Error | File | Category | HTTP Status | Description |
|---|------------|------|----------|-------------|-------------|
| 1 | UnauthorizedError | [errors.ts:3](../src/lib/errors.ts#L3) | Auth | 401 | Invalid or missing JWT token |
| 2 | ForbiddenError | [errors.ts:12](../src/lib/errors.ts#L12) | Auth | 403 | Insufficient permissions |
| 3 | NotFoundError | [errors.ts:21](../src/lib/errors.ts#L21) | Not Found | 404 | Resource not found |
| 4 | ConflictError | [errors.ts:30](../src/lib/errors.ts#L30) | Conflict | 409 | Duplicate resource |
| 5 | ValidationError | [errors.ts:39](../src/lib/errors.ts#L39) | Validation | 422 | Input validation failed |
| 6 | InternalError | [errors.ts:48](../src/lib/errors.ts#L48) | Internal | 500 | Unexpected server error |

## Proposed Rust Error Architecture

### Error Hierarchy Diagram

```text
                         AppError
                        /    |    \       \
               AuthError  DbError  ValidationError  ExternalError
                  |          |           |                |
           InvalidToken  Connection   Fields         Http
           Expired       Query        Format         Timeout
           Forbidden     UniqueViol.  MissingField   UnexpectedStatus
           InvalidCreds  NotFound
                         Transaction
```

### Per-Module Error Enums

#### Auth Module

**Source errors mapped**:

| Source Error | File | Rust Variant |
|-------------|------|-------------|
| UnauthorizedError (invalid token) | [errors.ts:3](../src/lib/errors.ts#L3) | AuthError::InvalidToken |
| UnauthorizedError (expired) | [errors.ts:3](../src/lib/errors.ts#L3) | AuthError::Expired |
| ForbiddenError | [errors.ts:12](../src/lib/errors.ts#L12) | AuthError::Forbidden |
| "Invalid credentials" (string throw) | [auth/login.ts:18](../src/lib/auth/login.ts#L18) | AuthError::InvalidCredentials |

```rust
#[derive(Debug, Error)]
pub enum AuthError {
    #[error("invalid or missing authentication token")]
    InvalidToken,

    #[error("authentication token has expired")]
    Expired,

    #[error("forbidden: insufficient permissions for {action} on {resource}")]
    Forbidden {
        action: String,
        resource: String,
    },

    #[error("invalid credentials")]
    InvalidCredentials,
}
```

#### Database Module

**Source errors mapped**:

| Source Error | File | Rust Variant |
|-------------|------|-------------|
| PrismaClientKnownRequestError (P2002) | [user-service.ts:23](../src/services/user-service.ts#L23) | DbError::UniqueViolation |
| PrismaClientKnownRequestError (P2025) | [task-service.ts:45](../src/services/task-service.ts#L45) | DbError::NotFound |
| Connection timeout | [prisma.ts:12](../src/db/prisma.ts#L12) | DbError::Connection |

```rust
#[derive(Debug, Error)]
pub enum DbError {
    #[error("database connection failed: {0}")]
    Connection(String),

    #[error("query failed: {0}")]
    Query(#[source] sqlx::Error),

    #[error("unique constraint violation on {field}")]
    UniqueViolation { field: String },

    #[error("record not found in {table}")]
    NotFound { table: &'static str },

    #[error("transaction failed: {0}")]
    Transaction(String),
}

impl From<sqlx::Error> for DbError {
    fn from(e: sqlx::Error) -> Self {
        match &e {
            sqlx::Error::RowNotFound => DbError::NotFound { table: "unknown" },
            sqlx::Error::Database(db_err) => {
                if let Some(code) = db_err.code() {
                    if code == "23505" {
                        return DbError::UniqueViolation {
                            field: db_err.message().to_string(),
                        };
                    }
                }
                DbError::Query(e)
            }
            _ => DbError::Query(e),
        }
    }
}
```

## Error Code Catalog

| Code | HTTP Status | Description | When It Occurs |
|------|-------------|-------------|----------------|
| INVALID_TOKEN | 401 | Authentication token is invalid or missing | No Authorization header, malformed JWT |
| TOKEN_EXPIRED | 401 | Authentication token has expired | JWT exp claim is in the past |
| INVALID_CREDENTIALS | 401 | Email or password is incorrect | Login attempt with wrong credentials |
| FORBIDDEN | 403 | User lacks permission | Accessing resource without required role |
| NOT_FOUND | 404 | Resource does not exist | GET/PUT/DELETE with non-existent ID |
| CONFLICT | 409 | Resource already exists | Creating user with duplicate email |
| VALIDATION_ERROR | 422 | Input validation failed | Missing required fields, invalid format |
| INTERNAL_ERROR | 500 | Unexpected server error | Database failure, serialization error |
| EXTERNAL_ERROR | 502 | Upstream service failed | Third-party API timeout or error |
```

## Quality Criteria

- [ ] Every custom error/exception class in the source has a corresponding Rust enum variant
- [ ] Every untyped error throw (string throws, generic Error) is categorized and mapped
- [ ] Root `AppError` enum is defined with `thiserror`
- [ ] Per-module error enums exist for modules with 3+ error conditions
- [ ] All `From` implementations for external crate errors are written with full conversion logic
- [ ] HTTP status code mapping is complete for every error variant (if web service)
- [ ] `IntoResponse` implementation compiles and handles all variants
- [ ] Error messages are human-readable and include contextual information
- [ ] Panic conditions are inventoried and each is justified as a programming bug
- [ ] Error context pattern is documented with `anyhow::Context` examples
- [ ] Logging integration specifies log level for each error category
- [ ] Error code catalog matches the source project's existing error codes
- [ ] Error hierarchy diagram visualizes the full conversion chain
