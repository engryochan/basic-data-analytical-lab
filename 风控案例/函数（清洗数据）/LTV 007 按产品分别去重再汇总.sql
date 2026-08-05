-- ============================================================================
-- LTV_007_按产品分别去重再汇总.sql
-- ============================================================================
-- 上一轮去重只按 bet05+dt 取最新快照，但同一天很可能有多个 game_type(bet02)，
-- 各自有一串快照——先按 bet05+dt+bet02 分别取最新，再跨 game_type 相加，
-- 才是"这个会员这一天全部产品加总"的真实值。这是目前最可能的解释，
-- 但仍需要这一步验证：如果修正后倍差普遍收敛到1附近，说明找对了；
-- 如果还是乱的，就不建议再猜下去，直接把"dailyreport_member真实口径"
-- 当成正式问题转给表owner，跟game_result/wallet_dtl一样处理。
-- ============================================================================

WITH bet01笔数 AS (
    SELECT bet05 AS uid, dt, COUNT(*) AS bet01_笔数, SUM(bet12) AS bet01_投注额
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt = '2026-07-17'
    GROUP BY bet05, dt
),
逐游戏最终快照 AS (
    SELECT
        bet05, dt, bet02,
        CAST(bet13 AS DECIMAL(18,4)) AS bet13,
        CAST(count AS BIGINT)        AS cnt,
        ROW_NUMBER() OVER (PARTITION BY bet05, dt, bet02 ORDER BY sync_time DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE dt = '2026-07-17'
),
会员日汇总_跨产品 AS (
    SELECT
        CAST(bet05 AS BIGINT) AS uid, dt,
        SUM(bet13)            AS daily_金额_跨产品汇总,
        SUM(cnt)              AS daily_笔数_跨产品汇总,
        COUNT(DISTINCT bet02) AS 当天涉及产品数
    FROM 逐游戏最终快照
    WHERE rn = 1
    GROUP BY bet05, dt
)
SELECT
    a.uid, a.bet01_笔数, a.bet01_投注额,
    d.daily_笔数_跨产品汇总, d.daily_金额_跨产品汇总, d.当天涉及产品数,
    ROUND(d.daily_笔数_跨产品汇总 / NULLIF(a.bet01_笔数, 0), 2) AS 笔数倍差_修正后
FROM bet01笔数 a
JOIN 会员日汇总_跨产品 d ON a.uid = d.uid AND a.dt = d.dt
ORDER BY 笔数倍差_修正后 DESC;
-- 不加LIMIT——上一轮完整样本比只看前20行更有说服力，这次同样看全貌：
-- 倍差是不是普遍收敛到比较靠近1的范围（比如大多数落在0.5~3之间），
-- 还是仍然从个位数漫延到几百倍。前者说明找对了取数逻辑，直接可用；
-- 后者说明问题不在取数逻辑，该正式转给工程side问清楚了。

-- 顺手验证 103517820 这个已知例子，修正后是否合理：
SELECT bet05, dt, bet02, bet13, count, sync_time
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE bet05 = '103517820' AND dt = '2026-07-17'
ORDER BY bet02, sync_time;
-- 如果这个人当天其实还有别的bet02，之前只看到108是因为105那批快照
-- 恰好同步得比其它game_type都晚——这里能直接看出来。
