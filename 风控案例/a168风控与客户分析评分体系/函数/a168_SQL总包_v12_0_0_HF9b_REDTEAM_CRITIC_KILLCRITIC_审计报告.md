# A168 SQL 总包 v12.0.0-HF9b · REDTEAM / CRITIC / KILLCRITIC 审计报告

## 结论先行

两份附件经过静态逐模块核验后，结论分三层：

1. **两版的业务核心 CTE / 聚合逻辑目前是逐模块一致的：129 / 129。**
   - 我将两版外层“分批包装 / audit_rn 包装”剥离后，对 129 个同名模块逐一规范化比较。
   - 129 个模块的核心 `WITH x_ranked ...` 逻辑全部一致。
   - 因此，“分批版与原版核心业务逻辑不同”这一指控目前**不成立**。

2. **但是，现版存在数个真正的 REDTEAM 阻断项。**
   - 分批版的“分批”只是**结果集分页**，不是计算分片；每一批仍重新执行完整扫描、聚合、窗口排序。
   - 分批版还额外先执行一次 `T_true` 全量计数，因此第 1 批至少多做一轮完整逻辑计算；多批执行后，总计算量可能远高于原版。
   - `audit_rn` 的稳定性依赖排序键，而基础注单去重 `ROW_NUMBER()` 的 `ORDER BY` 原本没有足够的确定性 tie-breaker。
   - 文件名是 HF9b，但内部主标题仍写 HF3，属于**版本血统漂移**。
   - 顶部已经宣布 AG-03 候选 B 已定案，但实际输出仍写 `AG03-UNRESOLVED` / `PENDING_AG03`，属于**口径状态与代码状态冲突**。
   - 顶部声明权威字段是 `agent_cost / net_margin / net_margin_rate`，实际输出却主要暴露为 `cost_complement_b / residual_b / residual_b_rate`，属于**数据契约名实不一致**。

3. 我已经生成一组 **REDTEAM_HF9bR1 候选修订版**。
   - 不覆盖原件。
   - 修正已能由脚本自身证据确定的缺陷。
   - 不擅自改变尚缺业务证据的 `bet23 NULL` 会计语义，也不把“结果分页”伪装成真正计算分批。

---

## 一、文件级核验

| 项目 | 分批作业版 | 原版审计版 |
|---|---:|---:|
| 文件大小 | 6,811,809 bytes | 3,318,062 bytes |
| 模块数 | 129 | 129 |
| 核心 CTE 比对 | 129/129 一致 | 129/129 一致 |
| 括号平衡 | PASS | PASS |
| 字符串/注释扫描 | PASS | PASS |
| 语法级结构静态检查 | PASS（未连接数据库） | PASS（未连接数据库） |
| 原版 `audit_rn` | 有 | 有 |
| 分批 `batch_id` | 有 | 无 |
| `T_true` 预计数 | 有 | 无 |

### 重要限定

这里的“PASS”是**静态结构审计**，不是数据库执行通过。

本次没有真实连接你的 StarRocks 集群，因此不能把以下事项冒充为已执行验证：

- 真实表是否存在；
- 字段类型是否与当前生产库完全一致；
- 当前集群版本是否接受全部 session variable；
- 实际 Query Profile；
- 实际 OOM；
- 实际输出行数；
- 真实数据下的 AG-03 数值闭合。

---

# 二、KILLCRITIC：最重要的致命问题

## K1 · “分批作业”实际上不是计算分批

分批版的结构本质是：

`完整 WITH / JOIN / GROUP BY / PERCENTILE_APPROX / WINDOW`
→ `ROW_NUMBER()`
→ `WHERE audit_rn BETWEEN ...`

也就是说：

> `WHERE audit_rn` 发生在全局 `audit_rn` 已经计算之后。

因此：

- 第 1 批不是只计算前 100,000 行；
- 第 2 批也不是只计算 100,001–200,000；
- 每一批都必须重新完成整个候选总体的计算，才能知道这些行的 `audit_rn`。

这在 StarRocks 窗口函数的执行语义下尤其重要：窗口计算发生在 JOIN / WHERE / GROUP BY 之后，再由外层过滤结果。官方文档亦明确说明窗口函数是在这些操作之后生效。

因此目前的“分批”准确名称应是：

> **分批取数 / 分批导出**

而不是：

> **分批计算 / 分批作业**

### 后果

如果一个模块需要 N 批：

- 原版：约 1 次完整计算；
- 当前分批版：约 N 次完整计算；
- 第 1 批之前还多了一次 `T_true` 预计算。

所以当 N 较大时：

> **当前分批版可能比原版更耗 CPU、IO、内存和总运行时间。**

这不是理论吹毛求疵，而是当前脚本结构直接决定的。

---

# 三、KILLCRITIC · T_true 又把问题放大了一层

每个分批模块先执行：

`SELECT COUNT(*) AS T_true FROM (完整业务查询)`

然后再执行一次真正的：

`SELECT ... ROW_NUMBER() ... WHERE audit_rn ...`

因此第 1 批至少存在：

> **先完整算一次 → 再完整算一次**

虽然优化器可能对 COUNT 子查询做部分列裁剪，但不能把它当成“廉价 count”。

所以当前流程：

`T_true → 第1批 → 第2批 → ...`

并不是：

`一次计算 → 多次读取`

而更接近：

`多次重新计算 → 多次读取`

---

# 四、KILLCRITIC · 跨批一致性没有被锁住

原版审计版是一条查询。

分批版则要求人工执行：

- 第 1 批；
- 第 2 批；
- 第 3 批；
- ...

如果底层 `ods_a168_bet02` 或关联表在批次之间发生：

- 补数；
- 修正；
- 删除；
- Upsert；
- 延迟同步；

那么第二批重新计算出来的 `audit_rn` 可能已经移动。

于是理论上会出现：

- 同一行进入不同批次；
- 某行漏掉；
- 某行重复；
- 两批拼起来不再等于某一时刻的完整原版结果。

所以：

> **`audit_rn` 本身不能跨多个独立 SELECT 自动形成一个稳定快照。**

真正的解决方案应当是：

`一次完整计算`
→ `物化 canonical result`
→ `冻结 audit_rn`
→ `WHERE audit_rn BETWEEN ...`

StarRocks 当前文档支持 `CREATE TEMPORARY TABLE AS SELECT`，且临时表生命周期可以绑定 Session；这正适合把一次昂贵计算变成后续批次的稳定读取。

---

# 五、KILLCRITIC · 注单去重排序原本不具备完全确定性

两版都大量使用：

`ROW_NUMBER() OVER (PARTITION BY b.bet01 ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)`

问题是：

如果同一 `bet01` 有多行同时满足：

- `updatetime` 相同；
- `sync_time` 相同；
- `dt` 相同；

那么 `ROW_NUMBER()` 没有唯一 tie-breaker。

StarRocks 官方 FAQ 明确指出：

> 如果 ROW_NUMBER 的 ORDER BY 字段存在重复，SQL 标准不保证多次执行的稳定排序；应加入唯一字段。

这直接威胁：

`x_rn = 1`
→ canonical bet
→ x_agg
→ 六层商业指标
→ audit_rn

整条链的可重复性。

---

# 六、KILLCRITIC · HF9b 文件内部仍自称 HF3

文件名：

`v12_0_0_HF9b`

内部主标题却仍然：

`a168 SQL 总包 v12.0.0-HF3`

这不是单纯美观问题。

在审计系统里，版本身份必须能回答：

> “这份 SQL 到底是哪一版？”

否则容易出现：

- HF9b 文件被当 HF3；
- 审计日志记录 HF3；
- 输出文件名记录 HF9b；
- 后续无法证明哪个修订真正产生结果。

这是典型的 **version drift / provenance defect**。

---

# 七、KILLCRITIC · AG-03 已定案，但代码仍写“未决”

顶部明确写：

> AG-03 已判决 = 候选 B

但输出字段仍存在：

- `AG03-UNRESOLVED`
- `PENDING_AG03`

这已经不是意见问题，而是：

> **文档状态 ≠ 程序状态**

尤其严重的是，顶部同时宣称：

`net_margin = ngr - agent_cost`

为正式商业口径。

如果下游程序读取 `agent_formula_version` / `decision_status`，会得到“尚未判决”的机器事实。

这属于应该立即修复的状态契约错误。

---

# 八、KILLCRITIC · 权威字段名称没有真正落到输出

顶部定义：

- `agent_cost`
- `net_margin`
- `net_margin_rate`

实际六层输出主要是：

- `cost_complement_b`
- `residual_b`
- `residual_b_rate`

也就是说：

> **公式已经回到 B 候选，但字段契约仍停留在旧命名。**

这会导致：

- SQL 口径文档说 `net_margin`；
- 下游数据字典找不到 `net_margin`；
- 风控规则可能继续读 `residual_b`；
- 不同版本出现 alias drift。

这是非常典型的“公式修好了，但数据契约没有完全修好”。

---

# 九、六层商业指标并非 129 件都可直接商业消费

当前登记结果：

| net_margin 状态 | 件数 | 处理 |
|---|---:|---|
| OK | 24 | 可直接商业判定 |
| WRONG_GRAIN | 37 | 只能背景使用 |
| INVALID | 67 | 不得用于决策 |
| NULL | 1 | 六层不可用 |
| **合计** | **129** | |

所以：

> **只有 24 / 129 = 18.6% 的模块可以直接把六层 net_margin 当本行事实使用。**

其余 105 件不是“商业指标失败”，而是本来就属于：

- 上层粒度广播；
- 笛卡尔广播；
- 元数据；
- 桥接；
- 支撑证据；
- 跨实体连接。

这点原脚本其实已经写得很诚实。

但 REDTEAM 建议进一步升级：

> **不要继续把“六层商业字段”物理注入全部 129 件。**

更好的架构是：

`Evidence Output`
+
`Commercial Accounting Output`

两者分离。

---

# 十、潜在会计风险：bet23 NULL 被强制当成 0

代码使用：

`COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL),0)`

于是：

`bet23 = NULL / blank`

会被解释为：

`company_retain_pct = 0`

继而：

`agent_pct = 100`

这在数学上是明确的，但在业务上并不自动成立。

可能存在至少三种含义：

1. 真的是 0% 公司自留；
2. 字段缺失；
3. 该记录不适用代理分成。

目前脚本没有把三者区分。

### 这里我没有擅自改公式

这是刻意的。

因为：

> 这是需要真实数据字典 / 生产样本证明的业务语义，而不是可以仅靠 SQL 静态审计替你决定的事实。

正确升级应增加：

- `ag03_pct_status`
- `ag03_missing_flag`
- `ag03_coverage_rate`
- `net_margin_eligibility`

然后规定：

> AG-03 coverage 不达标时，net_margin 不得进入风险决策。

---

# 十一、硬编码日期也是长期维护风险

全包大量硬编码：

- `2026-03-21`
- `2026-08-07`
- `2026-07-08`

这对一次性冻结审计是合理的。

但对商业生产脚本则有风险：

> 下一次复制脚本如果忘记修改日期，整个 129 件包仍可能“成功执行”，但分析窗口已经悄悄过期。

建议把：

- `analysis_start`
- `analysis_end`
- `recent_start`

提升为统一会话参数或单一参数 CTE。

---

# 十二、PERCENTILE_APPROX / Window 计算本身合法，但非常重

当前包大量使用：

- `PERCENTILE_APPROX`
- `PERCENT_RANK`
- `NTILE`
- 多层 `ROW_NUMBER`

这些函数在 StarRocks 当前文档中均有对应支持；`PERCENTILE_APPROX` 也是官方提供的近似分位数函数。

因此：

> **函数本身不是主要红队问题。**

真正的问题是：

> 同一个昂贵逻辑被 129 个模块重复计算，再被分批版重复计算。

所以优化方向不应是“删掉 PERCENTILE_APPROX”，而应是：

`canonical base`
→ `canonical accounting`
→ `materialized evidence`
→ `module-specific aggregation`

而不是每个模块重新从 `ods_a168_bet02` 开始。

---

# 十三、已经实施的 REDTEAM_HF9bR1 修补

我生成了两份候选修订版，原文件没有覆盖。

### 已修 1 · 明确当前版本身份

加入：

`v12.0.0-HF9b`

并注明 AG-03 B 是承继 HF3 的正式判定。

### 已修 2 · AG-03 状态同步

将：

`AG03-UNRESOLVED`

改为：

`AG03-RESOLVED-B`

将：

`PENDING_AG03`

改为：

`RESOLVED_AG03_B`

### 已修 3 · 恢复正式 canonical accounting alias

在最终输出层增加：

- `agent_cost`
- `net_margin`
- `net_margin_rate`

旧字段：

- `cost_complement_b`
- `residual_b`
- `residual_b_rate`

仍保留，避免破坏历史审计。

### 已修 4 · 强化 bet01 去重稳定性

在原来的：

`updatetime → sync_time → dt`

之后增加输出相关源字段作为确定性 tie-breaker。

这意味着：

- 不改变正常唯一 bet01 的结果；
- 如果时间字段相同但记录内容不同，则有稳定排序；
- 如果连全部这些字段都完全相同，则这些记录在当前业务输出上本身不可区分。

### 已修 5 · 明确“分批≠计算分片”

在分批版顶部加入 REDTEAM 运行语义警告，避免后续人员把：

`WHERE audit_rn`

误认为：

`WHERE pushed down into base computation`。

---

# 十四、我刻意没有自动修的三项

## A. 没有把 bet23 NULL 自动改成 NULL 成本

因为这属于业务事实，不应由红队擅自猜测。

## B. 没有把分批版直接改成 CTAS 临时表架构

这是下一阶段最值得做的升级，但会改变：

- 权限要求；
- Superset 执行流程；
- Session 生命周期；
- 输出流程；
- 清理策略。

所以应先确认生产环境允许 StarRocks Temporary Table。

## C. 没有把 129 件全部强制变成“可决策”

原包已经明确承认：

`67 INVALID + 37 WRONG_GRAIN + 1 NULL`

这些不能靠改 SQL alias 变成可信商业事实。

---

# 十五、下一版建议架构

建议直接从：

`v12.0.0-HF9b`

升级成：

`v12.0.0-HF10`

并拆成四层：

## L0 · Source Freeze

冻结：

- 时间窗口；
- 数据版本；
- source row count；
- bet01 duplicate profile；
- bet11 / bet23 coverage。

## L1 · Canonical Bet

只做一次：

- bet01 dedup；
- canonical fields；
- FX normalization；
- test-line exclusion；
- source fingerprint。

## L2 · Canonical Accounting

只做一次：

- stake
- valid_bet
- profit
- rebate_cost
- agent_cost
- ngr
- net_margin
- net_margin_rate
- accounting_status

## L3 · Materialized Audit Result

一次计算：

- module output；
- deterministic `audit_rn`；
- `row_fingerprint`；
- `run_id`；
- `as_of_ts`；
- `source_window`.

然后所有批次只执行：

`WHERE audit_rn BETWEEN ...`

## L4 · Commercial / Evidence split

最终分为：

- `PRIMARY`
- `SCREENING`
- `SUPPORT`
- `REFERENCE`
- `NOT_FOR_DECISION`

而不是把六层指标机械挂在所有 129 件。

---

# 十六、最终裁定

### 原版审计版

**判定：结构上较干净，适合作为单次完整审计基准，但仍有会计字段命名、AG-03 状态、dedup determinism 等问题。**

### 分批作业版

**判定：业务核心逻辑没有被改坏，但“分批作业”这个名称具有误导性。它是分批取数，不是分批计算；在 OOM 场景下甚至可能适得其反。**

### 两版一致性

**判定：核心业务逻辑 129 / 129 一致。**

因此目前最重要的不是继续争论：

> “两版公式是否一致？”

答案已经可以锁：

> **一致。**

真正应该进入下一轮 REDTEAM 的，是：

> **怎样让一次完整计算可冻结、可复用、可分批读取，并且让 audit_rn 真正成为跨批稳定的审计坐标。**

---

## 生成文件

原件保持不动。

- 原版：`a168_SQL总包_v12_0_0_HF9b_分批作业版_六层商业版.sql`
  SHA-256: `b67c30d5efcf7b6043d969e61b426ebe431e7b80b0c2724b09adba6aa0ee258c`

- 原版：`a168_SQL总包_v12_0_0_HF9b_原版审计版_六层商业版.sql`
  SHA-256: `518392cc04841d75ba19ef4a2be4d80ac08212d77208871d596517a7bd99a983`

### REDTEAM_HF9bR1 候选修订版

- `a168_SQL总包_v12_0_0_HF9b_分批作业版_六层商业版_REDTEAM_HF9bR1.sql`
  SHA-256: `283bba0c27f1acff6f3bc1b8fff3742db96b3078d38356bf9261216819d24d13`

- `a168_SQL总包_v12_0_0_HF9b_原版审计版_六层商业版_REDTEAM_HF9bR1.sql`
  SHA-256: `67ebf5796bf0756b741075f59b6b25a919d9d7bb1062211413681903229881b7`

> 注：最后一项 SHA-256 应以文件实际校验工具再次复核后再登记进正式血统台账；本轮静态检查已经确认文件可读、129 模块存在、括号平衡、两版核心逻辑 129/129 对齐。
