# 01｜Plugin 結構規格

> 依 PROMPT.md 第 4 步規定，本檔分三節：已定、規格本文、待對齊。

## 一、已定（來源與依據）

- **R1／R4／R5（2026-09-10 重構裁決，見 `spec/README.md`）**：七 phase（Explore／Prototype*／Spec／TDD／Build／Review／Wrap，`*` 為 optional）；internal skill 廢止、改為 `references/` 純 markdown 文件；agent 收斂為 `worker`／`reviewer` 兩個 general-purpose agent。
- **Q17**：Repo 自帶 marketplace——本 repo 同時是 marketplace 根目錄與 plugin 根目錄。
- **research 01 §1.1**：`plugin.json` 的 `skills` 欄位不宣告時，預設掃描 `skills/` 目錄；`agents` 欄位不宣告時，預設掃描 `agents/`。R4 之後 skills 平鋪於 `skills/` 下，兩個欄位皆可省略。
- **research 05 實驗五**（【證實】）：`claude plugin validate <path>` 只驗證明確指定的路徑，不遞迴；不檢查未知欄位、不檢查 plugin agent 誤用 `hooks`／`mcpServers`／`permissionMode`。
- **Q36**：agent 命名衝突不做啟動掃描。**R11 修正**：該風險經實測不成立（`research/11` §2），風險說明已改寫；不做掃描的裁決維持。
- **R11（2026-09-14 裁決，見 `spec/README.md`；證據 `research/11-agent-namespace-and-builtins.md`）**：撞名風險敘述（§2.4）依實測改寫——命名空間並存、不覆蓋；`agents/` 保留不廢除。
- **R10（2026-09-14 裁決，見 `spec/README.md`）**：README 中英分家——`README.md` 英文為主檔、`README.zh-TW.md` 繁中對照，兩份章節結構逐節對齊；各含兩張 mermaid 圖（七 phase 流程與三承諾點、品質迴圈與退回判定）。
- **R9（2026-09-14 裁決，見 `spec/README.md`）**：分類／檢索欄位全部移除——`plugin.json` 的 `keywords`（§2.1）、`marketplace.json` 的 `category`／`tags`（§2.2）。
- **R8（2026-09-14 裁決，見 `spec/README.md`；證據 `research/10-validate-targets.md` §5）**：`CLAUDE.md` 自 repo 根移至 `.claude/CLAUDE.md`，消除 validate 誤報並讓 `--strict` 可用；`.gitignore` 同步改為 `.claude/*` ＋ `!.claude/CLAUDE.md`。版本號在正式發佈前一律維持 `0.1.0`（使用者裁決）。
- **R7（2026-09-14 裁決，見 `spec/README.md`；證據 `research/10-validate-targets.md`）**：§2.5.1 驗證程序依實測改寫——`claude plugin validate .` 在雙 manifest 下只驗 marketplace，改為明確指向 `.claude-plugin/plugin.json`；該指令會遞迴驗證所有 skill／agent，故原表中 `./agents`／`./skills` 兩列刪除。
- **R6（2026-09-14 裁決，見 `spec/README.md`）**：開發流程文件（`PROMPT.md`／`DESIGN.md`／`research/`／`spec/`）收攏至 `context/`；新增 `CLAUDE.md`（位置見 R8）。採非隱藏目錄名而非 `.context/`，因 ripgrep 與 shell glob 預設跳過 dot 目錄，會使實作期每次都要讀的 `spec/` 退出預設搜尋範圍。
- 原「巢狀 skills 分組目錄需最小驗證」段落（舊版 §2.6）隨 R4 平鋪結構**廢止**：不再有 `skills/external/`／`skills/internal/` 分組，預設 `skills/` 掃描是文件明載行為，無需額外驗證。

---

## 二、規格本文

### 2.1 `.claude-plugin/plugin.json` 目標內容

```json
{
  "$schema": "https://anthropic.com/claude-code/plugin.schema.json",
  "name": "agent-flow",
  "version": "0.1.0",
  "description": "Waterfall spec-driven development workflow: seven phases (Explore, Prototype [optional], Spec, TDD, Build, Review, Wrap), three approval gates, independent quality loops with automatic fallback to the faulty phase, dispatched from a main-session orchestrator to two general-purpose agents (worker/reviewer).",
  "author": { "name": "wiasliaw", "email": "wiasliaw@protonmail.com" },
  "repository": "https://github.com/wiasliaw/agent-flow",
  "license": "MIT"
}
```

- **`keywords` 移除（R9）**：與 §2.2 的 `category`／`tags` 同一裁決——三個分類／檢索欄位全部不保留。
- **`skills` 欄位移除**（相對舊版 `["./skills/external", "./skills/internal"]`）：R4 之後 skills 平鋪於預設位置 `skills/<name>/SKILL.md`，走預設掃描即可。
- **`agents` 欄位不宣告**：2 個 agent 檔放預設位置 `agents/*.md`。
- **`references/` 不需要在 manifest 宣告**：純參考文件，不是 plugin 元件，由 skill／派工 prompt 以路徑指名 `Read`。

### 2.2 `.claude-plugin/marketplace.json` 目標內容

```json
{
  "name": "agent-flow",
  "owner": { "name": "wiasliaw", "email": "wiasliaw@protonmail.com" },
  "description": "Marketplace for the agent-flow plugin (this repository is the plugin)",
  "plugins": [
    {
      "name": "agent-flow",
      "source": "./",
      "description": "Waterfall spec-driven development workflow with automatic fallback and independent quality loops",
      "version": "0.1.0",
      "author": { "name": "wiasliaw" },
      "repository": "https://github.com/wiasliaw/agent-flow",
      "license": "MIT"
    }
  ]
}
```

- **`category`／`tags` 移除（R9）**：與 §2.1 的 `keywords` 同一裁決。實測 `claude plugin validate --strict` 對「有／無」兩種版本都通過、不做區別（與 research 05 實驗五「不查未知欄位」一致），故此處純為取捨，非技術限制。

### 2.3 完整目錄樹

```
agent-flow/                          # repo 根 = plugin 根 = marketplace 根（Q17）
├── .claude-plugin/
│   ├── plugin.json                  # §2.1
│   └── marketplace.json             # §2.2
├── agents/                          # 2 個 general-purpose agent（spec/03-agents.md）
│   ├── worker.md
│   └── reviewer.md
├── skills/                          # 8 個 external skill，平鋪、預設掃描（spec/05–12）
│   ├── orchestrate/SKILL.md
│   ├── explore/SKILL.md
│   ├── prototype/SKILL.md
│   ├── spec/SKILL.md
│   ├── tdd/SKILL.md
│   ├── build/SKILL.md
│   ├── review/SKILL.md
│   └── wrap/SKILL.md
├── references/                      # 6 份內部參考文件，非 skill（spec/04-references.md）
│   ├── glossary.md
│   ├── state-management.md
│   ├── sdd-guide.md
│   ├── tdd-guide.md
│   ├── dispatch.md
│   └── quality-loop.md
├── context/                         # 開發流程文件，非 plugin 執行期內容（R6）
│   ├── README.md                    # 索引與各文件效力狀態
│   ├── PROMPT.md
│   ├── DESIGN.md                    # 歷史文件，核心結構已被 R1–R5 推翻
│   ├── research/
│   └── spec/
├── .claude/
│   └── CLAUDE.md                    # 本 repo 的開發約定（R6／R8）
├── README.md                        # 對外門面，英文（R10）
└── README.zh-TW.md                  # 繁中對照，章節與 README.md 逐節對齊（R10）
```

`context/` 與 `.claude/CLAUDE.md` 都不是 plugin 元件：`plugin install` 會複製整個 repo，但兩者不被任何 manifest 欄位宣告、不被掃描、不影響 plugin 行為。

**`CLAUDE.md` 必須放 `.claude/` 而非 repo 根（R8）**：放根目錄時 `claude plugin validate` 會發出 `root: CLAUDE.md at the plugin root is not loaded as project context` 警告並使 `--strict` 失敗——那是給「想把 context 隨 plugin 出貨給安裝者」的人看的提示，對本 repo 是誤報。移入 `.claude/` 後警告消失、`--strict` 通過，且專案 context 照常載入（research 10 §5 實測）。

**`.gitignore` 必須排除 `.claude/` 的其他內容但保留 `CLAUDE.md`**：
```
.claude/*
!.claude/CLAUDE.md
```
寫成 `.claude/` 會連同 `CLAUDE.md` 一起忽略，開發約定就進不了版控；寫成 `.claude/*` 才能用後續的否定規則挖回單一檔案。`.claude/settings.json` 維持忽略（那是個人環境設定）。

**執行期目錄（不屬於本 repo）**：`.agent-flow/`（`specs/`、`changes/`、`archive/`）產生於安裝後的使用者專案根目錄，結構見 `spec/02-state.md`。

### 2.4 安裝流程

```bash
$ claude plugin marketplace add wiasliaw/agent-flow
$ claude plugin install agent-flow@agent-flow
```

- 安裝後可用指令：`/agent-flow:orchestrate` 與七個 `/agent-flow:<phase>`（`explore`／`prototype`／`spec`／`tdd`／`build`／`review`／`wrap`）。
- Scope 選擇（user／project／local）與旅程主情境（user scope）沿用 Q17。
- **命名衝突：命名空間已提供保護（R11 修正 Q36 的風險敘述）**：舊版記載「使用者專案或個人層級的同名 agent 會悄悄取代本 plugin 的定義」——**實測不成立**（`research/11` §2【證實】）。同名的專案 agent 與 plugin agent **並存**：專案版佔用裸名 `worker`，plugin 版維持 `agent-flow:worker`，各自定址到自己的定義。`research/01` §7.4 引述的「覆蓋」描述的是遷移情境（把 `.claude/agents/` 搬進 plugin 卻未刪原檔，裸名引用會解析到專案副本）。
  - 殘留風險只有一種且性質不同：**主 session 把派工目標誤寫成裸名**（`worker` 而非 `agent-flow:worker`）時會打到使用者自己的 agent。這是派工紀律問題——`references/glossary.md` 的 `dispatch` 原語已明文規定一律使用命名空間形式。
  - Q36「不做啟動掃描」的裁決因風險消失而自然成立，不需變更。

### 2.5 `claude plugin validate` 的使用與其檢查不到的項目

#### 2.5.1 驗證程序（R7，依 research 10 改寫）

兩道指令即完整涵蓋所有 plugin 元件：

| 驗證對象 | 指令 | 驗證內容 |
|---|---|---|
| Plugin manifest ＋ 全部元件 | `claude plugin validate .claude-plugin/plugin.json` | `plugin.json` 已知欄位缺漏與 JSON 合法性，**並遞迴驗證 2 個 agent 與 8 個 skill** 的 frontmatter 可解析性與 `description` |
| Marketplace manifest | `claude plugin validate .claude-plugin/marketplace.json` | 必填欄位、`plugins[].source` 格式 |

三項必須知道的行為（全部【證實】於 research 10）：

1. **不得使用 `claude plugin validate .`**。本 repo 的 `.claude-plugin/` 同時有兩份 manifest，指到目錄時 marketplace 優先，`plugin.json` 永遠驗不到。必須明確指到檔案路徑。
2. **`./agents`／`./skills` 兩道已廢止**，非因失效而是多餘——第一道指令已完整涵蓋，且元件有錯時 exit code 為 1。目錄型驗證仍可用，但目錄 basename 必須是 `skills`／`agents`／`commands`。
3. **輸出只列出有問題的元件**，乾淨的元件不會出現在輸出中。「沒列出 skills／agents」代表全部通過，不代表沒被掃描。

任何一次回報失敗立即修正，不累積（PROMPT 第 5 步）。兩道指令在現行結構下均零警告，故 `--strict` 可直接用於 CI（R8 之前因根目錄 `CLAUDE.md` 觸發誤報而不可用，該問題已由 §2.3 的 `.claude/` 擺放方式解決）。

#### 2.5.2 `validate` 檢查不到的項目與補強要求

§2.5.1 的遞迴涵蓋不改變以下兩項缺口——檢查深度仍然很淺（research 05 實驗五、research 10 §4）：

1. **未知欄位**與 **plugin agent 誤用 `hooks`／`mcpServers`／`permissionMode`**：`validate`（含 `--strict`）完全不查（research 05 實驗五）。規格要求：`agents/` 完成後另跑一次機械檢查，斷言兩個 agent 檔的 frontmatter key 集合不含這三個欄位。
2. **`references/` 目錄**：不是 plugin 元件，`validate` 完全不涉及。規格要求：同一道機械檢查需一併斷言 `references/` 下 6 個檔案（§2.3 清單）全部存在——skill 與派工 prompt 以路徑指名這些檔案，缺檔會在執行期才爆出 `Read` 失敗。

檢查手段的實作形式（shell script／CI）留給實作階段選最簡單做法。

---

## 三、待對齊

無。本檔內容可追溯至 R1／R4／R5／R6／R7／R8／R9／R10／R11、Q17、Q36 與 research 01／05／10／11；巢狀分組驗證段落的廢止是 R4 平鋪結構的直接推論。
