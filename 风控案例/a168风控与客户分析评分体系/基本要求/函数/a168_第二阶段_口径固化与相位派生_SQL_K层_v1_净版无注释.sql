SET SESSION query_timeout = 259200;
SET SESSION cbo_cte_reuse = true;

WITH v AS (
  SELECT b.bet01, b.bet05, b.bet08, b.bet11, b.bet38, b.category, b.dt,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
latest AS (SELECT * FROM v WHERE rn = 1)
SELECT
    (SELECT COUNT(*) FROM v)                                        AS S0_原始行数,
    (SELECT COUNT(*) FROM latest)                                   AS S1_去重后订单数,
    (SELECT COUNT(*) FROM v) - (SELECT COUNT(*) FROM latest)        AS S1_历史版本行数,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1' THEN 1 ELSE 0 END) AS S2_叠加category,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
             THEN 1 ELSE 0 END)                                     AS S3_叠加非重对,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
             THEN 1 ELSE 0 END)                                     AS S4_叠加会员号为正,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
              AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0
             THEN 1 ELSE 0 END)                                     AS S5_叠加汇率为正,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
              AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0
              AND NULLIF(TRIM(bet08),'') IS NOT NULL
             THEN 1 ELSE 0 END)                                     AS S6_有效订单数,
    SUM(CASE WHEN CAST(NULLIF(TRIM(bet05),'') AS BIGINT) IS NULL
             THEN 1 ELSE 0 END)                                     AS 附_会员号非数值,
    MIN(dt)                                                         AS 附_dt最小,
    MAX(dt)                                                         AS 附_dt最大
FROM latest;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet05, b.bet08, b.bet11, b.bet13, b.bet38, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT r.*,
         COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) AS hit_testline
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
)
SELECT
    (SELECT COUNT(*) FROM ta)                                       AS 测试线代理数,
    COUNT(*)                                                        AS 有效订单数含测试线,
    SUM(CASE WHEN hit_testline IS NULL THEN 1 ELSE 0 END)           AS 有效订单数排除后,
    SUM(CASE WHEN hit_testline IS NOT NULL THEN 1 ELSE 0 END)       AS 测试线订单数,
    SUM(CASE WHEN hit_testline IS NOT NULL THEN 1 ELSE 0 END)
      * 1.0 / NULLIF(COUNT(*), 0)                                   AS 测试线订单占比,
    COUNT(DISTINCT CAST(bet05 AS VARCHAR))                          AS 会员数含测试线,
    COUNT(DISTINCT CASE WHEN hit_testline IS NULL
                        THEN CAST(bet05 AS VARCHAR) END)            AS 会员数排除后,
    SUM(CASE WHEN hit_testline IS NOT NULL
             THEN CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
                  / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))
             ELSE 0 END)                                            AS 测试线本金
FROM vd;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.dt, b.bet05, b.bet08, b.bet11, b.bet13, b.bet14,
         b.bet16, b.bet17, b.bet41, b.validbet, b.commission,
         b.bet38, b.category, b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT
      dt,
      CAST(NULLIF(TRIM(commission),'') AS VARCHAR)                  AS comm_flag,
      CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS stake,
      CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS valid_bet,
      (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS game_pnl,
      CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS rebate,
      CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS bet_rebate,
      CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS net_pnl
  FROM vd
)
SELECT
    dt                                                              AS 日期,
    COUNT(*)                                                        AS 有效订单数,
    SUM(stake)                                                      AS 本金,
    SUM(valid_bet)                                                  AS 洗码量,
    SUM(game_pnl)                                                   AS 游戏输赢,
    SUM(rebate)                                                     AS 退水,
    SUM(bet_rebate)                                                 AS 下注退水,
    SUM(net_pnl)                                                    AS 净输赢,
    SUM(net_pnl) - SUM(game_pnl) - SUM(rebate)                      AS 残差式一,
    SUM(net_pnl) - SUM(game_pnl) - SUM(rebate) - SUM(bet_rebate)    AS 残差式二,
    SUM(net_pnl) - SUM(game_pnl) - SUM(bet_rebate)                  AS 残差式三,
    SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)                       AS 游戏输赢率洗码量为分母,
    SUM(game_pnl) / NULLIF(SUM(stake), 0)                           AS 游戏输赢率本金为分母,
    SUM(CASE WHEN comm_flag = '1' THEN 1 ELSE 0 END)                AS 免佣订单数,
    SUM(CASE WHEN comm_flag NOT IN ('0','1') THEN 1 ELSE 0 END)     AS 佣金标脏值订单数
FROM bs
GROUP BY dt
ORDER BY dt;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet40, b.bet06, b.bet08,
         b.bet05, b.bet11, b.bet38, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CAST(r.bet40 AS VARCHAR)                                      AS room_id,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(r.bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME))                 AS d_sec
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
rmax AS (
  SELECT table_id, room_id, round_key, MAX(d_sec) AS max_d
  FROM vd
  WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, room_id, round_key
)
SELECT
    table_id                                                        AS 桌号,
    COUNT(*)                                                        AS 局数,
    COUNT(DISTINCT room_id)                                         AS 涉及房间数,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.50)                  AS 最末下注秒P50,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.95)                  AS 最末下注秒P95,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.99)                  AS 最末下注秒P99,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.999)                 AS 最末下注秒P999,
    MAX(max_d)                                                      AS 最末下注秒最大,
    CAST(CEIL(PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.99)) AS INT)
                                                                    AS 窗口秒_自数据求,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.99)
      - PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.95)              AS P99减P95_稳健性判据,
    SUM(CASE WHEN max_d > PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.99)
             THEN 1 ELSE 0 END)                                     AS 逾制局数
FROM rmax
GROUP BY table_id
ORDER BY 窗口秒_自数据求, 桌号;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet06, b.bet08,
         b.bet09, b.bet11, b.bet13, b.bet14, b.validbet, b.eid,
         b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.bet09 AS VARCHAR)                                      AS bet_side,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(r.bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME))                 AS d_sec,
      CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS valid_bet,
      (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS game_pnl
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
rmax AS (
  SELECT table_id, round_key, MAX(d_sec) AS max_d
  FROM vd WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, round_key
),
tw AS (
  SELECT table_id,
         CAST(CEIL(PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.99)) AS INT) AS win_sec
  FROM rmax GROUP BY table_id
),
ph AS (
  SELECT d.*, w.win_sec,
         w.win_sec - d.d_sec                                        AS sec_to_close,
         d.d_sec * 1.0 / NULLIF(w.win_sec, 0)                       AS bet_progress
  FROM vd d JOIN tw w ON w.table_id = d.table_id
  WHERE d.d_sec IS NOT NULL
)
SELECT
    'K1_20260813'                                                   AS def_lock,
    win_sec                                                         AS 桌台窗口秒,
    CASE WHEN d_sec < 0                THEN 'A_时序异常'
         WHEN sec_to_close < 0         THEN 'B_逾制'
         WHEN sec_to_close <= 1        THEN 'C_封盘前1秒内'
         WHEN sec_to_close <= 2        THEN 'D_封盘前1至2秒'
         WHEN sec_to_close <= 3        THEN 'E_封盘前2至3秒'
         WHEN sec_to_close <= 5        THEN 'F_封盘前3至5秒'
         ELSE                               'G_常规时段' END        AS 相位段,
    COUNT(*)                                                        AS 注单数,
    COUNT(DISTINCT member_id)                                       AS 会员数,
    COUNT(DISTINCT round_key)                                       AS 局数,
    COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY win_sec)      AS 段内注单占比,
    SUM(valid_bet)                                                  AS 洗码量,
    SUM(game_pnl)                                                   AS 游戏输赢,
    SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)                       AS 游戏输赢率,
    PERCENTILE_APPROX(CAST(bet_progress AS DOUBLE), 0.50)           AS 下注进度P50
FROM ph
GROUP BY win_sec,
    CASE WHEN d_sec < 0                THEN 'A_时序异常'
         WHEN sec_to_close < 0         THEN 'B_逾制'
         WHEN sec_to_close <= 1        THEN 'C_封盘前1秒内'
         WHEN sec_to_close <= 2        THEN 'D_封盘前1至2秒'
         WHEN sec_to_close <= 3        THEN 'E_封盘前2至3秒'
         WHEN sec_to_close <= 5        THEN 'F_封盘前3至5秒'
         ELSE                               'G_常规时段' END
ORDER BY 桌台窗口秒, 相位段;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet06, b.bet08,
         b.bet09, b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,
         b.validbet, b.eid, b.ip, b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.ip    AS VARCHAR)                                      AS bet_ip,
      CAST(r.bet09 AS VARCHAR)                                      AS bet_side,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(r.bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME))                 AS d_sec,
      CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS stake,
      CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS valid_bet,
      (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS game_pnl,
      CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS rebate,
      CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS net_pnl
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
rmax AS (
  SELECT table_id, round_key, MAX(d_sec) AS max_d
  FROM vd WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, round_key
),
tw AS (
  SELECT table_id,
         CAST(CEIL(PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.99)) AS INT) AS win_sec
  FROM rmax GROUP BY table_id
),
pr AS (
  SELECT
      d.member_id, d.round_key, d.table_id,
      MIN(d.acct_date)                                              AS acct_date,
      MAX(d.dealer_id)                                              AS dealer_id_any,
      COUNT(DISTINCT d.dealer_id)                                   AS n_dealer_in_row,
      MAX(d.bet_ip)                                                 AS bet_ip_any,
      COUNT(*)                                                      AS n_orders,
      COUNT(DISTINCT d.bet_side)                                    AS n_side,
      SUM(d.stake)                                                  AS stake,
      SUM(d.valid_bet)                                              AS valid_bet,
      SUM(d.game_pnl)                                               AS game_pnl,
      SUM(d.rebate)                                                 AS rebate,
      SUM(d.net_pnl)                                                AS net_pnl,
      MAX(d.d_sec)                                                  AS last_d_sec
  FROM vd d
  GROUP BY d.member_id, d.round_key, d.table_id
)
SELECT
    'K1_20260813'                                                   AS def_lock,
    p.member_id                                                     AS 会员ID,
    p.round_key                                                     AS 物理局键,
    p.table_id                                                      AS 桌号,
    p.acct_date                                                     AS 账务日期,
    p.dealer_id_any                                                 AS 荷官ID,
    CASE WHEN p.dealer_id_any = '-1' THEN 1 ELSE 0 END              AS 是否哨兵荷官,
    p.bet_ip_any                                                    AS 下注IP,
    p.n_orders                                                      AS 局内注单数,
    p.n_side                                                        AS 局内玩法数,
    CASE WHEN p.n_side >= 2 AND p.game_pnl = 0 THEN 1 ELSE 0 END    AS 疑似同局对冲,
    p.stake                                                         AS 本金,
    p.valid_bet                                                     AS 洗码量,
    p.game_pnl                                                      AS 局游戏输赢,
    p.rebate                                                        AS 局退水,
    p.net_pnl                                                       AS 局净输赢,
    CASE WHEN p.game_pnl > 0 THEN '胜局'
         WHEN p.game_pnl < 0 THEN '负局'
         ELSE '和局' END                                            AS 局结果,
    p.last_d_sec                                                    AS 局内最末距开局秒,
    w.win_sec                                                       AS 桌台窗口秒,
    w.win_sec - p.last_d_sec                                        AS 局内最末距封盘秒
FROM pr p
JOIN tw w ON w.table_id = p.table_id
ORDER BY p.member_id, p.round_key;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet11, b.ip, b.eid,
         b.bet38, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet08,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.ip    AS VARCHAR)                                      AS bet_ip,
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
)
SELECT
    COUNT(*)                                                        AS L0_注单层行数,
    COUNT(DISTINCT CONCAT_WS('#', member_id, round_key))            AS L1_玩家局层应有行数,
    COUNT(DISTINCT round_key)                                       AS L2_局层应有行数,
    COUNT(DISTINCT member_id)                                       AS L3_会员层应有行数,
    COUNT(DISTINCT table_id)                                        AS 桌台数,
    COUNT(DISTINCT dealer_id)                                       AS 荷官数含哨兵,
    COUNT(DISTINCT CASE WHEN dealer_id <> '-1' THEN dealer_id END)  AS 荷官数排除哨兵,
    COUNT(DISTINCT bet_ip)                                          AS IP数,
    COUNT(*) * 1.0
      / NULLIF(COUNT(DISTINCT CONCAT_WS('#', member_id, round_key)), 0)
                                                                    AS 每玩家局平均注单数,
    COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT round_key), 0)           AS 每局平均注单数
FROM vd;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet08, b.bet11,
         b.bet13, b.bet14, b.validbet, b.eid, b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS valid_bet,
      (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS game_pnl
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
)
SELECT
    'K1_20260813'                                                   AS def_lock,
    CASE WHEN dealer_id = '-1' THEN 'S_哨兵层' ELSE 'Q_合格层' END   AS 分层,
    COUNT(*)                                                        AS 注单数,
    COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()                          AS 注单占比,
    COUNT(DISTINCT member_id)                                       AS 会员数,
    COUNT(DISTINCT round_key)                                       AS 局数,
    COUNT(DISTINCT table_id)                                        AS 桌台数,
    COUNT(DISTINCT dealer_id)                                       AS 荷官数,
    COUNT(DISTINCT acct_date)                                       AS 账务日数,
    MIN(acct_date)                                                  AS 起始日,
    MAX(acct_date)                                                  AS 结束日,
    SUM(valid_bet)                                                  AS 洗码量,
    SUM(game_pnl)                                                   AS 游戏输赢,
    SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)                       AS 游戏输赢率
FROM vd
GROUP BY CASE WHEN dealer_id = '-1' THEN 'S_哨兵层' ELSE 'Q_合格层' END
ORDER BY 分层;

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet08, b.bet11,
         b.eid, b.ip, b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.ip    AS VARCHAR)                                      AS bet_ip,
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
sz AS (
  SELECT round_key, COUNT(DISTINCT member_id) AS n_member
  FROM vd GROUP BY round_key
)
SELECT
    'round_key 局键'                                                AS 连接键,
    COUNT(DISTINCT round_key)                                       AS 基数,
    '高基数，可直接连接'                                              AS 建议
FROM vd
UNION ALL
SELECT 'member_id 会员键', COUNT(DISTINCT member_id), '高基数，可直接连接' FROM vd
UNION ALL
SELECT 'bet_ip IP键', COUNT(DISTINCT bet_ip), '高基数，可直接连接' FROM vd
UNION ALL
SELECT 'table_id 桌号', COUNT(DISTINCT table_id), '低基数，须先聚合再连接' FROM vd
UNION ALL
SELECT 'dealer_id 荷官', COUNT(DISTINCT dealer_id), '低基数，须先聚合再连接' FROM vd
UNION ALL
SELECT 'acct_date 账务日', COUNT(DISTINCT acct_date), '低基数，须先聚合再连接' FROM vd
UNION ALL
SELECT '同桌配对预估_局内两两组合',
       CAST(SUM(CAST(n_member AS BIGINT) * (CAST(n_member AS BIGINT) - 1) / 2) AS BIGINT),
       '此即同桌共现之实际配对量，超十亿者须设局规模上限'
FROM sz
ORDER BY 基数 DESC;
