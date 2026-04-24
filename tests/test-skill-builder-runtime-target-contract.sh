#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_BUILDER_FILE="$ROOT_DIR/skills/skill-builder/SKILL.md"
LAYOUT_CONTRACT_FILE="$ROOT_DIR/docs/generated-skill-layout.md"
QUESTIONNAIRE_FILE="$ROOT_DIR/docs/builder-questionnaire-flow.md"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if ! grep -Eq "$pattern" "$file"; then
    echo "Missing contract requirement: $description" >&2
    echo "Checked file: $file" >&2
    exit 1
  fi
}

# Enforce Claude-mode entrypoint contract.
assert_contains "$SKILL_BUILDER_FILE" 'runtime_target: claude-code.*SKILL\.md.*<skill-name>\.md' \
  "Claude runtime target uses SKILL.md and disallows <skill-name>.md primary entrypoint"
assert_contains "$LAYOUT_CONTRACT_FILE" '\| `claude-code` \| `.claude/skills/superagents/<skill-name>/` \| `SKILL\.md` \|' \
  "Generated layout maps claude-code runtime target to SKILL.md entrypoint"
assert_contains "$LAYOUT_CONTRACT_FILE" 'do not publish the primary skill as `.claude/skills/superagents/<name>\.md`' \
  "Generated layout forbids orphan top-level .md primary skill entrypoint in Claude mode"

# Enforce runtime-target ambiguity gate.
assert_contains "$SKILL_BUILDER_FILE" 'If `runtime_target` is ambiguous at assembly time, ask the focused `runtime-target` follow-up question' \
  "Builder asks runtime-target follow-up when runtime target is ambiguous"
assert_contains "$LAYOUT_CONTRACT_FILE" 'if confidence is below high and output layout would change, the builder should ask a focused follow-up question before writing files' \
  "Generated layout requires ambiguity follow-up before writing files"

# Enforce runtime target decision-state recording (confirmed/assumed/unresolved).
assert_contains "$SKILL_BUILDER_FILE" 'Record each resulting decision as confirmed, assumed, unresolved, or not-applicable' \
  "Builder records decision state in metadata"
assert_contains "$QUESTIONNAIRE_FILE" 'state: unresolved' \
  "Questionnaire flow documents unresolved decision state"
assert_contains "$QUESTIONNAIRE_FILE" 'state: assumed' \
  "Questionnaire flow documents assumed decision state"
assert_contains "$QUESTIONNAIRE_FILE" 'state: confirmed' \
  "Questionnaire flow documents confirmed decision state"

echo "Skill-builder runtime-target contract tests: passed"
