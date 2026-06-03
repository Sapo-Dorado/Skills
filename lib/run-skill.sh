#!/usr/bin/env bash
# Shared library for executing Claude skills from SapoHub scripts.
# Usage: source this file, then call: run_skill <skill-name>

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.claude/skills"
PREREQS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/prerequisites"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLAUDE=$(ls -d /nix/store/*-claude-code-*/bin/claude 2>/dev/null | sort -t- -k4 -V | tail -1)
if [ -z "$CLAUDE" ]; then
  echo "ERROR: claude binary not found" >&2
  exit 1
fi

_parse_frontmatter_list() {
  local file="$1" field="$2"
  awk "/^${field}:/{found=1; next} found && /^ *- /{gsub(/^ *- */, \"\"); print; next} found{exit}" "$file"
}

_parse_frontmatter_value() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" | head -1 | sed "s/^${field}: *//"
}

run_skill() {
  local skill_name="$1"
  local skill_file="${SKILLS_DIR}/${skill_name}/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    echo "ERROR: skill '${skill_name}' not found at ${skill_file}" >&2
    exit 1
  fi

  local prerequisites
  prerequisites=$(_parse_frontmatter_list "$skill_file" "prerequisites")
  while IFS= read -r prereq; do
    [ -z "$prereq" ] && continue
    local prereq_script="${PREREQS_DIR}/${prereq}.sh"
    if [ ! -f "$prereq_script" ]; then
      echo "ERROR: prerequisite script '${prereq}.sh' not found" >&2
      exit 1
    fi
    bash "$prereq_script"
    if [ $? -ne 0 ]; then
      echo "ERROR: prerequisite '${prereq}' failed" >&2
      exit 1
    fi
  done <<< "$prerequisites"

  local allowed_tools
  allowed_tools=$(_parse_frontmatter_value "$skill_file" "allowed-tools")

  export DISPLAY=":99"
  export XDG_RUNTIME_DIR="/var/lib/sapo_hub/tmp/runtime"

  local chrome_tools="mcp__claude-in-chrome__browser_batch,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__find,mcp__claude-in-chrome__form_input,mcp__claude-in-chrome__get_page_text,mcp__claude-in-chrome__gif_creator,mcp__claude-in-chrome__javascript_tool,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__read_console_messages,mcp__claude-in-chrome__read_network_requests,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__tabs_close_mcp,mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__tabs_create_mcp"

  local all_tools="${chrome_tools}"
  [ -n "$allowed_tools" ] && all_tools="${all_tools},${allowed_tools}"

  local claude_args=("--print" "/${skill_name}" "--chrome" "--allowedTools" "$all_tools")

  local output
  output=$(cd "$SOURCE_DIR" && "$CLAUDE" "${claude_args[@]}" 2>&1)
  local exit_code=$?

  echo "$output"

  if [ $exit_code -ne 0 ]; then
    exit 1
  fi

  if echo "$output" | grep -q "^ERROR:"; then
    exit 1
  fi

  if ! echo "$output" | grep -q "^SUCCESS:"; then
    echo "ERROR: skill did not produce a SUCCESS output" >&2
    exit 1
  fi

  exit 0
}
