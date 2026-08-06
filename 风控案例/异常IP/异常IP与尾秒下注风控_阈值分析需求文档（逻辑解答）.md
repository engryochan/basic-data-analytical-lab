# 异常 IP 与尾秒下注风控 · 阈值分析需求文档

**Anomalous-IP & Tail-Second Betting Risk Control — Threshold Analysis Requirements Specification**

| 项 | 值 |
|---|---|
| 文档编号 | `REQ-A168-RISK-IPTS-001` |
| 版本 | `v1.0` |
| 状态 | 草案 · 待评审 |
| 目标平台 | a168 真人荷官平台 |
| 数据层 | StarRocks ODS `ods_mariadb_2b` |
| 模型版本号（拟） | `A168_IP_TAILBET_V1` |
| 金额语义合同（拟） | `BET17_POCKET_NET_V1` |
| 校准基线合同（拟） | `A168_IPTS_V1_NONOVERLAP_90D_PURGED` |
| 作者 | ®γσ ξηg（Ryo Eng）· 世博量化® Scibrokes Trading® |

---

## 0. 文档控制

### 0.1 与既有系统的关系

平台内已存在同事开发的 `wm_live_risk` 反套利系统（`BACCARAT_ANTI_ARBITRAGE_V1`）。
本项目**不读取、不依赖该系统的任何表**，全部指标自 `ods_a168_*` 独立计算。

`wm_live_risk` 在本文档中的定位是**工程基准（engineering benchmark）**：
其若干设计模式经评估为业界良好实践，本文档予以采纳并标注；
另有四个方向本文档主动加码，见 §0.2。

| 采纳自基准的设计 | 本文档对应章节 |
|---|---|
| 不可变阈值快照 + SHA-256 可重放标识 | §4.5 |
| Cohort 多级回退（细分群组 → 全局） | §4.4 |
| 百分位值与绝对门槛双轨，按方向取极值 | §4.3 |
| 半开窗口 `[start, end)` + `as_of_time` 右边界 | §5.1 |
| 影子模式（shadow-only）先行 | §7.2 |
| 人工复核队列与四分类标签 | §7.3 |
| 健康指标与风险分严格隔离 | §7.5 |
| `reason_code` 显式说明不可用原因 | §7.6 |
| 样本安全性检查（sample_safe） | §4.6 |

### 0.2 本文档相对基准的四项加码

1. **净化时序验证**（§5）——基准的 `as_of_time` 右边界已实现单向性，
   但未见对**标签实现滞后**的净化与禁运处理。本文档要求 purged walk-forward
   与 CPCV，并强制披露净化前后指标差值。
2. **有限样本覆盖保证**（§5.6）——引入共形预测，使每一条高风险判定
   附带可陈述的覆盖率保证，而非仅有点估计。
3. **尾秒的相对位置口径**（§3.1.3）——下注窗口长度非恒定，绝对秒数在不同桌台
   含义不同。本文档要求同时计算绝对与相对两套口径并比较判别力。
4. **代理链组织维度**（§3.3.2）——`bet18`–`bet22`（LV1–LV5）提供了比 IP 更难
   伪造的组织关系，基准未使用，本文档纳入为一等公民维度。

### 0.3 对既有交接单的勘误

以下三条经实测数据证伪，本文档以实测为准：

| 交接单原文 | 实测结论 |
|---|---|
| ④「排除 `age022=1` 测试线」 | ⛔ `bet02` **无 `age022` 列**。测试线过滤改用 `ods_a168_member.mem019 (is_test = 'Y')` |
| ③「`bet01.bet14`=退水%，需 join `bet01`」 | ⚠️ `bet02` 自带 `bet15`（退水%）与 `bet16`（退水金额）。**本项目不需要 `bet01`** |
| 「净盈亏 = `bet17/bet11`」（未说明是否含返水） | ✅ 补全：`bet17 = (bet14 − bet13) + bet16`，会员视角、**已含返水**。样本验证：`780−400+3.2 = 383.2` ✓ |

另补两条实测新增：

- **局唯一键 = `(bet03, bet04)`**。`bet03` 为靴/場次編號（每桌递增），`bet04` 为靴内局号。
- **`bet06` = 開局時間**，是尾秒计算的权威原点；同一局所有会员的 `bet06` 完全一致。

---

## 1. 目标与范围

### 1.1 业务目标

建立一套**可辩护、可重放、可审计**的阈值体系，用于识别两类风险行为：

- **尾秒下注（Tail-Second Betting）**：在下注窗口末端下注，可能利用延迟、
  外部信息或对局面的抢先观察获取不当优势。
- **异常 IP（Anomalous IP）**：通过共享 IP、稀有网段聚集、异常切换、
  登录与下注 IP 不一致等模式，识别多开、代打、团伙协同。

### 1.2 交付目标

1. 一份**阈值规格**：每个指标的定义、口径、切点、cohort 分层、生效期。
2. 一套**不可变阈值快照机制**：任一历史判定可精确重放。
3. 一份**验证报告**：净化时序验证下的判别力、校准度、覆盖率与成本权衡。
4. 一份**局限声明**：明确本体系不能做什么。

### 1.3 明确的非目标（Out of Scope）

- ❌ 不做自动封禁。本体系输出**建议动作**，执行权限不在系统。
- ❌ 不宣称识别"作弊"。识别的是**统计异常模式**，异常 ≠ 违规。
- ❌ 不覆盖非真人桌局（`bet03 = '0'`，第三方/电投，无 IP、无荷官）。
- ❌ 不做实时拦截。本期为离线批处理，最小粒度为小时。
- ❌ 不使用 `wm_live_risk` / `wm_risk` 的任何数据。

---

## 2. 数据契约

### 2.1 唯一数据源

```
ods_mariadb_2b.ods_a168_bet02          注单主表（190,212,574 行）
ods_mariadb_2b.ods_a168_member         会员维表（日快照）
ods_mariadb_2b.ods_a168_mem_login      登录日志
ods_mariadb_2b.ods_a168_dailyreport_member   弱监督锚点
ods_mariadb_2b.ods_a168_risklist       平台已标注名单（9,958 行）
ods_mariadb_2b.ods_a168_white_list     白名单（6,798 行）
```

### 2.2 字段契约（实测定案）

| 语义 | 列 | 约束 |
|---|---|---|
| 日分区 | `dt` | **每条查询必须裁剪** |
| 靴/場次編號 | `bet03` | `'0'` = 非真人局，剔除 |
| 靴内局号 | `bet04` | 与 `bet03` 组成局唯一键 |
| 會員編號 | `bet05` | |
| 開局時間 | `bet06` | 尾秒原点 |
| 下注時間 | `bet08` | |
| 下注內容 | `bet09` | 投注选项 |
| 幣別 / 匯率 | `bet10` / `bet11` | 归一分母，须 `> 0` |
| 下注金額 | `bet13` | 流水 |
| 派彩 | `bet14` | |
| 退水% / 退水金額 | `bet15` / `bet16` | |
| 結果 | `bet17` | `= (bet14−bet13) + bet16` |
| LV1–LV5 代理 | `bet18`–`bet22` | 组织维度 |
| 桌子 / 房間 | `bet39` / `bet40` | |
| 有效投注 | `validbet` | ⚠️ 见 §2.4 陷阱 2 |
| 投注模式 | `gametype` | 1网投 2电投 3/4混合 |
| 佣金模式 | `commission` | 0一般 1免佣 |
| 荷官 | `eid` | 非真人局为 `0` |
| 下注IP | `ip` | 非真人局为空 |

### 2.3 金额语义合同 `BET17_POCKET_NET_V1`

所有金额一律除以正数 `bet11` 归一。五个口径**严格分列，禁止混用**：

| 口径 | 公式 | 用途 |
|---|---|---|
| 流水 turnover | `SUM(bet13 / bet11)` | 规模 |
| 有效投注 valid_bet | `SUM(validbet / bet11)` | ROI 分母（须分品类） |
| 纯盈亏 game_pnl | `SUM((bet14 − bet13) / bet11)` | 不含返水 |
| 返水 rebate | `SUM(bet16 / bet11)` | 成本 |
| 口袋净变动 pocket_net | `SUM(bet17 / bet11)` | 含返水，会员视角 |

**对账恒等式**：`pocket_net − game_pnl − rebate ≡ 0`（容差 `1e-6`）。
任一 cohort 违反此式，该 cohort 的所有指标标记 `reason_code = RECON_FAILED` 并停用。

**平台净贡献** `= −pocket_net`。**严禁**再从中扣减返水（会双重扣减）。

### 2.4 已知数据陷阱（必须写入报告局限章节）

1. **测试线过滤器不在注单表**：`bet02` 无 `age022`。必须 join `member.mem019`
   的最新 `dt` 切片。`member` 为日快照，直接 `COUNT(DISTINCT)` 会重复计数。
2. **`validbet` 口径跨品类不一致**：百家乐和局/退还 `validbet = 0`；
   番摊类（`bet02 = 107`）观察到 `validbet = 净额`（`bet13=40, bet14=59, validbet=19`）。
   **跨品类汇总 `validbet` 前必须按 `bet02` 分组核验比值分布**（验收项 A4）。
3. **ODS 同步滞后约两个月**（`dt = 2026-03-22` vs `sync_time = 2026-05-21`）。
   时序切分的标签实现时刻 `t1` **必须用业务时间，禁用 `sync_time`**。
4. **非真人局无 IP 与荷官**。IP 分析的分母天然只覆盖真人桌局，
   报告中所有 IP 相关渗透率必须声明此分母口径。
5. **分页去重**：StarRocks 分页若不带 `ORDER BY` 会静默产生重复行
   （历史曾出现 36.49% 重复）。所有导出强制 `ORDER BY` 主键。

### 2.5 统一过滤条件（所有指标共用）

```sql
b.dt >= :dt_from AND b.dt < :dt_to           -- 分区裁剪，半开区间
AND b.bet03 <> '0'                            -- 剔非真人局
AND NULLIF(TRIM(b.bet11),'') IS NOT NULL
AND CAST(b.bet11 AS DECIMAL(20,8)) > 0        -- 汇率有效
AND COALESCE(ml.is_test, 'N') <> 'Y'          -- 剔测试户（join member 最新快照）
AND b.bet05 NOT IN (SELECT member_id FROM white_list)   -- 剔白名单
```

**分母定义（不可变更）**：满足上述条件的 `COUNT(DISTINCT bet05)`。
预期量级约 132.9 万。**严禁使用 5,850 万账户总数作分母。**

---

## 3. 指标定义

### 3.1 尾秒下注指标族（TS-*）

#### 3.1.1 基础量

```
sec_from_open  = TIMESTAMPDIFF(SECOND, bet06, bet08)      -- 距开局秒数
round_window   = MAX(sec_from_open) OVER (PARTITION BY bet03, bet04)
sec_to_close   = round_window − sec_from_open             -- 距窗口末端秒数
rel_position   = sec_from_open / NULLIF(round_window, 0)  -- 相对位置 ∈ [0,1]
```

> **要求**：`round_window` 必须按 `(bet03, bet04)` 计算，且需先验证
> 该值在同一 `(桌台, 游戏类别)` 内是否稳定（验收项 A8）。

#### 3.1.2 绝对秒口径

| 指标 | 定义 |
|---|---|
| `TS-A1` 尾 N 秒注单占比 | `COUNT(sec_to_close ≤ N) / COUNT(*)` |
| `TS-A2` 尾 N 秒注额占比 | `SUM(turnover WHERE sec_to_close ≤ N) / SUM(turnover)` |
| `TS-A3` 尾 N 秒 ROI | `game_pnl(尾N秒) / valid_bet(尾N秒)` |
| `TS-A4` ROI 差 | `TS-A3 − 非尾秒 ROI` ★ 核心判别量 |

**N 的取值不得预设**，由 §4.2 的数据驱动流程确定，且允许分 cohort 不同。

#### 3.1.3 相对位置口径 ★ 相对基准的加码

| 指标 | 定义 |
|---|---|
| `TS-R1` 末段注单占比 | `COUNT(rel_position ≥ q) / COUNT(*)`，`q` 由分位数定 |
| `TS-R2` 末段注额占比 | 同上，加权 turnover |
| `TS-R3` 末段 ROI 差 | 同 `TS-A4`，改用相对位置切分 |
| `TS-R4` 相对位置分布偏度 | 会员 `rel_position` 分布的三阶矩 |

**强制要求**：报告必须**并列呈现绝对与相对两套口径的判别力**（AUC / PR-AUC / Lift），
并明确说明最终采用哪一套及理由。若窗口长度方差小（A8 验证），
可保留绝对口径以利业务沟通；若方差大，必须采用相对口径。

#### 3.1.4 节律型指标

| 指标 | 定义 | 风险含义 |
|---|---|---|
| `TS-B1` 下注延迟标准差 | `SD(sec_from_open)` | 极低 → 脚本 |
| `TS-B2` 下注延迟众数集中度 | 最高频秒段占比 | 极高 → 脚本 |
| `TS-B3` 亚秒级对齐率 | `bet08` 毫秒位分布的均匀性检验 p 值 | 若有毫秒精度 |
| `TS-B4` 局内首注排序位次均值 | 会员在局内下注顺序的平均排名 | 恒定靠后 → 观望 |

### 3.2 异常 IP 指标族（IP-*）

#### 3.2.1 共享与集中

| 指标 | 定义 |
|---|---|
| `IP-S1` 会员 IP 数 | `COUNT(DISTINCT ip)` |
| `IP-S2` IP 集中度 HHI | `SUM(share_i²)`，`share_i` 为各 IP 注单占比 |
| `IP-S3` 主 IP 共享会员数 | 该会员主 IP 下的去重会员数 |
| `IP-S4` 加权共享度 | `SUM(share_i × n_members(ip_i))` |
| `IP-S5` 同局共 IP 对数 | 同一 `(bet03, bet04)` 内共享 IP 的会员对计数 ★ 强证据 |

#### 3.2.2 网段稀有度

| 指标 | 定义 |
|---|---|
| `IP-N1` /24 网段会员数 | 该会员所属 /24 段的去重会员数 |
| `IP-N2` /24 段稀有度 | `−log(该段会员数 / 全平台会员数)` |
| `IP-N3` /16 段集中指数 | 同上，粗粒度 |
| `IP-N4` 段内净盈亏偏离 | 该 /24 段整体 ROI 相对全局的 z 分数 |

> **要求**：稀有度必须是**连续量**而非布尔判定，阈值化留给 §4。
> 且须区分「稀有」与「小样本」——段内会员数 < 样本安全下限时标记
> `reason_code = SAMPLE_UNSAFE`，不参与评分。

#### 3.2.3 切换与一致性

| 指标 | 定义 |
|---|---|
| `IP-C1` 日均 IP 切换次数 | 相邻注单 IP 变更次数 / 活跃天数 |
| `IP-C2` 局内 IP 切换 | 同一局内 IP 发生变更的次数（异常强信号） |
| `IP-C3` 登录-下注 IP 一致率 | join `mem_login`，时间就近匹配 |
| `IP-C4` 跨地理跳变率 | 若 IP 归属地可得，单位时间内不可能的位移 |

> `IP-C4` 依赖 IP 归属库。**若不可得，本指标标记为「未实现及原因」，
> 不得用其它指标近似替代后声称已实现。**

#### 3.2.4 IP 网络结构 ★ 加码

将「会员 — 共享 IP — 会员」构造为加权无向图：

| 指标 | 定义 |
|---|---|
| `IP-G1` 度 | 共享 IP 的邻接会员数 |
| `IP-G2` 加权度 | 按共享注单数加权 |
| `IP-G3` k-core 层数 | 所处最大 k-core |
| `IP-G4` 社区规模 | Louvain / Leiden 社区大小 |
| `IP-G5` 社区内 ROI | 所属社区整体 ROI 偏离 |
| `IP-G6` 介数中心性 | 桥接多个社区者（抽样近似） |

> **命名空间纪律**：R 端 `igraph` 函数一律显式限定（`igraph::`），防 masking。

### 3.3 辅助维度

#### 3.3.1 荷官与桌台

| 指标 | 定义 |
|---|---|
| `AX-D1` 荷官集中度 HHI | 会员在各荷官的注单份额平方和 |
| `AX-D2` 会员×荷官 ROI 偏离 | 相对该会员全局 ROI 的差 |
| `AX-D3` 桌台集中度 HHI | 同上，按 `bet39` |

#### 3.3.2 代理链组织维度 ★ 加码

`bet18`–`bet22` 为 LV1–LV5 代理层级 ID。样本显示大量会员共享完整代理链。

| 指标 | 定义 |
|---|---|
| `AX-A1` 代理链完全一致的同局对数 | 强组织关联 |
| `AX-A2` LV3 组内会员数 | 组织规模 |
| `AX-A3` LV3 组内 ROI 偏离 | 组织层面的异常 |
| `AX-A4` 代理链 × IP 交叉一致率 | 同链且同 IP → 最高置信 |

**设计理由**：IP 可通过代理/VPN 伪造，代理链是平台内部账务结构，
伪造成本高得多。二者交叉命中的组合在证据强度上显著优于单一 IP 信号。

---

## 4. 阈值架构

### 4.1 三层结构（全部必须同时报告）

| 层 | 来源 | 作用 |
|---|---|---|
| **L1 外部锚** | 监管实践与公共卫生文献的覆盖率靶心 | 对外可辩护性 |
| **L2 内生分位** | 本平台数据的经验分位数 | 运营可执行性 |
| **L3 监督校准** | 弱标签下的 Lift / PR-AUC | 精度验收 |

**硬性要求**：报告中每一个阈值必须同时给出三层信息。
三者不一致时**如实呈现分歧，不做单方面裁决**。

L1 的覆盖率靶心参考监管实践中「高消费账户顶部约 3%」的定位，
设定初始命中率目标区间 **3%–5%** 的有下注会员。此为**靶心而非硬约束**，
若 L3 显示该区间精度不可接受，须调整并说明。

### 4.2 切点生成流程（数据驱动，禁止硬编码）

```
Step 1  计算指标全量分布（分 cohort），输出 P50/P75/P90/P95/P99/P99.5/P99.9
Step 2  以弱标签计算各候选切点的 Precision / Recall / Lift / 命中率
Step 3  绘制命中率–精度权衡曲线，标出 L1 靶心区间
Step 4  在靶心区间内取 PR-AUC 最优切点为 moderate
Step 5  strong = 更严一档（如 P99.5 或 moderate 对应 Lift 翻倍处）
Step 6  与绝对门槛取极值（§4.3）
Step 7  样本安全性检查（§4.6）
Step 8  写入不可变快照（§4.5）
```

**所有分位数用 `PERCENTILE_APPROX` 在 SQL 端计算，
R 端不得对已聚合数据二次估计分位数。**

### 4.3 百分位与绝对门槛双轨

每个指标声明方向 `metric_direction ∈ {HIGH, LOW}`（HIGH = 值越大越可疑）。

```
moderate_value = HIGH ? MAX(moderate_percentile, absolute_moderate_floor)
                      : MIN(moderate_percentile, absolute_moderate_floor)
strong_value   = HIGH ? MAX(strong_percentile,   absolute_strong_floor)
                      : MIN(strong_percentile,   absolute_strong_floor)
```

**绝对门槛的作用**：防止群体整体漂移时阈值被稀释。
例如若某月大量脚本户涌入，纯分位数会自动抬高切点从而放过它们；
绝对门槛提供下限保护。

**绝对门槛的来源必须在文档中逐条注明**（业务规则 / 物理约束 / 历史稳态），
不得凭空设定。

### 4.4 Cohort 分层与回退

分层维度（由细到粗）：

```
Level 1: (game_category, commission, volume_band, activity_band)
Level 2: (game_category, commission, volume_band)
Level 3: (game_category, commission)
Level 4: (game_category)
Level 5: 全局
```

- `volume_band`：有效投注额分桶（按全局分位数切，非固定金额）
- `activity_band`：活跃度分桶（活跃天数 / 窗口天数）

**回退规则**：从 Level 1 起逐级尝试，首个通过样本安全性检查（§4.6）的层级即采用。
实际采用层级写入 `cohort_level`，**必须随判定一起持久化**，否则无法重放。

### 4.5 不可变阈值快照

每次校准发布生成一条快照：

| 字段 | 说明 |
|---|---|
| `baseline_date` | 校准发布日 |
| `threshold_snapshot_id` | 全部阈值内容的 SHA-256，不可变 |
| `model_version` | `A168_IP_TAILBET_V1` |
| `metric_contract` | `BET17_POCKET_NET_V1` |
| `baseline_contract` | `A168_IPTS_V1_NONOVERLAP_90D_PURGED` |
| `anchor_start` / `anchor_end` | 校准锚点区间 `[start, end)`，**与评估窗口不重叠** |
| `observation_count` / `distinct_player_count` | 校准样本量 |
| `confidence` | 由完整锚点数与样本安全性推出 |
| `purge_rate` / `embargo_days` | ★ 净化参数，随快照固化 |

**每一条风险判定必须携带 `threshold_snapshot_id`。**
给定该 ID 与原始注单，任何第三方应能**逐位重放**出相同判定。
这是审计与申诉（§7.4）的技术前提。

### 4.6 样本安全性检查

阈值仅在满足以下全部条件时标记 `sample_safe = TRUE`：

- cohort 内去重会员数 ≥ `MIN_MEMBERS`（建议 500，需数据验证后定）
- cohort 内注单数 ≥ `MIN_BETS`（建议 50,000）
- 用于估计该分位数的有效观测数 ≥ `MIN_OBS_FOR_QUANTILE`
  （建议 `10 / (1 − q)`，即 P99 需 ≥ 1,000）
- 分位数的 bootstrap 95% CI 宽度 / 点估计 ≤ `MAX_CI_RATIO`（建议 0.2）

不满足 → 回退至更粗 cohort（§4.4）；至 Level 5 仍不满足 →
`reason_code = SAMPLE_UNSAFE`，该指标**不参与评分**（而非按 0 计入）。

---

## 5. 验证协议 ★ 本文档的核心加码

### 5.1 时间边界纪律

- 一切窗口为**半开区间** `[start, end)`。
- 每次评估声明 `as_of_time`，证据**严格仅覆盖时间 < as_of_time**。
- 标签实现时刻 `t1` 用**业务时间**（`bet08` / 结算时间），**禁用 `sync_time`**
  （ODS 同步滞后约两个月，用它会制造巨大的伪未来信息）。

### 5.2 为什么普通 k-fold 在此必然泄漏

会员的风险标签跨期实现，且同一会员相邻期高度自相关。标准 k-fold 假设行独立，
洗牌切分会把未来答案泄回训练集；测试窗口紧后的行同样因序列相关而泄漏。
两种效应都会系统性抬高判别指标。

### 5.3 Purged Walk-Forward

```
对每一折 k:
  train = 时间序上位于 test 之前的全部样本
  test  = 第 k 个时间块
  Purging: 剔除 train 中 t1 ≥ min(t0[test]) 的样本
  Embargo: 再剔除 t0 落在 (max(t1[test]), max(t1[test]) + E] 的样本
```

**`E`（embargo 天数）不得照抄文献值，必须由 `t1 − t0` 滞后经验分布的 P95 决定。**
文献常见的 21 天是别人数据的值，不是本平台的值。

### 5.4 CPCV（组合式净化交叉验证）

将时间序不打乱地分为 `N` 组，测试集取 `k` 组，穷举 `C(N, k)` 种划分，
每种划分独立净化与禁运。产出多条回测路径而非单条，
用于压低多次试验下的假发现率。

建议初始参数 `N = 8, k = 2`（28 种划分），实际以样本量决定。

### 5.5 强制披露项

报告必须包含以下表格，**缺一不可**：

| 协议 | AUC | PR-AUC | 95% CI | 说明 |
|---|---|---|---|---|
| 朴素 5-fold（有泄漏） | | | | 仅作对照，**不得用于结论** |
| Purged Walk-Forward | | | | **主口径** |
| CPCV（多路径均值 ± 标准差） | | | | 稳健性 |

**并明确报告净化前后的差值。差值本身是结论的一部分。**
差值大说明泄漏严重，说明净化协议是必要的而非形式的。

同时披露：
- 各折**净化率**（被剔除训练样本占比）
- **有效折数**（净化后训练样本量不足的折须剔除并说明）
- **泄漏断言结果**：任一折若 `max(t1[train]) ≥ min(t0[test])` 则显式报错，
  不得静默放行

### 5.6 共形预测覆盖保证 ★ 加码

对每一条高风险判定，输出一个**共形预测集**，附带有限样本覆盖保证
（在可交换性假设下，覆盖率 ≥ 1 − α，不依赖模型正确性）。

**业务含义**：可以对复核人员陈述「此判定的置信集在 90% 的名义覆盖率下不含
『正常行为』」，而不只是给一个无保证的分数。这对申诉流程（§7.4）至关重要。

**可交换性假设在时序数据下并不严格成立**，须使用适配时序的变体
（如按时间块做校准），并在局限章节声明此假设。

### 5.7 反事实与因果框架

尾秒下注是否**真的**带来优势，需要区分相关与因果：

- **朴素比较**：尾秒注单 ROI vs 非尾秒注单 ROI（有混淆：下注选项、金额、桌台不同）
- **匹配比较**：在同一 `(bet03, bet04, bet09)` 内，比较尾秒与非尾秒下注者的结果
  ——同局同选项，赔付规则相同，混淆大幅降低
- **安慰剂检验**：对无信息价值的时点做同样切分，ROI 差应不显著

**若匹配比较下 ROI 差不显著，必须在报告中明确指出「尾秒下注在本数据下
未观察到统计显著的优势」，即使这削弱了项目的叙事。**

### 5.8 校准与判别

| 指标 | 要求 |
|---|---|
| PR-AUC | **主口径**（类别极不平衡下 ROC-AUC 无信息量） |
| ROC-AUC | 仅作横向对照 |
| Brier Score | 越低越好 |
| ECE（期望校准误差） | 分箱数须声明 |
| 校准曲线 | 必须出图 |
| DeLong 检验 | 模型间 AUC 差异的显著性 |
| Bootstrap CI | 所有点估计须附 CI |

### 5.9 标签质量声明

`dailyreport_member.risk` 与 `member.mem024` 均为**平台自评标签**，
属 noisy、positive-only。因此：

- 结论一律以 **Lift 与 PR-AUC** 表述
- **禁用 Accuracy**
- **不得宣称达到"真实风险"的召回率**
- 若两个弱标签不一致，须报告一致性（Cohen's κ）并说明处理方式

### 5.10 漂移监控

| 指标 | 频率 |
|---|---|
| 各特征 PSI（群体稳定性指数） | 每周 |
| 命中率时间序列 | 每日 |
| cohort 分布漂移 | 每周 |
| 阈值快照间的切点变动幅度 | 每次校准 |

PSI > 0.25 触发重校准评审。

---

## 6. 评分与分级

### 6.1 四维度评分

沿用「行为 / 关系 / 经济 / 持续性」四维分解（此结构清晰，予以采纳）：

| 维度 | 本项目对应指标 |
|---|---|
| 行为 Behavior | `TS-*` 全族 |
| 关系 Relationship | `IP-S*`、`IP-G*`、`AX-A*` |
| 经济 Economic | ROI 偏离、净盈亏、有效投注 |
| 持续性 Persistence | 跨期重复命中、命中周数占比 |

每维度 0–25 分，合计 `risk_score ∈ [0, 100]`。

**加权方式必须由数据决定**（以 PR-AUC 最优化），不得凭直觉分配，
且权重随快照固化。

### 6.2 分级

| 等级 | 条件（示例，实际由 §4.2 流程定） |
|---|---|
| `CRITICAL` | 多维度 strong 命中 + 经济维度显著 |
| `HIGH` | 单维度 strong 或多维度 moderate |
| `MEDIUM` | 单维度 moderate |
| `LOW` | 无命中 |
| `UNKNOWN` | 数据不足（`reason_code` 非 `READY`） |

⚠️ **`UNKNOWN` 必须与 `LOW` 严格区分。**
「没查出问题」与「查不了」是完全不同的两件事，混同二者是审计上的重大缺陷。

### 6.3 建议动作

`ALLOW` / `MONITOR` / `REVIEW` / `BLOCK_RECOMMENDED`

**全部为建议，不含执行语义。** 系统不具备封禁权限。

### 6.4 成本敏感阈值

最终切点须经成本权衡：

```
误杀成本 c_FP = 被误判会员的期望净贡献（流失损失）
漏放成本 c_FN = 未识别异常会员的期望敞口
最优阈值 = argmin( c_FP × FP(t) + c_FN × FN(t) )
```

**`c_FP` 与 `c_FN` 必须由数据推得**（如中位净贡献、P95 会员赢额），
不得设为业务方拍脑袋的数字。若业务方坚持指定，须在报告中标注为
「业务给定参数」并做敏感性分析。

---

## 7. 治理与合规

### 7.1 误报预算

发布前须明确声明**可接受的误报率上限**，并在监控中持续跟踪。
超出预算触发阈值回滚至上一快照。

### 7.2 影子模式先行

新模型版本首先以 `shadow_only = TRUE` 运行**至少 30 天**，
仅记录不产生动作。影子期结束后比较：

- 影子判定与既有流程判定的重合度
- 影子期内人工复核的四分类结果分布
- 误报预算是否守住

三项通过方可退出影子模式。

### 7.3 人工复核

进入复核队列的案件由人工标注四分类：

```
CONFIRMED_ABUSE          确认异常
ENHANCED_DUE_DILIGENCE   需加强尽调
NORMAL_BEHAVIOR          正常
INSUFFICIENT_EVIDENCE    证据不足
```

⚠️ **复核标签是条件抽样，不是随机抽样。**
它只覆盖被系统抓出来送审的案件。因此：

- 可用作**验证集**（在系统召回范围内比较精度）
- **不可**直接用于估计整体召回率（会严重高估）
- 估计新发现能力须另用未被抓过的样本做独立评估

**此限制必须写入报告，且不得以任何方式绕过。**

### 7.4 申诉与可解释性

任一被判定会员有权要求解释。系统须能提供：

1. 触发的具体指标与其取值
2. 该指标的 cohort 阈值与 `cohort_level`
3. `threshold_snapshot_id`（可重放）
4. 共形预测集与其名义覆盖率
5. SHAP 归因（局部解释）

**证据必须可追溯到具体注单 ID，不得伪造或估算局号列表。**

### 7.5 健康指标隔离

数据管道健康指标（延迟、缺失率、对账差额等）**永不贡献风险分**。
它们只影响 `data_status` 与 `reason_code`。

将管道故障混入风险分是严重设计错误——会把技术问题误判为会员行为异常。

### 7.6 `reason_code` 词表

```
READY                正常
SAMPLE_UNSAFE        样本量不足
RECON_FAILED         对账恒等式不成立
MISSING_IP           IP 缺失（非真人局或采集失败）
MISSING_GEO          IP 归属库不可得
STALE_DATA           数据滞后超阈值
COHORT_FALLBACK_MAX  已回退至全局仍不安全
```

---

## 8. 交付物清单

| # | 交付物 | 格式 |
|---|---|---|
| D1 | 本需求文档 | `.md` |
| D2 | SQL 生成器（配置驱动） | `.R` |
| D3 | 取数 SQL 包（分区裁剪、逐条可执行） | `.sql` × N |
| D4 | 阈值校准脚本（含 bootstrap CI、样本安全检查） | `.R` |
| D5 | 净化验证模块（purged WF / CPCV / 泄漏断言） | `.R` |
| D6 | 阈值快照表 DDL 与生成逻辑 | `.sql` + `.R` |
| D7 | 分析报告 | `.qmd` → HTML |
| D8 | 局限与不确定性声明 | 报告章节 |
| D9 | 复现说明 | 报告附录 |

---

## 9. 验收标准

### 9.1 数据层（硬性）

| # | 标准 | 判定 |
|---|---|---|
| V1 | 分母 = 有下注会员数，与 132.9 万量级一致（误差 < 5%） | 数值核对 |
| V2 | 对账恒等式 `pocket_net − game_pnl − rebate` 容差内为零 | 数值核对 |
| V3 | 导出数据重复率 < 0.1% | 主键去重比 |
| V4 | `validbet` 跨品类比值分布已核验并记录 | 表格存在 |
| V5 | 所有查询带 `dt` 分区裁剪 | 代码审查 |

### 9.2 方法层（硬性）

| # | 标准 | 判定 |
|---|---|---|
| V6 | 泄漏断言全折通过 | 断言输出 |
| V7 | embargo 由经验分布推出，非文献照抄 | 代码 + 分布图 |
| V8 | 朴素 k-fold 与 purged WF 的 AUC 差值已披露 | 表格存在 |
| V9 | 所有阈值三层信息齐备（L1/L2/L3） | 逐指标核对 |
| V10 | 无任何硬编码阈值 | 代码审查（grep 数值常量） |
| V11 | 样本安全检查覆盖全部 cohort | 检查报告 |
| V12 | 阈值快照可重放（随机抽 10 条判定验证） | 重放测试 |

### 9.3 结论层（硬性）

| # | 标准 | 判定 |
|---|---|---|
| V13 | 主口径为 PR-AUC，未使用 Accuracy 作结论 | 文本审查 |
| V14 | 弱标签性质已声明 | 章节存在 |
| V15 | 复核标签的条件抽样限制已声明 | 章节存在 |
| V16 | 命中率落在 L1 靶心区间，或有明确偏离理由 | 数值 + 说明 |
| V17 | 尾秒优势的因果检验已做，结论如实呈现 | 章节存在 |
| V18 | `UNKNOWN` 与 `LOW` 严格区分 | 分级逻辑审查 |
| V19 | 未实现项已逐条列明及原因 | 局限章节 |

---

## 10. 已知局限（必须写入报告，不得省略）

1. **异常 ≠ 违规。** 本体系识别统计异常模式。异常可能源于合法行为
   （网吧共享 IP、家庭多账户、网络环境不稳）。所有判定须经人工复核。
2. **IP 可伪造。** VPN / 代理 / 移动网络 NAT 均会污染 IP 信号。
   这正是引入代理链维度（§3.3.2）的原因，但后者也非完美。
3. **无 IP 归属库时，跨地理跳变（`IP-C4`）不可实现。**
   不得用其它指标近似替代后声称已实现。
4. **覆盖面限于真人桌局。** 非真人局无 IP 无荷官，不在范围内。
5. **弱标签非金标准。** 结论以 Lift 表述，不等同真实风险召回。
6. **复核标签为条件抽样。** 不可用于估计整体召回率。
7. **共形预测的可交换性假设在时序下不严格成立。** 已用时序变体，
   但保证是近似的。
8. **ODS 滞后约两个月。** 本体系为离线批处理，不具备实时能力。
9. **`validbet` 跨品类口径不一致。** 已按品类分组处理，
   但若新增游戏类型，须重新核验。
10. **样本安全下限为经验值。** `MIN_MEMBERS` 等参数需随数据规模复核。

---

## 11. 里程碑与数据依赖

| 阶段 | 内容 | 依赖批次 |
|---|---|---|
| M1 | 口径校验与陷阱确认 | A1–A8 |
| M2 | 尾秒指标计算与窗口长度验证 | A8 → B1–B3 |
| M3 | IP 指标计算与图构建 | A5 → C1–C5 |
| M4 | 建模底座与滞后分布 | D1–D5 |
| M5 | 阈值校准与快照 | M2 + M3 + E1–E3 |
| M6 | 净化验证与因果检验 | D2 + D3 |
| M7 | 报告成稿 | 全部 |
| M8 | 影子模式运行 30 天 | M7 |

### 数据依赖批次（详见《a168_分批上载清单_v2.md》）

- **批次 A**（口径校验，全部小结果）——**当前唯一未完成的前置**
- 批次 B（尾秒）、C（异常IP）、D（建模底座）、E（标签与资金）可在 A 完成后并行

---

## 附录 A · 关键 SQL 骨架

```sql
-- 尾秒基础量（局唯一键 = bet03 + bet04，原点 = bet06）
WITH member_latest AS (
    SELECT mem001 AS member_id, mem019 AS is_test
    FROM (SELECT m.*, ROW_NUMBER() OVER (PARTITION BY m.mem001 ORDER BY m.dt DESC) rn
          FROM ods_mariadb_2b.ods_a168_member m WHERE m.dt < :dt_to) x
    WHERE rn = 1
),
base AS (
    SELECT b.bet05 AS member_id, b.bet03 AS shoe_id, b.bet04 AS round_no,
           b.bet39 AS table_id, b.eid AS dealer_id, b.bet02 AS game_cat,
           b.ip AS bet_ip, b.bet09 AS bet_side,
           b.bet18 AS lv1, b.bet19 AS lv2, b.bet20 AS lv3,
           CAST(b.bet06 AS DATETIME) AS open_ts,
           CAST(b.bet08 AS DATETIME) AS bet_ts,
           CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
             / CAST(b.bet11 AS DECIMAL(20,8)) AS turnover,
           CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))
             / CAST(b.bet11 AS DECIMAL(20,8)) AS valid_bet,
           (CAST(NULLIF(TRIM(b.bet14),'') AS DECIMAL(20,4))
            - CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)))
             / CAST(b.bet11 AS DECIMAL(20,8)) AS game_pnl
    FROM ods_mariadb_2b.ods_a168_bet02 b
    JOIN member_latest ml ON b.bet05 = ml.member_id
    WHERE b.dt >= :dt_from AND b.dt < :dt_to
      AND b.bet03 <> '0'
      AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
      AND COALESCE(ml.is_test,'N') <> 'Y'
),
timed AS (
    SELECT b.*,
           TIMESTAMPDIFF(SECOND, b.open_ts, b.bet_ts) AS sec_from_open,
           MAX(TIMESTAMPDIFF(SECOND, b.open_ts, b.bet_ts))
             OVER (PARTITION BY b.shoe_id, b.round_no) AS round_window
    FROM base b
)
SELECT *,
       round_window - sec_from_open AS sec_to_close,
       sec_from_open * 1.0 / NULLIF(round_window, 0) AS rel_position
FROM timed;
```

## 附录 B · 净化切分器（R，无闭源依赖）

```r
purged_wf_splits <- function(panel, t0_col = "t0", t1_col = "t1",
                             n_splits = 6L, embargo_days = NULL) {
  t0 <- as.POSIXct(panel[[t0_col]]); t1 <- as.POSIXct(panel[[t1_col]])
  stopifnot(all(t1 >= t0, na.rm = TRUE))
  if (is.null(embargo_days)) {
    lagd <- as.numeric(difftime(t1, t0, units = "days"))
    embargo_days <- ceiling(stats::quantile(lagd[is.finite(lagd)], .95, na.rm = TRUE))
    message(glue::glue("embargo 由经验分布定为 {embargo_days} 天（滞后 P95）"))
  }
  ord <- order(t0); n <- length(ord)
  bd <- floor(seq(1, n + 1, length.out = n_splits + 1L))
  lapply(seq_len(n_splits - 1L), function(k) {
    tr <- ord[seq_len(bd[k + 1L] - 1L)]
    te <- ord[bd[k + 1L]:(bd[k + 2L] - 1L)]
    te0 <- min(t0[te], na.rm = TRUE); te1 <- max(t1[te], na.rm = TRUE)
    keep <- t1[tr] < te0 &
            !(t0[tr] > te1 & t0[tr] <= te1 + as.difftime(embargo_days, units = "days"))
    list(fold = k, train = tr[keep], test = te,
         purge_rate = mean(!keep), embargo_days = embargo_days)
  })
}

assert_no_leakage <- function(splits, panel, t0_col = "t0", t1_col = "t1") {
  t0 <- as.POSIXct(panel[[t0_col]]); t1 <- as.POSIXct(panel[[t1_col]])
  ok <- vapply(splits, function(s)
    length(s$train) == 0 ||
      max(t1[s$train], na.rm = TRUE) < min(t0[s$test], na.rm = TRUE), logical(1))
  if (!all(ok)) stop("检测到泄漏，折号：", paste(which(!ok), collapse = ", "))
  invisible(TRUE)
}
```

---

## 附录 C · 术语对照

| 中文 | English |
|---|---|
| 尾秒下注 | Tail-second betting |
| 稀有网段 | Rare subnet |
| 不可变阈值快照 | Immutable threshold snapshot |
| 群组回退 | Cohort fallback |
| 净化交叉验证 | Purged cross-validation |
| 禁运期 | Embargo |
| 共形预测 | Conformal prediction |
| 影子模式 | Shadow mode |
| 误报预算 | False-positive budget |
| 金额语义合同 | Metric contract |
