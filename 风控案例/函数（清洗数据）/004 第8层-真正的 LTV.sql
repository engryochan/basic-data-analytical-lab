SELECT

    member_id,

    -- 收入
    ggr,

    -- 有效投注
    valid_bet_amount,

    -- 会员盈亏
    member_profit_loss,

    -- 返水
    rebate_amount,

    -- 优惠
    bonus_amount,

    -- 佣金
    commission_amount,

    -- 支付成本
    payment_cost,

    -- 贡献利润
    ggr
    - rebate_amount
    - bonus_amount
    - commission_amount
    - payment_cost
    AS contribution_profit,

    -- ROI
    CASE

        WHEN valid_bet_amount > 0

        THEN
            (
                ggr
                - rebate_amount
                - bonus_amount
                - commission_amount
                - payment_cost
            )
            / valid_bet_amount

        ELSE NULL

    END AS contribution_roi

FROM member_financial;
