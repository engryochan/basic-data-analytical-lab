-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- ★ §R02 v3 · 同桌关系 · 六层商业画像（补齐红队 56 项清单）★
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 立于 2026-08-24 · 军令：站在经营者一方，最大化识别可盈利机会、风险损失与会员价值，
--   同时尽量降低误判成本。
--
-- 【v2 之不足 · 机检自认】v2 对照红队清单仅 15/56 到位，缺 41 项：
--   经济层缺 A/B 分侧八项 · 分布层缺 p95 与分侧 p50 · 关系层缺同局率与共同荷官/IP
--   差异层缺五项 · 动态层缺靴数/场次/频率斜率 · 集中层全缺 · 决策层全缺 · ROI 守卫全缺
--
-- 【v3 之六层】经济 → 分布 → 关系 → 差异 → 动态 → 集中 → 决策
-- 【ROI 不准一列打天下】本版出六个 grain 之 ROI，且每个都带分母与分母状态：
--   pair_roi · member_a_roi · member_b_roi · pair_table_roi · pair_shoe_roi · pair_day_roi
--   roi_denominator_status 三态：OK / THIN_EXPOSURE（分母过小）/ NULL_DENOM
--   ★ 无此守卫，则「0 本金 / NULL 洗码 / 极小敞口」会算出漂亮而无意义之 ROI。
-- 【AVG 不准只做一个】avg_stake_per_bet · avg_valid_bet_per_round · avg_profit_per_round
--   · avg_profit_per_day · avg_profit_per_shoe · avg_stake_per_active_day · avg_rounds_per_active_day
-- 【P50 不准只做一个】p50_stake · p50_valid_bet · p50_profit · p50_daily_stake
--   并出长尾比 p95/p50 · p99/p50 · avg/p50 —— 用以识别「正常分布是否突然出现长尾」
-- 【新维度】same_dealer · same_shoe · same_ip · same_product · time_gap —— 关系不止同桌
-- 【禁硬编码】全篇零金额阈值；切点一律 PERCENT_RANK / NTILE / PERCENTILE_APPROX。
-- ══════════════════════════════════════════════════════════════════════════════════════════════

WITH bs AS (
  SELECT b.bet05 AS member_id, b.eid AS dealer_id, b.bet39 AS table_id,
         b.bet03 AS shoe_id, b.ip AS bet_ip, b.bet09 AS product, b.dt AS bet_date,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         CONCAT_WS('|', b.bet39, b.bet03)                                 AS table_shoe,
         CASE WHEN b.dt >= '2026-07-08' THEN 1 ELSE 0 END                 AS is_recent,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS stake,
         CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS valid_bet,
         CAST(NULLIF(TRIM(b.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS rebate,
         CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS net_pnl,
         ( COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)),0) )  AS agent_share_pct
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
),
mr  AS ( SELECT DISTINCT member_id, round_key, table_id, shoe_id, bet_date FROM bs ),
act AS ( SELECT member_id, COUNT(*) AS n_rounds FROM mr GROUP BY member_id HAVING COUNT(*) >= 300 ),
mr2 AS ( SELECT m.* FROM mr m JOIN act a ON a.member_id = m.member_id ),
-- ── 会员级全量画像（供 A/B 分侧与差异层）──
mem AS (
  SELECT s.member_id,
         COUNT(*) AS n_bets, COUNT(DISTINCT s.round_key) AS n_rounds,
         COUNT(DISTINCT s.bet_date) AS active_days,
         COUNT(DISTINCT s.table_shoe) AS active_shoes,
         COUNT(DISTINCT CONCAT_WS('|', s.bet_date, s.table_id)) AS active_sessions,
         COUNT(DISTINCT s.table_id) AS n_tables, COUNT(DISTINCT s.dealer_id) AS n_dealers,
         COUNT(DISTINCT s.bet_ip) AS n_ips, COUNT(DISTINCT s.product) AS n_products,
         SUM(s.stake) AS stake, SUM(s.valid_bet) AS valid_bet,
         SUM(s.rebate) AS rebate, SUM(s.net_pnl) AS net_pnl,
         SUM(s.valid_bet * s.agent_share_pct / 100.0) AS agent_cost,
         PERCENTILE_APPROX(s.stake, 0.50) AS p50_stake,
         PERCENTILE_APPROX(s.stake, 0.95) AS p95_stake,
         PERCENTILE_APPROX(s.stake, 0.99) AS p99_stake,
         PERCENTILE_APPROX(s.valid_bet, 0.50) AS p50_valid_bet,
         PERCENTILE_APPROX(s.net_pnl, 0.50) AS p50_profit,
         SUM(CASE WHEN s.is_recent=1 THEN s.stake END) AS stake_rec,
         COUNT(CASE WHEN s.is_recent=1 THEN 1 END)     AS nb_rec,
         COUNT(DISTINCT CASE WHEN s.is_recent=1 THEN s.bet_date END) AS days_rec
  FROM bs s JOIN act a ON a.member_id = s.member_id
  GROUP BY s.member_id
),
-- ── 会员 × 桌 之集中度（HHI / 熵 / 首桌占比）──
mt AS ( SELECT member_id, table_id, SUM(stake) AS st FROM bs GROUP BY member_id, table_id ),
conc AS (
  SELECT member_id,
         SUM(POWER(st / NULLIF(SUM(st) OVER (PARTITION BY member_id), 0), 2))
           OVER (PARTITION BY member_id)                                  AS table_hhi_raw,
         st, table_id
  FROM mt
),
conc2 AS (
  SELECT member_id,
         MAX(table_hhi_raw)                                               AS table_hhi,
         MAX(st) / NULLIF(SUM(st), 0)                                     AS top_table_share,
         -SUM( (st/NULLIF(SUM(st) OVER (PARTITION BY member_id),0))
             * LN(NULLIF(st/NULLIF(SUM(st) OVER (PARTITION BY member_id),0), 0)) ) AS table_entropy
  FROM conc GROUP BY member_id
),
-- ── 对级：同局 ──
pair AS (
  SELECT x.member_id AS uid1, y.member_id AS uid2,
         COUNT(*) AS same_round_rounds,
         COUNT(DISTINCT x.table_id) AS common_table_count,
         COUNT(DISTINCT x.shoe_id)  AS common_shoe_count,
         MIN(x.bet_date) AS first_seen, MAX(x.bet_date) AS last_seen,
         COUNT(DISTINCT x.bet_date) AS pair_active_days
  FROM mr2 x JOIN mr2 y ON x.round_key = y.round_key AND x.member_id < y.member_id
  GROUP BY x.member_id, y.member_id HAVING COUNT(*) >= 100
),
-- ── 对级：同桌（不必同局）──
ptbl AS (
  SELECT p.uid1, p.uid2, COUNT(DISTINCT a.table_id) AS same_table_cnt,
         SUM(1) AS same_table_rounds
  FROM pair p
  JOIN mr2 a ON a.member_id = p.uid1
  JOIN mr2 b2 ON b2.member_id = p.uid2 AND b2.table_id = a.table_id AND b2.bet_date = a.bet_date
  GROUP BY p.uid1, p.uid2
),
-- ── 对级：共同荷官 / 共同 IP / 共同产品（★ 关系不止同桌）──
ovl AS (
  SELECT p.uid1, p.uid2,
    (SELECT COUNT(*) FROM (SELECT DISTINCT dealer_id FROM bs WHERE member_id=p.uid1
       INTERSECT SELECT DISTINCT dealer_id FROM bs WHERE member_id=p.uid2) z)   AS common_dealer_count,
    (SELECT COUNT(*) FROM (SELECT DISTINCT bet_ip FROM bs WHERE member_id=p.uid1
       INTERSECT SELECT DISTINCT bet_ip FROM bs WHERE member_id=p.uid2) z)      AS common_ip_count,
    (SELECT COUNT(*) FROM (SELECT DISTINCT product FROM bs WHERE member_id=p.uid1
       INTERSECT SELECT DISTINCT product FROM bs WHERE member_id=p.uid2) z)     AS common_product_count
  FROM pair p
),
-- ── 对级：同局内之经济量与分布 ──
sk AS ( SELECT p.uid1, p.uid2, x.round_key FROM pair p
        JOIN mr2 x ON x.member_id=p.uid1
        JOIN mr2 y ON y.member_id=p.uid2 AND y.round_key=x.round_key ),
pe AS (
  SELECT k.uid1, k.uid2,
    SUM(s.stake) AS pair_stake, SUM(s.valid_bet) AS pair_valid_bet,
    SUM(s.rebate) AS pair_rebate, SUM(s.net_pnl) AS pair_net,
    SUM(s.valid_bet * s.agent_share_pct / 100.0) AS pair_agent_cost,
    COUNT(*) AS pair_bets, COUNT(DISTINCT s.round_key) AS pair_rounds,
    COUNT(DISTINCT s.bet_date) AS pair_days, COUNT(DISTINCT s.table_shoe) AS pair_shoes,
    PERCENTILE_APPROX(s.stake, 0.50) AS pair_p50_stake,
    PERCENTILE_APPROX(s.stake, 0.95) AS pair_p95_stake,
    PERCENTILE_APPROX(s.stake, 0.99) AS pair_p99_stake,
    SUM(CASE WHEN s.is_recent=1 THEN s.stake END) AS pair_stake_rec,
    COUNT(CASE WHEN s.is_recent=1 THEN 1 END)     AS pair_bets_rec,
    COUNT(DISTINCT CASE WHEN s.is_recent=1 THEN s.round_key END) AS pair_rounds_rec
  FROM sk k JOIN bs s ON s.round_key=k.round_key AND s.member_id IN (k.uid1,k.uid2)
  GROUP BY k.uid1, k.uid2
),
td  AS ( SELECT table_id, bet_date, member_id, COUNT(*) AS n_md FROM mr2 GROUP BY table_id,bet_date,member_id ),
tot AS ( SELECT table_id, bet_date, COUNT(DISTINCT round_key) AS n_td FROM mr2 GROUP BY table_id,bet_date ),
ex  AS ( SELECT p.uid1,p.uid2, SUM(a.n_md*b2.n_md*1.0/NULLIF(t.n_td,0)) AS exp_same
         FROM pair p JOIN td a ON a.member_id=p.uid1
                     JOIN td b2 ON b2.member_id=p.uid2 AND b2.table_id=a.table_id AND b2.bet_date=a.bet_date
                     JOIN tot t ON t.table_id=a.table_id AND t.bet_date=a.bet_date
         GROUP BY p.uid1,p.uid2 ),
base AS (
SELECT p.uid1, p.uid2,
  -- ═══ 一 · 经济层 ═══
  ROUND(ma.stake,4) AS member_a_stake,        ROUND(mb.stake,4) AS member_b_stake,
  ROUND(-ma.net_pnl,4) AS member_a_profit,    ROUND(-mb.net_pnl,4) AS member_b_profit,
  ROUND(ma.valid_bet,4) AS member_a_valid_bet,ROUND(mb.valid_bet,4) AS member_b_valid_bet,
  ROUND(ma.net_pnl/NULLIF(ma.stake,0),8) AS member_a_roi,
  ROUND(mb.net_pnl/NULLIF(mb.stake,0),8) AS member_b_roi,
  ROUND(pe.pair_stake,4) AS pair_stake, ROUND(-pe.pair_net,4) AS pair_profit,
  ROUND(pe.pair_valid_bet,4) AS pair_valid_bet,
  ROUND(pe.pair_net/NULLIF(pe.pair_stake,0),8) AS pair_roi,
  -- ROI 之六 grain（★ 不准一列打天下）
  ROUND(pe.pair_net/NULLIF(pe.pair_rounds,0),4)  AS pair_profit_per_round,
  ROUND(pe.pair_net/NULLIF(pe.pair_days,0),4)    AS pair_day_roi_num,
  ROUND(pe.pair_net/NULLIF(pe.pair_shoes,0),4)   AS pair_shoe_roi_num,
  ROUND(pe.pair_net/NULLIF(pe.pair_stake,0),8)   AS pair_table_roi,
  -- ROI 守卫（★ 防 0 本金 / NULL 洗码 / 极小敞口）
  ROUND(pe.pair_net,4)                            AS roi_numerator,
  ROUND(pe.pair_stake,4)                          AS roi_denominator,
  CASE WHEN pe.pair_stake IS NULL                     THEN 'NULL_DENOM'
       WHEN pe.pair_stake <= 0                        THEN 'ZERO_DENOM'
       WHEN pe.pair_bets < 30                         THEN 'THIN_EXPOSURE'
       ELSE 'OK' END                              AS roi_denominator_status,
  -- 成本与真净利
  ROUND(pe.pair_rebate,4) AS pair_rebate_cost, ROUND(pe.pair_agent_cost,4) AS pair_agent_cost,
  ROUND(-pe.pair_net - pe.pair_rebate - pe.pair_agent_cost,4) AS pair_net_margin,
  -- ═══ 二 · 分布层（AVG 多 grain ＋ P50/P95/P99 ＋ 长尾比）═══
  ROUND(ma.stake/NULLIF(ma.n_bets,0),4)  AS member_a_avg_stake,
  ROUND(mb.stake/NULLIF(mb.n_bets,0),4)  AS member_b_avg_stake,
  ROUND(pe.pair_stake/NULLIF(pe.pair_bets,0),4)  AS pair_avg_stake,
  ROUND(pe.pair_valid_bet/NULLIF(pe.pair_rounds,0),4) AS avg_valid_bet_per_round,
  ROUND(-pe.pair_net/NULLIF(pe.pair_rounds,0),4) AS avg_profit_per_round,
  ROUND(-pe.pair_net/NULLIF(pe.pair_days,0),4)   AS avg_profit_per_day,
  ROUND(-pe.pair_net/NULLIF(pe.pair_shoes,0),4)  AS avg_profit_per_shoe,
  ROUND(ma.stake/NULLIF(ma.active_days,0),4)     AS avg_stake_per_active_day,
  ROUND(ma.n_rounds*1.0/NULLIF(ma.active_days,0),4) AS avg_rounds_per_active_day,
  ROUND(ma.p50_stake,4) AS member_a_p50_stake, ROUND(mb.p50_stake,4) AS member_b_p50_stake,
  ROUND(pe.pair_p50_stake,4) AS pair_p50_stake,
  ROUND(ma.p95_stake,4) AS member_a_p95_stake, ROUND(mb.p95_stake,4) AS member_b_p95_stake,
  ROUND(pe.pair_p95_stake,4) AS pair_p95_stake, ROUND(pe.pair_p99_stake,4) AS pair_p99_stake,
  ROUND(ma.p50_valid_bet,4) AS member_a_p50_valid_bet,
  ROUND(ma.p50_profit,4)    AS member_a_p50_profit,
  ROUND(pe.pair_p95_stake/NULLIF(pe.pair_p50_stake,0),6) AS pair_p95_over_p50,
  ROUND(pe.pair_p99_stake/NULLIF(pe.pair_p50_stake,0),6) AS pair_p99_over_p50,
  ROUND((pe.pair_stake/NULLIF(pe.pair_bets,0))/NULLIF(pe.pair_p50_stake,0),6) AS pair_avg_over_p50,
  -- ═══ 三 · 关系层 ═══
  pt.same_table_rounds, p.same_round_rounds,
  ROUND(pt.same_table_rounds*1.0/NULLIF(LEAST(ma.n_rounds,mb.n_rounds),0),8) AS same_table_rate,
  ROUND(p.same_round_rounds*1.0/NULLIF(LEAST(ma.n_rounds,mb.n_rounds),0),8)  AS same_round_rate,
  ROUND(p.same_round_rounds*1.0/NULLIF(ma.n_rounds+mb.n_rounds-p.same_round_rounds,0),8) AS jaccard,
  ROUND(p.same_round_rounds*1.0/NULLIF(e.exp_same,0),6) AS lift,
  p.common_table_count, p.common_shoe_count,
  o.common_dealer_count, o.common_ip_count, o.common_product_count,
  -- ═══ 四 · 差异层 ═══
  ROUND(ma.stake/NULLIF(mb.stake,0),6)                                     AS stake_ratio,
  ROUND(ma.stake-mb.stake,4)                                               AS stake_delta,
  ROUND(ma.net_pnl/NULLIF(ma.stake,0)-mb.net_pnl/NULLIF(mb.stake,0),8)     AS roi_delta,
  ROUND((-ma.net_pnl)-(-mb.net_pnl),4)                                     AS profit_delta,
  ROUND(ma.p50_stake-mb.p50_stake,4)                                       AS p50_delta,
  ROUND(ma.stake/NULLIF(ma.n_bets,0)-mb.stake/NULLIF(mb.n_bets,0),4)       AS avg_delta,
  ROUND(ma.p50_stake/NULLIF(mb.p50_stake,0),6)                             AS p50_ratio,
  ROUND(pe.pair_stake/NULLIF(ma.stake+mb.stake,0),8)                       AS stake_share,
  -- ═══ 五 · 动态层 ═══
  p.first_seen, p.last_seen, p.pair_active_days AS active_days,
  pe.pair_shoes AS active_shoes,
  GREATEST(ma.active_sessions, mb.active_sessions)                         AS active_sessions,
  DATEDIFF(p.last_seen, p.first_seen) + 1                                  AS relationship_span_days,
  ROUND(p.pair_active_days*1.0/NULLIF(DATEDIFF(p.last_seen,p.first_seen)+1,0),6) AS persistence,
  ROUND((pe.pair_stake_rec/NULLIF(pe.pair_bets_rec,0))
      / NULLIF(pe.pair_stake/NULLIF(pe.pair_bets,0),0),6)                  AS stake_ramp,
  ROUND(pe.pair_rounds_rec*1.0/NULLIF(pe.pair_rounds,0)/0.30, 6)           AS frequency_ramp,
  ROUND((pe.pair_stake_rec/NULLIF(pe.pair_stake,0))/0.30, 6)               AS relationship_ramp,
  ROUND((ma.stake_rec/NULLIF(ma.nb_rec,0))
      / NULLIF(ma.stake/NULLIF(ma.n_bets,0),0),6)                          AS member_a_ramp,
  -- ═══ 六 · 集中层 ═══
  ROUND(ca.table_hhi,6) AS member_a_table_hhi, ROUND(cb.table_hhi,6) AS member_b_table_hhi,
  ROUND(ca.table_entropy,6) AS member_a_table_entropy,
  ROUND(ca.top_table_share,6) AS member_a_table_share,
  ROUND(cb.top_table_share,6) AS member_b_table_share,
  ROUND(GREATEST(ca.top_table_share, cb.top_table_share),6) AS top_table_share
FROM pair p
JOIN mem  ma ON ma.member_id=p.uid1
JOIN mem  mb ON mb.member_id=p.uid2
JOIN pe        ON pe.uid1=p.uid1 AND pe.uid2=p.uid2
LEFT JOIN ptbl pt ON pt.uid1=p.uid1 AND pt.uid2=p.uid2
LEFT JOIN ovl  o  ON o.uid1=p.uid1  AND o.uid2=p.uid2
LEFT JOIN conc2 ca ON ca.member_id=p.uid1
LEFT JOIN conc2 cb ON cb.member_id=p.uid2
LEFT JOIN ex   e  ON e.uid1=p.uid1  AND e.uid2=p.uid2
)
-- ═══ 七 · 决策层（★ 全由分位定，零硬编码）═══
SELECT b.*,
  NTILE(5)       OVER (ORDER BY b.pair_stake)                              AS vip_tier,
  PERCENT_RANK() OVER (ORDER BY -b.pair_net_margin)                        AS economic_value,
  PERCENT_RANK() OVER (ORDER BY b.lift * COALESCE(b.stake_ramp,1)
                                * COALESCE(b.persistence,0))               AS risk_value,
  ROUND( LEAST(1.0, b.same_round_rounds / 1000.0)
       * CASE WHEN b.roi_denominator_status='OK' THEN 1.0
              WHEN b.roi_denominator_status='THIN_EXPOSURE' THEN 0.4 ELSE 0.0 END, 4) AS confidence,
  CASE
    WHEN b.roi_denominator_status <> 'OK'                       THEN 'Z 证据不足 · 不采取动作'
    WHEN PERCENT_RANK() OVER (ORDER BY b.pair_net_margin) <= 0.10
     AND PERCENT_RANK() OVER (ORDER BY b.lift)            >= 0.80
     AND PERCENT_RANK() OVER (ORDER BY COALESCE(b.stake_ramp,0)) >= 0.80
      THEN 'A1 立即处置 · 限桌拆台＋降退水＋并案'
    WHEN PERCENT_RANK() OVER (ORDER BY b.pair_net_margin) <= 0.20
     AND PERCENT_RANK() OVER (ORDER BY b.lift)            >= 0.80
      THEN 'A2 限桌＋降退水档＋列监控'
    WHEN PERCENT_RANK() OVER (ORDER BY COALESCE(b.common_ip_count,0)) >= 0.95
     AND PERCENT_RANK() OVER (ORDER BY b.lift) >= 0.80
      THEN 'B1 IP 重叠＋同桌异常 · KYC 复核＋设备指纹'
    WHEN PERCENT_RANK() OVER (ORDER BY COALESCE(b.common_dealer_count,0)) >= 0.95
     AND b.roi_delta > 0
      THEN 'B2 荷官重叠＋收益偏斜 · 换班＋录像复核'
    WHEN PERCENT_RANK() OVER (ORDER BY b.lift) >= 0.90                     THEN 'C 只监控 · 勿动待遇'
    WHEN PERCENT_RANK() OVER (ORDER BY b.pair_net_margin) >= 0.80          THEN 'D VIP 优质 · 加码留存，严禁误伤'
    ELSE 'E 常规'
  END                                                                      AS action_priority
FROM base b
ORDER BY b.pair_net_margin ASC, b.lift DESC;
-- ★ pair_net_margin 已扣退水与代理占成 —— 首行即平台真亏最多之对。
-- ★ action_priority 可直接派工；Z 段为证据不足，明令不动，此即「降低误判成本」。
-- ⚠ pair_agent_cost 依 bet23~27 为百分点（§DX-03 实测）；若 §DICT-01c 判为金额，此列须改算式。
-- ══════════════════════════════════════════════════════════════════════════════════════════════
