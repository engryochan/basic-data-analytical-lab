SET query_timeout = 1800;

-- ---- 诊断14：log_age_cash_change.lacc03 与 bet01.bet05 是否是同一套编号 ----
-- 如果重合率高，说明lacc03就是会员ID，lacc06这个真正带正负号的字段
-- 就是会员级别的真实资金变动——这将是两轮排查以来第一个可信候选
WITH lacc_ids AS (
    SELECT DISTINCT lacc03 AS id FROM ods_mariadb_2b.ods_a168_log_age_cash_change
    WHERE dt = '2026-07-24'
),
bet_uid AS (
    SELECT DISTINCT bet05 AS id FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt = '2026-07-24'
)
SELECT
    (SELECT COUNT(*) FROM lacc_ids) AS lacc03当日去重数,
    (SELECT COUNT(*) FROM bet_uid) AS bet05当日去重数,
    (SELECT COUNT(*) FROM lacc_ids a JOIN bet_uid b ON a.id = b.id) AS 两者重合数;


-- ---- 诊断15：lacc06全量取值分布——确认正负数都是真实存在的大量样本，
-- 不是极少数噪音 ----
SELECT
    MIN(CAST(lacc06 AS DOUBLE)) AS lacc06_min,
    MAX(CAST(lacc06 AS DOUBLE)) AS lacc06_max,
    AVG(CAST(lacc06 AS DOUBLE)) AS lacc06_平均值,
    SUM(CASE WHEN CAST(lacc06 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS 负数次数,
    SUM(CASE WHEN CAST(lacc06 AS DOUBLE) > 0 THEN 1 ELSE 0 END) AS 正数次数,
    SUM(CASE WHEN CAST(lacc06 AS DOUBLE) = 0 THEN 1 ELSE 0 END) AS 零值次数
FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt = '2026-07-24';


-- ---- 诊断16：把某个已知在候选名单里的真实会员，拿去lacc03里查，
-- 看看能不能查到这个人具体的资金变动记录(用双重命中名单里的第一个uid测试) ----
SELECT dt, lacc03, lacc06, lacc07, lacc09, lacc10, lacc11
FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt = '2026-07-24' AND lacc03 = '148997934'
ORDER BY lacc07
LIMIT 20;
