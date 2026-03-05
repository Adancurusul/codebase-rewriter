# 31 - Python None/Optional to Rust Option/Result Mapping

**Output**: `.migration-plan/mappings/none-handling.md`

## Purpose

Map every Python `None` usage, `Optional[T]` type hint, truthiness check, and sentinel value to the Rust `Option<T>` and `Result<T, E>` system. Python uses `None` as a universal sentinel -- for missing values, default returns, error indicators, uninitialized state, and "no result." Rust splits these concerns: `Option<T>` for "value or nothing," `Result<T, E>` for "value or error." Every `None`-producing or `None`-consuming expression in the source must be classified and mapped to the correct Rust idiom.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- identifies all `Optional[T]`, `T | None`, and untyped parameters that accept `None`
- `error-patterns.md` -- identifies functions that return `None` to signal errors vs. "not found"
- `architecture.md` -- identifies patterns where `None` flows across module boundaries

Extract every instance of:
- `Optional[T]` parameter and return type annotations
- `T | None` (Python 3.10+) annotations
- `if x is None` / `if x is not None` checks
- `x or default_value` patterns
- `getattr(obj, "attr", default)` calls
- `dict.get(key)` and `dict.get(key, default)` calls
- Functions returning `None` to indicate failure vs. absence
- `None` as default parameter value
- Truthiness checks (`if x:`, `if not x:`) on nullable values
- Variables initialized to `None` and later assigned
- Multiple return values where some may be `None`
- `None` as sentinel in collections (`list[T | None]`)

### Step 2: Classify each None usage and determine Rust equivalent

**Classification decision tree:**

```
What does None mean in this context?

1. "Value might not exist" (Optional data)
   -> Option<T>
   Examples: user.middle_name, dict.get(key), find_by_id()

2. "Operation might fail" (Error signaling)
   -> Result<T, E>
   Examples: parse_int(s) returning None on failure

3. "Not yet initialized" (Late initialization)
   -> Option<T> with .expect() at usage site
   OR: builder pattern / two-phase init
   Examples: self.connection = None in __init__, set later

4. "No meaningful return value" (Void return)
   -> () (unit type)
   Examples: def save(self) -> None

5. "Default parameter" (Optional argument)
   -> Option<T> parameter with .unwrap_or() / .unwrap_or_else()
   OR: builder pattern for many optional params
   Examples: def search(query, limit=None, offset=None)

6. "Sentinel in collection" (Sparse data)
   -> Vec<Option<T>> or filter out Nones
   Examples: results: list[Result | None]
```

**Python to Rust conversion patterns:**

| Python Pattern | Rust Equivalent | Method |
|---------------|-----------------|--------|
| `Optional[T]` / `T \| None` | `Option<T>` | Direct mapping |
| `if x is None` | `x.is_none()` or `if let None = x` | Prefer `match` or `if let` |
| `if x is not None` | `x.is_some()` or `if let Some(val) = x` | Prefer `if let` to extract value |
| `x or default` | `x.unwrap_or(default)` | Value must be `Clone` or cheap |
| `x or compute()` | `x.unwrap_or_else(\|\| compute())` | Lazy evaluation |
| `x if x is not None else default` | `x.unwrap_or(default)` | Conditional expression |
| `getattr(obj, 'a', default)` | `obj.a.clone().unwrap_or(default)` | Field is `Option<T>` |
| `dict.get(key)` | `map.get(&key)` returns `Option<&V>` | Borrowed reference |
| `dict.get(key, default)` | `map.get(&key).cloned().unwrap_or(default)` | Clone to own |
| `x = None; ...; x = value` | `let x: Option<T> = None; ...; x = Some(value);` | Late init |
| `return None` (error) | `return Err(SomeError)` | Error case |
| `return None` (not found) | `return Ok(None)` or `return None` | Depends on function signature |
| `assert x is not None` | `x.expect("reason")` or `x.unwrap()` | Panics; use only for invariants |
| `if x:` (truthiness on Option) | `if let Some(val) = x` | No implicit truthiness in Rust |
| `if not x:` (falsy check) | `if x.is_none()` or `match x { None => ..., ... }` | Explicit check |
| `[x for x in items if x is not None]` | `items.into_iter().flatten().collect()` | `Option` implements `IntoIterator` |
| `next((x for x in items if pred(x)), None)` | `items.iter().find(\|x\| pred(x))` | Returns `Option<&T>` |

### Step 3: Produce None-handling mapping document

For EACH `None` usage site found, produce:
1. Source location and code snippet
2. Classification (which of the 6 categories)
3. Rust equivalent with compilable code
4. Any `unwrap()` or `expect()` calls justified

## Code Examples

### Example 1: Optional parameters and return values

Python:
```python
from typing import Optional

def find_user(user_id: int) -> Optional[User]:
    row = db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    if row is None:
        return None
    return User.from_row(row)

def greet(name: str, title: Optional[str] = None) -> str:
    if title is not None:
        return f"Hello, {title} {name}!"
    return f"Hello, {name}!"
```

Rust:
```rust
async fn find_user(pool: &PgPool, user_id: i64) -> Result<Option<User>, DbError> {
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await?;
    Ok(user)
}

fn greet(name: &str, title: Option<&str>) -> String {
    match title {
        Some(t) => format!("Hello, {t} {name}!"),
        None => format!("Hello, {name}!"),
    }
}
```

### Example 2: dict.get() with default values

Python:
```python
config = {"timeout": 30, "retries": 3}

timeout = config.get("timeout", 60)
retries = config.get("retries", 1)
debug = config.get("debug", False)

# Nested access with defaults
db_config = config.get("database", {})
host = db_config.get("host", "localhost")
port = db_config.get("port", 5432)
```

Rust:
```rust
use std::collections::HashMap;

let config: HashMap<String, serde_json::Value> = load_config();

let timeout = config
    .get("timeout")
    .and_then(|v| v.as_i64())
    .unwrap_or(60);

let retries = config
    .get("retries")
    .and_then(|v| v.as_i64())
    .unwrap_or(1);

let debug = config
    .get("debug")
    .and_then(|v| v.as_bool())
    .unwrap_or(false);

// Nested access -- use a strongly typed config struct instead
#[derive(Debug, Deserialize)]
pub struct DbConfig {
    #[serde(default = "default_host")]
    pub host: String,
    #[serde(default = "default_port")]
    pub port: u16,
}

fn default_host() -> String { "localhost".into() }
fn default_port() -> u16 { 5432 }
```

### Example 3: Truthiness checks on nullable values

Python:
```python
def process_items(items: list[str] | None, name: str | None) -> str:
    # Truthiness: checks for both None AND empty
    if not items:
        items = ["default"]

    # Truthiness on string: checks for None AND empty string
    if not name:
        name = "anonymous"

    # Truthiness on number is tricky: 0 is falsy
    count: int | None = get_count()
    if not count:  # BUG: this treats 0 as missing!
        count = 10

    return f"{name}: {len(items)} items, count={count}"
```

Rust:
```rust
fn process_items(items: Option<Vec<String>>, name: Option<String>) -> String {
    // Option<Vec<T>>: must decide if empty vec is "no value" or valid
    let items = match items {
        Some(v) if !v.is_empty() => v,
        _ => vec!["default".to_string()],
    };

    // Option<String>: must decide if empty string is "no value" or valid
    let name = match name {
        Some(n) if !n.is_empty() => n,
        _ => "anonymous".to_string(),
    };

    // Option<i32>: Rust forces explicit handling -- no 0-is-falsy bug
    let count = get_count().unwrap_or(10);
    // If 0 should genuinely be treated as "use default":
    // let count = get_count().filter(|&c| c > 0).unwrap_or(10);

    format!("{name}: {} items, count={count}", items.len())
}
```

### Example 4: None as late initialization sentinel

Python:
```python
class Connection:
    def __init__(self, url: str):
        self.url = url
        self._client: Optional[httpx.Client] = None
        self._session_id: Optional[str] = None

    def connect(self) -> None:
        self._client = httpx.Client(base_url=self.url)
        response = self._client.post("/session")
        self._session_id = response.json()["session_id"]

    def query(self, sql: str) -> list[dict]:
        if self._client is None:
            raise RuntimeError("Not connected. Call connect() first.")
        return self._client.post("/query", json={"sql": sql}).json()
```

Rust:
```rust
use reqwest::Client;

pub struct Connection {
    url: String,
    client: Option<Client>,
    session_id: Option<String>,
}

impl Connection {
    pub fn new(url: String) -> Self {
        Self {
            url,
            client: None,
            session_id: None,
        }
    }

    pub async fn connect(&mut self) -> Result<(), ConnectionError> {
        let client = Client::new();
        let response: serde_json::Value = client
            .post(format!("{}/session", self.url))
            .send()
            .await?
            .json()
            .await?;

        let session_id = response["session_id"]
            .as_str()
            .ok_or(ConnectionError::InvalidResponse)?
            .to_string();

        self.client = Some(client);
        self.session_id = Some(session_id);
        Ok(())
    }

    pub async fn query(&self, sql: &str) -> Result<Vec<serde_json::Value>, ConnectionError> {
        let client = self.client.as_ref().ok_or(ConnectionError::NotConnected)?;
        let result = client
            .post(format!("{}/query", self.url))
            .json(&serde_json::json!({"sql": sql}))
            .send()
            .await?
            .json()
            .await?;
        Ok(result)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ConnectionError {
    #[error("not connected -- call connect() first")]
    NotConnected,

    #[error("invalid response from server")]
    InvalidResponse,

    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
}
```

### Example 5: Filtering None from collections

Python:
```python
from typing import Optional

def get_emails(users: list[User]) -> list[str]:
    # Filter out users without emails
    return [user.email for user in users if user.email is not None]

def first_valid(values: list[Optional[int]]) -> Optional[int]:
    for v in values:
        if v is not None:
            return v
    return None

def collect_results(tasks: list[Task]) -> list[str]:
    results: list[Optional[str]] = [t.result for t in tasks]
    return [r for r in results if r is not None]
```

Rust:
```rust
fn get_emails(users: &[User]) -> Vec<String> {
    users
        .iter()
        .filter_map(|user| user.email.clone())
        .collect()
}

fn first_valid(values: &[Option<i32>]) -> Option<i32> {
    values.iter().copied().flatten().next()
}

fn collect_results(tasks: &[Task]) -> Vec<String> {
    tasks
        .iter()
        .filter_map(|t| t.result.clone())
        .collect()
}
```

### Example 6: None return meaning "error" vs. "not found"

Python:
```python
# BAD: None means both "not found" and "parse error"
def parse_config(path: str) -> Optional[Config]:
    try:
        with open(path) as f:
            data = json.load(f)
        return Config(**data)
    except (FileNotFoundError, json.JSONDecodeError, TypeError):
        return None  # Caller cannot distinguish error from missing

# GOOD: Separate error from absence
def find_user(user_id: int) -> Optional[User]:
    """Returns None only for 'not found'; raises on errors."""
    row = db.query_one_or_none("SELECT * FROM users WHERE id = ?", user_id)
    if row is None:
        return None
    return User.from_row(row)
```

Rust:
```rust
// The "bad" Python pattern becomes clear and correct in Rust:
fn parse_config(path: &std::path::Path) -> Result<Config, ConfigError> {
    let content = std::fs::read_to_string(path)?;  // Err on file not found
    let config: Config = serde_json::from_str(&content)?;  // Err on parse failure
    Ok(config)
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("failed to read config file: {0}")]
    Io(#[from] std::io::Error),

    #[error("failed to parse config: {0}")]
    Parse(#[from] serde_json::Error),
}

// "Not found" is genuinely Optional:
async fn find_user(pool: &PgPool, user_id: i64) -> Result<Option<User>, DbError> {
    sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(DbError::from)
}
```

## Option Method Quick Reference

| Python Idiom | Rust `Option<T>` Method | Returns |
|-------------|------------------------|---------|
| `x if x is not None else default` | `x.unwrap_or(default)` | `T` |
| `x if x is not None else compute()` | `x.unwrap_or_else(\|\| compute())` | `T` |
| `x if x is not None else T.default()` | `x.unwrap_or_default()` | `T` (requires `Default`) |
| `f(x) if x is not None else None` | `x.map(f)` | `Option<U>` |
| `f(x) if x is not None else None` (f returns Optional) | `x.and_then(f)` | `Option<U>` |
| `x if x is not None else y` (both Optional) | `x.or(y)` | `Option<T>` |
| `x if x is not None else compute_opt()` | `x.or_else(\|\| compute_opt())` | `Option<T>` |
| `x is None` | `x.is_none()` | `bool` |
| `x is not None` | `x.is_some()` | `bool` |
| `assert x is not None; use(x)` | `x.expect("msg")` or `x.unwrap()` | `T` (panics if None) |
| `x is not None and pred(x)` | `x.is_some_and(\|v\| pred(v))` | `bool` |
| `[x for x in opts if x is not None]` | `opts.into_iter().flatten().collect()` | `Vec<T>` |
| `(x, y) if both not None` | `x.zip(y)` | `Option<(T, U)>` |

## Template

```markdown
# None/Optional Handling Map

Source: {project_name}
Generated: {date}

## Summary

| Category | Count | Notes |
|----------|-------|-------|
| Optional parameter -> Option<T> | {n} | |
| Optional return -> Option<T> | {n} | |
| None-as-error -> Result<T, E> | {n} | |
| Late init -> Option<T> | {n} | |
| Void return -> () | {n} | |
| Truthiness check -> explicit check | {n} | |
| dict.get -> HashMap::get | {n} | |
| None sentinel in collection -> filter_map | {n} | |

## None Usage Inventory

### 1. {Description}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Category**: Optional data / Error signaling / Late init / Void / Default param / Sentinel
**Python**:
```python
{source code}
```

**Rust**:
```rust
{compilable Rust code}
```

**Rationale**: {why Option vs Result vs unit type}

---

### 2. {Description}
...

## unwrap()/expect() Inventory

List every place where `.unwrap()` or `.expect()` is used, with justification:

| Location | Method | Justification |
|----------|--------|---------------|
| `main.rs:15` | `.expect("DATABASE_URL must be set")` | Startup config -- fail fast |
| `parser.rs:42` | `.unwrap()` | Value guaranteed by prior check |
| ... | ... | ... |
```

## Completeness Check

- [ ] Every `Optional[T]` / `T | None` annotation has a Rust `Option<T>` or `Result<T, E>` mapping
- [ ] Every `if x is None` check has a Rust `Option` method or `match` equivalent
- [ ] Every `x or default` pattern uses `.unwrap_or()` or `.unwrap_or_else()`
- [ ] Every `dict.get()` call has a `HashMap::get()` equivalent with correct ownership
- [ ] Every truthiness check (`if x:`, `if not x:`) is replaced with explicit Option/len/isEmpty check
- [ ] Every None-as-error-signal is converted to `Result<T, E>` with a specific error type
- [ ] Every late-initialization `None` has `Option<T>` with `.ok_or()` at usage sites
- [ ] Every void return (`-> None`) is mapped to `-> ()` or `-> Result<(), E>`
- [ ] Every `unwrap()` / `expect()` in the output is justified and inventoried
- [ ] No Python truthiness bugs are carried over (e.g., `0` and `""` being falsy)
- [ ] Collection filtering of `None` values uses `filter_map()` or `flatten()`
