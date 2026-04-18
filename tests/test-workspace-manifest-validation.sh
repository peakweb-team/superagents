#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT_DIR/scripts/validate-workspace-manifest.sh"
VALID_DIR="$ROOT_DIR/tests/fixtures/workspace-manifests/valid"
INVALID_DIR="$ROOT_DIR/tests/fixtures/workspace-manifests/invalid"

pass_count=0
fail_count=0

run_expect_pass() {
  local file="$1"
  if "$VALIDATOR" "$file" >/dev/null 2>&1; then
    echo "PASS(valid): $file"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL(valid): $file"
    fail_count=$((fail_count + 1))
  fi
}

run_expect_fail() {
  local file="$1"
  if "$VALIDATOR" "$file" >/dev/null 2>&1; then
    echo "FAIL(invalid accepted): $file"
    fail_count=$((fail_count + 1))
  else
    echo "PASS(invalid rejected): $file"
    pass_count=$((pass_count + 1))
  fi
}

valid_files=("$VALID_DIR"/*.yaml)
invalid_files=("$INVALID_DIR"/*.yaml)

if [[ ${#valid_files[@]} -eq 0 ]]; then
  echo "Missing workspace manifest validation fixtures in $VALID_DIR"
  exit 1
fi

if [[ ${#invalid_files[@]} -eq 0 ]]; then
  echo "Missing workspace manifest validation fixtures in $INVALID_DIR"
  exit 1
fi

for file in "${valid_files[@]}"; do
  run_expect_pass "$file"
done

for file in "${invalid_files[@]}"; do
  run_expect_fail "$file"
done

echo "Workspace manifest validation tests: ${pass_count} passed, ${fail_count} failed"

if [[ $fail_count -ne 0 ]]; then
  exit 1
fi
