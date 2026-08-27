-- ==============================================================================================
--  UNIVERSE-PROBE v1.4  ·  四条 · 判定「48」究竟是零值哨兵、还是四个多父节点
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.3 六条已跑 —— P1d/P1g/P5b/P6-fix PASS · P1e 48=48 · P1f lv5=1 / lv4=3
--  ----------------------------------------------------------------------------------------
--  ★★ 本件存在的唯一理由：v1.3 的 P1e 是一次【空转测试】，不是反证 ★★
--    P1d 实测：lv1_null ~ lv5_null 【全部为 0】—— 全窗零 NULL。
--    而 P1e 的路径继承哨兵写的是 COALESCE(CAST(eX AS STRING), CONCAT('~', k(X-1)))，
--    只在【NULL 时】才继承。既然一个 NULL 都没有，继承分支【一次都没触发】，
--    k1~k5 与 f1~f5 是【同一个表达式】，故 48 = 48 是恒等式，不是证据。
--    铁证：max_k1/k3/k5 = 12/23/70 与 max_f1/f3/f5 = 12/23/70 【逐位相同】。
--    ⇒ 「路径继承哨兵已改变终止节点编码」这一前提【不成立】，
--       据此宣布 W-42 KILLED 属于【以空转测试作反证】，本件予以纠正。
--  ----------------------------------------------------------------------------------------
--  ★ 真正的终止标记是 0，不是 NULL。P1d 实测：
--      lv1_zero 0 · lv2_zero 75 · lv3_zero 58,069 · lv4_zero 540,897 · lv5_zero 638,864
--    逐层【单调递增】，与「链在第 d 层终止，其后各层皆为 0」的预期完全一致。
--    且 lv5_zero = 638,864 与 CHAIN-01 已锁数值【逐位相同】（CHAIN-01 仍冻结，此处只作交叉验证）。
--    v1.3 的 gap_lv2_broken / gap_lv4_broken 用的是 IS NULL 判据，故恒为 0 —— 【零值断链从未被测】。
--  ----------------------------------------------------------------------------------------
--  ★ P1f 扣除 0 号伪节点后的净结构违规（与 v1.3 P1c 逐项相减，差恰为 1，证明 0 是单一伪节点）：
--      lv5_multi_parent4  2 → 1      lv5_multi_top1  7 → 6
--      lv4_multi_parent3  4 → 3      lv4_multi_top1  4 → 3
--      lv3_multi_parent2  1 → 0      lv3_multi_top1  1 → 0      lv2_multi_top1  0
--    ⇒ 真实非树节点为 lv4 三个 + lv5 一个，合计 4 个，占真实代理 4,001 名的 0.10%。
--    ⇒ lv3 与 lv2 两层【是完美的树】。
--  ----------------------------------------------------------------------------------------
--  本件要回答的四问（缺一不可，缺则模型重构失去依据）：
--    ① 0 到底是「链终止哨兵」还是「一个 id 为 0 的真实代理」？（查维表 + 查嵌套性）
--    ② 把 0 也纳入继承哨兵后，48 还剩几个？残量才是真实的结构违规数。
--    ③ 那 4 个多父节点，其多父关系是【时间先后】还是【同期一对多】？
--    ④ 那 4 个节点的敞口有多大（注单 / 会员 / 注额）？敞口决定 HF9-A 是带标施工还是停工。
--  ----------------------------------------------------------------------------------------
--  纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    清洗一律 U* 口径（723,442 会员 / 124,713,543 注单，五级测试线已剔）
--    串行执行，先逐行单跑 Z00C；任一条超 10 分钟立即取消，不重试、不双开
-- ==============================================================================================


-- ==============================================================================================
--  §P1h · 0 的语义判定：哨兵，还是真实代理？
--  ----------------------------------------------------------------------------------------
--  两条独立证据同时取：
--    证据一（维表）：ods_a168_agent 里是否存在 age001 = 0 的代理？不存在 ⇒ 0 是哨兵。
--    证据二（嵌套性）：lvX = 0 是否蕴含其后各层皆为 0？若存在「0 之后又冒出非 0」，
--                     则 0 不是终止标记，此时零感知哨兵不成立，须另寻解释。
-- ==============================================================================================


-- -- P1h -- 0 的维表存在性 ＋ 零值嵌套性（是否终止即不再复现）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
d AS (
  SELECT DISTINCT
         b.bet01,
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
SELECT (SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_agent
         WHERE CAST(NULLIF(TRIM(age001),'') AS BIGINT) = 0)               AS agent_id_zero_in_dim,
       (SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_agent)               AS agent_dim_rows,
       COUNT(*)                                                           AS n_rows_dedup,
       SUM(CASE WHEN lv2 = 0 AND lv3 <> 0 THEN 1 ELSE 0 END)              AS zero2_then_nonzero3,
       SUM(CASE WHEN lv3 = 0 AND lv4 <> 0 THEN 1 ELSE 0 END)              AS zero3_then_nonzero4,
       SUM(CASE WHEN lv4 = 0 AND lv5 <> 0 THEN 1 ELSE 0 END)              AS zero4_then_nonzero5,
       SUM(CASE WHEN lv2 = 0 AND (lv3 <> 0 OR lv4 <> 0 OR lv5 <> 0)
                THEN 1 ELSE 0 END)                                        AS zero2_resurrect_any,
       SUM(CASE WHEN lv3 = 0 AND (lv4 <> 0 OR lv5 <> 0) THEN 1 ELSE 0 END) AS zero3_resurrect_any,
       SUM(CASE WHEN lv1 <> 0 AND lv2 <> 0 AND lv3 <> 0
                 AND lv4 <> 0 AND lv5 <> 0 THEN 1 ELSE 0 END)             AS n_full5_chain,
       SUM(CASE WHEN lv5 = 0 AND lv4 <> 0 THEN 1 ELSE 0 END)              AS n_depth4_chain,
       SUM(CASE WHEN lv4 = 0 AND lv3 <> 0 THEN 1 ELSE 0 END)              AS n_depth3_chain
FROM d;
--    验收判据：
--      ① agent_id_zero_in_dim = 0 ⇒ 维表无 id 为 0 的代理 ⇒ 0 是【哨兵】而非真实代理
--         若 > 0 ⇒ 存在 id 为 0 的真实代理，零感知哨兵【不得】采用，本件后续两条须重解读
--      ② zero2_resurrect_any / zero3_resurrect_any / zero4_then_nonzero5 全部 = 0
--         ⇒ 0 一旦出现即不再复现非 0 ⇒ 0 确为【链终止标记】，嵌套性成立
--         任一 > 0 ⇒ 存在「终止后又续」的链，chain_key 的层位语义崩塌，HF9-A 须重新设计
--      ③ n_full5_chain / n_depth4_chain / n_depth3_chain 三数相加应接近 n_rows_dedup，
--         差额即深度 ≤ 2 的链，可与 lv2_zero = 75 对照


-- ==============================================================================================
--  §P1i · 零感知单调性：把 0 也纳入继承哨兵后，48 还剩几个？
--  ----------------------------------------------------------------------------------------
--  v1.3 的继承条件写的是「IS NULL 才继承」，而全窗零 NULL，故继承从未触发（空转）。
--  本条把继承条件改为「IS NULL 或 = 0 才继承」，三版并出，逐行对照：
--      f 版：平哨兵（COALESCE(...,-1)）                  —— 应仍得 48（同源锚）
--      g 版：NULL 继承（v1.3 原写法）                     —— 应仍得 48（证明空转）
--      z 版：NULL 或 0 继承（本件新增）                    —— 残量即真实结构违规数
--  ★ 若 z 版 = 0：48 全数由零值折叠造成，HF9-A 的计数列改用零感知哨兵即可。
--  ★ 若 z 版 > 0：残量才是那 4 个多父节点造成的真实违规，须由 §P1j / §P1k 定性。
--  ★ 无论何者，本条【不裁定】HF9-A 是否施工，只给出真实违规数。
-- ==============================================================================================


-- -- P1i -- 三版哨兵的逐行单调性对照
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
base AS (
  SELECT TRIM(b.ip)                                                       AS bet_ip,
         NULLIF(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT), 0)              AS e1,
         NULLIF(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT), 0)              AS e2,
         NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT), 0)              AS e3,
         NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT), 0)              AS e4,
         NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT), 0)              AS e5,
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
z1 AS (SELECT bet_ip, e2, e3, e4, e5, f1, f2, f3, f4, f5,
              COALESCE(CAST(e1 AS STRING), '~')                           AS z1k
       FROM base),
z2 AS (SELECT bet_ip, e3, e4, e5, f1, f2, f3, f4, f5, z1k,
              COALESCE(CAST(e2 AS STRING), CONCAT('~', z1k))              AS z2k
       FROM z1),
z3 AS (SELECT bet_ip, e4, e5, f1, f2, f3, f4, f5, z1k, z2k,
              COALESCE(CAST(e3 AS STRING), CONCAT('~', z2k))              AS z3k
       FROM z2),
z4 AS (SELECT bet_ip, e5, f1, f2, f3, f4, f5, z1k, z2k, z3k,
              COALESCE(CAST(e4 AS STRING), CONCAT('~', z3k))              AS z4k
       FROM z3),
z5 AS (SELECT bet_ip, f1, f2, f3, f4, f5, z1k, z2k, z3k, z4k,
              COALESCE(CAST(e5 AS STRING), CONCAT('~', z4k))              AS z5k
       FROM z4),
g AS (
  SELECT bet_ip,
         COUNT(DISTINCT z1k) AS nz1, COUNT(DISTINCT z2k) AS nz2,
         COUNT(DISTINCT z3k) AS nz3, COUNT(DISTINCT z4k) AS nz4,
         COUNT(DISTINCT z5k) AS nz5,
         COUNT(DISTINCT f1)  AS nf1, COUNT(DISTINCT f2)  AS nf2,
         COUNT(DISTINCT f3)  AS nf3, COUNT(DISTINCT f4)  AS nf4,
         COUNT(DISTINCT f5)  AS nf5
  FROM z5 GROUP BY bet_ip
)
SELECT COUNT(*)                                                           AS ips_before,
       SUM(CASE WHEN NOT (nf1 <= nf2 AND nf2 <= nf3
                      AND nf3 <= nf4 AND nf4 <= nf5) THEN 1 ELSE 0 END)   AS flat_violation,
       SUM(CASE WHEN NOT (nz1 <= nz2 AND nz2 <= nz3
                      AND nz3 <= nz4 AND nz4 <= nz5) THEN 1 ELSE 0 END)   AS zeroaware_violation,
       SUM(CASE WHEN NOT (nz3 <= nz4) THEN 1 ELSE 0 END)                  AS viol_at_lv3_to_lv4,
       SUM(CASE WHEN NOT (nz4 <= nz5) THEN 1 ELSE 0 END)                  AS viol_at_lv4_to_lv5,
       SUM(CASE WHEN NOT (nz1 <= nz2) THEN 1 ELSE 0 END)                  AS viol_at_lv1_to_lv2,
       SUM(CASE WHEN NOT (nz2 <= nz3) THEN 1 ELSE 0 END)                  AS viol_at_lv2_to_lv3,
       MAX(nz1) AS max_z1, MAX(nz3) AS max_z3, MAX(nz5) AS max_z5,
       MAX(nf1) AS max_f1, MAX(nf3) AS max_f3, MAX(nf5) AS max_f5
FROM g;
--    验收判据：
--      ① flat_violation 必须 = 48（与 v1.3 P1e 逐位相同）⇒ 同源可比
--      ② zeroaware_violation = 0 ⇒ 48 全数为零值折叠伪影，
--         HF9-A 的 n_lvX 计数列改用零感知哨兵即可，无须重构关系模型
--      ③ zeroaware_violation > 0 ⇒ 残量即真实结构违规，
--         viol_at_lv*_to_lv* 四数指出违规发生在哪一层，与 P1f 的 lv4=3 / lv5=1 对照
--      ★ max_z* 与 max_f* 若【不相同】，即证明零感知哨兵确实改变了编码（v1.3 正是因为
--        max_k* 与 max_f* 逐位相同，才暴露出那一版是空转）


-- ==============================================================================================
--  §P1j · 四个多父节点：时间关系 ＋ 敞口
--  ----------------------------------------------------------------------------------------
--  P1f 已定位：lv4 三个节点有多个 lv3 父、lv5 一个节点有多个 lv4 父。
--  本条不硬编码任何 id，以集合方式自动圈出，并同时给出：
--    ① 每个 (子, 父) 组合的时间区间与注单数 —— 判定是【时间先后】还是【同期一对多】
--    ② 这些节点的敞口（注单 / 会员 / 注额）—— 敞口决定 HF9-A 停工还是带标施工
--  ★ 输出行数极少（约 10 行内），无 ORDER BY 亦可读。
-- ==============================================================================================


-- -- P1j -- 多父节点的 (子,父) 组合、时间区间与敞口
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT b.bet01, b.dt                                                    AS bet_date,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                         AS member_id,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)    AS stake,
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
bad4 AS (SELECT lv4 FROM r WHERE lv4 IS NOT NULL AND lv3 IS NOT NULL
         GROUP BY lv4 HAVING COUNT(DISTINCT lv3) > 1),
bad5 AS (SELECT lv5 FROM r WHERE lv5 IS NOT NULL AND lv4 IS NOT NULL
         GROUP BY lv5 HAVING COUNT(DISTINCT lv4) > 1)
SELECT 'lv4_child'                                                        AS node_level,
       CAST(x.lv4 AS STRING)                                              AS child_id,
       CAST(x.lv3 AS STRING)                                              AS parent_id,
       MIN(x.bet_date)                                                    AS first_day,
       MAX(x.bet_date)                                                    AS last_day,
       COUNT(DISTINCT x.bet01)                                            AS n_bets,
       COUNT(DISTINCT x.member_id)                                        AS n_members,
       ROUND(SUM(x.stake), 4)                                             AS stake
FROM r x JOIN bad4 c ON c.lv4 = x.lv4
WHERE x.lv3 IS NOT NULL
GROUP BY x.lv4, x.lv3
UNION ALL
SELECT 'lv5_child'                                                        AS node_level,
       CAST(y.lv5 AS STRING)                                              AS child_id,
       CAST(y.lv4 AS STRING)                                              AS parent_id,
       MIN(y.bet_date)                                                    AS first_day,
       MAX(y.bet_date)                                                    AS last_day,
       COUNT(DISTINCT y.bet01)                                            AS n_bets,
       COUNT(DISTINCT y.member_id)                                        AS n_members,
       ROUND(SUM(y.stake), 4)                                             AS stake
FROM r y JOIN bad5 c2 ON c2.lv5 = y.lv5
WHERE y.lv4 IS NOT NULL
GROUP BY y.lv5, y.lv4;
--    判读指引（仅供 GATE 审议，本件不下结论）：
--      · 同一 child_id 的多行若【时间区间不重叠】（前一父的 last_day < 后一父的 first_day）
--        ⇒ 属【代理关系随时间变化】，即 upline change ⇒ HF9-A 须采 time-aware path，
--          且该现象与 H-UPLINE-01（change_log 有 48 条 changeUpline）方向一致
--      · 若【时间区间重叠】⇒ 属【同期一对多】⇒ 关系模型不是树，HF9-A 须采 path-set / graph
--      ★ 「48 条 changeUpline」与「48 个违规 IP」数值相同，属【待检验的巧合】，
--        在 §P1k 给出同局证据前，不得当作因果关联
--      · n_bets / n_members / stake 三列合计即这些节点的【敞口】。
--        敞口占全窗 124,713,543 注单与 13,149,241,211 注额的比例，决定 HF9-A 是停工还是带标施工。


-- ==============================================================================================
--  §P1k · 多父是否发生在【同一局】—— 时间假说与同期假说的判决性检验
--  ----------------------------------------------------------------------------------------
--  §P1j 的时间区间只能给出「重叠 / 不重叠」，粒度是日。
--  本条把粒度压到【同一局】（round_key = bet03|bet04|bet39）：
--    若存在某一局内，同一 lv4 子节点同时挂在两个不同 lv3 父之下，
--    则【同期一对多】成立，时间假说被否，关系模型必须改为 path-set / graph。
--    若同局零命中，则多父只可能是跨时间产生 ⇒ time-aware path 即可解决。
--  ★ 这是「时间变化」与「同期多父」两假说的判决性检验，不是辅助指标。
-- ==============================================================================================


-- -- P1k -- 同局内的多父检验（判决性）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.dt                                                             AS bet_date,
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
rd4 AS (SELECT round_key, lv4, COUNT(DISTINCT lv3) AS np
        FROM r WHERE lv4 IS NOT NULL AND lv3 IS NOT NULL
        GROUP BY round_key, lv4),
rd5 AS (SELECT round_key, lv5, COUNT(DISTINCT lv4) AS np
        FROM r WHERE lv5 IS NOT NULL AND lv4 IS NOT NULL
        GROUP BY round_key, lv5),
dy4 AS (SELECT bet_date, lv4, COUNT(DISTINCT lv3) AS np
        FROM r WHERE lv4 IS NOT NULL AND lv3 IS NOT NULL
        GROUP BY bet_date, lv4),
dy5 AS (SELECT bet_date, lv5, COUNT(DISTINCT lv4) AS np
        FROM r WHERE lv5 IS NOT NULL AND lv4 IS NOT NULL
        GROUP BY bet_date, lv5)
SELECT (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM rd4)          AS same_round_multi_parent_lv4,
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM rd5)          AS same_round_multi_parent_lv5,
       (SELECT COUNT(DISTINCT lv4) FROM rd4 WHERE np > 1)                 AS n_lv4_nodes_same_round,
       (SELECT COUNT(DISTINCT lv5) FROM rd5 WHERE np > 1)                 AS n_lv5_nodes_same_round,
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM dy4)          AS same_day_multi_parent_lv4,
       (SELECT SUM(CASE WHEN np > 1 THEN 1 ELSE 0 END) FROM dy5)          AS same_day_multi_parent_lv5,
       (SELECT COUNT(DISTINCT lv4) FROM dy4 WHERE np > 1)                 AS n_lv4_nodes_same_day,
       (SELECT COUNT(DISTINCT lv5) FROM dy5 WHERE np > 1)                 AS n_lv5_nodes_same_day
FROM (SELECT 1) z;
--    判决规则（本件唯一允许的二分判定，因两假说互斥且穷尽）：
--      ① same_round_* 与 same_day_* 【全部 = 0】
--         ⇒ 多父关系【从不同期出现】⇒ 时间假说成立 ⇒ HF9-A 采 time-aware path，
--            chain_key 加 valid_from / valid_to，或以 bet_date 为路径的一部分
--      ② same_round_* 任一 > 0
--         ⇒ 同一局内同一子节点挂多个父 ⇒【同期一对多】⇒ 关系不是树，
--            HF9-A 必须采 path-set / graph relation，CONCAT_WS 单键设计作废
--      ③ same_round_* = 0 但 same_day_* > 0
--         ⇒ 日内切换 ⇒ 时间假说成立但粒度需细到局，chain_key 须以局为时点锚
--    ★ 无论何种判定，均只决定【HF9-A 的路径模型】，
--      不改变 chain_key 唯一性（P1g 已 PASS：2,528 = 2,528 = 2,528），
--      也不改变 U*、#069 切片可行性、#083 输出规模三项已 PASS 的结论。


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条    | 耗时 | query_id | 返回值 | 判据结果
--  ------+------+----------+--------+----------------------------------------------------
--  P1h   |      |          |        | agent_id_zero_in_dim = ? · 三个 resurrect 是否全 0
--  P1i   |      |          |        | flat_violation = 48（同源）· zeroaware_violation = ?
--  P1j   |      |          |        | 各 (子,父) 的时间区间是否重叠 · 敞口三数
--  P1k   |      |          |        | same_round_* / same_day_* 是否全 0
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已逐行单跑 Z00C  ② 是否串行  ③ 有无报错或超时
--  ----------------------------------------------------------------------------------------
--  ★ 本件不裁定任何业务判据。分位数是分布事实，不是门槛；
--    29,606 只称「结构候选池」；7 名极值会员之结构与多机制相容，当前无法区分。
-- ==============================================================================================
