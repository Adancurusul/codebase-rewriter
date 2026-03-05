# 15 - Pattern Mapping

**Output**: `.migration-plan/mappings/pattern-transforms.md`

Map every source design pattern to its Rust equivalent.

## Method

1. Read `.migration-plan/analysis/architecture.md` -- get design pattern list
2. Read `ref/{language}.md` -- consult the Common Pattern Transforms section
3. For EACH design pattern found:
   a. Identify the Rust equivalent (see ref table)
   b. Note structural changes needed
   c. Rate migration complexity
4. Also map language-specific idioms:
   - TS: decorators, DI, middleware chain, barrel exports
   - Python: context managers, generators, comprehensions, dunder methods
   - Go: struct embedding, defer, init(), functional options, iota

## Template

```markdown
# Pattern Transforms

Patterns found: {N}

## Pattern #{n}: {PatternName}

- **Source**: {where in code and what it looks like}
- **Category**: architectural / behavioral / structural / idiom
- **Rust equivalent**: {what to use instead}
- **Complexity**: Low / Medium / High
- **Affected files**: {list}

### Current
{brief description of how it works now}

### Migration Strategy
{brief description of how to implement in Rust}

{repeat for EVERY pattern}

## Summary Table

| Pattern | Source | Rust Equivalent | Complexity |
|---------|--------|-----------------|-----------|
| DI container | inversify | manual Arc<dyn Trait> wiring | Medium |
| Decorator auth | @Auth() | axum middleware::from_fn | Medium |
| Repository pattern | UserRepo class | trait + impl | Low |
| Event bus | EventEmitter | tokio broadcast channel | Medium |
{EVERY pattern}
```
