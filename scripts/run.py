#!/usr/bin/env python3
"""Generate conventional commit messages from staged git changes."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

DOC_PATTERNS = {".md", ".txt", ".rst", ".adoc"}
CONFIG_PATTERNS = {".json", ".yml", ".yaml", ".toml", ".ini", ".cfg", ".conf", ".env"}
TEST_PATTERNS = {"test", "spec", "__tests__", "tests"}
FIX_KEYWORDS = {"fix", "bug", "error", "patch", "issue", "crash", "broken"}
PERF_KEYWORDS = {"perf", "optimize", "cache", "speed", "fast", "slow", "memory"}


def git(args: list[str], repo: str = ".") -> tuple[int, str]:
    result = subprocess.run(["git", "-C", repo] + args, capture_output=True, text=True)
    return result.returncode, result.stdout.strip()


def get_staged_files(repo: str) -> list[dict]:
    code, output = git(["diff", "--cached", "--name-status"], repo)
    if code != 0 or not output:
        return []
    files = []
    for line in output.split("\n"):
        if not line.strip():
            continue
        parts = line.split("\t", 1)
        if len(parts) == 2:
            files.append({"status": parts[0][0], "path": parts[1]})
    return files


def get_diff_content(repo: str) -> str:
    code, output = git(["diff", "--cached"], repo)
    return output if code == 0 else ""


def detect_type(files: list[dict], diff_content: str) -> str:
    if not files:
        return "chore"

    paths = [f["path"] for f in files]
    statuses = [f["status"] for f in files]

    # All new files
    if all(s == "A" for s in statuses):
        return "feat"

    # All test files
    if all(any(tp in p.lower() for tp in TEST_PATTERNS) for p in paths):
        return "test"

    # All doc files
    if all(Path(p).suffix.lower() in DOC_PATTERNS for p in paths):
        return "docs"

    # All config files
    if all(Path(p).suffix.lower() in CONFIG_PATTERNS for p in paths):
        return "chore"

    # Check diff content for keywords
    diff_lower = diff_content.lower()
    if any(kw in diff_lower for kw in FIX_KEYWORDS):
        return "fix"

    if any(kw in diff_lower for kw in PERF_KEYWORDS):
        return "perf"

    # More deletions than additions
    added = diff_lower.count("\n+") - diff_lower.count("\n+++")
    removed = diff_lower.count("\n-") - diff_lower.count("\n---")
    if removed > added and removed > 5:
        return "refactor"

    return "feat"


def detect_scope(files: list[dict]) -> str:
    if not files:
        return ""

    # Find common directory prefix
    dirs = []
    for f in files:
        parts = Path(f["path"]).parts
        if len(parts) > 1:
            dirs.append(parts[1] if parts[0] in ("src", "lib", "app", "pkg") and len(parts) > 2 else parts[0] if parts[0] not in ("src", "lib", "app", "pkg") else (parts[1] if len(parts) > 1 else ""))
        # Root-level files have no scope

    if not dirs or all(d == "" for d in dirs):
        return ""

    # Most common non-empty directory
    dir_counts: dict[str, int] = {}
    for d in dirs:
        if d:
            dir_counts[d] = dir_counts.get(d, 0) + 1

    if not dir_counts:
        return ""

    return max(dir_counts, key=dir_counts.get)


def generate_subject(files: list[dict], commit_type: str) -> str:
    if len(files) == 1:
        path = files[0]["path"]
        name = Path(path).name
        status = files[0]["status"]
        if status == "A":
            return f"add {name}"
        elif status == "D":
            return f"remove {name}"
        else:
            return f"update {name}"
    else:
        # Multiple files
        file_count = len(files)
        if commit_type == "docs":
            names = [Path(f["path"]).name for f in files[:3]]
            return "update " + " and ".join(names) if len(names) <= 2 else f"update {file_count} doc files"
        elif commit_type == "test":
            return f"update {file_count} test files"
        else:
            added = sum(1 for f in files if f["status"] == "A")
            modified = sum(1 for f in files if f["status"] == "M")
            deleted = sum(1 for f in files if f["status"] == "D")
            parts = []
            if added:
                parts.append(f"add {added} file{'s' if added > 1 else ''}")
            if modified:
                parts.append(f"update {modified} file{'s' if modified > 1 else ''}")
            if deleted:
                parts.append(f"remove {deleted} file{'s' if deleted > 1 else ''}")
            return ", ".join(parts) if parts else f"update {file_count} files"


def generate_body(files: list[dict]) -> str:
    lines = ["Files changed:", ""]
    for f in files:
        status_word = {"A": "added", "M": "modified", "D": "deleted", "R": "renamed"}.get(f["status"], "changed")
        lines.append(f"- {f['path']} ({status_word})")
    return "\n".join(lines)


def main():
    args = sys.argv[1:]
    if "--help" in args or "-h" in args:
        print("Usage: run.py [OPTIONS]")
        print()
        print("Generate a conventional commit message from staged git changes.")
        print()
        print("Options:")
        print("  --repo PATH     Path to git repository (default: .)")
        print("  --scope SCOPE   Override auto-detected scope")
        print("  --type TYPE     Override auto-detected type")
        print("  --body          Include body with file change summary")
        print("  --dry-run       Show message without committing")
        print("  --format FMT    Output: text or json (default: text)")
        print("  -h, --help      Show this help")
        sys.exit(0)

    repo = "."
    override_scope = None
    override_type = None
    include_body = False
    dry_run = False
    fmt = "text"

    i = 0
    while i < len(args):
        if args[i] == "--repo" and i + 1 < len(args):
            repo = args[i + 1]; i += 2
        elif args[i] == "--scope" and i + 1 < len(args):
            override_scope = args[i + 1]; i += 2
        elif args[i] == "--type" and i + 1 < len(args):
            override_type = args[i + 1]; i += 2
        elif args[i] == "--body":
            include_body = True; i += 1
        elif args[i] == "--dry-run":
            dry_run = True; i += 1
        elif args[i] == "--format" and i + 1 < len(args):
            fmt = args[i + 1]; i += 2
        else:
            i += 1

    # Verify repo
    code, _ = git(["rev-parse", "--git-dir"], repo)
    if code != 0:
        print(f"Error: {repo} is not a git repository", file=sys.stderr)
        sys.exit(2)

    files = get_staged_files(repo)
    if not files:
        print("Error: no staged changes found. Stage files with git add first.", file=sys.stderr)
        sys.exit(1)

    diff_content = get_diff_content(repo)
    commit_type = override_type or detect_type(files, diff_content)
    scope = override_scope if override_scope is not None else detect_scope(files)
    subject = generate_subject(files, commit_type)

    scope_str = f"({scope})" if scope else ""
    message = f"{commit_type}{scope_str}: {subject}"

    body = ""
    if include_body:
        body = generate_body(files)

    if fmt == "json":
        result = json.dumps({
            "type": commit_type,
            "scope": scope,
            "subject": subject,
            "body": body,
            "message": message + ("\n\n" + body if body else ""),
        }, indent=2) + "\n"
        print(result, end="")
    else:
        print(message)
        if body:
            print()
            print(body)


if __name__ == "__main__":
    main()
