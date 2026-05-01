#!/usr/bin/env bash
#
# tests/test-in-container-upgrade-guard.sh
#
# Verifies the scaffold-guard logic in
# skills/devcontainer-bootstrap/templates/upgrade-superagents-in-container.sh.
#
# Strategy: source the script (do NOT execute main) so we can call
# scaffold_guard directly against fixture trees we build in temp dirs. Two
# trees are constructed:
#   1. a "project" tree representing what is currently committed under the
#      consumer project's .devcontainer/
#   2. an "upstream" tree representing what was just cloned from the
#      configured SUPERAGENTS_REPO@SUPERAGENTS_REF
#
# Cases covered:
#   A. matching scaffold files -> guard passes (returns 0)
#   B. one scaffold file differs -> guard fails (returns 2)
#   C. project missing a scaffold file -> guard fails (returns 2)
#   D. upstream missing a scaffold file -> guard fails (returns 2)
#   E. end-to-end via --dry-run -> exit 0 when matching, exit 2 when differing,
#      and ~/.claude/ is never touched
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/skills/devcontainer-bootstrap/templates/upgrade-superagents-in-container.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "FAIL: upgrade script not found at $SCRIPT_PATH" >&2
  exit 1
fi
if [ ! -x "$SCRIPT_PATH" ]; then
  echo "FAIL: upgrade script not executable at $SCRIPT_PATH" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------
SCAFFOLD_RELPATHS=(
  ".devcontainer/Dockerfile"
  ".devcontainer/devcontainer.json"
  ".devcontainer/post-create-superagents.sh"
  ".devcontainer/scaffold-devcontainer.sh"
)

# Populate a tree with byte-identical placeholder content for each scaffold
# file. Callers can mutate individual files afterward to simulate drift.
populate_tree() {
  local root="$1"
  mkdir -p "$root/.devcontainer"
  for relpath in "${SCAFFOLD_RELPATHS[@]}"; do
    printf 'baseline content for %s\n' "$relpath" > "$root/$relpath"
  done
  # The script also expects scripts/install.sh to be executable on the
  # upstream side when running end-to-end. Tests stop at --dry-run so this
  # is only needed for the dry-run-mode E2E case below.
  mkdir -p "$root/scripts"
  cat > "$root/scripts/install.sh" <<'EOF'
#!/usr/bin/env bash
echo "test fixture install.sh: refusing to run during tests" >&2
exit 99
EOF
  chmod +x "$root/scripts/install.sh"
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL [$label]: expected $expected, got $actual" >&2
    exit 1
  fi
  echo "  ok: $label (=$actual)"
}

# -------------------------------------------------------------------------
# Source the script in a guarded subshell so we can call its functions.
# Because the script's tail is gated by `[ "${BASH_SOURCE[0]}" = "$0" ]`,
# sourcing it does NOT execute main(). We get the helper functions only.
# -------------------------------------------------------------------------
# shellcheck disable=SC1090
source "$SCRIPT_PATH"

# -------------------------------------------------------------------------
# Case A: all scaffold files match -> scaffold_guard returns 0
# -------------------------------------------------------------------------
echo "Case A: matching scaffold files"
PROJECT_A="$WORK_DIR/case-a/project"
UPSTREAM_A="$WORK_DIR/case-a/upstream"
populate_tree "$PROJECT_A"
populate_tree "$UPSTREAM_A"

set +e
( scaffold_guard "$PROJECT_A" "$UPSTREAM_A" >/dev/null 2>&1 )
rc_a=$?
set -e
assert_eq "case-A scaffold_guard returns 0" "0" "$rc_a"

# -------------------------------------------------------------------------
# Case B: one scaffold file differs -> scaffold_guard returns 2
# -------------------------------------------------------------------------
echo "Case B: one scaffold file differs"
PROJECT_B="$WORK_DIR/case-b/project"
UPSTREAM_B="$WORK_DIR/case-b/upstream"
populate_tree "$PROJECT_B"
populate_tree "$UPSTREAM_B"
printf 'upstream changed Dockerfile content\n' > "$UPSTREAM_B/.devcontainer/Dockerfile"

set +e
guard_b_output="$( scaffold_guard "$PROJECT_B" "$UPSTREAM_B" 2>&1 )"
rc_b=$?
set -e
assert_eq "case-B scaffold_guard returns 2" "2" "$rc_b"
if ! grep -q "Rebuild required" <<<"$guard_b_output"; then
  echo "FAIL [case-B]: expected 'Rebuild required' in stderr, got:" >&2
  echo "$guard_b_output" >&2
  exit 1
fi
if ! grep -q "Dockerfile" <<<"$guard_b_output"; then
  echo "FAIL [case-B]: expected the differing file 'Dockerfile' to be named in the message" >&2
  echo "$guard_b_output" >&2
  exit 1
fi
if ! grep -q "superagents-devcontainer skill" <<<"$guard_b_output"; then
  echo "FAIL [case-B]: expected message to point at superagents-devcontainer skill" >&2
  echo "$guard_b_output" >&2
  exit 1
fi
echo "  ok: case-B message names differing file and points at devcontainer skill"

# -------------------------------------------------------------------------
# Case C: project is missing a scaffold file -> guard returns 2
# -------------------------------------------------------------------------
echo "Case C: project missing scaffold file"
PROJECT_C="$WORK_DIR/case-c/project"
UPSTREAM_C="$WORK_DIR/case-c/upstream"
populate_tree "$PROJECT_C"
populate_tree "$UPSTREAM_C"
rm "$PROJECT_C/.devcontainer/scaffold-devcontainer.sh"

set +e
( scaffold_guard "$PROJECT_C" "$UPSTREAM_C" >/dev/null 2>&1 )
rc_c=$?
set -e
assert_eq "case-C scaffold_guard returns 2" "2" "$rc_c"

# -------------------------------------------------------------------------
# Case D: upstream is missing a scaffold file -> guard returns 2
# -------------------------------------------------------------------------
echo "Case D: upstream missing scaffold file"
PROJECT_D="$WORK_DIR/case-d/project"
UPSTREAM_D="$WORK_DIR/case-d/upstream"
populate_tree "$PROJECT_D"
populate_tree "$UPSTREAM_D"
rm "$UPSTREAM_D/.devcontainer/post-create-superagents.sh"

set +e
( scaffold_guard "$PROJECT_D" "$UPSTREAM_D" >/dev/null 2>&1 )
rc_d=$?
set -e
assert_eq "case-D scaffold_guard returns 2" "2" "$rc_d"

# -------------------------------------------------------------------------
# Case E: end-to-end via --dry-run.
# We can't have main() really clone from the network, so we replace `git`
# in PATH with a stub that copies the upstream tree into the destination
# the script asked it to clone into. Then we run the script with --dry-run
# so install.sh is NEVER invoked. We assert exit 0 when matching, exit 2
# when differing, and that ~/.claude/ is untouched in both cases.
# -------------------------------------------------------------------------
echo "Case E: end-to-end --dry-run"

GIT_STUB_DIR="$WORK_DIR/git-stub-bin"
mkdir -p "$GIT_STUB_DIR"
# Stub `git`. When called as `git clone --depth 1 --branch X URL DEST`,
# copy the contents of $FAKE_UPSTREAM_DIR into DEST. Otherwise fall through
# to the real git so `git rev-parse --show-toplevel` keeps working.
cat > "$GIT_STUB_DIR/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "clone" ]; then
  # Last positional argument is the destination directory.
  dest="${@: -1}"
  mkdir -p "$dest"
  cp -R "${FAKE_UPSTREAM_DIR:?FAKE_UPSTREAM_DIR must be set for git stub}/." "$dest/"
  exit 0
fi
# Resolve the real git from PATH minus our stub dir.
PATH="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v -F "$(dirname "$0")" | paste -sd: -)" \
  exec git "$@"
STUB
chmod +x "$GIT_STUB_DIR/git"

# Sub-case E1: matching scaffold files -> dry-run exits 0
echo "  sub-case E1: matching scaffold -> dry-run exit 0"
PROJECT_E1="$WORK_DIR/case-e1/project"
UPSTREAM_E1="$WORK_DIR/case-e1/upstream"
populate_tree "$PROJECT_E1"
populate_tree "$UPSTREAM_E1"
# Initialise the project as a git repo so `git rev-parse --show-toplevel`
# resolves to PROJECT_E1 when we cd into it.
( cd "$PROJECT_E1" && git init -q && git -c user.email=t@t -c user.name=t \
    -c commit.gpgsign=false add . && git -c user.email=t@t -c user.name=t \
    -c commit.gpgsign=false commit -q -m init >/dev/null )

# Capture the ~/.claude/ snapshot before; assert it is unchanged after.
CLAUDE_DIR="${HOME:-}/.claude"
claude_before="$WORK_DIR/case-e1/claude-before.txt"
if [ -d "$CLAUDE_DIR" ]; then
  ( cd "$CLAUDE_DIR" && find . -type f -print0 | xargs -0 sha256sum 2>/dev/null \
      | LC_ALL=C sort ) > "$claude_before" || true
else
  : > "$claude_before"
fi

set +e
FAKE_UPSTREAM_DIR="$UPSTREAM_E1" \
SUPERAGENTS_SKIP_HOST_GUARD=1 \
PATH="$GIT_STUB_DIR:$PATH" \
  bash -c "cd '$PROJECT_E1' && '$SCRIPT_PATH' --dry-run" \
    >"$WORK_DIR/case-e1/stdout" 2>"$WORK_DIR/case-e1/stderr"
rc_e1=$?
set -e
assert_eq "case-E1 dry-run exit code" "0" "$rc_e1"

claude_after="$WORK_DIR/case-e1/claude-after.txt"
if [ -d "$CLAUDE_DIR" ]; then
  ( cd "$CLAUDE_DIR" && find . -type f -print0 | xargs -0 sha256sum 2>/dev/null \
      | LC_ALL=C sort ) > "$claude_after" || true
else
  : > "$claude_after"
fi
if ! cmp -s "$claude_before" "$claude_after"; then
  echo "FAIL [case-E1]: ~/.claude/ changed during --dry-run" >&2
  diff "$claude_before" "$claude_after" >&2 || true
  exit 1
fi
echo "  ok: case-E1 ~/.claude/ untouched"

# Sub-case E2: differing scaffold -> dry-run exits 2, ~/.claude/ untouched
echo "  sub-case E2: differing scaffold -> dry-run exit 2"
PROJECT_E2="$WORK_DIR/case-e2/project"
UPSTREAM_E2="$WORK_DIR/case-e2/upstream"
populate_tree "$PROJECT_E2"
populate_tree "$UPSTREAM_E2"
printf 'upstream rewrote devcontainer.json\n' > "$UPSTREAM_E2/.devcontainer/devcontainer.json"
( cd "$PROJECT_E2" && git init -q && git -c user.email=t@t -c user.name=t \
    -c commit.gpgsign=false add . && git -c user.email=t@t -c user.name=t \
    -c commit.gpgsign=false commit -q -m init >/dev/null )

claude_before2="$WORK_DIR/case-e2/claude-before.txt"
if [ -d "$CLAUDE_DIR" ]; then
  ( cd "$CLAUDE_DIR" && find . -type f -print0 | xargs -0 sha256sum 2>/dev/null \
      | LC_ALL=C sort ) > "$claude_before2" || true
else
  : > "$claude_before2"
fi

set +e
FAKE_UPSTREAM_DIR="$UPSTREAM_E2" \
SUPERAGENTS_SKIP_HOST_GUARD=1 \
PATH="$GIT_STUB_DIR:$PATH" \
  bash -c "cd '$PROJECT_E2' && '$SCRIPT_PATH' --dry-run" \
    >"$WORK_DIR/case-e2/stdout" 2>"$WORK_DIR/case-e2/stderr"
rc_e2=$?
set -e
assert_eq "case-E2 dry-run exit code (guard fired)" "2" "$rc_e2"
if ! grep -q "Rebuild required" "$WORK_DIR/case-e2/stderr"; then
  echo "FAIL [case-E2]: expected 'Rebuild required' in stderr" >&2
  cat "$WORK_DIR/case-e2/stderr" >&2
  exit 1
fi

claude_after2="$WORK_DIR/case-e2/claude-after.txt"
if [ -d "$CLAUDE_DIR" ]; then
  ( cd "$CLAUDE_DIR" && find . -type f -print0 | xargs -0 sha256sum 2>/dev/null \
      | LC_ALL=C sort ) > "$claude_after2" || true
else
  : > "$claude_after2"
fi
if ! cmp -s "$claude_before2" "$claude_after2"; then
  echo "FAIL [case-E2]: ~/.claude/ changed even though guard fired" >&2
  diff "$claude_before2" "$claude_after2" >&2 || true
  exit 1
fi
echo "  ok: case-E2 ~/.claude/ untouched after guard fire"

# -------------------------------------------------------------------------
# Case F: scaffold-devcontainer.sh ships the new template
# -------------------------------------------------------------------------
echo "Case F: scaffold-devcontainer.sh installs the new template"
SCAFFOLD_TEMPLATE="$ROOT_DIR/skills/devcontainer-bootstrap/templates/scaffold-devcontainer.sh"
if ! grep -q "upgrade-superagents-in-container.sh" "$SCAFFOLD_TEMPLATE"; then
  echo "FAIL [case-F]: scaffold-devcontainer.sh does not copy upgrade-superagents-in-container.sh" >&2
  exit 1
fi
echo "  ok: scaffold-devcontainer.sh references the new template"

echo
echo "In-container upgrade guard tests: passed"
