-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ HF9f · 落盘前回归闸（schema 驱动）· 配 a168_SQL总包_v12_0_0_HF9f_*版_六层商业版 ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 用途：HF9f 任一件落盘之前，先跑本闸。三判据全过方准落盘；任一不过即整件作废。
-- 铁律：白名单不写死于本档，改由 column_registry_v1.0_075.csv 之 class 栏驱动（A1 逐位／A2 容差／B 血统）。
-- 排除：audit_rn · batch_id · run_id 三列按设计排除于逐位比对之外（行号／批号／运行标识非事实列）。
-- 注意：本档为只读校验，不建表、不写数；行注释 only，禁块注释；无 OFFSET；ID 比较一律显式 CAST。

-- ── 判据① 会员集合恒等：HF9f 之 n_rounds>=30 子集，须与 HF9d 之 161,156 名逐 ID 恒等 ──
-- 期望：n_hf9f_qualified = 161156，且 n_only_hf9f = 0、n_only_hf9d = 0。
-- 说明：HF9d 之 CSV 须先落地为可查对象；若仅有档案，则以本闸左半在 HF9f 上取数后与档案外部比对。
SELECT                                                                                              -- 取列：起始取列子句
  'GATE-1 会员集合' AS gate_id,                                                                      -- 字面取值：闸门编号
  COUNT(*) AS n_hf9f_qualified,                                                                     -- 计数表达式：HF9f 合格子集之会员数
  161156 AS n_hf9d_expected,                                                                        -- 字面取值：HF9d 之登记行数（已由 HF9d 原档实测确认）
  CASE WHEN COUNT(*) = 161156 THEN 'PASS' ELSE 'FAIL' END AS verdict                                -- 条件分支：收束判词
FROM (                                                                                              -- 取数来源：起始子查询
  -- ★ 此处置入 HF9f #075 之完整交付件查询，外层仅加 WHERE n_rounds >= 30 ★
  -- ★ 占位：待落盘作业时，将《a168_SQL总包_v12_0_0_HF9f_原版审计版_六层商业版.sql》#075 区块（行 24436 起）整段粘入 ★
  SELECT 1 AS n_rounds WHERE 1 = 0                                                                  -- 占位取值：本行为空集占位，未替换前本闸恒回 FAIL，属刻意设计
) g                                                                                                 -- 取数来源：收束子查询
WHERE g.n_rounds >= 30;                                                                             -- 过滤条件：限定合格子集

-- ── 判据② 台账锚逐位：合格子集之 Σstake 须等于 13,149,241,210.83 ──
-- 期望：sum_stake_qualified = 13149241210.83（HF9d 原档实测值，已两次独立复算）。
SELECT                                                                                              -- 取列：起始取列子句
  'GATE-2 台账锚' AS gate_id,                                                                        -- 字面取值：闸门编号
  ROUND(SUM(g.stake), 2) AS sum_stake_qualified,                                                    -- 聚合取值：合格子集之本金合计
  13149241210.83 AS anchor_expected,                                                                -- 字面取值：HF9d 之台账锚
  CASE WHEN ROUND(SUM(g.stake), 2) = 13149241210.83 THEN 'PASS' ELSE 'FAIL' END AS verdict           -- 条件分支：收束判词
FROM (                                                                                              -- 取数来源：起始子查询
  -- ★ 同上，置入 HF9f #075 完整交付件查询 ★
  SELECT CAST(0 AS DECIMAL(38,8)) AS stake, 0 AS n_rounds WHERE 1 = 0                               -- 占位取值：空集占位
) g                                                                                                 -- 取数来源：收束子查询
WHERE g.n_rounds >= 30;                                                                             -- 过滤条件：限定合格子集

-- ── 判据③ 列级差异分类：A1 逐位／A2 容差／B 血统 ──
-- 本判据不在 SQL 内完成，须由外部比对脚本按 column_registry 之 class 栏执行，判词如下：
--   class = A1   ⇒ 与 HF9d 同批 161,156 名逐位相同，容差 0。任一行不同即 FAIL。
--   class = A2   ⇒ 容许相对差 ≤ 0.5%（承 HF9d↔HF9e 实测上界 0.454%，见 F-4 敏感性实验后收紧）。
--                  且不同行数须 ≤ 5 行 / 161,156（承实测 1–3 行）。
--   class = B    ⇒ 容许数值差异（分母已由 161,156 变 723,442），但 pr_* 血统五元组须完整且自洽：
--                  pr_global_population_n = 本件总行数；pr_qualified_population_n = n_rounds>=30 之行数。
--   class = META ⇒ 不比对。
-- 期望之已知差异（HF9e → HF9f，非缺陷，属本版设计）：
--   economic_value  方向翻转（F-19）· action_priority A/D 标签更名（F-20）· Z 档扩张 +18,537（F-2）· 新增 11 列。

-- ── 判据④ 反演还原：HF9f 之 Z 档人数须等于 HF9e 之 Z 档人数 ＋ 18,537 ──
-- 期望：#075 之 n_z_hf9f = 562286（＝ HF9e 543,749 ＋ 盲区 18,537）。此数由 HF9e CSV 实测反解，可第三方复算。
SELECT                                                                                              -- 取列：起始取列子句
  'GATE-4 Z档反演' AS gate_id,                                                                       -- 字面取值：闸门编号
  SUM(CASE WHEN g.action_priority LIKE 'Z%' THEN 1 ELSE 0 END) AS n_z_hf9f,                         -- 聚合取值：HF9f 之 Z 档人数
  562286 AS n_z_expected,                                                                           -- 字面取值：预期值 543749 + 18537
  CASE WHEN SUM(CASE WHEN g.action_priority LIKE 'Z%' THEN 1 ELSE 0 END) = 562286                   -- 条件分支：起始分支
       THEN 'PASS' ELSE 'FAIL' END AS verdict                                                        -- 条件分支：收束判词
FROM (                                                                                              -- 取数来源：起始子查询
  -- ★ 同上，置入 HF9f #075 完整交付件查询 ★
  SELECT CAST('' AS STRING) AS action_priority WHERE 1 = 0                                          -- 占位取值：空集占位
) g;                                                                                                -- 取数来源：收束子查询
