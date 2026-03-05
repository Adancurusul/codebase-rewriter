# 02 - Error Handling Analysis

**Output**: `.migration-plan/analysis/error-patterns.md`

Catalog every error handling pattern in the source codebase.

## Method

1. Grep for error patterns:
   - TS: `throw\s+new`, `catch\s*\(`, `extends\s+Error`, `.catch(`
   - Python: `raise\s+`, `except\s+`, `class\s+\w+.*Exception`, `class\s+\w+.*Error`
   - Go: `errors\.New`, `fmt\.Errorf`, `if\s+err\s*!=\s*nil`, `type\s+\w+Error`
2. For EACH error type/pattern: identify where thrown, where caught, what info it carries
3. Classify: typed error / string error / wrapped error / ignored error / panic

## Template

```markdown
# Error Patterns

Total patterns: {N} | Custom error types: {N} | Untyped throws: {N}

## Custom Error Types

| Error Type | Source | Fields | HTTP Status | Used In |
|-----------|--------|--------|------------|---------|
| NotFoundError | [errors.ts:5](../src/errors.ts#L5) | message, entity | 404 | users, orders |
| ValidationError | [errors.ts:15](../src/errors.ts#L15) | message, field, value | 400 | middleware |
{EVERY custom error type}

## Error Flow Patterns

### Pattern #{n}: {description}
- **Throw site**: [{file}:{line}](../src/{file}#L{line})
- **Catch site**: [{file}:{line}](../src/{file}#L{line})
- **Category**: typed / string / wrapped / ignored
- **Info carried**: {what data travels with the error}

{repeat for EVERY distinct pattern}

## Anti-patterns

| Pattern | Location | Issue |
|---------|----------|-------|
| Swallowed error | [file:line] | catch block ignores error |
| String-only throw | [file:line] | No error type, just string |
```
