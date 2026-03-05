# 14 - Testing Patterns Mapping

**Output**: `.migration-plan/mappings/testing-strategy.md`

## Purpose

Map the source project's test framework, test structure, mocking patterns, fixtures, and CI pipeline to Rust's built-in test system and testing ecosystem. Every test file, test utility, mock, and fixture in the source must have a concrete Rust migration strategy.

## Method

### Step 1: Read Phase 1 analysis

Read these files from `.migration-plan/analysis/`:
- `testing-build.md` -- test framework, test file inventory, coverage tools, CI configuration
- `architecture.md` -- module structure (determines test module placement)
- `type-catalog.md` -- types that need test fixtures/builders

Extract every instance of:
- Test framework configuration (jest.config, pytest.ini, go test flags)
- Test file naming conventions and locations
- Test utility functions and helpers
- Fixtures and test data factories
- Mocking/stubbing patterns
- Integration test setup (database, HTTP, external services)
- E2E/acceptance tests
- Coverage configuration
- CI pipeline test steps

### Step 2: Map test framework concepts

**Framework mapping:**

| Source Concept | Rust Equivalent |
|---------------|-----------------|
| `describe("group", () => { ... })` (Jest) | `mod tests { ... }` or `mod group { ... }` |
| `it("should do X", () => { ... })` (Jest) | `#[test] fn should_do_x() { ... }` |
| `test("name", () => { ... })` (Jest) | `#[test] fn name() { ... }` |
| `def test_name(self):` (pytest) | `#[test] fn test_name() { ... }` |
| `func TestName(t *testing.T)` (Go) | `#[test] fn test_name() { ... }` |
| `beforeEach` / `setUp` | Helper function called at start of each test |
| `afterEach` / `tearDown` | `Drop` impl or explicit cleanup |
| `beforeAll` / `setUpClass` | `#[ctor]` or `LazyLock` in test module |
| `expect(x).toBe(y)` | `assert_eq!(x, y)` |
| `expect(x).toThrow()` | `#[should_panic]` or `assert!(result.is_err())` |
| `test.skip` | `#[ignore]` |
| `test.only` | `cargo test test_name` (run specific test) |
| `jest.mock("module")` | `mockall` crate or manual mock struct |
| `@pytest.fixture` | Helper function or `TestContext` struct |
| `t.Helper()` (Go) | Regular helper function (Rust shows full backtrace) |
| `t.Parallel()` (Go) | Default (Rust tests run in parallel by default) |
| `t.Run("sub", func())` (Go) | Nested `mod` or parameterized test |

### Step 3: Map test structure

**Rust test organization:**

```
src/
  lib.rs          # Unit tests inline: mod tests { ... }
  models/
    user.rs       # Unit tests inline at bottom of file
    order.rs      # Unit tests inline at bottom of file
  services/
    user_service.rs  # Unit tests inline

tests/              # Integration tests (separate binary crates)
  api_tests.rs      # HTTP endpoint integration tests
  db_tests.rs       # Database integration tests
  common/
    mod.rs          # Shared test utilities

benches/            # Benchmarks
  performance.rs
```

**Unit test module pattern:**

```rust
// src/services/user_service.rs

pub struct UserService { /* ... */ }

impl UserService {
    pub fn validate_email(email: &str) -> Result<(), ValidationError> {
        if !email.contains('@') {
            return Err(ValidationError::Format {
                field: "email".into(),
                message: "must contain @".into(),
            });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validate_email_accepts_valid_email() {
        let result = UserService::validate_email("user@example.com");
        assert!(result.is_ok());
    }

    #[test]
    fn validate_email_rejects_missing_at_sign() {
        let result = UserService::validate_email("invalid-email");
        assert!(matches!(
            result,
            Err(ValidationError::Format { field, .. }) if field == "email"
        ));
    }

    #[test]
    #[should_panic(expected = "assertion failed")]
    fn panics_on_invalid_invariant() {
        // Test that internal invariants panic appropriately
        UserService::dangerous_operation(invalid_input);
    }

    #[test]
    #[ignore] // Slow test, run with: cargo test -- --ignored
    fn slow_integration_test() {
        // ...
    }
}
```

### Step 4: Map assertion patterns

| Source Assertion | Rust Assertion |
|-----------------|----------------|
| `expect(a).toBe(b)` / `assertEqual(a, b)` | `assert_eq!(a, b)` |
| `expect(a).not.toBe(b)` / `assertNotEqual` | `assert_ne!(a, b)` |
| `expect(a).toBeTruthy()` / `assertTrue` | `assert!(a)` |
| `expect(a).toBeFalsy()` / `assertFalse` | `assert!(!a)` |
| `expect(a).toContain(b)` / `assertIn` | `assert!(a.contains(b))` |
| `expect(a).toHaveLength(n)` | `assert_eq!(a.len(), n)` |
| `expect(a).toBeGreaterThan(b)` | `assert!(a > b)` |
| `expect(a).toMatchObject({...})` | `assert_eq!(a.field, expected)` per field |
| `expect(a).toThrow(ErrorType)` | `assert!(matches!(result, Err(ErrorType::..)))` |
| `expect(a).toBeNull()` | `assert!(a.is_none())` |
| `expect(a).toBeDefined()` | `assert!(a.is_some())` |
| `expect(a).toEqual([...])` (deep equal) | `assert_eq!(a, vec![...])` (requires `PartialEq`) |
| `expect(fn).toHaveBeenCalledWith(...)` | `mock.checkpoint()` (mockall) |
| `assert.deepStrictEqual(a, b)` | `assert_eq!(a, b)` with `#[derive(PartialEq)]` |
| `t.Errorf("msg")` (Go) | `assert!(false, "msg")` or return `Result` |

**Enhanced assertions with `pretty_assertions`:**

```rust
// In Cargo.toml:
// [dev-dependencies]
// pretty_assertions = "1"

#[cfg(test)]
mod tests {
    use pretty_assertions::assert_eq;

    #[test]
    fn complex_struct_equality() {
        let expected = User { name: "Alice".into(), age: 30 };
        let actual = build_user("Alice", 30);
        assert_eq!(expected, actual); // Colored diff on failure
    }
}
```

### Step 5: Map mocking patterns

**Decision tree for mocking:**

```
Does the dependency have a trait?
  YES -> Use mockall to auto-generate mock
  NO  ->
    Can you introduce a trait?
      YES -> Extract trait, use mockall
      NO  ->
        Is it a function?
          YES -> Accept generic Fn parameter, pass closure in test
        Is it an external HTTP service?
          YES -> Use wiremock for HTTP mocking
        Is it a database?
          YES -> Use test database with transactions (rollback after test)
```

**mockall example:**

```rust
use mockall::{automock, predicate::*};

#[automock]
#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, DbError>;
    async fn create(&self, input: CreateUser) -> Result<User, DbError>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate;

    #[tokio::test]
    async fn get_user_returns_user_when_found() {
        let mut mock_repo = MockUserRepository::new();
        let user_id = Uuid::new_v4();
        let expected_user = User {
            id: user_id,
            name: "Alice".into(),
            email: "alice@example.com".into(),
        };

        mock_repo
            .expect_find_by_id()
            .with(predicate::eq(user_id))
            .times(1)
            .returning(move |_| Ok(Some(expected_user.clone())));

        let service = UserService::new(Arc::new(mock_repo));
        let result = service.get_user(user_id).await.unwrap();

        assert_eq!(result.name, "Alice");
    }

    #[tokio::test]
    async fn get_user_returns_not_found_error() {
        let mut mock_repo = MockUserRepository::new();

        mock_repo
            .expect_find_by_id()
            .returning(|_| Ok(None));

        let service = UserService::new(Arc::new(mock_repo));
        let result = service.get_user(Uuid::new_v4()).await;

        assert!(matches!(result, Err(AppError::NotFound { .. })));
    }
}
```

**wiremock for HTTP service mocking:**

```rust
use wiremock::{MockServer, Mock, ResponseTemplate};
use wiremock::matchers::{method, path, body_json};

#[tokio::test]
async fn calls_external_api_correctly() {
    let mock_server = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path("/api/notify"))
        .and(body_json(serde_json::json!({
            "user_id": "123",
            "message": "hello"
        })))
        .respond_with(ResponseTemplate::new(200).set_body_json(
            serde_json::json!({ "status": "sent" })
        ))
        .mount(&mock_server)
        .await;

    let client = NotificationClient::new(&mock_server.uri());
    let result = client.send_notification("123", "hello").await;

    assert!(result.is_ok());
}
```

### Step 6: Map test fixtures and builders

**Test data builder pattern (replaces factories/fixtures):**

```rust
#[cfg(test)]
mod test_helpers {
    use super::*;

    /// Builder for creating test User instances with sensible defaults
    pub struct UserBuilder {
        id: Uuid,
        name: String,
        email: String,
        role: Role,
    }

    impl Default for UserBuilder {
        fn default() -> Self {
            Self {
                id: Uuid::new_v4(),
                name: "Test User".into(),
                email: "test@example.com".into(),
                role: Role::Member,
            }
        }
    }

    impl UserBuilder {
        pub fn new() -> Self {
            Self::default()
        }

        pub fn name(mut self, name: impl Into<String>) -> Self {
            self.name = name.into();
            self
        }

        pub fn email(mut self, email: impl Into<String>) -> Self {
            self.email = email.into();
            self
        }

        pub fn admin(mut self) -> Self {
            self.role = Role::Admin;
            self
        }

        pub fn build(self) -> User {
            User {
                id: self.id,
                name: self.name,
                email: self.email,
                role: self.role,
            }
        }
    }

    // Usage in tests:
    // let user = UserBuilder::new().name("Alice").admin().build();
}
```

### Step 7: Map integration test patterns

**Integration test structure:**

```rust
// tests/api_tests.rs
// This is a separate binary crate -- can only access pub API

use my_app::{create_app, AppConfig};
use axum::http::StatusCode;
use axum_test::TestServer;
use sqlx::PgPool;

/// Shared test context with database and HTTP client
struct TestContext {
    server: TestServer,
    db: PgPool,
}

impl TestContext {
    async fn new() -> Self {
        let config = AppConfig::test_config();
        let db = PgPool::connect(&config.database_url)
            .await
            .expect("failed to connect to test database");

        sqlx::migrate!().run(&db).await.expect("migration failed");

        let app = create_app(config, db.clone());
        let server = TestServer::new(app).expect("failed to start test server");

        Self { server, db }
    }

    /// Clean up test data after each test
    async fn cleanup(&self) {
        sqlx::query("TRUNCATE users, orders CASCADE")
            .execute(&self.db)
            .await
            .expect("cleanup failed");
    }
}

#[tokio::test]
async fn create_user_returns_201() {
    let ctx = TestContext::new().await;

    let response = ctx.server
        .post("/api/users")
        .json(&serde_json::json!({
            "name": "Alice",
            "email": "alice@example.com"
        }))
        .await;

    assert_eq!(response.status_code(), StatusCode::CREATED);

    let body: serde_json::Value = response.json();
    assert_eq!(body["name"], "Alice");
    assert!(body["id"].is_string());

    ctx.cleanup().await;
}

#[tokio::test]
async fn get_nonexistent_user_returns_404() {
    let ctx = TestContext::new().await;

    let response = ctx.server
        .get(&format!("/api/users/{}", Uuid::new_v4()))
        .await;

    assert_eq!(response.status_code(), StatusCode::NOT_FOUND);

    ctx.cleanup().await;
}
```

### Step 8: Map async test patterns

```rust
// Async tests need tokio runtime
#[tokio::test]
async fn async_operation_works() {
    let result = fetch_data().await;
    assert!(result.is_ok());
}

// Test with timeout
#[tokio::test]
#[should_panic] // or use tokio::time::timeout inside the test
async fn slow_operation_has_timeout() {
    tokio::time::timeout(
        std::time::Duration::from_secs(5),
        slow_operation(),
    )
    .await
    .expect("operation timed out");
}

// Test with multiple async tasks
#[tokio::test]
async fn concurrent_operations_dont_conflict() {
    let (result_a, result_b) = tokio::join!(
        operation_a(),
        operation_b(),
    );
    assert!(result_a.is_ok());
    assert!(result_b.is_ok());
}
```

## Template

```markdown
# Testing Strategy

Source: {project_name}
Generated: {date}

## Test Framework Migration

| Aspect | Source | Rust |
|--------|-------|------|
| Framework | {jest/pytest/go test} | Built-in `#[test]` + `#[tokio::test]` |
| Runner | {jest/pytest/go test} | `cargo test` |
| Assertions | {expect/assert/t.Error} | `assert!`, `assert_eq!`, `assert_ne!` |
| Mocking | {jest.mock/unittest.mock/testify} | `mockall` |
| HTTP Mocking | {nock/responses/httptest} | `wiremock` |
| Coverage | {istanbul/coverage.py/go cover} | `cargo tarpaulin` or `cargo llvm-cov` |
| Parallel | {default/explicit} | Default parallel (use `--test-threads=1` for serial) |

## Test File Migration Map

| Source Test File | Rust Destination | Type |
|-----------------|------------------|------|
| `src/__tests__/user.test.ts` | `src/services/user_service.rs` (inline `mod tests`) | Unit |
| `src/__tests__/api.test.ts` | `tests/api_tests.rs` | Integration |
| `tests/e2e/flow.test.ts` | `tests/e2e_tests.rs` | E2E |

## Mocking Strategy

| Dependency | Current Mock | Rust Mock | Crate |
|-----------|-------------|-----------|-------|
| UserRepository | {jest.mock/Mock} | `MockUserRepository` (mockall) | `mockall` |
| HTTP Client | {nock/responses} | `MockServer` (wiremock) | `wiremock` |
| Database | {in-memory/mock} | Test PgPool with transactions | `sqlx` |
| Time | {jest.fakeTimers/freezegun} | `tokio::time::pause()` | `tokio` (test-util) |
| Filesystem | {mock-fs/pyfakefs} | `tempfile` crate | `tempfile` |

## Test Data Strategy

| Source Pattern | Rust Pattern |
|---------------|-------------|
| Factory functions | Builder pattern (see `UserBuilder` above) |
| JSON fixtures | `include_str!("fixtures/user.json")` + `serde_json::from_str` |
| Database seeds | SQL migration files in `tests/fixtures/` |
| Random data | `fake` crate |

## CI Pipeline

```yaml
# Example GitHub Actions
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@stable
    - uses: Swatinem/rust-cache@v2
    - run: cargo test --all-features
    - run: cargo clippy -- -D warnings
    - run: cargo fmt --check
```

## Crate Dependencies (dev)

```toml
[dev-dependencies]
tokio = { version = "1", features = ["test-util", "macros", "rt-multi-thread"] }
mockall = "0.13"
wiremock = "0.6"
pretty_assertions = "1"
tempfile = "3"
fake = { version = "3", features = ["derive"] }
axum-test = "16"  # If testing axum handlers
```
```

## Completeness Check

- [ ] Every test file in the source has a Rust destination (inline mod or tests/ directory)
- [ ] Test framework mapping table is complete
- [ ] Every assertion pattern used in the source has a Rust equivalent
- [ ] Every mock/stub has a Rust mocking strategy (mockall, wiremock, or manual)
- [ ] Test fixtures/factories are mapped to builder pattern or fixture files
- [ ] Integration test setup (database, HTTP) has a concrete Rust strategy
- [ ] Async test patterns use `#[tokio::test]`
- [ ] CI pipeline configuration is provided
- [ ] Dev-dependencies are listed with versions
- [ ] Coverage tool is recommended
- [ ] Test naming conventions are documented
- [ ] beforeEach/afterEach patterns are mapped to setup/cleanup functions
