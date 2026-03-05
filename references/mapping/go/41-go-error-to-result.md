# 41 - Go Error Handling to Rust Result/Option

**Output**: Contributes to `.migration-plan/mappings/error-hierarchy.md`

## Purpose

Map every Go error handling pattern to its Rust `Result<T, E>` and `Option<T>` equivalent. Go uses a convention of returning `(value, error)` tuples with `if err != nil` checks. Rust uses the type system to enforce error handling through `Result<T, E>` with the `?` operator for propagation. Every error return, error check, sentinel error, error wrapping, and panic/recover in the Go source must receive a concrete Rust translation using `thiserror` for typed errors and `anyhow` for application-level context.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `error-patterns.md` -- inventory of all error handling patterns, custom error types, sentinel errors
- `type-catalog.md` -- custom error types implementing the `error` interface
- `architecture.md` -- module boundaries that determine error scope and propagation paths

Extract every instance of:
- Functions returning `(T, error)`
- `if err != nil { return ... }` blocks
- `errors.New()` and `fmt.Errorf()` calls
- Sentinel errors (`var ErrNotFound = errors.New(...)`)
- Custom error types (structs implementing `Error() string`)
- `errors.Is()` and `errors.As()` usage
- Error wrapping with `%w` verb
- `panic()` and `recover()` usage
- Ignored errors (`val, _ := SomeFunc()`)
- Error type assertions (`err.(*CustomError)`)

### Step 2: For each error pattern, determine Rust equivalent

**Error mapping decision tree:**

```
Is this a sentinel error (package-level var)?
  YES -> Enum variant in module error type
  NO  ->
    Is this a custom error type (struct with Error() method)?
      YES -> Dedicated error enum with thiserror
      NO  ->
        Is this errors.New("static message")?
          YES -> Enum variant with static message
          NO  ->
            Is this fmt.Errorf("context: %w", err)?
              YES -> .context("...") with anyhow, or map_err
              NO  ->
                Is this a panic()?
                  Recoverable? -> Result<T, E>
                  Programming bug? -> panic!() (keep as panic)
```

**Error propagation mapping:**

| Go Pattern | Rust Equivalent |
|-----------|----------------|
| `if err != nil { return err }` | `?` operator |
| `if err != nil { return fmt.Errorf("ctx: %w", err) }` | `.context("ctx")?` or `.map_err(...)` |
| `if err != nil { return nil, err }` | `?` (returns `Err`) |
| `if err != nil { log; return }` | `if let Err(e) = ... { tracing::error!(...); return; }` |
| `if err != nil { log; continue }` | `match ... { Err(e) => { tracing::warn!(...); continue; } ... }` |
| `val, _ := SomeFunc()` | `.unwrap_or_default()` or `.ok()` (document the ignore) |

### Step 3: Produce error mapping document

For EACH error pattern found in the source, produce:
1. Go source code with file:line reference
2. Error type/category
3. Rust equivalent code (compilable)
4. Crate dependencies needed
5. Propagation chain (how this error flows to callers)

## Code Examples

### Example 1: Basic Error Return to Result

**Go:**
```go
func FindUser(db *sql.DB, id int64) (*User, error) {
    var user User
    err := db.QueryRow("SELECT id, name, email FROM users WHERE id = ?", id).
        Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, fmt.Errorf("user not found: %d", id)
        }
        return nil, fmt.Errorf("query user: %w", err)
    }
    return &user, nil
}
```

**Rust:**
```rust
use sqlx::PgPool;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum UserError {
    #[error("user not found: {0}")]
    NotFound(i64),

    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
}

pub async fn find_user(pool: &PgPool, id: i64) -> Result<User, UserError> {
    sqlx::query_as::<_, User>("SELECT id, name, email FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await?                          // sqlx::Error -> UserError::Database via From
        .ok_or(UserError::NotFound(id))  // None -> UserError::NotFound
}
```

### Example 2: Sentinel Errors to Enum Variants

**Go:**
```go
package cache

import "errors"

var (
    ErrNotFound    = errors.New("cache: key not found")
    ErrExpired     = errors.New("cache: key expired")
    ErrCapacity    = errors.New("cache: capacity exceeded")
    ErrInvalidKey  = errors.New("cache: invalid key")
)

func (c *Cache) Get(key string) ([]byte, error) {
    entry, ok := c.store[key]
    if !ok {
        return nil, ErrNotFound
    }
    if entry.IsExpired() {
        delete(c.store, key)
        return nil, ErrExpired
    }
    return entry.Value, nil
}

// Caller checks with errors.Is:
// if errors.Is(err, cache.ErrNotFound) { ... }
```

**Rust:**
```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum CacheError {
    #[error("cache: key not found")]
    NotFound,

    #[error("cache: key expired")]
    Expired,

    #[error("cache: capacity exceeded")]
    Capacity,

    #[error("cache: invalid key")]
    InvalidKey,
}

impl Cache {
    pub fn get(&mut self, key: &str) -> Result<Vec<u8>, CacheError> {
        let entry = self.store.get(key).ok_or(CacheError::NotFound)?;
        if entry.is_expired() {
            self.store.remove(key);
            return Err(CacheError::Expired);
        }
        Ok(entry.value.clone())
    }
}

// Caller matches on variant:
// match cache.get("key") {
//     Err(CacheError::NotFound) => { /* handle */ }
//     Err(e) => return Err(e.into()),
//     Ok(val) => { /* use val */ }
// }
```

### Example 3: Error Wrapping with fmt.Errorf %w to anyhow context

**Go:**
```go
func (s *Service) ProcessOrder(ctx context.Context, orderID string) error {
    order, err := s.repo.GetOrder(ctx, orderID)
    if err != nil {
        return fmt.Errorf("get order %s: %w", orderID, err)
    }

    if err := s.validateOrder(order); err != nil {
        return fmt.Errorf("validate order %s: %w", orderID, err)
    }

    if err := s.chargePayment(ctx, order); err != nil {
        return fmt.Errorf("charge payment for order %s: %w", orderID, err)
    }

    return nil
}
```

**Rust (with anyhow for application-level code):**
```rust
use anyhow::{Context, Result};

impl Service {
    pub async fn process_order(&self, order_id: &str) -> Result<()> {
        let order = self.repo.get_order(order_id)
            .await
            .with_context(|| format!("get order {order_id}"))?;

        self.validate_order(&order)
            .with_context(|| format!("validate order {order_id}"))?;

        self.charge_payment(&order)
            .await
            .with_context(|| format!("charge payment for order {order_id}"))?;

        Ok(())
    }
}
```

**Rust (with typed errors for library code):**
```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum OrderError {
    #[error("get order {order_id}: {source}")]
    Fetch {
        order_id: String,
        #[source]
        source: RepoError,
    },

    #[error("validate order {order_id}: {source}")]
    Validation {
        order_id: String,
        #[source]
        source: ValidationError,
    },

    #[error("charge payment for order {order_id}: {source}")]
    Payment {
        order_id: String,
        #[source]
        source: PaymentError,
    },
}

impl Service {
    pub async fn process_order(&self, order_id: &str) -> Result<(), OrderError> {
        let order = self.repo.get_order(order_id)
            .await
            .map_err(|source| OrderError::Fetch {
                order_id: order_id.to_string(),
                source,
            })?;

        self.validate_order(&order)
            .map_err(|source| OrderError::Validation {
                order_id: order_id.to_string(),
                source,
            })?;

        self.charge_payment(&order)
            .await
            .map_err(|source| OrderError::Payment {
                order_id: order_id.to_string(),
                source,
            })?;

        Ok(())
    }
}
```

### Example 4: Custom Error Type to thiserror Enum

**Go:**
```go
type ValidationError struct {
    Field   string
    Message string
    Value   interface{}
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on field %q: %s (got: %v)",
        e.Field, e.Message, e.Value)
}

type MultiValidationError struct {
    Errors []ValidationError
}

func (e *MultiValidationError) Error() string {
    msgs := make([]string, len(e.Errors))
    for i, err := range e.Errors {
        msgs[i] = err.Error()
    }
    return strings.Join(msgs, "; ")
}
```

**Rust:**
```rust
use thiserror::Error;

#[derive(Debug, Error)]
#[error("validation failed on field {field:?}: {message} (got: {value})")]
pub struct FieldError {
    pub field: String,
    pub message: String,
    pub value: String, // Use String instead of interface{}/Any
}

#[derive(Debug, Error)]
#[error("{}", .0.iter().map(|e| e.to_string()).collect::<Vec<_>>().join("; "))]
pub struct MultiValidationError(pub Vec<FieldError>);

impl MultiValidationError {
    pub fn new() -> Self {
        Self(Vec::new())
    }

    pub fn add(&mut self, field: impl Into<String>, message: impl Into<String>, value: impl ToString) {
        self.0.push(FieldError {
            field: field.into(),
            message: message.into(),
            value: value.to_string(),
        });
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    pub fn into_result<T>(self, value: T) -> Result<T, Self> {
        if self.is_empty() {
            Ok(value)
        } else {
            Err(self)
        }
    }
}
```

### Example 5: errors.Is() and errors.As() to Pattern Matching

**Go:**
```go
func HandleError(err error) {
    // errors.Is -- check for specific sentinel error
    if errors.Is(err, sql.ErrNoRows) {
        log.Println("record not found")
        return
    }

    // errors.As -- extract specific error type
    var pgErr *pgconn.PgError
    if errors.As(err, &pgErr) {
        if pgErr.Code == "23505" {
            log.Printf("unique violation on constraint: %s", pgErr.ConstraintName)
            return
        }
    }

    log.Printf("unexpected error: %v", err)
}
```

**Rust:**
```rust
fn handle_error(err: &AppError) {
    // Direct pattern match replaces errors.Is
    match err {
        AppError::Database(DbError::NotFound { .. }) => {
            tracing::info!("record not found");
        }

        // Nested match replaces errors.As
        AppError::Database(DbError::Query(sqlx_err)) => {
            if let Some(db_err) = sqlx_err.as_database_error() {
                if db_err.code().as_deref() == Some("23505") {
                    tracing::warn!(
                        constraint = db_err.constraint().unwrap_or("unknown"),
                        "unique violation"
                    );
                    return;
                }
            }
            tracing::error!(error = ?sqlx_err, "unexpected database error");
        }

        other => {
            tracing::error!(error = ?other, "unexpected error");
        }
    }
}
```

### Example 6: Panic/Recover to Result or panic!

**Go:**
```go
// Pattern 1: Panic for programming errors (keep as panic)
func MustParseConfig(path string) *Config {
    cfg, err := ParseConfig(path)
    if err != nil {
        panic(fmt.Sprintf("failed to parse config %s: %v", path, err))
    }
    return cfg
}

// Pattern 2: Recover from panics at boundaries
func SafeHandler(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if r := recover(); r != nil {
            log.Printf("panic recovered: %v", r)
            http.Error(w, "internal server error", 500)
        }
    }()
    handleRequest(w, r)
}
```

**Rust:**
```rust
// Pattern 1: Keep as panic for programming errors (startup-only)
pub fn must_parse_config(path: &str) -> Config {
    parse_config(path)
        .unwrap_or_else(|e| panic!("failed to parse config {path}: {e}"))
}

// Or better, propagate the error:
pub fn parse_config(path: &str) -> Result<Config, ConfigError> {
    let content = std::fs::read_to_string(path)
        .map_err(|e| ConfigError::Read { path: path.to_string(), source: e })?;
    toml::from_str(&content)
        .map_err(|e| ConfigError::Parse { path: path.to_string(), source: e })
}

// Pattern 2: catch_unwind is discouraged -- use Result instead
// Axum/actix-web already catch panics at the framework level.
// Convert the inner handler to return Result:
pub async fn safe_handler(
    req: axum::extract::Request,
) -> Result<axum::response::Response, AppError> {
    handle_request(req).await
    // If handle_request returns Err, axum's error handling converts it
}

// If you truly need catch_unwind (rare):
use std::panic;

pub fn safe_execute<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce() -> T + panic::UnwindSafe,
{
    panic::catch_unwind(f)
        .map_err(|e| {
            if let Some(s) = e.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = e.downcast_ref::<String>() {
                s.clone()
            } else {
                "unknown panic".to_string()
            }
        })
}
```

### Example 7: Multiple Return Values to Result

**Go:**
```go
// (value, bool) pattern -> Option<T>
func (m *Map) Get(key string) (Value, bool) {
    v, ok := m.data[key]
    return v, ok
}

// (value, error) pattern -> Result<T, E>
func ParseAge(s string) (int, error) {
    age, err := strconv.Atoi(s)
    if err != nil {
        return 0, fmt.Errorf("invalid age: %w", err)
    }
    if age < 0 || age > 150 {
        return 0, errors.New("age out of range")
    }
    return age, nil
}

// (value1, value2, error) pattern -> Result<(T1, T2), E>
func ParseCoordinates(s string) (float64, float64, error) {
    parts := strings.Split(s, ",")
    if len(parts) != 2 {
        return 0, 0, errors.New("expected 'lat,lon' format")
    }
    lat, err := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
    if err != nil {
        return 0, 0, fmt.Errorf("invalid latitude: %w", err)
    }
    lon, err := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
    if err != nil {
        return 0, 0, fmt.Errorf("invalid longitude: %w", err)
    }
    return lat, lon, nil
}
```

**Rust:**
```rust
// (value, bool) -> Option<T>
impl Map {
    pub fn get(&self, key: &str) -> Option<&Value> {
        self.data.get(key)
    }
}

// (value, error) -> Result<T, E>
pub fn parse_age(s: &str) -> Result<i32, ParseError> {
    let age: i32 = s.parse()
        .map_err(|_| ParseError::InvalidAge(s.to_string()))?;
    if !(0..=150).contains(&age) {
        return Err(ParseError::AgeOutOfRange(age));
    }
    Ok(age)
}

// (value1, value2, error) -> Result<(T1, T2), E> or Result<Struct, E>
pub fn parse_coordinates(s: &str) -> Result<(f64, f64), ParseError> {
    let parts: Vec<&str> = s.split(',').collect();
    if parts.len() != 2 {
        return Err(ParseError::InvalidFormat("expected 'lat,lon' format".into()));
    }
    let lat: f64 = parts[0].trim().parse()
        .map_err(|_| ParseError::InvalidLatitude(parts[0].trim().to_string()))?;
    let lon: f64 = parts[1].trim().parse()
        .map_err(|_| ParseError::InvalidLongitude(parts[1].trim().to_string()))?;
    Ok((lat, lon))
}
```

### Example 8: Ignored Errors to Explicit Handling

**Go:**
```go
// Deliberately ignored error
resp.Body.Close()                          // error ignored
_ = os.Remove(tmpFile)                     // explicitly ignored with _
json.Unmarshal(data, &config)              // error silently dropped

// Should-not-ignore patterns
conn, _ := net.Dial("tcp", addr)           // dangerous: conn is nil on error
```

**Rust:**
```rust
// Deliberately ignored: use let _ = or drop()
let _ = resp.body().close(); // explicit ignore is fine for cleanup
let _ = std::fs::remove_file(&tmp_file); // explicit ignore

// For unmarshal: force the caller to decide
let config: Config = serde_json::from_slice(&data)
    .unwrap_or_default(); // or .expect("config must be valid")

// Should-not-ignore: Rust forces you to handle it
let conn = TcpStream::connect(addr)
    .await
    .expect("failed to connect"); // or propagate with ?

// The compiler warns on unused Result values.
// Use #[must_use] on your own Result-returning functions to enforce this:
#[must_use]
pub fn validate(&self) -> Result<(), ValidationError> {
    // ...
    Ok(())
}
```

## Template

```markdown
# Go Error to Rust Result/Option Mapping

Source: {project_name}
Generated: {date}

## Error Type Hierarchy

```text
                    AppError (root)
                   /    |    \     \
          {Module}Error  ...  ...  ...
              |
          (variants from sentinel errors)
```

## Sentinel Error Inventory

| # | Go Sentinel | Package | File | Rust Enum | Variant |
|---|------------|---------|------|-----------|---------|
| 1 | `ErrNotFound` | `repo` | [{file}:{line}] | `RepoError` | `NotFound` |
| 2 | `ErrTimeout` | `client` | [{file}:{line}] | `ClientError` | `Timeout` |

## Custom Error Type Inventory

| # | Go Error Type | File | Rust Type | Strategy |
|---|--------------|------|-----------|----------|
| 1 | `ValidationError` | [{file}:{line}] | `ValidationError` enum | thiserror |
| 2 | `APIError` | [{file}:{line}] | `ApiError` struct | thiserror |

## Error Propagation Map

### {function_name}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Go signature**: `func Name(args) (T, error)`
**Rust signature**: `async fn name(args) -> Result<T, E>`

Error propagation chain:
```text
Name() -> callee1() -> returns ErrX -> wraps as "context: %w" -> becomes ModuleError::X
       -> callee2() -> returns ErrY -> wraps as "context: %w" -> becomes ModuleError::Y
```

Rust equivalent:
```rust
async fn name(args: Args) -> Result<T, ModuleError> {
    let x = callee1().await.context("context")?;
    let y = callee2().await.context("context")?;
    Ok(result)
}
```

## Panic Inventory

| # | Location | Panic Message | Strategy | Rationale |
|---|----------|--------------|----------|-----------|
| 1 | [{file}:{line}] | "must not be nil" | Keep as `panic!` | Startup-only invariant |
| 2 | [{file}:{line}] | "unreachable" | `unreachable!()` | Dead code path |
| 3 | [{file}:{line}] | recoverable | Convert to `Result` | Should not panic in production |

## Ignored Error Inventory

| # | Location | Go Code | Risk | Rust Strategy |
|---|----------|---------|------|---------------|
| 1 | [{file}:{line}] | `_ = f.Close()` | Low (cleanup) | `let _ = f.close()` |
| 2 | [{file}:{line}] | `conn, _ := Dial()` | High | Must handle with `?` |

## Crate Dependencies

```toml
[dependencies]
thiserror = "2"
anyhow = "1"
```
```

## Completeness Check

- [ ] Every `(T, error)` return is mapped to `Result<T, E>`
- [ ] Every `(T, bool)` return is mapped to `Option<T>`
- [ ] Every sentinel error (`var Err... = errors.New(...)`) has an enum variant
- [ ] Every custom error type (struct with `Error() string`) has a thiserror enum
- [ ] Every `if err != nil` block has a Rust `?` or match equivalent
- [ ] Every `fmt.Errorf("...: %w", err)` is mapped to `.context()` or `.map_err()`
- [ ] Every `errors.Is()` call is mapped to pattern matching
- [ ] Every `errors.As()` call is mapped to downcast or pattern matching
- [ ] Every `panic()` is categorized as keep-panic or convert-to-Result
- [ ] Every `recover()` boundary is replaced with Result or removed (framework handles)
- [ ] Every ignored error (`_, _ :=`) is audited and explicitly handled or documented
- [ ] Error hierarchy diagram covers all modules
- [ ] `From` implementations are defined for all cross-module error conversions
- [ ] `thiserror` derive macros have human-readable `#[error("...")]` messages
