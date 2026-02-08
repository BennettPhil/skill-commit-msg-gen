#!/usr/bin/env python3
"""
Analyze a unified diff and produce a conventional commit message.

Reads from stdin or --diff-file=PATH. Outputs a message like:
  feat(auth): add login endpoint

Supports --format=json for structured output.
"""

import sys
import re
import os
import json


def parse_args(argv):
    """Parse CLI arguments."""
    opts = {"diff_file": None, "format": "text"}
    for arg in argv[1:]:
        if arg.startswith("--diff-file="):
            opts["diff_file"] = arg.split("=", 1)[1]
        elif arg.startswith("--format="):
            opts["format"] = arg.split("=", 1)[1]
    return opts


def read_diff(opts):
    """Read diff from file or stdin."""
    if opts["diff_file"]:
        with open(opts["diff_file"], "r") as f:
            return f.read()
    else:
        if sys.stdin.isatty():
            print("Error: no diff provided. Pipe a diff via stdin or use --diff-file=PATH", file=sys.stderr)
            sys.exit(1)
        return sys.stdin.read()


def parse_diff(raw):
    """Parse unified diff into structured file-level info."""
    files = []
    current = None
    for line in raw.splitlines():
        # Detect file header
        m = re.match(r'^diff --git a/(.*) b/(.*)', line)
        if m:
            current = {
                "old_path": m.group(1),
                "new_path": m.group(2),
                "is_new": False,
                "is_deleted": False,
                "added_lines": [],
                "deleted_lines": [],
            }
            files.append(current)
            continue
        if current is None:
            continue
        if line.startswith("new file mode"):
            current["is_new"] = True
        elif line.startswith("deleted file mode"):
            current["is_deleted"] = True
        elif line.startswith("+") and not line.startswith("+++"):
            current["added_lines"].append(line[1:])
        elif line.startswith("-") and not line.startswith("---"):
            current["deleted_lines"].append(line[1:])
    return files


# --------------- type detection ---------------

BUG_KEYWORDS = re.compile(r'\b(fix|bug|error|issue|patch|crash|fault|defect|broken|wrong|incorrect)\b', re.IGNORECASE)
CHORE_PATTERNS = re.compile(
    r'(^\.gitignore$|^Makefile$|^Dockerfile$|^docker-compose|^\.github/|^\.circleci/|^\.gitlab-ci'
    r'|^Jenkinsfile$|^package\.json$|^package-lock\.json$|^yarn\.lock$|^Gemfile$|^Gemfile\.lock$'
    r'|^\.eslintrc|^\.prettierrc|^tsconfig|^setup\.cfg$|^setup\.py$|^pyproject\.toml$'
    r'|^Cargo\.toml$|^Cargo\.lock$|^go\.mod$|^go\.sum$|^\.env)'
)
DOC_PATTERNS = re.compile(r'(\.md$|^README|^docs/|^CHANGELOG|^LICENSE|^CONTRIBUTING)', re.IGNORECASE)
TEST_PATTERNS = re.compile(r'(test_|_test\.|\.test\.|\.spec\.|/tests/|/test/|/__tests__/)', re.IGNORECASE)


def _normalize_ws(s):
    """Strip all whitespace for style-change comparison."""
    return re.sub(r'\s+', '', s)


def is_style_only(f):
    """Check if changes are formatting-only (whitespace differences)."""
    if not f["added_lines"] or not f["deleted_lines"]:
        return False
    if abs(len(f["added_lines"]) - len(f["deleted_lines"])) > max(1, len(f["added_lines"]) // 3):
        return False
    for a, d in zip(f["added_lines"], f["deleted_lines"]):
        if _normalize_ws(a) != _normalize_ws(d):
            return False
    return True


def is_refactor(f):
    """Heuristic: similar number of adds and deletes in same file, no new/deleted file."""
    if f["is_new"] or f["is_deleted"]:
        return False
    a = len(f["added_lines"])
    d = len(f["deleted_lines"])
    if a == 0 or d == 0:
        return False
    ratio = min(a, d) / max(a, d)
    return ratio > 0.5 and a >= 3


def detect_type(files):
    """Determine commit type from parsed file info."""
    if not files:
        return "chore"

    # Collect per-file signals
    signals = {
        "feat": 0, "fix": 0, "test": 0, "docs": 0,
        "chore": 0, "style": 0, "refactor": 0,
    }

    for f in files:
        path = f["new_path"]

        # Test files
        if TEST_PATTERNS.search(path):
            signals["test"] += 1
            continue

        # Doc files
        if DOC_PATTERNS.search(path):
            signals["docs"] += 1
            continue

        # Chore / config files
        if CHORE_PATTERNS.search(path):
            signals["chore"] += 1
            continue

        # New file -> feat
        if f["is_new"]:
            signals["feat"] += 1
            continue

        # Bug-related keywords in added lines -> fix
        added_text = "\n".join(f["added_lines"])
        if BUG_KEYWORDS.search(added_text):
            signals["fix"] += 1
            continue

        # Style-only
        if is_style_only(f):
            signals["style"] += 1
            continue

        # Refactor heuristic
        if is_refactor(f):
            signals["refactor"] += 1
            continue

        # New functions/classes added to existing file -> feat
        func_pattern = re.compile(r'^\s*(def |function |class |const \w+ = |export )')
        if any(func_pattern.match(l) for l in f["added_lines"]):
            signals["feat"] += 1
            continue

        # Fallback
        signals["chore"] += 1

    # Pick highest signal
    best = max(signals, key=lambda k: signals[k])
    if signals[best] == 0:
        return "chore"
    return best


# --------------- scope detection ---------------

def detect_scope(files):
    """Derive scope from the most-changed directory or file."""
    if not files:
        return ""

    # Count changes per file
    change_counts = {}
    for f in files:
        path = f["new_path"]
        count = len(f["added_lines"]) + len(f["deleted_lines"])
        change_counts[path] = count

    if not change_counts:
        return ""

    # If single file
    if len(change_counts) == 1:
        path = list(change_counts.keys())[0]
        parts = path.split("/")
        if len(parts) == 1:
            # Root-level file: use filename without extension
            name = parts[0]
            return os.path.splitext(name)[0].lower()
        else:
            return parts[0].lower()

    # Multiple files: find the most-changed file's directory
    most_changed = max(change_counts, key=change_counts.get)
    dirs = set()
    for path in change_counts:
        parts = path.split("/")
        if len(parts) > 1:
            dirs.add(parts[0])
        else:
            dirs.add(os.path.splitext(parts[0])[0])

    # If all in the same top-level dir, use that
    if len(dirs) == 1:
        return dirs.pop().lower()

    # Use most-changed file's directory
    parts = most_changed.split("/")
    if len(parts) > 1:
        return parts[0].lower()
    return os.path.splitext(parts[0])[0].lower()


# --------------- summary generation ---------------

def detect_summary(files, commit_type):
    """Generate a brief summary of what changed."""
    if not files:
        return "empty change"

    # Collect filenames
    names = [f["new_path"].split("/")[-1] for f in files]

    if len(files) == 1:
        f = files[0]
        name = f["new_path"].split("/")[-1]
        if f["is_new"]:
            return f"add {name}"
        elif f["is_deleted"]:
            return f"remove {name}"
        else:
            if commit_type == "fix":
                return f"fix issue in {name}"
            elif commit_type == "refactor":
                return f"refactor {name}"
            elif commit_type == "style":
                return f"format {name}"
            elif commit_type == "docs":
                return f"update {name}"
            elif commit_type == "test":
                return f"update tests in {name}"
            else:
                return f"update {name}"
    else:
        new_count = sum(1 for f in files if f["is_new"])
        del_count = sum(1 for f in files if f["is_deleted"])
        mod_count = len(files) - new_count - del_count

        parts = []
        if new_count:
            parts.append(f"add {new_count} file{'s' if new_count > 1 else ''}")
        if del_count:
            parts.append(f"remove {del_count} file{'s' if del_count > 1 else ''}")
        if mod_count:
            parts.append(f"update {mod_count} file{'s' if mod_count > 1 else ''}")

        return ", ".join(parts) if parts else f"update {len(files)} files"


# --------------- main ---------------

def main():
    opts = parse_args(sys.argv)
    raw = read_diff(opts)

    if not raw.strip():
        print("Error: empty diff", file=sys.stderr)
        sys.exit(1)

    files = parse_diff(raw)

    if not files:
        print("Error: no file changes found in diff", file=sys.stderr)
        sys.exit(1)

    commit_type = detect_type(files)
    scope = detect_scope(files)
    summary = detect_summary(files, commit_type)

    if scope:
        message = f"{commit_type}({scope}): {summary}"
    else:
        message = f"{commit_type}: {summary}"

    if opts["format"] == "json":
        result = {
            "type": commit_type,
            "scope": scope,
            "summary": summary,
            "message": message,
        }
        print(json.dumps(result))
    else:
        print(message)


if __name__ == "__main__":
    main()
