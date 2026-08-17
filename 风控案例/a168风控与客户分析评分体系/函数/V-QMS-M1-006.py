#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 VALIDATOR PASSPORT
================================================================================
 VALIDATOR-ID   V-QMS-M1-006
 VERSION        1.3.1  （v1.3.1 补装 R-PATH-M1 自动寻径）
 PURPOSE        合并／压缩／转录／重排之【内容保全】三层检验
                  M1-A 结构完整性   —— 单元 ID、行数、栏数、顺序
                  M1-B 语义载荷完整性 —— 每个审计单元之必要限定语义
                  M1-C 引用完整性   —— 内容移至 xref 者，须验目标实体存在

 设计红线（本器自身之防退化条款）
   ★ M1-B 禁写成 `"24 列" in target`。
     判据为【栏内共现】：限定语义须与其所限定之对象出现于【同一表格栏】。
     单字散落他处一律不算 —— 否则只是把 SC-049 之 `key in target` 换地方重造。
   ★ M1-C 禁以标题或 xref 行满足内容检查（SC-049 之封堵）。

 NOT-CAPABLE-OF（本器不能回答）
   · 压缩后之措辞是否【语义等价】（只查载荷在否，不裁同义）
   · 哪一份是【应留】之版本（只报包含关系，不裁去留）
   · 载荷清单是否【完备】（清单由人裁定并预注册，本器不自创）
   · 表头栏名之语义等价性（如「是否重算」vs「已重算」→ 须人工裁）

 SC-LINKED-DEFECTS
   SC-049  目录式引用以字面命中刷过覆盖   → NC-M1-05 专项封堵
   SC-050  转录时压缩栏内文字致语义丢失   → M1-B 即为其回归测试
   SC-047  以窄命题之验证冒充宽命题       → 三层【分列报告】，禁以总分掩盖

 STOP-ANCHOR  A1（集合运算与字串定位皆纯算术）
              A2（机械可复算）
              A3（载荷清单于比对前写死，见 §PRE_REG）

 GATE  M1-A 失败 → BLOCKED（结构已异，不必续查）
       M1-B 失败 → BLOCKED，且【禁止将来源改为 xref】
       M1-C 悬空 → 该项不计覆盖
================================================================================
"""
import re, sys, os, hashlib

# ==============================================================================
# §PRE_REG（A3 锚）—— 载荷清单于比对前写死；本器不自创载荷
# ==============================================================================
PRE_REG = {
    "unit_id": r'`(SC-\d+)`',          # 审计单元之主键
    # 语义载荷：{单元ID: [(限定语义, 所限定之对象, 理由)]}
    # 判据 = 二者须【同栏共现】
    "payload": {
        "SC-018": [("24 列", "join", "界定 join 之作用域——几列参与"),
                   ("边界比对", "5.061e-15", "界定该读数之出处")],
        "SC-026": [("非零", "退出码", "界定机制——不捕之退出码须为非零")],
        "SC-027": [("声明区间", "档头", "界定越界对象——越过的是档头【声明的区间】")],
        "SC-016": [("浮点列", "字符串精确匹配", "界定误用之对象类型")],
        "SC-017": [("canonical key", "formatC", "界定失效之构件")],
        "SC-030": [("rows", "频数", "界定误用之量——rows 之频数而非相异 OFFSET")],
    },
}



# ==============================================================================
# R-PATH-M1 · 自动寻径（v1.3.1 补装；纪律同 R-PATH-001）
#   ① 有界搜索  ② 逐候选报分  ③ 零命中必败  ④ 并列不代选  ⑤ 同名异容告警
# ==============================================================================
SEARCH_UP, SEARCH_DOWN = 4, 2
PAT_A = "红队论证卷"          # 甲 SOURCE 之档名特征
PAT_B = "合卷"                # 乙 TARGET 之档名特征


def _enum_dirs(origin):
    import glob as _g
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
    return seen


def resolve_pair(verbose=True):
    try:
        origin = os.path.dirname(os.path.abspath(__file__))
        src = "__file__"
    except NameError:
        origin, src = os.getcwd(), "cwd（__file__ 不可得，已明记）"
    if verbose:
        print("=" * 72); print("R-PATH-M1 · 自动寻径"); print("=" * 72)
        print(f"  起点   : {origin}   （来源：{src}）")
        print(f"  搜索域 : 向上 {SEARCH_UP} 层 × 向下 {SEARCH_DOWN} 层（有界）")
        print(f"  特征   : 甲=「{PAT_A}」  乙=「{PAT_B}」\n")
    hits = {"A": [], "B": []}
    for d in _enum_dirs(origin):
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for n in names:
            if not n.endswith('.md'):
                continue
            f = os.path.join(d, n)
            if PAT_A in n:
                hits["A"].append(f)
            elif PAT_B in n:
                hits["B"].append(f)
    for k, lab in (("A", "甲 SOURCE"), ("B", "乙 TARGET")):
        if verbose:
            print(f"  {lab}  候选 {len(hits[k])}")
            for i, f in enumerate(hits[k], 1):
                import datetime as _dt
                mt = _dt.datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M')
                print(f"     {i}. mtime {mt}   {f}")
    if not hits["A"] or not hits["B"]:
        if verbose:
            miss = [lab for k, lab in (("A", "甲"), ("B", "乙")) if not hits[k]]
            print(f"\n⛔ 零命中：{'、'.join(miss)} 未寻获。")
            print("   依 SC-029 纪律，零结果必须失败退出，不得静默续行。")
            print("   若二卷未存于本机，须先下载；或以显式路径重跑：")
            print("     %run -- <本脚本> <甲路径> <乙路径>")
        return None, None
    if len(hits["A"]) > 1 or len(hits["B"]) > 1:
        if verbose:
            print("\n⚪ INCONCLUSIVE —— 候选并列，本器【不代选】（SC-032 同名异容防线）。")
        return None, None
    if verbose:
        print(f"\n  ✅ 甲 {hits['A'][0]}\n  ✅ 乙 {hits['B'][0]}\n")
    return hits["A"][0], hits["B"][0]


def read(p):
    return open(p, encoding='utf-8').read()


def extract_unit_table(text, section_kw):
    """取出指定节内之表格，回传 {unit_id: [栏1, 栏2, ...]} 与结构摘要。"""
    L = text.split('\n')
    idx = [i for i, l in enumerate(L) if section_kw in l and l.strip().startswith('#')]
    if not idx:
        return None, None
    i = idx[0]
    e = next((j for j in range(i + 1, len(L)) if re.match(r'^#{1,3}\s', L[j])), len(L))
    seg = L[i:e]
    header = next((l for l in seg if re.match(r'^\|\s*SC\s*\|', l.strip())), None)
    rows, order = {}, []
    for l in seg:
        m = re.match(r'\|\s*' + PRE_REG["unit_id"] + r'\s*\|(.*)\|\s*$', l.strip())
        if m:
            cols = [c.strip() for c in m.group(2).split('|')]
            rows[m.group(1)] = cols
            order.append(m.group(1))
    meta = {"header": header, "order": order,
            "ncol": len(next(iter(rows.values()))) if rows else 0,
            "nrow": len(rows), "seg_lines": len(seg)}
    return rows, meta


# ==============================================================================
# M1-A · 结构完整性
# ==============================================================================
def M1A(ra, ma, rb, mb):
    print("-" * 72); print("M1-A · 结构完整性"); print("-" * 72)
    ok = True
    same_id = set(ra) == set(rb)
    print(f"  单元 ID 集合   甲 {len(ra)} ／ 乙 {len(rb)}   "
          f"{'✅ 相同' if same_id else '❌ 不同'}")
    if not same_id:
        print(f"      仅甲有 {sorted(set(ra)-set(rb))}   仅乙有 {sorted(set(rb)-set(ra))}")
    ok &= same_id
    same_ord = ma["order"] == mb["order"]
    print(f"  单元顺序       {'✅ 一致' if same_ord else '⚠️ 不一致（不阻断，但须记）'}")
    same_col = ma["ncol"] == mb["ncol"]
    print(f"  栏数           甲 {ma['ncol']} ／ 乙 {mb['ncol']}   "
          f"{'✅' if same_col else '❌'}")
    ok &= same_col
    same_hdr = ma["header"] == mb["header"]
    print(f"  表头           {'✅ 相同' if same_hdr else '⚠️ 不同 → 语义等价性【须人工裁】，本器不判'}")
    if not same_hdr:
        print(f"      甲 {ma['header']}")
        print(f"      乙 {mb['header']}")
    print(f"\n  M1-A → {'🟢 PASS' if ok else '🔴 BLOCKED'}")
    return ok


# ==============================================================================
# M1-B · 语义载荷完整性（栏内共现，非单字计数）
# ==============================================================================
def M1B(rb, tname):
    print("-" * 72)
    print(f"M1-B · 语义载荷完整性 —— {tname}")
    print("      判据：限定语义须与其所限定之对象【同栏共现】；散落他处不算")
    print("-" * 72)
    lost, checked = [], 0
    for uid, items in PRE_REG["payload"].items():
        if uid not in rb:
            for q, o, why in items:
                lost.append((uid, q, o, "单元不存在"))
            continue
        cols = rb[uid]
        for q, o, why in items:
            checked += 1
            hit = any((q in c) and (o in c) for c in cols)
            loose = any(q in c for c in cols)          # 只出现、未共现
            if hit:
                print(f"  🟢 {uid}  「{q}」× 「{o}」同栏共现")
            else:
                state = "散落他栏，未与对象共现" if loose else "完全缺失"
                print(f"  🔴 {uid}  「{q}」× 「{o}」{state}")
                print(f"        载荷作用：{why}")
                lost.append((uid, q, o, state))
    print(f"\n  载荷 {checked} 项   存活 {checked-len(lost)}   遗失 {len(lost)}")
    ok = not lost
    print(f"  M1-B → {'🟢 PASS' if ok else '🔴 BLOCKED —— 且【禁止将来源改为 xref】'}")
    return ok, lost


# ==============================================================================
# M1-C · 引用完整性（封堵 SC-049）
# ==============================================================================
def M1C(target_text, sources, section_kw):
    print("-" * 72)
    print("M1-C · 引用完整性（内容移至 xref 者）")
    print("-" * 72)
    xlines = [l for l in target_text.split('\n') if '↗' in l and section_kw in l]
    if not xlines:
        print("  本卷未以 xref 承载该单元 —— 不适用")
        return True
    ok = True
    for l in xlines:
        found = False
        for sn, st in sources.items():
            if sn not in l:
                continue
            m = re.search(r'§[^\s`｜]+', l.split('↗', 1)[1])
            if not m or m.group(0) not in st:
                print(f"  🔴 悬空：{l.strip()[:70]}")
                ok = False; found = True; break
            # ★ SC-049 封堵：目标节内须【确有实体内容】，非仅标题
            rr, _ = extract_unit_table(st, section_kw)
            if not rr:
                print(f"  🔴 目标节存在但【无实体表格】：{sn} {m.group(0)}")
                ok = False
            else:
                print(f"  🟢 有效：↗ {sn} {m.group(0)}   实体 {len(rr)} 单元")
            found = True; break
        if not found:
            print(f"  🔴 来源档不存在：{l.strip()[:70]}"); ok = False
    print(f"\n  M1-C → {'🟢 PASS' if ok else '🔴 悬空项不计覆盖'}")
    return ok


# ==============================================================================
# 负控制 —— 五项，皆须 FAIL 方证本器有效
# ==============================================================================
def controls():
    print("=" * 72); print("负控制（五项皆须【检出】方算通过）"); print("=" * 72)
    base = """### 回溯影响矩阵（十条验证器缺陷 · 待填）

| SC | 缺陷 | 曾支撑之结论 | 已重算 | 重算读数 | 等级 |
|---|---|---|:---:|---|---|
| `SC-016` | 以字符串精确匹配比对**浮点列** | 边界比对「24 列逐行一致」 | ⬜ | | |
| `SC-017` | `formatC` canonical key 失效 | 全局检索 `NOT_FOUND 56,612` | ⬜ | | |
| `SC-018` | 24 列 double 精确 join 不适用容差型数据 | 边界比对「最大相对误差 `5.061e-15`」 | ⬜ | | |
| `SC-026` | `try/catch` 不捕原生非零退出码 | EVTX 八档**导出成功**判定 | ⬜ | | |
| `SC-027` | evtx 解析器越过分块档头声明区间 | RecordId **零重号**判定 | ⬜ | | |
| `SC-030` | 批次完整性误用 `rows` 频数 | `182 相异 OFFSET` | ⬜ | | |
"""
    cases = [
        ("NC-M1-01 删「24 列」",      base.replace("24 列 double", "double")),
        ("NC-M1-02 删「非零」",        base.replace("原生非零退出码", "原生退出码")),
        ("NC-M1-03 删「声明区间」",    base.replace("分块档头声明区间", "分块档头")),
        ("NC-M1-04 删「边界比对」",    base.replace("边界比对「最大相对误差", "「最大相对误差")),
        ("NC-M1-05 只留标题与 xref",
         "### 回溯影响矩阵（十条验证器缺陷 · 待填）\n\n"
         "- **回溯影响矩阵** ↗ `甲.md` §八、有限影响回溯　（24 列 非零 声明区间 边界比对）\n"),
    ]
    ok_all = True
    # 先证正控制：完整版须 PASS
    rb, _ = extract_unit_table(base, "回溯影响矩阵")
    p0, l0 = M1B_quiet(rb)
    print(f"  PC-M1-00 完整版      期望 0 遗失   实得 {len(l0)}   "
          f"{'PASS' if p0 else 'FAIL'}")
    ok_all &= p0
    for name, txt in cases:
        rb, _ = extract_unit_table(txt, "回溯影响矩阵")
        if rb is None or not rb:
            det = True   # 表都没了，必然检出
            n = "N/A（无表格）"
        else:
            p, l = M1B_quiet(rb)
            det = not p
            n = len(l)
        print(f"  {name:<26} 期望 检出     实得 遗失 {n}   "
              f"{'PASS' if det else '🔴 FAIL —— 本器无效'}")
        ok_all &= det
    print(f"\n{'✅ 控制全过 —— 本器具备执行资格' if ok_all else '⛔ 控制未过 —— 本器无资格'}\n")
    return ok_all


def M1B_quiet(rb):
    lost = []
    for uid, items in PRE_REG["payload"].items():
        if uid not in rb:
            lost += [(uid, q, o) for q, o, _ in items]; continue
        for q, o, _ in items:
            if not any((q in c) and (o in c) for c in rb[uid]):
                lost.append((uid, q, o))
    return (not lost), lost


# ==============================================================================
def main(fa, fb, kw="回溯影响矩阵"):
    print("=" * 72)
    print(f" V-QMS-M1-006  v1.3.1   三层内容保全检验")
    print("=" * 72 + "\n")
    if not controls():
        return 1
    ta, tb = read(fa), read(fb)
    ra, ma = extract_unit_table(ta, kw)
    rb, mb = extract_unit_table(tb, kw)
    print("=" * 72)
    print(f"甲 SOURCE：{os.path.basename(fa)}   单元 {ma['nrow']} 栏 {ma['ncol']}")
    print(f"乙 TARGET：{os.path.basename(fb)}   单元 {mb['nrow']} 栏 {mb['ncol']}")
    print("=" * 72 + "\n")
    a = M1A(ra, ma, rb, mb); print()
    b, lost = M1B(rb, os.path.basename(fb)); print()
    c = M1C(tb, {os.path.basename(fa): ta}, kw)
    print("\n" + "=" * 72)
    print("总判（三层分列，禁以总分掩盖 —— SC-047）")
    print("=" * 72)
    print(f"  M1-A 结构  {'🟢 PASS' if a else '🔴 BLOCKED'}")
    print(f"  M1-B 语义  {'🟢 PASS' if b else '🔴 BLOCKED'}")
    print(f"  M1-C 引用  {'🟢 PASS' if c else '🔴 悬空'}")
    print(f"\n  甲 ⊆ 乙 ？ {'✅ 成立 —— 可执行 xref' if (a and b) else '❌ 不成立 —— 禁止 xref，禁止删除'}")
    if lost:
        print(f"\n  乙须回填之语义载荷（{len(lost)} 项）：")
        for uid, q, o, st in lost:
            print(f"    · {uid}  「{q}」须与「{o}」同栏  （现况：{st}）")
    return 0 if (a and b and c) else 3


if __name__ == "__main__":
    if len(sys.argv) >= 3:
        fa, fb = sys.argv[1], sys.argv[2]
        kw = sys.argv[3] if len(sys.argv) > 3 else "回溯影响矩阵"
    else:
        fa, fb = resolve_pair()
        kw = "回溯影响矩阵"
        if fa is None:
            sys.exit(1)
    sys.exit(main(fa, fb, kw))
