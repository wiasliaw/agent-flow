# 10 — Build Phase 規格（`skills/build/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R1**：原 Dev phase 改名 Build——以 subagent／worktree 平行執行票證。
- **R12（2026-09-14，證據 research 12／13）**：**取消** Agent tool 的 `isolation: "worktree"`——ticket worktree 改由主 session 自行 `git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit-name>` 建立，以分支名指定來源。R5 的呼叫時隔離參數裁決至此作廢。
- **Q10（承襲，路由依 R3 改版）**：實作者不可改測試——發現測試被改或測試有誤，自動退回 TDD（原 ESC 上報廢止）。
- **Q11／Q34（承襲）**：平行度依票證相依圖分波次；一票證一 commit 不 squash。
- **Q23／research 08 廢止（R12）**：`worktree.baseRef` 專案設定前置條件取消——`git worktree add` 的參數已直接指定來源分支。`SendMessage` 續談規則保留為**首選**，但「重新派工＝全新 worktree、實作全失」的前提消失（worktree 生命週期由主 session 持有，research 13 §2），INV-3 隨之放寬。
- **S11（改版）**：相依圖死結——原判定 `approved-artifact` 寫 ESC，R3 之後改為 waterfall 退回 TDD（根因在相依圖本身）。
- **S13（承襲）**：`reviewer` `cd` 進 worktree 的假設維持、實作前優先驗證。
- **Q4（承襲）**：逐票證標準迴圈 3 輪。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: build
description: >-
  Implements ready tickets in parallel, one isolated worktree per ticket,
  until every contract test goes green and passes independent review.
---
```

### 2. 觸發與前置條件

- **觸發**：`/agent-flow:build`，或由 `orchestrate` 在 TDD 迴圈通過後驅動。
- **前置條件**：`phases.tdd.status == "done"`，且無票證處於 `draft` 或未裁決的 `escalated`。待處理票證——`ready`（待派工）或被靜置的 `in_build`／`in_review`（局部退回恢復時出現，走續談恢復而非重新派工，spec/05 §4.5 步驟 6）。首輪全部 `ready`；waterfall 退回重走輪可為 `ready`／`merged`／靜置狀態混合。**全部票證皆 `merged` 且無待處理票證**（全量退回重走、但票證未受影響的情境）：前置條件視為滿足，**不派工**——直接將 `phases.build` 標記 `"done"` 並自動接續 Review（§4 步驟 7 的空集合特例）。紅燈已由 TDD 審查確認，此處不重新驗證。
- 工作單位判定：`resolve_unit()`。

### 3. Build 前置檢查（INV-13）

計算第一波派工前執行。**不需要使用者設定任何東西**——`git worktree add` 以分支名指定來源，專案設定與當下 checkout 的分支都影響不到分岔基準（R12）：

1. 確認 `.agent-flow/.gitignore` 存在且含 `worktrees/`，不存在則建立。缺這一行時 `git add -A` 會把 worktree 當成 embedded git repository 加入索引（research 13 §3【證實】）。此檔在 agent-flow 自己的目錄內，不動使用者的專案設定。
2. 確認目前分支是 `flow/<unit-name>`，不是則 `git checkout`（session 自身操作，無需同意）。這是為了讓合併落在正確的分支上，與 worktree 的分岔基準無關。

### 4. 平行派工程序（Q11）

0. **局部退回恢復情境**：先依 spec/05 §4.5 步驟 6 以 `SendMessage` 續談恢復被靜置的 `in_build`／`in_review` 票證（原 `agentId`、原 worktree、輪次沿用保留值），再執行以下波次計算。
1. 讀取全部票證 `dependsOn`（權威：frontmatter；`state.json` 僅交叉核對）。
2. 計算可派集合：`status == "ready"` 且 `dependsOn` 全部 `merged`。
3. 可派集合為空但仍有未完成票證時，**依序排除後才可判死結**：
   - 存在 `in_build`／`in_review` 票證（進行中或靜置待恢復）：**等待**其完成當輪處置（或依步驟 0 恢復）後重算，不判死結。
   - 剩餘 `ready` 票證的相依鏈上存在未裁決的 `escalated` 票證：等待使用者裁決，不判死結。
   - 以上皆排除（`ready` 票證之間形成無法滿足的循環相依）＝相依死結：**局部 waterfall 退回 TDD**（`fallback("tdd", "dependency deadlock")`，撤銷情境 (a)，受影響票證＝該循環涉及的票證；根因在相依圖本身，S11 之 R3 改版）。
4. 集合 ≤ 20：先為整波每張票證建立 worktree（`git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit-name>`），再於同一輪回應一次發出整波 Agent tool 呼叫——`subagent_type: "agent-flow:worker"`、**普通派工不帶 `isolation`**（R12）、prompt 依角色簡報契約（角色：ticket implementer；指名 `references/tdd-guide.md`；傳票證與 spec 路徑，以及該 worktree 的**絕對路徑**與「先 `cd` 進去」的指示）。
5. 集合 > 20：先派滿 20，名額釋出後補上（INV-4），先到先補。
6. 每張票證合併完成後重算步驟 2–5，發下一波。
7. 全部票證 `merged` → Build 完成，自動接續 Review（`orchestrate` 驅動時）。

### 5. 品質迴圈（逐票證，`qualityLoops.build:<ticket-id>`，上限 3 輪）

1. `worker` 實作到測試轉綠、worktree 內 commit 一次（Q34），回報（回傳含 `agentId`；`worktreePath` 不需回傳——主 session 建立時就知道，R12）。
2. 票證 `status → in_review`。
3. 派 `reviewer`（指名 `references/tdd-guide.md`、`references/quality-loop.md`；prompt 帶入 `worktreePath`——`reviewer` 在自己的一般執行環境 `cd` 進該路徑操作；**S13 實作前置驗證要求見 spec/03 §3**）。
4. `reviewer` 獨立重跑測試、核對實作與票證／spec 吻合、`git diff` 核對測試檔未被修改，依契約回傳：
   - `pass` → §6 合併與清理。
   - `reject` 且 `targetPhase: "build"`：主 session **親自** `SendMessage` 續談該 `agentId`（INV-3，不可重新派工、不可委派中介），`worker` 基於 worktree 現狀修正；`rounds` 遞增，回到步驟 2。
   - `reject` 且 `targetPhase: "tdd"`（測試檔被修改、或測試本身被判定有誤）：**局部 waterfall 退回 TDD**（spec/05 §4.5 撤銷情境 (a)）——先讓已派出的其他票證完成當輪處置（§4.5 步驟 0：通過者照常合併，退回者靜置、保留狀態與 worktree），期間不發新波次；該票證 `status → draft`、移除其 `build:<id>` key，**未受影響票證的迴圈紀錄與狀態全部保留**；TDD 針對受影響票證重做並重過整批迴圈（`merged`／靜置票證不適用紅燈判準，spec/09 §3），通過後依 §4 步驟 0 恢復靜置票證、受影響票證回到派工集合。
   - `reject` 且任一 blocking finding 的 `targetPhase` 為 `"spec"` 或更早（`"prototype"`／`"explore"`）：依 spec/05 §4.4 取**最早**目標執行**全量** waterfall 退回（§4.5 撤銷情境 (b)，先執行步驟 0 靜置在飛票證）；同輪並存 `targetPhase: "tdd"` 的 finding 時，全量退回的下游重走自然涵蓋之，不另做局部退回。
   - 3 輪超限：ESC（`round-limit`，`ticket` 欄位填該票證），票證 `status → escalated`，不阻塞其他票證。

### 6. 合併與清理

1. 在 `flow/<unit-name>` checkout 下 `git merge --no-ff <worktree-branch>`（一票一 commit，Q34）。
2. 合併後**立即** `git worktree remove`（必要時先 `unlock`）——有變更的 worktree 不會被自動清除。
3. 票證 `status → merged`（frontmatter 與 `state.json` 同步）；`qualityLoops.build:<id>.status = "passed"`。
4. 觸發 §4 步驟 6 計算下一波。

### 7. 承諾點

否。全部票證 `merged` 後自動接續 Review。

### 8. 單獨呼叫時的行為

- TDD 未完成：停止並提示。
- 續談必須由當下執行本 skill 的 session 親自發起（與是否經 orchestrate 無關）。
- Waterfall 退回 TDD 在單獨呼叫情境：執行留痕與狀態撤銷後停止，提示使用者呼叫 `/agent-flow:tdd`（spec/05 §7）。
- 完成後不自動接續 Review（INV-11）。

---

## 待對齊

無。改名、呼叫時隔離參數、退回 TDD 路由是 R1／R5／R3 的直接落地；其餘（波次排程、續談限制、合併清理、S13 驗證要求）承襲原 Dev 規格。
