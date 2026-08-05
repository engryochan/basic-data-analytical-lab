DELETE FROM ${BUSINESS_RISK_TARGET_DATABASE}.business_risk_same_table_pair_snapshot
WHERE as_of_time = TIMESTAMP('${AS_OF_TIME}');

INSERT INTO ${BUSINESS_RISK_TARGET_DATABASE}.business_risk_same_table_pair_snapshot (
    as_of_time,
    player_a,
    player_b,
    window_start,
    window_end,
    same_round_count,
    player_a_round_count,
    player_b_round_count,
    same_rate,
    opposite_round_count,
    opposite_rate,
    first_game_time,
    last_game_time,
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
        CAST(bet13 AS DECIMAL(38,8)) AS bet_amount,
        UPPER(TRIM(CAST(bet30 AS STRING))) AS cancel_flag,
        CAST(bet31 AS BIGINT) AS table_id,
        CASE UPPER(TRIM(CAST(bet09 AS STRING)))
            WHEN 'BANKER' THEN 'BANKER'
            WHEN 'B' THEN 'BANKER'
            WHEN 'ZHUANG' THEN 'BANKER'
            WHEN '庄' THEN 'BANKER'
            WHEN '莊' THEN 'BANKER'
            WHEN 'PLAYER' THEN 'PLAYER'
            WHEN 'P' THEN 'PLAYER'
            WHEN 'XIAN' THEN 'PLAYER'
            WHEN '闲' THEN 'PLAYER'
            WHEN '閒' THEN 'PLAYER'
            WHEN 'TIE' THEN 'TIE'
            WHEN 'DRAW' THEN 'TIE'
            WHEN 'HE' THEN 'TIE'
            WHEN '和' THEN 'TIE'
            ELSE 'OTHER'
        END AS bet_side,
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
        round_id,
        sub_round_id,
        table_id,
        player_id,
        bet_time,
        bet_amount,
        bet_side
    FROM ranked_orders
    WHERE row_num = 1
      AND game_type = 101
      AND category = 1
      AND cancel_flag = 'N'
      AND bet_amount > CAST(0 AS DECIMAL(38,8))
      AND round_id > 0
      AND table_id > 0
      AND player_id > 0
),
player_participation AS (
    SELECT
        round_id,
        sub_round_id,
        table_id,
        player_id,
        SUM(
            CASE WHEN bet_side = 'BANKER'
                THEN bet_amount ELSE CAST(0 AS DECIMAL(38,8)) END
        ) AS banker_amount,
        SUM(
            CASE WHEN bet_side = 'PLAYER'
                THEN bet_amount ELSE CAST(0 AS DECIMAL(38,8)) END
        ) AS player_amount,
        MIN(bet_time) AS first_bet_time,
        MAX(bet_time) AS last_bet_time
    FROM valid_orders
    GROUP BY round_id, sub_round_id, table_id, player_id
),
player_counts AS (
    SELECT
        player_id,
        COUNT(*) AS player_round_count
    FROM player_participation
    GROUP BY player_id
),
pair_rounds AS (
    SELECT
        a.player_id AS player_a,
        b.player_id AS player_b,
        LEAST(a.banker_amount, b.player_amount)
            + LEAST(a.player_amount, b.banker_amount) AS matched_principal,
        LEAST(a.first_bet_time, b.first_bet_time) AS first_game_time,
        GREATEST(a.last_bet_time, b.last_bet_time) AS last_game_time
    FROM player_participation a
    INNER JOIN player_participation b
        ON b.round_id = a.round_id
       AND b.sub_round_id = a.sub_round_id
       AND b.table_id = a.table_id
       AND a.player_id < b.player_id
),
pair_totals AS (
    SELECT
        player_a,
        player_b,
        COUNT(*) AS same_round_count,
        SUM(CASE WHEN matched_principal > 0 THEN 1 ELSE 0 END) AS opposite_round_count,
        MIN(first_game_time) AS first_game_time,
        MAX(last_game_time) AS last_game_time
    FROM pair_rounds
    GROUP BY player_a, player_b
),
rated_pairs AS (
    SELECT
        pair.player_a,
        pair.player_b,
        pair.same_round_count,
        player_a.player_round_count AS player_a_round_count,
        player_b.player_round_count AS player_b_round_count,
        CAST(
            CAST(pair.same_round_count AS DECIMAL(38,8))
                / NULLIF(
                    CAST(
                        LEAST(
                            player_a.player_round_count,
                            player_b.player_round_count
                        ) AS DECIMAL(38,8)
                    ),
                    0
                )
            AS DECIMAL(9,6)
        ) AS same_rate,
        pair.opposite_round_count,
        CAST(
            CAST(pair.opposite_round_count AS DECIMAL(38,8))
                / NULLIF(CAST(pair.same_round_count AS DECIMAL(38,8)), 0)
            AS DECIMAL(9,6)
        ) AS opposite_rate,
        pair.first_game_time,
        pair.last_game_time
    FROM pair_totals pair
    INNER JOIN player_counts player_a
        ON player_a.player_id = pair.player_a
    INNER JOIN player_counts player_b
        ON player_b.player_id = pair.player_b
)
SELECT
    TIMESTAMP('${AS_OF_TIME}') AS as_of_time,
    player_a,
    player_b,
    TIMESTAMP('${WINDOW_START}') AS window_start,
    TIMESTAMP('${WINDOW_END}') AS window_end,
    same_round_count,
    player_a_round_count,
    player_b_round_count,
    same_rate,
    opposite_round_count,
    opposite_rate,
    first_game_time,
    last_game_time,
    CURRENT_TIMESTAMP() AS created_time
FROM rated_pairs
WHERE same_round_count >= ${BUSINESS_RISK_SAME_ROUND_COUNT_MIN}
  AND same_rate >= CAST(
      ${BUSINESS_RISK_SAME_RATE_MIN} AS DECIMAL(9,6)
  )
  AND opposite_rate >= CAST(
      ${BUSINESS_RISK_OPPOSITE_RATE_MIN} AS DECIMAL(9,6)
  );
