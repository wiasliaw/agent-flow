# PROMPT：在空 repo 建立 agent-flow 的第一個 prompt

把下面整段貼給 Claude Code。它不內嵌任何設計決策 — 決策在訪談時由你給出。
這個 prompt 只固定三件事：產品構想（phase 與其一句話定義、skill 撰寫的 DSL
術語表模式）、工作流程（研究 → 訪談 → 設計 → 對齊 → 實作），以及「不得替你
做決定」這條紅線。

---

我要建立一個 Claude Code plugin，名稱 agent-flow：把規格驅動開發（Spec-Driven Development, SDD）
與測試驅動開發（Test-Driven Development, TDD）結合成 waterfall 工作流程，七個 phase
（其中一個 optional）：

- **Explore**：以蘇格拉底提問釐清使用者意圖，同時內外並查、確認實作可行性。
- **Prototype**（optional）：Explore 留下未解決技術疑問時才觸發；用丟棄式程式碼做實驗
  回答疑問，留下問題、做法與證據；程式碼不進正式產品。
- **Spec**：撰寫 SDD 規格。
- **TDD**：根據規格切出可驗證票證，並定義 TDD 測試規格——每張票證附可執行的紅燈測試。
- **Build**：以 subagent 或 worktree 平行執行票證。
- **Review**：對照規格與票證，對整個工作單位做整體審查，列出缺口與問題。
- **Wrap**：全自動收尾，合併與清理不留人工步驟。

規格驅動整個流程；測試先於實作，在 TDD 階段隨票證產出。
每個 phase 結束時由獨立於作者的角色跑一次品質檢查迴圈；流程採 waterfall 模式——
審查判定問題根因在較早的階段時，自動退回該階段重做，重做後依序重走下游階段，
被撤銷的承諾點須重新核准。品質迴圈與自動退回都有明確的次數上限，超限不自行變通，
一律停下來上報、把決定權交還給我。
整個引擎以多 agent 協作（agent orchestration）運作：主 session 作為 orchestrator，
只負責調度、決策與記錄；實際工作派給少數 general-purpose 子 agent（作者／審查
兩種角色）分工執行——不為每個步驟設專屬 agent，角色差異由派工時的角色簡報與
指定的參考文件表達，盡量把長時間的工作推出主 session。

Skill 分兩層：使用者可觸發的 external skill，與不屬於 skill 的內部參考文件
（internal reference，純 markdown，派工時指名載入）。Skill 的程序段落以 pseudo-code
DSL 撰寫，不用長篇散文：把 dispatch／gate／fallback／escalate 這類動詞、共用變數與
共用程序收斂成一份術語表（glossary）reference 文件，跨 phase 的硬性規則編成帶編號的
不變量清單（INV-n）集中定義、各處引用；散文只保留使用者可見文案、產物格式與設計理由。
主 session 執行任何 external skill 前先載入術語表；找不到適用分支時停下來問，
不自行發明路由。

這個 repo 是空的。不要直接開始設計。照下面的順序工作，每一步做完停下來等我確認再進下一步：

1. **可行性研究**。派平行的研究 agent 查官方文件（plugin 元件機制、orchestration 與子代理）
   與 SDD、TDD、多 agent 協作的先行案例（Spec Kit、OpenSpec、Kiro、BMAD、Superpowers、
   內建 /deep-research 這一類）。凡是文件說不清楚的平台行為，在本機做小實驗實測：
   測試 plugin 放 /tmp、用便宜模型、不碰 ~/.claude/。結果寫進 research/，每個主張附來源 URL，
   查不到就標「未記載」；文件與實驗矛盾時以實驗為準。

2. **需求訪談**。設計中的每一個決策都必須來自我的原話或我選的選項，不是你的推論。
   一次一題、選項式提問、附你的建議；研究結果會影響選項的，先講結果再問。
   問答逐字記錄，放在設計文件的開頭作為全文依據 — 之後任何設計內容都要能追溯到某一條回答。

3. **設計**。訪談完成後寫 DESIGN.md（目標與非目標、架構、phase、品質迴圈、agent 協作與派工、
   狀態外部化、VCS、已知取捨，以及從安裝到日常使用的完整旅程與文案）。寫完做一輪自評稽核，
   把發現列給我；需要我裁決的，回到訪談的方式問。

4. **規格對齊**。把設計逐需求展開成 spec/ 下的規格文件，每份分三節：已定（來源與依據）、
   規格本文、待對齊。待對齊的點由我裁決；裁決後改寫進本文並刪除該項。
   對設計文件的累積變更記在 spec/README.md，供之後回寫。

5. **實作**。只實作規格已定的部分，照規格做、不重新設計。規格沒寫的細節選最簡單的做法，
   做完用一行回報。每個檔案完成就跑 claude plugin validate 等驗證，不要累積到最後。
   每次只做我指定的「本次交付」，其餘不動。

文件（research/、DESIGN.md、spec/）用繁體中文；plugin 內容（SKILL.md、agent 定義、模板）
用英文。

---

後續的 prompt 都很短：對訪談與待對齊給裁決、對每一步的產出給確認或修改，
以及在第 5 步逐一指定「本次交付」的檔案清單。
