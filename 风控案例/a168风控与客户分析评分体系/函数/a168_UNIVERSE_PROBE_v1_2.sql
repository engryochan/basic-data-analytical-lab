-- ==============================================================================================
--  UNIVERSE-PROBE v1.2  ·  最后一轮探查（四条）
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.0 十七条 ACCEPTED（三锚全中）；v1.1 五条中 P1b 因 W-38 作废，其余四条 ACCEPTED。
--  ----------------------------------------------------------------------------------------
--  ★ W-38 说明（本件存在的第一理由）
--    v1.1 的 P1b 只取了 lv1 / lv3 / lv5，漏掉 lv2（bet19）与 lv4（bet21）。
--    动机是「让查询轻一点」—— 这与 #069 把门槛由 100 抬到 300「降内存」是同一种错误：
--    【让计算资源决定分析口径】。P1b v1.1 作废，不得作为 HF8c 证据。本件 P1b-fix 五级齐全。
--  ----------------------------------------------------------------------------------------
--  性质与纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释
--    去重一律 COUNT(DISTINCT bet01)（Gate-00-B 已 PROVEN；v1.0/v1.1 六锚实测逐位相符）
--    清洗一律用 U* 口径（U* = 723,442 会员 / 124,713,543 注单，五级测试线已剔）
--    串行执行，先跑 Z00C；任一条超 10 分钟立即取消，不重试、不双开
--  ----------------------------------------------------------------------------------------
--  已知锚（自证用）
--    P1b-fix : ips_before = 1,326,575 · ips_after = 6,752（C01 CSV 行数）
--              n_lv3 相关值须与 v1.1 P1b 完全一致：ip_multi_top 一项不比对（定义改了），
--              但 max_lv3 = 23 · avg_lv3 = 1.6852646853739894 须逐位相同 —— 这是「新旧同源」之证
--    P5      : 无锚，首测。#069 现行门槛 300，源码 L16783
--    P6      : 无锚，首测。#083 主体数现行 26,941、去闸后 723,442（v1.0 G083 已测）
-- ==============================================================================================


-- ==============================================================================================
--  §P1b-fix · 五级代理链在 IP 粒度的完整基数与【逐行】单调性
--  ----------------------------------------------------------------------------------------
--  五级为严格嵌套下行链，故任一 IP 上必然 n_lv1 <= n_lv2 <= n_lv3 <= n_lv4 <= n_lv5。
--  ★ 单调性须【逐行】验证，不得只比 AVG/MAX —— 均值单调无法排除个别行反序。
--  ★ NULL 与 '0' 的处理（CHAIN-01 相关，该案仍冻结）：
--      lv 层为空表示代理链短于五级，非错误。故计数用 COALESCE(...,-1)，
--      把「无此层」当作一个独立分支，单调性方有意义。
--      另 CHAIN-01 已实测 lv5='0' 占全窗注额 3.49%，'0' 是合法数字，
--      故本条另出 n_lv5_zero_ip 与 n_lv5_nz（把 '0' 视同无值）两组，供 GATE 对照。
--  ★ 单调性成立 ≠ 五级身份映射正确。身份映射另由 §P1c 验。
-- ==============================================================================================


-- -- P1b-fix -- IP 粒度五级基数 + 逐行单调性闸
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT TRIM(b.ip)                                                       AS bet_ip,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         COALESCE(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT), -1)           AS lv1,
         COALESCE(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT), -1)           AS lv2,
         COALESCE(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), -1)           AS lv3,
         COALESCE(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), -1)           AS lv4,
         COALESCE(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), -1)           AS lv5,
         COALESCE(NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), 0), -1) AS lv5_nz,
         CASE WHEN CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT) = 0 THEN 1 ELSE 0 END AS f_lv5_zero
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
         COUNT(DISTINCT member_id)                                        AS n_member,
         COUNT(DISTINCT lv1)                                              AS n_lv1,
         COUNT(DISTINCT lv2)                                              AS n_lv2,
         COUNT(DISTINCT lv3)                                              AS n_lv3,
         COUNT(DISTINCT lv4)                                              AS n_lv4,
         COUNT(DISTINCT lv5)                                              AS n_lv5,
         COUNT(DISTINCT lv5_nz)                                           AS n_lv5_nz,
         MAX(f_lv5_zero)                                                  AS has_lv5_zero
  FROM base GROUP BY bet_ip
)
SELECT COUNT(*)                                                           AS ips_before,
       SUM(CASE WHEN n_member >= 20 THEN 1 ELSE 0 END)                    AS ips_after,
       SUM(CASE WHEN NOT (n_lv1 <= n_lv2 AND n_lv2 <= n_lv3
                      AND n_lv3 <= n_lv4 AND n_lv4 <= n_lv5)
                THEN 1 ELSE 0 END)                                        AS n_monotonic_violation,
       SUM(CASE WHEN n_lv1 = 1 AND n_lv5 >= 3 THEN 1 ELSE 0 END)          AS ip_single_top_multi_tail,
       SUM(CASE WHEN n_lv1 >= 3 THEN 1 ELSE 0 END)                        AS ip_multi_top,
       SUM(has_lv5_zero)                                                  AS n_ip_with_lv5_zero,
       MAX(n_lv1) AS max_lv1, MAX(n_lv2) AS max_lv2, MAX(n_lv3) AS max_lv3,
       MAX(n_lv4) AS max_lv4, MAX(n_lv5) AS max_lv5, MAX(n_lv5_nz) AS max_lv5_nz,
       AVG(n_lv1) AS avg_lv1, AVG(n_lv2) AS avg_lv2, AVG(n_lv3) AS avg_lv3,
       AVG(n_lv4) AS avg_lv4, AVG(n_lv5) AS avg_lv5
FROM g;
--    验收判据（三条，任一不满足即停手回报）：
--      ① n_monotonic_violation 必须 = 0。非零即证 lv 层的取值或映射有误，HF8c 不得施工。
--      ② max_lv3 必须 = 23 且 avg_lv3 必须 = 1.6852646853739894（与 v1.1 P1b 逐位相同）。
--         此为「新旧同源」之证：若不同，说明 COALESCE(...,-1) 改变了 lv3 的计数语义，须回查。
--      ③ ips_before = 1,326,575 · ips_after = 6,752（C01_ip_chain CSV 行数）。


-- ==============================================================================================
--  §P1c · 五级【身份映射】验证（单调性所不能证明的那一半）
--  ----------------------------------------------------------------------------------------
--  严格嵌套树的充要特征是：每个下层代理有且只有一个上层父代理。
--  故：任一 lv5 应只对应一个 lv4、一个 lv3、一个 lv2、一个 lv1。
--  若存在 lv5 对应多个 lv1，则五级链【不是树】，chain_key 的语义不成立，HF8c 须重新设计。
--  ★ 这正是「单调性成立 ≠ 五级代理身份正确」的那一半，必须单独验。
-- ==============================================================================================


-- -- P1c -- 每个 lv5 的父代理是否唯一（自 bet18~bet22 的实际对应关系直接验）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT COALESCE(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT), -1)           AS lv1,
         COALESCE(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT), -1)           AS lv2,
         COALESCE(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), -1)           AS lv3,
         COALESCE(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), -1)           AS lv4,
         COALESCE(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), -1)           AS lv5,
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
p5 AS (SELECT lv5, COUNT(DISTINCT lv4) AS n_p4, COUNT(DISTINCT lv3) AS n_p3,
              COUNT(DISTINCT lv2) AS n_p2, COUNT(DISTINCT lv1) AS n_p1
       FROM base GROUP BY lv5),
p4 AS (SELECT lv4, COUNT(DISTINCT lv3) AS n_p3, COUNT(DISTINCT lv1) AS n_p1
       FROM base GROUP BY lv4),
p3 AS (SELECT lv3, COUNT(DISTINCT lv2) AS n_p2, COUNT(DISTINCT lv1) AS n_p1
       FROM base GROUP BY lv3),
pm AS (SELECT member_id, COUNT(DISTINCT lv5) AS n_lv5, COUNT(DISTINCT lv1) AS n_lv1
       FROM base GROUP BY member_id)
SELECT (SELECT COUNT(*) FROM p5)                                          AS n_lv5_agents,
       (SELECT SUM(CASE WHEN n_p4 > 1 THEN 1 ELSE 0 END) FROM p5)         AS lv5_multi_parent4,
       (SELECT SUM(CASE WHEN n_p1 > 1 THEN 1 ELSE 0 END) FROM p5)         AS lv5_multi_top1,
       (SELECT COUNT(*) FROM p4)                                          AS n_lv4_agents,
       (SELECT SUM(CASE WHEN n_p3 > 1 THEN 1 ELSE 0 END) FROM p4)         AS lv4_multi_parent3,
       (SELECT SUM(CASE WHEN n_p1 > 1 THEN 1 ELSE 0 END) FROM p4)         AS lv4_multi_top1,
       (SELECT COUNT(*) FROM p3)                                          AS n_lv3_agents,
       (SELECT SUM(CASE WHEN n_p2 > 1 THEN 1 ELSE 0 END) FROM p3)         AS lv3_multi_parent2,
       (SELECT SUM(CASE WHEN n_p1 > 1 THEN 1 ELSE 0 END) FROM p3)         AS lv3_multi_top1,
       (SELECT COUNT(*) FROM pm)                                          AS n_members,
       (SELECT SUM(CASE WHEN n_lv5 > 1 THEN 1 ELSE 0 END) FROM pm)        AS member_multi_lv5,
       (SELECT SUM(CASE WHEN n_lv1 > 1 THEN 1 ELSE 0 END) FROM pm)        AS member_multi_lv1
FROM (SELECT 1) z;
--    验收判据：
--      ① lv5_multi_parent4 / lv5_multi_top1 / lv4_multi_parent3 / lv4_multi_top1
--         / lv3_multi_parent2 / lv3_multi_top1 全部 = 0 ⇒ 五级链【是树】，chain_key 语义成立
--      ② 任一不为零 ⇒ 五级链【不是树】，chain_key 必须改为「路径集合」而非单一字符串，
--         HF8c 的 CONCAT_WS 设计须重做。此为 HF8c 的生死判据。
--      ③ member_multi_lv5 / member_multi_lv1 > 0 ⇒ 窗内确有会员换线 ⇒
--         这是「零换线」命题的【独立验证】（此前只有 n_chain≡1 这一死列，不足为证）。
--         注意：本条只测有无，不下「换线原因」之结论。
--    ★ n_lv3_agents 应 = 376（v1.1 P1b 实测 lv3 唯一值数），可作同源锚。


-- ==============================================================================================
--  §P5 · #069 R02_same_table 自连接的【精确】产出规模（v1.2 的生死闸）
--  ----------------------------------------------------------------------------------------
--  #069 源码 L16788-16797：mr2 自连接 ON x.round_key = y.round_key AND x.member_id < y.member_id
--  ⇒ 中间产出行数恰为 Σ over round_key of C(k,2)，k = 该局内候选池会员数。
--  ★ 本条【不做自连接】，直接算 Σ C(k,2)，故零 OOM 风险，却给出精确答案。
--  ★ 同时给出 100 与 300 两个门槛的对照，以裁定「300 → 100 复原」是否可执行。
--  ★ 纪律：不得因为「看起来很大」就擅自改回 300。资源问题由分批与执行计划解决。
--  ★ 口径修正：#069 现行 q 侧【无测试线剔除】（HF9-C 待修）。本条【已加】五级剔除，
--    即测量的是【修复后】的规模。另出未剔除口径无意义，故不出。
-- ==============================================================================================


-- -- P5 -- #069 配对规模精确测算（Σ C(k,2)，禁自连接）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
mr AS (
  SELECT DISTINCT
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
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
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
act AS (SELECT member_id, COUNT(*) AS n_rounds FROM mr GROUP BY member_id),
j AS (SELECT m.round_key, a.n_rounds FROM mr m JOIN act a ON a.member_id = m.member_id),
r AS (
  SELECT round_key,
         CAST(SUM(CASE WHEN n_rounds >= 100 THEN 1 ELSE 0 END) AS BIGINT)  AS k100,
         CAST(SUM(CASE WHEN n_rounds >= 300 THEN 1 ELSE 0 END) AS BIGINT)  AS k300
  FROM j GROUP BY round_key
)
SELECT (SELECT COUNT(*) FROM act)                                         AS all_members,
       (SELECT SUM(CASE WHEN n_rounds >= 100 THEN 1 ELSE 0 END) FROM act) AS candidate_members_100,
       (SELECT SUM(CASE WHEN n_rounds >= 300 THEN 1 ELSE 0 END) FROM act) AS candidate_members_300,
       (SELECT COUNT(*) FROM mr)                                          AS mr_rows,
       COUNT(*)                                                           AS candidate_rounds,
       SUM(k100 * (k100 - 1) / 2)                                         AS pairs_rows_100,
       SUM(k300 * (k300 - 1) / 2)                                         AS pairs_rows_300,
       MAX(k100)                                                          AS max_k100,
       MAX(k300)                                                          AS max_k300,
       PERCENTILE_APPROX(k100, 0.50)                                      AS k100_p50,
       PERCENTILE_APPROX(k100, 0.90)                                      AS k100_p90,
       PERCENTILE_APPROX(k100, 0.99)                                      AS k100_p99
FROM r;
--    判读（仅供 GATE 审议）：
--      pairs_rows_100 即恢复业务判据 100 后，自连接的【精确】中间行数。
--      ratio = pairs_rows_100 / pairs_rows_300 即源码注释所称「约一个数量级」之实测值 ——
--      源码当时是【预言】，本条是【实测】，二者若不符，须以实测为准并更正源码注释。
--      ★ 若 pairs_rows_100 过大，正解是【分批 + 按 table_id 或 bet_date 切片】，
--        绝不是把门槛改回 300。


-- ==============================================================================================
--  §P6 · #083 T02_daily_roi 的【输出粒度】规模与决策层权重偏斜
--  ----------------------------------------------------------------------------------------
--  源码 L20221-20226：q 侧输出粒度为 member_id × bet_date（不是 member_id）。
--  v1.0 的 G083 只测了主体（会员）数：26,941 → 723,442（26.85×），
--  但【输出行数】至今未知 —— 这才是真正的容量闸。
--  ----------------------------------------------------------------------------------------
--  ★ 本条另测一项 v1.0/v1.1 均未触及的结构问题：
--    #083 外层以 LEFT JOIN x_agg 取【会员级】六层商业列，再在 member × day 粒度上
--    施加 PERCENT_RANK() / NTILE() 且【无 PARTITION】（源码 L20288-20297）。
--    ⇒ 同一会员的 residual_b 在其每个活跃日各重复一次，参与排名。
--    ⇒ 活跃日多的会员在分位分布中被【加权】，PERCENT_RANK 不等于会员分位。
--    本条以 rows / members 之比与 n_days 的极差，量化该加权的非均匀程度。
--    ★ 只量不裁：本条不判定该设计对错，只提供 GATE 裁定所需的量。
-- ==============================================================================================


-- -- P6 -- #083 输出行数（member × day）与决策层权重偏斜
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
),
md AS (SELECT member_id, bet_date, COUNT(DISTINCT bet01) AS n_rows
       FROM base GROUP BY member_id, bet_date),
mm AS (SELECT member_id, COUNT(*) AS n_days, SUM(n_rows) AS n_rows FROM md GROUP BY member_id)
SELECT (SELECT COUNT(*) FROM mm)                                          AS members_all,
       (SELECT SUM(CASE WHEN n_days >= 20 THEN 1 ELSE 0 END) FROM mm)     AS members_ge20d,
       COUNT(*)                                                           AS out_rows_all,
       SUM(CASE WHEN m.n_days >= 20 THEN 1 ELSE 0 END)                    AS out_rows_ge20d,
       MAX(m.n_days)                                                      AS max_days,
       MIN(m.n_days)                                                      AS min_days,
       PERCENTILE_APPROX(m.n_days, 0.50)                                  AS days_p50,
       PERCENTILE_APPROX(m.n_days, 0.90)                                  AS days_p90,
       PERCENTILE_APPROX(m.n_days, 0.99)                                  AS days_p99
FROM md d JOIN mm m ON m.member_id = d.member_id;
--    判读（仅供 GATE 审议）：
--      out_rows_ge20d = #083 现行 CSV 的行数（未曾导出，故无锚，本条即为首测）
--      out_rows_all   = 取消宇宙门后的 CSV 行数 ⇒ 除以 100000 即批数
--      max_days / min_days 之比 = 决策层 PERCENT_RANK 的最大权重倍数。
--      若 max_days = 139 而 min_days = 1，则单一会员在分位分布中的权重最多相差 139 倍。


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条       | 耗时 | query_id | 返回值 | 锚点/判据结果
--  ---------+------+----------+--------+---------------------------------------------
--  P1b-fix  |      |          |        | 单调性违反数必须 = 0 · max_lv3 = 23 ·
--           |      |          |        | avg_lv3 = 1.6852646853739894 · ips_after = 6,752
--  P1c      |      |          |        | 六个 multi_parent 计数必须全 = 0 · n_lv3_agents = 376
--  P5       |      |          |        | pairs_rows_100 / pairs_rows_300 / ratio
--  P6       |      |          |        | out_rows_all / out_rows_ge20d / max_days / min_days
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已跑 Z00C  ② 是否串行  ③ 有无报错或超时
-- ==============================================================================================
