# 07 — `explore` Phase Skill 規格

## 已定（來源與依據）

- **PROMPT.md**：「Explore：內外並查，確認實作可行性。」
- **Q1**：greenfield／brownfield 兩種情境皆支援——Explore 需同時涵蓋內部程式碼調查（brownfield）
  與外部技術調查（greenfield 或不熟悉的依賴）。
- **Q3**：Explore 不是承諾點，自動接續。
- **Q4**：標準迴圈，單一審查者，上限 3 輪。
- **Q2**：phase skill 可單獨呼叫。
- **DESIGN §3.2**：Explore 的目的、進入條件、產物、品質迴圈、承諾點完整定義。
- **spec/03-agents.md 第 2、3 節**：`explorer`、`explore-reviewer` 的完整 frontmatter 與職責
  規格，本檔直接引用。
- **spec/04-internal-skills.md `quality-loop` 一節**：審查者輸出格式契約。
- **spec/05-orchestrate.md §4**：派工程序、輪次管理、退回路由通則，本檔在此基礎上補充 Explore
  自己的細節。
- **spec/02-state.md §2.1**：`explore.md` 的建立時機與生命週期（`explorer` 撰寫，品質迴圈通過後
  不再修改）。

---

## 規格本文

### 1. Frontmatter

檔案路徑：`skills/external/explore/SKILL.md`。

```yaml
---
name: explore
description: >-
  Investigates the existing codebase and external options to confirm the
  approved intent is actually feasible.
---
```

`description` 逐字採用 DESIGN §9 表格文案（Q40 核准）。

### 2. 觸發與前置條件

- **依賴**：Discuss 承諾點已核准（`state.json.gates.discuss.approvedAt != null`）。
- 經 `orchestrate` 驅動：Discuss 承諾點核准後自動觸發，無需使用者額外呼叫。
- 使用者直接呼叫 `/agent-flow:explore`（Q2）：本 phase skill 需自行檢查目標工作單位的
  `state.json.gates.discuss.approvedAt` 是否非 `null`；若為 `null`（Discuss 尚未核准，或
  `changes/<unit>/discuss.md` 根本不存在），拒絕執行並提示使用者「此工作單位尚未完成 Discuss
  承諾點，請先執行 `/agent-flow:discuss`」。

### 3. 程序步驟

1. `orchestrate`（或單獨呼叫情境下的本 phase skill 自身）用 Agent tool 派工
   `agent-flow:explorer`（spec/03-agents.md 第 2 節），prompt 傳遞 `changes/<unit>/discuss.md`
   路徑，要求：
   - 內部程式碼調查：讀取專案既有原始碼、既有測試、既有依賴，判斷與意圖摘要相關的現況。
   - 外部技術調查：查詢官方文件、技術選項、已知限制（若涉及不熟悉的依賴或全新技術選型）。
   - 兩者皆須覆蓋（Q1：不可只做其中一種，即使是明顯的 greenfield 情境，仍應檢查專案既有的
     慣例/架構/工具鏈是否對新功能有約束；即使是明顯的 brownfield 情境，仍應檢查是否有更好的
     外部技術選項可用）。
   - 產出 `changes/<unit>/explore.md`（見 §4）。
2. `explorer` 完成後，`orchestrate` 派工 `agent-flow:explore-reviewer`（spec/03-agents.md
   第 3 節），prompt 附上 `explore.md` 路徑與目前輪次。
3. 讀取審查結果（依 spec/04-internal-skills.md `quality-loop` JSON 格式）：
   - `"pass"`：`state.json.phases.explore.status = "done"`，commit
     （`flow(<unit>): explore passed review`），自動接續判斷是否需要 Prototype（見 §6）。
   - `"reject"` 且 `rootCause: "implementation-issue"`：`orchestrate` 用 Agent tool 重新派工
     `agent-flow:explorer`（一般 phase 的退回機制，不涉及 worktree，直接重新呼叫），prompt
     附上 `explore-reviewer` 的 `findings`。
   - `"reject"` 且 `rootCause: "approved-artifact"`：理論上 Explore 階段唯一的已核准產物是
     `discuss.md`（Discuss 承諾點已過）——若審查者判定 Explore 的問題根因其實是「Discuss 摘要
     本身有誤導性或遺漏」，依 Q5 一律上報，不自動退回 `explorer` 重做（因為問題不在
     `explorer` 身上）。
4. 上限 3 輪（Q4），超過依 spec/05-orchestrate.md §4.6 轉為 ESC 上報。

### 4. 產物

`changes/<unit>/explore.md`，固定三個章節：

```markdown
# Explore：<unit-name>

## 內部程式碼調查發現

<既有程式碼、既有測試、既有依賴、既有架構慣例的相關發現，附檔案路徑佐證>

## 外部技術調查發現

<外部技術選項、官方文件引用、已知限制，附來源鏈接佐證>

## 未解決的技術疑問清單

- <疑問 1，需要用實驗才能回答的具體技術問題>
- <疑問 2>
（若無任何疑問，本章節寫「無」，供 Prototype phase 判斷是否可略過）
```

「未解決的技術疑問清單」是 Prototype phase 進入條件的直接依據（DESIGN §3.3）：本清單若為空，
Prototype phase 整段略過。

### 5. 品質迴圈

標準迴圈（Q4）：`explorer` 撰寫 → `explore-reviewer` 獨立審查（是否有明顯遺漏、結論是否有佐證）
→ 退回 `explorer` 修 → 上限 3 輪 → 上報。

### 6. 是否承諾點

否（Q3）。品質迴圈通過後，`orchestrate` 讀取 `explore.md` 的「未解決的技術疑問清單」：

- 清單非空：自動進入 Prototype。
- 清單為空：略過 Prototype，`state.json.phases.prototype = {"status": "skipped", "reason":
  "no open technical question"}`，直接進入 Spec。

自動接續本身不需要使用者輸入，不呈現任何等待核准的訊息。

### 7. 單獨呼叫（不經 `orchestrate`）時的行為

- 前置條件不滿足（Discuss 未核准）：拒絕執行，提示訊息見 §2。
- 完成後：**不**自動接續 Prototype 或 Spec（Q2，接續邏輯屬於 `orchestrate`）。品質迴圈通過後，
  可提示使用者「Explore 已完成，未解決技術疑問：<有/無>，可用 `/agent-flow:prototype`（若有
  疑問）或 `/agent-flow:spec`（若無疑問）繼續」。

---

## 待對齊

無。本檔內容全部可追溯至 Q1、Q2、Q3、Q4、DESIGN §3.2、§3.3，以及 spec/02–05 已定案的規格。
