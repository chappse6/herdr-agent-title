#!/usr/bin/env bash
# Labels agent panes for Herdr:
#   display_agent = "<agent> · <title>"  (pane border label)
#   $task token   = "<title>"            (sidebar rows)
#
# Title priority, per agent session:
#   1. user pin   `set <title>`   title the user named; never replaced by `auto`
#   2. agent pin  `auto <title>`  title the agent chose for its current task
#   3. the agent's terminal title
#
#   agent-title.sh                refresh (plugin startup / event hooks / action)
#   agent-title.sh set <title>    pin the user's title on the calling pane
#   agent-title.sh auto <title>   pin the agent's own title on the calling pane
#   agent-title.sh clear          drop the user pin
#   agent-title.sh show           print label, title and source
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HERDR="${HERDR_BIN_PATH:-herdr}"
REPORTER="agent-title"
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

# auto_title AGENT RAW: terminal title without decorations naming the agent
# ("Fix bug - grok", "claude: Fix bug") or dashes left by a stripped spinner.
auto_title() {
  local stripped
  stripped=$(perl -CSA -e '
    my ($agent, $t) = @ARGV;
    my $a = quotemeta $agent;
    my $sep = qr/\s*[-\x{2013}\x{2014}|:\x{00B7}]\s*/;
    $t =~ s/^\s*$a(?:\s+code)?$sep//i;
    $t =~ s/$sep$a(?:\s+code)?\s*$//i;
    $t =~ s/\s*\(\s*$a\s*\)\s*$//i;
    $t =~ s/^\s*[-\x{2013}\x{2014}]+\s*//;
    print $t;
  ' -- "$1" "$2")
  clip "$MAX_CHARS" "$stripped"
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

# read_pane PANE: loads the pane's state into P_* variables.
read_pane() {
  local info
  info=$("$HERDR" pane get "$1" 2>/dev/null) || return 1
  IFS="$SEP" read -r P_STATUS P_AGENT P_TERMINAL P_SESSION \
    P_USER P_USER_SID P_PIN P_PIN_SID P_LABEL P_TASK < <(
    jq -r --arg sep "$SEP" '.result.pane | [
      .agent_status, .agent, .terminal_title_stripped, .agent_session.value,
      .tokens.title_user, .tokens.title_user_session,
      .tokens.title_agent, .tokens.title_agent_session,
      .display_agent, .tokens.task
    ] | map(. // "") | join($sep)' <<<"$info"
  )
}

# resolve: TITLE / SOURCE / LABEL from the P_* state. Pins belong to the agent
# session that set them; a new session in the pane ignores them.
resolve() {
  if [ -n "$P_USER" ] && [ "$P_USER_SID" = "$P_SESSION" ]; then
    TITLE="$P_USER" SOURCE=user
  elif [ -n "$P_PIN" ] && [ "$P_PIN_SID" = "$P_SESSION" ]; then
    TITLE="$P_PIN" SOURCE=agent
  else
    TITLE=$(auto_title "$P_AGENT" "$P_TERMINAL") SOURCE=terminal
  fi
  LABEL=$(make_label "$P_AGENT" "$TITLE")
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

refresh() {
  local pane="$1" seq
  P_STATUS=""
  # Taken before the read so a slower, older run can't overwrite a newer one.
  seq=$(now_ms)
  read_pane "$pane" || return 0
  [ -n "$P_AGENT" ] || return 0
  resolve

  # Unchanged: no report, so hook-triggered runs can't loop.
  [ "$P_LABEL" = "$LABEL" ] && [ "$P_TASK" = "$TITLE" ] && return 0

  if [ -n "$TITLE" ]; then
    set -- --token "task=$TITLE"
  else
    set -- --clear-token task
  fi
  "$HERDR" pane report-metadata "$pane" \
    --source "$REPORTER" --agent "$P_AGENT" --seq "$seq" \
    --display-agent "$LABEL" "$@" >/dev/null
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
  read_pane "$1" || return 1
  resolve
  printf 'label: %s\ntitle: %s\nsource: %s\n' "$LABEL" "${TITLE:--}" "$SOURCE"
}

# pin user|agent TITLE...: stores the pin with the current agent session.
pin() {
  local tier="$1" pane title
  shift
  [ $# -gt 0 ] || { echo "$MSG_USAGE_PIN" >&2; exit 2; }
  title=$(clip "$MAX_CHARS" "$*")
  [ -n "$title" ] || { echo "agent-title: $MSG_EMPTY_TITLE" >&2; exit 2; }
  pane=$(calling_pane) || exit 1
  read_pane "$pane" || exit 1
  "$HERDR" pane report-metadata "$pane" --source "$REPORTER" --seq "$(now_ms)" \
    --token "title_$tier=$title" --token "title_${tier}_session=$P_SESSION" >/dev/null || exit 1
  refresh "$pane"
  show "$pane"
}

main() {
  local pane
  case "${1:-}" in
    set)
      load_messages "$ROOT"
      shift
      pin user "$@"
      ;;
    auto)
      load_messages "$ROOT"
      shift
      pin agent "$@"
      ;;
    clear)
      load_messages "$ROOT"
      pane=$(calling_pane) || exit 1
      "$HERDR" pane report-metadata "$pane" --source "$REPORTER" --seq "$(now_ms)" \
        --clear-token title_user --clear-token title_user_session >/dev/null || exit 1
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
          if [ "$P_STATUS" = "working" ] && [ -n "${HERDR_PLUGIN_EVENT_JSON:-}" ]; then
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

# Sourcing (tests, hooks) only defines the functions.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
