

SET SESSION query_timeout = 259200;
SET SESSION cbo_cte_reuse = true;

SELECT
    TABLE_NAME                                                   AS 表名,
    TABLE_TYPE                                                   AS 表类型,
    TABLE_ROWS                                                   AS 估计行数,
    TABLE_COMMENT                                                AS 表注释,
    CASE
      WHEN LOWER(TABLE_NAME) LIKE '%_bak%'  THEN '备份'
      WHEN LOWER(TABLE_NAME) LIKE '%bak2%'  THEN '备份'
      WHEN LOWER(TABLE_NAME) LIKE '%_test%' THEN '测试'
      WHEN LOWER(TABLE_NAME) LIKE '%_tmp%'  THEN '临时'
      WHEN LOWER(TABLE_NAME) LIKE '%_old%'  THEN '旧版'
      WHEN LOWER(TABLE_NAME) LIKE '%_copy%' THEN '副本'
      WHEN LOWER(TABLE_NAME) LIKE '%_v1%'   THEN '疑似旧版'
      WHEN LOWER(TABLE_NAME) LIKE '%demo%'  THEN '疑似演示'
      ELSE '生产'
    END                                                          AS 疑似性质
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY 疑似性质, TABLE_NAME;

SELECT
    TABLE_NAME                          AS 表名,
    TABLE_ROWS                          AS 估计行数,
    TABLE_COMMENT                       AS 表注释,
    CASE
      WHEN LOWER(TABLE_NAME) LIKE '%_bak%'  OR LOWER(TABLE_NAME) LIKE '%bak2%' THEN '备份表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_test%' THEN '测试表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_tmp%'  THEN '临时表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_old%'  THEN '旧版表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_copy%' THEN '副本表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%demo%'  THEN '演示表·须确认'
      ELSE '其他·须确认'
    END                                 AS 处置
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (   LOWER(TABLE_NAME) LIKE '%_bak%'  OR LOWER(TABLE_NAME) LIKE '%bak2%'
       OR LOWER(TABLE_NAME) LIKE '%_test%' OR LOWER(TABLE_NAME) LIKE '%_tmp%'
       OR LOWER(TABLE_NAME) LIKE '%_old%'  OR LOWER(TABLE_NAME) LIKE '%_copy%'
       OR LOWER(TABLE_NAME) LIKE '%demo%')
ORDER BY 处置, TABLE_NAME;

SELECT
    TABLE_NAME                                                        AS 表名,
    ORDINAL_POSITION                                                  AS 列序,
    COLUMN_NAME                                                       AS 列名,
    DATA_TYPE                                                         AS 存储类型,
    IS_NULLABLE                                                       AS 可空,
    REGEXP_EXTRACT(COLUMN_COMMENT, 'source_type=([^;]+)', 1)          AS 原始类型,
    TRIM(REGEXP_REPLACE(COLUMN_COMMENT, 'source_type=[^;]+;', ''))    AS 业务含义,
    COLUMN_COMMENT                                                    AS 原始注释
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

WITH d AS (
  SELECT
      COLUMN_NAME,
      TABLE_NAME,
      TRIM(REGEXP_REPLACE(COLUMN_COMMENT, 'source_type=[^;]+;', ''))  AS 含义,
      REGEXP_EXTRACT(COLUMN_COMMENT, 'source_type=([^;]+)', 1)        AS 类型
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
    AND COLUMN_COMMENT IS NOT NULL
    AND TRIM(COLUMN_COMMENT) <> ''
)
SELECT
    COLUMN_NAME                                  AS 列名,
    COUNT(DISTINCT 含义)                          AS 释义数,
    COUNT(DISTINCT 类型)                          AS 类型数,
    COUNT(DISTINCT TABLE_NAME)                   AS 出现表数,
    CASE WHEN COUNT(DISTINCT 类型) >= 2 THEN '🔴 义异且型异'
         ELSE '🟠 义异型同' END                   AS 风险,
    GROUP_CONCAT(DISTINCT CONCAT(TABLE_NAME, ' → ', 含义, ' [', 类型, ']')
                 SEPARATOR '  ||  ')             AS 明细
FROM d
GROUP BY COLUMN_NAME
HAVING COUNT(DISTINCT 含义) >= 2
ORDER BY 类型数 DESC, 释义数 DESC, 出现表数 DESC, COLUMN_NAME;

SELECT
    TABLE_NAME                        AS 表名,
    ORDINAL_POSITION                  AS 列序,
    COLUMN_NAME                       AS 列名,
    DATA_TYPE                         AS 存储类型,
    COLUMN_COMMENT                    AS 原始注释,
    CASE
      WHEN COLUMN_COMMENT IS NULL OR TRIM(COLUMN_COMMENT) = ''      THEN '🔴 无任何注释'
      WHEN COLUMN_COMMENT NOT LIKE '%source_type=%'                 THEN '🟠 缺原始类型'
      WHEN TRIM(REGEXP_REPLACE(COLUMN_COMMENT,'source_type=[^;]+;','')) = ''
                                                                    THEN '🟠 有类型无含义'
      ELSE '🟢 完整'
    END                               AS 状态
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (COLUMN_COMMENT IS NULL
       OR TRIM(COLUMN_COMMENT) = ''
       OR COLUMN_COMMENT NOT LIKE '%source_type=%'
       OR TRIM(REGEXP_REPLACE(COLUMN_COMMENT,'source_type=[^;]+;','')) = '')
ORDER BY 状态, TABLE_NAME, ORDINAL_POSITION;

SELECT
    c.TABLE_NAME                                          AS 表名,
    c.ORDINAL_POSITION                                    AS 列序,
    c.COLUMN_NAME                                         AS 列名,
    t.TABLE_ROWS                                          AS 估计行数,
    CONCAT(
      'SELECT ''', c.TABLE_NAME, ''' AS t, ''', c.COLUMN_NAME, ''' AS c, ',
      'CAST(', c.COLUMN_NAME, ' AS VARCHAR) AS v, COUNT(*) AS n, ',
      'COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct ',
      'FROM ods_mariadb_2b.', c.TABLE_NAME, ' ',
      'GROUP BY 3 ORDER BY n DESC LIMIT 20;'
    )                                                     AS 待执行SQL
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN INFORMATION_SCHEMA.TABLES t
       ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'
  AND c.COLUMN_NAME NOT IN ('__source_pk','source_db','source_table',
                            'ods_table_name','sync_time')
  AND NOT (   LOWER(c.TABLE_NAME) LIKE '%_bak%'  OR LOWER(c.TABLE_NAME) LIKE '%bak2%'
           OR LOWER(c.TABLE_NAME) LIKE '%_test%' OR LOWER(c.TABLE_NAME) LIKE '%_tmp%'
           OR LOWER(c.TABLE_NAME) LIKE '%_old%'  OR LOWER(c.TABLE_NAME) LIKE '%_copy%')
ORDER BY t.TABLE_ROWS DESC, c.TABLE_NAME, c.ORDINAL_POSITION;

SELECT 'ods_a168_bet02' AS t, 'bet03' AS c, CAST(bet03 AS VARCHAR) AS v,
       COUNT(*) AS n, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet04', CAST(bet04 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet39', CAST(bet39 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'eid', CAST(eid AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'gametype', CAST(gametype AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'commission', CAST(commission AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'category', CAST(category AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet09', CAST(bet09 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet10', CAST(bet10 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet11', CAST(bet11 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
ORDER BY 1, 2, 4 DESC;

WITH v AS (
  SELECT
      CAST(bet03 AS VARCHAR) AS k3,
      CAST(bet04 AS VARCHAR) AS k4,
      CAST(bet39 AS VARCHAR) AS k39,
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR)) AS round_key
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
per_key AS (
  SELECT round_key,
         COUNT(*)                  AS n_rows,
         COUNT(DISTINCT member_id) AS n_member,
         COUNT(DISTINCT k39)       AS n_table
  FROM v GROUP BY round_key
),
per_k3 AS (
  SELECT k3, COUNT(DISTINCT k39) AS n_table_per_k3,
             COUNT(DISTINCT k4)  AS n_k4_per_k3
  FROM v GROUP BY k3
)
SELECT
    (SELECT COUNT(*) FROM v)                                            AS 注单行数,
    (SELECT COUNT(*) FROM per_key)                                      AS 局键数,
    (SELECT MAX(n_rows)   FROM per_key)                                 AS 单局最大注单行数,
    (SELECT MAX(n_member) FROM per_key)                                 AS 单局最大会员数,
    (SELECT PERCENTILE_APPROX(CAST(n_member AS DOUBLE),0.999) FROM per_key)
                                                                        AS 单局会员数P999,
    (SELECT COUNT(*) FROM per_key WHERE n_table > 1)                    AS 跨桌局键数_应为0,
    (SELECT COUNT(*) FROM per_k3 WHERE n_table_per_k3 > 1)              AS bet03跨桌数,
    (SELECT COUNT(*) FROM per_k3)                                       AS bet03唯一值数,
    (SELECT SUM(CASE WHEN k3 IN ('-1','0','') OR k3 IS NULL
                       OR k4 IN ('-1','0','') OR k4 IS NULL
                       OR k39 IN ('-1','0','') OR k39 IS NULL
                     THEN 1 ELSE 0 END) FROM v)                         AS 局键含哨兵值行数;

WITH v AS (
  SELECT
      dt,
      CAST(NULLIF(TRIM(bet07),'') AS DATE)      AS d_acct,
      CAST(NULLIF(TRIM(bet06),'') AS DATETIME)  AS t_open,
      CAST(NULLIF(TRIM(bet08),'') AS DATETIME)  AS t_bet
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
)
SELECT
    COUNT(*)                                                        AS 行数,
    SUM(CASE WHEN dt = d_acct THEN 1 ELSE 0 END)                    AS dt等于账务日,
    SUM(CASE WHEN dt = DATE(t_bet) THEN 1 ELSE 0 END)               AS dt等于下注日,
    SUM(CASE WHEN d_acct = DATE(t_bet) THEN 1 ELSE 0 END)           AS 账务日等于下注日,
    SUM(CASE WHEN d_acct IS NULL THEN 1 ELSE 0 END)                 AS 账务日不可用,
    SUM(CASE WHEN t_open IS NULL THEN 1 ELSE 0 END)                 AS 开局时间不可用,
    SUM(CASE WHEN t_bet  IS NULL THEN 1 ELSE 0 END)                 AS 下注时间不可用,
    SUM(CASE WHEN t_bet <= '1971-01-01 00:00:00' THEN 1 ELSE 0 END) AS 下注时间纪元哨兵,
    SUM(CASE WHEN t_open <= '1971-01-01 00:00:00' THEN 1 ELSE 0 END) AS 开局时间纪元哨兵,
    MIN(d_acct)                                                     AS 账务日最小,
    MAX(d_acct)                                                     AS 账务日最大,
    SUM(CASE WHEN TIMESTAMPDIFF(SECOND, t_open, t_bet) <  0 THEN 1 ELSE 0 END)
                                                                    AS 下注早于开局_时序异常,
    MIN(TIMESTAMPDIFF(SECOND, t_open, t_bet))                       AS 下注距开局秒_最小,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.50)
                                                                    AS 下注距开局秒_P50,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.99)
                                                                    AS 下注距开局秒_P99,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.999)
                                                                    AS 下注距开局秒_P999,
    MAX(TIMESTAMPDIFF(SECOND, t_open, t_bet))                       AS 下注距开局秒_最大
FROM v;

WITH v AS (
  SELECT
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR))                        AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(bet08),'') AS DATETIME))                   AS d_sec
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
hist AS (
  SELECT d_sec, COUNT(*) AS n_orders
  FROM v WHERE d_sec IS NOT NULL
  GROUP BY d_sec
),
rmax AS (
  SELECT round_key, MAX(d_sec) AS max_d
  FROM v WHERE d_sec IS NOT NULL
  GROUP BY round_key
),
rhist AS (
  SELECT max_d, COUNT(*) AS n_rounds
  FROM rmax GROUP BY max_d
)
SELECT '注单层·逐秒' AS 层, CAST(h.d_sec AS VARCHAR) AS 距开局秒,
       h.n_orders AS 计数,
       h.n_orders * 1.0 / SUM(h.n_orders) OVER ()               AS 占比,
       SUM(h.n_orders) OVER (ORDER BY h.d_sec)
         * 1.0 / SUM(h.n_orders) OVER ()                        AS 累计占比
FROM hist h
UNION ALL
SELECT '局层·该局最末下注秒', CAST(r.max_d AS VARCHAR),
       r.n_rounds,
       r.n_rounds * 1.0 / SUM(r.n_rounds) OVER (),
       SUM(r.n_rounds) OVER (ORDER BY r.max_d)
         * 1.0 / SUM(r.n_rounds) OVER ()
FROM rhist r
ORDER BY 1, CAST(距开局秒 AS INT);

WITH v AS (
  SELECT
      CAST(bet39 AS VARCHAR)                                        AS table_id,
      CAST(bet40 AS VARCHAR)                                        AS room_id,
      dt,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR))                        AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(bet08),'') AS DATETIME))                   AS d_sec
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
rmax AS (
  SELECT table_id, room_id, round_key,
         DATE_FORMAT(MIN(dt), '%Y-%m')        AS ym,
         MAX(d_sec)                           AS max_d
  FROM v
  WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, room_id, round_key
),
cls AS (
  SELECT table_id, room_id, ym, round_key, max_d,
         CASE WHEN max_d <= 13 THEN '短制式约14秒'
              WHEN max_d <= 25 THEN '长制式约26秒'
              ELSE '逾制·异常'          END   AS regime
  FROM rmax
)
SELECT
    table_id                                                        AS 桌号,
    room_id                                                         AS 房间,
    ym                                                              AS 年月,
    COUNT(*)                                                        AS 局数,
    SUM(CASE WHEN regime = '短制式约14秒' THEN 1 ELSE 0 END)          AS 短制式局数,
    SUM(CASE WHEN regime = '长制式约26秒' THEN 1 ELSE 0 END)          AS 长制式局数,
    SUM(CASE WHEN regime = '逾制·异常'   THEN 1 ELSE 0 END)          AS 逾制局数,
    GREATEST(SUM(CASE WHEN regime = '短制式约14秒' THEN 1 ELSE 0 END),
             SUM(CASE WHEN regime = '长制式约26秒' THEN 1 ELSE 0 END))
      * 1.0 / NULLIF(COUNT(*), 0)                                   AS 制式纯度,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.50)                  AS 最末下注秒P50,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.95)                  AS 最末下注秒P95,
    MAX(max_d)                                                      AS 最末下注秒最大
FROM cls
GROUP BY table_id, room_id, ym
ORDER BY 制式纯度 ASC, 局数 DESC;

WITH v AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CAST(ip    AS VARCHAR) AS ip_addr,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR)) AS round_key,
      CASE WHEN CAST(bet03 AS VARCHAR) IN ('-1','0','') OR bet03 IS NULL
                OR CAST(bet04 AS VARCHAR) IN ('-1','0','') OR bet04 IS NULL
                OR CAST(bet39 AS VARCHAR) IN ('-1','0','') OR bet39 IS NULL
           THEN 1 ELSE 0 END AS is_sentinel_key
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
a AS (
  SELECT COUNT(*) AS n_rows, COUNT(DISTINCT round_key) AS n_key,
         COUNT(DISTINCT member_id) AS n_member, COUNT(DISTINCT ip_addr) AS n_ip
  FROM v
),
b AS (
  SELECT COUNT(*) AS n_rows, COUNT(DISTINCT round_key) AS n_key,
         COUNT(DISTINCT member_id) AS n_member, COUNT(DISTINCT ip_addr) AS n_ip
  FROM v WHERE is_sentinel_key = 0
),
ma AS (SELECT MAX(c) AS m FROM (SELECT round_key, COUNT(DISTINCT member_id) AS c
                                FROM v GROUP BY round_key) x),
mb AS (SELECT MAX(c) AS m FROM (SELECT round_key, COUNT(DISTINCT member_id) AS c
                                FROM v WHERE is_sentinel_key = 0 GROUP BY round_key) y)
SELECT
    a.n_rows   AS 未处置_注单行数,  b.n_rows   AS 已处置_注单行数,
    a.n_key    AS 未处置_局键数,    b.n_key    AS 已处置_局键数,
    a.n_member AS 未处置_会员数,    b.n_member AS 已处置_会员数,
    a.n_ip     AS 未处置_IP数,      b.n_ip     AS 已处置_IP数,
    ma.m       AS 未处置_单局最大会员数,
    mb.m       AS 已处置_单局最大会员数,
    ma.m - mb.m                                       AS 单局最大会员数_差额,
    a.n_rows - b.n_rows                               AS 剔除行数,
    (a.n_rows - b.n_rows) * 1.0 / NULLIF(a.n_rows, 0) AS 剔除占比
FROM a CROSS JOIN b CROSS JOIN ma CROSS JOIN mb;

