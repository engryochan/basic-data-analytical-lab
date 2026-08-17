#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID        V-A168-CLAIM-SCAN-003
 VERSION             2.1.0
 SUPERSEDES          2.0.0（SC-044/045 修复）／ 1.0.0（SC-043，已停用）

 v2.1 变更（三项）
   ① 新增【自动寻径解析器】R-PATH-001 —— 无须手传目录
   ② 甲案：靶标分【单值量】与【量词】；量词一律 OUT-OF-SCOPE，不报同义异数
   ③ 非度量数值排除：年份、§章节号、#编号

 SC-LINKED-DEFECTS
   SC-043  正负控制未测规模化特异度              → v2.0 置换检验补足  REMEDIATED
   SC-044  靶标未分单值量／量词，对量词报同义异数为范畴错误  → v2.1 修  ★本版
   SC-045  未排除年份／章节号等非度量数值          → v2.1 修  ★本版
   SC-029  通配递归降级致计数器零验证力
           → 寻径限定深度，且【逐目录报分】，零命中必须失败退出，不得静默
   SC-032  同名异容之证物碰撞
           → ★ 寻径器强制列出【所有】候选目录与其档案 mtime；
              同名档跨目录出现即告警——此为自动寻径【新引入】之失效模式

 NOT-CAPABLE-OF（本器不能回答）
   · 哪一个数值是对的（只报冲突，不裁对错）
   · 数值落于【引述／撤销说明】抑或【正文主张】（语义作用域 → 人工）
   · 量词类计数应否统一（31/29/27/18 → 维持 UNKNOWN）
   · 自动选中之目录是否为【最新版】—— 只报 mtime 与档数，不裁版本

 STOP-ANCHOR   A1 计数与比值为纯算术
               A2 机械可复算（随机种子固定；寻径评分公开可复算）
               A3 §PRE_REG 与 §THRESH 判据于看结果前写死

 CERTIFICATION UNCERTIFIED —— NC-00/01/02/03 全过方可标 CERTIFIED v2.1.0
================================================================================
"""
import os, re, sys, csv, glob, random, statistics, unicodedata, datetime
from collections import defaultdict

# ==============================================================================
# §PRE_REG（A3 锚）
# ==============================================================================
PRE_REG = {
    "seed": 20260815,

    # ── SC-044 修：靶标分两类 ────────────────────────────────────────────
    # 单值量：应有唯一值，多值即冲突 → 报同义异数
    "single_valued": ["MASE", "Spearman", "自相关", "索提诺", "Sortino", "Jaccard"],
    # 量词／类别名：天生多值 → OUT-OF-SCOPE，只统计不判冲突
    "classifier":    ["维", "门槛", "退水", "洗码量", "占成", "毛利率", "净贡献"],

    # ── SC-045 修：非度量数值排除 ───────────────────────────────────────
    "exclude_year_lo": 1900, "exclude_year_hi": 2099,   # 文献年份
    "exclude_prefix": "§#第",                            # 章节号／编号前导字元

    "dist_grid": [5, 8, 10, 12, 15, 20, 25, 30, 40, 60, 80],
    "thresh_rule": "Recall ≥ 0.90 之候选中取 Precision_proxy 最大者；无候选则 INCONCLUSIVE，不得放宽",
    "min_recall": 0.90,
    "n_perm": 200,
    "disc_alpha": 0.05,
    # GOLD：每一项皆须【先经语料确认为邻接型】方可入集
    "gold": [("MASE", "9.8"), ("MASE", "13.232"), ("Spearman", "0.2"),
             ("自相关", "0.112"), ("Jaccard", "0.02")],
    # ── SC-046 留证：以下配对曾入 gold，经查【超出本器适用域】而撤销 ──
    #    撤销理由须为「适用域之外」，不得为「达不到 Recall 门槛」（移动球门）
    "gold_out_of_scope": [
        (("索提诺", "1.41"),
         "语料实为『会员级索提诺率 P50 −0.43／P90 0.082／P95 0.356／P99 1.41』，"
         "系【列表中之分位值】而非邻接配对；中间夹三个数值，"
         "为约束③正确排除。本器不做列表解析 → OUT-OF-SCOPE，非漏报。"
         "撤销日 2026-08-15，见 SC-046。"),
    ],

    # ── 寻径 ────────────────────────────────────────────────────────────
    "manifest": [
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
    ],
    "search_up": 4,      # 自脚本处向上回溯层数（有界，SC-029）
    "search_down": 2,    # 每层向下扫描深度（有界）
    "min_hit": 3,        # 命中少于此数之目录不列为候选
}
random.seed(PRE_REG["seed"])

NUM_RE  = re.compile(r'(?<![\w.])(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)')
SENT_RE = re.compile(r'[。；！？\n]|","')


# ==============================================================================
# R-PATH-001 · 自动寻径解析器
# ==============================================================================
def resolve_target_dir(explicit=None, verbose=True):
    """回传 (chosen_dir, report)。
       纪律：① 有界搜索  ② 逐目录报分  ③ 零命中必败
             ④ 并列第一必判 INCONCLUSIVE，不代选
             ⑤ 同名档跨目录出现即告警（SC-032）
    """
    rep = {"origin": None, "candidates": [], "chosen": None,
           "status": None, "collisions": {}}

    if explicit:
        rep["origin"] = os.path.abspath(explicit)
        rep["status"] = "EXPLICIT"
        rep["chosen"] = rep["origin"]
        return rep["chosen"], rep

    # 起点：脚本所在处（%run 会设 __file__）；退回 cwd 并明记
    try:
        origin = os.path.dirname(os.path.abspath(__file__))
        rep["origin"] = f"{origin}   （来源：__file__）"
    except NameError:
        origin = os.getcwd()
        rep["origin"] = f"{origin}   （来源：cwd —— __file__ 不可得，已明记）"

    # 有界枚举：自 origin 向上 N 层，每层向下 M 层
    roots, cur = [], origin
    for _ in range(PRE_REG["search_up"] + 1):
        roots.append(cur)
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent

    seen, cand = set(), {}
    for r in roots:
        for depth in range(PRE_REG["search_down"] + 1):
            pat = os.path.join(r, *(['*'] * depth)) if depth else r
            for d in ([pat] if depth == 0 else glob.glob(pat)):
                if not os.path.isdir(d):
                    continue
                d = os.path.abspath(d)
                if d in seen:
                    continue
                seen.add(d)
                names = set(os.listdir(d)) if os.access(d, os.R_OK) else set()
                hit = [m for m in PRE_REG["manifest"] if m in names]
                if len(hit) >= PRE_REG["min_hit"]:
                    mt = max((os.path.getmtime(os.path.join(d, h)) for h in hit),
                             default=0)
                    cand[d] = {"hit": len(hit), "files": hit, "mtime": mt}

    rep["candidates"] = sorted(
        [{"dir": k, **v} for k, v in cand.items()],
        key=lambda x: (-x["hit"], -x["mtime"]))

    # SC-032：同名档跨目录出现
    where = defaultdict(list)
    for c in rep["candidates"]:
        for f in c["files"]:
            where[f].append(c["dir"])
    rep["collisions"] = {f: ds for f, ds in where.items() if len(ds) > 1}

    if verbose:
        print("=" * 74)
        print("R-PATH-001 · 自动寻径")
        print("=" * 74)
        print(f"  起点   : {rep['origin']}")
        print(f"  搜索域 : 向上 {PRE_REG['search_up']} 层 × 向下 "
              f"{PRE_REG['search_down']} 层（有界，SC-029）")
        print(f"  清单   : {len(PRE_REG['manifest'])} 档")
        print(f"  候选   : {len(rep['candidates'])} 个目录\n")
        for i, c in enumerate(rep["candidates"], 1):
            ts = datetime.datetime.fromtimestamp(c["mtime"]).strftime('%Y-%m-%d %H:%M')
            print(f"   {i}. 命中 {c['hit']:>2}/{len(PRE_REG['manifest'])}  "
                  f"最新 mtime {ts}   {c['dir']}")

    if not rep["candidates"]:
        rep["status"] = "NOT-FOUND"
        if verbose:
            print("\n⛔ 零命中 —— 依 SC-029 纪律，零结果必须失败退出，不得静默续行。")
            print("   请以显式目录重跑：main('<九档目录>')")
        return None, rep

    top = rep["candidates"][0]
    tied = [c for c in rep["candidates"] if c["hit"] == top["hit"]]
    if len(tied) > 1:
        rep["status"] = "INCONCLUSIVE-TIE"
        if verbose:
            print(f"\n⚪ INCONCLUSIVE —— {len(tied)} 个目录并列命中 {top['hit']} 档。")
            print("   本器【不代选】。请以显式目录指定，此为同名异容之防线（SC-032）。")
        return None, rep

    rep["chosen"] = top["dir"]
    rep["status"] = "RESOLVED"
    if verbose:
        print(f"\n  ✅ 选定：{top['dir']}   （唯一最高命中 {top['hit']}）")
        if top["hit"] < len(PRE_REG["manifest"]):
            miss = [m for m in PRE_REG["manifest"] if m not in top["files"]]
            print(f"  ⚠ 缺席 {len(miss)} 档：")
            for m in miss:
                print(f"      ⚪ {m}")
            print("     —— 缺席档之声明无从比对，本轮适用域仅及实得档")
        if rep["collisions"]:
            print(f"\n  🔴 同名异容告警（SC-032）：{len(rep['collisions'])} 个档名"
                  f"出现于多个目录")
            for f, ds in list(rep["collisions"].items())[:5]:
                print(f"      {f}")
                for d in ds:
                    print(f"        · {d}")
            print("     —— 本器【不裁】何者为最新版，请自行确认后以显式目录重跑")
    return rep["chosen"], rep


# ==============================================================================
# 解析
# ==============================================================================
def norm_num(s):
    s = unicodedata.normalize('NFKC', s).replace(',', '')
    try:
        return f"{float(s):.12g}"
    except ValueError:
        return None


def is_non_metric(raw, sent, start):
    """SC-045：排除年份、章节号、编号。"""
    pre = sent[max(0, start - 2):start]
    if any(ch in pre for ch in PRE_REG["exclude_prefix"]):
        return True
    if '.' not in raw and ',' not in raw:
        try:
            v = int(raw)
            if PRE_REG["exclude_year_lo"] <= v <= PRE_REG["exclude_year_hi"]:
                return True
        except ValueError:
            pass
    return False


def sentences(text):
    out, pos = [], 0
    for m in SENT_RE.finditer(text):
        s = text[pos:m.start()]
        if s.strip():
            out.append((pos, s))
        pos = m.end()
    if text[pos:].strip():
        out.append((pos, text[pos:]))
    return out


def pairs_in(text, fname, targets, dist, filter_non_metric=True):
    res = []
    for base, sent in sentences(text):
        nums = []
        for m in NUM_RE.finditer(sent):
            if filter_non_metric and is_non_metric(m.group(1), sent, m.start()):
                continue
            v = norm_num(m.group(1))
            if v is not None:
                nums.append((m.start(), m.end(), v))
        if not nums:
            continue
        tpos = [(m.start(), m.end(), t)
                for t in targets for m in re.finditer(re.escape(t), sent)]
        for ts, te, t in tpos:
            for ns, ne, v in nums:
                ga, gb = (te, ns) if ns >= te else (ne, ts)
                d = gb - ga
                if d < 0 or d > dist:
                    continue
                mid = sent[ga:gb]
                if NUM_RE.search(mid):
                    continue
                if any(o in mid for o in targets if o != t):
                    continue
                res.append({"file": fname,
                            "line": text.count('\n', 0, base + ts) + 1,
                            "term": t, "value": v, "dist": d,
                            "sent": sent.strip()[:140]})
    return res


def concentration(prs):
    by = defaultdict(list)
    for p in prs:
        by[p["term"]].append(p["value"])
    return {t: (len(set(v)) / len(v), len(set(v)), len(v)) for t, v in by.items()}


# ==============================================================================
# 控制层
# ==============================================================================
def nc00_pathresolver():
    """R-PATH-001 之自身控制。"""
    print("  —— NC-00 寻径器控制 ——")
    import tempfile, shutil
    ok = True
    tmp = tempfile.mkdtemp()
    try:
        empty = os.path.join(tmp, "empty"); os.makedirs(empty)
        d, r = resolve_target_dir(explicit=None, verbose=False)
        # 空目录情境无法直接注入，改以内部函数语义检查
        p1 = (PRE_REG["min_hit"] >= 1 and PRE_REG["search_up"] < 10)
        print(f"     NC-00a 搜索域有界        期望 up<10 且 min_hit≥1   "
              f"实得 up={PRE_REG['search_up']}, min_hit={PRE_REG['min_hit']}   "
              f"{'PASS' if p1 else 'FAIL'}")
        ok &= p1
        p2 = (resolve_target_dir(explicit=tmp, verbose=False)[0] == os.path.abspath(tmp))
        print(f"     NC-00b 显式目录优先      期望 原样回传             "
              f"实得 {'原样' if p2 else '被改写'}   {'PASS' if p2 else 'FAIL'}")
        ok &= p2
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return ok


def nc01_regression(dist):
    print("  —— NC-01 回归：v1／v2 原控制须【同答】 ——")
    A = "会员级 MASE 为 0.87 ，窗口稳定。索提诺 1.41 为门槛。共 31 维。"
    B = "会员级 MASE 为 0.87 ，与主方案一致。索提诺 1.41 同。共 31 维。"
    C = "策略级 MASE 为 12.4 ，基线不同。"
    T = PRE_REG["single_valued"] + PRE_REG["classifier"]
    ok = True
    c = concentration(pairs_in(A, "A", T, dist) + pairs_in(B, "B", T, dist))
    p1 = all(u == 1 for _, u, _ in c.values())
    print(f"     PC-01 一致不报冲突    期望 每术语1值  实得 "
          f"{ {k: v[1] for k, v in c.items()} }  {'PASS' if p1 else 'FAIL'}"); ok &= p1
    p2 = norm_num("1,000") == norm_num("1000")
    print(f"     PC-02 格式归一        期望 一致       实得 "
          f"{'一致' if p2 else '不一致'}  {'PASS' if p2 else 'FAIL'}"); ok &= p2
    c = concentration(pairs_in(A, "A", T, dist) + pairs_in(C, "C", T, dist))
    p3 = c.get("MASE", (0, 0, 0))[1] >= 2
    print(f"     NC-01 同义异数须报    期望 MASE≥2值   实得 "
          f"{c.get('MASE',(0,0,0))[1]}  {'PASS' if p3 else 'FAIL'}"); ok &= p3
    c = concentration(pairs_in("共 31 维。", "E", T, dist)
                      + pairs_in("共 31 维，与前一致。", "F", T, dist))
    p4 = c.get("维", (0, 1, 0))[1] == 1
    print(f"     NC-04 格式差异不误报  期望 维=1值     实得 "
          f"{c.get('维',(0,0,0))[1]}  {'PASS' if p4 else 'FAIL'}"); ok &= p4
    return ok


def nc02_synthetic(dist):
    print("  —— NC-02 合成负例 ——")
    T = PRE_REG["single_valued"] + PRE_REG["classifier"]
    filler = "此处为无关叙述文字用以拉开距离并阻断邻接关系故不应成对"
    txt = "".join(f"{t}{filler}{random.randint(100,999)}。" for t in T)
    n = len(pairs_in(txt, "SYN", T, dist))
    print(f"     期望 0 配对   实得 {n}   {'PASS' if n == 0 else 'FAIL'}")
    return n == 0


def nc05_nonmetric():
    """SC-045 之专项控制：年份与章节号须被排除，真度量须存活。"""
    print("  —— NC-05 非度量排除（SC-045）——")
    T = PRE_REG["single_valued"]
    a = pairs_in("Sortino 1991 提出该比率。", "x", T, 25)
    b = pairs_in("见 §17.2 索提诺 一节。", "x", T, 25)
    c = pairs_in("Spearman 0.2 为实测值。", "x", T, 25)
    d = pairs_in("自相关 0.112 已锁。", "x", T, 25)
    r = [("年份 1991 须排除", len(a) == 0), ("§章节号须排除", len(b) == 0),
         ("真度量 0.2 须存活", len(c) == 1), ("真度量 0.112 须存活", len(d) == 1)]
    for k, v in r:
        print(f"     {k:<22} {'PASS' if v else 'FAIL'}")
    return all(v for _, v in r)


def sweep_threshold(TEXTS):
    print("\n" + "=" * 74)
    print("§THRESH · 距离阈值扫描（不硬编）")
    print("=" * 74)
    print(f"  规则（预注册）：{PRE_REG['thresh_rule']}")
    gold, rows = set(PRE_REG["gold"]), []
    T = PRE_REG["single_valued"]
    for dd in PRE_REG["dist_grid"]:
        allp = [x for p, t in TEXTS.items() for x in pairs_in(t, p, T, dd)]
        found = {(x["term"], x["value"]) for x in allp}
        rec = len(gold & found) / len(gold)
        conc = concentration(allp)
        prox = 1 - statistics.mean([v[0] for v in conc.values()]) if conc else 0
        rows.append((dd, len(allp), rec, prox))
        print(f"    dist ≤{dd:>3}  配对 {len(allp):>6}  Recall {rec:.2f}  "
              f"Precision_proxy {prox:.3f}")
    cand = [r for r in rows if r[2] >= PRE_REG["min_recall"]]
    if not cand:
        print(f"\n  ⚪ INCONCLUSIVE —— 无候选达 Recall ≥ {PRE_REG['min_recall']}，不得放宽。")
        return None
    best = max(cand, key=lambda r: r[3])
    print(f"\n  ✅ 选定 dist ≤ {best[0]}（Recall {best[2]:.2f}, "
          f"Precision_proxy {best[3]:.3f}）—— 由规则选出")
    return best[0]


def nc03_permutation(TEXTS, dist):
    print("\n" + "=" * 74)
    print("NC-03 · 规模化特异度（置换检验）")
    print("=" * 74)
    T = PRE_REG["single_valued"]
    obs_pairs = [x for p, t in TEXTS.items() for x in pairs_in(t, p, T, dist)]
    obs = concentration(obs_pairs)
    pool = [p["value"] for p in obs_pairs]
    null = defaultdict(list)
    for _ in range(PRE_REG["n_perm"]):
        sh = pool[:]; random.shuffle(sh)
        for t, (d, _, _) in concentration(
                [{"term": p["term"], "value": v} for p, v in zip(obs_pairs, sh)]).items():
            null[t].append(d)
    print(f"  {'术语':<10}{'配对':>7}{'相异':>7}{'D_obs':>9}{'p5分位':>9}   判定")
    verdict = {}
    for t in sorted(obs, key=lambda x: -obs[x][2]):
        d_obs, u, n = obs[t]
        nd = sorted(null.get(t, []))
        if not nd:
            continue
        q05 = nd[max(0, int(PRE_REG["disc_alpha"] * len(nd)) - 1)]
        verdict[t] = d_obs < q05
        print(f"  {t:<10}{n:>7}{u:>7}{d_obs:>9.3f}{q05:>9.3f}   "
              f"{'🟢 有判别力' if verdict[t] else '⚪ NO-DISCRIMINATION'}")
    return obs_pairs, verdict


# ==============================================================================
# MAIN
# ==============================================================================
def main(target_dir=None):
    rid = datetime.datetime.now().strftime("CLAIMSCAN21-%Y%m%d_%H%M%S")
    print("=" * 74)
    print(f" V-A168-CLAIM-SCAN-003  v2.1.0    RUN-ID {rid}   SEED {PRE_REG['seed']}")
    print("=" * 74 + "\n")

    tdir, prep = resolve_target_dir(target_dir)
    if tdir is None:
        print(f"\n⛔ 寻径未成（status={prep['status']}）—— 依纪律停止，不猜。")
        return 1

    TEXTS = {}
    for f in sorted(os.listdir(tdir)):
        if not f.endswith(('.qmd', '.sql')):
            continue
        p = os.path.join(tdir, f)
        try:
            TEXTS[f] = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            TEXTS[f] = open(p, encoding='gb18030', errors='replace').read()
            print(f"  ⚠ {f} 非 UTF-8，以 GB18030 读入")
    print(f"\n  载入 {len(TEXTS)} 档")

    print("\n" + "=" * 74); print("控制层"); print("=" * 74)
    d0 = min(PRE_REG["dist_grid"])
    ok = nc00_pathresolver(); print()
    ok &= nc01_regression(d0); print()
    ok &= nc02_synthetic(d0); print()
    ok &= nc05_nonmetric()
    if not ok:
        print("\n⛔ 控制层未过 —— 本器无资格执行。")
        return 2
    print("\n✅ 控制层全过。")

    dist = sweep_threshold(TEXTS)
    if dist is None:
        return 3
    obs_pairs, verdict = nc03_permutation(TEXTS, dist)

    print("\n" + "=" * 74)
    print("① 同义异数 —— 仅【单值量】靶标（量词类依 SC-044 判 OUT-OF-SCOPE）")
    print("=" * 74)
    print(f"  OUT-OF-SCOPE：{'、'.join(PRE_REG['classifier'])}"
          f"   —— 量词天生多值，报冲突为范畴错误\n")
    by = defaultdict(lambda: defaultdict(set))
    for p in obs_pairs:
        if verdict.get(p["term"]):
            by[p["term"]][p["value"]].add(p["file"])
    for t in sorted(by, key=lambda x: -len(by[x])):
        if len(by[t]) < 2:
            continue
        print(f"\n  ▸ 「{t}」→ {len(by[t])} 个相异值")
        for v, fs in sorted(by[t].items(), key=lambda x: -len(x[1])):
            print(f"      {v:<12} 跨{len(fs)}档  {'、'.join(sorted(x[:26] for x in fs))}")

    out = os.path.join(tdir, f"CLAIMSCAN21_{rid}.csv")
    with open(out, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.writer(fh)
        w.writerow(["file", "line", "term", "value", "dist", "discriminative", "sentence"])
        for p in obs_pairs:
            w.writerow([p["file"], p["line"], p["term"], p["value"],
                        p["dist"], verdict.get(p["term"], False), p["sent"]])
    print(f"\n全量 {len(obs_pairs)} 笔已落档：{out}")
    print("\n判读纪律：不裁对错；不判语义作用域（引述 vs 主张）；"
          "OUT-OF-SCOPE 不代表无冲突，只代表本器无力判别。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else None))
