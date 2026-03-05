# 06 - Test Structure and Build System Analysis

**Output**: `.migration-plan/analysis/testing-build.md`

## Purpose

Catalog every test file, test framework, build command, and CI/CD pipeline configuration. This analysis ensures the Rust migration preserves test coverage and replicates the build/deploy infrastructure:

- Every test case represents a behavior that must be verified in the Rust version
- Test frameworks inform which Rust testing patterns to use (unit, integration, property-based, e2e)
- Build commands must be mapped to Cargo equivalents
- CI/CD pipelines must be updated for Rust compilation, testing, and deployment
- Code coverage thresholds and quality gates must be maintained

## Method

### Step 1: Find all test files

Use Glob to locate every test file in the project.

**TypeScript/JavaScript**:
```
Glob: **/*.test.ts, **/*.test.tsx, **/*.test.js, **/*.test.jsx
Glob: **/*.spec.ts, **/*.spec.tsx, **/*.spec.js, **/*.spec.jsx
Glob: **/__tests__/**/*.ts, **/__tests__/**/*.tsx
Glob: **/__tests__/**/*.js, **/__tests__/**/*.jsx
Glob: **/test/**/*.ts, **/test/**/*.js
Glob: **/tests/**/*.ts, **/tests/**/*.js
Glob: **/*.e2e-spec.ts, **/*.integration.ts
Glob: **/cypress/**/*.cy.ts, **/playwright/**/*.ts
```

**Python**:
```
Glob: **/test_*.py, **/*_test.py
Glob: **/tests/**/*.py, **/test/**/*.py
Glob: **/conftest.py
Glob: **/factories.py, **/fixtures.py
```

**Go**:
```
Glob: **/*_test.go
Glob: **/testdata/**
Glob: **/*_integration_test.go, **/*_e2e_test.go
```

### Step 2: Identify test frameworks and tools

Grep for test framework imports and configuration.

**TypeScript/JavaScript**:
```
Grep: import.*from\s+['"]jest['"]|describe\(|it\(|test\(|expect\(     (Jest)
Grep: import.*from\s+['"]vitest['"]|import.*vi\s+from                  (Vitest)
Grep: import.*from\s+['"]mocha['"]|import.*chai                        (Mocha + Chai)
Grep: import.*from\s+['"]@testing-library                              (Testing Library)
Grep: import.*from\s+['"]supertest['"]                                 (Supertest / HTTP testing)
Grep: import.*from\s+['"]nock['"]|import.*from\s+['"]msw['"]          (HTTP mocking)
Grep: import.*from\s+['"]sinon['"]                                     (Sinon mocking)
Grep: import.*from\s+['"]cypress['"]                                   (Cypress e2e)
Grep: import.*from\s+['"]@playwright                                   (Playwright e2e)
Grep: import.*from\s+['"]fast-check['"]                                (Property-based testing)
```

Read config files:
```
Glob: jest.config.*, vitest.config.*, .mocharc.*, cypress.config.*
Glob: playwright.config.*
```

**Python**:
```
Grep: import\s+pytest|from\s+pytest                                     (pytest)
Grep: import\s+unittest|from\s+unittest                                 (unittest)
Grep: from\s+hypothesis                                                 (property-based)
Grep: from\s+factory_boy|import\s+factory                              (test factories)
Grep: from\s+faker|import\s+faker                                      (fake data)
Grep: from\s+unittest\.mock|from\s+mock|@patch|@mock                   (mocking)
Grep: from\s+responses|import\s+responses|@responses\.activate         (HTTP mocking)
Grep: from\s+httpx|from\s+starlette\.testclient|from\s+fastapi\.testclient (API testing)
Grep: from\s+django\.test|from\s+rest_framework\.test                  (Django testing)
```

Read config files:
```
Glob: pytest.ini, pyproject.toml ([tool.pytest]), setup.cfg ([tool:pytest])
Glob: tox.ini, noxfile.py
Glob: .coveragerc, pyproject.toml ([tool.coverage])
```

**Go**:
```
Grep: import\s+"testing"                                                (standard testing)
Grep: "github\.com/stretchr/testify                                    (testify)
Grep: "github\.com/onsi/ginkgo|"github\.com/onsi/gomega               (Ginkgo/Gomega)
Grep: "github\.com/golang/mock|"go\.uber\.org/mock                     (GoMock)
Grep: "github\.com/DATA-DOG/go-sqlmock                                (SQL mock)
Grep: "github\.com/jarcoal/httpmock                                    (HTTP mock)
Grep: httptest\.NewServer|httptest\.NewRecorder                        (httptest)
Grep: func\s+Test\w+\(t\s+\*testing\.T\)                              (test functions)
Grep: func\s+Benchmark\w+\(b\s+\*testing\.B\)                         (benchmarks)
Grep: func\s+Example\w+\(                                             (examples as tests)
Grep: func\s+Fuzz\w+\(f\s+\*testing\.F\)                              (fuzz tests)
```

### Step 3: Analyze each test file

For EACH test file found:

#### A. Basic Information
- **File path**: full path
- **Module tested**: which source module this tests
- **Test framework**: which framework is used
- **Test type**: unit / integration / e2e / performance / property-based

#### B. Test Cases

List EVERY test case (describe/it/test block or test function):
- **Test name**: the test description string or function name
- **What it tests**: brief description of the behavior being verified
- **Assertions**: count of assertions/expects
- **Mocks/Stubs**: what is mocked (DB, HTTP, time, etc.)
- **Fixtures**: what test data/setup is used

#### C. Test Helpers and Fixtures

Identify shared test utilities:
```
Grep: beforeAll|beforeEach|afterAll|afterEach                (lifecycle hooks)
Grep: @pytest\.fixture|conftest                               (pytest fixtures)
Grep: TestMain|TestSuite|SetupTest|TearDownTest              (Go test setup)
Grep: factory\.|Factory\(|create_batch                       (test factories)
```

For EACH test helper/fixture:
- Name
- File location
- What it provides (DB connection, seeded data, HTTP client, mock server)
- Scope (per-test, per-file, per-suite, global)

### Step 4: Assess test coverage

Look for coverage configuration and reports:

```
Glob: coverage/**, htmlcov/**, .coverage, lcov.info
Grep: --coverage|--cov|coverage run|go test.*-coverprofile
```

Record:
- Coverage tool used
- Current coverage percentage (if available in config or CI)
- Coverage thresholds enforced
- Files/patterns excluded from coverage

### Step 5: Analyze the build system

#### Build Commands

Read all build-related configuration:

**TypeScript/JavaScript**:
```
Read: package.json "scripts" section (EVERY script)
Glob: Makefile, Taskfile.yml, Justfile
Glob: webpack.config.*, rollup.config.*, esbuild.config.*, vite.config.*
Glob: tsconfig.json, tsconfig.build.json, tsconfig.*.json
```

**Python**:
```
Read: pyproject.toml [build-system] and [tool.setuptools]
Read: Makefile, Taskfile.yml, Justfile
Glob: setup.py, setup.cfg
Read: tox.ini, noxfile.py (build/test automation)
```

**Go**:
```
Read: Makefile, Taskfile.yml, Justfile
Glob: goreleaser.yml, .goreleaser.yaml
Grep: //go:generate                     (code generation directives)
Grep: //go:build|// \+build             (build tags/constraints)
```

For EACH build command:
- Command name and invocation
- What it does
- Dependencies (what must run before it)
- Cargo equivalent

#### Code Generation

Identify any code generation:
```
Grep: //go:generate|go generate                  (Go generate)
Grep: protoc|protobuf|\.proto                    (Protocol Buffers)
Grep: openapi-generator|swagger-codegen          (API code generation)
Grep: graphql-codegen|@graphql                   (GraphQL code generation)
Grep: prisma generate|drizzle-kit generate       (ORM code generation)
Grep: sqlc|sqlx.*prepare                         (SQL code generation)
```

For EACH code generation step:
- Tool used
- Input files
- Output files
- Rust equivalent tool

### Step 6: Analyze CI/CD configuration

Read CI/CD config files:

```
Glob: .github/workflows/*.yml, .github/workflows/*.yaml
Glob: .gitlab-ci.yml
Glob: Jenkinsfile
Glob: .circleci/config.yml
Glob: .travis.yml
Glob: Dockerfile, docker-compose.yml, docker-compose.*.yml
Glob: .dockerignore
```

For EACH CI pipeline/workflow:

- **Name**: workflow/pipeline name
- **Trigger**: what triggers it (push, PR, schedule, manual)
- **Steps**: list every step with what it does
- **Environment**: OS, language version, services (DB, Redis)
- **Artifacts**: what is produced (binary, Docker image, npm package)
- **Deployment**: where and how it deploys

### Step 7: Identify linting and formatting

```
Glob: .eslintrc*, .eslintignore, eslint.config.*
Glob: .prettierrc*, .prettierignore
Glob: .pylintrc, .flake8, ruff.toml, pyproject.toml ([tool.ruff])
Glob: .golangci.yml, .golangci.yaml
Glob: .editorconfig
```

For EACH linting/formatting tool:
- Tool name
- Configuration summary (key rules enabled/disabled)
- Rust equivalent

### Step 8: Organize output

## Template

```markdown
# Test Structure and Build System Analysis

Generated: {date}
Source: {project_path}

## Summary

| Metric | Count |
|--------|-------|
| Test files | {N} |
| Test cases | {N} |
| Unit tests | {N} |
| Integration tests | {N} |
| E2E tests | {N} |
| Benchmark/perf tests | {N} |
| Property-based tests | {N} |
| Test helpers/fixtures | {N} |
| Build scripts/commands | {N} |
| CI workflows | {N} |
| Code generation steps | {N} |

## Test Frameworks

| Framework | Version | Type | Rust Equivalent |
|-----------|---------|------|-----------------|
| {Jest} | {29.x} | Unit/Integration | Built-in `#[test]` + assert macros |
| {Supertest} | {6.x} | HTTP Integration | `axum::test` or `reqwest` in tests |
| {Playwright} | {1.x} | E2E | Keep Playwright or use `fantoccini` |
| {fast-check} | {3.x} | Property-based | `proptest` or `quickcheck` |
| ... | | | |

## Test Coverage

| Metric | Value |
|--------|-------|
| Coverage tool | {Jest --coverage / pytest-cov / go test -cover} |
| Current coverage | {N}% (if available) |
| Coverage threshold | {N}% (if enforced) |
| Excluded patterns | {list} |
| Rust equivalent | `cargo llvm-cov` or `cargo tarpaulin` |

## Test File Inventory

### TF-{nnn}: {test_file_path}

- **File**: [{test_file_path}](../{test_file_path})
- **Tests**: {source_module_tested}
- **Framework**: {Jest / pytest / testing}
- **Type**: {unit / integration / e2e}
- **Test cases**: {N}
- **Mocks used**: {list what is mocked}

**Test cases**:

| # | Test name | What it verifies | Assertions | Mocks |
|---|-----------|-----------------|------------|-------|
| 1 | "should create a new user" | User creation with valid data | 3 | DB |
| 2 | "should reject duplicate email" | Unique constraint enforcement | 2 | DB |
| 3 | "should hash password" | Password is not stored in plain text | 1 | None |
| ... | | | | |

---

{Repeat for EVERY test file. List every test case.}

## Test Helpers and Fixtures

### TH-{nn}: {helper_name}

- **File**: [{file_path}](../{file_path})
- **Provides**: {what it sets up, e.g., "database connection with seeded test data"}
- **Scope**: {per-test / per-file / per-suite / global}
- **Used by**: {list test files that use this helper}
- **Rust equivalent**: {e.g., "#[fixture] with sqlx::test or custom setup fn"}

---

{Repeat for EVERY test helper/fixture.}

## Test Data and Factories

| # | Factory/Fixture | File | Creates | Rust Equivalent |
|---|----------------|------|---------|-----------------|
| 1 | UserFactory | tests/factories/user.ts | User with random data | `fake` crate + builder |
| 2 | seed_database | tests/fixtures/seed.py | Pre-populated DB | sqlx migrations + fixtures |
| ... | | | | |

## Mock Patterns

| # | What's mocked | Tool | Used in | Rust Equivalent |
|---|--------------|------|---------|-----------------|
| 1 | Database queries | {jest.mock / unittest.mock / gomock} | {N} test files | Trait-based mocking with `mockall` |
| 2 | HTTP calls | {nock / responses / httpmock} | {N} test files | `wiremock` or `mockito` |
| 3 | Time/clock | {jest.useFakeTimers / freezegun} | {N} test files | `tokio::time::pause` |
| 4 | File system | {memfs / pyfakefs} | {N} test files | `tempfile` + trait abstraction |
| ... | | | | |

## Build System

### Build Commands

| # | Command | Source | What It Does | Deps | Cargo Equivalent |
|---|---------|--------|-------------|------|------------------|
| 1 | `npm run build` | package.json | Compile TS to JS | - | `cargo build --release` |
| 2 | `npm run dev` | package.json | Dev server with hot reload | - | `cargo watch -x run` |
| 3 | `npm test` | package.json | Run all tests | build | `cargo test` |
| 4 | `npm run lint` | package.json | ESLint + Prettier check | - | `cargo clippy && cargo fmt --check` |
| 5 | `npm run typecheck` | package.json | TypeScript type checking | - | Built into `cargo build` |
| 6 | `npm run migrate` | package.json | Run DB migrations | - | `sqlx migrate run` |
| ... | | | | | |

{List EVERY script/command from package.json, Makefile, etc.}

### TypeScript/Build Configuration

| Config File | Key Settings | Migration Notes |
|------------|-------------|-----------------|
| tsconfig.json | target: ES2022, strict: true, paths: {...} | Strictness built into Rust, paths become module structure |
| webpack.config.js | Entry, output, loaders, plugins | Replaced by Cargo build system |
| ... | | |

### Code Generation

| # | Tool | Input | Output | Trigger | Rust Equivalent |
|---|------|-------|--------|---------|-----------------|
| 1 | Prisma | schema.prisma | Generated client | `prisma generate` | sqlx (no codegen) or diesel (schema.rs) |
| 2 | protoc | *.proto | TS/Go types | build script | `tonic-build` in build.rs |
| 3 | GraphQL Codegen | schema.graphql | TS types | `codegen` | `async-graphql` derive macros |
| ... | | | | | |

## CI/CD Pipelines

### CI-{nn}: {workflow_name}

- **File**: [{ci_config_path}](../{ci_config_path})
- **Trigger**: {push to main / PR / schedule / manual}
- **Environment**: {OS, language version}

**Steps**:

| # | Step | Command | Purpose | Rust Equivalent |
|---|------|---------|---------|-----------------|
| 1 | Checkout | actions/checkout@v4 | Get source code | Same |
| 2 | Setup Node | actions/setup-node@v4 | Install Node 20 | `dtolnay/rust-toolchain@stable` |
| 3 | Install deps | npm ci | Install packages | (built into cargo build) |
| 4 | Lint | npm run lint | Code quality | `cargo clippy -- -D warnings` |
| 5 | Type check | npm run typecheck | Type safety | `cargo build` (implicit) |
| 6 | Test | npm test | Run tests | `cargo test` |
| 7 | Build | npm run build | Compile | `cargo build --release` |
| 8 | Docker | docker build | Container image | `docker build` (update Dockerfile) |
| 9 | Deploy | deploy script | Ship to production | Same or update for binary |
| ... | | | | |

**Services**:
| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | postgres:16 | 5432 | Test database |
| Redis | redis:7 | 6379 | Test cache |

---

{Repeat for EVERY CI/CD workflow.}

## Docker Configuration

### Dockerfile Analysis

- **Base image**: {node:20-alpine / python:3.12-slim / golang:1.21}
- **Build stages**: {multi-stage? list stages}
- **Final image size**: {estimate}
- **Rust migration**:
  - Build stage: `rust:1.XX as builder`
  - Runtime stage: `debian:bookworm-slim` or `scratch` or `distroless`
  - Expected image size improvement: {estimate}

### Docker Compose Services

| Service | Image | Purpose | Rust Changes |
|---------|-------|---------|-------------|
| app | Dockerfile | Main application | Update Dockerfile |
| db | postgres:16 | Database | No change |
| redis | redis:7 | Cache | No change |
| ... | | | |

## Linting and Formatting

| Tool | Config File | Key Rules | Rust Equivalent |
|------|------------|-----------|-----------------|
| ESLint | .eslintrc.js | {key rules} | `cargo clippy` |
| Prettier | .prettierrc | {format settings} | `cargo fmt` (rustfmt.toml) |
| TypeScript strict | tsconfig.json | strict: true | Built into Rust's type system |
| ... | | | |

## Migration Checklist for Testing

- [ ] All unit test behaviors are covered by Rust `#[test]` functions
- [ ] Integration test infrastructure (DB setup, HTTP server) is replicated
- [ ] E2E tests can run against Rust binary (may keep original framework)
- [ ] Mock patterns are mapped to Rust equivalents (trait-based or `mockall`)
- [ ] Test data factories are ported
- [ ] Coverage tooling is configured (`cargo llvm-cov` or `tarpaulin`)
- [ ] CI pipeline is updated for Rust build/test/deploy cycle
- [ ] Dockerfile is updated for Rust compilation
- [ ] All code generation steps have Rust equivalents or `build.rs` scripts
```

## Completeness Check

- [ ] Every test file is listed individually (not "found N test files")
- [ ] Every test case within each file is listed with its name and purpose
- [ ] Every test helper and fixture is cataloged with scope and usage
- [ ] Every mock pattern is identified with its Rust equivalent
- [ ] Every build command/script is listed with Cargo equivalent
- [ ] Every CI/CD workflow is documented step by step
- [ ] Every code generation step is identified with Rust equivalent
- [ ] Every linting/formatting tool is listed with Rust equivalent
- [ ] Docker configuration is analyzed with Rust migration notes
- [ ] Test coverage metrics and thresholds are documented
- [ ] No test files or build commands are summarized as "and N more"
