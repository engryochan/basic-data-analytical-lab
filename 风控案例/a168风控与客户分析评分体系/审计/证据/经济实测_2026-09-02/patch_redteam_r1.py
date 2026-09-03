# -*- coding: utf-8 -*-
"""Red-team round-1 corrections to gen_registry_v1_5_002.py (P-15/P-16/P-17/P-18/P-20 compliance, semantics, structure)."""
p = "gen_registry_v1_5_002.py"
s = open(p, encoding="utf-8").read()
def rep(old, new, cnt=1):
    global s
    assert old in s, "MISSING: " + old[:90]
    s = s.replace(old, new, cnt)

# 13. MONEY regex: exclude counts/ratios, add vb/amount tokens
rep('MONEY = re.compile(r"(^|_)(stake|valid_?bet|validbet|game_pnl|net_pnl|pnl|profit|ggr|ngr|revenue|rebate|commission|margin|residual|house_pnl|player_pnl|saving|cost)(_|$)|流水贡献|游戏输赢贡献|退水支出|在桌洗码量|桌面输赢|洗码量|输赢", re.I)',
    'MONEY = re.compile(r"(^|_)(stake|valid_?bet|validbet|vb|amount|amt|payout|game_pnl|net_pnl|pnl|profit|ggr|ngr|revenue|rebate|commission|margin|residual|house_pnl|player_pnl|saving|cost)(_|$)|流水贡献|游戏输赢贡献|退水支出|在桌洗码量|桌面输赢|洗码量|输赢", re.I)\n'
    'NOT_MONEY = re.compile(r"^(n_|nd_|cnt_|num_|pct_|share_|ratio_)|(_rate|_share|_cv|_pct|_ratio|_entropy|_p\\d+_p\\d+|_p\\d+|_dep|_len|_seq|_status|_flag|_id|_date|_time)$|_cv_|multiple", re.I)')
rep('    own_money  = [c for c in own_native if MONEY.search(c)]',
    '    own_money  = [c for c in own_native if MONEY.search(c) and not NOT_MONEY.search(c)]')

# 13b. MIXED refinement -> CONSTANT_WITH_NA
rep('''    blk = v.get("census_verdict", "NO_BLOCK" if present else "FILE_ABSENT")
    if present and rows == 1 and blk == "PER_ROW": blk = "SINGLE_ROW_BROADCAST"''',
'''    blk = v.get("census_verdict", "NO_BLOCK" if present else "FILE_ABSENT")
    if present and rows == 1 and blk == "PER_ROW": blk = "SINGLE_ROW_BROADCAST"
    if blk == "MIXED":
        _cols = {c["column"]: c for c in census if c["table"] == f}
        _money = [_cols[k] for k in ("stake","profit","rebate_cost","ngr","net_margin_bet23_formal_canonical","hold_rate") if k in _cols]
        if _money and all(x["status"] in ("CONSTANT_BROADCAST","EMPTY") for x in _money) and int(_cols.get("economic_value",{}).get("n_distinct",99)) <= 2: blk = "CONSTANT_WITH_NA"''')

# 10. T-03 deliverables: PROFILE_ONLY_P18
T03_FILES = '("R01_late_shoe.csv","R01_late_shoe_w2.csv","P13_personal_entry.csv","S_player_tail.csv","X_combo.csv","D03S_daily_roi_diff.csv")'
rep('''    cnt_verd[blk] += 1; cnt_adm[adm] += 1''',
'''    if f in %s and adm == "ADMISSIBLE_AT_OWN_GRAIN": adm = "PROFILE_ONLY_P18"
    cnt_verd[blk] += 1; cnt_adm[adm] += 1''' % T03_FILES)
rep('''        ("economic_admissibility", adm),''',
'''        ("economic_admissibility", adm), ("p18_guard", f in %s),''' % T03_FILES)

# 3/9. treatment section
rep('''    te_items.append(collections.OrderedDict([
        ("treatment_field", tf), ("treatment_name", {"mem015": "限额 LIMIT (T3)", "mem016": "账户启停 ENABLE (T3/A12)", "mem017": "下注权限 CANBET (A12)"}[tf]),''',
'''    te_items.append(collections.OrderedDict([
        ("id", f"TE-{tf}"), ("treatment_field", tf), ("field_meaning_from_ledger", {"mem015": "限额（新版限額 mem015；TL14 limit 事件同源）", "mem016": "账户启停 enable", "mem017": "下注权限 canbet"}[tf]),
        ("provisional_treatment_mapping", {"mem015": "T3 LIMIT / A01", "mem016": "A12 Exit/Restriction", "mem017": "A12 Exit/Restriction"}[tf]), ("mapping_status", "PROVISIONAL_FIELD_TO_TREATMENT（treatment_status.S3 OPEN，非已定义之 treatment）"),
        ("nature", "PRE_POST_DESCRIPTIVE · 非效应估计（P-20）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),''')
rep('''        ("business_lost_stake_pre_of_no_exposure", round(sum(fnum(r["stake_pre"]) or 0 for r in noexp))),
        ("business_lost_hold_pre_pct_of_no_exposure", round(-100 * sum((fnum(r["stake_pre"]) or 0) * (fnum(r["roi_pre"]) or 0) for r in noexp) / sum(fnum(r["stake_pre"]) or 0 for r in noexp), 3) if noexp and sum(fnum(r["stake_pre"]) or 0 for r in noexp) else None),
    ]))''',
'''        ("stake_pre_of_no_post_exposure", round(sum(fnum(r["stake_pre"]) or 0 for r in noexp))),
        ("hold_pre_pct_of_no_post_exposure", round(-100 * sum((fnum(r["stake_pre"]) or 0) * (fnum(r["roi_pre"]) or 0) for r in noexp) / sum(fnum(r["stake_pre"]) or 0 for r in noexp), 3) if noexp and sum(fnum(r["stake_pre"]) or 0 for r in noexp) else None),
        ("attribution", "NONE — post 期零投注与 hold 变动不归因于处置（S4 OUTCOME LINKAGE OPEN）"),
    ]))''')
rep('''pi02_rows = [collections.OrderedDict([("cohort", r["cohort"]), ("phase", r["phase"]), ("n_members", int(fnum(r["n_members"]))), ("sum_stake", round(fnum(r["sum_stake"]))), ("sum_revenue", round(fnum(r["sum_revenue"]))), ("hold_pct", round(fnum(r["hold_pct"]), 4)), ("revenue_per_member", round(fnum(r["revenue_per_member"]), 2))]) for r in pi02]''',
'''pi02_rows = [collections.OrderedDict([("cohort", r["cohort"]), ("phase", r["phase"]), ("n_members", int(fnum(r["n_members"]))), ("sum_stake", round(fnum(r["sum_stake"]))), ("sum_validbet", round(fnum(r["sum_validbet"]))), ("sum_revenue", round(fnum(r["sum_revenue"]))), ("hold_validbet_pct", round(fnum(r["hold_pct"]), 4)), ("hold_stake_pct", round(100 * fnum(r["sum_revenue"]) / fnum(r["sum_stake"]), 4)), ("revenue_per_member", round(fnum(r["revenue_per_member"]), 2)), ("denominator_note", "交付件 hold_pct 之分母为 valid_bet（非本金）；本册另算 hold_stake_pct 以合 SC-15 R4-3")]) for r in pi02]''')
rep('''treat_section = collections.OrderedDict([
    ("iron_caveats", [''',
'''treat_section = collections.OrderedDict([
    ("nature", "PRE_POST_DESCRIPTIVE_ONLY：处置前后之经济量对照登记；非处置效应估计（P-20 BLOCKED until S3∧S4 CLOSED）；非处置名单（P-16）"),
    ("iron_caveats", [''')
rep('''("d_hold_positive", f"{sum(1 for r in both_all if fnum(r['d_hold_pct']) > 0)}/{len(both_all)}"), ("sign_test_p", 0.000112), ("sum_d_revenue", round(sum(fnum(r["d_revenue"]) or 0 for r in pi01))), ("n_stopped_betting_post", sum(1 for r in pi01 if grp(r) == "NO_EXPOSURE")), ("stake_pre_of_stopped", round(sum(fnum(r["stake_pre"]) or 0 for r in pi01 if grp(r) == "NO_EXPOSURE")))])),''',
'''("d_hold_positive", f"{sum(1 for r in both_all if fnum(r['d_hold_pct']) > 0)}/{len(both_all)}"), ("inference", "NOT_RUN — 配对检验属处置效应估计，P-20 BLOCKED；只登计数"), ("sum_d_revenue", round(sum(fnum(r["d_revenue"]) or 0 for r in pi01))), ("n_no_post_exposure", sum(1 for r in pi01 if grp(r) == "NO_EXPOSURE")), ("stake_pre_of_no_post_exposure", round(sum(fnum(r["stake_pre"]) or 0 for r in pi01 if grp(r) == "NO_EXPOSURE")))])),
    ("population_reconciliation", [{"definition": "PI01 被处置会员（member×treat_time）", "n": 186}, {"definition": "PI01 处置前有注单", "n": 167}, {"definition": "PI01 处置后有注单", "n": 90}, {"definition": "PI01 前后皆有注单（可比）", "n": 71}, {"definition": "PI01 处置后零投注", "n": 96}, {"definition": "PI01 处置前无注单", "n": 19}, {"definition": "PI02 TREATED PRE / POST 人数", "n": "167 / 90"}, {"definition": "TL14 限红事件 / 会员", "n": "568 / 484"}, {"definition": "TL11 处置节 / 会员", "n": "315 / 154"}, {"definition": "TL10 台账行 / 会员", "n": "8,589 / 1,497"}, {"definition": "registry.window.universe_members（OQ-04 未闭）", "n": 721190}, {"definition": "S01 逐员行数", "n": 723442}]),''')
rep('''("note", "限红档以 TIGHTEN 为主（416/568），中位数减半；释放 97 件")''',
'''("note", "限红档以 TIGHTEN 为主（416/568），中位数减半；RELEASE 97 件、FLAT 52 件 —— 父版 policies[T3].ledger_source『方向仅 TIGHTEN，无 LOOSEN 样本』与 §PIT-01『direction=TIGHTEN』据此撤回，见 retraction_register W-82")''')
rep('''    ("treatment_ids_measured", ["T3 LIMIT（mem015/TL14）", "A12 Exit/Restriction（mem016 启停 · mem017 下注权限）"]),''',
'''    ("fields_with_pre_post_data", ["mem015（临时映射 T3/A01）", "mem016 · mem017（临时映射 A12）"]),''')

# 1/11/2/8. levers
rep('''collections.OrderedDict([("id", "LM-05"), ("lever", "平台净利之会员集中度与损益桶（S01 action_priority）"), ("treatment_id", "T1/T4"), ("actions", ["A06"]),''',
'''collections.OrderedDict([("id", "LM-05"), ("lever", "平台净额之会员集中度与总包 action_priority 桶之分布（S01）"), ("usage", "PROFILE_ONLY · 桶系总包以全窗百分位与 n<30 手写门槛所定（P-15／P-06 疑违），本册只登记分布，禁据以处置（P-16）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),''')
rep('''    ("note", "A 桶 34,990 人合计净付 97.8M，惟 P-16 禁以实现输赢符号定罚；D 桶 69,269 人贡献 278M 为留存优先对象（T1 PROTECT）"), ("evidence_ladder", "E1")]),''',
'''    ("note", "A 桶 34,990 人合计净额 −97.8M、D 桶 69,269 人 +278M：系实现输赢之全窗百分位切分，P-16 禁以之定罚、P-15 禁以之定赏罚线；此处仅为经济暴露之分布描述"), ("evidence_ladder", "E1")]),''')
rep('''collections.OrderedDict([("id", "LM-04"), ("lever", "代理线净贡献（S03_agent_score，4,191 代理）"), ("treatment_id", "T5"), ("actions", ["A02","A11"]),''',
'''collections.OrderedDict([("id", "LM-04"), ("lever", "代理线净贡献分布（S03_agent_score，4,191 代理）"), ("usage", "PROFILE_ONLY · 禁依 NGR 符号对代理施以 T5/A02（P-16 不限于会员）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),''')
rep('''collections.OrderedDict([("id", "LM-01"), ("lever", "L-01 退水档位重定价（BIZ_三杠杆 L1 之离线复算，S01 逐员）"), ("treatment_id", "T11"), ("actions", ["A05"]),''',
'''collections.OrderedDict([("id", "LM-01"), ("lever", "L-01 退水档位（规则杠杆）之经济量登记（BIZ_三杠杆 L1 之离线复算，S01 逐员）"), ("treatment_id", "T11"), ("actions", ["A05"]), ("usage", "规则层（改档位表）之输入；逐员统计只作分布描述，禁作处置名单（P-16）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"), ("cut_points_provenance", "0.5%／1%／1.5% 为描述用分桶，非登记阈值；L-01 解析线 1.1465% 为登记值"),''')
rep('''可定价之真靶为 [1%,1.5%) 档 1,468 人（NGR −488,686）与退水超毛赢之 5,876 人（退水 3,371,447）——须按 L-01 解析线逐员反解，非普适降档"),''',
'''档位表整体对 L-01 解析线 1.1465% 之距离决定规则层可为；[1%,1.5%) 档之合并 NGR 为负（−488,686）只说明该档位规则本身入不敷出，属档位表设计问题，不构成任何逐员处置依据（P-16）"),''')
rep('''    ("verdict", "高对冲会员之 hold 1.54%~2.17% 不低于平台 1.68%，退水仅 9.6 万；套利型对打在本平台无经济侵蚀（与 L-01 解析线 1.1465% 结论一致）。转移型对打（chip dumping）不在此度量内"), ("evidence_ladder", "E1")]),''',
'''    ("cut_points_provenance", "5%／20%／50% 为描述用分桶，非登记阈值；hedge_rate 之 threshold_status 仍 PENDING_INVERSE（T-05）"), ("usage", "DESCRIPTIVE_ONLY"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),
    ("verdict", "观察：各对冲档之合并 hold（1.48%~2.17%）与平台 1.68% 同量级，退水合计 9.6 万；本窗未观测到对冲行为侵蚀 hold 之经济量，与 L-01 解析线 1.1465% 之结构性结论一致。转移型对打（chip dumping）不在此度量内；本条不构成判定（P-17）"), ("evidence_ladder", "E1")]),''')
rep('''collections.OrderedDict([("id", "LM-03"), ("lever", "L-02 注型 edge 向量（QSB_02c 六族 μ0）"), ("treatment_id", "T12"), ("actions", ["A03"]),''',
'''collections.OrderedDict([("id", "LM-03"), ("lever", "L-02 注型 edge 向量（QSB_02c 六族 μ0）"), ("treatment_id", "T12"), ("actions", ["A03"]), ("usage", "规则层（产品／赔付）之输入"),''')

# platform accounting tags
rep('''    ("net_margin_bet23_formal", round(lev["platform_net_margin_bet23"])),''',
'''    ("net_margin_bet23_formal", round(lev["platform_net_margin_bet23"])), ("net_margin_status", "ORDERING_ONLY（AG-03 UNRESOLVED；agent_cost 候选 B 未裁，绝对额不得对外）"), ("implied_agent_cost_candidate_B", round(lev["platform_ngr"] - lev["platform_net_margin_bet23"])),''')
rep('''    ("action_priority_buckets", [collections.OrderedDict([("bucket", r["action_priority"]), ("n", int(r["n"])), ("sum_net_margin", round(fnum(r["sum_net_margin"]))), ("sum_stake", round(fnum(r["sum_stake"])))]) for r in ap]),''',
'''    ("action_priority_buckets_status", "PROFILE_ONLY · 总包桶名系全窗百分位 ＋ n_rounds<30 手写门槛（P-15／P-06 疑违）；本册只登记分布，禁据以处置（P-16）"),
    ("action_priority_buckets", [collections.OrderedDict([("bucket", r["action_priority"]), ("n", int(r["n"])), ("sum_net_margin_ordering_only", round(fnum(r["sum_net_margin"]))), ("sum_ngr", round(fnum(r["sum_ngr"]))), ("sum_stake", round(fnum(r["sum_stake"])))]) for r in ap]),''')

# 4. gate states
rep('''    if t == "T-03": gate = "FATAL_PROFILE_ONLY"; why = "T-03 已四重证伪；经济列只得作画像，不得作触发（P-18）"''',
'''    if t == "T-03": gate = "FATAL_PROFILE_ONLY"; why = "T-03 已四重证伪；经济列只得作画像，不得作触发（P-18）；E4/E5 于本类 NOT_APPLICABLE"''')
rep('''    elif pi and pi["economic_admissibility"] == "ADMISSIBLE_AT_OWN_GRAIN": gate = "PASS"; why''',
'''    elif pi and pi["economic_admissibility"] in ("ADMISSIBLE_AT_OWN_GRAIN","PROFILE_ONLY_P18"): gate = "E1_E5_COMPUTABLE_AT_GRAIN"; why''')
rep('''    elif money: gate = "PASS_OWN_GRAIN_ONLY"; why''',
'''    elif money: gate = "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY"; why''')
rep('''        ("E4_E5_rebate_cost_available", True), ("E4_E5_note",''',
'''        ("gate_meaning", "可算性闸，≠ admit_to_risk_decision，≠ SC-15 §四 之『准入商业决策』；父版 blocker_state／admit 字段一字未动"),
        ("E4_E5_rebate_cost_available", (t != "T-03")), ("E4_E5_note",''')
rep('''("states", ["PASS", "PASS_OWN_GRAIN_ONLY", "BLOCKED_GRAIN", "BLOCKED_UPSTREAM", "BLOCKED_UPSTREAM_FILE_MISSING", "FATAL_PROFILE_ONLY"]), ("rule", "SC-15 §四 三态扩为五态：PASS_OWN_GRAIN_ONLY 谓六层块不可信而自有货币列可算；BLOCKED_GRAIN 谓主表粒度无货币列")''',
'''("states", ["E1_E5_COMPUTABLE_AT_GRAIN", "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY", "BLOCKED_GRAIN", "BLOCKED_UPSTREAM", "BLOCKED_UPSTREAM_FILE_MISSING", "FATAL_PROFILE_ONLY", "FAIL"]), ("rule", "本节系『经济量可算性』登记，非 SC-15 §四 之 economic_metric_gate（其 PASS＝准入商业决策）；SC-15 §四 三态原样保留，本节七态与之正交。E1_E5_COMPUTABLE_AT_GRAIN 谓主表六层可信且逐行有值；E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY 谓六层块不可信而自有货币列可算；BLOCKED_GRAIN 谓主表粒度无货币列；FAIL 保留给『定义与粒度不符或出裸 avg/rate/roi』者（本版无）")''')

# 5. typology block lines + CSV cells left empty
rep('''    return [f"  treatment_ids: [{', '.join(L['treatment_ids'])}]", f"  capability_dim_ids: [{', '.join(L['caps'])}]" if L["caps"] else "  capability_dim_ids: []", f"  economic_linkage_ref: EL-{t}"]''',
'''    return [f"  treatment_ids: [{', '.join(L['treatment_ids'])}]", f"  capability_dim_ids: [{', '.join(L['caps'])}]" if L["caps"] else "  capability_dim_ids: []", "  linkage_status: PROPOSED_BY_AUDIT_2026-09-02 · 待先生裁定 · 非 SSOT", f"  economic_linkage_ref: EL-{t}"]''')
rep('''        if r["treatment_ids"] == "": r["treatment_ids"] = "；".join(L["treatment_ids"]); n_fill += 1
        if r["capability_dim_ids"] == "" and L["caps"]: r["capability_dim_ids"] = "；".join(L["caps"]); n_fill += 1''',
'''        pass   # CSV 投影不承载提案：treatment_ids / capability_dim_ids 待裁后回填（YAML 提案带 linkage_status 标记）''')
rep('''       ["YAML_TYPOLOGY_BLOCKS","T-01..T-15","treatment_ids/capability_dim_ids/economic_linkage_ref","(不存在)",f"+{n_ins} 行（15 块×3）","ADDED","✓ 只增（提案，待裁）"],''',
'''       ["YAML_TYPOLOGY_BLOCKS","T-01..T-15","treatment_ids/capability_dim_ids/linkage_status/economic_linkage_ref","(不存在)",f"+{n_ins} 行（15 块×4）","ADDED","✓ 只增（提案，带 PROPOSED 标记，待裁）"],
       ["YAML_RETRACTION","W-82","retraction_register.entries","(不存在)","+1 条（撤回『限红方向仅 TIGHTEN』）","ADDED","✓ 只增"],''')
rep('''chg.append(["CSV_CELL","66 行","treatment_ids / capability_dim_ids","空","填提案值",f"FILLED×{n_fill}","填空视为加法（待裁）"])''',
'''chg.append(["CSV_CELL","66 行","treatment_ids / capability_dim_ids","空","空（提案不入投影，待裁后回填）","UNCHANGED","CSV 与父版逐字节相同"])''')
rep('''            if cur: out.extend(ins_lines(cur)); n_ins += 3
            cur = m.group(1)
    if i == typ_end and cur: out.extend(ins_lines(cur)); n_ins += 3; cur = None
    out.append(l)''',
'''            if cur: out.extend(ins_lines(cur)); n_ins += 4
            cur = m.group(1)
    if i == typ_end and cur: out.extend(ins_lines(cur)); n_ins += 4; cur = None
    out.append(l)
# W-82 retraction entry appended to the parent's last section (retraction_register.entries)
out.extend(["  - id: W-82", "    claim: 限红处置『方向仅 TIGHTEN，无 LOOSEN 样本』（treatment_status.policy_extension.policies[T3].ledger_source）与 §PIT-01『direction=TIGHTEN』", "    to: null", "    ruling: ★TL14_limit_treatment.csv 实测 568 件：TIGHTEN 416 · RELEASE 97 · FLAT 52 · UNKNOWN_NO_DICT 3（2026-09-02 全量读）；父版原句保留不删，以本条撤回"])''')

# 6. semantics ruling additions
rep(''' dict(column="action_priority", current="A/D/E/Z 由 PERCENT_RANK 与 n_bets/n_rounds<30 定", meaning="决策标签", ruling="仅 OK 件可信；广播件内一律 'X' 或无义"),''',
''' dict(column="action_priority", current="A/D/E/Z 由 PERCENT_RANK 与 n_bets/n_rounds<30 定", meaning="总包决策标签", ruling="仅 OK 件可信；广播件内一律 'X' 或无义。★ n<30 系手写普适门槛（P-06 违例，须以 evidence_rate 反解替代）；A/D 桶以全窗百分位定赏罚线（P-15）且据实现输赢符号（P-16）——本册只登记分布，禁据以处置"),
 dict(column="hold_validbet_pct（PI02 之 hold_pct）", current="sum_revenue / sum_validbet", meaning="洗码量口径之 hold", ruling="与本金口径 hold_rate 分母不同，恒等式 hold≡−roi 不成立（SC-15 R4-3）；禁互代，须另立列名"),
 dict(column="net_margin（绝对额）", current="Σ(−net−rebate−agent_cost)", meaning="含 AG-03 候选 B 之代理成本", ruling="AG-03 UNRESOLVED ⇒ 绝对额 ORDERING_ONLY，不得对外称『真净利』；对外量以 NGR 为准"),''')

# 9. refs
rep('''        ("measured_effect_refs", ["TE-LIMIT-mem015","TE-ENABLE-mem016","TE-CANBET-mem017","TE-PLATFORM-PI02"] if "T3" in L["treatment_ids"] else []),''',
'''        ("related_pre_post_descriptives", ["TE-mem015","TE-mem016","TE-mem017"] if "T3" in L["treatment_ids"] else []), ("related_pre_post_note", "描述性前后对照之索引，非效应通路（S4 OPEN）"),''')

# gaps
rep('''severity="S2", status="SUPERSEDED_FACT", unblock="SC-15 升 v1.1.1 改判 E4/E5 为 PASS_AT_MEMBER_GRAIN；惟 agent_cost 之 AG-03 仍 UNRESOLVED"''',
'''severity="S2", status="PROPOSED_SUPERSESSION · 待裁", unblock="SC-15 升 v1.1.1 改判 E4/E5 于会员粒度可算（≠ 准入商业决策）；惟 agent_cost 之 AG-03 仍 UNRESOLVED"''')

# ---- round-1b (third structural audit) ----
# YAML-1.1 boolean-token keys: no -> seq, n -> count
rep('''        ("no", no), ("file", f), ("present", present), ("successor", successor),''',
'''        ("seq", no), ("file", f), ("present", present), ("successor", successor if successor else ("R03b_player_dealer_daily_b1_to_b8.csv（PARTIAL：前八批 800,000 行，未登记）" if f == "R03b_player_dealer_daily.csv" else None)),''')
s = s.replace('("n", len(sub))', '("count", len(sub))').replace('("n", int(r["n"]))', '("count", int(r["n"]))').replace('("n", len(pi01))', '("count", len(pi01))')
s = s.replace('{"definition": "PI01 被处置会员（member×treat_time）", "n": 186}', '{"definition": "PI01 被处置会员（member×treat_time）", "count": 186}')
s = s.replace('"n": 167}', '"count": 167}').replace('"n": 90}', '"count": 90}').replace('"n": 71}', '"count": 71}').replace('"n": 96}', '"count": 96}').replace('"n": 19}', '"count": 19}').replace('"n": "167 / 90"}', '"count": "167 / 90"}').replace('"n": "568 / 484"}', '"count": "568 / 484"}').replace('"n": "315 / 154"}', '"count": "315 / 154"}').replace('"n": "8,589 / 1,497"}', '"count": "8,589 / 1,497"}').replace('"n": 721190}', '"count": 721190}').replace('"n": 723442}', '"count": 723442}')
assert '("n",' not in s and '"n":' not in s, "remaining bare n keys: " + str([m.start() for m in __import__('re').finditer(r'\("n",|"n":', s)][:5])
# empty dict inside list-of-dict emitter -> unquoted {}
rep('''                    elif isinstance(v, list):
                        out.append(f"{p}{k}: [{', '.join(yq(x) for x in v)}]" if v else f"{p}{k}: []")
                    else:
                        out.append(f"{p}{k}: {yq(v)}")
                    first = False''',
'''                    elif isinstance(v, list):
                        out.append(f"{p}{k}: [{', '.join(yq(x) for x in v)}]" if v else f"{p}{k}: []")
                    elif isinstance(v, dict):
                        out.append(f"{p}{k}: {{}}")
                    else:
                        out.append(f"{p}{k}: {yq(v)}")
                    first = False''')
# quote issued date
rep('''    ("issued", TODAY), ("parent_identity",''', '''    ("issued", "'" + TODAY + "'"), ("parent_identity",''')
# join-key aliases in header verification
rep('''        kc = [c for c in ("member_id","uid","uid1","uid2","m_a","m_b","bet_ip","ip","dealer_id","agent_id","table_id","dt","bet_date","product_code","bet09_family","rebate_rate","event_date","is_sentinel_dealer","lv1_id") if c in HDR.get(f, set())]''',
'''        kc = [c for c in ("member_id","uid","uid1","uid2","m_a","m_b","mid","player_id","bet_ip","ip","dealer_id","agent_id","table_id","gi011","dt","dt_day","bet_date","ym","bet_month","product_code","bet09","bet_side","bet09_value","bet09_family","rebate_rate","rebate_rate_actual","event_date","action_date","is_sentinel_dealer","lv1_id","scope","grp","subnet_24") if c in HDR.get(f, set())]''')
rep('''("join_columns_verified_in_headers", keys_ok), ("evidence_ladder", "E1")]))''',
'''("join_columns_verified_in_headers", keys_ok), ("join_key_note", "列出者皆经表头核验；别名（bet_side / bet09_value / dt_day / ym / mid / player_id）已纳入核验集"), ("evidence_ladder", "E1")]))''')
# note on grain provenance + uploadable whitelist
rep('''("method", "逐件读表头（own = 非六层块之栏）；六层块逐栏读全量算相异值（econ_census.R）；BROADCAST_CONSTANT = 多行单值"), ("items", inv)])),''',
'''("method", "逐件读表头（own = 非六层块之栏）；六层块逐栏读全量算相异值（econ_census.R）；BROADCAST_CONSTANT = 多行单值；grain 栏原样取自总包模块索引（其『1』『3』等即 GROUP BY 常量，非行数）"), ("items", inv)])),''')
rep('''    ("ruling_required", [''', '''    ("csv_projection_note", "treatment_ids 已在 field_scope_registry.type_level_scalar_uploadable 白名单内，capability_dim_ids 尚未入白名单；故本版 CSV 投影两栏皆留空，待裁后先补白名单再回填"),
    ("ruling_required", [''')
rep(''' dict(id="EG-11", gap="R03b_player_dealer_daily_b1_to_b8.csv''',
''' dict(id="EG-12", gap="R24b 仍 NOT_RUN：P-16 之机检栏 criterion_family=OUTCOME_BASED 于父版 66 判据覆盖 0（VACUOUS），P-17/P-20 未绑定；本版新增之经济量虽逐条标 criterion_family: OUTCOME_BASED，惟 R24b 只扫判据层 CSV", severity="S1", status="OPEN", unblock="N-5 判据语义裁决（T-07 win_rate_all 等改标 OUTCOME_BASED）＋ 校验器 R24b 增扫本册经济节", evidence="verify_dual_result_1_5_002.csv R24b"),
 dict(id="EG-13", gap="父版两处措辞与实测相悖：policies[T3].ledger_source『方向仅 TIGHTEN，无 LOOSEN 样本』、§PIT-01『direction=TIGHTEN』，实测 RELEASE 97 件", severity="S2", status="RETRACTED_BY_W-82", unblock="父版句保留不删，W-82 撤回", evidence="TL14 实测"),
 dict(id="EG-11", gap="R03b_player_dealer_daily_b1_to_b8.csv''')

# upgrade section text
rep('''    ("derivation", "加法升级 · 机器生成（gen_registry_v1_5_002.py）· 父版 3,943 行仅两行版本号改动，其余逐字节保留；typology 块各插入 3 行；末尾追加 9 节"),''',
'''    ("derivation", "加法升级 · 机器生成（gen_registry_v1_5_002.py）· 父版 3,943 行仅两行版本号改动 ＋ 一行 git_anchor 新增，其余逐字节保留；typology 块各插入 4 行（提案带 PROPOSED 标记）；retraction_register 增 W-82；末尾追加 10 节；CSV 投影与父版逐字节相同"),''')
rep('''    ("ruling_required", ["typology_economic_linkage 之 treatment_ids/capability_dim_ids 提案（16 对象）", "economic_value 正名", "SC-15 §四 改判", "E4/E5 于会员粒度 PASS 之宣告", "registry_loader.R .expect 1.5.001 → 1.5.002（一行）"]),''',
'''    ("ruling_required", ["typology_economic_linkage 之 treatment_ids/capability_dim_ids 提案（15 类）—— 裁后方回填 CSV 投影", "economic_value 正名 net_margin_pr_global", "SC-15 §四 之 E4/E5 改判（PROPOSED_SUPERSESSION）", "总包 action_priority 桶（P-15/P-06/P-16 疑违）之去留", "registry_loader.R .expect 1.5.001 → 1.5.002（一行）"]),
    ("prohibition_self_check", ["P-15：本册未设任何赏罚线；总包 A/D 桶只登记分布并标 PROFILE_ONLY", "P-16：本册未据实现输赢符号出任何名单；LM-01/LM-04/LM-05 已去处置绑定", "P-17：无阈值判据一律只出分布与排序；描述用分桶标 cut_points_provenance", "P-18：T-03 六件标 PROFILE_ONLY_P18，E4/E5 NOT_APPLICABLE", "P-20：处置前后只登计数与金额，无配对检验、无归因（inference: NOT_RUN）"]),''')

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("generator patched (red-team round 1)")
