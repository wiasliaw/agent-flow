# Dev 迴圈平台假設實測：SendMessage 續談與 Worktree 分岔基準

調查目的：驗證 agent-flow Dev phase 設計依賴的兩個平台假設——(A) 審查退回時能否用 `SendMessage` 續談「同一個」已完成的 `isolation: worktree` 子代理，worktree 與 context 是否保留；(B) `git worktree`（子代理 `isolation: worktree` 或 headless `--worktree`）的分岔基準是否等於「orchestrator 發起 session 當下 checkout 的分支」。這兩項是 `research/06-experiments-hooks-worktree.md` 「待實測」清單留下的空白：該份報告已證實「用 Agent tool **重新派工**（新的一次 Agent tool 呼叫）每次都拿到全新 worktree」，但未測「續談已完成的同一個子代理」是否有不同行為。

背景（`research/02-orchestration.md` §2.4）：子代理完成後會拿到 **agent ID**，可用 `SendMessage` 對已完成的子代理續談（自動在背景恢復），前提是該名稱仍指向同一個 agent。

---

## 環境與紀律

本次實驗分兩部分，紀律不同：

- **Test A**：在本 session 內直接做（本 session 本身即為 agent-flow 專案的一個 agent-teams 隊友，由 team-lead 派工），**不使用 /tmp**。全程只允許子代理寫自己 worktree 內的檔案；不對主 repo（`/Users/wiasliaw/Github/claude/agent-flow`）做任何 checkout／commit／非 `research/` 檔案的修改。
- **Test B**：在 `/tmp/agent-flow-exp-devloop/repo` 下用全新 local repo 測試，headless（`claude -p`）執行，事後整個 `/tmp/agent-flow-exp-devloop` 已刪除。

**環境限制（Test A 特有）**：本 session 本身是 team-lead 底下的一個 agent-teams 隊友（teammate）。派工時嘗試依原計畫帶 `name: "exp-wt-child"` 呼叫 Agent tool，被系統直接拒絕：

```
Teammates cannot spawn other teammates — the team roster is flat. To spawn a subagent instead, omit the `name` parameter.
```

這是巢狀被擋的一種形式，但**不是**「完全測不出」——改成不帶 `name` 參數即可正常派生子代理（拿到 `agentId`，可用該 ID 做 `SendMessage` 續談）。以下記錄的是「省略 `name`」這條路徑的實測結果；「帶 `name` 参数」在 agent-teams 隊友身份下的巢狀限制本身已是一項有效發現，見下方判定。

---

## Test A：SendMessage 續談 + isolation: worktree

**Step 1（第一輪）**：用 Agent tool 派生子代理（`isolation: worktree`、`model: haiku`、`subagent_type: general-purpose`，省略 `name`），指示執行 `pwd`、`git branch --show-current`，並在工作目錄寫入 `scratch-proof.txt`（內容 `turn1`，不 commit）。

**第一輪逐字回報**：
```
pwd output:
/Users/wiasliaw/Github/claude/agent-flow/.claude/worktrees/agent-aabf4335508ce27be

git branch --show-current output:
worktree-agent-aabf4335508ce27be

File written: scratch-proof.txt has been created in the current working directory with the exact content `turn1`
```
工具結果另外附帶：`agentId: aabf4335508ce27be`、`worktreePath: /Users/wiasliaw/Github/claude/agent-flow/.claude/worktrees/agent-aabf4335508ce27be`、`worktreeBranch: worktree-agent-aabf4335508ce27be`、`duration_ms: 10070`（同步完成，非背景等待）。

**Step 2（子代理閒置期間，獨立於子代理自報的檔案系統直接檢查）**：在等待續談結果期間，直接對主 repo 執行：
```
git -C /Users/wiasliaw/Github/claude/agent-flow worktree list
```
輸出：
```
/Users/wiasliaw/Github/claude/agent-flow                                           4344ef1 [main]
/Users/wiasliaw/Github/claude/agent-flow/.claude/worktrees/agent-aabf4335508ce27be 4344ef1 [worktree-agent-aabf4335508ce27be]
```
（無 `locked` 標記——與 `research/06` §4(c) 一致：`isolation: worktree` 產生的 worktree 執行完不殘留鎖檔，鎖僅存在執行期間；但這裡是「有變更」的 worktree，故未被自動清除，與該報告「有變更保留、無變更清除」的結論吻合。）

直接讀取該路徑下的檔案：`scratch-proof.txt` 存在，內容為 `turn1`——證實子代理閒置期間 dirty worktree 確實原封不動留在磁碟上，**這項判定不依賴子代理自身的回報，而是外部直接驗證**。

**Step 3（第二輪續談）**：用 `SendMessage` 對 `to: "aabf4335508ce27be"` 續談，指示再次回報 `pwd`、`git branch --show-current`，並檢查 `scratch-proof.txt` 是否存在（**明令**：若不存在不得建立）。

`SendMessage` 呼叫本身立即回傳的是投遞確認，不含實際回覆內容：
```json
{"success":true,"message":"Resuming agent aabf433","resumedAgentId":"aabf4335508ce27be","pin":{"id":"aabf4335508ce27be","name":"aabf4335508ce27be","ref":"75924c"}}
```

**關鍵發現（通知路由）**：本 session（子代理，發起續談的一方）在送出後**等待超過 5 分鐘**都沒有收到完成通知，即使該子代理實際上約 20 秒後就已完成續談（依 team-lead 回報的 transcript 時間戳）。完成通知**沒有**送回發起 `SendMessage` 的這個子代理，而是**直接送到了主 session（team-lead）**。本次是由 team-lead 從其收到的通知中取出結果，再用 teammate 訊息轉交給我，我才拿到第二輪的逐字內容。

**第二輪逐字結果**（team-lead 轉交，取自該 agent transcript 最後一則 assistant 訊息）：
```
pwd output:
/Users/wiasliaw/Github/claude/agent-flow/.claude/worktrees/agent-aabf4335508ce27be

git branch --show-current output:
worktree-agent-aabf4335508ce27be

scratch-proof.txt: EXISTS
Content: turn1
```

**判定**：
- 兩輪 `pwd` **完全相同**（同一絕對路徑）。
- 兩輪 `git branch --show-current` **完全相同**。
- `scratch-proof.txt` 在第二輪「不得建立」的明令下仍回報 **EXISTS**、內容為第一輪寫入的 `turn1`，且此結果與 Step 2 的外部檔案系統直接檢查一致——不是子代理憑空宣稱，是可獨立驗證的事實。

**結論【證實】**：用 `SendMessage` 續談一個「已完成、仍指向同一 agent」的 `isolation: worktree` 子代理，worktree 路徑、分支、以及該 worktree 內的未 commit 變更（context）**完整保留**，不會像重新呼叫 Agent tool 那樣拿到全新 worktree。這與 `research/06` 證實的「**重新派工**（新的一次 Agent tool 呼叫，即使同名）永遠拿到全新 worktree」並不矛盾——兩者是不同機制：「續談同一個已完成 agent」（SendMessage 對已知 agentId）與「重新派工」（再次呼叫 Agent tool）在 worktree 生命週期上行為完全不同，前者延續，後者總是全新。

**額外發現【證實，文件未記載】**：完成通知的路由對象是**主 session**，不是**發起 SendMessage 續談的那個 agent**。若子代理自己對另一個子代理發起 `SendMessage` 續談並等待結果，它可能永遠等不到通知（除非有第三方如主 session 把結果轉交），只能靠自己反覆檢查（如直接讀檔案）或由外部協調者告知。這對「由 orchestrator 主 session 親自做 SendMessage 續談」沒有影響（因為 orchestrator 本身就是通知的目的地），但若設計成「某個子代理（而非主 session）負責串接 Dev 迴圈並自己發 SendMessage 續談前一輪 worker」，**會拿不到完成通知**，必須改由主 session 代為發起續談，或子代理自行輪詢工作產物（例如檔案是否更新）而非依賴通知機制。

**未能測出**：帶 `name` 參數（讓子代理具名、可用名稱而非 raw agentId 續談）在「本 session 本身是 agent-teams 隊友」的情境下被系統擋下（「Teammates cannot spawn other teammates」）。這是否也發生在「主 session 本身不是隊友（一般互動或 headless 模式）」的情境下，本次未測——`research/02-orchestration.md` §3.3 已知 agent-teams 啟用後有「沒有巢狀團隊」的限制，此處實測到的擋下訊息與該限制吻合，但無法排除是否為 agent-teams 特有限制，還是所有子代理巢狀 spawn 具名子代理都有此限制。若 agent-flow 的 Dev phase orchestrator 本身**不是**跑在 agent-teams 隊友身份下（多數情況下應該不是），此限制大機率不適用；但若 orchestrator 本身也是被更上層派出的具名子代理／隊友，需要另外驗證。

---

## Test B：Worktree 分岔基準

**Step 1**：`/tmp/agent-flow-exp-devloop/repo` 建 local repo，`main` 上 `commit A`（`fileA.txt`），另開 `flow/unit` 分支加 `commit B`（`fileB.txt`），保持 checkout 在 `flow/unit`。

```
--- log on flow/unit ---
34cf01d commit B
cc60e7e commit A
--- current branch ---
flow/unit
```

**Step 2**：在此狀態下（checkout 在 `flow/unit`）用 headless 建立 worktree `tkt1`：
```bash
claude -p --worktree tkt1 --model claude-haiku-4-5-20251001 --output-format text \
  "Run: git branch --show-current ; git log --oneline -5 ; pwd. Print outputs verbatim."
```
逐字輸出：
```
worktree-tkt1
34cf01d commit B
cc60e7e commit A
/private/tmp/agent-flow-devloop/repo/.claude/worktrees/tkt1
```
（EXIT=0）——**含 commit B**，分岔自 `flow/unit` 的 tip。

**Step 3（對照組）**：把 repo checkout 回 `main`：
```
--- current branch ---
main
--- log on main ---
cc60e7e commit A
```
再用 headless 建立 worktree `tkt2`：
```bash
claude -p --worktree tkt2 --model claude-haiku-4-5-20251001 --output-format text \
  "Run: git branch --show-current ; git log --oneline -5 ; pwd. Print outputs verbatim."
```
逐字輸出：
```
worktree-tkt2
cc60e7e commit A
/private/tmp/agent-flow-devloop/repo/.claude/worktrees/tkt2
```
（EXIT=0）——**不含 commit B**，只有 `commit A`。

**判定**：同一個 repo、同樣沒有變更任何設定，僅僅把「發起當下的 checkout」從 `flow/unit` 換成 `main`，worktree 的分岔起點就跟著換——`tkt1` 分岔自 `flow/unit`（含 commit B），`tkt2` 分岔自 `main`（不含 commit B）。

**環境限制（需明確記錄的替代解釋）**：`git remote -v` 確認此測試 repo **沒有設定 remote**：
```
--- remotes ---
（空）
--- config ---
(no worktree config)
```
`research/02-orchestration.md` §4.4 記載官方預設 `worktree.baseRef` 是 `"fresh"`：「從遠端預設分支（通常是 main）分出」。本測試 repo 沒有遠端，因此無法排除「`fresh` 在沒有 remote 可用時，退回到目前 local HEAD（= 當下 checkout 的分支）」這個替代解釋，與「`baseRef` 本身的真正語意就是『當下 checkout』」是兩種不同的机制成因，但**外部可觀察行為相同**。`research/06-experiments-hooks-worktree.md` §3 的既有實驗（兩個平行 headless session，皆基於同一台 repo 的 `main` HEAD 分岔）與本次結果互相佐證：在沒有 remote 的本機 repo 情境下，worktree 分岔點穩定跟隨「發起當下的本地 checkout」。

**結論【證實，附條件】**：在**沒有設定 remote 的 local repo**（agent-flow 若在 CI 或本機開發環境下對尚未 push 的 spec/ticket 分支跑 Dev phase worktree，很可能正是這種情境）下，worktree 的分岔基準確實跟隨「orchestrator 發起 session 當下 checkout 的分支」，不是固定分岔自某個叫 `main` 的分支名稔。**已補測（`research/12`，2026-09-14）**：有 remote 且 `origin/HEAD` 指向 `main` 時，預設 `"fresh"` **確實改從遠端預設分支分出**，worktree 拿不到單位分支上的 commit；本段原本的「未能測出」至此結案。也就是說，本測試觀察到的「跟隨當下 checkout」是 `"fresh"` 找不到遠端預設分支時退回本地 HEAD 的副作用，不是 `baseRef` 的真正語意。真實專案幾乎都有 remote，因此「多張票證共同基於同一個未 push 的單位分支」**必須**明確設定 `worktree.baseRef: "head"`，不能靠「不設定、指望它自動抓到當下分支」。

---

## 總結：每項一行結論

**A（SendMessage 續談 worktree 子代理）**：【證實】用 `SendMessage` 續談已完成、仍指向同一 `agentId` 的 `isolation: worktree` 子代理，worktree 路徑、分支、未 commit 的變更（context）完整保留，不會像重新呼叫 Agent tool 那樣拿到全新 worktree；但完成通知只送回**主 session**、不會送回發起續談的子代理本身，這條路由規則需要一併寫進設計。

**B（worktree 分岔基準）**：【證實，附條件：僅驗證於無 remote 的 local repo；有 remote 情境已由 `research/12` 補測結案——預設 `"fresh"` **會**改從遠端預設分支分出，故 `baseRef: "head"` 為必要設定】worktree 分岔點跟隨「orchestrator 發起當下 checkout 的分支」而非固定分岔自 `main`。有 remote 時**不**如此（`research/12`），故 agent-flow 一律明確設定 `worktree.baseRef: "head"`，不依賴預設行為。

---

## 對設計的裁決意義

**(A) 對 Dev 退回機制的裁決**：設計**可以**寫成「審查退回時用 `SendMessage` 續談同一個 dev-worker」——worktree 與 context 確實會保留，不需要改成「全新 worker＋交接前次 worktree 分支與 diff 摘要」这种更重的機制。但有一個必須寫進設計的限制：**發起續談的角色必須是主 session（orchestrator）本身**，不能是「某個中介子代理代替 orchestrator 去 SendMessage 續談 dev-worker」——因為完成通知只回主 session，中介子代理會收不到通知、卡在等待。若 agent-flow 的 Review phase 是由主 session 直接讀取子代理審查結果、再親自 SendMessage 續談對應的 dev-worker，這條路徑没有問題；若 Review phase 本身也是一個獨立子代理、由它去 SendMessage 續談 dev-worker，需要額外設計「結果如何從主 session 轉交回 Review 子代理」的機制（例如寫入檔案讓 Review 子代理輪詢讀取，而非依賴通知），否則會卡住。

**(B) 對設計是否需要補「orchestrator 需 checkout 到單位分支」的裁決**：**需要補上**，且要比原本設想的更明確——不能只是「建議 checkout 到正確分支」，而應直接規定 Dev phase 產生 worktree 前，明確設定 `worktree.baseRef: "head"`（而非依賴預設 `"fresh"` 在特定情境下恰好等同於當下 checkout 的行為）。理由：本次實測雖證實無 remote 情境下分岔基準確實跟隨當下 checkout，但這可能只是「`fresh` 在缺乏 remote 時的退回行為」，並非該設定本身穩定保證的語意；一旦 agent-flow 部署環境有 remote（例如票證分支已 push），依賴「不設定、指望它自動跟上當下分支」的做法可能在有 remote 的環境下失效，變成所有票證都分岔自 remote 的 `main`、而非 Spec/Ticket 的工作分支。因此設計文件應把「Dev phase 建立 worktree 前，orchestrator 需 checkout 到單位分支，且明確設定 `baseRef: head`」列為**必要**條件，而不是可選建議。
