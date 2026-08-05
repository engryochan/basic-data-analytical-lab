WITH candidate_tables AS (

    SELECT

        TABLE_SCHEMA,
        TABLE_NAME,

        MAX(
            CASE
                WHEN
                    LOWER(COLUMN_NAME) LIKE '%member%'
                    OR LOWER(COLUMN_NAME) LIKE '%user%'
                    OR LOWER(COLUMN_NAME) LIKE '%uid%'
                    OR LOWER(COLUMN_NAME) LIKE '%account%'
                    OR COLUMN_COMMENT LIKE '%會員%'
                    OR COLUMN_COMMENT LIKE '%会员%'
                THEN 1
                ELSE 0
            END
        ) AS has_member_key,

        MAX(
            CASE
                WHEN
                    LOWER(COLUMN_NAME) LIKE '%amount%'
                    OR LOWER(COLUMN_NAME) LIKE '%money%'
                    OR LOWER(COLUMN_NAME) LIKE '%cash%'
                    OR LOWER(COLUMN_NAME) LIKE '%balance%'
                    OR COLUMN_COMMENT LIKE '%金額%'
                    OR COLUMN_COMMENT LIKE '%金额%'
                THEN 1
                ELSE 0
            END
        ) AS has_money_field,

        MAX(
            CASE
                WHEN
                    LOWER(COLUMN_NAME) LIKE '%deposit%'
                    OR LOWER(COLUMN_NAME) LIKE '%withdraw%'
                    OR LOWER(COLUMN_NAME) LIKE '%recharge%'
                    OR LOWER(COLUMN_NAME) LIKE '%cashout%'
                    OR COLUMN_COMMENT LIKE '%充值%'
                    OR COLUMN_COMMENT LIKE '%提现%'
                    OR COLUMN_COMMENT LIKE '%存款%'
                    OR COLUMN_COMMENT LIKE '%提款%'
                THEN 1
                ELSE 0
            END
        ) AS has_cashflow_field,

        MAX(
            CASE
                WHEN
                    LOWER(COLUMN_NAME) LIKE '%profit%'
                    OR LOWER(COLUMN_NAME) LIKE '%loss%'
                    OR LOWER(COLUMN_NAME) LIKE '%win%'
                    OR LOWER(COLUMN_NAME) LIKE '%payout%'
                    OR LOWER(COLUMN_NAME) LIKE '%result%'
                    OR COLUMN_COMMENT LIKE '%盈虧%'
                    OR COLUMN_COMMENT LIKE '%盈亏%'
                    OR COLUMN_COMMENT LIKE '%輸贏%'
                    OR COLUMN_COMMENT LIKE '%输赢%'
                    OR COLUMN_COMMENT LIKE '%派彩%'
                THEN 1
                ELSE 0
            END
        ) AS has_profit_field,

        MAX(
            CASE
                WHEN
                    LOWER(COLUMN_NAME) LIKE '%bonus%'
                    OR LOWER(COLUMN_NAME) LIKE '%rebate%'
                    OR LOWER(COLUMN_NAME) LIKE '%commission%'
                    OR COLUMN_COMMENT LIKE '%紅利%'
                    OR COLUMN_COMMENT LIKE '%红利%'
                    OR COLUMN_COMMENT LIKE '%返水%'
                    OR COLUMN_COMMENT LIKE '%傭金%'
                    OR COLUMN_COMMENT LIKE '%佣金%'
                THEN 1
                ELSE 0
            END
        ) AS has_cost_field

    FROM information_schema.columns

    WHERE TABLE_SCHEMA = 'ods_mariadb_2b'

    GROUP BY
        TABLE_SCHEMA,
        TABLE_NAME
)

SELECT

    *,

    (
        has_member_key
        + has_money_field
        + has_cashflow_field
        + has_profit_field
        + has_cost_field
    ) AS financial_signal_score

FROM candidate_tables

WHERE

    has_member_key = 1

    AND (

        has_cashflow_field = 1

        OR has_profit_field = 1

        OR has_cost_field = 1

    )

ORDER BY

    financial_signal_score DESC,

    TABLE_NAME;
    