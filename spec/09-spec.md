# 09 — Spec Phase 規格（`skills/external/spec/SKILL.md`）

## 已定（來源與依據）

- PROMPT.md：八 phase 定義，「Spec：撰寫 SDD 規格」。
- Q2：每個 phase skill 獨立、可單獨呼叫，本身不含自動接續邏輯（接續是 orchestration 的責任）。
- Q3：Spec 是四個承諾點之一。
- Q4：標準品質迴圈（單一獨立審查者 → 退回原作者 → 上限 3 輪 → 上報）。
- Q7：需求用 EARS 格式＋編號，供票證與測試回鏈。
- Q8：spec 為 delta 為主（ADDED/MODIFIED/REMOVED），greenfield 情境下 delta 即全部新增。
- Q24：主 spec 依領域分域，`.agent-flow/specs/<domain>/spec.md`，切分粒度由專案自訂。
- Q40：external skill 一句話文案核准，逐字採用。
- DESIGN.md §3.4：Spec phase 目的、進入條件、產物、品質迴圈、承諾點。
- DESIGN.md §5：派工語法（`Agent(subagent_type="agent-flow:spec-writer", ...)`）、輸出落地檔案只傳輕量引用原則。
- DESIGN.md §6：`state.json` schema，`gates.spec`、`phases.spec`、`qualityLoops.spec` 欄位。
- DESIGN.md §9：旅程範例步驟 5（Spec 承諾點呈現方式）。
- `spec/02-state.md`：票證 `requirementRefs` 欄位格式（與本檔需求編號格式必須一致）、`state.json` 逐欄位 schema、ESC 留痕同步規則。
- `spec/03-agents.md` 第 6、7 節：`spec-writer`、`spec-reviewer` 的 frontmatter、職責與禁令、preload 的 internal skill。
- `spec/04-internal-skills.md` 第 2、6 節：`sdd-guide`（EARS 句型、delta spec 語法、主 spec 合併規則）、`quality-loop`（審查者輸出格式契約、根因二分法、ESC 格式）。
- **S9 裁決**：`explore.md` 不存在時停止並提示、不自動代跑 Explore，照本檔原預設定案；不新增
  「強制跳過 Explore」語法。

---

## 規格本文

### Frontmatter

檔案路徑：`skills/external/spec/SKILL.md`

```yaml
---
name: spec
description: Turns the approved findings into an EARS-format delta spec, numbered for traceability, and asks for your approval before tickets get cut.
---
```

不加 `user-invocable: false`（external skill 預設兩者皆可呼叫，Q37–Q39）；不加 `context: fork`（依 DESIGN §2，phase skill 驅動的是「目前呼叫它的這個 session」，不是被 fork 出去的獨立子代理）。

### 觸發與前置條件

- **觸發**：使用者輸入 `/agent-flow:spec`（可附加自然語言補充指示，透過 `$ARGUMENTS` 傳入），或由 `orchestrate` 在 Explore（與可能的 Prototype）自動接續完成後驅動（DESIGN §3.4「進入條件」）。
- **前置條件**：`changes/<unit>/explore.md` 必須存在，且其品質迴圈已通過（由 `orchestrate` 驅動時，`state.json phases.explore.status == "done"`；單獨呼叫時見下方「單獨使用時的行為」）。若 `changes/<unit>/prototype.md` 存在（Prototype 曾執行），一併讀取。

### 工作單位判定（本檔與 10–13 共用同一套規則，後續檔案只引用不重複）

由於 Spec phase 可能被單獨呼叫（不經 `orchestrate` 排程外殼），執行本 skill 的 session 必須先判定「目前是哪個工作單位」：

1. 若目前 git 分支符合 `flow/<unit-name>` 命名規則（Q12），以此作為工作單位。
2. 否則，若 `.agent-flow/changes/` 下恰好只有一個子目錄，視其為目前工作單位。
3. 否則（存在零個或多個候選、且分支名不吻合），停止並詢問使用者要操作哪一個工作單位（列出 `changes/` 下所有子目錄供選擇）。

此規則適用於本檔與 spec/10–13 的所有五個 phase skill，後續檔案不重複這段文字。

### 程序步驟

1. 判定工作單位（見上）。
2. 讀取 `changes/<unit>/discuss.md`、`changes/<unit>/explore.md`、（若有）`changes/<unit>/prototype.md`，以及 `.agent-flow/specs/<domain>/spec.md`（若已存在，用於避免編號衝突並判斷相對現況的變化）。
3. 以 Agent tool 派工給 `spec-writer`（`subagent_type: "agent-flow:spec-writer"`），prompt 只傳檔案路徑，不整段貼文字內容（DESIGN §5 輸出落地原則）：
   ```
   Agent(subagent_type="agent-flow:spec-writer",
         description="Write delta spec for <unit>",
         prompt="Read changes/<unit>/discuss.md, changes/<unit>/explore.md,
                 and changes/<unit>/prototype.md (if present), plus the
                 existing main spec at .agent-flow/specs/<domain>/spec.md
                 (if present). Write changes/<unit>/spec-delta.md following
                 the EARS and ADDED/MODIFIED/REMOVED contract defined in the
                 sdd-guide internal skill.")
   ```
4. `spec-writer` 完成後回傳「結論摘要＋寫入的檔案路徑」（不整段回傳規格內容）。
5. 以 Agent tool 派工給 `spec-reviewer`（同樣只傳檔案路徑），審查 `spec-delta.md` 的 EARS 格式正確性、編號一致性、與 `discuss.md`／`explore.md` 結論是否吻合。
6. `spec-reviewer` 依 `quality-loop` internal skill 定義的標準審查者輸出格式回傳 `verdict`：
   - `"pass"`：進入步驟 7。
   - `"reject"`：依 `findings[].rootCause` 判斷——本 phase 尚無「已核准產物」（Spec 本身還沒核准），故所有退回一律歸類為 `implementation-issue`，退回步驟 3 由 `spec-writer` 重新派工修正，`state.json qualityLoops.spec.rounds` 遞增。上限 3 輪（Q4）；達上限則依 `quality-loop` 規則寫入 ESC（`decisions.md` + `state.json escalations[]`）並停下等待使用者裁決。
7. 通過後，呈現 `spec-delta.md` 全文給使用者，詢問是否核准進入 Ticket（DESIGN §9 旅程步驟 5：「呈現規格全文給使用者核准」）。
8. 使用者核准後：
   - 更新 `state.json`：`phases.spec.status = "done"`、`phases.spec.artifact = "spec-delta.md"`、`gates.spec.approvedAt`／`approvedBy` 寫入。
   - `spec-delta.md` 自此成為**已核准產物**（Q5、Q10 的「已核准產物不可自行推翻」原則自此適用）。
   - 若由 `orchestrate` 驅動，自動接續 Ticket phase；若單獨呼叫，流程到此結束（見下方「單獨使用時的行為」）。
   - 使用者若不核准並提出修改意見，回到步驟 3 由 `spec-writer` 依意見修訂（不計入品質迴圈輪數，因為這是使用者退回而非審查者退回）。

### `spec-delta.md` 格式與需求編號規則

依 `sdd-guide` internal skill（`spec/04-internal-skills.md` 第 2 節）定義的語法，本檔給出可直接落地的完整範例：

```markdown
---
unit: 2026-09-04-password-reset
domain: auth
---

## ADDED Requirements

### 1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a reset link valid for 1 hour.

### 1.2 WHEN the reset link is used after expiry THE SYSTEM SHALL reject the
request and prompt the user to request a new link.

## MODIFIED Requirements

(此區塊在 greenfield 或本次變更未修改既有需求時省略，不寫空區塊)

## REMOVED Requirements

(同上，未移除既有需求時省略)
```

- **Frontmatter**：`unit`（工作單位名稱）、`domain`（Wrap 時合併進 `.agent-flow/specs/<domain>/spec.md` 的目標領域，Q24）。`domain` 由 `spec-writer` 依現有 `.agent-flow/specs/` 下的既有領域名稱判斷，若無吻合的既有領域則依變更內容自訂一個新領域名（kebab-case）。
- **編號規則**：`<主編號>.<子編號>`（如 `1.1`、`1.2`），與 `spec/02-state.md` 定案的票證 frontmatter `requirementRefs` 欄位格式（`requirementRefs: ["1.1", "1.2"]`）完全一致——Ticket phase 的每張票證引用的就是這裡的編號。同一領域內編號不得重複；`MODIFIED` 區塊沿用被修改需求的原編號；`REMOVED` 區塊同樣沿用原編號並附一句話說明移除原因。

### 品質迴圈

標準迴圈（Q4）。審查者（`spec-reviewer`）與作者（`spec-writer`）的完整 frontmatter／職責見 `spec/03-agents.md` 第 6、7 節；審查者輸出格式契約見 `spec/04-internal-skills.md` 第 6 節。上限 3 輪，超限或根因判定為已核准產物時走 ESC 上報流程（本 phase 因 Spec 本身尚未核准，實務上不會出現「根因在已核准產物」的退回——那要等到 Ticket/Dev phase 才可能發生，Spec phase 本身的退回恆為 `implementation-issue`）。

### 承諾點

是（Q3）。核准後 `spec-delta.md` 成為已核准產物，`state.json gates.spec` 寫入核准時間與核准人。

### 單獨使用時的行為（Q2）

- 若 `changes/<unit>/explore.md` 不存在：**停止並提示**使用者先執行 `/agent-flow:explore`，不自動代為執行 Explore（因為 Q2 已定「單一 phase 走純手動」，本 phase 不應該替使用者跨 phase 自動執行）；不提供任何「強制跳過 Explore」的語法或選項（S9 裁決）。
- 若成功執行到承諾點核准，行為與由 `orchestrate` 驅動時完全相同（DESIGN §2：「無論被 orchestrate 驅動、還是使用者直接呼叫某一個 phase skill 單獨執行，實際執行 phase 邏輯的都是目前呼叫它的那個 session 本身」），差別只在於核准後**不會**自動接續 Ticket phase——使用者需自行呼叫 `/agent-flow:ticket` 或 `/agent-flow:orchestrate` 接續。

---

## 待對齊

無。原第 1 項（`explore.md` 不存在時的確切處置）已由 S9 裁決確認採本檔原預設（停止並提示，
不自動代跑），且明確排除新增跳過語法，改寫進「單獨使用時的行為」一節規格本文。
