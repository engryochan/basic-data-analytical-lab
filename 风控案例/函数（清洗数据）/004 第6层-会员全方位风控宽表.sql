WITH member_bet AS (

    SELECT

        CAST(bet05 AS BIGINT) AS member_id,

        COUNT(DISTINCT bet01) AS bet_count,

        COUNT(DISTINCT bet03) AS session_count,

        SUM(
            CASE
                WHEN bet30 IS NULL
                  OR bet30 <> 'Y'
                THEN CAST(bet13 AS DECIMAL(20,4))
                ELSE 0
            END
        ) AS valid_bet_amount,

        SUM(
            CAST(bet13 AS DECIMAL(20,4))
        ) AS gross_bet_amount,

        AVG(
            CAST(bet13 AS DECIMAL(20,4))
        ) AS avg_bet_amount,

        MAX(
            CAST(bet13 AS DECIMAL(20,4))
        ) AS max_single_bet,

        COUNT(DISTINCT dt) AS active_days,

        COUNT(DISTINCT bet31) AS table_count,

        COUNT(DISTINCT bet32) AS room_count,

        COUNT(DISTINCT eid) AS dealer_count,

        COUNT(DISTINCT ip) AS ip_count,

        COUNT(DISTINCT betwalletid) AS wallet_count,

        MIN(CAST(bet08 AS DATETIME))
            AS first_bet_time,

        MAX(CAST(bet08 AS DATETIME))
            AS last_bet_time,

        SUM(
            CASE
                WHEN bet30 IS NULL
                  OR bet30 <> 'Y'
                THEN
                    CAST(bet13 AS DECIMAL(20,4))
                    *
                    CAST(bet14 AS DECIMAL(20,8))
                ELSE 0
            END
        ) AS estimated_rebate

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'

    GROUP BY

        CAST(bet05 AS BIGINT)
)

SELECT

    *,

    DATEDIFF(
        last_bet_time,
        first_bet_time
    ) AS observed_lifetime_days,

    CASE

        WHEN active_days >= 30
         AND valid_bet_amount >= 100000
        THEN 'A_高价值活跃'

        WHEN active_days >= 15
         AND valid_bet_amount >= 50000
        THEN 'B_高价值'

        WHEN active_days >= 7
         AND valid_bet_amount >= 10000
        THEN 'C_中价值'

        WHEN active_days >= 3
        THEN 'D_低活跃'

        ELSE 'E_新/低频'

    END AS value_segment

FROM member_bet;
