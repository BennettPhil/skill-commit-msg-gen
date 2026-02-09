# Basic Example

> Generate a commit message from a git diff.

## What You Will Learn

How to use commit-msg-gen to produce conventional commit messages from staged changes.

## Step 1: Generate from Diff

Pipe a git diff into the tool:

```bash
git diff --cached | ./scripts/run.sh
```

Expected output:

```
feat: add user authentication middleware
```

## Step 2: With Context

Add a hint for better messages:

```bash
git diff --cached | ./scripts/run.sh --hint "fixing login bug"
```

Expected output:

```
fix: resolve login session expiry handling
```

## Next Steps

- See [Common Patterns](./common-patterns.md) for more usage
