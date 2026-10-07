#!/usr/bin/env bash
# Links the herdr-title agent skill into the skill directories of installed
# agents: ~/.claude/skills (Claude Code) and ~/.agents/skills (Codex, also read
# by Copilot CLI and Gemini CLI).
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKILL="$ROOT/skills/herdr-title"

. "$ROOT/lib/i18n.sh"
load_messages "$ROOT"

link_into() {
  local dir="$1" dest="$1/herdr-title"
  mkdir -p "$dir"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$SKILL" ]; then
    printf "$MSG_ALREADY_LINKED\n" "$dest"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    printf "$MSG_SKIPPED\n" "$dest" >&2
  else
    ln -s "$SKILL" "$dest" && printf "$MSG_LINKED\n" "$dest"
  fi
}

[ -d "$HOME/.claude" ] && link_into "$HOME/.claude/skills"
if [ -d "$HOME/.agents" ] || [ -d "$HOME/.codex" ]; then
  link_into "$HOME/.agents/skills"
fi
exit 0
