-- ══════════════════════════════════════════════════════════════════════════
-- §VB-41b · bet41 ≡ validbet 分层恒等检验  审计工具 v1.0.2（★ 十八列冻结版）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.1 → v1.0.2 · 三项斧正，皆我方缺陷】
--   SC-4（★ 我方自纠 · 口称与实作不符）：v1.0.1 我口称「十三列版」，
--     而所交之档实际输出 **16 列**。**口称与实作不符，本身即锁十二之实例**
--     （注释声明 ≠ 代码实现）。裁示所算方为正：
--     现有 10 ＋ 缺失 4 ＋ 新增 3 ＝ **17**，再加 n_b41_pos_vb_zero ＝ **18**。
--   SC-5（裁示所加 · 最要紧之一列）：新增 **n_b41_pos_vb_zero**
--     （bet41 > 0 ∧ validbet = 0）。缘由：
--       A 类  bet41 = 990、validbet = 1000  → **数值修正**
--       B 类  bet41 =   0、validbet = 1000  → **结构性缺失**
--     二者皆满足 bet41 < validbet，惟对洗码、VIP 分层、ROI 分母之意义迥异。
--     ★ 而反向（bet41 > 0 ∧ validbet = 0）若亦存在，业务含义又自不同——
--       故须双向皆计，不可只计已观察到之一向。
--   SC-6（判词分两轴）：v1.0.1 令 verdict 兼管「相同与否」与「方向」，
--     致方向性直接介入业务裁定。今分离：
--       verdict_stratum   五态 —— 答「可比与否、是否相同」
--       d_sign_uniform    四态 —— 答「差异之方向」，**独立诊断，不裁业务**
--   ★ min_abs_diff 依裁示**不加**——其与 d_min／d_max 信息重叠。
--
-- 【十八列 canonical schema · 顺序冻结，禁重排】
--    1 bet09_value          2 commission_value    3 n_rows
--    4 n_both_null          5 n_null_asym         6 n_value_diff
--    7 pct_value_diff       8 max_abs_diff        9 d_min
--   10 d_max               11 sum_abs_diff       12 n_both_zero
--   13 n_b41_zero_vb_pos   14 n_b41_pos_vb_zero  15 d_sign_uniform
--   16 b41_sum             17 vb_sum             18 verdict_stratum
--   ★ 顺序固定，令后续审计工具可按 canonical schema 稳定比对。
--
-- 【七项硬校验 · 跑毕须逐条对账（承裁示第七节）】
--   Σ n_rows        = 125,654,711        Σ n_value_diff  = 964
--   Σ n_both_null   = 0                  Σ n_null_asym   = 0
--   Σ sum_abs_diff  = 2,242,708          MIN(d_min)      = −1,000,000
--   MAX(d_max)      = 0
--   ★ 七条全过，方许把分层结论写入 registry。任一不对账即本件或全局条有误。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41b · 分层恒等检验（十八列冻结版）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41b_identity_strata_v18.csv」。
--   ★ verdict_stratum 五态（答「可比与否、是否相同」）：
--     NO_COMPARABLE_VALUE   本层二列皆恒为零 —— **无可比之量**
--     IDENTICAL_NONZERO     无差异且有正值 —— 真正之「相同」
--     IDENTICAL_ZERO_ONLY   无差异惟总额皆零 —— 形式相同、实质为空
--     CONDITIONAL           有数值差异
--     FAIL                  空值语义不同 —— 二列不可互代
--   ★ d_sign_uniform 四态（**独立诊断，不裁业务**）：
--     NO_DIFFERENCE ／ B41_LE_VB_UNIFORM ／ B41_GE_VB_UNIFORM ／ BIDIRECTIONAL
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
  SUM(CASE WHEN v41 = 0 AND vvb > 0 THEN 1 ELSE 0 END)                   AS n_b41_zero_vb_pos,      -- 条件计数：〔13〕★ bet41 零而 validbet 正——结构性缺失
  SUM(CASE WHEN v41 > 0 AND vvb = 0 THEN 1 ELSE 0 END)                   AS n_b41_pos_vb_zero,      -- 条件计数：〔14〕★★ 反向——bet41 正而 validbet 零
  CASE                                                                                              -- 条件分支：〔15〕起始分支——方向性诊断（独立，不裁业务）
    WHEN MIN(d) IS NULL OR MAX(d) IS NULL        THEN 'NO_DATA'                                     -- 分支判定：无可比之行
    WHEN MIN(d) = 0 AND MAX(d) = 0               THEN 'NO_DIFFERENCE'                               -- 分支判定：差值恒零
    WHEN MAX(d) = 0 AND MIN(d) < 0               THEN 'B41_LE_VB_UNIFORM'                           -- 分支判定：单向——bet41 ≤ validbet
    WHEN MIN(d) = 0 AND MAX(d) > 0               THEN 'B41_GE_VB_UNIFORM'                           -- 分支判定：单向——bet41 ≥ validbet
    WHEN MIN(d) < 0 AND MAX(d) > 0               THEN 'BIDIRECTIONAL'                               -- 分支判定：双向
    ELSE 'UNCLASSIFIED'                                                                             -- 分支判定：未归类，须人查
  END                                                                    AS d_sign_uniform,         -- 条件分支：收束上方判词，产出「d_sign_uniform」
  ROUND(SUM(v41), 2)                                                     AS b41_sum,                -- 汇总表达式：〔16〕该层 bet41 总额
  ROUND(SUM(vvb), 2)                                                     AS vb_sum,                 -- 汇总表达式：〔17〕该层 validbet 总额
  CASE                                                                                              -- 条件分支：〔18〕起始分支——五态裁定（承裁示第三节之逻辑）
    WHEN SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END) > 0
      THEN 'FAIL'                                                                                   -- 分支判定：空值语义不同——二列不可互代
    WHEN COUNT(*) = SUM(CASE WHEN v41 = 0 AND vvb = 0 THEN 1 ELSE 0 END)
      THEN 'NO_COMPARABLE_VALUE'                                                                    -- 分支判定：★ 本层二列皆恒为零，无可比之量
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) = 0
     AND (SUM(v41) > 0 OR SUM(vvb) > 0)
      THEN 'IDENTICAL_NONZERO'                                                                      -- 分支判定：无差异且有正值——真正之相同
    WHEN SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb THEN 1 ELSE 0 END) = 0
     AND COALESCE(SUM(v41), 0) = 0 AND COALESCE(SUM(vvb), 0) = 0
      THEN 'IDENTICAL_ZERO_ONLY'                                                                    -- 分支判定：★ 无差异惟总额皆零——形式相同、实质为空
    ELSE 'CONDITIONAL'                                                                              -- 分支判定：有数值差异
  END                                                                    AS verdict_stratum         -- 条件分支：收束上方判词，产出「verdict_stratum」
FROM src                                                                                            -- 取数来源：取自本条自建的中间结果集 src
GROUP BY g, comm                                                                                    -- 分组：按注型与佣金制分层
ORDER BY n_null_asym DESC, n_value_diff DESC, n_rows DESC, bet09_value, commission_value;           -- 排序：异常者置顶；导出必带确定性排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之三条新锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁二十二 · 单向差异须再拆「数值修正」与「结构性缺失」（承裁示第四节）。
--     bet41 = 990、validbet = 1000  → 数值修正，二列量纲同而值微异
--     bet41 =   0、validbet = 1000  → 结构性缺失，bet41 侧根本未记
--   二者皆满足 bet41 < validbet，惟对洗码量、VIP 分层、ROI 分母之意义迥异。
--   ★ n_value_diff 一列远远不够 —— 须以 n_b41_zero_vb_pos 与
--     n_b41_pos_vb_zero 双向拆之。
--
-- 锁二十三 · 方向性不裁业务。
--   d_sign_uniform 系**独立诊断轴**，答「差异往哪个方向」；
--   verdict_stratum 答「可比与否、是否相同」。二者分列，禁令方向直接决定裁定。
--   ★ 缘由：单向性纵然成立，亦不证其成因无害——单向可源于系统性规则，
--     亦可源于系统性错误。方向只是线索，非结论。
--
-- 锁二十四 · 口称之规格须与实作逐列核对。
--   v1.0.1 我口称「十三列」而实作 16 列 —— 口称与实作不符，
--   系锁十二（注释声明 ≠ 代码实现）之又一实例，且发生在我自己身上。
--   ★ 凡宣称列数、行数、语句数者，须以机器点数为准，禁凭记忆。
--
-- ★ 跑毕之七项硬校验（任一不过即不得写入 registry）：
--     Σ n_rows 125,654,711 ／ Σ n_value_diff 964 ／ Σ n_both_null 0 ／
--     Σ n_null_asym 0 ／ Σ sum_abs_diff 2,242,708 ／
--     MIN(d_min) −1,000,000 ／ MAX(d_max) 0
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
