-- ══════════════════════════════════════════════════════════════════════════
-- B-4 · μ0(g, w) 分层现算 · 审计工具 v1.0.0（★ 零占位符，可直接运行）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/ ★
-- ★ 本件系 v12 之前置阻断 B-4 之解除工具，不入 SQL 总包，不触 v11.0.3 一字 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由（承 Z2-01 · v11.0.3 已立而未现算）：
--   ROI 之零假设非 0，而为 **μ0(g, w) ＝ −hold%(g, w)**，g 为玩法／注型组、
--   w 为时间窗。v11.0.3 已把此律写入规范层，惟**各组之值仍为 UNKNOWN**。
--   未现算前，凡用 μ0 者须标明系「全局近似」抑或「分层」——此即 B-4 之阻断。
--
-- ★ 一处关系斧正（本件所据）：
--   bet16（退水）与 bet41（有效投注／洗码量）**在源表 ods_a168_bet02 中是有的**；
--   B-5 所卡者系「未在交付件名单交付」，**非「源表没有」**。
--   故 μ0 现算可直接自源表取数，**GGR 与 NGR 两口径可同时算出**，
--   **B-4 不受 B-5 阻断**。二者若不辨明，B-4 会被误判为须等 B-5 而白白串行。
--
-- ★ 口径锁（承在册铁律，不得改）：
--   本金 stake ＝ bet13 ÷ bet11（原币÷汇率，本金口径，**非洗码口径**）
--   H16 恒等式  bet17 ＝ bet14 − bet13 + bet16（实测 100% 成立）
--   会员净盈亏（不含退水） ＝ bet14 − bet13
--   会员净盈亏（含退水）   ＝ bet17
--   平台毛利 GGR ＝ bet13 − bet14        平台净额 NGR ＝ −bet17
--   ⚠ ROI 系**净收益率**，持平 ＝ 0（非回报倍数 1+ROI）；分母恒为本金口径。
--
-- ★ 去重与排除（四道，缺一即污染）：
--   ① 同注单号取最新版本 rn = 1（三级排序 updatetime／sync_time／dt）
--   ② category = '1' 一般注单     ③ bet38 = 'N' 非重对
--   ④ 排除公司测试线代理（age022 = '1'，在册 214 条，五级代理线逐级排除）
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-1 · μ0(g) 逐注型组现算（★ B-4 之主件 · 全窗）
-- ▸ 导出：需要 —— 存为「审计/_b4/_B4_1_mu0_by_bettype.csv」（μ0 登记之底料）。
--   ★ 判读：
--     · hold_ggr_pct 系平台毛利率，μ0_ggr ＝ −hold_ggr_pct，即该组之 ROI 零假设
--     · 各组 μ0 若彼此相差逾一个数量级，即坐实「全局单一 μ0 系统性偏误」之判
--     · n_bets 过小之组（< 1000）判 NON_DIAGNOSTIC_ZERO 之近亲，其 μ0 不得登记
--   ★ 本条不预设注型之业务名（庄／闲／和／对子／边注），只按 bet09 取值分组，
--     其业务名须俟 §M0-3 之取值普查与上游确认后方得标注——承 R4-SEMANTIC-02。
-- ──────────────────────────────────────────────────────────────────────────
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta——公司测试线代理
  SELECT DISTINCT age001                                                 AS aid                     -- 取列：代理编号
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档
  WHERE age022 = '1'                                                                                -- 过滤条件：铁律④b——公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk——同注单号取最新版本
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                    -- 取列：注单号、会员、玩法、汇率、本金、派彩、退水、净额
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category, b.bet38, b.commission,            -- 续行：五级代理、注单类别、重对标记、免佣标记
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每注单之最新版本
           PARTITION BY b.bet01                                                                     -- 窗口分区：按注单号分区
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS rn                      -- 排序：三级排序取最新
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单主表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定分析窗
    AND CAST(b.bet02 AS STRING) = '101'                                                             -- 并列条件：限定百家乐
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd——有效注单
  SELECT r.bet09, r.commission,                                                                     -- 取列：玩法／注型，免佣标记
         CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS stake,                  -- 取值表达式：本金口径 stake ＝ bet13 ÷ bet11
         CAST(NULLIF(TRIM(r.bet14), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS payout,                 -- 取值表达式：派彩，同除汇率归一
         CAST(NULLIF(TRIM(r.bet16), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS rebate,                 -- 取值表达式：★ 退水，同除汇率归一
         CAST(NULLIF(TRIM(r.bet17), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS net_member              -- 取值表达式：会员净额（含退水）
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：一级代理是否测试线
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：二级代理是否测试线
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：三级代理是否测试线
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：四级代理是否测试线
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：五级代理是否测试线
  WHERE r.rn = 1                                                                                    -- 过滤条件：去重①——同注单号取最新版本
    AND r.category = '1'                                                                            -- 并列条件：去重②——一般注单
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：去重③——非重对
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：去重④——排除测试线
    AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0                                        -- 并列条件：汇率须为正，免除零
    AND CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8)) > 0                                        -- 并列条件：本金须为正
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(bet09)                                                            AS bet_type_raw,           -- 取列：★ 注型原值（业务名俟 §M0-3 确认后标注）
  TRIM(commission)                                                       AS commission_flag,        -- 取列：免佣标记（影响庄注理论优势）
  COUNT(*)                                                               AS n_bets,                 -- 计数表达式：该组注单数
  ROUND(SUM(stake), 2)                                                   AS stake_sum,              -- 汇总表达式：本金总额（★ 一切比率之分母）
  ROUND(SUM(stake - payout), 2)                                          AS ggr_sum,                -- 汇总表达式：平台毛利 GGR ＝ Σ(本金 − 派彩)
  ROUND(SUM(rebate), 2)                                                  AS rebate_sum,             -- 汇总表达式：★ 退水总额（B-5 所缺之列，源表实有）
  ROUND(SUM(-1 * net_member), 2)                                         AS ngr_sum,                -- 汇总表达式：★ 平台净额 NGR ＝ −Σ会员净额
  ROUND(SUM(stake - payout) * 100.0 / NULLIF(SUM(stake), 0), 6)          AS hold_ggr_pct,           -- 比率表达式：毛利率 hold%（GGR 口径）
  ROUND(SUM(-1 * net_member) * 100.0 / NULLIF(SUM(stake), 0), 6)         AS hold_ngr_pct,           -- 比率表达式：净利率 hold%（NGR 口径）
  ROUND(-1 * SUM(stake - payout) * 100.0 / NULLIF(SUM(stake), 0), 6)     AS mu0_ggr_pct,            -- 比率表达式：★★ μ0(g)｜GGR 口径 ＝ −hold%
  ROUND(-1 * SUM(-1 * net_member) * 100.0 / NULLIF(SUM(stake), 0), 6)    AS mu0_ngr_pct,            -- 比率表达式：★★ μ0(g)｜NGR 口径 ＝ −hold%
  ROUND(SUM(rebate) * 100.0 / NULLIF(SUM(stake), 0), 6)                  AS rebate_pct,             -- 比率表达式：退水率——GGR 与 NGR 之差即此
  CASE                                                                                              -- 条件分支：起始分支——判该组之 μ0 可否登记
    WHEN COUNT(*) < 1000                                                 THEN 'NON_DIAGNOSTIC（组内注单不足千笔，μ0 不得登记）' -- 分支判定：基数不足
    WHEN SUM(stake) IS NULL OR SUM(stake) = 0                            THEN 'STRUCTURAL_ZERO（分母为零）'                 -- 分支判定：结构性零
    ELSE '✅ 可登记'                                                                                -- 分支判定：可用
  END                                                                    AS verdict_mu0             -- 条件分支：收束上方判词，产出「verdict_mu0」
FROM vd                                                                                             -- 取数来源：取自本条自建的中间结果集 vd
GROUP BY TRIM(bet09), TRIM(commission)                                                              -- 分组：按注型与免佣标记分组——★ 此即 g 之定义
ORDER BY stake_sum DESC, bet_type_raw, commission_flag;                                             -- 排序：按本金总额降序排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-2 · 全局近似 μ0 vs 分层 μ0 之差（★ 坐实分层之必要，或反证其不必要）
-- ▸ 导出：不需要 —— §M0-2 对照读数，屏幕看结果。
--   ★ 本条系 Z2-01 之**证伪机会**：若各组 μ0 彼此相近，则「全局近似」本无大碍，
--     Z2-01 之分层要求即属过度设计，应据实收窄——**规则亦须受证据检验**。
--   ★ 判读：
--     spread_ratio ＝ max|μ0| ÷ min|μ0|
--       < 2   → 分层收益有限，全局近似可用（须另标其误差上界）
--       ≥ 10  → 分层为必须，全局 μ0 判 S1 系统性偏误
--   ★ 只计入 §M0-1 判「可登记」之组，免小组噪声污染极值。
-- ──────────────────────────────────────────────────────────────────────────
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta——公司测试线代理
  SELECT DISTINCT age001                                                 AS aid                     -- 取列：代理编号
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档
  WHERE age022 = '1'                                                                                -- 过滤条件：公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk——同注单号取最新版本
  SELECT b.bet01, b.bet09, b.bet11, b.bet13, b.bet14, b.bet17,                                      -- 取列：注单号、玩法、汇率、本金、派彩、净额
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category, b.bet38,                          -- 续行：五级代理、注单类别、重对标记
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：取每注单之最新版本
           PARTITION BY b.bet01                                                                     -- 窗口分区：按注单号分区
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS rn                      -- 排序：三级排序取最新
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单主表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定分析窗
    AND CAST(b.bet02 AS STRING) = '101'                                                             -- 并列条件：限定百家乐
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd——有效注单
  SELECT TRIM(r.bet09)                                                   AS g,                      -- 取列：注型组
         CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS stake,                  -- 取值表达式：本金口径
         CAST(NULLIF(TRIM(r.bet14), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS payout                  -- 取值表达式：派彩
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：一级代理
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：二级代理
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：三级代理
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：四级代理
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：五级代理
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：去重三道
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：排除测试线
    AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0                                        -- 并列条件：汇率为正
    AND CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8)) > 0                                        -- 并列条件：本金为正
),                                                                                                  -- 续行：收束上方的子查询或函数括号
byg AS (                                                                                            -- 公共表表达式：开启中间结果集 byg——逐组 μ0
  SELECT g,                                                                                         -- 取列：注型组
         COUNT(*)                                                        AS n_bets,                 -- 计数表达式：组内注单数
         SUM(stake)                                                      AS stake_sum,              -- 汇总表达式：组内本金
         -1 * SUM(stake - payout) * 100.0 / NULLIF(SUM(stake), 0)        AS mu0_pct                 -- 比率表达式：该组 μ0（GGR 口径）
  FROM vd                                                                                           -- 取数来源：取自本条自建的中间结果集 vd
  GROUP BY g                                                                                        -- 分组：按注型组汇总
  HAVING COUNT(*) >= 1000                                                                           -- 分组后过滤：只计可登记之组，免小组噪声
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  COUNT(*)                                                               AS n_groups,               -- 计数表达式：可登记之组数
  ROUND(-1 * (SELECT SUM(stake_sum) * 0 + SUM(s2.stake - s2.payout) FROM vd s2) * 100.0
        / NULLIF((SELECT SUM(s3.stake) FROM vd s3), 0), 6)               AS mu0_global_pct,         -- 比率表达式：★ 全局近似 μ0（暴露加权，式甲）
  ROUND(MIN(mu0_pct), 6)                                                 AS mu0_min_pct,            -- 聚合取值：分层 μ0 之下界
  ROUND(MAX(mu0_pct), 6)                                                 AS mu0_max_pct,            -- 聚合取值：分层 μ0 之上界
  ROUND(MAX(ABS(mu0_pct)) / NULLIF(MIN(ABS(mu0_pct)), 0), 4)             AS spread_ratio,           -- 比率表达式：★★ 极差比——分层必要性之判据
  CASE                                                                                              -- 条件分支：起始分支——分层必要性裁定
    WHEN COUNT(*) < 2                                                    THEN 'NON_DIAGNOSTIC（可登记之组不足二）'          -- 分支判定：无从比较
    WHEN MAX(ABS(mu0_pct)) / NULLIF(MIN(ABS(mu0_pct)), 0) >= 10          THEN '★ 分层为必须——全局 μ0 判 S1 系统性偏误'      -- 分支判定：分层必要
    WHEN MAX(ABS(mu0_pct)) / NULLIF(MIN(ABS(mu0_pct)), 0) < 2            THEN '⚠ 分层收益有限——Z2-01 之要求宜据实收窄'        -- 分支判定：过度设计
    ELSE '◐ 分层有益惟非悬殊——须标明所用口径，不得默认'                                                 -- 分支判定：居中
  END                                                                    AS verdict_stratify        -- 条件分支：收束上方判词，产出「verdict_stratify」
FROM byg;                                                                                           -- 取数来源：取自本条自建的中间结果集 byg


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-3 · bet09 取值普查（★ 承 R4-SEMANTIC-02：未读值即不得标业务名）
-- ▸ 导出：需要 —— 存为「审计/_b4/_B4_3_bet09_census.csv」（注型业务名之底料）。
--   ★ 缘由：§M0-1 只按 bet09 原值分组，**未标业务名**。庄／闲／和／对子／边注
--     之对应关系须先自取值分布与样例读出，再向上游确认，方得标注。
--     未读值即标名者，正是 R4-SEMANTIC-02 所禁——本包已两犯，不再犯第三次。
--   ★ 判读：若某取值之 μ0 显著偏离（如逾 −10%），多为和局或边注，可为确认之佐证；
--     惟**佐证非定谳**，业务名仍须上游确认后方得登记。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(bet09)                                                            AS bet09_value,            -- 取列：注型原值
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该值之注单数
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 4)                     AS pct_of_all,             -- 比率窗口表达式：该值占全窗之比
  COUNT(DISTINCT TRIM(bet05))                                            AS n_members,              -- 计数表达式：涉及会员数
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：首现分区日
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：末现分区日
  COUNT(DISTINCT TRIM(commission))                                       AS n_commission_flag,      -- 计数表达式：该值下之免佣标记取值数
  ROUND(AVG(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
            / NULLIF(CAST(NULLIF(TRIM(bet11), '') AS DECIMAL(20,8)), 0)), 4) AS avg_stake           -- 聚合取值：均注额——边注多为小额，可为佐证
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
GROUP BY TRIM(bet09)                                                                                -- 分组：按注型原值汇总
ORDER BY n_rows DESC, bet09_value;                                                                  -- 排序：按注单数降序排列；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之五条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · B-4 不受 B-5 阻断。
--   bet16／bet41 在**源表**中实有，B-5 所卡者系**交付件名单未交付**。
--   故 μ0 之 GGR 与 NGR 两口径皆可自源表现算。二者若不辨，B-4 将被误判为
--   须等 B-5 而白白串行——此即「阻断之依赖关系亦须逐条核实」之实例。
--
-- 锁二 · 业务名须上游确认，不得由数值倒推。
--   §M0-1 只出 bet09 原值，**不标庄／闲／和／对子／边注**。
--   μ0 偏离虽可为佐证，**佐证非定谳**；未经上游确认即标名者，判 R4-SEMANTIC-02 违例。
--
-- 锁三 · 规则亦须受证据检验。
--   §M0-2 系 Z2-01 之**证伪机会**：若 spread_ratio < 2，则分层收益有限，
--   Z2-01 之要求应据实收窄。**立了规则就不许它被证伪，即是教条而非纪律。**
--
-- 锁四 · 小组不得登记。
--   组内注单 < 1000 者判 NON_DIAGNOSTIC，其 μ0 不入册；
--   §M0-2 之极值亦只取可登记之组，免小组噪声污染 spread_ratio。
--
-- 锁五 · 两口径不得互代。
--   μ0_ggr 与 μ0_ngr 差一个 rebate_pct。凡用 μ0 者须明书所取何口径；
--   以 GGR 口径之 μ0 判 NGR 口径之 ROI（或反之），判 S1。
--
-- ★ B-4 解除条件：§M0-1 之各组 μ0 现算完毕、§M0-3 之业务名经上游确认、
--   §M0-2 之分层必要性裁定在册 —— 三者齐备，B-4 方由 BLOCK 转 PASS。
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，与 SQL 总包版号无涉；
--   总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
