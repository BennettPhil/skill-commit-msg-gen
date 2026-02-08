# Examples

## New Feature Files

Staged: `src/auth/login.js` (new file)

```
feat(auth): add login.js
```

## Bug Fix

Staged: `src/utils/parser.py` (modified, diff contains "fix" and "error")

```
fix(utils): update parser.py
```

## Documentation Only

Staged: `README.md`, `docs/setup.md`

```
docs: update README.md and setup.md
```

## Error: No Staged Changes

```bash
python3 scripts/run.py
# Error: no staged changes found. Stage files with git add first.
# Exit code: 1
```
