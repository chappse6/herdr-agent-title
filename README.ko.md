# Agent Title

[English](README.md) · **한국어** · [日本語](README.ja.md) · [简体中文](README.zh-CN.md)

agent pane에 지금 하는 작업을 표시하는 [herdr](https://herdr.dev) 플러그인입니다.

- pane 테두리 (왼쪽 위): `claude · 로그인 버그 수정`
- 사이드바: `로그인 버그 수정`

타이틀은 agent가 직접 정한 터미널 타이틀(Claude Code는 세션마다 이름을 붙입니다)을 쓰거나, 직접 고정한 타이틀을 씁니다. 어떤 언어와 문자든 지원합니다. 타이틀은 유니코드 정규화(NFC)를 거치고 글자 단위로 잘리기 때문에 한글, 가나, 한자, 아랍 문자, 악센트가 붙은 라틴 문자, 이모지가 깨지지 않습니다.

## 설치

```bash
herdr plugin install chappse6/herdr-agent-title
```

herdr 0.9.3 이상, `jq`, `perl`이 필요합니다 (macOS와 대부분의 Linux에 기본 설치).

`~/.config/herdr/config.toml`에 아래를 추가하고 `herdr server reload-config`를 실행하세요.

```toml
[ui]
pane_borders = "always"                  # pane이 하나여도 테두리 표시
show_agent_labels_on_pane_borders = true # 테두리에 라벨 표시

[ui.sidebar.agents]
rows = [
  ["state_icon", "machine", "workspace", "tab"],
  ["$task"],                             # 사이드바에는 타이틀만
]
```

## 타이틀 고정

herdr pane 안에서:

```bash
root=$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "seeun.agent-title") | .plugin_root')
bash "$root/agent-title.sh" set "로그인 버그 수정"   # 이 pane에 고정
bash "$root/agent-title.sh" clear                    # 자동 타이틀로 복귀
bash "$root/agent-title.sh" show                     # 라벨 / 타이틀 출력
```

고정한 타이틀은 그것을 설정한 agent 세션에만 적용됩니다. 같은 pane에서 새 세션을 시작하거나 herdr 서버를 재시작하면 자동 타이틀로 돌아갑니다.

### Agent skill (Claude Code / Codex)

함께 들어 있는 `herdr-title` skill을 쓰면 어떤 언어로 요청해도 agent가 타이틀을 고정합니다 ("타이틀 바꿔줘", "set the title to…", "タイトルを変えて", "把标题改成…").

```bash
herdr plugin action invoke seeun.agent-title.install-skill
```

skill이 `~/.claude/skills`(Claude Code)와 `~/.agents/skills`(Codex)에 연결됩니다. 새 agent 세션부터 적용됩니다.

## 언어

CLI 메시지는 `AGENT_TITLE_LANG`, 그다음 `LC_ALL` / `LC_MESSAGES` / `LANG`을 따릅니다. 지원 언어: English, 한국어, 日本語, 简体中文, 繁體中文, Español, Français, Deutsch. 출력 키(`label:`, `title:`, `pinned:`)는 스크립트가 읽을 수 있도록 영어로 유지합니다.

언어를 추가하려면 `i18n/en.sh`를 `i18n/<코드>.sh`(예: `pt.sh`)로 복사해 번역하고 `bash tests/run.sh`를 실행하세요.

## 라벨이 갱신되는 시점

- herdr 서버 시작
- `pane.agent_detected`, `pane.agent_status_changed`. agent가 작업 중이면 3초, 10초 뒤에 한 번 더 확인해 Claude가 프롬프트에 맞춰 새로 정한 타이틀을 반영합니다
- `set` / `clear`
- 수동: `herdr plugin action invoke seeun.agent-title.refresh`

herdr 0.9.3에는 터미널 타이틀 변경에 대한 플러그인 hook이 없어서, 작업 도중 바뀐 타이틀은 다음 상태 변경 때 반영됩니다.

## 동작 방식

플러그인은 `herdr pane report-metadata`로 agent pane마다 두 값을 보고합니다.

| 값 | 표시 위치 | 내용 |
|---|---|---|
| `display_agent` | pane 테두리 라벨 | `<agent> · <타이틀>` |
| `$task` 토큰 | 사이드바 행 | `<타이틀>` |

고정한 타이틀은 `title_override`, `title_session` pane 토큰에 저장됩니다.

## 개발

```bash
herdr plugin link "$PWD"   # 작업 중인 폴더를 연결
bash tests/run.sh          # 오프라인 테스트, herdr 불필요
```

## 라이선스

MIT
