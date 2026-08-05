-- ==============================================================================
-- 批量抽取_bet01_基于候选名单.sql
-- ==============================================================================
-- 候选名单最终版：132,982人（投注异常118,946 + 同桌异常62,245 + 荷官关联
-- 70,217，三路UNION去重后）。risklist系统标记这一路已确认排除——该表是
-- 2022年历史归档数据(2022-07-12~2022-11-02)，跟bet01当前数据窗口
-- (2026-03-21起)完全不重叠，桥接不上是数据生命周期问题，不是候选名单的
-- 责任范围，不用勉强凑进来。
--
-- 【分批策略说明】候选名单本身132,982人，但这批人在bet01里的总记录数
-- 未知(候选名单是按"投注笔数>50、同桌局数>50、荷官关联笔数>50"这类
-- 条件筛出来的，天然都是高活跃账号，人均记录数会明显高于全体平均值)，
-- 直接一次性拉全部数据很可能远超10万行。按日期切片分批下载，每批
-- 控制在可控范围内，这也是企业级数据工程里"大结果集导出"的标准做法，
-- 不是权宜之计。
-- ==============================================================================

SET query_timeout = 1800;

-- ---- 第一步：先摸清楚这132,982人在bet01里总共有多少条记录，
-- 决定要切成几批 ----
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
SELECT COUNT(*) AS 候选人群在bet01的总记录数
FROM ods_mariadb_2b.ods_a168_bet01
WHERE CAST(bet05 AS BIGINT) IN (SELECT uid FROM 候选_最终);
-- 先跑这条，看这个数字——如果是几十万到百万级别，往下按周/按月切；
-- 如果是几百万甚至更多，切片粒度要更细(比如按天切)


-- ==============================================================================
-- 第二步：确认总量后，按日期切片实际下载——下面给第一批(3月21-31日)示例，
-- 后续每批只需改WHERE里最后一行的日期范围，候选名单CTE部分原样复制
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
SELECT *
FROM ods_mariadb_2b.ods_a168_bet01
WHERE CAST(bet05 AS BIGINT) IN (SELECT uid FROM 候选_最终)
  AND dt BETWEEN '2026-03-21' AND '2026-03-31'          -- 第1批：11天，先试小范围
ORDER BY dt, bet01;                                       -- 加ORDER BY保证多批下载之间数据不重不漏
