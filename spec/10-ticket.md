# 10 — Ticket Phase 規格（`skills/external/ticket/SKILL.md`）

## 已定（來源與依據）

- PROMPT.md：「Ticket：切出可驗證票證；以 TDD 在這個階段製作可驗證的測試。」
- Q2：phase skill 獨立、可單獨呼叫。
- Q3：Ticket 是承諾點。
- Q4：標準品質迴圈。
- Q7：需求編號回鏈。
- Q9：Ticket 階段產出**可執行的失敗測試**（真測試碼，非骨架／清單），執行後必須紅燈。
- Q10：Dev 階段實作者不可改 Ticket 產出的測試，錯了走 Q5 上報流程——本 phase 是這個合約的**產生源頭**。
- Q32：票證相依（`dependsOn`）以票證 frontmatter 為準，`state.json` 同步。
- DESIGN.md §3.5：Ticket phase 目的、進入條件、產物、品質迴圈、承諾點。
- DESIGN.md §9：旅程範例步驟 6（Ticket 承諾點呈現方式，含票證拆分範例）。
- `spec/02-state.md` 第 2.4 節：票證檔案完整 frontmatter schema（`id`／`title`／`status`／`dependsOn`／`requirementRefs`／`testFiles`）與 `status` 枚舉，本檔直接沿用、不重新定義。
- `spec/03-agents.md` 第 8、9 節：`ticket-writer`、`ticket-reviewer` 的 frontmatter、職責與禁令。
- `spec/04-internal-skills.md` 第 3、6 節：`tdd-guide`（紅綠鐵律、測試合約、偷跳話術反駁表）、`quality-loop`（審查者輸出格式契約）。
- `spec/09-spec.md`「工作單位判定」一節：本檔沿用同一套規則，不重複定義。
- **S2 裁決（實質修正本檔品質迴圈模型）**：Ticket 迴圈＝整批一輪——`ticket-reviewer` 一次審查
  整組票證與其測試（非逐張票證獨立計輪），`state.json.qualityLoops` 使用單一 key `"ticket"`
  （與 `"spec"`／`"explore"` 等其他標準迴圈 phase 一致，撤銷本檔先前自創的 `ticket:<ticket-id>`
  逐票計輪例外），上限 3 輪（Q4）。`spec/02-state.md`、`spec/05-orchestrate.md` 兩份文件從一開始
  就是這個單一 key 模式，不需要修改，本檔是修正自己先前不一致的規格本文。
- **S10 裁決**：`dependsOn` 判斷判準照本檔原推導定案。

---

## 規格本文

### Frontmatter

檔案路徑：`skills/external/ticket/SKILL.md`

```yaml
---
name: ticket
description: Splits the approved spec into verifiable tickets, each shipped with a real, currently-failing test — no implementation until you approve.
---
```

### 觸發與前置條件

- **觸發**：`/agent-flow:ticket`，或由 `orchestrate` 在 Spec 承諾點核准後驅動。
- **前置條件**：`changes/<unit>/spec-delta.md` 必須存在**且**已通過 Spec 承諾點核准（`state.json gates.spec.approvedAt != null`；單獨呼叫時見下方「單獨使用時的行為」）。

### 工作單位判定

同 `spec/09-spec.md`「工作單位判定」一節，不重複。

### 程序步驟

1. 判定工作單位。
2. 讀取已核准的 `changes/<unit>/spec-delta.md`。
3. 以 Agent tool 派工給 `ticket-writer`（`subagent_type: "agent-flow:ticket-writer"`），只傳檔案路徑：
   ```
   Agent(subagent_type="agent-flow:ticket-writer",
         description="Split approved spec into tickets for <unit>",
         prompt="Read the approved changes/<unit>/spec-delta.md. For each
                 requirement or logical group of requirements, write one
                 ticket file under changes/<unit>/tickets/ following the
                 frontmatter schema and status lifecycle defined in
                 spec/02-state.md §2.4, and the red-before-green contract
                 defined in the tdd-guide internal skill. Each ticket's test
                 must be real, executable code that you run and confirm
                 fails (red) before reporting completion.")
   ```
4. `ticket-writer` 對每張票證：
   - 依 `spec-delta.md` 的需求編號切分出邏輯獨立、可驗證的工作單位，每張票證的 `requirementRefs` 對應一或多條需求編號（Q7）。
   - 撰寫**真實可執行**的測試碼（Q9），寫入專案原有的測試目錄結構（見下方「測試檔案位置」），並**實際執行**該測試指令，確認結果為紅燈（因功能未實作而失敗，非語法或環境錯誤）。
   - 填寫票證 frontmatter 的 `dependsOn`：依票證之間的實作先後關係判斷——若某票證的實作邏輯上必須建立在另一票證的產出之上（例如「寄送重設信」依賴「產生重設 token」），則前者 `dependsOn` 後者的 `id`；判斷依據是「B 的實作若在 A 完成前開始會導致 B 無法獨立驗證或需要 mock 掉 A 尚不存在的介面」，不是單純的檔案讀寫順序。
   - 票證 `id` 依 `spec/02-state.md` 定案格式 `TICKET-<3 位數字流水號>`，同一工作單位內遞增。
   - 初始 `status: draft`（`spec/02-state.md` 定案枚舉）。
5. 以 Agent tool 派工給 `ticket-reviewer`（**一次派工、一次審查整組票證**，S2 裁決——不是逐張票證各自獨立派工），對每張票證分別檢查：
   - **測試是否真的能執行**：獨立重新執行一次該測試指令，確認無語法／環境錯誤導致無法執行。
   - **是否真的紅燈、且是「正確原因」的紅燈**：判斷依據——執行輸出中的失敗訊息型態必須是測試框架回報的**斷言失敗**（assertion failure，例如 `AssertionError`、`expect(...).toBe(...)` 失敗），而**不是**下列任一種「假紅燈」：模組載入錯誤（`ImportError`/`ModuleNotFoundError`/`Cannot find module`）、語法錯誤、測試執行器本身無法啟動（exit code 非測試框架定義的失敗碼）、逾時（timeout）。若紅燈的原因屬於後者，該張票證判定為有問題，理由標記為「環境錯誤紅燈，非有效測試」。
   - **需求編號是否正確對應**：核對 `requirementRefs` 內的編號確實存在於 `spec-delta.md` 且語意相符。
   - 逐張票證分別執行以上三項檢查，但**輸出一份涵蓋全部票證的單一裁定結果**（不是每張票證各自一份 `verdict`）。
6. `ticket-reviewer` 依 `quality-loop` 標準輸出格式回傳**單一** `verdict`（涵蓋整組票證）：
   - `"pass"`：全部票證皆通過，進入步驟 7。
   - `"reject"`：`findings[]` 陣列列出所有有問題的票證，每條 finding 明確指名對應的票證 id；本 phase 內票證尚未核准，一律歸類 `implementation-issue`，**整批**退回 `ticket-writer`（依 finding 清單修正被指出問題的票證，不需要重寫全部未被指出問題的票證，但這是「同一輪」內的重新派工，不是每張票證各自的獨立輪次）。計入 `state.json.qualityLoops.ticket.rounds`（單一 key `"ticket"`，S2 裁決，與其他標準迴圈 phase 命名模式一致）。上限 3 輪（Q4），超限走 ESC 上報。
7. 全部票證通過審查後，呈現票證清單（含每張票證的標題、依賴關係、測試檔案位置）給使用者，詢問是否核准進入 Dev（DESIGN §9 旅程步驟 6）。
8. 使用者核准後：
   - 全部票證 `status` 由 `draft` 轉為 `approved`（`spec/02-state.md` §2.4 生命週期表）。
   - `state.json`：`phases.ticket.status = "done"`、`phases.ticket.artifact = "tickets/"`、`gates.ticket.approvedAt`／`approvedBy` 寫入；`tickets.<id>` 逐筆鏡像票證 frontmatter（`status`／`dependsOn`／`requirementRefs`）。
   - 票證與其測試自此成為**已核准產物**（Q10）：Dev 階段的 `dev-worker` 不可修改測試檔案，發現測試有誤須走 Q5 上報流程。
   - 若由 `orchestrate` 驅動，自動接續 Dev phase；若單獨呼叫，流程到此結束。

### 測試檔案位置

測試碼本身寫入**專案（consumer repo）原有的測試目錄結構**（例如 `tests/`、`__tests__/`，依專案既有慣例判斷——若專案已有測試目錄則沿用其結構與命名慣例，若無既有測試目錄則採該語言/框架的社群慣例），**不**寫入 `.agent-flow/` 之下——因為測試碼要在 Dev phase 被實作程式碼消費並轉綠，且 Wrap phase 要在合併後的 main 上重新執行全部測試（DESIGN §3.8），測試必須是專案正式測試套件的一部分才能被一般測試指令（如 `npm test`、`pytest`）發現與執行。票證 frontmatter 的 `testFiles` 欄位記錄這些路徑（相對於專案根目錄，`spec/02-state.md` §2.4 已定案）。

### 品質迴圈

標準迴圈（Q4，S2 裁決：**整批一輪，非逐票計輪**）：`ticket-writer` 一次產出整組票證 →
`ticket-reviewer` 一次審查整組票證與其測試，輸出單一裁定結果 → 有問題則整批退回
`ticket-writer` 依 finding 清單修正 → 重新整批審查 → 上限 3 輪 → 超限走 ESC。
`state.json.qualityLoops` 的 key 為單一的 `"ticket"`，與 `"spec"`／`"explore"` 等其他標準迴圈
phase 一致的命名模式（`spec/02-state.md`、`spec/05-orchestrate.md` 兩份文件從一開始就是這個
模式，S2 裁決撤銷了本檔先前自創、與之不一致的 `ticket:<ticket-id>` 逐票計輪例外）。

### 承諾點

是（Q3）。核准後票證與測試成為已核准產物，`state.json gates.ticket` 寫入。呈現行為：列出票證清單、每張票證的標題、`dependsOn`、`testFiles`（DESIGN §9 步驟 6：「呈現票證清單與測試檔案位置給使用者核准」）。

### 單獨使用時的行為（Q2）

- 若 `spec-delta.md` 不存在或尚未核准：停止並提示使用者先完成 `/agent-flow:spec` 並核准（與 09-spec.md 對 Explore 前置條件的處置一致）。
- 核准後不自動接續 Dev phase，使用者需自行呼叫 `/agent-flow:dev` 或 `/agent-flow:orchestrate`。

---

## 待對齊

無。原兩項待對齊已由使用者裁決：

- **原 #1（S10 裁決）**：`dependsOn` 判斷判準（「B 若在 A 完成前開始會導致 B 無法獨立驗證或
  需要 mock 掉 A 尚不存在的介面」）照本檔原推導定案。
- **原 #2**：因 S2 裁決把品質迴圈模型改為整批一輪、單一 key `"ticket"`，「逐票計輪、key 為
  `ticket:<ticket-id>`」這個原待對齊項目所討論的命名規則本身已不存在，隨新模型一併消滅，
  不再適用。
