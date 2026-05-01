#!/usr/bin/env bash
set -euo pipefail

# Verifies that scaffold-devcontainer.sh installs the dc-build, dc-up, and
# dc-shell host-side CLI helper scripts at the project root, with the right
# shebang, perms, guards, and command bodies (issue #156).
#
# Also verifies idempotency: a second scaffold run against a project where the
# operator has modified dc-up MUST NOT clobber the modification.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="$ROOT_DIR/skills/devcontainer-bootstrap/templates/scaffold-devcontainer.sh"
FIXTURE="$ROOT_DIR/tests/fixtures/scaffold-devcontainer/anthropic-base-dockerfile.txt"

[[ -x "$SCAFFOLD" ]] || { echo "Missing or non-executable scaffold script: $SCAFFOLD" >&2; exit 1; }
[[ -f "$FIXTURE" ]]  || { echo "Missing fixture: $FIXTURE" >&2; exit 1; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Stand up a fake "Anthropic upstream" served from the local filesystem so the
# scaffold's curl call is hermetic. The scaffold's BASE_URL is consumed by curl
# directly, so a file:// URL prefix works.
UPSTREAM_DIR="$TMP_ROOT/upstream"
mkdir -p "$UPSTREAM_DIR"
cp "$FIXTURE" "$UPSTREAM_DIR/Dockerfile"

# Minimal devcontainer.json sufficient for the scaffold's JSON patch step.
cat >"$UPSTREAM_DIR/devcontainer.json" <<'JSON'
{
  "name": "test",
  "build": { "dockerfile": "Dockerfile" },
  "runArgs": ["--cap-add", "NET_ADMIN", "--cap-add", "NET_RAW"],
  "mounts": [],
  "containerEnv": {},
  "postStartCommand": "echo hi",
  "waitFor": "postStartCommand"
}
JSON

# Run scaffold inside a fake repo with a known name that exists in ports.yaml.
# Pick the first project entry from the real ports registry so the lookup
# succeeds without us having to mutate the registry.
PORTS_YAML="$ROOT_DIR/skills/devcontainer-bootstrap/ports.yaml"
[[ -f "$PORTS_YAML" ]] || { echo "Missing ports registry at $PORTS_YAML" >&2; exit 1; }
REPO_NAME="$(python3 - "$PORTS_YAML" <<'PYEOF'
import sys, re
with open(sys.argv[1]) as f:
    in_projects = False
    for line in f:
        s = line.strip()
        if s.startswith('#') or not s:
            continue
        if s == 'projects:':
            in_projects = True
            continue
        if in_projects:
            if re.match(r'^\S', line) and not line.startswith(' '):
                break
            m = re.match(r'^\s+(\S+):\s*\d+', line)
            if m:
                print(m.group(1))
                sys.exit(0)
PYEOF
)"
[[ -n "$REPO_NAME" ]] || { echo "Could not pick a repo name from $PORTS_YAML" >&2; exit 1; }

REPO_DIR="$TMP_ROOT/$REPO_NAME"
mkdir -p "$REPO_DIR"
git -C "$REPO_DIR" init -q
git -C "$REPO_DIR" config user.email "test@example.com"
git -C "$REPO_DIR" config user.name  "Test"
git -C "$REPO_DIR" commit --allow-empty -q -m "init"

TARGET_DIR="$REPO_DIR/.devcontainer"

run_scaffold() {
  ( cd "$REPO_DIR" \
    && ANTHROPIC_DEVCONTAINER_BASE_URL="file://$UPSTREAM_DIR" \
       "$SCAFFOLD" "$TARGET_DIR" >/dev/null )
}

assert_helper_common() {
  local label="$1"
  local helper="$2"
  local path="$REPO_DIR/$helper"

  [[ -f "$path" ]] || { echo "[$label] FAIL: $helper not produced at $path" >&2; exit 1; }
  [[ -x "$path" ]] || { echo "[$label] FAIL: $helper at $path is not executable" >&2; exit 1; }

  # Shebang must be the portable env form.
  local first_line
  first_line="$(head -n 1 "$path")"
  if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
    echo "[$label] FAIL: $helper has unexpected shebang: $first_line" >&2
    exit 1
  fi

  # Strict mode preamble.
  if ! grep -q "set -euo pipefail" "$path"; then
    echo "[$label] FAIL: $helper missing 'set -euo pipefail'" >&2
    exit 1
  fi

  # Host-side guard: must reference either /.dockerenv or DEVCONTAINER env.
  if ! grep -qE "/\.dockerenv|DEVCONTAINER" "$path"; then
    echo "[$label] FAIL: $helper missing host-side guard (no /.dockerenv or DEVCONTAINER check)" >&2
    exit 1
  fi

  # devcontainer-on-PATH self-check.
  if ! grep -q "command -v devcontainer" "$path"; then
    echo "[$label] FAIL: $helper missing 'command -v devcontainer' PATH check" >&2
    exit 1
  fi
}

assert_dc_build() {
  local label="$1"
  local path="$REPO_DIR/dc-build"
  if ! grep -q "devcontainer up" "$path"; then
    echo "[$label] FAIL: dc-build does not invoke 'devcontainer up'" >&2
    exit 1
  fi
  if ! grep -q -- "--remove-existing-container" "$path"; then
    echo "[$label] FAIL: dc-build missing --remove-existing-container flag" >&2
    exit 1
  fi
}

assert_dc_up() {
  local label="$1"
  local path="$REPO_DIR/dc-up"
  if ! grep -q "devcontainer up" "$path"; then
    echo "[$label] FAIL: dc-up does not invoke 'devcontainer up'" >&2
    exit 1
  fi
  # dc-up must NOT include --remove-existing-container — that's dc-build's job.
  if grep -q -- "--remove-existing-container" "$path"; then
    echo "[$label] FAIL: dc-up unexpectedly includes --remove-existing-container" >&2
    exit 1
  fi
}

assert_dc_shell() {
  local label="$1"
  local path="$REPO_DIR/dc-shell"
  if ! grep -q "devcontainer exec" "$path"; then
    echo "[$label] FAIL: dc-shell does not invoke 'devcontainer exec'" >&2
    exit 1
  fi
  if ! grep -qw "zsh" "$path"; then
    echo "[$label] FAIL: dc-shell does not invoke zsh" >&2
    exit 1
  fi
}

# First run: helpers should be installed cleanly.
run_scaffold

for helper in dc-build dc-up dc-shell; do
  assert_helper_common "first run" "$helper"
done
assert_dc_build "first run"
assert_dc_up    "first run"
assert_dc_shell "first run"

# Idempotency: simulate operator modification of dc-up, then re-run scaffold.
# The modification must survive (skip-if-exists semantics).
SENTINEL="# operator-edit: do-not-clobber-${RANDOM}"
printf '\n%s\n' "$SENTINEL" >> "$REPO_DIR/dc-up"
MODIFIED_HASH="$(sha256sum "$REPO_DIR/dc-up" | awk '{print $1}')"

run_scaffold

POST_HASH="$(sha256sum "$REPO_DIR/dc-up" | awk '{print $1}')"
if [[ "$MODIFIED_HASH" != "$POST_HASH" ]]; then
  echo "FAIL: scaffold clobbered operator-modified dc-up on second run" >&2
  exit 1
fi
if ! grep -qF "$SENTINEL" "$REPO_DIR/dc-up"; then
  echo "FAIL: operator sentinel missing from dc-up after second scaffold run" >&2
  exit 1
fi

# Sanity: dc-build and dc-shell should still pass their checks after re-run.
assert_helper_common "second run" "dc-build"
assert_helper_common "second run" "dc-shell"
assert_dc_build "second run"
assert_dc_shell "second run"

echo "cli-helper scaffold tests: passed"
