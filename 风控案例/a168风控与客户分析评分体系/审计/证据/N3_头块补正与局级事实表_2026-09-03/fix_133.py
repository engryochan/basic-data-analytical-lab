# -*- coding: utf-8 -*-
"""#133 RK01_round_fact 校对斧正（三版同步）· 二进制处理 · 保 CRLF · 每处替换须恰一次"""
import os, sys, hashlib
sys.stdout.reconfigure(encoding="utf-8")
D = r"C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/函数"
FILES = ["a168_SQL总包_v12_0_0_HF9g-P5D_原版审计版_六层商业版_OPT.sql",
         "a168_SQL总包_v12_0_0_HF9g-P5D_分批作业版_六层商业版_OPT.sql",
         "a168_SQL总包_v12_0_0_HF9g-P5D_分批作业版1万_六层商业版_OPT.sql"]
NL = "\r\n"
REPL = [
 # ① 头部模块索引计数
 ("-- ★ a168 SQL 总包 v12.0.0-HF9g-P5 · 模块索引（132 件 · 132 张 CSV · 含 #130~#132 字典三件）★",
  "-- ★ a168 SQL 总包 v12.0.0-HF9g-P5 · 模块索引（133 件 · 133 张 CSV · 含 #130~#132 字典三件 · #133 局级事实表）★"),
 # ② 索引表增一行（紧接 #130~#132 之注记行后）
 ("--     ★ #130~#132 为字典补件（元数据），循 #078 之例不套六层商业块；net_margin 栏恒 N/A，用法 DICTIONARY。" + NL,
  "--     ★ #130~#132 为字典补件（元数据），循 #078 之例不套六层商业块；net_margin 栏恒 N/A，用法 DICTIONARY。" + NL
  + "-- 133 RK01_round_fact.csv                RK   E 局        round_key = bet03|bet04|bet39  24 N/A         FACT_BASE" + NL
  + "--     ★ #133 为局级事实表（2026-09-03 新建，只出事实不出判定），不套六层商业块；「局」非可处置实体。" + NL
  + "--       列数 24 含审计三栏（audit_rn／run_id／snapshot_sync_time）；分批版另加 batch_id 为 25。" + NL),
 # ③ 测试线 CTE：agent_id／is_test 二栏于 ods_a168_agent 不存在，改正典 age001／age022='1'
 ("      SELECT DISTINCT CAST(agent_id AS BIGINT) AS aid" + NL
  + "      FROM ods_mariadb_2b.ods_a168_agent" + NL
  + "      WHERE UPPER(TRIM(COALESCE(is_test, 'N'))) = 'Y'" + NL,
  "      SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid" + NL
  + "      FROM ods_mariadb_2b.ods_a168_agent" + NL
  + "      WHERE age022 = '1'" + NL),
 # ④ 荷官栏：bet06 系「開局時間」（datetime），荷官为 eid（字典 column_comment「荷官」；正典 x_bs0 取 b.eid AS x_dealer）
 ("             TRIM(r.bet06)                                                      AS dealer_id,",
  "             TRIM(r.eid)                                                        AS dealer_id,"),
 # ⑤ validbet 缺者回落 bet13（承本包 round_key 族 ord 层 COALESCE(vb_raw, stake_raw)）
 ("             CAST(NULLIF(TRIM(r.validbet), '') AS DECIMAL(20,8))" + NL
  + "               / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0)    AS vbet,",
  "             COALESCE(CAST(NULLIF(TRIM(r.validbet), '') AS DECIMAL(20,8)),"  + NL
  + "                      CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8)))" + NL
  + "               / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0)    AS vbet,"),
 # ⑥ 闸门：去 bet13>0（正典无此闸），补 bet05>0（正典 ord 层有）
 ("        AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0" + NL
  + "        AND CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8)) > 0" + NL,
  "        AND CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT) > 0" + NL
  + "        AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0" + NL),
 # ⑦ 口径六锁注记同步
 ("--            · bet11 > 0（汇率为正）· bet13 > 0（本金为正）",
  "--            · bet05 > 0（会员号为正）· bet11 > 0（汇率为正）"),
 ("--   ⑥ 归一   一切金额除以 bet11（汇率），与 #053 PI01 / #075 S01 逐字同法",
  "--   ⑥ 归一   一切金额除以 bet11（汇率），与本包 round_key 族 ord 层（#075 S01 之 x_bs0 同）逐字同法"),
 # ⑧ 斧正记录（紧接标题块之后）
 ("--       即重蹈 D-14 覆辙（相对刻度施于非实体行）。局之赏罚一律回落至会员／荷官／桌台三实体。" + NL
  + "-- ══════════════════════════════════════════════════════════════════════════════════════════════" + NL,
  "--       即重蹈 D-14 覆辙（相对刻度施于非实体行）。局之赏罚一律回落至会员／荷官／桌台三实体。" + NL
  + "--     ★ 2026-09-03 校对斧正（三版同步，以 DICT_ALL_columns.csv 与本包正典逐栏核对）：" + NL
  + "--       ① 测试线 CTE 原书 agent_id／is_test 二栏，于 ods_a168_agent（51 栏）皆不存在 ⇒ 改正典 age001／age022='1'（与 x_testagent 同）；" + NL
  + "--       ② 荷官栏原取 bet06，字典注「開局時間」（datetime）⇒ 改 eid（字典注「荷官」，正典 x_bs0 之 x_dealer）；" + NL
  + "--       ③ validbet 缺者回落 bet13（承 ord 层 COALESCE(vb_raw, stake_raw)）；" + NL
  + "--       ④ 闸门去 bet13>0（正典无）、补 bet05>0（正典有），六锁自此与 round_key 族逐字同一；" + NL
  + "--       ⑤ ggr 系【庄家视角】= (bet13 − bet14)/bet11 = −game_pnl（本包 game_pnl 为会员视角 payout−stake），hold_pct 为洗码口径。" + NL
  + "-- ══════════════════════════════════════════════════════════════════════════════════════════════" + NL),
]
for fn in FILES:
    p = os.path.join(D, fn); b = open(p, "rb").read()
    assert b.count(b"\n") == b.count(b"\r\n"), "非纯 CRLF"
    s = b.decode("utf-8"); n0 = s.count(NL)
    for old, new in REPL:
        c = s.count(old)
        assert c == 1, f"{fn}: 替换目标出现 {c} 次（须恰 1）：{old[:60]!r}"
        s = s.replace(old, new)
    b2 = s.encode("utf-8"); assert b2.count(b"\n") == b2.count(b"\r\n")
    open(p, "wb").write(b2)
    print(f"{fn[:58]} | lines {n0} -> {b2.count(NL.encode())} | bytes {len(b)} -> {len(b2)} | md5 {hashlib.md5(b2).hexdigest()}")
print("OK: 8 replacements x 3 files")
