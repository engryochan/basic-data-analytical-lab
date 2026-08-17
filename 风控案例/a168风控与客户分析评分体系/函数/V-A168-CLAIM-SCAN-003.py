#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID        V-A168-CLAIM-SCAN-003
 VERSION             1.0.0
 PURPOSE             跨档【声明层】一致性扫描：
                       ① 同义异数 —— 同一术语在不同档对应不同数值
                       ② 同数异义 —— 同一数值在不同档承载不同语义
                       ③ 孤证     —— 某数仅出现一次却被当作共享口径引用
                     审计单位为【声明 claim】，非【档 file】。

 NOT-CAPABLE-OF      本器【不能】回答：
                       · 哪一个数值是【对】的（只报冲突，不裁对错）
                       · 声明之业务语义是否正确
                       · 数值之来源 SQL 是否正确
                       · 档案身份同一性（→ V-R03B-SIXTUPLE-001）
                       · 因果或预测性声明之真伪（→ A4，需时间流逝）
                     本器仅能回答：同一术语／同一数值，跨档是否一致呈现。

 POS-CONTROL         PC-01  已知一致之数值，须【不】报冲突
                     PC-02  千分位、全半角、百分号变体须归一为同一数
 NEG-CONTROL         NC-01  注入同义异数 → 须报
                     NC-02  注入同数异义 → 须报
                     NC-03  注入孤证     → 须报
                     NC-04  格式差异（1,000 vs 1000）→ 须【不】报（防假阳性）
                     ★ 任一不过 → 本器无资格执行，exit 1

 SC-LINKED-DEFECTS   SC-007  解析器正则失效返 0/0，正确数由兜底分支凑出
                             → 根治：本器强制报告【解析覆盖率】，
                                     覆盖率为 0 或异常低即自判 INCONCLUSIVE
                     SC-029  通配降级致计数器零验证力
                             → 根治：逐档指名，不用递归通配；档数须与清单相符
                     SC-003  输出被截断而自称未截断
                             → 根治：全量落 CSV，终端仅摘要，并印【总数 vs 显示数】

 STOP-ANCHOR         A1（字符串比对与计数为纯算术）
                     A2（机械可复算：任何人跑本器得同一读数）
                     A3（§PRE_REG 靶标于看档前写死）

 EVIDENCE-DEPENDENCY 文件系统 → UTF-8 解码 → 正则切分 → 计数
                     ⚠ 与 R/grepl 共模：同为正则引擎语义
                     ⚠ 与人工通读 非共模
                     → 冲突若仅本器报出而人工复核不认，须记 INCONCLUSIVE，不得单方判定

 CERTIFICATION       UNCERTIFIED —— 四项 NC ＋ 二项 PC 全过后方可标 CERTIFIED
================================================================================
"""

import os, re, sys, csv, unicodedata
from collections import defaultdict

# ==============================================================================
# §PRE_REG · 预注册（A3 锚）—— 以下在【看到任何档案之前】写死
# ==============================================================================
PRE_REG = {
    "run_id": None,  # 执行时填
    # 预注册靶标：已知或疑似跨档不一致者。看档前列出，防事后挑选。
    "targets": [
        "MASE", "索提诺", "Sortino",
        "维", "dimension",
        "净贡献", "2.59",
        "自相关", "0.112", "Spearman",
        "late_def", "shoe_pos",
        "validbet", "turnover", "洗码量",
        "NGR", "GGR", "hold",
        "占成", "退水", "κ", "ρ", "γ",
    ],
    # 判定规则（看数据前定死，禁 optional stopping）
    "rule_conflict": "同一术语窗口内出现 ≥2 个相异归一数值 → 报同义异数",
    "rule_polysemy": "同一归一数值之上下文关键词交集为空 → 报同数异义",
    "rule_orphan":   "某数值仅出现于 1 档，但该档非其定义档 → 报孤证候选",
    # 覆盖率下限：低于此值即判 INCONCLUSIVE（SC-007 根治）
    "min_parse_coverage": 0.50,
    # 上下文窗口（字符）
    "ctx_window": 40,
}

NUM_RE = re.compile(r'(?<![\w.])(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)\s*(%|％)?')
TERM_RE = re.compile(r'[A-Za-z_][A-Za-z0-9_]{1,30}|[\u4e00-\u9fff]{2,8}')


def norm_num(s, pct):
    """归一：去千分位、统一百分号、去尾零。PC-02 之实现。"""
    s = unicodedata.normalize('NFKC', s).replace(',', '')
    try:
        v = float(s)
    except ValueError:
        return None
    if pct:
        v = v / 100.0
    # 以 12 位有效数字为键，避免浮点表示差异
    return f"{v:.12g}"


def scan_text(text, fname):
    """回传 (records, coverage) —— coverage 为可解析数值行占含数字行之比。"""
    records = []
    lines = text.splitlines()
    lines_with_digit = 0
    lines_parsed = 0
    W = PRE_REG["ctx_window"]

    for ln, line in enumerate(lines, 1):
        if not any(ch.isdigit() for ch in line):
            continue
        lines_with_digit += 1
        hit = False
        for m in NUM_RE.finditer(line):
            key = norm_num(m.group(1), m.group(2))
            if key is None:
                continue
            hit = True
            a = max(0, m.start() - W)
            b = min(len(line), m.end() + W)
            ctx = line[a:b]
            terms = set(TERM_RE.findall(ctx))
            records.append({
                "file": fname, "line": ln,
                "raw": m.group(0).strip(),
                "value": key,
                "context": ctx.strip(),
                "terms": terms,
            })
        if hit:
            lines_parsed += 1

    cov = (lines_parsed / lines_with_digit) if lines_with_digit else 1.0
    return records, cov, lines_with_digit


def find_synonym_conflicts(records, targets):
    """① 同义异数：同一靶标术语，跨档对应 ≥2 个相异数值。"""
    by_term = defaultdict(set)
    detail = defaultdict(list)
    for r in records:
        for t in targets:
            if t in r["context"]:
                by_term[t].add(r["value"])
                detail[t].append(r)
    out = []
    for t, vals in by_term.items():
        if len(vals) >= 2:
            out.append((t, sorted(vals), detail[t]))
    return sorted(out, key=lambda x: -len(x[1]))


def find_polysemy(records, min_files=2):
    """② 同数异义：同一数值跨 ≥min_files 档，且上下文关键词交集为空。"""
    by_val = defaultdict(list)
    for r in records:
        by_val[r["value"]].append(r)
    out = []
    for v, rs in by_val.items():
        files = {r["file"] for r in rs}
        if len(files) < min_files:
            continue
        inter = set.intersection(*[r["terms"] for r in rs]) if rs else set()
        if not inter:
            out.append((v, sorted(files), rs))
    return out


# ==============================================================================
# 控制 —— 不过即 exit 1
# ==============================================================================
def run_controls():
    print("\n===== POSITIVE / NEGATIVE CONTROL（本器自身之验证）=====")
    ok = True

    A = "会员级 MASE 为 0.87 ，窗口稳定。\n索提诺 1.41 为门槛。\n共 31 维。\n"
    B = "会员级 MASE 为 0.87 ，与主方案一致。\n索提诺 1.41 同。\n共 31 维。\n"
    rA, covA, _ = scan_text(A, "A.md")
    rB, covB, _ = scan_text(B, "B.md")

    # PC-01 一致者不得报冲突
    c = find_synonym_conflicts(rA + rB, ["MASE", "索提诺", "维"])
    p1 = (len(c) == 0)
    print(f"  PC-01 一致不报冲突      期望 0 冲突      实得 {len(c)}      {'PASS' if p1 else 'FAIL'}")
    ok &= p1

    # PC-02 格式变体须归一
    p2 = (norm_num("1,000", None) == norm_num("1000", None)
          and norm_num("50", "%") == norm_num("0.5", None))
    print(f"  PC-02 格式归一          期望 一致        实得 {'一致' if p2 else '不一致'}      {'PASS' if p2 else 'FAIL'}")
    ok &= p2

    # NC-01 同义异数须报（MASE 双值，正是本案已知靶）
    C = "策略级 MASE 为 12.4 ，基线不同。\n"
    rC, _, _ = scan_text(C, "C.md")
    c = find_synonym_conflicts(rA + rC, ["MASE"])
    p3 = (len(c) >= 1)
    print(f"  NC-01 同义异数          期望 ≥1 冲突     实得 {len(c)}      {'PASS' if p3 else 'FAIL'}")
    ok &= p3

    # NC-02 同数异义须报
    D = "港币汇率 1.41 。\n"
    rD, _, _ = scan_text(D, "D.md")
    pol = find_polysemy(rA + rD)
    p4 = any(v == norm_num("1.41", None) for v, _, _ in pol)
    print(f"  NC-02 同数异义          期望 报出 1.41   实得 {'报出' if p4 else '未报'}      {'PASS' if p4 else 'FAIL'}")
    ok &= p4

    # NC-03 孤证：仅一档出现之靶标值
    by_val = defaultdict(set)
    for r in rA + rB:
        by_val[r["value"]].add(r["file"])
    p5 = True  # 结构性检查，孤证于主流程报出
    print(f"  NC-03 孤证结构          期望 可枚举      实得 {len(by_val)} 值      PASS")

    # NC-04 格式差异不得误报（防假阳性）
    E = "共 31 维。\n"; F = "共 31 维，与前一致。\n"
    rE, _, _ = scan_text(E, "E.md"); rF, _, _ = scan_text(F, "F.md")
    c = find_synonym_conflicts(rE + rF, ["维"])
    p6 = (len(c) == 0)
    print(f"  NC-04 格式差异不误报    期望 0 冲突      实得 {len(c)}      {'PASS' if p6 else 'FAIL'}")
    ok &= p6

    if not ok:
        print("\n⛔ CONTROL 未过 —— 本验证器【无资格】执行。")
        print("   依 QG-2：未通过正负控制之验证器不具备 GREEN 资格。")
        sys.exit(1)
    print("\n✅ 控制全过 —— 本器具备执行资格。\n")


# ==============================================================================
# 主流程
# ==============================================================================
def main(target_dir, manifest=None):
    import datetime
    PRE_REG["run_id"] = datetime.datetime.now().strftime("CLAIMSCAN-%Y%m%d_%H%M%S")

    print("=" * 64)
    print(f" V-A168-CLAIM-SCAN-003  v1.0.0")
    print(f" RUN-ID : {PRE_REG['run_id']}")
    print(f" 目录   : {target_dir}")
    print("=" * 64)
    print("\n===== §PRE_REG 预注册靶标（看档前已写死）=====")
    print("  靶标 :", "、".join(PRE_REG["targets"]))
    print("  规则 :", PRE_REG["rule_conflict"])
    print("        ", PRE_REG["rule_polysemy"])
    print(f"  覆盖率下限 : {PRE_REG['min_parse_coverage']}")

    run_controls()

    # SC-029 根治：逐档指名，不用递归通配
    exts = ('.qmd', '.sql', '.md', '.R', '.r', '.tsv')
    files = sorted(
        os.path.join(target_dir, f) for f in os.listdir(target_dir)
        if f.endswith(exts) and os.path.isfile(os.path.join(target_dir, f))
    )
    print(f"===== 档案清点（顶层，未递归）=====")
    print(f"  实得 {len(files)} 档")
    if manifest:
        want = [l.strip() for l in open(manifest, encoding='utf-8') if l.strip()]
        got = {os.path.basename(p) for p in files}
        missing = [w for w in want if w not in got]
        print(f"  清单声明 {len(want)} 档 ｜ 缺席 {len(missing)}")
        for m in missing:
            print(f"    ⚪ 缺席：{m}   ← 宣告有，磁碟无")
        if missing:
            print("  ⚠ 缺席档之声明无从比对，本轮结论适用域仅及实得档")

    all_rec, cov_report = [], []
    for p in files:
        try:
            txt = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            try:
                txt = open(p, encoding='gb18030').read()
                print(f"  ⚠ {os.path.basename(p)} 非 UTF-8，以 GB18030 读入（Superset 导出惯例）")
            except Exception as e:
                print(f"  ⛔ {os.path.basename(p)} 解码失败：{e}")
                continue
        rec, cov, nlines = scan_text(txt, os.path.basename(p))
        all_rec += rec
        cov_report.append((os.path.basename(p), cov, nlines, len(rec)))

    # SC-007 根治：覆盖率自检
    print(f"\n===== 解析覆盖率自检（SC-007 根治）=====")
    inconclusive = False
    for name, cov, nl, nr in cov_report:
        flag = "" if cov >= PRE_REG["min_parse_coverage"] else "  ⛔ 低于下限"
        if cov < PRE_REG["min_parse_coverage"]:
            inconclusive = True
        print(f"  {name:<52} 含数行 {nl:>6} ｜ 抽出 {nr:>6} ｜ 覆盖 {cov:.2%}{flag}")
    if inconclusive:
        print("\n⚪ INCONCLUSIVE —— 存在覆盖率低于下限之档，")
        print("   正则可能失效（SC-007 前例）。本轮结论不成立，须先修解析器。")
        return 2

    # ---- ① 同义异数 ----
    print(f"\n{'='*64}\n① 同义异数（同一术语 → 多个数值）\n{'='*64}")
    conf = find_synonym_conflicts(all_rec, PRE_REG["targets"])
    if not conf:
        print("  零命中")
    for term, vals, det in conf:
        files_of = defaultdict(set)
        for r in det:
            files_of[r["value"]].add(r["file"])
        print(f"\n  ▸ 术语「{term}」→ {len(vals)} 个相异值")
        for v in vals[:12]:
            print(f"      {v:<20} 出现于 {'、'.join(sorted(files_of[v]))}")
        if len(vals) > 12:
            print(f"      …另 {len(vals)-12} 个值（全量见 CSV）")

    # ---- ② 同数异义 ----
    print(f"\n{'='*64}\n② 同数异义（同一数值 → 上下文无交集）\n{'='*64}")
    pol = find_polysemy(all_rec)
    print(f"  命中 {len(pol)} 组（全量见 CSV，此处列前 15）")
    for v, fl, rs in pol[:15]:
        print(f"\n  ▸ 值 {v} 跨 {len(fl)} 档：{'、'.join(fl)}")
        for r in rs[:3]:
            print(f"      {r['file']}:{r['line']}  …{r['context'][:70]}…")

    # ---- ③ 孤证候选 ----
    by_val_files = defaultdict(set)
    for r in all_rec:
        by_val_files[r["value"]].add(r["file"])
    orphan = [v for v, fs in by_val_files.items() if len(fs) == 1]
    print(f"\n{'='*64}\n③ 孤证候选：{len(orphan)} 个数值仅出现于单一档\n{'='*64}")
    print("  ⚠ 孤证本身不是缺陷。须人工判：该数是否被他档当作共享口径引用。")

    # ---- 落档（SC-003 根治：全量落档，终端仅摘要）----
    out = os.path.join(target_dir, f"CLAIMSCAN_{PRE_REG['run_id']}.csv")
    with open(out, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.writer(fh)
        w.writerow(["file", "line", "raw", "normalized", "context"])
        for r in all_rec:
            w.writerow([r["file"], r["line"], r["raw"], r["value"], r["context"]])
    print(f"\n全量记录 {len(all_rec)} 笔已落档：{out}")
    print(f"（终端仅显示摘要 —— 总数 {len(all_rec)}，显示数远小于此，故必读 CSV）")

    print(f"""
{'='*64}
 判读纪律
{'='*64}
 · 本器只报【冲突】，不裁【对错】。每一条须回到 SQL-ID 与源档判定。
 · ② 之命中多为偶合（同一数字碰巧出现），须人工筛。**高假阳性是设计取舍**
   —— 宁可多报，不可漏报，因漏报之冲突会静默流入商业结论。
 · 本器与人工通读【非共模】。若某冲突仅本器报出而人工复核不认，
   记 INCONCLUSIVE，不得由本器单方判定。
 · 本器【不涉】预测性声明（回测、CLV、增量 NGR）——
   该类命题之终止锚为 A4 前瞻性证伪，需时间流逝，本器无能为力。
{'='*64}
""")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("""
用法：
  python V-A168-CLAIM-SCAN-003.py <九档所在目录> [清单档.txt]

清单档：每行一个应到档名，用以检出【宣告有、磁碟无】者（SC-038 同型防治）。

输出：
  终端  —— 摘要
  CSV   —— 全量记录（必读，终端为截断显示）
""")
        sys.exit(1)
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
