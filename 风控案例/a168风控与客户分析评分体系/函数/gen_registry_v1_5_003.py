# -*- coding: utf-8 -*-
"""
gen_registry_v1_5_003.py  --  头块补正生成器（机器派生 · 只增不减）
registry_risk_typology_v1.5.002  ->  v1.5.003

裁定（Ryo Eng · 2026-09-03）：v1.5.002 头块补正为 v1.5.003，只改 parent／version_note／revision_note 三处，
并于校验器 verify_registry_dual.R 增一条闸「registry.parent.version 须等于 VRD$parent_version」（R04b）。

缺陷（2026-09-03 审计发现）：v1.5.002 由 gen_registry_v1_5_002.py「头块逐字节保留」派生，致
  ① registry.parent 仍指祖父 v1.5.0（md5 f9eb7af3…／d2b79045…），真正父版 v1.5.001 之身份只登于档末 v1_5_002_upgrade；
  ② version_note 仍称「身份名 1.5.001 为唯一权威」；
  ③ revision_note 无 v1.5.002 条目。
  校验器 R04 只检 parent 非空，故 23 PASS 而未捕。

本器规则：
  * 父版 10,677 行逐字节保留，仅改第 3／4／5／6／18／19／21～26 行（身份四行 ＋ 裁定三处），末尾追加 v1_5_003_upgrade 一节。
  * 判据层 66 行、十五 typology 块、已追加十节一字未改。
  * CSV 投影与父版逐字节相同（registry.version 不在 CSV 内）。
  * 输出 UTF-8 · LF · YAML 无 BOM ／ CSV 带 BOM（承 SC-25）。
  * 一切 md5／字节数自盘上实读，不手写。
"""
import hashlib, os, shutil, csv, io, sys
sys.stdout.reconfigure(encoding="utf-8")

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = os.path.join(PROJ, "规范")
SRC_YAML = os.path.join(SPEC, "registry_risk_typology_v1.5.002.yaml")
SRC_CSV  = os.path.join(SPEC, "registry_risk_typology_v1.5.002.csv")
DST_YAML = os.path.join(SPEC, "registry_risk_typology_v1.5.003.yaml")
DST_CSV  = os.path.join(SPEC, "registry_risk_typology_v1.5.003.csv")
DST_MAP  = os.path.join(SPEC, "v1.5.002_TO_v1.5.003_逐行对照表.csv")
TODAY = "2026-09-03"
GIT_ANCHOR = "24b8d8d"   # HEAD「整合」——将 v1.5.002 提升为载入器目标版之提交（已推送）

def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

src = open(SRC_YAML, "rb").read()
assert b"\r\n" not in src and src[:3] != b"\xef\xbb\xbf", "父版 YAML 须 LF 无 BOM"
p_yaml_md5, p_csv_md5 = md5(SRC_YAML), md5(SRC_CSV)
p_yaml_bytes, p_csv_bytes = os.path.getsize(SRC_YAML), os.path.getsize(SRC_CSV)
lines = src.decode("utf-8").split("\n")          # 末元素为 '' （档末换行）
assert lines[-1] == "", "父版须以 LF 结尾"

def expect(i, startswith):
    assert lines[i-1].startswith(startswith), f"L{i} 非预期：{lines[i-1][:60]!r}"

changes = []   # (line_no, field, old, new, verdict, judgement)
def setline(i, field, new, verdict, judgement):
    old = lines[i-1]; lines[i-1] = new; changes.append((i, field, old, new, verdict, judgement))

# ── 身份四行 ──
expect(3, "  version: 1.5.002");          setline(3, "registry.version", "  version: 1.5.003", "MODIFIED", "身份递增")
expect(4, "  git_anchor: 7f713dc");       setline(4, "registry.git_anchor", f"  git_anchor: {GIT_ANCHOR}", "MODIFIED", "锚改指提升 v1.5.002 之提交（R05）")
expect(5, "  issued: '2026-09-02'");      setline(5, "registry.issued", f"  issued: '{TODAY}'", "MODIFIED", "签发日")
expect(18, "  version_semver: 1.5.2");    setline(18, "registry.version_semver", "  version_semver: 1.5.3", "MODIFIED", "随身份递增")

# ── 裁定三处 ──
expect(6, '  revision_note: "'); assert lines[5].endswith('"'), "L6 须以双引号收尾"
rev_add = (
    "\\nv1.5.002：加法升级（2026-09-02，锚 7f713dc）——十五 typology 块各插 treatment_ids／capability_dim_ids／"
    "linkage_status／economic_linkage_ref 四行（PROPOSED_BY_AUDIT，待裁，非 SSOT）、retraction_register 增 W-82、"
    "末尾追加 platform_accounting_measured 等十节（自 数据表/ 实测生成）；CSV 投影与父版逐字节相同。"
    "\\nv1.5.003：头块补正（2026-09-03，锚 24b8d8d）——父版 registry.parent 仍指祖父 v1.5.0、version_note 仍称 1.5.001、"
    "revision_note 缺 v1.5.002 条目（2026-09-03 审计发现；校验器 R04 只检非空故未捕）。本版只改 parent／version_note／"
    "revision_note 三处（Ryo Eng 裁定），并于校验器增 R04b「registry.parent.version 须等于校验器 parent_version」。"
    "判据层 66 行、十五 typology 块、已追加十节一字未改；CSV 与父版逐字节相同。"
)
setline(6, "registry.revision_note", lines[5][:-1] + rev_add + '"', "APPENDED", "补 v1.5.002 条目 ＋ v1.5.003 条目（原文一字未删）")
expect(19, "  version_note: 身份名 1.5.001 为唯一权威")
setline(19, "registry.version_note",
        "  version_note: 身份名 1.5.003 为唯一权威；version_semver 仅供 git tag / renv 等须 SemVer 解析之工具链。盘上档名唯点号（承 SC-29）。",
        "MODIFIED", "身份名由 1.5.001（陈旧）改 1.5.003")
expect(20, "  parent:")
expect(21, "    version: 1.5.0");     setline(21, "registry.parent.version",    "    version: 1.5.002", "MODIFIED", "父版由祖父 v1.5.0 改指真正父版 v1.5.002")
expect(22, "    yaml_md5: f9eb7af3"); setline(22, "registry.parent.yaml_md5",   f"    yaml_md5: {p_yaml_md5}", "MODIFIED", "自盘上实读")
expect(23, "    csv_md5: d2b79045");  setline(23, "registry.parent.csv_md5",    f"    csv_md5: {p_csv_md5}", "MODIFIED", "自盘上实读")
expect(24, "    yaml_bytes: 57938");  setline(24, "registry.parent.yaml_bytes", f"    yaml_bytes: {p_yaml_bytes}", "MODIFIED", "自盘上实读")
expect(25, "    csv_bytes: 50110");   setline(25, "registry.parent.csv_bytes",  f"    csv_bytes: {p_csv_bytes}", "MODIFIED", "自盘上实读")
expect(26, "    derivation: 加法升级 · 机器派生 · 只增不减")
setline(26, "registry.parent.derivation", "    derivation: 头块补正 · 机器派生（gen_registry_v1_5_003.py）· 只增不减 · 判据层与已追加十节一字未改",
        "MODIFIED", "派生方式")

# ── 档末追加一节（只增）──
tail = f"""
# ═════════════════════════════════════════════════════════════════════════
# v1.5.003 · 头块补正（{TODAY}）· 由 gen_registry_v1_5_003.py 机器派生 · 只增不减
# ═════════════════════════════════════════════════════════════════════════
v1_5_003_upgrade:
  issued: "{TODAY}"
  parent_identity:
    version: "1.5.002"
    yaml_md5: {p_yaml_md5}
    csv_md5: {p_csv_md5}
    yaml_bytes: {p_yaml_bytes}
    csv_bytes: {p_csv_bytes}
  git_anchor: {GIT_ANCHOR}
  git_anchor_note: HEAD {GIT_ANCHOR}「整合」——将 v1.5.002 提升为载入器目标版之提交（已推送 origin）；本版候选尚未入库
  ruling: "Ryo Eng {TODAY}：v1.5.002 头块补正为 v1.5.003，只改 parent／version_note／revision_note 三处；校验器增 R04b（registry.parent.version 须等于 VRD$parent_version）"
  defect_corrected:
    - id: HB-01
      field: registry.parent
      was: "version 1.5.0 · yaml_md5 f9eb7af3… · csv_md5 d2b79045…（祖父版）"
      now: "version 1.5.002 · yaml_md5 {p_yaml_md5[:8]}… · csv_md5 {p_csv_md5[:8]}…（真正父版，自盘上实读）"
      root_cause: gen_registry_v1_5_002.py 头块逐字节保留，未随版更新 parent
      why_uncaught: 校验器 R04 只检 parent.yaml_md5／csv_md5 非空，不比对 parent.version 与校验器 parent_version
    - id: HB-02
      field: registry.version_note
      was: 身份名 1.5.001 为唯一权威
      now: 身份名 1.5.003 为唯一权威
    - id: HB-03
      field: registry.revision_note
      was: 止于 v1.5.001 条目
      now: 补 v1.5.002 与 v1.5.003 两条目（原文一字未删）
  identity_lines_changed: [3, 4, 5, 18]
  ruling_lines_changed: [6, 19, 21, 22, 23, 24, 25, 26]
  unchanged: 判据层 66 行 · 十五 typology 块 · v1_5_002_upgrade 起十节 · 一字未改；CSV 投影与父版逐字节相同
  supersedes_note: v1_5_002_upgrade.ruling_required 之「registry_loader.R .expect 1.5.001 → 1.5.002」已于 N-2A（2026-09-03）完成；该条原文保留不删
  verifier_gate_added: "R04b · 父版身份自洽：YAML registry.parent.version 须等于校验器 VRD$parent_version（verify_registry_dual.R 1.2.0）"
"""
out = "\n".join(lines).rstrip("\n") + "\n" + tail.lstrip("\n")
assert "\r" not in out
with open(DST_YAML, "wb") as f:
    f.write(out.encode("utf-8"))
shutil.copyfile(SRC_CSV, DST_CSV)

# ── 逐行对照表（承 v1.5.001_TO_v1.5.002 体例：UTF-8-BOM · LF）──
rows = [("scope", "row_key", "field", "v1.5.002", "v1.5.003", "verdict", "judgement")]
for (i, field, old, new, verdict, judgement) in changes:
    o = old if len(old) <= 80 else old[:77] + "…"
    n = new if len(new) <= 80 else new[:77] + "…"
    rows.append(("YAML_LINE", str(i), field, o.strip(), n.strip(), verdict, judgement))
rows.append(("YAML_SECTION", "tail", "v1_5_003_upgrade", "(不存在)", f"+{tail.count(chr(10))-1} 行", "ADDED", "✓ 只增（头块补正登记）"))
rows.append(("YAML_TYPOLOGY_BLOCKS", "T-01..T-15", "*", "逐字节保留", "逐字节保留", "UNCHANGED", "✓"))
rows.append(("YAML_SECTIONS", "v1_5_002_upgrade..economic_gap_register", "*", "逐字节保留", "逐字节保留", "UNCHANGED", "✓"))
rows.append(("CSV", "*", "*", p_csv_md5, md5(DST_CSV), "IDENTICAL", "✓ 与父版逐字节相同"))
with open(DST_MAP, "w", encoding="utf-8-sig", newline="\n") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerows(rows)

def six(p):
    b = open(p, "rb").read()
    nl, crlf, bom = b.count(b"\n"), b.count(b"\r\n"), b[:3] == b"\xef\xbb\xbf"
    return "%s | bytes=%d | lines=%d | eol=%s | bom=%s | md5=%s" % (os.path.basename(p), len(b), nl, "CRLF" if crlf else "LF", bom, md5(p))
print("父版 YAML md5", p_yaml_md5, "bytes", p_yaml_bytes)
for p in (DST_YAML, DST_CSV, DST_MAP): print(six(p))
print(f"改行数 {len(changes)}；追加 {tail.count(chr(10))-1} 行；对照表 {len(rows)-1} 行")
