DELETE FROM ${BUSINESS_RISK_TARGET_DATABASE}.business_risk_late_bet_snapshot
WHERE as_of_time = TIMESTAMP('${AS_OF_TIME}');

INSERT INTO ${BUSINESS_RISK_TARGET_DATABASE}.business_risk_late_bet_snapshot (
    as_of_time,
    player_id,
    window_start,
    window_end,
    late_order_count,
    total_order_count,
    late_order_rate,
    first_bet_time,
    last_bet_time,
    created_time
)
WITH ranked_orders AS (
    SELECT
        CAST(bet01 AS BIGINT) AS bet_id,
        CAST(bet02 AS INT) AS game_type,
        CAST(bet03 AS BIGINT) AS round_id,
        CAST(bet04 AS INT) AS sub_round_id,
        CAST(bet05 AS BIGINT) AS player_id,
        CAST(bet08 AS DATETIME) AS bet_time,
        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,
        UPPER(TRIM(CAST(bet30 AS STRING))) AS cancel_flag,
        CAST(category AS INT) AS category,
        ROW_NUMBER() OVER (
            PARTITION BY CAST(bet01 AS BIGINT)
            ORDER BY
                CAST(updatetime AS DATETIME) DESC,
                CAST(sync_time AS DATETIME) DESC,
                CAST(dt AS DATE) DESC,
                CAST(bet01 AS BIGINT) DESC
        ) AS row_num
    FROM ${BUSINESS_RISK_SOURCE_DATABASE}.${BUSINESS_RISK_SOURCE_BET01}
    WHERE CAST(dt AS DATE) >= DATE_SUB(DATE('${WINDOW_START}'), INTERVAL 1 DAY)
      AND CAST(dt AS DATE) < DATE_ADD(DATE('${WINDOW_END}'), INTERVAL 1 DAY)
      AND CAST(bet08 AS DATETIME) >= TIMESTAMP('${WINDOW_START}')
      AND CAST(bet08 AS DATETIME) < TIMESTAMP('${WINDOW_END}')
),
valid_orders AS (
    SELECT
        bet_id,
        sub_round_id,
        player_id,
        bet_time
    FROM ranked_orders
    WHERE row_num = 1
      AND game_type = 101
      AND category = 1
      AND cancel_flag = 'N'
      AND bet_amount > CAST(0 AS DECIMAL(20,4))
      AND round_id > 0
      AND player_id > 0
),
player_totals AS (
    SELECT
        player_id,
        SUM(
            CASE
                WHEN sub_round_id >= ${BUSINESS_RISK_LATE_SUB_ROUND_MIN}
                THEN 1
                ELSE 0
            END
        ) AS late_order_count,
        COUNT(*) AS total_order_count,
        MIN(bet_time) AS first_bet_time,
        MAX(bet_time) AS last_bet_time
    FROM valid_orders
    GROUP BY player_id
),
rated_players AS (
    SELECT
        player_id,
        late_order_count,
        total_order_count,
        CAST(
            CAST(late_order_count AS DECIMAL(38,8))
                / NULLIF(CAST(total_order_count AS DECIMAL(38,8)), 0)
            AS DECIMAL(9,6)
        ) AS late_order_rate,
        first_bet_time,
        last_bet_time
    FROM player_totals
)
SELECT
    TIMESTAMP('${AS_OF_TIME}') AS as_of_time,
    player_id,
    TIMESTAMP('${WINDOW_START}') AS window_start,
    TIMESTAMP('${WINDOW_END}') AS window_end,
    late_order_count,
    total_order_count,
    late_order_rate,
    first_bet_time,
    last_bet_time,
    CURRENT_TIMESTAMP() AS created_time
FROM rated_players
WHERE late_order_count > ${BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE}
  AND late_order_rate >= CAST(
      ${BUSINESS_RISK_LATE_ORDER_RATE_MIN} AS DECIMAL(9,6)
  );
