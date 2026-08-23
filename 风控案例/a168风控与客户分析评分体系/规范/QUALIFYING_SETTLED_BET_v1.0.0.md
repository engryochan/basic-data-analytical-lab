# `QUALIFYING_SETTLED_BET` · Numerator Layer 第一闸 · v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**ARTIFACT CLASS**：`A3 SPEC`　**canonical**：`false`
**承**：`Topology_Resolution_T07_T14_v1.0.0.md`
**范围**：**只定义「什么能进入分子」，不趁机增加指标**（裁示纪律）

---

## 〇、★★★ 立册之由 · 实测揭出 canonical 内已有**四套 `win_rate`，两种分母**

| 出处 | 式 | 分母之义 | `push` |
|:--|:--|:--|:--|
| `§R-03` 行 4531 | `n_win / n_dec` | 决胜局（**已排除退还局**） | **EXCLUDE** |
| `§DX-04` 行 5938 | `SUM(pnl>0) / SUM(pnl<>0)` | 净输赢非零者 | **EXCLUDE** |
| `§R03b` 行 6145 | `SUM(pnl>0) / SUM(pnl<>0)` | 同上 | **EXCLUDE** |
| **`§P11` 行 9431** | **`win_orders / total_orders`** | **全部注单** | **INCLUDE** |

$$\text{同一名 } \texttt{win\_rate}\text{，四处之中三处一义、一处另义}$$

**二式之别：**

$$\text{EXCLUDE：} \frac{W}{W+L} \qquad\qquad \text{INCLUDE：} \frac{W}{W+L+P}$$

**以百家乐和局率约 9.5% 计**（`Tie` 命中 9.47% 实测）：

$$50.11\% \quad\text{vs}\quad 45.35\% \qquad \boxed{\text{差 } 4.76\text{ pp}}$$

★★ **且 canonical 行 4081 已明书**：

> **`win_rate_3state`（胜／负／和三态，**禁二态**）**

**规范要求三态，而现有四处实现皆非三态**——三处二态（EXCLUDE）、一处含混（INCLUDE）。

> **这正是裁示所诫「`push` 埋在 `CASE WHEN` 里」之实况——不是将来会发生，是已经发生了。**

---

## 一、`QUALIFYING_SETTLED_BET` 之集合定义

$$\text{QSB} = \text{settled} \wedge \text{valid} \wedge \neg\text{cancelled} \wedge \neg\text{void} \wedge \neg\text{rebet} \wedge \neg\text{testline} \wedge \text{push 有明确处置}$$

**硬约束**：

$$\text{numerator} = \text{QSB} \cap \text{win} \qquad \text{denominator} = \text{QSB} \cap \text{settled outcomes}$$

**同一 QSB universe，不得分子取 A 集、分母取 B 集。**

---

## 二、逐项 `INCLUDE ／ EXCLUDE ／ UNKNOWN`（★ 禁因「看起来应该如此」直接归类）

| # | 项 | 判 | 据 | 缺口 |
|--:|:--|:--|:--|:--|
| 1 | **测试线** | **EXCLUDE** | 铁律④b `age022='1'`，五级 `LEFT JOIN`；`§M0-2b` 实测命中 11,739 | 无 |
| 2 | **重对单 rebet** | **EXCLUDE** | `bet38='N'` 为准入，canonical 54 处一致 | 无 |
| 3 | **一般单** | **INCLUDE** | `category='1'`，canonical 全包一致 | ⚠ `category` 其余取值之语义**未普查** |
| 4 | **汇率有效** | **INCLUDE** | `bet11>0`；`§M0-2b` 实测该闸砍 0 行 | 无 |
| 5 | **本金为正** | **INCLUDE** | `bet13>0`；`§M0-2b` 实测该闸砍 0 行 | 无 |
| 6 | **最新版本** | **INCLUDE** | `rn=1`；`§M0-6` 已证 `n_tie=0`，地基成立 | 无 |
| 7 | **`push`／和局退还** | **`UNKNOWN`** | ★★ 见第三节 | **四处实现不一致** |
| 8 | **取消单 cancelled** | **`UNKNOWN`** | canonical 代码层 `cancel` 仅 4 处，**无判别字段** | **判别字段未定** |
| 9 | **无效单 void** | **`UNKNOWN`** | 同上 | **判别字段未定** |
| 10 | **未结算 unsettled** | **`UNKNOWN`** | 代码层 0 处；`category='1'` **是否已含「已结算」之义未证** | **结算态判别未定** |
| 11 | **`commission` 哨兵值** | **EXCLUDE** | `§M0-4` 实测 31 笔（0.0000247%），定性为上线测试期未初始化 | 无 |
| 12 | **上线测试单** | **EXCLUDE** | `§M0-3`：2026-07-20 七注型各 1 笔 | 无 |
| 13 | **`Tip_1_`** | **`UNKNOWN`** | ★ `§M0-5b` 实测：`bet13>0` 100%、`bet14=0` 100%、零命中 | **性质 `UNKNOWN`，禁径判小费** |

**已定 8 项 ／ `UNKNOWN` 5 项。**

★ **第 3 项之缺口须记**：全包以 `category='1'` 为准入，惟**其余取值代表什么，从未普查**。若 `category='2'` 恰是「已取消」，则第 8 项自解；若不是，则取消单**现仍混在 `category='1'` 内**。**此为一条可自解之工单。**

---

## 三、★ `push` 之显式契约（不得埋于 `CASE WHEN`）

**锁四十一 · `push` 之处置须为 contract 之显式字段。**

三种合法契约，**须择一明书，禁默认**：

| 契约 | 式 | 义 | 用处 |
|:--|:--|:--|:--|
| **A · 三态**（canonical 行 4081 所要求） | `win / (win + loss + push)` 并同出 `push_rate` | 押注命中率 | **规范指定** |
| **B · 二态** | `win / (win + loss)` | 决胜局胜率 | `§R-03` Z-score 之基准 |
| **C · 经济态** | `pnl>0 / pnl<>0` | 净输赢方向率 | `§DX-04`／`§R03b` |

$$\text{A} \ne \text{B} \ne \text{C}\text{，三者数值与业务意义皆不同}$$

★★ **B 与 C 看似等价，实则不然**：
`pnl = 0` 者未必是 push——**亦可能是「赢的金额恰等于佣金」**（`Banker` 收佣 5% 之边缘情形）。**C 式把这类归入分母之外，B 式则视 `n_dec` 之定义而定。**

**故三式须各有其 `metric_id`，禁共用 `win_rate` 一名。**

---

## 四、命名裁定（承锁三十八 · 血统不继承）

| 旧名 | 新名 | 契约 | 状态 |
|:--|:--|:--|:--|
| `win_rate`（`§R-03`） | `decisive_win_rate` | B | `PENDING_VALIDATION` |
| `win_rate_base`（`§DX-04`） | `pnl_positive_rate` | C | `PENDING_VALIDATION` |
| `win_rate`（`§R03b`） | `pnl_positive_rate_daily` | C | `PENDING_VALIDATION` |
| `win_rate`（`§P11`） | **⚠ 须先定其 `push` 之意图** | ? | **`UNKNOWN`** |
| `win_rate_all`（T-07） | `qualified_win_rate` | **A（三态）** | `PENDING_VALIDATION` |

**四者皆 `evidence_tier = UNKNOWN` 自零起算，禁自旧条目继承任何一栏。**

★ **`§P11` 之 `win_orders / total_orders`**：其分母系全部注单，**但 `total_orders` 是否已含 QSB 之六项基础闸，须回查原文**。若未含，则该式**连测试线与重对单都在分母里**——较 `push` 之争更严重。**已开工单。**

---

## 五、T-14 之 numerator（同批立，惟证据未闭合）

```
post-treatment exposure  →  qualified post bets  →  post stake / post validbet
                         →  post profit          →  ROI_post
```

**★ 零暴露之判词（承 `§VB-41b` 之「零对零 ≠ 有值相同」）：**

$$\text{exposure} = 0 \;\Longrightarrow\; \boxed{\texttt{NO\_EXPOSURE}} \qquad \textbf{禁写 } \texttt{ROI\_post} = 0\%$$

**契约态：**

```
contract           可定义
evidence           未闭合（effective_limit 之 PIT 未重建，BLOCKED(B-09)）
decision admission FALSE
```

**★ 公式完整 ≠ 可升 `DECISION`。**

---

## 六、血统栏（十六栏 · 每一新 metric 须留）

```
metric_id ／ metric_name ／ parent_metric ／ grain ／ numerator ／ denominator ／
qualifying_set ／ source ／ missing_semantics ／ metric_role ／ evidence_tier ／
direction ／ threshold_status ／ admit_to_profile ／ admit_to_feature_scoring ／
admit_to_risk_decision
```

★ `parent_metric` 记血统来源，**惟不得据以继承任何属性**（锁三十八）。

---

## 七、本闸之出口条件

**QSB 闸开之前，须先闭五项 `UNKNOWN`：**

| # | 项 | 解法 | 可自解否 |
|--:|:--|:--|:--|
| 7 | `push` | 择 A／B／C 三契约之一，逐指标明书 | ✅ **可裁定** |
| 8 | 取消单 | 普查 `category` 全部取值 | ✅ **可实测** |
| 9 | 无效单 | 同上 | ✅ **可实测** |
| 10 | 未结算 | 同上 ＋ 验 `category='1'` 是否已含结算义 | ✅ **可实测** |
| 13 | `Tip_1_` | 上游确认 | ❌ 须外部 |

**四项可自解，一项须外部。**

$$\boxed{\text{下一刀：`category` 全取值普查——它一条可闭三项 UNKNOWN}}$$

---

## 八、口诀

> **同一 qualifying universe 是硬约束；push 不得埋于 CASE WHEN；三态非二态，二态非经济态；先把集合钉死，再谈计算；先把血统钉死，再谈阈值。**

**本册二锁**：

> **锁四十一**：`push` 之处置须为 contract 之显式字段，禁默认、禁埋于 `CASE WHEN`。
> **锁四十二**：`pnl = 0` ≠ `push`——亦可能是赢额恰等于佣金。**经济态与胜负态不可互代。**

---

```
QUALIFYING_SETTLED_BET   已定 8 ／ UNKNOWN 5
四套 win_rate            已揭，四者须各立 metric_id
v11.0.3                  LOCKED ／ 03E774DE ／ 未触一字
v11.0.4  不启动    registry  不改    B-5  不动    T-15  NOT_IDENTIFIABLE
```
