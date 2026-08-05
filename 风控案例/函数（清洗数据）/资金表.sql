SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_COMMENT
FROM information_schema.columns
WHERE
    (
        LOWER(COLUMN_NAME) LIKE '%wallet%'
        OR LOWER(COLUMN_NAME) LIKE '%deposit%'
        OR LOWER(COLUMN_NAME) LIKE '%withdraw%'
        OR LOWER(COLUMN_NAME) LIKE '%amount%'
        OR LOWER(COLUMN_NAME) LIKE '%profit%'
        OR LOWER(COLUMN_NAME) LIKE '%loss%'
        OR LOWER(COLUMN_NAME) LIKE '%rebate%'
        OR LOWER(COLUMN_NAME) LIKE '%bonus%'
        OR LOWER(COLUMN_NAME) LIKE '%balance%'
        OR LOWER(COLUMN_NAME) LIKE '%member%'
        OR LOWER(COLUMN_NAME) LIKE '%user%'
    )
ORDER BY
    TABLE_SCHEMA,
    TABLE_NAME,
    ORDINAL_POSITION;
