# 35 - Python-Specific Pattern Conversions

**Output**: `.migration-plan/mappings/pattern-transforms.md` (Python patterns section)

## Purpose

Map Python-specific language patterns and idioms that do not fit cleanly into other mapping categories to their Rust equivalents. This covers decorators, generators, comprehensions, variadic arguments, pattern matching, global state, monkey patching, duck typing, string formatting, slicing, exception hierarchies, and context managers. These are the patterns that make Python feel like Python -- and each must be deliberately translated to idiomatic Rust rather than naively transliterated.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- identifies decorators, generators, comprehensions, and special patterns
- `architecture.md` -- identifies global state, monkey patching, plugin patterns
- `error-patterns.md` -- identifies exception hierarchy and `with` statement usage

Extract every instance of:
- `@decorator` usage (function decorators, class decorators)
- `with` statements (context managers)
- Generator functions (`yield`, `yield from`)
- List/dict/set comprehensions
- `*args` / `**kwargs` parameter patterns
- `match` / `case` statements (Python 3.10+)
- Global variables and `global` keyword
- Monkey patching (runtime attribute assignment on classes/modules)
- Duck typing patterns (using attributes without type checking)
- Dunder methods not covered in `32-py-class-to-rust.md`
- f-string formatting
- Slice operations (`list[1:3]`, `str[:5]`)
- Exception hierarchy (custom exception classes inheriting from `Exception`)
- `with` statement for resource management
- Walrus operator (`:=`)
- Unpacking (`a, b, *rest = items`)
- Chained comparisons (`0 < x < 10`)
- Ternary expressions (`x if condition else y`)
- `__all__` module exports
- `if __name__ == "__main__"` guard
- `@dataclass` with custom `__post_init__`

### Step 2: For each pattern, determine Rust equivalent

**Pattern mapping summary:**

| Python Pattern | Rust Equivalent | Strategy |
|---------------|-----------------|----------|
| `@decorator` (logging/timing) | Wrapper function or proc macro | See Example 1 |
| `@decorator` (auth/validation) | Middleware (tower) or wrapper fn | See Example 1 |
| `with ctx_mgr:` | RAII + Drop or explicit scope | See Example 2 |
| `yield` (generator) | `Iterator` trait or `async Stream` | See Example 3 |
| `[x for x in ...]` | `.iter().map().collect()` | See Example 4 |
| `*args, **kwargs` | Tuples or builder pattern | See Example 5 |
| `match/case` | `match` | See Example 6 |
| `global x` | `static` + `LazyLock<Mutex<T>>` or `OnceLock` | See Example 7 |
| Monkey patching | Feature flags or trait impl | See Example 7 |
| Duck typing | Trait bounds | See Example 8 |
| f-strings | `format!()` macro | See Example 9 |
| Slicing | Index ranges or `.get()` | See Example 9 |
| Exception hierarchy | Error enum hierarchy | See Example 10 |

### Step 3: Produce pattern mapping document

For EACH pattern instance found, produce:
1. Source location and Python code snippet
2. Pattern classification
3. Rust equivalent with compilable code
4. Any crate dependencies or design decisions needed

## Code Examples

### Example 1: Decorators to wrapper functions / middleware

Python:
```python
import time
import functools
from typing import Callable, TypeVar, ParamSpec

P = ParamSpec("P")
R = TypeVar("R")

# Timing decorator
def timed(func: Callable[P, R]) -> Callable[P, R]:
    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        start = time.time()
        result = func(*args, **kwargs)
        elapsed = time.time() - start
        print(f"{func.__name__} took {elapsed:.3f}s")
        return result
    return wrapper

# Retry decorator
def retry(max_attempts: int = 3, delay: float = 1.0):
    def decorator(func: Callable[P, R]) -> Callable[P, R]:
        @functools.wraps(func)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            last_error = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_error = e
                    time.sleep(delay)
            raise last_error
        return wrapper
    return decorator

# Auth decorator (web)
def require_auth(func):
    @functools.wraps(func)
    async def wrapper(request, *args, **kwargs):
        token = request.headers.get("Authorization")
        if not token:
            raise HTTPException(status_code=401)
        request.user = verify_token(token)
        return await func(request, *args, **kwargs)
    return wrapper

@timed
@retry(max_attempts=3)
def fetch_data(url: str) -> dict:
    return requests.get(url).json()
```

Rust:
```rust
use std::time::Instant;
use tracing::instrument;

// Timing decorator -> tracing::instrument (most common approach)
#[instrument]
fn fetch_data(url: &str) -> Result<serde_json::Value, reqwest::Error> {
    // tracing automatically records function entry/exit with timing
    let response = reqwest::blocking::get(url)?.json()?;
    Ok(response)
}

// Or manual timing wrapper function:
async fn timed<F, Fut, T>(name: &str, f: F) -> T
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = T>,
{
    let start = Instant::now();
    let result = f().await;
    let elapsed = start.elapsed();
    tracing::info!("{name} took {elapsed:.3?}");
    result
}

// Retry decorator -> generic retry function
async fn retry<F, Fut, T, E>(
    max_attempts: u32,
    delay: std::time::Duration,
    f: F,
) -> Result<T, E>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
    E: std::fmt::Debug,
{
    let mut last_error = None;
    for attempt in 0..max_attempts {
        match f().await {
            Ok(val) => return Ok(val),
            Err(e) => {
                tracing::warn!(attempt, error = ?e, "retrying");
                last_error = Some(e);
                if attempt + 1 < max_attempts {
                    tokio::time::sleep(delay).await;
                }
            }
        }
    }
    Err(last_error.unwrap())
}

// Usage:
async fn fetch_data_with_retry(url: &str) -> Result<serde_json::Value, AppError> {
    retry(3, std::time::Duration::from_secs(1), || async {
        let data: serde_json::Value = reqwest::get(url).await?.json().await?;
        Ok(data)
    })
    .await
}

// Auth decorator -> axum middleware / extractor
use axum::{extract::FromRequestParts, http::request::Parts};

pub struct AuthUser {
    pub user_id: uuid::Uuid,
    pub role: String,
}

impl<S: Send + Sync> FromRequestParts<S> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or(AppError::Auth(AuthError::InvalidToken))?;

        let claims = verify_token(token)?;
        Ok(AuthUser {
            user_id: claims.sub,
            role: claims.role,
        })
    }
}

// Usage: auth is automatic via extractor
async fn get_profile(user: AuthUser) -> Result<Json<Profile>, AppError> {
    // user is already authenticated and extracted
    Ok(Json(fetch_profile(user.user_id).await?))
}
```

### Example 2: Context managers to RAII and scope guards

Python:
```python
from contextlib import contextmanager

@contextmanager
def database_transaction(conn):
    tx = conn.begin()
    try:
        yield tx
        tx.commit()
    except Exception:
        tx.rollback()
        raise

@contextmanager
def temporary_directory():
    path = tempfile.mkdtemp()
    try:
        yield path
    finally:
        shutil.rmtree(path)

# Usage
with database_transaction(conn) as tx:
    tx.execute("INSERT INTO users ...")

with temporary_directory() as tmpdir:
    process_files(tmpdir)
```

Rust:
```rust
// Database transaction: RAII via sqlx (auto-rollback on drop)
async fn create_user(pool: &sqlx::PgPool, user: &NewUser) -> Result<User, DbError> {
    let mut tx = pool.begin().await?;

    let user = sqlx::query_as::<_, User>(
        "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *"
    )
    .bind(&user.name)
    .bind(&user.email)
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;  // Explicit commit; Drop would rollback
    Ok(user)
}

// Temporary directory: RAII via tempfile crate
fn process_with_temp_dir() -> Result<(), AppError> {
    let tmpdir = tempfile::tempdir()?; // Automatically removed on drop

    let file_path = tmpdir.path().join("data.txt");
    std::fs::write(&file_path, "hello")?;
    process_files(tmpdir.path())?;

    Ok(())
    // tmpdir dropped here -> directory removed
}

// Custom scope guard (for patterns without a crate):
pub struct ScopeGuard<F: FnOnce()> {
    callback: Option<F>,
}

impl<F: FnOnce()> ScopeGuard<F> {
    pub fn new(callback: F) -> Self {
        Self { callback: Some(callback) }
    }
}

impl<F: FnOnce()> Drop for ScopeGuard<F> {
    fn drop(&mut self) {
        if let Some(callback) = self.callback.take() {
            callback();
        }
    }
}

// Usage:
fn with_cleanup() {
    let _guard = ScopeGuard::new(|| {
        tracing::info!("cleanup executed on scope exit");
    });
    // ... do work ...
    // cleanup runs when _guard is dropped (even on early return or panic)
}
```

### Example 3: Generators (yield) to Iterator trait

Python:
```python
def fibonacci():
    """Infinite generator."""
    a, b = 0, 1
    while True:
        yield a
        a, b = b, a + b

def read_chunks(file_path: str, chunk_size: int = 1024):
    """Generator that yields file chunks."""
    with open(file_path, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            yield chunk

def flatten(nested: list[list]) -> list:
    """Generator to flatten nested lists."""
    for sublist in nested:
        yield from sublist

# Usage
for n in fibonacci():
    if n > 1000:
        break
    print(n)

total_size = sum(len(chunk) for chunk in read_chunks("big_file.dat"))
```

Rust:
```rust
// Infinite generator -> Iterator struct
pub struct Fibonacci {
    a: u64,
    b: u64,
}

impl Fibonacci {
    pub fn new() -> Self {
        Self { a: 0, b: 1 }
    }
}

impl Iterator for Fibonacci {
    type Item = u64;

    fn next(&mut self) -> Option<u64> {
        let value = self.a;
        let next = self.a + self.b;
        self.a = self.b;
        self.b = next;
        Some(value) // Infinite: always returns Some
    }
}

// File chunk generator -> Iterator over Read
pub struct ChunkReader<R: std::io::Read> {
    reader: R,
    chunk_size: usize,
    buf: Vec<u8>,
}

impl<R: std::io::Read> ChunkReader<R> {
    pub fn new(reader: R, chunk_size: usize) -> Self {
        Self {
            reader,
            chunk_size,
            buf: vec![0u8; chunk_size],
        }
    }
}

impl<R: std::io::Read> Iterator for ChunkReader<R> {
    type Item = std::io::Result<Vec<u8>>;

    fn next(&mut self) -> Option<Self::Item> {
        match self.reader.read(&mut self.buf) {
            Ok(0) => None,
            Ok(n) => Some(Ok(self.buf[..n].to_vec())),
            Err(e) => Some(Err(e)),
        }
    }
}

// yield from -> flatten()
fn flatten<T>(nested: Vec<Vec<T>>) -> impl Iterator<Item = T> {
    nested.into_iter().flatten()
}

// Usage:
fn main() {
    for n in Fibonacci::new() {
        if n > 1000 {
            break;
        }
        println!("{n}");
    }

    let file = std::fs::File::open("big_file.dat").unwrap();
    let total_size: usize = ChunkReader::new(file, 1024)
        .filter_map(|chunk| chunk.ok())
        .map(|chunk| chunk.len())
        .sum();
}
```

### Example 4: Comprehensions to iterator chains

Python:
```python
# List comprehension
squares = [x ** 2 for x in range(10)]

# Filtered list comprehension
evens = [x for x in numbers if x % 2 == 0]

# Nested comprehension
flat = [item for sublist in matrix for item in sublist]

# Dict comprehension
word_lengths = {word: len(word) for word in words}

# Set comprehension
unique_domains = {email.split("@")[1] for email in emails}

# Conditional expression in comprehension
labels = ["even" if x % 2 == 0 else "odd" for x in numbers]

# Generator expression (lazy)
total = sum(price * qty for price, qty in orders)

# Nested dict comprehension with filtering
active_users = {
    uid: user
    for uid, user in users.items()
    if user.is_active and user.age >= 18
}
```

Rust:
```rust
use std::collections::{HashMap, HashSet};

// List comprehension -> map + collect
let squares: Vec<i64> = (0..10).map(|x| x * x).collect();

// Filtered list comprehension -> filter + collect
let evens: Vec<i64> = numbers.iter().copied().filter(|x| x % 2 == 0).collect();

// Nested comprehension -> flatten + collect
let flat: Vec<i64> = matrix.into_iter().flatten().collect();

// Dict comprehension -> map + collect into HashMap
let word_lengths: HashMap<&str, usize> = words
    .iter()
    .map(|word| (*word, word.len()))
    .collect();

// Set comprehension -> map + collect into HashSet
let unique_domains: HashSet<&str> = emails
    .iter()
    .filter_map(|email| email.split('@').nth(1))
    .collect();

// Conditional in comprehension -> map with match/if
let labels: Vec<&str> = numbers
    .iter()
    .map(|x| if x % 2 == 0 { "even" } else { "odd" })
    .collect();

// Generator expression (lazy) -> iterator chain (no collect)
let total: f64 = orders.iter().map(|(price, qty)| price * qty).sum();

// Nested dict comprehension with filtering
let active_users: HashMap<&str, &User> = users
    .iter()
    .filter(|(_, user)| user.is_active && user.age >= 18)
    .map(|(uid, user)| (uid.as_str(), user))
    .collect();
```

### Example 5: *args / **kwargs to tuples or builder pattern

Python:
```python
def log_event(event: str, *tags: str, **metadata: str) -> None:
    print(f"Event: {event}")
    for tag in tags:
        print(f"  tag: {tag}")
    for key, value in metadata.items():
        print(f"  {key}: {value}")

log_event("user_login", "auth", "success", user_id="123", ip="10.0.0.1")

# **kwargs for optional config
def create_connection(host: str, port: int = 5432, **options) -> Connection:
    timeout = options.get("timeout", 30)
    ssl = options.get("ssl", False)
    return Connection(host, port, timeout=timeout, ssl=ssl)
```

Rust:
```rust
use std::collections::HashMap;

// *tags -> &[&str] slice, **metadata -> HashMap
fn log_event(event: &str, tags: &[&str], metadata: &HashMap<&str, &str>) {
    println!("Event: {event}");
    for tag in tags {
        println!("  tag: {tag}");
    }
    for (key, value) in metadata {
        println!("  {key}: {value}");
    }
}

// Usage:
log_event(
    "user_login",
    &["auth", "success"],
    &HashMap::from([("user_id", "123"), ("ip", "10.0.0.1")]),
);

// **kwargs for optional config -> Builder pattern
pub struct ConnectionBuilder {
    host: String,
    port: u16,
    timeout: u64,
    ssl: bool,
    max_retries: u32,
}

impl ConnectionBuilder {
    pub fn new(host: impl Into<String>) -> Self {
        Self {
            host: host.into(),
            port: 5432,
            timeout: 30,
            ssl: false,
            max_retries: 3,
        }
    }

    pub fn port(mut self, port: u16) -> Self {
        self.port = port;
        self
    }

    pub fn timeout(mut self, timeout: u64) -> Self {
        self.timeout = timeout;
        self
    }

    pub fn ssl(mut self, ssl: bool) -> Self {
        self.ssl = ssl;
        self
    }

    pub fn max_retries(mut self, max_retries: u32) -> Self {
        self.max_retries = max_retries;
        self
    }

    pub fn build(self) -> Result<Connection, ConnectionError> {
        Connection::connect(self)
    }
}

// Usage: reads like named parameters
let conn = ConnectionBuilder::new("db.example.com")
    .port(5433)
    .timeout(60)
    .ssl(true)
    .build()?;
```

### Example 6: Python match/case to Rust match

Python:
```python
# Python 3.10+ structural pattern matching
def process_command(command: dict) -> str:
    match command:
        case {"action": "create", "name": str(name)}:
            return f"Creating {name}"
        case {"action": "delete", "id": int(id)}:
            return f"Deleting {id}"
        case {"action": "list", "filter": {"status": str(status)}}:
            return f"Listing with status={status}"
        case {"action": str(action)}:
            return f"Unknown action: {action}"
        case _:
            return "Invalid command"

def classify_status(code: int) -> str:
    match code:
        case code if 200 <= code < 300:
            return "success"
        case 404:
            return "not found"
        case code if 500 <= code < 600:
            return "server error"
        case _:
            return "other"
```

Rust:
```rust
use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
enum Command {
    Create { name: String },
    Delete { id: i64 },
    List { filter: Option<ListFilter> },
}

#[derive(Debug, Deserialize)]
struct ListFilter {
    status: Option<String>,
}

fn process_command(command: &Command) -> String {
    match command {
        Command::Create { name } => format!("Creating {name}"),
        Command::Delete { id } => format!("Deleting {id}"),
        Command::List { filter: Some(ListFilter { status: Some(status) }) } => {
            format!("Listing with status={status}")
        }
        Command::List { .. } => "Listing all".to_string(),
    }
}

fn classify_status(code: u16) -> &'static str {
    match code {
        200..=299 => "success",
        404 => "not found",
        500..=599 => "server error",
        _ => "other",
    }
}
```

### Example 7: Global variables and monkey patching

Python:
```python
# Global mutable state
_registry: dict[str, type] = {}
_config: dict | None = None

def register(name: str, cls: type):
    global _registry
    _registry[name] = cls

def get_config() -> dict:
    global _config
    if _config is None:
        _config = load_config_from_file()
    return _config

# Monkey patching for testing
import mymodule
original_fetch = mymodule.fetch_data

def mock_fetch(url):
    return {"mock": True}

mymodule.fetch_data = mock_fetch  # Monkey patch!
```

Rust:
```rust
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex, OnceLock};

// Global mutable registry -> LazyLock<Mutex<HashMap>>
static REGISTRY: LazyLock<Mutex<HashMap<String, String>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub fn register(name: String, class_name: String) {
    REGISTRY.lock().unwrap().insert(name, class_name);
}

// Global config loaded once -> OnceLock
static CONFIG: OnceLock<AppConfig> = OnceLock::new();

pub fn get_config() -> &'static AppConfig {
    CONFIG.get_or_init(|| {
        load_config_from_file().expect("failed to load config")
    })
}

// Monkey patching -> trait objects for dependency injection (testable)
pub trait DataFetcher: Send + Sync {
    fn fetch(&self, url: &str) -> Result<serde_json::Value, FetchError>;
}

pub struct HttpFetcher;

impl DataFetcher for HttpFetcher {
    fn fetch(&self, url: &str) -> Result<serde_json::Value, FetchError> {
        // Real HTTP fetch
        let data = reqwest::blocking::get(url)?.json()?;
        Ok(data)
    }
}

// In tests: use a mock instead of monkey patching
#[cfg(test)]
mod tests {
    use super::*;

    struct MockFetcher;

    impl DataFetcher for MockFetcher {
        fn fetch(&self, _url: &str) -> Result<serde_json::Value, FetchError> {
            Ok(serde_json::json!({"mock": true}))
        }
    }

    #[test]
    fn test_with_mock() {
        let fetcher: Box<dyn DataFetcher> = Box::new(MockFetcher);
        let result = fetcher.fetch("https://example.com").unwrap();
        assert_eq!(result["mock"], true);
    }
}
```

### Example 8: Duck typing to trait bounds

Python:
```python
# Duck typing: any object with .read() works
def process_input(source):
    """Accepts file, StringIO, BytesIO, socket -- anything with .read()"""
    data = source.read()
    return parse(data)

# Duck typing: any object with .items() works
def merge_dicts(*dicts):
    result = {}
    for d in dicts:
        for key, value in d.items():
            result[key] = value
    return result

# Duck typing with hasattr check
def get_name(obj) -> str:
    if hasattr(obj, 'full_name'):
        return obj.full_name
    elif hasattr(obj, 'name'):
        return obj.name
    else:
        return str(obj)
```

Rust:
```rust
use std::io::Read;

// Duck typing .read() -> Read trait bound
fn process_input(mut source: impl Read) -> Result<ParsedData, AppError> {
    let mut data = Vec::new();
    source.read_to_end(&mut data)?;
    parse(&data)
}

// Usage: works with File, Cursor, TcpStream, etc.
let file = std::fs::File::open("input.txt")?;
process_input(file)?;

let cursor = std::io::Cursor::new(b"hello world");
process_input(cursor)?;

// Duck typing .items() -> IntoIterator trait bound
fn merge_maps<I, K, V>(maps: I) -> std::collections::HashMap<K, V>
where
    I: IntoIterator,
    I::Item: IntoIterator<Item = (K, V)>,
    K: Eq + std::hash::Hash,
{
    let mut result = std::collections::HashMap::new();
    for map in maps {
        for (key, value) in map {
            result.insert(key, value);
        }
    }
    result
}

// Duck typing with hasattr -> trait with enum or explicit methods
pub trait Named {
    fn display_name(&self) -> String;
}

// Each type implements the trait with its own logic:
impl Named for User {
    fn display_name(&self) -> String {
        self.full_name.clone()
    }
}

impl Named for Organization {
    fn display_name(&self) -> String {
        self.name.clone()
    }
}
```

### Example 9: f-strings, slicing, and misc syntax

Python:
```python
# f-strings
name = "World"
greeting = f"Hello, {name}!"
debug = f"User(id={user.id}, name={user.name!r})"
padded = f"{value:>10.2f}"
multiline = f"""
    Name: {name}
    Age: {age}
    Score: {score:.1f}%
"""

# Slicing
first_three = items[:3]
last_two = items[-2:]
middle = items[1:-1]
reversed_list = items[::-1]
every_other = items[::2]
substring = text[5:10]

# Walrus operator
if (match := pattern.search(text)) is not None:
    print(match.group())

# Chained comparison
if 0 < x < 100:
    print("in range")

# Unpacking
first, *rest = items
a, b, c = (1, 2, 3)
```

Rust:
```rust
// f-strings -> format!() macro
let name = "World";
let greeting = format!("Hello, {name}!");
let debug = format!("User(id={}, name={:?})", user.id, user.name);
let padded = format!("{:>10.2}", value);
let multiline = format!(
    "Name: {name}\nAge: {age}\nScore: {score:.1}%",
    name = name,
    age = age,
    score = score,
);

// Slicing -> index ranges and methods
let first_three = &items[..3];               // items[:3]
let last_two = &items[items.len() - 2..];    // items[-2:]
let middle = &items[1..items.len() - 1];     // items[1:-1]

let reversed_list: Vec<_> = items.iter().rev().collect();  // items[::-1]
let every_other: Vec<_> = items.iter().step_by(2).collect(); // items[::2]

let substring = &text[5..10];  // text[5:10] (byte indices, not char!)
// For char-safe slicing:
let substring: String = text.chars().skip(5).take(5).collect();

// Walrus operator -> if let
if let Some(m) = pattern.find(text) {
    println!("{}", m.as_str());
}

// Chained comparison -> logical AND
if 0 < x && x < 100 {
    println!("in range");
}
// Or use range contains:
if (1..100).contains(&x) {
    println!("in range");
}

// Unpacking -> pattern matching
let (first, rest) = items.split_first().unwrap();
// Or:
let first = items[0];
let rest = &items[1..];

let (a, b, c) = (1, 2, 3);
```

### Example 10: Exception hierarchy to Error enum hierarchy

Python:
```python
class AppError(Exception):
    """Base application error."""
    pass

class ValidationError(AppError):
    def __init__(self, field: str, message: str):
        self.field = field
        self.message = message
        super().__init__(f"Validation error on {field}: {message}")

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str):
        self.resource = resource
        self.id = id
        super().__init__(f"{resource} with id {id} not found")

class AuthenticationError(AppError):
    pass

class AuthorizationError(AppError):
    def __init__(self, action: str, resource: str):
        self.action = action
        self.resource = resource
        super().__init__(f"Not authorized to {action} on {resource}")

# Usage
try:
    user = find_user(user_id)
    if user is None:
        raise NotFoundError("User", user_id)
    validate_user(user)
except NotFoundError as e:
    return {"error": str(e)}, 404
except ValidationError as e:
    return {"error": str(e), "field": e.field}, 422
except AuthenticationError:
    return {"error": "Unauthorized"}, 401
except AppError as e:
    return {"error": str(e)}, 500
```

Rust:
```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("validation error on {field}: {message}")]
    Validation { field: String, message: String },

    #[error("{resource} with id {id} not found")]
    NotFound { resource: &'static str, id: String },

    #[error("authentication required")]
    Authentication,

    #[error("not authorized to {action} on {resource}")]
    Authorization { action: String, resource: String },

    #[error("internal error: {0}")]
    Internal(String),

    #[error(transparent)]
    Database(#[from] sqlx::Error),

    #[error(transparent)]
    Unexpected(#[from] anyhow::Error),
}

// HTTP status mapping (replaces try/except -> status code)
impl axum::response::IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        use axum::http::StatusCode;

        let (status, error_json) = match &self {
            AppError::Validation { field, message } => (
                StatusCode::UNPROCESSABLE_ENTITY,
                serde_json::json!({"error": self.to_string(), "field": field}),
            ),
            AppError::NotFound { .. } => (
                StatusCode::NOT_FOUND,
                serde_json::json!({"error": self.to_string()}),
            ),
            AppError::Authentication => (
                StatusCode::UNAUTHORIZED,
                serde_json::json!({"error": "Unauthorized"}),
            ),
            AppError::Authorization { .. } => (
                StatusCode::FORBIDDEN,
                serde_json::json!({"error": self.to_string()}),
            ),
            _ => {
                tracing::error!(error = ?self, "internal error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    serde_json::json!({"error": "internal error"}),
                )
            }
        };

        (status, axum::Json(error_json)).into_response()
    }
}

// Usage: match replaces try/except
async fn get_user_handler(
    Path(user_id): Path<uuid::Uuid>,
) -> Result<Json<User>, AppError> {
    let user = find_user(user_id)
        .await?                           // ? replaces except for DB errors
        .ok_or(AppError::NotFound {       // None -> NotFoundError
            resource: "User",
            id: user_id.to_string(),
        })?;

    validate_user(&user)?;                // ValidationError propagates via ?

    Ok(Json(user))
}
```

## Additional Pattern Quick Reference

| Python | Rust | Notes |
|--------|------|-------|
| `if __name__ == "__main__":` | `fn main()` | Rust has explicit entry point |
| `__all__ = ["Foo", "Bar"]` | `pub` visibility on items | No runtime export list |
| `@classmethod` | Associated function (no `&self`) | `impl Type { fn method() }` |
| `@staticmethod` | Associated function (no `&self`) | Same as classmethod in Rust |
| `@abstractmethod` | Trait method (no default) | `trait T { fn method(&self); }` |
| `@property` | Getter method | `fn name(&self) -> &str` |
| `lambda x: x + 1` | `\|x\| x + 1` | Closure syntax |
| `map(fn, items)` | `items.iter().map(fn)` | Lazy iterator |
| `filter(fn, items)` | `items.iter().filter(fn)` | Lazy iterator |
| `zip(a, b)` | `a.iter().zip(b.iter())` | Lazy iterator |
| `enumerate(items)` | `items.iter().enumerate()` | Returns `(usize, &T)` |
| `sorted(items, key=fn)` | `items.sort_by_key(fn)` (in-place) | Or `.sorted_by_key()` from itertools |
| `reversed(items)` | `items.iter().rev()` | Lazy reverse iterator |
| `any(pred(x) for x in items)` | `items.iter().any(pred)` | Short-circuits |
| `all(pred(x) for x in items)` | `items.iter().all(pred)` | Short-circuits |
| `min(items)` / `max(items)` | `items.iter().min()` / `.max()` | Returns `Option<&T>` |
| `sum(items)` | `items.iter().sum::<T>()` | Requires `Sum` trait |
| `len(items)` | `items.len()` | Method call, not function |
| `isinstance(x, T)` | `match` on enum / `downcast_ref` | No runtime type checking |
| `type(x).__name__` | `std::any::type_name::<T>()` | Compile-time |
| `id(x)` | `std::ptr::addr_of!(x)` | Pointer address |
| `del x` | `drop(x)` or let go out of scope | Ownership-based |
| `pass` | `{}` or `todo!()` | Empty block or placeholder |
| `...` (Ellipsis) | `todo!()` or `unimplemented!()` | Placeholder |

## Template

```markdown
# Python Pattern Conversions

Source: {project_name}
Generated: {date}

## Summary

| Pattern Category | Count | Notes |
|-----------------|-------|-------|
| Decorators converted | {n} | -> wrapper fn / middleware / proc macro |
| Context managers converted | {n} | -> RAII + Drop |
| Generators converted | {n} | -> Iterator impl |
| Comprehensions converted | {n} | -> iterator chains |
| *args/**kwargs converted | {n} | -> slices / builders |
| match/case converted | {n} | -> Rust match |
| Global state converted | {n} | -> LazyLock / OnceLock |
| Duck typing resolved | {n} | -> trait bounds |
| Exception hierarchy converted | {n} | -> Error enums |

## Pattern Conversions

### 1. {Pattern Description}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Category**: Decorator / Context Manager / Generator / Comprehension / ...

**Python**:
```python
{source code}
```

**Rust**:
```rust
{compilable Rust code}
```

**Rationale**: {why this approach was chosen}

---

### 2. {Pattern Description}
...
```

## Completeness Check

- [ ] Every `@decorator` has a Rust equivalent (wrapper fn, middleware, or proc macro)
- [ ] Every `with` statement has an RAII or scope-guard equivalent
- [ ] Every generator function has an `Iterator` or `Stream` implementation
- [ ] Every list/dict/set comprehension has an iterator chain equivalent
- [ ] Every `*args` / `**kwargs` is resolved to slices, tuples, or builder pattern
- [ ] Every `match` / `case` (3.10+) has a Rust `match` equivalent
- [ ] Every global variable has a `static` / `LazyLock` / `OnceLock` strategy
- [ ] Every monkey patching pattern is replaced with trait objects or feature flags
- [ ] Every duck typing pattern has explicit trait bounds
- [ ] Every f-string has a `format!()` equivalent
- [ ] Every slice operation has an index range or iterator equivalent
- [ ] Every exception class has a variant in the error enum hierarchy
- [ ] Every `if __name__ == "__main__"` is mapped to `fn main()`
- [ ] No Python-specific idioms are carried over without deliberate translation
- [ ] All Rust code examples compile with current crate versions
