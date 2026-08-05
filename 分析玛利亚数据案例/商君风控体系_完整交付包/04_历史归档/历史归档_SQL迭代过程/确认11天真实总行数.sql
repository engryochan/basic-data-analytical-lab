SET query_timeout = 1800;
WITH 候选_投注异常 AS (
    SELECT CAST(bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY CAST(bet05 AS BIGINT)
    HAVING COUNT(*) > 50
       AND (SUM(CAST(bet12 AS DOUBLE)) > 100000
            OR AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT CAST(a.bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY a.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_荷官关联 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT COUNT(*) AS 该11天真实总行数                          -- 只返回一个数字，不受1000行预览上限影响
FROM ods_mariadb_2b.ods_a168_bet01
WHERE CAST(bet05 AS BIGINT) IN (SELECT uid FROM 候选_最终)
  AND dt BETWEEN '2026-03-21' AND '2026-03-31';
