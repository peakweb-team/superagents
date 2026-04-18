#!/usr/bin/env bash
set -euo pipefail

# Enforce a single non-shell scripting runtime for tracked shebang scripts.
# Shell scripts (bash/sh/zsh) are excluded from runtime counting.

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required to evaluate tracked files." >&2
  exit 1
fi

normalize_interpreter() {
  local shebang="$1"
  local trimmed interpreter

  trimmed="${shebang#\#!}"
  trimmed="${trimmed#${trimmed%%[![:space:]]*}}"

  if [[ "$trimmed" == /usr/bin/env* ]]; then
    interpreter="${trimmed#/usr/bin/env}"
    interpreter="${interpreter#${interpreter%%[![:space:]]*}}"
    interpreter="${interpreter%% *}"
  else
    interpreter="${trimmed%% *}"
    interpreter="${interpreter##*/}"
  fi

  case "$interpreter" in
    python3*|python2*|python)
      echo "python"
      ;;
    nodejs|node)
      echo "node"
      ;;
    ruby)
      echo "ruby"
      ;;
    perl)
      echo "perl"
      ;;
    php)
      echo "php"
      ;;
    lua)
      echo "lua"
      ;;
    bash|sh|zsh)
      echo "shell"
      ;;
    *)
      echo "$interpreter"
      ;;
  esac
}

runtime_names=()
runtime_paths=()

runtime_index() {
  local target="$1"
  local i
  for ((i = 0; i < ${#runtime_names[@]}; i += 1)); do
    if [[ "${runtime_names[$i]}" == "$target" ]]; then
      echo "$i"
      return 0
    fi
  done
  echo "-1"
}

while IFS= read -r file; do
  [[ -f "$file" ]] || continue

  if ! IFS= read -r first_line < "$file"; then
    continue
  fi

  [[ "$first_line" == \#!* ]] || continue

  interpreter="$(normalize_interpreter "$first_line")"
  if [[ "$interpreter" == "shell" || -z "$interpreter" ]]; then
    continue
  fi

  index="$(runtime_index "$interpreter")"
  if [[ "$index" != "-1" ]]; then
    runtime_paths[$index]="${runtime_paths[$index]}\n$file"
  else
    runtime_names+=("$interpreter")
    runtime_paths+=("$file")
  fi
done < <(git ls-files)

runtime_count="${#runtime_names[@]}"
if [[ "$runtime_count" -gt 1 ]]; then
  echo "ERROR: Multiple non-shell runtimes detected in shebang scripts." >&2
  echo "Only one non-shell runtime is allowed (shell scripts are exempt)." >&2
  for ((i = 0; i < runtime_count; i += 1)); do
    runtime="${runtime_names[$i]}"
    echo "- Runtime '$runtime' used by:" >&2
    while IFS= read -r path; do
      [[ -n "$path" ]] && echo "  - $path" >&2
    done <<< "$(printf '%b' "${runtime_paths[$i]}")"
  done
  exit 1
fi

if [[ "$runtime_count" -eq 1 ]]; then
  for runtime in "${runtime_names[@]}"; do
    echo "Runtime policy OK: single non-shell runtime is '$runtime'."
  done
else
  echo "Runtime policy OK: no non-shell runtime scripts detected."
fi
