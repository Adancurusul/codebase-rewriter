# 10 - Ownership Model Mapping

**Output**: `.migration-plan/mappings/ownership-model.md`

## Purpose

Map the source language's memory management and data-sharing patterns to Rust's ownership, borrowing, and lifetime system. This is the most critical mapping because Rust's ownership model has no direct equivalent in garbage-collected or reference-counted languages. Every shared state pattern, global variable, reference cycle, and long-lived reference in the source must receive a concrete Rust ownership strategy.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- identifies all types, their mutability, and sharing patterns
- `architecture.md` -- identifies shared state, singletons, global caches, and cross-module data flow
- `async-model.md` -- identifies data shared across threads or async tasks

Extract every instance of:
- Global/module-level mutable state
- Shared references between objects (multiple owners)
- Reference cycles (parent-child, observer patterns)
- Long-lived references (caches, connection pools, registries)
- Data passed across thread/task boundaries
- Large data structures copied frequently

### Step 2: For each item, determine Rust equivalent

Apply this decision tree for EVERY shared-state pattern found:

```
Is this data shared between multiple owners?
  NO  -> Use owned data (T), pass by value or &/&mut borrow
  YES ->
    Is it mutable?
      NO  -> Use Arc<T> (thread-safe) or Rc<T> (single-thread)
      YES ->
        Is it accessed across threads?
          NO  -> Rc<RefCell<T>>
          YES ->
            Is contention expected to be low?
              YES -> Arc<Mutex<T>>
              NO  -> Arc<RwLock<T>> (many readers, few writers)
                     OR consider channels (mpsc/broadcast)
                     OR consider dashmap for concurrent maps

Does this form a reference cycle?
  YES -> Replace one direction with Weak<T> (Weak<Mutex<T>> for mutable)

Is this a global singleton?
  YES -> Use once_cell::sync::Lazy or std::sync::LazyLock (Rust 1.80+)

Is this a connection pool?
  YES -> Use Arc<Pool<T>> (e.g., deadpool, bb8, r2d2)

Is this configuration loaded once?
  YES -> Use Arc<Config> initialized at startup, passed via dependency injection
```

Common pattern translations:

| Source Pattern | Rust Equivalent |
|---------------|-----------------|
| Global mutable variable | `static INSTANCE: LazyLock<Mutex<T>>` |
| Singleton class | `LazyLock<T>` or pass as `&T` / `Arc<T>` |
| Shared config object | `Arc<Config>` passed to handlers |
| In-memory cache | `Arc<RwLock<HashMap<K, V>>>` or `Arc<DashMap<K, V>>` |
| Event emitter with listeners | `Vec<Box<dyn Fn(Event)>>` or channel-based |
| Parent-child reference cycle | Parent owns `Vec<Child>`, child holds `Weak<Parent>` |
| Database connection pool | `Arc<Pool>` (deadpool/bb8) |
| Thread-local storage | `thread_local!` macro |
| Shared mutable counter | `Arc<AtomicU64>` or `Arc<Mutex<u64>>` |
| Immutable shared data | `Arc<T>` or `&'static T` |

### Step 3: Produce mapping document

For EACH shared-state pattern found in the source, produce an entry with:
1. Source location and code snippet
2. What the pattern does (semantics)
3. Rust ownership strategy (with compilable code)
4. Rationale for the choice
5. Crate dependencies needed (if any)

## Template

```markdown
# Ownership Model Mapping

Source: {project_name}
Generated: {date}

## Decision Tree Applied

```text
Shared? -> Mutable? -> Threaded? -> Contention? -> Strategy
```

## Global State Inventory

### 1. {Pattern Name}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Pattern**: {Global variable / Singleton / Shared cache / ...}
**Semantics**: {What it does and why it's shared}

Source code:
```typescript
// Example: TypeScript global
let connectionPool: Pool;
let config: AppConfig;
```

Rust equivalent:
```rust
use std::sync::{Arc, LazyLock, Mutex};

// Connection pool: shared across threads, managed by pool crate
pub struct AppState {
    pub db: Arc<deadpool_postgres::Pool>,
    pub config: Arc<AppConfig>,
    pub cache: Arc<dashmap::DashMap<String, CachedItem>>,
}

// If truly global (discouraged, prefer dependency injection):
static CONFIG: LazyLock<AppConfig> = LazyLock::new(|| {
    AppConfig::from_env().expect("failed to load config")
});
```

**Rationale**: Connection pool is inherently shared and thread-safe internally; wrap in `Arc` for shared ownership across handler tasks. Config is immutable after load, so `Arc<AppConfig>` suffices without interior mutability.

**Crates**: `deadpool-postgres`, `dashmap`

---

### 2. {Pattern Name}

**Source**: [{file}:{line}](../src/{file}#L{line})
...

## Module Ownership Summary

| Module | Owned Data | Shared Data (`Arc`) | Interior Mutability | Notes |
|--------|-----------|---------------------|---------------------|-------|
| `api` | Request/Response types | `AppState` | None | Handlers receive `&AppState` |
| `cache` | None | `DashMap<K, V>` | `DashMap` (built-in) | Lock-free concurrent map |
| `db` | Query results | Connection pool | Pool-internal | Pool manages its own locks |
| `auth` | Token data | Session store | `RwLock<HashMap>` | Read-heavy, write-rare |

## Lifetime Annotations Needed

List any cases where lifetime annotations are required instead of owned data:

### {Case Name}
**Source**: [{file}:{line}](../src/{file}#L{line})
**Why lifetime needed**: {Data borrowed from a longer-lived scope, zero-copy parsing, etc.}

```rust
// Example: zero-copy JSON parsing
pub struct ParsedRequest<'a> {
    pub method: &'a str,
    pub path: &'a str,
    pub body: &'a [u8],
}

// Example: borrowing from app state
pub fn get_config_value<'a>(state: &'a AppState, key: &str) -> Option<&'a str> {
    state.config.get(key).map(|v| v.as_str())
}
```

## Reference Cycle Resolution

List any reference cycles detected and how to break them:

### {Cycle Name}
**Source**: [{files involved}]
**Cycle**: A -> B -> A

```rust
use std::sync::{Arc, Weak, Mutex};

pub struct Parent {
    pub children: Vec<Arc<Mutex<Child>>>,
}

pub struct Child {
    // Weak reference breaks the cycle
    pub parent: Weak<Mutex<Parent>>,
}

impl Child {
    pub fn get_parent(&self) -> Option<Arc<Mutex<Parent>>> {
        self.parent.upgrade()
    }
}
```

## Clone vs Borrow Strategy

| Type | Strategy | Rationale |
|------|----------|-----------|
| Small value types (< 64 bytes) | `Clone` + `Copy` if possible | Cheap to copy, avoids lifetime complexity |
| String identifiers | `Clone` or `Arc<str>` | Depends on frequency of sharing |
| Large data structures | `&T` borrow or `Arc<T>` | Avoid expensive copies |
| Data crossing async boundaries | `Arc<T>` or `.clone()` owned | Must be `'static` for `tokio::spawn` |
| Request-scoped data | Owned `T`, pass by `&T` within handler | Natural ownership, no sharing needed |
```

## Completeness Check

- [ ] Every global/module-level variable has a Rust ownership strategy
- [ ] Every singleton pattern has a `LazyLock` or dependency-injection alternative
- [ ] Every shared mutable state has `Arc<Mutex<T>>` or `Arc<RwLock<T>>` with rationale
- [ ] Every reference cycle is identified and resolved with `Weak<T>`
- [ ] Every cross-thread data transfer has `Send + Sync` compliance verified
- [ ] Every connection pool/cache has a concrete crate recommendation
- [ ] Lifetime annotations are specified for any borrowed (non-owned) data paths
- [ ] Module ownership summary table covers all modules
- [ ] Clone vs Borrow strategy table covers all major types
