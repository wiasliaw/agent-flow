# 08 — `prototype` Phase Skill 規格

## 已定（來源與依據）

- **PROMPT.md**：「Prototype：用丟棄式程式碼做實驗回答技術疑問，留下問題、做法與證據；程式碼
  不進正式產品。」
- **Q3**：Prototype 不是承諾點，自動接續。
- **Q4**：標準迴圈，單一審查者，上限 3 輪。
- **Q2**：phase skill 可單獨呼叫。
- **Q18**：Prototype 的碼與證據都進單位目錄（未採建議選項「碼在 `/tmp`」），需配套「不進正式
  產品」的協調紀律。
- **DESIGN §3.3**：Prototype 的目的、進入條件（Explore 產出中列有未解決技術疑問；若無疑問可
  略過）、產物、品質迴圈、承諾點完整定義。
- **DESIGN §8「Q18 實驗碼進版控的清理紀律」（Q35 定案）**：三點協調規則——`prototype/` 不在任何
  正式產品原始碼路徑下、Review phase 明確查核零依賴、Wrap 歸檔時保留但不做進一步整合。
- **spec/03-agents.md 第 4、5 節**：`prototyper`、`prototype-reviewer` 的完整 frontmatter 與
  職責規格，本檔直接引用。
- **spec/04-internal-skills.md `quality-loop` 一節**：審查者輸出格式契約。
- **spec/05-orchestrate.md §4**：派工程序、輪次管理、退回路由通則。
- **spec/02-state.md §2.1**：`prototype.md`／`prototype/` 的建立時機、`skipped` 狀態的記錄方式。

---

## 規格本文

### 1. Frontmatter

檔案路徑：`skills/external/prototype/SKILL.md`。

```yaml
---
name: prototype
description: >-
  Answers open technical questions with throwaway experiments, capturing
  the question, approach, and evidence — never the code itself.
---
```

`description` 逐字採用 DESIGN §9 表格文案（Q40 核准）。

### 2. 觸發與前置條件

- **依賴**：Explore phase 已完成，且其「未解決的技術疑問清單」非空（spec/07-explore.md §4）。
  若清單為空，本 phase 整段略過（PROMPT 對 Prototype 的定義本身就是「回答技術疑問」，沒有疑問
  就沒有存在理由；DESIGN §3.3）。
- 經 `orchestrate` 驅動：`orchestrate` 讀取 `explore.md` 的疑問清單，非空才觸發本 phase；為空
  則直接記錄 `skipped` 並跳至 Spec（spec/07-explore.md §6、spec/02-state.md §2.1）。
- 使用者直接呼叫 `/agent-flow:prototype`（Q2）：本 phase skill 需自行檢查
  `changes/<unit>/explore.md` 是否存在且 `state.json.phases.explore.status == "done"`；若不
  滿足，拒絕執行並提示先完成 Explore。若 Explore 已完成但其疑問清單為空，仍允許使用者強制執行
  （使用者可能有 Explore 產物未捕捉到的疑問想額外驗證）——此為單獨呼叫情境下使用者主動繞過
  「清單為空即略過」的自動判斷，不視為違反規格（該自動判斷是給 `orchestrate` 自動接續用的
  捷徑，不是禁止使用者手動執行 Prototype 的硬性限制）。

### 3. 程序步驟

1. `orchestrate`（或單獨呼叫情境下的本 phase skill 自身）用 Agent tool 派工
   `agent-flow:prototyper`（spec/03-agents.md 第 4 節），prompt 傳遞 `explore.md` 的「未解決
   的技術疑問清單」，要求：
   - 針對每一條疑問，撰寫丟棄式實驗碼，寫入 `changes/<unit>/prototype/`（**絕不**寫入任何正式
     產品原始碼路徑，如 `src/`——這是 Q18 配套紀律的核心禁令，見 §4「與正式產品的協調」）。
   - 實際執行實驗，取得證據（指令輸出、log、量測結果等）。
   - 產出 `changes/<unit>/prototype.md`（見 §4，PROMPT 原文四要素：問題／做法／證據／結論）。
2. `prototyper` 完成後，`orchestrate` 派工 `agent-flow:prototype-reviewer`
   （spec/03-agents.md 第 5 節），prompt 附上 `prototype.md`、`prototype/` 路徑與目前輪次。
   `prototype-reviewer` 實際重跑 `prototype/` 下的實驗碼，確認證據可重現。
3. 讀取審查結果（依 spec/04-internal-skills.md `quality-loop` JSON 格式）：
   - `"pass"`：`state.json.phases.prototype = {"status": "done", "artifact":
     "prototype.md"}`，commit（`flow(<unit>): prototype passed review`），自動接續 Spec。
   - `"reject"` 且 `rootCause: "implementation-issue"`：`orchestrate` 重新派工
     `agent-flow:prototyper`，附上 `prototype-reviewer` 的 `findings`。
   - `"reject"` 且 `rootCause: "approved-artifact"`：根因可能指向 `discuss.md`（意圖理解有誤，
     導致實驗方向錯誤），依 Q5 上報，不自動退回 `prototyper`。
4. 上限 3 輪（Q4），超過依 spec/05-orchestrate.md §4.6 轉為 ESC 上報。

### 4. 產物與正式產品的協調

`changes/<unit>/prototype.md`，固定四個章節（PROMPT 原文要素）：

```markdown
# Prototype：<unit-name>

## 問題

<這個實驗要回答哪一條 Explore 留下的技術疑問，逐一列出對應>

## 做法

<實驗設計、使用的技術/工具、實驗碼位置（指向 prototype/ 下的相對路徑）>

## 證據

<實際執行結果：指令輸出、log、量測數據，須可由 prototype-reviewer 重現>

## 結論

<每條疑問是否已解決，若未解決說明還缺什麼>
```

`changes/<unit>/prototype/`：實驗碼本身，進版控（Q18，非建議選項），目錄結構不限（依實驗需要
自行組織，例如每條疑問一個子目錄）。

**與「不進正式產品」的協調**（DESIGN §8、Q35 定案，三點紀律，本 phase 的執行面落實）：

1. `prototype/` 位於 `.agent-flow/changes/<unit>/prototype/`，不在任何正式產品原始碼路徑下
   （如 `src/`）——`prototyper` 的系統提示已明文禁止寫入正式路徑（spec/03-agents.md 第 4
   節）；本 phase 的品質迴圈中，`prototype-reviewer` 需連帶檢查 `prototyper` 沒有意外寫入
   `prototype/` 以外的路徑（例如誤寫進 `src/` 做「順手測試」）。
2. 正式的「零依賴」查核（正式產品程式碼是否 import／依賴 `prototype/`）不在本 phase 執行，而是
   Review phase 由 `review-spec-compliance-auditor` 做最終確認（spec/03-agents.md 第 14
   節）——本 phase 的 `prototype-reviewer` 只需確認**自己這次撰寫的實驗碼**沒有被引用到正式
   路徑，不需要對整個工作單位的最終狀態做零依賴掃描（那時 Dev phase 都還沒發生）。
3. Wrap 歸檔時，`prototype/` 隨 `changes/<unit>/` 整包移入 `archive/<date>-<unit>/`（見
   spec/13-wrap.md），本 phase 不涉及歸檔動作。

### 5. 品質迴圈

標準迴圈（Q4）：`prototyper` 撰寫 → `prototype-reviewer` 審查問題是否真的被回答、證據是否可信
（實際重跑驗證）→ 上限 3 輪 → 上報。

### 6. 是否承諾點

否（Q3）。品質迴圈通過後自動接續 Spec，不等待使用者輸入。

### 7. 單獨呼叫（不經 `orchestrate`）時的行為

- 前置條件不滿足（`explore.md` 不存在或未完成）：拒絕執行，提示先完成 Explore。
- 完成後：**不**自動接續 Spec（Q2）。品質迴圈通過後，可提示使用者「Prototype 已完成，可用
  `/agent-flow:spec` 繼續」。

---

## 待對齊

無。本檔內容全部可追溯至 Q2、Q3、Q4、Q18、Q35、DESIGN §3.3、§8，以及 spec/02–05 已定案的規格。
