SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT bet01) AS distinct_bet_count,
    SUM(CASE WHEN bet01 IS NULL THEN 1 ELSE 0 END) AS null_bet_id,
    COUNT(DISTINCT bet05) AS member_count,
    MIN(dt) AS min_dt,
    MAX(dt) AS max_dt
FROM ods_mariadb_2b.ods_a168_bet01;
