-- ============================================================================
-- LTV_006_bet05是否同一套ID体系.sql
-- ============================================================================
-- 判断依据很简单：如果dailyreport_member.bet05 跟 bet01.bet05 是同一个人，
-- 两边同一天的"下注笔数"应该大致对得上（不需要完全相等，但不该差几个数量级）。
-- 用上一轮已知的具体例子(103517820, 2026-07-17)先验证，再扩大到一批样本。
-- ============================================================================

-- 6a. 单点验证：103517820 在 bet01 里这天到底下了几笔、共多少钱
SELECT
    COUNT(*)      AS bet01_真实笔数,
    SUM(bet12)    AS bet01_真实投注额
FROM ods_mariadb_2b.ods_a168_bet01
WHERE bet05 = '103517820' AND dt = '2026-07-17';
-- 对照组：dailyreport_member最终快照(2026-07-17 12:24:09之后任一条)显示 count=400。
-- 如果这里查出来的bet01_真实笔数不是几百这个量级(大概率是个位数)，
-- 基本可以确认两边bet05不是同一个人/同一套编号。

-- 6b. 扩大到20个样本，看这个"笔数对不上"是不是普遍现象，而非103517820个例
WITH bet01笔数 AS (
    SELECT bet05 AS uid, dt, COUNT(*) AS bet01_笔数, SUM(bet12) AS bet01_投注额
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt = '2026-07-17'
    GROUP BY bet05, dt
),
daily最终快照 AS (
    SELECT uid, dt, count, bet13
    FROM (
        SELECT
            CAST(bet05 AS BIGINT) AS uid, dt, count, bet13,
            ROW_NUMBER() OVER (PARTITION BY bet05, dt ORDER BY sync_time DESC) AS rn
        FROM ods_mariadb_2b.ods_a168_dailyreport_member
        WHERE dt = '2026-07-17'
    ) t
    WHERE rn = 1
)
SELECT
    a.uid, a.bet01_笔数, a.bet01_投注额,
    d.count AS daily_笔数, d.bet13 AS daily_金额,
    ROUND(d.count / NULLIF(a.bet01_笔数, 0), 1) AS 笔数倍差
FROM bet01笔数 a
JOIN daily最终快照 d ON a.uid = d.uid AND a.dt = d.dt
ORDER BY 笔数倍差 DESC
LIMIT 20;
-- 如果"笔数倍差"普遍是几十、几百倍，基本坐实bet05不是同一套ID体系
-- (或者dailyreport_member统计的范围比单个会员更大，比如含下级代理)——
-- 这种情况建议直接把"dailyreport_member.bet05到底代表什么"当成正式问题
-- 转给工程side/表的owner去回答，不建议继续靠猜字段含义往下查，
-- 跟game_result、wallet_dtl那两个缺口一样处理：记录清楚、正式提出去。
