#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ══════════════════════════════════════════════════════════════════════════
# R4-SEMANTIC-03 · 业务锚点吸收审计  v1.0.0
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false
# ★ 置放：审计/工具/R4S03_业务锚点吸收审计_v1.0.0.py
# ══════════════════════════════════════════════════════════════════════════
# 立件缘由（承 REDTEAM 裁示 · 三层递进）：
#   第一层  名称检索   —— 搜段号字符串 → **已证不可用**
#           实例：canonical 内「§R01-chk 34 处」曾被我误判为「已吸收」。
#           名称出现只证有同名章节，不证内容进来了。此系 R4-SEMANTIC-02 之复发。
#   第二层  语句指纹   —— 规范化后 MD5 逐条比对 → **只能作候选定位**
#           实例：chk2_chk3 得 0/2 精确命中，惟一条完整查询若被拆入多个 CTE，
#           一对一指纹**天然无法证明吸收**。
#   第三层  业务锚点   —— 本件所行者
#           把「一条 SQL」拆成**不可稀释之业务锚点**，逐锚检索 canonical。
#
# ★ 为何 Jaccard 不足（本件之核心斧正 · 我方缺陷）：
#   我上轮书「J ≥ 0.85 → 极可能改写吸收；J ≤ 0.40 → 极可能未吸收」，
#   **把启发式写成了判据形式**。反例二则，皆足以推翻：
#     ① 语义同而词汇异：
#          WHERE bet41 <> validbet
#        与  SUM(CASE WHEN bet41 <> validbet THEN 1 ELSE 0 END)
#        业务意义一致，token Jaccard 却可能甚低。
#     ② 词汇同而语义异：
#        bet13／bet14／bet16／bet41／validbet 五字段俱现，
#        不代表真的实现了 bet41 ≡ validbet 之恒等检验。
#   → **Jaccard 只作候选排序器，不作验收规则。** 本件不用它下任何裁定。
#
# 【七类锚点】
#   TABLE      取数来源表
#   COLUMN     所涉字段（bet01~bet41／validbet／age022 之属）
#   PREDICATE  过滤谓词（bet02='101'／category='1'／bet38='N'／窗口两端）
#   WINDOW     窗口函数之完整签名（partition + order 三级排序）
#   JOIN       连接形态与连接键
#   GATE       闸／排除逻辑（test_agents／五级代理位）
#   FORMULA    计算式（比率、恒等式、差额）
#
# 【判词四态 · 逐锚而非逐档】
#   ABSORBED_EXACT     锚在 canonical 内原样可见
#   ABSORBED_REWRITTEN 锚之语义可见，形式已改（须人工复核，本件只标不判）
#   SUPERSEDED         canonical 有更强之替代实现（须人工指认）
#   NOT_ABSORBED       canonical 内遍寻不见
#   ★ 本件只机械产出前二与第四；SUPERSEDED **必由人裁**，工具不得代断。
#
# 用法：
#   python 审计\工具\R4S03_业务锚点吸收审计_v1.0.0.py
#   python 审计\工具\R4S03_业务锚点吸收审计_v1.0.0.py <canonical.sql> <patch1.sql> ...
# ══════════════════════════════════════════════════════════════════════════
import sys, os, re, glob

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

DEFAULT_CANON = os.path.join('函数', 'a168_取数与核验_SQL总包_v11.0.3.sql')
DEFAULT_PATCH = [
    os.path.join('函数', 'a168_SQL总包_v10_斧正补丁_R01_P11c.sql'),
    os.path.join('函数', 'a168_SQL总包_v10_斧正补丁_增补_chk2_chk3.sql'),
    os.path.join('函数', 'a168_SQL总包_v10_斧正补丁_增补_chk2_chk3_v2.sql'),
]


def norm(path):
    """剥块注释 → 剥行注释 → 压空白 → 小写。返回全文一串。"""
    txt = open(path, 'rb').read().decode('utf-8')
    txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
    code = '\n'.join(l.split('--', 1)[0] for l in txt.split('\n'))
    return re.sub(r'\s+', ' ', code).strip().lower()


def stmts(path):
    body = norm(path)
    return [s.strip() for s in body.split(';') if s.strip()]


def anchors(s):
    """自一条规范化语句抽七类锚点。"""
    A = []
    for t in sorted(set(re.findall(r'ods_mariadb_2b\.(\w+)', s))):
        A.append(('TABLE', t, t))
    for c in sorted(set(re.findall(r'\b(bet\d{2}|validbet|age\d{3}|category|commission|updatetime|sync_time)\b', s))):
        A.append(('COLUMN', c, r'\b' + c + r'\b'))
    for p in sorted(set(re.findall(r"(\w+\s*=\s*'[^']{1,20}')", s))):
        A.append(('PREDICATE', p, re.escape(re.sub(r'\s+', '', p))))
    for w in set(re.findall(r'row_number\(\)\s*over\s*\(\s*partition by ([\w.]+)\s*order by ([^)]{5,140})\)', s)):
        sig = 'row_number partition=%s order=%s' % (w[0], re.sub(r'\s+', ' ', w[1]).strip())
        key = r'row_number\(\)\s*over\s*\(\s*partition by\s*' + re.escape(w[0])
        A.append(('WINDOW', sig, key))
    for j in sorted(set(re.findall(r'(left join|inner join|join)\s+(\w+)\s+\w+\s+on\s+([\w.]+)\s*=\s*([\w.]+)', s))):
        A.append(('JOIN', '%s %s on %s=%s' % j, r'%s\s+%s\s' % (j[0], j[1])))
    for g in sorted(set(re.findall(r"(age022\s*=\s*'1'|test_agents|coalesce\([^)]*agent_id[^)]*\)|not exists)", s))):
        A.append(('GATE', g, re.escape(re.sub(r'\s+', '', g))))
    for f in sorted(set(re.findall(r'(\w+\s*<>\s*\w+|\w+\s*/\s*nullif\([^)]{3,50}\)|sum\(case when [^)]{5,90}\))', s))):
        A.append(('FORMULA', f[:70], re.escape(re.sub(r'\s+', '', f))[:200]))
    seen, out = set(), []
    for kind, disp, key in A:
        if (kind, disp) in seen: continue
        seen.add((kind, disp)); out.append((kind, disp, key))
    return out


def probe(canon_body, canon_nospace, kind, key):
    """锚是否见于 canonical。两式并检：原样式 ＋ 去空白式（抗排版差异）。"""
    try:
        if re.search(key, canon_body):
            return 'ABSORBED_EXACT'
        if re.search(key, canon_nospace):
            return 'ABSORBED_REWRITTEN'
    except re.error:
        k = re.escape(key)
        if re.search(k, canon_body): return 'ABSORBED_EXACT'
    return 'NOT_ABSORBED'


def main():
    argv = sys.argv[1:]
    canon = argv[0] if argv else DEFAULT_CANON
    patches = argv[1:] if len(argv) > 1 else DEFAULT_PATCH

    if not os.path.exists(canon):
        print('❌ canonical 不存在：%s' % canon)
        print('   当前工作目录：%s' % os.getcwd())
        return 2

    cb = norm(canon)
    cn = re.sub(r'\s+', '', cb)
    print('=' * 100)
    print('R4-SEMANTIC-03 · 业务锚点吸收审计 v1.0.0')
    print('canonical：%s   （规范化 %s 字符 ／ %d 条语句）' % (canon, format(len(cb), ','), len(stmts(canon))))
    print('=' * 100)
    print('★ 判词四态：ABSORBED_EXACT ／ ABSORBED_REWRITTEN ／ NOT_ABSORBED ／ SUPERSEDED（必由人裁）')
    print('★ 本件不使用 Jaccard —— 相似度只作排序器，不作验收规则。')

    grand = {}
    for p in patches:
        if not os.path.exists(p):
            print('\n❌ 补丁不存在：%s' % p); continue
        print('\n' + '=' * 100)
        print('[%s]' % os.path.basename(p))
        print('=' * 100)
        for i, s in enumerate(stmts(p), 1):
            A = anchors(s)
            res = [(k, d, probe(cb, cn, k, key)) for k, d, key in A]
            miss = [r for r in res if r[2] == 'NOT_ABSORBED']
            rew  = [r for r in res if r[2] == 'ABSORBED_REWRITTEN']
            rate = (len(res) - len(miss)) / len(res) if res else 0
            print('\n  ── 语句 #%d ── 锚点 %d ｜ 命中 %d ｜ 改写命中 %d ｜ 未命中 %d ｜ 锚覆盖率 %.1f%%'
                  % (i, len(res), len(res) - len(miss) - len(rew), len(rew), len(miss), rate * 100))
            by = {}
            for k, d, v in res: by.setdefault(k, []).append((d, v))
            for k in ('TABLE', 'COLUMN', 'PREDICATE', 'WINDOW', 'JOIN', 'GATE', 'FORMULA'):
                if k not in by: continue
                ok = sum(1 for _, v in by[k] if v != 'NOT_ABSORBED')
                print('      %-10s %2d/%2d' % (k, ok, len(by[k])))
                for d, v in by[k]:
                    if v == 'NOT_ABSORBED':
                        print('          ❌ %s' % d[:88])
            grand.setdefault(os.path.basename(p), []).append((i, len(res), len(miss)))

    print('\n' + '=' * 100)
    print('汇总（★ 本表只列机械读数，不下 ARCHIVE 裁定）')
    print('=' * 100)
    print('  %-52s %-6s %-8s %-8s %s' % ('补丁 · 语句', '锚点', '未命中', '锚覆盖率', '待人裁'))
    for f, rows in grand.items():
        for i, n, m in rows:
            r = (n - m) / n if n else 0
            need = 'SUPERSEDED?' if m else '—'
            print('  %-52s %-6d %-8d %-8.1f%% %s' % ('%s #%d' % (f[:44], i), n, m, r * 100, need))

    print('\n判读三锁：')
    print('  锁一 · 锚覆盖率 100% ≠ 吸收完成。')
    print('         七类锚俱在，仍可能只是「字段都用到了」，未必实现了同一业务命题。')
    print('         例：bet41 与 validbet 两列俱现，不等于做了 bet41 ≡ validbet 之恒等检验。')
    print('  锁二 · 任一 NOT_ABSORBED 锚，即足以阻断该档之 ARCHIVE READY。')
    print('         归档之前提是「能力已在别处」，一个锚找不到就还没证到这一步。')
    print('  锁三 · SUPERSEDED 必由人裁，工具不得代断。')
    print('         「canonical 有更强之替代实现」是价值判断，非字符串可决。')
    return 0


if __name__ == '__main__':
    _rc = main()
    if len(sys.argv) > 1 or _rc == 2:
        sys.exit(_rc)
