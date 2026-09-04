# spec/ 索引

> 本目錄是 agent-flow 開發流程第 4 步「規格對齊」（`PROMPT.md`）的產出：把 `DESIGN.md`
> 逐需求展開成可直接實作的規格文件。每份文件固定三節結構：**已定（來源與依據）**、
> **規格本文**、**待對齊**。待對齊的點由使用者裁決；裁決後改寫進對應文件的規格本文並
> 刪除該項，同時（若裁決涉及回寫 `DESIGN.md`）記錄到本檔「DESIGN.md 回寫記錄」一節。

## 檔案索引

| 檔案 | 內容 | 待對齊項數 |
|---|---|---|
| [`01-plugin-structure.md`](./01-plugin-structure.md) | `plugin.json`／`marketplace.json` 目標內容、完整目錄樹、安裝流程、`claude plugin validate` 的使用範圍與查不到的項目、巢狀 `skills/` 目錄的最小驗證步驟 | 0 |
| [`02-state.md`](./02-state.md) | `.agent-flow/` 目錄規格、`state.json` 完整 schema（含 S4 新增的 `escalations[].targetArtifact`）、`decisions.md` ESC 留痕模板、票證檔案格式與 frontmatter | 0 |
| [`03-agents.md`](./03-agents.md) | 17 個角色 agent 定義檔規格：檔名、frontmatter（model／tools／skills preload／isolation）、系統提示必涵蓋的職責與禁令 | 0 |
| [`04-internal-skills.md`](./04-internal-skills.md) | 6 個 internal skill（`state-management`／`sdd-guide`／`tdd-guide`／`parallel-dispatch`／`using-worktree`／`quality-loop`）的 frontmatter 與規則清單；`quality-loop` 一節的審查者輸出格式契約（S4 核准定案） | 0 |
| [`05-orchestrate.md`](./05-orchestrate.md) | 總控 skill：啟動檢查、phase 接續與四承諾點、派工程序、`SendMessage` 續談規則、與 `state.json` 的互動；Review 退回路由的 S1 特例 | 0 |
| [`06-discuss.md`](./06-discuss.md) | Discuss phase：先發散後收斂、`intent-reviewer` 審查、承諾點一 | 0 |
| [`07-explore.md`](./07-explore.md) | Explore phase：內外並查、`explorer`／`explore-reviewer`、自動接續 | 0 |
| [`08-prototype.md`](./08-prototype.md) | Prototype phase：丟棄式實驗、碼與證據進單位目錄、`prototyper`／`prototype-reviewer` | 0 |
| [`09-spec.md`](./09-spec.md) | Spec phase：EARS delta spec、`spec-writer`／`spec-reviewer`、承諾點二 | 0 |
| [`10-ticket.md`](./10-ticket.md) | Ticket phase：可執行失敗測試、票證切分與 `dependsOn`、`ticket-writer`／`ticket-reviewer`、承諾點三；品質迴圈為整批一輪（S2 改版，key 為單一 `"ticket"`） | 0 |
| [`11-dev.md`](./11-dev.md) | Dev phase：票證相依圖分波次平行、worktree 隔離、`SendMessage` 續談、合併與清理 | 0 |
| [`12-review.md`](./12-review.md) | Review phase：三組平行審查＋`review-triage`；S1 改版——不自動退回／自動 ESC，全部 finding 於承諾點呈使用者裁決，核准修正後派全新 `dev-worker` 修正、重跑一輪 | 0 |
| [`13-wrap.md`](./13-wrap.md) | Wrap phase：執行—驗證迴圈、合併／歸檔／清理、全自動；上報沿用 ESC 格式（S3） | 0 |

**待對齊項目總計：0 項**。原 16 項待對齊（含已由 `research/08-baseref-persistence.md` 化解的
1 項）已於使用者裁決 S1–S13（見下方「裁決記錄」）後全數落地進各檔規格本文並從「待對齊」節
刪除；13 份規格文件的「待對齊」節目前皆為「無」（保留簡短的裁決依據說明，非空白區塊）。

## 建議閱讀順序

1. `01-plugin-structure.md` — 先看整體骨架與目錄樹，建立「這個 plugin 長什麼樣子」的整體印象。
2. `02-state.md` → `03-agents.md` → `04-internal-skills.md` — 三份「基礎規格」，定義了後面所有
   phase 規格都會引用的共用結構：`state.json` schema、票證 frontmatter、17 個 agent 的
   檔名／模型／`skills:` preload 清單、審查者輸出格式契約（`quality-loop` 起草）。
3. `05-orchestrate.md` — 總控 skill，串起八個 phase 的排程邏輯，讀完才看得懂各 phase 規格裡
   「自動接續」「承諾點」的呈現行為是誰在執行。
4. `06`–`13`（`discuss` → `explore` → `prototype` → `spec` → `ticket` → `dev` → `review` →
   `wrap`）— 依 phase 順序閱讀；`11-dev.md` 是複雜度最高的一份，建議搭配 `research/07`、
   `research/08` 一併看。

## 三份基礎規格之間的依賴關係（供實作階段參考）

`02`／`03`／`04` 三份文件互相獨立撰寫，但彼此的規格內容有語意銜接：

- `02-state.md` 定案的票證 `status` 枚舉（`draft`／`approved`／`in_dev`／`in_review`／
  `merged`／`escalated`）同時是票證 frontmatter 與 `state.json.tickets.<id>.status` 的合法值。
- `03-agents.md` 的每個 agent 的 `skills:` preload 清單，依據就是 `04-internal-skills.md`
  每個 internal skill 的「範圍界定」表格中「誰在何時載入」欄位。
- `04-internal-skills.md` 的 `quality-loop` 一節起草的審查者輸出格式契約，是
  `03-agents.md` 每個「審查類」角色系統提示裡「輸出標準化格式」規則的具體依據，也是
  `05`、`09`–`13` 各 phase 規格裡「品質迴圈」段落判斷退回路由（Q5 兩分法）的依據。

`06`–`13` 八份 phase 規格在撰寫時已讀取上述三份定案內容，未重新發明衝突的版本。

## 跨檔案待裁決事項（已解決）

以下項目原本同時出現在多份文件中、彼此互相呼應，使用者已在裁決 S1–S13 中一併確認，不再是
待裁決狀態：

1. **【已解決，S3】Wrap phase 失敗上報是否沿用 ESC／`decisions.md` 格式**：原同時出現在
   `03-agents.md`、`04-internal-skills.md`、`13-wrap.md` 三處的同一個決策點，S3 裁決確認
   「沿用同一套 ESC 格式，『Phase／輪次』欄位在 Wrap 情境下填『Wrap（無輪次，執行—驗證迴圈）』，
   `state.json.escalations[].phase` 合法值含 `"wrap"`」，三處已同步落地。
2. **【已解決，S13】`dev-reviewer` 能否 `cd` 進 `dev-worker` worktree 的平台假設**：原同時
   出現在 `03-agents.md`、`11-dev.md` 的信心邊界標註，S13 裁決確認維持此設計並保留「實作前
   必須優先用最小可行範例驗證」的要求（不是懸而未決的待對齊，是規格本文裡的一個明確實作前置
   驗證步驟），兩處已同步落地一致的措辭。

## 裁決記錄（S1–S13）

使用者對 13 份規格文件累計 16 項待對齊（含已由 `research/08` 化解的 1 項，故實際由使用者
逐項裁決的是 15 項，經團隊整併重複／連帶項目後編號為 S1–S13）給出的裁決，逐條記錄如下。
效力與 DESIGN.md 訪談記錄的 Q1–Q40、設計稽核補充裁決 Q23–Q39 相同，是本目錄規格內容的
全文依據之一。

| 編號 | 題目 | 裁決 | 落地檔案 |
|---|---|---|---|
| S1 | Review phase 發現「純實作問題」finding 時，是否比照其他 phase 自動退回修正？ | **未採 DESIGN §3.7 原建議（實質設計變更）**：不自動修正。獵人＋`review-triage` 的全部 finding（不分根因分類）一律在 Review 承諾點全量呈給使用者裁決；使用者核准要修的項目，由 `orchestrate` 派全新 `isolation: worktree` 子代理（自單位分支 tip，機制同 Dev）執行修正，修完重跑 Review 計一輪（Q29 五輪上限落在「修正→重審」循環）。 | `12-review.md`、`05-orchestrate.md` §4.4/4.7/§5、`04-internal-skills.md` `quality-loop` 規則 3 |
| S2 | Ticket phase 的品質迴圈是逐張票證各自計輪，還是整批一次？ | 整批一輪：`ticket-reviewer` 一次審整組票證＋測試，`state.json.qualityLoops` 用單一 key `"ticket"`（與其他標準迴圈 phase 一致的命名模式），上限 3 輪。 | `10-ticket.md` |
| S3 | Wrap phase 失敗上報是否沿用 ESC／`decisions.md` 格式？ | 沿用。「Phase／輪次」欄位在 Wrap 情境下填「Wrap（無輪次，執行—驗證迴圈）」；`state.json.escalations[].phase` 合法值含 `"wrap"`。 | `03-agents.md`、`04-internal-skills.md`、`13-wrap.md`、`02-state.md` |
| S4 | `quality-loop` 起草的審查者輸出格式契約是否核准？`escalations[]` schema 是否需要擴充？ | 核准定案（`severity` 二階、Review 兩層設計均維持不變）；`02-state.md` 的 `escalations[]` 新增 `targetArtifact` 欄位（`"discuss"｜"spec"｜"ticket"`），對 Q30 定案 schema 的擴充。 | `04-internal-skills.md`、`02-state.md` |
| S5 | 票證 `status` 枚舉命名是否照提案？ | 照提案：`draft`／`approved`／`in_dev`／`in_review`／`merged`／`escalated`。 | `02-state.md` |
| S6 | `escalated` 票證裁定「測試本身需修正」後，`status` 是否重置為 `draft`？ | 照推論：重置為 `draft`。 | `02-state.md` |
| S7 | `state.json` schema 版本不符時，是否現在就設計遷移框架？ | 不預先設計；讀取前檢查 `schemaVersion`，不符則停止並回報使用者，遷移邏輯留到真正需要升版時再設計。 | `04-internal-skills.md` |
| S8 | 重新呼叫已通過核准的 Discuss 時該怎麼處理？ | 照選項 (a)：拒絕重新執行，提示使用者需明確表示要修改已核准的 Discuss 摘要。 | `06-discuss.md` |
| S9 | `/agent-flow:spec` 被單獨呼叫但 `explore.md` 不存在時該怎麼處理？ | 照原預設：停止並提示，不自動代跑 Explore；不新增跳過語法。 | `09-spec.md` |
| S10 | `ticket-writer` 判斷 `dependsOn` 的判準是否照推導？ | 照推導：「B 若在 A 完成前開始會導致 B 無法獨立驗證或需要 mock 掉 A 尚不存在的介面」。 | `10-ticket.md` |
| S11 | Dev phase 相依圖出現無法推進的死結時該怎麼處理？ | 照建議：判定 `rootCause: "approved-artifact"`、`escalation.targetArtifact: "ticket"`，寫入 ESC。 | `11-dev.md` |
| S12 | Wrap 合併後重跑測試失敗時，是否該建議使用者復原合併？ | 照建議：ESC 內容附「是否復原合併」問題，agent 不自動回退，決定權交還使用者。 | `13-wrap.md` |
| S13 | `dev-reviewer` 能否 `cd` 進 `dev-worker` worktree 的平台假設是否維持？ | 維持假設；「實作前必須優先驗證」標註保留在規格本文（不是待對齊，是明確的實作前置步驟）。 | `03-agents.md`、`11-dev.md` |

## 疑似設計矛盾清單

1. **【已由 research/08 查證化解】`11-dev.md` 原待對齊 #1：Q23「檢查 `.claude/settings.json`
   是否已設定 `worktree.baseRef: "head"`」與 DESIGN.md §7「plugin 根目錄 `settings.json` 只
   支援 `agent`／`subagentStatusLine` 兩個 key」之間的落差**。獨立稽核後派了一次針對性查證
   （`research/08-baseref-persistence.md`），直接命中官方文件：`worktree.baseRef` 【證實可
   持久化】是寫進**專案** `.claude/settings.json`（與 `User`/`Local`/`Managed` 同一階層）的
   欄位，欄位路徑與格式為 `{"worktree": {"baseRef": "head"}}`，型別為字串、僅接受
   `"fresh"`（預設）／`"head"`，不是 Agent tool 逐次呼叫時的參數（Agent tool 呼叫參數 schema
   中沒有對應欄位）。DESIGN.md §7 提到的「plugin 根目錄 `settings.json` 只支援兩個 key」指的
   是另一個檔案（plugin 套件本身隨 plugin 發布的預設 settings），與此處討論的專案層級
   `.claude/settings.json` 本來就不衝突——`11-dev.md` 先前的疑慮源自誤讀，不是 DESIGN.md
   本身有錯。已依此查證結果修正 `11-dev.md`（改回 Q23 字面裁決，「checkout 到單位分支」保留
   為互補前提而非替代方案）、`05-orchestrate.md` §2.2（補上依據標註），並移除該待對齊項目。
   詳細查證過程見 `research/08-baseref-persistence.md`。

## DESIGN.md 回寫記錄

（本節為累積變更清單，供之後回寫 `DESIGN.md`。規格對齊階段本身不修改 `DESIGN.md`；以下
兩筆是使用者裁決 S1、S4 與 `DESIGN.md` 現有文字有出入、須回寫的項目，登記「日期／裁決依據／
`DESIGN.md` 待更新的章節與內容摘要」，尚未實際執行回寫。）

1. **2026-09-05／裁決依據：S1／待更新章節：`DESIGN.md` 第 3.7 節「Review」、第 4 節「品質
   迴圈」**——現行 `DESIGN.md` §3.7 描述 Review phase 的重型迴圈「裁定為『純實作問題』（由
   orchestrator 親自以 SendMessage 續談對應的 dev-worker 修，機制見第 3.6 節）」，即「純實作
   問題可自動退回修正」；S1 裁決推翻這個行為：Review phase 不做任何自動退回或自動 ESC，三個
   平行審查小組＋`review-triage` 產出的全部 finding（不分根因分類）一律在 Review 承諾點全量
   呈現給使用者裁決，使用者核准要修的項目才由 orchestrator 派**全新**（非續談）的
   `isolation: worktree` 子代理從單位分支 tip 執行修正，修完重新完整跑一輪 Review（計入
   Q29 五輪上限）。回寫時應更新 §3.7「品質迴圈」段落與第 4 節「根因分流與上報」對 Review
   的適用範圍說明（第 4 節目前的二分法路由規則對其餘標準迴圈 phase 仍然成立，只有 Review
   是例外）。落地細節見 `spec/12-review.md`、`spec/05-orchestrate.md` §4.4/4.7/§5、
   `spec/04-internal-skills.md` `quality-loop` 規則 3。
2. **2026-09-05／裁決依據：S4／待更新章節：`DESIGN.md` 第 6 節「狀態外部化」`state.json`
   schema 範例**——現行 `DESIGN.md` §6 的 `escalations[]` 範例物件只有 `id`／`phase`／
   `ticket`／`rootCause`／`raisedAt`／`resolvedAt` 六個欄位；S4 裁決在此基礎上新增
   `targetArtifact` 欄位（`"discuss"｜"spec"｜"ticket"｜null`，`rootCause ==
   "approved-artifact"` 時必填，指出根因指向哪個已核准產物），這是對 Q30 定案 schema 的擴充，
   不是推翻。回寫時應在 §6 的 JSON 範例中補上這個欄位。落地細節見 `spec/02-state.md` §2.2
   `escalations` 陣列一節、`spec/04-internal-skills.md` `quality-loop` 規則 7（審查者輸出
   格式契約的 `escalation.targetArtifact` 欄位，S4 確認兩處欄位語意一致）。
