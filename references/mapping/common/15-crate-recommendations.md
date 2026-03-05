# 15 - Crate Recommendations

**Output**: Contributes to `.migration-plan/mappings/dependency-mapping.md` (crate selection section)

## Purpose

Master crate recommendation table mapping source language packages to their Rust equivalents. This is the comprehensive package ecosystem reference organized by category. For every dependency found in the source project, this guide provides the recommended Rust crate with version, confidence rating, and migration notes.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `dependency-tree.md` -- complete list of source dependencies with versions and usage

### Step 2: For each source dependency, find Rust equivalent

1. Look up the dependency in the category tables below
2. If found, use the recommended crate with the listed version
3. If not found, note it as `NO_EQUIVALENT` and suggest an alternative approach
4. Record the confidence level for each mapping

### Step 3: Produce dependency mapping

For EACH source dependency, produce an entry with the recommended crate, version, confidence, and any migration notes.

**Confidence levels:**

| Level | Meaning |
|-------|---------|
| HIGH | Direct equivalent, well-maintained, widely used, API parity > 90% |
| MEDIUM | Good equivalent but API differs significantly, or less mature |
| LOW | Partial equivalent, missing features, may need custom code |
| NO_EQUIVALENT | No crate exists; must implement manually or redesign |

## Crate Recommendation Tables

### HTTP Server

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| express | TS/JS | `axum` | 0.8 | HIGH | Preferred; tower-based middleware |
| fastify | TS/JS | `axum` | 0.8 | HIGH | axum matches fastify's performance focus |
| koa | TS/JS | `axum` | 0.8 | HIGH | Middleware model maps well |
| hapi | TS/JS | `axum` | 0.8 | MEDIUM | Plugin system needs manual mapping |
| nest.js | TS/JS | `axum` + manual DI | 0.8 | MEDIUM | No decorator/DI framework equivalent |
| flask | Python | `axum` | 0.8 | HIGH | Similar simplicity |
| fastapi | Python | `axum` + `utoipa` | 0.8 / 5 | HIGH | utoipa for OpenAPI generation |
| django | Python | `axum` + `sqlx` | 0.8 | MEDIUM | No ORM+admin equivalent; assemble from parts |
| gin | Go | `axum` | 0.8 | HIGH | Similar router API |
| echo | Go | `axum` | 0.8 | HIGH | Direct mapping |
| fiber | Go | `axum` | 0.8 | HIGH | Similar performance focus |
| chi | Go | `axum` | 0.8 | HIGH | Similar router design |
| net/http | Go | `axum` or `hyper` | 0.8 / 1 | HIGH | hyper for low-level control |

```rust
// axum server setup
use axum::{routing::{get, post}, Router, Json, extract::State};
use std::sync::Arc;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let state = Arc::new(AppState::new().await?);

    let app = Router::new()
        .route("/api/users", get(list_users).post(create_user))
        .route("/api/users/{id}", get(get_user).put(update_user).delete(delete_user))
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app).await?;
    Ok(())
}
```

### HTTP Client

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| axios | TS/JS | `reqwest` | 0.12 | HIGH | Async by default, similar API |
| node-fetch | TS/JS | `reqwest` | 0.12 | HIGH | Direct mapping |
| got | TS/JS | `reqwest` | 0.12 | HIGH | Retry via `reqwest-middleware` |
| superagent | TS/JS | `reqwest` | 0.12 | HIGH | Builder pattern matches |
| requests | Python | `reqwest` | 0.12 | HIGH | Very similar API |
| httpx | Python | `reqwest` | 0.12 | HIGH | Async support matches |
| aiohttp | Python | `reqwest` | 0.12 | HIGH | Async client |
| net/http | Go | `reqwest` | 0.12 | HIGH | Higher-level than Go's stdlib |
| resty | Go | `reqwest` | 0.12 | HIGH | Builder pattern maps well |

```rust
// reqwest client usage
let client = reqwest::Client::builder()
    .timeout(std::time::Duration::from_secs(30))
    .build()?;

let response = client
    .post("https://api.example.com/data")
    .header("Authorization", format!("Bearer {token}"))
    .json(&payload)
    .send()
    .await?;

let data: ApiResponse = response.json().await?;
```

### Database ORM / Query Builder

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| prisma | TS/JS | `sqlx` | 0.8 | MEDIUM | No schema-first ORM; use sqlx compile-time checks |
| typeorm | TS/JS | `sea-orm` | 1 | MEDIUM | Closest ORM equivalent |
| sequelize | TS/JS | `sea-orm` | 1 | MEDIUM | Active record pattern |
| knex | TS/JS | `sqlx` | 0.8 | HIGH | Query builder -> raw SQL with compile checks |
| drizzle | TS/JS | `sqlx` | 0.8 | MEDIUM | Type-safe queries |
| sqlalchemy | Python | `diesel` or `sea-orm` | 2 / 1 | MEDIUM | diesel for query DSL, sea-orm for async |
| tortoise-orm | Python | `sea-orm` | 1 | MEDIUM | Async ORM mapping |
| peewee | Python | `diesel` | 2 | MEDIUM | Simple ORM |
| gorm | Go | `sea-orm` or `diesel` | 1 / 2 | MEDIUM | sea-orm for async, diesel for sync |
| sqlx (Go) | Go | `sqlx` (Rust) | 0.8 | HIGH | Same name, similar philosophy |
| pgx | Go | `sqlx` | 0.8 | HIGH | Direct SQL with type safety |

```rust
// sqlx usage (recommended for most cases)
use sqlx::PgPool;

#[derive(Debug, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

async fn find_user(pool: &PgPool, id: Uuid) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}
```

### Serialization / Deserialization

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| JSON.parse/stringify | TS/JS | `serde` + `serde_json` | 1 / 1 | HIGH | Industry standard |
| class-transformer | TS/JS | `serde` derive macros | 1 | HIGH | `#[serde(rename, skip, default)]` |
| json (stdlib) | Python | `serde_json` | 1 | HIGH | Direct mapping |
| pydantic (serialization) | Python | `serde` | 1 | HIGH | Derive macros for struct serialization |
| encoding/json | Go | `serde` + `serde_json` | 1 / 1 | HIGH | `#[serde(rename_all = "camelCase")]` |
| yaml | Any | `serde_yaml` | 0.9 | HIGH | Via serde |
| toml | Any | `toml` | 0.8 | HIGH | Via serde |
| csv | Any | `csv` | 1 | HIGH | Via serde |
| msgpack | Any | `rmp-serde` | 1 | HIGH | Via serde |
| protobuf | Any | `prost` | 0.13 | HIGH | Code generation from .proto files |

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApiResponse<T: Serialize> {
    pub data: T,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    pub request_id: String,
}
```

### Validation

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| zod | TS/JS | `validator` | 0.19 | MEDIUM | Derive macros for validation |
| joi | TS/JS | `validator` | 0.19 | MEDIUM | Similar constraint system |
| class-validator | TS/JS | `validator` | 0.19 | HIGH | Decorator -> derive macro mapping |
| yup | TS/JS | `validator` | 0.19 | MEDIUM | Schema validation |
| pydantic | Python | `validator` + `serde` | 0.19 / 1 | MEDIUM | Validation + serialization split |
| marshmallow | Python | `validator` + `serde` | 0.19 / 1 | MEDIUM | Schema -> struct + derive |
| cerberus | Python | `validator` | 0.19 | MEDIUM | Rule-based validation |
| go-playground/validator | Go | `validator` | 0.19 | HIGH | Very similar tag-based API |
| ozzo-validation | Go | `validator` | 0.19 | MEDIUM | Programmatic validation |

```rust
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
pub struct CreateUserInput {
    #[validate(length(min = 1, max = 100))]
    pub name: String,

    #[validate(email)]
    pub email: String,

    #[validate(length(min = 8, max = 128))]
    pub password: String,

    #[validate(range(min = 0, max = 200))]
    pub age: Option<u8>,

    #[validate(url)]
    pub website: Option<String>,
}

// Usage in handler
async fn create_user(Json(input): Json<CreateUserInput>) -> Result<Json<User>, AppError> {
    input.validate().map_err(|e| {
        AppError::Validation(ValidationError::Fields(
            e.field_errors()
                .into_iter()
                .map(|(field, errors)| FieldError {
                    field: field.to_string(),
                    message: errors.first().map(|e| format!("{e}")).unwrap_or_default(),
                })
                .collect()
        ))
    })?;
    // ...
}
```

### CLI Framework

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| commander | TS/JS | `clap` | 4 | HIGH | Derive macro for type-safe args |
| yargs | TS/JS | `clap` | 4 | HIGH | Similar subcommand support |
| inquirer | TS/JS | `dialoguer` | 0.11 | HIGH | Interactive prompts |
| chalk | TS/JS | `colored` | 3 | HIGH | Terminal colors |
| ora | TS/JS | `indicatif` | 0.17 | HIGH | Progress bars and spinners |
| click | Python | `clap` | 4 | HIGH | Decorator -> derive macro |
| argparse | Python | `clap` | 4 | HIGH | Built-in replacement |
| typer | Python | `clap` | 4 | HIGH | Type-hint -> derive macro |
| rich | Python | `indicatif` + `colored` | 0.17 / 3 | MEDIUM | Partial coverage |
| cobra | Go | `clap` | 4 | HIGH | Very similar API |
| viper | Go | `config` | 0.14 | MEDIUM | Config file loading |
| pflag | Go | `clap` | 4 | HIGH | Flag parsing built into clap |

```rust
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "myapp", version, about = "My application")]
struct Cli {
    /// Input file path
    #[arg(short, long)]
    input: std::path::PathBuf,

    /// Output directory
    #[arg(short, long, default_value = "./output")]
    output: std::path::PathBuf,

    /// Verbosity level
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,

    #[command(subcommand)]
    command: Commands,
}

#[derive(clap::Subcommand, Debug)]
enum Commands {
    /// Process input files
    Process {
        /// Enable parallel processing
        #[arg(long)]
        parallel: bool,
    },
    /// Show statistics
    Stats,
}
```

### Logging and Observability

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| winston | TS/JS | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | HIGH | Structured logging |
| pino | TS/JS | `tracing` | 0.1 | HIGH | JSON structured logs |
| bunyan | TS/JS | `tracing` | 0.1 | HIGH | Structured logging |
| morgan | TS/JS | `tower-http::trace` | 0.6 | HIGH | HTTP request logging middleware |
| debug | TS/JS | `tracing` with levels | 0.1 | HIGH | Conditional debug output |
| logging | Python | `tracing` | 0.1 | HIGH | Direct level mapping |
| loguru | Python | `tracing` | 0.1 | HIGH | Similar ergonomics |
| structlog | Python | `tracing` | 0.1 | HIGH | Structured logging is tracing's strength |
| zap | Go | `tracing` | 0.1 | HIGH | Structured, high-performance |
| logrus | Go | `tracing` | 0.1 | HIGH | Structured logging |
| slog | Go | `tracing` | 0.1 | HIGH | Structured logging |
| opentelemetry | Any | `opentelemetry` + `tracing-opentelemetry` | 0.28 / 0.28 | HIGH | OTEL integration |

```rust
use tracing::{info, warn, error, debug, instrument};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

fn init_tracing() {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .with(tracing_subscriber::fmt::layer().json()) // JSON output
        .init();
}

#[instrument(skip(pool))]
async fn get_user(pool: &PgPool, id: Uuid) -> Result<User, AppError> {
    info!(user_id = %id, "fetching user");
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await?;

    match user {
        Some(u) => {
            debug!(user_name = %u.name, "user found");
            Ok(u)
        }
        None => {
            warn!(user_id = %id, "user not found");
            Err(AppError::NotFound { resource: "user", id: id.to_string() })
        }
    }
}
```

### Testing

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| jest | TS/JS | Built-in `#[test]` | - | HIGH | No external dep needed |
| mocha + chai | TS/JS | Built-in `#[test]` | - | HIGH | assert macros replace chai |
| supertest | TS/JS | `axum-test` | 16 | HIGH | HTTP integration testing |
| nock | TS/JS | `wiremock` | 0.6 | HIGH | HTTP mocking |
| sinon | TS/JS | `mockall` | 0.13 | HIGH | Mock/stub/spy |
| pytest | Python | Built-in `#[test]` | - | HIGH | No external dep needed |
| pytest-asyncio | Python | `#[tokio::test]` | - | HIGH | Built into tokio |
| factory-boy | Python | Builder pattern | - | HIGH | Manual builder structs |
| responses | Python | `wiremock` | 0.6 | HIGH | HTTP response mocking |
| unittest.mock | Python | `mockall` | 0.13 | HIGH | Auto-mock generation |
| testing (stdlib) | Go | Built-in `#[test]` | - | HIGH | Same concept |
| testify | Go | `pretty_assertions` + `mockall` | 1 / 0.13 | HIGH | Assert + mock |
| httptest | Go | `wiremock` | 0.6 | HIGH | HTTP test server |
| gomock | Go | `mockall` | 0.13 | HIGH | Interface mocking |

### Date and Time

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| dayjs | TS/JS | `chrono` | 0.4 | HIGH | Full date/time library |
| moment | TS/JS | `chrono` | 0.4 | HIGH | moment is deprecated; chrono is active |
| luxon | TS/JS | `chrono` | 0.4 | HIGH | Timezone support via chrono-tz |
| date-fns | TS/JS | `chrono` | 0.4 | HIGH | Functional date utilities |
| datetime (stdlib) | Python | `chrono` | 0.4 | HIGH | Direct mapping |
| dateutil | Python | `chrono` | 0.4 | HIGH | Parsing and relative deltas |
| arrow | Python | `chrono` | 0.4 | HIGH | Human-friendly dates |
| time (stdlib) | Go | `chrono` or `time` | 0.4 / 0.3 | HIGH | chrono is more popular; `time` is lighter |
| carbon | Go | `chrono` | 0.4 | HIGH | Extended date operations |

```rust
use chrono::{DateTime, Utc, NaiveDate, Duration, TimeZone};

let now: DateTime<Utc> = Utc::now();
let tomorrow = now + Duration::days(1);
let formatted = now.format("%Y-%m-%d %H:%M:%S").to_string();
let parsed = DateTime::parse_from_rfc3339("2024-01-15T10:30:00Z").unwrap();
```

### UUID

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| uuid | TS/JS | `uuid` | 1 | HIGH | Same name, same purpose |
| nanoid | TS/JS | `nanoid` | 0.4 | HIGH | Direct equivalent |
| cuid | TS/JS | `cuid2` | 0.1 | MEDIUM | Less popular in Rust |
| uuid (stdlib) | Python | `uuid` | 1 | HIGH | Direct mapping |
| shortuuid | Python | `uuid` + custom encoding | 1 | MEDIUM | Encode uuid to base57 manually |
| google/uuid | Go | `uuid` | 1 | HIGH | Direct mapping |
| rs/xid | Go | `xid` | 1 | HIGH | Direct equivalent |

```rust
use uuid::Uuid;

let id = Uuid::new_v4();
let id_str = id.to_string();
let parsed = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000")?;

// With serde
#[derive(Serialize, Deserialize)]
pub struct Entity {
    pub id: Uuid, // Serializes as string automatically
}
```

### Cryptography and Security

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| bcrypt | TS/JS | `bcrypt` or `argon2` | 0.16 / 0.5 | HIGH | argon2 preferred for new projects |
| crypto (Node.js) | TS/JS | `ring` or `sha2` + `hmac` | 0.17 / 0.10 | HIGH | ring for general crypto |
| jsonwebtoken | TS/JS | `jsonwebtoken` | 9 | HIGH | Same name, similar API |
| jose | TS/JS | `jsonwebtoken` | 9 | HIGH | JWT handling |
| passlib | Python | `argon2` | 0.5 | HIGH | Password hashing |
| cryptography | Python | `ring` + `rustls` | 0.17 | HIGH | General crypto |
| pyjwt | Python | `jsonwebtoken` | 9 | HIGH | JWT encoding/decoding |
| golang.org/x/crypto | Go | `ring` + `argon2` | 0.17 / 0.5 | HIGH | Crypto primitives |
| dgrijalva/jwt-go | Go | `jsonwebtoken` | 9 | HIGH | JWT handling |

```rust
// Password hashing with argon2
use argon2::{Argon2, PasswordHasher, PasswordVerifier, password_hash::{SaltString, rand_core::OsRng}};

fn hash_password(password: &str) -> Result<String, argon2::password_hash::Error> {
    let salt = SaltString::generate(&mut OsRng);
    let hash = Argon2::default().hash_password(password.as_bytes(), &salt)?;
    Ok(hash.to_string())
}

fn verify_password(password: &str, hash: &str) -> Result<bool, argon2::password_hash::Error> {
    let parsed = argon2::PasswordHash::new(hash)?;
    Ok(Argon2::default().verify_password(password.as_bytes(), &parsed).is_ok())
}

// JWT
use jsonwebtoken::{encode, decode, Header, EncodingKey, DecodingKey, Validation};

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: usize,
    iat: usize,
}
```

### Async Runtime

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| Event loop (built-in) | TS/JS | `tokio` | 1 | HIGH | Multi-threaded async runtime |
| asyncio | Python | `tokio` | 1 | HIGH | Full async runtime |
| goroutines | Go | `tokio` | 1 | HIGH | Spawn tasks with `tokio::spawn` |
| worker_threads | TS/JS | `rayon` or `tokio::spawn_blocking` | 1 / 1 | HIGH | CPU-bound parallelism |
| multiprocessing | Python | `rayon` | 1 | HIGH | CPU-bound parallelism |

```rust
// tokio runtime
#[tokio::main]
async fn main() {
    // Async I/O tasks
    tokio::spawn(async { /* ... */ });

    // CPU-bound work
    tokio::task::spawn_blocking(|| {
        // Heavy computation
    }).await.unwrap();
}
```

### Environment and Configuration

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| dotenv | TS/JS | `dotenvy` | 0.15 | HIGH | Drop-in replacement (dotenv crate is unmaintained) |
| config | TS/JS | `config` | 0.14 | HIGH | Layered configuration |
| convict | TS/JS | `config` + `serde` | 0.14 / 1 | MEDIUM | Schema-based config |
| python-dotenv | Python | `dotenvy` | 0.15 | HIGH | .env file loading |
| pydantic-settings | Python | `config` + `serde` | 0.14 / 1 | MEDIUM | Typed config from env |
| os.Getenv | Go | `std::env::var` | - | HIGH | Built-in, no crate needed |
| viper | Go | `config` | 0.14 | HIGH | Multi-source config |
| envconfig | Go | `envy` | 0.4 | HIGH | Env vars to struct |

```rust
use dotenvy::dotenv;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct AppConfig {
    pub database_url: String,
    pub port: u16,
    pub jwt_secret: String,
    #[serde(default = "default_log_level")]
    pub log_level: String,
}

fn default_log_level() -> String { "info".into() }

impl AppConfig {
    pub fn from_env() -> Result<Self, envy::Error> {
        dotenv().ok(); // Load .env file if present
        envy::from_env()
    }
}
```

### File System

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| fs (Node.js) | TS/JS | `std::fs` + `tokio::fs` | - | HIGH | Built-in sync and async |
| fs-extra | TS/JS | `fs_extra` or `std::fs` | 1 | HIGH | Recursive copy/move |
| glob | TS/JS | `glob` | 0.3 | HIGH | File pattern matching |
| chokidar | TS/JS | `notify` | 7 | HIGH | File system watching |
| pathlib | Python | `std::path::PathBuf` | - | HIGH | Built-in path handling |
| os.path | Python | `std::path::Path` | - | HIGH | Built-in |
| shutil | Python | `std::fs` + `fs_extra` | - / 1 | HIGH | Copy/move operations |
| watchdog | Python | `notify` | 7 | HIGH | File watching |
| os/filepath | Go | `std::path::PathBuf` | - | HIGH | Built-in |
| afero | Go | `std::fs` (or custom trait) | - | MEDIUM | Virtual FS needs manual abstraction |

```rust
use std::path::{Path, PathBuf};
use walkdir::WalkDir;
use tokio::fs;

// Recursive directory traversal
fn find_files(dir: &Path, extension: &str) -> Vec<PathBuf> {
    WalkDir::new(dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().map_or(false, |ext| ext == extension))
        .map(|e| e.path().to_owned())
        .collect()
}

// Async file operations
async fn read_json_file<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, AppError> {
    let content = fs::read_to_string(path).await?;
    let data: T = serde_json::from_str(&content)?;
    Ok(data)
}
```

### WebSocket

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| ws / socket.io | TS/JS | `axum` (built-in WS) + `tokio-tungstenite` | 0.8 / 0.24 | MEDIUM | No socket.io equivalent; use raw WS |
| websockets | Python | `tokio-tungstenite` | 0.24 | HIGH | Async WebSocket |
| gorilla/websocket | Go | `tokio-tungstenite` | 0.24 | HIGH | Similar API |

### Task Queues and Background Jobs

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| bull / bullmq | TS/JS | `apalis` | 0.6 | MEDIUM | Redis-backed job queue |
| celery | Python | `apalis` or `rusty-celery` | 0.6 / 0.6 | MEDIUM | apalis is more idiomatic |
| asynq | Go | `apalis` | 0.6 | MEDIUM | Similar Redis-backed queue |

### Template Engines

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| handlebars / ejs | TS/JS | `tera` or `askama` | 1 / 0.12 | HIGH | askama for compile-time templates |
| jinja2 | Python | `tera` | 1 | HIGH | Jinja2-compatible syntax |
| html/template | Go | `tera` or `askama` | 1 / 0.12 | HIGH | Similar template concepts |

### Email

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| nodemailer | TS/JS | `lettre` | 0.11 | HIGH | Full SMTP client |
| smtplib | Python | `lettre` | 0.11 | HIGH | SMTP sending |
| gomail | Go | `lettre` | 0.11 | HIGH | Email sending |

### Rate Limiting

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| express-rate-limit | TS/JS | `tower-governor` | 0.5 | HIGH | Tower middleware |
| slowapi | Python | `tower-governor` | 0.5 | HIGH | Rate limiting middleware |
| tollbooth | Go | `tower-governor` | 0.5 | HIGH | Rate limiting |

### Caching

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| ioredis / redis | TS/JS | `redis` (crate) or `fred` | 0.27 / 10 | HIGH | fred for advanced features |
| redis-py | Python | `redis` (crate) | 0.27 | HIGH | Async Redis client |
| go-redis | Go | `redis` (crate) | 0.27 | HIGH | Feature parity |
| node-cache | TS/JS | `moka` | 0.12 | HIGH | In-memory cache with TTL |
| cachetools | Python | `moka` | 0.12 | HIGH | In-memory caching |
| lru | Any | `lru` | 0.12 | HIGH | LRU cache |

```rust
// In-memory cache with moka
use moka::future::Cache;
use std::time::Duration;

let cache: Cache<String, User> = Cache::builder()
    .max_capacity(10_000)
    .time_to_live(Duration::from_secs(300))
    .build();

// Insert
cache.insert("user:123".into(), user.clone()).await;

// Get
if let Some(user) = cache.get(&"user:123".into()).await {
    return Ok(user);
}
```

### Regex

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| RegExp (built-in) | TS/JS | `regex` | 1 | HIGH | No backtracking (safer) |
| re (stdlib) | Python | `regex` | 1 | HIGH | Direct mapping |
| regexp (stdlib) | Go | `regex` | 1 | HIGH | Similar RE2 syntax |

```rust
use regex::Regex;
use std::sync::LazyLock;

// Compile regex once (important for performance)
static EMAIL_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap()
});

fn is_valid_email(email: &str) -> bool {
    EMAIL_RE.is_match(email)
}
```

### Miscellaneous

| Source Package | Language | Rust Crate | Version | Confidence | Notes |
|---------------|----------|------------|---------|------------|-------|
| lodash | TS/JS | Iterator methods (built-in) | - | HIGH | Most lodash functions are stdlib iterators |
| ramda | TS/JS | Iterator + custom traits | - | MEDIUM | Functional patterns via iterators |
| p-limit | TS/JS | `futures::stream::buffer_unordered` | 0.3 | HIGH | Concurrency limiting |
| retry | Any | `backoff` or `tokio-retry` | 0.4 / 0.3 | HIGH | Exponential backoff |
| mime-types | Any | `mime` | 0.3 | HIGH | MIME type detection |
| semver | Any | `semver` | 1 | HIGH | Semantic versioning |
| url | Any | `url` | 2 | HIGH | URL parsing |
| base64 | Any | `base64` | 0.22 | HIGH | Base64 encoding |

## Template

```markdown
# Dependency Mapping

Source: {project_name}
Generated: {date}

## Summary

| Total Dependencies | Mapped (HIGH) | Mapped (MEDIUM) | Mapped (LOW) | No Equivalent |
|-------------------|---------------|-----------------|-------------- |---------------|
| {count} | {count} | {count} | {count} | {count} |

## Dependency Mapping Table

| # | Source Package | Version | Purpose | Rust Crate | Crate Version | Confidence | Notes |
|---|--------------|---------|---------|------------|---------------|------------|-------|
| 1 | express | 4.18 | HTTP server | axum | 0.8 | HIGH | Tower middleware ecosystem |
| 2 | prisma | 5.0 | ORM | sqlx | 0.8 | MEDIUM | Switch to raw SQL with compile checks |
| 3 | zod | 3.22 | Validation | validator | 0.19 | MEDIUM | Derive macros instead of schema objects |
| ... | ... | ... | ... | ... | ... | ... | ... |

## No-Equivalent Dependencies

| Source Package | Purpose | Rust Strategy |
|---------------|---------|---------------|
| {package} | {purpose} | {manual implementation plan or alternative approach} |

## Cargo.toml

```toml
[dependencies]
# Web
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace"] }

# Database
sqlx = { version = "0.8", features = ["runtime-tokio", "tls-rustls", "postgres", "uuid", "chrono"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Error handling
thiserror = "2"
anyhow = "1"

# Observability
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# Utilities
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
dotenvy = "0.15"
validator = { version = "0.19", features = ["derive"] }
reqwest = { version = "0.12", features = ["json"] }
regex = "1"

[dev-dependencies]
tokio = { version = "1", features = ["test-util", "macros", "rt-multi-thread"] }
mockall = "0.13"
wiremock = "0.6"
pretty_assertions = "1"
```
```

## Completeness Check

- [ ] Every source dependency is listed with a Rust crate recommendation
- [ ] Confidence level is assigned for every mapping
- [ ] Dependencies with NO_EQUIVALENT have an alternative strategy
- [ ] Version numbers are current and correct
- [ ] Compilable code examples are provided for major crates
- [ ] Complete `Cargo.toml` is generated with all dependencies
- [ ] Dev-dependencies are separated from production dependencies
- [ ] Feature flags are specified where needed (e.g., sqlx features)
- [ ] Summary table shows counts by confidence level
