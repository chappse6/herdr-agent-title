# Agent Title

[English](README.md) · [한국어](README.ko.md) · **日本語** · [简体中文](README.zh-CN.md)

エージェントのペインに作業内容を表示する [herdr](https://herdr.dev) プラグインです。

- ペインの枠 (左上): `claude · ログイン不具合の修正`
- サイドバー: `ログイン不具合の修正`

タイトルにはエージェント自身のターミナルタイトル (Claude Code はセッションごとに名前を付けます) か、自分で固定したタイトルを使います。どの言語・文字にも対応しています。タイトルは Unicode 正規化 (NFC) され、書記素単位で切り詰められるため、ハングル、かな、漢字、アラビア文字、アクセント付きラテン文字、絵文字の連結シーケンスも崩れません。

## インストール

```bash
herdr plugin install chappse6/herdr-agent-title
```

herdr 0.9.3 以降、`jq`、`perl` が必要です (macOS とほとんどの Linux に標準で入っています)。

`~/.config/herdr/config.toml` に以下を追加し、`herdr server reload-config` を実行します。

```toml
[ui]
pane_borders = "always"                  # ペインが 1 つでも枠を表示
show_agent_labels_on_pane_borders = true # 枠にラベルを表示

[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  ["$task"],                             # サイドバーはタイトルのみ
]
```

## タイトル

優先順位 (エージェントセッション単位): **ユーザーの固定 > エージェントの固定 > エージェントのターミナルタイトル**。

| 固定 | 決める人 | コマンド | 置き換わるとき |
|---|---|---|---|
| ユーザー | ユーザーがタイトルを指定 | `set "<タイトル>"` | ユーザーのみ (`set` し直すか `clear`) |
| エージェント | エージェントが現在の作業に合わせて | `auto "<タイトル>"` | エージェントの次の `auto`。ユーザーの固定があると隠れる |

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')
bash "$root/agent-title.sh" set "ログイン不具合の修正"   # ユーザーの固定
bash "$root/agent-title.sh" auto "デプロイ整理"         # エージェントの固定
bash "$root/agent-title.sh" clear                       # ユーザーの固定を解除
bash "$root/agent-title.sh" show                        # ラベル / タイトル / 出所
```

固定は、それを設定したエージェントセッションにのみ適用されます。同じペインで新しいセッションを始めるか herdr サーバーを再起動すると、ターミナルタイトルに戻ります。

### エージェント連携 (Claude Code / Codex)

```bash
herdr plugin action invoke seeun.agent-title.install-agents
```

両方のエージェントに次を接続します。

- **スキル** `herdr-title`: `~/.claude/skills` と `~/.agents/skills` にリンクされます。どの言語でタイトルを頼んでも (「タイトルを変えて」、"set the title to…"、「타이틀 바꿔줘」、「把标题改成…」)、エージェントが `set` で固定します。
- **プロンプトフック**: `~/.claude/settings.json` と `~/.codex/hooks.json` に登録されます。herdr 内でプロンプトを送るたびに現在のタイトルを含む短い案内を追加するため、エージェントは作業が始まったり変わったりしたときに `auto` で自分のタイトルを固定し、ユーザーの固定には触れません。herdr の外では何も出力しません。

新しいエージェントセッションから有効になります。解除は `herdr plugin action invoke seeun.agent-title.uninstall-agents` です。インストーラーが編集するファイルは `<ファイル>.bak-agent-title` としてバックアップされます。

## 言語

CLI メッセージは `AGENT_TITLE_LANG`、次に `LC_ALL` / `LC_MESSAGES` / `LANG` に従います。対応言語: English、한국어、日本語、简体中文、繁體中文、Español、Français、Deutsch。出力のキー (`label:`、`title:`、`source:`) はスクリプトで読めるよう英語のままです。

言語を追加するには、`i18n/en.sh` を `i18n/<コード>.sh` (例: `pt.sh`) にコピーして翻訳し、`bash tests/run.sh` を実行してください。

## ラベルが更新されるタイミング

- herdr サーバーの起動時
- `pane.agent_detected` と `pane.agent_status_changed`。エージェントが作業中なら 3 秒後と 10 秒後にもう一度確認し、Claude がプロンプトに合わせて付けた新しいタイトルを反映します
- `set` / `clear`
- 手動: `herdr plugin action invoke seeun.agent-title.refresh`

herdr 0.9.3 にはターミナルタイトルの変更に対するプラグインフックがないため、作業の途中で変わったタイトルは次の状態変化で反映されます。

## 仕組み

プラグインは `herdr pane report-metadata` でエージェントのペインごとに 2 つの値を報告します。

| 値 | 表示場所 | 内容 |
|---|---|---|
| `display_agent` | ペインの枠のラベル | `<agent> · <タイトル>` |
| `$task` トークン | サイドバーの行 | `<タイトル>` |

固定したタイトルは `title_user` / `title_agent` のペイントークンに保存され、それぞれ設定したエージェントセッション (`title_user_session`、`title_agent_session`) も記録されます。

## 開発

```bash
herdr plugin link "$PWD"   # 作業ツリーをリンク
bash tests/run.sh          # オフラインテスト (herdr 不要)
```

## ライセンス

MIT
