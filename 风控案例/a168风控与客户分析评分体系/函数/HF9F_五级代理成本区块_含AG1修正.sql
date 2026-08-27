-- ==============================================================================================
--  HF9-F · 五级代理成本区块（可直接替换的施工件）
--  ----------------------------------------------------------------------------------------
--  基准源码：a168_SQL总包_v12_0_0_HF8b_原版审计版_六层商业版.sql
--            纯代码MD5 b0723b0e7f1b79b04082520cf779ad3a
--  替换位置：x_bs0 的 x_agpct 一行（L328）与 x_agg 的代理块（L356~360），129 件同构
--  ----------------------------------------------------------------------------------------
--  ★ 依据：AG2 实测已 PROVEN「费率第 k 列 ↔ 代理链第 k 级」严格一一对应
--      depth=1 → bet24~bet27 恒为 0（100%）
--      depth=2 → bet25~bet27 恒为 0（100%）
--      depth=3 → bet26~bet27 恒为 0（100%）
--      depth=4 → bet27       恒为 0（100%）
--      depth=5 → 无一层恒零
--      各档行数 75 / 57,994 / 482,828 / 97,967 / 124,074,679，合计 124,713,543 = U* 锚
--  ★ 因此：缺层的 0 是【该层不存在】，不是【该层公司保留 0%】。
--    现行任何把缺层当 0 参与运算的写法都会把缺层误算成「代理拿走 100%」，
--    这正是「五级总和 460%」的真正成因。本件一律以 NULLIF(...,0) 转 NULL，
--    再按「不存在即不抽成」以 100 代入，从根上消除该误算。
--  ----------------------------------------------------------------------------------------
--  ★ 本件【不裁定 AG-03】。三种解读全部出列，由业务对账后择定，
--    生产口径在裁定前维持 cost_complement_b（甲）不变，以保住已锁八项台账。
-- ==============================================================================================


-- ── 一、x_bs0 层：把 x_agpct 一行替换为五级齐出 ──────────────────────────────────
--    原：COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)),0)   AS x_agpct,
--    改：

       COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0)     AS x_agpct,
       NULLIF(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0)       AS x_rate1,
       NULLIF(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)), 0)       AS x_rate2,
       NULLIF(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)), 0)       AS x_rate3,
       NULLIF(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)), 0)       AS x_rate4,
       NULLIF(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)), 0)       AS x_rate5,
       (CASE WHEN NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT),0) IS NOT NULL THEN 5
             WHEN NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT),0) IS NOT NULL THEN 4
             WHEN NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT),0) IS NOT NULL THEN 3
             WHEN NULLIF(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT),0) IS NOT NULL THEN 2
             WHEN NULLIF(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT),0) IS NOT NULL THEN 1
             ELSE 0 END)                                                AS x_chain_depth,
--    ★ x_agpct 保留原样不动 —— 已锁八项台账的 cost_complement_b 由它算出，改则锚断。


-- ── 二、x_agg 层：代理块替换（原 L356~360）──────────────────────────────────────
--    ★ 乘法用 DOUBLE，不用 DECIMAL：五个 DECIMAL(20,6) 相乘会把标度累加到 30 以上，
--      StarRocks 上限 38，AG1 首跑即因此报
--      「Return scale(47) exceeds maximum value(38)」而失败（W-50，我的疏漏）。
--      比率相乘用 DOUBLE，相对误差约 1e-15，远小于既有的 ROUND(...,4)，可接受。
--      最终成本一律 CAST 回 DECIMAL(20,4) 后再聚合，货币量不落 DOUBLE。

       SUM(s.x_net)                                                     AS net,

--    甲 · 单层（现行生产口径，LEGACY 留锚，值与旧版逐位相同）
       SUM(-s.x_net * (100.0 - s.x_agpct)/100.0)                        AS agent_cost,
       AVG(100.0 - s.x_agpct)                                           AS agent_pct,
       AVG(s.x_agpct)                                                   AS company_retain_pct,

--    逐级公司保留率（缺层以 100 代入 ＝ 该层不存在、不抽成）
       AVG(COALESCE(s.x_rate1, 100))                                    AS retain_pct_lv1,
       AVG(COALESCE(s.x_rate2, 100))                                    AS retain_pct_lv2,
       AVG(COALESCE(s.x_rate3, 100))                                    AS retain_pct_lv3,
       AVG(COALESCE(s.x_rate4, 100))                                    AS retain_pct_lv4,
       AVG(COALESCE(s.x_rate5, 100))                                    AS retain_pct_lv5,
       AVG(s.x_chain_depth)                                             AS chain_depth_avg,

--    逐级代理占成率（该层不存在时为 0，不参与）
       AVG(COALESCE(100.0 - s.x_rate1, 0))                              AS agent_pct_lv1,
       AVG(COALESCE(100.0 - s.x_rate2, 0))                              AS agent_pct_lv2,
       AVG(COALESCE(100.0 - s.x_rate3, 0))                              AS agent_pct_lv3,
       AVG(COALESCE(100.0 - s.x_rate4, 0))                              AS agent_pct_lv4,
       AVG(COALESCE(100.0 - s.x_rate5, 0))                              AS agent_pct_lv5,

--    逐级代理成本（金额，五层分开出，先生令「囊括各阶层」之本体）
       SUM(CAST(-s.x_net * COALESCE(100.0 - s.x_rate1, 0)/100.0 AS DECIMAL(20,4))) AS agent_cost_lv1,
       SUM(CAST(-s.x_net * COALESCE(100.0 - s.x_rate2, 0)/100.0 AS DECIMAL(20,4))) AS agent_cost_lv2,
       SUM(CAST(-s.x_net * COALESCE(100.0 - s.x_rate3, 0)/100.0 AS DECIMAL(20,4))) AS agent_cost_lv3,
       SUM(CAST(-s.x_net * COALESCE(100.0 - s.x_rate4, 0)/100.0 AS DECIMAL(20,4))) AS agent_cost_lv4,
       SUM(CAST(-s.x_net * COALESCE(100.0 - s.x_rate5, 0)/100.0 AS DECIMAL(20,4))) AS agent_cost_lv5,

--    乙 · 加法五级（仅对存在的层求和；缺层不入和）
       SUM(CAST(-s.x_net * ( COALESCE(100.0 - s.x_rate1, 0)
                           + COALESCE(100.0 - s.x_rate2, 0)
                           + COALESCE(100.0 - s.x_rate3, 0)
                           + COALESCE(100.0 - s.x_rate4, 0)
                           + COALESCE(100.0 - s.x_rate5, 0))/100.0
                AS DECIMAL(20,4)))                                      AS agent_cost_chain_additive,

--    丙 · 嵌套五级（逐级抽成；缺层以 1.0 代入，即不抽成）
       SUM(CAST(-s.x_net * (1.0
             - CAST(COALESCE(s.x_rate1,100) AS DOUBLE)/100.0
             * CAST(COALESCE(s.x_rate2,100) AS DOUBLE)/100.0
             * CAST(COALESCE(s.x_rate3,100) AS DOUBLE)/100.0
             * CAST(COALESCE(s.x_rate4,100) AS DOUBLE)/100.0
             * CAST(COALESCE(s.x_rate5,100) AS DOUBLE)/100.0)
                AS DECIMAL(20,4)))                                      AS agent_cost_chain_nested,

--    A 读法遗留（原样保留）
       SUM(-s.x_net * s.x_agpct/100.0)                                  AS agent_cost_a_legacy,
       SUM(s.x_valid * s.x_agpct/100.0)                                 AS agent_cost_valid_base_legacy,


-- ── 三、出列层：在每件的最终 SELECT 追加（129 件同构）──────────────────────────
--    ★ 旧列一字不改，全部留锚；以下全为新增列。

       ROUND(e.agent_cost_lv1,4)                       AS agent_cost_lv1,
       ROUND(e.agent_cost_lv2,4)                       AS agent_cost_lv2,
       ROUND(e.agent_cost_lv3,4)                       AS agent_cost_lv3,
       ROUND(e.agent_cost_lv4,4)                       AS agent_cost_lv4,
       ROUND(e.agent_cost_lv5,4)                       AS agent_cost_lv5,
       ROUND(e.agent_pct_lv1,6)                        AS agent_pct_lv1,
       ROUND(e.agent_pct_lv2,6)                        AS agent_pct_lv2,
       ROUND(e.agent_pct_lv3,6)                        AS agent_pct_lv3,
       ROUND(e.agent_pct_lv4,6)                        AS agent_pct_lv4,
       ROUND(e.agent_pct_lv5,6)                        AS agent_pct_lv5,
       ROUND(e.retain_pct_lv1,6)                       AS retain_pct_lv1,
       ROUND(e.retain_pct_lv2,6)                       AS retain_pct_lv2,
       ROUND(e.retain_pct_lv3,6)                       AS retain_pct_lv3,
       ROUND(e.retain_pct_lv4,6)                       AS retain_pct_lv4,
       ROUND(e.retain_pct_lv5,6)                       AS retain_pct_lv5,
       ROUND(e.chain_depth_avg,4)                      AS chain_depth_avg,
       ROUND(e.agent_cost_chain_additive,4)            AS agent_cost_chain_additive,
       ROUND(e.agent_cost_chain_nested,4)              AS agent_cost_chain_nested,
       ROUND(-e.net - e.rebate - e.agent_cost_chain_nested,4)     AS residual_chain_nested,
       ROUND(-e.net - e.rebate - e.agent_cost_chain_additive,4)   AS residual_chain_additive,
       'AG03-UNRESOLVED-3READINGS'                     AS agent_formula_version,
       'ALL5_LEVELS_bet23_to_bet27'                    AS agent_level_scope,


-- ==============================================================================================
--  四、回归闸（用现有六件 CSV 作锚，零额外成本）
--  ----------------------------------------------------------------------------------------
--    ① 旧列一律逐行不变：cost_complement_b · residual_b · pct_complement · pct_top_bet23 ·
--       agent_cost_a_legacy · agent_cost_valid_base_legacy · residual_a
--    ② 八项台账不变：13,149,241,211 / 11,843,669,641 / 196,872,453 / 8,138,341 /
--                     8,073,461 / 188,734,111 / 180,660,651 / 161,156
--    ③ 恒等式：agent_cost_lv1 逐行 = cost_complement_b（甲即第一级，二者必须相等）
--    ④ 单调性：agent_cost_chain_nested ≤ agent_cost_chain_additive（数学必然）
--    ⑤ 层级零值：chain_depth = d 的行，agent_cost_lv(d+1) ~ lv5 必须恒为 0
--    ⑥ 预期量级（由 AG2 均值推算，供粗核，非硬闸）：
--         depth=5：甲 3.991% · 乙 38.588% · 丙 33.492%
--         depth=4：甲 6.000% · 乙 69.775% · 丙 57.478%
--         depth=3：甲 6.000% · 乙 54.112% · 丙 48.103%
--         depth=2：甲 5.932% · 乙 12.187% · 丙 11.816%
--         depth=1：甲 4.880% · 乙  4.880% · 丙  4.880%（单层三读法必然相等，自证闸）
-- ==============================================================================================


-- ==============================================================================================
--  五、AG1 修正版（W-50：原版因十进制标度溢出而未跑成）
--  ----------------------------------------------------------------------------------------
--  原错误：starrocks error: Return scale(47) exceeds maximum value(38)
--  成因：五个 DECIMAL(20,6) 连乘并连除 100.0，标度逐次累加至 47，超 StarRocks 上限 38。
--  修正：比率乘除一律走 DOUBLE，金额在聚合前 CAST 回 DECIMAL(20,4)。
--        同时把缺层由 0 改为 NULL 再以 100/0 代入，消除「缺层＝代理拿走 100%」之误算。
-- ==============================================================================================


-- -- AG1b -- 三种解读的全窗代理成本（修正标度 ＋ 修正缺层语义）
WITH ta AS (SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'),
r AS (
  SELECT b.bet01                                                          AS bet01,
         NULLIF(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0)       AS q1,
         NULLIF(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)), 0)       AS q2,
         NULLIF(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)), 0)       AS q3,
         NULLIF(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)), 0)       AS q4,
         NULLIF(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)), 0)       AS q5,
         COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)), 0)     AS p1,
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
d AS (SELECT DISTINCT bet01, q1, q2, q3, q4, q5, p1, net FROM r)
SELECT COUNT(*)                                                           AS n_rows_dedup,
       ROUND(SUM(-net), 4)                                                AS profit_total,
       ROUND(SUM(CAST(-net * (100.0 - p1)/100.0 AS DECIMAL(20,4))), 4)    AS cost_jia_single,
       ROUND(SUM(CAST(-net * ( COALESCE(100.0-q1,0) + COALESCE(100.0-q2,0)
                             + COALESCE(100.0-q3,0) + COALESCE(100.0-q4,0)
                             + COALESCE(100.0-q5,0))/100.0
                     AS DECIMAL(20,4))), 4)                               AS cost_yi_additive,
       ROUND(SUM(CAST(-net * (1.0
             - CAST(COALESCE(q1,100) AS DOUBLE)/100.0
             * CAST(COALESCE(q2,100) AS DOUBLE)/100.0
             * CAST(COALESCE(q3,100) AS DOUBLE)/100.0
             * CAST(COALESCE(q4,100) AS DOUBLE)/100.0
             * CAST(COALESCE(q5,100) AS DOUBLE)/100.0)
                     AS DECIMAL(20,4))), 4)                               AS cost_bing_nested,
       ROUND(SUM(CAST(-net * COALESCE(100.0-q1,0)/100.0 AS DECIMAL(20,4))), 4) AS cost_lv1,
       ROUND(SUM(CAST(-net * COALESCE(100.0-q2,0)/100.0 AS DECIMAL(20,4))), 4) AS cost_lv2,
       ROUND(SUM(CAST(-net * COALESCE(100.0-q3,0)/100.0 AS DECIMAL(20,4))), 4) AS cost_lv3,
       ROUND(SUM(CAST(-net * COALESCE(100.0-q4,0)/100.0 AS DECIMAL(20,4))), 4) AS cost_lv4,
       ROUND(SUM(CAST(-net * COALESCE(100.0-q5,0)/100.0 AS DECIMAL(20,4))), 4) AS cost_lv5
FROM d;
--    验收判据：
--      ① n_rows_dedup 必须 = 124,713,543 · profit_total 必须 = 196,872,453
--      ② cost_jia_single 必须 = 8,073,461（已锁台账）⇒ 同源自证
--      ③ cost_lv1 必须 = cost_jia_single（甲即第一级，二者恒等）
--      ④ cost_lv1 + cost_lv2 + cost_lv3 + cost_lv4 + cost_lv5 必须 = cost_yi_additive
--      ⑤ cost_bing_nested < cost_yi_additive（数学必然；不成立即公式抄错）
-- ==============================================================================================
