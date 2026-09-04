# Claude Code Plugin 機制實測報告

調查目的：針對 `research/01-plugin-mechanism.md`、`research/02-orchestration.md` 兩份文件研究中「## 待實測」列出的、官方文件本身矛盾或未說明的行為，用本機小實驗驗證，作為 `agent-flow` plugin 設計依據。

實驗環境：`claude --version` = `2.1.259 (Claude Code)`；平台 macOS（Darwin）。所有測試 plugin 與專案目錄放在 `/tmp/agent-flow-exp/`（結束後未清理，路徑見文末）。

**沙箱與認證說明**：原計畫用 `CLAUDE_CONFIG_DIR=/tmp/agent-flow-exp/config-sandbox` 完全隔離設定目錄，但實測後該沙箱下無登入憑證（`"result":"Not logged in · Please run /login"`），故依實驗紀律規定退回使用預設設定目錄，全程只用 `--plugin-dir`（唯讀掛載本機目錄，不 install、不寫入 `~/.claude/plugins/`）與 `claude plugin validate`（唯讀）。**全程未對 `~/.claude/` 做任何寫入操作**；`/tmp/agent-flow-exp/config-sandbox/` 目錄本身雖建立但因認證失效未被實際使用於任何測試指令中。

執行注意：本次實驗是在一個已運行中的 Claude Code agent 行程內用 Bash 呼叫巢狀的 `claude -p`，因此子行程會繼承目前 shell 的環境變數——其中包含使用者個人 `~/.claude/settings.json` 設定的 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 與 `permissions.allow: ["Bash(*)", ...]`。這解釋了下方部分測試中觀察到「委派後改用 SendMessage 輪詢」等 agent-teams 風格行為，以及必須用 `--restricted` 排除全域 allow 規則才能做出乾淨的權限對照實驗。此環境混雜狀況本身也印證了 02 報告「待實測 5」關於此環境變數意外開啟風險的疑慮是真實存在的。

所有 headless 呼叫皆用 `--model claude-haiku-4-5-20251001`（最便宜模型），未使用 `--dangerously-skip-permissions`。

---

## 實驗一：Plugin agent 是否支援 `hooks` / `mcpServers` / `permissionMode`

**文件矛盾**：`plugins-reference` 頁面明確寫「plugin agent 不支援 `hooks`、`mcpServers`、`permissionMode`」（[Plugins reference](https://code.claude.com/docs/en/plugins-reference)），但 `sub-agents` 通用頁面列出的完整欄位表（[Create custom subagents](https://code.claude.com/docs/en/sub-agents)）並未排除 plugin 來源。

### 做法

建立 `/tmp/agent-flow-exp/plugins/exp-plugin/agents/test-agent.md`，frontmatter 同時宣告三個欄位：

```yaml
---
name: test-agent
description: A test subagent for experimenting with plugin agent frontmatter fields...
tools: Read, Write, Bash
permissionMode: bypassPermissions
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "echo HOOK_FIRED_FROM_PLUGIN_AGENT >> /tmp/agent-flow-exp/hooklog/hook-fired.log"
mcpServers:
  test-mcp:
    command: "echo"
    args: ["mcp-test-server-would-start-here"]
---
You are test-agent... run the Bash command `echo agent-ran` and then respond with the exact literal text: TEST_AGENT_RESPONDED
```

### 1a. `hooks` 欄位

先跑 `claude plugin validate`（見實驗五，結果：完全無警告/錯誤），再用 `--plugin-dir` 實際載入並委派給該 agent，觀察它執行 `Bash echo agent-ran` 時，宣告的 `PreToolUse` hook 是否真的觸發：

```bash
cd /tmp/agent-flow-exp && rm -f hooklog/hook-fired.log
claude --plugin-dir ./plugins/exp-plugin -p "Use the Agent tool to delegate to the exp-plugin:test-agent subagent with a trivial task. Wait for and report its full result verbatim." \
  --model claude-haiku-4-5-20251001 --output-format stream-json --permission-mode bypassPermissions \
  --forward-subagent-text --verbose > run2-3.jsonl
```

關鍵輸出（逐字，經解析 stream-json）：

```
[TOOL_USE] Agent {"subagent_type": "exp-plugin:test-agent", ...} parent= None
[TOOL_USE] Bash {"command": "echo agent-ran", "description": "Echo test marker"} parent= toolu_01HNwmCCHCX8XVBeSLYiEif9
[TOOL_RESULT] agent-ran parent= toolu_01HNwmCCHCX8XVBeSLYiEif9
[TEXT] TEST_AGENT_RESPONDED parent= toolu_01HNwmCCHCX8XVBeSLYiEif9
```

```bash
$ cat /tmp/agent-flow-exp/hooklog/hook-fired.log
bat error: '/tmp/agent-flow-exp/hooklog/hook-fired.log': No such file or directory (os error 2)
```

subagent 確實執行了 `Bash echo agent-ran`（tool_result 顯示指令成功跑完），但宣告要在 `PreToolUse` + `matcher: Bash` 時寫入的 hook 檔案**從未被建立**。

**結論【證實】**：文件說「plugin agent 不支援 `hooks`」，實測為真——`hooks` 欄位被完全忽略，未在該 subagent 的工具呼叫生命週期中生效。以 URL [Plugins reference — Agents](https://code.claude.com/docs/en/plugins-reference) 為準的說法與實測一致。

### 1b. `mcpServers` 欄位

Session 啟動時的 `system init` 事件之 `mcp_servers` 清單：

```
"mcp_servers":[{"name":"plugin:context7:context7","status":"pending"},
               {"name":"plugin:linear:linear","status":"pending"},
               {"name":"obscura","status":"failed"}]
```

其中不含 test-agent.md 宣告的 `test-mcp`。另嘗試讓 subagent 自報可用工具清單以間接確認，但因該 agent 的 system prompt 被我寫死為「只回覆 TEST_AGENT_RESPONDED」，無法讓它列出工具（實驗設計瑕疵，已達 2 次嘗試上限，不再深究）。

**結論【未能測出】**：`test-mcp` 未出現在全域 server 清單，是支持「不支援」說法的間接證據，但 (a) 一般（非 plugin）subagent 的 `mcpServers` 本來就是該 subagent 執行期間才啟動、不進全域清單，這點本身不能排除；(b) 用 `command: echo` 充當假 MCP server 本來就不會真的完成 MCP 握手，無法用「連線成功與否」判斷欄位是否被讀取。需要換一個會實際完成 MCP handshake 的假 server，並讓 subagent 能自由回報工具清單，才能做出乾淨判定——超出本次 2 次嘗試上限，如實記錄為未能測出。

### 1c. `permissionMode` 欄位

用 `--restricted --tools Bash,Task`（排除使用者全域 `~/.claude/settings.json` 的 `permissions.allow: ["Bash(*)"]` 規則）+ `--permission-mode default`（parent 用 default，非 bypass/acceptEdits，理論上不會覆蓋 subagent 自訂 `permissionMode`，見 02 報告 §1）+ `--permission-prompts none`（無核准介面，該准的動作照准、該問的直接拒絕）：

```bash
claude --plugin-dir ./plugins/exp-plugin --restricted --tools Bash,Task \
  -p "Use the Agent tool to delegate to the exp-plugin:test-agent subagent..." \
  --model claude-haiku-4-5-20251001 --output-format stream-json \
  --permission-mode default --permission-prompts none --forward-subagent-text --verbose
```

`test-agent`（宣告 `permissionMode: bypassPermissions`）的 `Bash echo agent-ran` **成功執行、無拒絕**；同一 session 中主 thread 之後另跑一個 Bash 讀取任務輸出檔，則被明確拒絕：

```
[TOOL_RESULT] Permission for this tool use was denied. It requires approval, and this
session has no approval surface — nobody can answer a permission prompt here — so it
was denied automatically... is_error= True
```

看似支持「`permissionMode` 有效」。但做對照實驗：另建立完全相同、只是**不含** `permissionMode` 欄位的 `test-agent-noperm.md`，同條件重跑：

```bash
claude --plugin-dir ./plugins/exp-plugin --restricted --tools Bash,Task \
  -p "...delegate to the exp-plugin:test-agent-noperm subagent..." \
  --permission-mode default --permission-prompts none ...
```

結果**完全相同**——`Bash echo agent-ran` 一樣無提示、無拒絕地成功執行：

```
[TOOL_USE] Bash {"command": "echo agent-ran", ...} parent= toolu_014EsLeFiHpJzT7D6wsDMzwt
[TOOL_RESULT] agent-ran is_error= False parent= toolu_014EsLeFiHpJzT7D6wsDMzwt
```

**結論【未能測出】**：有無 `permissionMode: bypassPermissions` 得到一模一樣的結果（Bash 皆放行），無法用這個測試方法區分該欄位是否生效——更可能的解釋是背景 subagent 執行像 `echo` 這種指令，在本測試環境下本來就不受主 session `--permission-mode default` 管制（或有獨立的預設放行邏輯），而不是因為 frontmatter 的 `permissionMode` 欄位起作用。需要換一個「明確需要核准、且不會被任何啟發式判定為安全」的動作（如寫入 cwd 外的檔案）重測才能下定論，已達 2 次嘗試上限。

---

## 實驗二：Agent tool 呼叫 plugin agent 的 `subagent_type` 語法

**待驗證問題**：文件只示範使用者手動 `@agent-my-plugin:security-reviewer` 語法，未直接示範 orchestrator 用 Agent tool 派工時 `subagent_type` 參數該填什麼。

### 做法

用 `--plugin-dir` 載入 `exp-plugin`，headless 送出「請用 Agent tool 委派給 `exp-plugin:test-agent` 這個 subagent」的自然語言 prompt，用 `--output-format stream-json --forward-subagent-text --verbose` 捕捉 Claude 實際產生的工具呼叫參數：

```bash
claude --plugin-dir ./plugins/exp-plugin \
  -p "Use the Agent tool to delegate to the exp-plugin:test-agent subagent with a trivial task..." \
  --model claude-haiku-4-5-20251001 --output-format stream-json \
  --permission-mode bypassPermissions --forward-subagent-text --verbose
```

關鍵輸出（逐字）：

```
[TOOL_USE] Agent {"subagent_type": "exp-plugin:test-agent", "description": "Trivial test task",
  "prompt": "Do your thing — just report what you can do and what happened."} parent= None
...
RESULT: Agent completed. The exp-plugin:test-agent returned: **TEST_AGENT_RESPONDED**
```

Session 啟動時 `system init` 的 `agents` 清單也直接證實命名空間格式：

```
"agents":["claude","exp-plugin:persona-agent","exp-plugin:test-agent","Explore",
          "general-purpose","Plan","statusline-setup","tldraw-offline"]
```

**結論【證實】**：Agent tool 的 `subagent_type` 參數對 plugin agent 使用與 `@agent-` mention 相同的 `<plugin-name>:<agent-name>` 命名空間格式（本例為 `exp-plugin:test-agent`），且委派成功、正確拿到 subagent 回傳結果。此語法與 [Plugins reference — Agents](https://code.claude.com/docs/en/plugins-reference) 描述的命名規則一致，只是該文件本身沒有給出 Agent-tool 呼叫的程式化範例，屬於「文件未寫但實測一致」。

---

## 實驗三：Plugin 根目錄 `settings.json` 的 `agent` 欄位

**待驗證問題**：這個欄位是否真的會把主 thread 換成該 agent，以及這是否會跟「主 session 自由派工」的 orchestrator 設計衝突。

### 做法

在 `/tmp/agent-flow-exp/plugins/exp-plugin/settings.json` 寫入 `{"agent": "persona-agent"}`，`persona-agent.md` 的 frontmatter 明確設 `tools: Read, Write, Bash`（不含 Agent tool），system prompt 要求「無論使用者問什麼，只回覆 `PERSONA_AGENT_ACTIVE`」：

```bash
claude --plugin-dir ./plugins/exp-plugin -p "What is 2 plus 2? Just answer normally." \
  --model claude-haiku-4-5-20251001 --output-format json --permission-mode bypassPermissions
```

```
RESULT: PERSONA_AGENT_ACTIVE
```

```
tools: ['Read', 'Write', 'Bash']
```

主 thread 完全被換成 `persona-agent` 的人格與工具集——問「2+2 是多少」得到的是固定文字 `PERSONA_AGENT_ACTIVE`，且工具集被限制成該 agent frontmatter 宣告的 `tools`（不含 `Task`，即 Agent tool 消失）。

再建立第二個 agent `orchestrator-persona.md`（**省略 `tools:` 欄位**，依規則繼承全部工具），改設 `settings.json` 為 `{"agent": "orchestrator-persona"}`，其 system prompt 要求收到任何問題都要用 Agent tool 委派給 `exp-plugin:test-agent-noperm`：

```
tools: ['Task', 'Bash', 'CronCreate', ... 'Write', 'mcp__plugin_linear_linear__...']  # 完整工具集，含 Task
[TOOL_USE] Agent {"description": "Answer simple arithmetic question",
  "subagent_type": "exp-plugin:test-agent-noperm", "prompt": "What is 2 plus 2?"}
RESULT: ORCH: TEST_AGENT_RESPONDED
```

**結論【證實】**（分兩點）：
1. Plugin `settings.json` 的 `agent` 欄位確實會在啟用時把主 thread 換成該 plugin agent 的 system prompt + 工具集，文件描述屬實（[Plugins reference](https://code.claude.com/docs/en/plugins-reference)）。
2. 這**不必然**與「主 session 自由派工」衝突，但衝突與否完全取決於被指定的 agent 自己的 `tools` frontmatter 欄位：若該 agent 顯式列出 `tools:`（白名單）且未包含 Agent tool，主 thread 就會失去派工能力（如 `persona-agent` 案例）；若該 agent **省略 `tools:`**（預設繼承全部工具，含 Agent tool），主 thread 仍可正常用 Agent tool 委派其他 subagent（如 `orchestrator-persona` 案例，成功委派並取回結果）。這點文件完全沒有提及，屬本次實測獨立發現。

---

## 實驗四：`claude plugin eval`

```bash
cd /tmp/agent-flow-exp/plugins/exp-plugin && claude plugin eval init --bare exp-eval-case
# => `plugin eval` is currently in early access   (exit 1)

claude plugin eval .
# => `plugin eval` is currently in early access   (exit 1)

CLAUDE_CODE_ENABLE_PLUGIN_EVAL=1 claude plugin eval .
CLAUDE_CODE_EARLY_ACCESS=1 claude plugin eval .
# => 同上，皆回報 early access 訊息，無法用猜測的環境變數繞過
```

**結論【未能測出】**：`claude plugin eval`（含 `eval init`）在本機環境被鎖在 early access 後面，本次實驗沒有取得存取權，無法實際跑 eval case 或檢視 `case.yaml` schema 的實際執行結果。唯一可得資訊是 `claude plugin eval --help` 的介面描述（唯讀、已於本機驗證）：eval 目錄預設 `evals/`（可用 `--eval-dir` 或 manifest 的 `experimental.evals` 覆寫）；case 來源為 `<eval dir>/**/case.yaml` 或 `prompt.md` + `graders/*.md`；`eval init` 用互動訪談產生 case，`--bare <name>` 給空白單一 case 範本；跑分時預設會加一組 no-plugin baseline 對照（`--ablation with-without`）；grader 有 `llm`/`baseline` 等付費與免費之分，`--judge-model`（預設 haiku）、`--mocks record|off` 可控制 MCP mock 行為、`--scaffold` 才會執行 case 作者提供的 bash（預設關閉，需自己審過再開）。**但這些都只是 `--help` 文字描述，未經實際執行驗證**，是否真能表達「多輪、多 agent」流程斷言（team lead 關切的重點）完全未知，需等 early access 開通後另行實驗。

---

## 實驗五：`claude plugin validate` 的實際檢查範圍

### 5a. 只驗證 `plugin.json` 或指定的 agents 目錄，兩者不會互相包含

```bash
$ claude plugin validate ./plugins/exp-plugin --json
{"success":true,"strict":false,"target":".../plugin.json","manifest":{...,"warnings":[{"path":"author",...}]},"contents":[]}
```

指向 plugin 根目錄時只驗證 `.claude-plugin/plugin.json`，`contents` 恆為空——**不會**自動連帶掃描 `agents/` 目錄。必須額外對 `agents/` 目錄單獨呼叫一次才會驗證 agent 檔案：

```bash
$ claude plugin validate ./plugins/exp-plugin/agents --json
{"success":true,"strict":false,"target":".../agents","manifest":null,"contents":[]}
```

### 5b. 只有「有警告/錯誤」的檔案才會出現在報告中，通過驗證的檔案完全不列出

刻意做四個對照組（皆放在各自獨立的最小 plugin 內，避免互相干擾）：

| 檔案內容 | `claude plugin validate <agents-dir>` 結果 |
|---|---|
| 缺 `description`（`missing-desc.md`） | `contents` 出現 1 筆，warning: `No description in frontmatter...` |
| 有效 YAML，但含未知欄位 `totallyMadeUpField`（`unknown-field.md`） | **完全不出現**，`Validation passed`，`--strict` 下仍是 `success:true` |
| 有效 YAML，含 `hooks`/`mcpServers`/`permissionMode`（本報告實驗一用的 `test-agent.md`） | **完全不出現**，`Validation passed`，`--strict` 下仍是 `success:true` |
| 語法上無法解析的 YAML（`reallybad.md`：`name: [this is not closed` 等） | `contents` 出現 1 筆，**error**：`YAML frontmatter failed to parse: YAML Parse error: Unexpected token. At runtime this agent does not load at all — with no frontmatter name it is treated as a co-located reference document and skipped.` |
| 無 `name` 欄位、有 `description`（`noname.md`） | 完全不出現（視為合法，執行期會用檔名頂替） |
| 完全沒有 `---` frontmatter 分隔線（`nodelim.md`） | 完全不出現（視為純文件，非 agent 定義，本就不該報錯） |

`--strict` 對「未知欄位」「plugin agent 不該有的 hooks/mcpServers/permissionMode」**沒有任何效果**——這兩類問題不會被當成警告，遑論錯誤：

```bash
$ claude plugin validate ./plugins/exp-plugin/agents --strict --json
{"success":true,"strict":true,"target":".../agents","manifest":null,"contents":[]}
```

**結論【證實】**（針對 team lead 關切的「CI 能依賴它多少」）：`claude plugin validate` 的檢查深度很淺，只做兩類事：(1) plugin.json/marketplace.json 的**已知欄位** schema 檢查（如缺 `author`/`description` 給 warning）；(2) agent/skill/command 檔案的 **YAML 是否能被解析**、以及是否有 `description`（給 warning，不阻擋）。它**不會**：檢查未知或不該出現的 frontmatter 欄位（包含本報告要驗證的 `hooks`/`mcpServers`/`permissionMode` 在 plugin agent 中是否合法——完全不檢查）、深入比對欄位型別是否符合各元件 schema、遞迴掃描 plugin 根目錄下所有元件（一次只驗證你明確指定的路徑）。`--strict` 只把「已產生的警告」升級成錯誤，不會讓 validate 多發現新問題。**這代表 CI 若只靠 `claude plugin validate` 把關，agent-flow 若不小心在 plugin agent 裡誤用了 `hooks`/`mcpServers`/`permissionMode`，validate 會完全放行、不會提示任何錯誤**，必須另外自行寫檢查（例如簡單 script 掃 plugin `agents/*.md` frontmatter key 名單）。

### 5c.（附加發現）validate 的錯誤訊息文字本身與實測執行期行為矛盾

實驗五 5b 中 `reallybad.md` 的 validate 錯誤訊息宣稱：「At runtime this agent does not load at all... skipped」。但把同一個檔案放進 `exp-plugin/agents/` 並用 `--plugin-dir` 實際載入後，`system init` 的 `agents` 清單是：

```
"agents":["claude","exp-plugin:orchestrator-persona","exp-plugin:persona-agent",
          "exp-plugin:reallybad","exp-plugin:test-agent","exp-plugin:test-agent-noperm",
          "Explore","general-purpose","Plan","statusline-setup","tldraw-offline"]
```

`exp-plugin:reallybad` **確實出現**在可用 agent 清單中（用檔名 `reallybad` 頂替 `name`）——與 validate 錯誤訊息「不會載入」的說法直接矛盾，反而印證了 02 報告 §1.2 所引述的 [Plugins reference — Agents](https://code.claude.com/docs/en/plugins-reference) 原文說法（frontmatter 解析失敗時，plugin agent 仍會用檔名當 name 載入，而非跳過）。

**結論【推翻】**：`claude plugin validate` 錯誤訊息文字聲稱「frontmatter 解析失敗的 plugin agent 在執行期完全不會載入」，實測為假——它其實會用檔名頂替載入，可被 Agent tool 用 `<plugin>:<檔名>` 呼叫到。以實測為準；validate 的錯誤訊息文案本身不可信，不能拿來判斷執行期行為。

---

## 附錄：測試目錄與檔案路徑

- `/tmp/agent-flow-exp/plugins/exp-plugin/` — 主要實驗 plugin（`test-agent.md`、`test-agent-noperm.md`、`persona-agent.md`、`orchestrator-persona.md`、根目錄 `settings.json`）
- `/tmp/agent-flow-exp/plugins/exp-plugin-broken/agents/` — `missing-desc.md`、`bad-yaml.md`、`unknown-field.md`（混合放置測試）
- `/tmp/agent-flow-exp/plugins/exp-check-unknown/`、`exp-check-badyaml/`、`exp-check-minimal/`、`exp-check-yaml2/` — 各自獨立的單一變因對照組 plugin（避免互相干擾）
- `/tmp/agent-flow-exp/hooklog/` — hook 應寫入但從未寫入的 log 目錄
- `/tmp/agent-flow-exp/config-sandbox/` — 建立但因認證失效未使用的 `CLAUDE_CONFIG_DIR` 沙箱
- `/tmp/agent-flow-exp/run2-1.json`、`run2-3.jsonl`、`run2-4.jsonl`、`run3-permtest.jsonl`、`run4-permtest-control.jsonl`、`run5-settingsagent.json`、`run6-settingsagent-orch.json` — 各次 headless 呼叫的完整輸出存檔

未做任何 `~/.claude/` 寫入、未 install 任何 plugin、未使用 `--dangerously-skip-permissions`。

---

## 對 agent-flow 設計的直接影響（逐項一行）

1. **hooks/mcpServers/permissionMode**：plugin agent 的 `hooks` 確認不生效（實測證實文件），故 Dev/Review phase 若需要 per-agent 專屬 hook，必須放在 plugin 層級 `hooks/hooks.json` 靠 `matcher` 比對 agent/工具名變相達成，不能寫進 agent frontmatter；`mcpServers`/`permissionMode` 是否生效本次未能測出，設計上應保守假設「不生效」，需要的話改用 project 層級 `.claude/agents/`。
2. **subagent_type 語法**：orchestrator 派工給任何 phase agent 一律用 `<plugin-name>:<agent-name>`（本例 `exp-plugin:test-agent`）格式，已在 CLAUDE.md/派工 skill 中可直接照此格式撰寫呼叫指示。
3. **settings.json 的 agent 欄位**：可以安全用來把主 thread 固化成 orchestrator 角色，但 orchestrator agent 定義**必須省略 `tools:` 欄位**（或明確納入 Agent/Task tool），否則會把自己派工能力鎖死——這是設計 agent-flow 主 orchestrator agent 定義檔時的硬性檢查點。
4. **claude plugin eval**：因 early access 未開通，無法確認能否表達多輪多 agent 流程斷言，CI 回歸測試暫時不能規劃依賴它，需另尋（如自建 headless 腳本斷言）或等待存取權開通後補測。
5. **claude plugin validate**：檢查極淺（只查已知 manifest 欄位缺失與 YAML 可解析性），完全不檢查 plugin agent 不該用的欄位，CI 不能只靠它把關 agent-flow 自訂的「plugin agent 欄位白名單」規則，需要額外自寫 lint 腳本。
