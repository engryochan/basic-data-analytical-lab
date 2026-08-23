#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ══════════════════════════════════════════════════════════════════════════
# G11 · Block-Comment Topology 状态机结构闸  v2.0.1
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
# ══════════════════════════════════════════════════════════════════════════
# 【v2.0.0 → v2.0.1 之斧正】
#   SC-1 · REPL 不可用：v2.0.0 于末尾直呼 main()，且以 sys.exit() 收束。
#     于 reticulate::repl_python() 或任何交互式 REPL 内**整段贴入**时：
#       ① sys.argv 无档名 → 打印用法后 sys.exit(2)
#       ② REPL 中 sys.exit 抛 SystemExit → 现 Traceback，形同报错
#     此非 bug 而系设计与用法错配，惟工具须容错，故改：
#       · 拆出 run(path) 纯函数，可于 REPL 直呼，**不抛 SystemExit**
#       · main() 只在 __main__ 且确有 argv 时才走命令行分支
#       · 无 argv 时不再 exit，改为友善提示并列出可行用法
#   SC-2 · Windows 编码：加 -*- coding -*- 与 stdout 重配置，
#     免 PowerShell 之 cp950／cp936 吞掉 ✅❌★ 等字符。
#
# 【三种用法】
#   ① 命令行（推荐 · 可挂 CI）
#        python G11_块注释拓扑闸_v2.0.1.py 数据库/a168_取数与核验_SQL总包_v11.0.3.sql
#        退出码 0 = PASS ／ 1 = FAIL ／ 2 = 用法错
#   ② R 之 reticulate REPL 内
#        整段贴入后，另起一行呼：  run("数据库/a168_取数与核验_SQL总包_v11.0.3.sql")
#        返回 True/False，**不抛 SystemExit**
#   ③ R 侧直呼
#        reticulate::source_python("审计/工具/G11_块注释拓扑闸_v2.0.1.py")
#        ok <- run("数据库/a168_取数与核验_SQL总包_v11.0.3.sql")
#
# 七项检查：① 进入块注释 ② 注释态识别闭合符 ③ 闭合后复 CODE 态 ④ 再入下一块
#           ⑤ 文件结束须回 CODE 态 ⑥ 块内描述文本不得被误当控制符
#           ⑦ 可执行语句是否被异常包入注释态（ADVISORY，不判 FAIL）
# ★ 第一原则：**配对数量相等 ≠ 注释拓扑正确**；验收对象是状态转移结构。
# ══════════════════════════════════════════════════════════════════════════
import sys, os, re

try:                                    # Windows PowerShell 之 cp936 会吞 emoji
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

EXEC_KW = re.compile(r'(?im)^\s*(SELECT|WITH|INSERT|CREATE|UPDATE|DELETE|ALTER|DROP)\b')


def scan(path):
    """纯扫描，不打印、不退出。返回 (检查列表, 是否 PASS, ⑦清单, 配对区间, 全文)。"""
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


def run(path):
    """打印报告并返回 True/False。★ 不抛 SystemExit，REPL 内可安全直呼。"""
    if not os.path.exists(path):
        print('❌ 档不存在：%s' % path)
        print('   当前工作目录：%s' % os.getcwd())
        cand = []
        for root, _, fs in os.walk('.'):
            for f in fs:
                if f.endswith('.sql') and '总包' in f:
                    cand.append(os.path.join(root, f))
        if cand:
            print('   本目录树内之候选总包：')
            for c in cand[:10]: print('     %s' % c)
        else:
            print('   本目录树内未见任何「*总包*.sql」——请先确认工作目录。')
        return False

    R, ok, swallowed, spans, d = scan(path)
    print('=' * 84)
    print('G11 · Block-Comment Topology 状态机结构闸 v2.0.1')
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
    if not argv:
        print('G11 · 块注释拓扑闸 v2.0.1 —— 未指定受检档。')
        print('')
        print('  命令行用法：')
        print('    python G11_块注释拓扑闸_v2.0.1.py <file.sql>')
        print('')
        print('  REPL／reticulate 内用法（不抛 SystemExit）：')
        print('    run("数据库/a168_取数与核验_SQL总包_v11.0.3.sql")')
        print('')
        print('  当前工作目录：%s' % os.getcwd())
        return 2
    return 0 if run(argv[0]) else 1


if __name__ == '__main__' and len(sys.argv) > 1:
    sys.exit(main())                    # ★ 只在确有 argv 时才 exit，免 REPL 报错
elif __name__ == '__main__':
    main()                              # ★ 无 argv 只提示，不 exit
