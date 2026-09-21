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

> 本節原版依訪談記錄與 research 01–07 撰寫，其核心結構（八 phase／四承諾點／
> 17 agent／internal skill／`approved-artifact` ESC 路由）已被 2026-09-10 的
> R1–R5 裁決推翻；2026-09-21 依 R14 裁決整體改寫為與現行 `spec/` 對齊的設計
> 總覽（原版全文見 git 歷史）。**實作的唯一依據仍是 `spec/`**——本文與 `spec/`
> 矛盾時以 `spec/` 為準；影響設計結構的後續裁決需回寫本文（`spec/README.md`
> 「DESIGN.md 回寫記錄」）。決策標註來源：訪談回答標「（Qn）」、重構後裁決標
> 「（Rn）」（全文見 `spec/README.md` 裁決記錄）、`PROMPT.md` 原文標
> 「（PROMPT）」、研究裁決標「（research NN）」。

### 1. 目標與非目標

**目標**

- 把規格驅動開發（Spec-Driven Development, SDD）與測試驅動開發（Test-Driven
  Development, TDD）結合成七 phase 的 waterfall 工作流程：Explore／Prototype
  （optional）／Spec／TDD／Build／Review／Wrap（PROMPT、R1——原八 phase 收斂：
  Discuss 併入 Explore，Ticket 改名 TDD，Dev 改名 Build）。
- 兩種情境都支援：全新專案（greenfield）與既有專案（brownfield），走同一流程
  （Q1）。
- 規格驅動整個流程；測試先於實作，在 TDD phase 隨票證產出，品質迴圈通過即成為
  Build 的測試合約（PROMPT、Q9、R2）。
- 每個 phase 結束由獨立於作者的審查跑品質迴圈（PROMPT、Q4）；審查判定根因在
  較早 phase 時**自動退回**該 phase 重做，重做後依序重走下游（R3）。
- 以多 agent 協作運作：主 session 只負責調度、決策與記錄；撰寫與審查派給
  `worker`／`reviewer` 兩個 general-purpose agent 分工執行（PROMPT、R5）。
- 在三個承諾點（Explore、Spec、Review）停下來交還控制權給使用者（R2）；核准
  即結束 session，由使用者開新 session 續接（R13）；無承諾點的 phase 自動
  接續；Wrap 全自動、不留人工步驟（PROMPT、Q13）。
- 以 plugin 形式散布，repo 自帶 marketplace，透過 `claude plugin marketplace
  add` 安裝（Q17）。

**非目標**

- **不 push 遠端**：Wrap 只做本地合併，push 留給使用者自行決定（Q13）。
- **不接管主 session 身分**：orchestrate 是引導主 session 的總控 skill，不
  透過 plugin `settings.json` 的 `agent` 欄位把主 session 換成單一 agent
  人格（Q15）。
- **不做「一路到底不檢查」**：即使是自動接續或全自動的 phase，仍各自跑品質
  迴圈或逐動作驗證（Q4、Q13）。
- **不逐案徵求退回同意**：審查發現根因在較早 phase 時自動退回，不先上報等
  使用者裁決——原「根因在已核准產物一律上報」的設計（Q5）由 R3 取代。制衡
  改由兩處提供：被撤銷的承諾點重做後必須重新核准（INV-8）；同一退回目標
  累計 3 次即上報（INV-6 的 fallback-limit）。
- **不提供「Quick 模式跳過關卡」**：單獨呼叫某一 phase skill（Q2）不免除該
  phase 的前置檢查與品質迴圈；前置不滿足即停止提示，無跳過語法（S9、
  INV-11）。
- **Build 不用 headless worker 程序或 Workflow 腳本作平行機制**：採同
  session 子代理＋worktree 隔離（Q11）。
- **不維護「每功能一份完整 spec、每次重寫」的模型**：delta spec 為主、歸檔時
  合併進主 spec（Q8）。
- **不支援任意自訂狀態目錄路徑**：固定為 `.agent-flow/`（Q6）。
- **不維護 internal skill 機制**：內部共用指引改為 `references/` 純 markdown
  文件，不是 skill、無 frontmatter、不出現在任何選單（R4；原 Q37–Q40 的兩層
  skill 設計作廢）。

---

### 2. 架構總覽

**orchestrator＝主 session，由 `orchestrate` skill 引導（Q15、Q20）**。呼叫
方式為 `/agent-flow:orchestrate`（research 01 §3.3）。`orchestrate` 與七個
phase skill 都不設 `context: fork`——skill 內容是驅動「目前這個 session」的
指示（research 01 §2.2.1）；無論被 `orchestrate` 依序驅動，還是使用者單獨
呼叫某個 phase skill（Q2），執行 phase 邏輯的都是當下的 session 本身。

**為什麼不用 plugin `settings.json` 的 `agent` 欄位固化 orchestrator
（Q15）**：research 05 實驗三證實該欄位能換掉主 thread 的 system prompt 與
工具集，但代價是主 session 受 agent 定義檔的 `tools:` 白名單牽制；訪談選擇
「總控 skill 引導主 session」，約束靠文件紀律，換取主 session 隨時保有完整
工具集與派工能力。

**External skill 八個、平鋪（R4）**：`orchestrate` 加七個 phase skill
（`explore`／`prototype`／`spec`／`tdd`／`build`／`review`／`wrap`），全部
放在 `skills/<name>/SKILL.md`、走 manifest 預設掃描，使用者以
`/agent-flow:<name>` 觸發。內容是「這個 session 現在該做什麼」的劇本，控制流
以 pseudo-code DSL 寫成（G1／G3 承襲），DSL 的解讀規則、primitives、變數、
共用程序與 INV-1～INV-13 全文定於 `references/glossary.md`——主 session 執行
任何 external skill 前先 `Read` 它（R4，取代舊 G2 的 internal skill 載入
規則）。

**內部共用指引是 `references/` 六份純 markdown（R4）**，非 plugin 元件、不受
validate 檢查（存在性由機械檢查補強，spec/01 §2.5.2）：

| 檔案 | 內容 | 誰讀 |
|---|---|---|
| `glossary.md` | DSL 語法、primitives、變數、共用程序、INV-1～INV-13 | 主 session（執行任何 external skill 前） |
| `state-management.md` | `state.json` 讀寫規範 | 主 session |
| `dispatch.md` | 平行派工通則＋worktree 生命週期（原 `parallel-dispatch`＋`using-worktree` 合併） | 主 session |
| `quality-loop.md` | 品質迴圈、waterfall 路由、審查者輸出 JSON 契約、FB／ESC 格式 | 主 session；審查派工時指名給 `reviewer` |
| `sdd-guide.md` | EARS、delta spec、需求編號回鏈、主 spec 合併規則 | Spec／TDD／Review（compliance lens）／Wrap 派工時指名 |
| `tdd-guide.md` | 紅綠鐵律、測試合約、反駁表 | TDD／Build 派工時指名 |

Reference 路徑一律相對 plugin 根目錄；skill 內文寫
`${CLAUDE_PLUGIN_ROOT}/references/<name>.md`，派工時由主 session 展開成
**絕對路徑**傳入——子代理與 worktree 內無從解析 plugin 相對路徑（spec/04
通則 3）。

**Agent 兩個、general-purpose（R5）**：原 17 個角色 agent 收斂為
`agents/worker.md`（sonnet，作者／機械執行）與 `agents/reviewer.md`（opus，
獨立審查、`disallowedTools: Write, Edit` 唯讀）。角色差異不再靠 agent 檔，
由每次派工的**角色簡報五要素**表達（spec/03 通則 5）：(a) 本次角色；(b) 要先
`Read` 的 reference 絕對路徑清單；(c) 輸入產物路徑；(d) 產物落地路徑；(e)
輸出格式要求與輪次資訊。保留 `agents/` 而不改用內建 agent 的理由（R11）：
`reviewer` 的唯讀與「不持有 Agent tool」是實測有強制力的工具層保證
（research 11 §3），是品質迴圈獨立性與 INV-10 的物理基礎。

**命名規則（R11）**：agent 定義檔的 `name` 一律裸名（`worker`／`reviewer`），
命名空間 `agent-flow:<name>` 由平台自動衍生——寫進 `name` 會疊加成
`agent-flow:agent-flow:worker` 且 validate 不攔（research 11 §3.5）。派工端
（glossary 的 `dispatch` 原語、orchestrate）才寫命名空間形式。

**主 session 唯一的例外——Explore 的對話環節**：PROMPT 要求主 session「只
負責調度、決策與記錄」，但 Explore（合併原 Discuss，R1）的蘇格拉底對話需要
與使用者多輪即時往返，子代理不具備這個通道（research 02 §1.4、§2.1 反推），
因此對話由主 session 直接進行；範圍嚴格限於「與使用者對話、產出摘要」，
調查派 `worker`、審查派 `reviewer`，維持「獨立於作者」（PROMPT）。

**Session 邊界在承諾點（R13）**：單一 session 連跑多 phase 會累積 skill
本文、glossary 重複載入與承諾點全文呈現，觸發 auto-compact；而 model 沒有
任何官方記載的機制能偵測自己剩餘的 context（research 14），動態斷點不可行。
因此承諾點核准後（寫入 gate、commit）即 `halt` 結束 session，提示使用者開新
session 執行 `/agent-flow:orchestrate` 續接——新 session 讀 `state.json`
判斷接續點（spec/05 §2.1）。無承諾點的 phase 間維持同 session 自動接續。

**架構圖**：

```
                        User
                         │ /agent-flow:orchestrate（或單獨呼叫某個 phase skill）
                         ▼
  ┌─────────────────────────────────────────────────────────────┐
  │               Main Session = Orchestrator                   │
  │         guided by the `orchestrate` skill (Q15, Q20)        │
  │                                                             │
  │  - 執行 skill 前先 Read references/glossary.md（R4）          │
  │  - 唯一寫入 .agent-flow/changes/<unit>/state.json（INV-1）    │
  │  - 三承諾點 Explore／Spec／Review 停等核准（R2）；核准即結束     │
  │    session，新 session 讀 state.json 續接（R13）              │
  │  - 審查根因在較早 phase → 自動 waterfall 退回（R3）            │
  │  - Build 的 ticket worktree 由主 session 自建與清理（R12）    │
  └──────────────┬──────────────────────────────────────────────┘
                 │ Agent tool：subagent_type =
                 │   "agent-flow:worker" ／ "agent-flow:reviewer"
                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │  worker（sonnet，作者／執行）      reviewer（opus，唯讀審查）    │
  │  調查、丟棄式實驗、delta spec、    quality-loop JSON 契約；      │
  │  票證＋紅燈測試、票證實作、        Review 三 lens＋triage；      │
  │  wrap 機械執行                    Wrap 逐動作驗證              │
  │                                                             │
  │  角色由派工簡報五要素＋指名的 references 決定（R5）；            │
  │  兩者皆不得巢狀派工（INV-10）                                  │
  └─────────────────────────────────────────────────────────────┘
```

**Repo 層結構（spec/01）**：repo 根同時是 plugin 根與 marketplace 根
（Q17）。兩份 manifest 只保留必要欄位，`keywords`／`category`／`tags` 全部
移除（R9）；開發脈絡文件收攏於非隱藏目錄 `context/`（R6），開發約定放
`.claude/CLAUDE.md`——放 repo 根會觸發 validate 誤報並使 `--strict` 失敗
（R8）；對外 README 中英兩份、章節逐節對齊（R10）。驗證程序兩道指令：
`claude plugin validate .claude-plugin/plugin.json`（遞迴驗證全部 skill 與
agent）與 `claude plugin validate .claude-plugin/marketplace.json`（R7，
research 10）；validate 查不到的部分（agent 禁用欄位、`references/` 存在性）
由 `scripts/mechanical-check.sh` 補強（spec/01 §2.5.2）。

---

### 3. 七個 Phase

以下每個 phase 列出：目的、進入條件、產物、品質迴圈形態、是否承諾點。詳細
程序以 `spec/06`–`12` 為準。

#### 3.1 Explore（承諾點一）

- **目的**：釐清意圖的同時做可行性研究（R1：原 Discuss＋Explore 合併）。
  對話形態「先發散後收斂」（Q16）：開放式提問探索意圖，選項式逐題收斂；
  調查內外並查（Q1：既有程式碼與外部技術選項都覆蓋）。
- **進入條件**：流程起點，無前置依賴。經 orchestrate 驅動時工作單位已建立；
  單獨呼叫時先 `resolve_unit()`／`create_unit()`；已核准的 Explore 拒絕重新
  執行（S8），除非使用者明確要求修改（視同使用者發起的退回）。
- **產物**：`changes/<unit>/explore.md`——意圖（發散紀錄／收斂問答／摘要）、
  調查（內部／外部發現，附佐證）、**未解決的技術疑問清單**（Prototype 是否
  進場的直接依據）。
- **執行方式**：對話由主 session 直接進行（第 2 節）；調查派 `worker`
  （investigator 角色），對話與調查可交錯。
- **品質迴圈**：標準迴圈 3 輪——`reviewer` 檢查摘要忠實性、調查佐證、疑問
  清單完整性；findings 的 `targetPhase` 恆為 `"explore"`（首 phase 特例）。
  第 3 輪仍未通過：ESC 與承諾點合併呈現，核准回應同時視為對待確認項目的
  裁決（承襲原 Discuss 處置）。
- **承諾點**：是（R2）。核准後 `gates.explore` 寫入、commit，**結束
  session**（R13）；續接 session 判定：疑問清單非空 → Prototype，為空 →
  Prototype 標記 `skipped`、進 Spec。

#### 3.2 Prototype（optional）

- **目的**：用丟棄式程式碼實驗回答 Explore 留下的技術疑問，留下問題、做法與
  證據；程式碼不進正式產品（PROMPT）。
- **進入條件**：Explore 已核准且疑問清單非空；清單為空時整段略過
  （`phases.prototype = "skipped"` 附 reason，R1）。單獨呼叫時清單為空仍
  允許強制執行（「為空即略過」是 orchestrate 的自動接續捷徑，不是硬限制）。
- **產物**：`changes/<unit>/prototype.md`（問題／做法／證據／結論）＋
  `changes/<unit>/prototype/`（實驗碼本身，進版控——Q18 未採「碼在 /tmp」
  的建議選項，配套紀律見第 8 節）。
- **品質迴圈**：標準迴圈 3 輪——`reviewer` 實際重跑實驗碼驗證疑問是否被
  回答、證據是否可重現、是否誤寫入 `prototype/` 以外路徑。`targetPhase:
  "explore"`（意圖誤導致實驗方向錯誤）時自動退回 Explore（R3）。
- **承諾點**：否。迴圈通過即 commit、自動接續 Spec。

#### 3.3 Spec（承諾點二）

- **目的**：撰寫 SDD 規格（PROMPT）。
- **進入條件**：`explore.md` 存在且 Explore 已核准；`phases.prototype ==
  "done"` 時一併讀 `prototype.md`——**以 phase 狀態為準，不以檔案存在為準**
  （spec/05 §4.5 步驟 4：退回後的殘留檔案只是底稿）。
- **產物**：`changes/<unit>/spec-delta.md`——delta 形態（Q8）：
  `## ADDED/MODIFIED/REMOVED Requirements` 三區塊（greenfield 只寫 ADDED）；
  需求採 EARS 句型附編號，供票證與測試回鏈（Q7）；frontmatter 的 `domain`
  是 Wrap 合併進主 spec 的目標領域（Q24）。
- **品質迴圈**：標準迴圈 3 輪——`worker`（spec author，指名 sdd-guide）撰寫
  → `reviewer` 審查句型、編號、分類屬實、與上游結論吻合、未引入新範圍。
  `targetPhase` 為 `"explore"`／`"prototype"` 時 waterfall 退回（R3——合併
  Discuss 後 Explore 已是已核准上游，取代原「Spec 之前恆為實作問題」的單一
  路由）。
- **承諾點**：是（R2）。呈現全文核准後 `gates.spec` 寫入、commit、結束
  session（R13）；續接 session 進 TDD。

#### 3.4 TDD（無承諾點）

- **目的**：依已核准的 spec 切出可驗證票證，每張附**可執行的失敗測試**
  （R1：原 Ticket 改名；Q9：真測試碼、實際執行確認紅燈）。
- **進入條件**：`spec-delta.md` 存在且已核准。
- **產物**：`changes/<unit>/tickets/<ticket-id>.md`（frontmatter：`id`／
  `title`／`status`／`dependsOn`（權威來源，Q32）／`requirementRefs`（Q7）／
  `testFiles`）＋測試碼寫入專案原有測試目錄（不進 `.agent-flow/`——必須是
  正式測試套件的一部分）。`dependsOn` 依 S10 判準填寫。
- **品質迴圈**：標準迴圈、**整批一輪**（S2，`qualityLoops` 單一 key
  `"tdd"`，上限 3 輪）——`reviewer` 獨立重跑：測試能執行、真紅燈且是斷言
  失敗（模組載入錯誤等一律判假紅燈）、編號對應正確。退回重做輪先做差異
  判定，只重做受影響票證；「補測試覆蓋」情境（實作已存在、新案例直接綠燈）
  以拋棄式副本的可失敗性證據替代紅燈（spec/09 §2–§3）。`targetPhase` 為
  `"spec"` 或更早時 waterfall 退回。
- **承諾點**：**否（R2，原 Ticket 承諾點移除）**。迴圈通過即：全部 `draft`
  票證轉 `ready`、**測試合約生效**（Q10 的合約起點由「gate 核准」改為「迴圈
  通過」）、commit、自動接續 Build。

#### 3.5 Build（無承諾點）

- **目的**：以子代理＋worktree 平行實作票證，讓合約測試轉綠（R1：原 Dev
  改名）。
- **進入條件**：`phases.tdd == "done"`，無 `draft` 或未裁決的 `escalated`
  票證。全部已 `merged` 時（退回重走但票證未受影響）不派工、直接標 `done`。
- **執行機制（R12）**：主 session 依相依圖計算波次（Q11）——`ready` 且
  `dependsOn` 全部 `merged` 的票證為一波；先為整波每張票證自建 worktree
  （`git worktree add -b ticket/<id> .agent-flow/worktrees/<id>
  flow/<unit-name>`，以分支名指定來源，**無任何使用者前置設定**），再同一輪
  回應發出整波**普通派工**（不帶 `isolation` 參數），角色簡報傳入 worktree
  絕對路徑與「先 `cd` 進去」的指示（research 12／13 實測：平行子代理互不
  干擾）。單波超過 20 個分批（INV-4）。前置檢查：`.agent-flow/.gitignore`
  含 `worktrees/`（缺這行 `git add -A` 會把 worktree 當 embedded repo 加入
  索引，research 13 §3）、checkout 在單位分支。
- **品質迴圈**：逐票證 3 輪——`worker` 實作到測試轉綠、worktree 內 commit
  一次（Q34）→ `reviewer` `cd` 進同一 worktree 獨立重跑測試、`git diff`
  核對測試檔未被修改。退回修正**首選** `SendMessage` 續談同一 `agentId`
  （INV-3；不可委派中介——完成通知只回主 session，research 07 Test A）；原
  agent 不可定址時改派全新子代理進**同一個 worktree**，工作不遺失（R12 之後
  worktree 生命週期由主 session 持有，INV-3 隨之放寬）。通過即合併進單位
  分支（`--no-ff`，一票一 commit）並**立即** `git worktree remove`。
- **退回路由**：測試檔被修改或測試本身有誤 → **局部退回 TDD**（僅受影響
  票證轉 `draft`，其餘保留；spec/05 §4.5 情境 (a)）；相依死結同樣局部退回
  TDD（S11 的 R3 改版：根因在相依圖）；`targetPhase` 為 `"spec"` 或更早 →
  全量退回（情境 (b)）。
- **承諾點**：否。全部票證 `merged` 後自動接續 Review。

#### 3.6 Review（承諾點三）

- **目的**：對照 spec 與票證，對整個工作單位（單位分支相對 main 的整體
  diff，Q12）做多視角整體審查（PROMPT）。
- **進入條件**：所有票證 `merged`。
- **產物**：`changes/<unit>/review.md`（輪次摘要、blocking／non-blocking
  findings、自動處置歷史、prototype 零依賴查核結果）。
- **品質迴圈（重型，上限 5 輪，Q29）**：三個 `reviewer` lens 平行（gap／
  edge-case／spec-compliance，互不可見）＋一個 `reviewer` triage 逐條親自
  重查、不採信自報嚴重度（research 04）——四次派工都是同一個 `reviewer`
  agent 的不同角色簡報（R5）。compliance lens 查核正式路徑對
  `changes/<unit>/prototype/` 零依賴（Q35，違反＝blocking）。
- **Blocking finding 自動處置（R3，取代 S1 的全量呈現裁決）**：
  `targetPhase` 為較早 phase → waterfall 退回（`qualityLoops.review.rounds`
  跨退回**保留**，五輪上限是持久預算）；`targetPhase: "build"` → 主 session
  自建修正用 worktree（`ticket/review-fix-<round>`）派**全新** `worker` 一次
  處理全部此類 finding，合併後重跑完整一輪（S1 的修正機制本體保留，觸發改
  自動）。無 blocking finding 才進承諾點。
- **承諾點**：是（R2）。呈現 `review.md` 與剩餘 non-blocking 清單（知情後
  暫緩），核准後 `gates.review` 寫入、commit、結束 session（R13）；續接
  session 進 Wrap。

#### 3.7 Wrap（全自動）

- **目的**：全自動收尾，合併與清理不留人工步驟（PROMPT、R1）。
- **進入條件**：Review 已核准；另需**全測試綠**（單位分支重跑完整套件，
  Q13）。
- **執行方式（Q25、R5）**：「執行—驗證」形態，非作者／審查迴圈——`worker`
  （wrap executor）逐動作執行，`reviewer`（Wrap 驗證模式，不適用
  quality-loop 契約）逐動作獨立查證是否真的發生；任一步失敗立即 ESC
  （`wrap-failure`），不重試、不自動回退（INV-9）。動作序列：前置測試 →
  合併進 main（`--no-ff`、不 push）→ delta 合併進主 spec（ADDED 附加／
  MODIFIED 覆寫／REMOVED 刪除）→ 歸檔 `archive/<date>-<unit>/` → 刪除單位
  分支與殘留 worktree → **合併後的 main 上重跑全測試**。合併後測試失敗的
  ESC 必須附「是否復原合併」問題，決定權交還使用者（S12）。
- **產物**：`archive/<date>-<unit>/wrap.md`（逐動作留痕：動作／執行結果／
  驗證結果／時間戳；`reviewer` 結論經主 session 轉交 `worker` 轉錄，不直接
  寫檔）。
- **承諾點**：否，全自動（PROMPT、Q13）。完成即流程結束，印出「已完成本地
  合併，尚未 push，請自行推送。」

---

### 4. 品質迴圈與 waterfall 退回

**分級迴圈（Q4）**：兩級，不對每個 phase 套最重機制、也不全部用最輕：

- **標準迴圈**（Explore／Prototype／Spec／TDD／Build 逐票證）：單一
  `reviewer` → 有問題退回原作者修 → 上限 3 輪 → 超限 ESC。
- **重型迴圈**（僅 Review）：三 lens 平行＋獨立 triage（BMAD 式，research
  04），上限 5 輪（Q29）。

**為什麼審查靠主 session 派工、不靠 hook**：`SubagentStop` hook 擋下後重試
的是同一個子代理（research 06 實驗一），無法達成「獨立於作者」；審查一律是
主 session 對 `reviewer` 的另一次獨立派工（INV-10）。

**Waterfall 路由（R3，本設計的核心機制）**：路由**只由 blocking finding
驅動**；non-blocking 不影響路由，隨修訂順帶處理或留待承諾點知情呈現。
`reviewer` 每條 finding 附 `targetPhase`（根因所在 phase）：

1. blocking findings 全部指向當前 phase → in-phase 退回原作者修正，輪數
   遞增（Build 用 `SendMessage` 續談；其餘重新派工附全部 findings）。
2. 任一 blocking finding 指向較早 phase → **自動退回**至其中**最早**的
   phase（`fallback(toPhase, reason)`，spec/05 §4.5）：FB 留痕（`decisions.md`
   ＋`state.json.fallbacks[]` 原子雙寫，INV-12）→ 撤銷下游 phase 與 gate
   狀態（局部退回 Build→TDD 時未受影響票證全部保留；`qualityLoops.review`
   的輪數預算跨退回保留）→ 既有產物保留為底稿修訂 → 重做、重過迴圈、承諾點
   **重新核准**（INV-8）→ 依序重走。不徵求同意、不上報。
3. 輪數超限（標準 3、重型 5）→ ESC（`round-limit`）。
4. 同一退回目標累計第 3 次 → 不執行退回，ESC（`fallback-limit`）。

**ESC 只剩三種（R3）**：`round-limit`／`fallback-limit`／`wrap-failure`。
原 `approved-artifact` 路由（Q5 的「根因在已核准產物一律上報」）廢止——
承諾點的重新核准與 fallback 上限取代了逐案裁決。使用者在承諾點提出的修改
不計輪（INV-7）；要求回到更早 phase 重做視同使用者發起的退回，走同一 §4.5
程序。

**測試合約（Q10，起點依 R2 改版）**：TDD 迴圈通過後票證測試檔即為合約，
Build 的 `worker` 不得修改（INV-2）；測試檔被改或測試本身被判定有誤，一律
`targetPhase: "tdd"` 自動退回（不再是 ESC 上報）；受影響票證重置 `draft`、
重過 TDD 迴圈後合約重新生效。

**審查者輸出契約**：定義於 `references/quality-loop.md`（spec/04 §5）——
標準迴圈輸出單一 JSON（`verdict`／`findings[]`，每條含 `severity`／
`targetPhase`／`evidence`；`reject` 若且唯若存在 blocking finding）；Review
分 raw-finding 層（lens，無 verdict、`reportedSeverity` 僅供參考）與 triage
裁定層。原設計「格式契約待補」已於規格對齊時定案。

**留痕**：FB 條目與 ESC 條目模板定於 `spec/02` §2.3（Q31 模板依 R3 改版），
markdown 給人讀、`state.json` 對應陣列給機器判斷，兩處原子雙寫（INV-12）。

---

### 5. Agent 協作與派工

**兩個 agent 的定位（R5）**：

| Agent | 模型 | 定位 | 工具層保證 |
|---|---|---|---|
| `worker` | sonnet | 作者／機械執行：調查、實驗、spec、票證＋測試、實作、wrap 執行 | 不持有 `Agent` tool（禁巢狀派工） |
| `reviewer` | opus | 獨立審查：迴圈審查、Review lens／triage、Wrap 逐動作驗證 | `disallowedTools: Write, Edit` 唯讀（實測有強制力，research 11 §3）；不持有 `Agent` tool |

原 Q33 的 17 角色模型指派表廢止，模型分級收斂為兩級；原 haiku 級機械角色的
工作落到 sonnet／opus，成本上升是收斂為兩個 agent 的明確取捨（spec/03 通則
6，第 8 節）。

**派工語法**：Agent tool，`subagent_type` 填 `agent-flow:worker`／
`agent-flow:reviewer`（research 05 實驗二）；prompt 依角色簡報五要素（第 2
節）。範例：

```
Agent(subagent_type="agent-flow:worker",
      description="Write delta spec for 2026-09-10-password-reset",
      prompt="Role: spec author. First Read <abs>/references/sdd-guide.md.
              Inputs: changes/2026-09-10-password-reset/explore.md and
              (if present) prototype.md, plus .agent-flow/specs/<domain>/spec.md.
              Write changes/2026-09-10-password-reset/spec-delta.md following
              the EARS and ADDED/MODIFIED/REMOVED contract.")
```

**輸出落地檔案、只傳輕量引用（research 04）**：prompt 一律傳檔案路徑不貼
內容；子代理只回「結論摘要＋讀寫路徑清單」；審查回傳必須是 quality-loop
JSON 契約。

**平行度依票證相依圖（Q11、Q32）**：票證 frontmatter 的 `dependsOn` 是權威
來源，`state.json.tickets` 為鏡像；波次計算與 20 並行上限分批見第 3.5 節與
`references/dispatch.md`。平行審查互不可見（INV-10）。

**續談與 worktree 生命週期（R12、research 07／13）**：Build 退回修正首選主
session 親自 `SendMessage` 續談原 `agentId`（保留其已建立的理解）；不可
委派中介子代理發起續談（完成通知只回主 session）。R12 之後 worktree 由主
session 自建持有，原 agent 不可定址時可改派全新子代理進同一 worktree、工作
不遺失——「重新派工＝全新 worktree、實作全失」的舊前提（research 06 實驗四，
`isolation` 機制時代）已不成立，INV-3 相應放寬；但同一張票證不得建立第二個
worktree（INV-13）。

**巢狀深度**：主 session（第 0 層）→ `worker`／`reviewer`（第 1 層），到此
為止；子代理不再往下派（INV-10；呼應 research 04「禁止 implementer 自己生
reviewer」的教訓）。

---

### 6. 狀態外部化

**目錄結構**（Q6／Q22／Q28；完整規格 `spec/02`）：

```
.agent-flow/
├── .gitignore                      # 內含 worktrees/（R12，見第 7 節）
├── specs/                          # 主 spec（已合併、反映現況）
│   └── <domain>/spec.md            # 依領域分域，粒度由專案自訂（Q24）
├── changes/                        # 進行中的工作單位（Q22）
│   └── <unit-name>/                # <YYYY-MM-DD>-<slug>（Q28）
│       ├── state.json              # 狀態檔（Q21）
│       ├── explore.md              # R1 合併後：意圖＋調查＋疑問清單
│       ├── prototype.md            # optional
│       ├── prototype/              # 實驗碼，進版控（Q18）
│       ├── spec-delta.md           # ADDED/MODIFIED/REMOVED（Q8）
│       ├── tickets/<ticket-id>.md  # TDD 產物
│       ├── review.md
│       ├── wrap.md
│       └── decisions.md            # FB／ESC 留痕
└── archive/
    └── <date>-<unit-name>/         # changes/<unit-name>/ 完整快照
```

**state.json schema v2**（Q21／Q30 承襲結構，R1–R3 改版遞增版本；完整欄位表
`spec/02` §2.2）：`schemaVersion: 2`（S7：讀取前檢查，不符即停止回報）；
`phases` 七 key；`gates` 三 key（`explore`／`spec`／`review`）；
`qualityLoops`（key 為 phase 名或 `build:<ticket-id>`）；`tickets` 鏡像；
**`fallbacks[]`（R3 新增）**——每次 waterfall 退回一筆 `FB-<n>`，記
`fromPhase`／`toPhase`／`reason`／`round`；`escalations[]` 的 `rootCause`
枚舉縮減為三值。只由驅動流程的主 session 寫入（INV-1），整份讀出→修改→
覆寫，寫入前重讀最新內容。

**票證 `status` 枚舉**（S5 結構承襲、R1／R2 改名）：`draft` → `ready`
（原 `approved`——無 gate，TDD 迴圈通過即整批轉入）→ `in_build`（原
`in_dev`）→ `in_review` → `merged`；`escalated` 為輪數超限等待裁決。
frontmatter 為權威、`state.json` 同步鏡像（Q32）。

---

### 7. 版本控制（VCS）

**兩層分支（Q12、R12）**：每個工作單位一條 `flow/<unit-name>` 從 main 切出；
票證層由主 session 自建 worktree——`git worktree add -b ticket/<id>
.agent-flow/worktrees/<id> flow/<unit-name>`，分支名 `ticket/<id>` 由主
session 直接命名、來源分支由參數直接指定（R12 取代 `isolation: "worktree"`
機制——該機制的分支名不可控、worktree 不可重用、且分岔基準依賴
`worktree.baseRef` 專案設定；research 12 證實該設定是舊機制的必要前置，R12
以自建 worktree 徹底取消這個前置條件）。Review 審單位分支相對 main 的整體
diff（Q12），Wrap 再合回 main（Q13），main 隨時保持乾淨。

**Worktree 生命週期（R12、research 13）**：建立於 `.agent-flow/worktrees/
<ticket-id>`；`.agent-flow/.gitignore` 必須含 `worktrees/`（缺這行
`git add -A` 會把 worktree 當 embedded git repository 加入索引，research 13
§3）；生命週期由主 session 持有——合併後**立即** `git worktree remove`
（必要時先 `unlock`），不依賴自動清理；Build 與 Review 不共用 worktree
（Review 的修正派工另建 `ticket/review-fix-<round>`）。

**Commit 時機（Q34）**：phase 品質迴圈通過即 commit（訊息
`flow(<unit>): <phase> passed review`），單位分支歷史即 phase 進度記錄；
Build 一票一 commit、合併 `--no-ff` 不 squash；Wrap 合併進 main 保留逐票證
歷史。Waterfall 退回不回退已合併的 commit（spec/05 §4.5 步驟 5 通則）——
重走時只處理受影響票證，未受影響者直接視為 `merged`。

---

### 8. 已知取捨

**Token 成本 4–15 倍（research 04）**：多 agent 協作的固有成本。緩解手段：
兩級模型（sonnet 作者／opus 審查，R5）；平行度依相依圖與複雜度分級（Q11）；
輸出落地檔案只傳引用（第 5 節）。

**兩個 agent 的模型成本（R5、spec/03 通則 6）**：原 haiku 級機械角色
（wrap-executor／wrap-verifier）的工作落到 `worker`（sonnet）與 `reviewer`
（opus），成本高於 17 agent 舊設計——這是收斂的明確取捨，不另設第三個
agent。

**承諾點斷 session 的操作成本（R13）**：每過一個承諾點使用者要開新 session
續接，多兩次手動動作。換來的是不依賴任何未記載的 context 偵測機制（research
14：model 無法得知自己剩餘 context）、續接一律走 `state.json` 這條已存在的
路徑。候選過的替代方案（核准後詢問、減量微調、hook 注入用量）皆不採。

**validate 檢查很淺（research 05／10）**：不查未知欄位、不查 agent 禁用
欄位、完全不涉及 `references/`——由 `scripts/mechanical-check.sh` 補強
（spec/01 §2.5.2），兩道 validate 與機械檢查都要跑。

**Q18 實驗碼進版控的清理紀律（Q35）**：`prototype/` 位於
`.agent-flow/changes/<unit>/` 下、不在正式原始碼路徑，「不進正式產品」理解
為「不被生產程式碼依賴」而非「不留在 repo 歷史」；Review 的 compliance lens
查核零依賴（違反＝blocking）；Wrap 隨單位整包歸檔、不做進一步整合。

**Agent 撞名風險不成立（R11 修正 Q36 的風險敘述）**：實測（research 11
§2）同名的使用者專案 agent 只佔裸名，plugin 版維持 `agent-flow:<name>`，
兩者並存、不覆蓋——原「靜默覆蓋」的風險敘述作廢，Q36「不做啟動掃描」因風險
消失而自然成立。殘留風險只有派工紀律一種：主 session 把派工目標誤寫成裸名
時會打到使用者自己的 agent，故 `dispatch` 原語明文規定一律用命名空間形式。

**設計總覽與 spec/ 的雙源同步成本（R14）**：本文與 `spec/` 描述同一套設計，
每次影響設計結構的裁決都要回寫本文（`spec/README.md`「DESIGN.md 回寫
記錄」），否則會再度走鐘——這是 R14 選擇「整體改寫對齊」而非「只留訪談
記錄」的明確代價；矛盾時一律以 `spec/` 為準。

---

### 9. 完整旅程與文案

**安裝**（Q17）：

```bash
$ claude plugin marketplace add wiasliaw/agent-flow
$ claude plugin install agent-flow@agent-flow
```

安裝後可用 `/agent-flow:orchestrate` 與七個 `/agent-flow:<phase>`（user
scope 為主情境，Q17）。

**旅程範例**：既有專案（brownfield）加上「忘記密碼」流程，工作單位
`2026-09-21-password-reset`。

1. 使用者輸入 `/agent-flow:orchestrate 幫使用者加上忘記密碼流程`。主 session
   讀 glossary，建立 `.agent-flow/changes/2026-09-21-password-reset/`（含
   `.agent-flow/.gitignore`）、初始化 `state.json`、切出分支
   `flow/2026-09-21-password-reset`，進入 Explore。
2. **Explore（承諾點一）**：主 session 發散提問（「目前忘記密碼的痛點？」），
   派 `worker` 調查現有帳號／email 機制與外部套件，再收斂為選項式問題
   （「重設連結有效期？1. 15 分鐘 2. 1 小時 3. 24 小時」）。`reviewer` 審查
   通過後呈現摘要＋調查結論＋疑問清單，使用者核准 → 寫 gate、commit、
   **session 結束**（R13），提示開新 session 續接。
3. **（新 session）Prototype（自動，視情況）**：續接 session 讀
   `state.json`；疑問清單非空（如「現有 email 服務的 rate limit 夠不夠」）
   則派 `worker` 寫丟棄式腳本量測，`reviewer` 重跑驗證；無疑問則標記
   `skipped` 直接進 Spec。
4. **Spec（承諾點二）**：`worker`（spec author）依 EARS 寫 `spec-delta.md`，
   `reviewer` 審查通過後呈現全文，使用者核准 → 寫 gate、commit、session
   結束。
5. **（新 session）TDD（自動）**：`worker`（test author）切票證（TICKET-001
   產 token、TICKET-002 寄 email、TICKET-003 重設頁），每張附實際執行確認
   紅燈的測試；`reviewer` 整批獨立重跑。迴圈通過 → 票證轉 `ready`、測試
   合約生效、自動接續 Build——**不停等核准**（R2）。
6. **Build（自動）**：主 session 算相依圖，TICKET-001 無相依先跑：自建
   worktree `ticket/TICKET-001` 後普通派工 `worker` `cd` 進去實作；
   `reviewer` 進同一 worktree 重跑測試。退回修正走 `SendMessage` 續談；通過
   即合併（`--no-ff`）、立即移除 worktree，解鎖 TICKET-002／003 平行跑。
   若審查發現測試本身有誤 → 自動局部退回 TDD（FB 留痕），修完自動回來。
7. **Review（承諾點三）**：三 lens 平行＋triage 審整體 diff。若有
   `targetPhase: "build"` 的 blocking finding，自建 `ticket/review-fix-1`
   worktree 派全新 `worker` 修正後重跑一輪。無 blocking 後呈現：「2 個非
   阻斷建議，視為知情後暫緩。是否核准進入 Wrap？」核准 → 寫 gate、commit、
   session 結束。
8. **（新 session）Wrap（全自動）**：`worker` 逐動作執行：跑全測試 → 合併進
   main → delta 併入 `.agent-flow/specs/auth/spec.md` → 歸檔 → 刪分支與
   殘留 worktree → 合併後重跑測試；`reviewer` 逐動作獨立查證。完成後印出
   「已完成本地合併，尚未 push，請自行推送。」

**External skill（8 個）的一句話文案（英文，plugin 內容；現行版本，定於
`spec/05`–`12` 各檔 frontmatter）**：

| Skill | Description |
|---|---|
| `orchestrate` | Drives the seven phases in sequence, pausing at the three approval gates and ending the session after each approval — a fresh session resumes from state.json — while falling back automatically to the faulty phase when a review finds its root cause upstream. |
| `explore` | Runs a Socratic dialogue to pin down intent while investigating the codebase and external options for feasibility, then asks for your approval before anything gets specified. |
| `prototype` | Answers open technical questions with throwaway experiments, capturing the question, approach, and evidence — never the code itself. |
| `spec` | Turns the approved findings into an EARS-format delta spec, numbered for traceability, and asks for your approval before tests get written. |
| `tdd` | Splits the approved spec into verifiable tickets, each shipped with a real, currently-failing test that becomes the build contract once the review loop passes. |
| `build` | Implements ready tickets in parallel, one isolated worktree per ticket, until every contract test goes green and passes independent review. |
| `review` | Runs a multi-perspective audit of the whole unit against its spec and tickets, auto-fixing or falling back on blocking findings, then asks for your approval before wrap-up. |
| `wrap` | Merges, archives, and cleans up fully automatically once review is approved and every test is green — commits locally, never pushes. |

原 Q40 核准的 internal skill 六句文案隨 R4 作廢——`references/` 是純
markdown 文件，無 frontmatter、無 description；何時讀哪一份由派工簡報指名
（第 2 節清單總表）。

---

### 10. 殘餘待驗證事項

**無。** 原版本節的兩項平台查證（巢狀 skills 分組目錄、`user-invocable:
false` 機制）隨 R4 廢止 internal skill 而失去對象。重構後新增的平台假設均已
實驗證實並記錄於 `context/research/`：

- validate 的目標解析與遞迴行為（research 10，R7／R8 依據）。
- Agent 命名空間並存、`disallowedTools` 強制力、裸名規則（research 11，R11
  依據）。
- 主 session 自建 worktree 的派工／續談／合併／清理全流程（research 12／
  13，R12 依據；S13 的實作前置驗證要求已由此證實）。
- Model 無法偵測自身剩餘 context——動態斷點不可行（research 14，R13 依據）。

平台行為存疑時的處理方式依 `.claude/CLAUDE.md`：不猜，做小實驗，結論寫進
`context/research/` 並附來源 URL。
