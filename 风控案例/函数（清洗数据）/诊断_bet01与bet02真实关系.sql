SET query_timeout = 1800;

-- ---- 诊断1：bet01与bet02的交易ID(bet01列)有没有重合 ----
-- 如果两表是"同一笔交易先下注(bet01)后结算(bet02)"的关系，交易ID应该
-- 大量重合；如果是两条独立产品线，交易ID体系应该完全不重合
WITH bet01_ids AS (
    SELECT DISTINCT bet01 AS 交易id FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt = '2026-07-24'
),
bet02_ids AS (
    SELECT DISTINCT bet01 AS 交易id FROM ods_mariadb_2b.ods_a168_bet02
    WHERE dt = '2026-07-24'
)
SELECT
    (SELECT COUNT(*) FROM bet01_ids) AS bet01当日交易数,
    (SELECT COUNT(*) FROM bet02_ids) AS bet02当日交易数,
    (SELECT COUNT(*) FROM bet01_ids a JOIN bet02_ids b ON a.交易id = b.交易id) AS 交易id重合数;


-- ---- 诊断2：两表的gametype分布是否互斥 ----
SELECT 'bet01' AS 来源表, gametype, COUNT(*) AS 笔数
FROM ods_mariadb_2b.ods_a168_bet01 WHERE dt = '2026-07-24'
GROUP BY gametype
UNION ALL
SELECT 'bet02' AS 来源表, gametype, COUNT(*) AS 笔数
FROM ods_mariadb_2b.ods_a168_bet02 WHERE dt = '2026-07-24'
GROUP BY gametype
ORDER BY 来源表, 笔数 DESC;


-- ---- 诊断3：两表的会员(bet05)是否高度重合 ----
-- 如果是同一批人在打不同产品(真人+电子)，会员应该大量重合；
-- 如果连人都不重合，那更可能是完全独立的两套系统/产品线
WITH bet01_uid AS (SELECT DISTINCT bet05 FROM ods_mariadb_2b.ods_a168_bet01 WHERE dt = '2026-07-24'),
     bet02_uid AS (SELECT DISTINCT bet05 FROM ods_mariadb_2b.ods_a168_bet02 WHERE dt = '2026-07-24')
SELECT
    (SELECT COUNT(*) FROM bet01_uid) AS bet01当日会员数,
    (SELECT COUNT(*) FROM bet02_uid) AS bet02当日会员数,
    (SELECT COUNT(*) FROM bet01_uid a JOIN bet02_uid b ON a.bet05 = b.bet05) AS 会员重合数;
