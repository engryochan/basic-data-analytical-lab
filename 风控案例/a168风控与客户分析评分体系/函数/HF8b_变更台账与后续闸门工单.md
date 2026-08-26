# HF8b · 变更台账与后续闸门工单

**日期**：2026-08-26
**性质**：**纯结构修复（structure-only）**。零业务 predicate 变更、零阈值变更、零块注释清理、零 checksum 口径变更。
**依据**：REDTEAM 裁示「HF8b = 仅修复 #078 结构断裂 + 补末层 ORDER BY」，并守「一次一变量」。

---

## 一、五项变更（全部限于 #078 `S03_agent_score.csv`）

| # | 版别 | 变更 | 原位置 | 性质 |
|---|---|---|---|---|
| **A** | 分批作业版 | #078 ② 批次 SQL 本体自文件尾 **归位**至 #078 原位 | 原 L64828–64961 → 现 #078 段内 | 搬移，**逐字未改** |
| **B** | 分批作业版 | 删除原位**裸分号** `;` | 原 L39935 | 删除空语句 |
| **C** | 分批作业版 | 删除文件尾**未终止残留**（134 行） | 原 L64827–64963 | 删除（内容已由 A 归位） |
| **D** | 分批作业版 | 删除**重复的两份 ③ 注释**（含 AG-03 违规措辞「首行＝平台真净亏最多者」） | 原 L39910–39915、L39937–39942 | 删除，保留中立措辞版 |
| **E** | 原版审计版 | #078 末尾补 `ORDER BY audit_rn;` | 原 L19122–19133 | **唯一的一行新增代码** |

附带（house-style 归位，零语义）：
- 分批版 #078 ① 语句由 `) x` + 11 行注释 + `;` 改为 `) x;`，③ 注释前移至 SELECT 之前（HF6e 惯例）
- 原版 #078 ③ 注释由「语句体与分号之间」前移至 SELECT 之前
- 分批版 #078 ② 的逐批 WHERE 阶梯注释置于 `) z` 与 `WHERE` 之间（与 #079 等 128 件同格式）

---

## 二、结构闸验收（STRUCTURE-GATE）

| 闸项 | HF8 原版 | HF8b 原版 | HF8 分批 | HF8b 分批 | 判 |
|---|---|---|---|---|---|
| 目录编号 129/129 无缺无重 | ✔ | ✔ | ✔ | ✔ | PASS |
| 章节编号 129/129 无缺无重 | ✔ | ✔ | ✔ | ✔ | PASS |
| `AS audit_rn` 代码行 | 129 | 129 | 129 | 129 | PASS |
| 以 `ORDER BY audit_rn;` 收尾的语句 | **128** | **129** | **128** | **129** | **修复** |
| 裸分号语句 | 0 | 0 | **1** | **0** | **修复** |
| 尾部未终止残留行 | 0 | 0 | **134** | **0** | **修复** |
| 129 件 ×（T_true 1 条 + 批次 1 条）配对 | — | — | 异常 1 件 | **异常 0 件** | **修复** |
| `OFFSET` | 0 | 0 | 0 | 0 | PASS |
| 「平台真净亏最多者」出现处 | 1 | 1 | 129 | **127** | **修复**（删 #078 两处残留） |

---

## 三、语义零变更之证明

逐语句规范化（剥注释 → 折叠空白）后逐条比对：

| 版别 | 语句总数 | 逐位相同 | 不同 | 不同处说明 |
|---|---|---|---|---|
| 原版审计版 | 137 | **136** | 1 | 第 86 条（#078）尾部追加 `ORDER BY audit_rn` —— 即变更 E |
| 分批作业版 | 266 | **264** | 2 | 第 163 条（#078 ①）`) x ;` → `) x;`（仅空白）；第 164 条（#078 ②）由空语句 `;` 恢复为完整本体 |

**#078 ② 本体核验**：HF8b 中该语句去注释后 **134 行**，与 HF8 文件尾残留 **134 行逐字完全相同**，差异仅为末行追加 `;`。

---

## 四、HF8b 六元组（归档基准）

```
原版审计版  a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
            行 30,896 · 字节 2,636,260 · CRLF · UTF-8(无BOM)
            纯代码 28,846 行 · 纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
            全文MD5 672ebe5334b3992421039e91686377ea

分批作业版  a168_SQL总包_v12_0_0_HF8b_分批作业版_六层商业版.sql
            行 64,947 · 字节 5,448,145 · CRLF · UTF-8(无BOM)
            纯代码 57,942 行 · 纯代码MD5 ecc862982bf8c4b911408e6de61a78db
            全文MD5 07ab7384357c87cba8dfba53d885580f
```

**注**：纯代码 MD5 仍按现行（未剥块注释）口径计算，与 HF8 同契约，便于对照。checksum contract 的冻结与改版仍属 HF9。

**归档纪律**：HF6e / HF7 / HF8 三代**一律保留**，不得清理，直至 HF8b × #075 S01 × HF6e × HF7 四方对账完成。

---

## 五、HF8c 工单 · 代理链五级化（**未施工，待批**）

### 5.1 范围：13 件

| 类别 | 件 | 现况 |
|---|---|---|
| **出列 6 件** | #007 C01_ip_chain · #010 C08_subnet_all · #011 C08_subnet_sparse · #023 I_ip_player · #075 S01_player_score · #080 S05_member_month_panel | `n_lv3_chain` / `n_chain` / `lv3` 进 CSV |
| **内部 7 件** | #006 · #008 · #012 · #022 · #057 · #082 · #110 | `v.bet20 AS lv3` 仅存于 CTE |

### 5.2 锚点（两版格式完全一致，逐处须抽样核对）

```sql
v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
```

改为：

```sql
v.bet18 AS lv1, v.bet19 AS lv2, v.bet20 AS lv3, v.bet21 AS lv4, v.bet22 AS lv5,
CONCAT_WS('|', COALESCE(CAST(NULLIF(TRIM(v.bet18),'') AS STRING),'-'),
               COALESCE(CAST(NULLIF(TRIM(v.bet19),'') AS STRING),'-'),
               COALESCE(CAST(NULLIF(TRIM(v.bet20),'') AS STRING),'-'),
               COALESCE(CAST(NULLIF(TRIM(v.bet21),'') AS STRING),'-'),
               COALESCE(CAST(NULLIF(TRIM(v.bet22),'') AS STRING),'-')) AS chain_key,
v.bet09 AS bet_side, v.dt AS bet_date,
```

### 5.3 出列改动 —— **纯增列，旧列一律保留作对账锚**

**A · IP／网段粒度（#007 / #010 / #011 / #023）**

```sql
COUNT(DISTINCT b.lv3)       AS n_lv3_chain,   -- LEGACY · 保留 · 逐行须与旧 CSV 相同
COUNT(DISTINCT b.lv1)       AS n_lv1_chain,   -- 新增
COUNT(DISTINCT b.lv2)       AS n_lv2_chain,   -- 新增
COUNT(DISTINCT b.lv4)       AS n_lv4_chain,   -- 新增
COUNT(DISTINCT b.lv5)       AS n_lv5_chain,   -- 新增
COUNT(DISTINCT b.chain_key) AS n_chain_key,   -- 新增
ROUND(COUNT(DISTINCT b.lv5)*1.0/NULLIF(COUNT(DISTINCT b.lv1),0),6) AS chain_spread,
ROUND(1.0/NULLIF(COUNT(DISTINCT b.lv1),0),6)                       AS top_concentration,
```

**B · 会员粒度（#075 / #080）—— `n_chain` KILL**

```sql
-- KILL: COUNT(DISTINCT b.lv3) AS n_chain      ← 实测 161,156/161,156 与 278,729/278,729 恒为 1
MAX(b.lv1) AS lv1_id, MAX(b.lv2) AS lv2_id, MAX(b.lv3) AS lv3_id,
MAX(b.lv4) AS lv4_id, MAX(b.lv5) AS lv5_id,
MAX(b.chain_key)            AS chain_key,
COUNT(DISTINCT b.chain_key) AS n_chain_key,
CASE WHEN COUNT(DISTINCT b.chain_key) > 1 THEN 1 ELSE 0 END AS f_upline_changed,
(CASE WHEN MAX(b.lv1) IS NOT NULL THEN 1 ELSE 0 END)
+ (CASE WHEN MAX(b.lv2) IS NOT NULL THEN 1 ELSE 0 END)
+ (CASE WHEN MAX(b.lv3) IS NOT NULL THEN 1 ELSE 0 END)
+ (CASE WHEN MAX(b.lv4) IS NOT NULL THEN 1 ELSE 0 END)
+ (CASE WHEN MAX(b.lv5) IS NOT NULL THEN 1 ELSE 0 END) AS chain_depth,
```

> `MAX(lv*)` 对窗内换线会员取值不确定；`n_chain_key` 与 `f_upline_changed` 的职责就是把这份不确定性**显式出列**，而非藏在 `MAX()` 内。

### 5.4 HF8c 回归闸（用现有六件 CSV 作锚，零额外成本）

| 件 | 旧 CSV MD5 | 回归判据 |
|---|---|---|
| C01_ip_chain | `40af3ccd25666e0564f26827f31f390f` | 新 `n_lv3_chain` 与旧逐行相同 |
| C08_subnet_all | `12d65bf711ee5b7fb1b41b7b9ce3bf7d` | 同上 |
| C08_subnet_sparse | `7d28c07eea43e8d1ab95852bb48a2e1c` | 同上 |
| I_ip_player | `9496bfbe9f4c4346ff478eda6bc8854e` | 新 `lv3` 与旧逐行相同 |
| S01_player_score | `fa0ac8affc40a9261d5a7c87dd709345` | 除删除的 `n_chain` 外，其余 84 列逐行相同；八项合计不变 |
| S05_member_month_panel | `a5503c620b0f500bd0c7cc942b3b5437` | 同上 |

**新增列必须满足** `n_lv1_chain ≤ n_lv2_chain ≤ n_lv3_chain ≤ n_lv4_chain ≤ n_lv5_chain`（五级嵌套下行链之必然），任一行违反即判 JOIN 或 CTE 错。

### 5.5 滚动纪律

`H-UPLINE-01` 已证代理上级会变，`chain_key` 窗内非恒定。故 `chain_*` 系列**与 `testline` 系列同等对待，写入 `ROLLING_SNAPSHOT` 禁用清单**，除非能重建 t 时刻链快照。

---

## 六、UNIVERSE-GATE 工单（**未施工，待批**）—— 范围远大于 #075

全包 **HAVING 子句共 28 处 / 25 件**（明细见 `UNIVERSE_GATE_宇宙门全扫描_28处25件.csv`）。须先三分类，不可一刀切：

| 闸类 | 处数 | 处置 |
|---|---|---|
| **G-UNIVERSE**（按活跃度删主体，幸存者筛选） | **14 件** | ★ 宇宙门 → 改证据标签 |
| **G-PAIR**（配对样本量门） | 4 处 | 阈值须数据推导，删除对象是「配对」非「会员」，风险较低 |
| **G-DEF**（对象定义门） | 9 处 | 保留，但内嵌常数须数据推导 |
| **G-CLEAN**（非限制性） | 1 处 | 无须动 |

### 6.1 `参考.txt` 架构须补一处 —— 移除 HAVING **不等于**回到全窗宇宙

`#075` q 侧在 `HAVING` **之上**另有四道 predicate：

```sql
r.rn = 1                                             -- 去重（清洗，保留）
r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'      -- 哨兵（清洗，保留）
CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0         -- 哨兵（清洗，保留）
CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0  -- 哨兵（清洗，保留）
NULLIF(TRIM(r.bet08),'') IS NOT NULL                 -- ← 性质待判：清洗？还是宇宙门？
COALESCE(t1.aid,…,t5.aid) IS NULL                    -- 测试线剔除（清洗，保留）
```

**故仅删 `HAVING >= 30` 得到的不是 723,557，而是第三个尚未测量的数。**
必须先跑 **UNIVERSE-PROBE**（只读、单件、轻量）测出四个数，再定宇宙：

```
U0 = 窗内 bet02='101' 去重后会员数                     （已知 723,557）
U1 = U0 经四道哨兵清洗后                                 待测
U2 = U1 再经 bet08 非空                                  待测
U3 = U2 再经测试线剔除                                   待测（此即 HF8c 之后的合法宇宙）
U4 = U3 再经 HAVING round_key>=30                       已知 161,156
```

### 6.2 资源硬约束 —— `参考.txt` 未评估，而这正是事故根因

移除宇宙门后主件行数放大估算：

| 件 | 现行行数 | 移除宇宙门后（上界 = U3） | 放大 |
|---|---|---|---|
| #075 S01 | 161,156 | ≤ 723,557 | ≤ 4.5× |
| #080 S05 | 278,729 | 会员×月，上界更高 | ≥ 4× |
| #023 I_ip_player | 696,403 | IP×会员配对，上界最高 | 待测 |

`BE:10265` / `BE:10266` 因内存与 spill 事故被拉黑，运维**至今无人处理**，且账号无 `SHOW BACKENDS` 权限。
**故 UNIVERSE-GATE 的施工顺序必须是：UNIVERSE-PROBE 测数 → 容量评估 → 分批参数重定（100,000 或更小）→ 才改 SQL。**
不得先改 SQL 再撞内存 —— 那将重演 **W-30 / W-31**。

---

## 七、DECISION-GATE 工单（**未施工，待批**）

`#075` L18436–18441 直接输出执行性结论：

```
'A 平台净亏首位 · 立即处置'
'D VIP 优质 · 加码留存，严禁误伤'
```

其排序键为 `residual_b`，而 AG-03 = `UNRESOLVED`，`residual_*` 禁作商业处置依据；`admit_to_risk_decision = FALSE`；T-03 对 `ranking/scoring/trigger/enforcement` 之禁令为绝对。

**建议改法（两列并存，日后 AG-03 裁定只改映射层，不重算底层）：**

```sql
CASE WHEN e.stake IS NULL OR e.stake<=0 OR e.n_bets < :min_bets_derived
       THEN 'Z 证据不足'
     WHEN PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost) <= 0.10
       THEN 'A 残值最低十分位 · 待裁'
     WHEN PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost) >= 0.80
       THEN 'D 残值最高二十分位 · 待裁'
     ELSE 'E 常规' END                       AS action_priority,
'PENDING_AG03'                               AS decision_status,
'FALSE'                                      AS admit_to_risk_decision,
'NOT_FOR_ENFORCEMENT'                        AS deliverable_class,
```

`:min_bets_derived` 须由 UNIVERSE-PROBE 的分位推导，不得沿用硬编码 `30`。

---

## 八、ARCHIVE-NORM-01（另立，不混入 HF8b/HF8c）

现有六件导出 CSV 行尾不一致：`S01 / S05 / I_ip_player = CRLF`，`C01 / C08_all / C08_sparse = LF`。
归档纪律要求 CRLF。**但转换会改 MD5，须另立闸门并单独记录换算关系**（CRLF→LF 字节差恰等于行数）。本轮不动。

---

## 九、施工序列（修订版）

```
HF8
 └─ 已证：#075 S01 八项逐位 PASS（自 CSV 实算）
HF8b        ← ★ 本轮交付，已过 STRUCTURE-GATE
 └─ 129/129 件号 · 129/129 audit_rn · 129/129 末层 ORDER BY · 0 裸分号 · 0 残留
UNIVERSE-PROBE          ← ★ 提前至此（原 参考.txt 无此步）
 └─ 测 U1/U2/U3 与各件放大倍数 + 容量评估
HF8c        代理链五级化（13 件，纯增列，旧列留锚）
UNIVERSE-GATE           14 件宇宙门 → 证据标签
DECISION-GATE           AG-03 未裁不得宣判
正式落盘    128 件（#002 单独封锁）
HF9         块注释 · checksum contract · 版本自证 · LIMIT 20 定性 · 前言排序键 · ARCHIVE-NORM-01
```

**未获先生逐项批准，HF8c / UNIVERSE-GATE / DECISION-GATE 一律不施工。**
