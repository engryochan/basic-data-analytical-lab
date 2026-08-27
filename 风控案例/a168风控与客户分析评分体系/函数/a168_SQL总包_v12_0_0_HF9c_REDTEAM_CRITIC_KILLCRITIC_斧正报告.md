# a168 SQL HF9c · REDTEAM / CRITIC / KILLCRITIC 斧正报告

## 结论

本次不是把 R1 整体合并，而是以 **HF9b 为唯一数值基底**，把 HF10 与 R1 中已经通过红队裁定的运行治理与 accounting contract 一次性并入，形成 **HF9c**。

### 明确拒绝

- `AG03-RESOLVED-B` / `RESOLVED_AG03_B`：拒绝。AG-03 保持 `UNRESOLVED / PENDING_AG03`；历史候选 B 仅作为 provenance，不因重新计算或重新命名自动升级。
- 27 列 tie-breaker：拒绝。保留 `updatetime DESC, sync_time DESC, dt DESC` 三列；没有真实源唯一键就不伪造 deterministic dedup。
- CRLF → LF：拒绝。HF9c 输出统一恢复 CRLF。

### 综合采纳

- canonical accounting contract：采纳，但不采用 R1 的裸 `agent_cost / net_margin / net_margin_rate` 命名。
- canonical rate：直接从未舍入的 `e.*` 与 `e.stake` 计算，避免 `ROUND(...,4)` 后再除造成 W-56 型舍入分裂。
- 五级与两种链式口径：同时提供显式 scope 的 canonical 字段。
- 分批语义：正式写死为 **分批取数 ≠ 分批计算**。
- 批次变量：统一使用 `@a168_batch_lo / @a168_batch_hi / @a168_batch_size`，不再逐件手改 SQL 主体。
- `T_true`：取消 129 件逐件完整预跑；末批由实际返回行数 `< batch_size` 判定，最终用各批 `audit_rn` 区间核对总量。
- 跨批快照：使用 StarRocks user-defined variables 固定 `@a168_run_id` 与 `@a168_snapshot_sync_time`；所有直接读取 `ods_a168_bet02` 的来源均加同一 watermark。
- 审计元数据：两版均输出 `run_id` 与 `snapshot_sync_time`；分批版另外输出 `batch_id`。

## 四元版本身份核验

| 文件 | bytes | 行数 | CRLF | 裸 LF | MD5 |
|---|---:|---:|---:|---:|---|
| HF9b 原版审计 | 3,318,062 | 38,390 | 38,390 | 0 | `169a4efa4cd9546713f63a92416a441a` |
| HF9b 分批 | 6,811,809 | 79,935 | 79,935 | 0 | `78241a3a2c5665b5b27b74d1eaade31d` |
| HF9c 原版审计 | 3,676,157 | 42,630 | 42,630 | 0 | `9e270822dbfb80213d276ae9dbcbbc0f` |
| HF9c 分批 | 4,072,042 | 47,658 | 47,658 | 0 | `fd5200a332ba55cd9c6e88ec8b020ca4` |

HF9b 原件 MD5 与交付基底一致：原版 `169a4efa4cd9546713f63a92416a441a`；分批版 `78241a3a2c5665b5b27b74d1eaade31d`。HF9c 两份均为 CRLF、裸 LF = 0。

## HF9c 实施项

### 1. AG-03 状态机

机器字段保持：

```text
agent_formula_version = AG03-UNRESOLVED
decision_status       = PENDING_AG03
admit_to_risk_decision = FALSE
deliverable_class     = NOT_FOR_ENFORCEMENT
```

另加 `agent_formula_candidate = 'B'` 的文档性说明，但不把 candidate 当 resolved。

### 2. Canonical accounting

128 个含六层商业口径的模块均新增 canonical contract。核心字段包括：

- `agent_cost_bet23_formal_canonical`
- `net_margin_bet23_formal_canonical`
- `net_margin_bet23_formal_rate_canonical`
- `agent_cost_lv1_bet23_canonical` … `agent_cost_lv5_bet27_canonical`
- `net_margin_lv1_bet23_canonical` … `net_margin_lv5_bet27_canonical`
- `agent_cost_chain_additive_canonical`
- `agent_cost_chain_nested_canonical`
- `net_margin_chain_additive_canonical`
- `net_margin_chain_nested_canonical`
- 对应未舍入分子直接计算的 canonical rates

现有 `cost_complement_b / residual_b / residual_b_rate` 等字段全部保留，不删除、不覆盖。

### 3. Snapshot / watermark

HF9c 在同一 Session 先建立：

```sql
SET @a168_run_id = ...;
SET @a168_snapshot_sync_time = NOW();
```

随后所有直接读取 `ods_a168_bet02` 的来源均加入：

```sql
... sync_time <= @a168_snapshot_sync_time
```

这解决的是**跨批事实宇宙漂移**，不是数据完整性证明；迟到数据仍须另行审计。若期间发生补数/修数，当前 run 必须作废并重新建立 run_id。

### 4. 分批版

取消 129 件 `T_true` 的完整预跑；每批使用：

```sql
@a168_batch_size
@a168_batch_lo
@a168_batch_hi
```

实际过滤：

```sql
WHERE z.audit_rn > @a168_batch_lo
  AND z.audit_rn <= @a168_batch_hi
```

并输出：

```text
batch_id
run_id
snapshot_sync_time
```

注意：这仍然是**完整计算后切片**，不是计算分片，不应被当成 OOM 根治。

## 静态验收

- HF9c 原版 `audit_rn`：129
- HF9c 分批 `audit_rn`：129
- canonical 商业模块：128 / 128
- `AG03-RESOLVED-B`：0
- `RESOLVED_AG03_B`：0
- 27 列 tie-breaker：0
- HF9c 分批可执行 `T_true`：0
- HF9c 分批实际 batch WHERE：129 / 129
- HF9c 原版实际 batch WHERE：0
- 两份 HF9c：CRLF 全量、裸 LF = 0
- 静态括号扫描（忽略字符串及注释）：通过

## 一个必须保留的边界

HF9c 没有把 `agent_formula_candidate = B` 提升为 `RESOLVED`，也没有把 canonical 字段自动视为风险可执行字段。`canonical ≠ admissible`；24 / 37 / 67 / 1 的既有 grain / evidence 状态全部继承。

## 最终版本血统

```text
HF9b
  ├─ 数值公式 / 129 模块核心逻辑：继承
  ├─ R1-1 AG03 RESOLVED：拒绝
  ├─ R1-3 27 列 tie-breaker：拒绝
  ├─ LF：拒绝，恢复 CRLF
  ├─ R1-2：改造成 scope-explicit canonical accounting contract
  ├─ R1-4：正式锁定「分批取数 ≠ 分批计算」
  ├─ HF10：run_id / snapshot watermark / batch variables / T_true 优化
  └─ => HF9c
```

> HF9c 是一次性综合修订版；原 HF9b 文件未覆盖。
