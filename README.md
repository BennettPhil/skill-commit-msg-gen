# commit-msg-gen

Generate conventional commit messages by analyzing staged git changes.

## Prerequisites

- Python 3.10+
- Git

## Quick Start

```bash
git add src/auth/login.js
python3 scripts/run.py
# feat(auth): add login.js
```

See [references/usage-guide.md](references/usage-guide.md) for detailed usage.
See [references/api.md](references/api.md) for type detection rules and flags.
