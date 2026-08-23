-- ══════════════════════════════════════════════════════════════════════════
-- B-4 · μ0 分层现算 · 审计工具 v1.0.2（★ P0 全修版 · 零占位符）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.1 → v1.0.2 · 五项 P0 全修，皆我方缺陷】
--   P0-1（执行阻断）：CTE 名 glob 系 StarRocks 保留字（GLOB 运算符），
--     解析器直接拒收「Unable to parse SQL near 'glob' at line 46」。
--     今改 global_mu0，别名 gm。**纯语法热修，不动 μ0 公式、不动过滤、不动血统。**
--   P0-2（★ 循环论证 · 本版最重之改）：撤回「Tip_1_ 系小费」之判，
--     并**自过滤器中移除该排除**。
--     实测反证：n_bet13_pos = 5,564 / 5,564 ＝ 100%，bet13_sum = 472,187.4。
--     原判之「证据」实为误读——我以「§M0-1 未见 Tip_1_，因 bet13 > 0 滤掉了」
--     为据，而那恰恰证明它**有**正本金。因果读反。
--     ★ 立锁：**业务规则不得先写进过滤器，再用过滤后之数据证明该规则。**
--       假设 → 验证 → 裁定 → 方得成 GATE。次序颠倒即循环论证。
--     Tip_1_ 现判 UNKNOWN / SPECIAL_TRANSACTION —— bet13 > 0 且 bet14 = 0
--     只证其与「本金—派彩」结构不同，可能系手续费／调账／赠送／非标结算／
--     系统内部交易。**禁自动归为 tip。**
--   P0-3：spread_ratio **降级为诊断排序器**，不得单独裁 S1。
--     缘由：min|μ0| → 0 时极差比数学爆炸，可制造假警报。
--   P0-4：near-zero 保护 —— 仅 NULLIF(x,0) 不足，增 ε 门槛与 near_zero 计数。
--   P0-5：dirty / clean 双报 —— v1.0.1 注释书「兼报两版」而实际只算洁净版，
--     属规格声明与实现不一致。今真正双报，并出逐 gate 漏斗。
--
-- 【v1.0.2 新增 P1】
--   逐 gate 漏斗计数 ／ 五级代理逐级命中率 ／ ROW_NUMBER 并列检测 ／
--   组级增报 n_members・payout・n_days ／ 名称明确 exposure_weighted。
--
-- 【与 canonical 之关系（实测查证，免重复造轮）】
--   ★ canonical §DX-04（行 5936）与 §DX-05（行 6004）**早已按 bet09 算
--     house_hold_pct**，注释明书「应接近该玩法的理论庄家优势」。
--     故 μ0 之分层能力本已在册；本工具之 §M0-1 与之重复。
--   → v11.0.4 不应新增 §M0-1，应**扩充 §DX-04**：加 commission 维度、
--     正式命名 μ0、并补 spread 诊断。此为「增强既有段」而非「另立新段」。
--
-- 口径锁、去重四道、纪律，同前版。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-2b · 逐 gate 漏斗 ＋ dirty/clean 双报 ＋ 分层诊断（★ P0 全修）
-- ▸ 导出：需要 —— 存为「审计/_b4/_B4_2b_funnel_and_mu0.csv」。
--   ★ 三段并出，一次看清：
--     ① 每道 gate 砍掉多少（污染量化，此前不可见）
--     ② dirty 与 clean 两版全局 μ0（差额即污染影响）
--     ③ 分层极差与 near-zero 计数（spread 只作排序器，不裁 S1）
--   ★ Tip_1_ **不再排除** —— 其性质未定，排除即先验假定。
-- ──────────────────────────────────────────────────────────────────────────
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta——公司测试线代理
  SELECT DISTINCT age001                                                 AS aid                     -- 取列：代理编号
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档
  WHERE age022 = '1'                                                                                -- 过滤条件：铁律④b——公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk——同注单号取最新版本
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet14, b.dt, b.commission,                  -- 取列：注单号、会员、玩法、汇率、本金、派彩、分区日、佣金标记
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category, b.bet38,                          -- 续行：五级代理、注单类别、重对标记
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：取每注单之最新版本
           PARTITION BY b.bet01                                                                     -- 窗口分区：按注单号分区
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS rn                      -- 排序：三级排序取最新
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单主表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定分析窗
    AND CAST(b.bet02 AS STRING) = '101'                                                             -- 并列条件：限定百家乐
),                                                                                                  -- 续行：收束上方的子查询或函数括号
tagged AS (                                                                                         -- 公共表表达式：开启中间结果集 tagged——逐行打 gate 标，不过滤
  SELECT r.bet01, r.bet05, TRIM(r.bet09)                                 AS g,                      -- 取列：注单号、会员、注型组
         TRIM(r.commission)                                              AS comm,                   -- 取列：佣金标记
         r.dt                                                            AS dt,                     -- 取列：分区日
         CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS stake,                  -- 取值表达式：本金口径 stake
         CAST(NULLIF(TRIM(r.bet14), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS payout,                 -- 取值表达式：派彩，同除汇率归一
         CASE WHEN r.rn = 1                            THEN 1 ELSE 0 END AS g1_latest,              -- 条件取值：gate①——最新版本
         CASE WHEN r.category = '1'                    THEN 1 ELSE 0 END AS g2_category,            -- 条件取值：gate②——一般注单
         CASE WHEN UPPER(TRIM(r.bet38)) = 'N'          THEN 1 ELSE 0 END AS g3_norebet,             -- 条件取值：gate③——非重对
         CASE WHEN t1.aid IS NULL THEN 0 ELSE 1 END                      AS lv1_hit,                -- 条件取值：★ 一级代理命中测试线
         CASE WHEN t2.aid IS NULL THEN 0 ELSE 1 END                      AS lv2_hit,                -- 条件取值：★ 二级代理命中
         CASE WHEN t3.aid IS NULL THEN 0 ELSE 1 END                      AS lv3_hit,                -- 条件取值：★ 三级代理命中
         CASE WHEN t4.aid IS NULL THEN 0 ELSE 1 END                      AS lv4_hit,                -- 条件取值：★ 四级代理命中
         CASE WHEN t5.aid IS NULL THEN 0 ELSE 1 END                      AS lv5_hit,                -- 条件取值：★ 五级代理命中
         CASE WHEN COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
              THEN 1 ELSE 0 END                                          AS g4_notest,              -- 条件取值：gate④——非测试线
         CASE WHEN CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0
              THEN 1 ELSE 0 END                                          AS g5_rate,                -- 条件取值：gate⑤——汇率为正
         CASE WHEN CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8)) > 0
              THEN 1 ELSE 0 END                                          AS g6_stake,               -- 条件取值：gate⑥——本金为正
         CASE WHEN TRIM(r.commission) IN ('0', '1')    THEN 1 ELSE 0 END AS g7_comm,                -- 条件取值：gate⑦——佣金标记非哨兵
         CASE WHEN NOT (r.dt = '2026-07-20' AND TRIM(r.bet09) IN
              ('Bear8', 'Lucky7TwoCard', 'SmallTiger', 'SuperTie4',
               'SuperTie5', 'SuperTie8', 'SuperTie9'))
              THEN 1 ELSE 0 END                                          AS g8_launch               -- 条件取值：gate⑧——非上线测试单
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：一级代理是否测试线
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：二级代理是否测试线
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：三级代理是否测试线
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：四级代理是否测试线
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：五级代理是否测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号
funnel AS (                                                                                         -- 公共表表达式：开启中间结果集 funnel——逐 gate 漏斗
  SELECT COUNT(*)                                                        AS n_raw,                  -- 计数表达式：原始行数
         SUM(g1_latest)                                                  AS n_g1,                   -- 汇总表达式：过 gate① 者
         SUM(g1_latest * g2_category)                                    AS n_g2,                   -- 汇总表达式：累计过 gate①②
         SUM(g1_latest * g2_category * g3_norebet)                       AS n_g3,                   -- 汇总表达式：累计过 ①②③
         SUM(g1_latest * g2_category * g3_norebet * g4_notest)           AS n_g4,                   -- 汇总表达式：累计过 ①~④
         SUM(g1_latest * g2_category * g3_norebet * g4_notest * g5_rate) AS n_g5,                   -- 汇总表达式：累计过 ①~⑤
         SUM(g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake)          AS n_g6, -- 汇总表达式：累计过 ①~⑥（＝ dirty 母体）
         SUM(g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake * g7_comm) AS n_g7, -- 汇总表达式：累计过 ①~⑦
         SUM(g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake * g7_comm * g8_launch) AS n_g8, -- 汇总表达式：累计过 ①~⑧（＝ clean 母体）
         SUM(lv1_hit) AS n_lv1, SUM(lv2_hit) AS n_lv2, SUM(lv3_hit) AS n_lv3,                       -- 汇总表达式：★ 五级代理逐级命中
         SUM(lv4_hit) AS n_lv4, SUM(lv5_hit) AS n_lv5,                                              -- 汇总表达式：四级与五级命中
         SUM(CASE WHEN g4_notest = 0 THEN 1 ELSE 0 END)                  AS n_any_test              -- 条件计数：任一级命中之合计
  FROM tagged                                                                                       -- 取数来源：取自本条自建的中间结果集 tagged
),                                                                                                  -- 续行：收束上方的子查询或函数括号
global_mu0 AS (                                                                                     -- 公共表表达式：★ P0-1 —— 原名 glob 系保留字，今正名
  SELECT SUM(CASE WHEN g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake = 1
                  THEN stake END)                                        AS s_dirty,                -- 条件汇总：dirty 母体之本金（未剔哨兵与上线测试）
       SUM(CASE WHEN g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake = 1
                  THEN stake - payout END)                               AS g_dirty,                -- 条件汇总：dirty 母体之毛利
       SUM(CASE WHEN g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake * g7_comm * g8_launch = 1
                  THEN stake END)                                        AS s_clean,                -- 条件汇总：clean 母体之本金
       SUM(CASE WHEN g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake * g7_comm * g8_launch = 1
                  THEN stake - payout END)                               AS g_clean                 -- 条件汇总：clean 母体之毛利
  FROM tagged                                                                                       -- 取数来源：取自本条自建的中间结果集 tagged
),                                                                                                  -- 续行：收束上方的子查询或函数括号
byg AS (                                                                                            -- 公共表表达式：开启中间结果集 byg——逐组 μ0（★ 增报稳定性列）
  SELECT g,                                                                                         -- 取列：注型组
         COUNT(*)                                                        AS n_bets,                 -- 计数表达式：组内注单数
         COUNT(DISTINCT bet05)                                           AS n_members,              -- 计数表达式：★ 组内会员数
         COUNT(DISTINCT dt)                                              AS n_days,                 -- 计数表达式：★ 组内出现天数
         SUM(stake)                                                      AS stake_sum,              -- 汇总表达式：组内本金暴露
         SUM(payout)                                                     AS payout_sum,             -- 汇总表达式：★ 组内派彩暴露
         -1 * SUM(stake - payout) * 100.0 / NULLIF(SUM(stake), 0)        AS mu0_pct                 -- 比率表达式：该组 μ0（暴露加权，GGR 口径）
  FROM tagged                                                                                       -- 取数来源：取自本条自建的中间结果集 tagged
  WHERE g1_latest * g2_category * g3_norebet * g4_notest * g5_rate * g6_stake * g7_comm * g8_launch = 1 -- 过滤条件：只取 clean 母体
  GROUP BY g                                                                                        -- 分组：按注型组汇总
  HAVING COUNT(*) >= 1000                                                                           -- 分组后过滤：小组无判别力，不入分层诊断
),                                                                                                  -- 续行：收束上方的子查询或函数括号
agg AS (                                                                                            -- 公共表表达式：开启中间结果集 agg——分层极值与 near-zero 计数
  SELECT COUNT(*)                                                        AS n_groups,               -- 计数表达式：可诊断之组数
         MIN(mu0_pct)                                                    AS mu0_min_pct,            -- 聚合取值：分层下界
         MAX(mu0_pct)                                                    AS mu0_max_pct,            -- 聚合取值：分层上界
         MIN(ABS(mu0_pct))                                               AS abs_min,                -- 聚合取值：绝对值下界
         MAX(ABS(mu0_pct))                                               AS abs_max,                -- 聚合取值：绝对值上界
         SUM(CASE WHEN ABS(mu0_pct) < 0.05 THEN 1 ELSE 0 END)            AS n_near_zero             -- 条件计数：★ P0-4——μ0 逼近零之组数，极差比之爆炸源
  FROM byg                                                                                          -- 取数来源：取自本条自建的中间结果集 byg
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  f.n_raw                                                                AS n_raw,                  -- 取列：原始行数
  f.n_g1, f.n_g2, f.n_g3, f.n_g4, f.n_g5, f.n_g6, f.n_g7, f.n_g8,                                   -- 取列：★ 逐 gate 累计存活行数——污染量化之底料
  f.n_lv1, f.n_lv2, f.n_lv3, f.n_lv4, f.n_lv5, f.n_any_test,                                        -- 取列：★ 五级代理逐级命中与合计
  ROUND(-1 * gm.g_dirty * 100.0 / NULLIF(gm.s_dirty, 0), 6)              AS mu0_global_dirty_ew_pct, -- 比率表达式：★ dirty 全局 μ0（暴露加权）
  ROUND(-1 * gm.g_clean * 100.0 / NULLIF(gm.s_clean, 0), 6)              AS mu0_global_clean_ew_pct, -- 比率表达式：★ clean 全局 μ0（暴露加权）
  ROUND(ABS(-1 * gm.g_dirty * 100.0 / NULLIF(gm.s_dirty, 0)
          - (-1 * gm.g_clean * 100.0 / NULLIF(gm.s_clean, 0))), 8)       AS contamination_pp,       -- 比率表达式：★★ 二者之差即 SC-2 污染影响（百分点）
  a.n_groups                                                             AS n_groups,               -- 取列：可诊断之组数
  ROUND(a.mu0_min_pct, 6)                                                AS mu0_min_pct,            -- 取列：分层下界
  ROUND(a.mu0_max_pct, 6)                                                AS mu0_max_pct,            -- 取列：分层上界
  ROUND(a.abs_min, 6)                                                    AS abs_min,                -- 取列：★ 绝对值下界——须与 spread 并读
  ROUND(a.abs_max, 6)                                                    AS abs_max,                -- 取列：绝对值上界
  a.n_near_zero                                                          AS n_near_zero,            -- 取列：★ near-zero 组数
  ROUND(a.abs_max / NULLIF(a.abs_min, 0), 4)                             AS spread_ratio,           -- 比率表达式：极差比（★ 诊断排序器，非裁定判据）
  CASE                                                                                              -- 条件分支：起始分支——★ P0-3 判词降级
    WHEN a.n_groups < 2                THEN 'NON_DIAGNOSTIC（可诊断之组不足二）'                       -- 分支判定：无从比较
    WHEN a.n_near_zero > 0             THEN 'NON_DIAGNOSTIC（有组 μ0 逼近零，极差比失真）'              -- 分支判定：★ near-zero 保护
    WHEN a.abs_min < 0.05              THEN 'NON_DIAGNOSTIC（下界过小，极差比失真）'                    -- 分支判定：ε 门槛
    ELSE '✅ spread_ratio 可读（★ 系诊断排序器，不单独裁 S1；分层必要性须并读 abs_min／abs_max／组样本量）' -- 分支判定：可读
  END                                                                    AS verdict_spread          -- 条件分支：收束上方判词，产出「verdict_spread」
FROM agg a                                                                                          -- 取数来源：取自本条自建的中间结果集 agg
CROSS JOIN global_mu0 gm                                                                            -- 交叉连接：★ 别名 gm，接单行全局汇总
CROSS JOIN funnel f;                                                                                -- 交叉连接：接单行漏斗汇总


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-5b · Tip_1_ 性质完整核验（★ P0-2／P0-5 · 撤回小费之判后重做）
-- ▸ 导出：需要 —— 存为「审计/_b4/_B4_5b_tip_nature.csv」。
--   ★ v1.0.1 只验 bet13 是否 > 0，不足以定性。今补 bet13 × bet14 之完整交叉，
--     并按注型分列，看其分布形态。
--   ★ 判读（四态，禁跳过 UNKNOWN 直取 TIP）：
--     bet13>0 ∧ bet14 恒为 0        → 单向扣款，**非投注亦非小费之充分证据**
--     bet13>0 ∧ bet14 有正值        → 具赔付关系，或系某种玩法
--     bet13 与 bet14 皆有零有正      → 结构混杂，须再拆
--     ★ 无论何者，**在上游确认前一律 UNKNOWN / SPECIAL_TRANSACTION**。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(bet09)                                                            AS bet09_value,            -- 取列：注型原值
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(bet05))                                            AS n_members,              -- 计数表达式：涉及会员数
  COUNT(DISTINCT dt)                                                     AS n_days,                 -- 计数表达式：出现天数
  SUM(CASE WHEN NULLIF(TRIM(bet13), '') IS NULL THEN 1 ELSE 0 END)       AS n_b13_blank,            -- 条件计数：本金为空
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_b13_zero, -- 条件计数：本金为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_b13_pos,  -- 条件计数：本金为正
  SUM(CASE WHEN NULLIF(TRIM(bet14), '') IS NULL THEN 1 ELSE 0 END)       AS n_b14_blank,            -- 条件计数：★ 派彩为空
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_b14_zero, -- 条件计数：★ 派彩为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_b14_pos,  -- 条件计数：★ 派彩为正
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0
             AND CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_both_pos, -- 条件计数：★ 二者皆正——具赔付关系者
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0
             AND COALESCE(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)), 0) = 0 THEN 1 ELSE 0 END) AS n_b13pos_b14zero, -- 条件计数：★★ 有本金无派彩——单向扣款
  ROUND(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 2)          AS b13_sum,                -- 汇总表达式：本金总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))), 2)          AS b14_sum,                -- 汇总表达式：派彩总额
  COUNT(DISTINCT TRIM(commission))                                       AS n_comm,                 -- 计数表达式：佣金标记取值数
  CASE                                                                                              -- 条件分支：起始分支——性质裁定（四态）
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) = 0
     AND SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '⚠ 单向扣款（本金恒正・派彩恒零）—— UNKNOWN / SPECIAL_TRANSACTION，禁径判为小费'          -- 分支判定：单向扣款
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) > 0
      THEN '◐ 具赔付关系——形似投注，惟仍须上游确认其玩法定义'                                        -- 分支判定：具赔付
    ELSE '⚠ 结构混杂——须再拆分后重验'                                                               -- 分支判定：混杂
  END                                                                    AS verdict_nature          -- 条件分支：收束上方判词，产出「verdict_nature」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(bet09) IN ('Tip_1_', 'Banker', 'Tie')                                                    -- 并列条件：受检注型 ＋ 二组对照（Banker 常态・Tie 高赔）
GROUP BY TRIM(bet09)                                                                                -- 分组：按注型原值汇总
ORDER BY n_rows DESC, bet09_value;                                                                  -- 排序：按行数降序排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-6 · bet01 身份与 ROW_NUMBER 并列检测（★ P1 · rn=1 逻辑之地基）
-- ▸ 导出：不需要 —— §M0-6 地基读数，屏幕看结果。
--   ★ 缘由：全包 54 处 rn=1 去重，皆建于「bet01 代表同一张注单」与
--     「三级排序可定唯一最新版」二前提上。二者从未正面实测。
--   ★ 判读：
--     n_tie > 0  → 三级排序未能定唯一，ROW_NUMBER 任选一行 → 结果不可复现
--     n_tie = 0  → 排序唯一，rn=1 逻辑之地基成立
-- ──────────────────────────────────────────────────────────────────────────
WITH v AS (                                                                                         -- 公共表表达式：开启中间结果集 v——注单版本与并列计数
  SELECT b.bet01                                                         AS bet01,                  -- 取列：注单号
         COUNT(*)                                                        AS n_ver,                  -- 计数表达式：该注单之版本数
         COUNT(DISTINCT CONCAT(COALESCE(b.updatetime, ''), '|',
                               COALESCE(b.sync_time, ''), '|',
                               COALESCE(CAST(b.dt AS STRING), '')))      AS n_sortkey               -- 计数表达式：★ 三级排序键之去重数
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单主表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定分析窗
    AND CAST(b.bet02 AS STRING) = '101'                                                             -- 并列条件：限定百家乐
  GROUP BY b.bet01                                                                                  -- 分组：按注单号汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  COUNT(*)                                                               AS n_bet01,                -- 计数表达式：去重注单数
  SUM(n_ver)                                                             AS n_rows_total,           -- 汇总表达式：总行数
  ROUND(SUM(n_ver) * 1.0 / NULLIF(COUNT(*), 0), 4)                       AS ver_per_bet01,          -- 比率表达式：每注单平均版本数
  SUM(CASE WHEN n_ver > 1 THEN 1 ELSE 0 END)                             AS n_multi_ver,            -- 条件计数：多版本之注单数
  SUM(CASE WHEN n_ver > n_sortkey THEN 1 ELSE 0 END)                     AS n_tie,                  -- 条件计数：★★ 三级排序键并列之注单数
  SUM(CASE WHEN n_ver > n_sortkey THEN n_ver - n_sortkey ELSE 0 END)     AS n_tie_rows,             -- 条件汇总：并列所涉之多余行数
  MAX(n_ver)                                                             AS max_ver,                -- 聚合取值：单注单最多版本数
  CASE                                                                                              -- 条件分支：起始分支——地基裁定
    WHEN SUM(CASE WHEN n_ver > n_sortkey THEN 1 ELSE 0 END) = 0
      THEN '✅ 三级排序唯一——rn=1 逻辑之地基成立，结果可复现'                                         -- 分支判定：地基成立
    ELSE '❌ 存在并列——ROW_NUMBER 任选一行，rn=1 结果不可复现，须加第四级排序键'                        -- 分支判定：地基不成立
  END                                                                    AS verdict_tie             -- 条件分支：收束上方判词，产出「verdict_tie」
FROM v;                                                                                             -- 取数来源：取自本条自建的中间结果集 v


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（v1.0.2 之四条新锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁九 · **业务规则不得先写进过滤器，再用过滤后之数据证明该规则。**
--   次序须为：HYPOTHESIS → 验证 → OBSERVED → 人工裁定 → 方成 GATE。
--   颠倒即循环论证。本轮 Tip_1_ 即实例：我先写 bet09 <> 'Tip_1_'，
--   再以「§M0-1 未见 Tip_1_」为据证其非投注——而那恰因过滤器自己滤掉了它。
--   ★ 撤回 W-10：锁六（Tip_1_ 系小费）作废；其性质改判 UNKNOWN。
--
-- 锁十 · 极差比只作诊断排序器，不单独裁 S1。
--   min|μ0| → 0 时 spread_ratio 数学爆炸，可制造假警报。
--   须并读 abs_min／abs_max／n_near_zero／组样本量，方得下分层必要性之判。
--
-- 锁十一 · 保留字须实测，不得凭印象取 CTE 名。
--   glob 系 StarRocks 之 GLOB 运算符保留字，解析器直接拒收。
--   ★ 凡新立 CTE 名，宜避 glob／match／like／range／rank／value 等常见保留字。
--
-- 锁十二 · 「注释声明」≠「代码实现」。
--   v1.0.1 注释书「兼报含脏与洁净两版」，实际只算洁净版——
--   规格与实现不一致，且注释看似已覆盖，最易骗过审查。
--   ★ 凡注释承诺之输出，须逐项对照 SELECT 列表核实其确已产出。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
