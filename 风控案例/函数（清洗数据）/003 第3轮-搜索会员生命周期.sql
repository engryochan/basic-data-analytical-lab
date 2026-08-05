SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    COLUMN_COMMENT

FROM information_schema.columns

WHERE TABLE_SCHEMA = 'ods_mariadb_2b'

AND (

       LOWER(COLUMN_NAME) LIKE '%register%'
    OR LOWER(COLUMN_NAME) LIKE '%login%'
    OR LOWER(COLUMN_NAME) LIKE '%lastlogin%'
    OR LOWER(COLUMN_NAME) LIKE '%active%'
    OR LOWER(COLUMN_NAME) LIKE '%status%'
    OR LOWER(COLUMN_NAME) LIKE '%member%'
    OR LOWER(COLUMN_NAME) LIKE '%user%'

)

ORDER BY
    TABLE_NAME,
    ORDINAL_POSITION;
    