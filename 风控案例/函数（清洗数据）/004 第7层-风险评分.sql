WITH member_feature AS (

    -- 这里可以直接替换为您的 member_360 结果

    SELECT

        member_id,

        valid_bet_amount,

        active_days,

        table_count,

        dealer_count,

        ip_count,

        wallet_count,

        estimated_rebate

    FROM member_360
)

SELECT

    *,

    (

        CASE

            WHEN ip_count = 1
             AND active_days >= 10
            THEN 10

            ELSE 0

        END

        +

        CASE

            WHEN wallet_count = 1
             AND active_days >= 10
            THEN 10

            ELSE 0

        END

        +

        CASE

            WHEN table_count <= 2
             AND active_days >= 10
            THEN 15

            ELSE 0

        END

        +

        CASE

            WHEN dealer_count <= 1
             AND active_days >= 10
            THEN 15

            ELSE 0

        END

        +

        CASE

            WHEN estimated_rebate
                 / NULLIF(valid_bet_amount,0)
                 > 0.01
            THEN 10

            ELSE 0

        END

    ) AS rule_risk_score

FROM member_feature;
