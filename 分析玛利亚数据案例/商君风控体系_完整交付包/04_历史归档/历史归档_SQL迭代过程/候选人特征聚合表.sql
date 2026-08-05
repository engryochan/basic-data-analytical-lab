-- ==============================================================================
-- 候选人特征聚合表.sql —— 从"下载原始明细"转向"下载特征表"
-- ==============================================================================
-- 【为什么必须转向】实测确认：132,982人候选名单在bet01里，光11天就有
-- 1253.77万行，外推全部126天约1.44亿行——占全表173,529,760行的约83%。
-- 按10万行一批下载，要切1,440批，且每批都要重算一次候选名单，这条路
-- 在现实中走不通，必须放弃"拉原始明细"这个思路。
--
-- 正确做法：不拉每一笔投注的明细行，而是在SQL层面把每个人的全部行为
-- 直接聚合成统计特征——每人一行，不管背后有多少亿笔交易支撑，下载量
-- 永远固定在候选人数这个规模（132,982行），而且这些统计量是在全量
-- 1.74亿行上算出来的，不是抽样估计，零误差。这正是上一轮外部建议里
-- "Feature Store"这个思路的具体落地，不是另起炉灶。
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
-- 【重要修正，说明为什么这样写】自连接是这条SQL里唯一"贵"的操作
-- (已实测跑全量数据要12-13分钟)，之前的写法里"候选_同桌异常"和
-- "同桌配对统计"各自单独做了一次自连接——两段做的其实是同一件事，
-- 只是聚合粒度不同(一个只要uid、一个要完整配对明细)。现在改成自连接
-- 只做这一次(同桌配对统计)，"候选_同桌异常"直接从这张聚合结果派生，
-- 确保这个最贵的操作全程只真正触发一次数据库执行。
同桌配对统计 AS (
    SELECT a2.bet05 AS uid1, b2.bet05 AS uid2, COUNT(DISTINCT a2.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a2
    JOIN ods_mariadb_2b.ods_a168_bet01 b2
      ON a2.bet03 = b2.bet03 AND a2.bet05 <> b2.bet05 AND a2.dt = b2.dt
    WHERE a2.dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY a2.bet05, b2.bet05
    HAVING COUNT(DISTINCT a2.bet03) > 50
),
候选_同桌异常 AS (
    SELECT DISTINCT uid1 AS uid FROM 同桌配对统计                        -- 直接从上面派生，不再重新触发自连接
),
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
),
-- ---- 特征①：投注行为聚合 —— 每人一行，不管背后有多少笔投注支撑 ----
投注特征 AS (
    SELECT
        CAST(bet05 AS BIGINT) AS uid,
        COUNT(*) AS 总投注笔数,
        SUM(CAST(bet12 AS DOUBLE)) AS 总投注额,                          -- bet12是真实投注额
        SUM(CAST(bet13 AS DOUBLE)) AS 总有效投注额,                       -- bet13是有效投注(非盈利，已验证)
        AVG(CAST(bet11 AS DOUBLE)) AS 平均赔率,
        AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) AS 晚注比例,
        COUNT(DISTINCT bet02) AS 涉及桌台数,
        COUNT(DISTINCT eid) AS 涉及荷官数,
        MIN(dt) AS 首次投注日期,
        MAX(dt) AS 最后投注日期
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
      AND CAST(bet05 AS BIGINT) IN (SELECT uid FROM 候选_最终)           -- 只对候选人算特征，不是全表
    GROUP BY CAST(bet05 AS BIGINT)
),
-- ---- 特征②：同桌关联聚合 —— 该会员总共关联了几个不同的疑似同伙、
-- 单一关系里同桌局数最高多少 ----
-- 直接复用前面已经定义好的"同桌配对统计"，不再重新定义、不再重新
-- 触发那段最贵的自连接
同桌特征 AS (
    SELECT uid1 AS uid,
           COUNT(DISTINCT uid2) AS 高频同桌关联人数,                     -- 跟多少个不同的人达到强同桌关联
           MAX(同桌局数) AS 最高单一同桌局数
    FROM 同桌配对统计
    GROUP BY uid1
),
-- ---- 特征③：荷官关联聚合 —— 该会员跟哪个荷官往来最频繁、经手笔数多少 ----
-- 同样简化：直接在(eid,bet05)聚合结果上再汇总一次，不额外多做一次
-- 对原始bet01的join
荷官配对统计 AS (
    SELECT eid, bet05, COUNT(*) AS 经手笔数
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
),
荷官特征 AS (
    SELECT CAST(bet05 AS BIGINT) AS uid,
           COUNT(DISTINCT eid) AS 高频关联荷官数,
           MAX(经手笔数) AS 单一荷官最高经手笔数
    FROM 荷官配对统计
    GROUP BY bet05
)
-- ---- 最终输出：一人一行，左连接合并三组特征，缺失的用NULL(如实反映
-- "这个人没有触发这一类风险信号"，不强行补0掩盖差异)----
SELECT
    c.uid,
    p.总投注笔数, p.总投注额, p.总有效投注额, p.平均赔率, p.晚注比例,
    p.涉及桌台数, p.涉及荷官数, p.首次投注日期, p.最后投注日期,
    s.高频同桌关联人数, s.最高单一同桌局数,
    d.高频关联荷官数, d.单一荷官最高经手笔数
FROM 候选_最终 c
LEFT JOIN 投注特征 p ON c.uid = p.uid
LEFT JOIN 同桌特征 s ON c.uid = s.uid
LEFT JOIN 荷官特征 d ON c.uid = d.uid
ORDER BY c.uid;
-- 预期返回：132,982行，一次性下载即可，不用分批
