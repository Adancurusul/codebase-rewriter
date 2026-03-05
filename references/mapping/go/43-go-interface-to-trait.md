# 43 - Go Interface to Rust Trait

**Output**: `.migration-plan/mappings/go-interface-to-trait.md`

## Purpose

Map every Go interface definition and its implicit satisfaction pattern to Rust's explicit trait system. Go uses structural typing: any type that has the right method set automatically satisfies an interface with no declaration needed. Rust uses nominal typing: every trait implementation must be explicitly declared with `impl Trait for Type`. This guide covers interface definitions, implicit satisfaction, interface embedding, empty interfaces, type assertions, standard library interface mappings, and testing with mock interfaces. Every interface and every type that satisfies it in the Go source must receive a concrete Rust trait definition and explicit `impl` block.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- inventory of all interfaces and their method sets
- `architecture.md` -- module boundaries, cross-package interface usage
- `dependency-tree.md` -- external interfaces imported and implemented

Extract every instance of:
- Interface definitions (including method signatures)
- Interface embedding (composing interfaces)
- Types that satisfy each interface (implicit satisfaction)
- `interface{}` / `any` usage
- Type assertions (`v.(Type)`)
- Type switches (`switch v.(type)`)
- Interface values as function parameters
- Interface slices (`[]Interface`)
- Interface values stored in structs
- Standard library interfaces implemented (`io.Reader`, `io.Writer`, `fmt.Stringer`, etc.)
- Compile-time interface checks (`var _ Interface = (*Type)(nil)`)
- Interface-based mocking in tests

### Step 2: For each interface, determine Rust equivalent

**Interface conversion decision tree:**

```
Is this interface empty (interface{} / any)?
  YES ->
    Is the set of possible types known?
      YES -> Use an enum (sum type)
      NO  -> Use generics <T> or Box<dyn Any>

Is this interface used as a function parameter?
  YES ->
    Does the caller always know the concrete type?
      YES -> Use generics: fn foo<T: Trait>(x: T)
      NO  -> Use trait objects: fn foo(x: &dyn Trait)

Is this interface stored in a collection?
  YES -> Vec<Box<dyn Trait>> or Vec<Arc<dyn Trait>>

Does this interface have async methods?
  YES -> Use #[async_trait] or return Pin<Box<dyn Future>>

Is this interface used for testing/mocking?
  YES -> Define trait, use mockall for test doubles
```

**Method signature conversion:**

| Go Method Signature | Rust Trait Method |
|--------------------|-------------------|
| `Method()` | `fn method(&self)` |
| `Method() error` | `fn method(&self) -> Result<(), E>` |
| `Method() (T, error)` | `fn method(&self) -> Result<T, E>` |
| `Method(ctx context.Context)` | `async fn method(&self, cancel: CancellationToken)` |
| `Method(a A, b B) (C, error)` | `fn method(&self, a: A, b: B) -> Result<C, E>` |

### Step 3: Produce interface mapping document

For EACH interface found in the source, produce:
1. Go interface definition with file:line reference
2. Rust trait definition with full method signatures
3. List of all types that implement this interface
4. Explicit `impl Trait for Type` blocks for each implementor
5. Usage sites (function parameters, struct fields, collections)

## Code Examples

### Example 1: Basic Interface to Trait (Implicit to Explicit)

**Go:**
```go
// repository.go
type UserRepository interface {
    FindByID(ctx context.Context, id int64) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id int64) error
}

// postgres_repo.go -- implicitly satisfies UserRepository
type PostgresUserRepo struct {
    db *sql.DB
}

func (r *PostgresUserRepo) FindByID(ctx context.Context, id int64) (*User, error) {
    // implementation
}
func (r *PostgresUserRepo) FindByEmail(ctx context.Context, email string) (*User, error) {
    // implementation
}
func (r *PostgresUserRepo) Create(ctx context.Context, user *User) error {
    // implementation
}
func (r *PostgresUserRepo) Update(ctx context.Context, user *User) error {
    // implementation
}
func (r *PostgresUserRepo) Delete(ctx context.Context, id int64) error {
    // implementation
}
```

**Rust:**
```rust
// repository.rs
use async_trait::async_trait;

#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find_by_id(&self, id: i64) -> Result<Option<User>, RepoError>;
    async fn find_by_email(&self, email: &str) -> Result<Option<User>, RepoError>;
    async fn create(&self, user: &User) -> Result<(), RepoError>;
    async fn update(&self, user: &User) -> Result<(), RepoError>;
    async fn delete(&self, id: i64) -> Result<(), RepoError>;
}

// postgres_repo.rs -- explicit impl required
pub struct PostgresUserRepo {
    pool: sqlx::PgPool,
}

#[async_trait]
impl UserRepository for PostgresUserRepo {
    async fn find_by_id(&self, id: i64) -> Result<Option<User>, RepoError> {
        sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
            .bind(id)
            .fetch_optional(&self.pool)
            .await
            .map_err(RepoError::from)
    }

    async fn find_by_email(&self, email: &str) -> Result<Option<User>, RepoError> {
        sqlx::query_as::<_, User>("SELECT * FROM users WHERE email = $1")
            .bind(email)
            .fetch_optional(&self.pool)
            .await
            .map_err(RepoError::from)
    }

    async fn create(&self, user: &User) -> Result<(), RepoError> {
        sqlx::query("INSERT INTO users (name, email) VALUES ($1, $2)")
            .bind(&user.name)
            .bind(&user.email)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn update(&self, user: &User) -> Result<(), RepoError> {
        sqlx::query("UPDATE users SET name = $1, email = $2 WHERE id = $3")
            .bind(&user.name)
            .bind(&user.email)
            .bind(user.id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn delete(&self, id: i64) -> Result<(), RepoError> {
        sqlx::query("DELETE FROM users WHERE id = $1")
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
```

### Example 2: Interface Embedding to Supertrait

**Go:**
```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type ReadWriter interface {
    Reader
    Writer
}

type Closer interface {
    Close() error
}

type ReadWriteCloser interface {
    ReadWriter
    Closer
}
```

**Rust:**
```rust
pub trait Reader {
    fn read(&mut self, buf: &mut [u8]) -> Result<usize, IoError>;
}

pub trait Writer {
    fn write(&mut self, buf: &[u8]) -> Result<usize, IoError>;
}

// Supertrait: ReadWriter requires both Reader and Writer
pub trait ReadWriter: Reader + Writer {}

// Blanket implementation: any type implementing Reader + Writer gets ReadWriter
impl<T: Reader + Writer> ReadWriter for T {}

pub trait Closer {
    fn close(&mut self) -> Result<(), IoError>;
}

// Supertrait composition
pub trait ReadWriteCloser: Reader + Writer + Closer {}

impl<T: Reader + Writer + Closer> ReadWriteCloser for T {}
```

### Example 3: Empty Interface to Enum or Generics

**Go:**
```go
// Generic container using interface{}
type Cache struct {
    data map[string]interface{}
}

func (c *Cache) Set(key string, value interface{}) {
    c.data[key] = value
}

func (c *Cache) Get(key string) (interface{}, bool) {
    v, ok := c.data[key]
    return v, ok
}

// Usage:
// cache.Set("user:1", user)
// cache.Set("count", 42)
// val, ok := cache.Get("user:1")
// user := val.(*User)
```

**Rust (enum -- when the set of types is known, preferred):**
```rust
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub enum CacheValue {
    User(User),
    Count(i64),
    Text(String),
    Bytes(Vec<u8>),
}

pub struct Cache {
    data: HashMap<String, CacheValue>,
}

impl Cache {
    pub fn set(&mut self, key: String, value: CacheValue) {
        self.data.insert(key, value);
    }

    pub fn get(&self, key: &str) -> Option<&CacheValue> {
        self.data.get(key)
    }

    pub fn get_user(&self, key: &str) -> Option<&User> {
        match self.data.get(key) {
            Some(CacheValue::User(u)) => Some(u),
            _ => None,
        }
    }
}
```

**Rust (generics -- when the type is uniform per operation):**
```rust
use std::collections::HashMap;
use std::any::{Any, TypeId};

pub struct Cache {
    data: HashMap<String, Box<dyn Any + Send + Sync>>,
}

impl Cache {
    pub fn new() -> Self {
        Self { data: HashMap::new() }
    }

    pub fn set<T: Any + Send + Sync>(&mut self, key: String, value: T) {
        self.data.insert(key, Box::new(value));
    }

    pub fn get<T: Any>(&self, key: &str) -> Option<&T> {
        self.data.get(key)?.downcast_ref::<T>()
    }
}
```

### Example 4: Interface as Function Parameter

**Go:**
```go
// Interface parameter: accept any Logger
func ProcessWithLogging(logger Logger, data []byte) error {
    logger.Info("processing started", "size", len(data))
    result, err := process(data)
    if err != nil {
        logger.Error("processing failed", "error", err)
        return err
    }
    logger.Info("processing complete", "result_size", len(result))
    return nil
}
```

**Rust (generics -- zero-cost, monomorphized):**
```rust
pub fn process_with_logging<L: Logger>(logger: &L, data: &[u8]) -> Result<(), AppError> {
    logger.info(&format!("processing started, size={}", data.len()));
    let result = process(data)?;
    logger.info(&format!("processing complete, result_size={}", result.len()));
    Ok(())
}
```

**Rust (trait object -- dynamic dispatch, when generic is impractical):**
```rust
pub fn process_with_logging(logger: &dyn Logger, data: &[u8]) -> Result<(), AppError> {
    logger.info(&format!("processing started, size={}", data.len()));
    let result = process(data)?;
    logger.info(&format!("processing complete, result_size={}", result.len()));
    Ok(())
}
```

**Rust (impl Trait -- caller knows the type, concise syntax):**
```rust
pub fn process_with_logging(logger: &impl Logger, data: &[u8]) -> Result<(), AppError> {
    logger.info(&format!("processing started, size={}", data.len()));
    let result = process(data)?;
    logger.info(&format!("processing complete, result_size={}", result.len()));
    Ok(())
}
```

### Example 5: Interface Slice to Vec<Box<dyn Trait>>

**Go:**
```go
type Validator interface {
    Validate(value interface{}) error
}

type ValidationChain struct {
    validators []Validator
}

func (vc *ValidationChain) Add(v Validator) {
    vc.validators = append(vc.validators, v)
}

func (vc *ValidationChain) ValidateAll(value interface{}) error {
    for _, v := range vc.validators {
        if err := v.Validate(value); err != nil {
            return err
        }
    }
    return nil
}
```

**Rust:**
```rust
pub trait Validator: Send + Sync {
    fn validate(&self, value: &dyn std::any::Any) -> Result<(), ValidationError>;
}

pub struct ValidationChain {
    validators: Vec<Box<dyn Validator>>,
}

impl ValidationChain {
    pub fn new() -> Self {
        Self { validators: Vec::new() }
    }

    pub fn add(&mut self, validator: impl Validator + 'static) {
        self.validators.push(Box::new(validator));
    }

    pub fn validate_all(&self, value: &dyn std::any::Any) -> Result<(), ValidationError> {
        for validator in &self.validators {
            validator.validate(value)?;
        }
        Ok(())
    }
}

// Typed alternative (preferred when possible):
pub trait TypedValidator<T> {
    fn validate(&self, value: &T) -> Result<(), ValidationError>;
}

pub struct TypedValidationChain<T> {
    validators: Vec<Box<dyn TypedValidator<T>>>,
}

impl<T> TypedValidationChain<T> {
    pub fn validate_all(&self, value: &T) -> Result<(), ValidationError> {
        for validator in &self.validators {
            validator.validate(value)?;
        }
        Ok(())
    }
}
```

### Example 6: Standard Library Interface Mapping

**Go:**
```go
// Implementing io.Reader
type CountingReader struct {
    reader    io.Reader
    bytesRead int64
}

func (cr *CountingReader) Read(p []byte) (int, error) {
    n, err := cr.reader.Read(p)
    cr.bytesRead += int64(n)
    return n, err
}

// Implementing fmt.Stringer
type Money struct {
    Amount   int64
    Currency string
}

func (m Money) String() string {
    return fmt.Sprintf("%s %.2f", m.Currency, float64(m.Amount)/100)
}

// Implementing sort.Interface
type ByAge []Person

func (a ByAge) Len() int           { return len(a) }
func (a ByAge) Less(i, j int) bool { return a[i].Age < a[j].Age }
func (a ByAge) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
```

**Rust:**
```rust
// std::io::Read (equivalent of io.Reader)
use std::io::{self, Read};

pub struct CountingReader<R: Read> {
    reader: R,
    bytes_read: u64,
}

impl<R: Read> Read for CountingReader<R> {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let n = self.reader.read(buf)?;
        self.bytes_read += n as u64;
        Ok(n)
    }
}

// std::fmt::Display (equivalent of fmt.Stringer)
use std::fmt;

#[derive(Debug, Clone)]
pub struct Money {
    pub amount: i64,
    pub currency: String,
}

impl fmt::Display for Money {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} {:.2}", self.currency, self.amount as f64 / 100.0)
    }
}

// Ord trait (equivalent of sort.Interface)
// Rust uses derive or manual Ord implementation, no separate sort type needed
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct Person {
    pub name: String,
    pub age: u32,
}

impl Ord for Person {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.age.cmp(&other.age)
    }
}

impl PartialOrd for Person {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

// Usage: people.sort(); -- no wrapper type needed
```

**Standard library interface mapping reference:**

| Go Interface | Rust Trait | Notes |
|-------------|-----------|-------|
| `io.Reader` | `std::io::Read` | `read(&mut self, buf: &mut [u8]) -> io::Result<usize>` |
| `io.Writer` | `std::io::Write` | `write(&mut self, buf: &[u8]) -> io::Result<usize>` |
| `io.Closer` | `Drop` or manual `close()` | Rust uses `Drop` for automatic cleanup |
| `io.ReadCloser` | `Read` + manual `close()` | Or wrap in `BufReader` |
| `io.ReadWriter` | `Read + Write` | Supertrait composition |
| `fmt.Stringer` | `std::fmt::Display` | `fmt(&self, f: &mut Formatter) -> fmt::Result` |
| `fmt.GoStringer` | `std::fmt::Debug` | `#[derive(Debug)]` is idiomatic |
| `error` | `std::error::Error` | Usually via `thiserror` derive |
| `sort.Interface` | `Ord + PartialOrd + Eq + PartialEq` | Use `#[derive(Ord, ...)]` |
| `encoding.BinaryMarshaler` | `serde::Serialize` | Via `serde` framework |
| `encoding.BinaryUnmarshaler` | `serde::Deserialize` | Via `serde` framework |
| `json.Marshaler` | `serde::Serialize` | `#[derive(Serialize)]` |
| `json.Unmarshaler` | `serde::Deserialize` | `#[derive(Deserialize)]` |
| `http.Handler` | Axum handler function | `async fn(req) -> impl IntoResponse` |
| `http.ResponseWriter` | `axum::response::Response` | Builder pattern |
| `context.Context` | `CancellationToken` + tracing | See concurrency mapping |
| `hash.Hash` | `std::hash::Hasher` | Via `Hash` derive |

### Example 7: Compile-Time Interface Check (Not Needed in Rust)

**Go:**
```go
// Compile-time check that PostgresUserRepo satisfies UserRepository
var _ UserRepository = (*PostgresUserRepo)(nil)
var _ io.ReadWriteCloser = (*MyStream)(nil)
```

**Rust:**
```rust
// Not needed! The compiler enforces this at the impl block.
// If PostgresUserRepo doesn't implement all methods of UserRepository,
// the code won't compile.

// The Rust equivalent already guarantees this:
impl UserRepository for PostgresUserRepo {
    // If any method is missing, compilation fails with:
    // "not all trait items implemented, missing: `find_by_id`"
}

// If you want to assert a trait is object-safe (can be used as dyn Trait):
fn _assert_object_safe(_: &dyn UserRepository) {}
```

### Example 8: Mock Interface for Testing

**Go:**
```go
// In tests, create a mock that satisfies the interface
type MockUserRepo struct {
    FindByIDFunc func(ctx context.Context, id int64) (*User, error)
    CreateFunc   func(ctx context.Context, user *User) error
}

func (m *MockUserRepo) FindByID(ctx context.Context, id int64) (*User, error) {
    return m.FindByIDFunc(ctx, id)
}

func (m *MockUserRepo) Create(ctx context.Context, user *User) error {
    return m.CreateFunc(ctx, user)
}

// Usage in test:
func TestService(t *testing.T) {
    repo := &MockUserRepo{
        FindByIDFunc: func(ctx context.Context, id int64) (*User, error) {
            return &User{ID: id, Name: "test"}, nil
        },
    }
    svc := NewService(repo)
    // ... test svc
}
```

**Rust (with mockall):**
```rust
// In trait definition, add mockall attribute:
#[cfg_attr(test, mockall::automock)]
#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find_by_id(&self, id: i64) -> Result<Option<User>, RepoError>;
    async fn create(&self, user: &User) -> Result<(), RepoError>;
}

// In tests:
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[tokio::test]
    async fn test_service() {
        let mut mock_repo = MockUserRepository::new();

        mock_repo
            .expect_find_by_id()
            .with(eq(1))
            .returning(|id| Ok(Some(User { id, name: "test".into() })));

        mock_repo
            .expect_create()
            .returning(|_| Ok(()));

        let svc = Service::new(Arc::new(mock_repo));
        let user = svc.get_user(1).await.unwrap();
        assert_eq!(user.unwrap().name, "test");
    }
}
```

### Example 9: Type Assertion to Trait Upcasting or Enum

**Go:**
```go
// Interface upgrade: check if a type supports additional methods
type ReadCloser interface {
    io.Reader
    io.Closer
}

func ProcessStream(r io.Reader) error {
    // Check if the reader also supports Close
    if closer, ok := r.(io.Closer); ok {
        defer closer.Close()
    }

    // Process the reader
    data, err := io.ReadAll(r)
    // ...
}
```

**Rust (trait upcasting -- unstable, use alternatives):**
```rust
use std::io::Read;

// Option A: Accept the broader trait from the start
pub fn process_stream(r: &mut (impl Read + 'static)) -> Result<(), AppError> {
    let mut data = Vec::new();
    r.read_to_end(&mut data)?;
    // ...
    Ok(())
}

// Option B: Use an enum for known concrete types
pub enum StreamSource {
    File(std::fs::File),       // implements Read + close via Drop
    Buffer(std::io::Cursor<Vec<u8>>),  // implements Read, no close needed
    Network(std::net::TcpStream),      // implements Read + close via Drop
}

impl Read for StreamSource {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        match self {
            Self::File(f) => f.read(buf),
            Self::Buffer(b) => b.read(buf),
            Self::Network(s) => s.read(buf),
        }
    }
}
// Drop is automatic for all variants -- no explicit Close needed in Rust

// Option C: Use a custom trait that combines Read with optional close
pub trait ReadMaybeClose: Read {
    fn close_if_needed(&mut self) -> Result<(), std::io::Error> {
        Ok(()) // default: no-op
    }
}
```

### Example 10: Interface with Dependency Injection

**Go:**
```go
type Service struct {
    repo   UserRepository
    cache  CacheService
    mailer EmailService
}

func NewService(repo UserRepository, cache CacheService, mailer EmailService) *Service {
    return &Service{
        repo:   repo,
        cache:  cache,
        mailer: mailer,
    }
}
```

**Rust (trait objects in Arc -- dynamic dispatch):**
```rust
pub struct Service {
    repo: Arc<dyn UserRepository>,
    cache: Arc<dyn CacheService>,
    mailer: Arc<dyn EmailService>,
}

impl Service {
    pub fn new(
        repo: Arc<dyn UserRepository>,
        cache: Arc<dyn CacheService>,
        mailer: Arc<dyn EmailService>,
    ) -> Self {
        Self { repo, cache, mailer }
    }
}
```

**Rust (generics -- static dispatch, zero-cost):**
```rust
pub struct Service<R, C, M>
where
    R: UserRepository,
    C: CacheService,
    M: EmailService,
{
    repo: R,
    cache: C,
    mailer: M,
}

impl<R, C, M> Service<R, C, M>
where
    R: UserRepository,
    C: CacheService,
    M: EmailService,
{
    pub fn new(repo: R, cache: C, mailer: M) -> Self {
        Self { repo, cache, mailer }
    }
}
```

## Template

```markdown
# Go Interface to Rust Trait Mapping

Source: {project_name}
Generated: {date}

## Interface Inventory

### 1. {InterfaceName}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Method count**: {N}
**Embeds**: {list of embedded interfaces, or "none"}
**Async**: {yes/no}

**Go definition**:
```go
type InterfaceName interface {
    EmbeddedInterface
    Method1(args) (returns, error)
    Method2(args) returns
}
```

**Rust trait**:
```rust
#[async_trait]
pub trait InterfaceName: Send + Sync {
    async fn method1(&self, args: Args) -> Result<Returns, Error>;
    fn method2(&self, args: Args) -> Returns;
}
```

**Implementors**:

| # | Go Type | File | Pointer Receiver? | Rust impl |
|---|---------|------|-------------------|-----------|
| 1 | `ConcreteTypeA` | [{file}:{line}] | Yes | `impl InterfaceName for ConcreteTypeA` |
| 2 | `ConcreteTypeB` | [{file}:{line}] | No | `impl InterfaceName for ConcreteTypeB` |

**Usage sites**:

| # | Usage | File | Rust Pattern |
|---|-------|------|-------------|
| 1 | Function parameter | [{file}:{line}] | `impl Trait` or `&dyn Trait` |
| 2 | Struct field | [{file}:{line}] | `Arc<dyn Trait>` |
| 3 | Slice `[]Interface` | [{file}:{line}] | `Vec<Box<dyn Trait>>` |

---

## Empty Interface (interface{}) Usage

| # | Location | Purpose | Rust Strategy |
|---|----------|---------|---------------|
| 1 | [{file}:{line}] | Generic container | Enum with known variants |
| 2 | [{file}:{line}] | Printf-like args | Generics with Display bound |
| 3 | [{file}:{line}] | Truly dynamic | `Box<dyn Any>` |

## Type Assertion Inventory

| # | Location | Go Code | Rust Pattern |
|---|----------|---------|-------------|
| 1 | [{file}:{line}] | `v.(Type)` | `match` on enum |
| 2 | [{file}:{line}] | `v.(ExtendedInterface)` | Additional trait bound |

## Standard Library Trait Mapping

| Go Interface | Implementors in Source | Rust Trait | Notes |
|-------------|----------------------|-----------|-------|
| `io.Reader` | `TypeA, TypeB` | `std::io::Read` | |
| `fmt.Stringer` | `TypeC` | `std::fmt::Display` | |

## Crate Dependencies

```toml
[dependencies]
async-trait = "0.1"

[dev-dependencies]
mockall = "0.13"
```
```

## Completeness Check

- [ ] Every Go interface definition has a Rust trait definition
- [ ] Every type that implicitly satisfies an interface has an explicit `impl Trait for Type`
- [ ] Every embedded interface is mapped to a supertrait
- [ ] Every `interface{}` / `any` usage is mapped to enum, generics, or `Box<dyn Any>`
- [ ] Every type assertion is mapped to pattern matching or downcast
- [ ] Every type switch is mapped to exhaustive `match`
- [ ] Every interface used as a function parameter has a generics-vs-trait-object decision
- [ ] Every interface slice is mapped to `Vec<Box<dyn Trait>>` or `Vec<Arc<dyn Trait>>`
- [ ] Every standard library interface implementation is mapped to the Rust equivalent trait
- [ ] Every interface used for mocking has `mockall` integration documented
- [ ] Compile-time interface checks are noted as unnecessary in Rust
- [ ] `async_trait` is applied to traits with async methods
- [ ] All trait objects have `Send + Sync` bounds where needed for async contexts
- [ ] Object safety is verified for traits used as `dyn Trait`
