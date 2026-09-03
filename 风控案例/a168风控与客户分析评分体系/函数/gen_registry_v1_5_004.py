# -*- coding: utf-8 -*-
"""
gen_registry_v1_5_004.py  --  加法升级（机器派生 · 只增不减）
registry_risk_typology_v1.5.003  ->  v1.5.004

裁定（Ryo Eng · 2026-09-03）：「全权依照先生之见斧正」——承先生问「何谓 RC-01 与 CD-01」之查证结论：
  该二编号系本会话临时所铸，无 SSOT 地位；且 RC-01 与既有 H 轴源系统码 H-SRC-01（支付／资金）
  实质冲突——全库含 RC-01 字串者 78 档，其中 76 档实为 H-SRC-01，误中率约 97%。
  另《版本编号纪律 v1.0.0》只规范版本号，未规范缺陷编号前缀，属纪律空白。

本版三事（皆只增不减）：
  ① open_questions 追加 OQ-13（代理名册无快照锁）与 OQ-14（#133 测试线连接之 CAST 口径分歧），
     以取代临时编号 RC-01 与 CD-01，使二者取得 SSOT 地位并可被校验器机检。
  ② 新增顶层键 id_namespace_registry —— 编号前缀命名空间登记，补纪律空白，防再铸冲突之号。
  ③ 头块身份四行递增；registry.parent 指真正父版 v1.5.003（承 v1.5.003 之 R04b 闸）。

判据层 66 行、十五 typology 块、既有 OQ-01~OQ-12、及此前追加各节，一字未改；CSV 与父版逐字节相同。
"""
import hashlib, os, shutil, csv, sys
sys.stdout.reconfigure(encoding="utf-8")

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = os.path.join(PROJ, "规范")
SRC_YAML = os.path.join(SPEC, "registry_risk_typology_v1.5.003.yaml")
SRC_CSV  = os.path.join(SPEC, "registry_risk_typology_v1.5.003.csv")
DST_YAML = os.path.join(SPEC, "registry_risk_typology_v1.5.004.yaml")
DST_CSV  = os.path.join(SPEC, "registry_risk_typology_v1.5.004.csv")
DST_MAP  = os.path.join(SPEC, "v1.5.003_TO_v1.5.004_逐行对照表.csv")
TODAY = "2026-09-03"
GIT_ANCHOR = "24b8d8d"

def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""): h.update(chunk)
    return h.hexdigest()

src = open(SRC_YAML, "rb").read()
assert b"\r\n" not in src and src[:3] != b"\xef\xbb\xbf", "父版 YAML 须 LF 无 BOM"
p_yaml_md5, p_csv_md5 = md5(SRC_YAML), md5(SRC_CSV)
p_yaml_bytes, p_csv_bytes = os.path.getsize(SRC_YAML), os.path.getsize(SRC_CSV)
lines = src.decode("utf-8").split("\n")
assert lines[-1] == "", "父版须以 LF 结尾"

changes = []
def expect(i, pfx): assert lines[i-1].startswith(pfx), f"L{i} 非预期：{lines[i-1][:70]!r}"
def setline(i, field, new, verdict, judgement):
    changes.append((i, field, lines[i-1], new, verdict, judgement)); lines[i-1] = new

# ── 身份四行 ──
expect(3, "  version: 1.5.003");        setline(3, "registry.version", "  version: 1.5.004", "MODIFIED", "身份递增")
expect(5, "  issued: '2026-09-03'");    setline(5, "registry.issued", f"  issued: '{TODAY}'", "UNCHANGED_VALUE", "同日签发")
expect(18, "  version_semver: 1.5.3");  setline(18, "registry.version_semver", "  version_semver: 1.5.4", "MODIFIED", "随身份递增")
expect(19, "  version_note: 身份名 1.5.003 为唯一权威")
setline(19, "registry.version_note",
        "  version_note: 身份名 1.5.004 为唯一权威；version_semver 仅供 git tag / renv 等须 SemVer 解析之工具链。盘上档名唯点号（承 SC-29）。",
        "MODIFIED", "身份名递增")
# ── parent 指向 v1.5.003（承 R04b 闸：parent.version 须等于校验器 parent_version）──
expect(21, "    version: 1.5.002");     setline(21, "registry.parent.version",    "    version: 1.5.003", "MODIFIED", "父版改指 v1.5.003")
expect(22, "    yaml_md5: ");           setline(22, "registry.parent.yaml_md5",   f"    yaml_md5: {p_yaml_md5}", "MODIFIED", "自盘上实读")
expect(23, "    csv_md5: ");            setline(23, "registry.parent.csv_md5",    f"    csv_md5: {p_csv_md5}", "MODIFIED", "自盘上实读")
expect(24, "    yaml_bytes: ");         setline(24, "registry.parent.yaml_bytes", f"    yaml_bytes: {p_yaml_bytes}", "MODIFIED", "自盘上实读")
expect(25, "    csv_bytes: ");          setline(25, "registry.parent.csv_bytes",  f"    csv_bytes: {p_csv_bytes}", "MODIFIED", "自盘上实读")
# ── revision_note 追加（原文一字未删）──
expect(6, '  revision_note: "'); assert lines[5].endswith('"')
rev_add = ("\\nv1.5.004：加法升级（2026-09-03）——① open_questions 追加 OQ-13（ods_a168_agent 全档 177 处取用无一带快照锁，"
           "测试线名册随时间漂移，注记 214 vs 实测 215）与 OQ-14（#133 测试线连接双侧 CAST AS BIGINT，而包内正典 139 处"
           "皆 varchar 直比，剔除集可能相异），以取代本会话临时所铸之 RC-01／CD-01——后者无 SSOT 地位，且 RC-01 与既有"
           "H 轴源系统码 H-SRC-01（支付／资金）实质冲突（全库 78 档含此字串，76 档实为 H-SRC-01，误中率约 97%）；"
           "② 新增顶层键 id_namespace_registry，登记编号前缀命名空间，补《版本编号纪律 v1.0.0》之空白；"
           "③ 头块身份四行递增、parent 改指 v1.5.003。判据层 66 行与既有各节一字未改；CSV 与父版逐字节相同。")
setline(6, "registry.revision_note", lines[5][:-1] + rev_add + '"', "APPENDED", "补 v1.5.004 条目（原文未删）")

# ── open_questions 追加两条（插于 OQ-12 之后、scoring_matrix 之前）──
i_sm = next(k for k, l in enumerate(lines) if l.startswith("scoring_matrix:"))
oq_new = [
 "- id: OQ-13",
 "  q: ods_a168_agent 全档 177 处取用无一处带快照锁；而注单侧恒锁 sync_time。测试线名册随时间漂移 ⇒ 同一 SQL 于不同日跑出不同剔除集。实测：包内七处 ta 注记书「公司测试线代理（214 条，跨五级）」，2026-09-03 实跑《函数/RK01_行数实测探针_v2_0_1.sql》§0 得 215（+1）。",
 "  severity: S1",
 "  scope: AGENT_DIM_TEMPORAL_REPRODUCIBILITY",
 "  evidence: 探针 §0 实测 215 ／ 包内注记 214 ／ 177 处取用零快照锁（2026-09-03 机检）",
 "  impact: 重导之剔除集不可复现 ⇒ 六元组失其意义；一切代理级分析之时点可比性存疑",
 "  action: 二选一并裁 —— 甲、冻结名册（导出该 215 条为 agent_roster_snapshot_v1.csv 并锁 md5，全批统一读取）；乙、补快照锁（须先证该表有可用之时间栏）。建议甲——该表未必有时间栏，且冻结档可入六元组。",
 "  blocked_until: 先生裁定（须在 P5D 全盘落盘之前，因其改变行集）",
 "  supersedes: 本会话临时编号 RC-01（无 SSOT 地位；且与既有 H-SRC-01 字串冲突，误中率约 97%）",
 "- id: OQ-14",
 "  q: 局级事实表 RK01（#133）之测试线连接双侧 CAST 至 BIGINT（承该件头注之 ID 铁律），而包内正典 x_testagent 与 ta 两族共 139 处皆以 varchar 直比（t1.aid = r.bet18，无 CAST）。",
 "  severity: S2",
 "  scope: CALIBER_DIVERGENCE_TESTLINE_JOIN",
 "  evidence: 包内 139 处正典无 CAST（2026-09-03 机检）；RK01 六锁下测试线剔 11,737 注单、0 局（探针 §2 L3→L4）",
 "  impact: 二者于前导零与空白之处置不同 ⇒ RK01 与其余 132 件可能剔不同的行，口径不同源",
 "  action: 二选一并裁 —— 甲、RK01 从正典去 CAST 与 132 件同源；乙、正典向 RK01 看齐补 CAST（跨 132 件之大改）。建议甲——口径同源重于单件严格；惟须重跑探针 §1 并回填 t_true（现值 6,048,562 可能变）。",
 "  blocked_until: 先生裁定（须在 P5D 全盘落盘之前，因其改变行集）",
 "  supersedes: 本会话临时编号 CD-01（无 SSOT 地位）",
]
lines[i_sm:i_sm] = oq_new + [""]
changes.append((f"OQ 段末", "open_questions", "OQ-01..OQ-12（12 条）", "OQ-01..OQ-14（14 条）", "ADDED",
                "✓ 只增：既有 12 条一字未改"))

# ── 档末追加 id_namespace_registry 与 v1_5_004_upgrade ──
tail = f"""
# ═════════════════════════════════════════════════════════════════════════
# id_namespace_registry · 编号前缀命名空间（v1.5.004 新增 · {TODAY}）
# ─────────────────────────────────────────────────────────────────────────
# 【立意】《版本编号纪律 v1.0.0》只规范版本号（三段式／禁跳级／身份非序号），
#   未规范【缺陷与议题编号之前缀】，属纪律空白。2026-09-03 本会话即因此空白而
#   自铸 RC-01／CD-01 二号，其中 RC-01 与既有 H-SRC-01（H 轴源系统码「支付／资金」，
#   自 v11 沿用至今并已写入两份交付件）实质冲突：全库 78 档含 RC-01 字串，76 档实为
#   H-SRC-01，误中率约 97%。本节即补此空白。
# 【铁律】新铸编号前，须先对本册与全库作字串冲突检索；命中既有者一律另择。
#   ⛔ 临时编号不得进入 SQL 注释或交付件——注释一旦入库即成事实标准，日后难以回收。
# ═════════════════════════════════════════════════════════════════════════
id_namespace_registry:
  issued: "{TODAY}"
  iron_rule: 新铸编号前须全库字串冲突检索；临时编号不得写入 SQL 注释或交付件
  reserved_prefixes:
    T: 风险类型（typologies）· T-01~T-15
    P: 全局禁令（global_prohibitions / prohibited_action_registry）· P-01~P-20
    B: 阻断项（blockers）· B-01~B-11
    W: 撤回登记（retraction_register）· W-38~W-85
    F: 缺陷发现（findings，总包侧主用）· F-1~F-47
    D: 设计缺陷（总包侧）· D-06 / D-14 / D-14b
    G: 门（gates）· G-04~G-07 / G01~G05
    OQ: 待裁议题（open_questions）· OQ-01~OQ-14
    EG: 经济缺口（economic_gap_register）· EG-01~EG-16
    SC: 役所定（规范裁定）· SC-15 / SC-25 / SC-29 / SC-31 / SC-32
    L: 经济杠杆（policy_lever_registry）· L-01~L-03
    MC: 指标搭配（metric_combinations）· MC-01~
    LM: 杠杆实测（economic_levers_measured）· LM-01~LM-06
    TZ: 时区／时轴· TZ-01~
    AG: 代理成本口径· AG-03
    CC: 会计口径校正· CC-01
    RT: 红队台账· RT-04~RT-12
    PIT: 处置台账· PIT-01
    Z: 总包章节· Z-00~Z-19
    TL: 处置台账件· TL-09~TL-14
    EX: 排除项· EX-00~EX-17b
    DX: 字典探针· DX-01~DX-05
    SRC: H 轴源系统· H-SRC-01~H-SRC-06（★ 注意：任何以 -RC- 结尾之新号皆与此冲突）
    R: 校验判据（verify_registry_dual）· R01~R25 / R24b
  forbidden_prefixes:
    RC: ⛔ 与 H-SRC-01 字串冲突（子串命中率约 97%）——永不启用
    CD: ⛔ 2026-09-03 曾临时使用，已由 OQ-14 取代——不另立缺陷册前，不启用
  retired_temporary_ids:
  - id: RC-01
    minted: "{TODAY}"
    minted_by: 本会话（Claude Code）
    superseded_by: OQ-13
    reason: 无 SSOT 地位；且与既有 H-SRC-01 字串冲突
  - id: CD-01
    minted: "{TODAY}"
    minted_by: 本会话（Claude Code）
    superseded_by: OQ-14
    reason: 无 SSOT 地位
  session_minted_pending_review:
    note: 本会话另铸下列编号，皆只见于施工报告（未入 SQL 注释与交付件），暂留待裁
    ids: [SQ-01~SQ-09（总包缺陷）, HB-01~HB-03（登记册头块缺陷）, CA-01, CA-02, RW-01, TS-01]
    action: 或并入 F-／OQ- 既有空间，或另立缺陷册并先定前缀；本版不擅改

# ═════════════════════════════════════════════════════════════════════════
# v1.5.004 · 加法升级（{TODAY}）· 由 gen_registry_v1_5_004.py 机器派生 · 只增不减
# ═════════════════════════════════════════════════════════════════════════
v1_5_004_upgrade:
  issued: "{TODAY}"
  parent_identity:
    version: "1.5.003"
    yaml_md5: {p_yaml_md5}
    csv_md5: {p_csv_md5}
    yaml_bytes: {p_yaml_bytes}
    csv_bytes: {p_csv_bytes}
  git_anchor: {GIT_ANCHOR}
  ruling: "Ryo Eng {TODAY}：『全权依照先生之见斧正』——承『何谓 RC-01 与 CD-01』之查证：临时编号退场，改登 OQ-13／OQ-14，另补编号前缀命名空间"
  sections_added: [open_questions（OQ-13, OQ-14 二条）, id_namespace_registry, v1_5_004_upgrade]
  unchanged: 判据层 66 行 · 十五 typology 块 · 既有 OQ-01~OQ-12 · v1_5_002_upgrade 起各节 · 一字未改；CSV 与父版逐字节相同
  cascade_required: [registry_loader.R .expect, rule_registry_loader.R 版本串＋RULES_PATH, verify_registry_dual.R VRD, report_config parent, 模板血统层]
"""
out = "\n".join(lines).rstrip("\n") + "\n" + tail.lstrip("\n")
assert "\r" not in out
open(DST_YAML, "wb").write(out.encode("utf-8"))
shutil.copyfile(SRC_CSV, DST_CSV)

rows = [("scope", "row_key", "field", "v1.5.003", "v1.5.004", "verdict", "judgement")]
for (i, field, old, new, verdict, judgement) in changes:
    o = str(old); n = str(new)
    rows.append(("YAML_LINE", str(i), field, (o[:77] + "…") if len(o) > 80 else o.strip(),
                 (n[:77] + "…") if len(n) > 80 else n.strip(), verdict, judgement))
rows.append(("YAML_SECTION", "tail", "id_namespace_registry", "(不存在)", "新增", "ADDED", "✓ 只增（补编号纪律空白）"))
rows.append(("YAML_SECTION", "tail", "v1_5_004_upgrade", "(不存在)", "新增", "ADDED", "✓ 只增"))
rows.append(("YAML_TYPOLOGY_BLOCKS", "T-01..T-15", "*", "逐字节保留", "逐字节保留", "UNCHANGED", "✓"))
rows.append(("CSV", "*", "*", p_csv_md5, md5(DST_CSV), "IDENTICAL", "✓ 与父版逐字节相同"))
with open(DST_MAP, "w", encoding="utf-8-sig", newline="\n") as f:
    csv.writer(f, lineterminator="\n").writerows(rows)

def six(p):
    b = open(p, "rb").read()
    nl, crlf, bom = b.count(b"\n"), b.count(b"\r\n"), b[:3] == b"\xef\xbb\xbf"
    return "%s | bytes=%d | lines=%d | eol=%s | bom=%s | md5=%s" % (os.path.basename(p), len(b), nl, "CRLF" if crlf else "LF", bom, md5(p))
print("父版 YAML md5", p_yaml_md5, "bytes", p_yaml_bytes)
for p in (DST_YAML, DST_CSV, DST_MAP): print(six(p))
print(f"改行 {len(changes)} 处；OQ 12 → 14 条")
