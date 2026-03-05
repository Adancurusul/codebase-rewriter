# 32 - Python Class Hierarchy to Rust Composition + Traits

**Output**: `.migration-plan/mappings/class-hierarchy.md`

## Purpose

Map every Python class, inheritance hierarchy, mixin, magic method, property, and metaclass to Rust structs, traits, impl blocks, and derive macros. Python relies heavily on class inheritance, duck typing, and dunder methods for behavior customization. Rust has no inheritance -- it uses composition, traits, and explicit implementations. Every class relationship and magic method in the source must receive a concrete Rust design that preserves the original semantics.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- all classes, their inheritance chains, methods, and properties
- `architecture.md` -- class relationships, dependency patterns, plugin/extension points
- `dependency-tree.md` -- identifies frameworks that define base classes (Django models, Flask views, etc.)

Extract every instance of:
- Class definitions with `__init__`
- Single inheritance chains (class B(A))
- Multiple inheritance (class C(A, B))
- Mixin classes (class LoggingMixin)
- Abstract base classes (ABC with @abstractmethod)
- Magic/dunder methods (`__repr__`, `__str__`, `__eq__`, `__hash__`, `__iter__`, `__len__`, `__getitem__`, `__call__`, `__enter__`/`__exit__`, `__add__`, etc.)
- `@property` / `@name.setter` decorators
- `@staticmethod` / `@classmethod` decorators
- `super()` calls
- Metaclasses (`class Meta` or `metaclass=`)
- `__slots__` definitions
- Descriptor protocol (`__get__`, `__set__`, `__delete__`)
- Class variables vs instance variables
- `__post_init__` (dataclass hook)

### Step 2: For each class pattern, determine Rust equivalent

**Class-to-struct decision tree:**

```
Is this class a pure data container (dataclass/TypedDict/NamedTuple)?
  YES -> See 30-py-types-to-rust.md

Does this class have subclasses?
  YES ->
    Is the set of subclasses fixed and known?
      YES -> Use enum with per-variant data
      NO  -> Use trait + struct composition
  NO -> Use plain struct + impl

Does this class use multiple inheritance or mixins?
  YES -> Each mixin becomes a separate trait

Does this class use __init__ with complex logic?
  YES -> impl new() constructor with builder pattern if many optional params

Does this class use magic methods?
  YES -> Map each dunder to the corresponding Rust trait (see table below)
```

**Dunder method to Rust trait mapping:**

| Python Dunder | Rust Trait | Notes |
|--------------|-----------|-------|
| `__repr__` | `Debug` | `#[derive(Debug)]` or manual `impl fmt::Debug` |
| `__str__` | `Display` | Manual `impl fmt::Display` |
| `__eq__` | `PartialEq` | `#[derive(PartialEq)]` or manual impl |
| `__ne__` | Provided by `PartialEq` | Automatic in Rust |
| `__lt__`, `__le__`, `__gt__`, `__ge__` | `PartialOrd` / `Ord` | `#[derive(PartialOrd, Ord)]` or manual |
| `__hash__` | `Hash` | `#[derive(Hash)]` -- requires `Eq` |
| `__bool__` | No direct equivalent | Use explicit method: `fn is_empty(&self) -> bool` |
| `__len__` | No `Len` trait | Use method: `fn len(&self) -> usize` + `fn is_empty(&self) -> bool` |
| `__iter__` | `IntoIterator` | `impl IntoIterator for &MyType` |
| `__next__` | `Iterator` | `impl Iterator for MyIterator` with `type Item` |
| `__getitem__` | `Index` | `impl std::ops::Index<usize> for MyType` |
| `__setitem__` | `IndexMut` | `impl std::ops::IndexMut<usize> for MyType` |
| `__contains__` | No direct trait | Method: `fn contains(&self, item: &T) -> bool` |
| `__add__` | `Add` | `impl std::ops::Add for MyType` |
| `__sub__` | `Sub` | `impl std::ops::Sub for MyType` |
| `__mul__` | `Mul` | `impl std::ops::Mul for MyType` |
| `__call__` | `Fn` / `FnMut` / `FnOnce` | Rarely impl directly; use closure or method |
| `__enter__` / `__exit__` | `Drop` + RAII | Resource cleanup via Drop; see Example 6 |
| `__del__` | `Drop` | `impl Drop for MyType` |
| `__getattr__` | No equivalent | Use explicit methods; no runtime attribute lookup |
| `__setattr__` | No equivalent | Use explicit setter methods |
| `__init_subclass__` | No equivalent | Use proc macros or trait requirements |
| `__class_getitem__` | Generics | `struct MyType<T>` |

**Inheritance to composition mapping:**

| Python Pattern | Rust Equivalent |
|---------------|-----------------|
| `class B(A)` | `struct B { base: A }` + delegate methods, or trait |
| `class C(A, B)` | `struct C` implements `trait A` + `trait B` |
| `class M(MixinA, MixinB, Base)` | `struct M` implements all traits from mixins |
| `super().__init__()` | `Self { base: Base::new(), ... }` |
| `super().method()` | Trait default method or explicit delegation |
| `isinstance(x, T)` | `match` on enum, or `downcast_ref::<T>()` on `dyn Any` |

### Step 3: Produce class hierarchy mapping document

For EACH class found in the source, produce:
1. Source class with file:line reference and full method list
2. Rust struct/trait/enum with compilable code
3. All trait implementations mapped from dunder methods
4. Inheritance resolution strategy

## Code Examples

### Example 1: Simple class to struct + impl

Python:
```python
class BankAccount:
    def __init__(self, owner: str, balance: float = 0.0):
        self.owner = owner
        self.balance = balance
        self._transactions: list[float] = []

    def deposit(self, amount: float) -> None:
        if amount <= 0:
            raise ValueError("Deposit amount must be positive")
        self.balance += amount
        self._transactions.append(amount)

    def withdraw(self, amount: float) -> None:
        if amount > self.balance:
            raise ValueError("Insufficient funds")
        self.balance -= amount
        self._transactions.append(-amount)

    def __repr__(self) -> str:
        return f"BankAccount(owner={self.owner!r}, balance={self.balance:.2f})"

    def __str__(self) -> str:
        return f"{self.owner}'s account: ${self.balance:.2f}"
```

Rust:
```rust
use std::fmt;

#[derive(Debug, Clone)]
pub struct BankAccount {
    owner: String,
    balance: f64,
    transactions: Vec<f64>,
}

impl BankAccount {
    pub fn new(owner: String, balance: f64) -> Self {
        Self {
            owner,
            balance,
            transactions: Vec::new(),
        }
    }

    pub fn owner(&self) -> &str {
        &self.owner
    }

    pub fn balance(&self) -> f64 {
        self.balance
    }

    pub fn deposit(&mut self, amount: f64) -> Result<(), AccountError> {
        if amount <= 0.0 {
            return Err(AccountError::InvalidAmount(
                "deposit amount must be positive".into(),
            ));
        }
        self.balance += amount;
        self.transactions.push(amount);
        Ok(())
    }

    pub fn withdraw(&mut self, amount: f64) -> Result<(), AccountError> {
        if amount > self.balance {
            return Err(AccountError::InsufficientFunds);
        }
        self.balance -= amount;
        self.transactions.push(-amount);
        Ok(())
    }
}

// __repr__ -> Debug (already derived)

// __str__ -> Display
impl fmt::Display for BankAccount {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}'s account: ${:.2}", self.owner, self.balance)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum AccountError {
    #[error("insufficient funds")]
    InsufficientFunds,

    #[error("invalid amount: {0}")]
    InvalidAmount(String),
}
```

### Example 2: Single inheritance to composition

Python:
```python
class Animal:
    def __init__(self, name: str, age: int):
        self.name = name
        self.age = age

    def speak(self) -> str:
        return "..."

    def describe(self) -> str:
        return f"{self.name}, age {self.age}"

class Dog(Animal):
    def __init__(self, name: str, age: int, breed: str):
        super().__init__(name, age)
        self.breed = breed

    def speak(self) -> str:
        return "Woof!"

    def fetch(self, item: str) -> str:
        return f"{self.name} fetches the {item}"

class Cat(Animal):
    def __init__(self, name: str, age: int, indoor: bool = True):
        super().__init__(name, age)
        self.indoor = indoor

    def speak(self) -> str:
        return "Meow!"
```

Rust (enum approach -- fixed set of animal types):
```rust
#[derive(Debug, Clone)]
pub enum Animal {
    Dog {
        name: String,
        age: u32,
        breed: String,
    },
    Cat {
        name: String,
        age: u32,
        indoor: bool,
    },
}

impl Animal {
    pub fn name(&self) -> &str {
        match self {
            Animal::Dog { name, .. } => name,
            Animal::Cat { name, .. } => name,
        }
    }

    pub fn age(&self) -> u32 {
        match self {
            Animal::Dog { age, .. } => *age,
            Animal::Cat { age, .. } => *age,
        }
    }

    pub fn speak(&self) -> &'static str {
        match self {
            Animal::Dog { .. } => "Woof!",
            Animal::Cat { .. } => "Meow!",
        }
    }

    pub fn describe(&self) -> String {
        format!("{}, age {}", self.name(), self.age())
    }
}

impl Animal {
    /// Dog-specific method -- returns None for non-Dog variants.
    pub fn fetch(&self, item: &str) -> Option<String> {
        match self {
            Animal::Dog { name, .. } => Some(format!("{name} fetches the {item}")),
            _ => None,
        }
    }
}
```

Rust (trait approach -- open-ended, extensible):
```rust
pub trait Animal: std::fmt::Debug {
    fn name(&self) -> &str;
    fn age(&self) -> u32;
    fn speak(&self) -> &str;

    fn describe(&self) -> String {
        format!("{}, age {}", self.name(), self.age())
    }
}

#[derive(Debug, Clone)]
pub struct Dog {
    pub name: String,
    pub age: u32,
    pub breed: String,
}

impl Animal for Dog {
    fn name(&self) -> &str { &self.name }
    fn age(&self) -> u32 { self.age }
    fn speak(&self) -> &str { "Woof!" }
}

impl Dog {
    pub fn fetch(&self, item: &str) -> String {
        format!("{} fetches the {item}", self.name)
    }
}

#[derive(Debug, Clone)]
pub struct Cat {
    pub name: String,
    pub age: u32,
    pub indoor: bool,
}

impl Animal for Cat {
    fn name(&self) -> &str { &self.name }
    fn age(&self) -> u32 { self.age }
    fn speak(&self) -> &str { "Meow!" }
}
```

### Example 3: Multiple inheritance / Mixins to traits

Python:
```python
class JsonMixin:
    def to_json(self) -> str:
        import json
        return json.dumps(self.__dict__)

class LoggingMixin:
    def log(self, message: str) -> None:
        print(f"[{self.__class__.__name__}] {message}")

class TimestampMixin:
    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)

    @property
    def created_at_iso(self) -> str:
        return self.created_at.isoformat()

class Order(JsonMixin, LoggingMixin, TimestampMixin):
    def __init__(self, order_id: str, total: float):
        self.order_id = order_id
        self.total = total
        self.created_at = datetime.utcnow()

    def process(self) -> None:
        self.log(f"Processing order {self.order_id}")
        # ...
```

Rust:
```rust
use chrono::{DateTime, Utc};
use serde::Serialize;

// JsonMixin -> trait with serde
pub trait ToJson: Serialize {
    fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }
}

// LoggingMixin -> trait using tracing (no inheritance needed)
pub trait Loggable {
    fn type_name(&self) -> &'static str;

    fn log(&self, message: &str) {
        tracing::info!(component = self.type_name(), "{message}");
    }
}

// TimestampMixin -> trait for types with a created_at field
pub trait Timestamped {
    fn created_at(&self) -> DateTime<Utc>;

    fn created_at_iso(&self) -> String {
        self.created_at().to_rfc3339()
    }
}

// Order implements all three traits (composition replaces MRO)
#[derive(Debug, Clone, Serialize)]
pub struct Order {
    pub order_id: String,
    pub total: f64,
    pub created_at: DateTime<Utc>,
}

impl Order {
    pub fn new(order_id: String, total: f64) -> Self {
        Self {
            order_id,
            total,
            created_at: Utc::now(),
        }
    }

    pub fn process(&self) {
        self.log(&format!("Processing order {}", self.order_id));
        // ...
    }
}

impl ToJson for Order {}  // Blanket implementation from Serialize

impl Loggable for Order {
    fn type_name(&self) -> &'static str { "Order" }
}

impl Timestamped for Order {
    fn created_at(&self) -> DateTime<Utc> { self.created_at }
}
```

### Example 4: __eq__, __hash__, __lt__ to derive macros

Python:
```python
class Version:
    def __init__(self, major: int, minor: int, patch: int):
        self.major = major
        self.minor = minor
        self.patch = patch

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Version):
            return NotImplemented
        return (self.major, self.minor, self.patch) == (other.major, other.minor, other.patch)

    def __hash__(self) -> int:
        return hash((self.major, self.minor, self.patch))

    def __lt__(self, other: "Version") -> bool:
        return (self.major, self.minor, self.patch) < (other.major, other.minor, other.patch)

    def __le__(self, other: "Version") -> bool:
        return self == other or self < other

    def __repr__(self) -> str:
        return f"Version({self.major}.{self.minor}.{self.patch})"
```

Rust:
```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Version {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
}

impl Version {
    pub fn new(major: u32, minor: u32, patch: u32) -> Self {
        Self { major, minor, patch }
    }
}

impl std::fmt::Display for Version {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}.{}.{}", self.major, self.minor, self.patch)
    }
}
```

### Example 5: __iter__ / __next__ to Iterator trait

Python:
```python
class Paginator:
    def __init__(self, items: list, page_size: int = 10):
        self.items = items
        self.page_size = page_size
        self._index = 0

    def __iter__(self):
        self._index = 0
        return self

    def __next__(self) -> list:
        if self._index >= len(self.items):
            raise StopIteration
        page = self.items[self._index:self._index + self.page_size]
        self._index += self.page_size
        return page

    def __len__(self) -> int:
        return (len(self.items) + self.page_size - 1) // self.page_size
```

Rust:
```rust
pub struct Paginator<T> {
    items: Vec<T>,
    page_size: usize,
}

impl<T: Clone> Paginator<T> {
    pub fn new(items: Vec<T>, page_size: usize) -> Self {
        Self { items, page_size }
    }

    pub fn len(&self) -> usize {
        (self.items.len() + self.page_size - 1) / self.page_size
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    pub fn iter(&self) -> PaginatorIter<'_, T> {
        PaginatorIter {
            items: &self.items,
            page_size: self.page_size,
            index: 0,
        }
    }
}

pub struct PaginatorIter<'a, T> {
    items: &'a [T],
    page_size: usize,
    index: usize,
}

impl<'a, T: Clone> Iterator for PaginatorIter<'a, T> {
    type Item = Vec<T>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.index >= self.items.len() {
            return None;
        }
        let end = (self.index + self.page_size).min(self.items.len());
        let page = self.items[self.index..end].to_vec();
        self.index = end;
        Some(page)
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let remaining = if self.index >= self.items.len() {
            0
        } else {
            (self.items.len() - self.index + self.page_size - 1) / self.page_size
        };
        (remaining, Some(remaining))
    }
}

impl<'a, T: Clone> ExactSizeIterator for PaginatorIter<'a, T> {}

// Allow `for page in &paginator { ... }`
impl<'a, T: Clone> IntoIterator for &'a Paginator<T> {
    type Item = Vec<T>;
    type IntoIter = PaginatorIter<'a, T>;

    fn into_iter(self) -> Self::IntoIter {
        self.iter()
    }
}
```

### Example 6: Context manager (__enter__/__exit__) to RAII + Drop

Python:
```python
class DatabaseTransaction:
    def __init__(self, connection):
        self.connection = connection
        self.savepoint = None

    def __enter__(self):
        self.savepoint = self.connection.begin()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            self.savepoint.rollback()
        else:
            self.savepoint.commit()
        return False  # Don't suppress exceptions

class TempFile:
    def __init__(self, path: str):
        self.path = path
        self.file = None

    def __enter__(self):
        self.file = open(self.path, 'w')
        return self.file

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.file:
            self.file.close()
        os.unlink(self.path)
        return False
```

Rust:
```rust
// Database transaction: use sqlx's built-in transaction type (RAII)
async fn transfer_funds(pool: &PgPool, from: i64, to: i64, amount: f64) -> Result<(), DbError> {
    // Transaction is automatically rolled back if not committed (RAII)
    let mut tx = pool.begin().await?;

    sqlx::query("UPDATE accounts SET balance = balance - $1 WHERE id = $2")
        .bind(amount)
        .bind(from)
        .execute(&mut *tx)
        .await?;

    sqlx::query("UPDATE accounts SET balance = balance + $1 WHERE id = $2")
        .bind(amount)
        .bind(to)
        .execute(&mut *tx)
        .await?;

    tx.commit().await?; // Explicit commit; Drop would rollback
    Ok(())
}

// TempFile: custom Drop implementation
pub struct TempFile {
    path: std::path::PathBuf,
    file: std::fs::File,
}

impl TempFile {
    pub fn new(path: impl Into<std::path::PathBuf>) -> std::io::Result<Self> {
        let path = path.into();
        let file = std::fs::File::create(&path)?;
        Ok(Self { path, file })
    }

    pub fn file(&self) -> &std::fs::File {
        &self.file
    }

    pub fn file_mut(&mut self) -> &mut std::fs::File {
        &mut self.file
    }
}

impl Drop for TempFile {
    fn drop(&mut self) {
        // Best-effort cleanup; log error but don't panic
        if let Err(e) = std::fs::remove_file(&self.path) {
            tracing::warn!(path = ?self.path, error = ?e, "failed to remove temp file");
        }
    }
}
```

### Example 7: @property to getter/setter methods

Python:
```python
class Circle:
    def __init__(self, radius: float):
        self._radius = radius

    @property
    def radius(self) -> float:
        return self._radius

    @radius.setter
    def radius(self, value: float) -> None:
        if value < 0:
            raise ValueError("Radius cannot be negative")
        self._radius = value

    @property
    def area(self) -> float:
        return math.pi * self._radius ** 2

    @property
    def circumference(self) -> float:
        return 2 * math.pi * self._radius
```

Rust:
```rust
#[derive(Debug, Clone, Copy)]
pub struct Circle {
    radius: f64,
}

impl Circle {
    pub fn new(radius: f64) -> Result<Self, GeometryError> {
        if radius < 0.0 {
            return Err(GeometryError::NegativeRadius);
        }
        Ok(Self { radius })
    }

    // Getter (replaces @property)
    pub fn radius(&self) -> f64 {
        self.radius
    }

    // Setter (replaces @radius.setter)
    pub fn set_radius(&mut self, value: f64) -> Result<(), GeometryError> {
        if value < 0.0 {
            return Err(GeometryError::NegativeRadius);
        }
        self.radius = value;
        Ok(())
    }

    // Computed property (replaces @property for derived values)
    pub fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }

    pub fn circumference(&self) -> f64 {
        2.0 * std::f64::consts::PI * self.radius
    }
}
```

### Example 8: @staticmethod / @classmethod to associated functions

Python:
```python
class User:
    _id_counter = 0

    def __init__(self, name: str, email: str):
        User._id_counter += 1
        self.id = User._id_counter
        self.name = name
        self.email = email

    @staticmethod
    def validate_email(email: str) -> bool:
        return "@" in email and "." in email

    @classmethod
    def from_dict(cls, data: dict) -> "User":
        return cls(name=data["name"], email=data["email"])

    @classmethod
    def from_csv_row(cls, row: str) -> "User":
        parts = row.split(",")
        return cls(name=parts[0].strip(), email=parts[1].strip())
```

Rust:
```rust
use std::sync::atomic::{AtomicU64, Ordering};

static ID_COUNTER: AtomicU64 = AtomicU64::new(0);

#[derive(Debug, Clone)]
pub struct User {
    pub id: u64,
    pub name: String,
    pub email: String,
}

impl User {
    pub fn new(name: String, email: String) -> Self {
        let id = ID_COUNTER.fetch_add(1, Ordering::Relaxed) + 1;
        Self { id, name, email }
    }

    // @staticmethod -> associated function (no &self)
    pub fn validate_email(email: &str) -> bool {
        email.contains('@') && email.contains('.')
    }

    // @classmethod from_dict -> associated function taking a map
    pub fn from_map(data: &std::collections::HashMap<String, String>) -> Result<Self, UserError> {
        let name = data
            .get("name")
            .ok_or(UserError::MissingField("name"))?
            .clone();
        let email = data
            .get("email")
            .ok_or(UserError::MissingField("email"))?
            .clone();
        Ok(Self::new(name, email))
    }

    // @classmethod from_csv_row -> associated function
    pub fn from_csv_row(row: &str) -> Result<Self, UserError> {
        let parts: Vec<&str> = row.split(',').collect();
        if parts.len() < 2 {
            return Err(UserError::InvalidCsvRow);
        }
        Ok(Self::new(
            parts[0].trim().to_string(),
            parts[1].trim().to_string(),
        ))
    }
}
```

### Example 9: __getitem__ / __setitem__ to Index/IndexMut

Python:
```python
class Matrix:
    def __init__(self, rows: int, cols: int):
        self.rows = rows
        self.cols = cols
        self.data = [[0.0] * cols for _ in range(rows)]

    def __getitem__(self, key: tuple[int, int]) -> float:
        row, col = key
        return self.data[row][col]

    def __setitem__(self, key: tuple[int, int], value: float) -> None:
        row, col = key
        self.data[row][col] = value

    def __repr__(self) -> str:
        return f"Matrix({self.rows}x{self.cols})"
```

Rust:
```rust
#[derive(Debug, Clone)]
pub struct Matrix {
    rows: usize,
    cols: usize,
    data: Vec<f64>, // Flat storage for cache locality
}

impl Matrix {
    pub fn new(rows: usize, cols: usize) -> Self {
        Self {
            rows,
            cols,
            data: vec![0.0; rows * cols],
        }
    }

    pub fn rows(&self) -> usize { self.rows }
    pub fn cols(&self) -> usize { self.cols }
}

impl std::ops::Index<(usize, usize)> for Matrix {
    type Output = f64;

    fn index(&self, (row, col): (usize, usize)) -> &f64 {
        assert!(row < self.rows && col < self.cols, "index out of bounds");
        &self.data[row * self.cols + col]
    }
}

impl std::ops::IndexMut<(usize, usize)> for Matrix {
    fn index_mut(&mut self, (row, col): (usize, usize)) -> &mut f64 {
        assert!(row < self.rows && col < self.cols, "index out of bounds");
        &mut self.data[row * self.cols + col]
    }
}

impl std::fmt::Display for Matrix {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Matrix({}x{})", self.rows, self.cols)
    }
}
```

## Class Variable and __slots__ Mapping

| Python Pattern | Rust Equivalent |
|---------------|-----------------|
| Class variable (shared, immutable) | `const` or `static` in module scope |
| Class variable (shared, mutable) | `static` with `AtomicU64` / `LazyLock<Mutex<T>>` |
| Instance variable (`self.x`) | Struct field |
| `__slots__ = ['x', 'y']` | Just use struct fields (Rust structs are always "slotted") |
| `__dict__` access | No equivalent; use struct fields or `HashMap` for dynamic attrs |

## Template

```markdown
# Class Hierarchy Mapping

Source: {project_name}
Generated: {date}

## Summary

| Category | Count |
|----------|-------|
| Classes total | {n} |
| -> Converted to struct + impl | {n} |
| -> Converted to enum variants | {n} |
| -> Converted to trait definitions | {n} |
| -> Removed (absorbed into other types) | {n} |
| Inheritance chains resolved | {n} |
| Dunder methods mapped to traits | {n} |
| Properties -> getter/setter methods | {n} |

## Class Mappings

### 1. {ClassName}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Inherits from**: {parent classes}
**Strategy**: struct + impl / enum variant / trait

**Python class**:
```python
{source code}
```

**Rust equivalent**:
```rust
{compilable Rust code}
```

**Dunder mappings**:
| Python Method | Rust Trait/Impl |
|--------------|-----------------|
| `__repr__` | `#[derive(Debug)]` |
| `__eq__` | `#[derive(PartialEq)]` |

---

### 2. {ClassName}
...

## Inheritance Resolution Summary

| Python Hierarchy | Rust Strategy | Rationale |
|-----------------|---------------|-----------|
| `Dog(Animal)` | `enum Animal { Dog {...}, Cat {...} }` | Fixed set of subtypes |
| `UserRepo(BaseRepo)` | `trait Repository` + `struct UserRepo` | Open for extension |
| `Order(JsonMixin, LogMixin, Base)` | `struct Order` + impl 3 traits | Mixin decomposition |
```

## Completeness Check

- [ ] Every class in the source has a Rust struct, enum variant, or trait
- [ ] Every inheritance chain is resolved to composition, trait, or enum
- [ ] Every mixin is extracted into a separate Rust trait
- [ ] Every `__init__` is mapped to a `new()` associated function
- [ ] Every `__repr__` / `__str__` is mapped to Debug / Display
- [ ] Every `__eq__` / `__hash__` is mapped to PartialEq / Hash derives
- [ ] Every `__iter__` / `__next__` is mapped to Iterator trait
- [ ] Every `__enter__` / `__exit__` is mapped to RAII + Drop
- [ ] Every `__getitem__` / `__setitem__` is mapped to Index / IndexMut
- [ ] Every operator overload (`__add__`, `__mul__`, etc.) is mapped to std::ops traits
- [ ] Every `@property` is mapped to getter/setter methods
- [ ] Every `@staticmethod` / `@classmethod` is mapped to associated functions
- [ ] Every `super()` call is resolved (default trait method or delegation)
- [ ] Every metaclass usage is resolved (proc macro or trait)
- [ ] Class variables are mapped to const/static/module-level items
- [ ] `isinstance()` checks are replaced with `match` or trait bounds
- [ ] No Python inheritance is carried over -- all relationships use composition or traits
