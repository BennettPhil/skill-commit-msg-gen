---
name: commit-msg-gen
description: Analyzes staged git changes and produces conventional commit messages. Detects type (feat, fix, refactor, etc.) and scope from the diff.
version: 0.1.0
license: Apache-2.0
---

# commit-msg-gen

A commit message generator that analyzes staged git changes (unified diff format)
and produces a conventional commit message.

## Usage

```bash
git diff --cached | ./scripts/run.sh
```

Or with a diff file:

```bash
./scripts/run.sh --diff-file=changes.diff
```

## Output

Default: a single-line conventional commit message, e.g.:

```
feat(auth): add login endpoint
```

With `--format=json`:

```json
{"type": "feat", "scope": "auth", "summary": "add login endpoint", "message": "feat(auth): add login endpoint"}
```

## Type Detection

| Type     | Heuristic                                              |
|----------|--------------------------------------------------------|
| feat     | New files or new functions added                       |
| fix      | Bug-related keywords in added lines                    |
| refactor | Restructuring (similar add/delete counts in same file) |
| docs     | Markdown or documentation file changes                 |
| test     | Test file changes                                      |
| style    | Formatting-only changes (whitespace, indentation)      |
| chore    | Config files, CI, build system                         |
