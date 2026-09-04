# Claude Code Plugin 元件機制調查報告

調查目的：作為 `agent-flow` plugin（結合 SDD/TDD 八 phase 工作流程，以主 session 作 orchestrator、派工給子 agent）的設計依據。

調查方法：以官方文件（`code.claude.com/docs/en/*`）為主要來源，逐頁 WebFetch 全文；輔以本機唯讀指令 `claude --help`、`claude plugin --help`、`claude plugin validate --help` 等驗證 CLI 介面（未安裝、未寫入 `~/.claude/`）。所有主張皆標明來源；文件未記載的行為在文末「## 待實測」列出，不腦補。

驗證環境：`claude --version` 對應之 CLI（2026-09 當下版本；文件中多處標註功能引入版本如 v2.1.xxx，代表功能可能不存在於較舊版本）。

---

## 1. plugin.json 與 marketplace.json 的 schema

### 1.1 plugin.json

位置：`<plugin-root>/.claude-plugin/plugin.json`。此 manifest **是選填的**：若省略，Claude Code 會自動探索預設位置的元件，並以目錄名稱作為 plugin 名稱；只有在需要提供 metadata 或自訂元件路徑時才需要它。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

唯一必填欄位：`name`（kebab-case，不可含空白或控制字元）。
來源：同上；quickstart 範例亦確認最小可行的 manifest 只需 `name`、`description`、`version`、`author`（[Create plugins](https://code.claude.com/docs/en/plugins)）。

完整欄位表（依官方 reference 頁面整理）：

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `name` | string | 是 | 唯一 kebab-case 識別碼 |
| `displayName` | string | 否 | 人類可讀名稱，預設回退為 `name` |
| `version` | string | 否 | Semver；設定後會把 plugin 釘在該版本（見 §7 版本管理） |
| `description` | string | 否 | 簡介 |
| `author` | object | 否 | `{name, email, url}` |
| `homepage` | string | 否 | 文件 URL |
| `repository` | string | 否 | 原始碼 URL |
| `license` | string | 否 | 授權識別碼（如 `MIT`） |
| `keywords` | array | 否 | 探索用標籤 |
| `metadata` | object | 否 | 自由格式資料，**不影響行為** |
| `defaultEnabled` | boolean | 否 | 安裝後是否預設啟用（預設 `true`） |
| `skills` | string\|array | 否 | 額外 skill 目錄（**疊加**於預設 `skills/`，見 §2 path behavior） |
| `commands` | string\|array | 否 | 扁平 `.md` skill 檔案（**取代**預設 `commands/`） |
| `agents` | string\|array | 否 | Agent 檔案路徑（**取代**預設 `agents/`） |
| `workflows` | string\|array | 否 | Workflow script 檔案（**取代**預設 `workflows/`） |
| `hooks` | string\|array\|object | 否 | Hook 設定檔路徑或內嵌設定 |
| `mcpServers` | string\|array\|object | 否 | MCP 設定檔路徑或內嵌設定 |
| `outputStyles` | string\|array | 否 | Output style 檔案（**取代**預設 `output-styles/`） |
| `lspServers` | string\|array\|object | 否 | LSP server 設定 |
| `experimental.themes` | string\|array | 否 | 色彩主題檔案（**取代**預設 `themes/`） |
| `experimental.monitors` | string\|array | 否 | Monitor 設定 |
| `userConfig` | object | 否 | 啟用時可設定的使用者參數（見 §1.3） |
| `channels` | array | 否 | 訊息頻道宣告，綁定至 MCP server（見 §1.4） |
| `dependencies` | array | 否 | 相依的其他 plugin，可帶 semver 版本範圍（見 §7.3） |
| `settings.json`（plugin 根目錄檔案，非 `plugin.json` 欄位） | — | 否 | 啟用 plugin 時套用的預設 settings，目前只支援 `agent` 與 `subagentStatusLine` 兩個 key |

來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)、[Create plugins](https://code.claude.com/docs/en/plugins)

**重要結構警告（官方文件明確標註為常見錯誤）**：`commands/`、`agents/`、`skills/`、`hooks/` 等目錄**不可**放在 `.claude-plugin/` 裡面；只有 `plugin.json` 屬於 `.claude-plugin/`，其餘目錄一律位於 plugin 根目錄。Plugin 根目錄是傳給 `--plugin-dir` 或含有 `.claude-plugin/plugin.json` 的那個目錄，**絕不是** `~/.claude/`。
來源：[Create plugins](https://code.claude.com/docs/en/plugins)

未知欄位在執行期會被忽略，`claude plugin validate` 會回報警告，加 `--strict` 則視警告為錯誤（利於跨生態系 manifest，如同時相容 VS Code/npm）。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)（本機 `claude plugin validate --help` 已驗證 `--strict` 旗標存在）

### 1.2 標準目錄結構

```
enterprise-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── <name>/SKILL.md
├── commands/            # 扁平 .md skill（舊式；新專案建議用 skills/）
├── agents/
│   └── *.md
├── workflows/
├── output-styles/
├── themes/
├── monitors/
│   └── monitors.json
├── hooks/
│   └── hooks.json
├── bin/                 # 加入 Bash tool 的 PATH
├── .mcp.json
├── .lsp.json
├── scripts/
├── settings.json         # plugin 啟用時的預設 settings（僅 agent、subagentStatusLine）
├── package.json
├── LICENSE
└── CHANGELOG.md
```

若 plugin 只有一個 skill，可以把 `SKILL.md` 直接放在 plugin 根目錄（不建 `skills/`），此時用 frontmatter 的 `name` 作為呼叫名稱；會成長為多個 skill 的 plugin 建議用 `skills/` 佈局。
來源：[Create plugins](https://code.claude.com/docs/en/plugins)

### 1.3 userConfig（使用者可設定參數）

```json
{
  "userConfig": {
    "api_token": {
      "type": "string",
      "title": "API token",
      "description": "API authentication token",
      "sensitive": true
    }
  }
}
```

| 欄位 | 必填 | 說明 |
|---|---|---|
| `type` | 是 | `string`、`number`、`boolean`、`directory`、`file` |
| `title` | 是 | 設定對話框顯示的標籤 |
| `description` | 是 | 說明文字 |
| `sensitive` | 否 | `true` 則遮蔽輸入並用安全儲存 |
| `required` | 否 | 空值時驗證失敗 |
| `default` | 否 | 預設值 |
| `multiple` | 否 | 對 `string` 型別允許陣列 |
| `min`/`max` | 否 | `number` 型別的上下界 |

取用方式：在 MCP/LSP 設定與 hook 指令中以 `${user_config.KEY}` 取用；匯出給 hook process 時為環境變數 `CLAUDE_PLUGIN_OPTION_<KEY>`；儲存在使用者 `settings.json` 的 `pluginConfigs[<plugin-id>].options`；敏感值存於系統 keychain 或 `~/.claude/.credentials.json`。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

安裝時可透過 CLI 帶入：`claude plugin install <plugin> --config key=value`（可重複帶多個 `--config`），本機 `claude plugin install --help` 已驗證此旗標。

### 1.4 marketplace.json

位置：`<marketplace-root>/.claude-plugin/marketplace.json`（**必須**在 repo 根目錄下的這個相對路徑）。
來源：[Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces)

必填欄位：

```json
{
  "name": "marketplace-identifier",
  "owner": { "name": "Owner Name" },
  "plugins": [
    { "name": "plugin-name", "source": "./plugins/plugin-name" }
  ]
}
```

| 欄位 | 型別 | 說明 |
|---|---|---|
| `name` | string | Marketplace 識別碼，kebab-case，公開可見，須唯一（每使用者） |
| `owner` | object | `{name}` 必填，`email`、`url` 選填 |
| `plugins` | array | 每項至少含 `name`、`source` |
| `$schema`（選填） | string | 編輯器驗證用的 JSON Schema URL |
| `description`（選填） | string | 簡介 |
| `version`（選填） | string | Marketplace manifest 版本 |
| `metadata.pluginRoot`（選填，v2.1.239+） | string | 讓 `source` 可用不含 `./` 的裸名稱 |
| `allowCrossMarketplaceDependenciesOn`（選填） | array | 允許此 marketplace 內 plugin 相依的其他 marketplace |
| `renames`（選填） | object | 舊名稱 → 新名稱（或 `null` 代表移除）的對照表，屬 append-only 歷史紀錄 |

**Plugin 條目**內，除 `name`、`source` 必填外，其餘欄位（`displayName`、`description`、`version`、`author`、`homepage`、`repository`、`license`、`keywords`、`skills`、`commands`、`agents`、`hooks`、`mcpServers`、`lspServers`、`category`、`tags`、`headers`/`headersHelper`）都是選填，且與 `plugin.json` schema 共用同一組欄位定義，另外多了 marketplace 專屬欄位：

- `strict`（預設 `true`）：`true` 時 `plugin.json` 是元件定義的權威來源，marketplace 條目只是補充；`false` 時 marketplace 條目本身就是完整定義，若此時 plugin 自己的 `plugin.json` 又宣告元件會產生衝突。
- `defaultEnabled`（預設 `true`）：安裝後是否預設啟用。

來源：[Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)

**Source 型別**（`source` 可為字串相對路徑，或物件）：

| source 型別 | 範例欄位 |
|---|---|
| 相對路徑 | `"./plugins/my-plugin"`（相對於 marketplace 根目錄，須以 `./` 開頭，不可用 `../` 逃逸；`metadata.pluginRoot` 設定後可用裸名稱） |
| `github` | `{source:"github", repo:"owner/repo", ref?, sha?}` |
| `url`（git） | `{source:"url", url, ref?, sha?}` |
| `git-subdir` | `{source:"git-subdir", url, path, ref?, sha?}` |
| `npm` | `{source:"npm", package, version?, registry?}` |
| `archive`（zip） | `{source:"archive", url, sha256?}`（僅 HTTPS，上限 256 MiB） |
| `command` | `{source:"command", command, timeout?, mode?}`（指令印出 plugin 目錄路徑到 stdout 並 exit 0；`mode:"link"` 讓大型 plugin 留在原地不複製，Windows 不支援） |

來源：[Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)

**保留 marketplace 名稱**（禁止第三方使用，避免冒充官方來源）：`claude-code-marketplace`、`claude-code-plugins`、`claude-plugins-official`、`claude-plugins-community`、`anthropic-marketplace`、`anthropic-plugins`、`agent-skills`、`anthropic-agent-skills`、`knowledge-work-plugins`、`life-sciences`、`claude-for-legal`、`claude-for-financial-services`、`financial-services-plugins`、`first-party-plugins`、`healthcare`，以及任何冒充官方（如 `official-claude-plugins`）的名稱。Claude Code 每次載入 marketplace 都會檢查，不只在新增時；若某個 marketplace 是在名稱被保留之前註冊的，會停止載入並回報「registered from an untrusted source」，需移除後從官方來源重新加入。
來源：[Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)（第一手研究時的搜尋摘要有提及，已用官方頁面全文確認欄位存在，但保留清單本身文字取自搜尋摘要整合官方頁 fetch 結果——見「待實測」關於此清單是否完整的註記）

### 1.5 版本管理（version management）

版本解析順序（第一個命中者勝出）：
1. Marketplace 條目中明確的 `version`
2. `plugin.json` 中明確的 `version`
3. Git 來源：解析後的 commit SHA
4. Archive 來源：SHA-256 digest
5. 依來源型別的下一個判斷依據

規則：設定 `version` 後，使用者只有在該值變動時才會收到更新；git 來源若省略 `version`，會在新 commit 出現時自動更新；**不要**同時在 `plugin.json` 與 marketplace 條目設定 `version`；每次推送新 commit 應同步調高版本號。
來源：[Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)

---

## 2. Plugin 可內含的元件

### 2.1 元件總覽（含目錄與檔案格式）

| 元件 | 預設位置 | 格式 | plugin.json 覆寫欄位行為 |
|---|---|---|---|
| Skills | `skills/<name>/SKILL.md` | Markdown + YAML frontmatter | `skills` 欄位是**疊加**（scan 預設 + manifest 路徑），但 marketplace root source 例外（取代） |
| Commands（舊式扁平 skill） | `commands/*.md` | Markdown + YAML frontmatter | `commands` 欄位**取代**預設 |
| Agents | `agents/*.md` | Markdown + YAML frontmatter | `agents` 欄位**取代**預設 |
| Workflows | `workflows/*.js` | Script | `workflows` 欄位**取代**預設 |
| Hooks | `hooks/hooks.json` | JSON | `hooks` 欄位**合併**所有來源 |
| MCP servers | `.mcp.json` | JSON | `mcpServers` 欄位**合併**所有來源 |
| LSP servers | `.lsp.json` | JSON | `lspServers` 欄位**合併**所有來源 |
| Output styles | `output-styles/*.md` | Markdown | `outputStyles` 欄位**取代**預設 |
| Themes | `themes/*.json` | JSON | `experimental.themes` **取代**預設 |
| Monitors | `monitors/monitors.json` | JSON | `experimental.monitors` **取代**預設 |
| Executables | `bin/` | 任意執行檔 | 加入 Bash tool 的 `PATH`；**不可**用於透過 claude.ai organization settings 發佈的 plugin |

來源：[Plugins reference — Path Behavior Rules](https://code.claude.com/docs/en/plugins-reference)、[Create plugins](https://code.claude.com/docs/en/plugins)

路徑規則：manifest 中的路徑必須相對於 plugin 根目錄、須以 `./` 開頭（`skills` 例外可用 `.`）、可為陣列（多路徑）、不可用 `../..` 逃逸出 plugin 目錄。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

### 2.2 Skills（SKILL.md）—— 完整 frontmatter 欄位

Skill 是 Claude Code 對 [Agent Skills 開放標準](https://agentskills.io) 的實作延伸；plugin 內的 skill 支援官方文件表列的**所有**欄位（若要讓 skill 也能在 claude.ai 上傳、Skills API、`package_skill.py` 打包等**非 Claude Code** 通路使用，則只能用標準六欄位：`name`、`description`、`license`、`compatibility`、`metadata`、`allowed-tools`，多用其他欄位會直接 hard error）。
來源：[Skills](https://code.claude.com/docs/en/skills)

完整欄位表（官方頁面逐字轉錄，全部為選填，只有 `description` 屬「建議」）：

| 欄位 | 說明 |
|---|---|
| `name` | 顯示名稱，預設為目錄名稱；對 plugin skill 而言，此欄位會取代呼叫指令的最後一段（見 §3） |
| `description` | Claude 判斷何時使用此 skill 的依據；若省略，取 markdown 第一段。`description` + `when_to_use` 合計於 skill listing 中截斷至 1536 字元 |
| `when_to_use` | 額外觸發條件說明（例句、觸發詞），附加在 `description` 之後，同計入 1536 字元上限 |
| `argument-hint` | Autocomplete 時顯示的參數提示，例如 `[issue-number]` |
| `arguments` | 具名位置參數列表，供 `$name` 替換使用；接受空白分隔字串或 YAML list |
| `disable-model-invocation` | `true` 時只有使用者能呼叫（`/name`），Claude 不會自動觸發；也會使該 skill不被 preload 進 subagent、不會被 scheduled task 以此 skill 為 prompt 時觸發。預設 `false` |
| `user-invocable` | `false` 時只有 Claude 能呼叫，`/` 選單隱藏、打 `/name` 不執行。預設 `true` |
| `allowed-tools` | 呼叫該 skill 的**當下這一輪**內，列出的工具無需詢問權限即可用；下一則使用者訊息送出後授權即清除；不限制其餘工具的可用性，只是預先核准列出的工具 |
| `disallowed-tools` | 該 skill 生效期間，從 Claude 可用工具池中移除列出的工具；同樣在下一則訊息後清除 |
| `model` | 該 skill 生效期間使用的模型；只在當輪有效，不寫入 settings；接受與 `/model` 相同的值，或 `inherit`；搭配 `context: fork` 則設定的是被 fork 出的 subagent 的模型 |
| `effort` | 該 skill 生效期間的 effort level；預設繼承 session；選項 `low`/`medium`/`high`/`xhigh`/`max` |
| `context` | 設為 `fork` 時，skill 在被 fork 出的 subagent 情境中執行（見 §2.2.1） |
| `agent` | `context: fork` 時使用哪個 subagent 型別 |
| `background` | 僅 `context: fork` 適用；設為 `false` 時在呼叫該輪內等待 forked subagent 結果，而非背景執行；預設 `true`（需 v2.1.218+） |
| `hooks` | 呼叫此 skill 時註冊的 hook，並於本次 session 剩餘時間持續生效 |
| `paths` | Glob pattern，限制此 skill 只在符合特定檔案時才自動觸發 |
| `shell` | `` !`command` `` 注入指令使用的 shell，`bash`（預設）或 `powershell` |
| `metadata` | 自由格式 YAML map，供自訂工具讀取，Claude Code 本身不處理其內容 |
| `license` | Agent Skills 標準欄位，Claude Code 接受但不作用 |
| `compatibility` | Agent Skills 標準欄位（字串，上限 500 字元），Claude Code 接受但不作用 |

來源：[Skills — Frontmatter reference](https://code.claude.com/docs/en/skills)

**布林欄位解析**：接受 `yes`、`no`、`on`、`off`、`1`、`0`（任意大小寫）以及 `true`/`false`；v2.1.218 之前只認 `true`/`false`。
**Frontmatter 判讀條件**：只有當檔案第一行就是 `---` 才會被解析為 frontmatter，否則整個檔案（含 `---` 記號）都被當成 skill 內容。
來源：同上

#### 2.2.1 Skill 於 subagent 中執行（`context: fork`）

`context: fork` 讓 skill 內容變成驅動一個 subagent 的 prompt，該 subagent 無法存取當前對話歷史。預設在**背景**執行（你可以繼續操作，結果完成後才回到對話中）；設 `background: false` 則改為在呼叫當輪等待結果（v2.1.218 之前一律阻塞式等待）。以下情況即使沒設 `background: false` 也會等待：非互動模式（`-p` 或 Agent SDK）、`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`、同一 skill 前一次呼叫尚未完成、由 scheduled task 觸發時。

背景執行的 forked skill 適用「背景 subagent 較窄的工具集」（見 §4 subagent 章節），且其編輯不受 checkpoint（`/rewind`）保護，需用 git 回退。

Skill 與 subagent 的兩種組合方式對照：

| 方式 | System prompt 來源 | Task | 額外載入 |
|---|---|---|---|
| Skill + `context: fork` | 來自 agent 型別 | SKILL.md 內容 | CLAUDE.md（Explore/Plan 除外） |
| Subagent + `skills` 欄位 | Subagent 的 markdown body | Claude 的委派訊息 | Preloaded skills + CLAUDE.md |

`agent` 欄位可指定內建型別（`Explore`、`Plan`、`general-purpose`）或任何自訂 subagent；省略時預設 `general-purpose`。
來源：[Skills — Run skills in a subagent](https://code.claude.com/docs/en/skills)

#### 2.2.2 參數傳遞（字串替換）

| 變數 | 說明 |
|---|---|
| `$ARGUMENTS` | 呼叫時傳入的完整參數字串；若沒有任何 placeholder 接收到參數，Claude Code 會自動在 skill 內容末尾附加 `ARGUMENTS: <value>` |
| `$ARGUMENTS[N]` | 依 0-based 索引取得特定參數 |
| `$N` | `$ARGUMENTS[N]` 的簡寫 |
| `$name` | 對應 `arguments` frontmatter 宣告的具名參數（依宣告順序對應位置） |
| `${CLAUDE_SESSION_ID}` | 目前 session ID |
| `${CLAUDE_EFFORT}` | 目前 effort level |
| `${CLAUDE_SKILL_DIR}` | 該 skill 的 SKILL.md 所在目錄（plugin skill 則是 plugin 內的子目錄，非 plugin 根目錄） |
| `${CLAUDE_PROJECT_DIR}` | 專案根目錄，與 hooks/MCP 收到的同名環境變數一致 |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin 安裝目錄，僅在 plugin skill 中替換 |
| `${CLAUDE_PLUGIN_DATA}` | Plugin 持久化資料目錄，僅在 plugin skill 中替換 |

`${CLAUDE_SKILL_DIR}`、`${CLAUDE_PLUGIN_ROOT}` 等變數在 skill 的 markdown 內容**與** `allowed-tools` 的 Bash 規則中都會被替換，因此可以讓「skill 指示執行的腳本」與「allowed-tools 授權的腳本」用同一變數精準對應、不觸發權限提示。

參數使用 shell 風格引號解析（多字詞需加引號成單一參數）；`$ARGUMENTS` 永遠展開為完整原始輸入；未對應到參數的索引 placeholder（如只傳一個參數卻寫 `$2`）保留原字面文字；未對應到參數的具名 placeholder 則展開為空字串。若參數值本身包含 `$1` 或 `$ARGUMENTS` 這類文字，Claude Code 會將其當作字面文字插入、不再展開；`\$1.00` 這種以反斜線跳脫可強制輸出字面 `$`。

可在一則訊息開頭堆疊多個 skill（如 `/write-tests /fix-issue 123`），尾端文字會作為 `$ARGUMENTS` 傳給每個被展開的 skill；最多展開第一個加上其後五個（共六個），遇到非「inline user-invocable」的 skill（如本身是 forked subagent 的 skill，或參數可能以 `/` 開頭的 skill）即停止展開。
來源：[Skills — Available string substitutions / Pass arguments to skills](https://code.claude.com/docs/en/skills)

#### 2.2.3 動態情境注入（`!` command injection）

`` !`<command>` `` 語法會在 skill 內容送給 Claude **之前**先在本機執行 shell 指令，並用輸出取代該 placeholder（只替換一次，不會對指令輸出再次掃描 placeholder）。`!` 必須出現在行首或緊接空白之後才會被辨識；多行指令改用 ` ```! ` fenced code block。

指令失敗（非零 exit code，且不在 `search/comparison` 白名單豁免範圍內）會導致**整個 skill 呼叫中止**，Claude 完全不會看到該次呼叫的 skill 內容；權限檢查非 allow 時（含原本會詢問使用者的規則）也會直接中止（注入指令從不觸發互動式權限提示）。可用 `allowed-tools` 預先核准以避免中止。

可用 `disableSkillShellExecution: true` settings 全域關閉此行為（bundled/managed skill 不受影響）；此設定對「從 claude.ai 帳號同步的 skill」永遠強制關閉。
來源：[Skills — Inject dynamic context](https://code.claude.com/docs/en/skills)

#### 2.2.4 Skill 內容生命週期與 auto-compaction

Skill 內容一旦被載入對話，就會以單一訊息形式留在上下文中，**跨後續輪次持續存在**（但 `allowed-tools` 授權只在當輪有效）。Claude Code 不會在後續輪次重新讀取 skill 檔案，因此 skill 指示應寫成「持續適用的標準指示」而非「一次性步驟」。重複呼叫內容相同的 skill 時，Claude Code 只加一句「已載入」的提示，不會重複貼整份內容；內容不同（如參數變了或動態注入產生新輸出）才會再次附加完整內容。

Auto-compaction（上下文壓縮）時，Claude Code 會在摘要後重新附加「最近一次呼叫」的每個 skill，每個 skill 保留前 5000 tokens，所有重新附加的 skill 共享 25000 tokens 預算，由最近呼叫者優先填入；較舊的 skill 可能在壓縮後被完全捨棄。
來源：[Skills — Skill content lifecycle](https://code.claude.com/docs/en/skills)

### 2.3 Agents（子代理定義）

位置：`agents/*.md`（plugin 內）。格式：YAML frontmatter + markdown system prompt。
來源：[Create custom subagents](https://code.claude.com/docs/en/sub-agents)、[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

完整 frontmatter 欄位表（官方 `sub-agents` 頁面）：

| 欄位 | 必填 | 說明 |
|---|---|---|
| `name` | 是 | 唯一識別碼，小寫+連字號，不可含冒號 |
| `description` | 是 | Claude 判斷何時委派給此 subagent 的依據 |
| `tools` | 否 | 工具白名單；省略則繼承全部工具 |
| `disallowedTools` | 否 | 工具黑名單，從繼承集合中移除 |
| `model` | 否 | `sonnet`、`opus`、`haiku`、`fable`、完整 model ID，或 `inherit` |
| `permissionMode` | 否 | `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan` |
| `maxTurns` | 否 | 最大 agentic turn 數，超過則標記為 partial |
| `skills` | 否 | 啟動時預先載入（preload）進 context 的 skill 清單 |
| `memory` | 否 | `user`/`project`/`local`，啟用跨 session 持久記憶 |
| `background` | 否 | `true` 時即使 Claude 要求前景執行，仍強制留在背景 |
| `isolation` | 否 | 僅 `"worktree"` 一個合法值，於獨立 git worktree 中執行 |
| `color` | 否 | 顯示顏色 |
| `effort` | 否 | Effort 覆寫 |
| `mcpServers` | 否 | 僅此 subagent 可用的 MCP server |
| `hooks` | 否 | 僅此 subagent 執行期間生效的 hook |
| `initialPrompt` | 否 | 當此 agent 作為主 session 執行時自動送出的第一輪訊息 |
| `experimental.cacheTtl` | 否 | Prompt cache TTL，如 `5m`/`1h` |

**Plugin 內 agents 的安全限制**：官方 plugins-reference 頁面特別註明，plugin agent frontmatter **不支援** `hooks`、`mcpServers`、`permissionMode`（與 sub-agents 頁面所列一般 subagent 支援的欄位有落差——即這三個欄位在一般 `.claude/agents/` 中可用，但在 **plugin** 提供的 agent 中被限制/不支援）。
來源：[Plugins reference — Agents](https://code.claude.com/docs/en/plugins-reference)（此差異點在後面「待實測」再次強調，因兩份文件描述不完全一致）

**命名**：Plugin agent 呼叫時以 `my-plugin:agent-name` 命名空間呈現；若檔案沒有 `name`，以檔名作為預設。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

**Scope 優先順序**（由高到低）：
1. Managed settings（組織強制部署）
2. `--agents` CLI flag（僅該 session）
3. `.claude/agents/`（專案，可入版控）
4. `~/.claude/agents/`（個人，跨專案）
5. Plugin `agents/` 目錄（最低優先，命名空間為 `my-plugin:agent-name`）

目錄遞迴掃描；同一 scope 內名稱須唯一（子資料夾不建立命名空間）；缺少 `name` 或 `description` frontmatter 的檔案會被跳過；巢狀專案目錄以最接近者為準。
來源：[Create custom subagents](https://code.claude.com/docs/en/sub-agents)

**內建 subagent**：`Explore`（唯讀，快速搜尋，繼承主對話模型並在 Claude API 上限制為 Opus）、`Plan`（唯讀，plan mode 研究用）、`general-purpose`（完整工具集，複雜多步驟任務）、`claude`（catch-all，所有工具）、`statusline-setup`、`claude-code-guide`。可用 `permissions.deny: ["Agent(Explore)", ...]` 或環境變數 `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1` 停用。
來源：[Create custom subagents](https://code.claude.com/docs/en/sub-agents)

**呼叫方式**：自動委派（依 `description` 判斷，加「use proactively」可提高委派機率）、自然語言指名、`@agent-<name>` mention（plugin agent 用 `@agent-my-plugin:security-reviewer`）、作為整個 session 的預設（`--agent <name>` CLI 或 settings.json 的 `"agent"` 欄位）。
來源：[Create custom subagents](https://code.claude.com/docs/en/sub-agents)

**前景 vs 背景**：前景會阻塞主對話、權限提示直接問你、擁有完整工具集；背景可並行、權限提示浮現在主 session、工具集較窄（背景 subagent 只有：`Read, Grep, Glob, Bash, PowerShell, Edit, Write, NotebookEdit, WebFetch, WebSearch, TodoWrite, Skill, ToolSearch, EnterWorktree, ExitWorktree, Monitor, TaskStop, SendMessage` + MCP 工具 + 有條件的 `Agent`/`ExitPlanMode`）。預設行為：互動模式（fork mode 開）預設背景；非互動模式預設前景（除非設 `background: true`）。
來源：[Create custom subagents](https://code.claude.com/docs/en/sub-agents)

**巢狀與併發限制**：subagent 預設可再往下 spawn 最多 3 層（`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`，設 `1` 可完全停用巢狀）；預設最多同時執行 20 個 subagent（`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`）。
來源：同上

**初始上下文**（非 fork 的 subagent 啟動時得到）：agent 自身 system prompt、Claude 傳來的 task 訊息、所有層級的 CLAUDE.md（Explore/Plan 跳過）、git status 快照（Explore/Plan 跳過）、`skills` 欄位 preload 的 skill 完整內容、可供 `SendMessage` 使用的同儕名單。**不包含**：對話歷史、output style、auto memory、主對話的 context。Fork 模式例外：繼承 parent 對話的一切。
來源：同上

### 2.4 Hooks

Plugin 內宣告位置：`hooks/hooks.json`，或內嵌於 `plugin.json` 的 `hooks` 欄位。
Plugin hook 會與使用者、專案層級的 hook **合併**生效（非取代）。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)、[Hooks reference](https://code.claude.com/docs/en/hooks)

範例：

```json
{
  "description": "Automatic code formatting",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh",
            "args": [],
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**完整事件清單**（依觸發頻率分類）：

- 每個 session 一次：`SessionStart`、`SessionEnd`、`Setup`（限 `--init-only`/`--init`/`--maintenance` 於 `-p` 模式）
- 每個 turn 一次：`UserPromptSubmit`、`Stop`、`StopFailure`
- Agentic loop 每次工具呼叫：`PreToolUse`、`PostToolUse`、`PostToolUseFailure`、`PostToolBatch`、`PermissionRequest`、`PermissionDenied`
- 其他：`UserPromptExpansion`、`Notification`、`MessageDisplay`、`SubagentStart`、`SubagentStop`、`TaskCreated`、`TaskCompleted`、`TeammateIdle`、`InstructionsLoaded`、`ConfigChange`、`CwdChanged`、`DirectoryAdded`、`FileChanged`、`WorktreeCreate`、`WorktreeRemove`、`PreCompact`、`PostCompact`、`PreModelSwitch`、`PostModelSwitch`、`Elicitation`、`ElicitationResult`

來源：[Hooks reference](https://code.claude.com/docs/en/hooks)

**Hook handler 型別**（`type` 欄位）：

| 型別 | 必填欄位 | 說明 |
|---|---|---|
| `command` | `command` | Shell 指令；`args` 存在時為 exec form（不經 shell 解析），不存在時為 shell form（支援 pipe、`&&`、glob） |
| `http` | `url` | POST event JSON 到指定端點；`headers`、`allowedEnvVars` 選填 |
| `mcp_tool` | `server`、`tool` | 呼叫 MCP server 上的工具；`input` 支援 `${path}` 從 hook JSON input 取值 |
| `prompt` | `prompt` | 以 LLM 評估 prompt；`$ARGUMENTS` 為 hook input JSON；`model` 選填（預設用快速模型） |
| `agent` | `prompt` | 啟動可用工具的 subagent 驗證器再回傳決策 |

共通欄位：`if`（permission rule 語法過濾，如 `"Bash(git *)"`）、`timeout`（預設：command/http/mcp_tool 為 600 秒、prompt 30 秒、agent 60 秒）、`statusMessage`、`once`（僅 skill frontmatter 適用，成功執行一次後移除）。
來源：[Hooks reference](https://code.claude.com/docs/en/hooks)

**Matcher 規則**：`"*"`/空字串/省略 = 全部匹配；純字母數字/`_`/`-`/空白/`,`/`|` = 精確字串或列表（如 `Bash`、`Edit|Write`）；含其他字元 = 視為 JavaScript regex（unanchored）。不同事件的 matcher 比對對象不同（工具事件比對工具名；`SessionStart` 比對啟動方式；`Notification` 比對通知型別等，詳見官方頁面表格）。MCP 工具遵循 `mcp__<server>__<tool>` 命名；**plugin 內建的 MCP server** 使用有 scope 的名稱：`mcp__plugin_<plugin-name>_<server-name>__<tool>`。
來源：同上

**輸出/決策格式**：Command/HTTP hook 在 stdout 回傳 JSON（`hookSpecificOutput.permissionDecision` 為 `allow`/`deny`/`default`，另有 `additionalContext`、`updatedInput`、`systemMessage`、`terminalSequence` 等）。Exit code 0 = 成功、依 JSON 決策；exit code 2 = 阻擋動作（永遠覆蓋 JSON 輸出）；其他 code 視事件而定。
來源：同上

**安全性**：hook 以完整使用者權限執行，**無沙盒**；企業可用 `allowManagedHooksOnly` 限制只能用組織核准的 hook；HTTP/MCP hook 受 allowlist 控制（`allowedHttpHookUrls`、`httpHookAllowedEnvVars`）。
來源：同上

### 2.5 MCP Servers

位置：`.mcp.json`，或內嵌於 `plugin.json` 的 `mcpServers` 欄位。啟用 plugin 時自動啟動，以標準 MCP 工具形式出現，命名為 `mcp__plugin_<plugin-name>_<server-name>__<tool>`。

```json
{
  "mcpServers": {
    "plugin-database": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": { "DB_PATH": "${CLAUDE_PLUGIN_DATA}" }
    }
  }
}
```

`${CLAUDE_PLUGIN_ROOT}`、`${CLAUDE_PLUGIN_DATA}`、`${CLAUDE_PROJECT_DIR}` 於 stdio server 的 `command`/`args`/`env`，以及 http/sse/ws server 的 `url`/`headers`/`headersHelper` 中皆可替換。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

### 2.6 其他元件（LSP servers / Monitors / Themes / Channels）

- **LSP servers**（`.lsp.json`）：必填 `command`、`extensionToLanguage`；選填 `args`、`transport`（`stdio`/`socket`）、`env`、`initializationOptions`、`settings`、`workspaceFolder`、`startupTimeout`、`shutdownTimeout`、`restartOnCrash`（預設 `true`）、`maxRestarts`、`diagnostics`（預設 `true`）。官方建議常見語言直接裝官方 LSP plugin，只有語言未被涵蓋時才自建。**雲端 session 不會啟動 plugin 的 LSP server**。
- **Monitors**（`monitors/monitors.json`）：必填 `name`、`command`（背景常駐 process）、`description`；選填 `when`（`"always"` 預設，或 `"on-skill-invoke:<skill-name>"`）。啟用時自動啟動，stdout 每一行都會作為通知送給 Claude。
- **Themes**（`themes/*.json`）：`{name, base, overrides:{...}}`。
- **Channels**：`server` 欄位必填，需對應到某個 MCP server key；可選 per-channel `userConfig`。

來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)、[Create plugins](https://code.claude.com/docs/en/plugins)

### 2.7 環境變數（路徑替換）

| 變數 | 解析為 | 適用範圍 |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Plugin 安裝目錄 | skill/agent 內容、hook/monitor 指令、MCP stdio 的 command/args/env、MCP http/sse/ws 的 url/headers/headersHelper、LSP 的 command/args/env/workspaceFolder |
| `${CLAUDE_PLUGIN_DATA}` | `~/.claude/plugins/data/{id}/`，跨版更新持久保留 | 同上 |
| `${CLAUDE_PROJECT_DIR}` | 專案根目錄 | 同上 |

來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

### 2.8 Plugin 快取與相依性

**快取**：位於 `~/.claude/plugins/cache/`；marketplace plugin 會被複製到快取（非原地使用）；每個版本獨立目錄；孤兒版本約 14 天後清除；更新後 `${CLAUDE_PLUGIN_ROOT}` 會改變；載入前驗證完整性；有 grace period 讓執行中 session 仍可存取舊版本路徑（不應把 state 寫到舊版本路徑）。

**相依性**（`dependencies` 欄位）：`"~2.1.0"` = `>=2.1.0 <2.2.0`；`"^2.1.0"` = `>=2.1.0 <3.0.0`；精確版本字串 = exact。啟用某 plugin 時，相依會在同一 scope 自動啟用；停用被依賴的 plugin 若仍有相依者會失敗；自動安裝的相依會出現在 `plugin list` 中。
來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

**Node.js 套件相依**：若 plugin 同時有 `package.json` 與 lockfile，Claude Code 會自動安裝（`bun.lock(b)` → `bun install --frozen-lockfile --ignore-scripts`；`npm-shrinkwrap.json`/`package-lock.json` → `npm ci --ignore-scripts`）；60 秒逾時、無 lifecycle script、版本凍結（exact）、安裝失敗不會阻擋 plugin 載入。
來源：同上

---

## 3. Skills 的觸發與呼叫方式

### 3.1 觸發途徑

1. **`/skill-name`**：使用者直接輸入斜線指令觸發。
2. **模型自動觸發**：Claude 依 skill 的 `description`（+ `when_to_use`）判斷相關性後自動載入，除非 `disable-model-invocation: true`。
3. **Skill tool**：Claude 內部透過名為 `Skill` 的工具呼叫 skill；可用 `/permissions` 對其設 deny 規則整體停用，或用 `Skill(name)`（精確比對）/`Skill(name *)`（前綴比對）規則允許/拒絕特定 skill。

來源：[Skills — Restrict Claude's skill access](https://code.claude.com/docs/en/skills)

### 3.2 who-invokes 控制

| Frontmatter | 使用者可呼叫 | Claude 可呼叫 | 何時載入 context |
|---|---|---|---|
| （預設） | 是 | 是 | Description 常駐 context；呼叫時載入完整內容 |
| `disable-model-invocation: true` | 是 | 否 | Description **不**在 context 中；使用者呼叫時才載入完整內容 |
| `user-invocable: false` | 否 | 是 | Description 常駐 context；呼叫時載入完整內容 |

來源：[Skills — Control who invokes a skill](https://code.claude.com/docs/en/skills)

另可用 settings 層級的 `skillOverrides`（不改動 SKILL.md）控制可見度，四種狀態：`"on"`（名稱+描述皆列出、選單顯示）、`"name-only"`（只列名稱、選單顯示）、`"user-invocable-only"`（對 Claude 隱藏、選單顯示）、`"off"`（對兩者都隱藏）。**Plugin skill 不受 `skillOverrides` 影響**，須透過 `/plugin` 管理。
來源：[Skills — Override skill visibility from settings](https://code.claude.com/docs/en/skills)

### 3.3 命名規則（plugin skill）

Plugin skill 一律以 `plugin-name:skill-name` 命名空間呈現，避免與其他來源衝突。命令名稱來源規則：

| Skill 位置 | 命令名稱來源 | 範例 |
|---|---|---|
| Plugin `skills/` 子目錄 | frontmatter `name` 或目錄名，帶 plugin 前綴 | `my-plugin/skills/review/SKILL.md` → `/my-plugin:review`，若 `name: fancy` 則 `/my-plugin:fancy` |
| Plugin 根目錄 `SKILL.md` | frontmatter `name`，無則 fallback 為 plugin 目錄名 | `my-plugin/SKILL.md` 加 `name: review` → `/my-plugin:review` |

若 `name` 已經自帶 plugin 前綴，v2.1.246+ 不會重複加前綴（v2.1.216–v2.1.245 之間會重複加前綴，屬已知歷史缺陷）。
來源：[Skills — How a skill gets its command name](https://code.claude.com/docs/en/skills)

### 3.4 參數傳遞

見 §2.2.2（`$ARGUMENTS`、`$ARGUMENTS[N]`、`$N`、`$name`）。

### 3.5 Frontmatter 欄位實際效果

已在 §2.2 完整表列。要點回顧：`description`/`allowed-tools`/`model` 的實際效果——

- `description`：**唯一**被官方標「建議」欄位；直接決定 Claude 是否自動觸發，並截斷顯示於 skill listing（與 `when_to_use` 合計 1536 字元上限）。
- `allowed-tools`：**只在呼叫當輪**授權列出的工具免詢問，不是「限制」而是「預先核准」；不受 workspace trust 閘門控制（即使在未信任的資料夾用 `-p` 執行也照樣套用）——因此文件特別警告：使用前應檢視 checked-in skill 的 `allowed-tools` 內容。
- `model`：只在該 skill 生效的當輪覆寫模型，不寫入 settings，下一則訊息恢復 session 模型；若指定值被組織 `availableModels` allowlist 排除則不生效並維持原模型。

來源：[Skills](https://code.claude.com/docs/en/skills)

---

## 4. Plugin 內附 agents 的定義格式與 frontmatter

已在 §2.3 完整列出。這裡特別彙整與「工具/模型/權限」直接相關的三組欄位供設計參考：

- **工具控制**：`tools`（白名單，省略則繼承全部）、`disallowedTools`（黑名單）。可用 `Agent(worker, researcher)` 語法限制此 subagent 能再 spawn 哪些下游 subagent；MCP pattern 如 `mcp__github`、`mcp__*` 可整批移除。
- **模型選擇優先序**：(1) 呼叫時的 per-invocation `model` 參數 → (2) subagent frontmatter 的 `model` → (3) `CLAUDE_CODE_SUBAGENT_MODEL` 環境變數 → (4) 主對話模型。可用 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 強制所有 subagent 用同一模型。
- **權限模式（`permissionMode`）**：`default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan`；**parent 的 `bypassPermissions` 或 `acceptEdits` 會覆蓋 subagent 自訂的 `permissionMode`**；parent 為 `auto` 模式時強制 subagent 也進入 `auto`。

**Plugin agent 的欄位限制**（與獨立 `.claude/agents/` 的差異）：官方 plugins-reference 頁面明確指出 plugin 提供的 agent **不支援** `hooks`、`mcpServers`、`permissionMode`（安全限制）。這點在 sub-agents 通用頁面所列完整欄位表中並未特別排除 plugin 來源，兩份文件之間存在描述落差，已列入「待實測」。

來源：[Create custom subagents](https://code.claude.com/docs/en/sub-agents)、[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

---

## 5. Hooks 在 plugin 中的宣告方式與事件清單

已在 §2.4 完整列出宣告格式（`hooks/hooks.json`）、5 種 handler 型別（command/http/mcp_tool/prompt/agent）、完整事件清單、matcher 規則、輸出/決策格式、安全性考量。重點回顧與 plugin 特別相關者：

- Plugin hook 與使用者/專案層級 hook **合併**生效（不是互斥/取代關係）。
- Plugin hook 也可以直接內嵌在 `plugin.json` 的 `hooks` 欄位（字串路徑/陣列/物件三種寫法皆可）。
- Hook 型別欄位 `matcher` 表中，`SubagentStart`/`SubagentStop` 比對的是「agent 型別」（如 `general-purpose`、`Explore`、或自訂名稱），這對 orchestrator 監控子 agent 生命週期很直接相關。
- Skill/subagent frontmatter 也可以宣告自己的 `hooks`（skill 呼叫後持續整個 session，可設 `once: true`；subagent 的 hook 只在該 subagent 執行期間有效，執行完自動移除，且 `Stop` 事件在 subagent 情境下會轉換成 `SubagentStop`）。

來源：[Hooks reference](https://code.claude.com/docs/en/hooks)

---

## 6. claude plugin CLI

以下透過本機 `claude plugin --help`、`claude plugin <sub> --help` 唯讀查證，與官方文件交叉確認一致。

### 6.1 子指令總覽（本機驗證）

```
claude plugin|plugins [options] [command]

  details [options] <name>             顯示 plugin 元件清單與預估 token 成本
  disable [options] [plugin]           停用已啟用的 plugin
  enable [options] <plugin>            啟用已停用的 plugin
  eval [options] [target]              對 plugin 執行 eval case 並回報分數
  init|new [options] <name>            在 ~/.claude/skills/<name>/ 建立 plugin 骨架
  install|i [options] <plugin>         從已知 marketplace 安裝 plugin（可用 plugin@marketplace 指定）
  list [options]                       列出已安裝的 plugin
  marketplace                          管理 marketplace
  prune|autoremove [options]           移除不再需要的自動安裝相依
  tag [options] [path]                 建立 {name}--v{version} git tag，驗證 plugin.json 與 marketplace 條目一致
  uninstall|remove [options] <plugin>  移除已安裝的 plugin
  update [options] <plugin>            更新 plugin 至最新版本（需重啟生效）
  validate [options] <path>            驗證 plugin/marketplace manifest 或目錄中的 skills/agents/commands
```

### 6.2 各子指令關鍵旗標（本機驗證 + 官方文件補充）

- **`plugin init <name>`**：`--description`、`--author`、`--author-email`（預設取 `git config`）、`--with <components...>`（可加 `skills, agents, hooks, mcp, lsp, output-style, channel`）、`-f/--force`。骨架建立在 `~/.claude/skills/<name>/`，下一 session 自動載入為 `<name>@skills-dir`，**不需要** marketplace 或 install 步驟。
- **`plugin install <plugin>`**：`-s/--scope <user|project|local>`（預設 `user`）、`--config <key=value>`（可重複，設定 `userConfig`）、`-y/--yes`（跳過 command-source 的確認提示；非 TTY 環境必填）。
- **`plugin validate <path>`**：`--strict`（警告視為錯誤）、`--json`（JSON 格式報告，exit code 相同）。可驗證單一 plugin、marketplace manifest，或某目錄下的 skills/agents/commands。
- **`plugin marketplace add <source>`**：接受 GitHub `owner/repo`、任意 git URL、本機路徑、遠端 `marketplace.json` URL；`--scope`（`user`/`project`/`local`）、`--sparse <paths...>`（monorepo 部分 checkout）。
- **`plugin marketplace update [name]`**：不帶名稱時更新全部。
- **`plugin uninstall`**：`--keep-data`（保留持久資料目錄）、`--prune`（連帶移除自動安裝的相依）。
- **`plugin prune`**：`--dry-run`（僅列出不刪除）。
- **`plugin tag`**：建立 `{name}--v{version}` 格式的 git tag，會驗證 `plugin.json` 與（若有）外層 marketplace 條目版本一致。
- **`plugin eval`**：對 `<eval dir>/**/case.yaml` 或 `prompt.md` + `graders/*.md` 執行 eval case 並評分；target 可為路徑、plugin 名稱或 `plugin@marketplace`；installed 與 skills-dir plugin 皆可解析，並會加上一組 no-plugin baseline 對照。

來源：本機 `claude --help`、`claude plugin --help`、`claude plugin validate --help`、`claude plugin install --help`、`claude plugin marketplace --help`、`claude plugin init --help`（已於 2026-09-04 執行驗證）；輔以 [Plugins reference](https://code.claude.com/docs/en/plugins-reference) 交叉確認一致。

### 6.3 本機開發流程

**方式一：`--plugin-dir`**（不需 manifest，指向任意目錄即可測試）：

```bash
claude --plugin-dir ./my-plugin
```

- 可重複指定多次以同時載入多個 plugin：`--plugin-dir ./a --plugin-dir ./b`
- 也接受 `.zip` 封存檔路徑。
- 若同名 plugin 已透過 marketplace 安裝，`--plugin-dir` 版本在該 session 中優先（可測試現有 plugin 的改動而不必先解除安裝），但**無法覆蓋** managed settings 強制啟用/停用的 plugin。
- 修改後執行 `/reload-plugins` 即可套用變更（重載 plugin、skills、agents、hooks、plugin 的 MCP/LSP server），不需重啟整個 session。
- 另有 `--plugin-url`：從遠端下載 `.zip` 封存檔，僅該次 session 有效，適合測 CI 產出的 build artifact；同樣可重複指定或以空白分隔多個 URL 於單一引數中傳入。

來源：[Create plugins — Test your plugins locally](https://code.claude.com/docs/en/plugins)

**方式二：`claude plugin init`**（把開發中 plugin 放進 skills 目錄，免除每次帶 flag）：

```bash
claude plugin init my-tool
```

會在 `~/.claude/skills/my-tool/` 建立含 `.claude-plugin/plugin.json` 與起始 `SKILL.md` 的骨架，下一個 session 自動載入為 `my-tool@skills-dir`，不需 marketplace 或 install。

來源：[Create plugins — Develop a plugin in your skills directory](https://code.claude.com/docs/en/plugins)、[Plugins reference — Skills-directory plugins](https://code.claude.com/docs/en/plugins-reference)

**Skills-directory plugin 的規則**：
- `~/.claude/skills/`：個人層級（每個專案皆可用）。
- `<cwd>/.claude/skills/`：專案層級（需通過 workspace trust 對話框）。
- `SKILL.md` 純文字變更**即時**生效（live change detection），不需 `/reload-plugins`；但其他元件（`hooks/`、`.mcp.json`、`agents/`、`output-styles/`）的變更仍需 `/reload-plugins` 或重啟。
- 停用：`claude plugin disable <name>@skills-dir`。

來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

---

## 7. 安裝與範圍

### 7.1 Scope 對照表

| Scope | Settings 檔案 | 用途 |
|---|---|---|
| `user` | `~/.claude/settings.json` | 個人跨專案使用（預設） |
| `project` | `.claude/settings.json` | 團隊共用，可入版控 |
| `local` | `.claude/settings.local.json` | 專案內個人設定，通常 gitignore |
| `managed` | Managed settings | 組織強制部署，唯讀 |

來源：[Plugins reference](https://code.claude.com/docs/en/plugins-reference)

安裝時互動介面提供三種可選 scope（`managed` scope 只會出現在已安裝清單中，使用者無法自行選擇）：
- **User scope**：個人跨所有專案安裝。
- **Project scope**：安裝給此 repo 所有協作者，寫入 `.claude/settings.json`。
- **Local scope**：僅自己在此 repo 內使用，不與協作者共享。

來源：[Discover and install prebuilt plugins](https://code.claude.com/docs/en/discover-plugins)

### 7.2 Marketplace add 流程

兩階段：先 `add` marketplace（僅登錄目錄，不安裝任何 plugin），再 `install` 個別 plugin。

```
/plugin marketplace add anthropics/claude-code        # GitHub owner/repo
/plugin marketplace add https://gitlab.com/x/y.git    # 任意 git URL
/plugin marketplace add ./my-marketplace               # 本機路徑
/plugin marketplace add https://example.com/marketplace.json  # 遠端檔案
/plugin install plugin-name@marketplace-name
```

官方內建兩個公開 marketplace：
- **`claude-plugins-official`**：Anthropic 策展，**首次互動啟動時自動登錄**（非互動模式下不會自動加入，需手動 `claude plugin marketplace add anthropics/claude-plugins-official`）。
- **`claude-community`**（repo: `anthropics/claude-plugins-community`）：第三方投稿經自動驗證與安全審查後進入，需手動 `/plugin marketplace add anthropics/claude-plugins-community`，安裝時用 `@claude-community`。

來源：[Discover and install prebuilt plugins](https://code.claude.com/docs/en/discover-plugins)

### 7.3 更新機制

- **自動更新**：session 啟動後隨機延遲最多 10 分鐘檢查 marketplace 與已安裝 plugin 的更新；若有更新，提示 `/reload-plugins` 或於下次啟動生效。官方大多數 marketplace 預設開啟自動更新；第三方與本機開發用 marketplace 預設**關閉**。可於 `/plugin` → Marketplaces → 選定 marketplace → Enable/Disable auto-update 切換；`DISABLE_AUTOUPDATER` 環境變數全域關閉；`command` source 的 plugin 有獨立的「每 session 重新執行一次」更新節奏，不受上述設定影響。
- **手動更新**：`claude plugin update <plugin>`（CLI，需重啟生效）或 `/plugin marketplace update <name>`（session 內，`/reload-plugins` 生效）。
- **版本判定**：見 §1.5 版本解析順序。

來源：[Discover and install prebuilt plugins — Configure auto-updates](https://code.claude.com/docs/en/discover-plugins)、[Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)

### 7.4 命名衝突規則

- **Skill 命名衝突**（跨層級解析順序）：enterprise > personal > project；同層級中 skill 會覆蓋同名的 bundled skill（但不覆蓋 bundled skill 的別名）；`.claude/commands/` 與 `.claude/skills/` 同名時 skill 優先；**plugin skill 因為有 `plugin-name:skill-name` 命名空間，天生不與其他層級衝突**，可與同名的專案 skill 並存。
- **Agent 命名衝突**：見 §2.3 的 5 層優先序（managed > `--agents` CLI > 專案 `.claude/agents/` > 個人 `~/.claude/agents/` > plugin `agents/`，plugin agent 一樣有 `plugin-name:agent-name` 命名空間）。遷移指南特別提醒：專案/個人層級的 `.claude/agents/` 定義會**覆蓋**同名的 plugin agent，因此把 `.claude/` 內容轉為 plugin 後，須刪除原始檔案，plugin 版本才會生效。
- **Marketplace 內 plugin 改名**：用 `renames` 欄位做「舊名 → 新名或 null」對照，既有安裝會自動遷移（v2.1.193+）。
- **Marketplace 名稱衝突/保留字**：見 §1.4。

來源：[Skills — Where skills live](https://code.claude.com/docs/en/skills)、[Create custom subagents](https://code.claude.com/docs/en/sub-agents)、[Create plugins — What changes when migrating](https://code.claude.com/docs/en/plugins)、[Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)

### 7.5 團隊層級自動安裝

在專案的 `.claude/settings.json` 加入 `extraKnownMarketplaces`，團隊成員信任該 repo 資料夾後即自動登錄該 marketplace（不會自動安裝外部來源 plugin，只是免手動 add）：

```json
{
  "extraKnownMarketplaces": {
    "my-team-tools": {
      "source": { "source": "github", "repo": "your-org/claude-plugins" }
    }
  }
}
```

若專案 `.claude/settings.json` 的 `enabledPlugins` 宣告了來自外部來源（如 GitHub repo、npm package）的 plugin，v2.1.195+ 不會自動安裝，只會提示尚未安裝，並顯示 `claude plugin install` 指令供成員手動執行。
來源：[Discover and install prebuilt plugins — Configure team marketplaces](https://code.claude.com/docs/en/discover-plugins)

---

## 待實測

以下事項文件描述不夠明確、或不同官方頁面之間存在落差，需要用實際 plugin 開發實驗驗證，且皆會影響 `agent-flow` 的架構設計：

1. **Plugin agent 是否真的不能用 `hooks`/`mcpServers`/`permissionMode`。**
   不確定什麼：`plugins-reference` 頁面明確寫「plugin 提供的 agent 不支援 `hooks`、`mcpServers`、`permissionMode`」，但 `sub-agents` 通用頁面列出的完整欄位表（含這三個欄位）並未註明「僅限非 plugin 來源」。兩者矛盾，不確定實際載入時是「欄位被忽略」「載入直接報錯」還是「plugin agent 其實可以用，只是 reference 頁面過時」。
   為何影響設計：`agent-flow` 若要讓各 phase（Discuss/Explore/.../Wrap）的子 agent 各自有專屬 hook（例如 Dev phase 結束後自動跑 lint/test 的 `PostToolUse` hook）或需要獨立 MCP server（例如 Ticket phase 連 Jira/Linear），若 plugin agent 真的不能宣告這些，就必須改用 plugin 層級的 `hooks/hooks.json`（用 `matcher` 比對 `SubagentStart`/`SubagentStop` 或工具名稱來變相達成 per-agent 行為），架構會完全不同。

2. **`--plugin-dir` 開發時，plugin 內的 subagent 之間互相呼叫（Agent tool / SendMessage）是否受 plugin 命名空間影響，以及 orchestrator（主 session）呼叫 plugin agent 時的確切語法。**
   不確定什麼：文件給的例子是 `@agent-my-plugin:security-reviewer` 這種使用者輸入的 mention 語法，但 `agent-flow` 的設計是「主 session 作 orchestrator，把工作派給子 agent」——這通常代表用 `Agent` tool（而非使用者手動 @mention）呼叫。`Agent` tool 呼叫 plugin agent 時，`subagent_type` 參數要填 `my-plugin:agent-name` 還是別的格式，文件沒有直接給範例。
   為何影響設計：這直接決定 orchestrator 端（如 CLAUDE.md 或某個「派工」skill）呼叫各 phase agent 的程式碼/prompt 該怎麼寫；寫錯會導致找不到 agent。

3. **Phase 之間如何確實傳遞「上一階段產出」給下一階段的 agent，尤其搭配 `isolation: worktree`、`memory` 與 `background` 選項時的实际資料流。**
   不確定什麼：文件說非 fork 的 subagent「不含對話歷史」，只拿到「Claude 傳來的 task 訊息」；八 phase 工作流需要 Discuss/Explore 產出的結論確實流入 Spec/Ticket/Dev，若靠 orchestrator 在每次呼叫時手動把前一階段結果整段塞進 task 訊息，token 成本與正確性如何，文件未討論大型 orchestrator 反覆呼叫、逐階段傳遞長文本 artifact 的最佳實踐或已知限制（例如是否有 task 訊息長度限制、是否建議改用檔案系統中介而非直接傳文字）。
   為何影響設計：這是八 phase 流程能否可靠銜接的核心機制，需要用真實多階段 plugin 實驗驗證「orchestrator 手動傳遞 vs. 讓子 agent 讀寫共用檔案（如 `.agent-flow/spec.md`）」何者更穩定、更省 token。

4. **Skill 的 `context: fork` 與 subagent `isolation: worktree` 併用時的實際行為，以及 worktree 清理時機是否會與 phase 順序衝突。**
   不確定什麼：文件分別說明「forked skill 背景執行的編輯不受 checkpoint 保護」與「worktree 沒有變更時自動清除」，但沒有明確說明：若 Dev phase 用 `isolation: worktree` 的 agent 做修改，緊接著 Review phase 需要看到這些修改時，worktree 是否還在、路徑是否穩定可傳給下一個 agent。
   為何影響設計：`agent-flow` 的 Dev/Review 兩個 phase 若要在隔離環境中連續工作（避免污染主 checkout），必須確認 worktree 的生命週期橫跨多個 phase 呼叫時是否可控，否則需改回不用 `isolation` 而靠 git branch 手動管理。

5. **Plugin 內 `settings.json` 的 `agent` 欄位（啟用 plugin 時把某個 plugin agent 設為主 thread）與「主 session 作 orchestrator」的設計是否相容/衝突。**
   不確定什麼：文件說 plugin 根目錄的 `settings.json` 可設 `agent` 欄位，啟用 plugin 時直接把主對話 thread 換成該 agent 的 system prompt/工具限制/模型。若 `agent-flow` 想讓「使用者一啟用 plugin，主 session 就變成 orchestrator 角色」，這是否是正確用法，還是這個機制設計給「plugin 想完全接管主 session 人格」的單一 agent plugin（而非本專案的多 agent 派工模型）用的；用了之後 orchestrator 還能不能正常用 `Agent` tool 派工給其他 phase agent。
   為何影響設計：決定 `agent-flow` 要不要用這個機制固化 orchestrator 角色，還是單純靠 README/skill 引導使用者手動輸入初始指令。

6. **Marketplace 保留名稱清單的完整性與 `agent-flow` 專案/marketplace 命名是否安全。**
   不確定什麼：保留清單是否為官方文件當下完整列表，或還有其他未公開/會隨時間增加的保留字；`agent-flow` 未來若要自建 marketplace 散布，需先用 `claude plugin validate` 或實際 `marketplace add` 測試命名是否會被拒。
   為何影響設計：影響專案未來發佈 marketplace 時的命名選擇，屬低風險但值得在正式發佈前一次性驗證。

7. **`claude plugin eval` 的 `case.yaml`/`prompt.md` + `graders/*.md` 格式與八 phase 工作流程的可測試性。**
   不確定什麼：本機 `--help` 只給出指令輪廓（target 可為路徑/plugin 名稱/`plugin@marketplace`，含 no-plugin baseline），但未查證 `case.yaml` schema、grader 撰寫方式、如何針對「多 phase 順序流程」寫 eval（而非單一 skill 的輸入輸出）。
   為何影響設計：若 `agent-flow` 想用官方 eval 機制做 CI 回歸測試（驗證 SDD/TDD 八 phase 是否正確銜接），需要先搞懂 eval 框架能不能表達「多輪、多 agent」的流程斷言，或需自建測試機制。

---

## 摘要

本報告已完整取得 Claude Code plugin 系統的官方 schema：`plugin.json`（1 個必填欄位 `name`，20+ 選填欄位，manifest 本身可省略靠自動探索）、`marketplace.json`（`name`/`owner`/`plugins` 必填，7 種 plugin source 型別）；六種元件（skills、agents、hooks、MCP servers、LSP servers、monitors，另有 output-styles/themes/workflows/channels）各自的目錄結構與完整 frontmatter/schema；skill 的三種觸發方式（`/name`、模型自動、Skill tool）與 `disable-model-invocation`/`user-invocable`/`allowed-tools`/`context:fork` 等控制欄位；plugin agent 的命名空間、scope 優先序（managed > CLI > 專案 > 個人 > plugin）與背景/前景工具集差異；hook 的 5 種 handler 型別與 30+ 事件；`claude plugin` CLI 全部子指令（已用本機 `--help` 交叉驗證）；以及 user/project/local/managed 四種安裝 scope 與命名衝突規則。

**待實測清單（7 項，摘要）**：(1) plugin agent 能否用 `hooks`/`mcpServers`/`permissionMode`（兩份官方頁面矛盾）；(2) orchestrator 用 `Agent` tool 呼叫 plugin agent 的確切 `subagent_type` 語法；(3) 多 phase 之間傳遞產出的最佳資料流（task 訊息 vs. 共用檔案）；(4) `context:fork` + `isolation:worktree` 併用時 worktree 能否跨 phase 存活；(5) plugin `settings.json` 的 `agent` 欄位是否適合用來固化 orchestrator 角色；(6) marketplace 保留名稱清單完整性；(7) `claude plugin eval` 能否表達多輪多 agent 流程測試。這 7 項都需要在下一波「安裝實驗」階段用實際 plugin 骨架驗證，再據以定案 `agent-flow` 的元件切分與呼叫協定。
