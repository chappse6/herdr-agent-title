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
