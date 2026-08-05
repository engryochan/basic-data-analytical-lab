WITH bet_base AS (
    SELECT
        bet01 AS bet_id,
        CAST(bet05 AS BIGINT) AS member_id,
        CAST(bet03 AS BIGINT) AS session_id,
        CAST(bet04 AS INT) AS sub_session_id,

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

        CAST(gametype AS INT) AS game_type,
        CAST(commission AS INT) AS commission_type,
        CAST(category AS INT) AS category,

        gameId AS game_id,
        betwalletid AS wallet_id,

        dt

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'
)
SELECT *
FROM bet_base
LIMIT 100;
