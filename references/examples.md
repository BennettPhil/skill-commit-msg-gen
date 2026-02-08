# commit-msg-gen Examples

## Basic Usage

Generate a commit message from staged changes:

```bash
git diff --cached | .soup/skills/commit-msg-gen/scripts/run.sh
```

Output:
```
feat(auth): add login.py
```

## JSON Output

```bash
git diff --cached | .soup/skills/commit-msg-gen/scripts/run.sh --format=json
```

Output:
```json
{"type": "feat", "scope": "auth", "summary": "add login.py", "message": "feat(auth): add login.py"}
```

## From a Diff File

```bash
git diff --cached > /tmp/changes.diff
.soup/skills/commit-msg-gen/scripts/run.sh --diff-file=/tmp/changes.diff
```

## Integration with Git Workflow

### As a Pre-commit Helper

```bash
# In your workflow:
MSG=$(git diff --cached | .soup/skills/commit-msg-gen/scripts/run.sh)
git commit -m "$MSG"
```

### Review Before Committing

```bash
git diff --cached | .soup/skills/commit-msg-gen/scripts/run.sh --format=json | python3 -m json.tool
```

## Type Detection Examples

| Change | Detected Type |
|--------|---------------|
| New `auth/login.py` | `feat` |
| Fix bug in `parser.py` (keyword: "fix bug") | `fix` |
| Update `tests/test_parser.py` | `test` |
| Edit `README.md` | `docs` |
| Modify `.gitignore` | `chore` |
| Reformat `app.py` (whitespace only) | `style` |
| Restructure `engine.py` (balanced add/delete) | `refactor` |

## Scope Detection Examples

| Files Changed | Scope |
|---------------|-------|
| `auth/login.py` | `auth` |
| `README.md` | `readme` |
| `src/api.py`, `src/models.py` | `src` |
| `api/routes.py`, `lib/utils.py` | most-changed dir |
