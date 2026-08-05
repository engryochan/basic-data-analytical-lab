WITH bet_base AS (

    SELECT

        -- =========================
        -- 会员
        -- =========================
        CAST(bet05 AS BIGINT) AS member_id,

        -- =========================
        -- 注单
        -- =========================
        CAST(bet01 AS BIGINT) AS bet_id,

        -- =========================
        -- 场次
        -- =========================
        CAST(bet03 AS BIGINT) AS session_id,

        -- =========================
        -- 时间
        -- =========================
        CAST(bet06 AS DATETIME) AS game_time,

        CAST(bet08 AS DATETIME) AS bet_time,

        CAST(bet07 AS DATE) AS account_date,

        dt,

        -- =========================
        -- 投注金额
        -- =========================
        CAST(bet13 AS DECIMAL(20,4)) AS bet_amount,

        -- =========================
        -- 返水比例
        -- =========================
        CAST(bet14 AS DECIMAL(20,8)) AS rebate_rate,

        -- =========================
        -- 取消状态
        -- =========================
        bet30 AS cancel_flag,

        -- =========================
        -- 空间关系
        -- =========================
        CAST(bet31 AS BIGINT) AS table_id,

        CAST(bet32 AS BIGINT) AS room_id,

        CAST(eid AS BIGINT) AS dealer_id,

        -- =========================
        -- 网络
        -- =========================
        ip,

        -- =========================
        -- 钱包
        -- =========================
        betwalletid AS wallet_id

    FROM ods_mariadb_2b.ods_a168_bet01

    WHERE dt BETWEEN '2026-01-01' AND '2026-03-31'
),

-- =====================================================
-- IP → 会员关系
-- 用于识别一个 IP 对应多少会员
-- =====================================================

ip_member_count AS (

    SELECT

        ip,

        COUNT(DISTINCT member_id) AS ip_member_count

    FROM bet_base

    WHERE ip IS NOT NULL

    GROUP BY ip
),

-- =====================================================
-- 会员级别 360 特征
-- =====================================================

member_360 AS (

    SELECT

        b.member_id,

        -- =========================================
        -- 1. 投注规模
        -- =========================================

        COUNT(DISTINCT b.bet_id)
            AS bet_count,

        COUNT(DISTINCT b.session_id)
            AS session_count,

        SUM(b.bet_amount)
            AS gross_bet_amount,

        SUM(
            CASE
                WHEN b.cancel_flag IS NULL
                  OR b.cancel_flag <> 'Y'
                THEN b.bet_amount
                ELSE 0
            END
        ) AS valid_bet_amount,

        SUM(
            CASE
                WHEN b.cancel_flag = 'Y'
                THEN b.bet_amount
                ELSE 0
            END
        ) AS cancelled_bet_amount,

        COUNT(
            CASE
                WHEN b.cancel_flag = 'Y'
                THEN 1
            END
        ) AS cancelled_bet_count,

        -- =========================================
        -- 2. 投注行为
        -- =========================================

        AVG(b.bet_amount)
            AS avg_bet_amount,

        MAX(b.bet_amount)
            AS max_single_bet,

        -- =========================================
        -- 3. 活跃度
        -- =========================================

        COUNT(DISTINCT b.account_date)
            AS active_days,

        COUNT(DISTINCT b.table_id)
            AS table_count,

        COUNT(DISTINCT b.room_id)
            AS room_count,

        COUNT(DISTINCT b.dealer_id)
            AS dealer_count,

        -- =========================================
        -- 4. 网络关系
        -- =========================================

        COUNT(DISTINCT b.ip)
            AS ip_count,

        COUNT(
            DISTINCT
            CASE
                WHEN i.ip_member_count > 1
                THEN b.ip
            END
        ) AS shared_ip_count,

        MAX(
            i.ip_member_count
        ) AS max_members_per_ip,

        -- =========================================
        -- 5. 钱包
        -- =========================================

        COUNT(DISTINCT b.wallet_id)
            AS wallet_count,

        -- =========================================
        -- 6. 生命周期
        -- =========================================

        MIN(b.bet_time)
            AS first_bet_time,

        MAX(b.bet_time)
            AS last_bet_time,

        DATEDIFF(
            MAX(b.account_date),
            MIN(b.account_date)
        ) AS observed_lifetime_days,

        -- =========================================
        -- 7. 返水
        -- =========================================

        SUM(
            CASE
                WHEN b.cancel_flag IS NULL
                  OR b.cancel_flag <> 'Y'
                THEN
                    b.bet_amount
                    *
                    b.rebate_rate
                ELSE 0
            END
        ) AS estimated_rebate_amount

    FROM bet_base b

    LEFT JOIN ip_member_count i

        ON b.ip = i.ip

    GROUP BY

        b.member_id
)

SELECT

    m.*,

    -- =========================================
    -- 取消率
    -- =========================================

    CASE

        WHEN m.bet_count > 0

        THEN
            m.cancelled_bet_count
            /
            m.bet_count

        ELSE 0

    END AS cancellation_rate,

    -- =========================================
    -- 返水率
    -- =========================================

    CASE

        WHEN m.valid_bet_amount > 0

        THEN
            m.estimated_rebate_amount
            /
            m.valid_bet_amount

        ELSE 0

    END AS effective_rebate_rate,

    -- =========================================
    -- 日均有效投注
    -- =========================================

    CASE

        WHEN m.active_days > 0

        THEN
            m.valid_bet_amount
            /
            m.active_days

        ELSE 0

    END AS avg_daily_valid_bet,

    -- =========================================
    -- 活跃密度
    -- =========================================

    CASE

        WHEN m.observed_lifetime_days > 0

        THEN
            m.active_days
            /
            m.observed_lifetime_days

        ELSE 1

    END AS activity_density,

    -- =========================================
    -- 基础价值分层
    -- =========================================

    CASE

        WHEN
            m.active_days >= 30
            AND m.valid_bet_amount >= 100000

        THEN 'A_高价值活跃'

        WHEN
            m.active_days >= 15
            AND m.valid_bet_amount >= 50000

        THEN 'B_高价值'

        WHEN
            m.active_days >= 7
            AND m.valid_bet_amount >= 10000

        THEN 'C_中价值'

        WHEN
            m.active_days >= 3

        THEN 'D_低活跃'

        ELSE 'E_新客低频'

    END AS value_segment,

    -- =========================================
    -- 基础风控评分
    -- 注意：这里只是规则评分，不是最终风险概率
    -- =========================================

    (

        CASE

            WHEN
                m.shared_ip_count >= 1

            THEN 20

            ELSE 0

        END

        +

        CASE

            WHEN
                m.max_members_per_ip >= 3

            THEN 20

            ELSE 0

        END

        +

        CASE

            WHEN
                m.active_days >= 10
                AND m.table_count <= 2

            THEN 15

            ELSE 0

        END

        +

        CASE

            WHEN
                m.active_days >= 10
                AND m.dealer_count <= 1

            THEN 15

            ELSE 0

        END

        +

        CASE

            WHEN
                m.valid_bet_amount > 0
                AND
                m.estimated_rebate_amount
                /
                m.valid_bet_amount > 0.01

            THEN 10

            ELSE 0

        END

        +

        CASE

            WHEN
                m.cancelled_bet_count > 0
                AND
                m.cancelled_bet_count
                /
                NULLIF(m.bet_count,0) > 0.1

            THEN 10

            ELSE 0

        END

    ) AS rule_risk_score

FROM member_360 m

ORDER BY

    rule_risk_score DESC,

    valid_bet_amount DESC;
    