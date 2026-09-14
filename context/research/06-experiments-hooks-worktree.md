# Hooks 品質閘門與 Worktree 隔離：實測報告

調查目的：驗證 `research/02-orchestration.md` 「## 待實測」章節中，文件說明不完整、但直接影響 `agent-flow`（八 phase SDD+TDD 工作流程 plugin）架構設計的六個行為，尤其是「品質迴圈能否換人審查」（SubagentStop 身分問題）與「Wrap phase 能否全自動」（無人值守權限提示）兩個核心裁決點。

驗證環境：`claude --version` = `2.1.259 (Claude Code)`；所有測試 repo 建立於 `/tmp/agent-flow-exp-hooks/` 下（依實驗分子目錄），hooks 與 agents 一律放測試專案的 `.claude/`（project scope），**未寫入 `~/.claude/`**；模型一律 `claude-haiku-4-5-20251001`；一律 headless（`-p`）。

**重要環境警告（影響第 5 項的初次測試結果）**：本機 `~/.claude/settings.json`（使用者既有全域設定，非本次實驗寫入）含：

```json
"permissions": {
  "allow": ["Bash(*)", "WebFetch(*)", "mcp__context7__*", "mcp__grep__*"],
  "deny": ["NotebookEdit", "Read(~/.ssh/**)", ...],
  "defaultMode": "bypassPermissions"
}
```

這代表本機所有 `claude -p` 呼叫預設 `permissionMode` 是 `bypassPermissions`，且 `Bash(*)` 被全域 allowlist。這汙染了第 1–4 項與第 6 項實驗的預設行為（工具呼叫全部被自動核准，未曾真正觸發過權限提示），但不影響那些實驗的結論（它們驗證的是 hook/worktree 機制本身，與權限模式無關）。第 5 項實驗因此改用 CLI `--permission-mode default` 明確覆寫，並改測 `Write`（全域未被 allowlist 的工具）而非 `Bash`，才能觀察到真正的權限決策，詳見該項小節。

---

## 1. SubagentStop 閘門的身分問題（最關鍵）

**設計**：`/tmp/agent-flow-exp-hooks/exp1-subagentstop/`，agent `writer`（寫一首俳句到檔案），`.claude/settings.json` 掛 `SubagentStop` matcher `"writer"`，指令型 hook：讀 stdin JSON、用 `agent_id` 記次數、次數 < 2 時輸出訊息到 stderr 並 `exit 2`（要求補寫一行 `REVISED`），第二次 `exit 0` 放行。

**指令**：
```bash
claude -p "Use the writer subagent to write a haiku about autumn into a file named poem.txt" \
  --model claude-haiku-4-5-20251001 \
  --output-format json \
  --allowedTools "Write,Read,Bash,Agent"
```

**關鍵輸出**（`logs/summary.log`）：
```
[hook] fired for agent_id=a3b628bc41a67707a count=1 at 1788517331.382943000
[hook] fired for agent_id=a3b628bc41a67707a count=2 at 1788517336.954470000
```

兩次觸發的 `agent_id` **完全相同**（`a3b628bc41a67707a`）。第一次 payload 的 `last_assistant_message`：「完成了。秋季詩歌已儲存至...」；第二次 payload（`stop_hook_active` 從 `false` 變 `true`）的 `last_assistant_message`：「已更新。詩歌文件現已在末尾添加了 'REVISED' 一行...」——子代理用的動詞是「更新」而非「重寫」，且最終 `poem.txt` 內容是原本俳句 + 新增的 `REVISED` 行，證明它**記得自己第一次寫過什麼**：

```
Leaves fall slowly down
Golden branches stripped of green
Winter waits to come
REVISED
```

完整 payload 結構（第二次觸發）：
```json
{
  "session_id": "1fc38b12-5f13-4aed-8c1f-a9ecc36b3374",
  "transcript_path": "/Users/wiasliaw/.claude/projects/.../1fc38b12....jsonl",
  "cwd": "/private/tmp/agent-flow-exp-hooks/exp1-subagentstop",
  "prompt_id": "15212393-e4c5-40ed-aee0-917954487bb0",
  "permission_mode": "bypassPermissions",
  "agent_id": "a3b628bc41a67707a",
  "agent_type": "writer",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": true,
  "agent_transcript_path": "/Users/wiasliaw/.claude/projects/.../subagents/agent-a3b628bc41a67707a.jsonl",
  "last_assistant_message": "已更新。詩歌文件現已在末尾添加了 'REVISED' 一行，儲存至 .../poem.txt。",
  "background_tasks": [ { "id": "a3b628bc41a67707a", "type": "subagent", "status": "running", ... } ],
  "session_crons": []
}
```

**與文件的差異**：`research/02-orchestration.md` §5.2 引用的官方範例 hook 讀取 `.subagent_result.status`（`jq -r '.subagent_result.status'`），但實測 payload **完全沒有 `subagent_result` 欄位**。文件說有 `subagent_result`，實測為不存在此欄位（至少本版本、本情境下），以實測為準，來源比對：[Hooks reference](https://code.claude.com/docs/en/hooks)。另外實測揭露文件未明確提及的欄位 `agent_transcript_path`（每個子代理獨立的 transcript 檔案路徑，格式 `<session-dir>/subagents/agent-<agent_id>.jsonl`）與 `stop_hook_active`（布林值，標示這是否為 hook 阻擋後的重試）。

**結論【證實】**：`SubagentStop` exit 2 阻擋後，重試的是**同一個子代理（同 `agent_id`、同 context）**，不是換一個獨立審查者。子代理在自己的 context 內看到 hook 的 stderr 文字後繼續作業，且保留先前的推理與產出記憶。Hook 機制本身**沒有**任何欄位或輸出格式可以指定「換人重跑」——`hookSpecificOutput` 只能 `allow`/`deny`/`default` 加文字，無法指派另一個 agent 型別去接手。

**未能測出**：是否有「hook 型別 `agent`」（`research/01-plugin-mechanism.md` §2.4 提到 `SubagentStop` 可掛 `type: agent` 的 hook，啟動「可用工具的 subagent 驗證器」）可以間接達成類似「獨立驗證」效果——這與 `SubagentStop` 阻擋重試機制是兩回事（hook 本身可以是獨立子代理去做驗證判斷，但它驗證完之後回傳的 `exit 2` 仍然只會讓**原本那個被攔下的子代理**重跑，不會把後續工作轉交給驗證用的 hook agent）。因時間限制未實測 `type: agent` hook 是否能把驗證意見以外的東西（如審查結果內容）帶回並影響下一輪；但這不影響上述核心結論。

**對 agent-flow 設計的影響**：品質迴圈的「審查者需獨立於作者」**不能靠 `SubagentStop` hook 本身完成**，必須由 orchestrator（主 session）在拿到子代理（撰寫者）結果後，明確再用 Agent tool 派一個獨立的審查子代理；`SubagentStop` hook 適合用來做「同一作者的自我修正重試迴圈」（如 lint/測試沒過就打回去自己修），但無法替代「換人審查」這個需求。

---

## 2. Hook matcher 語法

**設計**：`/tmp/agent-flow-exp-hooks/exp2-matcher/`，兩個 agent：`ticket-writer`、`code-reviewer`。單一 `SubagentStop` 事件同時掛三條 matcher 規則做對照：

```json
"SubagentStop": [
  { "matcher": "ticket-writer", "hooks": [...ruleA-exact...] },
  { "matcher": "ticket-writer|code-reviewer", "hooks": [...ruleB-pipelist...] },
  { "matcher": ".*-reviewer$", "hooks": [...ruleC-regex...] }
]
```

**指令**：
```bash
claude -p "First, use the ticket-writer subagent to write the text 'TICKET-1' into file ticket.txt. Then, use the code-reviewer subagent to write the text 'REVIEW-1' into file review.txt." \
  --model claude-haiku-4-5-20251001 --output-format json --allowedTools "Write,Agent"
```

**輸出**（`logs/summary.log`，逐字）：
```
[hook:ruleB-pipelist] fired for agent_type=ticket-writer at 1788517402.340868000
[hook:ruleA-exact] fired for agent_type=ticket-writer at 1788517402.340877000
[hook:ruleB-pipelist] fired for agent_type=code-reviewer at 1788517403.175969000
[hook:ruleC-regex] fired for agent_type=code-reviewer at 1788517403.176669000
```

**結論【證實】**：
- `matcher: "ticket-writer"`（純字母數字+連字號）＝精確字串比對，**只**對 `ticket-writer` 觸發，`code-reviewer` 完全不受影響。
- `matcher: "ticket-writer|code-reviewer"`（pipe 分隔）＝多名稱清單（OR），對兩者皆觸發。
- `matcher: ".*-reviewer$"`（含 `.`、`*`、`$` 等特殊字元）＝視為 JavaScript regex，**只**對 `code-reviewer` 觸發（比對 `agent_type` 尾碼），`ticket-writer` 不受影響。

這與 `research/01-plugin-mechanism.md` §2.4 記載的「Matcher 規則」完全吻合（純字母數字/`_`/`-`/空白/`,`/`|` = 精確字串或列表；含其他字元 = regex），本次是對該規則在 `SubagentStop` 事件、以 `agent_type` 為比對對象時的**逐字驗證**，非推翻。

**對 agent-flow 設計的影響**：可以精準只對特定角色（如僅 `ticket-writer` 作者）掛品質迴圈 hook，不影響 `code-reviewer` 等其他角色，且可用 pipe 清單一次涵蓋多個作者角色（如多張票證的 worker），regex 亦可用命名慣例（如統一 `-writer` 結尾）批次涵蓋。

---

## 3. Headless 平行 worktree

**設計**：`/tmp/agent-flow-exp-hooks/exp3-worktree/`，同一 repo 下同時背景啟動兩個 headless session，各用不同 `--worktree` 名稱：

```bash
claude -p "Create a file named ticket-a.txt ... commit ..." --worktree ticket-a --model claude-haiku-4-5-20251001 --allowedTools "Write,Bash(git *)" &
claude -p "Create a file named ticket-b.txt ... commit ..." --worktree ticket-b --model claude-haiku-4-5-20251001 --allowedTools "Write,Bash(git *)" &
wait
```

**輸出**：兩者皆 `exit 0`，`stderr` 皆空（無鎖衝突、無錯誤訊息）。事後 `git worktree list`：
```
/private/tmp/.../exp3-worktree                            649323c [main]
/private/tmp/.../exp3-worktree/.claude/worktrees/ticket-a 4151a90 [worktree-ticket-a] locked
/private/tmp/.../exp3-worktree/.claude/worktrees/ticket-b 0767089 [worktree-ticket-b] locked
```
分支各自獨立（`worktree-ticket-a`、`worktree-ticket-b`），各自 commit 成功（`git log` 各自可見 `add ticket-a`／`add ticket-b`）；鎖檔內容：
```
.git/worktrees/ticket-a/locked: claude session ticket-a (pid 97765 start Fri Sep 4 10:23:56 2026)
.git/worktrees/ticket-b/locked: claude session ticket-b (pid 97767 start Fri Sep 4 10:23:56 2026)
```

**清理測試**：兩個 headless session 都已正常結束（exit 0）**之後**，鎖依然是 `locked` 狀態、worktree 目錄依然存在。額外測試：在同一 repo 主目錄下再跑一個**普通** `claude -p`（不帶 `--worktree`），事後 `git worktree list` 顯示鎖與 worktree **依然原封不動**——一般 headless 呼叫本身**不會**觸發文件所稱的「stale-lock sweep」。

**結論【證實】**：不同 `--worktree` 名稱的兩個 headless 行程真正並行時**沒有 lock 或 branch 名衝突**（各自獨立分支、各自獨立鎖檔、皆基於平行建立當下的 `main` HEAD 分岔）。**【證實，並補充文件未寫清楚之處】**：headless 完成後不清理殘留物——殘留物具體樣貌是 `.claude/worktrees/<name>/` 目錄仍在、`.git/worktrees/<name>/locked` 鎖檔仍在（內含已死的 PID）、`worktree-<name>` 分支仍在。文件（[Worktrees — Clean up worktrees](https://code.claude.com/docs/en/worktrees)）只說「鎖會留到下次 session 的 stale-lock sweep 才釋放」，但實測發現：**單純再跑一個 headless `-p` session 並不會觸發這個 sweep**（sweep 可能僅在互動模式或特定操作時發生，本次實測環境無 TTY 無法測試互動模式，此點列為未能測出）。

**未能測出**：`worktree.baseRef: "head"` 在平行情境下是否會因時序不同而分岔點不一致——本次兩個平行行程用的是預設 `baseRef`（未特別設定 `head`），且測試時主分支在整個測試期間沒有新 commit 進來，不足以觀察到分岔點不一致的情境；互動模式下的 stale-lock sweep 行為（因無 TTY 環境未能測試）。

**對 agent-flow 設計的影響**：Dev phase 用多個 headless `--worktree` 平行跑票證是安全的（不會相撞），但**必須自行設計 worktree/lock 清理機制**（例如 Wrap phase 結束時明確跑 `git worktree remove`/`git worktree unlock`），不能依賴 Claude Code 自動清掃。

---

## 4. 子代理 `isolation: worktree`

**設計**：`/tmp/agent-flow-exp-hooks/exp4-isolation/`，agent `iso-worker`（frontmatter `isolation: worktree`），每次執行先把 `pwd`/`branch`/`commit`/時間戳寫到 repo 外的固定 log 檔（`/tmp/.../logs/iso-log.txt`，刻意放在 worktree 之外以區分「worktree 內變更」與「worktree 外副作用」）。

**(a) 同一 agent 跑兩次是否為同一 worktree**：單一 `-p` 呼叫要求依序（非同一次呼叫內）呼叫 `iso-worker` 兩次，各自在自己的 worktree 內寫入 `change-1.txt`／`change-2.txt`。`iso-log.txt` 逐字輸出：
```
PWD=/private/tmp/.../exp4-isolation/.claude/worktrees/agent-aeae419bc9c2b9456 BRANCH=worktree-agent-aeae419bc9c2b9456 ...
PWD=/private/tmp/.../exp4-isolation/.claude/worktrees/agent-a8047144f37bf7bc8 BRANCH=worktree-agent-a8047144f37bf7bc8 ...
```
兩次呼叫的目錄與分支**完全不同**。事後檢查各 worktree 目錄內容：`agent-aeae419bc9c2b9456/` 只有 `change-1.txt`，`agent-a8047144f37bf7bc8/` 只有 `change-2.txt`，證實彼此互不可見、各自獨立。

**結論【證實】（a=否）**：同一個 agent（同名）每次執行都拿到**全新、獨立**的臨時 worktree，不會重用。

**(b) worktree 能否跨呼叫存活以供 Dev→Review 共用**：直接由 (a) 的結果推論——**否**，每次呼叫（即使是同一 agent 名稱）都是新 worktree，因此 `isolation: worktree` 這個機制本身無法讓「Dev 子代理」與「Review 子代理」自動共用同一份隔離工作目錄；若要共用，必須靠其他機制（例如兩者共用同一個用 `--worktree` 或 `EnterWorktree` 建立、session 層級的 worktree，而非各自宣告 `isolation: worktree`）。

**(c) 無變更時自動清理**：第三次呼叫要求「不要做任何變更，只記錄環境後停止」。`iso-log.txt` 顯示這次仍被分配了新 worktree（`agent-ad48f5f10a91c0c64`），但**事後 `git worktree list`、`.claude/worktrees/` 目錄、`.git/worktrees/` 目錄、`git branch -a` 都完全找不到這個 worktree 或其分支**——目錄、admin 資料、分支三者皆被乾淨移除。相對地，(a) 中兩個有變更的 worktree 在整個測試過程中**持續保留在硬碟上**（`.claude/worktrees/agent-a8047144f37bf7bc8`、`agent-aeae419bc9c2b9456` 皆仍存在）。另外注意到：`isolation: worktree` 產生的 worktree 執行完成後**沒有殘留 `locked` 鎖檔**（不同於第 3 項 `--worktree` session 級的鎖會留到下次 sweep），與文件「該清掃在 agent 執行期間會用 `git worktree lock` 保護中的 worktree」的描述一致——鎖僅存在於執行期間，執行完（不論有無變更）就釋放。

**結論【證實】(c)**：無變更的 worktree 完成後確實會自動清除（目錄、分支、admin 資料一併刪除），與 [Worktrees — Isolate subagents with worktrees](https://code.claude.com/docs/en/worktrees) 文件描述一致。

**對 agent-flow 設計的影響**：`isolation: worktree` 適合「每張票證各自一次性隔離執行」（如 Dev phase 一個 worker 對應一張票），但**不適合**用來讓 Dev 與 Review 兩個子代理共用同一份隔離工作區——若需要「Dev 寫完、Review 在同一份未 commit 的變更上檢查」，應改用 session 層級的 `--worktree`/`EnterWorktree`（讓 Dev 與 Review 都在同一個已建立的 worktree 內以子代理身分工作），而非替 Review 也掛 `isolation: worktree`。

---

## 5. 無人值守的權限提示

**環境汙染與修正**：見文件開頭警告。首次測試（子代理跑未列入 allowlist 的 `Bash` 指令）在預設條件下**直接成功**，因為使用者全域設定 `defaultMode: bypassPermissions` 且 `Bash(*)` 全域 allowlist，並非真正測到「需要權限但未核准」的情境。改用兩項修正：CLI 明確帶 `--permission-mode default`（覆寫 session 的預設模式）；受測動作改為 `Write`（本機全域設定中**未**被 allowlist 的工具），確保是真正未被任何規則涵蓋的動作。

**(單一子代理) 指令**：
```bash
claude -p 'Call the Agent tool now with subagent_type="risky-writer", ...' \
  --model claude-haiku-4-5-20251001 --output-format json \
  --permission-mode default --allowedTools "Agent"
```
背景執行、外部加 30 秒觀察窗（自訂 `sleep 30` + `kill -0` 判斷，因本機無 `timeout`/`gtimeout` 指令）。

**結果**：行程在 30 秒觀察窗內**自行結束**（未卡住），`exit=0`；目標檔案 `write-test-marker.txt` **未被建立**；最終回覆逐字：
> 寫入權限被拒絕。risky-writer 代理嘗試在 `/tmp/agent-flow-exp-hooks/exp5-permissions/write-test-marker.txt` 建立檔案時遭到權限系統阻止。

**(兩個子代理同時觸發) 指令**：同一輪內平行呼叫 `risky-writer`、`risky-writer-2` 兩個子代理，各自嘗試寫入不同檔案，皆未被 allowlist 涵蓋。同樣加 35 秒觀察窗。

**結果**：同樣**自行結束**（未卡住），兩個檔案皆未建立，最終回覆逐字：
> Agent 1 (risky-writer) completed with a permission denial ... Waiting for agent 2 to complete.
> Agent 2 (risky-writer-2) also completed with a permission denial ...
> Both parallel agents ran and both encountered write permission denials.

**結論【證實】**：headless（`-p`）模式下，子代理觸發「需要權限但未被 allowlist 涵蓋、也未通過 `--permission-mode` 自動核准」的操作時，行為是**直接拒絕（deny）並讓子代理正常結束、回報拒絕原因**——**不會卡住等待**（沒有 TTY 可回答，所以不會真的掛起），主 session 也能正常收到拒絕結果並繼續往下走、正常輸出最終摘要，**不會因此整個 process 失敗或掛起**。這與文件描述的 `--permission-prompts none`（[Headless — Turn off permission prompts](https://code.claude.com/docs/en/headless)）行為一致，但本次實測連**該旗標都沒有帶**，只用一般 `--permission-mode default`，headless 下同樣自動變成「拒絕」而非「卡住」——這代表 headless 模式（無 TTY）本身即會讓未涵蓋動作預設走拒絕路徑，而不需要額外指定 `--permission-prompts none` 才能避免卡死。**多個子代理同時觸發時，彼此獨立拒絕、無互相阻塞或排隊延遲**現象。

**對 agent-flow 設計的影響**：Wrap phase（或任何 headless、無人值守的 phase）「全自動」在權限維度上**是可行的**——即使 allowlist 沒設好，未涵蓋的動作會乾淨地被拒絕、流程不會卡死，只是該動作本身不會執行（會被回報為「被拒絕」，需要 orchestrator 邏輯自行判斷拒絕後如何處理，例如記錄失敗、改用其他手段，或提前把 allowlist/`permission-mode auto` 設好以避免關鍵動作被誤拒）。因此更精確的風險不是「卡死」，而是「該做的事被靜默拒絕、若沒有妥善的失敗處理邏輯，流程可能誤以為完成」。

---

## 6. Dynamic Workflow 的觸發限制

**設計**：`/tmp/agent-flow-exp-hooks/exp6-workflow/`。

**測試 A（隱性關鍵字觸發）**：
```bash
claude -p "ultracode: write three haikus, ... to three separate files spring.txt, summer.txt, winter.txt" \
  --model claude-haiku-4-5-20251001 --output-format json --allowedTools "Workflow,Write,Agent"
```
結果：`tool_use` 事件中**完全沒有 `Workflow` 呼叫**，只出現 3 次 `Write`（`ultracode:` 這個字面字串被當一般文字忽略，模型自己選擇直接寫三次檔案，而非啟用 Workflow 腳本編排）。

**測試 B（明確指名要求呼叫 Workflow 工具）**：
```bash
claude -p "Use the Workflow tool to write and execute a script that runs three parallel Write agent() calls, ..." \
  --model claude-haiku-4-5-20251001 --output-format json --allowedTools "Workflow,Write,Agent"
```
結果：`tool_use` 事件出現 `Workflow`（+ `Skill`、`Read` 各若干次），最終回覆逐字：
> Workflow 成功執行三個平行的 agent() 調用，每個都寫了一首季節主題的五言絕句到各自的檔案 ... 三個 agent 完全平行執行，耗時約 7 秒。

事後確認 `spring.txt`／`summer.txt`／`winter.txt` 三個檔案皆確實存在且內容正確，證實是真正的平行執行結果而非幻覺回報。

**結論【證實，但需修正文件表述的精確度】**：`research/02-orchestration.md` 待實測 4 引用的文件主張「`ultracode` 關鍵字與『使用工作流程』等自然語言請求只在使用者親自輸入的 prompt 中生效，明確排除 `-p` 傳入的 prompt」——**部分證實、部分需要精確化**：**隱性的 `ultracode:` magic-keyword 捷徑觸發，實測確認在 `-p` 中不生效**（測試 A），這部分與文件一致。但**「Workflow 工具本身」在 `-p` 中並非被封鎖**——只要 prompt **明確指名**「Use the Workflow tool to ...」，`-p` 呼叫一樣能成功觸發並執行 Workflow（測試 B），且執行結果正確、真正平行。也就是說：文件說「自然語言請求跑 workflow 也被排除於 -p 之外」，實測為「至少『明確點名呼叫 Workflow 工具』這種自然語言指令在 -p 下可正常運作」，兩者有落差，以實測為準；來源比對：[Orchestrate subagents at scale with dynamic workflows](https://code.claude.com/docs/en/workflows)。**未能測出**的是文件所稱「更含蓄的自然語言」（例如不點名工具名稱、只說「幫我平行處理這些票證」）在 -p 下是否也能觸發——受限於 2 次嘗試上限未進一步測試更多種措辭。

**對 agent-flow 設計的影響**：若 agent-flow 想在 headless（`-p`）串接的 Dev phase 借助 Dynamic Workflow 的平行編排能力，**不能依賴使用者輸入含 `ultracode` 或模糊自然語言請求來自動觸發**，但**可以在 orchestrator 產生的 prompt 中明確指名「使用 Workflow 工具」**來可靠地啟用它——這對 Dev phase 用單一 headless 呼叫平行處理多張票證是可行路徑。

---

## 總結：每項一行結論

1. **SubagentStop 身分**：【證實】exit 2 後重試的是**同一個子代理（同 `agent_id`、同 context）**，hook 本身無法切換到獨立審查者，「作者／審查者分離」必須由 orchestrator 在拿到結果後另派子代理實作。
2. **Hook matcher 語法**：【證實】精確字串／`|` 多名稱清單／regex（含特殊字元自動判定）三種模式皆如 `01-plugin-mechanism.md` 記載運作，可精準只鎖定特定角色。
3. **Headless 平行 worktree**：【證實】不同 `--worktree` 名稱平行跑無衝突（各自獨立分支/鎖），但完成後鎖與目錄**不會**自動清理，且事後再跑一個普通 headless session **也不會**觸發清理，需自行管理生命週期。
4. **`isolation: worktree`**：【證實】(a) 同一 agent 每次呼叫都是全新獨立 worktree，不會重用；(b) 因此無法讓 Dev/Review 共用同一隔離環境；(c) 無變更時目錄、分支、鎖三者皆確實自動乾淨清除。
5. **無人值守權限提示**：【證實】未涵蓋的動作在 headless 下會**乾淨拒絕並讓流程繼續**，不會卡住，多個子代理同時觸發也各自獨立拒絕、不互相阻塞；風險在於「靜默失敗」而非「掛死」。
6. **Dynamic Workflow 觸發限制**：【證實＋修正】`ultracode:` 隱性關鍵字在 `-p` 下不觸發（與文件一致），但**明確指名「使用 Workflow 工具」的自然語言指令在 `-p` 下可正常運作並成功平行執行**（文件用詞過於一概而論，以實測為準）。
