# Common Patterns

> The 5 most common ways to use commit-msg-gen.

## 1. Simple Feature Addition

When you add a new file or function:

```bash
echo "+function validateEmail(email) {" | ./scripts/run.sh
```

Output: `feat: add email validation function`

## 2. Bug Fix

When changes fix existing behavior:

```bash
echo "-  if (count = 0)
+  if (count === 0)" | ./scripts/run.sh
```

Output: `fix: correct equality check in count comparison`

## 3. Refactoring

When restructuring without behavior change:

```bash
echo "-const handler = function(req, res) {
+const handler = (req, res) => {" | ./scripts/run.sh
```

Output: `refactor: convert handler to arrow function`

## 4. Documentation Changes

When only docs change:

```bash
echo "+## API Reference
+
+### GET /users" | ./scripts/run.sh
```

Output: `docs: add API reference for users endpoint`

## 5. JSON Output

For integration with tools:

```bash
echo "+new feature" | ./scripts/run.sh --format json
```

Output:
```json
{"type": "feat", "scope": null, "message": "add new feature", "full": "feat: add new feature"}
```
