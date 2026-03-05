# 25 - TypeScript-Specific Pattern Conversions

**Output**: `.migration-plan/mappings/ts-patterns.md`

## Purpose

Map TypeScript-specific patterns and idioms that do not fit neatly into the type, class, async, or null mapping guides to their Rust equivalents. This covers decorators, dependency injection, middleware patterns, event-driven architecture, module augmentation, barrel exports, namespaces, type guards, assertion functions, and module-level side effects. These patterns are deeply embedded in TypeScript codebases and require deliberate architectural decisions during migration.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `type-catalog.md` -- decorators, type guards, assertion functions
- `architecture.md` -- DI containers, middleware chains, module structure, event architecture
- `dependency-tree.md` -- DI frameworks (inversify, tsyringe), decorator libraries, middleware packages
- `testing-build.md` -- build configuration (tsconfig paths, barrel exports, module resolution)

Extract every instance of:
- Decorator usage (`@Controller`, `@Injectable`, `@Get`, custom decorators)
- DI container configuration (inversify modules, tsyringe registration)
- Middleware patterns (Express `next()`, NestJS interceptors/guards/pipes)
- EventEmitter patterns beyond simple pub/sub
- Module augmentation and declaration merging
- Barrel exports (`index.ts` re-export files)
- TypeScript namespaces
- String-valued enums with reverse mapping
- Type guards (`is` return type)
- Assertion functions (`asserts` return type)
- Module-level side effects (import for side effects, polyfills)
- `satisfies` operator usage
- `as const` assertions
- Template literal types in runtime code
- Branded/opaque types

### Step 2: For each pattern, determine Rust equivalent

**Pattern conversion decision table:**

| TypeScript Pattern | Rust Equivalent | Complexity |
|-------------------|-----------------|-----------|
| Class decorator | Trait impl or proc macro | Medium |
| Method decorator | Trait method or attribute macro | Medium |
| Property decorator | Derive macro field attribute | Low |
| Parameter decorator | No equivalent; redesign | High |
| DI container (inversify/tsyringe) | Manual DI or `Arc<dyn Trait>` | Low |
| Express middleware `next()` | Tower `Layer` / `Service` | Medium |
| NestJS Guard | Tower middleware or extractor | Medium |
| NestJS Interceptor | Tower middleware | Medium |
| NestJS Pipe | Extractor with validation | Low |
| EventEmitter (complex) | `tokio::sync::broadcast` + enum | Medium |
| Declaration merging | Feature flags or extension traits | Low |
| Barrel exports (`index.ts`) | `mod.rs` with `pub use` re-exports | Low |
| Namespaces | Rust modules | Low |
| String enums | `strum` crate with derive macros | Low |
| Type guards | `match` arms on enums | Low |
| Assertion functions | `assert!` / `panic!` / `Result` | Low |
| Side-effect imports | `LazyLock` / `ctor` / init function | Low |
| Branded types | Newtype pattern | Low |
| `as const` | `const` / `static` | Low |
| `satisfies` | Trait bounds / type ascription | Low |

### Step 3: Produce pattern mapping document

For EACH pattern instance, produce:
1. Source code with file:line reference
2. Pattern category
3. Rust equivalent with compilable code
4. Migration complexity and rationale

## Code Examples

### Example 1: Decorators to Trait Implementations

**TypeScript (NestJS-style):**
```typescript
@Controller("users")
@UseGuards(AuthGuard)
@UseInterceptors(LoggingInterceptor)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @UseGuards(RolesGuard)
  @Roles("admin")
  async findAll(@Query() query: PaginationQuery): Promise<User[]> {
    return this.usersService.findAll(query);
  }

  @Get(":id")
  async findOne(@Param("id") id: string): Promise<User> {
    return this.usersService.findById(id);
  }

  @Post()
  @HttpCode(201)
  async create(@Body() createUserDto: CreateUserDto): Promise<User> {
    return this.usersService.create(createUserDto);
  }

  @Put(":id")
  async update(
    @Param("id") id: string,
    @Body() updateUserDto: UpdateUserDto
  ): Promise<User> {
    return this.usersService.update(id, updateUserDto);
  }

  @Delete(":id")
  @HttpCode(204)
  async remove(@Param("id") id: string): Promise<void> {
    return this.usersService.remove(id);
  }
}
```

**Rust (axum equivalent):**
```rust
use axum::{
    extract::{Path, Query, State, Json},
    http::StatusCode,
    middleware,
    routing::{get, post, put, delete},
    Router,
};
use std::sync::Arc;
use uuid::Uuid;

// @Controller("users") -> Router with route prefix
pub fn users_router(state: Arc<AppState>) -> Router<Arc<AppState>> {
    Router::new()
        .route("/", get(find_all).post(create))
        .route("/{id}", get(find_one).put(update).delete(remove))
        // @UseGuards(AuthGuard) -> middleware layer
        .layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ))
        // @UseInterceptors(LoggingInterceptor) -> tower layer
        .layer(tower_http::trace::TraceLayer::new_for_http())
}

// @Get() -> handler function with extractors
// @UseGuards(RolesGuard) + @Roles("admin") -> extractor that checks roles
async fn find_all(
    State(state): State<Arc<AppState>>,
    _admin: RequireRole<Admin>,  // Role guard as extractor
    Query(query): Query<PaginationQuery>,
) -> Result<Json<Vec<User>>, AppError> {
    let users = state.users_service.find_all(&query).await?;
    Ok(Json(users))
}

// @Get(":id") -> path extractor
async fn find_one(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<Json<User>, AppError> {
    let user = state.users_service.find_by_id(id).await?;
    Ok(Json(user))
}

// @Post() + @HttpCode(201) -> return (StatusCode, Json<T>)
async fn create(
    State(state): State<Arc<AppState>>,
    Json(input): Json<CreateUserDto>,
) -> Result<(StatusCode, Json<User>), AppError> {
    input.validate().map_err(AppError::from)?;
    let user = state.users_service.create(input).await?;
    Ok((StatusCode::CREATED, Json(user)))
}

// @Put(":id")
async fn update(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
    Json(input): Json<UpdateUserDto>,
) -> Result<Json<User>, AppError> {
    let user = state.users_service.update(id, input).await?;
    Ok(Json(user))
}

// @Delete(":id") + @HttpCode(204)
async fn remove(
    State(state): State<Arc<AppState>>,
    Path(id): Path<Uuid>,
) -> Result<StatusCode, AppError> {
    state.users_service.remove(id).await?;
    Ok(StatusCode::NO_CONTENT)
}

// Role guard as an extractor (replaces @Roles decorator + RolesGuard)
pub struct RequireRole<R: RoleMarker>(std::marker::PhantomData<R>);

pub trait RoleMarker: Send + Sync + 'static {
    fn required_role() -> &'static str;
}

pub struct Admin;
impl RoleMarker for Admin {
    fn required_role() -> &'static str { "admin" }
}

#[axum::async_trait]
impl<S, R: RoleMarker> axum::extract::FromRequestParts<S> for RequireRole<R>
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut axum::http::request::Parts,
        _state: &S,
    ) -> Result<Self, Self::Rejection> {
        // Extract user from request extensions (set by auth middleware)
        let user = parts.extensions.get::<AuthUser>()
            .ok_or(AppError::Auth(AuthError::NotAuthenticated))?;

        if user.role != R::required_role() {
            return Err(AppError::Auth(AuthError::Forbidden {
                action: "access".into(),
                resource: "endpoint".into(),
            }));
        }

        Ok(RequireRole(std::marker::PhantomData))
    }
}
```

### Example 2: Dependency Injection (inversify/tsyringe) to Manual DI

**TypeScript:**
```typescript
import { injectable, inject } from "inversify";
import { TYPES } from "./types";

@injectable()
class UserService {
  constructor(
    @inject(TYPES.UserRepository) private userRepo: IUserRepository,
    @inject(TYPES.EmailService) private emailService: IEmailService,
    @inject(TYPES.Logger) private logger: ILogger,
  ) {}

  async createUser(data: CreateUserInput): Promise<User> {
    this.logger.info("Creating user", { email: data.email });
    const user = await this.userRepo.create(data);
    await this.emailService.sendWelcome(user.email);
    return user;
  }
}

// Container configuration
const container = new Container();
container.bind<IUserRepository>(TYPES.UserRepository).to(PostgresUserRepository);
container.bind<IEmailService>(TYPES.EmailService).to(SmtpEmailService);
container.bind<ILogger>(TYPES.Logger).to(WinstonLogger);
container.bind<UserService>(TYPES.UserService).to(UserService);

// Resolution
const userService = container.get<UserService>(TYPES.UserService);
```

**Rust:**
```rust
use std::sync::Arc;

// Interfaces -> traits
#[async_trait::async_trait]
pub trait UserRepository: Send + Sync {
    async fn create(&self, data: CreateUserInput) -> Result<User, DbError>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, DbError>;
}

#[async_trait::async_trait]
pub trait EmailService: Send + Sync {
    async fn send_welcome(&self, email: &str) -> Result<(), AppError>;
}

// @injectable class -> struct with trait object dependencies
pub struct UserService {
    user_repo: Arc<dyn UserRepository>,
    email_service: Arc<dyn EmailService>,
    // Logger: use tracing (global), not injected
}

impl UserService {
    // Constructor injection -> new() function
    pub fn new(
        user_repo: Arc<dyn UserRepository>,
        email_service: Arc<dyn EmailService>,
    ) -> Self {
        Self { user_repo, email_service }
    }

    pub async fn create_user(&self, data: CreateUserInput) -> Result<User, AppError> {
        tracing::info!(email = %data.email, "creating user");
        let user = self.user_repo.create(data).await?;
        self.email_service.send_welcome(&user.email).await?;
        Ok(user)
    }
}

// Container configuration -> manual wiring in main.rs
pub struct AppState {
    pub user_service: Arc<UserService>,
    pub order_service: Arc<OrderService>,
    // ... other services
}

impl AppState {
    pub async fn new(config: &AppConfig) -> Result<Self, AppError> {
        // Create concrete implementations
        let pool = sqlx::PgPool::connect(&config.database_url).await?;
        let pool = Arc::new(pool);

        let user_repo: Arc<dyn UserRepository> =
            Arc::new(PostgresUserRepository::new(pool.clone()));
        let email_service: Arc<dyn EmailService> =
            Arc::new(SmtpEmailService::new(&config.smtp_config));

        let user_service = Arc::new(UserService::new(
            user_repo.clone(),
            email_service.clone(),
        ));

        Ok(Self { user_service })
    }
}

// No container needed -- Rust's type system ensures correctness at compile time
```

### Example 3: Express Middleware next() to Tower Layer/Service

**TypeScript:**
```typescript
// Express middleware
function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace("Bearer ", "");
  if (!token) {
    return res.status(401).json({ error: "No token provided" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: "Invalid token" });
  }
}

// Timing middleware
function timingMiddleware(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  res.on("finish", () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} - ${duration}ms`);
  });
  next();
}

// Error handling middleware
function errorMiddleware(err: Error, req: Request, res: Response, next: NextFunction) {
  console.error(err.stack);
  res.status(500).json({ error: "Internal Server Error" });
}

app.use(timingMiddleware);
app.use(authMiddleware);
app.use(errorMiddleware);
```

**Rust:**
```rust
use axum::{
    extract::Request,
    http::{header, StatusCode},
    middleware::Next,
    response::Response,
};
use std::time::Instant;

// Express middleware -> axum middleware function
// `next` parameter replaces `next()` callback
async fn auth_middleware(
    State(state): State<Arc<AppState>>,
    mut request: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(AppError::Auth(AuthError::NotAuthenticated))?;

    let claims = jsonwebtoken::decode::<Claims>(
        token,
        &DecodingKey::from_secret(state.config.jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| AppError::Auth(AuthError::InvalidToken))?
    .claims;

    // req.user = decoded -> insert into request extensions
    request.extensions_mut().insert(AuthUser {
        id: claims.sub.parse()?,
        role: claims.role,
    });

    // next() -> next.run(request).await
    Ok(next.run(request).await)
}

// Timing middleware
async fn timing_middleware(request: Request, next: Next) -> Response {
    let method = request.method().clone();
    let path = request.uri().path().to_string();
    let start = Instant::now();

    let response = next.run(request).await;

    let duration = start.elapsed();
    tracing::info!(
        method = %method,
        path = %path,
        duration_ms = duration.as_millis(),
        status = response.status().as_u16(),
        "request completed"
    );

    response
}

// Error handling -> IntoResponse impl on AppError (see error strategy guide 11)
// No separate error middleware needed; errors are handled via Result types

// Middleware registration
let app = Router::new()
    .route("/api/users", get(list_users))
    .layer(axum::middleware::from_fn(timing_middleware))
    .layer(axum::middleware::from_fn_with_state(
        state.clone(),
        auth_middleware,
    ));
```

### Example 4: Barrel Exports (index.ts) to mod.rs Re-exports

**TypeScript:**
```typescript
// src/models/index.ts (barrel export)
export { User } from "./user";
export { Order } from "./order";
export { Product } from "./product";
export { Category, type CategoryType } from "./category";
export * from "./common";

// src/services/index.ts
export { UserService } from "./user.service";
export { OrderService } from "./order.service";
export { default as AnalyticsService } from "./analytics.service";

// Consumer: clean imports from barrel
import { User, Order, UserService, OrderService } from "../models";
```

**Rust:**
```rust
// src/models/mod.rs (equivalent of index.ts barrel export)
mod user;
mod order;
mod product;
mod category;
mod common;

pub use user::User;
pub use order::Order;
pub use product::Product;
pub use category::{Category, CategoryType};
pub use common::*;

// src/services/mod.rs
mod user_service;
mod order_service;
mod analytics_service;

pub use user_service::UserService;
pub use order_service::OrderService;
pub use analytics_service::AnalyticsService;

// Consumer: clean imports via module path
use crate::models::{User, Order};
use crate::services::{UserService, OrderService};
```

### Example 5: Type Guards to Pattern Matching

**TypeScript:**
```typescript
// Type guard function
function isError(value: unknown): value is Error {
  return value instanceof Error;
}

// Discriminated union type guard
interface SuccessResult {
  type: "success";
  data: any;
}

interface ErrorResult {
  type: "error";
  error: string;
  code: number;
}

type Result = SuccessResult | ErrorResult;

function isSuccess(result: Result): result is SuccessResult {
  return result.type === "success";
}

// User-defined type guard with refinement
interface Admin {
  role: "admin";
  permissions: string[];
  adminLevel: number;
}

interface RegularUser {
  role: "user";
  preferences: UserPreferences;
}

type AnyUser = Admin | RegularUser;

function isAdmin(user: AnyUser): user is Admin {
  return user.role === "admin";
}

// Usage with narrowing
function handleUser(user: AnyUser) {
  if (isAdmin(user)) {
    console.log(user.adminLevel); // TypeScript knows this is Admin
  } else {
    console.log(user.preferences); // TypeScript knows this is RegularUser
  }
}
```

**Rust:**
```rust
// Type guard -> pattern matching on enum variants
// No separate guard function needed -- match does it directly

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum ApiResult<T: Serialize> {
    Success { data: T },
    Error { error: String, code: i32 },
}

impl<T: Serialize> ApiResult<T> {
    // Optional convenience methods (replace type guard functions)
    pub fn is_success(&self) -> bool {
        matches!(self, ApiResult::Success { .. })
    }

    pub fn into_data(self) -> Option<T> {
        match self {
            ApiResult::Success { data } => Some(data),
            ApiResult::Error { .. } => None,
        }
    }
}

// Discriminated union -> enum with variants
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "role", rename_all = "lowercase")]
pub enum AnyUser {
    Admin {
        permissions: Vec<String>,
        admin_level: u32,
    },
    User {
        preferences: UserPreferences,
    },
}

// isAdmin type guard -> match
fn handle_user(user: &AnyUser) {
    match user {
        AnyUser::Admin { admin_level, .. } => {
            println!("Admin level: {admin_level}");
        }
        AnyUser::User { preferences, .. } => {
            println!("Preferences: {preferences:?}");
        }
    }
}

// If you need a boolean check (rare, prefer match):
impl AnyUser {
    pub fn is_admin(&self) -> bool {
        matches!(self, AnyUser::Admin { .. })
    }
}
```

### Example 6: Branded/Opaque Types to Newtypes

**TypeScript:**
```typescript
// Branded types for type safety
type UserId = string & { readonly __brand: "UserId" };
type OrderId = string & { readonly __brand: "OrderId" };
type Email = string & { readonly __brand: "Email" };

function createUserId(id: string): UserId {
  return id as UserId;
}

function createEmail(email: string): Email {
  if (!email.includes("@")) {
    throw new Error("Invalid email");
  }
  return email as Email;
}

// Prevents mixing up IDs
function getUser(id: UserId): Promise<User> { ... }
function getOrder(id: OrderId): Promise<Order> { ... }

// Compile error: cannot pass OrderId where UserId is expected
// getUser(orderId);
```

**Rust:**
```rust
use serde::{Deserialize, Serialize};
use std::fmt;
use uuid::Uuid;

// Branded type -> newtype struct (zero-cost abstraction)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UserId(Uuid);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct OrderId(Uuid);

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Email(String);

impl UserId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    pub fn from_uuid(id: Uuid) -> Self {
        Self(id)
    }

    pub fn as_uuid(&self) -> &Uuid {
        &self.0
    }
}

impl fmt::Display for UserId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl Email {
    pub fn new(email: impl Into<String>) -> Result<Self, ValidationError> {
        let email = email.into();
        if !email.contains('@') {
            return Err(ValidationError::Format {
                field: "email".into(),
                message: "must contain @".into(),
            });
        }
        Ok(Self(email))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for Email {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

// Compile error: cannot pass OrderId where UserId is expected
async fn get_user(id: UserId) -> Result<User, AppError> { todo!() }
async fn get_order(id: OrderId) -> Result<Order, AppError> { todo!() }
```

### Example 7: Module-Level Side Effects to Lazy Initialization

**TypeScript:**
```typescript
// Side-effect import: registers something globally
import "reflect-metadata"; // Polyfill for decorators
import "./config/instrument"; // OpenTelemetry setup

// Module-level initialization
const logger = createLogger({ level: "info" });
const db = new DatabasePool(process.env.DATABASE_URL!);

// Global augmentation
declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

// Module with side effects on import
// metrics.ts
import { Counter, Histogram } from "prom-client";

export const httpRequestCount = new Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "path", "status"],
});

export const httpRequestDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration",
  labelNames: ["method", "path"],
});
```

**Rust:**
```rust
// Side-effect imports -> explicit initialization in main()
// No "import for side effect" in Rust; everything must be called explicitly

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // "import reflect-metadata" -> not needed (no decorator runtime)

    // "import ./config/instrument" -> explicit call
    init_tracing();

    // Module-level initialization -> explicit construction
    let config = AppConfig::from_env()?;
    let pool = sqlx::PgPool::connect(&config.database_url).await?;

    let state = Arc::new(AppState::new(config, pool).await?);

    let app = create_router(state);
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app).await?;

    Ok(())
}

fn init_tracing() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer().json())
        .init();
}

// Global augmentation -> not needed; use request extensions
// No "declare global" in Rust; type-safe via Extensions

// Metrics: use LazyLock for global metrics (initialized once)
use metrics::{counter, histogram};
use std::sync::LazyLock;

// Option A: Use the `metrics` crate facade (preferred)
fn record_http_request(method: &str, path: &str, status: u16, duration_secs: f64) {
    counter!("http_requests_total",
        "method" => method.to_string(),
        "path" => path.to_string(),
        "status" => status.to_string()
    )
    .increment(1);

    histogram!("http_request_duration_seconds",
        "method" => method.to_string(),
        "path" => path.to_string()
    )
    .record(duration_secs);
}

// Option B: LazyLock for pre-created metric handles
use metrics_exporter_prometheus::PrometheusBuilder;

fn init_metrics() {
    PrometheusBuilder::new()
        .install()
        .expect("failed to install prometheus exporter");
}
```

### Example 8: Assertion Functions to assert!/panic!/Result

**TypeScript:**
```typescript
// Assertion function (narrows types and throws on failure)
function assertDefined<T>(value: T | undefined, message?: string): asserts value is T {
  if (value === undefined) {
    throw new Error(message ?? "Value is undefined");
  }
}

function assertNonNull<T>(value: T | null, message?: string): asserts value is NonNullable<T> {
  if (value === null || value === undefined) {
    throw new Error(message ?? "Value is null or undefined");
  }
}

// Assertion with type narrowing
function assertIsString(value: unknown): asserts value is string {
  if (typeof value !== "string") {
    throw new TypeError(`Expected string, got ${typeof value}`);
  }
}

// Usage
function processConfig(config: Partial<Config>) {
  assertDefined(config.host, "host is required");
  assertDefined(config.port, "port is required");
  // After assertions, TypeScript knows host and port are defined
  connect(config.host, config.port);
}
```

**Rust:**
```rust
// Assertion functions are not needed in Rust because:
// 1. Option<T> forces handling at compile time
// 2. Pattern matching / ? operator narrows types

// If the value being absent is a programming error -> unwrap/expect/assert
fn process_config(config: PartialConfig) -> Result<(), AppError> {
    // Option A: Convert to Result with ? (preferred for user input)
    let host = config.host.ok_or_else(|| {
        AppError::Validation(ValidationError::MissingField("host".into()))
    })?;
    let port = config.port.ok_or_else(|| {
        AppError::Validation(ValidationError::MissingField("port".into()))
    })?;

    connect(&host, port)?;
    Ok(())
}

// Option B: Assert for invariants that should never fail (programming errors)
fn process_internal_config(config: &InternalConfig) {
    // These should always be set by the time we get here
    assert!(config.host.is_some(), "host must be configured before processing");
    assert!(config.port.is_some(), "port must be configured before processing");

    let host = config.host.as_ref().unwrap();
    let port = config.port.unwrap();
    // ...
}

// Generic assertion helper (if you need the pattern frequently)
pub trait AssertSome<T> {
    fn assert_some(self, field_name: &str) -> Result<T, AppError>;
}

impl<T> AssertSome<T> for Option<T> {
    fn assert_some(self, field_name: &str) -> Result<T, AppError> {
        self.ok_or_else(|| AppError::Validation(
            ValidationError::MissingField(field_name.into())
        ))
    }
}

// Usage:
// let host = config.host.assert_some("host")?;
// let port = config.port.assert_some("port")?;
```

### Example 9: TypeScript Namespaces to Rust Modules

**TypeScript:**
```typescript
namespace Validators {
  export interface StringValidator {
    isValid(s: string): boolean;
  }

  export class EmailValidator implements StringValidator {
    isValid(s: string): boolean {
      return /^[^@]+@[^@]+\.[^@]+$/.test(s);
    }
  }

  export class ZipCodeValidator implements StringValidator {
    isValid(s: string): boolean {
      return /^\d{5}(-\d{4})?$/.test(s);
    }
  }

  export function validateAll(
    value: string,
    validators: StringValidator[]
  ): boolean {
    return validators.every(v => v.isValid(value));
  }
}

// Usage
const emailValidator = new Validators.EmailValidator();
```

**Rust:**
```rust
// TypeScript namespace -> Rust module
pub mod validators {
    use regex::Regex;
    use std::sync::LazyLock;

    pub trait StringValidator: Send + Sync {
        fn is_valid(&self, s: &str) -> bool;
    }

    pub struct EmailValidator;

    static EMAIL_RE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^[^@]+@[^@]+\.[^@]+$").unwrap()
    });

    impl StringValidator for EmailValidator {
        fn is_valid(&self, s: &str) -> bool {
            EMAIL_RE.is_match(s)
        }
    }

    pub struct ZipCodeValidator;

    static ZIP_RE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^\d{5}(-\d{4})?$").unwrap()
    });

    impl StringValidator for ZipCodeValidator {
        fn is_valid(&self, s: &str) -> bool {
            ZIP_RE.is_match(s)
        }
    }

    pub fn validate_all(value: &str, validators: &[&dyn StringValidator]) -> bool {
        validators.iter().all(|v| v.is_valid(value))
    }
}

// Usage:
// use validators::{EmailValidator, StringValidator};
// let validator = EmailValidator;
// assert!(validator.is_valid("test@example.com"));
```

### Example 10: as const and satisfies to const/static

**TypeScript:**
```typescript
// as const: create a readonly, narrowed literal type
const HTTP_METHODS = ["GET", "POST", "PUT", "DELETE", "PATCH"] as const;
type HttpMethod = (typeof HTTP_METHODS)[number];

const STATUS_CODES = {
  OK: 200,
  CREATED: 201,
  NOT_FOUND: 404,
  INTERNAL_ERROR: 500,
} as const;

// satisfies: check type without widening
const routes = {
  users: "/api/users",
  orders: "/api/orders",
  products: "/api/products",
} satisfies Record<string, string>;

type RouteName = keyof typeof routes;
```

**Rust:**
```rust
// as const array -> const array or enum
pub const HTTP_METHODS: &[&str] = &["GET", "POST", "PUT", "DELETE", "PATCH"];

// Better: use an enum for type safety
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HttpMethod {
    Get,
    Post,
    Put,
    Delete,
    Patch,
}

// as const object -> const or module with constants
pub mod status_codes {
    pub const OK: u16 = 200;
    pub const CREATED: u16 = 201;
    pub const NOT_FOUND: u16 = 404;
    pub const INTERNAL_ERROR: u16 = 500;
}

// satisfies -> type annotation (Rust always requires explicit types)
use std::collections::HashMap;
use std::sync::LazyLock;

pub static ROUTES: LazyLock<HashMap<&'static str, &'static str>> = LazyLock::new(|| {
    let mut m = HashMap::new();
    m.insert("users", "/api/users");
    m.insert("orders", "/api/orders");
    m.insert("products", "/api/products");
    m
});

// Or use a strongly-typed struct (preferred):
pub struct Routes {
    pub users: &'static str,
    pub orders: &'static str,
    pub products: &'static str,
}

pub const ROUTES_TYPED: Routes = Routes {
    users: "/api/users",
    orders: "/api/orders",
    products: "/api/products",
};
```

## Template

```markdown
# TypeScript Pattern Mapping

Source: {project_name}
Generated: {date}

## Summary

| Pattern Category | Count | Rust Strategy | Complexity |
|-----------------|-------|---------------|-----------|
| Decorators (class/method) | {count} | Trait impls + axum extractors | Medium |
| DI container usage | {count} | Manual Arc<dyn Trait> wiring | Low |
| Middleware chains | {count} | Tower Layer/middleware | Medium |
| Barrel exports | {count} | mod.rs pub use re-exports | Low |
| Type guards | {count} | match on enum variants | Low |
| Assertion functions | {count} | .ok_or() / assert! | Low |
| Branded types | {count} | Newtype structs | Low |
| Module side effects | {count} | Explicit init in main() | Low |
| Namespace usage | {count} | Rust modules | Low |
| as const / satisfies | {count} | const / static / structs | Low |

## Pattern Conversion Table

| # | Source Pattern | File | Category | Rust Equivalent | Notes |
|---|--------------|------|----------|-----------------|-------|
| 1 | `@Controller("users")` | [{file}:{line}] | Decorator | `Router::new().route()` | Route prefix |
| 2 | `@inject(TYPES.Repo)` | [{file}:{line}] | DI | `Arc<dyn Repo>` param | Manual wiring |
| 3 | `function isAdmin(u): u is Admin` | [{file}:{line}] | Type guard | `matches!(u, User::Admin { .. })` | Enum match |
| 4 | `export * from "./models"` | [{file}:{line}] | Barrel | `pub use models::*;` | mod.rs |
| ... | ... | ... | ... | ... | ... |

## Decorator Migration Map

| Decorator | Framework | Rust Equivalent | Location |
|-----------|-----------|-----------------|----------|
| `@Controller(path)` | NestJS | `Router::new().nest(path, ...)` | Router setup |
| `@Get/@Post/...` | NestJS | `routing::get/post` | Route handler |
| `@Injectable` | NestJS/inversify | No equivalent (struct is always injectable) | Remove |
| `@UseGuards(Guard)` | NestJS | `middleware::from_fn()` | Layer |
| `@Body()` | NestJS | `Json<T>` extractor | Handler param |
| `@Param(name)` | NestJS | `Path<T>` extractor | Handler param |
| `@Query()` | NestJS | `Query<T>` extractor | Handler param |
| ... | ... | ... | ... |

## DI Wiring Plan

```text
main.rs
  |-- Create PgPool
  |-- Create Arc<dyn UserRepository> = Arc::new(PostgresUserRepository::new(pool))
  |-- Create Arc<dyn EmailService> = Arc::new(SmtpEmailService::new(config))
  |-- Create UserService::new(user_repo, email_service)
  |-- Create AppState { user_service, ... }
  |-- Pass AppState to Router via .with_state()
```

## Module Structure Mapping

| TypeScript Path | Purpose | Rust Path |
|----------------|---------|-----------|
| `src/models/index.ts` | Barrel export | `src/models/mod.rs` |
| `src/services/index.ts` | Barrel export | `src/services/mod.rs` |
| `src/utils/index.ts` | Barrel export | `src/utils/mod.rs` |
| `src/types/index.ts` | Type definitions | `src/types/mod.rs` or `src/models/` |
| ... | ... | ... |

## Crate Dependencies

```toml
[dependencies]
axum = "0.8"
tower = "0.5"
tower-http = { version = "0.6", features = ["cors", "trace"] }
strum = { version = "0.26", features = ["derive"] }
regex = "1"
metrics = "0.24"
metrics-exporter-prometheus = "0.16"
```
```

## Completeness Check

- [ ] Every decorator usage is mapped to a Rust equivalent (trait impl, middleware, or extractor)
- [ ] Every DI container registration has manual wiring in `main.rs` or `AppState`
- [ ] Every middleware chain is converted to Tower layers
- [ ] Every barrel export (`index.ts`) has a corresponding `mod.rs` with `pub use`
- [ ] Every type guard function is replaced with `match` or `matches!` macro
- [ ] Every assertion function is replaced with `.ok_or()` or `assert!`
- [ ] Every branded/opaque type has a newtype struct
- [ ] Every module side-effect import has explicit initialization in `main()`
- [ ] Every TypeScript namespace is converted to a Rust module
- [ ] Every `as const` declaration has a `const` or `enum` equivalent
- [ ] Every string enum uses `strum` or `serde` for serialization
- [ ] The DI wiring plan shows the complete dependency graph
- [ ] Module structure mapping covers all source directories
