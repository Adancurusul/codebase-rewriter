# TypeScript -> Rust Reference

## Primitive Types

| TypeScript | Rust | Notes |
|---|---|---|
| `string` | `String` | Owned; use `&str` for borrowed |
| `number` (integer) | `i32` / `i64` / `u32` / `u64` | Pick size by domain |
| `number` (float) | `f64` | Default for JS numbers |
| `boolean` | `bool` | |
| `bigint` | `i128` / `u128` or `num::BigInt` | |
| `any` / `unknown` | `serde_json::Value` | Or generic `T` |
| `void` | `()` | Unit type |
| `never` | `!` (never type) | Or `Infallible` |
| `null` / `undefined` | `Option<T>` | Both collapse to `Option` |
| `Date` | `chrono::DateTime<Utc>` | Crate: `chrono` |
| `string[]` / `Array<T>` | `Vec<T>` | |
| `[T, U]` (tuple) | `(T, U)` | |
| `Record<K, V>` | `HashMap<K, V>` | `BTreeMap` if ordering needed |
| `Map<K, V>` | `HashMap<K, V>` | |
| `Set<T>` | `HashSet<T>` | |
| `Buffer` | `Vec<u8>` or `bytes::Bytes` | |
| `RegExp` | `regex::Regex` | Crate: `regex` |
| `Error` | Custom enum implementing `std::error::Error` | Use `thiserror` |
| `symbol` | No equivalent | Redesign with enums or strings |

## TypeScript Constructs

| TypeScript | Rust | Notes |
|---|---|---|
| `interface Foo { }` | `struct Foo { }` | Add `#[derive(Debug, Clone, Serialize, Deserialize)]` |
| `type Foo = { }` | `struct Foo { }` | Same as interface |
| `type Foo = string` | `type Foo = String;` | Direct alias |
| `type Foo = A \| B` (union) | `enum Foo { A(A), B(B) }` | `#[serde(untagged)]` |
| `type Foo = A & B` (intersection) | Struct with `#[serde(flatten)]` fields | Or trait composition |
| `enum E { A, B }` (numeric) | `enum E { A, B }` | `#[repr(i32)]` if values matter |
| `enum E { A = "a" }` (string) | `enum E { A }` + `strum` | `#[strum(serialize = "a")]` |
| Discriminated union `{ type: "a" }` | `#[serde(tag = "type")]` enum | Internally tagged |
| `Partial<T>` | Separate struct, all fields `Option<T>` | `#[serde(skip_serializing_if)]` |
| `Required<T>` | Struct with no `Option` fields | Default Rust struct |
| `Pick<T, K>` | New struct with selected fields only | Manual |
| `Omit<T, K>` | New struct without excluded fields | Manual |
| `Readonly<T>` | Default (immutable by default) | No action needed |
| `keyof T` | Enum of field names | No direct equivalent |
| `typeof value` | No equivalent | Types always explicit |
| Generic `T extends U` | `T: TraitBound` | Trait bounds |
| Conditional type | Separate impls or trait specialization | Case-by-case |
| Template literal type | Newtype with validation | Runtime validation |

## Null/Optional Patterns

| TypeScript | Rust | Notes |
|---|---|---|
| `T \| null` | `Option<T>` | |
| `T \| undefined` | `Option<T>` | |
| `field?: T` | `Option<T>` | `#[serde(skip_serializing_if = "Option::is_none")]` |
| `param?: T` | `Option<T>` | Or builder pattern |
| `a?.b` | `a.as_ref().map(\|a\| &a.b)` | |
| `a?.b?.c` | `a.as_ref().and_then(\|a\| a.b.as_ref()).map(\|b\| &b.c)` | Chain combinators |
| `value ?? fallback` | `.unwrap_or(fallback)` | Or `.unwrap_or_else(\|\| ...)` |
| `value!` (non-null assert) | `.expect("reason")` | Prefer `?` or `.ok_or()` |
| `if (x !== null) { x.foo }` | `if let Some(x) = x { x.foo }` | |
| `typeof x !== "undefined"` | `x.is_some()` | |
| `!!value` (to bool) | `.is_some()` or `.unwrap_or(false)` | |
| Null-as-not-found return | `Result<Option<T>, E>` | Separates "not found" from error |
| Null-as-error return | `Result<T, E>` | Error variant for the failure |
| `#[serde(default)]` on `Vec` | Defaults to empty if missing from JSON | |
| `#[serde(default = "fn")]` | Custom default when field missing | |

## Error Handling Patterns

| TypeScript | Rust | Notes |
|---|---|---|
| `try { } catch (e) { }` | `match result { Ok(v) => ..., Err(e) => ... }` | Or `?` operator |
| `throw new Error("msg")` | `return Err(AppError::Msg("msg".into()))` | Typed error enum |
| `class AppError extends Error` | `#[derive(thiserror::Error)] enum AppError` | thiserror derive |
| `class NotFoundError extends AppError` | `AppError::NotFound` variant | Flatten hierarchy |
| `Promise.reject(err)` | `Err(err)` in async fn | Same Result<T, E> |
| `catch (e) { if (e instanceof X) }` | `match err { AppError::X(e) => ... }` | Pattern matching |
| `express error middleware` | `axum IntoResponse for AppError` | Tower error handling |
| `throw` in constructor | `fn new() -> Result<Self, Error>` | Fallible construction |
| `Error.cause` (chaining) | `.source()` or `#[from]` | thiserror `#[source]` |
| `AggregateError` | `Vec<Error>` or multi-variant enum | |

## Class -> Struct Patterns

| TypeScript | Rust | When |
|---|---|---|
| `class Foo { }` (no inheritance) | `struct Foo { }` + `impl Foo { }` | Default |
| `class Foo extends Bar` (open) | Embed `Bar` in `Foo` + trait delegation | Extensible hierarchy |
| `class Foo extends Bar` (closed set) | `enum FooKind { A(A), B(B) }` | Known subclasses |
| `abstract class Base` | `trait Base` with default methods | Abstract + concrete methods |
| `class Foo implements IFoo` | `impl IFoo for Foo` | |
| `extends` + `implements` x N | `struct` + multiple `impl Trait for` | |
| Mixin `extends mix(A, B)` | Multiple trait impls | Composition |
| `static method()` | `fn method()` (no `self`) | Associated function |
| `private field` | No `pub` prefix | Module-private |
| `protected field` | `pub(crate) field` | Crate-visible |
| `public field` | `pub field` | |
| `readonly field` | Default (immutable via `&self`) | |
| `constructor()` | `fn new() -> Self` | Rust convention |
| `get prop()` / `set prop()` | `fn prop(&self)` / `fn set_prop(&mut self, v)` | Explicit methods |
| `@decorator` | Trait impl or proc macro | See patterns section |
| `instanceof` | `match` on enum variant | Or `matches!()` macro |
| `this` | `&self` / `&mut self` | Explicit receiver |
| Singleton class | DI via `Arc<T>` (preferred) or `LazyLock` | Avoid global state |
| Static-only utility class | Module with free functions | `pub mod utils { }` |
| Callback binding (`this.fn.bind`) | Clone data into closure | No `this` issues in Rust |

## Async Patterns

| TypeScript | Rust | Notes |
|---|---|---|
| `async function foo(): Promise<T>` | `async fn foo() -> Result<T, E>` | Always `Result` for fallibility |
| `await expr` | `expr.await` | Postfix syntax |
| `.then(fn)` | `.await` + sequential code | Flatten chains |
| `.catch(fn)` | `match` or `?` operator | |
| `.finally(fn)` | `Drop` impl or explicit cleanup | |
| `Promise.all([a, b, c])` (fixed) | `tokio::join!(a, b, c)` | Compile-time known count |
| `Promise.all(arr.map(fn))` (dynamic) | `futures::future::join_all(futs)` | |
| `Promise.allSettled(...)` | `JoinSet` + individual Result handling | |
| `Promise.race([a, b])` | `tokio::select!` | First to complete wins |
| `Promise.any([a, b])` | `JoinSet` + first `Ok` wins | Collect errors |
| `new Promise((resolve, reject))` | `tokio::sync::oneshot` or direct async | |
| `setTimeout(fn, ms)` | `tokio::time::sleep` + `tokio::spawn` | |
| `setInterval(fn, ms)` | `tokio::time::interval` in a loop | |
| `clearTimeout` / `clearInterval` | `JoinHandle::abort()` or `CancellationToken` | |
| `EventEmitter.on(event, fn)` | `tokio::sync::broadcast` receiver loop | |
| `EventEmitter.once(event, fn)` | `broadcast::Receiver::recv()` (single) | Task ends after one event |
| `EventEmitter.emit(event, data)` | `broadcast::Sender::send(data)` | Typed enum events |
| `process.nextTick(fn)` | `tokio::task::yield_now()` | |
| `setImmediate(fn)` | `tokio::spawn(async { fn() })` | |
| Readable stream | `tokio::io::AsyncRead` / `BufReader` | |
| `async function*` generator | `async_stream::stream!` or channel | |
| `AbortController` / `AbortSignal` | `tokio_util::sync::CancellationToken` | |
| `worker_threads` | `tokio::task::spawn_blocking` or `rayon` | CPU-bound |
| Concurrency limit (`p-limit`) | `futures::stream::buffer_unordered(n)` | |
| Retry with backoff | `backoff` crate | Or manual loop |
| Timeout | `tokio::time::timeout(dur, fut)` | |

## NPM -> Crate Mapping

### HTTP Server

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `express` | `axum` | 0.8 | HIGH |
| `fastify` | `axum` | 0.8 | HIGH |
| `koa` | `axum` | 0.8 | HIGH |
| `@nestjs/core` | `axum` + manual DI | 0.8 | MEDIUM |
| `@nestjs/swagger` | `utoipa` | 5 | HIGH |
| `cors` | `tower-http` (CorsLayer) | 0.6 | HIGH |
| `helmet` | `tower-http` (headers) | 0.6 | HIGH |
| `compression` | `tower-http` (CompressionLayer) | 0.6 | HIGH |
| `body-parser` | Built-in axum extractors | - | HIGH |
| `multer` | `axum-extra` (Multipart) | 0.10 | HIGH |
| `cookie-parser` | `tower-cookies` | 0.10 | HIGH |
| `express-rate-limit` | `tower-governor` | 0.5 | HIGH |
| `serve-static` | `tower-http` (ServeDir) | 0.6 | HIGH |
| `morgan` | `tower-http` (TraceLayer) | 0.6 | HIGH |

### HTTP Client

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `axios` | `reqwest` | 0.12 | HIGH |
| `node-fetch` | `reqwest` | 0.12 | HIGH |
| `got` | `reqwest` + `reqwest-retry` | 0.12 | HIGH |
| `undici` | `reqwest` / `hyper` | 0.12 / 1 | HIGH |

### Database / ORM

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `prisma` | `sqlx` | 0.8 | MEDIUM |
| `typeorm` | `sea-orm` | 1 | MEDIUM |
| `sequelize` | `sea-orm` | 1 | MEDIUM |
| `mongoose` | `mongodb` | 3 | HIGH |
| `knex` | `sqlx` | 0.8 | HIGH |
| `drizzle-orm` | `sqlx` | 0.8 | MEDIUM |
| `pg` / `pg-pool` | `sqlx` (postgres feature) | 0.8 | HIGH |
| `mysql2` | `sqlx` (mysql feature) | 0.8 | HIGH |
| `better-sqlite3` | `rusqlite` / `sqlx` | 0.32 / 0.8 | HIGH |
| `ioredis` / `redis` | `redis` | 0.27 | HIGH |

### Auth and Security

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `jsonwebtoken` / `jose` | `jsonwebtoken` | 9 | HIGH |
| `bcrypt` / `bcryptjs` | `bcrypt` or `argon2` | 0.16 / 0.5 | HIGH |
| `argon2` | `argon2` | 0.5 | HIGH |
| `passport` | Custom middleware | - | MEDIUM |
| `express-session` | `tower-sessions` | 0.13 | MEDIUM |

### Validation

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `zod` / `joi` / `yup` | `validator` + `serde` | 0.19 / 1 | MEDIUM |
| `class-validator` | `validator` | 0.19 | HIGH |
| `class-transformer` | `serde` | 1 | HIGH |
| `ajv` | `jsonschema` | 0.26 | HIGH |

### CLI and Terminal

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `commander` / `yargs` | `clap` | 4 | HIGH |
| `inquirer` | `dialoguer` | 0.11 | HIGH |
| `chalk` | `colored` | 3 | HIGH |
| `ora` / `progress` | `indicatif` | 0.17 | HIGH |
| `cli-table3` | `tabled` | 0.17 | HIGH |
| `glob` / `minimatch` | `glob` | 0.3 | HIGH |

### Testing

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `jest` / `vitest` / `mocha` | Built-in `#[test]` | - | HIGH |
| `chai` | `pretty_assertions` | 1 | HIGH |
| `sinon` | `mockall` | 0.13 | HIGH |
| `supertest` | `axum-test` | 16 | HIGH |
| `nock` | `wiremock` | 0.6 | HIGH |
| `faker` | `fake` | 3 | HIGH |
| `nyc` / `c8` | `cargo-tarpaulin` / `cargo-llvm-cov` | - | HIGH |

### Logging and Observability

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `winston` / `pino` / `bunyan` | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | HIGH |
| `debug` | `tracing` with env filter | 0.1 | HIGH |
| `morgan` | `tower-http::trace` | 0.6 | HIGH |
| `prom-client` | `metrics` + `metrics-exporter-prometheus` | 0.24 / 0.16 | HIGH |
| `@opentelemetry/*` | `opentelemetry` + `tracing-opentelemetry` | 0.28 | HIGH |

### Config and Environment

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `dotenv` | `dotenvy` | 0.15 | HIGH |
| `config` | `config` | 0.14 | HIGH |
| `envalid` | `envy` | 0.4 | HIGH |

### Serialization and Data

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `csv-parse` | `csv` | 1 | HIGH |
| `xml2js` / `fast-xml-parser` | `quick-xml` + `serde` | 0.37 | HIGH |
| `js-yaml` | `serde_yaml` | 0.9 | HIGH |
| `protobufjs` | `prost` | 0.13 | HIGH |
| `msgpack` | `rmp-serde` | 1 | HIGH |
| `uuid` | `uuid` | 1 | HIGH |
| `nanoid` | `nanoid` | 0.4 | HIGH |

### Date and Time

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `dayjs` / `moment` / `luxon` / `date-fns` | `chrono` (+ `chrono-tz`) | 0.4 | HIGH |
| `ms` | `humantime` | 2 | HIGH |
| `cron` / `node-cron` | `cron` | 0.13 | HIGH |

### WebSocket and Real-Time

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `ws` | `tokio-tungstenite` | 0.24 | HIGH |
| `socket.io` | `axum` WS + custom protocol | 0.8 | MEDIUM |
| `sse` / `better-sse` | `axum` (Sse response) | 0.8 | HIGH |
| `graphql-ws` | `async-graphql` | 7 | HIGH |

### Message Queues

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `bull` / `bullmq` | `apalis` | 0.6 | MEDIUM |
| `amqplib` | `lapin` | 2 | HIGH |
| `kafkajs` | `rdkafka` | 0.36 | HIGH |
| `node-schedule` | `tokio-cron-scheduler` | 0.13 | HIGH |

### Caching, Crypto, Email, File, GraphQL

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `node-cache` / `lru-cache` | `moka` | 0.12 | HIGH |
| `node:crypto` | `ring` + `sha2` + `hmac` | 0.17 / 0.10 / 0.12 | HIGH |
| `nodemailer` | `lettre` | 0.11 | HIGH |
| `node:fs` / `fs-extra` | `std::fs` + `tokio::fs` | - | HIGH |
| `@aws-sdk/client-s3` | `aws-sdk-s3` | 1 | HIGH |
| `sharp` | `image` | 0.25 | MEDIUM |
| `chokidar` | `notify` | 7 | HIGH |
| `tempfile` | `tempfile` | 3 | HIGH |
| `@apollo/server` / `type-graphql` | `async-graphql` | 7 | HIGH |
| `dataloader` | `async-graphql` (built-in) | 7 | HIGH |

### Utilities

| npm Package | Rust Crate | Version | Confidence |
|---|---|---|---|
| `lodash` | Iterator methods (stdlib) | - | HIGH |
| `rxjs` | `tokio-stream` + `futures` | 0.1 / 0.3 | MEDIUM |
| `p-limit` / `p-queue` | `buffer_unordered` / `Semaphore` | 0.3 / 1 | HIGH |
| `retry` / `p-retry` | `backoff` | 0.4 | HIGH |
| `semver` | `semver` | 1 | HIGH |
| `url` | `url` | 2 | HIGH |
| `qs` / `querystring` | `serde_qs` / `serde_urlencoded` | 0.13 / 0.7 | HIGH |
| `base64` | `base64` | 0.22 | HIGH |
| `marked` / `markdown-it` | `pulldown-cmark` | 0.12 | HIGH |
| `sanitize-html` | `ammonia` | 4 | HIGH |
| `cheerio` | `scraper` | 0.21 | HIGH |
| `puppeteer` / `playwright` | `chromiumoxide` / `headless-chrome` | 0.7 / 1 | MEDIUM |
| `handlebars` | `handlebars` | 6 | HIGH |
| `ejs` / `nunjucks` | `tera` | 1 | HIGH |
| `eventemitter3` | `tokio::sync::broadcast` | 1 | MEDIUM |

## Common Pattern Transforms

| TypeScript Pattern | Rust Equivalent | Notes |
|---|---|---|
| `@Controller("path")` | `Router::new().nest("/path", ...)` | Route prefix via nesting |
| `@Get()` / `@Post()` decorators | `routing::get(handler)` / `routing::post(handler)` | axum routing |
| `@Body()` / `@Param()` / `@Query()` | `Json<T>` / `Path<T>` / `Query<T>` extractors | |
| `@UseGuards(AuthGuard)` | `middleware::from_fn(auth_middleware)` | Tower layer |
| `@Injectable` + DI container | `struct` + `Arc<dyn Trait>` constructor params | Manual wiring in main |
| Express `next()` middleware | `next.run(request).await` | axum middleware |
| Barrel exports (`index.ts`) | `mod.rs` with `pub use` re-exports | |
| TypeScript namespace | `pub mod name { }` | |
| Type guard `value is T` | `match` / `matches!()` on enum | |
| Assertion function `asserts x is T` | `.ok_or(Error)?` or `assert!()` | |
| Branded type `string & { __brand }` | Newtype struct `struct Id(String)` | Zero-cost in Rust |
| `as const` array | `const ARR: &[&str] = &[...]` | Or enum |
| `as const` object | `const` struct or `mod` with constants | |
| `satisfies Record<K,V>` | Type annotation on binding | Always explicit in Rust |
| Side-effect import | Explicit `init()` call in `main()` | No implicit side effects |
| `req.user = decoded` (augmentation) | `request.extensions_mut().insert(user)` | axum extensions |
| `switch` on discriminant | `match` on enum | Exhaustive by default |
