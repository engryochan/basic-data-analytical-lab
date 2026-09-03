-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- RK01_行数实测探针 v2.0.1   [#133 RK01_round_fact.csv 之观测值实测 · 只读 · 不落盘]
-- 立册 : 2026-09-03        Owner : Ryo Eng        配套 : a168_SQL总包_v12_0_0_HF9g-P5D_*_OPT.sql #133
-- ----------------------------------------------------------------------------------------------
-- 变更 : 2.0.0（2026-09-03 · 承先生「若只是一天的话就错了，因为原本的 132 件数据表都一致
--          WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'」之训）——三处实质斧正：
--        ① **废除 v1.1.0 之「§0 单日冒烟测试」**。单日自立门户，与 132 件之全窗口径相悖，
--           属口径漂移；纵只为验连线，亦不得产出任何窗口内之局部数（易被误引为业务数）。
--           改以【§0 连线自检】——只读 ods_a168_agent 之测试线名册（约数十行），
--           **不触 ods_a168_bet02、不设窗口、不出任何口径量**，故无从漂移。
--        ② **「6,048,725」正名**。v1.x 误书「承口诀之旧测」；实系 **#014
--           DICT_01b_roundkey_card.csv** 之落盘实测（`nd_round_key` 栏），且其口径只【四锁】。
--           本件为【六锁】，故 T_true 必 **≤** 6,048,725，非「约等于」。
--        ③ **§2 口径漏斗改为「有锚阶梯」**：逐闸回值须与 #014（四锁）之落盘数对得上，
--           末端须与 §1 之 t_true_rows 逐位相等。无锚之漏斗只是数字，有锚方为证据。
--        另：三节之去重排序键一律归全档正典（139 处皆 updatetime→sync_time→dt 三键）。
-- 变更 : 2.0.1（2026-09-03 · 实测后）§3 判读斧正：分位数于子集非单调，不得与极值同论「须 ≤ #118」；
--          另于档末【实测存档】登记 2026-09-03 §0~§3 之全部回值，供日后重跑逐位对账。
-- 变更 : 1.1.0（2026-09-03）新增【疑难排解】节（CSRF 之诊）。1.0.0 立册。
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【本件之问】#133 一共有多少观测值？——即 RK01_round_fact.csv 之【行数 T_true】。
--   #133 之粒度为 round_key（= bet03|bet04|bet39），故 T_true = 六锁过滤后 round_key 之相异数。
--
-- 【三个口径 · 三个数 · 不可混引】（皆自 数据表/ 落盘件实读，非推测）
--   ┌ #118 Z08_roundkey_integrity.csv ── 【二锁】bet02='101' ＋ sync_time 快照，**无 dt 窗口**
--   │    注单行数 143,085,880 ｜ 局键数 **6,919,057** ｜ 单局最大会员 256 ｜ 单局会员数 P999 93.225
--   │    ★ 无窗口 ⇒ 含窗外历史，与本件口径最远，**不可**引为本件之预期。
--   ├ #014 DICT_01b_roundkey_card.csv ── 【四锁】dt 窗口 ＋ bet02='101' ＋ 快照 ＋ TRIM(category)='1'
--   │    注单行数 125,649,147 ｜ 局键数 **6,048,725** ｜ 每局均注 20.7728 ｜ nd_bet03 123,359 ｜ nd_bet39 30
--   │    ★ **不含**去重 rn=1、bet38='N'、剔测试线、bet05>0、bet11>0。
--   └ #133 RK01_round_fact.csv（本件之标的）── 【六锁】全
--        T_true = **待测**，且必 ≤ 6,048,725。
--   【为何去重不减局数】rn=1 每一 bet01 恒留一行，无从令某局之全部注单皆被剔 ⇒ 局键集合不变。
--        故 6,048,725 → T_true 之减数，只来自 bet38='N'、剔测试线、bet05>0、bet11>0 四闸。
--
-- 【口径六锁 · 与 #133 逐字同一，勿改；亦与 132 件全窗口径一致】
--   ① 窗口 dt >= '2026-03-21' AND dt < '2026-08-07'   ② 产品 bet02 = '101'
--   ③ 快照 sync_time <= '2026-08-27 09:00:00'
--   ④ 去重 PARTITION BY bet01 ORDER BY updatetime DESC, sync_time DESC, dt DESC 取 rn = 1
--   ⑤ 基础闸 category='1' · UPPER(TRIM(bet38))='N' · 五级代理左连取 NULL（剔测试线）· bet05>0 · bet11>0
--   ⑥ 归一 一切金额除以 bet11（本件不出金额，故⑥于此只作口径声明）
--   ⛔ 全窗铁律：本件任何一节皆**不得**以单日、单桌、单月或 LIMIT 缩窗取巧。
--      缩窗所得之数与 132 件不可对账，纵然跑得快，亦是废数。
--
-- 【禁令遵循】只用行注释（分号／斜线在块注释内会被误判为语句终止）；一切 ID 比较 CAST 至 BIGINT；
--   一切除法以 NULLIF 护零；NULL ≠ 0，未观测者留 NULL 不写 0；禁 OFFSET；禁以 DATE(bet08) 切日。
--
-- 【用法】四节各为独立一句，一次只贴一节（Superset 预设禁多语句）。
--   §0 连线自检 —— 秒级；只读代理名册，不触注单主表，不出口径量
--   §1 主探针   —— 必跑；回 T_true、分批数、局内人数与对次之总量
--   §2 口径漏斗 —— 有锚阶梯；L1 须对上 #014 之 6,048,725，L6 须对上 §1 之 t_true_rows
--   §3 形态探针 —— 每局人数分位、多荷官局（#133 注记之待裁项），与 #118 对照
-- ══════════════════════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【疑难排解】客户端之误 vs SQL 之误 —— 先分清，再动码
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- ★ 症状一：「400 Bad Request: The CSRF tokens do not match」／「Issue 1011 - Superset 遇到了未知错误」
--   判定：**非 SQL 之误**。耗时不足一秒即回（如 0.341s）、错误码 400（HTTP 层）、错文只言 CSRF 令牌——
--         此请求根本未送抵 StarRocks，谈不上 SQL 对错。CSRF 系 Superset 之跨站请求伪造防护令牌，
--         页面开置过久、后台重启、Cookie 被清、或另开分页致会话轮换，皆令令牌与服务端不符。
--   解法（依序试）：
--     ① 于 SQL Lab 页面硬刷新（Windows：Ctrl+F5 或 Ctrl+Shift+R），令浏览器重取新令牌，再贴再跑；
--     ② 仍不行则登出 Superset 再登入（会话重建），再贴再跑；
--     ③ 若频发，改以 MySQL 协议直连 StarRocks FE（预设 9030 埠），绕开 Superset 之 Web 层：
--          mysql -h <FE_HOST> -P 9030 -u <USER> -p
--        ★ StarRocks 兼容 MySQL 协议，故 DBeaver／Navicat／mysql CLI 皆可直连。
--   ⛔ 切勿因此错而改动 SQL —— 改码治不了会话之病，反致口径漂移。
--   ⛔ 尤其不得为「跑得快些」而缩窗（改单日、加 LIMIT）—— 那是以口径换速度，废数一场。
--
-- ★ 症状二：「Only single queries supported」／只跑了第一节
--   判定：Superset SQL Lab 预设禁多语句。本档四节以分号分隔，**须一次只贴一节**。
--
-- ★ 症状三：查询逾时（Query timeout／Async queries）
--   判定：§1～§3 皆全量扫 ods_a168_bet02（窗内 125,649,147 注单，出 #014 落盘实测），分钟级属正常。
--   解法：先跑 §0 连线自检（秒级、无口径）确认连线与权限；再于 Superset 开启异步查询（Async）
--         或调高 SQLLAB_TIMEOUT／SQLLAB_ASYNC_TIME_LIMIT_SEC；或改走 MySQL 直连（无 Web 逾时）。
--         ⛔ 不得以缩窗规避逾时。
--
-- ★ 症状四：语法报错
--   判定：本档字段型别已对 数据表/DICT_ALL_columns.csv 逐栏核实——ods_a168_bet02 之
--         bet01/bet03/bet04/bet05/bet09/bet11/bet13/bet38/bet39/validbet/category/eid 皆 varchar(65533)，
--         dt 为 date、sync_time 为 datetime、updatetime 见字典；ods_a168_agent 之 age001/age022 皆 varchar(65533)。
--         故 TRIM()／CAST()／字串比较（age022 = '1'）皆型别正确。若仍报错，请回报**完整错文**再诊。
-- ══════════════════════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §0 连线自检 · 只读代理名册（秒级 · 不触注单主表 · 不设窗口 · 不出任何口径量）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【用途】遇客户端异常（CSRF／逾时／连线断）时先跑本节，用以分清病灶：
--   · 秒级回值 ⇒ 连线通、权限足、语法解析无碍 ⇒ 问题在会话或逾时，回上节依序排解；
--   · 本节亦报错 ⇒ 方为连线、权限或语法之误，据错文再诊。
-- 【何以不设窗口】本节只数测试线代理（ods_a168_agent 表极小），与 dt 窗口、bet02 产品锁全然无涉，
--   故**不产生任何可被误引之口径量**——此即取代 v1.1.0 单日冒烟测试之理由。
SELECT 'RK01 §0 连线自检 · 无口径量 · 仅验连线与权限'          AS probe,
       COUNT(*)                                              AS n_agent_rows_scanned,
       COUNT(DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT)) AS nd_test_agent_id,
       CURRENT_TIMESTAMP()                                   AS probe_at
FROM ods_mariadb_2b.ods_a168_agent
WHERE age022 = '1';
--   ★ 回值即证：连线通、权限足、TRIM/CAST 语法可解析。此后 §1～§3 若再遇 400／逾时，一律属客户端。
--   ★ nd_test_agent_id 即六锁之⑤「剔测试线」所用之名册基数，可与 §2 之 L4 减数互参。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §1 主探针 · T_true 与分批数（必跑 · 全窗六锁 · 回一行）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)          AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.sync_time <= '2026-08-27 09:00:00'
),
base AS (
  SELECT CONCAT_WS('|', TRIM(r.bet03), TRIM(r.bet04), TRIM(r.bet39))            AS round_key,
         TRIM(r.bet39)                                                          AS table_id,
         TRIM(r.bet03)                                                          AS shoe_key,
         TRIM(r.bet04)                                                          AS round_seq,
         r.dt                                                                   AS biz_date,
         CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT)                              AS member_id,
         TRIM(r.eid)                                                            AS dealer_id
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(r.bet18), '') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(r.bet19), '') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(r.bet20), '') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(r.bet21), '') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(r.bet22), '') AS BIGINT)
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
    AND CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0
),
g AS (
  -- 与 #133 之 GROUP BY 逐字同一（四栏中后三栏系 round_key 之分量，故等价于按 round_key 聚合）
  SELECT b.round_key,
         b.table_id,
         b.shoe_key,
         b.round_seq,
         MIN(b.biz_date)                    AS biz_date,
         COUNT(DISTINCT b.member_id)        AS n_members,
         COUNT(DISTINCT b.dealer_id)        AS n_dealer_id,
         COUNT(*)                           AS n_bets
  FROM base b
  GROUP BY b.round_key, b.table_id, b.shoe_key, b.round_seq
)
SELECT 'RK01 §1 主探针 · #133 · 全窗六锁实测'                                    AS probe,
       COUNT(*)                                                                 AS t_true_rows,
       COUNT(DISTINCT g.round_key)                                              AS nd_round_key,
       6048725                                                                  AS upper_bound_from_014,
       6048725 - COUNT(*)                                                       AS reduced_by_locks_4to6,
       ROUND(COUNT(*) * 100.0 / 6048725, 4)                                     AS pct_of_upper_bound,
       CAST(CEIL(COUNT(*) / 100000.0) AS BIGINT)                                AS n_batches_100k,
       CAST(CEIL(COUNT(*)  / 10000.0) AS BIGINT)                                AS n_batches_10k,
       COUNT(*) - (CAST(CEIL(COUNT(*) / 100000.0) AS BIGINT) - 1) * 100000      AS last_batch_rows_100k,
       COUNT(*) - (CAST(CEIL(COUNT(*)  / 10000.0) AS BIGINT) - 1) * 10000       AS last_batch_rows_10k,
       SUM(g.n_bets)                                                            AS n_bets_total,
       COUNT(DISTINCT g.table_id)                                               AS nd_table,
       COUNT(DISTINCT CONCAT_WS('|', g.table_id, g.shoe_key))                   AS nd_table_shoe,
       COUNT(DISTINCT g.biz_date)                                               AS nd_biz_date,
       MIN(g.biz_date)                                                          AS min_biz_date,
       MAX(g.biz_date)                                                          AS max_biz_date,
       SUM(CASE WHEN g.n_members >= 2 THEN 1 ELSE 0 END)                        AS n_rounds_multiparty,
       SUM(CAST(g.n_members * (g.n_members - 1) / 2 AS BIGINT))                 AS n_member_pairs_total,
       SUM(CASE WHEN g.n_dealer_id > 1 THEN 1 ELSE 0 END)                       AS n_rounds_multi_dealer,
       MAX(g.n_members)                                                         AS max_members_in_round,
       ROUND(AVG(g.n_members), 4)                                               AS avg_members_per_round,
       ROUND(AVG(g.n_bets), 4)                                                  AS avg_bets_per_round,
       'A168_HF9F_20260827_0900'                                                AS run_id,
       '2026-08-27 09:00:00'                                                    AS snapshot_sync_time
FROM g;
--   ★ 判读一：t_true_rows ＝ nd_round_key 须相等（后三栏系 round_key 之分量，不等即 TRIM 口径有异，须查）。
--   ★ 判读二：t_true_rows 须 **≤ 6,048,725**（#014 四锁上界）。若 >，则六锁之实作有误，须停跑查因。
--     reduced_by_locks_4to6 即 bet38='N' ＋ 剔测试线 ＋ bet05>0 ＋ bet11>0 四闸所剔之局数，
--     其构成由 §2 逐闸给出。
--   ★ 判读三：nd_table 应与 #014 之 nd_bet39 = 30 同量级；nd_table_shoe 应 ≤ #014 之 nd_shoe_table 123,359；
--     nd_biz_date 应 = 139（窗内营运日数）。任一项相去甚远，即口径或数据有异，须查而非改码。
--   ★ 回填：t_true_rows／n_batches_100k／last_batch_rows_100k／n_batches_10k／last_batch_rows_10k
--     五数须回填 #133 之【规模警示】与两分批版之①注，以实测取代上界。
--   ★ n_member_pairs_total 系 T-01／T-04／T-05 之共现零模型【分母基数】——全窗同局共现之总对次。
--     无此数，「两人同局 N 次」之显著性无从判定（现状是有分子无分母）。
--   ★ n_rounds_multi_dealer > 0 者须查：同一局键出现多个荷官，或系换班切局，或系桌台字段污染，
--     与 G3 十三张桌（900~913）之疑似电子桌占位标识同属待裁项。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §2 口径漏斗 · 有锚阶梯（选跑 · 全窗 · 回一行 · L1 对锚 #014，L6 对锚 §1）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【本节之立意】无锚之漏斗只是数字，有锚方为证据。L1 之二值须与 #014 DICT_01b_roundkey_card.csv
--   之落盘数**逐位相等**；相等即证本档之窗口、产品、快照、category 四锁与 132 件同源，
--   其后逐闸之减数方可信。末端 L6 须与 §1 之 t_true_rows 逐位相等（同一口径两法互证）。
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)          AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.sync_time <= '2026-08-27 09:00:00'
),
f AS (
  SELECT r.rn,
         r.category,
         r.bet38,
         CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT)                            AS member_id,
         CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8))                     AS fx,
         CONCAT_WS('|', TRIM(r.bet03), TRIM(r.bet04), TRIM(r.bet39))          AS round_key,
         COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid)                     AS test_aid
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(r.bet18), '') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(r.bet19), '') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(r.bet20), '') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(r.bet21), '') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(r.bet22), '') AS BIGINT)
)
SELECT 'RK01 §2 口径漏斗 · 有锚阶梯 · 全窗'                                                        AS probe,
       -- L0 三锁：窗口 ＋ 产品 ＋ 快照（rk 之 WHERE 已施）
       COUNT(*)                                                                                    AS l0_rows,
       COUNT(DISTINCT round_key)                                                                   AS l0_nd_round_key,
       -- L1 四锁：＋ TRIM(category)='1' —— ★ 须等于 #014：rows 125,649,147 ／ 局键 6,048,725
       SUM(CASE WHEN TRIM(category) = '1' THEN 1 ELSE 0 END)                                       AS l1_rows_anchor014,
       COUNT(DISTINCT CASE WHEN TRIM(category) = '1' THEN round_key END)                           AS l1_nd_round_key_anchor014,
       -- L1b 同上但用 #133 之写法 category='1'（无 TRIM）—— 两者应相等；不等即 category 含空白
       SUM(CASE WHEN category = '1' THEN 1 ELSE 0 END)                                             AS l1b_rows_no_trim,
       -- L2 五锁：＋ 去重 rn=1 —— ★ 局键数应与 L1 相等（去重不减局）
       SUM(CASE WHEN TRIM(category) = '1' AND rn = 1 THEN 1 ELSE 0 END)                            AS l2_rows_dedup,
       COUNT(DISTINCT CASE WHEN TRIM(category) = '1' AND rn = 1 THEN round_key END)                AS l2_nd_round_key,
       -- L3 ＋ bet38='N'（剔重对）
       SUM(CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' THEN 1 ELSE 0 END)                                   AS l3_rows,
       COUNT(DISTINCT CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' THEN round_key END)                                  AS l3_nd_round_key,
       -- L4 ＋ 剔测试线
       SUM(CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' AND test_aid IS NULL THEN 1 ELSE 0 END)              AS l4_rows,
       COUNT(DISTINCT CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' AND test_aid IS NULL THEN round_key END)             AS l4_nd_round_key,
       -- L5 ＋ bet05>0（会员号为正）
       SUM(CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' AND test_aid IS NULL
                 AND member_id > 0 THEN 1 ELSE 0 END)                                              AS l5_rows,
       COUNT(DISTINCT CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' AND test_aid IS NULL
                 AND member_id > 0 THEN round_key END)                                             AS l5_nd_round_key,
       -- L6 ＋ bet11>0（汇率为正）—— ★ 须等于 §1 之 t_true_rows
       SUM(CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' AND test_aid IS NULL
                 AND member_id > 0 AND fx > 0 THEN 1 ELSE 0 END)                                   AS l6_rows,
       COUNT(DISTINCT CASE WHEN TRIM(category) = '1' AND rn = 1
                 AND UPPER(TRIM(bet38)) = 'N' AND test_aid IS NULL
                 AND member_id > 0 AND fx > 0 THEN round_key END)                                  AS l6_nd_round_key_eq_t_true
FROM f;
--   ★ 判读一（对锚 #014）：l1_rows_anchor014 须 = 125,649,147；l1_nd_round_key_anchor014 须 = 6,048,725。
--     二者皆合 ⇒ 本档四锁与 132 件同源，其后减数可信；任一不合 ⇒ 先查窗口／产品／快照／category 之写法，
--     **不得**径改本档以迁就（改之即与 132 件脱钩）。
--   ★ 判读二（去重不减局）：l2_nd_round_key 须 = l1_nd_round_key_anchor014。若小于，则有整局之注单
--     全数落于 rn>1，须逐 bet01 查其版本史，属数据异常而非闸之误。
--   ★ 判读三（末端互证）：l6_nd_round_key_eq_t_true 须与 §1 之 t_true_rows 逐位相等。
--   ★ 判读四（写法之别）：l1b_rows_no_trim 与 l1_rows_anchor014 应相等。不等即 category 栏含前后空白，
--     则 #014 之 TRIM(category) 与 #133 之 category 两写法所选母体不同，须立案（口径写法不一致）。
--   ★ 逐闸减数 = 前一级 nd_round_key − 本级 nd_round_key，即该闸所剔之局数，供 §1 之
--     reduced_by_locks_4to6 分解归因。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §3 形态探针 · 每局人数分位与多荷官局（选跑 · 全窗六锁 · 回一行 · 与 #118 对照）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)          AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.sync_time <= '2026-08-27 09:00:00'
),
base AS (
  SELECT CONCAT_WS('|', TRIM(r.bet03), TRIM(r.bet04), TRIM(r.bet39)) AS round_key,
         CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT)                   AS member_id,
         TRIM(r.eid)                                                 AS dealer_id
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(r.bet18), '') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(r.bet19), '') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(r.bet20), '') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(r.bet21), '') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(r.bet22), '') AS BIGINT)
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
    AND CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0
),
g AS (
  SELECT round_key,
         COUNT(DISTINCT member_id) AS n_members,
         COUNT(DISTINCT dealer_id) AS n_dealer_id,
         COUNT(*)                  AS n_bets
  FROM base
  GROUP BY round_key
)
SELECT 'RK01 §3 形态 · 全窗六锁 · 对照 #118 Z08'                              AS probe,
       COUNT(*)                                                                 AS n_rounds,
       SUM(CASE WHEN n_members = 1 THEN 1 ELSE 0 END)                           AS n_rounds_solo,
       SUM(CASE WHEN n_members BETWEEN 2 AND 4 THEN 1 ELSE 0 END)               AS n_rounds_2_4,
       SUM(CASE WHEN n_members BETWEEN 5 AND 9 THEN 1 ELSE 0 END)               AS n_rounds_5_9,
       SUM(CASE WHEN n_members >= 10 THEN 1 ELSE 0 END)                         AS n_rounds_ge10,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.50)                       AS p50_members,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.90)                       AS p90_members,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.99)                       AS p99_members,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.999)                      AS p999_members,
       256                                                                      AS ref118_max_members,
       93.225                                                                   AS ref118_p999_members,
       MAX(n_members)                                                           AS max_members,
       MAX(n_bets)                                                              AS max_bets_in_round,
       414                                                                      AS ref118_max_bets_in_round,
       SUM(CASE WHEN n_dealer_id = 0 THEN 1 ELSE 0 END)                         AS n_rounds_dealer_null,
       SUM(CASE WHEN n_dealer_id = 1 THEN 1 ELSE 0 END)                         AS n_rounds_dealer_1,
       SUM(CASE WHEN n_dealer_id > 1 THEN 1 ELSE 0 END)                         AS n_rounds_dealer_multi,
       MAX(n_dealer_id)                                                         AS max_dealer_in_round
FROM g;
--   ★ 判读（对照 #118 Z08_roundkey_integrity.csv · v2.0.1 斧正）：Z08 系【二锁】（bet02＋快照，
--     **无 dt 窗口**，注单 143,085,880 行、局键 6,919,057），其值系**更宽口径**（含窗外历史）。
--     ┌ **极值**（max_members／max_bets_in_round）：子集之极值必 **≤** 全集，故本节须 ≤ 256／414。
--     │   若本节反大，即口径或去重有误，须停跑查因。
--     └ **分位数**（p50／p90／p99／p999）：**不受此约束**。分位数于子集非单调——剔去一批小局，
--         余者之分位即上移。故本节 p999 略高于 Z08 之 93.225 属正常，**不得**据以判误。
--         （v1.x～v2.0.0 之判读误将分位与极值同论，已于 2026-09-03 实测后斧正。）
--     ⛔ 二者不可互引为同一口径之数——引用时须随附口径标注。
--   ★ n_rounds_dealer_null > 0 者：eid 为空之局；须与 #076 S02_dealer_score 之荷官名册对盘后方可解释。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【实测存档】2026-09-03 · StarRocks 实跑回值（供日后重跑逐位对账；数据未变则回值须逐位相同）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §0 连线自检（0.466s）：n_agent_rows_scanned 215 ／ nd_test_agent_id 215（测试线代理名册基数）
--
-- §1 主探针（10.685s）★ 判读一/二/三 全数 PASS
--   t_true_rows 6,048,562 ＝ nd_round_key 6,048,562        ← #133 之观测值总数（定案）
--   upper_bound_from_014 6,048,725 ／ reduced_by_locks_4to6 163 ／ pct_of_upper_bound 99.9973%
--   n_batches_100k 61 ／ last_batch_rows_100k 48,562
--   n_batches_10k 605 ／ last_batch_rows_10k  8,562
--   n_bets_total 124,713,543 ／ avg_bets_per_round 20.6187 ／ avg_members_per_round 15.1447
--   nd_table 30 ／ nd_table_shoe 123,357 ／ nd_biz_date 139 ／ 2026-03-21 ~ 2026-08-06
--   n_rounds_multiparty 5,863,816 ／ n_member_pairs_total 1,181,326,647 ／ n_rounds_multi_dealer 6,713
--   max_members_in_round 256
--
-- §2 口径漏斗（22.674s）★ L1 对锚 #014 逐位相等；L6 对锚 §1 逐位相等
--   L0 三锁          125,654,711 行 ／ 6,048,790 局
--   L1 ＋category    125,649,147 行 ／ 6,048,725 局   ← ★ 与 #014 逐位相等（125,649,147／6,048,725）
--   L1b 无 TRIM      125,649,147 行                  ← 与 L1 相等 ⇒ category 栏无前后空白
--   L2 ＋rn=1        124,726,293 行 ／ 6,048,725 局   ← 剔 922,854 行、0 局
--   L3 ＋bet38='N'   124,725,280 行 ／ 6,048,562 局   ← 剔 1,013 行、163 局
--   L4 ＋剔测试线     124,713,543 行 ／ 6,048,562 局   ← 剔 11,737 行、0 局
--   L5 ＋bet05>0     124,713,543 行 ／ 6,048,562 局   ← 剔 0 行、0 局（VACUOUS_FILTER）
--   L6 ＋bet11>0     124,713,543 行 ／ 6,048,562 局   ← 剔 0 行、0 局（VACUOUS_FILTER）
--
-- §3 形态探针（9.741s）
--   n_rounds 6,048,562 ／ 独玩 184,746（3.05%）／ 2~4 人 903,091 ／ 5~9 人 1,509,720 ／ ≥10 人 3,451,005（57.05%）
--   P50 11 ／ P90 32 ／ P99 63 ／ P999 94 ／ max_members 256 ／ max_bets_in_round 414
--   荷官：为空 0 局 ／ 单荷官 6,041,849（99.889%）／ 多荷官 6,713（0.111%）／ 单局最多 3
--
-- 【实测所立之三事】
--   ① #133 之观测值 ＝ 6,048,562，分批数 61（100k）／605（10k），已回填三版 #133 之注记。
--   ② VACUOUS_FILTER：bet05>0 与 bet11>0 于本窗剔 0 行 —— 恒真闸，不得据以宣称数据洁净。
--   ③ 多荷官局 6,713（0.111%）确存，须辨『换班切局』抑或『字段污染』；未辨明前 dealer_id_min
--      不得作荷官归属之唯一依据（承 P-17）。
