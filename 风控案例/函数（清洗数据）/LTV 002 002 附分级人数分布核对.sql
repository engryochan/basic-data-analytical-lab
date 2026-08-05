-- ============================================================================
-- LTV_002_附_分级人数分布核对.sql
-- 只看每个分级有多少人、RFM总分的分布，用来确认导出被截断的怀疑，
-- 不用重新导出全量明细。
-- ============================================================================

WITH 会员行为基础 AS (
    SELECT
        bet05                                      AS uid,
        COUNT(DISTINCT bet03)                       AS 总局数,
        COUNT(DISTINCT dt)                          AS 活跃天数,
        SUM(bet13)                                  AS 总有效投注额,
        DATEDIFF('2026-07-24', MAX(dt))             AS 距今未活跃天数
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY bet05
),
RFM打分 AS (
    SELECT
        b.*,
        NTILE(5) OVER (ORDER BY b.距今未活跃天数 ASC)  AS R_score,
        NTILE(5) OVER (ORDER BY b.活跃天数 ASC)        AS F_score,
        NTILE(5) OVER (ORDER BY b.总有效投注额 ASC)     AS M_score
    FROM 会员行为基础 b
),
价值分级 AS (
    SELECT *, (R_score + F_score + M_score) AS RFM总分,
        CASE
            WHEN R_score + F_score + M_score >= 13 THEN '钻石会员'
            WHEN R_score + F_score + M_score >= 10 THEN '黄金会员'
            WHEN R_score + F_score + M_score >= 7  THEN '白银会员'
            WHEN R_score + F_score + M_score >= 4  THEN '普通会员'
            ELSE '沉睡_流失会员'
        END AS 价值分级
    FROM RFM打分
)
SELECT 价值分级, COUNT(*) AS 人数, MIN(RFM总分) AS 最低分, MAX(RFM总分) AS 最高分
FROM 价值分级
GROUP BY 价值分级
ORDER BY 最高分 DESC;
-- 五个分级都应该各有人数（哪怕不均等），如果这里也是"只有钻石会员"，
-- 那才是分级逻辑真的有问题；如果这里五档都有合理人数，
-- 就纯粹是上次导出截断的问题，回去检查客户端/导出设置的行数上限即可。
