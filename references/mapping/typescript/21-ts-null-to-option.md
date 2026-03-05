# 21 - TypeScript Null/Undefined to Rust Option/Result Mapping

**Output**: Contributes to `.migration-plan/mappings/type-mapping.md` (null/Option section)

## Purpose

Map every TypeScript null and undefined handling pattern to Rust's `Option<T>` and `Result<T, E>` types. TypeScript's `null` and `undefined` are pervasive -- optional parameters, nullable return values, optional chaining, nullish coalescing, non-null assertions, and strict null checks all require deliberate conversion. Every nullable access path in the source must be transformed into an explicit `Option<T>` or `Result<T, E>` with proper handling, eliminating the possibility of null reference errors at compile time.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- identifies all types with optional fields, nullable properties, and union types involving null/undefined
- `error-patterns.md` -- identifies patterns where null is used as an error signal vs. absent-value signal
- `architecture.md` -- identifies data flow paths where null propagation crosses module boundaries

Extract every instance of:
- `T | null` types
- `T | undefined` types
- `T | null | undefined` types
- Optional properties (`field?: T`)
- Optional parameters (`param?: T`)
- Optional chaining (`obj?.prop?.method()`)
- Nullish coalescing (`value ?? fallback`)
- Non-null assertions (`value!`)
- Type guards for null checks (`if (x !== null)`)
- `void` return types
- Functions that return `T | null` to signal "not found"

### Step 2: For each nullable pattern, determine Rust equivalent

**Core mapping rules:**

| TypeScript Pattern | Rust Equivalent | Notes |
|-------------------|-----------------|-------|
| `T \| null` | `Option<T>` | Most common mapping |
| `T \| undefined` | `Option<T>` | Same as null in Rust |
| `T \| null \| undefined` | `Option<T>` | Both collapse to `Option` |
| `field?: T` (optional property) | `Option<T>` | With `#[serde(skip_serializing_if)]` |
| `param?: T` (optional parameter) | `Option<T>` or `impl Into<Option<T>>` | Or use builder pattern |
| `obj?.prop` (optional chaining) | `.as_ref().map(\|o\| &o.prop)` or `.and_then()` | Chain with combinators |
| `value ?? fallback` (nullish coalescing) | `.unwrap_or(fallback)` | Or `.unwrap_or_else(\|\| ...)` |
| `value!` (non-null assertion) | `.unwrap()` | WARNING: panics; prefer `?` or `.expect()` |
| `if (x !== null) { x.foo }` | `if let Some(x) = x { x.foo }` | Pattern matching |
| `typeof x !== "undefined"` | `x.is_some()` | Boolean check |
| `void` return type | `()` unit type | Or `Result<(), E>` if it can fail |
| `T \| null` as "not found" | `Option<T>` or `Result<T, NotFoundError>` | Depends on whether caller should handle not-found |

**Decision tree for null-as-error vs. null-as-absent:**

```
Is null used to signal an error condition?
  YES -> Use Result<T, E> with a specific error variant
    Example: database query fails -> Result<T, DbError>
  NO ->
    Is null a valid "nothing here" value?
      YES -> Use Option<T>
        Example: optional profile picture -> Option<String>
      MAYBE (depends on context) ->
        Does the caller need to distinguish "not found" from "error"?
          YES -> Return Result<Option<T>, E>
            Example: find_user(id) -> Result<Option<User>, DbError>
          NO -> Return Result<T, E> with NotFound variant
```

**Serde configuration for optional fields:**

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserProfile {
    pub name: String,

    // Optional field: omitted from JSON when None
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bio: Option<String>,

    // Optional field with default: uses default if missing from input JSON
    #[serde(default)]
    pub tags: Vec<String>,

    // Optional field that must serialize as null (not omitted)
    #[serde(default)]
    pub deleted_at: Option<DateTime<Utc>>,

    // Optional field with custom default
    #[serde(default = "default_role")]
    pub role: String,
}

fn default_role() -> String {
    "viewer".to_string()
}
```

### Step 3: Produce nullability mapping document

For EACH nullable access path in the source, produce:
1. Source expression with file:line reference
2. Null semantics (error vs. absent vs. default)
3. Rust equivalent expression
4. Error handling strategy (if converting null to Result)

## Code Examples

### Example 1: Basic Null/Undefined to Option

**TypeScript:**
```typescript
interface Config {
  host: string;
  port: number;
  database: string;
  password: string | null;
  sslCert?: string;
  maxConnections: number | undefined;
}

function getPassword(config: Config): string | null {
  return config.password;
}

function getSslCert(config: Config): string | undefined {
  return config.sslCert;
}
```

**Rust:**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub database: String,
    pub password: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ssl_cert: Option<String>,
    pub max_connections: Option<u32>,
}

fn get_password(config: &Config) -> Option<&str> {
    config.password.as_deref()
}

fn get_ssl_cert(config: &Config) -> Option<&str> {
    config.ssl_cert.as_deref()
}
```

### Example 2: Optional Chaining to Combinators

**TypeScript:**
```typescript
interface Company {
  name: string;
  address?: {
    street: string;
    city: string;
    state?: string;
    zip: string;
  };
  ceo?: {
    name: string;
    email?: string;
  };
}

// Deep optional chaining
const ceoEmail = company?.ceo?.email;
const state = company?.address?.state?.toUpperCase();
const stateOrDefault = company?.address?.state ?? "N/A";

// Optional chaining with method calls
const emailDomain = company?.ceo?.email?.split("@")[1];
const cityLength = company?.address?.city?.length ?? 0;
```

**Rust:**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Company {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub address: Option<Address>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ceo: Option<Ceo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Address {
    pub street: String,
    pub city: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub state: Option<String>,
    pub zip: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ceo {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
}

// Deep optional chaining -> .as_ref().and_then()
let ceo_email: Option<&str> = company.ceo.as_ref()
    .and_then(|ceo| ceo.email.as_deref());

let state: Option<String> = company.address.as_ref()
    .and_then(|addr| addr.state.as_ref())
    .map(|s| s.to_uppercase());

// Nullish coalescing -> .unwrap_or / .unwrap_or_else
let state_or_default: &str = company.address.as_ref()
    .and_then(|addr| addr.state.as_deref())
    .unwrap_or("N/A");

// Optional chaining with method calls
let email_domain: Option<&str> = company.ceo.as_ref()
    .and_then(|ceo| ceo.email.as_deref())
    .and_then(|email| email.split('@').nth(1));

let city_length: usize = company.address.as_ref()
    .map(|addr| addr.city.len())
    .unwrap_or(0);
```

### Example 3: Non-Null Assertion to .unwrap() / .expect()

**TypeScript:**
```typescript
// Non-null assertion -- developer "guarantees" value is not null
const userId = getCurrentUser()!.id;

// After type guard -- safe usage
function processUser(user: User | null) {
  if (user === null) {
    throw new Error("User is required");
  }
  // TypeScript narrows type to User here
  console.log(user.name);
}

// Double-bang pattern for booleans
const isActive = !!user?.active;
```

**Rust:**
```rust
// Non-null assertion -> .expect() with descriptive message (AVOID .unwrap() in production)
let user_id = get_current_user()
    .expect("getCurrentUser should always return a user in authenticated context")
    .id;

// Preferred: propagate with ?
let user_id = get_current_user()
    .ok_or(AppError::Auth(AuthError::NotAuthenticated))?
    .id;

// Type guard -> if let / match
fn process_user(user: Option<User>) -> Result<(), AppError> {
    let user = user.ok_or_else(|| AppError::Validation(
        ValidationError::MissingField("user".into())
    ))?;
    println!("{}", user.name);
    Ok(())
}

// Alternative: match for explicit control
fn process_user_v2(user: Option<User>) -> Result<(), AppError> {
    match user {
        Some(user) => {
            println!("{}", user.name);
            Ok(())
        }
        None => Err(AppError::Validation(
            ValidationError::MissingField("user".into())
        )),
    }
}

// Double-bang -> .is_some_and() or .unwrap_or(false)
let is_active: bool = user.as_ref()
    .and_then(|u| u.active)
    .unwrap_or(false);
// Or in Rust 1.70+:
let is_active: bool = user.as_ref()
    .is_some_and(|u| u.active.unwrap_or(false));
```

### Example 4: Null Return as "Not Found" to Result<Option<T>, E>

**TypeScript:**
```typescript
async function findUserByEmail(email: string): Promise<User | null> {
  const user = await db.query("SELECT * FROM users WHERE email = $1", [email]);
  return user.rows[0] ?? null;
}

async function getUserOrThrow(id: string): Promise<User> {
  const user = await findUserById(id);
  if (!user) {
    throw new NotFoundError(`User ${id} not found`);
  }
  return user;
}

// Caller handles null
const user = await findUserByEmail("alice@example.com");
if (user) {
  await sendWelcomeEmail(user);
}
```

**Rust:**
```rust
// "Not found" returns Option -- separates "not found" from "database error"
async fn find_user_by_email(
    pool: &PgPool,
    email: &str,
) -> Result<Option<User>, DbError> {
    let user = sqlx::query_as::<_, User>(
        "SELECT * FROM users WHERE email = $1"
    )
    .bind(email)
    .fetch_optional(pool)
    .await
    .map_err(DbError::from)?;

    Ok(user)
}

// "Must exist" converts Option to Result with NotFound error
async fn get_user_or_error(
    pool: &PgPool,
    id: Uuid,
) -> Result<User, AppError> {
    find_user_by_id(pool, id)
        .await?
        .ok_or_else(|| AppError::NotFound {
            resource: "user",
            id: id.to_string(),
        })
}

// Caller handles Option
let user = find_user_by_email(&pool, "alice@example.com").await?;
if let Some(user) = user {
    send_welcome_email(&user).await?;
}
```

### Example 5: Optional Function Parameters

**TypeScript:**
```typescript
interface SearchOptions {
  query: string;
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
  filters?: Record<string, string>;
}

async function searchUsers(options: SearchOptions): Promise<PaginatedResponse<User>> {
  const page = options.page ?? 1;
  const pageSize = options.pageSize ?? 20;
  const sortBy = options.sortBy ?? "createdAt";
  const sortOrder = options.sortOrder ?? "desc";
  // ...
}

// Overloaded function with optional params
function formatName(first: string, last?: string, title?: string): string {
  let result = first;
  if (last) result += ` ${last}`;
  if (title) result = `${title} ${result}`;
  return result;
}
```

**Rust:**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SearchOptions {
    pub query: String,
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_page_size")]
    pub page_size: u32,
    #[serde(default = "default_sort_by")]
    pub sort_by: String,
    #[serde(default = "default_sort_order")]
    pub sort_order: SortOrder,
    #[serde(default)]
    pub filters: HashMap<String, String>,
}

fn default_page() -> u32 { 1 }
fn default_page_size() -> u32 { 20 }
fn default_sort_by() -> String { "created_at".into() }
fn default_sort_order() -> SortOrder { SortOrder::Desc }

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SortOrder {
    Asc,
    Desc,
}

async fn search_users(
    pool: &PgPool,
    options: &SearchOptions,
) -> Result<PaginatedResponse<User>, DbError> {
    // options.page, options.page_size, etc. are already defaulted by serde
    // No need for ?? fallback -- defaults are set at deserialization
    todo!()
}

// Optional parameters -> Option<T> with unwrap_or pattern
fn format_name(first: &str, last: Option<&str>, title: Option<&str>) -> String {
    let mut result = first.to_string();
    if let Some(last) = last {
        result.push(' ');
        result.push_str(last);
    }
    if let Some(title) = title {
        result = format!("{title} {result}");
    }
    result
}

// Usage:
// format_name("Alice", Some("Smith"), None)
// format_name("Bob", None, Some("Dr."))
```

### Example 6: Complex Null Propagation Chains

**TypeScript:**
```typescript
interface Order {
  id: string;
  customer?: {
    name: string;
    shippingAddress?: {
      line1: string;
      line2?: string;
      city: string;
      state: string;
      zip: string;
      country?: string;
    };
  };
  discount?: {
    code: string;
    percentage: number;
  };
}

function getShippingSummary(order: Order): string {
  const name = order.customer?.name ?? "Unknown";
  const line1 = order.customer?.shippingAddress?.line1 ?? "No address";
  const line2 = order.customer?.shippingAddress?.line2;
  const city = order.customer?.shippingAddress?.city ?? "";
  const country = order.customer?.shippingAddress?.country ?? "US";
  const discountText = order.discount
    ? `${order.discount.percentage}% off with ${order.discount.code}`
    : "No discount";

  let summary = `Ship to: ${name}\n${line1}`;
  if (line2) summary += `\n${line2}`;
  summary += `\n${city}, ${country}`;
  summary += `\nDiscount: ${discountText}`;
  return summary;
}
```

**Rust:**
```rust
fn get_shipping_summary(order: &Order) -> String {
    let name = order.customer.as_ref()
        .map(|c| c.name.as_str())
        .unwrap_or("Unknown");

    let address = order.customer.as_ref()
        .and_then(|c| c.shipping_address.as_ref());

    let line1 = address.map(|a| a.line1.as_str()).unwrap_or("No address");
    let line2 = address.and_then(|a| a.line2.as_deref());
    let city = address.map(|a| a.city.as_str()).unwrap_or("");
    let country = address
        .and_then(|a| a.country.as_deref())
        .unwrap_or("US");

    let discount_text = match &order.discount {
        Some(d) => format!("{}% off with {}", d.percentage, d.code),
        None => "No discount".to_string(),
    };

    let mut summary = format!("Ship to: {name}\n{line1}");
    if let Some(line2) = line2 {
        summary.push('\n');
        summary.push_str(line2);
    }
    summary.push_str(&format!("\n{city}, {country}"));
    summary.push_str(&format!("\nDiscount: {discount_text}"));
    summary
}
```

## Template

```markdown
# Nullability Mapping

Source: {project_name}
Generated: {date}

## Summary

| Pattern | Count | Rust Strategy |
|---------|-------|---------------|
| `T \| null` properties | {count} | `Option<T>` |
| `T \| undefined` properties | {count} | `Option<T>` |
| Optional parameters (`param?`) | {count} | `Option<T>` or defaults |
| Optional chaining (`?.`) | {count} | `.as_ref().and_then()` |
| Nullish coalescing (`??`) | {count} | `.unwrap_or()` / `.unwrap_or_else()` |
| Non-null assertions (`!`) | {count} | `.expect()` with message (review each) |
| Null-as-not-found returns | {count} | `Result<Option<T>, E>` |
| Null-as-error returns | {count} | `Result<T, E>` |

## Null Semantics Classification

For each nullable value, classify its semantics:

| # | Location | Expression | Null Meaning | Rust Type | Strategy |
|---|----------|-----------|-------------|-----------|----------|
| 1 | [{file}:{line}] | `user.avatar` | Absent value | `Option<String>` | `skip_serializing_if` |
| 2 | [{file}:{line}] | `findUser(id)` | Not found | `Result<Option<User>, E>` | Return Option in Ok |
| 3 | [{file}:{line}] | `parseJson(s)` | Parse error | `Result<T, E>` | Return Err on failure |
| 4 | [{file}:{line}] | `config.timeout` | Use default | `u64` with `#[serde(default)]` | Default at deserialization |
| ... | ... | ... | ... | ... | ... |

## Non-Null Assertion Audit

Every `!` (non-null assertion) must be individually reviewed:

| # | Location | Expression | Safe? | Rust Replacement |
|---|----------|-----------|-------|------------------|
| 1 | [{file}:{line}] | `user!.id` | No | `.ok_or(AuthError::NotAuthenticated)?` |
| 2 | [{file}:{line}] | `items[0]!` | No | `.first().ok_or(AppError::Internal(...))?` |
| 3 | [{file}:{line}] | `map.get(key)!` | No | `.ok_or_else(\|\| AppError::NotFound { ... })?` |
| ... | ... | ... | ... | ... |

## Optional Chaining Conversion Table

| TypeScript | Rust | Combinator Used |
|-----------|------|-----------------|
| `a?.b` | `a.as_ref().map(\|a\| &a.b)` | `map` |
| `a?.b?.c` | `a.as_ref().and_then(\|a\| a.b.as_ref()).map(\|b\| &b.c)` | `and_then` + `map` |
| `a?.b()` | `a.as_ref().map(\|a\| a.b())` | `map` |
| `a?.b ?? default` | `a.as_ref().map(\|a\| &a.b).unwrap_or(&default)` | `map` + `unwrap_or` |
| `a?.b?.c ?? default` | `a.as_ref().and_then(\|a\| a.b.as_ref()).and_then(\|b\| b.c.as_ref()).unwrap_or(&default)` | chain |

## Serde Configuration Reference

```rust
// Field omitted from JSON when None
#[serde(skip_serializing_if = "Option::is_none")]
pub field: Option<T>,

// Field defaults to None if missing from input
#[serde(default)]
pub field: Option<T>,

// Field defaults to specific value if missing
#[serde(default = "default_fn")]
pub field: T,

// Field serialized as null (not omitted) when None
// (default behavior -- no attribute needed)
pub field: Option<T>,

// Vec defaults to empty if missing
#[serde(default)]
pub items: Vec<T>,

// HashMap defaults to empty if missing
#[serde(default)]
pub metadata: HashMap<String, String>,
```

## Crate Dependencies

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```
```

## Completeness Check

- [ ] Every `T | null` type is mapped to `Option<T>`
- [ ] Every `T | undefined` type is mapped to `Option<T>`
- [ ] Every optional property (`field?`) has `Option<T>` with correct serde attribute
- [ ] Every optional parameter has an `Option<T>` or default value strategy
- [ ] Every optional chaining expression (`?.`) is converted to combinator chains
- [ ] Every nullish coalescing (`??`) is converted to `.unwrap_or()` or `.unwrap_or_else()`
- [ ] Every non-null assertion (`!`) is audited and replaced with `.expect()` or `?`
- [ ] Null-as-not-found patterns use `Result<Option<T>, E>`
- [ ] Null-as-error patterns use `Result<T, E>` with appropriate error variant
- [ ] Serde `skip_serializing_if` is applied to all optional JSON fields
- [ ] Serde `default` is applied where missing JSON fields should use defaults
- [ ] No bare `.unwrap()` calls exist without explicit justification
- [ ] Nested optional access patterns are mapped with correct combinator chains
