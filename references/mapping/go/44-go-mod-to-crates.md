# 44 - Go Module/Stdlib to Rust Crate Mapping

**Output**: Contributes to `.migration-plan/mappings/dependency-mapping.md`

## Purpose

Map every Go standard library package and third-party module dependency to its Rust crate equivalent. This serves as a comprehensive lookup table for the migration. Every `import` statement in the Go source must have a concrete Rust crate recommendation with version, confidence level, and API mapping notes. The goal is to eliminate guesswork during implementation by providing a pre-researched, vetted crate for every dependency.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `dependency-tree.md` -- complete list of Go module dependencies from `go.mod` and all imports
- `architecture.md` -- identifies which packages are used in which modules
- `type-catalog.md` -- types from external packages that need mapping

Extract every instance of:
- Standard library imports (`fmt`, `net/http`, `encoding/json`, etc.)
- Third-party module imports from `go.mod`
- Transitive dependencies that surface in the API
- Build tool dependencies (`go generate`, linters, etc.)

### Step 2: For each Go package, determine Rust crate equivalent

Use the reference tables below. For each dependency:
1. Find the matching Rust crate(s)
2. Verify the crate version is current and maintained
3. Note API differences (sync vs async, error handling, initialization)
4. Note confidence level: High (direct equivalent), Medium (similar but different API), Low (no direct equivalent, requires custom code)

### Step 3: Produce dependency mapping document

For EACH Go import, produce:
1. Go package path
2. Rust crate name and version
3. Confidence level
4. API mapping notes (key differences)
5. Feature flags needed (if any)

## Reference Tables

### HTTP Server

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `net/http` (stdlib server) | `axum` | 0.8 | High | Async, tower-based middleware, extractors |
| `net/http` (stdlib server) | `actix-web` | 4 | High | Actor-based, mature, slightly different API |
| `github.com/gin-gonic/gin` | `axum` | 0.8 | High | Gin routes -> axum Router, middleware -> tower layers |
| `github.com/labstack/echo` | `axum` | 0.8 | High | Echo groups -> axum nested routers |
| `github.com/gofiber/fiber` | `axum` | 0.8 | Medium | Fiber is Express-like; axum is more idiomatic Rust |
| `github.com/go-chi/chi` | `axum` | 0.8 | High | Chi router -> axum Router, both composable |
| `github.com/gorilla/mux` | `axum` | 0.8 | High | Gorilla routes -> axum routing |
| `github.com/gorilla/websocket` | `axum` + `tokio-tungstenite` | 0.8 / 0.24 | High | WebSocket upgrade via axum extractors |
| `net/http/httptest` | `axum-test` | 16 | High | Test server and client |

### HTTP Client

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `net/http` (stdlib client) | `reqwest` | 0.12 | High | Async by default, connection pooling built-in |
| `github.com/go-resty/resty` | `reqwest` | 0.12 | High | Resty convenience -> reqwest builder pattern |
| `github.com/hashicorp/go-retryablehttp` | `reqwest` + `reqwest-retry` | 0.12 / 0.7 | High | Retry middleware via tower |

### Database

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `database/sql` | `sqlx` | 0.8 | High | Async, compile-time query checking, multi-DB |
| `database/sql` | `diesel` | 2 | High | Sync, type-safe query builder, code-gen |
| `github.com/jmoiron/sqlx` | `sqlx` (Rust) | 0.8 | High | Same name, similar ergonomics |
| `github.com/jackc/pgx` | `sqlx` with `postgres` feature | 0.8 | High | pgx -> sqlx PgPool |
| `github.com/go-sql-driver/mysql` | `sqlx` with `mysql` feature | 0.8 | High | MySQL driver |
| `github.com/mattn/go-sqlite3` | `sqlx` with `sqlite` feature | 0.8 | High | SQLite driver |
| `go.mongodb.org/mongo-driver` | `mongodb` | 3 | High | Official MongoDB driver |
| `gorm.io/gorm` | `sea-orm` | 1 | Medium | ORM with async, migrations, different API |
| `gorm.io/gorm` | `diesel` | 2 | Medium | Sync ORM, code-gen approach |
| `github.com/golang-migrate/migrate` | `sqlx` migrations or `sea-orm-migration` | - | Medium | Migration tooling |
| `github.com/pressly/goose` | `sqlx` migrations | - | Medium | SQL-based migrations |

### Redis

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/redis/go-redis` | `redis` | 0.27 | High | Async with `tokio-comp` feature |
| `github.com/gomodule/redigo` | `redis` | 0.27 | High | Connection pooling via `deadpool-redis` |

### Serialization

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `encoding/json` | `serde` + `serde_json` | 1 / 1 | High | Derive macros, zero-copy parsing available |
| `encoding/xml` | `serde` + `quick-xml` | 1 / 0.37 | High | XML serde integration |
| `gopkg.in/yaml.v3` | `serde` + `serde_yaml` | 1 / 0.9 | High | YAML serde integration |
| `github.com/BurntSushi/toml` | `serde` + `toml` | 1 / 0.8 | High | TOML serde integration |
| `github.com/pelletier/go-toml` | `serde` + `toml` | 1 / 0.8 | High | Same crate |
| `google.golang.org/protobuf` | `prost` | 0.13 | High | Protobuf code generation |
| `github.com/vmihailenco/msgpack` | `rmp-serde` | 1 | High | MessagePack serde |
| `encoding/csv` | `csv` | 1 | High | CSV reader/writer with serde |
| `encoding/binary` | `byteorder` or `bytes` | 1 / 1 | High | Binary encoding |
| `encoding/base64` | `base64` (crate) | 0.22 | High | Base64 encoding/decoding |
| `encoding/hex` | `hex` | 0.4 | High | Hex encoding/decoding |

### CLI

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/spf13/cobra` | `clap` | 4 | High | Derive macros, subcommands, completions |
| `github.com/urfave/cli` | `clap` | 4 | High | Same target |
| `github.com/spf13/pflag` | `clap` | 4 | High | Integrated flag parsing |
| `github.com/AlecAivazis/survey` | `dialoguer` | 0.11 | High | Interactive prompts |
| `github.com/fatih/color` | `colored` or `owo-colors` | 2 / 4 | High | Terminal colors |
| `github.com/schollz/progressbar` | `indicatif` | 0.17 | High | Progress bars and spinners |
| `flag` (stdlib) | `clap` | 4 | High | Stdlib flag replacement |

### Logging and Tracing

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `log` (stdlib) | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | High | Structured logging + spans |
| `log/slog` (Go 1.21+) | `tracing` | 0.1 | High | Both are structured logging |
| `go.uber.org/zap` | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | High | Structured, high-performance |
| `github.com/sirupsen/logrus` | `tracing` | 0.1 | High | Field-based structured logging |
| `github.com/rs/zerolog` | `tracing` | 0.1 | High | Zero-alloc structured logging |

### Configuration

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/spf13/viper` | `config` | 0.14 | High | Multi-source config (file, env, defaults) |
| `github.com/kelseyhightower/envconfig` | `envy` or `config` | 0.4 / 0.14 | High | Env-based config |
| `github.com/joho/godotenv` | `dotenvy` | 0.15 | High | .env file loading |
| `os` (stdlib, env vars) | `std::env` | - | High | Direct stdlib equivalent |

### Testing

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `testing` (stdlib) | Built-in `#[test]` | - | High | Native test framework |
| `github.com/stretchr/testify/assert` | Built-in `assert!`, `assert_eq!` | - | High | No external crate needed |
| `github.com/stretchr/testify/require` | `assert!` (panics on failure) | - | High | All asserts panic by default |
| `github.com/stretchr/testify/suite` | `#[cfg(test)] mod tests` | - | Medium | Use setup/teardown functions |
| `github.com/stretchr/testify/mock` | `mockall` | 0.13 | High | Auto-generated mocks |
| `github.com/golang/mock` (gomock) | `mockall` | 0.13 | High | Similar mock generation |
| `net/http/httptest` | `axum-test` | 16 | High | HTTP handler testing |
| `github.com/jarcoal/httpmock` | `wiremock` | 0.6 | High | HTTP server mocking |
| `testing/fstest` | `tempfile` | 3 | High | Temporary file/dir for tests |

### Cryptography

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `crypto/sha256` | `sha2` | 0.10 | High | SHA-2 family |
| `crypto/sha512` | `sha2` | 0.10 | High | SHA-512 |
| `crypto/md5` | `md5` | 0.7 | High | MD5 (legacy use only) |
| `crypto/hmac` | `hmac` | 0.12 | High | HMAC |
| `crypto/aes` | `aes` + `aes-gcm` | 0.8 / 0.10 | High | AES encryption |
| `crypto/rsa` | `rsa` | 0.9 | High | RSA operations |
| `crypto/ecdsa` | `ecdsa` + `p256` | 0.16 / 0.13 | High | ECDSA signing |
| `crypto/ed25519` | `ed25519-dalek` | 2 | High | Ed25519 signing |
| `crypto/rand` | `rand` | 0.9 | High | Cryptographic RNG |
| `crypto/tls` | `rustls` | 0.23 | High | TLS implementation |
| `crypto/x509` | `x509-parser` or `webpki` | 0.16 / 0.22 | Medium | X.509 cert parsing |
| `golang.org/x/crypto/bcrypt` | `bcrypt` | 0.16 | High | Password hashing |
| `golang.org/x/crypto/argon2` | `argon2` | 0.5 | High | Password hashing (recommended) |
| `golang.org/x/crypto/ssh` | `russh` | 0.46 | Medium | SSH client/server |

### Authentication

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/golang-jwt/jwt` | `jsonwebtoken` | 9 | High | JWT creation and validation |
| `github.com/dgrijalva/jwt-go` (deprecated) | `jsonwebtoken` | 9 | High | Same target |
| `golang.org/x/oauth2` | `oauth2` | 4 | Medium | OAuth2 client flows |
| `github.com/coreos/go-oidc` | `openidconnect` | 4 | Medium | OIDC client |

### gRPC

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `google.golang.org/grpc` | `tonic` | 0.12 | High | gRPC server and client |
| `google.golang.org/protobuf` | `prost` | 0.13 | High | Protobuf types, used with tonic |
| `google.golang.org/grpc/status` | `tonic::Status` | 0.12 | High | gRPC status codes |
| `google.golang.org/grpc/metadata` | `tonic::metadata` | 0.12 | High | gRPC metadata/headers |
| `google.golang.org/grpc/credentials` | `tonic` + `rustls` | 0.12 / 0.23 | High | TLS for gRPC |

### Message Queues

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/IBM/sarama` (Kafka) | `rdkafka` | 0.36 | High | librdkafka bindings (requires C lib) |
| `github.com/segmentio/kafka-go` | `rdkafka` | 0.36 | High | Same target |
| `github.com/rabbitmq/amqp091-go` | `lapin` | 2 | High | Async AMQP client |
| `github.com/streadway/amqp` (deprecated) | `lapin` | 2 | High | Same target |
| `github.com/nats-io/nats.go` | `async-nats` | 0.38 | High | NATS client |
| `cloud.google.com/go/pubsub` | `google-cloud-pubsub` | 0.25 | Medium | GCP Pub/Sub |

### File and I/O

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `os` | `std::fs`, `std::env` | - | High | Direct stdlib mapping |
| `io` | `std::io` | - | High | Reader/Writer traits |
| `io/fs` | `std::fs` | - | High | File system operations |
| `bufio` | `std::io::BufReader`, `BufWriter` | - | High | Buffered I/O |
| `path/filepath` | `std::path::Path`, `PathBuf` | - | High | Path manipulation |
| `os/exec` | `tokio::process::Command` | 1 | High | Process spawning |
| `github.com/fsnotify/fsnotify` | `notify` | 7 | High | File system watching |
| `github.com/spf13/afero` | `std::fs` (or custom trait) | - | Medium | Virtual filesystem (abstract via trait) |
| `archive/zip` | `zip` | 2 | High | ZIP archive handling |
| `archive/tar` | `tar` | 0.4 | High | Tar archive handling |
| `compress/gzip` | `flate2` | 1 | High | Gzip compression |
| `compress/zlib` | `flate2` | 1 | High | Zlib compression |
| `path` (stdlib) | `std::path` | - | High | Path operations |
| `filepath.Walk` | `walkdir` | 2 | High | Directory traversal |
| `embed` (Go 1.16+) | `include_str!` / `include_bytes!` | - | High | Embed files at compile time |
| `embed` (many files) | `rust-embed` | 8 | High | Embed directory of files |

### Concurrency

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `sync` | `std::sync`, `tokio::sync` | - | High | Mutex, RwLock, channels |
| `sync/atomic` | `std::sync::atomic` | - | High | Atomic types |
| `golang.org/x/sync/errgroup` | `tokio::task::JoinSet` | 1 | High | Concurrent task groups |
| `golang.org/x/sync/semaphore` | `tokio::sync::Semaphore` | 1 | High | Counting semaphore |
| `golang.org/x/sync/singleflight` | `moka` (with cache) or custom | 0.12 | Medium | Dedup concurrent calls |

### Template Engines

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `html/template` | `tera` | 1 | High | Jinja2-like templates, runtime |
| `text/template` | `tera` | 1 | High | Same crate for text templates |
| `html/template` | `askama` | 0.12 | High | Compile-time templates (type-safe) |
| `github.com/a-h/templ` | `askama` | 0.12 | High | Component templates |

### Time

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `time` (stdlib) | `chrono` | 0.4 | High | Date, time, timezone handling |
| `time` (stdlib) | `time` (Rust crate) | 0.3 | High | Alternative to chrono, lighter |
| `time.Duration` | `std::time::Duration` | - | High | Duration type |
| `time.Now()` | `chrono::Utc::now()` or `std::time::Instant::now()` | - | High | Current time |
| `time.Parse` | `chrono::DateTime::parse_from_str` | 0.4 | High | Time parsing |
| `time.Sleep` | `tokio::time::sleep` (async) | 1 | High | Async sleep |
| `github.com/robfig/cron` | `tokio-cron-scheduler` | 0.13 | High | Cron job scheduling |

### Networking

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `net` | `tokio::net` | 1 | High | TCP/UDP async networking |
| `net/url` | `url` | 2 | High | URL parsing |
| `net/smtp` | `lettre` | 0.11 | High | Email sending |
| `net/http/cookiejar` | `reqwest::cookie::Jar` | 0.12 | High | Cookie management |
| `github.com/miekg/dns` | `hickory-dns` (was trust-dns) | 0.25 | High | DNS client/server |

### Strings and Formatting

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `fmt` | `std::fmt`, `format!` macro | - | High | String formatting |
| `strings` | `str` methods, `String` methods | - | High | String manipulation |
| `strconv` | `.parse::<T>()`, `.to_string()` | - | High | String conversion |
| `regexp` | `regex` | 1 | High | Regular expressions |
| `unicode` | `unicode-segmentation` | 1 | High | Unicode handling |
| `unicode/utf8` | Built-in (Rust strings are UTF-8) | - | High | Native UTF-8 |
| `text/tabwriter` | `comfy-table` | 7 | High | Tabular text output |

### UUID and ID Generation

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/google/uuid` | `uuid` | 1 | High | UUID v4, v7, parsing |
| `github.com/rs/xid` | `xid` or `ulid` | - / 1 | High | Sortable IDs |
| `github.com/oklog/ulid` | `ulid` | 1 | High | ULID generation |
| `github.com/bwmarrin/snowflake` | `snowflake` | - | Medium | Distributed IDs |

### Validation

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/go-playground/validator` | `validator` | 0.19 | High | Struct validation with derive |
| Custom validation | `garde` | 0.22 | High | Alternative validation crate |

### Scheduling and Background Jobs

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/robfig/cron` | `tokio-cron-scheduler` | 0.13 | High | Cron-based scheduling |
| `github.com/hibiken/asynq` | Custom with `redis` + `tokio` | - | Low | No direct equivalent; build with channels |

### Cloud SDKs

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/aws/aws-sdk-go-v2` | `aws-sdk-*` | 1 | High | Official AWS SDK for Rust |
| `cloud.google.com/go` | `google-cloud-*` | varies | Medium | GCP Rust SDK (some services) |
| `github.com/Azure/azure-sdk-for-go` | `azure_*` | varies | Medium | Azure Rust SDK |

### Observability

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `github.com/prometheus/client_golang` | `prometheus` or `metrics` | 0.13 / 0.24 | High | Prometheus metrics |
| `go.opentelemetry.io/otel` | `opentelemetry` | 0.28 | High | OpenTelemetry SDK |
| `go.opentelemetry.io/otel/trace` | `opentelemetry` + `tracing-opentelemetry` | 0.28 / 0.28 | High | Distributed tracing |
| `github.com/DataDog/dd-trace-go` | `opentelemetry` with DD exporter | 0.28 | Medium | Use OTLP exporter to DD |
| `expvar` (stdlib) | `metrics` | 0.24 | Medium | Runtime metrics |

### Miscellaneous

| Go Package | Rust Crate | Version | Confidence | Notes |
|-----------|-----------|---------|------------|-------|
| `math` | `std::f64`, `num` crate | - / 0.4 | High | Math operations |
| `math/rand` | `rand` | 0.9 | High | Random number generation |
| `sort` | `.sort()`, `.sort_by()` methods | - | High | Slice sorting (built-in) |
| `container/heap` | `std::collections::BinaryHeap` | - | High | Priority queue |
| `container/list` | `std::collections::LinkedList` | - | High | Doubly-linked list |
| `container/ring` | `VecDeque` | - | High | Ring buffer equivalent |
| `reflect` | Limited; use `serde` or proc macros | - | Low | Rust has no runtime reflection |
| `unsafe` | `unsafe {}` blocks | - | High | Unsafe operations |
| `runtime` | `tokio::runtime` | 1 | Medium | Runtime control |
| `runtime/debug` | `std::backtrace` | - | Medium | Stack traces |
| `bytes` | `bytes` (crate) | 1 | High | Byte buffer utilities |
| `github.com/cenkalti/backoff` | `backoff` | 0.4 | High | Exponential backoff |
| `github.com/avast/retry-go` | `backoff` | 0.4 | High | Retry with backoff |
| `github.com/patrickmn/go-cache` | `moka` | 0.12 | High | In-memory cache with TTL |
| `github.com/hashicorp/golang-lru` | `moka` or `lru` | 0.12 / 0.12 | High | LRU cache |

## Template

```markdown
# Go Module to Rust Crate Mapping

Source: {project_name}
Generated: {date}

## go.mod Dependencies

```
module {module_name}

go {version}

require (
    {list from go.mod}
)
```

## Cargo.toml Dependencies

```toml
[dependencies]
# HTTP
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace", "compression-gzip"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Database
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "chrono", "uuid"] }

# Error handling
thiserror = "2"
anyhow = "1"

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# ... (add all required crates)

[dev-dependencies]
mockall = "0.13"
axum-test = "16"
tokio = { version = "1", features = ["test-util", "macros"] }
```

## Dependency Mapping Table

| # | Go Package | Usage | Rust Crate | Version | Confidence | Feature Flags | Notes |
|---|-----------|-------|-----------|---------|------------|---------------|-------|
| 1 | `net/http` | HTTP server | `axum` | 0.8 | High | - | Router + handlers |
| 2 | `encoding/json` | JSON | `serde_json` | 1 | High | - | With `serde` derive |
| 3 | `database/sql` | Postgres | `sqlx` | 0.8 | High | `postgres` | Async queries |
| ... | ... | ... | ... | ... | ... | ... | ... |

## API Migration Notes

### {Go Package} -> {Rust Crate}

**Key differences**:
- {difference 1}
- {difference 2}

**Migration example**:

Go:
```go
// Go code
```

Rust:
```rust
// Rust equivalent
```

## Missing Equivalents

| # | Go Package | Purpose | Rust Strategy | Effort |
|---|-----------|---------|---------------|--------|
| 1 | `reflect` | Runtime reflection | Proc macros or manual | High |
| 2 | {package} | {purpose} | {strategy} | {effort} |

## Build Tool Mapping

| Go Tool | Rust Equivalent | Notes |
|---------|----------------|-------|
| `go build` | `cargo build` | |
| `go test` | `cargo test` | |
| `go vet` | `cargo clippy` | Linting |
| `go fmt` | `cargo fmt` (rustfmt) | |
| `go generate` | `build.rs` + proc macros | |
| `go mod tidy` | (automatic with Cargo) | |
| `golangci-lint` | `cargo clippy` | |
| `go doc` | `cargo doc` | |
| `go run` | `cargo run` | |
```

## Completeness Check

- [ ] Every import in the Go source has a Rust crate mapping
- [ ] Every entry in `go.mod` has a Rust crate mapping
- [ ] Every crate version is current and the crate is actively maintained
- [ ] Confidence level is assigned (High/Medium/Low) for each mapping
- [ ] Feature flags are specified for crates that need them
- [ ] API migration notes cover key differences for Medium/Low confidence mappings
- [ ] Missing equivalents are documented with alternative strategies
- [ ] `Cargo.toml` is complete with all required dependencies
- [ ] Build tool equivalents are documented
- [ ] Transitive dependencies that surface in the API are mapped
- [ ] Dev-dependencies (testing, mocking) are mapped separately
