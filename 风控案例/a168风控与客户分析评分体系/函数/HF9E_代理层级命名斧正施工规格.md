# HF9-E · 代理层级命名斧正施工规格

**日期**：2026-08-27
**性质**：**纯命名与增列**。零口径变更、零 predicate 变更、旧名一律留锚。
**起因**：Ryo Eng 先生令 —— 「每个牵涉到代理阶层的数据表与维度，务必包含各阶层代理而非仅仅 lv3 而已。倘若目前包含了各阶层的话，务必重新命名列名。」

---

## 一、核实：先分清「CSV 出列名」与「CTE 内部名」

我先前的命名审计把两者混为一谈，须先斧正自己。以 `S01_player_score.csv` 的**实际表头**逐名核对：

| 名称 | 是否出现在 CSV 表头 | 性质 |
|---|---|---|
| `agent_cost` | **否** | `x_agg` CTE 内部名，下游以 `e.agent_cost` 引用 |
| `agent_pct` | **否** | CTE 内部名 |
| `company_retain_pct` | **否** | CTE 内部名 |
| `x_agpct` | **否** | `x_bs0` CTE 内部名 |
| `cost_complement_b` | **是** | 出列 |
| `pct_complement` | **是** | 出列 |
| `pct_top_bet23` | **是** | 出列 |
| `agent_cost_a_legacy` | **是** | 出列 |
| `agent_cost_valid_base_legacy` | **是** | 出列 |
| `residual_a` / `residual_b` | **是** | 出列 |
| `residual_a_rate` / `residual_b_rate` | **是** | 出列 |
| `n_chain` | **是** | 出列（已裁 KILLED） |
| `agent_formula_version` | **是** | 出列常量 |

**修正**：CTE 内部名**不进 CSV**，先生和任何消费端都看不到，**改它们没有商业价值，反而须改动 128 件的下游引用，风险高、收益零**。

⇒ **HF9-E 只动出列名，不动 CTE 内部名。** 我上一轮说「9 列 × 128 件」，其中 3 个是 CTE 内部名，实际须处置的出列名是 **8 个**。

---

## 二、层级范围的实证

`HF8b 原版审计版 L328`：

```sql
COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0) AS x_agpct
```

`x_agpct = bet23` —— **仅 LV1（顶级）占成率**。`bet24`~`bet27`（二至五级）不进入计算。

这是 **HF2 的刻意取舍**（原为 Σ五级，因五级之和 = 460%、加法份额解读矛盾而改为 bet23），是 AG-03 `UNRESOLVED` 的直接来源，**不是新缺陷**。

**但名称欺骗是真的**：`cost_complement_b` 读作「补集成本」、`residual_b` 读作「平台残值」，无一字声明只算了一层。任何人拿到 CSV 都会误读为「已扣全部五级代理成本」。

---

## 三、施工清单（八列 + 一列新增）

### A · 已锁八项台账内的两列 —— **旧名留锚，并出新列**

`cost_complement_b` 与 `residual_b` 是已锁经济账本的锚（8,073,461 / 180,660,651），**改名即全部锚点作废**。故：

```sql
ROUND(e.agent_cost,4)                           AS cost_complement_b,        -- LEGACY 留锚，值不变
ROUND(e.agent_cost,4)                           AS cost_complement_lv1_b,    -- 新增，同值，声明层级
ROUND(-e.net-e.rebate-e.agent_cost,4)           AS residual_b,               -- LEGACY 留锚，值不变
ROUND(-e.net-e.rebate-e.agent_cost,4)           AS residual_lv1_b,           -- 新增，同值，声明层级
```

### B · 未入台账的六列 —— **旧名留锚 + 并出新名**（与 A 同法，保持全包一致）

| 旧名（留锚） | 新增名 |
|---|---|
| `pct_complement` | `pct_complement_lv1` |
| `agent_cost_a_legacy` | `agent_cost_a_lv1_legacy` |
| `agent_cost_valid_base_legacy` | `agent_cost_valid_base_lv1_legacy` |
| `residual_a` | `residual_lv1_a` |
| `residual_b_rate` | `residual_lv1_b_rate` |
| `residual_a_rate` | `residual_lv1_a_rate` |

> **为何不直接改名而要双列**：直接改名会使六件已导出 CSV（MD5 在册）无法逐列对账，违反「旧列留锚，新列增益」原则。双列的代价是每件多 8 列，`S01` 由 85 列增至 93 列，可接受。

### C · 全 129 件新增一列常量 —— 把层级范围写进每一行

```sql
'LV1_ONLY_bet23'                                AS agent_level_scope,
```

与既有 `agent_formula_version = 'AG03-UNRESOLVED'` 并列。**这一列的价值最高**：无须读文档，看 CSV 即知代理成本只算了顶级一层。

### D · `pct_top_bet23` —— **PASS，不动**

名称已含 `bet23` 与 `top`，层级范围自明。

### E · `#007` 的 `member_per_chain` —— 更名 + 五级版

```sql
COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv3),0)  AS member_per_chain,        -- LEGACY 留锚
COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv3),0)  AS member_per_lv3_chain,    -- 更名版
COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv1),0)  AS member_per_lv1_chain,
COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv2),0)  AS member_per_lv2_chain,
COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv4),0)  AS member_per_lv4_chain,
COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv5),0)  AS member_per_lv5_chain,
```

### F · `f_multi_parent_*` —— 四层齐出，零值层照出

```sql
f_multi_parent_lv2, f_multi_parent_lv3, f_multi_parent_lv4, f_multi_parent_lv5,
GREATEST(f_multi_parent_lv2, f_multi_parent_lv3,
         f_multi_parent_lv4, f_multi_parent_lv5)  AS f_multi_parent_any,
CONCAT_WS('|', ...)                               AS multi_parent_levels,
```

**实测为零的层（lv2/lv3/lv5）照常出列，值恒为 0** —— 不因为零就省略。省略即等于把「已实测为零」偷换成「未测」，二者证据等级不同。

---

## 四、回归闸（用现有六件 CSV 作锚，零额外成本）

| 判据 | 要求 |
|---|---|
| 旧列逐行不变 | `cost_complement_b` · `residual_b` · `pct_complement` 等八列，与旧 CSV **逐行逐位相同** |
| 新旧同值 | `cost_complement_lv1_b = cost_complement_b`，逐行相等（差值恒为 0） |
| 八项台账不变 | S01 求和仍为 13,149,241,211 / 11,843,669,641 / 196,872,453 / 8,138,341 / 8,073,461 / 188,734,111 / 180,660,651 / 161,156 |
| 列数 | S01 由 85 列增至 93 列（+8）；`#007` 由 82 列增至 88 列（+6） |
| 结构闸 | 129/129 件号 · 129/129 `audit_rn` · 129/129 末层 `ORDER BY audit_rn;` · 0 裸分号 · 0 残留 · 129 件配对 |

---

## 五、待批三项

| # | 事项 | 建议 |
|---|---|---|
| **1** | 只动出列名，**不动 CTE 内部名**（后者不进 CSV，改之风险高收益零） | 批准 |
| **2** | 八列一律**旧名留锚 + 并出 `_lv1_` 新名**（不直接改名，保护六件 CSV 的对账能力） | 批准 |
| **3** | 全 129 件新增 `agent_level_scope = 'LV1_ONLY_bet23'` | 批准 |

**批准后与 HF9-A/B/C/D 同轮交付。**
