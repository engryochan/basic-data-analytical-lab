-- ============================================================================
-- LTV_004_修复与复核.sql
-- 1) 修复报错："Column '平台净贡献' cannot be resolved"
-- 2) 复核两个从验证结果里看出来的疑点：总返水成本恒为0、量级异常巨大
--    ——这两点不解决，就算SQL能跑，数字也不能信，跟修bug是两件独立的事。
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 【修复】原第2节的报错，是因为占位子查询x只算了"会员净贡献占位"，
-- 根本没有名叫"平台净贡献"和"平台ROI"的列——这正是原文件注释里提前
-- 写明的"偷懒写法仅作示意"那部分。这里换成正式做法：先落地中间表，
-- 第2节从表里读，不再重复内联整段第1节逻辑（也是原注释建议的方案）。
-- ----------------------------------------------------------------------------

-- 4a. 先把第1节完整逻辑落地成中间表（跑一次即可，之后第2节直接复用）
-- CREATE TABLE dwd.会员LTV AS
-- (把 LTV_003 第1节从 WITH 会员日粒度 一直到 LTV计算 的完整逻辑原样搬过来，
--  最后 SELECT uid, 平台净贡献, 平台ROI, 净贡献十分位_1最高 FROM LTV计算)
-- 在拿到下面4b、4c两个疑点的复核结果之前，不建议真的建这张表——建了也是
-- 建在两个疑点之上，等于把不确定的数字固化下来。

-- 4b. 价值×风险矩阵——桥接好之后的正式写法（先跑通4b/4c再启用）
-- SELECT
--     l.uid, l.净贡献十分位_1最高, l.平台ROI,
--     CASE WHEN r.uid IS NOT NULL THEN '高置信度行为风险' ELSE '未触发' END AS 行为风险标记,
--     CASE
--         WHEN l.净贡献十分位_1最高 <= 2 AND r.uid IS NOT NULL THEN '优先人工复核+回查录像'
--         WHEN l.净贡献十分位_1最高 >  2 AND r.uid IS NOT NULL THEN '按SOP直接限制返水/冻结排查'
--         WHEN l.净贡献十分位_1最高 <= 2 AND r.uid IS NULL      THEN '重点维护，差异化权益'
--         ELSE '常规监控'
--     END AS 建议动作
-- FROM dwd.会员LTV l
-- LEFT JOIN dwd.风控高置信度名单 r ON l.uid = r.uid
-- ORDER BY l.净贡献十分位_1最高, l.平台ROI DESC;


-- ============================================================================
-- 【疑点1】总返水成本在明细结果里全是0.0000——不是变小，是恰好为零
-- 跟第0节校验里 LV1退水_均值=0.0287 放在一起看，这个均值本身也更像"费率"
-- 不是"金额"：同一份校验里 有效投注/下注额_均值=0.9346，是个正常比值；
-- 0.0287 数量级跟它接近，但下注/派彩动辄百亿千亿——一个真金额字段不该
-- 均值只有0.03。先查清楚，再决定要不要用它当返水成本。
-- ============================================================================
SELECT
    COUNT(*)                                                                  AS 总行数,
    SUM(CASE WHEN bet28 IS NULL AND bet29 IS NULL AND bet30 IS NULL
              AND bet31 IS NULL AND bet32 IS NULL THEN 1 ELSE 0 END)          AS 五级退水全部为NULL的行数,
    SUM(CASE WHEN COALESCE(CAST(bet28 AS DECIMAL(18,4)),0)
                + COALESCE(CAST(bet29 AS DECIMAL(18,4)),0)
                + COALESCE(CAST(bet30 AS DECIMAL(18,4)),0)
                + COALESCE(CAST(bet31 AS DECIMAL(18,4)),0)
                + COALESCE(CAST(bet32 AS DECIMAL(18,4)),0) = 0
             THEN 1 ELSE 0 END)                                                AS 五级退水合计恰好为零的行数,
    MAX(CAST(bet28 AS DECIMAL(18,4)))                                         AS bet28最大值,
    -- 关键对照：如果bet28是"费率"，它应该跟下注额相乘才是真实退水金额
    ROUND(AVG(CAST(bet28 AS DECIMAL(18,4)) * CAST(bet13 AS DECIMAL(18,4))), 2) AS 若bet28是费率_乘以下注额后的均值
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24';


-- ============================================================================
-- 【疑点2】量级异常——dailyreport_member算出来的总下注额，比bet01同期同一批
-- 会员的总投注额大出六七个数量级(千亿 vs 万级别)，需要先确认是不是同一
-- 币种/单位，或者dailyreport_member是不是本身就有重复计数(fan-out)问题。
-- ============================================================================
WITH bet01日汇总 AS (
    SELECT bet05 AS uid, dt, SUM(bet12) AS bet01_当日投注额
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY bet05, dt
),
daily报表 AS (
    SELECT CAST(bet05 AS BIGINT) AS uid, dt, CAST(bet13 AS DECIMAL(18,4)) AS daily_下注金额
    FROM ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
)
SELECT
    a.uid, a.dt, a.bet01_当日投注额, d.daily_下注金额,
    ROUND(d.daily_下注金额 / NULLIF(a.bet01_当日投注额, 0), 2) AS 倍数差异
FROM bet01日汇总 a
JOIN daily报表 d ON a.uid = d.uid AND a.dt = d.dt
ORDER BY 倍数差异 DESC
LIMIT 20;
-- 看倍数差异这一列：如果20行里数字很集中(比如都在9000~11000倍附近)，
-- 大概率是单位换算问题(比如"分"vs"元"，或者点数系统)，乘/除一个固定
-- 系数就能对齐；如果倍数忽大忽小、毫无规律，大概率是dailyreport_member
-- 这张表本身有重复行/JOIN放大的问题，不是简单换算能解决的，需要单独排查
-- 这张表的数据生成逻辑(它是不是本来就该按uid+dt去重，或者本身就是多来源
-- 汇总导致重复)。
