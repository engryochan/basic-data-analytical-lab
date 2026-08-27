-- ==============================================================================================
--  UNIVERSE-PROBE v1.8  ·  ZERO-CAUSE-01  ·  查证 PG2 三行为零之因
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.7 PG1 PASS（八列 × 全宇宙，incons 全 0）· PG2 四对全扫
--  ----------------------------------------------------------------------------------------
--  ★ Ryo Eng 先生质问：PG2 四行里三行为零，为何？须查证，不得以「结构如此」搪塞。
--
--  ★ 已有的【阳性对照】：PG2 四行用【完全相同的模板】（同一 r CTE、同一 GROUP BY 形状、
--    同一 HAVING 逻辑），其中 lv4_over_lv3 一行返回 724，且与 v1.6 PK2b/PK2c 逐位相同。
--    ⇒ 模板本身能检出多父，三行为零【不是查询失效】。
--    但「模板有效」只排除了一种可能，不构成对零值成因的解释。本件补齐解释。
--
--  ★ 三种互斥的零值成因（依 R4-STAT-03，零值必须分类，不得笼统称「无」）：
--      STRUCTURAL_ZERO  · 该层级对本就是严格树，任何粒度下都不可能多父
--      TEMPORAL_ZERO    · 该层级对全窗【有】多父节点，但各父在时间上前后相继，
--                         故在「同一局」这一细粒度下必然为零
--      SCOPE_ZERO       · 过滤条件把候选行滤空了（口径错误），属缺陷
--  ----------------------------------------------------------------------------------------
--  ★ 判别方法：同一四对父子关系，在【三种粒度】上各测一次 ——
--        全窗（无分组键）→ 同日（bet_date）→ 同局（round_key）
--    · 三级全零           ⇒ STRUCTURAL_ZERO
--    · 全窗 > 0 而同局 = 0 ⇒ TEMPORAL_ZERO（并由 span 列指出时间分离）
--    · 候选组数为 0        ⇒ SCOPE_ZERO（口径错误，须立即斧正）
--  ★ 本件同时输出每对的【候选行数】与【候选子节点数】，即「分母」——
--    分母非零而分子为零，才叫「实测为零」；分母为零叫「没测到」，二者证据等级不同。
--  ----------------------------------------------------------------------------------------
--  纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    清洗一律 U* 口径；0 一律以 NULLIF(...,0) 视为链终止哨兵（v1.4 P1h 已 PROVEN）
--    五级源列 bet18~bet22 全数参与，不得只取其一
--    输出 4 行，结构上不可能被前端 1,000 行上限截断（W-44 教训）
-- ==============================================================================================


-- -- ZC1 -- 四对父子关系 × 三种粒度（全窗 / 同日 / 同局）+ 分母 + 时间跨度
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.dt                                                             AS bet_date,
         b.bet01                                                          AS bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         NULLIF(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT), 0)              AS lv1,
         NULLIF(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT), 0)              AS lv2,
         NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0)              AS lv3,
         NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0)              AS lv4,
         NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), 0)              AS lv5
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
p21 AS (SELECT lv2 AS child, lv1 AS parent, bet_date, round_key, bet01, member_id
        FROM r WHERE lv2 IS NOT NULL AND lv1 IS NOT NULL),
p32 AS (SELECT lv3 AS child, lv2 AS parent, bet_date, round_key, bet01, member_id
        FROM r WHERE lv3 IS NOT NULL AND lv2 IS NOT NULL),
p43 AS (SELECT lv4 AS child, lv3 AS parent, bet_date, round_key, bet01, member_id
        FROM r WHERE lv4 IS NOT NULL AND lv3 IS NOT NULL),
p54 AS (SELECT lv5 AS child, lv4 AS parent, bet_date, round_key, bet01, member_id
        FROM r WHERE lv5 IS NOT NULL AND lv4 IS NOT NULL),
w21 AS (SELECT child, COUNT(DISTINCT parent) AS np, MIN(bet_date) AS d0, MAX(bet_date) AS d1
        FROM p21 GROUP BY child),
w32 AS (SELECT child, COUNT(DISTINCT parent) AS np, MIN(bet_date) AS d0, MAX(bet_date) AS d1
        FROM p32 GROUP BY child),
w43 AS (SELECT child, COUNT(DISTINCT parent) AS np, MIN(bet_date) AS d0, MAX(bet_date) AS d1
        FROM p43 GROUP BY child),
w54 AS (SELECT child, COUNT(DISTINCT parent) AS np, MIN(bet_date) AS d0, MAX(bet_date) AS d1
        FROM p54 GROUP BY child),
d21 AS (SELECT bet_date, child, COUNT(DISTINCT parent) AS np FROM p21 GROUP BY bet_date, child),
d32 AS (SELECT bet_date, child, COUNT(DISTINCT parent) AS np FROM p32 GROUP BY bet_date, child),
d43 AS (SELECT bet_date, child, COUNT(DISTINCT parent) AS np FROM p43 GROUP BY bet_date, child),
d54 AS (SELECT bet_date, child, COUNT(DISTINCT parent) AS np FROM p54 GROUP BY bet_date, child),
k21 AS (SELECT round_key, child, COUNT(DISTINCT parent) AS np FROM p21 GROUP BY round_key, child),
k32 AS (SELECT round_key, child, COUNT(DISTINCT parent) AS np FROM p32 GROUP BY round_key, child),
k43 AS (SELECT round_key, child, COUNT(DISTINCT parent) AS np FROM p43 GROUP BY round_key, child),
k54 AS (SELECT round_key, child, COUNT(DISTINCT parent) AS np FROM p54 GROUP BY round_key, child)
SELECT 'lv2_over_lv1'                                                     AS level_pair,
       (SELECT COUNT(*) FROM p21)                                         AS candidate_rows,
       (SELECT COUNT(*) FROM w21)                                         AS child_nodes,
       (SELECT COUNT(DISTINCT parent) FROM p21)                           AS parent_nodes,
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM w21)          AS multi_window,
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM d21)          AS multi_sameday,
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM k21)          AS multi_sameround,
       (SELECT MAX(np) FROM w21)                                          AS max_parent_window,
       (SELECT MAX(DATEDIFF(d1, d0)) + 1 FROM w21 WHERE np > 1)           AS span_days_of_multi
UNION ALL
SELECT 'lv3_over_lv2',
       (SELECT COUNT(*) FROM p32), (SELECT COUNT(*) FROM w32),
       (SELECT COUNT(DISTINCT parent) FROM p32),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM w32),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM d32),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM k32),
       (SELECT MAX(np) FROM w32),
       (SELECT MAX(DATEDIFF(d1, d0)) + 1 FROM w32 WHERE np > 1)
UNION ALL
SELECT 'lv4_over_lv3',
       (SELECT COUNT(*) FROM p43), (SELECT COUNT(*) FROM w43),
       (SELECT COUNT(DISTINCT parent) FROM p43),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM w43),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM d43),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM k43),
       (SELECT MAX(np) FROM w43),
       (SELECT MAX(DATEDIFF(d1, d0)) + 1 FROM w43 WHERE np > 1)
UNION ALL
SELECT 'lv5_over_lv4',
       (SELECT COUNT(*) FROM p54), (SELECT COUNT(*) FROM w54),
       (SELECT COUNT(DISTINCT parent) FROM p54),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM w54),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM d54),
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM k54),
       (SELECT MAX(np) FROM w54),
       (SELECT MAX(DATEDIFF(d1, d0)) + 1 FROM w54 WHERE np > 1);
--    验收判据（逐行判，四行都要判，不得只看非零那行）：
--      ① candidate_rows 与 child_nodes 必须【全部大于零】。
--         任一为零 ⇒ SCOPE_ZERO：过滤条件把该层级对滤空了，属口径缺陷，立即停手斧正。
--      ② child_nodes 应与 v1.4 P1f 的真实代理数同量级：
--         lv2 ≈ 220 · lv3 ≈ 454 · lv4 ≈ 866 · lv5 ≈ 2,461
--         若差距悬殊 ⇒ 口径不同源，须回查。
--      ③ 逐行分类：
--         multi_window = 0 且 multi_sameday = 0 且 multi_sameround = 0 ⇒ STRUCTURAL_ZERO
--         multi_window > 0 且 multi_sameround = 0                      ⇒ TEMPORAL_ZERO
--         （此时 span_days_of_multi 给出该多父节点两父之间的时间跨度）
--      ④ 已知锚（与前件逐位对照）：
--         lv4_over_lv3 · multi_window 应 = 3 · multi_sameday 应 = 121 · multi_sameround 应 = 724
--         lv5_over_lv4 · multi_window 应 = 1（v1.4 P1f）· multi_sameround 应 = 0（v1.4 P1k）
--         ⇒ lv5 若呈「全窗 1、同局 0」，即 TEMPORAL_ZERO 的教科书式实例，
--            对应 v1.4 P1j 已测的节点 56212：父 6352 于 06-10~06-11、父 56759 于 06-13~06-29，
--            两段不重叠 ⇒ 同局必然为零。
--      ★ 本件不裁定任何业务判据。零值分类只描述结构，不推断代理行为，
--        亦不因某层为零而将该层排除于 HF9-A 的五级出列之外 ——
--        五级一律出列，零值层照出，只是其 f_multi_parent_lvX 恒为 0。
-- ==============================================================================================
