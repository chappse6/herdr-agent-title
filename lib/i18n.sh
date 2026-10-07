# Message catalogs for user-facing CLI output. Sourced, not executed.
# Language: $AGENT_TITLE_LANG, then the usual locale variables; English fallback.
# Catalogs live in i18n/<lang>.sh and define the MSG_* variables from en.sh.

detect_lang() {
  local l="${AGENT_TITLE_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"
  l="${l%%.*}"
  l="${l%%@*}"
  case "$l" in
    zh_TW* | zh_HK* | zh_MO* | zh-TW* | zh-HK* | zh-MO* | zh-Hant* | zh_Hant*) echo zh-Hant ;;
    zh*) echo zh-Hans ;;
    "" | C | POSIX) echo en ;;
    *) echo "${l%%[_-]*}" ;;
  esac
}

# $1: directory holding the i18n/ catalogs.
load_messages() {
  local lang
  lang=$(detect_lang)
  . "$1/i18n/en.sh"
  if [ "$lang" != en ] && [ -f "$1/i18n/$lang.sh" ]; then
    . "$1/i18n/$lang.sh"
  fi
}
