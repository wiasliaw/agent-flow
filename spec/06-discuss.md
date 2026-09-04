# 06 — `discuss` Phase Skill 規格

## 已定（來源與依據）

- **PROMPT.md**：「Discuss：以蘇格拉底提問訪問談話者，確認使用者意圖。」
- **Q16**：先發散後收斂——前半自由對話探索意圖（開放式提問），後半選項式逐項收斂，最後產出意圖
  摘要。
- **Q3**：Discuss 是四個承諾點之一，使用者核准後才進入 Explore。
- **Q4**：標準迴圈，單一審查者，上限 3 輪。
- **Q2**：phase skill 可單獨呼叫，不強制經 `orchestrate`。
- **Q28**：工作單位命名規則（Discuss 若是流程起點，需自行建立工作單位）。
- **DESIGN §2「主 session 唯一的例外」**：Discuss 的對話環節必須由主 session 直接進行，不委派給
  子代理——這是 PROMPT「主 session 只負責調度」原則下唯一的必要例外，範圍嚴格限於「與使用者
  對話、產出摘要」本身；審查仍委派給獨立的 `intent-reviewer` 子代理。
- **DESIGN §3.1**：Discuss 的目的、進入條件、產物、品質迴圈、承諾點完整定義。
- **spec/03-agents.md 第 1 節**：`intent-reviewer` 的完整 frontmatter 與職責規格，本檔直接引用。
- **spec/04-internal-skills.md `quality-loop` 一節**：審查者輸出格式契約，本檔審查步驟依此格式
  具體化。
- **spec/05-orchestrate.md §2.3、§3.1**：工作單位建立程序、承諾點呈現行為的通則，Discuss 作為
  流程起點與唯一的對話型 phase，在此基礎上補充自己的細節。
- **S8 裁決**：重新呼叫已核准 Discuss → 拒絕並提示需明確意圖，照本檔原選項 (a) 定案。

---

## 規格本文

### 1. Frontmatter

檔案路徑：`skills/external/discuss/SKILL.md`。

```yaml
---
name: discuss
description: >-
  Runs a Socratic dialogue with you to pin down intent before any spec or
  code gets written, then asks for your approval before moving on.
---
```

`description` 逐字採用 DESIGN §9 表格文案（Q40 核准）。不設 `context: fork`（理由同
spec/05-orchestrate.md §1：對話環節必須發生在主 session，fork 出去的子代理無法與使用者多輪
即時往返）。

### 2. 觸發與前置條件

Discuss 是流程起點，**無前置 phase 產物依賴**（DESIGN §3.1）。觸發方式：

- 經 `orchestrate` 驅動：`orchestrate` 已完成工作單位建立（spec/05-orchestrate.md §2.3），
  直接進入本節「程序步驟」。
- 使用者直接呼叫 `/agent-flow:discuss`（Q2，不經 `orchestrate`）：本 phase skill 自己判斷是否
  已存在目標工作單位——
  - 若使用者訊息未指明任何既有工作單位、或目前所在分支不是任何 `flow/<unit-name>`：視為建立
    新工作單位，執行與 spec/05-orchestrate.md §2.3 完全相同的建立程序（單位命名、目錄、
    `state.json` 初始化、切分支）——這段邏輯在「單獨呼叫」情境下由本 phase skill 自己承擔（因為
    當下沒有 `orchestrate` 在運作，spec/05-orchestrate.md §7 已定此原則）。
  - 若已指明既有工作單位且該單位的 `discuss.md` 已存在且已通過 Discuss 承諾點：**拒絕重新
    執行**（S8 裁決），回報使用者：「此工作單位的 Discuss 已核准，如需修改請明確要求『修改
    已核准的 Discuss 摘要』」，不自動進入發散/收斂對話，避免「重跑同名指令」意外覆寫已核准
    產物（呼應 Q5「已核准產物不可自行推翻」的精神，即使觸發者是使用者本人，也要求明確意圖而
    非讓指令重跑本身觸發覆寫）。使用者若之後明確要求「修改已核准的 Discuss 摘要」，比照
    `spec/05-orchestrate.md` §3.1「使用者主動修改已核准產物」機制處理：重新進入發散/收斂
    對話、完成後重新走一次品質迴圈與承諾點核准，並在 `changes/<unit>/decisions.md` 留痕
    （根因分類填「使用者主動修改」，非標準 ESC 上報）。

### 3. 程序步驟

1. **發散階段（Q16 前半）**：主 session 直接與使用者進行開放式提問（例如「目前這個功能的痛點是
   什麼？」「有沒有既有的相關機制可以參考？」），不限定選項、鼓勵使用者自由描述意圖、痛點、
   限制條件。主 session 逐輪記錄問答內容。發散階段沒有固定輪數，由主 session 判斷「意圖是否已
   足夠清晰、可以進入收斂階段」——判斷依據為：能否針對使用者意圖提出具體、可回答「是/否」或
   「選項 1/2/3」形式的收斂問題；若還做不到，繼續發散提問。
2. **收斂階段（Q16 後半）**：主 session 針對發散階段浮現的關鍵決策點，逐一提出選項式問題（一次
   一題，附建議選項，呼應 DESIGN.md 訪談本身採用的格式），例如「重設連結的有效期？1. 15 分鐘
   2. 1 小時 3. 24 小時」。使用者逐題回答。
3. **產出意圖摘要**：主 session 將發散與收斂階段的內容整理為結構化摘要，寫入
   `changes/<unit>/discuss.md`（見 §4 產物格式）。
4. **委派審查**：`orchestrate`（或單獨呼叫情境下的本 phase skill 自身）用 Agent tool 派工
   `agent-flow:intent-reviewer`（spec/03-agents.md 第 1 節），prompt 附上
   `changes/<unit>/discuss.md` 路徑與目前輪次（`round`/`maxRounds: 3`）。
5. **讀取審查結果**：依 spec/04-internal-skills.md `quality-loop` 定義的 JSON 格式解析
   `verdict`：
   - `"pass"`：進入 §5 承諾點呈現。
   - `"reject"`：`findings[].rootCause` 對 Discuss phase 而言恆為 `"implementation-issue"`
     （Discuss 尚未核准，不存在「根因在已核准產物」這種情況，因為 Discuss 本身就是這個工作單位
     第一個承諾點，之前沒有其他已核准產物可以作為根因——此為 Discuss phase 的特例，其餘 phase
     的審查者仍需完整判斷 `rootCause`，但 Discuss 的審查者收到的派工 prompt 應明確告知這一點，
     避免產生無意義的 `approved-artifact` 判定）。主 session 依 `findings` 內容，針對性地向
     使用者補問（回到發散或收斂階段，視 finding 性質而定），修訂摘要後回到步驟 4。
6. 上限 3 輪（Q4）：第 3 輪仍為 `reject`，依 spec/05-orchestrate.md §4.6 轉為 ESC 上報——但
   DESIGN §3.1 原文對 Discuss 有一個更貼近其性質的替代描述：「仍未通過則列成待確認項目，隨摘要
   一併交給使用者裁決」，這與標準 ESC 上報流程（§4.6）的差異在於：Discuss 的「上報」本質上就是
   直接把待確認項目攤開給使用者看（因為下一步本來就是使用者核准的承諾點），不是一個獨立於承諾點
   呈現之外的中斷。本規格採用的做法：第 3 輪仍未通過時，**仍然**依標準流程寫入 ESC（`decisions.md`
   ＋ `state.json.escalations`，保持與其他 phase 一致的可稽核性），但呈現方式與 §5 承諾點呈現
   合併——在呈現意圖摘要供核准時，一併列出「待確認項目」段落（引用該筆 ESC 的內容），使用者的
   核准回應可以同時視為對這些待確認項目的裁決。

### 4. 產物

`changes/<unit>/discuss.md`，固定三個章節：

```markdown
# Discuss：<unit-name>

## 發散階段紀錄

<逐輪問答，開放式提問與使用者回答的紀錄>

## 收斂階段選項與回答

### Q1：<選項式問題>
**選項**：1. ... 2. ... 3. ...（附建議）
**回答**：<使用者選擇與補充>

（依此格式列出全部收斂問題）

## 意圖摘要

<整理後的意圖描述，供 intent-reviewer 審查與使用者核准>
```

此格式呼應 DESIGN.md 自身訪談記錄的格式（開放式研究背景 + 選項式提問 + 回答），確保 agent-flow
自己產出的 Discuss 摘要與其設計文件的撰寫方式一致、可追溯。

### 5. 品質迴圈

標準迴圈（Q4）：`intent-reviewer` 獨立審查 → 有問題主 session 補問使用者、修訂摘要 → 上限 3 輪 →
第 3 輪仍未通過則列成待確認項目，隨摘要一併交給使用者裁決（§3 步驟 6）。

### 6. 承諾點呈現

依 spec/05-orchestrate.md §3.1 通則，Discuss 的具體呈現內容：

1. 呈現「意圖摘要」章節全文（若有第 3 輪仍未解決的待確認項目，一併呈現）。
2. 提出：「以下是我理解的意圖：<摘要>。是否核准進入 Explore？」
3. 使用者核准：`state.json.gates.discuss = {"approvedAt": <now>, "approvedBy": "user"}`，
   commit（`flow(<unit>): discuss passed review`），`discuss.md` 成為已核准產物（自此適用
   Q5、Q10 的不可推翻原則）。
4. 使用者提出修改：回到 §3 步驟 5 對應的修訂流程（不計入標準迴圈輪數，因為這是使用者直接介入，
   非審查子代理退回）。

### 7. 單獨呼叫（不經 `orchestrate`）時的行為

- 前置條件：無（Discuss 是流程起點），故單獨呼叫 `discuss` 不需要檢查任何前一 phase 產物是否
  存在。
- 完成後：**不**自動接續 Explore（Q2：接續邏輯屬於 `orchestrate`，phase skill 本身不含接續
  邏輯）。呈現承諾點核准訊息後，若使用者核准，可額外提示「意圖已核准，可用 `/agent-flow:explore`
  繼續，或 `/agent-flow:orchestrate` 接手後續自動接續」——此提示文字為建議性質，不影響
  `state.json` 的正確性（gate 已核准的狀態，之後不論是被 `orchestrate` 或使用者手動呼叫
  `explore` 接續，讀到的 `state.json` 都是一致的）。

---

## 待對齊

無。原第 1 項（重新呼叫已核准 Discuss 的行為）已由 S8 裁決採選項 (a) 定案，改寫進「觸發與
前置條件」一節規格本文。
