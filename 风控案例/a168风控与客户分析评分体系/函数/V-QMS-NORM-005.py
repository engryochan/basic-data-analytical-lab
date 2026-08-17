#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID   V-QMS-NORM-005
 VERSION        1.3.1  （v1.3.1 修 SC-052 真根因：set 迭代序不确定）  （v1.3 补 R-PATH-NORM；修 SC-052 种子污染）  （v1.2.2 修 NC-M3-02 假阳性：判据由全档字串改为执行码路径）  （v1.2.1 封 M3 能力边界与门槛纪律；数值未改）  （v1.1 加交叉引用；v1.2 修目录式刷过漏洞）
 PURPOSE        规范卷之【第 Ⅰ 类劣势】度量：可测量者，给度量＋门槛＋闸
                  M1 概念覆盖率   —— 改版/合并是否遗失实质内容
                  M2 规范膨胀     —— 条数/字节/层级分布
                  M3 重复立法     —— 跨卷语义重叠（置换检验定基线）
                                     ★ 候选发现器，非裁判器 —— 见 §M3-PASSPORT
                  M4 退役覆盖率   —— 多少条规范有 RETIREMENT

 NOT-CAPABLE-OF（本器不能回答）
   · 一条规范是否【正确】（规范无真值，只能后果检验）
   · 结构性劣势（supersedes 宣告、法源层级）—— 属制度设计，非度量问题
   · 自审之独立性缺口 —— 统计无法制造独立复核者
   · 遗失之内容是否【应该】遗失（只报遗失，不裁去留）

 SC-LINKED-DEFECTS
   SC-047  以窄命题之验证结果冒充宽命题
           → 根治：M1 强制【逐概念】列示，禁以总分掩盖单项遗失
   SC-040  以 observed fraction 冒充概率参数
           → 根治：M3 之相似度门槛由【置换检验】取得，不硬编
   SC-043  toy control 通过而真实规模失效
           → 根治：M3 直接跑真实规范卷，非合成样本

 STOP-ANCHOR  A1（计数、比值、n-gram 集合运算皆纯算术）
              A2（随机种子固定，任何人可复算）
              A3（探针集与门槛于比对前写死）

 GATE         NG-1 概念覆盖率 < 100% → 该合并/改版 BLOCKED，不得宣告 supersedes
              NG-2 退役覆盖率 = 0%   → 该卷标 PERPETUAL-RISK
              NG-3 M3 显著高于置换基线 → 报重复立法候选，须裁并
================================================================================
"""
import re, sys, os, json, random, statistics, itertools
from collections import defaultdict

PRE_REG = {
    "seed": 20260815,
    "n_perm": 300,
    "ngram": 8,                 # 字符 n-gram 长度
    "cover_gate": 1.00,         # NG-1 门槛：概念覆盖率须 100%
    "sim_alpha": 0.01,          # M3 置换检验显著水平
    # ── 概念探针（合并/改版前写死；每项须为【实质内容】而非措辞）─────────
    "probes": [
        ("铁律·降级不禁无证降级禁", "无证降级禁"),
        ("铁律·证据不足是彻查理由", "彻查理由"),
        ("彻查=走完冻结序", "冻结取证序"),
        ("SC-031 与 A-05/06 之判别", "SC-031"),
        ("三锚 A1 数学恒等式", "数学恒等式"),
        ("三锚 A2 机械可复算", "机械可复算"),
        ("三锚 A3 预注册", "预注册"),
        ("锚非公理·因果不相交", "因果不相交"),
        ("Agrippa 三难之指认", "Agrippa"),
        ("降幅闭式 (1−p)(1−ρ)", "(1−p)(1−ρ)"),
        ("NOT-CAPABLE-OF 必填", "NOT-CAPABLE-OF"),
        ("NEG-CONTROL 记实返值", "实际返回值"),
        ("Upgrade ≠ Certification", "回归测试"),
        ("独立性论两两非单体", "pairwise") ,
        ("INDEP 移出 min 池", "min 池"),
        ("有限影响回溯", "有限影响回溯"),
        ("SC 八栏", "Effective Period"),
        ("四条共压一底座", "5.061e-15"),
        ("ISO 17025 不适用之论证", "17025"),
        ("单人项目职责分离不可得", "职责分离"),
        ("RETIREMENT 设立当日写死", "RETIREMENT"),
        ("红线五条审计", "RL-005"),
        ("RL-001 语义式改写全文", "预测力天花板之自相关值"),
        ("规范增生核心指认", "口径宗精简"),
        ("MVG 四项", "MVG"),
        ("Gate/QG 定义", "QG-2"),
        ("比例原则挂 severity", "比例原则"),
    ],
    # ── 规范层级关键词（M2 分层用）─────────────────────────────────────
    "layers": {"铁律": ["铁律", "IL-0"], "纪律": ["纪律", "须", "禁"],
               "建议": ["建议", "宜", "可"], "个案": ["批 61", "DB62", "56,612"]},
}
random.seed(PRE_REG["seed"])



# ==============================================================================
# R-PATH-NORM · 自动寻径（v1.3 补装；纪律同 R-PATH-001／R-PATH-M1）
#   ① 有界搜索 ② 逐候选报分 ③ 零命中必败 ④ 并列不代选 ⑤ 归档件须避特征字
# ==============================================================================
SEARCH_UP, SEARCH_DOWN = 4, 2
NORM_PATS = ["红队论证卷", "RL-QMS", "合卷"]      # 三卷之档名特征


def resolve_norm_docs(verbose=True):
    import glob as _g, datetime as _dt
    try:
        origin = os.path.dirname(os.path.abspath(__file__)); src = "__file__"
    except NameError:
        origin, src = os.getcwd(), "cwd（__file__ 不可得，已明记）"
    roots, cur = [], origin
    for _ in range(SEARCH_UP + 1):
        roots.append(cur)
        par = os.path.dirname(cur)
        if par == cur:
            break
        cur = par
    seen = []
    for r in roots:
        for d in range(SEARCH_DOWN + 1):
            pat = os.path.join(r, *(['*'] * d)) if d else r
            for x in ([pat] if d == 0 else _g.glob(pat)):
                if os.path.isdir(x):
                    x = os.path.abspath(x)
                    if x not in seen:
                        seen.append(x)
    hits = {k: [] for k in NORM_PATS}
    for d in seen:
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for n in names:
            if not n.endswith('.md'):
                continue
            for k in NORM_PATS:
                if k in n:
                    hits[k].append(os.path.join(d, n)); break
    if verbose:
        print("=" * 74); print("R-PATH-NORM · 自动寻径"); print("=" * 74)
        print(f"  起点   : {origin}   （来源：{src}）")
        print(f"  搜索域 : 向上 {SEARCH_UP} 层 × 向下 {SEARCH_DOWN} 层（有界）")
        print(f"  特征   : {'、'.join(NORM_PATS)}\n")
        for k in NORM_PATS:
            print(f"  「{k}」候选 {len(hits[k])}")
            for i, f in enumerate(hits[k], 1):
                mt = _dt.datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
                print(f"     {i}. mtime {mt}   {f}")
    miss = [k for k in NORM_PATS if not hits[k]]
    tie = [k for k in NORM_PATS if len(hits[k]) > 1]
    if miss:
        if verbose:
            print(f"\n⛔ 零命中：{'、'.join(miss)} 未寻获。")
            print("   依 SC-029 纪律，零结果必须失败退出，不得静默续行。")
            print("   请确认三卷同置一处，或以显式路径重跑：")
            print("     %run -- <本脚本> <甲> <RL-QMS> <乙>")
        return None
    if tie:
        if verbose:
            print(f"\n⚪ INCONCLUSIVE —— {'、'.join(tie)} 候选并列，本器【不代选】（SC-032）。")
            print("   ⚠ 归档／BEFORE 副本须置于搜索域外，或改名避开特征字。")
        return None
    out = [hits[k][0] for k in NORM_PATS]
    if verbose:
        print("\n  ✅ 三卷定位完成\n")
    return out


def read(p):
    try:
        return open(p, encoding='utf-8').read()
    except UnicodeDecodeError:
        return open(p, encoding='gb18030', errors='replace').read()


def norm(t):
    """归一：去 markdown 装饰与空白，只留实体字元。"""
    t = re.sub(r'[`*_>#|\-\s]+', '', t)
    return t


def ngrams(t, n):
    t = norm(t)
    return set(t[i:i + n] for i in range(max(0, len(t) - n + 1)))


def jaccard(a, b):
    return len(a & b) / len(a | b) if (a | b) else 0.0


# ==============================================================================
# 控制层
# ==============================================================================
def controls():
    print("=" * 74); print("控制层"); print("=" * 74)
    ok = True
    # NC-A 概念探针须能检出人为遗失
    a = "本卷载明 无证降级禁 与 有限影响回溯 两条。"
    b = "本卷载明 无证降级禁 一条。"
    ca = sum(1 for _, k in PRE_REG["probes"] if k in a)
    cb = sum(1 for _, k in PRE_REG["probes"] if k in b)
    p1 = (ca == 2 and cb == 1)
    print(f"  NC-A 遗失可检出      期望 2→1   实得 {ca}→{cb}   {'PASS' if p1 else 'FAIL'}")
    ok &= p1
    # NC-B 相同文本相似度须为 1；无关文本须远低
    x = ngrams("质量管理体系之铁律与验证器之适用域", 8)
    y = ngrams("质量管理体系之铁律与验证器之适用域", 8)
    z = ngrams("百家乐靴末段投注比例与荷官轮值时长统计", 8)
    p2 = (abs(jaccard(x, y) - 1.0) < 1e-9 and jaccard(x, z) < 0.1)
    print(f"  NC-B 相似度端点      期望 1.0 / <0.1   实得 "
          f"{jaccard(x,y):.3f} / {jaccard(x,z):.3f}   {'PASS' if p2 else 'FAIL'}")
    ok &= p2
    # NC-C 空卷不得报 100% 覆盖
    cov = sum(1 for _, k in PRE_REG["probes"] if k in "") / len(PRE_REG["probes"])
    p3 = (cov == 0.0)
    print(f"  NC-C 空卷不伪报      期望 0.00   实得 {cov:.2f}   "
          f"{'PASS' if p3 else 'FAIL'}")
    ok &= p3
    # NC-D 可解析交叉引用须算覆盖（v1.1 新增）
    src = {"来源卷.md": "……本节标题 §四 · 对原七层图之指认 ……内容……"}
    tgt = "- **Agrippa 三难之指认** ↗ `来源卷.md` §四 · 对原七层图之指认"
    okd, _, _ = resolve_xref(tgt, "Agrippa 三难之指认", src)
    print(f"  NC-D 有效引用算覆盖  期望 True    实得 {okd}   {'PASS' if okd else 'FAIL'}")
    ok &= okd
    # NC-E 悬空引用【不得】算覆盖
    bad1 = "- **Agrippa 三难之指认** ↗ `不存在.md` §四 · 对原七层图之指认"
    bad2 = "- **Agrippa 三难之指认** ↗ `来源卷.md` §九十九 · 查无此节"
    e1, _, _ = resolve_xref(bad1, "Agrippa 三难之指认", src)
    e2, _, _ = resolve_xref(bad2, "Agrippa 三难之指认", src)
    pe = (not e1) and (not e2)
    print(f"  NC-E 悬空引用不算    期望 False/False   实得 {e1}/{e2}   "
          f"{'PASS' if pe else 'FAIL'}")
    ok &= pe
    # NC-F 目录式引用不得以字面命中刷过直接覆盖（v1.2）
    body_only = '\n'.join(l for l in
        "- **Agrippa 三难之指认** ↗ `x.md` §一\n本卷正文并未论述该项。".split('\n')
        if '↗' not in l)
    pf = ("Agrippa" not in body_only)
    print(f"  NC-F 目录式引用不刷过  期望 False   实得 "
          f"{'Agrippa' in body_only}   {'PASS' if pf else 'FAIL'}")
    ok &= pf
    # ── M3 Passport 之控制（1 正 2 负）──
    u1 = ngrams("甲卷之回溯影响矩阵含二十四列与边界比对之限定语义载荷说明", 8)
    u2 = ngrams("甲卷之回溯影响矩阵含二十四列与边界比对之限定语义载荷说明", 8)
    u3 = ngrams("荷官轮值时长与靴末段投注比例之月度统计口径说明", 8)
    pg = jaccard(u1, u2) == 1.0
    print(f"  PC-M3-01 保全后同一      期望 1.000   实得 {jaccard(u1,u2):.3f}   "
          f"{'PASS' if pg else 'FAIL'}")
    ok &= pg
    ph = jaccard(u1, u3) < 0.05
    print(f"  NC-M3-01 无关内容低相似  期望 <0.05   实得 {jaccard(u1,u3):.3f}   "
          f"{'PASS' if ph else 'FAIL'}")
    ok &= ph
    # NC-M3-02 门槛须由零分布取得，不得为硬编常数
    #   ★ 判据修正（2026-08-15）：前版以【全档字串搜寻】判定，
    #     会把 Passport 内之【禁令原文】与【历史读数登记】误判为硬编 → 假阳性。
    #     今改为只验 M3 函数【执行码】之取值路径，且先剥除注释。
    import inspect
    body = inspect.getsource(M3)
    code = '\n'.join(l.split('#')[0] for l in body.split('\n'))
    from_null = bool(re.search(r'\bq\s*=\s*null\s*\[', code))
    hard = bool(re.search(r'\bq\s*=\s*[-+]?\d*\.?\d+\s*$', code, re.M))
    pi = from_null and not hard
    print(f"  NC-M3-02 门槛由零分布取得  期望 q←null[…] 且无字面赋值   实得 "
          f"{'q←null[…]' if from_null else '未取自零分布'}"
          f"{'，另有字面赋值 ⛔' if hard else ''}   {'PASS' if pi else 'FAIL'}")
    ok &= pi
    # NC-M3-03 假阳性回归：Passport 内之禁令原文不得触发 NC-M3-02
    #   （本条即 2026-08-15 该假阳性之回归测试）
    fake = "# 禁写：M3 threshold = 0.0110\nq = null[3]\n"
    fake_code = '\n'.join(l.split('#')[0] for l in fake.split('\n'))
    pj = bool(re.search(r'\bq\s*=\s*null\s*\[', fake_code)) and \
         not re.search(r'\bq\s*=\s*[-+]?\d*\.?\d+\s*$', fake_code, re.M)
    print(f"  NC-M3-03 禁令原文不误判    期望 PASS（注释内之 0.0110 不算）   实得 "
          f"{'不误判' if pj else '仍误判 ⛔'}   {'PASS' if pj else 'FAIL'}")
    ok &= pj
    # NC-M3-04 可复算性：置换序列不得受 set 迭代序影响（SC-052 之回归测试）
    #   判据：以两个【内容相同但插入序不同】之集合建 pool，摊平后须得同一序列
    sa = set("质量管理体系铁律验证器适用域")
    sb = set(reversed(list("质量管理体系铁律验证器适用域")))
    pk = (sorted(sa) == sorted(sb)) and (list(sa) is not list(sb))
    src_m3 = inspect.getsource(M3)
    pk = pk and ('sorted(' in src_m3.split('pool =')[1].split('\n')[0]) \
             and ('rng.shuffle' in src_m3)
    print(f"  NC-M3-04 置换可复算      期望 pool 已排序 且 用 rng   实得 "
          f"{'是' if pk else '否 ⛔'}   {'PASS' if pk else 'FAIL'}")
    ok &= pk
    print(f"\n{'✅ 控制层全过' if ok else '⛔ 控制层未过'}\n")
    return ok


# ==============================================================================
# M1 · 概念覆盖率（SC-047 根治：逐概念列示，禁以总分掩盖）
# ==============================================================================
def resolve_xref(target, label, sources):
    """交叉引用是否【可解析】：须同时满足三条，缺一即不算覆盖。
         ① 目标卷内有一行同时含 概念标签 与 ↗ 标记
         ② 该行指名之来源档确实存在于 sources
         ③ 该行所指之 §节 字串确实出现于该来源档
       悬空引用（指到不存在之档或不存在之节）一律【不算覆盖】。
    """
    for line in target.split('\n'):
        if '↗' not in line or label not in line:
            continue
        for sname, stext in sources.items():
            if sname not in line:
                continue
            m = re.search(r'§[^\s`｜]+', line.split('↗', 1)[1])
            if m and m.group(0) in stext:
                return True, sname, m.group(0)
            return False, sname, "§节不存在 → 悬空"
        return False, "?", "来源档不存在 → 悬空"
    return False, None, None


def M1(sources, target, tname):
    print("=" * 74)
    print(f"M1 · 概念覆盖率 —— 来源诸卷 → {tname}")
    print("  （v1.1：接受【可解析交叉引用】为覆盖；悬空引用不算）")
    print("=" * 74)
    rows, lost, xr = [], [], []
    # ★ v1.2 修：直接覆盖须在【交叉引用行之外】成立。
    #   否则「Agrippa 三难之指认 ↗ …」这类目录式引用会以字面命中刷过探针。
    body = '\n'.join(l for l in target.split('\n') if '↗' not in l)
    for lab, key in PRE_REG["probes"]:
        insrc = [n for n, t in sources.items() if key in t]
        direct = key in body
        okx, sname, sec = (False, None, None)
        if not direct:
            okx, sname, sec = resolve_xref(target, lab, sources)
            if okx:
                xr.append((lab, sname, sec))
            elif sname is not None:
                print(f"  🔴 悬空引用：{lab} → {sname} {sec}")
        intgt = direct or okx
        if insrc and not intgt:
            lost.append((lab, insrc))
        rows.append((lab, bool(insrc), intgt))
    have = [r for r in rows if r[1]]
    cov = sum(1 for r in have if r[2]) / len(have) if have else 1.0
    print(f"  探针 {len(rows)}   来源含有 {len(have)}   目标存活 "
          f"{sum(1 for r in have if r[2])}   覆盖率 {cov:.1%}")
    if xr:
        print(f"\n  🔗 以可解析交叉引用覆盖 {len(xr)} 项（未复制内容，故不增 M3 重复）：")
        for lab, s, sec in xr:
            print(f"      · {lab}  ↗ {s} {sec}")
    if lost:
        print(f"\n  🔴 遗失 {len(lost)} 项（逐项列示，禁以总分掩盖 —— SC-047）：")
        for lab, src in lost:
            print(f"      · {lab}    来源：{'、'.join(src)}")
    gate = cov >= PRE_REG["cover_gate"]
    print(f"\n  NG-1 闸：覆盖率 {cov:.1%} {'≥' if gate else '<'} "
          f"{PRE_REG['cover_gate']:.0%} → {'🟢 PASS' if gate else '🔴 BLOCKED'}")
    if not gate:
        print("       ⛔ 该合并/改版【不得宣告 supersedes / consolidates】，来源卷须保留。")
    return cov, lost


# ==============================================================================
# M2 · 规范膨胀
# ==============================================================================
def M2(docs):
    print("\n" + "=" * 74); print("M2 · 规范膨胀监控"); print("=" * 74)
    print(f"  {'卷':<34}{'字节':>9}{'行':>7}{'节':>6}{'编号条':>8}{'祈使句':>8}")
    tot = defaultdict(int)
    for n, t in docs.items():
        secs = len(re.findall(r'^#{1,3}\s+', t, re.M))
        ids = len(set(re.findall(r'\b(?:SC|RL|QG|IL|A)-\d{2,3}\b', t)))
        imper = len(re.findall(r'(?:须|必须|禁|不得|一律)', t))
        print(f"  {n[:32]:<34}{len(t.encode()):>9}{t.count(chr(10)):>7}"
              f"{secs:>6}{ids:>8}{imper:>8}")
        tot["bytes"] += len(t.encode()); tot["ids"] += ids; tot["imper"] += imper
    print(f"  {'合计':<34}{tot['bytes']:>9}{'':>7}{'':>6}{tot['ids']:>8}{tot['imper']:>8}")
    print(f"\n  祈使句密度 = {tot['imper']} 条约束 ÷ {tot['bytes']/1024:.0f} KB "
          f"= {tot['imper']/(tot['bytes']/1024):.2f} 条/KB")
    print("  ⚠ 本指标无预设门槛 —— 首次量测即为基线，其【趋势】方有判读力。")
    return tot



# ==============================================================================
# §M3-PASSPORT  ·  M3 · Duplicate-Legislation Similarity
#   版本 1.1（2026-08-15 封口；本次只补能力边界与门槛纪律，不改任何数值）
# ------------------------------------------------------------------------------
# CAPABLE-OF
#   ① 测量规范单元之间的文本／语义相似程度
#   ② 以置换零分布建立【当前语料下】之经验阈值
#   ③ 标出超过阈值之高相似单元对
#   ④ 比较不同版本之间相似度之变化
#
# NOT-CAPABLE-OF   ★ 本器为【候选重复发现器】，非【重复立法裁判器】
#   ① 单凭相似度判定两单元属「有害重复立法」
#   ② 区分「合法内容保全」与「不必要重复」
#   ③ 判定哪个版本应当删除
#   ④ 证成 XREF / DELETE / consolidates 之治理裁决
#   ⑤ 将 M3 数值变化直接解释为治理质量之改善或恶化
#
#   已知实例（2026-08-15）：甲→乙内容保全合并后，
#     M3 由 0.677 升至 0.928。此升高之机械成因为
#     「乙由甲之压缩版恢复为甲之全文，两卷文本自然趋同」，
#     **不是重复治理恶化**。本器无力自行区分二者。
#
# THRESHOLD-DISCIPLINE   ★ 置换门槛非常数，禁沿用旧值
#   禁写：M3 threshold = 0.0110
#   须写：M3 threshold = permutation-derived（当轮重取）
#   触发重取之条件：任何会改变相似度结构之语料操作
#     语料改变 → 重生 permutation null → 重算 99% 分位
#              → 重算 observed M3 → 方可比较
#
# HISTORY（修解释层，不修历史读数）
#   v2.1  M3 = 151 / 2016   threshold = 0.0110
#   v2.2  M3 = 152 / 2016   threshold = 0.0104
#   INTERPRETATION: M3 is not capable of distinguishing
#     content-preservation similarity from harmful duplication.
#   ⚠ 禁为使旧结论符合新认识而回写旧数据 —— 此为审计污染
#
# STOP-ANCHOR  A1（Jaccard 与分位数皆纯算术）
#              A2（种子固定，可复算）
#              A3（sim_alpha 与 ngram 于比对前写死）
# CERTIFICATION  执行验证 🟢 CERTIFIED·A2 ／ 设计验证 🔴 NOT CERTIFIED（无第二实作）
# ==============================================================================

# ==============================================================================
# M3 · 重复立法（置换检验定基线，不硬编门槛）
# ==============================================================================
def M3(docs):
    print("\n" + "=" * 74)
    print("M3 · 重复立法检测（门槛由置换检验取得，非硬编 —— SC-040 根治）")
    print("=" * 74)
    units = {}
    for n, t in docs.items():
        for m in re.finditer(r'^#{2,3}\s+(.+)$', t, re.M):
            s = m.start()
            e = t.find('\n#', s + 1)
            body = t[s:e if e > 0 else len(t)]
            if len(norm(body)) > 120:
                units[f"{n[:14]}｜{m.group(1)[:34]}"] = ngrams(body, PRE_REG["ngram"])
    ks = list(units)
    print(f"  规范单元 {len(ks)} 个（跨 {len(docs)} 卷，节长 >120 字元者）")
    obs = [(a, b, jaccard(units[a], units[b]))
           for a, b in itertools.combinations(ks, 2)]
    # ★ SC-052 斧正：置换在本函数【内部重设种子】，
    #   使读数不受此前任何 random 调用（如控制层）之序列消耗影响。
    #   未修前：同码同语料两次执行门槛 0.0110 / 0.0104 不同 → A2 不成立。
    rng = random.Random(PRE_REG["seed"])
    # 置换零分布：打散各单元之 n-gram 后重算
    # ★ SC-052 根因（更正）：pool 由 set 摊平，而 set 之迭代顺序受
    #   PYTHONHASHSEED 影响，【每个进程不同】。仅固定 rng 种子不足以复算。
    #   须先【排序】使序列本身确定，rng 方能产生可复算之置换。
    #   （前版归因为「调用序列消耗」，该归因不成立，已更正。）
    pool = sorted(g for u in units.values() for g in u)
    null = []
    sizes = [len(units[k]) for k in ks]
    for _ in range(PRE_REG["n_perm"]):
        rng.shuffle(pool)
        i, sh = 0, []
        for s in sizes:
            sh.append(set(pool[i:i + s])); i += s
        a, b = rng.sample(range(len(sh)), 2)
        null.append(jaccard(sh[a], sh[b]))
    null.sort()
    q = null[int((1 - PRE_REG["sim_alpha"]) * len(null)) - 1]
    print(f"  置换零分布：均值 {statistics.mean(null):.4f}   "
          f"{1-PRE_REG['sim_alpha']:.0%} 分位 = {q:.4f}")
    print(f"  ⚠ 此门槛【仅属本轮语料】，非 M3 之常数。语料一变即须重取，禁沿用。")
    hits = sorted([o for o in obs if o[2] > q], key=lambda x: -x[2])
    print(f"  超门槛之单元对：{len(hits)} / {len(obs)}   "
          f"（占 {len(hits)/max(1,len(obs)):.2%}）")
    for a, b, s in hits[:12]:
        print(f"    {s:.3f}  {a}\n            ↔ {b}")
    if len(hits) > 12:
        print(f"    …另 {len(hits)-12} 对")
    print("\n  ── M3 能力边界（见 §M3-PASSPORT）──")
    print("  本器为【候选重复发现器】，非【重复立法裁判器】：")
    print("    · 不判相似是否构成【有害重复】")
    print("    · 不分【合法内容保全】与【不必要重复】")
    print("    · 不裁删除、不证成 XREF / DELETE / consolidates")
    print("    · M3 升降【不得】直接读作治理之改善或恶化")
    print("  实例：2026-08-15 甲→乙内容保全后 0.677→0.928，成因为文本自然趋同。")
    return hits, q


# ==============================================================================
# M4 · 退役覆盖率
# ==============================================================================
def M4(docs):
    print("\n" + "=" * 74); print("M4 · 退役条件覆盖率"); print("=" * 74)
    tot_rule = tot_ret = 0
    for n, t in docs.items():
        ids = set(re.findall(r'\b(?:SC|RL|QG|IL)-\d{2,3}\b', t))
        ret = len(re.findall(r'RETIREMENT|退役条件|退役', t))
        tot_rule += len(ids); tot_ret += ret
        print(f"  {n[:34]:<36} 编号规范 {len(ids):>3}   退役字样 {ret:>3}")
    cov = tot_ret / tot_rule if tot_rule else 0
    print(f"\n  编号规范合计 {tot_rule}   退役字样合计 {tot_ret}   粗覆盖 {cov:.1%}")
    print(f"  NG-2 闸：{'🟢' if cov > 0 else '🔴 PERPETUAL-RISK'}")
    print("  ⚠ 本指标只数字样，不证【该退役条件可执行】—— 须人工核每条之可判定性。")
    return cov


# ==============================================================================
def main(paths):
    print("=" * 74)
    print(" V-QMS-NORM-005  v1.3.1    SEED", PRE_REG["seed"])
    print("=" * 74 + "\n")
    if not controls():
        return 1
    docs = {os.path.basename(p): read(p) for p in paths if os.path.exists(p)}
    if len(docs) < 2:
        print("⛔ 须至少两卷方可比对。"); return 1
    src = {k: v for k, v in docs.items() if "合卷" not in k}
    tgt = [k for k in docs if "合卷" in k]
    if tgt:
        M1(src, docs[tgt[0]], tgt[0])
    M2(docs); M3(docs); M4(docs)
    print("\n" + "=" * 74)
    print("本器只处理【第 Ⅰ 类·可测量】之劣势。")
    print("第 Ⅱ 类（结构性：supersedes 宣告、法源层级、规范与审计混册）")
    print("  → 属制度设计，统计手段无效，须裁定。")
    print("第 Ⅲ 类（不可对治：自审无独立复核者、规范无真值）")
    print("  → 只能声明适用域，不得以任何度量宣称已解决。")
    print("=" * 74)
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        sys.exit(main(sys.argv[1:]))
    _p = resolve_norm_docs()
    sys.exit(1 if _p is None else main(_p))
