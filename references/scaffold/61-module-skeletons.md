# 61 - Module Skeletons

**Output**: `{project_root}/crates/*/src/*.rs` (skeleton source files)

## Purpose

Generate skeleton Rust source files for every module identified in the migration plan. Each file contains the complete type definitions (structs, enums, traits) with derive macros, serde annotations, and function signatures with `todo!()` bodies. This gives dev-workflow concrete starting points for each implementation task.

## Prerequisites

- `.migration-plan/mappings/type-mapping.md` -- all type definitions with Rust equivalents
- `.migration-plan/mappings/module-mapping.md` -- module structure
- `.migration-plan/mappings/error-hierarchy.md` -- error types
- Cargo workspace already generated (guide 60)

## Method

### Step 1: Read type mappings

From `type-mapping.md`, extract every Rust type definition. Group by target module.

### Step 2: Generate type definition files

For EACH module, create source files with COMPLETE type definitions.

#### Models crate example

```rust
// crates/models/src/lib.rs
pub mod user;
pub mod order;
pub mod product;
pub mod category;

// Re-export commonly used types
pub use user::{User, UserRole, CreateUserRequest, UpdateUserRequest};
pub use order::{Order, OrderItem, OrderStatus};
pub use product::{Product, ProductVariant};
pub use category::Category;
```

```rust
// crates/models/src/user.rs

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// User account.
///
/// Source: src/models/user.ts:5-15
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub name: Option<String>,
    pub role: UserRole,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// User role enumeration.
///
/// Source: src/models/user.ts:17-21
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum UserRole {
    Admin,
    User,
    Viewer,
}

impl Default for UserRole {
    fn default() -> Self {
        Self::User
    }
}

/// Request body for creating a user.
///
/// Source: src/routes/users.ts:30-35 (request validation schema)
#[derive(Debug, Clone, Deserialize)]
pub struct CreateUserRequest {
    pub email: String,
    pub name: Option<String>,
    #[serde(default)]
    pub role: UserRole,
}

/// Request body for updating a user.
///
/// Source: src/routes/users.ts:37-41
#[derive(Debug, Clone, Deserialize)]
pub struct UpdateUserRequest {
    pub name: Option<String>,
    pub role: Option<UserRole>,
}
```

#### Error crate example

```rust
// crates/error/src/lib.rs

use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

/// Application error hierarchy.
///
/// Source: src/errors/custom-errors.ts
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found: {0}")]
    NotFound(String),

    #[error("unauthorized: {0}")]
    Unauthorized(String),

    #[error("validation error: {0}")]
    Validation(String),

    #[error("internal error: {0}")]
    Internal(String),

    #[error(transparent)]
    Database(#[from] sqlx::Error),

    #[error(transparent)]
    Unexpected(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            Self::NotFound(msg) => (StatusCode::NOT_FOUND, msg.clone()),
            Self::Unauthorized(msg) => (StatusCode::UNAUTHORIZED, msg.clone()),
            Self::Validation(msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            Self::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, msg.clone()),
            Self::Database(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "database error".to_string(),
            ),
            Self::Unexpected(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "unexpected error".to_string(),
            ),
        };

        let body = Json(json!({
            "error": message,
            "status": status.as_u16(),
        }));

        (status, body).into_response()
    }
}
```

#### Service crate example (signatures only)

```rust
// crates/services/src/user_service.rs

use models::{CreateUserRequest, UpdateUserRequest, User};
use error::AppError;
use sqlx::PgPool;
use uuid::Uuid;

/// User service handling business logic.
///
/// Source: src/services/user-service.ts
pub struct UserService {
    pool: PgPool,
}

impl UserService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// Get user by ID.
    ///
    /// Source: src/services/user-service.ts:15-20
    pub async fn get_by_id(&self, id: Uuid) -> Result<User, AppError> {
        todo!("Migrate from UserService.getById")
    }

    /// List all users with optional role filter.
    ///
    /// Source: src/services/user-service.ts:22-35
    pub async fn list(&self, role: Option<models::UserRole>) -> Result<Vec<User>, AppError> {
        todo!("Migrate from UserService.list")
    }

    /// Create a new user.
    ///
    /// Source: src/services/user-service.ts:37-50
    pub async fn create(&self, req: CreateUserRequest) -> Result<User, AppError> {
        todo!("Migrate from UserService.create")
    }

    /// Update an existing user.
    ///
    /// Source: src/services/user-service.ts:52-65
    pub async fn update(&self, id: Uuid, req: UpdateUserRequest) -> Result<User, AppError> {
        todo!("Migrate from UserService.update")
    }

    /// Delete a user.
    ///
    /// Source: src/services/user-service.ts:67-72
    pub async fn delete(&self, id: Uuid) -> Result<(), AppError> {
        todo!("Migrate from UserService.delete")
    }
}
```

#### API handler example (signatures only)

```rust
// crates/api/src/handlers/users.rs

use axum::{
    extract::{Path, Query, State},
    Json,
};
use models::{CreateUserRequest, UpdateUserRequest, User};
use error::AppError;
use uuid::Uuid;
use std::sync::Arc;

use crate::AppState;

/// GET /api/users
///
/// Source: src/routes/users.ts:10-15
pub async fn list_users(
    State(state): State<Arc<AppState>>,
    Query(params): Query<ListUsersParams>,
) -> Result<Json<Vec<User>>, AppError> {
    todo!("Migrate from GET /api/users handler")
}

/// GET /api/users/:id
///
/// Source: src/routes/users.ts:17-25
pub async fn get_user(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<Json<User>, AppError> {
    todo!("Migrate from GET /api/users/:id handler")
}

/// POST /api/users
///
/// Source: src/routes/users.ts:27-40
pub async fn create_user(
    State(state): State<Arc<AppState>>,
    Json(body): Json<CreateUserRequest>,
) -> Result<Json<User>, AppError> {
    todo!("Migrate from POST /api/users handler")
}

/// PUT /api/users/:id
///
/// Source: src/routes/users.ts:42-55
pub async fn update_user(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
    Json(body): Json<UpdateUserRequest>,
) -> Result<Json<User>, AppError> {
    todo!("Migrate from PUT /api/users/:id handler")
}

/// DELETE /api/users/:id
///
/// Source: src/routes/users.ts:57-65
pub async fn delete_user(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<(), AppError> {
    todo!("Migrate from DELETE /api/users/:id handler")
}

#[derive(Debug, serde::Deserialize)]
pub struct ListUsersParams {
    pub role: Option<String>,
    pub page: Option<u32>,
    pub limit: Option<u32>,
}
```

### Step 3: Generate lib.rs and mod.rs files

Every directory needs a module declaration file:

```rust
// crates/api/src/handlers/mod.rs
pub mod users;
pub mod orders;
pub mod products;
pub mod health;
```

```rust
// crates/api/src/lib.rs
pub mod handlers;
pub mod middleware;

use axum::Router;
use std::sync::Arc;

pub struct AppState {
    pub db: sqlx::PgPool,
    // Add other shared state here
}

pub fn create_router(state: Arc<AppState>) -> Router {
    todo!("Build router from source route definitions")
}
```

### Step 4: Generate main.rs for binary crates

```rust
// crates/api/src/main.rs

use std::sync::Arc;
use tokio::net::TcpListener;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    // Load configuration
    let config = config::load()?;

    // Connect to database
    let pool = sqlx::PgPool::connect(&config.database_url).await?;

    // Run migrations
    sqlx::migrate!().run(&pool).await?;

    // Build application state
    let state = Arc::new(api::AppState { db: pool });

    // Build router
    let app = api::create_router(state);

    // Start server
    let listener = TcpListener::bind(&config.bind_address).await?;
    tracing::info!("listening on {}", config.bind_address);
    axum::serve(listener, app).await?;

    Ok(())
}
```

## Rules

1. **Types are COMPLETE** -- struct fields, derive macros, serde annotations all filled in
2. **Functions have `todo!()` bodies** -- signature is complete, implementation is a placeholder
3. **Source references in doc comments** -- every type/function links back to source file:line
4. **Imports are correct** -- all `use` statements resolve
5. **`cargo build` must pass** -- `todo!()` compiles; the project must be buildable at scaffold stage
6. **Follow type-mapping.md exactly** -- don't invent types not in the plan

## Quality Criteria

- [ ] Every type from type-mapping.md has a corresponding Rust definition
- [ ] All struct fields have correct types and serde annotations
- [ ] Every function from module-mapping.md has a skeleton with `todo!()` body
- [ ] All `mod` declarations and `use` imports are correct
- [ ] `cargo build --workspace` succeeds with no errors (warnings from `todo!()` are OK)
- [ ] `cargo clippy --workspace` passes (except `todo!()` warnings)
- [ ] Source file:line references are in doc comments
- [ ] No placeholder types (`Any`, `Object`, `unknown`) -- all types are concrete
