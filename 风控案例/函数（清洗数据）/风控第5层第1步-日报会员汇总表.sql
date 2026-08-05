SELECT
    COLUMN_NAME,
    DATA_TYPE,
    COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA='ods_mariadb_2b'
AND TABLE_NAME='ods_a168_dailyreport_member'
ORDER BY ORDINAL_POSITION;
