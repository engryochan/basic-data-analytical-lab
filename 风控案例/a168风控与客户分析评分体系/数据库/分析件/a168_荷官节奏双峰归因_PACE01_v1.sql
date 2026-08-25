-- ══════════════════════════════════════════════════════════════════════════════
--  PACE-01 · 荷官发牌节奏双峰归因分析（生产级 · 非探针）
--  背景：S02b 实测 149 名荷官（局数≥5000）每局秒数呈严格双峰
--        25–30s 68 人 · 30–40s 【0 人】· 40–45s 57 人 · 45–50s 24 人
--        两组 hold% 几乎相同（1.676% vs 1.717%）⇒ 慢 49% 未换来任何 hold 优势
--  待答：30–40 秒空档是【桌型规格】还是【作业习惯】？
--        桌型 ⇒ 无提速空间；作业习惯 ⇒ 纯运营增收
--  判读：看 L3 —— 同一荷官在不同桌是否自动切换 27s / 41s
--        会切换 ⇒ 桌型决定（PACE_BY_TABLE）
--        不切换 ⇒ 人员作业标准（PACE_BY_DEALER）→ 可干预
--  纪律：行注释 only · 无 OFFSET · ID 用 CAST(... AS BIGINT) · 除法 NULLIF 护零
--  窗口：dt >= '2026-03-21' AND dt < '2026-08-07' · bet02='101' · category='1'
-- ══════════════════════════════════════════════════════════════════════════════


-- ── L1 · 荷官 × 桌台 —— 同一荷官在哪些桌快、哪些桌慢 ──
-- 储存为：PACE01_L1_dealer_table.csv
WITH r AS (
  SELECT b.eid                                                        AS dealer_id,
         TRIM(b.bet39)                                                AS table_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                     AS round_key,
         MIN(b.bet08)                                                 AS t_first,
         MAX(b.bet08)                                                 AS t_last,
         SUM(CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)) AS r_stake,
         SUM(-CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)) AS r_profit,
         COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))       AS r_members
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  GROUP BY b.eid, TRIM(b.bet39), CONCAT_WS('|', b.bet03, b.bet04, b.bet39)
),
seq AS (
  SELECT dealer_id, table_id, round_key, t_first, r_stake, r_profit, r_members,
         LAG(t_first) OVER (PARTITION BY table_id ORDER BY t_first)     AS t_prev,
         LAG(dealer_id) OVER (PARTITION BY table_id ORDER BY t_first)   AS dealer_prev
  FROM r
),
gap AS (
  SELECT dealer_id, table_id, r_stake, r_profit, r_members,
         UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev)              AS gap_sec
  FROM seq
  WHERE t_prev IS NOT NULL
    AND dealer_prev = dealer_id
    AND UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev) BETWEEN 5 AND 300
),
dt_cell AS (
  SELECT dealer_id, table_id,
         COUNT(*)                                                      AS n_rounds,
         ROUND(AVG(gap_sec), 3)                                        AS avg_sec,
         ROUND(PERCENTILE_APPROX(gap_sec, 0.50), 3)                    AS p50_sec,
         ROUND(STDDEV(gap_sec), 3)                                     AS sd_sec,
         ROUND(SUM(r_stake), 2)                                        AS stake,
         ROUND(SUM(r_profit), 2)                                       AS profit,
         ROUND(100.0 * SUM(r_profit) / NULLIF(SUM(r_stake), 0), 4)     AS hold_pct,
         MAX(r_members)                                                AS max_members_per_round
  FROM gap
  GROUP BY dealer_id, table_id
  HAVING COUNT(*) >= 200
)
SELECT dealer_id, table_id, n_rounds, avg_sec, p50_sec, sd_sec,
       CASE WHEN avg_sec < 35 THEN 'FAST' ELSE 'SLOW' END              AS pace_group,
       stake, profit, hold_pct, max_members_per_round
FROM dt_cell
ORDER BY dealer_id, table_id;


-- ── L2 · 桌台层 —— 慢是否集中在特定桌 ──
--    若某桌下【所有】荷官都慢，则该桌是慢桌（桌型/限红/服务流程决定）
-- 储存为 PACE01_L2_table.csv
WITH r AS (
  SELECT b.eid AS dealer_id, TRIM(b.bet39) AS table_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key,
         MIN(b.bet08) AS t_first,
         SUM(CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)) AS r_stake,
         SUM(-CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)) AS r_profit
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  GROUP BY b.eid, TRIM(b.bet39), CONCAT_WS('|', b.bet03, b.bet04, b.bet39)
),
seq AS (
  SELECT dealer_id, table_id, t_first, r_stake, r_profit,
         LAG(t_first)   OVER (PARTITION BY table_id ORDER BY t_first) AS t_prev,
         LAG(dealer_id) OVER (PARTITION BY table_id ORDER BY t_first) AS dealer_prev
  FROM r
),
gap AS (
  SELECT dealer_id, table_id, r_stake, r_profit,
         UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev) AS gap_sec
  FROM seq
  WHERE t_prev IS NOT NULL AND dealer_prev = dealer_id
    AND UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev) BETWEEN 5 AND 300
),
cell AS (
  SELECT dealer_id, table_id, COUNT(*) AS n, AVG(gap_sec) AS avg_sec,
         SUM(r_stake) AS stake, SUM(r_profit) AS profit
  FROM gap GROUP BY dealer_id, table_id HAVING COUNT(*) >= 200
)
SELECT table_id,
       COUNT(DISTINCT dealer_id)                                       AS n_dealers,
       SUM(n)                                                          AS n_rounds,
       ROUND(AVG(avg_sec), 3)                                          AS table_avg_sec,
       ROUND(MIN(avg_sec), 3)                                          AS min_dealer_sec,
       ROUND(MAX(avg_sec), 3)                                          AS max_dealer_sec,
       ROUND(MAX(avg_sec) - MIN(avg_sec), 3)                           AS sec_span_within_table,
       SUM(CASE WHEN avg_sec <  35 THEN 1 ELSE 0 END)                  AS n_fast_dealers,
       SUM(CASE WHEN avg_sec >= 35 THEN 1 ELSE 0 END)                  AS n_slow_dealers,
       ROUND(SUM(stake), 2)                                            AS stake,
       ROUND(100.0 * SUM(profit) / NULLIF(SUM(stake), 0), 4)           AS hold_pct,
       CASE WHEN MAX(avg_sec) - MIN(avg_sec) < 5  THEN 'TABLE_DETERMINED'
            WHEN MAX(avg_sec) - MIN(avg_sec) >= 10 THEN 'DEALER_DETERMINED'
            ELSE 'MIXED' END                                           AS pace_driver
FROM cell
GROUP BY table_id
ORDER BY sec_span_within_table DESC;


-- ── L3 · ★判决层★ 同一荷官跨桌是否自动切换节奏 ──
--    sec_span_within_dealer 大  ⇒ 同一人在不同桌快慢不同 ⇒ 桌型决定，无提速空间
--    sec_span_within_dealer 小  ⇒ 同一人到哪张桌都一个速度 ⇒ 人员作业标准，可干预
-- 储存为 PACE01_L3_dealer_verdict.csv
WITH r AS (
  SELECT b.eid AS dealer_id, TRIM(b.bet39) AS table_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key, MIN(b.bet08) AS t_first
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  GROUP BY b.eid, TRIM(b.bet39), CONCAT_WS('|', b.bet03, b.bet04, b.bet39)
),
seq AS (
  SELECT dealer_id, table_id, t_first,
         LAG(t_first)   OVER (PARTITION BY table_id ORDER BY t_first) AS t_prev,
         LAG(dealer_id) OVER (PARTITION BY table_id ORDER BY t_first) AS dealer_prev
  FROM r
),
gap AS (
  SELECT dealer_id, table_id,
         UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev) AS gap_sec
  FROM seq
  WHERE t_prev IS NOT NULL AND dealer_prev = dealer_id
    AND UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev) BETWEEN 5 AND 300
),
cell AS (
  SELECT dealer_id, table_id, COUNT(*) AS n, AVG(gap_sec) AS avg_sec
  FROM gap GROUP BY dealer_id, table_id HAVING COUNT(*) >= 200
)
SELECT dealer_id,
       COUNT(DISTINCT table_id)                                        AS n_tables,
       SUM(n)                                                          AS n_rounds,
       ROUND(MIN(avg_sec), 3)                                          AS fastest_table_sec,
       ROUND(MAX(avg_sec), 3)                                          AS slowest_table_sec,
       ROUND(MAX(avg_sec) - MIN(avg_sec), 3)                           AS sec_span_within_dealer,
       SUM(CASE WHEN avg_sec <  35 THEN 1 ELSE 0 END)                  AS n_fast_tables,
       SUM(CASE WHEN avg_sec >= 35 THEN 1 ELSE 0 END)                  AS n_slow_tables,
       CASE WHEN MAX(avg_sec) - MIN(avg_sec) >= 10 THEN 'SWITCHES_BY_TABLE'
            WHEN MAX(avg_sec) - MIN(avg_sec) <  5  THEN 'CONSTANT_PACE'
            ELSE 'MIXED' END                                           AS verdict
FROM cell
GROUP BY dealer_id
HAVING COUNT(DISTINCT table_id) >= 2
ORDER BY sec_span_within_dealer DESC;


-- ── L4 · 时段层 —— 慢是否集中在特定时段（班次/客流） ──
-- 储存为 PACE01_L4_hour.csv
WITH r AS (
  SELECT b.eid AS dealer_id, TRIM(b.bet39) AS table_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key, MIN(b.bet08) AS t_first,
         SUM(CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)) AS r_stake,
         SUM(-CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)) AS r_profit
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  GROUP BY b.eid, TRIM(b.bet39), CONCAT_WS('|', b.bet03, b.bet04, b.bet39)
),
seq AS (
  SELECT dealer_id, table_id, t_first, r_stake, r_profit,
         LAG(t_first)   OVER (PARTITION BY table_id ORDER BY t_first) AS t_prev,
         LAG(dealer_id) OVER (PARTITION BY table_id ORDER BY t_first) AS dealer_prev
  FROM r
)
SELECT HOUR(t_first)                                                   AS hour_of_day,
       COUNT(*)                                                        AS n_rounds,
       COUNT(DISTINCT dealer_id)                                       AS n_dealers,
       COUNT(DISTINCT table_id)                                        AS n_tables,
       ROUND(AVG(UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev)), 3) AS avg_sec,
       ROUND(SUM(r_stake), 2)                                          AS stake,
       ROUND(100.0 * SUM(r_profit) / NULLIF(SUM(r_stake), 0), 4)       AS hold_pct
FROM seq
WHERE t_prev IS NOT NULL AND dealer_prev = dealer_id
  AND UNIX_TIMESTAMP(t_first) - UNIX_TIMESTAMP(t_prev) BETWEEN 5 AND 300
GROUP BY HOUR(t_first)
ORDER BY hour_of_day;
