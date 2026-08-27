-- ==============================================================================================
--  UNIVERSE-PROBE v1.3  ·  六条 · 拆「树、平方项、粒度」三颗雷的最后一轮
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.0 十七条 ACCEPTED · v1.1 四条 ACCEPTED（P1b 因 W-38 作废）
--        v1.2 四条已跑：P1b-fix ②③ PASS / ① FAIL(48) · P1c FAIL(2,7,4,4,1,1) · P5 PASS · P6 口径失效
--  ----------------------------------------------------------------------------------------
--  ★ 本件存在的三个理由（全部是我的错，先登记再修）
--    W-39  P1c 的锚点 n_lv3_agents = 376 是我设错的参照系。376 出自 I_ip_player.csv
--          （已过 COUNT(*)>=30 配对闸），455 出自全宇宙 U*。两者本非同一 population。
--          交叉验证：全平台 LV3 共 460 名，扣测试线后 455，内部自洽。锚作废，非数据问题。
--    W-41  P6 写了五个 LEFT JOIN ta 却漏写 AND COALESCE(t1.aid,...,t5.aid) IS NULL，
--          五个 JOIN 成死代码，测量含测试线。铁证：members_all = 723,496（U2）而非 723,442（U*）；
--          members_ge20d = 26,942 而 v1.0 G083 实测 26,941，恰多 1 名。本件 P6-fix 以 U* 重测。
--    W-42  P1b-fix / P1c 用 COALESCE(...,-1) 平哨兵，把【所有】「该层无代理」压成同一个桶。
--          于是同一 IP 上 (1|2|3|-|-) 与 (1|2|9|-|-) 两条链：n_lv3 = 2 而 n_lv4 = 1 ⇒ 单调性被破。
--          48 / 1,326,575 = 0.0036%，量级与「少数短链共处一 IP」相符。
--          同一缺陷污染 P1c：lv5 = -1 组装的是全部短于五级的链，lv5 = 0 组是 CHAIN-01 的合法零值，
--          二者天然多父。故 7 个 lv5_multi_top1 里至少 2 个是假节点。
--          ⇒ 本件改用【路径继承哨兵】：终止标记带上父路径，使不同终止点保持可分辨。
--  ----------------------------------------------------------------------------------------
--  性质与纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    去重一律 COUNT(DISTINCT bet01) 或 SELECT DISTINCT（Gate-00-B 已 PROVEN，六锚已实证）
--    清洗一律 U* 口径（723,442 会员 / 124,713,543 注单，五级测试线已剔）
--    ★ 不合并多路 COUNT(DISTINCT)：宁可多扫几遍，不做十路 distinct（StarRocks 内存杀手）
--    串行执行，先逐行单跑 Z00C；任一条超 10 分钟立即取消，不重试、不双开
--  ----------------------------------------------------------------------------------------
--  ★ 本件不裁定任何业务判据。分位数是分布事实，不是门槛；
--    29,606 只称「结构候选池」，不称团伙；multi_parent 归零只证结构，不证身份无异常。
-- ==============================================================================================


-- ==============================================================================================
--  §P1d · 逐层 NULL / ZERO 全普查（红队 §2 指定）
--  ----------------------------------------------------------------------------------------
--  仅靠 n_lv1<=...<=n_lv5 的计数比较，无法证明链本身合法。例如 lv1=123 / lv2=NULL / lv3=456
--  这种「中断后又续」的链，计数比较不会报错。故须先把每层的空值与零值分别数清。
--  ★ 去重用 SELECT DISTINCT bet01+五级列（内层），外层纯 SUM，不做多路 distinct。
-- ==============================================================================================


-- -- P1d -- 五级各层的 NULL 与 0 的注单数（U* 口径）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
d AS (
  SELECT DISTINCT
         b.bet01,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)                         AS lv1,
         CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)                         AS lv2,
         CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)                         AS lv3,
         CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)                         AS lv4,
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
)
SELECT COUNT(*)                                                           AS n_rows_dedup,
       SUM(CASE WHEN lv1 IS NULL THEN 1 ELSE 0 END)                       AS lv1_null,
       SUM(CASE WHEN lv2 IS NULL THEN 1 ELSE 0 END)                       AS lv2_null,
       SUM(CASE WHEN lv3 IS NULL THEN 1 ELSE 0 END)                       AS lv3_null,
       SUM(CASE WHEN lv4 IS NULL THEN 1 ELSE 0 END)                       AS lv4_null,
       SUM(CASE WHEN lv5 IS NULL THEN 1 ELSE 0 END)                       AS lv5_null,
       SUM(CASE WHEN lv1 = 0 THEN 1 ELSE 0 END)                           AS lv1_zero,
       SUM(CASE WHEN lv2 = 0 THEN 1 ELSE 0 END)                           AS lv2_zero,
       SUM(CASE WHEN lv3 = 0 THEN 1 ELSE 0 END)                           AS lv3_zero,
       SUM(CASE WHEN lv4 = 0 THEN 1 ELSE 0 END)                           AS lv4_zero,
       SUM(CASE WHEN lv5 = 0 THEN 1 ELSE 0 END)                           AS lv5_zero,
       SUM(CASE WHEN lv1 IS NOT NULL AND lv1 <> 0
                 AND lv2 IS NULL
                 AND lv3 IS NOT NULL AND lv3 <> 0 THEN 1 ELSE 0 END)      AS gap_lv2_broken,
       SUM(CASE WHEN lv3 IS NOT NULL AND lv3 <> 0
                 AND lv4 IS NULL
                 AND lv5 IS NOT NULL AND lv5 <> 0 THEN 1 ELSE 0 END)      AS gap_lv4_broken,
       COUNT(DISTINCT member_id)                                          AS n_members
FROM d;
--    验收判据：
--      ① n_rows_dedup 必须 = 124,713,543 · n_members 必须 = 723,442（U* 锚，逐位相符）
--      ② gap_lv2_broken / gap_lv4_broken 必须 = 0。非零即证存在「中断后又续」的非法链，
--         此时 chain_key 的层位语义崩塌，HF9-A 必须重新设计，不得只改哨兵。
--      ③ lv5_zero 应与 CHAIN-01 已锁的 638,864 笔同量级（CHAIN-01 仍冻结，此处只作对照，不解冻）


-- ==============================================================================================
--  §P1e · 路径继承哨兵下的逐行单调性（修 W-42）
--  ----------------------------------------------------------------------------------------
--  平哨兵 -1 把不同深度的终止点压成同一桶，故 n_lv3 可能大于 n_lv4。
--  路径继承哨兵令终止标记带上父路径：
--      k1 = lv1 或 '~'
--      k2 = lv2 或 CONCAT('~', k1)
--      k3 = lv3 或 CONCAT('~', k2)   …依此类推
--  于是 (1|2|3|终止) 与 (1|2|9|终止) 的第四层分别为 '~3' 与 '~9'，仍可分辨，
--  单调性由构造保证。若本条仍有违反，则问题在数据而非哨兵，HF9-A 须彻底重做。
--  ★ 本条同时保留平哨兵版计数，两版并出，差值即哨兵伪影的精确规模。
-- ==============================================================================================


-- -- P1e -- IP 粒度：路径继承哨兵 vs 平哨兵，逐行单调性对照
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT TRIM(b.ip)                                                       AS bet_ip,
         CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)                         AS e1,
         CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)                         AS e2,
         CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)                         AS e3,
         CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)                         AS e4,
         CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)                         AS e5,
         COALESCE(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT), -1)           AS f1,
         COALESCE(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT), -1)           AS f2,
         COALESCE(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), -1)           AS f3,
         COALESCE(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), -1)           AS f4,
         COALESCE(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), -1)           AS f5
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
a1 AS (SELECT bet_ip, e2, e3, e4, e5, f1, f2, f3, f4, f5,
              COALESCE(CAST(e1 AS STRING), '~')                           AS k1
       FROM base),
a2 AS (SELECT bet_ip, e3, e4, e5, f1, f2, f3, f4, f5, k1,
              COALESCE(CAST(e2 AS STRING), CONCAT('~', k1))               AS k2
       FROM a1),
a3 AS (SELECT bet_ip, e4, e5, f1, f2, f3, f4, f5, k1, k2,
              COALESCE(CAST(e3 AS STRING), CONCAT('~', k2))               AS k3
       FROM a2),
a4 AS (SELECT bet_ip, e5, f1, f2, f3, f4, f5, k1, k2, k3,
              COALESCE(CAST(e4 AS STRING), CONCAT('~', k3))               AS k4
       FROM a3),
a5 AS (SELECT bet_ip, f1, f2, f3, f4, f5, k1, k2, k3, k4,
              COALESCE(CAST(e5 AS STRING), CONCAT('~', k4))               AS k5
       FROM a4),
g AS (
  SELECT bet_ip,
         COUNT(DISTINCT k1) AS n_k1, COUNT(DISTINCT k2) AS n_k2,
         COUNT(DISTINCT k3) AS n_k3, COUNT(DISTINCT k4) AS n_k4,
         COUNT(DISTINCT k5) AS n_k5,
         COUNT(DISTINCT f1) AS n_f1, COUNT(DISTINCT f2) AS n_f2,
         COUNT(DISTINCT f3) AS n_f3, COUNT(DISTINCT f4) AS n_f4,
         COUNT(DISTINCT f5) AS n_f5
  FROM a5 GROUP BY bet_ip
)
SELECT COUNT(*)                                                           AS ips_before,
       SUM(CASE WHEN NOT (n_f1 <= n_f2 AND n_f2 <= n_f3
                      AND n_f3 <= n_f4 AND n_f4 <= n_f5)
                THEN 1 ELSE 0 END)                                        AS flat_violation,
       SUM(CASE WHEN NOT (n_k1 <= n_k2 AND n_k2 <= n_k3
                      AND n_k3 <= n_k4 AND n_k4 <= n_k5)
                THEN 1 ELSE 0 END)                                        AS inherit_violation,
       MAX(n_k1) AS max_k1, MAX(n_k2) AS max_k2, MAX(n_k3) AS max_k3,
       MAX(n_k4) AS max_k4, MAX(n_k5) AS max_k5,
       MAX(n_f1) AS max_f1, MAX(n_f3) AS max_f3, MAX(n_f5) AS max_f5
FROM g;
--    验收判据：
--      ① flat_violation 必须 = 48（与 v1.2 P1b-fix 逐位相同）⇒ 本条与前条同源，可比
--      ② inherit_violation 必须 = 0 ⇒ 路径继承哨兵消除伪影，W-42 假说成立，
--         HF9-A 的计数列改用继承哨兵即可，无须重做设计
--      ③ 若 inherit_violation 仍 > 0 ⇒ 问题在数据而非哨兵，HF9-A 彻底 BLOCK，
--         须改由 §P1d 的 gap_* 两数定位断链位置


-- ==============================================================================================
--  §P1f · 树检验（排除哨兵与零值）＋ 孤儿检验（红队 §3 指定）
--  ----------------------------------------------------------------------------------------
--  v1.2 P1c 的 multi_parent 非零，但 lv5 = -1 组装的是全部短链、lv5 = 0 是 CHAIN-01 的合法零值，
--  二者天然多父。本条【只对真实代理】（IS NOT NULL 且 <> 0）做父唯一性检验。
--  ★ 红队 §3 正确指出：multi_parent 只查「多父」，查不到「零父」。
--    严格树要求 parent_count 恰为 1，故本条同出 zero_parent 与 multi_parent 两组。
-- ==============================================================================================


-- -- P1f -- 真实代理的父唯一性（零父 / 多父 双查）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)                         AS lv1,
         CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT)                         AS lv2,
         CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT)                         AS lv3,
         CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT)                         AS lv4,
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
),
r AS (SELECT lv1, lv2, lv3, lv4, lv5 FROM base
      WHERE lv1 IS NOT NULL AND lv1 <> 0),
p5 AS (SELECT lv5,
              COUNT(DISTINCT CASE WHEN lv4 IS NOT NULL AND lv4 <> 0 THEN lv4 END) AS np4,
              COUNT(DISTINCT lv1)                                                 AS np1
       FROM r WHERE lv5 IS NOT NULL AND lv5 <> 0 GROUP BY lv5),
p4 AS (SELECT lv4,
              COUNT(DISTINCT CASE WHEN lv3 IS NOT NULL AND lv3 <> 0 THEN lv3 END) AS np3,
              COUNT(DISTINCT lv1)                                                 AS np1
       FROM r WHERE lv4 IS NOT NULL AND lv4 <> 0 GROUP BY lv4),
p3 AS (SELECT lv3,
              COUNT(DISTINCT CASE WHEN lv2 IS NOT NULL AND lv2 <> 0 THEN lv2 END) AS np2,
              COUNT(DISTINCT lv1)                                                 AS np1
       FROM r WHERE lv3 IS NOT NULL AND lv3 <> 0 GROUP BY lv3),
p2 AS (SELECT lv2, COUNT(DISTINCT lv1)                                            AS np1
       FROM r WHERE lv2 IS NOT NULL AND lv2 <> 0 GROUP BY lv2)
SELECT (SELECT COUNT(*) FROM p5)                                          AS n_lv5_real,
       (SELECT SUM(CASE WHEN np4 = 0 THEN 1 ELSE 0 END) FROM p5)          AS lv5_zero_parent4,
       (SELECT SUM(CASE WHEN np4 > 1 THEN 1 ELSE 0 END) FROM p5)          AS lv5_multi_parent4,
       (SELECT SUM(CASE WHEN np1 > 1 THEN 1 ELSE 0 END) FROM p5)          AS lv5_multi_top1,
       (SELECT COUNT(*) FROM p4)                                          AS n_lv4_real,
       (SELECT SUM(CASE WHEN np3 = 0 THEN 1 ELSE 0 END) FROM p4)          AS lv4_zero_parent3,
       (SELECT SUM(CASE WHEN np3 > 1 THEN 1 ELSE 0 END) FROM p4)          AS lv4_multi_parent3,
       (SELECT SUM(CASE WHEN np1 > 1 THEN 1 ELSE 0 END) FROM p4)          AS lv4_multi_top1,
       (SELECT COUNT(*) FROM p3)                                          AS n_lv3_real,
       (SELECT SUM(CASE WHEN np2 = 0 THEN 1 ELSE 0 END) FROM p3)          AS lv3_zero_parent2,
       (SELECT SUM(CASE WHEN np2 > 1 THEN 1 ELSE 0 END) FROM p3)          AS lv3_multi_parent2,
       (SELECT SUM(CASE WHEN np1 > 1 THEN 1 ELSE 0 END) FROM p3)          AS lv3_multi_top1,
       (SELECT COUNT(*) FROM p2)                                          AS n_lv2_real,
       (SELECT SUM(CASE WHEN np1 > 1 THEN 1 ELSE 0 END) FROM p2)          AS lv2_multi_top1
FROM (SELECT 1) z;
--    验收判据：
--      ① 六个 multi_* 全部 = 0 ⇒ 真实代理构成严格树，chain_key 的层位语义成立
--      ② 三个 zero_parent_* 全部 = 0 ⇒ 无孤儿，parent_count 恰为 1（红队 §3 之要求）
--      ③ ①② 任一不满足 ⇒ 五级链不是严格树，chain_key 必须改为「路径集合」，
--         HF9-A 的 CONCAT_WS 单键设计作废
--      ★ n_lv5_real / n_lv4_real / n_lv3_real 应分别接近 2,467 / 872 / 460（全平台基数）
--        扣测试线后略少，用作同源对照，不作硬闸（W-39 教训：锚点须同 population）


-- ==============================================================================================
--  §P1g · chain_key 唯一性与规范化碰撞（红队 §4②③ 指定）
--  ----------------------------------------------------------------------------------------
--  即使树成立，仍须证明 chain_key 与原始路径【一一对应】。两类风险：
--    ① CONCAT_WS 遇 NULL 会【跳过】该参数，导致层位左移、路径压缩 ——
--       故必须先 COALESCE 成占位符再拼接，本条即验此写法是否真的无碰撞。
--    ② CAST 到 BIGINT 会把 '02' 与 '2'、' 2' 与 '2' 规范化成同一值，
--       若源数据存在此类格式差异，字符串路径数将大于 BIGINT 路径数。
--  三个数必须【完全相等】，否则 HF9-A 立即 BLOCK。
-- ==============================================================================================


-- -- P1g -- 原始路径（字符串） vs 原始路径（BIGINT） vs chain_key，三者须相等
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT COALESCE(NULLIF(TRIM(b.bet18),''), '<N>')                        AS s1,
         COALESCE(NULLIF(TRIM(b.bet19),''), '<N>')                        AS s2,
         COALESCE(NULLIF(TRIM(b.bet20),''), '<N>')                        AS s3,
         COALESCE(NULLIF(TRIM(b.bet21),''), '<N>')                        AS s4,
         COALESCE(NULLIF(TRIM(b.bet22),''), '<N>')                        AS s5,
         COALESCE(CAST(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT) AS STRING), '<N>') AS b1,
         COALESCE(CAST(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT) AS STRING), '<N>') AS b2,
         COALESCE(CAST(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT) AS STRING), '<N>') AS b3,
         COALESCE(CAST(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT) AS STRING), '<N>') AS b4,
         COALESCE(CAST(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT) AS STRING), '<N>') AS b5
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
ps AS (SELECT DISTINCT s1, s2, s3, s4, s5 FROM base),
pb AS (SELECT DISTINCT b1, b2, b3, b4, b5 FROM base),
ck AS (SELECT DISTINCT CONCAT_WS('|', b1, b2, b3, b4, b5) AS chain_key FROM base)
SELECT (SELECT COUNT(*) FROM ps)                                          AS n_path_rawstring,
       (SELECT COUNT(*) FROM pb)                                          AS n_path_bigint,
       (SELECT COUNT(*) FROM ck)                                          AS n_chain_key
FROM (SELECT 1) z;
--    验收判据：
--      ① n_path_rawstring = n_path_bigint ⇒ 无字符串规范化碰撞（无前导零 / 空白差异）
--      ② n_path_bigint = n_chain_key      ⇒ CONCAT_WS 拼接无路径压缩、无键碰撞
--      ③ 两式任一不成立 ⇒ HF9-A 立即 BLOCK；n_path_rawstring > n_path_bigint 属 ①类，
--         n_path_bigint > n_chain_key 属 ②类，两类修法完全不同，须分别处置
--      ★ 本条另给出五级链的【真实路径总数】，即 chain_key 的基数，
--        供 HF9-A 估算新增列的字典规模（远小于 4,191 的全排列，不会撑爆内存）


-- ==============================================================================================
--  §P5b · #069 平方项的【切片可行性】（红队 §6 指定的两个补数）
--  ----------------------------------------------------------------------------------------
--  v1.2 P5 已测：ΣC(k,2) @100 = 961,606,221 · @300 = 799,131,535 · ratio = 1.2033
--  ⇒ 源码注释「门槛提三倍，配对数约降一个数量级」被证伪，实测仅降 16.9%，
--    却牺牲 50.97% 的候选会员（80,631 → 39,531）。
--  红队 §6 要求补 candidate_rounds@100 与 @300：ΣC(k,2) 是【输出配对量】，
--  candidate_rounds 是【触发平方项的原始组数】，两者必须同时看。
--  ★ 本条另测切片可行性：round_key = bet03|bet04|bet39，一局归属唯一日期，
--    故按 bet_date 切片是【精确划分】，不丢任何配对（跨片只需最后对 (uid1,uid2) 求和）。
--  ★ 仍不执行自连接，零 OOM 风险。
-- ==============================================================================================


-- -- P5b -- 触发组数 + 按日切片后的每片峰值
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
j AS (SELECT m.round_key, m.bet_date, a.n_rounds
      FROM mr m JOIN act a ON a.member_id = m.member_id),
r AS (
  SELECT bet_date, round_key,
         CAST(SUM(CASE WHEN n_rounds >= 100 THEN 1 ELSE 0 END) AS BIGINT) AS k100,
         CAST(SUM(CASE WHEN n_rounds >= 300 THEN 1 ELSE 0 END) AS BIGINT) AS k300
  FROM j GROUP BY bet_date, round_key
),
dd AS (
  SELECT bet_date,
         SUM(CASE WHEN k100 >= 2 THEN 1 ELSE 0 END)                       AS rounds100_d,
         SUM(CASE WHEN k300 >= 2 THEN 1 ELSE 0 END)                       AS rounds300_d,
         SUM(k100 * (k100 - 1) / 2)                                       AS pairs100_d,
         SUM(k300 * (k300 - 1) / 2)                                       AS pairs300_d
  FROM r GROUP BY bet_date
)
SELECT COUNT(*)                                                           AS n_slices_days,
       SUM(rounds100_d)                                                   AS candidate_rounds_100,
       SUM(rounds300_d)                                                   AS candidate_rounds_300,
       SUM(pairs100_d)                                                    AS pairs_rows_100,
       SUM(pairs300_d)                                                    AS pairs_rows_300,
       MAX(pairs100_d)                                                    AS max_pairs_per_day_100,
       AVG(pairs100_d)                                                    AS avg_pairs_per_day_100,
       MAX(rounds100_d)                                                   AS max_rounds_per_day_100
FROM dd;
--    验收判据：
--      ① pairs_rows_100 必须 = 961,606,221 · pairs_rows_300 必须 = 799,131,535
--         （与 v1.2 P5 逐位相同）⇒ 按日切片是精确划分，无遗漏、无重复
--      ② max_pairs_per_day_100 即单片峰值。若 <= 约 2,000 万，139 片串行完全可控，
--         #069 恢复业务判据 100 在【执行层面】可行
--      ★ 本条只回答「能不能跑」，不回答「该不该用 100」。
--        100 = BUSINESS_ORIGINATED（源码 L16779 自述「判据本要求同桌 ≥100 笔」）
--             / STATISTICALLY_UNVALIDATED
--        300 = KILLED / RESOURCE_DERIVED（且其自称的资源收益实测仅 16.9%，未兑现）
--        最终判据仍待 UNIVERSE-GATE，不得由本条推导。


-- ==============================================================================================
--  §P6-fix · #083 输出规模重测（修 W-41：补回测试线剔除）
--  ----------------------------------------------------------------------------------------
--  v1.2 的 P6 写了五个 LEFT JOIN ta 却漏了 AND COALESCE(...) IS NULL，测量含测试线。
--  本条以 U* 口径重测，并保留决策层权重偏斜的量化。
-- ==============================================================================================


-- -- P6-fix -- #083 输出行数（member × day，U* 口径）与决策层权重偏斜
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
md AS (SELECT member_id, bet_date, COUNT(DISTINCT bet01) AS n_rows
       FROM base GROUP BY member_id, bet_date),
mm AS (SELECT member_id, COUNT(*) AS n_days FROM md GROUP BY member_id)
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
--    验收判据：
--      ① members_all 必须 = 723,442（U* 锚）· members_ge20d 必须 = 26,941（v1.0 G083 锚）
--         v1.2 误值为 723,496 / 26,942，差 54 / 1，即测试线污染的精确规模
--      ② out_rows_ge20d = #083 现行 CSV 行数（首测，无锚）
--      ③ out_rows_all   = 取消宇宙门后的行数 ⇒ 除以 100000 即批数
--      ★ out_rows_ge20d / out_rows_all 之比即【决策层权重超额代表倍数】的分子：
--        v1.2 误值下为 3.72% 会员占 43.35% 排名行 = 超额 11.6 倍，本条给出 U* 口径的准值。


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条      | 耗时 | query_id | 返回值 | 判据结果
--  --------+------+----------+--------+--------------------------------------------------
--  P1d     |      |          |        | n_rows_dedup=124,713,543 · n_members=723,442 ·
--          |      |          |        | gap_lv2_broken=0 · gap_lv4_broken=0
--  P1e     |      |          |        | flat_violation=48（同源）· inherit_violation=0
--  P1f     |      |          |        | 六 multi_* 全 0 · 三 zero_parent_* 全 0
--  P1g     |      |          |        | n_path_rawstring = n_path_bigint = n_chain_key
--  P5b     |      |          |        | pairs_rows_100=961,606,221 · pairs_rows_300=799,131,535
--          |      |          |        | max_pairs_per_day_100 = ?
--  P6-fix  |      |          |        | members_all=723,442 · members_ge20d=26,941
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已逐行单跑 Z00C  ② 是否串行  ③ 有无报错或超时
--  ----------------------------------------------------------------------------------------
--  ★ 六条全过 = HF9-A 的四张许可证（P1b + P1c + NULL/0 孤儿检验 + chain_key 唯一性）齐备。
--    但 HF9-B 的 evidence_level 分层判据【仍属业务裁定】，不由本件产生。
--    分位数是分布事实，不是门槛 —— 此条永久生效。
-- ==============================================================================================
