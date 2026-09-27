#!/usr/bin/env bash
# Runs every check CI runs: format, lint, headless import, unit tests.
# Usage: scripts/check.sh
# Set GODOT to the Godot binary if `godot` is not on PATH (on Windows use the *_console.exe).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
GD_DIRS=(sim ui tests)

echo "== gdformat --check"
gdformat --check "${GD_DIRS[@]}"

echo "== gdlint"
gdlint "${GD_DIRS[@]}"

echo "== godot --import (parse check)"
import_log="$(mktemp)"
"$GODOT" --headless --import 2>&1 | tee "$import_log"
# Godot exits 0 even when scripts fail to parse, so scan the log.
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$import_log"; then
  echo "Script errors found during import." >&2
  exit 1
fi

echo "== godot --check-only (typed GDScript, warnings as errors)"
# --import only compiles scripts that something references, so parse every script explicitly.
failed=0
while IFS= read -r script; do
  if ! "$GODOT" --headless --check-only -s "res://$script" > /dev/null 2>&1; then
    echo "Parse check failed: $script" >&2
    "$GODOT" --headless --check-only -s "res://$script" 2>&1 | grep -E "ERROR|at:" >&2 || true
    failed=1
  fi
done < <(find "${GD_DIRS[@]}" -name '*.gd' | sort)
if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "== GUT tests"
mkdir -p test_results
"$GODOT" --headless -s addons/gut/gut_cmdln.gd

echo "All checks passed."
