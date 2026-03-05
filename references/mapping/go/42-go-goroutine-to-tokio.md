# 42 - Go Goroutine/Channel to Tokio

**Output**: Contributes to `.migration-plan/mappings/async-strategy.md`

## Purpose

Map every Go concurrency pattern -- goroutines, channels, sync primitives, context propagation, and select statements -- to its Rust tokio equivalent. Go's concurrency model is built on goroutines (lightweight green threads) and channels ("share memory by communicating"). Rust's async model uses futures with an executor runtime (tokio), channels from `tokio::sync`, and explicit ownership to guarantee data-race freedom at compile time. Every goroutine launch, channel operation, mutex usage, WaitGroup, and context.Context in the Go source must receive a concrete Rust translation.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `async-model.md` -- inventory of all goroutines, channels, sync primitives, concurrency patterns
- `architecture.md` -- identifies shared state, worker pools, pipeline patterns
- `type-catalog.md` -- types passed across goroutine boundaries (must be Send + Sync)
- `error-patterns.md` -- error handling in concurrent code (errgroup patterns)

Extract every instance of:
- `go func() { ... }()` launches
- Channel creation (`make(chan T)`, `make(chan T, N)`)
- Channel operations (`ch <- val`, `val := <-ch`, `val, ok := <-ch`)
- `select { case ... }` statements
- `sync.WaitGroup` usage
- `sync.Mutex` / `sync.RWMutex` usage
- `sync.Once` usage
- `sync.Map` usage
- `sync.Pool` usage
- `context.Context` propagation
- `context.WithCancel`, `context.WithTimeout`, `context.WithDeadline`
- `errgroup.Group` usage
- `time.After`, `time.Tick`, `time.NewTimer`
- Worker pool patterns
- Fan-out / fan-in patterns
- Pipeline patterns
- Rate limiting

### Step 2: For each concurrency pattern, determine Rust equivalent

**Core mapping table:**

| Go Construct | Rust Equivalent | Crate |
|-------------|----------------|-------|
| `go func() { ... }()` | `tokio::spawn(async { ... })` | tokio |
| `make(chan T)` (unbuffered) | `mpsc::channel(1)` | tokio |
| `make(chan T, n)` (buffered) | `mpsc::channel(n)` | tokio |
| `ch <- val` | `tx.send(val).await` | tokio |
| `val := <-ch` | `rx.recv().await` | tokio |
| `val, ok := <-ch` | `rx.recv().await` returns `Option<T>` | tokio |
| `close(ch)` | Drop the `Sender` | (ownership) |
| `for val := range ch` | `while let Some(val) = rx.recv().await` | tokio |
| `select { case ... }` | `tokio::select! { ... }` | tokio |
| `sync.WaitGroup` | `tokio::task::JoinSet` | tokio |
| `sync.Mutex` | `tokio::sync::Mutex` or `std::sync::Mutex` | tokio / std |
| `sync.RWMutex` | `tokio::sync::RwLock` or `std::sync::RwLock` | tokio / std |
| `sync.Once` | `std::sync::OnceLock` or `std::sync::LazyLock` | std |
| `sync.Map` | `dashmap::DashMap` | dashmap |
| `sync.Pool` | `object_pool` or manual implementation | object-pool |
| `context.Context` | `CancellationToken` + timeout | tokio-util |
| `context.WithCancel` | `CancellationToken::new()` + `.child_token()` | tokio-util |
| `context.WithTimeout` | `tokio::time::timeout(dur, future)` | tokio |
| `context.WithDeadline` | `tokio::time::timeout_at(instant, future)` | tokio |
| `context.Value` | Struct fields or `tracing::Span` | tracing |
| `errgroup.Group` | `tokio::task::JoinSet` with error collection | tokio |
| `time.After(d)` | `tokio::time::sleep(d)` | tokio |
| `time.NewTicker(d)` | `tokio::time::interval(d)` | tokio |
| `time.NewTimer(d)` | `tokio::time::sleep(d)` (one-shot) | tokio |
| `runtime.GOMAXPROCS` | Tokio runtime builder `.worker_threads(n)` | tokio |

**Mutex decision tree:**

```
Is the lock held across an .await point?
  YES -> tokio::sync::Mutex (async-aware)
  NO  ->
    Is contention expected to be very low and lock held briefly?
      YES -> std::sync::Mutex (faster, no async overhead)
      NO  -> tokio::sync::Mutex
```

### Step 3: Produce concurrency mapping document

For EACH concurrency pattern found in the source, produce:
1. Go source code with file:line reference
2. Pattern type (goroutine launch, channel, select, mutex, etc.)
3. Rust equivalent code (compilable)
4. Send + Sync analysis for types crossing task boundaries
5. Cancellation strategy

## Code Examples

### Example 1: Goroutine Launch to tokio::spawn

**Go:**
```go
func (s *Server) HandleRequest(req *Request) {
    // Fire-and-forget goroutine
    go func() {
        if err := s.sendNotification(req.UserID, "request received"); err != nil {
            log.Printf("notification failed: %v", err)
        }
    }()

    // Process the request synchronously
    s.processRequest(req)
}
```

**Rust:**
```rust
impl Server {
    pub async fn handle_request(&self, req: Request) {
        // Fire-and-forget task
        let notifier = self.notifier.clone(); // Clone Arc for the spawned task
        let user_id = req.user_id;
        tokio::spawn(async move {
            if let Err(e) = notifier.send_notification(user_id, "request received").await {
                tracing::error!(error = ?e, user_id, "notification failed");
            }
        });

        // Process the request
        self.process_request(&req).await;
    }
}
```

### Example 2: Unbuffered and Buffered Channels

**Go:**
```go
func Pipeline() {
    // Unbuffered channel -- synchronizes sender and receiver
    sync := make(chan int)

    // Buffered channel -- decouples sender and receiver
    buffered := make(chan string, 100)

    go func() {
        for i := 0; i < 10; i++ {
            sync <- i    // blocks until receiver reads
        }
        close(sync)
    }()

    go func() {
        for val := range sync {
            buffered <- fmt.Sprintf("processed: %d", val)
        }
        close(buffered)
    }()

    for result := range buffered {
        fmt.Println(result)
    }
}
```

**Rust:**
```rust
use tokio::sync::mpsc;

pub async fn pipeline() {
    // Bounded channel with capacity 1 approximates unbuffered
    // (true unbuffered requires rendezvous channel; mpsc(1) is close enough)
    let (sync_tx, mut sync_rx) = mpsc::channel::<i32>(1);

    // Buffered channel
    let (buf_tx, mut buf_rx) = mpsc::channel::<String>(100);

    // Producer
    tokio::spawn(async move {
        for i in 0..10 {
            if sync_tx.send(i).await.is_err() {
                break; // receiver dropped
            }
        }
        // sync_tx is dropped here, closing the channel
    });

    // Transformer
    tokio::spawn(async move {
        while let Some(val) = sync_rx.recv().await {
            let result = format!("processed: {val}");
            if buf_tx.send(result).await.is_err() {
                break;
            }
        }
        // buf_tx is dropped here, closing the channel
    });

    // Consumer
    while let Some(result) = buf_rx.recv().await {
        println!("{result}");
    }
}
```

### Example 3: Select Statement to tokio::select!

**Go:**
```go
func (w *Worker) Run(ctx context.Context, jobs <-chan Job, results chan<- Result) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            log.Println("worker shutting down")
            return
        case job, ok := <-jobs:
            if !ok {
                log.Println("job channel closed")
                return
            }
            result := w.process(job)
            results <- result
        case <-ticker.C:
            w.reportStats()
        }
    }
}
```

**Rust:**
```rust
use tokio::sync::mpsc;
use tokio::time::{self, Duration};
use tokio_util::sync::CancellationToken;

impl Worker {
    pub async fn run(
        &self,
        cancel: CancellationToken,
        mut jobs: mpsc::Receiver<Job>,
        results: mpsc::Sender<JobResult>,
    ) {
        let mut ticker = time::interval(Duration::from_secs(30));

        loop {
            tokio::select! {
                _ = cancel.cancelled() => {
                    tracing::info!("worker shutting down");
                    return;
                }
                job = jobs.recv() => {
                    match job {
                        Some(job) => {
                            let result = self.process(job).await;
                            if results.send(result).await.is_err() {
                                return; // results receiver dropped
                            }
                        }
                        None => {
                            tracing::info!("job channel closed");
                            return;
                        }
                    }
                }
                _ = ticker.tick() => {
                    self.report_stats().await;
                }
            }
        }
    }
}
```

### Example 4: sync.WaitGroup to JoinSet

**Go:**
```go
func FetchAll(urls []string) []Response {
    var wg sync.WaitGroup
    results := make([]Response, len(urls))
    var mu sync.Mutex

    for i, url := range urls {
        wg.Add(1)
        go func(i int, url string) {
            defer wg.Done()
            resp, err := http.Get(url)
            if err != nil {
                log.Printf("fetch %s failed: %v", url, err)
                return
            }
            mu.Lock()
            results[i] = parseResponse(resp)
            mu.Unlock()
        }(i, url)
    }

    wg.Wait()
    return results
}
```

**Rust:**
```rust
use tokio::task::JoinSet;

pub async fn fetch_all(urls: Vec<String>) -> Vec<Option<Response>> {
    let mut set = JoinSet::new();

    for (i, url) in urls.iter().enumerate() {
        let url = url.clone();
        set.spawn(async move {
            let result = reqwest::get(&url).await;
            match result {
                Ok(resp) => Some((i, parse_response(resp).await)),
                Err(e) => {
                    tracing::error!(url = %url, error = ?e, "fetch failed");
                    None
                }
            }
        });
    }

    let mut results = vec![None; urls.len()];
    while let Some(Ok(outcome)) = set.join_next().await {
        if let Some((i, resp)) = outcome {
            results[i] = Some(resp);
        }
    }

    results
}
```

### Example 5: errgroup.Group to JoinSet with Error Collection

**Go:**
```go
import "golang.org/x/sync/errgroup"

func (s *Service) SyncAll(ctx context.Context) error {
    g, ctx := errgroup.WithContext(ctx)

    g.Go(func() error {
        return s.syncUsers(ctx)
    })

    g.Go(func() error {
        return s.syncOrders(ctx)
    })

    g.Go(func() error {
        return s.syncProducts(ctx)
    })

    return g.Wait() // returns first error, cancels others via ctx
}
```

**Rust:**
```rust
use tokio::task::JoinSet;
use tokio_util::sync::CancellationToken;

impl Service {
    pub async fn sync_all(&self, cancel: CancellationToken) -> Result<(), SyncError> {
        let mut set = JoinSet::new();

        let svc = self.clone(); // Assumes Service: Clone (via Arc internals)
        let token = cancel.clone();
        set.spawn(async move { svc.sync_users(token).await });

        let svc = self.clone();
        let token = cancel.clone();
        set.spawn(async move { svc.sync_orders(token).await });

        let svc = self.clone();
        let token = cancel.clone();
        set.spawn(async move { svc.sync_products(token).await });

        // Collect results, fail on first error (cancel-on-error like errgroup)
        while let Some(result) = set.join_next().await {
            match result {
                Ok(Ok(())) => {} // task succeeded
                Ok(Err(e)) => {
                    cancel.cancel(); // cancel remaining tasks
                    set.abort_all();
                    return Err(e);
                }
                Err(join_err) => {
                    cancel.cancel();
                    set.abort_all();
                    return Err(SyncError::TaskPanicked(join_err.to_string()));
                }
            }
        }

        Ok(())
    }
}
```

### Example 6: sync.Mutex / sync.RWMutex

**Go:**
```go
type Cache struct {
    mu    sync.RWMutex
    items map[string]Item
}

func (c *Cache) Get(key string) (Item, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    item, ok := c.items[key]
    return item, ok
}

func (c *Cache) Set(key string, item Item) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = item
}
```

**Rust (std::sync -- lock NOT held across await):**
```rust
use std::collections::HashMap;
use std::sync::RwLock;

pub struct Cache {
    items: RwLock<HashMap<String, Item>>,
}

impl Cache {
    pub fn get(&self, key: &str) -> Option<Item> {
        let guard = self.items.read().unwrap();
        guard.get(key).cloned()
    }

    pub fn set(&self, key: String, item: Item) {
        let mut guard = self.items.write().unwrap();
        guard.insert(key, item);
    }
}
```

**Rust (DashMap -- better for concurrent access):**
```rust
use dashmap::DashMap;

pub struct Cache {
    items: DashMap<String, Item>,
}

impl Cache {
    pub fn get(&self, key: &str) -> Option<Item> {
        self.items.get(key).map(|entry| entry.value().clone())
    }

    pub fn set(&self, key: String, item: Item) {
        self.items.insert(key, item);
    }
}
```

### Example 7: context.Context to CancellationToken + Timeout

**Go:**
```go
func (c *Client) FetchData(ctx context.Context, id string) (*Data, error) {
    // Create child context with timeout
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, "GET",
        fmt.Sprintf("%s/data/%s", c.baseURL, id), nil)
    if err != nil {
        return nil, err
    }

    resp, err := c.httpClient.Do(req)
    if err != nil {
        if ctx.Err() == context.DeadlineExceeded {
            return nil, fmt.Errorf("fetch data timed out after 5s")
        }
        return nil, fmt.Errorf("fetch data: %w", err)
    }
    defer resp.Body.Close()

    var data Data
    if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
        return nil, fmt.Errorf("decode data: %w", err)
    }
    return &data, nil
}
```

**Rust:**
```rust
use std::time::Duration;
use tokio_util::sync::CancellationToken;

impl Client {
    pub async fn fetch_data(
        &self,
        cancel: CancellationToken,
        id: &str,
    ) -> Result<Data, ClientError> {
        let url = format!("{}/data/{}", self.base_url, id);

        // Timeout wraps the entire operation
        let result = tokio::time::timeout(Duration::from_secs(5), async {
            tokio::select! {
                _ = cancel.cancelled() => {
                    Err(ClientError::Cancelled)
                }
                result = self.http_client.get(&url).send() => {
                    let resp = result.map_err(ClientError::Http)?;
                    let data: Data = resp.json().await.map_err(ClientError::Decode)?;
                    Ok(data)
                }
            }
        })
        .await;

        match result {
            Ok(inner) => inner,
            Err(_elapsed) => Err(ClientError::Timeout {
                operation: format!("fetch data {id}"),
                duration: Duration::from_secs(5),
            }),
        }
    }
}
```

### Example 8: Worker Pool Pattern

**Go:**
```go
func WorkerPool(numWorkers int, jobs <-chan Job) <-chan Result {
    results := make(chan Result, numWorkers)

    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            for job := range jobs {
                result := processJob(workerID, job)
                results <- result
            }
        }(i)
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

**Rust:**
```rust
use tokio::sync::mpsc;
use tokio::task::JoinSet;

pub async fn worker_pool(
    num_workers: usize,
    mut jobs: mpsc::Receiver<Job>,
    results: mpsc::Sender<JobResult>,
) {
    let mut set = JoinSet::new();

    // Distribute jobs across workers using a shared receiver is not possible
    // with mpsc (single consumer). Use a different pattern:

    // Pattern: bounded channel as work queue with multiple consumers
    // Re-wrap the receiver into a shared structure
    let jobs = std::sync::Arc::new(tokio::sync::Mutex::new(jobs));

    for worker_id in 0..num_workers {
        let jobs = jobs.clone();
        let results = results.clone();

        set.spawn(async move {
            loop {
                // Each worker competes for the next job
                let job = {
                    let mut rx = jobs.lock().await;
                    rx.recv().await
                };

                match job {
                    Some(job) => {
                        let result = process_job(worker_id, job).await;
                        if results.send(result).await.is_err() {
                            break;
                        }
                    }
                    None => break, // channel closed
                }
            }
        });
    }

    // Drop our copy of results sender so the channel closes when workers finish
    drop(results);

    // Wait for all workers
    while let Some(result) = set.join_next().await {
        if let Err(e) = result {
            tracing::error!(error = ?e, "worker task panicked");
        }
    }
}
```

### Example 9: Fan-Out / Fan-In

**Go:**
```go
func FanOutFanIn(input <-chan int, numWorkers int) <-chan int {
    // Fan-out: multiple goroutines reading from one channel
    channels := make([]<-chan int, numWorkers)
    for i := 0; i < numWorkers; i++ {
        channels[i] = worker(input)
    }

    // Fan-in: merge multiple channels into one
    return merge(channels...)
}

func merge(channels ...<-chan int) <-chan int {
    var wg sync.WaitGroup
    merged := make(chan int)

    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan int) {
            defer wg.Done()
            for val := range c {
                merged <- val
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(merged)
    }()

    return merged
}
```

**Rust:**
```rust
use futures::stream::{self, StreamExt};
use tokio::sync::mpsc;

pub async fn fan_out_fan_in(
    mut input: mpsc::Receiver<i32>,
    num_workers: usize,
) -> mpsc::Receiver<i32> {
    let (merged_tx, merged_rx) = mpsc::channel(num_workers * 2);

    // Share the input across workers
    let input = std::sync::Arc::new(tokio::sync::Mutex::new(input));

    for _ in 0..num_workers {
        let input = input.clone();
        let tx = merged_tx.clone();

        tokio::spawn(async move {
            loop {
                let val = {
                    let mut rx = input.lock().await;
                    rx.recv().await
                };
                match val {
                    Some(v) => {
                        let result = process(v).await;
                        if tx.send(result).await.is_err() {
                            break;
                        }
                    }
                    None => break,
                }
            }
        });
    }

    // Drop the original sender so merged_rx closes when all workers finish
    drop(merged_tx);

    merged_rx
}

// Alternative: use Stream combinators for fan-in
pub fn merge_streams<T: Send + 'static>(
    receivers: Vec<mpsc::Receiver<T>>,
) -> impl futures::Stream<Item = T> {
    let streams: Vec<_> = receivers
        .into_iter()
        .map(tokio_stream::wrappers::ReceiverStream::new)
        .collect();

    stream::select_all(streams)
}
```

### Example 10: Graceful Shutdown

**Go:**
```go
func main() {
    ctx, cancel := context.WithCancel(context.Background())

    server := NewServer()
    go server.Run(ctx)

    // Wait for interrupt signal
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
    <-sigCh

    log.Println("shutting down...")
    cancel()

    // Give goroutines time to finish
    time.Sleep(5 * time.Second)
    log.Println("shutdown complete")
}
```

**Rust:**
```rust
use tokio::signal;
use tokio_util::sync::CancellationToken;
use std::time::Duration;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let cancel = CancellationToken::new();

    let server = Server::new();
    let server_cancel = cancel.clone();
    let server_handle = tokio::spawn(async move {
        server.run(server_cancel).await
    });

    // Wait for shutdown signal
    tokio::select! {
        _ = signal::ctrl_c() => {
            tracing::info!("received SIGINT, shutting down...");
        }
        result = server_handle => {
            match result {
                Ok(Ok(())) => tracing::info!("server exited normally"),
                Ok(Err(e)) => tracing::error!(error = ?e, "server error"),
                Err(e) => tracing::error!(error = ?e, "server task panicked"),
            }
            return Ok(());
        }
    }

    // Signal all tasks to stop
    cancel.cancel();

    // Give tasks a grace period
    tokio::time::sleep(Duration::from_secs(5)).await;

    tracing::info!("shutdown complete");
    Ok(())
}
```

### Example 11: sync.Once to OnceLock

**Go:**
```go
var (
    instance *Database
    once     sync.Once
)

func GetDatabase() *Database {
    once.Do(func() {
        instance = connectToDatabase()
    })
    return instance
}
```

**Rust:**
```rust
use std::sync::OnceLock;

static DATABASE: OnceLock<Database> = OnceLock::new();

pub fn get_database() -> &'static Database {
    DATABASE.get_or_init(|| {
        connect_to_database()
            .expect("failed to connect to database")
    })
}

// Prefer dependency injection over global state:
pub struct AppState {
    pub db: Database,
}

impl AppState {
    pub async fn new() -> Result<Self, AppError> {
        let db = connect_to_database().await?;
        Ok(Self { db })
    }
}
```

### Example 12: Rate Limiting with time.Ticker

**Go:**
```go
func RateLimitedProcess(items []Item) {
    limiter := time.NewTicker(100 * time.Millisecond) // 10 per second
    defer limiter.Stop()

    for _, item := range items {
        <-limiter.C
        process(item)
    }
}
```

**Rust:**
```rust
use tokio::time::{self, Duration};

pub async fn rate_limited_process(items: Vec<Item>) {
    let mut interval = time::interval(Duration::from_millis(100)); // 10 per second

    for item in items {
        interval.tick().await;
        process(item).await;
    }
}

// Alternative: use a semaphore for concurrent rate limiting
use tokio::sync::Semaphore;
use std::sync::Arc;

pub async fn concurrent_rate_limited(items: Vec<Item>, max_concurrent: usize) {
    let semaphore = Arc::new(Semaphore::new(max_concurrent));
    let mut set = tokio::task::JoinSet::new();

    for item in items {
        let permit = semaphore.clone().acquire_owned().await.unwrap();
        set.spawn(async move {
            let result = process(item).await;
            drop(permit); // release when done
            result
        });
    }

    while let Some(result) = set.join_next().await {
        if let Err(e) = result {
            tracing::error!(error = ?e, "task failed");
        }
    }
}
```

## Template

```markdown
# Go Goroutine/Channel to Tokio Mapping

Source: {project_name}
Generated: {date}

## Runtime Configuration

```toml
[dependencies]
tokio = { version = "1", features = ["full"] }
tokio-util = "0.7"
tokio-stream = "0.1"
futures = "0.3"
dashmap = "6"
```

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Multi-threaded runtime (default)
    Ok(())
}
```

## Goroutine Inventory

| # | Location | Pattern | Data Passed | Rust Strategy | Send+Sync? |
|---|----------|---------|-------------|---------------|------------|
| 1 | [{file}:{line}] | fire-and-forget | `UserID` | `tokio::spawn` | Yes |
| 2 | [{file}:{line}] | worker | `Job` via channel | `tokio::spawn` + `mpsc` | Yes |
| 3 | [{file}:{line}] | background loop | Shared `Cache` | `tokio::spawn` + `Arc` | Yes |

## Channel Inventory

| # | Location | Direction | Type | Buffer | Rust Channel |
|---|----------|-----------|------|--------|-------------|
| 1 | [{file}:{line}] | `chan<-` | `Job` | 100 | `mpsc::channel(100)` |
| 2 | [{file}:{line}] | `<-chan` | `Result` | 0 | `mpsc::channel(1)` |
| 3 | [{file}:{line}] | bidirectional | `Event` | 50 | `broadcast::channel(50)` |

## Select Statement Inventory

| # | Location | Cases | Rust Mapping |
|---|----------|-------|-------------|
| 1 | [{file}:{line}] | `ctx.Done`, `jobs`, `ticker` | `tokio::select!` with 3 branches |

## Sync Primitive Inventory

| # | Location | Go Type | Protects | Rust Type | Rationale |
|---|----------|---------|----------|-----------|-----------|
| 1 | [{file}:{line}] | `sync.Mutex` | `map[string]Item` | `DashMap` | Concurrent map |
| 2 | [{file}:{line}] | `sync.RWMutex` | `Config` | `ArcSwap` | Read-heavy |
| 3 | [{file}:{line}] | `sync.WaitGroup` | N goroutines | `JoinSet` | Collect results |
| 4 | [{file}:{line}] | `sync.Once` | init | `OnceLock` | One-time init |

## Context Propagation Map

| # | Location | Context Usage | Rust Strategy |
|---|----------|--------------|---------------|
| 1 | [{file}:{line}] | `WithCancel` | `CancellationToken::child_token()` |
| 2 | [{file}:{line}] | `WithTimeout(5s)` | `tokio::time::timeout(5s, ...)` |
| 3 | [{file}:{line}] | `Value(key, val)` | Struct field or `tracing::Span` |

## Concurrency Patterns

### {Pattern Name}

**Source**: [{file}:{line}](../src/{file}#L{line})
**Pattern**: {worker pool / fan-out / pipeline / ...}
**Go code**: ...
**Rust code**: ...
```

## Completeness Check

- [ ] Every `go func()` launch is mapped to `tokio::spawn`
- [ ] Every channel creation is mapped to appropriate tokio channel type
- [ ] Every `select {}` statement is mapped to `tokio::select!`
- [ ] Every `sync.WaitGroup` is replaced with `JoinSet`
- [ ] Every `sync.Mutex` / `sync.RWMutex` has a Rust equivalent with rationale
- [ ] Every `sync.Once` is replaced with `OnceLock` or `LazyLock`
- [ ] Every `sync.Map` is replaced with `DashMap`
- [ ] Every `context.Context` propagation path is mapped to `CancellationToken`
- [ ] Every `context.WithTimeout` / `WithDeadline` is mapped to `tokio::time::timeout`
- [ ] Every `context.Value` usage is replaced with struct fields or tracing spans
- [ ] Every `errgroup.Group` is mapped to `JoinSet` with error collection
- [ ] Every `time.Ticker` / `time.Timer` is mapped to `tokio::time::interval` / `sleep`
- [ ] Worker pool patterns are mapped with bounded concurrency
- [ ] Fan-out / fan-in patterns are mapped with proper channel topology
- [ ] Graceful shutdown strategy is defined with `CancellationToken`
- [ ] All types crossing task boundaries are verified `Send + Sync`
- [ ] CPU-bound work uses `tokio::task::spawn_blocking`
- [ ] No `std::sync::Mutex` guards are held across `.await` points
