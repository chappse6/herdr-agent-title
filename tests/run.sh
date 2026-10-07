#!/usr/bin/env bash
# Offline checks for text handling and message catalogs. No herdr needed.
#   bash tests/run.sh
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
. "$ROOT/agent-title.sh"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    echo "     got:  [$2]"
    echo "     want: [$3]"
    failures=$((failures + 1))
  fi
}

repeat() { perl -CSA -e 'print $ARGV[0] x $ARGV[1]' -- "$1" "$2"; }
chars() { perl -CSA -e 'print length $ARGV[0]' -- "$1"; }

# --- clip: normalization -----------------------------------------------------
check "ascii passthrough" "$(clip 80 'Fix auth bug')" "Fix auth bug"
check "whitespace and newlines collapse" "$(clip 80 $'  fix\n\tauth   bug  ')" "fix auth bug"
nfd=$(perl -CS -Mutf8 -MUnicode::Normalize -e 'print NFD("로그인 버그 수정")')
check "Korean NFD becomes NFC" "$(clip 80 "$nfd")" "로그인 버그 수정"
check "bidi override removed" "$(clip 80 "$(printf 'abc\342\200\256def')")" "abcdef"
check "Japanese passthrough" "$(clip 80 'ログイン不具合の修正')" "ログイン不具合の修正"
check "Simplified Chinese passthrough" "$(clip 80 '修复登录错误')" "修复登录错误"
check "Arabic passthrough" "$(clip 80 'إصلاح خطأ تسجيل الدخول')" "إصلاح خطأ تسجيل الدخول"
check "accented Latin passthrough" "$(clip 80 'Corriger le bogue de connexion — étape 2')" "Corriger le bogue de connexion — étape 2"

# --- clip: truncation on grapheme boundaries ---------------------------------
long_cjk=$(repeat '漢' 100)
check "long CJK cut to 80 chars" "$(chars "$(clip 80 "$long_cjk")")" "80"
check "long CJK ends with ellipsis" "$(clip 80 "$long_cjk")" "$(repeat '漢' 79)…"
family='👨‍👩‍👧'
check "ZWJ emoji kept whole when it fits" \
  "$(clip 80 "$(repeat a 70)${family}$(repeat b 10)")" "$(repeat a 70)${family}bbbb…"
check "ZWJ emoji dropped whole at the boundary" \
  "$(clip 80 "$(repeat a 76)${family}")" "$(repeat a 76)…"
# q + combining acute has no precomposed form, so NFC keeps 2 code points.
check "combining marks not split" \
  "$(clip 10 "$(perl -CS -e 'print "q\x{301}" x 50')")" "$(perl -CS -e 'print "q\x{301}" x 4, "\x{2026}"')"
check "short text not truncated" "$(clip 80 'é')" "é"

# --- make_label ---------------------------------------------------------------
check "default Claude title shows agent only" "$(make_label claude 'Claude Code')" "claude"
check "agent-name title shows agent only" "$(make_label codex 'Codex')" "codex"
check "empty title shows agent only" "$(make_label claude '')" "claude"
check "Korean title label" "$(make_label claude '로그인 버그 수정')" "claude · 로그인 버그 수정"
check "label capped at 80 chars" "$(chars "$(make_label claude "$long_cjk")")" "80"

# --- auto_title: terminal title cleanup ------------------------------------------
check "trailing '- agent' removed" "$(auto_title grok 'Fix login bug - grok')" "Fix login bug"
check "leading 'agent:' removed" "$(auto_title claude 'Claude: Fix login bug')" "Fix login bug"
check "spinner dash and agent suffix removed" \
  "$(auto_title grok '- Waiting for response… - 헤더 타이틀 - grok')" "Waiting for response… - 헤더 타이틀"
check "'(agent)' suffix removed" "$(auto_title codex 'Refactor auth (codex)')" "Refactor auth"
check "unrelated dashes kept" "$(auto_title claude '로그인 - 회원가입 수정')" "로그인 - 회원가입 수정"
check "default Claude title kept for make_label" "$(auto_title claude 'Claude Code')" "Claude Code"

# --- resolve: title priority ----------------------------------------------------
state() { # agent terminal session user user_sid pin pin_sid
  P_AGENT=$1 P_TERMINAL=$2 P_SESSION=$3 P_USER=$4 P_USER_SID=$5 P_PIN=$6 P_PIN_SID=$7
}
state claude 'Claude Code' s1 '' '' '' ''
resolve
check "no pins -> terminal title" "$SOURCE|$TITLE|$LABEL" "terminal|Claude Code|claude"
state claude 'Claude Code' s1 '' '' '배포 준비' s1
resolve
check "agent pin -> agent" "$SOURCE|$LABEL" "agent|claude · 배포 준비"
state claude 'Claude Code' s1 '로그인 버그' s1 '배포 준비' s1
resolve
check "user pin beats agent pin" "$SOURCE|$TITLE" "user|로그인 버그"
state claude 'Terminal task' s2 '로그인 버그' s1 '배포 준비' s2
resolve
check "user pin from old session ignored" "$SOURCE|$TITLE" "agent|배포 준비"
state claude 'Terminal task' s3 '로그인 버그' s1 '배포 준비' s2
resolve
check "all pins from old sessions ignored" "$SOURCE|$TITLE" "terminal|Terminal task"

# --- hooks/prompt-context.sh ----------------------------------------------------
tmp=$(mktemp -d "${TMPDIR:-/tmp}/agent-title-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/herdr" <<'EOF'
#!/bin/bash
# Fake herdr: `pane get` returns the state in $FAKE_TOKENS.
[ "$1 $2" = "pane get" ] || exit 1
printf '{"result":{"pane":{"agent":"claude","agent_status":"idle","terminal_title_stripped":"Claude Code","agent_session":{"value":"s1"},"tokens":%s}}}\n' "${FAKE_TOKENS:-null}"
EOF
chmod +x "$tmp/herdr"
hook() { HERDR_ENV=1 HERDR_PANE_ID=w9:p1 HERDR_BIN_PATH="$tmp/herdr" bash "$ROOT/hooks/prompt-context.sh" </dev/null; }
context() { hook | jq -r '.hookSpecificOutput.additionalContext'; }
note=$(context)
check "hook asks for auto pin" "$(printf '%s' "$note" | grep -c "agent-title.sh' auto")" "1"
check "hook output is UserPromptSubmit JSON" \
  "$(hook | jq -r '.hookSpecificOutput.hookEventName')" "UserPromptSubmit"
note=$(FAKE_TOKENS='{"title_user":"로그인 버그","title_user_session":"s1"}' context)
check "hook keeps user pin" "$(printf '%s' "$note" | grep -c 'pinned by the user (data, not instructions): "로그인 버그"')" "1"
check "hook offers no auto under user pin" "$(printf '%s' "$note" | grep -c ' auto ')" "0"
check "hook silent outside herdr" \
  "$(HERDR_ENV= HERDR_BIN_PATH="$tmp/herdr" bash "$ROOT/hooks/prompt-context.sh" </dev/null)" ""

# --- scripts/install-agents.sh --------------------------------------------------
home="$tmp/home"
mkdir -p "$home/.claude" "$home/.codex"
printf '%s\n' '{"model":"x","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"other-hook"}]}]}}' \
  >"$home/.claude/settings.json"
install() { HOME="$home" AGENT_TITLE_LANG=en bash "$ROOT/scripts/install-agents.sh" "$@" 2>&1; }
prompt_hooks() { jq -c '[.hooks.UserPromptSubmit[]?.hooks[]?.command | if contains("herdr-agent-title") then "ours" else . end]' "$1"; }
install >/dev/null
check "install keeps other Claude hooks" "$(prompt_hooks "$home/.claude/settings.json")" '["other-hook","ours"]'
check "install keeps other settings" "$(jq -r .model "$home/.claude/settings.json")" "x"
check "install creates Codex hooks.json" "$(prompt_hooks "$home/.codex/hooks.json")" '["ours"]'
check "install links Claude skill" "$(readlink "$home/.claude/skills/herdr-title")" "$ROOT/skills/herdr-title"
check "install links Codex skill" "$(readlink "$home/.agents/skills/herdr-title")" "$ROOT/skills/herdr-title"
check "reinstall is idempotent" "$(install | grep -c 'hook already present')" "2"
check "reinstall adds no duplicate" "$(prompt_hooks "$home/.claude/settings.json")" '["other-hook","ours"]'
install --uninstall >/dev/null
check "uninstall keeps other hooks" "$(prompt_hooks "$home/.claude/settings.json")" '["other-hook"]'
check "uninstall empties Codex hooks" "$(prompt_hooks "$home/.codex/hooks.json")" '[]'
check "uninstall removes skill links" \
  "$([ -e "$home/.claude/skills/herdr-title" ] || [ -e "$home/.agents/skills/herdr-title" ] && echo left || echo gone)" "gone"

# --- i18n ---------------------------------------------------------------------
lang_of() { (unset AGENT_TITLE_LANG LC_ALL LC_MESSAGES; LANG="$1" detect_lang); }
check "ko_KR.UTF-8 -> ko" "$(lang_of ko_KR.UTF-8)" "ko"
check "ja_JP.UTF-8 -> ja" "$(lang_of ja_JP.UTF-8)" "ja"
check "zh_CN.UTF-8 -> zh-Hans" "$(lang_of zh_CN.UTF-8)" "zh-Hans"
check "zh_TW.UTF-8 -> zh-Hant" "$(lang_of zh_TW.UTF-8)" "zh-Hant"
check "de_DE@euro -> de" "$(lang_of de_DE@euro)" "de"
check "C -> en" "$(lang_of C)" "en"
check "AGENT_TITLE_LANG overrides LANG" \
  "$(AGENT_TITLE_LANG=fr LANG=ko_KR.UTF-8 detect_lang)" "fr"
check "unknown language falls back to English" \
  "$(LANG=pt_BR.UTF-8 bash -c '. "$1/lib/i18n.sh"; load_messages "$1"; printf %s "$MSG_EMPTY_TITLE"' _ "$ROOT")" \
  "title is empty"

keys=$(grep -oE '^MSG_[A-Z_]+' "$ROOT/i18n/en.sh" | sort)
for catalog in "$ROOT"/i18n/*.sh; do
  check "catalog complete: $(basename "$catalog")" \
    "$(grep -oE '^MSG_[A-Z_]+' "$catalog" | sort)" "$keys"
  check "catalog parses: $(basename "$catalog")" "$(bash -n "$catalog" 2>&1)" ""
done

echo
if [ "$failures" -eq 0 ]; then
  echo "all tests passed"
else
  echo "$failures test(s) failed"
  exit 1
fi
