# 02｜狀態外部化規格：`.agent-flow/`、`state.json`、`decisions.md`、票證檔案

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 一、已定（來源與依據）

- **Q6**：`.agent-flow/` 下按工作單位分目錄，Wrap 時歸檔到 `archive/`。
- **Q7**：spec 需求用 EARS 格式＋編號，票證與測試用編號回鏈。
- **Q8**：spec 為 delta 為主＋主 spec 合併（歸檔時）。
- **Q9**：Ticket 階段產出**可執行的失敗測試**（真測試碼，非骨架）。
- **Q10**：Dev 階段實作者不可改 Ticket 產出的測試，錯了走 Q5 上報流程。
- **Q18**：Prototype 的碼與證據都進單位目錄（未採建議選項，需配套清理紀律，見 DESIGN.md 第 8 節，本檔只定位置）。
- **Q21**：狀態檔格式「照推薦」——每個工作單位一個 `state.json`，含 schema 版本欄位。
- **Q22**：進行中工作單位目錄名為 `changes/`。
- **Q24**：主 spec 依領域分域，`.agent-flow/specs/<domain>/spec.md`。
- **Q28**：工作單位命名 `YYYY-MM-DD-slug`。
- **Q30**：state.json 完整 schema「照提案（建議）」——DESIGN.md 第 6 節給出的 JSON 範例即該提案，本檔逐欄位精確化。
- **Q31**：decisions.md 的 ESC 留痕模板「照提案（建議）」——DESIGN.md 第 4 節給出的模板即該提案，本檔逐欄位精確化並定義與 state.json 的同步規則。
- **Q32**：票證相依記法「票證 frontmatter 為準，state.json 同步（建議）」。
- **DESIGN.md 第 3.5、3.6 節**：票證生命週期（Ticket phase 寫出＋測試紅燈 → Ticket 承諾點核准 → Dev phase 依相依圖排入 → 相依滿足派工 → `dev-worker` 實作轉綠 → `dev-reviewer` 審查 → 通過合併進單位分支）——本檔票證 `status` 枚舉的推導依據。
- **DESIGN.md 第 4 節**：品質迴圈根因二分流（純實作問題／根因在已核准產物）、輪數上限（標準 3、Review 5）——本檔 `qualityLoops.status` 與 `escalations.rootCause` 枚舉的推導依據。
- **DESIGN.md 第 6、7 節**：`.agent-flow/` 完整目錄樹範例、`state.json` 範例、`branch` 欄位語意。
- **DESIGN.md 第 2 節「Internal skills」表**：`state-management`「唯一寫入 state.json 者」為 `orchestrate`——本檔中「哪個角色寫入」規則的依據。
- **S3**：Wrap 上報沿用本檔 ESC 格式與 `escalations` 陣列，`phase` 允許 `"wrap"`。
- **S4**：`escalations[]` 新增 `targetArtifact` 欄位（對 Q30 定案 schema 的擴充，已登記
  `spec/README.md`「DESIGN.md 回寫記錄」§6）。
- **S5**：票證 `status` 枚舉 `draft`／`approved`／`in_dev`／`in_review`／`merged`／`escalated`
  照本檔提案定案。
- **S6**：`escalated` 票證裁決後若判定「測試本身需修正」，重置為 `draft` 照本檔推論定案。

---

## 二、規格本文

### 2.1 `.agent-flow/` 目錄規格

```
.agent-flow/
├── specs/                                # 主 spec（已合併、反映現況），Q24
│   └── <domain>/
│       └── spec.md                       # 依領域分域，切分粒度由專案自訂
├── changes/                              # 進行中的工作單位，Q22
│   └── <unit-name>/                      # <unit-name> = <YYYY-MM-DD>-<slug>，Q28
│       ├── state.json                    # §2.2
│       ├── discuss.md                    # Discuss phase 產物
│       ├── explore.md                    # Explore phase 產物
│       ├── prototype.md                  # Prototype phase 產物（問題/做法/證據/結論）
│       ├── prototype/                    # 實驗碼本身，進版控，Q18
│       │   └── ...
│       ├── spec-delta.md                 # Spec phase 產物，ADDED/MODIFIED/REMOVED，Q8
│       ├── tickets/
│       │   └── <ticket-id>.md            # §2.4
│       ├── review.md                     # Review phase 產物
│       ├── wrap.md                       # Wrap phase 產物（逐動作執行與驗證留痕）
│       └── decisions.md                  # §2.3，上報裁決留痕
└── archive/                              # Wrap 後歸檔，Q6
    └── <date>-<unit-name>/               # changes/<unit-name>/ 的完整快照（含 state.json、decisions.md 等全部檔案）
```

**檔案建立時機與生命週期**（逐檔）：

| 檔案／目錄 | 建立時機（角色／phase） | 生命週期 |
|---|---|---|
| `state.json` | Discuss phase 啟動時由 `orchestrate` 建立骨架 | 全程由 `orchestrate` 持續更新（見 §2.2 說明），Wrap 歸檔時隨資料夾整包移動，內容不再變更 |
| `discuss.md` | 主 session（Discuss 對話環節，DESIGN.md 第 2 節）撰寫 | Discuss 承諾點核准後不再修改（已核准產物） |
| `explore.md` | `explorer` 撰寫 | Explore 品質迴圈通過後不再修改 |
| `prototype.md`、`prototype/` | `prototyper` 撰寫 | Prototype 品質迴圈通過後不再修改；若 Explore 無未解決技術疑問，本 phase 略過，這兩項不存在（`state.json` 對應 `status: "skipped"`） |
| `spec-delta.md` | `spec-writer` 撰寫 | Spec 承諾點核准後成為已核准產物（Q5/Q10 適用），Wrap 時合併進 `specs/<domain>/spec.md` 後留在 `changes/` 快照中隨歸檔保留（不刪除，作為歷史記錄） |
| `tickets/<ticket-id>.md` | `ticket-writer` 撰寫（含建立對應的可執行失敗測試，測試檔本身在專案原始碼路徑下，非 `.agent-flow/` 內） | Ticket 承諾點核准後成為已核准產物；`status` 欄位持續由 `orchestrate` 依 Dev phase 進度更新至 `merged` |
| `review.md` | Review phase 的 `review-triage` 產出 | Review 承諾點核准後不再修改 |
| `wrap.md` | `wrap-executor` 撰寫、`wrap-verifier` 附加驗證結果 | Wrap 完成即歸檔，內容為最終版本 |
| `decisions.md` | 首次發生上報裁決時由 `orchestrate` 建立 | 持續追加 ESC 條目，Wrap 歸檔時保留完整歷史 |

`specs/<domain>/spec.md` 只在 Wrap phase 由 `wrap-executor` 寫入（合併 delta），其餘 phase 唯讀（`explorer`／`spec-writer` 等角色讀取以了解現況，不修改）。

### 2.2 `state.json` 完整 schema

**寫入權責**：依 DESIGN.md 第 2 節 internal skills 表，`state.json` **只由 `orchestrate` 寫入**；任何角色子代理需要讀取工作單位進度時唯讀讀取，不直接寫入——即使是單獨呼叫某個 phase skill（不經 `orchestrate`）的情境，寫入 `state.json` 的動作仍須由當下驅動該 phase 的 session（此時該 session本身即扮演最小化的 orchestrate 角色，見各 phase skill 規格「單獨使用時的行為」一節，spec/06–13）执行，不得委派給子代理。

**頂層欄位表**：

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `schemaVersion` | integer | 是 | 目前恆為 `1`；未來 schema 變更時遞增，供 `orchestrate` 讀取時判斷是否需要遷移邏輯 |
| `unit` | string | 是 | 工作單位名稱，格式 `<YYYY-MM-DD>-<slug>`（Q28），與所在目錄名一致 |
| `createdAt` | string | 是 | ISO 8601 時間戳（含時區偏移），工作單位建立時間，之後不變 |
| `updatedAt` | string | 是 | ISO 8601 時間戳，每次 `orchestrate` 寫入本檔時更新為當下時間 |
| `currentPhase` | string enum | 是 | 目前所在 phase，取值為八個 phase 名之一：`"discuss"` \| `"explore"` \| `"prototype"` \| `"spec"` \| `"ticket"` \| `"dev"` \| `"review"` \| `"wrap"` |
| `phases` | object | 是 | 見下方「`phases` 物件」 |
| `gates` | object | 是 | 見下方「`gates` 物件」 |
| `qualityLoops` | object | 是（可為空物件 `{}`） | 見下方「`qualityLoops` 物件」 |
| `tickets` | object | 是（可為空物件 `{}`，Ticket phase 之前恆為空） | 見下方「`tickets` 物件」 |
| `escalations` | array | 是（可為空陣列） | 見下方「`escalations` 陣列」 |
| `branch` | object | 是 | 見下方「`branch` 物件」 |

**`phases` 物件**：key 固定為八個 phase 名（與 `currentPhase` 同一組枚舉），每個 value 為：

| 子欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `status` | string enum | 是 | `"pending"`（尚未開始）\| `"in_progress"`（正在進行，含品質迴圈進行中）\| `"done"`（品質迴圈通過，且若為承諾點 phase 則已通過使用者核准）\| `"skipped"`（明確略過，目前僅 `prototype` 有實際發生情境） |
| `artifact` | string \| null | 否，`status: "done"` 時應填 | 該 phase 主要產物的相對路徑（相對於 `changes/<unit>/`），例如 `"discuss.md"`、`"tickets/"`（Ticket phase 為目錄） |
| `reason` | string | 否，僅 `status: "skipped"` 時填 | 略過原因，例如 `"no open technical question"` |

**枚舉推導說明**：`pending`／`in_progress`／`done`／`skipped` 四值直接取自 DESIGN.md 第 6 節範例（`discuss`/`explore`/`spec`/`ticket` 為 `"done"`、`dev` 為 `"in_progress"`、`review`/`wrap` 為 `"pending"`、`prototype` 為 `"skipped"`），四者互斥且窮盡涵蓋一個 phase 從未開始到完成的所有狀態，不另外新增「escalated」等狀態於 `phases.status`——上報裁決的狀態由 `qualityLoops.<key>.status`（見下）與 `escalations` 陣列表達，`phases.<phase>.status` 在上報期間維持 `"in_progress"`（該 phase 仍未結束，只是被卡住等待使用者裁決）。

**`gates` 物件**：key 固定為四個承諾點 phase 名——`"discuss"`、`"spec"`、`"ticket"`、`"review"`（Q3；不含 `explore`／`prototype`／`dev`／`wrap` 因為這四個 phase 依 Q3 不是承諾點，不需要核准欄位）。每個 value 為：

| 子欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `approvedAt` | string \| null | 是 | ISO 8601 時間戳；尚未核准為 `null` |
| `approvedBy` | string \| null | 是 | 目前恆為 `"user"`（單使用者情境）或 `null`（尚未核准） |

**`qualityLoops` 物件**：key 命名規則（Q32 相依記法之外的既有設計，DESIGN.md 第 6 節範例已示範）——一般 phase（Discuss／Explore／Prototype／Spec／Ticket／Review）用 phase 名本身作 key（如 `"spec"`）；Dev phase 逐票證各自一個 key，格式 `"dev:<ticket-id>"`（如 `"dev:TICKET-002"`）。每個 value 為：

| 子欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `rounds` | integer | 是 | 目前已進行的退回輪數，初始派工＋審查算第 1 輪，每次退回原作者重做則遞增 |
| `maxRounds` | integer | 是 | 該迴圈上限：一般 phase 與 Dev 逐票證固定 `3`（Q4 標準迴圈）；Review 固定 `5`（Q29 重型迴圈） |
| `status` | string enum | 是 | `"in_progress"`（迴圈進行中，`rounds` < `maxRounds`）\| `"passed"`（審查通過）\| `"escalated"`（已上報使用者裁決，等待處理） |

**`status` 枚舉推導說明**：`in_progress`／`passed` 直接取自 DESIGN.md 第 6 節範例。`escalated` 是依 Q4／Q5 機械推導：品質迴圈只有兩種終止方式——審查通過（`passed`），或觸發上報（Q4 超過輪數上限、或 Q5 根因在已核准產物，兩者皆導向「上報使用者裁決」，見下方 `escalations.rootCause` 對應）。上報後迴圈進入等待狀態，故需要一個與 `in_progress`（仍在自動重試中）、`passed`（已完成）都不同的第三態，`escalated` 是此狀態的直接、無其他合理候選的命名。

**`tickets` 物件**：key 為票證 id（如 `"TICKET-001"`），value 為票證狀態在 `state.json` 側的鏡像（權威來源是票證 frontmatter，見 §2.4，Q32）：

| 子欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `status` | string enum | 是 | 與票證 frontmatter 的 `status` 欄位同一組枚舉，見 §2.4 |
| `dependsOn` | array\<string\> | 是（可為空陣列） | 依賴的票證 id 清單，鏡像自票證 frontmatter |
| `requirementRefs` | array\<string\> | 是（可為空陣列） | 對應的 EARS 需求編號，鏡像自票證 frontmatter |

**同步規則**：`orchestrate` 每次讀到 `tickets/<ticket-id>.md` frontmatter 異動（`ticket-writer` 新寫、或票證狀態因 Dev phase 進度改變）時，立即覆寫 `state.json` 對應欄位；`state.json` side 不接受與 frontmatter 不一致的手動修改。

**`escalations` 陣列**：每個元素為一次上報事件：

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `id` | string | 是 | 格式 `"ESC-<n>"`，`n` 為該工作單位內遞增序號，與 `decisions.md` 對應章節標題（`## ESC-<n>：...`）共用同一個 id 作為連結鍵 |
| `phase` | string | 是 | 觸發上報的 phase 名，八個 phase 名皆為合法值（含 `"wrap"`——S3 裁決：Wrap 的執行—驗證迴圈失敗上報沿用本陣列與 ESC 格式，不另訂簡化格式；`decisions.md` 模板「Phase／輪次」欄位在 `phase == "wrap"` 時填「Wrap（無輪次，執行—驗證迴圈）」取代 `<k>/<max>` 數字形式，見 §2.3） |
| `ticket` | string \| null | 是 | 若上報源自 Dev phase 某張票證，填該票證 id；否則為 `null` |
| `rootCause` | string enum | 是 | `"approved-artifact"`（根因在已核准產物，Q5）\| `"round-limit-exceeded"`（純實作問題但迴圈輪數已達上限，Q4） |
| `targetArtifact` | string enum \| null | 是（S4 新增欄位，對 Q30 定案 schema 的擴充） | `rootCause == "approved-artifact"` 時必填，指出根因指向哪個已核准產物：`"discuss"` \| `"spec"` \| `"ticket"`；`rootCause == "round-limit-exceeded"` 時為 `null`（純實作問題無「指向哪個已核准產物」的語意）。與 `spec/04-internal-skills.md` `quality-loop` 規則 7 審查者輸出契約的 `escalation.targetArtifact` 欄位語意一致，`orchestrate` 寫入 ESC 時直接取值 |
| `raisedAt` | string | 是 | ISO 8601 時間戳，上報當下寫入 |
| `resolvedAt` | string \| null | 是 | ISO 8601 時間戳；使用者裁決前為 `null` |

**`rootCause` 枚舉推導說明**：直接對應 Q5 定義的品質迴圈退回二分流——「純實作問題」由迴圈自動處理，**不**產生 escalation（不進這個陣列），只有兩種情況會真正產生一筆 escalation：(1) 根因判定為「已核准產物」，依 Q5 一律立即上報，無論輪數（`rootCause: "approved-artifact"`）；(2) 根因是純實作問題，但重試已達 `maxRounds` 上限仍未通過，依 Q4「超過上限一律上報使用者」（`rootCause: "round-limit-exceeded"`）。二者窮盡涵蓋 DESIGN.md 第 4 節定義的所有上報觸發條件。

**`branch` 物件**：

| 子欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `unit` | string | 是 | 單位分支名，格式 `"flow/<unit-name>"`（Q12） |
| `baseRef` | string | 是 | 單位分支切出時的基準分支，目前恆為 `"main"` |

### 2.3 `decisions.md` 的 ESC 留痕模板

依 Q31 採用 DESIGN.md 第 4 節提案模板，逐欄位定義：

```markdown
## ESC-<n>：<一行摘要>
- Phase／輪次：<phase>（第 <k>/<max> 輪）
- 觸發角色：<author-role> vs <reviewer-role>
- 根因分類：<純實作問題 | 根因在已核准產物：Discuss/Spec/Ticket>
- 細節：...
- 使用者裁決：...
- 裁決時間：...
```

| 欄位 | 對應 `state.json escalations[]` 欄位 | 填寫規則 |
|---|---|---|
| 標題 `ESC-<n>` | `id` | `n` 為同一工作單位內的遞增整數，兩處使用同一個值 |
| 一行摘要 | 無直接對應（人讀用） | 一句話描述問題本身 |
| Phase／輪次 | `phase`＋對應 `qualityLoops.<key>.rounds`／`maxRounds` | 例如 `dev（第 3/3 輪）` |
| 觸發角色 | 無直接對應（人讀用） | 例如 `dev-worker vs dev-reviewer` |
| 根因分類 | `rootCause` | markdown 用人讀語句（「純實作問題」／「根因在已核准產物：Spec」），`state.json` 用機器可讀枚舉（`round-limit-exceeded`／`approved-artifact`）；兩者語意一一對應，見 §2.2 `rootCause` 推導說明 |
| 細節 | 無直接對應（人讀用） | 具體描述審查退回理由、雙方分歧點 |
| 使用者裁決 | 決定 `resolvedAt` 是否被填入的觸發事件 | 使用者實際給出的裁決內容 |
| 裁決時間 | `resolvedAt` | 使用者裁決當下的 ISO 8601 時間戳，markdown 與 JSON 兩處同步寫入同一個值 |

**同步時機**：上報發生當下，`orchestrate` **同時**在 `decisions.md` 追加一個新的 `## ESC-<n>` 區塊（「使用者裁決」「裁決時間」先留空或標記「待裁決」）與在 `state.json` 的 `escalations` 陣列 push 一筆新元素（`resolvedAt: null`）；兩次寫入視為同一個原子操作的兩個部分，由 `orchestrate` 一次完成，不允許只寫其中一處。使用者給出裁決後，`orchestrate` 同樣同時回填 `decisions.md` 對應區塊的「使用者裁決」「裁決時間」欄位與 `state.json` 該筆 `escalations[].resolvedAt`。

### 2.4 票證檔案格式與 frontmatter

路徑：`.agent-flow/changes/<unit>/tickets/<ticket-id>.md`。`<ticket-id>` 格式為 `TICKET-<3 位數字流水號>`（如 `TICKET-001`），同一工作單位內遞增、不重複使用已刪除的編號。

**YAML frontmatter 欄位表**：

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `id` | string | 是 | 與檔名（去除 `.md`）一致，如 `TICKET-001` |
| `title` | string | 是 | 一行標題 |
| `status` | string enum | 是 | 見下方「`status` 枚舉」 |
| `dependsOn` | array\<string\> | 是（可為空陣列 `[]`） | 依賴的票證 id 清單；本欄位是相依關係的**權威來源**（Q32），`state.json` 的 `tickets.<id>.dependsOn` 是其鏡像 |
| `requirementRefs` | array\<string\> | 是（可為空陣列，但一般不應為空） | 對應的 EARS 需求編號（Q7），格式如 `["1.1", "1.2"]`，編號語法由 `sdd-guide` internal skill 定義（見 spec/04-internal-skills.md） |
| `testFiles` | array\<string\> | 是（可為空陣列，但 Ticket phase 完成時不應為空——Q9 要求可執行失敗測試） | 對應的測試檔案路徑，**相對於專案（consumer repo）根目錄**，不在 `.agent-flow/` 之下——測試碼本身是專案原始碼的一部分，隨 Dev phase 實作、Wrap phase 全測試綠燈檢查的對象 |

**`status` 枚舉**（依 DESIGN.md 第 3.5、3.6 節票證生命週期推導）：

| 值 | 語意 | 進入時機 | 離開時機 |
|---|---|---|---|
| `draft` | `ticket-writer` 已寫出、尚未通過 `ticket-reviewer` 審查或尚未通過 Ticket 承諾點核准 | Ticket phase 開始撰寫時建立 | `ticket-reviewer` 通過**且**使用者核准 Ticket 承諾點後轉 `approved` |
| `approved` | 已核准的已核准產物（Q5/Q10 適用），等待 Dev phase 排入；相依尚未滿足時持續停留於此狀態 | Ticket 承諾點核准瞬間，該工作單位全部票證同時轉入 | 相依全部滿足、被 `orchestrate` 派工給 `dev-worker` 時轉 `in_dev` |
| `in_dev` | `dev-worker` 正在實作，或審查退回後由 `orchestrate` 以 `SendMessage` 續談修改中 | 派工當下；或 `dev-reviewer` 退回時從 `in_review` 轉回 | `dev-worker` 完成一輪實作、測試轉綠，等待 `dev-reviewer` 審查時轉 `in_review` |
| `in_review` | `dev-reviewer` 正在審查（狀態值取自 DESIGN.md 第 6 節範例 `TICKET-002` 原樣使用） | `dev-worker` 完成當輪實作時 | 審查通過轉 `merged`；審查要求修改轉回 `in_dev`；輪數超限或判定根因在已核准產物轉 `escalated` |
| `merged` | 已通過 `dev-reviewer` 審查並合併進單位分支（狀態值取自 DESIGN.md 第 6 節範例 `TICKET-001` 原樣使用） | 合併動作完成瞬間 | 終態，不再變更（Wrap 歸檔前保持不變） |
| `escalated` | 已上報使用者裁決，等待處理（對應 `state.json escalations[]` 中 `ticket` 欄位指向此票證的那一筆） | Dev 品質迴圈超過輪數上限、或 `dev-worker` 判定測試本身有誤（Q10）觸發上報時 | 使用者裁決後，依裁決內容轉回 `in_dev`（若判定為可修正的實作問題）或轉回 Ticket phase 重新走一次 Ticket 品質迴圈與承諾點（若裁決結果是測試本身需修正，依 DESIGN.md 第 4 節「該票證需重新走一次 Ticket 的品質迴圈與承諾點核准，才能重新進入 Dev」——此時該票證 `status` 應重置為 `draft`） |

**未設立獨立 `queued` 狀態的理由**：`approved` 狀態同時涵蓋「已核准、相依未滿足、尚未派工」與「已核准、相依已滿足、即將派工」兩種情境，不另立狀態值——因為「相依是否滿足」已可由 `dependsOn` 欄位與其他票證的即時狀態機械計算得出（`orchestrate` 在 Dev phase 開始時遍歷 `approved` 狀態的票證、檢查其 `dependsOn` 是否全部為 `merged`），不需要在 `status` 本身重複編碼這個可推導的資訊。

**完整範例**：

```markdown
---
id: TICKET-002
title: Send password reset email with time-limited token
status: in_review
dependsOn: [TICKET-001]
requirementRefs: ["1.2", "2.1"]
testFiles:
  - tests/auth/test_password_reset_email.py
---

## 描述

依 `requirementRefs` 對應的 spec-delta.md 需求，寄送含重設連結的 email，連結於 1 小時後失效。

## 驗收條件（對應 EARS 需求）

- **1.2**：WHEN a user requests a password reset THE SYSTEM SHALL send a reset link valid for 1 hour.
- **2.1**：WHEN the reset link is used after expiry THE SYSTEM SHALL reject the request and prompt the user to request a new link.

## 對應測試

- `tests/auth/test_password_reset_email.py`：`test_reset_link_sent_on_request`、`test_reset_link_expires_after_one_hour`
```

---

## 三、待對齊

無。原兩項待對齊已由使用者裁決：

- **原 #1（S5 裁決）**：票證 `status` 枚舉 `draft`／`approved`／`in_dev`／`in_review`／
  `merged`／`escalated` 六個值照本檔原提案定案，不更動命名。
- **原 #2（S6 裁決）**：`escalated` 票證裁決後，若判定根因是「測試本身需修正」，`status`
  重置為 `draft` 照本檔原推論定案，不新增第七個過渡狀態值。
