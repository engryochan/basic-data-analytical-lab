# -*- coding: utf-8 -*-
"""R03b ＃071 排序键裁剪 · 探针输出之逐字节比对审计   v1.0.0   2026-09-05
   ⛔ 只读，不改任何档。

用法（择一）：
    python R03b_探针_逐字节比对审计_v1.0.0.py  <探针导出之csv>
    python R03b_探针_逐字节比对审计_v1.0.0.py  <探针导出之csv>  <基准csv>

    省略基准档时，默认取
      数据库 HF9g-P5D_OPT/R03b_player_dealer_daily (一次一万行)/R03b_player_dealer_daily_b100.csv

判读：
    【判一】原始位元组 MD5 相同        → ★ 逐字节全同，无须再看，直接放行
    若位元组不同，续查其因（导出器之换行／编码／数值格式差异，未必是 SQL 之过）：
    【判二】表头逐栏相同
    【判三】行数相同
    【判四】逐行逐栏逐字比对 —— 不符之栏与例
    只有【判四】零不符，方可宣布「输出一模一样」。
"""
import io, os, sys, csv, hashlib, collections

out = io.open(sys.stdout.fileno(), "w", encoding="utf-8", closefd=False)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_BASE = os.path.join(ROOT, "数据库 HF9g-P5D_OPT",
                            "R03b_player_dealer_daily (一次一万行)",
                            "R03b_player_dealer_daily_b100.csv")

if len(sys.argv) < 2:
    out.write(__doc__)
    sys.exit(1)
NEW = sys.argv[1]
BASE = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_BASE

for p in (NEW, BASE):
    if not os.path.exists(p):
        out.write("⛔ 档不在位：%s\n" % p)
        sys.exit(1)

rn, rb = io.open(NEW, "rb").read(), io.open(BASE, "rb").read()
out.write("=" * 96 + "\n")
out.write("探针输出 : %s\n           %s B ｜ MD5 %s\n" % (NEW, "{:,}".format(len(rn)), hashlib.md5(rn).hexdigest()))
out.write("基准现档 : %s\n           %s B ｜ MD5 %s\n" % (BASE, "{:,}".format(len(rb)), hashlib.md5(rb).hexdigest()))
out.write("=" * 96 + "\n")

if rn == rb:
    out.write("【判一】★ 原始位元组【完全相同】—— 输出一模一样，一字不差。裁剪案【可放行】。\n")
    out.write("=" * 96 + "\n")
    sys.exit(0)
out.write("【判一】位元组不同（差 %s B）。⚑ 未必是 SQL 之过 —— 导出器之换行／BOM／数值格式亦会致差。续查。\n"
          % "{:,}".format(len(rn) - len(rb)))
out.write("        换行：新档 CRLF %s / LF %s ｜ 基准 CRLF %s / LF %s\n"
          % ("{:,}".format(rn.count(b"\r\n")), "{:,}".format(rn.count(b"\n")),
             "{:,}".format(rb.count(b"\r\n")), "{:,}".format(rb.count(b"\n"))))
out.write("        BOM ：新档 %s ｜ 基准 %s\n" % (rn[:3] == b"\xef\xbb\xbf", rb[:3] == b"\xef\xbb\xbf"))


def load(p):
    fh = io.open(p, encoding="utf-8-sig", newline="")
    r = csv.reader(fh)
    h = next(r)
    d = [row for row in r]
    fh.close()
    return h, d


hn, dn = load(NEW)
hb, db = load(BASE)
out.write("\n【判二】表头：新档 %d 栏 ／ 基准 %d 栏 → %s\n"
          % (len(hn), len(hb), "★ 逐栏相同" if hn == hb else "⛔ 不同"))
if hn != hb:
    only_n = [c for c in hn if c not in hb]
    only_b = [c for c in hb if c not in hn]
    out.write("    新档独有：%s\n    基准独有：%s\n" % (only_n[:8], only_b[:8]))
    order = [(i, a, b) for i, (a, b) in enumerate(zip(hn, hb)) if a != b]
    out.write("    同位不同名者 %d 处，前 5：%s\n" % (len(order), order[:5]))
    out.write("=" * 96 + "\n")
    sys.exit(2)

out.write("【判三】行数：新档 %s ／ 基准 %s → %s\n"
          % ("{:,}".format(len(dn)), "{:,}".format(len(db)),
             "★ 相同" if len(dn) == len(db) else "⛔ 不同"))
if len(dn) != len(db):
    out.write("=" * 96 + "\n")
    sys.exit(3)

out.write("\n【判四】逐行逐栏逐字比对（%s 行 × %d 栏 ＝ %s 格）\n"
          % ("{:,}".format(len(dn)), len(hn), "{:,}".format(len(dn) * len(hn))))
bad = collections.Counter()
ex = {}
nbadrow = 0
for i in range(len(dn)):
    a, b = dn[i], db[i]
    hit = False
    for j in range(len(hn)):
        va = a[j] if j < len(a) else ""
        vb = b[j] if j < len(b) else ""
        if va != vb:
            bad[hn[j]] += 1
            hit = True
            if hn[j] not in ex:
                ex[hn[j]] = (i + 1, va[:40], vb[:40])
    if hit:
        nbadrow += 1
tot = sum(bad.values())
out.write("    不符之格 = %s ／ 不符之行 = %s ／ 涉及 %d 栏\n"
          % ("{:,}".format(tot), "{:,}".format(nbadrow), len(bad)))
if tot == 0:
    out.write("\n★★ 逐行逐栏逐字【零不符】—— 输出一模一样。位元组之差纯系导出器格式，非 SQL 之过。\n")
    out.write("    裁剪案【可放行】。\n")
else:
    out.write("\n⛔ 有不符，裁剪案【不可放行】。逐栏明细（前 15 栏）：\n")
    for c, n in bad.most_common(15):
        i, va, vb = ex[c]
        out.write("      %-42s %8s 格   例第 %d 行  新=%r  基准=%r\n"
                  % (c, "{:,}".format(n), i, va, vb))
out.write("=" * 96 + "\n")
sys.exit(0 if tot == 0 else 4)
