# research/ — 可行性研究索引

本目錄是 agent-flow 開發流程第 1 步「可行性研究」的產出。方法：四個平行研究
agent 做文件與先行案例調查（01–04），彙整各報告的「待實測」清單後，兩個實驗
agent 在 /tmp 沙箱以便宜模型（Haiku）headless 實測（05–06）。全程未寫入
`~/.claude/`。文件與實驗矛盾時，以實驗為準。

## 報告索引

| 檔案 | 內容 | 方法 |
|---|---|---|
| `01-plugin-mechanism.md` | plugin.json／marketplace.json schema、六大元件目錄結構與 frontmatter、skill 觸發機制、agent scope 優先序、hook 事件清單、CLI 子指令、安裝範圍與命名衝突 | 官方文件 + 本機唯讀 CLI 查證 |
| `02-orchestration.md` | 子代理定義與呼叫、巢狀與平行度上限、worktree 隔離、hooks 品質閘門能力、狀態外部化、headless 執行、model 與成本控制 | 官方文件 |
| `03-prior-art-sdd.md` | SDD 先行案例：Spec Kit、OpenSpec、Kiro — phase 結構、產物格式、traceability、關卡設計、狀態外部化（文末對照表） | clone 原始碼 + 官方文件；Kiro 部分為第三方資料（已標註） |
| `04-prior-art-workflows.md` | TDD 與多 agent 案例：BMAD-METHOD、Superpowers、Anthropic 多智能體研究系統 — TDD 防呆、審查退回機制、平行隔離、收尾自動化（文末對照表） | clone 原始碼 + 官方工程文章；claude-flow 為第三方報導（已標註低可信度） |
| `05-experiments-plugin.md` | 實測：plugin agent 欄位支援、程式化呼叫語法、settings.json agent 欄位、plugin eval、validate 檢查深度 | /tmp 實驗（產物留在 `/tmp/agent-flow-exp/`） |
| `06-experiments-hooks-worktree.md` | 實測：SubagentStop 閘門身分、hook matcher 語法、headless 平行 worktree、isolation: worktree 生命週期、無人值守權限行為、Dynamic Workflow 觸發限制 | /tmp 實驗（產物留在 `/tmp/agent-flow-exp-hooks/`） |
| `07-experiments-dev-loop.md` | 實測（設計稽核後補做）：SendMessage 續談 worktree 子代理、worktree 分岔基準 | 本 session 內＋/tmp 實驗（worktree 已清理） |
| `08-baseref-persistence.md` | 查證（規格對齊時補做）：worktree.baseRef 證實為可持久化的 settings.json 欄位（{"worktree": {"baseRef": "head"}}，Scope: Any file）；spec 疑似設計矛盾不成立 | 官方文件（worktrees 頁＋settings-reference 頁） |

## 對設計影響最大的裁決

以下每條在對應報告內有完整證據與來源 URL。

1. **寫審分離必須由 orchestrator 完成**：SubagentStop hook 阻擋後重試的是同一個
   子代理（同 context），hook 無法換成獨立審查者（06 第 1 項【證實】）。品質迴圈
   的「獨立於作者」只能靠 orchestrator 拿到產出後另派審查子代理。
2. **Wrap 全自動在權限維度可行，但要處理靜默失敗**：headless 下未涵蓋的權限會
   乾淨拒絕、流程繼續、不卡住（06 第 5 項【證實】）。風險型態是「動作被拒但流程
   照走」，收尾邏輯必須驗證每個動作實際成功。先行案例中無「全自動合併」範本
   （04），判準需自行定義。
3. **Dev／Review 無法共用隔離環境**：`isolation: worktree` 每次呼叫都是全新
   worktree、不重用（06 第 4 項【證實】）；headless `--worktree` 用完不自動清理
   （06 第 3 項【證實】），生命週期要自行管理。
4. **plugin agent 不支援 hooks 欄位**：官方兩頁描述矛盾，實測裁決為不支援
   （05 第 1 項【證實】）。品質閘門 hooks 須放專案層級。
5. **程式化派工語法確認**：Agent tool 的 subagent_type 為
   `<plugin-name>:<agent-name>`（05 第 2 項【證實】）。
6. **`claude plugin validate` 檢查很淺**：不查未知欄位與 plugin agent 禁用欄位，
   CI 不能只靠它（05 第 5 項【證實】）。
7. **狀態外部化沒有官方格式**：transcript 格式不保證穩定（02），先行案例一致採
   「檔案落地進版控」（03、04）——phase 狀態應存 repo 內檔案。

### 補充裁決（07，設計稽核發現的空白）

8. **Dev 退回可用 SendMessage 續談**：續談同一個 worktree 子代理時，worktree
   路徑、分支與未 commit 變更完整保留（【證實】）；但完成通知只回到主
   session，不回發起續談的中介子代理 — 續談必須由主 session 親自發起。
9. **worktree 分岔基準跟隨當下 checkout**（【證實，附條件】，無 remote 的
   local repo 下）：Dev 建 worktree 前 orchestrator 必須 checkout 到單位分支
   並明確設 baseRef: head，不能依賴預設。有 remote 情境未測。

## 實驗推翻或修正文件的紀錄

- `claude plugin validate` 錯誤訊息聲稱 YAML 解析失敗的 agent「執行期不會載入」，
  實測仍會以檔名載入並可被委派（05，【推翻】）。
- 文件稱自然語言請求 Dynamic Workflow 在 `-p` 下被排除；實測 `ultracode:` 隱性
  關鍵字確實不觸發，但明確指名「Use the Workflow tool」在 `-p` 下可運作
  （06 第 6 項，表述過於一概而論，以實測為準）。

## 未實測項目與原因

| 項目 | 來源 | 不實驗的原因 |
|---|---|---|
| marketplace 保留名稱清單完整性 | 01 待實測 | 純文件問題，無法以實驗窮舉 |
| TaskCreate 系列長流程穩定性 | 02 待實測 | 無法小規模重現長流程 |
| 狀態檔寫入與 auto-compact／worktree 檢查的互動 | 02 待實測 | 無法小規模且確定性地觸發 compaction |
| agent teams 意外啟用的防護 | 02 待實測 | 優先級低（實驗性功能、預設關閉） |
| plugin eval 多輪多 agent 斷言 | 05【未能測出】 | 本機鎖在 early access |
| plugin agent 的 mcpServers／permissionMode 欄位 | 05【未能測出】 | 假 MCP server 無法握手；A/B 對照無差異無法歸因 |

## 環境備註

本機 `~/.claude/settings.json` 既有設定含 `defaultMode: bypassPermissions` 與
`Bash(*)` allowlist，曾汙染 06 第 5 項的初次測試（已用 `--permission-mode
default` 修正重測）。後續在本機驗證 agent-flow 的權限相關行為時，須注意本機
設定與終端使用者預設環境不同。
