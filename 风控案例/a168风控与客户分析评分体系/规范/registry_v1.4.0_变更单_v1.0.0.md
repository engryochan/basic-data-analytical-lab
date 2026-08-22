# registry_risk_typology v1.3.0 → v1.4.0 变更单 v1.0.0

> **文件性质：变更单／非权威文件。** 生效以升版后之 YAML＋CSV 双档为准，双档同步、六元组重立册。
> 原则：本版**不动任何 T 类实质 verdict**（唯一例外 RT-12 系事实性陈旧修正，非改判）；只修字段结构与语义隔离。

---

## 一、REDTEAM 台账续录（编号已依册正名）

| 台账号 | 发现 | 裁定 | 严重度 |
|---|---|---|---|
| RT-04（上轮） | T-10 `admit_to_profile`：CSV=TRUE、YAML 缺键 | 采：YAML 补 `admit_to_profile: true` | 🔴 双档分叉 |
| RT-05（上轮） | B-11 `affects=[T-05,T-08]` 单向挂载 | 采：两类 blockers 回挂 B-11 | 🟠 漏挂 |
| RT-06 | OBSERVED ≠ 已证风险判别力（语义滑移链） | 采，升铁律 | 🔴 |
| RT-07 | `admit_to_scoring` 承担双义 | 采，拆二字段 | 🔴 |
| RT-08 | criterion 本体混装（实测 direction 13 值域／threshold_status 36 种自由文本） | 采＋实证加重 | 🟠 |
| RT-09 | T-05 机制证据与经济后果未分层 | 采，措辞降格 | 🟠 |
| RT-10 | T-10 外部法规为声明性引用，非已验背书 | 采，拆二字段 | 🟠 |
| RT-11 | T-04/05/08 未经 L1a 判别力量测即入 scoring | 采，新字段下消解＋影子实验立项 | 🔴 |
| RT-12（本轮新立） | T-05 verdict 仍引已废 166/133 样本；与修订注②（SUPERSEDED）及 367 行样本三处失同步 | 采：verdict 改写同步 | 🔴 册内失同步 |

---

## 二、新增治理字段（七项）

### 2.1 三层证据状态（每行必填）

| 字段 | 值域 | 回答 |
|---|---|---|
| `phenomenon_status` | OBSERVED / INFERRED / UNKNOWN | 现象是否被数据直接观察 |
| `label_validation_status` | NOT_TESTED / TESTED_PASS / TESTED_FAIL / REFUTED / BLOCKED / NOT_APPLICABLE | 是否经独立风险标签（L1a）验证 |
| `causal_status` | NOT_ESTABLISHED / ESTABLISHED / REFUTED / NOT_APPLICABLE | 能否支持因果／机制解释 |

**铁律（RT-06 条文）**：`phenomenon_status=OBSERVED` 仅证现象存在，**不得**据以宣称判别力、因果或处置正当性；四层（现象→标签→因果→准入）逐层独立举证，禁止跨层滑移。

### 2.2 准入二分（每行必填）

| 字段 | 值域 | 语义 |
|---|---|---|
| `admit_to_feature_scoring` | TRUE/FALSE | 允许作为评分模型**输入变量**（实验层） |
| `admit_to_risk_decision` | TRUE/FALSE | 允许作为**处置依据**（决策层） |

**v1.4.0 全册**：`admit_to_risk_decision = FALSE ×16 行**，无例外**。解锁三锁齐落方可逐类申请：① 五门全 PASS；② 该类 `label_validation_status=TESTED_PASS`；③ MCID 处置成本锚建成（现 BLOCKED 待 Treatment Ledger）。Probe-02 OPEN 期间禁写任何"处置已验证"。

### 2.3 外部标准二分（现仅 T-10 适用）

| 字段 | 值域 |
|---|---|
| `external_standard_status` | NONE / REFERENCED / VERIFIED_SOURCE |
| `applicability_status` | NOT_APPLICABLE / UNRESOLVED / CONFIRMED |

T-10 现值：`REFERENCED`＋`UNRESOLVED`（a168 持牌辖区未定；引用≠背书，三层不得压一层）。升 VERIFIED_SOURCE 须过标准八问（谁颁布／原文何言／类别／现行否／适用范围／更严更新源／反例／引用抑或自撰）。

---

## 三、criterion 本体归一（RT-08 主修）

### 3.1 新增 `criterion_role` 枚举（每判据行必填）

| 角色 | 含义 | 现值映射（direction 列） |
|---|---|---|
| STAT_DIRECTIONAL | 统计方向判据，可反解阈值 | high(28) / low(10) / jump(3) / abnormal(1) → 38+ 行 |
| REFERENCE | 参照量／基线／分布对照 | ref(10) |
| JOIN_KEY | 关联键，无阈值语义 | join(4) |
| FILTER | 准入过滤器 | filter(1) |
| FLAG | 布尔标志 | flag(1) |
| BUCKET | 契约档位／分桶 | bucket(1) |
| IDENTITY | 恒等式（残差必零） | must_be_zero(1)＝T-10 |
| STATE | 状态量 | state(1) |
| RANK | 排序键 | rank_desc(1)＝V 轴 |
| PROFILE_ONLY | 仅画像展示（T-03 四指标） | profile_only(4) |

`direction` 字段保留但**仅 STAT_DIRECTIONAL 行可非空**（high/low/jump/abnormal），其余行置空——方向语义不再冒充角色语义。

### 3.2 `threshold_status` 归一为枚举＋备注双列

| 枚举 | 吸收现值 |
|---|---|
| PENDING_INVERSE | 「待反解」全族（24＋各带注变体） |
| NO_THRESHOLD_BY_DESIGN | 禁设阈值(4)／非阈值各条／参照／对照／布尔／档位／键类 |
| BLOCKED | ★B-03(2)／★B-06(1)／★B-07(1)／★B-08(1)／★B-09(1)＋试探待建 |
| NOT_APPLICABLE | 恒等式等 |

原 36 种自由文本**全文迁入新列 `threshold_note`，一字不删**（历史注记是血统，不是噪声）。

---

## 四、迁移默认值（16 行，机器可执行）

| 行 | phenomenon | label_validation | causal | feature_scoring | risk_decision |
|---|---|---|---|---|---|
| T-03 | OBSERVED | **REFUTED** | **REFUTED** | FALSE | FALSE |
| T-04 | OBSERVED | NOT_TESTED | NOT_ESTABLISHED | TRUE | FALSE |
| T-05 | OBSERVED | NOT_TESTED | NOT_ESTABLISHED | TRUE | FALSE |
| T-08 | OBSERVED | NOT_TESTED | NOT_ESTABLISHED | TRUE | FALSE |
| T-10 | OBSERVED | NOT_APPLICABLE | NOT_APPLICABLE | FALSE | FALSE |
| T-01 | INFERRED | NOT_TESTED | NOT_ESTABLISHED | FALSE | FALSE |
| T-09 | INFERRED | NOT_TESTED | NOT_ESTABLISHED | FALSE | FALSE |
| T-02 | UNKNOWN | **BLOCKED**(B-02) | NOT_ESTABLISHED | FALSE | FALSE |
| T-06 | UNKNOWN | BLOCKED(B-03) | NOT_ESTABLISHED | FALSE | FALSE |
| T-07 | UNKNOWN | BLOCKED(B-04) | NOT_ESTABLISHED | FALSE | FALSE |
| T-11 | UNKNOWN | BLOCKED(B-06) | NOT_ESTABLISHED | FALSE | FALSE |
| T-12 | UNKNOWN | BLOCKED(B-07) | NOT_ESTABLISHED | FALSE | FALSE |
| T-13 | UNKNOWN | BLOCKED(B-08) | NOT_ESTABLISHED | FALSE | FALSE |
| T-14 | UNKNOWN | BLOCKED(B-09) | NOT_ESTABLISHED | FALSE | FALSE |
| T-15 | UNKNOWN | BLOCKED(B-10) | NOT_ESTABLISHED | FALSE | FALSE |
| V-01 | OBSERVED | NOT_APPLICABLE | NOT_APPLICABLE | TRUE | FALSE |

（`phenomenon_status` 即由现 `evidence_tier` 平移；`evidence_tier` 保留一版作对照列，v1.5.0 议废。）

---

## 五、分层状态机（采红队四层，一处驳修）

| 层 | 成员 | 语义 |
|---|---|---|
| 🟢 A 模型实验层 | T-04／T-05／T-08（＋V 排序键） | feature_scoring=TRUE；进入影子评分实验；**进模型≠可处置** |
| 🟡 B 画像候选层 | T-01／T-06／T-07／T-09／T-12／T-13／T-15 | 阻断解除后逐类申请升 A |
| 🔴 C 禁触发层 | T-03 | FATAL 定格；profile=TRUE 为全册模板 |
| ⛔ D 阻断层 | T-02·B-02／T-06·B-03／T-07·B-04／T-09·B-05／T-11·B-06／T-12·B-07／T-13·B-08／T-14·B-09／T-15·B-10 | 硬阻断：B-02／B-06／B-09 |
| 🔵 E 内控轨（**驳修**） | T-10 | 红队原置 A 层，驳：T-10 scoring=FALSE 且 risk_axis_rule 明定评分轴仅由 scoring=true 构成；恒等式对账属内控监控，独立成轨，永不入会员风险评分 |

---

## 六、文本修正（随本版一并执行）

1. **RT-12**：T-05 verdict 改写为——「经济机制已由平台规则与标注样本直接验证（等额对押之注不计洗码，该月洗码合计为零而盈亏照记）；样本依 §Z-14 逐层反解口径（367 行正例，非全集），旧 166 会员-月样本 SUPERSEDED 仅存档；具体损益影响依 NGR／退水契约口径另算，不在本册断言。」
2. **RT-04**：YAML T-10 补 `admit_to_profile: true`。
3. **RT-05**：T-05／T-08 `blockers` 回挂 `B-11`（OPEN·随窗口复检，不改门禁）。
4. 修订注新增 v1.4.0 条目，逐字记录 RT-04～RT-12 之裁定与本变更单 MD5。

---

## 七、下一轮 REDTEAM 主任务（立项）

**「四层防串线审计」**：Evidence／Label-Validation／Causal／Admission 四层以状态机核验——每一层升级必须指向一条可执行实验或一个可关闭阻断项。首件实验已定：**影子模式量测 T-04／T-05／T-08 三特征对外部 L1a 标签之判别力**（sensitivity／specificity／precision／lift／FPR／calibration 全套，AUC 命名循例「Outcome Association AUC」），实验注册先行、量测后录，TESTED_PASS 方可谈 B→A 之外的任何升级。
