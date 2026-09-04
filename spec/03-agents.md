# 03 — Agent 定義檔規格

## 已定（來源與依據）

- **檔案數量的落差說明**：DESIGN.md 第 5 節「角色清單與模型指派」表格以 15 列呈現，但其中一列
  `review-gap-hunter` / `review-edge-case-hunter` / `review-spec-compliance-auditor`
  用 `/` 合併書寫三個獨立角色（DESIGN §3.7、§2 架構圖皆明確描述這是「三個獨立審查子代理平行運作」）。
  展開後 agent 定義檔實際共 **17 個**，非 15 個。這不是設計矛盾，只是表格書寫方式的計數落差，
  本檔案依實際檔案數逐一規格化。
- 三類角色（作者／審查／機械）與其「獨立於作者」原則：DESIGN §2「角色子代理分三類」、PROMPT
  原文「每個 phase 結束時由獨立於作者的角色跑一次品質檢查迴圈」。
- 品質迴圈由 orchestrator 派審查子代理達成、不是靠 hook：DESIGN §4；research 06 實驗一（引用於
  DESIGN §4）。
- 分級迴圈與根因分流二分法：Q4、Q5；標準迴圈上限 3 輪、Review 重型迴圈上限 5 輪：Q4、Q29。
- 測試合約（Dev 不可改測試，錯了上報）：Q10、DESIGN §3.6、§4。
- Dev phase 執行機制（`isolation: worktree`、平行度依相依圖）：Q11、DESIGN §3.6、§5、§7；
  worktree 分岔基準必要條件：research 07 Test B。
- Dev 退回機制（orchestrator 親自 `SendMessage` 續談同一個 `dev-worker`）與其兩個限制：
  research 07 Test A，DESIGN §3.6、§4。
- 15/17 角色模型指派表（Q33 定案）：DESIGN §5。
- 六個 internal skill 的「誰在何時載入」欄位：DESIGN §2 表格（Q37–Q39 裁決）。
- Wrap 執行—驗證迴圈形態（Q25）與逐動作驗證紀律：DESIGN §3.8、§7。
- Plugin agent frontmatter 完整欄位表與 plugin 特有限制（**不支援** `hooks`／`mcpServers`／
  `permissionMode`）：research 01 §2.3、research 02 §1.1–1.2。
- `hooks` 欄位在 plugin agent 上完全不生效（實測）：research 05 實驗一 1a；`mcpServers`／
  `permissionMode` 保守假設不生效（未能測出，但文件與實測皆不支持生效）：research 05 實驗一 1b、1c。
- 巢狀派工上限與 agent-flow 的選擇（角色子代理不再往下派生審查者）：research 02 §2.2；
  DESIGN §5「巢狀深度」（呼應 research 04 對 Superpowers「明確禁止 implementer 自己生
  reviewer」的引用）。
- Review phase 重型迴圈三段式（平行蒐集 → 獨立驗證裁定 → 根因分流）：Q4、DESIGN §3.7；
  research 04 對 BMAD-METHOD 的記載（三／四層獨立審查、triage 不採信審查者自報嚴重度）。
- **S13 裁決**：`dev-reviewer` 於自己一般執行環境中 `cd` 進 `dev-worker` worktree 的設計維持
  不變，定為規格本文；「實作前必須優先用最小可行範例驗證此平台假設」的要求同樣保留、寫入
  規格本文（不是待裁決的待對齊項）。
- **S3 裁決**：Wrap 上報沿用 `spec/02-state.md`／`spec/04-internal-skills.md` 定案的 ESC 格式，
  `decisions.md` 模板「Phase／輪次」欄位在 Wrap 情境下填「Wrap（無輪次，執行—驗證迴圈）」，
  `state.json escalations[].phase` 合法值含 `"wrap"`。

## 規格本文

### 通則（適用全部 17 個 agent，不重複寫在每一節）

1. **檔案位置**：`agents/<name>.md`（plugin 根目錄，不放在 `.claude-plugin/` 內——
   research 01 §1.1「重要結構警告」）。
2. **一律不得出現的 frontmatter 欄位**：`hooks`、`mcpServers`、`permissionMode`。原因：
   plugin agent 明確不支援這三個欄位（research 01 §2.3、02 §1.2），`hooks` 已實測完全不生效
   （research 05 實驗一 1a），另兩個保守假設不生效。若日後需要這三者，必須改放專案層級
   `.claude/agents/*.md`（不在本次交付範圍內，DESIGN 未要求）。
3. **一律不得出現 `Agent` 工具**：17 個角色子代理都不再往下派生下一層子代理——「審查獨立於
   作者」永遠由 orchestrator（主 session）親自派工達成，角色子代理本身不巢狀派工（DESIGN §5
   「巢狀深度」）。因此以下所有 `tools:` 清單都不含 `Agent`。
4. **`state-management` internal skill 不被任何一個角色 agent preload**：DESIGN §2 表格
   將載入者定為「`orchestrate`（唯一寫入 state.json 者）；任何需要讀取工作單位進度的角色」。
   逐一檢視 17 個角色的職責後判斷：所有角色都只需讀寫自己這一輪委派範圍內的 markdown 產物
   （discuss.md／explore.md／spec-delta.md／票證檔／review.md／wrap.md），不需要直接讀寫
   `state.json`——票證相依關係的權威來源是票證 frontmatter 而非 state.json（Q32），迴圈輪次
   由 orchestrator 在派工 prompt 中直接告知（例如「這是第 2/3 輪」），不需要角色自己查
   state.json。因此本檔案 17 個角色皆不 preload `state-management`；下方每節不再重複此推理。
5. **`parallel-dispatch`、`using-worktree` 不被任何一個角色 agent preload**：兩者的載入者依
   DESIGN §2 表格都是「派工者」（orchestrator 本身，`using-worktree` 表格甚至明寫「僅
   `orchestrate`」），不是被派工的角色。17 個角色都是被派工的一方，因此都不 preload 這兩個
   internal skill；下方每節不再重複此推理。
6. **Model 一律照 Q33 定案表**（見下方逐節 frontmatter），不再另外設 `effort`／`color`等
   非 DESIGN 提及的欄位，避免無依據的臆造欄位。
7. **已知風險：agent 命名衝突會被靜默覆蓋，agent-flow 不做啟動時掃描檢查**（Q36、DESIGN §8）。
   Plugin agent 的 scope 優先序敬陪末座（managed > CLI `--agents` > 專案 `.claude/agents/` >
   個人 `~/.claude/agents/` > plugin `agents/`，research 01 §2.3、§7.4）：若使用者的專案或個人
   層級剛好存在與本檔任一 agent 同名的定義檔（例如 `.claude/agents/dev-worker.md`、
   `~/.claude/agents/spec-reviewer.md`），該檔會在使用者不知情的狀況下**悄悄取代**本檔對應的
   agent-flow 角色定義，品質迴圈與模型分級可能因此失效卻無任何警告或錯誤訊息。Q36 已裁決
   「不檢查」——`orchestrate` 不在啟動時掃描比對專案與個人層級 `agents/` 目錄，這是明確裁決過
   的已知取捨，不是本次規格對齊的遺漏；風險留給使用者自行注意本檔 17 個 agent 檔名
   （見下方總表）是否與專案／個人層級既有的 agent 定義撞名。
8. **`skills:` preload 對照總表**（推導過程見各節）：

   | Agent | 作者/審查/機械 | Model | `isolation` | `skills:` preload |
   |---|---|---|---|---|
   | `intent-reviewer` | 審查 | inherit | — | `quality-loop` |
   | `explorer` | 作者 | sonnet | — | （無） |
   | `explore-reviewer` | 審查 | opus | — | `quality-loop` |
   | `prototyper` | 作者 | sonnet | — | （無） |
   | `prototype-reviewer` | 審查 | opus | — | `quality-loop` |
   | `spec-writer` | 作者 | sonnet | — | `sdd-guide` |
   | `spec-reviewer` | 審查 | opus | — | `sdd-guide`, `quality-loop` |
   | `ticket-writer` | 作者 | sonnet | — | `sdd-guide`, `tdd-guide` |
   | `ticket-reviewer` | 審查 | opus | — | `sdd-guide`, `tdd-guide`, `quality-loop` |
   | `dev-worker` | 作者 | sonnet | `worktree` | `tdd-guide` |
   | `dev-reviewer` | 審查 | opus | — | `tdd-guide`, `quality-loop` |
   | `review-gap-hunter` | 審查 | opus | — | `quality-loop` |
   | `review-edge-case-hunter` | 審查 | opus | — | `quality-loop` |
   | `review-spec-compliance-auditor` | 審查 | opus | — | `sdd-guide`, `quality-loop` |
   | `review-triage` | 審查 | opus | — | `quality-loop` |
   | `wrap-executor` | 機械 | haiku | — | `sdd-guide` |
   | `wrap-verifier` | 機械/審查 | haiku | — | （無） |

---

### 1. `intent-reviewer`

- **檔名**：`agents/intent-reviewer.md`
- **依據**：Q3（Discuss 承諾點）、Q16（先發散後收斂）、DESIGN §3.1、§4。

```yaml
---
name: intent-reviewer
description: >-
  Independently reviews the Discuss-phase intent summary (discuss.md) for
  completeness and internal contradictions before the user is asked to
  approve it. Dispatched by the agent-flow orchestrator after the main
  session finishes the Socratic dialogue; not for automatic delegation.
model: inherit
tools: Read, Grep, Glob
disallowedTools: Write, Edit, Bash
skills: quality-loop
---
```

- **Frontmatter 理由**：`model: inherit` 依 Q33 定案（意圖判斷需要與主 session 相同水準的
  理解力，且訪談摘要通常不長，繼承主 session 模型不額外增加太多成本）。唯讀工具即可完成審查
  （不需 Bash，因為 discuss.md 是純文字摘要，沒有需要執行驗證的程式碼或測試）。`quality-loop`
  preload：本角色須輸出 04-internal-skills.md 定義的標準審查判定格式。
- **System prompt body 必須涵蓋**：
  - 只讀取 `changes/<unit>/discuss.md`（必要時可 Grep 專案既有文件確認訪談中提及的事實是否與
    專案現況矛盾），不得修改該檔案本身。
  - 檢查項目：發散階段的探索是否有明顯遺漏面向、收斂階段的選項式問答是否有邏輯矛盾、意圖摘要
    是否忠實反映使用者原話（不可摻入審查者自己的推論當作使用者意圖）。
  - 輸出必須是 `quality-loop` 定義的標準判定格式（verdict/findings/round 等）。
  - 明文：審查是否完整、有無矛盾的判斷，不能因為「摘要看起來合理」就放行——必須明確核對每個
    收斂階段問答是否都被摘要涵蓋。

---

### 2. `explorer`

- **檔名**：`agents/explorer.md`
- **依據**：Q1（greenfield/brownfield 皆支援）、DESIGN §3.2。

```yaml
---
name: explorer
description: >-
  Investigates the existing codebase (brownfield) and external technical
  options/documentation (greenfield or unfamiliar dependencies) to confirm
  the approved Discuss-phase intent is actually feasible, and writes
  explore.md. Dispatched by the agent-flow orchestrator after the Discuss
  gate is approved.
model: sonnet
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch, Write, Edit
---
```

- **Frontmatter 理由**：`model: sonnet` 依 Q33（作者類、研究型工作）。工具集需同時涵蓋內部
  程式碼調查（Read/Grep/Glob/Bash）與外部技術調查（WebFetch/WebSearch），並需要 Write/Edit
  寫出 `explore.md`。不 preload 任何 internal skill——explorer 的產物是自由格式的調查發現，
  不受 `sdd-guide`（EARS／delta spec 語法）或 `tdd-guide` 規範。
- **System prompt body 必須涵蓋**：
  - 只寫入 `changes/<unit>/explore.md`；讀取 `changes/<unit>/discuss.md` 作為調查範圍依據。
  - 內部調查（讀現有程式碼、既有測試、既有依賴）與外部調查（技術選項、官方文件、已知限制）
    都要覆蓋，依 Q1 兩情境皆支援的原則，不可只做其中一種。
  - 必須明確列出「未解決的技術疑問清單」，供 orchestrator 判斷是否需要進入 Prototype
    （DESIGN §3.3 進入條件依賴這份清單）。
  - 結論需附佐證（引用的檔案路徑或外部來源），不可只給沒有依據的斷言——這是
    `explore-reviewer` 審查的重點之一。

---

### 3. `explore-reviewer`

- **檔名**：`agents/explore-reviewer.md`
- **依據**：Q4（標準迴圈）、DESIGN §3.2。

```yaml
---
name: explore-reviewer
description: >-
  Independently reviews explore.md for obvious omissions and unsupported
  conclusions before the Explore phase auto-continues to Prototype or Spec.
  Dispatched by the agent-flow orchestrator; not for automatic delegation.
model: opus
tools: Read, Grep, Glob, Bash, WebFetch
disallowedTools: Write, Edit
skills: quality-loop
---
```

- **Frontmatter 理由**：`model: opus` 依 Q33（審查類）。保留 Bash／WebFetch 作為「查核」用途
  （例如驗證 explorer 宣稱某檔案存在、某 API 行為屬實），但 `disallowedTools: Write, Edit`
  明確禁止修改 explore.md 本身。
- **System prompt body 必須涵蓋**：
  - 逐條核對 explorer 的結論是否有可查證的佐證（檔案路徑是否真的存在、外部連結描述是否屬實），
    可主動用 Bash/WebFetch 抽查而非照單全收。
  - 檢查「未解決的技術疑問清單」是否合理完整——遺漏會導致 Prototype phase 被錯誤跳過。
  - 獨立於作者的判斷：不得因為 explorer 的敘述語氣自信就放行，須自行查證關鍵宣稱。
  - 輸出 `quality-loop` 標準判定格式。

---

### 4. `prototyper`

- **檔名**：`agents/prototyper.md`
- **依據**：PROMPT（Prototype 定義）、Q18、DESIGN §3.3、§8。

```yaml
---
name: prototyper
description: >-
  Runs throwaway experiments to answer open technical questions left by
  Explore, writing findings to prototype.md and experiment code to
  prototype/ (both under the unit's changes/ directory; never under a
  production source path). Dispatched by the agent-flow orchestrator when
  Explore leaves open technical questions.
model: sonnet
tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch
---
```

- **Frontmatter 理由**：`model: sonnet`（作者類）。工具集比 `explorer` 多一層「動手做實驗」的
  需求，但本質相同（讀寫＋執行＋外部查詢）。不 preload internal skill：prototype.md／
  prototype/ 的格式由 PROMPT 與 Q18 直接定義（問題／做法／證據／結論），不涉及 `sdd-guide`
  或 `tdd-guide` 的規則範圍。
- **System prompt body 必須涵蓋**：
  - 產物必須落在 `changes/<unit>/prototype.md`（問題／做法／證據／結論）與
    `changes/<unit>/prototype/`（實驗碼本身）——**絕不**寫入任何正式產品原始碼路徑
    （如 `src/`），這是 Q18 配套紀律（DESIGN §8）的核心禁令，必須在系統提示中明文強調。
  - 實驗碼是丟棄式的：只為了回答技術疑問存在，不必符合正式程式碼的品質標準，但證據必須真實
    可重現（`prototype-reviewer` 會實際重跑）。
  - 每個實驗必須明確對應 Explore 留下的哪一條技術疑問，結論要明確回答「疑問是否已解決」。

---

### 5. `prototype-reviewer`

- **檔名**：`agents/prototype-reviewer.md`
- **依據**：Q4、DESIGN §3.3。

```yaml
---
name: prototype-reviewer
description: >-
  Independently reviews prototype.md and prototype/ to verify each open
  technical question was actually answered and the evidence is credible
  (reproducible), before Prototype auto-continues to Spec. Dispatched by
  the agent-flow orchestrator; not for automatic delegation.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: quality-loop
---
```

- **Frontmatter 理由**：`model: opus`（審查類）。保留 Bash 是本角色的核心需求——DESIGN §3.3
  明訂審查重點是「證據是否可信」，唯一可靠的驗證方式是實際重跑 `prototype/` 下的實驗碼。
- **System prompt body 必須涵蓋**：
  - 對每個宣稱已解決的技術疑問，實際重跑對應的 `prototype/` 實驗碼，確認結果與 `prototype.md`
    所述證據一致。
  - 檢查 `prototype/` 內容確實沒有被任何正式產品路徑引用（Review phase 之前的第一道防線，
    呼應 DESIGN §8 的清理紀律；正式的「零依賴」查核在 Review phase 由
    `review-spec-compliance-auditor` 做最終確認，本角色只做 Prototype 當下的初步檢查）。
  - 輸出 `quality-loop` 標準判定格式，若證據無法重現視為退回（純實作問題，退回
    `prototyper` 重做）。

---

### 6. `spec-writer`

- **檔名**：`agents/spec-writer.md`
- **依據**：PROMPT、Q7、Q8、DESIGN §3.4。

```yaml
---
name: spec-writer
description: >-
  Writes the delta spec (spec-delta.md) for the current unit in EARS format
  with ADDED/MODIFIED/REMOVED sections, based on the approved Discuss
  summary and Explore/Prototype findings. Dispatched by the agent-flow
  orchestrator after Explore (and Prototype, if run) completes.
model: sonnet
tools: Read, Write, Edit, Grep, Glob
skills: sdd-guide
---
```

- **Frontmatter 理由**：`model: sonnet`（作者類）。不需要 Bash／WebFetch——spec-writer 的
  輸入是既有 phase 產物與主 spec（`.agent-flow/specs/`），不需要執行程式或查外部資源。
  `sdd-guide` preload：EARS 句型、delta spec 語法、需求編號規則是這個角色的核心依循。
- **System prompt body 必須涵蓋**：
  - 讀取 `changes/<unit>/discuss.md`、`explore.md`、（若有）`prototype.md`，以及
    `.agent-flow/specs/<domain>/spec.md`（現有主 spec，用於判斷相對現況的變化與避免編號衝突）。
  - 產物固定為 `changes/<unit>/spec-delta.md`：`## ADDED/MODIFIED/REMOVED Requirements`
    區塊，需求本文用 EARS（`WHEN ... THE SYSTEM SHALL ...`）並附編號（Q7、Q8）。
  - Greenfield 情境（無現有主 spec 對應領域）時，delta 就是全部 ADDED，不特殊處理成另一種格式
    （Q8：兩情境共用同一形態）。
  - 不得直接編修主 spec 本身——主 spec 的合併是 Wrap phase 的職責（`wrap-executor`）。

---

### 7. `spec-reviewer`

- **檔名**：`agents/spec-reviewer.md`
- **依據**：Q3（Spec 承諾點）、Q4、DESIGN §3.4。

```yaml
---
name: spec-reviewer
description: >-
  Independently reviews spec-delta.md for EARS format correctness,
  numbering consistency, and alignment with the approved Discuss/Explore
  conclusions, before the Spec gate is presented to the user. Dispatched
  by the agent-flow orchestrator; not for automatic delegation.
model: opus
tools: Read, Grep, Glob
disallowedTools: Write, Edit, Bash
skills: sdd-guide, quality-loop
---
```

- **Frontmatter 理由**：`model: opus`（審查類）。純文字規格審查不需要 Bash。`sdd-guide`
  preload 讓審查者依循與作者相同的格式契約，不會出現「審查標準與撰寫標準不一致」的落差。
- **System prompt body 必須涵蓋**：
  - 逐條需求檢查 EARS 句型是否正確（`WHEN ... THE SYSTEM SHALL ...`）、編號是否連續無衝突、
    ADDED/MODIFIED/REMOVED 分類是否正確對應現況。
  - 核對 spec-delta.md 的內容與 `discuss.md`／`explore.md`（／`prototype.md`）的結論是否吻合，
    不得引入訪談與調查未提及的新範圍。
  - 這是 Q3 定義的承諾點前最後一道自動化把關，通過後 delta spec 才會被呈現給使用者核准
    （核准後即成為「已核准產物」，適用 Q5、Q10 的不可推翻原則）。

---

### 8. `ticket-writer`

- **檔名**：`agents/ticket-writer.md`
- **依據**：PROMPT、Q7、Q9、DESIGN §3.5。

```yaml
---
name: ticket-writer
description: >-
  Splits the approved spec-delta.md into verifiable tickets, each with a
  requirement backlink and a real, executable test that must fail (red)
  before implementation. Dispatched by the agent-flow orchestrator after
  the Spec gate is approved.
model: sonnet
tools: Read, Write, Edit, Grep, Glob, Bash
skills: sdd-guide, tdd-guide
---
```

- **Frontmatter 理由**：`model: sonnet`（作者類）。**必須含 Bash**——Q9 選擇「可執行的失敗
  測試」，ticket-writer 必須實際執行測試指令以確認紅燈，不能只是靜態寫出測試碼。`sdd-guide`
  提供需求編號回鏈規則，`tdd-guide` 提供紅綠鐵律與測試合約規則。
- **System prompt body 必須涵蓋**：
  - 讀取已核准的 `changes/<unit>/spec-delta.md`，每張票證附對應需求編號回鏈（Q7）。
  - 每張票證的測試必須是**真測試碼**（非骨架、非清單），寫完後**必須實際執行**並確認結果為
    紅燈（Q9）；若因環境問題無法執行，視為本角色未完成，不得交付。
  - 票證 frontmatter 需含 `dependsOn: [<ticket-id>, ...]`（相依關係的權威來源，Q32），
    orchestrator 之後會同步鏡像進 `state.json`。
  - 產物固定為 `changes/<unit>/tickets/<ticket-id>.md`（含測試碼路徑或內嵌測試）。
  - 不得因為「先讓測試可以跑之後再說」而寫出實際上會通過的測試——必須是真正因為功能未實作
    而失敗的紅燈，這是 `ticket-reviewer` 的審查重點。

---

### 9. `ticket-reviewer`

- **檔名**：`agents/ticket-reviewer.md`
- **依據**：Q3（Ticket 承諾點）、Q4、Q9、Q10、DESIGN §3.5。

```yaml
---
name: ticket-reviewer
description: >-
  Independently reviews each ticket's test for real executability, genuine
  red status (not an environment error), and correct requirement backlinks,
  before the Ticket gate is presented to the user. Dispatched by the
  agent-flow orchestrator; not for automatic delegation.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: sdd-guide, tdd-guide, quality-loop
---
```

- **Frontmatter 理由**：`model: opus`（審查類）。**必須含 Bash**——本角色的核心職責是「測試
  是否真的能執行、是否真的紅燈」（DESIGN §3.5），只能靠實際執行驗證，不能靠讀程式碼判斷。
  `disallowedTools: Write, Edit` 確保審查者不會「順手」把測試改到會過。
- **System prompt body 必須涵蓋**：
  - 對每張票證，實際執行其測試，確認：(a) 測試真的能執行（無語法/環境錯誤導致無法執行）、
    (b) 失敗原因是「功能未實作」而非測試本身寫錯或環境問題、(c) 對應的需求編號正確。
  - 這是 Q10「測試合約」成立前的最後把關：一旦通過本審查、使用者核准 Ticket 承諾點，這些測試
    就成為 Dev phase 不可修改的合約。
  - 若發現測試本身邏輯有誤，判定為退回 `ticket-writer` 重寫（此時仍在 Ticket phase 內、尚未
    核准，屬於「純實作問題」，不觸發 Q5 上報——上報路徑只在 Ticket **已核准之後**、Dev phase
    才會用到，見 `dev-worker`／`dev-reviewer` 一節）。

---

### 10. `dev-worker`

- **檔名**：`agents/dev-worker.md`
- **依據**：PROMPT、Q10、Q11、Q34、DESIGN §3.6、§4、§7；research 07 Test A、Test B。

```yaml
---
name: dev-worker
description: >-
  Implements one approved ticket in an isolated git worktree until its
  pre-written test goes green, then commits. One instance is dispatched
  per ticket by the agent-flow orchestrator once its dependencies are
  merged into the unit branch; a worktree cannot be created before the
  orchestrator checks out the unit branch and sets worktree.baseRef: head
  (research 07 Test B).
model: sonnet
isolation: worktree
tools: Read, Write, Edit, Bash, Grep, Glob
skills: tdd-guide
---
```

- **Frontmatter 理由**：`model: sonnet`（作者類）。`isolation: worktree` 是本角色的定義性
  欄位（Q11），每次以 Agent tool **重新派工**都會拿到全新 worktree（research 06 實驗四）；
  「退回重做」必須靠 orchestrator 用 `SendMessage` 續談同一個已完成的 agent ID，而非重新呼叫
  Agent tool（research 07 Test A 已證實續談時 worktree／分支／未 commit 變更完整保留）——這條
  規則屬於 `using-worktree` internal skill 的範圍，僅 `orchestrate` 載入，`dev-worker` 自己
  不需要、也不會 preload 它。`tdd-guide` preload 讓 dev-worker 清楚知道測試合約邊界。
- **System prompt body 必須涵蓋**：
  - **絕對禁止修改票證測試檔案**（Q10）：若判斷測試本身有誤，不得直接修改，必須在回報中明確
    標示「測試疑似有誤」並停止實作該部分，交由 orchestrator 依 Q5 上報使用者裁決。
  - Red-before-green 已由 Ticket phase 保證（測試進來時已確認是紅燈）；dev-worker 的職責純粹
    是撰寫最少必要的實作程式碼讓測試轉綠，不重新驗證「測試曾經是紅燈」這件事。
  - 實作到測試轉綠後，在自己的 worktree 內 **commit 一次**（Q34：一票證一 commit，不 squash，
    方便 `dev-reviewer` 與後續 Review phase 逐票核對）。
  - 若被 `SendMessage` 續談（審查退回重做），必須基於自己先前的實作與 worktree 現狀繼續修正，
    不得從頭重寫已通過部分。
  - 說明性補充（非強制規則，寫進系統提示供理解）：測試合約在 agent 定義層級沒有技術性強制
    手段（plugin agent 不支援 `hooks`，見「通則」第 2 點），完全依賴本條系統提示的紀律約束，
    違反與否由 `dev-reviewer` 逐次審查把關。

---

### 11. `dev-reviewer`

- **檔名**：`agents/dev-reviewer.md`
- **依據**：Q4、Q10、DESIGN §3.6、§4；research 07 Test A。

```yaml
---
name: dev-reviewer
description: >-
  Independently reviews one ticket's implementation in the dev-worker's
  worktree: verifies the test genuinely went green, checks alignment with
  the ticket and spec, and flags quality issues. One instance is
  dispatched per ticket by the agent-flow orchestrator after dev-worker
  reports completion.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: tdd-guide, quality-loop
---
```

- **Frontmatter 理由**：`model: opus`（審查類）。**必須含 Bash**——核心職責是獨立重跑測試確認
  真的轉綠，不能只讀程式碼判斷。**不宣告 `isolation: worktree`**：若宣告，本角色自己呼叫時會
  拿到一個全新、空白的隔離 worktree，看不到 `dev-worker` 已完成的變更（research 06 實驗四）。
  正確做法是：orchestrator 派工時，把該次 `dev-worker`呼叫回傳的 `worktreePath`
  （research 07 Test A 已證實此欄位存在於 Agent tool 呼叫結果中）作為 prompt 內容傳給
  `dev-reviewer`，`dev-reviewer` 在**自己的一般執行環境**中用 Bash `cd` 進該絕對路徑執行測試、
  用 Read/Grep 檢視程式碼，不建立、也不需要自己的隔離工作區。**（S13 裁決：此設計維持不變，
  定為規格本文）**
  **信心邊界與強制的實作前置驗證（S13 裁決：標註保留在規格本文，非待對齊）**：這個「非隔離
  子代理可否 `cd` 進另一個子代理的 worktree 目錄操作」的具體場景，research 02 §4.2 只記載了
  「worktree 隔離狀態下的 session 會被限制在自己的 worktree 內」這一半（限制施加對象是**已
  進入隔離狀態的一方**），沒有逐字驗證「未隔離的一方能否讀取／執行另一個 worktree 目錄」——
  後者在邏輯上應該可行（worktree 只是磁碟上的普通目錄），但這個確切互動場景本次規格對齊沒有
  直接的實測依據。整個 Dev phase 品質迴圈（`spec/11-dev.md`「品質迴圈」步驟 3–4）都建立在這個
  假設成立的前提上，因此**規格要求**：第 5 步實作開始寫 Dev phase 之前，**必須優先**用最小
  可行範例驗證此假設——具體驗證方法：先建立一個 `isolation: worktree` 的假子代理寫入檔案，
  再用一個普通子代理帶入其 `worktreePath` 嘗試 `cd` 與 `Bash`／`Read` 讀取，驗證通過即維持本節
  設計，不需改動。**若驗證不成立**，改用替代機制：`dev-reviewer` 也宣告 `isolation: worktree`，
  並要求 orchestrator 傳入 `dev-worker` 的分支名稱（而非路徑），審查時先 `git fetch` 該
  worktree 分支到自己的隔離環境內再操作——此替代機制額外依賴「同一個 repo 底下兩個
  `isolation: worktree` 子代理能否互相 fetch 對方的 worktree 分支」，本身也需要在切換到此
  替代機制時一併驗證。
- **System prompt body 必須涵蓋**：
  - 依 orchestrator 提供的 `worktreePath`，`cd` 進該目錄執行票證測試，確認測試真的轉綠（不是
    因為測試被動了手腳而「看起來」過）。
  - 核對實作內容是否符合票證描述與 spec-delta.md 對應需求編號。
  - 核對票證測試檔案本身**沒有被 `dev-worker` 修改**（可用 `git diff` 對照該 worktree 分支
    的初始 commit 與目前狀態，鎖定測試檔案路徑）——這是 Q10 合約在 Dev phase 的技術性覆核，
    唯一的強制手段。
  - 輸出 `quality-loop` 標準判定格式；若發現測試檔案被修改，一律判定為「根因在已核准產物」
    （因為問題出在票證測試合約被破壞，即使表面上是實作者的行為，其本質是對已核准產物的違反），
    觸發 Q5 上報路徑，不得當作一般實作問題自動退回。

---

### 12. `review-gap-hunter`

- **檔名**：`agents/review-gap-hunter.md`
- **依據**：Q4（Review 重型迴圈）、DESIGN §3.7；research 04 對 BMAD-METHOD 平行審查 lens 的記載。

```yaml
---
name: review-gap-hunter
description: >-
  One of three parallel Review-phase auditors. Reads only the unit
  branch's diff against main and the spec/ticket file paths to find
  missing implementations, unimplemented requirements, or missing tests —
  without seeing the other two auditors' findings. Dispatched by the
  agent-flow orchestrator alongside review-edge-case-hunter and
  review-spec-compliance-auditor.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: quality-loop
---
```

- **Frontmatter 理由**：`model: opus`（審查類）。Bash 用於 `git diff` 取得單位分支相對 main
  的整體 diff（Q12：Review 審單位分支整體 diff）與必要時執行測試核對覆蓋率。
- **System prompt body 必須涵蓋**：
  - 只讀取 orchestrator 提供的 diff 範圍與 `spec-delta.md`／`tickets/` 路徑，**不得**主動去看
    另外兩個平行審查小組（`review-edge-case-hunter`、`review-spec-compliance-auditor`）的過程
    或結論——這是 DESIGN §3.7 明訂「不互看彼此的過程或結論，避免互相汙染」的紀律。
  - 專注找「缺口」：spec 需求沒有對應實作、票證沒有對應測試、明顯遺漏的功能面向。
  - 每條 finding 標註自己認為的嚴重度，但需理解：`review-triage` 會重新裁定，本角色自報的
    嚴重度僅供參考、非最終判定（呼應 research 04 BMAD「Disregard any severity a reviewing
    subagent assigned」）。
  - 輸出格式依 04-internal-skills.md `quality-loop` 定義的 Review 專用「原始 finding」層。

---

### 13. `review-edge-case-hunter`

- **檔名**：`agents/review-edge-case-hunter.md`
- **依據**：同上（與 `review-gap-hunter` 並列的第二個平行審查 lens）。

```yaml
---
name: review-edge-case-hunter
description: >-
  One of three parallel Review-phase auditors. Reads only the unit
  branch's diff against main and the spec/ticket file paths to find
  untested edge cases and boundary conditions — without seeing the other
  two auditors' findings. Dispatched by the agent-flow orchestrator
  alongside review-gap-hunter and review-spec-compliance-auditor.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: quality-loop
---
```

- **Frontmatter 理由**：同 `review-gap-hunter`。Bash 供實際嘗試邊界輸入／執行既有測試以佐證
  發現的邊界情境確實未被涵蓋。
- **System prompt body 必須涵蓋**：
  - 同樣的「不互看其他審查小組」紀律。
  - 專注找「邊界情境」：票證測試涵蓋的案例之外，是否有明顯的邊界值、異常輸入、併發／時序問題
    未被涵蓋。
  - 可實際執行程式碼／既有測試以驗證推測的邊界情境是否真的會出錯，而非只憑閱讀程式碼臆測。
  - 輸出格式同 `review-gap-hunter`（Review 專用原始 finding 層）。

---

### 14. `review-spec-compliance-auditor`

- **檔名**：`agents/review-spec-compliance-auditor.md`
- **依據**：同上；DESIGN §8（Prototype 清理紀律的 Review 查核責任歸屬於本角色）。

```yaml
---
name: review-spec-compliance-auditor
description: >-
  One of three parallel Review-phase auditors. Reads only the unit
  branch's diff against main and the spec/ticket file paths to verify the
  implementation actually complies with spec-delta.md's ADDED/MODIFIED/
  REMOVED requirements, and that no production code path depends on
  changes/<unit>/prototype/. Dispatched by the agent-flow orchestrator
  alongside review-gap-hunter and review-edge-case-hunter.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: sdd-guide, quality-loop
---
```

- **Frontmatter 理由**：與其他兩個平行審查角色一致，多 preload `sdd-guide`——本角色的核心
  職責是核對實作與 EARS 格式需求／delta spec 語意是否一致，需要與 `spec-writer`／
  `spec-reviewer` 相同的格式契約知識，才能準確判斷「是否合規」。
- **System prompt body 必須涵蓋**：
  - 同樣的「不互看其他審查小組」紀律。
  - 逐條需求核對：`spec-delta.md` 的每一條 ADDED/MODIFIED 需求是否有對應實作與測試；REMOVED
    需求對應的舊行為是否真的被移除。
  - **明確查核**（DESIGN §8 Q35 配套紀律的 Review 承諾點必要條件）：用 Grep 確認正式產品程式碼
    路徑（例如 `src/`，依專案實際結構）中沒有任何檔案 import／依賴
    `.agent-flow/changes/<unit>/prototype/` 下的內容；這是 Review 承諾點通過的必要條件之一，
    查到違反必須列為阻斷性 finding。
  - 輸出格式同其他兩個平行審查角色（Review 專用原始 finding 層）。

---

### 15. `review-triage`

- **檔名**：`agents/review-triage.md`
- **依據**：Q4、Q5、Q29、DESIGN §3.7、§4；research 04 對 BMAD-METHOD triage 步驟的記載。

```yaml
---
name: review-triage
description: >-
  Independently re-verifies every finding reported by review-gap-hunter,
  review-edge-case-hunter, and review-spec-compliance-auditor, discarding
  their self-reported severity, and routes each confirmed finding to
  either an implementation-issue retry or an approved-artifact escalation.
  Dispatched by the agent-flow orchestrator once all three parallel Review
  auditors report.
model: opus
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
skills: quality-loop
---
```

- **Frontmatter 理由**：`model: opus`（審查類，且是 Review 重型迴圈中承擔最終裁定責任的角色，
  不可用較低階模型）。Bash 用於親自重跑測試／重新查證每條 finding 宣稱的事實，而非只讀三個
  平行小組的文字報告。
- **System prompt body 必須涵蓋**：
  - **不採信審查者自報的嚴重度**（明文寫入系統提示，呼應 research 04 BMAD 記載
    「Disregard any severity a reviewing subagent assigned — they lack the context to
    grade」）：對三個平行小組回報的每一條 finding，親自重新查證是否真實發生，重新裁定嚴重度。
  - **根因分流二分法**（Q5，agent-flow 版本只分兩類，不採 BMAD 的四分流）：
    1. `implementation-issue`——問題出在 Dev phase 尚未核准的實作細節，路由回「純實作問題」，
       由 orchestrator 親自 `SendMessage` 續談對應的 `dev-worker` 修正。
    2. `approved-artifact`——根因在 Discuss／Spec／Ticket 等已核准產物，路由為上報使用者裁決，
       不自動回頭改寫（Q5、Q10 已定的「已核准產物不可自行推翻」原則在 Review phase 的落地點）。
  - 若同一條 finding 追溯後發現根因其實是「已核准的 Ticket 測試本身有問題」，即使外觀上是
    Dev 階段的程式碼問題，仍必須分類為 `approved-artifact`（呼應 `dev-reviewer` 一節的規則）。
  - 裁定結果彙整成 `changes/<unit>/review.md`（結構化缺口/問題清單，含嚴重度與根因分類，
    DESIGN §3.7 產物定義）。
  - 迴圈輪數上限 5 輪（Q29）：本角色需在輸出中標註目前輪次，供 orchestrator 判斷是否已達上限、
    需直接上報「不收斂」。

---

### 16. `wrap-executor`

- **檔名**：`agents/wrap-executor.md`
- **依據**：PROMPT（Wrap 全自動）、Q13、Q25、Q34、DESIGN §3.8、§6、§7。

```yaml
---
name: wrap-executor
description: >-
  Mechanically executes the Wrap phase once the Review gate is approved
  and all tests are green: merges the unit branch into main locally
  (no push), merges the delta spec into the main spec, archives
  changes/<unit>/ into archive/, and removes the unit branch and any
  leftover ticket worktrees. Dispatched once by the agent-flow orchestrator
  per unit.
model: haiku
tools: Read, Write, Edit, Bash, Grep, Glob
skills: sdd-guide
---
```

- **Frontmatter 理由**：`model: haiku`（機械類，Q14／Q33）。**不宣告 `isolation: worktree`**：
  本角色的合併目標就是主 checkout 本身（把單位分支合入 main），若在隔離 worktree 內執行，
  合併結果不會反映到真正的主 checkout，與職責矛盾。`sdd-guide` preload 依 DESIGN §2 表格明文
  「Wrap 的 `wrap-executor`」是載入者之一——合併 delta spec 進主 spec 需要遵守與 `spec-writer`
  相同的 ADDED/MODIFIED/REMOVED 合併規則。
- **是否需要 `using-worktree`（worktree 清理）**：本角色需要清理「本工作單位」殘留的票證
  worktree（DESIGN §9 旅程步驟 10：「刪除單位分支與殘留 worktree」），但這是**一般性的
  safety-net 清理**——用普通的 `git worktree list` / `git worktree remove` 指令核對並移除
  屬於本單位的殘留項目，不涉及建立新的 `isolation: worktree` 子代理、不涉及 `SendMessage`
  續談規則（那是 Dev phase 進行中才需要的機制）。`using-worktree` skill 的範圍界定明文限定
  「僅 `orchestrate`」載入，且其規則主體是「建立/續談票證 worktree」，與 `wrap-executor` 單純
  的清理動作性質不同，因此本角色**不** preload `using-worktree`。
- **System prompt body 必須涵蓋**：
  - 執行前置條件檢查（由 orchestrator 傳入既定事實：Review 承諾點已核准）：**先在單位分支上
    重跑一次完整測試**，不綠則視為前置條件不成立，立即停止並回報失敗（不進行任何合併動作）。
  - 依序執行：合併單位分支進 main（本地合併、不 push，Q13）→ 把 `spec-delta.md` 依
    `sdd-guide` 規則合併進 `.agent-flow/specs/<domain>/spec.md` → 把
    `changes/<unit>/` 整包移入 `archive/<date>-<unit>/`（含 `prototype/`，DESIGN §8：留在歷史
    中但不做進一步整合）→ 刪除單位分支 → 清理屬於本單位的殘留票證 worktree。
  - 逐動作寫入 `changes/<unit>/wrap.md`（之後隨單位一起歸檔）作為執行紀錄。
  - Commit 顆粒度依 Q34：合併時保留逐票證 commit 歷史，不 squash。
  - 每個動作執行後即回報給 orchestrator，供 `wrap-verifier` 逐一查證——不得自行宣稱「全部
    完成」而不逐項可查證地記錄下來。

---

### 17. `wrap-verifier`

- **檔名**：`agents/wrap-verifier.md`
- **依據**：Q13、Q25、DESIGN §3.8；research 06（headless 靜默拒絕、動作被拒但流程照走）。

```yaml
---
name: wrap-verifier
description: >-
  Independently re-verifies each action wrap-executor reports as done —
  checks main's git log for the merge commit, confirms worktrees were
  actually removed, and reruns the full test suite on merged main — rather
  than trusting wrap-executor's self-report. Dispatched by the agent-flow
  orchestrator after each wrap-executor action (or batch of actions).
model: haiku
tools: Read, Bash, Grep, Glob
disallowedTools: Write, Edit
---
```

- **Frontmatter 理由**：`model: haiku`（機械類，Q14／Q33——查證動作本身是機械性的，不需要高階
  推理）。`disallowedTools: Write, Edit`：本角色只驗證、不動手修改任何檔案，驗證結果回報給
  orchestrator，由 orchestrator（或委託 `wrap-executor` 下一個動作）決定後續。**不宣告
  `isolation: worktree`**：驗證對象是主 checkout 上的真實合併結果，隔離工作區看不到它。
- **是否 preload `quality-loop`**：本角色**不** preload。理由：`quality-loop` internal skill
  定義的是「作者寫、審查退回重寫」的標準／重型迴圈判定格式（含輪次、根因分流二分法），但 Wrap
  的迴圈形態依 Q25 是「執行—驗證、失敗即上報」——沒有「退回原作者修」這個路徑，也沒有 3 輪或
  5 輪的輪次上限概念，一失敗就直接停下上報，因此不適用 `quality-loop` 的判定 schema。
  本角色的輸出是更單純的「該動作是否確實發生：是／否＋查證方式」，直接在系統提示中定義即可，
  不需要引入另一份格式契約。
- **System prompt body 必須涵蓋**：
  - 對 `wrap-executor` 回報的每一個動作，**獨立**查證是否真的發生，不信任其自我回報：
    - 合併 commit：查 main 的 `git log` 確實包含該次合併。
    - 分支/worktree 清理：查 `git branch` / `git worktree list` 確實不再出現該單位的分支與
      worktree。
    - 測試綠燈：**在合併後的 main 上重新完整跑一次測試**（不是重複讀取 `wrap-executor`
      先前跑過的結果），確認真的通過（呼應 research 04 對 Superpowers「合併後在結果上重跑一次
      測試」的記載）。
  - 任何一項驗證失敗，立即回報失敗並停止（Q25：不重試），把已查證的具體事實（而非臆測原因）
    回報給 orchestrator，供其上報使用者裁決——**上報格式（S3 裁決）沿用**
    `spec/02-state.md`／`spec/04-internal-skills.md` 定案的 ESC 格式（`decisions.md` 模板 +
    `state.json escalations[]`，`phase: "wrap"`），「Phase／輪次」欄位固定填「Wrap（無輪次，
    執行—驗證迴圈）」，不另訂簡化格式，也不引入「輪次」概念（Wrap 本來就沒有輪次）。
  - 這個角色存在的理由直接呼應 research 06 的核心發現：headless 下未涵蓋的權限會「乾淨拒絕、
    流程照走」，最大風險是「動作被拒但流程自認完成」的靜默失敗——所以必須有獨立角色實際查證
    而非只信任 `wrap-executor` 的文字回報。

## 待對齊

無。原兩項待對齊已由使用者裁決：

- **原 #1（S13 裁決）**：`dev-reviewer` 進 worktree 的假設維持不變，「實作前必須優先用最小
  可行範例驗證」的要求已改寫進第 11 節規格本文（含驗證方法與驗證失敗時的替代機制），不再是
  待裁決選項。
- **原 #2（S3 裁決）**：`wrap-verifier` 的驗證失敗上報確認沿用 ESC 格式與 `escalations` 陣列，
  已改寫進第 17 節規格本文。
