-- ══════════════════════════════════════════════════════════════════════════
-- §VB-41b · bet41 ≡ validbet 分层恒等检验  审计工具 v1.0.1（十三列版）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.0 → v1.0.1 · 输出规格补完，皆我方缺陷】
--   SC-1（REDTEAM 所指）：v1.0.0 之 §VB-41b 只出 max_abs_diff，
--     **缺 pct_value_diff／d_min／d_max／sum_abs_diff 四列**。
--     致「单向性是否逐层成立」无从复验——全局虽观察到 d_max = 0（差值恒非正），
--     惟该性质是否逐层皆成立，v1.0.0 之输出答不了。
--     → §VB-41b 判 **INSUFFICIENT**（非 PASS／CONDITIONAL／FAIL 之任一），
--       因输出规格不足以支撑任何裁定。今补。
--   SC-2（我方新发现 · 判词失辨）：v1.0.0 之「✅ 本层相同」
--     **无法区分「有值相同」与「零对零相同」**。
--     实测原档可见：Tip_1_／Player,comm=2／Player,comm=-1 等层
--     b41_sum ＝ vb_sum ＝ 0，判「相同」字面不错，
--     业务上却系「该层根本无洗码量可比」。
--     ★ 零对零之相同，与四千万笔有值之相同，不该共用同一判词。今分离。
--   SC-3（我方新发现 · 原档已见其形）：数层现 b41_sum = 0 而 vb_sum > 0
--     （Banker,comm=2／-1／999／100 与 SuperTie9 等）——
--     **非「差一点」，系「一边全零」**。今立专列 n_b41_zero_vb_pos 计之。
--
-- 【本件十三列 · 十列承 REDTEAM 所定 ＋ 三列我方新增】
--   承定十列：bet09 · commission · n_rows · n_value_diff · pct_value_diff
--             n_null_asym · d_min · d_max · max_abs_diff · sum_abs_diff
--   新增三列：n_both_zero        —— 分离零对零之「相同」
--             n_b41_zero_vb_pos —— bet41 全零而 validbet 非零者
--             d_sign_uniform    —— 该层差值是否单向（承全局 d_max = 0 之观察）
--   另留三列：n_both_null · b41_sum · vb_sum（v1.0.0 已有，不删——禁退化）
--
-- 【全局已 OBSERVED 者（§VB-41 · 不受本件影响）】
--   n_both_null 0 ／ n_null_asym 0 ／ n_exact_equal 125,653,747 ／
--   n_value_diff 964 ／ pct_exact_equal 99.99923280% ／
--   max_abs_diff 1,000,000 ／ sum_abs_diff 2,242,708 ／
--   d_min −1,000,000 ／ d_max 0
--   ★ d_max = 0 意味 bet41 ≤ validbet 于全局恒成立 —— 本件验其是否逐层亦然。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF；
--   CTE 名避保留字。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41b · 分层恒等检验（十三列 · 逐层复验单向性与零值形态）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41b_identity_strata_v2.csv」。
--   ★ 判读五态（较 v1.0.0 之二态为细）：
--     n_null_asym > 0                          → ❌ 空值语义不同，二列不可互代
--     n_value_diff > 0 ∧ d_max > 0             → ❌ 单向性破裂（出现 bet41 > validbet）
--     n_value_diff > 0 ∧ d_max ≤ 0             → ◐ 单向差异（bet41 ≤ validbet）
--     n_value_diff = 0 ∧ n_both_zero = n_rows  → ⊘ 零对零——本层无可比之量
--     n_value_diff = 0 ∧ 有正值                 → ✅ 有值相同
--   ★ 分层合计须与 §VB-41 之全局 964 精确对账；不对账即本件或全局条有误。
-- ──────────────────────────────────────────────────────────────────────────
WITH src AS (                                                                                       -- 公共表表达式：开启中间结果集 src——逐行取二列与差值
  SELECT TRIM(bet09)                                                     AS g,                      -- 取列：注型组
         TRIM(commission)                                                AS comm,                   -- 取列：佣金标记
         CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8))               AS v41,                    -- 取列：bet41 转数值
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))               AS vvb,                    -- 取列：validbet 转数值
         CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8))
           - CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))           AS d                       -- 取值表达式：差值 D ＝ bet41 − validbet
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  g                                                                      AS bet09,                  -- 取列：★ 承定第一列——注型
  comm                                                                   AS commission,             -- 取列：★ 承定第二列——佣金制
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：★ 承定第三列——该层行数
  SUM(CASE WHEN v41 IS NULL AND vvb IS NULL THEN 1 ELSE 0 END)           AS n_both_null,            -- 条件计数：二者皆空（v1.0.0 已有，留）
  SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END)        AS n_null_asym,            -- 条件计数：★ 承定第六列——空值非对称
  SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) AS n_value_diff, -- 条件计数：★ 承定第四列——数值不等
  ROUND(SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 8)                                        AS pct_value_diff,         -- 比率表达式：★ 承定第五列——差异占该层之比
  ROUND(MIN(d), 8)                                                       AS d_min,                  -- 聚合取值：★ 承定第七列——差值下界
  ROUND(MAX(d), 8)                                                       AS d_max,                  -- 聚合取值：★★ 承定第八列——差值上界，单向性之判据
  ROUND(MAX(ABS(d)), 8)                                                  AS max_abs_diff,           -- 聚合取值：★ 承定第九列——最大绝对差
  ROUND(SUM(ABS(d)), 8)                                                  AS sum_abs_diff,           -- 汇总表达式：★ 承定第十列——绝对差之和
  SUM(CASE WHEN v41 = 0 AND vvb = 0 THEN 1 ELSE 0 END)                   AS n_both_zero,            -- 条件计数：★★ 新增——零对零，分离「无可比之量」
  SUM(CASE WHEN v41 = 0 AND vvb > 0 THEN 1 ELSE 0 END)                   AS n_b41_zero_vb_pos,      -- 条件计数：★★ 新增——bet41 全零而 validbet 非零
  CASE                                                                                              -- 条件分支：起始分支——★★ 新增：单向性判定
    WHEN MAX(d) IS NULL                          THEN 'NO_DATA'                                     -- 分支判定：无可比之行
    WHEN MAX(d) <= 0 AND MIN(d) < 0              THEN 'UNIFORM_NEG（bet41 ≤ validbet 恒成立）'        -- 分支判定：单向为负
    WHEN MAX(d) = 0 AND MIN(d) = 0               THEN 'ALL_ZERO_DIFF（差值恒零）'                     -- 分支判定：差值恒零
    WHEN MIN(d) >= 0 AND MAX(d) > 0              THEN '★ UNIFORM_POS（bet41 ≥ validbet）—— 与全局反向，须追'  -- 分支判定：单向为正
    ELSE '★★ MIXED_SIGN（双向差异）—— 单向性破裂，须追成因'                                            -- 分支判定：双向
  END                                                                    AS d_sign_uniform,         -- 条件分支：收束上方判词，产出「d_sign_uniform」
  ROUND(SUM(v41), 2)                                                     AS b41_sum,                -- 汇总表达式：该层 bet41 总额（v1.0.0 已有，留）
  ROUND(SUM(vvb), 2)                                                     AS vb_sum,                 -- 汇总表达式：该层 validbet 总额（v1.0.0 已有，留）
  CASE                                                                                              -- 条件分支：起始分支——★ 五态裁定（v1.0.0 仅二态）
    WHEN SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END) > 0
      THEN '❌ 空值语义不同——二列不可互代'                                                            -- 分支判定：空值非对称
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) > 0
     AND MAX(d) > 0
      THEN '❌ 单向性破裂——本层出现 bet41 > validbet，与全局 d_max = 0 相悖'                           -- 分支判定：单向破裂
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) > 0
      THEN '◐ 单向差异（bet41 ≤ validbet）——须逐笔追成因'                                             -- 分支判定：单向差异
    WHEN SUM(CASE WHEN v41 = 0 AND vvb = 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '⊘ 零对零——本层二列皆恒为零，**无可比之量**，非「有值相同」'                                  -- 分支判定：★ 新增——零对零
    ELSE '✅ 有值相同'                                                                              -- 分支判定：有值相同
  END                                                                    AS verdict_stratum         -- 条件分支：收束上方判词，产出「verdict_stratum」
FROM src                                                                                            -- 取数来源：取自本条自建的中间结果集 src
GROUP BY g, comm                                                                                    -- 分组：按注型与佣金制分层
ORDER BY n_null_asym DESC, n_value_diff DESC, n_rows DESC, bet09, commission;                       -- 排序：异常者置顶；导出必带确定性排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之四条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁十八 · 输出规格不足者，判 INSUFFICIENT，不判 PASS／FAIL。
--   v1.0.0 缺 d_min／d_max，故「单向性是否逐层成立」根本答不了。
--   ★ 此时任何裁定皆属越权——**工具答不了的问题，不得由判词代答。**
--
-- 锁十九 · 零对零之「相同」，非「有值相同」。
--   b41_sum ＝ vb_sum ＝ 0 之层，二列皆恒为零，本层**无可比之量**。
--   与四千万笔有值之相同共用一个 ✅，即以形式之同掩盖实质之空。
--
-- 锁二十 · 单向性须逐层复验，不得由全局推定。
--   全局 d_max = 0 只证「不存在任何一笔 bet41 > validbet」——此结论确实可下推。
--   惟 d_min 之分布、差异之集中度、是否某层双向，皆须逐层方见。
--   ★ 全局单向 → 逐层必单向（数学上成立）；
--     惟「逐层皆单向」不等于「逐层差异同源」——成因仍须逐层追。
--
-- 锁二十一 · 禁退化。
--   v1.0.1 保留 v1.0.0 全部三列（n_both_null／b41_sum／vb_sum），只增不减。
--   ★ 工具升级不得以「精简」为名删去既有输出——旧读数将因此不可复现。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
