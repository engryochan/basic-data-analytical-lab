# 经济指标字典 · 自 `R01_late_shoe.csv` 逐字段登记 v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**性质**：口径登记（§ECON 之 STEP 3／STEP 4 填实）

**解锁声明**：§ECON 第八节曾锁「STEP 1（`§R01-0` ＋ `§R01-0b`）未执行前，禁以 R01 之 `roi`／`avg` 口径为其余 14 类之模板」。该前置**已于 2026-08-23 结案**（R01 粒度 CLOSED／OBSERVED，见 `v11.0.1` 之 §Z-16 与 `审计/G4G5_注释纠错_diff`），故本册得以落笔。

---

## 一、总答：这份 CSV 只到**毛利**，到不了**净利**

赌场之真实经济价值不是 GGR，是 **NGR**：

$$\mathrm{NGR} \;=\; \mathrm{GGR} \;-\; \underbrace{\text{退水}}_{\texttt{bet16}} \;-\; \underbrace{\text{占成}}_{\kappa \times \text{洗码}} \;-\; \underbrace{\text{红利／通道／风险成本}}_{\text{另表}}$$

而 `R01_late_shoe.csv` 之十五列里，**上式右侧三项一项都没有**。故：

> **本档可算之「经济价值」，止于 GGR（毛利），且只是本金口径之博彩毛利，不含任何成本扣项。**
> 把 GGR 当成经济价值汇报，是把营收当利润 —— 此为本册要防的头号误读。

---

## 二、可算者（七要素登记 · 全部 OBSERVED）

**在册十五列**：`late_def`／`uid`／`n_orders_all`／`n_orders_late`／`late_share`／`shoe_pos_p50`／`stake_late_avg`／`stake_early_avg`／`stake_ramp`／`roi_late`／`roi_early`／`stake_late`／`game_pnl_late`／`stake_all`／`game_pnl_all`

| 指标 | 粒度 | 窗口 | 分子 | 分母 | 零分母 | 角色 |
|:--|:--|:--|:--|:--|:--|:--|
| `n_orders` | member | 分析窗 | `n_orders_all` | — | — | OUTCOME |
| `stake_sum` | member | 分析窗 | `stake_all` | — | — | OUTCOME |
| `pnl_sum`（会员侧） | member | 分析窗 | `game_pnl_all` | — | — | OUTCOME |
| **`ggr`（平台侧）** | member | 分析窗 | **`−game_pnl_all`** | — | — | **OUTCOME** |
| `stake_avg` | member | 分析窗 | `stake_all` | `n_orders_all` | NULL | OUTCOME |
| `pnl_avg` | member | 分析窗 | `game_pnl_all` | `n_orders_all` | NULL | OUTCOME |
| `roi_all` | member | 分析窗 | `game_pnl_all` | `stake_all` | NULL | OUTCOME |
| **`hold_pct`** | member | 分析窗 | `−game_pnl_all` | `stake_all` | NULL | OUTCOME |
| `stake_late` | member·晚段 | 分析窗 | `stake_late` | — | — | OUTCOME |
| `ggr_late` | member·晚段 | 分析窗 | `−game_pnl_late` | — | — | OUTCOME |
| `stake_early`（派生） | member·早段 | 分析窗 | `stake_all − stake_late` | — | — | OUTCOME |
| `ggr_early`（派生） | member·早段 | 分析窗 | `−(game_pnl_all − game_pnl_late)` | — | — | OUTCOME |
| `roi_late`／`roi_early` | member·分段 | 分析窗 | 在册 | 分段本金 | NULL | OUTCOME |

**恒等式（可作校验）**：`hold_pct ≡ −roi_all`；`stake_late + stake_early ≡ stake_all`；`game_pnl_late + game_pnl_early ≡ game_pnl_all`。

**三条尺度锁**：① ROI 为**净收益率**，持平 ＝ 0（非回报倍数）；② 分母恒为**本金口径**（`stake = bet13 ÷ bet11`），非洗码；③ 零假设非 0，而为 `μ₀ = −hold%`。

---

## 三、算不出者（五项，这才是「经济价值」之缺口）

| 缺项 | 所需列 | 缺则算不出 | 判级 |
|:--|:--|:--|:--|
| **洗码量** | `validbet` | 洗码口径之一切指标；`κ × 洗码` 之占成成本 | UNKNOWN |
| **退水支出** | `bet16` | **`NGR = GGR − 退水`**；退水消耗比；打水套利之经济量 | UNKNOWN |
| **占成成本** | 代理线 ＋ `ag012` | 代理分成；线级净利 | UNKNOWN |
| **活跃跨度** | `dt` 粒度 | `active_days`／`active_shoes`／持续性／人均日贡献 | UNKNOWN |
| **注额分布** | `bet_p0/p50/p90/p99` | 限额档位之刻度；`stake_cv`；尾部风险 | UNKNOWN |

**须记明**：本档现有之 `stake_late_avg`／`stake_early_avg` 系**均值**，非分位。均值抹平会员内波动，**不可代分位**用于限额设档——以均注设上限者，对真实尾部注额之削减为**下偏估计**。

**解锁最短路径（四件）**：① 名单增列 `validbet`；② 名单增列 `bet16`；③ 名单增列 `n_days`／`n_shoes`；④ 交付逐员注额分位件。四件到齐，本册方能由「毛利层」升至「净利层」。

---

## 四、实算演示（22 行样本 · ⚠ 有偏，仅示范算术）

> **样本性质**：`late_share` 降序之头部 22 行，**非随机抽样**，不得外推全域。此处只演示「同一批数字如何算出经济价值」。

**域级读数**

| 项 | 值 |
|:--|--:|
| Σ 本金 `stake_all` | 556,093.63 |
| Σ 会员净盈亏 | −9,430.45 |
| **Σ 平台毛利 GGR** | **9,430.45** |
| **域内 `hold%`** | **+1.6958%** |
| Σ 注单 | 11,353 |
| 均注 | 48.98 |

**分段拆解**

| 段 | 本金 | 占比 | GGR | `hold%` |
|:--|--:|--:|--:|--:|
| 晚段 | 529,100.93 | 95.15% | 14,043.86 | **+2.6543%** |
| 早段 | 26,992.70 | 4.85% | −4,613.41 | **−17.0913%** |

⚠ **早段 `hold%` 之 −17% 不是「早段亏钱」，是分母只有 4.85%。** 分段 `hold%` 之方差与分母成反比；跨段比大小前须先同分母，否则必被小分母段的极端值带偏。这正是「分段指标不可直接横比」之实证。

**集中度**

- 会员净赢者 8／22（36.4%），其净赢合计 2,998.52；净输者 14，合计 −12,428.96；
- **贡献 GGR 最大之一人（`uid 136583726`）独占全样本 GGR 之 66.91%**；
- 侵蚀 GGR 最大之一人（`uid 139849308`）令平台净付 937.49。

⚠ **一人占六成七** —— 这正是「暴露加权 ROI」与「逐员等权 ROI」必须并报的理由：前者答「平台赚了多少」（被巨鲸主导），后者答「会员长什么样」（一人一票）。二者互代即误读。

---

## 五、R 侧现算（接上 `R01_late_shoe.csv` 即出）

```r
library(data.table)
M <- fread("数据库/R01_late_shoe.csv", encoding = "UTF-8")
stopifnot("口径锁须单值" = uniqueN(M$late_def) == 1L)

D <- M[, .(uid = as.character(uid),
           n   = as.numeric(n_orders_all),
           stk = as.numeric(stake_all),
           pnl = as.numeric(game_pnl_all),
           stk_lat = as.numeric(stake_late),
           pnl_lat = as.numeric(game_pnl_late))]
D <- D[is.finite(stk) & stk > 0 & is.finite(n) & n > 0]

## 派生（早段 ＝ 全段 − 晚段；恒等式可作校验）
D[, `:=`(stk_ear = stk - stk_lat, pnl_ear = pnl - pnl_lat,
         ggr = -pnl, roi_all = pnl / stk, stake_avg = stk / n)]
D[, hold_pct := ggr / stk * 100]
stopifnot("恒等式 hold ≡ −ROI" = max(abs(D$hold_pct/100 + D$roi_all)) < 1e-9)

## 域级：暴露加权（钱说了算）
mu0  <- sum(D$pnl) / sum(D$stk)          # ＝ −hold%，会员 ROI 之零假设
hold <- -mu0
## 逐员等权（人说了算）——与上式答的不是同一个问题，并报，禁互代
roi_equal <- mean(D$roi_all)

cat(sprintf("会员 %s ｜本金 %s ｜GGR %s ｜hold %+.4f%% ｜μ0 %+.6f ｜等权 ROI %+.6f\n",
            format(nrow(D), big.mark=","), format(round(sum(D$stk)), big.mark=","),
            format(round(sum(D$ggr)), big.mark=","), hold*100, mu0, roi_equal))

## 集中度：前 1% 会员贡献了多少 GGR
setorder(D, -ggr)
k <- ceiling(nrow(D) * 0.01)
cat(sprintf("GGR 前 1%%（%s 人）贡献 %.2f%%\n", format(k, big.mark=","),
            sum(D$ggr[1:k]) / sum(D$ggr) * 100))

## ⚠ 到此为止即是本档之上限：**毛利**。
##   NGR = GGR − 退水 − 占成 − 红利，三项皆不在本 CSV，须待四件解锁。
```

---

## 六、三条读法禁令

**其一 · GGR ≠ 经济价值。** GGR 是毛利；真正可比较的经济量是 NGR。在四件解锁前，一切汇报须写作「**平台毛利 GGR**」，**禁简称「利润」「经济价值」「贡献」**。

**其二 · 分段 `hold%` 不可横比。** 分母越小、方差越大、尾部越极端。早段 −17.09% 与晚段 +2.65% 不构成「早段亏钱」之证据，只反映 4.85% 之分母。

**其三 · 经济指标不是判据。** 本册所列一律 `economic_role = OUTCOME`，答「造成了什么经济后果」；**不答「为何命中」**。以 `roi > 0` 出名单、行处置者判 **S1 FATAL** —— 零假设下会员 ROI 之期望非 0 而为 `μ₀ = −hold%`，「跑赢 0」不等于「跑赢赌场」。

---

## 七、本册之版级与后续

本册为 `v1.0.0`（`规范/`），其后修订循 `v1.0.1 → …`。

与 SQL 总包之关系：本册**不触代码**，故不影响 `v11.0.1` 之任何六元组。四件解锁所需之名单增列，属交付件表头变更 → **`schema_diff` 非空 → MAJOR**，届时须与下游三档 `must=` 同步。
