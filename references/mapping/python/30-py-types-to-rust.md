# 30 - Python Type Hints to Rust Type Mapping

**Output**: Contributes to `.migration-plan/mappings/type-mapping.md`

## Purpose

Map every Python type annotation -- type hints, dataclasses, TypedDict, NamedTuple, enums, Protocols, ABCs, Pydantic models, and attrs classes -- to their Rust struct, enum, trait, and generic equivalents. Python's type system is optional and erased at runtime; Rust's is mandatory and enforced at compile time. This mapping bridges that gap by producing a concrete Rust type for every annotated (and unannotated) Python type found in the source.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- inventory of all classes, dataclasses, TypedDicts, NamedTuples, enums, Protocols, ABCs, type aliases, and Pydantic models
- `architecture.md` -- module structure and cross-module type usage
- `dependency-tree.md` -- identifies pydantic, attrs, or other type-related libraries

Extract every instance of:
- `@dataclass` and `@dataclass(frozen=True)` classes
- `TypedDict` definitions
- `NamedTuple` definitions
- `enum.Enum` / `enum.IntEnum` / `enum.StrEnum` subclasses
- `Union[A, B]` and `A | B` type hints
- `Literal["x", "y"]` type hints
- `Protocol` classes (structural typing)
- `ABC` / `abstractmethod` classes
- `Generic[T]` parameterized classes
- `TypeVar` and `ParamSpec` definitions
- `type` alias statements and `TypeAlias` annotations
- `Pydantic BaseModel` subclasses
- `attrs` / `@define` / `@attr.s` classes
- `NewType` definitions
- Bare classes with `__init__` (not using any framework)

### Step 2: For each Python type, determine Rust equivalent

Apply this mapping table for EVERY type found:

| Python Type | Rust Equivalent | Derive Macros | Notes |
|-------------|-----------------|---------------|-------|
| `@dataclass` | `struct` | `Debug, Clone` | Add `PartialEq, Eq` if `eq=True` (default) |
| `@dataclass(frozen=True)` | `struct` (no `&mut` methods) | `Debug, Clone, Hash, PartialEq, Eq` | Immutable by convention; Rust enforces via ownership |
| `TypedDict` | `struct` | `Debug, Clone, Serialize, Deserialize` | All fields become owned types |
| `TypedDict(total=False)` | `struct` with `Option<T>` fields | `Debug, Clone, Serialize, Deserialize` | Non-required fields become `Option<T>` |
| `NamedTuple` | `struct` | `Debug, Clone, PartialEq` | Positional access via named fields |
| `enum.Enum` | `enum` | `Debug, Clone, Copy, PartialEq, Eq` | Unit variants |
| `enum.IntEnum` | `enum` with `#[repr(i32)]` | `Debug, Clone, Copy, PartialEq, Eq` | Integer-backed enum |
| `enum.StrEnum` | `enum` with `Serialize/Deserialize` | `Debug, Clone, PartialEq, Eq, Serialize, Deserialize` | String-serialized enum |
| `Union[A, B]` | `enum Variants { A(A), B(B) }` | `Debug, Clone` | Tagged union |
| `Literal["x", "y"]` | `enum` or `const` | Depends on usage | Small fixed set -> enum; single value -> const |
| `Protocol` | `trait` | N/A | Structural typing -> explicit trait impl |
| `ABC` | `trait` | N/A | Abstract methods become trait methods |
| `Generic[T]` | `struct<T>` / `fn<T>` | Varies | Add trait bounds from usage analysis |
| `TypeVar("T", bound=X)` | `T: X` trait bound | N/A | Bounded generics |
| `type alias` | `type Alias = ConcreteType;` | N/A | Direct alias |
| `NewType` | Newtype pattern `struct Name(Inner);` | `Debug, Clone` | Type-safe wrapper |
| `BaseModel` (Pydantic) | `struct` + validation | `Debug, Clone, Serialize, Deserialize, Validate` | Use `validator` or `garde` crate |
| `@define` (attrs) | `struct` | `Debug, Clone` | `attrs` validators -> custom `new()` or `garde` |

### Step 3: Produce type mapping document

For EACH type found in the source, produce:
1. Source definition with file:line reference
2. Python code snippet
3. Rust equivalent with compilable code
4. Derive macros selected with rationale
5. Any crate dependencies needed

## Code Examples

### Example 1: dataclass to struct

Python:
```python
from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID

@dataclass
class User:
    id: UUID
    name: str
    email: str
    age: int
    tags: list[str] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)
```

Rust:
```rust
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub age: i32,
    pub tags: Vec<String>,
    pub created_at: DateTime<Utc>,
}

impl User {
    pub fn new(id: Uuid, name: String, email: String, age: i32) -> Self {
        Self {
            id,
            name,
            email,
            age,
            tags: Vec::new(),
            created_at: Utc::now(),
        }
    }
}
```

### Example 2: frozen dataclass to immutable struct

Python:
```python
@dataclass(frozen=True)
class Point:
    x: float
    y: float

    def distance_to(self, other: "Point") -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5
```

Rust:
```rust
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

impl Point {
    pub fn new(x: f64, y: f64) -> Self {
        Self { x, y }
    }

    pub fn distance_to(&self, other: &Point) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
    }
}
```

### Example 3: TypedDict to struct with serde

Python:
```python
from typing import TypedDict, NotRequired

class UserResponse(TypedDict):
    id: str
    name: str
    email: str
    avatar_url: NotRequired[str]
    bio: NotRequired[str]
```

Rust:
```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserResponse {
    pub id: String,
    pub name: String,
    pub email: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bio: Option<String>,
}
```

### Example 4: enum.Enum and enum.StrEnum to Rust enum

Python:
```python
from enum import Enum, IntEnum, StrEnum

class Color(Enum):
    RED = "red"
    GREEN = "green"
    BLUE = "blue"

class HttpStatus(IntEnum):
    OK = 200
    NOT_FOUND = 404
    INTERNAL_ERROR = 500

class Role(StrEnum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"
```

Rust:
```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Color {
    Red,
    Green,
    Blue,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum HttpStatus {
    Ok = 200,
    NotFound = 404,
    InternalError = 500,
}

impl HttpStatus {
    pub fn from_code(code: i32) -> Option<Self> {
        match code {
            200 => Some(Self::Ok),
            404 => Some(Self::NotFound),
            500 => Some(Self::InternalError),
            _ => None,
        }
    }

    pub fn code(&self) -> i32 {
        *self as i32
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Admin,
    User,
    Guest,
}

impl std::fmt::Display for Role {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Role::Admin => write!(f, "admin"),
            Role::User => write!(f, "user"),
            Role::Guest => write!(f, "guest"),
        }
    }
}
```

### Example 5: Union type to Rust enum

Python:
```python
from typing import Union
from dataclasses import dataclass

@dataclass
class TextMessage:
    content: str

@dataclass
class ImageMessage:
    url: str
    width: int
    height: int

@dataclass
class FileMessage:
    filename: str
    size_bytes: int

Message = Union[TextMessage, ImageMessage, FileMessage]

def render_message(msg: Message) -> str:
    if isinstance(msg, TextMessage):
        return msg.content
    elif isinstance(msg, ImageMessage):
        return f"[Image: {msg.url}]"
    elif isinstance(msg, FileMessage):
        return f"[File: {msg.filename}]"
```

Rust:
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Message {
    Text { content: String },
    Image { url: String, width: i32, height: i32 },
    File { filename: String, size_bytes: u64 },
}

impl Message {
    pub fn render(&self) -> String {
        match self {
            Message::Text { content } => content.clone(),
            Message::Image { url, .. } => format!("[Image: {url}]"),
            Message::File { filename, .. } => format!("[File: {filename}]"),
        }
    }
}
```

### Example 6: Protocol to trait

Python:
```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class Drawable(Protocol):
    def draw(self, canvas: "Canvas") -> None: ...
    def bounding_box(self) -> tuple[float, float, float, float]: ...

class Serializable(Protocol):
    def to_bytes(self) -> bytes: ...
    def from_bytes(cls, data: bytes) -> "Serializable": ...
```

Rust:
```rust
pub trait Drawable {
    fn draw(&self, canvas: &mut Canvas);
    fn bounding_box(&self) -> (f64, f64, f64, f64);
}

pub trait Serializable: Sized {
    fn to_bytes(&self) -> Vec<u8>;
    fn from_bytes(data: &[u8]) -> Result<Self, DecodeError>;
}
```

### Example 7: Pydantic BaseModel to struct with validation

Python:
```python
from pydantic import BaseModel, Field, field_validator, EmailStr

class CreateUserRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    age: int = Field(ge=0, le=200)
    password: str = Field(min_length=8)
    tags: list[str] = Field(default_factory=list, max_length=20)

    @field_validator("name")
    @classmethod
    def name_must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("name must not be blank")
        return v.strip()
```

Rust:
```rust
use serde::Deserialize;
use validator::Validate;

#[derive(Debug, Clone, Deserialize, Validate)]
pub struct CreateUserRequest {
    #[validate(length(min = 1, max = 100), custom(function = "validate_not_blank"))]
    pub name: String,

    #[validate(email)]
    pub email: String,

    #[validate(range(min = 0, max = 200))]
    pub age: i32,

    #[validate(length(min = 8))]
    pub password: String,

    #[validate(length(max = 20))]
    #[serde(default)]
    pub tags: Vec<String>,
}

fn validate_not_blank(name: &str) -> Result<(), validator::ValidationError> {
    if name.trim().is_empty() {
        return Err(validator::ValidationError::new("name must not be blank"));
    }
    Ok(())
}
```

### Example 8: Generic class and NewType

Python:
```python
from typing import Generic, TypeVar, NewType

T = TypeVar("T")
K = TypeVar("K")

class Registry(Generic[K, T]):
    def __init__(self) -> None:
        self._items: dict[K, T] = {}

    def register(self, key: K, item: T) -> None:
        self._items[key] = item

    def get(self, key: K) -> T | None:
        return self._items.get(key)

    def all(self) -> list[T]:
        return list(self._items.values())

UserId = NewType("UserId", int)
OrderId = NewType("OrderId", str)
```

Rust:
```rust
use std::collections::HashMap;
use std::hash::Hash;

pub struct Registry<K, T>
where
    K: Eq + Hash,
{
    items: HashMap<K, T>,
}

impl<K, T> Registry<K, T>
where
    K: Eq + Hash,
{
    pub fn new() -> Self {
        Self {
            items: HashMap::new(),
        }
    }

    pub fn register(&mut self, key: K, item: T) {
        self.items.insert(key, item);
    }

    pub fn get(&self, key: &K) -> Option<&T> {
        self.items.get(key)
    }

    pub fn all(&self) -> Vec<&T> {
        self.items.values().collect()
    }
}

impl<K, T> Default for Registry<K, T>
where
    K: Eq + Hash,
{
    fn default() -> Self {
        Self::new()
    }
}

// Newtype pattern -- provides type safety, zero runtime cost
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct UserId(pub i64);

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct OrderId(pub String);

impl std::fmt::Display for UserId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::fmt::Display for OrderId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}
```

### Example 9: ABC to trait with default methods

Python:
```python
from abc import ABC, abstractmethod

class Repository(ABC):
    @abstractmethod
    def find_by_id(self, id: str) -> dict | None:
        ...

    @abstractmethod
    def save(self, entity: dict) -> dict:
        ...

    def find_or_create(self, id: str, defaults: dict) -> dict:
        """Non-abstract method with default implementation."""
        existing = self.find_by_id(id)
        if existing is not None:
            return existing
        return self.save({**defaults, "id": id})
```

Rust:
```rust
pub trait Repository {
    type Entity: Clone;

    fn find_by_id(&self, id: &str) -> Result<Option<Self::Entity>, DbError>;
    fn save(&mut self, entity: Self::Entity) -> Result<Self::Entity, DbError>;

    /// Default method -- implementors can override if needed.
    fn find_or_create(
        &mut self,
        id: &str,
        defaults: Self::Entity,
    ) -> Result<Self::Entity, DbError> {
        if let Some(existing) = self.find_by_id(id)? {
            return Ok(existing);
        }
        self.save(defaults)
    }
}
```

## Primitive Type Mapping

| Python Type | Rust Type | Notes |
|-------------|-----------|-------|
| `int` | `i64` | Python ints are unbounded; use `i64` unless range is known |
| `int` (known small) | `i32` / `i16` / `i8` | Use smallest type that fits the domain |
| `int` (non-negative) | `u64` / `u32` / `usize` | For counts, sizes, indices |
| `float` | `f64` | Python `float` is always 64-bit |
| `str` | `String` (owned) / `&str` (borrowed) | Owned for struct fields; borrowed for function params |
| `bytes` | `Vec<u8>` (owned) / `&[u8]` (borrowed) | Byte sequences |
| `bool` | `bool` | Direct mapping |
| `None` | `()` (unit type) | As return type; see `31-py-none-to-option.md` for Optional |
| `list[T]` | `Vec<T>` | Dynamic array |
| `tuple[T, ...]` | `Vec<T>` | Homogeneous variable-length tuple |
| `tuple[A, B, C]` | `(A, B, C)` | Fixed-length heterogeneous tuple |
| `dict[K, V]` | `HashMap<K, V>` | Requires `K: Eq + Hash` |
| `set[T]` | `HashSet<T>` | Requires `T: Eq + Hash` |
| `frozenset[T]` | `HashSet<T>` (no `&mut` access) | Immutable by API design |
| `collections.OrderedDict` | `IndexMap<K, V>` | From `indexmap` crate |
| `collections.deque` | `VecDeque<T>` | Double-ended queue |
| `collections.Counter` | `HashMap<K, usize>` | Manual counting |
| `collections.defaultdict` | `HashMap` with `.entry().or_default()` | Entry API |
| `Any` | `Box<dyn Any>` (avoid) | Redesign to use enums or traits |
| `object` | Redesign | No universal base type in Rust |
| `Callable[[A, B], R]` | `Fn(A, B) -> R` | See `35-py-patterns.md` |
| `Iterator[T]` | `impl Iterator<Item = T>` | See `35-py-patterns.md` |
| `datetime.datetime` | `chrono::DateTime<Utc>` | From `chrono` crate |
| `datetime.date` | `chrono::NaiveDate` | From `chrono` crate |
| `datetime.timedelta` | `chrono::Duration` | From `chrono` crate |
| `uuid.UUID` | `uuid::Uuid` | From `uuid` crate |
| `pathlib.Path` | `std::path::PathBuf` (owned) / `&Path` (borrowed) | Built-in |
| `decimal.Decimal` | `rust_decimal::Decimal` | From `rust_decimal` crate |
| `re.Pattern` | `regex::Regex` | From `regex` crate |
| `ipaddress.IPv4Address` | `std::net::Ipv4Addr` | Built-in |
| `ipaddress.IPv6Address` | `std::net::Ipv6Addr` | Built-in |
| `typing.IO` | `std::io::Read` / `std::io::Write` | Trait-based I/O |

## Template

```markdown
# Type Mapping

Source: {project_name}
Generated: {date}

## Summary

| Category | Count | Notes |
|----------|-------|-------|
| dataclass -> struct | {n} | |
| TypedDict -> struct | {n} | |
| NamedTuple -> struct | {n} | |
| enum.Enum -> enum | {n} | |
| Union -> enum | {n} | |
| Protocol -> trait | {n} | |
| ABC -> trait | {n} | |
| BaseModel -> struct+validation | {n} | |
| Generic -> generic struct/fn | {n} | |
| NewType -> newtype struct | {n} | |
| type alias -> type alias | {n} | |

## Type Mappings

### 1. {TypeName}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Category**: dataclass / TypedDict / Enum / Protocol / ABC / BaseModel / ...
**Python type**:
```python
{source code}
```

**Rust equivalent**:
```rust
{compilable Rust code}
```

**Derive macros**: `Debug, Clone, PartialEq, Eq, Serialize, Deserialize`
**Rationale**: {why these derives, any special handling}
**Crates**: {any external crates needed}

---

### 2. {TypeName}
...

## Primitive Type Mapping Applied

| Python Type Used | Rust Type Chosen | Occurrences | Rationale |
|-----------------|------------------|-------------|-----------|
| `str` | `String` | {n} | Owned data in structs |
| `int` | `i64` | {n} | General-purpose integer |
| `float` | `f64` | {n} | Standard IEEE 754 |
| `list[str]` | `Vec<String>` | {n} | Dynamic string list |
| `dict[str, Any]` | `HashMap<String, serde_json::Value>` | {n} | Untyped JSON |
| ... | ... | ... | ... |

## Crate Dependencies

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4", "serde"] }
validator = { version = "0.19", features = ["derive"] }
indexmap = { version = "2", features = ["serde"] }
rust_decimal = { version = "1", features = ["serde"] }
```
```

## Completeness Check

- [ ] Every `@dataclass` has a Rust struct with appropriate derives
- [ ] Every `TypedDict` has a Rust struct with serde derives
- [ ] Every `NamedTuple` has a Rust struct
- [ ] Every `enum.Enum` / `IntEnum` / `StrEnum` has a Rust enum with correct representation
- [ ] Every `Union[A, B, ...]` has a Rust enum with named variants
- [ ] Every `Literal[...]` has a Rust enum or const
- [ ] Every `Protocol` has a Rust trait with all methods mapped
- [ ] Every `ABC` has a Rust trait with default methods where applicable
- [ ] Every `Generic[T]` has Rust generics with correct trait bounds
- [ ] Every `TypeVar` bound is translated to a trait bound
- [ ] Every `type` alias has a Rust `type` alias
- [ ] Every `NewType` has a Rust newtype wrapper struct
- [ ] Every Pydantic `BaseModel` has a struct with `validator` or `garde` derives
- [ ] Every `attrs` class has a struct with appropriate derives
- [ ] Primitive type mapping table covers all Python types used in the source
- [ ] All serde rename strategies are specified for JSON-serialized types
- [ ] All optional/default fields use `Option<T>` with `#[serde(default)]` or `skip_serializing_if`
- [ ] Crate dependencies are listed with correct versions
