-- ==============================================================================
-- 候选人特征_拆分三条查询.sql
-- ==============================================================================
-- 【为什么拆】上一版把"投注特征"(全表GROUP BY，约1.44亿行参与聚合)、
-- "同桌特征"(自连接，已知内存/耗时都很重)、"荷官特征"三块放进同一条
-- 查询，StarRocks执行时这几块的中间结果同时占用内存，叠加起来撑爆了
-- 单个BE节点96.4GB的内存池。拆成三条独立查询分别执行、分别下载，
-- 每条只跑一类重活，互不叠加，最后在本地(R/Python)按uid做left_join
-- 合并成最终特征表——这是处理"单条查询内存超限"最直接有效的办法，
-- 不需要联系DBA调整集群内存配置。
-- ==============================================================================


-- ██████████████████████████████████████████████████████████████████████████
-- 查询A：投注特征（单独跑，不掺入自连接）
-- ██████████████████████████████████████████████████████████████████████████
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
同桌配对统计 AS (
    SELECT a2.bet05 AS uid1, b2.bet05 AS uid2, COUNT(DISTINCT a2.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a2
    JOIN ods_mariadb_2b.ods_a168_bet01 b2
      ON a2.bet03 = b2.bet03 AND a2.bet05 <> b2.bet05 AND a2.dt = b2.dt
    WHERE a2.dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY a2.bet05, b2.bet05
    HAVING COUNT(DISTINCT a2.bet03) > 50
),
候选_同桌异常 AS ( SELECT DISTINCT uid1 AS uid FROM 同桌配对统计 ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM (
        SELECT eid, bet05 FROM ods_mariadb_2b.ods_a168_bet01
        WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
        GROUP BY eid, bet05 HAVING COUNT(*) > 50
    ) t
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT
    CAST(bet05 AS BIGINT) AS uid,
    COUNT(*) AS 总投注笔数,
    SUM(CAST(bet12 AS DOUBLE)) AS 总投注额,
    SUM(CAST(bet13 AS DOUBLE)) AS 总有效投注额,
    AVG(CAST(bet11 AS DOUBLE)) AS 平均赔率,
    AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) AS 晚注比例,
    COUNT(DISTINCT bet02) AS 涉及桌台数,
    COUNT(DISTINCT eid) AS 涉及荷官数,
    MIN(dt) AS 首次投注日期,
    MAX(dt) AS 最后投注日期
FROM ods_mariadb_2b.ods_a168_bet01
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
  AND CAST(bet05 AS BIGINT) IN (SELECT uid FROM 候选_最终)
GROUP BY CAST(bet05 AS BIGINT);
-- 下载为：候选人特征_投注.csv


-- ██████████████████████████████████████████████████████████████████████████
-- 查询B：同桌特征（单独跑，只有自连接这一件重活，没有别的聚合掺进来）
-- ██████████████████████████████████████████████████████████████████████████
SET query_timeout = 1800;
WITH 同桌配对统计 AS (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 < b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50
)
SELECT
    uid1 AS uid,
    COUNT(DISTINCT uid2) AS 高频同桌关联人数,
    MAX(同桌局数) AS 最高单一同桌局数
FROM 同桌配对统计
GROUP BY uid1;
-- 下载为：候选人特征_同桌.csv


-- ██████████████████████████████████████████████████████████████████████████
-- 查询C：荷官特征（单独跑，最轻量的一块，预期几秒完成）
-- ██████████████████████████████████████████████████████████████████████████
SET query_timeout = 1800;
WITH 荷官配对统计 AS (
    SELECT eid, bet05, COUNT(*) AS 经手笔数
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
)
SELECT
    CAST(bet05 AS BIGINT) AS uid,
    COUNT(DISTINCT eid) AS 高频关联荷官数,
    MAX(经手笔数) AS 单一荷官最高经手笔数
FROM 荷官配对统计
GROUP BY bet05;
-- 下载为：候选人特征_荷官.csv


-- ==============================================================================
-- 三份CSV下载完成后，本地合并的R代码（不用再回StarRocks做join，
-- 三张表规模都是十几万行级别，本地data.table合并秒级完成）：
--
-- library(data.table)
-- 投注 <- fread("候选人特征_投注.csv")
-- 同桌 <- fread("候选人特征_同桌.csv")
-- 荷官 <- fread("候选人特征_荷官.csv")
-- 特征表 <- merge(投注, 同桌, by = "uid", all.x = TRUE)
-- 特征表 <- merge(特征表, 荷官, by = "uid", all.x = TRUE)
-- fwrite(特征表, "候选人特征聚合表_最终.csv")
-- ==============================================================================
