# `Metric Contract` · Phase 0.5 · v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**ARTIFACT CLASS**：`A3 SPEC`　**canonical**：`false`
**承**：`Contract_Skeleton_Phase0_v1.0.0.md`（已 CLOSED）
**规格**：十二栏 × 逐指标　**五态纪律**（`NOT_IDENTIFIABLE` 本册起为正式态）

---

## 〇、五态状态机（★ 第五态由裁示新增）

| 态 | 义 | 可解否 | 解法 |
|:--|:--|:--|:--|
| `UNKNOWN` | 目前不知道 | ✅ | 查、验、开工单 |
| `NOT_AVAILABLE` | 现有数据链无此字段 | ✅ | 向数据方索取 |
| `STRUCTURALLY_FORBIDDEN` | **当前 grain 下数学上无合法定义** | ✅ | **改 grain**（非改阈值） |
| `PENDING_VALIDATION` | 定义可成立，上游未验 | ✅ | 上游确认 |
| **`NOT_IDENTIFIABLE`** | **现有观察窗、字段、时间边界不足以唯一识别目标状态** | ❌ 计算不可解 | **须增观察历史／PIT／他源证据** |

★ **第五态之独有性质**：前四态**继续算下去或可解**；`NOT_IDENTIFIABLE` **算多久都不会解**——它不是知识缺口，是**可观测性缺口**。

★ **我方自纠（本册立册之由）**：`Contract Skeleton` 中我把 `T-15` 之 `NOT_IDENTIFIABLE` 塞进 `PENDING_VALIDATION` 当注脚。
**那是以既有词汇迁就新现象**——与我此前所诫「零对零之相同不该与有值相同共用一判词」乃同一族错误。今正之。

---

## 一、`STRUCTURALLY_FORBIDDEN` 之措辞锁（承裁示①）

**禁写**：`win_rate` 永久不存在。
**须写**：

> **在当前未拆主注／边注／Tie 之 grain 下，`win_rate_all` 禁入能力型判定。**

$$\text{grain} = \text{member} \times \text{game} \times \text{bet\_type} \;\Longrightarrow\; \text{可重获合法性}$$

**锁三十五**：`STRUCTURALLY_FORBIDDEN` **绑定于「当前 grain」，非绑定于「该概念」**。
**解法是改拓扑，不是改阈值。** 凡书此态者，须同时书「若 grain 改为 X 则可解」，否则该态即成永久墓碑。

---

## 二、本册之核心 · **分母审计先于分子**

`Contract Skeleton` 实测已证：

$$\text{grain：12 已定 ／ 2 UNKNOWN ／ 1 NOT\_IDENTIFIABLE}$$
$$\text{denominator：5 已定 ／ 6 PENDING ／ 2 NOT\_AVAILABLE ／ 1 STRUCT\_FORBIDDEN}$$

> **B-3 之瓶颈已自 topology 转移至 denominator semantics。**

**故本册之次序：分母 → 分子 → 有效性 → 角色 → 准入。** 与直觉相反，**但分母错则一切比率皆错，分子错只错其一。**

**锁三十六**：**无合法分母，无 RATE；无合法经济分母，无 ROI；无合法事件分母，不得硬造 ROI。**

---

## 三、六十五判据之现况（registry v1.5.0 实测）

| 维 | 分布 |
|:--|:--|
| `criterion_role` | `STAT_DIRECTIONAL` 42 ／ `REFERENCE` 10 ／ `PROFILE_ONLY` 4 ／ `JOIN_KEY` 4 ／ 余 5 |
| `threshold_status` | **`PENDING_INVERSE` 36** ／ `NO_THRESHOLD_BY_DESIGN` 21 ／ `BLOCKED` 7 ／ `NOT_APPLICABLE` 1 |
| `evidence_tier` | **`UNKNOWN` 35** ／ `OBSERVED` 21 ／ `INFERRED` 9 |
| `direction` | `high` 28 ／ **（空）23** ／ `low` 10 ／ `jump` 3 ／ `abnormal` 1 |
| `severity` | S3 29 ／ S4 17 ／ S2 15 ／ **S1 4** |

★ **三处须记**：

1. **`evidence_tier = UNKNOWN` 者 35 条，逾半（53.8%）** —— 过半判据之证据等级本身未定
2. **`direction` 空白 23 条** —— 而 `STAT_DIRECTIONAL` 有 42 条，**意即至少若干条「方向性判据」没有方向**
3. **`PENDING_INVERSE` 36 条** —— 阈值待反解者，正是 `Phase 3` 之全部工作量

---

## 四、Metric Contract 十二栏 · 逐类分母裁定

**本节只裁分母，分子与其余栏待分母定谳后另册。**

### 已定分母（5 类）

| 类 | 分母 | 据 | 风险 |
|:--|:--|:--|:--|
| **T-01** | `exp_same` 期望共现局数 | registry `criteria` 含 `exp_same` | ★ **非「总局数」**——`lift` 之分母系期望值，误用即失去富集之义 |
| **T-04** | 该对共同在场局数 | `hedge_coverage` 之分母 | 须**逐局**判在场，非按日 |
| **T-06** | `n_member_raw` | 与 `n_member_eff` 并出 | ★ **二者须永久并出**（同阈值 P64 vs P98.7） |
| **T-09** | 链上会员数 | `member_per_chain` | 五级链须 `LEFT JOIN`，禁相关 `EXISTS` |
| **T-10** | **`NOT_APPLICABLE`** | 恒等式残差为绝对量 | ★ **非比率，禁加分母** |

### `PENDING_VALIDATION`（6 类）· 逐条列明待验何物

| 类 | 待验 | 解锁条件 |
|:--|:--|:--|
| **T-02** | `z_score_w` 之权重口径 | 权重定义 ＋ 荷官场次基线 |
| **T-05** | `rebate_dep` 之退水分母 | **`bet16` 语义确认**（现为「退水金额」，H16 恒等式已 100% 成立，惟业务定义未确认） |
| **T-08** | 有效投注口径 | ★ **`§VB` 已推进**：`validbet` 契约实证已备，`n_vb_null = 0`、`n_vb_zero = 9,551,241` |
| **T-12** | 桌台延迟基线 | `gi004` 可得性（现 `UNKNOWN`） |
| **T-13** | **在线暴露基准** | 须建 `expected_night_exposure` |
| **T-15** | **观测跨度**（非窗口长度） | ★ 见 `NOT_IDENTIFIABLE` 一节 |

### `NOT_AVAILABLE`（2 类）

| 类 | 分母 | 何以不可得 |
|:--|:--|:--|
| **T-11** | 设备维度 | **ODS 无设备指纹字段** —— 非 SQL 可解 |
| **T-14** | `effective_limit` | **现档为快照，须 PIT 重建** —— 快照冒充历史即 `Treatment → Feature` 反因果 |

### `STRUCTURALLY_FORBIDDEN`（1 类 ＋ 1 指标）

| 对象 | 当前 grain | 何以禁 | **解法（须同书）** |
|:--|:--|:--|:--|
| **T-14 之 `ROI`** | 处置事件 | 事件无投注收益分母 | **改 grain 为「会员 × 处置前后窗」**，则 ROI 可成立 |
| **T-07 之 `win_rate_all`** | 全部注单混合 | **mixture confounding**：Tie 命中 9.47%、Banker 55.35%，胜率随玩法配比而变 | **改 grain 为 `member × game × bet_type`**，并重定命中分母 |

---

## 五、`T-15` · `NOT_IDENTIFIABLE` 之完整论证

**实测**：112,798 人（67.1%）仅现一个月；六月全勤 2.01%。

**不可推之式**：

$$\text{silent\_days} \;\ne\; \text{inactive\_days}$$

**因**：

$$\text{观察不到} \;\ne\; \text{没有发生}$$

**左截断之机制**：会员或于 2026-03-21 前已活跃，惟数据窗自该日始。则

$$\text{silent\_days} \uparrow \;\Longleftarrow\; \text{left truncation} \uparrow \quad(\text{非真实沉睡} \uparrow)$$

**何以不可算解**：纵将窗口内每一笔皆算尽，**窗外之历史仍不在数据中**。
增加计算量、改进算法、换分母，**皆不能产生窗外的观测**。

$$\boxed{\text{此系可观测性缺口，非知识缺口}}$$

**解法**（唯三）：① 延长观察历史 ② 取注册日等 PIT 信息作左边界 ③ 引他源证据。

**★ `member` 表已证系注册日分区表**（P-H0 实测，`dt` ＝ 注册日）——**故解法②或有路**：以注册日为左边界，可区分「窗前已在」与「窗内新入」。**惟此为线索，未实测，不得先书为可解。**

---

## 六、`T-12` 之 `UNKNOWN` 何以不改 `NOT_AVAILABLE`（承裁示②）

```
formula_known = TRUE      （bet08 − gi004）
grain_known   = FALSE
```

**二者可同时成立。** 尚缺三层证据：

```
gi004 是否稳定存在  →  gi004 与 bet08 是否同一注单粒度  →  能否可靠连接 member／table／time
```

**`NOT_AVAILABLE` 者，须已证其不存在。** 现况是**尚未验**，故 `UNKNOWN` 严谨。

**锁三十七**：**知晓计算公式 ≠ 已证分析拓扑成立。**

---

## 七、`metric_role` 之实填（十五类）

| 角色 | 类 | 数 |
|:--|:--|--:|
| `PROFILE` | T-03 ／ T-07 ／ T-10 ／ T-11 ／ T-12 ／ T-13 ／ T-14 ／ T-15 | 8 |
| `STRUCTURAL` | T-01 ／ T-02 ／ T-04 ／ T-05 ／ T-06 ／ T-08 ／ T-09 | 7 |
| **`DECISION`** | **无** | **0** |

**无一类现够 `DECISION`** —— contract、validation、causal 三闸无一全过。

**T-03 之 `PROFILE` 系强制**（`gate = FATAL`，`Z2-08` 五条禁径，不可复活）。
**T-10 之 `PROFILE` 系内控轨**（`admit_to_profile = FALSE`，禁入客户画像）。

---

## 八、下一册之工作量（`Phase 1` 前置）

| 项 | 量 | 依赖 |
|:--|--:|:--|
| 分母定谳 | **10 类** | 6 待上游／2 待数据方／2 待改 grain |
| 阈值反解 | **36 条** | 须先有分布 → 须先有分母 |
| `evidence_tier` 定级 | **35 条** | 逐条追溯其证据 |
| `direction` 补全 | **23 条空白** | 须先定方向语义 |

$$\text{分母未定} \Rightarrow \text{分布无意义} \Rightarrow \text{阈值不可反解}$$

**故 36 条 `PENDING_INVERSE` 之解锁，全数卡在那 10 个分母上。**

---

## 九、口诀

> **未知不是不存在，不存在不是不可识别；分母未定不算率，拓扑未定不判义；先锁合法性，再谈指标强弱。**

**本册新增二锁**：

> **锁三十五**：`STRUCTURALLY_FORBIDDEN` 绑当前 grain，非绑概念；书此态须同书解法，否则即成永久墓碑。
> **锁三十六**：无合法分母无 RATE；无合法经济分母无 ROI；无合法事件分母不得硬造 ROI。
> **锁三十七**：知晓计算公式 ≠ 已证分析拓扑成立。

---

```
Contract Skeleton   CLOSED
Metric Contract     本册 · 分母层已出，分子层待续
v11.0.3             LOCKED ／ 03E774DE ／ 未触一字
v11.0.4             暂不施工
registry v1.5.0     不改
B-5                 不动
```
