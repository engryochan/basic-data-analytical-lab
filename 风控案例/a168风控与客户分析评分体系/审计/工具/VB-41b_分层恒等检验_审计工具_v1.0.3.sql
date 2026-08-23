-- ══════════════════════════════════════════════════════════════════════════
-- §VB-41b · bet41 ≡ validbet 分层恒等检验  审计工具 v1.0.3（★ 六态穷尽版）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.2 → v1.0.3 · 一项斧正，系我方判词空间不完整】
--   SC-7：v1.0.2 之 d_sign_uniform 四态**未穷尽 (d_min, d_max) 之合法组合**。
--     实测七层 d_min ＝ d_max ＝ −10（同为负且非零），落在四态之外，
--     遂入 UNCLASSIFIED 兜底。★ 幸有兜底，未静默误判——惟兜底非设计。
--   ★ 裁示所定之更高要求（我原拟只补两态，仍属打补丁，方向不足）：
--     **本版之目的不是把七层改名，而是证明判词空间已完整覆盖。**
--     故加**穷举锁**：跑毕 UNCLASSIFIED 须 ＝ 0；非零即判词空间仍有缺口。
--
-- 【六态互斥穷尽 · (d_min, d_max) 之全域划分】
--   设 a ＝ d_min、b ＝ d_max，恒有 a ≤ b。全域按符号与是否相等划分：
--     a = 0, b = 0                 → NO_DIFFERENCE          差值恒零
--     a < 0, b = 0, a < b          → B41_LE_VB_UNIFORM      有零有负
--     a < 0, b < 0, a = b          → B41_LE_VB_CONSTANT     恒定负差 ★ 本版新增
--     a = 0, b > 0                 → B41_GE_VB_UNIFORM      有零有正
--     a > 0, b > 0, a = b          → B41_GE_VB_CONSTANT     恒定正差 ★ 本版新增
--     a < 0, b > 0                 → BIDIRECTIONAL          双向
--   ★ 余下未列之组合（如 a<0,b<0,a<b 或 a>0,b>0,a<b）属「同号而不等」，
--     v1.0.2 亦未覆盖。本版以 UNIFORM 二态含之——理由见锁二十五。
--
-- 【承 v1.0.2 之七项硬校验（已全过，本版须复现）】
--   Σ n_rows 125,654,711 ／ Σ n_value_diff 964 ／ Σ n_both_null 0 ／
--   Σ n_null_asym 0 ／ Σ sum_abs_diff 2,242,708 ／
--   MIN(d_min) −1,000,000 ／ MAX(d_max) 0
--   ★ 另加第八项：Σ(d_sign_uniform = 'UNCLASSIFIED') ＝ 0
--
-- 【十八列 schema 不变，禁重排】——承 v1.0.2 之冻结，只改第 15 列之判词逻辑。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41b · 分层恒等检验（十八列 · 六态穷尽 · UNCLASSIFIED 须为零）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41b_identity_strata_v18b.csv」。
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
  g                                                                      AS bet09_value,            -- 取列：〔01〕注型
  comm                                                                   AS commission_value,       -- 取列：〔02〕佣金制
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：〔03〕该层行数
  SUM(CASE WHEN v41 IS NULL AND vvb IS NULL THEN 1 ELSE 0 END)           AS n_both_null,            -- 条件计数：〔04〕二者皆空
  SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END)        AS n_null_asym,            -- 条件计数：〔05〕空值非对称
  SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) AS n_value_diff, -- 条件计数：〔06〕数值不等
  ROUND(SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 8)                                        AS pct_value_diff,         -- 比率表达式：〔07〕差异占该层之比
  ROUND(MAX(ABS(d)), 8)                                                  AS max_abs_diff,           -- 聚合取值：〔08〕最大绝对差
  ROUND(MIN(d), 8)                                                       AS d_min,                  -- 聚合取值：〔09〕差值下界
  ROUND(MAX(d), 8)                                                       AS d_max,                  -- 聚合取值：〔10〕差值上界
  ROUND(SUM(ABS(d)), 8)                                                  AS sum_abs_diff,           -- 汇总表达式：〔11〕绝对差之和
  SUM(CASE WHEN v41 = 0 AND vvb = 0 THEN 1 ELSE 0 END)                   AS n_both_zero,            -- 条件计数：〔12〕零对零
  SUM(CASE WHEN v41 = 0 AND vvb > 0 THEN 1 ELSE 0 END)                   AS n_b41_zero_vb_pos,      -- 条件计数：〔13〕bet41 零而 validbet 正
  SUM(CASE WHEN v41 > 0 AND vvb = 0 THEN 1 ELSE 0 END)                   AS n_b41_pos_vb_zero,      -- 条件计数：〔14〕反向
  CASE                                                                                              -- 条件分支：〔15〕起始分支——★ 六态穷尽（本版之核心）
    WHEN MIN(d) IS NULL OR MAX(d) IS NULL                       THEN 'NO_DATA'                      -- 分支判定：该层无可比之行
    WHEN MIN(d) = 0 AND MAX(d) = 0                              THEN 'NO_DIFFERENCE'                -- 分支判定：a=0 ∧ b=0——差值恒零
    WHEN MIN(d) < 0 AND MAX(d) < 0 AND MIN(d) = MAX(d)          THEN 'B41_LE_VB_CONSTANT'           -- 分支判定：★ a=b<0——恒定负差
    WHEN MIN(d) > 0 AND MAX(d) > 0 AND MIN(d) = MAX(d)          THEN 'B41_GE_VB_CONSTANT'           -- 分支判定：★ a=b>0——恒定正差
    WHEN MIN(d) < 0 AND MAX(d) <= 0                             THEN 'B41_LE_VB_UNIFORM'            -- 分支判定：a<0 ∧ b≤0——单向非正
    WHEN MIN(d) >= 0 AND MAX(d) > 0                             THEN 'B41_GE_VB_UNIFORM'            -- 分支判定：a≥0 ∧ b>0——单向非负
    WHEN MIN(d) < 0 AND MAX(d) > 0                              THEN 'BIDIRECTIONAL'                -- 分支判定：a<0 ∧ b>0——双向
    ELSE 'UNCLASSIFIED'                                                                             -- 分支判定：★★ 穷举锁——跑毕须为 0，非零即判词空间仍有缺口
  END                                                                    AS d_sign_uniform,         -- 条件分支：收束上方判词，产出「d_sign_uniform」
  ROUND(SUM(v41), 2)                                                     AS b41_sum,                -- 汇总表达式：〔16〕该层 bet41 总额
  ROUND(SUM(vvb), 2)                                                     AS vb_sum,                 -- 汇总表达式：〔17〕该层 validbet 总额
  CASE                                                                                              -- 条件分支：〔18〕起始分支——五态裁定（承 v1.0.2，不改）
    WHEN SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END) > 0
      THEN 'FAIL'                                                                                   -- 分支判定：空值语义不同
    WHEN COUNT(*) = SUM(CASE WHEN v41 = 0 AND vvb = 0 THEN 1 ELSE 0 END)
      THEN 'NO_COMPARABLE_VALUE'                                                                    -- 分支判定：二列皆恒为零，无可比之量
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) = 0
     AND (SUM(v41) > 0 OR SUM(vvb) > 0)
      THEN 'IDENTICAL_NONZERO'                                                                      -- 分支判定：无差异且有正值
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) = 0
     AND COALESCE(SUM(v41), 0) = 0 AND COALESCE(SUM(vvb), 0) = 0
      THEN 'IDENTICAL_ZERO_ONLY'                                                                    -- 分支判定：无差异惟总额皆零
    ELSE 'CONDITIONAL'                                                                              -- 分支判定：有数值差异
  END                                                                    AS verdict_stratum         -- 条件分支：收束上方判词，产出「verdict_stratum」
FROM src                                                                                            -- 取数来源：取自本条自建的中间结果集 src
GROUP BY g, comm                                                                                    -- 分组：按注型与佣金制分层
ORDER BY n_null_asym DESC, n_value_diff DESC, n_rows DESC, bet09_value, commission_value;           -- 排序：异常者置顶；导出必带确定性排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之二条新锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁二十五 · 判词空间须证其穷尽，非逐案补丁。
--   我原拟「补两态」仍属打补丁；裁示所定方为正——
--   **目的不是把七层改名，而是证明判词空间已覆盖 (d_min, d_max) 之全域。**
--   ★ 故立穷举锁：UNCLASSIFIED 须恒为 0。非零即判词空间仍有缺口，
--     须先补齐再论数据，**不得以「兜底已接住」为由放行**。
--   ⚠ 一处诚实交代：本版以 B41_LE_VB_UNIFORM 含「a<0 ∧ b<0 ∧ a<b」之情形
--     （同为负而不相等）。严格论之，该情形与「有零有负」在业务上或有别，
--     惟二者皆满足 bet41 ≤ validbet 恒成立，故归一态。
--     **若日后须细分，须另立态而非改判现有态。**
--
-- 锁二十六 · 模式相同 ≠ 血统相同（承裁示第五节，照录）。
--   七个上线测试层（Bear8／Lucky7TwoCard／SmallTiger／SuperTie4/5/8/9）
--   各 n_rows = 1、bet41 = 0、validbet = 10，其**数学形态与 964 笔完全一致**。
--   ★ 惟只得书「二者具有相同之字段表现模式」，
--     **禁书「二者确定同源」**——时间相邻 ≠ 来源关系。
--   → 证据须拆两群：A 主群 964 笔结构性差异 ／ B 七笔上线测试型观察。
--
-- ★ 八项硬校验（第八项为本版新增）：
--     Σ n_rows 125,654,711 ／ Σ n_value_diff 964 ／ Σ n_both_null 0 ／
--     Σ n_null_asym 0 ／ Σ sum_abs_diff 2,242,708 ／
--     MIN(d_min) −1,000,000 ／ MAX(d_max) 0 ／
--     ★★ COUNT(d_sign_uniform = 'UNCLASSIFIED') ＝ 0
--
-- ★ 措辞锁（承裁示第四节）：可登记者为
--   「964 笔非一致记录，100% 属 bet41 = 0 ∧ validbet > 0，
--     不存在反向；全局与 51 层于行数、差异数、差额绝对值、极值、
--     空值语义五项皆对账」——此系 **OBSERVED**。
--   **禁登记「964 笔是系统漏记」**——成因仍属 UNKNOWN，跨级即越权。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
