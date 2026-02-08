#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZE="$SCRIPT_DIR/analyze.py"

PASS=0
FAIL=0
ERRORS=""

run_test() {
    local name="$1"
    local input="$2"
    local expected="$3"
    local extra_args="${4:-}"

    local output
    if [ -n "$extra_args" ]; then
        output=$(echo "$input" | python3 "$ANALYZE" $extra_args 2>&1) || true
    else
        output=$(echo "$input" | python3 "$ANALYZE" 2>&1) || true
    fi

    if echo "$output" | grep -qF -- "$expected"; then
        PASS=$((PASS + 1))
        echo "  PASS: $name"
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  FAIL: $name\n    expected to contain: $expected\n    got: $output"
        echo "  FAIL: $name"
        echo "    expected to contain: $expected"
        echo "    got: $output"
    fi
}

run_test_exact_type() {
    local name="$1"
    local input="$2"
    local expected_type="$3"
    local extra_args="${4:-}"

    local output
    if [ -n "$extra_args" ]; then
        output=$(echo "$input" | python3 "$ANALYZE" --format=json $extra_args 2>&1) || true
    else
        output=$(echo "$input" | python3 "$ANALYZE" --format=json 2>&1) || true
    fi

    local actual_type
    actual_type=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['type'])" 2>/dev/null) || actual_type="PARSE_ERROR"

    if [ "$actual_type" = "$expected_type" ]; then
        PASS=$((PASS + 1))
        echo "  PASS: $name (type=$actual_type)"
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  FAIL: $name\n    expected type: $expected_type\n    got type: $actual_type\n    raw output: $output"
        echo "  FAIL: $name"
        echo "    expected type: $expected_type"
        echo "    got type: $actual_type"
    fi
}

echo "=== commit-msg-gen test suite ==="
echo ""

# --- Test 1: New Python file -> feat ---
DIFF_NEW_FILE=$(cat <<'DIFFEOF'
diff --git a/auth/login.py b/auth/login.py
new file mode 100644
index 0000000..abcdef1
--- /dev/null
+++ b/auth/login.py
@@ -0,0 +1,10 @@
+"""Login endpoint."""
+
+def login(username, password):
+    """Authenticate user."""
+    if check_credentials(username, password):
+        return create_token(username)
+    return None
DIFFEOF
)
run_test_exact_type "New Python file -> feat" "$DIFF_NEW_FILE" "feat"

# --- Test 2: Bug fix in existing file -> fix ---
DIFF_BUG_FIX=$(cat <<'DIFFEOF'
diff --git a/utils/parser.py b/utils/parser.py
index abcdef1..abcdef2 100644
--- a/utils/parser.py
+++ b/utils/parser.py
@@ -10,7 +10,7 @@
 def parse_input(data):
     """Parse user input."""
-    result = data.split(",")
+    # Fix bug where empty input caused crash
+    if not data:
+        return []
+    result = data.split(",")
     return result
DIFFEOF
)
run_test_exact_type "Bug fix in existing file -> fix" "$DIFF_BUG_FIX" "fix"

# --- Test 3: Test file changes -> test ---
DIFF_TEST=$(cat <<'DIFFEOF'
diff --git a/tests/test_parser.py b/tests/test_parser.py
index abcdef1..abcdef2 100644
--- a/tests/test_parser.py
+++ b/tests/test_parser.py
@@ -5,6 +5,12 @@
 def test_parse_basic():
     assert parse_input("a,b") == ["a", "b"]
 
+def test_parse_empty():
+    assert parse_input("") == []
+
+def test_parse_single():
+    assert parse_input("a") == ["a"]
DIFFEOF
)
run_test_exact_type "Test file changes -> test" "$DIFF_TEST" "test"

# --- Test 4: README changes -> docs ---
DIFF_DOCS=$(cat <<'DIFFEOF'
diff --git a/README.md b/README.md
index abcdef1..abcdef2 100644
--- a/README.md
+++ b/README.md
@@ -1,5 +1,8 @@
 # My Project
 
+## Installation
+
+Run `pip install myproject` to get started.
+
 ## Usage
 
 See the docs for details.
DIFFEOF
)
run_test_exact_type "README changes -> docs" "$DIFF_DOCS" "docs"

# --- Test 5: Config file changes -> chore ---
DIFF_CHORE=$(cat <<'DIFFEOF'
diff --git a/.gitignore b/.gitignore
index abcdef1..abcdef2 100644
--- a/.gitignore
+++ b/.gitignore
@@ -1,3 +1,5 @@
 __pycache__/
 *.pyc
+.env
+dist/
DIFFEOF
)
run_test_exact_type "Config file changes -> chore" "$DIFF_CHORE" "chore"

# --- Test 6: JSON output format ---
DIFF_JSON_TEST=$(cat <<'DIFFEOF'
diff --git a/src/main.py b/src/main.py
new file mode 100644
index 0000000..abcdef1
--- /dev/null
+++ b/src/main.py
@@ -0,0 +1,5 @@
+def main():
+    print("hello")
+
+if __name__ == "__main__":
+    main()
DIFFEOF
)
JSON_OUTPUT=$(echo "$DIFF_JSON_TEST" | python3 "$ANALYZE" --format=json 2>&1) || true

# Validate JSON structure
JSON_VALID=$(echo "$JSON_OUTPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    assert 'type' in d
    assert 'scope' in d
    assert 'summary' in d
    assert 'message' in d
    print('valid')
except:
    print('invalid')
" 2>/dev/null) || JSON_VALID="invalid"

if [ "$JSON_VALID" = "valid" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: JSON output format is valid"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: JSON output format\n    got: $JSON_OUTPUT"
    echo "  FAIL: JSON output format"
    echo "    got: $JSON_OUTPUT"
fi

# --- Test 7: Empty diff -> error ---
EMPTY_OUTPUT=$(echo "" | python3 "$ANALYZE" 2>&1) || true
if echo "$EMPTY_OUTPUT" | grep -qF -- "Error"; then
    PASS=$((PASS + 1))
    echo "  PASS: Empty diff -> error"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: Empty diff -> error\n    expected Error message\n    got: $EMPTY_OUTPUT"
    echo "  FAIL: Empty diff -> error"
    echo "    got: $EMPTY_OUTPUT"
fi

# --- Test 8: Multiple files changed -> correct scope ---
DIFF_MULTI=$(cat <<'DIFFEOF'
diff --git a/api/routes.py b/api/routes.py
index abcdef1..abcdef2 100644
--- a/api/routes.py
+++ b/api/routes.py
@@ -5,3 +5,10 @@
 def get_users():
     return []
+
+def get_user(user_id):
+    return {"id": user_id}
+
+def create_user(data):
+    return {"id": 1, **data}
diff --git a/api/models.py b/api/models.py
index abcdef1..abcdef2 100644
--- a/api/models.py
+++ b/api/models.py
@@ -1,3 +1,6 @@
 class User:
     pass
+
+class UserProfile:
+    pass
DIFFEOF
)
MULTI_OUTPUT=$(echo "$DIFF_MULTI" | python3 "$ANALYZE" --format=json 2>&1) || true
MULTI_SCOPE=$(echo "$MULTI_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['scope'])" 2>/dev/null) || MULTI_SCOPE="PARSE_ERROR"

if [ "$MULTI_SCOPE" = "api" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: Multiple files -> scope=api"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: Multiple files -> scope\n    expected: api\n    got: $MULTI_SCOPE"
    echo "  FAIL: Multiple files -> scope"
    echo "    expected: api"
    echo "    got: $MULTI_SCOPE"
fi

# --- Test 9: Refactor detection ---
DIFF_REFACTOR=$(cat <<'DIFFEOF'
diff --git a/core/engine.py b/core/engine.py
index abcdef1..abcdef2 100644
--- a/core/engine.py
+++ b/core/engine.py
@@ -10,12 +10,14 @@
-def process_data(raw_input):
-    parsed = raw_input.strip()
-    tokens = parsed.split(" ")
-    result = []
-    for t in tokens:
-        result.append(t.lower())
-    return result
+def process_data(raw_input):
+    """Process and tokenize input data."""
+    cleaned = raw_input.strip()
+    tokens = cleaned.split()
+    return [token.lower() for token in tokens]
+
+
+def validate_data(raw_input):
+    """Validate input before processing."""
+    return bool(raw_input and raw_input.strip())
DIFFEOF
)
run_test_exact_type "Refactor detection" "$DIFF_REFACTOR" "refactor"

# --- Test 10: Scope for root-level file ---
DIFF_ROOT=$(cat <<'DIFFEOF'
diff --git a/Makefile b/Makefile
index abcdef1..abcdef2 100644
--- a/Makefile
+++ b/Makefile
@@ -1,3 +1,5 @@
 build:
 	go build ./...
+test:
+	go test ./...
DIFFEOF
)
ROOT_OUTPUT=$(echo "$DIFF_ROOT" | python3 "$ANALYZE" --format=json 2>&1) || true
ROOT_SCOPE=$(echo "$ROOT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['scope'])" 2>/dev/null) || ROOT_SCOPE="PARSE_ERROR"

if [ "$ROOT_SCOPE" = "makefile" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: Root-level file -> scope=makefile"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: Root-level file -> scope\n    expected: makefile\n    got: $ROOT_SCOPE"
    echo "  FAIL: Root-level file -> scope"
    echo "    expected: makefile"
    echo "    got: $ROOT_SCOPE"
fi

# --- Test 11: --diff-file flag ---
TMPFILE=$(mktemp)
cat > "$TMPFILE" <<'DIFFEOF'
diff --git a/lib/helper.py b/lib/helper.py
new file mode 100644
index 0000000..abcdef1
--- /dev/null
+++ b/lib/helper.py
@@ -0,0 +1,3 @@
+def helper():
+    return True
DIFFEOF

FILE_OUTPUT=$(python3 "$ANALYZE" --diff-file="$TMPFILE" 2>&1) || true
rm -f "$TMPFILE"

if echo "$FILE_OUTPUT" | grep -qF -- "feat"; then
    PASS=$((PASS + 1))
    echo "  PASS: --diff-file flag works"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: --diff-file flag\n    expected feat message\n    got: $FILE_OUTPUT"
    echo "  FAIL: --diff-file flag"
    echo "    got: $FILE_OUTPUT"
fi

# --- Test 12: Style-only changes ---
DIFF_STYLE=$(cat <<'DIFFEOF'
diff --git a/src/app.py b/src/app.py
index abcdef1..abcdef2 100644
--- a/src/app.py
+++ b/src/app.py
@@ -1,6 +1,6 @@
-def   hello( ):
-    x=1
-    y =  2
-    return x+y
+def hello():
+    x = 1
+    y = 2
+    return x + y
DIFFEOF
)
run_test_exact_type "Style-only changes -> style" "$DIFF_STYLE" "style"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failures:"
    echo -e "$ERRORS"
    exit 1
fi

echo ""
echo "All tests passed."
exit 0
