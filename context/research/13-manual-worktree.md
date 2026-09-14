# 13｜改用主 session 自建 worktree 的可行性與擺放位置

調查目的：`research/12` 證實在有 remote 的專案中，`isolation: "worktree"` 的預設
分岔基準是遠端預設分支，因此必須要求使用者寫入 `{"worktree": {"baseRef": "head"}}`。
使用者裁決改採 `research/12` §5 記錄的替代方案——**由主 session 自行
`git worktree add` 從單位分支建立**，以取消該前置設定。本報告驗證此機制是否成立，
並判定 worktree 的擺放位置。

- **環境**：Claude Code CLI 2.1.259，macOS（2026-09-14）。
- **方法**：`/tmp/af-mw/` 沙箱建**帶真實 remote** 的 repo（與 `research/12` 同一
  佈置），**刻意不建立 `.claude/settings.json`**，逐項驗證。全程未寫入
  `~/.claude/`；沙箱已清理。

## 1. 核心機制成立【證實】

單位分支 `flow/test` 上有未 push 的 commit `9f9a736`（含 `UNIT_MARKER.txt`），
遠端預設分支 `origin/main` 停在更早的 commit。**無任何 `baseRef` 設定**下，主
session 執行：

```sh
git worktree add -b ticket/t1 <path>/t1 flow/test
git worktree add -b ticket/t2 <path>/t2 flow/test
```

兩個 worktree 的 HEAD 皆為 `9f9a736`、`UNIT_MARKER.txt` 皆存在——**分岔基準由指令
參數直接指定，不經過 `baseRef` 解析**，所以遠端預設分支是什麼完全不相干。

**平行工作**：同一則訊息派出兩個 `general-purpose` 子代理（**不帶** `isolation`
參數），各自在派工 prompt 中被告知 `cd <worktree path>`。兩者都正確回報自己的分支
（`ticket/t1`／`ticket/t2`）、看得到 `UNIT_MARKER.txt`、各自建檔並 commit 成功。
每個子代理有獨立的 Bash session，`cd` 互不干擾。

**合併與清理**：`git merge --no-ff ticket/t1`／`t2` 依序合併回單位分支後，
`git worktree remove` ＋ `git branch -d` 清理乾淨，`git worktree list` 只剩主工作樹。

## 2. 附帶收穫：INV-3 的硬性約束可以放寬【證實】

原 INV-3 規定「Build 票證的審查退回只能用 `SendMessage` 續談同一個 `agentId`」，
理由是**重新派工會拿到全新 worktree、既有實作全失**（`research/07` Test A）。

改為主 session 自建之後，worktree 的生命週期**與子代理無關**——它存在於磁碟上，
直到主 session 明確移除。實測：兩個 worktree 在其子代理結束後仍保有各自的 commit
（`4357909`／`2c1143c`）。因此「派一個新子代理並告知同一個 worktree 路徑」不再會
遺失任何工作。

**判定**：續談仍然是**首選**（保留子代理已經建立的理解，省去重新摸索的成本），但
它從「正確性的唯一手段」降級為「效率上的偏好」。災難性失效模式消失。

## 3. 擺放位置：三個選項的實測【證實】

**共同問題**：巢狀 worktree 會出現在母 repo 的 `git status` 中，而且
`git add -A` 會把它當成 **embedded git repository** 加入索引：

```
warning: adding embedded git repository: .agent-flow/worktrees/t6
A  .agent-flow/worktrees/t6
```

這會讓單位分支的 commit 帶進一個 gitlink，必須阻止。

| 選項 | 結果 |
|---|---|
| **A. `.git/` 底下**（如 `.git/agent-flow-worktrees/<id>`） | `git status` 完全乾淨、不需任何 ignore 設定——但 **Write 工具被權限系統擋下**（子代理回報 `Permission to use Write has been denied.`，即使 `Write` 在 `--allowedTools` 內）。Build 實作者必須寫檔，**此選項不可用** |
| **B. 專案根 `.gitignore` 加 `.agent-flow/worktrees/`** | 可行，`git status` 乾淨、`git add -A` 安全——但需要修改使用者的專案設定，等於把「寫 settings.json」換成「寫 .gitignore」，沒有真正取消前置步驟 |
| **C. `.agent-flow/.gitignore` 內含 `worktrees/`**（**採用**） | 可行且**完全自給自足**：ignore 檔在 agent-flow 自己的目錄內，由它建立 `.agent-flow/` 時一併產生，不碰專案根目錄的任何設定。實測 `git status` 乾淨、`git add -A` 不吃進 worktree、worktree 功能完全正常、專案根目錄自始至終沒有 `.gitignore` |

**採用 C**：worktree 路徑為 `.agent-flow/worktrees/<ticket-id>`，並在建立
`.agent-flow/` 時一併寫入 `.agent-flow/.gitignore`，內容一行 `worktrees/`。

## 4. 對規格的影響

| 原規定 | 變更後 |
|---|---|
| `worktree.baseRef: "head"` 專案設定（INV-13 前半） | **取消**——分岔基準由 `git worktree add <path> flow/<unit>` 的參數直接指定 |
| `worktree_preflight()` 一次性檢查與徵詢代寫 | **取消**——無設定可檢查 |
| Agent tool 呼叫時參數 `isolation: "worktree"` | **取消**——改為普通派工＋prompt 告知 `cd <path>` |
| `$worktree_path` 來自完成通知 | 改為**主 session 自己決定並記錄**（建立時就知道） |
| INV-3「只能 `SendMessage` 續談」 | 放寬為「續談為首選」；重新派工至同一路徑不再遺失工作（§2） |
| INV-13「設定 ＋ checkout 單位分支」兩前提 | 只剩「單位分支存在」——`git worktree add` 明確指定來源分支，主 session 當下 checkout 在哪已不相干 |

新增要求：建立 `.agent-flow/` 時一併寫 `.agent-flow/.gitignore`（§3）。

## 5. 未實測項目

| 項目 | 原因 |
|---|---|
| 子代理在 worktree 內誤用 `cd` 跑掉到別的路徑的防護 | 屬 prompt 紀律，非平台行為 |
| Windows 路徑與 `git worktree` 的互動 | 本機僅 macOS |
| 20 個以上 worktree 並存時的磁碟與效能表現 | INV-4 的 20 併發上限本來就先觸發 |
