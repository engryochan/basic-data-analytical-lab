SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    COLUMN_COMMENT

FROM information_schema.columns

WHERE TABLE_SCHEMA = 'ods_mariadb_2b'

AND (

       LOWER(COLUMN_NAME) LIKE '%deposit%'
    OR LOWER(COLUMN_NAME) LIKE '%withdraw%'
    OR LOWER(COLUMN_NAME) LIKE '%wallet%'
    OR LOWER(COLUMN_NAME) LIKE '%balance%'
    OR LOWER(COLUMN_NAME) LIKE '%cash%'
    OR LOWER(COLUMN_NAME) LIKE '%transaction%'
    OR LOWER(COLUMN_NAME) LIKE '%payment%'
    OR LOWER(COLUMN_NAME) LIKE '%money%'
    OR LOWER(COLUMN_NAME) LIKE '%amount%'

)

ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
