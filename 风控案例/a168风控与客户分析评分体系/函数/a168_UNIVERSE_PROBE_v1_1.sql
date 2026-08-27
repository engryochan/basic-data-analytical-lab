-- ==============================================================================================
--  UNIVERSE-PROBE v1.1  ·  补测件（v1.0 未覆盖的三个盲区）
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.0 已跑毕（十七条全通，U0/G075/G080 三锚逐位相符）。
--  ----------------------------------------------------------------------------------------
--  v1.0 遗漏的三个盲区，本件补齐：
--    盲区一：G-PAIR 类件（#023 / #007 / #010 / #011）的容量完全未测。
--            v1.0 只测了 G-UNIVERSE（删主体），未测 G-PAIR（删配对）。
--            #023 现有 696,403 行，是全包最大的一张 CSV，其放大倍数至今 UNKNOWN。
--    盲区二：荷官测试线至今 UNKNOWN。employee 维表无测试标记列（DEALER-01 D1 已证），
--            但可【间接】识别：若某荷官的注单几乎全部来自测试线代理，则该荷官极可能是测试荷官。
--    盲区三：v1.0 的 Q075 测出 max_rounds = 484,046（139 天内每 24.8 秒一局，不眠不休），
--            此会员是否真人、是否机器人、是否聚合账号，至今未查。
--  ----------------------------------------------------------------------------------------
--  性质与纪律：同 v1.0 —— ★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁任何窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释
--    去重一律用 COUNT(DISTINCT bet01)（Gate-00-B 已 PROVEN 重复行为纯副本；
--    v1.0 的 U0 / G075 / G080 三锚实测逐位相符，该替换已【经验证实】，不再是假设）
--    串行执行，跑前逐行单跑 Z00C，一条一条来，任一条超 10 分钟即取消回报
-- ==============================================================================================


-- ==============================================================================================
--  §P1 · 盲区一：G-PAIR 类件的容量
-- ==============================================================================================


-- -- P1a -- #023 I_ip_player。粒度 IP × 会员，闸 COUNT(*) >= 30（源码 L5648）
--    已知锚：现有 CSV 696,403 行 · MD5 9496bfbe9f4c4346ff478eda6bc8854e
--    ⇒ groups_after 应 = 696,403。若不符，说明 #023 的 base 与本条不同源，须回查源码。
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         TRIM(b.ip)                                                       AS bet_ip
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
    AND NULLIF(TRIM(b.ip),'') IS NOT NULL
),
g AS (SELECT bet_ip, member_id, COUNT(DISTINCT bet01) AS n_rows FROM base GROUP BY bet_ip, member_id)
SELECT COUNT(*)                                                           AS pairs_before,
       SUM(CASE WHEN n_rows >= 30 THEN 1 ELSE 0 END)                      AS pairs_after,
       SUM(n_rows)                                                        AS rows_before,
       SUM(CASE WHEN n_rows >= 30 THEN n_rows ELSE 0 END)                 AS rows_after,
       COUNT(DISTINCT bet_ip)                                             AS n_ip,
       COUNT(DISTINCT member_id)                                          AS n_member
FROM g;


-- -- P1b -- #007 C01_ip_chain。粒度 bet_ip，闸 COUNT(DISTINCT member_id) >= 20（源码 L1879）
--    已知锚：现有 CSV 6,752 行 · MD5 40af3ccd25666e0564f26827f31f390f
--    本条另出 n_lv1..n_lv5 的可行性数据：五级代理在 IP 粒度上的实际基数，
--    供 HF8c 的 chain_spread / top_concentration 判断是否有判别力。
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01, TRIM(b.ip)                                              AS bet_ip,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)                         AS lv1,
         CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)                         AS lv3,
         CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)                         AS lv5
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
    AND NULLIF(TRIM(b.ip),'') IS NOT NULL
),
g AS (
  SELECT bet_ip,
         COUNT(DISTINCT member_id) AS n_member,
         COUNT(DISTINCT lv1)       AS n_lv1,
         COUNT(DISTINCT lv3)       AS n_lv3,
         COUNT(DISTINCT lv5)       AS n_lv5
  FROM base GROUP BY bet_ip
)
SELECT COUNT(*)                                                           AS ips_before,
       SUM(CASE WHEN n_member >= 20 THEN 1 ELSE 0 END)                    AS ips_after,
       SUM(CASE WHEN n_lv1 = 1 AND n_lv5 >= 3 THEN 1 ELSE 0 END)          AS ip_single_top_multi_tail,
       SUM(CASE WHEN n_lv1 >= 3 THEN 1 ELSE 0 END)                        AS ip_multi_top,
       MAX(n_lv1)                                                         AS max_lv1,
       MAX(n_lv3)                                                         AS max_lv3,
       MAX(n_lv5)                                                         AS max_lv5,
       AVG(n_lv1)                                                         AS avg_lv1,
       AVG(n_lv3)                                                         AS avg_lv3,
       AVG(n_lv5)                                                         AS avg_lv5
FROM g;
--    ★ 本条同时是 HF8c 的【价值验证】：
--      ip_single_top_multi_tail = 同一顶级代理旗下多条末端线共用 IP（团伙嫌疑最高）
--      ip_multi_top             = 多个互不相干顶代共用 IP（网吧/公共出口，风险低）
--      若二者数量都不为零，则证明 n_lv1/n_lv5 确有判别力，HF8c 的商业价值成立；
--      若 ip_single_top_multi_tail = 0，则须重新审视 chain_spread 的设计。


-- ==============================================================================================
--  §P2 · 盲区二：荷官测试线的【间接】识别
--  ----------------------------------------------------------------------------------------
--  DEALER-01 D1 已证 ods_a168_employee 无任何测试标记列（type=3 为荷官，enable=Y/N 为停启用）。
--  故无法直接判定。但可反向推断：
--    若某荷官（eid）在窗内的注单【几乎全部】来自测试线代理，则该荷官极可能只服务测试线。
--  ★ 本条只测量分布，【不得】据此直接把任何荷官判为测试荷官 ——
--    「近似条件 → 身份结论」是明令禁止的推理（UNKNOWN ≠ FALSE，SCREENING ≠ 定罪）。
-- ==============================================================================================


-- -- P2 -- 按荷官统计其注单中测试线占比
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01, TRIM(b.eid)                                             AS dealer_id,
         CASE WHEN COALESCE(t1.aid,t2.aid,t3.aid,t4.aid,t5.aid) IS NOT NULL
              THEN 1 ELSE 0 END                                           AS f_testline
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
    AND NULLIF(TRIM(b.eid),'') IS NOT NULL
    AND TRIM(b.eid) NOT IN ('-1', '0')
),
g AS (SELECT dealer_id,
             COUNT(DISTINCT bet01)                                        AS n_all,
             COUNT(DISTINCT CASE WHEN f_testline = 1 THEN bet01 END)      AS n_test
      FROM base GROUP BY dealer_id)
SELECT COUNT(*)                                                           AS n_dealers,
       SUM(CASE WHEN n_test = 0     THEN 1 ELSE 0 END)                    AS d_zero_test,
       SUM(CASE WHEN n_test = n_all THEN 1 ELSE 0 END)                    AS d_all_test,
       SUM(CASE WHEN n_test > 0 AND n_test < n_all THEN 1 ELSE 0 END)     AS d_mixed,
       SUM(n_all)                                                         AS rows_all,
       SUM(n_test)                                                        AS rows_test,
       MAX(n_all)                                                         AS max_rows_per_dealer,
       MIN(n_all)                                                         AS min_rows_per_dealer
FROM g;
--    判读指引（仅供 GATE 审议，不得在本件内下结论）：
--      d_all_test > 0 ⇒ 存在【只服务测试线】的荷官 ⇒ 荷官测试线【客观存在】，
--                       且现行清洗已把他们连同注单一并剔除（因其注单全为测试线）
--      d_all_test = 0 ⇒ 无荷官只服务测试线 ⇒ 「荷官测试线」这一概念可能不成立，
--                       DEALER-01 可结案为 NOT_ESTABLISHED
--      d_mixed  > 0  ⇒ 有荷官同时服务真实与测试注单 ⇒ 荷官身份与测试线【不同轴】，
--                       不可用注单来源反推荷官身份


-- ==============================================================================================
--  §P3 · 盲区三：极值会员核查
--  ----------------------------------------------------------------------------------------
--  v1.0 Q075 实测 max_rounds = 484,046。139 天 ⇒ 每日 3,482 局 ⇒ 平均 24.8 秒一局，
--  且须 139 天不眠不休。此非人类可为。须查明其性质。
--  ★ 禁 ORDER BY，故改用【阈值分桶】而非 TOP-N。
-- ==============================================================================================


-- -- P3 -- 超高频会员的规模与结构（不排序，只分桶）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         TRIM(b.ip)                                                       AS bet_ip,
         b.bet39                                                          AS table_id,
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
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
g AS (
  SELECT member_id,
         COUNT(DISTINCT round_key)                                        AS n_rounds,
         COUNT(DISTINCT bet_ip)                                           AS n_ip,
         COUNT(DISTINCT table_id)                                         AS n_table,
         COUNT(DISTINCT bet_date)                                         AS n_days
  FROM base GROUP BY member_id
)
SELECT SUM(CASE WHEN n_rounds >= 100000 THEN 1 ELSE 0 END)                AS m_ge_100k,
       SUM(CASE WHEN n_rounds >=  50000 AND n_rounds < 100000 THEN 1 ELSE 0 END) AS m_50k_100k,
       SUM(CASE WHEN n_rounds >=  20000 AND n_rounds <  50000 THEN 1 ELSE 0 END) AS m_20k_50k,
       SUM(CASE WHEN n_rounds >=  10000 AND n_rounds <  20000 THEN 1 ELSE 0 END) AS m_10k_20k,
       SUM(CASE WHEN n_rounds >= 100000 THEN n_rounds ELSE 0 END)         AS rounds_in_ge100k,
       MAX(CASE WHEN n_rounds >= 100000 THEN n_ip   ELSE NULL END)        AS max_ip_in_ge100k,
       MAX(CASE WHEN n_rounds >= 100000 THEN n_table ELSE NULL END)       AS max_table_in_ge100k,
       MAX(CASE WHEN n_rounds >= 100000 THEN n_days ELSE NULL END)        AS max_days_in_ge100k,
       MIN(CASE WHEN n_rounds >= 100000 THEN n_days ELSE NULL END)        AS min_days_in_ge100k
FROM g;
--    判读指引（仅供 GATE 审议）：
--      n_days 若 = 139 且 n_table 极大 ⇒ 极可能是聚合账号或机器人，须单列不得混入评分
--      n_ip   若 = 1                   ⇒ 单一出口，接口/脚本特征
--      n_ip   若极大                   ⇒ 多人共用账号特征
--      ★ 无论何种，在 AG-03 与 DECISION-GATE 未过之前，一律不得据此处置。


-- ==============================================================================================
--  §P4 · 补测：14 件主体分析件中 q 侧【无】测试线剔除者的污染规模
--  ----------------------------------------------------------------------------------------
--  经 HF8b 源码全扫：129 件中 44 件 q 侧含五级测试线剔除，85 件无。
--  85 件里 14 件属主体分析件（其余为字典/核验件，本就该看原始数据）。
--  以荷官关联件 #070 R03_player_dealer 为代表，量其测试线污染。
-- ==============================================================================================


-- -- P4 -- 荷官 × 会员 配对中的测试线污染
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT b.bet01, TRIM(b.eid)                                             AS dealer_id,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CASE WHEN COALESCE(t1.aid,t2.aid,t3.aid,t4.aid,t5.aid) IS NOT NULL
              THEN 1 ELSE 0 END                                           AS f_testline
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
    AND NULLIF(TRIM(b.eid),'') IS NOT NULL
    AND TRIM(b.eid) NOT IN ('-1', '0')
),
g AS (SELECT dealer_id, member_id,
             COUNT(DISTINCT bet01)                                        AS n_all,
             COUNT(DISTINCT CASE WHEN f_testline = 1 THEN bet01 END)      AS n_test
      FROM base GROUP BY dealer_id, member_id)
SELECT COUNT(*)                                                           AS pairs_all,
       SUM(CASE WHEN n_test > 0 THEN 1 ELSE 0 END)                        AS pairs_touched_by_test,
       SUM(CASE WHEN n_test = n_all THEN 1 ELSE 0 END)                    AS pairs_pure_test,
       SUM(n_all)                                                         AS rows_all,
       SUM(n_test)                                                        AS rows_test
FROM g;


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑者写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条  | 耗时 | query_id | 返回值 | 与已知锚是否相符
--  ----+------+----------+--------+------------------
--  P1a |      |          |        | 锚 pairs_after = 696,403
--  P1b |      |          |        | 锚 ips_after = 6,752
--  P2  |      |          |        | 无锚，首测
--  P3  |      |          |        | 无锚，首测（Q075 已知 max = 484,046）
--  P4  |      |          |        | 无锚，首测
-- ==============================================================================================
