#!/usr/bin/env python3
# ══════════════════════════════════════════════════════════════════════════
# G11 · Block-Comment Topology 状态机结构闸  v2.0.0
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
# ══════════════════════════════════════════════════════════════════════════
# 立闸缘由（v11.0.3 实证）：
#   全档块注释起始符 224 处、闭合符 223 处，而「剥配对后余 0」——
#   计数相抵，结构却已错位：一个起始符无自身闭合符，系被下一段横幅之闭合符
#   顺手关掉。若日后删改该横幅，其后整条 SELECT 将被静默吞掉，查询不报错。
#   ★ 故立本闸之第一原则：**配对数量相等 ≠ 注释拓扑正确**。
#     验收对象是**状态转移结构**，非符号计数。
#
# 七项检查（承 REDTEAM 裁示）：
#   ① 进入块注释      ② 注释态下识别闭合符    ③ 闭合后恢复 CODE 态
#   ④ 重新进入下一块  ⑤ 文件结束须回到 CODE 态
#   ⑥ 块内描述性文本不得被误当作真正之控制符
#   ⑦ SELECT／WITH／INSERT／CREATE 等可执行语句是否被异常包入注释态
#
# 用法：python3 G11_块注释拓扑闸_v2.0.0.py <file.sql>
# 退出码：0 = PASS ／ 1 = FAIL（可挂 CI）
# ══════════════════════════════════════════════════════════════════════════
import sys, re

EXEC_KW = re.compile(r'(?im)^\s*(SELECT|WITH|INSERT|CREATE|UPDATE|DELETE|ALTER|DROP)\b')

def scan(path):
    raw = open(path, 'rb').read()
    d = raw.decode('utf-8')
    nl = lambda pos: d[:pos].count('\n') + 1

    # ── 状态机：CODE ⇄ COMMENT（SQL 块注释不嵌套）──────────────────────
    i, state, start = 0, 'CODE', None
    spans, opens_in_comment, stray_close = [], [], []
    in_line_comment = False
    in_string = False
    while i < len(d) - 1:
        ch, pair = d[i], d[i:i+2]
        if state == 'CODE':
            if in_line_comment:
                if ch == '\n': in_line_comment = False
                i += 1; continue
            if in_string:
                if ch == "'": in_string = False
                i += 1; continue
            if ch == "'": in_string = True; i += 1; continue
            if pair == '--': in_line_comment = True; i += 2; continue
            if pair == '/*': state, start = 'COMMENT', i; i += 2; continue
            if pair == '*/': stray_close.append(i); i += 2; continue      # ⑥ 游离闭合符
            i += 1
        else:                                    # COMMENT 态
            if pair == '*/':
                spans.append((start, i + 2)); state = 'CODE'; i += 2; continue
            if pair == '/*':
                opens_in_comment.append(i); i += 2; continue              # ⑥ 块内起始符
            i += 1

    R, ok = [], True
    def chk(no, name, detail, passed):
        nonlocal ok
        R.append((no, name, detail, passed))
        if not passed: ok = False

    chk('①②③④', '状态转移闭合', f'配对块 {len(spans)} 段', len(spans) > 0)
    chk('⑤', '文件结束回到 CODE 态',
        f'结束态 = {state}' + ('' if state == 'CODE' else f'（未闭合起始符于第 {nl(start)} 行）'),
        state == 'CODE')
    chk('⑥a', '块内无字面起始符',
        f'{len(opens_in_comment)} 处' + (f' → 行 {[nl(p) for p in opens_in_comment[:6]]}' if opens_in_comment else ''),
        not opens_in_comment)
    chk('⑥b', '无游离闭合符',
        f'{len(stray_close)} 处' + (f' → 行 {[nl(p) for p in stray_close[:6]]}' if stray_close else ''),
        not stray_close)
    chk('计数', '起始符 ≡ 闭合符（**辅助项，非充分条件**）',
        f"起 {d.count('/*')} ／ 闭 {d.count('*/')}", d.count('/*') == d.count('*/'))

    # ⑦ 被包入注释态之可执行语句 —— 不判 FAIL，逐段列出供人工确认
    swallowed = []
    for a, b in spans:
        seg = d[a+2:b]
        kws = EXEC_KW.findall(seg)
        if kws:
            swallowed.append((nl(a), nl(b), len(seg.split('\n')), sorted(set(k.upper() for k in kws)),
                              seg.strip().split('\n')[0][:64]))
    return R, ok, swallowed, spans, d

def main():
    if len(sys.argv) < 2:
        print('用法：python3 G11_块注释拓扑闸_v2.0.0.py <file.sql>'); sys.exit(2)
    path = sys.argv[1]
    R, ok, swallowed, spans, d = scan(path)

    print('═' * 84)
    print(f'G11 · Block-Comment Topology 状态机结构闸 v2.0.0')
    print(f'受检件：{path}')
    print('═' * 84)
    for no, name, detail, passed in R:
        print(f'  {no:<6} {name:<38} {detail:<28} {"✅PASS" if passed else "❌FAIL"}')

    print('\n' + '─' * 84)
    print(f'⑦ 被包入注释态之可执行语句：{len(swallowed)} 段（**不判 FAIL，须逐段人工确认摘除系出于本意**）')
    print('─' * 84)
    if not swallowed:
        print('  无。')
    else:
        for s, e, n, kws, head in swallowed:
            print(f'  行 {s:>6}–{e:<6} ({n:>3} 行)  {",".join(kws):<28} {head}')
        print('\n  ★ 判读：此类段落多系「已摘除之旧版查询」，保留作告示本属正当；')
        print('    惟须逐段确认其**确系有意摘除**，而非因注释拓扑错位被误吞。')
        print('    凡无「已摘除／告示／保留备查」等明示者，即为可疑，须开工单。')

    print('\n' + '═' * 84)
    print(f'G11 总判：{"✅ PASS —— 注释拓扑正确" if ok else "❌ FAIL —— 注释拓扑错位，禁止发布"}')
    print('═' * 84)
    sys.exit(0 if ok else 1)

if __name__ == '__main__':
    main()
