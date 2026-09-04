# 13 — Wrap Phase 規格（`skills/external/wrap/SKILL.md`）

## 已定（來源與依據）

- PROMPT.md：「Wrap：全自動收尾，合併與清理不留人工步驟。」
- Q2：phase skill 獨立、可單獨呼叫。
- Q3／Q13：Wrap 不是承諾點，全自動；本地合併、不 push，push 留給使用者。
- Q6：Wrap 時歸檔到 `archive/`。
- Q8：delta spec 合併進主 spec。
- Q25：Wrap 品質迴圈形態為「執行—驗證，失敗即上報」，不比照其他 phase 做 3 輪重試。
- Q34：commit 顆粒度（保留逐票證歷史，不 squash）。
- DESIGN.md §3.8：Wrap phase 目的、進入條件、產物、執行條件、品質迴圈、承諾點。
- DESIGN.md §6：主 spec 依領域分域合併規則的落地位置。
- DESIGN.md §7：Wrap 合併判準與逐動作驗證留痕。
- DESIGN.md §8：Prototype 清理紀律（隨歸檔保留，不做進一步整合）。
- DESIGN.md §9：旅程步驟 10（Wrap 執行內容與完成後摘要文案）。
- research 04：Superpowers「合併後在結果上重跑一次測試」。
- research 06：headless 下未涵蓋的權限「乾淨拒絕、流程照走」，靜默失敗風險，逐動作驗證的必要性。
- `spec/02-state.md`：`decisions.md` ESC 模板、`state.json escalations[]` schema。
- `spec/03-agents.md` 第 16、17 節：`wrap-executor`、`wrap-verifier` 的 frontmatter、職責與禁令；`wrap-executor` 不 preload `using-worktree` 的推理（殘留 worktree 清理是一般性 safety-net 清理，非 Dev phase 建立/續談機制）；`wrap-verifier` 不 preload `quality-loop` 的推理（Wrap 無「退回原作者」路徑，不適用該 schema）；本檔「上報格式」一節與 `spec/03-agents.md` 第 17 節、`spec/04-internal-skills.md` 的 ESC 格式提案已由 S3 裁決一併確認採用（原互相呼應的待對齊項目均已消滅）。
- `spec/04-internal-skills.md`：`sdd-guide` 的主 spec 合併演算法（ADDED 附加／MODIFIED 覆蓋／REMOVED 刪除）。
- `spec/09-spec.md`「工作單位判定」一節：本檔沿用同一套規則。
- **S3 裁決**：Wrap 上報確認沿用 ESC 格式，「Phase／輪次」欄位填「Wrap（無輪次，執行—驗證
  迴圈）」，`escalations[].phase` 允許 `"wrap"`，照本檔原「選項 (a)」定案。
- **S12 裁決**：合併後重跑測試失敗時，ESC 內容應包含「目前 main 已包含合併結果但測試未過，
  是否要復原合併」的具體問題，agent 不自動回退，照本檔原建議定案。

---

## 規格本文

### Frontmatter

檔案路徑：`skills/external/wrap/SKILL.md`

```yaml
---
name: wrap
description: Merges, archives, and cleans up fully automatically once review is approved and every test is green — commits locally, never pushes.
---
```

### 觸發與前置條件

- **觸發**：`/agent-flow:wrap`，或由 `orchestrate` 在 Review 承諾點核准後自動驅動。
- **前置條件**：Review 承諾點已核准（`state.json gates.review.approvedAt != null`）。若未核准且被單獨呼叫，見「單獨使用時的行為」。

### 工作單位判定

同 `spec/09-spec.md`「工作單位判定」一節。

### 執行條件（Q13）

除「Review 關卡已過」外，另需**全測試綠**：在單位分支 `flow/<unit-name>` 上重新完整跑一次專案測試套件，全部通過才可執行合併動作；不通過則整個 Wrap 立即停止並上報，不執行任何合併/歸檔/清理動作（此檢查是 `wrap-executor` 執行序列的第一步，見下方）。

### 程序步驟（「執行—驗證」，Q25：失敗即上報，不重試）

`wrap-executor` 與 `wrap-verifier` 交替執行，每個動作完成後立即驗證，任何一步驗證失敗即刻停止並上報，不進行本動作或後續動作的重試：

1. **前置測試**：`wrap-executor` 在單位分支上完整跑一次測試套件。
   - 驗證（`wrap-verifier`）：確認測試指令的 exit code 與輸出確實代表全部通過（不得只看 `wrap-executor` 的文字回報）。
   - 失敗 → 停止，上報（見「上報格式」）。
2. **合併單位分支進 main**：`wrap-executor` 執行本地合併（例如 `git checkout main && git merge --no-ff flow/<unit-name>`），**不 push**（Q13）。
   - 驗證：`wrap-verifier` 查 `main` 的 `git log`，確認確實包含該次合併 commit（以及其下逐票證的 commit 歷史，Q34 保留不 squash）。
   - 失敗 → 停止，上報。
3. **合併 delta spec 進主 spec**：`wrap-executor` 依 `sdd-guide` internal skill 定義的規則，把 `changes/<unit>/spec-delta.md` 的 `ADDED`/`MODIFIED`/`REMOVED` 區塊合併進 `.agent-flow/specs/<domain>/spec.md`（`domain` 取自 `spec-delta.md` frontmatter，`spec/09-spec.md` 已定案）：
   - `ADDED` 區塊每條需求附加進對應領域 `spec.md`（不存在則新建該領域檔案）。
   - `MODIFIED` 區塊依編號找到既有條目並整條覆寫。
   - `REMOVED` 區塊依編號刪除既有條目。
   - 驗證：`wrap-verifier` 讀取合併後的 `spec.md`，逐條核對 `spec-delta.md` 中每一條需求確實已按規則反映在主 spec（ADDED 存在、MODIFIED 內容一致、REMOVED 已消失）。
   - 失敗 → 停止，上報。
4. **歸檔工作單位**：`wrap-executor` 把 `changes/<unit>/`（含 `state.json`、`decisions.md`、`prototype/` 等全部內容）整包移動到 `archive/<date>-<unit-name>/`（`<date>` 為 Wrap 執行當下日期，`<unit-name>` 與原目錄同名——注意：若 `<unit-name>` 本身已含日期前綴（Q28 命名慣例 `<YYYY-MM-DD>-<slug>`），歸檔路徑會出現兩個日期，這是刻意的：前者是歸檔動作發生的日期，後者是工作單位建立的日期，兩者語意不同，不合併省略）。
   - 驗證：`wrap-verifier` 確認 `changes/<unit>/` 已不存在、`archive/<date>-<unit-name>/` 存在且內容完整（檔案數量與移動前一致）。
   - 失敗 → 停止，上報。
5. **刪除單位分支與殘留 worktree**：`wrap-executor` 執行 `git branch -d flow/<unit-name>`（合併後應可直接刪除，不需要 `-D`）；用 `git worktree list` 核對是否有屬於本單位、理論上該在 Dev phase 已清理但仍殘留的 worktree（safety-net，一般情況下不應有殘留），若有則 `git worktree remove` 清除。
   - 驗證：`wrap-verifier` 確認 `git branch` 不再列出 `flow/<unit-name>`、`git worktree list` 不再包含任何屬於本單位的路徑。
   - 失敗 → 停止，上報。
6. **合併後重跑測試**：`wrap-executor` 在合併後的 `main` 上**重新**完整跑一次測試套件（不是重複讀取步驟 1 的結果——呼應 research 04 Superpowers「合併後在結果上重跑一次測試」）。
   - 驗證：`wrap-verifier` 獨立確認 exit code 與輸出代表全部通過。
   - 失敗 → 停止，上報（此時 main 已包含合併結果但測試未過，屬於最需要人工介入的情境，不做自動回退——Q25 明訂失敗即上報、不重試，回退與否留給使用者裁決）。
7. 全部動作驗證通過後，`wrap-executor` 產出 `changes/<unit>/wrap.md`（此時該檔案已隨步驟 4 移至 `archive/<date>-<unit-name>/wrap.md`，即在該最終路徑寫入本檔案），主 session 印出摘要：「已完成本地合併，尚未 push，請自行推送。」（DESIGN §9 旅程步驟 10）
8. `state.json`（此時已隨歸檔移動到 `archive/<date>-<unit-name>/state.json`）更新：`phases.wrap.status = "done"`、`phases.wrap.artifact = "wrap.md"`、`currentPhase` 維持 `"wrap"`（工作單位已完結，不再有下一個 phase）。

### `wrap.md` 章節結構

```markdown
# Wrap：<unit-name>

## 執行結果：<成功 | 於步驟 <n> 失敗並上報>

## 逐動作紀錄

### 1. 前置測試
- 動作：在 flow/<unit-name> 上執行 `<測試指令>`
- 執行結果：<通過（N 項測試）| 失敗（詳情）>
- 驗證結果：<wrap-verifier 獨立確認：通過 | 失敗：原因>
- 時間戳：<ISO 8601>

### 2. 合併單位分支進 main
- 動作：`git merge --no-ff flow/<unit-name>`
- 執行結果：...
- 驗證結果：...
- 時間戳：...

（3–6 同樣格式，依序：合併主 spec／歸檔／刪除分支與清理 worktree／合併後重跑測試）
```

### 上報格式

若任一步驟驗證失敗，上報方式**沿用** `spec/02-state.md`／`spec/04-internal-skills.md` 定案的 ESC 格式（`decisions.md` 模板 + `state.json escalations[].phase = "wrap"`），但 Wrap 沒有「輪次」概念，ESC 模板中的「Phase／輪次：`<phase>`（第 `<k>/<max>` 輪）」欄位在 Wrap 情境下無法比照其他 phase 填入實際輪次——本檔規格本文的處置是填「Wrap（無輪次，執行—驗證迴圈）」取代 `<k>/<max>` 的數字形式。此為承接 `spec/03-agents.md`、`spec/04-internal-skills.md` 的一致提案，**已由 S3 裁決確認採用**。

**合併後測試失敗（步驟 6）的 ESC 內容要求（S12 裁決）**：步驟 6 失敗時寫入的 ESC，其「細節」欄位**必須**包含「目前 main 已包含合併結果但測試未過，是否要復原合併」這個具體問題，把決定權交還使用者；agent-flow 本身不自動執行任何回退動作（`git reset --hard` 等），維持 Q25「失敗即上報、不重試」的精神——「不重試」同樣適用於「不自動回退」。

**`decisions.md` 的路徑歸屬（步驟 1–3 與步驟 5–6 不同，須明確區分）**：步驟 4「歸檔工作單位」把 `changes/<unit>/`（含 `decisions.md`、`state.json`）整包移動到 `archive/<date>-<unit-name>/`。因此：

- 步驟 1–3（前置測試／合併單位分支／合併主 spec）若失敗，此時歸檔尚未發生，ESC 寫入 `changes/<unit>/decisions.md`（原路徑）。
- 步驟 5、6（刪除分支與清理殘留 worktree／合併後重跑測試）若失敗，此時步驟 4 已完成、原 `changes/<unit>/` 已不存在，ESC **必須**寫入歸檔後的路徑 `archive/<date>-<unit-name>/decisions.md`，`state.json` 的 `escalations[]` 陣列同樣寫入已隨歸檔移動的 `archive/<date>-<unit-name>/state.json`——與本檔「`wrap.md` 章節結構」一節、「產物」一節對 `wrap.md`／`state.json` 路徑轉移的既有處理方式一致（第 77、78 行已預先說明這兩個檔案在步驟 4 之後的最終路徑），`decisions.md` 應比照同一規則，不得寫回已不存在的原路徑。

### 產物

- `changes/<unit>/wrap.md`（歸檔後路徑為 `archive/<date>-<unit-name>/wrap.md`）：逐動作執行與驗證留痕。
- main 上出現合併 commit（含逐票證歷史）。
- `.agent-flow/specs/<domain>/spec.md` 更新。
- `.agent-flow/archive/<date>-<unit-name>/`：`changes/<unit>/` 的完整快照。
- 單位分支與所有票證 worktree 已清理。

### 承諾點

否，全自動（PROMPT、Q13）。

### 單獨使用時的行為（Q2）

若 Review 承諾點未核准（`state.json gates.review.approvedAt == null`）：**拒絕執行**，回報使用者「Review 尚未核准，無法執行 Wrap」，不進行任何動作——這是「執行條件」一節已定的硬性前置條件（Review 關卡已過＋全測試綠），Wrap 本身不提供繞過機制（呼應 DESIGN 非目標「不提供 Quick 模式跳過關卡」）。

---

## 待對齊

無。原兩項待對齊已由使用者裁決：

- **原 #1（S3 裁決）**：Wrap 上報確認沿用 ESC/`decisions.md` 格式，「無輪次」欄位填「Wrap（無
  輪次，執行—驗證迴圈）」，改寫進「上報格式」一節規格本文。
- **原 #2（S12 裁決）**：合併後重跑測試失敗時的 ESC 內容要求（附「是否復原合併」問題、agent
  不自動回退）照本檔原建議定案，改寫進「上報格式」一節規格本文。
