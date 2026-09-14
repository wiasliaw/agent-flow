# 先行案例調查：規格驅動開發（Spec-Driven Development, SDD）工具

本文調查三個規格驅動開發（Spec-Driven Development, SDD）工具的先行案例——GitHub Spec Kit、OpenSpec、Kiro——目的是回答：先行者怎麼設計 phase、產物與流程控制，哪些設計值得 agent-flow（八 phase：Discuss／Explore／Prototype／Spec／Ticket／Dev／Review／Wrap）借鑑、哪些是坑。

調查方式：優先讀官方 repo／官方文件；為取得精確格式，已將 `github/spec-kit`（commit 為調查當下 main 分支）與 `Fission-AI/OpenSpec` clone 到本機直接讀原始檔。Kiro 為封閉 IDE 產品，僅能透過官方文件（kiro.dev）與第三方資料交叉查證，凡屬第三方來源已在文中明確標註。

---

## 一、GitHub Spec Kit

- 官方 repo：[github/spec-kit](https://github.com/github/spec-kit)
- 設計哲學文件：[spec-driven.md](https://github.com/github/spec-kit/blob/main/spec-driven.md)

### Phase 結構與順序

核心指令依序為：`/speckit.constitution` → `/speckit.specify` → `/speckit.plan` → `/speckit.tasks` → `/speckit.implement`，另有輔助指令 `/speckit.clarify`（澄清）、`/speckit.analyze`（跨產物一致性分析）、`/speckit.checklist`（品質檢核清單）、`/speckit.converge`（評估現有程式碼與規格的落差）、`/speckit.taskstoissues`（把任務轉成 GitHub Issues）。完整指令清單見 [templates/commands/](https://github.com/github/spec-kit/tree/main/templates/commands)（`analyze.md`、`checklist.md`、`clarify.md`、`constitution.md`、`converge.md`、`implement.md`、`plan.md`、`specify.md`、`tasks.md`、`taskstoissues.md`）。

可跳過／迭代：`constitution` 通常只跑一次（建立專案原則）；`clarify` 與 `analyze` 是選用步驟，官方建議「務必在 implement 前跑一次 analyze」但不強制；`plan`／`tasks` 可重複執行覆寫產物。各指令彼此獨立、可單獨重跑，不是一個不可中斷的單一流程。專案也提供 preset 機制（`presets/lean`、`presets/self-test`、`presets/scaffold`、`presets/constitution-sync`）可覆寫模板與指令，代表官方本身也認知到「單一固定流程」不適合所有專案，見 [presets/](https://github.com/github/spec-kit/tree/main/presets)。

值得注意的落差：哲學文件 [spec-driven.md](https://github.com/github/spec-kit/blob/main/spec-driven.md) 中描述一套固定的「九條憲法」（Article I–IX，含 Library-First、Test-First、Simplicity Gate、Anti-Abstraction Gate、Integration-First Gate 等），但目前 main 分支的實際模板 [templates/constitution-template.md](https://github.com/github/spec-kit/blob/main/templates/constitution-template.md) 已經完全改為空白佔位符（`[PRINCIPLE_1_NAME]`／`[PRINCIPLE_1_DESCRIPTION]` 等），由使用者自行定義原則，範例僅以 HTML 註解形式保留在模板中供參考。也就是說專案已從「內建九條硬性原則」演化為「使用者自訂原則、工具只負責當作 gate 執行」，這是设计上重要的演进方向。

### 每個 Phase 的產物格式與位置

- `constitution.md` → 解析後寫入 `.specify/memory/constitution.md`（模板：[constitution-template.md](https://github.com/github/spec-kit/blob/main/templates/constitution-template.md)）。
- `spec.md` → `specs/<NNN或timestamp>-<short-name>/spec.md`，含 User Scenarios（依 P1/P2/P3 優先權分的獨立可測試 user story）、Functional Requirements（`FR-001`…）、Success Criteria（`SC-001`…，須技術無關、可量測）、Key Entities、Assumptions。模板：[spec-template.md](https://github.com/github/spec-kit/blob/main/templates/spec-template.md)。
- `plan.md`／`research.md`／`data-model.md`／`quickstart.md`／`contracts/` → 同一 feature 目錄下，由 `/speckit.plan` 產生。模板：[plan-template.md](https://github.com/github/spec-kit/blob/main/templates/plan-template.md)，內含 **Constitution Check** 區塊（「GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.」）與 **Complexity Tracking** 表（僅在違反憲法時需要填寫理由）。
- `tasks.md` → 依 User Story 分組（Setup → Foundational → 各 User Story Phase → Polish），格式 `[ID] [P?] [Story] Description`，`[P]` 標記可平行執行、`[Story]` 標記對應哪個 user story。模板：[tasks-template.md](https://github.com/github/spec-kit/blob/main/templates/tasks-template.md)。
- 品質檢核清單 → `specs/<feature>/checklists/requirements.md`，由 `/speckit.specify` 建立、`/speckit.clarify` 重新驗證，見 [commands/specify.md](https://github.com/github/spec-kit/blob/main/templates/commands/specify.md) 第 144–234 行。

### 需求如何追溯到實作（Traceability）

多層機制：(1) spec 內 `FR-###`／`SC-###` 編號；(2) tasks.md 用 `[Story]`（US1/US2/US3）把任務綁回 user story；(3) `/speckit.analyze` 會建立「Requirements inventory」與「Task coverage mapping」，輸出 Coverage Summary Table（哪些 requirement 有對應 task、哪些 task 沒有對應 requirement），見 [commands/analyze.md](https://github.com/github/spec-kit/blob/main/templates/commands/analyze.md) 第 106–187 行。這是三個案例中「自動化覆蓋率檢查」做得最完整的一個。

### 品質檢查與人工確認點

- **Spec 品質檢核清單**：`/speckit.specify` 產生後立即自我驗證（Content Quality／Requirement Completeness／Feature Readiness 三類檢核項），最多重試 3 輪，見 [commands/specify.md](https://github.com/github/spec-kit/blob/main/templates/commands/specify.md) 第 144–234 行。
- **`/speckit.clarify`**：最多問 5 題澄清問題，每題都要用戶回答（或明確接受建議答案），見 [commands/clarify.md](https://github.com/github/spec-kit/blob/main/templates/commands/clarify.md) 第 129–180 行。
- **Constitution Check gate**：`plan.md` 產生前後各檢查一次是否違反憲法原則。
- **`/speckit.analyze`**：明確定義為「STRICTLY READ-ONLY」，只產出分級報告（CRITICAL/HIGH/MEDIUM/LOW），不自動修改檔案，修正需使用者另外核准，見 [commands/analyze.md](https://github.com/github/spec-kit/blob/main/templates/commands/analyze.md) 第 56–61 行。
- **`/speckit.implement` 執行前的 checklist gate**：若 `checklists/` 下有未勾選項目，會停下來明確詢問「Some checklists have unchecked items. Do you want to proceed with implementation anyway?」，見 [commands/implement.md](https://github.com/github/spec-kit/blob/main/templates/commands/implement.md) 第 56–88 行。

### 狀態外部化（多 Session 之間如何接續）

`/speckit.specify` 執行時把解析後的 feature 目錄路徑寫入 `.specify/feature.json`，讓後續指令（`plan`／`tasks`／`implement`）不必依賴 git branch 名稱推斷目前在做哪個 feature，見 [commands/specify.md](https://github.com/github/spec-kit/blob/main/templates/commands/specify.md) 第 99–106 行。擴充掛鉤（extension hooks）的啟用狀態記錄於 `.specify/extensions.yml`；checklist 的通過/未通過狀態記錄於 `checklists/*.md` 本身的 checkbox。整體而言狀態全部落地為版控中的檔案，沒有額外的資料庫或 session 記憶體。

### 對 agent-flow 的啟示

值得借鑑：
1. **澄清問題有上限（≤3～5 題）且優先排序（scope > 安全/隱私 > UX > 技術細節）**——避免 agent 在 Discuss phase 無限發問，適合直接套用到 agent-flow 的蘇格拉底提問設計。
2. **`analyze` 唯讀＋分級報告＋不自動改檔**的模式，很適合 agent-flow 的 Review phase：先產出結構化發現清單（含覆蓋率統計），修正動作由人或下一個明確步驟決定，而不是在審查當下就動手改。
3. **checklist-as-gate**（未勾選項目會擋下並詢問是否強制跳過）是一個輕量但有效的機制，可用在 Ticket→Dev 或 Dev→Review 之間的關卡。

應避免：
1. 第三方評論（如 [Putting Spec Kit Through Its Paces](https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html)）指出這套五步驟很容易被使用者當成不可回頭的線性瀑布流程執行，即使工具本身允許重跑各指令。agent-flow 若把八個 phase 做成強制線性、缺乏「小改動走輕量路徑」的選項，容易重蹈這個評價。
2. 哲學文件與目前模板已經出現落差（九條憲法 vs. 空白佔位符），顯示「寫死的最佳實踐」很難長期維持；agent-flow 的 Spec phase 若要有類似 constitution 的機制，宜從一開始就設計成使用者可定義、而非工具內建固定清單。

---

## 二、OpenSpec

- 官方 repo：[Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec)
- 核心概念文件：[docs/concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md)

OpenSpec 有一個特別之處：這個專案本身就用 OpenSpec 管理自己的開發（dogfooding），repo 內的 [openspec/changes/](https://github.com/Fission-AI/OpenSpec/tree/main/openspec/changes) 與 [openspec/changes/archive/](https://github.com/Fission-AI/OpenSpec/tree/main/openspec/changes/archive) 就是真實運作中的案例，可以直接看到幾十個已歸檔變更的實際格式。

### Phase 結構與順序

官方明確主張「fluid not rigid — no phase gates」（[concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) 第 7–14 行）。流程用**依賴圖（schema）**而非線性關卡表達：`proposal`（無依賴）→ `specs` 與 `design`（都只依賴 proposal，可平行產生）→ `tasks`（依賴 specs 與 design）。官方原文：「Dependencies are enablers, not gates. They show what's possible to create, not what you must create next.」（同文件第 456 行）。

對應的 slash command 流程（chat 端）為：`/opsx:explore`（選用，先想清楚再動手）→ `/opsx:propose`（一次產出 proposal＋specs delta＋design＋tasks）→ `/opsx:apply`（依 tasks 實作，過程中可回頭更新 proposal/design）→ `/opsx:verify`（選用，檢查實作是否符合 spec）→ `/opsx:archive`（合併並歸檔）。CLI 端另有 `openspec init`／`list`／`show`／`validate`／`view` 等指令，見 [docs/how-commands-work.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/how-commands-work.md) 第 18–22、124–137 行。

可跳過／迭代：`.openspec.yaml` 的 `skip_specs: true` 可讓某次變更完全不產生 spec delta；自訂 schema（`openspec schema fork`）可以定義完全不同的 artifact 順序（例如「research-first」跳過 specs/design 直接到 tasks），見 [concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) 第 482–499 行。這是三個案例中對「跳過」支援最明確、最結構化的一個。

### 每個 Phase 的產物格式與位置

單一變更（change）打包成一個資料夾 `openspec/changes/<change-name>/`：

```
openspec/changes/add-dark-mode/
├── proposal.md           # 意圖／範圍／技術取向（Intent / Scope / Approach）
├── design.md             # 技術方案與架構決策
├── tasks.md              # 實作清單（階層編號 1.1、1.2…）
├── .openspec.yaml        # 選用中繼資料：schema、created、skip_specs、retire_capabilities
└── specs/                # Delta specs（相對於主 spec 的變更）
    └── ui/spec.md
```

（[concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) 第 188–202 行）主 spec（真理來源）另外存於 `openspec/specs/<domain>/spec.md`，格式為 `## Requirement:`＋`#### Scenario:`（Given/When/Then），並用 RFC 2119 關鍵字（SHALL/MUST/SHOULD/MAY）標示強制程度（同文件第 76–134 行）。真實範例可見 [openspec/specs/openspec-conventions/](https://github.com/Fission-AI/OpenSpec/tree/main/openspec/specs/openspec-conventions)。

### 需求如何追溯到實作（Traceability）

核心機制是 **delta spec**：change 內的 `specs/<domain>/spec.md` 用 `## ADDED Requirements`／`## MODIFIED Requirements`／`## REMOVED Requirements` 三種區塊描述「相對於現況的變化」，而不是重寫整份 spec；歸檔時這些區塊會被結構化合併回主 spec（新增的附加、修改的覆蓋、移除的刪除，若 `retire_capabilities: true` 且移除了該能力最後一條需求，甚至會刪除整個 spec 檔案），見 [concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) 第 346–406、503–557 行。tasks.md 到 spec 的回鏈沒有強制的 ID 語法，是用「章節分組＋人工審查」建立對應關係，見 [docs/reviewing-changes.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/reviewing-changes.md) 第 75–87 行（審查者要自問「這個任務有沒有對應到某個需求？」）。相較 Spec Kit 的 `FR-###` 編號＋自動 coverage table，OpenSpec 的 traceability 更依賴人工審查而非自動比對。

### 品質檢查與人工確認點

官方明確只定義**兩個**人工審查時機（[docs/reviewing-changes.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/reviewing-changes.md) 第 7–20 行）：
1. `/opsx:propose` 之後、`/opsx:apply` 之前——讀 proposal／spec delta／tasks 三份文件，逐一確認「這是對的問題嗎？」「done 的定義對嗎？」「工作計畫合理嗎？」。
2. 實作完成後，`/opsx:verify`（選用）——從 Completeness／Correctness／Coherence 三個維度重讀 artifacts 與程式碼，回報 CRITICAL/WARNING/SUGGESTION，但**明確不阻擋歸檔**：「it does **not** block archiving — it surfaces the gaps and leaves the call to you」（同文件第 119 行）。

`openspec validate` 提供結構層級的檢查（proposal.md 格式、delta spec 語法等），機器可讀輸出定義在 [docs/agent-contract.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/agent-contract.md) 第 55–56 行（`validate --json` 回傳每個 item 的 issues 陣列與 pass/fail 統計）。

### 狀態外部化（多 Session 之間如何接續）

狀態即檔案系統本身：一個 change 資料夾的存在與其內容就是狀態，不需要額外資料庫。CLI 提供 `openspec status --json` 把每個 artifact 標記為 `done`/`ready`/`blocked`/`skipped`，並附上 `missingDeps`（缺哪些依賴才能解鎖）與 `nextSteps`，讓任何一個新的 agent session 都能立刻知道「現在做到哪、下一步做什麼」，見 [docs/agent-contract.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/agent-contract.md) 第 59 行。歸檔後的資料夾以日期前綴（`YYYY-MM-DD-<name>`）移入 `changes/archive/`，形成可追溯的歷史紀錄，見 [concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) 第 503–557 行，可在 repo 中看到大量真實案例，例如 [changes/archive/2025-08-13-add-archive-command/](https://github.com/Fission-AI/OpenSpec/tree/main/openspec/changes/archive/2025-08-13-add-archive-command)。

### 對 agent-flow 的啟示

值得借鑑：
1. **Delta spec（ADDED/MODIFIED/REMOVED）** 是三個案例中最適合處理「棕地（brownfield）反覆修 spec」情境的設計，agent-flow 的 Spec phase 若要支援多輪迭代或後續變更，這個語法直接可以借。
2. **Archive／歸檔即狀態合併**：完成後把 change 的 delta 合併回主 spec、資料夾整包移入帶日期的歸檔區，形成審計軌跡——這與 agent-flow 的 Wrap phase（自動收尾）目標高度一致，可直接借用「合併＋加日期前綴歸檔」這個具體動作。
3. **「兩個明確的人工確認點」而非每個產物都要人工點頭**：propose 後、verify 後，避免過多關卡造成審查疲勞（review fatigue），對 agent-flow 決定 Review phase 要卡在哪裡有參考價值。

應避免：
1. `verify` 是非阻斷式（non-blocking）的軟性把關——「surfaces gaps and leaves the call to you」。若 agent-flow 的 Review phase 期待有較強的確定性／TDD 硬性約束，照搬這種「僅提示不擋」的設計可能不夠嚴謹，需要額外加一個可切換的「嚴格模式」。
2. OpenSpec 目前的 CLI 已經相當複雜（見 [docs/agent-contract.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/agent-contract.md) 列出的十幾種 JSON schema、multi-repo store、schema fork 等機制），連官方文件都承認有「Known inconsistencies」（同文件第 133–144 行）。這提醒 agent-flow 在設計狀態外部化機制時要克制，避免為了通用性堆出過度工程化（overengineering）的介面。

---

## 三、Kiro（AWS）

- 官方文件首頁：[kiro.dev/docs/specs/](https://kiro.dev/docs/specs/)
- Feature Specs：[kiro.dev/docs/specs/feature-specs/](https://kiro.dev/docs/specs/feature-specs/)
- Hooks：[kiro.dev/docs/hooks/](https://kiro.dev/docs/hooks/)
- Steering：[kiro.dev/docs/steering/](https://kiro.dev/docs/steering/)

Kiro 是封閉原始碼的 IDE 產品，官方文件偏概念說明、較少列出精確檔案語法。以下標註「（第三方）」的內容來自非官方來源，已與官方文件交叉比對過方向是否一致，但精確語法本身未經 AWS 官方確認。

### Phase 結構與順序

三階段：Requirements → Design → Tasks，之後進入 Execution（執行）。兩種啟動方式：Requirements-First（由行為出發）與 Design-First（由架構/虛擬碼出發，反推可行的需求），見 [feature-specs](https://kiro.dev/docs/specs/feature-specs/)。

可跳過／迭代：標準 Feature Spec 在每個階段之間都有「approval gate」，需使用者明確核准才進入下一階段；官方提供 **Quick Spec** 作為快速模式，「runs all three phases automatically without approval gates between them」，兩者產出的檔案格式相同，差別只在於是否每步都要人工核准，見 [best-practices](https://kiro.dev/docs/specs/best-practices/)。文件建議 Quick Spec 用在「熟悉且信任 Kiro 輸出」的場景，標準流程用在「探索未知領域」或「需求/設計需要反覆迭代」的場景。官方文件未提及可以中途切換兩種模式（未記載）。

### 每個 Phase 的產物格式與位置

三份檔案 `requirements.md`／`design.md`／`tasks.md`。**requirements.md** 用 EARS（Easy Approach to Requirements Syntax）記法撰寫，格式為 `WHEN [事件/條件] THE SYSTEM SHALL [預期行為]`（[feature-specs](https://kiro.dev/docs/specs/feature-specs/)）；第三方逆向工程資料（見下方「傳聞資料」段落）顯示更完整的模板包含 `WHEN [event] THEN [system] SHALL [response]` 與 `IF [precondition] THEN [system] SHALL [response]` 兩種變體，並以「User Story ＋ 編號 Acceptance Criteria（1、2、3…）」的結構呈現。**design.md** 記錄技術架構、循序圖（sequence diagram）與實作考量。**tasks.md** 是可追蹤狀態的實作清單，官方文件說明 Kiro 會分析任務相依關係並「建立依賴圖，把獨立任務分成波次（wave）」並行執行，Wave 1 為零依賴任務、Wave 2 為 Wave 1 完成後才解鎖的任務，依此類推（搜尋結果彙整自 kiro.dev，惟未能取得對應頁面精確 URL，列為**未記載**具體出處頁面）。

目錄位置：**（第三方）** 依 [github/spec-kit Issue #1242](https://github.com/github/spec-kit/issues/1242)（提出「Kiro → spec-kit 遷移工具」的社群提案，文中描述其觀察到的 Kiro 專案結構）：

```
.kiro/
├── specs/<feature-name>/
│   ├── requirements.md
│   ├── design.md
│   └── tasks.md
├── steering/
│   ├── product.md
│   ├── structure.md
│   └── tech.md
├── hooks/
└── memory/
```

`.kiro/specs` 路徑本身在官方文件 [Using specs for complex work](https://kiro.dev/docs/guides/learn-by-playing/05-using-specs-for-complex-work/) 中有出現（「specifications are stored under `.kiro/specs`」），可視為官方確認；`steering/`、`hooks/`、`memory/` 的細部結構則來自上述第三方 Issue，未經官方頁面逐一核實。

### 需求如何追溯到實作（Traceability）

**（第三方，未經官方確認）** 依一份被回報為 Kiro 內部系統提示（system prompt）的公開 gist（[notdp/19822831b54190bd9c6b34f6b69fadeb](https://gist.github.com/notdp/19822831b54190bd9c6b34f6b69fadeb)，屬逆向工程／洩漏內容，非官方發布），tasks.md 的每個任務項下方會附上 `_Requirements: 1.1, 2.3_` 這樣的行內標註，直接回鏈到 requirements.md 中對應的編號 Acceptance Criteria。若此語法屬實，這是三個案例中**最明確、最細顆粒度**的需求↔任務回鏈機制（優於 Spec Kit 的 `[Story]` 標籤與 OpenSpec 純人工審查）。官方文件僅泛稱「each requirement maps to test cases and implementation tasks」（[feature-specs](https://kiro.dev/docs/specs/feature-specs/)），未展示精確語法，故此點的具體語法標記為第三方來源、無法在官方頁面中直接驗證。

### 品質檢查與人工確認點

標準 Feature Spec 流程在三個階段之間都要求人工核准。**（第三方，同一份逆向工程 gist）** 回報的確切核准問句為：Requirements 階段問「Do the requirements look good? If so, we can move on to the design.」；Design 階段問「Does the design look good? If so, we can move on to the implementation plan.」；Tasks 階段問「Do the tasks look good?」。官方文件則以較概括的方式描述同一機制：「if so, you approve and move to the next phase; if not, you provide feedback and Kiro revises」，並提及在進入 design 前可選擇執行 “Analyze Requirements” 找邏輯矛盾、模糊點與衝突（[repost.aws 文章](https://repost.aws/articles/AROjWKtr5RTjy6T2HbFJD_Mw/%F0%9F%91%BB-kiro-agentic-ai-ide-beyond-a-coding-assistant-full-stack-software-development-with-spec-driven-ai) 綜整官方行為描述，屬第三方文章但與官方文件方向一致）。Quick Spec 則明確跳過這些關卡。

### 狀態外部化（多 Session 之間如何接續）

官方文件未直接說明跨 session 的狀態機制（**未記載**），但強調 spec 檔案「designed to be version-controlled」，暗示狀態即版控中的 markdown 檔案本身，這點與 Spec Kit、OpenSpec 一致。**（第三方）** 依 Issue #1242 的描述，tasks.md 內每個任務帶有 `[TODO]`／`[IN_PROGRESS]`／`[DONE]` 狀態標記；另有 `.kiro/memory/` 目錄用於存放「historical decisions, context」，若屬實則是三案例中唯一明確為「跨 session 記憶」設計專門目錄的做法，但此細節缺乏官方文件佐證。Hooks（`.kiro/hooks/`）與 spec 流程相互獨立運作，可在 `PreToolUse`、`PostFileSave`、`Pre Task Execution`、`Post Task Execution` 等事件觸發，其中 Pre/Post Task Execution 明確與 tasks.md 的任務執行掛鉤，見 [kiro.dev/docs/hooks/](https://kiro.dev/docs/hooks/)。Steering 檔案（`.kiro/steering/`）透過 YAML front matter 的 `inclusion` 欄位控制載入時機（always／conditional fileMatch／manual／auto），是跨 session 都會自動套用的專案知識層，見 [kiro.dev/docs/steering/](https://kiro.dev/docs/steering/)。

### 對 agent-flow 的啟示

值得借鑑：
1. **EARS 格式**（`WHEN...THE SYSTEM SHALL...`／`IF...THEN...SHALL...`）比純自然語言更容易寫成可測試的驗收條件，適合 agent-flow 的 Spec phase 產出規格時採用，天然對應到 Ticket phase 要切的 TDD 測試案例。
2. 若第三方回報的 `_Requirements: 1.1, 2.3_` 標記屬實，這種**顯式、細顆粒度的任務↔需求回鏈語法**是三案例中最值得抄的 traceability 設計，agent-flow 的 Ticket phase 可以要求每張票／每個測試都標註對應哪條 spec 需求編號。
3. **Hooks 與 spec 流程解耦、事件驅動**（PostFileSave 觸發 lint、Pre/Post Task Execution 掛勾任務執行）以及**依賴圖分波次並行執行 tasks.md**的做法，直接對應 agent-flow Dev phase「平行實作」的需求，可作為排程設計的參考模型。

應避免：
1. Quick Spec 為了速度整個拿掉核准關卡，容易讓「先確認意圖再往下走」的價值被犧牲——這正是 agent-flow 特別把 Discuss（蘇格拉底提問）獨立成一個 phase 想要避免的反面案例，設計時應提醒自己不要為了效率而讓 Discuss phase 變成選用甚至可略過的裝飾。
2. Kiro 作為封閉產品，其 spec 產物的精確語法（traceability 標記、approval 用語、狀態標記）竟然需要靠社群逆向工程系統提示才能確認，官方文件反而語焉不詳。這提醒 agent-flow 應該把每個 phase 產物的 schema／格式當作**公開、明確定義**的一等公民（例如寫進 plugin 文件或 JSON schema），而不是只靠 prompt 內部隱性約定，否則使用者與外部工具都難以對接。

---

## 對照表

| 面向 | Spec Kit | OpenSpec | Kiro |
|---|---|---|---|
| **Phase 結構** | Constitution → Specify →（Clarify）→ Plan → Tasks →（Analyze）→ Implement；5 個核心＋4 個輔助指令，各自獨立可重跑 | Propose →（specs／design 依 schema 依賴圖平行產出）→ Apply →（Verify）→ Archive；用依賴圖取代線性關卡 | Requirements → Design → Tasks → Execution；三階段順序固定，標準流程每步皆需人工核准 |
| **可跳過／迭代** | Clarify／Analyze 為選用；plan／tasks 可重跑覆寫；preset 可整套換掉流程 | 高度可迭代（「dependencies are enablers, not gates」）；`skip_specs: true` 可跳過 spec 產出；可自訂 schema 改變順序 | 標準流程逐階段核准，不可任意跳；Quick Spec 一次產生三檔、無核准關卡，但無法中途換模式（未記載細節） |
| **產物格式與位置** | `spec.md`／`plan.md`／`tasks.md`／`research.md`／`data-model.md`／`contracts/`，存於 `specs/<NNN-feature>/` | `proposal.md`／`design.md`／`tasks.md`／`specs/<domain>/spec.md`（delta），存於 `openspec/changes/<name>/`；歸檔後合併進 `openspec/specs/` | `requirements.md`（EARS）／`design.md`／`tasks.md`，存於 `.kiro/specs/<feature>/`（目錄結構第三方來源，`.kiro/specs` 路徑本身有官方文件佐證） |
| **Traceability** | `FR-###`／`SC-###` 編號；tasks 用 `[Story]` 標籤對應 user story；`analyze` 自動產出 requirement↔task 覆蓋率表 | Delta spec 的 `## ADDED/MODIFIED/REMOVED Requirements` 直接對應主 spec；tasks.md 僅階層編號分組，無強制 ID 回鏈語法，靠人工審查對應 | Requirements 用編號 Acceptance Criteria；tasks.md 用 `_Requirements: 1.1, 2.3_` 顯式回鏈（第三方逆向工程資料，未經官方確認） |
| **品質檢查／人工確認點** | Spec 品質檢核清單（自我驗證＋最多 3 輪修正）；Constitution Check gate；`analyze` 唯讀分級報告（CRITICAL/HIGH/MEDIUM/LOW）；`implement` 前的 checklist gate | 兩個明確人工確認點：propose 後讀 plan（apply 前）、apply 後跑 `verify`（非阻斷，僅提示不擋歸檔）；`validate` 做結構層級檢查 | 三階段各自的「approval gate」問句（第三方確認精確用語）；Quick Spec 無 gate；可選 “Analyze Requirements” 找矛盾/模糊點 |
| **狀態外部化** | `.specify/feature.json`（記錄 feature 目錄，脫鉤 git branch）；`.specify/extensions.yml`（hooks 設定）；`checklists/*.md`（品質狀態） | `openspec status --json` 回報每個 artifact 的 `done`/`ready`/`blocked`/`skipped` 與 `missingDeps`／`nextSteps`；change 資料夾本身即狀態；歸檔即移入帶日期前綴的 `archive/` | Spec 三檔存於版控即狀態；tasks.md 內 `[TODO]`/`[IN_PROGRESS]`/`[DONE]`（第三方來源）；`.kiro/memory/` 據稱存放歷史決策（第三方來源，未經官方確認）；官方文件未明講跨 session 機制 |

---

## 主要來源清單

- Spec Kit：[github/spec-kit](https://github.com/github/spec-kit)、[spec-driven.md](https://github.com/github/spec-kit/blob/main/spec-driven.md)、[templates/](https://github.com/github/spec-kit/tree/main/templates)（含 `constitution-template.md`、`spec-template.md`、`plan-template.md`、`tasks-template.md`、`commands/specify.md`、`commands/clarify.md`、`commands/analyze.md`、`commands/implement.md`）
- OpenSpec：[Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec)、[docs/concepts.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md)、[docs/getting-started.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/getting-started.md)、[docs/how-commands-work.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/how-commands-work.md)、[docs/agent-contract.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/agent-contract.md)、[docs/reviewing-changes.md](https://github.com/Fission-AI/OpenSpec/blob/main/docs/reviewing-changes.md)、[openspec/changes/archive/](https://github.com/Fission-AI/OpenSpec/tree/main/openspec/changes/archive)（真實案例）
- Kiro：[kiro.dev/docs/specs/](https://kiro.dev/docs/specs/)、[kiro.dev/docs/specs/feature-specs/](https://kiro.dev/docs/specs/feature-specs/)、[kiro.dev/docs/specs/best-practices/](https://kiro.dev/docs/specs/best-practices/)、[kiro.dev/docs/hooks/](https://kiro.dev/docs/hooks/)、[kiro.dev/docs/steering/](https://kiro.dev/docs/steering/)、[kiro.dev/docs/guides/learn-by-playing/05-using-specs-for-complex-work/](https://kiro.dev/docs/guides/learn-by-playing/05-using-specs-for-complex-work/)；第三方：[github/spec-kit Issue #1242](https://github.com/github/spec-kit/issues/1242)（目錄結構）、[gist: Kiro Spec Agent System Prompt](https://gist.github.com/notdp/19822831b54190bd9c6b34f6b69fadeb)（逆向工程系統提示，traceability 標記與核准問句，未經官方確認）
