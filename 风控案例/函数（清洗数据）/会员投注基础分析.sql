WITH bet_base AS (
    SELECT
        CAST(bet05 AS BIGINT) AS member_id,
        CAST(bet01 AS BIGINT) AS bet_id,
        CAST(bet03 AS BIGINT) AS game_round_id,
        CAST(bet04 AS INT) AS sub_round_id,

        dt,

        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,
        CAST(bet14 AS DECIMAL(20,4)) AS rebate_rate,

        CAST(bet10 AS INT) AS currency_id,
        CAST(bet11 AS DECIMAL(20,8)) AS exchange_rate,

        CAST(bet30 AS VARCHAR) AS cancel_flag,

        CAST(bet31 AS BIGINT) AS table_id,
        CAST(bet32 AS BIGINT) AS room_id,

        CAST(eid AS BIGINT) AS dealer_id,

        ip,
        betwalletid,
        gametype,

        bet08 AS bet_time,
        bet06 AS game_start_time

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'
)

SELECT
    member_id,

    COUNT(*) AS bet_count,

    COUNT(DISTINCT game_round_id) AS round_count,

    SUM(bet_amount) AS total_bet_amount,

    AVG(bet_amount) AS avg_bet_amount,

    MAX(bet_amount) AS max_single_bet,

    SUM(
        CASE
            WHEN cancel_flag <> 'Y'
            THEN bet_amount
            ELSE 0
        END
    ) AS valid_bet_amount,

    SUM(
        CASE
            WHEN cancel_flag = 'Y'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_bet_count,

    COUNT(DISTINCT table_id) AS table_count,

    COUNT(DISTINCT dealer_id) AS dealer_count,

    COUNT(DISTINCT ip) AS ip_count,

    COUNT(DISTINCT betwalletid) AS wallet_count,

    MIN(bet_time) AS first_bet_time,

    MAX(bet_time) AS last_bet_time

FROM bet_base

GROUP BY member_id

ORDER BY total_bet_amount DESC;
