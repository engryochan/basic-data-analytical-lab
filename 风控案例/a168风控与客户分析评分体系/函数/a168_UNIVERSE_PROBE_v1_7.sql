-- ==============================================================================================
--  UNIVERSE-PROBE v1.7  ·  五级全维复核（斧正「只测 lv3」之缺）
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  ----------------------------------------------------------------------------------------
--  ★★ W-46 · Ryo Eng 先生指出：bet01_multi_lv3 只测 lv3 一层，不足 ★★
--    v1.6 PK2b 的 Gate-00-B 复核只问了「同一 bet01 是否出现两个 lv3」。
--    但重复副本若在 lv1 / lv2 / lv4 / lv5 任一层不一致，该检验【一律看不见】。
--    ⇒ Gate-00-B 的交叉复核实际只覆盖 【1/5】 的代理列。
--    ⇒ 本件改为五层全测：bet01 × (lv1, lv2, lv3, lv4, lv5) 逐层一致性。
--
--  ★★ W-47 · f_multi_parent_round 与 PK2 系列同为单层构件 ★★
--    v1.4 P1k / v1.5 PK2 / v1.6 PK2b·PK2c 的多父检验，全部只做
--        GROUP BY round_key, lv4 HAVING COUNT(DISTINCT lv3) > 1
--    即【仅 lv4→lv3 一对层级】。四对父子关系中只测了一对。
--    ⇒ 本件改为四对全测：lv2→lv1 · lv3→lv2 · lv4→lv3 · lv5→lv4。
--
--    ★ 逻辑补注（须与实测并列，不可互相取代）：
--      v1.4 P1f 已于【全窗】测得 lv3_multi_parent2 = 0 且 lv2_multi_top1 = 0。
--      全窗父唯一 ⇒ 任一子集（含单局）内亦父唯一，故 lv3→lv2 与 lv2→lv1 的
--      同局多父在【逻辑上】必为 0。本件仍逐层实测，理由有二：
--        ① 逻辑蕴含依赖 P1f 的口径与本件一致，须以实测确认同源；
--        ② 「不可能为非零」与「实测为零」是两个不同的证据等级，registry 须记后者。
--  ----------------------------------------------------------------------------------------
--  ★ 已完成五级化、无须再补的构件（本件不重复测）：
--      n_lv1_chain ~ n_lv5_chain（v1.2 P1b-fix / v1.3 P1e / v1.4 P1i 均五级齐全）
--      chain_key（P1g 已证 2,528 = 2,528 = 2,528 唯一，五列全参与拼接）
--      测试线剔除（129 件中 44 件 q 侧、129 件 e 侧，经扫描【五层无一漏】）
--      lvX_null / lvX_zero 普查（v1.3 P1d 五层齐全）
--      父唯一性（v1.4 P1f 覆盖 lv5→lv4/lv1 · lv4→lv3/lv1 · lv3→lv2/lv1 · lv2→lv1）
--  ----------------------------------------------------------------------------------------
--  纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    清洗一律 U* 口径；0 一律以 NULLIF(...,0) 视为链终止哨兵（v1.4 P1h 已 PROVEN）
--    ★ 输出全为聚合，行数上界 1 行与 5 行，结构上不可能被前端 1,000 行上限截断（W-44 教训）
--    串行执行，先逐行单跑 Z00C；任一条超 10 分钟立即取消，不重试、不双开
-- ==============================================================================================


-- ==============================================================================================
--  §PG1 · Gate-00-B 五层全维复核（修 W-46）
--  ----------------------------------------------------------------------------------------
--  重复行若为「纯副本」，则同一 bet01 的各副本在【全部五个代理列】上必须一致。
--  本条不限于多父组，而是对【整个 U* 宇宙】逐层检验 —— 因为 Gate-00-B 的适用范围是全宇宙，
--  只在 2,178 笔样本上复核，覆盖率仅 0.0017%，不足以支撑「PASS」。
--  ★ 本条同时复核会员、荷官两个实体列，因为 Gate-00-B 的原始断言涵盖 24 个业务字段，
--    而此前从未逐列复验过任何一个。
-- ==============================================================================================


-- -- PG1 -- 同一 bet01 的各副本，五级代理 ＋ 会员 ＋ 荷官 是否逐列一致（全宇宙）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT b.bet01                                                          AS bet01,
         NULLIF(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT), 0)              AS lv1,
         NULLIF(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT), 0)              AS lv2,
         NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0)              AS lv3,
         NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0)              AS lv4,
         NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), 0)              AS lv5,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         TRIM(b.eid)                                                      AS dealer_id,
         TRIM(b.bet39)                                                    AS table_id
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
  SELECT bet01,
         COUNT(*)                                                         AS n_copies,
         COUNT(DISTINCT lv1)       AS d1, COUNT(DISTINCT lv2)       AS d2,
         COUNT(DISTINCT lv3)       AS d3, COUNT(DISTINCT lv4)       AS d4,
         COUNT(DISTINCT lv5)       AS d5,
         COUNT(DISTINCT member_id) AS dm, COUNT(DISTINCT dealer_id) AS dd,
         COUNT(DISTINCT table_id)  AS dt
  FROM r GROUP BY bet01
)
SELECT COUNT(*)                                                           AS n_bet01_total,
       SUM(CASE WHEN n_copies > 1 THEN 1 ELSE 0 END)                      AS n_bet01_with_copies,
       SUM(n_copies)                                                      AS n_rows_total,
       SUM(CASE WHEN d1 > 1 THEN 1 ELSE 0 END)                            AS incons_lv1,
       SUM(CASE WHEN d2 > 1 THEN 1 ELSE 0 END)                            AS incons_lv2,
       SUM(CASE WHEN d3 > 1 THEN 1 ELSE 0 END)                            AS incons_lv3,
       SUM(CASE WHEN d4 > 1 THEN 1 ELSE 0 END)                            AS incons_lv4,
       SUM(CASE WHEN d5 > 1 THEN 1 ELSE 0 END)                            AS incons_lv5,
       SUM(CASE WHEN dm > 1 THEN 1 ELSE 0 END)                            AS incons_member,
       SUM(CASE WHEN dd > 1 THEN 1 ELSE 0 END)                            AS incons_dealer,
       SUM(CASE WHEN dt > 1 THEN 1 ELSE 0 END)                            AS incons_table,
       SUM(CASE WHEN d1 > 1 OR d2 > 1 OR d3 > 1 OR d4 > 1 OR d5 > 1
                  OR dm > 1 OR dd > 1 OR dt > 1 THEN 1 ELSE 0 END)        AS incons_any
FROM g;
--    验收判据：
--      ① n_bet01_total 必须 = 124,713,543（U* 锚）；n_rows_total 必须 ≥ n_bet01_total
--      ② incons_lv1 ~ incons_lv5 【五个全部 = 0】⇒ 五级代理在副本间逐层一致
--         ⇒ Gate-00-B 的代理维度【五层全覆盖】通过（此前仅 lv3 一层、仅 0.0017% 样本）
--      ③ incons_member / incons_dealer / incons_table 亦须 = 0
--         ⇒ 会员、荷官、桌台三个实体列同样一致
--      ★★ 任一项 > 0 ⇒ 【Gate-00-B 被证伪】。此时：
--         rn=1 去重的等价性、COUNT(DISTINCT bet01) 替换、U* 两锚、v1.0~v1.6 全部结论
--         须重验。应【立即停手回报】，不得施工任何 HF9 组件。


-- ==============================================================================================
--  §PG2 · 同局多父：四对父子层级全扫（修 W-47）
--  ----------------------------------------------------------------------------------------
--  此前只测 lv4→lv3 一对。本条把四对父子关系一次测齐：
--      lv2→lv1 · lv3→lv2 · lv4→lv3 · lv5→lv4
--  并同时给出【组数 / 会员 / 注单 / 注额】四维敞口，以供 f_multi_parent_* 的分层设计。
--  ★ 已知锚：lv4→lv3 应 = 724 组 · 1,498 会员格 · 2,178 注单 · 390,114.6808 注额
--            lv5→lv4 应 = 0（v1.4 P1k 实测 same_round_multi_parent_lv5 = 0）
-- ==============================================================================================


-- -- PG2 -- 四对父子层级的同局多父规模与敞口
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.bet01                                                          AS bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)    AS stake,
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
g2 AS (SELECT round_key AS rk, lv2 AS child, COUNT(DISTINCT lv1) AS np,
              COUNT(DISTINCT member_id) AS nm, COUNT(DISTINCT bet01) AS nb, SUM(stake) AS st
       FROM r WHERE lv2 IS NOT NULL AND lv1 IS NOT NULL GROUP BY round_key, lv2),
g3 AS (SELECT round_key AS rk, lv3 AS child, COUNT(DISTINCT lv2) AS np,
              COUNT(DISTINCT member_id) AS nm, COUNT(DISTINCT bet01) AS nb, SUM(stake) AS st
       FROM r WHERE lv3 IS NOT NULL AND lv2 IS NOT NULL GROUP BY round_key, lv3),
g4 AS (SELECT round_key AS rk, lv4 AS child, COUNT(DISTINCT lv3) AS np,
              COUNT(DISTINCT member_id) AS nm, COUNT(DISTINCT bet01) AS nb, SUM(stake) AS st
       FROM r WHERE lv4 IS NOT NULL AND lv3 IS NOT NULL GROUP BY round_key, lv4),
g5 AS (SELECT round_key AS rk, lv5 AS child, COUNT(DISTINCT lv4) AS np,
              COUNT(DISTINCT member_id) AS nm, COUNT(DISTINCT bet01) AS nb, SUM(stake) AS st
       FROM r WHERE lv5 IS NOT NULL AND lv4 IS NOT NULL GROUP BY round_key, lv5)
SELECT 'lv2_over_lv1'                                                     AS level_pair,
       COUNT(*)                                                           AS groups_scanned,
       SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END)                            AS groups_multi_parent,
       COUNT(DISTINCT CASE WHEN np > 1 THEN child END)                    AS n_child_nodes,
       SUM(CASE WHEN np > 1 THEN nm ELSE 0 END)                           AS members_cells,
       SUM(CASE WHEN np > 1 THEN nb ELSE 0 END)                           AS n_bets,
       ROUND(SUM(CASE WHEN np > 1 THEN st ELSE 0 END), 4)                 AS stake,
       MAX(np)                                                            AS max_parents
FROM g2
UNION ALL
SELECT 'lv3_over_lv2', COUNT(*), SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END),
       COUNT(DISTINCT CASE WHEN np > 1 THEN child END),
       SUM(CASE WHEN np > 1 THEN nm ELSE 0 END),
       SUM(CASE WHEN np > 1 THEN nb ELSE 0 END),
       ROUND(SUM(CASE WHEN np > 1 THEN st ELSE 0 END), 4), MAX(np)
FROM g3
UNION ALL
SELECT 'lv4_over_lv3', COUNT(*), SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END),
       COUNT(DISTINCT CASE WHEN np > 1 THEN child END),
       SUM(CASE WHEN np > 1 THEN nm ELSE 0 END),
       SUM(CASE WHEN np > 1 THEN nb ELSE 0 END),
       ROUND(SUM(CASE WHEN np > 1 THEN st ELSE 0 END), 4), MAX(np)
FROM g4
UNION ALL
SELECT 'lv5_over_lv4', COUNT(*), SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END),
       COUNT(DISTINCT CASE WHEN np > 1 THEN child END),
       SUM(CASE WHEN np > 1 THEN nm ELSE 0 END),
       SUM(CASE WHEN np > 1 THEN nb ELSE 0 END),
       ROUND(SUM(CASE WHEN np > 1 THEN st ELSE 0 END), 4), MAX(np)
FROM g5;
--    验收判据：
--      ① lv4_over_lv3 行必须 = 724 组 · 1,498 会员格 · 2,178 注单 · 390,114.6808 注额
--         （与 v1.6 PK2b/PK2c 逐位相同）⇒ 本件与前件同源可比
--      ② lv5_over_lv4 行的 groups_multi_parent 必须 = 0（与 v1.4 P1k 相同）
--      ③ lv2_over_lv1 与 lv3_over_lv2 两行：
--         · 若 = 0 ⇒ 与 v1.4 P1f 全窗父唯一的逻辑蕴含一致，同源确认
--         · 若 > 0 ⇒ 与 P1f 矛盾，二者必有一错，【立即停手回报】，
--                    不得以「逻辑上不可能」为由忽略实测
--      ★ 四行的 groups_multi_parent 之和，即 f_multi_parent_round 的完整命中面；
--        此前只用 lv4_over_lv3 一行，覆盖不全。


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条   | 耗时 | query_id | 返回值 | 判据结果
--  -----+------+----------+--------+--------------------------------------------------------
--  PG1  |      |          |        | ★ incons_lv1~lv5 / member / dealer / table 须全 0
--       |      |          |        |   任一 > 0 立即停手，Gate-00-B 被证伪
--  PG2  |      |          |        | 四行；lv4_over_lv3 须 = 724/1498/2178/390114.6808
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已逐行单跑 Z00C  ② 是否串行  ③ 有无报错或超时
--  ----------------------------------------------------------------------------------------
--  ★ 本件不裁定任何业务判据。多父现象在四层全扫完成前，一律只称「同局多父」，
--    不称代理图、不称串联、不称异常；29,606 只称「结构候选池」。
-- ==============================================================================================
