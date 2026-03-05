# 23 - TypeScript Promise/Async to Rust Future/Tokio Mapping

**Output**: `.migration-plan/mappings/async-mapping.md`

## Purpose

Map every TypeScript Promise and async/await pattern to Rust's `Future` and `tokio` async runtime equivalents. TypeScript runs on a single-threaded event loop (Node.js), while Rust's tokio provides a multi-threaded async runtime. This fundamental difference affects concurrency patterns, shared state management, error propagation, and cancellation. Every async call site, promise chain, concurrent execution pattern, timer, event emitter, and streaming API in the source must receive a concrete tokio-based Rust implementation.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `async-model.md` -- complete inventory of async patterns, event emitters, timers, streams
- `architecture.md` -- server model, middleware pipeline, background job architecture
- `dependency-tree.md` -- async-related npm packages (e.g., p-limit, p-queue, rxjs, event-related)

Extract every instance of:
- `async function` / `async () =>` declarations
- `await` expressions
- `new Promise()` constructor usage
- `Promise.all()`, `Promise.allSettled()`, `Promise.race()`, `Promise.any()`
- `.then()` / `.catch()` / `.finally()` chains
- `setTimeout` / `setInterval` / `clearTimeout` / `clearInterval`
- `EventEmitter` usage (`.on()`, `.emit()`, `.once()`, `.removeListener()`)
- Callback-based APIs and callback-to-promise wrappers
- `process.nextTick()` / `setImmediate()`
- Streams (Readable, Writable, Transform, pipeline)
- Generator functions (`function*`) and async generators (`async function*`)
- Worker threads and `worker_threads` module
- AbortController / AbortSignal for cancellation

### Step 2: Choose async runtime configuration

**Standard tokio setup for TypeScript migrations:**

```rust
// Cargo.toml
[dependencies]
tokio = { version = "1", features = ["full"] }
futures = "0.3"
tokio-stream = "0.1"
tokio-util = "0.7"

// main.rs
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Application startup
    Ok(())
}
```

**Key difference from Node.js**: Node.js is single-threaded -- shared mutable state "just works" because there is no parallel access. In Rust with tokio's multi-threaded runtime, shared state must be wrapped in `Arc<Mutex<T>>` or `Arc<RwLock<T>>`. See ownership guide (10) for details.

### Step 3: Map each async pattern

For EACH async call site in the source, determine the Rust equivalent using the conversion table below.

**Core async mapping table:**

| TypeScript Pattern | Rust Equivalent | Notes |
|-------------------|-----------------|-------|
| `async function foo(): Promise<T>` | `async fn foo() -> Result<T, E>` | Always return Result for fallibility |
| `await expression` | `expression.await` | Postfix syntax in Rust |
| `new Promise((resolve, reject) => ...)` | `tokio::sync::oneshot` or direct async | See Example 4 |
| `.then(fn)` | `.await` + sequential code | Flatten promise chains |
| `.catch(fn)` | `match` or `?` operator | See error strategy (11) |
| `.finally(fn)` | `Drop` impl or explicit cleanup | Or `scopeguard` crate |
| `Promise.all([a, b, c])` | `tokio::join!(a, b, c)` | Fixed count |
| `Promise.all(arr.map(fn))` | `futures::future::join_all` | Dynamic count |
| `Promise.allSettled([a, b])` | `tokio::join!` + individual Result handling | See Example 3 |
| `Promise.race([a, b])` | `tokio::select!` | First to complete wins |
| `Promise.any([a, b])` | `tokio::select!` with error collection | First success wins |
| `setTimeout(fn, ms)` | `tokio::time::sleep` + `tokio::spawn` | See Example 5 |
| `setInterval(fn, ms)` | `tokio::time::interval` in a loop | See Example 5 |
| `clearTimeout` / `clearInterval` | `JoinHandle::abort()` or cancel token | See Example 5 |
| `EventEmitter.on(event, handler)` | `tokio::sync::broadcast` or `mpsc` | See Example 6 |
| `EventEmitter.once(event, handler)` | `broadcast::Receiver::recv()` (single await) | One-shot listener |
| `process.nextTick(fn)` | `tokio::task::yield_now()` | Yield to scheduler |
| `setImmediate(fn)` | `tokio::spawn(async { fn() })` | Schedule on next poll |
| Readable stream | `tokio::io::AsyncRead` or `Stream` trait | See Example 7 |
| `async function*` generator | `async_stream::stream!` or channel | See Example 8 |
| `AbortController` | `tokio_util::sync::CancellationToken` | See Example 9 |
| `worker_threads` | `tokio::task::spawn_blocking` or `rayon` | CPU-bound work |

## Code Examples

### Example 1: Basic Async/Await Conversion

**TypeScript:**
```typescript
async function fetchUserWithPosts(userId: string): Promise<UserWithPosts> {
  try {
    const user = await userService.findById(userId);
    if (!user) {
      throw new NotFoundError(`User ${userId} not found`);
    }
    const posts = await postService.findByUserId(userId);
    const enrichedPosts = posts.map(post => ({
      ...post,
      authorName: user.name,
    }));
    return { ...user, posts: enrichedPosts };
  } catch (error) {
    if (error instanceof NotFoundError) throw error;
    throw new InternalError(`Failed to fetch user: ${error.message}`);
  }
}
```

**Rust:**
```rust
async fn fetch_user_with_posts(
    user_service: &UserService,
    post_service: &PostService,
    user_id: Uuid,
) -> Result<UserWithPosts, AppError> {
    let user = user_service
        .find_by_id(user_id)
        .await?
        .ok_or_else(|| AppError::NotFound {
            resource: "user",
            id: user_id.to_string(),
        })?;

    let posts = post_service.find_by_user_id(user_id).await?;

    let enriched_posts: Vec<EnrichedPost> = posts
        .into_iter()
        .map(|post| EnrichedPost {
            id: post.id,
            title: post.title,
            body: post.body,
            author_name: user.name.clone(),
        })
        .collect();

    Ok(UserWithPosts {
        id: user.id,
        name: user.name,
        email: user.email,
        posts: enriched_posts,
    })
}
```

### Example 2: Promise.all to tokio::join!

**TypeScript:**
```typescript
// Fixed count -- known at compile time
async function getDashboardData(userId: string): Promise<Dashboard> {
  const [user, orders, notifications, stats] = await Promise.all([
    userService.findById(userId),
    orderService.findByUserId(userId),
    notificationService.getUnread(userId),
    analyticsService.getUserStats(userId),
  ]);
  return { user, orders, notifications, stats };
}

// Dynamic count -- array.map
async function fetchAllUsers(ids: string[]): Promise<User[]> {
  const users = await Promise.all(ids.map(id => userService.findById(id)));
  return users.filter((u): u is User => u !== null);
}

// With concurrency limit (using p-limit)
import pLimit from "p-limit";
const limit = pLimit(5);

async function processItems(items: Item[]): Promise<Result[]> {
  return Promise.all(
    items.map(item => limit(() => processItem(item)))
  );
}
```

**Rust:**
```rust
// Fixed count -> tokio::join! (compile-time known)
async fn get_dashboard_data(
    user_service: &UserService,
    order_service: &OrderService,
    notification_service: &NotificationService,
    analytics_service: &AnalyticsService,
    user_id: Uuid,
) -> Result<Dashboard, AppError> {
    let (user, orders, notifications, stats) = tokio::join!(
        user_service.find_by_id(user_id),
        order_service.find_by_user_id(user_id),
        notification_service.get_unread(user_id),
        analytics_service.get_user_stats(user_id),
    );

    Ok(Dashboard {
        user: user?,
        orders: orders?,
        notifications: notifications?,
        stats: stats?,
    })
}

// Dynamic count -> futures::future::join_all
async fn fetch_all_users(
    user_service: &UserService,
    ids: &[Uuid],
) -> Result<Vec<User>, AppError> {
    let futures: Vec<_> = ids
        .iter()
        .map(|id| user_service.find_by_id(*id))
        .collect();

    let results = futures::future::join_all(futures).await;

    let users: Vec<User> = results
        .into_iter()
        .filter_map(|r| r.ok().flatten())
        .collect();

    Ok(users)
}

// With concurrency limit -> buffer_unordered (replaces p-limit)
use futures::stream::{self, StreamExt};

async fn process_items(items: Vec<Item>) -> Result<Vec<ProcessResult>, AppError> {
    let results: Vec<Result<ProcessResult, AppError>> = stream::iter(items)
        .map(|item| async move {
            process_item(&item).await
        })
        .buffer_unordered(5) // max 5 concurrent
        .collect()
        .await;

    results.into_iter().collect()
}
```

### Example 3: Promise.allSettled to Individual Result Handling

**TypeScript:**
```typescript
async function sendNotifications(userIds: string[]): Promise<NotificationReport> {
  const results = await Promise.allSettled(
    userIds.map(id => sendNotification(id))
  );

  const succeeded = results.filter(r => r.status === "fulfilled").length;
  const failed = results
    .filter((r): r is PromiseRejectedResult => r.status === "rejected")
    .map(r => r.reason.message);

  return { total: userIds.length, succeeded, failed };
}
```

**Rust:**
```rust
use tokio::task::JoinSet;

async fn send_notifications(user_ids: &[Uuid]) -> NotificationReport {
    let mut join_set = JoinSet::new();

    for &user_id in user_ids {
        join_set.spawn(async move {
            (user_id, send_notification(user_id).await)
        });
    }

    let mut succeeded = 0u32;
    let mut failed = Vec::new();

    while let Some(result) = join_set.join_next().await {
        match result {
            Ok((_, Ok(()))) => succeeded += 1,
            Ok((user_id, Err(e))) => {
                failed.push(format!("user {user_id}: {e}"));
            }
            Err(join_err) => {
                failed.push(format!("task panicked: {join_err}"));
            }
        }
    }

    NotificationReport {
        total: user_ids.len() as u32,
        succeeded,
        failed,
    }
}
```

### Example 4: new Promise() Constructor to oneshot/async

**TypeScript:**
```typescript
// Wrapping callback API in a Promise
function readFileAsync(path: string): Promise<string> {
  return new Promise((resolve, reject) => {
    fs.readFile(path, "utf-8", (err, data) => {
      if (err) reject(err);
      else resolve(data);
    });
  });
}

// Manual Promise for complex flow
function waitForCondition(check: () => boolean, intervalMs: number): Promise<void> {
  return new Promise((resolve) => {
    const timer = setInterval(() => {
      if (check()) {
        clearInterval(timer);
        resolve();
      }
    }, intervalMs);
  });
}

// Deferred pattern
class Deferred<T> {
  promise: Promise<T>;
  resolve!: (value: T) => void;
  reject!: (reason: any) => void;

  constructor() {
    this.promise = new Promise((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }
}
```

**Rust:**
```rust
// Wrapping callback API -> just use async directly (most Rust APIs are already async)
async fn read_file_async(path: &std::path::Path) -> Result<String, std::io::Error> {
    tokio::fs::read_to_string(path).await
}

// If wrapping a truly callback-based FFI:
use tokio::sync::oneshot;

async fn callback_to_async() -> Result<String, AppError> {
    let (tx, rx) = oneshot::channel();

    // Hypothetical callback-based API
    legacy_api_call(move |result| {
        let _ = tx.send(result);
    });

    rx.await.map_err(|_| AppError::Internal("callback channel dropped".into()))
}

// waitForCondition -> tokio interval with condition check
async fn wait_for_condition<F>(check: F, interval_ms: u64) -> Result<(), AppError>
where
    F: Fn() -> bool,
{
    let mut interval = tokio::time::interval(
        std::time::Duration::from_millis(interval_ms)
    );

    loop {
        interval.tick().await;
        if check() {
            return Ok(());
        }
    }
}

// With timeout to prevent infinite waiting:
async fn wait_for_condition_with_timeout<F>(
    check: F,
    interval_ms: u64,
    timeout_ms: u64,
) -> Result<(), AppError>
where
    F: Fn() -> bool,
{
    tokio::time::timeout(
        std::time::Duration::from_millis(timeout_ms),
        wait_for_condition(check, interval_ms),
    )
    .await
    .map_err(|_| AppError::External(ExternalError::Timeout {
        service: "condition_wait".into(),
        timeout_ms,
    }))?
}

// Deferred pattern -> oneshot channel
pub struct Deferred<T> {
    pub sender: oneshot::Sender<T>,
    pub receiver: oneshot::Receiver<T>,
}

impl<T> Deferred<T> {
    pub fn new() -> Self {
        let (sender, receiver) = oneshot::channel();
        Self { sender, receiver }
    }

    pub fn resolve(self, value: T) {
        let _ = self.sender.send(value);
    }

    pub async fn wait(self) -> Result<T, oneshot::error::RecvError> {
        self.receiver.await
    }
}
```

### Example 5: setTimeout/setInterval to tokio Timers

**TypeScript:**
```typescript
// setTimeout -- delayed execution
setTimeout(() => {
  console.log("Delayed task");
}, 5000);

// setInterval -- periodic execution
const intervalId = setInterval(() => {
  cleanupExpiredSessions();
}, 60000);

// Clear interval on shutdown
process.on("SIGINT", () => {
  clearInterval(intervalId);
  process.exit(0);
});

// Debounce pattern
function debounce<T extends (...args: any[]) => any>(
  fn: T,
  delay: number
): (...args: Parameters<T>) => void {
  let timeoutId: NodeJS.Timeout;
  return (...args) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), delay);
  };
}

// Retry with exponential backoff
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number,
  baseDelayMs: number
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(r => setTimeout(r, baseDelayMs * 2 ** i));
    }
  }
  throw new Error("unreachable");
}
```

**Rust:**
```rust
use tokio::time::{self, Duration, Instant};

// setTimeout -> tokio::time::sleep + tokio::spawn
let handle = tokio::spawn(async {
    time::sleep(Duration::from_secs(5)).await;
    tracing::info!("Delayed task");
});

// Cancel: handle.abort()

// setInterval -> tokio::time::interval in a spawned task
let cleanup_handle = tokio::spawn(async {
    let mut interval = time::interval(Duration::from_secs(60));
    loop {
        interval.tick().await;
        if let Err(e) = cleanup_expired_sessions().await {
            tracing::error!(error = ?e, "session cleanup failed");
        }
    }
});

// clearInterval on shutdown -> abort the task
// or use CancellationToken for graceful shutdown:
use tokio_util::sync::CancellationToken;

let cancel = CancellationToken::new();
let cancel_clone = cancel.clone();

tokio::spawn(async move {
    let mut interval = time::interval(Duration::from_secs(60));
    loop {
        tokio::select! {
            _ = interval.tick() => {
                cleanup_expired_sessions().await.ok();
            }
            _ = cancel_clone.cancelled() => {
                tracing::info!("cleanup task stopped");
                break;
            }
        }
    }
});

// On shutdown:
cancel.cancel();

// Retry with exponential backoff -> backoff crate
use backoff::ExponentialBackoffBuilder;
use backoff::future::retry;

async fn retry_with_backoff<T, E, F, Fut>(
    f: F,
    max_retries: u32,
    base_delay_ms: u64,
) -> Result<T, E>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, backoff::Error<E>>>,
{
    let backoff = ExponentialBackoffBuilder::default()
        .with_initial_interval(Duration::from_millis(base_delay_ms))
        .with_max_elapsed_time(None)
        .build();

    retry(backoff, || f()).await
}

// Or manual implementation without crate:
async fn retry_manual<T, E, F, Fut>(
    f: F,
    max_retries: u32,
    base_delay_ms: u64,
) -> Result<T, E>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
    E: std::fmt::Debug,
{
    let mut last_err = None;
    for attempt in 0..max_retries {
        match f().await {
            Ok(val) => return Ok(val),
            Err(e) => {
                tracing::warn!(attempt, error = ?e, "retrying");
                last_err = Some(e);
                let delay = base_delay_ms * 2u64.pow(attempt);
                time::sleep(Duration::from_millis(delay)).await;
            }
        }
    }
    Err(last_err.unwrap())
}
```

### Example 6: EventEmitter to Channels

**TypeScript:**
```typescript
import { EventEmitter } from "events";

class OrderService extends EventEmitter {
  async createOrder(data: CreateOrderInput): Promise<Order> {
    const order = await this.db.insert("orders", data);

    // Emit events for side effects
    this.emit("order:created", order);
    this.emit("notification:send", {
      userId: order.userId,
      message: `Order ${order.id} created`,
    });

    return order;
  }
}

// Listeners registered elsewhere
orderService.on("order:created", async (order: Order) => {
  await analyticsService.trackOrder(order);
});

orderService.on("order:created", async (order: Order) => {
  await inventoryService.reserveItems(order.items);
});

orderService.once("order:created", async (order: Order) => {
  console.log("First order created:", order.id);
});
```

**Rust:**
```rust
use tokio::sync::broadcast;

// Define event types as an enum (replaces string event names)
#[derive(Debug, Clone)]
pub enum OrderEvent {
    Created(Order),
    Updated { order_id: Uuid, changes: OrderUpdate },
    Cancelled { order_id: Uuid, reason: String },
}

#[derive(Debug, Clone)]
pub enum NotificationEvent {
    Send { user_id: Uuid, message: String },
}

pub struct OrderService {
    db: Arc<PgPool>,
    order_events: broadcast::Sender<OrderEvent>,
    notification_events: broadcast::Sender<NotificationEvent>,
}

impl OrderService {
    pub fn new(
        db: Arc<PgPool>,
        order_events: broadcast::Sender<OrderEvent>,
        notification_events: broadcast::Sender<NotificationEvent>,
    ) -> Self {
        Self { db, order_events, notification_events }
    }

    pub async fn create_order(&self, data: CreateOrderInput) -> Result<Order, AppError> {
        let order = sqlx::query_as::<_, Order>(
            "INSERT INTO orders (user_id, total) VALUES ($1, $2) RETURNING *"
        )
        .bind(data.user_id)
        .bind(data.total)
        .fetch_one(&*self.db)
        .await?;

        // Emit events (non-blocking; receivers get cloned data)
        let _ = self.order_events.send(OrderEvent::Created(order.clone()));
        let _ = self.notification_events.send(NotificationEvent::Send {
            user_id: order.user_id,
            message: format!("Order {} created", order.id),
        });

        Ok(order)
    }
}

// Listeners: spawn tasks that subscribe to events
fn start_event_listeners(
    order_events: broadcast::Sender<OrderEvent>,
    analytics_service: Arc<AnalyticsService>,
    inventory_service: Arc<InventoryService>,
) {
    // Listener 1: analytics tracking (.on equivalent)
    let mut rx1 = order_events.subscribe();
    let analytics = analytics_service.clone();
    tokio::spawn(async move {
        while let Ok(event) = rx1.recv().await {
            if let OrderEvent::Created(order) = event {
                if let Err(e) = analytics.track_order(&order).await {
                    tracing::error!(error = ?e, "analytics tracking failed");
                }
            }
        }
    });

    // Listener 2: inventory reservation (.on equivalent)
    let mut rx2 = order_events.subscribe();
    let inventory = inventory_service.clone();
    tokio::spawn(async move {
        while let Ok(event) = rx2.recv().await {
            if let OrderEvent::Created(order) = event {
                if let Err(e) = inventory.reserve_items(&order.items).await {
                    tracing::error!(error = ?e, "inventory reservation failed");
                }
            }
        }
    });

    // .once equivalent: receive one event then stop
    let mut rx3 = order_events.subscribe();
    tokio::spawn(async move {
        if let Ok(OrderEvent::Created(order)) = rx3.recv().await {
            tracing::info!(order_id = %order.id, "First order created");
        }
        // Task ends after first event -- equivalent to .once()
    });
}
```

### Example 7: Node.js Streams to Rust Async Streams

**TypeScript:**
```typescript
import { Readable, Transform, pipeline } from "stream";
import { promisify } from "util";
const pipelineAsync = promisify(pipeline);

// Reading a file as a stream
async function processLargeFile(path: string): Promise<number> {
  let lineCount = 0;

  const lineCounter = new Transform({
    transform(chunk, encoding, callback) {
      const lines = chunk.toString().split("\n");
      lineCount += lines.length - 1;
      callback(null, chunk);
    },
  });

  await pipelineAsync(
    fs.createReadStream(path),
    lineCounter,
    fs.createWriteStream("/dev/null")
  );

  return lineCount;
}

// Async iteration over stream
async function* readLines(path: string): AsyncGenerator<string> {
  const stream = fs.createReadStream(path, { encoding: "utf-8" });
  let buffer = "";
  for await (const chunk of stream) {
    buffer += chunk;
    const lines = buffer.split("\n");
    buffer = lines.pop()!;
    for (const line of lines) {
      yield line;
    }
  }
  if (buffer) yield buffer;
}
```

**Rust:**
```rust
use tokio::fs::File;
use tokio::io::{AsyncBufReadExt, BufReader, AsyncRead};
use tokio_stream::{wrappers::LinesStream, StreamExt};
use futures::Stream;
use std::pin::Pin;

// Processing a large file line by line
async fn process_large_file(path: &std::path::Path) -> Result<usize, std::io::Error> {
    let file = File::open(path).await?;
    let reader = BufReader::new(file);
    let mut lines = reader.lines();

    let mut line_count = 0usize;
    while let Some(line) = lines.next_line().await? {
        line_count += 1;
        // Process line here if needed
        let _ = line;
    }

    Ok(line_count)
}

// Async generator -> return impl Stream
fn read_lines(
    path: std::path::PathBuf,
) -> Pin<Box<dyn Stream<Item = Result<String, std::io::Error>> + Send>> {
    Box::pin(async_stream::try_stream! {
        let file = File::open(&path).await?;
        let reader = BufReader::new(file);
        let mut lines = reader.lines();
        while let Some(line) = lines.next_line().await? {
            yield line;
        }
    })
}

// Usage:
// let mut stream = read_lines(path);
// while let Some(line) = stream.next().await {
//     let line = line?;
//     process(line);
// }

// Stream pipeline with transformations (replaces Transform streams)
use futures::stream;

async fn transform_pipeline(
    input_path: &std::path::Path,
) -> Result<Vec<String>, AppError> {
    let file = File::open(input_path).await?;
    let reader = BufReader::new(file);

    let results: Vec<String> = LinesStream::new(reader.lines())
        .filter_map(|line| async {
            match line {
                Ok(l) if !l.is_empty() => Some(l),
                _ => None,
            }
        })
        .map(|line| line.to_uppercase()) // Transform step
        .collect()
        .await;

    Ok(results)
}
```

### Example 8: Promise.race to tokio::select!

**TypeScript:**
```typescript
// Race: first to complete wins
async function fetchWithFallback(url: string): Promise<Response> {
  return Promise.race([
    fetch(url),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), 5000)
    ),
  ]);
}

// Promise.any: first success wins (ignores rejections)
async function fetchFromMirrors(urls: string[]): Promise<Response> {
  return Promise.any(urls.map(url => fetch(url)));
}

// Select between multiple event sources
async function waitForEvent(): Promise<string> {
  return Promise.race([
    waitForMessage().then(() => "message"),
    waitForTimeout().then(() => "timeout"),
    waitForCancel().then(() => "cancelled"),
  ]);
}
```

**Rust:**
```rust
use tokio::time::{timeout, Duration};

// Race with timeout -> tokio::time::timeout (most common pattern)
async fn fetch_with_fallback(url: &str) -> Result<String, AppError> {
    let response = timeout(
        Duration::from_secs(5),
        reqwest::get(url),
    )
    .await
    .map_err(|_| AppError::External(ExternalError::Timeout {
        service: url.to_string(),
        timeout_ms: 5000,
    }))?
    .map_err(|e| AppError::External(ExternalError::Http {
        service: url.to_string(),
        message: e.to_string(),
        source: e,
    }))?;

    response.text().await.map_err(|e| AppError::Internal(e.to_string()))
}

// Promise.any -> tokio::select! with error collection
async fn fetch_from_mirrors(urls: &[String]) -> Result<String, AppError> {
    let mut join_set = tokio::task::JoinSet::new();

    for url in urls {
        let url = url.clone();
        join_set.spawn(async move {
            reqwest::get(&url).await?.text().await
        });
    }

    let mut errors = Vec::new();
    while let Some(result) = join_set.join_next().await {
        match result {
            Ok(Ok(body)) => return Ok(body),
            Ok(Err(e)) => errors.push(e.to_string()),
            Err(e) => errors.push(format!("task panicked: {e}")),
        }
    }

    Err(AppError::Internal(format!(
        "all mirrors failed: {}",
        errors.join("; ")
    )))
}

// Select between multiple event sources
async fn wait_for_event(
    mut message_rx: tokio::sync::mpsc::Receiver<Message>,
    cancel: CancellationToken,
) -> &'static str {
    tokio::select! {
        Some(_msg) = message_rx.recv() => "message",
        _ = tokio::time::sleep(Duration::from_secs(30)) => "timeout",
        _ = cancel.cancelled() => "cancelled",
    }
}
```

### Example 9: AbortController to CancellationToken

**TypeScript:**
```typescript
const controller = new AbortController();

async function fetchWithAbort(url: string): Promise<Response> {
  return fetch(url, { signal: controller.signal });
}

// Cancel after 10 seconds
setTimeout(() => controller.abort(), 10000);

// Or cancel on user action
button.addEventListener("click", () => controller.abort());
```

**Rust:**
```rust
use tokio_util::sync::CancellationToken;

let cancel = CancellationToken::new();

// Pass cancel token to async operations
let cancel_clone = cancel.clone();
let fetch_handle = tokio::spawn(async move {
    tokio::select! {
        result = reqwest::get("https://api.example.com/data") => {
            result.map_err(|e| AppError::Internal(e.to_string()))
        }
        _ = cancel_clone.cancelled() => {
            Err(AppError::Internal("request aborted".into()))
        }
    }
});

// Cancel after 10 seconds
let cancel_timer = cancel.clone();
tokio::spawn(async move {
    tokio::time::sleep(Duration::from_secs(10)).await;
    cancel_timer.cancel();
});

// Or cancel from another trigger
// cancel.cancel();
```

## Template

```markdown
# Async Pattern Mapping

Source: {project_name}
Generated: {date}

## Runtime Configuration

**Runtime**: tokio 1.x (multi-threaded)
**Entry point**: `#[tokio::main]`

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
futures = "0.3"
tokio-stream = "0.1"
tokio-util = "0.7"
backoff = { version = "0.4", features = ["tokio"] }
async-stream = "0.3"
```

## Async Function Inventory

| # | Source Function | File | Pattern | Rust Equivalent | Notes |
|---|---------------|------|---------|-----------------|-------|
| 1 | `fetchUser()` | [{file}:{line}] | async/await | `async fn fetch_user()` | Direct |
| 2 | `getDashboard()` | [{file}:{line}] | Promise.all | `tokio::join!` | 4 concurrent |
| 3 | `processQueue()` | [{file}:{line}] | setInterval | `tokio::time::interval` | 60s period |
| 4 | `onOrderCreated()` | [{file}:{line}] | EventEmitter | `broadcast::Receiver` | Event listener |
| ... | ... | ... | ... | ... | ... |

## Concurrent Execution Patterns

### Pattern: {Name}
**Source**: [{file}:{line}](../src/{file}#L{line})
**Type**: {Promise.all / Promise.race / Promise.allSettled / Promise.any}
**Count**: {fixed / dynamic}
**Concurrency limit**: {number or unlimited}

## Event Architecture

```text
OrderService --[broadcast]--> Analytics Listener
                          --> Inventory Listener
                          --> Notification Listener
```

## Timer/Interval Inventory

| # | Source | Type | Interval | Cancellation | Rust Pattern |
|---|--------|------|----------|-------------|-------------|
| 1 | `cleanupJob` | setInterval | 60s | SIGINT | CancellationToken |
| 2 | `debounce` | setTimeout | 300ms | clearTimeout | sleep + select |
| ... | ... | ... | ... | ... | ... |

## Stream Conversions

| # | Source Stream | Type | Rust Equivalent | Crate |
|---|-------------|------|-----------------|-------|
| 1 | `fs.createReadStream` | Readable | `tokio::fs::File` + `BufReader` | tokio |
| 2 | `Transform` stream | Transform | `.map()` / `.filter()` on Stream | futures |
| ... | ... | ... | ... | ... |
```

## Completeness Check

- [ ] Every `async function` has a Rust `async fn` equivalent
- [ ] Every `await` expression is converted to `.await` with `?` error propagation
- [ ] Every `Promise.all` is converted to `tokio::join!` or `futures::future::join_all`
- [ ] Every `Promise.race` is converted to `tokio::select!` or `tokio::time::timeout`
- [ ] Every `Promise.allSettled` is converted to `JoinSet` with individual error handling
- [ ] Every `setTimeout` is converted to `tokio::time::sleep` + `tokio::spawn`
- [ ] Every `setInterval` is converted to `tokio::time::interval` in a loop
- [ ] Every `clearTimeout`/`clearInterval` uses `JoinHandle::abort()` or `CancellationToken`
- [ ] Every `EventEmitter` is replaced with typed broadcast/mpsc channels
- [ ] Every callback-based API is wrapped with `oneshot::channel` or native async
- [ ] Every Node.js stream is converted to `tokio::io` or `futures::Stream`
- [ ] Every async generator is converted to `async_stream::stream!` or channel-based stream
- [ ] Every `AbortController` is replaced with `CancellationToken`
- [ ] Concurrency limits (p-limit) are replaced with `buffer_unordered`
- [ ] Graceful shutdown strategy accounts for all background tasks
- [ ] Error propagation uses `?` operator consistently (no `.then().catch()` chains)
