WITH bet_base AS (

    SELECT

        CAST(bet05 AS BIGINT) AS member_id,
        bet01 AS bet_id,
        bet03 AS round_id,
        bet31 AS table_id,
        bet32 AS room_id,
        eid AS dealer_id,
        ip,
        betwalletid AS wallet_id,
        bet08 AS bet_time,
        bet13 AS bet_amount,
        bet14 AS rebate_rate,
        bet30 AS cancel_flag,
        dt

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01'
                  AND '2026-03-31'
),

member_bet_behavior AS (

    SELECT

        member_id,

        COUNT(DISTINCT bet_id) AS bet_count,

        COUNT(DISTINCT round_id) AS round_count,

        COUNT(DISTINCT dt) AS active_days,

        COUNT(DISTINCT table_id) AS table_count,

        COUNT(DISTINCT room_id) AS room_count,

        COUNT(DISTINCT dealer_id) AS dealer_count,

        COUNT(DISTINCT ip) AS ip_count,

        COUNT(DISTINCT wallet_id) AS wallet_count,

        SUM(
            CASE
                WHEN cancel_flag IS NULL
                  OR cancel_flag <> 'Y'
                THEN CAST(bet_amount AS DECIMAL(20,8))
                ELSE 0
            END
        ) AS total_bet_amount,

        AVG(
            CAST(rebate_rate AS DECIMAL(20,8))
        ) AS avg_rebate_rate,

        MIN(dt) AS first_bet_date,

        MAX(dt) AS last_bet_date

    FROM bet_base

    GROUP BY member_id
)

SELECT *
FROM member_bet_behavior;
