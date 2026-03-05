# 22 - TypeScript Class Hierarchy to Rust Composition + Traits

**Output**: Contributes to `.migration-plan/mappings/type-mapping.md` (class/struct section)

## Purpose

Map every TypeScript class -- including inheritance chains, abstract classes, mixins, static methods, access modifiers, constructors, getters/setters, decorators, and `instanceof` checks -- to Rust structs, traits, impl blocks, and associated functions. TypeScript classes rely on prototype-based inheritance, which has no direct Rust equivalent. This guide converts inheritance hierarchies to Rust's composition-over-inheritance model using trait objects, enum dispatch, or struct embedding, choosing the most idiomatic pattern for each case.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- all class declarations, inheritance chains, abstract classes, mixins
- `architecture.md` -- class instantiation patterns, dependency injection, service layers
- `dependency-tree.md` -- third-party classes that are extended or implemented

Extract every instance of:
- Class declarations (concrete and abstract)
- Inheritance chains (`extends`)
- Interface implementations (`implements`)
- Mixins and multiple inheritance patterns
- Static methods and properties
- Access modifiers (`private`, `protected`, `public`, `readonly`)
- Constructor signatures and initialization logic
- Getter/setter properties
- Class decorators and method decorators
- `instanceof` runtime type checks
- `this` context usage (especially in callbacks and closures)
- Class expressions and anonymous classes
- Singleton classes

### Step 2: For each class, determine Rust equivalent

**Decision tree for class conversion:**

```
Is this class ever subclassed?
  NO ->
    Does it have only data (no methods or trivial methods)?
      YES -> Convert to struct with derive macros
      NO  -> Convert to struct + impl block
  YES ->
    Is the set of subclasses FIXED and KNOWN?
      YES -> Convert to enum with variants (preferred)
      NO  ->
        Is it an abstract class?
          YES -> Convert to trait (abstract methods) + default impls (concrete methods)
          NO  -> Convert to trait + base struct composition
```

**Core mapping table:**

| TypeScript Pattern | Rust Equivalent | When to Use |
|-------------------|-----------------|-------------|
| `class Foo { ... }` | `struct Foo { ... }` + `impl Foo { ... }` | No inheritance |
| `class Foo extends Bar` | Embed `Bar` in `Foo` + trait delegation | Open hierarchy |
| `class Foo extends Bar` (fixed set) | `enum FooKind { A(A), B(B) }` | Closed hierarchy |
| `abstract class Base` | `trait Base` with default methods | Abstract + concrete methods |
| `class Foo implements IFoo` | `impl IFoo for Foo` | Interface implementation |
| `class Foo extends Base implements IFoo, IBar` | `struct Foo` + `impl Trait for Foo` x N | Multiple traits |
| Mixin via `extends mix(A, B)` | Multiple trait impls | Composition |
| `static method()` | `fn method()` associated function (no `self`) | Class-level behavior |
| `private field` | Private field (no `pub`) | Module-private by default |
| `protected field` | `pub(crate) field` | Crate-visible |
| `public field` | `pub field` | Fully public |
| `readonly field` | Regular field (immutable by default via `&self`) | No special annotation |
| `constructor()` | `fn new() -> Self` associated function | Rust convention |
| `get prop()` / `set prop()` | `fn prop(&self) -> T` / `fn set_prop(&mut self, v: T)` | Explicit methods |
| `@decorator` | Trait impl or proc macro | See patterns guide (25) |
| `instanceof` | `match` on enum or trait downcasting | Prefer enum matching |
| `this` | `&self` / `&mut self` | Explicit receiver |

**Access modifier mapping:**

| TypeScript | Rust | Scope |
|-----------|------|-------|
| `public` (default) | `pub` | Visible everywhere |
| `private` | No `pub` prefix | Visible within the module only |
| `protected` | `pub(crate)` | Visible within the crate |
| `readonly` | Immutable by default | Take `&self` not `&mut self` |
| `#field` (private with `#`) | No `pub` prefix | Same as `private` |

### Step 3: Produce class mapping document

For EACH class in the source, produce:
1. Source class with file:line reference
2. Inheritance chain (parent, interfaces)
3. Rust equivalent (struct + traits)
4. Conversion rationale
5. All method signatures mapped

## Code Examples

### Example 1: Simple Class to Struct + Impl

**TypeScript:**
```typescript
class UserService {
  private readonly db: Database;
  private cache: Map<string, User>;

  constructor(db: Database) {
    this.db = db;
    this.cache = new Map();
  }

  async findById(id: string): Promise<User | null> {
    const cached = this.cache.get(id);
    if (cached) return cached;

    const user = await this.db.query("SELECT * FROM users WHERE id = $1", [id]);
    if (user) {
      this.cache.set(id, user);
    }
    return user;
  }

  async create(data: CreateUserInput): Promise<User> {
    const user = await this.db.insert("users", data);
    this.cache.set(user.id, user);
    return user;
  }

  clearCache(): void {
    this.cache.clear();
  }
}
```

**Rust:**
```rust
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;

pub struct UserService {
    db: Arc<PgPool>,
    cache: RwLock<HashMap<Uuid, User>>,
}

impl UserService {
    pub fn new(db: Arc<PgPool>) -> Self {
        Self {
            db,
            cache: RwLock::new(HashMap::new()),
        }
    }

    pub async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, DbError> {
        // Check cache first
        {
            let cache = self.cache.read().await;
            if let Some(user) = cache.get(&id) {
                return Ok(Some(user.clone()));
            }
        }

        // Query database
        let user = sqlx::query_as::<_, User>(
            "SELECT * FROM users WHERE id = $1"
        )
        .bind(id)
        .fetch_optional(&*self.db)
        .await
        .map_err(DbError::from)?;

        // Populate cache
        if let Some(ref user) = user {
            let mut cache = self.cache.write().await;
            cache.insert(id, user.clone());
        }

        Ok(user)
    }

    pub async fn create(&self, data: CreateUserInput) -> Result<User, DbError> {
        let user = sqlx::query_as::<_, User>(
            "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *"
        )
        .bind(&data.name)
        .bind(&data.email)
        .fetch_one(&*self.db)
        .await
        .map_err(DbError::from)?;

        let mut cache = self.cache.write().await;
        cache.insert(user.id, user.clone());

        Ok(user)
    }

    pub async fn clear_cache(&self) {
        let mut cache = self.cache.write().await;
        cache.clear();
    }
}
```

### Example 2: Abstract Class to Trait with Default Methods

**TypeScript:**
```typescript
abstract class BaseRepository<T extends BaseEntity> {
  protected db: Database;

  constructor(db: Database) {
    this.db = db;
  }

  // Abstract methods -- subclasses must implement
  abstract tableName(): string;
  abstract mapRow(row: any): T;

  // Concrete methods with shared logic
  async findById(id: string): Promise<T | null> {
    const row = await this.db.query(
      `SELECT * FROM ${this.tableName()} WHERE id = $1`, [id]
    );
    return row ? this.mapRow(row) : null;
  }

  async findAll(): Promise<T[]> {
    const rows = await this.db.query(`SELECT * FROM ${this.tableName()}`);
    return rows.map(row => this.mapRow(row));
  }

  async deleteById(id: string): Promise<void> {
    await this.db.query(
      `DELETE FROM ${this.tableName()} WHERE id = $1`, [id]
    );
  }
}

class UserRepository extends BaseRepository<User> {
  tableName(): string { return "users"; }
  mapRow(row: any): User {
    return { id: row.id, name: row.name, email: row.email };
  }
}

class OrderRepository extends BaseRepository<Order> {
  tableName(): string { return "orders"; }
  mapRow(row: any): Order {
    return { id: row.id, userId: row.user_id, total: row.total };
  }
}
```

**Rust:**
```rust
use async_trait::async_trait;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

// Abstract class -> trait with default methods
#[async_trait]
pub trait BaseRepository: Send + Sync {
    type Entity: for<'r> FromRow<'r, sqlx::postgres::PgRow> + Send + Sync + Unpin;

    fn table_name(&self) -> &'static str;
    fn pool(&self) -> &PgPool;

    // Default implementations (concrete methods from the abstract class)
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Self::Entity>, DbError> {
        let query = format!("SELECT * FROM {} WHERE id = $1", self.table_name());
        sqlx::query_as::<_, Self::Entity>(&query)
            .bind(id)
            .fetch_optional(self.pool())
            .await
            .map_err(DbError::from)
    }

    async fn find_all(&self) -> Result<Vec<Self::Entity>, DbError> {
        let query = format!("SELECT * FROM {}", self.table_name());
        sqlx::query_as::<_, Self::Entity>(&query)
            .fetch_all(self.pool())
            .await
            .map_err(DbError::from)
    }

    async fn delete_by_id(&self, id: Uuid) -> Result<(), DbError> {
        let query = format!("DELETE FROM {} WHERE id = $1", self.table_name());
        sqlx::query(&query)
            .bind(id)
            .execute(self.pool())
            .await
            .map_err(DbError::from)?;
        Ok(())
    }
}

// Concrete subclass -> struct that implements the trait
pub struct UserRepository {
    pool: PgPool,
}

impl UserRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl BaseRepository for UserRepository {
    type Entity = User;

    fn table_name(&self) -> &'static str { "users" }
    fn pool(&self) -> &PgPool { &self.pool }
}

pub struct OrderRepository {
    pool: PgPool,
}

impl OrderRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl BaseRepository for OrderRepository {
    type Entity = Order;

    fn table_name(&self) -> &'static str { "orders" }
    fn pool(&self) -> &PgPool { &self.pool }
}
```

### Example 3: Multi-Level Inheritance Chain

**TypeScript:**
```typescript
class Animal {
  name: string;
  constructor(name: string) {
    this.name = name;
  }
  speak(): string {
    return `${this.name} makes a sound`;
  }
}

class Dog extends Animal {
  breed: string;
  constructor(name: string, breed: string) {
    super(name);
    this.breed = breed;
  }
  speak(): string {
    return `${this.name} barks`;
  }
  fetch(item: string): string {
    return `${this.name} fetches ${item}`;
  }
}

class ServiceDog extends Dog {
  handler: string;
  constructor(name: string, breed: string, handler: string) {
    super(name, breed);
    this.handler = handler;
  }
  speak(): string {
    return `${this.name} is quiet (working)`;
  }
  assist(): string {
    return `${this.name} assists ${this.handler}`;
  }
}

// Usage with instanceof
function describeAnimal(animal: Animal): string {
  if (animal instanceof ServiceDog) {
    return `Service dog: ${animal.assist()}`;
  } else if (animal instanceof Dog) {
    return `Dog: ${animal.fetch("ball")}`;
  } else {
    return animal.speak();
  }
}
```

**Rust (Enum approach -- preferred for fixed hierarchy):**
```rust
#[derive(Debug, Clone)]
pub enum Animal {
    Generic { name: String },
    Dog { name: String, breed: String },
    ServiceDog { name: String, breed: String, handler: String },
}

impl Animal {
    pub fn name(&self) -> &str {
        match self {
            Animal::Generic { name } => name,
            Animal::Dog { name, .. } => name,
            Animal::ServiceDog { name, .. } => name,
        }
    }

    pub fn speak(&self) -> String {
        match self {
            Animal::Generic { name } => format!("{name} makes a sound"),
            Animal::Dog { name, .. } => format!("{name} barks"),
            Animal::ServiceDog { name, .. } => format!("{name} is quiet (working)"),
        }
    }

    pub fn fetch(&self, item: &str) -> Option<String> {
        match self {
            Animal::Dog { name, .. } | Animal::ServiceDog { name, .. } => {
                Some(format!("{name} fetches {item}"))
            }
            _ => None,
        }
    }

    pub fn assist(&self) -> Option<String> {
        match self {
            Animal::ServiceDog { name, handler, .. } => {
                Some(format!("{name} assists {handler}"))
            }
            _ => None,
        }
    }
}

// instanceof -> match
fn describe_animal(animal: &Animal) -> String {
    match animal {
        Animal::ServiceDog { .. } => {
            format!("Service dog: {}", animal.assist().unwrap())
        }
        Animal::Dog { .. } => {
            format!("Dog: {}", animal.fetch("ball").unwrap())
        }
        Animal::Generic { .. } => {
            animal.speak()
        }
    }
}
```

**Rust (Trait approach -- for open/extensible hierarchy):**
```rust
pub trait Animal: Send + Sync {
    fn name(&self) -> &str;
    fn speak(&self) -> String {
        format!("{} makes a sound", self.name())
    }
}

pub trait Fetchable: Animal {
    fn fetch(&self, item: &str) -> String {
        format!("{} fetches {item}", self.name())
    }
}

pub trait Assistable: Animal {
    fn handler(&self) -> &str;
    fn assist(&self) -> String {
        format!("{} assists {}", self.name(), self.handler())
    }
}

#[derive(Debug, Clone)]
pub struct GenericAnimal {
    pub name: String,
}

impl Animal for GenericAnimal {
    fn name(&self) -> &str { &self.name }
}

#[derive(Debug, Clone)]
pub struct Dog {
    pub name: String,
    pub breed: String,
}

impl Animal for Dog {
    fn name(&self) -> &str { &self.name }
    fn speak(&self) -> String { format!("{} barks", self.name) }
}

impl Fetchable for Dog {}

#[derive(Debug, Clone)]
pub struct ServiceDog {
    pub name: String,
    pub breed: String,
    pub handler: String,
}

impl Animal for ServiceDog {
    fn name(&self) -> &str { &self.name }
    fn speak(&self) -> String { format!("{} is quiet (working)", self.name) }
}

impl Fetchable for ServiceDog {}
impl Assistable for ServiceDog {
    fn handler(&self) -> &str { &self.handler }
}
```

### Example 4: Getters/Setters to Methods

**TypeScript:**
```typescript
class Temperature {
  private _celsius: number;

  constructor(celsius: number) {
    this._celsius = celsius;
  }

  get celsius(): number {
    return this._celsius;
  }

  set celsius(value: number) {
    if (value < -273.15) {
      throw new Error("Temperature below absolute zero");
    }
    this._celsius = value;
  }

  get fahrenheit(): number {
    return this._celsius * 9 / 5 + 32;
  }

  set fahrenheit(value: number) {
    this.celsius = (value - 32) * 5 / 9;
  }

  get kelvin(): number {
    return this._celsius + 273.15;
  }
}
```

**Rust:**
```rust
#[derive(Debug, Clone, Copy)]
pub struct Temperature {
    celsius: f64,
}

impl Temperature {
    pub fn new(celsius: f64) -> Result<Self, ValidationError> {
        if celsius < -273.15 {
            return Err(ValidationError::OutOfRange {
                field: "celsius".into(),
                message: "temperature below absolute zero".into(),
            });
        }
        Ok(Self { celsius })
    }

    pub fn from_fahrenheit(fahrenheit: f64) -> Result<Self, ValidationError> {
        let celsius = (fahrenheit - 32.0) * 5.0 / 9.0;
        Self::new(celsius)
    }

    // Getter -- takes &self, returns value
    pub fn celsius(&self) -> f64 {
        self.celsius
    }

    // Setter -- takes &mut self, returns Result for validation
    pub fn set_celsius(&mut self, value: f64) -> Result<(), ValidationError> {
        if value < -273.15 {
            return Err(ValidationError::OutOfRange {
                field: "celsius".into(),
                message: "temperature below absolute zero".into(),
            });
        }
        self.celsius = value;
        Ok(())
    }

    // Computed getter -- derived from internal state
    pub fn fahrenheit(&self) -> f64 {
        self.celsius * 9.0 / 5.0 + 32.0
    }

    pub fn set_fahrenheit(&mut self, value: f64) -> Result<(), ValidationError> {
        let celsius = (value - 32.0) * 5.0 / 9.0;
        self.set_celsius(celsius)
    }

    pub fn kelvin(&self) -> f64 {
        self.celsius + 273.15
    }
}
```

### Example 5: Static Methods to Associated Functions

**TypeScript:**
```typescript
class DateUtils {
  static isWeekend(date: Date): boolean {
    const day = date.getDay();
    return day === 0 || day === 6;
  }

  static addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  static formatISO(date: Date): string {
    return date.toISOString();
  }

  static parse(dateStr: string): Date {
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) {
      throw new Error(`Invalid date string: ${dateStr}`);
    }
    return date;
  }
}

// Usage
const isWeekend = DateUtils.isWeekend(new Date());
const nextWeek = DateUtils.addDays(new Date(), 7);
```

**Rust:**
```rust
use chrono::{DateTime, Datelike, Duration, NaiveDate, Utc, Weekday};

// Static-only class -> module with free functions, or struct with associated functions
// Prefer a module if there is no state:

pub mod date_utils {
    use super::*;

    pub fn is_weekend(date: &DateTime<Utc>) -> bool {
        matches!(date.weekday(), Weekday::Sat | Weekday::Sun)
    }

    pub fn add_days(date: DateTime<Utc>, days: i64) -> DateTime<Utc> {
        date + Duration::days(days)
    }

    pub fn format_iso(date: &DateTime<Utc>) -> String {
        date.to_rfc3339()
    }

    pub fn parse(date_str: &str) -> Result<DateTime<Utc>, chrono::ParseError> {
        date_str.parse::<DateTime<Utc>>()
    }
}

// Usage:
// let is_weekend = date_utils::is_weekend(&Utc::now());
// let next_week = date_utils::add_days(Utc::now(), 7);
```

### Example 6: Interface Implementation (implements)

**TypeScript:**
```typescript
interface Serializable {
  serialize(): string;
  deserialize(data: string): void;
}

interface Cacheable {
  cacheKey(): string;
  ttl(): number;
}

interface Loggable {
  toLogString(): string;
}

class Product implements Serializable, Cacheable, Loggable {
  id: string;
  name: string;
  price: number;

  constructor(id: string, name: string, price: number) {
    this.id = id;
    this.name = name;
    this.price = price;
  }

  serialize(): string {
    return JSON.stringify({ id: this.id, name: this.name, price: this.price });
  }

  deserialize(data: string): void {
    const parsed = JSON.parse(data);
    this.id = parsed.id;
    this.name = parsed.name;
    this.price = parsed.price;
  }

  cacheKey(): string {
    return `product:${this.id}`;
  }

  ttl(): number {
    return 3600;
  }

  toLogString(): string {
    return `Product(${this.id}, ${this.name}, $${this.price})`;
  }
}
```

**Rust:**
```rust
use serde::{Deserialize, Serialize};
use std::fmt;

// interface -> trait
pub trait Cacheable {
    fn cache_key(&self) -> String;
    fn ttl(&self) -> u64;
}

pub trait Loggable {
    fn to_log_string(&self) -> String;
}

// Serializable interface -> use serde derive (Rust idiomatic)
// No need for a custom Serializable trait

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Product {
    pub id: String,
    pub name: String,
    pub price: f64,
}

impl Product {
    pub fn new(id: String, name: String, price: f64) -> Self {
        Self { id, name, price }
    }

    // serialize/deserialize handled by serde:
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    pub fn from_json(data: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(data)
    }
}

impl Cacheable for Product {
    fn cache_key(&self) -> String {
        format!("product:{}", self.id)
    }

    fn ttl(&self) -> u64 {
        3600
    }
}

impl Loggable for Product {
    fn to_log_string(&self) -> String {
        format!("Product({}, {}, ${:.2})", self.id, self.name, self.price)
    }
}

// Also implement Display for general formatting
impl fmt::Display for Product {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Product({}, {}, ${:.2})", self.id, self.name, self.price)
    }
}
```

### Example 7: Singleton Class to LazyLock or Passed State

**TypeScript:**
```typescript
class ConfigManager {
  private static instance: ConfigManager;
  private config: Map<string, string>;

  private constructor() {
    this.config = new Map();
  }

  static getInstance(): ConfigManager {
    if (!ConfigManager.instance) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  get(key: string): string | undefined {
    return this.config.get(key);
  }

  set(key: string, value: string): void {
    this.config.set(key, value);
  }

  loadFromEnv(): void {
    this.config.set("PORT", process.env.PORT ?? "3000");
    this.config.set("DB_URL", process.env.DB_URL ?? "");
  }
}

// Usage
const config = ConfigManager.getInstance();
config.loadFromEnv();
const port = config.get("PORT");
```

**Rust (Preferred: dependency injection, no global state):**
```rust
use std::collections::HashMap;

pub struct ConfigManager {
    config: HashMap<String, String>,
}

impl ConfigManager {
    pub fn from_env() -> Result<Self, AppError> {
        let mut config = HashMap::new();
        config.insert(
            "PORT".into(),
            std::env::var("PORT").unwrap_or_else(|_| "3000".into()),
        );
        config.insert(
            "DB_URL".into(),
            std::env::var("DB_URL").unwrap_or_default(),
        );
        Ok(Self { config })
    }

    pub fn get(&self, key: &str) -> Option<&str> {
        self.config.get(key).map(|v| v.as_str())
    }
}

// In main.rs: create once, pass via Arc
// let config = Arc::new(ConfigManager::from_env()?);
// pass config into AppState
```

**Rust (Alternative: true global if absolutely needed):**
```rust
use std::sync::{LazyLock, RwLock};
use std::collections::HashMap;

static CONFIG: LazyLock<RwLock<HashMap<String, String>>> = LazyLock::new(|| {
    let mut map = HashMap::new();
    map.insert(
        "PORT".into(),
        std::env::var("PORT").unwrap_or_else(|_| "3000".into()),
    );
    map.insert(
        "DB_URL".into(),
        std::env::var("DB_URL").unwrap_or_default(),
    );
    RwLock::new(map)
});

// Usage (discouraged -- prefer dependency injection):
// let port = CONFIG.read().unwrap().get("PORT").cloned();
```

### Example 8: this Context and Closures

**TypeScript:**
```typescript
class EventProcessor {
  private handlers: Map<string, ((event: Event) => void)[]>;

  constructor() {
    this.handlers = new Map();
  }

  on(eventName: string, handler: (event: Event) => void): void {
    const handlers = this.handlers.get(eventName) ?? [];
    handlers.push(handler);
    this.handlers.set(eventName, handlers);
  }

  emit(eventName: string, event: Event): void {
    const handlers = this.handlers.get(eventName) ?? [];
    handlers.forEach(handler => handler(event));
  }

  // Problem: `this` context can be lost in callbacks
  startListening(): void {
    // Arrow function preserves `this`
    setInterval(() => {
      this.emit("tick", { type: "tick", timestamp: Date.now() });
    }, 1000);
  }
}

class Logger {
  prefix: string;

  constructor(prefix: string) {
    this.prefix = prefix;
    // Bind ensures `this` is correct when method is passed as callback
    this.log = this.log.bind(this);
  }

  log(message: string): void {
    console.log(`[${this.prefix}] ${message}`);
  }
}
```

**Rust:**
```rust
use std::collections::HashMap;

pub struct Event {
    pub event_type: String,
    pub timestamp: u64,
}

pub struct EventProcessor {
    // Box<dyn Fn> replaces callback function type
    handlers: HashMap<String, Vec<Box<dyn Fn(&Event) + Send + Sync>>>,
}

impl EventProcessor {
    pub fn new() -> Self {
        Self {
            handlers: HashMap::new(),
        }
    }

    pub fn on<F>(&mut self, event_name: &str, handler: F)
    where
        F: Fn(&Event) + Send + Sync + 'static,
    {
        self.handlers
            .entry(event_name.to_string())
            .or_default()
            .push(Box::new(handler));
    }

    pub fn emit(&self, event_name: &str, event: &Event) {
        if let Some(handlers) = self.handlers.get(event_name) {
            for handler in handlers {
                handler(event);
            }
        }
    }
}

// No `this` binding issues in Rust -- closures capture by value or reference explicitly
// `self` is always explicit, never implicit

pub struct Logger {
    prefix: String,
}

impl Logger {
    pub fn new(prefix: impl Into<String>) -> Self {
        Self { prefix: prefix.into() }
    }

    pub fn log(&self, message: &str) {
        println!("[{}] {message}", self.prefix);
    }

    // To use as a callback, clone the data into a closure
    pub fn as_callback(&self) -> impl Fn(&str) + Send + Sync + 'static {
        let prefix = self.prefix.clone();
        move |message: &str| {
            println!("[{prefix}] {message}");
        }
    }
}

// Usage:
// let logger = Logger::new("APP");
// let callback = logger.as_callback();
// some_system.on_message(callback);
```

## Template

```markdown
# Class Hierarchy Mapping

Source: {project_name}
Generated: {date}

## Summary

| Category | Count | Rust Strategy |
|----------|-------|---------------|
| Concrete classes (no inheritance) | {count} | struct + impl |
| Abstract classes | {count} | trait + default methods |
| Subclasses (open hierarchy) | {count} | trait impls |
| Subclasses (closed hierarchy) | {count} | enum variants |
| Singleton classes | {count} | `LazyLock` or DI |
| Static-only utility classes | {count} | Module with free functions |
| Mixin patterns | {count} | Multiple trait impls |

## Inheritance Chains

### Chain: {Root Class}

```text
{Root}
  |- {Child A}
  |    |- {Grandchild A1}
  |- {Child B}
```

**Strategy**: {Enum (closed) / Trait (open)}
**Rationale**: {Why this strategy was chosen}

## Class Mapping Table

| # | TypeScript Class | File | Rust Type | Strategy | Traits Implemented |
|---|-----------------|------|-----------|----------|-------------------|
| 1 | `UserService` | [{file}:{line}] | `struct UserService` | struct + impl | None |
| 2 | `BaseRepository<T>` | [{file}:{line}] | `trait BaseRepository` | trait + defaults | - |
| 3 | `UserRepository` | [{file}:{line}] | `struct UserRepository` | trait impl | `BaseRepository` |
| 4 | `Animal` | [{file}:{line}] | `enum Animal` | enum dispatch | - |
| ... | ... | ... | ... | ... | ... |

## Constructor Mapping

| TypeScript Constructor | Rust `new()` Function | Dependencies |
|-----------------------|----------------------|-------------|
| `new UserService(db)` | `UserService::new(db: Arc<PgPool>)` | `PgPool` |
| `new Logger(prefix)` | `Logger::new(prefix: impl Into<String>)` | None |
| ... | ... | ... |

## Access Modifier Mapping

| Class.Field | TypeScript | Rust | Notes |
|------------|-----------|------|-------|
| `UserService.db` | `private readonly` | `db: Arc<PgPool>` (no pub) | Module-private, immutable via &self |
| `User.name` | `public` | `pub name: String` | Public |
| `Base.config` | `protected` | `pub(crate) config: Config` | Crate-visible |
| ... | ... | ... | ... |

## Static Method Mapping

| TypeScript Static | Rust Equivalent | Location |
|------------------|-----------------|----------|
| `DateUtils.isWeekend()` | `date_utils::is_weekend()` | Module function |
| `User.fromJson()` | `User::from_json()` | Associated function |
| `Config.getInstance()` | DI via `Arc<Config>` | Removed singleton |
| ... | ... | ... |

## instanceof Replacement Table

| TypeScript instanceof | Rust Equivalent | Pattern |
|----------------------|-----------------|---------|
| `x instanceof Dog` | `matches!(x, Animal::Dog { .. })` | Enum matching |
| `x instanceof Error` | `x.downcast_ref::<CustomError>()` | Trait downcast (avoid) |
| ... | ... | ... |

## Crate Dependencies

```toml
[dependencies]
async-trait = "0.1"   # For async methods in traits
```
```

## Completeness Check

- [ ] Every class declaration has a Rust struct or trait equivalent
- [ ] Every inheritance chain is mapped to either enum or trait composition
- [ ] Every abstract class is converted to a trait with default methods
- [ ] Every interface implementation (`implements`) has a `impl Trait for Struct`
- [ ] Every constructor is mapped to a `new()` associated function
- [ ] Every static method is mapped to an associated function or module function
- [ ] Every getter/setter is mapped to explicit methods
- [ ] Every access modifier (`private`/`protected`/`public`/`readonly`) is mapped
- [ ] Every `instanceof` check is replaced with `match` or enum pattern
- [ ] Every singleton is either removed (use DI) or converted to `LazyLock`
- [ ] Every mixin pattern is converted to multiple trait implementations
- [ ] `this` binding issues are resolved with explicit closure captures
- [ ] Callback methods are converted to closure-returning methods where needed
- [ ] Decorator patterns are noted for migration (see guide 25)
