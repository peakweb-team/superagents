#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENCY_ROOT="$ROOT_DIR/.agency/skills"
FIXTURE_ROOT="$ROOT_DIR/tests/fixtures/manifest-upgrade-metadata"
VALID_FIXTURE_DIR="$FIXTURE_ROOT/valid"
INVALID_FIXTURE_DIR="$FIXTURE_ROOT/invalid"

# Compatibility status enum from docs/release-versioning-and-upgrade-contract.md.
ALLOWED_STATUSES=(compatible regeneration-recommended regeneration-required)

# Required top-level scalar fields. Each entry is "<key>:<regex>" where the
# regex matches the field on a line of its own (allowing optional value).
REQUIRED_TOP_LEVEL=(
  'framework_release:^framework_release:[[:space:]]*\S'
  'generated_at:^generated_at:[[:space:]]*\S'
)

# Extract the value of a top-level scalar key from a YAML manifest.
# Treats the file as a flat YAML document with two-space indentation for
# nested objects. Strips surrounding quotes and trailing comments.
get_top_level() {
  local key="$1" file="$2"
  awk -v key="$key" '
    $0 ~ "^"key":" {
      sub("^"key":[[:space:]]*", "", $0)
      sub("[[:space:]]+#.*$", "", $0)
      gsub(/^["'\'']|["'\'']$/, "", $0)
      print
      exit
    }
  ' "$file"
}

# Extract the value of a nested key (single level) under a parent object.
# Assumes two-space indentation for child keys. Strips surrounding quotes
# so callers receive the string value of YAML scalars regardless of
# quoting style. Use get_nested_raw when the YAML type itself
# (integer/boolean vs quoted string) needs to be enforced.
get_nested() {
  local parent="$1" key="$2" file="$3"
  awk -v parent="$parent" -v key="$key" '
    $0 ~ "^"parent":[[:space:]]*$" { in_block = 1; next }
    in_block && /^[^[:space:]]/ { in_block = 0 }
    in_block && $0 ~ "^  "key":" {
      sub("^  "key":[[:space:]]*", "", $0)
      sub("[[:space:]]+#.*$", "", $0)
      gsub(/^["'\'']|["'\'']$/, "", $0)
      print
      exit
    }
  ' "$file"
}

# Same as get_nested but preserves surrounding quotes so type-strict
# checks (e.g. integer or boolean) can reject quoted YAML scalars.
get_nested_raw() {
  local parent="$1" key="$2" file="$3"
  awk -v parent="$parent" -v key="$key" '
    $0 ~ "^"parent":[[:space:]]*$" { in_block = 1; next }
    in_block && /^[^[:space:]]/ { in_block = 0 }
    in_block && $0 ~ "^  "key":" {
      sub("^  "key":[[:space:]]*", "", $0)
      sub("[[:space:]]+#.*$", "", $0)
      sub("[[:space:]]+$", "", $0)
      print
      exit
    }
  ' "$file"
}

is_iso_8601() {
  local value="$1"
  # Accept basic ISO-8601 UTC ("...Z") or with explicit offset ("+HH:MM"/"-HH:MM").
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]
}

is_allowed_status() {
  local value="$1" allowed
  for allowed in "${ALLOWED_STATUSES[@]}"; do
    if [[ "$value" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

is_boolean() {
  local value="$1"
  [[ "$value" == "true" || "$value" == "false" ]]
}

# Validate a single manifest. Returns 0 on success, 1 on the first
# contract violation, and prints a description of the violation to stdout.
# Does not call exit; callers decide whether a non-zero return is a test
# pass (negative fixture) or a test failure (positive fixture / real
# manifest).
validate_manifest() {
  local manifest="$1" entry field pattern
  local framework_release generated_at value status reason
  local manual_review_required nested_key

  for entry in "${REQUIRED_TOP_LEVEL[@]}"; do
    field="${entry%%:*}"
    pattern="${entry#*:}"
    if ! grep -Eq "$pattern" "$manifest"; then
      echo "missing or empty top-level field '$field'"
      return 1
    fi
  done

  framework_release="$(get_top_level framework_release "$manifest")"
  if [[ -z "$framework_release" ]]; then
    echo "framework_release is empty"
    return 1
  fi

  generated_at="$(get_top_level generated_at "$manifest")"
  if ! is_iso_8601 "$generated_at"; then
    echo "generated_at is not a valid ISO-8601 timestamp: '$generated_at'"
    return 1
  fi

  for nested_key in fragment_schema generated_skill_schema integration_declaration_schema; do
    # Use the raw extractor: a quoted YAML scalar like `"1"` is a string,
    # not the integer the contract requires.
    value="$(get_nested_raw contract_versions "$nested_key" "$manifest")"
    if [[ -z "$value" ]]; then
      echo "contract_versions.$nested_key is missing"
      return 1
    fi
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
      echo "contract_versions.$nested_key must be an unquoted integer, got '$value'"
      return 1
    fi
  done

  status="$(get_nested compatibility status "$manifest")"
  if [[ -z "$status" ]]; then
    echo "compatibility.status is missing"
    return 1
  fi
  if ! is_allowed_status "$status"; then
    echo "compatibility.status '$status' is not one of: ${ALLOWED_STATUSES[*]}"
    return 1
  fi

  reason="$(get_nested compatibility reason "$manifest")"
  if [[ -z "$reason" ]]; then
    echo "compatibility.reason is missing or empty"
    return 1
  fi

  # Use the raw extractor so a quoted YAML string like `"true"` is rejected;
  # the contract requires the YAML boolean type.
  manual_review_required="$(get_nested_raw compatibility manual_review_required "$manifest")"
  if [[ -z "$manual_review_required" ]]; then
    echo "compatibility.manual_review_required is missing"
    return 1
  fi
  if ! is_boolean "$manual_review_required"; then
    echo "compatibility.manual_review_required must be an unquoted boolean, got '$manual_review_required'"
    return 1
  fi

  return 0
}

pass_count=0
fail_count=0

# Always exercise the committed fixtures so this contract test is
# meaningful in CI even when no .agency/skills/ bundle is present.
# CodeRabbit flagged the previous skip-on-empty behavior as letting
# upgrade-contract regressions slip through automated runs; the fixtures
# guarantee both positive and negative coverage on every run.
valid_fixtures=("$VALID_FIXTURE_DIR"/*.yaml)
invalid_fixtures=("$INVALID_FIXTURE_DIR"/*.yaml)

if [[ ${#valid_fixtures[@]} -eq 0 ]]; then
  echo "Manifest upgrade-metadata test failure: no valid fixtures found in $VALID_FIXTURE_DIR" >&2
  exit 1
fi

if [[ ${#invalid_fixtures[@]} -eq 0 ]]; then
  echo "Manifest upgrade-metadata test failure: no invalid fixtures found in $INVALID_FIXTURE_DIR" >&2
  exit 1
fi

for fixture in "${valid_fixtures[@]}"; do
  echo "Validating valid fixture: $fixture"
  if reason="$(validate_manifest "$fixture")"; then
    echo "  PASS"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL(valid fixture rejected): $reason" >&2
    fail_count=$((fail_count + 1))
  fi
done

for fixture in "${invalid_fixtures[@]}"; do
  echo "Validating invalid fixture: $fixture"
  if reason="$(validate_manifest "$fixture")"; then
    echo "  FAIL(invalid fixture accepted)" >&2
    fail_count=$((fail_count + 1))
  else
    echo "  PASS(invalid fixture rejected: $reason)"
    pass_count=$((pass_count + 1))
  fi
done

# Additionally validate any real generated manifests under .agency/skills/.
# The dogfood metadata bundle is gitignored and only present after a local
# builder run, so this pass is best-effort on a clean checkout but enforced
# on developer machines that have actually generated a bundle.
real_manifest_count=0
if [[ -d "$AGENCY_ROOT" ]]; then
  mapfile -d '' real_manifests < <(find "$AGENCY_ROOT" -type f -name 'manifest.yaml' -print0)
  for manifest in "${real_manifests[@]}"; do
    real_manifest_count=$((real_manifest_count + 1))
    echo "Validating real manifest: $manifest"
    if reason="$(validate_manifest "$manifest")"; then
      echo "  PASS"
      pass_count=$((pass_count + 1))
    else
      echo "  FAIL(real manifest rejected): $reason" >&2
      fail_count=$((fail_count + 1))
    fi
  done
fi

total_checked=$((${#valid_fixtures[@]} + ${#invalid_fixtures[@]} + real_manifest_count))

if [[ $total_checked -eq 0 ]]; then
  echo "Manifest upgrade-metadata test failure: zero manifests were checked" >&2
  exit 1
fi

echo "Manifest upgrade-metadata tests: ${pass_count} passed, ${fail_count} failed (${#valid_fixtures[@]} valid fixture(s), ${#invalid_fixtures[@]} invalid fixture(s), ${real_manifest_count} real manifest(s))"

if [[ $fail_count -ne 0 ]]; then
  exit 1
fi
