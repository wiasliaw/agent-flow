# 08 — Spec Phase 規格（`skills/spec/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R2**：Spec 是三承諾點之一。
- **Q7／Q8／Q24（承襲）**：EARS 格式＋編號；delta spec（ADDED/MODIFIED/REMOVED，greenfield 即全 ADDED）；主 spec 依領域分域。
- **Q4／Q2（承襲）**：標準迴圈 3 輪；可單獨呼叫。
- **S9（承襲，前置對象改為 explore.md）**：前置產物不存在時停止提示、不自動代跑、不提供跳過語法。
- **R3**：審查發現根因在 Explore 時自動退回（取代原「Spec 尚未核准故恆為 implementation-issue」的單一路由——合併 Discuss 後，Explore 已是已核准的上游產物）。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: spec
description: >-
  Turns the approved findings into an EARS-format delta spec, numbered for
  traceability, and asks for your approval before tests get written.
---
```

### 2. 觸發與前置條件

- **觸發**：`/agent-flow:spec`，或由 `orchestrate` 在 Explore 核准（與可能的 Prototype 完成）後驅動。
- **前置條件**：`changes/<unit>/explore.md` 存在且 Explore 已核准（`gates.explore.approvedAt != null`）；`phases.prototype.status == "done"` 時一併讀取 `prototype.md`——**以 phase 狀態為準，不以檔案存在為準**（spec/05 §4.5 步驟 4）：`skipped` 時即使檔案存在（waterfall 退回後殘留的舊底稿）也不作為輸入。
- 工作單位判定：`resolve_unit()`（`references/glossary.md` 共用程序，本檔與 spec/09–12 皆引用、不重複）。

### 3. 程序步驟

1. `resolve_unit()`，確認前置條件。
2. 派 `worker`（角色：spec author；指名 `references/sdd-guide.md`），prompt 傳 `explore.md`、（`phases.prototype == "done"` 時）`prototype.md` 與 `.agent-flow/specs/<domain>/spec.md` 路徑，要求寫出 `changes/<unit>/spec-delta.md`。
3. 派 `reviewer`（指名 `references/sdd-guide.md`、`references/quality-loop.md`；告知輪次），審查：EARS 句型正確、編號連續無衝突、ADDED/MODIFIED/REMOVED 分類屬實、內容與 `explore.md`（及 `phases.prototype == "done"` 時的 `prototype.md`）結論吻合、未引入調查未提及的新範圍。
4. 路由：
   - `pass`：進承諾點。
   - `reject` 且 blocking findings 全部 `targetPhase: "spec"`：重新派 `worker` 附 findings，`rounds` 遞增，上限 3 輪，超限 ESC。
   - `reject` 且任一 blocking finding 的 `targetPhase` 為較早 phase（`"explore"` 或 `"prototype"`，例：意圖摘要誤導、實驗結論有誤）：waterfall 退回至最早目標（spec/05 §4.5）。
5. 承諾點：呈現 `spec-delta.md` 全文，詢問是否核准進入 TDD。核准後 `gates.spec` 寫入、commit，`spec-delta.md` 成為已核准產物；使用者提修改意見則派回 `worker` 修訂（不計輪，INV-7）。

### 4. `spec-delta.md` 格式與編號規則

```markdown
---
unit: 2026-09-10-password-reset
domain: auth
---

## ADDED Requirements

### 1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a reset link valid for 1 hour.

### 1.2 WHEN the reset link is used after expiry THE SYSTEM SHALL reject the
request and prompt the user to request a new link.

## MODIFIED Requirements

(greenfield 或未修改既有需求時省略，不寫空區塊)

## REMOVED Requirements

(同上)
```

- `domain`：Wrap 合併目標領域（Q24），由 `worker` 依既有 `.agent-flow/specs/` 領域判斷，無吻合則自訂 kebab-case 新領域名。
- 編號 `<主編號>.<子編號>`，與票證 `requirementRefs` 格式一致；MODIFIED／REMOVED 沿用原編號，REMOVED 附一句話移除原因。

### 5. 承諾點

是（R2）。核准後 `spec-delta.md` 成為已核准產物。

### 6. 單獨呼叫時的行為

- `explore.md` 不存在或未核准：停止並提示先執行 `/agent-flow:explore`，不自動代跑、無跳過語法（S9）。
- 核准後不自動接續 TDD（INV-11）。

---

## 待對齊

無。內容承襲原 Spec 規格；退回路由依 R3 加入 `targetPhase: "explore"` 的 fallback 分支。
