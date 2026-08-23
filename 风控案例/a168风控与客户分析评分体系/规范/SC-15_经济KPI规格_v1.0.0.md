# SC-15 · 经济 KPI 规格 v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**性质**：规格冻结（**不改任何既有档**）
**上游**：`§ECON`（`v11.0.1` 在册）／`经济指标字典 v1.0.0`／`经济结果层·粒度对齐规格 v1.0.0`
**总纲**：**十五类各自须有 `ROI／AVG／RATE` 等经济 KPI；名可统一，式须按 grain 锁定。**

---

## 〇、对裁示本身之五处斧正（R4）

### R4-1 · `offset_rate` 之定义有误，会把「同向同额」误判为对冲

裁示第四节写作：

$$\text{offset\_rate} = 1 - \frac{|stake_1 - stake_2|}{stake_1 + stake_2}$$

此式量的是**金额对称度**，**与方向无关**。两人同押庄、金额相等者，此式亦得 1.0——而那是**跟注**，不是对冲。

**斧正为二分**：

| 指标 | 式 | 量什么 |
|:--|:--|:--|
| `stake_symmetry` | $1-\dfrac{\lvert stake_1-stake_2\rvert}{stake_1+stake_2}$ | 金额对称度（裁示原式，正名） |
| **`pnl_offset_rate`** | $1-\dfrac{\lvert pnl_1+pnl_2\rvert}{\lvert pnl_1\rvert+\lvert pnl_2\rvert}$ | **盈亏抵销度** |

**对打之经济指纹须三条同时成立**：`opposite_rate` 高（方向相反）∧ `stake_symmetry` 高（金额相当）∧ `pnl_offset_rate` 高（盈亏抵销）。缺任一条皆非对冲。

### R4-2 · `Exposure = Stake × P(Risk)` 把流水当成了损失

$$\text{Stake} \ne \text{Loss}$$

流水是**周转量**，不是**风险金额**。乘上概率只得「预期在险周转」，非「预期在险金钱」。正式定义：

$$\mathbb{E}[L] \;=\; P(\text{Risk}) \times \mathbb{E}[L \mid \text{Risk}], \qquad
\mathbb{E}[L \mid \text{Risk}] \;=\; \text{stake} \times \bigl(\hat{\mu}_i - \mu_0\bigr)$$

其中 $\hat{\mu}_i$ 为该主体**收缩后**之前瞻 ROI，$\mu_0 = -\text{hold\%}$ 为零假设。**只有超出 $\mu_0$ 的那一部分才是损失**；其余是赌场本来就该赚到而没赚到的抽水，属经营常态。

> 此误与「GGR ＝ 利润」同类：**把营收当利润，把流水当损失。** 二者皆须在本册第一节即封死。

### R4-3 · `Hold ≡ −ROI` 有适用边界，须写明

该恒等式**只在分子分母同源时成立**（皆取本金口径）。若日后 `hold` 改以**洗码量**为分母（casino 惯用 handle 口径），则分母不同，**恒等式立破**。故：

- 本册一律锁 `hold_stake_based`（本金口径）；
- 若增 `hold_validbet_based`，须另立列名，**禁与前者互代、禁沿用同一恒等式**。

### R4-4 · 裁示违反了自己援引的「禁跳级」

裁示第十九节援引本项目版本纪律判为 **MAJOR**，随即写作 `registry_risk_typology_v2.0.0` —— 由 `v1.5.0` **直跃 `v2.0.0`，跳过整个 `v1.x` 阶梯**，正是纪律第一之二所禁。

**正确路径**：

```
v1.5.0（现，LOCKED）
   ↓ PATCH：只登记本规格之指针与 gate 之定义，不新增任何字段
v1.5.1
   ↓ MINOR：新增 economic_metrics: 区块（additive，既有字段一字不动）
v1.6.0
   ↓ MAJOR：仅当须改既有字段名／语义／删字段时方晋
v2.0.0
```

**前置待查**：`registry_loader.R`（v1.4.1）对 YAML 键系**子集读取**（忽略未知键）抑或**全等校验**（遇未知键 STOP）？

- 子集读取 → 新增 `economic_metrics:` 为 additive → **`v1.6.0` 即可**，无须 `v2.0.0`；
- 全等校验 → loader 须先升版，**loader 升版在前、登记册升版在后**。

查明前一律按严处理，但**不得因此跳级**。

### R4-5 · `ltv_365d` 属 NOT RECOVERABLE，非 UNKNOWN

139 日窗内不含第 366 日，故 `ngr_365d`／`ltv_365d` **不是「数据不足」，是「窗口结构上不存在该期间」**。二者判级不同、处置不同：

| 判级 | 含义 | 处置 |
|:--|:--|:--|
| `UNKNOWN` | 数据或列缺，补齐即可算 | 列入解锁清单 |
| **`NOT_RECOVERABLE`** | **窗口／口径结构上不可得** | **禁列入解锁清单，须换窗方可** |

混为一谈者，会误以为「再补几列就能算 LTV」。

---

## 一、六族 ＋ 一族：经济 KPI 之骨架

| 族 | 答什么 | 代表指标 |
|:--|:--|:--|
| **E1 规模 Scale** | 涉及多少资金／多少次 | `stake_*`、`n_orders`、`n_days`、`n_shoes` |
| **E2 强度 Intensity** | 做得多密集 | `*_rate`、`*_share`、`avg_*`、`velocity` |
| **E3 结果 Outcome** | 已经产生什么（**毛利**） | `pnl`、`roi`、`hold`、`ggr` |
| **E4 成本 Cost** | 消耗多少扣项 | `rebate_cost`、`κ × validbet`、`bonus_cost` |
| **E5 净经济 Net** | 真正赚了多少（**净利**） | `ngr` |
| **E6 干预价值 Impact** | 动手能挽回多少 | `expected_loss`、`avoidable_loss`、`intervention_value` |
| **E7 分布 Distribution** | 均值之外的形状 | `median`、`p75/p90/p95/p99`、`max`、`CV`、`top1_share`、`HHI` |

**E7 系裁示第十六、十七节之正式立族。** 理由：

$$\text{avg\_stake}=500,\ p_{99}=80{,}000 \qquad\text{vs}\qquad \text{avg\_stake}=500,\ p_{99}=800$$

**均值相同，商业风险相差两个量级。** 故本册立硬规：

> **凡出 `avg_*` 者，必并出 `median`、`p90`、`p99`、`CV`。单出 `avg` 判 FAIL。**

**集中度**（承 R01 实测：22 人样本中一人独占 GGR 之 66.91%）：

$$\text{HHI}=\sum_i s_i^2,\qquad s_i=\frac{\text{ggr}_i}{\sum_j \text{ggr}_j}$$

⚠ `top1_share = 66.91%` 系**有偏样本**（`late_share` 降序头部 22 行）之读数，**不得当作全域值**。全域须另算。

---

## 二、命名与定义锁

**其一 · 名可统一，式按 grain。**

```
roi          → 名统一
member_roi   / pair_roi / ip_roi / agent_roi   → 式按 grain 各自锁定
avg_stake    → 名统一
avg_stake_member / avg_stake_pair / avg_stake_ip → 式按 grain
```

**其二 · 会员侧与平台侧分名，禁混。**

| 侧 | 名 | 式 |
|:--|:--|:--|
| 会员 | `member_roi` | `pnl ÷ stake` |
| 平台 | `operator_hold` | `−pnl ÷ stake` |

否则「会员 ROI +2%」极易被读成「公司利润 +2%」。

**其三 · `rate` 须分四类，禁混一族。**

| 类 | 例 | 语义 |
|:--|:--|:--|
| 行为率 | `same_table_rate`、`hedge_rate`、`night_rate` | 行为密集度 |
| 资金率 | `risk_stake_share`、`ggr_share` | 资金占比 |
| 成本率 | `rebate_rate`、`bonus_cost_rate` | 扣项占比 |
| 损耗率 | `ngr_drag_rate`、`avoidable_loss_rate` | 净经济侵蚀 |

**其四 · 禁裸 `avg`／禁裸 `rate`／禁裸 `roi`**（无 grain 前缀者一律 FAIL）。

---

## 三、十五类之经济主体（`economic_subject × grain`）

| 类 | 风险类型 | `economic_subject` | `grain` |
|:--|:--|:--|:--|
| T-01 | 同桌聚集 | 会员对 | `uid1 × uid2 × window` |
| T-02 | 荷官—玩家串谋 | 玩家×荷官 | `uid × eid × window` |
| T-03 | 尾投／靴尾 | 会员×分段 | `uid × segment × window` |
| T-04 | 跨账户对打／对冲 | 会员对 | `uid1 × uid2 × window` |
| T-05 | 自我对冲／打水 | 会员 | `uid × window` |
| T-06 | 异常 IP 聚集 | **IP 聚合体** | `ip × window` |
| T-07 | 技术型玩家 | 会员×玩法 | `uid × bet09_class × window` |
| T-08 | 退水／占成套利 | 会员／代理／合约 | `uid ∥ agent × window` |
| T-09 | 代理线自打／养号 | 代理线 | `agent × window` |
| T-10 | 账务恒等式残差 | **账务对象（非会员）** | `record × window` |
| T-11 | 多账户／共享设备 | **账户簇** | `cluster × window` |
| T-12 | 机器人／脚本 | 会员 | `uid × window` |
| T-13 | 夜间异常 | 会员×时段 | `uid × hour_band × window` |
| T-14 | 限红试探 | 会员×限额档 | `uid × limit_tier × window` |
| T-15 | 静默复活／接管 | 会员×前后期 | `uid × pre/post × window` |

**T-10 特别处置**（承裁示第二十二节）：系内控 KRI，非会员风险。**禁塞 `member_roi`／`member_avg`**，改用 `residual_amount`／`residual_rate`／`affected_stake`／`financial_exposure`。

**T-07 特别处置**（承裁示第十二节）：`bet09` 二十三种玩法之**主注与边注 P&L 未拆**。不拆则高胜率主注与高波动边注混算，所谓「技术型」可能只是**高庄家优势边注之统计假象**。须拆 `main_bet_*` 与 `side_bet_*`。

**T-03 特别处置**：已判 `FATAL_PROFILE_ONLY`。加入 `roi_late` 后**绝不得因某批会员赚钱即重新激活**。正确表述：「该会员具备 T-03 画像标签；经济结果层观察到 ROI 为 X」，**不得**写「T-03 风险会员 ROI 为 X」。

---

## 四、`economic_metric_gate` · 三态（非二态）

裁示原设二态（PASS／FAIL）。**须补第三态**，否则会有人为了让 gate 通过而伪造字段。

| 态 | 判据 | 处置 |
|:--|:--|:--|
| `PASS` | E1／E2／E3／E5 各至少一项在册且可算 | 准入商业决策 |
| **`BLOCKED_UPSTREAM`** | **指标已定义，但其源列（`bet16`／`validbet` 之属）尚未交付** | **不得判 FAIL，亦不得判 PASS**；列入解锁清单 |
| `FAIL` | 指标未定义，或定义与 grain 不符，或出裸 `avg`／`rate`／`roi` | 退回重定义 |

**当前实况**：`bet16`（退水）与 `validbet`（洗码）皆未在名单交付，故 **十五类之 E4／E5 目前几乎全数 `BLOCKED_UPSTREAM`**。此系诚实读数，**不得以任何方式粉饰为 PASS**。

---

## 五、逐类经济契约（须补之经济层）

| 类 | E1 规模 | E2 强度 | E3 结果 | E4／E5 成本与净额 | E6 干预 |
|:--|:--|:--|:--|:--|:--|
| T-01 | `stake_pair`、`n_orders_pair`、`avg_stake_pair` | `same_table_rate`、`stake_symmetry`、`pnl_offset_rate` | `roi_1`／`roi_2` **分列**、`ggr_pair`、`hold_pair` | `rebate_cost_pair` → `ngr_pair` | `avoidable_rebate` |
| T-02 | `stake_uid_eid` | `co_presence_rate` | `hold_gap_vs_dealer_mean` | — | `excess_ggr_loss` |
| T-03 | `stake_late`／`stake_early` | `late_share` | `roi_late`／`roi_early`、`hold_late`／`hold_early` | — | ❌ 禁作触发器 |
| T-04 | `stake_pair`、`p90/p99_stake_pair` | `opposite_rate`、`hedge_coverage`、`pnl_offset_rate` | `roi_1`／`roi_2`、`ggr_pair` | **`rebate_leakage`** | `avoidable_loss` |
| T-05 | `stake`、`avg/median/p90/p99` | `hedge_rate`、`rebate_dep` | `roi`、`ggr` | **`rebate_cost` → `ngr`** | `intervention_value` |
| T-06 | `stake_ip`、`n_members_eff`、`avg_stake_ip` | `member_share`、`stake_share` | `ggr_ip`、**`hold_gap_vs_domain`** | — | `economic_exposure` |
| T-07 | `main/side` 分拆之 `stake`、`p99_stake` | `side_bet_share` | `main_bet_roi`／`side_bet_roi`、`profit_stability` | — | `expected_loss` |
| T-08 | `stake`、`validbet` | **`rebate_rate`、`rebate_over_ggr_pct`** | `ggr` | **`rebate_cost`、`κ×validbet` → `ngr`、`roi_net`** | **`rebate_drag`** |
| T-09 | `agent_stake`、`n_downline` | `retention_rate` | `agent_ggr` | `agent_ngr`、`cost_per_member` | `ltv`（⚠ 见 R4-5） |
| T-10 | `affected_stake` | `residual_rate` | `residual_amount` | — | `financial_exposure` |
| T-11 | `combined_stake`、`n_accounts` | `device_share`、`multi_account_rate` | `combined_roi`、`combined_ggr` | — | `economic_exposure` |
| T-12 | `stake`、`avg_stake` | `interval_cv`、`burst_rate` | `roi`、`ggr` | `automation_cost` | `avoidable_cost` |
| T-13 | `night_stake` | `night_rate` | `night_roi`、`night_ggr` | — | `night_exposure` |
| T-14 | `stake_to_limit` | `limit_hit_rate` | `roi` | — | `expected_liability` |
| T-15 | `pre/post_stake` | `stake_jump_rate` | `pre/post_roi`、`ggr_change` | — | `economic_exposure` |

---

## 六、V 轴升三轴（承裁示第十五节）

现行 `V = stake_all` 单轴。**升为三轴，且优先级函数不得退化为 `Priority = Stake`**：

```
V1 · Risk Likelihood   P(Risk | Evidence)
V2 · Economic Exposure 见 R4-2 之正式定义（禁用 Stake × P）
V3 · Economic Impact   avoidable_loss、intervention_value
```

$$\text{Priority}=f\bigl(\text{Evidence},\ V_1,\ V_2,\ V_3\bigr)$$

**原 V 轴之限界须原样保留**：`stake` 之高 AUC 部分反映「谁被复核得多」而非「谁更危险」，**不得作因果证据**。

---

## 七、施工路线与优先级

```
P0  本规格冻结（本册）                              ← 已完成
P1  名单增列 bet16（退水）＋ validbet（洗码）        ← 解锁 E4／E5，最高
P2  registry v1.5.1（PATCH）→ v1.6.0（MINOR，additive economic_metrics）
P3  各交付件按 grain 落地经济列（SQL 总包 MINOR／MAJOR）
P4  Economic QA → NGR／expected_loss／intervention_value
P5  风险评分：Priority = f(Evidence, V1, V2, V3)，禁 f(ROI)
```

**当前不产出任何 SQL、不改任何登记册、不改版本纪律。** 先定口径，再动代码。

---

## 八、四条不变之锁

1. **GGR ≠ 利润 ≠ 经济价值。** 四件解锁前一律写「平台毛利 GGR」。
2. **流水 ≠ 损失。** `Exposure` 须按 R4-2 之式，禁用 `Stake × P(Risk)`。
3. **经济指标一律 `economic_role = OUTCOME／PRIORITIZATION`**，答「造成什么后果」，不答「为何命中」。判据仍归各 T 类自身。
4. **`roi > 0` 不是任何一类之判据。** 零假设下会员 ROI 之期望非 0 而为 $\mu_0=-\text{hold\%}$；据之出名单行处置者判 **S1 FATAL**。
