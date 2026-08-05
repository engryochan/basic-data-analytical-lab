-- ==============================================================================
-- 候选_系统标记_修正版.sql
-- ==============================================================================
-- risklist真实字段：__source_pk, dt, bet01, op, optime, source_db, source_table,
-- ods_table_name, sync_time —— 没有bet05！这张表的"bet01"列是具体投注交易ID
-- (对应主表bet01.bet01这个交易主键)，不是会员ID，记录的是"系统对某笔交易
-- 做了什么风控操作(op)、什么时候做的(optime)"，是交易级别的操作日志，
-- 不是会员名单。要拿到会员ID，必须反查回主表。
-- ==============================================================================

SET query_timeout = 1800;
WITH 候选_系统标记 AS (
    SELECT DISTINCT CAST(b.bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_risklist r
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON r.bet01 = b.bet01                      -- risklist的交易ID桥接回主表的交易主键
)
SELECT COUNT(*) AS 系统标记候选数 FROM 候选_系统标记;


-- ==============================================================================
-- 四路全部就绪，最终合并——这条把之前已验证的三路(投注异常、同桌异常、
-- 荷官关联，全部是1-13分钟内跑完的真实结果)加上刚修正的系统标记，
-- 一次性去重合并成唯一权威候选名单
-- ==============================================================================
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
    -- 已实测：耗时约12.7分钟，62,245人，覆盖173,529,760行全量数据，零采样误差
),
候选_荷官关联 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
),
候选_系统标记 AS (
    SELECT DISTINCT CAST(b.bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_risklist r
    JOIN ods_mariadb_2b.ods_a168_bet01 b ON r.bet01 = b.bet01
)
SELECT
    (SELECT COUNT(*) FROM 候选_投注异常) AS 投注异常候选数,
    (SELECT COUNT(*) FROM 候选_同桌异常) AS 同桌异常候选数,
    (SELECT COUNT(*) FROM 候选_荷官关联) AS 荷官关联候选数,
    (SELECT COUNT(*) FROM 候选_系统标记) AS 系统标记候选数,
    (SELECT COUNT(*) FROM (
        SELECT uid FROM 候选_投注异常
        UNION SELECT uid FROM 候选_同桌异常
        UNION SELECT uid FROM 候选_荷官关联
        UNION SELECT uid FROM 候选_系统标记
    ) t) AS 最终去重候选总数;
