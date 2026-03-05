# Codebase Rewriter

Ultra-detailed migration planning tool for rewriting codebases from TypeScript, Python, or Go to Rust.

## What It Does

Analyzes source codebases and generates exhaustive migration plans where **every type, every dependency, every module** has a concrete Rust migration strategy. The output is detailed enough for dev-workflow to execute mechanically.

## Pipeline

```
codebase-explorer     ->  codebase-rewriter     ->  dev-workflow
(understand code)         (plan Rust migration)     (execute rewrite)
```

## Supported Source Languages

| Language | Priority | Difficulty |
|----------|----------|------------|
| Go | High | Medium |
| TypeScript | High | High |
| Python | High | Very High |

## Quick Start

```bash
# Install into your project
./install.sh /path/to/your/project

# Or install as symlink (for development)
./install.sh /path/to/your/project --symlink

# Then in Claude Code:
/codebase-rewriter
```

## Output

Generates `.migration-plan/` directory with:

- **analysis/**: Deep source code analysis (types, errors, async, deps, architecture)
- **mappings/**: Concrete Rust equivalents for every source construct
- **migration-plan.md**: Executive summary
- **feasibility-report.md**: Should you rewrite?
- **dev-workflow/**: Ready-to-execute roadmap for dev-workflow

## Detail Level

Every mapping includes actual Rust code:

```
Source (TypeScript):
  interface User { id: string; email: string | null; }

Target (Rust):
  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct User {
      pub id: Uuid,
      pub email: Option<String>,
  }
```

## Installation

### Per-project (recommended)

```bash
./install.sh /path/to/project
```

### Global skill

```bash
mkdir -p ~/.claude/skills
ln -sfn /path/to/codebase-rewriter ~/.claude/skills/codebase-rewriter
```

### Uninstall

```bash
./install.sh /path/to/project --uninstall
```
