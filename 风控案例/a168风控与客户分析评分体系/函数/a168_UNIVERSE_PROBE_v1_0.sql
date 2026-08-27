-- ==============================================================================================
--  UNIVERSE-PROBE v1.0  ·  a168 风控项目 · 宇宙容量与闸门影响测量件
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a · 30,896 行 · CRLF · UTF-8
--  本件所有 predicate 均自上述源码【逐行抄录】，未凭记忆重写。每节均注明源码行号。
--  ----------------------------------------------------------------------------------------
--  性质：★ 测量件，不是裁决件 ★
--        只回答「现有 predicate 逐级筛选后宇宙剩多少、闸门砍掉多少、放大多少倍」。
--        不得在本件内决定「应保留多少会员」「应改用 P50/P70」「应设 >= N」。
--        任何阈值裁定一律留给 UNIVERSE-PROBE-GATE，由先生批准后另立工单。
--  ----------------------------------------------------------------------------------------
--  执行纪律（本件专属，务必逐条遵守）
--    1. 先在【同一标签页】逐行单跑 Z00C_溢写节流_逐行单跑.sql，会话参数不跨标签页。
--    2. 串行执行，一次只跑一条，禁止多标签并行（BE 内存共享）。
--    3. 复制时只选 SELECT ... ; 为止，分号之后一个字都不要带。跑前按 Esc 清除高亮选区。
--    4. 本件全部只读：无建表、无写入、无 INSERT/UPDATE/DELETE。
--    5. 本件禁用 ROW_NUMBER / 任何窗口函数、禁用 ORDER BY、禁用 OFFSET、禁用 SELECT *。
--    6. 「轻量」不等于「零成本」：仍会扫描约 1.26 亿行。若某条超过 10 分钟未返回，
--       立即取消并回报，不要重试、不要开第二个标签页。
--    7. 每条跑完请记录：耗时、query_id、返回值。任一条失败即停手回报，不要跳过继续。
--  ----------------------------------------------------------------------------------------
--  ★ 去重口径的等价替换（本件唯一的方法学变通，须先生知悉）
--    生产件用 ROW_NUMBER() OVER (PARTITION BY bet01 ORDER BY updatetime,sync_time,dt) 取 rn=1 去重。
--    窗口函数是 BE 内存事故的主因之一，故本件一律以 COUNT(DISTINCT b.bet01) 替代。
--    等价性依据：Gate-00-B 已 PROVEN —— n_full = n_bet01 = 124,731,833（24 业务字段全比对），
--    即 922,878 行重复是【纯副本】。既为纯副本，任何作用于业务字段的 predicate 对同一 bet01
--    的各副本给出相同结果，故「先过滤再 COUNT(DISTINCT bet01)」与「先取 rn=1 再 COUNT(*)」
--    在【计数】意义上逐位等价。
--    ★ 等价性的边界（必须明示）：Gate-00-B 比对的是业务字段，不含 dt / sync_time / updatetime。
--      故本替换仅对【计数】成立；凡涉及逐行取 dt（如 bet_date 归属）的口径，不得援引本替换。
--      本件不产出任何逐行 dt 归属量，故不受此限。
--  ----------------------------------------------------------------------------------------
--  已知答案锚（自证用，任一不符即判集群返回不完整，立即停手）
--    U0 n_rows_dedup = 124,731,833   ·  U0 n_members = 723,557
--    G075 闸后主体数 = 161,156        （HF8 实测 CSV：161,156 行 · MD5 fa0ac8affc40a9261d5a7c87dd709345）
--    G080 闸后主体数 = 278,729        （HF8 实测 CSV：278,729 行 · MD5 a5503c620b0f500bd0c7cc942b3b5437）
-- ==============================================================================================


-- ==============================================================================================
--  §U · 宇宙阶梯：现有 predicate 逐级筛掉多少
--  ----------------------------------------------------------------------------------------
--  每条只有一个目的、只出两个数（去重注单数 / 去重会员数），不做多路 COUNT DISTINCT。
--  多路 distinct 是 StarRocks 的内存杀手，故此处宁可多扫几遍，也不合并成一条。
--  阶梯是【严格递减】的：U0 >= U1 >= ... >= U5。任一级反增即判 predicate 抄错。
-- ==============================================================================================


-- -- U0 -- 基础窗：仅分区窗 + 百家乐。源码 #075 L18264。已知答案：124,731,833 / 723,557
SELECT COUNT(DISTINCT b.bet01)                                            AS u0_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u0_members
FROM ods_mariadb_2b.ods_a168_bet02 b
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101';


-- -- U1 -- + 有效注单哨兵（category='1' 且 bet38='N'）。源码 #075 L18274
SELECT COUNT(DISTINCT b.bet01)                                            AS u1_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u1_members
FROM ods_mariadb_2b.ods_a168_bet02 b
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N';


-- -- U2 -- + 会员身份哨兵（bet05 > 0）。源码 #075 L18275
SELECT COUNT(DISTINCT b.bet01)                                            AS u2_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u2_members
FROM ods_mariadb_2b.ods_a168_bet02 b
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0;


-- -- U3 -- + 汇率哨兵（bet11 > 0）。源码 #075 L18276。已知 bet11 缺失或 <=0 者为 0 笔，故 U3 应 = U2
SELECT COUNT(DISTINCT b.bet01)                                            AS u3_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u3_members
FROM ods_mariadb_2b.ods_a168_bet02 b
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
  AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0;


-- -- U4 -- + bet08 非空。源码 #075 L18277
--    ★ 本条的差值是【本次探查最关键的未知数之一】：
--      bet08 非空究竟是「清洗」（脏值剔除）还是「宇宙门」（删主体），
--      取决于它砍掉多少会员。砍注单不砍会员 => 清洗；砍掉整批会员 => 宇宙门，须重裁。
SELECT COUNT(DISTINCT b.bet01)                                            AS u4_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u4_members
FROM ods_mariadb_2b.ods_a168_bet02 b
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
  AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  AND NULLIF(TRIM(b.bet08),'') IS NOT NULL;


-- -- U5 -- + 五级代理测试线剔除。源码 #075 L18278（五级 LEFT JOIN，与生产件逐字同构）
--    ★ U5 即 #075 / #057 / #080 / #081 / #110 五件在【移除宇宙门后】的合法宇宙。
SELECT COUNT(DISTINCT b.bet01)                                            AS u5_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u5_members
FROM ods_mariadb_2b.ods_a168_bet02 b
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t1
       ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t2
       ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t3
       ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t4
       ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t5
       ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
  AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
  AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL;


-- -- U5N -- 同 U5 但【不含 bet08 非空】。这是 #046 / #049 / #064 / #083 / #084 的口径。
--    ★ 全包 14 件 G-UNIVERSE 并非同一套清洗 predicate，故宇宙不止一个。
--      U5 与 U5N 的差值即「bet08 口径分歧」的规模，须一并留档。
SELECT COUNT(DISTINCT b.bet01)                                            AS u5n_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS u5n_members
FROM ods_mariadb_2b.ods_a168_bet02 b
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t1
       ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t2
       ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t3
       ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t4
       ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
LEFT JOIN (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
           FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1') t5
       ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
  AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL;


-- ==============================================================================================
--  §G · 十四件 G-UNIVERSE 宇宙门的逐件影响
--  ----------------------------------------------------------------------------------------
--  每条一次算齐四数：闸前主体数、闸后主体数、闸前注单数、闸后注单数。
--  主体放大倍数 = groups_before / groups_after ； 注单放大倍数 = rows_before / rows_after。
--  ★ 生产件的 HAVING COUNT(*) 在此一律替换为 COUNT(DISTINCT bet01)（见文件头等价性说明）。
--  ★ 本节只测量，不裁定阈值。
-- ==============================================================================================


-- -- G075 -- #075 S01_player_score ★ 主件。粒度 member_id，闸 COUNT(DISTINCT round_key) >= 30
--    源码：清洗 L18274-18278 · round_key L18283 · GROUP BY L18369 · HAVING L18370
--    已知答案锚：groups_after 应 = 161,156
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (
  SELECT member_id,
         COUNT(DISTINCT round_key)                                        AS n_gate,
         COUNT(DISTINCT bet01)                                            AS n_rows
  FROM base
  GROUP BY member_id
)
SELECT COUNT(*)                                                           AS groups_before,
       SUM(CASE WHEN n_gate >= 30 THEN 1 ELSE 0 END)                      AS groups_after,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_gate >= 30 THEN n_rows ELSE 0 END)                 AS rows_after,
       MIN(n_gate)                                                        AS gate_min,
       MAX(n_gate)                                                        AS gate_max
FROM g;


-- -- G080 -- #080 S05_member_month_panel。粒度 member_id × 月，闸 COUNT(DISTINCT bet01) >= 30
--    源码：清洗 L19450-19454 · GROUP BY L19487 · HAVING L19488
--    已知答案锚：groups_after 应 = 278,729
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         DATE_TRUNC('month', b.dt)                                        AS ym
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (SELECT member_id, ym, COUNT(DISTINCT bet01) AS n_rows FROM base GROUP BY member_id, ym)
SELECT COUNT(*)                                                           AS groups_before,
       SUM(CASE WHEN n_rows >= 30 THEN 1 ELSE 0 END)                      AS groups_after,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_rows >= 30 THEN n_rows ELSE 0 END)                 AS rows_after,
       COUNT(DISTINCT member_id)                                          AS members_before
FROM g;


-- -- G057 -- #057 P_player_month。粒度 member_id × 月，闸 COUNT(DISTINCT round_key) >= 30
--    源码：清洗 L13570-13574（与 #075 同套）· round_key L13579 · HAVING L13601
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         DATE_TRUNC('month', b.dt)                                        AS ym,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (SELECT member_id, ym, COUNT(DISTINCT round_key) AS n_gate, COUNT(DISTINCT bet01) AS n_rows
      FROM base GROUP BY member_id, ym)
SELECT COUNT(*)                                                           AS groups_before,
       SUM(CASE WHEN n_gate >= 30 THEN 1 ELSE 0 END)                      AS groups_after,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_gate >= 30 THEN n_rows ELSE 0 END)                 AS rows_after,
       COUNT(DISTINCT member_id)                                          AS members_before
FROM g;


-- -- G083 -- #083 T02_daily_roi。粒度 member_id，闸 COUNT(DISTINCT bet_date) >= 20
--    源码：清洗 L20212-20215（★ 无 bet08 条件）· HAVING L20219
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         b.dt                                                             AS bet_date
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (SELECT member_id, COUNT(DISTINCT bet_date) AS n_gate, COUNT(DISTINCT bet01) AS n_rows
      FROM base GROUP BY member_id)
SELECT COUNT(*)                                                           AS groups_before,
       SUM(CASE WHEN n_gate >= 20 THEN 1 ELSE 0 END)                      AS groups_after,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_gate >= 20 THEN n_rows ELSE 0 END)                 AS rows_after
FROM g;


-- ==============================================================================================
--  §GB · 会员粒度、闸为「注单数」的九件，可用同一条查询一次量齐
--  ----------------------------------------------------------------------------------------
--  这九件的宇宙门形式统一为：GROUP BY 会员 HAVING COUNT(*) >= T。
--  其清洗 predicate 分两套（含/不含 bet08），故拆成 GB-A 与 GB-B 两条。
--  一条查询同时给出 T = 30 / 100 / 300 三个门槛的闸后规模，避免为每件各扫一遍。
--  T=30  → #044(pid) #081 #110
--  T=100 → #046 #049 #050 #064 #084
--  T=300 → #069（但 #069 另有特殊性，见 §W2）
-- ==============================================================================================


-- -- GB-A -- 清洗口径【不含 bet08】：#046 #049 #064 #084 及 #044 #050 的近似
--    ★ 注意：#044 的 grain 用 bet05，另有 bet03/bet04 非空条件；#050 的闸是 SUM(n_bets)，
--      在会员粒度上等价于 COUNT(*)。两件的细微差异记入 §W3，不在本条内混算。
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (SELECT member_id, COUNT(DISTINCT bet01) AS n_rows FROM base GROUP BY member_id)
SELECT COUNT(*)                                                           AS members_before,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_rows >=  30 THEN 1 ELSE 0 END)                     AS members_ge30,
       SUM(CASE WHEN n_rows >=  30 THEN n_rows ELSE 0 END)                AS rows_ge30,
       SUM(CASE WHEN n_rows >= 100 THEN 1 ELSE 0 END)                     AS members_ge100,
       SUM(CASE WHEN n_rows >= 100 THEN n_rows ELSE 0 END)                AS rows_ge100,
       SUM(CASE WHEN n_rows >= 300 THEN 1 ELSE 0 END)                     AS members_ge300,
       SUM(CASE WHEN n_rows >= 300 THEN n_rows ELSE 0 END)                AS rows_ge300
FROM g;


-- -- GB-B -- 清洗口径【含 bet08 非空】：#081 #110 及 #075 家族的会员基数对照
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (SELECT member_id, COUNT(DISTINCT bet01) AS n_rows FROM base GROUP BY member_id)
SELECT COUNT(*)                                                           AS members_before,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_rows >=  30 THEN 1 ELSE 0 END)                     AS members_ge30,
       SUM(CASE WHEN n_rows >=  30 THEN n_rows ELSE 0 END)                AS rows_ge30,
       SUM(CASE WHEN n_rows >= 100 THEN 1 ELSE 0 END)                     AS members_ge100,
       SUM(CASE WHEN n_rows >= 100 THEN n_rows ELSE 0 END)                AS rows_ge100,
       SUM(CASE WHEN n_rows >= 300 THEN 1 ELSE 0 END)                     AS members_ge300,
       SUM(CASE WHEN n_rows >= 300 THEN n_rows ELSE 0 END)                AS rows_ge300
FROM g;


-- ==============================================================================================
--  §W · 三条警示查询：本次核对源码时发现的、参考裁示未涵盖的异常
-- ==============================================================================================


-- -- W1 -- #065 R01_late_shoe_w2 的观察窗与全包【不同】
--    源码 L15712：dt >= '2026-08-07' AND dt < '2026-08-20'
--    即 #065 用的是主窗【之后】的 13 天，属 walk-forward 样本外窗，
--    方向正确（以过去预测未来，非以未来解释过去），但：
--      ① 它不属于 U0~U5 任何一级宇宙，绝不可并入主窗口径合并统计；
--      ② 其宇宙门 COUNT(*) >= 100 是在【13 天】窗上设的，与主窗 139 天的 100 不可比。
--    本条只测该窗的基础规模，供 UNIVERSE-PROBE-GATE 单独裁定。
SELECT COUNT(DISTINCT b.bet01)                                            AS w2win_rows_dedup,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS w2win_members,
       MIN(b.dt)                                                          AS dt_min,
       MAX(b.dt)                                                          AS dt_max
FROM ods_mariadb_2b.ods_a168_bet02 b
WHERE b.dt >= '2026-08-07' AND b.dt < '2026-08-20'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0;


-- -- W2 -- #069 R02_same_table 的 q 侧【没有测试线剔除】
--    源码 L16765-16776：mr CTE 直接自 bet02 取数，仅有 category='1' / bet38='N' / bet05>0，
--    既无 rn=1（但有 SELECT DISTINCT，对本粒度等效去重），亦【无五级代理测试线剔除】。
--    ⇒ 11,739 笔测试线注单会进入 #069。本条量其规模。
--    另：源码 L16778-16781 自述门槛由 100 提至 300 是【为降内存】，非业务推导 ——
--        这是「资源约束改写业务判据」的实证案例，须于 UNIVERSE-PROBE-GATE 单独裁定。
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1')
SELECT COUNT(DISTINCT b.bet01)                                            AS n069_rows_all,
       COUNT(DISTINCT CASE WHEN COALESCE(t1.aid,t2.aid,t3.aid,t4.aid,t5.aid) IS NOT NULL
                           THEN b.bet01 END)                              AS n069_rows_testline,
       COUNT(DISTINCT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT))           AS n069_members_all
FROM ods_mariadb_2b.ods_a168_bet02 b
LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101'
  AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0;


-- -- W3 -- #044 的 grain 与清洗与其余会员件不同，单独量
--    源码 L10259-10263（清洗，★ 无 bet05>0、无 bet11>0）· L10280-10282（bet03/04/05 非空）
--    · GROUP BY pid L10287 · HAVING COUNT(*) >= 30 L10288
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01, CAST(b.bet05 AS BIGINT)                                 AS pid
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
    AND b.bet03 IS NOT NULL AND b.bet04 IS NOT NULL AND b.bet05 IS NOT NULL
),
g AS (SELECT pid, COUNT(DISTINCT bet01) AS n_rows FROM base GROUP BY pid)
SELECT COUNT(*)                                                           AS members_before,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_rows >= 30 THEN 1 ELSE 0 END)                      AS members_ge30,
       SUM(CASE WHEN n_rows >= 30 THEN n_rows ELSE 0 END)                 AS rows_ge30
FROM g;


-- ==============================================================================================
--  §Q · 选跑：宇宙门指标的分位数分布（★ 只量不裁）
--  ----------------------------------------------------------------------------------------
--  ★★ 本节【不得】被用来直接设定新门槛。它的唯一用途是：
--     让 UNIVERSE-PROBE-GATE 在裁定「证据等级分层」时，手上有真实分布而非凭空常数。
--     依铁律第九条，任何门槛必须数据推导；没有分布就只能凭空设数，那正是要杜绝的。
--  ★★ 若 §U / §G 任一条已显吃紧（耗时 > 5 分钟或报内存），本节【跳过不跑】。
-- ==============================================================================================


-- -- Q075 -- #075 会员局数分布（供分层参考，非阈值裁定）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
    AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (SELECT member_id, COUNT(DISTINCT round_key) AS n_rounds FROM base GROUP BY member_id)
SELECT COUNT(*)                                                           AS n_members,
       PERCENTILE_APPROX(n_rounds, 0.10)                                  AS p10,
       PERCENTILE_APPROX(n_rounds, 0.25)                                  AS p25,
       PERCENTILE_APPROX(n_rounds, 0.50)                                  AS p50,
       PERCENTILE_APPROX(n_rounds, 0.75)                                  AS p75,
       PERCENTILE_APPROX(n_rounds, 0.90)                                  AS p90,
       PERCENTILE_APPROX(n_rounds, 0.95)                                  AS p95,
       PERCENTILE_APPROX(n_rounds, 0.99)                                  AS p99,
       AVG(n_rounds)                                                      AS avg_rounds,
       MAX(n_rounds)                                                      AS max_rounds
FROM g;


-- ==============================================================================================
--  §R · 回报模板（跑完请照此填，一格不留空；未跑者写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  节点 | 查询   | 耗时 | query_id | 返回值 | 与已知答案是否相符
--  -----+--------+------+----------+--------+------------------
--  U    | U0     |      |          |        | 锚 124,731,833 / 723,557
--  U    | U1     |      |          |        |
--  U    | U2     |      |          |        |
--  U    | U3     |      |          |        | 应 = U2（bet11 异常已知为 0 笔）
--  U    | U4     |      |          |        | ★ bet08 是清洗还是宇宙门，看本条差值
--  U    | U5     |      |          |        | ★ #075 家族的合法宇宙
--  U    | U5N    |      |          |        | ★ 不含 bet08 的口径
--  G    | G075   |      |          |        | 锚 groups_after = 161,156
--  G    | G080   |      |          |        | 锚 groups_after = 278,729
--  G    | G057   |      |          |        |
--  G    | G083   |      |          |        |
--  GB   | GB-A   |      |          |        |
--  GB   | GB-B   |      |          |        |
--  W    | W1     |      |          |        | #065 样本外窗
--  W    | W2     |      |          |        | #069 测试线未剔
--  W    | W3     |      |          |        | #044 口径特例
--  Q    | Q075   |      |          |        | 选跑
--  ----------------------------------------------------------------------------------------
--  另请一并回报（EXPORT_CONTROL 六项，本件无 CSV 导出，故只需前三项）：
--    ① 本次会话是否已跑 Z00C           ② 是否串行执行            ③ 有无任何一条报错或超时
-- ==============================================================================================
