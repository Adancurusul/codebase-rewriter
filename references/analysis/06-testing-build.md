# 06 - Testing and Build System

**Output**: `.migration-plan/analysis/testing-build.md`

Catalog the test suite, build pipeline, and deployment configuration.

## Method

1. Find test files: `**/*.test.*`, `**/*.spec.*`, `**/test_*.py`, `**/*_test.go`, `tests/`
2. Identify test framework, assertion library, mocking approach
3. Read build config: tsconfig.json / pyproject.toml / go.mod, Makefile, scripts
4. Check CI: .github/workflows/, .gitlab-ci.yml, Dockerfile, docker-compose

## Template

```markdown
# Testing & Build

## Test Summary

| Metric | Value |
|--------|-------|
| Framework | jest / pytest / go test |
| Test files | {N} |
| Test cases | {N} (approximate) |
| Coverage config | Yes / No |
| Mock library | sinon / unittest.mock / gomock |

## Test Catalog

| Test File | Tests | Type | What It Tests |
|-----------|-------|------|--------------|
| [users.test.ts](../tests/users.test.ts) | 8 | Unit | User CRUD |
| [api.test.ts](../tests/api.test.ts) | 12 | Integration | API endpoints |
{EVERY test file}

## Build System

| Tool | Config File | Purpose |
|------|------------|---------|
| TypeScript | tsconfig.json | Type checking + compilation |
| esbuild | build.ts | Bundling |

## CI/CD

| Platform | Config | Jobs |
|----------|--------|------|
| GitHub Actions | .github/workflows/ci.yml | lint, test, build, deploy |

## Deployment

| Target | Method | Config |
|--------|--------|--------|
| Docker | Dockerfile | Multi-stage, node:20-slim |
| K8s | k8s/*.yaml | Deployment + Service |
```
