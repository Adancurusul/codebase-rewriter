# Output Templates

Templates for all Phase 3 synthesis documents.

---

## migration-plan.md (Executive Summary)

**Output**: `.migration-plan/migration-plan.md`

```markdown
# Migration Plan: {project-name}

## Overview
| Metric | Value |
|--------|-------|
| Source Language | {lang} |
| Source LOC | {N} |
| Modules | {N} |
| Dependencies | {N} |
| Target | Rust (tokio + axum/clap) |

## Rationale
{Why rewrite to Rust? 2-3 sentences with specific benefits for this project.}

## Scope
- **Included**: {modules/features being migrated}
- **Excluded**: {what stays in original language or gets dropped}

## Strategy
{Module-by-module / Strangler fig / Big bang}

## Key Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Async runtime | tokio | Industry standard |
| Web framework | axum | Tower ecosystem |
| Error handling | thiserror | Typed errors |
| Database | sqlx | Compile-time SQL |

## Estimated Effort
Total rounds: {N} | Risk multiplier: {X} | Effective: {N}
```

---

## feasibility-report.md

**Output**: `.migration-plan/feasibility-report.md`

```markdown
# Feasibility Report

## Recommendation: {GO / CONDITIONAL GO / NO-GO}

## Score: {X.X} / 10

| Dimension | Score (1-10) | Weight | Rationale |
|-----------|-------------|--------|-----------|
| Performance Need | {N} | 0.15 | {evidence} |
| Safety Need | {N} | 0.15 | {evidence} |
| Deployment Benefit | {N} | 0.10 | {evidence} |
| Type System Benefit | {N} | 0.10 | {evidence} |
| Ecosystem Maturity | {N} | 0.15 | {evidence} |
| Team Readiness | {N} | 0.15 | {evidence} |
| Codebase Complexity | {N} | 0.10 | {evidence} |
| Maintenance Burden | {N} | 0.10 | {evidence} |

## Blockers
{Showstoppers that make migration impossible, or "None identified"}

## Risks
{Challenges that increase effort but are solvable}

## Alternatives
| Option | Pros | Cons |
|--------|------|------|
| Full rewrite | {pros} | {cons} |
| Partial migration | {pros} | {cons} |
| Optimize in place | {pros} | {cons} |
```

---

## risk-assessment.md

**Output**: `.migration-plan/risk-assessment.md`

```markdown
# Risk Assessment

| ID | Risk | Category | Probability | Impact | Score | Mitigation |
|----|------|----------|------------|--------|-------|-----------|
| R1 | {description} | Technical | H/M/L | H/M/L | {P*I} | {strategy} |
| R2 | {description} | Dependency | H/M/L | H/M/L | {P*I} | {strategy} |
{EVERY identified risk}

## Risk Matrix

|        | Low Impact | Medium Impact | High Impact |
|--------|-----------|--------------|------------|
| High P | | | {R-ids} |
| Med P  | | {R-ids} | |
| Low P  | {R-ids} | | |
```

---

## dev-workflow/roadmap.md

**Output**: `.migration-plan/dev-workflow/roadmap.md`

Uses exact dev-workflow format:

```markdown
# Migration Roadmap

## Milestone 1: Foundation
- [ ] #1 Initialize Cargo workspace
  - Description: Create workspace, crates: {list}
  - Rounds: 5 (risk 1.0, effective 5)
  - Verification: `cargo build` passes
  - Dependencies: none

- [ ] #2 Implement error types
  - Description: {from error-hierarchy.md}
  - Rounds: 8 (risk 1.3, effective 10)
  - Verification: `cargo test -p error`
  - Dependencies: #1

## Milestone 2: Core Types
- [ ] #3 Migrate model types
  - Description: {N} types from type-mapping.md
  - Rounds: {N} (risk 1.3, effective {N})
  - Verification: serde round-trip tests
  - Dependencies: #1

## Milestone 3: Business Logic
{service layer tasks}

## Milestone 4: API Layer
{handler + middleware tasks}

## Milestone 5: Testing
{test migration tasks}

## Milestone 6: Deployment
{CI/CD + Docker tasks}
```

---

## dev-workflow/requirements.md

**Output**: `.migration-plan/dev-workflow/requirements.md`

```markdown
# Migration Requirements

## R1: {Module} Migration
- **Source**: {source path}
- **Target**: {rust crate}
- **Acceptance**: {what "done" looks like}

{one requirement per module}
```

---

## dev-workflow/solution.md

**Output**: `.migration-plan/dev-workflow/solution.md`

```markdown
# Migration Architecture

## Target Architecture
{Cargo workspace layout diagram}

## Technology Stack
| Layer | Choice | Rationale |
|-------|--------|-----------|
| HTTP | axum 0.8 | {why} |
| DB | sqlx 0.8 | {why} |
| Error | thiserror 2 | {why} |

## Migration Approach
{module-by-module strategy with ordering}
```
