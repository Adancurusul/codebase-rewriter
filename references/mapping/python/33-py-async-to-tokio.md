# 33 - Python asyncio to Rust Tokio Mapping

**Output**: `.migration-plan/mappings/async-mapping.md`

## Purpose

Map every Python `asyncio` pattern -- `async def`, `await`, `asyncio.gather()`, `asyncio.create_task()`, queues, events, locks, semaphores, and async iteration -- to its Rust `tokio` equivalent. Python's async model runs on a single-threaded event loop with the GIL; Rust's tokio is a multi-threaded work-stealing runtime with true parallelism. This mapping addresses not just syntax translation but also the fundamental concurrency model differences: Python async code that was "concurrent but not parallel" becomes genuinely parallel in Rust, requiring proper `Send + Sync` bounds and thread-safe data structures.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `async-model.md` -- inventory of all async functions, coroutines, tasks, and synchronization primitives
- `architecture.md` -- identifies the event loop setup, task spawning patterns, and server model
- `dependency-tree.md` -- identifies async libraries (aiohttp, asyncpg, aiofiles, etc.)

Extract every instance of:
- `async def` function definitions
- `await` expressions
- `asyncio.gather()` calls
- `asyncio.create_task()` calls
- `asyncio.Queue` / `asyncio.PriorityQueue`
- `asyncio.Event` / `asyncio.Condition`
- `asyncio.Lock` / `asyncio.Semaphore`
- `asyncio.sleep()`
- `asyncio.wait()` / `asyncio.wait_for()` / `asyncio.shield()`
- `async for` loops
- `async with` context managers
- `asyncio.run()` entry points
- `asyncio.get_event_loop()` usage
- `aiohttp` client/server usage
- `asyncpg` / `aiomysql` database usage
- `aiofiles` file I/O
- `asyncio.StreamReader` / `asyncio.StreamWriter`
- `asyncio.subprocess` usage
- Thread pool executor usage (`loop.run_in_executor`)

### Step 2: For each asyncio pattern, determine tokio equivalent

**Core syntax mapping:**

| Python asyncio | Rust tokio | Notes |
|---------------|-----------|-------|
| `async def foo() -> T:` | `async fn foo() -> Result<T, E>` | Always return Result in Rust |
| `await coro` | `coro.await` | Postfix `.await` in Rust |
| `asyncio.run(main())` | `#[tokio::main]` | Macro-based entry point |
| `asyncio.run(main())` (custom) | `tokio::runtime::Runtime::new()` | Manual runtime construction |
| `asyncio.gather(a(), b(), c())` | `tokio::join!(a(), b(), c())` | Fixed count, compile-time |
| `asyncio.gather(*coros)` | `futures::future::join_all(futs)` | Dynamic count |
| `asyncio.create_task(coro)` | `tokio::spawn(fut)` | Spawns on runtime; requires `Send + 'static` |
| `asyncio.sleep(secs)` | `tokio::time::sleep(Duration)` | Takes `Duration`, not float |
| `asyncio.wait_for(coro, timeout)` | `tokio::time::timeout(dur, fut)` | Returns `Result<T, Elapsed>` |
| `asyncio.shield(coro)` | No direct equiv; use `tokio::spawn` | Shield = "don't cancel me" |
| `asyncio.wait(tasks, FIRST_COMPLETED)` | `tokio::select!` | Select on multiple futures |
| `asyncio.Queue()` | `tokio::sync::mpsc::channel` | Multi-producer, single-consumer |
| `asyncio.Queue(maxsize=N)` | `tokio::sync::mpsc::channel(N)` | Bounded channel |
| `asyncio.Event()` | `tokio::sync::Notify` | Notify one or all waiters |
| `asyncio.Lock()` | `tokio::sync::Mutex` | Async-aware mutex |
| `asyncio.Semaphore(N)` | `tokio::sync::Semaphore` | Concurrency limiter |
| `asyncio.Condition()` | `tokio::sync::watch` or manual | Condition variable pattern |
| `async for item in aiter:` | `while let Some(item) = stream.next().await` | Uses `StreamExt` |
| `async with resource:` | Scope + Drop or explicit cleanup | No async drop in Rust |
| `loop.run_in_executor(None, fn)` | `tokio::task::spawn_blocking(fn)` | CPU-bound work |
| `loop.run_in_executor(executor, fn)` | `tokio::task::spawn_blocking(fn)` | Thread pool |

**GIL implications -- critical differences:**

| Python (with GIL) | Rust (without GIL) | Impact |
|-------------------|-------------------|--------|
| `asyncio.gather()` is concurrent but NOT parallel | `tokio::join!` is truly parallel | Data shared across tasks must be `Send + Sync` |
| Shared mutable state is "safe" due to GIL | Shared state needs `Arc<Mutex<T>>` | Must add synchronization primitives |
| `dict` is "thread-safe" for single operations | `HashMap` is NOT thread-safe | Use `DashMap` or `Arc<RwLock<HashMap>>` |
| No data races possible (GIL prevents them) | Data races caught at compile time | Borrow checker enforces safety |
| CPU-bound async blocks the loop | CPU-bound async blocks one worker | Use `spawn_blocking` for CPU work |

### Step 3: Produce async mapping document

For EACH async call site in the source, produce:
1. Source location and code snippet
2. Python async pattern classification
3. Rust tokio equivalent with compilable code
4. Any `Send + Sync` implications noted

## Code Examples

### Example 1: Basic async function with await

Python:
```python
import asyncio
import aiohttp

async def fetch_url(url: str) -> str:
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.text()

async def main():
    content = await fetch_url("https://example.com")
    print(content)

asyncio.run(main())
```

Rust:
```rust
use reqwest;

async fn fetch_url(url: &str) -> Result<String, reqwest::Error> {
    let content = reqwest::get(url).await?.text().await?;
    Ok(content)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let content = fetch_url("https://example.com").await?;
    println!("{content}");
    Ok(())
}
```

### Example 2: asyncio.gather() to tokio::join! and join_all

Python:
```python
async def fetch_all(urls: list[str]) -> list[str]:
    # Fixed set of tasks
    title, body, comments = await asyncio.gather(
        fetch_title(post_id),
        fetch_body(post_id),
        fetch_comments(post_id),
    )

    # Dynamic set of tasks
    tasks = [fetch_url(url) for url in urls]
    results = await asyncio.gather(*tasks)
    return results

async def fetch_with_limit(urls: list[str], limit: int = 5) -> list[str]:
    semaphore = asyncio.Semaphore(limit)

    async def limited_fetch(url: str) -> str:
        async with semaphore:
            return await fetch_url(url)

    return await asyncio.gather(*[limited_fetch(url) for url in urls])
```

Rust:
```rust
use futures::stream::{self, StreamExt};

async fn fetch_all(post_id: i64, urls: &[String]) -> Result<Vec<String>, AppError> {
    // Fixed set of tasks -- tokio::join! (compile-time known)
    let (title, body, comments) = tokio::join!(
        fetch_title(post_id),
        fetch_body(post_id),
        fetch_comments(post_id),
    );
    let title = title?;
    let body = body?;
    let comments = comments?;

    // Dynamic set of tasks -- futures::future::join_all
    let handles: Vec<_> = urls
        .iter()
        .map(|url| {
            let url = url.clone();
            tokio::spawn(async move { fetch_url(&url).await })
        })
        .collect();

    let results: Vec<String> = futures::future::join_all(handles)
        .await
        .into_iter()
        .map(|r| r.expect("task panicked"))
        .collect::<Result<Vec<_>, _>>()?;

    Ok(results)
}

// Concurrency-limited fetching (replaces Semaphore-based pattern)
async fn fetch_with_limit(urls: &[String], limit: usize) -> Result<Vec<String>, AppError> {
    let results: Vec<Result<String, AppError>> = stream::iter(urls)
        .map(|url| async move { fetch_url(url).await })
        .buffer_unordered(limit)
        .collect()
        .await;

    results.into_iter().collect()
}
```

### Example 3: asyncio.create_task() to tokio::spawn

Python:
```python
async def handle_request(request: Request) -> Response:
    # Fire-and-forget background task
    asyncio.create_task(log_request(request))

    # Task with result
    task = asyncio.create_task(compute_recommendation(request.user_id))

    # Do other work while task runs
    user = await fetch_user(request.user_id)

    # Wait for the background task
    recommendation = await task

    return Response(user=user, recommendation=recommendation)
```

Rust:
```rust
async fn handle_request(request: Request) -> Result<Response, AppError> {
    // Fire-and-forget background task
    let req_clone = request.clone();
    tokio::spawn(async move {
        if let Err(e) = log_request(&req_clone).await {
            tracing::error!(error = ?e, "failed to log request");
        }
    });

    // Task with result -- must be Send + 'static
    let user_id = request.user_id;
    let rec_handle = tokio::spawn(async move {
        compute_recommendation(user_id).await
    });

    // Do other work concurrently
    let user = fetch_user(request.user_id).await?;

    // Await the spawned task
    let recommendation = rec_handle.await
        .map_err(|e| AppError::Internal(format!("task panicked: {e}")))?
        ?;

    Ok(Response { user, recommendation })
}
```

### Example 4: asyncio.Queue to tokio::sync::mpsc

Python:
```python
import asyncio

async def producer(queue: asyncio.Queue, items: list[str]):
    for item in items:
        await queue.put(item)
        print(f"Produced: {item}")
    await queue.put(None)  # Sentinel to signal completion

async def consumer(queue: asyncio.Queue):
    while True:
        item = await queue.get()
        if item is None:
            break
        print(f"Consumed: {item}")
        await process_item(item)
        queue.task_done()

async def main():
    queue = asyncio.Queue(maxsize=10)
    items = ["a", "b", "c", "d", "e"]

    await asyncio.gather(
        producer(queue, items),
        consumer(queue),
    )
```

Rust:
```rust
use tokio::sync::mpsc;

async fn producer(tx: mpsc::Sender<String>, items: Vec<String>) {
    for item in items {
        tracing::info!(item = %item, "produced");
        if tx.send(item).await.is_err() {
            tracing::warn!("receiver dropped");
            break;
        }
    }
    // Dropping tx signals completion (no sentinel needed)
}

async fn consumer(mut rx: mpsc::Receiver<String>) {
    while let Some(item) = rx.recv().await {
        tracing::info!(item = %item, "consumed");
        process_item(&item).await;
    }
    // Loop ends when all senders are dropped
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let (tx, rx) = mpsc::channel::<String>(10);  // bounded, maxsize=10
    let items = vec!["a", "b", "c", "d", "e"]
        .into_iter()
        .map(String::from)
        .collect();

    let producer_handle = tokio::spawn(producer(tx, items));
    let consumer_handle = tokio::spawn(consumer(rx));

    // Wait for both to complete
    let (p, c) = tokio::join!(producer_handle, consumer_handle);
    p?;
    c?;
    Ok(())
}
```

### Example 5: asyncio.Lock and asyncio.Semaphore

Python:
```python
import asyncio

class RateLimiter:
    def __init__(self, max_concurrent: int, per_second: float):
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.lock = asyncio.Lock()
        self.tokens = per_second
        self.last_refill = asyncio.get_event_loop().time()

    async def acquire(self):
        await self.semaphore.acquire()
        async with self.lock:
            now = asyncio.get_event_loop().time()
            elapsed = now - self.last_refill
            if elapsed < 1.0 / self.tokens:
                await asyncio.sleep(1.0 / self.tokens - elapsed)
            self.last_refill = asyncio.get_event_loop().time()

    def release(self):
        self.semaphore.release()
```

Rust:
```rust
use std::sync::Arc;
use tokio::sync::{Mutex, Semaphore, SemaphorePermit};
use tokio::time::{Duration, Instant};

pub struct RateLimiter {
    semaphore: Arc<Semaphore>,
    state: Mutex<RateLimiterState>,
    interval: Duration,
}

struct RateLimiterState {
    last_refill: Instant,
}

impl RateLimiter {
    pub fn new(max_concurrent: usize, per_second: f64) -> Self {
        Self {
            semaphore: Arc::new(Semaphore::new(max_concurrent)),
            state: Mutex::new(RateLimiterState {
                last_refill: Instant::now(),
            }),
            interval: Duration::from_secs_f64(1.0 / per_second),
        }
    }

    pub async fn acquire(&self) -> Result<SemaphorePermit<'_>, tokio::sync::AcquireError> {
        let permit = self.semaphore.acquire().await?;

        {
            let mut state = self.state.lock().await;
            let now = Instant::now();
            let elapsed = now - state.last_refill;
            if elapsed < self.interval {
                tokio::time::sleep(self.interval - elapsed).await;
            }
            state.last_refill = Instant::now();
        }

        Ok(permit)
        // SemaphorePermit is returned; dropping it releases the permit (RAII)
    }
}
```

### Example 6: asyncio.Event to tokio::sync::Notify

Python:
```python
import asyncio

class Coordinator:
    def __init__(self):
        self.ready_event = asyncio.Event()
        self.shutdown_event = asyncio.Event()

    async def wait_until_ready(self):
        await self.ready_event.wait()

    def signal_ready(self):
        self.ready_event.set()

    async def run(self):
        # Initialize
        await self.setup()
        self.signal_ready()

        # Run until shutdown
        await self.shutdown_event.wait()
        await self.cleanup()
```

Rust:
```rust
use tokio::sync::Notify;
use std::sync::Arc;

pub struct Coordinator {
    ready: Arc<Notify>,
    shutdown: Arc<Notify>,
}

impl Coordinator {
    pub fn new() -> Self {
        Self {
            ready: Arc::new(Notify::new()),
            shutdown: Arc::new(Notify::new()),
        }
    }

    pub async fn wait_until_ready(&self) {
        self.ready.notified().await;
    }

    pub fn signal_ready(&self) {
        self.ready.notify_waiters(); // Notify all waiters
    }

    pub async fn run(&self) -> anyhow::Result<()> {
        self.setup().await?;
        self.signal_ready();

        // Run until shutdown signal
        self.shutdown.notified().await;
        self.cleanup().await?;
        Ok(())
    }

    pub fn signal_shutdown(&self) {
        self.shutdown.notify_one();
    }

    async fn setup(&self) -> anyhow::Result<()> { /* ... */ Ok(()) }
    async fn cleanup(&self) -> anyhow::Result<()> { /* ... */ Ok(()) }
}
```

### Example 7: async for (async iteration) to Stream

Python:
```python
async def read_lines(path: str):
    """Async generator yielding lines from a file."""
    async with aiofiles.open(path) as f:
        async for line in f:
            yield line.strip()

async def process_large_file(path: str):
    async for line in read_lines(path):
        await process_line(line)

async def paginated_fetch(url: str):
    """Async generator for paginated API."""
    page = 1
    while True:
        response = await fetch_page(url, page)
        if not response["items"]:
            break
        for item in response["items"]:
            yield item
        page += 1
```

Rust:
```rust
use futures::stream::{self, Stream, StreamExt};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::fs::File;
use std::pin::Pin;

// Async line reader using tokio streams
fn read_lines(
    path: &std::path::Path,
) -> impl Stream<Item = Result<String, std::io::Error>> + '_ {
    async_stream::stream! {
        let file = File::open(path).await?;
        let reader = BufReader::new(file);
        let mut lines = reader.lines();
        while let Some(line) = lines.next_line().await? {
            yield Ok(line);
        }
    }
}

async fn process_large_file(path: &std::path::Path) -> anyhow::Result<()> {
    let mut stream = std::pin::pin!(read_lines(path));
    while let Some(line) = stream.next().await {
        let line = line?;
        process_line(&line).await;
    }
    Ok(())
}

// Paginated fetch as a stream
fn paginated_fetch(
    client: &reqwest::Client,
    url: String,
) -> impl Stream<Item = Result<Item, reqwest::Error>> + '_ {
    async_stream::stream! {
        let mut page = 1u32;
        loop {
            let response: PageResponse = client
                .get(&url)
                .query(&[("page", page)])
                .send()
                .await?
                .json()
                .await?;

            if response.items.is_empty() {
                break;
            }

            for item in response.items {
                yield Ok(item);
            }
            page += 1;
        }
    }
}
```

### Example 8: asyncio.run() and event loop management

Python:
```python
import asyncio
import signal

async def serve():
    server = await start_server()
    print(f"Server running on {server.address}")

    # Handle graceful shutdown
    loop = asyncio.get_running_loop()
    stop = loop.create_future()

    def handle_signal():
        stop.set_result(None)

    loop.add_signal_handler(signal.SIGINT, handle_signal)
    loop.add_signal_handler(signal.SIGTERM, handle_signal)

    await stop
    await server.close()
    print("Server shut down")

if __name__ == "__main__":
    asyncio.run(serve())
```

Rust:
```rust
use tokio::net::TcpListener;
use tokio::signal;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let listener = TcpListener::bind("0.0.0.0:3000").await?;
    tracing::info!(addr = %listener.local_addr()?, "server running");

    let app = build_router();

    // axum::serve handles graceful shutdown natively
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    tracing::info!("server shut down");
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}
```

## Async Library Mapping

| Python Library | Rust Equivalent | Notes |
|---------------|-----------------|-------|
| `aiohttp` (client) | `reqwest` 0.12 | Async HTTP client with connection pooling |
| `aiohttp` (server) | `axum` 0.8 | HTTP server framework |
| `asyncpg` | `sqlx` 0.8 (with `postgres` feature) | Compile-time SQL checking |
| `aiomysql` | `sqlx` 0.8 (with `mysql` feature) | MySQL async driver |
| `aioredis` | `redis` 0.27 (with `tokio-comp` feature) | Async Redis client |
| `aiofiles` | `tokio::fs` | Built-in async file I/O |
| `aiodns` | `trust-dns-resolver` | Async DNS resolution |
| `websockets` | `tokio-tungstenite` 0.24 | WebSocket client/server |
| `uvloop` | Not needed | tokio's scheduler is already highly optimized |
| `async_timeout` | `tokio::time::timeout` | Built into tokio |
| `aiohttp_session` | `tower-sessions` | Session middleware |
| `celery` (async) | `tokio::spawn` + `mpsc` or `apalis` | Task queue patterns |

## Template

```markdown
# Async Pattern Mapping (Python asyncio -> Rust tokio)

Source: {project_name}
Generated: {date}

## Runtime Configuration

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
futures = "0.3"
async-stream = "0.3"
tokio-stream = "0.1"
reqwest = { version = "0.12", features = ["json"] }
```

## Async Function Inventory

| # | Python Function | File:Line | Rust Function | Send+Sync? | Notes |
|---|----------------|-----------|---------------|------------|-------|
| 1 | `async def fetch_users()` | [{file}:{line}] | `async fn fetch_users()` | Yes | Uses reqwest |
| 2 | `async def process_queue()` | [{file}:{line}] | `async fn process_queue()` | Yes | mpsc consumer |
| ... | ... | ... | ... | ... | ... |

## Concurrency Pattern Conversion Table

| # | Python Pattern | File:Line | Rust Pattern | Notes |
|---|---------------|-----------|-------------|-------|
| 1 | `asyncio.gather(a, b, c)` | [{file}:{line}] | `tokio::join!` | Fixed count |
| 2 | `asyncio.gather(*tasks)` | [{file}:{line}] | `join_all` + `spawn` | Dynamic count |
| 3 | `asyncio.create_task(bg)` | [{file}:{line}] | `tokio::spawn` | Fire-and-forget |
| 4 | `asyncio.Queue()` | [{file}:{line}] | `mpsc::channel` | Producer/consumer |
| 5 | `asyncio.Semaphore(N)` | [{file}:{line}] | `buffer_unordered(N)` | Concurrency limit |
| ... | ... | ... | ... | ... |

## GIL Migration Notes

List each place where Python's GIL provided implicit safety that Rust requires explicit handling:

| Shared State | Python Safety | Rust Safety | Migration |
|-------------|--------------|-------------|-----------|
| `self.cache = {}` | GIL protects dict | `Arc<DashMap<K,V>>` | Add Arc + concurrent map |
| `cls.counter += 1` | GIL protects int | `AtomicU64` | Use atomic |
| `global_list.append(x)` | GIL protects list | `Arc<Mutex<Vec<T>>>` | Add synchronization |
```

## Completeness Check

- [ ] Every `async def` has a Rust `async fn` equivalent
- [ ] Every `await` expression has a `.await` equivalent
- [ ] Every `asyncio.gather()` is mapped to `tokio::join!` or `join_all`
- [ ] Every `asyncio.create_task()` is mapped to `tokio::spawn` with `Send + 'static` verified
- [ ] Every `asyncio.Queue` is mapped to `tokio::sync::mpsc` with correct bound
- [ ] Every `asyncio.Event` is mapped to `tokio::sync::Notify`
- [ ] Every `asyncio.Lock` is mapped to `tokio::sync::Mutex`
- [ ] Every `asyncio.Semaphore` is mapped to `tokio::sync::Semaphore` or `buffer_unordered`
- [ ] Every `asyncio.sleep()` is mapped to `tokio::time::sleep(Duration)`
- [ ] Every `async for` is mapped to `StreamExt::next()` pattern
- [ ] Every `async with` is mapped to scope-based RAII or explicit cleanup
- [ ] Every `asyncio.run()` is mapped to `#[tokio::main]`
- [ ] GIL-dependent shared state is identified and given proper synchronization
- [ ] All spawned tasks are verified to be `Send + 'static`
- [ ] CPU-bound work uses `tokio::task::spawn_blocking()`
- [ ] Graceful shutdown is designed with signal handling
- [ ] All async libraries (aiohttp, asyncpg, etc.) have Rust crate equivalents
