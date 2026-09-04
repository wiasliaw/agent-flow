# 12 — Review Phase 規格（`skills/external/review/SKILL.md`）

## 已定（來源與依據）

- PROMPT.md：「Review：對照規格與票證，對整個工作單位做整體審查，列出缺口與問題。」
- Q2：phase skill 獨立、可單獨呼叫。
- Q3：Review 是承諾點。
- Q4：Review 用重型迴圈（多視角平行審查＋獨立 triage，BMAD 式）。
- Q5：根因二分法，已核准產物一律上報。
- Q12：Review 審單位分支整體 diff（相對 main）。
- Q29：Review 重型迴圈輪數上限 5 輪。
- DESIGN.md §3.7：Review phase 目的、進入條件、產物、品質迴圈、承諾點。
- DESIGN.md §8：`review-spec-compliance-auditor` 對 `prototype/` 零依賴的查核責任（Q18/Q35 配套紀律）。
- DESIGN.md §9：旅程步驟 9（Review 承諾點呈現方式）。
- research 04：BMAD-METHOD 四層獨立審查 lens 平行運作、triage 不採信審查者自報嚴重度、根因分流。
- `spec/03-agents.md` 第 12–15 節：`review-gap-hunter`／`review-edge-case-hunter`／`review-spec-compliance-auditor`／`review-triage` 的 frontmatter、職責與禁令。
- `spec/04-internal-skills.md` 第 6 節：`quality-loop` 的 Review 兩層 schema（平行小組原始 finding／`review-triage` 裁定輸出）。
- `spec/11-dev.md`：Dev phase 的 worktree 合併與清理機制，本檔「純實作問題的修正機制」引用其
  「合併與清理」步驟、不重複機制說明。
- `spec/09-spec.md`「工作單位判定」一節：本檔沿用同一套規則。
- **S1（裁決記錄，未採 DESIGN §3.7 原建議「純實作問題可退回修正」——實質設計變更）**：Review
  phase 不自動修正 finding；獵人＋`review-triage` 產出的全部 finding（不分根因分類）一律在
  Review 承諾點全量呈現給使用者裁決；使用者核准要修的 `implementation-issue` finding，由
  `orchestrate` 派**全新** `isolation: worktree` 的 `dev-worker`（從單位分支 tip 分岔，機制同
  Dev phase）執行修正，修完重新完整跑一輪 Review（三審查小組＋triage 全部重跑），計入
  Q29 的 5 輪上限。此變更與 DESIGN §3.7 原文（「純實作問題由迴圈自動退回原作者子代理修正」對
  Review 同樣適用）不同，是使用者明確裁決的實質設計變更，已登記到 `spec/README.md`
  「DESIGN.md 回寫記錄」。原本待對齊 #1（「單一 ESC 是否阻塞其餘 finding」）因這個新模型下
  已無「部分自動修正、部分上報」的混合狀態而不再適用，見「待對齊」節說明。

---

## 規格本文

### Frontmatter

檔案路徑：`skills/external/review/SKILL.md`

```yaml
---
name: review
description: Runs a multi-perspective audit of the whole unit against its spec and tickets, then asks for your approval before wrap-up.
---
```

### 觸發與前置條件

- **觸發**：`/agent-flow:review`，或由 `orchestrate` 在 Dev phase 全部票證 `merged` 後自動驅動。
- **前置條件**：該工作單位所有票證的 `status == "merged"`（`state.json` 中每筆 `tickets.<id>.status` 皆為 `"merged"`；若有 `"escalated"` 票證尚未裁決解決，不可進入 Review）。

### 工作單位判定

同 `spec/09-spec.md`「工作單位判定」一節。

### 程序步驟

1. 判定工作單位，確認前置條件（全部票證 `merged`）。
2. 取得單位分支 `flow/<unit-name>` 相對 `main` 的整體 diff（`git diff main...flow/<unit-name>`，Q12）。
3. **同一輪回應中**平行派工三個審查小組（依 `parallel-dispatch` internal skill 的通則，且三者彼此不互看過程或結論）：
   ```
   Agent(subagent_type="agent-flow:review-gap-hunter",
         description="Find gaps for <unit>",
         prompt="Review the diff at <diff-file-path> against
                 changes/<unit>/spec-delta.md and changes/<unit>/tickets/.
                 Report findings using the raw-finding schema defined in
                 the quality-loop internal skill (role: review-gap-hunter).")

   Agent(subagent_type="agent-flow:review-edge-case-hunter",
         description="Find untested edge cases for <unit>",
         prompt="... (同上，role: review-edge-case-hunter)")

   Agent(subagent_type="agent-flow:review-spec-compliance-auditor",
         description="Audit spec compliance for <unit>",
         prompt="... (同上，role: review-spec-compliance-auditor；並確認正式
                 產品程式碼路徑沒有任何檔案 import/依賴
                 changes/<unit>/prototype/ 下的內容)")
   ```
   diff 內容本身先寫入一個暫存檔案路徑（例如 `changes/<unit>/.review-diff-round-<k>.txt`，非正式產物、Review 完成後可清除），三個 prompt 只傳這個檔案路徑，不整段貼 diff 文字（DESIGN §5 輸出落地原則，`parallel-dispatch` 通則）。
4. 三個審查小組平行完成，各自回傳原始 finding（`quality-loop` 定義的 Review 原始 finding schema，不含 `verdict`／`rootCause`）。
5. 以 Agent tool 派工給 `review-triage`，prompt 傳入三份原始 finding 的檔案路徑（三個審查小組的完整回報應先由 orchestrator 落地成檔案，而非直接貼入 `review-triage` 的 prompt——同樣的輸出落地原則）：
   - `review-triage` 對每一條 finding **不採信自報嚴重度**、親自重新查證（重跑相關測試、重讀程式碼），依 `quality-loop` 標準輸出格式回傳裁定結果（`verdict`／`findings[].severity`／`findings[].rootCause`／`findings[].sourceFindingIds`／`escalation`）。`rootCause` 分類**仍然保留並輸出**（供分類呈現與判斷後續可行動作的種類，見步驟 8），但依 S1 裁決**不再驅動自動退回或自動 ESC**——這是本檔相對舊版規格本文的核心變更。
6. orchestrator 彙整 `review-triage` 的全部裁定結果（`verdict == "pass"` 或 `findings` 為空時，`findings` 陣列自然為空，直接視為本輪無 finding），產出／更新 `changes/<unit>/review.md`，列出**全部** finding（不分根因分類，見「`review.md` 章節結構」）。
7. **呈現 `review.md` 給使用者（本輪的承諾點互動）**：統計本輪 finding 數（阻斷／非阻斷）、目前輪次（第 `k`/5 輪），逐條列出 finding 與其根因分類，並提出以下請求：「以下是本輪發現的問題，請指出哪些需要立即修正；未指定修正的項目視為暫緩，不阻擋核准進入 Wrap。是否核准進入 Wrap？」（DESIGN §9 旅程步驟 9 原文問句在此基礎上擴充為「先選修正項目，再問是否核准」的複合問句）。
8. 依使用者的回覆分三種情境處理：
   - **(a) 核准進入 Wrap，且未指定任何 finding 需要修正**（不論是否還有未解決的非阻斷 finding，皆視為使用者已知情並接受現狀）：進入步驟 10（承諾點通過）。
   - **(b) 指定若干 finding 需要修正**：
     - `rootCause == "implementation-issue"`：orchestrator 依「純實作問題的修正機制」（見下）派**一個全新**的 `dev-worker` 處理使用者本輪核准的全部此類 finding（同一個 worktree 內依序處理，不逐條各開一個 worktree，降低同一輪內多處修正互相衝突的風險）。
     - `rootCause == "approved-artifact"`：orchestrator **不**直接派修正子代理——根因在已核准的 Spec 或 Ticket，依 Q5「已核准產物 agent 不自行推翻」，若使用者要求修正，即等同使用者主動決定重開對應 phase，套用 `spec/05-orchestrate.md` §3.1「使用者主動修改已核准產物」機制（回到 Spec 或 Ticket 重新走一次品質迴圈與承諾點，記錄於 `decisions.md`，非標準 ESC 流程）；重開完成、受影響票證的 Dev phase 重新跑完後，才重新進入 Review。
     - 兩者皆處理完成（或至少完成使用者本輪要求的部分）後，回到步驟 2 重新取得 diff、重新跑一輪完整 Review（三個審查小組＋`review-triage` 全部重跑），`state.json qualityLoops.review.rounds` 遞增（Q29：「修正→重審」循環計為一輪）。
   - **(c) 既未核准進入 Wrap，也未指定任何 finding 需要修正**（例如使用者仍在考慮）：停在目前狀態等待使用者進一步輸入，不遞增輪次、不自動執行任何動作。
9. 迴圈輪數達 5 輪（Q29）仍未核准進入 Wrap：視為不收斂，寫入 ESC（`decisions.md` + `state.json escalations[]`，`rootCause: "round-limit-exceeded"`），停止自動重跑本輪迴圈，向使用者明確告知已達輪數上限，後續完全依使用者指示（例如「這次先這樣，核准進入 Wrap」或其他人工介入方式）決定，不再自動重試。
10. 使用者核准後：`state.json phases.review.status = "done"`、`gates.review.approvedAt`／`approvedBy` 寫入；若由 `orchestrate` 驅動，自動接續 Wrap。

### 純實作問題的修正機制（S1，全新 `dev-worker` 從單位分支 tip 派工）

與 Dev phase 品質迴圈「續談既有 `dev-worker`」的機制不同——Review 沒有一個「原本正在做這件事」
的 `dev-worker` 可以續談（Review 發生在全部票證都已合併之後，不對應任何單一進行中的
`dev-worker`）。orchestrator 依以下步驟執行：

1. 確認目前已 `checkout` 在單位分支 `flow/<unit-name>`（Dev phase 完成後，單位分支應已包含
   全部票證的合併結果）。
2. 用 Agent tool **全新**派工一個 `dev-worker`（`subagent_type: "agent-flow:dev-worker"`，
   `isolation: worktree`）——**不是**續談，是新的一次呼叫；新 worktree 從目前單位分支 tip
   分岔（`worktree.baseRef: "head"` 沿用 Dev phase 已確認／代寫的專案設定，見
   `spec/05-orchestrate.md` §2.2，不需要重新檢查一次），天然包含所有已合併票證的成果。
3. Prompt 中列出使用者本輪核准要修正的全部 `implementation-issue` finding（引用 `review.md`
   對應章節的檔案路徑，不整段貼 finding 文字，依 `parallel-dispatch`／`using-worktree` 通則的
   檔案落地原則），要求 `dev-worker` 依序處理全部列出的項目。
4. `dev-worker` 完成修正、（若涉及既有測試）確認相關測試仍為綠燈後，在自己的 worktree 內
   commit 一次。
5. orchestrator 把該 worktree 的變更合併進單位分支（機制引用 `spec/11-dev.md`「合併與清理」
   一節：`git merge --no-ff`，合併後立即 `git worktree remove`，不重複機制說明）。
6. 回到「程序步驟」步驟 2，重新取得 diff、開始下一輪 Review。

此修正**不**經過獨立的 `dev-reviewer` 審查（不同於 Dev phase 票證的品質迴圈）——下一輪 Review
的三個審查小組＋`review-triage` 本身就是對這次修正的獨立驗證，不需要疊加一層額外審查，避免
重複勞動。

### `review.md` 章節結構

```markdown
# Review：<unit-name>

## 摘要
- 阻斷問題：<N> 個
- 非阻斷建議：<M> 個
- 審查輪次：第 <k>/5 輪

## 阻斷問題

### R1：<一行摘要>
- 嚴重度：blocking
- 位置：<檔案路徑>
- 描述：...
- 根因分類：<implementation-issue | approved-artifact>
- 處置：<待使用者裁決（本輪首次呈現）| 使用者要求修正，已於第 <k> 輪修正並重審 | 使用者選擇暫緩，不阻擋核准 | 使用者要求重開 Spec/Ticket（見 decisions.md）>
- 來源審查者：<review-gap-hunter | review-edge-case-hunter | review-spec-compliance-auditor>

## 非阻斷建議

### R2：<一行摘要>
（欄位同上，severity: non-blocking）

## Prototype 零依賴查核（`review-spec-compliance-auditor`）
- 結果：<通過 | 發現違反：列出違反的檔案路徑>
```

每條 `R<n>` 對應 `review-triage` 輸出中的一筆 `findings[]`（`id` 沿用 `T<n>` 或轉譯為 `R<n>`，`sourceFindingIds` 保留供追溯）。

### `review-spec-compliance-auditor` 的額外職責

依 DESIGN §8（Q18/Q35 配套紀律），本角色**必須**在其審查範圍內明確檢查：正式產品程式碼路徑（依專案實際結構判斷，例如 `src/`）中沒有任何檔案 `import`／依賴 `.agent-flow/changes/<unit>/prototype/` 下的內容。查到違反必須列為**阻斷性** finding（`reportedSeverity: "blocking"`），這是 Review 承諾點通過的必要條件之一（`review.md` 需在「Prototype 零依賴查核」章節明確記錄此項結果）。

### 品質迴圈

重型迴圈（Q4／Q29），但退回路由依 S1 裁決與其他標準迴圈 phase 不同：**不做自動退回或自動 ESC**，
每輪的全部 finding（不分根因分類）一律先呈現給使用者裁決，使用者決定要修正的項目後才觸發下一輪
（見「純實作問題的修正機制」與「程序步驟」步驟 7–8）。角色定義見 `spec/03-agents.md` 第 12–15
節；輸出格式契約見 `spec/04-internal-skills.md` 第 6 節「Review 重型迴圈」兩層 schema（`rootCause`
欄位在 Review 情境下的作用改為「決定使用者要求修正時可行的修正手段種類」，不再直接驅動自動路由，
見該檔規則 3 的 Review 特例說明）。上限 5 輪，超限走 ESC（`rootCause: "round-limit-exceeded"`）。

### 承諾點

是（Q3）。核准後方可進入 Wrap。呈現行為見「程序步驟」步驟 9。

### 單獨使用時的行為（Q2）

- 若尚有票證未 `merged`：停止並提示使用者先完成 Dev phase。
- 核准後不自動接續 Wrap，使用者需自行呼叫 `/agent-flow:wrap` 或 `/agent-flow:orchestrate`。

---

## 待對齊

無。原待對齊 #1（「單一 ESC 是否阻塞其餘 finding 的繼續處理」）已由 S1 裁決消滅——新模型下
不再有「部分 finding 自動修正、部分上報 ESC」的混合狀態：全部 finding 一律在每輪的 Review
承諾點統一呈現給使用者，由使用者在同一次回覆中決定要修正哪些、是否核准進入 Wrap，原本要問的
「是否允許在有未解決 ESC 時提前核准 Wrap」已內建在步驟 8(a) 的設計中（使用者未指定修正的
finding 視為知情後暫緩，不阻擋核准）——這正是原待對齊項目關切的問題，S1 的設計本身就是其答案。
