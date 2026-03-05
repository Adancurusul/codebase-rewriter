# 01 - Deep Type System Analysis

**Output**: `.migration-plan/analysis/type-catalog.md`

## Purpose

Catalog every type definition in the source codebase: every interface, type alias, class, struct, enum, and data model. This is the single most important analysis for Rust migration because:

- Rust's type system is stricter and more expressive. Every source type must be consciously mapped.
- Ownership and borrowing decisions depend on understanding how types are used (passed by reference? cloned? shared across threads?).
- Nullable/optional fields must be identified for `Option<T>` mapping.
- Inheritance hierarchies must be redesigned as trait + struct compositions.
- Generic types must be evaluated for Rust's monomorphized generics.

The type catalog feeds directly into Phase 2's type mapping guide, which produces the actual Rust struct/enum/trait definitions.

## Method

### Step 1: Find all type definitions

Use Grep to locate every type definition in the codebase.

**TypeScript/JavaScript**:
```
Grep: ^export\s+(interface|type|class|enum|const enum|abstract class)\s+\w+
Grep: ^(interface|type|class|enum)\s+\w+
Grep: z\.object\(|z\.enum\(|z\.union\(          (Zod schemas as types)
Grep: @Schema|@Entity|@model|@ObjectType        (decorator-based type definitions)
Grep: as const                                   (const assertions creating literal types)
Grep: = createSelectSchema|= createInsertSchema  (Drizzle ORM schemas)
Grep: Prisma model definitions in schema.prisma
```

**Python**:
```
Grep: ^class\s+\w+
Grep: @dataclass|@dataclass_transform
Grep: class\s+\w+\(BaseModel\)                  (Pydantic models)
Grep: class\s+\w+\(TypedDict\)                  (TypedDict definitions)
Grep: \w+\s*=\s*TypeVar\(                        (TypeVar definitions)
Grep: \w+\s*=\s*NewType\(                        (NewType definitions)
Grep: \w+\s*=\s*Union\[|Optional\[               (type aliases)
Grep: class\s+\w+\(Enum\)|class\s+\w+\(IntEnum\) (enum classes)
Grep: class\s+\w+\(.*Model\)                     (Django/SQLAlchemy models)
Grep: @strawberry\.type|@strawberry\.input        (Strawberry GraphQL types)
```

**Go**:
```
Grep: ^type\s+\w+\s+struct
Grep: ^type\s+\w+\s+interface
Grep: ^type\s+\w+\s+(int|string|float|bool|byte|\[\])  (type aliases)
Grep: ^type\s+\w+\s+func\(                              (function types)
Grep: const\s*\(\s*\n\s*\w+.*iota                       (iota enums)
```

### Step 2: Analyze each type definition

For EACH type found, read the full definition and extract:

#### A. Basic Information
- **Name**: Exact type name as declared
- **Kind**: interface / type alias / class / struct / enum / union / intersection / generic / decorator-based
- **File**: Path with line number `[file.ts:15](../src/file.ts#L15)`
- **Exported**: Yes / No (is it part of the public API?)

#### B. Fields and Members

For EACH field/property/member of the type:
- **Field name**
- **Field type** (exact source type as written)
- **Optional**: Yes / No (marked with `?` in TS, `Optional[]` in Python, pointer in Go)
- **Default value**: if any
- **Validation**: any constraints (decorators, Zod refinements, struct tags)
- **Rust type hint**: initial mapping (e.g., `string` -> `String`, `number | null` -> `Option<f64>`)

#### C. Relationships

- **Extends/Inherits**: what types does this extend? (parent classes, extended interfaces)
- **Implements**: what interfaces/protocols does this implement?
- **Contains**: what other project-defined types appear as fields? (creates dependency ordering)
- **Used by**: which other types reference this type as a field?
- **Generic parameters**: any type parameters and their constraints

#### D. Behavioral Members (classes only)

- **Methods**: list each method with signature (name, params, return type)
- **Constructor**: parameter list and what it initializes
- **Static members**: static methods or properties
- **Getters/Setters**: computed properties

#### E. Migration Complexity Rating

Rate EACH type:

| Rating | Criteria |
|--------|----------|
| **Simple** | Flat data struct, no methods, no inheritance, no generics. Direct `struct` mapping. |
| **Moderate** | Has optional fields, simple generics, or implements one interface. Needs `Option<T>` or one trait impl. |
| **Complex** | Has inheritance, multiple generics, decorators, or complex union types. Needs trait redesign. |
| **Requires-Redesign** | Deep inheritance hierarchy, mixin patterns, dynamic typing, or reflection-based. Architecture change needed. |

### Step 3: Identify type categories

Group the cataloged types into functional categories:

| Category | Description | Examples |
|----------|-------------|---------|
| **Domain Models** | Core business entities | User, Order, Product |
| **DTOs / API Types** | Request/response shapes | CreateUserRequest, ApiResponse |
| **Database Models** | ORM/schema types | UserEntity, user_table |
| **Config Types** | Configuration structures | AppConfig, DatabaseConfig |
| **Error Types** | Custom error classes/types | AppError, ValidationError |
| **Utility Types** | Helper/generic types | Paginated<T>, Result<T> |
| **State Types** | Application state | AppState, StoreState |
| **Event Types** | Event/message definitions | UserCreatedEvent, Message |

### Step 4: Identify type patterns requiring special attention

Scan for patterns that are challenging in Rust:

- **Discriminated unions**: `type Shape = Circle | Square` -- map to Rust enum
- **Intersection types**: `type A = B & C` -- map to struct composition or trait bounds
- **Mapped types**: `Record<K, V>`, `Partial<T>`, `Pick<T, K>` -- map to HashMap/Option wrapping
- **Conditional types**: `T extends U ? X : Y` -- may need trait specialization
- **Index signatures**: `[key: string]: any` -- map to HashMap
- **Self-referential types**: `type Tree = { children: Tree[] }` -- needs `Box<T>` or `Rc<T>`
- **Union with None/null**: nullable fields -- map to `Option<T>`
- **Dynamic dispatch**: interface types used as function parameters -- `dyn Trait` or generics
- **Circular references**: Type A references Type B which references Type A -- needs `Rc<RefCell<T>>` or redesign

### Step 5: Organize output

Compile everything into the template below. Every type gets its own entry. If there are more than 50 types, split into multiple sections by category but still list every single one.

## Template

```markdown
# Type System Catalog

Generated: {date}
Source: {project_path}

## Summary

| Metric | Count |
|--------|-------|
| Total type definitions | {N} |
| Interfaces / Protocols | {N} |
| Classes | {N} |
| Type aliases | {N} |
| Enums | {N} |
| Structs (Go) | {N} |
| Generic types | {N} |
| Union / Intersection types | {N} |

### Migration Complexity Distribution

| Rating | Count | % |
|--------|-------|---|
| Simple | {N} | {N}% |
| Moderate | {N} | {N}% |
| Complex | {N} | {N}% |
| Requires-Redesign | {N} | {N}% |

## Type Catalog

### Domain Models

#### T-{nn}: {TypeName}

- **Kind**: {interface / class / type alias / struct}
- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Exported**: {Yes / No}
- **Complexity**: {Simple / Moderate / Complex / Requires-Redesign}
- **Generic params**: {none / <T extends Foo>}
- **Extends**: {none / ParentType}
- **Implements**: {none / InterfaceName}

**Fields**:

| Field | Source Type | Optional | Default | Rust Type Hint |
|-------|-----------|----------|---------|----------------|
| id | string | No | - | Uuid |
| name | string | No | - | String |
| email | string \| null | Yes | null | Option<String> |
| role | UserRole | No | "user" | UserRole (enum) |
| created_at | Date | No | - | chrono::DateTime<Utc> |
| metadata | Record<string, any> | Yes | {} | Option<HashMap<String, serde_json::Value>> |

**Methods** (if class):

| Method | Params | Return | Notes |
|--------|--------|--------|-------|
| validate() | - | boolean | Move to trait impl or standalone fn |
| toJSON() | - | object | Derive Serialize |
| clone() | - | User | Derive Clone |

**Referenced by**: {list types that use this type as a field}
**References**: {list project types used as fields}

**Migration notes**: {specific notes for this type, e.g., "Self-referential via `manager: User`, will need Option<Box<User>> or ID reference"}

---

{Repeat for EVERY type. Use --- separator between types.}

### DTOs / API Types

#### T-{nn}: {TypeName}
{Same structure as above}

### Database Models

#### T-{nn}: {TypeName}
{Same structure as above}

### Config Types

#### T-{nn}: {TypeName}
{Same structure as above}

### Error Types

#### T-{nn}: {TypeName}
{Same structure as above}

### Utility Types

#### T-{nn}: {TypeName}
{Same structure as above}

### Enums

#### T-{nn}: {EnumName}

- **Kind**: enum
- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Exported**: {Yes / No}
- **Complexity**: {Simple / Moderate}

**Variants**:

| Variant | Value | Rust Mapping |
|---------|-------|-------------|
| Admin | "admin" | Admin |
| User | "user" | User |
| Guest | "guest" | Guest |

**Migration notes**: {e.g., "String enum -> Rust enum with Serialize/Deserialize"}

---

{Repeat for every enum.}

## Special Patterns

### Discriminated Unions

| # | Source Type | Discriminant | Variants | Rust Mapping |
|---|-----------|-------------|----------|-------------|
| 1 | Shape | kind | Circle, Square, Triangle | enum Shape { Circle {...}, Square {...}, Triangle {...} } |
| 2 | Event | type | Click, Hover, Scroll | enum Event { Click {...}, Hover {...}, Scroll {...} } |

### Self-Referential Types

| # | Type | Self-Reference Field | Rust Strategy |
|---|------|---------------------|---------------|
| 1 | TreeNode | children: TreeNode[] | Vec<Box<TreeNode>> |
| 2 | LinkedList | next: LinkedList \| null | Option<Box<LinkedList>> |

### Circular References

| # | Type A | Type B | Reference Path | Rust Strategy |
|---|--------|--------|---------------|---------------|
| 1 | User | Organization | User.org -> Org.members -> User | Break cycle: use ID references or Rc<RefCell<T>> |

### Generic Types

| # | Type | Params | Constraints | Rust Mapping |
|---|------|--------|------------|-------------|
| 1 | Paginated<T> | T | - | Paginated<T> (direct) |
| 2 | Repository<T> | T extends Entity | T: Entity | Repository<T: Entity> with trait bound |

## Type Dependency Order

List types in dependency order (types with no dependencies first):

1. {TypeA} (no dependencies)
2. {TypeB} (no dependencies)
3. {TypeC} (depends on TypeA)
4. {TypeD} (depends on TypeA, TypeB)
5. {TypeE} (depends on TypeC, TypeD)
...

{This ordering informs the migration sequence: migrate leaf types first.}
```

## Completeness Check

- [ ] Every type definition in the codebase is cataloged (not "found N types")
- [ ] Every field of every type is listed with its source type and Rust type hint
- [ ] Every method of every class is listed with its signature
- [ ] Every type has a migration complexity rating
- [ ] Every type's relationships (extends, implements, contains, used-by) are documented
- [ ] Every enum has all variants listed
- [ ] Special patterns (unions, self-referential, circular, generics) are identified and cataloged
- [ ] Types are organized by functional category
- [ ] A dependency order is provided for migration sequencing
- [ ] File paths include line numbers and are formatted as links
- [ ] No type is summarized as "similar to above" or "and N more types"
