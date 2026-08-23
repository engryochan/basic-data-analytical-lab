-- ══════════════════════════════════════════════════════════════════════════
-- §VB · validbet 统一契约 ＋ bet41 ≡ validbet 恒等检验  审计工具 v1.0.0
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由（三条独立证据同指一处）：
--   ① R4S03 业务锚点审计：P11c #4 之四象限 FORMULA 锚 **0/4**，
--      chk2_chk3 之 v41 <> validbet 同缺 → 三档 v10 补丁皆 NOT ARCHIVABLE。
--   ② canonical 实测：'n_both_null|n_null_asym|n_value_diff|bet41 <> validbet'
--      于代码层 **0 处**、全文 **0 处** —— 该恒等检验从未进入总包。
--   ③ 在册读数「bet41 ≡ validbet，D=0 于 99.999230%」之产出语句
--      **只活在 v10 补丁中**；补丁若归档，B-5 之证据链即断于源头。
--   → 附件裁定：**此为 v11.0.4 之一级施工项。** 本件系其设计前之实证底料。
--
-- ★ 本件不改 canonical 一字；其产出用于 v11.0.4 之 §VB-00／§VB-41 施工设计。
--
-- 【两段之别，禁混】
--   §VB-00  **契约**：validbet 之取值形态与回退规则 —— 答「该用哪一列」
--   §VB-41  **恒等**：bet41 与 validbet 是否同一量 —— 答「二者是否可互代」
--   前者定下游 JOIN 之唯一入口；后者定二列之数学关系。二者不可互相充当证据。
--
-- 【承 B-11 之教训（在册）】
--   总包内并存两式：COALESCE(vb_raw, stake_raw) 与 直取 validbet。
--   当前窗口 NULL = 0 故结果暂同 —— 惟此系**数据条件等价，非设计等价**。
--   换窗、换产品、换库即可能分歧。故须立唯一契约，禁各章各自为政。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
--   ★ CTE 名避保留字（glob／match／range／rank／value 之属，v1.0.2 已受其教训）。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-00 · validbet 契约普查（★ 答「该用哪一列、如何回退」）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_00_validbet_contract.csv」。
--   ★ 五态并出：raw 非空／raw 为空／raw 为零／回退触发／回退后仍空。
--   ★ 判读：
--     null_rate = 0        → 直取 validbet 与 COALESCE 二式等价（**当前窗口**）
--     null_rate > 0        → 二式分歧，须立唯一契约方可下游 JOIN
--     ★ 无论何者，**皆不得以「当前等价」推定「设计等价」**——承 B-11。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'validbet 契约普查（全窗 · 百家乐）'                                    AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  SUM(CASE WHEN validbet IS NULL THEN 1 ELSE 0 END)                      AS n_vb_null,              -- 条件计数：raw 为空值
  SUM(CASE WHEN validbet IS NOT NULL AND TRIM(validbet) = '' THEN 1 ELSE 0 END) AS n_vb_blank,      -- 条件计数：raw 为空串
  SUM(CASE WHEN CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_vb_zero, -- 条件计数：raw 为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_vb_pos,  -- 条件计数：raw 为正
  SUM(CASE WHEN CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_vb_neg,  -- 条件计数：★ raw 为负——若非零须追成因
  ROUND(SUM(CASE WHEN NULLIF(TRIM(validbet), '') IS NULL THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 8)                                        AS null_rate_pct,          -- 比率表达式：★★ 回退触发率——二式分歧之量
  SUM(CASE WHEN NULLIF(TRIM(validbet), '') IS NULL
             AND NULLIF(TRIM(bet13), '') IS NULL THEN 1 ELSE 0 END)      AS n_fallback_also_null,   -- 条件计数：★ 回退源 bet13 亦空——契约在此失效
  ROUND(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 2)       AS vb_sum,                 -- 汇总表达式：raw 总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 2)          AS b13_sum,                -- 汇总表达式：本金总额——与 vb 对照
  ROUND(SUM(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))), 2)          AS b41_sum,                -- 汇总表达式：bet41 总额
  CASE                                                                                              -- 条件分支：起始分支——契约裁定
    WHEN SUM(CASE WHEN NULLIF(TRIM(validbet), '') IS NULL THEN 1 ELSE 0 END) = 0
      THEN '◐ 本窗口内 null_rate = 0 —— 直取与 COALESCE 二式**数据条件等价**（★ 非设计等价，换窗须重验）' -- 分支判定：暂时等价
    ELSE '❌ 二式分歧 —— 须立唯一契约 validbet_effective，禁各章各自为政'                              -- 分支判定：须立契约
  END                                                                    AS verdict_contract        -- 条件分支：收束上方判词，产出「verdict_contract」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101';                                                                -- 并列条件：限定百家乐


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41 · bet41 ≡ validbet 恒等检验 · 四象限全表（★ 一级施工项之核心）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41_identity_global.csv」。
--   ★ 四象限（此即 P11c #4 之完整业务命题，canonical 内一格不落地缺失）：
--       bet41 空 ∧ validbet 空       → n_both_null
--       bet41 空 ⊕ validbet 空       → n_null_asym  （非对称，最危险之一态）
--       二者皆非空 ∧ 值相等          → n_exact_equal
--       二者皆非空 ∧ 值不等          → n_value_diff
--   ★ 并出差值分布（min／p01／p05／p50／p95／p99／max、绝对差之和与最大）。
--   ★ 判读（三态，禁跳过 CONDITIONAL 直取 IDENTICAL）：
--     n_null_asym = 0 ∧ n_value_diff = 0        → IDENTICAL（本窗口内）
--     n_value_diff > 0 而 max_abs_diff 极小      → CONDITIONAL（浮点或量纲差）
--     n_null_asym > 0                           → NOT_IDENTICAL（空值语义不同）
--   ★ 措辞锁：纵得 IDENTICAL，亦只得书「**本窗口、本产品下二列取值相同**」，
--     **禁写「bet41 就是 validbet」**——那是设计断言，本检验证不到。
-- ──────────────────────────────────────────────────────────────────────────
WITH vb AS (                                                                                        -- 公共表表达式：开启中间结果集 vb——两列并置与差值
  SELECT CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8))               AS v41,                    -- 取列：bet41 转数值
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))               AS vvb,                    -- 取列：validbet 转数值
         CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8))
           - CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))           AS d                       -- 取值表达式：★ 差值 D ＝ bet41 − validbet
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'bet41 ≡ validbet（全窗 · 百家乐）'                                    AS test,                   -- 字面取值：受检命题
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  SUM(CASE WHEN v41 IS NULL AND vvb IS NULL THEN 1 ELSE 0 END)           AS n_both_null,            -- 条件计数：★ 象限一——二者皆空
  SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END)        AS n_null_asym,            -- 条件计数：★★ 象限二——空值非对称，最危险
  SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 = vvb THEN 1 ELSE 0 END) AS n_exact_equal, -- 条件计数：★ 象限三——皆非空且相等
  SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) AS n_value_diff, -- 条件计数：★ 象限四——皆非空而不等
  ROUND(SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 = vvb THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL THEN 1 ELSE 0 END), 0), 8) AS pct_exact_equal, -- 比率表达式：★★ 皆非空者中之相等率
  ROUND(MAX(ABS(d)), 8)                                                  AS max_abs_diff,           -- 聚合取值：★ 最大绝对差——判是否仅浮点误差
  ROUND(SUM(ABS(d)), 8)                                                  AS sum_abs_diff,           -- 汇总表达式：绝对差之和
  ROUND(MIN(d), 8)                                                       AS d_min,                  -- 聚合取值：差值下界
  ROUND(PERCENTILE_APPROX(d, 0.01), 8)                                   AS d_p01,                  -- 取近似分位数表达式：差值 1 分位
  ROUND(PERCENTILE_APPROX(d, 0.05), 8)                                   AS d_p05,                  -- 取近似分位数表达式：差值 5 分位
  ROUND(PERCENTILE_APPROX(d, 0.50), 8)                                   AS d_p50,                  -- 取近似分位数表达式：差值中位
  ROUND(PERCENTILE_APPROX(d, 0.95), 8)                                   AS d_p95,                  -- 取近似分位数表达式：差值 95 分位
  ROUND(PERCENTILE_APPROX(d, 0.99), 8)                                   AS d_p99,                  -- 取近似分位数表达式：差值 99 分位
  ROUND(MAX(d), 8)                                                       AS d_max,                  -- 聚合取值：差值上界
  CASE                                                                                              -- 条件分支：起始分支——恒等裁定（三态）
    WHEN SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END) > 0
      THEN '❌ NOT_IDENTICAL —— 空值语义不同（非对称空），二列不可互代'                                 -- 分支判定：空值非对称
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) > 0
      THEN '◐ CONDITIONAL —— 存在数值差异，须并读 max_abs_diff 判其系浮点抑或量纲之别'                 -- 分支判定：有数值差
    ELSE '✅ IDENTICAL（★ 措辞锁：只得书「本窗口本产品下二列取值相同」，禁书「bet41 就是 validbet」）'     -- 分支判定：本窗口相同
  END                                                                    AS verdict_identity        -- 条件分支：收束上方判词，产出「verdict_identity」
FROM vb;                                                                                            -- 取数来源：取自本条自建的中间结果集 vb


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41b · 恒等检验之四维分层（★ 全局相同 ≠ 逐层相同）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41b_identity_strata.csv」。
--   ★ 缘由：全局 D = 0 可由「多数组皆同、少数组互相抵销」造成。
--     须按 bet09（注型）× commission（佣金制）分层复验，方排除抵销之可能。
--   ★ 判读：任一层 n_value_diff 或 n_null_asym > 0，即全局之 IDENTICAL 不成立。
--   ★ 只列有差异之层 ＋ 前若干大层，免全量输出。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(bet09)                                                            AS bet09_value,            -- 取列：注型组
  TRIM(commission)                                                       AS commission_value,       -- 取列：佣金标记
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该层行数
  SUM(CASE WHEN NULLIF(TRIM(bet41), '') IS NULL
             AND NULLIF(TRIM(validbet), '') IS NULL THEN 1 ELSE 0 END)   AS n_both_null,            -- 条件计数：象限一
  SUM(CASE WHEN (NULLIF(TRIM(bet41), '') IS NULL)
            <> (NULLIF(TRIM(validbet), '') IS NULL) THEN 1 ELSE 0 END)   AS n_null_asym,            -- 条件计数：★ 象限二
  SUM(CASE WHEN NULLIF(TRIM(bet41), '') IS NOT NULL
             AND NULLIF(TRIM(validbet), '') IS NOT NULL
             AND CAST(TRIM(bet41) AS DECIMAL(20,8))
               <> CAST(TRIM(validbet) AS DECIMAL(20,8)) THEN 1 ELSE 0 END) AS n_value_diff,         -- 条件计数：★ 象限四
  ROUND(MAX(ABS(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))
                - CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)))), 8) AS max_abs_diff,          -- 聚合取值：该层最大绝对差
  ROUND(SUM(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))), 2)          AS b41_sum,                -- 汇总表达式：该层 bet41 总额
  ROUND(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 2)       AS vb_sum,                 -- 汇总表达式：该层 validbet 总额
  CASE                                                                                              -- 条件分支：起始分支——逐层裁定
    WHEN SUM(CASE WHEN (NULLIF(TRIM(bet41), '') IS NULL)
                   <> (NULLIF(TRIM(validbet), '') IS NULL) THEN 1 ELSE 0 END) > 0
      THEN '❌ 本层空值非对称'                                                                       -- 分支判定：空值非对称
    WHEN SUM(CASE WHEN NULLIF(TRIM(bet41), '') IS NOT NULL
                    AND NULLIF(TRIM(validbet), '') IS NOT NULL
                    AND CAST(TRIM(bet41) AS DECIMAL(20,8))
                      <> CAST(TRIM(validbet) AS DECIMAL(20,8)) THEN 1 ELSE 0 END) > 0
      THEN '◐ 本层有数值差'                                                                         -- 分支判定：有数值差
    ELSE '✅ 本层相同'                                                                              -- 分支判定：本层相同
  END                                                                    AS verdict_stratum         -- 条件分支：收束上方判词，产出「verdict_stratum」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
GROUP BY TRIM(bet09), TRIM(commission)                                                              -- 分组：按注型与佣金制分层
ORDER BY n_null_asym DESC, n_value_diff DESC, n_rows DESC;                                          -- 排序：有差异者置顶；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之五条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁十三 · 契约与恒等，二事不可互证。
--   §VB-00 答「该用哪一列」，§VB-41 答「二列是否同一量」。
--   纵然 bet41 ≡ validbet 成立，仍须立唯一契约——因下游若各取一列，
--   换窗后二者一旦分歧，分析结果即静默分裂而无人察觉。
--
-- 锁十四 · 数据条件等价 ≠ 设计等价（承 B-11）。
--   当前窗口 null_rate 若为 0，COALESCE 与直取二式结果相同，
--   **此系数据碰巧如此，非二式定义相同**。换窗、换产品、换库须重验。
--
-- 锁十五 · 全局恒等 ≠ 逐层恒等。
--   全局 D = 0 可由组间抵销造成。§VB-41b 之分层复验为必要条件，非锦上添花。
--
-- 锁十六 · 空值非对称最危险。
--   n_null_asym > 0 意味二列之**空值语义不同**——一列以 NULL 表「无」，
--   另一列以 0 表「无」。此类差异在 SUM 中被静默吞掉，只在分母处爆发。
--
-- 锁十七 · 措辞锁。
--   纵得 IDENTICAL，只得书「本窗口、本产品下二列取值相同」；
--   **禁书「bet41 就是 validbet」**——后者系设计断言，本检验证不到。
--
-- ★ 本件之产出，系 v11.0.4 §VB-00／§VB-41 施工设计之实证底料。
--   施工后须以 R4S03 回归复验：四象限 FORMULA 锚须至少一枚可识别，
--   届时三档 v10 补丁方得转 ARCHIVABLE。
--   **能力进 Canonical，验证留 Regression；补丁只作证据，不作真相源。**
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
