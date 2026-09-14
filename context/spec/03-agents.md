# 03 — Agent 定義檔規格

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R5（2026-09-10 重構裁決）**：17 個角色 agent 收斂為 2 個 general-purpose agent——`worker`（作者／機械執行，sonnet）與 `reviewer`（獨立審查，opus，唯讀）。角色差異由派工 prompt（角色簡報）＋指定的 reference 文件表達；Build 的 worktree 隔離原改用 Agent tool 呼叫時參數 `isolation: "worktree"`（**此項已由 R12 廢止**，改為主 session 自建 worktree ＋ 派工 prompt 指定 `cd` 路徑）。Q33 的 17 角色模型指派表隨之廢止，模型分級收斂為兩級。
- **R4**：internal skill 廢止——agent 不再有 `skills:` preload 清單；需要的參考文件由派工 prompt 指名路徑、agent 自行 `Read`。
- 三類角色語意（作者／審查／機械）與「審查獨立於作者」原則承襲：DESIGN §2、PROMPT——現在由「同一 agent 定義、不同派工」實現：審查一律是對 `reviewer` 的**另一次獨立派工**，永遠由主 session 直接派。
- Plugin agent 禁用欄位（`hooks`／`mcpServers`／`permissionMode`）：research 01 §2.3、research 05 實驗一。
- 巢狀派工禁令：research 02 §2.2、DESIGN §5。
- **S13（承襲）**：非隔離 `reviewer` `cd` 進 `worker` worktree 審查的平台假設維持，「實作前必須優先用最小可行範例驗證」的要求保留。
- **Q36（承襲）／R11 修正**：命名衝突不掃描。R11 實測證明命名空間已提供保護，同名的使用者 agent 只佔裸名、不覆蓋 `agent-flow:<name>`（`research/11` §2、spec/01 §2.4），原「通用名風險升高」的說法作廢。
- 測試合約（worker 不可改測試）：Q10——起點依 R2 改為「TDD 迴圈通過」。

## 規格本文

### 通則

1. **檔案位置**：`agents/worker.md`、`agents/reviewer.md`。
2. **一律不得出現的 frontmatter 欄位**：`hooks`、`mcpServers`、`permissionMode`（plugin agent 不支援）；`skills`（R4：無 preload，參考文件由派工 prompt 指名）；`isolation`（R5：隔離改為呼叫時參數，agent 定義本身不隔離）。
3. **一律不得出現 `Agent` 工具**：兩個 agent 都不往下派生子代理；審查獨立性由主 session 一層直接派工達成。
4. **`name` 欄位一律是裸名**（`worker`／`reviewer`），**絕對不要把命名空間寫進去**（R11）。命名空間由平台自動衍生為 `<plugin-name>:<agent-name>`，寫成 `name: agent-flow:worker` 會讓實際的 `subagent_type` 變成 `agent-flow:agent-flow:worker`（冒號疊加，`research/11` §3 實測），而 `claude plugin validate` 不會攔下這個錯誤。派工端（`references/glossary.md` 的 `dispatch` 原語、`skills/orchestrate/SKILL.md`）才寫命名空間形式。
5. **角色簡報（dispatch prompt）契約**：主 session 每次派工的 prompt 必須包含五個要素——(a) 本次角色（例如 "You are acting as the spec author"）；(b) 要先 `Read` 的 reference 檔案**絕對路徑**清單（主 session 以 `${CLAUDE_PLUGIN_ROOT}/references/<name>.md` 展開後傳入——子代理與 worktree 內無從解析 plugin 相對路徑，見 spec/04 通則 3）；(c) 輸入產物路徑；(d) 產物落地路徑；(e) 輸出格式要求（reviewer 一律要求 `references/quality-loop.md` 定義的 JSON 契約）與輪次資訊（`round`/`maxRounds`）。各 phase 的具體組合見 spec/06–12。
6. **模型成本取捨（已知、R5 定案）**：原 haiku 級機械角色（wrap-executor／wrap-verifier）的工作分別落到 `worker`（sonnet）與 `reviewer`（opus），成本高於舊設計——這是收斂為兩個 agent 的明確取捨，不另設第三個 agent。

### 1. `worker`

- **檔名**：`agents/worker.md`

```yaml
---
name: worker
description: >-
  General-purpose author/executor for all agent-flow phases: investigation,
  throwaway prototyping, spec writing, ticket/test authoring, ticket
  implementation, and mechanical wrap-up. Reads the role briefing and the
  reference files named in the dispatch prompt, writes only to the artifact
  paths it names, and never modifies contract test files. Dispatched by the
  agent-flow orchestrator; not for automatic delegation.
model: sonnet
tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch
---
```

- **System prompt body 必須涵蓋**：
  - 開工前先 `Read` 派工 prompt 指名的每一份 reference 檔案，依其規則執行；prompt 未指名的 reference 不需要讀。
  - 產物只寫入派工 prompt 指定的路徑；實驗碼（Prototype 角色）只進 `changes/<unit>/prototype/`，**絕不**寫入正式產品原始碼路徑。
  - **測試合約（Q10／R2）**：擔任 Build 實作角色時，絕對禁止修改票證測試檔案；判斷測試本身有誤時停止該部分實作、在回報中明確標示「測試疑似有誤」，由主 session 依 waterfall 規則退回 TDD 處理。
  - TDD 角色時：測試必須是真測試碼且實際執行確認紅燈（Q9），無法執行視為未完成。
  - Build 角色時：只寫最少必要實作讓測試轉綠；轉綠後在自己的 worktree 內 commit 一次（Q34）；被 `SendMessage` 續談時基於 worktree 現狀繼續修正，不從頭重寫已通過部分。
  - Wrap 角色時：逐動作執行、逐動作留痕（`wrap.md`），不得自行宣稱「全部完成」而缺可查證記錄。
  - 回報一律是「結論摘要＋讀寫的檔案路徑清單」，不整段複述產物內容。

### 2. `reviewer`

- **檔名**：`agents/reviewer.md`

```yaml
---
name: reviewer
description: >-
  General-purpose independent reviewer for all agent-flow phases. Verifies
  the author's artifact against the checklist and reference files named in
  the dispatch prompt, re-runs tests and evidence itself instead of
  trusting the author's report, and replies using the quality-loop JSON
  contract. Read-only. Dispatched by the agent-flow orchestrator; not for
  automatic delegation.
model: opus
tools: Read, Grep, Glob, Bash, WebFetch
disallowedTools: Write, Edit
---
```

- **Frontmatter 理由**：保留 Bash／WebFetch 供獨立查證（重跑測試、重現實驗、驗證外部宣稱）；`disallowedTools: Write, Edit` 確保審查者不修改受審產物。
- **System prompt body 必須涵蓋**：
  - 獨立查證：不因作者敘述語氣自信而放行；關鍵宣稱（檔案存在、測試紅／綠、實驗可重現）必須親自重跑或重讀。
  - 輸出一律用 `references/quality-loop.md` 定義的 JSON 契約，含每條 finding 的 `targetPhase` 判定（根因落在哪個 phase——waterfall 退回路由的依據，R3）。
  - **Review lens 模式**（派工 prompt 標明為三平行審查之一時）：只看指定的 diff 與產物路徑，不得探查其他平行審查者的過程或結論；輸出 raw-finding 層（無 verdict、無 targetPhase，`reportedSeverity` 僅供參考）。
  - **Triage 模式**：不採信 lens 自報嚴重度，逐條親自重新查證後裁定 `severity` 與 `targetPhase`。
  - **Wrap 驗證模式**：不適用 quality-loop 契約（Wrap 無退回路徑，Q25）；輸出為逐動作的「是否確實發生：是/否＋查證方式」，任何一項失敗立即回報停止。驗證結論只回傳主 session，由主 session 轉交 `worker` 轉錄至 `wrap.md`；`reviewer` 不直接寫入該檔。
  - 測試合約覆核（Build 審查角色）：用 `git diff` 核對測試檔相對初始 commit 未被修改；發現被修改一律判 `targetPhase: "tdd"`（測試合約特例，見 `references/quality-loop.md`）。
  - **唯讀契約的適用範圍與拋棄式副本**：唯讀限制的對象是受審產物與正式工作樹；執行 TDD「補測試覆蓋」的可失敗性驗證（spec/09 §3）時，允許以 Bash 自行建立拋棄式副本（暫存目錄的 `git worktree` 或等效）並在副本內擾動實作，正式樹全程不動；審查結束前必須清理副本並確認無殘留。

### 3. 派工參數與實作前置驗證

1. **Build／Review 修正派工的隔離（R12）**：主 session 先 `git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit-name>` 自建 worktree，再以**普通派工**（不帶任何 `isolation` 參數）送出，角色簡報額外傳入該 worktree 的絕對路徑與「先 `cd` 進去」的指示。同一個 `worker` 因此能同時服務 Build 票證與其餘 phase 兩種情境。
2. **實作前必須優先驗證的兩個平台假設**（任一不成立即需回頭調整本節設計，不要等整個 Build phase 寫完才發現）：
   - (a) **已於 research 13 §1 證實**：普通派工的子代理能 `cd` 進主 session 自建的 worktree 工作、commit，且兩個平行子代理互不干擾。原「`isolation` 參數是否對 plugin agent 生效」的驗證項隨 R12 失效。
   - (b) **（S13 承襲，已由 (a) 一併證實）**`reviewer` 同樣以 Bash `cd` 進該 worktree 執行測試與讀碼——與 `worker` 走完全相同的機制，不再有「隔離／非隔離」之分。

## 待對齊

無。R5 定案兩個 agent 與呼叫時隔離參數；S13 的驗證要求以「實作前置步驟」形式保留於規格本文；模型成本取捨已在通則第 5 點明文記錄為已知決策。
