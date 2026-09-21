# context/ — agent-flow 的開發脈絡

這裡放的是「怎麼做出 agent-flow」的記錄，不是 plugin 執行時會用到的東西。
plugin 執行期內容全部在 repo 根目錄的 `skills/`、`agents/`、`references/`、
`.claude-plugin/`、`scripts/`——那些目錄裡的檔案一律用英文寫，本目錄一律用
繁體中文。

`context/` 不是 plugin 元件：沒有任何 manifest 欄位宣告它，`claude plugin
validate` 不涉及它，它的內容不影響 plugin 行為。

## 權威鏈

```
PROMPT.md  →  research/  →  DESIGN.md  →  spec/  →  實作
（流程憲法）   （證據）      （設計總覽）   （唯一依據）
```

**實作與問答一律以 `spec/` 為準。** 下游文件推翻上游時以下游為準，唯一例外是
`PROMPT.md` 的流程規則——它定義工作方式本身，任何階段都不得自行放寬。

## 各文件與效力狀態

| 文件 | 內容 | 效力 |
|---|---|---|
| `PROMPT.md` | 建立本 repo 的第一個 prompt，定義五步流程（研究 → 訪談 → 設計 → 規格對齊 → 實作）與「不得替使用者做決定」這條紅線 | **有效**。流程規則的來源，逐字保存不修改 |
| `research/` | 9 份可行性研究：官方文件調查（01–04）、`/tmp` 沙箱實測（05–07）、補做查證（08–09）。每個主張附來源 URL，查不到標「未記載」 | **有效**。文件與實驗矛盾時以實驗為準；`research/README.md` 列出對設計影響最大的 9 條裁決 |
| `DESIGN.md` | 訪談逐字記錄（Q1–Q40）＋ 設計本文十章 | **有效（設計總覽）**。設計本文已於 2026-09-21 依 R14 整體改寫、與 `spec/` 對齊（見下）；與 `spec/` 矛盾時以 `spec/` 為準，訪談記錄逐字保存不修改 |
| `spec/` | 12 份規格，每份分三節：已定（來源與依據）／規格本文／待對齊 | **有效，實作的唯一依據**。`spec/README.md` 是索引與裁決記錄 |

## DESIGN.md 的效力沿革

- **2026-09-10（R1–R5）**：原版設計本文的五項核心結構被推翻：

  | 原版設計本文寫的 | 現行（spec/） |
  |---|---|
  | 八個 phase | 七個（Explore／Prototype*／Spec／TDD／Build／Review／Wrap） |
  | 四個承諾點 | 三個（Explore／Spec／Review） |
  | 17 個專屬 agent | 2 個 general-purpose agent（`worker`／`reviewer`） |
  | external／internal 兩層 skill | 8 個平鋪 external skill ＋ `references/` 純 markdown |
  | `approved-artifact` ESC 路由 | waterfall 自動退回，ESC 僅剩三種 |

- **2026-09-14（R6）**：裁定不改寫，DESIGN.md 降為歷史文件。
- **2026-09-21（R14）**：推翻 R6 的「不改寫」部分——設計本文十章依現行
  `spec/` 整體改寫為**設計總覽**（原版全文見 git 歷史）。自此影響設計結構的
  裁決須同步回寫 DESIGN.md（`spec/README.md`「DESIGN.md 回寫記錄」）。

訪談逐字記錄 Q1–Q40 逐字保存不修改，它仍是唯一無法從 `spec/` 反推重建的
內容——要追溯某條規格為什麼長這樣、使用者當初的原話是什麼，看那一節。

完整的裁決演進與承襲對照在 `spec/README.md`。
