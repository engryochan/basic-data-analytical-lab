WITH bet_base AS (

    SELECT
        bet01 AS bet_id,
        CAST(bet05 AS BIGINT) AS member_id,
        CAST(bet03 AS BIGINT) AS session_id,

        CAST(bet06 AS DATETIME) AS game_time,
        CAST(bet08 AS DATETIME) AS bet_time,
        CAST(bet07 AS DATE) AS account_date,

        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,

        CAST(bet14 AS DECIMAL(20,8)) AS rebate_rate,

        bet30 AS cancel_flag,

        CAST(bet31 AS BIGINT) AS table_id,
        CAST(bet32 AS BIGINT) AS room_id,

        CAST(eid AS BIGINT) AS dealer_id,

        ip,

        betwalletid AS wallet_id

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'
),

member_bet AS (

    SELECT

        member_id,

        COUNT(*) AS raw_bet_count,

        COUNT(DISTINCT bet_id) AS bet_count,

        COUNT(DISTINCT session_id) AS session_count,

        SUM(bet_amount) AS gross_bet_amount,

        SUM(
            CASE
                WHEN cancel_flag IS NULL
                  OR cancel_flag <> 'Y'
                THEN bet_amount
                ELSE 0
            END
        ) AS valid_bet_amount,

        SUM(
            CASE
                WHEN cancel_flag = 'Y'
                THEN bet_amount
                ELSE 0
            END
        ) AS cancelled_bet_amount,

        COUNT(
            CASE
                WHEN cancel_flag = 'Y'
                THEN 1
            END
        ) AS cancelled_bet_count,

        AVG(bet_amount) AS avg_bet_amount,

        MAX(bet_amount) AS max_single_bet,

        COUNT(DISTINCT account_date) AS active_days,

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
        ) AS observed_lifetime_days,

        -- 理论返水金额
        SUM(
            CASE
                WHEN cancel_flag IS NULL
                  OR cancel_flag <> 'Y'
                THEN bet_amount * rebate_rate
                ELSE 0
            END
        ) AS estimated_rebate_amount

    FROM bet_base

    GROUP BY member_id
)

SELECT *

FROM member_bet

ORDER BY valid_bet_amount DESC;
