# 05 — `orchestrate` 總控 Skill 規格

## 已定（來源與依據）

- **Q20**：總控 skill 命名為 `orchestrate`（呼叫名 `/agent-flow:orchestrate`）。
- **Q15**：orchestrator 是「總控 skill 引導主 session」的行為，不透過 `settings.json` 的 `agent`
  欄位固化——`orchestrate` 因此**不**設 `context: fork`，其內容驅動的是主 session 自身（DESIGN
  §2：「不是被 `context: fork` 出去的獨立子代理，而是載入主 session 自身 context 的一份腳本」）。
- **Q23**：啟動（實際上是「進入需要該設定的 phase 前」，見規格本文 2.2 的釐清）發現專案缺
  `worktree.baseRef` 設定時，檢查、提示、徵求同意後代寫；DESIGN §9 旅程步驟 7、§7「限制」段落。
- **research 08**【證實可持久化】：`worktree.baseRef` 是官方 `settings-reference` 文件記載、可
  持久化寫入 `.claude/settings.json` 的欄位（Scope: `Any file`，型別為字串，僅接受
  `"fresh"`（預設）／`"head"`），欄位路徑與格式為 `{"worktree": {"baseRef": "head"}}`；本節 §2.2
  的檢查與代寫流程即依此欄位逐字實作，非規格層級的推論或替代解讀。此查證同時化解了
  `spec/11-dev.md` 原待對齊 #1 對 Q23 可行性的疑慮（詳見 research/08、`spec/11-dev.md` 已定節）。
- **Q3**：四個承諾點（Discuss／Spec／Ticket／Review）停下等待使用者核准；Explore／Prototype／Dev
  自動接續；Wrap 全自動。
- **Q2**：八個 phase skill 各自獨立、不含接續邏輯；自動接續是 orchestrate 層的責任。
- **Q11、Q12、Q28**：Dev 平行機制（子代理＋worktree 隔離）、分支結構（單位分支＋票證 worktree
  兩層）、工作單位命名 `<YYYY-MM-DD>-<slug>`。
- **Q21、Q32**：`orchestrate` 是唯一寫入 `state.json` 者；票證 frontmatter 為準、`state.json`
  同步。
- **Q34**：commit 顆粒度——phase 品質迴圈通過即 commit、一票一 commit 不 squash。
- **DESIGN §2**：架構圖、Discuss 對話環節是主 session 的唯一例外、Skills 分層（`orchestrate` 可
  載入的 internal skills）。
- **DESIGN §3（各節）**：八個 phase 的進入條件、產物、品質迴圈、承諾點——本檔只整合「orchestrate
  如何驅動它們」，各 phase 自身細節見 spec/06–13。
- **DESIGN §4**：品質迴圈由 orchestrator 派審查子代理達成（不是靠 hook）；根因分流二分法；輪數
  上限；ESC 留痕與 `state.json` 同步。
- **DESIGN §5**：派工語法（`Agent(subagent_type="agent-flow:<role>")`，research 05 實驗二證實）、
  票證相依圖分波次派工、輸出落地檔案只傳輕量引用（research 04）、巢狀深度限制。
- **DESIGN §6、§7**：`state.json` 完整 schema（精確版見 spec/02-state.md）、兩層分支結構、
  worktree 生命週期、commit 時機。
- **DESIGN §9**：完整旅程範例（步驟 1–10）——本檔規格本文的「程序步驟」逐一對應此範例並精確化。
- **research 05 實驗二**【證實】：Agent tool 的 `subagent_type` 對 plugin agent 使用
  `<plugin-name>:<agent-name>` 命名空間，本例為 `agent-flow:<role>`。
- **research 07 Test A、Test B**：SendMessage 續談規則（worktree／context 完整保留，但完成通知
  只回主 session）；worktree 分岔基準必要條件（`baseRef: head`）。
- **spec/02-state.md、spec/03-agents.md、spec/04-internal-skills.md**：本檔所有欄位名稱、agent
  檔名／模型、審查者輸出格式契約，一律以這三份已定案規格為準，不重新發明。
- **S1（裁決記錄，未採 DESIGN §3.7 原建議——實質設計變更）**：Review phase 的退回路由不適用
  §4.5／本檔 §5 定義的自動退回機制；全部 finding 一律在 Review 承諾點呈給使用者裁決，使用者
  核准修正後由 orchestrator 派全新（非續談）`dev-worker` 執行修正。已登記到 `spec/README.md`
  「DESIGN.md 回寫記錄」；詳細機制見 spec/12-review.md。

---

## 規格本文

### 1. Frontmatter

檔案路徑：`skills/external/orchestrate/SKILL.md`。

```yaml
---
name: orchestrate
description: >-
  Drives all eight phases in sequence, stopping only at the four approval
  gates, so you don't have to invoke each phase by hand.
---
```

- **`description`**：逐字採用 DESIGN §9「External skills 的一句話文案」表格（Q40 核准），不改寫。
- **不設 `context: fork`**：硬性規格（Q15、DESIGN §2）——`orchestrate` 必須驅動主 session 自身，
  fork 出去的子代理無法與使用者進行 Discuss phase 所需的多輪即時對話（DESIGN §2「主 session 唯一
  的例外」）。
- **不設 `disable-model-invocation`／`user-invocable`**：external skill 使用預設值即可（使用者可
  透過 `/agent-flow:orchestrate` 呼叫、Claude 也可能在使用者自然語言請求「幫我做一個完整的 XX
  功能」時自動判斷觸發此 skill）——DESIGN.md 沒有要求限制 Claude 的自動觸發能力，維持預設。
- **不設 `agent`**（`context: fork` 專用欄位）：因為不設 `context: fork`，此欄位不適用。
- **不設 `model`／`effort`**：orchestrate 驅動的是主 session，理應沿用使用者當下 session 的模型
  設定，不覆寫。

### 2. 啟動與工作單位建立

#### 2.1 判斷「新工作單位」或「接續既有工作單位」

`orchestrate` 被呼叫時，先判斷使用者意圖：

1. 若使用者輸入的參數／訊息指向一個既有的 `.agent-flow/changes/<unit-name>/` 目錄（例如使用者
   明確提及某個工作單位名，或目前 git 分支就是某個 `flow/<unit-name>`），讀取該單位的
   `state.json`（依 `state-management` internal skill 的讀取規範，spec/04-internal-skills.md
   第 1 節），從 `currentPhase` 與各 `phases.<phase>.status`／`gates.<phase>` 判斷應接續到哪個
   phase。
2. 否則視為建立新工作單位，執行 §2.3「建立工作單位」。

#### 2.2 Worktree 前置設定檢查（Q23）

**時機釐清**：DESIGN §7、Q23 原文用語是「orchestrate 啟動時檢查」，但 DESIGN §9 旅程範例把這個
檢查具體排在步驟 7「Dev 前置檢查」，即進入 Dev phase 之前，而非工作單位一開始（Discuss 之前）就
執行。本規格採用旅程範例的具體時機為準：**這項檢查只在即將進入 Dev phase（第一次需要建立票證
worktree）之前執行**，因為 `worktree.baseRef` 只影響 Dev phase 的 worktree 建立行為，在 Discuss／
Explore／Prototype／Spec／Ticket 階段沒有作用，提前檢查沒有實質效益，且會讓使用者在流程一開始就
被問一個當下無關的設定問題。此為文字表述層次的精確化，非 DESIGN.md 內部矛盾。

**檢查步驟**：

1. 讀取專案根目錄的 `.claude/settings.json`（若不存在，視為未設定）。
2. 檢查 `worktree.baseRef` 欄位是否等於 `"head"`。
3. 若已設定為 `"head"`：略過，直接進入 Dev phase。
4. 若未設定，或設定為其他值（如預設的 `"fresh"`）：向使用者呈現以下提示（可依實際情境微調文字，
   但須包含這三個要素：現況、原因、要寫入的具體內容）：

   ```
   Dev phase 需要每張票證的 worktree 從目前的單位分支分岔，而不是從遠端 main 分岔
   （否則多張票證會各自基於不同的起點，無法正確疊在同一個單位分支上累積）。

   這需要在 .claude/settings.json 設定：
     { "worktree": { "baseRef": "head" } }

   是否同意寫入這項專案設定？
   ```

5. 使用者同意後，讀取現有 `.claude/settings.json`（若存在，保留其他既有欄位，只新增／覆寫
   `worktree.baseRef` 為 `"head"`；若不存在則新建僅含此欄位的檔案）並寫入。
6. 使用者不同意：停止流程，不強行進入 Dev phase（此為使用者主動否決 orchestrate 的建議，屬於
   使用者裁決，不觸發 ESC 上報機制——ESC 是給「agent 之間的分歧」用的，不是給「使用者不同意
   orchestrate 的建議」用的）。

此檢查與 Dev phase 內部「每次建立票證 worktree 前都要確認 `baseRef: head` 生效」（spec/11-dev.md、
`using-worktree` internal skill 規則 1）是不同層次的動作：本節是「專案設定是否存在」的一次性檢查
（存在即不重複詢問，套用到本 session 之後建立的所有 worktree，`baseRef` 是持久化的專案設定而非
逐次 Agent tool 呼叫時傳入的參數，research 08），Dev phase 內部規則是「orchestrator 是否已 checkout
到正確的單位分支」這個互補前提的執行期保證（見 spec/11-dev.md「建立 worktree 的必要條件」）——
後者依賴前者已完成，但不是同一件事，兩者缺一不可。

#### 2.3 建立工作單位

1. **決定 `<unit-name>`**：格式 `<YYYY-MM-DD>-<slug>`（Q28）。
   - 日期：建立當下的日期（`YYYY-MM-DD`，與 `state.json.createdAt` 同一天）。
   - `slug`：從使用者這次請求的核心意圖推導，規則（PROMPT 第 5 步「規格沒寫的細節選最簡單做法」
     授權的實作細節，非需要使用者裁決的設計決策）：取使用者請求中最能代表功能主題的 2–4 個英文
     單詞（若使用者以中文描述，先意譯為對應的英文關鍵詞），轉小寫、以連字號連接（kebab-case），
     去除標點與贅字（如 the/a/for）。範例：使用者說「幫使用者加上忘記密碼流程」→
     `password-reset`；完整單位名 `2026-09-04-password-reset`（DESIGN §9 旅程範例採用的正是這個
     值，可作為驗證此規則的參照）。
   - 若同一天已存在相同 slug 的目錄，附加遞增數字後綴（`-2`、`-3`⋯）避免覆蓋。
2. **建立目錄**：`.agent-flow/changes/<unit-name>/`。
3. **初始化 `state.json`**：依 spec/02-state.md §2.2 schema，`schemaVersion: 1`、
   `unit: <unit-name>`、`createdAt`／`updatedAt` 為當下時間、`currentPhase: "discuss"`，
   `phases` 八個 key 皆為 `{"status": "pending"}`，`gates` 四個 key 皆為
   `{"approvedAt": null, "approvedBy": null}`，`qualityLoops: {}`、`tickets: {}`、
   `escalations: []`，`branch: {"unit": "flow/<unit-name>", "baseRef": "main"}`。
4. **切出單位分支**：`git checkout -b flow/<unit-name> main`（從 main 切出，DESIGN §7）。
5. **進入 Discuss phase**（依 §3 驅動）。

### 3. Phase 接續與四個承諾點

`orchestrate` 依序驅動以下順序，每個 phase 的具體程序見對應規格檔（spec/06–13）；本節只定義
**接續邏輯與承諾點呈現行為**：

| 順序 | Phase | 承諾點？（Q3） | 自動接續條件 |
|---|---|---|---|
| 1 | Discuss | 是 | 使用者核准後才進入 Explore |
| 2 | Explore | 否 | 品質迴圈通過即自動進入下一步 |
| 3 | Prototype | 否（可能整段略過） | 若 Explore 產出無未解決技術疑問，略過本 phase 直接進入 Spec；否則品質迴圈通過即自動接續 |
| 4 | Spec | 是 | 使用者核准後才進入 Ticket |
| 5 | Ticket | 是 | 使用者核准後才進入 Dev |
| 6 | Dev | 否 | 全部票證的 Dev 品質迴圈皆通過後自動進入 Review |
| 7 | Review | 是 | 使用者核准後才進入 Wrap |
| 8 | Wrap | 否（全自動） | 完成後整個流程結束，無下一步 |

#### 3.1 承諾點的呈現行為（通則）

四個承諾點的呈現遵循同一個模式（各 phase 的具體呈現內容見 spec/06、09、10、12）：

1. 該 phase 的品質迴圈已通過（`qualityLoops.<key>.status == "passed"`）。
2. `orchestrate` 讀取該 phase 的產物檔案，向使用者呈現內容（依 phase 而定：Discuss 呈現意圖
   摘要、Spec 呈現規格全文、Ticket 呈現票證清單與測試檔案位置、Review 呈現缺口/問題摘要）。
3. 明確提出核准請求（例如「是否核准進入 Explore？」），等待使用者輸入。
4. 使用者核准：寫入 `state.json.gates.<phase> = {"approvedAt": <now>, "approvedBy": "user"}`，
   commit（Q34：「phase 通過即 commit」，訊息格式 `flow(<unit>): <phase> passed review`），
   進入下一 phase。
5. 使用者不核准、提出修改意見：視意見性質分兩種處理——
   - 若是對產物內容的具體修改要求（例如「這條需求描述不對」）：視為對該 phase 品質迴圈的一次
     額外退回（不計入原本的審查者退回輪數，是使用者直接介入），委派回該 phase 的作者子代理修改
     後重新呈現。
   - 若使用者要求回到更早的 phase 重做：`orchestrate` 依 DESIGN §5「已核准產物不可自行推翻」
     原則處理——若目標 phase 尚未核准（例如 Explore 還沒到承諾點），可直接退回；若目標 phase
     已核准（例如已通過 Discuss 承諾點又想改），這是使用者主動要求修改已核准產物，使用者本人的
     裁決優先於「agent 不自行推翻」規則（該規則限制的是 agent 自行推翻，不限制使用者本人的決定），
     `orchestrate` 執行後應在對應的 `changes/<unit>/decisions.md` 追加一筆記錄留痕（沿用 ESC
     模板格式，`根因分類` 填「使用者主動修改」，`使用者裁決` 填修改內容摘要），但這不是標準
     ESC 上報流程（不寫入 `state.json.escalations`，因為那個陣列的語意是「agent 之間分歧觸發的
     上報」，不是「使用者主動要求變更」——此為 PROMPT 第 5 步授權的實作細節選擇，若使用者認為
     這種情境也該計入 `escalations`，屬於可裁決的細節，本規格採較簡單的區分方式）。

### 4. 派工程序

#### 4.1 Agent tool 呼叫語法

一律用 `subagent_type: "agent-flow:<role>"`（research 05 實驗二證實），`<role>` 為
spec/03-agents.md 定案的 17 個角色檔名之一（不含 `.md` 副檔名）。範例：

```
Agent(subagent_type="agent-flow:spec-writer",
      description="Write delta spec for 2026-09-04-password-reset",
      prompt="Read changes/2026-09-04-password-reset/explore.md and (if present)
              prototype.md, then write changes/2026-09-04-password-reset/spec-delta.md
              following the sdd-guide internal skill's EARS/delta contract.")
```

#### 4.2 檔案路徑傳遞、輕量引用回傳（research 04）

- Prompt 內容一律傳遞**檔案路徑**（相對於專案根目錄，或明確的絕對路徑），不把前一階段產物整段
  貼入 prompt 文字。
- 子代理完成後的回傳，`orchestrate` 只需要：(a) 一句結論摘要；(b) 它寫入或修改的檔案路徑清單。
  完整內容永遠留在檔案系統，`orchestrate` 需要細節時另行 `Read` 該檔案，不依賴子代理在對話中
  複述內容。
- 審查子代理的回傳**必須**是 spec/04-internal-skills.md `quality-loop` 定義的標準 JSON 格式
  （見 §4.4）；`orchestrate` 在派工 prompt 中明確要求審查子代理以該格式輸出（可附上格式範例）。

#### 4.3 標準迴圈的派工與輪次管理

適用 Discuss／Explore／Prototype／Spec／Ticket／Dev（逐票證）。以 Spec phase 為例，通則對其餘
標準迴圈 phase 一致：

1. 第 1 輪：`orchestrate` 派工作者子代理（如 `spec-writer`）撰寫產物。
2. 作者完成後，`orchestrate` 派審查子代理（如 `spec-reviewer`），prompt 中告知目前是第幾輪
   （`round`）與上限（`maxRounds: 3`）。
3. 讀取審查子代理回傳的 JSON（依 §4.4 解析），依 `verdict` 分流：
   - `"pass"`：寫入 `state.json.qualityLoops.<key> = {"rounds": <當輪次>, "maxRounds": 3,
     "status": "passed"}`，該 phase 完成，若為承諾點 phase 則進入承諾點呈現（§3.1），否則自動
     接續下一 phase。
   - `"reject"`：依 `findings[].rootCause` 分流（見 §4.5）。
4. 若 `rounds` 即將超過 `maxRounds`（即本輪已是第 3 輪且仍為 `reject`）：不再派工修改，直接轉為
   ESC 上報（見 §4.6），`qualityLoops.<key>.status = "escalated"`。

#### 4.4 讀取審查結果

依 spec/04-internal-skills.md `quality-loop` 一節定案的 JSON schema 解析：

- `verdict`：決定通過或退回。
- `findings[].rootCause`：`"implementation-issue"` 或 `"approved-artifact"`，決定退回路由
  （§4.5）。
- `escalation`：`verdict = "reject"` 且任一 finding 的 `rootCause` 為 `"approved-artifact"`
  時必填，`targetArtifact` 指出根因指向哪個已核准產物（`"discuss"`／`"spec"`／`"ticket"`）。

Review phase 的重型迴圈另有兩層格式（原始 finding／`review-triage` 裁定），`orchestrate` 解析
`review-triage` 的裁定輸出（沿用標準迴圈 schema 形狀）彙整進 `review.md`；三個平行小組的原始
finding 只是中介產物，不直接呈現給使用者。**與其他標準迴圈 phase 不同**：Review 的 `verdict`／
`findings[].rootCause` 依 S1 裁決**不驅動自動路由**（不自動退回、不自動 ESC），`orchestrate`
只是把全部 finding（不分根因分類）整理進 `review.md` 交給使用者在 Review 承諾點裁決，實際路由
邏輯見 §5 與 spec/12-review.md「純實作問題的修正機制」。

#### 4.5 退回路由（Q5）

- **`implementation-issue`**：問題出在本 phase 內、尚未核准的產物，由 `orchestrate` 退回原作者
  子代理修正：
  - 一般 phase（Discuss／Explore／Prototype／Spec／Ticket）：`orchestrate` 用 Agent tool
    **重新派工**同一個角色（同 `subagent_type`，新的一次呼叫），prompt 中附上審查子代理的
    `findings`，要求依此修正。
  - Dev phase（`dev-worker`）：**不可**重新派工（會拿到全新 worktree，research 06 實驗四），
    必須由 `orchestrate` 親自用 `SendMessage` 續談同一個 `agentId`（見 §5）。
  - `rounds` 遞增 1，寫回 `state.json`。
- **`approved-artifact`**：根因在已核准產物，`orchestrate` **不**退回任何子代理修改，直接轉為
  ESC 上報（§4.6），無論目前輪次是第幾輪（Q5：無論輪數，一律立即上報）。

#### 4.6 ESC 上報（超限或根因在已核准產物）

依 spec/02-state.md §2.3、spec/04-internal-skills.md `quality-loop` 規則 6：

1. `orchestrate` 決定新的 `ESC-<n>`（`n` 為該工作單位內目前既有 ESC 數量 + 1）。
2. 同時（視為一個原子操作的兩部分）：
   - 在 `changes/<unit>/decisions.md` 追加 `## ESC-<n>` 區塊（「使用者裁決」「裁決時間」留空／
     標記「待裁決」）。
   - 在 `state.json.escalations` push 一筆新元素（`resolvedAt: null`）。
3. 更新對應 `qualityLoops.<key>.status = "escalated"`。
4. 向使用者呈現 ESC 內容，等待裁決（此為除四個承諾點之外，`orchestrate` 停下等待使用者輸入的
   另一種情境——ESC 上報本質上也是一種「交還控制權給使用者」的動作，但不是 Q3 定義的四個「承諾
   點」之一，是品質迴圈本身的例外出口）。
5. 使用者給出裁決後，回填 `decisions.md` 與 `state.json.escalations[].resolvedAt`，依裁決內容
   決定後續（可能是：修改已核准產物並重新走該 phase 的品質迴圈與承諾點；或維持現狀、判定審查者
   誤報，退回重試；或其他使用者指示的動作）——具體後續動作由使用者裁決內容決定，`orchestrate`
   不預設固定的「裁決後行為」，因為 DESIGN.md 沒有為每一種可能的裁決結果定義固定的後續程序。

#### 4.7 重型迴圈（Review）

見 spec/12-review.md 完整程序；`orchestrate` 這一側的差異在於：`maxRounds` 固定為 5（Q29）、
派工對象是三個平行審查小組＋`review-triage`（而非單一審查者）、`qualityLoops` key 固定為
`"review"`（不像 Dev 逐票證各自一個 key，因為 Review 是對整個工作單位的一次性審查），**以及
§4.5「退回路由」規則不適用於 Review**（S1 裁決：Review 不做自動退回、不做自動 ESC，全部
finding 一律在 Review 承諾點呈給使用者裁決，「一輪」的定義是「使用者核准修正 → 修正 → 重新
完整跑一次三小組＋triage」，見 spec/12-review.md「程序步驟」步驟 7–9）。5 輪上限與超限即 ESC
（`rootCause: "round-limit-exceeded"`）這條規則本身不受 S1 影響，仍適用（Q29）。

### 5. Dev phase 的 SendMessage 續談（research 07 Test A）

依 spec/04-internal-skills.md `using-worktree` 一節（僅 `orchestrate` 載入）：

1. `dev-reviewer` 判定某票證 `verdict: "reject"` 且 `rootCause: "implementation-issue"`。
2. `orchestrate`（**必須是主 session 本身**，不可委派任何中介子代理）用 `SendMessage` 工具，
   `to` 帶該次 `dev-worker` 呼叫回傳的 `agentId`，附上 `dev-reviewer` 的 `findings` 作為續談
   內容。
3. **不可**改用 Agent tool 重新呼叫 `agent-flow:dev-worker`（即使 `subagent_type` 相同）——會
   拿到全新 worktree，先前實作與 worktree 內容不會保留（research 06 實驗四）。
4. `dev-worker` 續談完成後，完成通知會送回主 session（因為就是主 session 發起續談，通知路由
   本來就對得上，research 07 Test A：「完成通知只回主 session」對 `orchestrate` 自己發起續談
   的情境沒有負面影響）。
5. `orchestrate` 收到續談結果後，重新派 `dev-reviewer` 審查（這次是**重新派工**，不是續談——
   審查者不需要保留 worktree 狀態，每次審查都是對目前 worktree 現狀的獨立判斷）。
6. `rounds` 遞增，重複 §4.3 的輪次管理邏輯，上限 3 輪。

**本節的續談機制不適用於 Review phase**（S1 裁決，修正先前規格本文在此處與 spec/12-review.md
之間互相引用卻都沒有實際定義「Dev worktree 已因合併而移除後如何續談」的問題——該問題已因 S1
不再需要回答而消失）：Review 發現的 finding 沒有一個「原本正在做這件事」的 `dev-worker` 可以
續談（Review 在全部票證合併後才發生），因此 Review phase 的修正一律用**全新**（非續談）的
`dev-worker` 從單位分支 tip 派工，機制定義在 spec/12-review.md「純實作問題的修正機制」一節，
不在本節重複。

### 6. 與 `state.json` 的互動：事件 → 更新欄位對照表

| 事件 | 更新的 `state.json` 欄位 |
|---|---|
| 建立新工作單位 | 整份初始化（§2.3 步驟 3） |
| 某 phase 開始執行（第一次派工作者子代理） | `phases.<phase>.status = "in_progress"`、`currentPhase = <phase>` |
| 某 phase 品質迴圈通過 | `phases.<phase>.status = "done"`、`phases.<phase>.artifact = <路徑>`、`qualityLoops.<key>.status = "passed"` |
| Prototype phase 因無未解決技術疑問而略過 | `phases.prototype = {"status": "skipped", "reason": "no open technical question"}` |
| 承諾點使用者核准 | `gates.<phase> = {"approvedAt": <now>, "approvedBy": "user"}` |
| 每次審查迴圈完成一輪（不論通過或退回） | `qualityLoops.<key>.rounds` 遞增、`qualityLoops.<key>.status` 依 §4.3/4.4 判定值更新 |
| 讀到票證 frontmatter 異動 | `tickets.<id> = {"status": ..., "dependsOn": [...], "requirementRefs": [...]}`（鏡像同步，Q32） |
| ESC 上報發生 | `escalations` push 新元素、對應 `qualityLoops.<key>.status = "escalated"` |
| 使用者裁決 ESC | 對應 `escalations[].resolvedAt` 填入時間 |
| 每次寫入 | `updatedAt` 更新為當下時間 |

### 7. 單獨呼叫某個 phase skill（不經 `orchestrate`，Q2）

`orchestrate` 完全不參與這種情境——使用者直接呼叫 `/agent-flow:<phase>` 時，該 phase skill 自己
承擔：(a) 判斷前置條件是否滿足；(b) 驅動自己的品質迴圈；(c) 若是承諾點 phase，自己呈現核准請求
並自己寫入 `state.json.gates.<phase>`（此時該 phase skill 暫代 `orchestrate` 唯一寫入者的角色，
因為當下沒有 `orchestrate` 在運作）；(d) 完成後**不**自動接續下一個 phase（因為使用者只呼叫了
這一個 phase，接續邏輯屬於 `orchestrate`，不屬於任何單一 phase skill，Q2）。各 phase skill 的
標準化「單獨使用時的行為」細節見 spec/06–13 各檔對應章節。

---

## 待對齊

無。本檔內容全部可追溯至 Q2、Q3、Q11、Q12、Q15、Q20、Q21、Q23、Q28、Q29、Q32、Q34、DESIGN §2、
§3、§4、§5、§6、§7、§9，或 research 04、05、06、07 的記載與實測，以及 spec/02–04 已定案的規格。
§2.3「slug 推導規則」、§3.1「使用者主動修改已核准產物是否計入 escalations」屬 PROMPT 第 5 步
「規格沒寫的細節選最簡單做法」授權範圍內的實作細節，不影響其餘規格邏輯，故未列為待對齊。
