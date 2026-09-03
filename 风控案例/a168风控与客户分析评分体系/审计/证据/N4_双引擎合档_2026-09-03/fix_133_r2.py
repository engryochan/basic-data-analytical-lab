# -*- coding: utf-8 -*-
"""#133 第二轮斧正（三版同步）· 保 CRLF · 每处替换须恰一次
 SQ-06 去重排序键非正典：全档 139 处用 (updatetime, sync_time, dt) 三键，独 #133 用 sync_time 单键 ⇒ 并列时不确定
 SQ-07 「6,048,725」之出处误书「口诀旧测」：实系 #014 DICT_01b_roundkey_card.csv 之落盘实测，且其口径只四锁
        （无去重、无 bet38='N'、无剔测试线、无 bet05>0/bet11>0）⇒ #133 六锁之 T_true 必 ≤ 6,048,725，非「≈」
 SQ-08 分批数「61 批／末批 48,725 行」系由上述上界推得 ⇒ 须标为上界，待探针实测后回填
"""
import os, sys, hashlib
sys.stdout.reconfigure(encoding="utf-8")
D = r"C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/函数"
NL = "\r\n"
COMMON = [
 # ── SQ-06 去重排序键归正典 ──
 ("             ROW_NUMBER() OVER (PARTITION BY b.bet01 ORDER BY b.sync_time DESC) AS rn" + NL,
  "             ROW_NUMBER() OVER (" + NL
  + "               PARTITION BY b.bet01" + NL
  + "               ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)                AS rn" + NL),
 ("--   ④ 去重   PARTITION BY bet01 取 rn = 1",
  "--   ④ 去重   PARTITION BY bet01 ORDER BY updatetime DESC, sync_time DESC, dt DESC 取 rn = 1"),
 # ── SQ-07 出处正名 ＋ 上界改写 ──
 ("--   P999 = 93.2 · 全窗 6,048,725 局），却在既有 132 件中**无任何一件以其为主键**。",
  "--   P999 = 93.2 —— 二者出 #118 Z08_roundkey_integrity.csv 之落盘实测），却在既有 132 件中**无一以其为主键**。"),
 ("-- 【规模警示】预期 T_true ≈ 6,048,725 行（口诀已实测之 round_key 去重数）。" + NL,
  "-- 【规模警示 · 2026-09-03 斧正】T_true 之【上界】＝ 6,048,725 行，非「约等于」。" + NL
  + "--   该数出 #014 DICT_01b_roundkey_card.csv 之落盘实测（nd_round_key = 6,048,725；n_rows = 125,649,147），" + NL
  + "--   然其口径只【四锁】：dt 窗口 ＋ bet02='101' ＋ sync_time 快照 ＋ TRIM(category)='1'——" + NL
  + "--   **不含**去重 rn=1、bet38='N'、剔测试线、bet05>0、bet11>0。本件为【六锁】，故 T_true 必 ≤ 6,048,725。" + NL
  + "--   （去重 rn=1 不减局数：每一 bet01 恒留一行，无从令某局全灭；减数只来自后四锁。）" + NL
  + "--   另 #118 Z08_roundkey_integrity.csv 之局键数 6,919,057 系【二锁】（bet02＋快照，**无 dt 窗口**，" + NL
  + "--   注单行数 143,085,880），与本件口径更远，不可混引。" + NL
  + "--   ⇒ 落盘前须先跑《函数/RK01_行数实测探针_v1_0_0.sql》§1，以其回值为准，并回填本注与分批数。" + NL),
]
SPECIFIC = {
 "a168_SQL总包_v12_0_0_HF9g-P5D_原版审计版_六层商业版_OPT.sql": [],
 "a168_SQL总包_v12_0_0_HF9g-P5D_分批作业版_六层商业版_OPT.sql": [
   ("-- ── ① T_true 预期 6,048,725 行（口诀已实测之 round_key 去重数）；实跑须以本件回值复核。" + NL
    + "--      本批实际返回行数 < 100000 即判定为末批；预期共 61 批，末批 48,725 行。" + NL,
    "-- ── ① T_true 之【上界】6,048,725 行（出 #014 DICT_01b_roundkey_card.csv 四锁实测；本件六锁故必更少）。" + NL
    + "--      ⇒ 批数【上界】61 批（末批上界 48,725 行）。真值须先跑《函数/RK01_行数实测探针_v1_0_0.sql》§1，" + NL
    + "--      以其 t_true_rows／n_batches_100k／last_batch_rows_100k 回填本注，勿以上界充实测。" + NL
    + "--      本批实际返回行数 < 100000 即判定为末批。" + NL),
 ],
 "a168_SQL总包_v12_0_0_HF9g-P5D_分批作业版1万_六层商业版_OPT.sql": [
   ("-- ── ① T_true 预期 6,048,725 行（口诀已实测之 round_key 去重数）；实跑须以本件回值复核。" + NL
    + "--      本批实际返回行数 < 10000 即判定为末批；预期共 605 批，末批 8,725 行。" + NL,
    "-- ── ① T_true 之【上界】6,048,725 行（出 #014 DICT_01b_roundkey_card.csv 四锁实测；本件六锁故必更少）。" + NL
    + "--      ⇒ 批数【上界】605 批（末批上界 8,725 行）。真值须先跑《函数/RK01_行数实测探针_v1_0_0.sql》§1，" + NL
    + "--      以其 t_true_rows／n_batches_10k／last_batch_rows_10k 回填本注，勿以上界充实测。" + NL
    + "--      本批实际返回行数 < 10000 即判定为末批。" + NL),
 ],
}
# 斧正记录追加（承首轮五条，续三条）
LOGADD = ("--       ⑤ ggr 系【庄家视角】= (bet13 − bet14)/bet11 = −game_pnl（本包 game_pnl 为会员视角 payout−stake），hold_pct 为洗码口径。" + NL,
          "--       ⑤ ggr 系【庄家视角】= (bet13 − bet14)/bet11 = −game_pnl（本包 game_pnl 为会员视角 payout−stake），hold_pct 为洗码口径。" + NL
          + "--     ★ 2026-09-03 第二轮斧正（承先生「须依原本 132 件」之训）：" + NL
          + "--       ⑥ 去重排序键原书 ORDER BY sync_time DESC 单键——全档 139 处正典皆为" + NL
          + "--          ORDER BY updatetime DESC, sync_time DESC, dt DESC 三键；单键遇并列即不确定 ⇒ 已归正典。" + NL
          + "--       ⑦ 「6,048,725」原注为「口诀已实测」，实出 #014 DICT_01b_roundkey_card.csv 之落盘实测，" + NL
          + "--          且其口径只四锁 ⇒ 本件六锁之 T_true 必 ≤ 之，已由「约等于」改「上界」。" + NL
          + "--       ⑧ 分批数系由上界推得，已标为上界，待探针 §1 实测回填。" + NL)
for fn, spec in SPECIFIC.items():
    p = os.path.join(D, fn); b = open(p, "rb").read()
    assert b.count(b"\n") == b.count(b"\r\n"), fn + " 非纯 CRLF"
    s = b.decode("utf-8"); n0 = s.count(NL)
    for old, new in COMMON + spec + [LOGADD]:
        c = s.count(old); assert c == 1, f"{fn}: 替换目标出现 {c} 次（须恰 1）：{old[:70]!r}"
        s = s.replace(old, new)
    b2 = s.encode("utf-8"); assert b2.count(b"\n") == b2.count(b"\r\n")
    open(p, "wb").write(b2)
    print(f"{fn[:56]} | lines {n0} -> {b2.count(NL.encode())} | bytes {len(b)} -> {len(b2)} | md5 {hashlib.md5(b2).hexdigest()}")
print("OK: #133 第二轮斧正 · 三版同步")
