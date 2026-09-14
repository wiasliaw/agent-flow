# 04 — References（內部參考文件）規格

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R4（2026-09-10 重構裁決）**：internal skill 機制廢止，內容改為 `references/` 目錄下的純 markdown 參考文件——不是 skill、無 frontmatter、不出現在任何選單；主 session 與子代理都以 `Read` 載入（子代理由派工 prompt 指名路徑）。Q37–Q40（兩層 skills 與 internal skill 文案）、G2（glossary internal skill 載體）隨之廢止；G1／G3 的 DSL＋Invariant 模式本身承襲，載體改為 `references/glossary.md`。
- **R3**：quality-loop 的路由模型改版——`rootCause` 二分法（`implementation-issue`/`approved-artifact`）與 `escalation.targetArtifact` 廢止，改為 `targetPhase` 驅動的 waterfall 退回。
- **R5**：原「誰在何時載入」按 17 角色的分配廢止，改為「主 session 讀」與「派工 prompt 指名給 worker／reviewer 讀」兩類。
- 原六個 internal skill 收斂為六份 reference：`state-management`／`sdd-guide`／`tdd-guide` 內容承襲；`parallel-dispatch`＋`using-worktree` 合併為 `dispatch`；`quality-loop` 依 R3 改版；`glossary` 依 R3／R4 改版。
- 承襲的個別裁決：Q7／Q8（EARS、delta 語法）、Q9／Q10（紅綠鐵律、測試合約——起點依 R2 改為 TDD 迴圈通過）、Q25（Wrap 執行—驗證不適用迴圈契約）、Q34（commit 顆粒度）、S7（schema 版本檢查）、research 02 §3.1（20 並行上限）、research 04（落地檔案、不採信自報嚴重度、反駁表精神）、research 06／07（worktree 續談與清理）；**research 12／13（R12）取代 research 08**——worktree 改由主 session 自建，`worktree.baseRef` 不再是前置條件。

## 規格本文

### 通則

1. **檔案位置**：`references/<name>.md`，純 markdown、無 YAML frontmatter。
2. **不受 `claude plugin validate` 檢查**：存在性由 spec/01 §2.5.2 的機械檢查補強。
3. **讀者與載入方式**：
   - 主 session：執行任何 external skill 前先 `Read` glossary（取代舊 G2 載入規則）；驅動流程時依需要 `Read` 其他 reference。
   - 子代理（`worker`／`reviewer`）：只讀派工 prompt 指名的檔案，開工前先讀。
   - **路徑解析基準**：reference 路徑一律相對 **plugin 根目錄**，不是使用者專案或 worktree 的目前工作目錄。External skill 內文引用 reference 時必須寫 `${CLAUDE_PLUGIN_ROOT}/references/<name>.md`（skill 執行期展開）；主 session 派工時把**展開後的絕對路徑**寫進角色簡報——子代理（尤其在隔離 worktree 內）無從解析 plugin 相對路徑。本規格各處的 `references/<name>.md` 簡寫皆指此解析規則下的同一檔案。
4. **自足性**：每份 reference 對其讀者自足——reviewer 只拿到 `quality-loop.md` 也要能正確輸出契約，不依賴讀過 glossary。

### 清單總表

| 檔案 | 內容 | 誰讀 |
|---|---|---|
| `glossary.md` | DSL 語法、primitives、變數、共用程序、INV-1～INV-13 | 主 session（執行任何 external skill 前） |
| `state-management.md` | `state.json` 讀寫規範 | 主 session |
| `dispatch.md` | 平行派工通則＋worktree 生命週期（原兩份合併） | 主 session |
| `quality-loop.md` | 品質迴圈、waterfall 路由、審查者輸出 JSON 契約、FB／ESC 格式 | 主 session；審查派工時指名給 `reviewer` |
| `sdd-guide.md` | EARS、delta spec、需求編號回鏈、主 spec 合併規則 | Spec／TDD／Review（compliance lens）／Wrap 派工時指名 |
| `tdd-guide.md` | 紅綠鐵律、測試合約、反駁表 | TDD／Build 派工時指名 |

### 1. `state-management.md`

內文必須涵蓋：

1. **Schema 版本檢查（S7）**：讀取前確認 `schemaVersion == 2`，不符即停止並回報使用者，不自動遷移。
2. **逐欄位語意**：抄錄 `spec/02-state.md` §2.2 schema 並附說明（七 phase、三 gate、`qualityLoops` key 規則、`tickets` 鏡像、`fallbacks[]`、`escalations[]`、`branch`）。
3. **寫入時機**：建立單位時初始化；phase 狀態變化；gate 核准與撤銷（waterfall 退回時）；每輪迴圈完成；票證 frontmatter 異動的鏡像同步（Q32：讀到異動後同步）；FB／ESC 發生時的原子雙寫。
4. **單一寫入者**：只有驅動流程的主 session 寫入，子代理一律不寫。
5. **寫入方式**：整份讀出→修改→整份覆寫，寫入前重新讀取最新內容（Build 多票並行時尤其重要）。

### 2. `sdd-guide.md`

內文必須涵蓋（承襲原規格，不變）：

1. **EARS 句型（Q7）**：`WHEN <事件/條件> THE SYSTEM SHALL <預期行為>`，每條附編號 `<主編號>.<子編號>`。
2. **Delta spec 語法（Q8）**：`## ADDED / MODIFIED / REMOVED Requirements` 三區塊；greenfield 只寫 ADDED，不寫空區塊。
3. **需求編號回鏈（Q7）**：票證 frontmatter `requirementRefs: ["1.1", ...]` 與 `state.json` 鏡像欄位同名；每張票證至少一條；測試檔內以註解標註對應編號。
4. **合併進主 spec 的規則（Wrap）**：ADDED 附加（無檔則新建）、MODIFIED 依編號整條覆寫、REMOVED 依編號刪除；同一領域內編號不重複；領域切分由專案自訂（Q24）。
5. **審查核對項**：句型正確、編號連續無衝突、ADDED/MODIFIED/REMOVED 分類與主 spec 現況屬實。

### 3. `tdd-guide.md`

內文必須涵蓋：

1. **紅綠鐵律（Q9）**：TDD phase 產出的測試必須是可執行真測試碼，作者實際執行確認紅燈（因功能未實作而失敗）；審查者獨立重跑確認。**退回重做輪的例外**：waterfall 退回 TDD 後，紅燈判準只適用於**本輪新增或修改的測試案例**——`draft` 票證中未修改的既有案例（實作已合併者）維持綠燈是預期；`merged`／`ready`／靜置票證與純票證資料修正（測試檔不動）不適用紅燈判準，改核對合約完整性（測試檔未被未授權修改）與相依／編號一致性。**補測試覆蓋情境**：新增／修改的案例若因既有實作已滿足而直接綠燈，以**可失敗性證據**替代紅燈——擾動**只在拋棄式副本中執行、正式工作樹不動**：副本內擾動相關實作 → 案例轉紅 → 清理副本 → 正式樹確認綠燈；作者附執行紀錄，審查者於自建副本獨立重現，並以驗證前記錄的基準比對確認正式樹**相較驗證前無新增改動**（待審的未 commit 測試與票證變更原樣保留，不要求乾淨）、自建副本已清理（spec/09 §2–§3、spec/03 唯讀契約適用範圍）。
2. **測試合約（Q10，起點依 R2 改版）**：**TDD 品質迴圈通過後**，票證測試檔即為合約。Build 的 `worker` 不得修改；發現測試疑似有誤時停止並回報標示，由主 session 依 waterfall 規則（R3）**自動退回 TDD** 修訂測試（受影響票證重置 `draft`、重過 TDD 迴圈），不再是 ESC 上報。審查者以 `git diff` 覆核測試檔未被修改，被修改一律判 `targetPhase: "tdd"`。
3. **偷跳話術反駁表**：逐字承襲原版十條（「這個測試太簡單，不用真的跑」…「審查者應該可以理解我的意圖，不用逐字核對」），僅將角色名替換為 worker／reviewer、phase 名替換為 TDD／Build。
4. **Build 角色職責邊界**：只讓已確認紅燈的測試轉綠，不重新驗證「曾經紅燈」；轉綠後 worktree 內 commit 一次（Q34）。

### 4. `dispatch.md`（原 `parallel-dispatch`＋`using-worktree` 合併）

內文必須涵蓋：

**平行派工通則**：

1. 輸出落地檔案、prompt 只傳路徑；子代理只回「結論摘要＋檔案路徑清單」（research 04）。
2. 平行度依複雜度分級：單一問題 1 個；Review 固定 3 lens；多子項目依「調查範圍互不重疊」拆分。
3. 20 並行上限與分批（research 02 §3.1）。
4. 禁止巢狀派工：子代理不得再派子代理；審查獨立性由主 session 一層達成。
5. 平行審查互不可見：派工 prompt 不得夾帶其他審查者的初步看法。

**Worktree 生命週期（Build）**：

6. **建立（R12，research 12／13）**：主 session 自行 `git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit-name>`。以分支名指定來源，故不存在任何使用者設定型的前置條件——Build 不向使用者要求設定。
7. **索引隔離（R12，research 13 §3）**：`.agent-flow/.gitignore` 必須含 `worktrees/`，於建立 `.agent-flow/` 時寫入；缺這一行時 `git add -A` 會把 worktree 當 embedded git repository 加入索引。此檔在 agent-flow 自己的目錄內，不動使用者的專案設定。
8. **派工方式（R12）**：普通派工，**不帶** `isolation` 參數；角色簡報額外傳入 worktree 的**絕對路徑**並要求先 `cd` 進去。子代理各有獨立 shell，平行票證互不干擾。
9. **續談規則（research 07 Test A、research 13 §2）**：審查退回修正**首選**由主 session 親自 `SendMessage` 續談該 `agentId`（保留該 agent 已建立的理解）；不可委派中介子代理發起續談（完成通知只回主 session）。原 agent 不可定址時，改派全新子代理進**同一個 worktree 路徑**，不遺失任何工作（worktree 生命週期由主 session 持有）。無論哪種方式，同一張票證都不得建立第二個 worktree。
10. **波次排程**：計算 `dependsOn` 全部 `merged` 的票證集合，先建立該波全部 worktree，再同一輪回應一次發出整波；完成合併後再算下一波。
10. **合併後立即清理**：`git worktree remove`（必要時先 `unlock`），不依賴自動清理；Build 與 Review 不共用 worktree。

### 5. `quality-loop.md`（R3 改版核心）

內文必須涵蓋：

1. **兩級迴圈**：標準迴圈——Explore／Prototype／Spec／TDD／Build（逐票證），單一 `reviewer`，上限 3 輪；重型迴圈——僅 Review，3 lens 平行＋triage，上限 5 輪（Q29）。
2. **審查程序**：審查者收到產物路徑後獨立判斷，輸出下方 JSON 契約；主 session 依 `verdict` 與 `findings[].targetPhase` 路由。
3. **Waterfall 路由（R3，取代舊 rootCause 二分法）**：路由**只由 blocking finding 驅動**；non-blocking finding 不影響路由，隨 in-phase 修訂順帶處理或留待承諾點知情呈現。
   - blocking findings 的 `targetPhase` 全部為當前 phase：in-phase 退回原作者修正（Build 用 `SendMessage` 續談；其餘 phase 重新派工附全部 findings，含 non-blocking），輪數遞增。
   - 任一 blocking finding 的 `targetPhase` 為較早 phase：**自動退回**至其中**最早**的 phase——主 session 執行 `spec/05-orchestrate.md` §4.5 的退回程序（FB 留痕、撤銷、重做、重新核准、依序重走），不徵求使用者同意、不上報；其餘 blocking finding 由下游重走自然涵蓋。
   - 輪數達上限（標準 3、重型 5）：ESC（`rootCause: "round-limit"`）。
   - 同一退回目標累計達 3 次：不執行第 3 次退回，ESC（`rootCause: "fallback-limit"`）。
4. **測試合約特例**：測試檔被修改、或測試本身被判定有誤——一律 `targetPhase: "tdd"`，不當作當前 phase 的實作問題。
5. **首 phase 特例**：Explore 是第一個 phase，其 findings 的 `targetPhase` 恆為 `"explore"`（無更早 phase 可退）。
6. **審查者輸出 JSON 契約**：

   **標準迴圈**輸出：

   ```json
   {
     "schemaVersion": 2,
     "phase": "tdd",
     "unit": "2026-09-10-auth",
     "target": { "artifact": "changes/2026-09-10-auth/tickets/", "ticketId": null },
     "round": 2,
     "maxRounds": 3,
     "verdict": "reject",
     "findings": [
       {
         "id": "F1",
         "severity": "blocking",
         "targetPhase": "tdd",
         "location": "changes/2026-09-10-auth/tickets/TICKET-002.md",
         "description": "Test asserts against a mock that is never configured.",
         "evidence": "Ran `npm test TICKET-002.spec.ts`; failure is a TypeError, not the expected assertion failure."
       }
     ]
   }
   ```

   - `verdict`：`"pass" | "reject"`。**`reject` 若且唯若存在至少一條 blocking finding**——僅有 non-blocking finding 時必須輸出 `"pass"`（findings 照列，供修訂參考與承諾點知情），保證主 session 的路由分支（規則 3）恆有唯一適用項。
   - `severity`：`"blocking" | "non-blocking"`（承襲二元詞彙）。
   - `targetPhase`：七個 phase 名之一，只能是當前或更早的 phase；取代舊 `rootCause`／`escalation.targetArtifact` 欄位。

   **Review 重型迴圈**分兩層（結構承襲，欄位隨 R3 調整）：

   - (a) 三個 lens 的 raw finding：無 `verdict`、無 `targetPhase`，`severity` 改名 `reportedSeverity`（僅供參考，triage 不採信）。
   - (b) triage 裁定：沿用標準契約形狀，額外加 `findings[].sourceFindingIds`（格式 `"<lens>:<id>"`），`maxRounds` 固定 5。

7. **FB／ESC 留痕格式**：指向 `spec/02-state.md` §2.3 兩種模板；編號由主 session 遞增指派，審查者不編號。

### 6. `glossary.md`

內文必須涵蓋：

1. **DSL 解讀規則**（承襲 G1／G3）：程序區塊是依序指令、非可執行碼；`name(args)` 展開為 primitive 或共用程序；`if`／match 分支語法；`# INV-n` 註記；**封閉世界規則**（無分支適用即 `halt` 呈現）；散文管內容、區塊管控制流。
2. **Primitives**：`dispatch`（Agent tool 派工 `agent-flow:worker|reviewer`，prompt 依 spec/03 通則 4 的角色簡報契約）、`parallel`、`resume`（SendMessage 續談）、`read_state`／`write_state`、`gate`（承諾點呈現儀式）、`fallback(toPhase, reason)`（**新增**：waterfall 退回儀式，展開為 spec/05 §4.5 程序）、`escalate`、`ask`、`halt`、`commit`、`run`。
3. **變數**：`$unit`、`$ARGUMENTS`、`$round`／`$maxRounds`、`$verdict`／`$findings`、`$agent_id`／`$worktree_path`。
4. **共用程序**：`resolve_unit()`（工作單位判定三步驟：分支名吻合 → `changes/` 唯一子目錄 → 詢問使用者）、`create_unit($request)`（命名、目錄、`.agent-flow/.gitignore`、`state.json` 初始化、切分支）、`make_worktree(ticket)`／`drop_worktree(ticket)`（R12：建立與移除 ticket worktree；`worktree_preflight()` 隨 R12 廢止）、`standard_loop(key, author_briefing, reviewer_briefing, maxRounds=3)`（標準迴圈：dispatch worker → dispatch reviewer → 依 quality-loop 路由）。
5. **Invariant 清單 INV-1～INV-13**（隨 R1–R5 重編，全文定於 `references/glossary.md`，例外只能寫在 INV 自己的條文內）：

   | 編號 | 內容 | 溯源 |
   |---|---|---|
   | INV-1 | `state.json` 只由驅動流程的主 session 寫入 | Q21、Q30 |
   | INV-2 | 測試合約：TDD 迴圈通過後測試檔不可由 worker 修改；疑似有誤 → `targetPhase: "tdd"` 退回 | Q10、R2、R3 |
   | INV-3 | Build 進行中票證的退回修正只能 `SendMessage` 續談同一 `agentId`（重新派工＝全新 worktree）。例外：全量 waterfall 退回撤銷 Build 後的重走（worktree 已移除、票證轉 `ready`，spec/05 §4.5 步驟 3(b)）與 Review 的修正派工（spec/11 §4），皆為全新派工、不適用續談 | research 07 Test A、R3 |
   | INV-4 | 子代理並行上限 20，超過分批 | research 02 §3.1 |
   | INV-5 | 迴圈輪數上限：標準 3、Review 5（`qualityLoops.review.rounds` 跨 waterfall 退回保留，不因撤銷歸零）；超限 → ESC（`round-limit`） | Q4、Q29 |
   | INV-6 | Waterfall 退回：blocking finding 的 `targetPhase` 較早 → 自動退回最早目標 phase 重做；下游 phase 與 gate 依 spec/05 §4.5 撤銷（Build→TDD 為局部退回，未受影響票證保留）、依序重走；同一退回目標累計 3 次 → ESC（`fallback-limit`） | R3 |
   | INV-7 | 使用者於承諾點的退回不計入迴圈輪數 | 承襲 |
   | INV-8 | 承諾點三個：Explore／Spec／Review；被撤銷的承諾點重做後必須重新核准 | R2、R3 |
   | INV-9 | Wrap 執行—驗證：任何一步失敗即 ESC（`wrap-failure`），不重試、不自動回退 | Q25、S12 |
   | INV-10 | 審查一律由主 session 對 `reviewer` 的獨立派工完成；子代理不巢狀派工；平行審查互不可見；triage 不採信自報嚴重度 | DESIGN §4、research 04 |
   | INV-11 | 單獨呼叫 phase skill：前置未滿足即停止提示；完成後不自動接續 | Q2、S8、S9 |
   | INV-12 | FB／ESC 留痕為 markdown＋`state.json` 原子雙寫 | Q31、R3 |
   | INV-13 | ticket worktree 由主 session 以 `git worktree add` 自建，一律以分支名自 `flow/<unit>` 分岔、一律放 `.agent-flow/worktrees/<ticket-id>`、合併後一律移除；不使用 Agent tool 的 `isolation` 參數；`.agent-flow/.gitignore` 須含 `worktrees/` | research 12、research 13、R12 |

## 待對齊

無。六份 reference 中，`state-management`／`sdd-guide`／`tdd-guide` 為內容承襲（僅測試合約起點依 R2 改版）；`dispatch` 是兩份既有文件的機械合併；`quality-loop` 與 `glossary` 的改版內容全部是 R3／R4／R5 的直接推導。
