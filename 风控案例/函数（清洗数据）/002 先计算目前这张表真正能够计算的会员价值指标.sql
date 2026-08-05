WITH bet_base AS (

    SELECT
        bet01 AS bet_id,
        CAST(bet05 AS BIGINT) AS member_id,
        CAST(bet03 AS BIGINT) AS session_id,
        CAST(bet06 AS DATETIME) AS game_time,
        CAST(bet08 AS DATETIME) AS bet_time,
        CAST(bet07 AS DATE) AS account_date,

        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,
        CAST(bet14 AS DECIMAL(20,6)) AS rebate_rate,

        bet30 AS cancel_flag,

        CAST(bet31 AS BIGINT) AS table_id,
        CAST(bet32 AS BIGINT) AS room_id,

        CAST(eid AS BIGINT) AS dealer_id,

        ip,
        betwalletid AS wallet_id,

        dt

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'
),

member_value AS (

    SELECT

        member_id,

        COUNT(DISTINCT bet_id) AS bet_count,

        SUM(bet_amount) AS total_bet_amount,

        AVG(bet_amount) AS avg_bet_amount,

        COUNT(DISTINCT account_date) AS active_days,

        COUNT(DISTINCT session_id) AS game_sessions,

        COUNT(DISTINCT table_id) AS table_count,

        COUNT(DISTINCT room_id) AS room_count,

        COUNT(DISTINCT dealer_id) AS dealer_count,

        COUNT(DISTINCT ip) AS ip_count,

        COUNT(DISTINCT wallet_id) AS wallet_count,

        MIN(bet_time) AS first_bet_time,

        MAX(bet_time) AS last_bet_time,

        DATEDIFF(
            MAX(account_date),
            MIN(account_date)
        ) AS lifetime_days,

        SUM(
            bet_amount * rebate_rate
        ) AS estimated_rebate_amount

    FROM bet_base

    WHERE cancel_flag <> 'Y'
       OR cancel_flag IS NULL

    GROUP BY member_id
)

SELECT *

FROM member_value

ORDER BY total_bet_amount DESC;
