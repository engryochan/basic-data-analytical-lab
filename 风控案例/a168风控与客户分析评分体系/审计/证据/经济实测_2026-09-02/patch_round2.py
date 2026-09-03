# -*- coding: utf-8 -*-
"""Round-2 corrections from the completeness critic + round2.R measurements:
CC-01 (block profit = NGR; ngr column double-deducts), corrected rebate/hedge bands with CI, seed cohort,
ledger-wide pre/post (P12c), unit reconciliation, EMPTY_BLOCK, item 133, scope, EG fixes."""
p = "gen_registry_v1_5_002.py"
s = open(p, encoding="utf-8").read()
def rep(old, new, cnt=1):
    global s
    assert old in s, "MISSING: " + old[:100]
    s = s.replace(old, new, cnt)

# ---- inputs from round2.R ----
rep('''er     = rcsv(os.path.join(SP, "S01_evidence_rate.csv"))''',
'''er     = rcsv(os.path.join(SP, "S01_evidence_rate.csv"))
r2     = {r["metric"]: float(r["value"]) for r in rcsv(os.path.join(SP, "round2_summary.csv"))}
rb2    = rcsv(os.path.join(SP, "S01_rebate_bands_v2.csv"))
hedge2 = rcsv(os.path.join(SP, "T03_hedge_bands_v2.csv"))
seed2  = rcsv(os.path.join(SP, "seed_cohort_v2.csv"))
cw     = rcsv(os.path.join(SP, "hold_crosswalk.csv"))
xt     = rcsv(os.path.join(SP, "PI01_x_typology.csv"))
lp     = rcsv(os.path.join(SP, "ledger_prepost_by_field.csv"))
l14    = rcsv(os.path.join(SP, "tl14_prepost_by_direction.csv"))
recon  = rcsv(os.path.join(SP, "own_money_reconciliation.csv"))
recon_by_table = {}
for r in recon: recon_by_table.setdefault(r["table"], []).append(r)''')

# ---- EMPTY_BLOCK state + units reconciliation field + T-03 guard already; item 133 appended later ----
rep('''    if blk == "MIXED":''',
'''    _sc = next((c for c in census if c["table"] == f and c["column"] == "stake"), None)
    if _sc and _sc["status"] == "EMPTY" and blk in ("BROADCAST_CONSTANT", "SINGLE_ROW_BROADCAST", "PER_ROW"): blk = "EMPTY_BLOCK"
    if blk == "MIXED":''')
rep('''        ("economic_value_distinct", int(ev["n_distinct"]) if ev else None),
    ]))''',
'''        ("economic_value_distinct", int(ev["n_distinct"]) if ev else None),
        ("own_money_units_reconciliation", [collections.OrderedDict([("column", x["column"]), ("sum", round(float(x["sum"]))), ("ratio_to_platform_stake", round(float(x["ratio_to_stake"]), 4)), ("ratio_to_gross_ggr", round(float(x["ratio_to_gross_ggr"]), 4)), ("verdict", x["units_verdict"])]) for x in recon_by_table.get(f, [])] if recon_by_table.get(f) else None),
        ("own_money_units_verdict", ("PLAUSIBLE" if all(x["units_verdict"] == "PLAUSIBLE" for x in recon_by_table[f]) else "UNITS_OR_SCOPE_UNRECONCILED") if recon_by_table.get(f) else ("NO_OWN_MONEY_COLUMNS" if present else None)),
    ]))''')
# downgrade admissibility when units unreconciled
rep('''    if f in ("R01_late_shoe.csv","R01_late_shoe_w2.csv","P13_personal_entry.csv","S_player_tail.csv","X_combo.csv","D03S_daily_roi_diff.csv") and adm == "ADMISSIBLE_AT_OWN_GRAIN": adm = "PROFILE_ONLY_P18"''',
'''    if f in ("R01_late_shoe.csv","R01_late_shoe_w2.csv","P13_personal_entry.csv","S_player_tail.csv","X_combo.csv","D03S_daily_roi_diff.csv") and adm == "ADMISSIBLE_AT_OWN_GRAIN": adm = "PROFILE_ONLY_P18"
    if adm == "OWN_COLUMNS_ONLY" and recon_by_table.get(f) and any(x["units_verdict"] != "PLAUSIBLE" for x in recon_by_table[f]): adm = "OWN_COLUMNS_UNITS_UNRECONCILED"''')
# item 133 (partial file) appended after loop
rep('''# ---------------------------------------------------------------- 2. treatment economic effects''',
'''_pf = "R03b_player_dealer_daily_b1_to_b8.csv"; _ph = header(_pf); _pown = [c for c in _ph if c not in BLOCK and not TYPO_SUFFIX.search(c)]
inv.append(collections.OrderedDict([("seq", 133), ("file", _pf), ("present", True), ("successor", None), ("mcode", "M07"), ("domain", "C"), ("entity", "会员"), ("grain", "bet_date × uid × dealer_id × is_sentinel_dealer（#071 之前八批 PARTIAL）"),
    ("rows", 800000), ("ncol", len(_ph)), ("n_own", len(_pown)), ("n_block", len(_ph) - len(_pown)), ("pack_credibility", "WRONG_GRAIN（承 #071；D-14b 六层 16 列置 NULL）"), ("pack_usage", "NOT_FOR_DECISION"), ("lineage_class", "未登记"),
    ("econ_block_status", "NULL_BY_DESIGN_D14b"), ("economic_admissibility", "OWN_COLUMNS_ONLY_PARTIAL"), ("p18_guard", False),
    ("own_money_columns", [c for c in _pown if MONEY.search(c) and not NOT_MONEY.search(c)]), ("own_metric_columns", [c for c in _pown if ECON_HINT.search(c)][:40]), ("own_native_columns_n", len(_pown)), ("typo_econ_suffix_columns_n", len(_ph) - len(_pown) - len(BLOCK)),
    ("theo", "ABSENT"), ("adt", "ABSENT"), ("nmpt", "ABSENT"), ("esi", "ABSENT"), ("economic_value_semantics", "ABSENT（CAST(NULL AS DOUBLE)，D-14b）"), ("economic_value_distinct", 0),
    ("own_money_units_reconciliation", None), ("own_money_units_verdict", "NOT_CHECKED_PARTIAL_FILE"), ("coverage", "batches 1–8 of #071（8 × 100,000 行）；#071 全量 18,139,550 行 MISSING（B-02）")]))
cnt_verd["NULL_BY_DESIGN_D14b"] += 1; cnt_adm["OWN_COLUMNS_ONLY_PARTIAL"] += 1

# ---------------------------------------------------------------- 2. treatment economic effects''')

# ---- typology gate: T-08 units ----
rep('''    elif money: gate = "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY"; why''',
'''    elif money and pi and pi.get("own_money_units_verdict") == "UNITS_OR_SCOPE_UNRECONCILED": gate = "BLOCKED_UNITS"; why = f"主表 {prim} 自有货币栏之合计与平台总额不可对账（如 E02 rebate 合计 14.9B ≫ 平台 8.2M），单位或范围未裁，禁作经济量"
    elif money: gate = "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY"; why''')
rep('''("states", ["E1_E5_COMPUTABLE_AT_GRAIN", "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY", "BLOCKED_GRAIN", "BLOCKED_UPSTREAM", "BLOCKED_UPSTREAM_FILE_MISSING", "FATAL_PROFILE_ONLY", "FAIL"])''',
'''("states", ["E1_E5_COMPUTABLE_AT_GRAIN", "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY", "BLOCKED_UNITS", "BLOCKED_GRAIN", "BLOCKED_UPSTREAM", "BLOCKED_UPSTREAM_FILE_MISSING", "FATAL_PROFILE_ONLY", "FAIL"])''')

# ---- platform accounting: gross basis (CC-01) ----
rep('''platform = collections.OrderedDict([
    ("source", "S01_player_score.csv（#075，OK/PRIMARY，723,442 会员逐员）— 2026-09-02 R 实读全量"),
    ("members", int(lev["platform_members"])), ("stake", round(lev["platform_stake"])), ("valid_bet", round(lev["platform_valid_bet"])),
    ("ggr", round(lev["platform_ggr"])), ("rebate_cost_bet16", round(lev["platform_rebate_cost"])), ("ngr", round(lev["platform_ngr"])),''',
'''platform = collections.OrderedDict([
    ("source", "S01_player_score.csv（#075，OK/PRIMARY，723,442 会员逐员）— 2026-09-02 R 实读全量；范围：百家乐（bet02='101'）单产品"),
    ("scope", collections.OrderedDict([("product", "101 百家乐（本报告口径）"), ("other_products_out_of_scope", collections.OrderedDict([("products", "102/103/104/105/107/108/5031"), ("stake", round(r2["other_products_stake"])), ("ggr", round(r2["other_products_ggr"])), ("member_rows", int(r2["other_products_members"])), ("note", "DX05 实测；其他产品 4.90B 本金、130.75M 毛利未入任何会员级经济表（EG-14）")]))])),
    ("basis_ruling_CC01", "六层块 profit = −bet17/bet11 = GGR − 退水 = NGR（bet17 已含退水）；块 ngr = GGR − 2×退水（重复扣减，DEPRECATED）；毛利 GGR = profit + rebate_cost = −游戏输赢贡献（M02）。以下各量按此口径"),
    ("members", int(lev["platform_members"])), ("stake", round(lev["platform_stake"])), ("valid_bet", round(lev["platform_valid_bet"])),
    ("ggr_gross", round(r2["gross_ggr"])), ("rebate_cost_bet16", round(lev["platform_rebate_cost"])), ("ngr", round(r2["ngr_true"])), ("ngr_column_double_deducted_DEPRECATED", round(lev["platform_ngr"])),''')
rep('''    ("net_margin_bet23_formal", round(lev["platform_net_margin_bet23"])), ("net_margin_status", "ORDERING_ONLY（AG-03 UNRESOLVED；agent_cost 候选 B 未裁，绝对额不得对外）"), ("implied_agent_cost_candidate_B", round(lev["platform_ngr"] - lev["platform_net_margin_bet23"])),
    ("hold_pct", round(lev["platform_hold_pct"], 4)), ("ngr_pct", round(lev["platform_ngr_pct"], 4)), ("net_margin_pct", round(lev["platform_net_margin_pct"], 4)),
    ("members_ngr_negative", int(lev["ngr_neg_members"])), ("ngr_negative_sum", round(lev["ngr_neg_sum"])),''',
'''    ("net_margin_candidate", round(r2["net_margin_candidate"])), ("net_margin_status", "ORDERING_ONLY（AG-03 UNRESOLVED；agent_cost 候选 B 未裁，绝对额不得对外）"), ("net_margin_column_double_deducted_DEPRECATED", round(lev["platform_net_margin_bet23"])),
    ("agent_cost_bases", collections.OrderedDict([("formal_bet23", round(r2["agent_cost_formal"])), ("lv1", round(r2["agent_cost_lv1"])), ("lv2", round(r2["agent_cost_lv2"])), ("lv3", round(r2["agent_cost_lv3"])), ("lv4", round(r2["agent_cost_lv4"])), ("lv5", round(r2["agent_cost_lv5"])), ("spread", round(r2["agent_cost_spread"])), ("note", "五口径极差 659,108 ＝ 代理成本 7.2%、毛利 0.28%；AG-03 之经济量级已量化，裁决仍待")])),
    ("hold_gross_pct_stake_basis", round(r2["hold_gross_stake_pct"], 4)), ("hold_gross_pct_validbet_basis", round(r2["hold_gross_validbet_pct"], 4)), ("ngr_rate_pct", round(r2["ngr_rate_pct"], 4)), ("net_margin_candidate_pct", round(r2["net_margin_candidate_pct"], 4)),
    ("hold_basis_crosswalk", [collections.OrderedDict([("source", r["source"]), ("numerator", round(fnum(r["numerator"]))), ("denominator", round(fnum(r["denominator"]))), ("hold_pct", fnum(r["hold_pct"]))]) for r in cw]),
    ("members_ngr_negative", int(r2["members_ngr_negative"])), ("ngr_negative_sum", round(r2["members_ngr_negative_sum"])), ("members_gross_negative", int(r2["members_gross_negative"])),''')

# ---- LM-01 rebate bands v2, LM-02 hedge v2, LM-06 seed ----
rep('''    ("members_receiving_rebate", int(lev["rebate_members"])), ("rebate_paid", round(lev["rebate_members_rebate"])), ("their_ggr", round(lev["rebate_members_ggr"])), ("their_ngr", round(lev["rebate_members_ngr"])),
    ("their_pooled_hold_pct", round(lev["rebate_members_hold_pct"], 3)), ("their_pooled_ngr_pct", round(lev["rebate_members_ngr_pct"], 3)),
    ("rebate_bands", [collections.OrderedDict([("band", r["rb_band"]), ("count", int(r["n"])), ("valid_bet", round(fnum(r["valid_bet"]))), ("ggr", round(fnum(r["ggr"]))), ("rebate", round(fnum(r["rebate"]))), ("ngr", round(fnum(r["ngr"]))), ("hold_pct", fnum(r["hold_pct"])), ("ngr_pct", fnum(r["ngr_pct"])), ("n_ngr_negative", int(r["n_ngr_neg"]))]) for r in rb]),
    ("rebate_members_with_negative_ngr", int(lev["rebate_members_ngr_neg_n"])), ("rebate_paid_to_negative_ngr_members", round(lev["rebate_members_ngr_neg_rebate"])),''',
'''    ("basis", "CC-01 毛利口径：ggr_gross = profit + rebate_cost；ngr = profit"),
    ("members_receiving_rebate", int(r2["rebate_members"])), ("rebate_paid", round(r2["rebate_members_rebate"])), ("their_ggr_gross", round(r2["rebate_members_ggr_gross"])), ("their_ngr", round(r2["rebate_members_ngr"])),
    ("their_pooled_hold_gross_pct", round(r2["rebate_members_hold_gross_pct"], 3)), ("their_pooled_ngr_rate_pct", round(r2["rebate_members_ngr_rate_pct"], 3)), ("their_n_rounds", int(r2["rebate_members_n_rounds"])),
    ("rebate_bands", [collections.OrderedDict([("band", r["rb_band"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("valid_bet", round(fnum(r["valid_bet"]))), ("ggr_gross", round(fnum(r["ggr_gross"]))), ("rebate", round(fnum(r["rebate"]))), ("ngr", round(fnum(r["ngr"]))), ("hold_gross_pct", fnum(r["hold_gross_pct"])), ("ngr_rate_pct", fnum(r["ngr_rate_pct"])), ("n_rounds", int(fnum(r["n_rounds"]))), ("ci95_halfwidth_pp", fnum(r["ci_halfwidth_pp"])), ("n_ngr_negative", int(r["n_ngr_negative"])), ("L5_share", fnum(r["L5_share"]))]) for r in rb2]),
    ("rebate_members_with_negative_ngr", int(r2["rebate_members_ngr_negative_n"])), ("rebate_paid_to_negative_ngr_members", round(r2["rebate_members_ngr_negative_rebate"])),''')
rep('''档位表整体对 L-01 解析线 1.1465% 之距离决定规则层可为；[1%,1.5%) 档之合并 NGR 为负（−488,686）只说明该档位规则本身入不敷出，属档位表设计问题，不构成任何逐员处置依据（P-16）"),''',
'''档位表整体对 L-01 解析线 1.1465% 之距离决定规则层可为。★ 口径纠正（CC-01）：前稿以重复扣减之 ngr 栏称 [1%,1.5%) 档『NGR −488,686』，实为 NGR +125,283（毛利 739,251，退水 613,968，NGR 率 0.185%，CI ±0.61pp）；领退水者毛利率 1.987% 高于平台 1.743%，退水后 NGR 率 1.237% 低于平台 1.682%。任何逐员数字皆非处置依据（P-16）"),''')
rep('''    ("hedge_bands", [collections.OrderedDict([("band", r["hb"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("rebate", round(fnum(r["rebate"]))), ("ggr", round(fnum(r["ggr"]))), ("hold_pct", fnum(r["hold_pct"])), ("ngr", round(fnum(r["ngr"])))]) for r in hedge]),''',
'''    ("hedge_bands", [collections.OrderedDict([("band", r["hb"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("ggr_gross", round(fnum(r["ggr_gross"]))), ("rebate", round(fnum(r["rebate"]))), ("ngr", round(fnum(r["ngr"]))), ("hold_gross_pct", fnum(r["hold_gross_pct"])), ("ngr_rate_pct", fnum(r["ngr_rate_pct"])), ("n_rounds", int(fnum(r["n_rounds"]))), ("ci95_halfwidth_pp", fnum(r["ci_pp"]))]) for r in hedge2]),''')
rep('''    ("verdict", "观察：各对冲档之合并 hold（1.48%~2.17%）与平台 1.68% 同量级，退水合计 9.6 万；本窗未观测到对冲行为侵蚀 hold 之经济量，与 L-01 解析线 1.1465% 之结构性结论一致。转移型对打（chip dumping）不在此度量内；本条不构成判定（P-17）"), ("evidence_ladder", "E1")]),''',
'''    ("verdict", "观察（毛利口径）：各对冲档合并 hold 1.48%~2.17%，与平台毛利率 1.743% 同量级；[20%,50%) 档 1.543% ± 0.246pp 之下界低于平台，故『不低于平台』不成立，只能说『未观测到系统性侵蚀』。退水合计 9.6 万。转移型对打（chip dumping）不在此度量内；本条不构成判定（P-17）"), ("evidence_ladder", "E1")]),
 collections.OrderedDict([("id", "LM-06"), ("lever", "人工标记／种子会员之经济对照（S01.人工标记史 · K01b_seed_manual）"), ("usage", "PROFILE_ONLY · 描述性对照；标记系人工处置史，非因果"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),
    ("cohorts", [collections.OrderedDict([("cohort", r["cohort"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("ggr_gross", round(fnum(r["ggr_gross"]))), ("ngr", round(fnum(r["ngr"]))), ("rebate", round(fnum(r["rebate"]))), ("hold_gross_pct", fnum(r["hold_gross_pct"])), ("ngr_rate_pct", fnum(r["ngr_rate_pct"])), ("n_rounds", int(fnum(r["n_rounds"]))), ("ci95_halfwidth_pp", fnum(r["ci_pp"]))]) for r in seed2]),
    ("note", "127 名人工标记会员毛利率 1.108% ± 0.230pp，低于未标记者 1.752%；K01b 125 名种子中 124 名见于 S01（1.069%）。K01_risk_feature_matrix 之 is_seed 恒 0 系该件构建缺陷，非数据不存在（EG-08 改判 MEASURED）"), ("evidence_ladder", "E1")]),''')

# ---- treatment section: PI01 x typology, bootstrap CI, ledger-wide pre/post ----
rep('''    ("population_reconciliation", [''',
'''    ("pooled_all_treated_bootstrap_ci95_of_sum_d_revenue", [round(r2["pi01_d_revenue_ci_lo"]), round(r2["pi01_d_revenue_ci_hi"])]),
    ("pooled_all_treated_exposure_note", "n_post 之 P10/P25/P50/P75/P90 = 0/0/0/663.5/5,533.5；post 天数 0/0/0/4/19 —— 半数以上处置后无暴露，ΣΔGGR 之自助 95% 区间含 0"),
    ("pi01_by_typology_markers", [collections.OrderedDict([("treatment_field", r["treat_field"]), ("count", int(r["n"])), ("in_S01", int(r["in_S01"])), ("marked_人工标记史", int(r["marked"])), ("hedge_rate_ge_20pct", int(r["hedge_ge20"])), ("shared_ip_n_member_eff_ge_10", int(r["shared_ip_ge10"])), ("evidence_L5", int(r["L5"])), ("evidence_L1_L4", int(r["L1_L4"])), ("sum_d_revenue", round(fnum(r["sum_d_revenue"])))]) for r in xt]),
    ("ledger_wide_pre_post_P12c", collections.OrderedDict([
        ("method", "TL10 台账 8,525 事件 × P12c_member_daily_pnl（uid×dt，day_stake/day_pnl；day_pnl 系 bet17 口径含退水，故 ggr 列为 NGR 口径）：pre = 事件日前全部日，post = 事件日后全部日；不归因"),
        ("coverage", collections.OrderedDict([("tl10_members", int(r2["tl10_members"])), ("tl10_members_in_P12c", int(r2["tl10_members_in_P12c"])), ("tl14_members", 484), ("tl14_members_in_P12c", int(r2["tl14_members_in_P12c"])), ("note", "P12c 只覆盖 92,412 名会员（R01 宇宙），故 1,249 名台账会员不可测；覆盖率登记为事实，非缺口填充")])),
        ("by_field", [collections.OrderedDict([("field", r["field_grp"]), ("events", int(r["events"])), ("members", int(r["members"])), ("with_pre_and_post", int(r["with_both"])), ("stake_pre", round(fnum(r["stake_pre"]))), ("stake_post", round(fnum(r["stake_post"]))), ("ngr_pre", round(fnum(r["ggr_pre"]))), ("ngr_post", round(fnum(r["ggr_post"]))), ("ngr_rate_pre_pct", fnum(r["hold_pre_pct"])), ("ngr_rate_post_pct", fnum(r["hold_post_pct"])), ("d_ngr", round(fnum(r["d_ggr"])))]) for r in lp if int(r["events"]) >= 4]),
        ("tl14_by_direction", [collections.OrderedDict([("direction", r["direction"]), ("events", int(r["events"])), ("members", int(r["members"])), ("with_pre_and_post", int(r["with_both"])), ("stake_pre", round(fnum(r["stake_pre"]))), ("stake_post", round(fnum(r["stake_post"]))), ("ngr_pre", round(fnum(r["ggr_pre"]))), ("ngr_post", round(fnum(r["ggr_post"]))), ("ngr_rate_pre_pct", fnum(r["hold_pre_pct"])), ("ngr_rate_post_pct", fnum(r["hold_post_pct"])), ("d_ngr", round(fnum(r["d_ggr"])))]) for r in l14]),
        ("caveat", "pre／post 窗长不等（post 本金远大于 pre 者系处置早、余期长），率可比、额不可比；回归均值与幸存者偏差未除；P-20 禁读作效应")])),
    ("population_reconciliation", [''')
rep('''        ("nature", "PRE_POST_DESCRIPTIVE · 非效应估计（P-20）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),''',
'''        ("nature", "PRE_POST_DESCRIPTIVE · 非效应估计（P-20）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"), ("revenue_basis", "PI01/PI02 之 revenue 系毛利 GGR（Σ = 234,152,958 与 DX05 相符）"),''')

# ---- semantics ruling: CC-01 rows ----
rep(''' dict(column="ngr", current="-e.net - e.rebate", meaning="GGR − 退水（bet16）", ruling="E5 净额层之会员级真值（OK 件内）；广播件内为平台常量"),''',
''' dict(column="profit（六层块）", current="ROUND(-e.net,4)，e.net = bet17/bet11", meaning="★CC-01：bet17 已含退水 ⇒ profit = GGR − 退水 = NGR（T03 逐行 net_pnl == game_pnl + rebate 100%；DX05 product 101 ggr 234,152,957 = Σprofit + Σrebate_cost）", ruling="profit 即 NGR；总包头注『profit = 平台牌桌毛赢』与实况相悖，须改注"),
 dict(column="ngr（六层块）", current="-e.net - e.rebate", meaning="GGR − 2×退水（退水重复扣减）", ruling="DEPRECATED_DOUBLE_DEDUCTION：不得作 NGR 用；NGR 取 profit 栏"),
 dict(column="ggr_gross（本册派生）", current="profit + rebate_cost = −游戏输赢贡献（M02）", meaning="毛利 GGR", ruling="平台毛利之唯一口径；hold_gross = ggr_gross/stake = 1.7427%（洗码口径 1.9349%）"),''')
rep(''' dict(column="hold_rate", current="-e.net/e.stake", meaning="平台毛利率 = −roi（本金口径）", ruling="率型：须并读 evidence_rate 与 hold_ci_halfwidth_approx"),''',
''' dict(column="hold_rate", current="-e.net/e.stake", meaning="★CC-01：系 NGR 率（bet17 口径），非毛利率", ruling="率型：须并读 evidence_rate 与 hold_ci_halfwidth_approx；对外须标『NGR 率』"),
 dict(column="roi（六层块）", current="e.net/e.stake", meaning="会员净回报率，bet17 口径（含退水），= −hold_rate", ruling="OPT 总包 128 处定义；ROI>0 非任何类判据（SC-15 §八 锁 4）"),''')

# ---- gaps: EG-04 positions, EG-08 measured, EG-09 corrected, EG-14 scope, EG-15 coverage, EG-16 units ----
rep('''evidence="registry_risk_typology_v1.5.001.csv 列 49–56"''', '''evidence="registry_risk_typology_v1.5.001.csv 新增十六栏居第 41–56 栏；treatment_ids 第 55、capability_dim_ids 第 56"''')
rep('''dict(id="EG-08", gap="K01_risk_feature_matrix 交付件 is_seed 恒 0（120,063 行），人工标记种子对照不可得；K01b_seed_goldip 空档", severity="S2", status="OPEN", unblock="回填 K01b/K01c 125 名种子至 K01；或另出 seed×economics 对照件", evidence="K01_seed_cohort.csv"),''',
'''dict(id="EG-08", gap="K01_risk_feature_matrix 交付件 is_seed 恒 0（120,063 行）系构建缺陷；种子对照已改由 S01.人工标记史（127 人）与 K01b→S01（124/125）实测（LM-06）", severity="S2", status="MEASURED_VIA_S01", unblock="修 K01 之 is_seed 构建；K01b_seed_goldip 空档待回填", evidence="seed_cohort_v2.csv"),''')
rep('''dict(id="EG-09", gap="退水杠杆之分位分档（BIZ L1）在本平台退化：档位聚于 0.8%~0.9%，A/B 段空集，静态节省 ≈ 0；退水总额仅占 GGR 3.64%", severity="S3", status="MEASURED", unblock="改为逐员对 L-01 解析线（1.1465%）之反解，靶向 [1%,1.5%) 档 1,468 人与退水超毛赢 5,876 人", evidence="L1_segments.csv；S01_rebate_bands.csv"),''',
'''dict(id="EG-09", gap="退水杠杆之分位分档（BIZ L1）在本平台退化：档位聚于 0.8%~0.9%，A/B 段空集，静态节省 ≈ 0；退水总额 8,220,756 仅占毛利 3.51%（CC-01 口径）", severity="S3", status="MEASURED", unblock="规则层：档位表整体对 L-01 解析线 1.1465% 之距离；禁逐员靶向（P-16）", evidence="L1_segments.csv；S01_rebate_bands_v2.csv"),''')
rep(''' dict(id="EG-11", gap="R03b_player_dealer_daily_b1_to_b8.csv''',
''' dict(id="EG-14", gap="范围边界：一切会员级经济量皆为百家乐（bet02='101'）单产品；DX05 实测其他七产品本金 4,900,008,008、毛利 130,751,499（＝百家乐毛利 55.8%）不入任何会员级经济表；member×product 粒度件缺", severity="S2", status="BLOCKED_UPSTREAM", unblock="出 member×bet02 粒度交付件；本册所有会员级数字须标『百家乐口径』", evidence="DX05_product_panorama.csv 八行"),
 dict(id="EG-15", gap="台账级处置前后覆盖有限：TL10 1,497 名会员中仅 248 名见于 P12c（uid×dt 面板只覆盖 R01 宇宙 92,412 人）；TL14 484 名中 114 名", severity="S2", status="MEASURED_PARTIAL", unblock="出全宇宙 member×dt 面板（T02_daily_roi 之 1,160,259 行亦只覆盖同宇宙）", evidence="ledger_prepost_by_field.csv"),
 dict(id="EG-16", gap="自有货币栏单位／范围未对账：E02 之 rebate/commission 合计 14.9B/166.8B ≫ 平台退水 8.2M；DICT_01a／QSB_01a／QSB_01c／VB_* 之 stake 合计 676.9B 系全产品全库口径；I_ip_player／R03 之 *_all 栏为会员总额逐行广播", severity="S2", status="MEASURED", unblock="逐件登记单位与范围；T-08 主表 E02 降 BLOCKED_UNITS", evidence="own_money_reconciliation.csv（14/51 件不可对账）"),
 dict(id="EG-11", gap="R03b_player_dealer_daily_b1_to_b8.csv''')

# ---- inventory census crosswalk + derivation text ----
rep('''        ("econ_block_status_census", dict(cnt_verd)), ("economic_admissibility_census", dict(cnt_adm)),''',
'''        ("econ_block_status_census", dict(cnt_verd)), ("economic_admissibility_census", dict(cnt_adm)),
        ("census_x_pack_credibility_crosswalk", (lambda: (lambda C: [collections.OrderedDict([("econ_block_status", k[0]), ("pack_credibility", k[1]), ("count", v)]) for k, v in sorted(C.items())])(collections.Counter((i["econ_block_status"], i["pack_credibility"]) for i in inv)))()),
        ("units_reconciliation_method", "对每一自有货币栏求和并对平台总额比对（本金 13.44B、毛利 234.2M、退水 8.2M）；逾 3× 本金者判 EXCEEDS，同族量级内者判 PLAUSIBLE，其余 CHECK；见 own_money_reconciliation.csv"),''')
rep('''("total", 132), ("present_on_disk", sum(1 for i in inv if i["present"]))''', '''("total", 132), ("registered_plus_partial", 133), ("present_on_disk", sum(1 for i in inv if i["present"]))''')

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("round-2 patch applied")
