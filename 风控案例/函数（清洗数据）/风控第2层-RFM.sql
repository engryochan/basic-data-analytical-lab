SELECT

bet05 AS member_id,

DATEDIFF(CURRENT_DATE,
MAX(CAST(bet08 AS DATE))) AS Recency,

COUNT(*) AS Frequency,

SUM(CAST(bet13 AS DECIMAL(18,4))) AS Monetary

FROM ods_mariadb_2b.ods_a168_bet01

WHERE bet30='N'

GROUP BY bet05;
