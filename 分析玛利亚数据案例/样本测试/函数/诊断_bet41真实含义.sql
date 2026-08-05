SET query_timeout = 1800;

-- ---- 诊断5：bet41真实数值分布——是否呈现"盈亏"该有的特征(有正有负，
-- 或者跟投注额不是同一个量级) ----
SELECT
    MIN(CAST(bet41 AS DOUBLE)) AS 最小值,
    MAX(CAST(bet41 AS DOUBLE)) AS 最大值,
    AVG(CAST(bet41 AS DOUBLE)) AS 平均值,
    SUM(CASE WHEN CAST(bet41 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS 负数出现次数,
    SUM(CASE WHEN CAST(bet41 AS DOUBLE) > 0 THEN 1 ELSE 0 END) AS 正数出现次数,
    SUM(CASE WHEN CAST(bet41 AS DOUBLE) = 0 THEN 1 ELSE 0 END) AS 零值出现次数
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt = '2026-07-24';


-- ---- 诊断6：抽10个真实样本，把dailyreport_member的关键字段跟对应会员
-- 当天在bet01里的真实投注额放一起对照，看bet41是不是"盈亏"该有的量级
-- (比如远小于投注额、可正可负，符合"庄家抽成后的净输赢"这个特征) ----
SELECT
    d.bet05 AS uid,
    d.count AS 日报_订单数,
    d.orders AS 日报_orders字段,
    CAST(d.bet13 AS DOUBLE) AS 日报_bet13,
    CAST(d.bet41 AS DOUBLE) AS 日报_bet41,
    d.risk AS 日报_risk标记,
    b.真实投注额合计,
    b.真实订单数
FROM ods_mariadb_2b.ods_a168_dailyreport_member d
JOIN (
    SELECT bet05, SUM(CAST(bet12 AS DOUBLE)) AS 真实投注额合计, COUNT(*) AS 真实订单数
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt = '2026-07-24'
    GROUP BY bet05
) b ON d.bet05 = b.bet05
WHERE d.dt = '2026-07-24'
ORDER BY b.真实投注额合计 DESC
LIMIT 10;
