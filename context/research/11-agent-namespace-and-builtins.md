# 11｜Agent 命名空間的實際保護力，與內建 agent 能否取代 `agents/`

調查目的：兩個相連的問題。(A) `spec/01` §2.4 記載的「已知風險：agent 命名衝突靜默
覆蓋」（源自 Q36）是否真的成立——派工語法是命名空間化的 `agent-flow:worker`，專案
層級的同名 `worker` 究竟會不會蓋掉它？(B) 若風險成立，是否應該乾脆不實作
`agents/`，改用 Claude Code 內建 agent（`general-purpose`／`Explore`）加上派工
prompt 表達角色？

- **環境**：Claude Code CLI 2.1.259，macOS（2026-09-14）。
- **方法**：`/tmp/af-collide/` 沙箱，headless `-p` ＋ Haiku ＋ `--plugin-dir`
  唯讀掛載實驗 plugin，未 install、未寫入 `~/.claude/`。實驗後沙箱已清理。
- 來源比對：`research/01` §2.3／§7.4、`research/02` §1–§3。

## 1. 起點：官方文件在這一點上自相矛盾

`research/01` §7.4 同一段裡有兩句話互相牴觸：

> Agent 命名衝突：見 §2.3 的 5 層優先序（managed > `--agents` CLI > 專案
> `.claude/agents/` > 個人 `~/.claude/agents/` > plugin `agents/`，**plugin agent
> 一樣有 `plugin-name:agent-name` 命名空間**）。遷移指南特別提醒：專案/個人層級的
> `.claude/agents/` 定義會**覆蓋**同名的 plugin agent。

「有命名空間」與「同名會覆蓋」不可能同時為真——除非覆蓋只發生在以**裸名**定址時。
相鄰的 skill 條目則明確寫「plugin skill 因為有命名空間，天生不與其他層級衝突」。
本實驗就是要判定 agent 屬於哪一種。

## 2. 實驗一：同名的 plugin agent 與專案 agent 是否共存【證實】

佈置：專案 `.claude/agents/worker.md`（body 要求回覆 `IAM_PROJECT_COPY`）與 plugin
`agents/worker.md`（回覆 `IAM_PLUGIN_COPY`），兩者 `name` 皆為 `worker`。

**可見性**——請主 session 列出所有可用的 `subagent_type`：

```
claude
Explore
expp:worker        ← plugin 版，命名空間形式
general-purpose
Plan
worker             ← 專案版，裸名
```

兩個都在清單裡，**以不同名稱並存**，plugin 版沒有被移除。

**定址結果**：

| 派工目標 | 實際執行的定義 |
|---|---|
| `subagent_type: "expp:worker"` | `IAM_PLUGIN_COPY` |
| `subagent_type: "worker"` | `IAM_PROJECT_COPY` |

**結論【證實】**：命名空間確實提供保護。專案／個人層級的同名 agent 只佔用**裸名**，
不會取代 `<plugin>:<name>`。`research/01` §7.4 引述的「覆蓋」說法描述的是另一種情境
——把 `.claude/agents/*.md` 遷移進 plugin 卻沒刪除原檔時，既有的**裸名**引用會解析
到專案副本，所以遷移指南才要求刪除原始檔案。

**對 `spec/01` §2.4 的影響**：該節「使用者專案或個人層級若已有同名 agent 定義檔，會
悄悄取代本 plugin 的定義且無任何警告」**不成立**。agent-flow 一律以
`agent-flow:worker`／`agent-flow:reviewer` 派工（`references/glossary.md` 的
`dispatch` 原語明文規定），落在受保護的路徑上。殘留的真實風險只有一種，而且性質不同：
主 session 若把派工目標誤寫成裸名 `worker`，會打到使用者自己的 agent。那是派工紀律
問題，不是平台的靜默覆蓋。

## 3. 實驗二：`disallowedTools` 對 plugin agent 是否有強制力【證實】

`reviewer` 的唯讀保證靠 `disallowedTools: Write, Edit`。若這只是建議性的，保留
`agents/` 的主要論據就不存在。

佈置：plugin agent 宣告 `tools: Read, Write, Edit, Bash` 但
`disallowedTools: Write, Edit`，然後明確要求它用 Write 建立檔案。

子代理回覆：

> The Write tool is **not available** to me. My available tools are: Read, Bash.
> The Write tool is not included in my toolkit, so I cannot complete this task.

目標檔案未被建立（目錄為空）。

**結論【證實】**：`disallowedTools` 在工具層真正移除該工具，不是 prompt 層的勸導。
`tools` allowlist 同理（`research/02` §1.2 記載 denylist 優先）。

## 3.5 實驗三：命名空間**不可**寫進 `name` 欄位【證實】

既然命名空間有保護力，直覺會想「那乾脆把它明寫進 agent 定義」。實測顯示這會造成
冒號疊加。

佈置：同一個 plugin（`name: expp`）下兩個 agent——一個 frontmatter 寫
`name: expp:worker`，一個對照組寫 `name: plain`。列出可用的 `subagent_type`：

```
expp:expp:worker     ← frontmatter 寫了命名空間的那個
expp:plain           ← 裸名對照組，正常
```

**結論【證實】**：命名空間由平台自動衍生為 `<plugin-name>:<agent-name>`，`name`
欄位只該放裸名。寫成 `name: expp:worker` 會讓正式名稱變成 `expp:expp:worker`。
（附帶觀察：以 `expp:worker` 派工在本次測試中仍能解析到該 agent，推測有前綴容錯，
但正式清單名已經是疊加形式——不應依賴未記載的容錯行為。）

**`claude plugin validate` 不會攔截這個錯誤**：含冒號 `name` 的 plugin 驗證
`✔ Validation passed`，零警告。這與 `research/10` §4 的結論一致——validate 不檢查
欄位值的語意。

## 4. 內建 agent 與本 plugin 兩個 agent 的能力對照

內建可用者（`research/01` §2.3）：`Explore`（唯讀、快速搜尋、一次性）、`Plan`
（唯讀、plan mode 研究）、`general-purpose`（完整工具集）、`claude`（catch-all、
所有工具）。逐項比對 agent-flow 的硬性需求：

| agent-flow 的需求 | 依據 | 自訂 `agents/` | `general-purpose` ＋ prompt | `Explore` ＋ prompt |
|---|---|---|---|---|
| Build 票證審查退回時**續談同一子代理** | INV-3；`research/07` Test A（重新派工＝全新 worktree、實作全失） | 可續談 | 可續談 | **不可**——內建 Explore／Plan 是 one-shot（`research/02` §2.4） |
| `reviewer` 工具層唯讀 | spec/03 唯讀契約；避免審查者改動受審產物 | `disallowedTools` 強制（§3【證實】） | **做不到**——完整工具集含 Write／Edit，只能靠 prompt 勸導 | 工具層唯讀 ✓ |
| 子代理**不得巢狀派工** | INV-10、`references/dispatch.md` 規則 4 | `tools` 不含 `Agent`，`scripts/mechanical-check.sh` 斷言 | **做不到**——持有 `Agent` tool，預設可巢狀 3 層（`research/02` §3.2） | 無 `Agent` tool ✓ |
| 模型分級（worker sonnet／reviewer opus） | R5 | frontmatter `model` | 呼叫時 `model` 參數即可 ✓ | 同 ✓（優先序：呼叫參數 > frontmatter，`research/02` §7.1） |
| `isolation: "worktree"` | R5、spec/03 | 呼叫時參數 | 同 ✓ | 同 ✓ |
| 角色鐵律常駐（測試合約禁改、審查不採信自報、拋棄式副本紀律） | INV-2、spec/03、spec/11 | agent body，每次派工自動載入 | 須寫進每次派工 prompt 或另一份 reference | 同左，且要對抗其內建「找程式碼、不做審查」的取向 |

另有兩點對 `Explore` 不利：它會**跳過 CLAUDE.md 與 git status 快照**以加快啟動
（`research/01` §2.3、`research/02` §1.3），而它的內建 system prompt 明確定位為
「讀節錄而非整檔，負責定位程式碼、不做審查或稽核」——把它當 `reviewer` 用，等於一路
與它自己的 system prompt 對抗。

## 5. 結論

1. **命名衝突風險不成立**（§2）。`spec/01` §2.4 的風險敘述應改寫；Q36「不做啟動
   掃描」的裁決因風險消失而自然成立，不需要變更。
2. **不應廢除 `agents/`**（§3、§4）。移除後會失去兩項**工具層**保證——`reviewer`
   的唯讀、以及子代理不得巢狀派工——兩者都退化成 prompt 層的勸導，而它們正好是品質
   迴圈「獨立於作者」與 INV-10 的物理基礎。模型指派與 worktree 隔離確實可以改用呼叫
   時參數，但那本來就不是保留 `agents/` 的理由。
3. 原本推動「廢除 `agents/`」的動機（規避撞名）已被 §2 推翻，因此這筆交易是**只有
   成本、沒有收益**。

## 6. 未實測項目

| 項目 | 原因 |
|---|---|
| `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` 能否替代 `tools` 排除 `Agent` | 那是使用者環境變數，plugin 無法控制，不構成可用的替代方案 |
| 個人層級 `~/.claude/agents/worker.md` 的行為 | 依實驗紀律不寫入 `~/.claude/`；專案層級已足以判定命名空間規則 |
| `--agents` CLI 與 managed scope 是否也只佔裸名 | 優先序更高的兩層未測，但兩者皆為使用者／管理者主動指定，不屬「靜默」情境 |
