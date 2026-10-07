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

## Titles

Priority, per agent session: **user pin > agent pin > the agent's terminal title**.

| Pin | Chosen by | Command | Replaced by |
|---|---|---|---|
| user | you name the title | `set "<title>"` | only you (`set` again or `clear`) |
| agent | the agent, for its current task | `auto "<title>"` | the agent's next `auto`; hidden under a user pin |

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')
bash "$root/agent-title.sh" set "Fix login bug"     # user pin
bash "$root/agent-title.sh" auto "Clean up deploy"  # agent pin
bash "$root/agent-title.sh" clear                   # drop the user pin
bash "$root/agent-title.sh" show                    # label / title / source
```

Pins apply only to the agent session that set them. A new session in the same pane, or a herdr server restart, falls back to the terminal title.

### Agent integration (Claude Code / Codex)

```bash
herdr plugin action invoke seeun.agent-title.install-agents
```

This connects both agents:

- **Skill** `herdr-title`, linked into `~/.claude/skills` and `~/.agents/skills`. When you ask for a title in any language ("set the title to…", "타이틀 바꿔줘", "タイトルを変えて", "把标题改成…"), the agent pins it with `set`.
- **Prompt hook** in `~/.claude/settings.json` and `~/.codex/hooks.json`. On each prompt inside herdr it adds a short note with the current title, so the agent pins its own title with `auto` when a task starts or changes, and leaves your pin alone. Outside herdr it prints nothing.

Start a new agent session to pick them up. Undo with `herdr plugin action invoke seeun.agent-title.uninstall-agents`. Every file the installer edits is backed up as `<file>.bak-agent-title`.

## Languages

CLI messages follow `AGENT_TITLE_LANG`, then `LC_ALL` / `LC_MESSAGES` / `LANG`: English, 한국어, 日本語, 简体中文, 繁體中文, Español, Français, Deutsch. Output keys (`label:`, `title:`, `source:`) stay English so scripts can parse them.

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

Pins are stored as the `title_user` / `title_agent` pane tokens, each with the agent session that set it (`title_user_session`, `title_agent_session`).

## Development

```bash
herdr plugin link "$PWD"   # use the working tree
bash tests/run.sh          # offline tests, no herdr needed
```

## License

MIT
