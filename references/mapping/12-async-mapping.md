# 12 - Async Mapping

**Output**: `.migration-plan/mappings/async-strategy.md`

Map every async/concurrency pattern to its Rust tokio equivalent.

## Method

1. Read `.migration-plan/analysis/async-model.md` -- get all async patterns
2. Read `ref/{language}.md` -- consult the Async Patterns section
3. Choose async runtime: tokio (default) or async-std (rare)
4. For EACH async pattern found:
   a. Determine Rust equivalent (see ref table)
   b. Check if data crosses task boundaries (needs Send + 'static)
   c. Check shared mutable state (needs Arc<Mutex<T>> or similar)
5. Design cancellation strategy if applicable

## Template

```markdown
# Async Strategy

Runtime: tokio 1.x
Async functions: {N} | Spawn points: {N} | Shared state items: {N}

## Runtime Configuration

\`\`\`rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // ...
}
\`\`\`

## Pattern Mapping

| Source Pattern | Source Location | Rust Equivalent |
|---------------|----------------|-----------------|
| Promise.all([a, b, c]) | [api.ts:30] | `tokio::join!(a, b, c)` |
| setTimeout(fn, 1000) | [worker.ts:15] | `tokio::time::sleep(Duration::from_secs(1))` |
| EventEmitter.on('x') | [events.ts:5] | `tokio::sync::broadcast::channel` |
{EVERY async pattern}

## Shared State Plan

| State | Current | Rust Equivalent | Why |
|-------|---------|-----------------|-----|
| cache | module var | `Arc<DashMap<K,V>>` | Concurrent reads+writes |
| db pool | singleton | `sqlx::PgPool` (already Arc) | Built-in pooling |
{EVERY shared mutable state}

## Send + Sync Analysis

| Data | Crosses task boundary | Send? | Fix needed |
|------|----------------------|-------|-----------|
| User struct | Yes (spawned task) | Yes if owned | Ensure no Rc |
{items that cross boundaries}
```
