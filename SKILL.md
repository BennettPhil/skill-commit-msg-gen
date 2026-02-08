---
name: commit-msg-gen
description: Generate conventional commit messages by analyzing staged git changes to detect type and scope.
version: 0.1.0
license: Apache-2.0
---

# Commit Message Generator

## Purpose

Analyzes staged git changes (`git diff --cached`) and produces a conventional commit message. Detects the commit type (feat, fix, refactor, etc.) and scope from file paths and diff content.

## Quick Start

```bash
# Stage your changes, then:
python3 scripts/run.py
```

## Reference Index

- [references/api.md](references/api.md) — CLI flags, type detection rules, exit codes
- [references/usage-guide.md](references/usage-guide.md) — Walkthrough of common workflows
- [references/examples.md](references/examples.md) — Example diffs and generated messages

## Implementation

See `scripts/run.py` — Python script using `subprocess` to read git state.
