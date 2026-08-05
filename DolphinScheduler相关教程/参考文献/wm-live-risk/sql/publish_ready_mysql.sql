INSERT INTO business_risk_publish_state (
    dataset_name,
    as_of_time,
    window_start,
    window_end,
    publish_status,
    late_bet_row_count,
    same_table_row_count,
    player_dealer_row_count,
    published_at,
    update_time
)
SELECT
    'BACCARAT_BUSINESS_RISK',
    '${AS_OF_TIME}',
    '${WINDOW_START}',
    '${WINDOW_END}',
    'READY',
    (
        SELECT COUNT(*)
        FROM business_risk_late_bet_stat
        WHERE as_of_time = '${AS_OF_TIME}'
    ),
    (
        SELECT COUNT(*)
        FROM business_risk_same_table_pair_stat
        WHERE as_of_time = '${AS_OF_TIME}'
    ),
    (
        SELECT COUNT(*)
        FROM business_risk_player_dealer_stat
        WHERE as_of_time = '${AS_OF_TIME}'
    ),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
ON DUPLICATE KEY UPDATE
    as_of_time = VALUES(as_of_time),
    window_start = VALUES(window_start),
    window_end = VALUES(window_end),
    publish_status = VALUES(publish_status),
    late_bet_row_count = VALUES(late_bet_row_count),
    same_table_row_count = VALUES(same_table_row_count),
    player_dealer_row_count = VALUES(player_dealer_row_count),
    published_at = VALUES(published_at),
    update_time = VALUES(update_time);
