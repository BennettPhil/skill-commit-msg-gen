---
name: commit-msg-gen
description: Generate conventional commit messages from git diffs using heuristic analysis.
version: 0.1.0
license: Apache-2.0
---

# Commit Message Generator

Generate conventional commit messages from git diffs using heuristic analysis of the changes.

## See It in Action

Start with [examples/basic-example.md](examples/basic-example.md) to see it working in 30 seconds.

## Examples Index

| Example | Description |
|---------|-------------|
| [Basic Example](examples/basic-example.md) | Generate your first commit message from a diff |
| [Common Patterns](examples/common-patterns.md) | Feature additions, bug fixes, refactoring, docs |

## Reference

| Option | Default | Description |
|--------|---------|-------------|
| `--format` | `text` | Output: text or json |
| `--hint` | none | Context hint to guide message generation |
| `--scope` | auto | Override the scope (e.g., `auth`, `api`) |
| `--help` | - | Show usage |

## How It Works

1. Reads a unified diff from stdin
2. Analyzes additions/removals to determine change type (feat, fix, refactor, docs, chore, style, test)
3. Extracts affected file paths to determine scope
4. Generates a concise summary message
5. Outputs in conventional commit format: `type(scope): message`
