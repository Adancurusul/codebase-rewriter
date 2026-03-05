# Scaffold Guide

**Output**: Cargo workspace + module skeletons + CI in the target project

Optional Phase 4. Only run when user explicitly requests scaffold generation.

## Method

1. Read `.migration-plan/mappings/module-mapping.md` -- get crate layout
2. Read `.migration-plan/mappings/type-mapping.md` -- get type definitions
3. Read `.migration-plan/mappings/dependency-mapping.md` -- get crate versions
4. Read `.migration-plan/mappings/error-hierarchy.md` -- get error types

## Step 1: Cargo Workspace

Create root `Cargo.toml`:

```toml
[workspace]
members = ["crates/*"]
resolver = "2"

[workspace.package]
version = "0.1.0"
edition = "2024"

[workspace.dependencies]
# declare shared deps here, reference with .workspace = true in members
```

Create `Cargo.toml` for each crate in `crates/{name}/`.

## Step 2: Module Skeletons

For each crate:
- `src/lib.rs` with `pub mod` declarations
- One `.rs` file per module from module-mapping
- **Type definitions**: COMPLETE (from type-mapping.md) with all derives and serde attrs
- **Function signatures**: `todo!()` body, complete parameter types and return types
- **Doc comments**: source file:line reference on every type and function

## Step 3: Error Types

Implement the error hierarchy from error-hierarchy.md:
- Full `AppError` enum with thiserror
- `IntoResponse` impl (if web service)
- `From` impls for external errors

## Step 4: CI Configuration

Generate based on source CI platform (default: GitHub Actions):

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
      - run: cargo check --workspace
      - run: cargo test --workspace
      - run: cargo clippy --workspace -- -D warnings
      - run: cargo fmt --check
```

Generate Dockerfile if source has one (multi-stage build).

## Step 5: Supporting Files

- `rust-toolchain.toml`: stable channel
- `.cargo/config.toml`: aliases (dev, t, ta, c)
- `.env.example`: environment variables
- Add `/target` to `.gitignore`

## Verification

```bash
cargo build --workspace   # must pass
cargo clippy --workspace  # warnings OK from todo!()
cargo fmt --check         # must pass
```
