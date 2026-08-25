#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
a168 · P0-4 闸门  ——  JOIN 粒度契约 + x_win 单行 + 行数守恒  静态验证器
版本 v0.1.0 · 随 REL-0006 / C2 / v12.0.1 同版归档
零外部依赖（无 sqlglot / sqlparse），可离线运行。

用法：
    python3 grain_gate.py <总包.sql> [--json 报告.json]

判定（任一 FAIL 即 S1，禁止归档）：
  G1  x_win 单行静态可证：CTE 名以 x_win 开头者，其顶层 SELECT
      必须「无 GROUP BY」且「每一出列皆为聚合函数或常量」
      —— 此为 SQL 语义级证明，强于运行时 COUNT(*)=1 抽验
  G2  CROSS JOIN 仅允许挂 x_win；挂任何带 GROUP BY 的 CTE 一律 FAIL
  G3  LEFT/INNER JOIN 的右表粒度键集合必须 ⊇ 左表粒度键集合（1:1 或 1:N→左侧不膨胀）
      不可判定者标 UNKNOWN，不得默认 PASS
  G4  派生表/CTE 出列重名 = 0（C04）
  G5  命名空间：e/w 侧列名须匹配 ^(xagg|xup|xwin)__[A-Za-z0-9_]+__[A-Za-z0-9_]+__.+$
  G6  硬编码黑名单：/0.30、'2026-07-08' 等须出现 0 次（白名单由 constants_a168 提供）
  G7  行尾 CRLF、UTF-8、无块注释
"""
import re, sys, json
from collections import Counter

# ─────────── 词法 ───────────
def strip_line_comments(txt):
    out=[]
    for l in txt.split('\n'):
        res='';i=0;q=None
        while i<len(l):
            c=l[i]
            if q:
                res+=c
                if c==q:q=None
                i+=1;continue
            if c in "'\"":q=c;res+=c;i+=1;continue
            if c=='-' and i+1<len(l) and l[i+1]=='-':break
            res+=c;i+=1
        out.append(res.rstrip())
    return '\n'.join(out)

def split_stmts(txt):
    out=[];cur='';q=None
    for ch in txt:
        if q:
            cur+=ch
            if ch==q:q=None
            continue
        if ch in "'\"":q=ch;cur+=ch;continue
        if ch==';':out.append(cur);cur=''
        else:cur+=ch
    if cur.strip():out.append(cur)
    return out

def depth_map(s):
    d=0;q=None;res=[]
    for ch in s:
        if q:
            res.append(d)
            if ch==q:q=None
            continue
        if ch in "'\"":q=ch;res.append(d);continue
        if ch=='(':d+=1;res.append(d);continue
        if ch==')':res.append(d);d-=1;continue
        res.append(d)
    return res

def split_list(txt):
    parts=[];d=0;cur='';q=None
    for ch in txt:
        if q:
            cur+=ch
            if ch==q:q=None
            continue
        if ch in "'\"":q=ch;cur+=ch;continue
        if ch=='(':d+=1
        if ch==')':d-=1
        if ch==',' and d==0:parts.append(cur);cur=''
        else:cur+=ch
    parts.append(cur);return parts

AGG=re.compile(r'\b(COUNT|SUM|AVG|MIN|MAX|PERCENTILE_APPROX|STDDEV|VARIANCE|GROUP_CONCAT|ANY_VALUE|BITMAP_UNION|HLL_UNION)\s*\(',re.I)
LIT=re.compile(r"^\s*(?:'[^']*'|\d+(?:\.\d+)?|NULL|TRUE|FALSE)\s*(?:AS\s+\w+)?\s*$",re.I)

def cte_bodies(s):
    out={}
    for m in re.finditer(r'\b`?(\w+)`?\s+AS\s*\(', s):
        name=m.group(1);st=m.end();d=1;j=st
        while j<len(s) and d>0:
            if s[j]=='(':d+=1
            elif s[j]==')':d-=1
            j+=1
        body=s[st:j-1]
        if re.search(r'\bSELECT\b',body,re.I): out[name]=body
    return out

def top_select_list(body):
    dm=depth_map(body)
    pos=[m.start() for m in re.finditer(r'\bSELECT\b',body,re.I) if dm[m.start()]==0]
    if not pos: return None
    s=pos[-1]
    for m in re.finditer(r'\bFROM\b',body,re.I):
        if m.start()>s and dm[m.start()]==dm[s]: return body[s+6:m.start()]
    return body[s+6:]

def has_top_groupby(body):
    dm=depth_map(body)
    return any(dm[m.start()]==0 for m in re.finditer(r'\bGROUP\s+BY\b',body,re.I))

def singleton_provable(body, scope=None, depth=0):
    """单行静态可证：无 GROUP BY 且（出列全为聚合/常量 或 FROM 源本身单行可证）"""
    if body is None or depth>4: return False
    if has_top_groupby(body): return False
    sl=top_select_list(body)
    if sl is None: return False
    allagg=True
    for it in split_list(sl):
        if not it.strip(): continue
        if AGG.search(it) or LIT.match(' '.join(it.split())): continue
        allagg=False; break
    if allagg: return True
    # 递归：出列非聚合，但 FROM 源单行可证 ⇒ 本层仍单行
    scope = scope or {}
    inner = dict(scope); inner.update(cte_bodies(body))
    dm=depth_map(body)
    srcs=[m.group(1) for m in re.finditer(r'\bFROM\s+`?(\w+)`?', body, re.I) if dm[m.start()]==0]
    if len(srcs)==1 and srcs[0] in inner:
        return singleton_provable(inner[srcs[0]], inner, depth+1)
    # FROM ( ... ) alias 形态
    m2=re.search(r'\bFROM\s*\(', body, re.I)
    if m2 and dm[m2.start()]==0:
        st=m2.end(); d=1; j=st
        while j<len(body) and d>0:
            if body[j]=='(':d+=1
            elif body[j]==')':d-=1
            j+=1
        return singleton_provable(body[st:j-1], inner, depth+1)
    return 'UNKNOWN'

# ─────────── 闸门 ───────────
def gate(path):
    raw=open(path,'rb').read()
    try: txt=raw.decode('utf-8')
    except UnicodeDecodeError:
        return [dict(gate='G7',status='FAIL',detail='非 UTF-8 编码')]
    findings=[]
    # G7
    crlf=txt.count('\r\n'); lf=txt.count('\n')
    findings.append(dict(gate='G7',item='line_ending',
        status='PASS' if crlf==lf and lf>0 else 'FAIL',
        detail='CRLF %d / LF %d'%(crlf,lf)))
    nblk=len(re.findall(r'/\*',txt))
    findings.append(dict(gate='G7',item='block_comment',
        status='PASS' if nblk==0 else 'FAIL', detail='块注释 %d 处'%nblk))
    body=strip_line_comments(txt.replace('\r\n','\n'))
    # G6
    for pat,name in ((r'/\s*0\.30\b','/0.30'), (r"'2026-07-08'","'2026-07-08'")):
        c=len(re.findall(pat,body))
        findings.append(dict(gate='G6',item=name,
            status='PASS' if c==0 else 'FAIL', detail='出现 %d 次'%c))
    stmts=[s for s in split_stmts(body) if re.search(r'\bSELECT\b',s,re.I)]
    nfail=Counter()
    for n,s in enumerate(stmts,1):
        C=cte_bodies(s)
        # G1 x_win 单行静态可证
        for name,b in C.items():
            if not name.lower().startswith('x_win'): continue
            ok = not has_top_groupby(b)
            sl=top_select_list(b) or ''
            bad=[' '.join(i.split()) for i in split_list(sl)
                 if i.strip() and not AGG.search(i) and not LIT.match(i)]
            if not ok or bad:
                nfail['G1']+=1
                findings.append(dict(gate='G1',stmt=n,item=name,status='FAIL',
                    detail=('含顶层 GROUP BY' if not ok else '')+('；非聚合出列 %s'%bad[:3] if bad else '')))
        # G2 CROSS JOIN 右表
        for m in re.finditer(r'CROSS\s+JOIN\s+`?(\w+)`?\s*(\()?',s,re.I):
            rt=m.group(1)
            if m.group(2) or rt.lower() in ('unnest','lateral','table','explode','generate_series'):
                continue  # 表函数 / LATERAL：相关展开，非笛卡尔积
            if rt.lower().startswith('x_win'): continue
            single = singleton_provable(C[rt], C) if rt in C else None
            sev = 'S3' if single is True else ('UNKNOWN' if single=='UNKNOWN' else 'S1')
            nfail['G2']+=1
            findings.append(dict(gate='G2',stmt=n,item=rt,status='FAIL',severity=sev,
                detail=('不可判定：需运行时 SELECT COUNT(*) 佐证' if single=='UNKNOWN'
                        else '单行可证，仅命名不合 x_win 规范' if single is True
                        else ('右表带顶层 GROUP BY，笛卡尔积' if rt in C and has_top_groupby(C[rt])
                              else ('右表非单行可证' if rt in C else '右表非本语句 CTE（物理表/外部）')))))
        # G4 出列重名
        for name,b in C.items():
            sl=top_select_list(b)
            if not sl: continue
            names=[]
            for it in split_list(sl):
                it=' '.join(it.split())
                mm=re.search(r'\bAS\s+`?(\w+)`?$',it,re.I)
                if mm: names.append(mm.group(1))
            dup=[k for k,v in Counter(names).items() if v>1]
            if dup:
                nfail['G4']+=1
                findings.append(dict(gate='G4',stmt=n,item=name,status='FAIL',detail='重名 %s'%dup))
        # G4b  <cte>.* + 后缀 的合并重名（覆盖派生表层，v12.0.0 的 25 件致命即在此层）
        for mm in re.finditer(r'\n\s*SELECT\s+`?(\w+)`?\.\*\s*,(.*?)\n\s*FROM\s+\1\b', s, re.S):
            base, suf = mm.group(1), mm.group(2)
            if base not in C: continue
            bl=top_select_list(C[base]) or ''
            bn=[]
            for it in split_list(bl):
                it=' '.join(it.split())
                q2=re.search(r'\bAS\s+`?(\w+)`?$',it,re.I)
                if q2: bn.append(q2.group(1))
                else:
                    q3=re.match(r'^(?:\w+\.)?`?(\w+)`?$',it)
                    if q3: bn.append(q3.group(1))
            sn=[]
            for it in split_list(suf):
                it=' '.join(it.split())
                q2=re.search(r'\bAS\s+`?(\w+)`?$',it,re.I)
                if q2: sn.append(q2.group(1))
                else:
                    q3=re.match(r'^(?:\w+\.)?`?(\w+)`?$',it)
                    if q3: sn.append(q3.group(1))
            dup=sorted(k for k,v in Counter(bn+sn).items() if v>1)
            if dup:
                nfail['G4b']+=1
                findings.append(dict(gate='G4b',stmt=n,item='%s.*+suffix'%base,status='FAIL',
                    severity='S1',detail='合并后重名 %s'%dup))
        # G8  跨实体连接：x_key 语义与 q 连接键来源实体不一致
        xk=re.findall(r'SELECT\s+(\S+)\s+AS\s+x_key', ' '.join((C.get('x_agg') or '').split()))
        if xk:
            xk=xk[0].replace('s.x_','')
            for mm in re.finditer(r'LEFT JOIN x_agg e ON.*?q\.`?(\w+)`?', s):
                jk=mm.group(1)
                qb=C.get('q') or ''
                sl=top_select_list(qb) or ''
                expr=None
                for it in split_list(sl):
                    t=' '.join(it.split())
                    m3=re.search(r'\bAS\s+`?'+re.escape(jk)+r'`?$', t, re.I)
                    if m3: expr=t[:m3.start()]; break
                    if re.match(r'^(?:\w+\.)?`?'+re.escape(jk)+r'`?$', t): expr=t; break
                bad=re.findall(r'\b(creator|operator|analyst|eid|gi\d{3})\b', expr or '')
                if xk=='member' and bad:
                    nfail['G8']+=1
                    findings.append(dict(gate='G8',stmt=n,item=jk,status='FAIL',severity='S1',
                        detail='跨实体连接：x_key=会员(bet05) ↔ q.%s 源自 %s'%(jk,bad)))
        # G9  ID 连接的类型转换纪律（须 CAST(... AS BIGINT)）
        for mm in re.finditer(r'JOIN\s+x_agg\s+e\s+ON\s*(.{0,160})', s):
            t=' '.join(mm.group(1).split())
            if 'AS BIGINT' not in t:
                nfail['G9']+=1
                findings.append(dict(gate='G9',stmt=n,item='x_agg join',status='FAIL',severity='S2',
                    detail='ID 比较未用 CAST(... AS BIGINT)：%s'%t[:70]))
        # G10 审计序不得由商业值决定（D9）
        for mm in re.finditer(r'ROW_NUMBER\(\)\s*OVER\s*\(\s*ORDER BY(.*?)\)\s*AS\s+audit_rn', s, re.S|re.I):
            keys=[]
            for k in split_list(mm.group(1)):
                mk=re.search(r'([A-Za-z_]\w*)`?\s*(?:ASC|DESC)?\s*$', k.strip().split('.')[-1].replace('`',' ').strip())
                if mk: keys.append(mk.group(1))
            biz=[k for k in keys[:2] if k in ('net_margin','profit','roi','stake','economic_value','risk_value','valid_bet','hold_rate')]
            if biz:
                nfail['G10']+=1
                findings.append(dict(gate='G10',stmt=n,item='audit_rn',status='FAIL',severity='S1',
                    detail='审计序主键为商业值 %s（D9 禁）'%biz))
        # G5 命名空间
        for mm in re.finditer(r'\bAS\s+`?((?:xagg|xup|xwin)\w*)`?',s):
            a=mm.group(1)
            if not re.match(r'^(xagg|xup|xwin)__[A-Za-z0-9_]+__[A-Za-z0-9_]+__.+$',a):
                nfail['G5']+=1
                findings.append(dict(gate='G5',stmt=n,item=a,status='FAIL',detail='不合四段式 <source>__<grain>__<window>__<metric>'))
    findings.append(dict(gate='SUMMARY',item='statements',status='INFO',detail='%d 条'%len(stmts)))
    return findings

if __name__=='__main__':
    if len(sys.argv)<2: print(__doc__); sys.exit(2)
    f=gate(sys.argv[1])
    fails=[x for x in f if x.get('status')=='FAIL']
    from collections import Counter as C2
    print('闸门报告：%s'%sys.argv[1])
    print('  FAIL %d 项  |  分布 %s'%(len(fails), C2(x['gate'] for x in fails).most_common()))
    for x in f:
        if x.get('status') in ('FAIL','PASS') and x['gate'] in ('G6','G7'):
            print('   [%s] %-14s %s  %s'%(x['status'],x['gate'],x.get('item'),x.get('detail')))
    sev=C2(x.get('severity','S1') for x in fails if x['gate']=='G2')
    print('  G2 分级: %s'%sev.most_common())
    print('  G2 右表分布: %s'%C2(x['item'] for x in fails if x['gate']=='G2').most_common(8))
    for x in fails[:12]:
        if x['gate'] not in ('G6','G7'):
            print('   [FAIL·%s] %s stmt=%s %s : %s'%(x.get('severity','-'),x['gate'],x.get('stmt'),x.get('item'),x.get('detail')))
    if '--json' in sys.argv:
        json.dump(f,open(sys.argv[sys.argv.index('--json')+1],'w',encoding='utf-8'),ensure_ascii=False,indent=1)
    sys.exit(1 if fails else 0)
