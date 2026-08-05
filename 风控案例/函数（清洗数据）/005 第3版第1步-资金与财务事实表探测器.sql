SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
AND (
       LOWER(COLUMN_NAME) LIKE '%profit%'
    OR LOWER(COLUMN_NAME) LIKE '%loss%'
    OR LOWER(COLUMN_NAME) LIKE '%win%'
    OR LOWER(COLUMN_NAME) LIKE '%payout%'
    OR LOWER(COLUMN_NAME) LIKE '%result%'
    OR LOWER(COLUMN_NAME) LIKE '%valid%'
    OR LOWER(COLUMN_NAME) LIKE '%turnover%'
    OR LOWER(COLUMN_NAME) LIKE '%deposit%'
    OR LOWER(COLUMN_NAME) LIKE '%withdraw%'
    OR LOWER(COLUMN_NAME) LIKE '%bonus%'
    OR LOWER(COLUMN_NAME) LIKE '%rebate%'
    OR LOWER(COLUMN_NAME) LIKE '%commission%'
    OR LOWER(COLUMN_NAME) LIKE '%payment%'
    OR LOWER(COLUMN_NAME) LIKE '%cash%'
    OR LOWER(COLUMN_NAME) LIKE '%balance%'
    OR LOWER(COLUMN_NAME) LIKE '%amount%'
)

ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
    