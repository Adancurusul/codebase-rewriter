# 13 - Generics and Traits Mapping

**Output**: `.migration-plan/mappings/pattern-transforms.md` (generics/traits section)

## Purpose

Map the source language's interfaces, abstract classes, generics, type parameters, and polymorphism patterns to Rust traits, generics, and enum-based dispatch. This guide determines whether each abstraction becomes a trait, a generic constraint, an enum, or a concrete type -- and whether dispatch is static (`impl Trait`) or dynamic (`dyn Trait`).

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- all interfaces, abstract classes, generic types, type parameters
- `architecture.md` -- dependency injection patterns, plugin systems, strategy patterns

Extract every instance of:
- Interface/protocol/abstract class definitions
- Generic/parameterized types
- Type parameters and constraints
- Polymorphic function arguments (accepts multiple types)
- Dependency injection (constructor injection, service locators)
- Factory patterns
- Strategy/plugin patterns
- Union types / sum types
- Type aliases and type-level computation

### Step 2: For each abstraction, determine Rust equivalent

**Decision tree for interfaces/abstract classes:**

```
Is it implemented by a KNOWN, FIXED set of types?
  YES -> Use enum (fastest, most idiomatic)
    Example: Shape = Circle | Rectangle | Triangle

  NO (open-ended, user-extensible) ->
    Does the consumer need to store/own the implementor?
      YES ->
        Is the exact type known at compile time?
          YES -> Use generics: struct Container<T: MyTrait>
          NO  -> Use trait object: struct Container { inner: Box<dyn MyTrait> }
      NO (just needs to call methods) ->
        Is this in a hot path (performance critical)?
          YES -> Use generics: fn process(item: impl MyTrait)
          NO  -> Either works; prefer impl Trait for simplicity

    Does it need to work across threads?
      YES -> Add Send + Sync bounds: Box<dyn MyTrait + Send + Sync>
      NO  -> Box<dyn MyTrait> is fine
```

**Decision tree for generic types:**

```
Is the type parameter constrained (bounded)?
  YES -> Use trait bounds: fn foo<T: Clone + Debug>(item: T)
  NO  -> Use unbounded generic: fn foo<T>(item: T)

Are there multiple type parameters?
  YES -> List all bounds: fn foo<K: Hash + Eq, V: Clone>(map: HashMap<K, V>)

Is the generic used in a return position?
  YES ->
    Is the concrete type known to the caller?
      YES -> Use generic: fn foo<T: FromStr>(input: &str) -> Result<T, E>
      NO  -> Use impl Trait: fn foo() -> impl Iterator<Item = i32>

Is this a generic struct?
  YES -> struct Cache<K: Hash + Eq, V> { inner: HashMap<K, V> }
```

**Common source-to-Rust mappings:**

| Source Concept | Rust Equivalent | When to Use |
|---------------|-----------------|-------------|
| Interface (TS/Go) | `trait` | Shared behavior contract |
| Abstract class (Python) | `trait` + default methods | Has both abstract and concrete methods |
| Generic class `Class<T>` | `struct Name<T: Bound>` | Type parameterization |
| Interface with one method | `Fn` trait or closure | Callback/strategy |
| Union type `A \| B \| C` | `enum Name { A(A), B(B), C(C) }` | Closed set of variants |
| `any` / `interface{}` / `object` | `Box<dyn Any>` (avoid) or redesign | Last resort |
| Optional interface method | Trait with default impl | `fn method(&self) -> T { default }` |
| Multiple inheritance | Multiple `trait` impls | Rust has no inheritance |
| Mixin | Trait with default methods | Reusable behavior |
| Type guard / type narrowing | `match` on enum variants | Pattern matching |

### Step 3: Produce mapping document

For EACH interface/abstract/generic found, produce:
1. Source definition with file:line reference
2. Rust equivalent (trait, enum, or generic) with compilable code
3. Rationale for the choice (why trait vs enum vs generic)
4. List of all implementors/variants
5. Dispatch strategy (static or dynamic)

## Template

```markdown
# Generics and Traits Mapping

Source: {project_name}
Generated: {date}

## Summary

| Source Interfaces | -> Traits | -> Enums | -> Generics | -> Removed |
|-------------------|-----------|----------|-------------|------------|
| {count} | {count} | {count} | {count} | {count} |

## Trait Definitions

### Trait: {TraitName}

**Source**: [{interface_name} in {file}:{line}](../src/{file}#L{line})
**Dispatch**: Static (`impl Trait`) / Dynamic (`dyn Trait`)
**Implementors**: {list of types that implement this}

Source interface:
```typescript
interface Repository<T> {
  findById(id: string): Promise<T | null>;
  findAll(filter: Filter): Promise<T[]>;
  create(data: CreateDto<T>): Promise<T>;
  update(id: string, data: UpdateDto<T>): Promise<T>;
  delete(id: string): Promise<void>;
}
```

Rust trait:
```rust
use async_trait::async_trait;

#[async_trait]
pub trait Repository: Send + Sync {
    type Entity: Send + Sync;
    type CreateInput: Send;
    type UpdateInput: Send;
    type Filter: Send;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Self::Entity>, DbError>;
    async fn find_all(&self, filter: Self::Filter) -> Result<Vec<Self::Entity>, DbError>;
    async fn create(&self, data: Self::CreateInput) -> Result<Self::Entity, DbError>;
    async fn update(&self, id: Uuid, data: Self::UpdateInput) -> Result<Self::Entity, DbError>;
    async fn delete(&self, id: Uuid) -> Result<(), DbError>;
}

// Concrete implementation
pub struct UserRepository {
    pool: Arc<PgPool>,
}

#[async_trait]
impl Repository for UserRepository {
    type Entity = User;
    type CreateInput = CreateUser;
    type UpdateInput = UpdateUser;
    type Filter = UserFilter;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, DbError> {
        sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
            .bind(id)
            .fetch_optional(&*self.pool)
            .await
            .map_err(DbError::from)
    }

    // ... other methods
}
```

**Rationale**: This is an open-ended abstraction (multiple entity types use it), so a trait is appropriate. Uses associated types instead of type parameters to avoid specifying types at every call site. `async_trait` is needed for async methods in traits (until native async trait support is stabilized for `dyn` dispatch).

**Crates**: `async-trait` (for `dyn` dispatch of async traits)

---

### Trait: {TraitName}

**Source**: [{file}:{line}](../src/{file}#L{line})
...

## Enum Types (Closed Polymorphism)

### Enum: {EnumName}

**Source**: [{type_name} in {file}:{line}](../src/{file}#L{line})
**Variants**: {count}
**Why enum over trait**: Fixed, known set of variants; enables exhaustive matching

Source union/discriminated union:
```typescript
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "rectangle"; width: number; height: number }
  | { kind: "triangle"; base: number; height: number };

function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "rectangle": return shape.width * shape.height;
    case "triangle": return 0.5 * shape.base * shape.height;
  }
}
```

Rust enum:
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Shape {
    Circle { radius: f64 },
    Rectangle { width: f64, height: f64 },
    Triangle { base: f64, height: f64 },
}

impl Shape {
    pub fn area(&self) -> f64 {
        match self {
            Shape::Circle { radius } => std::f64::consts::PI * radius * radius,
            Shape::Rectangle { width, height } => width * height,
            Shape::Triangle { base, height } => 0.5 * base * height,
        }
    }
}
```

**Rationale**: Fixed set of shapes, compiler enforces exhaustive matching, serde tag preserves JSON compatibility.

---

## Generic Structs and Functions

### Generic: {Name}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Type Parameters**: {list with bounds}

Source:
```typescript
class Cache<K extends string, V> {
  private store: Map<K, { value: V; expiresAt: number }>;

  get(key: K): V | undefined { ... }
  set(key: K, value: V, ttlMs: number): void { ... }
}
```

Rust:
```rust
use std::collections::HashMap;
use std::hash::Hash;
use std::time::{Duration, Instant};

pub struct Cache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    store: HashMap<K, CacheEntry<V>>,
}

struct CacheEntry<V> {
    value: V,
    expires_at: Instant,
}

impl<K, V> Cache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    pub fn new() -> Self {
        Self {
            store: HashMap::new(),
        }
    }

    pub fn get(&self, key: &K) -> Option<&V> {
        self.store.get(key).and_then(|entry| {
            if Instant::now() < entry.expires_at {
                Some(&entry.value)
            } else {
                None
            }
        })
    }

    pub fn set(&mut self, key: K, value: V, ttl: Duration) {
        self.store.insert(
            key,
            CacheEntry {
                value,
                expires_at: Instant::now() + ttl,
            },
        );
    }
}
```

**Rationale**: Direct generic translation. `Eq + Hash` bounds replace the `extends string` constraint. `Clone` bound added because Rust requires explicit copyability.

---

## Dispatch Strategy Summary

| Abstraction | Source | Dispatch | Rationale |
|-------------|--------|----------|-----------|
| `Repository` | Interface | Dynamic (`Box<dyn>`) | Need to store in `AppState`, swap impls for testing |
| `Middleware` | Interface | Dynamic (`Box<dyn>`) | Plugin-style chain of handlers |
| `Serializer` | Interface | Static (`impl`) | Known at compile time, hot path |
| `Shape` | Union type | Enum | Fixed variants, exhaustive matching |
| `Cache<K,V>` | Generic class | Generic struct | Direct type parameterization |
| `EventHandler` | Callback | `Fn` trait | Single method, closure-compatible |

## Dependency Injection Mapping

Source DI pattern:
```typescript
class UserService {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly emailService: EmailService,
    private readonly logger: Logger,
  ) {}
}
```

Rust equivalent (no DI framework needed):
```rust
pub struct UserService {
    user_repo: Arc<dyn UserRepository>,
    email_service: Arc<dyn EmailService>,
    // Logger is global via tracing, not injected
}

impl UserService {
    pub fn new(
        user_repo: Arc<dyn UserRepository>,
        email_service: Arc<dyn EmailService>,
    ) -> Self {
        Self { user_repo, email_service }
    }
}

// In main.rs or app setup:
let user_repo = Arc::new(PostgresUserRepository::new(pool.clone()));
let email_service = Arc::new(SmtpEmailService::new(smtp_config));
let user_service = Arc::new(UserService::new(user_repo, email_service));
```

**Rationale**: Rust does not need a DI container. Constructor injection with `Arc<dyn Trait>` provides testability and runtime flexibility. For testing, pass `Arc<MockUserRepository>`.

## Closures and Function Traits

| Source Pattern | Rust Equivalent |
|---------------|-----------------|
| `(x: number) => number` | `Fn(i64) -> i64` or `fn(i64) -> i64` |
| `callback: (err, result) => void` | `FnOnce(Result<T, E>)` |
| Stored callback | `Box<dyn Fn(T) -> R + Send>` |
| One-shot callback | `Box<dyn FnOnce(T) -> R + Send>` |
| Mutable closure | `FnMut` |
| Higher-order function | Generic with `Fn` bound |

```rust
// Storing callbacks
pub struct EventBus {
    handlers: Vec<Box<dyn Fn(&Event) + Send + Sync>>,
}

impl EventBus {
    pub fn on<F>(&mut self, handler: F)
    where
        F: Fn(&Event) + Send + Sync + 'static,
    {
        self.handlers.push(Box::new(handler));
    }
}

// Higher-order function
pub fn retry<F, Fut, T, E>(max_retries: u32, f: F) -> impl Future<Output = Result<T, E>>
where
    F: Fn() -> Fut,
    Fut: Future<Output = Result<T, E>>,
    E: std::fmt::Debug,
{
    async move {
        let mut last_err = None;
        for attempt in 0..=max_retries {
            match f().await {
                Ok(val) => return Ok(val),
                Err(e) => {
                    tracing::warn!(attempt, error = ?e, "retrying");
                    last_err = Some(e);
                }
            }
        }
        Err(last_err.unwrap())
    }
}
```

## Crate Dependencies

```toml
[dependencies]
async-trait = "0.1"   # Only if dyn dispatch of async traits is needed
```
```

## Completeness Check

- [ ] Every interface/protocol/abstract class has a Rust trait, enum, or removal decision
- [ ] Every generic type has Rust generic equivalent with correct trait bounds
- [ ] Every union/discriminated union type has a Rust enum equivalent
- [ ] Dispatch strategy (static vs dynamic) is specified for every trait
- [ ] All implementors are listed for each trait
- [ ] Dependency injection patterns are mapped to constructor injection with `Arc<dyn Trait>`
- [ ] Closure/callback patterns are mapped to `Fn`/`FnMut`/`FnOnce` traits
- [ ] Higher-order functions use generic bounds on `Fn` traits
- [ ] `Send + Sync` bounds are added where cross-thread usage is needed
- [ ] Enum variants use `#[serde(tag = ...)]` where JSON compatibility is needed
- [ ] Summary table accounts for every source abstraction
