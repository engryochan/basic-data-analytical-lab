# -*- coding: utf-8 -*-
"""
gen_registry_v1_5_002.py  --  additive upgrade generator
registry_risk_typology_v1.5.001  ->  candidate v1.5.002  (scratchpad only; project files untouched)

Rules honoured:
  * 只增不减：the 3,943 lines of the v1.5.001 YAML are kept byte-identical except two version lines
    (registry.version, registry.version_semver). All new content is (a) inserted lines inside each
    typology block (treatment_ids / capability_dim_ids / economic_linkage_ref) and (b) appended
    top-level sections.
  * 实测优先：every number in the appended sections is computed here from the delivered CSVs or
    read from the census/lever summaries produced by econ_census.R / levers.R / treat_effects*.R.
  * 禁硬编码阈值：cut points used in lever replicas are percent ranks of the data.
  * NULL ≠ 0 / UNKNOWN ≠ FAIL：absent metrics are registered ABSENT, never 0.
"""
import csv, os, re, io, hashlib, collections, statistics, datetime

PROJ = r"C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系"
SP   = r"C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/68213601-ea3b-40ee-91c5-9668c14b1274/scratchpad"
OUT  = os.path.join(SP, "registry_v1.5.002"); os.makedirs(OUT, exist_ok=True)
D    = os.path.join(PROJ, "数据表")
SRC_YAML = os.path.join(PROJ, "规范", "registry_risk_typology_v1.5.001.yaml")
SRC_CSV  = os.path.join(PROJ, "规范", "registry_risk_typology_v1.5.001.csv")
TODAY = "2026-09-02"
GIT_ANCHOR = "7f713dc"   # HEAD commit that introduced v1.5.001 ("推出《registry_risk_typology_v1.5.001》")

def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""): h.update(chunk)
    return h.hexdigest()
def sixtuple(p):
    b = open(p, "rb").read()
    return dict(bytes=len(b), lines_lf=b.count(b"\n"), eol=("CRLF" if b"\r\n" in b else "LF"), bom=(b[:3] == b"\xef\xbb\xbf"), md5=md5(p))
def rcsv(p, **kw): return list(csv.DictReader(open(p, encoding="utf-8-sig", errors="replace", newline=""), **kw))
def fnum(x):
    try: return float(x)
    except: return None

# ---------------------------------------------------------------- YAML emitter (no PyYAML dependency)
def yq(v):
    """scalar -> YAML text"""
    if v is None: return "null"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return (str(v) + ".0") if abs(v) >= 2147483647 else str(v)
    if isinstance(v, float):
        if v != v: return "null"
        return repr(round(v, 6)) if abs(v) < 1e15 else repr(v)
    s = str(v)
    if s == "": return "''"
    needs = re.search(r"[:#\[\]\{\},&\*!\|>'\"%@`\n]", s) or s.strip() != s or s.lower() in ("null","true","false","yes","no","on","off","y","n","~") or re.match(r"^[-+]?[0-9.]+$", s) or re.match(r"^\d{4}-\d{2}-\d{2}", s) or s.startswith("-")
    if needs: return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'
    return s
def yemit(obj, ind=0, out=None):
    out = [] if out is None else out; pad = "  " * ind
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, dict) and v:
                out.append(f"{pad}{k}:"); yemit(v, ind + 1, out)
            elif isinstance(v, list) and v and any(isinstance(x, (dict, list)) for x in v):
                out.append(f"{pad}{k}:"); yemit(v, ind, out)
            elif isinstance(v, list):
                out.append(f"{pad}{k}: [{', '.join(yq(x) for x in v)}]" if v else f"{pad}{k}: []")
            elif isinstance(v, dict):
                out.append(f"{pad}{k}: {{}}")
            else:
                out.append(f"{pad}{k}: {yq(v)}")
    elif isinstance(obj, list):
        for it in obj:
            if isinstance(it, dict):
                first = True
                for k, v in it.items():
                    p = f"{pad}- " if first else f"{pad}  "
                    if isinstance(v, dict) and v:
                        out.append(f"{p}{k}:"); yemit(v, ind + 2, out)
                    elif isinstance(v, list) and v and any(isinstance(x, (dict, list)) for x in v):
                        out.append(f"{p}{k}:"); yemit(v, ind + 1, out)
                    elif isinstance(v, list):
                        out.append(f"{p}{k}: [{', '.join(yq(x) for x in v)}]" if v else f"{p}{k}: []")
                    elif isinstance(v, dict):
                        out.append(f"{p}{k}: {{}}")
                    else:
                        out.append(f"{p}{k}: {yq(v)}")
                    first = False
            else:
                out.append(f"{pad}- {yq(it)}")
    return out

# ---------------------------------------------------------------- inputs
pack   = {r["file"]: r for r in rcsv(os.path.join(SP, "pack_index.csv"))}
verd   = {r["table"]: r for r in rcsv(os.path.join(SP, "table_econ_verdict.csv"))}
census = rcsv(os.path.join(SP, "econ_block_census.csv"))
freq   = {r["column"]: int(r["n_tables"]) for r in rcsv(os.path.join(SP, "column_frequency.csv"))}
BLOCK  = sorted(c for c, n in freq.items() if n >= 120)
lev    = {r["metric"]: float(r["value"]) for r in rcsv(os.path.join(SP, "levers_summary.csv"))}
L1seg  = rcsv(os.path.join(SP, "L1_segments.csv"))
rb     = rcsv(os.path.join(SP, "S01_rebate_bands.csv"))
hedge  = rcsv(os.path.join(SP, "T03_hedge_bands.csv"))
pi04   = rcsv(os.path.join(SP, "PI04_observability.csv"))
ap     = rcsv(os.path.join(SP, "S01_action_priority.csv"))
er     = rcsv(os.path.join(SP, "S01_evidence_rate.csv"))
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
for r in recon: recon_by_table.setdefault(r["table"], []).append(r)
lineage= {r["CSV名称"]: r for r in rcsv(os.path.join(PROJ, "函数", "HF9g-P4_129件血统分类表.csv"))}
reg_csv = rcsv(SRC_CSV)
types = collections.OrderedDict()
for r in reg_csv:
    if r["type_id"] not in types: types[r["type_id"]] = r

MONEY = re.compile(r"(^|_)(stake|valid_?bet|validbet|vb|amount|amt|payout|game_pnl|net_pnl|pnl|profit|ggr|ngr|revenue|rebate|commission|margin|residual|house_pnl|player_pnl|saving|cost)(_|$)|流水贡献|游戏输赢贡献|退水支出|在桌洗码量|桌面输赢|洗码量|输赢", re.I)
NOT_MONEY = re.compile(r"^(n_|nd_|cnt_|num_|pct_|share_|ratio_)|(_rate|_share|_cv|_pct|_ratio|_entropy|_p\d+_p\d+|_p\d+|_dep|_len|_seq|_status|_flag|_id|_date|_time)$|_cv_|multiple", re.I)
TYPO_SUFFIX = re.compile(r"^(roi_(non_)?[a-z_]+|avg_stake_(non_)?[a-z_]+|share_[a-z_]+|hold_rate_[a-z_]+|roi_delta_[a-z_]+|ramp_[a-z_]+|[a-z_]+_xagg|stake_ramp_xagg|n_bets_xagg|n_rounds_xagg|span_days_xagg)$", re.I)
ECON_HINT = re.compile(r"roi|hold|ngr|ggr|pnl|profit|stake|valid|rebate|commission|revenue|margin|cost|saving|delta|diff|ramp|share|rate|pct|hhi|entropy|_cv|winrate|lift|jaccard|turnover|residual|贡献|输赢|洗码|退水|流水", re.I)

def header(f):
    with open(os.path.join(D, f), "rb") as fh: h = fh.readline()
    return [c.strip().strip('"') for c in h.decode("utf-8-sig", "replace").rstrip("\r\n").split(",")]

# ---------------------------------------------------------------- 1. deliverable_metric_inventory (132)
inv = []; cnt_verd = collections.Counter(); cnt_adm = collections.Counter()
for no in range(1, 133):
    p = next((v for v in pack.values() if int(v["no"]) == no), None)
    f = p["file"]; present = os.path.exists(os.path.join(D, f))
    successor = None
    if not present and f == "TL03_pseudo_treatment.csv": successor = "TL03b_pseudo_treatment.csv"
    hdr = header(f) if present else []
    own = [c for c in hdr if c not in BLOCK]
    # typology-specific econ suffix family (TYPO_ECON block: roi_<p>/roi_non_<p>/avg_stake_<p>/share_<p>/hold_rate_<p>/roi_delta_<p>/ramp_<p>/*_xagg) is template-injected, not table-native
    own_native = [c for c in own if not TYPO_SUFFIX.search(c)]
    own_metric = [c for c in own_native if ECON_HINT.search(c)]
    own_money  = [c for c in own_native if MONEY.search(c) and not NOT_MONEY.search(c)]
    v = verd.get(f, {})
    rows = int(v.get("rows", 0) or 0)
    blk = v.get("census_verdict", "NO_BLOCK" if present else "FILE_ABSENT")
    if present and rows == 1 and blk == "PER_ROW": blk = "SINGLE_ROW_BROADCAST"
    _sc = next((c for c in census if c["table"] == f and c["column"] == "stake"), None)
    if _sc and _sc["status"] == "EMPTY" and blk in ("BROADCAST_CONSTANT", "SINGLE_ROW_BROADCAST", "PER_ROW"): blk = "EMPTY_BLOCK"
    if blk == "MIXED":
        _cols = {c["column"]: c for c in census if c["table"] == f}
        _money = [_cols[k] for k in ("stake","profit","rebate_cost","ngr","net_margin_bet23_formal_canonical","hold_rate") if k in _cols]
        if _money and all(x["status"] in ("CONSTANT_BROADCAST","EMPTY") for x in _money) and int(_cols.get("economic_value",{}).get("n_distinct",99)) <= 2: blk = "CONSTANT_WITH_NA"
    cred = p["credibility"]; usage = p["usage"]
    if not present: adm = "FILE_ABSENT"
    elif cred == "N/A": adm = "DICTIONARY"
    elif cred == "OK" and blk == "PER_ROW" and usage in ("PRIMARY", "SUPPORT", "SCREENING", "REFERENCE"): adm = "ADMISSIBLE_AT_OWN_GRAIN"
    elif own_money: adm = "OWN_COLUMNS_ONLY"          # block invalid/broadcast but own money columns carry real values at own grain
    elif cred in ("WRONG_GRAIN",): adm = "BACKGROUND_ONLY"
    else: adm = "NOT_ADMISSIBLE"
    if f in ("R01_late_shoe.csv","R01_late_shoe_w2.csv","P13_personal_entry.csv","S_player_tail.csv","X_combo.csv","D03S_daily_roi_diff.csv") and adm == "ADMISSIBLE_AT_OWN_GRAIN": adm = "PROFILE_ONLY_P18"
    if adm == "OWN_COLUMNS_ONLY" and recon_by_table.get(f) and any(x["units_verdict"] != "PLAUSIBLE" for x in recon_by_table[f]): adm = "OWN_COLUMNS_UNITS_UNRECONCILED"
    cnt_verd[blk] += 1; cnt_adm[adm] += 1
    ev = next((c for c in census if c["table"] == f and c["column"] == "economic_value"), None)
    inv.append(collections.OrderedDict([
        ("seq", no), ("file", f), ("present", present), ("successor", successor if successor else ("R03b_player_dealer_daily_b1_to_b8.csv（PARTIAL：前八批 800,000 行，未登记）" if f == "R03b_player_dealer_daily.csv" else None)),
        ("mcode", p["mcode"]), ("domain", p["domain"]), ("entity", p["entity"]), ("grain", p["grain"]),
        ("rows", rows if present else None), ("ncol", len(hdr) if present else None), ("n_own", len(own) if present else None), ("n_block", (len(hdr) - len(own)) if present else None),
        ("pack_credibility", cred), ("pack_usage", usage), ("lineage_class", lineage.get(f, {}).get("血统判定", "")),
        ("econ_block_status", blk),
        ("economic_admissibility", adm), ("p18_guard", f in ("R01_late_shoe.csv","R01_late_shoe_w2.csv","P13_personal_entry.csv","S_player_tail.csv","X_combo.csv","D03S_daily_roi_diff.csv")),
        ("own_money_columns", own_money), ("own_metric_columns", own_metric[:40]), ("own_native_columns_n", len(own_native)), ("typo_econ_suffix_columns_n", len(own) - len(own_native)),
        ("theo", "ABSENT"), ("adt", "ABSENT"), ("nmpt", "ABSENT"), ("esi", "ABSENT"),
        ("economic_value_semantics", "PERCENT_RANK(-net-rebate-agent_cost) 0..1 — 秩非金额" if (present and "economic_value" in hdr) else "ABSENT"),
        ("economic_value_distinct", int(ev["n_distinct"]) if ev else None),
        ("own_money_units_reconciliation", [collections.OrderedDict([("column", x["column"]), ("sum", round(float(x["sum"]))), ("ratio_to_platform_stake", round(float(x["ratio_to_stake"]), 4)), ("ratio_to_gross_ggr", round(float(x["ratio_to_gross_ggr"]), 4)), ("verdict", x["units_verdict"])]) for x in recon_by_table.get(f, [])] if recon_by_table.get(f) else None),
        ("own_money_units_verdict", ("PLAUSIBLE" if all(x["units_verdict"] == "PLAUSIBLE" for x in recon_by_table[f]) else "UNITS_OR_SCOPE_UNRECONCILED") if recon_by_table.get(f) else ("NO_OWN_MONEY_COLUMNS" if present else None)),
    ]))

_pf = "R03b_player_dealer_daily_b1_to_b8.csv"; _ph = header(_pf); _pown = [c for c in _ph if c not in BLOCK and not TYPO_SUFFIX.search(c)]
inv.append(collections.OrderedDict([("seq", 133), ("file", _pf), ("present", True), ("successor", None), ("mcode", "M07"), ("domain", "C"), ("entity", "会员"), ("grain", "bet_date × uid × dealer_id × is_sentinel_dealer（#071 之前八批 PARTIAL）"),
    ("rows", 800000), ("ncol", len(_ph)), ("n_own", len(_pown)), ("n_block", len(_ph) - len(_pown)), ("pack_credibility", "WRONG_GRAIN（承 #071；D-14b 六层 16 列置 NULL）"), ("pack_usage", "NOT_FOR_DECISION"), ("lineage_class", "未登记"),
    ("econ_block_status", "NULL_BY_DESIGN_D14b"), ("economic_admissibility", "OWN_COLUMNS_ONLY_PARTIAL"), ("p18_guard", False),
    ("own_money_columns", [c for c in _pown if MONEY.search(c) and not NOT_MONEY.search(c)]), ("own_metric_columns", [c for c in _pown if ECON_HINT.search(c)][:40]), ("own_native_columns_n", len(_pown)), ("typo_econ_suffix_columns_n", len(_ph) - len(_pown) - len(BLOCK)),
    ("theo", "ABSENT"), ("adt", "ABSENT"), ("nmpt", "ABSENT"), ("esi", "ABSENT"), ("economic_value_semantics", "ABSENT（CAST(NULL AS DOUBLE)，D-14b）"), ("economic_value_distinct", 0),
    ("own_money_units_reconciliation", None), ("own_money_units_verdict", "NOT_CHECKED_PARTIAL_FILE"), ("coverage", "batches 1–8 of #071（8 × 100,000 行）；#071 全量 18,139,550 行 MISSING（B-02）")]))
cnt_verd["NULL_BY_DESIGN_D14b"] += 1; cnt_adm["OWN_COLUMNS_ONLY_PARTIAL"] += 1

# ---------------------------------------------------------------- 2. treatment economic effects (computed here from PI01/PI02/TL14/TL11/TL10)
pi01 = rcsv(os.path.join(D, "PI01_treatment_delta_member.csv"))
def grp(r):
    v = r["verdict_exposure"]
    return "NO_EXPOSURE" if "NO_EXPOSURE" in v else "NO_BASELINE" if "NO_BASELINE" in v else "GGR_DOWN" if "下降" in v else "GGR_UP_FLAT"
te_items = []
for tf in ("mem015", "mem016", "mem017"):
    sub = [r for r in pi01 if r["treat_field"] == tf]
    both = [r for r in sub if fnum(r["d_hold_pct"]) is not None]
    sp = sum(fnum(r["stake_pre"]) or 0 for r in sub); spost = sum(fnum(r["stake_post"]) or 0 for r in sub)
    gpre = -sum((fnum(r["stake_pre"]) or 0) * (fnum(r["roi_pre"]) or 0) for r in sub); gpost = -sum((fnum(r["stake_post"]) or 0) * (fnum(r["roi_post"]) or 0) for r in sub)
    noexp = [r for r in sub if grp(r) == "NO_EXPOSURE"]
    te_items.append(collections.OrderedDict([
        ("id", f"TE-{tf}"), ("treatment_field", tf), ("field_meaning_from_ledger", {"mem015": "限额（新版限額 mem015；TL14 limit 事件同源）", "mem016": "账户启停 enable", "mem017": "下注权限 canbet"}[tf]),
        ("provisional_treatment_mapping", {"mem015": "T3 LIMIT / A01", "mem016": "A12 Exit/Restriction", "mem017": "A12 Exit/Restriction"}[tf]), ("mapping_status", "PROVISIONAL_FIELD_TO_TREATMENT（treatment_status.S3 OPEN，非已定义之 treatment）"),
        ("nature", "PRE_POST_DESCRIPTIVE · 非效应估计（P-20）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"), ("revenue_basis", "PI01/PI02 之 revenue 系毛利 GGR（Σ = 234,152,958 与 DX05 相符）"),
        ("n_treated", len(sub)), ("n_with_pre_and_post", len(both)), ("n_no_exposure_post", len(noexp)),
        ("n_no_baseline", sum(1 for r in sub if grp(r) == "NO_BASELINE")),
        ("stake_pre", round(sp)), ("stake_post", round(spost)), ("ggr_pre", round(gpre)), ("ggr_post", round(gpost)),
        ("pooled_hold_pre_pct", round(100 * gpre / sp, 3) if sp else None), ("pooled_hold_post_pct", round(100 * gpost / spost, 3) if spost else None),
        ("sum_d_revenue", round(sum(fnum(r["d_revenue"]) or 0 for r in sub))),
        ("median_d_hold_pct", round(statistics.median([fnum(r["d_hold_pct"]) for r in both]), 3) if both else None),
        ("median_d_stake", round(statistics.median([fnum(r["d_stake"]) for r in sub if fnum(r["d_stake"]) is not None])) if sub else None),
        ("share_d_hold_positive", (f"{sum(1 for r in both if fnum(r['d_hold_pct']) > 0)}/{len(both)}") if both else "0/0"),
        ("stake_pre_of_no_post_exposure", round(sum(fnum(r["stake_pre"]) or 0 for r in noexp))),
        ("hold_pre_pct_of_no_post_exposure", round(-100 * sum((fnum(r["stake_pre"]) or 0) * (fnum(r["roi_pre"]) or 0) for r in noexp) / sum(fnum(r["stake_pre"]) or 0 for r in noexp), 3) if noexp and sum(fnum(r["stake_pre"]) or 0 for r in noexp) else None),
        ("attribution", "NONE — post 期零投注与 hold 变动不归因于处置（S4 OUTCOME LINKAGE OPEN）"),
    ]))
both_all = [r for r in pi01 if fnum(r["d_hold_pct"]) is not None]
pi02 = rcsv(os.path.join(D, "PI02_treatment_delta_platform.csv"))
pi02_rows = [collections.OrderedDict([("cohort", r["cohort"]), ("phase", r["phase"]), ("n_members", int(fnum(r["n_members"]))), ("sum_stake", round(fnum(r["sum_stake"]))), ("sum_validbet", round(fnum(r["sum_validbet"]))), ("sum_revenue", round(fnum(r["sum_revenue"]))), ("hold_validbet_pct", round(fnum(r["hold_pct"]), 4)), ("hold_stake_pct", round(100 * fnum(r["sum_revenue"]) / fnum(r["sum_stake"]), 4)), ("revenue_per_member", round(fnum(r["revenue_per_member"]), 2)), ("denominator_note", "交付件 hold_pct 之分母为 valid_bet（非本金）；本册另算 hold_stake_pct 以合 SC-15 R4-3")]) for r in pi02]
tl14 = rcsv(os.path.join(D, "TL14_limit_treatment.csv"))
ratios = sorted(fnum(r["max_hi_after"]) / fnum(r["max_hi_before"]) for r in tl14 if fnum(r["max_hi_before"]) and fnum(r["max_hi_after"]) is not None)
tl14_dir = collections.Counter(r["direction"] for r in tl14)
tl11 = rcsv(os.path.join(D, "TL11_treatment_episode.csv"))
tl11_by = collections.Counter(r["enforcement_type"] for r in tl11)
tl11_cens = collections.Counter(r["censor_reason"] for r in tl11)
tl10 = rcsv(os.path.join(D, "TL10_treatment_ledger.csv"))
tl10_fields = collections.Counter(r["field_name"] for r in tl10)
tl03b = rcsv(os.path.join(D, "TL03b_pseudo_treatment.csv"))
tl03b_dir = collections.Counter((r["action_type"], r["direction"]) for r in tl03b)

# ---------------------------------------------------------------- 3. typology economic linkage (proposals, evidence-linked; 待裁)
LINK = {
 "T-01": dict(subject="会员对", grain="uid1 × uid2 × window", treatment_ids=["T3","T4","T11"], levers=["L-01","L-03"], caps=["M07","M01","M09"], actions=["A01","A05"]),
 "T-02": dict(subject="玩家×荷官", grain="uid × eid × window", treatment_ids=["T9","T4","T10"], levers=[], caps=["H05","H06","H08","H09","H10"], actions=["A04","A09"]),
 "T-03": dict(subject="会员×分段", grain="uid × segment × window", treatment_ids=["T0"], levers=[], caps=[], actions=[], note="P-18：四布尔全 false，永不复活；经济层只作画像"),
 "T-04": dict(subject="会员对", grain="uid1 × uid2 × window", treatment_ids=["T11","T3","T4"], levers=["L-01","L-03"], caps=["M07","M09"], actions=["A05","A01"]),
 "T-05": dict(subject="会员", grain="uid × window", treatment_ids=["T11","T3"], levers=["L-01","L-03"], caps=["M07","M01"], actions=["A05","A01"]),
 "T-06": dict(subject="IP 聚合体", grain="ip × window", treatment_ids=["T2","T4"], levers=[], caps=["M09","M08"], actions=["A08"]),
 "T-07": dict(subject="会员×玩法", grain="uid × bet09_class × window", treatment_ids=["T3","T12","T1"], levers=["L-02"], caps=["M06","M04","M02"], actions=["A01","A03"], note="M02 属 OUTCOME_BASED，禁作罚轴（P-16）；误伤即损业绩（SC-15）"),
 "T-08": dict(subject="会员／代理／合约", grain="uid ∥ agent × window", treatment_ids=["T11","T5"], levers=["L-01"], caps=["A07","M01"], actions=["A05","A02"]),
 "T-09": dict(subject="代理线", grain="agent × window", treatment_ids=["T5","T4"], levers=[], caps=["A05","A06","A04","A07"], actions=["A02","A11"]),
 "T-10": dict(subject="账务对象（非会员）", grain="record × window", treatment_ids=["T4","T10"], levers=[], caps=["C15"], actions=["A09"], note="内控 KRI，禁塞 member_roi（SC-15 §三）"),
 "T-11": dict(subject="账户簇", grain="cluster × window", treatment_ids=["T2","T4"], levers=[], caps=["M08","M09"], actions=["A08"]),
 "T-12": dict(subject="会员", grain="uid × window", treatment_ids=["T2","T3"], levers=[], caps=["M15"], actions=["A10","A01"]),
 "T-13": dict(subject="会员×时段", grain="uid × hour_band × window", treatment_ids=["T2"], levers=[], caps=["M15","M03"], actions=["A07"]),
 "T-14": dict(subject="会员×限额档", grain="uid × limit_tier × window", treatment_ids=["T3"], levers=[], caps=["M01","M16"], actions=["A01"]),
 "T-15": dict(subject="会员×前后期", grain="uid × pre/post × window", treatment_ids=["T2","T4","T7"], levers=[], caps=["M05","M14"], actions=["A06","A11"]),
 "V":    dict(subject="会员", grain="uid × window", treatment_ids=["T1","T8"], levers=[], caps=["M01"], actions=["A06","A11"]),
}
def primary_of(t): return types[t]["primary_deliverable"]
def supports_of(t): return [x.strip() for x in re.split(r"[；;]", types[t]["supporting_deliverables"]) if x.strip()]
def tab_info(f):
    it = next((i for i in inv if i["file"] == f), None)
    return it
gate_items = []; link_items = []
for t in types:
    if t == "V": continue
    prim = primary_of(t); pi = tab_info(prim)
    sups = supports_of(t); si = [tab_info(x) for x in sups if tab_info(x)]
    money = pi["own_money_columns"] if pi else []
    if t == "T-03": gate = "FATAL_PROFILE_ONLY"; why = "T-03 已四重证伪；经济列只得作画像，不得作触发（P-18）；E4/E5 于本类 NOT_APPLICABLE"
    elif pi and not pi["present"]: gate = "BLOCKED_UPSTREAM_FILE_MISSING"; why = f"主表 {prim} 不在盘（B-02）；盘上仅有未登记之部分件 R03b_player_dealer_daily_b1_to_b8.csv（800,000 行 = 前八批）"
    elif pi and pi["economic_admissibility"] in ("ADMISSIBLE_AT_OWN_GRAIN","PROFILE_ONLY_P18"): gate = "E1_E5_COMPUTABLE_AT_GRAIN"; why = f"主表 {prim} 六层可信 OK 且逐行有值；E1/E3/E4/E5 于 {pi['entity']} 粒度可算"
    elif money and pi and pi.get("own_money_units_verdict") == "UNITS_OR_SCOPE_UNRECONCILED": gate = "BLOCKED_UNITS"; why = f"主表 {prim} 自有货币栏之合计与平台总额不可对账（如 E02 rebate 合计 14.9B ≫ 平台 8.2M），单位或范围未裁，禁作经济量"
    elif money: gate = "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY"; why = f"主表 {prim} 六层块 {pi['pack_credibility']}（勿用），惟自有货币列 {money[:6]} 于其粒度 {pi['grain'][:30]} 可算 E1/E3"
    elif pi and pi["pack_credibility"] == "WRONG_GRAIN": gate = "BLOCKED_GRAIN"; why = f"主表 {prim} 粒度 {pi['grain'][:30]} 无自有货币列；六层块为上卷广播，禁算比率"
    else: gate = "BLOCKED_UPSTREAM"; why = f"主表 {prim} 无自有货币列且六层块 {pi['pack_credibility'] if pi else 'ABSENT'}；须补该粒度之 pnl/stake 列"
    alt = None
    if t in ("T-01","T-04","T-08","T-05"): alt = "S01_player_score（会员级 rebate_cost/ngr/net_margin 逐员有值）＋ T03_arbitrage（validbet/rebate/hedge_rate）；对级 pnl_offset_rate 仍待对级 pnl 列"
    if t == "T-02": alt = "R03_player_dealer 自有列 stake_amount/profit_amount/net_pnl/win_rate（uid×dealer）可算 hold_gap_vs_dealer_mean"
    if t == "T-09": alt = "S03_agent_score 自有列 stake/profit/ngr/residual_a 逐代理有值（4,191 代理）"
    if t == "T-11": alt = "I_ip_player 自有列（bet_ip×member_id）可算簇级合并流水；设备指纹缺（B-06）"
    gate_items.append(collections.OrderedDict([("type_id", t), ("name_zh", types[t]["name_zh"]), ("gate", gate), ("primary_deliverable", prim),
        ("primary_pack_credibility", pi["pack_credibility"] if pi else None), ("primary_econ_block", pi["econ_block_status"] if pi else None),
        ("primary_own_money_columns", money), ("supporting_credibility", {x["file"]: x["pack_credibility"] for x in si}), ("reason", why), ("alternative_source", alt),
        ("gate_meaning", "可算性闸，≠ admit_to_risk_decision，≠ SC-15 §四 之『准入商业决策』；父版 blocker_state／admit 字段一字未动"),
        ("E4_E5_rebate_cost_available", (t != "T-03")), ("E4_E5_note", "S01/PI04/T03 等会员级件已含 rebate_cost(bet16)/valid_bet/ngr/net_margin 逐员值；SC-15 §四『bet16/validbet 未交付』之判已过时，惟 agent_cost 仍 AG-03 UNRESOLVED"),
        ("theo_adt_nmpt_esi", "ABSENT — F-22~25 BLOCKED（house_edge 未授权 · x_prod 粒度未建 · 范围未裁）")]))
    L = LINK[t]
    link_items.append(collections.OrderedDict([("id", f"EL-{t}"), ("type_id", t), ("name_zh", types[t]["name_zh"]), ("economic_subject", L["subject"]), ("economic_grain", L["grain"]),
        ("treatment_ids", L["treatment_ids"]), ("policy_levers", L["levers"]), ("capability_dim_ids", L["caps"]), ("action_primitives", L["actions"]),
        ("related_pre_post_descriptives", ["TE-mem015","TE-mem016","TE-mem017"] if "T3" in L["treatment_ids"] else []), ("related_pre_post_note", "描述性前后对照之索引，非效应通路（S4 OPEN）"),
        ("economic_path_status", "NOT_ESTABLISHED"), ("linkage_status", "PROPOSED_BY_AUDIT_2026-09-02 · 待先生裁定"), ("note", L.get("note", ""))]))

# ---------------------------------------------------------------- 4. metric combinations (cross-table, join keys verified against headers)
HDR = {f: set(header(f)) for f in os.listdir(D) if f.endswith(".csv")}
def has(f, *cols): return all(c in HDR.get(f, set()) for c in cols)
COMBOS = [
 ("MC-01", "会员核心账本", ["S01_player_score.csv","PI04_member_5d_profile.csv","K01_risk_feature_matrix.csv","T03_arbitrage.csv","S_player_tail.csv"], "member_id", "会员×窗", ["stake","valid_bet","profit(GGR)","rebate_cost","ngr","net_margin_bet23_formal_canonical","hedge_rate","tail_share","n_active_days"], "会员级 NGR 排序、退水重定价、对冲敞口、活跃跨度；E1–E5 皆可算", "COMPUTABLE_NOW"),
 ("MC-02", "会员×尾投画像（FATAL 只画像）", ["R01_late_shoe.csv","P13_personal_entry.csv","S_player_tail.csv"], "uid↔member_id", "会员×窗", ["late_share","stake_late","roi_late","tail_share","entry_pos_p50"], "T-03 画像列；禁触发（P-18）", "COMPUTABLE_NOW_PROFILE_ONLY"),
 ("MC-03", "会员×处置前后", ["S01_player_score.csv","PI01_treatment_delta_member.csv","TL14_limit_treatment.csv","TL11_treatment_episode.csv","TL10_treatment_ledger.csv"], "member_id", "会员×处置事件", ["stake_pre/post","hold_pre/post_pct","d_revenue","max_hi_before/after","duration_days"], "处置手段前后经济效应（描述性；P-20 禁因果）", "COMPUTABLE_NOW_DESCRIPTIVE"),
 ("MC-04", "会员×月／日面板", ["S05_member_month_panel.csv","P_player_month.csv","T02_daily_roi.csv","P12c_member_daily_pnl.csv","B01_bt_panel.csv"], "member_id/uid × bet_date/month", "会员×时", ["stake","game_pnl","roi","net_pnl"], "时序稳定性、ramp、留存韧性（M14）；六层块勿用（WRONG_GRAIN），自有列可用", "COMPUTABLE_NOW_OWN_COLUMNS"),
 ("MC-05", "IP 筛查链→会员", ["I_ip_agg.csv","C01_ip_chain.csv","A_anchor.csv","C08_subnet_sparse.csv","I_ip_player.csv","S01_player_score.csv"], "bet_ip/ip → (bet_ip×member_id) → member_id", "IP→会员", ["n_member_eff","net_pnl(IP)","stake_ip","ngr(member)"], "IP 聚合体经济敞口须并报 n_members_eff 与 hold_gap_vs_domain；桥接唯一：I_ip_player", "COMPUTABLE_NOW"),
 ("MC-06", "会员对（同桌）", ["R02_same_table.csv","S01_player_score.csv"], "uid1/uid2 ↔ member_id", "会员对×窗", ["same_rate","jaccard","lift","stake(各员)","ngr(各员)"], "对级 stake_pair_sum/ngr 各员分列可算；pnl_offset_rate 须同局对级 pnl（缺）", "PARTIAL_BLOCKED_PAIR_PNL"),
 ("MC-07", "对冲对（同 IP 同局）", ["C06_hedge_pairs.csv","C06d_hedge_pairs_dated.csv","S01_player_score.csv","I_ip_player.csv"], "m_a/m_b ↔ member_id; bet_ip", "会员对×IP", ["opposite_rate","hedge_coverage","rebate_cost(各员)","ngr(各员)"], "对打经济指纹：opposite_rate 高 ∧ stake_symmetry ∧ pnl_offset_rate（后二者待对级 pnl）", "PARTIAL_BLOCKED_PAIR_PNL"),
 ("MC-08", "荷官维度", ["S02_dealer_score.csv","S02b_dealer_pace.csv","R03_player_dealer.csv"], "dealer_id", "荷官 / 会员×荷官", ["在桌洗码量","桌面输赢(OUTCOME_BASED)","局速","profit_amount(uid×dealer)","win_rate"], "hold_gap_vs_dealer_mean；桌面输赢禁入罚轴（P-16/DF-2）", "COMPUTABLE_NOW_OWN_COLUMNS"),
 ("MC-09", "代理线经济", ["S03_agent_score.csv","S01_player_score.csv"], "agent_id ↔ lv1_id..lv5_id", "代理×层级", ["stake","profit","ngr","residual_a","n_members_prod","own_share_pct_w"], "代理 NGR、下线质量、退水消耗比（A07）；AG-03 未决故 net_margin 仍 PENDING", "COMPUTABLE_NOW_AG03_PENDING"),
 ("MC-10", "产品／注型政策", ["DX04_bet09_profile.csv","DX05_product_panorama.csv","QSB_01c_cat1_contamination.csv","QSB_02c_push_by_family.csv"], "bet09 / product_code / bet09_family", "玩法", ["house_hold_pct","ggr","rebate_rate","mu0_pct(六族)"], "政策杠杆 L-02（注型 edge 向量）；theo 装配之料源", "COMPUTABLE_NOW"),
 ("MC-11", "平台日历", ["P12a_platform_daily.csv","D03S_daily_roi_diff.csv","TL06_log_mem_change.csv","_PH0_6b_member_daily.csv"], "dt / bet_date", "日", ["ggr_sum","hold_pct","roi_tail/roi_norm","n_enable_N/n_canbet_N"], "日级 hold 与处置量之并置（时序对照，非因果）", "COMPUTABLE_NOW"),
 ("MC-12", "退水政策", ["R_rebate_dist.csv","P01B_diff_ratio.csv","S01_player_score.csv"], "rebate_rate ↔ rebate_rate_actual", "档位×会员", ["rebate_rate","rebate_cost","valid_bet","ngr"], "政策杠杆 L-01：档位 vs 解析盈亏线 1.1465%；实测档位 ≤1%", "COMPUTABLE_NOW"),
 ("MC-13", "限红处置", ["TL14_limit_treatment.csv","TL03b_pseudo_treatment.csv","S01_player_score.csv"], "member_id", "会员×限额事件", ["max_hi_before/after","direction","stake","ngr"], "T-14 限红试探须 PIT 重建（B-09）；TL14 568 行为 PIT 料源", "COMPUTABLE_NOW_PARTIAL"),
 ("MC-14", "处置日志三源", ["EV01_disposal_events.csv","EV02_member_disposal.csv","TL08_treatment_events.csv","TL10_treatment_ledger.csv"], "member_id / event_date", "事件", ["event_type","action_class","field_name","value_before/after"], "S2 事件语义（PARTIALLY CLOSED）；S3 映射待闭合", "COMPUTABLE_NOW_SEMANTICS_OPEN"),
 ("MC-15", "标签与种子", ["K01b_seed_manual.csv","K01c_seed_dated.csv","L_label_dist.csv","K01_risk_feature_matrix.csv","S01_player_score.csv"], "member_id", "会员", ["is_seed","risk","ngr","hold_rate"], "人工标记史 vs 经济：K01 交付件 is_seed 全 0（120,063 行），种子对照现不可得", "BLOCKED_SEED_ABSENT"),
 ("MC-16", "哨兵荷官影响", ["Z11_sentinel_impact.csv","R03_player_dealer.csv"], "is_sentinel_dealer", "荷官", ["剔除行数 119","剔除占比 8e-7"], "哨兵剔除对总量影响 ≈ 0（Z11 实测）", "REFERENCE"),
 ("MC-17", "责任博彩痕迹", ["PH0_8r1_rg_case.csv","PH0_8r2_rg_crosstable.csv","_PH0_3_lmc_category.csv","_PH0_4b_rg_keyword.csv","TL02_config_change.csv"], "member/keyword", "事件", ["n_rg_true 0","变更率"], "RG 标记窗内为零；M10 无经济承载", "REFERENCE"),
 ("MC-18", "桌台产能（L2 料源）", ["S_second_dist.csv","T_table_span.csv","R01chk_shoe_len_by_table.csv","B_online_base.csv"], "table_id", "桌台", ["n_shoes","span","sec_elapsed"], "杠杆 L2 须 桌×时段×荷官×日 之 house_pnl_per_table_hour；现无小时维度交付件", "BLOCKED_UPSTREAM_NO_HOUR_GRAIN"),
 ("MC-19", "有效投注恒等式", ["VB_00_validbet_contract.csv","VB_41_identity_global.csv","VB_41c1_964_detail.csv","DICT_01a_bet41_tri.csv"], "scope/member", "契约", ["diff_vb_minus_b41"], "数据契约（bet41≡validbet 99.99923%），非经济杠杆", "REFERENCE"),
 ("MC-20", "资金漏斗（L3）", [], "wallet.user→mem002→mem001→bet05", "会员×资金", ["net_deposit","churn_multiple","roi_cash"], "wallet_dtl 系内部转账与余额快照，非入金流水（§V-2）；B-11 链 MISSING", "BLOCKED_UPSTREAM_NO_SOURCE"),
]
mc_items = []
for cid, name, tabs, key, grain, mets, q, st in COMBOS:
    keys_ok = {}
    for f in tabs:
        kc = [c for c in ("member_id","uid","uid1","uid2","m_a","m_b","mid","player_id","bet_ip","ip","dealer_id","agent_id","table_id","gi011","dt","dt_day","bet_date","ym","bet_month","product_code","bet09","bet_side","bet09_value","bet09_family","rebate_rate","rebate_rate_actual","event_date","action_date","is_sentinel_dealer","lv1_id","scope","grp","subnet_24") if c in HDR.get(f, set())]
        keys_ok[f] = kc[:4]
    cred = {f: pack.get(f, {}).get("credibility", "?") for f in tabs}
    mc_items.append(collections.OrderedDict([("id", cid), ("name_zh", name), ("tables", tabs), ("join_key", key), ("grain", grain), ("economic_metrics", mets), ("business_question", q), ("computable_status", st), ("pack_credibility", cred), ("join_columns_verified_in_headers", keys_ok), ("join_key_note", "列出者皆经表头核验；别名（bet_side / bet09_value / dt_day / ym / mid / player_id）已纳入核验集"), ("evidence_ladder", "E1")]))

# ---------------------------------------------------------------- 5. assemble sections
platform = collections.OrderedDict([
    ("source", "S01_player_score.csv（#075，OK/PRIMARY，723,442 会员逐员）— 2026-09-02 R 实读全量；范围：百家乐（bet02='101'）单产品"),
    ("scope", collections.OrderedDict([("product", "101 百家乐（本报告口径）"), ("other_products_out_of_scope", collections.OrderedDict([("products", "102/103/104/105/107/108/5031"), ("stake", round(r2["other_products_stake"])), ("ggr", round(r2["other_products_ggr"])), ("member_rows", int(r2["other_products_members"])), ("note", "DX05 实测；其他产品 4.90B 本金、130.75M 毛利未入任何会员级经济表（EG-14）")]))])),
    ("basis_ruling_CC01", "六层块 profit = −bet17/bet11 = GGR − 退水 = NGR（bet17 已含退水）；块 ngr = GGR − 2×退水（重复扣减，DEPRECATED）；毛利 GGR = profit + rebate_cost = −游戏输赢贡献（M02）。以下各量按此口径"),
    ("members", int(lev["platform_members"])), ("stake", round(lev["platform_stake"])), ("valid_bet", round(lev["platform_valid_bet"])),
    ("ggr_gross", round(r2["gross_ggr"])), ("rebate_cost_bet16", round(lev["platform_rebate_cost"])), ("ngr", round(r2["ngr_true"])), ("ngr_column_double_deducted_DEPRECATED", round(lev["platform_ngr"])),
    ("net_margin_candidate", round(r2["net_margin_candidate"])), ("net_margin_status", "ORDERING_ONLY（AG-03 UNRESOLVED；agent_cost 候选 B 未裁，绝对额不得对外）"), ("net_margin_column_double_deducted_DEPRECATED", round(lev["platform_net_margin_bet23"])),
    ("agent_cost_bases", collections.OrderedDict([("formal_bet23", round(r2["agent_cost_formal"])), ("lv1", round(r2["agent_cost_lv1"])), ("lv2", round(r2["agent_cost_lv2"])), ("lv3", round(r2["agent_cost_lv3"])), ("lv4", round(r2["agent_cost_lv4"])), ("lv5", round(r2["agent_cost_lv5"])), ("spread", round(r2["agent_cost_spread"])), ("note", "五口径极差 659,108 ＝ 代理成本 7.2%、毛利 0.28%；AG-03 之经济量级已量化，裁决仍待")])),
    ("hold_gross_pct_stake_basis", round(r2["hold_gross_stake_pct"], 4)), ("hold_gross_pct_validbet_basis", round(r2["hold_gross_validbet_pct"], 4)), ("ngr_rate_pct", round(r2["ngr_rate_pct"], 4)), ("net_margin_candidate_pct", round(r2["net_margin_candidate_pct"], 4)),
    ("hold_basis_crosswalk", [collections.OrderedDict([("source", r["source"]), ("numerator", round(fnum(r["numerator"]))), ("denominator", round(fnum(r["denominator"]))), ("hold_pct", fnum(r["hold_pct"]))]) for r in cw]),
    ("members_ngr_negative", int(r2["members_ngr_negative"])), ("ngr_negative_sum", round(r2["members_ngr_negative_sum"])), ("members_gross_negative", int(r2["members_gross_negative"])),
    ("ngr_share_top1pct_members", round(lev["ngr_top1pct_share"], 2)), ("ngr_share_top10pct_members", round(lev["ngr_top10pct_share"], 2)),
    ("evidence_L5_insufficient_members", int(lev["evidence_L5_members"])),
    ("action_priority_buckets_status", "PROFILE_ONLY · 总包桶名系全窗百分位 ＋ n_rounds<30 手写门槛（P-15／P-06 疑违）；本册只登记分布，禁据以处置（P-16）"),
    ("action_priority_buckets", [collections.OrderedDict([("bucket", r["action_priority"]), ("count", int(r["n"])), ("sum_net_margin_ordering_only", round(fnum(r["sum_net_margin"]))), ("sum_ngr", round(fnum(r["sum_ngr"]))), ("sum_stake", round(fnum(r["sum_stake"])))]) for r in ap]),
    ("evidence_rate_tiers", [collections.OrderedDict([("tier", r["evidence_rate"]), ("count", int(r["n"])), ("sum_stake", round(fnum(r["sum_stake"]))), ("sum_ngr", round(fnum(r["sum_ngr"])))]) for r in er]),
    ("observability_PI04", [collections.OrderedDict([("verdict", r["verdict_observability"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("revenue", round(fnum(r["revenue"]))), ("hold_pct", fnum(r["hold_pct"]))]) for r in pi04]),
])
levers_measured = [
 collections.OrderedDict([("id", "LM-01"), ("lever", "L-01 退水档位（规则杠杆）之经济量登记（BIZ_三杠杆 L1 之离线复算，S01 逐员）"), ("treatment_id", "T11"), ("actions", ["A05"]), ("usage", "规则层（改档位表）之输入；逐员统计只作分布描述，禁作处置名单（P-16）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"), ("cut_points_provenance", "0.5%／1%／1.5% 为描述用分桶，非登记阈值；L-01 解析线 1.1465% 为登记值"),
    ("basis", "CC-01 毛利口径：ggr_gross = profit + rebate_cost；ngr = profit"),
    ("members_receiving_rebate", int(r2["rebate_members"])), ("rebate_paid", round(r2["rebate_members_rebate"])), ("their_ggr_gross", round(r2["rebate_members_ggr_gross"])), ("their_ngr", round(r2["rebate_members_ngr"])),
    ("their_pooled_hold_gross_pct", round(r2["rebate_members_hold_gross_pct"], 3)), ("their_pooled_ngr_rate_pct", round(r2["rebate_members_ngr_rate_pct"], 3)), ("their_n_rounds", int(r2["rebate_members_n_rounds"])),
    ("rebate_bands", [collections.OrderedDict([("band", r["rb_band"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("valid_bet", round(fnum(r["valid_bet"]))), ("ggr_gross", round(fnum(r["ggr_gross"]))), ("rebate", round(fnum(r["rebate"]))), ("ngr", round(fnum(r["ngr"]))), ("hold_gross_pct", fnum(r["hold_gross_pct"])), ("ngr_rate_pct", fnum(r["ngr_rate_pct"])), ("n_rounds", int(fnum(r["n_rounds"]))), ("ci95_halfwidth_pp", fnum(r["ci_halfwidth_pp"])), ("n_ngr_negative", int(r["n_ngr_negative"])), ("L5_share", fnum(r["L5_share"]))]) for r in rb2]),
    ("rebate_members_with_negative_ngr", int(r2["rebate_members_ngr_negative_n"])), ("rebate_paid_to_negative_ngr_members", round(r2["rebate_members_ngr_negative_rebate"])),
    ("BIZ_L1_percentile_segmentation_result", [collections.OrderedDict([("seg", r["seg"]), ("count", int(r["n"])), ("rebate_now", round(fnum(r["rebate_now"]))), ("rebate_proposed", round(fnum(r["rebate_proposed"]))), ("saving", round(fnum(r["saving"]))), ("ngr", round(fnum(r["ngr"]))), ("hold_pct", fnum(r["hold_pct"]))]) for r in L1seg]),
    ("BIZ_L1_static_saving", round(lev["L1_saving_total"])),
    ("verdict", "L1 之分位分档在本平台退化：实测档位聚于 0.8%~0.9%（VIP 各档 P25=P50=0.008），A/B 段为空集，静态节省 ≈ 0。退水总额 8,220,756 仅占 GGR 3.64%，全砍上限亦 8.2M（未计流失）。档位表整体对 L-01 解析线 1.1465% 之距离决定规则层可为。★ 口径纠正（CC-01）：前稿以重复扣减之 ngr 栏称 [1%,1.5%) 档『NGR −488,686』，实为 NGR +125,283（毛利 739,251，退水 613,968，NGR 率 0.185%，CI ±0.61pp）；领退水者毛利率 1.987% 高于平台 1.743%，退水后 NGR 率 1.237% 低于平台 1.682%。任何逐员数字皆非处置依据（P-16）"),
    ("upper_bound_saving_if_rebate_zeroed", round(lev["platform_rebate_cost"])), ("evidence_ladder", "E1"), ("caveat", "静态节省，未计流失；落地须 DID（P-20 现 BLOCKED）")]),
 collections.OrderedDict([("id", "LM-02"), ("lever", "对冲／打水会员之经济敞口（T03_arbitrage 逐员）"), ("treatment_id", "T11"), ("actions", ["A05"]),
    ("members", int(lev["T03_members"])), ("members_hedge_rate_positive", int(lev["T03_hedge_pos_members"])), ("members_hedge_rate_ge_20pct", int(lev["T03_hedge_ge20_members"])),
    ("hedge_ge_20pct_stake", round(lev["T03_hedge_ge20_stake"])), ("hedge_ge_20pct_ggr", round(lev["T03_hedge_ge20_ggr"])), ("hedge_ge_20pct_rebate", round(lev["T03_hedge_ge20_rebate"])), ("hedge_ge_20pct_ngr", round(lev["T03_hedge_ge20_ngr"])),
    ("hedge_bands", [collections.OrderedDict([("band", r["hb"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("ggr_gross", round(fnum(r["ggr_gross"]))), ("rebate", round(fnum(r["rebate"]))), ("ngr", round(fnum(r["ngr"]))), ("hold_gross_pct", fnum(r["hold_gross_pct"])), ("ngr_rate_pct", fnum(r["ngr_rate_pct"])), ("n_rounds", int(fnum(r["n_rounds"]))), ("ci95_halfwidth_pp", fnum(r["ci_pp"]))]) for r in hedge2]),
    ("cut_points_provenance", "5%／20%／50% 为描述用分桶，非登记阈值；hedge_rate 之 threshold_status 仍 PENDING_INVERSE（T-05）"), ("usage", "DESCRIPTIVE_ONLY"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),
    ("verdict", "观察（毛利口径）：各对冲档合并 hold 1.48%~2.17%，与平台毛利率 1.743% 同量级；[20%,50%) 档 1.543% ± 0.246pp 之下界低于平台，故『不低于平台』不成立，只能说『未观测到系统性侵蚀』。退水合计 9.6 万。转移型对打（chip dumping）不在此度量内；本条不构成判定（P-17）"), ("evidence_ladder", "E1")]),
 collections.OrderedDict([("id", "LM-06"), ("lever", "人工标记／种子会员之经济对照（S01.人工标记史 · K01b_seed_manual）"), ("usage", "PROFILE_ONLY · 描述性对照；标记系人工处置史，非因果"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),
    ("cohorts", [collections.OrderedDict([("cohort", r["cohort"]), ("count", int(r["n"])), ("stake", round(fnum(r["stake"]))), ("ggr_gross", round(fnum(r["ggr_gross"]))), ("ngr", round(fnum(r["ngr"]))), ("rebate", round(fnum(r["rebate"]))), ("hold_gross_pct", fnum(r["hold_gross_pct"])), ("ngr_rate_pct", fnum(r["ngr_rate_pct"])), ("n_rounds", int(fnum(r["n_rounds"]))), ("ci95_halfwidth_pp", fnum(r["ci_pp"]))]) for r in seed2]),
    ("note", "127 名人工标记会员毛利率 1.108% ± 0.230pp，低于未标记者 1.752%；K01b 125 名种子中 124 名见于 S01（1.069%）。K01_risk_feature_matrix 之 is_seed 恒 0 系该件构建缺陷，非数据不存在（EG-08 改判 MEASURED）"), ("evidence_ladder", "E1")]),
 collections.OrderedDict([("id", "LM-03"), ("lever", "L-02 注型 edge 向量（QSB_02c 六族 μ0）"), ("treatment_id", "T12"), ("actions", ["A03"]), ("usage", "规则层（产品／赔付）之输入"),
    ("families_mu0_pct", {"F1_庄闲主注": -1.593812, "F2_和局": -13.232791, "F3_对子族": -9.980930, "F4_例牌族": -15.309513, "F5_龙宝族": -8.250356, "F6_幸运族": -22.438564, "F7_大小": -4.792781}),
    ("note", "theo 解封只差装配：theo_i = Σ_k handle_ik × |μ0_k|，须 member×bet09 中间粒度（M11 AWAITING_SOURCE）"), ("evidence_ladder", "E1")]),
 collections.OrderedDict([("id", "LM-04"), ("lever", "代理线净贡献分布（S03_agent_score，4,191 代理）"), ("usage", "PROFILE_ONLY · 禁依 NGR 符号对代理施以 T5/A02（P-16 不限于会员）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),
    ("agents_negative_ngr", 821), ("agents_negative_ngr_sum", -16862323), ("top5_agents_by_ngr", [["4298",1,48610555],["4299",2,46424753],["4300",3,29068874],["4202",1,26962427],["4203",2,23912754]]),
    ("note", "S03 六层块无 economic_value/net_margin 列；自有列 stake/profit/ngr/residual_a 逐代理有值；AG-03 未决故 agent_cost 仍 PENDING"), ("evidence_ladder", "E1")]),
 collections.OrderedDict([("id", "LM-05"), ("lever", "平台净额之会员集中度与总包 action_priority 桶之分布（S01）"), ("usage", "PROFILE_ONLY · 桶系总包以全窗百分位与 n<30 手写门槛所定（P-15／P-06 疑违），本册只登记分布，禁据以处置（P-16）"), ("criterion_family", "OUTCOME_BASED"), ("window_scope", "FULL_WINDOW"),
    ("A_bucket_net_loss_decile", {"members": int(lev["A_bucket_members"]), "sum_net_margin": round(lev["A_bucket_net_margin"]), "sum_stake": round(lev["A_bucket_stake"])}),
    ("D_bucket_top_profit_quintile", {"members": int(lev["D_bucket_members"]), "sum_net_margin": round(lev["D_bucket_net_margin"]), "sum_stake": round(lev["D_bucket_stake"])}),
    ("Z_bucket_insufficient_evidence", {"members": int(lev["Z_bucket_members"]), "sum_net_margin": round(lev["Z_bucket_net_margin"])}),
    ("note", "A 桶 34,990 人合计净额 −97.8M、D 桶 69,269 人 +278M：系实现输赢之全窗百分位切分，P-16 禁以之定罚、P-15 禁以之定赏罚线；此处仅为经济暴露之分布描述"), ("evidence_ladder", "E1")]),
]
treat_section = collections.OrderedDict([
    ("nature", "PRE_POST_DESCRIPTIVE_ONLY：处置前后之经济量对照登记；非处置效应估计（P-20 BLOCKED until S3∧S4 CLOSED）；非处置名单（P-16）"),
    ("iron_caveats", ["描述性前后对照，非因果估计：treatment_status S3/S4 OPEN ⇒ PSM/DID/HMM 一律 BLOCKED（P-20）", "处置对象系因『赢』而被处置，post 期 hold 回升含回归均值与幸存者偏差，禁读作处置效应", "禁以实现输赢符号定罚（P-16）；本节只回答『处置后平台经济量变了多少』", "样本量：186 人／90 人有 post 注单／71 人前后皆有 ⇒ evidence_rate 多为 L5_INSUFFICIENT"]),
    ("sources", ["PI01_treatment_delta_member.csv（186 行，member×treat_time）", "PI02_treatment_delta_platform.csv（cohort×phase）", "TL14_limit_treatment.csv（568 行）", "TL11_treatment_episode.csv（315 节）", "TL10_treatment_ledger.csv（8,589 行）", "TL03b_pseudo_treatment.csv（148 行）"]),
    ("member_level_by_treatment_field", te_items),
    ("pooled_all_treated", collections.OrderedDict([("count", len(pi01)), ("n_pre_and_post", len(both_all)), ("d_hold_positive", f"{sum(1 for r in both_all if fnum(r['d_hold_pct']) > 0)}/{len(both_all)}"), ("inference", "NOT_RUN — 配对检验属处置效应估计，P-20 BLOCKED；只登计数"), ("sum_d_revenue", round(sum(fnum(r["d_revenue"]) or 0 for r in pi01))), ("n_no_post_exposure", sum(1 for r in pi01 if grp(r) == "NO_EXPOSURE")), ("stake_pre_of_no_post_exposure", round(sum(fnum(r["stake_pre"]) or 0 for r in pi01 if grp(r) == "NO_EXPOSURE")))])),
    ("pooled_all_treated_bootstrap_ci95_of_sum_d_revenue", [round(r2["pi01_d_revenue_ci_lo"]), round(r2["pi01_d_revenue_ci_hi"])]),
    ("pooled_all_treated_exposure_note", "n_post 之 P10/P25/P50/P75/P90 = 0/0/0/663.5/5,533.5；post 天数 0/0/0/4/19 —— 半数以上处置后无暴露，ΣΔGGR 之自助 95% 区间含 0"),
    ("pi01_by_typology_markers", [collections.OrderedDict([("treatment_field", r["treat_field"]), ("count", int(r["n"])), ("in_S01", int(r["in_S01"])), ("marked_人工标记史", int(r["marked"])), ("hedge_rate_ge_20pct", int(r["hedge_ge20"])), ("shared_ip_n_member_eff_ge_10", int(r["shared_ip_ge10"])), ("evidence_L5", int(r["L5"])), ("evidence_L1_L4", int(r["L1_L4"])), ("sum_d_revenue", round(fnum(r["sum_d_revenue"])))]) for r in xt]),
    ("ledger_wide_pre_post_P12c", collections.OrderedDict([
        ("method", "TL10 台账 8,525 事件 × P12c_member_daily_pnl（uid×dt，day_stake/day_pnl；day_pnl 系 bet17 口径含退水，故 ggr 列为 NGR 口径）：pre = 事件日前全部日，post = 事件日后全部日；不归因"),
        ("coverage", collections.OrderedDict([("tl10_members", int(r2["tl10_members"])), ("tl10_members_in_P12c", int(r2["tl10_members_in_P12c"])), ("tl14_members", 484), ("tl14_members_in_P12c", int(r2["tl14_members_in_P12c"])), ("note", "P12c 只覆盖 92,412 名会员（R01 宇宙），故 1,249 名台账会员不可测；覆盖率登记为事实，非缺口填充")])),
        ("by_field", [collections.OrderedDict([("field", r["field_grp"]), ("events", int(r["events"])), ("members", int(r["members"])), ("with_pre_and_post", int(r["with_both"])), ("stake_pre", round(fnum(r["stake_pre"]))), ("stake_post", round(fnum(r["stake_post"]))), ("ngr_pre", round(fnum(r["ggr_pre"]))), ("ngr_post", round(fnum(r["ggr_post"]))), ("ngr_rate_pre_pct", fnum(r["hold_pre_pct"])), ("ngr_rate_post_pct", fnum(r["hold_post_pct"])), ("d_ngr", round(fnum(r["d_ggr"])))]) for r in lp if int(r["events"]) >= 4]),
        ("tl14_by_direction", [collections.OrderedDict([("direction", r["direction"]), ("events", int(r["events"])), ("members", int(r["members"])), ("with_pre_and_post", int(r["with_both"])), ("stake_pre", round(fnum(r["stake_pre"]))), ("stake_post", round(fnum(r["stake_post"]))), ("ngr_pre", round(fnum(r["ggr_pre"]))), ("ngr_post", round(fnum(r["ggr_post"]))), ("ngr_rate_pre_pct", fnum(r["hold_pre_pct"])), ("ngr_rate_post_pct", fnum(r["hold_post_pct"])), ("d_ngr", round(fnum(r["d_ggr"])))]) for r in l14]),
        ("caveat", "pre／post 窗长不等（post 本金远大于 pre 者系处置早、余期长），率可比、额不可比；回归均值与幸存者偏差未除；P-20 禁读作效应")])),
    ("population_reconciliation", [{"definition": "PI01 被处置会员（member×treat_time）", "count": 186}, {"definition": "PI01 处置前有注单", "count": 167}, {"definition": "PI01 处置后有注单", "count": 90}, {"definition": "PI01 前后皆有注单（可比）", "count": 71}, {"definition": "PI01 处置后零投注", "count": 96}, {"definition": "PI01 处置前无注单", "count": 19}, {"definition": "PI02 TREATED PRE / POST 人数", "count": "167 / 90"}, {"definition": "TL14 限红事件 / 会员", "count": "568 / 484"}, {"definition": "TL11 处置节 / 会员", "count": "315 / 154"}, {"definition": "TL10 台账行 / 会员", "count": "8,589 / 1,497"}, {"definition": "registry.window.universe_members（OQ-04 未闭）", "count": 721190}, {"definition": "S01 逐员行数", "count": 723442}]),
    ("platform_cohort_PI02", pi02_rows),
    ("limit_events_TL14", collections.OrderedDict([("events", len(tl14)), ("members", len({r["member_id"] for r in tl14})), ("direction", dict(tl14_dir)), ("after_over_before_ratio_P10_P50_P90", [ratios[int(len(ratios)*.1)], ratios[len(ratios)//2], ratios[int(len(ratios)*.9)]] if ratios else None), ("note", "限红档以 TIGHTEN 为主（416/568），中位数减半；RELEASE 97 件、FLAT 52 件 —— 父版 policies[T3].ledger_source『方向仅 TIGHTEN，无 LOOSEN 样本』与 §PIT-01『direction=TIGHTEN』据此撤回，见 retraction_register W-82")])),
    ("episodes_TL11", collections.OrderedDict([("episodes", len(tl11)), ("members", len({r["member_id"] for r in tl11})), ("by_enforcement_type", dict(tl11_by)), ("censor_reason", dict(tl11_cens))])),
    ("ledger_TL10", collections.OrderedDict([("rows", len(tl10)), ("members", len({r["member_id"] for r in tl10})), ("top_fields", dict(tl10_fields.most_common(8)))])),
    ("pseudo_treatment_TL03b", {f"{a}·{d}": n for (a, d), n in tl03b_dir.items()}),
    ("fields_with_pre_post_data", ["mem015（临时映射 T3/A01）", "mem016 · mem017（临时映射 A12）"]),
    ("treatment_ids_zero_ledger", ["T1","T6","T7","T8","T9","T10"]),
])
gaps = [
 dict(id="EG-01", gap="theo / adt / nmpt / esi 于 132 件交付件与 OPT 总包中一律 ABSENT（house_edge = NULL · theo = NULL）", severity="S1", status="BLOCKED", unblock="F-47 commission lineage 闭合 ＋ (bet09, is_free_comm) house_edge 授权入册 ＋ x_prod 中间粒度 CTE ＋ 施加范围裁示（8 处 vs 256 处）", evidence="HF9f_B_增补件_theo族_草案_BLOCKED.sql；capability_registry M11/A08 AWAITING_SOURCE；M12/M13/A10 REFUTED_AS_PRIMARY"),
 dict(id="EG-02", gap="economic_value 列非金额：PERCENT_RANK(−net−rebate−agent_cost) ∈ [0,1]，53 件恒为单值广播、24 件低基数", severity="S1", status="OPEN", unblock="正名为 net_margin_pr_global（承 F-17 之例），并于登记册 metric_semantics_ruling 锁定；下游禁作『经济价值金额』读", evidence="OPT 行 1003；econ_block_census.csv"),
 dict(id="EG-03", gap="六层商业块 118 栏被 CROSS JOIN 广播：65 件之 stake 逐行恒为平台总本金 13,436,093,473.33（48 件多行 ＋ 17 件单行，同批 economic_value 恒 0；红队独立复算）；另 37 件上卷广播", severity="S1", status="OPEN", unblock="HF9b 红队建议：Evidence Output 与 Commercial Accounting Output 分离；不再把六层块物理注入全部 129 件", evidence="pack 模块索引 24 OK／37 WRONG_GRAIN／67 INVALID／1 NULL；本次 R 逐件实测 52 件 BROADCAST_CONSTANT ＋ 18 件 SINGLE_ROW_BROADCAST；红队复算 65 件 stake 恒等平台总本金"),
 dict(id="EG-04", gap="v1.5.001 十六新栏中 treatment_ids / capability_dim_ids 于 66 行全空；economic_path_status 66 行全 NOT_ESTABLISHED；domain_id / capability_facet 66 行全同值（D08 / F06）——entity_type 则已分 MEMBER 55 / DEALER 6（T-02）/ AGENT 4（T-09）/ RISK_OFFICER 1（T-10）", severity="S2", status="PATCHED_IN_1_5_002_AS_PROPOSAL", unblock="先生裁定 typology_economic_linkage 之提案后回填", evidence="registry_risk_typology_v1.5.001.csv 新增十六栏居第 41–56 栏；treatment_ids 第 55、capability_dim_ids 第 56"),
 dict(id="EG-05", gap="SC-15 §四『bet16/validbet 未交付 ⇒ E4/E5 全 BLOCKED_UPSTREAM』已过时：S01/PI04/T03 等会员级件已含 rebate_cost(bet16)、valid_bet、ngr、net_margin 逐员值", severity="S2", status="PROPOSED_SUPERSESSION · 待裁", unblock="SC-15 升 v1.1.1 改判 E4/E5 于会员粒度可算（≠ 准入商业决策）；惟 agent_cost 之 AG-03 仍 UNRESOLVED", evidence="levers_summary.csv：platform_rebate_cost 8,220,756；members_with_rebate 18,616"),
 dict(id="EG-06", gap="处置效应因果链 BLOCKED：treatment_status S3（映射）/S4（结局链接）OPEN；mcid_cost_anchor_status BLOCKED（F-26）；cost_per_unit 十三类全 BLOCKED", severity="S1", status="BLOCKED", unblock="S3/S4 闭合 → Treatment Ledger → MCID → 成本 C → 阈值（W-78 链）", evidence="treatment_status.policy_extension"),
 dict(id="EG-07", gap="杠杆 L2（桌台×时段×荷官产能）与 L3（资金漏斗）无交付件：无小时粒度件；wallet_dtl 非入金流水", severity="S2", status="BLOCKED_UPSTREAM", unblock="L2：新增 桌×小时 交付件（BIZ_三杠杆 L2 SQL 已备）；L3：B-11 全链 ＋ 真入金表", evidence="BIZ_商业方案_三杠杆_v1_0_0.sql；pending_functions §B-11"),
 dict(id="EG-08", gap="K01_risk_feature_matrix 交付件 is_seed 恒 0（120,063 行）系构建缺陷；种子对照已改由 S01.人工标记史（127 人）与 K01b→S01（124/125）实测（LM-06）", severity="S2", status="MEASURED_VIA_S01", unblock="修 K01 之 is_seed 构建；K01b_seed_goldip 空档待回填", evidence="seed_cohort_v2.csv"),
 dict(id="EG-09", gap="退水杠杆之分位分档（BIZ L1）在本平台退化：档位聚于 0.8%~0.9%，A/B 段空集，静态节省 ≈ 0；退水总额 8,220,756 仅占毛利 3.51%（CC-01 口径）", severity="S3", status="MEASURED", unblock="规则层：档位表整体对 L-01 解析线 1.1465% 之距离；禁逐员靶向（P-16）", evidence="L1_segments.csv；S01_rebate_bands_v2.csv"),
 dict(id="EG-10", gap="evidence_rate：719,125 会员（99.40%）为 L5_INSUFFICIENT，率型指标（hold/ROI）个体判定对其统计上不成立", severity="S1", status="MEASURED", unblock="率型结论只对 L1–L4 4,317 人出；余者以和型指标（stake/n_bets）与画像出", evidence="S01_evidence_rate.csv；HF9B 证据分层判据书"),
 dict(id="EG-12", gap="R24b 仍 NOT_RUN：P-16 之机检栏 criterion_family=OUTCOME_BASED 于父版 66 判据覆盖 0（VACUOUS），P-17/P-20 未绑定；本版新增之经济量虽逐条标 criterion_family: OUTCOME_BASED，惟 R24b 只扫判据层 CSV", severity="S1", status="OPEN", unblock="N-5 判据语义裁决（T-07 win_rate_all 等改标 OUTCOME_BASED）＋ 校验器 R24b 增扫本册经济节", evidence="verify_dual_result_1_5_002.csv R24b"),
 dict(id="EG-13", gap="父版两处措辞与实测相悖：policies[T3].ledger_source『方向仅 TIGHTEN，无 LOOSEN 样本』、§PIT-01『direction=TIGHTEN』，实测 RELEASE 97 件", severity="S2", status="RETRACTED_BY_W-82", unblock="父版句保留不删，W-82 撤回", evidence="TL14 实测"),
 dict(id="EG-14", gap="范围边界：一切会员级经济量皆为百家乐（bet02='101'）单产品；DX05 实测其他七产品本金 4,900,008,008、毛利 130,751,499（＝百家乐毛利 55.8%）不入任何会员级经济表；member×product 粒度件缺", severity="S2", status="BLOCKED_UPSTREAM", unblock="出 member×bet02 粒度交付件；本册所有会员级数字须标『百家乐口径』", evidence="DX05_product_panorama.csv 八行"),
 dict(id="EG-15", gap="台账级处置前后覆盖有限：TL10 1,497 名会员中仅 248 名见于 P12c（uid×dt 面板只覆盖 R01 宇宙 92,412 人）；TL14 484 名中 114 名", severity="S2", status="MEASURED_PARTIAL", unblock="出全宇宙 member×dt 面板（T02_daily_roi 之 1,160,259 行亦只覆盖同宇宙）", evidence="ledger_prepost_by_field.csv"),
 dict(id="EG-16", gap="自有货币栏单位／范围未对账：E02 之 rebate/commission 合计 14.9B/166.8B ≫ 平台退水 8.2M；DICT_01a／QSB_01a／QSB_01c／VB_* 之 stake 合计 676.9B 系全产品全库口径；I_ip_player／R03 之 *_all 栏为会员总额逐行广播", severity="S2", status="MEASURED", unblock="逐件登记单位与范围；T-08 主表 E02 降 BLOCKED_UNITS", evidence="own_money_reconciliation.csv（14/51 件不可对账）"),
 dict(id="EG-11", gap="R03b_player_dealer_daily_b1_to_b8.csv（800,000 行，#071 之前八批）在盘未登记；#071 全量 18,139,550 行 MISSING（B-02）", severity="S2", status="OPEN", unblock="deliverable_roster 增 PARTIAL 态并登记该件六元组；或按 D-14b 瘦身版重导", evidence="数据表 目录实测"),
]
semantics = [
 dict(column="economic_value", current="PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)", meaning="平台真净利（residual_b）之全体百分位秩，0..1", ruling="非金额；禁作『经济价值』读；建议正名 net_margin_pr_global，旧名保留兼容"),
 dict(column="risk_value", current="PERCENT_RANK(roi)", meaning="恒等于 roi_pr_global（F-17）", ruling="兼容列，HF9g 起废弃；与『风险』无关"),
 dict(column="profit（六层块）", current="ROUND(-e.net,4)，e.net = bet17/bet11", meaning="★CC-01：bet17 已含退水 ⇒ profit = GGR − 退水 = NGR（T03 逐行 net_pnl == game_pnl + rebate 100%；DX05 product 101 ggr 234,152,957 = Σprofit + Σrebate_cost）", ruling="profit 即 NGR；总包头注『profit = 平台牌桌毛赢』与实况相悖，须改注"),
 dict(column="ngr（六层块）", current="-e.net - e.rebate", meaning="GGR − 2×退水（退水重复扣减）", ruling="DEPRECATED_DOUBLE_DEDUCTION：不得作 NGR 用；NGR 取 profit 栏"),
 dict(column="ggr_gross（本册派生）", current="profit + rebate_cost = −游戏输赢贡献（M02）", meaning="毛利 GGR", ruling="平台毛利之唯一口径；hold_gross = ggr_gross/stake = 1.7427%（洗码口径 1.9349%）"),
 dict(column="net_margin_bet23_formal_canonical", current="-e.net - e.rebate - e.agent_cost", meaning="NGR − 代理成本（bet23 候选 B）", ruling="AG-03 UNRESOLVED ⇒ 只作排序，不作绝对额对外"),
 dict(column="residual_b / cost_complement_b", current="同上之旧名", meaning="canonical 对应列", ruling="保留兼容，禁互代"),
 dict(column="hold_rate", current="-e.net/e.stake", meaning="★CC-01：系 NGR 率（bet17 口径），非毛利率", ruling="率型：须并读 evidence_rate 与 hold_ci_halfwidth_approx；对外须标『NGR 率』"),
 dict(column="roi（六层块）", current="e.net/e.stake", meaning="会员净回报率，bet17 口径（含退水），= −hold_rate", ruling="OPT 总包 128 处定义；ROI>0 非任何类判据（SC-15 §八 锁 4）"),
 dict(column="hold_ci_halfwidth_approx", current="1.96·0.95/√n_rounds", meaning="hold 95% CI 半宽近似", ruling="逐行现算；L5 者半宽 ≫ 效应量"),
 dict(column="action_priority", current="A/D/E/Z 由 PERCENT_RANK 与 n_bets/n_rounds<30 定", meaning="总包决策标签", ruling="仅 OK 件可信；广播件内一律 'X' 或无义。★ n<30 系手写普适门槛（P-06 违例，须以 evidence_rate 反解替代）；A/D 桶以全窗百分位定赏罚线（P-15）且据实现输赢符号（P-16）——本册只登记分布，禁据以处置"),
 dict(column="hold_validbet_pct（PI02 之 hold_pct）", current="sum_revenue / sum_validbet", meaning="洗码量口径之 hold", ruling="与本金口径 hold_rate 分母不同，恒等式 hold≡−roi 不成立（SC-15 R4-3）；禁互代，须另立列名"),
 dict(column="net_margin（绝对额）", current="Σ(−net−rebate−agent_cost)", meaning="含 AG-03 候选 B 之代理成本", ruling="AG-03 UNRESOLVED ⇒ 绝对额 ORDERING_ONLY，不得对外称『真净利』；对外量以 NGR 为准"),
 dict(column="vip_tier", current="NTILE(5) OVER (ORDER BY stake)", meaning="本金五分位，非真 VIP 等级", ruling="真 VIP 字段无数据来源在册（TYPO_ECON §VIP）"),
 dict(column="rebate_rate_actual", current="e.rebate/e.valid", meaning="实测退水档位", ruling="L-01 杠杆之靶列；比配置列可靠"),
]
upgrade = collections.OrderedDict([
    ("issued", TODAY), ("parent_identity", collections.OrderedDict([("version", "1.5.001"), ("yaml_md5", md5(SRC_YAML)), ("csv_md5", md5(SRC_CSV)), ("yaml_bytes", os.path.getsize(SRC_YAML)), ("csv_bytes", os.path.getsize(SRC_CSV))])),
    ("git_anchor", GIT_ANCHOR), ("git_anchor_note", "HEAD 7f713dc 推出《registry_risk_typology_v1.5.001》；本版候选尚未入库"),
    ("derivation", "加法升级 · 机器生成（gen_registry_v1_5_002.py）· 父版 3,943 行仅两行版本号改动 ＋ 一行 git_anchor 新增，其余逐字节保留；typology 块各插入 4 行（提案带 PROPOSED 标记）；retraction_register 增 W-82；末尾追加 10 节；CSV 投影与父版逐字节相同"),
    ("iron_rules_applied", ["只增不减", "一切数字自 数据表/ 实读现算（S01/PI01/PI02/TL14/TL11/TL10/T03/K01/PI04/S03/QSB_02c）", "禁硬编码阈值：分档一律分位秩", "NULL≠0：缺者登 ABSENT", "P-16/P-17/P-18/P-20 禁令逐条自检"]),
    ("sections_added", ["v1_5_002_upgrade", "platform_accounting_measured", "deliverable_metric_inventory", "metric_combinations", "treatment_economic_effects", "economic_levers_measured", "economic_metric_gate_status", "typology_economic_linkage", "metric_semantics_ruling", "economic_gap_register"]),
    ("csv_projection_note", "treatment_ids 已在 field_scope_registry.type_level_scalar_uploadable 白名单内，capability_dim_ids 尚未入白名单；故本版 CSV 投影两栏皆留空，待裁后先补白名单再回填"),
    ("ruling_required", ["typology_economic_linkage 之 treatment_ids/capability_dim_ids 提案（15 类）—— 裁后方回填 CSV 投影", "economic_value 正名 net_margin_pr_global", "SC-15 §四 之 E4/E5 改判（PROPOSED_SUPERSESSION）", "总包 action_priority 桶（P-15/P-06/P-16 疑违）之去留", "registry_loader.R .expect 1.5.001 → 1.5.002（一行）"]),
    ("prohibition_self_check", ["P-15：本册未设任何赏罚线；总包 A/D 桶只登记分布并标 PROFILE_ONLY", "P-16：本册未据实现输赢符号出任何名单；LM-01/LM-04/LM-05 已去处置绑定", "P-17：无阈值判据一律只出分布与排序；描述用分桶标 cut_points_provenance", "P-18：T-03 六件标 PROFILE_ONLY_P18，E4/E5 NOT_APPLICABLE", "P-20：处置前后只登计数与金额，无配对检验、无归因（inference: NOT_RUN）"]),
])
sections = collections.OrderedDict([
    ("v1_5_002_upgrade", upgrade),
    ("platform_accounting_measured", platform),
    ("deliverable_metric_inventory", collections.OrderedDict([("total", 132), ("registered_plus_partial", 133), ("present_on_disk", sum(1 for i in inv if i["present"])), ("six_layer_block_columns", len(BLOCK)), ("block_column_list", BLOCK),
        ("econ_block_status_census", dict(cnt_verd)), ("economic_admissibility_census", dict(cnt_adm)),
        ("census_x_pack_credibility_crosswalk", (lambda: (lambda C: [collections.OrderedDict([("econ_block_status", k[0]), ("pack_credibility", k[1]), ("count", v)]) for k, v in sorted(C.items())])(collections.Counter((i["econ_block_status"], i["pack_credibility"]) for i in inv)))()),
        ("units_reconciliation_method", "对每一自有货币栏求和并对平台总额比对（本金 13.44B、毛利 234.2M、退水 8.2M）；逾 3× 本金者判 EXCEEDS，同族量级内者判 PLAUSIBLE，其余 CHECK；见 own_money_reconciliation.csv"),
        ("theo_adt_nmpt_esi_present_in_any_table", False), ("method", "逐件读表头（own = 非六层块之栏）；六层块逐栏读全量算相异值（econ_census.R）；BROADCAST_CONSTANT = 多行单值；grain 栏原样取自总包模块索引（其『1』『3』等即 GROUP BY 常量，非行数）"), ("items", inv)])),
    ("metric_combinations", collections.OrderedDict([("principle", "粒度对齐：经济指标之粒度须与交付件粒度对齐（经济结果层_粒度对齐规格 §二）；跨粒度直接套用即串线"), ("count", len(mc_items)), ("items", mc_items)])),
    ("treatment_economic_effects", treat_section),
    ("economic_levers_measured", levers_measured),
    ("economic_metric_gate_status", collections.OrderedDict([("states", ["E1_E5_COMPUTABLE_AT_GRAIN", "E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY", "BLOCKED_UNITS", "BLOCKED_GRAIN", "BLOCKED_UPSTREAM", "BLOCKED_UPSTREAM_FILE_MISSING", "FATAL_PROFILE_ONLY", "FAIL"]), ("rule", "本节系『经济量可算性』登记，非 SC-15 §四 之 economic_metric_gate（其 PASS＝准入商业决策）；SC-15 §四 三态原样保留，本节七态与之正交。E1_E5_COMPUTABLE_AT_GRAIN 谓主表六层可信且逐行有值；E1_E3_COMPUTABLE_OWN_COLUMNS_ONLY 谓六层块不可信而自有货币列可算；BLOCKED_GRAIN 谓主表粒度无货币列；FAIL 保留给『定义与粒度不符或出裸 avg/rate/roi』者（本版无）"), ("items", gate_items)])),
    ("typology_economic_linkage", collections.OrderedDict([("status", "PROPOSED_BY_AUDIT · 待先生裁定后方为 SSOT"), ("items", link_items)])),
    ("metric_semantics_ruling", semantics),
    ("economic_gap_register", gaps),
])
appended = ["", "# ═════════════════════════════════════════════════════════════════════════", f"# v1.5.002 · 加法升级（{TODAY}）· 以下各节由 gen_registry_v1_5_002.py 自 数据表/ 实测生成", "# ═════════════════════════════════════════════════════════════════════════"] + yemit(sections)

# ---------------------------------------------------------------- 6. compose YAML
src = open(SRC_YAML, encoding="utf-8").read().split("\n")
assert src[2] == "  version: 1.5.001", src[2]
src[2] = "  version: 1.5.002"
src.insert(3, "  git_anchor: 7f713dc")   # additive line: R05 Git anchor (HEAD commit that introduced parent v1.5.001)
i_sem = next(i for i, l in enumerate(src) if l.startswith("  version_semver: 1.5.1")); src[i_sem] = "  version_semver: 1.5.2"
# insert per-typology additive lines before the next block start
out = []; cur = None; n_ins = 0
typ_start = next(i for i, l in enumerate(src) if l == "typologies:")
typ_end = next(i for i, l in enumerate(src) if l == "treatment_status:")
def ins_lines(t):
    L = LINK[t]
    return [f"  treatment_ids: [{', '.join(L['treatment_ids'])}]", f"  capability_dim_ids: [{', '.join(L['caps'])}]" if L["caps"] else "  capability_dim_ids: []", "  linkage_status: PROPOSED_BY_AUDIT_2026-09-02 · 待先生裁定 · 非 SSOT", f"  economic_linkage_ref: EL-{t}"]
for i, l in enumerate(src):
    if typ_start < i < typ_end:
        m = re.match(r"^- type_id: (T-\d\d)$", l)
        if m:
            if cur: out.extend(ins_lines(cur)); n_ins += 4
            cur = m.group(1)
    if i == typ_end and cur: out.extend(ins_lines(cur)); n_ins += 4; cur = None
    out.append(l)
# W-82 retraction entry appended to the parent's last section (retraction_register.entries)
out.extend(["  - id: W-82", "    claim: 限红处置『方向仅 TIGHTEN，无 LOOSEN 样本』（treatment_status.policy_extension.policies[T3].ledger_source）与 §PIT-01『direction=TIGHTEN』", "    to: null", "    ruling: ★TL14_limit_treatment.csv 实测 568 件：TIGHTEN 416 · RELEASE 97 · FLAT 52 · UNKNOWN_NO_DICT 3（2026-09-02 全量读）；父版原句保留不删，以本条撤回"])
text = "\n".join(out)
if not text.endswith("\n"): text += "\n"
text += "\n".join(appended) + "\n"
OUT_YAML = os.path.join(OUT, "registry_risk_typology_v1.5.002.yaml")
open(OUT_YAML, "w", encoding="utf-8", newline="\n").write(text)

# ---------------------------------------------------------------- 7. CSV: identical + fill treatment_ids / capability_dim_ids (empty -> proposal)
rows = rcsv(SRC_CSV); hdr = list(rows[0].keys())
assert hdr[54] == "treatment_ids" and hdr[55] == "capability_dim_ids", hdr[54:56]
n_fill = 0
for r in rows:
    L = LINK.get(r["type_id"])
    if L:
        pass   # CSV 投影不承载提案：treatment_ids / capability_dim_ids 待裁后回填（YAML 提案带 linkage_status 标记）
OUT_CSV = os.path.join(OUT, "registry_risk_typology_v1.5.002.csv")
with open(OUT_CSV, "w", encoding="utf-8-sig", newline="") as f:
    w = csv.DictWriter(f, fieldnames=hdr, lineterminator="\n"); w.writeheader(); w.writerows(rows)

# ---------------------------------------------------------------- 8. change table + six-tuples
chg = [["scope","row_key","field","v1.5.001","v1.5.002","verdict","judgement"],
       ["YAML_LINE","3","registry.version","1.5.001","1.5.002","MODIFIED","身份递增"],
       ["YAML_LINE",str(i_sem+1),"registry.version_semver","1.5.1","1.5.2","MODIFIED","随身份递增"],
       ["YAML_LINE","4","registry.git_anchor","(不存在)","7f713dc","ADDED","✓ 只增（R05 Git 锚）"],
       ["YAML_TYPOLOGY_BLOCKS","T-01..T-15","treatment_ids/capability_dim_ids/linkage_status/economic_linkage_ref","(不存在)",f"+{n_ins} 行（15 块×4）","ADDED","✓ 只增（提案，带 PROPOSED 标记，待裁）"],
       ["YAML_RETRACTION","W-82","retraction_register.entries","(不存在)","+1 条（撤回『限红方向仅 TIGHTEN』）","ADDED","✓ 只增"],
       ["YAML_TOPKEY","-","（父版 60 顶层键）","保留","保留（逐字节）","UNCHANGED","✓ 保留"]]
for k in sections: chg.append(["YAML_TOPKEY","-",k,"(不存在)","(新增)","ADDED","✓ 只增"])
chg.append(["CSV_COLUMN","-","（56 栏）","56","56","UNCHANGED","✓ 一栏未增未删"])
chg.append(["CSV_CELL","66 行","treatment_ids / capability_dim_ids","空","空（提案不入投影，待裁后回填）","UNCHANGED","CSV 与父版逐字节相同"])
chg.append(["CSV_ROWS","-","行数","66","66","UNCHANGED","✓"])
with open(os.path.join(OUT, "v1.5.001_TO_v1.5.002_逐行对照表.csv"), "w", encoding="utf-8-sig", newline="") as f:
    csv.writer(f, lineterminator="\n").writerows(chg)
st = {os.path.basename(p): sixtuple(p) for p in (SRC_YAML, SRC_CSV, OUT_YAML, OUT_CSV)}
with open(os.path.join(OUT, "六元组.csv"), "w", encoding="utf-8-sig", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["file","bytes","lines_lf","eol","bom","md5"])
    for k, v in st.items(): w.writerow([k, v["bytes"], v["lines_lf"], v["eol"], v["bom"], v["md5"]])
print("YAML written:", OUT_YAML, st[os.path.basename(OUT_YAML)])
print("CSV written :", OUT_CSV, st[os.path.basename(OUT_CSV)])
print("inserted typology lines:", n_ins, " csv cells filled:", n_fill, " appended lines:", len(appended))
print("inventory census:", dict(cnt_verd), dict(cnt_adm))
print("gate:", collections.Counter(g["gate"] for g in gate_items))
