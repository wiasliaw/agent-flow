# agent-flow

一個 Claude Code plugin：把規格驅動開發（Spec-Driven Development, SDD）與測試驅動
開發（Test-Driven Development, TDD）結合成 waterfall 工作流程。這個 repo 同時是
plugin 根目錄與 marketplace 根目錄。

## repo 的兩個世界

| | 目錄 | 語言 |
|---|---|---|
| **plugin 執行期內容** | `skills/`（8 個 external skill）、`agents/`（`worker`／`reviewer`）、`references/`（6 份純 markdown）、`.claude-plugin/`、`scripts/` | **英文** |
| **開發脈絡** | `context/`（`PROMPT.md`／`DESIGN.md`／`research/`／`spec/`） | **繁體中文** |

語言規則沒有例外，包括 manifest 的 `description` 欄位與程式碼註解。

根目錄的 README 是第三種情形：`README.md` **英文**（對外門面），`README.zh-TW.md`
**繁體中文**。兩份**章節結構逐節對齊**，改其中一份就要改另一份的對應節——結構鎖死
是為了讓雙語版本長期不走鐘，不要在其中一份自行增刪章節。

## 動手前先讀

`context/README.md` — 權威鏈與各文件的效力狀態。三件最容易踩的事：

1. **實作的唯一依據是 `context/spec/`**，不是 `context/DESIGN.md`。後者的設計本文
   已被 2026-09-10 的 R1–R5 裁決推翻（八 phase／四承諾點／17 agent／internal
   skill／`approved-artifact` ESC 全數作廢），只剩訪談逐字記錄 Q1–Q40 供追溯。
2. **`context/PROMPT.md` 定義工作方式本身**，任何階段都不得自行放寬。
3. `context/research/` 的結論若與官方文件矛盾，以實驗為準。

## 不替使用者做決定

這是 `PROMPT.md` 的紅線，不是禮貌：

- 設計決策必須來自使用者的原話或他選的選項，不是你的推論。需要裁決時一次問一題、
  給選項、附你的建議；研究結果會影響選項的，先講結果再問。
- 規格的「待對齊」節**只有使用者能裁決**。裁決後把結論改寫進「規格本文」、刪除該
  項，並在 `context/spec/README.md` 登記。
- 規格沒寫到的實作細節，選最簡單的做法，做完用一行回報——不要為此發明規格。
- 每次只做使用者指定的「本次交付」，其餘不動。

## 寫 plugin 內容的體例

- **先讀 `references/glossary.md`**：所有 DSL 原語、變數、共用程序與 `INV-n` 都在
  那裡解析。
- SKILL.md 的程序段落用 pseudo-code DSL 寫控制流；散文只留使用者可見文案、產物
  格式、設計理由三種。找不到適用分支就 `halt` 問使用者，不自行發明路由
  （closed-world rule）。
- **`INV-n` 的全文只存在 `references/glossary.md`**，其他檔案一律只引編號、不複述
  規則內容。
- 派工前把 `${CLAUDE_PLUGIN_ROOT}` 展開成絕對路徑——子代理與 worktree 解析不了
  plugin 相對路徑。
- 只有 `worker`（sonnet，作者／執行）與 `reviewer`（opus，唯讀審查）兩個
  general-purpose agent。角色差異由派工時的角色簡報五要素＋指名的 reference 表達，
  不新增 agent 檔。
- agent frontmatter 禁用 `hooks`／`mcpServers`／`permissionMode`／`skills`／
  `isolation`，也不得授予 `Agent` 工具（禁止巢狀派工）。`isolation: "worktree"` 是
  Agent tool 的呼叫時參數，不是 agent 定義欄位。
- **agent 的 `name` 只寫裸名**（`worker`／`reviewer`）。命名空間
  `agent-flow:<name>` 由平台自動衍生，寫進 `name` 會變成
  `agent-flow:agent-flow:worker`，而 `validate` 不會擋（research 11 §3.5 實測）。
  只有派工端才寫命名空間形式。

## 驗證

每完成一個檔案就跑，不要累積到最後：

```sh
claude plugin validate .claude-plugin/plugin.json       # manifest ＋ 遞迴驗證 8 skill / 2 agent
claude plugin validate .claude-plugin/marketplace.json  # marketplace manifest
./scripts/mechanical-check.sh                            # validate 查不到的部分
```

指向 `plugin.json` 就會連 `skills/` 與 `agents/` 一起驗完，元件有錯時 exit 1；輸出
只列出有問題的元件，沒被列出代表通過。路徑要指到檔案，不要指到目錄——`.claude-plugin/`
下同時有兩份 manifest 時 marketplace 優先（research 10【證實】）。

validate 本身檢查很淺：不查未知欄位、不查 plugin agent 的禁用欄位、完全不涉及
`references/`。`scripts/mechanical-check.sh` 補的就是這兩塊——不能只跑 validate。
兩道 validate 目前零警告，加 `--strict` 也通過。

**本檔要留在 `.claude/`**，不要搬到 repo 根目錄——放根目錄會讓 validate 發出
「CLAUDE.md at the plugin root is not loaded as project context」警告並使 `--strict`
失敗。`.claude/` 位置的載入效果相同（research 10 §5.1【證實】）。`.gitignore` 因此
寫成 `.claude/*` ＋ `!.claude/CLAUDE.md`，改回 `.claude/` 會讓本檔脫離版控。

## 平台行為存疑時

不要猜，做小實驗：放 `/tmp`、用便宜模型（Haiku）headless 跑、**不寫入
`~/.claude/`**。結論寫進 `context/research/` 並附來源 URL，查不到就標「未記載」。

本機 `~/.claude/settings.json` 含 `defaultMode: bypassPermissions` 與 `Bash(*)`
allowlist，與終端使用者的預設環境不同。測任何權限相關行為必須加
`--permission-mode default`，否則結果無效——這個坑已經汙染過一次實驗
（`context/research/README.md` 環境備註）。
