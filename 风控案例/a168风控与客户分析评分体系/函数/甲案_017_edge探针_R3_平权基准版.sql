-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ 甲案 R3 · #017 bet09 注种级 edge 候选反解探针 · 平权基准版 · 只读 · 不落 Canonical ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【R2 报错修复】StarRocks 回：Unsupported nest window function inside aggregation（第 96~104 行）。
--   成因：overdispersion_Q 之算式把 SUM(...) OVER (PARTITION BY ...) 嵌在 SUM(...) 之内，StarRocks 不允许。
--   R3 改法：先以 grp CTE 求出各组加权均值，再以 qstat CTE 回接逐格算 Cochran Q，全程不嵌窗口函数。
--   同时把 CASE 内之相关子查询改为预聚合 ym_agg 后连接，避免相关子查询在聚合上下文重算。
-- 【R2 第二处斧正 —— 平权基准】先生已立基准：平权为准，加权须实测证实更优方可采。
--   R2 径以本金加权为主估计，违此基准，本版收回。R3 改为三估计式【并列出列】，由数据自行裁断：
--     ① hold_equal        平权 —— 各格等权，登记基准
--     ② hold_stake_pooled 本金加权 —— 候选
--     ③ hold_prec         精度倒数加权 n/σ̂² —— 候选
--   并出 estimator_max_reldev（三者最大相对差）。三者相近 ⇒ 加权无增益，维持平权；
--   三者显著分歧 ⇒ 须先解释分歧来源（格大小与 hold 相关？桌台异质？），方可议是否改用加权。
-- 【R1 判据全数作废】「任一格 hold < 0 ⇒ KILL」统计上不成立：格内 hold 之标准误 σ/√n，
--   以 Banker 计 σ≈0.927、格闸 n>=1000 时 SE≈2.93%，而真 edge 仅约 1.2% ⇒ 单格负值属抽样常态。
--   R1 之 20/26 KILL 判 INVALID_TEST_RESULT，不得作负 hold 之实证。hold_cell_min 降为诊断量。
-- 【#018 第三条证据撤回】product_code=105 属 bet02 别类，非百家乐域，不可作本域 edge 之反证。
--   #018 现存有效缺陷仅二：① bet02 ≠ bet09（粒度）② 无 month/table 切分。
-- 【commission 语义未知 —— 本轮最高优先阻断】
--   实测 commission=0 之 Banker hold 1.1633% ＞ commission=1 之 1.2027% 与规则方向矛盾：
--   若 1 确为免佣桌，edge 应升至约 1.46%，实测反低。故本版一律称 commission_flag，
--   并出 commission_semantics = 'UNKNOWN'，禁止下游按「免佣」解读。此链未闭合前，不得授权任何 edge。
-- 【禁令】只切 bet09 与 commission，严禁引入 bet03/bet04（靴号/靴内局序）。T-03 FATAL。
-- 【本探针不做】不产出 house_edge 定值 · 不写 edge_map · 不写 theo/adt/nmpt/esi · 不改任何生产判型。

WITH x_ranked AS (                                                                                  -- 定义 CTE：起始 —— 按注单主键去重，与总包逐字同构
  SELECT b.bet01, b.bet09, b.bet11, b.bet13, b.bet17, b.bet38, b.bet39,                             -- 直接取列：主键 / 注种 / 汇率 / 本金 / 净额 / 重对标记 / 桌号
         b.category, b.commission, b.dt, b.validbet, b.updatetime, b.sync_time,                     -- 直接取列：类别 / 佣金标记 / 账期 / 有效投注 / 更新 / 同步
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部，免出重复行
           PARTITION BY b.bet01                                                                     -- 分区键：注单主键
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS x_rn                    -- 排序键：取最新一版
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：注单事实表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：分析窗（139 营业日，用 dt 非 DATE(bet08)）
    AND b.bet02 = '101'                                                                             -- 过滤条件：百家乐产品域，全程锁定
    AND b.sync_time <= '2026-08-27 09:00:00'                                                        -- 过滤条件：快照水位，与总包三元锚同
),                                                                                                  -- 定义 CTE：收束 x_ranked
x_base AS (                                                                                         -- 定义 CTE：起始 —— 折原币、打佣金旗标、算每注回报率
  SELECT b.bet09                                                          AS bet09,                 -- 直接取列：注种
         CASE WHEN TRIM(b.commission) = '1' THEN 1 ELSE 0 END             AS commission_flag,       -- 条件分支：佣金旗标 —— ★ 语义未知，不得读作「免佣」
         SUBSTR(CAST(b.dt AS STRING), 1, 7)                               AS ym,                    -- 字符串取值：年月，跨月切分键
         b.bet39                                                          AS x_table,               -- 直接取列：桌号，跨桌切分键
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))                                            -- 数值取值：本金分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_stake,               -- 比率表达式：除汇率折回原币，产出「x_stake」
         CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))                                         -- 数值取值：洗码量分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_valid,               -- 比率表达式：除汇率折回原币，产出「x_valid」
         -CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))                                           -- 数值取值：平台净额分子（玩家净额取负）
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_house,               -- 比率表达式：除汇率折回原币，产出「x_house」
         -CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))                                           -- 数值取值：平台净额分子
           / NULLIF(CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)),0)    AS r_bet                  -- 比率表达式：★ 每注平台回报率 = −净额 ÷ 本金，抽样零模型之基本随机变量
  FROM x_ranked b                                                                                   -- 取数来源：取自去重后注单
  WHERE b.x_rn = 1                                                                                  -- 过滤条件：仅取每注单最新一版
    AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'                                             -- 过滤条件：正常类别且非重对单
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 过滤条件：汇率为正，杜绝除零
    AND CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)) > 0                                         -- 过滤条件：本金为正，杜绝除零
),                                                                                                  -- 定义 CTE：收束 x_base
cell AS (                                                                                           -- 定义 CTE：起始 —— 最细格：注种 × 佣金旗标 × 月 × 桌，并就地实测格内每注方差
  SELECT bet09, commission_flag, ym, x_table,                                                       -- 直接取列：四键
         COUNT(*)                                    AS n_bets,                                     -- 计数表达式：格内注单数
         SUM(x_stake)                                AS stake,                                      -- 聚合取值：格内本金
         SUM(x_valid)                                AS valid_bet,                                  -- 聚合取值：格内洗码量
         SUM(x_house)                                AS house_win,                                  -- 聚合取值：格内平台净赢
         SUM(x_house) / NULLIF(SUM(x_stake),0)       AS hold_cell,                                  -- 比率表达式：格内 observed hold
         STDDEV_SAMP(r_bet)                          AS sd_bet_cell                                 -- 聚合取值：★ 格内每注回报率标准差，抽样零模型之 σ̂，就地实测非假设
  FROM x_base                                                                                       -- 取数来源：取自折算后注单
  GROUP BY bet09, commission_flag, ym, x_table                                                      -- 分组子句：四键分组
),                                                                                                  -- 定义 CTE：收束 cell
cell_ok AS (                                                                                        -- 定义 CTE：起始 —— 证据闸 ＋ 逐格标准误 ＋ 精度权重
  SELECT c.bet09, c.commission_flag, c.ym, c.x_table, c.n_bets, c.stake, c.valid_bet,               -- 直接取列：承上
         c.house_win, c.hold_cell, c.sd_bet_cell,                                                   -- 直接取列：承上
         c.sd_bet_cell / SQRT(CAST(c.n_bets AS DOUBLE))                   AS se_cell,               -- 比率表达式：该格 hold 之抽样标准误 σ̂/√n，逐格现算
         CAST(c.n_bets AS DOUBLE) / NULLIF(POWER(c.sd_bet_cell,2),0)      AS w_cell                 -- 比率表达式：精度倒数权重 n/σ̂²（＝1/se²），候选估计式之权
  FROM cell c                                                                                        -- 取数来源：取自最细格
  WHERE c.n_bets >= 1000                                                                             -- 过滤条件：证据闸 —— 每格至少 1,000 注
    AND c.sd_bet_cell > 0                                                                            -- 过滤条件：格内须有变异，否则零模型无定义
),                                                                                                  -- 定义 CTE：收束 cell_ok
grp AS (                                                                                            -- 定义 CTE：起始 —— 组级一次聚合，供 Q 统计量回接（避免窗口函数嵌入聚合）
  SELECT bet09, commission_flag,                                                                    -- 直接取列：两键
         COUNT(*)                                    AS n_cells,                                    -- 计数表达式：达闸格数
         COUNT(DISTINCT ym)                          AS n_months,                                   -- 计数表达式：覆盖月数
         COUNT(DISTINCT x_table)                     AS n_tables,                                   -- 计数表达式：覆盖桌数
         SUM(n_bets)                                 AS n_bets_total,                               -- 聚合取值：总注单数
         SUM(stake)                                  AS stake_total,                                -- 聚合取值：总本金
         SUM(valid_bet)                              AS valid_bet_total,                            -- 聚合取值：总洗码量
         SUM(house_win)                              AS house_win_total,                            -- 聚合取值：总平台净赢
         AVG(hold_cell)                              AS hold_equal,                                 -- 聚合取值：★ 估计式① 平权（登记基准）
         STDDEV_SAMP(hold_cell)                      AS hold_equal_sd,                              -- 聚合取值：平权之格间标准差
         SUM(w_cell)                                 AS sum_w,                                      -- 聚合取值：权重合计，供估计式③ 与其半宽
         SUM(w_cell * hold_cell)                     AS sum_wh,                                     -- 聚合取值：加权和，供估计式③
         AVG(se_cell)                                AS se_cell_mean,                               -- 聚合取值：平均格内抽样标准误，对照格间离散
         MIN(hold_cell)                              AS hold_cell_min,                              -- 聚合取值：诊断量 —— 负值属抽样常态，非 KILL 依据
         MAX(hold_cell)                              AS hold_cell_max                               -- 聚合取值：诊断量
  FROM cell_ok                                                                                       -- 取数来源：取自达闸格
  GROUP BY bet09, commission_flag                                                                     -- 分组子句：两键分组
),                                                                                                  -- 定义 CTE：收束 grp
qstat AS (                                                                                          -- 定义 CTE：起始 —— Cochran 式异质性统计量，逐格回接组均值后聚合
  SELECT c.bet09, c.commission_flag,                                                                -- 直接取列：两键
         SUM(c.w_cell * POWER(c.hold_cell - g.sum_wh / NULLIF(g.sum_w,0), 2)) AS q_raw              -- 聚合取值：Q = Σ wᵢ(hᵢ − h̄_w)²，组均值由 grp 提供，故无窗口函数嵌套
  FROM cell_ok c                                                                                     -- 取数来源：取自达闸格
  JOIN grp g                                                                                         -- 内连接：接组级聚合
    ON g.bet09 = c.bet09 AND g.commission_flag = c.commission_flag                                   -- 连接条件：两键相等
  GROUP BY c.bet09, c.commission_flag                                                                -- 分组子句：两键分组
),                                                                                                  -- 定义 CTE：收束 qstat
ym_lvl AS (                                                                                         -- 定义 CTE：起始 —— 月级折叠，供符号稳定性判据
  SELECT bet09, commission_flag, ym,                                                                -- 直接取列：三键
         AVG(hold_cell)                              AS hold_ym_equal,                              -- 聚合取值：该月平权 hold（与基准同口径）
         SUM(house_win) / NULLIF(SUM(stake),0)       AS hold_ym_stake                               -- 比率表达式：该月本金加权 hold（候选口径，并列出列）
  FROM cell_ok                                                                                       -- 取数来源：取自达闸格
  GROUP BY bet09, commission_flag, ym                                                                -- 分组子句：三键分组
),                                                                                                  -- 定义 CTE：收束 ym_lvl
ym_agg AS (                                                                                         -- 定义 CTE：起始 —— 月级折叠再聚合，避免在 CASE 内用相关子查询
  SELECT bet09, commission_flag,                                                                    -- 直接取列：两键
         MIN(hold_ym_equal)                          AS hold_ym_equal_min,                          -- 聚合取值：逐月平权 hold 之最小值
         MIN(hold_ym_stake)                          AS hold_ym_stake_min,                          -- 聚合取值：逐月加权 hold 之最小值
         SUM(CASE WHEN hold_ym_equal <= 0 THEN 1 ELSE 0 END) AS n_months_nonpos_equal,              -- 聚合取值：平权口径下非正月数
         SUM(CASE WHEN hold_ym_stake <= 0 THEN 1 ELSE 0 END) AS n_months_nonpos_stake               -- 聚合取值：加权口径下非正月数
  FROM ym_lvl                                                                                        -- 取数来源：取自月级折叠
  GROUP BY bet09, commission_flag                                                                     -- 分组子句：两键分组
)                                                                                                    -- 定义 CTE：收束 ym_agg
SELECT                                                                                              -- 取列：起始取列子句
  g.bet09                                                                 AS bet09,                 -- 直接取列：注种
  g.commission_flag                                                       AS commission_flag,       -- 直接取列：佣金旗标
  'UNKNOWN'                                                               AS commission_semantics,  -- 字面取值：★ 语义未证实，禁止下游读作「免佣」
  g.n_bets_total                                                          AS n_bets_total,          -- 直接取列：总注单数
  ROUND(g.stake_total, 2)                                                 AS stake_total,           -- 数值取值：总本金
  ROUND(g.valid_bet_total, 2)                                             AS valid_bet_total,       -- 数值取值：总洗码量
  g.n_cells                                                               AS n_cells,               -- 直接取列：达闸格数
  g.n_months                                                              AS n_months,              -- 直接取列：覆盖月数
  g.n_tables                                                              AS n_tables,              -- 直接取列：覆盖桌数
  ROUND(g.hold_equal, 8)                                                  AS hold_equal,            -- 数值取值：★ 估计式① 平权（登记基准）
  ROUND(1.96 * g.hold_equal_sd / SQRT(CAST(g.n_cells AS DOUBLE)), 8)      AS hold_equal_ci_half,    -- 比率表达式：平权估计之 95% 半宽，逐行现算
  ROUND(g.house_win_total / NULLIF(g.stake_total,0), 8)                   AS hold_stake_pooled,     -- 比率表达式：估计式② 本金加权（候选）
  ROUND(g.sum_wh / NULLIF(g.sum_w,0), 8)                                  AS hold_prec,             -- 比率表达式：估计式③ 精度倒数加权（候选）
  ROUND(1.96 / SQRT(NULLIF(g.sum_w,0)), 8)                                AS hold_prec_ci_half,     -- 比率表达式：精度加权估计之 95% 半宽
  ROUND(GREATEST(ABS(g.hold_equal - g.house_win_total / NULLIF(g.stake_total,0)),                   -- 数值取值：起始 —— 三估计式两两之最大绝对差
                 ABS(g.hold_equal - g.sum_wh / NULLIF(g.sum_w,0)),                                  -- 数值取值：续
                 ABS(g.house_win_total / NULLIF(g.stake_total,0) - g.sum_wh / NULLIF(g.sum_w,0)))   -- 数值取值：续
        / NULLIF(ABS(g.hold_equal),0), 6)                                 AS estimator_max_reldev,  -- 比率表达式：★ 以平权为分母之最大相对分歧；小 ⇒ 加权无增益，维持平权
  ROUND(q.q_raw / NULLIF(CAST(g.n_cells - 1 AS DOUBLE),0), 6)             AS overdispersion_Q,      -- 比率表达式：★ Cochran Q/(k−1)。≈1 ⇒ 无额外异质之强证据；>>1 ⇒ 有格间异质，须查 regime/桌/月
  ROUND(g.se_cell_mean, 8)                                                AS se_cell_mean,          -- 数值取值：平均格内抽样标准误（诊断量）
  ROUND(g.hold_equal_sd, 8)                                               AS hold_cell_sd,          -- 数值取值：格间标准差（诊断量）
  ROUND(g.hold_cell_min, 8)                                               AS hold_cell_min,         -- 数值取值：诊断量 —— 负值属抽样常态，不再作 KILL 依据
  ROUND(g.hold_cell_max, 8)                                               AS hold_cell_max,         -- 数值取值：诊断量
  ROUND(y.hold_ym_equal_min, 8)                                           AS hold_ym_equal_min,     -- 数值取值：逐月平权 hold 最小值
  ROUND(y.hold_ym_stake_min, 8)                                           AS hold_ym_stake_min,     -- 数值取值：逐月加权 hold 最小值
  y.n_months_nonpos_equal                                                 AS n_months_nonpos_equal, -- 直接取列：平权口径非正月数
  y.n_months_nonpos_stake                                                 AS n_months_nonpos_stake, -- 直接取列：加权口径非正月数
  CASE WHEN g.n_cells < 30 OR g.n_months < 4 OR g.n_tables < 20                                     -- 条件分支：起始分支 —— 覆盖不足，无从判
         THEN 'L5_INSUFFICIENT_COVERAGE'                                                            -- 分支取值：覆盖不足
       WHEN y.n_months_nonpos_equal > 0                                                             -- 分支判定：判据③ 基准口径下有月级非正
         THEN 'SIGN_UNSTABLE_MONTHLY'                                                               -- 分支取值：月级符号不稳，须查规则或污染
       WHEN 1.96 * g.hold_equal_sd / SQRT(CAST(g.n_cells AS DOUBLE)) > 0.20 * ABS(g.hold_equal)     -- 分支判定：判据② 基准估计之半宽逾点估计两成
         THEN 'IMPRECISE_CI_GT_20PCT'                                                               -- 分支取值：精度不足
       ELSE 'EDGE_CANDIDATE_PENDING_RULE_SSOT' END                        AS verdict                -- 条件分支：收束判词 —— ★ 即便通过亦仅「候选」，须规则级 SSOT 背书
FROM grp g                                                                                          -- 取数来源：组级聚合
JOIN qstat q ON q.bet09 = g.bet09 AND q.commission_flag = g.commission_flag                          -- 内连接：接 Q 统计量
JOIN ym_agg y ON y.bet09 = g.bet09 AND y.commission_flag = g.commission_flag                         -- 内连接：接月级稳定性
ORDER BY g.stake_total DESC;                                                                        -- 排序子句：按本金降序，主力注种在前

-- ── §四、R3 判据（跑完对照，不得事后放宽）──
--   基准估计恒为 hold_equal（平权）。加权二式只作并列佐证，除非 estimator_max_reldev 显示分歧且
--   分歧来源经解释后证实加权更优，否则一律以平权入册。
--   ① 估计式一致性：estimator_max_reldev ≤ 0.10 ⇒ 加权无实质增益，维持平权基准
--   ② 异质性：overdispersion_Q ≈ 1 ⇒ 无额外异质之强证据（★ 非等于「theo 成立」）；
--              Q >> 1 ⇒ 有格间异质之证据（★ 非等于「theo 不存在」），须查 regime / 桌台 / 月份效应
--   ③ 符号稳定：n_months_nonpos_equal = 0 且 hold_ym_equal_min > 0
--   三支全过 ⇒ verdict = 'EDGE_CANDIDATE_PENDING_RULE_SSOT'，仅得进候选链，不得径填 edge_map。
-- ── §五、本探针权限之上限 ──
--   本探针至多把 observed_hold 推进到 EDGE_CANDIDATE_PENDING_RULE_SSOT，无权产生 theoretical_edge。
--   规则级权威仅三条：游戏规则文档 · 产品定义表 · 供应商契约。且规则值本身亦须锁血统：
--   rule_source · rule_version · effective_from · effective_to · product_variant · commission_regime。
--   数字吻合只能称 numerically consistent，不得称 rule-identified。
