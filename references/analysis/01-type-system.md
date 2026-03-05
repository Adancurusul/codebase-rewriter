# 01 - Type System Analysis

**Output**: `.migration-plan/analysis/type-catalog.md`

Catalog every type definition in the source codebase.

## Method

1. Grep for type definitions:
   - TS: `interface\s+\w+`, `type\s+\w+\s*=`, `enum\s+\w+`, `class\s+\w+`
   - Python: `class\s+\w+`, `@dataclass`, `TypedDict`, `NamedTuple`
   - Go: `type\s+\w+\s+struct`, `type\s+\w+\s+interface`
2. For EACH type found: read its definition, count references, note dependencies on other types
3. Identify special patterns: discriminated unions, self-referential types, circular references, generic types with complex bounds
4. Rate migration complexity: Low (direct mapping) / Medium (needs redesign) / High (no equivalent)

## Template

```markdown
# Type Catalog

Total types: {N} | Low: {N} | Medium: {N} | High: {N}

## Type #{n}: {TypeName}

- **Source**: [{file}:{line}](../src/{file}#L{line})
- **Kind**: interface / class / enum / type alias / dataclass / struct
- **Fields**: {count}
- **Referenced by**: {list of files}
- **Depends on**: {list of other types}
- **Complexity**: Low / Medium / High
- **Notes**: {anything unusual for Rust migration}

### Definition
\`\`\`{lang}
{exact source definition}
\`\`\`

{repeat for EVERY type}

## Special Patterns

| Category | Type | Details |
|----------|------|---------|
| Discriminated union | {TypeName} | Discriminant: {field name} |
| Self-referential | {TypeName} | {field}: {TypeName}[] |
| Circular reference | {TypeA} <-> {TypeB} | {A.field} -> {B.field} -> {A} |
| Generic (complex) | {TypeName}<T> | T extends/bound: {constraint} |
{EVERY special pattern}

## Dependency Order

{topological sort: types with no dependencies first}
```
