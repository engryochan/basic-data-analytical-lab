-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- RK01_行数实测探针 v1.1.0   [#133 RK01_round_fact.csv 之观测值实测 · 只读 · 不落盘]
-- 立册 : 2026-09-03        Owner : Ryo Eng        配套 : a168_SQL总包_v12_0_0_HF9g-P5D_*_OPT.sql #133
-- 变更 : 1.1.0（2026-09-03）新增 §0 冒烟测试（单日 · 秒级）与【疑难排解】一节 —— 承先生实跑所遇
--        「400 Bad Request: The CSRF tokens do not match ／ Issue 1011」。该错非 SQL 之误，详见下节。
--        §1～§3 之判据与 SQL 一字未改。
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【本件之问】#133 一共有多少观测值？——即 RK01_round_fact.csv 之【行数 T_true】。
--   #133 之粒度为 round_key（= bet03|bet04|bet39），故 T_true = 六锁过滤后 round_key 之相异数。
--   ★ 总包 #133 注记「预期 6,048,725 行」系承口诀之旧测，**非本包六锁下之实测**。
--     两者口径不同（旧测未必含 category='1' / bet38='N' / 测试线剔除 / bet05>0 / bet11>0），
--     故落盘前须以本件回值为准；若两数不符，以本件为真，并回改 #133 之注记与分批数。
--
-- 【口径六锁 · 与 #133 逐字同一，勿改】
--   ① 窗口 dt >= '2026-03-21' AND dt < '2026-08-07'   ② 产品 bet02 = '101'
--   ③ 快照 sync_time <= '2026-08-27 09:00:00'          ④ 去重 PARTITION BY bet01 取 rn = 1
--   ⑤ 基础闸 category='1' · UPPER(bet38)='N' · 五级代理左连取 NULL（剔测试线）· bet05>0 · bet11>0
--   ⑥ 归一 一切金额除以 bet11（本件不出金额，故⑥于此只作口径声明）
--
-- 【禁令遵循】只用行注释（分号／斜线在块注释内会被误判为语句终止）；一切 ID 比较 CAST 至 BIGINT；
--   一切除法以 NULLIF 护零；NULL ≠ 0，未观测者留 NULL 不写 0；禁 OFFSET；禁以 DATE(bet08) 切日。
--
-- 【用法】三节各为独立一句，可分开跑。§1 必跑；§2／§3 选跑。
--   §1 主探针   —— 回一行：T_true、分批数、局内人数与对次之总量
--   §2 口径漏斗 —— 回一行：逐闸剩余注单数，用以定位「行数不符预期」之闸在哪一层
--   §3 形态探针 —— 回一行：每局人数分位、多荷官局数（#133 注记之待裁项）
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
--     ③ 若频发，改以 MySQL 协议直连 StarRocks FE（预设 9030 埠）跑本档，绕开 Superset 之 Web 层：
--          mysql -h <FE_HOST> -P 9030 -u <USER> -p -e "source 函数/RK01_行数实测探针_v1_0_0.sql"
--        ★ StarRocks 兼容 MySQL 协议，故 DBeaver／Navicat／mysql CLI 皆可直连。
--   ⛔ 切勿因此错而改动 SQL —— 改码治不了会话之病，反致口径漂移。
--
-- ★ 症状二：「Only single queries supported」／只跑了第一节
--   判定：Superset SQL Lab 预设禁多语句。本档三节以分号分隔，**须一次只贴一节**（本档设计即如此）。
--
-- ★ 症状三：查询逾时（Query timeout／Async queries）
--   判定：§1～§3 皆全量扫 ods_a168_bet02（窗内约 1.24 亿注单），分钟级属正常，非卡死。
--   解法：先跑 §0 冒烟测试（单日，秒级）确认 SQL 可跑；再于 Superset 开启异步查询（Async）
--         或调高 SQLLAB_TIMEOUT／SQLLAB_ASYNC_TIME_LIMIT_SEC；或改走 MySQL 直连（无 Web 逾时）。
--
-- ★ 症状四：语法报错
--   判定：本档字段型别已对 数据表/DICT_ALL_columns.csv 逐栏核实——ods_a168_bet02 之
--         bet01/bet03/bet04/bet05/bet09/bet11/bet13/bet38/bet39/validbet/category/eid 皆 varchar(65533)，
--         dt 为 date、sync_time 为 datetime；ods_a168_agent 之 age001/age022 皆 varchar(65533)。
--         故 TRIM()／CAST()／字串比较（age022 = '1'）皆型别正确。若仍报错，请回报**完整错文**再诊。
-- ══════════════════════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §0 冒烟测试 · 单日（选跑 · 秒级回一行）—— 只为证「SQL 本身可跑」，不作口径结论
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【用途】遇客户端异常（CSRF／逾时／连线断）时，先跑本节：
--   · 秒级回值 ⇒ SQL 与权限皆无碍，问题在会话或逾时，回上节依序排解；
--   · 本节亦报错 ⇒ 方为 SQL 或权限之误，据错文再诊。
-- 【警示】本节只取 2026-03-21 单日，其 t_true_rows_1d **不可**充作 #133 之观测值总数。
--   全窗总数一律以 §1 为准。
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (PARTITION BY b.bet01 ORDER BY b.sync_time DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt = '2026-03-21'
    AND b.bet02 = '101'
    AND b.sync_time <= '2026-08-27 09:00:00'
),
base AS (
  SELECT CONCAT_WS('|', TRIM(r.bet03), TRIM(r.bet04), TRIM(r.bet39)) AS round_key,
         CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT)                   AS member_id
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
)
SELECT 'RK01 冒烟测试 · 单日 2026-03-21 · 不可作全窗结论'  AS probe,
       COUNT(DISTINCT round_key)                          AS t_true_rows_1d,
       COUNT(*)                                           AS n_bets_1d,
       COUNT(DISTINCT member_id)                          AS nd_member_1d
FROM base;
--   ★ 回值即证：连线通、权限足、语法对、口径六锁可执行。此后 §1 若再遇 400／逾时，一律属客户端。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §1 主探针 · T_true 与分批数（必跑 · 回一行）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (PARTITION BY b.bet01 ORDER BY b.sync_time DESC) AS rn
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
SELECT 'RK01_round_fact · #133 · 六锁实测'                                      AS probe,
       COUNT(*)                                                                 AS t_true_rows,
       COUNT(DISTINCT g.round_key)                                              AS nd_round_key,
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
--   ★ 判读：t_true_rows ＝ nd_round_key 须相等（后三栏系 round_key 之分量，不等即 TRIM 口径有异，须查）。
--   ★ t_true_rows 即 #133 之观测值总数；n_batches_100k／n_batches_10k 即两分批版应跑之批数，
--     须回填 #133 注记「预期共 NN 批，末批 NN 行」；末批行数由 last_batch_rows_* 直接给出。
--   ★ n_member_pairs_total 系 T-01／T-04／T-05 之共现零模型【分母基数】——全窗同局共现之总对次。
--     无此数，「两人同局 N 次」之显著性无从判定（现状是有分子无分母）。
--   ★ n_rounds_multi_dealer > 0 者须查：同一局键出现多个荷官，或系换班切局，或系桌台字段污染，
--     与 G3 十三张桌（900~913）之疑似电子桌占位标识同属待裁项。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §2 口径漏斗 · 逐闸剩余注单数（选跑 · 回一行 · 用以定位行数不符预期之成因）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (PARTITION BY b.bet01 ORDER BY b.sync_time DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.sync_time <= '2026-08-27 09:00:00'
),
f AS (
  SELECT r.rn,
         r.category,
         r.bet38,
         CAST(NULLIF(TRIM(r.bet05), '') AS BIGINT)              AS member_id,
         CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8))       AS fx,
         CONCAT_WS('|', TRIM(r.bet03), TRIM(r.bet04), TRIM(r.bet39)) AS round_key,
         COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid)       AS test_aid
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(r.bet18), '') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(r.bet19), '') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(r.bet20), '') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(r.bet21), '') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(r.bet22), '') AS BIGINT)
)
SELECT 'RK01 口径漏斗 · 逐闸剩余注单'                                            AS probe,
       COUNT(*)                                                                                    AS s0_window_product_snapshot,
       SUM(CASE WHEN rn = 1 THEN 1 ELSE 0 END)                                                     AS s1_dedup_rn1,
       SUM(CASE WHEN rn = 1 AND category = '1' THEN 1 ELSE 0 END)                                  AS s2_category1,
       SUM(CASE WHEN rn = 1 AND category = '1' AND UPPER(TRIM(bet38)) = 'N' THEN 1 ELSE 0 END)      AS s3_bet38_N,
       SUM(CASE WHEN rn = 1 AND category = '1' AND UPPER(TRIM(bet38)) = 'N'
                 AND test_aid IS NULL THEN 1 ELSE 0 END)                                            AS s4_non_test_line,
       SUM(CASE WHEN rn = 1 AND category = '1' AND UPPER(TRIM(bet38)) = 'N'
                 AND test_aid IS NULL AND member_id > 0 THEN 1 ELSE 0 END)                          AS s5_member_gt0,
       SUM(CASE WHEN rn = 1 AND category = '1' AND UPPER(TRIM(bet38)) = 'N'
                 AND test_aid IS NULL AND member_id > 0 AND fx > 0 THEN 1 ELSE 0 END)               AS s6_fx_gt0,
       COUNT(DISTINCT CASE WHEN rn = 1 AND category = '1' AND UPPER(TRIM(bet38)) = 'N'
                 AND test_aid IS NULL AND member_id > 0 AND fx > 0 THEN round_key END)              AS s6_nd_round_key,
       COUNT(DISTINCT round_key)                                                                    AS s0_nd_round_key
FROM f;
--   ★ 判读：s6_nd_round_key 须与 §1 之 t_true_rows 逐位相等（同一口径两法互证）。
--   ★ s0_nd_round_key 与 s6_nd_round_key 之差，即六锁所剔之局数——若差额过大，须逐闸复核而非改闸。


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- §3 形态探针 · 每局人数分位与多荷官局（选跑 · 回一行）
-- ══════════════════════════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001), '') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.*,
         ROW_NUMBER() OVER (PARTITION BY b.bet01 ORDER BY b.sync_time DESC) AS rn
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
         COUNT(DISTINCT dealer_id) AS n_dealer_id
  FROM base
  GROUP BY round_key
)
SELECT 'RK01 形态 · 每局人数分位'                                               AS probe,
       COUNT(*)                                                                 AS n_rounds,
       SUM(CASE WHEN n_members = 1 THEN 1 ELSE 0 END)                           AS n_rounds_solo,
       SUM(CASE WHEN n_members BETWEEN 2 AND 4 THEN 1 ELSE 0 END)               AS n_rounds_2_4,
       SUM(CASE WHEN n_members BETWEEN 5 AND 9 THEN 1 ELSE 0 END)               AS n_rounds_5_9,
       SUM(CASE WHEN n_members >= 10 THEN 1 ELSE 0 END)                         AS n_rounds_ge10,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.50)                       AS p50_members,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.90)                       AS p90_members,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.99)                       AS p99_members,
       PERCENTILE_APPROX(CAST(n_members AS DOUBLE), 0.999)                      AS p999_members,
       MAX(n_members)                                                           AS max_members,
       SUM(CASE WHEN n_dealer_id = 0 THEN 1 ELSE 0 END)                         AS n_rounds_dealer_null,
       SUM(CASE WHEN n_dealer_id = 1 THEN 1 ELSE 0 END)                         AS n_rounds_dealer_1,
       SUM(CASE WHEN n_dealer_id > 1 THEN 1 ELSE 0 END)                         AS n_rounds_dealer_multi,
       MAX(n_dealer_id)                                                         AS max_dealer_in_round
FROM g;
--   ★ 判读：口诀旧测「单局最大会员 256 · P999 = 93.2」；若本件 max_members／p999_members 与之相去甚远，
--     系口径差（旧测未剔测试线与非一般注单），非数据变动——以本件为准，并回改 #133 之注记。
--   ★ n_rounds_dealer_null > 0 者：eid 为空之局；须与 #076 S02_dealer_score 之荷官名册对盘后方可解释。
