#!/usr/bin/env bash
# Labels agent panes for Herdr:
#   display_agent = "<agent> · <title>"  (pane border label)
#   $task token   = "<title>"            (sidebar rows)
# The title is the agent's terminal title unless one was pinned with `set`.
#
#   agent-title.sh               refresh (plugin startup / event hooks / action)
#   agent-title.sh set <title>   pin a title on the calling pane ($HERDR_PANE_ID)
#   agent-title.sh clear         unpin, back to the agent's terminal title
#   agent-title.sh show          print the calling pane's label and title
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HERDR="${HERDR_BIN_PATH:-herdr}"
SOURCE="agent-title"
SEP=$'\x1f'
# Herdr caps display_agent and token values at 80 characters.
MAX_CHARS=80

. "$ROOT/lib/i18n.sh"

now_ms() {
  perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'
}

# clip MAX TEXT: NFC-normalize, turn control characters into spaces, drop bidi
# embedding/override/isolate controls, collapse whitespace, then cut to MAX
# code points on a grapheme boundary (emoji ZWJ sequences, combining marks)
# with a trailing ellipsis, so Herdr's own cap never splits a character.
clip() {
  perl -CSA -MUnicode::Normalize -e '
    my ($max, $s) = @ARGV;
    $s = NFC($s);
    $s =~ s/\p{Cc}/ /g;
    $s =~ s/[\x{202A}-\x{202E}\x{2066}-\x{2069}]//g;
    $s =~ s/\s+/ /g;
    $s =~ s/^ | $//g;
    if (length $s > $max) {
      my $out = "";
      for my $g ($s =~ /(\X)/g) {
        last if length($out) + length($g) > $max - 1;
        $out .= $g;
      }
      $out =~ s/ $//;
      $s = "$out\x{2026}";
    }
    print $s;
  ' -- "$1" "$2"
}

# make_label AGENT TITLE: border label, or the bare agent name when the title
# only repeats it (e.g. Claude's default "Claude Code").
make_label() {
  local agent="$1" title="$2" lower
  lower=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    "" | "$agent" | "$agent code" | "$agent cli") printf '%s' "$agent" ;;
    *) clip "$MAX_CHARS" "$agent · $title" ;;
  esac
}

# Pane from the triggering event; every live agent pane otherwise.
target_panes() {
  local id=""
  if [ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ]; then
    id=$(printf '%s' "$HERDR_PLUGIN_EVENT_JSON" \
      | jq -r 'first(.. | objects | .pane_id? // empty)' 2>/dev/null)
  fi
  if [ -n "$id" ]; then
    printf '%s\n' "$id"
  else
    "$HERDR" agent list 2>/dev/null | jq -r '.result.agents[]?.pane_id'
  fi
}

STATUS=""

refresh() {
  local pane="$1" seq info agent auto pinned pinned_for session cur_label cur_task
  local title label
  STATUS=""
  # Taken before the read so a slower, older run can't overwrite a newer one.
  seq=$(now_ms)
  info=$("$HERDR" pane get "$pane" 2>/dev/null) || return 0

  IFS="$SEP" read -r STATUS agent auto pinned pinned_for session cur_label cur_task < <(
    jq -r --arg sep "$SEP" '.result.pane | [
      .agent_status, .agent, .terminal_title_stripped,
      .tokens.title_override, .tokens.title_session, .agent_session.value,
      .display_agent, .tokens.task
    ] | map(. // "") | join($sep)' <<<"$info"
  )
  [ -n "$agent" ] || return 0

  # A pinned title belongs to the agent session that set it.
  if [ -n "$pinned" ] && [ "$pinned_for" = "$session" ]; then
    title="$pinned"
  else
    title=$(clip "$MAX_CHARS" "$auto")
  fi
  label=$(make_label "$agent" "$title")

  # Unchanged: no report, so hook-triggered runs can't loop.
  [ "$cur_label" = "$label" ] && [ "$cur_task" = "$title" ] && return 0

  if [ -n "$title" ]; then
    set -- --token "task=$title"
  else
    set -- --clear-token task
  fi
  "$HERDR" pane report-metadata "$pane" \
    --source "$SOURCE" --agent "$agent" --seq "$seq" \
    --display-agent "$label" "$@" >/dev/null
}

calling_pane() {
  if [ "${HERDR_ENV:-}" != 1 ] || [ -z "${HERDR_PANE_ID:-}" ]; then
    echo "agent-title: $MSG_NOT_IN_HERDR" >&2
    exit 1
  fi
  printf '%s\n' "$HERDR_PANE_ID"
}

# Keys stay English so scripts and agents can parse the output.
show() {
  "$HERDR" pane get "$1" | jq -r '.result.pane |
    "label: \(.display_agent // .agent // "-")\ntitle: \(.tokens.task // "-")" +
    (if .tokens.title_override and
        (.tokens.title_session // "") == (.agent_session.value // "")
     then "\npinned: \(.tokens.title_override)" else "" end)'
}

main() {
  local pane title session
  case "${1:-}" in
    set)
      load_messages "$ROOT"
      shift
      [ $# -gt 0 ] || { echo "$MSG_USAGE_SET" >&2; exit 2; }
      title=$(clip "$MAX_CHARS" "$*")
      [ -n "$title" ] || { echo "agent-title: $MSG_EMPTY_TITLE" >&2; exit 2; }
      pane=$(calling_pane) || exit 1
      session=$("$HERDR" pane get "$pane" | jq -r '.result.pane.agent_session.value // empty')
      "$HERDR" pane report-metadata "$pane" --source "$SOURCE" --seq "$(now_ms)" \
        --token "title_override=$title" --token "title_session=$session" >/dev/null || exit 1
      refresh "$pane"
      show "$pane"
      ;;
    clear)
      load_messages "$ROOT"
      pane=$(calling_pane) || exit 1
      "$HERDR" pane report-metadata "$pane" --source "$SOURCE" --seq "$(now_ms)" \
        --clear-token title_override --clear-token title_session >/dev/null || exit 1
      refresh "$pane"
      show "$pane"
      ;;
    show)
      load_messages "$ROOT"
      pane=$(calling_pane) || exit 1
      show "$pane"
      ;;
    "")
      # A failed report exits non-zero so `herdr plugin log list` shows it.
      target_panes | {
        failed=0
        while IFS= read -r pane; do
          [ -n "$pane" ] || continue
          refresh "$pane" || failed=1
          # Claude retitles the session a few seconds after a new prompt starts work.
          if [ "$STATUS" = "working" ] && [ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ]; then
            sleep 3 && { refresh "$pane" || failed=1; }
            sleep 7 && { refresh "$pane" || failed=1; }
          fi
        done
        exit "$failed"
      }
      ;;
    *)
      load_messages "$ROOT"
      echo "$MSG_USAGE" >&2
      exit 2
      ;;
  esac
}

# Sourcing (tests) only defines the functions.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
