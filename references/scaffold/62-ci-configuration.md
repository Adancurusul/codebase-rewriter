# 62 - CI Configuration

**Output**: `{project_root}/.github/workflows/ci.yml`, `{project_root}/Dockerfile`

## Purpose

Generate CI/CD configuration for the scaffolded Rust project. The CI pipeline ensures the migrated codebase stays healthy as dev-workflow fills in implementations. It runs checks, tests, formatting, and linting on every push/PR.

## Prerequisites

- Cargo workspace generated (guide 60)
- `.migration-plan/analysis/testing-build.md` -- source CI/CD analysis

## Method

### Step 1: Read source CI analysis

From `testing-build.md`, extract:
- Current CI platform (GitHub Actions, GitLab CI, Jenkins, CircleCI)
- Test commands and workflows
- Deployment targets
- Environment variables needed

### Step 2: Generate GitHub Actions workflow

Default to GitHub Actions (most common). Generate `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always
  RUST_BACKTRACE: 1

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --workspace --all-targets

  test:
    name: Test
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    env:
      DATABASE_URL: postgres://test:test@localhost:5432/test_db
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo test --workspace

  clippy:
    name: Clippy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy
      - uses: Swatinem/rust-cache@v2
      - run: cargo clippy --workspace --all-targets -- -D warnings

  fmt:
    name: Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt
      - run: cargo fmt --all -- --check

  # Uncomment when ready for deployment
  # build-release:
  #   name: Build Release
  #   needs: [check, test, clippy, fmt]
  #   runs-on: ubuntu-latest
  #   steps:
  #     - uses: actions/checkout@v4
  #     - uses: dtolnay/rust-toolchain@stable
  #     - uses: Swatinem/rust-cache@v2
  #     - run: cargo build --release
  #     - uses: actions/upload-artifact@v4
  #       with:
  #         name: binary
  #         path: target/release/{binary-name}
```

### Step 3: Adapt for source CI platform

If the source project uses a different CI platform, also generate equivalent config:

#### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - check
  - test
  - build

variables:
  CARGO_HOME: $CI_PROJECT_DIR/.cargo
  RUST_BACKTRACE: "1"

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .cargo/
    - target/

check:
  stage: check
  image: rust:latest
  script:
    - cargo check --workspace

test:
  stage: test
  image: rust:latest
  services:
    - postgres:16
  variables:
    DATABASE_URL: postgres://postgres:postgres@postgres:5432/test_db
    POSTGRES_DB: test_db
    POSTGRES_PASSWORD: postgres
  script:
    - cargo test --workspace

clippy:
  stage: check
  image: rust:latest
  script:
    - rustup component add clippy
    - cargo clippy --workspace -- -D warnings

fmt:
  stage: check
  image: rust:latest
  script:
    - rustup component add rustfmt
    - cargo fmt --all -- --check

build:
  stage: build
  image: rust:latest
  script:
    - cargo build --release
  artifacts:
    paths:
      - target/release/
  only:
    - main
```

### Step 4: Generate Dockerfile (if source has one)

```dockerfile
# Dockerfile

# Build stage
FROM rust:1.85-slim AS builder

WORKDIR /app

# Cache dependencies
COPY Cargo.toml Cargo.lock ./
COPY crates/models/Cargo.toml crates/models/
COPY crates/error/Cargo.toml crates/error/
COPY crates/config/Cargo.toml crates/config/
COPY crates/services/Cargo.toml crates/services/
COPY crates/api/Cargo.toml crates/api/

# Create dummy source files for dependency caching
RUN for dir in crates/*/src; do \
      mkdir -p "$dir" && \
      echo "fn main() {}" > "$dir/main.rs" 2>/dev/null; \
      echo "" > "$dir/lib.rs" 2>/dev/null; \
    done

RUN cargo build --release 2>/dev/null || true

# Copy actual source
COPY crates/ crates/

# Build for real
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/{binary-name} /usr/local/bin/app

EXPOSE 3000

CMD ["app"]
```

### Step 5: Generate docker-compose for local development

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/app_db
      - RUST_LOG=info
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app_db
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

### Step 6: Generate .env.example

```bash
# .env.example
DATABASE_URL=postgres://postgres:postgres@localhost:5432/app_db
RUST_LOG=info
BIND_ADDRESS=0.0.0.0:3000
```

## Adaptation Rules

| Source has | Generate |
|-----------|----------|
| GitHub Actions | `.github/workflows/ci.yml` |
| GitLab CI | `.gitlab-ci.yml` |
| CircleCI | `.circleci/config.yml` |
| Dockerfile | Multi-stage Dockerfile |
| docker-compose | docker-compose.yml |
| No CI | GitHub Actions as default |

| Source uses | CI service |
|-------------|------------|
| PostgreSQL | Add postgres service container |
| MySQL | Add mysql service container |
| Redis | Add redis service container |
| MongoDB | Add mongo service container (consider alternatives in Rust) |
| No database | Omit service containers |

## Quality Criteria

- [ ] CI runs cargo check, test, clippy, fmt
- [ ] Database service container matches source database
- [ ] Environment variables documented in .env.example
- [ ] Dockerfile uses multi-stage build for small image
- [ ] Cargo caching configured for CI (rust-cache action or equivalent)
- [ ] CI platform matches source project (or defaults to GitHub Actions)
- [ ] Docker image size < 50MB for release build (no debug symbols)
- [ ] All CI jobs pass on the scaffold (with `todo!()` warnings allowed)
