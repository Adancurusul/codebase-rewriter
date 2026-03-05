# 20 - TypeScript Types to Rust Types Mapping

**Output**: `.migration-plan/mappings/type-system-mapping.md`

## Purpose

Map every TypeScript type system construct -- interfaces, type aliases, enums, union types, intersection types, mapped types, conditional types, utility types, template literal types, and discriminated unions -- to its Rust equivalent using structs, enums, traits, type aliases, and derive macros. TypeScript has one of the most expressive type systems of any mainstream language; this guide ensures no type-level construct is lost or silently downgraded during migration.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- complete inventory of all interfaces, types, enums, and type aliases
- `architecture.md` -- module boundaries and how types are shared across modules

Extract every instance of:
- Interface declarations
- Type alias declarations (including complex ones)
- Enum declarations (numeric and string)
- Union types (simple and discriminated)
- Intersection types
- Generic types with constraints
- Mapped types (`Record`, `Partial`, `Pick`, custom mapped types)
- Conditional types (`T extends U ? X : Y`)
- Utility types (`Partial`, `Required`, `Pick`, `Omit`, `Readonly`, `Extract`, `Exclude`)
- Template literal types
- Index signatures and dynamic keys
- Declaration merging / module augmentation

### Step 2: For each TypeScript type construct, determine Rust equivalent

**Core type mapping table:**

| TypeScript Construct | Rust Equivalent | Notes |
|---------------------|-----------------|-------|
| `interface Foo { ... }` | `struct Foo { ... }` | Add `#[derive(Debug, Clone, Serialize, Deserialize)]` |
| `type Foo = { ... }` | `struct Foo { ... }` | Identical to interface mapping |
| `type Foo = string` | `type Foo = String;` | Direct type alias |
| `type Foo = A \| B \| C` (simple union) | `enum Foo { A(A), B(B), C(C) }` | Each variant wraps the type |
| `type Foo = A & B` (intersection) | Struct with flattened fields or trait composition | See examples below |
| `enum Direction { Up, Down }` (numeric) | `enum Direction { Up, Down }` | Add `repr(i32)` if numeric values matter |
| `enum Color { Red = "red" }` (string) | `enum Color { Red }` + `strum` crate | Use `#[strum(serialize = "red")]` |
| `Partial<T>` | Struct with all `Option<T>` fields | Or a separate `UpdateFoo` struct |
| `Required<T>` | Struct with no `Option<T>` fields | The default Rust struct |
| `Pick<T, "a" \| "b">` | New struct with only fields `a` and `b` | Manual field selection |
| `Omit<T, "a">` | New struct without field `a` | Manual field exclusion |
| `Readonly<T>` | Default in Rust (immutable by default) | No action needed |
| `Record<K, V>` | `HashMap<K, V>` or `BTreeMap<K, V>` | Use `BTreeMap` if ordering matters |
| `T extends U ? X : Y` | Trait bounds or separate impls | See conditional types section |
| Template literal type | `String` with validation | Runtime validation or newtype |
| Index signature `[key: string]: T` | `HashMap<String, T>` | Dynamic keys |
| Generic `interface Foo<T>` | `struct Foo<T>` | With trait bounds where needed |
| `keyof T` | No direct equivalent | Use an enum of field names |
| `typeof value` | No direct equivalent | Types are always explicit in Rust |

### Step 3: Produce type mapping document

For EACH type found in the source, produce:
1. Source type with file:line reference
2. Rust equivalent with compilable code
3. Derive macros needed
4. Serde attributes for JSON compatibility
5. Any crate dependencies introduced

## Code Examples

### Example 1: Interface to Struct

**TypeScript:**
```typescript
interface User {
  id: string;
  name: string;
  email: string;
  age?: number;
  createdAt: Date;
  metadata: Record<string, unknown>;
}
```

**Rust:**
```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub age: Option<u32>,
    pub created_at: DateTime<Utc>,
    pub metadata: HashMap<String, serde_json::Value>,
}
```

### Example 2: Type Alias (Simple and Complex)

**TypeScript:**
```typescript
type UserId = string;
type Coordinate = [number, number];
type StringOrNumber = string | number;
type Callback<T> = (error: Error | null, result: T) => void;
```

**Rust:**
```rust
type UserId = String;
type Coordinate = (f64, f64);

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum StringOrNumber {
    String(String),
    Number(f64),
}

// Callback type: use a closure or function pointer
// For sync: Box<dyn Fn(Result<T, AppError>) + Send>
// For async: typically replaced with Result<T, E> return values
```

### Example 3: Discriminated Union to Rust Enum

**TypeScript:**
```typescript
type ApiResponse =
  | { status: "success"; data: UserData; requestId: string }
  | { status: "error"; error: string; code: number; requestId: string }
  | { status: "pending"; retryAfter: number; requestId: string };

function handleResponse(resp: ApiResponse) {
  switch (resp.status) {
    case "success":
      console.log(resp.data);
      break;
    case "error":
      console.error(`Error ${resp.code}: ${resp.error}`);
      break;
    case "pending":
      setTimeout(() => retry(), resp.retryAfter * 1000);
      break;
  }
}
```

**Rust:**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "camelCase")]
pub enum ApiResponse {
    #[serde(rename = "success")]
    Success {
        data: UserData,
        request_id: String,
    },
    #[serde(rename = "error")]
    Error {
        error: String,
        code: i32,
        request_id: String,
    },
    #[serde(rename = "pending")]
    Pending {
        retry_after: u64,
        request_id: String,
    },
}

fn handle_response(resp: ApiResponse) {
    match resp {
        ApiResponse::Success { data, .. } => {
            println!("{data:?}");
        }
        ApiResponse::Error { code, error, .. } => {
            eprintln!("Error {code}: {error}");
        }
        ApiResponse::Pending { retry_after, .. } => {
            // Schedule retry after `retry_after` seconds
        }
    }
}
```

### Example 4: Intersection Types to Struct Composition

**TypeScript:**
```typescript
interface Timestamps {
  createdAt: Date;
  updatedAt: Date;
}

interface SoftDeletable {
  deletedAt: Date | null;
}

type BaseEntity = Timestamps & SoftDeletable & { id: string };

interface User extends BaseEntity {
  name: string;
  email: string;
}

interface Order extends BaseEntity {
  userId: string;
  total: number;
}
```

**Rust (Option A: Flatten with serde):**
```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Timestamps {
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SoftDeletable {
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: Uuid,
    #[serde(flatten)]
    pub timestamps: Timestamps,
    #[serde(flatten)]
    pub soft_deletable: SoftDeletable,
    pub name: String,
    pub email: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Order {
    pub id: Uuid,
    #[serde(flatten)]
    pub timestamps: Timestamps,
    #[serde(flatten)]
    pub soft_deletable: SoftDeletable,
    pub user_id: Uuid,
    pub total: f64,
}
```

**Rust (Option B: Trait-based shared behavior):**
```rust
pub trait HasTimestamps {
    fn created_at(&self) -> DateTime<Utc>;
    fn updated_at(&self) -> DateTime<Utc>;
}

pub trait SoftDeletable {
    fn deleted_at(&self) -> Option<DateTime<Utc>>;
    fn is_deleted(&self) -> bool {
        self.deleted_at().is_some()
    }
}

impl HasTimestamps for User {
    fn created_at(&self) -> DateTime<Utc> { self.timestamps.created_at }
    fn updated_at(&self) -> DateTime<Utc> { self.timestamps.updated_at }
}

impl SoftDeletable for User {
    fn deleted_at(&self) -> Option<DateTime<Utc>> { self.soft_deletable.deleted_at }
}
```

### Example 5: Generic Types with Constraints

**TypeScript:**
```typescript
interface Repository<T extends BaseEntity> {
  findById(id: string): Promise<T | null>;
  findAll(filter: Partial<T>): Promise<T[]>;
  create(data: Omit<T, "id" | "createdAt" | "updatedAt">): Promise<T>;
  update(id: string, data: Partial<Omit<T, "id">>): Promise<T>;
  delete(id: string): Promise<void>;
}

class PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}
```

**Rust:**
```rust
use async_trait::async_trait;
use uuid::Uuid;

#[async_trait]
pub trait Repository: Send + Sync {
    type Entity: Send + Sync + Clone;
    type CreateInput: Send;
    type UpdateInput: Send;
    type Filter: Send;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Self::Entity>, DbError>;
    async fn find_all(&self, filter: Self::Filter) -> Result<Vec<Self::Entity>, DbError>;
    async fn create(&self, data: Self::CreateInput) -> Result<Self::Entity, DbError>;
    async fn update(&self, id: Uuid, data: Self::UpdateInput) -> Result<Self::Entity, DbError>;
    async fn delete(&self, id: Uuid) -> Result<(), DbError>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PaginatedResponse<T: Serialize> {
    pub items: Vec<T>,
    pub total: u64,
    pub page: u32,
    pub page_size: u32,
    pub has_more: bool,
}

impl<T: Serialize> PaginatedResponse<T> {
    pub fn new(items: Vec<T>, total: u64, page: u32, page_size: u32) -> Self {
        Self {
            has_more: (page as u64 * page_size as u64) < total,
            items,
            total,
            page,
            page_size,
        }
    }
}
```

### Example 6: Mapped Types and Utility Types

**TypeScript:**
```typescript
interface User {
  id: string;
  name: string;
  email: string;
  password: string;
  role: Role;
}

// Utility type usage
type CreateUserInput = Omit<User, "id">;
type UpdateUserInput = Partial<Omit<User, "id" | "password">>;
type PublicUser = Pick<User, "id" | "name" | "email">;
type ReadonlyUser = Readonly<User>;

// Custom mapped type
type Nullable<T> = { [K in keyof T]: T[K] | null };
```

**Rust:**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub password: String,
    pub role: Role,
}

// Omit<User, "id"> -- create a new struct without `id`
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateUserInput {
    pub name: String,
    pub email: String,
    pub password: String,
    pub role: Role,
}

// Partial<Omit<User, "id" | "password">> -- all fields optional, excluding id and password
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateUserInput {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub role: Option<Role>,
}

// Pick<User, "id" | "name" | "email"> -- only selected fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PublicUser {
    pub id: Uuid,
    pub name: String,
    pub email: String,
}

// Readonly<User> -- default in Rust (immutable by reference)
// No special type needed; `&User` is already immutable

// From conversions for ergonomic construction
impl From<User> for PublicUser {
    fn from(user: User) -> Self {
        PublicUser {
            id: user.id,
            name: user.name,
            email: user.email,
        }
    }
}
```

### Example 7: String Enums with strum

**TypeScript:**
```typescript
enum UserRole {
  Admin = "admin",
  Editor = "editor",
  Viewer = "viewer",
  Guest = "guest",
}

enum HttpMethod {
  GET = "GET",
  POST = "POST",
  PUT = "PUT",
  DELETE = "DELETE",
  PATCH = "PATCH",
}

function roleToPermissionLevel(role: UserRole): number {
  switch (role) {
    case UserRole.Admin: return 100;
    case UserRole.Editor: return 50;
    case UserRole.Viewer: return 10;
    case UserRole.Guest: return 0;
  }
}
```

**Rust:**
```rust
use serde::{Deserialize, Serialize};
use strum::{Display, EnumString, EnumIter, IntoStaticStr};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[derive(Display, EnumString, EnumIter, IntoStaticStr)]
#[serde(rename_all = "snake_case")]
#[strum(serialize_all = "snake_case")]
pub enum UserRole {
    Admin,
    Editor,
    Viewer,
    Guest,
}

impl UserRole {
    pub fn permission_level(&self) -> u32 {
        match self {
            UserRole::Admin => 100,
            UserRole::Editor => 50,
            UserRole::Viewer => 10,
            UserRole::Guest => 0,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[derive(Display, EnumString)]
pub enum HttpMethod {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
}

// Usage:
// let role: UserRole = "admin".parse().unwrap();
// let role_str: &str = role.into();
// assert_eq!(role_str, "admin");
```

### Example 8: Conditional Types and Template Literal Types

**TypeScript:**
```typescript
// Conditional type
type IsString<T> = T extends string ? true : false;
type ExtractPromise<T> = T extends Promise<infer U> ? U : T;

// Template literal type
type EventName = `on${Capitalize<"click" | "hover" | "focus">}`;
// Result: "onClick" | "onHover" | "onFocus"

type ApiEndpoint = `/api/${string}/${number}`;

// Conditional type in practice
type ApiResponse<T> = T extends void
  ? { success: boolean }
  : { success: boolean; data: T };
```

**Rust:**
```rust
// Conditional types: Rust uses trait specialization or separate impls

// ExtractPromise<T> -- not needed; Rust async fn returns T directly, not Future<T>
// The Rust type system already "unwraps" the Future at the call site

// Template literal types: Rust has no equivalent at the type level
// Use a newtype with validation instead
#[derive(Debug, Clone)]
pub struct EventName(String);

impl EventName {
    pub fn new(name: &str) -> Result<Self, ValidationError> {
        let valid_names = ["onClick", "onHover", "onFocus"];
        if valid_names.contains(&name) {
            Ok(EventName(name.to_string()))
        } else {
            Err(ValidationError::Format {
                field: "event_name".into(),
                message: format!("must be one of: {}", valid_names.join(", ")),
            })
        }
    }
}

// ApiResponse<T> conditional type: use separate types or an enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiSuccess {
    pub success: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiDataResponse<T: Serialize> {
    pub success: bool,
    pub data: T,
}

// Or use a single enum that handles both cases
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ApiResponse<T: Serialize> {
    WithData { success: bool, data: T },
    NoData { success: bool },
}
```

## Template

```markdown
# Type System Mapping

Source: {project_name}
Generated: {date}

## Summary

| Category | Count | Rust Strategy |
|----------|-------|---------------|
| Interfaces | {count} | Structs with derive macros |
| Type aliases (simple) | {count} | `type` aliases |
| Type aliases (complex) | {count} | Structs or enums |
| Numeric enums | {count} | `#[repr(i32)]` enums |
| String enums | {count} | Enums + strum crate |
| Discriminated unions | {count} | `#[serde(tag = "...")]` enums |
| Simple unions | {count} | `#[serde(untagged)]` enums |
| Intersection types | {count} | Struct composition + `#[serde(flatten)]` |
| Generic types | {count} | Generic structs with trait bounds |
| Utility types (Partial/Pick/Omit) | {count} | Separate concrete structs |
| Conditional types | {count} | Trait impls or separate types |
| Mapped types | {count} | Manual struct definitions |
| Template literal types | {count} | Newtypes with validation |

## Type Mappings

### 1. {TypeName}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Category**: {Interface / Union / Enum / Generic / ...}

TypeScript:
```typescript
{source code}
```

Rust:
```rust
{rust code with all derive macros and serde attributes}
```

**Derive macros**: `Debug, Clone, Serialize, Deserialize`
**Serde config**: `#[serde(rename_all = "camelCase")]`
**Crates**: {any new crate dependencies}

---

### 2. {TypeName}
...

## Enum Mapping Table

| TypeScript Enum | Type | Rust Enum | Serde Strategy | Strum Needed |
|----------------|------|-----------|----------------|-------------|
| `UserRole` | String | `UserRole` | `rename_all = "snake_case"` | Yes |
| `Direction` | Numeric | `Direction` | `repr(i32)` | No |
| ... | ... | ... | ... | ... |

## Utility Type Expansion Table

For each use of `Partial`, `Pick`, `Omit`, `Required`, list the concrete struct generated:

| Source Utility Type | Applied To | Rust Struct Name | Fields |
|--------------------|------------|------------------|--------|
| `Partial<User>` | `User` | `UpdateUser` | All fields as `Option<T>` |
| `Pick<User, "id" \| "name">` | `User` | `PublicUser` | `id`, `name` only |
| `Omit<User, "password">` | `User` | `SafeUser` | All except `password` |
| ... | ... | ... | ... |

## Generic Type Parameters

| Source Generic | Constraint | Rust Bound | Notes |
|---------------|-----------|------------|-------|
| `T extends BaseEntity` | Must have id, timestamps | Associated type in trait | Use trait |
| `K extends string` | String keys | `K: AsRef<str> + Hash + Eq` | Or just `String` |
| `T extends Record<string, any>` | Object-like | `T: Serialize + DeserializeOwned` | Serde bound |
| ... | ... | ... | ... |

## Crate Dependencies

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4", "serde"] }
strum = { version = "0.26", features = ["derive"] }
```
```

## Completeness Check

- [ ] Every `interface` declaration has a corresponding Rust struct
- [ ] Every `type` alias has a corresponding Rust `type` or struct
- [ ] Every TypeScript `enum` (numeric and string) has a Rust enum with correct serialization
- [ ] Every discriminated union has a `#[serde(tag = "...")]` Rust enum
- [ ] Every simple union has a `#[serde(untagged)]` Rust enum or explicit enum
- [ ] Every intersection type is resolved via struct composition or `#[serde(flatten)]`
- [ ] Every use of `Partial<T>` has a concrete struct with `Option<T>` fields
- [ ] Every use of `Pick<T, K>` has a concrete struct with only the selected fields
- [ ] Every use of `Omit<T, K>` has a concrete struct without the excluded fields
- [ ] Every generic type has correct trait bounds replacing TypeScript constraints
- [ ] Conditional types are resolved to concrete Rust types or trait implementations
- [ ] Template literal types are replaced with newtypes or validated strings
- [ ] `Record<K, V>` types are mapped to `HashMap<K, V>` or `BTreeMap<K, V>`
- [ ] All `#[serde(...)]` attributes are specified for JSON compatibility
- [ ] All derive macros are listed for every new struct and enum
- [ ] `From` impls are defined for all struct-to-struct conversions used in the source
- [ ] Enum mapping table covers every TypeScript enum
- [ ] Utility type expansion table covers every `Partial/Pick/Omit/Required` usage
