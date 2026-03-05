# 10 - Type Mapping

**Output**: `.migration-plan/mappings/type-mapping.md`

Map every source type to a concrete Rust equivalent with compilable code.

## Method

1. Read `.migration-plan/analysis/type-catalog.md` -- get the complete type list
2. Read `ref/{language}.md` -- consult the Type Mapping Table for primitive conversions
3. For EACH type in the catalog:
   a. Determine Rust equivalent (struct, enum, trait, type alias)
   b. Add derive macros: `Debug, Clone, Serialize, Deserialize` minimum
   c. Add serde attributes for field renaming (camelCase -> snake_case)
   d. Note which crates are needed (uuid, chrono, serde, etc.)
   e. Determine migration order based on type dependencies
4. For class hierarchies: flatten inheritance into composition + trait implementations
5. For union/sum types: create Rust enum with typed variants
6. Write output with EVERY type mapped

## Template

```markdown
# Type Mapping

Source types: {N} | Mapped: {N}

## Type #{n}: {TypeName}

### Source ({language}) -- {file}:{line}
\`\`\`{lang}
{exact source definition}
\`\`\`

### Target (Rust)
\`\`\`rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeName {
    pub field: Type,
}
\`\`\`

### Notes
- {field conversion notes}
- Crates needed: {list}
- Referenced by: {N} files
- Depends on: {other types}

{repeat for EVERY type}

## Migration Order
1. {Type with no deps}
2. {Type depending on #1}
...
```

## Example

```markdown
## Type #1: UserRole

### Source (TypeScript) -- src/models/user.ts:3
\`\`\`typescript
type UserRole = "admin" | "user" | "viewer";
\`\`\`

### Target (Rust)
\`\`\`rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum UserRole { Admin, User, Viewer }
\`\`\`

### Notes
- String union -> enum with strum or serde rename
- Crates: serde
- Referenced by: 4 files
- Depends on: nothing
```
