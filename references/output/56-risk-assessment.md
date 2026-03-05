# 56 - Risk Assessment

**Output**: `.migration-plan/risk-assessment.md`

## Purpose

Evaluate every identified risk that could impact the success, timeline, or quality of the Rust migration. Each risk is categorized, scored, and paired with a mitigation strategy and contingency plan. This document helps stakeholders understand what could go wrong, how likely it is, and what the team will do about it.

The risk assessment is generated during Phase 3 (Synthesis) after all analysis and mapping work is complete, when the full scope of the migration is understood.

## Template

```markdown
# Risk Assessment

Source: {project_name}
Generated: {date}

## Risk Summary

| Category | Total Risks | High Severity | Medium Severity | Low Severity |
|----------|------------|---------------|-----------------|-------------|
| Technical | {N} | {N} | {N} | {N} |
| Dependency | {N} | {N} | {N} | {N} |
| Timeline | {N} | {N} | {N} | {N} |
| Organizational | {N} | {N} | {N} | {N} |
| **Total** | **{N}** | **{N}** | **{N}** | **{N}** |

### Overall Risk Level: {LOW / MEDIUM / HIGH / CRITICAL}

{1-2 sentence justification for the overall risk level.}

## Risk Matrix

```text
              Low Impact      Medium Impact     High Impact
           +---------------+----------------+----------------+
High Prob  | {risk IDs}    | {risk IDs}     | {risk IDs}     |
           +---------------+----------------+----------------+
Med Prob   | {risk IDs}    | {risk IDs}     | {risk IDs}     |
           +---------------+----------------+----------------+
Low Prob   | {risk IDs}    | {risk IDs}     | {risk IDs}     |
           +---------------+----------------+----------------+
```

### Risk Scoring

| Score | Probability * Impact |
|-------|---------------------|
| 1-2 | Low -- monitor only |
| 3-4 | Medium -- mitigation required |
| 6-9 | High -- active management required |

Probability: Low=1, Medium=2, High=3
Impact: Low=1, Medium=2, High=3

## Technical Risks

### R-1: {Risk Title}

| Field | Value |
|-------|-------|
| Category | Technical |
| Description | {Detailed description of what could go wrong} |
| Probability | {Low / Medium / High} |
| Impact | {Low / Medium / High} |
| Risk Score | {P * I = N} |
| Affected Components | {list modules/crates affected} |
| Source Evidence | [{file}:{line}](../src/{file}#L{line}) -- {what in the analysis revealed this risk} |

**Mitigation Strategy**: {What to do to prevent or reduce this risk before it materializes. Specific, actionable steps.}

**Contingency Plan**: {What to do if the risk materializes despite mitigation. The fallback approach.}

**Owner**: {Role responsible for monitoring this risk, e.g., "Migration Lead", "Backend Developer"}

---

### R-2: {Risk Title}

| Field | Value |
|-------|-------|
| Category | Technical |
| Description | {description} |
| Probability | {Low / Medium / High} |
| Impact | {Low / Medium / High} |
| Risk Score | {N} |
| Affected Components | {components} |
| Source Evidence | {evidence from analysis} |

**Mitigation Strategy**: {steps}

**Contingency Plan**: {fallback}

**Owner**: {role}

---

{Repeat for each technical risk}

## Dependency Risks

### R-{N}: {Risk Title}

| Field | Value |
|-------|-------|
| Category | Dependency |
| Description | {e.g., "No Rust crate equivalent for {package}. Must implement {functionality} manually."} |
| Probability | {Low / Medium / High} |
| Impact | {Low / Medium / High} |
| Risk Score | {N} |
| Affected Components | {components} |
| Source Evidence | dependency-mapping.md -- {package} rated NO_EQUIVALENT |

**Mitigation Strategy**: {steps}

**Contingency Plan**: {fallback}

**Owner**: {role}

---

{Repeat for each dependency risk}

## Timeline Risks

### R-{N}: {Risk Title}

| Field | Value |
|-------|-------|
| Category | Timeline |
| Description | {e.g., "Complex async patterns in {module} may take 2x estimated rounds"} |
| Probability | {Low / Medium / High} |
| Impact | {Low / Medium / High} |
| Risk Score | {N} |
| Affected Components | {components} |
| Source Evidence | {analysis finding that suggests timeline risk} |

**Mitigation Strategy**: {steps}

**Contingency Plan**: {fallback}

**Owner**: {role}

---

{Repeat for each timeline risk}

## Organizational Risks

### R-{N}: {Risk Title}

| Field | Value |
|-------|-------|
| Category | Organizational |
| Description | {e.g., "Team has limited Rust experience; learning curve may slow early phases"} |
| Probability | {Low / Medium / High} |
| Impact | {Low / Medium / High} |
| Risk Score | {N} |
| Affected Components | All phases |
| Source Evidence | Prerequisites assessment in migration-plan.md |

**Mitigation Strategy**: {steps}

**Contingency Plan**: {fallback}

**Owner**: {role}

---

{Repeat for each organizational risk}

## Risk-to-Task Mapping

| Risk ID | Risk Title | Roadmap Tasks Affected | Risk Factor Applied |
|---------|-----------|----------------------|---------------------|
| R-1 | {title} | #{task_ids} | {multiplier, e.g., 1.3x} |
| R-2 | {title} | #{task_ids} | {multiplier} |
| R-3 | {title} | #{task_ids} | {multiplier} |
| ... | | | |

## Risk Monitoring Schedule

| Risk ID | Check Frequency | Trigger Condition | Escalation Action |
|---------|----------------|-------------------|-------------------|
| R-1 | {Every milestone / Every N rounds / Weekly} | {specific condition that signals risk is materializing} | {what to do: pause, re-plan, escalate} |
| R-2 | {frequency} | {trigger} | {action} |
| ... | | | |

## Accepted Risks

Risks with Low severity that are accepted without active mitigation:

| Risk ID | Risk Title | Score | Rationale for Acceptance |
|---------|-----------|-------|--------------------------|
| R-{N} | {title} | {score} | {why it's acceptable to not actively mitigate} |
| ... | | | |
```

## Instructions

When producing this document:

1. **Read ALL analysis and mapping outputs** to identify risks. Key sources:
   - `dependency-mapping.md`: NO_EQUIVALENT and LOW confidence mappings are dependency risks
   - `type-mapping.md`: "Requires Redesign" types are technical risks
   - `module-mapping.md`: "Very High" complexity modules are timeline risks
   - `error-hierarchy.md`: Complex error patterns are technical risks
   - `analysis/async-model.md`: Complex concurrency patterns are technical risks
2. **Every NO_EQUIVALENT dependency becomes a risk entry**. If there is no crate for a critical dependency, that is a risk.
3. **Risk descriptions must be specific**, not generic. "Prisma has no direct Rust equivalent; all 48 ORM queries must be rewritten as raw SQL" -- not "database migration may be complex".
4. **Source Evidence must reference the analysis document** where the risk was discovered. This creates traceability.
5. **Mitigation strategies must be actionable**: "Write a proof-of-concept query migration for the most complex query (TaskService.findWithFilters) before committing to full migration" -- not "plan carefully".
6. **Contingency plans must be realistic alternatives**: "If apalis cannot handle the job queue requirements, fall back to manual tokio::spawn with Redis polling" -- not "find another solution".
7. **Risk-to-Task Mapping** connects each risk to the roadmap tasks it affects and the risk multiplier applied to those tasks.
8. **Risk Monitoring Schedule** defines when to check if risks are materializing and what to do if they are.
9. **Do not invent risks that have no basis in the analysis**. Every risk should be traceable to a specific finding.
10. Write in the same language the user used to invoke the skill.

## Example

```markdown
# Risk Assessment

Source: taskflow-api
Generated: 2026-03-05

## Risk Summary

| Category | Total Risks | High Severity | Medium Severity | Low Severity |
|----------|------------|---------------|-----------------|-------------|
| Technical | 4 | 1 | 2 | 1 |
| Dependency | 2 | 1 | 1 | 0 |
| Timeline | 2 | 0 | 2 | 0 |
| Organizational | 1 | 0 | 0 | 1 |
| **Total** | **9** | **2** | **5** | **2** |

### Overall Risk Level: MEDIUM

Two high-severity risks (Prisma ORM replacement, BullMQ job queue migration) require active management. Remaining risks are manageable with standard mitigation practices.

## Risk Matrix

```text
              Low Impact      Medium Impact     High Impact
           +---------------+----------------+----------------+
High Prob  |               | R-6            |                |
           +---------------+----------------+----------------+
Med Prob   | R-9           | R-3, R-5, R-7  | R-1, R-2       |
           +---------------+----------------+----------------+
Low Prob   |               | R-8            | R-4             |
           +---------------+----------------+----------------+
```

## Technical Risks

### R-1: Prisma ORM queries require full rewrite as raw SQL

| Field | Value |
|-------|-------|
| Category | Technical |
| Description | The source project uses Prisma for all 48 database queries across 8 service files. Prisma provides relation loading, auto-generated types, and schema-first migrations. sqlx requires raw SQL with manual struct definitions and no relation auto-loading. Every query must be manually rewritten and tested for correctness. |
| Probability | Medium (certainty it must be done; risk is in effort underestimation) |
| Impact | High (affects all data access, which is the foundation of the application) |
| Risk Score | 6 |
| Affected Components | crates/db (all query modules), crates/services (all services depend on db) |
| Source Evidence | dependency-mapping.md -- @prisma/client rated MEDIUM confidence. type-mapping.md shows 18 Prisma-generated types. |

**Mitigation Strategy**: Start with a proof-of-concept: port the most complex query (TaskService.findWithFilters, which has 5 filter parameters, sorting, and pagination) to sqlx first. If this succeeds within 1 round, the remaining 47 queries are estimated correctly. If it takes longer, revise the M3 round estimate upward by 1.5x.

**Contingency Plan**: If raw sqlx proves too verbose for complex queries, switch to sea-orm which provides query builder patterns closer to Prisma. This adds ~2 rounds for switching mid-migration but reduces per-query effort.

**Owner**: Backend Developer

---

### R-3: Complex async patterns in notification service

| Field | Value |
|-------|-------|
| Category | Technical |
| Description | The NotificationService uses concurrent Promise.all() with error accumulation (settling all promises and collecting errors). This pattern requires careful translation to Rust's futures::join_all() with proper error handling. Source has 3 locations with this pattern. |
| Probability | Medium |
| Impact | Medium |
| Risk Score | 4 |
| Affected Components | crates/services/src/notification_service.rs |
| Source Evidence | analysis/async-model.md -- identified 3 instances of Promise.allSettled() pattern in notification sending |

**Mitigation Strategy**: Implement a utility function `settle_all<T, E>(futures: Vec<impl Future<Output = Result<T, E>>>) -> (Vec<T>, Vec<E>)` that mirrors the Promise.allSettled() behavior in Rust. Test this utility independently before using it in the notification service.

**Contingency Plan**: If concurrent notification sending proves too complex, switch to sequential processing with error logging. This loses parallelism but simplifies the code. Performance impact is minimal since notification sending is a background job.

**Owner**: Backend Developer

## Dependency Risks

### R-2: BullMQ job queue has no mature Rust equivalent

| Field | Value |
|-------|-------|
| Category | Dependency |
| Description | BullMQ provides Redis-backed job queues with delayed jobs, rate limiting, retries with exponential backoff, job prioritization, and a dashboard UI. The Rust equivalent (apalis) covers basic job queuing and retries but lacks BullMQ's dashboard, rate limiting, and job prioritization features. |
| Probability | Medium |
| Impact | High |
| Risk Score | 6 |
| Affected Components | crates/jobs (all job processors) |
| Source Evidence | dependency-mapping.md -- bullmq mapped to apalis with MEDIUM confidence. 6 job processor files use BullMQ features. |

**Mitigation Strategy**: Audit which BullMQ features are actually used vs. available. If only basic enqueue/process/retry is used, apalis is sufficient. If rate limiting or prioritization is needed, implement these on top of apalis using Redis sorted sets.

**Contingency Plan**: If apalis proves insufficient, implement a minimal job queue directly on Redis using the redis crate. This adds ~3 rounds but gives full control over job queue behavior.

**Owner**: Backend Developer

## Risk-to-Task Mapping

| Risk ID | Risk Title | Roadmap Tasks Affected | Risk Factor Applied |
|---------|-----------|----------------------|---------------------|
| R-1 | Prisma ORM rewrite | #12-#16 (database queries) | 1.3x |
| R-2 | BullMQ replacement | #24 (background jobs) | 1.5x |
| R-3 | Async notification patterns | #18 (notification service) | 1.3x |
| R-4 | JWT backward compatibility | #11 (auth module) | 1.2x |
| R-5 | Test coverage gap | #27-#29 (testing) | 1.2x |
| R-6 | Source tests not comprehensive | #27-#29 (testing) | 1.3x |
| R-7 | Complex validation rules | #6-#9 (core types) | 1.2x |
| R-8 | Database schema drift | #31 (migration setup) | 1.2x |
| R-9 | Team Rust learning curve | All phases | 1.0x (absorbed in base estimates) |

## Risk Monitoring Schedule

| Risk ID | Check Frequency | Trigger Condition | Escalation Action |
|---------|----------------|-------------------|-------------------|
| R-1 | After each db query module | Single query takes > 0.5 rounds | Revise M3 estimate, consider sea-orm |
| R-2 | After M4 task #24 starts | apalis cannot handle required features | Switch to manual Redis implementation |
| R-3 | After M3 task #18 | settle_all utility takes > 1 round | Switch to sequential processing |
```

## Quality Criteria

- [ ] Every NO_EQUIVALENT dependency from dependency-mapping.md has a corresponding risk entry
- [ ] Every "Very High" complexity module from module-mapping.md has a corresponding risk entry
- [ ] Every "Requires Redesign" type from type-mapping.md is represented in a risk entry
- [ ] Each risk has all required fields: Category, Description, Probability, Impact, Score, Evidence
- [ ] Descriptions are specific to this project (not generic "migration is hard" statements)
- [ ] Source Evidence traces back to a specific analysis or mapping document finding
- [ ] Mitigation strategies are actionable with specific steps
- [ ] Contingency plans provide a realistic alternative approach
- [ ] Risk Matrix visualization places all risk IDs correctly by probability and impact
- [ ] Risk-to-Task Mapping connects every high/medium risk to specific roadmap task IDs
- [ ] Risk factors in the mapping match the risk factors used in roadmap.md
- [ ] Risk Monitoring Schedule defines concrete check frequencies and trigger conditions
- [ ] Accepted Risks are justified (not just "we will deal with it later")
- [ ] Overall Risk Level assessment is justified with a clear rationale
