# 11 - Error Mapping

**Output**: `.migration-plan/mappings/error-hierarchy.md`

Design the complete Rust error type hierarchy for the migrated project.

## Method

1. Read `.migration-plan/analysis/error-patterns.md` -- get all error types and patterns
2. Read `ref/{language}.md` -- consult the Error Handling Patterns section
3. Design a Rust error enum hierarchy:
   a. One root `AppError` enum with thiserror
   b. Per-module error enums if the project is large
   c. `From` impls for external crate errors (sqlx::Error, reqwest::Error, etc.)
   d. `IntoResponse` impl if it's a web service (map error -> HTTP status)
4. Map EVERY source error type/pattern to a Rust error variant
5. Decide: thiserror (library) vs anyhow (application) vs both

## Template

```markdown
# Error Hierarchy

Source error types: {N} | Rust error variants: {N}

## Root Error

\`\`\`rust
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found: {0}")]
    NotFound(String),

    #[error("unauthorized: {0}")]
    Unauthorized(String),

    #[error(transparent)]
    Database(#[from] sqlx::Error),
}
\`\`\`

## Error Mapping

| Source Error | Rust Variant | HTTP Status | From impl |
|-------------|-------------|------------|-----------|
| NotFoundError | AppError::NotFound | 404 | manual |
| ValidationError | AppError::Validation | 400 | manual |
| sqlx::Error | AppError::Database | 500 | #[from] |
{EVERY error mapped}

## IntoResponse Implementation

\`\`\`rust
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, msg) = match &self {
            Self::NotFound(m) => (StatusCode::NOT_FOUND, m.clone()),
            // ...
        };
        (status, Json(json!({"error": msg}))).into_response()
    }
}
\`\`\`

## Context Strategy
- Internal functions: return `Result<T, AppError>`
- External boundaries: use `.context("doing X")?` with anyhow where needed
```
