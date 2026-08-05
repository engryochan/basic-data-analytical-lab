SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM information_schema.tables
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY TABLE_NAME;
