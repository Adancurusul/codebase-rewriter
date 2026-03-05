# 02 - Error Handling Pattern Analysis

**Output**: `.migration-plan/analysis/error-patterns.md`

## Purpose

Catalog every error handling pattern in the source codebase. Rust replaces exceptions with `Result<T, E>` and panics, making error handling one of the most transformative aspects of migration. This analysis must capture:

- Every try/catch block and what errors it handles
- Every custom error class/type
- Every error propagation path (throw, raise, return err)
- Every error recovery pattern (retry, fallback, default value)
- Whether errors are recoverable (map to `Result`) or fatal (map to `panic!`)

The output feeds Phase 2's error hierarchy design, where a unified Rust error type tree is constructed.

## Method

### Step 1: Find all error handling sites

Use Grep to locate every error handling construct in the codebase.

**TypeScript/JavaScript**:
```
Grep: try\s*\{                                    (try blocks)
Grep: \}\s*catch\s*\(                             (catch blocks)
Grep: \}\s*finally\s*\{                           (finally blocks)
Grep: \.catch\(                                    (Promise catch handlers)
Grep: throw\s+new\s+\w+                           (throw statements with new)
Grep: throw\s+\w+                                  (throw statements with variables)
Grep: Promise\.reject\(                            (Promise rejections)
Grep: \.then\(.*,\s*\(?err                        (then error callbacks)
Grep: process\.exit\(                              (process termination)
Grep: console\.(error|warn)\(                     (error logging)
Grep: class\s+\w+\s+extends\s+(Error|TypeError|RangeError)  (custom error classes)
Grep: \.status\(\d{3}\)                           (HTTP error responses)
Grep: new\s+(Error|TypeError|RangeError|Custom\w*Error)\(   (error construction)
```

**Python**:
```
Grep: \btry\s*:                                    (try blocks)
Grep: \bexcept\s+                                  (except clauses)
Grep: \bexcept\s*:                                 (bare except)
Grep: \bfinally\s*:                                (finally blocks)
Grep: \braise\s+\w+                                (raise statements)
Grep: \braise\s*$                                  (bare raise / re-raise)
Grep: class\s+\w+(Error|Exception)\(               (custom exception classes)
Grep: logging\.(error|warning|exception)\(         (error logging)
Grep: sys\.exit\(                                   (process termination)
Grep: assert\s+                                     (assertions)
Grep: HTTPException\(|abort\(                       (HTTP error responses)
Grep: @app\.exception_handler|@app\.errorhandler    (error handler decorators)
```

**Go**:
```
Grep: if\s+err\s*!=\s*nil                          (error checks)
Grep: return\s+.*,?\s*err\b                        (error returns)
Grep: return\s+.*,?\s*fmt\.Errorf\(                (formatted errors)
Grep: errors\.New\(                                 (error construction)
Grep: fmt\.Errorf\(                                 (wrapped errors)
Grep: errors\.Is\(|errors\.As\(                    (error matching)
Grep: errors\.Wrap\(|errors\.Wrapf\(               (pkg/errors wrapping)
Grep: panic\(                                       (panics)
Grep: recover\(\)                                   (panic recovery)
Grep: log\.(Fatal|Panic)\(                          (fatal logging)
Grep: type\s+\w+Error\s+struct|type\s+\w+\s+error  (custom error types)
Grep: func\s+\(\w+\s+\*?\w+\)\s+Error\(\)\s+string (Error() method implementations)
```

### Step 2: Analyze each error handling site

For EACH try/catch, if-err, or except block found:

#### A. Location
- **File**: path with line range `[file.ts:15-25](../src/file.ts#L15-L25)`
- **Function/Method**: which function contains this error handling
- **Context**: what operation is being protected (DB query, HTTP call, file I/O, parsing, validation)

#### B. Error Source
- **What can fail**: the specific operation in the try block or before the error check
- **Error types caught**: specific types (e.g., `catch (e: TypeError)`) or generic (`catch (e)`)
- **Is the error type checked**: does the handler inspect the error type to decide action?

#### C. Recovery Strategy

Categorize EACH handler into exactly one pattern:

| Pattern | Description | Rust Equivalent |
|---------|-------------|-----------------|
| **Propagate** | Re-throw or return error to caller | `?` operator |
| **Propagate-Wrapped** | Wrap error with context, then propagate | `.map_err()` or `anyhow::Context` |
| **Recover-Default** | Use a default/fallback value on error | `.unwrap_or()` / `.unwrap_or_default()` |
| **Recover-Retry** | Retry the operation (with/without backoff) | Loop with `Result` match |
| **Recover-Fallback** | Try alternative approach | Match arms with fallback logic |
| **Log-and-Continue** | Log the error, continue execution | `if let Err(e) = ... { log::error!(...) }` |
| **Log-and-Abort** | Log the error, terminate process | `log::error!(...); std::process::exit(1)` |
| **Transform** | Convert to different error type (e.g., HTTP status) | `impl From<SourceError> for TargetError` |
| **Ignore** | Empty catch block or `_ =` in Go | Remove or add explicit handling |
| **Aggregate** | Collect multiple errors, report together | `Vec<Error>` pattern |

#### D. Severity Classification

| Severity | Description | Rust Mapping |
|----------|-------------|-------------|
| **Fatal** | Application cannot continue (missing config, DB unreachable at startup) | `panic!()` or `std::process::exit()` |
| **Recoverable** | Operation failed but app can continue (single request fails) | `Result<T, E>` with `?` propagation |
| **Validation** | Input validation failure (expected error path) | `Result<T, ValidationError>` |
| **Ignorable** | Non-critical failure (cache miss, optional feature unavailable) | `Option<T>` or log + continue |

### Step 3: Catalog custom error types

For EACH custom error class/type/struct:

- **Name**: error type name
- **File**: path with line number
- **Extends/Wraps**: parent error class or wrapped error type
- **Fields**: additional data carried by the error (error code, HTTP status, user message)
- **Used in**: list every throw/raise/return site that creates this error
- **Rust equivalent hint**: `thiserror` enum variant, `anyhow` context, or custom struct

### Step 4: Map error propagation chains

Trace how errors flow through the application. For each major error flow:

1. **Origin**: where the error is first created/thrown
2. **Intermediate handlers**: each catch/except/if-err that touches it
3. **Final handler**: where the error is ultimately handled (HTTP response, log, exit)

Document at least the 5 most important error propagation chains.

### Step 5: Identify error handling anti-patterns

Flag patterns that need redesign for Rust:

| Anti-Pattern | Description | Rust Fix |
|-------------|-------------|----------|
| **Empty catch** | `catch (e) {}` -- silently swallowing errors | Must handle or propagate with `?` |
| **Catch-all** | `catch (e: any)` -- no type discrimination | Use typed error enum variants |
| **String errors** | `throw "something failed"` | Use structured error types |
| **Error as control flow** | Using exceptions for normal branching | Use `Option<T>` or `Result<T, E>` |
| **Nested try/catch** | Deeply nested error handling | Flatten with `?` operator |
| **Global error state** | Setting global error flags | Return `Result<T, E>` |
| **Bare except** | Python `except:` catching everything including KeyboardInterrupt | Use specific error types |
| **Panic in library code** | Go `panic()` in non-main packages | Return `Result` |

### Step 6: Organize output

## Template

```markdown
# Error Handling Pattern Analysis

Generated: {date}
Source: {project_path}

## Summary

| Metric | Count |
|--------|-------|
| Total error handling sites | {N} |
| try/catch blocks (or if err != nil) | {N} |
| throw/raise/return-err statements | {N} |
| Custom error types | {N} |
| Promise .catch() handlers | {N} |
| Empty/silent catch blocks | {N} |
| process.exit / sys.exit / log.Fatal | {N} |

### Recovery Pattern Distribution

| Pattern | Count | % |
|---------|-------|---|
| Propagate | {N} | {N}% |
| Propagate-Wrapped | {N} | {N}% |
| Recover-Default | {N} | {N}% |
| Recover-Retry | {N} | {N}% |
| Recover-Fallback | {N} | {N}% |
| Log-and-Continue | {N} | {N}% |
| Log-and-Abort | {N} | {N}% |
| Transform | {N} | {N}% |
| Ignore | {N} | {N}% |
| Aggregate | {N} | {N}% |

### Severity Distribution

| Severity | Count | % |
|----------|-------|---|
| Fatal | {N} | {N}% |
| Recoverable | {N} | {N}% |
| Validation | {N} | {N}% |
| Ignorable | {N} | {N}% |

## Custom Error Types

### E-{nn}: {ErrorTypeName}

- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Extends**: {parent error type or "base Error"}
- **Fields**:
  | Field | Type | Purpose |
  |-------|------|---------|
  | message | string | Human-readable description |
  | code | string | Machine-readable error code |
  | statusCode | number | HTTP status code |
  | details | object | Additional context |
- **Thrown in**: {list every file:line where this error is created}
- **Caught in**: {list every file:line where this error is specifically caught}
- **Rust hint**: `thiserror` enum variant with fields

---

{Repeat for EVERY custom error type.}

## Error Handling Sites

### Category: {e.g., Database Operations}

#### EH-{nnn}: {function_name} in {file_path}

- **File**: [{file_path}:{line_range}](../{file_path}#L{start}-L{end})
- **Operation**: {what is being tried, e.g., "SELECT user by ID from PostgreSQL"}
- **Error types caught**: {specific types or "all"}
- **Recovery pattern**: {Propagate / Recover-Default / Transform / ...}
- **Severity**: {Fatal / Recoverable / Validation / Ignorable}
- **Handler action**: {what happens on error, e.g., "returns 404 JSON response"}
- **Rust mapping**: {e.g., "sqlx::Error -> map_err to AppError::NotFound, propagate with ?"}

---

{Repeat for EVERY error handling site. Group by category (Database, HTTP, Validation, File I/O, etc.)}

### Category: {HTTP/API Calls}

#### EH-{nnn}: {function_name} in {file_path}
{Same structure as above}

### Category: {Input Validation}

#### EH-{nnn}: {function_name} in {file_path}
{Same structure as above}

### Category: {File System}

#### EH-{nnn}: {function_name} in {file_path}
{Same structure as above}

## Error Propagation Chains

### Chain {n}: {description, e.g., "Database error to HTTP response"}

```
{origin_file}:{line} -- {ErrorType} created
    |
    v
{middleware_file}:{line} -- caught, wrapped with context
    |
    v
{handler_file}:{line} -- caught, transformed to HTTP 500
    |
    v
HTTP Response: { error: "Internal Server Error", code: "DB_ERROR" }
```

**Rust design**: {how this chain maps to Result propagation}

---

{Repeat for each major error chain.}

## Anti-Patterns Found

| # | Anti-Pattern | File | Line | Description | Fix Required |
|---|-------------|------|------|-------------|-------------|
| 1 | Empty catch | src/api/users.ts | 45 | Swallows database errors silently | Add proper error handling or propagate |
| 2 | String error | src/utils/parse.ts | 12 | `throw "invalid format"` | Create typed ParseError |
| 3 | Bare except | src/worker.py | 88 | `except:` catches SystemExit | Use `except Exception:` |
| ... | | | | | |

## Rust Error Architecture Hints

Based on the error patterns found, the recommended Rust error strategy is:

- **Error crate**: {thiserror / anyhow / custom / combination}
- **Top-level error enum**: {suggested name and variants based on error categories found}
- **Error conversion traits**: {which `From` impls will be needed}
- **HTTP error mapping**: {how errors map to response status codes}
- **Estimated error enum variants**: {N} (one per category of error)
```

## Completeness Check

- [ ] Every try/catch (or if-err, or except) block is listed individually
- [ ] Every throw/raise/return-err statement is listed individually
- [ ] Every custom error class/type is cataloged with its fields and usage sites
- [ ] Every error handling site has a recovery pattern classification
- [ ] Every error handling site has a severity classification
- [ ] Error propagation chains are traced for the major error flows
- [ ] Anti-patterns are identified with specific file and line references
- [ ] No error handling sites are summarized as "and N more similar patterns"
- [ ] Empty/silent catch blocks are explicitly flagged
- [ ] Rust error architecture hints are provided based on findings
