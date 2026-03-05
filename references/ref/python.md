# Python -> Rust Reference

## Primitive Types

| Python | Rust | Notes |
|--------|------|-------|
| `int` | `i64` | Unbounded -> use `i64` unless range known |
| `int` (small) | `i32` / `i16` / `i8` | Smallest type that fits domain |
| `int` (non-negative) | `u64` / `u32` / `usize` | Counts, sizes, indices |
| `float` | `f64` | Always 64-bit |
| `str` | `String` / `&str` | Owned for fields; borrowed for params |
| `bytes` | `Vec<u8>` / `&[u8]` | Owned / borrowed |
| `bool` | `bool` | Direct |
| `None` (return) | `()` | Unit type for void return |
| `list[T]` | `Vec<T>` | Dynamic array |
| `tuple[A, B, C]` | `(A, B, C)` | Fixed-length heterogeneous |
| `tuple[T, ...]` | `Vec<T>` | Variable-length homogeneous |
| `dict[K, V]` | `HashMap<K, V>` | `K: Eq + Hash` |
| `set[T]` | `HashSet<T>` | `T: Eq + Hash` |
| `frozenset[T]` | `HashSet<T>` (no `&mut`) | Immutable by API |
| `OrderedDict` | `IndexMap<K, V>` | `indexmap` crate |
| `deque` | `VecDeque<T>` | Double-ended queue |
| `Counter` | `HashMap<K, usize>` | Manual counting |
| `defaultdict` | `HashMap` + `.entry().or_default()` | Entry API |
| `Any` | `Box<dyn Any>` | Avoid; prefer enums/traits |
| `Callable[[A,B], R]` | `Fn(A, B) -> R` | Trait bound |
| `Iterator[T]` | `impl Iterator<Item = T>` | Trait |
| `datetime.datetime` | `chrono::DateTime<Utc>` | `chrono` crate |
| `datetime.date` | `chrono::NaiveDate` | `chrono` crate |
| `datetime.timedelta` | `chrono::Duration` | `chrono` crate |
| `uuid.UUID` | `uuid::Uuid` | `uuid` crate |
| `pathlib.Path` | `PathBuf` / `&Path` | `std::path` |
| `decimal.Decimal` | `rust_decimal::Decimal` | `rust_decimal` crate |
| `re.Pattern` | `regex::Regex` | `regex` crate |
| `IPv4Address` | `std::net::Ipv4Addr` | Built-in |
| `IPv6Address` | `std::net::Ipv6Addr` | Built-in |
| `typing.IO` | `std::io::Read` / `Write` | Trait-based |

## Structured Types

| Python | Rust | Derives |
|--------|------|---------|
| `@dataclass` | `struct` | `Debug, Clone, PartialEq, Eq` |
| `@dataclass(frozen=True)` | `struct` (no `&mut`) | `Debug, Clone, Hash, PartialEq, Eq` |
| `TypedDict` | `struct` | `Debug, Clone, Serialize, Deserialize` |
| `TypedDict(total=False)` | `struct` with `Option<T>` fields | `+ Serialize, Deserialize` |
| `NamedTuple` | `struct` | `Debug, Clone, PartialEq` |
| `enum.Enum` | `enum` (unit variants) | `Debug, Clone, Copy, PartialEq, Eq` |
| `enum.IntEnum` | `enum` + `#[repr(i32)]` | `Debug, Clone, Copy, PartialEq, Eq` |
| `enum.StrEnum` | `enum` + serde | `+ Serialize, Deserialize` |
| `Union[A, B]` | `enum { A(A), B(B) }` | `Debug, Clone` |
| `Literal["x","y"]` | `enum` or `const` | Small set -> enum |
| `Protocol` | `trait` | N/A |
| `ABC` | `trait` | N/A |
| `Generic[T]` | `struct<T>` / `fn<T>` | Add trait bounds |
| `TypeVar("T", bound=X)` | `T: X` | Trait bound |
| `type` alias | `type Alias = Type;` | N/A |
| `NewType` | `struct Name(Inner);` | `Debug, Clone` |
| `BaseModel` (pydantic) | `struct` + validation | `+ Serialize, Deserialize, Validate` |
| `@define` (attrs) | `struct` | `Debug, Clone` |

## None/Optional Patterns

| Python | Rust |
|--------|------|
| `Optional[T]` / `T \| None` | `Option<T>` |
| `if x is None` | `x.is_none()` or `if let None = x` |
| `if x is not None` | `if let Some(val) = x` |
| `x or default` | `x.unwrap_or(default)` |
| `x or compute()` | `x.unwrap_or_else(\|\| compute())` |
| `x if x is not None else default` | `x.unwrap_or(default)` |
| `x if x is not None else T.default()` | `x.unwrap_or_default()` |
| `f(x) if x is not None else None` | `x.map(f)` |
| `f(x) if f returns Optional` | `x.and_then(f)` |
| `x if x is not None else y` (both Opt) | `x.or(y)` |
| `getattr(obj, 'a', default)` | `obj.a.unwrap_or(default)` |
| `dict.get(key)` | `map.get(&key)` -> `Option<&V>` |
| `dict.get(key, default)` | `map.get(&key).cloned().unwrap_or(default)` |
| `x = None; ...; x = val` | `let x: Option<T> = None; x = Some(val)` |
| `return None` (error) | `return Err(SomeError)` |
| `return None` (not found) | `return Ok(None)` or `return None` |
| `assert x is not None` | `x.expect("reason")` |
| `if x:` (truthiness) | `if let Some(val) = x` |
| `[x for x in items if x is not None]` | `items.into_iter().flatten().collect()` |
| `next(x for x if pred, None)` | `items.iter().find(\|x\| pred(x))` |
| `x is not None and pred(x)` | `x.is_some_and(\|v\| pred(v))` |
| `(x, y) if both not None` | `x.zip(y)` -> `Option<(T, U)>` |

## Error Handling Patterns

| Python | Rust | Notes |
|--------|------|-------|
| `try: ... except: ...` | `match result { Ok(v) => ..., Err(e) => ... }` | Or `?` operator |
| `raise ValueError("msg")` | `return Err(AppError::Validation("msg".into()))` | Typed enum |
| `class AppError(Exception)` | `#[derive(thiserror::Error)] enum AppError` | thiserror |
| `except (TypeError, ValueError)` | `Err(AppError::Type(_) \| AppError::Value(_))` | Multi-match |
| `raise ... from cause` | `#[source] inner: OtherError` | thiserror `#[from]` |
| `try: ... finally: ...` | RAII / `Drop` impl | Automatic cleanup |
| `with open(f) as fp:` | `let fp = File::open(f)?;` + Drop | RAII |
| `except Exception as e: log(e); raise` | `.map_err(\|e\| { log(&e); e })?` | Log and propagate |
| `sys.exit(1)` | `std::process::exit(1)` or `Result` from main | Prefer Result |

## Class -> Struct Patterns

### Dunder -> Trait Mapping

| Python Dunder | Rust Trait | Notes |
|---------------|-----------|-------|
| `__repr__` | `Debug` | `#[derive(Debug)]` or manual |
| `__str__` | `Display` | Manual `impl fmt::Display` |
| `__eq__` | `PartialEq` | `#[derive(PartialEq)]` |
| `__ne__` | via `PartialEq` | Automatic |
| `__lt__/__le__/__gt__/__ge__` | `PartialOrd` / `Ord` | `#[derive(PartialOrd, Ord)]` |
| `__hash__` | `Hash` | `#[derive(Hash)]` requires `Eq` |
| `__bool__` | No trait | Use `fn is_empty(&self) -> bool` |
| `__len__` | No trait | Use `fn len(&self) -> usize` |
| `__iter__` | `IntoIterator` | `impl IntoIterator for &Type` |
| `__next__` | `Iterator` | `type Item` + `fn next()` |
| `__getitem__` | `Index` | `std::ops::Index` |
| `__setitem__` | `IndexMut` | `std::ops::IndexMut` |
| `__contains__` | No trait | `fn contains(&self, item: &T) -> bool` |
| `__add__` | `Add` | `std::ops::Add` |
| `__sub__` | `Sub` | `std::ops::Sub` |
| `__mul__` | `Mul` | `std::ops::Mul` |
| `__call__` | `Fn`/`FnMut`/`FnOnce` | Prefer closures |
| `__enter__`/`__exit__` | `Drop` + RAII | Scope-based cleanup |
| `__del__` | `Drop` | `impl Drop` |
| `__getattr__` | No equiv | Use explicit methods |
| `__class_getitem__` | Generics | `struct<T>` |

### Inheritance -> Composition

| Python | Rust |
|--------|------|
| `class B(A)` | `struct B { base: A }` + delegate, or trait |
| `class C(A, B)` (multiple) | `struct C` implements `trait A` + `trait B` |
| `class M(MixinA, MixinB, Base)` | `struct M` implements all traits |
| `super().__init__()` | `Self { base: Base::new(), ... }` |
| `super().method()` | Trait default method or delegation |
| `isinstance(x, T)` | `match` on enum or `downcast_ref::<T>()` |
| `@property` (getter) | `fn name(&self) -> &T` |
| `@prop.setter` | `fn set_name(&mut self, val: T)` |
| `@staticmethod` | Associated fn (no `&self`) |
| `@classmethod` | Associated fn (no `&self`) |
| Class var (immutable) | `const` or `static` |
| Class var (mutable) | `static` + `AtomicU64` / `LazyLock<Mutex<T>>` |
| `__slots__` | Struct fields (always "slotted") |

## Async Patterns

| Python asyncio | Rust tokio | Notes |
|----------------|-----------|-------|
| `async def f() -> T` | `async fn f() -> Result<T, E>` | Always return Result |
| `await coro` | `coro.await` | Postfix syntax |
| `asyncio.run(main())` | `#[tokio::main]` | Macro entry point |
| `asyncio.gather(a, b, c)` | `tokio::join!(a, b, c)` | Fixed count |
| `asyncio.gather(*coros)` | `futures::future::join_all(futs)` | Dynamic count |
| `asyncio.create_task(coro)` | `tokio::spawn(fut)` | Requires `Send + 'static` |
| `asyncio.sleep(secs)` | `tokio::time::sleep(Duration)` | Takes `Duration` |
| `asyncio.wait_for(c, timeout)` | `tokio::time::timeout(dur, fut)` | Returns `Result<T, Elapsed>` |
| `asyncio.shield(coro)` | `tokio::spawn` | No direct equiv |
| `asyncio.wait(FIRST_COMPLETED)` | `tokio::select!` | Select on futures |
| `asyncio.Queue()` | `tokio::sync::mpsc::channel` | MPSC channel |
| `asyncio.Queue(maxsize=N)` | `mpsc::channel(N)` | Bounded |
| `asyncio.Event()` | `tokio::sync::Notify` | Notify waiters |
| `asyncio.Lock()` | `tokio::sync::Mutex` | Async mutex |
| `asyncio.Semaphore(N)` | `tokio::sync::Semaphore` | Concurrency limiter |
| `async for item in aiter` | `while let Some(item) = stream.next().await` | `StreamExt` |
| `async with resource` | Scope + Drop | No async Drop |
| `loop.run_in_executor(fn)` | `tokio::task::spawn_blocking(fn)` | CPU-bound work |

### GIL Migration

| Python (GIL) | Rust (no GIL) | Fix |
|---------------|--------------|-----|
| `dict` shared across tasks | `HashMap` not thread-safe | `DashMap` or `Arc<RwLock<HashMap>>` |
| Shared mutable state | Needs synchronization | `Arc<Mutex<T>>` |
| `cls.counter += 1` | Not atomic | `AtomicU64` |
| `global_list.append(x)` | Not safe | `Arc<Mutex<Vec<T>>>` |

## pip -> Crate Mapping

| Python Package | Rust Crate | Version | Confidence |
|----------------|-----------|---------|------------|
| flask / fastapi / starlette / aiohttp(srv) | `axum` (+ `utoipa` for OpenAPI) | 0.8 | HIGH |
| django | `axum` + `sqlx` + `tera` | 0.8 | MEDIUM |
| uvicorn / gunicorn | `tokio` + `hyper` | 1 | HIGH |
| requests / httpx / aiohttp(cli) / urllib3 | `reqwest` | 0.12 | HIGH |
| tenacity | `backoff` / `tokio-retry` | 0.4 | HIGH |
| sqlalchemy / asyncpg / psycopg2 | `sqlx` or `diesel` | 0.8 / 2 | HIGH |
| tortoise-orm / django ORM | `sea-orm` | 1 | MEDIUM |
| pymongo / motor | `mongodb` | 3 | HIGH |
| redis-py / aioredis | `redis` | 0.27 | HIGH |
| pymysql / aiomysql | `sqlx` (mysql) | 0.8 | HIGH |
| sqlite3 / aiosqlite | `sqlx` (sqlite) / `rusqlite` | 0.8 | HIGH |
| alembic | `sqlx-cli` | 0.8 | MEDIUM |
| pydantic / marshmallow | `serde` + `validator` | 1 / 0.19 | HIGH |
| orjson / json | `serde_json` / `simd-json` | 1 | HIGH |
| msgpack | `rmp-serde` | 1 | HIGH |
| protobuf | `prost` | 0.13 | HIGH |
| toml | `toml` | 0.8 | HIGH |
| pyyaml | `serde_yaml` | 0.9 | HIGH |
| jsonschema | `jsonschema` | 0.26 | HIGH |
| pandas | `polars` | 0.46 | MEDIUM |
| numpy | `ndarray` | 0.16 | MEDIUM |
| pyarrow | `arrow` | 53 | HIGH |
| csv (stdlib) | `csv` | 1 | HIGH |
| openpyxl / xlrd | `calamine` + `xlsxwriter` | 0.26 | MEDIUM |
| click / typer / argparse | `clap` | 4 | HIGH |
| rich | `indicatif` + `colored` + `comfy-table` | 0.17 | MEDIUM |
| tqdm | `indicatif` | 0.17 | HIGH |
| tabulate | `comfy-table` / `tabled` | 7 | HIGH |
| questionary | `dialoguer` | 0.11 | HIGH |
| pytest / unittest | `#[test]` / `#[tokio::test]` | - | HIGH |
| unittest.mock / pytest-mock | `mockall` | 0.13 | HIGH |
| hypothesis | `proptest` | 1 | HIGH |
| faker | `fake` | 3 | HIGH |
| responses | `wiremock` | 0.6 | HIGH |
| pytest-cov | `cargo-llvm-cov` | - | HIGH |
| logging / loguru / structlog | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | HIGH |
| sentry-sdk | `sentry` | 0.35 | HIGH |
| prometheus-client | `metrics` + exporter | 0.23 | HIGH |
| opentelemetry | `opentelemetry` + `tracing-opentelemetry` | 0.28 | HIGH |
| pyjwt / python-jose | `jsonwebtoken` | 9 | HIGH |
| passlib / bcrypt | `argon2` / `bcrypt` | 0.5 / 0.16 | HIGH |
| cryptography | `ring` + `rustls` | 0.17 | HIGH |
| hashlib | `sha2` + `md-5` | 0.10 | HIGH |
| secrets | `rand` | 0.8 | HIGH |
| python-dotenv | `dotenvy` | 0.15 | HIGH |
| pydantic-settings | `config` + `envy` | 0.14 / 0.4 | MEDIUM |
| celery / dramatiq / rq | `apalis` | 0.6 | MEDIUM |
| schedule / apscheduler | `tokio-cron-scheduler` | 0.13 | HIGH |
| cachetools / lru_cache | `moka` / `cached` | 0.12 / 0.54 | HIGH |
| watchdog | `notify` | 7 | HIGH |
| tempfile | `tempfile` | 3 | HIGH |
| zipfile | `zip` | 2 | HIGH |
| websockets | `tokio-tungstenite` | 0.24 | HIGH |
| paramiko | `russh` | 0.46 | MEDIUM |
| smtplib | `lettre` | 0.11 | HIGH |
| jinja2 | `tera` | 1 | HIGH |
| beautifulsoup4 / lxml | `scraper` | 0.21 | HIGH |
| markdown | `pulldown-cmark` | 0.12 | HIGH |
| pillow | `image` | 0.25 | HIGH |
| itertools | `itertools` | 0.13 | HIGH |
| subprocess | `std::process::Command` | - | HIGH |
| multiprocessing | `rayon` | 1 | HIGH |
| base64 | `base64` | 0.22 | HIGH |
| glob | `glob` | 0.3 | HIGH |
| textwrap | `textwrap` | 0.16 | HIGH |
| difflib | `similar` | 2 | HIGH |

## Common Pattern Transforms

| Python Pattern | Rust Equivalent |
|----------------|-----------------|
| `@decorator` (logging) | `#[instrument]` or wrapper fn |
| `@decorator` (auth) | Axum extractor (`FromRequestParts`) |
| `@decorator` (retry) | Generic `retry()` async fn |
| `with ctx_mgr:` | RAII scope + `Drop` |
| `yield` (generator) | `Iterator` trait impl |
| `yield from` | `.flatten()` |
| `async yield` | `Stream` + `async_stream::stream!` |
| `[x for x in ...]` | `.iter().map().collect()` |
| `{k: v for ...}` | `.iter().map().collect::<HashMap>()` |
| `{x for ...}` | `.iter().collect::<HashSet>()` |
| `*args` | `&[T]` slice |
| `**kwargs` | `HashMap` or builder pattern |
| `global x` (immutable) | `static` / `OnceLock` |
| `global x` (mutable) | `LazyLock<Mutex<T>>` |
| Monkey patching | Trait objects / DI |
| Duck typing | Trait bounds (`impl Read`) |
| `f"Hello, {name}!"` | `format!("Hello, {name}!")` |
| `items[:3]` | `&items[..3]` |
| `items[-2:]` | `&items[items.len()-2..]` |
| `items[::-1]` | `items.iter().rev().collect()` |
| Walrus `:=` | `if let Some(x) = ...` |
| `0 < x < 100` | `(1..100).contains(&x)` |
| `first, *rest = items` | `let (first, rest) = items.split_first()` |
| `lambda x: x+1` | `\|x\| x + 1` |
| `map(fn, items)` | `items.iter().map(fn)` |
| `filter(fn, items)` | `items.iter().filter(fn)` |
| `zip(a, b)` | `a.iter().zip(b.iter())` |
| `enumerate(items)` | `items.iter().enumerate()` |
| `sorted(items, key=fn)` | `items.sort_by_key(fn)` |
| `any(pred(x) for ...)` | `items.iter().any(pred)` |
| `all(pred(x) for ...)` | `items.iter().all(pred)` |
| `isinstance(x, T)` | `match` on enum |
| `try/except` hierarchy | `thiserror` enum + `?` operator |
| `if __name__ == "__main__"` | `fn main()` |
| `__all__ = [...]` | `pub` visibility |
| `pass` / `...` | `todo!()` or `{}` |
