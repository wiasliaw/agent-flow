# 06 — Explore Phase 規格（`skills/explore/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R1**：原 Discuss ＋ Explore 合併為單一 Explore phase——釐清意圖的同時做可行性研究。
- **R2**：Explore 是三承諾點之一。
- **Q16（承襲）**：先發散後收斂——開放式提問探索意圖，選項式逐項收斂，最後產出摘要。
- **Q1（承襲）**：greenfield／brownfield 皆支援——內部程式碼調查與外部技術調查都要覆蓋。
- **DESIGN §2「主 session 唯一的例外」（承襲）**：對話環節由主 session 直接進行、不委派；調查與審查照常委派子代理。
- **Q4／Q2／Q28（承襲）**：標準迴圈上限 3 輪；可單獨呼叫；流程起點需自行建立工作單位。
- **S8（承襲，對象改為 explore）**：重新呼叫已核准的 Explore → 拒絕並提示需明確表示要修改已核准產物。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: explore
description: >-
  Runs a Socratic dialogue to pin down intent while investigating the
  codebase and external options for feasibility, then asks for your
  approval before anything gets specified.
---
```

不設 `context: fork`（對話環節必須發生在主 session）。

### 2. 觸發與前置條件

Explore 是流程起點，無前置 phase 依賴。

- 經 `orchestrate` 驅動：工作單位已建立，直接進入程序步驟。
- 單獨呼叫 `/agent-flow:explore`：先 `resolve_unit()`；無既有單位則 `create_unit()`；若目標單位的 Explore 已核准（`gates.explore.approvedAt != null`）→ **拒絕重新執行**（S8），提示需明確要求「修改已核准的 Explore 產物」——該情境視同使用者發起的 waterfall 退回（spec/05 §3.1）。

### 3. 程序步驟

1. **發散對話（Q16 前半）**：主 session 開放式提問，探索意圖、痛點、限制；持續到能提出具體的收斂問題為止。
2. **可行性調查（原 Explore 職責）**：主 session 從對話中歸納調查面向後，派 `worker`（角色：investigator；無需指名 reference）執行內外並查——內部：既有程式碼、測試、依賴、架構慣例；外部：技術選項、官方文件、已知限制（Q1：兩者皆須覆蓋）。`worker` 把調查發現寫入 `explore.md` 的「調查」章節，結論附佐證（檔案路徑或來源鏈接）。對話與調查可交錯進行——調查發現回饋到收斂提問。
3. **收斂問答（Q16 後半）**：主 session 結合調查發現，逐題提出選項式問題（一次一題、附建議），使用者逐題回答。
4. **產出**：主 session 整理「意圖摘要」與「未解決的技術疑問清單」，完成 `explore.md`（§4）。
5. **委派審查**：派 `reviewer`（指名 `references/quality-loop.md`；prompt 告知 `round`/`maxRounds: 3`），檢查：收斂問答是否被摘要忠實涵蓋（不摻入審查者推論）、調查結論是否有可查證佐證（可抽查）、疑問清單是否合理完整（遺漏會導致 Prototype 被錯誤跳過）。
6. **路由**：`pass` → §5 承諾點；`reject` → findings 的 `targetPhase` 恆為 `"explore"`（首 phase 特例，quality-loop 規則 5），主 session 依 findings 補問使用者或重派 `worker` 補查，修訂後回到步驟 5，`rounds` 遞增。
7. 第 3 輪仍未通過：照標準流程寫 ESC（`round-limit`），但呈現方式與承諾點合併——呈現摘要時一併列出「待確認項目」，使用者的核准回應同時視為對這些項目的裁決（承襲原 Discuss 的處置）。

### 4. 產物

`changes/<unit>/explore.md`：

```markdown
# Explore：<unit-name>

## 意圖

### 發散紀錄
<逐輪開放式問答>

### 收斂問答
#### Q1：<選項式問題>
**選項**：1. ... 2. ... 3. ...（附建議）
**回答**：<使用者選擇與補充>

### 意圖摘要
<整理後的意圖描述>

## 調查

### 內部發現
<既有程式碼／測試／依賴／慣例，附檔案路徑佐證>

### 外部發現
<技術選項／官方文件／已知限制，附來源鏈接佐證>

## 未解決的技術疑問清單

- <需要實驗才能回答的具體技術問題>
（若無，寫「無」——Prototype 是否略過的直接依據）
```

### 5. 承諾點

依 spec/05 §3.1 通則。呈現：意圖摘要＋調查結論要點＋疑問清單（＋若有，第 3 輪未解決的待確認項目）。核准後：`gates.explore` 寫入，commit（`flow(<unit>): explore passed review`），`explore.md` 成為已核准產物；疑問清單非空 → Prototype，為空 → Spec（`orchestrate` 驅動時）。

### 6. 單獨呼叫時的行為

- 前置條件：無。
- 完成後不自動接續（INV-11）；可提示「已核准，可用 `/agent-flow:prototype`（有疑問）或 `/agent-flow:spec`（無疑問）繼續」。

---

## 待對齊

無。合併方式（對話留主 session、調查派 worker、交錯進行）是 R1 落地的直接推導；其餘承襲 Q1／Q16／S8 與原 Discuss／Explore 兩檔的既有裁決。
