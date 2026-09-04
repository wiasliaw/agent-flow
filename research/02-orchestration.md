# Claude Code 多代理協作與子代理機制研究

調查目的：評估 `agent-flow` plugin（八 phase SDD+TDD 工作流程：Discuss/Explore/Prototype/Spec/Ticket/Dev/Review/Wrap；主 session 作 orchestrator、撰寫與審查派給不同子 agent、Dev phase 用 subagent 或 git worktree 平行執行票證、每個 phase 結束由獨立角色跑品質檢查迴圈）在 Claude Code 平台上的可行性與實作方式。

資料來源以官方文件為主（`code.claude.com/docs/en/*`，`docs.claude.com` 舊網址會 301 轉址到同一站）。所有版本號（如 `v2.1.xxx`）皆為文件原文標註的行為變更版本，代表這些機制仍在快速演進中。

---

## 1. 子代理（Subagent）定義格式

子代理（subagent）定義檔採 YAML frontmatter + Markdown 系統提示（system prompt）格式，放在 `.claude/agents/*.md`（專案層級）或 `~/.claude/agents/*.md`（使用者層級），或 plugin 內的 `agents/` 目錄。
來源：[Subagents](https://code.claude.com/docs/en/sub-agents)

### 1.1 Frontmatter 欄位

必填：`name`（小寫字母與連字號，不可含 `:`，因為 `:` 保留給 plugin 命名空間）、`description`（決定 Claude 何時自動委派給這個子代理，且所有子代理 description 合計超過 15,000 tokens 會在啟動時顯示警告）。

選填欄位（節錄與 agent-flow 相關者）：`tools`（allowlist）、`disallowedTools`（denylist，兩者都設定時 denylist 優先）、`model`（`sonnet`/`opus`/`haiku`/`fable`/完整 model ID/`inherit`）、`permissionMode`、`maxTurns`（達上限時回傳部分結果，並標記可續跑，需 v2.1.246+）、`skills`（啟動時預載完整內容）、`mcpServers`、`hooks`（scoped 到該子代理）、`memory`（`user`/`project`/`local` 跨 session 記憶）、`background`、`effort`、`isolation: worktree`（見第 4 節）、`color`、`initialPrompt`（作為 `--agent` 主 session 時的第一則使用者訊息）。
來源：[Subagents — Supported frontmatter fields](https://code.claude.com/docs/en/sub-agents)

### 1.2 Plugin 內 agents 目錄的差異（重要）

Plugin 提供的子代理與 project/user 子代理在支援欄位上有差異：

- Plugin agents **支援**：`name`、`description`、`model`、`effort`、`maxTurns`、`tools`、`disallowedTools`、`skills`、`memory`、`background`、`isolation`（只能是 `"worktree"`）。
- Plugin agents **不支援**（安全限制）：`hooks`、`mcpServers`、`permissionMode`。
- 若檔名未指定 `name`，Claude Code 會以檔名自動命名，並加上 plugin 命名空間，例如 plugin `my-plugin` 內的 `agents/reviewer.md` 會載入為 `my-plugin:reviewer`。
- **重要差異**：若 plugin agent 檔案的 frontmatter 解析失敗，Claude Code 仍會載入該檔案（用檔名當 name、`Agent from my-plugin plugin` 當 description、忽略所有欄位內容）；相對地，project/user/managed 層級的 agent 檔案若 frontmatter 解析失敗則會被跳過。
- 可用 `claude plugin validate ./my-plugin` 檢查 agents 目錄下 frontmatter 是否能解析。
- `plugin.json` 可用 `agents` 欄位指定自訂路徑陣列，取代預設的 `agents/` 目錄掃描。

來源：[Plugins reference — Agents](https://code.claude.com/docs/en/plugins-reference)

由於 agent-flow 本身就是一個 plugin，這代表：Dev phase 或 Review phase 若要用「獨立於作者的角色」跑品質檢查，若把這些角色定義為 plugin agents，就**不能**用 `hooks` 或 `permissionMode` 欄位鎖定其行為，只能靠 `tools`/`disallowedTools` 限制能力；若需要 `permissionMode` 或該子代理專屬的 hooks，必須改用 project 層級的 `.claude/agents/*.md`（隨 plugin 一起發佈時，可能需要 plugin 安裝腳本把檔案複製到使用者專案的 `.claude/agents/`，而非放在 plugin 自己的 `agents/` 目錄）。

### 1.3 自動委派 vs 明確呼叫

自動委派（automatic delegation）：Claude 依 `description` 欄位判斷何時委派任務，不需特殊語法（例如使用者直接說「Use the test-runner subagent to fix failing tests」）。文件建議在 description 中加入「use proactively」字樣以鼓勵自動委派。

明確呼叫（explicit invocation）：用 `@agent-<name>` 或 plugin 命名空間 `@agent-my-plugin:code-reviewer` 明確指定，或用 `claude --agent <name>` 讓整個 session 使用該子代理的系統提示、工具限制與模型。

來源：[Subagents — Invocation patterns](https://code.claude.com/docs/en/sub-agents)

### 1.4 Context 隔離

一般（非 fork）子代理**從零開始**，初始 context 只包含：自己的系統提示 + Claude Code 附加的環境資訊（不含 Claude Code 本身的系統提示）、Task 委派訊息、CLAUDE.md 檔案（Explore/Plan 內建子代理例外，會跳過 CLAUDE.md 以加快速度）、git status 快照、預載的 skills、其他具名 agent 的名單（sibling roster，v2.1.206+）。**不會**收到：對話歷史、輸出風格偏好、主對話的 auto memory、先前的 skill 呼叫紀錄。

Fork 模式（用 `/subtask` 或 `/fork` 啟動）則是完整繼承主對話的 context（相同系統提示、工具、模型、訊息歷史）。

來源：[Subagents — Context isolation](https://code.claude.com/docs/en/sub-agents)

這對 agent-flow 的設計意義：Dev phase 的「撰寫者」子代理與「審查者」子代理若都是一般子代理，彼此互不知道對方的推理過程，只能透過 orchestrator 傳遞的委派訊息與各自讀到的檔案溝通——這正好符合「審查者需獨立於作者」的需求，因為審查者不會被作者的 context 汙染判斷。

### 1.5 子代理發現優先序

當同名子代理出現在多個位置時，優先序為：managed settings（組織層級）> `--agents` CLI flag（單次 session）> `.claude/agents/`（專案，沿目錄樹往上找，v2.1.178+ 以離工作目錄最近的定義為準）> `~/.claude/agents/`（使用者）> plugin 的 `agents/` 目錄（最低優先）。
來源：[Subagents — Subagent scope & availability](https://code.claude.com/docs/en/sub-agents)

---

## 2. Task／Agent tool 運作機制

Claude 用來派工的內建工具官方稱為 **Agent tool**（在 UI 顯示為「Task」，文件也稱之為 Task tool 的舊名，但需注意文件中另有一組真正叫 `TaskCreate`/`TaskGet`/`TaskList`/`TaskUpdate` 的獨立工具，語意不同，見 2.4）。
來源：[Tools reference — Agent tool](https://code.claude.com/docs/en/tools-reference)

### 2.1 基本行為

Agent tool 產生一個在獨立 context window 執行任務的子代理；子代理只回傳**最終文字結果**，中間的工具呼叫與輸出對主對話是隱藏的（不會佔用主 context）。啟用 fork 模式時，帶 `name` 參數的呼叫可能改為啟動 agent team 的隊友（見第 3 節）。
來源：[Tools reference — Agent tool](https://code.claude.com/docs/en/tools-reference)

### 2.2 巢狀深度（Nesting）

**預設情況下，子代理可以再往下巢狀 spawn 子代理，最多 3 層（低於主對話）。** 達到深度上限時，Claude Code 會從該層級的所有子代理（fork 除外）拿掉 Agent tool，所以它只能自己完成委派的工作並回傳一則摘要。可用環境變數 `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` 調整（設為 `1` 完全停用巢狀），也可以在子代理定義的 `tools` 欄位中不列出 `Agent` 來針對單一子代理停用。Fork 型子代理在任何深度都保留 Agent tool。
來源：[Subagents — Nesting](https://code.claude.com/docs/en/sub-agents)

對 agent-flow 而言：orchestrator（第 0 層）→ Dev phase 派出的票證 worker（第 1 層）→ worker 底下再派品質檢查子代理（第 2 層），這樣的兩層巢狀在預設 3 層限制內沒有問題。

### 2.3 前景／背景執行

Claude Code 依規則自動決定子代理跑前景（foreground）還是背景（background）：互動式 session 預設開啟 fork 模式時，用 Agent tool 產生的子代理會跑在背景。前景子代理的權限提示（permission prompt）跟主對話一樣即時彈出；背景子代理的權限提示會在主 session 顯示並標明是哪個子代理發出的（v2.1.186+，之前版本會直接自動拒絕該次工具呼叫並繼續跑）。背景子代理使用「精簡版內建工具集」（Read/Grep/Glob/Bash/PowerShell/Edit/Write/NotebookEdit/WebFetch/WebSearch 等），但保留全部 MCP 工具。
來源：[Subagents — Run subagents in foreground or background](https://code.claude.com/docs/en/sub-agents)、[Tools reference — Foreground vs. background execution](https://code.claude.com/docs/en/tools-reference)

### 2.4 結果回傳與續談（Resume）

子代理完成後，Claude 會拿到該子代理的 **agent ID**。用 `SendMessage` 工具可以對已完成的子代理續談（自動在背景恢復），前提是該名稱仍指向同一個 agent（v2.1.199+ 起會檢查名稱是否被新產生的同名背景 agent 佔用，若是則拒絕發送而非誤送）。內建的 Explore/Plan 子代理是一次性（one-shot），不可續談。`maxTurns` 觸頂時輸出會標記為部分結果，並註明可以續跑。
來源：[Subagents — Resuming subagents](https://code.claude.com/docs/en/sub-agents)、[Tools reference — SendMessage tool](https://code.claude.com/docs/en/tools-reference)

### 2.5 另一組「Task」工具（`TaskCreate`/`TaskGet`/`TaskList`/`TaskUpdate`）

這組工具是給**共享任務清單**用的（agent teams 使用，見第 3 節），與 Agent tool（派生子代理）是不同機制。**重要限制**：v2.1.233 起，在 Opus 4.8、Sonnet 5、Fable 5、Mythos 5 或更新版本上，這組工具**預設不開放**（官方理由是新模型已能靠自身追蹤多步驟工作，不需要書面清單，開放工具會消耗 context）；`TodoWrite` 也只有在 `CLAUDE_CODE_ENABLE_TASKS=0` 時才會被移除。要重新開啟需設定環境變數 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`，或用 `--allowedTools TaskCreate` 等方式 opt-in。背景／雲端執行永遠可用這組工具。
來源：[Tools reference — Task tool availability](https://code.claude.com/docs/en/tools-reference)

若 agent-flow 想用官方的共享任務清單機制來追蹤 8 個 phase 或 Dev phase 的多張票證，必須注意目標模型（Fable 5 系列）預設關閉這組工具，需要明確 opt-in。

---

## 3. 平行度（Parallelism）

Claude Code 提供四種平行執行方式，官方比較表如下（節錄）：

| 方式 | 誰負責協調 | 是否需要隔離檔案 | 適用情境 |
|---|---|---|---|
| Subagents | 主 agent 管理全部工作 | 可各自搭配 worktree | 只在乎結果的聚焦任務 |
| Agent view（`claude agents`，research preview） | 你自己派工並查看狀態 | 每個派出的 session 自動分配 worktree | 多個獨立任務，派工後各自查看 |
| Agent teams（實驗性，預設關閉） | 一個 lead session 協調隊友，隊友互相直接傳訊 | **不會**自動隔離，需自行分工檔案 | 需要討論、互相挑戰結論的複雜工作 |
| Dynamic workflows | 一段 Claude 寫的 JavaScript 腳本 | 由 agent 自行處理 | 規模超過一次對話能協調的量、需要交叉驗證 |

來源：[Run agents in parallel](https://code.claude.com/docs/en/agents)

### 3.1 子代理並行上限

Agent tool 產生的子代理，**預設最多同時 20 個並行**，超過會出現 `Concurrent subagent limit reached` 錯誤；可用環境變數 `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` 調整為任意正整數。
來源：[Subagents — Parallelism & concurrency](https://code.claude.com/docs/en/sub-agents)

### 3.2 Dynamic Workflows 的並行上限

Dynamic workflows（由 Claude 寫的腳本呼叫 `agent()`/`pipeline()`/`parallel()`）有明確的執行期限制：

- 同時最多 **16 個並行 agent**（若可用 CPU 較少，會更低，包含在受 CPU 限制的容器內）。
- 單次 `parallel()` 或 `pipeline()` 呼叫最多 **4,096 個項目**，超過會直接報錯拒絕（不是靜默丟棄）。
- 單次 workflow 執行**總計最多 1,000 個 agent**，防止失控迴圈。
- 排程超過 25 個 agent，或預估 token 總量超過 150 萬，會在進度列顯示「Large workflow」警告（僅提示，不會暫停執行）。
- 可用「size guideline」設定（`unrestricted`/`small`(<5)/`medium`(<15，預設)/`large`(<50)）作為給 Claude 的建議值（非硬上限）。

來源：[Orchestrate subagents at scale with dynamic workflows — Behavior and limits](https://code.claude.com/docs/en/workflows)

### 3.3 Agent Teams 建議規模

官方**沒有硬性人數上限**，但列出實務限制：token 成本隨隊友數線性增加、協調開銷增加、報酬遞減。建議大多數工作流程從 **3-5 名隊友**開始；每位隊友配置 5-6 個任務可維持生產力並讓 lead 可重新指派工作。agent teams 使用的 token 量比單一 session **顯著更高**（在 plan mode 下約為標準 session 的 **7 倍**）。
來源：[Agent teams — Choose an appropriate team size](https://code.claude.com/docs/en/agent-teams)、[Manage costs — Manage agent team costs](https://code.claude.com/docs/en/costs)

Agent teams 目前是**實驗性功能，預設關閉**，須設定 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 才會啟用；且啟用後會改變一般委派行為——**Claude 為子代理命名時，該子代理會自動升級為隊友**（teammate），即使使用者沒有要求組隊。這對 agent-flow 是個重要風險：若專案或使用者環境不慎啟用此旗標，Dev phase 原本設計成「輕量、結果回傳」的 subagent 語意可能被悄悄改成「隊友、訊息式協調」，行為與成本都會不同。agent-flow 的 `settings.json` 應明確將此變數設為 `0` 以避免非預期行為。
來源：[Agent teams — Enable agent teams](https://code.claude.com/docs/en/agent-teams)

Agent teams 已知限制中特別值得注意：**沒有巢狀團隊**（隊友不能再組自己的隊伍，只有 lead 能管理團隊）、**session 恢復不還原 in-process 隊友**（`/resume`/`/rewind` 不會還原正在跑的隊友，恢復後 lead 可能嘗試傳訊給已不存在的隊友）、**任務狀態可能延遲**（隊友有時無法正確標記任務完成，會卡住依賴它的任務）。
來源：[Agent teams — Limitations](https://code.claude.com/docs/en/agent-teams)

---

## 4. Git Worktree 隔離

官方明確支援用 git worktree（[git 官方文件](https://git-scm.com/docs/git-worktree)）隔離平行 session 的檔案編輯。
來源：[Run parallel sessions with worktrees](https://code.claude.com/docs/en/worktrees)

### 4.1 三種建立方式

1. `claude --worktree <name>`（或 `-w`）：在 `.claude/worktrees/<name>/` 建立新 worktree，分支名為 `worktree-<name>`，並在其中啟動 session。
2. 對話中請 Claude「work in a worktree」：Claude 會呼叫 `EnterWorktree` 工具建立並切換過去；離開 `.claude/worktrees/` 以外的路徑會要求使用者核准（v2.1.206+，因為這會把 session 的工作目錄、寫入權限、CLAUDE.md 與 settings 一併移過去）。
3. 子代理 frontmatter 加 `isolation: worktree`：讓該子代理**每次都**在獨立臨時 worktree 中執行，見下方 4.3。

### 4.2 隔離強制機制（4 項檢查）

當 session 處於 worktree 隔離狀態時（不論是 `--worktree` 啟動、`EnterWorktree` 進入、或恢復 worktree session），Claude Code 會**強制**擋下以下 4 種操作，且**同樣套用在該 session 派生的每一個子代理上**（不論前景或背景）：

- **檔案編輯**：擋下目標路徑落在主 checkout 的 `Edit`/`Write`/`NotebookEdit`。
- **命令工作目錄**：擋下工作目錄解析到主 checkout、或無法驗證其停留在 worktree 外的 Bash/PowerShell/Monitor 命令。
- **Git 重導向**：擋下透過 `git -C`、`--git-dir`、`GIT_DIR`/`GIT_WORK_TREE` 變數，或先 `cd` 進主 checkout 再跑 git 的命令。
- **命令形狀**：擋下 Claude Code 無法追蹤是否停留在 worktree 內的 shell 結構（例如 brace expansion、未加引號分隔字元的 heredoc），**此檢查無法關閉**。

來源：[Worktrees — How Claude Code enforces isolation](https://code.claude.com/docs/en/worktrees)

### 4.3 子代理專屬 Worktree 隔離

`isolation: worktree` 讓子代理每次執行都拿到獨立的臨時 worktree，用相同的 base branch 邏輯（見 4.4）。無變更的 worktree 完成後會**自動清除**；有變更的 worktree 會保留在硬碟上，直到週期性清掃（sweep）依 `cleanupPeriodDays` 設定移除，且該清掃在 agent 執行期間會用 `git worktree lock` 保護中的 worktree 不被誤刪。
來源：[Worktrees — Isolate subagents with worktrees](https://code.claude.com/docs/en/worktrees)

範例（文件原文）：
```markdown
---
name: refactorer
description: Applies mechanical refactors across many files
isolation: worktree
---

Apply the requested refactor across every affected file, then run the tests
and report the results.
```

### 4.4 Base Branch 選擇

預設 `worktree.baseRef` 是 `"fresh"`：從遠端預設分支（通常是 `main`）分出，確保乾淨起點。設為 `"head"` 則從目前本地 `HEAD` 分出（含未 push 的 commit），**官方建議**：「Use this when isolating subagents that need to operate on in-progress work.」——這正好對應 agent-flow Dev phase「在同一個 Spec/Ticket 分支基礎上平行開多張票」的情境。
來源：[Worktrees — Choose the base branch](https://code.claude.com/docs/en/worktrees)

### 4.5 Headless 模式下的清理注意事項

`-p`（非互動）模式沒有離開時的清理提示，**Claude Code 不會自動清掃這些 worktree**，鎖（lock）會留到下次 session 的 stale-lock sweep 才釋放。若要手動清除需 `git worktree remove`（鎖住則先 `git worktree unlock`）。
來源：[Worktrees — Clean up worktrees](https://code.claude.com/docs/en/worktrees)

這對 agent-flow 若採「headless + `--worktree` 平行跑多張票」有直接影響：長流程或 CI 情境下需要自行設計 worktree 生命週期管理，不能單純依賴互動模式的自動清理行為。

### 4.6 Worktree 與主 Checkout 共享的東西

Worktree 與主 checkout **共享**：同一個 `.git` 目錄（所以 `git commit` 等指令在 sandbox 下也能正常寫入共享的 git 資料庫）、專案層級安裝的 plugins（不需每個 worktree 重裝）、以及權限核准記錄（在 worktree 中選「不要再問」會寫入主 checkout 的 `.claude/settings.local.json`，套用到所有 worktree 且 worktree 被刪除後仍保留，v2.1.211+）。
來源：[Worktrees — What worktrees share with the main checkout](https://code.claude.com/docs/en/worktrees)

---

## 5. Hooks 可否用來做品質迴圈

Hooks 是在特定生命週期節點觸發的使用者自訂命令、HTTP endpoint、MCP 工具、LLM prompt，**或子代理**（文件原文：「user-defined commands, HTTP endpoints, MCP tools, LLM prompts, or subagents」）。
來源：[Hooks reference](https://code.claude.com/docs/en/hooks)

### 5.1 完整事件清單（33 個，節錄與品質迴圈相關者）

| 事件 | 觸發時機 | 可否阻擋 |
|---|---|---|
| `PreToolUse` | 工具呼叫執行前 | 可（`permissionDecision: deny` 或 exit code 2） |
| `PostToolUse` | 工具呼叫成功後 | 不可阻擋（工具已執行完），但可回饋文字給 Claude |
| `PostToolUseFailure` | 工具呼叫失敗後 | 同上 |
| `PostToolBatch` | 一整批平行工具呼叫都解決後、下一次模型呼叫前 | 可 |
| `SubagentStart` | 子代理被產生時 | 僅資訊性 |
| `SubagentStop` | 子代理結束時 | **可**，exit 2 會阻止子代理停止 |
| `Stop` | Claude 完成一次回應時 | **可**，exit 2 會阻止停止並繼續對話 |
| `StopFailure` | 因 API 錯誤而結束該輪 | — |
| `TaskCreated` | `TaskCreate` 建立任務時 | 可阻止建立 |
| `TaskCompleted` | 任務被標記完成時 | **可**，exit 2 阻止標記完成 |
| `TeammateIdle` | Agent team 隊友即將進入閒置狀態時 | **可**，exit 2 讓隊友繼續工作 |
| `PreCompact` | 內容壓縮（compaction）前 | 可阻止壓縮 |
| `PostCompact` | 壓縮完成後 | — |
| `WorktreeCreate` / `WorktreeRemove` | worktree 建立／移除時 | 可完全取代預設 git 邏輯（見第 4 節非 git VCS） |

完整 33 個事件另包含 `SessionStart`/`SessionEnd`/`Setup`/`UserPromptSubmit`/`UserPromptExpansion`/`PermissionRequest`/`PermissionDenied`/`Notification`/`MessageDisplay`/`InstructionsLoaded`/`ConfigChange`/`CwdChanged`/`DirectoryAdded`/`FileChanged`/`PreModelSwitch`/`PostModelSwitch`/`Elicitation`/`ElicitationResult`。
來源：[Hooks reference](https://code.claude.com/docs/en/hooks)

### 5.2 阻擋／強制重做的機制

Exit code 2 是**唯一單靠 exit code 就能觸發阻擋的方式**；不帶合法 JSON 的 exit code 1 會被視為非阻擋錯誤而放行。也可以 exit 0 並輸出符合 schema 的 JSON（`hookSpecificOutput.permissionDecision: "deny"` + `permissionDecisionReason`）達到同樣效果並附上理由文字。
來源：[Hooks reference — Exit code behavior](https://code.claude.com/docs/en/hooks)

`SubagentStop` 的輸入 JSON 含 `agent_id`、`agent_type`、`last_assistant_message`、`subagent_result` 等欄位；`Stop` 含 `last_assistant_message`。範例（文件示意）：

```bash
#!/bin/bash
RESULT=$(jq -r '.subagent_result.status' <<< "$(cat)")
if [[ "$RESULT" != "approved" ]]; then
  echo "Subagent review not approved" >&2
  exit 2  # 阻止該子代理停止，使其繼續處理
fi
exit 0
```

`TaskCompleted` 可用來擋下任務被標記完成（例如驗證未通過時拒絕標記），`TeammateIdle` 可用來讓隊友在還有工作時不要閒置下來。
來源：[Hooks reference — SubagentStop / TaskCompleted / TeammateIdle](https://code.claude.com/docs/en/hooks)

**對 agent-flow 品質迴圈設計的直接意義**：`SubagentStop` hook 理論上可以實作「阻止 Dev phase 的撰寫子代理停止，直到品質檢查通過」的迴圈——但要注意，被 exit 2 擋下後，**繼續工作的是同一個子代理（在自己的 context 內重試）**，而不是自動觸發一個「獨立於作者」的審查者去看。若要做到「作者與審查者分離」，仍需要 orchestrator 層在拿到子代理結果後，明確再派一個獨立的審查子代理（用 Agent tool），而不能單靠 `SubagentStop` hook 本身完成角色分離。這點文件沒有直接示範，屬於需要實測驗證的行為（見「待實測」）。

### 5.3 PreCompact 用於狀態存檔

`PreCompact` hook 收到 `compact_reason`（`manual` 或 `auto`），文件建議的用途之一就是「archive the full transcript」——在壓縮前把完整 transcript 存檔。這是官方認可、可用於長流程狀態保存的機制之一。
來源：[Explore the context window — PreCompact hook](https://code.claude.com/docs/en/context-window)（經 WebSearch 摘要確認原文提及此 hook 與其存檔用途）

---

## 6. 狀態外部化（長流程狀態管理）

### 6.1 Session 持久化與 Transcript

每個 session 的完整對話（含工具呼叫與結果）持續寫入本機 JSONL：`~/.claude/projects/<project>/<session-id>.jsonl`。**重要警告**：「Each line is a JSON object for a message, tool use, or metadata entry. The entry format is internal to Claude Code and changes between versions, so scripts that parse these files directly can break on any release.」——文件明確建議不要直接解析這個檔案，改用 `/export`、`claude -p --output-format json/stream-json`，或 hooks/statusline 收到的 `transcript_path` 來取得結構化資料。
來源：[Manage sessions — Where transcripts are stored](https://code.claude.com/docs/en/sessions)

保留期預設 30 天（`cleanupPeriodDays` 可調整）。

### 6.2 Resume 機制

`--continue`（恢復目前目錄最近一次 session）、`--resume <id|name>`（恢復指定 session，可跨目錄尋找，v2.1.223+ 起可在本機任一專案中找到該 ID）、`--fork-session`（複製出新 session ID，不動到原本的 worktree 綁定）、`/branch`（在同一 session 中建立對話分支）。恢復時會還原：對話歷史、模型（除非已退役或被 `availableModels` 擋掉）、`--agent` 指定的子代理身分、權限模式（規則因恢復方式而異）、進行中的 goal、尚未過期的排程任務。**但不會還原**：`--mcp-config`、`--settings`、`--plugin-dir`、`--fallback-model`、`--add-dir` 加入的目錄——這些需要在 resume 時重新傳入。
來源：[Manage sessions — What a resumed session restores](https://code.claude.com/docs/en/sessions)

### 6.3 Context 壓縮（Compaction）

模型 context window 填滿後會自動壓縮（auto-compact），壓縮邏輯與手動 `/compact` 相同。Sonnet 5 這類大 context window 模型預設在約 967K tokens 觸發（可用 `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 調整），可用 `/autocompact <token數>` 設定閾值。CLAUDE.md 內容會被壓縮器讀取，可在其中加入自由格式的段落指示壓縮時該保留什麼；但**壓縮會用摘要取代較舊訊息，因此對話早期給的具體指示不保證被保留**。若單一檔案或工具輸出過大導致壓縮後 context 又立即被塞滿，Claude Code 會在嘗試數次後停止並回報「Autocompact is thrashing」錯誤，而非無限迴圈。
來源：WebSearch 摘要引用自 [Explore the context window](https://code.claude.com/docs/en/context-window)、[Manage costs](https://code.claude.com/docs/en/costs)（此頁面本身為互動式模擬頁，官方原文經工具摘要取得，未逐字核對原始 JS 原始碼）

`PreCompact` hook 可在壓縮發生前執行自訂邏輯（如存檔完整 transcript），見 5.3。
來源：[Explore the context window](https://code.claude.com/docs/en/context-window)

長時間閒置後恢復大型 session（Pro/Max 方案，閒置超過約 1 小時且對話超過 100,000 tokens）時，Claude Code 會跳出對話框讓使用者選擇「Resume from summary」（立即執行一次 `/compact`）、「Resume full session as-is」（保留完整對話但重新處理/快取全部歷史）、或「Don't ask me again」。
來源：[Manage sessions — Resume from a summary](https://code.claude.com/docs/en/sessions)

### 6.4 Dynamic Workflows 的狀態機制

Workflow 執行期把每個 `agent()` 呼叫的結果保存在腳本變數中（而非塞進 Claude 的 context），這使得**同一 session 內**的 workflow 執行可以被暫停與續跑（resume）：已完成的 agent 直接回傳快取結果；執行中被中斷的 agent 重新開始；失敗的 agent 連同其後啟動的所有 agent（即使已完成）都會重跑。每次執行的腳本會被寫到 `~/.claude/projects/` 底下該 session 的目錄中。若把整個 session 背景化（background），workflow 會在背景 session 中以相同方式重播並繼續；若直接結束 session（Exit and stop tasks），workflow 隨之停止，但已存的結果仍保留，供之後用 `claude --resume` 恢復並重新請求執行同一 workflow 時重播使用。
來源：[Orchestrate subagents at scale with dynamic workflows — How a workflow runs / Resume after a pause](https://code.claude.com/docs/en/workflows)

### 6.5 Agent Teams 的狀態儲存位置

Team config：`~/.claude/teams/{team-name}/config.json`（session 結束即刪除，**不持久**）；任務清單：`~/.claude/tasks/{team-name}/`（**持久保存於本機、不上傳，恢復 session 後任務仍在**，保留期同樣受 `cleanupPeriodDays` 控制）。每個 agent 的信箱（mailbox）是獨立 JSON 檔：`~/.claude/teams/{team-name}/inboxes/{agent-name}.json`。團隊名稱衍生自 session ID 前 8 碼（`session-<8碼>`），**沒有專案層級的團隊設定**（放一個 `.claude/teams/teams.json` 在專案目錄不會被識別為設定檔）。
來源：[Agent teams — Architecture](https://code.claude.com/docs/en/agent-teams)

### 6.6 跨 Session 訊息（Cross-session messaging）作為狀態傳遞手段

若 agent-flow 的 8 個 phase 各自用獨立 session（而非單一長對話），Claude 之間可用 `ListAgents` + `SendMessage` 工具互傳純文字訊息（**只傳文字，不傳送對方的對話歷史或檔案**）。同機器上的傳遞走本機 socket（macOS/Linux 為 Unix domain socket，Windows 為 named pipe），不經過 Anthropic 伺服器；跨機器則經 Remote Control 連線走 Anthropic 伺服器。`-p`（headless）session 預設也會綁定收信 socket（除非用 `--bare`），因此長跑的 headless worker 也能接收訊息，但無法顯示核准對話框，改用 `dialogExpiry`（預設 5 分鐘）逾時規則處理待核准訊息；要讓 headless worker 無人值守接收訊息，需在 `--settings` 中把 `crossSessionInbound` 設為 `accept`。
來源：[Message your other Claude Code sessions](https://code.claude.com/docs/en/cross-session-messaging)

**與官方文件的定位差異**：文件明確建議「resume session 是延續同一對話與其 context 的正確做法，cross-session messaging 只用於傳遞『發現』或『狀態』這類單則文字訊息」。因此若 agent-flow 想要「phase A 產出的 spec 完整交給 phase B」，正確做法是 resume 同一 session（或至少把 spec 寫成檔案讓下一個 phase 去讀），而不是靠 cross-session messaging 傳遞大量內容（訊息大小上限約一百萬字元，且是純文字，結構化資料不保證）。
來源：[Cross-session messaging — When to use / Limitations](https://code.claude.com/docs/en/cross-session-messaging)

### 6.7 官方對「把狀態寫進檔案」沒有給出統一建議模式

綜合以上，官方文件**沒有**針對「長流程用自訂 markdown/JSON 檔案在 repo 中持久化進度」給出專屬的 best practice 頁面或建議格式；能找到的官方支援點只有：transcript（格式不穩定、不建議直接解析）、workflow 腳本變數（僅限單一 workflow 執行內、單一 session 內）、agent teams 的任務清單（實驗性功能限定）、以及 hooks 收到的 `transcript_path`/`cwd` 等欄位可供自訂腳本另行寫檔。**agent-flow 若要自行設計「phase 狀態檔」（例如 `.agent-flow/state.json` 或每個 phase 一份 markdown），這是文件既未明確推薦也未反對的自建方案**，需要自行驗證其在 hook 中讀寫的穩定性與時機（例如 `SubagentStop`/`Stop` hook 內寫檔案是否會與後續壓縮、resume 行為衝突）。

---

## 7. Headless／程式化執行

### 7.1 基本用法

`claude -p "<prompt>"`（或 `--print`）非互動執行；`--output-format text|json|stream-json` 控制輸出格式。`json` 格式回傳 `result`/`session_id`/`total_cost_usd`（及各模型分項成本，為 client-side 估算，可能與實際帳單有落差）。`stream-json` 每行一個 JSON 事件，可搭配 `--include-partial-messages` 取得逐 token 串流。
來源：[Run Claude Code programmatically](https://code.claude.com/docs/en/headless)

### 7.2 `--bare` 模式

跳過 hooks、skills、custom commands、subagents、plugins、MCP servers、auto memory、CLAUDE.md 的自動探索以加速啟動，適合 CI／腳本要求「每台機器結果一致」的場景。**官方明言**：「`--bare` is the recommended mode for scripted and SDK calls, and will become the default for `-p` in a future release.」`--bare` 模式下仍可用 `--allowedTools`、`--agents <json>`（自訂子代理）、`--mcp-config`、`--plugin-dir` 個別載入所需內容。
來源：[Run Claude Code programmatically — Start faster with bare mode](https://code.claude.com/docs/en/headless)

### 7.3 從 Hook 或 Skill 內再起一個 `claude` 程序當 Worker

文件沒有把「在 hook 或 skill 腳本內呼叫 `claude -p` 產生另一個 worker 程序」列為官方推薦的正式模式（未有專屬章節示範這種用法）。但從既有機制可以合理推得可行性（**以下屬推論而非文件直接背書**）：
- `-p` 模式支援被當一般 CLI 工具管線化使用（`git diff | claude -p "..."`），技術上 hook 腳本（本質是任意 shell 命令）當然可以呼叫它。
- Cross-session messaging 章節證實 `-p` session 會綁定收信 socket、可被其他 session 訊息喚醒，說明官方是把 headless `-p` 進程視為可與其他 Claude Code 進程互動的一等公民，而非純粹一次性批次工具。
- `SIGTERM`／`SIGINT` 對 `-p` 行程的處理、背景 Bash 任務結束時的 5 秒寬限期等章節，說明官方確實預期 `-p` 會被其他程序（例如父 shell script）啟動、監控與終止。

**未記載**：官方沒有明確說明「hook 呼叫的子行程算不算會被父 session 的 `PreToolUse`/`PostToolUse` 等 hook 遞迴觸發」「巢狀 `claude -p` 呼叫是否也受 `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` 限制」（推測不受限制，因為那是給 Agent tool 用的，`claude -p` 是全新獨立進程，不是透過 Agent tool 產生的子代理，但文件未明確排除或確認）。這點列入待實測。

### 7.4 權限與無人值守執行

`--permission-mode auto`（分類器自動審核多數動作）、`--permission-mode dontAsk`（只允許 allowlist 規則與唯讀命令，其餘一律拒絕，適合鎖死的 CI）、`--permission-prompts none`（無人可回答提示時，任何原本要跳出提示的動作直接被拒絕，並告知 Claude 不要重試）。`--allowedTools` 可用權限規則語法（如 `Bash(git diff *)`）精準允許特定命令前綴。
來源：[Run Claude Code programmatically — Auto-approve tools / Turn off permission prompts](https://code.claude.com/docs/en/headless)

### 7.5 追蹤子代理輸出

`--forward-subagent-text`（或 `CLAUDE_CODE_FORWARD_SUBAGENT_TEXT`）可在 `stream-json` 輸出中額外包含子代理的文字與思考區塊（預設只有 `tool_use`/`tool_result`），並透過 `parent_tool_use_id` 欄位重建巢狀樹（v2.1.219+ 起連巢狀子代理的訊息都會被轉發）。
來源：[Run Claude Code programmatically — Follow subagent messages](https://code.claude.com/docs/en/headless)

---

## 8. 每個子代理的 Model 選擇與成本控制

### 8.1 Model 解析順序

呼叫子代理時，model 依序取自：① 呼叫當下傳入的參數 → ② 子代理定義 frontmatter 的 `model` 欄位 → ③ 環境變數 `CLAUDE_CODE_SUBAGENT_MODEL` → ④ 主對話目前使用的模型（v2.1.251 之前，`CLAUDE_CODE_SUBAGENT_MODEL` 的優先序更高，會蓋過前兩者，含 `model: inherit`）。若要強制所有子代理統一用同一模型（例如全部用便宜的 haiku），需**同時**設定 `CLAUDE_CODE_SUBAGENT_MODEL` 與 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`，此時連內建的 Explore/Plan 子代理也會被強制改模型。
來源：[Subagents — Model resolution order](https://code.claude.com/docs/en/sub-agents)

### 8.2 官方成本建議

- 簡單子代理任務指定 `model: haiku`。
- Sonnet 適合大多數編碼任務，成本低於 Opus；Opus 保留給複雜架構決策。
- **把高 verbose 量的操作（跑測試、抓文件、處理 log）委派給子代理**，讓詳細輸出留在子代理自己的 context，只有摘要回到主對話——這是官方明確列出的降低成本手法之一。
- Agent teams 用 Sonnet 做隊友以平衡成本與能力；保持團隊精簡；縮短 spawn prompt（隊友的 CLAUDE.md/MCP/skills 是自動載入的，但 spawn prompt 內容從一開始就會佔用其 context）；工作做完就關閉隊友，因為每個活躍隊友持續消耗 token。
- Effort（推理努力）等級可用 `/effort`（`low`/`medium`/`high`/`xhigh`/`max`）調整；子代理有自己的 `effort` frontmatter 欄位可覆寫 session 等級；Fable 系列模型不支援關閉 extended thinking。

來源：[Manage costs — Choose the right model / Delegate verbose operations to subagents](https://code.claude.com/docs/en/costs)、[Agent teams — Token usage](https://code.claude.com/docs/en/agent-teams)

### 8.3 子代理與 Prompt Cache

一般子代理（含 agent teams 的 in-process 隊友、workflow 產生的 agent）的請求落在主對話 cache TTL 分桶之外，**預設只有 5 分鐘快取存留時間**（即使是訂閱方案），可用 `subagentPromptCacheTtl` 設為 `1h` 延長（API 會以較高費率計費 1 小時快取寫入）。Dynamic workflow 的同批次 fan-out agent，若共用相同 model/effort/agent type/tools/output schema/工作目錄，會共讀彼此的 prompt cache 前綴（第一個 agent 先跑，其餘最多延遲 5 秒等待共享前綴快取生效，可用 `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` 調整）。
來源：[Agent teams — Token usage](https://code.claude.com/docs/en/agent-teams)、[Orchestrate subagents at scale with dynamic workflows — Prompt caching in a fan-out](https://code.claude.com/docs/en/workflows)

若 agent-flow 的 Dev phase 用 dynamic workflow 平行處理多張票證，且票證的審查子代理型態（model/tools/schema）相同，理論上可透過這個共享前綴快取機制降低成本，但預設只有 5 分鐘 TTL，需視票證處理節奏評估是否要設定 `1h`。

---

## 待實測

以下項目文件說明不完整、但會直接影響 agent-flow 架構設計，建議在正式開發前用最小可行範例（minimal reproducible example）實測：

1. **`SubagentStop` hook 的「阻止停止」實際語意**：exit 2 後究竟是讓「同一個子代理」在自身 context 內繼續嘗試（reactive retry），還是可以搭配某種機制讓 orchestrator 收到訊號後改派一個「獨立於作者」的審查子代理？文件的範例只展示前者。若 agent-flow 的品質迴圈設計依賴「hook 直接觸發獨立審查角色」，需要實測確認 hook 只能retry 同一 agent，還是能真正切換執行者身分——這決定「審查獨立於作者」這個核心需求究竟要靠 hook 實作、還是必須靠 orchestrator 邏輯（在拿到子代理回傳結果後手動再派審查子代理）實作。

2. **`SubagentStop`/`PreToolUse` 等 hook 的 `matcher` 語法完整規則**：文件範例僅示範用子代理名稱字串（如 `code-reviewer`）當 matcher，未列出是否支援正規表達式、萬用字元、多名稱組合。這決定能否針對 agent-flow 8 個 phase 中特定角色（如僅對 `ticket-writer` 生效、不影響 `code-reviewer`）精準掛載品質迴圈 hook。

3. **`TaskCreate`/`TaskGet`/`TaskList`/`TaskUpdate` 在 Fable 5 系列上 opt-in 後的實際效果與穩定性**：這組工具在新模型上預設關閉且屬於較新機制，文件未說明 opt-in 後在長流程、多子代理情境下的 context 消耗與可靠度是否符合預期。若 agent-flow 想用官方共享任務清單追蹤 8 個 phase 或多張票證，需要實測其在 headless 模式與跨 session resume 下的行為（尤其任務清單持久化在 `~/.claude/tasks/`，但 agent teams 頁面已註明「任務狀態可能延遲、卡住依賴任務」這類已知缺陷，不確定是否僅限 agent teams 情境或也影響一般 session 內的 Task 工具使用）。

4. **Dynamic Workflow 能否從子代理內部觸發，或只能由使用者輸入的 prompt 觸發**：文件明確列出 `ultracode` 關鍵字與「使用工作流程」等自然語言請求**只在使用者親自輸入的 prompt 中**生效，明確排除 `-p` 傳入的 prompt、SDK 非人類輸入、排程 prompt、webhook payload。這代表如果 agent-flow 用 headless（`claude -p`）串接整條 SDD+TDD 流程，官方的 dynamic workflow 高階編排能力可能無法透過一般對話式觸發，必須改用 Agent SDK 直接呼叫 Workflow 工具（文件連結到 Agent SDK TypeScript 參考中的 `Workflow` 項目，本次調查未深入該頁）。若 agent-flow 的 Dev phase 平行執行票證想借助 dynamic workflow 的 16 並行、1000 agent 上限與自動交叉驗證能力，需要先確認 Agent SDK 呼叉 Workflow 工具的正確方式與其在 `-p` 模式下的權限流程（文件提到 `-p`/Agent SDK 呼叫 Workflow 時仍會走 `PreToolUse` 一類的一般權限評估，但沒有端對端範例）。

5. **Agent teams 意外啟用的防護是否完整**：`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 一旦被任何設定來源（含使用者個人 `settings.json`、managed settings）設為 `1`，Claude 為子代理命名時就會自動升級為隊友。agent-flow 若要保證「Dev phase 的票證 worker 一定是輕量子代理語意」，需要實測：在 plugin 的 `settings.json`（或 hook）中明確關閉此旗標，是否真的能蓋過使用者個人設定或其他 plugin 的設定（文件的「Settings precedence」規則顯示 managed settings 優先序最高，plugin 本身的設定能否達到同等強制力未在本次調查中確認）。

6. **Headless + `--worktree` 平行跑多張票證的長期穩定性**：文件承認 `-p` 模式下的 worktree 不會自動清理、鎖需靠下次 session 的 stale-lock sweep 釋放。若 agent-flow 的 Dev phase 在 CI 或無人值守環境下用多個 `claude -p --worktree` 平行處理票證，需要實測：多個 headless 行程同時建立/釋放 worktree lock 時是否有 race condition、`worktree.baseRef: "head"` 在平行情境下每個 worktree 各自從哪個 commit 分岔（是否會因為平行建立時序不同而分岔點不一致）。

7. **自訂「phase 狀態檔」持久化方案的可靠時機**：如第 6.7 節所述，官方沒有針對「把 8-phase 進度寫進 repo 內檔案」給出建議格式或時機保證。需要實測：在 `Stop`/`SubagentStop`/`PreCompact` 等 hook 內寫入狀態檔案，是否會與 Claude Code 自身的 auto-compact、session resume、worktree 隔離的四項強制檢查（第 4.2 節，例如寫入路徑若被誤判為「目標路徑落在主 checkout」會被擋下）互相衝突。

8. **子代理背景權限提示的實際互動體驗**：背景子代理的權限提示會「浮現在主 session 並標明是哪個子代理」，但若 agent-flow 的 Dev phase 同時背景平行跑多張票證的子代理，多個子代理同時觸發權限提示時的排隊、UI 呈現與是否可能互相阻塞，文件未描述，需要實測驗證是否會造成無人值守流程卡死（可能需要搭配 `--permission-prompts none` 或完整 allowlist 規避）。
