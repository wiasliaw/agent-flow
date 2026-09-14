# 09 — TDD Phase 規格（`skills/tdd/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R1**：原 Ticket phase 改名 TDD——根據已核准的 spec 定義 TDD 測試規格（切票證＋可執行紅燈測試）。
- **R2**：TDD **不設承諾點**——品質迴圈通過即測試合約生效（Q10 合約起點由「gate 核准」改為「迴圈通過」），自動接續 Build。
- **Q7／Q9（承襲）**：需求編號回鏈；產出可執行的失敗測試（真測試碼、實際執行確認紅燈）。
- **S2（承襲）**：品質迴圈整批一輪，`qualityLoops` 單一 key `"tdd"`，上限 3 輪。
- **S10（承襲）**：`dependsOn` 判準——「B 若在 A 完成前開始會導致 B 無法獨立驗證或需要 mock 掉 A 尚不存在的介面」。
- **Q32（承襲）**：票證 frontmatter 為相依權威來源。
- **R3**：審查發現根因在 Spec 時自動退回 Spec。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: tdd
description: >-
  Splits the approved spec into verifiable tickets, each shipped with a
  real, currently-failing test that becomes the build contract once the
  review loop passes.
---
```

### 2. 觸發與前置條件

- **觸發**：`/agent-flow:tdd`，或由 `orchestrate` 在 Spec 核准後驅動。
- **前置條件**：`changes/<unit>/spec-delta.md` 存在且已核准（`gates.spec.approvedAt != null`）。
- 工作單位判定：`resolve_unit()`。

### 3. 程序步驟

1. `resolve_unit()`，讀取已核准的 `spec-delta.md`。
2. 派 `worker`（角色：test author；指名 `references/sdd-guide.md`、`references/tdd-guide.md`）——首輪對象為全部票證。**重做輪（waterfall 退回後）先做差異判定**：比對目前的 `spec-delta.md` 與既有票證（局部退回時受影響集合已由退回程序標定，直接沿用），將修訂需求分為兩類：
   - **測試行為變更**（需求增修刪波及測試內容）：所涉票證重置 `status → "draft"` 重做。
   - **純票證資料修正**（僅 `dependsOn`／`requirementRefs`／描述文字需要改，測試檔不動）：直接修訂票證 frontmatter 與內文，**不轉 `draft`**、原狀態保留（`merged` 維持 `merged`）。

   只重做 `draft` 票證，其餘票證不重寫、沿用既有測試與證據（spec/05 §4.5）。對每張重做對象票證：
   - 依需求編號切分邏輯獨立、可驗證的工作單位，`requirementRefs` 對應一或多條編號（Q7）。
   - 撰寫真實可執行的測試碼（Q9），寫入專案原有測試目錄結構（§4），**實際執行**確認結果，依兩種情境驗證：
     - **缺實作**（首輪票證；或重做輪新增／修改的案例執行後紅燈）：確認紅燈（因功能未實作而失敗）；無法執行視為未完成。
     - **補測試覆蓋**（重做輪限定：實作已存在、新案例執行後直接綠燈——典型情境是 Review 判定既有實作行為正確、只缺測試覆蓋而退回）：綠燈是合法結果，但必須附**可失敗性證據（falsifiability check）**，且擾動**只在拋棄式副本中執行、正式工作樹全程不動**——自目前 HEAD 建立暫存副本（如 `git worktree add` 至暫存目錄，並把本輪尚未 commit 的測試檔複製進副本），在副本內對相關實作做針對性擾動（例如反轉該邊界條件），執行新案例確認轉紅；隨即移除副本（`git worktree remove --force` 或等效），回到正式樹執行新案例確認綠燈。把「擾動內容 → 副本內紅 → 正式樹綠」的執行紀錄寫進票證，證明新案例真的在測目標行為、不是恆真測試。
   - 依 S10 判準填 `dependsOn`；`id` 格式 `TICKET-<3 位數>`；初始 `status: draft`。
3. 派 `reviewer`（**一次審查整組票證**，S2；指名 `references/tdd-guide.md`、`references/quality-loop.md`；告知輪次），檢查判準依票證狀態區分：
   - **`draft` 票證**（首輪為全部；退回重做輪為受影響票證）：
     - **測試真的能執行**：獨立重跑，無語法／環境錯誤。
     - **真紅燈且是正確原因**：失敗訊息必須是測試框架的**斷言失敗**；模組載入錯誤、語法錯誤、執行器無法啟動、timeout 一律判「假紅燈（環境錯誤），非有效測試」。
     - **紅燈判準的適用粒度是「本輪新增或修改的測試案例」**：票證原為 `merged`（實作已合併）而測試被修訂時，只有新增／修改的案例適用本判準，未修改的既有案例維持綠燈是預期，不因此判拒；首輪（無既有實作）則全部案例須紅燈。
     - **補測試覆蓋的替代證據**：新增／修改的案例若因既有實作已滿足而直接綠燈，**不判拒**，改驗證票證附的可失敗性證據（步驟 2）——reviewer **自行建立自己的拋棄式副本**重現同一擾動，確認案例於副本轉紅、正式樹上為綠；正式工作樹全程唯讀（reviewer 唯讀契約的適用對象，spec/03 第 2 節）。驗證前先記錄正式樹基準（`git status --porcelain` 清單與相關檔案的 diff／雜湊——此時正式樹本來就含待審的未 commit 測試與票證變更，**不要求乾淨**）；驗證後比對基準確認**相較驗證前無新增改動**（待審變更原樣保留），並確認自己建立的副本已移除（`git worktree list` 無殘留）。缺此證據、或副本內擾動後案例仍綠（恆真測試），判拒。
     - **需求編號正確對應**：`requirementRefs` 存在於 `spec-delta.md` 且語意相符。
   - **`merged` 票證**（僅退回重做輪出現）：實作已合併、測試為綠是預期狀態，**不適用紅燈判準**；改核對——測試檔未被未授權修改（合約完整性，`git diff` 對照單位分支歷史）、與本輪修訂票證的相依／編號一致性。
   - **`ready` 票證**（重做輪未受影響、尚無實作）：沿用既有紅燈測試，紅燈判準自然成立；審查確認其未被本輪修訂波及即可，不要求重寫。
   - **`in_build`／`in_review` 票證**（局部退回時被靜置的進行中票證，spec/05 §4.5 步驟 0）：比照 `merged` 核對合約完整性，不適用紅燈判準。
   - 輸出**單一裁定結果**涵蓋全部票證（非逐票各一份 verdict）。
4. 路由：
   - `pass`：進步驟 5。
   - `reject` 且 blocking findings 全部 `targetPhase: "tdd"`：整批退回 `worker` 依 findings 修正被指出的票證，計入 `qualityLoops.tdd.rounds`，上限 3 輪，超限 ESC。
   - `reject` 且任一 blocking finding 的 `targetPhase` 為較早 phase（`"spec"`／`"prototype"`／`"explore"`，例：需求本身矛盾、不可測試）：waterfall 退回至最早目標（spec/05 §4.5）。
5. **迴圈通過（R2，取代原承諾點）**：
   - 全部 `draft` 票證 `status → ready`（其餘狀態票證維持不變）；`phases.tdd = "done"`、`artifact: "tickets/"`；`tickets.<id>` 鏡像同步。
   - **測試合約自此生效（Q10）**：Build 的 `worker` 不可修改測試檔；發現測試有誤走 waterfall 退回 TDD（`references/tdd-guide.md` 規則 2）。
   - commit（`flow(<unit>): tdd passed review`）；由 `orchestrate` 驅動時自動接續 Build。

### 4. 測試檔案位置

測試碼寫入專案原有測試目錄結構（沿用既有慣例；無既有目錄則採該語言／框架社群慣例），**不**寫入 `.agent-flow/`——測試必須是正式測試套件的一部分，才能被 Build 消費轉綠、被 Wrap 的全測試檢查發現。票證 `testFiles` 記錄路徑（相對專案根目錄）。

### 5. 承諾點

否（R2）。迴圈通過即合約生效並自動接續，不停等使用者核准——被 waterfall 退回重做時同理，重過迴圈即重新生效。

### 6. 單獨呼叫時的行為

- `spec-delta.md` 不存在或未核准：停止並提示先完成 `/agent-flow:spec`。
- 完成後不自動接續 Build（INV-11）。

---

## 待對齊

無。改名與 gate 移除是 R1／R2 的直接落地；整批迴圈（S2）、假紅燈判準、`dependsOn` 判準（S10）、測試檔位置全部承襲原 Ticket 規格。
