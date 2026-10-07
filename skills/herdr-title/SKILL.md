---
name: herdr-title
description: Use when running inside a herdr pane (HERDR_ENV=1) and the user, in any language, wants to set, change, pin, show, or reset the task title on the herdr pane border or sidebar — e.g. "set the title to…", "타이틀 바꿔줘", "タイトルを変えて", "把标题改成…", "把標題改成…", "cambia el título", "change le titre", "Titel ändern", "/herdr-title".
---

# herdr-title

Pins a task title on the calling herdr pane. herdr shows it as `<agent> · <title>` on the pane border and as the bare title in the sidebar. Backed by the `seeun.agent-title` herdr plugin; without a pin the agent's own terminal title is used.

## Commands

If `HERDR_ENV` is not `1`, say you are not inside herdr and stop.

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')

bash "$root/agent-title.sh" set "로그인 버그 수정"   # pin
bash "$root/agent-title.sh" clear                    # back to the auto title
bash "$root/agent-title.sh" show                     # current label / title
```

Report the `label:` line that `set` / `clear` prints. Output keys stay English; error messages follow the locale.

## Title

- Language: the user's language. User gave the text → use it verbatim.
- User gave none → summarize the current task in that language.
- Length: a short noun phrase of about 30 terminal columns. CJK characters and emoji take 2 columns, so aim for ~15 of them.
- Any script works (Hangul, kana, Han, Arabic, accented Latin, emoji); the plugin normalizes it.

## Notes

- A pin lasts for this agent session only; a new session in the same pane falls back to the auto title.
- Empty `$root` → the plugin is not installed. Tell the user to run `herdr plugin install chappse6/herdr-agent-title`.
- Codex: the sandbox can block herdr's socket. If a `herdr` call fails with a connection or permission error, rerun it with escalated permissions.
