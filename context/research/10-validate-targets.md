# 10｜`claude plugin validate` 的目標解析與遞迴範圍

調查目的：`spec/01-plugin-structure.md` §2.5.1 記載的逐路徑驗證程序有兩處與實際行為
不符——(A) 表中第一列 `claude plugin validate .` 標示為「驗 `plugin.json`」，但本 repo
根目錄同時有 `marketplace.json`，實際驗到的是 marketplace manifest，`plugin.json`
完全沒被檢查；(B) `research/09` §4 記載 per-directory 驗證失敗、判定「現行 CLI 下不
可用」，但未查明成因。本報告實測釐清 validate 如何解析目標路徑、遞迴到哪裡為止，
作為 §2.5.1 修訂的依據。

- **環境**：Claude Code CLI 2.1.259，macOS（2026-09-14）。與 `research/09` §4 同一
  版本——下列差異**不是**版本變更造成的。
- **方法**：`/tmp/af-validate-exp/` 沙箱建最小 plugin（`plugin.json` ＋
  `marketplace.json` ＋ 2 個 agent ＋ 2 個 skill，其中各 1 個故意壞掉），逐一改變
  驗證目標觀察輸出與 exit code。全程唯讀本機設定，未寫入 `~/.claude/`。
- 來源比對：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)、
  `claude plugin validate --help`。官方文件對「目標路徑如何解析」**未記載**。

## 1. 目標解析規則【證實】

`claude plugin validate <path>` 依 `<path>` 的型態走三條互斥的路：

| `<path>` | 實際行為 |
|---|---|
| 指到 `plugin.json` | `Validating plugin manifest:` — 驗 manifest **並遞迴驗證整個 plugin 的 skills／agents**（見 §2） |
| 指到 `marketplace.json` | `Validating marketplace manifest:` — 只驗 marketplace 必填欄位與 `plugins[].source` |
| 指到目錄 | 先找該目錄下的 `.claude-plugin/marketplace.json` 或 `plugin.json`；**找到 marketplace 就只驗 marketplace**（plugin manifest 不會被驗到）。找不到 manifest 時，看目錄 basename 是否為元件目錄名 |

### 1.1 `validate .` 在本 repo 只驗 marketplace【證實】

```
$ claude plugin validate .
Validating marketplace manifest: .../.claude-plugin/marketplace.json
✔ Validation passed
```

沙箱重現相同行為。本 repo 是「repo 根＝plugin 根＝marketplace 根」（Q17），兩份
manifest 同處一個 `.claude-plugin/`，marketplace 優先。**結論：`validate .` 永遠驗
不到本 repo 的 `plugin.json`，必須明確指到 `.claude-plugin/plugin.json`。**

### 1.2 目錄驗證取決於 basename【證實】

`research/09` §4 記載 `claude plugin validate ./skills/external` 失敗
（`No manifest found in directory`）而 `./skills` 可用，當時未查明成因。實測為
**basename 規則**，不是版本變更：

```
$ claude plugin validate <p>/skills/group      # basename "group"
✘ directory: No manifest found in directory. Expected
  .claude-plugin/marketplace.json or .claude-plugin/plugin.json

$ claude plugin validate <p>/nest/skills       # basename "skills"，深兩層仍可用
Validating components in: <p>/nest/skills
✔ Validation passed
```

目錄 basename 必須是元件目錄名（`skills`／`agents`／`commands`）才會走
`Validating components in:`；否則一律當成 plugin 根目錄找 manifest 而失敗。與路徑
深度無關。R4 平鋪之後本 repo 已無 `skills/external` 這類分組目錄，此限制不再影響
agent-flow。

## 2. `plugin.json` 驗證會遞迴到元件【證實，推翻 research/05】

`research/05` 實驗五結論稱 validate「不遞迴掃描 plugin 根目錄下所有元件（一次只驗證
你明確指定的路徑）」。實測**推翻**此點：指向 `plugin.json` 時會一併驗證該 plugin 的
所有 skill 與 agent。

沙箱測試 B：只留一個壞掉的 agent（YAML 無法解析），**只**驗 `plugin.json`：

```
$ claude plugin validate <p>/.claude-plugin/plugin.json; echo $?
Validating plugin manifest: <p>/.claude-plugin/plugin.json
Validating agent: <p>/agents/badagent.md
✘ Found 1 error:
  ❯ frontmatter: YAML frontmatter failed to parse: ...
✘ Validation failed
1
```

**關鍵觀察：clean 的元件不會被列出。** 測試 A 把壞檔全部移除後，輸出只剩 manifest
一行——「沒列出 skills／agents」代表它們全部乾淨，不代表沒被掃描。這一點容易誤判為
「沒有遞迴」，推測也是 `research/05` 當初的誤讀來源。

**推論：`claude plugin validate ./agents` 與 `./skills` 對本 repo 是多餘的**——
`validate .claude-plugin/plugin.json` 已完整涵蓋，且錯誤時 exit code 為 1。

## 3. 錯誤訊息文案已修正【證實】

`research/05` §5c【推翻】指出 validate 對 YAML 解析失敗的 agent 宣稱「At runtime this
agent does not load at all... skipped」與實測矛盾（實際會用檔名載入）。2.1.259 的訊息
已改為：

> At runtime this agent loads with its name taken from the filename and every other
> frontmatter field silently dropped.

與 `research/05` 的實測結論一致。該筆【推翻】記錄的**事實判斷仍然成立**，但「validate
錯誤訊息文案不可信」這句評語對現行版本已不適用。

## 4. 仍然檢查不到的項目（`scripts/mechanical-check.sh` 的存在理由不變）

遞迴驗證不改變 `research/05` 實驗五的核心結論——檢查深度仍然很淺：

- 不檢查未知或不該出現的 frontmatter 欄位（`hooks`／`mcpServers`／`permissionMode`／
  `skills`／`isolation` 在 plugin agent 中一律放行）。
- 完全不涉及 `references/`——那不是 plugin 元件，6 份檔案缺任何一份都不會被發現，
  只會在執行期 `Read` 失敗。

這兩塊仍須由 `scripts/mechanical-check.sh` 補，不能只跑 validate。

## 5. 附帶發現：plugin 根目錄的 `CLAUDE.md` 會觸發警告（已解決，R8）

驗 `plugin.json` 時對本 repo 新增的根目錄 `CLAUDE.md` 發出：

> root: CLAUDE.md at the plugin root is not loaded as project context. To ship context
> with your plugin, use a skill (skills/<name>/SKILL.md) instead.

針對的是「想把 context 隨 plugin 出貨給安裝者」的情境。本 repo 的 `CLAUDE.md` 是給
開發者用的、不打算讓安裝者載入，屬誤報。但 `--strict` 會把它升級成錯誤
（`✘ Validation failed (--strict treats warnings as errors)`）。

### 5.1 解法：移入 `.claude/CLAUDE.md`【證實】

前提是 `<專案>/.claude/CLAUDE.md` 真的會被當專案 context 載入——官方文件對這個位置
**未記載**，故實測。沙箱三組對照，headless `-p` ＋ Haiku ＋
`--disallowedTools "Read,Glob,Grep,Bash,..."`（禁用工具，確保答案只能來自自動載入的
context 而非現場讀檔），各問「專案代號是什麼」：

| 組別 | 佈局 | 回答 |
|---|---|---|
| a | `.claude/CLAUDE.md` 內含代號 `ZARQUON-7742` | `ZARQUON-7742` |
| b | 根目錄 `CLAUDE.md` 內含代號 `BOROGROVE-1183`（正對照） | `BOROGROVE-1183` |
| c | 無任何 context 檔（負對照） | `NONE` |

**結論【證實】**：`.claude/CLAUDE.md` 與根目錄 `CLAUDE.md` 的載入效果相同，負對照排除
了猜測。移入後在本 repo 重驗：`claude plugin validate .claude-plugin/plugin.json`
與加上 `--strict` 皆 `✔ Validation passed`、零警告、exit 0。

**連帶陷阱**：`.gitignore` 原本寫 `.claude/`，會把 `CLAUDE.md` 一起忽略掉。必須改成
`.claude/*` ＋ `!.claude/CLAUDE.md`——git 的否定規則無法挖回被整個排除的目錄下的檔案，
排除目標必須是目錄「內容」而非目錄本身。以 `git status --porcelain` 與
`git add --dry-run` 驗證：`CLAUDE.md` 可加入版控，`settings.json` 維持忽略。

## 6. 未實測項目

| 項目 | 原因 |
|---|---|
| 指向 `plugin.json` 時是否也遞迴 `commands/`／`hooks/` | 本 plugin 無這兩類元件，無從觀察 |
| marketplace 有多個 `plugins[]` 條目時是否逐一遞迴其 plugin.json | 本 repo 只有一個條目 |
