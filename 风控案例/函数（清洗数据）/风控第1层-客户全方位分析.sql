WITH customer360 AS (

SELECT

    bet05                                          AS member_id,

    MIN(CAST(bet08 AS DATETIME))                   AS first_bet,

    MAX(CAST(bet08 AS DATETIME))                   AS last_bet,

    DATEDIFF(MAX(CAST(bet08 AS DATE)),
             MIN(CAST(bet08 AS DATE))) + 1         AS lifetime_days,

    COUNT(*)                                       AS total_bets,

    COUNT(DISTINCT CAST(bet08 AS DATE))            AS active_days,

    SUM(CAST(bet13 AS DECIMAL(18,4)))              AS total_turnover,

    AVG(CAST(bet13 AS DECIMAL(18,4)))              AS avg_bet,

    MAX(CAST(bet13 AS DECIMAL(18,4)))              AS max_bet,

    MIN(CAST(bet13 AS DECIMAL(18,4)))              AS min_bet,

    COUNT(DISTINCT bet02)                          AS game_types,

    COUNT(DISTINCT bet03)                          AS matches,

    COUNT(DISTINCT bet31)                          AS tables,

    COUNT(DISTINCT bet32)                          AS rooms,

    COUNT(DISTINCT ip)                             AS ip_count,

    AVG(CAST(bet14 AS DECIMAL(8,4)))               AS rebate_rate,

    SUM(
        CAST(bet13 AS DECIMAL(18,4))
        *
        CAST(bet14 AS DECIMAL(8,4))/100
    )                                              AS estimated_rebate

FROM ods_mariadb_2b.ods_a168_bet01

WHERE bet30='N'

GROUP BY bet05

)

SELECT *
FROM customer360;