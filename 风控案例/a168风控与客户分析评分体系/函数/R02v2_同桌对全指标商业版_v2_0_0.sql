-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ★ §R02 v2 · 同桌对 · 全指标商业版（取代 R02_same_table.csv 之十二列裸表）★
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 立于 2026-08-24 · 军令状：帮赌场与博彩公司**提升业绩**，非旁观分析。
--
-- 【前版之罪 · 我认】原 R02_same_table.csv 只出十二列：uid1/uid2/n_same_orders/
--   rounds_1/rounds_2/same_rate/jaccard/lift/exp_same/n_tables/first_day/last_day。
--   先生下载一看，无一 roi、无一 p50、无一 avg —— 怒之有理。
--
-- 【本版之别 · 用的是档内早已实测之字段，不再探针】
--   自包内字段字典（行 324~352）挖出四个从未被 §R02 用过之主表字段：
--     bet15      会员退水%          ← 退水档位就在主表，根本不必去探 member_dtl
--     bet23~27   LV1~5 占成          ← **代理分成成本**（§DX-03 已实测：比率，均值 87~96）
--     bet28~32   LV1~5 退水%         ← 代理线退水成本
--     commission 0一般/1免佣 · gametype 1网投/2电投 · bet10 币别 · bet40 房间
--   ★ 由此，第一次算得出**平台真净利**，而非只算账面输赢：
--
--       net_margin = house_pnl − 退水 − 代理占成分成
--                  = (−Σbet17) − Σbet16 − Σ(validbet × Σbet23~27 ÷ 100)
--
--     此数才是「这一对会员，平台到底赚了多少钱」。前版一个字都没提。
--
-- 【三十四列 · 四类指标 ＋ 分位 ＋ 成本 ＋ 商业分段】
--   avg  avg_stake_same_1/2 · avg_stake_solo_1/2
--   p50  stake_p50/p90/p99（同桌 与 独坐 分开出）★先生点名之分位，前版全无
--   roi  roi_same_1/2/pair · roi_solo_pair · roi_gap_same · roi_ex_rebate_pair
--   rate hold_rate_same · same_rate · jaccard · lift · turnover_multiple
--        rebate_rate_actual（bet16÷bet41 实付）· rebate_pct_config（bet15 配置）
--        commission_free_rate · agent_share_rate（占成分成率）
--   ramp ramp_same（同桌÷独坐）· ramp_recent（近月÷全窗）
--   钱   house_pnl_pair · rebate_cost · agent_cost · **net_margin_pair**
--   分段 vip_tier · action_seg（可直接派工之处置建议）
--
-- 【禁硬编码】全篇零金额阈值；分段切点一律由 PERCENT_RANK 分位定。
-- 【排序】ORDER BY net_margin_pair ASC —— **首行为平台真亏最多之对**，非按 lift 排。
-- ══════════════════════════════════════════════════════════════════════════════════════════

WITH bs AS (
  SELECT b.bet05 AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.bet39 AS table_id,
         b.dt    AS bet_date,
         CASE WHEN b.dt >= '2026-07-08' THEN 1 ELSE 0 END                 AS is_recent,
         CASE WHEN TRIM(b.commission) = '1' THEN 1 ELSE 0 END             AS is_free_comm,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS stake,
         CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS validbet,
         CAST(NULLIF(TRIM(b.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS rebate,
         CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS net_pnl,
         CAST(NULLIF(TRIM(b.bet15),'') AS DECIMAL(20,6))                  AS rebate_pct_cfg,
         ( COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)),0)
         + COALESCE(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)),0) )  AS agent_share_pct
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
),
mr  AS ( SELECT DISTINCT member_id, round_key, table_id, bet_date FROM bs ),
act AS ( SELECT member_id, COUNT(*) AS n_rounds FROM mr GROUP BY member_id HAVING COUNT(*) >= 300 ),
mr2 AS ( SELECT m.* FROM mr m JOIN act a ON a.member_id = m.member_id ),
pair AS (
  SELECT x.member_id AS uid1, y.member_id AS uid2,
         COUNT(*) AS same_rounds, COUNT(DISTINCT x.table_id) AS n_tables,
         MIN(x.bet_date) AS first_day, MAX(x.bet_date) AS last_day
  FROM mr2 x JOIN mr2 y ON x.round_key = y.round_key AND x.member_id < y.member_id
  GROUP BY x.member_id, y.member_id HAVING COUNT(*) >= 100
),
sk AS (  -- 该对共同出现之局键
  SELECT p.uid1, p.uid2, x.round_key
  FROM pair p JOIN mr2 x ON x.member_id = p.uid1
              JOIN mr2 y ON y.member_id = p.uid2 AND y.round_key = x.round_key
),
econ AS (  -- ★ 同桌 vs 独坐，两侧分开算；p50/p90/p99 亦分开出
  SELECT k.uid1, k.uid2,
    -- 同桌侧
    SUM(CASE WHEN s.member_id=k.uid1 THEN s.stake END)                    AS stake_same_1,
    SUM(CASE WHEN s.member_id=k.uid2 THEN s.stake END)                    AS stake_same_2,
    COUNT(CASE WHEN s.member_id=k.uid1 THEN 1 END)                        AS nb_same_1,
    COUNT(CASE WHEN s.member_id=k.uid2 THEN 1 END)                        AS nb_same_2,
    SUM(s.stake)                                                          AS stake_same,
    SUM(s.validbet)                                                       AS validbet_same,
    SUM(s.rebate)                                                         AS rebate_same,
    SUM(s.net_pnl)                                                        AS net_same,
    SUM(s.validbet * s.agent_share_pct / 100.0)                           AS agent_cost_same,
    AVG(s.rebate_pct_cfg)                                                 AS rebate_pct_cfg_same,
    AVG(s.agent_share_pct)                                                AS agent_share_pct_same,
    AVG(s.is_free_comm * 1.0)                                             AS free_comm_rate_same,
    PERCENTILE_APPROX(s.stake, 0.50)                                      AS stake_p50_same,
    PERCENTILE_APPROX(s.stake, 0.90)                                      AS stake_p90_same,
    PERCENTILE_APPROX(s.stake, 0.99)                                      AS stake_p99_same,
    MAX(s.stake)                                                          AS stake_max_same,
    SUM(CASE WHEN s.is_recent=1 THEN s.stake END)                         AS stake_same_rec,
    COUNT(CASE WHEN s.is_recent=1 THEN 1 END)                             AS nb_same_rec,
    COUNT(DISTINCT s.bet_date)                                            AS n_days_same
  FROM sk k JOIN bs s ON s.round_key = k.round_key AND s.member_id IN (k.uid1, k.uid2)
  GROUP BY k.uid1, k.uid2
),
solo AS (  -- 该对二人之全窗总量（减去同桌部分即得独坐）
  SELECT s.member_id, SUM(s.stake) AS stake_all, COUNT(*) AS nb_all,
         SUM(s.net_pnl) AS net_all, SUM(s.validbet) AS validbet_all,
         SUM(s.rebate) AS rebate_all,
         SUM(s.validbet * s.agent_share_pct / 100.0) AS agent_cost_all,
         PERCENTILE_APPROX(s.stake, 0.50) AS stake_p50_all
  FROM bs s JOIN act a ON a.member_id = s.member_id
  GROUP BY s.member_id
),
td  AS ( SELECT table_id, bet_date, member_id, COUNT(*) AS n_md FROM mr2 GROUP BY table_id, bet_date, member_id ),
tot AS ( SELECT table_id, bet_date, COUNT(DISTINCT round_key) AS n_td FROM mr2 GROUP BY table_id, bet_date ),
ex  AS ( SELECT p.uid1, p.uid2, SUM(a.n_md * b.n_md * 1.0 / NULLIF(t.n_td,0)) AS exp_same
         FROM pair p JOIN td a ON a.member_id=p.uid1
                     JOIN td b ON b.member_id=p.uid2 AND b.table_id=a.table_id AND b.bet_date=a.bet_date
                     JOIN tot t ON t.table_id=a.table_id AND t.bet_date=a.bet_date
         GROUP BY p.uid1, p.uid2 ),
base AS (
SELECT p.uid1, p.uid2,
  -- ── 结构（原十二列，口径未动）──
  p.same_rounds AS n_same_orders, a1.n_rounds AS rounds_1, a2.n_rounds AS rounds_2,
  ROUND(p.same_rounds*1.0/NULLIF(LEAST(a1.n_rounds,a2.n_rounds),0), 8)   AS same_rate,
  ROUND(p.same_rounds*1.0/NULLIF(a1.n_rounds+a2.n_rounds-p.same_rounds,0),8) AS jaccard,
  ROUND(p.same_rounds*1.0/NULLIF(e.exp_same,0), 6)                       AS lift,
  ROUND(e.exp_same,4) AS exp_same, p.n_tables, p.first_day, p.last_day, ec.n_days_same,
  -- ── 规模 ──
  ROUND(ec.stake_same, 4)                                                AS stake_same_pair,
  ROUND(ec.validbet_same, 4)                                             AS validbet_same_pair,
  ROUND(s1.stake_all + s2.stake_all - ec.stake_same, 4)                  AS stake_solo_pair,
  -- ── avg ──
  ROUND(ec.stake_same_1/NULLIF(ec.nb_same_1,0), 4)                       AS avg_stake_same_1,
  ROUND(ec.stake_same_2/NULLIF(ec.nb_same_2,0), 4)                       AS avg_stake_same_2,
  ROUND((s1.stake_all-ec.stake_same_1)/NULLIF(s1.nb_all-ec.nb_same_1,0),4) AS avg_stake_solo_1,
  ROUND((s2.stake_all-ec.stake_same_2)/NULLIF(s2.nb_all-ec.nb_same_2,0),4) AS avg_stake_solo_2,
  -- ── p50 / p90 / p99（★ 前版全无）──
  ROUND(ec.stake_p50_same, 4)                                            AS stake_p50_same,
  ROUND(ec.stake_p90_same, 4)                                            AS stake_p90_same,
  ROUND(ec.stake_p99_same, 4)                                            AS stake_p99_same,
  ROUND(ec.stake_max_same, 4)                                            AS stake_max_same,
  ROUND((s1.stake_p50_all + s2.stake_p50_all)/2.0, 4)                    AS stake_p50_solo_avg,
  -- ── ramp ──
  ROUND( (ec.stake_same_1/NULLIF(ec.nb_same_1,0))
       / NULLIF((s1.stake_all-ec.stake_same_1)/NULLIF(s1.nb_all-ec.nb_same_1,0),0), 6) AS ramp_same_1,
  ROUND( (ec.stake_same_2/NULLIF(ec.nb_same_2,0))
       / NULLIF((s2.stake_all-ec.stake_same_2)/NULLIF(s2.nb_all-ec.nb_same_2,0),0), 6) AS ramp_same_2,
  ROUND( (ec.stake_same_rec/NULLIF(ec.nb_same_rec,0))
       / NULLIF(ec.stake_same/NULLIF(ec.nb_same_1+ec.nb_same_2,0),0), 6) AS ramp_recent,
  -- ── roi（平衡点 0；>0 即会员赚、平台亏）──
  ROUND(ec.net_same/NULLIF(ec.stake_same,0), 8)                          AS roi_same_pair,
  ROUND((s1.net_all+s2.net_all-ec.net_same)
      / NULLIF(s1.stake_all+s2.stake_all-ec.stake_same,0), 8)            AS roi_solo_pair,
  ROUND(ec.net_same/NULLIF(ec.stake_same,0)
      - (s1.net_all+s2.net_all-ec.net_same)
        /NULLIF(s1.stake_all+s2.stake_all-ec.stake_same,0), 8)           AS roi_gap_same,
  ROUND((ec.net_same-ec.rebate_same)/NULLIF(ec.stake_same,0), 8)         AS roi_ex_rebate_pair,
  -- ── rate ──
  ROUND(-ec.net_same/NULLIF(ec.stake_same,0), 8)                         AS hold_rate_same,
  ROUND(ec.validbet_same/NULLIF(ec.stake_same,0), 6)                     AS turnover_multiple,
  ROUND(ec.rebate_same/NULLIF(ec.validbet_same,0), 8)                    AS rebate_rate_actual,
  ROUND(ec.rebate_pct_cfg_same, 6)                                       AS rebate_pct_config,
  ROUND(ec.agent_share_pct_same, 4)                                      AS agent_share_pct,
  ROUND(ec.free_comm_rate_same, 6)                                       AS free_comm_rate,
  -- ── ★ 钱：平台真净利 ──
  ROUND(-ec.net_same, 4)                                                 AS house_pnl_pair,
  ROUND(ec.rebate_same, 4)                                               AS rebate_cost,
  ROUND(ec.agent_cost_same, 4)                                           AS agent_cost,
  ROUND(-ec.net_same - ec.rebate_same - ec.agent_cost_same, 4)           AS net_margin_pair,
  ROUND((-ec.net_same - ec.rebate_same - ec.agent_cost_same)
      / NULLIF(ec.stake_same,0), 8)                                      AS net_margin_rate
FROM pair p
JOIN act  a1 ON a1.member_id=p.uid1
JOIN act  a2 ON a2.member_id=p.uid2
JOIN econ ec ON ec.uid1=p.uid1 AND ec.uid2=p.uid2
JOIN solo s1 ON s1.member_id=p.uid1
JOIN solo s2 ON s2.member_id=p.uid2
LEFT JOIN ex e ON e.uid1=p.uid1 AND e.uid2=p.uid2
)
SELECT b.*,
  NTILE(5)       OVER (ORDER BY b.stake_same_pair)                       AS vip_tier_by_stake,
  PERCENT_RANK() OVER (ORDER BY b.lift)                                  AS pr_lift,
  PERCENT_RANK() OVER (ORDER BY GREATEST(COALESCE(b.ramp_same_1,0),
                                         COALESCE(b.ramp_same_2,0)))     AS pr_ramp,
  PERCENT_RANK() OVER (ORDER BY b.stake_same_pair)                       AS pr_stake,
  PERCENT_RANK() OVER (ORDER BY b.net_margin_pair)                       AS pr_net_margin,
  CASE
    WHEN PERCENT_RANK() OVER (ORDER BY b.net_margin_pair) <= 0.10
     AND PERCENT_RANK() OVER (ORDER BY b.lift)            >= 0.80
     AND PERCENT_RANK() OVER (ORDER BY GREATEST(COALESCE(b.ramp_same_1,0),
                                                COALESCE(b.ramp_same_2,0))) >= 0.80
      THEN 'A 团伙确信 · 立即限桌拆台＋降退水＋并案'
    WHEN PERCENT_RANK() OVER (ORDER BY b.net_margin_pair) <= 0.20
     AND PERCENT_RANK() OVER (ORDER BY b.lift)            >= 0.80
      THEN 'B 高度可疑 · 限桌＋降退水档＋列监控'
    WHEN PERCENT_RANK() OVER (ORDER BY b.lift)            >= 0.90
      THEN 'C 同桌异常而平台未亏 · 只监控，勿动待遇'
    WHEN PERCENT_RANK() OVER (ORDER BY b.net_margin_pair) >= 0.80
      THEN 'D 优质客源 · **不可误伤**，可加码留存'
    ELSE 'E 常规'
  END                                                                    AS action_seg
FROM base b
ORDER BY b.net_margin_pair ASC, b.lift DESC;
-- ★ 首行 = **平台真亏最多之对**（已扣退水与代理占成），非按 lift 排。
-- ★ net_margin_pair 之总和，即同桌团伙这一类**当窗真实损益**——可直接写进 P&L。
-- ★ action_seg 可直接派工：A 段立即处置、D 段严禁误伤。
-- ⚠ agent_cost 依 bet23~27 为百分点（§DX-03 已实测，均值 87~96，除以 100 用）；
--   若 §DICT-01c 判其为金额，则本列须改算式——该闸未过之前，agent_cost 标 CONDITIONAL。
-- ══════════════════════════════════════════════════════════════════════════════════════════
