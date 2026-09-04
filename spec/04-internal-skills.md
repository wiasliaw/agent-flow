# 04 — Internal Skills 規格

## 已定（來源與依據）

- 六個 internal skill 定案清單（`state-management`／`sdd-guide`／`tdd-guide`／
  `parallel-dispatch`／`using-worktree`／`quality-loop`）：Q38、Q39。
- Internal skill 與 external skill 的分層動機、各自「範圍界定」與「誰在何時載入」：
  DESIGN §2「Skills 分兩層：external／internal」表格。
- 六句 internal skill 一句話文案（Q40 核准，逐字採用）：DESIGN §9「Internal skills（6 個，
  Q37–Q39）的一句話文案」表格。
- `user-invocable: false` 是 internal skill 的定義性 frontmatter 欄位、Claude 仍可載入但
  使用者無法手動觸發：research 01 §2.2「完整欄位表」、§3.2「who-invokes 控制」表格；DESIGN
  第 10 節 (b)（「殘餘待驗證事項」中已查證為非待實測項目）。
- `state.json` schema（Q30 定案）：DESIGN §6，本檔案 `state-management` 一節據此展開讀寫規範。
- EARS 格式、delta spec ADDED/MODIFIED/REMOVED 語法：Q7、Q8、DESIGN §3.4；research 03
  對 OpenSpec delta spec 語法、Kiro EARS 記法的記載。
- 需求編號回鏈：Q7；`state.json` 範例中 `tickets.<id>.requirementRefs` 欄位（DESIGN §6）
  是本檔案 `sdd-guide` 一節推導票證 frontmatter 對應欄位名稱的直接依據。
- 紅綠鐵律、測試合約：Q9、Q10、DESIGN §3.5、§3.6、§4；research 04 對 Superpowers TDD 鐵律與
  十條偷跳話術反駁表的記載（DESIGN §2 表格明文授權 `tdd-guide` 借用此設計）。
- 唯讀平行派工通則、20 並行上限：research 02 §3.1；DESIGN §2 表格（`parallel-dispatch` 範圍
  界定明文「這條是兩個派工 skill（`parallel-dispatch`／`using-worktree`）共通的通則，定義於此」）。
- 平行度依複雜度分級：research 04 對 Anthropic 多智能體研究系統的記載；DESIGN §5、§8。
- Worktree 建立前置條件（`baseRef: head`）、SendMessage 續談規則與其「必須由主 session 親自
  發起」的限制：research 07 Test A、Test B；DESIGN §3.6、§7。
- Review 重型迴圈三段式（平行蒐集 → 獨立驗證裁定 → 根因分流）、「不採信審查者自報嚴重度」：
  Q4、DESIGN §3.7；research 04 對 BMAD-METHOD 的記載。
- 根因分流二分法（`implementation-issue` / `approved-artifact`）：Q5。
- 迴圈輪數上限（標準 3 輪、重型 5 輪）與超限即上報（不換模型續作）：Q4、Q29、DESIGN §4。
- ESC 留痕格式（`decisions.md` 模板）與 `state.json.escalations` 同步：Q31、Q32、DESIGN §4。
- **審查者輸出格式契約（本檔案 `quality-loop` 一節的核心交付）**：DESIGN §4 明文延後、
  授權於規格對齊階段起草：「具體格式於規格對齊（PROMPT 第 4 步）時定義，不在設計階段先發明」。
  以下 schema 為本次規格對齊依此授權起草，並經**使用者裁決 S4 核准定案**（severity 二階、
  Review 兩層設計均維持不變）。
- **S1（裁決記錄，未採 DESIGN §3.7 原建議——實質設計變更）**：Review 重型迴圈不做自動退回／
  自動 ESC，全部 finding 於 Review 承諾點呈使用者裁決，已登記 `spec/README.md`「DESIGN.md
  回寫記錄」，本檔 `quality-loop` 規則 3 據此補充 Review 特例說明。
- **S3**：Wrap 上報沿用本節 ESC 格式，`escalations[].phase` 合法值含 `"wrap"`。
- **S4**：審查者輸出格式契約定案；`spec/02-state.md` `escalations[]` schema 新增
  `targetArtifact` 欄位（對 Q30 定案 schema 的擴充，已登記 `spec/README.md`「DESIGN.md
  回寫記錄」§6）。
- **S7**：`state.json` schema 版本不符時的處置維持保守停止上報，不預先設計遷移框架。

## 規格本文

### 通則

1. **檔案位置**：`skills/internal/<name>/SKILL.md`（plugin 根目錄 `skills/` 下的
   `internal/` 分組子目錄，對應 `plugin.json` 的 `"skills": ["./skills/external",
   "./skills/internal"]` 設定——巢狀分組目錄的平台支援依據見 01-plugin-structure.md）。
2. **六個 internal skill 一律加上 `user-invocable: false`**，且**不使用**
   `disable-model-invocation: true`：後者的語意是「使用者可呼叫、Claude 不可呼叫」
   （research 01 §3.2 who-invokes 控制表），與 internal skill 要的「Claude 可呼叫、使用者
   不可呼叫」剛好相反；`user-invocable: false` 才是正確欄位（`/` 選單隱藏、打 `/name` 不執行，
   但 description 常駐 context、Claude 判斷需要時仍可呼叫或由 `skills:` frontmatter preload）。
3. **六個 internal skill 都不宣告 `disable-model-invocation`、`allowed-tools`、
   `disallowed-tools`、`context: fork`**：這些 skill 是程序性指引文件，不需要在被載入的當輪
   預先核准或限制工具，也不需要 fork 出獨立子代理執行——它們的內容就是「怎麼做」的規則文字，
   由載入它的 agent／orchestrator 自己的工具集執行動作。
4. **Description 逐字採用 DESIGN §9 表格文案**（Q40 已核准，見下方每節 frontmatter），不重寫。

---

### 1. `state-management`

- **檔案路徑**：`skills/internal/state-management/SKILL.md`
- **依據**：Q21、Q30、Q32、DESIGN §2、§6。

```yaml
---
name: state-management
description: >-
  Load this before any read or write to
  .agent-flow/changes/<unit>/state.json — keeps phase status, gate status,
  loop rounds, and ticket status consistent with the schema.
user-invocable: false
---
```

- **誰在何時載入**：`orchestrate`（唯一寫入 `state.json` 者）；03-agents.md 已逐一檢視 17 個
  角色 agent 的職責，結論是目前沒有任何角色 agent 需要直接讀寫 `state.json`（票證相依關係的
  權威來源是票證 frontmatter，迴圈輪次由 orchestrator 在派工 prompt 中直接告知），因此本 skill
  只被 `orchestrate` 這一個 external skill preload／載入。
- **內文必須涵蓋的規則**：
  1. **Schema 版本檢查**：讀取前先確認 `schemaVersion` 欄位等於本 skill 內文記載的目前版本
     （1，依 DESIGN §6 範例）。若不相等，停止並回報使用者（本規格不定義自動遷移邏輯——見
     「待對齊」）。
  2. **逐欄位語意**（原樣抄錄 DESIGN §6 schema 並附中文說明，供載入者對照）：
     - `unit`：工作單位名稱，格式 `<YYYY-MM-DD>-<slug>`（Q28）。
     - `currentPhase`：目前所在 phase 的鍵值（`discuss`／`explore`／`prototype`／`spec`／
       `ticket`／`dev`／`review`／`wrap` 之一）。
     - `phases.<phase>.status`：該 phase 的狀態（`pending`／`in_progress`／`done`／
       `skipped`）；`skipped` 僅 `prototype` 合法使用（DESIGN §3.3：無疑問可略過），且必須
       附 `reason` 欄位。
     - `gates.<phase>.approvedAt`／`approvedBy`：僅四個承諾點 phase（`discuss`／`spec`／
       `ticket`／`review`）有此物件；未核准時為 `null`。
     - `qualityLoops.<key>`：`key` 格式為 `<phase>` 或 `<phase>:<ticket-id>`（Dev phase 逐票
       各自一個 key，DESIGN §6 範例 `"dev:TICKET-002"`）；`rounds`／`maxRounds`／`status`
       三欄位，`status` 的合法列舉值與意義：`in_progress`（迴圈進行中）、`passed`（已通過）、
       `escalated`（達輪數上限或觸發 Q5 上報，已停止迴圈、待使用者裁決）。
     - `tickets.<id>.dependsOn`：票證 frontmatter 的鏡像（非權威來源，Q32）。
     - `tickets.<id>.requirementRefs`：對應需求編號（Q7），同樣鏡像自票證 frontmatter。
     - `escalations`：上報紀錄陣列，與 `decisions.md` 的 ESC 條目一一對應（見 `quality-loop`
       一節）。
     - `branch`：單位分支與其分岔基準的紀錄。
  3. **寫入時機**（僅 `orchestrate` 執行）：
     - 建立工作單位（Discuss 啟動）時初始化整份 `state.json`。
     - 每個 phase 狀態變化時（`pending → in_progress → done/skipped`）。
     - 承諾點核准時寫入 `gates.<phase>`。
     - 每次品質迴圈完成一輪（不論通過或退回）時更新對應 `qualityLoops.<key>`。
     - 每次讀到票證 markdown frontmatter 異動時，同步覆寫 `tickets.<id>` 對應欄位（Q32：
       「票證 frontmatter 為準，state.json 同步」——因此寫入時機是「讀到異動後」，不是
       「異動發生的當下」，允許有短暫的不同步窗口，只要下次讀取前完成同步）。
     - 每次寫入 `decisions.md` 的 ESC 條目時，同步 append 到 `escalations` 陣列。
  4. **單一寫入者原則**：只有 `orchestrate` 寫入 `state.json`；角色 agent 一律不直接讀寫此
     檔案（見上「誰在何時載入」）。
  5. **寫入方式**：每次寫入整份檔案（讀出→記憶體修改→整份覆寫），不做局部 patch，降低格式
     損毀風險；`orchestrate` 每次寫入前應重新讀取一次目前內容，避免對過期記憶體狀態覆寫
     （尤其是 Dev phase 多票並行、`state.json` 更新頻率較高時）。

---

### 2. `sdd-guide`

- **檔案路徑**：`skills/internal/sdd-guide/SKILL.md`
- **依據**：Q7、Q8、DESIGN §2、§3.4、§3.5、§6；research 03（EARS、OpenSpec delta spec）。

```yaml
---
name: sdd-guide
description: >-
  Load this when writing or reviewing a delta spec, a ticket's requirement
  backlink, or merging a delta into the main spec — defines the EARS and
  ADDED/MODIFIED/REMOVED contract.
user-invocable: false
---
```

- **誰在何時載入**：`spec-writer`／`spec-reviewer`／`ticket-writer`／`ticket-reviewer`；
  Wrap 的 `wrap-executor`；Review 的 `review-spec-compliance-auditor`（03-agents.md 額外
  推導，因其職責是核對實作與 delta spec 語意是否一致，需要相同的格式契約知識）。
- **內文必須涵蓋的規則**：
  1. **EARS 句型**（Q7）：需求本文一律用 `WHEN <事件/條件> THE SYSTEM SHALL <預期行為>` 句型
     撰寫；每條需求附編號（格式 `<主編號>.<子編號>`，如 `1.1`、`1.2`）。
  2. **Delta spec 語法**（Q8，借用 OpenSpec，research 03）：`spec-delta.md` 用三個區塊描述
     相對主 spec 的變化：
     ```markdown
     ## ADDED Requirements
     ### 1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a
     reset link valid for 1 hour.

     ## MODIFIED Requirements
     ### 2.3 WHEN ... (原編號，新內容)

     ## REMOVED Requirements
     ### 3.1 (原編號，附一句話說明移除原因)
     ```
     Greenfield 情境（該領域尚無主 spec）下，`spec-delta.md` 只會有 `## ADDED Requirements`
     區塊，其餘兩區塊省略不寫（不是寫空區塊）。
  3. **需求編號回鏈**（Q7）：票證 frontmatter 必須含 `requirementRefs: [<編號>, ...]`
     欄位（YAML 陣列，如 `requirementRefs: ["1.1", "2.3"]`）——此欄位名稱與
     `state.json.tickets.<id>.requirementRefs`（DESIGN §6 schema）保持一致，orchestrator
     讀到票證異動時原樣鏡像同步（見 `state-management` 一節）。每張票證至少對應一條需求編號；
     測試案例（Ticket phase 產出）在測試檔案的註解或描述中也應標註對應編號，供人工追溯。
  4. **合併進主 spec 的規則**（Wrap phase，`wrap-executor` 執行，DESIGN §6：主 spec 依領域
     分域存於 `.agent-flow/specs/<domain>/spec.md`，Q24）：
     - `ADDED` 區塊的每條需求，附加進對應領域 `spec.md`（若該領域 `spec.md` 不存在則新建）。
     - `MODIFIED` 區塊的每條需求，依編號找到主 spec 中的既有條目並整條覆寫其內容。
     - `REMOVED` 區塊的每條需求，依編號從主 spec 中刪除該條目。
     - 合併後主 spec 應保持與其目錄下需求編號的內部一致性（不強制全域重新編號，只要求同一
       領域內編號不重複）；領域切分粒度由專案自訂（Q24），本 skill 不規定切分規則本身。
  5. **審查者的額外核對項**（`spec-reviewer`／`review-spec-compliance-auditor`）：EARS 句型
     是否正確、編號是否連續無衝突、ADDED/MODIFIED/REMOVED 分類是否對應現況屬實（例如標成
     MODIFIED 但主 spec 其實沒有該編號的既有條目，應判定為錯誤分類）。

---

### 3. `tdd-guide`

- **檔案路徑**：`skills/internal/tdd-guide/SKILL.md`
- **依據**：Q9、Q10、DESIGN §2、§3.5、§3.6、§4；research 04（Superpowers TDD 鐵律與偷跳話術
  反駁表）。

```yaml
---
name: tdd-guide
description: >-
  Load this when writing, reviewing, or implementing a ticket's tests —
  the red-before-green rule, the no-editing-approved-tests contract, and
  the rationalization rebuttal table.
user-invocable: false
---
```

- **誰在何時載入**：`ticket-writer`／`ticket-reviewer`／`dev-worker`／`dev-reviewer`。
- **內文必須涵蓋的規則**：
  1. **紅綠鐵律**（Q9）：Ticket phase 產出的每張票證測試，必須是可執行的真測試碼，且
     `ticket-writer` 必須實際執行該測試並確認結果為紅燈（因功能未實作而失敗，非因語法或環境
     錯誤）；`ticket-reviewer` 必須獨立重跑一次確認同樣結果。
  2. **測試合約**（Q10）：Ticket 承諾點核准後，票證測試檔案成為不可修改的合約。`dev-worker`
     發現測試疑似有誤時，**不得直接修改**，必須停止該部分實作並在回報中明確標示，交由
     orchestrator 依 Q5 路由為「根因在已核准產物」上報使用者裁決。`dev-reviewer` 必須用
     `git diff` 核對測試檔案內容相對其初始 commit 未被修改，發現被修改一律判定為
     `approved-artifact` 根因（不當作一般實作問題自動退回）。
  3. **偷跳話術反駁表**（借用 research 04 記載的 Superpowers 設計精神，改寫為 agent-flow
     自己的措辭與情境，非逐字抄錄第三方 skill 文字）：

     | 常見話術 | 反駁 |
     |---|---|
     | 「這個測試太簡單，不用真的跑」 | 沒有實際執行紀錄的測試不算數；`ticket-reviewer`／`dev-reviewer` 只採信可重現的執行證據。 |
     | 「先跳過這條，之後再補測試」 | Ticket phase 的定義就是「測試先於實作」（PROMPT）；沒有先寫測試就沒有票證可以進 Dev phase。 |
     | 「我手動測過，結果是對的」 | 手動測試不是可重現證據，審查者必須能自己重新執行同一個測試得到同樣結果。 |
     | 「這條測試好像寫錯了，我直接改一下比較快」 | 違反 Q10 測試合約，必須停止並上報，不可自行修改。 |
     | 「測試失敗是環境問題，不是功能沒做」 | 必須先排除環境問題（確認測試框架能正常執行其他測試）才能宣稱這是有效的紅燈／綠燈結果。 |
     | 「這個案例邊界情況不重要，先跳過」 | 票證測試的範圍由 Ticket phase 核准內容決定，不由 `dev-worker` 自行縮減。 |
     | 「測試已經在別的地方涵蓋過了，不用重跑」 | `dev-reviewer` 每次審查都必須對**這張票證**的測試重新執行，不採信「別處測過」的說法。 |
     | 「先把功能做完，測試最後一起補」 | 違反紅綠鐵律；沒有先看到紅燈就不能開始寫實作。 |
     | 「刪掉重寫這段測試太浪費已經寫好的程式碼」 | 測試合約不因實作成本而讓步；若測試真的有誤，正確路徑是上報，不是繞過。 |
     | 「審查者應該可以理解我的意圖，不用逐字核對」 | 審查者的職責就是逐條核對而非理解意圖；含糊帶過視為未通過審查。 |
  4. **`dev-worker` 的職責邊界**：只負責讓已確認為紅燈的測試轉綠，不重新驗證「測試曾經是
     紅燈」（那是 Ticket phase 已完成的工作）；轉綠後在自己的 worktree 內 commit 一次（Q34）。

---

### 4. `parallel-dispatch`

- **檔案路徑**：`skills/internal/parallel-dispatch/SKILL.md`
- **依據**：Q11、DESIGN §2、§5、§8；research 02 §3.1；research 04（Anthropic 多智能體研究
  系統的分級平行度、輸出落地檔案原則）。

```yaml
---
name: parallel-dispatch
description: >-
  Load this before fanning out multiple read-only subagents at once —
  file-based handoff, complexity-based parallelism, and the 20-subagent
  batching rule.
user-invocable: false
---
```

- **誰在何時載入**：**派工者**本身（`orchestrate`），在需要一次派出多個唯讀審查／研究子代理
  時載入——例如 Review phase 同時派出 `review-gap-hunter`／`review-edge-case-hunter`／
  `review-spec-compliance-auditor` 三個平行審查小組，或任何 phase 需要多視角唯讀查核時。
  **這不是被派工的角色 agent 自己要載入的 skill**：三個平行審查小組與 `review-triage`
  本身不會再往下派生下一層子代理（DESIGN §5「巢狀深度」），所以它們不需要、也不 preload
  `parallel-dispatch`——03-agents.md 的 17 個 agent 定義檔皆未 preload 此 skill。
- **內文必須涵蓋的規則**：
  1. **輸出落地檔案、只傳輕量引用**（research 04）：任何一次唯讀平行派工，prompt 內容一律
     傳遞檔案路徑而非把內容整段貼入；子代理完成後只回傳「結論摘要＋讀取/寫入的檔案路徑」。
  2. **平行度依複雜度分級**（借用 research 04 記載的 Anthropic 案例分級規則，換算成
     agent-flow 情境）：
     - 單一明確問題（如核對一條需求是否有對應實作）：1 個子代理即可，不必平行拆分。
     - 多視角查核（如 Review phase 的三個獨立審查角度）：固定 3 個子代理平行（DESIGN §3.7
       已定案為三個角色，不依複雜度再增減）。
     - 若某 phase 需要對多個獨立子項目（如多個檔案／多個模組）分別做唯讀調查，才依項目數量
       決定平行度，不是「能拆多細就拆多細」——拆分粒度應以「每個子代理的調查範圍互不重疊」為
       判準。
  3. **20 個並行上限與分批規則**（research 02 §3.1；本規則與 `using-worktree` 共用，
     定義在此、`using-worktree` 一節只引用不重複）：Agent tool 產生的子代理預設最多同時 20
     個並行；單一波次若超過 20 個，先派滿 20 個，其餘等有名額釋出後再補上。
  4. **禁止巢狀再派審查者**：被 `parallel-dispatch` 派出的唯讀子代理，不得再用 Agent tool
     往下派生下一層審查子代理——「獨立於作者」的審查角色分派，永遠由 orchestrator 一層直接
     完成，不假手中介子代理（呼應 research 04 對 Superpowers「明確禁止 implementer 自己生
     reviewer」的引用，DESIGN §5）。
  5. **不共享 context、各自獨立判斷**：平行派出的多個審查/研究子代理，彼此看不到對方的過程
     或結論（DESIGN §3.7），這是 `parallel-dispatch` 的預設行為（非 fork 子代理天生互相隔離，
     research 02 §1.4），不需要額外設定，但 orchestrator 派工 prompt 中不得夾帶「其他角色的
     初步看法」，以免變相污染獨立性。

---

### 5. `using-worktree`

- **檔案路徑**：`skills/internal/using-worktree/SKILL.md`
- **依據**：Q11、DESIGN §2、§3.6、§7；research 06 實驗四；research 07 Test A、Test B。

```yaml
---
name: using-worktree
description: >-
  Load this only as the orchestrator, before creating or resuming a
  ticket's isolated worktree — the branch/baseRef precondition, the
  same-agent SendMessage resume rule, and worktree cleanup after merge.
user-invocable: false
---
```

- **誰在何時載入**：**僅 `orchestrate`**。Dev phase 的 worktree 建立、續談、合併、清理全部由
  主 session 親自執行（理由見規則 2：續談完成通知只回主 session）；`dev-worker` 自己不 preload
  這個 skill（它不需要知道「怎麼建立/續談 worktree」，它只是在已建好的 worktree 裡工作）；
  `wrap-executor` 的殘留 worktree 清理是一般性 safety-net 清理，不涉及本 skill 定義的
  建立/續談規則，同樣不 preload（推理見 03-agents.md 第 16 節）。
- **內文必須涵蓋的規則**：
  1. **建立票證 worktree 前的必要條件**（research 07 Test B）：orchestrator 必須先
     `git checkout` 到單位分支 `flow/<unit-name>`，並在呼叫 `dev-worker` 時明確設定
     `worktree.baseRef: "head"`——不得依賴預設值 `"fresh"`。理由：`"fresh"` 的官方語意是
     「從遠端預設分支分出」，實測（research 07 Test B）只在**無 remote** 的情境下觀察到分岔
     基準恰好跟隨當下 checkout；一旦專案有 remote，依賴「不設定、指望它自動跟上當下分支」
     可能導致所有票證分岔自 remote 的 `main`，而非單位分支目前累積的進度，破壞多票證疊在同一
     單位分支上逐步累積的設計前提。
  2. **審查退回時的續談規則**（research 07 Test A）：`dev-reviewer` 判定退回後，
     orchestrator（主 session）**親自**用 `SendMessage` 對該次 `dev-worker` 呼叫拿到的
     `agentId` 續談，**不可**：
     - 用 Agent tool **重新派工**（即使 `subagent_type` 相同）——重新派工一律拿到全新
       worktree，先前實作與 worktree 內容不會保留（research 06 實驗四）。
     - 委派任何中介子代理代替 orchestrator 發起續談——`SendMessage` 續談已完成子代理時，
       完成通知只會送回**主 session**，不會送回發起續談的那個子代理（research 07 Test A
       「額外發現」）；若讓中介子代理代為續談，它會永遠等不到完成通知而卡住。
  3. **平行派工與分波次排程**（Q11、DESIGN §5）：orchestrator 在 Dev phase 開始時，計算目前
     `dependsOn` 已全部完成（對應票證已合併進單位分支）的票證集合，於**同一輪回應**中一次
     發出該集合內所有票證的 Agent tool 呼叫（多個呼叫在同一輪回應＝平行）；等待整批完成、
     各自通過品質迴圈並合併後，才計算下一批解鎖的票證。超過 20 個並行上限時的分批規則引用
     `parallel-dispatch` 定義的通則，不在此重複定義。
  4. **合併後的清理**（research 02 §4.3、§7）：某票證品質迴圈通過後，orchestrator 把該票證
     worktree 的變更合併進單位分支，**立即明確執行 `git worktree remove`**（必要時先
     `git worktree unlock`）——不能依賴 Claude Code 自動清理，因為「有變更的 worktree」執行
     完不會被自動清除（只有無變更的 worktree 才會自動清除，research 06 實驗四 (c)），而 Dev
     phase 的票證本來就一定有變更。
  5. **Dev 與 Review 不共用 worktree**（research 06 實驗四）：Review phase 審查的是已合併的
     單位分支整體 diff，不是嘗試讀取某個已被移除的 Dev worktree——這與規則 4「合併後立即清理」
     天然吻合，orchestrator 不需要在 Dev/Review 之間額外保留任何 worktree。

---

### 6. `quality-loop`

- **檔案路徑**：`skills/internal/quality-loop/SKILL.md`
- **依據**：Q4、Q5、Q10、Q29、Q31、Q32、DESIGN §2、§4；research 04（BMAD triage 三段式、
  Superpowers 迴圈輪數與升級策略）。

```yaml
---
name: quality-loop
description: >-
  Load this whenever a reviewer needs to report a verdict, or the
  orchestrator needs to route one — the two-tier loop, the two-way
  routing rule, round limits, and the ESC trace format.
user-invocable: false
---
```

- **誰在何時載入**：每個 phase 的審查子代理（`intent-reviewer`、`explore-reviewer`、
  `prototype-reviewer`、`spec-reviewer`、`ticket-reviewer`、`dev-reviewer`、
  `review-gap-hunter`、`review-edge-case-hunter`、`review-spec-compliance-auditor`、
  `review-triage`，共 10 個角色）；`orchestrate` 讀取審查結果、判斷路由時也載入。
  `wrap-verifier` **不**載入——Wrap 的執行—驗證迴圈（Q25）不適用本 skill 定義的「退回原作者
  修」判定格式，理由見 03-agents.md 第 17 節。

- **內文必須涵蓋的規則**：

  1. **兩級迴圈選用規則**（Q4）：
     - **標準迴圈**：Discuss、Explore、Prototype、Spec、Ticket、Dev（逐票證）。單一獨立審查者
       → 有問題退回原作者修改 → 上限 **3 輪** → 上報使用者裁決。
     - **重型迴圈**：僅 Review。三個獨立審查子代理平行蒐集 finding → `review-triage` 獨立
       驗證裁定與根因分流 → 上限 **5 輪**（Q29）→ 上報。

  2. **審查程序**：審查者收到作者產物的檔案路徑後，獨立判斷（不受作者說法左右，不能因為作者
     的敘述語氣自信就放行），輸出下方定義的標準化格式；orchestrator 依 `verdict` 決定：
     `pass` → phase 完成，寫入 `state.json` 對應 `qualityLoops.<key>.status = "passed"`；
     `reject` → 依 `findings[].rootCause` 分流（見規則 3）。

  3. **退回路由二分法**（Q5，只分兩類，不採 BMAD 四分流）：
     - `implementation-issue`：問題出在本 phase 內、還沒核准的產物，由迴圈自動退回原作者
       子代理修正（標準迴圈：重新派工或依角色性質續談；Dev phase 的 `dev-worker` 必須用
       `SendMessage` 續談同一個 agent ID，見 `using-worktree`，不可重新派工），計入該迴圈輪數。
     - `approved-artifact`：根因在已核准產物（Discuss 摘要、Spec delta、Ticket 與其測試），
       一律停下來上報使用者裁決，agent 不自行推翻已核准的東西（Q5、Q10）。
     - **Review 重型迴圈不適用本規則的自動路由部分**（S1 裁決，見 `spec/12-review.md`、
       `spec/05-orchestrate.md` §4.7）：`rootCause` 分類仍然由 `review-triage` 輸出（`findings[].rootCause`
       欄位不變），但**不驅動自動退回、不驅動自動 ESC**——三個平行小組＋`review-triage` 的
       全部 finding（不分根因分類）一律先彙整進 `review.md`、於 Review 承諾點呈給使用者裁決；
       使用者核准修正 `implementation-issue` finding 後，orchestrator 派**全新**（非續談）的
       `dev-worker` 執行修正；`approved-artifact` finding 若使用者要求修正，走「使用者主動
       修改已核准產物」機制（`spec/05-orchestrate.md` §3.1），不是本規則的自動 ESC。此為
       DESIGN §3.7 原文（「純實作問題可退回修正」對 Review 同樣適用）之外的實質設計變更，
       已登記 `spec/README.md`「DESIGN.md 回寫記錄」。本規則的自動路由對其餘六個標準迴圈
       phase（Discuss／Explore／Prototype／Spec／Ticket／Dev）維持不變。

  4. **測試合約的路由特例**：任何審查者發現票證測試檔案本身被修改（不論是誰改的），一律將
     該 finding 的 `rootCause` 標為 `approved-artifact`（`escalation.targetArtifact: "ticket"`），
     不當作一般實作問題自動退回（呼應 `tdd-guide` 一節）。

  5. **輪數上限與超限處置**：達到上限（標準 3、重型 5）時，**不**自動換模型或換全新作者子
     代理重試（與 research 04 記載的 Superpowers 升級策略不同——訪談選擇「分級迴圈」而非
     「簡單迴圈＋升級」，Q4 選項 4 未採納），一律上報使用者裁決，並在 `state.json` 對應
     `qualityLoops.<key>.status` 寫入 `"escalated"`。

  6. **ESC 留痕格式**（Q31，逐字採用 DESIGN §4 模板）：每次上報寫入
     `changes/<unit>/decisions.md`：

     ```markdown
     ## ESC-<n>：<一行摘要>
     - Phase／輪次：<phase>（第 <k>/<max> 輪）
     - 觸發角色：<author-role> vs <reviewer-role>
     - 根因分類：<純實作問題 | 根因在已核准產物：Discuss/Spec/Ticket>
     - 細節：...
     - 使用者裁決：...
     - 裁決時間：...
     ```

     並同步 append 一筆到 `state.json.escalations` 陣列（`id`／`phase`／`ticket`（若適用）／
     `rootCause`／`raisedAt`／`resolvedAt`，欄位定義見 `state-management` 一節）。ESC 的
     `<n>` 編號由 orchestrator 依單位內既有 ESC 數量遞增指派，不由審查者自行編號。

  7. **審查者輸出格式契約（本規格對齊階段起草的提案 schema）**：

     所有審查子代理（含 Review 的三個平行小組與 `review-triage`）的輸出，一律使用以下 JSON
     形式回報（選 JSON 而非 YAML：與 `state.json` 一致，且 orchestrator 需要機械式解析，
     JSON 語意最無歧義，呼應 Q21 選擇 JSON 而非 markdown 作為狀態檔格式的同一理由）。

     **標準迴圈審查者**（`intent-reviewer`、`explore-reviewer`、`prototype-reviewer`、
     `spec-reviewer`、`ticket-reviewer`、`dev-reviewer`）輸出：

     ```json
     {
       "schemaVersion": 1,
       "role": "ticket-reviewer",
       "phase": "ticket",
       "unit": "2026-09-04-auth",
       "target": {
         "artifact": "changes/2026-09-04-auth/tickets/TICKET-002.md",
         "ticketId": "TICKET-002"
       },
       "round": 2,
       "maxRounds": 3,
       "verdict": "reject",
       "findings": [
         {
           "id": "F1",
           "severity": "blocking",
           "location": "changes/2026-09-04-auth/tickets/TICKET-002.md",
           "description": "Test asserts against a mock that is never configured.",
           "evidence": "Ran `npm test TICKET-002.spec.ts`; failure is a TypeError, not the expected assertion failure.",
           "rootCause": "implementation-issue"
         }
       ],
       "escalation": null
     }
     ```

     欄位說明：
     - `verdict`：`"pass" | "reject"`。
     - `target`：被審查的產物；`ticketId` 僅 Dev/Ticket 相關角色需要，其餘角色省略此欄位。
     - `round`／`maxRounds`：與 `state.json.qualityLoops.<key>` 的 `rounds`／`maxRounds`
       語意一致（本欄位由審查者依 orchestrator 派工時告知的目前輪次填寫，orchestrator 收到後
       據此更新 `state.json`，兩邊語意不衝突但不是同一份資料——`state.json` 是持久狀態，這裡
       是單次審查回報）。
     - `findings[].severity`：`"blocking" | "non-blocking"`（採用 DESIGN §9 旅程文案已使用
       的「阻斷／非阻斷」二元詞彙，而非另造 high/medium/low 三階，降低與既有文案不一致的風險）。
     - `findings[].rootCause`：`"implementation-issue" | "approved-artifact"`（Q5）。
     - `escalation`：`verdict = "reject"` 且任一 finding 的 `rootCause` 為
       `"approved-artifact"` 時必填，格式：
       ```json
       { "targetArtifact": "spec", "reason": "Requirement 1.2 conflicts with 1.4." }
       ```
       `targetArtifact` 合法值：`"discuss" | "spec" | "ticket"`（對應 ESC 模板的根因分類
       選項）。ESC 編號、`decisions.md` 寫入由 orchestrator 完成，審查者不填 ESC id。

     **Review 重型迴圈**分兩層：

     **(a) 三個平行審查小組**（`review-gap-hunter`／`review-edge-case-hunter`／
     `review-spec-compliance-auditor`）的**原始 finding**——不含 `verdict`、不含 `rootCause`
     （分類是 `review-triage` 的職責，平行小組不做根因判斷），`severity` 改名
     `reportedSeverity` 以明示「僅供參考、非最終判定」（呼應 DESIGN §3.7 對 BMAD「不採信
     審查者自報嚴重度」的引用）：

     ```json
     {
       "schemaVersion": 1,
       "role": "review-gap-hunter",
       "phase": "review",
       "unit": "2026-09-04-auth",
       "round": 1,
       "findings": [
         {
           "id": "G1",
           "location": "src/auth/reset.ts",
           "description": "No rate limiting on password-reset requests.",
           "evidence": "Grep of src/auth/reset.ts shows no throttling logic; spec-delta.md requirement 1.3 requires it.",
           "reportedSeverity": "blocking"
         }
       ]
     }
     ```

     **(b) `review-triage` 的裁定輸出**——沿用標準迴圈的 schema 形狀（`verdict`／
     `findings[].severity`／`findings[].rootCause`／`escalation` 語意相同），額外加一個欄位
     `findings[].sourceFindingIds` 回指裁定所依據的原始 finding（跨三個平行小組，格式
     `"<role>:<id>"`），並把 `maxRounds` 固定為 5（Q29）：

     ```json
     {
       "schemaVersion": 1,
       "role": "review-triage",
       "phase": "review",
       "unit": "2026-09-04-auth",
       "round": 1,
       "maxRounds": 5,
       "verdict": "reject",
       "findings": [
         {
           "id": "T1",
           "sourceFindingIds": ["review-gap-hunter:G1"],
           "severity": "blocking",
           "location": "src/auth/reset.ts",
           "description": "Confirmed: no rate limiting implemented despite spec-delta.md requirement 1.3.",
           "evidence": "Re-read src/auth/reset.ts and spec-delta.md directly; requirement 1.3 explicitly requires throttling.",
           "rootCause": "implementation-issue"
         }
       ],
       "escalation": null
     }
     ```

     這個兩層設計的理由：三個平行小組不共享彼此結果（DESIGN §3.7 隔離要求），若讓它們直接
     輸出「最終裁定」格式（含 `rootCause`），會變成三份互相矛盾的裁定、且違反「不採信審查者
     自報嚴重度」的精神；因此原始 finding 層刻意做得比標準迴圈簡單（無 `verdict`、無
     `rootCause`），把「裁定」這個動作唯一收斂到 `review-triage` 一個角色，裁定輸出直接複用
     標準迴圈 schema 的形狀，讓 orchestrator 端的解析邏輯可以共用同一套程式碼路徑處理
     `verdict`／`findings[].rootCause`／`escalation`，只有 Review 這一種角色的輸出多一個
     `sourceFindingIds` 欄位。

## 待對齊

無。以下三項原待對齊已由使用者裁決（S7、S3、S4）：

- **原 #1（S7 裁決：`state.json` schema 版本不符時的處置）**：採選項 (a)——維持「讀取前檢查
  `schemaVersion`，不符則停止並回報使用者」的保守處置，不預先設計遷移框架；`state-management`
  一節規則 1 原文已是此裁決的正確描述，不需修改文字，僅將裁決依據記為 S7。
- **原 #2（S3 裁決：`decisions.md` ESC 編號允許 phase 為 `"wrap"`）**：確認**沿用**本節定義的
  ESC 格式與 `escalations` 陣列，`escalations[].phase` 合法值集合擴充為包含 `"wrap"`（原
  `spec/02-state.md` §2.2 `escalations` 陣列的 `phase` 欄位型別為自由字串、本就未限制列舉值，
  這裡是明確記錄 `"wrap"` 為合法值，非新增欄位）；ESC 模板「Phase／輪次」欄位在 Wrap 情境下
  填「Wrap（無輪次，執行—驗證迴圈）」，取代 `<k>/<max>` 的數字形式——與 `spec/13-wrap.md`
  「上報格式」節、`spec/03-agents.md` 第 17 節一致。
- **原 #3（S4 裁決：審查者輸出格式契約核准）**：本節起草的 schema 整包定案，包含
  `severity: blocking/non-blocking`（不改為 high/medium/low）與 Review 兩層設計（原始
  finding／`review-triage` 裁定）均維持不變、不簡化為單層。**S4 附帶的 schema 擴充**：
  `escalation` 物件（規則 7）新增對應 `spec/02-state.md` `escalations[].targetArtifact` 的
  欄位語意一致性確認——`escalation.targetArtifact` 合法值 `"discuss" | "spec" | "ticket"`
  維持不變（S4 未要求擴充這組列舉值，只要求 `state.json.escalations[]` 補上對應欄位，見
  `spec/02-state.md` §2.2 該項變更，已登記 `spec/README.md`「DESIGN.md 回寫記錄」）。**S1
  對本契約的影響**：Review 情境下 `rootCause`／`escalation` 欄位仍然輸出，但語意從「驅動
  自動路由」改為「供使用者裁決與 orchestrator 判斷可行修正手段」，已於規則 3 補充說明，
  schema 本身欄位不變。
