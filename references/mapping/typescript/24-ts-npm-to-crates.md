# 24 - NPM Package to Rust Crate Mapping Reference

**Output**: `.migration-plan/mappings/npm-to-crates.md`

## Purpose

Provide a comprehensive mapping of NPM packages commonly found in TypeScript projects to their Rust crate equivalents. This is the TypeScript-specific extension of the common crate recommendations guide (15), covering 50+ npm packages organized by category with version numbers, confidence ratings, and API-level migration notes. For every npm dependency found in the source project's `package.json`, this guide provides the recommended Rust crate with concrete usage examples.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `dependency-tree.md` -- complete list of npm dependencies from `package.json` (both `dependencies` and `devDependencies`)
- `architecture.md` -- how dependencies are used (framework-level vs. utility-level)

### Step 2: For each npm dependency, find Rust equivalent

1. Look up the package in the category tables below
2. If found, use the recommended crate with the listed version
3. If not found, search crates.io for alternatives or note as `NO_EQUIVALENT`
4. Record the confidence level for each mapping

**Confidence levels:**

| Level | Meaning |
|-------|---------|
| HIGH | Direct equivalent, well-maintained, widely used, API parity > 90% |
| MEDIUM | Good equivalent but API differs significantly, or less mature |
| LOW | Partial equivalent, missing features, may need custom code |
| NONE | No crate exists; must implement manually or redesign |

### Step 3: Produce dependency mapping

For EACH npm dependency, produce an entry with:
1. NPM package name and version
2. Rust crate name and version
3. Confidence level
4. API mapping notes (key differences)
5. Migration effort estimate

## Crate Mapping Tables

### HTTP Server Frameworks

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `express` | 4.x / 5.x | `axum` | 0.8 | HIGH | Router + handlers + middleware; `app.get()` -> `Router::new().route()` |
| `fastify` | 4.x / 5.x | `axum` | 0.8 | HIGH | Schema validation via extractors; plugins -> tower layers |
| `koa` | 2.x | `axum` | 0.8 | HIGH | Middleware `ctx` -> extractors; `ctx.body` -> `Json()`/`Response` |
| `hapi` | 21.x | `axum` | 0.8 | MEDIUM | Plugin system has no direct equivalent; route config -> router |
| `@nestjs/core` | 10.x | `axum` + manual DI | 0.8 | MEDIUM | No decorator/DI framework; modules -> Rust modules; guards -> middleware |
| `@nestjs/swagger` | 7.x | `utoipa` | 5 | HIGH | Derive macros generate OpenAPI spec |
| `cors` / `@koa/cors` | 2.x | `tower-http` | 0.6 | HIGH | `CorsLayer` from tower-http; same config options |
| `helmet` | 7.x | `tower-http` | 0.6 | HIGH | Security headers via `SetResponseHeaderLayer` |
| `compression` | 1.x | `tower-http` | 0.6 | HIGH | `CompressionLayer` from tower-http |
| `body-parser` | 1.x | Built-in (axum) | - | HIGH | `Json<T>`, `Form<T>` extractors handle parsing |
| `multer` | 1.x | `axum-extra` | 0.10 | HIGH | `Multipart` extractor for file uploads |
| `cookie-parser` | 1.x | `tower-cookies` | 0.10 | HIGH | Cookie middleware layer |
| `express-rate-limit` | 7.x | `tower-governor` | 0.5 | HIGH | Rate limiting as tower middleware |
| `serve-static` | 1.x | `tower-http` | 0.6 | HIGH | `ServeDir` / `ServeFile` from tower-http |
| `morgan` | 1.x | `tower-http` | 0.6 | HIGH | `TraceLayer` for request logging |

### HTTP Client

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `axios` | 1.x | `reqwest` | 0.12 | HIGH | `axios.get()` -> `client.get().send().await`; interceptors -> reqwest-middleware |
| `node-fetch` | 3.x | `reqwest` | 0.12 | HIGH | `fetch(url)` -> `reqwest::get(url).await` |
| `got` | 14.x | `reqwest` | 0.12 | HIGH | Retry via `reqwest-middleware` + `reqwest-retry` |
| `superagent` | 9.x | `reqwest` | 0.12 | HIGH | Builder pattern matches closely |
| `undici` | 6.x | `reqwest` / `hyper` | 0.12 / 1 | HIGH | High-performance HTTP client |
| `node:http` / `node:https` | - | `hyper` | 1 | HIGH | Low-level HTTP; most projects should use reqwest |
| `http-proxy-middleware` | 3.x | `tower-http` + `hyper` | 0.6 / 1 | MEDIUM | Manual reverse proxy with hyper |

### Database / ORM

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `prisma` / `@prisma/client` | 5.x / 6.x | `sqlx` | 0.8 | MEDIUM | No schema-first ORM; use compile-time checked queries; migrations via sqlx-cli |
| `typeorm` | 0.3.x | `sea-orm` | 1 | MEDIUM | Decorator entities -> derive macros; query builder -> sea-query |
| `sequelize` | 6.x | `sea-orm` | 1 | MEDIUM | Active record -> active model in sea-orm |
| `mongoose` | 8.x | `mongodb` | 3 | HIGH | `Schema` -> `#[derive(Serialize, Deserialize)]`; queries are similar |
| `knex` | 3.x | `sqlx` | 0.8 | HIGH | Query builder -> raw SQL with compile-time checks |
| `drizzle-orm` | 0.35.x | `sqlx` | 0.8 | MEDIUM | Type-safe SQL; drizzle's approach is close to sqlx |
| `pg` / `pg-pool` | 8.x | `sqlx` | 0.8 | HIGH | `pool.query()` -> `sqlx::query().fetch()` |
| `mysql2` | 3.x | `sqlx` | 0.8 | HIGH | Same pattern as pg; use `sqlx` mysql feature |
| `better-sqlite3` | 11.x | `sqlx` or `rusqlite` | 0.8 / 0.32 | HIGH | `rusqlite` for sync; `sqlx` for async |
| `ioredis` | 5.x | `redis` | 0.27 | HIGH | `redis.get()` -> `cmd("GET").arg(key).query_async()` |
| `redis` | 4.x | `redis` | 0.27 | HIGH | Same crate as ioredis mapping |
| `node-redis` | 4.x | `redis` | 0.27 | HIGH | Same crate |
| `typeorm-naming-strategies` | 4.x | `sea-orm` (built-in) | 1 | HIGH | Naming conventions via `#[sea_orm(table_name)]` |

### Authentication and Security

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `jsonwebtoken` | 9.x | `jsonwebtoken` | 9 | HIGH | `jwt.sign()` -> `encode()`; `jwt.verify()` -> `decode()` |
| `jose` | 5.x | `jsonwebtoken` | 9 | HIGH | JWT/JWE/JWK handling |
| `passport` | 0.7.x | Custom middleware | - | MEDIUM | No equivalent framework; implement auth middleware manually |
| `bcrypt` / `bcryptjs` | 5.x / 2.x | `bcrypt` or `argon2` | 0.16 / 0.5 | HIGH | `argon2` preferred for new projects |
| `argon2` | 0.40.x | `argon2` | 0.5 | HIGH | Direct equivalent |
| `helmet` | 7.x | `tower-http` headers | 0.6 | HIGH | Set security headers via `SetResponseHeader` |
| `csurf` | 1.x | Custom implementation | - | LOW | CSRF tokens via middleware; no standard crate |
| `express-session` | 1.x | `tower-sessions` | 0.13 | MEDIUM | Session management middleware |
| `connect-redis` | 7.x | `tower-sessions-redis-store` | 0.5 | MEDIUM | Redis session store |
| `oauth2-server` | 4.x | `oxide-auth` | 0.5 | MEDIUM | OAuth2 server implementation |

### Validation

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `zod` | 3.x | `validator` + `serde` | 0.19 / 1 | MEDIUM | Schema objects -> derive macros; `.parse()` -> `.validate()` |
| `joi` | 17.x | `validator` | 0.19 | MEDIUM | Schema objects -> derive macros |
| `yup` | 1.x | `validator` | 0.19 | MEDIUM | Schema objects -> derive macros |
| `class-validator` | 0.14.x | `validator` | 0.19 | HIGH | Decorator `@IsEmail()` -> `#[validate(email)]` |
| `class-transformer` | 0.5.x | `serde` | 1 | HIGH | `@Transform()` -> `#[serde(rename, default, skip)]` |
| `ajv` | 8.x | `jsonschema` | 0.26 | HIGH | JSON Schema validation |
| `express-validator` | 7.x | `validator` + axum extractors | 0.19 | MEDIUM | Validation in request handlers |

### CLI and Terminal

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `commander` | 12.x | `clap` | 4 | HIGH | `.option()` -> `#[arg]` derive; `.command()` -> `#[command(subcommand)]` |
| `yargs` | 17.x | `clap` | 4 | HIGH | Similar subcommand + option API |
| `inquirer` / `@inquirer/prompts` | 10.x | `dialoguer` | 0.11 | HIGH | `input()` -> `Input::new()`; `select()` -> `Select::new()` |
| `chalk` | 5.x | `colored` | 3 | HIGH | `chalk.red()` -> `"text".red()` |
| `ora` | 8.x | `indicatif` | 0.17 | HIGH | Spinner -> `ProgressBar::new_spinner()` |
| `progress` | 2.x | `indicatif` | 0.17 | HIGH | Progress bar with templates |
| `cli-table3` | 0.6.x | `tabled` | 0.17 | HIGH | Table formatting |
| `figlet` | 1.x | `figlet-rs` | 0.1 | MEDIUM | ASCII art text |
| `boxen` | 8.x | Custom or `tabled` | - | LOW | Box drawing; manual implementation |
| `glob` | 11.x | `glob` | 0.3 | HIGH | File pattern matching |
| `minimatch` | 10.x | `glob` | 0.3 | HIGH | Glob pattern matching |

### Testing

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `jest` | 29.x | Built-in `#[test]` | - | HIGH | `describe` -> `mod tests`; `it` -> `#[test] fn`; `expect` -> `assert!` |
| `vitest` | 2.x | Built-in `#[test]` | - | HIGH | Same mapping as jest |
| `mocha` | 10.x | Built-in `#[test]` | - | HIGH | `describe/it` -> `mod/fn` |
| `chai` | 5.x | `pretty_assertions` | 1 | HIGH | `expect().to.equal()` -> `assert_eq!()` |
| `sinon` | 18.x | `mockall` | 0.13 | HIGH | `stub()` -> `expect_method().returning()`; `spy` -> `expect_method().times(1)` |
| `supertest` | 7.x | `axum-test` | 16 | HIGH | `request(app).get()` -> `server.get()` |
| `nock` | 13.x | `wiremock` | 0.6 | HIGH | HTTP mocking; `nock(url)` -> `Mock::given()` |
| `faker` / `@faker-js/faker` | 9.x | `fake` | 3 | HIGH | `faker.name()` -> `Faker.fake::<Name>()` |
| `jest-mock-extended` | 3.x | `mockall` | 0.13 | HIGH | Deep mock generation |
| `ts-jest` | 29.x | N/A | - | HIGH | Not needed; Rust tests are native |
| `c8` / `istanbul` / `nyc` | 10.x | `cargo-tarpaulin` or `cargo-llvm-cov` | - | HIGH | `cargo tarpaulin` or `cargo llvm-cov` |

### Logging and Observability

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `winston` | 3.x | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | HIGH | `logger.info()` -> `tracing::info!()`; transports -> layers |
| `pino` | 9.x | `tracing` + `tracing-subscriber` | 0.1 / 0.3 | HIGH | JSON logging via `fmt::layer().json()` |
| `bunyan` | 1.x | `tracing` | 0.1 | HIGH | Structured logging |
| `debug` | 4.x | `tracing` with filter | 0.1 | HIGH | `DEBUG=app:*` -> `RUST_LOG=app=debug` |
| `morgan` | 1.x | `tower-http::trace` | 0.6 | HIGH | HTTP request logging middleware |
| `prom-client` | 15.x | `metrics` + `metrics-exporter-prometheus` | 0.24 / 0.16 | HIGH | Prometheus metrics |
| `@opentelemetry/*` | 1.x | `opentelemetry` + `tracing-opentelemetry` | 0.28 / 0.28 | HIGH | OTEL traces, metrics, logs |

### Configuration and Environment

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `dotenv` | 16.x | `dotenvy` | 0.15 | HIGH | `dotenv.config()` -> `dotenvy::dotenv().ok()` |
| `config` | 3.x | `config` | 0.14 | HIGH | Layered config from files + env |
| `convict` | 6.x | `config` + `serde` | 0.14 / 1 | MEDIUM | Schema-based config -> typed struct deserialization |
| `cross-env` | 7.x | N/A | - | HIGH | Not needed; use `.env` files or shell env |
| `envalid` | 8.x | `envy` | 0.4 | HIGH | Env var validation -> typed struct deserialization |

### Serialization and Data Formats

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `class-transformer` | 0.5.x | `serde` | 1 | HIGH | `@Expose()/@Exclude()` -> `#[serde(skip)]`; `@Transform()` -> `#[serde(deserialize_with)]` |
| `csv-parse` / `csv-stringify` | 5.x | `csv` | 1 | HIGH | Reader/Writer via serde |
| `xml2js` / `fast-xml-parser` | 4.x | `quick-xml` + `serde` | 0.37 / 1 | HIGH | XML <-> struct via serde |
| `yaml` / `js-yaml` | 4.x | `serde_yaml` | 0.9 | HIGH | YAML <-> struct via serde |
| `protobufjs` | 7.x | `prost` | 0.13 | HIGH | .proto code generation with prost-build |
| `msgpack` / `@msgpack/msgpack` | 3.x | `rmp-serde` | 1 | HIGH | MessagePack via serde |
| `flatbuffers` | 24.x | `flatbuffers` | 24 | HIGH | Direct equivalent |
| `uuid` | 10.x | `uuid` | 1 | HIGH | `v4()` -> `Uuid::new_v4()` |
| `nanoid` | 5.x | `nanoid` | 0.4 | HIGH | `nanoid()` -> `nanoid::nanoid!()` |

### Date and Time

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `dayjs` | 1.x | `chrono` | 0.4 | HIGH | `dayjs()` -> `Utc::now()`; `.format()` -> `.format()` |
| `moment` | 2.x | `chrono` | 0.4 | HIGH | Deprecated in JS; chrono is the standard |
| `luxon` | 3.x | `chrono` + `chrono-tz` | 0.4 / 0.10 | HIGH | Timezone support via chrono-tz |
| `date-fns` | 4.x | `chrono` | 0.4 | HIGH | Functional API -> method calls on DateTime |
| `ms` | 2.x | `humantime` | 2 | HIGH | `ms("2 days")` -> `humantime::parse_duration("2days")` |
| `cron` / `node-cron` | 3.x | `cron` | 0.13 | HIGH | Cron expression parsing and scheduling |

### WebSocket and Real-Time

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `socket.io` | 4.x | `axum` (built-in WS) + custom protocol | 0.8 | MEDIUM | No socket.io equivalent; use raw WebSocket with custom rooms/events |
| `ws` | 8.x | `tokio-tungstenite` | 0.24 | HIGH | `new WebSocket(url)` -> `connect_async(url)` |
| `@socket.io/redis-adapter` | 8.x | Custom with `redis` | - | LOW | Must implement pub/sub room management |
| `socket.io-client` | 4.x | `tokio-tungstenite` | 0.24 | MEDIUM | Client-side WebSocket |
| `sse` / `better-sse` | 2.x | `axum` (SSE support) | 0.8 | HIGH | `Sse` response type in axum |
| `graphql-ws` | 5.x | `async-graphql` | 7 | HIGH | GraphQL subscription transport |

### Message Queues and Background Jobs

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `bull` / `bullmq` | 5.x | `apalis` | 0.6 | MEDIUM | Redis-backed job queue; `Queue.add()` -> `push_job()` |
| `amqplib` | 0.10.x | `lapin` | 2 | HIGH | RabbitMQ client; `channel.sendToQueue()` -> `basic_publish()` |
| `kafkajs` | 2.x | `rdkafka` | 0.36 | HIGH | Kafka producer/consumer |
| `agenda` | 5.x | `apalis` | 0.6 | MEDIUM | MongoDB-backed job scheduler |
| `node-schedule` | 2.x | `tokio-cron-scheduler` | 0.13 | HIGH | Cron-based task scheduling |

### Caching

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `ioredis` | 5.x | `redis` | 0.27 | HIGH | Async Redis client; pipeline/cluster support |
| `node-cache` | 5.x | `moka` | 0.12 | HIGH | In-memory cache with TTL; `set(key, val, ttl)` -> `cache.insert(key, val).await` |
| `lru-cache` | 11.x | `lru` or `moka` | 0.12 / 0.12 | HIGH | LRU eviction cache |
| `keyv` | 5.x | Custom or `redis` | - | MEDIUM | Multi-backend cache; implement per-backend |
| `memcached` | 2.x | `memcache` | 0.2 | MEDIUM | Memcached client |

### Crypto and Hashing

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `node:crypto` | - | `ring` + `sha2` + `hmac` | 0.17 / 0.10 / 0.12 | HIGH | `createHash('sha256')` -> `Sha256::digest()` |
| `crypto-js` | 4.x | `aes-gcm` / `ring` | 0.10 / 0.17 | HIGH | AES encryption; use ring for general crypto |
| `bcrypt` | 5.x | `bcrypt` or `argon2` | 0.16 / 0.5 | HIGH | Password hashing; argon2 preferred |
| `scrypt-js` | 3.x | `scrypt` | 0.11 | HIGH | Scrypt key derivation |
| `node-forge` | 1.x | `ring` + `rustls` | 0.17 | HIGH | PKI/TLS operations |
| `tweetnacl` | 1.x | `ed25519-dalek` | 2 | HIGH | Ed25519 signing |

### Email

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `nodemailer` | 6.x | `lettre` | 0.11 | HIGH | `transporter.sendMail()` -> `mailer.send()` |
| `email-templates` | 12.x | `lettre` + `tera` | 0.11 / 1 | MEDIUM | Template rendering + email sending |
| `mailgun.js` | 10.x | `reqwest` (REST API) | 0.12 | MEDIUM | Call Mailgun API directly |
| `@sendgrid/mail` | 8.x | `reqwest` (REST API) | 0.12 | MEDIUM | Call SendGrid API directly |

### File and Storage

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `node:fs` / `fs-extra` | - | `std::fs` + `tokio::fs` | - | HIGH | `readFile` -> `tokio::fs::read_to_string()` |
| `multer` | 1.x | `axum` multipart | 0.8 | HIGH | File upload handling in request extractors |
| `@aws-sdk/client-s3` | 3.x | `aws-sdk-s3` | 1 | HIGH | Official AWS SDK for Rust |
| `minio-js` | 8.x | `aws-sdk-s3` | 1 | HIGH | MinIO is S3-compatible; use aws-sdk-s3 |
| `sharp` | 0.33.x | `image` | 0.25 | MEDIUM | Image processing; fewer high-level features |
| `archiver` / `adm-zip` | 7.x / 0.5.x | `zip` | 2 | HIGH | Zip archive creation/extraction |
| `chokidar` | 4.x | `notify` | 7 | HIGH | File system watching |
| `tmp` / `tmp-promise` | 0.2.x | `tempfile` | 3 | HIGH | Temporary file/directory creation |

### GraphQL

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `@apollo/server` | 4.x | `async-graphql` | 7 | HIGH | Schema definition via derive macros |
| `graphql` / `graphql-js` | 16.x | `async-graphql` | 7 | HIGH | Type system + execution |
| `@graphql-codegen/*` | 5.x | `async-graphql` derive | 7 | HIGH | Code-first via derive macros |
| `type-graphql` | 2.x | `async-graphql` | 7 | HIGH | Decorator classes -> derive macros |
| `dataloader` | 2.x | `async-graphql` (built-in) | 7 | HIGH | DataLoader is built into async-graphql |
| `mercurius` | 14.x | `async-graphql` + `axum` | 7 / 0.8 | HIGH | GraphQL integration with HTTP server |

### Templating

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `handlebars` | 4.x | `handlebars` | 6 | HIGH | Same template syntax |
| `ejs` | 3.x | `tera` | 1 | HIGH | Jinja2/Tera syntax differs from EJS |
| `pug` | 3.x | `tera` or `askama` | 1 / 0.12 | MEDIUM | Indentation syntax not preserved; rewrite templates |
| `nunjucks` | 3.x | `tera` | 1 | HIGH | Jinja2-compatible syntax matches well |
| `mustache` | 4.x | `ramhorns` | 1 | HIGH | Logic-less templates |

### Utilities and Miscellaneous

| NPM Package | Version | Rust Crate | Version | Confidence | API Mapping Notes |
|-------------|---------|------------|---------|------------|-------------------|
| `lodash` | 4.x | Iterator methods (stdlib) | - | HIGH | `_.map/filter/reduce` -> `.iter().map/filter/fold()` |
| `ramda` | 0.30.x | Iterator + closures | - | MEDIUM | Functional patterns via stdlib iterators |
| `rxjs` | 7.x | `tokio-stream` + `futures` | 0.1 / 0.3 | MEDIUM | Observables -> Streams; operators -> stream combinators |
| `p-limit` | 6.x | `futures::stream::buffer_unordered` | 0.3 | HIGH | Concurrency limiting |
| `p-queue` | 8.x | `tokio::sync::Semaphore` | 1 | HIGH | Concurrency-limited task queue |
| `retry` | 0.13.x | `backoff` | 0.4 | HIGH | Exponential backoff retry |
| `p-retry` | 6.x | `backoff` | 0.4 | HIGH | Promise retry with backoff |
| `async-retry` | 1.x | `backoff` | 0.4 | HIGH | Async retry |
| `semver` | 7.x | `semver` | 1 | HIGH | Semantic versioning; nearly identical API |
| `mime-types` | 2.x | `mime` | 0.3 | HIGH | MIME type detection |
| `url` / `node:url` | - | `url` | 2 | HIGH | URL parsing; `new URL()` -> `Url::parse()` |
| `querystring` / `qs` | 6.x | `serde_qs` or `serde_urlencoded` | 0.13 / 0.7 | HIGH | Query string parsing |
| `base64` | - | `base64` | 0.22 | HIGH | Base64 encode/decode |
| `slugify` | 1.x | `slug` | 0.1 | HIGH | URL-friendly string generation |
| `validator` (npm) | 13.x | `validator` (crate) | 0.19 | HIGH | String validation (email, URL, etc.) |
| `deep-equal` / `fast-deep-equal` | 2.x | `PartialEq` derive | - | HIGH | `#[derive(PartialEq)]` + `assert_eq!` |
| `eventemitter3` | 5.x | `tokio::sync::broadcast` | 1 | MEDIUM | Event emitter -> channel-based pub/sub |
| `cron-parser` | 4.x | `cron` | 0.13 | HIGH | Cron expression parsing |
| `marked` / `markdown-it` | 14.x | `pulldown-cmark` | 0.12 | HIGH | Markdown parsing |
| `sanitize-html` | 2.x | `ammonia` | 4 | HIGH | HTML sanitization |
| `cheerio` | 1.x | `scraper` | 0.21 | HIGH | HTML parsing and CSS selectors |
| `puppeteer` / `playwright` | 1.x | `chromiumoxide` or `headless-chrome` | 0.7 / 1 | MEDIUM | Browser automation |

## Template

```markdown
# NPM to Crate Dependency Mapping

Source: {project_name}
Generated: {date}

## Summary

| Category | Total Deps | HIGH | MEDIUM | LOW | NONE |
|----------|-----------|------|--------|-----|------|
| Runtime | {count} | {count} | {count} | {count} | {count} |
| Dev | {count} | {count} | {count} | {count} | {count} |
| **Total** | {count} | {count} | {count} | {count} | {count} |

## Runtime Dependencies

| # | NPM Package | Version | Purpose | Rust Crate | Version | Confidence | Notes |
|---|-------------|---------|---------|------------|---------|------------|-------|
| 1 | {package} | {version} | {purpose} | {crate} | {version} | {level} | {notes} |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Dev Dependencies

| # | NPM Package | Version | Purpose | Rust Crate | Version | Confidence | Notes |
|---|-------------|---------|---------|------------|---------|------------|-------|
| 1 | {package} | {version} | {purpose} | {crate} | {version} | {level} | {notes} |
| ... | ... | ... | ... | ... | ... | ... | ... |

## No-Equivalent Dependencies

| NPM Package | Purpose | Rust Strategy |
|-------------|---------|---------------|
| {package} | {purpose} | {manual implementation plan} |

## Generated Cargo.toml

```toml
[dependencies]
# Web framework
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace", "compression-gzip"] }

# Database
sqlx = { version = "0.8", features = ["runtime-tokio", "tls-rustls", "postgres", "uuid", "chrono", "json"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Error handling
thiserror = "2"
anyhow = "1"

# Authentication
jsonwebtoken = "9"
argon2 = "0.5"

# Validation
validator = { version = "0.19", features = ["derive"] }

# Logging
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# HTTP client
reqwest = { version = "0.12", features = ["json"] }

# Utilities
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
dotenvy = "0.15"
regex = "1"
url = "2"
base64 = "0.22"

# Async utilities
futures = "0.3"
tokio-stream = "0.1"
tokio-util = "0.7"

[dev-dependencies]
tokio = { version = "1", features = ["test-util", "macros", "rt-multi-thread"] }
mockall = "0.13"
wiremock = "0.6"
pretty_assertions = "1"
fake = { version = "3", features = ["derive"] }
axum-test = "16"
tempfile = "3"
```

## Feature Flag Reference

Key crate feature flags to enable:

| Crate | Feature | When to Enable |
|-------|---------|---------------|
| `tokio` | `"full"` | Always (production); minimal features for lib crates |
| `sqlx` | `"postgres"` / `"mysql"` / `"sqlite"` | Based on database backend |
| `sqlx` | `"uuid"`, `"chrono"`, `"json"` | When using these types in queries |
| `serde` | `"derive"` | Always |
| `uuid` | `"v4"`, `"serde"` | UUID generation + serialization |
| `chrono` | `"serde"` | DateTime serialization |
| `reqwest` | `"json"` | JSON request/response bodies |
| `validator` | `"derive"` | Derive macro validation |
| `tower-http` | `"cors"`, `"trace"`, `"compression-gzip"` | Per feature used |
| `tracing-subscriber` | `"env-filter"`, `"json"` | Log filtering + JSON output |
```

## Completeness Check

- [ ] Every runtime dependency in `package.json` has a mapping entry
- [ ] Every dev dependency in `package.json` has a mapping entry
- [ ] Confidence level is assigned for every mapping
- [ ] Dependencies with NO equivalent have an alternative strategy documented
- [ ] Version numbers for Rust crates are current
- [ ] Feature flags are specified for crates that need them
- [ ] Complete `Cargo.toml` is generated with all dependencies
- [ ] Dev-dependencies are separated from production dependencies
- [ ] Summary table shows counts by confidence level
- [ ] API mapping notes explain key differences for MEDIUM/LOW confidence items
- [ ] No deprecated crates are recommended (e.g., `dotenv` -> `dotenvy`)
