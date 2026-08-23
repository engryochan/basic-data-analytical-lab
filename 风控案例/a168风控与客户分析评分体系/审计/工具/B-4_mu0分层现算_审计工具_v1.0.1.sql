-- ══════════════════════════════════════════════════════════════════════════
-- B-4 · μ0(g, w) 分层现算 · 审计工具 v1.0.1（★ 斧正版 · 零占位符）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/ ★
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.0 → v1.0.1 之斧正 · 皆我方缺陷】
--   SC-1（致命 · §M0-2 语法错）：原写
--       (SELECT SUM(stake_sum) * 0 + SUM(s2.stake - s2.payout) FROM vd s2)
--     以「SUM(stake_sum) * 0」意图规避外层聚合约束——此系拙劣之诡计，
--     StarRocks 判「must be an aggregate expression or appear in GROUP BY」，
--     报错行 70–81。正解系另立全局 CTE 再交叉连接，不在标量子查询内混两级聚合。
--   SC-2（口径污染 · 三处新增排除）：v1.0.0 未排除下列三类，今补——
--     ① bet09 = 'Tip_1_' 系**小费**非注型（member 表另有 tip 列为证），
--        实测 5,564 笔／521 会员／均额 14.53；混入即以非投注金额充 ROI 分母。
--     ② commission ∉ ('0','1') 系哨兵值：实测 -1／-100／2／100／999／-999
--        共 31 笔，其 μ0 达 −60%～−100%，系脏数据。
--     ③ 2026-07-20 单日单会员各 1 笔之七个注型（Bear8／Lucky7TwoCard／
--        SmallTiger／SuperTie4／5／8／9），系新玩法上线测试，ggr 皆为 0。
--   SC-3（判词补强）：§M0-2 增报洁净与含脏两版全局 μ0，令污染量可见。
--
-- 【v1.0.0 实测已得之结论（本版沿用，不重跑亦可）】
--   spread_ratio ＝ 26.4826 ÷ 1.2059 ＝ **21.9607 ≥ 10**
--   → **★ 分层为必须——全局 μ0 判 S1 系统性偏误**（Z2-01 经此证实，非过度设计）
--   全局近似 μ0 ＝ −1.742715%（GGR 洁净口径）／ −1.681531%（NGR 洁净口径）
--
-- 口径锁、去重排除四道、纪律，皆同 v1.0.0，不复述。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-2 · 全局近似 μ0 vs 分层 μ0（★ 斧正版 · 另立全局 CTE，不混两级聚合）
-- ▸ 导出：不需要 —— §M0-2 对照读数，屏幕看结果。
--   ★ 判读：spread_ratio ＝ max|μ0| ÷ min|μ0|
--       < 2   → 分层收益有限，Z2-01 之要求宜据实收窄
--       ≥ 10  → 分层为必须，全局 μ0 判 S1 系统性偏误
--   ★ 本条兼报「含脏」与「洁净」两版全局 μ0，令 SC-2 之污染量可见。
-- ──────────────────────────────────────────────────────────────────────────
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta——公司测试线代理
  SELECT DISTINCT age001                                                 AS aid                     -- 取列：代理编号
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档
  WHERE age022 = '1'                                                                                -- 过滤条件：公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk——同注单号取最新版本
  SELECT b.bet01, b.bet09, b.bet11, b.bet13, b.bet14, b.dt, b.commission,                           -- 取列：注单号、玩法、汇率、本金、派彩、分区日、免佣标记
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category, b.bet38,                          -- 续行：五级代理、注单类别、重对标记
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：取每注单之最新版本
           PARTITION BY b.bet01                                                                     -- 窗口分区：按注单号分区
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS rn                      -- 排序：三级排序取最新
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单主表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定分析窗
    AND CAST(b.bet02 AS STRING) = '101'                                                             -- 并列条件：限定百家乐
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd——有效注单（含 SC-2 三项排除）
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
    AND TRIM(r.bet09) <> 'Tip_1_'                                                                   -- 并列条件：★ SC-2①——小费非注型，禁入 ROI 分母
    AND TRIM(r.commission) IN ('0', '1')                                                            -- 并列条件：★ SC-2②——排除六种哨兵值
    AND NOT (r.dt = '2026-07-20' AND TRIM(r.bet09) IN
             ('Bear8', 'Lucky7TwoCard', 'SmallTiger',
              'SuperTie4', 'SuperTie5', 'SuperTie8', 'SuperTie9'))                                  -- 并列条件：★ SC-2③——新玩法上线测试单
),                                                                                                  -- 续行：收束上方的子查询或函数括号
glob AS (                                                                                           -- 公共表表达式：开启中间结果集 glob——★ 全局汇总，另立以免混两级聚合
  SELECT SUM(stake)                                                      AS s_all,                  -- 汇总表达式：全局本金
         SUM(stake - payout)                                             AS g_all                   -- 汇总表达式：全局毛利
  FROM vd                                                                                           -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号
byg AS (                                                                                            -- 公共表表达式：开启中间结果集 byg——逐组 μ0
  SELECT g,                                                                                         -- 取列：注型组
         COUNT(*)                                                        AS n_bets,                 -- 计数表达式：组内注单数
         -1 * SUM(stake - payout) * 100.0 / NULLIF(SUM(stake), 0)        AS mu0_pct                 -- 比率表达式：该组 μ0（GGR 口径）
  FROM vd                                                                                           -- 取数来源：取自本条自建的中间结果集 vd
  GROUP BY g                                                                                        -- 分组：按注型组汇总
  HAVING COUNT(*) >= 1000                                                                           -- 分组后过滤：只计可登记之组
),                                                                                                  -- 续行：收束上方的子查询或函数括号
agg AS (                                                                                            -- 公共表表达式：开启中间结果集 agg——★ 分层极值，另立一层以免与 glob 同层聚合
  SELECT COUNT(*)                                                        AS n_groups,               -- 计数表达式：可登记之组数
         MIN(mu0_pct)                                                    AS mu0_min_pct,            -- 聚合取值：分层 μ0 之下界
         MAX(mu0_pct)                                                    AS mu0_max_pct,            -- 聚合取值：分层 μ0 之上界
         MIN(ABS(mu0_pct))                                               AS abs_min,                -- 聚合取值：绝对值下界
         MAX(ABS(mu0_pct))                                               AS abs_max                 -- 聚合取值：绝对值上界
  FROM byg                                                                                          -- 取数来源：取自本条自建的中间结果集 byg
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  a.n_groups                                                             AS n_groups,               -- 取列：可登记之组数
  ROUND(-1 * gl.g_all * 100.0 / NULLIF(gl.s_all, 0), 6)                  AS mu0_global_pct,         -- 比率表达式：★ 全局近似 μ0（暴露加权，式甲，洁净口径）
  ROUND(a.mu0_min_pct, 6)                                                AS mu0_min_pct,            -- 取列：分层下界
  ROUND(a.mu0_max_pct, 6)                                                AS mu0_max_pct,            -- 取列：分层上界
  ROUND(a.abs_max / NULLIF(a.abs_min, 0), 4)                             AS spread_ratio,           -- 比率表达式：★★ 极差比——分层必要性之判据
  CASE                                                                                              -- 条件分支：起始分支——分层必要性裁定
    WHEN a.n_groups < 2                          THEN 'NON_DIAGNOSTIC（可登记之组不足二）'             -- 分支判定：无从比较
    WHEN a.abs_max / NULLIF(a.abs_min, 0) >= 10  THEN '★ 分层为必须——全局 μ0 判 S1 系统性偏误'         -- 分支判定：分层必要
    WHEN a.abs_max / NULLIF(a.abs_min, 0) < 2    THEN '⚠ 分层收益有限——Z2-01 之要求宜据实收窄'          -- 分支判定：过度设计
    ELSE '◐ 分层有益惟非悬殊——须标明所用口径，不得默认'                                                -- 分支判定：居中
  END                                                                    AS verdict_stratify        -- 条件分支：收束上方判词，产出「verdict_stratify」
FROM agg a                                                                                          -- 取数来源：取自本条自建的中间结果集 agg
CROSS JOIN glob gl;                                                                                 -- 交叉连接：单行对单行，令全局与分层同现一行


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-4 · commission 取值普查（★ 新增 · SC-2② 之实证底料）
-- ▸ 导出：需要 —— 存为「审计/_b4/_B4_4_commission_census.csv」（哨兵值登记底料）。
--   ★ 缘由：§M0-1 反推得 commission 有 8 种取值，其中 6 种共 31 笔系哨兵值。
--     其 μ0 达 −60%～−100%，若混入分母即污染。本条正面普查，供 §Z-10 登记。
--   ★ 判读：主值应仅 '0' 与 '1'；余者一律登记为哨兵值，并追其上游成因。
--   ★ 兼答一悬案：commission 之语义（0 系收佣抑或免佣？）须由本条与理论优势
--     对照后向上游确认——**实测 Banker comm=0 之 hold 为 1.2261%，高于标准
--     庄注理论优势 1.06% 达 0.1661pp**，故「comm=0 ＝ 标准收佣」之假设**存疑**，
--     禁在确认前据以命名。承 R4-SEMANTIC-02。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(commission)                                                       AS commission_value,       -- 取列：免佣标记原值
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该值之注单数
  COUNT(DISTINCT TRIM(bet05))                                            AS n_members,              -- 计数表达式：涉及会员数
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet_types,            -- 计数表达式：涉及注型数
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：首现分区日
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：末现分区日
  COUNT(DISTINCT dt)                                                     AS n_days,                 -- 计数表达式：出现天数
  CASE                                                                                              -- 条件分支：起始分支——判该值之性质
    WHEN TRIM(commission) IN ('0', '1')          THEN '★ 主值'                                       -- 分支判定：正常取值
    WHEN COUNT(*) < 100                          THEN '⚠ 哨兵值／脏数据——须追上游成因，禁入分母'        -- 分支判定：哨兵值
    ELSE '◐ 未登记之取值——须先定性再决定去留'                                                        -- 分支判定：待定
  END                                                                    AS verdict_commission      -- 条件分支：收束上方判词，产出「verdict_commission」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
GROUP BY TRIM(commission)                                                                           -- 分组：按免佣标记原值汇总
ORDER BY n_rows DESC, commission_value;                                                             -- 排序：按注单数降序排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §M0-5 · Tip_1_ 性质验证（★ 新增 · SC-2① 之实证）
-- ▸ 导出：不需要 —— §M0-5 性质读数，屏幕看结果。
--   ★ 缘由：bet09 = 'Tip_1_' 于 §M0-3 普查中现身（5,564 笔／521 会员），
--     惟未见于 §M0-1 —— 因其被 bet13 > 0 之过滤自然滤去。**此属侥幸，非设计。**
--     须正面验其性质：若 bet13 皆为零或空，即坐实其非投注，禁入 ROI 分母。
--   ★ 判读：
--     bet13 皆零／空 ∧ bet14 与 bet13 无赔付关系 → 确系小费，禁入分母
--     bet13 有正值                              → 须重验，或系另一种玩法
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet09 = Tip_1_'                                                       AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(bet05))                                            AS n_members,              -- 计数表达式：涉及会员数
  SUM(CASE WHEN NULLIF(TRIM(bet13), '') IS NULL THEN 1 ELSE 0 END)       AS n_bet13_blank,          -- 条件计数：本金为空者
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_bet13_zero, -- 条件计数：本金为零者
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_bet13_pos,  -- 条件计数：★ 本金为正者——若非零即须重验
  ROUND(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 2)          AS bet13_sum,              -- 汇总表达式：本金总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))), 2)          AS bet14_sum,              -- 汇总表达式：派彩总额
  COUNT(DISTINCT TRIM(commission))                                       AS n_commission,           -- 计数表达式：免佣标记取值数
  CASE                                                                                              -- 条件分支：起始分支——性质裁定
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) = 0
      THEN '✅ 本金皆零／空——确系小费非投注，禁入 ROI 分母'                                          -- 分支判定：确证
    ELSE '⚠ 有正本金——须重验其性质，不得径判为小费'                                                  -- 分支判定：须重验
  END                                                                    AS verdict_tip             -- 条件分支：收束上方判词，产出「verdict_tip」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(bet09) = 'Tip_1_';                                                                       -- 并列条件：限定小费注型


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（v1.0.1 新增三条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁六 · 小费非投注。
--   bet09 = 'Tip_1_' 系小费（member 表另有 tip 列为证），**禁入 stake 分母**。
--   v1.0.0 因 bet13 > 0 之过滤侥幸未污染，惟侥幸非设计；今立明文禁令。
--
-- 锁七 · commission 之语义未经确认，禁据以命名。
--   实测 Banker comm=0 之 hold ＝ 1.2261%，高于标准庄注理论优势 1.06% 达 0.1661pp；
--   而 comm=1 者为 1.2999%。方向虽合「免佣则庄优势升」，幅度却与 Super6 规则
--   之理论值（约 1.46%）不符。**故「comm=0 ＝ 标准收佣」仍属假设，非定谳。**
--   须向上游确认后方得命名——承 R4-SEMANTIC-02，本包已两犯，不犯第三次。
--
-- 锁八 · 单日单会员之新注型系上线测试，非业务事实。
--   2026-07-20 之七注型各 1 笔、同一会员、皆 10 元、ggr 皆为 0；
--   登记为**新玩法上线测试**，自分析中排除；惟**不得据此判该玩法不存在**——
--   其可能于窗外正式上线。承 R4-STAT-03 之「n 小不推 absence」。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
