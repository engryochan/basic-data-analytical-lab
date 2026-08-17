#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID    V-A168-QMS-RUNNER-004
 VERSION         1.0.0
 PURPOSE         单一入口编排器：寻径 → 四层内容指纹 → 声明扫描 → 登记簿 → 闸门
                 使「三件工具」成为「一套系统」——分界在【跨次持有状态并据以设闸】

 四层内容指纹
   L0 档级   六元组（行数/字节/MD5/SHA256/行尾/编码）      → 变了没有
   L1 节级   章节树 ＋ 每节 SHA-256                        → 变在哪一节
   L2 块级   围栏代码块／YAML 之 SHA-256                    → 变在哪一块
   L3 声明级 (术语,值,行) 之集合指纹                         → 变的是哪一条声明

 NOT-CAPABLE-OF（本器不能回答）
   · 变更是否【正当】（只报变更位置，不裁对错）
   · 何者为最新版（同名异容仅告警，不裁）
   · 声明之语义作用域（引述 vs 主张）
   · 首次执行时之「上次」——无 baseline 即无 diff，须明记为 ⚪ 不可证

 SC-LINKED-DEFECTS
   SC-003  输出截断而自称未截断     → 全量落 JSON，终端仅摘要并印总数
   SC-029  通配降级致计数器零验证力 → 逐档指名；零命中必败
   SC-032  同名异容碰撞             → 寻径器强制列全部候选
   SC-043  规模化特异度缺失         → 沿用 v2.1 置换检验
   SC-046  gold 未经语料确认        → 沿用 v2.1 已修 gold

 GATE（任一不过即全局 BLOCKED，不出结论）
   QG-2 验证器闸：任一子器控制层失败 → BLOCKED
   QG-4 变更闸：L0 指纹与登记簿不符 → 该档结论进入 IMPACT REVIEW，不得沿用

 STOP-ANCHOR  A1 哈希与计数为纯算术
              A2 机械可复算（登记簿为纯文本，任何人可重算比对）
              A3 判据于看结果前写死

 CERTIFICATION UNCERTIFIED —— 控制层全过方可标 CERTIFIED
================================================================================
"""
import os, re, sys, json, glob, hashlib, datetime, importlib.util
from collections import defaultdict

REG_NAME = "QMS_REGISTRY.json"

MANIFEST = [
    "a168风控与客户分层评分体系_商业方案.qmd",
    "a168风控评分_精要商业报告.qmd",
    "a168商业决策计数兵法_三十三问经.qmd",
    "a168_能力值口径解读_SQL转R_v7_2.qmd",
    "a168_取数与核验_SQL总包_v3.sql",
    "a168_处置账与结果账_建账规格_v1.sql",
    "a168_评分误判率与失误率最小化_专题方案_v3_9.qmd",
    "分析异常IP与尾秒投注的风控与降低误判_v8.qmd",
    "a168_全库结构与哨兵值审计_SQL_v5.sql",
    "a168_第二阶段_口径固化与相位派生_SQL_K层_v2.sql",
]

# v3 §一 所载六元组（🟠 转录，非本器实测）—— 供 L0 对账
V3_REGISTERED = {
    "a168风控与客户分层评分体系_商业方案.qmd":            (17386, 1210284, "32b0c463"),
    "a168风控评分_精要商业报告.qmd":                     (6829,   529758, "b732c7f5"),
    "a168商业决策计数兵法_三十三问经.qmd":                 (3433,   267300, "81f6c743"),
    "a168_能力值口径解读_SQL转R_v7_2.qmd":               (2520,   202930, "08141c80"),
    "a168_取数与核验_SQL总包_v3.sql":                    (7964,  1051529, "f0027651"),
    "a168_处置账与结果账_建账规格_v1.sql":                 (210,     18109, "919bd2cc"),
    "a168_评分误判率与失误率最小化_专题方案_v3_9.qmd":       (2662,   210378, "d86e4830"),
    "分析异常IP与尾秒投注的风控与降低误判_v8.qmd":            (1504,    78095, "2921110f"),
    "a168_全库结构与哨兵值审计_SQL_v5.sql":                (687,     47883, "0943b44d"),
    "a168_第二阶段_口径固化与相位派生_SQL_K层_v2.sql":      (832,     50026, "5bb0fb5e"),
}

H = re.compile(r'^(#{1,6})\s+(.+?)\s*(\{#([^}]+)\})?\s*$', re.M)      # markdown 标题
SQLSEC = re.compile(r'^\s*/\*[^\n]*?(§[^\s*]+)[^\n]*$|^\s*--+\s*(§[^\s]+)', re.M)
FENCE = re.compile(r'^```+\s*(\{?[^\n`]*\}?)\s*$', re.M)


def sha(b):
    return hashlib.sha256(b if isinstance(b, bytes) else b.encode()).hexdigest()


# ==============================================================================
# L0 · 档级六元组
# ==============================================================================
def fp_L0(path):
    b = open(path, 'rb').read()
    lf, cr = b.count(b'\n'), b.count(b'\r')
    le = 'LF' if cr == 0 else ('CRLF' if cr == lf else f'MIXED(cr={cr})')
    bom = b[:3] == b'\xef\xbb\xbf'
    try:
        b.decode('utf-8'); enc = 'UTF-8' + ('+BOM' if bom else '/noBOM')
    except UnicodeDecodeError:
        enc = 'NOT-UTF8'
    return {"lines": lf, "bytes": len(b),
            "md5": hashlib.md5(b).hexdigest(), "sha256": sha(b),
            "line_ending": le, "encoding": enc,
            "mtime": datetime.datetime.fromtimestamp(
                os.path.getmtime(path)).strftime('%Y-%m-%d %H:%M:%S')}


# ==============================================================================
# L1 · 节级
# ==============================================================================
def fp_L1(text, is_sql):
    marks = []
    if is_sql:
        for m in SQLSEC.finditer(text):
            marks.append((m.start(), (m.group(1) or m.group(2)).strip()))
    else:
        for m in H.finditer(text):
            marks.append((m.start(), f"{m.group(1)} {m.group(2)}"
                                     + (f" {{{m.group(4)}}}" if m.group(4) else "")))
    if not marks:
        return {"__whole__": {"sha256": sha(text)[:16], "bytes": len(text.encode()),
                              "line": 1}}
    out, n = {}, defaultdict(int)
    for i, (pos, name) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
        n[name] += 1
        key = name if n[name] == 1 else f"{name}#{n[name]}"
        body = text[pos:end]
        out[key] = {"sha256": sha(body)[:16], "bytes": len(body.encode()),
                    "line": text.count('\n', 0, pos) + 1}
    return out


# ==============================================================================
# L2 · 块级
# ==============================================================================
def fp_L2(text):
    fences = [(m.start(), m.end(), m.group(1).strip()) for m in FENCE.finditer(text)]
    out, n = {}, defaultdict(int)
    for i in range(0, len(fences) - 1, 2):
        s, e, lab = fences[i]
        body = text[e:fences[i + 1][0]]
        lab = lab or "plain"
        n[lab] += 1
        out[f"{lab}#{n[lab]}"] = {"sha256": sha(body)[:16],
                                  "bytes": len(body.encode()),
                                  "line": text.count('\n', 0, s) + 1}
    return out


# ==============================================================================
# L3 · 声明级（借 CLAIM-SCAN v2.1）
# ==============================================================================
def load_claimscan(here):
    for c in [os.path.join(here, "V-A168-CLAIM-SCAN-003_v2_1.py"),
              os.path.join(here, "函数", "V-A168-CLAIM-SCAN-003_v2_1.py"),
              os.path.join(os.path.dirname(here), "V-A168-CLAIM-SCAN-003_v2_1.py")]:
        if os.path.exists(c):
            sp = importlib.util.spec_from_file_location("cs", c)
            m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
            return m, c
    return None, None


def fp_L3(cs, text, fname):
    if cs is None:
        return {}
    T = cs.PRE_REG["single_valued"]
    prs = cs.pairs_in(text, fname, T, 10)
    agg = defaultdict(set)
    for p in prs:
        agg[p["term"]].add(p["value"])
    return {t: {"values": sorted(v), "n": len(v),
                "sha256": sha("|".join(sorted(v)))[:16]} for t, v in agg.items()}


# ==============================================================================
# 控制层
# ==============================================================================
def controls():
    print("=" * 74); print("控制层 · NC"); print("=" * 74)
    ok = True
    import tempfile
    d = tempfile.mkdtemp()
    p = os.path.join(d, "t.md")

    # NC-A：内容改一个字元，L1 该节指纹须变，其余节须不变
    open(p, 'w', encoding='utf-8').write("# 甲\n内容一\n\n# 乙\n内容二\n")
    a = fp_L1(open(p, encoding='utf-8').read(), False)
    open(p, 'w', encoding='utf-8').write("# 甲\n内容一\n\n# 乙\n内容三\n")
    b = fp_L1(open(p, encoding='utf-8').read(), False)
    p1 = (a["# 甲"]["sha256"] == b["# 甲"]["sha256"]
          and a["# 乙"]["sha256"] != b["# 乙"]["sha256"])
    print(f"  NC-A 节级定位     期望 甲不变·乙变     实得 "
          f"{'甲不变·乙变' if p1 else '未能定位'}   {'PASS' if p1 else 'FAIL'}")
    ok &= p1

    # NC-B：CRLF/LF 归一须被识别为行尾差而非改稿
    open(p, 'wb').write(b"a\nb\nc\n")
    x = fp_L0(p)
    open(p, 'wb').write(b"a\r\nb\r\nc\r\n")
    y = fp_L0(p)
    p2 = (y["bytes"] - x["bytes"] == y["lines"] and x["line_ending"] == 'LF'
          and y["line_ending"] == 'CRLF')
    print(f"  NC-B 行尾归一识别 期望 字节差=行数      实得 "
          f"{y['bytes']-x['bytes']}={y['lines']}   {'PASS' if p2 else 'FAIL'}")
    ok &= p2

    # NC-C：无 baseline 时不得伪造 diff
    p3 = (diff_registry({}, {"f": {"L0": {"md5": "x"}}})["status"] == "NO-BASELINE")
    print(f"  NC-C 无基线不伪造 期望 NO-BASELINE      实得 "
          f"{diff_registry({}, {'f':{'L0':{'md5':'x'}}})['status']}   "
          f"{'PASS' if p3 else 'FAIL'}")
    ok &= p3
    import shutil; shutil.rmtree(d, ignore_errors=True)
    print(f"\n{'✅ 控制层全过' if ok else '⛔ 控制层未过 —— 本器无资格执行'}\n")
    return ok


# ==============================================================================
# 登记簿 diff —— 系统与工具之分界
# ==============================================================================
def diff_registry(prev, cur):
    if not prev:
        return {"status": "NO-BASELINE", "changed": {}}
    out = {"status": "DIFFED", "changed": {}}
    for f, c in cur.items():
        p = prev.get(f)
        if p is None:
            out["changed"][f] = {"kind": "NEW"}; continue
        if p["L0"]["md5"] == c["L0"]["md5"]:
            continue
        det = {"kind": "MODIFIED",
               "L0": {"lines": (p["L0"]["lines"], c["L0"]["lines"]),
                      "bytes": (p["L0"]["bytes"], c["L0"]["bytes"])},
               "L1_changed": [], "L1_added": [], "L1_removed": [],
               "L3_changed": []}
        for k, v in c["L1"].items():
            if k not in p["L1"]:
                det["L1_added"].append(k)
            elif p["L1"][k]["sha256"] != v["sha256"]:
                det["L1_changed"].append(k)
        det["L1_removed"] = [k for k in p["L1"] if k not in c["L1"]]
        for k, v in c.get("L3", {}).items():
            if p.get("L3", {}).get(k, {}).get("sha256") != v["sha256"]:
                det["L3_changed"].append(k)
        out["changed"][f] = det
    for f in prev:
        if f not in cur:
            out["changed"][f] = {"kind": "REMOVED"}
    return out


# ==============================================================================
# MAIN
# ==============================================================================
def main(target_dir=None):
    rid = datetime.datetime.now().strftime("QMSRUN-%Y%m%d_%H%M%S")
    print("=" * 74)
    print(f" V-A168-QMS-RUNNER-004  v1.0.0    RUN-ID {rid}")
    print("=" * 74 + "\n")

    here = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() \
        else os.getcwd()
    cs, cs_path = load_claimscan(here)

    # 寻径：优先借用 CLAIM-SCAN 之 R-PATH-001
    if target_dir:
        tdir = os.path.abspath(target_dir)
        print(f"R-PATH · 显式目录：{tdir}\n")
    elif cs:
        tdir, _ = cs.resolve_target_dir(None)
        if tdir is None:
            print("\n⛔ 寻径未成 —— 停止，不猜。"); return 1
        print()
    else:
        print("⛔ 找不到 CLAIM-SCAN v2.1，且未给显式目录 —— 停止。"); return 1

    if not controls():
        print("⛔ GATE QG-2 BLOCKED —— 不出结论。"); return 2

    # ---- 指纹 ----
    print("=" * 74); print("四层内容指纹"); print("=" * 74)
    cur, missing = {}, []
    for name in MANIFEST:
        p = os.path.join(tdir, name)
        if not os.path.exists(p):
            missing.append(name); continue
        try:
            txt = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            txt = open(p, encoding='gb18030', errors='replace').read()
        is_sql = name.endswith('.sql')
        cur[name] = {"L0": fp_L0(p), "L1": fp_L1(txt, is_sql),
                     "L2": fp_L2(txt), "L3": fp_L3(cs, txt, name)}
    if missing:
        print(f"  ⚪ 缺席 {len(missing)} 档：")
        for m in missing:
            print(f"      {m}")
        print()

    print(f"  {'档':<44}{'行':>7}{'字节':>10}  {'L1节':>5}{'L2块':>5}{'L3术语':>7}  MD5")
    for n, c in cur.items():
        print(f"  {n[:42]:<44}{c['L0']['lines']:>7}{c['L0']['bytes']:>10}  "
              f"{len(c['L1']):>5}{len(c['L2']):>5}{len(c['L3']):>7}  "
              f"{c['L0']['md5'][:12]}")

    # ---- QG-4 · 与 v3 §一 登记对账 ----
    print("\n" + "=" * 74); print("QG-4 变更闸 · 与 v3 §一 登记对账"); print("=" * 74)
    blocked = []
    for n, c in cur.items():
        if n not in V3_REGISTERED:
            continue
        L, B, M = V3_REGISTERED[n]
        okk = (c['L0']['lines'] == L and c['L0']['bytes'] == B
               and c['L0']['md5'].startswith(M))
        if okk:
            print(f"  🟢 {n[:44]}")
        else:
            db = c['L0']['bytes'] - B
            note = ("字节差=行数 → CRLF/LF 归一" if db == c['L0']['lines']
                    else f"字节差 {db:+} ≠ 行数 {c['L0']['lines']} → 真改稿")
            print(f"  🔴 {n[:44]}")
            print(f"      登记 {L}/{B}/{M}…   实测 {c['L0']['lines']}/"
                  f"{c['L0']['bytes']}/{c['L0']['md5'][:8]}…   {note}")
            blocked.append(n)

    # ---- 登记簿 diff ----
    regp = os.path.join(tdir, REG_NAME)
    prev = {}
    if os.path.exists(regp):
        try:
            prev = json.load(open(regp, encoding='utf-8')).get("files", {})
        except Exception:
            prev = {}
    d = diff_registry(prev, cur)
    print("\n" + "=" * 74); print("登记簿 diff（系统与工具之分界）"); print("=" * 74)
    if d["status"] == "NO-BASELINE":
        print("  ⚪ NO-BASELINE —— 本次为首建登记簿，无上次可比。")
        print("     此格【不可证】，不得伪造 diff。下次执行起方有定位能力。")
    elif not d["changed"]:
        print("  🟢 与上次登记簿完全一致，零变更。")
    else:
        for f, det in d["changed"].items():
            print(f"\n  ▸ {f}  [{det['kind']}]")
            if det["kind"] != "MODIFIED":
                continue
            print(f"      L0 行 {det['L0']['lines'][0]}→{det['L0']['lines'][1]}   "
                  f"字节 {det['L0']['bytes'][0]}→{det['L0']['bytes'][1]}")
            for k, lbl in [("L1_changed", "改动节"), ("L1_added", "新增节"),
                           ("L1_removed", "删除节"), ("L3_changed", "声明变更")]:
                if det[k]:
                    print(f"      {lbl}（{len(det[k])}）：{'、'.join(det[k][:6])}"
                          + (" …" if len(det[k]) > 6 else ""))

    json.dump({"run_id": rid, "dir": tdir,
               "generated": datetime.datetime.now().isoformat(),
               "files": cur},
              open(regp, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f"\n登记簿已写：{regp}")

    # ---- 闸门总判 ----
    print("\n" + "=" * 74); print("闸门总判"); print("=" * 74)
    print(f"  QG-2 验证器闸   🟢 控制层全过")
    if blocked:
        print(f"  QG-4 变更闸     🔴 {len(blocked)} 档与登记不符 → IMPACT REVIEW")
        for b in blocked:
            print(f"                  · {b}")
        print(f"\n  ⛔ 该 {len(blocked)} 档之既有结论【不得沿用】，须重验后方可引用。")
        print(f"     其余 {len(cur)-len(blocked)} 档 🟢 OBSERVED，结论可用。")
    else:
        print(f"  QG-4 变更闸     🟢 全数吻合")
    print(f"\n  本器 NOT-CAPABLE-OF：不裁变更是否正当、不裁何者为最新版、"
          f"不判声明语义作用域。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else None))
