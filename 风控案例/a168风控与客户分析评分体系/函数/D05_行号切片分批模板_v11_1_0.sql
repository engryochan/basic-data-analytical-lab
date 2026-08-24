-- ═══════════════════════════════════════════════════════════════════════════════
-- §D05 · 行号切片分批模板（ROW_NUMBER 法 · 逐件 · 共 129 件）
-- 立于 2026-08-24 · 配 a168_取数与核验_SQL总包_v11_1_0.sql（REL-0006 / C1）
-- 每批上限 100,000 行。★ 本法取代 §D04 之「序号补全序 + OFFSET」，缘由如下。
--
-- 【何以弃 §D04 而立本节】
--   §D04 之「原 ORDER BY 后追加 1..N」于数学上确为全序，重复与遗漏亦确归零；
--   然其致命短处是**不可自证**——跑完之后，操作者无从判断这一批与上一批是否真的
--   首尾相接。一旦某批贴错位置、或引擎某处不认序号，它照样静默地错。
--   而遗漏本就是看不见的：手上只有取回之档，无从知道少了谁。
--   本节改以 ROW_NUMBER 显式赋号，rn 随行落档，**每一批都能当场验明**。
--
-- 【自证之法（本节全部价值所在）】
--   第 k 批取回之后，跑四数：
--     SELECT COUNT(*) , COUNT(DISTINCT rn), MIN(rn), MAX(rn) FROM <该批>;
--   须同时满足：COUNT(*) = COUNT(DISTINCT rn)          （批内无重复）
--             MIN(rn) = (k-1)*100000 + 1              （与上批严丝合缝）
--             MAX(rn) = MIN(rn) + COUNT(*) - 1        （批内无缺口）
--   全批取毕，再验：各批 rn 之并集 = 1 .. T_true，无缺号、无重号。
--   ★ 此四数不符者，即刻停手回报，禁止放行。这是重复与遗漏唯一可当场揭发之处。
--
-- 【取数前】先跑并留档：
--   SELECT COUNT(*) AS T_true FROM ( <原查询去掉末尾 ORDER BY 与分号> ) x;
--   T_true <= 100000 者，一律一次导全，不必分页（见成本警示）。
--
-- 【成本警示】rn 之窗口无 PARTITION，须把整个结果集汇于一处定序；且每批皆重算整条链。
--   LIMIT 与 rn 切片皆只省传输、不省计算。故 **批数越少越好**，能一次导全就别分批。
--   （总包行 4455~4458 早有同判，此处相承。）
--
-- 【两处红旗 · 分页之前必先裁定】
--   ① 语句内**已含 LIMIT** 者 2 件：_P12b-pre.csv、PH0_8r1_rg_case.csv。
--      该 LIMIT 系查询本身之截断（取样／限行），非分页所用。若在其外再加 rn 切片，
--      所分之批只是那截断结果之片段，**并非全量**。须先裁定该 LIMIT 之去留。
--   ② 投影中**有列取不出别名**者 7 件（多为 UNION 分支中之字面量列）：
--      Z07_probe_bet02、Z08_roundkey_integrity、V_table_counts、P0C02_标签口径、
--      TL11c_population_reconcile、P02A_lmc_samples、PH0_8r2_rg_crosstable。
--      其排序键无法列全，本节为之给出的键**不构成全序**。此七件之处置：
--      先跑 T_true——皆为普查／汇总件，几可断定不足十万，**一次导全即可，不必分页**；
--      若确超十万，则须先为那几列补上列别名，方可用本法。
-- ═══════════════════════════════════════════════════════════════════════════════
-- 【关于导出之行序】OVER 内首列尽量接回原 ORDER BY 之意图（含 DESC），其后补齐
--   全部输出别名以成全序。若某原排序项非输出列（如带表前缀之内部引用），则舍去——
--   舍之无害：它本就无法保证全序，正是重复与遗漏之源。行序或与旧档略异，
--   然**行之集合逐行等同**；表头契约系于列，不系于行序，故不破契约。
-- ═══════════════════════════════════════════════════════════════════════════════

-- ──   1. A_anchor.csv   [总包行 2999~3009 · 输出 5 列 · 接回原序 1 项]
--    原 ORDER BY：n_orders DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders` DESC, y.`ip`, y.`n_member`, y.`first_dt`, y.`last_dt`) AS rn
  FROM (
    /* 在此贴入总包行 2999~3009 之原查询，删去其末尾 ORDER BY 与分号 */
    WITH gold AS (SELECT DISTINCT TRIM(ip) AS ip                                                        -- 公共表表达式：产出「ip」
              FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                         -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
              WHERE NULLIF(TRIM(ip),'') IS NOT NULL)                                                -- 过滤条件：限定该值非空
SELECT g.ip,                                                                                        -- 取列：起始取列子句，本行先列 g.ip
       COUNT(b.bet01) AS n_orders,                                                                  -- 计数表达式：产出「n_orders」
       COUNT(DISTINCT b.bet05) AS n_member,                                                         -- 计数表达式：统计去重个数，产出「n_member」
       MIN(b.dt) AS first_dt, MAX(b.dt) AS last_dt                                                  -- 取最小值表达式：取最大值，取用 dt（营业日），产出「last_dt」
FROM gold g                                                                                         -- 取数来源：取自本条自建的中间结果集 gold
LEFT JOIN ods_mariadb_2b.ods_a168_bet02 b                                                           -- 左连接：取自注单明细表（金额与行为口径的第一料源）
  ON TRIM(b.ip)=g.ip AND b.dt>='2026-03-21' AND b.dt<'2026-08-07' AND b.bet02='101'                 -- 连接键：限定 TRIM(b.ip)等于 g.ip、b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
GROUP BY g.ip ORDER BY n_orders DESC                                                               -- 分组：按 g.ip ORDER BY n_orders（降序）汇总
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   2. B01_bt_panel.csv   [总包行 5314~5392 · 输出 14 列 · 接回原序 2 项]
--    原 ORDER BY：bet_date, member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`bet_date`, y.`member_id`, y.`stake`, y.`game_pnl`, y.`net_pnl`, y.`rebate`, y.`validbet`, y.`n_rounds`, y.`n_tables`, y.`n_ip`, y.`late_def`, y.`late_share_d`, y.`hedge_rate_d`, y.`stake_cv_d`) AS rn
  FROM (
    /* 在此贴入总包行 5314~5392 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   3. B01_bt_panel_delta.csv   [总包行 5406~5484 · 输出 14 列 · 接回原序 2 项]
--    原 ORDER BY：member_id, bet_date
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`bet_date`, y.`stake`, y.`game_pnl`, y.`net_pnl`, y.`rebate`, y.`validbet`, y.`n_rounds`, y.`n_tables`, y.`n_ip`, y.`late_def`, y.`late_share_d`, y.`hedge_rate_d`, y.`stake_cv_d`) AS rn
  FROM (
    /* 在此贴入总包行 5406~5484 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   4. B4_2b_funnel_and_mu0.csv   [总包行 11938~12058 · 输出 26 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_raw`, y.`n_g1`, y.`n_g2`, y.`n_g3`, y.`n_g4`, y.`n_g5`, y.`n_g6`, y.`n_g7`, y.`n_g8`, y.`n_lv1`, y.`n_lv2`, y.`n_lv3`, y.`n_lv4`, y.`n_lv5`, y.`n_any_test`, y.`mu0_global_dirty_ew_pct`, y.`mu0_global_clean_ew_pct`, y.`contamination_pp`, y.`n_groups`, y.`mu0_min_pct`, y.`mu0_max_pct`, y.`abs_min`, y.`abs_max`, y.`n_near_zero`, y.`spread_ratio`, y.`verdict_spread`) AS rn
  FROM (
    /* 在此贴入总包行 11938~12058 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   5. B4_5b_tip_nature.csv   [总包行 12072~12103 · 输出 16 列 · 接回原序 2 项]
--    原 ORDER BY：n_rows DESC, bet09_value
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rows` DESC, y.`bet09_value`, y.`n_members`, y.`n_days`, y.`n_b13_blank`, y.`n_b13_zero`, y.`n_b13_pos`, y.`n_b14_blank`, y.`n_b14_zero`, y.`n_b14_pos`, y.`n_both_pos`, y.`n_b13pos_b14zero`, y.`b13_sum`, y.`b14_sum`, y.`n_comm`, y.`verdict_nature`) AS rn
  FROM (
    /* 在此贴入总包行 12072~12103 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   6. B_online_base.csv   [总包行 2929~2991 · 输出 7 列 · 接回原序 2 项]
--    原 ORDER BY：table_id, sec_elapsed
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`table_id`, y.`sec_elapsed`, y.`n_orders`, y.`n_player`, y.`n_rounds`, y.`valid_bet`, y.`game_pnl`) AS rn
  FROM (
    /* 在此贴入总包行 2929~2991 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   7. C01_ip_chain.csv   [总包行 1663~1723 · 输出 8 列 · 接回原序 1 项]
--    原 ORDER BY：member_per_chain DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_per_chain` DESC, y.`bet_ip`, y.`n_member`, y.`n_lv3_chain`, y.`n_orders`, y.`stake`, y.`game_pnl`, y.`net_pnl`) AS rn
  FROM (
    /* 在此贴入总包行 1663~1723 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   8. C06_hedge_pairs.csv   [总包行 5814~5886 · 输出 7 列 · 接回原序 2 项]
--    原 ORDER BY：opposite_rate DESC, n_opposite_round DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`opposite_rate` DESC, y.`n_opposite_round` DESC, y.`bet_ip`, y.`m_a`, y.`m_b`, y.`n_same_round`, y.`hedge_coverage`) AS rn
  FROM (
    /* 在此贴入总包行 5814~5886 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──   9. C06d_hedge_pairs_dated.csv   [总包行 8067~8133 · 输出 9 列 · 接回原序 2 项]
--    原 ORDER BY：opposite_rate DESC, n_opposite_round DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`opposite_rate` DESC, y.`n_opposite_round` DESC, y.`bet_ip`, y.`m_a`, y.`m_b`, y.`n_same_round`, y.`first_opposite_dt`, y.`last_opposite_dt`, y.`n_opposite_days`) AS rn
  FROM (
    /* 在此贴入总包行 8067~8133 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  10. C08_subnet_all.csv   [总包行 1759~1820 · 输出 8 列 · 接回原序 1 项]
--    原 ORDER BY：n_member DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_member` DESC, y.`subnet_24`, y.`n_ip`, y.`n_lv3_chain`, y.`n_orders`, y.`stake`, y.`game_pnl`, y.`valid_bet`) AS rn
  FROM (
    /* 在此贴入总包行 1759~1820 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  11. C08_subnet_sparse.csv   [总包行 1829~1890 · 输出 8 列 · 接回原序 1 项]
--    原 ORDER BY：n_member DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_member` DESC, y.`subnet_24`, y.`n_ip`, y.`n_lv3_chain`, y.`member_per_ip`, y.`n_orders`, y.`valid_bet`, y.`game_pnl`) AS rn
  FROM (
    /* 在此贴入总包行 1829~1890 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  12. D03S_daily_roi_diff.csv   [总包行 1991~2062 · 输出 7 列 · 接回原序 1 项]
--    原 ORDER BY：bet_date
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`bet_date`, y.`n_rounds`, y.`vb_tail`, y.`vb_norm`, y.`roi_tail`, y.`roi_norm`, y.`roi_diff`) AS rn
  FROM (
    /* 在此贴入总包行 1991~2062 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  13. DICT_01a_bet41_tri.csv   [总包行 11764~11798 · 输出 14 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope`, y.`n_rows`, y.`sum_stake`, y.`sum_validbet`, y.`sum_bet41`, y.`sum_bet16`, y.`r41_vb`, y.`r16_vb`, y.`r_vb_stake`, y.`avg_bet15_pct`, y.`n_41_eq_vb`, y.`n_41_eq_16`, y.`pct_41_eq_vb`, y.`verdict_bet41`) AS rn
  FROM (
    /* 在此贴入总包行 11764~11798 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  14. DICT_01b_roundkey_card.csv   [总包行 11812~11835 · 输出 14 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope`, y.`n_rows`, y.`nd_bet03`, y.`nd_bet04`, y.`nd_bet39`, y.`nd_bet40`, y.`min_bet04`, y.`max_bet04`, y.`min_bet39`, y.`max_bet39`, y.`nd_round_key`, y.`nd_shoe_table`, y.`avg_bets_per_round`, y.`verdict_key`) AS rn
  FROM (
    /* 在此贴入总包行 11812~11835 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  15. DICT_01c_dimension.csv   [总包行 11850~11878 · 输出 12 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope`, y.`n_rows`, y.`avg_validbet`, y.`max_bet23`, y.`avg_bet23`, y.`max_bet27`, y.`max_bet28`, y.`avg_bet28`, y.`max_bet32`, y.`max_bet15`, y.`avg_sum_comm`, y.`verdict_dimension`) AS rn
  FROM (
    /* 在此贴入总包行 11850~11878 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  16. DICT_01d_bet_latency.csv   [总包行 11893~11926 · 输出 14 列 · 接回原序 2 项]
--    原 ORDER BY：n_rows DESC, table_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rows` DESC, y.`table_id`, y.`n_members`, y.`n_b06_null`, y.`n_b08_null`, y.`n_negative`, y.`lat_min`, y.`lat_avg`, y.`lat_max`, y.`lat_p01`, y.`lat_p50`, y.`lat_p99`, y.`lat_sd`, y.`verdict_latency`) AS rn
  FROM (
    /* 在此贴入总包行 11893~11926 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  17. DX04_bet09_profile.csv   [总包行 5971~6005 · 输出 9 列 · 接回原序 1 项]
--    原 ORDER BY：n_orders DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders` DESC, y.`bet_side`, y.`n_member`, y.`stake_total`, y.`player_pnl`, y.`house_hold_pct`, y.`win_rate_base`, y.`avg_stake`, y.`stake_cv`) AS rn
  FROM (
    /* 在此贴入总包行 5971~6005 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  18. DX05_product_panorama.csv   [总包行 6020~6073 · 输出 14 列 · 接回原序 1 项]
--    原 ORDER BY：n_orders DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders` DESC, y.`product_code`, y.`scope`, y.`n_member`, y.`n_dealer`, y.`stake_total`, y.`validbet_total`, y.`player_pnl`, y.`ggr`, y.`house_hold_pct`, y.`rebate_total`, y.`rebate_rate`, y.`order_share`, y.`stake_share`) AS rn
  FROM (
    /* 在此贴入总包行 6020~6073 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  19. E02_segment_econ.csv   [总包行 5707~5797 · 输出 9 列 · 接回原序 1 项]
--    原 ORDER BY：validbet DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`validbet` DESC, y.`segment`, y.`n_member`, y.`ggr`, y.`rebate`, y.`commission`, y.`comm_scale`, y.`reb_scale`, y.`tenure_months`) AS rn
  FROM (
    /* 在此贴入总包行 5707~5797 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  20. EV01_disposal_events.csv   [总包行 7112~7153 · 输出 13 列 · 接回原序 0 项]
--    原 ORDER BY：optime
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`event_id`, y.`event_time`, y.`event_date`, y.`fn`, y.`operator`, y.`operator_ip`, y.`event_type`, y.`member_login`, y.`table_ref`, y.`round_ref`, y.`whitelist_ip`, y.`is_cancel`, y.`content_len`) AS rn
  FROM (
    /* 在此贴入总包行 7112~7153 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  21. EV02_member_disposal.csv   [总包行 7289~7322 · 输出 12 列 · 接回原序 0 项]
--    原 ORDER BY：lmc09
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`event_id`, y.`event_date`, y.`event_time`, y.`type_code`, y.`action`, y.`operator`, y.`event_type`, y.`val_before`, y.`val_after`, y.`summary`, y.`is_batch`, y.`stmt_len`) AS rn
  FROM (
    /* 在此贴入总包行 7289~7322 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  22. I_ip_agg.csv   [总包行 2695~2768 · 输出 14 列 · 接回原序 1 项]
--    原 ORDER BY：n_member_eff DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_member_eff` DESC, y.`window_id`, y.`bet_ip`, y.`n_member_raw`, y.`n_prof_A`, y.`n_prof_B`, y.`n_prof_C`, y.`n_orders`, y.`n_rounds`, y.`stake`, y.`net_pnl`, y.`game_pnl`, y.`share_p50`, y.`share_p90`) AS rn
  FROM (
    /* 在此贴入总包行 2695~2768 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  23. I_ip_player.csv   [总包行 1589~1654 · 输出 14 列 · 接回原序 1 项]
--    原 ORDER BY：n_orders_ip DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
    /* 在此贴入总包行 1589~1654 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  24. K01_risk_feature_matrix.csv   [总包行 5499~5591 · 输出 15 列 · 接回原序 1 项]
--    原 ORDER BY：f.validbet DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`validbet` DESC, y.`member_id`, y.`is_seed`, y.`n_rounds`, y.`n_days`, y.`n_tables`, y.`n_ip`, y.`n_dealer`, y.`side_entropy`, y.`stake_cv`, y.`stake_p90_p50`, y.`hedge_rate`, y.`rebate_dep`, y.`night_share`, y.`roi_game`) AS rn
  FROM (
    /* 在此贴入总包行 5499~5591 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  25. K01b_seed_goldip.csv   [总包行 5637~5643 · 输出 2 列 · 接回原序 1 项]
--    原 ORDER BY：member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`seed_src`) AS rn
  FROM (
    /* 在此贴入总包行 5637~5643 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  26. K01b_seed_manual.csv   [总包行 5618~5625 · 输出 2 列 · 接回原序 1 项]
--    原 ORDER BY：member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`seed_src`) AS rn
  FROM (
    /* 在此贴入总包行 5618~5625 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  27. K01c_seed_dated.csv   [总包行 8330~8337 · 输出 6 列 · 接回原序 1 项]
--    原 ORDER BY：addtime
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`addtime`, y.`seed_id`, y.`seed_ip`, y.`creator`, y.`add_date`, y.`remarks`) AS rn
  FROM (
    /* 在此贴入总包行 8330~8337 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  28. L_label_dist.csv   [总包行 1472~1476 · 输出 6 列 · 接回原序 1 项]
--    原 ORDER BY：n_rows DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rows` DESC, y.`risk`, y.`orders`, y.`n_member`, y.`first_dt`, y.`last_dt`) AS rn
  FROM (
    /* 在此贴入总包行 1472~1476 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  29. P01A_crosstab.csv   [总包行 9199~9219 · 输出 13 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rows`, y.`bet16_null`, y.`bet16_zero`, y.`bet16_nonzero`, y.`bet41_null`, y.`bet41_zero`, y.`bet41_nonzero`, y.`equal_n`, y.`unequal_n`, y.`both_zero_n`, y.`b16zero_b41pos_n`, y.`both_pos_n`, y.`b16pos_b41zero_n`) AS rn
  FROM (
    /* 在此贴入总包行 9199~9219 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  30. P01B_diff_ratio.csv   [总包行 9223~9240 · 输出 11 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n`, y.`diff_min`, y.`diff_p50`, y.`diff_p90`, y.`diff_p99`, y.`diff_max`, y.`ratio_min`, y.`ratio_p01`, y.`ratio_p50`, y.`ratio_p99`, y.`ratio_max`) AS rn
  FROM (
    /* 在此贴入总包行 9223~9240 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  31. P01C_split_by_dim.csv   [总包行 9246~9269 · 输出 14 列 · 接回原序 4 项]
--    原 ORDER BY：ym, bet09, commission, bet10
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`ym`, y.`bet09`, y.`commission`, y.`bet10`, y.`n`, y.`equal_n`, y.`unequal_n`, y.`b16_nonzero_n`, y.`b41_nonzero_n`, y.`avg_b16`, y.`avg_b41`, y.`avg_diff`, y.`p50_b16`, y.`p50_b41`) AS rn
  FROM (
    /* 在此贴入总包行 9246~9269 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  32. P01D_vs_validbet.csv   [总包行 9274~9290 · 输出 9 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n`, y.`comparable_n`, y.`plausible_n`, y.`r41_p01`, y.`r41_p50`, y.`r41_p90`, y.`r41_p99`, y.`r16_p50`, y.`r16_p99`) AS rn
  FROM (
    /* 在此贴入总包行 9274~9290 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  33. P01E_identity_test.csv   [总包行 9295~9330 · 输出 8 列 · 接回原序 1 项]   [含 UNION]
--    原 ORDER BY：hypothesis
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`hypothesis`, y.`n`, y.`exact_match_n`, y.`exact_match_rate`, y.`abs_err_p50`, y.`abs_err_p95`, y.`abs_err_p99`, y.`abs_err_max`) AS rn
  FROM (
    /* 在此贴入总包行 9295~9330 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  34. P02A_lmc_samples.csv   [总包行 9351~9363 · 输出 9 列 · 接回原序 0 项]   [🚩第 [2] 列无别名 → 非全序，建议一次导全 · 含 UNION]
--    原 ORDER BY：类别, 取样端, 異動時間
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`lmc04`, y.`lmc08`, y.`lmc02`, y.`lmc03`, y.`lmc06`, y.`lmc07`, y.`lmc10`, y.`lmc05`) AS rn
  FROM (
    /* 在此贴入总包行 9351~9363 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  35. P02B_changestatus_patterns.csv   [总包行 9369~9378 · 输出 6 列 · 接回原序 1 项]
--    原 ORDER BY：n DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n` DESC, y.`内容前40字`, y.`涉实体数`, y.`最早`, y.`最晚`, y.`其中层级7数`) AS rn
  FROM (
    /* 在此贴入总包行 9369~9378 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  36. P02C_key_check.csv   [总包行 9385~9401 · 输出 8 列 · 接回原序 0 项]
--    原 ORDER BY：l.lmc03
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`层级`, y.`日志行数`, y.`去重实体数`, y.`实体ID为0之脏行`, y.`命中注单会员数`, y.`命中去重实体数`, y.`最早`, y.`最晚`) AS rn
  FROM (
    /* 在此贴入总包行 9385~9401 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  37. P02D_events_in_window.csv   [总包行 9406~9414 · 输出 4 列 · 接回原序 2 项]
--    原 ORDER BY：类别, 层级
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`类别`, y.`层级`, y.`窗口内行数`, y.`涉实体数`) AS rn
  FROM (
    /* 在此贴入总包行 9406~9414 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  38. P0C02_标签口径.csv   [总包行 7728~7761 · 输出 6 列 · 接回原序 0 项]   [🚩第 [1, 2, 3, 4, 5, 6] 列无别名 → 非全序，建议一次导全 · 含 UNION]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY ) AS rn
  FROM (
    /* 在此贴入总包行 7728~7761 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  39. P0C03_标记次数分布.csv   [总包行 7767~7781 · 输出 3 列 · 接回原序 1 项]
--    原 ORDER BY：标记次数
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`标记次数`, y.`会员数`, y.`累计会员数`) AS rn
  FROM (
    /* 在此贴入总包行 7767~7781 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  40. P0C04_同日泄漏检验.csv   [总包行 7793~7828 · 输出 7 列 · 接回原序 1 项]
--    原 ORDER BY：标记日_洗码量 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`标记日_洗码量` DESC, y.`mem`, y.`mark_day`, y.`标记日_注单数`, y.`前30日均_注单数`, y.`前30日均_洗码量`, y.`前30日活跃日数`) AS rn
  FROM (
    /* 在此贴入总包行 7793~7828 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  41. P0C05_标记时点定位.csv   [总包行 7833~7864 · 输出 8 列 · 接回原序 1 项]
--    原 ORDER BY：标记距首投_日
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`标记距首投_日`, y.`mem`, y.`mark_day`, y.`首投日`, y.`末投日`, y.`活跃日数`, y.`末投距标记_日`, y.`时点性质`) AS rn
  FROM (
    /* 在此贴入总包行 7833~7864 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  42. P0C06_LabelB骨架.csv   [总包行 7871~7904 · 输出 8 列 · 接回原序 2 项]
--    原 ORDER BY：a.mem, a.anchor_day
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`mem`, y.`anchor_day`, y.`特征窗起`, y.`特征窗止`, y.`结果窗起`, y.`结果窗止`, y.`label_b_未来14日被标记`, y.`label_a_当日被标记`) AS rn
  FROM (
    /* 在此贴入总包行 7871~7904 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  43. P0C09_安慰剂检验.csv   [总包行 7995~8032 · 输出 7 列 · 接回原序 1 项]
--    原 ORDER BY：a.mem, a.d
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`mem`, y.`参照日`, y.`参照日_注单数`, y.`参照日_洗码量`, y.`前30日均_注单数`, y.`前30日均_洗码量`, y.`前30日活跃日数`) AS rn
  FROM (
    /* 在此贴入总包行 7995~8032 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  44. P11_阿泽尾段投注总帐.csv   [总包行 9519~9655 · 输出 21 列 · 接回原序 1 项]   [含 UNION]
--    原 ORDER BY：b.scope_def
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope_def`, y.`n_orders`, y.`n_orders_pct`, y.`n_members`, y.`n_members_pct`, y.`n_lv1`, y.`n_lv2`, y.`n_lv3`, y.`n_lv4`, y.`n_lv5`, y.`stake_sum`, y.`stake_pct`, y.`validbet_sum`, y.`validbet_pct`, y.`ggr_sum`, y.`ggr_pct`, y.`rebate16_sum`, y.`rebate16_pct`, y.`rebate41_sum`, y.`ngr_by16`, y.`ngr_by16_pct`) AS rn
  FROM (
    /* 在此贴入总包行 9519~9655 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  45. P11_阿泽尾段投注模型会员名单.csv   [总包行 9443~9500 · 输出 9 列 · 接回原序 2 项]
--    原 ORDER BY：roi DESC, profit DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`roi` DESC, y.`profit` DESC, y.`player_id`, y.`total_orders`, y.`late_orders`, y.`late_ratio`, y.`win_orders`, y.`win_rate`, y.`valid_bet`) AS rn
  FROM (
    /* 在此贴入总包行 9443~9500 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  46. P11_雷欧尾段投注总帐.csv   [总包行 9667~9769 · 输出 21 列 · 接回原序 1 项]   [含 UNION]
--    原 ORDER BY：b.scope_def
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope_def`, y.`n_orders`, y.`n_orders_pct`, y.`n_members`, y.`n_members_pct`, y.`n_lv1`, y.`n_lv2`, y.`n_lv3`, y.`n_lv4`, y.`n_lv5`, y.`stake_sum`, y.`stake_pct`, y.`validbet_sum`, y.`validbet_pct`, y.`ggr_sum`, y.`ggr_pct`, y.`rebate16_sum`, y.`rebate16_pct`, y.`rebate41_sum`, y.`ngr_by16`, y.`ngr_by16_pct`) AS rn
  FROM (
    /* 在此贴入总包行 9667~9769 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  47. P12a_platform_daily.csv   [总包行 9808~9873 · 输出 9 列 · 接回原序 1 项]
--    原 ORDER BY：dt
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`dt`, y.`n_orders`, y.`n_members`, y.`stake_sum`, y.`validbet_sum`, y.`ggr_sum`, y.`late_stake_share`, y.`stake_ramp_day`, y.`hold_pct`) AS rn
  FROM (
    /* 在此贴入总包行 9808~9873 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  48. P12b_member_events.csv   [总包行 9885~9941 · 输出 8 列 · 接回原序 1 项]
--    原 ORDER BY：m.uid
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`uid`, y.`first_dt`, y.`last_dt`, y.`active_days`, y.`span_days`, y.`n_orders`, y.`mark_dt`, y.`censor_flag`) AS rn
  FROM (
    /* 在此贴入总包行 9885~9941 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  49. P12c_member_daily_pnl.csv   [总包行 9954~10005 · 输出 6 列 · 接回原序 2 项]
--    原 ORDER BY：g.uid, g.dt
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`uid`, y.`dt`, y.`day_orders`, y.`day_stake`, y.`day_vb`, y.`day_pnl`) AS rn
  FROM (
    /* 在此贴入总包行 9954~10005 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  50. P13_personal_entry.csv   [总包行 10145~10204 · 输出 7 列 · 接回原序 1 项]
--    原 ORDER BY：uid
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`uid`, y.`n_shoes`, y.`n_orders`, y.`entry_pos_p50`, y.`exit_pos_p50`, y.`bet_density_p50`, y.`entry_round_avg`) AS rn
  FROM (
    /* 在此贴入总包行 10145~10204 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  51. PH0_8r1_rg_case.csv   [总包行 13308~13322 · 输出 8 列 · 接回原序 0 项]   [🚩语句内已含 LIMIT]
--    原 ORDER BY：dt, lmc08, lmc02
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`dt_day`, y.`category`, y.`target_id`, y.`operator_id`, y.`change_time`, y.`operator_ip`, y.`content_full`, y.`sql_full`) AS rn
  FROM (
    /* 在此贴入总包行 13308~13322 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  52. PH0_8r2_rg_crosstable.csv   [总包行 13334~13390 · 输出 5 列 · 接回原序 0 项]   [🚩第 [1, 2, 3, 4, 5] 列无别名 → 非全序，建议一次导全 · 含 UNION]
--    原 ORDER BY：n_rg_true DESC, src
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY ) AS rn
  FROM (
    /* 在此贴入总包行 13334~13390 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  53. PI01_treatment_delta_member.csv   [总包行 13468~13599 · 输出 21 列 · 接回原序 2 项]
--    原 ORDER BY：d_revenue, member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`d_revenue`, y.`member_id`, y.`treat_time`, y.`treat_field`, y.`n_treat_events`, y.`n_pre`, y.`n_post`, y.`d_pre`, y.`d_post`, y.`stake_pre`, y.`stake_post`, y.`d_stake`, y.`d_validbet`, y.`hold_pre_pct`, y.`hold_post_pct`, y.`d_hold_pct`, y.`roi_pre`, y.`roi_post`, y.`d_roi`, y.`d_bets_per_day`, y.`verdict_exposure`) AS rn
  FROM (
    /* 在此贴入总包行 13468~13599 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  54. PI02_treatment_delta_platform.csv   [总包行 13612~13713 · 输出 13 列 · 接回原序 2 项]
--    原 ORDER BY：cohort, phase
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`cohort`, y.`phase`, y.`n_members`, y.`n_bets`, y.`n_dates`, y.`sum_stake`, y.`sum_validbet`, y.`sum_revenue`, y.`hold_pct`, y.`roi`, y.`revenue_per_member`, y.`share_of_stake_pct`, y.`share_of_revenue_pct`) AS rn
  FROM (
    /* 在此贴入总包行 13612~13713 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  55. PI03_reinvest_loop.csv   [总包行 13728~13791 · 输出 13 列 · 接回原序 2 项]
--    原 ORDER BY：n_pairs DESC, prev_outcome
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_pairs` DESC, y.`prev_outcome`, y.`n_members`, y.`n_negative_gap`, y.`gap_p10`, y.`gap_p50`, y.`gap_p90`, y.`gap_avg`, y.`ratio_p50`, y.`ratio_p90`, y.`ratio_avg`, y.`n_double_up`, y.`pct_double_up`) AS rn
  FROM (
    /* 在此贴入总包行 13728~13791 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  56. PI04_member_5d_profile.csv   [总包行 13808~13877 · 输出 20 列 · 接回原序 2 项]
--    原 ORDER BY：sum_revenue DESC, member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`sum_revenue` DESC, y.`member_id`, y.`n_bets`, y.`n_active_days`, y.`bets_per_day`, y.`n_bet_types`, y.`sum_stake`, y.`sum_validbet`, y.`hold_pct`, y.`roi`, y.`n_tables`, y.`n_comm_mode`, y.`first_date`, y.`last_date`, y.`span_days`, y.`night_share_pct`, y.`avg_latency_sec`, y.`share_stake_pct`, y.`share_revenue_pct`, y.`verdict_observability`) AS rn
  FROM (
    /* 在此贴入总包行 13808~13877 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  57. P_player_month.csv   [总包行 2865~2921 · 输出 9 列 · 接回原序 2 项]
--    原 ORDER BY：member_id, ym
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`ym`, y.`n_rounds`, y.`n_days`, y.`valid_bet`, y.`game_pnl`, y.`rebate`, y.`net_pnl`, y.`roi`) AS rn
  FROM (
    /* 在此贴入总包行 2865~2921 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  58. QSB_01a_category_census.csv   [总包行 11153~11197 · 输出 22 列 · 接回原序 2 项]
--    原 ORDER BY：n_rows DESC, category_value
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rows` DESC, y.`category_value`, y.`pct_of_total`, y.`n_members`, y.`n_dates`, y.`min_dt`, y.`max_dt`, y.`n_bet09`, y.`n_b14_null`, y.`n_b14_zero`, y.`n_b14_pos`, y.`n_pnl_zero`, y.`n_pnl_house_win`, y.`n_pnl_player_win`, y.`n_vb_zero`, y.`n_b41_zero`, y.`stake_sum`, y.`payout_sum`, y.`validbet_sum`, y.`n_rebet_flag`, y.`n_commission`, y.`shape_hint`) AS rn
  FROM (
    /* 在此贴入总包行 11153~11197 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  59. QSB_01c_cat1_contamination.csv   [总包行 11250~11283 · 输出 10 列 · 接回原序 3 项]
--    原 ORDER BY：n_b14_null DESC, n_pnl_zero_stake_pos DESC, n_rows DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_b14_null` DESC, y.`n_pnl_zero_stake_pos` DESC, y.`n_rows` DESC, y.`bet09_value`, y.`n_b13_null`, y.`n_b13_zero`, y.`n_exact_refund`, y.`pct_pnl_zero`, y.`stake_sum`, y.`verdict_contamination`) AS rn
  FROM (
    /* 在此贴入总包行 11250~11283 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  60. QSB_02a_lowcard_fields.csv   [总包行 11295~11316 · 输出 18 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope`, y.`n_rows`, y.`nd_bet04`, y.`nd_bet06`, y.`nd_bet07`, y.`nd_bet10`, y.`nd_bet23`, y.`nd_bet24`, y.`nd_bet25`, y.`nd_bet26`, y.`nd_bet28`, y.`nd_bet29`, y.`nd_bet30`, y.`nd_bet31`, y.`nd_bet40`, y.`nd_bet38`, y.`nd_category`, y.`nd_commission`) AS rn
  FROM (
    /* 在此贴入总包行 11295~11316 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  61. QSB_02b2_lowcard_five_gates.csv   [总包行 11498~11747 · 输出 19 列 · 接回原序 3 项]   [含 UNION]
--    原 ORDER BY：field_name, n_rows DESC, field_value
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`field_name`, y.`n_rows` DESC, y.`field_value`, y.`pct_of_field`, y.`n_null`, y.`n_bet09`, y.`n_dates`, y.`min_dt`, y.`max_dt`, y.`n_pnl_zero`, y.`n_pnl_pos`, y.`n_pnl_neg`, y.`pct_pnl_zero`, y.`pct_pnl_pos`, y.`pct_pnl_neg`, y.`n_exact_refund`, y.`n_payout_zero`, y.`payout_over_stake`, y.`verdict_state`) AS rn
  FROM (
    /* 在此贴入总包行 11498~11747 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  62. QSB_02b_state_cross.csv   [总包行 11331~11424 · 输出 9 列 · 接回原序 3 项]   [含 UNION]
--    原 ORDER BY：field_name, n_rows DESC, field_value
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`field_name`, y.`n_rows` DESC, y.`field_value`, y.`n_pnl_zero`, y.`n_pnl_pos`, y.`n_pnl_neg`, y.`n_payout_zero`, y.`n_bet09`, y.`verdict_align`) AS rn
  FROM (
    /* 在此贴入总包行 11331~11424 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  63. QSB_02c_push_by_family.csv   [总包行 11437~11489 · 输出 10 列 · 接回原序 2 项]
--    原 ORDER BY：n_rows DESC, bet09_family
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rows` DESC, y.`bet09_family`, y.`n_bet09_in_family`, y.`n_pnl_zero`, y.`pct_pnl_zero`, y.`n_exact_refund`, y.`n_payout_zero_stake_pos`, y.`pct_player_win`, y.`mu0_pct`, y.`verdict_family`) AS rn
  FROM (
    /* 在此贴入总包行 11437~11489 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  64. R01_late_shoe.csv   [总包行 3463~3539 · 输出 15 列 · 接回原序 2 项]
--    原 ORDER BY：late_share DESC, n_orders_late DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`late_share` DESC, y.`n_orders_late` DESC, y.`uid`, y.`n_orders_all`, y.`late_def`, y.`shoe_pos_p50`, y.`stake_late_avg`, y.`stake_early_avg`, y.`stake_ramp`, y.`roi_late`, y.`roi_early`, y.`stake_late`, y.`game_pnl_late`, y.`stake_all`, y.`game_pnl_all`) AS rn
  FROM (
    /* 在此贴入总包行 3463~3539 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  65. R01_late_shoe_w2.csv   [总包行 10048~10124 · 输出 15 列 · 接回原序 2 项]
--    原 ORDER BY：late_share DESC, n_orders_late DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`late_share` DESC, y.`n_orders_late` DESC, y.`uid`, y.`n_orders_all`, y.`late_def`, y.`shoe_pos_p50`, y.`stake_late_avg`, y.`stake_early_avg`, y.`stake_ramp`, y.`roi_late`, y.`roi_early`, y.`stake_late`, y.`game_pnl_late`, y.`stake_all`, y.`game_pnl_all`) AS rn
  FROM (
    /* 在此贴入总包行 10048~10124 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  66. R01anm_shoe_anomaly.csv   [总包行 3948~4009 · 输出 11 列 · 接回原序 4 项]
--    原 ORDER BY：s.max_round DESC, s.dt, s.table_id, s.shoe_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`max_round` DESC, y.`dt`, y.`table_id`, y.`shoe_id`, y.`min_round`, y.`rounds_with_bet`, y.`gap`, y.`n_bettors`, y.`n_bets`, y.`anomaly_type`, y.`hi_cut_used`) AS rn
  FROM (
    /* 在此贴入总包行 3948~4009 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  67. R01chk_shoe_len_by_table.csv   [总包行 3725~3855 · 输出 28 列 · 接回原序 2 项]
--    原 ORDER BY：z.avg_max_round DESC, z.table_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`avg_max_round` DESC, y.`table_id`, y.`table_flag`, y.`n_shoes`, y.`n_shoes_old`, y.`n_shoes_delta`, y.`avg_max_round_old`, y.`avg_maxround_inflation`, y.`sd_max_round`, y.`min_max_round`, y.`ceiling_observed`, y.`ceiling_old`, y.`p50_max_round`, y.`p90_max_round`, y.`p99_max_round`, y.`collision_flag`, y.`n_stub_shoes`, y.`avg_gap`, y.`avg_n_bettors`, y.`avg_bets_per_round`, y.`round_at_pos080`, y.`corr_len_density`, y.`corr_density_lo95`, y.`corr_density_hi95`, y.`corr_density_verdict`, y.`corr_len_bettors`, y.`corr_bettors_lo95`, y.`corr_bettors_hi95`) AS rn
  FROM (
    /* 在此贴入总包行 3725~3855 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  68. R01inv_shoe_len_census.csv   [总包行 3865~3940 · 输出 19 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_tables`, y.`n_shoes`, y.`mean_len`, y.`sd_len`, y.`p0`, y.`p01`, y.`p25`, y.`p50`, y.`p75`, y.`p90`, y.`p99`, y.`p100`, y.`n_len_ge_70`, y.`n_len_le_5`, y.`pct_with_gap`, y.`avg_gap`, y.`corr_cross_table`, y.`round_at_080_shortest`, y.`round_at_080_longest`) AS rn
  FROM (
    /* 在此贴入总包行 3865~3940 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  69. R02_same_table.csv   [总包行 4293~4365 · 输出 12 列 · 接回原序 2 项]
--    原 ORDER BY：lift DESC, same_rate DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`lift` DESC, y.`same_rate` DESC, y.`uid1`, y.`uid2`, y.`n_same_orders`, y.`rounds_1`, y.`rounds_2`, y.`jaccard`, y.`exp_same`, y.`n_tables`, y.`first_day`, y.`last_day`) AS rn
  FROM (
    /* 在此贴入总包行 4293~4365 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  70. R03_player_dealer.csv   [总包行 4502~4633 · 输出 33 列 · 接回原序 1 项]
--    原 ORDER BY：pdw.member_id, pdw.dealer_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`dealer_id`, y.`uid`, y.`is_sentinel_dealer`, y.`stake_amount`, y.`profit_amount`, y.`net_pnl`, y.`win_rate`, y.`n_related_orders`, y.`n_rounds_eff`, y.`p_base_mix_w`, y.`p_base_mix_unw`, y.`total_bet_amount`, y.`n_bets`, y.`z_score_w`, y.`z_score_unw`, y.`z_score`, y.`delta_p`, y.`delta_z`, y.`net_pnl_all`, y.`game_pnl_all`, y.`stake_all`, y.`win_rate_all`, y.`win_rate_other`, y.`eligibility_status`, y.`eligibility_min_n`, y.`eligibility_rule`, y.`filter_stage`, y.`filter_rule_version`, y.`comparison_id`, y.`cmp_time_window`, y.`cmp_population`, y.`cmp_label`, y.`z_score_alias_status`) AS rn
  FROM (
    /* 在此贴入总包行 4502~4633 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  71. R03b_player_dealer_daily.csv   [总包行 6143~6242 · 输出 24 列 · 接回原序 2 项]
--    原 ORDER BY：p.bet_date, p.member_id, p.dealer_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`bet_date`, y.`dealer_id`, y.`uid`, y.`is_sentinel_dealer`, y.`stake_amount`, y.`profit_amount`, y.`net_pnl`, y.`win_rate`, y.`n_related_orders`, y.`n_rounds_eff`, y.`p_base_mix_w`, y.`p_base_mix_unw`, y.`z_score_w`, y.`z_score_unw`, y.`z_score`, y.`delta_p`, y.`eligibility_status`, y.`comparison_id`, y.`filter_stage`, y.`filter_rule_version`, y.`cmp_time_window`, y.`cmp_population`, y.`cmp_label`, y.`z_score_alias_status`) AS rn
  FROM (
    /* 在此贴入总包行 6143~6242 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  72. R03chk_settlement_form.csv   [总包行 4684~4723 · 输出 6 列 · 接回原序 1 项]
--    原 ORDER BY：n_rounds DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rounds` DESC, y.`bet_side`, y.`n_push`, y.`push_rate`, y.`p_base_dnb`, y.`p_base_incl`) AS rn
  FROM (
    /* 在此贴入总包行 4684~4723 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  73. R03inv_pair_census.csv   [总包行 4745~4796 · 输出 6 列 · 接回原序 0 项]
--    原 ORDER BY：1, 2
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`eligibility_status`, y.`n_bucket`, y.`n_pairs`, y.`n_members`, y.`n_dealers`, y.`n_rounds_total`) AS rn
  FROM (
    /* 在此贴入总包行 4745~4796 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  74. R_rebate_dist.csv   [总包行 1489~1492 · 输出 3 列 · 接回原序 1 项]
--    原 ORDER BY：n_member DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_member` DESC, y.`rebate_rate`, y.`pct`) AS rn
  FROM (
    /* 在此贴入总包行 1489~1492 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  75. S01_player_score.csv   [总包行 2198~2320 · 输出 11 列 · 接回原序 1 项]
--    原 ORDER BY：流水贡献 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`流水贡献` DESC, y.`member_id`, y.`游戏输赢贡献`, y.`活跃稳定`, y.`退水支出`, y.`n_ip`, y.`n_chain`, y.`人工标记史`, y.`投注产品结构熵`, y.`索提诺稳定性`, y.`生命周期阶段`) AS rn
  FROM (
    /* 在此贴入总包行 2198~2320 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  76. S02_dealer_score.csv   [总包行 2339~2458 · 输出 9 列 · 接回原序 1 项]
--    原 ORDER BY：在桌洗码量 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`在桌洗码量` DESC, y.`dealer_id`, y.`客群广度`, y.`n_rounds`, y.`n_tables`, y.`桌面输赢`, y.`当值时长`, y.`节奏稳定度`, y.`特定玩家复现率`) AS rn
  FROM (
    /* 在此贴入总包行 2339~2458 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  77. S02b_dealer_pace.csv   [总包行 6390~6447 · 输出 3 列 · 接回原序 1 项]
--    原 ORDER BY：局速 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`局速` DESC, y.`dealer_id`, y.`平均每局秒数`) AS rn
  FROM (
    /* 在此贴入总包行 6390~6447 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  78. S03_agent_score.csv   [总包行 2467~2566 · 输出 9 列 · 接回原序 1 项]
--    原 ORDER BY：真实流水 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`真实流水` DESC, y.`lv3`, y.`线下规模`, y.`退水支出`, y.`链下游戏输赢`, y.`退水消耗比`, y.`下线留存`, y.`新增会员质量`, y.`新增会员数`) AS rn
  FROM (
    /* 在此贴入总包行 2467~2566 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  79. S04_analyst_score.csv   [总包行 6277~6302 · 输出 7 列 · 接回原序 1 项]
--    原 ORDER BY：标注产量 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`标注产量` DESC, y.`entity_id`, y.`覆盖IP广度`, y.`判定详尽度`, y.`理由空白数`, y.`首次登记`, y.`最近登记`) AS rn
  FROM (
    /* 在此贴入总包行 6277~6302 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  80. S05_member_month_panel.csv   [总包行 2614~2678 · 输出 10 列 · 接回原序 2 项]
--    原 ORDER BY：b.member_id, bet_date
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`bet_date`, y.`流水贡献`, y.`游戏输赢贡献`, y.`活跃稳定`, y.`退水支出`, y.`n_ip`, y.`n_chain`, y.`round_key`, y.`risk_label`) AS rn
  FROM (
    /* 在此贴入总包行 2614~2678 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  81. S_player_tail.csv   [总包行 2077~2189 · 输出 18 列 · 接回原序 1 项]
--    原 ORDER BY：member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`n_rounds_all`, y.`n_rounds_tail`, y.`tail_share`, y.`tail_win`, y.`tail_lose`, y.`tail_winrate`, y.`norm_winrate`, y.`winrate_diff`, y.`tail_stake`, y.`tail_valid_bet`, y.`tail_game_pnl`, y.`tail_rebate`, y.`tail_net_pnl`, y.`tail_roi`, y.`norm_game_pnl`, y.`norm_roi`, y.`tail_profit_share`) AS rn
  FROM (
    /* 在此贴入总包行 2077~2189 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  82. S_second_dist.csv   [总包行 1914~1982 · 输出 8 列 · 接回原序 1 项]
--    原 ORDER BY：n_orders DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders` DESC, y.`table_id`, y.`p50`, y.`p75`, y.`p90`, y.`p95`, y.`p99`, y.`max_progress`) AS rn
  FROM (
    /* 在此贴入总包行 1914~1982 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  83. T02_daily_roi.csv   [总包行 5146~5190 · 输出 5 列 · 接回原序 2 项]
--    原 ORDER BY：o.member_id, o.bet_date
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`bet_date`, y.`stake`, y.`game_pnl`, y.`n_rounds`) AS rn
  FROM (
    /* 在此贴入总包行 5146~5190 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  84. T03_arbitrage.csv   [总包行 5204~5275 · 输出 10 列 · 接回原序 2 项]
--    原 ORDER BY：hedge_rate DESC, validbet DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`hedge_rate` DESC, y.`validbet` DESC, y.`member_id`, y.`stake`, y.`game_pnl`, y.`net_pnl`, y.`rebate`, y.`stake_cv`, y.`n_rounds`, y.`n_days`) AS rn
  FROM (
    /* 在此贴入总包行 5204~5275 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  85. TL00_table_inventory.csv   [总包行 8168~8215 · 输出 5 列 · 接回原序 3 项]
--    原 ORDER BY：处置类列数 DESC, 定日类列数 DESC, c.TABLE_NAME
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`处置类列数` DESC, y.`定日类列数` DESC, y.`TABLE_NAME`, y.`列数`, y.`时间列数`) AS rn
  FROM (
    /* 在此贴入总包行 8168~8215 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  86. TL02_config_change.csv   [总包行 8238~8269 · 输出 4 列 · 接回原序 1 项]   [含 UNION]
--    原 ORDER BY：发生变更的会员数 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`发生变更的会员数` DESC, y.`变更列`, y.`在册会员数`, y.`变更率`) AS rn
  FROM (
    /* 在此贴入总包行 8238~8269 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  87. TL03_pseudo_treatment.csv   [总包行 8276~8324 · 输出 6 列 · 接回原序 2 项]
--    原 ORDER BY：member_id, change_date
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`change_date`, y.`action_type`, y.`value_before`, y.`value_after`, y.`direction`) AS rn
  FROM (
    /* 在此贴入总包行 8276~8324 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  88. TL03b_pseudo_treatment.csv   [总包行 8417~8466 · 输出 8 列 · 接回原序 3 项]
--    原 ORDER BY：member_id, cate, change_date
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`cate`, y.`change_date`, y.`prev_date`, y.`action_type`, y.`value_before`, y.`value_after`, y.`direction`) AS rn
  FROM (
    /* 在此贴入总包行 8417~8466 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  89. TL04_log_schema.csv   [总包行 8383~8389 · 输出 5 列 · 接回原序 2 项]
--    原 ORDER BY：TABLE_NAME, ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`TABLE_NAME`, y.`ORDINAL_POSITION`, y.`COLUMN_NAME`, y.`DATA_TYPE`, y.`COLUMN_COMMENT`) AS rn
  FROM (
    /* 在此贴入总包行 8383~8389 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  90. TL06_log_mem_change.csv   [总包行 8473~8479 · 输出 2 列 · 接回原序 1 项]
--    原 ORDER BY：dt
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`dt`, y.`行数`) AS rn
  FROM (
    /* 在此贴入总包行 8473~8479 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  91. TL07_mem_change_shape.csv   [总包行 8519~8533 · 输出 10 列 · 接回原序 1 项]
--    原 ORDER BY：条数 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`条数` DESC, y.`类别`, y.`涉及会员数`, y.`操作者数`, y.`最早异动`, y.`最晚异动`, y.`内容平均长度`, y.`内容样例`, y.`SQL平均长度`, y.`SQL样例`) AS rn
  FROM (
    /* 在此贴入总包行 8519~8533 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  92. TL08_treatment_events.csv   [总包行 8541~8572 · 输出 9 列 · 接回原序 2 项]
--    原 ORDER BY：ev.action_time, ev.member_id
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`action_time`, y.`member_id`, y.`action_date`, y.`action_class`, y.`operator_id`, y.`operator_lv`, y.`content`, y.`raw_sql`, y.`is_baccarat_member`) AS rn
  FROM (
    /* 在此贴入总包行 8541~8572 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  93. TL09_member_schema.csv   [总包行 8603~8607 · 输出 4 列 · 接回原序 1 项]
--    原 ORDER BY：ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`ORDINAL_POSITION`, y.`COLUMN_NAME`, y.`DATA_TYPE`, y.`COLUMN_COMMENT`) AS rn
  FROM (
    /* 在此贴入总包行 8603~8607 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  94. TL10_treatment_ledger.csv   [总包行 8615~8675 · 输出 10 列 · 接回原序 3 项]
--    原 ORDER BY：p.action_time, p.member_id, p.field_name
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`action_time`, y.`member_id`, y.`field_name`, y.`action_date`, y.`action_class`, y.`value_before`, y.`value_after`, y.`operator_id`, y.`operator_lv`, y.`is_baccarat_member`) AS rn
  FROM (
    /* 在此贴入总包行 8615~8675 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  95. TL11_treatment_episode.csv   [总包行 8706~8832 · 输出 24 列 · 接回原序 1 项]
--    原 ORDER BY：p.member_id, p.action_time
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`field_name`, y.`business_field`, y.`enforcement_type`, y.`is_baccarat_member`, y.`episode_id`, y.`start_date`, y.`start_time`, y.`value_before`, y.`value_after`, y.`start_operator`, y.`start_operator_lv`, y.`parse_sep`, y.`parse_status`, y.`release_date`, y.`censored`, y.`last_bet_date`, y.`n_bets_in_window`, y.`last_config_time`, y.`days_since_last_bet`, y.`censor_cutoff_days`, y.`censor_reason`, y.`duration_days`, y.`episode_seq`) AS rn
  FROM (
    /* 在此贴入总包行 8706~8832 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  96. TL11c_population_reconcile.csv   [总包行 8969~9055 · 输出 7 列 · 接回原序 0 项]   [🚩第 [1, 2, 3, 4, 5, 6, 7] 列无别名 → 非全序，建议一次导全 · 含 UNION]
--    原 ORDER BY：lvl
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY ) AS rn
  FROM (
    /* 在此贴入总包行 8969~9055 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  97. TL14_limit_treatment.csv   [总包行 5058~5136 · 输出 15 列 · 接回原序 2 项]
--    原 ORDER BY：l.member_id, l.action_time
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`action_time`, y.`action_date`, y.`operator_id`, y.`operator_lv`, y.`grp_before`, y.`grp_after`, y.`max_hi_before`, y.`max_hi_after`, y.`n_grp_before`, y.`n_grp_after`, y.`direction`, y.`has_zero_group`, y.`is_baccarat_member`, y.`filter_rule_version`) AS rn
  FROM (
    /* 在此贴入总包行 5058~5136 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  98. T_table_span.csv   [总包行 1447~1455 · 输出 6 列 · 接回原序 1 项]
--    原 ORDER BY：n_rounds DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_rounds` DESC, y.`table_id`, y.`mean_sec`, y.`p50`, y.`p90`, y.`p99`) AS rn
  FROM (
    /* 在此贴入总包行 1447~1455 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ──  99. VB_00_validbet_contract.csv   [总包行 10675~10697 · 输出 13 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope`, y.`n_rows`, y.`n_vb_null`, y.`n_vb_blank`, y.`n_vb_zero`, y.`n_vb_pos`, y.`n_vb_neg`, y.`null_rate_pct`, y.`n_fallback_also_null`, y.`vb_sum`, y.`b13_sum`, y.`b41_sum`, y.`verdict_contract`) AS rn
  FROM (
    /* 在此贴入总包行 10675~10697 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 100. VB_00b_zero_five_rates.csv   [总包行 10801~10869 · 输出 18 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`scope`, y.`n_base_rows`, y.`n_active_member`, y.`n_zero_rows`, y.`n_zero_member`, y.`zero_record_rate_pct`, y.`zero_amount_rate_pct`, y.`zero_member_rate_pct`, y.`zero_profit_rate_pct`, y.`zero_active_rate_pct`, y.`zero_stake_sum`, y.`zero_ggr_sum`, y.`all_stake_sum`, y.`all_ggr_sum`, y.`zero_mu0_pct`, y.`base_mu0_pct`, y.`n_zero_both`, y.`verdict_zero`) AS rn
  FROM (
    /* 在此贴入总包行 10801~10869 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 101. VB_41_identity_global.csv   [总包行 10716~10750 · 输出 17 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`test`, y.`n_rows`, y.`n_both_null`, y.`n_null_asym`, y.`n_exact_equal`, y.`n_value_diff`, y.`pct_exact_equal`, y.`max_abs_diff`, y.`sum_abs_diff`, y.`d_min`, y.`d_p01`, y.`d_p05`, y.`d_p50`, y.`d_p95`, y.`d_p99`, y.`d_max`, y.`verdict_identity`) AS rn
  FROM (
    /* 在此贴入总包行 10716~10750 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 102. VB_41b_identity_strata.csv   [总包行 10761~10792 · 输出 10 列 · 接回原序 3 项]
--    原 ORDER BY：n_null_asym DESC, n_value_diff DESC, n_rows DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_null_asym` DESC, y.`n_value_diff` DESC, y.`n_rows` DESC, y.`bet09_value`, y.`commission_value`, y.`n_both_null`, y.`max_abs_diff`, y.`b41_sum`, y.`vb_sum`, y.`verdict_stratum`) AS rn
  FROM (
    /* 在此贴入总包行 10761~10792 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 103. VB_41b_identity_strata_v18b.csv   [总包行 10876~10930 · 输出 18 列 · 接回原序 5 项]
--    原 ORDER BY：n_null_asym DESC, n_value_diff DESC, n_rows DESC, bet09_value, commission_value
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_null_asym` DESC, y.`n_value_diff` DESC, y.`n_rows` DESC, y.`bet09_value`, y.`commission_value`, y.`n_both_null`, y.`pct_value_diff`, y.`max_abs_diff`, y.`d_min`, y.`d_max`, y.`sum_abs_diff`, y.`n_both_zero`, y.`n_b41_zero_vb_pos`, y.`n_b41_pos_vb_zero`, y.`d_sign_uniform`, y.`b41_sum`, y.`vb_sum`, y.`verdict_stratum`) AS rn
  FROM (
    /* 在此贴入总包行 10876~10930 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 104. VB_41c1_964_detail.csv   [总包行 10939~10970 · 输出 22 列 · 接回原序 5 项]
--    原 ORDER BY：grp, dt, bet_time, member_id, bet01
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`grp`, y.`dt`, y.`bet_time`, y.`member_id`, y.`bet01`, y.`table_id`, y.`shoe_id`, y.`bet09`, y.`commission`, y.`category`, y.`rebet_flag`, y.`agent_lv1`, y.`stake_raw`, y.`fx_rate`, y.`payout_raw`, y.`rebate_raw`, y.`net_raw`, y.`bet41`, y.`validbet`, y.`diff_vb_minus_b41`, y.`updatetime`, y.`sync_time`) AS rn
  FROM (
    /* 在此贴入总包行 10939~10970 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 105. VB_41c2_concentration.csv   [总包行 10982~11045 · 输出 20 列 · 接回原序 1 项]
--    原 ORDER BY：t.grp
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`grp`, y.`n_rows`, y.`n_members`, y.`top1_member_share_pct`, y.`top1_member_n`, y.`max_member_diff_sum`, y.`n_dates`, y.`min_date`, y.`max_date`, y.`top_date_n`, y.`top_date_share_pct`, y.`n_tables`, y.`top_table_share_pct`, y.`n_bet09`, y.`n_commission`, y.`sum_stake`, y.`sum_validbet`, y.`min_stake`, y.`max_stake`, y.`verdict_concentration`) AS rn
  FROM (
    /* 在此贴入总包行 10982~11045 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 106. VB_41c2_concentration_v2.csv   [总包行 11052~11140 · 输出 20 列 · 接回原序 1 项]
--    原 ORDER BY：o.grp
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`grp`, y.`n_rows`, y.`n_members`, y.`n_dates`, y.`n_tables`, y.`n_bet09`, y.`top1_member_share_pct`, y.`top_date_share_pct`, y.`top_table_share_pct`, y.`top_bet09_share_pct`, y.`top_stake_share_pct`, y.`st_member`, y.`st_date`, y.`st_table`, y.`st_bet09`, y.`st_stake`, y.`n_dims_high`, y.`n_dims_near_or_high`, y.`verdict_concentration`, y.`sum_stake`) AS rn
  FROM (
    /* 在此贴入总包行 11052~11140 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 107. V_ipmatch.csv   [总包行 3017~3029 · 输出 5 列 · 接回原序 1 项]
--    原 ORDER BY：b.n_member_log DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_member_log` DESC, y.`ip`, y.`country`, y.`city`, y.`in_bet_ip`) AS rn
  FROM (
    /* 在此贴入总包行 3017~3029 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 108. V_recon.csv   [总包行 1506~1576 · 输出 12 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_matched_round`, y.`mae_turnover`, y.`mae_rebate`, y.`mae_net`, y.`scale_turnover`, y.`scale_rebate`, y.`scale_net`, y.`mase_turnover`, y.`mase_rebate`, y.`mase_net`, y.`pct_exact_turnover`, y.`pct_exact_net`) AS rn
  FROM (
    /* 在此贴入总包行 1506~1576 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 109. V_table_counts.csv   [总包行 6092~6101 · 输出 2 列 · 接回原序 0 项]   [🚩第 [1, 2] 列无别名 → 非全序，建议一次导全 · 含 UNION]
--    原 ORDER BY：行数 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY ) AS rn
  FROM (
    /* 在此贴入总包行 6092~6101 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 110. X_combo.csv   [总包行 2776~2857 · 输出 6 列 · 接回原序 0 项]
--    原 ORDER BY：1 DESC,2 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`flag_ip`, y.`flag_tail_p90`, y.`n_member`, y.`valid_bet`, y.`game_pnl`, y.`roi`) AS rn
  FROM (
    /* 在此贴入总包行 2776~2857 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 111. Z01_table_inventory.csv   [总包行 561~579 · 输出 5 列 · 接回原序 1 项]
--    原 ORDER BY：疑似性质, TABLE_NAME
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`疑似性质`, y.`表名`, y.`表类型`, y.`估计行数`, y.`表注释`) AS rn
  FROM (
    /* 在此贴入总包行 561~579 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 112. Z02_excluded_tables.csv   [总包行 589~608 · 输出 4 列 · 接回原序 1 项]
--    原 ORDER BY：处置, TABLE_NAME
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`处置`, y.`表名`, y.`估计行数`, y.`表注释`) AS rn
  FROM (
    /* 在此贴入总包行 589~608 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 113. Z03_column_dictionary.csv   [总包行 619~630 · 输出 8 列 · 接回原序 0 项]
--    原 ORDER BY：TABLE_NAME, ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`表名`, y.`列序`, y.`列名`, y.`存储类型`, y.`可空`, y.`原始类型`, y.`业务含义`, y.`原始注释`) AS rn
  FROM (
    /* 在此贴入总包行 619~630 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 114. Z04_name_collision.csv   [总包行 644~667 · 输出 6 列 · 接回原序 3 项]
--    原 ORDER BY：类型数 DESC, 释义数 DESC, 出现表数 DESC, COLUMN_NAME
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`类型数` DESC, y.`释义数` DESC, y.`出现表数` DESC, y.`列名`, y.`风险`, y.`明细`) AS rn
  FROM (
    /* 在此贴入总包行 644~667 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 115. Z05_missing_typehint.csv   [总包行 676~695 · 输出 6 列 · 接回原序 1 项]
--    原 ORDER BY：状态, TABLE_NAME, ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`状态`, y.`表名`, y.`列序`, y.`列名`, y.`存储类型`, y.`原始注释`) AS rn
  FROM (
    /* 在此贴入总包行 676~695 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 116. Z06_generated_probe_sql.csv   [总包行 709~730 · 输出 5 列 · 接回原序 0 项]
--    原 ORDER BY：t.TABLE_ROWS DESC, c.TABLE_NAME, c.ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`表名`, y.`列序`, y.`列名`, y.`估计行数`, y.`待执行SQL`) AS rn
  FROM (
    /* 在此贴入总包行 709~730 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 117. Z07_probe_bet02.csv   [总包行 743~782 · 输出 5 列 · 接回原序 0 项]   [🚩第 [1, 2, 3, 4, 5] 列无别名 → 非全序，建议一次导全 · 含 UNION]
--    原 ORDER BY：1, 2, 4 DESC
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY ) AS rn
  FROM (
    /* 在此贴入总包行 743~782 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 118. Z08_roundkey_integrity.csv   [总包行 796~833 · 输出 9 列 · 接回原序 0 项]   [🚩第 [9] 列无别名 → 非全序，建议一次导全]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`注单行数`, y.`局键数`, y.`单局最大注单行数`, y.`单局最大会员数`, y.`单局会员数P999`, y.`跨桌局键数_应为0`, y.`bet03跨桌数`, y.`bet03唯一值数`) AS rn
  FROM (
    /* 在此贴入总包行 796~833 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 119. Z09_time_axis_recon.csv   [总包行 854~885 · 输出 17 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`行数`, y.`dt等于账务日`, y.`dt等于下注日`, y.`账务日等于下注日`, y.`账务日不可用`, y.`开局时间不可用`, y.`下注时间不可用`, y.`下注时间纪元哨兵`, y.`开局时间纪元哨兵`, y.`账务日最小`, y.`账务日最大`, y.`下注早于开局_时序异常`, y.`下注距开局秒_最小`, y.`下注距开局秒_P50`, y.`下注距开局秒_P99`, y.`下注距开局秒_P999`, y.`下注距开局秒_最大`) AS rn
  FROM (
    /* 在此贴入总包行 854~885 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 120. Z11_sentinel_impact.csv   [总包行 919~957 · 输出 13 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`未处置_注单行数`, y.`已处置_注单行数`, y.`未处置_局键数`, y.`已处置_局键数`, y.`未处置_会员数`, y.`已处置_会员数`, y.`未处置_IP数`, y.`已处置_IP数`, y.`未处置_单局最大会员数`, y.`已处置_单局最大会员数`, y.`单局最大会员数_差额`, y.`剔除行数`, y.`剔除占比`) AS rn
  FROM (
    /* 在此贴入总包行 919~957 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 121. Z14_zero_month_diagnosis.csv   [总包行 1026~1130 · 输出 23 列 · 接回原序 3 项]
--    原 ORDER BY：verdict_hint, m.member_id, m.bet_month
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`verdict_hint`, y.`member_id`, y.`bet_month`, y.`zero_kind`, y.`vb_sum_state`, y.`n_orders`, y.`n_rounds_month`, y.`n_days_month`, y.`n_tables_month`, y.`n_vb_null`, y.`n_vb_blank`, y.`n_vb_true_zero`, y.`n_vb_positive`, y.`vb_null_share`, y.`sum_valid_bet`, y.`sum_stake`, y.`sum_game_pnl`, y.`sum_rebate`, y.`n_order_nocomm`, y.`n_hedge_rounds`, y.`n_hedge_eq`, y.`n_zero_pnl_rounds`, y.`hedge_eq_share`) AS rn
  FROM (
    /* 在此贴入总包行 1026~1130 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 122. _P12b-pre.csv   [总包行 9791~9799 · 输出 4 列 · 接回原序 0 项]   [🚩语句内已含 LIMIT]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`member_id`, y.`action`, y.`content`, y.`action_time`) AS rn
  FROM (
    /* 在此贴入总包行 9791~9799 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 123. _PH0_1b_table_inventory.csv   [总包行 12393~12445 · 输出 10 列 · 接回原序 2 项]
--    原 ORDER BY：h_src, table_nature, t.TABLE_NAME
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`h_src`, y.`table_nature`, y.`table_name`, y.`has_uid`, y.`has_time`, y.`has_amount`, y.`n_cols`, y.`scope_db`, y.`scope_pattern`, y.`scope_scanned_at`) AS rn
  FROM (
    /* 在此贴入总包行 12393~12445 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 124. _PH0_2b_column_inventory.csv   [总包行 12457~12505 · 输出 11 列 · 接回原序 0 项]
--    原 ORDER BY：c.TABLE_NAME, c.ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`table_name`, y.`col_pos`, y.`column_name`, y.`data_type`, y.`column_comment`, y.`name_style`, y.`col_family`, y.`fp_flag`, y.`scope_db`, y.`scope_pattern`, y.`scope_scanned_at`) AS rn
  FROM (
    /* 在此贴入总包行 12457~12505 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 125. _PH0_3_lmc_category.csv   [总包行 12598~12615 · 输出 12 列 · 接回原序 2 项]
--    原 ORDER BY：n_events DESC, lmc04_category
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_events` DESC, y.`lmc04_category`, y.`n_target_id`, y.`n_operator`, y.`dt_min`, y.`dt_max`, y.`n_in_win`, y.`avg_len_content`, y.`avg_len_sql`, y.`n_content_hit_mem01617`, y.`n_sql_hit_mem01617`, y.`n_hit_rg_semantics`) AS rn
  FROM (
    /* 在此贴入总包行 12598~12615 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 126. _PH0_4L1_member_columns.csv   [总包行 12811~12820 · 输出 5 列 · 接回原序 0 项]
--    原 ORDER BY：c.TABLE_NAME, c.ORDINAL_POSITION
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`table_name`, y.`col_pos`, y.`column_name`, y.`data_type`, y.`column_comment`) AS rn
  FROM (
    /* 在此贴入总包行 12811~12820 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 127. _PH0_4b_rg_keyword.csv   [总包行 12664~12694 · 输出 11 列 · 接回原序 2 项]
--    原 ORDER BY：n_events DESC, lmc04_category
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_events` DESC, y.`lmc04_category`, y.`rg_self_exclusion`, y.`rg_cooling_off`, y.`rg_responsible`, y.`biz_limit`, y.`biz_freeze`, y.`biz_disable`, y.`biz_block`, y.`amb_exclude_any`, y.`n_in_win`) AS rn
  FROM (
    /* 在此贴入总包行 12664~12694 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 128. _PH0_4w2_balance_points.csv   [总包行 12777~12799 · 输出 12 列 · 接回原序 0 项]
--    原 ORDER BY：（无）
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`dt_slice`, y.`n_user_active`, y.`n_pts_total`, y.`pts_avg`, y.`pts_min`, y.`pts_p50`, y.`pts_p90`, y.`pts_p99`, y.`pts_max`, y.`pts_ok_avg`, y.`n_user_single_pt`, y.`pct_single_pt`) AS rn
  FROM (
    /* 在此贴入总包行 12777~12799 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;

-- ── 129. _PH0_6b_member_daily.csv   [总包行 13015~13025 · 输出 6 列 · 接回原序 0 项]
--    原 ORDER BY：dt
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`dt_day`, y.`n_rows`, y.`n_mem001`, y.`rows_per_key`, y.`n_enable_N`, y.`n_canbet_N`) AS rn
  FROM (
    /* 在此贴入总包行 13015~13025 之原查询，删去其末尾 ORDER BY 与分号 */
  ) y
) z
WHERE z.rn >      0 AND z.rn <=  100000   -- 第 1 批；第 k 批：> (k-1)*100000 AND <= k*100000
ORDER BY z.rn;
