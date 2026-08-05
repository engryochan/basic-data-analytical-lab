SELECT
    player_a,
    player_b,
    same_round_count,
    player_a_rounds,
    player_b_rounds,
    same_rate,
    first_game_time,
    last_game_time,

    DATEDIFF(last_game_time, first_game_time) AS relationship_days,

    LEAST(player_a_rounds, player_b_rounds) AS min_rounds,

    GREATEST(player_a_rounds, player_b_rounds) AS max_rounds,

    same_round_count /
    NULLIF(LEAST(player_a_rounds, player_b_rounds), 0) AS relation_strength,

    DATEDIFF(CURRENT_DATE, last_game_time) AS active_days,

    (
        0.45 * same_rate
        + 0.35 * (
            same_round_count /
            NULLIF(MAX(same_round_count) OVER (), 0)
        )
        + 0.20 * (
            DATEDIFF(last_game_time, first_game_time) /
            NULLIF(MAX(DATEDIFF(last_game_time, first_game_time)) OVER (), 0)
        )
    ) AS risk_score

FROM player_pair_stat;
