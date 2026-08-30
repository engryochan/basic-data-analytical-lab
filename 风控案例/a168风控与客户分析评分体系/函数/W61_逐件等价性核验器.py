#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
W-61 · P1 ↔ P2 逐件（逐函数）等价性核验器

做法：
  1. 把整份 .sql 归约为【可执行语句序列】—— 去行注释、去块注释，
     字符串/反引号内不切；再按顶层分号切分。
  2. 每条语句再归约为【token 序列】，取 SHA-256。
  3. P1 与 P2 逐条对位比较：条数、次序、token 数、摘要。
  4. 把每条语句挂回其所属交付件（以 P2 的区块标题为准），出逐件核验表。

输出：终端摘要 ＋ 逐件核验表（CSV）
"""
import re, sys, csv, hashlib


# ── 归约一：去注释（字符串/反引号内不算注释）────────────────────────────────
def strip_comments(text):
    out, i, n = [], 0, len(text)
    q = None
    while i < n:
        c = text[i]
        if q:
            out.append(c)
            if c == q:
                q = None
            i += 1
            continue
        if c in ("'", '"', "`"):
            q = c; out.append(c); i += 1; continue
        if c == "-" and i + 1 < n and text[i + 1] == "-":          # 行注释
            while i < n and text[i] not in "\r\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":          # 块注释
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            out.append(" ")
            continue
        out.append(c); i += 1
    return "".join(out)


# ── 归约二：按顶层分号切分语句 ──────────────────────────────────────────────
def split_statements(exe):
    stmts, buf, q, i, n = [], [], None, 0, len(exe)
    while i < n:
        c = exe[i]
        if q:
            buf.append(c)
            if c == q:
                q = None
            i += 1; continue
        if c in ("'", '"', "`"):
            q = c; buf.append(c); i += 1; continue
        if c == ";":
            s = "".join(buf).strip()
            if s:
                stmts.append(s)
            buf = []; i += 1; continue
        buf.append(c); i += 1
    s = "".join(buf).strip()
    if s:
        stmts.append(s)
    return stmts


# ── 归约三：token 化 ────────────────────────────────────────────────────────
TOK = re.compile(r"'(?:[^']|'')*'|\"[^\"]*\"|`[^`]*`|[A-Za-z_][A-Za-z_0-9$]*|\d+\.\d+|\d+|[^\sA-Za-z_0-9]")


def tokens(stmt):
    return TOK.findall(stmt)


def digest(toks):
    return hashlib.sha256("\u0001".join(toks).encode("utf-8")).hexdigest()


# ── 把语句挂回所属交付件（以文件内标题行的字节位置为界）──────────────────────
def statement_owners(raw):
    """回 [(起始偏移, 语句文本)]，并回 [(偏移, 件号, 件名)]。"""
    # 交付件标题在原文中的偏移
    heads = []
    for m in re.finditer(r"^--\s+(\d+)\.\s+(\S+\.csv)\s+\[", raw, re.M):
        heads.append((m.start(), int(m.group(1)), m.group(2)))
    return heads


def statements_with_offsets(raw):
    """在【保长】的去注释文本上切分，使每条语句仍可回溯原文偏移。"""
    n = len(raw)
    keep = list(raw)
    i, q = 0, None
    while i < n:
        c = raw[i]
        if q:
            if c == q:
                q = None
            i += 1; continue
        if c in ("'", '"', "`"):
            q = c; i += 1; continue
        if c == "-" and i + 1 < n and raw[i + 1] == "-":
            while i < n and raw[i] not in "\r\n":
                keep[i] = " "; i += 1
            continue
        if c == "/" and i + 1 < n and raw[i + 1] == "*":
            j = raw.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                keep[k] = " "
            i = j; continue
        i += 1
    masked = "".join(keep)                       # 与原文等长，注释位已抹为空格

    res, start, q, i = [], 0, None, 0
    while i < n:
        c = masked[i]
        if q:
            if c == q:
                q = None
            i += 1; continue
        if c in ("'", '"', "`"):
            q = c; i += 1; continue
        if c == ";":
            seg = masked[start:i]
            if seg.strip():
                res.append((start + len(seg) - len(seg.lstrip()), seg.strip()))
            start = i + 1
        i += 1
    seg = masked[start:]
    if seg.strip():
        res.append((start + len(seg) - len(seg.lstrip()), seg.strip()))
    return res


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    return raw, statements_with_offsets(raw), statement_owners(raw)


def owner_of(off, heads):
    cur = ("§Z 前置段", 0)
    for h_off, no, name in heads:
        if h_off <= off:
            cur = (name, no)
        else:
            break
    return cur


def run(p1, p2, label, writer):
    raw1, st1, hd1 = load(p1)
    raw2, st2, hd2 = load(p2)
    ok = True
    print("═" * 92)
    print("【%s】" % label)
    print("  可执行语句数  P1 = %d   P2 = %d   %s"
          % (len(st1), len(st2), "✓ 相同" if len(st1) == len(st2) else "✗ 不同"))
    if len(st1) != len(st2):
        return False
    print("  交付件标题数  P1 = %d   P2 = %d" % (len(hd1), len(hd2)))
    mism = []
    for k, ((o1, s1), (o2, s2)) in enumerate(zip(st1, st2), 1):
        t1, t2 = tokens(s1), tokens(s2)
        d1, d2 = digest(t1), digest(t2)
        name, no = owner_of(o2, hd2)
        same = (d1 == d2)
        if not same:
            mism.append((k, name))
            ok = False
        writer.writerow([label, k, no if no else "", name, len(t1), len(t2),
                         d1[:16], d2[:16], "IDENTICAL" if same else "DIFF"])
    print("  逐条 token 摘要比对：%d / %d 条 IDENTICAL   %s"
          % (len(st1) - len(mism), len(st1), "✓" if ok else "✗ 不符：%s" % mism[:10]))
    # 全文合并摘要
    a = digest([t for _, s in st1 for t in tokens(s)])
    b = digest([t for _, s in st2 for t in tokens(s)])
    print("  全文 token 流摘要  P1 %s" % a[:40])
    print("                     P2 %s   %s" % (b[:40], "✓" if a == b else "✗"))
    return ok


if __name__ == "__main__":
    out = open(sys.argv[1], "w", newline="", encoding="utf-8-sig")
    w = csv.writer(out)
    w.writerow(["版本", "语句序号", "件号", "所属交付件", "P1_token数", "P2_token数",
                "P1_摘要16", "P2_摘要16", "判定"])
    allok = True
    for v in ["原版审计版", "分批作业版"]:
        allok &= run(
            "/mnt/user-data/uploads/a168_SQL总包_v12_0_0_HF9g-P1_%s_六层商业版.sql" % v,
            "/mnt/user-data/outputs/a168_SQL总包_v12_0_0_HF9g-P2_%s_六层商业版.sql" % v,
            v, w)
    out.close()
    print("═" * 92)
    print("总判定：%s" % ("PASS —— 全部语句逐条 token 流一致" if allok else "FAIL"))
