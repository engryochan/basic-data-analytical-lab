WITH bet_base AS (

    SELECT

        CAST(bet05 AS BIGINT) AS member_id,

        CAST(bet08 AS DATETIME) AS bet_time,

        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,

        bet30 AS cancel_flag,

        CAST(bet03 AS BIGINT) AS session_id,

        CAST(bet31 AS BIGINT) AS table_id

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'
),

member_activity AS (

    SELECT

        member_id,

        COUNT(DISTINCT DATE(bet_time))
            AS active_days,

        COUNT(DISTINCT session_id)
            AS session_count,

        COUNT(DISTINCT table_id)
            AS table_count,

        SUM(
            CASE
                WHEN cancel_flag IS NULL
                  OR cancel_flag <> 'Y'
                THEN bet_amount
                ELSE 0
            END
        ) AS valid_bet_amount,

        MIN(bet_time)
            AS first_activity,

        MAX(bet_time)
            AS last_activity

    FROM bet_base

    GROUP BY member_id
)

SELECT

    *,

    DATEDIFF(
        last_activity,
        first_activity
    ) AS lifetime_days,

    CASE
        WHEN active_days > 0
        THEN valid_bet_amount / active_days
        ELSE 0
    END AS avg_daily_valid_bet,

    CASE
        WHEN lifetime_days > 0
        THEN active_days / lifetime_days
        ELSE 1
    END AS activity_density

FROM member_activity;
