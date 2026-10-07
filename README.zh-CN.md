# Agent Title

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **简体中文**

一个 [herdr](https://herdr.dev) 插件，在智能体窗格上显示它正在做的工作。

- 窗格边框 (左上角): `claude · 修复登录错误`
- 侧边栏: `修复登录错误`

标题来自智能体自己的终端标题 (Claude Code 会为每个会话命名)，或者来自你手动固定的标题。支持任何语言和文字：标题会经过 Unicode 规范化 (NFC)，并按字素边界截断，因此韩文、假名、汉字、阿拉伯文、带重音的拉丁字母以及组合表情符号都不会被截坏。

## 安装

```bash
herdr plugin install chappse6/herdr-agent-title
```

需要 herdr 0.9.3 及以上版本、`jq` 和 `perl` (macOS 和大多数 Linux 发行版已预装)。

然后在 `~/.config/herdr/config.toml` 中添加以下内容，并运行 `herdr server reload-config`:

```toml
[ui]
pane_borders = "always"                  # 单个窗格也绘制边框
show_agent_labels_on_pane_borders = true # 在边框上显示标签

[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  ["$task"],                             # 侧边栏只显示标题
]
```

## 标题

优先级 (按智能体会话): **用户固定 > 智能体固定 > 智能体的终端标题**。

| 固定 | 由谁决定 | 命令 | 何时被替换 |
|---|---|---|---|
| 用户 | 用户指定标题 | `set "<标题>"` | 只有用户 (再次 `set` 或 `clear`) |
| 智能体 | 智能体根据当前任务 | `auto "<标题>"` | 智能体的下一次 `auto`；存在用户固定时被隐藏 |

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')
bash "$root/agent-title.sh" set "修复登录错误"    # 用户固定
bash "$root/agent-title.sh" auto "整理部署脚本"   # 智能体固定
bash "$root/agent-title.sh" clear                 # 取消用户固定
bash "$root/agent-title.sh" show                  # 标签 / 标题 / 来源
```

固定只对设置它的那个智能体会话生效。在同一窗格中开始新会话，或重启 herdr 服务器后，会恢复为终端标题。

### 智能体集成 (Claude Code / Codex)

```bash
herdr plugin action invoke seeun.agent-title.install-agents
```

为两个智能体接入:

- **技能** `herdr-title`: 链接到 `~/.claude/skills` 和 `~/.agents/skills`。无论用哪种语言请求标题 (“把标题改成…”、"set the title to…"、“타이틀 바꿔줘”、“タイトルを変えて”)，智能体都会用 `set` 固定。
- **提示钩子**: 注册到 `~/.claude/settings.json` 和 `~/.codex/hooks.json`。在 herdr 中每次发送提示时，它会附加一段包含当前标题的简短说明，于是智能体在任务开始或变化时用 `auto` 固定自己的标题，而不会改动用户固定的标题。在 herdr 之外不输出任何内容。

从新的智能体会话开始生效。撤销: `herdr plugin action invoke seeun.agent-title.uninstall-agents`。安装脚本修改的每个文件都会备份为 `<文件>.bak-agent-title`。

## 语言

CLI 消息依次参考 `AGENT_TITLE_LANG`、`LC_ALL` / `LC_MESSAGES` / `LANG`。支持: English、한국어、日本語、简体中文、繁體中文、Español、Français、Deutsch。输出键 (`label:`、`title:`、`source:`) 保持英文，便于脚本解析。

添加新语言: 将 `i18n/en.sh` 复制为 `i18n/<代码>.sh` (例如 `pt.sh`)，翻译其中的值，然后运行 `bash tests/run.sh`。

## 标签何时刷新

- herdr 服务器启动时
- `pane.agent_detected` 和 `pane.agent_status_changed`；智能体工作中时，插件会在 3 秒和 10 秒后再检查一次，以获取 Claude 为该提示生成的新标题
- `set` / `clear`
- 手动: `herdr plugin action invoke seeun.agent-title.refresh`

herdr 0.9.3 没有针对终端标题变化的插件钩子，因此在一轮工作中途变化的标题会在下一次状态变化时显示。

## 工作原理

插件通过 `herdr pane report-metadata` 为每个智能体窗格上报两个值:

| 值 | 显示位置 | 内容 |
|---|---|---|
| `display_agent` | 窗格边框标签 | `<agent> · <标题>` |
| `$task` 令牌 | 侧边栏行 | `<标题>` |

固定的标题保存在 `title_user` / `title_agent` 窗格令牌中，并分别记录设置它的智能体会话 (`title_user_session`、`title_agent_session`)。

## 开发

```bash
herdr plugin link "$PWD"   # 使用工作目录
bash tests/run.sh          # 离线测试，无需 herdr
```

## 许可证

MIT
