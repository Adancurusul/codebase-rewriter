# 00 - Source Inventory

**Output**: `.migration-plan/analysis/source-inventory.md`

Catalog every file and directory in the source project.

## Method

1. Scan project root (depth 3-4), excluding: node_modules, .git, build, dist, vendor, __pycache__, venv, target
2. Count files by extension, identify primary language
3. Identify key directories (src, lib, pkg, cmd, internal, tests, scripts, config)
4. List every source file with line count and purpose

## Template

```markdown
# Source Inventory

## Summary

| Metric | Value |
|--------|-------|
| Primary Language | {TypeScript/Python/Go} |
| Total Source Files | {N} |
| Total Lines | {N} |
| Test Files | {N} |
| Config Files | {N} |

## Directory Tree

{depth 3-4 tree output}

## Files by Extension

| Extension | Count | Lines | Purpose |
|-----------|-------|-------|---------|
| .ts | 45 | 3200 | Source code |
| .json | 8 | 120 | Configuration |

## Source File Catalog

| File | Lines | Purpose |
|------|-------|---------|
| [src/index.ts](../src/index.ts) | 25 | Entry point |
| [src/app.ts](../src/app.ts) | 80 | App setup |
{EVERY source file listed}
```
