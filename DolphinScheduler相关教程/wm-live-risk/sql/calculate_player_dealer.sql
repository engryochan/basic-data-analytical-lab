DELETE FROM ${BUSINESS_RISK_TARGET_DATABASE}.business_risk_player_dealer_snapshot
WHERE as_of_time = TIMESTAMP('${AS_OF_TIME}');

INSERT INTO ${BUSINESS_RISK_TARGET_DATABASE}.business_risk_player_dealer_snapshot (
    as_of_time,
    player_id,
    dealer_id,
    window_start,
    window_end,
    bet_amount,
    game_pnl,
    rebate_amount,
    net_profit_amount,
    player_overall_net_profit,
    win_count,
    lose_count,
    push_count,
    win_rate,
    order_count,
    round_count,
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
        CAST(bet11 AS DECIMAL(38,8)) AS exchange_rate,
        CAST(bet13 AS DECIMAL(38,8)) AS source_bet_amount,
        CAST(bet14 AS DECIMAL(38,8)) AS payout_amount,
        CAST(bet16 AS DECIMAL(38,8)) AS source_rebate_amount,
        CAST(bet17 AS DECIMAL(38,8)) AS source_net_profit_amount,
        UPPER(TRIM(CAST(bet38 AS STRING))) AS regrade_flag,
        CAST(bet39 AS BIGINT) AS table_id,
        CAST(category AS INT) AS category,
        CAST(eid AS BIGINT) AS dealer_id,
        ROW_NUMBER() OVER (
            PARTITION BY CAST(bet01 AS BIGINT)
            ORDER BY
                CAST(updatetime AS DATETIME) DESC,
                CAST(sync_time AS DATETIME) DESC,
                CAST(dt AS DATE) DESC,
                CAST(bet01 AS BIGINT) DESC
        ) AS row_num
    FROM ${BUSINESS_RISK_SOURCE_DATABASE}.${BUSINESS_RISK_SOURCE_BET02}
    WHERE CAST(dt AS DATE) >= DATE_SUB(DATE('${WINDOW_START}'), INTERVAL 1 DAY)
      AND CAST(dt AS DATE) < DATE_ADD(DATE('${WINDOW_END}'), INTERVAL 1 DAY)
      AND CAST(bet08 AS DATETIME) >= TIMESTAMP('${WINDOW_START}')
      AND CAST(bet08 AS DATETIME) < TIMESTAMP('${WINDOW_END}')
),
valid_orders AS (
    SELECT
        bet_id,
        round_id,
        sub_round_id,
        table_id,
        player_id,
        dealer_id,
        bet_time,
        source_bet_amount / exchange_rate AS bet_amount,
        (payout_amount - source_bet_amount) / exchange_rate AS game_pnl,
        source_rebate_amount / exchange_rate AS rebate_amount,
        source_net_profit_amount / exchange_rate AS net_profit_amount
    FROM ranked_orders
    WHERE row_num = 1
      AND game_type = 101
      AND category = 1
      AND regrade_flag = 'N'
      AND round_id > 0
      AND table_id > 0
      AND player_id > 0
      AND dealer_id > 0
      AND exchange_rate > CAST(0 AS DECIMAL(38,8))
),
unambiguous_player_round_keys AS (
    SELECT
        round_id,
        sub_round_id,
        table_id,
        player_id
    FROM valid_orders
    GROUP BY round_id, sub_round_id, table_id, player_id
    HAVING COUNT(DISTINCT dealer_id) = 1
),
unambiguous_orders AS (
    SELECT orders.*
    FROM valid_orders orders
    INNER JOIN unambiguous_player_round_keys valid_round
        ON valid_round.round_id = orders.round_id
       AND valid_round.sub_round_id = orders.sub_round_id
       AND valid_round.table_id = orders.table_id
       AND valid_round.player_id = orders.player_id
),
player_rounds AS (
    SELECT
        round_id,
        sub_round_id,
        table_id,
        player_id,
        dealer_id,
        SUM(bet_amount) AS bet_amount,
        SUM(game_pnl) AS game_pnl,
        SUM(rebate_amount) AS rebate_amount,
        SUM(net_profit_amount) AS net_profit_amount,
        COUNT(*) AS order_count,
        MIN(bet_time) AS first_bet_time,
        MAX(bet_time) AS last_bet_time
    FROM unambiguous_orders
    GROUP BY round_id, sub_round_id, table_id, player_id, dealer_id
),
player_totals AS (
    SELECT
        player_id,
        SUM(net_profit_amount) AS player_overall_net_profit
    FROM player_rounds
    GROUP BY player_id
    HAVING SUM(net_profit_amount) > 0
),
dealer_totals AS (
    SELECT
        player_id,
        dealer_id,
        SUM(bet_amount) AS bet_amount,
        SUM(game_pnl) AS game_pnl,
        SUM(rebate_amount) AS rebate_amount,
        SUM(net_profit_amount) AS net_profit_amount,
        SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) AS win_count,
        SUM(CASE WHEN game_pnl < 0 THEN 1 ELSE 0 END) AS lose_count,
        SUM(CASE WHEN game_pnl = 0 THEN 1 ELSE 0 END) AS push_count,
        SUM(order_count) AS order_count,
        COUNT(*) AS round_count,
        MIN(first_bet_time) AS first_bet_time,
        MAX(last_bet_time) AS last_bet_time
    FROM player_rounds
    GROUP BY player_id, dealer_id
),
rated_dealers AS (
    SELECT
        dealer.player_id,
        dealer.dealer_id,
        CAST(dealer.bet_amount AS DECIMAL(20,4)) AS bet_amount,
        CAST(dealer.game_pnl AS DECIMAL(20,4)) AS game_pnl,
        CAST(dealer.rebate_amount AS DECIMAL(20,4)) AS rebate_amount,
        CAST(dealer.net_profit_amount AS DECIMAL(20,4)) AS net_profit_amount,
        CAST(player.player_overall_net_profit AS DECIMAL(20,4))
            AS player_overall_net_profit,
        dealer.win_count,
        dealer.lose_count,
        dealer.push_count,
        CAST(
            CAST(dealer.win_count AS DECIMAL(38,8))
                / NULLIF(
                    CAST(dealer.win_count + dealer.lose_count AS DECIMAL(38,8)),
                    0
                )
            AS DECIMAL(9,6)
        ) AS win_rate,
        dealer.order_count,
        dealer.round_count,
        dealer.first_bet_time,
        dealer.last_bet_time
    FROM dealer_totals dealer
    INNER JOIN player_totals player
        ON player.player_id = dealer.player_id
)
SELECT
    TIMESTAMP('${AS_OF_TIME}') AS as_of_time,
    player_id,
    dealer_id,
    TIMESTAMP('${WINDOW_START}') AS window_start,
    TIMESTAMP('${WINDOW_END}') AS window_end,
    bet_amount,
    game_pnl,
    rebate_amount,
    net_profit_amount,
    player_overall_net_profit,
    win_count,
    lose_count,
    push_count,
    win_rate,
    order_count,
    round_count,
    first_bet_time,
    last_bet_time,
    CURRENT_TIMESTAMP() AS created_time
FROM rated_dealers
WHERE player_overall_net_profit > CAST(0 AS DECIMAL(20,4))
  AND win_rate > CAST(
      ${BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE} AS DECIMAL(9,6)
  )
  AND order_count >
      ${BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE};
