#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

check_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    ((PASS++))
    echo "  PASS: $desc"
  else
    ((FAIL++))
    echo "  FAIL: $desc — output does not contain '$needle'"
    echo "    output: $haystack"
  fi
}

echo "Running tests for: commit-msg-gen"
echo "=================================="

# --- Type detection ---
echo ""
echo "Type detection:"

# Pure additions => feat
RESULT=$(printf '+function validateEmail() {}' | "$SCRIPT_DIR/run.sh")
check_contains "pure additions detected as feat" "feat" "$RESULT"

# Doc file => docs
RESULT=$(printf '+++ b/README.md\n+## API Reference' | "$SCRIPT_DIR/run.sh")
check_contains "markdown file detected as docs" "docs" "$RESULT"

# Hint override
RESULT=$(printf '+some change' | "$SCRIPT_DIR/run.sh" --hint "fixing login bug")
check_contains "hint overrides to fix" "fix" "$RESULT"

RESULT=$(printf '+some change' | "$SCRIPT_DIR/run.sh" --hint "adding new feature")
check_contains "hint overrides to feat" "feat" "$RESULT"

# --- Scope detection ---
echo ""
echo "Scope detection:"

RESULT=$(printf '+++ b/src/auth/login.js\n+code' | "$SCRIPT_DIR/run.sh")
check_contains "scope from file path" "auth" "$RESULT"

RESULT=$(printf '+code' | "$SCRIPT_DIR/run.sh" --scope api)
check_contains "manual scope override" "api" "$RESULT"

# --- Format ---
echo ""
echo "Output format:"

RESULT=$(printf '+new feature' | "$SCRIPT_DIR/run.sh" --format json)
check_contains "JSON has type field" '"type"' "$RESULT"
check_contains "JSON has full field" '"full"' "$RESULT"

# --- Help ---
echo ""
echo "Help:"

RESULT=$("$SCRIPT_DIR/run.sh" --help 2>&1)
check_contains "help shows usage" "Usage" "$RESULT"

# --- Error ---
echo ""
echo "Error handling:"

RESULT=$(echo "" | "$SCRIPT_DIR/run.sh" 2>&1 || true)
check_contains "empty input error" "Error" "$RESULT"

echo ""
echo "=================================="
echo "Results: $PASS passed, $FAIL failed, $((PASS + FAIL)) total"
[ "$FAIL" -eq 0 ] || exit 1
