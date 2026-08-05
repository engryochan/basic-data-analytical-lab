SELECT
    TABLE_NAME,
    COUNT(*) AS column_count
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
