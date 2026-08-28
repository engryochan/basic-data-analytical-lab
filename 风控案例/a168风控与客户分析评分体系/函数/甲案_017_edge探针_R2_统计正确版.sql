-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ 甲案 R2 · #017 bet09 注种级 edge 候选反解探针 · 统计正确版 · 只读 · 不落 Canonical ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【R1 自纠 · 2026-08-28】R1 已实跑（5.121 秒），但其判据有两处设计错误，判词全数作废，重跑本版：
--   错误一（致命）：以「任一格 hold_cell_min < 0 ⇒ KILL_NEGATIVE_HOLD」为判据，统计上不成立。
--     格内 hold 是随机变量，标准误 ≈ σ/√n_cell。以 Banker 计，σ≈0.927、格闸 n>=1000 时 SE≈2.93%，
--     而真实 edge 仅 1.16% ⇒ 真 edge 为正时，单格 hold 为负仍属常态。R1 实跑 20/26 判 KILL，全属误杀。
--   错误二：以未加权之 AVG/STDDEV 跨格聚合。各格 n 悬殊（最小 1,000，最大逾 20 万），
--     未加权统计被小格噪声主导。正解须以精度倒数加权，并与抽样零模型比对。
-- 【R2 之判据改为三支并用，CV 降为诊断量不再生杀】
--   ① 点估计偏差：hold_pooled（本金加权）与规则级理论值之相对偏差
--   ② 过度离散：格内 hold 之实际方差 ÷ 抽样零模型方差（Cochran 式），≈1 即纯抽样，>>1 即真异质
--   ③ 符号稳定：逐月 hold 之 95% 下界是否恒为正
-- 【R1 实跑所得，已足以推翻之结论】
--   Player 佣金桌 hold_pooled = 1.226380%，规则值 1.235100% ⇒ 相对偏差 −0.71%
--   Banker 佣金桌 hold_pooled = 1.163251%，规则值 1.057900% ⇒ 相对偏差 +9.96%
--   BPair 10.5315% / PPair 10.1567%，规则值 10.3614% ⇒ ±1.6~2.0%
--   26 行中 25 行之格均值 95% 下界 > 0；本金占比 >1% 者全部 > 0
--   另 #017 DX04 交付件 win_rate_base：庄 0.5066782（理论 0.5067885）、闲 0.4931331（理论 0.4932115），
--   偏差 1.1e-4 与 7.8e-5，於 n=4,600 万量级下约 1.5 个标准误 ⇒ 与理论不可区分。
-- 【禁令】只切 bet09 与 commission，严禁引入 bet03/bet04（靴号/靴内局序）。T-03 FATAL，不得借新指标复活。
-- 【本探针不做】不产出 house_edge 定值 · 不写 edge_map · 不改 HF9f-B · 不改任何生产判型。

WITH x_ranked AS (                                                                                  -- 定义 CTE：起始 —— 按注单主键去重，与总包逐字同构
  SELECT b.bet01, b.bet09, b.bet11, b.bet13, b.bet17, b.bet38, b.bet39,                             -- 直接取列：主键 / 注种 / 汇率 / 本金 / 净额 / 重对标记 / 桌号
         b.category, b.commission, b.dt, b.validbet, b.updatetime, b.sync_time,                     -- 直接取列：类别 / 免佣 / 账期 / 有效投注 / 更新 / 同步
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部，免出重复行
           PARTITION BY b.bet01                                                                     -- 分区键：注单主键
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS x_rn                    -- 排序键：取最新一版
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：注单事实表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：分析窗（139 营业日，用 dt 非 DATE(bet08)）
    AND b.bet02 = '101'                                                                             -- 过滤条件：百家乐产品域，全程锁定
    AND b.sync_time <= '2026-08-27 09:00:00'                                                        -- 过滤条件：快照水位，与总包三元锚同
),                                                                                                  -- 定义 CTE：收束 x_ranked
x_base AS (                                                                                         -- 定义 CTE：起始 —— 折原币、打免佣标记、算每注回报率
  SELECT b.bet09                                                          AS bet09,                 -- 直接取列：注种
         CASE WHEN TRIM(b.commission) = '1' THEN 1 ELSE 0 END             AS is_free_comm,          -- 条件分支：免佣标记（免佣桌庄注 6 点赢半赔，规则不同，须独立分层）
         SUBSTR(CAST(b.dt AS STRING), 1, 7)                               AS ym,                    -- 字符串取值：年月，跨月切分键
         b.bet39                                                          AS x_table,               -- 直接取列：桌号，跨桌切分键
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))                                            -- 数值取值：本金分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_stake,               -- 比率表达式：除汇率折回原币，产出「x_stake」
         CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))                                         -- 数值取值：洗码量分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_valid,               -- 比率表达式：除汇率折回原币，产出「x_valid」
         CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))                                            -- 数值取值：玩家净额分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_net,                 -- 比率表达式：除汇率折回原币，产出「x_net」（正＝玩家赢）
         -CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))                                           -- 数值取值：平台净额分子（取负）
           / NULLIF(CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)),0)    AS r_bet                  -- 比率表达式：★ 每注平台回报率 = −净额 ÷ 本金，抽样零模型之基本随机变量
  FROM x_ranked b                                                                                   -- 取数来源：取自去重后注单
  WHERE b.x_rn = 1                                                                                  -- 过滤条件：仅取每注单最新一版
    AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'                                             -- 过滤条件：正常类别且非重对单
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 过滤条件：汇率为正，杜绝除零
    AND CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)) > 0                                         -- 过滤条件：本金为正，杜绝除零
),                                                                                                  -- 定义 CTE：收束 x_base
cell AS (                                                                                           -- 定义 CTE：起始 —— 最细格：注种 × 免佣 × 月 × 桌，并就地算格内每注方差
  SELECT bet09, is_free_comm, ym, x_table,                                                          -- 直接取列：四键
         COUNT(*)                                    AS n_bets,                                     -- 计数表达式：格内注单数
         SUM(x_stake)                                AS stake,                                      -- 聚合取值：格内本金
         SUM(x_valid)                                AS valid_bet,                                  -- 聚合取值：格内洗码量
         SUM(-x_net)                                 AS house_win,                                  -- 聚合取值：格内平台净赢
         SUM(-x_net) / NULLIF(SUM(x_stake),0)        AS hold_cell,                                  -- 比率表达式：格内 observed hold
         STDDEV_SAMP(r_bet)                          AS sd_bet_cell                                 -- 聚合取值：★ 格内每注回报率之标准差，抽样零模型之 σ̂，就地实测非假设
  FROM x_base                                                                                       -- 取数来源：取自折算后注单
  GROUP BY bet09, is_free_comm, ym, x_table                                                         -- 分组子句：四键分组
),                                                                                                  -- 定义 CTE：收束 cell
cell_ok AS (                                                                                        -- 定义 CTE：起始 —— 证据闸 ＋ 逐格标准误 ＋ 精度权重
  SELECT c.*,                                                                                       -- 直接取列：承上全列
         c.sd_bet_cell / SQRT(CAST(c.n_bets AS DOUBLE))       AS se_cell,                           -- 比率表达式：该格 hold 之抽样标准误 σ̂/√n，逐格现算
         POWER(SQRT(CAST(c.n_bets AS DOUBLE)) / NULLIF(c.sd_bet_cell,0), 2) AS w_cell               -- 数值取值：精度倒数权重 = n/σ̂²，用以加权而非等权
  FROM cell c                                                                                        -- 取数来源：取自最细格
  WHERE c.n_bets >= 1000                                                                             -- 过滤条件：证据闸 —— 每格至少 1,000 注
    AND c.sd_bet_cell > 0                                                                            -- 过滤条件：格内须有变异，否则零模型无定义
),                                                                                                  -- 定义 CTE：收束 cell_ok
ym_lvl AS (                                                                                         -- 定义 CTE：起始 —— 月级折叠，供符号稳定性判据
  SELECT bet09, is_free_comm, ym,                                                                   -- 直接取列：三键
         SUM(house_win) / NULLIF(SUM(stake),0)       AS hold_ym                                     -- 比率表达式：该月本金加权 hold
  FROM cell_ok                                                                                       -- 取数来源：取自达闸格
  GROUP BY bet09, is_free_comm, ym                                                                   -- 分组子句：三键分组
)                                                                                                    -- 定义 CTE：收束 ym_lvl
SELECT                                                                                              -- 取列：起始取列子句
  k.bet09                                                                 AS bet09,                 -- 直接取列：注种
  k.is_free_comm                                                          AS is_free_comm,          -- 直接取列：免佣标记
  SUM(k.n_bets)                                                           AS n_bets_total,          -- 聚合取值：总注单数
  ROUND(SUM(k.stake), 2)                                                  AS stake_total,           -- 聚合取值：总本金
  COUNT(*)                                                                AS n_cells,               -- 计数表达式：达闸格数
  COUNT(DISTINCT k.ym)                                                    AS n_months,              -- 计数表达式：覆盖月数
  COUNT(DISTINCT k.x_table)                                               AS n_tables,              -- 计数表达式：覆盖桌数
  ROUND(SUM(k.house_win) / NULLIF(SUM(k.stake),0), 8)                     AS hold_pooled,           -- 比率表达式：★ 判据① 本金加权点估计
  ROUND(SUM(k.w_cell * k.hold_cell) / NULLIF(SUM(k.w_cell),0), 8)         AS hold_prec_weighted,    -- 比率表达式：精度加权点估计，与 hold_pooled 互为佐证
  ROUND(1.96 / SQRT(NULLIF(SUM(k.w_cell),0)), 8)                          AS hold_ci_halfwidth,     -- 比率表达式：精度加权估计之 95% 半宽，逐行现算
  ROUND(SUM(k.w_cell * POWER(k.hold_cell - SUM(k.w_cell * k.hold_cell) OVER (PARTITION BY k.bet09, k.is_free_comm) / NULLIF(SUM(k.w_cell) OVER (PARTITION BY k.bet09, k.is_free_comm),0), 2)) / NULLIF(COUNT(*) - 1, 0), 8) AS overdispersion_Q,  -- 比率表达式：★ 判据② Cochran 式过度离散 Q/(k−1)，≈1 即纯抽样，>>1 即真异质
  ROUND(AVG(k.se_cell), 8)                                                AS se_cell_mean,          -- 聚合取值：平均格内抽样标准误，用以对照格间离散
  ROUND(STDDEV_SAMP(k.hold_cell), 8)                                      AS hold_cell_sd,          -- 聚合取值：格间离散（诊断量，非判据）
  ROUND(MIN(k.hold_cell), 8)                                              AS hold_cell_min,         -- 聚合取值：★ 诊断量 —— 负值属抽样常态，不再作 KILL 依据
  ROUND(MAX(k.hold_cell), 8)                                              AS hold_cell_max,         -- 聚合取值：诊断量
  (SELECT MIN(y.hold_ym) FROM ym_lvl y WHERE y.bet09 = k.bet09 AND y.is_free_comm = k.is_free_comm) AS hold_ym_min,  -- 子查询取值：★ 判据③ 逐月 hold 之最小值，月级方为符号稳定性之合理粒度
  (SELECT COUNT(*) FROM ym_lvl y WHERE y.bet09 = k.bet09 AND y.is_free_comm = k.is_free_comm AND y.hold_ym <= 0) AS n_months_nonpos, -- 子查询取值：判据③ 非正月数
  CASE WHEN COUNT(*) < 30 OR COUNT(DISTINCT k.ym) < 4 OR COUNT(DISTINCT k.x_table) < 20             -- 条件分支：起始分支 —— 覆盖不足，无从判
         THEN 'L5_INSUFFICIENT_COVERAGE'                                                            -- 分支取值：覆盖不足
       WHEN (SELECT COUNT(*) FROM ym_lvl y WHERE y.bet09 = k.bet09 AND y.is_free_comm = k.is_free_comm AND y.hold_ym <= 0) > 0  -- 分支判定：判据③ 有月级非正
         THEN 'SIGN_UNSTABLE_MONTHLY'                                                               -- 分支取值：月级符号不稳，须查规则或污染
       WHEN 1.96 / SQRT(NULLIF(SUM(k.w_cell),0)) > 0.20 * ABS(SUM(k.house_win) / NULLIF(SUM(k.stake),0))  -- 分支判定：半宽逾点估计之两成
         THEN 'IMPRECISE_CI_GT_20PCT'                                                               -- 分支取值：精度不足
       ELSE 'EDGE_CANDIDATE_PENDING_RULE_SSOT' END                        AS verdict                -- 条件分支：收束判词 —— ★ 即便通过，仍只是「候选」，须规则级 SSOT 背书方得为 edge
FROM cell_ok k                                                                                      -- 取数来源：取自达闸格
GROUP BY k.bet09, k.is_free_comm                                                                    -- 分组子句：按注种 × 免佣 汇总
ORDER BY SUM(k.stake) DESC;                                                                         -- 排序子句：按本金降序，主力注种在前

-- ── §四、R2 判据（跑完对照，不得事后放宽）──
--   ① 点估计：hold_pooled 与 hold_prec_weighted 二者相对差 ≤ 10% ⇒ 估计式稳健
--   ② 过度离散：overdispersion_Q ≈ 1 ⇒ 格间差异纯属抽样；Q >> 1 ⇒ 存在桌台/月份真异质，须建随机效应模型
--   ③ 符号稳定：n_months_nonpos = 0 且 hold_ym_min > 0 ⇒ 月级恒正
--   三支全过且 verdict = 'EDGE_CANDIDATE_PENDING_RULE_SSOT' ⇒ 可进候选链，但仍不得径填 edge_map。
-- ── §五、判词命名之所以带 PENDING_RULE_SSOT ──
--   observed hold 纵使稳定，仍是「结果」而非「规则」。规则级 edge 之权威来源只有三条：
--     游戏规则文档 · 产品定义表 · 供应商契约。数据只能提供候选值与一致性佐证，不能自证为规则。
--   故本探针最好之结果，也只到「候选值与规则值一致」，而非「由数据定义规则」。
