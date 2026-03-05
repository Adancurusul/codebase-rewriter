# 40 - Go Types to Rust Types

**Output**: Contributes to `.migration-plan/mappings/type-mapping.md`

## Purpose

Map every Go type construct -- structs, interfaces, type aliases, named types, pointers, slices, maps, channels, and function types -- to its Rust equivalent. Go's type system is structurally typed with implicit interface satisfaction and pervasive pointer usage. Rust's type system is nominally typed with explicit trait implementations, ownership semantics, and no null pointers. Every type definition and type usage pattern in the Go source must receive a concrete Rust translation with compilable code.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- inventory of all structs, interfaces, type aliases, named types
- `architecture.md` -- module boundaries, type visibility, cross-package type usage
- `dependency-tree.md` -- external types imported from third-party packages

Extract every instance of:
- Struct definitions (fields, embedded structs, tags)
- Interface definitions (method sets)
- Type aliases and named types
- Pointer types and pointer receivers
- Slice and array types
- Map types
- Channel types
- Function types and closures
- Type assertions and type switches
- Method sets (value vs pointer receivers)
- Zero value reliance

### Step 2: For each Go type, determine Rust equivalent

Apply this conversion table for EVERY type found:

| Go Type | Rust Equivalent | Notes |
|---------|----------------|-------|
| `struct { fields }` | `struct { fields }` | Direct mapping, add `#[derive(...)]` |
| Embedded struct | Field + `Deref` impl or trait delegation | See examples below |
| `interface { methods }` | `trait { methods }` | Must add explicit `impl` |
| `interface{}` / `any` | `Box<dyn Any>` or generic `T` | Prefer generics |
| `type Name = Existing` | `type Name = Existing;` | Direct type alias |
| `type Name Underlying` | Newtype: `struct Name(Underlying);` | Preserves type safety |
| `*T` (pointer) | `&T`, `&mut T`, `Box<T>`, or `Option<Box<T>>` | See decision tree |
| `[]T` (slice) | `Vec<T>` (owned) or `&[T]` (borrowed) | Depends on ownership |
| `[N]T` (array) | `[T; N]` | Direct mapping |
| `map[K]V` | `HashMap<K, V>` or `BTreeMap<K, V>` | Add `use std::collections::HashMap` |
| `chan T` | `mpsc::Sender<T>` / `mpsc::Receiver<T>` | See async mapping guide |
| `func(A) B` | `fn(A) -> B` or `Fn(A) -> B` trait | See function types below |
| `error` | `Result<T, E>` with custom error enum | See error mapping guide |

**Pointer decision tree:**

```
Is this a nullable pointer (can be nil)?
  YES -> Option<Box<T>> or Option<&T>
  NO  ->
    Is ownership transferred?
      YES -> Box<T> (heap) or T (move)
      NO  ->
        Is the referent mutated?
          YES -> &mut T
          NO  -> &T
```

**Zero value decision tree:**

```
Does the code rely on zero values?
  YES -> Implement Default trait
  NO  -> Use constructors (new/builder pattern)
```

### Step 3: Produce type mapping document

For EACH type found in the source, produce an entry with:
1. Go source type with file:line reference
2. Rust target type with full definition
3. Derive macros needed (`Debug`, `Clone`, `Serialize`, etc.)
4. Conversion notes (field renames, visibility changes, etc.)
5. Any trait implementations required

## Code Examples

### Example 1: Struct to Struct

**Go:**
```go
// models/user.go
type User struct {
    ID        int64     `json:"id" db:"id"`
    Email     string    `json:"email" db:"email"`
    Name      string    `json:"name" db:"name"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
    IsActive  bool      `json:"is_active" db:"is_active"`
}
```

**Rust:**
```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct User {
    pub id: i64,
    pub email: String,
    pub name: String,
    #[serde(rename = "created_at")]
    pub created_at: DateTime<Utc>,
    #[serde(rename = "is_active")]
    pub is_active: bool,
}
```

### Example 2: Embedded Struct to Composition

**Go:**
```go
type BaseModel struct {
    ID        int64     `json:"id"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type Product struct {
    BaseModel
    Name  string  `json:"name"`
    Price float64 `json:"price"`
}

// Usage: product.ID, product.CreatedAt (promoted fields)
```

**Rust (field composition):**
```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BaseModel {
    pub id: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Product {
    #[serde(flatten)]
    pub base: BaseModel,
    pub name: String,
    pub price: f64,
}

// If promoted field access is heavily used, implement Deref:
impl std::ops::Deref for Product {
    type Target = BaseModel;
    fn deref(&self) -> &BaseModel {
        &self.base
    }
}

// Usage: product.id, product.created_at (via Deref)
// Or explicitly: product.base.id
```

### Example 3: Interface to Trait

**Go:**
```go
type Storage interface {
    Get(ctx context.Context, key string) ([]byte, error)
    Set(ctx context.Context, key string, value []byte, ttl time.Duration) error
    Delete(ctx context.Context, key string) error
}
```

**Rust:**
```rust
use async_trait::async_trait;
use std::time::Duration;

#[async_trait]
pub trait Storage: Send + Sync {
    async fn get(&self, key: &str) -> Result<Option<Vec<u8>>, StorageError>;
    async fn set(&self, key: &str, value: &[u8], ttl: Duration) -> Result<(), StorageError>;
    async fn delete(&self, key: &str) -> Result<(), StorageError>;
}
```

### Example 4: Type Assertion to Match

**Go:**
```go
func processValue(v interface{}) string {
    switch val := v.(type) {
    case string:
        return val
    case int:
        return strconv.Itoa(val)
    case *User:
        return val.Name
    default:
        return fmt.Sprintf("%v", val)
    }
}
```

**Rust (using enum -- preferred):**
```rust
pub enum Value {
    Text(String),
    Number(i64),
    User(Box<User>),
}

pub fn process_value(v: &Value) -> String {
    match v {
        Value::Text(s) => s.clone(),
        Value::Number(n) => n.to_string(),
        Value::User(u) => u.name.clone(),
    }
}
```

**Rust (using `dyn Any` -- when enum is impractical):**
```rust
use std::any::Any;

pub fn process_value(v: &dyn Any) -> String {
    if let Some(s) = v.downcast_ref::<String>() {
        s.clone()
    } else if let Some(n) = v.downcast_ref::<i64>() {
        n.to_string()
    } else if let Some(u) = v.downcast_ref::<User>() {
        u.name.clone()
    } else {
        String::from("<unknown>")
    }
}
```

### Example 5: Named Type (Newtype Pattern)

**Go:**
```go
type UserID int64
type Email string
type Latitude float64
type Longitude float64

func (e Email) Validate() error {
    if !strings.Contains(string(e), "@") {
        return errors.New("invalid email")
    }
    return nil
}
```

**Rust:**
```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UserId(pub i64);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Email(pub String);

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Latitude(pub f64);

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Longitude(pub f64);

impl Email {
    pub fn validate(&self) -> Result<(), ValidationError> {
        if !self.0.contains('@') {
            return Err(ValidationError::InvalidEmail(self.0.clone()));
        }
        Ok(())
    }
}

// Implement Display for string-like newtypes
impl std::fmt::Display for Email {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

// Implement From for easy conversion
impl From<i64> for UserId {
    fn from(id: i64) -> Self {
        UserId(id)
    }
}
```

### Example 6: Pointer Types to Rust Ownership

**Go:**
```go
type Node struct {
    Value    int
    Children []*Node   // owned child pointers
    Parent   *Node     // nullable back-reference
}

func NewNode(value int, parent *Node) *Node {
    return &Node{
        Value:  value,
        Parent: parent,
    }
}

func (n *Node) AddChild(value int) *Node {
    child := NewNode(value, n)
    n.Children = append(n.Children, child)
    return child
}
```

**Rust:**
```rust
use std::sync::{Arc, Weak, Mutex};

pub struct Node {
    pub value: i32,
    pub children: Vec<Arc<Mutex<Node>>>,
    pub parent: Option<Weak<Mutex<Node>>>,   // Weak breaks reference cycle
}

impl Node {
    pub fn new(value: i32) -> Arc<Mutex<Self>> {
        Arc::new(Mutex::new(Node {
            value,
            children: Vec::new(),
            parent: None,
        }))
    }

    pub fn add_child(parent: &Arc<Mutex<Node>>, value: i32) -> Arc<Mutex<Node>> {
        let child = Arc::new(Mutex::new(Node {
            value,
            children: Vec::new(),
            parent: Some(Arc::downgrade(parent)),
        }));
        parent.lock().unwrap().children.push(Arc::clone(&child));
        child
    }
}
```

### Example 7: Map and Slice Types

**Go:**
```go
type Config struct {
    Settings map[string]string
    Tags     []string
    Limits   [3]int
}

func (c *Config) GetSetting(key string) (string, bool) {
    val, ok := c.Settings[key]
    return val, ok
}

func (c *Config) HasTag(tag string) bool {
    for _, t := range c.Tags {
        if t == tag {
            return true
        }
    }
    return false
}
```

**Rust:**
```rust
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct Config {
    pub settings: HashMap<String, String>,
    pub tags: Vec<String>,
    pub limits: [i32; 3],
}

impl Config {
    pub fn get_setting(&self, key: &str) -> Option<&str> {
        self.settings.get(key).map(|s| s.as_str())
    }

    pub fn has_tag(&self, tag: &str) -> bool {
        self.tags.iter().any(|t| t == tag)
    }
}
```

### Example 8: Function Types

**Go:**
```go
type Handler func(ctx context.Context, req *Request) (*Response, error)

type Middleware func(Handler) Handler

func LoggingMiddleware(next Handler) Handler {
    return func(ctx context.Context, req *Request) (*Response, error) {
        log.Printf("handling request: %s", req.Path)
        resp, err := next(ctx, req)
        log.Printf("response status: %d", resp.Status)
        return resp, err
    }
}
```

**Rust:**
```rust
use std::future::Future;
use std::pin::Pin;

// Type alias for async handler function
pub type Handler = Box<
    dyn Fn(Request) -> Pin<Box<dyn Future<Output = Result<Response, AppError>> + Send>>
        + Send
        + Sync,
>;

// Middleware as a function that wraps a handler
pub type Middleware = Box<dyn Fn(Handler) -> Handler + Send + Sync>;

// Alternatively, use traits for a cleaner API (preferred):
#[async_trait::async_trait]
pub trait Handler: Send + Sync {
    async fn handle(&self, req: Request) -> Result<Response, AppError>;
}

pub fn logging_middleware<H: Handler + 'static>(next: H) -> impl Handler {
    struct LoggingHandler<H> {
        next: H,
    }

    #[async_trait::async_trait]
    impl<H: Handler> Handler for LoggingHandler<H> {
        async fn handle(&self, req: Request) -> Result<Response, AppError> {
            tracing::info!(path = %req.path, "handling request");
            let resp = self.next.handle(req).await?;
            tracing::info!(status = resp.status, "response");
            Ok(resp)
        }
    }

    LoggingHandler { next }
}
```

### Example 9: Method Sets (Value vs Pointer Receiver)

**Go:**
```go
type Counter struct {
    count int
}

// Value receiver: does not mutate
func (c Counter) Count() int {
    return c.count
}

// Pointer receiver: mutates
func (c *Counter) Increment() {
    c.count++
}

// Pointer receiver: mutates
func (c *Counter) Reset() {
    c.count = 0
}
```

**Rust:**
```rust
pub struct Counter {
    count: i32,
}

impl Counter {
    // &self: equivalent to Go value receiver (read-only)
    pub fn count(&self) -> i32 {
        self.count
    }

    // &mut self: equivalent to Go pointer receiver (mutates)
    pub fn increment(&mut self) {
        self.count += 1;
    }

    // &mut self: equivalent to Go pointer receiver (mutates)
    pub fn reset(&mut self) {
        self.count = 0;
    }
}
```

### Example 10: Channel Types

**Go:**
```go
type Job struct {
    ID   int
    Data string
}

func producer(jobs chan<- Job) {
    for i := 0; i < 100; i++ {
        jobs <- Job{ID: i, Data: fmt.Sprintf("job-%d", i)}
    }
    close(jobs)
}

func consumer(jobs <-chan Job, results chan<- string) {
    for job := range jobs {
        results <- fmt.Sprintf("processed: %s", job.Data)
    }
    close(results)
}
```

**Rust:**
```rust
use tokio::sync::mpsc;

pub struct Job {
    pub id: i32,
    pub data: String,
}

pub async fn producer(tx: mpsc::Sender<Job>) {
    for i in 0..100 {
        let job = Job {
            id: i,
            data: format!("job-{i}"),
        };
        if tx.send(job).await.is_err() {
            break; // receiver dropped
        }
    }
    // tx is dropped here, closing the channel
}

pub async fn consumer(mut rx: mpsc::Receiver<Job>, tx: mpsc::Sender<String>) {
    while let Some(job) = rx.recv().await {
        let result = format!("processed: {}", job.data);
        if tx.send(result).await.is_err() {
            break;
        }
    }
    // tx is dropped here, closing the results channel
}
```

## Template

```markdown
# Go Types to Rust Mapping

Source: {project_name}
Generated: {date}

## Primitive Type Mapping

| Go Type | Rust Type | Notes |
|---------|-----------|-------|
| `bool` | `bool` | |
| `int` | `i64` | Go int is platform-dependent; use i64 for safety |
| `int8` | `i8` | |
| `int16` | `i16` | |
| `int32` / `rune` | `i32` | `rune` is a Unicode code point |
| `int64` | `i64` | |
| `uint` | `u64` | |
| `uint8` / `byte` | `u8` | |
| `uint16` | `u16` | |
| `uint32` | `u32` | |
| `uint64` | `u64` | |
| `uintptr` | `usize` | |
| `float32` | `f32` | |
| `float64` | `f64` | |
| `complex64` | `num::Complex<f32>` | Requires `num` crate |
| `complex128` | `num::Complex<f64>` | Requires `num` crate |
| `string` | `String` (owned) / `&str` (borrowed) | |
| `[]byte` | `Vec<u8>` (owned) / `&[u8]` (borrowed) | |
| `error` | `Result<T, E>` | See error mapping guide |

## Struct Inventory

### 1. {StructName}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Go definition**:
```go
type StructName struct {
    Field1 Type1 `json:"field1"`
    Field2 Type2 `json:"field2"`
}
```

**Rust definition**:
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructName {
    pub field1: RustType1,
    pub field2: RustType2,
}
```

**Derive macros**: `Debug, Clone, Serialize, Deserialize`
**Notes**: {any field renames, visibility changes, or special handling}

---

## Interface Inventory

### 1. {InterfaceName}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Go definition**:
```go
type InterfaceName interface {
    Method1(args) (returns, error)
}
```

**Rust trait**:
```rust
#[async_trait::async_trait]
pub trait InterfaceName: Send + Sync {
    async fn method1(&self, args: Args) -> Result<Returns, Error>;
}
```

**Implementors**: {list of structs that satisfy this interface}

---

## Named Type Inventory

| # | Go Named Type | File | Rust Newtype | Derives |
|---|--------------|------|-------------|---------|
| 1 | `type X Y` | [{file}:{line}] | `struct X(Y);` | `Debug, Clone, ...` |

## Type Assertion / Type Switch Inventory

| # | Location | Go Pattern | Rust Pattern | Notes |
|---|----------|-----------|-------------|-------|
| 1 | [{file}:{line}] | `v.(Type)` | `match` on enum | Replace with enum |
| 2 | [{file}:{line}] | `switch v.(type)` | `match` on enum | Exhaustive |

## Zero Value Reliance

| # | Type | File | Zero Value Used | Rust Strategy |
|---|------|------|----------------|---------------|
| 1 | `User` | [{file}:{line}] | `User{}` | `impl Default for User` |
| 2 | `Config` | [{file}:{line}] | `Config{}` | `Config::default()` |
```

## Completeness Check

- [ ] Every struct definition has a Rust struct with appropriate derive macros
- [ ] Every embedded struct is converted to composition (field + optional Deref)
- [ ] Every interface is converted to a trait with explicit `impl` blocks listed
- [ ] Every `interface{}` / `any` usage is converted to enum or generics
- [ ] Every type alias is mapped (alias vs newtype decision documented)
- [ ] Every named type has a newtype wrapper with appropriate derives
- [ ] Every pointer type has an ownership strategy (Box, &T, &mut T, Option)
- [ ] Every slice type has owned/borrowed decision (Vec vs &[T])
- [ ] Every map type has a HashMap/BTreeMap decision
- [ ] Every channel type is mapped to appropriate tokio channel
- [ ] Every function type is mapped to fn pointer or Fn trait
- [ ] Every type assertion is converted to match on enum or downcast
- [ ] Every type switch is converted to exhaustive match
- [ ] Every method set is mapped to impl block with correct self receivers
- [ ] Every zero-value usage is replaced with Default trait or constructor
- [ ] Struct field JSON tags are mapped to serde attributes
- [ ] Struct field db tags are mapped to sqlx/diesel attributes
