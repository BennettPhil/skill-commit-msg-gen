# API Reference

## Command

```
python3 scripts/run.py [OPTIONS]
```

## Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--repo` | string | `.` | Path to git repository |
| `--scope` | string | auto | Override auto-detected scope |
| `--type` | string | auto | Override auto-detected type |
| `--body` | flag | false | Include a body section with file change summary |
| `--dry-run` | flag | false | Show the message without committing |
| `--format` | string | text | Output: `text` or `json` |
| `-h, --help` | flag | - | Show help message |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | No staged changes |
| 2 | Not a git repository |

## Type Detection Rules

| Condition | Detected Type |
|-----------|--------------|
| New files added (no deletions) | `feat` |
| Only test files changed | `test` |
| Only doc/README files changed | `docs` |
| Only config files (.json, .yml, .toml) changed | `chore` |
| Deletions outnumber additions | `refactor` |
| Bug-related keywords in diff (fix, bug, error, patch) | `fix` |
| Performance keywords (perf, optimize, cache, speed) | `perf` |
| Style-only changes (whitespace, formatting) | `style` |
| Default for mixed changes | `feat` |

## Scope Detection

Scope is inferred from the most common directory prefix among changed files:
- `src/auth/login.js` → scope: `auth`
- `tests/utils.test.py` → scope: `utils`
- Files in project root → no scope
