# 07 — Prototype Phase 規格（`skills/prototype/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R1**：Prototype 為 **optional** phase——僅在 Explore 留下未解決技術疑問時觸發，否則整段略過。
- **Q18／Q35（承襲）**：實驗碼與證據都進單位目錄（`prototype/`），配套「不進正式產品」三點紀律。
- **Q4／Q2（承襲）**：標準迴圈 3 輪；可單獨呼叫；非承諾點，自動接續。
- **R3**：審查發現根因在 Explore（意圖誤導致實驗方向錯誤）時，自動退回 Explore（原 `approved-artifact` ESC 廢止）。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: prototype
description: >-
  Answers open technical questions with throwaway experiments, capturing
  the question, approach, and evidence — never the code itself.
---
```

### 2. 觸發與前置條件

- **依賴**：Explore 已核准（`gates.explore.approvedAt != null`）且「未解決的技術疑問清單」非空。清單為空時整段略過（`phases.prototype = {"status": "skipped", "reason": "no open technical question"}`）。
- 單獨呼叫：檢查 Explore 已核准，否則停止提示；Explore 已核准但清單為空時**仍允許強制執行**（使用者可能有清單未捕捉的疑問——「為空即略過」是 orchestrate 的自動接續捷徑，不是禁止手動執行的硬限制，承襲原裁決）。

### 3. 程序步驟

1. 派 `worker`（角色：prototyper；無需指名 reference），prompt 傳疑問清單，要求：
   - 針對每條疑問撰寫丟棄式實驗碼，只寫入 `changes/<unit>/prototype/`——**絕不**寫入正式產品路徑（Q18 核心禁令）。
   - 實際執行取得證據（輸出、log、量測）。
   - 產出 `changes/<unit>/prototype.md`（四要素：問題／做法／證據／結論）。
2. 派 `reviewer`（指名 `references/quality-loop.md`；告知輪次），實際重跑 `prototype/` 實驗碼驗證：每條疑問是否真的被回答、證據是否可重現、是否誤寫入 `prototype/` 以外路徑。
3. 路由：
   - `pass`：`phases.prototype = "done"`，commit（`flow(<unit>): prototype passed review`），自動接續 Spec。
   - `reject` 且 `targetPhase: "prototype"`：重新派 `worker` 附 findings，`rounds` 遞增，上限 3 輪，超限 ESC（`round-limit`）。
   - `reject` 且 `targetPhase: "explore"`（意圖理解有誤導致實驗方向錯誤）：執行 waterfall 退回（spec/05 §4.5）——Explore 重做、重新核准後重走本 phase。

### 4. 產物與正式產品的協調

`prototype.md` 四章節（問題／做法／證據／結論）與 `prototype/` 實驗碼，格式承襲原規格。三點紀律（Q35）：(1) 實驗碼只在 `changes/<unit>/prototype/`；(2) 正式「零依賴」查核由 Review 的 compliance lens 做最終確認，本 phase 審查者只查自己這次寫的碼未被正式路徑引用；(3) Wrap 歸檔時隨單位整包保留、不做進一步整合。

### 5. 承諾點

否。迴圈通過後自動接續 Spec。

### 6. 單獨呼叫時的行為

前置不滿足即停止提示；完成後不自動接續（INV-11），可提示「可用 `/agent-flow:spec` 繼續」。

---

## 待對齊

無。內容承襲原 Prototype 規格，僅退回路由依 R3 改為自動 fallback。
