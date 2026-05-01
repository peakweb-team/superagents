#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENCY_ROOT="$ROOT_DIR/.agency/skills"

# The dogfood metadata bundle under .agency/skills/ is gitignored and only
# present after a local builder run. If it is absent, there is nothing to
# validate in this environment; the test is a no-op rather than a failure.
if [[ ! -d "$AGENCY_ROOT" ]]; then
  echo "Manifest upgrade-metadata tests: no .agency/skills/ found, skipping (passed)"
  exit 0
fi

mapfile -d '' MANIFESTS < <(find "$AGENCY_ROOT" -type f -name 'manifest.yaml' -print0)

if [[ "${#MANIFESTS[@]}" -eq 0 ]]; then
  echo "Manifest upgrade-metadata tests: no manifest.yaml files found under .agency/skills/, skipping (passed)"
  exit 0
fi

# Compatibility status enum from docs/release-versioning-and-upgrade-contract.md.
ALLOWED_STATUSES=(compatible regeneration-recommended regeneration-required)

# Required top-level scalar fields. Each entry is "<key>:<regex>" where the
# regex matches the field on a line of its own (allowing optional value).
REQUIRED_TOP_LEVEL=(
  'framework_release:^framework_release:[[:space:]]*\S'
  'generated_at:^generated_at:[[:space:]]*\S'
)

fail() {
  echo "Manifest upgrade-metadata test failure: $1" >&2
  if [[ -n "${2:-}" ]]; then
    echo "  manifest: $2" >&2
  fi
  exit 1
}

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
# Assumes two-space indentation for child keys.
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

for manifest in "${MANIFESTS[@]}"; do
  echo "Validating $manifest"

  for entry in "${REQUIRED_TOP_LEVEL[@]}"; do
    field="${entry%%:*}"
    pattern="${entry#*:}"
    if ! grep -Eq "$pattern" "$manifest"; then
      fail "missing or empty top-level field '$field'" "$manifest"
    fi
  done

  framework_release="$(get_top_level framework_release "$manifest")"
  if [[ -z "$framework_release" ]]; then
    fail "framework_release is empty" "$manifest"
  fi

  generated_at="$(get_top_level generated_at "$manifest")"
  if ! is_iso_8601 "$generated_at"; then
    fail "generated_at is not a valid ISO-8601 timestamp: '$generated_at'" "$manifest"
  fi

  for nested_key in fragment_schema generated_skill_schema integration_declaration_schema; do
    value="$(get_nested contract_versions "$nested_key" "$manifest")"
    if [[ -z "$value" ]]; then
      fail "contract_versions.$nested_key is missing" "$manifest"
    fi
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
      fail "contract_versions.$nested_key must be an integer, got '$value'" "$manifest"
    fi
  done

  status="$(get_nested compatibility status "$manifest")"
  if [[ -z "$status" ]]; then
    fail "compatibility.status is missing" "$manifest"
  fi
  if ! is_allowed_status "$status"; then
    fail "compatibility.status '$status' is not one of: ${ALLOWED_STATUSES[*]}" "$manifest"
  fi

  reason="$(get_nested compatibility reason "$manifest")"
  if [[ -z "$reason" ]]; then
    fail "compatibility.reason is missing or empty" "$manifest"
  fi

  manual_review_required="$(get_nested compatibility manual_review_required "$manifest")"
  if [[ -z "$manual_review_required" ]]; then
    fail "compatibility.manual_review_required is missing" "$manifest"
  fi
  if ! is_boolean "$manual_review_required"; then
    fail "compatibility.manual_review_required must be a boolean, got '$manual_review_required'" "$manifest"
  fi
done

echo "Manifest upgrade-metadata tests: passed (${#MANIFESTS[@]} manifest(s) validated)"
