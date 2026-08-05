SET query_timeout = 1800;

-- ---- 诊断6：bet02独有9个新字段 + resultwalletid 的取值分布——
-- 真正的盈亏字段必须同时有正数和负数(有人赢有人输)，这是最快的筛选标准 ----
SELECT
    MIN(CAST(bet33 AS DOUBLE)) AS bet33_min, MAX(CAST(bet33 AS DOUBLE)) AS bet33_max,
    SUM(CASE WHEN CAST(bet33 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet33_负数次数,
    MIN(CAST(bet34 AS DOUBLE)) AS bet34_min, MAX(CAST(bet34 AS DOUBLE)) AS bet34_max,
    SUM(CASE WHEN CAST(bet34 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet34_负数次数,
    MIN(CAST(bet35 AS DOUBLE)) AS bet35_min, MAX(CAST(bet35 AS DOUBLE)) AS bet35_max,
    SUM(CASE WHEN CAST(bet35 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet35_负数次数
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt = '2026-07-24';


-- ---- 诊断7：bet36~bet41 同样的检查(拆成两条，避免单条太宽) ----
SELECT
    MIN(CAST(bet36 AS DOUBLE)) AS bet36_min, MAX(CAST(bet36 AS DOUBLE)) AS bet36_max,
    SUM(CASE WHEN CAST(bet36 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet36_负数次数,
    MIN(CAST(bet37 AS DOUBLE)) AS bet37_min, MAX(CAST(bet37 AS DOUBLE)) AS bet37_max,
    SUM(CASE WHEN CAST(bet37 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet37_负数次数,
    MIN(CAST(bet38 AS DOUBLE)) AS bet38_min, MAX(CAST(bet38 AS DOUBLE)) AS bet38_max,
    SUM(CASE WHEN CAST(bet38 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet38_负数次数,
    MIN(CAST(bet39 AS DOUBLE)) AS bet39_min, MAX(CAST(bet39 AS DOUBLE)) AS bet39_max,
    SUM(CASE WHEN CAST(bet39 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet39_负数次数,
    MIN(CAST(bet40 AS DOUBLE)) AS bet40_min, MAX(CAST(bet40 AS DOUBLE)) AS bet40_max,
    SUM(CASE WHEN CAST(bet40 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet40_负数次数,
    MIN(CAST(bet41 AS DOUBLE)) AS bet41_min, MAX(CAST(bet41 AS DOUBLE)) AS bet41_max,
    SUM(CASE WHEN CAST(bet41 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS bet41_负数次数
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt = '2026-07-24';


-- ---- 诊断8：resultwalletid 是什么类型的字段(钱包ID还是金额？) + 抽样看内容 ----
SELECT resultwalletid, betwalletid, COUNT(*) AS 出现次数
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt = '2026-07-24'
GROUP BY resultwalletid, betwalletid
ORDER BY 出现次数 DESC
LIMIT 15;


-- ---- 诊断9：把最可能是盈亏的候选字段，跟已知的投注额(bet12)放一起
-- 对照10笔真实交易，看数值关系是否符合"派彩-投注=盈亏"这个逻辑 ----
SELECT
    bet01 AS 交易id, bet05 AS 会员, bet09 AS 投注选项, bet11 AS 赔率,
    CAST(bet12 AS DOUBLE) AS 投注额,
    CAST(bet33 AS DOUBLE) AS bet33, CAST(bet34 AS DOUBLE) AS bet34,
    CAST(bet35 AS DOUBLE) AS bet35, CAST(bet36 AS DOUBLE) AS bet36,
    CAST(bet37 AS DOUBLE) AS bet37, CAST(bet38 AS DOUBLE) AS bet38,
    CAST(bet39 AS DOUBLE) AS bet39, CAST(bet40 AS DOUBLE) AS bet40,
    CAST(bet41 AS DOUBLE) AS bet41
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt = '2026-07-24'
LIMIT 15;
