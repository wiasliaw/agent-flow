# agent-flow 設計文件

> 本文件依 PROMPT.md 的流程產出。開頭的「訪談記錄」是全文依據：
> 之後任何設計內容都必須能追溯到其中某一條回答（標記為 Q1、Q2⋯）。
> 設計本文在訪談完成後撰寫（第 3 步）。

## 訪談記錄（逐字）

研究依據：`research/`（01–06 與 README）。訪談中引用研究結果時標記來源報告。

<!-- 問答依序附加於下，格式：
### Qn：題目
**研究背景**（若有）：…
**選項**：…（含建議）
**回答**：使用者選擇與補充原話
-->

### Q1：agent-flow 主要用在什麼情境？全新專案（greenfield）還是既有專案（brownfield）？

**研究背景**：Spec Kit 從零生成整套規格，被第三方批評「容易變成重新發明瀑布」、
偏向全新專案（03）；OpenSpec 用變更提案（delta spec）驅動，天生適合既有專案
持續演進（03）。影響 Spec phase 產物形態與狀態目錄設計。

**選項**：
1. 兩者皆支援（建議）— 八 phase 走同一流程，Explore 本來就會讀既有碼；代價是
   Spec 產物要同時考慮完整 spec 與變更 delta 兩種形態。
2. 既有專案為主 — 像 OpenSpec 以變更提案驅動，greenfield 之後擴充。
3. 全新專案為主 — 像 Spec Kit 從零建立完整規格。

**回答**：兩者皆支援（建議）。

### Q2：八個 phase 怎麼觸發與組合？

**研究背景**：Spec Kit 每步驟一個指令、使用者手動接續（03）；Kiro 單一流程
自動推進、每階段停下等核准（03）；PROMPT 定位是「可組合的工作流程」。

**選項**：
1. 每 phase 一指令 + 總控指令（建議）— 八個獨立指令可單用可組合，總控指令
   從任一 phase 開始自動接續。
2. 單一指令一條龍 — 只有一個 /agent-flow，內部依序走八 phase。
3. 每 phase 一指令，純手動接續 — 像 Spec Kit，不做自動接續。

**回答**：「單個 phase 走 3。自動接續由 orchestration 負責」
（解讀：八個 phase 指令各自獨立、本身不自動接續；自動接續是 orchestration
層的責任，phase 指令內不含接續邏輯。）

### Q3：orchestration 自動接續時，哪些 phase 結束必須停下來等使用者確認？

**研究背景**：Kiro 標準流程每階段人工核准，其 Quick Spec 拿掉關卡被視為坑
（03）；OpenSpec 只設兩個不阻斷確認點（03）；Spec Kit 用 checklist gate
（03）。PROMPT 已定 Wrap 全自動、不留人工步驟。

**選項**：
1. 停在承諾點（建議）— Discuss、Spec、Ticket、Review 四個 phase 結束後停；
   Explore、Prototype、Dev 自動過，Wrap 照 PROMPT 全自動。
2. 每 phase 都停 — 七個 phase 結束都等確認（Wrap 除外）。
3. 最少關卡 — 只停 Spec 與 Review 之後。
4. 全自動不停 — 品質迴圈把關，一路到底。

**回答**：停在承諾點（建議）。

### Q4：每個 phase 結束的品質檢查迴圈怎麼運作？

**研究背景**：hook 閘門擋下後只會同一子代理重試，「獨立於作者」只能靠
orchestrator 另派審查子代理（06 實測）。BMAD：多視角平行審查＋獨立 triage＋
根因分流，上限 5 輪（04）；Superpowers：上限 5 輪，前三輪原 agent 續修、
後兩輪換更強模型全新 agent（04）。多 agent token 成本為單輪對話 4–15 倍（04）。

**選項**：
1. 分級迴圈（建議）— 一般 phase：單一獨立審查者 → 退回原作者修 → 上限 3 輪
   後上報使用者；Review phase 用重型：多視角平行審查＋獨立 triage（BMAD 式）。
2. 全部 BMAD 式 — 每 phase 都多視角＋triage＋根因分流，上限 5 輪。
3. 全部簡單迴圈 — 每 phase（含 Review）單一審查者，上限 3 輪。
4. 簡單迴圈＋升級 — 單一審查者，後段換更強模型全新 agent，上限 5 輪。

**回答**：分級迴圈（建議）。

### Q5：審查發現根因在更早 phase 的產物（例如 Dev 時發現 spec 錯）時，怎麼處理？

**研究背景**：BMAD triage 按根因分流 — patch（實作補丁）／bad_spec（回頭改
spec 重新生成）／intent_gap（上報人類）／defer（記錄延後）（04）。與 Q3 承諾點
的張力：spec 與票證是使用者核准過的產物。

**選項**：
1. 上報裁決（建議）— 根因在已核准產物時停下來讓使用者裁決；核准過的東西
   agent 不自行推翻；純實作問題仍由迴圈自動修。
2. 自動回頭改（BMAD 式）— 自動改前面 phase 產物並重新生成，事後報告。
3. 記錄後繼續（defer）— 記成 issue 繼續走，留給 Review 一併處理。

**回答**：上報裁決（建議）。

### Q6：工作單位的產物與狀態檔放在 repo 的什麼位置？

**研究背景**：三個 SDD 案例一致「檔案落地進版控」（03）；平台無官方狀態格式、
transcript 不穩定（02）；Anthropic 與 Superpowers 收斂出「產出落地檔案系統、
只傳輕量引用」（04）。

**選項**：
1. .agent-flow/ 下按工作單位分目錄（建議）— 如 .agent-flow/2026-09-04-auth/，
   內含各 phase 產物與狀態檔；Wrap 時歸檔到 archive/（OpenSpec 式）。
2. specs/ 可見目錄（Spec Kit 式）— specs/<功能名>/，規格視為專案正式文件。
3. 每專案自訂路徑 — 設定檔指定，預設值之一。

**回答**：.agent-flow/ 下按單位分目錄（建議）。

### Q7：spec 裡的需求用什麼格式寫？怎麼追溯到票證與測試？

**研究背景**：traceability 精細度 Kiro > Spec Kit > OpenSpec（03）。Kiro 用
EARS（WHEN ... THE SYSTEM SHALL ...）讓需求天然可測試、任務行內
`_Requirements: 1.1` 回鏈（03，第三方資料）；Spec Kit 用 FR-### 編號＋覆蓋率表；
OpenSpec 靠人工對應。

**選項**：
1. EARS 格式＋編號回鏈（建議）— 需求用 WHEN...SHALL... 句型＋編號；票證與
   測試標記對應需求編號。
2. 自由格式＋編號 — FR-### 編號、不強制句型。
3. 自由格式不編號 — 人工對應。

**回答**：EARS 格式＋編號回鏈（建議）。

### Q8：每個工作單位的 spec 是「變更 delta」還是「完整 spec」？

**研究背景**：OpenSpec 每變更產 delta spec（ADDED/MODIFIED/REMOVED），歸檔時
合併進主 spec、移入 archive/，主 spec 永遠反映現況（03）；Spec Kit 與 Kiro
每功能維護完整 spec（03）。Q6 已選 OpenSpec 式歸檔目錄。

**選項**：
1. Delta 為主＋主 spec 合併（建議）— 每單位寫 delta，Wrap 歸檔時合併進主
   spec；greenfield 第一個單位的 delta 就是全部新增，兩情境單一形態。
2. 完整 spec 每次編修 — Spec Kit／Kiro 式。
3. 兩態並存 — greenfield 完整、brownfield delta，維護兩套。

**回答**：Delta 為主＋主 spec 合併（建議）。

### Q9：Ticket 階段隨票證產出的測試，要到什麼程度？

**研究背景**：PROMPT 已定「測試先於實作，在 Ticket 階段隨票證產出」；
Superpowers TDD 鐵律「沒有先失敗的測試不准寫實作，違反就刪除重寫」＋十條
偷跳話術反駁表，是先行案例中防呆最強的（04）。

**選項**：
1. 可執行的失敗測試（建議）— Ticket 就寫真測試碼、執行必須紅燈；Dev 完成
   定義是轉綠。代價：Ticket 較重、需要專案已有可跑的測試環境。
2. 測試骨架＋案例清單 — Dev 先補完測試讓它失敗再實作。
3. 只列驗收條件 — 測試全在 Dev 寫（偏離 PROMPT 定義）。

**回答**：可執行的失敗測試（建議）。

### Q10：Dev 階段的實作者可以改 Ticket 產出的測試嗎？

**研究背景**：Superpowers 把「測試好像不對」列為偷跳話術之一，處理是升級上報
而非改測試（04）。Q5 已定「已核准產物 agent 不自行推翻」，Q3 已定 Ticket 是
承諾點。

**選項**：
1. 不可改，錯了上報（建議）— 測試是合約；實作者認為測試錯誤時走 Q5 上報
   裁決流程。
2. 可改但需審查者核可 — 獨立審查者判斷；agent 可能合謀削弱測試。
3. 可自由改 — 靠 Review 事後把關；是 agent 偷跳 TDD 的主要破口。

**回答**：不可改，錯了上報（建議）。

### Q11：Dev 階段的票證用什麼機制平行執行？

**研究背景**：實測（06）：isolation: worktree 每次呼叫全新 worktree、無變更
自動清理；headless --worktree 平行不互撞但不自動清理。巢狀 3 層、並行上限 20
（02）。Anthropic 平行度依複雜度分級（04）。

**選項**：
1. 同 session 子代理＋worktree 隔離（建議）— Agent tool 平行派票，每票一個
   isolation: worktree 子代理；平行數依票證相依圖決定。
2. Headless worker 程序 — 自行管清理與權限，靜默失敗風險高。
3. 依票量自動選 — 兩套機制都要維護。
4. 循序不平行 — 放棄 PROMPT「平行執行」定義。

**回答**：同 session 子代理＋worktree 隔離（建議）。

### Q12：分支結構怎麼設計？

**研究背景**：先行案例產物皆進版控但分支策略各異；BMAD 自動 commit 不 push
（04）。Q3 定了 Review 後承諾點、Q6 定了歸檔目錄。

**選項**：
1. 單位分支＋票證分支兩層（建議）— 每工作單位一條分支（flow/<單位名>），
   票證 worktree 分支從它切出、完成合回；Review 審單位分支整體 diff，Wrap
   合回主幹。主幹隨時乾淨。
2. 票證分支直接對主幹 — 少一層，但 Review 無單一整體 diff 可審。
3. 偵測／尊重專案慣例 — 彈性高但行為難預測。

**回答**：單位分支＋票證分支兩層（建議）。

### Q13：Wrap 全自動收尾做到哪？合併後要不要 push？

**研究背景**：先行案例無全自動合併範本、判準自定（04）；headless 權限被拒是
乾淨拒絕、流程照走，風險型態是靜默失敗，動作要逐一驗證（06）；04 建議借
Superpowers「裁決留痕」讓全自動可稽核。

**選項**：
1. 本地合併、不 push（建議）— 條件：Review 關卡過＋全測試綠。合入主幹、
   delta 合併進主 spec 並歸檔、清 worktree 與分支；每動作驗證成功並留痕。
   push 留給使用者。
2. 合併並 push — 遠端是共享狀態，誤合影響擴大。
3. 準備好留人工確認 — 偏離 PROMPT「不留人工步驟」。

**回答**：本地合併、不 push（建議）。

### Q14：各角色子代理的模型怎麼配？

**研究背景**：多 agent token 成本 4–15 倍（04）；agent frontmatter 可固定
model，是主要成本控制手段（02）；Superpowers 用便宜優先＋卡關升級（04）。

**選項**：
1. 分角色配模型（建議）— 審查者與判斷型角色高階或繼承主 session；實作與
   研究中階（sonnet）；機械性動作輕量（haiku）。
2. 全部繼承主 session — 品質齊一、成本最高。
3. 便宜優先＋升級 — 前幾輪品質不穩。
4. 使用者設定檔控制 — 多一層複雜度。

**回答**：分角色配模型（建議）。

### Q15：orchestrator 角色怎麼實現？

**研究背景**：實測（05）：settings.json 的 agent 欄位會把主 session 換成指定
agent，可固化 orchestrator，但 tools 白名單漏 Agent tool 會失去派工能力；
另一路是總控 skill 引導主 session，不動設定。

**選項**：
1. 總控 skill 引導主 session（建議）— orchestration 是一個 skill（如 /flow），
   主 session 依劇本調度；最不侵入，約束靠文件紀律。
2. settings.json 固化 orchestrator agent — 角色穩固但接管整個主 session。
3. 兩者都提供 — 兩套行為都要測試維護。

**回答**：總控 skill 引導主 session（建議）。

### Q16：Discuss phase 的蘇格拉底提問用什麼形態進行？

**研究背景**：PROMPT 定義 Discuss 為蘇格拉底提問確認意圖。Kiro 直接生成
requirements 再讓人改；Spec Kit 用 /clarify 列問題清單逐一問（03）。

**選項**：
1. 先發散後收斂（建議）— 前半自由對話探意圖（開放式提問），後半選項式
   逐項收斂，產出意圖摘要等使用者核准（Q3 承諾點）。
2. 全選項式一次一題 — 紀律最強、可追溯，但發散不足。
3. 自由對話為主 — 自然但可追溯性最弱。

**回答**：先發散後收斂（建議）。

### Q17：agent-flow 怎麼發佈與安裝？

**研究背景**：repo 已有使用者建立的 .claude-plugin/marketplace.json 與
plugin.json 骨架，即「repo 自帶 marketplace」形態；安裝範圍與命名規則
記錄在 01。

**選項**：
1. Repo 自帶 marketplace（建議）— 公開 GitHub repo，claude plugin
   marketplace add 後安裝；旅程文案以 user scope 為主情境。
2. 僅本機個人使用 — 本機路徑安裝。
3. 投稿官方／第三方 marketplace — 受對方規則約束。

**回答**：Repo 自帶 marketplace（建議）。

### Q18：Prototype 的實驗碼與證據各放哪？

**研究背景**：PROMPT 定義 Prototype 產出「問題、做法與證據；程式碼不進正式
產品」。本次研究第二波實驗的做法是碼留 /tmp、證據進 research/。

**選項**：
1. 碼在 /tmp，證據進單位目錄（建議）— 實驗碼不進版控（強制丟棄）；問題、
   做法、證據、結論寫進 .agent-flow/<單位>/prototype.md。
2. 碼與證據都進單位目錄 — 實驗碼放 .agent-flow/<單位>/prototype/ 進版控，
   可回查重跑；需靠 Wrap 歸檔時的清理紀律。
3. 都不留，只留結論 — 失去證據可追溯。

**回答**：碼與證據都進單位目錄。（未採建議選項；設計須配套 Wrap 階段對
prototype/ 的清理／歸檔紀律，並確保實驗碼不流入正式產品路徑。）

### Q19：進入設計前，還有沒有想主動加進設計的需求或限制？

**選項**：1. 沒有，訪談結束；2. 有補充（Other 欄位填寫）。

**回答**：沒有，訪談結束。

### Q20：總控 skill 的名稱？（訪談結束後補充裁決）

**回答**：「總控 skill 名稱 -> orchestrate」。

### Q21：工作單位狀態檔的格式？（訪談結束後補充裁決）

**回答**：「狀態檔格式按照你推薦即可」。
（採納的推薦：每個工作單位一個 state.json，含 schema 版本欄位；理由：
orchestrate 與 hooks 需機械式讀寫 phase 進度、關卡狀態、迴圈輪數、票證
狀態，JSON 無歧義；人讀內容在各 markdown 產物，狀態檔純粹給機器。）

### Q22：進行中工作單位的目錄名？（訪談結束後補充裁決）

**選項**：1. changes/（建議，與 Q8 delta 模型及 OpenSpec 慣例一致）；
2. units/；3. 平鋪不分層。

**回答**：changes/（建議）。

### 設計稽核後補充裁決（Q23–Q39）

設計本文完成後經獨立稽核與補充實驗（research 07），以下為據此進行的
補充裁決，記錄形式從簡（題目／回答），效力與 Q1–Q22 相同。

**Q23** orchestrate 啟動發現專案缺必要設定（如 worktree baseRef）怎麼處理？
→「檢查後徵同意寫入」：檢查專案 .claude/settings.json，缺少時提示並徵求
同意後代寫；旅程補這一步。

**Q24** 主 spec 怎麼組織？→「依領域分域」：.agent-flow/specs/<domain>/spec.md，
切分粒度由專案自訂。

**Q25** Wrap 品質迴圈形態？→「執行—驗證、失敗即上報」：逐動作獨立驗證，
失敗不重試直接上報。

**Q26** 訪談前建立的 plugin.json／marketplace.json 骨架與設計不一致怎麼辦？
→「規格對齊時更新骨架」。（後由 Q37–Q39 修正範圍：骨架的
skills/external／skills/internal 切分保留，nine phases 與 Workflow tool
敘述仍更新。）

**Q27** 10 項瑣事級待裁決怎麼處理？→「逐項問我」。

**Q28** 工作單位命名？→「YYYY-MM-DD-slug（建議）」。
**Q29** Review 重型迴圈輪數上限？→「5 輪（建議）」。
**Q30** state.json 完整 schema？→「照提案 schema（建議）」。
**Q31** decisions.md 的 ESC 留痕模板？→「照提案模板（建議）」。
**Q32** 票證相依記法？→「票證 frontmatter 為準，state.json 同步（建議）」。
**Q33** 15 角色模型映射表？→「照提案表（建議）」。
**Q34** commit 顆粒度？→「照提案（建議）」（phase 通過即 commit、一票一
commit 不 squash、Wrap 保留逐票歷史）。
**Q35** Prototype 清理紀律？→「照提案（建議）」（碼留單位目錄不入正式路徑、
Review 查無依賴、隨歸檔保留）。
**Q36** agent 命名衝突啟動檢查？→「不檢查」（未採建議選項；設計移除啟動
掃描，改在已知取捨記為使用者自行注意的風險）。

**Q37** 九個 skill 英文文案照提案採用？→ 未選選項，原話：「這是 external
skill，還有 internal skill 沒有設計」；後續選擇「連同 internal 一起重寫」。

**Q38** internal skill 怎麼補進設計？→「你直接指定清單」，使用者原話：
「internal skill／state-management: 狀態外部化指引／sdd-guide: SDD 指引／
tdd-guide: TDD 指引／using-worktree: 指引 orchestrator 如何使用 worktree
平行執行／不妥可以反駁」。

**Q39** 反駁與釐清後定案：平行派工 skill 怎麼切？→ 原話「拆兩個，兩種平行
方式各寫一個」（唯讀平行與 worktree 寫檔平行各一個 skill）；quality-loop
（品質迴圈協定）加入清單？→「加（建議）」。internal skill 定案六個：
state-management、sdd-guide、tdd-guide、parallel-dispatch（唯讀平行＋共用
派工通則）、using-worktree（worktree 寫檔平行）、quality-loop。

**Q40** （delta 稽核指出 Q37 後 external 文案追溯鏈未補）15 句 skill 文案
定案：external 9 句怎麼處理？→「維持原文」（審視後確認不需重寫，實作階段
可微調字句）；internal 6 句（Load this when/before … 寫法，導向何時載入）？
→「核准」。

---

（訪談結束。以上 Q1–Q40 為設計本文的全文依據；設計中任何內容都必須能
追溯到某一條回答或 PROMPT.md 原文。）

---

## 設計本文

> 本節依訪談記錄（Q1–Q39）、`PROMPT.md` 與 `research/01`–`07` 撰寫。每個決策
> 標註來源：訪談回答標「（Qn）」，`PROMPT.md` 原文標「（PROMPT）」，研究裁決
> 標「（research 0X）」。原本第 10 節列出的 13 項【提案】已由設計稽核與
> 補充實驗（research 07）後的 Q23–Q39 全數裁決，逐項改寫進本文對應章節、
> 不再另外標記【提案】；第 10 節「殘餘待驗證事項」只保留兩項性質是待實測、
> 不是使用者裁決的平台查證（Q37–Q39 的 internal skills 設計依賴項）。

### 1. 目標與非目標

**目標**

- 把規格驅動開發（Spec-Driven Development, SDD）與測試驅動開發（Test-Driven
  Development, TDD）結合成可組合的八 phase 工作流程：Discuss／Explore／
  Prototype／Spec／Ticket／Dev／Review／Wrap（PROMPT）。
- 兩種情境都支援：全新專案（greenfield）與既有專案（brownfield），八 phase 走
  同一流程（Q1）。
- 規格驅動整個流程；測試先於實作，在 Ticket 階段隨票證產出（PROMPT）。
- 每個 phase 結束由獨立於作者的角色跑一次品質檢查迴圈（PROMPT、Q4）。
- 以多 agent 協作運作：主 session 只負責調度、決策與記錄；撰寫與檢查派給不同
  子 agent 分工執行，盡量把長時間的工作推出主 session（PROMPT）。
- 在四個承諾點（Discuss、Spec、Ticket、Review）停下來交還控制權給使用者
  （Q3）；Explore、Prototype、Dev 自動接續；Wrap 全自動、不留人工步驟
  （PROMPT、Q13）。
- 以 plugin 形式散布，repo 自帶 marketplace，透過 `claude plugin marketplace
  add` 安裝（Q17）。

**非目標**

- **不 push 遠端**：Wrap 只做本地合併，push 留給使用者自行決定（Q13）。
- **不接管主 session 身分**：orchestrator 是總控 skill 引導主 session 的行為，
  不透過 plugin 根目錄 `settings.json` 的 `agent` 欄位把主 session 換成單一
  agent 人格（Q15）。
- **不做「一路到底不檢查」**：即使是自動接續或全自動的 phase（Explore、
  Prototype、Dev、Wrap），仍各自跑品質迴圈或逐動作驗證（Q4 選項 4 未採納；
  Q13）。
- **不允許 agent 自行推翻已核准產物**：根因在已核准（已通過承諾點）的產物時
  一律上報使用者裁決，不自動回頭改寫（Q5、Q10）。
- **不提供「Quick 模式跳過關卡」**：不同於 Kiro 的 Quick Spec（research 03）；
  訪談中每個涉及關卡數量的問題（Q3、Q4）都沒有選擇「無關卡」或「最少關卡」
  選項。單獨呼叫某一 phase（Q2）不會因此免除該 phase 自己的品質迴圈。
- **Dev phase 不用 headless worker 程序或 Dynamic Workflow 腳本作主要平行機制**：
  採用同 session 子代理＋worktree 隔離（Q11 選項 1；選項 2「headless worker
  程序」與選項 3「兩套並存」皆未採納）。
- **不維護「每功能一份完整 spec、每次重寫」的模型**：採用 delta spec 為主、
  歸檔時合併進主 spec 的模型（Q8；Kiro／Spec Kit 式的完整 spec 模型未採納，
  research 03）。
- **不支援任意自訂狀態目錄路徑**：固定為 `.agent-flow/`（Q6 選項 1；選項 3
  「每專案自訂路徑」未採納）。

---

### 2. 架構總覽

**orchestrator＝主 session，由 `orchestrate` skill 引導（Q15、Q20）**。名稱取自
訪談補充裁決（Q20：「總控 skill 名稱 -> orchestrate」），呼叫方式依 plugin skill
命名規則為 `/agent-flow:orchestrate`（research 01 §3.3）。`orchestrate` 不是被
`context: fork` 出去的獨立子代理，而是載入主 session 自身 context 的一份腳本
（research 01 §2.2.1：預設情況下 skill 內容就是驅動「目前這個 session」的
指示，除非明確宣告 `context: fork`）——這一點對八個 phase skill 同樣成立：無論
是被 `orchestrate` 依序驅動，還是使用者直接呼叫某一個 phase skill 單獨執行
（Q2），實際執行 phase 邏輯（派工、收結果、判斷是否重試、是否停下等使用者
核准）的都是**目前呼叫它的那個 session 本身**，不是另一個被 fork 出去的 agent。

**為什麼 orchestrator 不用 plugin `settings.json` 的 `agent` 欄位固化（Q15）**：
research 05 實驗三證實這個欄位確實能把主 thread 換成指定 agent 的
system prompt 與工具集，但若該 agent frontmatter 明確列出 `tools:` 白名單且
未含 Agent tool，主 session 會直接失去派工能力；訪談選擇「總控 skill 引導主
session」（Q15 選項 1）而非此機制（選項 2），代價是「約束靠文件紀律」而非
平台強制——但換來的是主 session 隨時保有完整工具集與派工能力，不受某個
agent 定義檔案的 `tools:` 白名單牽制。

**主 session 唯一的例外——Discuss 的對話環節**：PROMPT 要求主 session「只負責
調度、決策與記錄」，但 Discuss phase 需要與使用者做多輪蘇格拉底式對話
（Q16：先發散後收斂）。子代理只回傳最終文字結果，中間過程對主對話隱藏，且
不具備在單次委派中與使用者即時來回問答的通道（推論自 research 02 §1.4、
§2.1——這兩份記載的是子代理的 context 隔離與結果回傳機制本身，並未直接寫出
「不能與使用者即時問答」這句結論，是本設計依其記載的平台機制反推得出，稽核
標記為低度發現）——因此這段對話**必須**由主 session 直接進行，這是
PROMPT「主 session 只負責調度」
原則下唯一的必要例外，且範圍嚴格限於「與使用者對話、產出摘要」本身；審查
這份摘要是否完整、有無矛盾，仍委派給獨立的 `intent-reviewer` 子代理（見第 3.1
節），維持「獨立於作者」的要求（PROMPT）。

**角色子代理分三類**（完整清單與模型指派見第 5 節）：

- **作者類**：`explorer`、`prototyper`、`spec-writer`、`ticket-writer`、
  `dev-worker`（每票證一個 instance）、`wrap-executor`。
- **審查類**（獨立於作者）：`intent-reviewer`、`explore-reviewer`、
  `prototype-reviewer`、`spec-reviewer`、`ticket-reviewer`、`dev-reviewer`
  （每票證一個 instance）、Review 專用的 `review-gap-hunter` /
  `review-edge-case-hunter` / `review-spec-compliance-auditor` /
  `review-triage`、`wrap-verifier`。
- **機械類**：`wrap-executor`、`wrap-verifier`（機械執行與驗證，模型輕量）。

**架構圖**：

```
                              User
                               │
                               │ /agent-flow:orchestrate  (or a single phase skill)
                               ▼
   ┌───────────────────────────────────────────────────────────────┐
   │                  Main Session = Orchestrator                    │
   │          guided by the `orchestrate` skill (Q15, Q20)           │
   │                                                                   │
   │   - runs in default context, never context:fork (research 01)   │
   │   - talks to the user directly only for Discuss dialogue (Q16)  │
   │   - reads/writes .agent-flow/changes/<unit>/state.json (Q21)    │
   │   - stops at 4 gates: Discuss / Spec / Ticket / Review (Q3);    │
   │     Explore / Prototype / Dev auto-continue; Wrap is fully      │
   │     automatic (PROMPT, Q13)                                      │
   │   - never writes phase artifacts itself (except Discuss         │
   │     dialogue); dispatches all writing/reviewing to subagents    │
   └───────┬──────────┬────────────┬─────────────┬──────────────────┘
           │          │            │             │
     /agent-flow: /agent-flow: /agent-flow:  ... /agent-flow:
       discuss      explore      prototype         wrap
       (8 independent phase skills, each invokable alone — Q2)
           │
           │ Agent tool, subagent_type = "agent-flow:<role>" (research 05)
           ▼
   ┌───────────────────────────────────────────────────────────────┐
   │    Author subagents               Reviewer subagents            │
   │    (produce artifacts)            (independent of author, Q4)   │
   │                                                                   │
   │    explorer, prototyper,          intent-reviewer,               │
   │    spec-writer, ticket-writer,    explore-reviewer, spec-reviewer,│
   │    dev-worker (×N tickets,        ticket-reviewer, dev-reviewer  │
   │      isolation: worktree)         (×N), review-panel (×3) +      │
   │    wrap-executor                  review-triage, wrap-verifier   │
   └───────────────────────────────────────────────────────────────┘
```

（各角色子代理與 `orchestrate` 自己另外可載入六個 internal skill 取得程序性
指引；這條路徑不經過上圖的 Agent tool 派工，而是子代理啟動時的 `skills:`
frontmatter 欄位 preload，或執行中主動呼叫 Skill tool，見下方。）

**Skills 分兩層：external／internal（Q37–Q39）**

設計稽核發現原始設計只定義了「使用者觸發」這一層 skill，沒有處理「子代理與
orchestrator 內部共用、彼此該遵守同一套規則」這個問題——例如任何一個要寫
delta spec 的角色，都得遵守同一份 EARS／ADDED-MODIFIED-REMOVED 格式規則；
與其把這份規則各自複製進每個 phase skill 或每個 agent 的 system prompt，
不如抽成一份共用指引、由需要的角色各自載入。訪談就此補充裁決（Q37 使用者
原話：「這是 external skill，還有 internal skill 沒有設計」；Q38：「你直接
指定清單」；Q39：反駁與釐清後定案），agent-flow 的 skill 因此分兩層：

- **External skills（9 個）**：`orchestrate` 加八個 phase skill（`discuss`／
  `explore`／`prototype`／`spec`／`ticket`／`dev`／`review`／`wrap`），使用者
  直接觸發（`/agent-flow:<name>`），內容是「這個 session 現在該做什麼」的
  劇本（第 3 節）。
- **Internal skills（6 個，Q38–Q39）**：子代理與 orchestrator 內部載入的
  程序性指引，使用者不直接觸發，解決的是「怎麼做」而非「現在做什麼」：

| Internal skill | 範圍界定 | 誰在何時載入 |
|---|---|---|
| `state-management` | `state.json` 讀寫規範：schema 版本檢查、欄位語意、寫入時機（第 6 節） | `orchestrate`（唯一寫入 state.json 者）；任何需要讀取工作單位進度的角色 |
| `sdd-guide` | EARS 契約、delta spec（ADDED/MODIFIED/REMOVED）語法、票證↔需求編號回鏈規則、Wrap 時合併進主 spec 的規則（第 3.4、6 節） | `spec-writer`／`spec-reviewer`／`ticket-writer`／`ticket-reviewer`；Wrap 的 `wrap-executor` |
| `tdd-guide` | 紅綠鐵律（測試須先紅燈才可實作）、Q10 測試合約（Dev 不可改測試，錯了上報）、防呆話術反駁表（借用 research 04 記載的 Superpowers 十條偷跳話術反駁） | `ticket-writer`／`ticket-reviewer`／`dev-worker`／`dev-reviewer` |
| `parallel-dispatch` | 唯讀平行派工的共用通則：輸出落地檔案傳輕量引用（第 5 節）、平行度依相依圖／複雜度分級、**單波超過 20 個並行上限時分批（research 02 §3.1）——這條是兩個派工 skill（`parallel-dispatch`／`using-worktree`）共通的通則，定義於此**、禁止子代理再往下巢狀派審查者 | 需要一次派出多個唯讀審查／研究子代理的角色：Review 的三個平行審查小組＋`review-triage`；各 phase 若需要多視角唯讀查核時 |
| `using-worktree` | worktree **寫檔**平行的規則：建立票證 worktree 前必須 checkout 到單位分支並設定 `baseRef: head`（research 07 Test B）、審查退回時用 `SendMessage` 續談同一個 `dev-worker`（research 07 Test A）、合併後 `git worktree remove` 清理（第 3.6、7 節）、**單波超過 20 個並行上限時分批——引用 `parallel-dispatch` 定義的通則，不重複定義** | 僅 `orchestrate`——Dev phase 的 worktree 建立、續談、合併、清理全部由主 session 親自執行，理由見第 3.6 節（續談完成通知只回主 session，不可經中介子代理） |
| `quality-loop` | 兩級迴圈（標準／重型）選用規則、審查程序、退回路由二分法（純實作問題／根因在已核准產物）、測試合約、超限上報、ESC 留痕格式與 state.json 同步、審查者輸出格式契約（第 4 節） | 每個 phase 的審查子代理（產出「通過／退回＋理由」的標準化格式）；`orchestrate` 讀取審查結果、判斷路由 |

**平台查證（research 01；查證結果與依據見第 10 節）**：(a) `skills/
external/`、`skills/internal/` 這種巢狀分組目錄，plugin.json 的 `skills`
陣列指到這種分組目錄是否受支援；(b) internal skill「使用者不可觸發、但
Claude／子代理仍可載入」該用哪個 frontmatter 欄位。兩項皆已在 research 01
查到明確依據，非待實測，詳見第 10 節。

---

### 3. 八個 Phase

以下每個 phase 列出：目的、進入條件、產物、品質迴圈形態、是否承諾點。

#### 3.1 Discuss

- **目的**：以蘇格拉底提問訪問談話者，確認使用者意圖（PROMPT）。形態為「先發散
  後收斂」（Q16）：前半自由對話探索意圖（開放式提問），後半換成選項式逐項
  收斂，最後產出意圖摘要。
- **進入條件**：使用者建立新工作單位或呼叫 `/agent-flow:discuss`；不依賴任何
  前一 phase 產物（流程起點）。
- **產物**：`changes/<unit>/discuss.md`（意圖摘要，含發散階段紀錄與收斂階段的
  選項與回答）。
- **執行方式**：對話環節由主 session 直接進行（見第 2 節理由）；審查委派給
  獨立的 `intent-reviewer` 子代理。
- **品質迴圈**：標準迴圈（Q4）——`intent-reviewer` 審查摘要是否完整、有無矛盾
  → 有問題則主 session 補問使用者、修訂摘要 → 上限 3 輪 → 仍未通過則列成
  待確認項目，隨摘要一併交給使用者裁決。
- **承諾點**：是（Q3）。使用者核准後才進入 Explore。

#### 3.2 Explore

- **目的**：內外並查，確認實作可行性（PROMPT）。因兩種情境皆支援（Q1），
  Explore 本來就需要讀既有程式碼（brownfield）或調查外部技術選項
  （greenfield）。
- **進入條件**：Discuss 承諾點已核准。
- **產物**：`changes/<unit>/explore.md`（內部程式碼調查發現＋外部技術/文件
  調查發現，含未解決的技術疑問清單，供 Prototype 判斷是否需要進場）。
- **品質迴圈**：標準迴圈（Q4）——`explorer` 撰寫 → `explore-reviewer` 獨立
  審查（有無明顯遺漏、結論是否有佐證）→ 退回 `explorer` 修 → 上限 3 輪 →
  上報。
- **承諾點**：否（Q3）。自動接續。

#### 3.3 Prototype

- **目的**：用丟棄式程式碼做實驗回答技術疑問，留下問題、做法與證據；程式碼
  不進正式產品（PROMPT）。
- **進入條件**：Explore 產出中列有未解決的技術疑問；若無疑問可略過此 phase
  （PROMPT 對 Prototype 的定義本身就是「回答技術疑問」，沒有疑問就沒有存在
  理由；Q2 已確立每個 phase 可單獨呼叫、不強制全部經過）。
- **產物**：`changes/<unit>/prototype.md`（問題、做法、證據、結論，PROMPT
  原文要求）；`changes/<unit>/prototype/`（實驗碼本身）。訪談在此**未採納
  建議選項**——Q18 選擇「碼與證據都進單位目錄」（進版控），而非「碼在
  `/tmp`」；代價是需要配套清理／歸檔紀律，見第 8 節。
- **品質迴圈**：標準迴圈（Q4）——`prototyper` 撰寫 → `prototype-reviewer`
  審查問題是否真的被回答、證據是否可信 → 上限 3 輪 → 上報。
- **承諾點**：否（Q3）。自動接續。

#### 3.4 Spec

- **目的**：撰寫 SDD 規格（PROMPT）。
- **進入條件**：Explore（與可能的 Prototype）產出可用。
- **產物**：`changes/<unit>/spec-delta.md`——delta 為主的形態（Q8）：用
  `## ADDED/MODIFIED/REMOVED Requirements` 區塊描述相對現況的變化（借用
  OpenSpec 語法，research 03），而非每次重寫整份 spec；需求本文採 EARS 格式
  （`WHEN ... THE SYSTEM SHALL ...`）並附編號，供票證與測試回鏈（Q7）。
  Greenfield 情境下，第一個工作單位的 delta 就是全部新增，兩種情境共用同一種
  產物形態（Q8）。
- **品質迴圈**：標準迴圈（Q4）——`spec-writer` 撰寫 → `spec-reviewer` 獨立
  審查 EARS 格式正確性、編號一致性、與 Discuss/Explore 結論是否吻合 → 上限
  3 輪 → 上報。
- **承諾點**：是（Q3）。使用者核准後，delta spec 成為已核准產物，之後 agent
  不得自行推翻（Q5、Q10 的「已核准產物」原則自此適用）。

#### 3.5 Ticket

- **目的**：切出可驗證票證；以 TDD 在這個階段製作可驗證的測試（PROMPT）。
- **進入條件**：Spec 承諾點已核准。
- **產物**：`changes/<unit>/tickets/<ticket-id>.md`（票證描述＋對應需求編號
  回鏈，Q7 的編號機制在此落地）＋每張票證對應的**可執行失敗測試**（Q9：
  不是骨架或清單，是真測試碼，執行後必須是紅燈；這是 Q9 三個選項中最重的
  一個，代價是 Ticket phase 較重、且需要專案已有可跑的測試環境——訪談已
  明確承擔此代價）。
- **品質迴圈**：標準迴圈（Q4）——`ticket-writer` 撰寫 → `ticket-reviewer`
  獨立審查：測試是否真的能執行、是否真的紅燈（非因環境錯誤而紅）、是否
  對應到正確的需求編號 → 上限 3 輪 → 上報。
- **承諾點**：是（Q3）。使用者核准後，票證與其測試成為已核准產物：Dev 階段
  的實作者不可修改這些測試，發現測試本身有錯要走 Q5 的上報裁決流程，不可
  自行改測試（Q10）。此為三個選項中防呆最強的一個（呼應 research 04 對
  Superpowers「測試好像不對」是常見偷跳話術之一的記載，處理方式是升級上報
  而非改測試），與 Q5「已核准產物 agent 不自行推翻」、Q3「Ticket 是承諾點」
  直接呼應。

#### 3.6 Dev

- **目的**：以 subagent 或 worktree 平行執行票證（PROMPT）。
- **進入條件**：Ticket 承諾點已核准，且每張待開發票證的測試已確認為紅燈。
- **產物**：實作程式碼（落在對應票證的隔離 worktree／分支中）；
  `changes/<unit>/tickets/<ticket-id>.md` 更新狀態欄位。
- **執行機制**：同 session 子代理＋worktree 隔離（Q11）——`dev-worker` 子代理
  frontmatter 宣告 `isolation: worktree`；orchestrator 依票證相依圖（見第 5
  節）決定平行度，一次派工訊息中同時 dispatch 所有相依已滿足的票證（多個
  Agent tool 呼叫在同一輪回應＝平行，一輪一個＝序列，research 04 引述
  Superpowers 的判準）；若單一波次解鎖的票證數超過子代理並行上限 20
  （research 02 §3.1；此規則由 `parallel-dispatch` internal skill 定義、
  `using-worktree` 引用，第 2 節），orchestrator 分批派工，先派滿 20 個，
  其餘等有名額釋出再補上。某票證完成並合併進單位分支後，才解鎖依賴它的
  下一批票證。
  **建立 worktree 前的必要條件**（research 07 Test B，見第 7 節）：
  orchestrator 必須先 checkout 到單位分支 `flow/<unit-name>`，並明確設定
  `worktree.baseRef: "head"`，不得依賴預設值 `"fresh"`。
- **品質迴圈**：標準迴圈，逐票證各自跑一輪（Q4）——`dev-worker` 實作 → 執行
  測試確認轉綠 → `dev-reviewer` 獨立審查（是否真的讓測試轉綠、是否符合票證
  與 spec、有無明顯品質問題）→ 若需要修改，由**orchestrator（主 session）
  親自**用 `SendMessage` 續談同一個 `dev-worker`（同 `agentId`）→ 上限 3 輪 →
  上報。續談機制與其兩個限制皆由 research 07 Test A 實測裁定，取代原先誤引
  research 06 實驗一的描述（該實驗驗證的是 `SubagentStop` hook 在單次呼叫內
  的自我重試，與這裡「呼叫已完成、跨輪次的續談」是不同機制，不能互相借用
  來論證 worktree／context 是否保留）：
  1. **不可用重新派工**——用 Agent tool 再呼叫一次 `dev-worker`（即使同名）
     一律拿到全新 worktree，先前的實作與 worktree 內容不會保留
     （research 06 實驗四）。
  2. **不可委派中介子代理發起續談**——`SendMessage` 續談已完成子代理時，
     完成通知只會送回**主 session**，不會送回發起續談的那個子代理
     （research 07 Test A「額外發現」）；若讓某個中介子代理代替 orchestrator
     去續談 `dev-worker`，它會永遠等不到完成通知而卡住。因此這段續談邏輯
     必須由 `orchestrate` skill 直接在主 session 中執行（第 2 節
     `using-worktree` internal skill 只給 `orchestrate` 載入的理由）。
  「獨立於作者」仍是靠 orchestrator 另派 `dev-reviewer` 子代理達成，不是靠
  hook——`SubagentStop` hook 阻擋後重試的只會是同一個子代理在**單次呼叫內**
  自我修正（research 06 實驗一），這與「作者被審查者打回去、由 orchestrator
  續談同一個已完成的作者子代理」是不同層次的機制，細節見第 4 節。
- **承諾點**：否（Q3）。所有票證的 Dev 迴圈都通過後，自動接續到 Review。

#### 3.7 Review

- **目的**：對照規格與票證，對整個工作單位做整體審查，列出缺口與問題
  （PROMPT）。
- **進入條件**：該工作單位所有票證的 Dev 品質迴圈皆已通過。
- **產物**：`changes/<unit>/review.md`（結構化缺口/問題清單，含嚴重度與根因
  分類）。
- **品質迴圈**：重型迴圈（Q4 明訂 Review 用重型：多視角平行審查＋獨立
  triage，BMAD 式，research 04）——`review-gap-hunter`、
  `review-edge-case-hunter`、`review-spec-compliance-auditor` 三個獨立審查
  子代理平行運作，各自只讀取單位分支的 diff 與 spec/tickets 檔案路徑（不
  互看彼此的過程或結論，避免互相汙染，research 04 對 BMAD 的記載）；三者
  的 finding 全部交給獨立的 `review-triage` 子代理重新驗證每一條（不採信
  審查者自報的嚴重度，research 04），裁定為「純實作問題（由 orchestrator
  親自以 `SendMessage` 續談對應的 `dev-worker` 修，機制見第 3.6 節）」或
  「根因在已核准產物（Spec／Ticket）」——後者一律上報使用者裁決，不自動
  回頭改寫已核准產物（Q5）。輪數上限 5 輪（Q29；與 research 04 記載
  BMAD／Superpowers 一致採用的慣例相同），超過視為不收斂，直接上報。
- **承諾點**：是（Q3）。Review 通過（無阻斷性缺口、或所有缺口皆已上報並
  裁決）後，使用者核准即可進入 Wrap。

#### 3.8 Wrap

- **目的**：全自動收尾，合併與清理不留人工步驟（PROMPT）。
- **進入條件**：Review 承諾點已核准。
- **產物**：`changes/<unit>/wrap.md`（逐動作執行與驗證留痕，Q13）；主 spec
  更新（delta 合併進 `.agent-flow/specs/`，Q8）；`changes/<unit>/` 整包移入
  `.agent-flow/archive/<date>-<unit>/`（Q6）；main 上出現合併 commit；單位
  分支與所有票證 worktree 被清理。
- **執行條件**（Q13）：Review 關卡已過（承諾點核准）＋全測試綠，才可執行
  合併；本地合併、不 push，push 留給使用者。
- **品質迴圈**：Wrap 沒有「作者寫、審查退回重寫」的迴圈型態，因為它是機械性
  執行既定動作而非創造新產物；但 PROMPT 要求每個 phase 結束都有獨立於作者
  的品質檢查，因此 Wrap 的迴圈改採「執行—驗證」形態（Q25：執行—驗證、失敗
  即上報）：`wrap-executor`
  逐步執行合併/歸檔/清理動作 → 獨立的 `wrap-verifier` 子代理針對每一個動作
  重新查證是否真的發生（例如：真的檢查合併後 main 的 git log 含該
  commit、真的檢查 worktree 已被 `git worktree remove`、真的在合併後的 main
  上重跑一次測試確認綠燈——呼應 research 04 記載 Superpowers「合併後在結果
  上重跑一次測試」的作法）→ 任何一個動作驗證失敗即刻停下並上報使用者，
  不做重試（不同於其他 phase 的 3 輪重試，因為合併動作重試的風險遠高於
  文字產物，重試前應先讓人確認現況）。此設計呼應 research 06 的關鍵發現：
  headless 下未涵蓋的權限會「乾淨拒絕、流程照走」，風險型態是「動作被拒
  但流程照走」而非卡住，因此收尾邏輯必須驗證每個動作實際成功，不能只信任
  agent 自報「完成了」。
- **承諾點**：否，全自動（PROMPT、Q13）。

---

### 4. 品質迴圈

**分級迴圈（Q4）**：agent-flow 採兩級品質迴圈，不對每個 phase 都套用最重的
機制（Q4 選項 2 未採納），也不是每個 phase 都用最輕的機制（Q4 選項 3 未採納）：

- **標準迴圈**（Discuss、Explore、Prototype、Spec、Ticket、Dev 逐票證）：
  單一獨立審查者子代理 → 有問題退回原作者子代理修改 → 上限 3 輪 → 仍未通過
  則上報使用者裁決（Q4）。
- **重型迴圈**（僅 Review）：多視角平行審查子代理＋獨立 triage 子代理重新
  驗證與根因分流，借用 BMAD-METHOD 的三段式設計（research 04）：finding
  平行蒐集 → 獨立驗證裁定 → 依根因分流。

**為什麼是 orchestrator 派審查子代理，而不是靠 hook**：research 06 實驗一
證實，`SubagentStop` hook 用 `exit 2` 擋下子代理時，重新嘗試的是**同一個
子代理（同 `agent_id`、同 context）**——它記得自己第一次做了什麼並在此基礎
上修改，而不是換一個獨立角色重新審視；hook 機制本身沒有任何欄位可以指定
「換人重跑」。因此，「審查者需獨立於作者」這個 PROMPT 明訂的要求，只能由
orchestrator 在拿到作者子代理的產出後，明確再用 Agent tool 派一個獨立的審查
子代理實現——這是 agent-flow 品質迴圈的核心機制，不是靠 plugin hooks 或
subagent frontmatter 完成。`SubagentStop` 一類的 hook 仍可用於同一作者的自我
修正重試（例如 lint 沒過就打回去自己修），但不能替代「換人審查」。

**根因分流與上報（Q5）**：品質迴圈退回時只有兩種路由：

1. **純實作問題**——問題出在本 phase 內、還沒核准的產物，由迴圈自動退回
   原作者子代理修正，計入該迴圈的輪數。對 `isolation: worktree` 的作者
   子代理（Dev phase 的 `dev-worker`），「退回」的具體機制是 orchestrator
   親自用 `SendMessage` 續談同一個已完成子代理，而非重新派工——重新派工會
   拿到全新 worktree、丟失先前進度（research 06 實驗四），細節與其兩個
   限制見第 3.6 節、research 07。
2. **根因在已核准產物**（Discuss 摘要、Spec delta、Ticket 與其測試——凡是
   通過承諾點的東西）——一律停下來上報使用者裁決；agent 不自行推翻已核准的
   東西（Q5、Q10）。這與 research 04 記載的 BMAD triage 四分流
   （patch/bad_spec/intent_gap/defer）不同：agent-flow 刻意只分兩類，因為
   BMAD 的「bad_spec 自動回頭改 spec 重新生成」與 Q3 已定的承諾點精神衝突
   （Q5 選項 2「自動回頭改」未採納）。

**測試合約（Q10）**：Ticket phase 產出的測試，在 Dev phase 是不可修改的合約
（Q10 選項 1）。`dev-worker` 若判斷某條測試本身有誤，不得直接修改，必須觸發
「根因在已核准產物」的上報路徑，由使用者裁決是否回頭修正 Ticket（回頭修正後，
該票證需重新走一次 Ticket 的品質迴圈與承諾點核准，才能重新進入 Dev）。

**輪數上限**：agent-flow 標準迴圈統一 3 輪（Q4），重型迴圈（Review）5 輪
（Q29，見第 3.7 節）；超過上限一律上報使用者，**不**自動換模型或換全新
作者子代理重試——這與 research 04 記載的 Superpowers「前三輪原 agent 續修、
後兩輪換更強模型」設計不同，因為訪談選擇的是「分級迴圈」（Q4 選項 1）而非
「簡單迴圈＋升級」（Q4 選項 4 未採納），故超過輪數後的處置是「上報」而非
「升級」。

**留痕格式**：每一次上報裁決都寫入 `changes/<unit>/decisions.md`，格式借用
research 04 記載的 Superpowers ledger 精神（「決定了什麼、為什麼、錯了代價是
什麼」）（Q31：照提案模板）。每筆 ESC 同時同步寫入 state.json 的
`escalations` 陣列（Q32、第 6 節），markdown 給人讀、JSON 給機器判斷是否已
解決：

```markdown
## ESC-<n>：<一行摘要>
- Phase／輪次：<phase>（第 <k>/<max> 輪）
- 觸發角色：<author-role> vs <reviewer-role>
- 根因分類：<純實作問題 | 根因在已核准產物：Discuss/Spec/Ticket>
- 細節：...
- 使用者裁決：...
- 裁決時間：...
```

**審查者輸出格式契約待補**：`quality-loop` internal skill（第 2 節）的範圍
界定提到審查子代理要用「標準化格式」回報通過／退回＋理由，但本節與
`quality-loop` 都尚未定義這個格式的具體 schema——這是刻意延後而非遺漏：
具體格式於規格對齊（PROMPT 第 4 步）時定義，不在設計階段先發明。

---

### 5. Agent 協作與派工

**角色清單與模型指派**（Q14 分級原則「審查者與判斷型角色高階或繼承主
session；實作與研究中階（sonnet）；機械性動作輕量（haiku）」的具體展開；
下表照 Q33 定案）：

| 角色（agent 檔名） | 類別 | 對應 Phase | 模型 |
|---|---|---|---|
| `intent-reviewer` | 審查 | Discuss | inherit |
| `explorer` | 作者 | Explore | sonnet |
| `explore-reviewer` | 審查 | Explore | opus |
| `prototyper` | 作者 | Prototype | sonnet |
| `prototype-reviewer` | 審查 | Prototype | opus |
| `spec-writer` | 作者 | Spec | sonnet |
| `spec-reviewer` | 審查 | Spec | opus |
| `ticket-writer` | 作者 | Ticket | sonnet |
| `ticket-reviewer` | 審查 | Ticket | opus |
| `dev-worker`（每票一個 instance，`isolation: worktree`） | 作者 | Dev | sonnet |
| `dev-reviewer`（每票一個 instance） | 審查 | Dev | opus |
| `review-gap-hunter` / `review-edge-case-hunter` / `review-spec-compliance-auditor` | 審查（平行小組） | Review | opus |
| `review-triage` | 審查（獨立裁定） | Review | opus |
| `wrap-executor` | 機械 | Wrap | haiku |
| `wrap-verifier` | 機械 | Wrap | haiku |

**派工語法**：orchestrator 一律以 Agent tool 呼叫，`subagent_type` 填
`<plugin-name>:<agent-name>`，即 `agent-flow:<role>`（research 05 實驗二
實測證實此語法對 plugin agent 有效且能正確取回結果）。範例：

```
Agent(subagent_type="agent-flow:spec-writer",
      description="Write delta spec for <unit>",
      prompt="Read changes/<unit>/explore.md and changes/<unit>/prototype.md,
              then write changes/<unit>/spec-delta.md following the EARS
              format contract described in the spec skill instructions.")
```

**平行度依票證相依圖（Q11）**：每張票證在 `changes/<unit>/tickets/<ticket-id>.md`
的中繼資料宣告 `dependsOn: [<ticket-id>, ...]`；票證 frontmatter 是相依關係
的權威來源，orchestrator 讀取 Ticket phase 產出後把每張票證的 `dependsOn`
同步寫入 state.json 的 `tickets.<id>.dependsOn`（Q32：「票證 frontmatter 為
準，state.json 同步」；第 6 節），供之後機械式判斷「相依是否已全部完成」，
不必每次重新解析 markdown。orchestrator 在 Dev phase 開始時計算目前「相依已
全部完成」的票證集合，於同一輪回應中一次發出該集合內所有票證的 Agent tool
呼叫（超過並行上限 20 則分批，見第 3.6 節）；等待整批完成並各自通過品質
迴圈、合併進單位分支後，才計算下一批解鎖的票證。這個「分波次」排程方式與
research 03 記載的 Kiro `tasks.md` 依相依圖分波次（wave）平行執行的概念
一致，可作為排程設計的參考模型。

**輸出落地檔案、只傳輕量引用（research 04）**：任何委派給角色子代理的
prompt，一律傳遞檔案路徑而非把前一階段產物整段貼進 prompt；子代理完成後，
只把「結論摘要＋它寫入或修改的檔案路徑」回傳給 orchestrator，完整內容留在
檔案系統。這與 research 04 記載的 Superpowers（「Hand artifacts over as
files」）與 Anthropic 多智能體研究系統（「Subagent output to a filesystem to
minimize the game of telephone」）兩個獨立案例收斂出的共同原則一致，也是
agent-flow 狀態外部化（第 6 節）能夠可靠運作的前提。

**巢狀深度**：orchestrator（第 0 層）→ 角色子代理（第 1 層）在預設 3 層巢狀
上限內完全夠用（research 02 §2.2）。agent-flow 不要求角色子代理再往下派生
下一層子代理——`dev-worker` 不會自己再叫審查者，這呼應 research 04 記載
Superpowers「明確禁止 implementer 自己生 reviewer」的教訓：審查一律由
orchestrator 派出，不是作者自己找。

---

### 6. 狀態外部化

**目錄結構**（Q6：`.agent-flow/` 下按工作單位分目錄；Q22：進行中單位放在
`changes/`；Q8：delta 歸檔時合併進主 spec；Q18：Prototype 碼與證據都進單位
目錄）：

```
.agent-flow/
├── specs/                          # 主 spec（已合併、反映現況）
│   └── <domain>/spec.md            # 依領域分域，切分粒度由專案自訂（Q24）
├── changes/                        # 進行中的工作單位（Q22）
│   └── <unit-name>/
│       ├── state.json              # 狀態檔（Q21）
│       ├── discuss.md
│       ├── explore.md
│       ├── prototype.md            # 問題／做法／證據／結論（PROMPT）
│       ├── prototype/              # 實驗碼本身，進版控（Q18）
│       ├── spec-delta.md           # ADDED/MODIFIED/REMOVED（Q8）
│       ├── tickets/
│       │   └── <ticket-id>.md
│       ├── review.md
│       ├── wrap.md
│       └── decisions.md            # 上報裁決留痕（Q5，見第 4 節）
└── archive/                        # Wrap 後歸檔（Q6）
    └── <date>-<unit-name>/         # changes/<unit-name>/ 的完整快照
```

`<unit-name>` 命名慣例：`<YYYY-MM-DD>-<slug>`（如 `2026-09-04-auth`；Q28），
與 Q6 訪談例句本身示範的形態、OpenSpec 歸檔慣例一致（research 03）。

**state.json schema**（Q21：一個工作單位一個 state.json，含 schema 版本
欄位；欄位需涵蓋 phase 進度、關卡狀態、迴圈輪數、票證狀態）——以下欄位照
提案定案（Q30）：

```json
{
  "schemaVersion": 1,
  "unit": "2026-09-04-auth",
  "createdAt": "2026-09-04T10:00:00+08:00",
  "updatedAt": "2026-09-04T12:30:00+08:00",
  "currentPhase": "dev",
  "phases": {
    "discuss":   { "status": "done", "artifact": "discuss.md" },
    "explore":   { "status": "done", "artifact": "explore.md" },
    "prototype": { "status": "skipped", "reason": "no open technical question" },
    "spec":      { "status": "done", "artifact": "spec-delta.md" },
    "ticket":    { "status": "done", "artifact": "tickets/" },
    "dev":       { "status": "in_progress" },
    "review":    { "status": "pending" },
    "wrap":      { "status": "pending" }
  },
  "gates": {
    "discuss": { "approvedAt": "2026-09-04T10:20:00+08:00", "approvedBy": "user" },
    "spec":    { "approvedAt": "2026-09-04T11:10:00+08:00", "approvedBy": "user" },
    "ticket":  { "approvedAt": "2026-09-04T11:40:00+08:00", "approvedBy": "user" },
    "review":  { "approvedAt": null, "approvedBy": null }
  },
  "qualityLoops": {
    "spec": { "rounds": 1, "maxRounds": 3, "status": "passed" },
    "dev:TICKET-002": { "rounds": 2, "maxRounds": 3, "status": "in_progress" }
  },
  "tickets": {
    "TICKET-001": { "status": "merged", "dependsOn": [], "requirementRefs": ["1.1"] },
    "TICKET-002": { "status": "in_review", "dependsOn": ["TICKET-001"], "requirementRefs": ["1.2", "2.1"] }
  },
  "escalations": [
    { "id": "ESC-1", "phase": "dev", "ticket": "TICKET-002", "rootCause": "approved-artifact", "raisedAt": "...", "resolvedAt": null }
  ],
  "branch": { "unit": "flow/2026-09-04-auth", "baseRef": "main" }
}
```

理由沿用訪談原文（Q21）：`orchestrate` skill 需要機械式讀寫 phase 進度、關卡
狀態、迴圈輪數、票證狀態，JSON 無歧義；人讀內容都在各 markdown 產物，狀態檔
純粹給機器讀寫。`tickets.<id>.dependsOn` 是票證 markdown frontmatter 的同步
鏡像，不是權威來源（Q32）：權威來源永遠是 `changes/<unit>/tickets/<ticket-id>.md`
的 frontmatter，orchestrator 每次讀到票證異動就同步覆寫 state.json 對應欄位。

---

### 7. 版本控制（VCS）

**兩層分支（Q12）**：每個工作單位一條分支 `flow/<unit-name>`，從 main 切出；
票證的隔離工作區則由 `dev-worker` 子代理的 `isolation: worktree` 機制產生——
這一層的實際 git 分支名稱由 Claude Code 自動產生（如 `worktree-agent-<id>`，
research 06 實測所見格式），不是 orchestrator 能直接命名的（`isolation:
worktree` 沒有提供自訂分支名稱的欄位）；orchestrator 能控制的是「合併時機」
與「合併目標」——票證的品質迴圈通過後，orchestrator 把該票證 worktree 的
變更合併進單位分支 `flow/<unit-name>`，再移除該 worktree。Review phase 審查
的是單位分支相對 main 的整體 diff（Q12），Wrap 再把單位分支合回 main（Q13）。
main 隨時保持乾淨（Q12）。

**worktree 生命週期（research 06 實測依據）**：`isolation: worktree` 讓每次
呼叫 `dev-worker` 都拿到全新、獨立的臨時 worktree，不會在多次呼叫之間重用
（research 06 實驗四 (a)）；沒有變更的 worktree 完成後會自動清除，但**有
變更的 worktree 會持續保留在硬碟上**，直到週期性清掃或手動移除（research 06
實驗四 (c)、實驗三）。因為 Dev phase 的票證本來就一定有變更，orchestrator
必須在合併完成後明確執行 `git worktree remove`（必要時先
`git worktree unlock`），不能依賴 Claude Code 自動清理（research 02
§4.5）。

**必要條件（research 07 Test B）**：Dev phase 建立任何票證 worktree 之前，
orchestrator 必須先 checkout 到單位分支 `flow/<unit-name>`，並明確設定
`worktree.baseRef: "head"`——這不是建議，是必要條件。research 07 Test B
在無 remote 的本機 repo 下實測證實：worktree 的分岔基準確實跟隨「發起當下
的 checkout」，`flow/unit` checkout 下建立的 worktree 含該分支的 commit，
`main` checkout 下建立的則不含；但這項結論的驗證環境沒有設定 remote，一旦
專案有 remote，預設值 `"fresh"`（從遠端預設分支 `main` 分出，research 02
§4.4）可能優先於「當下 checkout」生效，屆時所有票證會分岔自 remote 的
main，而不是單位分支目前累積的進度，破壞「多張票證疊在同一條單位分支上
逐步累積」的設計前提（research 07 對設計的裁決意義）。因此不能依賴預設值
恰好等於當下 checkout 這個未完全驗證的行為，必須明確設定 `baseRef: head`。
**限制**：plugin 根目錄 `settings.json` 只支援 `agent` 與
`subagentStatusLine` 兩個 key（research 01 §1.1），無法用來自動帶入這個
worktree 基準點設定；`orchestrate` skill 啟動時檢查專案層級
`.claude/settings.json` 是否已設定，缺少則提示並徵求使用者同意後代寫
（Q23：「檢查後徵同意寫入」，旅程見第 9 節）——這是 plugin 機制本身的限制，
不是設計選擇。

**Dev 與 Review 不共用 worktree**：research 06 實驗四證實 `isolation:
worktree` 每次呼叫都是全新 worktree，因此無法讓 Dev 子代理與 Review 子代理
共用同一份隔離工作區。agent-flow 的因應設計（見第 8 節）：Dev 子代理的變更
先合併進單位分支、worktree 隨即移除；Review 子代理審查的對象是**已合併的
單位分支**（相對 main 的整體 diff），而不是嘗試去讀某個 Dev worktree——這
剛好與 Q12「Review 審單位分支整體 diff」的設計天然吻合，不需要額外機制。

**Commit 時機**（Q34：照提案）：

- 工作單位一開始（Discuss phase 啟動時）即建立 `flow/<unit-name>` 分支；此後
  每個 phase 產物寫入 `changes/<unit-name>/` 後，orchestrator 在該 phase
  品質迴圈通過時做一次 commit（訊息如 `flow(<unit>): discuss passed
  review`），讓單位分支的歷史本身就是一份可稽核的 phase 進度記錄。
- Dev phase：`dev-worker` 在自己的 worktree 內於實作完成、測試轉綠後 commit
  一次（供 `dev-reviewer` 對照 diff）；`dev-reviewer` 通過後，orchestrator
  把該變更合併進單位分支，建議保留「一票證一 commit」的顆粒度（不 squash），
  方便 Review 逐票核對。
- Wrap：單位分支合併進 main 時建立合併 commit，建議保留逐票證歷史（不整包
  squash），因為 Q13 要求「每動作驗證成功並留痕」，逐票證 commit 本身就是
  一種留痕。

**Wrap 合併判準與逐動作驗證留痕（Q13）**：合併條件為「Review 關卡過（承諾點
已核准）＋全測試綠」；本地合併、不 push（push 留給使用者）。逐動作驗證的
具體實作見第 3.8 節（`wrap-executor` 執行、`wrap-verifier` 獨立查證）；驗證
失敗立即停下上報，不比照其他 phase 做 3 輪重試。此設計呼應 research 06 的
核心發現：headless 下無人值守的權限拒絕是「乾淨拒絕、流程照走」而非卡住，
最大風險是「動作被拒但流程自認完成」的靜默失敗，所以全自動收尾必須逐一驗證
真實結果，不能只信任 agent 的自我回報。

---

### 8. 已知取捨

**Token 成本 4–15 倍（research 04）**：多 agent 協作（每 phase 至少一組
作者＋審查者子代理，Review phase 更是三個平行審查＋一個 triage）的 token
成本，相較單輪對話高出 4 到 15 倍（research 04 對 Anthropic 多智能體研究
系統的引述）。agent-flow 用兩個手段緩解：分級模型（Q14，機械性工作用
haiku、審查用 opus 而非全部用最貴模型）；平行度依票證相依圖與複雜度決定
（Q11），不是無條件把所有票證都拆到最細去平行（呼應 research 04 對 Anthropic
案例「平行度應依複雜度分級」的引述）。這是明確的成本／品質權衡：agent-flow
用「多 agent、獨立審查」換取品質與可稽核性，訪談選擇分級迴圈而非全部簡化
（Q4）已表明使用者接受這個取捨。

**Plugin agent 不支援 hooks（research 05／02）**：plugin 提供的 agent
frontmatter 不支援 `hooks`、`mcpServers`、`permissionMode`（research 05
實驗一實測證實，與官方 `plugins-reference` 頁面一致）。這對 agent-flow 的
實質影響比表面上小：核心的「審查者獨立於作者」本來就不能靠 hook 達成（見
第 4 節，research 06 實驗一），必須由 orchestrator 顯式派審查子代理，所以
這條限制不影響核心品質迴圈設計。真正受影響的是「單一作者的自我把關」這類
原本可以用 `SubagentStop` hook 微調的機制（例如某角色 lint 沒過就自動打
回去自己修，不需要 orchestrator 介入）——這類機制若要做，需改放在 plugin
層級的 `hooks/hooks.json`，用 `matcher` 比對 `agent_type` 變相達成
（research 01 §2.4、research 06 實驗二已驗證 matcher 可精確鎖定角色名稱），
而不能寫進個別 agent 檔案的 frontmatter。

**Dev／Review 不共用 worktree（research 06）**：見第 7 節，透過「Dev 合併進
單位分支後即移除 worktree、Review 審查單位分支 diff」的流程設計吸收了這個
平台限制，不需要額外機制。

**Q18 實驗碼進版控的清理紀律**：Q18 選擇「碼與證據都進單位目錄」而非建議
選項的「碼在 `/tmp`」，理由是保留可回查重跑的實驗碼；但 PROMPT 明訂
Prototype「程式碼不進正式產品」。兩者的協調方式（Q35：照提案，「碼留單位
目錄不入正式路徑、Review 查無依賴、隨歸檔保留」）：

1. `prototype/` 目錄位於 `.agent-flow/changes/<unit>/prototype/`，不在任何
   正式產品原始碼路徑下（如 `src/`），所以它進版控不等於它「進正式產品」——
   PROMPT 說的「不進正式產品」應理解為「不被生產程式碼依賴／引用」，而不是
   「不留在 repo 歷史裡」（Q18 選擇留下證據，正是為了在「不進正式產品」之外
   仍保留可稽核性）。
2. Review phase 的品質迴圈（`review-spec-compliance-auditor`）明確檢查：
   正式產品程式碼路徑中沒有任何檔案 import／依賴
   `.agent-flow/changes/<unit>/prototype/` 下的內容，這是 Review 承諾點通過
   的必要條件之一。
3. Wrap 歸檔時，`prototype/` 隨 `changes/<unit>/` 整包移入
   `archive/<date>-<unit>/`（第 6 節），保留在 main 分支歷史中作為證據，但
   不做任何進一步整合動作（不編譯、不打包、不在建置流程中引用）。

**Skill 撞名與命名空間（research 01）**：plugin skill 一律帶 `agent-flow:`
命名空間（如 `agent-flow:discuss`），天生不會與其他 plugin 或使用者個人
層級的同名 skill 衝突（research 01 §7.4）。但 **agent** 的命名空間規則不
對稱：專案或個人層級的 `.claude/agents/<name>.md` 會**覆蓋**同名的 plugin
agent（research 01 §7.4、§2.3 的 5 層優先序：managed > CLI > 專案 > 個人 >
plugin，plugin 敬陪末座）。這代表如果使用者的專案剛好也有一個叫
`dev-worker.md` 或 `spec-reviewer.md` 的 agent 定義，會在使用者不知情的
狀況下悄悄取代 agent-flow 出貨的角色子代理，品質迴圈與模型分級可能因此
失效卻無任何警告。**agent-flow 不做啟動時掃描檢查**（Q36：「不檢查」，
未採納原提案的啟動掃描機制）——這是明確裁決過的已知取捨，不是遺漏：偵測與
警告需要 `orchestrate` 每次啟動都額外掃描並比對專案與個人層級 `agents/`
目錄，訪談認為這個複雜度不值得。風險留給使用者自行注意：若專案或個人層級
剛好有同名 agent 檔案，agent-flow 的角色定義會被靜默覆蓋、且沒有任何提示。

---

### 9. 完整旅程與文案

**安裝**（Q17：repo 自帶 marketplace；本 repo 的 `.claude-plugin/
marketplace.json` 與 `plugin.json` 已將 marketplace 與 plugin 皆命名為
`agent-flow`，repo 為 `wiasliaw/agent-flow`）：

```bash
$ claude plugin marketplace add wiasliaw/agent-flow
$ claude plugin install agent-flow@agent-flow
```

安裝完成後，`/agent-flow:orchestrate` 與八個 `/agent-flow:<phase>` 指令即可
使用（user scope 為主情境，Q17）。

**旅程範例**：既有專案（brownfield）加上「忘記密碼」流程，工作單位命名為
`2026-09-04-password-reset`。

1. 使用者輸入 `/agent-flow:orchestrate 幫使用者加上忘記密碼流程`。orchestrator
   建立 `.agent-flow/changes/2026-09-04-password-reset/`、切出分支
   `flow/2026-09-04-password-reset`，進入 Discuss。
2. **Discuss（承諾點一）**：主 session 先發散提問（「目前忘記密碼的痛點是
   什麼？」「有沒有既有的 email 服務可用？」），再收斂為選項式問題（「重設
   連結的有效期？1. 15 分鐘 2. 1 小時 3. 24 小時」）。`intent-reviewer` 審查
   通過後，主 session 呈現：「以下是我理解的意圖：……是否核准進入
   Explore？」使用者輸入「核准」或修改意見。
3. **Explore（自動）**：`explorer` 調查現有帳號／email 機制與外部套件選項，
   `explore-reviewer` 審查通過後自動接續。
4. **Prototype（自動，視情況）**：若 Explore 留下技術疑問（如「現有 email
   服務的 rate limit 夠不夠」），`prototyper` 寫一段丟棄式腳本量測，結論寫入
   `prototype.md`；若無疑問則略過。
5. **Spec（承諾點二）**：`spec-writer` 依 EARS 格式寫 `spec-delta.md`（如
   `1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a reset
   link valid for 1 hour.`），`spec-reviewer` 審查通過後，主 session 呈現
   規格全文給使用者核准。
6. **Ticket（承諾點三）**：`ticket-writer` 切出票證（如 TICKET-001 產生
   reset token、TICKET-002 寄送 email、TICKET-003 驗證與重設密碼頁），每張
   票證附可執行的失敗測試（真的跑起來是紅燈）。`ticket-reviewer` 審查通過
   後，主 session 呈現票證清單與測試檔案位置給使用者核准。
7. **Dev 前置檢查（Q23）**：進入 Dev 前，`orchestrate` 檢查專案
   `.claude/settings.json` 是否已設定 `worktree.baseRef: "head"`（第 3.6、
   7 節的必要條件）；若未設定，提示：「Dev phase 需要每張票證的 worktree
   從目前的單位分支分岔，是否同意寫入這項專案設定？」使用者同意後代寫。
8. **Dev（自動）**：orchestrator 讀相依圖，TICKET-001 無相依先跑，
   TICKET-002／TICKET-003 相依 TICKET-001，待其合併後才平行跑。每張票證
   `dev-worker` 實作到測試轉綠，`dev-reviewer` 獨立審查；若需要修改，
   `orchestrate` 親自用 `SendMessage` 續談同一個 `dev-worker`（第 3.6
   節）；通過後合併進單位分支。
9. **Review（承諾點四）**：三個審查小組平行找缺口，`review-triage` 統一
   裁定、寫出 `review.md`。主 session 呈現：「發現 2 個非阻斷建議、0 個
   阻斷問題，是否核准進入 Wrap？」
10. **Wrap（全自動）**：`wrap-executor` 合併單位分支進 main、把
   `spec-delta.md` 併入 `.agent-flow/specs/`、把 `changes/
   2026-09-04-password-reset/` 移入 `archive/`、刪除單位分支與殘留
   worktree；`wrap-verifier` 逐一查證；完成後主 session 印出 `wrap.md`
   摘要：「已完成本地合併，尚未 push，請自行推送。」

**External skills（9 個）的一句話文案（英文，plugin 內容；Q40：審視後維持
原文，未重寫，實作階段可微調字句）**：

| Skill | Description |
|---|---|
| `orchestrate` | Drives all eight phases in sequence, stopping only at the four approval gates, so you don't have to invoke each phase by hand. |
| `discuss` | Runs a Socratic dialogue with you to pin down intent before any spec or code gets written, then asks for your approval before moving on. |
| `explore` | Investigates the existing codebase and external options to confirm the approved intent is actually feasible. |
| `prototype` | Answers open technical questions with throwaway experiments, capturing the question, approach, and evidence — never the code itself. |
| `spec` | Turns the approved findings into an EARS-format delta spec, numbered for traceability, and asks for your approval before tickets get cut. |
| `ticket` | Splits the approved spec into verifiable tickets, each shipped with a real, currently-failing test — no implementation until you approve. |
| `dev` | Implements approved tickets in parallel, one isolated worktree per ticket, until every test goes green and passes independent review. |
| `review` | Runs a multi-perspective audit of the whole unit against its spec and tickets, then asks for your approval before wrap-up. |
| `wrap` | Merges, archives, and cleans up fully automatically once review is approved and every test is green — commits locally, never pushes. |

**Internal skills（6 個，Q37–Q39）的一句話文案（Q40：核准）**——
`user-invocable: false`（第 2、10 節），描述導向「何時該載入」而非
「做什麼」：

| Skill | Description |
|---|---|
| `state-management` | Load this before any read or write to `.agent-flow/changes/<unit>/state.json` — keeps phase status, gate status, loop rounds, and ticket status consistent with the schema. |
| `sdd-guide` | Load this when writing or reviewing a delta spec, a ticket's requirement backlink, or merging a delta into the main spec — defines the EARS and ADDED/MODIFIED/REMOVED contract. |
| `tdd-guide` | Load this when writing, reviewing, or implementing a ticket's tests — the red-before-green rule, the no-editing-approved-tests contract, and the rationalization rebuttal table. |
| `parallel-dispatch` | Load this before fanning out multiple read-only subagents at once — file-based handoff, complexity-based parallelism, and the 20-subagent batching rule. |
| `using-worktree` | Load this only as the orchestrator, before creating or resuming a ticket's isolated worktree — the branch/baseRef precondition, the same-agent SendMessage resume rule, and worktree cleanup after merge. |
| `quality-loop` | Load this whenever a reviewer needs to report a verdict, or the orchestrator needs to route one — the two-tier loop, the two-way routing rule, round limits, and the ESC trace format. |

**旁註**：本 repo 現有 `.claude-plugin/plugin.json` 骨架（訪談前建立）敘述
「nine phases」「Workflow tool」與 `skills/external`／`skills/internal` 兩層
目錄。經 Q26 裁決「規格對齊時更新骨架」、Q37–Q39 修正範圍後定案：
`skills/external`／`skills/internal` 兩層目錄**保留**（本設計最終也是這個
形狀，見第 2 節）；「nine phases」與「Workflow tool」導向的敘述仍與本設計
（八 phase、以 Agent tool 為主要派工機制）不一致，留待下一步「規格對齊」時
更新骨架文字本身。

---

### 10. 殘餘待驗證事項

原第 10 節列出的 13 項【提案】已由設計稽核與補充實驗後的 Q23–Q39 全數裁決，
逐項改寫進本文對應章節（第 3.7／3.8／4／5／6／7／8／9 節），不再是待裁決
狀態。本節改列 Q37–Q39 新增的 internal skills 設計依賴的兩項平台查證——
性質是待實測／待文件查證，不是使用者裁決。

**(a) `skills/external/`、`skills/internal/` 這種巢狀分組目錄，plugin.json
的 `skills` 陣列指到這種分組目錄，平台是否支援？**

已於 research 01 查到明確依據，**非待實測**：research 01 §1.1 的
plugin.json 欄位表記載 `skills` 欄位型別為 `string|array`、語意是「額外
skill 目錄」，行為是「疊加」於預設 `skills/`（即額外掃描 manifest 指定的
目錄，規則與預設 `skills/<name>/SKILL.md` 相同）。對照同一張表：`agents`
欄位明確寫「Agent **檔案**路徑」、`commands` 欄位明確寫「扁平 `.md` skill
**檔案**」，兩者都是「取代」預設、且指向個別檔案——`skills` 欄位在措辭與
行為上都刻意不同：陣列中每個路徑是一個**目錄**，會被當成「額外的 skills
根目錄」，掃描其下的 `<name>/SKILL.md` 子目錄。這與 repo 既有
`plugin.json` 骨架的 `"skills": ["./skills/external", "./skills/internal"]`
設定直接吻合，支持 `skills/external/<name>/SKILL.md`／
`skills/internal/<name>/SKILL.md` 這種分組目錄設計（第 2、9 節）。
**信心邊界（如實揭露）**：research 01 沒有一個逐字操作過的範例展示這個確切
巢狀分組場景，只有欄位語意的文件記載；上述結論是從欄位型別描述＋與
`agents`／`commands` 兩個同類欄位的用詞對比推論出來的高信心結論，不是
實測驗證。若要更高把握，建議實作階段用 `claude plugin validate` 或
`--plugin-dir` 對這個確切目錄結構跑一次最小可行範例，但這不阻擋設計定案。

**(b) internal skill「使用者不可觸發、但 Claude／子代理仍可載入」的機制？**

已於 research 01 查到明確依據，**非待實測**：research 01 §2.2 的 skill
frontmatter 欄位表記載 `user-invocable`：「`false` 時只有 Claude 能呼叫，
`/` 選單隱藏，打 `/name` 不執行」；§3.2「who-invokes 控制」表格進一步確認
這個狀態下 Claude 仍可呼叫、description 常駐 context、呼叫時載入完整內容。
六個 internal skill（第 2 節）一律加上
`user-invocable: false`：Claude（含 orchestrator 判斷需要時自行呼叫、或
子代理透過 `skills:` frontmatter 欄位 preload、或呼叫 Skill tool）仍可
載入，但不會出現在使用者的 `/` 選單，使用者也無法手動
`/agent-flow:sdd-guide` 之類直接觸發。這是文件表格直接記載的行為，信心
程度高於 (a)，不需要進一步實驗。

**殘餘待驗證事項：0 項**——兩項查證皆已在 research 01 找到直接依據。(a) 的
信心邊界（無逐字巢狀分組範例）已如實揭露於上；若要更保守，可在實作階段
補一次最小可行範例驗證，但這不是設計定案的阻礙。
