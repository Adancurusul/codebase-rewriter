# 04 - Dependency Graph

**Output**: `.migration-plan/analysis/dependency-tree.md`

Catalog every external dependency with usage sites.

## Method

1. Read dependency manifest:
   - TS: `package.json` (dependencies + devDependencies)
   - Python: `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile`
   - Go: `go.mod` (require block)
2. For EACH dependency: grep for import/require statements to find actual usage sites
3. Classify: runtime vs dev-only, direct vs transitive

## Template

```markdown
# Dependency Tree

Total: {N} | Runtime: {N} | Dev-only: {N}

## Runtime Dependencies

| Package | Version | Category | Usage Files | Import Count |
|---------|---------|----------|-------------|-------------|
| express | ^4.18.2 | HTTP Server | app.ts, routes/*.ts | 8 |
| prisma | ^5.10 | ORM | services/*.ts | 12 |
{EVERY runtime dependency}

## Dev Dependencies

| Package | Version | Category |
|---------|---------|----------|
| typescript | ^5.3 | Build |
| jest | ^29 | Testing |
{EVERY dev dependency}

## Usage Detail

### {package-name} ({version})
- **Purpose**: {what it does in this project}
- **Import sites**:
  - [src/app.ts:3](../src/app.ts#L3)
  - [src/routes/users.ts:1](../src/routes/users.ts#L1)
- **APIs used**: `Router`, `json()`, `static()`

{repeat for EVERY runtime dependency}
```
