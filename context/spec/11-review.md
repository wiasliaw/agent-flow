# 11 — Review Phase 規格（`skills/review/SKILL.md`）

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 已定（來源與依據）

- **R2**：Review 是三承諾點之一。
- **R3（取代 S1）**：blocking finding 不再全量呈現待使用者裁決——依 `targetPhase` **自動處置**：`build` → 派全新 worker 修正；更早 phase → waterfall 退回。S1 的「全新 worker 從單位分支 tip 修正、修完重跑一輪、不疊加獨立審查」機制**保留**，但觸發從「使用者核准」改為「自動」。
- **R5**：三個平行審查小組與 triage 由同一個 `reviewer` agent 以四次不同角色簡報派工實現（lens：gap／edge-case／spec-compliance；另一次 triage）。
- **Q12／Q29（承襲）**：審單位分支相對 main 的整體 diff；重型迴圈上限 5 輪。
- **research 04（承襲）**：平行 lens 互不可見；triage 不採信自報嚴重度。
- **Q35／DESIGN §8（承襲）**：compliance lens 查核 `prototype/` 零依賴，違反為阻斷性 finding。

---

## 規格本文

> 執行本 skill 前，主 session 須先 `Read` `references/glossary.md`（R4）。

### 1. Frontmatter

```yaml
---
name: review
description: >-
  Runs a multi-perspective audit of the whole unit against its spec and
  tickets, auto-fixing or falling back on blocking findings, then asks for
  your approval before wrap-up.
---
```

### 2. 觸發與前置條件

- **觸發**：`/agent-flow:review`，或由 `orchestrate` 在全部票證 `merged` 後驅動。
- **前置條件**：所有票證 `status == "merged"`（有 `escalated` 未裁決不可進入）。
- 工作單位判定：`resolve_unit()`。

### 3. 程序步驟

1. `resolve_unit()`，確認前置條件。
2. 取得 `git diff main...flow/<unit-name>`（Q12），寫入暫存檔（如 `changes/<unit>/.review-diff-round-<k>.txt`，非正式產物）。
3. **同一輪回應**平行派三個 `reviewer`（lens 模式；各自指名 `references/quality-loop.md`，compliance lens 另加 `references/sdd-guide.md`），prompt 只傳 diff 檔與 `spec-delta.md`／`tickets/` 路徑，互不可見（INV-10）：
   - **gap lens**：找缺口——需求無對應實作、票證無對應測試、遺漏面向。
   - **edge-case lens**：找未測邊界——邊界值、異常輸入、併發時序，可實際執行驗證。
   - **spec-compliance lens**：逐條核對 ADDED/MODIFIED/REMOVED 落實；**並查核正式產品路徑對 `changes/<unit>/prototype/` 零依賴**（違反＝blocking）。
   - 三者輸出 raw-finding 層（`reportedSeverity` 僅供參考）。
4. 三份回報落地成檔案後，派 `reviewer`（triage 模式；指名 `references/quality-loop.md`），逐條**親自重新查證**、不採信自報嚴重度，輸出裁定層（`verdict`／`severity`／`targetPhase`／`sourceFindingIds`，`maxRounds: 5`）。
5. 主 session 彙整裁定結果，產出／更新 `changes/<unit>/review.md`（§5）。
6. **自動處置 blocking finding（R3）**：
   - 存在 `targetPhase` 為較早 phase（`"explore"`／`"prototype"`／`"spec"`／`"tdd"` 任一）的 blocking finding：取**最早**的 targetPhase 執行 waterfall 退回（spec/05 §4.5）——重做、重新核准、重走下游後回到本 phase 步驟 2。`qualityLoops.review.rounds` 跨退回**保留**（§4.5 撤銷規則 (b) 的明訂例外），回到本 phase 時在保留值上遞增——五輪上限（Q29）因此跨退回累計，不因撤銷歸零。
   - 僅有 `targetPhase: "build"` 的 blocking finding：依 §4 修正機制派**全新** `worker` 一次處理全部此類 finding，合併後回到步驟 2 重跑完整一輪（三 lens＋triage），`rounds` 遞增。
   - 無 blocking finding：進步驟 7。
7. **承諾點**：呈現 `review.md`——輪次（第 `k`/5 輪）、本輪已自動處置的歷史、剩餘 non-blocking finding 清單，提出「以上非阻斷項目視為知情後暫緩。是否核准進入 Wrap？」。核准 → `gates.review` 寫入、commit，自動接續 Wrap（orchestrate 驅動時）；使用者要求額外修正 → 視性質走 §4 或使用者發起的 fallback（不計輪，INV-7）。
8. 5 輪上限（Q29）：仍有 blocking finding 未收斂 → ESC（`round-limit`），停止自動重跑，後續依使用者指示。

### 4. Build finding 的修正機制（承襲 S1 機制、觸發改自動）

Review 時已無進行中的 `worker` 可續談（全部票證已合併），因此：

1. 確認 checkout 在 `flow/<unit-name>`（含全部合併結果）。
2. 主 session 先自建修正用 worktree——`git worktree add -b ticket/review-fix-<round> .agent-flow/worktrees/review-fix-<round> flow/<unit-name>`（以分支名指定來源，不依賴任何設定，R12）——再**全新**派工 `worker`（普通派工、不帶 `isolation`；prompt 傳入該 worktree 的**絕對路徑**並要求先 `cd` 進去）。
3. Prompt 引用 `review.md` 對應章節路徑，列出本輪全部 `targetPhase: "build"` 的 blocking finding，同一 worktree 內依序處理（不逐條開 worktree）。
4. `worker` 修正、確認相關測試綠燈、commit 一次。
5. 合併進單位分支（機制引用 spec/10 §6：`--no-ff`、立即 remove worktree）。
6. 回到步驟 2 重跑下一輪 Review——**不**疊加獨立審查，下一輪三 lens＋triage 本身就是對修正的驗證。

### 5. `review.md` 章節結構

```markdown
# Review：<unit-name>

## 摘要
- 審查輪次：第 <k>/5 輪
- 本輪 blocking：<N> 個（已自動處置：<修正 | 退回至 <phase>>）
- non-blocking：<M> 個

## Blocking findings

### R1：<一行摘要>
- 嚴重度：blocking
- 位置：<檔案路徑>
- 描述：...
- 退回目標（targetPhase）：<build | tdd | spec | prototype | explore>
- 處置：<第 <k> 輪派 worker 修正 | 第 <k> 輪退回 <phase>（見 FB-<n>）| 待處置>
- 來源 lens：<gap | edge-case | spec-compliance>

## Non-blocking findings

### R2：<一行摘要>
（欄位同上，處置：知情後暫緩）

## Prototype 零依賴查核（spec-compliance lens）
- 結果：<通過 | 發現違反：檔案路徑清單>
```

### 6. 承諾點

是（R2）。核准前提：本輪無 blocking finding（自動處置機制保證收斂或於 5 輪上限 ESC）。

### 7. 單獨呼叫時的行為

- 尚有票證未 `merged`：停止提示先完成 Build。
- 自動處置中的 waterfall 退回：留痕與撤銷後停止，提示使用者呼叫對應 phase skill（spec/05 §7）；`build` 修正派工不涉跨 phase，照常執行。
- 核准後不自動接續 Wrap（INV-11）。

---

## 待對齊

無。自動處置模型是 R3 對 S1 的明確取代（S1 的修正機制本體保留）；lens／triage 由 `reviewer` 多次派工實現是 R5 的直接推導；其餘承襲原 Review 規格。
