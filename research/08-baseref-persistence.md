# `worktree.baseRef` 持久化查證

調查目的：裁定 `worktree.baseRef`（"fresh"／"head"）是否為可持久化寫入專案
`.claude/settings.json` 的欄位，藉此解決 `DESIGN.md` §7／Q23（假設可持久化）
與 `spec/11-dev.md` 待對齊 #1（懷疑不可持久化、改採替代規格）之間的矛盾。

背景（已讀）：`research/02-orchestration.md` §4.4 記載官方預設 `baseRef` 為
`"fresh"`，設為 `"head"` 則從目前本地 `HEAD` 分出，但未記載存放位置；
`research/07-experiments-dev-loop.md` Test B 證實無 remote 情境下分岔跟隨當下
checkout，但未測設定持久化本身。

## 查證方法

**步驟 1（官方文件）**：直接命中，查到即停，未執行步驟 2、3（本機 schema
查證、`/tmp` 實驗）。

## 查證過程與逐字記錄

### (1) `code.claude.com/docs/en/worktrees`（WebFetch）

頁面「Customize worktree creation → Choose the base branch」小節原文（逐字）：

> New worktrees branch from the repository's default branch, so most sessions
> don't need this setting. Set `worktree.baseRef` in
> [settings](/docs/en/settings-reference#worktree) to branch from your
> current work instead. The setting accepts two values:
>
> * `"fresh"` (default): branch from the repository's default branch on the
>   remote, usually `main`, so the worktree starts from a clean tree matching
>   the remote.
> * `"head"`: branch from your current local `HEAD`, so the worktree carries
>   your unpushed commits and feature-branch state. Use this when isolating
>   subagents that need to operate on in-progress work. Inside a worktree,
>   `"head"` resolves to that worktree's `HEAD`, not the main checkout's.
>
> You can't set `worktree.baseRef` to a branch name. To start a worktree from
> a specific existing branch, [create it with git directly].
>
> This example makes every new worktree branch from your current work:
>
> ```json
> {
>   "worktree": {
>     "baseRef": "head"
>   }
> }
> ```

該頁同時明確指出「Subagent worktrees use the same base branch as
`--worktree`」——即 `isolation: worktree` 子代理與 `--worktree` CLI 旗標套用
同一套 `baseRef` 邏輯，沒有子代理專屬的另一套機制。

檔名標籤明示這是寫進 `settings.json`（欄位路徑 `worktree.baseRef`），並連到
`settings-reference#worktree` 頁面。

### (2) `code.claude.com/docs/en/settings-reference`（curl 下載 HTML 後 grep 原始
JSX/文字節點，因 WebFetch 對此頁做摘要時把 `worktree` 章節截斷）

指令與輸出（節錄，英文原文）：

```
$ curl -s 'https://code.claude.com/docs/en/settings-reference' -A "Mozilla/5.0" -o /tmp/settings-reference.html
$ grep -o '"worktree[^"]*"' /tmp/settings-reference.html | sort -u
"worktree.baseRef"
"worktree.bgIsolation"
"worktree.sparsePaths"
"worktree.symlinkDirectories"
```

`worktree.baseRef` 條目完整內容（逐字）：

> Choose which ref new worktrees branch from. `"fresh"` branches from
> `origin/<default-branch>` for a clean tree matching the remote; `"head"`
> branches from your current local `HEAD`, so unpushed commits and
> feature-branch state are present in the worktree.
>
> * **Scope**: `Any file`
> * **Type**: string, one of:
>   * `"fresh"`: new worktrees branch from `origin/<default-branch>`
>   * `"head"`: new worktrees branch from your current local `HEAD`, including
>     unpushed commits
> * **Default**: `"fresh"`

程式碼範例的檔名標籤（code-block header）明示為 `settings.json`。

「All settings」章節開頭定義 `Scope` 欄位的四種可能值（逐字）：

> Every key below links to its entry. Scope lists the [files] it can go in:
> `User` is `~/.claude/settings.json`, `Project` is `.claude/settings.json`,
> `Local` is `.claude/settings.local.json`, and `Managed` is what your
> organization deploys. `Any file` means all four, and `Global config` means
> `~/.claude.json`.

`worktree.baseRef` 的 Scope 標示為 `Any file`，依上述定義即：`User`
（`~/.claude/settings.json`）、`Project`（`.claude/settings.json`）、`Local`
（`.claude/settings.local.json`）、`Managed` 四種檔案皆可寫入，`Project` 正是
`DESIGN.md`／`spec/11-dev.md` 討論的專案層級 `.claude/settings.json`。

### 附帶發現：與「plugin 根目錄 settings.json」的區分

`spec/11-dev.md` 待對齊 #1 的疑慮源自把 `DESIGN.md` §7 提到的「plugin 根目錄
`settings.json` 只支援 `agent` 與 `subagentStatusLine` 兩個 key」誤讀成對
「一般專案 `.claude/settings.json`」也成立的限制。重讀 `research/01-plugin-mechanism.md`
第 49 行，原文已明確區分這是**兩個不同檔案**：

> `settings.json`（plugin 根目錄檔案，非 `plugin.json` 欄位）| — | 否 |
> 啟用 plugin 時套用的預設 settings，目前只支援 `agent` 與
> `subagentStatusLine` 兩個 key

這個「只支援兩個 key」的限制**只套用在 plugin 套件本身根目錄下、隨 plugin
發布的那份 `settings.json`**（plugin 作者寫的預設設定），與 Claude Code 一般
設定階層（User／Project／Local／Managed）中的專案級 `.claude/settings.json`
是完全不同的檔案、不同的 schema。`DESIGN.md` §7 原文其實已經正確做出這個
區分（「這是 plugin 機制本身的限制，不是設計選擇」），`spec/11-dev.md` 待對齊
#1 的懷疑是對 `DESIGN.md` 原意的誤讀，不是 `DESIGN.md` 本身有錯。

### 附帶發現：`baseRef` 不是 Agent tool 的呼叫參數

`spec/11-dev.md` 第 56、64、71 行的替代規格把 `baseRef: head` 描述成「每次
Agent tool 呼叫時當次指定的參數」。查證本 session 可用的 `Agent` tool
schema，其 `properties` 只有 `description`、`isolation`（僅
`"worktree"`／`"remote"`）、`mode`、`model`、`name`、`prompt`、
`subagent_type`、`team_name`，**沒有 `baseRef` 或 `worktree` 參數**。這與官方
文件的機制描述一致：`baseRef` 是**建立 worktree 時讀取的全域/專案設定**，不是
逐次呼叫帶入的參數；`isolation: worktree` 子代理與 `--worktree` 用的是同一套
設定讀取邏輯（見上方 (1) 引文）。

## 結論

【證實可持久化（附欄位路徑）】

`worktree.baseRef` 是可持久化寫入專案 `.claude/settings.json` 的欄位，欄位
路徑與格式為：

```json
{
  "worktree": {
    "baseRef": "head"
  }
}
```

型別為字串，僅接受 `"fresh"`（預設）或 `"head"` 兩個值，Scope 為 `Any file`
（`User`／`Project`／`Local`／`Managed` 四種 settings 檔案皆可設定，
`Project` 即 `.claude/settings.json`）。此設定套用範圍是「該 session 之後
建立的所有 worktree」（`--worktree` CLI 與 `isolation: worktree` 子代理共用
同一套邏輯），不是逐次 Agent tool 呼叫時傳入的參數——目前 Agent tool 的
schema 也確實沒有對應參數可傳。

## 對 spec 的裁決意義

`spec/11-dev.md` 待對齊 #1 應**依 `DESIGN.md`／Q23 字面裁決**，不採用該檔案
自行推論的替代規格：

1. **Q23「檢查後徵同意寫入」應照字面實作**——`orchestrate` 啟動時檢查專案
   `.claude/settings.json` 是否已有 `worktree.baseRef: "head"`，缺少則提示
   使用者、徵求同意後代寫這個具體欄位（`{"worktree": {"baseRef": "head"}}`），
   而不是把「檢查」重新解讀為「確認 orchestrator 已 checkout 到單位分支」這種
   行為紀律。
2. **但「checkout 到單位分支」這個前置動作仍然必要，且與設定 `baseRef` 是
   互補而非互斥的兩件事**：`baseRef: "head"` 的語意是「從目前本地 `HEAD`
   分出」，若 orchestrator 當下沒有 checkout 在 `flow/<unit-name>`，即使
   `baseRef` 已設為 `"head"`，新 worktree 依然會從錯誤的分支分岔。因此
   `spec/11-dev.md` 第 57、71 行「orchestrator 必須先 checkout 到單位分支」
   的要求應保留，但應改寫為「這是 `baseRef: head` 生效的必要前提，而非取代
   設定該欄位」，兩者需並存。
3. **需修正一處措辭**：`spec/11-dev.md` 第 64、71 行把 `worktree.baseRef:
   "head"` 描述成「該次 Agent tool 呼叫」的參數，這與官方機制不符——應改為
   「Dev phase 開始前，`orchestrate` 一次性確認並視需要代寫專案
   `.claude/settings.json` 的 `worktree.baseRef: "head"`（一次設定，套用到
   本 session 之後所有 `dev-worker` 呼叫），呼叫 `dev-worker` 本身不需要、
   也無法傳遞 `baseRef` 參數」。
4. `DESIGN.md` §7 原文（「plugin 根目錄 `settings.json` 只支援 `agent` 與
   `subagentStatusLine`」與「`orchestrate` 檢查專案層級 `.claude/settings.json`」
   两句）**維持成立、不需修改**——兩者本來就指涉不同檔案，`spec/11-dev.md`
   待對齊 #1 記載的落差是對 `DESIGN.md` 的誤讀，應予以撤銷。

## 參考來源

- [Run parallel sessions with worktrees — Choose the base branch](https://code.claude.com/docs/en/worktrees#choose-the-base-branch)
- [Claude Code settings reference — `worktree.baseRef`](https://code.claude.com/docs/en/settings-reference#worktree-baseref)
- [Claude Code settings reference — All settings（Scope 定義）](https://code.claude.com/docs/en/settings-reference#all-settings)
