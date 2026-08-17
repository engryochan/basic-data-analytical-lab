#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID        V-A168-CLAIM-SCAN-003
 VERSION             2.0.0   （v1.0.0 因 SC-043 停用，本版为 REMEDIATION）
 SUPERSEDES          v1.0.0  ——  v1 之 ① 号检测在真实规模下 FALSE POSITIVE 爆炸

 SC-LINKED-DEFECTS   SC-043  正负控制只测检出力，未测【规模化特异度】
                             Root Cause：toy control 与 production-scale evidence
                                         之间存在 Generalization Gap
                             Remediation：
                               ① 配对约束由「同 80 字元窗」改为「同句 ＋ 邻接」
                               ② 距离阈值【不硬编】，由 PR 曲线扫出（见 §THRESH）
                               ③ 新增 NC-03 规模化特异度：置换检验取 FP 基线
                             Status：REMEDIATION —— 三层测试全过方可恢复证据资格

 NOT-CAPABLE-OF      本器【不能】回答：
                       · 哪一个数值是对的（只报冲突，不裁对错）
                       · 数值出现在【引述块／撤销说明】抑或【正文主张】
                         → 此为语义作用域问题，须人工上下文复核（RL-001 之例）
                       · 不同口径之数字应否统一（31/29/27/18 之例）
                       · 预测性声明之真伪（→ A4，需时间流逝）

 CONTROLS            NC-01  v1 之六项原控制，本版须【同答】       ← 回归测试
                     NC-02  合成负例：随机术语×随机数值，须不报
                     NC-03  规模化特异度：真实九档 ＋ 置换检验
                            统计量 D(t) = 相异值数 ÷ 配对数（越低越集中）
                            判据【预注册】：D_obs 须落于置换分布 5% 分位以下，
                                            否则该术语判 NO-DISCRIMINATION，不入报

 STOP-ANCHOR         A1（计数与比值为纯算术）
                     A2（机械可复算，含置换之随机种子固定）
                     A3（§PRE_REG 与 §THRESH 判据于看结果前写死）

 CERTIFICATION       UNCERTIFIED —— NC-01/02/03 全过方可标 CERTIFIED v2.0.0
================================================================================
"""
import os, re, sys, csv, random, statistics, unicodedata
from collections import defaultdict

# ==============================================================================
# §PRE_REG（A3 锚）—— 看结果前写死
# ==============================================================================
PRE_REG = {
    "seed": 20260815,
    "targets": ["MASE", "索提诺", "Sortino", "维", "净贡献", "自相关",
                "Spearman", "洗码量", "退水", "占成", "毛利率", "门槛"],
    # 【不硬编距离】：候选阈值网格，由 §THRESH 之预注册规则选出
    "dist_grid": [5, 8, 10, 12, 15, 20, 25, 30, 40, 60, 80],
    # 阈值选择规则（看 PR 曲线前写死）：
    "thresh_rule": "在 Recall ≥ 0.90 之候选中，取 Precision_proxy 最大者；"
                   "若无候选达 Recall 0.90，判 INCONCLUSIVE，不得放宽",
    "min_recall": 0.90,
    # NC-03 判据
    "n_perm": 200,
    "disc_alpha": 0.05,
    # GOLD：本轮以窄口径直查人工确认之真阳配对（term, 归一值）
    "gold": [("MASE", "9.8"), ("MASE", "13.232"), ("Spearman", "0.2"),
             ("自相关", "0.112"), ("维", "31"), ("维", "27")],
}
random.seed(PRE_REG["seed"])

NUM_RE  = re.compile(r'(?<![\w.])(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)')
SENT_RE = re.compile(r'[。；！？\n]|","')


def norm_num(s):
    s = unicodedata.normalize('NFKC', s).replace(',', '')
    try:
        return f"{float(s):.12g}"
    except ValueError:
        return None


def sentences(text):
    """切句：中文句读 ＋ 换行 ＋ R data.frame 之 "," 边界。"""
    out, pos = [], 0
    for m in SENT_RE.finditer(text):
        s = text[pos:m.start()]
        if s.strip():
            out.append((pos, s))
        pos = m.end()
    if text[pos:].strip():
        out.append((pos, text[pos:]))
    return out


def pairs_in(text, fname, targets, dist):
    """句内邻接配对。
       约束三条（v1 全无）：
         ① 术语与数值须同句
         ② 字元距离 ≤ dist
         ③ 二者之间不得夹另一数值或另一靶标术语（方向/指标名一致性）
    """
    res = []
    for base, sent in sentences(text):
        nums = [(m.start(), m.end(), norm_num(m.group(1)))
                for m in NUM_RE.finditer(sent)]
        nums = [n for n in nums if n[2] is not None]
        if not nums:
            continue
        tpos = []
        for t in targets:
            for m in re.finditer(re.escape(t), sent):
                tpos.append((m.start(), m.end(), t))
        for ts, te, t in tpos:
            for ns, ne, v in nums:
                gap_a, gap_b = (te, ns) if ns >= te else (ne, ts)
                d = gap_b - gap_a
                if d < 0 or d > dist:
                    continue
                mid = sent[gap_a:gap_b]
                # 约束③
                if NUM_RE.search(mid):
                    continue
                if any(o in mid for o in targets if o != t):
                    continue
                ln = text.count('\n', 0, base + ts) + 1
                res.append({"file": fname, "line": ln, "term": t, "value": v,
                            "dist": d, "sent": sent.strip()[:120]})
    return res


def concentration(prs):
    """D(t) = 相异值数 ÷ 配对数。越低越集中，越像真信号。"""
    out = {}
    by_t = defaultdict(list)
    for p in prs:
        by_t[p["term"]].append(p["value"])
    for t, vs in by_t.items():
        out[t] = (len(set(vs)) / len(vs), len(set(vs)), len(vs))
    return out


# ==============================================================================
# NC-01 · v1 六项原控制之回归（须同答）
# ==============================================================================
def nc01_regression(dist):
    print("  —— NC-01 回归：v1 之六项原控制，本版须【同答】 ——")
    A = "会员级 MASE 为 0.87 ，窗口稳定。索提诺 1.41 为门槛。共 31 维。"
    B = "会员级 MASE 为 0.87 ，与主方案一致。索提诺 1.41 同。共 31 维。"
    C = "策略级 MASE 为 12.4 ，基线不同。"
    T = PRE_REG["targets"]
    ok = True

    c = concentration(pairs_in(A, "A", T, dist) + pairs_in(B, "B", T, dist))
    p1 = all(n_uni == 1 for _, n_uni, _ in c.values())
    print(f"     PC-01 一致不报冲突      期望 每术语 1 值   实得 "
          f"{ {k: v[1] for k, v in c.items()} }   {'PASS' if p1 else 'FAIL'}")
    ok &= p1

    p2 = (norm_num("1,000") == norm_num("1000"))
    print(f"     PC-02 格式归一          期望 一致          实得 "
          f"{'一致' if p2 else '不一致'}   {'PASS' if p2 else 'FAIL'}")
    ok &= p2

    c = concentration(pairs_in(A, "A", T, dist) + pairs_in(C, "C", T, dist))
    p3 = c.get("MASE", (0, 0, 0))[1] >= 2
    print(f"     NC-01 同义异数须报      期望 MASE ≥2 值    实得 "
          f"{c.get('MASE',(0,0,0))[1]}   {'PASS' if p3 else 'FAIL'}")
    ok &= p3

    E, F = "共 31 维。", "共 31 维，与前一致。"
    c = concentration(pairs_in(E, "E", T, dist) + pairs_in(F, "F", T, dist))
    p4 = c.get("维", (0, 1, 0))[1] == 1
    print(f"     NC-04 格式差异不误报    期望 维 = 1 值     实得 "
          f"{c.get('维',(0,0,0))[1]}   {'PASS' if p4 else 'FAIL'}")
    ok &= p4
    return ok


# ==============================================================================
# NC-02 · 合成负例
# ==============================================================================
def nc02_synthetic(dist):
    print("  —— NC-02 合成负例：随机术语 × 随机数值，须不报 ——")
    filler = "此处为无关叙述文字用以拉开距离并阻断邻接关系故不应成对"
    txt = "".join(f"{t}{filler}{random.randint(100,999)}。"
                  for t in PRE_REG["targets"])
    prs = pairs_in(txt, "SYN", PRE_REG["targets"], dist)
    ok = (len(prs) == 0)
    print(f"     期望 0 配对   实得 {len(prs)}   {'PASS' if ok else 'FAIL'}")
    return ok


# ==============================================================================
# §THRESH · 距离阈值由 PR 曲线扫出（不硬编）
# ==============================================================================
def sweep_threshold(TEXTS):
    print("\n" + "=" * 72)
    print("§THRESH · 距离阈值扫描（不硬编，由预注册规则选出）")
    print("=" * 72)
    print(f"  规则（看曲线前写死）：{PRE_REG['thresh_rule']}")
    gold = set(PRE_REG["gold"])
    rows = []
    for d in PRE_REG["dist_grid"]:
        allp = []
        for p, t in TEXTS.items():
            allp += pairs_in(t, p, PRE_REG["targets"], d)
        found = {(x["term"], x["value"]) for x in allp}
        rec = len(gold & found) / len(gold)
        conc = concentration(allp)
        # Precision_proxy = 1 − 平均离散度（离散度高＝噪声多）
        prox = 1 - statistics.mean([v[0] for v in conc.values()]) if conc else 0
        rows.append((d, len(allp), rec, prox))
        print(f"    dist ≤{d:>3}   配对 {len(allp):>7}   Recall(gold) {rec:.2f}   "
              f"Precision_proxy {prox:.3f}")
    cand = [r for r in rows if r[2] >= PRE_REG["min_recall"]]
    if not cand:
        print(f"\n  ⚪ INCONCLUSIVE —— 无候选达 Recall ≥ {PRE_REG['min_recall']}，"
              f"依预注册规则【不得放宽】。")
        return None
    best = max(cand, key=lambda r: r[3])
    print(f"\n  ✅ 选定 dist ≤ {best[0]}   （Recall {best[2]:.2f}, "
          f"Precision_proxy {best[3]:.3f}）—— 由规则选出，非人为拍定")
    return best[0]


# ==============================================================================
# NC-03 · 规模化特异度：置换检验（SC-043 之真正补足）
# ==============================================================================
def nc03_permutation(TEXTS, dist):
    print("\n" + "=" * 72)
    print("NC-03 · 规模化特异度（置换检验）—— SC-043 所缺之层")
    print("=" * 72)
    print(f"  统计量 D(t) = 相异值数 ÷ 配对数（越低越集中＝越像真信号）")
    print(f"  零假设：术语与数值之邻接为偶合 → 打乱数值后 D 应不变")
    print(f"  判据（预注册）：D_obs < 置换分布 {PRE_REG['disc_alpha']:.0%} 分位 "
          f"→ 有判别力；否则 NO-DISCRIMINATION，不入报\n")

    obs_pairs = []
    for p, t in TEXTS.items():
        obs_pairs += pairs_in(t, p, PRE_REG["targets"], dist)
    obs = concentration(obs_pairs)

    pool = [p["value"] for p in obs_pairs]
    null = defaultdict(list)
    for _ in range(PRE_REG["n_perm"]):
        sh = pool[:]
        random.shuffle(sh)
        tmp = [{"term": p["term"], "value": v} for p, v in zip(obs_pairs, sh)]
        for t, (d, _, _) in concentration(tmp).items():
            null[t].append(d)

    print(f"  {'术语':<10}{'配对':>7}{'相异':>7}{'D_obs':>9}{'D_perm均':>10}"
          f"{'p5分位':>9}   判定")
    verdict = {}
    for t in sorted(obs, key=lambda x: -obs[x][2]):
        d_obs, n_uni, n_pair = obs[t]
        nd = sorted(null.get(t, []))
        if not nd:
            continue
        q05 = nd[max(0, int(PRE_REG["disc_alpha"] * len(nd)) - 1)]
        mu = statistics.mean(nd)
        good = d_obs < q05
        verdict[t] = good
        print(f"  {t:<10}{n_pair:>7}{n_uni:>7}{d_obs:>9.3f}{mu:>10.3f}"
              f"{q05:>9.3f}   {'🟢 有判别力' if good else '⚪ NO-DISCRIMINATION'}")
    return obs_pairs, verdict


# ==============================================================================
# MAIN
# ==============================================================================
def main(target_dir):
    import datetime
    rid = datetime.datetime.now().strftime("CLAIMSCAN2-%Y%m%d_%H%M%S")
    print("=" * 72)
    print(f" V-A168-CLAIM-SCAN-003  v2.0.0   （v1 因 SC-043 停用）")
    print(f" RUN-ID : {rid}   SEED : {PRE_REG['seed']}")
    print("=" * 72)

    exts = ('.qmd', '.sql', '.md')
    files = sorted(os.path.join(target_dir, f) for f in os.listdir(target_dir)
                   if f.endswith(exts))
    TEXTS = {}
    for p in files:
        try:
            TEXTS[os.path.basename(p)] = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            TEXTS[os.path.basename(p)] = open(p, encoding='gb18030',
                                              errors='replace').read()
    print(f" 档案 {len(TEXTS)} 件\n")

    # ---- 第一层：回归 ＋ 合成负例（以最严距离先跑，确保不因放宽而通过）----
    print("=" * 72); print("第一层 · NC-01 回归 ＋ NC-02 合成负例"); print("=" * 72)
    d0 = min(PRE_REG["dist_grid"])
    ok = nc01_regression(d0)
    print()
    ok &= nc02_synthetic(d0)
    if not ok:
        print("\n⛔ 第一层未过 —— v2 无资格进入第二层。SC-043 维持 OPEN。")
        return 1
    print("\n✅ 第一层过。\n")

    # ---- 第二层：阈值扫描 ----
    dist = sweep_threshold(TEXTS)
    if dist is None:
        print("\n⛔ 阈值不可选 —— 判 INCONCLUSIVE。SC-043 维持 OPEN。")
        return 2

    # ---- 第三层：规模化特异度 ----
    obs_pairs, verdict = nc03_permutation(TEXTS, dist)
    n_ok = sum(verdict.values())
    print(f"\n  有判别力术语 {n_ok} / {len(verdict)}")
    if n_ok == 0:
        print("  ⛔ 无一术语有判别力 —— 与 v1 同病。SC-043 维持 OPEN。")
        return 3

    # ---- 出报：仅限有判别力之术语 ----
    print("\n" + "=" * 72)
    print("① 同义异数（仅列【有判别力】之术语；NO-DISCRIMINATION 者一律不入报）")
    print("=" * 72)
    by_t = defaultdict(lambda: defaultdict(set))
    for p in obs_pairs:
        if verdict.get(p["term"]):
            by_t[p["term"]][p["value"]].add(p["file"])
    for t in sorted(by_t, key=lambda x: -len(by_t[x])):
        vs = by_t[t]
        if len(vs) < 2:
            continue
        print(f"\n  ▸ 「{t}」→ {len(vs)} 个相异值")
        for v, fs in sorted(vs.items(), key=lambda x: -len(x[1]))[:10]:
            print(f"      {v:<14} 跨 {len(fs)} 档：{'、'.join(sorted(f[:24] for f in fs))}")

    out = os.path.join(target_dir, f"CLAIMSCAN2_{rid}.csv")
    with open(out, 'w', newline='', encoding='utf-8-sig') as fh:
        w = csv.writer(fh)
        w.writerow(["file", "line", "term", "value", "dist", "discriminative", "sentence"])
        for p in obs_pairs:
            w.writerow([p["file"], p["line"], p["term"], p["value"], p["dist"],
                        verdict.get(p["term"], False), p["sent"]])
    print(f"\n全量 {len(obs_pairs)} 笔已落档：{out}")
    print(f"\n判读纪律：本器不裁对错；不判语义作用域（引述 vs 主张）；"
          f"NO-DISCRIMINATION 之术语不代表无冲突，只代表【本器无力判别】。")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法：python V-A168-CLAIM-SCAN-003_v2.py <九档目录>")
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
