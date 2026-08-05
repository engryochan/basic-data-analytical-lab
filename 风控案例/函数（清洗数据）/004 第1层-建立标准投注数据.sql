WITH bet_base AS (

    SELECT
        -- =========================
        -- 主键
        -- =========================
        bet01 AS bet_id,

        -- 会员
        CAST(bet05 AS BIGINT) AS member_id,

        -- 场次
        CAST(bet03 AS BIGINT) AS session_id,

        CAST(bet04 AS INT) AS sub_session_id,

        -- =========================
        -- 时间
        -- =========================
        CAST(bet06 AS DATETIME) AS game_time,

        CAST(bet08 AS DATETIME) AS bet_time,

        CAST(bet07 AS DATE) AS account_date,

        dt,

        -- =========================
        -- 投注
        -- =========================
        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,

        CAST(bet14 AS DECIMAL(20,8)) AS rebate_rate,

        -- =========================
        -- 取消
        -- =========================
        bet30 AS cancel_flag,

        -- =========================
        -- 空间 / 游戏关系
        -- =========================
        CAST(bet31 AS BIGINT) AS table_id,

        CAST(bet32 AS BIGINT) AS room_id,

        CAST(eid AS BIGINT) AS dealer_id,

        -- =========================
        -- 网络 / 钱包
        -- =========================
        ip,

        betwalletid AS wallet_id,

        -- =========================
        -- 游戏
        -- =========================
        CAST(gametype AS INT) AS game_type,

        CAST(commission AS INT) AS commission_type,

        CAST(category AS INT) AS category,

        gameId AS game_id,

        -- =========================
        -- 币种
        -- =========================
        CAST(bet10 AS INT) AS currency_id,

        CAST(bet11 AS DECIMAL(20,8)) AS exchange_rate

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'

)

SELECT *

FROM bet_base

LIMIT 100;
