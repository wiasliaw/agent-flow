# 先行案例研究：TDD 工作流程與多 Agent 協作

## 研究目的

agent-flow 是一個八 phase 的 SDD+TDD（Spec-Driven Development + Test-Driven Development）Claude Code plugin，關鍵設計問題包括：測試先於實作（在 Ticket 階段隨票證產出）、每個 phase 結束由獨立於作者的角色跑品質檢查迴圈、Dev 階段用 subagent 或 worktree 平行執行、Wrap 階段全自動合併清理。本報告調查三類先行案例——BMAD-METHOD、Superpowers、Anthropic 的多智能體研究系統——如何在實際的 agent 工作流程中落實這些設計，並簡短補充 claude-flow 作為第四個案例。

**方法說明：** BMAD-METHOD 與 Superpowers 兩案例透過 `git clone` 官方 repo 到本機並直接讀取原始檔（SKILL.md、workflow 定義、文件）完成；Anthropic 案例透過官方工程部落格網頁擷取；claude-flow 僅透過網路搜尋的第三方報導取得，未直接讀取原始碼，標記如下。引用皆精確到檔案路徑，並附上讀取當下的 commit hash 以避免連結隨後續更新失效。

---

## 1. BMAD-METHOD

**版本鎖定：** `bmad-code-org/BMAD-METHOD`，commit `05bfbd46d00766ec88eb9b42e76be2c575d64d7b`（2026-09-04 擷取）。以下路徑皆可用
`https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/<path>` 展開。

### 1.0 架構概況：兩套並存的模型

BMAD-METHOD 目前的原始碼中同時存在兩套架構，網路上的第三方文章（如 Augment Code、Medium）多描述的是較早期、以人格化 agent 為中心的模型；但目前官方 repo 的「官方實作方法」（[docs/build/build-a-change.md](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/docs/build/build-a-change.md)）已改為以 `bmad-build` 為核心的「spine」模型，舊的 story 檔案工作流（`bmad-create-story`、`bmad-dev-story`）被標記為 `lifecycle: shim`、`Deprecated`，僅保留向後相容（[src/bmm-skills/v6-shims/bmad-dev-story/SKILL.md:3-4](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/v6-shims/bmad-dev-story/SKILL.md)）。

- **人格化 agent 模型（仍存在，`src/bmm-skills/agents/`）：** analyst、PM、architect、ux-designer、dev（Amelia）等具名角色，每個角色是一個獨立 skill，啟動時「adopt persona」並停留在該人格直到使用者解除（[src/bmm-skills/agents/bmad-agent-dev/SKILL.md:37-39](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/agents/bmad-agent-dev/SKILL.md)）。角色間透過共享檔案（PRD → epics → story）交接。
- **spine 模型（目前官方主流，`bmad-build` / `bmad-build-auto`）：** 不再是「一個角色扮演一個 agent」，而是「一個 workflow 依序驅動 clarify → plan → implement → review 四個 step 檔案」，並在 review 階段內部 fan-out 多個匿名審查 subagent。本報告以下各節同時涵蓋兩者，但以目前主流的 spine 模型（`bmad-build-auto`）為重點,因其明確定義了測試先行、審查迴圈輪數、halt 條件等機制。

### 1.1 測試先於實作的強制機制

**舊版 story 工作流（v6-shim，仍可作為設計意圖佐證）：** `bmad-dev-story` 的 Step 5 明文要求 red-green-refactor：

> "RED PHASE: Write FAILING tests first... Confirm tests fail before implementation... GREEN PHASE: Implement MINIMAL code to make tests pass..."
（[src/bmm-skills/v6-shims/bmad-dev-story/SKILL.md:316-345](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/v6-shims/bmad-dev-story/SKILL.md)）

防呆機制：Step 8 明文禁止「NEVER mark a task complete unless ALL conditions are met - NO LYING OR CHEATING」，要求「Verify ALL tests for this task/subtask ACTUALLY EXIST and PASS 100%」；並設有 3 次連續實作失敗即 HALT 的斷路器（"if 3 consecutive implementation failures occur"）（[同檔案:337-338, 364-371](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/v6-shims/bmad-dev-story/SKILL.md)）。配套的 checklist.md 把「Unit Tests」「Integration Tests」「Regression Prevention」列為 Definition of Done 的硬性條件，通不過就不能把 story 狀態改成 `review`（[checklist.md:42-46](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/v6-shims/bmad-dev-story/checklist.md)）。

**目前官方 spine 模型（`bmad-build-auto`）：** 不強制逐行 red-green，但改用「Matrix Test Audit」機制在 Verify 階段稽核——spec 若含 I/O & Edge-Case Matrix，每一列都必須有對應且**實際跑過並通過**的測試；「A covering test that exists but did not run — unregistered, filtered out, skipped, or disabled — counts as missing」，稽核失敗會直接 HALT（blocking condition `matrix test audit failed`）（[step-03-implement.md:42-44](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-build-auto/step-03-implement.md)）。這是一種「不規定寫測試的順序，但用矩陣稽核堵住漏測」的防呆策略，與 Superpowers 的「必須先看到測試失敗」是不同哲學。

### 1.2 作者與審查者分離

- **獨立於作者的角色：** `bmad-dev-story` 明文建議「Run `code-review` using a **different** LLM than the one that implemented this story」（[同檔案:496](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/v6-shims/bmad-dev-story/SKILL.md)）。
- **多層並行審查（`bmad-code-review` / `bmad-build-auto` step-04）：** 出廠內建四層獨立審查 lens——`blind-hunter`、`edge-case-hunter`、`verification-gap`、`acceptance-auditor`——全部以**同步、平行**方式一次性 dispatch（"launch every active layer before handling any layer's result... never backgrounded or detached"），每層各自產出 finding，互不看彼此結果（[step-02-review.md:23](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-code-review/steps/step-02-review.md)、[review-a-change.md:59-77](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/docs/build/review-a-change.md)）。
- **Triage 是獨立的第三步（非審查者本人做）：** 主流程對每個 finding 重新「verify the claim」——親自去讀被指出的程式碼，判斷壞結果是否真實發生，明文「Disregard any severity a reviewing subagent assigned — they lack the context to grade」，即審查者給的嚴重度不算數，由 triage 者重新裁定為 `high/medium/low/false/maybe-false`（[step-03-triage.md:19-27](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-code-review/steps/step-03-triage.md)）。
- **退回機制與輪數上限：** `bmad-build-auto` 的分類把 finding 路由到 `intent_gap`（意圖不明，HALT 讓人補完）、`bad_spec`（規格本身有問題，**回頭修 spec 再重新從 spec 重新生成程式碼**，而非在 diff 上打補丁——"read the ## Spec Change Log... then re-derive the code"）、`patch`（可直接自動修）、`defer`（非本次改動範圍）。每次 `bad_spec` 迴圈會遞增 `review_loop_iteration`，超過 **5 輪**即 HALT，blocking condition 為 `review repair loop exceeded 5 iterations (non-convergence)`（[step-04-review.md:70-72](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-build-auto/step-04-review.md)）。值得注意的設計理念：「如果程式碼錯是因為計畫弱，或計畫錯是因為目標錯，就回到那一層重新生成，而不是只在 diff 上打補丁」（[build-a-change.md:100-104](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/docs/build/build-a-change.md)）。

### 1.3 平行執行的切分與隔離

- **審查層平行：** 四個審查 lens 各自是獨立 subagent，僅透過檔案路徑（`{diff_file}`、`{claims_file}`）傳遞內容，"a launch prompt never carries diff text"，確保每個 subagent 的 context 互不污染（[step-04-review.md:23-25](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-build-auto/step-04-review.md)）。
- **不支援 subagent 時的降級：** 若平台不支援 subagent，四層 lens 改為循序執行，或退回到 main session（文件明言「far worse for review quality」），或退回讓使用者自己開別的 session/LLM 貼結果回來（[step-02-review.md:24](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-code-review/steps/step-02-review.md)）。
- **story/epic 層級的平行：** BMAD 本身不提供 worktree 隔離機制；`bmad-build-auto` 定位為「one session-sized unit」的無人職工，多個 story 平行執行需要「an orchestrator... must start one Build Auto worker per story」，隔離與衝突處理完全交給外部 orchestrator（如 `bmad-loop`），BMAD 本身**未記載** worktree 或檔案鎖機制（[autonomous-development-loops.md:29-35, 125-131](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/docs/build/autonomous-development-loops.md)）。`bmad-loop` 本身是**線性排程器**（"a linear scheduler: it does not infer a dependency graph"），並非真正的平行執行引擎；跨 epic 平行需要「a higher coordination layer」，BMAD 未提供（[同檔案:106-131](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/docs/build/autonomous-development-loops.md)）。

### 1.4 收尾自動化程度

- `bmad-build-auto` 完成後**會自動 commit 但不 push**：「Commit any reviewed-diff files... Do not push」，並確認 working copy 乾淨才能 HALT `done`（[step-04-review.md:111-116](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/src/bmm-skills/ship/bmad-build-auto/step-04-review.md)）。
- Epic 層級的收尾（`bmad-retrospective`）**明確定位為只提案、不動手**：「The skill proposes; you decide what runs. Nothing touches your code or your specs automatically」（[finish-an-epic.md:82-83](https://github.com/bmad-code-org/BMAD-METHOD/blob/05bfbd46d00766ec88eb9b42e76be2c575d64d7b/docs/build/finish-an-epic.md)）。它產出 verdict（`accepted` / `accepted-with-open-items` / `rejected`）與 action item 清單，但合併、清理分支等操作不在其職責內。
- 整體而言，BMAD 在「單一 story/unit」層級把 commit 自動化了，但**合併回主幹、分支清理、跨 story 整合**這些 Wrap 等級的動作，BMAD 官方文件中**未記載**由系統自動執行——設計上刻意把這類決定留給使用者或外部 orchestrator。

### 1.5 對 agent-flow 的啟示

**值得借鑑：**
1. **Triage 與審查分離、且不信任審查者自報的嚴重度**——四層審查各自平行找 finding，但由獨立的 triage 步驟重新驗證每一條 claim 並裁定嚴重度，這比「審查者說了算」更抗噪音，也避免多層審查互相矛盾時無所適從。agent-flow 的 Review phase 品質迴圈可借鑑「finding 平行蒐集 → 統一驗證裁定 → 分流（patch/defer/decision-needed）」三段式設計。
2. **迴圈輪數上限 + 依失敗根因分流的退回機制**——5 輪上限、且區分「這是程式碼問題（patch）」vs.「這是規格問題（bad_spec，需回頭改 spec 重新生成）」vs.「這是意圖不明（intent_gap，需要人）」，避免無止盡地在錯誤的圖層上打補丁。這與「Ticket 階段測試先行」的精神相通：若審查一直在同一類問題上迴圈，很可能是上游 phase（Spec/Ticket）的產出不夠精確，該退回上游而非死磕 Dev 產出。
3. **Matrix Test Audit 的「測試有跑且通過」稽核**，比單純「要求先寫測試」更能防止 agent 用「寫了測試但沒真的執行」矇混過關——這對 agent-flow 在 Ticket 階段產出測試、Dev 階段實作的設計特別有參考價值：可以在 Dev→Review 交接時稽核「Ticket 產出的每條驗收標準是否都對應到實際跑過的測試」。

**應避免：**
1. **BMAD 舊版 story 工作流的「強制 red-green-refactor 但無硬性防呆（如刪除先寫的程式碼）」**——相較 Superpowers 明文「Write code before the test? Delete it. Start over」，BMAD 的用語是「HALT and request guidance」，防呆力道較弱，容易被 agent 用話術繞過。agent-flow 若採 BMAD 式測試先行，應補強類似 Superpowers 的「不可協商」語氣與具體反例清單。
2. **收尾自動化程度不足、且平行執行隔離機制未定義**——這正是 agent-flow Dev/Wrap 兩個 phase 要解決的核心問題，BMAD 明確把這兩塊留白給外部系統，代表這是一個需要 agent-flow 自己設計、而非能直接照搬 BMAD 既有方案的部分。

---

## 2. Superpowers

**版本鎖定：** `obra/superpowers`，commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`（2026-08-12 擷取）。以下路徑皆可用
`https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/<path>` 展開。

### 2.0 組織方式

Superpowers 是純 markdown 的 skill 資料夾（14 個 `skills/<name>/SKILL.md`），無中央 orchestrator 程式碼；靠 `using-superpowers/SKILL.md` 這個「meta-skill」在每次對話開始時強制 agent 檢查是否有相關 skill 可用（"IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT."），並定義 skill 優先序：流程類 skill（brainstorming、systematic-debugging）先於實作類 skill（[skills/using-superpowers/SKILL.md](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/using-superpowers/SKILL.md)）。核心流程鏈是 brainstorming → writing-plans → (subagent-driven-development | executing-plans) → requesting-code-review → finishing-a-development-branch，每個環節都是可獨立呼叫的 skill 而非單一巨大 workflow。

### 2.1 測試先於實作的強制機制

`test-driven-development/SKILL.md` 是所有案例中對 TDD 描述最嚴格的一份：

- **鐵律：** "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"；違反時的處置是「Write code before the test? Delete it. Start over.」並明文禁止「保留當參考」「邊寫測試邊改」（[skills/test-driven-development/SKILL.md:31-45](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/test-driven-development/SKILL.md)）。
- **RED 階段必須「親眼看到失敗」**："**MANDATORY. Never skip.**"，並要求確認失敗原因正確（因為功能未實作，而非 typo）（[同檔案:113-129](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/test-driven-development/SKILL.md)）。
- **防呆表（"Common Rationalizations"）：** 逐條反駁 agent 常見的偷跳過測試話術，例如「太簡單不用測」「之後補測試也一樣」「已經手動測過了」「刪掉已寫的 X 小時代碼很浪費」等十種藉口，每條都給出技術性反駁（[同檔案:212-244](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/test-driven-development/SKILL.md)）。這是本報告調查的三個案例中，對「agent 偷跳過測試」防範最系統化的一份。
- **配套的 `verification-before-completion/SKILL.md`** 把「完成宣告前必須有新鮮驗證證據」單獨拉出成一個 skill：「NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE」，並列出常見的「應該可以過」「之前測過」等紅旗字眼（[skills/verification-before-completion/SKILL.md:16-59](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/verification-before-completion/SKILL.md)）。

### 2.2 作者與審查者分離

- **`subagent-driven-development`** 是核心執行引擎：每個 plan 中的 task 都 dispatch 給**全新的** implementer subagent（"never inherit your session's context or history"），完成後**強制**由另一個 task reviewer subagent 審查 spec 相容性與程式碼品質，二者都必須通過才算完成（"Never skip the task review, and never accept a report missing either verdict"）（[skills/subagent-driven-development/SKILL.md:10-12, 308-314](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。
- **明確禁止 implementer 自己生 reviewer**："The dispatch carries the no-subagents contract... the implementer never dispatches subagents — not helpers, and never a reviewer. Review arrives from you, after the report."，理由是實測發現這樣會造成重複審查席位（[同檔案:272-277, 501](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。
- **退回輪數與升級機制：** 每個 task 的 fix loop 上限 **5 輪**；第 1-3 輪重新啟用原 implementer（帶著它自己的 context），第 4-5 輪則換一個**更強模型**的全新 implementer（"A prior implementer attempted this task [N] times; you own it now"）（[同檔案:373-386](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。第 5 輪後仍有殘留 finding，由**控制者（coordinator）本人**裁定（parked / ruling），並在 ledger 記錄「Ruling: 決定了什麼 — 為什麼 — 錯了要付出什麼代價」，確保沒有「靜默丟棄」的裁決（[同檔案:411-429](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。
- **全分支最終審查（一次性）：** 所有 task 做完後，再對整個分支的 diff 做一次「broad review」，用最強模型執行；若有 finding，只 dispatch **一個**修復 subagent 一次處理所有 finding（而非每個 finding 各開一個），理由是「per-finding fixers each rebuild context and re-run suites」成本過高（[同檔案:445-461](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。
- **`receiving-code-review/SKILL.md`** 補上了「作者收到審查意見後該怎麼回應」的規範：禁止表演性附和（「You're absolutely right!」），要求技術驗證後才實作或提出反駁，且反駁需附技術理由（[skills/receiving-code-review/SKILL.md:27-38, 113-129](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/receiving-code-review/SKILL.md)）。

### 2.3 平行執行的切分與隔離

- **Context 隔離：** 所有 dispatch 都強調「Everything you paste into a dispatch prompt... stays resident in your context」，因此大宗內容一律透過檔案傳遞（"Hand artifacts over as files"），而非貼進 prompt（[skills/subagent-driven-development/SKILL.md:231-233](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。
- **worktree 隔離（`using-git-worktrees/SKILL.md`）：** 明確的優先序——先偵測是否已在隔離工作區（比對 `git rev-parse --git-dir` 與 `--git-common-dir`，並排除 submodule 的偽陽性）→ 優先用平台原生 worktree 工具 → 才 fallback 到手動 `git worktree add`；並要求驗證 worktree 目錄已被 `.gitignore` 排除，避免整個 worktree 被誤 commit 進主 repo（[skills/using-git-worktrees/SKILL.md:16-100](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/using-git-worktrees/SKILL.md)）。
- **平行 task 的切分原則（`dispatching-parallel-agents`）：** 用「是否共享 state」判準是否可平行——同一份檔案、同一個資源會互相干擾的 task 必須序列化；獨立子系統的 task 才平行 dispatch，且「Multiple dispatch calls in one response = parallel execution. One per response = sequential.」（[skills/dispatching-parallel-agents/SKILL.md:36-77](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/dispatching-parallel-agents/SKILL.md)）。但 `subagent-driven-development` 明文規定**實作 subagent 之間不平行**（"Never dispatch multiple implementation subagents in parallel (conflicts)"）——即衝突風險判斷是 Superpowers 決定是否平行的關鍵準則，implementer 級別預設序列，只有審查/獨立子任務才平行（[skills/subagent-driven-development/SKILL.md:282](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/subagent-driven-development/SKILL.md)）。
- **衝突怎麼合：** `dispatching-parallel-agents` 場景下由 dispatch 者事後「Review each summary → Check for conflicts (Did agents edit same code?) → Run full test suite → Integrate」（[skills/dispatching-parallel-agents/SKILL.md:79-85, 161-167](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/dispatching-parallel-agents/SKILL.md)），本質上是「平行產生、序列整合」而非自動合併，衝突偵測仍依賴人／協調者事後檢查。

### 2.4 收尾自動化程度

`finishing-a-development-branch/SKILL.md` 定義了完整流程：**先跑全套測試**（測試失敗直接停在這一步，不進選單）→ 偵測環境（一般 repo / worktree / detached HEAD）→ 呈現固定選單（合併到主幹本地 / push 建 PR / 保留原樣），**等待人類選擇，不代為決定**（[skills/finishing-a-development-branch/SKILL.md:14-65](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/finishing-a-development-branch/SKILL.md)）。合併後會**在合併結果上重跑一次測試**，失敗就停下不砍任何東西（"nothing has been pushed, so the merge is local and recoverable"）（[同檔案:98-104](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/finishing-a-development-branch/SKILL.md)）。worktree 清理有明確的所有權判斷（只清理 `.worktrees/`/`worktrees/` 底下、自己建立的）與拒絕清理時的安全處置（列出未提交檔案讓人決定，而非強制 `--force`）（[同檔案:159-222](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/finishing-a-development-branch/SKILL.md)）。**丟棄工作**這個不可逆動作要求打字輸入精確的 `discard` 一詞才執行（[同檔案:132-146](https://github.com/obra/superpowers/blob/b36e0829c6d0140e93cfef2ca599b1b07d4a7797/skills/finishing-a-development-branch/SKILL.md)）。

整體而言，Superpowers 的收尾是「自動化每一個檢查與清理步驟本身，但整合方式（合併/PR/保留）的**決策**永遠留給人」——與 agent-flow 設想的「Wrap 階段全自動合併清理」明顯不同，這是需要注意的落差。

### 2.5 對 agent-flow 的啟示

**值得借鑑：**
1. **TDD 的「刪除重來」鐵律 + 系統化的偷跳測試話術反駁表**，是三個案例中最強的防呆設計，直接可用於 agent-flow 的 Ticket→Dev 交接規範：測試在 Ticket 階段先寫好，Dev 階段若沒看到測試先失敗就寫實作，應視為違規並要求重來，而非僅提醒。
2. **模型分級 + fix loop 輪數升級策略**（前幾輪用原 subagent 續作、後幾輪換更強模型的新 subagent）是一個成本與品質兼顧的具體機制，可直接映射到 agent-flow 的 Dev↔Review 品質迴圈：初次退回用同一個 Dev subagent 修，多次退回後才升級模型或换人。
3. **「決策留痕（ledger + Ruling 記錄）」的設計**——所有平行/自動化過程中做出的裁決都要留下「決定了什麼、為什麼、錯了代價是什麼」，且明確禁止「靜默丟棄」finding，這對 agent-flow 想要的「全自動 Wrap」尤其重要：如果要做到全自動合併清理，必須有這種可追溯的裁決記錄，讓人事後能稽核 agent 自己做的判斷，而不是黑箱全自動。

**應避免：**
1. **implementer 之間不允許平行**（避免衝突）這個保守選擇，代表 Superpowers 事實上沒有解決「多個 Dev subagent 平行寫程式碼」的合併問題，只解決了「平行做互不相關的獨立任務」。若 agent-flow 想要 Dev 階段真正平行（多票證同時開發），需要自行設計比 Superpowers 更進一步的衝突偵測/合併機制，不能直接照搬。
2. **Wrap 階段仍要人選擇整合方式**，與 agent-flow「全自動合併清理」的目標有落差——照搬 Superpowers 的收尾設計並不會達到全自動，需要額外設計「什麼條件下可以免問直接合併」的判準（例如：測試全過、審查無殘留 finding、變更範圍在允許自動合併的白名單內）。

---

## 3. Anthropic 多智能體研究系統（Multi-Agent Research System）

**來源：** Anthropic 官方工程部落格 [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)（發布於 2025-06-13）。此案例是「研究型」fan-out/synthesis 系統，非程式碼開發，但其平行切分、context 隔離、品質評估機制對 agent-flow 的 Dev 階段平行執行設計有直接參考價值。

### 3.1 測試先於實作 / 驗證機制（此案例的對應概念）

此系統不寫程式碼，因此無傳統 TDD，但有對應的「先驗證後上線」精神：

- **提早用小樣本評估：** 「Start evaluating immediately with small samples」，從約 20 個代表性查詢開始，早期改動往往帶來 30%–80% 的效果差異，小樣本就能偵測到。
- **工具測試 agent：** 專門建立一個 agent，去嘗試使用「有缺陷的 MCP 工具」，反覆試錯後改寫工具描述以避免失敗；「By testing the tool dozens of times, this agent found key nuances and bugs」，結果讓後續 agent 完成任務時間減少 40%。這概念上等同於「用一個 agent 去對另一個 agent 的介面做驗收測試」，可類比 agent-flow 中 Ticket 階段先寫好驗收測試、由另一個 agent 拿測試去驗證 Dev 產出是否符合介面契約。
- **生產環境驗證：** 用完整生產 trace 診斷失敗原因，並用「rainbow deployments」（漸進式流量切換）避免中斷正在執行中的 agent，這是與程式碼部署不同但精神類似的「不要在半途中破壞正在跑的東西」的漸進驗證策略。

### 3.2 作者與審查者分離 / 品質檢查機制

- **LLM-as-judge 評估：** 用單一 LLM 呼叫評估最終輸出，檢查五個維度：「factual accuracy (do claims match sources?), citation accuracy (do the cited sources match the claims?), completeness (are all requested aspects covered?), source quality (did it use primary sources over lower-quality secondary sources?), and tool efficiency」。這是**產出完成後**的品質閘門，而非過程中的逐步審查（與 BMAD/Superpowers 的「每個 task 審一次」不同，屬於「整批完成後一次性評分」模式）。
- **人工評估補自動化評估的盲點：** 文中承認「People testing agents find edge cases that evals miss」，並舉實例：早期 agent 系統性偏好 SEO 優化過的內容農場勝過學術 PDF 等高權威但排名較低的來源，這種偏誤是人工測試發現、再回頭修 prompt 修正的——說明**純自動化評分無法取代人工抽查**。
- **無傳統「審查者退回作者」迴圈：** 此系統的架構是主代理（lead agent）→ 子代理（subagent）→ CitationAgent 的**單向 pipeline**，子代理完成後回報給主代理，主代理決定「是否需要更多研究」（可能生成新的子代理或調整策略），但沒有 BMAD/Superpowers 那種「reviewer 打回 implementer 重做同一份工作，上限幾輪」的顯式退回機制——**未記載**明確的迭代輪數上限。

### 3.3 平行執行的切分與隔離

這是本案例對 agent-flow 最直接有參考價值的部分：

- **兩層平行：** 主代理平行生成 **3–5 個子代理**，每個子代理內部再平行呼叫 **3 個以上工具**（"the lead agent spins up 3-5 subagents in parallel rather than serially" + "the subagents use 3+ tools in parallel"），這兩層平行合計讓複雜查詢的研究時間縮短最多 90%。
- **依複雜度分級的資源配置規則（寫死在 prompt 裡）：**
  - 簡單事實查找：1 個 agent，3–10 次工具呼叫
  - 直接比較：2–4 個子代理，各 10–15 次呼叫
  - 複雜研究：10+ 個子代理，職責明確劃分
- **Context 隔離的具體實作：** 子代理各自擁有獨立 context window；長對話中即使超過 20 萬 token 上限被截斷，也能透過「把研究計畫存進 Memory」讓新的子代理接續工作而不遺失進度（"agents can spawn fresh subagents with clean contexts while maintaining continuity through careful handoffs"）。
- **輸出彙整走檔案系統，不走對話歷史：** 「Subagent output to a filesystem to minimize the 'game of telephone.'」——子代理的完整輸出直接寫入外部檔案系統，只把輕量引用傳回主代理，避免大型輸出反覆複製進 context 造成的 token 浪費與失真，這與 Superpowers「用檔案路徑而非貼文字傳遞內容」的原則完全一致，是兩個獨立案例都收斂到的共同解法。
- **提示工程是主要調校手段：** 早期版本出現「子代理生太多」「無止盡搜尋不存在的資料源」等失控行為，Anthropic 的解法幾乎全部是調整 prompt（而非改架構），甚至發現 Claude 4 本身就能診斷失敗模式並自己提出 prompt 改善建議。

### 3.4 收尾自動化程度

不適用於此案例——這是研究/搜尋系統而非程式碼開發系統，沒有「合併」「分支清理」的對應概念。最終輸出經 CitationAgent 處理引用後直接回傳使用者，**未記載**類似 Wrap phase 的收尾流程。

### 3.5 對 agent-flow 的啟示

**值得借鑑：**
1. **平行度應該分級、寫成明確規則，而非固定併發數**——依任務複雜度決定要開幾個平行單位（1 個 vs. 2–4 個 vs. 10+ 個），這對 agent-flow 的 Dev 階段平行執行設計很直接：不是所有票證都該平行拆到最細，應該有「這張票證的複雜度該配幾個平行 worker」的判準，避免簡單票證也生一堆 subagent 造成浪費（文中指出多 agent 系統 token 成本是單 agent 對話的 15 倍，效益需要用複雜度換取）。
2. **子代理輸出一律落地到檔案系統，主代理只讀取輕量引用**——這與 Superpowers 的檔案傳遞原則相互印證，是兩個獨立系統收斂出的共同解法，agent-flow 在設計 Dev subagent 或 worktree 平行執行的交接格式時，應以此為預設，避免大型 diff/log 直接塞進協調者 context。

**應避免：**
1. **此案例的高 token 成本（4–15 倍）**是效能與成本的明確 trade-off，agent-flow 若要引入 Anthropic 式的多層平行（lead → subagent → tool 平行），需要同步考慮成本上限與判準，不能無條件套用「平行永遠更好」。
2. **本案例沒有 BMAD/Superpowers 式的「审查退回、輪數上限」機制**，是三案例中審查迴圈設計最弱的一個（其品質把關偏向產出後的一次性評分，而非過程中的迭代修正）——agent-flow 若參考此案例的平行架構，品質迴圈仍應採 BMAD/Superpowers 式的顯式退回機制，不能只靠事後 LLM-as-judge 評分。

---

## 4. 補充案例：claude-flow（現稱 ruflo）

**重要限制：** 本節僅根據網路搜尋取得的第三方報導（部落格文章、GitHub wiki 摘要）整理，**未直接 clone 原始碼驗證**，因此細節可信度低於前三案例，僅供概念參考，不應作為設計依據引用。

根據第三方報導：claude-flow（作者 Reuven Cohen / "ruvnet"，2025 年 5 月首次發佈，repo 後因商標問題從 `ruvnet/claude-flow` 更名為 `ruvnet/ruflo`）是一套將單一 Claude Code 實例擴充為多達 64 個特化 agent 的協調層，主打兩個模式：

- **SPARC 方法論**（Specification, Pseudocode, Architecture, Refinement, Completion）：號稱是內建的 TDD 工作流，強制先寫測試再寫程式碼，並在每個迭代驗證。**未記載**其強制機制的具體實作細節（是否有類似 Superpowers 的「刪除重寫」防呆）。
- **Swarm 模式 vs. Hive-Mind 模式：** Swarm 模式下每個子任務各自生成獨立 agent 平行執行、各自持久化輸出；Hive-Mind 模式則讓所有 agent 共享同一個 SQLite 記憶庫（`.swarm/memory.db`），彼此能讀到對方的中間產出，設計上用於「緊密耦合的子任務」（例如跨檔案重構）。這與 BMAD/Superpowers/Anthropic 案例的「獨立 context、透過檔案交接」策略形成對比——claude-flow 的 Hive-Mind 模式選擇了「共享可變狀態」而非「隔離 + 顯式交接」，两种設計哲學的取捨（一致性風險 vs. 交接開銷）**未記載**在可靠來源中有具體的衝突解決機制描述。

**對 agent-flow 的啟示（低確信度，僅供參考）：** claude-flow 的「共享記憶庫」設計提出了一個與本報告其他三案例相反的思路——若 agent-flow 未來需要處理「多個 Dev subagent 之間必須即時感知彼此決策」的緊密耦合情境（例如同一票證拆成強相依的子任務），共享狀態庫可能是比純檔案交接更合適的機制；但因未驗證原始碼，此點僅列為值得進一步查證的方向，不建議在未直接讀取其實作前採信細節。

---

## 對照表

| 問題 | BMAD-METHOD | Superpowers | Anthropic 多智能體研究系統 | claude-flow（未驗證，僅供參考） |
|---|---|---|---|---|
| **測試先行的強制機制** | 舊版 story 流程明文 red-green-refactor + Definition of Done 硬性檢查；現行 spine 模型改用「Matrix Test Audit」稽核每條驗收標準都有跑過且通過的測試 | 鐵律「無失敗測試不准寫實作程式碼」，違反即刪除重寫；配十條偷跳測試話術的系統化反駁表 | 不適用傳統 TDD；以「小樣本提早評估」+「工具測試 agent 反覆試錯改介面描述」+「生產環境漸進驗證」達到類似「先驗證後上線」的效果 | 號稱 SPARC 方法論強制先寫測試（未記載具體防呆機制） |
| **失敗時如何防止 agent 偷跳過測試** | 3 次連續失敗即 HALT；Matrix Audit 把「測試存在但沒真的跑」視同缺測 | 「Delete means delete」不可協商；十條常見藉口逐一反駁 | 未記載明確的「偷跳過驗證」防呆機制（偏向事後 LLM-as-judge 抓漏） | 未記載 |
| **作者與審查者如何分離** | 建議換一個 LLM 做 code review；四層獨立審查 lens 平行找 finding，triage 步驟重新驗證並裁定嚴重度（不採信審查者自報的嚴重度） | 每個 task 強制 dispatch 全新 reviewer subagent，禁止 implementer 自己生 reviewer；全分支再做一次最終審查 | 主代理／子代理是分工關係，非審查關係；品質評估靠 LLM-as-judge 對最終產出一次性評分 + 人工抽查補盲點 | 未記載 |
| **審查迴圈輪數與退回機制** | 上限 5 輪；依根因分流：patch（直接修）／bad_spec（回頭改 spec 重新生成程式碼）／intent_gap（HALT 等人）／defer（非本次範圍） | 上限 5 輪；1-3 輪原 subagent 續修，4-5 輪換更強模型的新 subagent；上限後由協調者裁決並記錄 ledger | 未記載顯式的「審查打回重做、輪數上限」機制 | 未記載 |
| **平行執行的切分與隔離** | 四層審查 lens 平行（各自讀檔案路徑，不共享 context）；story/epic 層級平行需外部 orchestrator（`bmad-loop` 為線性排程器，非真正平行引擎） | 依「是否共享 state」判斷可否平行；implementer 之間刻意不平行（防衝突），僅獨立任務／審查平行；worktree 隔離有明確偵測與 fallback 順序 | 兩層平行（3–5 個子代理 × 各 3+ 工具），依任務複雜度分級（1 / 2–4 / 10+ 個代理）；子代理各自獨立 context window | Swarm 模式各自獨立 agent；Hive-Mind 模式共享 SQLite 記憶庫（與其他三案例的「隔離 context」策略相反） |
| **衝突怎麼合** | 未記載明確的自動合併機制 | 平行 task 完成後由協調者人工檢查是否編輯同一段程式碼、跑全套測試再整合 | 子代理輸出寫入檔案系統，主代理讀輕量引用彙整（compression 手段而非衝突合併） | 未記載 |
| **收尾自動化程度** | 單一 unit 完成後自動 commit（不 push）；epic 層級 retrospective 明確「只提案不動手」，合併清理不自動化 | 測試全過後才進選單；選單三選項（本地合併／push 建 PR／保留）**必須人類選**；合併後在結果上重跑測試；worktree 清理有所有權判斷 | 不適用（無程式碼合併概念） | 未記載 |

---

## 摘要（給發起者）

三個案例都不支援「全自動合併」——BMAD 只自動 commit 不 push、Superpowers 的收尾選單堅持要人類選、Anthropic 案例根本不涉及程式碼合併，這代表 agent-flow 想做到的「Wrap 階段全自動合併清理」在目前公開的先行案例中**沒有直接可抄的範本**，需要自行定義「什麼條件下可以免問直接合併」的判準（可能需要 Superpowers 式的裁決留痕機制來讓全自動變得可稽核）。

每個案例最重要的一個啟示：
- **BMAD-METHOD：** 審查 finding 要走「平行蒐集 → 獨立驗證裁定 → 依根因分流（程式碼問題/規格問題/意圖不明）」三段式，且退回時要分清楚是回 Dev 重做還是回上游 phase（Spec）重新生成，不能只在 diff 表面打補丁。
- **Superpowers：** TDD 的「刪除重寫」鐵律加系統化話術防呆表，是目前看到最強的「防止 agent 偷跳測試」設計，可直接移植到 Ticket→Dev 交接規範；fix loop 的「先原 agent 續修、多輪後換更強模型」升級策略兼顧成本與收斂速度。
- **Anthropic 多智能體研究系統：** 平行度要依任務複雜度分級（而非固定併發數），且子代理輸出一律落地檔案系統只傳輕量引用回協調者——這條與 Superpowers 各自獨立收斂出的原則，值得作為 agent-flow Dev 階段 subagent 交接格式的預設規範。

補充案例 claude-flow 因僅有第三方報導未驗證原始碼，僅標記其「共享記憶庫（Hive-Mind）」這個與其他三案例相反的設計方向，作為未來若需處理緊密耦合子任務時的查證線索，不建議在未讀原始碼前直接採信細節。
