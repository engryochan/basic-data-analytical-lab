-- ==============================================================================
-- 补齐候选名单_第2~4路.sql
-- ==============================================================================
-- 已完成：候选_同桌异常 = 62,245人（已验证：这是173,529,760行全量数据算出
-- 来的结果，零采样误差，不用重跑）
--
-- 下面三路都是单表GROUP BY聚合，不涉及自连接（不是"每一行跟每一行比"，
-- 是"每一行只处理一次"），计算复杂度比同桌异常那个自连接低一个量级，
-- 预期在173.5M行规模下应该是几十秒到几分钟量级，不需要分月拆分，
-- 直接在全量range上跑一次即可。
--
-- 【保险起见】仍然把 SET query_timeout 放在同一次执行里，防止万一比预期慢
-- ==============================================================================

SET query_timeout = 1800;

-- ---- 候选_投注异常：策略性投注 + 高流水，单表聚合，无JOIN ----
WITH 候选_投注异常 AS (
    SELECT CAST(bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'          -- 覆盖全部126天真实数据
    GROUP BY CAST(bet05 AS BIGINT)
    HAVING COUNT(*) > 50
       AND (
            SUM(CAST(bet12 AS DOUBLE)) > 100000
            OR AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50
           )
)
SELECT COUNT(*) AS 投注异常候选数 FROM 候选_投注异常;


-- ---- 候选_荷官关联：单表GROUP BY(eid, bet05)，无JOIN ----
SET query_timeout = 1800;
WITH 候选_荷官关联 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
)
SELECT COUNT(*) AS 荷官关联候选数 FROM 候选_荷官关联;


-- ---- 候选_系统标记：risklist本身只有9,958行，全量导出秒回 ----
-- ⚠️ 请先确认risklist真实的会员字段名（用之前验证过的方法查一下，
-- 不要直接假设它也叫bet05——这张表的glimpse元数据/字段结构此前没有
-- 像bet01那样逐列核实过）：
SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ods_mariadb_2b' AND table_name = 'ods_a168_risklist'
ORDER BY ordinal_position;


-- ==============================================================================
-- 三路结果都拿到手之后，最后合并成最终候选名单（把已知的62,245人同桌异常
-- 也纳入同一个UNION，一次性产出唯一权威名单）：
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
候选_同桌异常 AS (
    SELECT DISTINCT CAST(a.bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY a.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50
    -- 注：这段已经实测跑通过，耗时约12.7分钟，62,245人——重跑一次会
    -- 再花同样的时间，如果Superset支持把已有结果存成临时表/视图，
    -- 可以考虑直接复用上次的62,245人清单，不用重新算一次
),
候选_荷官关联 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
),
候选_系统标记 AS (
    -- 待确认risklist真实字段名后，把下面的bet05换成真实列名
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid FROM ods_mariadb_2b.ods_a168_risklist
)
SELECT
    (SELECT COUNT(*) FROM 候选_投注异常) AS 投注异常候选数,
    (SELECT COUNT(*) FROM 候选_同桌异常) AS 同桌异常候选数,
    (SELECT COUNT(*) FROM 候选_荷官关联) AS 荷官关联候选数,
    (SELECT COUNT(*) FROM 候选_系统标记) AS 系统标记候选数,
    (SELECT COUNT(*) FROM (
        SELECT uid FROM 候选_投注异常
        UNION SELECT uid FROM 候选_同桌异常
        UNION SELECT uid FROM 候选_荷官关联
        UNION SELECT uid FROM 候选_系统标记
    ) t) AS 最终去重候选总数;
