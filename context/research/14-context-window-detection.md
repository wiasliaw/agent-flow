# 14 — model 能否自行偵測剩餘 context（R13 前置）

**問題**：orchestrate 在單一 session 連跑多個 phase 會觸發 auto-compact。若 model
（執行中的主 session 本身）能偵測自己剩餘多少 context，orchestrate 就能動態決定
何時停下、提示使用者換 session；否則只能採固定斷點。

**方法**：官方文件調查（由 claude-code-guide agent 代查，2026-09-21）。本研究
**未做 /tmp 實驗**——結論全部來自文件有無記載；文中標【未驗證】者若日後要採用，
須先依本 repo 慣例實測。

**結論**：**沒有任何官方記載的機制能讓 model 在 session 中讀到剩餘 context**。
動態斷點在 documented 行為範圍內不可行。

## 逐項查證

### 1. 低 context 系統警告——未記載

context-window 文件說明 context 填滿與 compaction 機制，但沒有任何「會注入 model
可讀的低 context 警告」的記載。SKILL.md 不能以「看到警告時做 X」為前提。

- 來源：<https://code.claude.com/docs/en/context-window.md>

### 2. `/context` 指令——僅使用者可見

`/context` 是 CLI 使用者指令，不在 model 的工具清單中，model 無法呼叫也看不到
其輸出。

- 來源：<https://code.claude.com/docs/en/tools-reference.md>（工具清單無此項）

### 3. `PreCompact` hook——能擋、不能回饋

- 觸發時機：自動或手動 compaction 之前；輸入 JSON 含 `session_id`、`cwd`、
  `transcript_path`、`compaction_trigger`（`"auto"`／`"manual"`）。
- exit code 2 可以擋下 compaction。
- 但 hook 輸出無法送進 model 的 context——PreCompact 在 model 下一輪之前執行，
  其輸出不會改變 model 收到的內容。無法用它告訴 model「context 快滿了」。

- 來源：<https://code.claude.com/docs/en/hooks.md>、
  <https://code.claude.com/docs/en/hooks-guide.md>（「Re-inject context after
  compaction」一節：`additionalContext` 重新注入是 SessionStart hook 的能力，
  發生在 compaction 之後）

### 4. statusline 輸入 JSON——欄位齊全但僅使用者可見

statusline 收到 `context_window.used_percentage`／`remaining_percentage`／
`total_input_tokens`／`context_window_size`，但輸出只渲染在終端 prompt 下方給
使用者看，不會送進 model。

- 來源：<https://code.claude.com/docs/en/statusline.md>（「Available data」一節）

### 5. 環境變數——不存在

`env-vars` 文件與 CLI reference 查無 `CLAUDE_AUTOCOMPACT`、`CLAUDE_CONTEXT_*`
等相關變數。未記載。

- 來源：<https://code.claude.com/docs/en/env-vars.md>

### 6. auto-compact 設定——可調但 model 讀不到

`autoCompactEnabled`（開關）與 `autoCompactWindow`（觸發閾值）皆為 settings
欄位（Scope: any settings file），但設定值不出現在 model 可見的任何資料中。

- 來源：<https://code.claude.com/docs/en/settings-reference.md>

## 未記載的可能繞路（均【未驗證】，採用前須實測）

1. **transcript 解析＋hook 注入**：hook 輸入含 `transcript_path`，session
   transcript（JSONL）內有每次 API 回應的 token 用量；理論上 `UserPromptSubmit`
   hook 可解析後把用量以 `additionalContext` 注入 model。屬逆向 session 內部
   格式，官方不支援；auto-compact 閾值本身仍讀不到，只能估百分比。
   - 相關佐證：<https://code.claude.com/docs/en/costs.md>（token 計數為使用者
     面向，無 model 端存取方式的記載）
2. **harness 注入 token 預算指標**：已觀察到存在「工具結果後附剩餘 token 數」
   的 harness 配置（本 repo 開發 session 親見），證明此類配置存在；但未記載、
   環境相依，plugin 發佈給終端使用者時不能假設它在。

## 對設計的意涵（→ R13）

動態偵測不可行，斷點只能固定。承諾點（gate）本來就是流程停等點、且
`state.json` 的續接程序（spec/05 §2.1）已支援從任意點恢復，因此承諾點是唯一
不需要新機制的自然 context 斷點。使用者側的輔助（statusline 百分比、PreCompact
hook 的 `systemMessage` 通知）給的是人、不是 model，可作為補充但不改變上述結論。

- 佐證：<https://code.claude.com/docs/en/how-claude-code-works.md>（「The context
  window」一節：說明 auto-compaction，並建議持久規則放 CLAUDE.md 而非依賴對話
  歷史——隱含 model 看不到 compaction 訊號）
