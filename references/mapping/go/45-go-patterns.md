# 45 - Go-Specific Pattern Conversions

**Output**: `.migration-plan/mappings/go-patterns.md`

## Purpose

Map Go-specific idioms, patterns, and language features that do not fit cleanly into the type, error, concurrency, or interface mapping guides. This covers struct embedding, `defer`, `init()` functions, table-driven tests, build tags, `go generate`, the internal package convention, functional options, iota enums, multiple return values, the blank identifier, pointer vs value receivers, and other Go-isms that require deliberate Rust translation. Every instance of these patterns in the Go source must receive a concrete, compilable Rust equivalent.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- struct embeddings, method receivers, iota enums
- `architecture.md` -- package layout, internal packages, init() functions, build tags
- `dependency-tree.md` -- go generate dependencies, build-time code generation
- `error-patterns.md` -- defer/panic/recover patterns
- `async-model.md` -- goroutine lifecycle management

Extract every instance of:
- Struct embedding (promoted fields and methods)
- `defer` statements (resource cleanup, unlock, close)
- `init()` functions (package-level initialization)
- Table-driven tests
- Build tags (`//go:build`)
- `go generate` directives
- `internal/` package convention
- Functional options pattern (`type Option func(*Config)`)
- `iota` enum patterns
- Blank identifier `_` usage
- Multiple return values
- Pointer vs value receivers
- Context propagation patterns
- Goroutine leak prevention

### Step 2: For each Go pattern, determine Rust equivalent

Apply the conversion table below for EVERY pattern instance found.

### Step 3: Produce pattern mapping document

For EACH pattern found in the source, produce:
1. Go source code with file:line reference
2. Pattern category
3. Rust equivalent code (compilable)
4. Migration notes and gotchas

## Code Examples

### Example 1: Struct Embedding to Composition + Deref

**Go:**
```go
type Logger struct {
    prefix string
    level  int
}

func (l *Logger) Log(msg string) {
    fmt.Printf("[%s] %s\n", l.prefix, msg)
}

func (l *Logger) SetLevel(level int) {
    l.level = level
}

type Server struct {
    Logger           // embedded: Server "is a" Logger
    addr   string
    port   int
}

// Usage:
// s := &Server{Logger: Logger{prefix: "srv"}, addr: "localhost", port: 8080}
// s.Log("started")        // promoted method
// s.prefix                // promoted field
// s.SetLevel(2)           // promoted method
```

**Rust (composition with Deref for field promotion):**
```rust
pub struct Logger {
    prefix: String,
    level: i32,
}

impl Logger {
    pub fn log(&self, msg: &str) {
        println!("[{}] {msg}", self.prefix);
    }

    pub fn set_level(&mut self, level: i32) {
        self.level = level;
    }
}

pub struct Server {
    pub logger: Logger,  // composition, not inheritance
    pub addr: String,
    pub port: u16,
}

// Deref provides method promotion (read-only access)
impl std::ops::Deref for Server {
    type Target = Logger;
    fn deref(&self) -> &Logger {
        &self.logger
    }
}

impl std::ops::DerefMut for Server {
    fn deref_mut(&mut self) -> &mut Logger {
        &mut self.logger
    }
}

// Usage:
// let mut s = Server { logger: Logger { prefix: "srv".into(), level: 0 }, addr: "localhost".into(), port: 8080 };
// s.log("started");       // via Deref
// s.set_level(2);         // via DerefMut
```

**Rust (trait delegation -- preferred for multiple embeddings):**
```rust
pub trait Loggable {
    fn log(&self, msg: &str);
    fn set_level(&mut self, level: i32);
}

impl Loggable for Logger {
    fn log(&self, msg: &str) {
        println!("[{}] {msg}", self.prefix);
    }
    fn set_level(&mut self, level: i32) {
        self.level = level;
    }
}

// Delegate trait methods to the inner Logger
impl Loggable for Server {
    fn log(&self, msg: &str) {
        self.logger.log(msg);
    }
    fn set_level(&mut self, level: i32) {
        self.logger.set_level(level);
    }
}
```

### Example 2: defer to Drop Trait or Scope Guard

**Go:**
```go
func ProcessFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()

    mu.Lock()
    defer mu.Unlock()

    // Process file...
    data, err := io.ReadAll(f)
    if err != nil {
        return err
    }

    return process(data)
}

// defer with named return value (for error annotation)
func ReadConfig(path string) (cfg Config, err error) {
    f, err := os.Open(path)
    if err != nil {
        return cfg, err
    }
    defer func() {
        closeErr := f.Close()
        if err == nil {
            err = closeErr
        }
    }()
    // ...
}
```

**Rust (Drop trait -- automatic cleanup, most common):**
```rust
pub fn process_file(path: &str) -> Result<(), AppError> {
    // File is automatically closed when `f` goes out of scope (Drop trait)
    let data = std::fs::read(path)?;

    // MutexGuard is automatically unlocked when dropped
    let guard = mu.lock().unwrap();

    process(&data)?;
    Ok(())
    // `guard` dropped here -> mutex unlocked
    // `f` would be dropped here -> file closed (if we used File directly)
}
```

**Rust (scopeguard -- for defer with custom logic):**
```rust
use scopeguard::defer;

pub fn do_work(ctx: &mut Context) -> Result<(), AppError> {
    ctx.start_transaction()?;

    // Equivalent of Go defer: runs when scope exits (success or error)
    defer! {
        ctx.end_transaction();
    }

    // Or with a captured variable:
    let temp_file = create_temp_file()?;
    let path = temp_file.path().to_owned();
    scopeguard::guard(temp_file, |_f| {
        let _ = std::fs::remove_file(&path);
    });

    perform_work(ctx)?;
    Ok(())
}
```

**Rust (explicit Drop impl for custom cleanup):**
```rust
pub struct Connection {
    handle: RawHandle,
    closed: bool,
}

impl Drop for Connection {
    fn drop(&mut self) {
        if !self.closed {
            unsafe { close_handle(self.handle) };
        }
    }
}

impl Connection {
    pub fn close(&mut self) -> Result<(), IoError> {
        if !self.closed {
            self.closed = true;
            unsafe { close_handle(self.handle) }
                .map_err(IoError::from)
        } else {
            Ok(())
        }
    }
}
```

### Example 3: init() Functions to Lazy Initialization

**Go:**
```go
// pkg/registry/registry.go
var (
    defaultRegistry *Registry
    defaultParsers  map[string]Parser
)

func init() {
    defaultRegistry = NewRegistry()
    defaultParsers = map[string]Parser{
        "json": &JSONParser{},
        "yaml": &YAMLParser{},
        "toml": &TOMLParser{},
    }
    registerBuiltinTypes(defaultRegistry)
}

// Multiple init() functions across files run in source order
// pkg/registry/builtins.go
func init() {
    defaultRegistry.Register("string", StringType{})
    defaultRegistry.Register("int", IntType{})
}
```

**Rust (LazyLock / OnceLock -- recommended):**
```rust
use std::sync::LazyLock;
use std::collections::HashMap;

static DEFAULT_REGISTRY: LazyLock<Registry> = LazyLock::new(|| {
    let mut registry = Registry::new();
    register_builtin_types(&mut registry);
    registry
});

static DEFAULT_PARSERS: LazyLock<HashMap<&'static str, Box<dyn Parser + Send + Sync>>> =
    LazyLock::new(|| {
        let mut parsers: HashMap<&str, Box<dyn Parser + Send + Sync>> = HashMap::new();
        parsers.insert("json", Box::new(JsonParser));
        parsers.insert("yaml", Box::new(YamlParser));
        parsers.insert("toml", Box::new(TomlParser));
        parsers
    });

// Prefer explicit initialization at startup over lazy globals:
pub fn init_registry() -> Registry {
    let mut registry = Registry::new();
    registry.register("string", StringType);
    registry.register("int", IntType);
    register_builtin_types(&mut registry);
    registry
}

// In main():
fn main() {
    let registry = init_registry();
    let app_state = AppState { registry };
    // pass app_state to handlers via dependency injection
}
```

### Example 4: Table-Driven Tests to Parameterized Tests

**Go:**
```go
func TestParseAge(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {"valid age", "25", 25, false},
        {"zero", "0", 0, false},
        {"max", "150", 150, false},
        {"negative", "-1", 0, true},
        {"too old", "151", 0, true},
        {"not a number", "abc", 0, true},
        {"empty", "", 0, true},
        {"float", "25.5", 0, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAge(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("ParseAge(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
                return
            }
            if got != tt.want {
                t.Errorf("ParseAge(%q) = %v, want %v", tt.input, got, tt.want)
            }
        })
    }
}
```

**Rust (using rstest for parameterized tests):**
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use rstest::rstest;

    #[rstest]
    #[case::valid_age("25", Ok(25))]
    #[case::zero("0", Ok(0))]
    #[case::max("150", Ok(150))]
    #[case::negative("-1", Err(()))]
    #[case::too_old("151", Err(()))]
    #[case::not_a_number("abc", Err(()))]
    #[case::empty("", Err(()))]
    #[case::float_value("25.5", Err(()))]
    fn test_parse_age(#[case] input: &str, #[case] expected: Result<i32, ()>) {
        let result = parse_age(input).map_err(|_| ());
        assert_eq!(result, expected);
    }
}
```

**Rust (using test_case macro):**
```rust
#[cfg(test)]
mod tests {
    use super::*;
    use test_case::test_case;

    #[test_case("25" => 25 ; "valid age")]
    #[test_case("0" => 0 ; "zero")]
    #[test_case("150" => 150 ; "max")]
    fn test_parse_age_valid(input: &str) -> i32 {
        parse_age(input).unwrap()
    }

    #[test_case("-1" ; "negative")]
    #[test_case("151" ; "too old")]
    #[test_case("abc" ; "not a number")]
    #[test_case("" ; "empty")]
    #[test_case("25.5" ; "float")]
    #[should_panic]
    fn test_parse_age_invalid(input: &str) {
        parse_age(input).unwrap();
    }
}
```

### Example 5: Build Tags to Cargo Features + cfg

**Go:**
```go
//go:build linux
// +build linux

package platform

func GetSystemInfo() SystemInfo {
    // Linux-specific implementation
}

//go:build !production
// +build !production

package debug

func EnableDebugMode() {
    // Only available in non-production builds
}

//go:build integration
// +build integration

package tests

func TestIntegration(t *testing.T) {
    // Integration test, only runs with: go test -tags=integration
}
```

**Rust (cfg attributes for OS-specific code):**
```rust
// Platform-specific code
#[cfg(target_os = "linux")]
pub fn get_system_info() -> SystemInfo {
    // Linux-specific implementation
}

#[cfg(target_os = "macos")]
pub fn get_system_info() -> SystemInfo {
    // macOS-specific implementation
}

#[cfg(target_os = "windows")]
pub fn get_system_info() -> SystemInfo {
    // Windows-specific implementation
}
```

**Rust (Cargo features for optional functionality):**
```toml
# Cargo.toml
[features]
default = []
debug-mode = []
integration-tests = []
```

```rust
// Feature-gated code
#[cfg(feature = "debug-mode")]
pub fn enable_debug_mode() {
    // Only compiled when: cargo build --features debug-mode
}

// Feature-gated tests
#[cfg(test)]
#[cfg(feature = "integration-tests")]
mod integration_tests {
    #[tokio::test]
    async fn test_integration() {
        // Only runs with: cargo test --features integration-tests
    }
}
```

### Example 6: go generate to build.rs + Proc Macros

**Go:**
```go
//go:generate stringer -type=Color
//go:generate mockgen -source=repository.go -destination=mock_repository.go

type Color int

const (
    Red Color = iota
    Green
    Blue
)
```

**Rust (build.rs for code generation):**
```rust
// build.rs
fn main() {
    // Example: generate protobuf code
    tonic_build::configure()
        .build_server(true)
        .compile_protos(&["proto/service.proto"], &["proto/"])
        .expect("failed to compile protos");

    // Example: generate version info
    println!("cargo:rustc-env=BUILD_TIME={}", chrono::Utc::now());
}
```

**Rust (derive macros replace go generate for enums):**
```rust
use strum::{Display, EnumString, EnumIter};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Display, EnumString, EnumIter)]
pub enum Color {
    #[strum(serialize = "red")]
    Red,
    #[strum(serialize = "green")]
    Green,
    #[strum(serialize = "blue")]
    Blue,
}

// strum provides: Display, FromStr, iteration -- no code generation step needed

// For mocks: mockall generates at compile time via proc macro
#[cfg_attr(test, mockall::automock)]
pub trait Repository {
    fn find(&self, id: i64) -> Result<Item, RepoError>;
}
```

### Example 7: internal/ Package to pub(crate)

**Go:**
```go
// pkg/mylib/internal/helper/helper.go
// This package is only importable by pkg/mylib and its sub-packages
package helper

func FormatKey(prefix, key string) string {
    return prefix + ":" + key
}

// pkg/mylib/store.go
package mylib

import "pkg/mylib/internal/helper"

func (s *Store) Get(key string) ([]byte, error) {
    formattedKey := helper.FormatKey(s.prefix, key)
    return s.backend.Get(formattedKey)
}
```

**Rust (pub(crate) visibility):**
```rust
// src/helper.rs (internal module)
// pub(crate) makes items visible only within the crate
pub(crate) fn format_key(prefix: &str, key: &str) -> String {
    format!("{prefix}:{key}")
}

// src/store.rs
use crate::helper;

impl Store {
    pub fn get(&self, key: &str) -> Result<Vec<u8>, StoreError> {
        let formatted_key = helper::format_key(&self.prefix, key);
        self.backend.get(&formatted_key)
    }
}

// Module visibility options:
// pub          -> visible to everyone (exported)
// pub(crate)   -> visible within the crate only (like internal/)
// pub(super)   -> visible to parent module only
// (no modifier) -> private to current module
```

### Example 8: Functional Options to Builder Pattern

**Go:**
```go
type ServerConfig struct {
    addr         string
    port         int
    readTimeout  time.Duration
    writeTimeout time.Duration
    maxConns     int
    logger       Logger
    tls          *tls.Config
}

type Option func(*ServerConfig)

func WithPort(port int) Option {
    return func(c *ServerConfig) {
        c.port = port
    }
}

func WithTimeout(read, write time.Duration) Option {
    return func(c *ServerConfig) {
        c.readTimeout = read
        c.writeTimeout = write
    }
}

func WithMaxConns(n int) Option {
    return func(c *ServerConfig) {
        c.maxConns = n
    }
}

func WithTLS(cfg *tls.Config) Option {
    return func(c *ServerConfig) {
        c.tls = cfg
    }
}

func NewServer(addr string, opts ...Option) *Server {
    cfg := &ServerConfig{
        addr:         addr,
        port:         8080,
        readTimeout:  30 * time.Second,
        writeTimeout: 30 * time.Second,
        maxConns:     1000,
    }
    for _, opt := range opts {
        opt(cfg)
    }
    return &Server{config: cfg}
}

// Usage:
// srv := NewServer("localhost",
//     WithPort(9090),
//     WithTimeout(10*time.Second, 10*time.Second),
//     WithMaxConns(5000),
// )
```

**Rust (builder pattern -- idiomatic):**
```rust
use std::time::Duration;

pub struct ServerConfig {
    pub addr: String,
    pub port: u16,
    pub read_timeout: Duration,
    pub write_timeout: Duration,
    pub max_conns: usize,
    pub tls: Option<TlsConfig>,
}

pub struct ServerBuilder {
    addr: String,
    port: u16,
    read_timeout: Duration,
    write_timeout: Duration,
    max_conns: usize,
    tls: Option<TlsConfig>,
}

impl ServerBuilder {
    pub fn new(addr: impl Into<String>) -> Self {
        Self {
            addr: addr.into(),
            port: 8080,
            read_timeout: Duration::from_secs(30),
            write_timeout: Duration::from_secs(30),
            max_conns: 1000,
            tls: None,
        }
    }

    pub fn port(mut self, port: u16) -> Self {
        self.port = port;
        self
    }

    pub fn timeout(mut self, read: Duration, write: Duration) -> Self {
        self.read_timeout = read;
        self.write_timeout = write;
        self
    }

    pub fn max_conns(mut self, n: usize) -> Self {
        self.max_conns = n;
        self
    }

    pub fn tls(mut self, config: TlsConfig) -> Self {
        self.tls = Some(config);
        self
    }

    pub fn build(self) -> Server {
        Server {
            config: ServerConfig {
                addr: self.addr,
                port: self.port,
                read_timeout: self.read_timeout,
                write_timeout: self.write_timeout,
                max_conns: self.max_conns,
                tls: self.tls,
            },
        }
    }
}

// Usage:
// let srv = ServerBuilder::new("localhost")
//     .port(9090)
//     .timeout(Duration::from_secs(10), Duration::from_secs(10))
//     .max_conns(5000)
//     .build();
```

**Rust (derive-based builder with `bon` crate):**
```rust
use bon::bon;

pub struct Server {
    config: ServerConfig,
}

#[bon]
impl Server {
    #[builder]
    pub fn new(
        addr: String,
        #[builder(default = 8080)]
        port: u16,
        #[builder(default = Duration::from_secs(30))]
        read_timeout: Duration,
        #[builder(default = Duration::from_secs(30))]
        write_timeout: Duration,
        #[builder(default = 1000)]
        max_conns: usize,
        tls: Option<TlsConfig>,
    ) -> Self {
        Self {
            config: ServerConfig { addr, port, read_timeout, write_timeout, max_conns, tls },
        }
    }
}

// Usage:
// let srv = Server::builder()
//     .addr("localhost".into())
//     .port(9090)
//     .read_timeout(Duration::from_secs(10))
//     .max_conns(5000)
//     .build();
```

### Example 9: iota Enums to Rust Enums

**Go:**
```go
type Status int

const (
    StatusPending  Status = iota // 0
    StatusActive                 // 1
    StatusInactive               // 2
    StatusDeleted                // 3
)

func (s Status) String() string {
    switch s {
    case StatusPending:
        return "pending"
    case StatusActive:
        return "active"
    case StatusInactive:
        return "inactive"
    case StatusDeleted:
        return "deleted"
    default:
        return fmt.Sprintf("unknown(%d)", s)
    }
}

// Bitmask iota
type Permission int

const (
    PermRead    Permission = 1 << iota // 1
    PermWrite                          // 2
    PermExecute                        // 4
    PermAdmin                          // 8
)

func (p Permission) Has(perm Permission) bool {
    return p&perm != 0
}
```

**Rust (simple enum with derives):**
```rust
use serde::{Deserialize, Serialize};
use strum::Display;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Display)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    #[strum(serialize = "pending")]
    Pending = 0,
    #[strum(serialize = "active")]
    Active = 1,
    #[strum(serialize = "inactive")]
    Inactive = 2,
    #[strum(serialize = "deleted")]
    Deleted = 3,
}

// If you need to convert from integer (e.g., database values):
impl TryFrom<i32> for Status {
    type Error = String;
    fn try_from(v: i32) -> Result<Self, Self::Error> {
        match v {
            0 => Ok(Status::Pending),
            1 => Ok(Status::Active),
            2 => Ok(Status::Inactive),
            3 => Ok(Status::Deleted),
            _ => Err(format!("unknown status: {v}")),
        }
    }
}
```

**Rust (bitmask with bitflags):**
```rust
use bitflags::bitflags;

bitflags! {
    #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
    pub struct Permission: u32 {
        const READ    = 0b0001;
        const WRITE   = 0b0010;
        const EXECUTE = 0b0100;
        const ADMIN   = 0b1000;

        const READ_WRITE = Self::READ.bits() | Self::WRITE.bits();
        const ALL = Self::READ.bits() | Self::WRITE.bits() | Self::EXECUTE.bits() | Self::ADMIN.bits();
    }
}

// Usage:
// let perms = Permission::READ | Permission::WRITE;
// assert!(perms.contains(Permission::READ));
// assert!(!perms.contains(Permission::ADMIN));
```

### Example 10: Pointer vs Value Receiver to &self vs &mut self

**Go:**
```go
type Point struct {
    X, Y float64
}

// Value receiver: does not modify, works on copy
func (p Point) Distance(other Point) float64 {
    dx := p.X - other.X
    dy := p.Y - other.Y
    return math.Sqrt(dx*dx + dy*dy)
}

// Value receiver: returns new value
func (p Point) Translate(dx, dy float64) Point {
    return Point{X: p.X + dx, Y: p.Y + dy}
}

// Pointer receiver: modifies in place
func (p *Point) TranslateInPlace(dx, dy float64) {
    p.X += dx
    p.Y += dy
}

// Pointer receiver: needed because struct is large
func (p *Point) MarshalJSON() ([]byte, error) {
    // ...
}
```

**Rust:**
```rust
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

impl Point {
    // &self: value receiver equivalent (read-only)
    pub fn distance(&self, other: &Point) -> f64 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        (dx * dx + dy * dy).sqrt()
    }

    // self + return: value receiver that returns new value
    // (since Point is Copy, this is cheap)
    pub fn translate(self, dx: f64, dy: f64) -> Point {
        Point {
            x: self.x + dx,
            y: self.y + dy,
        }
    }

    // &mut self: pointer receiver equivalent (modifies in place)
    pub fn translate_in_place(&mut self, dx: f64, dy: f64) {
        self.x += dx;
        self.y += dy;
    }
}

// Receiver decision guide:
// &self    -> Go value receiver (read-only access)
// &mut self -> Go pointer receiver (mutates the value)
// self     -> Takes ownership (consuming methods, builder pattern)
//
// For small Copy types (Point, Color, etc.): &self or self are equivalent
// For large types: always &self or &mut self (no implicit copy)
```

### Example 11: Multiple Return Values to Tuples or Structs

**Go:**
```go
// Two returns: use tuple
func Divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
}

// Three+ returns: consider a struct
func ParseAddress(raw string) (street string, city string, zip string, err error) {
    parts := strings.SplitN(raw, ",", 3)
    if len(parts) != 3 {
        return "", "", "", errors.New("invalid address format")
    }
    return strings.TrimSpace(parts[0]),
           strings.TrimSpace(parts[1]),
           strings.TrimSpace(parts[2]),
           nil
}
```

**Rust:**
```rust
// Two returns: use Result<T, E>
pub fn divide(a: f64, b: f64) -> Result<f64, MathError> {
    if b == 0.0 {
        return Err(MathError::DivisionByZero);
    }
    Ok(a / b)
}

// Three+ returns: use a struct (more readable than tuples)
pub struct Address {
    pub street: String,
    pub city: String,
    pub zip: String,
}

pub fn parse_address(raw: &str) -> Result<Address, ParseError> {
    let parts: Vec<&str> = raw.splitn(3, ',').collect();
    if parts.len() != 3 {
        return Err(ParseError::InvalidFormat("expected street,city,zip".into()));
    }
    Ok(Address {
        street: parts[0].trim().to_string(),
        city: parts[1].trim().to_string(),
        zip: parts[2].trim().to_string(),
    })
}

// For simple cases, tuples are acceptable:
pub fn min_max(values: &[i32]) -> Option<(i32, i32)> {
    if values.is_empty() {
        return None;
    }
    let min = *values.iter().min().unwrap();
    let max = *values.iter().max().unwrap();
    Some((min, max))
}
```

### Example 12: Blank Identifier and Unused Variables

**Go:**
```go
// Ignore a return value
_, err := fmt.Fprintf(w, "hello")

// Ignore index in range
for _, item := range items {
    process(item)
}

// Import for side effects
import _ "github.com/lib/pq"

// Compile-time interface check
var _ io.Reader = (*MyReader)(nil)
```

**Rust:**
```rust
// Ignore a return value
let _ = write!(w, "hello"); // explicit ignore with let _

// Ignore index in iteration (no special syntax needed)
for item in &items {
    process(item);
}

// With index available but unused:
for (_i, item) in items.iter().enumerate() {
    process(item);
}

// Import for side effects: not common in Rust
// Instead, call initialization explicitly in main()

// Compile-time interface check: not needed in Rust
// The compiler enforces trait implementations at `impl` blocks
```

### Example 13: Context Value Propagation to Struct Fields

**Go:**
```go
type contextKey string

const (
    requestIDKey contextKey = "request_id"
    userIDKey    contextKey = "user_id"
)

func WithRequestID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, requestIDKey, id)
}

func GetRequestID(ctx context.Context) string {
    if id, ok := ctx.Value(requestIDKey).(string); ok {
        return id
    }
    return ""
}

func Handler(ctx context.Context, req *Request) error {
    ctx = WithRequestID(ctx, uuid.New().String())
    return processRequest(ctx, req) // request ID propagated via context
}
```

**Rust (explicit struct fields -- type-safe):**
```rust
use uuid::Uuid;

pub struct RequestContext {
    pub request_id: String,
    pub user_id: Option<i64>,
    pub cancel: tokio_util::sync::CancellationToken,
}

impl RequestContext {
    pub fn new() -> Self {
        Self {
            request_id: Uuid::new_v4().to_string(),
            user_id: None,
            cancel: tokio_util::sync::CancellationToken::new(),
        }
    }

    pub fn with_user_id(mut self, user_id: i64) -> Self {
        self.user_id = Some(user_id);
        self
    }
}

pub async fn handler(req: Request) -> Result<Response, AppError> {
    let ctx = RequestContext::new();
    process_request(&ctx, &req).await
}
```

**Rust (tracing spans for observability context):**
```rust
use tracing::{info_span, Instrument};
use uuid::Uuid;

pub async fn handler(req: Request) -> Result<Response, AppError> {
    let request_id = Uuid::new_v4().to_string();

    // Span propagates context to all nested calls
    let span = info_span!("request", request_id = %request_id);

    async move {
        // All tracing events within this span include request_id
        tracing::info!("processing request");
        process_request(&req).await
    }
    .instrument(span)
    .await
}
```

### Example 14: Goroutine Leak Prevention to JoinHandle Management

**Go:**
```go
// Problematic: goroutine leak
func LeakySearch(ctx context.Context, query string) (Result, error) {
    ch := make(chan Result, 3)

    go func() { ch <- searchBackendA(query) }()
    go func() { ch <- searchBackendB(query) }()
    go func() { ch <- searchBackendC(query) }()

    // Takes first result, but other goroutines leak if ctx is cancelled
    select {
    case result := <-ch:
        return result, nil
    case <-ctx.Done():
        return Result{}, ctx.Err()
    }
}

// Fixed: proper cancellation
func SafeSearch(ctx context.Context, query string) (Result, error) {
    ctx, cancel := context.WithCancel(ctx)
    defer cancel() // cancels remaining goroutines

    ch := make(chan Result, 3)
    go func() { ch <- searchBackendA(ctx, query) }()
    go func() { ch <- searchBackendB(ctx, query) }()
    go func() { ch <- searchBackendC(ctx, query) }()

    select {
    case result := <-ch:
        return result, nil
    case <-ctx.Done():
        return Result{}, ctx.Err()
    }
}
```

**Rust (JoinSet with abort on first result):**
```rust
use tokio::task::JoinSet;

pub async fn safe_search(query: &str) -> Result<SearchResult, SearchError> {
    let mut set = JoinSet::new();

    let q = query.to_string();
    set.spawn(async move { search_backend_a(&q).await });

    let q = query.to_string();
    set.spawn(async move { search_backend_b(&q).await });

    let q = query.to_string();
    set.spawn(async move { search_backend_c(&q).await });

    // Take the first successful result
    while let Some(result) = set.join_next().await {
        match result {
            Ok(Ok(search_result)) => {
                // Abort remaining tasks (prevents leaks)
                set.abort_all();
                return Ok(search_result);
            }
            Ok(Err(e)) => {
                tracing::warn!(error = ?e, "search backend failed");
                // Continue waiting for other backends
            }
            Err(join_err) => {
                tracing::error!(error = ?join_err, "search task panicked");
            }
        }
    }

    Err(SearchError::AllBackendsFailed)
}

// JoinSet automatically aborts all tasks when dropped,
// so there is no goroutine leak risk
```

## Template

```markdown
# Go-Specific Pattern Conversions

Source: {project_name}
Generated: {date}

## Struct Embedding Inventory

| # | Outer Type | Embedded Type | File | Rust Strategy | Notes |
|---|-----------|--------------|------|---------------|-------|
| 1 | `Server` | `Logger` | [{file}:{line}] | Deref delegation | Single embedding |
| 2 | `Admin` | `User`, `Permissions` | [{file}:{line}] | Trait delegation | Multiple embeddings |

## Defer Statement Inventory

| # | Location | Resource | Cleanup Action | Rust Strategy |
|---|----------|----------|---------------|---------------|
| 1 | [{file}:{line}] | File | `f.Close()` | `Drop` (automatic) |
| 2 | [{file}:{line}] | Mutex | `mu.Unlock()` | `Drop` (MutexGuard) |
| 3 | [{file}:{line}] | Temp file | `os.Remove(path)` | `scopeguard` |
| 4 | [{file}:{line}] | Transaction | `tx.Rollback()` | `Drop` impl on Tx wrapper |

## init() Function Inventory

| # | Package | File | Purpose | Rust Strategy |
|---|---------|------|---------|---------------|
| 1 | `registry` | [{file}:{line}] | Register types | `LazyLock` or explicit init |
| 2 | `config` | [{file}:{line}] | Load defaults | `LazyLock` or startup fn |

## Build Tag Inventory

| # | File | Go Tag | Purpose | Rust Equivalent |
|---|------|--------|---------|----------------|
| 1 | [{file}:{line}] | `//go:build linux` | OS-specific | `#[cfg(target_os = "linux")]` |
| 2 | [{file}:{line}] | `//go:build integration` | Test filter | `#[cfg(feature = "integration")]` |

## go generate Inventory

| # | File | Generator | Purpose | Rust Equivalent |
|---|------|-----------|---------|----------------|
| 1 | [{file}:{line}] | `stringer` | Enum Display | `strum::Display` derive |
| 2 | [{file}:{line}] | `mockgen` | Mock generation | `mockall` derive |
| 3 | [{file}:{line}] | `protoc` | Protobuf | `tonic-build` in build.rs |

## Iota Enum Inventory

| # | Type | File | Variants | Rust Strategy |
|---|------|------|----------|---------------|
| 1 | `Status` | [{file}:{line}] | Pending=0, Active=1, ... | `enum` with derives |
| 2 | `Permission` | [{file}:{line}] | Read=1, Write=2, ... | `bitflags!` |

## Functional Options Inventory

| # | Constructor | File | Options Count | Rust Strategy |
|---|------------|------|---------------|---------------|
| 1 | `NewServer(addr, ...Option)` | [{file}:{line}] | 5 | Builder pattern |

## Internal Package Inventory

| # | Package Path | File | Rust Visibility |
|---|-------------|------|-----------------|
| 1 | `internal/helper` | [{file}:{line}] | `pub(crate)` |
| 2 | `internal/store` | [{file}:{line}] | `pub(crate)` |

## Crate Dependencies for Patterns

```toml
[dependencies]
scopeguard = "1"        # defer equivalents
strum = { version = "0.26", features = ["derive"] }  # enum Display/FromStr
bitflags = "2"          # bitmask enums

[dev-dependencies]
rstest = "0.23"         # parameterized tests
test-case = "3"         # alternative parameterized tests
```
```

## Completeness Check

- [ ] Every struct embedding is mapped to composition with Deref or trait delegation
- [ ] Every `defer` statement is mapped to Drop, MutexGuard, or scopeguard
- [ ] Every `init()` function is replaced with `LazyLock` or explicit initialization
- [ ] Every table-driven test is converted to parameterized tests (rstest or test_case)
- [ ] Every build tag is mapped to `#[cfg(...)]` or Cargo features
- [ ] Every `go generate` directive is mapped to build.rs or proc macros
- [ ] Every `internal/` package is mapped to `pub(crate)` visibility
- [ ] Every functional options pattern is converted to a builder pattern
- [ ] Every `iota` enum is mapped to Rust enum with appropriate derives
- [ ] Every bitmask iota is mapped to `bitflags!`
- [ ] Every blank identifier usage is mapped to `_` or `let _`
- [ ] Every multiple return value is mapped to `Result<T, E>`, tuple, or struct
- [ ] Every pointer receiver is mapped to `&mut self`, every value receiver to `&self`
- [ ] Context value propagation is replaced with struct fields or tracing spans
- [ ] Goroutine leak patterns are addressed with JoinSet/abort management
- [ ] `vendor/` directory reliance is replaced by Cargo.lock
