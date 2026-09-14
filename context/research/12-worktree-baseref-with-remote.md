# 12｜有 remote 情境下 `worktree.baseRef` 是否必要

調查目的：補上 `research/07` Test B 明確標註的空白。該測試證實 `isolation: worktree`
的分岔基準跟隨當下 checkout，但結論加了條件——**「無 remote 的 local repo 下」，
有 remote 情境未測**。若在有 remote 的真實專案中分岔基準仍跟隨當下 checkout，那麼
INV-13 要求的專案設定 `{"worktree": {"baseRef": "head"}}` 就是多餘的前置條件，
`spec/05` §2.2 的徵詢代寫程序、`references/dispatch.md` 規則 6 與 README 的「執行
Build 前」一節都可以刪除。本報告判定它是否真的必要。

- **環境**：Claude Code CLI 2.1.259，macOS（2026-09-14）。
- **方法**：`/tmp/af-wt/` 沙箱建**帶真實 remote** 的 git repo（`git init --bare` 當
  remote、clone 出工作 repo、`git remote set-head origin main` 明確設定遠端預設
  分支），在單位分支上以 headless `-p` ＋ Haiku 派出 `isolation: "worktree"` 子代理，
  比對有／無設定兩種條件下 worktree 的 HEAD。全程未寫入 `~/.claude/`；實驗後
  worktree 與沙箱已清理。
- 來源比對：`research/02` §4.4（官方預設 `baseRef` 為 `"fresh"`——從遠端預設分支
  分出）、`research/07` Test B、`research/08`（`baseRef` 可持久化於 settings.json）。

## 1. 佈置

```
remote.git (bare, default branch main)
└── work/                     ← clone，origin/HEAD → refs/remotes/origin/main
    ├── a2a311a  main: base commit          （在 main 上，已 push）
    └── 518a4ab  unit: adds UNIT_MARKER     （在 flow/test 上，未 push）
```

主 session 在 `flow/test` 上（HEAD = `518a4ab`），然後派出帶
`isolation: "worktree"` 的子代理，請它回報 `git log --oneline -2`。

判準很直接：worktree 的 HEAD 若是 `518a4ab` 就是跟隨當下 checkout；若是 `a2a311a`
就是從遠端預設分支分出。

## 2. 測試 A：**沒有**設定【證實】

專案無 `.claude/settings.json`。子代理回報：

```
(1) git branch --show-current
worktree-agent-a6d75b9e80aa001b7

(2) git log --oneline -2
a2a311a main: base commit
```

**worktree 分岔自 `a2a311a`——遠端預設分支**，只有一個 commit，單位分支的
`518a4ab` 不在其中，`UNIT_MARKER.txt` 不存在。

## 3. 測試 B：寫入 `{"worktree": {"baseRef": "head"}}`【證實】

同一個 repo、同一個分支，只加上專案 `.claude/settings.json`。子代理回報：

```
(2) git log --oneline -2
518a4ab unit: adds UNIT_MARKER
a2a311a main: base commit
```

**worktree 分岔自 `518a4ab`——單位分支 tip**，兩個 commit 都在。

補充確認（第三次派工）：worktree 路徑為
`<repo>/.claude/worktrees/agent-<id>`，`test -f UNIT_MARKER.txt` 回報
`MARKER_PRESENT`——檔案確實 checkout 出來，不只是 git 中繼資料。
（前兩次測試中 `ls` 回報空白是子代理輸出擷取的假象，非目錄真的為空。）

## 4. 結論

**設定是必要的【證實】。** `research/07` Test B「分岔跟隨當下 checkout」的結論
**只在沒有 remote 時成立**——那是 `"fresh"` 找不到遠端預設分支時退回本地 HEAD 的
副作用，不是 `baseRef` 的真正語意。真實專案幾乎都有 remote，此時預設行為會讓每個
票證 worktree 從 `origin/main` 分出：

- 票證拿不到單位分支上 Explore／Spec／TDD 階段已 commit 的產物（`.agent-flow/`
  底下的 `spec-delta.md`、`tickets/` 全部不存在）；
- 票證之間無法堆疊——第 2 波的票證看不到第 1 波已合併的實作，相依圖形同虛設。

因此 INV-13 的兩個前提（專案設定 `baseRef: "head"` **且** 主 session 已 checkout
到單位分支）確實缺一不可，`spec/05` §2.2 的一次性檢查與徵詢代寫程序、
`references/dispatch.md` 規則 6、README「執行 Build 前」一節**全部維持**。

`research/07` Test B 與 `research/08` 的附條件結論至此結案：前者的條件限定成立，
後者證實的可持久化性正是本設定得以一次寫入、長期生效的前提。

## 5. 替代方案（未採用，僅記錄）

理論上可以完全不依賴這個設定：不用 `isolation: "worktree"`，改由主 session 自行
`git worktree add <path> flow/<unit>` 建立，再派一般子代理並在派工 prompt 中要求它
先 `cd <path>`——每個子代理有獨立的 Bash session，`cd` 互不干擾。代價是放棄平台
管理的 worktree 生命週期與完成通知回傳的 `worktreePath`／`worktreeBranch`，並且
`references/dispatch.md` 規則 7–10 與 INV-3 的續談語意都要重寫。既有設計只需使用者
同意寫入一行設定，成本明顯較低，故不改。

## 6. 未實測項目

| 項目 | 原因 |
|---|---|
| `baseRef` 的其他合法值（除 `"fresh"`／`"head"` 外） | 官方文件只記載這兩個值，未記載是否還有其他 |
| 遠端預設分支不是 `main` 時的行為 | 判準相同（是否等於當下 HEAD），換名稱不影響結論 |
| 使用者拒絕寫入設定時的降級路徑 | 依 `spec/05` §2.2 設計上直接停止、不進 Build，無降級行為可測 |
