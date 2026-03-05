# 00 - Source Code Structure Inventory

**Output**: `.migration-plan/analysis/source-inventory.md`

## Purpose

Build a complete inventory of every source file, directory, entry point, and build artifact in the codebase. This is the foundational map that all subsequent analysis guides depend on. Without knowing exactly what files exist, where entry points are, and how the project is built, no migration plan can be accurate.

For Rust migration specifically, the inventory reveals:
- Total migration surface area (file counts drive effort estimates)
- Entry points that become `fn main()` or library roots
- Build system that must be replaced with Cargo
- Project metadata (name, version, description) that carries into `Cargo.toml`

## Method

### Step 1: Find all source files

Glob for source files by language, excluding vendored/generated directories:

**TypeScript/JavaScript**:
```
Glob: **/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.mjs, **/*.cjs
Exclude: node_modules/**, dist/**, build/**, .next/**, coverage/**
```

**Python**:
```
Glob: **/*.py, **/*.pyi
Exclude: venv/**, .venv/**, __pycache__/**, .eggs/**, *.egg-info/**
```

**Go**:
```
Glob: **/*.go
Exclude: vendor/**
```

**Common exclusions** (all languages):
```
Exclude: .git/**, .migration-plan/**, .codebase-analysis/**
```

### Step 2: Count files by directory and extension

For EACH directory that contains source files:
- Count files by extension
- Note total lines of code (use `wc -l`)
- Identify the directory's apparent purpose from naming conventions

Do not summarize directories into groups. List every directory individually.

### Step 3: Identify entry points

Grep for entry point patterns:

**TypeScript/JavaScript**:
```
Grep: "main" in package.json (the "main", "module", "bin", "scripts.start" fields)
Glob: **/index.ts, **/main.ts, **/app.ts, **/server.ts, **/cli.ts
Grep: #!/usr/bin/env (shebang lines for CLI tools)
Grep: express\(\)|createServer|fastify\(\)|Hono\(\)|new Koa (server creation)
```

**Python**:
```
Grep: if __name__ == .__main__. (main guards)
Grep: "scripts" in pyproject.toml or setup.py console_scripts
Glob: **/main.py, **/app.py, **/cli.py, **/manage.py, **/wsgi.py, **/asgi.py
Grep: uvicorn|gunicorn|flask.run|app\.run (server entry points)
```

**Go**:
```
Grep: ^package main$ (main packages)
Grep: ^func main\(\) (main functions)
Glob: **/main.go, **/cmd/**/main.go
```

For EACH entry point found, record:
- File path
- Entry point type (CLI binary, HTTP server, library export, worker, Lambda handler)
- What it initializes (database connections, config loading, middleware)

### Step 4: Read project configuration

Read the primary config files to extract project metadata:

**TypeScript/JavaScript** - Read `package.json`:
- name, version, description
- dependencies (count only here; detail in guide 04)
- devDependencies (count only)
- scripts (list all script names and commands)
- engines (Node version constraints)
- type ("module" or "commonjs")

Also check for: `tsconfig.json` (compiler options, paths, strict mode), `turbo.json` or `nx.json` (monorepo), `lerna.json`

**Python** - Read `pyproject.toml` or `setup.py` or `setup.cfg`:
- name, version, description
- python_requires
- dependencies (count only)
- optional-dependencies / extras_require (count only)
- scripts / console_scripts
- build-system (setuptools, poetry, hatch, flit, maturin)

Also check for: `Pipfile`, `requirements.txt`, `tox.ini`, `mypy.ini` or `[tool.mypy]`

**Go** - Read `go.mod`:
- module path
- go version
- require directives (count only)
- replace directives (list all -- these indicate forked dependencies)

Also check for: `Makefile`, `Taskfile.yml`, `goreleaser.yml`

### Step 5: Identify build system and commands

For EACH build/run command discovered:
- Command name
- What it does
- Equivalent Cargo command (preliminary mapping)

### Step 6: Detect monorepo structure

Check for workspace patterns:
- `package.json` "workspaces" field
- `pnpm-workspace.yaml`
- `go.work`
- Multiple `go.mod` files
- `Cargo.toml` at root with `[workspace]`

If monorepo detected, list EACH workspace member with its path, name, and purpose.

### Step 7: Organize output

Compile all findings into the output template below. Every directory gets its own row. Every entry point gets its own entry. Nothing is summarized into "and N more".

## Template

```markdown
# Source Inventory

Generated: {date}
Source: {project_path}

## Project Metadata

| Field | Value |
|-------|-------|
| Name | {project_name} |
| Version | {version} |
| Description | {description} |
| Source Language | {TypeScript / Python / Go / Mixed} |
| Language Version | {e.g., Node 18+, Python 3.11+, Go 1.21} |
| Module System | {ESM / CommonJS / Python packages / Go modules} |
| Build System | {tsc / esbuild / vite / setuptools / poetry / go build} |
| Monorepo | {Yes (tool) / No} |

## File Counts

| Directory | .ts | .tsx | .js | .py | .go | Other | Total | Purpose |
|-----------|-----|------|-----|-----|-----|-------|-------|---------|
| src/ | {n} | {n} | {n} | {n} | {n} | {n} | {n} | {purpose} |
| src/models/ | {n} | {n} | {n} | {n} | {n} | {n} | {n} | {purpose} |
| src/api/ | {n} | {n} | {n} | {n} | {n} | {n} | {n} | {purpose} |
| ... | | | | | | | | |
| **Total** | **{n}** | **{n}** | **{n}** | **{n}** | **{n}** | **{n}** | **{N}** | |

{Adjust columns based on detected language. Only include extension columns that have non-zero counts.}

## Lines of Code

| Directory | Lines | % of Total |
|-----------|-------|------------|
| src/ | {n} | {n}% |
| src/models/ | {n} | {n}% |
| ... | | |
| **Total** | **{N}** | **100%** |

## Entry Points

| # | File | Type | Description |
|---|------|------|-------------|
| 1 | [src/main.ts](../src/main.ts) | HTTP Server | Express app, loads middleware, connects DB |
| 2 | [src/cli.ts](../src/cli.ts) | CLI Binary | Commander-based CLI with 5 subcommands |
| 3 | [src/worker.ts](../src/worker.ts) | Background Worker | Bull queue processor for email jobs |
| ... | | | |

### Entry Point Details

#### EP-1: {file_path}
- **Type**: {CLI binary / HTTP server / Library / Worker / Lambda}
- **Initializes**: {list what it sets up}
- **Depends on**: {key modules it imports}
- **Rust equivalent**: {e.g., "axum server with tower middleware" / "clap CLI"}

{Repeat for each entry point}

## Build Commands

| Command | Source | What It Does | Cargo Equivalent |
|---------|--------|--------------|------------------|
| `npm run build` | package.json | Compile TypeScript to dist/ | `cargo build --release` |
| `npm run dev` | package.json | Start dev server with hot reload | `cargo watch -x run` |
| `npm test` | package.json | Run Jest tests | `cargo test` |
| `npm run lint` | package.json | ESLint + Prettier | `cargo clippy && cargo fmt --check` |
| ... | | | |

## Configuration Files

| File | Purpose | Migration Notes |
|------|---------|-----------------|
| tsconfig.json | TypeScript compiler config | Replaced by Cargo.toml + rustfmt.toml |
| .eslintrc.js | Linting rules | Replaced by clippy |
| jest.config.ts | Test configuration | Built into `cargo test` |
| Dockerfile | Container build | Update for Rust binary |
| .env.example | Environment variables | Use `dotenvy` crate |
| ... | | |

## Workspace Members (if monorepo)

| # | Path | Name | Purpose | Files | Lines |
|---|------|------|---------|-------|-------|
| 1 | packages/core | @project/core | Core business logic | {n} | {n} |
| 2 | packages/api | @project/api | REST API server | {n} | {n} |
| ... | | | | | |

{Omit this section entirely if not a monorepo.}

## Migration Surface Summary

- **Total source files**: {N}
- **Total lines of code**: {N}
- **Entry points**: {N} ({list types: N servers, N CLIs, N workers})
- **Workspace members**: {N or "N/A (single package)"}
- **Config files requiring migration**: {N}
- **Estimated Cargo.toml files needed**: {N}
```

## Completeness Check

- [ ] Every directory containing source files has its own row in the file counts table
- [ ] Every entry point is listed individually with type and description
- [ ] Every build command is listed with its Cargo equivalent
- [ ] Every configuration file is listed with migration notes
- [ ] Project metadata is fully extracted (name, version, language version)
- [ ] Monorepo structure is detected and each member is listed (if applicable)
- [ ] Lines of code are counted per directory
- [ ] No directories or files are summarized as "and N more" or "etc."
- [ ] File counts table columns match the actual languages found in the project
