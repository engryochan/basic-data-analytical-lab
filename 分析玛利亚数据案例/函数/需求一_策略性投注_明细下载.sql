-- ==============================================================================
-- 需求一_策略性投注_明细下载.sql
-- ==============================================================================
-- 之前只在全量1.74亿行上算过候选人数(118,946人)，没拉过每个人具体的
-- 晚注比例/投注笔数明细——这次补上，为后续套用图论/贝叶斯/XGBoost这套
-- 已在"团伙同桌"验证过的建模流程做准备。
--
-- 这条查询是单表GROUP BY，没有自连接，预期在1.74亿行全量上是秒级到
-- 几十秒完成，不需要像"团伙同桌"那样按月分批。
-- ==============================================================================

SET query_timeout = 1800;

SELECT
    CAST(bet05 AS BIGINT) AS uid,
    COUNT(*) AS 总投注笔数,
    SUM(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1 ELSE 0 END) AS 晚注笔数,
    AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) AS 晚注比例,
    SUM(CAST(bet12 AS DOUBLE)) AS 总投注额,
    AVG(CAST(bet11 AS DOUBLE)) AS 平均赔率,
    COUNT(DISTINCT bet02) AS 涉及桌台数,
    COUNT(DISTINCT eid) AS 涉及荷官数
FROM ods_mariadb_2b.ods_a168_bet01
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
GROUP BY CAST(bet05 AS BIGINT)
HAVING COUNT(*) > 100                                        -- 与需求一原始定义一致：订单数>100
   AND AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) >= 0.70;  -- 晚注比例≥70%
-- 下载为：策略性投注_候选明细.csv
-- 预期行数：应接近之前全量验证过的118,946人（口径略有差异，之前候选名单
-- 阈值放宽到>50笔+50%比例做广撒网，这次是最终版>100笔+70%比例的精确口径）
