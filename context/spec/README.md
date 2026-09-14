# spec/ 索引

> 本目錄是 agent-flow 開發流程第 4 步「規格對齊」（`PROMPT.md`）的產出：把設計逐需求展開成
> 可直接實作的規格文件。每份文件固定三節結構：**已定（來源與依據）**、**規格本文**、
> **待對齊**。2026-09-10 依使用者裁決 R1–R5（見下方「裁決記錄」）完成全面重構。

## 檔案索引

| 檔案 | 內容 |
|---|---|
| [`01-plugin-structure.md`](./01-plugin-structure.md) | `plugin.json`／`marketplace.json`、目錄樹（`agents/` 2 個、`skills/` 8 個平鋪、`references/` 6 份、`context/`）、安裝流程、validate 範圍與補強檢查 |
| [`02-state.md`](./02-state.md) | `.agent-flow/` 目錄、`state.json` schema v2（七 phase、三 gate、`fallbacks[]`、ESC 枚舉縮減）、`decisions.md` FB／ESC 模板、票證格式 |
| [`03-agents.md`](./03-agents.md) | 2 個 general-purpose agent（`worker` sonnet／`reviewer` opus 唯讀）、角色簡報契約、主 session 自建 worktree ＋ `cd` 派工（R12）、`name` 一律裸名（R11） |
| [`04-references.md`](./04-references.md) | 6 份參考文件（`glossary`／`state-management`／`sdd-guide`／`tdd-guide`／`dispatch`／`quality-loop`）；waterfall 路由與審查輸出契約；INV-1～INV-13 |
| [`05-orchestrate.md`](./05-orchestrate.md) | 總控 skill：啟動、phase 接續與三承諾點、派工程序、**waterfall 退回程序（§4.5）**、ESC、`SendMessage` 續談、state 事件表 |
| [`06-explore.md`](./06-explore.md) | Explore：對話（發散收斂）＋可行性調查合一、承諾點一 |
| [`07-prototype.md`](./07-prototype.md) | Prototype（optional）：丟棄式實驗，疑問清單非空才觸發 |
| [`08-spec.md`](./08-spec.md) | Spec：EARS delta spec、承諾點二 |
| [`09-tdd.md`](./09-tdd.md) | TDD：切票證＋紅燈測試，整批一輪；**無 gate**，迴圈通過即測試合約生效 |
| [`10-build.md`](./10-build.md) | Build：相依圖分波次平行、主 session 自建 worktree（R12，無使用者前置設定）、續談退回、合併清理 |
| [`11-review.md`](./11-review.md) | Review：三 lens＋triage；blocking finding **自動**修正或退回、承諾點三 |
| [`12-wrap.md`](./12-wrap.md) | Wrap：執行—驗證、全自動合併／歸檔／清理、失敗即 ESC |

## 建議閱讀順序

1. `01` — 整體骨架與目錄樹。
2. `02` → `03` → `04` — 三份基礎規格：state schema、兩個 agent 與角色簡報契約、六份 reference（含 waterfall 路由契約與 INV 清單）。
3. `05` — 總控與 waterfall 退回引擎（§4.5 是全流程的核心機制）。
4. `06`–`12` — 依 phase 順序閱讀。

## 裁決記錄（R1–R5，2026-09-10 重構）

使用者對前版規格（八 phase／17 agent／internal skill）提出四項結構性問題後，經選項式裁決定案：

| 編號 | 題目 | 裁決 |
|---|---|---|
| R1 | 八 phase 太沈重，如何收斂？ | 收斂為七（一個 optional）：**Explore**（原 Discuss＋Explore 合併，釐清意圖同時做可行性研究）→ **Prototype**（optional，疑問清單非空才觸發）→ **Spec** → **TDD**（原 Ticket 改名，依 spec 定義測試規格）→ **Build**（原 Dev 改名，subagent／worktree 平行）→ **Review** → **Wrap**（全自動收尾） |
| R2 | 承諾點放哪些 phase？ | 三個：Explore／Spec／Review。TDD 不設 gate——測試合約起點由「gate 核准」改為「TDD 品質迴圈通過」，通過即自動進 Build |
| R3 | Waterfall 退回怎麼運作？ | 審查判定根因在較早 phase 時**自動退回**該 phase 重做（不先徵求同意）；重做後承諾點 phase 重新核准，下游 phase 依序重走；留痕為 `FB-<n>`（`decisions.md`＋`state.json.fallbacks[]`）。原 `approved-artifact` ESC 機制廢止；ESC 僅剩 `round-limit`／`fallback-limit`（同一退回目標累計 3 次）／`wrap-failure` 三種 |
| R4 | external skill 與 internal reference 如何區分？ | internal skill 機制廢止，內容改為 `references/` 純 markdown 文件（非 skill、無 frontmatter）；`skills/` 平鋪只放 8 個 external skill；glossary 同樣改為 reference，主 session 執行任何 external skill 前先 `Read` |
| R5 | Agent 如何收斂？ | 17 個角色收斂為 2 個 general-purpose agent：`worker`（sonnet，作者／機械執行）＋`reviewer`（opus，唯讀審查）。角色差異由派工 prompt（角色簡報五要素）＋指定 reference 表達；Build 的 worktree 隔離改用 Agent tool 呼叫時參數 `isolation: "worktree"`（**此項已由 R12 廢止**，改為主 session 自建 worktree） |

## 裁決記錄（R6–R12，2026-09-14）

| 編號 | 題目 | 裁決 |
|---|---|---|
| R12 | `worktree.baseRef: "head"` 這個前置設定是必要的嗎？ | 依 `research/12` 是必要的——但使用者裁決改採 `research/12` §5 的替代方案以徹底取消它：**ticket worktree 改由主 session 自行 `git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit>` 建立**，以分支名指定來源，任何使用者設定都影響不到分岔基準。派工改為普通派工（**不再使用 `isolation` 參數**，R5 該項作廢），角色簡報傳入 worktree 絕對路徑與「先 `cd` 進去」的指示。`research/13` 實測證實：平行子代理各自在指定 worktree 內工作互不干擾、合併與清理正常。**擺放位置**取三案之一——`.git/` 底下雖不汙染 `git status` 但 Write 工具被權限系統擋下（不可用）；改專案根 `.gitignore` 等於換一個前置步驟；採**`.agent-flow/.gitignore` 內含 `worktrees/`**，由 `create_unit()` 一併建立，完全不碰使用者的專案設定。連帶 **INV-3 放寬**：worktree 生命週期改由主 session 持有，重新派工至同一路徑不再遺失實作，續談降為「首選」而非唯一正確手段 |
| R11 | 撞名風險是否成立？是否改用內建 agent、廢除 `agents/`？ | 依 `research/11` 實測：**撞名風險不成立**——同名專案 agent 只佔裸名，plugin 版維持 `agent-flow:<name>`，兩者並存（§2【證實】）。`spec/01` §2.4 風險敘述改寫，Q36「不做啟動掃描」因風險消失而自然成立、不變更。**`agents/` 保留**——廢除會失去兩項工具層保證：`reviewer` 的 `disallowedTools` 唯讀（實測有真正強制力，§3【證實】）與「子代理不得巢狀派工」（`general-purpose` 持有 `Agent` tool），兩者是品質迴圈獨立性與 INV-10 的物理基礎；內建 `Explore` 另因 one-shot（違反 INV-3 續談）與搜尋取向的 system prompt 不適任。模型指派與 `isolation` 確實可改用呼叫時參數，但那本非保留 `agents/` 的理由。**附帶裁定**：agent 的 `name` 一律裸名，命名空間由平台自動衍生，寫進 `name` 會造成 `agent-flow:agent-flow:worker` 冒號疊加且 `validate` 不攔（§3.5【證實】）——已寫入 `spec/03` 通則 4 |
| R10 | README 怎麼寫？ | 中英分成兩份：`README.md` 英文為對外主檔（符合「plugin 內容用英文」）、`README.zh-TW.md` 繁中對照（不用 `zh`，避免與簡體慣例混淆）。兩份**章節結構逐節對齊**以防長期不同步。各含兩張 mermaid 圖：七 phase 流程與三承諾點（含代表性退回虛線）、品質迴圈與退回判定。不使用 `classDef` 自訂顏色（暗色模式可讀性），改以節點形狀區分。不標示 pre-release，按已發佈撰寫。語言規則因此新增第三種情形，已寫入 `.claude/CLAUDE.md` |
| R9 | manifest 的分類／檢索欄位要不要保留？ | 全部移除：`plugin.json` 的 `keywords`（`spec/01` §2.1）與 `marketplace.json` 的 `category`／`tags`（§2.2）。實測 `validate --strict` 對有／無兩版皆通過、不做區別，故屬取捨而非技術限制。移除後兩份 manifest 的欄位集合與規格完全一致，無殘留實作落差 |
| R8 | 根目錄 `CLAUDE.md` 觸發 validate 誤報、使 `--strict` 失敗，怎麼處理？ | 移到 `.claude/CLAUDE.md`。前提「該位置會被當專案 context 載入」官方未記載，已實測【證實】（`research/10` §5.1 三組對照，含負對照）。移入後 `plugin.json` 驗證加 `--strict` 零警告通過，`spec/01` §2.5.1 的 CI 限制隨之解除。連帶：`.gitignore` 必須從 `.claude/` 改為 `.claude/*` ＋ `!.claude/CLAUDE.md`，否則開發約定進不了版控。另裁定**正式發佈前版本號一律維持 `0.1.0`**，`spec/01` §2.1／§2.2 的 `0.2.0` 改回 |
| R7 | `spec/01` §2.5.1 的驗證指令與實際行為不符，怎麼修？ | 依 `research/10-validate-targets.md` 實測改寫：驗證程序從四道指令收斂為**兩道**（`.claude-plugin/plugin.json` ＋ `.claude-plugin/marketplace.json`）。三項實測依據：(a) `validate .` 在雙 manifest 下 marketplace 優先，`plugin.json` 永遠驗不到；(b) 指向 `plugin.json` 會**遞迴驗證所有 skill／agent**（推翻 research 05 實驗五「不遞迴」之結論），故 `./agents`／`./skills` 兩列刪除；(c) 輸出只列出有問題的元件，乾淨者靜默。另記載 `CLAUDE.md` 觸發的 `--strict` 誤報，裁定 CI 不得對 `plugin.json` 用 `--strict` |
| R6 | 開發脈絡文件怎麼與 plugin 執行期內容分離？ | 收攏至**非隱藏**目錄 `context/`（`PROMPT.md`／`DESIGN.md`／`research/`／`spec/` 全部移入，新增 `context/README.md` 索引）；新增 `CLAUDE.md` 記載本 repo 的開發約定（擺放位置後由 R8 定為 `.claude/CLAUDE.md`）。不採 `.context/`——實測 ripgrep 與 shell glob 預設跳過 dot 目錄（`rg -l <needle> .` 找不到 `.context/` 下的檔案，需 `--hidden`），會使實作期每次都要讀的 `spec/` 退出預設搜尋。同時裁定 `DESIGN.md` **不重寫**，改在 `context/README.md` 標註效力狀態，實作一律以 `spec/` 為準 |

R6 僅影響 `01-plugin-structure.md` §2.3 目錄樹（四份文件同時移動，彼此的相對引用仍然自洽）；R7 僅影響同檔 §2.5；R8 影響同檔 §2.1／§2.2（版本號）與 §2.3／§2.5；R9 影響同檔 §2.1／§2.2；R10 僅影響同檔 §2.3 目錄樹；R12 影響 `03-agents.md`（§已定 R5 註記、§3 派工參數與前置驗證）、`04-references.md`（§dispatch 內容規格 6–10、共用程序、INV-13）、`05-orchestrate.md`（§已定、§2.2 廢止、§2.3 建立單位、§4.7）、`10-build.md`（§已定、§3 前置檢查、§4 派工、§5 迴圈）、`11-review.md`（§3 修正派工），以及兩份 README（刪除「執行 Build 前」一節）。R11 影響 `01-plugin-structure.md` §2.4 的風險敘述，與 `03-agents.md` 的 Q36 承襲條目與通則（新增第 4 點「`name` 一律裸名」，原第 4／5 點順延為 5／6）；兩個 agent 定義檔本身不變。其餘規格內容不變。

## 舊裁決承襲對照

前版裁決記錄（DESIGN.md 訪談 Q1–Q40、規格對齊 S1–S13、術語表 G1–G3）在重構後的效力：

**被取代**：
- S1（Review finding 全量呈現使用者裁決）→ R3 自動處置（修正機制本體保留，觸發改自動）。
- S4（`rootCause` 二分法＋`targetArtifact` 契約）→ R3 的 `targetPhase` 契約。
- S11（相依死結寫 ESC）→ R3 改為退回 TDD。
- Q3（四承諾點）→ R2 三承諾點。
- Q33（17 角色模型指派表）→ R5 兩級模型。
- Q37–Q40（兩層 skills、internal skill 文案）、G2（glossary internal skill 載體）→ R4。
- S5（票證枚舉命名）→ 結構承襲、`approved`→`ready`／`in_dev`→`in_build` 改名。

**承襲不變**：S2（TDD 整批一輪）、S3（Wrap ESC 格式）、S6（測試需修正時票證重置 `draft`，觸發改為自動退回）、S7（schema 版本檢查，版本遞增為 2）、S8（重呼叫已核准 phase 拒絕，對象改 Explore）、S9（前置缺失停止提示）、S10（`dependsOn` 判準）、S12（合併後測試失敗附復原問題）、S13（reviewer 進 worktree 的實作前置驗證）、G1／G3（DSL＋Invariant 模式，INV 清單重編為 1–13）；Q 系列中 Q1／Q2／Q7–Q13／Q16–Q18／Q21–Q25／Q28–Q32／Q34–Q36 語意承襲（細節見各檔「已定」節）。

## DESIGN.md 回寫記錄

（累積清單，規格對齊階段不修改 `DESIGN.md`。）

1. **2026-09-05／S1、S4**（前版登記，內容已被 R3 進一步取代，回寫時直接以第 3 筆為準）。
2. **2026-09-05／S4**（同上）。
3. **2026-09-10／R1–R5／待更新章節：全文**——本次重構推翻 DESIGN.md 的核心結構（八 phase、四承諾點、17 角色、internal skill、`approved-artifact` ESC 路由）。回寫時應以 `spec/README.md` 裁決記錄 R1–R5 與各檔規格本文為準整體改寫 DESIGN.md 對應章節；前兩筆登記的局部回寫項目一併作廢。
4. **2026-09-14／R6／回寫程序終止**——裁定不改寫 `DESIGN.md`。它自此為歷史文件：唯一仍具效力的部分是無法從 `spec/` 反推重建的訪談逐字記錄（Q1–Q40）；「設計本文」各章節一律以 `spec/` 為準。上列第 1–3 筆待回寫項目全部作廢，本清單不再累積。
