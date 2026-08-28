-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ 甲案 · #017 bet09 注种级 edge 候选反解探针 · 只读 · 单件 · 不落 Canonical ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【为何不用 #018】实测 DX05_product_panorama.csv 三条硬伤，不能承担本探针：
--   ① 粒度错：其 product_code = r.bet02（游戏类别 101/102/…/5031），非 bet09（注种）。theo 需要注种级 edge。
--   ② 无切分：全窗口 8 行聚合，无月份、无桌台维，稳定性检定无从跑起。
--   ③ 实证反例：product_code=105 之 house_hold_pct = -0.009569（负值）。理论庄家优势不可能为负，
--      故 observed hold 必含玩家行为与样本噪声，observed hold ≠ theoretical edge 由此实测坐实。
-- 【另附实测缺陷】#018 之六层连接键错配：x_agg.x_key = s.x_product（bet09），而 q.product_code = r.bet02，
--   两键分属不同字段族，永不相等 ⇒ 交付件 141 列中 127 列恒 NULL。已立案 G-05。
-- 【本探针之目标】不是产出 house_edge，而只回答一问：
--   「bet09 × 免佣 之 observed hold，是否具备跨月 × 跨桌台之稳定性，值得进入 theoretical-edge 候选链？」
-- 【判据】见档尾 §四。不达标即封死此路，另寻规则级 edge SSOT。
-- 【禁令】本探针只切 bet09（注种）与 commission（免佣），严禁引入 bet03/bet04（靴号/靴内局序）。
--   尾段投注假说已四检证伪（sign p=0.7591 · Wilcoxon p=0.8087 · 九门槛零命中 · L1a AUC=0.3828 反向），T-03 FATAL。

WITH x_ranked AS (                                                                                  -- 定义 CTE：起始 —— 按注单主键去重，与总包 #075/#017 逐字同构
  SELECT b.bet01, b.bet03, b.bet09, b.bet11, b.bet13, b.bet17, b.bet38, b.bet39,                    -- 直接取列：主键 / 靴号 / 注种 / 汇率 / 本金 / 净额 / 重对标记 / 桌号
         b.category, b.commission, b.dt, b.validbet, b.updatetime, b.sync_time,                     -- 直接取列：类别 / 免佣 / 账期 / 有效投注 / 更新时间 / 同步时间
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部，免出重复行
           PARTITION BY b.bet01                                                                     -- 分区键：注单主键
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS x_rn                    -- 排序键：取最新一版
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：注单事实表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：分析窗（139 个营业日，用 dt 非 DATE(bet08)）
    AND b.bet02 = '101'                                                                             -- 过滤条件：百家乐产品域，全程锁定
    AND b.sync_time <= '2026-08-27 09:00:00'                                                        -- 过滤条件：快照水位，与总包三元锚同
),                                                                                                  -- 定义 CTE：收束 x_ranked
x_base AS (                                                                                         -- 定义 CTE：起始 —— 折算原币并打免佣标记
  SELECT b.bet09                                                          AS bet09,                 -- 直接取列：注种（庄/闲/和/对子等）
         CASE WHEN TRIM(b.commission) = '1' THEN 1 ELSE 0 END             AS is_free_comm,          -- 条件分支：免佣标记，免佣桌庄注规则不同（6 点赢半赔），须独立分层
         SUBSTR(CAST(b.dt AS STRING), 1, 7)                               AS ym,                    -- 字符串取值：年月，跨月稳定性之切分键
         b.bet39                                                          AS x_table,               -- 直接取列：桌号，跨桌台稳定性之切分键
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))                                            -- 数值取值：本金分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_stake,               -- 比率表达式：除以汇率折回原币，产出「x_stake」
         CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))                                         -- 数值取值：洗码量分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_valid,               -- 比率表达式：除以汇率折回原币，产出「x_valid」
         CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))                                            -- 数值取值：玩家净额分子
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS x_net                  -- 比率表达式：除以汇率折回原币，产出「x_net」（正＝玩家赢）
  FROM x_ranked b                                                                                   -- 取数来源：取自去重后注单
  WHERE b.x_rn = 1                                                                                  -- 过滤条件：仅取每注单最新一版
    AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'                                             -- 过滤条件：正常类别且非重对单
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 过滤条件：汇率为正，杜绝除零
),                                                                                                  -- 定义 CTE：收束 x_base
cell AS (                                                                                           -- 定义 CTE：起始 —— 最细格：注种 × 免佣 × 月 × 桌
  SELECT bet09, is_free_comm, ym, x_table,                                                          -- 直接取列：四键
         COUNT(*)                                    AS n_bets,                                     -- 计数表达式：该格注单数
         SUM(x_stake)                                AS stake,                                      -- 聚合取值：该格本金
         SUM(x_valid)                                AS valid_bet,                                  -- 聚合取值：该格洗码量
         SUM(-x_net)                                 AS house_win                                   -- 聚合取值：平台净赢（玩家净额取负）
  FROM x_base                                                                                       -- 取数来源：取自折算后注单
  GROUP BY bet09, is_free_comm, ym, x_table                                                         -- 分组子句：四键分组
),                                                                                                  -- 定义 CTE：收束 cell
cell_ok AS (                                                                                        -- 定义 CTE：起始 —— 证据闸：格内注单数不足者不参与离散度
  SELECT c.*,                                                                                       -- 直接取列：承上全列
         c.house_win / NULLIF(c.stake,0)             AS hold_cell                                   -- 比率表达式：该格 observed hold（以本金为分母，与 #018 house_hold_pct 同口径）
  FROM cell c                                                                                        -- 取数来源：取自最细格
  WHERE c.n_bets >= 1000                                                                             -- 过滤条件：★ 证据闸 —— 每格至少 1,000 注方计入离散度，避免以噪声算方差
)                                                                                                    -- 定义 CTE：收束 cell_ok
SELECT                                                                                              -- 取列：起始取列子句
  k.bet09                                                                 AS bet09,                 -- 直接取列：注种
  k.is_free_comm                                                          AS is_free_comm,          -- 直接取列：免佣标记
  SUM(k.n_bets)                                                           AS n_bets_total,          -- 聚合取值：该注种总注单数
  ROUND(SUM(k.stake), 2)                                                  AS stake_total,           -- 聚合取值：该注种总本金
  ROUND(SUM(k.valid_bet), 2)                                              AS valid_bet_total,       -- 聚合取值：该注种总洗码量
  ROUND(SUM(k.house_win), 2)                                              AS house_win_total,       -- 聚合取值：该注种平台总净赢
  ROUND(SUM(k.house_win) / NULLIF(SUM(k.stake),0), 8)                     AS hold_pooled,           -- 比率表达式：合并 observed hold，edge 之候选点估计
  COUNT(*)                                                                AS n_cells,               -- 计数表达式：达闸格数（月 × 桌）
  COUNT(DISTINCT k.ym)                                                    AS n_months,              -- 计数表达式：覆盖月份数
  COUNT(DISTINCT k.x_table)                                               AS n_tables,              -- 计数表达式：覆盖桌台数
  ROUND(AVG(k.hold_cell), 8)                                              AS hold_cell_mean,        -- 聚合取值：格内 hold 之均值
  ROUND(STDDEV_SAMP(k.hold_cell), 8)                                      AS hold_cell_sd,          -- 聚合取值：格内 hold 之标准差 —— 稳定性之主判据
  ROUND(MIN(k.hold_cell), 8)                                              AS hold_cell_min,         -- 聚合取值：格内 hold 之最小值 —— 若为负则理论 edge 解释被证伪
  ROUND(MAX(k.hold_cell), 8)                                              AS hold_cell_max,         -- 聚合取值：格内 hold 之最大值
  ROUND(STDDEV_SAMP(k.hold_cell) / NULLIF(ABS(AVG(k.hold_cell)),0), 8)    AS hold_cv,               -- 比率表达式：变异系数 —— 判据一之量，越小越稳
  ROUND(1.96 * STDDEV_SAMP(k.hold_cell) / SQRT(COUNT(*)), 8)              AS hold_ci_halfwidth,     -- 比率表达式：均值之 95% 半宽，逐行现算
  CASE WHEN COUNT(*) < 30 THEN 'L5_INSUFFICIENT_CELLS'                                              -- 条件分支：起始分支 —— 格数不足，稳定性无从判
       WHEN MIN(k.hold_cell) < 0 THEN 'KILL_NEGATIVE_HOLD'                                          -- 分支判定：出现负 hold ⇒ 非理论 edge，封死
       WHEN STDDEV_SAMP(k.hold_cell) / NULLIF(ABS(AVG(k.hold_cell)),0) > 0.50 THEN 'UNSTABLE_CV_GT_50PCT'  -- 分支判定：CV 逾 50% ⇒ 不稳
       WHEN STDDEV_SAMP(k.hold_cell) / NULLIF(ABS(AVG(k.hold_cell)),0) > 0.20 THEN 'MARGINAL_CV_20_50PCT'  -- 分支判定：CV 介 20%~50% ⇒ 勉强
       ELSE 'EDGE_CANDIDATE' END                                          AS verdict                -- 条件分支：收束判词，产出「verdict」
FROM cell_ok k                                                                                      -- 取数来源：取自达闸格
GROUP BY k.bet09, k.is_free_comm                                                                    -- 分组子句：按注种 × 免佣 汇总
ORDER BY SUM(k.stake) DESC;                                                                         -- 排序子句：按本金降序，主力注种在前

-- ── §四、判据（跑完对照，不得事后放宽）──
--   PASS（可进候选链）：verdict = 'EDGE_CANDIDATE' 且 n_months >= 4 且 n_tables >= 20 且 n_cells >= 30
--   MARGINAL：CV 介 20%~50% —— 只可作先验，不可作 theo 之定值；须补桌台随机效应模型后再议
--   KILL：任一注种 hold_cell_min < 0 —— 理论庄家优势不可能为负，observed hold 之 edge 解释即告证伪
--   若主力注种（本金占比 > 50% 者）落入 KILL 或 UNSTABLE，则整条 observed-hold → edge 路径封死，
--   theo 须另寻规则级 SSOT（游戏规则文档 / 产品定义表 / 供应商契约），不得由数据反解。
-- ── §五、本探针不做之事 ──
--   不产出 house_edge 定值 · 不写入 edge_map · 不修改 HF9f-B · 不落 Canonical · 不改任何生产判型。
