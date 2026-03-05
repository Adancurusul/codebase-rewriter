# 03 - Async and Concurrency Analysis

**Output**: `.migration-plan/analysis/async-model.md`

Catalog every async/concurrent pattern in the source codebase.

## Method

1. Grep for async patterns:
   - TS: `async\s+`, `await\s+`, `Promise`, `setTimeout`, `setInterval`, `EventEmitter`
   - Python: `async\s+def`, `await\s+`, `asyncio\.`, `threading\.`, `multiprocessing`
   - Go: `go\s+func`, `go\s+\w+`, `<-`, `chan\s+`, `sync\.`, `context\.`
2. For EACH async site: identify what it awaits, whether it's CPU or IO bound, whether data crosses thread boundaries
3. Identify shared mutable state accessed from async contexts

## Template

```markdown
# Async Model

Runtime: {Node.js single-thread / asyncio / goroutines}
Async functions: {N} | Await sites: {N} | Shared state: {N}

## Async Functions

| Function | Source | Awaits | Sends across boundary | Notes |
|----------|--------|--------|-----------------------|-------|
| getUser | [user-service.ts:10](../src/user-service.ts#L10) | db query | No | IO-bound |
| processBatch | [worker.ts:5](../src/worker.ts#L5) | HTTP + DB | Yes (queue) | Fan-out |
{EVERY async function}

## Concurrency Patterns

| Pattern | Source | Description |
|---------|--------|-------------|
| Promise.all fan-out | [api.ts:30](../src/api.ts#L30) | 5 parallel HTTP calls |
| Event listener | [events.ts:10](../src/events.ts#L10) | on('order.created', handler) |
{EVERY concurrency pattern}

## Shared Mutable State

| State | Source | Accessed from | Needs Arc/Mutex |
|-------|--------|--------------|-----------------|
| cache | [cache.ts:1](../src/cache.ts#L1) | multiple handlers | Yes |
{EVERY shared mutable state}
```
