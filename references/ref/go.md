# Go -> Rust Reference

## Primitive Types

| Go | Rust | Notes |
|---|---|---|
| `bool` | `bool` | |
| `int` | `i64` | Go int is platform-dependent; use i64 |
| `int8` | `i8` | |
| `int16` | `i16` | |
| `int32` / `rune` | `i32` | rune = Unicode code point |
| `int64` | `i64` | |
| `uint` | `u64` | |
| `uint8` / `byte` | `u8` | |
| `uint16` | `u16` | |
| `uint32` | `u32` | |
| `uint64` | `u64` | |
| `uintptr` | `usize` | |
| `float32` | `f32` | |
| `float64` | `f64` | |
| `complex64` | `num::Complex<f32>` | `num` crate |
| `complex128` | `num::Complex<f64>` | `num` crate |
| `string` | `String` (owned) / `&str` (borrowed) | |
| `[]byte` | `Vec<u8>` (owned) / `&[u8]` (borrowed) | |
| `[]T` | `Vec<T>` (owned) / `&[T]` (borrowed) | |
| `[N]T` | `[T; N]` | |
| `map[K]V` | `HashMap<K, V>` | `use std::collections::HashMap` |
| `chan T` | `mpsc::Sender<T>` / `mpsc::Receiver<T>` | tokio::sync::mpsc |
| `func(A) B` | `fn(A) -> B` or `Fn(A) -> B` | fn ptr vs trait |
| `error` | `Result<T, E>` | thiserror / anyhow |
| `interface{}` / `any` | enum (preferred) / `Box<dyn Any>` / `T` generic | prefer enum when types known |
| `*T` (nullable) | `Option<Box<T>>` or `Option<&T>` | |
| `*T` (non-nil, owned) | `Box<T>` or `T` (move) | |
| `*T` (non-nil, borrowed, mutable) | `&mut T` | |
| `*T` (non-nil, borrowed, read) | `&T` | |
| `time.Time` | `chrono::DateTime<Utc>` | chrono crate |
| `time.Duration` | `std::time::Duration` | |
| `struct { fields }` | `struct { fields }` + `#[derive(...)]` | |
| `type Name = Existing` | `type Name = Existing;` | type alias |
| `type Name Underlying` | `struct Name(Underlying);` | newtype pattern |

## Error Handling Patterns

| Go | Rust |
|---|---|
| `if err != nil { return err }` | `?` operator |
| `if err != nil { return fmt.Errorf("ctx: %w", err) }` | `.context("ctx")?` (anyhow) or `.map_err(\|e\| ...)?` |
| `if err != nil { return nil, err }` | `?` (returns `Err(...)`) |
| `if err != nil { log; return }` | `if let Err(e) = ... { tracing::error!(...); return; }` |
| `if err != nil { log; continue }` | `match ... { Err(e) => { tracing::warn!(...); continue; } ... }` |
| `val, _ := SomeFunc()` | `.unwrap_or_default()` or `.ok()` |
| `(value, error)` return | `Result<T, E>` |
| `(value, bool)` return | `Option<T>` |
| `(v1, v2, error)` return | `Result<(T1, T2), E>` or `Result<Struct, E>` |
| `errors.New("msg")` | enum variant with `#[error("msg")]` (thiserror) |
| `fmt.Errorf("ctx: %w", err)` | `.with_context(\|\| format!("ctx"))` (anyhow) |
| `var ErrNotFound = errors.New(...)` | enum variant: `NotFound` in thiserror enum |
| `errors.Is(err, ErrX)` | `match err { MyError::X => ... }` |
| `errors.As(err, &target)` | `match` + nested pattern or `.downcast_ref()` |
| Custom error type (`Error() string`) | `#[derive(Debug, Error)]` struct/enum (thiserror) |
| `panic("msg")` (programming bug) | `panic!("msg")` |
| `panic("msg")` (recoverable) | Convert to `Result<T, E>` |
| `recover()` | `std::panic::catch_unwind` (rare) or framework handles |
| `Must*()` helpers | `.expect("msg")` or `.unwrap_or_else(\|e\| panic!(...))` |

## Concurrency Patterns

| Go | Rust | Crate |
|---|---|---|
| `go func() { ... }()` | `tokio::spawn(async { ... })` | tokio |
| `make(chan T)` (unbuffered) | `mpsc::channel(1)` | tokio |
| `make(chan T, n)` (buffered) | `mpsc::channel(n)` | tokio |
| `ch <- val` | `tx.send(val).await` | tokio |
| `val := <-ch` | `rx.recv().await` | tokio |
| `val, ok := <-ch` | `rx.recv().await` returns `Option<T>` | tokio |
| `close(ch)` | Drop the `Sender` | ownership |
| `for val := range ch` | `while let Some(val) = rx.recv().await` | tokio |
| `select { case ... }` | `tokio::select! { ... }` | tokio |
| `sync.WaitGroup` | `tokio::task::JoinSet` | tokio |
| `sync.Mutex` (lock held across await) | `tokio::sync::Mutex` | tokio |
| `sync.Mutex` (brief, no await) | `std::sync::Mutex` | std |
| `sync.RWMutex` | `tokio::sync::RwLock` or `std::sync::RwLock` | tokio/std |
| `sync.Once` | `std::sync::OnceLock` or `std::sync::LazyLock` | std |
| `sync.Map` | `dashmap::DashMap` | dashmap |
| `sync.Pool` | `object_pool` or manual | object-pool |
| `context.Context` (cancellation) | `CancellationToken` | tokio-util |
| `context.WithCancel` | `CancellationToken::new()` + `.child_token()` | tokio-util |
| `context.WithTimeout` | `tokio::time::timeout(dur, future)` | tokio |
| `context.WithDeadline` | `tokio::time::timeout_at(instant, future)` | tokio |
| `context.Value` | Struct fields or `tracing::Span` | tracing |
| `errgroup.Group` | `JoinSet` with error collection + cancel on first err | tokio |
| `time.After(d)` | `tokio::time::sleep(d)` | tokio |
| `time.NewTicker(d)` | `tokio::time::interval(d)` | tokio |
| `time.NewTimer(d)` | `tokio::time::sleep(d)` (one-shot) | tokio |
| `runtime.GOMAXPROCS` | Tokio runtime builder `.worker_threads(n)` | tokio |
| Worker pool (N goroutines + chan) | `JoinSet` + `Arc<Mutex<Receiver>>` | tokio |
| Fan-out/fan-in | `stream::select_all` or shared receiver | futures |
| Rate limiting (Ticker) | `tokio::time::interval` or `Semaphore` | tokio |
| `sync/atomic` | `std::sync::atomic` | std |
| `x/sync/semaphore` | `tokio::sync::Semaphore` | tokio |
| `x/sync/singleflight` | `moka` cache or custom dedup | moka |
| Graceful shutdown (signal + cancel) | `tokio::signal` + `CancellationToken` | tokio |

## Interface -> Trait Patterns

| Go | Rust |
|---|---|
| `type I interface { Method() }` | `pub trait I { fn method(&self); }` |
| Implicit satisfaction | Explicit `impl Trait for Type` required |
| Interface embedding (`ReadWriter` embeds `Reader`+`Writer`) | Supertrait: `trait ReadWriter: Reader + Writer {}` |
| `interface{}` / `any` (known types) | `enum` with variants (preferred) |
| `interface{}` / `any` (unknown types) | `Box<dyn Any + Send + Sync>` |
| `interface{}` / `any` (uniform per call) | Generics `<T>` |
| Interface as param (caller knows type) | `fn foo(x: &impl Trait)` or `fn foo<T: Trait>(x: &T)` |
| Interface as param (dynamic) | `fn foo(x: &dyn Trait)` |
| Interface slice `[]I` | `Vec<Box<dyn Trait>>` or `Vec<Arc<dyn Trait>>` |
| Interface in struct field | `Arc<dyn Trait>` (dynamic) or generic `<T: Trait>` (static) |
| Type assertion `v.(Type)` | `match` on enum variant or `.downcast_ref::<T>()` |
| Type switch `switch v.(type)` | Exhaustive `match` on enum |
| Async interface methods | `#[async_trait] pub trait T: Send + Sync { async fn ... }` |
| `var _ I = (*T)(nil)` (compile check) | Not needed; compiler enforces at `impl` block |
| Mock interface in tests | `#[cfg_attr(test, mockall::automock)]` on trait |
| `io.Reader` | `std::io::Read` |
| `io.Writer` | `std::io::Write` |
| `io.Closer` | `Drop` trait (automatic) |
| `io.ReadWriter` | `Read + Write` |
| `fmt.Stringer` | `std::fmt::Display` |
| `fmt.GoStringer` | `std::fmt::Debug` (`#[derive(Debug)]`) |
| `error` interface | `std::error::Error` (via thiserror) |
| `sort.Interface` | `Ord + PartialOrd + Eq + PartialEq` (`#[derive]`) |
| `json.Marshaler`/`Unmarshaler` | `serde::Serialize`/`Deserialize` (`#[derive]`) |
| `encoding.BinaryMarshaler` | `serde::Serialize` |
| `http.Handler` | Axum handler `async fn(req) -> impl IntoResponse` |
| `hash.Hash` | `std::hash::Hasher` |
| DI with interfaces | `Arc<dyn Trait>` (dynamic) or generics (static) |

## Go Module -> Crate Mapping

| Go Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| **HTTP Server** | | | |
| `net/http` (server) | `axum` | 0.8 | High |
| `gin-gonic/gin`, `echo`, `chi`, `gorilla/mux` | `axum` | 0.8 | High |
| `gorilla/websocket` | `axum` + `tokio-tungstenite` | 0.8/0.24 | High |
| `net/http/httptest` | `axum-test` | 16 | High |
| **HTTP Client** | | | |
| `net/http` (client), `go-resty/resty` | `reqwest` | 0.12 | High |
| `hashicorp/go-retryablehttp` | `reqwest` + `reqwest-retry` | 0.12/0.7 | High |
| **Database** | | | |
| `database/sql`, `jmoiron/sqlx`, `jackc/pgx` | `sqlx` | 0.8 | High |
| `go-sql-driver/mysql` | `sqlx` (mysql feature) | 0.8 | High |
| `mattn/go-sqlite3` | `sqlx` (sqlite feature) | 0.8 | High |
| `mongo-driver` | `mongodb` | 3 | High |
| `gorm.io/gorm` | `sea-orm` or `diesel` | 1/2 | Medium |
| `redis/go-redis`, `redigo` | `redis` (+ `deadpool-redis`) | 0.27 | High |
| **Serialization** | | | |
| `encoding/json` | `serde` + `serde_json` | 1/1 | High |
| `encoding/xml` | `serde` + `quick-xml` | 1/0.37 | High |
| `gopkg.in/yaml.v3` | `serde` + `serde_yaml` | 1/0.9 | High |
| `BurntSushi/toml` | `serde` + `toml` | 1/0.8 | High |
| `google.golang.org/protobuf` | `prost` | 0.13 | High |
| `vmihailenco/msgpack` | `rmp-serde` | 1 | High |
| `encoding/csv` | `csv` | 1 | High |
| `encoding/base64` | `base64` | 0.22 | High |
| **CLI** | | | |
| `spf13/cobra`, `urfave/cli`, `flag` | `clap` | 4 | High |
| `AlecAivazis/survey` | `dialoguer` | 0.11 | High |
| `fatih/color` | `colored` or `owo-colors` | 2/4 | High |
| `schollz/progressbar` | `indicatif` | 0.17 | High |
| **Logging** | | | |
| `log`, `slog`, `zap`, `logrus`, `zerolog` | `tracing` + `tracing-subscriber` | 0.1/0.3 | High |
| `prometheus/client_golang` | `prometheus` or `metrics` | 0.13/0.24 | High |
| `go.opentelemetry.io/otel` | `opentelemetry` | 0.28 | High |
| **Config** | | | |
| `spf13/viper` | `config` | 0.14 | High |
| `joho/godotenv` | `dotenvy` | 0.15 | High |
| **Testing** | | | |
| `testing`, `testify/assert` | Built-in `#[test]`, `assert_eq!` | - | High |
| `testify/mock`, `golang/mock` | `mockall` | 0.13 | High |
| `jarcoal/httpmock` | `wiremock` | 0.6 | High |
| `testing/fstest` | `tempfile` | 3 | High |
| **Crypto** | | | |
| `crypto/sha256`, `sha512` | `sha2` | 0.10 | High |
| `crypto/hmac` | `hmac` | 0.12 | High |
| `crypto/aes` | `aes` + `aes-gcm` | 0.8/0.10 | High |
| `crypto/rsa` | `rsa` | 0.9 | High |
| `crypto/ed25519` | `ed25519-dalek` | 2 | High |
| `crypto/rand` | `rand` | 0.9 | High |
| `crypto/tls` | `rustls` | 0.23 | High |
| `x/crypto/bcrypt` | `bcrypt` | 0.16 | High |
| `x/crypto/argon2` | `argon2` | 0.5 | High |
| **Auth** | | | |
| `golang-jwt/jwt` | `jsonwebtoken` | 9 | High |
| `x/oauth2` | `oauth2` | 4 | Medium |
| **gRPC** | | | |
| `google.golang.org/grpc` | `tonic` | 0.12 | High |
| `google.golang.org/protobuf` | `prost` | 0.13 | High |
| **Message Queues** | | | |
| `IBM/sarama`, `segmentio/kafka-go` | `rdkafka` | 0.36 | High |
| `rabbitmq/amqp091-go` | `lapin` | 2 | High |
| `nats-io/nats.go` | `async-nats` | 0.38 | High |
| **File / I/O** | | | |
| `os`, `io`, `bufio` | `std::fs`, `std::io` | - | High |
| `path/filepath` | `std::path::Path`/`PathBuf` | - | High |
| `os/exec` | `tokio::process::Command` | 1 | High |
| `fsnotify/fsnotify` | `notify` | 7 | High |
| `archive/zip` / `tar` | `zip` / `tar` | 2/0.4 | High |
| `compress/gzip` | `flate2` | 1 | High |
| `embed` | `rust-embed` or `include_str!` | 8/- | High |
| `filepath.Walk` | `walkdir` | 2 | High |
| **Networking** | | | |
| `net` | `tokio::net` | 1 | High |
| `net/url` | `url` | 2 | High |
| `net/smtp` | `lettre` | 0.11 | High |
| **Strings / IDs** | | | |
| `fmt`, `strings`, `strconv` | `std::fmt`, `str`/`String` methods, `.parse()` | - | High |
| `regexp` | `regex` | 1 | High |
| `google/uuid` | `uuid` | 1 | High |
| **Time** | | | |
| `time` | `chrono` | 0.4 | High |
| `robfig/cron` | `tokio-cron-scheduler` | 0.13 | High |
| **Misc** | | | |
| `math/rand` | `rand` | 0.9 | High |
| `sort` | `.sort()`, `.sort_by()` | - | High |
| `container/heap` | `std::collections::BinaryHeap` | - | High |
| `bytes` | `bytes` crate | 1 | High |
| `reflect` | `serde` / proc macros | - | Low |
| `cenkalti/backoff` | `backoff` | 0.4 | High |
| `patrickmn/go-cache`, `golang-lru` | `moka` | 0.12 | High |
| `go-playground/validator` | `validator` | 0.19 | High |
| `aws/aws-sdk-go-v2` | `aws-sdk-*` | 1 | High |

### Build Tools

| Go Tool | Rust Equivalent |
|---|---|
| `go build` / `go run` | `cargo build` / `cargo run` |
| `go test` | `cargo test` |
| `go vet` / `golangci-lint` | `cargo clippy` |
| `go fmt` | `cargo fmt` |
| `go generate` | `build.rs` + proc macros |
| `go doc` | `cargo doc` |

## Common Pattern Transforms

| Go Pattern | Rust Equivalent |
|---|---|
| Struct embedding (single) | Composition field + `Deref`/`DerefMut` impl |
| Struct embedding (multiple) | Composition + trait delegation |
| `defer f.Close()` | `Drop` trait (automatic) |
| `defer mu.Unlock()` | `MutexGuard` dropped at scope end |
| `defer` with custom logic | `scopeguard::defer!` or `scopeguard::guard` |
| `init()` function | `std::sync::LazyLock` or explicit init in `main()` |
| Table-driven tests | `rstest` (`#[rstest]` + `#[case]`) or `test_case` |
| `//go:build linux` | `#[cfg(target_os = "linux")]` |
| `//go:build integration` | `#[cfg(feature = "integration-tests")]` |
| `go generate stringer` | `strum::Display` derive macro |
| `go generate mockgen` | `mockall::automock` attribute |
| `go generate protoc` | `tonic-build` in `build.rs` |
| `internal/` package | `pub(crate)` visibility |
| Functional options `WithX()` | Builder pattern (manual or `bon` crate) |
| `iota` enum (sequential) | `enum` with `#[derive(Debug, Clone, Copy)]` + strum |
| `iota` bitmask (`1 << iota`) | `bitflags!` macro |
| Value receiver | `&self` |
| Pointer receiver | `&mut self` |
| `import _ "pkg"` (side effects) | Explicit init call in `main()` |
| `var _ I = (*T)(nil)` | Not needed (compiler enforces at `impl`) |
| Blank identifier `_, _ :=` | `let _ =` |
| `for _, v := range items` | `for v in &items` |
| `context.Value` propagation | Struct fields or `tracing::Span` |
| Goroutine leak prevention | `JoinSet` + `.abort_all()` (auto-abort on drop) |
| `vendor/` directory | `Cargo.lock` |
| Zero value reliance (`T{}`) | `impl Default` / `T::default()` |
| `(T, bool)` "comma ok" | `Option<T>` |
| Named return values | Return `Result<T, E>` |
| Multiple returns (3+) | `Result<Struct, E>` |
| `json:"field_name"` struct tags | `#[serde(rename = "field_name")]` |
| Embedded struct JSON flattening | `#[serde(flatten)]` |
