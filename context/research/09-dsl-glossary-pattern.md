# 09 — Skill 撰寫的 pseudo-code DSL 術語表模式（改進研究，2026-09-09～10 補做）

## 定位與方法

本檔與 01–08 不同：不是外部文件調查，而是對本 repo 已實作的 15 個 skill 做的
**內部分析**，加上一項本機 CLI 實測。外部來源僅止於 research/01–08 既有記載，
本檔未另查官方文件或先行案例；凡涉及平台行為的主張，均以本機實測為據並附
CLI 版本。產出即 `spec/14-glossary.md` 與 `skills/internal/glossary/SKILL.md`
（裁決 G1–G3，記錄於 `spec/README.md`）。

## 1. 問題診斷（改進動機）

對實作完成的 9 個 external skill（合計 2038 行）逐檔分析，發現兩類結構性問題：

1. **散文程序的重複**：同一套程序在多個 skill 以散文全文重複——工作單位判定
   三步驟出現在 5 個 phase skill；「reject 後依 rootCause 分流」的路由敘述在
   幾乎每個 phase 重述一次；worktree 前置檢查在 `orchestrate` 與 `dev` 各寫
   一份。散文重複的維護風險是**措辭漂移**：多份副本各自演化，語意逐漸分歧。
2. **隱性不變量散落**：約 16 條跨 phase 的硬性規則（state 單一寫入者、已核准
   產物不可改、測試合約、續談規則、輪數上限……）散落在各 skill 與 internal
   skill 的行文中，措辭不一、無編號、無單一權威位置。LLM 執行時無法機械地
   確認「這一步受哪條規則約束」。

## 2. 模式描述

採用的模式（使用者提出的原始構想：以 pseudo-code 格式提示 LLM，並把 keyword
彙整成術語表）展開為四個構件：

1. **Pseudo-code 程序區塊**：external skill 的控制流一律以 DSL 區塊表達——
   `name(args)` 為 primitive 或共用程序、`if <條件>:` 為守衛、`值 -> 動作`
   為 match 分支、`# INV-n` 註記該步受哪條不變量約束。散文只保留區塊管不到的
   內容（使用者可見文案、產物格式、rationale）——「散文管內容、區塊管控制流」。
2. **術語表（glossary）internal skill**：primitives（`dispatch`／`gate`／
   `escalate`…）、變數（`$unit`…）、共用程序（`resolve_unit()`／
   `standard_loop()`…）與語法解讀規則集中定義一次，主 session 執行任何
   external skill 前先載入。
3. **編號不變量清單（INV-1～INV-16）**：跨檔規則收斂為帶編號條文，例外只能寫
   在 INV 自己的條文內；DSL 區塊以 `# INV-n` 引用而不重抄。16 條全部溯源自
   既有裁決，清單本身不新增決策（逐條溯源見 `spec/14-glossary.md` 已定節）。
4. **封閉世界規則（closed-world rule）**：無分支適用、或前置條件無法判定時，
   不得自行發明路由——`halt` 並向使用者呈現狀況。這是 DSL 化後對「LLM 自由
   發揮」風險的總防線：散文程序被壓縮後，模型填補空白的誘因上升，必須以顯式
   規則堵住。

### 關鍵設計取捨：internal skill 自足性

角色 agent 只 preload 自己需要的 internal skill、看不到 glossary，因此六個既有
internal skill 的規則**全文保留**，僅在規則處加 `(INV-n)` 對照標籤；glossary 與
internal skill 之間存在**受控重複**（同一規則兩處有文字，讀者不同：主 session
vs 子代理），以 INV 編號作為語意同步點。替代方案「internal skill 也改為裸 INV
引用」被否決，因為那會迫使所有角色 agent 額外載入 glossary，擴大每個子代理的
context 而收益只有去重。

## 3. 成效量測（行數）

改寫前後 external skill 行數（wc -l，含 frontmatter）：

| skill | 前 | 後 |
|---|---|---|
| orchestrate | 368 | 198 |
| discuss | 196 | 123 |
| explore | 139 | 122 |
| prototype | 149 | 130 |
| spec | 183 | 117 |
| ticket | 230 | 181 |
| dev | 270 | 170 |
| review | 279 | 184 |
| wrap | 224 | 159 |
| **合計** | **2038** | **1384** |

新增 `glossary/SKILL.md` 234 行（主 session 載入一次、9 個 skill 共攤）。
語意保全（S1–S13 裁決全數保留）在改寫時逐檔人工比對；**尚未做過獨立的語意
稽核與 end-to-end 遵循度實測**——這是本模式目前最大的未驗證項。

## 4. 實測觀察：per-directory `claude plugin validate` 行為變化

- **環境**：Claude Code CLI 2.1.259，本機（2026-09-10）。
- **觀察**：`claude plugin validate ./skills/external` 與
  `claude plugin validate ./skills/internal` 均失敗，訊息為
  `No manifest found in directory. Expected .claude-plugin/marketplace.json
  or .claude-plugin/plugin.json`；repo 根目錄的 `claude plugin validate .`
  通過（僅驗證 marketplace manifest）。
- **矛盾**：`spec/01-plugin-structure.md` §2.5.1 記載的 per-directory validate
  程序（validate 表）預期子目錄可獨立驗證。與本次改寫無關——改寫前後行為相同。
- **判定**：以實測為準，spec/01 的 per-directory 程序在現行 CLI 下不可用。
  是官方行為變更還是當初記載有誤，**未查證**（未查官方 changelog）；spec/01
  §2.5.1 的修訂是獨立工作項，尚未處理。
- **後續（2026-09-14，`research/10` 已查明並結案）**：成因不是版本變更，而是
  **目錄 basename 規則**——basename 必須是 `skills`／`agents`／`commands` 才會走
  元件驗證，`external`／`internal` 這類分組名一律被當成 plugin 根目錄找 manifest
  而失敗。R4 平鋪後本 repo 已無分組目錄，限制不再適用。`spec/01` §2.5.1 已依
  `research/10` 改寫（裁決 R7）。

## 5. 未驗證項目

| 項目 | 原因 |
|---|---|
| 主 session 對 DSL 區塊的實際遵循度（封閉世界規則、`standard_loop` 展開） | 需要在 /tmp 測試專案跑完整 phase 流程，尚未執行 |
| 改寫後 skill 的語意流失／漂移 | 需要獨立稽核（逐檔 diff 對照 spec/06–13），尚未執行 |
| glossary 234 行常駐主 session context 的成本效益 | 未量測 token 影響 |
