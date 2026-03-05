# 13 - Dependency Mapping

**Output**: `.migration-plan/mappings/dependency-mapping.md`

Map every source dependency to a Rust crate equivalent.

## Method

1. Read `.migration-plan/analysis/dependency-tree.md` -- get complete dependency list with usage sites
2. Read `ref/{language}.md` -- consult the Package -> Crate Mapping table
3. For EACH runtime dependency:
   a. Look up in ref table -> get Rust crate + confidence
   b. If NOT in table: search crates.io mentally, or mark NO_EQUIVALENT
   c. Note API differences that affect migration
4. Generate workspace Cargo.toml dependency section

## Template

```markdown
# Dependency Mapping

Total: {N} | HIGH confidence: {N} | MEDIUM: {N} | LOW: {N} | NO_EQUIVALENT: {N}

## Mapping Table

| Source Package | Version | Rust Crate | Version | Confidence | Notes |
|---------------|---------|-----------|---------|------------|-------|
| express | ^4.18 | axum | 0.8 | HIGH | Tower middleware model |
| prisma | ^5.10 | sqlx | 0.8 | MEDIUM | No auto-migration, raw SQL |
| zod | ^3.22 | validator + garde | 0.18 | MEDIUM | Derive-based validation |
| custom-lib | ^1.0 | -- | -- | NO_EQUIVALENT | Must rewrite |
{EVERY runtime dependency}

## NO_EQUIVALENT Dependencies

### {package-name}
- **Purpose**: {what it does}
- **Strategy**: {rewrite from scratch / find alternative / remove feature}
- **Effort**: {Low / Medium / High}

## Generated Cargo.toml

\`\`\`toml
[workspace.dependencies]
axum = "0.8"
sqlx = { version = "0.8", features = ["runtime-tokio", "postgres"] }
serde = { version = "1", features = ["derive"] }
{all mapped crates}
\`\`\`
```
