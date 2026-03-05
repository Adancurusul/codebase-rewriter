# 14 - Module Mapping

**Output**: `.migration-plan/mappings/module-mapping.md`

Map every source module to a Rust crate or module in the workspace.

## Method

1. Read `.migration-plan/analysis/architecture.md` -- get module map and dependency graph
2. Read `.migration-plan/analysis/source-inventory.md` -- get file counts per directory
3. For EACH source module:
   a. Decide: separate crate (if reusable) or module within a crate
   b. Name it (snake_case)
   c. List its public API surface
   d. Determine migration complexity and order
4. Design Cargo workspace layout
5. Order by dependencies: migrate leaf modules first

## Template

```markdown
# Module Mapping

Source modules: {N} | Rust crates: {N}

## Workspace Layout

\`\`\`
project/
├── Cargo.toml          # workspace root
├── crates/
│   ├── models/         # src/models/ -> models crate
│   ├── error/          # src/errors/ -> error crate
│   ├── services/       # src/services/ -> services crate
│   └── api/            # src/routes/ -> api crate (binary)
\`\`\`

## Module Mapping Table

| Source Module | Source Path | Rust Crate/Module | Files | Complexity | Phase |
|--------------|------------|-------------------|-------|-----------|-------|
| models | src/models/ | crates/models | 6 | Low | 1 |
| errors | src/errors/ | crates/error | 2 | Low | 1 |
| services | src/services/ | crates/services | 5 | Medium | 2 |
| routes | src/routes/ | crates/api | 8 | Medium | 3 |
{EVERY module}

## Internal Dependency Graph

\`\`\`
api -> services -> models
                -> error
\`\`\`

## Per-Module Detail

### {source-module} -> {rust-crate}
- **Public API**: {exported types and functions}
- **Internal deps**: {other modules it imports}
- **External deps**: {crates it needs}
- **Complexity**: Low / Medium / High
- **Migration order**: Phase {N}
- **Estimated rounds**: {N}

{repeat for EVERY module}
```
