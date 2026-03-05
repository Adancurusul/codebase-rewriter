# 05 - Architecture Analysis

**Output**: `.migration-plan/analysis/architecture.md`

Analyze the overall architecture, module boundaries, and design patterns.

## Method

1. Identify architectural style: monolith / microservice / serverless / CLI / library
2. Map module boundaries: which directories form logical modules
3. Build internal dependency graph: which modules import which
4. Identify design patterns: MVC, repository, middleware chain, event-driven, etc.
5. Identify entry points: main(), HTTP server start, CLI commands

## Template

```markdown
# Architecture

## Style
{Monolith REST API / Microservice / CLI tool / Library}

## Entry Points

| Entry | Source | Type |
|-------|--------|------|
| HTTP server | [src/index.ts:20](../src/index.ts#L20) | Express listen |
| CLI | [src/cli.ts:1](../src/cli.ts#L1) | Commander program |

## Module Map

| Module | Directory | Files | Responsibility |
|--------|-----------|-------|---------------|
| api | src/routes/ | 8 | HTTP handlers |
| services | src/services/ | 5 | Business logic |
| models | src/models/ | 6 | Data types |
| db | src/db/ | 3 | Database access |
{EVERY logical module}

## Internal Dependencies

\`\`\`
api -> services -> db
              \-> models
\`\`\`

## Design Patterns

| Pattern | Location | Description |
|---------|----------|-------------|
| Repository | src/services/ | Data access abstracted behind service layer |
| Middleware chain | src/middleware/ | Auth, validation, error handling |
{EVERY identified pattern}

## Shared State

| State | Scope | Mutability |
|-------|-------|-----------|
| DB pool | Global | Read-only after init |
| Config | Global | Immutable |
```
