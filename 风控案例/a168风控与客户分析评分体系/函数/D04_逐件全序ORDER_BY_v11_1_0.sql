-- ═══════════════════════════════════════════════════════════════════════════════
-- §D04 · 全序 ORDER BY 与 OFFSET 分批模板（逐件 · 共 129 件）
-- 立于 2026-08-24 · 配 a168_取数与核验_SQL总包_v11_1_0.sql（REL-0006 / C1）
-- 每批上限 100,000 行。照此替换各件末尾之 ORDER BY，OFFSET 分批即零重复、零遗漏。
--
-- 【何以奏效】OFFSET 之病不在 OFFSET，在「非全序」。排序键若可并列，两次执行之
--   并列组内次序不同，切片处即错位，遂生重复与遗漏（二者恒等量）。今于原 ORDER BY
--   之后追加全部输出列之序号 1..N，则整行元组即为排序键——纵有值全同之行，其互换
--   亦不改变取回之值集，故分批结果与一次导全**逐行等同**。
--
-- 【停批规则】某批返回行数 < 100000 即为末批，其后不再取。
-- 【取数前】先跑 SELECT COUNT(*) FROM ( 原查询去掉 ORDER BY 与 LIMIT ) x  留档为 T_true。
-- 【取数后】自验三数相等：取回总行数 = 不重复行数 = T_true。任一不符即整件重取。
-- 【成本警示】ORDER BY 施于最终结果，故每批皆须把整条链重算一遍；LIMIT 只省传输，
--   不省计算。行数不足 10 万者一律一次导全，不必分批（详见总包行 4455~4458）。
-- ═══════════════════════════════════════════════════════════════════════════════

-- ──   1. A_anchor.csv   [总包行 2999~3009 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：n_orders DESC
ORDER BY n_orders DESC, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   2. B01_bt_panel.csv   [总包行 5314~5392 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：bet_date, member_id
ORDER BY bet_date, member_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   3. B01_bt_panel_delta.csv   [总包行 5406~5484 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：member_id, bet_date
ORDER BY member_id, bet_date, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   4. B4_2b_funnel_and_mu0.csv   [总包行 11938~12058 · 输出 26 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   5. B4_5b_tip_nature.csv   [总包行 12072~12103 · 输出 16 列 · 原判 C 级]
--    原 ORDER BY：n_rows DESC, bet09_value
ORDER BY n_rows DESC, bet09_value, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   6. B_online_base.csv   [总包行 2929~2991 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：table_id, sec_elapsed
ORDER BY table_id, sec_elapsed, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   7. C01_ip_chain.csv   [总包行 1663~1723 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：member_per_chain DESC
ORDER BY member_per_chain DESC, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   8. C06_hedge_pairs.csv   [总包行 5814~5886 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：opposite_rate DESC, n_opposite_round DESC
ORDER BY opposite_rate DESC, n_opposite_round DESC, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──   9. C06d_hedge_pairs_dated.csv   [总包行 8067~8133 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：opposite_rate DESC, n_opposite_round DESC
ORDER BY opposite_rate DESC, n_opposite_round DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  10. C08_subnet_all.csv   [总包行 1759~1820 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：n_member DESC
ORDER BY n_member DESC, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  11. C08_subnet_sparse.csv   [总包行 1829~1890 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：n_member DESC
ORDER BY n_member DESC, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  12. D03S_daily_roi_diff.csv   [总包行 1991~2062 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：bet_date
ORDER BY bet_date, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  13. DICT_01a_bet41_tri.csv   [总包行 11764~11798 · 输出 14 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  14. DICT_01b_roundkey_card.csv   [总包行 11812~11835 · 输出 14 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  15. DICT_01c_dimension.csv   [总包行 11850~11878 · 输出 12 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  16. DICT_01d_bet_latency.csv   [总包行 11893~11926 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：n_rows DESC, table_id
ORDER BY n_rows DESC, table_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  17. DX04_bet09_profile.csv   [总包行 5971~6005 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：n_orders DESC
ORDER BY n_orders DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  18. DX05_product_panorama.csv   [总包行 6020~6073 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：n_orders DESC
ORDER BY n_orders DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  19. E02_segment_econ.csv   [总包行 5707~5797 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：validbet DESC
ORDER BY validbet DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  20. EV01_disposal_events.csv   [总包行 7112~7153 · 输出 13 列 · 原判 C 级]
--    原 ORDER BY：optime
ORDER BY optime, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  21. EV02_member_disposal.csv   [总包行 7289~7322 · 输出 12 列 · 原判 C 级]
--    原 ORDER BY：lmc09
ORDER BY lmc09, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  22. I_ip_agg.csv   [总包行 2695~2768 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：n_member_eff DESC
ORDER BY n_member_eff DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  23. I_ip_player.csv   [总包行 1589~1654 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：n_orders_ip DESC
ORDER BY n_orders_ip DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  24. K01_risk_feature_matrix.csv   [总包行 5499~5591 · 输出 15 列 · 原判 C 级]
--    原 ORDER BY：f.validbet DESC
ORDER BY f.validbet DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  25. K01b_seed_goldip.csv   [总包行 5637~5643 · 输出 2 列 · 原判 C 级]
--    原 ORDER BY：member_id
ORDER BY member_id, 1, 2
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  26. K01b_seed_manual.csv   [总包行 5618~5625 · 输出 2 列 · 原判 C 级]
--    原 ORDER BY：member_id
ORDER BY member_id, 1, 2
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  27. K01c_seed_dated.csv   [总包行 8330~8337 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：addtime
ORDER BY addtime, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  28. L_label_dist.csv   [总包行 1472~1476 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：n_rows DESC
ORDER BY n_rows DESC, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  29. P01A_crosstab.csv   [总包行 9199~9219 · 输出 13 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  30. P01B_diff_ratio.csv   [总包行 9223~9240 · 输出 11 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  31. P01C_split_by_dim.csv   [总包行 9246~9269 · 输出 14 列 · 原判 C 级]
--    原 ORDER BY：ym, bet09, commission, bet10
ORDER BY ym, bet09, commission, bet10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  32. P01D_vs_validbet.csv   [总包行 9274~9290 · 输出 9 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  33. P01E_identity_test.csv   [总包行 9295~9330 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：hypothesis
ORDER BY hypothesis, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  34. P02A_lmc_samples.csv   [总包行 9351~9363 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：类别, 取样端, 異動時間
ORDER BY 类别, 取样端, 異動時間, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  35. P02B_changestatus_patterns.csv   [总包行 9369~9378 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：n DESC
ORDER BY n DESC, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  36. P02C_key_check.csv   [总包行 9385~9401 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：l.lmc03
ORDER BY l.lmc03, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  37. P02D_events_in_window.csv   [总包行 9406~9414 · 输出 4 列 · 原判 C 级]
--    原 ORDER BY：类别, 层级
ORDER BY 类别, 层级, 1, 2, 3, 4
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  38. P0C02_标签口径.csv   [总包行 7728~7761 · 输出 6 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  39. P0C03_标记次数分布.csv   [总包行 7767~7781 · 输出 3 列 · 原判 C 级]
--    原 ORDER BY：标记次数
ORDER BY 标记次数, 1, 2, 3
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  40. P0C04_同日泄漏检验.csv   [总包行 7793~7828 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：标记日_洗码量 DESC
ORDER BY 标记日_洗码量 DESC, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  41. P0C05_标记时点定位.csv   [总包行 7833~7864 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：标记距首投_日
ORDER BY 标记距首投_日, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  42. P0C06_LabelB骨架.csv   [总包行 7871~7904 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：a.mem, a.anchor_day
ORDER BY a.mem, a.anchor_day, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  43. P0C09_安慰剂检验.csv   [总包行 7995~8032 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：a.mem, a.d
ORDER BY a.mem, a.d, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  44. P11_阿泽尾段投注总帐.csv   [总包行 9519~9655 · 输出 21 列 · 原判 C 级]
--    原 ORDER BY：b.scope_def
ORDER BY b.scope_def, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  45. P11_阿泽尾段投注模型会员名单.csv   [总包行 9443~9500 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：roi DESC, profit DESC
ORDER BY roi DESC, profit DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  46. P11_雷欧尾段投注总帐.csv   [总包行 9667~9769 · 输出 21 列 · 原判 C 级]
--    原 ORDER BY：b.scope_def
ORDER BY b.scope_def, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  47. P12a_platform_daily.csv   [总包行 9808~9873 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：dt
ORDER BY dt, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  48. P12b_member_events.csv   [总包行 9885~9941 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：m.uid
ORDER BY m.uid, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  49. P12c_member_daily_pnl.csv   [总包行 9954~10005 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：g.uid, g.dt
ORDER BY g.uid, g.dt, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  50. P13_personal_entry.csv   [总包行 10145~10204 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：uid
ORDER BY uid, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  51. PH0_8r1_rg_case.csv   [总包行 13308~13322 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：dt, lmc08, lmc02
ORDER BY dt, lmc08, lmc02, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  52. PH0_8r2_rg_crosstable.csv   [总包行 13334~13390 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：n_rg_true DESC, src
ORDER BY n_rg_true DESC, src, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  53. PI01_treatment_delta_member.csv   [总包行 13468~13599 · 输出 21 列 · 原判 C 级]
--    原 ORDER BY：d_revenue, member_id
ORDER BY d_revenue, member_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  54. PI02_treatment_delta_platform.csv   [总包行 13612~13713 · 输出 13 列 · 原判 C 级]
--    原 ORDER BY：cohort, phase
ORDER BY cohort, phase, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  55. PI03_reinvest_loop.csv   [总包行 13728~13791 · 输出 13 列 · 原判 C 级]
--    原 ORDER BY：n_pairs DESC, prev_outcome
ORDER BY n_pairs DESC, prev_outcome, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  56. PI04_member_5d_profile.csv   [总包行 13808~13877 · 输出 20 列 · 原判 C 级]
--    原 ORDER BY：sum_revenue DESC, member_id
ORDER BY sum_revenue DESC, member_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  57. P_player_month.csv   [总包行 2865~2921 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：member_id, ym
ORDER BY member_id, ym, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  58. QSB_01a_category_census.csv   [总包行 11153~11197 · 输出 22 列 · 原判 C 级]
--    原 ORDER BY：n_rows DESC, category_value
ORDER BY n_rows DESC, category_value, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  59. QSB_01c_cat1_contamination.csv   [总包行 11250~11283 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：n_b14_null DESC, n_pnl_zero_stake_pos DESC, n_rows DESC
ORDER BY n_b14_null DESC, n_pnl_zero_stake_pos DESC, n_rows DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  60. QSB_02a_lowcard_fields.csv   [总包行 11295~11316 · 输出 18 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  61. QSB_02b2_lowcard_five_gates.csv   [总包行 11498~11747 · 输出 19 列 · 原判 C 级]
--    原 ORDER BY：field_name, n_rows DESC, field_value
ORDER BY field_name, n_rows DESC, field_value, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  62. QSB_02b_state_cross.csv   [总包行 11331~11424 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：field_name, n_rows DESC, field_value
ORDER BY field_name, n_rows DESC, field_value, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  63. QSB_02c_push_by_family.csv   [总包行 11437~11489 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：n_rows DESC, bet09_family
ORDER BY n_rows DESC, bet09_family, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  64. R01_late_shoe.csv   [总包行 3463~3539 · 输出 15 列 · 原判 C 级]
--    原 ORDER BY：late_share DESC, n_orders_late DESC
ORDER BY late_share DESC, n_orders_late DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  65. R01_late_shoe_w2.csv   [总包行 10048~10124 · 输出 15 列 · 原判 C 级]
--    原 ORDER BY：late_share DESC, n_orders_late DESC
ORDER BY late_share DESC, n_orders_late DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  66. R01anm_shoe_anomaly.csv   [总包行 3948~4009 · 输出 11 列 · 原判 C 级]
--    原 ORDER BY：s.max_round DESC, s.dt, s.table_id, s.shoe_id
ORDER BY s.max_round DESC, s.dt, s.table_id, s.shoe_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  67. R01chk_shoe_len_by_table.csv   [总包行 3725~3855 · 输出 28 列 · 原判 C 级]
--    原 ORDER BY：z.avg_max_round DESC, z.table_id
ORDER BY z.avg_max_round DESC, z.table_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  68. R01inv_shoe_len_census.csv   [总包行 3865~3940 · 输出 19 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  69. R02_same_table.csv   [总包行 4293~4365 · 输出 12 列 · 原判 C 级]
--    原 ORDER BY：lift DESC, same_rate DESC
ORDER BY lift DESC, same_rate DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  70. R03_player_dealer.csv   [总包行 4502~4633 · 输出 33 列 · 原判 C 级]
--    原 ORDER BY：pdw.member_id, pdw.dealer_id
ORDER BY pdw.member_id, pdw.dealer_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  71. R03b_player_dealer_daily.csv   [总包行 6143~6242 · 输出 24 列 · 原判 C 级]
--    原 ORDER BY：p.bet_date, p.member_id, p.dealer_id
ORDER BY p.bet_date, p.member_id, p.dealer_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  72. R03chk_settlement_form.csv   [总包行 4684~4723 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：n_rounds DESC
ORDER BY n_rounds DESC, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  73. R03inv_pair_census.csv   [总包行 4745~4796 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：1, 2
ORDER BY 1, 2, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  74. R_rebate_dist.csv   [总包行 1489~1492 · 输出 3 列 · 原判 C 级]
--    原 ORDER BY：n_member DESC
ORDER BY n_member DESC, 1, 2, 3
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  75. S01_player_score.csv   [总包行 2198~2320 · 输出 11 列 · 原判 C 级]
--    原 ORDER BY：流水贡献 DESC
ORDER BY 流水贡献 DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  76. S02_dealer_score.csv   [总包行 2339~2458 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：在桌洗码量 DESC
ORDER BY 在桌洗码量 DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  77. S02b_dealer_pace.csv   [总包行 6390~6447 · 输出 3 列 · 原判 C 级]
--    原 ORDER BY：局速 DESC
ORDER BY 局速 DESC, 1, 2, 3
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  78. S03_agent_score.csv   [总包行 2467~2566 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：真实流水 DESC
ORDER BY 真实流水 DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  79. S04_analyst_score.csv   [总包行 6277~6302 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：标注产量 DESC
ORDER BY 标注产量 DESC, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  80. S05_member_month_panel.csv   [总包行 2614~2678 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：b.member_id, bet_date
ORDER BY b.member_id, bet_date, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  81. S_player_tail.csv   [总包行 2077~2189 · 输出 18 列 · 原判 C 级]
--    原 ORDER BY：member_id
ORDER BY member_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  82. S_second_dist.csv   [总包行 1914~1982 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：n_orders DESC
ORDER BY n_orders DESC, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  83. T02_daily_roi.csv   [总包行 5146~5190 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：o.member_id, o.bet_date
ORDER BY o.member_id, o.bet_date, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  84. T03_arbitrage.csv   [总包行 5204~5275 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：hedge_rate DESC, validbet DESC
ORDER BY hedge_rate DESC, validbet DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  85. TL00_table_inventory.csv   [总包行 8168~8215 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：处置类列数 DESC, 定日类列数 DESC, c.TABLE_NAME
ORDER BY 处置类列数 DESC, 定日类列数 DESC, c.TABLE_NAME, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  86. TL02_config_change.csv   [总包行 8238~8269 · 输出 4 列 · 原判 C 级]
--    原 ORDER BY：发生变更的会员数 DESC
ORDER BY 发生变更的会员数 DESC, 1, 2, 3, 4
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  87. TL03_pseudo_treatment.csv   [总包行 8276~8324 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：member_id, change_date
ORDER BY member_id, change_date, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  88. TL03b_pseudo_treatment.csv   [总包行 8417~8466 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：member_id, cate, change_date
ORDER BY member_id, cate, change_date, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  89. TL04_log_schema.csv   [总包行 8383~8389 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：TABLE_NAME, ORDINAL_POSITION
ORDER BY TABLE_NAME, ORDINAL_POSITION, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  90. TL06_log_mem_change.csv   [总包行 8473~8479 · 输出 2 列 · 原判 C 级]
--    原 ORDER BY：dt
ORDER BY dt, 1, 2
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  91. TL07_mem_change_shape.csv   [总包行 8519~8533 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：条数 DESC
ORDER BY 条数 DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  92. TL08_treatment_events.csv   [总包行 8541~8572 · 输出 9 列 · 原判 C 级]
--    原 ORDER BY：ev.action_time, ev.member_id
ORDER BY ev.action_time, ev.member_id, 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  93. TL09_member_schema.csv   [总包行 8603~8607 · 输出 4 列 · 原判 C 级]
--    原 ORDER BY：ORDINAL_POSITION
ORDER BY ORDINAL_POSITION, 1, 2, 3, 4
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  94. TL10_treatment_ledger.csv   [总包行 8615~8675 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：p.action_time, p.member_id, p.field_name
ORDER BY p.action_time, p.member_id, p.field_name, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  95. TL11_treatment_episode.csv   [总包行 8706~8832 · 输出 24 列 · 原判 C 级]
--    原 ORDER BY：p.member_id, p.action_time
ORDER BY p.member_id, p.action_time, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  96. TL11c_population_reconcile.csv   [总包行 8969~9055 · 输出 7 列 · 原判 C 级]
--    原 ORDER BY：lvl
ORDER BY lvl, 1, 2, 3, 4, 5, 6, 7
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  97. TL14_limit_treatment.csv   [总包行 5058~5136 · 输出 15 列 · 原判 C 级]
--    原 ORDER BY：l.member_id, l.action_time
ORDER BY l.member_id, l.action_time, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  98. T_table_span.csv   [总包行 1447~1455 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：n_rounds DESC
ORDER BY n_rounds DESC, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ──  99. VB_00_validbet_contract.csv   [总包行 10675~10697 · 输出 13 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 100. VB_00b_zero_five_rates.csv   [总包行 10801~10869 · 输出 18 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 101. VB_41_identity_global.csv   [总包行 10716~10750 · 输出 17 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 102. VB_41b_identity_strata.csv   [总包行 10761~10792 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：n_null_asym DESC, n_value_diff DESC, n_rows DESC
ORDER BY n_null_asym DESC, n_value_diff DESC, n_rows DESC, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 103. VB_41b_identity_strata_v18b.csv   [总包行 10876~10930 · 输出 18 列 · 原判 C 级]
--    原 ORDER BY：n_null_asym DESC, n_value_diff DESC, n_rows DESC, bet09_value, commission_value
ORDER BY n_null_asym DESC, n_value_diff DESC, n_rows DESC, bet09_value, commission_value, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 104. VB_41c1_964_detail.csv   [总包行 10939~10970 · 输出 22 列 · 原判 C 级]
--    原 ORDER BY：grp, dt, bet_time, member_id, bet01
ORDER BY grp, dt, bet_time, member_id, bet01, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 105. VB_41c2_concentration.csv   [总包行 10982~11045 · 输出 20 列 · 原判 C 级]
--    原 ORDER BY：t.grp
ORDER BY t.grp, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 106. VB_41c2_concentration_v2.csv   [总包行 11052~11140 · 输出 20 列 · 原判 C 级]
--    原 ORDER BY：o.grp
ORDER BY o.grp, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 107. V_ipmatch.csv   [总包行 3017~3029 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：b.n_member_log DESC
ORDER BY b.n_member_log DESC, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 108. V_recon.csv   [总包行 1506~1576 · 输出 12 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 109. V_table_counts.csv   [总包行 6092~6101 · 输出 2 列 · 原判 C 级]
--    原 ORDER BY：行数 DESC
ORDER BY 行数 DESC, 1, 2
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 110. X_combo.csv   [总包行 2776~2857 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：1 DESC,2 DESC
ORDER BY 1 DESC,2 DESC, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 111. Z01_table_inventory.csv   [总包行 561~579 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：疑似性质, TABLE_NAME
ORDER BY 疑似性质, TABLE_NAME, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 112. Z02_excluded_tables.csv   [总包行 589~608 · 输出 4 列 · 原判 C 级]
--    原 ORDER BY：处置, TABLE_NAME
ORDER BY 处置, TABLE_NAME, 1, 2, 3, 4
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 113. Z03_column_dictionary.csv   [总包行 619~630 · 输出 8 列 · 原判 C 级]
--    原 ORDER BY：TABLE_NAME, ORDINAL_POSITION
ORDER BY TABLE_NAME, ORDINAL_POSITION, 1, 2, 3, 4, 5, 6, 7, 8
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 114. Z04_name_collision.csv   [总包行 644~667 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：类型数 DESC, 释义数 DESC, 出现表数 DESC, COLUMN_NAME
ORDER BY 类型数 DESC, 释义数 DESC, 出现表数 DESC, COLUMN_NAME, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 115. Z05_missing_typehint.csv   [总包行 676~695 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：状态, TABLE_NAME, ORDINAL_POSITION
ORDER BY 状态, TABLE_NAME, ORDINAL_POSITION, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 116. Z06_generated_probe_sql.csv   [总包行 709~730 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：t.TABLE_ROWS DESC, c.TABLE_NAME, c.ORDINAL_POSITION
ORDER BY t.TABLE_ROWS DESC, c.TABLE_NAME, c.ORDINAL_POSITION, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 117. Z07_probe_bet02.csv   [总包行 743~782 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：1, 2, 4 DESC
ORDER BY 1, 2, 4 DESC, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 118. Z08_roundkey_integrity.csv   [总包行 796~833 · 输出 9 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 119. Z09_time_axis_recon.csv   [总包行 854~885 · 输出 17 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 120. Z11_sentinel_impact.csv   [总包行 919~957 · 输出 13 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 121. Z14_zero_month_diagnosis.csv   [总包行 1026~1130 · 输出 23 列 · 原判 C 级]
--    原 ORDER BY：verdict_hint, m.member_id, m.bet_month
ORDER BY verdict_hint, m.member_id, m.bet_month, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 122. _P12b-pre.csv   [总包行 9791~9799 · 输出 4 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 123. _PH0_1b_table_inventory.csv   [总包行 12393~12445 · 输出 10 列 · 原判 C 级]
--    原 ORDER BY：h_src, table_nature, t.TABLE_NAME
ORDER BY h_src, table_nature, t.TABLE_NAME, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 124. _PH0_2b_column_inventory.csv   [总包行 12457~12505 · 输出 11 列 · 原判 C 级]
--    原 ORDER BY：c.TABLE_NAME, c.ORDINAL_POSITION
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 125. _PH0_3_lmc_category.csv   [总包行 12598~12615 · 输出 12 列 · 原判 C 级]
--    原 ORDER BY：n_events DESC, lmc04_category
ORDER BY n_events DESC, lmc04_category, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 126. _PH0_4L1_member_columns.csv   [总包行 12811~12820 · 输出 5 列 · 原判 C 级]
--    原 ORDER BY：c.TABLE_NAME, c.ORDINAL_POSITION
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION, 1, 2, 3, 4, 5
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 127. _PH0_4b_rg_keyword.csv   [总包行 12664~12694 · 输出 11 列 · 原判 C 级]
--    原 ORDER BY：n_events DESC, lmc04_category
ORDER BY n_events DESC, lmc04_category, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 128. _PH0_4w2_balance_points.csv   [总包行 12777~12799 · 输出 12 列 · 原判 D 级]
--    原 ORDER BY：（无 —— 原为 D 级，次序完全未定义）
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

-- ── 129. _PH0_6b_member_daily.csv   [总包行 13015~13025 · 输出 6 列 · 原判 C 级]
--    原 ORDER BY：dt
ORDER BY dt, 1, 2, 3, 4, 5, 6
LIMIT 100000 OFFSET 0;        -- 第 1 批；其后每批 OFFSET += 100000

