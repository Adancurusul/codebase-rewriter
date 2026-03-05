# 12 - Async Transform Mapping

**Output**: Contributes to `.migration-plan/mappings/async-strategy.md`

## Purpose

Choose the Rust async runtime and map every async/concurrent pattern from the source language to its Rust equivalent. This covers event loops, promises/futures, goroutines, async generators, channels, thread pools, and concurrent data structures. Every async call site in the source must have a concrete Rust async strategy.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `async-model.md` -- complete inventory of async patterns, concurrency model, threading usage
- `architecture.md` -- identifies server model (single-threaded event loop, multi-threaded, actor-based)
- `dependency-tree.md` -- identifies async-related dependencies (event emitters, task queues, etc.)

Extract every instance of:
- Async function definitions
- Promise/Future creation and consumption
- Concurrent execution (Promise.all, asyncio.gather, goroutines)
- Racing/selecting (Promise.race, select!)
- Channels and message passing
- Event emitters and pub/sub patterns
- Timers, delays, intervals
- Thread/worker pool usage
- Streaming/async iteration
- Callbacks and callback-to-async bridges

### Step 2: Choose async runtime

**Decision matrix:**

| Criteria | tokio | async-std | smol | No async |
|----------|-------|-----------|------|----------|
| Web server (axum, actix-web, tonic) | **Best** | Possible | No | No |
| CLI tool with some async I/O | Good | Good | **Best** | Maybe |
| Pure computation, no I/O | No | No | No | **Best** |
| Need async channels | **Best** | Good | Basic | No |
| Need timers/intervals | **Best** | Good | Basic | `std::thread::sleep` |
| Need multi-threaded runtime | **Best** | Good | Good | `std::thread` |
| Need single-threaded runtime | Good | Good | **Best** | N/A |
| Ecosystem crate compatibility | **Best** | Limited | Limited | N/A |

**Default choice**: `tokio` with `#[tokio::main]` and multi-threaded runtime unless there is a specific reason not to.

```rust
// Standard tokio setup
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Application entry point
    Ok(())
}
```

### Step 3: Map async patterns

For EACH async pattern found in the source, determine the Rust equivalent using this conversion table:

#### Async Function Declaration

| Source | Rust |
|--------|------|
| `async function foo(): Promise<T>` (TS) | `async fn foo() -> Result<T, E>` |
| `async def foo() -> T:` (Python) | `async fn foo() -> Result<T, E>` |
| `func foo() (T, error)` with goroutine (Go) | `async fn foo() -> Result<T, E>` |

```rust
// Basic async function
async fn fetch_user(id: Uuid) -> Result<User, AppError> {
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_one(&pool)
        .await?;
    Ok(user)
}
```

#### Concurrent Execution (Join)

| Source | Rust |
|--------|------|
| `Promise.all([a(), b(), c()])` (TS) | `tokio::join!(a(), b(), c())` |
| `asyncio.gather(a(), b(), c())` (Python) | `tokio::join!(a(), b(), c())` |
| `go func(); go func()` + `WaitGroup` (Go) | `tokio::join!(a(), b(), c())` |

```rust
// Fixed number of concurrent tasks (compile-time known)
let (users, orders, stats) = tokio::join!(
    fetch_users(),
    fetch_orders(),
    compute_stats(),
);
let users = users?;
let orders = orders?;
let stats = stats?;

// Dynamic number of concurrent tasks
let handles: Vec<_> = ids
    .iter()
    .map(|id| tokio::spawn(fetch_item(*id)))
    .collect();

let results: Vec<Result<Item, _>> = futures::future::join_all(handles)
    .await
    .into_iter()
    .map(|r| r.expect("task panicked"))
    .collect();

// Concurrent with concurrency limit (like p-limit in Node.js)
use futures::stream::{self, StreamExt};
let results: Vec<Item> = stream::iter(ids)
    .map(|id| async move { fetch_item(id).await })
    .buffer_unordered(10) // max 10 concurrent
    .collect()
    .await;
```

#### Racing / Select

| Source | Rust |
|--------|------|
| `Promise.race([a(), b()])` (TS) | `tokio::select!` |
| `asyncio.wait(FIRST_COMPLETED)` (Python) | `tokio::select!` |
| `select { case <-ch1: case <-ch2: }` (Go) | `tokio::select!` |

```rust
use tokio::time::{timeout, Duration};

// Race: first to complete wins
let result = tokio::select! {
    val = fetch_from_primary() => val,
    val = fetch_from_fallback() => val,
};

// Timeout pattern (very common)
let result = timeout(Duration::from_secs(5), fetch_data())
    .await
    .map_err(|_| AppError::External(ExternalError::Timeout {
        service: "data-service".into(),
        timeout_ms: 5000,
    }))?;

// Select with cancellation
loop {
    tokio::select! {
        msg = rx.recv() => {
            match msg {
                Some(m) => handle_message(m).await,
                None => break, // channel closed
            }
        }
        _ = shutdown.recv() => {
            tracing::info!("shutting down");
            break;
        }
    }
}
```

#### Event Emitters / Pub-Sub

| Source | Rust |
|--------|------|
| `EventEmitter.on("event", handler)` (TS) | `tokio::sync::broadcast` or `tokio::sync::watch` |
| `signal.connect(handler)` (Python) | Channel-based pattern |
| `chan <- value` (Go) | `tokio::sync::mpsc` |

```rust
use tokio::sync::{broadcast, mpsc, watch};

// One-to-many broadcast (like EventEmitter)
let (tx, _) = broadcast::channel::<Event>(100);
// Subscribe:
let mut rx = tx.subscribe();
tokio::spawn(async move {
    while let Ok(event) = rx.recv().await {
        handle_event(event).await;
    }
});
// Emit:
tx.send(Event::UserCreated { id: user_id })?;

// Many-to-one channel (like worker queue)
let (tx, mut rx) = mpsc::channel::<Job>(100);
tokio::spawn(async move {
    while let Some(job) = rx.recv().await {
        process_job(job).await;
    }
});

// Watch channel (latest-value, like reactive state)
let (tx, rx) = watch::channel(AppConfig::default());
// Update config:
tx.send(new_config)?;
// Read latest:
let config = rx.borrow().clone();
```

#### Timers and Intervals

| Source | Rust |
|--------|------|
| `setTimeout(fn, ms)` (TS) | `tokio::time::sleep` |
| `setInterval(fn, ms)` (TS) | `tokio::time::interval` |
| `asyncio.sleep(secs)` (Python) | `tokio::time::sleep` |
| `time.Tick(duration)` (Go) | `tokio::time::interval` |

```rust
use tokio::time::{self, Duration, Instant};

// Delay (setTimeout)
time::sleep(Duration::from_millis(500)).await;

// Interval (setInterval)
let mut interval = time::interval(Duration::from_secs(60));
loop {
    interval.tick().await;
    run_periodic_task().await;
}

// Debounce pattern
let mut last_event = Instant::now();
let debounce_duration = Duration::from_millis(300);
loop {
    tokio::select! {
        event = rx.recv() => {
            last_event = Instant::now();
            pending_event = Some(event);
        }
        _ = time::sleep_until(last_event + debounce_duration), if pending_event.is_some() => {
            process(pending_event.take().unwrap()).await;
        }
    }
}
```

#### Streaming / Async Iteration

| Source | Rust |
|--------|------|
| `for await (const item of stream)` (TS) | `while let Some(item) = stream.next().await` |
| `async for item in aiter:` (Python) | `while let Some(item) = stream.next().await` |
| `for item := range channel` (Go) | `while let Some(item) = rx.recv().await` |

```rust
use futures::StreamExt;
use tokio_stream::wrappers::ReceiverStream;

// Consuming an async stream
let mut stream = fetch_paginated_results();
while let Some(result) = stream.next().await {
    let item = result?;
    process(item).await;
}

// Creating an async stream from a channel
let (tx, rx) = mpsc::channel(100);
let stream = ReceiverStream::new(rx);

// Stream combinators
let processed: Vec<Output> = stream
    .filter(|item| futures::future::ready(item.is_valid()))
    .map(|item| transform(item))
    .collect()
    .await;
```

#### Callbacks to Async

```rust
// Wrapping a callback-based API in a Future
use tokio::sync::oneshot;

async fn callback_to_future() -> Result<Data, Error> {
    let (tx, rx) = oneshot::channel();

    legacy_api_with_callback(|result| {
        let _ = tx.send(result);
    });

    rx.await.map_err(|_| Error::Internal("callback dropped".into()))?
}
```

#### Spawning Background Tasks

| Source | Rust |
|--------|------|
| `process.nextTick(fn)` / fire-and-forget (TS) | `tokio::spawn` |
| `asyncio.create_task(coro)` (Python) | `tokio::spawn` |
| `go func() { ... }()` (Go) | `tokio::spawn` |

```rust
// Fire-and-forget task
tokio::spawn(async move {
    if let Err(e) = send_notification(user_id).await {
        tracing::error!(error = ?e, "failed to send notification");
    }
});

// Task with result
let handle = tokio::spawn(async move {
    compute_expensive_thing().await
});
let result = handle.await??; // First ? for JoinError, second for task's Result

// CPU-bound work (don't block async runtime)
let result = tokio::task::spawn_blocking(move || {
    compute_hash(&data) // synchronous, CPU-intensive
}).await?;
```

### Step 4: Produce async strategy document

For EACH async call site in the source, map it to the appropriate Rust pattern.

## Template

```markdown
# Async Strategy

Source: {project_name}
Generated: {date}

## Runtime Choice

**Selected runtime**: tokio {version}
**Rationale**: {why this runtime was chosen}

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
futures = "0.3"
tokio-stream = "0.1"
```

**Entry point**:
```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::init();
    // ...
    Ok(())
}
```

## Async Pattern Conversion Table

| # | Source Pattern | File | Rust Pattern | Notes |
|---|--------------|------|-------------|-------|
| 1 | `Promise.all([...])` | [{file}:{line}] | `tokio::join!` | Fixed count |
| 2 | `await fetch(url)` | [{file}:{line}] | `reqwest::get(url).await?` | Add timeout |
| 3 | `setInterval(fn, 60000)` | [{file}:{line}] | `tokio::time::interval` | Background task |
| 4 | `EventEmitter.emit("x")` | [{file}:{line}] | `broadcast::Sender::send` | 100 buffer |
| ... | ... | ... | ... | ... |

## Channel Architecture

```text
                   broadcast::channel
Producer  ------>  [Event Bus]  ------> Consumer A
                                 -----> Consumer B
                                 -----> Consumer C

                   mpsc::channel
Worker 1  ------>
Worker 2  ------> [Job Queue] -------> Processor
Worker 3  ------>
```

## Concurrency Patterns Mapped

### Pattern: {Name}
**Source**: [{file}:{line}](../src/{file}#L{line})
**Before** ({source_language}):
```typescript
const results = await Promise.all(
  users.map(user => enrichUserData(user))
);
```

**After** (Rust):
```rust
use futures::stream::{self, StreamExt};

let results: Vec<EnrichedUser> = stream::iter(users)
    .map(|user| async move {
        enrich_user_data(&user).await
    })
    .buffer_unordered(10)
    .try_collect()
    .await?;
```

## Graceful Shutdown

```rust
use tokio::signal;
use tokio::sync::broadcast;

async fn run_server() -> anyhow::Result<()> {
    let (shutdown_tx, _) = broadcast::channel::<()>(1);

    // Spawn background tasks with shutdown receiver
    let mut shutdown_rx = shutdown_tx.subscribe();
    tokio::spawn(async move {
        loop {
            tokio::select! {
                _ = do_periodic_work() => {},
                _ = shutdown_rx.recv() => break,
            }
        }
    });

    // Wait for shutdown signal
    signal::ctrl_c().await?;
    tracing::info!("shutdown signal received");
    let _ = shutdown_tx.send(());

    Ok(())
}
```

## Thread Safety Annotations

| Type | `Send` | `Sync` | Can cross `.await`? | Notes |
|------|--------|--------|---------------------|-------|
| `Arc<T>` where T: Send+Sync | Yes | Yes | Yes | Default for shared state |
| `Rc<T>` | No | No | No | Single-thread only |
| `MutexGuard` (std) | No* | No | **No** | Do not hold across await |
| `MutexGuard` (tokio) | Yes | Yes | Yes | Async-aware mutex |
| `Receiver` (mpsc) | Yes | No | Yes | Cannot be shared |

*Use `tokio::sync::Mutex` when the lock must be held across `.await` points.*
```

## Completeness Check

- [ ] Async runtime is chosen with rationale
- [ ] Every async function in the source has a Rust `async fn` equivalent
- [ ] Every concurrent execution pattern (join/gather/waitgroup) is mapped
- [ ] Every racing/select pattern is mapped
- [ ] Every event emitter is converted to a channel pattern
- [ ] Every timer/interval/delay is mapped
- [ ] Every background task spawn is mapped
- [ ] Streaming/async iteration patterns are mapped
- [ ] Callback-to-async bridges are designed (if needed)
- [ ] Graceful shutdown strategy is defined
- [ ] Thread safety (`Send`/`Sync`) constraints are documented
- [ ] Concurrency limits are defined for unbounded patterns
- [ ] `tokio::task::spawn_blocking` is used for CPU-bound work
