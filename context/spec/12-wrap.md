# 12 — Wrap Phase 規格（`skills/wrap/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R1**：Wrap 維持全自動收尾——合併與清理不留人工步驟。
- **R5**：執行者為 `worker`、逐動作驗證者為 `reviewer`（Wrap 驗證模式，不適用 quality-loop 契約——Q25 承襲）；模型成本取捨見 spec/03 通則 5。
- **Q13／Q6／Q8／Q34（承襲）**：本地合併不 push；歸檔 `archive/`；delta 合併進主 spec；保留逐票證 commit 不 squash。
- **Q25（承襲）**：執行—驗證、失敗即上報，不重試、不自動回退。
- **S3（承襲，格式依 R3 微調）**：上報沿用 ESC 格式，`rootCause: "wrap-failure"`，「Phase／輪次」欄位填「Wrap（無輪次，執行—驗證迴圈）」。
- **S12（承襲）**：合併後測試失敗的 ESC 必須附「是否復原合併」問題，agent 不自動回退。
- **research 04／06（承襲）**：合併後重跑測試；獨立查證防「動作被拒但流程自認完成」的靜默失敗。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: wrap
description: >-
  Merges, archives, and cleans up fully automatically once review is
  approved and every test is green — commits locally, never pushes.
---
```

### 2. 觸發與前置條件

- **觸發**：`/agent-flow:wrap`，或由 `orchestrate` 在 Review 核准後自動驅動。
- **前置條件**：`gates.review.approvedAt != null`。
- 工作單位判定：`resolve_unit()`。

### 3. 執行條件（Q13）

除 Review 已核准外，另需**全測試綠**：單位分支上重跑完整測試套件，不通過則整個 Wrap 立即停止並上報，不執行任何合併／歸檔／清理。

### 4. 程序步驟（執行—驗證，Q25）

`worker`（角色：wrap executor；指名 `references/sdd-guide.md`）與 `reviewer`（Wrap 驗證模式）交替；每動作完成即驗證，任一步失敗即停止上報：

**記錄權責**：`reviewer` 只將驗證結論與查證方式回傳主 session，不寫 `wrap.md`；主 session 將回報轉交 `worker`，由 `worker` 轉錄至 §5 的「驗證結果」欄位，不得更改 reviewer 的通過／失敗結論或查證方式。`state.json` 與 ESC 留痕仍由主 session 依 spec/02 寫入。

1. **前置測試**：`worker` 在單位分支跑完整測試。驗證：`reviewer` 獨立確認 exit code 與輸出代表全部通過。
2. **合併單位分支進 main**：`git checkout main && git merge --no-ff flow/<unit-name>`，**不 push**。驗證：`git log` 含合併 commit 與逐票證歷史（Q34）。
3. **合併 delta spec 進主 spec**：依 `references/sdd-guide.md` 規則（ADDED 附加／MODIFIED 覆寫／REMOVED 刪除）合併進 `.agent-flow/specs/<domain>/spec.md`（`domain` 取自 `spec-delta.md` frontmatter）。驗證：逐條核對每條需求已按規則反映。
4. **歸檔**：`changes/<unit>/` 整包移入 `archive/<date>-<unit-name>/`（兩個日期語意不同：歸檔日 vs 建立日，刻意不合併）。驗證：原目錄不存在、歸檔目錄內容完整。
5. **刪除單位分支與殘留 worktree**：`git branch -d flow/<unit-name>`；`git worktree list` 核對並清除屬於本單位的殘留（safety-net）。驗證：兩個清單皆不再出現本單位項目。
6. **合併後重跑測試**：在合併後的 main 上**重新**完整跑一次（不是重讀步驟 1 結果）。驗證：獨立確認全部通過。失敗＝最需人工介入的情境，不自動回退（S12）。
7. 全部通過：`worker` 在最終路徑 `archive/<date>-<unit-name>/wrap.md` 寫入逐動作留痕；主 session 印出「已完成本地合併，尚未 push，請自行推送。」
8. `state.json`（已隨歸檔移動）：`phases.wrap = "done"`、`artifact: "wrap.md"`。

### 5. `wrap.md` 章節結構

```markdown
# Wrap：<unit-name>

## 執行結果：<成功 | 於步驟 <n> 失敗並上報>

## 逐動作紀錄

### 1. 前置測試
- 動作：在 flow/<unit-name> 上執行 `<測試指令>`
- 執行結果：<通過（N 項）| 失敗（詳情）>
- 驗證結果：<reviewer 獨立確認：通過 | 失敗：原因>
- 時間戳：<ISO 8601>

（2–6 同格式，依序：合併進 main／合併主 spec／歸檔／刪除分支與 worktree／合併後重跑測試）
```

### 6. 上報格式

沿用 ESC 格式（spec/02 §2.3），`rootCause: "wrap-failure"`、`phase: "wrap"`，「Phase／輪次」填「Wrap（無輪次，執行—驗證迴圈）」（S3）。

- **步驟 6 失敗的 ESC 內容（S12）**：「細節」必須含「目前 main 已包含合併結果但測試未過，是否要復原合併」，決定權交還使用者；不自動執行任何回退。
- **`decisions.md` 路徑歸屬**：步驟 1–3 失敗寫 `changes/<unit>/decisions.md`（歸檔未發生）；步驟 5–6 失敗寫 `archive/<date>-<unit-name>/decisions.md`（歸檔已完成，`state.json.escalations` 同樣寫歸檔後路徑），不得寫回已不存在的原路徑。
- **步驟 4（歸檔）失敗**：先停止後續動作，不重試、不自動回移；ESC 記錄跟隨實際的 `state.json` 位置，由主 session 依序判定：
  1. `changes/<unit>/state.json` 仍存在：以來源為記錄位置，寫入同目錄的 `decisions.md` 與該 `state.json.escalations`；即使歸檔目標也存在，仍以來源為準，不雙邊寫入。
  2. 來源 `state.json` 已不存在，但 `archive/<date>-<unit-name>/state.json` 存在：寫入歸檔目錄的兩份記錄（包含搬移完成、但歸檔驗證失敗的情境）。
  3. 兩處皆無 `state.json`，或選定位置的記錄無法讀寫：立即向使用者回報歸檔失敗與無法完成 ESC 留痕的現況，不另建 `state.json` 或重建來源目錄，不宣稱已完成雙寫；待使用者處理後再補記。
  ESC「細節」須記錄來源與目標的實際存在狀態、失敗動作與選定的記錄位置；部分搬移的檔案維持原狀，交由使用者裁決。

### 7. 承諾點

否，全自動。

### 8. 單獨呼叫時的行為

Review 未核准：拒絕執行並回報，不提供繞過機制（無 Quick 模式）。

---

## 待對齊

無。內容承襲原 Wrap 規格；僅執行者／驗證者改為 worker／reviewer（R5）、ESC `rootCause` 依 R3 改為 `"wrap-failure"`。
