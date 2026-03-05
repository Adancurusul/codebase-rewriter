# 34 - pip/PyPI Package to Rust Crate Mapping

**Output**: Contributes to `.migration-plan/mappings/dependency-mapping.md`

## Purpose

Comprehensive reference table mapping Python pip packages from PyPI to their Rust crate equivalents on crates.io. For every Python dependency found in `requirements.txt`, `pyproject.toml`, `Pipfile`, or `setup.py`, this guide provides the recommended Rust crate with version, confidence rating, API mapping notes, and migration considerations. This is the authoritative lookup table for Python-to-Rust dependency translation.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `dependency-tree.md` -- complete list of Python dependencies with versions and usage patterns
- `architecture.md` -- identifies which dependencies are critical path vs. peripheral

### Step 2: For each Python dependency, find Rust equivalent

1. Look up the dependency in the category tables below
2. If found, use the recommended crate with the listed version
3. If not found, note it as `NO_EQUIVALENT` and suggest an alternative approach
4. Record the confidence level for each mapping

### Step 3: Produce dependency mapping

For EACH Python dependency, produce an entry with the recommended crate, version, confidence, and migration notes.

**Confidence levels:**

| Level | Meaning |
|-------|---------|
| HIGH | Direct equivalent, well-maintained, widely used, API parity > 90% |
| MEDIUM | Good equivalent but API differs significantly, or less mature |
| LOW | Partial equivalent, missing features, may need custom code |
| NO_EQUIVALENT | No crate exists; must implement manually or redesign |

## Crate Recommendation Tables

### Web Frameworks

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| flask | `axum` | 0.8 | HIGH | Routes via `Router::new().route()`, blueprints -> nested routers |
| fastapi | `axum` + `utoipa` | 0.8 / 5 | HIGH | Path params via extractors, auto-docs via utoipa |
| django | `axum` + `sqlx` + `tera` | 0.8 | MEDIUM | No admin panel / ORM migrations; assemble from parts |
| starlette | `axum` | 0.8 | HIGH | ASGI -> tower middleware, similar routing model |
| uvicorn | `tokio` + `hyper` | 1 | HIGH | Built into axum/tokio runtime |
| gunicorn | `tokio` (multi-threaded) | 1 | HIGH | tokio runtime replaces process workers |
| sanic | `axum` | 0.8 | HIGH | Async web framework -> axum |
| tornado | `axum` | 0.8 | HIGH | Async web framework |
| bottle | `axum` | 0.8 | HIGH | Minimal web framework |
| aiohttp (server) | `axum` | 0.8 | HIGH | Async HTTP server |
| falcon | `axum` | 0.8 | HIGH | REST-focused -> axum routes |
| quart | `axum` | 0.8 | HIGH | Flask-like async -> axum |
| django-rest-framework | `axum` + `serde` | 0.8 | MEDIUM | Serializers -> serde, viewsets -> handlers |
| django-ninja | `axum` + `utoipa` | 0.8 | MEDIUM | FastAPI-like in Django -> axum + OpenAPI |

```rust
// axum server replacing Flask/FastAPI
use axum::{routing::{get, post}, Router, Json, extract::{Path, Query, State}};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::net::TcpListener;

#[derive(Deserialize)]
struct PaginationParams {
    page: Option<u32>,
    per_page: Option<u32>,
}

async fn list_users(
    State(state): State<Arc<AppState>>,
    Query(params): Query<PaginationParams>,
) -> Result<Json<Vec<User>>, AppError> {
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(20);
    let users = state.user_repo.list(page, per_page).await?;
    Ok(Json(users))
}

async fn get_user(
    State(state): State<Arc<AppState>>,
    Path(user_id): Path<uuid::Uuid>,
) -> Result<Json<User>, AppError> {
    let user = state.user_repo.find(user_id).await?
        .ok_or(AppError::NotFound { resource: "user", id: user_id.to_string() })?;
    Ok(Json(user))
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let state = Arc::new(AppState::new().await?);
    let app = Router::new()
        .route("/api/users", get(list_users).post(create_user))
        .route("/api/users/{id}", get(get_user).put(update_user).delete(delete_user))
        .with_state(state);

    let listener = TcpListener::bind("0.0.0.0:8000").await?;
    axum::serve(listener, app).await?;
    Ok(())
}
```

### HTTP Clients

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| requests | `reqwest` (blocking) | 0.12 | HIGH | `reqwest::blocking::Client` for sync, `reqwest::Client` for async |
| httpx | `reqwest` | 0.12 | HIGH | Async client with connection pooling |
| aiohttp (client) | `reqwest` | 0.12 | HIGH | Async HTTP client |
| urllib3 | `reqwest` | 0.12 | HIGH | Connection pooling built into reqwest |
| httplib2 | `reqwest` | 0.12 | HIGH | HTTP/2 support via hyper backend |
| requests-toolbelt | `reqwest` + `reqwest-middleware` | 0.12 | MEDIUM | Multipart, retries via middleware |
| tenacity | `backoff` or `tokio-retry` | 0.4 / 0.3 | HIGH | Retry with exponential backoff |

### ORM / Database

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| sqlalchemy | `sqlx` or `diesel` | 0.8 / 2 | MEDIUM | sqlx for async + raw SQL; diesel for query DSL |
| sqlalchemy (async) | `sqlx` | 0.8 | HIGH | Both compile-time checked |
| tortoise-orm | `sea-orm` | 1 | MEDIUM | Async ORM with active record pattern |
| peewee | `diesel` | 2 | MEDIUM | Simple ORM -> query DSL |
| django ORM | `sea-orm` or `sqlx` | 1 / 0.8 | MEDIUM | No Django migrations equiv; use sqlx-cli |
| psycopg2 | `sqlx` (postgres feature) | 0.8 | HIGH | PostgreSQL driver |
| asyncpg | `sqlx` (postgres feature) | 0.8 | HIGH | Async PostgreSQL |
| pymongo | `mongodb` | 3 | HIGH | Official MongoDB driver |
| motor | `mongodb` | 3 | HIGH | Async MongoDB |
| redis-py | `redis` | 0.27 | HIGH | Sync and async Redis |
| aioredis | `redis` (tokio-comp feature) | 0.27 | HIGH | Async Redis |
| pymysql | `sqlx` (mysql feature) | 0.8 | HIGH | MySQL driver |
| aiomysql | `sqlx` (mysql feature) | 0.8 | HIGH | Async MySQL |
| sqlite3 (stdlib) | `sqlx` (sqlite feature) or `rusqlite` | 0.8 / 0.32 | HIGH | rusqlite for sync, sqlx for async |
| aiosqlite | `sqlx` (sqlite feature) | 0.8 | HIGH | Async SQLite |
| alembic | `sqlx-cli` (migrate) | 0.8 | MEDIUM | `sqlx migrate run` for migrations |
| databases | `sqlx` | 0.8 | HIGH | Async database toolkit |

```rust
// sqlx replacing SQLAlchemy / asyncpg
use sqlx::{PgPool, postgres::PgPoolOptions};

pub async fn create_pool(database_url: &str) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(20)
        .connect(database_url)
        .await
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct User {
    pub id: uuid::Uuid,
    pub name: String,
    pub email: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn find_users_by_name(pool: &PgPool, name: &str) -> Result<Vec<User>, sqlx::Error> {
    sqlx::query_as::<_, User>(
        "SELECT id, name, email, created_at FROM users WHERE name ILIKE $1 ORDER BY created_at DESC"
    )
    .bind(format!("%{name}%"))
    .fetch_all(pool)
    .await
}
```

### Data Processing

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| pandas | `polars` | 0.46 | MEDIUM | Different API but similar concepts; DataFrame-based |
| numpy | `ndarray` | 0.16 | MEDIUM | N-dimensional arrays; no NumPy broadcasting sugar |
| polars (Python) | `polars` | 0.46 | HIGH | Same library, native Rust! |
| scipy | `nalgebra` + `ndarray` | 0.33 / 0.16 | LOW | Partial coverage; no full SciPy equiv |
| scikit-learn | `linfa` | 0.7 | LOW | Partial ML algorithms; consider keeping Python |
| pyarrow | `arrow` | 53 | HIGH | Apache Arrow Rust implementation |
| dask | `polars` (lazy) + `rayon` | 0.46 / 1 | MEDIUM | Lazy evaluation + parallelism |
| openpyxl | `calamine` + `xlsxwriter` | 0.26 / 0.8 | MEDIUM | Read with calamine, write with xlsxwriter |
| csv (stdlib) | `csv` | 1 | HIGH | Serde integration for typed CSV |
| xlrd | `calamine` | 0.26 | HIGH | Excel reading |

```rust
// polars replacing pandas
use polars::prelude::*;

fn process_data() -> Result<DataFrame, PolarsError> {
    let df = CsvReadOptions::default()
        .with_has_header(true)
        .try_into_reader_with_file_path(Some("data.csv".into()))?
        .finish()?;

    let result = df
        .lazy()
        .filter(col("age").gt(lit(18)))
        .group_by([col("department")])
        .agg([
            col("salary").mean().alias("avg_salary"),
            col("name").count().alias("count"),
        ])
        .sort(["avg_salary"], Default::default())
        .collect()?;

    Ok(result)
}
```

### Serialization / Validation

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| pydantic | `serde` + `validator` | 1 / 0.19 | HIGH | Derive macros replace BaseModel |
| pydantic-settings | `config` + `envy` + `serde` | 0.14 / 0.4 / 1 | MEDIUM | Env var -> struct via envy |
| marshmallow | `serde` | 1 | HIGH | Schema -> struct with derive macros |
| cattrs | `serde` | 1 | HIGH | Structuring/unstructuring -> serde |
| cerberus | `validator` | 0.19 | MEDIUM | Rule-based validation |
| jsonschema | `jsonschema` | 0.26 | HIGH | JSON Schema validation |
| orjson | `serde_json` or `simd-json` | 1 / 0.14 | HIGH | serde_json for compatibility; simd-json for speed |
| msgpack | `rmp-serde` | 1 | HIGH | MessagePack via serde |
| protobuf | `prost` | 0.13 | HIGH | Protobuf code generation |
| toml (Python) | `toml` | 0.8 | HIGH | TOML via serde |
| pyyaml | `serde_yaml` | 0.9 | HIGH | YAML via serde |
| python-rapidjson | `serde_json` | 1 | HIGH | Fast JSON |

### CLI Frameworks

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| click | `clap` | 4 | HIGH | Decorators -> derive macros |
| typer | `clap` | 4 | HIGH | Type hints -> derive macros; natural mapping |
| argparse (stdlib) | `clap` | 4 | HIGH | ArgumentParser -> derive struct |
| fire | `clap` | 4 | MEDIUM | Auto-CLI from functions; manual in Rust |
| rich | `indicatif` + `colored` + `comfy-table` | 0.17 / 3 / 7 | MEDIUM | Progress + colors + tables |
| tqdm | `indicatif` | 0.17 | HIGH | Progress bar; `.wrap_iter()` |
| colorama | `colored` | 3 | HIGH | Terminal colors |
| tabulate | `comfy-table` or `tabled` | 7 / 0.16 | HIGH | Table formatting |
| prompt-toolkit | `dialoguer` + `rustyline` | 0.11 / 14 | MEDIUM | Interactive prompts + readline |
| questionary | `dialoguer` | 0.11 | HIGH | Interactive question prompts |

```rust
// clap replacing click/typer
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "myapp", version, about = "My CLI application")]
struct Cli {
    /// Enable verbose output
    #[arg(short, long)]
    verbose: bool,

    /// Configuration file path
    #[arg(short, long, default_value = "config.toml")]
    config: std::path::PathBuf,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run the server
    Serve {
        /// Port to listen on
        #[arg(short, long, default_value_t = 8000)]
        port: u16,
    },
    /// Run database migrations
    Migrate {
        /// Rollback N migrations
        #[arg(long)]
        rollback: Option<u32>,
    },
    /// Show system status
    Status,
}
```

### Testing

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| pytest | Built-in `#[test]` | - | HIGH | `cargo test`; no framework needed |
| pytest-asyncio | `#[tokio::test]` | - | HIGH | Built into tokio |
| unittest | Built-in `#[test]` | - | HIGH | `assert_eq!`, `assert!` macros |
| unittest.mock | `mockall` | 0.13 | HIGH | `#[automock]` on traits |
| pytest-mock | `mockall` | 0.13 | HIGH | Mock injection via trait objects |
| hypothesis | `proptest` | 1 | HIGH | Property-based testing |
| faker | `fake` | 3 | HIGH | Fake data generation |
| factory-boy | Builder pattern (manual) | - | MEDIUM | No equivalent; use builder structs |
| responses | `wiremock` | 0.6 | HIGH | HTTP response mocking |
| freezegun | `mockall` (mock `Utc::now`) | 0.13 | MEDIUM | Inject clock trait |
| pytest-cov | `cargo-llvm-cov` | - | HIGH | Coverage via `cargo llvm-cov` |
| coverage | `cargo-llvm-cov` | - | HIGH | LLVM-based coverage |
| pytest-xdist | `cargo test` (parallel by default) | - | HIGH | Tests run in parallel by default |
| tox | `cargo test` + CI | - | HIGH | Multi-env -> CI matrix |

```rust
// Testing patterns replacing pytest
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_creation() {
        let user = User::new("Alice".into(), "alice@example.com".into());
        assert_eq!(user.name, "Alice");
        assert_eq!(user.email, "alice@example.com");
    }

    #[tokio::test]
    async fn test_fetch_user() {
        let pool = setup_test_db().await;
        let user = find_user(&pool, 1).await.unwrap();
        assert!(user.is_some());
    }

    // Property-based test (hypothesis equivalent)
    use proptest::prelude::*;
    proptest! {
        #[test]
        fn test_email_validation(email in "[a-z]+@[a-z]+\\.[a-z]+") {
            assert!(User::validate_email(&email));
        }
    }
}
```

### Logging and Observability

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| logging (stdlib) | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | HIGH | `logging.info()` -> `tracing::info!()` |
| loguru | `tracing` | 0.1 | HIGH | Similar structured logging ergonomics |
| structlog | `tracing` | 0.1 | HIGH | Structured logging is tracing's core |
| sentry-sdk | `sentry` | 0.35 | HIGH | Official Rust SDK |
| prometheus-client | `metrics` + `metrics-exporter-prometheus` | 0.23 / 0.16 | HIGH | Prometheus metrics |
| opentelemetry-python | `opentelemetry` + `tracing-opentelemetry` | 0.28 / 0.28 | HIGH | OTEL tracing bridge |
| datadog | `tracing` + datadog exporter | 0.1 | MEDIUM | Via OTEL or DD agent |

### Environment and Configuration

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| python-dotenv | `dotenvy` | 0.15 | HIGH | `.env` file loading |
| pydantic-settings | `config` + `envy` | 0.14 / 0.4 | MEDIUM | Typed settings from env |
| configparser (stdlib) | `config` | 0.14 | HIGH | INI file parsing via config crate |
| os.environ (stdlib) | `std::env::var` | - | HIGH | Built-in; no crate needed |
| python-decouple | `dotenvy` + `envy` | 0.15 / 0.4 | HIGH | Env var with type casting |
| dynaconf | `config` | 0.14 | MEDIUM | Multi-environment config |

### Authentication and Security

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| pyjwt | `jsonwebtoken` | 9 | HIGH | `jwt.encode()` -> `encode()`, `jwt.decode()` -> `decode()` |
| python-jose | `jsonwebtoken` | 9 | HIGH | JOSE/JWT implementation |
| passlib | `argon2` | 0.5 | HIGH | Password hashing; prefer Argon2id |
| bcrypt | `bcrypt` | 0.16 | HIGH | Direct mapping |
| cryptography | `ring` + `rustls` | 0.17 | HIGH | General crypto primitives |
| hashlib (stdlib) | `sha2` + `md-5` | 0.10 | HIGH | Hash functions |
| secrets (stdlib) | `rand` | 0.8 | HIGH | `secrets.token_hex()` -> `rand::thread_rng()` |
| itsdangerous | Manual HMAC + `ring` | 0.17 | MEDIUM | Signed tokens via HMAC |
| authlib | `oauth2-rs` | 5 | MEDIUM | OAuth2 client/server |
| python-social-auth | Manual + `oauth2-rs` | 5 | LOW | Social login; assemble from parts |

### Task Queues and Background Jobs

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| celery | `apalis` or `tokio::spawn` + `mpsc` | 0.6 | MEDIUM | apalis for Redis-backed queue |
| dramatiq | `apalis` | 0.6 | MEDIUM | Actor-based task processing |
| rq (Redis Queue) | `apalis` | 0.6 | MEDIUM | Redis-backed job queue |
| huey | `apalis` | 0.6 | MEDIUM | Lightweight task queue |
| arq | `apalis` | 0.6 | MEDIUM | Async Redis job queue |
| schedule | `tokio-cron-scheduler` | 0.13 | HIGH | Cron-based scheduling |
| apscheduler | `tokio-cron-scheduler` | 0.13 | HIGH | Scheduled job execution |

### Caching

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| redis-py | `redis` | 0.27 | HIGH | Sync and async Redis client |
| cachetools | `moka` | 0.12 | HIGH | In-memory TTL cache |
| diskcache | `sled` or custom file cache | 0.34 | MEDIUM | Embedded database as cache |
| pylibmc / python-memcached | `memcache` | 0.2 | MEDIUM | Memcached client |
| aiocache | `moka` (in-memory) or `redis` | 0.12 / 0.27 | HIGH | Async cache backends |
| functools.lru_cache | `cached` or `moka` | 0.54 / 0.12 | HIGH | Function-level caching |

### Date and Time

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| datetime (stdlib) | `chrono` | 0.4 | HIGH | Direct type mapping |
| dateutil | `chrono` | 0.4 | HIGH | Parsing + relative deltas |
| arrow | `chrono` | 0.4 | HIGH | Human-friendly dates |
| pendulum | `chrono` + `chrono-tz` | 0.4 | HIGH | Timezone-aware datetimes |
| pytz | `chrono-tz` | 0.10 | HIGH | Timezone database |
| babel (dates) | `chrono` + `icu` | 0.4 | LOW | Locale-aware formatting needs ICU |

### File System and I/O

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| pathlib (stdlib) | `std::path::PathBuf` | - | HIGH | Built-in path handling |
| os / os.path (stdlib) | `std::fs` + `std::path` | - | HIGH | Built-in |
| shutil (stdlib) | `std::fs` + `fs_extra` | - / 1 | HIGH | Copy/move/remove operations |
| glob (stdlib) | `glob` | 0.3 | HIGH | File pattern matching |
| watchdog | `notify` | 7 | HIGH | File system watching |
| aiofiles | `tokio::fs` | - | HIGH | Async file I/O |
| tempfile (stdlib) | `tempfile` | 3 | HIGH | Temporary files and directories |
| zipfile (stdlib) | `zip` | 2 | HIGH | ZIP archive handling |
| tarfile (stdlib) | `tar` + `flate2` | 0.4 / 1 | HIGH | TAR + gzip |
| gzip (stdlib) | `flate2` | 1 | HIGH | Gzip compression |
| io (stdlib) | `std::io` | - | HIGH | Read/Write traits |

### Networking

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| websockets | `tokio-tungstenite` | 0.24 | HIGH | Async WebSocket |
| socket (stdlib) | `tokio::net` | - | HIGH | TCP/UDP sockets |
| paramiko | `russh` | 0.46 | MEDIUM | SSH client/server |
| ftplib (stdlib) | `suppaftp` | 6 | MEDIUM | FTP client |
| smtplib (stdlib) | `lettre` | 0.11 | HIGH | SMTP email sending |
| dnspython | `trust-dns-resolver` | 0.24 | HIGH | DNS resolution |

### Regex and Text Processing

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| re (stdlib) | `regex` | 1 | HIGH | No backtracking (safer, faster) |
| regex (PyPI) | `regex` (Rust) | 1 | HIGH | Direct mapping |
| jinja2 | `tera` | 1 | HIGH | Jinja2-compatible template engine |
| mako | `tera` | 1 | MEDIUM | Template engine |
| markdown | `pulldown-cmark` | 0.12 | HIGH | Markdown parser |
| beautifulsoup4 | `scraper` | 0.21 | HIGH | HTML parsing with CSS selectors |
| lxml | `scraper` + `quick-xml` | 0.21 / 0.37 | MEDIUM | HTML/XML parsing |
| html5lib | `scraper` | 0.21 | HIGH | HTML5 parser |

### Cryptography and Hashing

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| cryptography | `ring` | 0.17 | HIGH | General-purpose crypto |
| hashlib (stdlib) | `sha2` + `sha3` + `md-5` | 0.10 | HIGH | Hash algorithms |
| hmac (stdlib) | `hmac` | 0.12 | HIGH | HMAC computation |
| secrets (stdlib) | `rand` | 0.8 | HIGH | Secure random generation |
| certifi | `rustls-native-certs` or `webpki-roots` | 0.8 / 0.26 | HIGH | TLS certificate bundles |
| ssl (stdlib) | `rustls` or `openssl` | 0.23 / 0.10 | HIGH | TLS implementation |

### Image and Media

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| pillow | `image` | 0.25 | HIGH | Image loading/saving/manipulation |
| opencv-python | `opencv` (Rust bindings) | 0.93 | MEDIUM | OpenCV bindings |
| imageio | `image` | 0.25 | HIGH | Image I/O |
| ffmpeg-python | `ffmpeg-next` | 7 | MEDIUM | FFmpeg bindings |

### Miscellaneous Utilities

| Python Package | Rust Crate | Version | Confidence | API Mapping Notes |
|---------------|------------|---------|------------|-------------------|
| typing-extensions | Not needed | - | HIGH | Type system is built into Rust |
| dataclasses (stdlib) | `struct` + `#[derive]` | - | HIGH | Built into language |
| enum (stdlib) | `enum` | - | HIGH | Built into language |
| collections (stdlib) | `std::collections` | - | HIGH | HashMap, BTreeMap, VecDeque, etc. |
| itertools | `itertools` | 0.13 | HIGH | Same name! Extended iterator methods |
| more-itertools | `itertools` | 0.13 | MEDIUM | Most patterns covered |
| functools (stdlib) | Closures + methods | - | HIGH | No `partial`; use closures |
| copy (stdlib) | `Clone` trait | - | HIGH | `.clone()` for deep copy |
| abc (stdlib) | `trait` | - | HIGH | Abstract base classes -> traits |
| contextlib | RAII + Drop | - | HIGH | Context managers -> Drop |
| attrs | `struct` + `#[derive]` | - | HIGH | Attribute-based classes |
| semver | `semver` | 1 | HIGH | Semantic versioning |
| packaging | `semver` | 1 | HIGH | Version parsing |
| urllib.parse (stdlib) | `url` | 2 | HIGH | URL parsing |
| base64 (stdlib) | `base64` | 0.22 | HIGH | Base64 encoding |
| uuid (stdlib) | `uuid` | 1 | HIGH | UUID generation and parsing |
| decimal (stdlib) | `rust_decimal` | 1 | HIGH | Arbitrary precision decimal |
| ipaddress (stdlib) | `std::net` | - | HIGH | IP address types built-in |
| json (stdlib) | `serde_json` | 1 | HIGH | JSON serialization |
| pickle | `bincode` or `serde_json` | 2 / 1 | MEDIUM | No pickle equiv; use portable format |
| shelve | `sled` or `redb` | 0.34 / 2 | MEDIUM | Key-value storage |
| subprocess (stdlib) | `std::process::Command` or `tokio::process` | - | HIGH | Process spawning |
| multiprocessing (stdlib) | `rayon` | 1 | HIGH | Parallel computation |
| threading (stdlib) | `std::thread` or `tokio::spawn` | - | HIGH | Threading primitives |
| concurrent.futures | `rayon` or `tokio::spawn` | 1 | HIGH | Thread/process pool |
| typing (stdlib) | Built-in type system | - | HIGH | Rust is statically typed |
| pprint (stdlib) | `Debug` trait + `dbg!()` | - | HIGH | Debug printing |
| textwrap (stdlib) | `textwrap` | 0.16 | HIGH | Text wrapping |
| difflib (stdlib) | `similar` | 2 | HIGH | Text diffing |
| heapq (stdlib) | `std::collections::BinaryHeap` | - | HIGH | Priority queue |
| bisect (stdlib) | `Vec::binary_search` | - | HIGH | Binary search on sorted vec |
| enum34 | `enum` (built-in) | - | HIGH | Enums are a language feature |

## Template

```markdown
# Dependency Mapping (Python -> Rust)

Source: {project_name}
Generated: {date}

## Summary

| Total Dependencies | Mapped (HIGH) | Mapped (MEDIUM) | Mapped (LOW) | No Equivalent |
|-------------------|---------------|-----------------|--------------|---------------|
| {count} | {count} | {count} | {count} | {count} |

## Dependency Mapping Table

| # | Python Package | Version | Purpose | Rust Crate | Crate Version | Confidence | Notes |
|---|---------------|---------|---------|------------|---------------|------------|-------|
| 1 | fastapi | 0.115 | HTTP server | axum + utoipa | 0.8 / 5 | HIGH | Extractors replace decorators |
| 2 | sqlalchemy | 2.0 | ORM | sqlx | 0.8 | MEDIUM | Raw SQL with compile checks |
| 3 | pydantic | 2.10 | Validation | serde + validator | 1 / 0.19 | HIGH | Derive macros |
| 4 | celery | 5.4 | Task queue | apalis | 0.6 | MEDIUM | Redis-backed queue |
| ... | ... | ... | ... | ... | ... | ... | ... |

## No-Equivalent Dependencies

| Python Package | Purpose | Rust Strategy |
|---------------|---------|---------------|
| {package} | {purpose} | {implementation plan} |

## Cargo.toml

```toml
[dependencies]
# Web
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace", "compression-gzip"] }
utoipa = { version = "5", features = ["axum_extras"] }
utoipa-swagger-ui = { version = "9", features = ["axum"] }

# Database
sqlx = { version = "0.8", features = ["runtime-tokio", "tls-rustls", "postgres", "uuid", "chrono", "migrate"] }

# Serialization + Validation
serde = { version = "1", features = ["derive"] }
serde_json = "1"
validator = { version = "0.19", features = ["derive"] }

# Error handling
thiserror = "2"
anyhow = "1"

# HTTP client
reqwest = { version = "0.12", features = ["json"] }

# Observability
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# Auth
jsonwebtoken = "9"
argon2 = "0.5"

# Utilities
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
dotenvy = "0.15"
regex = "1"
rand = "0.8"

# Config
config = "0.14"
envy = "0.4"

[dev-dependencies]
tokio = { version = "1", features = ["test-util", "macros", "rt-multi-thread"] }
mockall = "0.13"
wiremock = "0.6"
pretty_assertions = "1"
proptest = "1"
fake = { version = "3", features = ["derive"] }
```
```

## Completeness Check

- [ ] Every Python dependency in requirements.txt / pyproject.toml is listed
- [ ] Confidence level is assigned for every mapping
- [ ] Dependencies with NO_EQUIVALENT have an alternative strategy
- [ ] Version numbers are current and correct (axum 0.8, tokio 1, sqlx 0.8, etc.)
- [ ] Compilable code examples are provided for major crate categories
- [ ] Complete `Cargo.toml` is generated with all dependencies
- [ ] Feature flags are specified where needed (sqlx features, serde features)
- [ ] Dev-dependencies are separated from production dependencies
- [ ] Python stdlib modules are mapped to Rust stdlib equivalents
- [ ] Summary table shows counts by confidence level
- [ ] Migration notes explain API differences for MEDIUM confidence mappings
