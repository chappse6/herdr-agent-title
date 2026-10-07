---
name: herdr-title
description: Use when running inside a herdr pane (HERDR_ENV=1) and the user, in any language, wants to set, change, pin, show, or reset the pane title on the herdr border or sidebar — e.g. "set the title to…", "타이틀 바꿔줘", "タイトルを変えて", "把标题改成…", "cambia el título", "change le titre", "Titel ändern", "/herdr-title" — or when a task starts or changes inside herdr.
---

# herdr-title

herdr shows the calling pane's title as `<agent> · <title>` on the pane border and as the bare title in the sidebar. Backed by the `seeun.agent-title` herdr plugin.

## Two pins

Priority: user pin > agent pin > the agent's terminal title.

| Who chose the words | Command | Replaced by |
|---|---|---|
| The user named the title | `set "<their words>"` | only the user (`set` again or `clear`) |
| You, for your current task | `auto "<your title>"` | your next `auto`; hidden while a user pin exists |

## Commands

If `HERDR_ENV` is not `1`, say you are not inside herdr and stop.

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')

bash "$root/agent-title.sh" set "로그인 버그 수정"   # user's title, verbatim
bash "$root/agent-title.sh" auto "배포 스크립트 정리"  # your own title
bash "$root/agent-title.sh" clear                    # drop the user pin
bash "$root/agent-title.sh" show                     # label / title / source
```

Each command prints `label:`, `title:` and `source:` (`user`, `agent` or `terminal`). Report the `label:` line after `set` or `clear`.

## When to run `auto`

- When a task starts, and whenever the task changes. Skip it when the task is unchanged.
- Not while `source: user`: the user's title stays until the user changes it.
- A herdr hook note in your context, when installed, shows the current title and source on each prompt.

## Title

- Language: the user's language.
- `set`: the user's words, verbatim.
- `auto`: a short noun phrase for the task.
- Length: about 30 terminal columns. CJK characters and emoji take 2 columns, so aim for ~15 of them.

## Notes

- Pins last for this agent session only; a new session in the same pane falls back to the terminal title.
- "Reset the title" → `clear`. The title falls back to your `auto` pin, then the terminal title.
- Empty `$root` → the plugin is not installed. Tell the user to run `herdr plugin install chappse6/herdr-agent-title`.
- Codex: the sandbox can block herdr's socket. If a `herdr` call fails with a connection or permission error, rerun it with escalated permissions.
