-- ==============================================================================================
--  UNIVERSE-PROBE v1.9  ·  AGENT-RATE-01  ·  bet23~bet27 五级费率语义判定
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  前置：v1.8 ZC1 PASS（四对父子 × 三粒度，零值成因已分类）
--  ----------------------------------------------------------------------------------------
--  ★★ W-48 · 我上一轮的 HF9-E 是「贴标签」而非「斧正」 ★★
--    先生诘问：「为何重新命名需要显示 lv1 而非直接囊括各阶层代理？
--                倘若先生错了就得补齐各阶层代理与会员去进行斧正，
--                而非继续钻牛角尖去使用单一层代理进行美化。」
--    此诘问成立。我提议把 cost_complement_b 改名为 cost_complement_lv1_b，
--    等于【把缺陷起个诚实的名字】，而不是【把缺的四层补上】。这是美化，不是斧正。
--
--  ★★ W-49 · 「bet23 = 仅 LV1」这个前提，我从未验证过 ★★
--    我据 pct_top_bet23 的命名与 HF2 的注记，推断 x_agpct = bet23 是「顶级一层」。
--    但这是【推断】，不是【实测】。实测证据反向：
--        pct_top_bet23 均值 = 96.1140 · pct_complement 均值 = 3.8860 · 两者恒和 100
--        ⇒ bet23 更像【公司保留占成率】，则 100 − bet23 已是【全链代理合计占成】
--        ⇒ 若如此，x_agpct = bet23 【本就涵盖五级】，
--           我提议的 _lv1_ 命名不但没斧正，还会给正确的东西贴上错误标签。
--    ⇒ 在语义判定之前，任何以层级命名的改动【一律不得施工】。
--  ----------------------------------------------------------------------------------------
--  ★ 待判定的三种解读（互斥且穷尽，AG-03 的算术核心）：
--      解读甲 · 单层：       agent_pct = 100 − bet23                （现行 HF2 口径）
--      解读乙 · 加法五级：   agent_pct = Σ(100 − betXX)             （HF2 之前口径，五级和 460% 之源）
--      解读丙 · 嵌套乘法：   agent_pct = 100 − Π(betXX/100)×100     （逐级抽成，从未测过）
--    三者对 cost_complement_b 的影响量级可差 5 倍以上，直接决定 residual_b 与全部风控结论。
--    ★ 本件【只量三种解读各自的数值】，不裁定何者为真 —— 裁定须待外部台账对账。
--  ----------------------------------------------------------------------------------------
--  纪律：★ 测量件，不是裁决件 ★
--    禁 ROW_NUMBER / 禁窗口函数 / 禁 ORDER BY / 禁 OFFSET / 禁 SELECT * / 禁块注释 / 全件只读
--    清洗一律 U* 口径；五级源列 bet18~bet22 与 bet23~bet27 全数参与，不得只取其一
--    输出 1 行与 6 行，结构上不可能被前端 1,000 行上限截断
-- ==============================================================================================


-- ==============================================================================================
--  §AG1 · 五级费率字段的分布、单调性、与三种解读的实测值
-- ==============================================================================================


-- -- AG1 -- bet23~bet27 五层齐测：分布 · 单调性 · 三种解读下的代理占成
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT b.bet01                                                          AS bet01,
         COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0)     AS p1,
         COALESCE(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)), 0)     AS p2,
         COALESCE(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)), 0)     AS p3,
         COALESCE(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)), 0)     AS p4,
         COALESCE(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)), 0)     AS p5,
         (CAST(NULLIF(TRIM(b.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)    AS net
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
d AS (SELECT DISTINCT bet01, p1, p2, p3, p4, p5, net FROM r)
SELECT COUNT(*)                                                           AS n_rows_dedup,
       ROUND(AVG(p1),6) AS avg_bet23, ROUND(AVG(p2),6) AS avg_bet24,
       ROUND(AVG(p3),6) AS avg_bet25, ROUND(AVG(p4),6) AS avg_bet26,
       ROUND(AVG(p5),6) AS avg_bet27,
       ROUND(AVG(p1+p2+p3+p4+p5),6)                                       AS avg_sum5,
       SUM(CASE WHEN p1 >= p2 AND p2 >= p3 AND p3 >= p4 AND p4 >= p5
                THEN 1 ELSE 0 END)                                        AS n_monotone_desc,
       SUM(CASE WHEN p1 = p2 AND p2 = p3 AND p3 = p4 AND p4 = p5
                THEN 1 ELSE 0 END)                                        AS n_all_equal,
       SUM(CASE WHEN p2 = 0 THEN 1 ELSE 0 END)                            AS n_bet24_zero,
       SUM(CASE WHEN p3 = 0 THEN 1 ELSE 0 END)                            AS n_bet25_zero,
       SUM(CASE WHEN p4 = 0 THEN 1 ELSE 0 END)                            AS n_bet26_zero,
       SUM(CASE WHEN p5 = 0 THEN 1 ELSE 0 END)                            AS n_bet27_zero,
       ROUND(SUM(-net * (100.0 - p1)/100.0), 4)                           AS cost_jia_single,
       ROUND(SUM(-net * ((100.0-p1)+(100.0-p2)+(100.0-p3)
                        +(100.0-p4)+(100.0-p5))/100.0), 4)                AS cost_yi_additive,
       ROUND(SUM(-net * (100.0 - p1/100.0*p2/100.0*p3/100.0
                                  *p4/100.0*p5/100.0*100.0)/100.0), 4)    AS cost_bing_nested,
       ROUND(SUM(-net), 4)                                                AS profit_total
FROM d;
--    验收判据：
--      ① n_rows_dedup 必须 = 124,713,543（U* 锚）
--      ② cost_jia_single 必须 = 8,073,461（已锁台账 cost_complement_b）⇒ 本件与生产件同源
--      ③ profit_total 必须 = 196,872,453（已锁台账 profit）
--      ④ avg_bet23 必须 = 96.1140 附近（已锁 pct_top_bet23 均值）
--    ★ 判读（仅供 GATE 审议，本件不裁定）：
--      · n_monotone_desc ≈ n_rows_dedup ⇒ 五级费率呈【逐级递减的嵌套阶梯】
--        ⇒ 「五级总和 460%」是把嵌套值当加法值累加的产物，解读乙【自证矛盾】
--      · n_bet24_zero ~ n_bet27_zero 若与链深分布（v1.4 P1h：五级 124,074,679 ·
--        四级 97,967 · 三级 482,828 · ≤二级 58,069）吻合
--        ⇒ 费率字段的层数与代理链层数【同源】，缺层即费率为 0
--      · cost_jia_single / cost_yi_additive / cost_bing_nested 三数之比，
--        即三种解读对 residual_b 的影响倍数。AG-03 的裁定须以此三数对外部台账，
--        而非继续以 bet23 单层「凑合」。


-- ==============================================================================================
--  §AG2 · 费率层数 × 代理链层数 是否同源（决定缺层如何处理）
--  ----------------------------------------------------------------------------------------
--  v1.4 P1h 已证：代理链以 0 为终止哨兵，链深分布为 五级/四级/三级/≤二级。
--  若费率字段与代理链同源，则链深为 d 的注单，其第 d+1 层及以后的费率应恒为 0（或等于第 d 层）。
--  本条按【链深】分组，逐组给出五个费率的均值与零值率，一次看清对应关系。
-- ==============================================================================================


-- -- AG2 -- 按代理链深分组的五级费率对照
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT b.bet01                                                          AS bet01,
         (CASE WHEN NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT),0) IS NOT NULL THEN 5
               WHEN NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT),0) IS NOT NULL THEN 4
               WHEN NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT),0) IS NOT NULL THEN 3
               WHEN NULLIF(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT),0) IS NOT NULL THEN 2
               WHEN NULLIF(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT),0) IS NOT NULL THEN 1
               ELSE 0 END)                                                AS chain_depth,
         COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0)     AS p1,
         COALESCE(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)), 0)     AS p2,
         COALESCE(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)), 0)     AS p3,
         COALESCE(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)), 0)     AS p4,
         COALESCE(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)), 0)     AS p5
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
d AS (SELECT DISTINCT bet01, chain_depth, p1, p2, p3, p4, p5 FROM r)
SELECT chain_depth,
       COUNT(*)                                                           AS n_rows,
       ROUND(AVG(p1),4) AS avg_bet23, ROUND(AVG(p2),4) AS avg_bet24,
       ROUND(AVG(p3),4) AS avg_bet25, ROUND(AVG(p4),4) AS avg_bet26,
       ROUND(AVG(p5),4) AS avg_bet27,
       ROUND(SUM(CASE WHEN p2 = 0 THEN 1 ELSE 0 END)*100.0/COUNT(*),4)    AS pct_bet24_zero,
       ROUND(SUM(CASE WHEN p3 = 0 THEN 1 ELSE 0 END)*100.0/COUNT(*),4)    AS pct_bet25_zero,
       ROUND(SUM(CASE WHEN p4 = 0 THEN 1 ELSE 0 END)*100.0/COUNT(*),4)    AS pct_bet26_zero,
       ROUND(SUM(CASE WHEN p5 = 0 THEN 1 ELSE 0 END)*100.0/COUNT(*),4)    AS pct_bet27_zero
FROM d GROUP BY chain_depth;
--    验收判据：
--      ① 各 chain_depth 的 n_rows 之和必须 = 124,713,543，且逐档应与 v1.4 P1h 吻合：
--         depth 5 = 124,074,679 · depth 4 = 97,967 · depth 3 = 482,828 · depth ≤2 = 58,069
--      ② 若 depth=3 组的 pct_bet26_zero 与 pct_bet27_zero 接近 100%
--         ⇒ 费率层数与代理链层数【同源】，缺层费率即为 0，
--            则「加法五级」解读在浅链上会把 (100−0)=100% 误计为满额代理成本，
--            这正是「五级总和 460%」的成因之一，解读乙【实证不成立】
--      ③ 若 depth=3 组的 bet26/bet27 反而非零 ⇒ 费率与链深【不同源】，
--            须另开 AGENT-RATE-02 追查其真实语义，AG-03 维持 UNRESOLVED


-- ==============================================================================================
--  §R · 回报模板（一格不留空；未跑写 NOT_RUN，不要写 0）
--  ----------------------------------------------------------------------------------------
--  条   | 耗时 | query_id | 返回值 | 判据结果
--  -----+------+----------+--------+---------------------------------------------------------
--  AG1  |      |          |        | cost_jia_single 须 = 8,073,461 · profit_total 须 = 196,872,453
--       |      |          |        | avg_bet23 ≈ 96.1140 · n_monotone_desc / n_rows_dedup = ?
--       |      |          |        | 三种解读的代理成本三数
--  AG2  |      |          |        | 各 chain_depth 行数须合 124,713,543 且与 P1h 逐档吻合
--  ----------------------------------------------------------------------------------------
--  另请回报：① 是否已逐行单跑 Z00C  ② 是否串行  ③ 有无报错或超时
--  ----------------------------------------------------------------------------------------
--  ★ 本件不裁定 AG-03。三种解读的数值一旦拿到，须与外部台账（代理佣金结算表 / 日报表）
--    对账后方可裁定，不得以「哪个数好看」择一。
-- ==============================================================================================
