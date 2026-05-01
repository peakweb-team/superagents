#!/usr/bin/env bash
#
# upgrade-superagents-in-container.sh -- Refresh ~/.claude/ from a superagents
# ref without rebuilding the devcontainer.
#
# Mirrors the clone+install pattern from .devcontainer/post-create-superagents.sh
# (lines 23-33) but adds a scaffold-guard: if any of the four scaffold files
# (.devcontainer/Dockerfile, devcontainer.json, post-create-superagents.sh,
# scaffold-devcontainer.sh) differ between the cloned ref and what is committed
# in the project, the script exits non-zero with a "rebuild required" message
# and does NOT touch ~/.claude/. When the guard passes, the script invokes
# scripts/install.sh --tool claude-code --no-interactive against the cloned
# checkout and reports what changed under ~/.claude/.
#
# Usage:
#   .devcontainer/upgrade-superagents-in-container.sh [--dry-run]
#
# Environment:
#   SUPERAGENTS_REPO  -- override the upstream repo (default: pw-agency-agents)
#   SUPERAGENTS_REF   -- pin a ref (default: main)
#
# Flags:
#   --dry-run         -- run the scaffold guard only; do not invoke install.sh.
#                        Exits 0 when guard passes, non-zero when it fires.
#                        Used by tests/test-in-container-upgrade-guard.sh.
#
# Exit codes:
#   0  -- success (install completed, or guard passed under --dry-run)
#   1  -- general failure
#   2  -- scaffold guard fired: rebuild required
#   3  -- not running inside a devcontainer (host guard)

set -euo pipefail

SUPERAGENTS_REPO="${SUPERAGENTS_REPO:-https://github.com/peakweb-team/pw-agency-agents.git}"
SUPERAGENTS_REF="${SUPERAGENTS_REF:-main}"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $arg" >&2
      echo "Usage: $0 [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Host guard -- bail loudly if we look like we are running on the host rather
# than inside a devcontainer. The script edits ~/.claude/ which would clobber
# the operator's host install. Heuristic: the official Anthropic devcontainer
# image runs as the `node` user with HOME=/home/node, and we ship inside a
# container created from that image. If neither marker is present, refuse.
# Override with SUPERAGENTS_SKIP_HOST_GUARD=1 (escape hatch for tests/CI).
# ---------------------------------------------------------------------------
host_guard() {
  if [ "${SUPERAGENTS_SKIP_HOST_GUARD:-0}" = "1" ]; then
    return 0
  fi
  if [ -d /home/node ] && [ "${HOME:-}" = "/home/node" ]; then
    return 0
  fi
  if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${CODESPACES:-}" ] || [ -n "${DEVCONTAINER:-}" ]; then
    return 0
  fi
  cat >&2 <<EOF
ERROR: this script must run inside the superagents devcontainer.
       It refreshes ~/.claude/ from a cloned superagents ref. Running on
       the host would clobber your host claude install.
       Open the project in its devcontainer and re-run from the container
       terminal. To bypass this guard (e.g. in CI), set
       SUPERAGENTS_SKIP_HOST_GUARD=1.
EOF
  exit 3
}

# ---------------------------------------------------------------------------
# Scaffold guard -- compare the four scaffold files in the project's
# .devcontainer/ against the cloned ref's .devcontainer/ files. If any differ,
# the project has either drifted ahead of upstream or upstream has changed in
# a way that requires a host-side rebuild. Exit 2 with a clear message; do not
# run install.sh.
#
# When the project root is a git checkout, the project-side comparison reads
# the COMMITTED blob via `git show HEAD:<relpath>` rather than the working
# tree, so uncommitted local edits to a scaffold file do not falsely trigger
# a "rebuild required" exit. Non-git project roots fall back to the
# working-tree file path.
#
# Args:
#   $1 -- absolute path to the project root (must contain .devcontainer/)
#   $2 -- absolute path to the cloned superagents checkout root
#         (must contain .devcontainer/)
# Returns:
#   0 -- all four scaffold files match
#   2 -- at least one differs
# ---------------------------------------------------------------------------
SCAFFOLD_FILES=(
  ".devcontainer/Dockerfile"
  ".devcontainer/devcontainer.json"
  ".devcontainer/post-create-superagents.sh"
  ".devcontainer/scaffold-devcontainer.sh"
)

scaffold_guard() {
  local project_root="$1"
  local clone_root="$2"
  local diffs=()
  local missing=()

  # If the project root is a git checkout, compare the COMMITTED scaffold
  # blobs against upstream rather than the working tree. Operators
  # frequently have unrelated working-tree edits to .devcontainer/ open;
  # those should not block the in-container update path. Non-git roots
  # (rare, e.g. an exported tarball) fall back to the working-tree file.
  local project_is_git_checkout=0
  if git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    project_is_git_checkout=1
  fi

  for relpath in "${SCAFFOLD_FILES[@]}"; do
    local project_file="$project_root/$relpath"
    local clone_file="$clone_root/$relpath"
    # `committed_file` is the path scaffold_guard actually compares against
    # `clone_file`. For git checkouts we materialize the committed blob into
    # a temp file (so cmp -s, missing-detection, and the diff message all
    # work uniformly across both branches).
    local committed_file=""

    if [ "$project_is_git_checkout" -eq 1 ]; then
      committed_file="$(mktemp)"
      # `git show HEAD:<relpath>` writes the committed blob to stdout. A
      # non-zero exit means the path is not tracked at HEAD (untracked,
      # never-committed, or removed) -- treat that as "missing on the
      # project side", same as the filesystem branch below.
      if ! git -C "$project_root" show "HEAD:$relpath" > "$committed_file" 2>/dev/null; then
        rm -f "$committed_file"
        missing+=("project: $relpath (not committed at HEAD)")
        continue
      fi
    else
      if [ ! -f "$project_file" ]; then
        missing+=("project: $relpath")
        continue
      fi
      committed_file="$project_file"
    fi

    if [ ! -f "$clone_file" ]; then
      # If the upstream ref does not ship this scaffold file, treat it as a
      # signal that scaffolding has changed shape — a rebuild path is needed.
      [ "$project_is_git_checkout" -eq 1 ] && rm -f "$committed_file"
      missing+=("upstream: $relpath")
      continue
    fi
    if ! cmp -s "$committed_file" "$clone_file"; then
      diffs+=("$relpath")
    fi
    [ "$project_is_git_checkout" -eq 1 ] && rm -f "$committed_file"
  done

  if [ ${#diffs[@]} -eq 0 ] && [ ${#missing[@]} -eq 0 ]; then
    return 0
  fi

  cat >&2 <<EOF
Rebuild required -- scaffold files differ between this project and superagents@${SUPERAGENTS_REF}.

Differing files:
EOF
  for f in "${diffs[@]}"; do
    echo "  - $f (content differs)" >&2
  done
  for f in "${missing[@]}"; do
    echo "  - $f (missing)" >&2
  done
  cat >&2 <<EOF

The in-container update path only refreshes ~/.claude/. Changes to the
devcontainer scaffold itself require rebuilding the container image on the
host.

See the superagents-devcontainer skill (Rebuild section) for the rebuild
procedure:
  ~/.claude/skills/superagents-devcontainer/SKILL.md  (section 1: Rebuild)

~/.claude/ was NOT modified by this run.
EOF
  return 2
}

# ---------------------------------------------------------------------------
# Snapshot helper -- capture a deterministic listing of ~/.claude/ contents so
# we can report what changed after install.sh runs. We use file path + size
# + sha256 to detect both content changes and additions/removals without
# blowing up on large files.
# ---------------------------------------------------------------------------
snapshot_claude_dir() {
  local out_file="$1"
  local claude_dir="${HOME}/.claude"
  if [ ! -d "$claude_dir" ]; then
    : > "$out_file"
    return 0
  fi
  ( cd "$claude_dir" && find . -type f -print0 \
      | xargs -0 sha256sum 2>/dev/null \
      | LC_ALL=C sort ) > "$out_file" || true
}

main() {
  host_guard

  local project_root
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

  if [ ! -d "$project_root/.devcontainer" ]; then
    echo "ERROR: $project_root/.devcontainer does not exist." >&2
    echo "       This script must run from within a project that was bootstrapped" >&2
    echo "       via the superagents-devcontainer-bootstrap skill." >&2
    exit 1
  fi

  local workdir
  workdir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$workdir'" EXIT

  local clone_root="$workdir/superagents"
  # SUPERAGENTS_REF can be a branch name, a tag, or a commit SHA. `git clone
  # --branch` only accepts branch/tag names, so we use the init/fetch/checkout
  # pattern instead -- `git fetch origin <ref>` resolves all three forms and
  # `git checkout --detach FETCH_HEAD` lands us on the resolved commit.
  echo "Fetching $SUPERAGENTS_REPO@$SUPERAGENTS_REF into temp dir..."
  git init --quiet "$clone_root"
  git -C "$clone_root" remote add origin "$SUPERAGENTS_REPO"
  if ! git -C "$clone_root" fetch --depth 1 origin "$SUPERAGENTS_REF"; then
    echo "ERROR: failed to fetch $SUPERAGENTS_REPO@$SUPERAGENTS_REF" >&2
    echo "       Verify SUPERAGENTS_REF is a valid branch, tag, or commit SHA" >&2
    echo "       on $SUPERAGENTS_REPO." >&2
    exit 1
  fi
  git -C "$clone_root" checkout --quiet --detach FETCH_HEAD

  echo "Running scaffold guard against ${#SCAFFOLD_FILES[@]} file(s)..."
  if ! scaffold_guard "$project_root" "$clone_root"; then
    exit 2
  fi
  echo "Scaffold guard passed: project .devcontainer/ matches superagents@${SUPERAGENTS_REF}."

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "--dry-run: skipping install.sh; exiting 0."
    exit 0
  fi

  local before_snapshot="$workdir/before.txt"
  local after_snapshot="$workdir/after.txt"
  snapshot_claude_dir "$before_snapshot"

  local installer="$clone_root/scripts/install.sh"
  if [ ! -x "$installer" ]; then
    echo "ERROR: installer not found or not executable at $installer" >&2
    exit 1
  fi

  echo "Running $installer --tool claude-code --no-interactive..."
  "$installer" --tool claude-code --no-interactive

  snapshot_claude_dir "$after_snapshot"

  echo
  echo "Changes under ~/.claude/:"
  if diff -u "$before_snapshot" "$after_snapshot" >/dev/null 2>&1; then
    echo "  (no changes detected)"
  else
    # Show only the changed file paths, not the full sha256 lines, to keep
    # the report compact. `+` for additions/changes, `-` for removals.
    # diff lines look like: "< <sha256>  <path>" or "> <sha256>  <path>".
    # Operate on $0 directly via sub() so paths with consecutive spaces are
    # preserved verbatim (avoids awk's $0 reconstruction via OFS).
    diff "$before_snapshot" "$after_snapshot" \
      | awk '/^[<>] [0-9a-f]+ / {
               sign=($1=="<"?"-":"+");
               sub(/^[<>] [0-9a-f]+[[:space:]]+/, "", $0);
               print sign " " $0;
             }' \
      | LC_ALL=C sort -u
    echo
    echo "If a SKILL.md you currently have open in your claude session changed,"
    echo "restart the claude session (or re-open the skill) so the new content"
    echo "is picked up."
  fi

  echo
  echo "Superagents refresh complete (ref: $SUPERAGENTS_REF)."
}

# Allow tests to source this file and call scaffold_guard / host_guard
# directly without running main. Detect by checking BASH_SOURCE vs $0 -- when
# sourced, BASH_SOURCE[0] != $0.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
