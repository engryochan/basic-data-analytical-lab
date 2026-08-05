WITH bet_base AS (

    SELECT

        CAST(bet05 AS BIGINT) AS member_id,

        bet01 AS bet_id,

        bet03 AS round_id,

        bet04 AS sub_round_id,

        bet06 AS game_start_time,

        bet07 AS accounting_date,

        bet08 AS bet_time,

        bet10 AS currency,

        CAST(bet11 AS DECIMAL(20,8)) AS exchange_rate,

        CAST(bet13 AS DECIMAL(20,8)) AS bet_amount,

        CAST(bet14 AS DECIMAL(20,8)) AS rebate_rate,

        bet30 AS cancel_flag,

        bet31 AS table_id,

        bet32 AS room_id,

        betwalletid AS wallet_id,

        gametype,

        commission,

        category,

        eid AS dealer_id,

        serid AS service_id,

        ip,

        partnerBetId,

        gameId,

        dt,

        updatetime,

        __source_pk

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01'
                  AND '2026-03-31'
)

SELECT *
FROM bet_base;
