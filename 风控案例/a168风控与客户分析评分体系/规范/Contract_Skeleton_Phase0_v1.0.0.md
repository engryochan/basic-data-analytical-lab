# `Contract Skeleton` · Phase 0 · v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**ARTIFACT CLASS**：`A3 SPEC`　**canonical**：`false`
**规格**：十五类 × 十二栏　**四态纪律**：`UNKNOWN` ／ `NOT_AVAILABLE` ／ `STRUCTURALLY_FORBIDDEN` ／ `PENDING_VALIDATION`

**铁律**：**不得为填满表格而猜。** 凡未经实测坐实者，一律填四态之一，并注明所据。

---

## 〇、四态之别（承裁示第三节 · 禁混为一）

| 态 | 义 | 处置 |
|:--|:--|:--|
| `UNKNOWN` | **目前不知道** | 可查，须开工单 |
| `NOT_AVAILABLE` | **现有 ODS／数据链无此字段或无从取得** | 须向数据方索取，非 SQL 可解 |
| `STRUCTURALLY_FORBIDDEN` | **该 grain 下数学上无合法定义** | **永久禁用，非「暂缺」** |
| `PENDING_VALIDATION` | **定义可成立，惟上游验证未毕** | 待验，不得先用 |

★ 四者最易混者为二、三。例：

- `TL14_limit_treatment` 之 `ROI` → **`STRUCTURALLY_FORBIDDEN`**
  处置事件粒度**没有投注收益分母**，非「暂时算不出」，是**分母在该 grain 上不存在**。
- `T-11` 之设备指纹 → **`NOT_AVAILABLE`**
  字段本身可定义，惟 ODS 无此列。

---

## 一、`metric_role` 之映射（承裁示第二节 · **role ≠ admission**）

| `metric_role` | `admit_to_profile` | `admit_to_feature_scoring` | `admit_to_risk_decision` |
|:--|:--:|:--:|:--|
| `PROFILE` | TRUE | FALSE | FALSE |
| `STRUCTURAL` | TRUE | **条件式** | FALSE |
| `DECISION` | TRUE | TRUE | **须 contract ＋ validation ＋ causal gate 三闸全过方 TRUE** |

**锁三十四**：`metric_role` 系**分析层角色**，`admit_to_*` 系**资格门禁**。
**禁由角色推出准入**——「某指标是 `DECISION`，故可进风险名单」是错误推论。

---

## 二、Contract Skeleton 主表（十五类 × 十二栏）

### T-01 · 同桌聚集

| 栏 | 值 | 据 |
|:--|:--|:--|
| `grain` | **会员对 × 桌** | registry `§R02`；`R02_same_table.csv` 22 列 |
| `entity` | `member_pair` | |
| `numerator` | 同桌共现局数 | `criteria: same_rate, exp_same` |
| `denominator` | **期望共现局数** `exp_same` | ★ 非「总局数」——`lift` 之分母系期望值 |
| `time_window` | 固定窗 139 日 | |
| `allowed_dims` | 桌台、营业日、注型 | |
| `required_dims` | **会员对两端 ＋ 桌** | 缺一则对不成立 |
| `forbidden_joins` | **禁注单粒度 × 局粒度裸连接**（canonical 行 219／405 明载「矩坍缩替代多对多 JOIN」） | |
| `source` | `ods_a168_bet02` | |
| `missing_semantics` | `UNKNOWN` | 未验：无共现之对，系「未同桌」抑或「未观测」 |
| `metric_role` | `STRUCTURAL` | `lift`／`jaccard` 系富集信号，非决策判据 |
| **阻断** | `BLOCKED(B-01)`；5 判据中 4 `PENDING_INVERSE` | |

### T-02 · 荷官—玩家串谋

| 栏 | 值 |
|:--|:--|
| `grain` | **会员 × 荷官 × 营业日**（canonical 行 348 明载「日粒度」） |
| `entity` | `member_dealer_pair` |
| `numerator` | `delta_z` ／ `delta_p` 之偏离量 |
| `denominator` | **`UNKNOWN`** —— `z_score_w` 之权重口径未定谳 |
| `time_window` | 固定窗 ＋ 日切（**须用营业日 `dt`，禁 `DATE(bet08)`**，后者 38.6% 偏差在册） |
| `required_dims` | 会员、荷官、营业日 |
| `forbidden_joins` | 禁跨日合并荷官场次 |
| `missing_semantics` | `PENDING_VALIDATION` —— `eligibility_status` 之判据待验 |
| `metric_role` | `STRUCTURAL` |
| **阻断** | `BLOCKED(B-02)` ／ `gate = BLOCK` ／ 6 判据中 5 `PENDING_INVERSE` |

### T-03 · 尾投／靴尾下注 ★ REFUTED

| 栏 | 值 |
|:--|:--|
| `grain` | **会员**（canonical 行 3521：`g2` 为 `§R01` 正式分析粒度，本窗内等价 `g1`） |
| `entity` | `member` |
| `numerator` | `late_share` ＝ `late_n(N)` |
| `denominator` | `N` ＝ 该靴实际最大局号（**`shoe_pos` 系 observed position，非 deck-depth**，`Z2-06`） |
| `time_window` | 固定窗 |
| `required_dims` | 靴（`shoe_id` ＋ `table_id`，行 3583 已定跨零点同靴） |
| `forbidden_joins` | — |
| `missing_semantics` | 已定 |
| `metric_role` | **`PROFILE`（强制）** |
| **阻断** | `UNBLOCKED` 惟 `gate = FATAL`；四项独立验证全数否定，AUC 0.3828 方向反转 |
| ★ | **`T-03` 之 `ranking／scoring／trigger／enforcement` 四者皆 `false`，绝对且不可复活（`Z2-08` 五条禁径）** |

### T-04 · 跨账户对打／对冲

| 栏 | 值 |
|:--|:--|
| `grain` | **会员对 × 局** |
| `entity` | `member_pair` |
| `numerator` | `n_opposite_round` 反向共押局数 |
| `denominator` | 该对共同在场局数（`hedge_coverage` 之分母） |
| `time_window` | 固定窗 ＋ 时点（`C06d_hedge_pairs_dated.csv`） |
| `required_dims` | 两会员、局、注向 |
| `forbidden_joins` | 禁与 `T-05` 自对冲混算（**跨账户 vs 单账户，主体不同**） |
| `missing_semantics` | 已定 |
| `metric_role` | `STRUCTURAL` |
| **阻断** | `UNBLOCKED` ／ `gate = ADVISORY`；999 完美对打在册，会员编号中位差 32 |

### T-05 · 自我对冲／打水

| 栏 | 值 |
|:--|:--|
| `grain` | **会员 × 月**（canonical 行 947：与 `§S-05` 同月粒度；行 951 明禁复用 `is_self_hedge`／`hedge_rate` 二名） |
| `entity` | `member` |
| `numerator` | `hedge_rate` 对冲局占比 |
| `denominator` | **`PENDING_VALIDATION`** —— `rebate_dep` 之退水分母待 `bet16` 语义确认 |
| `required_dims` | 会员、月、注向 |
| `forbidden_joins` | **禁与 T-04 共用指标名**（粒度不同，行 951 明载） |
| `missing_semantics` | `PENDING_VALIDATION` |
| `metric_role` | `STRUCTURAL` |
| **阻断** | `BLOCKED(B-11)` —— **`validbet` 契约**（本轮 `§VB` 已推进） |

### T-06 · 异常 IP 聚集

| 栏 | 值 |
|:--|:--|
| `grain` | **IP × 会员** |
| `entity` | `ip` |
| `numerator` | `n_member_eff` **有效会员数** |
| `denominator` | `n_member_raw` 原始会员数 ★ **二者须永久并出**（在册：同阈值下 P64 vs P98.7） |
| `time_window` | 固定窗 |
| `required_dims` | IP、会员 |
| `forbidden_joins` | **禁全网 IP 一刀切**——须分稀疏／高密／CGNAT／白名单／公司网 |
| `missing_semantics` | `UNKNOWN` —— CGNAT 判别字段未验 |
| `metric_role` | `STRUCTURAL` |
| **阻断** | `BLOCKED(B-03)`；4 判据中 **2 `BLOCKED`** |

### T-07 · 技术型玩家

| 栏 | 值 |
|:--|:--|
| `grain` | **会员** |
| `entity` | `member` |
| `numerator` | `win_rate_all` |
| `denominator` | **`STRUCTURALLY_FORBIDDEN`（当前形态）** ★ 见下 |
| `time_window` | 固定窗 |
| `required_dims` | **主注／边注之分**（`bet09` 23 种玩法，主边注 P&L 未分离） |
| `forbidden_joins` | — |
| `missing_semantics` | `PENDING_VALIDATION` |
| `metric_role` | `PROFILE` |
| **阻断** | `BLOCKED(B-04)`；4 判据全 `PENDING_INVERSE` |
| ★★ | **`win_rate_all` 以全部注单为分母者，结构性不成立**：高胜率可纯由玩法结构造成（`Tie` 赔 8:1 命中 9.47%，`Banker` 55.35%）。**须先拆主／边注，否则「整体 ROI」不得作技术能力之据。** |

### T-08 · 退水／占成套利

| 栏 | 值 |
|:--|:--|
| `grain` | **客户分层**（`E02_segment_econ.csv`） |
| `entity` | `member_segment` |
| `numerator` | 退水支出 |
| `denominator` | **`PENDING_VALIDATION`** —— 有效投注口径待 `§VB` 定谳 |
| `time_window` | 固定窗 |
| `required_dims` | 分层键、退水额、有效投注 |
| `forbidden_joins` | **★ 洗码口径（阿泽）与本金口径（雷欧）永久不可合并**（`T-10` 独轨，绝对） |
| `missing_semantics` | `PENDING_VALIDATION` |
| `metric_role` | `STRUCTURAL` |
| **阻断** | `BLOCKED(B-11)` |

### T-09 · 代理线自打／养号

| 栏 | 值 |
|:--|:--|
| `grain` | **代理**（五级链） |
| `entity` | `agent` |
| `numerator` | `member_per_chain` ／ 新增会员质量 |
| `denominator` | 链上会员数 |
| `time_window` | 固定窗 |
| `required_dims` | 五级代理位 `bet18`~`bet22` |
| `forbidden_joins` | **禁相关 `EXISTS`**（StarRocks 不支持）；须五级 `LEFT JOIN` ＋ `COALESCE(...) IS NULL` |
| `missing_semantics` | `UNKNOWN` |
| `metric_role` | `STRUCTURAL` |
| **阻断** | `BLOCKED(B-05)` |
| ★ | 本轮 `§M0-2b` 实测五级命中：`lv1 = 11,739`、**`lv2 = lv3 = lv4 = lv5 = 1,247`（四级同值）——须上游解释** |

### T-10 · 账务恒等式残差 ★ 内控独轨

| 栏 | 值 |
|:--|:--|
| `grain` | **注单**（直算，无中间交付件） |
| `entity` | `bet_order` |
| `numerator` | `resid_identity` ＝ `bet17 − (bet14 − bet13 + bet16)` |
| `denominator` | **`NOT_APPLICABLE`** —— 恒等式残差为绝对量，非比率 |
| `time_window` | 固定窗 |
| `required_dims` | `bet13`／`bet14`／`bet16`／`bet17` |
| `forbidden_joins` | **★ `admit_to_profile = FALSE`；内控独轨，禁入客户画像** |
| `missing_semantics` | 已定 |
| `metric_role` | **`PROFILE`（内控轨，非客户轨）** |
| **阻断** | `UNBLOCKED`；H16 恒等式实测 100% 成立 |

### T-11 · 多账户／共享设备

| 栏 | 值 |
|:--|:--|
| `grain` | **`NOT_AVAILABLE`** |
| `entity` | `UNKNOWN` |
| `numerator` | `NOT_AVAILABLE` |
| `denominator` | `NOT_AVAILABLE` |
| `required_dims` | **设备指纹 → `NOT_AVAILABLE`（ODS 无此字段）** |
| `missing_semantics` | `NOT_AVAILABLE` |
| `metric_role` | `PROFILE` |
| **阻断** | `BLOCKED(B-06)` ／ `gate = BLOCK`；判据含「注册时点邻近度」，registry 标**待建** |
| ★★ | **仅凭 IP 无从区分「多开」与「同网段多住户」。此非阈值问题，系数据缺口。禁以 IP 伪造 `device_score`。** |

### T-12 · 机器人／脚本下注

| 栏 | 值 |
|:--|:--|
| `grain` | **`UNKNOWN`** ★ 见下 |
| `entity` | `member`（暂拟） |
| `numerator` | `下注时点延迟方差` ＝ `bet08 − gi004` |
| `denominator` | **`PENDING_VALIDATION`** —— 须按桌台分层，桌台基线未建 |
| `required_dims` | `bet08`、**`gi004`（可得性未验 → `UNKNOWN`）**、桌台 |
| `forbidden_joins` | 禁跨桌合并延迟分布 |
| `missing_semantics` | `UNKNOWN` |
| `metric_role` | `PROFILE` |
| **阻断** | `BLOCKED(B-07)`；4 判据中 1 `BLOCKED` |
| ★ | **知公式 ≠ grain 成立。** `gi004` 之可得性、覆盖率、与注单之连接关系皆未实测，故 `grain` 判 `UNKNOWN` 而非「会员 × 桌」。 |
| ★★ | `stake_cv` 低既可能是机器人，**亦可能只是对冲玩家**——单指标不可判 |

### T-13 · 夜间异常活动

| 栏 | 值 |
|:--|:--|
| `grain` | **会员 × 营业日** |
| `entity` | `member` |
| `numerator` | `night_share` 夜间注单占比 |
| `denominator` | **`PENDING_VALIDATION`** —— 应为**在线暴露基准**，非总注单数 |
| `time_window` | 固定窗 ＋ 本地时区 |
| `required_dims` | **时区（`§TZ-04b`）、`bet_hour`、在线暴露** |
| `forbidden_joins` | 禁以 UTC 直判夜间 |
| `missing_semantics` | `PENDING_VALIDATION` |
| `metric_role` | `PROFILE` |
| **阻断** | `BLOCKED(B-08)`；2 判据中 1 `BLOCKED` |
| ★ | **「晚上下注多」≠ 异常。** 须 `night_excess = observed − expected_exposure`，而 `expected_exposure` 尚未建 |

### T-14 · 限红试探

| 栏 | 值 |
|:--|:--|
| `grain` | **处置事件**（`TL14_limit_treatment.csv`） |
| `entity` | `treatment_event` |
| `numerator` | 注额贴顶率 ＝ `stake / effective_limit` |
| `denominator` | **`NOT_AVAILABLE`** —— `effective_limit` 须 PIT 重建，现档为**快照** |
| `time_window` | **PIT（须重建，非快照）** |
| `required_dims` | `limit_change_time`、`limit_before`、`limit_after` |
| `forbidden_joins` | **禁以当前快照冒充历史限红** |
| `missing_semantics` | `NOT_AVAILABLE` |
| `metric_role` | `PROFILE` |
| **阻断** | `BLOCKED(B-09)` ／ `gate = BLOCK`；3 判据中 **2 `BLOCKED`** |
| ★★ | **`ROI` 于本 grain ＝ `STRUCTURALLY_FORBIDDEN`** —— 处置事件无投注收益分母，**非暂缺，系结构性不存在** |
| ★★ | **须分「玩家试探」与「平台主动调低」**，否则犯 `Treatment → Feature` 反因果 |

### T-15 · 静默复活／账户接管

| 栏 | 值 |
|:--|:--|
| `grain` | **会员**（生命周期） |
| `entity` | `member` |
| `numerator` | `silent_days` |
| `denominator` | **`PENDING_VALIDATION`** —— 须为**观测跨度**，非窗口长度 |
| `time_window` | 固定窗 139 日 ★ **左截断严重** |
| `required_dims` | `first_seen`、`last_seen`、`observed_span`、`left_censored` |
| `forbidden_joins` | — |
| `missing_semantics` | **`PENDING_VALIDATION`** |
| `metric_role` | `PROFILE` |
| **阻断** | `BLOCKED(B-10)` |
| ★★ | **112,798 人（67.1%）仅现一个月；六月全勤仅 2.01%。** 故 139 日窗内之 `silent_days` **不得径解为「沉睡」**；属左截断者须判 `NOT_IDENTIFIABLE`，**非 `UNKNOWN` 后再猜** |

---

## 三、汇总 · 四态分布

| 栏位 | 已定 | `UNKNOWN` | `NOT_AVAILABLE` | `STRUCT_FORBIDDEN` | `PENDING_VALID` |
|:--|--:|--:|--:|--:|--:|
| `grain` | 12 | 2 | 1 | 0 | 0 |
| `denominator` | 5 | 0 | 2 | 1 | 6 |
| `missing_semantics` | 3 | 3 | 2 | 0 | 7 |

**`grain` 十五类中十二类可定**——较我原先所虑（「大半 `UNKNOWN`」）为佳。

**`denominator` 才是真缺口**：仅 5 类可定，**6 类 `PENDING_VALIDATION`、2 类 `NOT_AVAILABLE`、1 类 `STRUCTURALLY_FORBIDDEN`**。

> **这印证了 `G-METRIC-01`：粒度多半清楚，分母普遍不清楚。**
> **而 ROI／RATE 之正确性，全系于分母。**

---

## 四、阻断映射（Contract → 六阻断）

| 阻断 | 所涉类 | 本轮进展 |
|:--|:--|:--|
| `B-11` `validbet` 契约 | T-05 ／ T-08 | ★ `§VB` 四件已 CLOSED，契约实证已备 |
| `B-04` 主边注分离 | T-07 | 未动 |
| `B-06` 设备指纹 | T-11 | **`NOT_AVAILABLE`，非 SQL 可解** |
| `B-07` `gi004` | T-12 | 可得性未验 |
| `B-08` 在线暴露 | T-13 | 未建 |
| `B-09` 限红 PIT | T-14 | 未建 |
| `B-01/02/03/05/10` | T-01/02/06/09/15 | 皆待阈值反解 |

---

## 五、本册禁做者（承裁示第五节）

```
❌ v11.0.4 大规模加指标        ❌ registry v1.5.x 改判词
❌ 给 UNKNOWN 类型补经验阈值    ❌ 用 CSV 相关性创造新风险类型
❌ 以 ROI/AVG/RATE 齐全度评价商业价值
❌ 把 STRUCTURAL 直接升为 DECISION
```

可续者：`L0 RAW/AUDIT` ／ `L1 DESCRIPTIVE` ／ `L2 STRUCTURAL` ／ 为阈值反解备分布。

---

## 六、口诀（照录）

> **十五类先定「是什么」；SQL 再定「怎么量」；CSV 只回答「长什么样」；分布才回答「阈值在哪里」；registry 最后回答「能不能判」。**

**方法论教训（本轮新增）**：

> **先扩观测面，再谈阈值；不得用调阈值掩盖漏维度。**

---

`canonical v11.0.3 ／ 03E774DE ／ LOCKED ／ 未触一字`
