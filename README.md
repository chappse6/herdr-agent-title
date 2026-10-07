# Agent Title

**English** · [한국어](README.ko.md) · [日本語](README.ja.md) · [简体中文](README.zh-CN.md)

A [herdr](https://herdr.dev) plugin that labels agent panes with what they are working on.

- Pane border (top-left): `claude · Fix login bug`
- Sidebar: `Fix login bug`

The title comes from the agent's own terminal title (Claude Code names each session), or from a title you pin yourself. Any language and script works: titles are Unicode-normalized (NFC) and cut on grapheme boundaries, so Hangul, kana, Han, Arabic, accented Latin and emoji sequences never break.

## Install

```bash
herdr plugin install chappse6/herdr-agent-title
```

Requires herdr 0.9.3+, `jq` and `perl` (preinstalled on macOS and most Linux distributions).

Then add to `~/.config/herdr/config.toml` and run `herdr server reload-config`:

```toml
[ui]
pane_borders = "always"                  # frame single panes too
show_agent_labels_on_pane_borders = true # show the label on the border

[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  ["$task"],                             # title only in the sidebar
]
```

## Pin a title

Inside a herdr pane:

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')
bash "$root/agent-title.sh" set "Fix login bug"   # pin on this pane
bash "$root/agent-title.sh" clear                 # back to the auto title
bash "$root/agent-title.sh" show                  # print label / title
```

A pin applies only to the agent session that set it. A new session in the same pane goes back to the auto title, and so does a herdr server restart.

### Agent skill (Claude Code / Codex)

The bundled `herdr-title` skill lets an agent pin titles when you ask in any language ("set the title to…", "타이틀 바꿔줘", "タイトルを変えて", "把标题改成…").

```bash
herdr plugin action invoke seeun.agent-title.install-skill
```

This links the skill into `~/.claude/skills` (Claude Code) and `~/.agents/skills` (Codex). Start a new agent session to pick it up.

## Languages

CLI messages follow `AGENT_TITLE_LANG`, then `LC_ALL` / `LC_MESSAGES` / `LANG`: English, 한국어, 日本語, 简体中文, 繁體中文, Español, Français, Deutsch. Output keys (`label:`, `title:`, `pinned:`) stay English so scripts can parse them.

To add a language, copy `i18n/en.sh` to `i18n/<code>.sh` (for example `pt.sh`), translate the values, and run `bash tests/run.sh`.

## When labels refresh

- herdr server startup
- `pane.agent_detected` and `pane.agent_status_changed`; while an agent is working, the plugin checks again after 3 s and 10 s to catch Claude's new title for the prompt
- `set` / `clear`
- manually: `herdr plugin action invoke seeun.agent-title.refresh`

herdr 0.9.3 has no plugin hook for terminal title changes, so a title that changes in the middle of a turn appears at the next status change.

## How it works

The plugin reports two values per agent pane through `herdr pane report-metadata`:

| Value | Shown in | Content |
|---|---|---|
| `display_agent` | pane border label | `<agent> · <title>` |
| `$task` token | sidebar rows | `<title>` |

Pinned titles are stored as the `title_override` and `title_session` pane tokens.

## Development

```bash
herdr plugin link "$PWD"   # use the working tree
bash tests/run.sh          # offline tests, no herdr needed
```

## License

MIT
