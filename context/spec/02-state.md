# 02｜狀態外部化規格：`.agent-flow/`、`state.json`、`decisions.md`、票證檔案

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 一、已定（來源與依據）

- **R1**：七 phase——`explore`／`prototype`（optional）／`spec`／`tdd`／`build`／`review`／`wrap`。
- **R2**：承諾點三個——`explore`／`spec`／`review`；TDD 不設 gate，測試合約起點為「TDD 品質迴圈通過」。
- **R3**：waterfall 自動退回——`approved-artifact` ESC 廢止，新增 `fallbacks[]` 陣列與 `FB-<n>` 留痕；ESC 僅剩 `round-limit`／`fallback-limit`／`wrap-failure` 三種。
- **Q6／Q22／Q28**：`.agent-flow/` 按工作單位分目錄、進行中目錄名 `changes/`、單位命名 `<YYYY-MM-DD>-<slug>`、Wrap 歸檔 `archive/`。
- **Q7／Q8／Q9**：EARS 需求編號回鏈；delta spec；TDD phase 產出可執行失敗測試（真測試碼）。
- **Q21／Q24／Q32**：每單位一個 `state.json` 含 schema 版本；主 spec 依領域分域；票證 frontmatter 為相依權威來源、`state.json` 鏡像同步。
- **S2（承襲）**：TDD 品質迴圈整批一輪，`qualityLoops` 單一 key `"tdd"`。
- **S5（部分承襲）**：票證 `status` 枚舉沿用六值結構，但配合 R2／R1 改名：`approved` → `ready`（無 gate 核准，改為迴圈通過即生效）、`in_dev` → `in_build`。
- **S6（語意承襲）**：票證測試需修正時 `status` 重置為 `draft`——但觸發方式由「ESC 裁決後」改為「waterfall 自動退回 TDD 時」（R3）。
- **S7（承襲）**：schema 版本不符即停止回報，不預先設計遷移；本次 schema 改版，`schemaVersion` 遞增為 `2`。

---

## 二、規格本文

### 2.1 `.agent-flow/` 目錄規格

```
.agent-flow/
├── specs/                            # 主 spec（已合併、反映現況），Q24
│   └── <domain>/spec.md
├── changes/                          # 進行中的工作單位，Q22
│   └── <unit-name>/                  # <YYYY-MM-DD>-<slug>，Q28
│       ├── state.json                # §2.2
│       ├── explore.md                # Explore 產物（意圖＋調查＋疑問清單，R1 合併後）
│       ├── prototype.md              # Prototype 產物（optional）
│       ├── prototype/                # 實驗碼本身，進版控（Q18 承襲）
│       ├── spec-delta.md             # Spec 產物，ADDED/MODIFIED/REMOVED
│       ├── tickets/
│       │   └── <ticket-id>.md        # §2.4，TDD 產物
│       ├── review.md                 # Review 產物
│       ├── wrap.md                   # Wrap 產物（逐動作留痕）
│       └── decisions.md              # §2.3，FB／ESC 留痕
└── archive/
    └── <date>-<unit-name>/           # changes/<unit-name>/ 完整快照
```

**檔案建立時機與生命週期**：

| 檔案／目錄 | 建立者 | 生命週期 |
|---|---|---|
| `state.json` | 主 session 於 Explore 啟動時建立骨架 | 全程由主 session 更新，歸檔後不再變更 |
| `explore.md` | 主 session（對話章節）＋`worker`（調查章節） | Explore gate 核准後成為已核准產物；被 waterfall 退回時以既有內容為底修訂、重新核准 |
| `prototype.md`／`prototype/` | `worker` | 迴圈通過後不再修改；無疑問時整段不存在（`status: "skipped"`） |
| `spec-delta.md` | `worker` | Spec gate 核准後成為已核准產物；退回時修訂、重新核准；Wrap 時合併進主 spec |
| `tickets/<id>.md` | `worker`（含建立紅燈測試，測試檔在專案原始碼路徑下） | TDD 迴圈通過即為合約（R2）；`status` 隨 Build 進度更新至 `merged` |
| `review.md` | 主 session 彙整 triage 裁定產出 | Review gate 核准後不再修改 |
| `wrap.md` | `worker` 撰寫，並轉錄主 session 轉交的 `reviewer` 驗證結論；`reviewer` 不直接寫檔 | Wrap 完成即歸檔 |
| `decisions.md` | 首次 FB／ESC 發生時由主 session 建立 | 持續追加，歸檔保留 |

`specs/<domain>/spec.md` 只在 Wrap 由 `worker` 寫入（合併 delta），其餘 phase 唯讀。

### 2.2 `state.json` 完整 schema

**寫入權責**：只由驅動流程的主 session（`orchestrate` 或單獨呼叫的 phase skill 當下的 session）寫入；子代理一律不寫。

**頂層欄位表**：

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `schemaVersion` | integer | 是 | 目前為 `2`（R1–R3 改版遞增；S7：讀取前檢查，不符即停止回報） |
| `unit` | string | 是 | `<YYYY-MM-DD>-<slug>`（Q28） |
| `createdAt`／`updatedAt` | string | 是 | ISO 8601 |
| `currentPhase` | string enum | 是 | `"explore"` \| `"prototype"` \| `"spec"` \| `"tdd"` \| `"build"` \| `"review"` \| `"wrap"` |
| `phases` | object | 是 | key 固定為七個 phase 名，value 見下 |
| `gates` | object | 是 | key 固定為 `"explore"`／`"spec"`／`"review"`（R2） |
| `qualityLoops` | object | 是（可空） | 見下 |
| `tickets` | object | 是（可空） | 見下 |
| `fallbacks` | array | 是（可空，R3 新增） | 見下 |
| `escalations` | array | 是（可空） | 見下 |
| `branch` | object | 是 | `{"unit": "flow/<unit-name>", "baseRef": "main"}`（Q12 承襲） |

**`phases.<phase>`**：`status`（`"pending"` \| `"in_progress"` \| `"done"` \| `"skipped"`，`skipped` 僅 `prototype` 合法且須附 `reason`）、`artifact`（`done` 時填相對路徑）。waterfall 退回時，被撤銷的下游 phase `status` 重置為 `"pending"`（退回目標本身轉 `"in_progress"`；Build→TDD 局部退回時 `build` 維持 `"in_progress"`，見 spec/05 §4.5）。

**`gates.<phase>`**：`approvedAt`／`approvedBy`（未核准為 `null`）。waterfall 退回撤銷某 gate 時兩欄位重置為 `null`（撤銷前的核准記錄留存於 `decisions.md` 對應 FB 條目，`state.json` 不保留歷史值）。

**`qualityLoops.<key>`**：key 為 phase 名（`explore`／`prototype`／`spec`／`tdd`／`review`）或 `build:<ticket-id>`（Build 逐票證）。value：`rounds`／`maxRounds`（標準 3、Review 5）／`status`（`"in_progress"` \| `"passed"` \| `"escalated"`）。waterfall 退回時移除被撤銷下游 phase 的對應 key——兩個例外（spec/05 §4.5）：`review` 的 key 不移除（`rounds` 是五輪上限的持久預算，跨退回保留、僅 `status` 重置為 `"in_progress"`）；Build→TDD 局部退回時未受影響票證的 `build:<id>` key 保留。

**`tickets.<id>`**：`status`（與票證 frontmatter 同一組枚舉，見 §2.4）、`dependsOn`、`requirementRefs`——鏡像自票證 frontmatter（Q32，frontmatter 為權威）。

**`fallbacks` 陣列（R3 新增）**：每個元素為一次 waterfall 退回事件：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | string | `"FB-<n>"`，單位內遞增，與 `decisions.md` 的 `## FB-<n>` 章節共用連結鍵 |
| `fromPhase` | string | 觸發退回的 phase（審查發生處） |
| `toPhase` | string | 退回目標 phase（根因所在） |
| `reason` | string | 一句話摘要 |
| `round` | integer | 觸發時 `fromPhase` 迴圈的輪次 |
| `raisedAt` | string | ISO 8601。退回是立即執行的動作，無 `resolvedAt` |

**`escalations` 陣列（R3 改版）**：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | string | `"ESC-<n>"`，單位內遞增（與 FB 各自獨立編號） |
| `phase` | string | 觸發 phase，七個 phase 名皆合法 |
| `ticket` | string \| null | 源自 Build 某票證時填票證 id |
| `rootCause` | string enum | `"round-limit"`（迴圈輪數超限）\| `"fallback-limit"`（同一退回目標累計達上限）\| `"wrap-failure"`（Wrap 執行—驗證失敗） |
| `raisedAt`／`resolvedAt` | string \| null | 使用者裁決前 `resolvedAt` 為 `null` |

舊 schema 的 `rootCause: "approved-artifact"` 與 `targetArtifact` 欄位隨 R3 廢止——根因在較早 phase 的情況不再上報，改走 `fallbacks[]` 自動退回。

### 2.3 `decisions.md` 留痕模板

兩種條目類型，發生時由主 session 同時寫入 markdown 與 `state.json` 對應陣列（原子雙寫，不允許只寫一處）：

**FB 條目（waterfall 退回留痕，R3）**：

```markdown
## FB-<n>：<一行摘要>
- 觸發：<fromPhase>（第 <k>/<max> 輪審查）
- 退回至：<toPhase>
- 原因：<審查 finding 摘要與根因推理>
- 撤銷範圍：<被重置的 phase 清單；被撤銷的 gate 與其原核准時間>
- 時間：<ISO 8601>
```

**ESC 條目（上報使用者裁決）**：

```markdown
## ESC-<n>：<一行摘要>
- Phase／輪次：<phase>（第 <k>/<max> 輪；Wrap 情境填「Wrap（無輪次，執行—驗證迴圈）」）
- 根因分類：<迴圈輪數超限 | 退回次數超限 | Wrap 執行—驗證失敗>
- 細節：...
- 使用者裁決：...（裁決前留空／標記「待裁決」）
- 裁決時間：...
```

使用者裁決後，主 session 同時回填 markdown 欄位與 `state.json.escalations[].resolvedAt`。

### 2.4 票證檔案格式與 frontmatter

路徑：`.agent-flow/changes/<unit>/tickets/<ticket-id>.md`，`<ticket-id>` 格式 `TICKET-<3 位數流水號>`。

**YAML frontmatter**：`id`／`title`／`status`／`dependsOn`（權威來源，Q32）／`requirementRefs`（EARS 編號回鏈，Q7）／`testFiles`（相對專案根目錄的測試檔路徑，TDD 完成時不得為空——Q9）。

**`status` 枚舉**（S5 結構承襲、R1／R2 改名）：

| 值 | 語意 | 進入時機 | 離開時機 |
|---|---|---|---|
| `draft` | `worker` 已寫出、TDD 迴圈尚未通過 | TDD 撰寫時；或 waterfall 退回 TDD 時由既有狀態重置 | TDD 迴圈通過後轉 `ready` |
| `ready` | 測試合約已生效（R2：迴圈通過即生效，無 gate），等待 Build 排入 | TDD 迴圈通過瞬間，整批同時轉入 | 相依滿足、派工時轉 `in_build` |
| `in_build` | `worker` 實作中，或審查退回續談修改中 | 派工當下；或審查退回時 | 測試轉綠、等待審查時轉 `in_review` |
| `in_review` | `reviewer` 審查中 | `worker` 完成當輪實作時 | 通過轉 `merged`；退回轉 `in_build`；測試合約問題觸發退回 TDD 時轉 `draft`；輪數超限轉 `escalated` |
| `merged` | 已合併進單位分支 | 合併完成瞬間 | 終態（waterfall 退回導致測試修訂時可重回 `draft`，見 spec/05 §4.5） |
| `escalated` | 輪數超限已上報，等待使用者裁決 | ESC（`round-limit`）觸發時 | 裁決後依內容轉回 `in_build` 或 `draft` |

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

無。schema 改版內容（七 phase、三 gate、`fallbacks[]`、`escalations` 枚舉縮減、票證枚舉改名、`schemaVersion: 2`）全部是 R1–R3 的機械推導；承襲項（S2／S6 語意／S7、Q6–Q9、Q21–Q32）依原裁決不變。
