-- ==============================================================================================
--  UNIVERSE-PROBE v1.6  ·  PK2b / PK2c  ·  member × parent 交集法证（甲乙判别的最后一刀）
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.5 三条已跑 —— PK0 PASS（drift_testline = 0，U* 两锚仍有效）
--                        PK1 PASS（round_key 严格一局唯一键，丙已排除）
--                        PK2 捕获多父，但【输出被截断】且缺 member 维度
--  ----------------------------------------------------------------------------------------
--  ★★ W-44 · PK2 的输出是截断样本，不是全量 ★★
--    724 个 (round_key, lv4) 组，实测 parent_count 全部 = 2 ⇒ 应输出 1,448 行。
--    实收 1,000 行整；其中 361 组各 2 行、278 组各 1 行（361×2 + 278 = 1,000）。
--    多父组不可能只有 1 行 ⇒ 【前端 1,000 行显示上限截断】，算术上完全吻合。
--    ⇒ 依铁律「LIMIT 产生样本，样本中不存在 ≠ 不存在」，
--       PK2 明细的任何分布（如 n_members_in_cell = 968/31/1）只能作【样本统计】，
--       不得当作总体。凡据此下的「甲乙比例」判断一律撤回。
--    ⇒ 本件全部改为【聚合输出】，行数上界 5 行，结构上不可能被截断。
--    ⇒ 新增纪律：探查件凡输出明细，必须走【导出 CSV】而非读屏；读屏一律视为样本。
--  ----------------------------------------------------------------------------------------
--  ★★ W-45 · PK2 缺 member 维度，甲乙本就无法判别 ★★
--    我在 PK2 只出了 n_members_in_cell（每格会员数），未出会员【身份】。
--    「两格各 1 名会员」既可能是同一人（乙），也可能是两个人（甲），
--    单靠计数无从分辨。此为设计缺陷，非数据问题。本件以集合交集直接判定。
--  ----------------------------------------------------------------------------------------
--  甲乙丙三分（互斥且穷尽）：
--    甲 · 同一局、同一 lv4、两个 lv3，各自的会员集合【无交集】
--         ⇒ 不同会员挂同一 lv4 却报不同 lv3 ⇒【代理关系并发多父】⇒ HF9-A 须采 path-set / graph
--    乙 · 会员集合【有交集】：同一会员在同一局内分属两个 lv3
--         ⇒ 同一事实被赋予两个上级 ⇒【数据一致性缺陷】⇒ 开 AGENT-CONSIST-01，HF9-A 不改模型
--    丙 · round_key 键碰撞 ⇒ 已由 PK1 排除（rk_span_multi_day = 0）
--    ★ 乙再分两级（红队要求两者都测，不得二选一）：
--       乙-1（会员级）同一 member + 同一 round + 不同 lv3
--       乙-2（注单级）同一 bet01 出现两个不同 lv3
--       ★ 乙-2 若 > 0，则同时【证伪 Gate-00-B】（重复行为纯副本），
--         因为 bet20 若在 24 个业务字段之内，各副本的 lv3 必然相同。
--         此为本件的附带高价值检验，影响远超 HF9-A。
--  ----------------------------------------------------------------------------------------
--  纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    清洗一律 U* 口径；0 一律以 NULLIF(...,0) 视为链终止哨兵（P1h 已 PROVEN）
--    串行执行，先逐行单跑 Z00C；任一条超 10 分钟立即取消，不重试、不双开
-- ==============================================================================================


-- ==============================================================================================
--  §PK2b · 全局甲乙判别（聚合输出，1 行，无截断风险）
-- ==============================================================================================


-- -- PK2b -- 724 组的会员交集判别 ＋ 注单级交集（Gate-00-B 附带检验）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.bet01                                                          AS bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)    AS stake,
         NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0)              AS lv3,
         NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0)              AS lv4
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
    AND NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0) IS NOT NULL
    AND NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0) IS NOT NULL
),
mp AS (SELECT round_key, lv4 FROM r
       GROUP BY round_key, lv4 HAVING COUNT(DISTINCT lv3) > 1),
cells AS (
  SELECT x.round_key, x.lv4, x.lv3, x.member_id, x.bet01, x.stake
  FROM r x JOIN mp m ON m.round_key = x.round_key AND m.lv4 = x.lv4
),
per_member AS (
  SELECT round_key, lv4, member_id,
         COUNT(DISTINCT lv3)                                              AS n_parent_of_member,
         COUNT(DISTINCT bet01)                                            AS n_bets,
         SUM(stake)                                                       AS stake
  FROM cells GROUP BY round_key, lv4, member_id
),
per_group AS (
  SELECT round_key, lv4,
         COUNT(*)                                                         AS n_members,
         SUM(CASE WHEN n_parent_of_member > 1 THEN 1 ELSE 0 END)          AS n_cross_members,
         SUM(n_bets)                                                      AS n_bets,
         SUM(stake)                                                       AS stake,
         SUM(CASE WHEN n_parent_of_member > 1 THEN n_bets ELSE 0 END)     AS n_bets_cross,
         SUM(CASE WHEN n_parent_of_member > 1 THEN stake ELSE 0 END)      AS stake_cross
  FROM per_member GROUP BY round_key, lv4
),
per_bet AS (
  SELECT bet01, COUNT(DISTINCT lv3)                                       AS n_lv3_of_bet
  FROM cells GROUP BY bet01
)
SELECT COUNT(*)                                                           AS groups_total,
       SUM(CASE WHEN n_cross_members > 0 THEN 1 ELSE 0 END)               AS groups_yi_member_cross,
       SUM(CASE WHEN n_cross_members = 0 THEN 1 ELSE 0 END)               AS groups_jia_disjoint,
       SUM(n_members)                                                     AS members_in_groups,
       SUM(n_cross_members)                                               AS members_cross,
       SUM(n_bets)                                                        AS bets_in_groups,
       SUM(n_bets_cross)                                                  AS bets_cross,
       ROUND(SUM(stake), 4)                                               AS stake_in_groups,
       ROUND(SUM(stake_cross), 4)                                         AS stake_cross,
       (SELECT COUNT(*) FROM per_bet WHERE n_lv3_of_bet > 1)              AS bet01_multi_lv3,
       (SELECT COUNT(*) FROM per_bet)                                     AS bet01_in_groups
FROM per_group;
--    验收判据（三条，逐条判，不得跳读）：
--      ① groups_total 必须 = 724（与 v1.4 P1k 逐位相同）⇒ 本件与前件同源可比
--      ② groups_yi_member_cross = 0 且 groups_jia_disjoint = 724
--         ⇒ 【甲】成立：不同会员挂同一 lv4 却报不同 lv3 ⇒ 代理关系并发多父
--         ⇒ HF9-A 必须采 path-set / graph，CONCAT_WS 单键【仅可作编码，不可作关系语义】
--      ③ groups_yi_member_cross > 0
--         ⇒ 【乙】存在：同一会员同一局分属两个 lv3 ⇒ 数据一致性缺陷
--         ⇒ 开 AGENT-CONSIST-01；HF9-A 是否改模型，须看甲乙两类的【敞口占比】而非组数
--      ★★ bet01_multi_lv3 必须 = 0。若 > 0 ⇒ 同一注单被赋两个 lv3
--         ⇒ 【Gate-00-B「重复行为纯副本」被证伪】，其影响远超 HF9-A：
--            rn=1 去重的等价性、COUNT(DISTINCT bet01) 替换、U* 两锚，全部须重验。
--            此时应【立即停手回报】，不得继续任何 HF9 工程。


-- ==============================================================================================
--  §PK2c · 逐节点敞口（最多 4 行，无截断风险）
--  ----------------------------------------------------------------------------------------
--  红队铁律：「不能因为只有 3 个节点，就只看节点数量。」
--  本条按 child 拆开甲乙两类的组数、会员、注单、注额，供 GATE 按敞口而非组数裁定。
-- ==============================================================================================


-- -- PK2c -- 三个 lv4 节点的甲乙敞口拆分
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.bet01                                                          AS bet01,
         b.dt                                                             AS bet_date,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)    AS stake,
         NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0)              AS lv3,
         NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0)              AS lv4
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
    AND NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0) IS NOT NULL
    AND NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0) IS NOT NULL
),
mp AS (SELECT round_key, lv4 FROM r
       GROUP BY round_key, lv4 HAVING COUNT(DISTINCT lv3) > 1),
cells AS (
  SELECT x.round_key, x.lv4, x.lv3, x.member_id, x.bet01, x.stake, x.bet_date
  FROM r x JOIN mp m ON m.round_key = x.round_key AND m.lv4 = x.lv4
),
per_member AS (
  SELECT round_key, lv4, member_id,
         COUNT(DISTINCT lv3)                                              AS n_parent_of_member,
         COUNT(DISTINCT bet01)                                            AS n_bets,
         SUM(stake)                                                       AS stake,
         MIN(bet_date)                                                    AS d0,
         MAX(bet_date)                                                    AS d1
  FROM cells GROUP BY round_key, lv4, member_id
),
per_group AS (
  SELECT round_key, lv4,
         SUM(CASE WHEN n_parent_of_member > 1 THEN 1 ELSE 0 END)          AS n_cross,
         SUM(n_bets)                                                      AS n_bets,
         SUM(stake)                                                       AS stake,
         COUNT(*)                                                         AS n_members,
         MIN(d0)                                                          AS d0,
         MAX(d1)                                                          AS d1
  FROM per_member GROUP BY round_key, lv4
)
SELECT CAST(lv4 AS STRING)                                                AS child_id,
       COUNT(*)                                                           AS groups_total,
       SUM(CASE WHEN n_cross > 0 THEN 1 ELSE 0 END)                       AS groups_yi,
       SUM(CASE WHEN n_cross = 0 THEN 1 ELSE 0 END)                       AS groups_jia,
       SUM(n_members)                                                     AS members_cells,
       SUM(n_bets)                                                        AS n_bets,
       ROUND(SUM(stake), 4)                                               AS stake,
       MIN(d0)                                                            AS first_day,
       MAX(d1)                                                            AS last_day
FROM per_group GROUP BY lv4;
--    验收判据：
--      ① 三行之和的 groups_total 必须 = 724
--      ② 逐节点的 groups_yi / groups_jia 拆分即甲乙敞口，
--         按 node × group × member × bet × stake 五维判，不得只看节点数
--      ★ v1.4 P1j 已测三节点全窗敞口：663,714 笔（U* 的 0.532%）· 注额 146,064,047（约 1.111%）。
--        本条给出的是【同局多父那一部分】的敞口，必然远小于全窗敞口，两者不可混用。


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条    | 耗时 | query_id | 返回值 | 判据结果
--  ------+------+----------+--------+-------------------------------------------------------
--  PK2b  |      |          |        | groups_total = 724？· groups_yi_member_cross = ?
--        |      |          |        | ★ bet01_multi_lv3 必须 = 0（非 0 立即停手）
--  PK2c  |      |          |        | 三行；groups_yi / groups_jia 逐节点拆分
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已逐行单跑 Z00C  ② 是否串行  ③ 有无报错或超时
--  ----------------------------------------------------------------------------------------
--  ★ 本件不裁定任何业务判据。3 个 lv4 节点在本件判定前，一律只称「同局多父候选」；
--    29,606 只称「结构候选池」；分位数是分布事实，不是门槛。
-- ==============================================================================================
