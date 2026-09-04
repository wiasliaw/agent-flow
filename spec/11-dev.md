# 11 — Dev Phase 規格（`skills/external/dev/SKILL.md`）

## 已定（來源與依據）

- PROMPT.md：「Dev：以 subagent 或 worktree 平行執行票證。」
- Q2：phase skill 獨立、可單獨呼叫。
- Q3：Dev 不是承諾點，自動接續 Review。
- Q4：標準品質迴圈，逐票證各自跑一輪。
- Q5：根因二分法（純實作問題／已核准產物），已核准產物一律上報。
- Q10：Dev 階段實作者不可改測試，錯了上報。
- Q11：同 session 子代理＋worktree 隔離，平行度依票證相依圖。
- Q23：啟動時檢查專案設定，缺少則徵同意寫入。
- Q34：commit 顆粒度（`dev-worker` 轉綠後 commit 一次，orchestrator 合併時保留一票一 commit）。
- DESIGN.md §3.6：Dev phase 目的、進入條件、產物、執行機制、品質迴圈、承諾點。
- DESIGN.md §5：派工語法、平行度依票證相依圖、20 並行上限分批規則。
- DESIGN.md §7：兩層分支、worktree 生命週期、`baseRef: head` 必要條件、Dev/Review 不共用 worktree。
- DESIGN.md §9：旅程步驟 7（Dev 前置檢查）、步驟 8（Dev 執行）。
- research 06 實驗四：重新派工 Agent tool 一律拿到全新 worktree；有變更的 worktree 不自動清除。
- research 07 Test A：`SendMessage` 續談已完成 `isolation: worktree` 子代理，worktree／分支／未 commit 變更完整保留；完成通知只回主 session。
- research 07 Test B：worktree 分岔基準跟隨發起當下 checkout；無 remote 情境下驗證成立，需明確設 `baseRef: head` 不依賴預設 `"fresh"`。
- research 08【證實可持久化】：`worktree.baseRef` 是可持久化寫入專案 `.claude/settings.json` 的欄位（`{"worktree": {"baseRef": "head"}}`，Scope 為 `Any file`，型別為字串，僅接受 `"fresh"`／`"head"`），不是 Agent tool 逐次呼叫時的參數（Agent tool 呼叫參數 schema 中沒有對應欄位）；DESIGN §7「plugin 根目錄 settings.json 只支援 agent／subagentStatusLine」指的是另一個檔案（plugin 套件本身隨 plugin 發布的預設 settings），與此處討論的專案層級 `.claude/settings.json` 無關，兩者不矛盾。本檔先前（規格對齊初稿）誤把 `baseRef` 理解為當次呼叫參數並因此質疑 Q23 字面可行性，已依 research 08 更正為 Q23 字面裁決。
- research 02 §3.1：子代理並行上限 20。
- `spec/02-state.md`：票證 `status` 枚舉與生命週期（`approved → in_dev → in_review → merged/escalated`）、`qualityLoops` key 格式 `dev:<ticket-id>`。
- `spec/03-agents.md` 第 10、11 節：`dev-worker`（`isolation: worktree`）、`dev-reviewer` 的 frontmatter、職責與禁令，含 `dev-reviewer` 如何取得 `worktreePath` 並操作的推理。
- `spec/04-internal-skills.md` 第 3、5、6 節：`tdd-guide`（測試合約）、`using-worktree`（建立/續談/清理規則，僅 `orchestrate` 載入）、`quality-loop`（審查者輸出格式契約）。
- `spec/09-spec.md`「工作單位判定」一節：本檔沿用同一套規則。
- **S11 裁決**：相依圖出現無法推進的死結時，判定 `rootCause: "approved-artifact"`、
  `escalation.targetArtifact: "ticket"`，寫入 ESC，照本檔原建議定案。
- **S13 裁決**：`dev-reviewer` 進 worktree 的假設維持不變、「實作前必須優先驗證」的要求保留，
  已改寫進 `spec/03-agents.md` 第 11 節規格本文（不再是待對齊），本檔品質迴圈步驟 3 的引用
  措辭同步調整。

---

## 規格本文

### Frontmatter

檔案路徑：`skills/external/dev/SKILL.md`

```yaml
---
name: dev
description: Implements approved tickets in parallel, one isolated worktree per ticket, until every test goes green and passes independent review.
---
```

### 觸發與前置條件

- **觸發**：`/agent-flow:dev`，或由 `orchestrate` 在 Ticket 承諾點核准後驅動。
- **前置條件**：`changes/<unit>/tickets/*.md` 全部存在且 `status: approved`（`state.json gates.ticket.approvedAt != null`）；每張待開發票證的測試已確認為紅燈（Ticket phase 的 `ticket-reviewer` 已驗證，此處不重新驗證，只在派工 `dev-worker` 前信任該狀態）。

### 工作單位判定

同 `spec/09-spec.md`「工作單位判定」一節。

### Dev phase 前置檢查（Q23，worktree 設定）

**在計算第一波派工票證集合之前**，執行本 skill 的 session（不論由 `orchestrate` 驅動或單獨呼叫）必須先確認專案已具備 Dev phase worktree 平行執行所需的設定。本節與 `spec/05-orchestrate.md` §2.2 是同一個檢查邏輯在不同呼叫路徑下的規格化——由 `orchestrate` 驅動時，這個檢查已在其進入 Dev phase 前執行過（見 05-orchestrate.md §2.2），不需要重複；單獨呼叫 `/agent-flow:dev` 時，本 skill 自己負責執行以下步驟：

1. 讀取專案根目錄 `.claude/settings.json`（若不存在，視為未設定）。
2. 檢查 `worktree.baseRef` 欄位是否等於 `"head"`（依 research 08【證實可持久化】：`worktree.baseRef` 是官方文件記載、可持久化寫入專案 `.claude/settings.json` 的欄位，型別為字串，僅接受 `"fresh"`（預設）或 `"head"`，Scope 為 `Any file`，涵蓋 `.claude/settings.json`）。
3. **未設定或設定為其他值時**：提示使用者「Dev phase 需要每張票證的 worktree 從目前的單位分支分岔，是否同意寫入這項專案設定：`{"worktree": {"baseRef": "head"}}` 到 `.claude/settings.json`？」，徵得同意後代寫（保留既有其他欄位，只新增／覆寫 `worktree.baseRef`）；使用者不同意則停止，不強行進入 Dev phase（Q23 字面裁決，依 research 08 的裁決意義第 1 點）。
4. **`checkout` 到單位分支是互補的第二個前提，不是 `baseRef` 設定的替代方案**：`baseRef: "head"` 的語意是「從目前本地 `HEAD` 分出」，若 orchestrator 當下沒有 checkout 在 `flow/<unit-name>`，即使 `baseRef` 已設為 `"head"`，新建立的 worktree 依然會從錯誤的分支分岔（research 08 的裁決意義第 2 點）。因此，無論步驟 2–3 的檢查結果為何，本 skill 都必須另外確認目前 git 分支就是單位分支 `flow/<unit-name>`（不是則先 `git checkout flow/<unit-name>`，這是 session 自己切換分支的操作，不需要使用者同意，因為不涉及寫入專案設定）。兩者缺一不可：只 checkout 不設定 `baseRef` 會落回預設 `"fresh"`（可能分岔自 remote 的 `main`）；只設定 `baseRef` 不 checkout 到正確分支則會分岔自錯誤的 `HEAD`。

### 平行派工程序（Q11）

1. 讀取全部票證的 `dependsOn`（權威來源：票證 frontmatter；`state.json tickets.<id>.dependsOn` 僅供交叉核對，不作為判斷依據，Q32）。
2. 計算「目前相依已全部完成」的票證集合：`status == "approved"` 且其 `dependsOn` 列出的每一張票證 `status == "merged"`（無 `dependsOn` 的票證第一波即符合資格）。
3. 若該集合為空但仍有未完成票證，代表存在無法推進的相依關係（理論上不應發生，因為 `ticket-writer` 產出的相依圖應是無環的）——若發生，停止並上報：判定 `rootCause: "approved-artifact"`、`escalation.targetArtifact: "ticket"`（根因歸咎於 Ticket phase 產出的相依圖本身），寫入 ESC（`decisions.md` + `state.json escalations[]`）（S11 裁決）。
4. 若集合票證數 ≤ 20：於**同一輪回應**中一次性發出集合內所有票證的 Agent tool 呼叫（`subagent_type: "agent-flow:dev-worker"`，`isolation: worktree`），這構成「一波」（DESIGN §5：多個 Agent tool 呼叫在同一輪回應＝平行）。`baseRef: "head"` 已於「Dev phase 前置檢查」一次性確認／代寫為專案設定，套用到本 session 之後建立的所有 worktree，呼叫本身不需要、也無法額外傳遞 `baseRef` 參數（Agent tool 呼叫參數 schema 中沒有對應欄位，research 08）。
5. 若集合票證數 > 20：先派滿 20 個（依 `parallel-dispatch` internal skill 定義的通則），其餘留待本波有名額釋出（某張已派工票證完成品質迴圈並合併）後再補上，補上時仍檢查新解鎖的票證是否應優先於仍在候位的票證（僅依「相依已滿足」判斷資格，不额外排序優先權，先到先補）。
6. 某張票證的品質迴圈通過並完成合併（見下方「合併與清理」）後，重新執行步驟 2–5，計算是否解鎖了依賴它的下一批票證，若有則發出下一波派工。
7. 全部票證皆 `status == "merged"` 時，Dev phase 完成，自動接續 Review（若由 `orchestrate` 驅動）。

### 建立 worktree 的必要條件（research 07 Test B、research 08）

每次呼叫 `dev-worker` 建立票證 worktree 前，需滿足兩個互補的前提（缺一不可，見「Dev phase 前置檢查」步驟 4，research 08 的裁決意義第 2 點）：

1. orchestrator 已 checkout 到單位分支 `flow/<unit-name>`（本波派工前的既定狀態）。
2. 專案 `.claude/settings.json` 已設定 `worktree.baseRef: "head"`——這是一次性確認／代寫的**專案設定**，套用到本 session 之後所有 worktree 建立，**不是**逐次 Agent tool 呼叫時傳入的參數（Agent tool 呼叫參數 schema 中沒有 `baseRef` 或 `worktree` 欄位，research 08 附帶發現）。

省略任一項都可能導致（尤其專案有 remote 時）worktree 分岔自 remote 的 `main`，而非單位分支目前累積的進度，破壞多票證疊在同一單位分支上逐步累積的設計前提。

### 品質迴圈（逐票證各自一輪，Q4）

1. `dev-worker` 實作到票證測試轉綠，在自己的 worktree 內 commit 一次（Q34），回報完成（回傳中含 `agentId`、`worktreePath`，兩者皆由 Agent tool 呼叫結果原生提供，見 `spec/03-agents.md` 第 10、11 節）。
2. `state.json tickets.<id>.status`（及票證 frontmatter）轉為 `in_review`。
3. orchestrator 以 Agent tool 派工給 `dev-reviewer`，prompt 中帶入該次 `dev-worker` 的 `worktreePath`（不是重新建立隔離環境，`dev-reviewer` 在自己的一般執行環境中 `cd` 進該路徑操作，見 `spec/03-agents.md` 第 11 節的規格本文與其信心邊界，S13 裁決已定案）。**實作前必須優先驗證的信心邊界**：這個「非隔離子代理 `cd` 進另一個子代理的 worktree 目錄操作」的具體場景沒有直接實測依據（見 `spec/03-agents.md` 第 11 節 `dev-reviewer` 的規格本文），且是 Dev phase 品質迴圈能否運作的關鍵前提——若驗證失敗，`dev-reviewer` 將完全無法審查，本節步驟 3–4 需要改採 `spec/03-agents.md` 第 11 節記載的替代機制。實作階段進入 Dev phase 開發前，應**優先**用最小可行範例驗證此假設，不要等到整個 Dev phase 實作完才發現。
4. `dev-reviewer` 獨立重跑測試確認真的轉綠、核對實作與票證/spec 是否吻合、用 `git diff` 核對測試檔案未被修改，依 `quality-loop` 標準輸出格式回傳 `verdict`：
   - `"pass"`：進入「合併與清理」。
   - `"reject"` 且 `findings[].rootCause == "implementation-issue"`：orchestrator（主 session）**親自**用 `SendMessage` 對該 `dev-worker` 的 `agentId` 續談，附上審查意見，要求修正；`dev-worker` 基於既有 worktree 內容繼續修改（不得從頭重寫已通過部分），完成後回到步驟 2。計入 `state.json qualityLoops.dev:<ticket-id>.rounds`，上限 3 輪。
   - `"reject"` 且 `findings[].rootCause == "approved-artifact"`（例如測試檔案被修改，依 `tdd-guide` 規則一律如此分類）：立即寫入 ESC（`decisions.md` + `state.json escalations[]`，`ticket` 欄位填該票證 id），該票證 `status` 轉為 `escalated`，停止該票證的迴圈，等待使用者裁決；**不阻塞**其他票證的並行進度（其他未受影響的票證繼續照常進行）。
   - 達到 3 輪上限仍未通過：寫入 ESC（`rootCause: "round-limit-exceeded"`），票證 `status` 轉為 `escalated`。

**兩個限制（務必遵守，research 06 實驗四、research 07 Test A）**：

1. **不可用重新派工修正同一張票證**——用 Agent tool 再呼叫一次 `dev-worker`（即使 `subagent_type` 相同）一律拿到全新、空白的 worktree，先前的實作與 worktree 內容不會保留。退回修正**只能**透過 `SendMessage` 續談已存在的 `agentId`。
2. **不可委派中介子代理發起續談**——`SendMessage` 續談已完成子代理時，完成通知只會送回**主 session**，不會送回發起續談的那個子代理。若 Dev phase 是被某個中介子代理（而非目前正在執行本 skill 的 session 本身）代為呼叫 `SendMessage`，該中介子代理會永遠等不到完成通知而卡住。因此步驟 3 的 `SendMessage` 續談，**必須**由目前正在執行 `/agent-flow:dev`（或 `orchestrate`）的 session 直接呼叫，不得再包一層委派。

### 合併與清理

某張票證 `dev-reviewer` 審查通過後，orchestrator 依序執行：

1. 在單位分支 `flow/<unit-name>` 的 checkout 下，將該票證 worktree 分支的 commit 合併進單位分支（例如 `git merge --no-ff <worktree-branch>`，保留該次 commit 作為獨立節點，Q34「一票證一 commit，不 squash」）。
2. 合併成功後，`git worktree remove <worktree-path>`（若因鎖定失敗，先 `git worktree unlock <worktree-path>` 再重試）——**立即**執行，不依賴 Claude Code 自動清理（有變更的 worktree 不會被自動清除）。
3. 更新票證 `status` 為 `merged`（frontmatter 與 `state.json tickets.<id>.status` 同步）。
4. `state.json qualityLoops.dev:<ticket-id>.status = "passed"`。
5. 觸發「平行派工程序」步驟 6，計算是否解鎖下一波。

### 產物

- 實作程式碼：先落在票證 worktree，合併後併入單位分支 `flow/<unit-name>`。
- `changes/<unit>/tickets/<ticket-id>.md` 的 `status` 欄位持續更新至 `merged`（或 `escalated`）。

### 承諾點

否（Q3）。全部票證的 Dev 迴圈皆通過（`merged`）後，若由 `orchestrate` 驅動，自動接續 Review。

### 單獨使用時的行為（Q2）

- 若 Ticket 承諾點未核准：停止並提示。
- 續談邏輯（`SendMessage`）不因單獨呼叫而改變——依 DESIGN §2、research 07 Test A 的結論，續談必須由「目前呼叫這個 phase skill 的那個 session 本身」執行，這與是否經過 `orchestrate` 排程外殼無關；單獨呼叫 `/agent-flow:dev` 時，執行 `/agent-flow:dev` 的這個 session 就是負責續談的 session。
- 全部票證通過後不自動接續 Review，使用者需自行呼叫 `/agent-flow:review` 或 `/agent-flow:orchestrate`。

---

## 待對齊

無。原待對齊 #1（相依圖死結的處置）已由 S11 裁決定案（`rootCause: "approved-artifact"`、
`escalation.targetArtifact: "ticket"`，寫入 ESC），改寫進「平行派工程序」步驟 3 規格本文。

（更早一項待對齊「Q23 檢查對象的落差」已由 research 08 查證化解，改回 Q23 字面裁決，詳見
「已定」節與「Dev phase 前置檢查」一節；不再列為待對齊。）
