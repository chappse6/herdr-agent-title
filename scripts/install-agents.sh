#!/usr/bin/env bash
# Wires the plugin into Claude Code and Codex:
#   - links the herdr-title skill into ~/.claude/skills (Claude Code) and
#     ~/.agents/skills (Codex; also read by other agents such as Grok)
#   - registers hooks/prompt-context.sh as a UserPromptSubmit hook in
#     ~/.claude/settings.json and ~/.codex/hooks.json
#     (previous file kept as <file>.bak-agent-title)
#
#   install-agents.sh               install or update
#   install-agents.sh --uninstall   remove both
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKILL="$ROOT/skills/herdr-title"
HOOK="$ROOT/hooks/prompt-context.sh"
# Identifies our hook entry across installs, even if the plugin path changed.
MARKER="# herdr-agent-title"
HOOK_CMD="[ -f '$HOOK' ] && bash '$HOOK' || true $MARKER"

. "$ROOT/lib/i18n.sh"
load_messages "$ROOT"

link_skill() {
  local dest="$1/herdr-title"
  mkdir -p "$1"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$SKILL" ]; then
    printf "$MSG_ALREADY_LINKED\n" "$dest"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    printf "$MSG_SKIPPED\n" "$dest" >&2
  else
    ln -s "$SKILL" "$dest" && printf "$MSG_LINKED\n" "$dest"
  fi
}

unlink_skill() {
  local dest="$1/herdr-title"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$SKILL" ]; then
    rm "$dest" && printf "$MSG_REMOVED\n" "$dest"
  fi
}

# rewrite_json FILE FILTER: applies a jq filter in place, keeping the file's
# inode and permissions; leaves the file untouched if jq fails.
rewrite_json() {
  local file="$1" filter="$2" tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/agent-title.XXXXXX") || return 1
  if jq --arg m "$MARKER" --arg c "$HOOK_CMD" "$filter" "$file" >"$tmp"; then
    cp "$file" "$file.bak-agent-title" && cat "$tmp" >"$file"
  fi
  rm -f "$tmp"
}

DROP_OURS='[.hooks.UserPromptSubmit[]?
  | .hooks |= map(select((.command // "") | contains($m) | not))
  | select(.hooks | length > 0)]'

add_hook() {
  local file="$1"
  [ -f "$file" ] || printf '{}\n' >"$file"
  if jq -e --arg c "$HOOK_CMD" \
    '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | index($c) != null' "$file" >/dev/null; then
    printf "$MSG_HOOK_PRESENT\n" "$file"
    return 0
  fi
  rewrite_json "$file" ".hooks.UserPromptSubmit = $DROP_OURS
    + [{hooks: [{type: \"command\", command: \$c, timeout: 5}]}]" \
    && printf "$MSG_HOOK_ADDED\n" "$file"
}

remove_hook() {
  local file="$1"
  [ -f "$file" ] || return 0
  jq -e --arg m "$MARKER" \
    '[.hooks.UserPromptSubmit[]?.hooks[]?.command // "" | contains($m)] | any' \
    "$file" >/dev/null || return 0
  rewrite_json "$file" ".hooks.UserPromptSubmit = $DROP_OURS" \
    && printf "$MSG_REMOVED\n" "$file"
}

if [ "${1:-}" = --uninstall ]; then
  unlink_skill "$HOME/.claude/skills"
  unlink_skill "$HOME/.agents/skills"
  remove_hook "$HOME/.claude/settings.json"
  remove_hook "$HOME/.codex/hooks.json"
  exit 0
fi

if [ -d "$HOME/.claude" ]; then
  link_skill "$HOME/.claude/skills"
  add_hook "$HOME/.claude/settings.json"
fi
if [ -d "$HOME/.codex" ]; then
  link_skill "$HOME/.agents/skills"
  add_hook "$HOME/.codex/hooks.json"
elif [ -d "$HOME/.agents" ]; then
  link_skill "$HOME/.agents/skills"
fi
exit 0
