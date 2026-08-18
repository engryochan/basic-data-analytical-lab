/* ═══════════════════════════════════════════════════════════════════════
   §Z-14a · 零值会员-月性质诊断（v2 修正版 · 承 §Z-14 首跑实测斧正）
   ▸ 导出：需要 —— 存为「数据库/Z14a_zero_month_diagnosis.csv」（§Z-14a 零值诊断修正版）

   ▸ 【v2 斧正 · 2026-08-18】首跑（§Z-14 v1）实测已裁定，并暴露本条自身两处缺陷：
       【已裁定】源库 validbet **零 NULL**（v1 实测 n_vb_null=0／393 行，
                 §Z-12 硬编码版独立复核 n_validbet_dbnull=0／361 行，两版互证）。
                 故：S05 之 0.00E+00 全为真实零，中转层未抹平任何 NULL；
                 「NULL 抹平」假说否定，「S05 信息损毁」登记撤销。
       【缺陷一】v1 以 ABS(sum_game_pnl) < 0.005 判「输赢为零」——该阈值系手写普适门槛，
                 违反本包铁律（最小样本量／阈值须逐指标反解，禁写普适数）。
                 实测 135 行假阳性：其 |sum_game_pnl| 皆落于 (0, 0.005)，无一为真零。
                 v2 斧正：改为 **精确等于零**，不设容差。金额列为 DECIMAL(20,4)，
                 精确比较无浮点风险；若日后改用浮点型，须按币种最小刻度反解容差。
       【缺陷二】v1 承 §S-05 之 n_orders>=30 月度门槛，致 **23 个洗码为零之会员-月漏检**
                 （§Z-12 无门槛口径实测：洗码为零者共 166 行，v1 只见 142 行）。
                 v2 斧正：**取消订单数门槛**——本条为全量诊断，非评分底料，
                 不应继承评分管道之准入门槛；门槛属 §S-05 之口径，不属本条。
   ▸ 用途：★★ 判定「会员×月 洗码量或游戏输赢恰为零」之成因，二择一：
             ① 源字段 validbet／金额列原为 NULL（数据缺陷，波及 F-02 之 §S-05 归属）
             ② 同局对押庄闲所致之真实零（T-05 自对押／打水之风险信号）

   ▸ 立项依据（2026-08-18 R4 审计）：
       · §R01 原始导出实证 Superset 保留 NULL 为空字段（7,200 处），
         而 S05_member_month_panel.csv 全档零空字段、143 行洗码为 0.00E+00
         —— 该档经电子表格中转，NULL 与 0 在文件层已不可分辨。
       · 三项反向检验（两类零值几乎不重合 1/278,729、洗码=0 者退水恒为 0 无矛盾、
         画像短促小额单日）转而支持②。本条回源头作最终判定。

   ▸ 判读契约（v1 已执行完毕，此处存录以备复算；v2 仅作口径修正后之重取）：
       · n_vb_null > 0 且占比高            → 支持①NULL 抹平    【v1 实测：否定】
       · n_vb_null = 0 且 n_hedge_eq 高     → 支持②自对押真实零  【v1 实测：成立】
       · 两者皆低                           → 第三机制，判 UNKNOWN 另查
                                              【v1 实测：244 行系缺陷一之假阳性，已结案】

   ▸ 与既有条目之关系（血统，禁止同名异义）：
       · §S-05  会员×月面板 —— 本条复用其口径（同窗口、同六项清洗、同月粒度），
                 但**不读其 CSV**：目标集于库内现算，杜绝「以待检文件筛待检对象」之循环。
       · §T03   自对押/打水 —— 其 is_self_hedge 为**会员×日×局**级布尔、hedge_rate 为
                 会员级比率；本条另出 n_hedge_rounds / n_hedge_eq，为**会员×月**级计数，
                 粒度不同故另立名，绝不复用 is_self_hedge／hedge_rate 二名。
       · §C06fix 跨账户对打 —— 其 opposite_rate 为**双会员**口径；本条为**单会员自对押**，
                 二者实体数不同，禁止互代。
       · §F-02  洗码量实现分叉 —— 本条为其唯一可实证之判据来源。
       · §Z-12  为「锁定」章（不导出），本条另取 §Z-14；§Z-13 为净化审计结论；
                 §Z-15 已为「前置净化层」预留，故取 Z-14 无碰撞。

   ▸ 铁律遵循：目标集软编码现算（无硬编码会员号清单）；无 OFFSET（无分页）；
             无块注释于语句内；ID 一律显式 CAST；以 dt 分区切日（非 DATE(bet08)）；
             五级代理线全 LEFT JOIN；同单号取最新版本；导出必带 ORDER BY；
             **零容差精确比较**（DECIMAL 精确型，不写任何手工容差数）；
             **不继承 §S-05 之 n_orders>=30 门槛**（诊断条不承评分条之准入）。
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet38, b.bet39,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.validbet, b.commission, b.category, b.dt,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)            AS member_id,
         DATE_TRUNC('month', r.dt)                           AS bet_month,
         r.dt                                                AS dt,
         r.bet39                                             AS table_id,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39)           AS round_key,
         TRIM(r.bet09)                                       AS bet_side,
         TRIM(r.commission)                                  AS commission,
         r.validbet                                          AS vb_txt,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))  AS vb_raw,
         CAST(NULLIF(TRIM(r.bet13),'')    AS DECIMAL(20,4))  AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'')    AS DECIMAL(20,4))  AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'')    AS DECIMAL(20,4))  AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet11),'')    AS DECIMAL(20,8))  AS fx
  FROM ranked r
  LEFT JOIN ta t1 ON t1.agent_id = CAST(NULLIF(TRIM(r.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.agent_id = CAST(NULLIF(TRIM(r.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.agent_id = CAST(NULLIF(TRIM(r.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.agent_id = CAST(NULLIF(TRIM(r.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.agent_id = CAST(NULLIF(TRIM(r.bet22),'') AS BIGINT)
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
rnd AS (
  SELECT member_id, bet_month, round_key,
         MAX(CASE WHEN bet_side = 'Banker' THEN 1 ELSE 0 END) AS has_b,
         MAX(CASE WHEN bet_side = 'Player' THEN 1 ELSE 0 END) AS has_p,
         SUM(CASE WHEN bet_side = 'Banker' THEN stake_raw/fx ELSE 0 END) AS stk_b,
         SUM(CASE WHEN bet_side = 'Player' THEN stake_raw/fx ELSE 0 END) AS stk_p,
         SUM((payout_raw - stake_raw)/fx)                                AS pnl_rnd
  FROM base
  GROUP BY member_id, bet_month, round_key
),
mm AS (
  SELECT member_id, bet_month,
         COUNT(*)                                                          AS n_orders,
         COUNT(DISTINCT round_key)                                         AS n_rounds_month,
         COUNT(DISTINCT dt)                                                AS n_days_month,
         COUNT(DISTINCT table_id)                                          AS n_tables_month,
         SUM(CASE WHEN vb_txt IS NULL THEN 1 ELSE 0 END)                   AS n_vb_null,
         SUM(CASE WHEN vb_txt IS NOT NULL AND TRIM(vb_txt) = '' THEN 1 ELSE 0 END)
                                                                           AS n_vb_blank,
         SUM(CASE WHEN vb_raw = 0 THEN 1 ELSE 0 END)                       AS n_vb_true_zero,
         SUM(CASE WHEN vb_raw > 0 THEN 1 ELSE 0 END)                       AS n_vb_positive,
         SUM(vb_raw / fx)                                                  AS sum_valid_bet,
         SUM(stake_raw / fx)                                               AS sum_stake,
         SUM((payout_raw - stake_raw) / fx)                                AS sum_game_pnl,
         SUM(rebate_raw / fx)                                              AS sum_rebate,
         SUM(CASE WHEN commission = '1' THEN 1 ELSE 0 END)                 AS n_order_nocomm
  FROM base
  GROUP BY member_id, bet_month
),
hg AS (
  SELECT member_id, bet_month,
         SUM(CASE WHEN has_b = 1 AND has_p = 1 THEN 1 ELSE 0 END)          AS n_hedge_rounds,
         SUM(CASE WHEN has_b = 1 AND has_p = 1 AND stk_b = stk_p
                  THEN 1 ELSE 0 END)                                       AS n_hedge_eq,
         SUM(CASE WHEN pnl_rnd = 0 THEN 1 ELSE 0 END)                       AS n_zero_pnl_rounds
  FROM rnd
  GROUP BY member_id, bet_month
)
SELECT m.member_id                                                         AS member_id,
       m.bet_month                                                         AS bet_month,
       CASE WHEN COALESCE(m.sum_valid_bet,0) = 0 AND COALESCE(m.sum_game_pnl,0) = 0
                 THEN '洗码与输赢皆为零'
            WHEN COALESCE(m.sum_valid_bet,0) = 0 THEN '洗码贡献为零'
            ELSE '游戏输赢为零' END                                          AS zero_kind,
       CASE WHEN m.sum_valid_bet IS NULL THEN 'NULL' ELSE '有值' END        AS vb_sum_state,
       m.n_orders, m.n_rounds_month, m.n_days_month, m.n_tables_month,
       m.n_vb_null, m.n_vb_blank, m.n_vb_true_zero, m.n_vb_positive,
       m.n_vb_null * 1.0 / NULLIF(m.n_orders,0)                            AS vb_null_share,
       m.sum_valid_bet, m.sum_stake, m.sum_game_pnl, m.sum_rebate,
       m.n_order_nocomm,
       h.n_hedge_rounds, h.n_hedge_eq, h.n_zero_pnl_rounds,
       h.n_hedge_eq * 1.0 / NULLIF(m.n_rounds_month,0)                     AS hedge_eq_share,
       CASE WHEN COALESCE(m.n_vb_null,0) + COALESCE(m.n_vb_blank,0) > 0 THEN '支持①NULL抹平'
            WHEN COALESCE(h.n_hedge_eq,0) > 0                              THEN '支持②自对押真实零'
            ELSE '两者皆低·判UNKNOWN' END                                    AS verdict_hint
FROM mm m
JOIN hg h ON h.member_id = m.member_id AND h.bet_month = m.bet_month
WHERE COALESCE(m.sum_valid_bet,0) = 0
   OR m.sum_valid_bet IS NULL
   OR m.sum_game_pnl = 0
   OR m.sum_game_pnl IS NULL
ORDER BY verdict_hint, m.member_id, m.bet_month;
