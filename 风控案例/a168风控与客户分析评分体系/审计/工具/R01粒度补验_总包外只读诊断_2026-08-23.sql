-- ══════════════════════════════════════════════════════════════════════════
-- R01 粒度补验 · 总包外只读诊断（★ 尚未入 a168_取数与核验_SQL总包 ★）
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由：REDTEAM 2026-08-23 裁示——v11 继续 LOCKED、v12 不启动；
--   G-1（列名去方向预设）／G-2（判词四态升五态）／G-3（补验入册）一律暂缓，
--   先以总包外只读诊断取得两把尺，再一次性收口。
-- 本件性质：只读、无写入、无 DDL、不覆盖任何交付件文件名。
--   ▸ 导出：可选 —— 若须留档，存为「数据库/_R01chk0c_day_split.csv」与
--     「数据库/_R01chk0b_cross_table.csv」；下划线前缀标明其为诊断留档、非交付件。
-- 口径血统：CTE test_agents／ranked／base 逐字沿用 §R01-0（含 b.dt 增列），
--   四闸齐备（剔测试线／版本去重／一般注单／非重对）＋ 数值守门三项。
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序。
-- ══════════════════════════════════════════════════════════════════════════
--
-- 【本件所答之两问，正交，禁互代】
--   甲 · 跨日之性质：2.5065% 之跨日，究系「同一物理靴跨零点被 dt 切开」，
--        抑或「靴号隔日复用」？—— day_span 单独不足以判，须加局号区间之衔接性。
--   乙 · 跨桌之有无：同日同 shoe_id 是否跨桌？—— 此为 §P12a／§P13 之
--        GROUP BY bet03 是否合并异桌靴的唯一裁决依据。
--        ⚠ corr_cross_table = −0.600417 系桌级聚合之相关，**不是**跨桌重号之证据，
--          二者不可互代（REDTEAM 已锁）。
--
-- 【落笔前之先验（判级 INFERRED，样本有偏，须以本件全域实测坐实或推翻）】
--   自 R01anm_shoe_anomaly.csv 之 377 条反解 shoe_id 编号体系：
--     · 90x 族（13 桌）：区间 12,792 ~ 12,107,520，位数 5~8
--     · 3x／11x／1-8 三族（17 桌）：区间 114,585,411 ~ 114,734,683，位数恒 9
--     · 两区间**完全不重叠**；三族之区间则**完全重叠且连续**
--     · 按日期序之递增比例 77.6% ~ 94.0%；日均增量与「桌数 × 每桌日靴数」同量级
--     · 本样本内同 shoe_id 跨桌者 **0 / 377**
--   故先验为：shoe_id 系**命名空间内之全局自增序号**，非按桌循环之小序号；
--   若成立，则 pct_cross_table 应趋近 0，§P12a／§P13 之 GROUP BY bet03
--   **不存在跨桌合并**——此与本人上一轮之担忧方向相反，如实登记。
--   ⚠ 但 377 条系「异常靴」之偏样本（超长 1 ＋ 残靴 376），占全域 0.3%，
--     绝不足以代表全域；先验只作预期，不作裁定。


-- ──────────────────────────────────────────────────────────────────────────
-- 诊断甲 · §R01-0c · 跨日两段之衔接性检验（比 day_span 更强之判别式）
-- ──────────────────────────────────────────────────────────────────────────
-- 判别原理：
--   · 若系「同一物理靴跨零点」：前日之局号止于 k，次日自 k+1 续接——
--     两段之局号区间**连续且不重叠**，且次日之起始局号远大于 1。
--   · 若系「靴号隔日复用」：次日为另一条物理靴，其局号**自 1 重新起算**——
--     两段区间重叠，次日起始局号 ≈ 1。
--   二者之别在「次日起始局号」，day_span 单独看不出来。
-- 判读：
--   n_contiguous ／ n_pairs 趋近 1 且 avg_rmin_day2 远大于 1 → 跨零点，粒度 CLOSED
--   n_restart 占比高（次日自 1 起）                        → 号码复用，粒度 REOPEN
--   day_span >= 2 之占比若不可忽略                          → 另有成因，须重开
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'                                  -- 铁律④b：公司测试线
),
ranked AS (                                            -- 需求 §3.2：同单号保留最新版本
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.bet38, b.bet39, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b                 -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.dt                                          AS dt,
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)      AS member_id,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')    AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')    AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)         AS round_no
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
pd AS (                                                -- 逐（靴，桌，日）之局号区间
  SELECT shoe_id, table_id, dt,
         MIN(round_no)                                              AS r_min,
         MAX(round_no)                                              AS r_max,
         COUNT(DISTINCT round_no)                                   AS n_rounds,
         COUNT(*)                                                   AS n_bets
  FROM base
  GROUP BY shoe_id, table_id, dt
),
pdw AS (                                               -- 开窗定序：同（靴，桌）内按日排序
  SELECT p.*,
         ROW_NUMBER() OVER (PARTITION BY shoe_id, table_id ORDER BY dt) AS d_rank,
         COUNT(*)     OVER (PARTITION BY shoe_id, table_id)             AS n_days
  FROM pd p
),
pair AS (                                              -- 只取 n_days = 2 者之首末两段
  SELECT a.shoe_id, a.table_id,
         a.dt AS dt1, b.dt AS dt2,
         DATEDIFF(b.dt, a.dt)                                       AS day_span,
         a.r_min AS r_min_1, a.r_max AS r_max_1, a.n_rounds AS n_rounds_1,
         b.r_min AS r_min_2, b.r_max AS r_max_2, b.n_rounds AS n_rounds_2
  FROM pdw a
  JOIN pdw b ON b.shoe_id = a.shoe_id AND b.table_id = a.table_id
            AND a.d_rank = 1 AND b.d_rank = 2
  WHERE a.n_days = 2
)
SELECT
  day_span,
  COUNT(*)                                                          AS n_pairs,
  SUM(CASE WHEN r_max_1 < r_min_2 THEN 1 ELSE 0 END)                AS n_contiguous,
  ROUND(SUM(CASE WHEN r_max_1 < r_min_2 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                   AS pct_contiguous,
  SUM(CASE WHEN r_min_2 <= 1 THEN 1 ELSE 0 END)                     AS n_restart_at_1,
  ROUND(SUM(CASE WHEN r_min_2 <= 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                   AS pct_restart_at_1,
  SUM(CASE WHEN r_max_1 >= r_min_2 THEN 1 ELSE 0 END)               AS n_overlap,
  ROUND(AVG(r_max_1), 4)                                            AS avg_rmax_day1,
  ROUND(AVG(r_min_2), 4)                                            AS avg_rmin_day2,
  ROUND(AVG(r_min_2 - r_max_1), 4)                                  AS avg_join_gap,
  ROUND(AVG(r_max_2), 4)                                            AS avg_rmax_day2,
  ROUND(AVG(n_rounds_1 + n_rounds_2), 4)                            AS avg_rounds_merged
FROM pair
GROUP BY day_span
ORDER BY day_span;


-- ──────────────────────────────────────────────────────────────────────────
-- 诊断乙 · §R01-0b · 跨桌重号验证 ＋ 三层粒度并报
-- ──────────────────────────────────────────────────────────────────────────
-- 三层粒度（直接对应本项目现存三种写法）：
--   g1  GROUP BY shoe_id                    ← §P12a／§P13 现行（只此一键）
--   g2  GROUP BY shoe_id, table_id          ← §R01／§B01／§B01-D／§P11b 现行
--   g3  GROUP BY dt, shoe_id, table_id      ← §R01-chk 族所用之新粒度
-- 判读：
--   pct_cross_table 趋近 0        → shoe_id 系全局自增序号，g1 无跨桌合并，
--                                    §P12a／§P13 之粒度**无实质污染**
--   pct_cross_table 显著大于 0    → g1 合并异桌靴，其 max_round 被夸大、
--                                    shoe_pos 被压低，须另立代码变更单
--   n_shoes_g1 与 n_shoes_g2 之差 → 合并之绝对量；差趋近 0 即证 g1 ≈ g2
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'                                  -- 铁律④b：公司测试线
),
ranked AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.bet38, b.bet39, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.dt                                          AS dt,
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)      AS member_id,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')    AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')    AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)         AS round_no
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
g1 AS (                                                -- §P12a／§P13 现行粒度
  SELECT shoe_id,
         COUNT(DISTINCT table_id)  AS n_tables,
         COUNT(DISTINCT dt)        AS n_days,
         MAX(round_no)             AS max_round_g1
  FROM base
  GROUP BY shoe_id
),
g2 AS (                                                -- §R01 现行粒度
  SELECT shoe_id, table_id, MAX(round_no) AS max_round_g2
  FROM base
  GROUP BY shoe_id, table_id
),
g3 AS (                                                -- §R01-chk 族新粒度
  SELECT dt, shoe_id, table_id, MAX(round_no) AS max_round_g3
  FROM base
  GROUP BY dt, shoe_id, table_id
)
SELECT
  (SELECT COUNT(*) FROM g1)                                         AS n_shoes_g1,
  (SELECT COUNT(*) FROM g2)                                         AS n_shoes_g2,
  (SELECT COUNT(*) FROM g3)                                         AS n_shoes_g3,
  (SELECT COUNT(*) FROM g2) - (SELECT COUNT(*) FROM g1)             AS delta_g2_minus_g1,
  SUM(CASE WHEN n_tables > 1 THEN 1 ELSE 0 END)                     AS n_cross_table,
  ROUND(SUM(CASE WHEN n_tables > 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                   AS pct_cross_table,
  MAX(n_tables)                                                     AS max_tables_per_shoe,
  ROUND(AVG(n_tables), 6)                                           AS avg_tables_per_shoe,
  ROUND(AVG(CASE WHEN n_tables > 1 THEN max_round_g1 END), 4)       AS avg_maxround_crosstable,
  ROUND(AVG(CASE WHEN n_tables = 1 THEN max_round_g1 END), 4)       AS avg_maxround_singletable,
  MAX(CASE WHEN n_tables > 1 THEN max_round_g1 END)                 AS peak_maxround_crosstable,
  ROUND((SELECT AVG(max_round_g1) FROM g1), 4)                      AS avg_maxround_g1,
  ROUND((SELECT AVG(max_round_g2) FROM g2), 4)                      AS avg_maxround_g2,
  ROUND((SELECT AVG(max_round_g3) FROM g3), 4)                      AS avg_maxround_g3
FROM g1;


-- ──────────────────────────────────────────────────────────────────────────
-- 诊断丙 · §R01-0d · 跨桌重号之逐行证据（仅在诊断乙判为「显著大于 0」时才跑）
-- ──────────────────────────────────────────────────────────────────────────
-- ★ 若 pct_cross_table ≈ 0，本条应返回零行——零行即证据，须照登，不得略过不跑。
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet11,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.bet38, b.bet39, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.dt                                          AS dt,
         COALESCE(NULLIF(TRIM(r.bet03),''), '(空)')    AS shoe_id,
         COALESCE(NULLIF(TRIM(r.bet39),''), '(空)')    AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)         AS round_no
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
sh AS (
  SELECT shoe_id,
         COUNT(DISTINCT table_id) AS n_tables,
         MIN(dt) AS dt_min, MAX(dt) AS dt_max,
         MAX(round_no) AS max_round_g1
  FROM base
  GROUP BY shoe_id
)
SELECT s.shoe_id, s.n_tables, s.dt_min, s.dt_max, s.max_round_g1,
       t.table_id, t.n_days_in_table, t.max_round_in_table
FROM sh s
JOIN (
  SELECT shoe_id, table_id,
         COUNT(DISTINCT dt) AS n_days_in_table,
         MAX(round_no)      AS max_round_in_table
  FROM base
  GROUP BY shoe_id, table_id
) t ON t.shoe_id = s.shoe_id
WHERE s.n_tables > 1
ORDER BY s.n_tables DESC, s.max_round_g1 DESC, s.shoe_id, t.table_id;
