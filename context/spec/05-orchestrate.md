# 05 — `orchestrate` 總控 Skill 規格

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R1／R2／R3／R5（2026-09-10 重構裁決）**：七 phase、三承諾點、waterfall 自動退回、worker／reviewer 兩 agent。舊 §4.5「rootCause 二分法退回路由」與 S1（Review 全量呈現裁決）由 R3 取代。
- **Q20／Q15（承襲）**：總控 skill 名 `orchestrate`；驅動主 session 自身、不設 `context: fork`（Explore 的對話環節需要主 session 與使用者多輪即時往返）。
- **Q2／Q3 語意承襲**：phase skill 各自獨立、不含接續邏輯；接續與承諾點停等是 orchestrate 層的責任；承諾點依 R2 改為三個。
- **R12（2026-09-14，證據 research 12／13）**：ticket worktree 改由主 session 自行 `git worktree add` 建立，以分支名指定來源；`worktree.baseRef` 專案設定的檢查與徵同意代寫程序（原 Q23／research 08）**整段廢止**。
- **Q21／Q32／Q34（承襲）**：主 session 唯一寫入 `state.json`；票證 frontmatter 為準；phase 迴圈通過即 commit、一票一 commit 不 squash。
- **research 05 實驗二（承襲）**：Agent tool 對 plugin agent 用 `<plugin-name>:<agent-name>` 命名空間，本例 `agent-flow:worker`／`agent-flow:reviewer`。
- **research 07 Test A／B（承襲）**：SendMessage 續談規則、worktree 分岔基準必要條件。
- **spec/02–04**：欄位名稱、agent 定義、角色簡報契約、審查輸出契約一律以該三份為準。

---

## 規格本文

### 1. Frontmatter

檔案路徑：`skills/orchestrate/SKILL.md`。

```yaml
---
name: orchestrate
description: >-
  Drives all seven phases in sequence, stopping only at the three approval
  gates and falling back automatically to the faulty phase when a review
  finds its root cause upstream.
---
```

- 不設 `context: fork`（Q15）；不設 `model`／`agent`／`user-invocable`（維持預設）。

### 2. 啟動與工作單位建立

#### 2.0 前置載入（R4）

執行任何後續程序前，主 session 先 `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md`（路徑解析基準見 spec/04 通則 3；本檔與 spec/06–12 的 `references/<name>.md` 簡寫皆依同一規則展開為絕對路徑，派工時傳絕對路徑）——所有程序區塊的 primitives、變數、共用程序與 INV 編號以其為準。

#### 2.1 判斷「新工作單位」或「接續既有工作單位」

1. 使用者輸入指向既有 `.agent-flow/changes/<unit-name>/`（明確提及單位名，或目前分支是 `flow/<unit-name>`）：讀取 `state.json`（依 `references/state-management.md`），從 `currentPhase`／`phases`／`gates` 判斷接續點。
2. 否則執行 `create_unit()`（§2.3）。

#### 2.2 Worktree 前置設定檢查——已廢止（R12）

本節原規定進 Build 前檢查專案 `.claude/settings.json` 的 `worktree.baseRef`、缺少時徵求使用者同意代寫。R12 之後主 session 以 `git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit-name>` 自建 worktree，來源分支由參數直接指定，**沒有任何使用者設定會影響分岔基準**，因此整段程序取消，orchestrate 不再向使用者要求任何前置設定。Build 自己的兩項檢查（`.agent-flow/.gitignore` 含 `worktrees/`、checkout 到單位分支）見 spec/10 §3。

#### 2.3 建立工作單位

1. 決定 `<unit-name>`：`<YYYY-MM-DD>-<slug>`（Q28；slug 推導規則承襲：2–4 個英文關鍵詞 kebab-case，同日撞名加遞增後綴）。
2. 建立 `.agent-flow/changes/<unit-name>/`。
3. 建立 `.agent-flow/.gitignore`（內容單行 `worktrees/`，R12——使 ticket worktree 不被 `git add -A` 當成 embedded repository 加入索引；檔案在 agent-flow 自己的目錄內，不動使用者的專案設定）。
4. 初始化 `state.json`（spec/02 §2.2）：`schemaVersion: 2`、`currentPhase: "explore"`、`phases` 七 key 皆 `pending`、`gates` 三 key（`explore`／`spec`／`review`）皆 `{"approvedAt": null, "approvedBy": null}`（保留物件形狀，spec/02 §2.2）、`qualityLoops: {}`、`tickets: {}`、`fallbacks: []`、`escalations: []`、`branch: {"unit": "flow/<unit-name>", "baseRef": "main"}`。
5. `git checkout -b flow/<unit-name> main`。
6. 進入 Explore。

### 3. Phase 接續與三個承諾點

| 順序 | Phase | 承諾點？（R2） | 自動接續條件 |
|---|---|---|---|
| 1 | Explore | 是 | 核准後：疑問清單非空 → Prototype；為空 → Spec |
| 2 | Prototype | 否（optional，可整段略過） | 迴圈通過即自動進 Spec |
| 3 | Spec | 是 | 核准後進 TDD |
| 4 | TDD | 否 | 迴圈通過（測試合約生效）即自動進 Build |
| 5 | Build | 否 | 全部票證 `merged` 後自動進 Review |
| 6 | Review | 是 | 核准後進 Wrap |
| 7 | Wrap | 否（全自動） | 完成即流程結束 |

#### 3.1 承諾點的呈現行為（通則）

1. 該 phase 品質迴圈已通過（`qualityLoops.<key>.status == "passed"`）。
2. 讀取產物檔案向使用者呈現（Explore 呈現意圖摘要＋調查結論＋疑問清單；Spec 呈現規格全文；Review 呈現 `review.md`）。
3. 明確提出核准請求，等待輸入。
4. 核准：寫入 `gates.<phase>`，commit（`flow(<unit>): <phase> passed review`），進下一 phase。
5. 不核准並提出修改意見：
   - 對產物的具體修改要求：視為使用者直接介入的一次額外退回（不計輪，INV-7），派回作者修訂後重新呈現。
   - 要求回到更早 phase 重做：視同**使用者發起的 waterfall 退回**，執行 §4.5 同一程序，FB 條目「原因」欄標記「使用者主動」。

### 4. 派工程序

#### 4.1 Agent tool 呼叫語法與角色簡報

`subagent_type: "agent-flow:worker"` 或 `"agent-flow:reviewer"`。Prompt 依 spec/03 通則 4 的五要素（角色、references 清單、輸入路徑、產物路徑、輸出格式＋輪次）。範例：

```
Agent(subagent_type="agent-flow:worker",
      description="Write delta spec for 2026-09-10-password-reset",
      prompt="Role: spec author. First Read references/sdd-guide.md.
              Inputs: changes/2026-09-10-password-reset/explore.md and
              (if present) prototype.md, plus .agent-flow/specs/<domain>/spec.md.
              Write changes/2026-09-10-password-reset/spec-delta.md following
              the EARS and ADDED/MODIFIED/REMOVED contract.")
```

#### 4.2 檔案路徑傳遞、輕量引用回傳

Prompt 一律傳檔案路徑不貼內容；子代理只回「結論摘要＋讀寫路徑清單」；審查回傳必須是 `references/quality-loop.md` 的 JSON 契約。

#### 4.3 標準迴圈的輪次管理

1. 派 `worker`（作者角色）撰寫產物。
2. 派 `reviewer`，prompt 告知 `round`／`maxRounds: 3`。
3. 依 `verdict` 分流：`"pass"` → `qualityLoops.<key>.status = "passed"`，承諾點 phase 進 §3.1、否則自動接續；`"reject"` → 依 §4.4／§4.5 路由。
4. 第 3 輪仍 `reject` 且路由為 in-phase：轉 ESC（§4.6，`round-limit`），`qualityLoops.<key>.status = "escalated"`。

#### 4.4 讀取審查結果

解析 `verdict` 與 `findings[].targetPhase`（`references/quality-loop.md` 契約；`reject` 若且唯若存在 blocking finding，僅 non-blocking 時 reviewer 必須輸出 `pass`）。**路由只由 blocking finding 驅動**，non-blocking finding 不影響路由（隨 in-phase 修訂順帶處理，或留待承諾點知情呈現）：

- `verdict == "pass"`：通過（non-blocking findings 照紀錄）。
- `verdict == "reject"` 且 blocking findings 的 `targetPhase` 全部為當前 phase：in-phase 退回原作者（一般 phase 重新派工附全部 findings；Build 用 `SendMessage` 續談，§5），`rounds` 遞增。
- `verdict == "reject"` 且任一 blocking finding 的 `targetPhase` 為較早 phase：執行 §4.5 waterfall 退回；多個較早目標並存時，**取最早的 `targetPhase`**（合法值為當前 phase 之前的任何 phase，含 `prototype`）一次退回，下游重走自然涵蓋其餘。
- Review 重型迴圈的差異見 §4.7 與 spec/11-review.md。

#### 4.5 Waterfall 退回程序（R3，核心）

`fallback(toPhase, reason)`：

0. **靜置進行中派工**：若有已派出、尚未完成的子代理呼叫（Build 平行波次），先讓它們完成當輪處置（審查通過者照常合併；被退回者靜置——局部退回時保留狀態與 worktree 待步驟 6 恢復，全量退回時依步驟 3(b) 處置），期間不發出任何新派工；全部收斂後才執行以下步驟。
1. **前置檢查**：`state.json.fallbacks` 中 `toPhase` 相同的既有筆數若已達 2（本次為第 3 次），不執行退回，改走 §4.6 ESC（`rootCause: "fallback-limit"`）。
2. **FB 留痕（原子雙寫，INV-12）**：`decisions.md` 追加 `## FB-<n>` 條目（spec/02 §2.3 模板，含撤銷範圍與被撤銷 gate 的原核准時間），`state.json.fallbacks` push 對應元素。
3. **撤銷狀態**，依情境分兩種：
   - **(a) 局部退回**（`fromPhase == "build"` 且 `toPhase == "tdd"`，僅部分票證受影響——含相依死結情境）：Build 不整段撤銷——`phases.build` 維持 `"in_progress"`；未受影響票證的 `qualityLoops.build:<id>` 與票證狀態**全部保留**，只移除受影響票證的 `build:<id>` key；`phases.tdd → "in_progress"`、`qualityLoops.tdd` 重置；`currentPhase = "tdd"`（TDD 重過後轉回 `"build"`）。
   - **(b) 全量退回**（其他情境：`toPhase` 為 `"explore"`／`"prototype"`／`"spec"`，或由 Review 觸發）：`toPhase` 之後的全部 phase `status → "pending"`、`toPhase` 本身 → `"in_progress"`；被涵蓋 gate 的 `approvedAt`／`approvedBy` 重置為 `null`（保留物件形狀，spec/02 §2.2）；移除下游 phase 的 `qualityLoops` key（含 `build:*`），**唯一例外：`qualityLoops.review` 不移除**——其 `rounds` 是 Q29 五輪上限的持久預算，跨退回保留，僅將 `status` 改為 `"in_progress"`（本輪審查結果失效、預算不歸零）；步驟 0 收斂後仍處於 `in_build`／`in_review` 的票證（當輪被退回未通過者）：移除其 worktree、`status → "ready"`——未合併的部分實作捨棄，重走 Build 時重新派工，TDD 差異判定可再將其轉 `draft`；`currentPhase = toPhase`。其餘標準迴圈 phase 重走時輪次重新起算（震盪由步驟 1 的 fallback 上限約束）。
4. **產物保留為底稿**：既有產物檔案不刪除；重做以現有內容為底修訂，不從零重寫。**產物有效性以 `state.json` 的 phase 狀態為準，不以檔案存在為準**：被撤銷 phase 的殘留檔案只是底稿，下游 phase 不得把它當成有效輸入（例：退回 Explore 重做後疑問清單變為空 → `phases.prototype = "skipped"`，殘留的舊 `prototype.md` 不再是 Spec 的有效輸入）。
5. **票證處置**：
   - 局部退回（`toPhase == "tdd"`）→ 受影響票證（測試或票證內容需修訂者）`status → "draft"`；其餘不動——含被步驟 0 靜置、保留 `in_build`／`in_review` 狀態的進行中票證（恢復程序見步驟 6）。
   - 全量退回（`toPhase` 為 `"spec"` 或更早）→ **退回當下不改任何票證狀態**；受影響集合的判定延後到重走 TDD 時執行（spec/09 §2 的差異判定）：測試行為受需求增修刪波及的票證重置 `status → "draft"` 並重做；僅票證資料（相依、編號、描述）需修正者直接修訂、不轉 `draft`；未受影響票證維持原狀態——`merged` 沿用既有實作與證據、`ready` 沿用既有紅燈測試，**不因退回被要求重新呈現紅燈**。
   - 通則：Build 已合併進單位分支的 commit **不回退**；重走 Build 時只派「測試轉紅或票證內容有變」的票證，已綠且未受影響的票證直接視為 `merged`。TDD 重做輪的紅燈判準只適用於**本輪新增或修改的測試案例**，實作已滿足新案例時（補測試覆蓋）以可失敗性證據替代紅燈（spec/09 §2–§3），其餘改核對合約完整性（`references/tdd-guide.md`）。
6. **重做與重走**：`toPhase` 重做 → 品質迴圈 → （若為承諾點）**重新核准**（INV-8）→ 依 §3 順序往下重走，直到回到 `fromPhase` 繼續。局部退回情境：TDD 重過後恢復 Build，**先恢復被靜置的進行中票證**——對每張保留 `in_build`／`in_review` 的票證，主 session 以 `SendMessage` 續談其原 `agentId`（其 worktree 因尚未合併而保留，research 07 Test A）繼續原修正，輪次沿用保留的 `qualityLoops.build:<id>.rounds`——再恢復 `ready` 票證的波次排程。

#### 4.6 ESC 上報

觸發條件只剩三種（R3）：`round-limit`（§4.3）、`fallback-limit`（§4.5 步驟 1）、`wrap-failure`（spec/12）。程序：

1. 決定 `ESC-<n>`，`decisions.md` ＋ `state.json.escalations` 原子雙寫（`resolvedAt: null`）。
2. 對應 `qualityLoops.<key>.status = "escalated"`（Wrap 情境無迴圈 key，略）。
3. 向使用者呈現 ESC 內容，等待裁決；裁決後回填兩處，依裁決內容決定後續。

#### 4.7 重型迴圈（Review）

`maxRounds: 5`（Q29）；派工對象是 3 個 `reviewer` lens ＋ 1 個 `reviewer` triage；`qualityLoops` key 固定 `"review"`。與標準迴圈的路由差異（R3 取代 S1）：blocking finding 的 `targetPhase == "build"` 時不是續談（Review 時已無進行中的 worker），而是主 session 自建修正用 worktree 後派**全新** `worker` 進去（R12）修正，再重跑一輪；`targetPhase` 更早則走 §4.5。完整程序見 spec/11-review.md。

### 5. Build 的 SendMessage 續談

1. `reviewer` 判定某票證 reject 且 `targetPhase: "build"`。
2. 主 session **親自**（不可委派中介）`SendMessage` 至該 `worker` 的 `agentId`，附 findings。
3. 不可重新派工（全新 worktree，research 06 實驗四）。
4. 續談完成後重新派 `reviewer`（審查是重新派工，不需保留狀態），`rounds` 遞增，上限 3。

### 6. 事件 → `state.json` 更新對照表

| 事件 | 更新欄位 |
|---|---|
| 建立工作單位 | 整份初始化（§2.3） |
| Phase 開始 | `phases.<phase>.status = "in_progress"`、`currentPhase` |
| Phase 迴圈通過 | `phases.<phase>.status = "done"`、`artifact`、`qualityLoops.<key>.status = "passed"` |
| Prototype 略過 | `phases.prototype = {"status": "skipped", "reason": "no open technical question"}` |
| 承諾點核准 | `gates.<phase>` |
| 迴圈完成一輪 | `qualityLoops.<key>.rounds`／`status` |
| Waterfall 退回 | `fallbacks` push、下游 `phases`／`gates`／`qualityLoops` 撤銷、`currentPhase`、票證狀態（§4.5） |
| 票證 frontmatter 異動 | `tickets.<id>` 鏡像同步 |
| ESC 上報／裁決 | `escalations` push／`resolvedAt` 回填 |
| 每次寫入 | `updatedAt` |

### 7. 單獨呼叫某個 phase skill（Q2）

使用者直接呼叫 `/agent-flow:<phase>` 時，該 phase skill 自己承擔：(a) 前置條件檢查；(b) 驅動自己的品質迴圈；(c) 承諾點 phase 自己呈現核准並寫 `state.json`；(d) 完成後不自動接續。**Waterfall 退回在單獨呼叫情境的特例**：當下 session 仍執行 §4.5 步驟 1–5（留痕與狀態撤銷），但**不自動跨 phase 重做**——停止並提示使用者依序呼叫 `/agent-flow:<toPhase>` 重做（Q2：跨 phase 接續屬於 orchestrate）。

---

## 待對齊

無。§4.5 的退回程序細節（最早 targetPhase 優先、fallback 上限 3 次、票證處置規則）是 R3 落地時的機械推導與 PROMPT 第 5 步授權的實作細節選擇；其餘內容承襲既有裁決或直接推導自 R1／R2／R5。
