# 11 - Error Strategy Mapping

**Output**: `.migration-plan/mappings/error-hierarchy.md`

## Purpose

Design the complete Rust error type hierarchy for the migrated project. Every error condition found in the source -- exceptions, error codes, sentinel values, panic conditions -- must map to a specific variant in a well-structured `Result<T, E>` system using `thiserror` for library errors and `anyhow` for application-level error propagation.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `error-patterns.md` -- inventory of all error handling patterns, exception types, error codes
- `architecture.md` -- module boundaries that determine error scope
- `type-catalog.md` -- custom error classes/types already defined in the source

Extract every instance of:
- Custom exception/error classes
- Error codes or error string constants
- Try/catch (try/except, if err != nil) blocks and what they catch
- HTTP status code mappings
- Validation error patterns
- External service error handling (database, API calls, file I/O)
- Panic/fatal/process.exit patterns
- Error wrapping and chaining patterns

### Step 2: For each error pattern, determine Rust equivalent

**Error categorization framework:**

| Category | Examples | Rust Strategy |
|----------|----------|---------------|
| Validation | Invalid input, missing fields, format errors | Per-module `ValidationError` enum |
| Not Found | Record not found, file not found, route not found | `NotFound` variant or `Option<T>` |
| Authentication | Invalid token, expired session, unauthorized | `AuthError` enum |
| Authorization | Forbidden, insufficient permissions | `AuthError::Forbidden` variant |
| Conflict | Duplicate entry, version conflict, race condition | `ConflictError` variant |
| External Service | Database errors, HTTP client errors, timeout | Wrap with `From` impl |
| Internal | Unexpected state, assertion failure, logic error | `InternalError` with context |
| Configuration | Missing env var, invalid config value | `ConfigError` enum, fail at startup |

**Decision process for each error:**

```
Is this error recoverable by the caller?
  YES -> Return Result<T, SpecificError>
  NO  ->
    Is it a programming bug (should never happen)?
      YES -> panic!() or debug_assert!()
      NO  -> Return Result<T, E> with InternalError variant

Is this error specific to one module?
  YES -> Define in that module's error enum
  NO  -> Place in root AppError enum

Does the caller need to match on specific variants?
  YES -> Use typed enum (thiserror)
  NO  -> Use anyhow::Error for ergonomic propagation
```

**Error conversion chain:**

```
Module-specific error  -->  AppError  -->  HTTP Response (if web service)
     (thiserror)          (thiserror)        (IntoResponse impl)
```

### Step 3: Produce error hierarchy document

For EACH error pattern found in the source, produce:
1. Source error (class/type with file:line reference)
2. Category (from the framework above)
3. Target Rust variant (in which enum, which variant)
4. `From` implementation needed (if wrapping external errors)
5. Display message format

## Template

```markdown
# Error Hierarchy Design

Source: {project_name}
Generated: {date}

## Error Architecture

```text
                    AppError (root)
                   /    |    \     \
          AuthError  DbError  ApiError  ValidationError
              |         |        |            |
          (variants) (variants) (variants) (variants)
```

## Root Error Type

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("authentication failed: {0}")]
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

## HTTP Status Code Mapping (if web service)

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
        let (status, code, message) = match &self {
            AppError::Auth(e) => match e {
                AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "INVALID_TOKEN", e.to_string()),
                AuthError::Expired => (StatusCode::UNAUTHORIZED, "TOKEN_EXPIRED", e.to_string()),
                AuthError::Forbidden { .. } => (StatusCode::FORBIDDEN, "FORBIDDEN", e.to_string()),
            },
            AppError::Validation(e) => (StatusCode::UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", e.to_string()),
            AppError::NotFound { .. } => (StatusCode::NOT_FOUND, "NOT_FOUND", self.to_string()),
            AppError::Conflict(_) => (StatusCode::CONFLICT, "CONFLICT", self.to_string()),
            AppError::Database(_) => (StatusCode::INTERNAL_SERVER_ERROR, "DATABASE_ERROR", "internal error".into()),
            AppError::External(_) => (StatusCode::BAD_GATEWAY, "EXTERNAL_ERROR", "upstream service error".into()),
            AppError::Internal(_) | AppError::Unexpected(_) => {
                tracing::error!(error = ?self, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "internal error".into())
            }
        };

        let body = ErrorResponse {
            error: message,
            code,
            details: None,
        };

        (status, Json(body)).into_response()
    }
}
```

## Per-Module Error Enums

### Auth Module

**Source errors mapped**:
| Source Error | File | Rust Variant |
|-------------|------|-------------|
| `UnauthorizedError` | [{file}:{line}](../src/{file}#L{line}) | `AuthError::InvalidToken` |
| `TokenExpiredError` | [{file}:{line}](../src/{file}#L{line}) | `AuthError::Expired` |
| `ForbiddenError` | [{file}:{line}](../src/{file}#L{line}) | `AuthError::Forbidden` |

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

### Database Module

**Source errors mapped**:
| Source Error | File | Rust Variant |
|-------------|------|-------------|
| `ConnectionError` | [{file}:{line}](../src/{file}#L{line}) | `DbError::Connection` |
| `QueryError` | [{file}:{line}](../src/{file}#L{line}) | `DbError::Query` |
| `UniqueViolation` | [{file}:{line}](../src/{file}#L{line}) | `DbError::UniqueViolation` |

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

// Automatic conversion from sqlx errors
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

### Validation Module

**Source errors mapped**:
| Source Error | File | Rust Variant |
|-------------|------|-------------|
| `ZodError` / `ValidationError` | [{file}:{line}](../src/{file}#L{line}) | `ValidationError::Fields` |

```rust
#[derive(Debug, Error)]
pub enum ValidationError {
    #[error("validation failed: {}", format_field_errors(.0))]
    Fields(Vec<FieldError>),

    #[error("invalid format for {field}: {message}")]
    Format { field: String, message: String },

    #[error("missing required field: {0}")]
    MissingField(String),

    #[error("value out of range for {field}: {message}")]
    OutOfRange { field: String, message: String },
}

fn format_field_errors(errors: &[FieldError]) -> String {
    errors
        .iter()
        .map(|e| format!("{}: {}", e.field, e.message))
        .collect::<Vec<_>>()
        .join(", ")
}
```

### External Service Module

```rust
#[derive(Debug, Error)]
pub enum ExternalError {
    #[error("HTTP request to {service} failed: {message}")]
    Http {
        service: String,
        message: String,
        #[source]
        source: reqwest::Error,
    },

    #[error("timeout calling {service} after {timeout_ms}ms")]
    Timeout {
        service: String,
        timeout_ms: u64,
    },

    #[error("{service} returned unexpected status {status}: {body}")]
    UnexpectedStatus {
        service: String,
        status: u16,
        body: String,
    },
}
```

## From Implementations

List all `From<ExternalCrateError>` conversions needed:

| External Error Type | Target | Conversion Logic |
|--------------------|--------|------------------|
| `sqlx::Error` | `DbError` | Match on error kind (see above) |
| `reqwest::Error` | `ExternalError` | Wrap in `ExternalError::Http` |
| `serde_json::Error` | `AppError::Internal` | Format as internal error |
| `std::io::Error` | `AppError::Internal` | Format as internal error |
| `jsonwebtoken::errors::Error` | `AuthError` | Map to `InvalidToken` or `Expired` |

```rust
// Example: serde_json -> AppError
impl From<serde_json::Error> for AppError {
    fn from(e: serde_json::Error) -> Self {
        AppError::Internal(format!("JSON serialization error: {e}"))
    }
}

// Example: std::io -> AppError
impl From<std::io::Error> for AppError {
    fn from(e: std::io::Error) -> Self {
        AppError::Internal(format!("I/O error: {e}"))
    }
}
```

## Error Context Pattern

For adding context to errors without losing the source:

```rust
use anyhow::Context;

// In application code, use anyhow's context for ad-hoc errors:
async fn load_user(id: Uuid) -> Result<User, AppError> {
    let user = db::find_user(id)
        .await
        .context(format!("failed to load user {id}"))?;

    Ok(user)
}

// The ? operator converts anyhow::Error into AppError::Unexpected
```

## Panic Inventory

Source patterns that should become panics (programming errors only):

| Source Pattern | File | Rust Equivalent | Rationale |
|---------------|------|-----------------|-----------|
| `assert(condition)` | [{file}:{line}] | `assert!(condition)` | Invariant violation = bug |
| `unreachable code` | [{file}:{line}] | `unreachable!()` | Dead code path |
| `array index without bounds check` | [{file}:{line}] | Rust auto-panics on OOB | Built-in safety |

## Error Mapping Summary

| Source Error/Exception | Category | Rust Type | Variant | HTTP Status |
|-----------------------|----------|-----------|---------|-------------|
| (fill for each source error) | Auth | `AuthError` | `InvalidToken` | 401 |
| | Validation | `ValidationError` | `Fields` | 422 |
| | Not Found | `AppError` | `NotFound` | 404 |
| | Database | `DbError` | `Query` | 500 |
| | External | `ExternalError` | `Http` | 502 |

## Crate Dependencies

```toml
[dependencies]
thiserror = "2"
anyhow = "1"
```
```

## Completeness Check

- [ ] Every custom exception/error class in the source has a Rust enum variant
- [ ] Every error code or error string has been categorized
- [ ] Root `AppError` enum is defined with `thiserror`
- [ ] Per-module error enums are defined for modules with 3+ error conditions
- [ ] All `From` implementations for external crate errors are listed
- [ ] HTTP status code mapping is complete (if web service)
- [ ] `IntoResponse` implementation is provided (if using axum/actix-web)
- [ ] Panic conditions are inventoried and justified
- [ ] Error context pattern is documented for ad-hoc errors
- [ ] Display messages are human-readable and include relevant context
- [ ] Error hierarchy diagram shows the full conversion chain
