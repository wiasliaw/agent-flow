# 01｜Plugin 結構規格

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 一、已定（來源與依據）

- **PROMPT.md 第 4 步**：規格對齊須把設計逐需求展開為可直接實作的規格；第 5 步要求「每個檔案完成就跑 `claude plugin validate` 等驗證，不要累積到最後」——這是本檔要求「逐路徑分次驗證」的直接依據。
- **Q17**（DESIGN.md 訪談記錄）：「Repo 自帶 marketplace」——本 repo 同時是 marketplace 根目錄與 plugin 根目錄，安裝方式為 `claude plugin marketplace add` + `claude plugin install`。
- **Q26**：「規格對齊時更新骨架」——本 repo 訪談前已建立的 `.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json` 骨架，與設計不一致之處在本檔（規格對齊階段）修正。
- **Q37–Q39**：skills 分 external（9 個，使用者觸發）／internal（6 個，`user-invocable: false`）兩層，對應骨架既有的 `"skills": ["./skills/external", "./skills/internal"]` 設定——此設定本身**保留**，不修正。
- **DESIGN.md 第 9 節「旁註」**：明確裁決骨架的「nine phases」「Workflow tool」敘述與設計（八 phase、以 Agent tool 為主要派工機制）不一致，「留待下一步『規格對齊』時更新骨架文字本身」——本檔即該次更新。
- **DESIGN.md 第 2 節**：orchestrator 一律以 Agent tool 呼叫子代理（`subagent_type: agent-flow:<role>`），不使用 Dynamic Workflow 腳本；非目標章節明文「Dev phase 不用 headless worker 程序或 Dynamic Workflow 腳本作主要平行機制」。
- **DESIGN.md 第 5 節**：17 個角色子代理清單（表格 15 列，其中 Review 平行小組一列展開為 3 個獨立角色，故 agents/ 目錄實際為 17 個檔案）。
- **research 01 §1.1**：`plugin.json` 完整欄位表，`skills` 欄位型別 `string|array`、語意「疊加」預設 `skills/`；§1.4：`marketplace.json` schema、plugin 條目 `strict`（預設 `true`：`plugin.json` 為權威來源，marketplace 條目只是補充展示用）、保留 marketplace 名稱清單（`agent-flow` 不在其中）。
- **research 01 §6.2、§7**：`claude plugin validate` 的路徑語意（可指向 plugin 根目錄、單一元件目錄，或 marketplace manifest）；安裝範圍（`user`/`project`/`local`/`managed`）與 `claude plugin marketplace add`／`claude plugin install` 兩階段流程。
- **research 05 實驗五**（【證實】）：`claude plugin validate <path>` 只驗證明確指定的那個路徑，指向 plugin 根目錄時只驗證 `plugin.json`，`contents` 恆為空、**不會**自動連帶掃描 `agents/`／`skills/` 等目錄；且只檢查「manifest 已知欄位缺失」與「agent/skill 檔案 YAML 是否可解析＋是否有 `description`」，**不檢查**未知欄位、**不檢查** plugin agent 誤用 `hooks`/`mcpServers`/`permissionMode`（即使 `--strict` 也一樣不查）。
- **DESIGN.md 第 10 節 (a)**：`skills/external/`、`skills/internal/` 這種巢狀分組目錄是否受平台支援，屬「高信心推論、非逐字實測」的殘餘不確定性，設計文件建議「實作階段用 `claude plugin validate` 或 `--plugin-dir` 對這個確切目錄結構跑一次最小可行範例」——本檔第三節即該驗證程序的規格化。

---

## 二、規格本文

### 2.1 `.claude-plugin/plugin.json` 目標內容

以下是規格對齊後、可直接落地的完整檔案內容。與現有骨架相比，**只修正 `description` 欄位**（移除「nine phases」與「Workflow tool」的錯誤敘述，改為與 DESIGN.md 一致的八 phase／Agent tool 派工敘述），其餘欄位（`name`／`version`／`author`／`repository`／`license`／`keywords`／`skills`）維持不動：

```json
{
  "$schema": "https://anthropic.com/claude-code/plugin.schema.json",
  "name": "agent-flow",
  "version": "0.1.0",
  "description": "Composable spec-driven development workflow: eight phases (Discuss, Explore, Prototype, Spec, Ticket, Dev, Review, Wrap), each closed by an independent quality loop dispatched via the Agent tool from a main-session orchestrator.",
  "author": { "name": "wiasliaw", "email": "wiasliaw@protonmail.com" },
  "repository": "https://github.com/wiasliaw/agent-flow",
  "license": "MIT",
  "keywords": ["spec-driven-development", "workflow", "quality-loop", "orchestration", "sdd"],
  "skills": ["./skills/external", "./skills/internal"]
}
```

**未變動欄位的理由**：`skills` 陣列（`["./skills/external", "./skills/internal"]`）是骨架中唯一與 Q37–Q39 的兩層 skills 設計直接對應的欄位，本身正確，不修正（Q26 的修正範圍僅止於「與設計矛盾之處」）。`agents` 欄位刻意**不新增**——17 個角色定義檔全部放在預設位置 `agents/*.md`，依 research 01 §1.1／§2.1，預設目錄會被自動掃描，不需要在 `plugin.json` 額外宣告 `agents` 欄位覆寫路徑。

### 2.2 `.claude-plugin/marketplace.json` 目標內容

現有骨架內容**維持不動**：

```json
{
  "name": "agent-flow",
  "owner": { "name": "wiasliaw", "email": "wiasliaw@protonmail.com" },
  "description": "Marketplace for the agent-flow plugin (this repository is the plugin)",
  "plugins": [
    {
      "name": "agent-flow",
      "source": "./",
      "description": "Composable spec-driven development workflow with independent quality loops",
      "version": "0.1.0",
      "author": { "name": "wiasliaw" },
      "repository": "https://github.com/wiasliaw/agent-flow",
      "license": "MIT",
      "category": "workflow",
      "tags": ["sdd", "workflow", "quality-loop"]
    }
  ]
}
```

**判斷依據**：此檔案的 `plugins[0].description` 沒有「nine phases」或「Workflow tool」字樣，與設計本身不矛盾，故 Q26 的修正範圍不適用於本檔。且 marketplace 條目未設定 `strict: false`，依 research 01 §1.4，預設 `strict: true` 代表 `plugin.json` 才是元件定義的權威來源，此處 `description` 只是 marketplace 瀏覽介面的展示文字、非強制要與 `plugin.json` 逐字一致，故不需要為了對齊而改動。

### 2.3 完整目錄樹

```
agent-flow/                              # 本 repo 根目錄 = plugin 根目錄 = marketplace 根目錄（Q17）
├── .claude-plugin/
│   ├── plugin.json                      # §2.1
│   └── marketplace.json                 # §2.2
├── agents/                               # 17 個角色定義檔，預設路徑，plugin.json 不覆寫（規格見 spec/03-agents.md）
│   ├── intent-reviewer.md
│   ├── explorer.md
│   ├── explore-reviewer.md
│   ├── prototyper.md
│   ├── prototype-reviewer.md
│   ├── spec-writer.md
│   ├── spec-reviewer.md
│   ├── ticket-writer.md
│   ├── ticket-reviewer.md
│   ├── dev-worker.md
│   ├── dev-reviewer.md
│   ├── review-gap-hunter.md
│   ├── review-edge-case-hunter.md
│   ├── review-spec-compliance-auditor.md
│   ├── review-triage.md
│   ├── wrap-executor.md
│   └── wrap-verifier.md
├── skills/
│   ├── external/                         # 9 個，使用者觸發，規格見 spec/05–13
│   │   ├── orchestrate/SKILL.md
│   │   ├── discuss/SKILL.md
│   │   ├── explore/SKILL.md
│   │   ├── prototype/SKILL.md
│   │   ├── spec/SKILL.md
│   │   ├── ticket/SKILL.md
│   │   ├── dev/SKILL.md
│   │   ├── review/SKILL.md
│   │   └── wrap/SKILL.md
│   └── internal/                         # 6 個，user-invocable: false，規格見 spec/04-internal-skills.md
│       ├── state-management/SKILL.md
│       ├── sdd-guide/SKILL.md
│       ├── tdd-guide/SKILL.md
│       ├── parallel-dispatch/SKILL.md
│       ├── using-worktree/SKILL.md
│       └── quality-loop/SKILL.md
├── PROMPT.md                              # 開發流程文件，非 plugin 執行期內容
├── DESIGN.md                              # 同上
├── research/                              # 同上
├── spec/                                  # 同上（本規格集本身）
└── README.md                              # 現有極簡檔案，不在本次規格對齊範圍
```

**執行期目錄（不屬於本 repo）**：`.agent-flow/`（`specs/`、`changes/`、`archive/`）是 agent-flow 被安裝到**使用者專案**後、在該專案根目錄下產生的執行期狀態目錄，不是本 repo（plugin 原始碼）的一部分。完整結構、`state.json` schema、票證 frontmatter 見 `spec/02-state.md`。

### 2.4 安裝流程

依 DESIGN.md 第 9 節「安裝」段落，使用者在自己的專案中執行：

```bash
$ claude plugin marketplace add wiasliaw/agent-flow
$ claude plugin install agent-flow@agent-flow
```

- 第一行：登錄本 repo 為一個 marketplace（來源型別為 GitHub `owner/repo`，見 research 01 §1.4「Source 型別」表），此步驟**不安裝任何 plugin**，只是登錄目錄（research 01 §7.2）。
- 第二行：從剛登錄的 `agent-flow` marketplace 安裝 `agent-flow` plugin（marketplace 名稱與 plugin 名稱恰好相同，`@` 前為 plugin 名、後為 marketplace 名）。
- 互動安裝時提供 `user`／`project`／`local` 三種 scope 選擇（research 01 §7.1）；DESIGN.md 旅程範例以 **user scope** 為主情境（Q17：「旅程文案以 user scope 為主情境」），即個人跨專案安裝，非團隊共用。若要團隊共用，安裝時選 `project` scope（寫入該專案的 `.claude/settings.json`）。
- 安裝完成後，`/agent-flow:orchestrate` 與八個 `/agent-flow:<phase>`（`discuss`／`explore`／`prototype`／`spec`／`ticket`／`dev`／`review`／`wrap`）指令即可使用；六個 internal skill 不會出現在 `/` 選單（`user-invocable: false`，見 spec/04-internal-skills.md）。
- **已知風險：agent 命名衝突會被靜默覆蓋（Q36、DESIGN §8）**——plugin agent 的 scope 優先序是五層中最低的一層（managed > CLI `--agents` > 專案 `.claude/agents/` > 個人 `~/.claude/agents/` > plugin `agents/`，research 01 §2.3、§7.4）。安裝本 plugin 前，使用者應自行確認專案 `.claude/agents/` 或個人 `~/.claude/agents/` 目錄下沒有與本 plugin 17 個角色 agent（見 `spec/03-agents.md`）同名的既有定義檔——若有，該既有定義檔會**悄悄取代**本 plugin 出貨的角色定義，且不會有任何警告或錯誤訊息。agent-flow 依 Q36 裁決不在啟動時掃描檢查此風險，安裝流程本身也不提供自動偵測，這是明確裁決過的已知取捨，須使用者自行留意。

### 2.5 `claude plugin validate` 的使用與其檢查不到的項目

#### 2.5.1 逐路徑驗證程序（PROMPT 第 5 步「每個檔案完成就跑驗證」的具體化）

依 research 05 實驗五【證實】，`validate` 只驗證明確指定的那一個路徑、不會自動遞迴子目錄。實作階段完成對應檔案後，**必須**分別對以下路徑各自呼叫一次：

| 驗證對象 | 指令 | 驗證內容 |
|---|---|---|
| Plugin manifest | `claude plugin validate .` | `plugin.json` 已知欄位是否缺漏（如 `author`／`description`），是否為合法 JSON |
| Marketplace manifest | `claude plugin validate .claude-plugin/marketplace.json` | `marketplace.json` 的 `name`／`owner`／`plugins` 必填欄位、`plugins[].source` 格式 |
| 全部 17 個角色定義檔 | `claude plugin validate ./agents` | 每個 `agents/*.md` 的 YAML frontmatter 是否可解析、是否有 `description`（research 05 §5b 對照表：無 `description` 給 warning；YAML 語法錯誤給 error；未知欄位／不該有的欄位一律不查） |
| External skills（9 個） | `claude plugin validate ./skills/external` | 依 research 01 §1.1 對 `skills` 欄位語意（額外 skills 根目錄、掃描其下 `<name>/SKILL.md`）與 §2.2 skill frontmatter 檢查同一套規則 |
| Internal skills（6 個） | `claude plugin validate ./skills/internal` | 同上；`user-invocable: false` 不影響 validate 檢查邏輯（validate 不檢查 who-invokes 語意是否合理，只檢查 frontmatter 格式） |

任何一次呼叫回報 `success: false` 或出現非預期的 `contents` 項目，須立即修正、不得累積到最後（PROMPT 第 5 步）。建議加 `--json` 取得結構化報告以利腳本化檢查。

#### 2.5.2 `validate` 檢查不到的項目與補強要求

依 research 05 實驗五【證實】，以下兩類問題 **`claude plugin validate`（含 `--strict`）完全不檢查**，規格要求實作階段必須另外補一道檢查手段，不能只依賴 `validate`：

1. **Manifest／frontmatter 的未知欄位**：`validate` 對未知欄位只是忽略，不產生警告，`--strict` 也不會讓它多發現問題（research 05 §5b 對照表第 2 列）。
2. **Plugin agent 誤用 `hooks`／`mcpServers`／`permissionMode`**：這三個欄位官方明文 plugin agent 不支援（research 01 §2.3、§4；research 05 實驗一【證實】`hooks` 完全不生效），但 `validate` 對此**沒有任何檢查**（research 05 §5b 對照表第 3 列，`--strict` 下依然 `success: true`）。這對 agent-flow 尤其重要：`agents/*.md` 中若有人不慎寫入這三個欄位，`validate` 會靜默放行，實際執行期該欄位卻不生效，形成一個「規格上看起來設了保護、實際上沒有」的隱性錯誤。

**規格要求**：實作階段須在 `agents/` 目錄完成後，額外執行一次機械檢查——掃描全部 `agents/*.md` 的 YAML frontmatter key 集合，斷言其中不包含 `hooks`、`mcpServers`、`permissionMode` 三者之一；若出現任一個，視為驗證失敗，等同 `claude plugin validate` 回報錯誤時的處置（立即修正、不累積）。此檢查手段的具體實作形式（獨立 shell script／CI 步驟／或整合進既有建置流程）留給實作階段選最簡單的做法（PROMPT 第 5 步：「規格沒寫的細節選最簡單的做法」），本規格只定義「必須存在這道檢查、檢查的斷言內容為何」。

### 2.6 巢狀 skills 目錄的實作階段最小驗證步驟

依 DESIGN.md 第 10 節 (a)：`skills/external/`、`skills/internal/` 這種巢狀分組目錄，`plugin.json` 的 `skills` 陣列指到這種分組目錄是否受支援，是「高信心推論、非逐字實測」的結論。實作階段完成 §2.3 目錄樹中的 `skills/` 部分後，須執行以下最小驗證程序，任一步驟結果與預期不符即視為此設計失效，須改採第 5 步（應變方案）：

1. **格式驗證**：依 §2.5.1 分別對 `./skills/external`、`./skills/internal` 執行 `claude plugin validate`，確認兩者皆 `success: true` 且 `contents` 不含未預期的錯誤項目。
2. **啟動載入驗證**：在本 repo 根目錄執行 `claude --plugin-dir .` 起一個互動 session，開啟 `/` 選單，確認**恰好**列出 9 個 `/agent-flow:<name>` external skill（`orchestrate`／`discuss`／`explore`／`prototype`／`spec`／`ticket`／`dev`／`review`／`wrap`），且**沒有**任何一個 internal skill（`state-management` 等 6 個）出現在選單中（依 research 01 §3.2 who-invokes 控制表：`user-invocable: false` 應使選單隱藏、直接輸入 `/agent-flow:sdd-guide` 不執行）。
3. **Internal skill 可被 Claude 載入驗證**：同一 session 中，給一個會自然觸發某個 internal skill 的任務（例如要求「寫一份 delta spec」，預期觸發 `sdd-guide`），用 `--forward-subagent-text --verbose`（或互動模式下觀察 transcript）確認 Claude 確實透過 Skill tool 呼叫了該 internal skill 並載入其完整內容（而非該 skill 完全不存在於 Claude 可觸達的清單中）。
4. **Agent 委派可用性交叉檢查**：確認 `system init` 事件（或等效的 session 啟動資訊）中的 `agents` 清單包含全部 17 個 `agent-flow:<role>` 角色（驗證 §2.3 的 `agents/` 目錄與 `skills/` 巢狀目錄互不干擾，agents 掃描不受 skills 分組結構影響）。
5. 若步驟 2 或 3 任一失敗（例如 internal skill 未被正確隱藏、或 external skill 未被正確列出），應變方案：放棄 `skills/external`／`skills/internal` 兩層分組，改為單一 `skills/` 目錄下 9 個 external + 6 個 internal skill 平鋪，僅靠各自的 `user-invocable` frontmatter 欄位區分兩層語意（frontmatter 欄位本身不受目錄結構影響，是驗證失敗時風險最低的降級路徑）。此應變方案不需要另外裁決，因為 Q37–Q39 裁決的是「external／internal 兩層*語意*上的區分」，未強制規定必須用目錄分層來實現這個區分。

---

## 三、待對齊

無。本檔全部內容皆可直接追溯到 Q17、Q26、Q37–Q39、DESIGN.md 第 2／5／9／10 節，或 research 01／05 的實測與文件記載；§2.5.2「補強檢查手段的具體實作形式」與 §2.6 步驟 5「應變方案的觸發」屬 PROMPT 第 5 步已授權的「規格沒寫的細節，實作階段選最簡單做法」範疇，不需使用者裁決。
