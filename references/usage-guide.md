# Usage Guide

## Basic Workflow

```bash
git add src/auth/login.js
python3 scripts/run.py
# Output: feat(auth): add login.js
```

## With Body

```bash
python3 scripts/run.py --body
# Output includes a summary of changed files
```

## Override Type

```bash
python3 scripts/run.py --type fix
# Forces "fix" type regardless of detection
```

## JSON Output

```bash
python3 scripts/run.py --format json
# {"type": "feat", "scope": "auth", "subject": "add login.js", "body": ""}
```

## Dry Run

```bash
python3 scripts/run.py --dry-run
# Shows the message without creating a commit
```
