-- ══════════════════════════════════════════════════════════════════════════
-- §76 · 靴长分母核验（核验类，非取数类）
-- ══════════════════════════════════════════════════════════════════════════
-- 用途：关闭在册 P0 阻断项「权威靴长表待表」——判 MAX(round_no) 系物理靴长
--       抑或被低估之观测值；并量化跨桌切牌规程异质对 shoe_pos 之影响。
-- 关系：本节核验 §R01 之坐标系分母。§R01 头注须加回指「本节分母之核验见 §76」，
--       两侧互相登记，缺一即血统断裂。
-- 段号：★ 待授权 ★ §75 已预注册予他件，本节顺位其后暂取 §76；
--       正式段号以登记册变更单（v1.5.0 → v1.6.0）为准，本文件不代行登记。
-- 口径：CTE test_agents / ranked / base 沿用 §R01 原文；
--       ★ 唯一改动＝ranked 与 base 增列 b.dt（投影增列，筛选条件一字未改）。
--       增 dt 之故：靴号粒度须验跨日复用，无 dt 即无从验（§76.0）。
-- 纪律：行注释 only（块注释内之分号／斜杠致 StarRocks 语句终止符误判）；
--       无 OFFSET（曾致 36.49% 重复行）；varchar ID 一律 CAST；
--       NULLIF 零除守门；窗口字面量用 dt 不用 DATE(bet08)。
-- 交付：D01_shoe_grain.csv／D02_shoe_len_by_table.csv／D03_shoe_len_overall.csv／
--       D04_shoe_anomaly.csv（四件，皆 GBK/GB18030 导出，报告侧读入须显式指定）
-- 裁定纪律：★ 本节任何结果皆不得复活 T-03 ★——若 50 局系真靴长，则 0.80 量的
--       就是靴尾而其已被四项独立检验证伪；若系低估，则该判据连自身所称之物
--       都未曾测过，证伪只会更彻底。本节能改的只有 shoe_pos 坐标系之判级。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §76.0 · 靴号粒度验证：bet03 是否跨日复用（前置闸，未过则 §76.1 起全部作废）
-- 导出：数据库/D01_shoe_grain.csv
-- 判读：pct_cross_day > 0 即证 bet03 系日内／场次循环序号，
--       则 (shoe_id, table_id) 粒度会把不同日之同号靴合并，MAX(round_no)
--       被系统性**夸大**——诊断结论反转，正确粒度须补 dt。
-- ──────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'                                        -- 铁律④b：公司测试线
),
ranked AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet38, b.bet39, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.bet01                                         AS bet_id,
         r.dt                                            AS dt,
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')      AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')      AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
grain AS (
  SELECT shoe_id, table_id,
         COUNT(DISTINCT dt)  AS n_days,
         MIN(dt)             AS dt_min,
         MAX(dt)             AS dt_max,
         MAX(round_no)       AS max_round_old_grain
  FROM base
  GROUP BY shoe_id, table_id
)
SELECT
  COUNT(*)                                                       AS n_shoe_table_old,
  SUM(CASE WHEN n_days > 1 THEN 1 ELSE 0 END)                    AS n_cross_day,
  ROUND(SUM(CASE WHEN n_days > 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                AS pct_cross_day,
  MAX(n_days)                                                    AS max_days_per_shoe,
  ROUND(AVG(n_days), 6)                                          AS avg_days_per_shoe,
  -- 夸大之直接证据：跨日者其 old-grain 最大局号
  ROUND(AVG(CASE WHEN n_days > 1 THEN max_round_old_grain END), 4) AS avg_maxround_crossday,
  ROUND(AVG(CASE WHEN n_days = 1 THEN max_round_old_grain END), 4) AS avg_maxround_singleday,
  MAX(CASE WHEN n_days > 1 THEN max_round_old_grain END)           AS peak_maxround_crossday,
  -- 哨兵占比：空串靴号／桌号之比重（零行亦须明示，缺档不是无内容）
  SUM(CASE WHEN shoe_id  = '(空)' THEN 1 ELSE 0 END)             AS n_shoe_sentinel,
  SUM(CASE WHEN table_id = '(空)' THEN 1 ELSE 0 END)             AS n_table_sentinel
FROM grain;


-- ──────────────────────────────────────────────────────────────────────────
-- §76.1 · 逐桌汇总：新旧两粒度并报 ＋ Fisher-z 相关系数区间
-- 导出：数据库/D02_shoe_len_by_table.csv
-- ★ 无 LIMIT：Superset 默认截断显示行数，导出前须确认总桌数与结果行数一致 ★
-- 判读三处：
--   ① corr_density 之 95% CI 跨 0 ⇒ 方向不可读，禁以点估计下结论；
--      CI 不跨 0 且显著为正 ⇒ 分母低估坐实；近零或为负 ⇒ 物理规程。
--   ② ceiling_observed 若远逾 p99（如 2 倍），系靴号碰撞／跨日合并之指纹。
--   ③ avg_max_round 逐桌系统性不同 ⇒ 切牌规程异质，同一 shoe_pos 在不同桌
--      对应之牌深不同——此为跨桌可比性问题，比阈值定在何处更要命。
-- ──────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet38, b.bet39, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.bet01                                         AS bet_id,
         r.dt                                            AS dt,
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')      AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')      AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
-- 新粒度（正确）：(dt, table_id, shoe_id)——靴号跨日复用亦不致合并
shoe_new AS (
  SELECT dt, table_id, shoe_id,
         MAX(round_no)                                        AS max_round,
         COUNT(DISTINCT round_no)                             AS rounds_with_bet,
         MAX(round_no) - COUNT(DISTINCT round_no)             AS gap,
         COUNT(DISTINCT member_id)                            AS n_bettors,
         COUNT(*)                                             AS n_bets,
         COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT round_no), 0) AS bets_per_round
  FROM base
  GROUP BY dt, table_id, shoe_id
),
-- 旧粒度（现行）：(table_id, shoe_id)——留作对照，差异即粒度污染之量
shoe_old AS (
  SELECT table_id, shoe_id,
         MAX(round_no) AS max_round_old
  FROM base
  GROUP BY table_id, shoe_id
),
agg AS (
  SELECT table_id,
         COUNT(*)                                     AS n_shoes,
         AVG(max_round)                               AS avg_max_round,
         STDDEV_SAMP(max_round)                       AS sd_max_round,
         MIN(max_round)                               AS min_max_round,
         MAX(max_round)                               AS ceiling_observed,
         PERCENTILE_APPROX(max_round, 0.50)           AS p50_max_round,
         PERCENTILE_APPROX(max_round, 0.90)           AS p90_max_round,
         PERCENTILE_APPROX(max_round, 0.99)           AS p99_max_round,
         AVG(gap)                                     AS avg_gap,
         AVG(n_bettors)                               AS avg_n_bettors,
         AVG(bets_per_round)                          AS avg_bets_per_round,
         CORR(max_round, bets_per_round)              AS r_density,
         CORR(max_round, n_bettors)                   AS r_bettors,
         SUM(CASE WHEN max_round <= 5 THEN 1 ELSE 0 END) AS n_stub_shoes
  FROM shoe_new
  GROUP BY table_id
),
agg_old AS (
  SELECT table_id,
         COUNT(*)           AS n_shoes_old,
         AVG(max_round_old) AS avg_max_round_old,
         MAX(max_round_old) AS ceiling_old
  FROM shoe_old
  GROUP BY table_id
),
-- Fisher-z 变换：r → z ＝ 0.5·ln((1+r)/(1−r))，se ＝ 1/√(n−3)
-- 反变换 tanh(x) ＝ (e^{2x}−1)/(e^{2x}+1)；n ≤ 3 或 |r| → 1 者归 NULL 照登
zc AS (
  SELECT a.*,
         CASE WHEN a.n_shoes > 3 AND ABS(a.r_density) < 0.999999
              THEN 0.5 * LN((1 + a.r_density) / (1 - a.r_density)) END AS z_d,
         CASE WHEN a.n_shoes > 3 AND ABS(a.r_bettors) < 0.999999
              THEN 0.5 * LN((1 + a.r_bettors) / (1 - a.r_bettors)) END AS z_b,
         CASE WHEN a.n_shoes > 3
              THEN 1.959964 / SQRT(a.n_shoes - 3) END                  AS hw
  FROM agg a
)
SELECT
  z.table_id,
  CASE WHEN z.table_id = '(空)' THEN '⚠️ 哨兵（禁并入正常桌）' ELSE '正常' END AS table_flag,
  z.n_shoes,
  o.n_shoes_old,
  z.n_shoes - o.n_shoes_old                                    AS n_shoes_delta,  -- >0 即证跨日复用
  ROUND(z.avg_max_round, 4)                                    AS avg_max_round,
  ROUND(o.avg_max_round_old, 4)                                AS avg_max_round_old,
  ROUND(o.avg_max_round_old - z.avg_max_round, 4)              AS avg_maxround_inflation,
  ROUND(z.sd_max_round, 4)                                     AS sd_max_round,
  z.min_max_round,
  z.ceiling_observed,
  o.ceiling_old,
  ROUND(z.p50_max_round, 2)                                    AS p50_max_round,
  ROUND(z.p90_max_round, 2)                                    AS p90_max_round,
  ROUND(z.p99_max_round, 2)                                    AS p99_max_round,
  -- 碰撞指纹：ceiling 逾 p99 之 1.5 倍者，靴号碰撞或跨日合并高度可疑
  CASE WHEN z.ceiling_observed > z.p99_max_round * 1.5
       THEN '⚠️ 碰撞可疑' ELSE '—' END                          AS collision_flag,
  z.n_stub_shoes,                                              -- max_round ≤ 5 之残靴数
  ROUND(z.avg_gap, 4)                                          AS avg_gap,
  ROUND(z.avg_n_bettors, 4)                                    AS avg_n_bettors,
  ROUND(z.avg_bets_per_round, 4)                               AS avg_bets_per_round,
  -- 0.80 阈值在本桌对应之起始局号（跨桌可比性之直接刻度）
  ROUND(0.80 * z.avg_max_round, 2)                             AS round_at_pos080,
  ROUND(z.r_density, 6)                                        AS corr_len_density,
  ROUND((EXP(2*(z.z_d - z.hw)) - 1) / (EXP(2*(z.z_d - z.hw)) + 1), 6) AS corr_density_lo95,
  ROUND((EXP(2*(z.z_d + z.hw)) - 1) / (EXP(2*(z.z_d + z.hw)) + 1), 6) AS corr_density_hi95,
  CASE
    WHEN z.z_d IS NULL THEN '○ n 不足（须 > 3）'
    WHEN ((EXP(2*(z.z_d - z.hw)) - 1) / (EXP(2*(z.z_d - z.hw)) + 1)) <= 0
     AND ((EXP(2*(z.z_d + z.hw)) - 1) / (EXP(2*(z.z_d + z.hw)) + 1)) >= 0
      THEN 'CI 跨 0：方向不可读'
    WHEN ((EXP(2*(z.z_d - z.hw)) - 1) / (EXP(2*(z.z_d - z.hw)) + 1)) > 0
      THEN 'CI > 0：低估假说得证'
    ELSE 'CI < 0：与低估假说反向'
  END                                                          AS corr_density_verdict,
  ROUND(z.r_bettors, 6)                                        AS corr_len_bettors,
  ROUND((EXP(2*(z.z_b - z.hw)) - 1) / (EXP(2*(z.z_b - z.hw)) + 1), 6) AS corr_bettors_lo95,
  ROUND((EXP(2*(z.z_b + z.hw)) - 1) / (EXP(2*(z.z_b + z.hw)) + 1), 6) AS corr_bettors_hi95
FROM zc z
LEFT JOIN agg_old o ON o.table_id = z.table_id
ORDER BY z.avg_max_round DESC, z.table_id;                     -- 导出必带确定性排序


-- ──────────────────────────────────────────────────────────────────────────
-- §76.2 · 全域分布 ＋ 跨桌相关（判「物理硬顶」与「规程异质」）
-- 导出：数据库/D03_shoe_len_overall.csv
-- 前置：test_agents / ranked / base / shoe_new 四段同 §76.1，逐字沿用
-- 判读：n_len_ge_70 ＝ 0 且 p99 封于某值 ⇒ 切牌收靴之硬指纹，物理上限存在；
--       corr_cross_table 显著为负 ⇒ 密桌反而靴短，与低估假说反向，规程异质坐实。
-- ──────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11, b.bet38, b.bet39,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.dt                                            AS dt,
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')      AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')      AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
shoe_new AS (
  SELECT dt, table_id, shoe_id,
         MAX(round_no)                                        AS max_round,
         COUNT(DISTINCT round_no)                             AS rounds_with_bet,
         MAX(round_no) - COUNT(DISTINCT round_no)             AS gap,
         COUNT(DISTINCT member_id)                            AS n_bettors,
         COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT round_no), 0) AS bets_per_round
  FROM base
  GROUP BY dt, table_id, shoe_id
),
tbl AS (                                                   -- 跨桌相关之单位＝桌
  SELECT table_id,
         COUNT(*)                AS n_shoes,
         AVG(max_round)          AS avg_len,
         AVG(bets_per_round)     AS avg_density
  FROM shoe_new
  GROUP BY table_id
)
SELECT
  (SELECT COUNT(*) FROM tbl)                                   AS n_tables,
  COUNT(*)                                                     AS n_shoes,
  ROUND(AVG(max_round), 4)                                     AS mean_len,
  ROUND(STDDEV_SAMP(max_round), 4)                             AS sd_len,
  MIN(max_round)                                               AS p0,
  ROUND(PERCENTILE_APPROX(max_round, 0.01), 2)                 AS p01,
  ROUND(PERCENTILE_APPROX(max_round, 0.25), 2)                 AS p25,
  ROUND(PERCENTILE_APPROX(max_round, 0.50), 2)                 AS p50,
  ROUND(PERCENTILE_APPROX(max_round, 0.75), 2)                 AS p75,
  ROUND(PERCENTILE_APPROX(max_round, 0.90), 2)                 AS p90,
  ROUND(PERCENTILE_APPROX(max_round, 0.99), 2)                 AS p99,
  MAX(max_round)                                               AS p100,
  SUM(CASE WHEN max_round >= 70 THEN 1 ELSE 0 END)             AS n_len_ge_70,
  SUM(CASE WHEN max_round <= 5  THEN 1 ELSE 0 END)             AS n_len_le_5,
  ROUND(SUM(CASE WHEN gap > 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                              AS pct_with_gap,
  ROUND(AVG(gap), 4)                                           AS avg_gap,
  -- 跨桌相关：单位＝桌（非靴），故与 §76.1 之桌内相关不可混为一谈
  ROUND((SELECT CORR(avg_density, avg_len) FROM tbl), 6)       AS corr_cross_table,
  -- 规程异质刻度：0.80 阈值在最短桌与最长桌各对应第几局
  ROUND(0.80 * (SELECT MIN(avg_len) FROM tbl), 2)              AS round_at_080_shortest,
  ROUND(0.80 * (SELECT MAX(avg_len) FROM tbl), 2)              AS round_at_080_longest
FROM shoe_new;


-- ──────────────────────────────────────────────────────────────────────────
-- §76.3 · 异常靴清单（碰撞与残靴之逐行证据；查账在先、查人在后）
-- 导出：数据库/D04_shoe_anomaly.csv
-- 前置：test_agents / ranked / base / shoe_new 四段同 §76.2，逐字沿用
-- 用途：为「ceiling 远逾 p99」与「max_round ≤ 5」两类逐行留证，供账务侧核单。
--       ★ 此清单系账务对象，非会员对象；禁作任何风控判据之输入 ★
-- ──────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11, b.bet38, b.bet39,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.dt                                            AS dt,
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')      AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')      AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
shoe_new AS (
  SELECT dt, table_id, shoe_id,
         MAX(round_no)                                        AS max_round,
         MIN(round_no)                                        AS min_round,
         COUNT(DISTINCT round_no)                             AS rounds_with_bet,
         MAX(round_no) - COUNT(DISTINCT round_no)             AS gap,
         COUNT(DISTINCT member_id)                            AS n_bettors,
         COUNT(*)                                             AS n_bets
  FROM base
  GROUP BY dt, table_id, shoe_id
),
cut AS (                                                   -- 阈值由数据反解，禁硬写
  SELECT PERCENTILE_APPROX(max_round, 0.99) * 1.5 AS hi_cut
  FROM shoe_new
)
SELECT s.dt, s.table_id, s.shoe_id,
       s.max_round, s.min_round, s.rounds_with_bet, s.gap,
       s.n_bettors, s.n_bets,
       CASE WHEN s.max_round > c.hi_cut THEN '⚠️ 超长：碰撞或跨日合并可疑'
            WHEN s.max_round <= 5       THEN '⚠️ 残靴：截断／换荷官／开收台可疑'
            ELSE '—' END                             AS anomaly_type,
       ROUND(c.hi_cut, 2)                            AS hi_cut_used
FROM shoe_new s
CROSS JOIN cut c
WHERE s.max_round > c.hi_cut OR s.max_round <= 5
ORDER BY s.max_round DESC, s.dt, s.table_id, s.shoe_id;        -- 确定性排序，无 OFFSET
