# 03 - Async and Concurrency Model Analysis

**Output**: `.migration-plan/analysis/async-model.md`

## Purpose

Map every async operation, concurrency primitive, and parallel execution pattern in the source codebase. Rust's async model differs fundamentally from TypeScript/Python/Go:

- **TypeScript**: Single-threaded event loop with Promises. Rust needs an explicit async runtime (tokio/async-std).
- **Python**: Single-threaded asyncio or multi-threaded threading/multiprocessing. Rust unifies these under tokio tasks.
- **Go**: Goroutines with channels, no colored functions. Rust has colored async functions with explicit `.await`.

This analysis identifies the async runtime requirements, concurrency patterns that must be preserved, shared state access patterns that affect `Send + Sync` bounds, and blocking operations that must be isolated in Rust.

## Method

### Step 1: Find all async/concurrency constructs

Use Grep to locate every async and concurrency construct.

**TypeScript/JavaScript**:
```
Grep: async\s+function\s+\w+|async\s+\(|async\s*=>     (async function declarations)
Grep: \bawait\s+                                        (await expressions)
Grep: new\s+Promise\(                                    (Promise constructors)
Grep: Promise\.(all|allSettled|race|any)\(               (Promise combinators)
Grep: \.then\(                                           (Promise chaining)
Grep: setTimeout\(|setInterval\(|setImmediate\(          (timer-based async)
Grep: new\s+Worker\(|worker_threads                     (Worker threads)
Grep: EventEmitter|\.on\(|\.emit\(                      (event-driven patterns)
Grep: Observable|Subject|BehaviorSubject                 (RxJS observables)
Grep: AsyncIterator|for\s+await|async\s*\*              (async iterators/generators)
Grep: Readable|Writable|Transform|pipeline              (Node.js streams)
Grep: WebSocket|socket\.io|ws\(                         (WebSocket connections)
Grep: Bull|BullMQ|Queue|Worker                          (job queues)
Grep: cron|schedule|setInterval                         (scheduled tasks)
Grep: cluster\.fork|child_process                       (process-based parallelism)
Grep: Mutex|Semaphore|Lock                              (concurrency primitives, if any)
```

**Python**:
```
Grep: async\s+def\s+\w+                                (async function definitions)
Grep: \bawait\s+                                        (await expressions)
Grep: asyncio\.(run|gather|create_task|wait|sleep)      (asyncio operations)
Grep: asyncio\.(Queue|Event|Lock|Semaphore|Condition)   (asyncio sync primitives)
Grep: aiohttp|httpx\.AsyncClient|aiofiles              (async libraries)
Grep: threading\.(Thread|Lock|RLock|Event|Semaphore)    (threading)
Grep: multiprocessing\.(Process|Pool|Queue)             (multiprocessing)
Grep: concurrent\.futures\.(ThreadPoolExecutor|ProcessPoolExecutor)  (executors)
Grep: celery|dramatiq|rq|huey                          (task queues)
Grep: @app\.(on_event|on_startup|on_shutdown)           (lifecycle events)
Grep: BackgroundTasks|background_task                   (FastAPI background tasks)
Grep: async\s+for|async\s+with                         (async context managers/iteration)
Grep: asyncio\.Condition|asyncio\.Barrier               (advanced sync)
Grep: signal\.signal|loop\.add_signal_handler           (signal handling)
Grep: websockets|socketio\.AsyncServer                  (async WebSocket)
```

**Go**:
```
Grep: \bgo\s+func\s*\(                                 (goroutine with anonymous func)
Grep: \bgo\s+\w+\(                                     (goroutine with named func)
Grep: make\(chan\s+                                     (channel creation)
Grep: <-\s*\w+|chan\s*<-                               (channel send/receive)
Grep: select\s*\{                                      (select statements)
Grep: sync\.(Mutex|RWMutex|WaitGroup|Once|Map|Pool|Cond)  (sync primitives)
Grep: sync/atomic                                       (atomic operations)
Grep: context\.(Background|TODO|WithCancel|WithTimeout|WithDeadline)  (context usage)
Grep: time\.(After|Tick|NewTimer|NewTicker|Sleep)       (timer patterns)
Grep: errgroup\.Group|golang\.org/x/sync               (extended sync)
Grep: net/http\.ListenAndServe|http\.Server             (HTTP server)
Grep: database/sql|sqlx|gorm                            (database connections)
Grep: grpc\.NewServer|pb\.\w+Server                     (gRPC servers)
```

### Step 2: Identify the async runtime model

Determine the project's overall async architecture:

| Aspect | What to identify |
|--------|-----------------|
| **Runtime** | Node.js event loop / asyncio / goroutine scheduler |
| **Colored functions** | Are async/sync functions separated? (TS/Python: yes, Go: no) |
| **Concurrency model** | Single-threaded async / multi-threaded / multi-process |
| **I/O model** | Non-blocking I/O everywhere? Or mixed blocking/non-blocking? |
| **Framework runtime** | Express, Fastify, FastAPI, Gin -- what runtime does the framework provide? |

### Step 3: Analyze each async operation

For EACH async function/goroutine/task found:

#### A. Basic Information
- **Name**: function/method name
- **File**: path with line number
- **Kind**: async function / goroutine / background task / scheduled job / event handler / stream processor
- **Caller**: who calls this function and how

#### B. Await Points

For each async function, list EVERY await point:
- **Line**: line number
- **Operation**: what is being awaited (DB query, HTTP call, file read, sleep, lock acquisition)
- **Timeout**: is there a timeout? What happens on timeout?
- **Cancellation**: can this operation be cancelled? How?

#### C. Concurrency Pattern Classification

| Pattern | Description | Rust Equivalent |
|---------|-------------|-----------------|
| **Sequential-Async** | `await a; await b; await c;` -- one after another | Same with tokio: `a.await; b.await; c.await;` |
| **Parallel-Join** | `Promise.all([a, b, c])` / `asyncio.gather(a, b, c)` | `tokio::join!(a, b, c)` or `futures::join_all` |
| **Parallel-Race** | `Promise.race([a, b])` / `select {}` | `tokio::select!` |
| **Fan-Out** | Launch N goroutines/tasks, collect results | `tokio::spawn` + `JoinSet` |
| **Pipeline** | Data flows through stages: produce -> transform -> consume | Channels with `tokio::sync::mpsc` |
| **Fire-and-Forget** | Launch task, don't wait for result | `tokio::spawn` (watch for error handling) |
| **Pub-Sub** | Event emitters, observers | `tokio::sync::broadcast` |
| **Worker-Pool** | Fixed pool of workers processing a queue | `tokio::sync::Semaphore` + `tokio::spawn` |
| **Periodic** | Recurring scheduled task | `tokio::time::interval` |
| **Stream-Processing** | Async iterators, ReadableStream | `futures::Stream` + `StreamExt` |

### Step 4: Map shared state patterns

For EACH piece of shared mutable state:

- **What**: the variable/field being shared
- **File**: where it's defined
- **Access pattern**: read-only / read-write / append-only
- **Shared across**: tasks / threads / processes
- **Current protection**: none / mutex / atomic / channel / immutable
- **Rust strategy**: `Arc<Mutex<T>>` / `Arc<RwLock<T>>` / `tokio::sync::Mutex` / channel / `DashMap`
- **Send + Sync**: will this type be `Send + Sync`? (important for tokio)

Common shared state patterns to look for:
```
Grep: global\s+\w+|var\s+\w+\s*=   (global mutable variables)
Grep: static\s+mut\s+               (static mutable, if Rust already present)
Grep: singleton|getInstance          (singleton patterns)
Grep: app\.locals|req\.app           (request-scoped state in Express)
Grep: g\.|current_app                (Flask/FastAPI app state)
Grep: sync\.Map|sync\.Pool           (Go sync containers)
```

### Step 5: Identify blocking operations

Operations that block the thread and must be handled specially in async Rust:

| Operation | File | Line | Current Behavior | Rust Strategy |
|-----------|------|------|-----------------|---------------|
| File system read | - | - | Sync `fs.readFileSync` | `tokio::fs::read` or `spawn_blocking` |
| DNS resolution | - | - | Implicit in HTTP calls | Usually handled by async HTTP client |
| CPU-heavy computation | - | - | Runs on event loop | `tokio::task::spawn_blocking` |
| Sleep/delay | - | - | `time.Sleep()` / `await asyncio.sleep()` | `tokio::time::sleep` |
| Database query | - | - | Async via driver | Async via `sqlx` |
| Child process | - | - | `child_process.exec` | `tokio::process::Command` |

### Step 6: Analyze cancellation and timeout patterns

For EACH timeout or cancellation pattern:

- **Where**: file and line
- **Mechanism**: `AbortController` / `context.WithTimeout` / `asyncio.wait_for` / manual flag
- **Scope**: single operation / request lifecycle / graceful shutdown
- **Rust mapping**: `tokio::select!` with timeout / `CancellationToken` / `tokio::time::timeout`

### Step 7: Organize output

## Template

```markdown
# Async and Concurrency Model Analysis

Generated: {date}
Source: {project_path}

## Runtime Model Summary

| Aspect | Source | Rust Target |
|--------|--------|-------------|
| Language | {TypeScript / Python / Go} | Rust |
| Runtime | {Node.js event loop / asyncio / goroutine scheduler} | tokio (multi-threaded) |
| Concurrency Model | {single-threaded async / goroutines} | async/await + tokio tasks |
| Colored Functions | {Yes / No} | Yes (async fn vs fn) |
| Framework | {Express / FastAPI / Gin / ...} | {axum / actix-web / tonic / ...} |
| I/O Model | {fully non-blocking / mixed} | {fully non-blocking} |

## Metrics

| Metric | Count |
|--------|-------|
| Async functions | {N} |
| Await points | {N} |
| Goroutines / spawned tasks | {N} |
| Channels | {N} |
| Mutexes / Locks | {N} |
| Background workers / jobs | {N} |
| Event emitters / handlers | {N} |
| Streams / async iterators | {N} |
| Timeouts / cancellation points | {N} |
| Blocking operations in async context | {N} |

### Concurrency Pattern Distribution

| Pattern | Count | Locations |
|---------|-------|-----------|
| Sequential-Async | {N} | {file1, file2, ...} |
| Parallel-Join | {N} | {file1, file2, ...} |
| Parallel-Race | {N} | {file1, file2, ...} |
| Fan-Out | {N} | {file1, file2, ...} |
| Pipeline | {N} | {file1, file2, ...} |
| Fire-and-Forget | {N} | {file1, file2, ...} |
| Pub-Sub | {N} | {file1, file2, ...} |
| Worker-Pool | {N} | {file1, file2, ...} |
| Periodic | {N} | {file1, file2, ...} |
| Stream-Processing | {N} | {file1, file2, ...} |

## Async Function Catalog

### AC-{nnn}: {function_name}

- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Kind**: {async function / goroutine / background task / event handler}
- **Pattern**: {Sequential-Async / Parallel-Join / Fan-Out / ...}
- **Called by**: {caller function(s)}

**Await points**:

| Line | Operation | Timeout | Cancellable |
|------|-----------|---------|-------------|
| {n} | DB query: SELECT user | 30s | Yes (request context) |
| {n} | HTTP call: GET /api/data | 10s | Yes (AbortController) |
| {n} | File read: config.json | None | No |

**Rust mapping**: {brief description of how this function maps to tokio}

---

{Repeat for EVERY async function / goroutine / spawned task.}

## Shared State Inventory

### SS-{nn}: {state_name}

- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Type**: {data type}
- **Scope**: {global / module / request-scoped / connection-scoped}
- **Access**: {read-only / read-write / append-only}
- **Shared across**: {async tasks / threads / goroutines}
- **Current protection**: {none / Mutex / RWMutex / atomic / channel / immutable}
- **Accessed by**: {list functions that read/write this state}
- **Rust strategy**: {Arc<RwLock<T>> / Arc<Mutex<T>> / DashMap / channel / OnceCell}
- **Send + Sync**: {Yes / No -- and why}

---

{Repeat for EVERY shared mutable state instance.}

## Channel / Communication Patterns

### CH-{nn}: {channel_name_or_description}

- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Type**: {channel type / EventEmitter event name / Observable type}
- **Direction**: {unidirectional / bidirectional}
- **Buffered**: {Yes (size N) / No (unbuffered) / N/A}
- **Producers**: {list sender functions}
- **Consumers**: {list receiver functions}
- **Rust mapping**: {tokio::sync::mpsc / broadcast / oneshot / watch}

---

{Repeat for EVERY channel / event / observable.}

## Blocking Operations

| # | File | Line | Operation | Current Behavior | Rust Strategy |
|---|------|------|-----------|-----------------|---------------|
| 1 | {path} | {n} | {operation} | {sync/async} | {spawn_blocking / async alternative} |
| 2 | {path} | {n} | {operation} | {sync/async} | {spawn_blocking / async alternative} |
| ... | | | | | |

## Timeout and Cancellation Patterns

### TC-{nn}: {description}

- **File**: [{file_path}:{line}](../{file_path}#L{line})
- **Mechanism**: {AbortController / context.WithTimeout / asyncio.wait_for / manual}
- **Timeout value**: {duration or "none"}
- **Scope**: {single operation / request / graceful shutdown}
- **On timeout**: {what happens -- error thrown? default returned? process exits?}
- **Rust mapping**: {tokio::time::timeout / tokio::select! / CancellationToken}

---

{Repeat for EVERY timeout/cancellation pattern.}

## Graceful Shutdown Pattern

- **Signal handling**: {SIGTERM / SIGINT handling present? Where?}
- **Drain connections**: {Does the app drain in-flight requests?}
- **Close resources**: {DB connections, file handles, channels}
- **Rust mapping**: {tokio::signal + graceful shutdown pattern}

**Source locations**:
| Step | File | Line | Action |
|------|------|------|--------|
| 1 | {path} | {n} | Register signal handler |
| 2 | {path} | {n} | Stop accepting new connections |
| 3 | {path} | {n} | Wait for in-flight requests |
| 4 | {path} | {n} | Close database pool |

## Rust Async Architecture Recommendations

Based on the patterns found:

- **Async runtime**: {tokio (recommended) / async-std / smol}
- **Runtime config**: {multi-threaded (default) / current-thread (if single-threaded source)}
- **Key crates needed**: {tokio, futures, tokio-stream, dashmap, ...}
- **Biggest migration challenges**:
  1. {challenge 1}
  2. {challenge 2}
  3. {challenge 3}
```

## Completeness Check

- [ ] Every async function is cataloged with all its await points
- [ ] Every goroutine/spawned task is listed individually
- [ ] Every channel/event emitter/observable is cataloged
- [ ] Every shared mutable state instance is identified with its protection mechanism
- [ ] Every blocking operation in async context is flagged
- [ ] Every timeout/cancellation pattern is documented
- [ ] Concurrency patterns are classified for each async function
- [ ] Shared state entries include Send + Sync analysis
- [ ] Graceful shutdown pattern is documented (if present)
- [ ] No async operations are summarized as "and N more async functions"
- [ ] Rust async runtime recommendation is provided with justification
