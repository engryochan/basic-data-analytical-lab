#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
§Z-13 · 哨兵值与脏值前置净化审计（v2 · 精确语句边界）
只核实，不改源文件。
"""
import re, os, json, hashlib, unicodedata
import pandas as pd

SRC = "/mnt/user-data/uploads/a168_取数与核验_SQL总包_v2斧正版.sql"
OUT = "/mnt/user-data/outputs"
os.makedirs(OUT, exist_ok=True)

raw = open(SRC, "rb").read()
text = raw.decode("utf-8")
lines = text.split("\n")

# ── 版本身份六元组 ──────────────────────────────────────────────────
lf = raw.replace(b"\r\n", b"\n")
IDENT = {
    "文件名": os.path.basename(SRC),
    "行数": len(lines) - (1 if lines[-1] == "" else 0),
    "字节数_原样CRLF": len(raw),
    "字节数_LF归一": len(lf),
    "MD5_原样CRLF": hashlib.md5(raw).hexdigest(),
    "MD5_LF归一": hashlib.md5(lf).hexdigest(),
    "换行制式": "CRLF",
    "编码": "UTF-8 (no BOM)",
}
IDENT["字节差"] = IDENT["字节数_原样CRLF"] - IDENT["字节数_LF归一"]
IDENT["字节差判读"] = ("✅ 恰等于行数 → 纯换行制式差异，非版本冲突"
                     if IDENT["字节差"] == IDENT["行数"] else "⚠ 不等于行数，须查")

# ── 乱码 / 不可见字符 / 同形异码 全文扫描 ───────────────────────────
BAD_CHARS = {
    "U+FFFD 替换符(乱码铁证)": "\ufffd",
    "U+00A0 不间断空格": "\u00a0",
    "U+3000 全角空格": "\u3000",
    "U+200B 零宽空格": "\u200b",
    "U+200E/200F 方向标记": "\u200e\u200f",
    "U+FEFF 零宽不断空格/BOM": "\ufeff",
    "制表符 TAB": "\t",
}
charscan = []
for name, chars in BAD_CHARS.items():
    hits = [(i + 1, ln) for i, ln in enumerate(lines) if any(c in ln for c in chars)]
    charscan.append({"字符类": name, "命中行数": len(hits),
                     "首现行": hits[0][0] if hits else "",
                     "判读": "⛔ 须清" if hits and "FFFD" in name else
                             ("⚠ 建议清" if hits else "✅ 零")})

# 全角标点混入 SQL 代码区（易致语法错或静默串值）
FULLWIDTH = "（）；，＝’＇“”％－"
fw_hits = []   # 延后到剥注释之后再扫

# ── 剥注释 ──────────────────────────────────────────────────────────
def strip_comments(s):
    out = []; i = 0; n = len(s)
    blk = lin = strq = False
    while i < n:
        c = s[i]; nx = s[i+1] if i+1 < n else ""
        if blk:
            if c == "*" and nx == "/": blk = False; i += 2; out.append("  "); continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if lin:
            if c == "\n": lin = False; out.append("\n")
            else: out.append(" ")
            i += 1; continue
        if strq:
            out.append(c)
            if c == "'": strq = False
            i += 1; continue
        if c == "/" and nx == "*": blk = True; i += 2; out.append("  "); continue
        if c == "-" and nx == "-": lin = True; i += 2; out.append("  "); continue
        if c == "'": strq = True; out.append(c); i += 1; continue
        out.append(c); i += 1
    return "".join(out)

code = strip_comments(text)
clines = code.split("\n")
# 全角标点只扫**代码区**（注释区用全角是行文，非缺陷）
for i, ln in enumerate(clines):
    if any(c in ln for c in FULLWIDTH):
        fw_hits.append(i + 1)

# ── 语句切分（裸分号）＋ 精确首行 ───────────────────────────────────
KW = re.compile(r"^\s*(WITH|SELECT|SET|SHOW|INSERT|CREATE)\b", re.I)
stmts = []; start = 0
bounds = [m.end() for m in re.finditer(r";", code)] + [len(code)]
for end in bounds:
    seg = code[start:end]
    if seg.strip():
        l0 = code[:start].count("\n")
        first = None
        for off, ln in enumerate(seg.split("\n")):
            if KW.match(ln): first = l0 + off + 1; break
        if first is None:
            first = l0 + 1 + next((o for o, ln in enumerate(seg.split("\n"))
                                   if ln.strip()), 0)
        stmts.append({"首行": first, "末行": code[:end].count("\n") + 1, "sql": seg})
    start = end

def kind(sql):
    u = sql.upper()
    if re.search(r"\bSET\s+SESSION\b", u): return "会话参数"
    if re.search(r"^\s*SHOW\b", u, re.M): return "SHOW"
    if re.search(r"\bSELECT\b", u): return "查询"
    return "其他"
for s in stmts: s["类型"] = kind(s["sql"])
queries = [s for s in stmts if s["类型"] == "查询"]

# ── 段号：自首行向上找最近的段标题 ─────────────────────────────────
HEAD = re.compile(r"(?:§\s*([A-Za-z][A-Za-z0-9]{0,3}-?\d{0,3}[a-z]?)|"
                  r"^\s{0,8}([A-Z]{1,3}-\d{1,2}[a-zA-Z]?))\s*(?:·|·)")
def sec_of(first):
    for i in range(first - 1, max(-1, first - 60), -1):
        m = HEAD.search(lines[i])
        if m: return (m.group(1) or m.group(2))
    return "?"

# ── 导出声明：自首行向上找 ▸ 导出 ──────────────────────────────────
EXP = re.compile(r"▸\s*导出[:：]\s*(需要|不需要|⛔)")
FN  = re.compile(r"数据库/([A-Za-z0-9_\u4e00-\u9fa5]+\.csv)")
def export_of(first):
    for i in range(first - 1, max(-1, first - 60), -1):
        m = EXP.search(lines[i])
        if m:
            fn = FN.search(lines[i])
            return m.group(1), (fn.group(1) if fn else "")
        if re.search(r"▸\s*导出[:：]\s*「数据库/", lines[i]):
            fn = FN.search(lines[i]); return "需要", (fn.group(1) if fn else "")
    return "", ""

GUARDS = {
    "剔测试线_age022":   r"age022\s*=\s*'1'",
    "版本去重_rn1":      r"\brn\s*=\s*1\b",
    "一般注单_category": r"category\s*=\s*'1'",
    "非重对_bet38":      r"bet38\s*\)*\s*=\s*'N'",
    "会员号_gt0":        r"bet05[^>]{0,60}>\s*0",
    "汇率_gt0":          r"bet11[^>]{0,60}>\s*0",
    "荷官哨兵_eid":      r"(eid|dealer_id)\s*\)?\s*NOT\s+IN\s*\(|is_sentinel",
    "空串归NULL":        r"NULLIF\s*\(\s*TRIM",
    "显式转型_CAST":     r"CAST\s*\(",
    "零除守卫":          r"NULLIF\s*\([^)]{0,60},\s*0\s*\)|pmax|GREATEST\s*\(",
    "百家乐_101":        r"bet02\s*=\s*'101'|gi001\s*=\s*'101'",
    "窗口谓词_dt":       r"dt\s*>=\s*'20\d\d-\d\d-\d\d'|gi004\s*>=\s*'20",
}
AGG = re.compile(r"\b(SUM|COUNT|AVG|MIN|MAX|STDDEV|PERCENTILE|GROUP\s+BY)\b", re.I)
TBL = re.compile(r"ods_mariadb_2b\.(ods_a168_\w+)|(information_schema)\.\w+")

rows = []
for q in queries:
    sql = q["sql"]
    tabs = sorted({(m.group(1) or m.group(2)) for m in TBL.finditer(sql)})
    sec = sec_of(q["首行"]); exp, fn = export_of(q["首行"])
    is_meta = "information_schema" in tabs
    hdr = "\n".join(lines[max(0, q["首行"] - 45):q["首行"]])
    is_inventory = bool(re.search(r"哨兵|普查|一览|清单|字典|侦测|占比|覆盖端点|时区|"
                                  r"COUNT\s*预检|行数复核|列名核对", hdr))
    # ★ 一览豁免只给「无交付件」或「Z0x/清单类交付件」者。
    #   凡产出分析用交付件者，一律不得豁免——一览之名不能成为带哨兵入库的通道。
    if fn and not re.match(r"(Z0\d|V_table_counts|TL00|TL11c_population)", fn):
        is_inventory = False
    r = {"首行": q["首行"], "末行": q["末行"], "段号": sec,
         "导出": exp or "(未声明)", "交付件": fn,
         "涉表": "、".join(tabs) or "(仅CTE)",
         "触注单主表": "是" if "ods_a168_bet02" in tabs else "否",
         "含聚合": "是" if AGG.search(sql) else "否",
         "豁免候选": "元数据" if is_meta else ("一览/占比" if is_inventory else "")}
    for k, p in GUARDS.items():
        r[k] = "✓" if re.search(p, sql, re.I) else ""
    rows.append(r)

df = pd.DataFrame(rows)

BASE4 = ["剔测试线_age022", "版本去重_rn1", "一般注单_category", "非重对_bet38"]
CLEAN = ["空串归NULL", "显式转型_CAST"]

def verdict(r):
    if r["豁免候选"] == "元数据":
        return "豁免·元数据(information_schema)"
    if r["触注单主表"] == "否":
        return "旁路·未触注单主表"
    if r["含聚合"] == "否":
        return "免检·非聚合"
    miss = [g for g in BASE4 if not r[g]]
    if miss:
        if r["豁免候选"] == "一览/占比":
            return "豁免·一览/占比（缺 " + "、".join(g.split("_")[0] for g in miss) + "）"
        return "⛔ 缺闸：" + "、".join(g.split("_")[0] for g in miss)
    m2 = [g for g in CLEAN if not r[g]]
    if m2:
        return "⚠ 净化不全：" + "、".join(m2)
    return "✅ 合规"

df["裁定"] = df.apply(verdict, axis=1)
df["优先级"] = df.apply(
    lambda r: "P0 交付件" if r["裁定"].startswith("⛔") and r["交付件"] else
              ("P1 屏幕核验" if r["裁定"].startswith("⛔") else
               ("P2" if r["裁定"].startswith("⚠") else "—")), axis=1)

df.to_csv(os.path.join(OUT, "Z13_哨兵与脏值前置净化审计矩阵.csv"),
          index=False, encoding="utf-8-sig")
pd.DataFrame(charscan).to_csv(os.path.join(OUT, "Z14_不可见字符与乱码全文扫描.csv"),
                              index=False, encoding="utf-8-sig")

print("=" * 78)
print("§Z-13 哨兵值与脏值前置净化审计 · 结论")
print("=" * 78)
print("\n【版本身份六元组】")
for k, v in IDENT.items(): print(f"  {k:18s} {v}")

print("\n【不可见字符 / 乱码全文扫描】")
for c in charscan: print(f"  {c['字符类']:26s} 命中 {c['命中行数']:>5} 行  {c['判读']}")
print(f"  {'全角标点混入代码区':26s} 命中 {len(fw_hits):>5} 行  "
      f"{'⚠ 须逐行确认' if fw_hits else '✅ 零'}")
if fw_hits[:12]: print("    首现行：", fw_hits[:12])

print(f"\n【语句切分】裸分号 {len(stmts)} 条；查询 {len(queries)} 条")
print("\n【裁定汇总】")
vs = df["裁定"].str.replace(r"[（:：].*$", "", regex=True).value_counts()
for k, v in vs.items(): print(f"  {k:34s} {v:>4}")

print("\n【P0 · 交付件缺闸（必须先处置再取数）】")
p0 = df[df["优先级"] == "P0 交付件"]
if len(p0) == 0: print("  ✅ 无")
for _, r in p0.iterrows():
    print(f"  行{r['首行']:>5}  §{r['段号']:<9} {r['交付件']:<34} {r['裁定']}")

print("\n【P1 · 屏幕核验类缺闸】")
p1 = df[df["优先级"] == "P1 屏幕核验"]
for _, r in p1.iterrows():
    print(f"  行{r['首行']:>5}  §{r['段号']:<9} {r['裁定']}")

print("\n【P2 · 净化不全】")
p2 = df[df["优先级"] == "P2"]
for _, r in p2.iterrows():
    print(f"  行{r['首行']:>5}  §{r['段号']:<9} {r['交付件']:<30} {r['裁定']}")

print("\n【✅ 合规】")
for _, r in df[df["裁定"] == "✅ 合规"].iterrows():
    print(f"  行{r['首行']:>5}  §{r['段号']:<9} {r['交付件']}")

json.dump(IDENT, open("/home/claude/work/ident.json", "w"), ensure_ascii=False, indent=2)
df.to_pickle("/home/claude/work/audit2.pkl")
