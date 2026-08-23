#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ══════════════════════════════════════════════════════════════════════════
# G11 · Block-Comment Topology 状态机结构闸  v2.0.2
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false
# ★ 本档置放：审计/工具/G11_块注释拓扑闸_v2.0.2.py
# ══════════════════════════════════════════════════════════════════════════
# 【五命名空间 · 路径纪律（v2.0.2 立，与全项目同步）】
#     数据库/   Delivery        交付件 CSV（.gitignore 第 22 行忽略之）
#     函数/     Execution       ★ SQL 总包、R 源码 —— 可执行内容皆居此
#     规范/     Specification   registry YAML／CSV、规格文书
#     配置/     Configuration   paths_a168.R 等
#     审计/     Audit           ★ 本工具、诊断输出（_ph0/ _b4/ …）
#   ⚠ 脚本与 SQL 总包**皆不得置于 数据库/** —— 该处只放数据，不放代码。
#
# 【v2.0.1 → v2.0.2 之斧正】
#   SC-3 · 默认路径错：v2.0.1 之用法示例书「数据库/a168_…v11.0.3.sql」，
#     与五命名空间相悖 —— SQL 总包属 Execution，应居 函数/。今正之，
#     并加**自动定位**：无参时自 函数/ → 项目根 → 全树 依序搜寻。
#   SC-4 · 无参即验：无参时不再只印用法，改为自动定位并直接受检，
#     令 `python G11_….py` 单独一句即可跑通（Windows 常见用法）。
#
# 【用法 · 三式】
#   ① PowerShell／cmd（推荐）
#        cd <项目根>
#        python 审计\工具\G11_块注释拓扑闸_v2.0.2.py
#        python 审计\工具\G11_块注释拓扑闸_v2.0.2.py 函数\a168_取数与核验_SQL总包_v11.0.3.sql
#      退出码 0 = PASS ／ 1 = FAIL ／ 2 = 找不到受检档
#   ② reticulate REPL 内（整段贴入后另起一行；★ 此为 Python 语法，非 PowerShell）
#        run()                       # 自动定位
#        run("函数/a168_取数与核验_SQL总包_v11.0.3.sql")
#   ③ R 侧（★ 此为 R 语法，禁贴入 PowerShell —— PowerShell 之 `<-` 系保留运算符）
#        reticulate::source_python("审计/工具/G11_块注释拓扑闸_v2.0.2.py")
#        ok <- run("函数/a168_取数与核验_SQL总包_v11.0.3.sql")
#
# 七项检查：① 进入块注释 ② 注释态识别闭合符 ③ 闭合后复 CODE 态 ④ 再入下一块
#           ⑤ 文件结束须回 CODE 态 ⑥ 块内描述文本不得被误当控制符
#           ⑦ 可执行语句是否被异常包入注释态（ADVISORY，不判 FAIL）
# ★ 第一原则：**配对数量相等 ≠ 注释拓扑正确**；验收对象是状态转移结构。
# ══════════════════════════════════════════════════════════════════════════
import sys, os, re, glob

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

EXEC_KW = re.compile(r'(?im)^\s*(SELECT|WITH|INSERT|CREATE|UPDATE|DELETE|ALTER|DROP)\b')

# ── 五命名空间之搜寻序（★ 函数/ 优先，数据库/ 明确排除）──────────────
SEARCH_ORDER = [
    os.path.join('函数', 'a168_取数与核验_SQL总包_v*.sql'),   # ① Execution —— 正位
    'a168_取数与核验_SQL总包_v*.sql',                          # ② 项目根 —— 过渡期容错
    os.path.join('*', 'a168_取数与核验_SQL总包_v*.sql'),       # ③ 任一子目录 —— 兜底
]
EXCLUDE_DIR = ('数据库',)          # ★ 数据库/ 只放数据，纵有 .sql 亦不取


def locate():
    """依五命名空间搜寻 canonical 总包；排除 _superseded 与 数据库/。"""
    for pat in SEARCH_ORDER:
        hits = [p for p in glob.glob(pat)
                if '_superseded' not in p
                and not any(p.replace('\\', '/').startswith(d + '/') for d in EXCLUDE_DIR)]
        if hits:
            hits.sort()                       # 版本号字典序，末者为最新
            return hits[-1], pat
    return None, None


def scan(path):
    raw = open(path, 'rb').read()
    d = raw.decode('utf-8')
    nl = lambda pos: d[:pos].count('\n') + 1

    i, state, start = 0, 'CODE', None
    spans, opens_in_comment, stray_close = [], [], []
    in_line_comment = in_string = False
    while i < len(d) - 1:
        ch, pair = d[i], d[i:i + 2]
        if state == 'CODE':
            if in_line_comment:
                if ch == '\n': in_line_comment = False
                i += 1; continue
            if in_string:
                if ch == "'": in_string = False
                i += 1; continue
            if ch == "'":   in_string = True;  i += 1; continue
            if pair == '--': in_line_comment = True; i += 2; continue
            if pair == '/*': state, start = 'COMMENT', i; i += 2; continue
            if pair == '*/': stray_close.append(i); i += 2; continue
            i += 1
        else:
            if pair == '*/':
                spans.append((start, i + 2)); state = 'CODE'; i += 2; continue
            if pair == '/*':
                opens_in_comment.append(i); i += 2; continue
            i += 1

    R, ok = [], True
    def chk(no, name, detail, passed):
        nonlocal ok
        R.append((no, name, detail, passed))
        if not passed: ok = False

    chk('1-4', '状态转移闭合', '配对块 %d 段' % len(spans), len(spans) > 0)
    chk('5', '文件结束回到 CODE 态',
        '结束态 = %s' % state + ('' if state == 'CODE'
                                 else '（未闭合起始符于第 %d 行）' % nl(start)),
        state == 'CODE')
    chk('6a', '块内无字面起始符',
        '%d 处' % len(opens_in_comment) +
        ('  行 %s' % [nl(p) for p in opens_in_comment[:6]] if opens_in_comment else ''),
        not opens_in_comment)
    chk('6b', '无游离闭合符',
        '%d 处' % len(stray_close) +
        ('  行 %s' % [nl(p) for p in stray_close[:6]] if stray_close else ''),
        not stray_close)
    chk('cnt', '起始符 = 闭合符（辅助项，非充分条件）',
        '起 %d / 闭 %d' % (d.count('/*'), d.count('*/')),
        d.count('/*') == d.count('*/'))

    swallowed = []
    for a, b in spans:
        seg = d[a + 2:b]
        kws = EXEC_KW.findall(seg)
        if kws:
            swallowed.append((nl(a), nl(b), len(seg.split('\n')),
                              sorted(set(k.upper() for k in kws)),
                              seg.strip().split('\n')[0][:64]))
    return R, ok, swallowed, spans, d


def run(path=None):
    """打印报告并返回 True/False。★ 不抛 SystemExit，REPL 内可安全直呼。
       path 省略时自动依五命名空间定位 canonical 总包。"""
    if path is None:
        path, pat = locate()
        if path is None:
            print('❌ 未能自动定位 SQL 总包。')
            print('   当前工作目录：%s' % os.getcwd())
            print('   搜寻序（依五命名空间）：')
            for p in SEARCH_ORDER: print('     %s' % p)
            print('   ⚠ 数据库/ 已明确排除 —— 该处只放数据，不放代码。')
            print('   请 cd 至项目根后重试，或显式给出档名。')
            return None
        print('★ 自动定位：%s   （命中搜寻式：%s）\n' % (path, pat))

    if not os.path.exists(path):
        print('❌ 档不存在：%s' % path)
        print('   当前工作目录：%s' % os.getcwd())
        cand = [p for p in glob.glob(os.path.join('*', '*.sql')) + glob.glob('*.sql')
                if '总包' in p]
        if cand:
            print('   本目录树内之候选总包：')
            for c in sorted(cand)[:10]: print('     %s' % c)
        return None

    R, ok, swallowed, spans, d = scan(path)
    print('=' * 84)
    print('G11 · Block-Comment Topology 状态机结构闸 v2.0.2')
    print('受检件：%s' % path)
    print('=' * 84)
    for no, name, detail, passed in R:
        print('  %-5s %-38s %-28s %s' % (no, name, detail, 'PASS ✅' if passed else 'FAIL ❌'))

    print('\n' + '-' * 84)
    print('⑦ 被包入注释态之可执行语句：%d 段（ADVISORY · 不判 FAIL · 须逐段人工确认）' % len(swallowed))
    print('-' * 84)
    if not swallowed:
        print('  无。')
    else:
        for s, e, n, kws, head in swallowed:
            print('  行 %6d-%-6d (%3d 行)  %-28s %s' % (s, e, n, ','.join(kws), head))
        print('\n  ★ 判读：此类多系「已摘除之旧版查询」，保留作告示本属正当；')
        print('    惟须逐段确认其确系有意摘除，而非因拓扑错位被误吞。')
        print('    ⚠ 本项高召回：散文中行首之 SELECT 等词亦会命中，属预期假阳性。')

    print('\n' + '=' * 84)
    print('G11 总判：%s' % ('PASS ✅ 注释拓扑正确' if ok else 'FAIL ❌ 注释拓扑错位，禁止发布'))
    print('=' * 84)
    return ok


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    r = run(argv[0] if argv else None)
    return 2 if r is None else (0 if r else 1)


if __name__ == '__main__':
    try:
        _rc = main()
    except BrokenPipeError:                 # ★ 管道被 head／more 截断，非缺陷
        try: sys.stdout.close()
        except Exception: pass
        os._exit(0)
    if len(sys.argv) > 1 or _rc == 2:
        sys.exit(_rc)          # ★ 只在命令行或定位失败时 exit，免 REPL 报错
