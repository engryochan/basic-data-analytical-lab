-- ==============================================================================================
--  UNIVERSE-PROBE v1.5  ·  P1k-FINAL / ROUND-GRAIN-01  ＋  DIM-DRIFT-01
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.4 四条已跑 —— P1h PASS · P1i 48→3 · P1j 八行 · P1k 724 / 3 nodes
--  ----------------------------------------------------------------------------------------
--  ★★ 本件的第一目的：为 724 个「同局多父」做法证落点 ★★
--    v1.4 P1k 实测 same_round_multi_parent_lv4 = 724，涉 3 个 lv4 节点、121 个日子。
--    但 724 是否为【真实业务同局多父】，取决于三件尚未验真的事：
--      ① round_key = CONCAT_WS('|', bet03, bet04, bet39) 是否真是「一局唯一键」
--      ② 同一 round_key 是否跨日 / 跨桌（键碰撞）
--      ③ 724 中的两个父，是【同一会员的两笔注单分属不同 lv3】，
--         还是【不同会员共用同一 lv4 却挂不同 lv3】
--    ①② 若不成立，724 是键碰撞的产物，须修正 P1k 而非据此重构模型；
--    ③ 的两种情形含义完全不同：前者是会员级换线或数据错，后者才是代理关系图。
--  ----------------------------------------------------------------------------------------
--  ★★ 本件的第二目的：DIM-DRIFT-01（v1.4 意外暴露、红队未察觉的问题）★★
--    HEALTH-01 H6 于 2026-08-26 实测 ods_a168_agent = 46,415 行。
--    v1.4 P1h 实测 agent_dim_rows = 46,449 行 ⇒ 代理维表在两次探查之间【增长 34 行】。
--    后果：U* 由「五级测试线剔除」定义，而测试线名单来自该维表。
--          维表在跑数期间变化 ⇒ 129 件若跨小时执行，各件的 U* 口径【互不一致】，
--          且 129 张 CSV 之间无法逐行对账。这是落盘前必须封口的可复现性缺口。
--    ⇒ 本件量其规模，并给出冻结方案所需的指纹。
--  ----------------------------------------------------------------------------------------
--  纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    清洗一律 U* 口径（723,442 会员 / 124,713,543 注单，五级测试线已剔）
--    0 一律以 NULLIF(...,0) 视为链终止哨兵（P1h 已 PROVEN：维表无 id=0 且零值零复现）
--    串行执行，先逐行单跑 Z00C；任一条超 10 分钟立即取消，不重试、不双开
-- ==============================================================================================


-- ==============================================================================================
--  §PK0 · DIM-DRIFT-01：代理维表漂移的规模与指纹
--  ----------------------------------------------------------------------------------------
--  跑 129 件之前必须先确认：维表是否还在动、动多少、测试线名单是否随之变化。
--  若测试线名单变化，则 U* 本身会变，先前所有锚点（723,442 / 124,713,543）失效。
-- ==============================================================================================


-- -- PK0 -- 代理维表当前基数、测试线名单指纹、与已锁锚点的差
SELECT COUNT(*)                                                           AS agent_rows_now,
       46415                                                              AS agent_rows_health01,
       COUNT(*) - 46415                                                   AS drift_rows,
       SUM(CASE WHEN TRIM(age022) = '1' THEN 1 ELSE 0 END)                AS n_testline_now,
       215                                                                AS n_testline_health01,
       SUM(CASE WHEN TRIM(age022) = '1' THEN 1 ELSE 0 END) - 215          AS drift_testline,
       SUM(CASE WHEN TRIM(age022) = '1'
                 THEN CAST(NULLIF(TRIM(age001),'') AS BIGINT) ELSE 0 END) AS testline_id_checksum,
       MIN(CASE WHEN TRIM(age022) = '1'
                THEN CAST(NULLIF(TRIM(age001),'') AS BIGINT) END)         AS testline_id_min,
       MAX(CASE WHEN TRIM(age022) = '1'
                THEN CAST(NULLIF(TRIM(age001),'') AS BIGINT) END)         AS testline_id_max,
       COUNT(DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT))            AS n_distinct_agent_id
FROM ods_mariadb_2b.ods_a168_agent;
--    验收判据：
--      ① drift_testline = 0 ⇒ 测试线名单未变 ⇒ U* 的两个锚仍然有效，可继续沿用
--      ② drift_testline <> 0 ⇒ 测试线名单已变 ⇒ U* 必须重测，
--         且 129 件落盘【必须】先冻结维表（建议：跑数前抄录 testline_id_checksum，
--         跑数后复抄，两者不等即该批作废重跑）
--      ③ n_distinct_agent_id 必须 = agent_rows_now（一代理一行，交接口诀已锁）
--      ★ testline_id_checksum 是本轮新增的【维表指纹】：
--        它对名单的任何增删改都敏感，且只需一次全表扫描（维表仅 4.6 万行，成本近乎零）。
--        建议纳入 EXPORT_CONTROL 的第七项，与 query_id / MD5 并列。


-- ==============================================================================================
--  §PK1 · round_key 完整性：它到底是不是「一局唯一键」
--  ----------------------------------------------------------------------------------------
--  round_key = CONCAT_WS('|', bet03, bet04, bet39) = 靴号 | 局号 | 桌号。
--  若靴号按日重置，则同一 round_key 会跨日复现 ⇒ 「同局」判定失真，724 不可信。
--  本条对【全宇宙】做完整性检验，不限于那 3 个节点 —— 因为 round_key 是全包 129 件的公共基石，
--  它若有问题，影响的远不止 HF9-A。
-- ==============================================================================================


-- -- PK1 -- round_key 是否跨日 / 跨桌 / 跨靴（全宇宙）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.dt                                                             AS bet_date,
         TRIM(b.bet39)                                                    AS table_id,
         TRIM(b.bet03)                                                    AS shoe_id,
         b.bet01
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
  SELECT round_key,
         COUNT(DISTINCT bet_date)                                         AS n_days,
         COUNT(DISTINCT table_id)                                         AS n_tables,
         COUNT(DISTINCT shoe_id)                                          AS n_shoes,
         COUNT(DISTINCT bet01)                                            AS n_bets
  FROM r GROUP BY round_key
)
SELECT COUNT(*)                                                           AS n_round_keys,
       SUM(CASE WHEN n_days   > 1 THEN 1 ELSE 0 END)                      AS rk_span_multi_day,
       SUM(CASE WHEN n_tables > 1 THEN 1 ELSE 0 END)                      AS rk_span_multi_table,
       SUM(CASE WHEN n_shoes  > 1 THEN 1 ELSE 0 END)                      AS rk_span_multi_shoe,
       MAX(n_days)                                                        AS max_days_per_rk,
       MAX(n_bets)                                                        AS max_bets_per_rk,
       SUM(n_bets)                                                        AS total_bets,
       SUM(CASE WHEN n_days > 1 THEN n_bets ELSE 0 END)                   AS bets_in_multiday_rk
FROM g;
--    验收判据：
--      ① rk_span_multi_day = 0 ⇒ round_key 不跨日 ⇒ 「同局」判定成立，724 是真实同局
--      ② rk_span_multi_day > 0 ⇒ round_key 跨日 ⇒ 靴号按日重置或存在键碰撞 ⇒
--         P1k 的 724 不可信，须把 bet_date 并入 round_key 后重测，
--         且【全包 129 件凡用 round_key 者一律须复核】（远大于 HF9-A 的范围）
--      ③ rk_span_multi_table / rk_span_multi_shoe 必须恒为 0（二者是 round_key 的组成部分，
--         非零即证 CONCAT_WS 拼接有误或字段含分隔符 '|'）
--      ★ n_round_keys 应与 v1.2 P5 的 candidate_rounds = 6,048,562 同量级但更大
--        （后者已过 ≥100 候选池过滤），可作合理性对照，非硬闸。


-- ==============================================================================================
--  §PK2 · 724 的法证明细（红队指定八列）
--  ----------------------------------------------------------------------------------------
--  逐 (round_key, lv4, lv3) 输出，仅限那 3 个问题节点，行数约 1,448 行以内。
--  ★ 关键新增列 n_members_in_cell：
--      = 1 ⇒ 同一局内【同一会员】的注单分属不同 lv3 ⇒ 属会员级换线或数据错，非代理图
--      > 1 ⇒ 不同会员共用同一 lv4 却挂不同 lv3 ⇒ 才是【代理关系并发多父】
--    这两种情形的修法完全不同，红队要求的八列本身分辨不出，故本条补此一列。
-- ==============================================================================================


-- -- PK2 -- 同局多父的逐格法证（含会员归属判别）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.dt                                                             AS bet_date,
         b.bet01,
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
),
bad AS (SELECT round_key, lv4, COUNT(DISTINCT lv3) AS parent_count
        FROM r WHERE lv4 IS NOT NULL AND lv3 IS NOT NULL
        GROUP BY round_key, lv4 HAVING COUNT(DISTINCT lv3) > 1)
SELECT x.round_key                                                        AS round_key,
       CAST(x.lv4 AS STRING)                                              AS child_id,
       CAST(x.lv3 AS STRING)                                              AS parent_id,
       MAX(bd.parent_count)                                               AS parent_count,
       COUNT(DISTINCT x.bet01)                                            AS n_distinct_bet01,
       COUNT(DISTINCT x.member_id)                                        AS n_members_in_cell,
       ROUND(SUM(x.stake), 4)                                             AS stake,
       MIN(x.bet_date)                                                    AS bet_date
FROM r x
JOIN bad bd ON bd.round_key = x.round_key AND bd.lv4 = x.lv4
WHERE x.lv3 IS NOT NULL
GROUP BY x.round_key, x.lv4, x.lv3;
--    判读规则（本件唯一允许的分类，因三种情形互斥且穷尽）：
--      甲 · 同一 (round_key, child) 的各行 n_members_in_cell 皆 = 1 且会员各不相同
--           ⇒ 不同会员挂同一 lv4 却报不同 lv3 ⇒【代理关系并发多父】⇒ HF9-A 须采 path-set / graph
--      乙 · 存在同一会员在同一局内出现于两个不同 lv3
--           ⇒ 同一注单事实被赋予两个上级 ⇒ 属【数据一致性缺陷】，须开 AGENT-CONSIST-01，
--              不得当作业务拓扑，HF9-A 不因此改模型
--      丙 · PK1 判定 round_key 跨日
--           ⇒ 724 是键碰撞产物 ⇒ 本条全部作废，须并入 bet_date 后重测
--    ★ 三者须先看 PK1 再判：PK1 不过，本条不得单独解读。


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条   | 耗时 | query_id | 返回值 | 判据结果
--  -----+------+----------+--------+------------------------------------------------------
--  PK0  |      |          |        | drift_rows = ? · drift_testline = ? · testline_id_checksum
--  PK1  |      |          |        | rk_span_multi_day 是否 = 0（决定 PK2 能否解读）
--  PK2  |      |          |        | 甲 / 乙 / 丙 三分之何者；行数约 ?
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已逐行单跑 Z00C  ② 是否串行  ③ 有无报错或超时
--  ----------------------------------------------------------------------------------------
--  ★ 本件不裁定任何业务判据。分位数是分布事实，不是门槛；
--    29,606 只称「结构候选池」；7 名极值会员之结构与多机制相容，当前无法区分；
--    3 个 lv4 异常节点在 PK1/PK2 判定前，一律只称「同局多父候选」，不称代理图。
-- ==============================================================================================
