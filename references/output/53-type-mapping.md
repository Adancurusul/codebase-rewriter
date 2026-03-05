# 53 - Type Mapping

**Output**: `.migration-plan/mappings/type-mapping.md`

## Purpose

Map every source type definition to its concrete Rust equivalent. This is THE most detailed document in the entire migration plan. Every interface, class, enum, type alias, union type, generic type, and constant gets a before/after code block showing the exact source definition and the exact Rust struct/enum/trait/type alias it becomes.

This document must be detailed enough that a developer can copy-paste the Rust type definitions into a `.rs` file and have them compile (with the correct crate dependencies). No ambiguity, no "TBD" placeholders, no "similar to source" hand-waving.

For Rust migration specifically, this document resolves:
- Nullable types -> `Option<T>`
- Union types -> enum variants
- Inheritance -> composition + traits
- Generic types -> generic structs with trait bounds
- Validation decorators -> `validator` derive macros
- Serialization annotations -> `serde` attributes
- Database annotations -> `sqlx::FromRow` or `diesel` derives

## Template

```markdown
# Type Mapping

Source: {project_name}
Generated: {date}
Source Language: {TypeScript / Python / Go}

## Summary

| Metric | Count |
|--------|-------|
| Total Types | {N} |
| Interfaces / Structs | {N} |
| Enums | {N} |
| Type Aliases | {N} |
| Generic Types | {N} |
| Union / Sum Types | {N} |
| Constants / Config | {N} |
| Classes (with methods) | {N} |

### Migration Complexity Distribution

| Complexity | Count | Description |
|-----------|-------|-------------|
| Direct (1:1) | {N} | Simple struct/enum mapping, no logic changes |
| Moderate | {N} | Requires serde annotations, derive macros, or Option wrapping |
| Complex | {N} | Inheritance flattening, union -> enum conversion, trait extraction |
| Requires Redesign | {N} | No direct Rust equivalent; needs architectural change |

## Type Mapping Index

| # | Source Type | Source File | Rust Type | Rust Location | Complexity | Dependencies | Usage Count |
|---|-----------|------------|-----------|---------------|------------|--------------|-------------|
| T-1 | {TypeName} | [{file}:{line}](../src/{file}#L{line}) | {RustType} | crates/{crate}/src/{module}.rs | {Direct/Moderate/Complex/Redesign} | {T-N, T-M} | {N files} |
| T-2 | {TypeName} | [{file}:{line}](../src/{file}#L{line}) | {RustType} | crates/{crate}/src/{module}.rs | {Direct/Moderate/Complex/Redesign} | {T-N} | {N files} |
| ... | | | | | | | |

## Detailed Type Mappings

### T-1: {TypeName}

**Source** ([{file}:{line}](../src/{file}#L{line})):

```{source_language}
{exact source type definition, copied verbatim}
```

**Rust Equivalent** (crates/{crate}/src/{module}.rs):

```rust
{complete Rust type definition with all derive macros, serde attributes,
 validation annotations, and documentation comments}
```

**Conversion Notes**:
- {Field-by-field mapping notes, e.g., "email: string | null -> email: Option<String>"}
- {Naming changes, e.g., "camelCase -> snake_case fields, serde(rename_all) handles JSON"}
- {Type changes, e.g., "Date -> chrono::DateTime<Utc>"}
- {Validation changes, e.g., "Zod z.string().email() -> #[validate(email)]"}
- {Derive macro rationale, e.g., "sqlx::FromRow for database queries"}

**Dependencies**: References {T-N: TypeName}, {T-M: TypeName}

**Used by**: {N} files -- [{file1}](../src/{file1}), [{file2}](../src/{file2}), ...

**Migration Order**: Phase {N} (depends on {T-N})

---

### T-2: {TypeName}

**Source** ([{file}:{line}](../src/{file}#L{line})):

```{source_language}
{exact source type definition}
```

**Rust Equivalent** (crates/{crate}/src/{module}.rs):

```rust
{complete Rust type definition}
```

**Conversion Notes**:
- {notes}

**Dependencies**: {references}

**Used by**: {files}

**Migration Order**: Phase {N}

---

{Repeat for EVERY type: T-3, T-4, ... T-N}

---

## Enum Mappings

### E-1: {EnumName}

**Source** ([{file}:{line}](../src/{file}#L{line})):

```{source_language}
{source enum definition}
```

**Rust Equivalent**:

```rust
{Rust enum with serde rename attributes for wire-format compatibility}
```

**Value Mapping**:

| Source Value | Rust Variant | Serialized As |
|-------------|-------------|---------------|
| {value} | {Variant} | "{wire_value}" |
| {value} | {Variant} | "{wire_value}" |

---

{Repeat for every enum}

---

## Union / Sum Type Mappings

### U-1: {UnionTypeName}

**Source** ([{file}:{line}](../src/{file}#L{line})):

```{source_language}
{source union type, e.g., type Result = Success | Failure | Pending}
```

**Rust Equivalent**:

```rust
{Rust enum with per-variant data, serde tag/content attributes for JSON compatibility}
```

**Discriminator Strategy**: {e.g., "serde(tag = \"type\", content = \"data\")" / "serde(untagged)" / "custom deserializer"}

---

{Repeat for every union type}

---

## Generic Type Mappings

### G-1: {GenericTypeName}<T>

**Source** ([{file}:{line}](../src/{file}#L{line})):

```{source_language}
{source generic type definition}
```

**Rust Equivalent**:

```rust
{Rust generic type with trait bounds}
```

**Trait Bounds**: {e.g., "T: Serialize + DeserializeOwned + Send + Sync + 'static"}

---

{Repeat for every generic type}

---

## Class-to-Struct Mappings

For source classes that have methods, the mapping involves splitting data (struct) from behavior (impl block or trait).

### C-1: {ClassName}

**Source** ([{file}:{line}](../src/{file}#L{line})):

```{source_language}
{source class with properties and methods}
```

**Rust Equivalent -- Data**:

```rust
{Rust struct with fields}
```

**Rust Equivalent -- Methods**:

```rust
impl {StructName} {
    {method signatures with return types}
}
```

**Rust Equivalent -- Trait** (if polymorphism is needed):

```rust
pub trait {TraitName} {
    {trait method signatures}
}

impl {TraitName} for {StructName} {
    {trait method implementations}
}
```

**Inheritance Resolution**: {e.g., "BaseClass fields are flattened into this struct" / "Shared behavior extracted into SharedTrait"}

---

{Repeat for every class}

---

## Type Alias Mappings

| # | Source Alias | Source Definition | Rust Equivalent | Notes |
|---|------------|------------------|-----------------|-------|
| A-1 | {AliasName} | `type X = string` | `type X = String` | Direct alias |
| A-2 | {AliasName} | `type ID = string` | `pub type Id = Uuid` | Semantic upgrade to Uuid |
| A-3 | {AliasName} | `type Handler = (req, res) => void` | `type Handler = fn(Request) -> Response` | Function type |
| ... | | | | |

## Constant Mappings

| # | Source Constant | Source File | Value | Rust Equivalent |
|---|----------------|------------|-------|-----------------|
| K-1 | {CONST_NAME} | [{file}:{line}](../src/{file}#L{line}) | {value} | `pub const {CONST_NAME}: {type} = {value};` |
| K-2 | {CONST_NAME} | [{file}:{line}](../src/{file}#L{line}) | {value} | `pub const {CONST_NAME}: {type} = {value};` |
| ... | | | | |

## Shared Derive Macros

Standard derive patterns used across all types:

| Pattern | Derives | When to Use |
|---------|---------|-------------|
| API Response | `#[derive(Debug, Clone, Serialize, Deserialize)]` | Types returned in HTTP responses |
| API Input | `#[derive(Debug, Deserialize, Validate)]` | Types received in HTTP requests |
| Database Row | `#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]` | Types read from database |
| Internal | `#[derive(Debug, Clone)]` | Types used only internally |
| Enum (string) | `#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]` | String-backed enums |
| Enum (int) | `#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize_repr, Deserialize_repr)]` | Integer-backed enums |

## Common Serde Patterns

```rust
// camelCase JSON fields with snake_case Rust fields
#[serde(rename_all = "camelCase")]

// Optional fields omitted from JSON when None
#[serde(skip_serializing_if = "Option::is_none")]

// Default value for missing fields
#[serde(default)]
#[serde(default = "default_fn")]

// Flatten nested struct
#[serde(flatten)]

// Rename single field
#[serde(rename = "type")]

// Custom serialization
#[serde(serialize_with = "custom_fn")]
#[serde(deserialize_with = "custom_fn")]

// Tagged enum for discriminated unions
#[serde(tag = "type", content = "data")]

// Untagged enum for untagged unions
#[serde(untagged)]
```

## Migration Order (Types)

Types must be migrated in dependency order. If type A references type B, type B must be defined first.

| Phase | Types | Rationale |
|-------|-------|-----------|
| 1 | {T-1, T-2, E-1, ...} | Leaf types with no type dependencies |
| 2 | {T-5, T-6, ...} | Types depending on Phase 1 types |
| 3 | {T-10, G-1, ...} | Types depending on Phase 1-2 types |
| ... | | |
```

## Instructions

When producing this document:

1. **Read `analysis/type-catalog.md`** for the complete inventory of all types found in the source.
2. **Read `mappings/module-mapping.md`** to know which Rust crate/module each type belongs to.
3. **ENUMERATE EVERY TYPE**. This is the cardinal rule. If the source has 47 interfaces, all 47 appear with before/after code blocks. No exceptions. No "and 15 more similar types".
4. **Source code must be exact**: Copy the source type definition verbatim, including comments. Reference the exact file:line.
5. **Rust code must compile**: Include all necessary derive macros, use statements, and type annotations. A developer should be able to copy the Rust code into a file and have it compile with the correct dependencies.
6. **Field-by-field conversion notes**: For every field that changes type (e.g., `string | null` -> `Option<String>`, `Date` -> `DateTime<Utc>`), document the change.
7. **serde attributes must be specified**: If the source uses camelCase in JSON, add `#[serde(rename_all = "camelCase")]`. If fields are optional in JSON, add `#[serde(skip_serializing_if = "Option::is_none")]`.
8. **Dependencies between types must be tracked**: If `Task` references `User`, note that `User` must be defined before `Task`.
9. **Usage count matters**: Types used in 20+ files are migration-critical. Types used in 1 file may be candidates for inlining.
10. **Classes with methods** must be split into struct (data) + impl block (methods) + trait (if polymorphism is needed).
11. **If the document exceeds 500 lines**, split into `type-mapping.md` (summary + first batch) and `type-mapping-continued.md` (remaining types).
12. Write in the same language the user used to invoke the skill.

## Example

```markdown
# Type Mapping

Source: taskflow-api
Generated: 2026-03-05
Source Language: TypeScript

## Summary

| Metric | Count |
|--------|-------|
| Total Types | 32 |
| Interfaces / Structs | 18 |
| Enums | 5 |
| Type Aliases | 4 |
| Generic Types | 3 |
| Union / Sum Types | 1 |
| Constants / Config | 1 |
| Classes (with methods) | 0 |

## Type Mapping Index

| # | Source Type | Source File | Rust Type | Rust Location | Complexity | Dependencies | Usage Count |
|---|-----------|------------|-----------|---------------|------------|--------------|-------------|
| T-1 | User | [models/user.ts:5](../src/models/user.ts#L5) | User | crates/core/src/types.rs | Moderate | T-8 (Role) | 23 files |
| T-2 | CreateUserInput | [models/user.ts:18](../src/models/user.ts#L18) | CreateUserInput | crates/core/src/types.rs | Moderate | - | 4 files |
| T-3 | Task | [models/task.ts:12](../src/models/task.ts#L12) | Task | crates/core/src/types.rs | Moderate | T-4, T-5, T-1 | 18 files |
| T-4 | TaskStatus | [models/task.ts:1](../src/models/task.ts#L1) | TaskStatus | crates/core/src/types.rs | Direct | - | 12 files |
| T-5 | Priority | [models/common.ts:1](../src/models/common.ts#L1) | Priority | crates/core/src/types.rs | Direct | - | 9 files |
| T-6 | PaginationParams | [models/common.ts:12](../src/models/common.ts#L12) | PaginationParams | crates/core/src/types.rs | Direct | - | 7 files |
| T-7 | PaginatedResponse<T> | [models/common.ts:18](../src/models/common.ts#L18) | PaginatedResponse<T> | crates/core/src/types.rs | Moderate | - | 7 files |
| T-8 | Role | [models/user.ts:1](../src/models/user.ts#L1) | Role | crates/core/src/types.rs | Direct | - | 8 files |

## Detailed Type Mappings

### T-1: User

**Source** ([models/user.ts:5](../src/models/user.ts#L5)):

```typescript
export interface User {
  id: string;
  name: string;
  email: string;
  role: Role;
  avatarUrl: string | null;
  bio: string | null;
  isActive: boolean;
  lastLoginAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}
```

**Rust Equivalent** (crates/core/src/types.rs):

```rust
/// A registered user in the system.
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub role: Role,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bio: Option<String>,
    pub is_active: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_login_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

**Conversion Notes**:
- `id: string` -> `id: Uuid` -- semantic upgrade; source uses UUID strings, Rust uses typed Uuid
- `role: Role` -> `role: Role` -- depends on enum T-8 (Role)
- `avatarUrl: string | null` -> `avatar_url: Option<String>` -- nullable becomes Option
- `bio: string | null` -> `bio: Option<String>` -- nullable becomes Option
- `lastLoginAt: Date | null` -> `last_login_at: Option<DateTime<Utc>>` -- nullable Date becomes Option<DateTime>
- `createdAt: Date` -> `created_at: DateTime<Utc>` -- Date becomes chrono::DateTime<Utc>
- `serde(rename_all = "camelCase")` preserves JSON wire format compatibility
- `sqlx::FromRow` enables direct database query deserialization
- `skip_serializing_if` omits null fields from JSON output (matches Express behavior)

**Dependencies**: T-8 (Role)

**Used by**: 23 files -- [services/user-service.ts](../src/services/user-service.ts), [routes/users.ts](../src/routes/users.ts), [middleware/auth.ts](../src/middleware/auth.ts), [services/task-service.ts](../src/services/task-service.ts), (+19 more)

**Migration Order**: Phase 1 (after T-8 Role is defined)

---

### T-2: CreateUserInput

**Source** ([models/user.ts:18](../src/models/user.ts#L18)):

```typescript
export const createUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  password: z.string().min(8).max(128),
  role: z.nativeEnum(Role).optional().default(Role.MEMBER),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
```

**Rust Equivalent** (crates/core/src/types.rs):

```rust
/// Input for creating a new user. Validated on deserialization.
#[derive(Debug, Deserialize, Validate)]
#[serde(rename_all = "camelCase")]
pub struct CreateUserInput {
    #[validate(length(min = 1, max = 100))]
    pub name: String,

    #[validate(email)]
    pub email: String,

    #[validate(length(min = 8, max = 128))]
    pub password: String,

    #[serde(default = "Role::default")]
    pub role: Role,
}

impl Default for Role {
    fn default() -> Self {
        Role::Member
    }
}
```

**Conversion Notes**:
- Zod schema `z.string().min(1).max(100)` -> `#[validate(length(min = 1, max = 100))]`
- Zod schema `z.string().email()` -> `#[validate(email)]`
- `z.nativeEnum(Role).optional().default(Role.MEMBER)` -> `#[serde(default = "Role::default")]` + `impl Default`
- No `Serialize` derive -- this type is input-only (deserialized from request, never serialized)
- No `sqlx::FromRow` -- this type is never read from database

**Dependencies**: T-8 (Role)

**Used by**: 4 files -- [routes/users.ts](../src/routes/users.ts), [services/user-service.ts](../src/services/user-service.ts), [tests/users.test.ts](../src/tests/users.test.ts), [routes/auth.ts](../src/routes/auth.ts)

**Migration Order**: Phase 1 (after T-8 Role is defined)

---

### T-4: TaskStatus (Enum)

**Source** ([models/task.ts:1](../src/models/task.ts#L1)):

```typescript
export enum TaskStatus {
  TODO = "TODO",
  IN_PROGRESS = "IN_PROGRESS",
  IN_REVIEW = "IN_REVIEW",
  DONE = "DONE",
  CANCELLED = "CANCELLED",
}
```

**Rust Equivalent** (crates/core/src/types.rs):

```rust
/// Status of a task in the workflow.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
#[sqlx(type_name = "task_status", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TaskStatus {
    Todo,
    InProgress,
    InReview,
    Done,
    Cancelled,
}
```

**Value Mapping**:

| Source Value | Rust Variant | Serialized As |
|-------------|-------------|---------------|
| "TODO" | TaskStatus::Todo | "TODO" |
| "IN_PROGRESS" | TaskStatus::InProgress | "IN_PROGRESS" |
| "IN_REVIEW" | TaskStatus::InReview | "IN_REVIEW" |
| "DONE" | TaskStatus::Done | "DONE" |
| "CANCELLED" | TaskStatus::Cancelled | "CANCELLED" |

**Conversion Notes**:
- `serde(rename_all = "SCREAMING_SNAKE_CASE")` preserves wire format
- `sqlx::Type` with `type_name = "task_status"` maps to PostgreSQL custom enum type
- `Copy` is derived because this is a simple enum with no data

**Dependencies**: None (leaf type)

**Used by**: 12 files

**Migration Order**: Phase 1 (leaf type, no dependencies)

---

### T-7: PaginatedResponse<T> (Generic)

**Source** ([models/common.ts:18](../src/models/common.ts#L18)):

```typescript
export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}
```

**Rust Equivalent** (crates/core/src/types.rs):

```rust
/// Generic paginated response wrapper.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PaginatedResponse<T: Serialize> {
    pub data: Vec<T>,
    pub total: i64,
    pub page: i64,
    pub page_size: i64,
    pub total_pages: i64,
}

impl<T: Serialize> PaginatedResponse<T> {
    pub fn new(data: Vec<T>, total: i64, page: i64, page_size: i64) -> Self {
        let total_pages = (total + page_size - 1) / page_size;
        Self {
            data,
            total,
            page,
            page_size,
            total_pages,
        }
    }
}
```

**Trait Bounds**: `T: Serialize` -- required for JSON serialization of the response.

**Conversion Notes**:
- `T[]` -> `Vec<T>` -- array becomes Vec
- `number` -> `i64` -- TypeScript number (float64) becomes i64 for pagination counts
- Added constructor method `new()` to calculate `total_pages` automatically

**Dependencies**: None

**Used by**: 7 files

**Migration Order**: Phase 1 (leaf generic type)
```

## Quality Criteria

- [ ] EVERY type definition in the source codebase has a mapping entry (no omissions)
- [ ] Each type has both a source code block and a Rust code block (before/after)
- [ ] Source code is copied verbatim with exact file:line reference
- [ ] Rust code includes all necessary derive macros and serde attributes
- [ ] Rust code would compile given the correct crate dependencies
- [ ] Field-by-field conversion notes explain every type change
- [ ] Nullable fields correctly use Option<T>
- [ ] serde rename attributes preserve JSON wire format compatibility
- [ ] Enums have a value mapping table showing source value -> Rust variant -> serialized form
- [ ] Generic types specify trait bounds
- [ ] Classes are split into struct + impl block + trait (where applicable)
- [ ] Dependencies between types are tracked (which types reference which)
- [ ] Usage count is provided for each type
- [ ] Migration order follows type dependency graph (leaf types first)
- [ ] Summary statistics are accurate
- [ ] Document is split if exceeding 500 lines (type-mapping.md + type-mapping-continued.md)
