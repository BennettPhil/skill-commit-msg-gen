# Commit Message Generator

Generate conventional commit messages from git diffs.

```bash
git diff --cached | ./scripts/run.sh
# => feat(auth): add login validation
```

## Prerequisites

- Python 3.6+

## Usage

```bash
# From staged changes
git diff --cached | ./scripts/run.sh

# With a hint
git diff --cached | ./scripts/run.sh --hint "fixing auth bug"

# JSON output
git diff --cached | ./scripts/run.sh --format json
```

## Examples

See `examples/` for detailed usage patterns.

## Test

```bash
./scripts/test-examples.sh
```
