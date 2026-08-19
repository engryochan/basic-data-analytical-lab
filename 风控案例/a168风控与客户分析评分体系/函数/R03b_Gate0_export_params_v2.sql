/* ═══════════════════════════════════════════════════════════════════════
   §Z-20 · R03b 重导前置锁证 · Gate-0 v2（完整自包含版）
   ▸ 承 v1 之作废：v1 三段留有 `SELECT NULL AS …` 可运行占位，未替换即静默
     产出假读数（db_row_count=1、ties_3col=0、verdict「全序成立·可分页」皆为
     1=1 所致之假阳性）。v1 三份产物标 **VOID / placeholder artifact**，
     保留留档不删（MD5：count a1dc0467… ／ keyorder 1dae79a0… ／ manifest bbb82c33…）。
     v2 起**完整嵌入 §R03b 主体，零占位符**，整段复制即可运行。

   ▸ ⛔ 不预设任何行数。6,143,388 与 18,139,550 皆 historical observation，
     本版不作 expected value；本轮 db_row_count 由 §A 现场推导，自成 current evidence。

   ▸ ★ 一级结构性检查（v2 新增，非脚本修补）：
     §R03b 主体末端实为
         GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer   ← 四键
         ORDER BY p.bet_date, p.member_id, p.dealer_id;                        ← 仅三键
     即 **GROUP BY 第四键 is_sentinel_dealer 未进入 ORDER BY**。
     故须双键并列检定，不可只检其一：
         K3 = (bet_date, uid, dealer_id)                      ← 现行 ORDER BY
         K4 = (bet_date, uid, dealer_id, is_sentinel_dealer)  ← 实际 GROUP BY
     判读契约（先写死，禁止事后择利解释）：
       · K3 dup > 0 且 K4 dup = 0
         → 裁定：**K3 非全序；K4 唯一。现行 ORDER BY 未覆盖 GROUP BY 全部区分键，
                   存在分页边界不稳定风险。** ⛔ 不得称之为「R03b 有重复」。
       · K4 dup > 0
         → 裁定：**粒度／主体定义问题**，须另启调查，禁入 §C。
       · K3 dup = 0 且 K4 dup = 0
         → 两键皆唯一；惟 **唯一性 ≠ 跨次导出稳定**，稳定性仍须 Run A/B + CC-03 方可断。
     ⛔ 无论何种结果，皆不得以 DISTINCT 抹平并列——那会改变观测集。

   ▸ ★ 输出列正名（v1 之误）：主体输出为 `p.member_id AS uid`，
     **CSV 侧业务键为 `uid`，非 `member_id`**。核验器须同步改。

   ▸ ★ cmp_time_window 实况核验（v2 新增）：主体内硬写
         cmp_time_window = '2026-03-21..2026-08-06'
     而实际 WHERE 为  b.dt >= '2026-03-21' AND b.dt < '2026-08-07'（半开区间）。
     二者语义或等价，但**不得凭标签断定**——须由 §D 以实测 min/max 裁定
     LABEL_MATCH ／ LABEL_MISMATCH ／ UNKNOWN。

   ▸ 本版只跑 §A ／ §B ／ §D 三段。**§C 分页清单未获放行前不得运行；
     Run A ／ Run B 一律禁止。**
   ═══════════════════════════════════════════════════════════════════════ */

-- ── §A · DB 总量与边界（current evidence，唯一合法期望值来源）─────────────
-- ▸ 导出：需要 —— 存为「数据库/R03b_count_check_v2.csv」
WITH ranked AS (
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,
         b.category, b.eid,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'
),
ord AS (
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord WHERE is_sentinel_dealer = 0
  GROUP BY bet_side
),
ordb AS (
  SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet_date, o.round_key, o.bet_side,
         o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side
  FROM      ord o
  LEFT JOIN side_base s ON s.bet_side = o.bet_side
),
pr AS (
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, round_key,
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,
         COUNT(*) AS n_orders_in_round,
         SUM(stake * p_side)
           / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)
                       AS p_base_round_w,
         AVG(p_side)   AS p_base_round_unw,
         MAX(bet_side) AS main_side
  FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet_date, round_key
)
SELECT COUNT(*)                                              AS db_row_count,
       COUNT(DISTINCT t.uid)                                 AS db_member,
       COUNT(DISTINCT t.dealer_id)                           AS db_dealer,
       COUNT(DISTINCT t.bet_date)                            AS db_date,
       MIN(t.bet_date)                                       AS date_min,
       MAX(t.bet_date)                                       AS date_max,
       MIN(t.uid)                                            AS member_min,
       MAX(t.uid)                                            AS member_max,
       MIN(t.dealer_id)                                      AS dealer_min,
       MAX(t.dealer_id)                                      AS dealer_max,
       SUM(CASE WHEN t.is_sentinel_dealer = 1 THEN 1 ELSE 0 END) AS n_sentinel_rows,
       SUM(CASE WHEN t.is_sentinel_dealer = 0 THEN 1 ELSE 0 END) AS n_nonsentinel_rows
FROM (
  SELECT p.bet_date, p.member_id AS uid, p.dealer_id, p.is_sentinel_dealer,
         SUM(p.stake)                                        AS stake_amount,
         SUM(p.game_pnl)                                     AS profit_amount,
         SUM(p.net_pnl)                                      AS net_pnl,
         SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,
         SUM(p.n_orders_in_round)                            AS n_related_orders,
         COUNT(*)                                            AS n_rounds_eff,
         AVG(p.p_base_round_w)                                 AS p_base_mix_w,
         AVG(p.p_base_round_unw)                             AS p_base_mix_unw,
         (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
          - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))
           / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                         * AVG(p.p_base_round_w)
                         * (1 - AVG(p.p_base_round_w))), 0)        AS z_score_w,
         (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
          - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_unw))
           / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                         * AVG(p.p_base_round_unw)
                         * (1 - AVG(p.p_base_round_unw))), 0)    AS z_score_unw,
         (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
          - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))
           / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                         * AVG(p.p_base_round_w)
                         * (1 - AVG(p.p_base_round_w))), 0)        AS z_score,
         AVG(p.p_base_round_w) - AVG(p.p_base_round_unw)          AS delta_p,
         CASE WHEN p.is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'
              WHEN AVG(p.p_base_round_w) IS NULL THEN 'NO_BASE_RATE'
              WHEN SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_DECISIVE_ROUND'
              ELSE 'ELIGIBLE' END                                 AS eligibility_status,
         'R03b_20260811_FULL_v1'                              AS comparison_id,
         'L1_ELIGIBILITY'                           AS filter_stage,
         'v2026-08-11'                              AS filter_rule_version,
         '2026-03-21..2026-08-06'                             AS cmp_time_window,
         'baccarat_bet02_101_all_pairs_incl_sentinel'         AS cmp_population,
         'round_win = game_pnl > 0 (decisive only)'           AS cmp_label,
         'COMPATIBILITY_ONLY_NOT_PRODUCTION'                  AS z_score_alias_status
  FROM pr p

  GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer
) t;

-- ── §B · 双键全序检定（K3 现行 ORDER BY ／ K4 实际 GROUP BY）★ STOP Gate ──
-- ▸ 导出：需要 —— 存为「数据库/R03b_keyorder_check_v2.csv」
WITH ranked AS (
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,
         b.category, b.eid,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'
),
ord AS (
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord WHERE is_sentinel_dealer = 0
  GROUP BY bet_side
),
ordb AS (
  SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet_date, o.round_key, o.bet_side,
         o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side
  FROM      ord o
  LEFT JOIN side_base s ON s.bet_side = o.bet_side
),
pr AS (
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, round_key,
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,
         COUNT(*) AS n_orders_in_round,
         SUM(stake * p_side)
           / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)
                       AS p_base_round_w,
         AVG(p_side)   AS p_base_round_unw,
         MAX(bet_side) AS main_side
  FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet_date, round_key
)
SELECT COUNT(*)                                                            AS n_rows,
       COUNT(DISTINCT CONCAT_WS('|', CAST(t.bet_date AS VARCHAR),
                                     CAST(t.uid AS VARCHAR),
                                     CAST(t.dealer_id AS VARCHAR)))        AS n_distinct_K3,
       COUNT(*) - COUNT(DISTINCT CONCAT_WS('|', CAST(t.bet_date AS VARCHAR),
                                                CAST(t.uid AS VARCHAR),
                                                CAST(t.dealer_id AS VARCHAR)))
                                                                           AS duplicate_K3_n,
       COUNT(DISTINCT CONCAT_WS('|', CAST(t.bet_date AS VARCHAR),
                                     CAST(t.uid AS VARCHAR),
                                     CAST(t.dealer_id AS VARCHAR),
                                     CAST(t.is_sentinel_dealer AS VARCHAR))) AS n_distinct_K4,
       COUNT(*) - COUNT(DISTINCT CONCAT_WS('|', CAST(t.bet_date AS VARCHAR),
                                                CAST(t.uid AS VARCHAR),
                                                CAST(t.dealer_id AS VARCHAR),
                                                CAST(t.is_sentinel_dealer AS VARCHAR)))
                                                                           AS duplicate_K4_n,
       CASE
         WHEN COUNT(*) <> COUNT(DISTINCT CONCAT_WS('|', CAST(t.bet_date AS VARCHAR),
                                CAST(t.uid AS VARCHAR), CAST(t.dealer_id AS VARCHAR),
                                CAST(t.is_sentinel_dealer AS VARCHAR)))
              THEN 'K4 亦有并列 → 粒度/主体定义问题，禁入 §C'
         WHEN COUNT(*) <> COUNT(DISTINCT CONCAT_WS('|', CAST(t.bet_date AS VARCHAR),
                                CAST(t.uid AS VARCHAR), CAST(t.dealer_id AS VARCHAR)))
              THEN 'K3 非全序·K4 唯一 → ORDER BY 未覆盖 GROUP BY 全部区分键，分页边界不稳定风险'
         ELSE 'K3 与 K4 皆唯一（惟唯一性 ≠ 跨次导出稳定，仍须 Run A/B + CC-03）'
       END                                                                 AS verdict
FROM (
  SELECT p.bet_date, p.member_id AS uid, p.dealer_id, p.is_sentinel_dealer,
         SUM(p.stake)                                        AS stake_amount,
         SUM(p.game_pnl)                                     AS profit_amount,
         SUM(p.net_pnl)                                      AS net_pnl,
         SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,
         SUM(p.n_orders_in_round)                            AS n_related_orders,
         COUNT(*)                                            AS n_rounds_eff,
         AVG(p.p_base_round_w)                                 AS p_base_mix_w,
         AVG(p.p_base_round_unw)                             AS p_base_mix_unw,
         (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
          - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))
           / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                         * AVG(p.p_base_round_w)
                         * (1 - AVG(p.p_base_round_w))), 0)        AS z_score_w,
         (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
          - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_unw))
           / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                         * AVG(p.p_base_round_unw)
                         * (1 - AVG(p.p_base_round_unw))), 0)    AS z_score_unw,
         (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
          - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))
           / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                         * AVG(p.p_base_round_w)
                         * (1 - AVG(p.p_base_round_w))), 0)        AS z_score,
         AVG(p.p_base_round_w) - AVG(p.p_base_round_unw)          AS delta_p,
         CASE WHEN p.is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'
              WHEN AVG(p.p_base_round_w) IS NULL THEN 'NO_BASE_RATE'
              WHEN SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_DECISIVE_ROUND'
              ELSE 'ELIGIBLE' END                                 AS eligibility_status,
         'R03b_20260811_FULL_v1'                              AS comparison_id,
         'L1_ELIGIBILITY'                           AS filter_stage,
         'v2026-08-11'                              AS filter_rule_version,
         '2026-03-21..2026-08-06'                             AS cmp_time_window,
         'baccarat_bet02_101_all_pairs_incl_sentinel'         AS cmp_population,
         'round_win = game_pnl > 0 (decisive only)'           AS cmp_label,
         'COMPATIBILITY_ONLY_NOT_PRODUCTION'                  AS z_score_alias_status
  FROM pr p

  GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer
) t;

-- ── §D · K3 并列成因归因 ＋ cmp_time_window 实况核验（v2 新增）───────────
-- ▸ 导出：需要 —— 存为「数据库/R03b_tie_and_window_v2.csv」
-- ▸ §D-1 直接验证：K3 并列是否由同一 (日,会员,荷官) 兼具哨兵与非哨兵两行所致。
--   若 n_k3_with_both_sentinel_flags > 0 且恰等于 duplicate_K3_n，则成因坐实。
-- ▸ §D-2 窗口标签核验：declared 取自主体硬写常量，actual 取自实测边界，
--   两者关系由数据裁定，不得凭标签自动认定。
WITH ranked AS (
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,
         b.category, b.eid,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'
),
ord AS (
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord WHERE is_sentinel_dealer = 0
  GROUP BY bet_side
),
ordb AS (
  SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet_date, o.round_key, o.bet_side,
         o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side
  FROM      ord o
  LEFT JOIN side_base s ON s.bet_side = o.bet_side
),
pr AS (
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, round_key,
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,
         COUNT(*) AS n_orders_in_round,
         SUM(stake * p_side)
           / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)
                       AS p_base_round_w,
         AVG(p_side)   AS p_base_round_unw,
         MAX(bet_side) AS main_side
  FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet_date, round_key
)
, agg AS (
  SELECT t.bet_date, t.uid, t.dealer_id,
         COUNT(*)                                       AS n_rows_k3,
         COUNT(DISTINCT t.is_sentinel_dealer)           AS n_flag_values
  FROM (
    SELECT p.bet_date, p.member_id AS uid, p.dealer_id, p.is_sentinel_dealer,
           SUM(p.stake)                                        AS stake_amount,
           SUM(p.game_pnl)                                     AS profit_amount,
           SUM(p.net_pnl)                                      AS net_pnl,
           SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
             / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,
           SUM(p.n_orders_in_round)                            AS n_related_orders,
           COUNT(*)                                            AS n_rounds_eff,
           AVG(p.p_base_round_w)                                 AS p_base_mix_w,
           AVG(p.p_base_round_unw)                             AS p_base_mix_unw,
           (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
            - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))
             / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                           * AVG(p.p_base_round_w)
                           * (1 - AVG(p.p_base_round_w))), 0)        AS z_score_w,
           (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
            - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_unw))
             / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                           * AVG(p.p_base_round_unw)
                           * (1 - AVG(p.p_base_round_unw))), 0)    AS z_score_unw,
           (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
            - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))
             / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                           * AVG(p.p_base_round_w)
                           * (1 - AVG(p.p_base_round_w))), 0)        AS z_score,
           AVG(p.p_base_round_w) - AVG(p.p_base_round_unw)          AS delta_p,
           CASE WHEN p.is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'
                WHEN AVG(p.p_base_round_w) IS NULL THEN 'NO_BASE_RATE'
                WHEN SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_DECISIVE_ROUND'
                ELSE 'ELIGIBLE' END                                 AS eligibility_status,
           'R03b_20260811_FULL_v1'                              AS comparison_id,
           'L1_ELIGIBILITY'                           AS filter_stage,
           'v2026-08-11'                              AS filter_rule_version,
           '2026-03-21..2026-08-06'                             AS cmp_time_window,
           'baccarat_bet02_101_all_pairs_incl_sentinel'         AS cmp_population,
           'round_win = game_pnl > 0 (decisive only)'           AS cmp_label,
           'COMPATIBILITY_ONLY_NOT_PRODUCTION'                  AS z_score_alias_status
    FROM pr p

    GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer
  ) t
  GROUP BY t.bet_date, t.uid, t.dealer_id
)
SELECT SUM(CASE WHEN n_rows_k3 > 1 THEN 1 ELSE 0 END)              AS n_k3_groups_dup,
       SUM(CASE WHEN n_rows_k3 > 1 THEN n_rows_k3 - 1 ELSE 0 END)  AS n_k3_excess_rows,
       SUM(CASE WHEN n_flag_values = 2 THEN 1 ELSE 0 END)          AS n_k3_with_both_flags,
       SUM(CASE WHEN n_rows_k3 > 1 AND n_flag_values = 1 THEN 1 ELSE 0 END)
                                                                   AS n_k3_dup_not_by_sentinel,
       MAX(n_rows_k3)                                              AS max_rows_per_k3,
       '2026-03-21..2026-08-06'                                    AS declared_time_window,
       'b.dt >= 2026-03-21 AND b.dt < 2026-08-07 (half-open)'      AS actual_where_predicate,
       MIN(bet_date)                                               AS derived_min_bet_date,
       MAX(bet_date)                                               AS derived_max_bet_date,
       CASE WHEN MIN(bet_date) = '2026-03-21' AND MAX(bet_date) = '2026-08-06'
              THEN 'LABEL_MATCH'
            WHEN MIN(bet_date) IS NULL OR MAX(bet_date) IS NULL
              THEN 'UNKNOWN'
            ELSE 'LABEL_MISMATCH' END                              AS window_label_verdict
FROM agg;
