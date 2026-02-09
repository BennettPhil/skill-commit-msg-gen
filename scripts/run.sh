#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: run.sh [OPTIONS]"
  echo ""
  echo "Generate conventional commit messages from git diffs."
  echo "Reads unified diff from stdin."
  echo ""
  echo "Options:"
  echo "  --format FORMAT   Output format: text (default), json"
  echo "  --hint TEXT       Context hint to guide message generation"
  echo "  --scope SCOPE     Override the scope"
  echo "  --help            Show this help"
}

FORMAT="text"
HINT=""
SCOPE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --hint) HINT="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DIFF_INPUT=$(cat)

if [ -z "$DIFF_INPUT" ]; then
  echo "Error: no diff input. Pipe a git diff into this command." >&2
  exit 1
fi

python3 -c "
import sys, json, re, os

diff_text = sys.stdin.read()
fmt = '$FORMAT'
hint = '$HINT'
scope_override = '$SCOPE'

lines = diff_text.strip().split('\n')

# Parse diff for files and change patterns
files_changed = []
additions = []
removals = []

for line in lines:
    if line.startswith('+++ b/') or line.startswith('+++ '):
        path = line.replace('+++ b/', '').replace('+++ ', '').strip()
        if path != '/dev/null':
            files_changed.append(path)
    elif line.startswith('+') and not line.startswith('+++'):
        additions.append(line[1:].strip())
    elif line.startswith('-') and not line.startswith('---'):
        removals.append(line[1:].strip())

add_count = len(additions)
rem_count = len(removals)
add_text = ' '.join(additions).lower()
rem_text = ' '.join(removals).lower()
all_text = add_text + ' ' + rem_text

# Determine scope from file paths
scope = scope_override
if not scope and files_changed:
    # Use first directory or file name
    first_file = files_changed[0]
    parts = first_file.split('/')
    if len(parts) > 1:
        scope = parts[0] if parts[0] not in ('src', 'lib', 'app') else (parts[1] if len(parts) > 1 else parts[0])
    else:
        scope = os.path.splitext(parts[0])[0]

# Determine commit type
commit_type = 'chore'  # default

# Check hint first
if hint:
    hint_lower = hint.lower()
    if any(w in hint_lower for w in ['fix', 'bug', 'resolve', 'correct', 'patch']):
        commit_type = 'fix'
    elif any(w in hint_lower for w in ['feat', 'add', 'new', 'implement', 'create']):
        commit_type = 'feat'
    elif any(w in hint_lower for w in ['refactor', 'restructure', 'reorganize', 'clean']):
        commit_type = 'refactor'
    elif any(w in hint_lower for w in ['doc', 'readme', 'comment']):
        commit_type = 'docs'
    elif any(w in hint_lower for w in ['test', 'spec']):
        commit_type = 'test'
    elif any(w in hint_lower for w in ['style', 'format', 'lint']):
        commit_type = 'style'
else:
    # Heuristic from diff content
    doc_exts = ['.md', '.txt', '.rst', '.adoc']
    test_patterns = ['test', 'spec', '__test__', '.test.']

    if files_changed and all(any(f.endswith(ext) for ext in doc_exts) for f in files_changed):
        commit_type = 'docs'
    elif files_changed and all(any(p in f.lower() for p in test_patterns) for f in files_changed):
        commit_type = 'test'
    elif add_count > 0 and rem_count == 0:
        commit_type = 'feat'
    elif rem_count > add_count * 2:
        commit_type = 'refactor'
    elif any(w in all_text for w in ['fix', 'bug', 'error', 'issue', 'correct', 'patch']):
        commit_type = 'fix'
    elif add_count > 0 and rem_count > 0 and abs(add_count - rem_count) < max(add_count, rem_count) * 0.3:
        commit_type = 'refactor'
    elif add_count > 0:
        commit_type = 'feat'

# Generate message summary
if hint:
    # Use hint as basis
    msg = hint.strip().lower()
    # Remove leading type words
    for prefix in ['fix:', 'feat:', 'add', 'fix', 'update', 'change']:
        if msg.startswith(prefix):
            msg = msg[len(prefix):].strip()
    msg = msg[:50]
else:
    # Generate from diff content
    if commit_type == 'docs':
        if additions:
            first_add = additions[0][:40]
            msg = f'add documentation for {first_add}' if first_add else 'update documentation'
        else:
            msg = 'update documentation'
    elif commit_type == 'test':
        msg = 'add test cases'
    elif files_changed:
        base_name = os.path.splitext(os.path.basename(files_changed[0]))[0]
        if commit_type == 'feat':
            msg = f'add {base_name} functionality'
        elif commit_type == 'fix':
            msg = f'resolve issue in {base_name}'
        elif commit_type == 'refactor':
            msg = f'restructure {base_name}'
        else:
            msg = f'update {base_name}'
    else:
        # No file info, use content
        if additions and additions[0]:
            snippet = additions[0][:30].strip()
            msg = f'add {snippet}'
        else:
            msg = 'update codebase'

# Build conventional commit
if scope:
    full_msg = f'{commit_type}({scope}): {msg}'
else:
    full_msg = f'{commit_type}: {msg}'

if fmt == 'json':
    result = {
        'type': commit_type,
        'scope': scope if scope else None,
        'message': msg,
        'full': full_msg
    }
    print(json.dumps(result, indent=2))
else:
    print(full_msg)
" <<< "$DIFF_INPUT"
