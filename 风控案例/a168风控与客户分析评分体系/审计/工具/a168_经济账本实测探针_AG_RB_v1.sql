-- ══════════════════════════════════════════════════════════════════════════════
--  a168 · 博彩经济账本 实测探针包  v1.0.0
--  目的：以数据库【真实配置表与结算数据】裁定三件事，不从报表总账反推
--        AG-01 bet23~bet27 字段语义
--        AG-02 五级层级关系（已由单调性初判为嵌套，此处求闭合证明）
--        AG-03 agent_cost 结算基数（stake / valid_bet / game_pnl / GGR / NGR）
--        RB-01 退水（bet15 配置率 ↔ bet16 实际金额）的结算标准
--        VB-01 validbet 归零 7.597% 的成因（游戏规则？对冲扣减？）
--  纪律：行注释 only（无块注释）· 无 OFFSET · ID 比较用 CAST(... AS BIGINT)
--        除法一律 NULLIF 护零 · 每条独立可跑 · 逐条留档
--  窗口：dt >= '2026-03-21' AND dt < '2026-08-07'（139 日）· bet02='101' 百家乐
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
--  P0 · 表名发现 —— 先找出配置表与结算表究竟叫什么，不猜
-- ══════════════════════════════════════════════════════════════════════════════
SELECT TABLE_SCHEMA, TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (  LOWER(TABLE_NAME) LIKE '%agent%'
      OR LOWER(TABLE_NAME) LIKE '%rebate%'
      OR LOWER(TABLE_NAME) LIKE '%commission%'
      OR LOWER(TABLE_NAME) LIKE '%settle%'
      OR LOWER(TABLE_NAME) LIKE '%report%'
      OR LOWER(TABLE_NAME) LIKE '%rule%'
      OR LOWER(TABLE_NAME) LIKE '%config%'
      OR LOWER(TABLE_NAME) LIKE '%setting%'
      OR LOWER(TABLE_NAME) LIKE '%rate%'
      OR LOWER(TABLE_NAME) LIKE '%level%'
      OR LOWER(TABLE_NAME) LIKE '%game%')
ORDER BY TABLE_NAME;


-- ══════════════════════════════════════════════════════════════════════════════
--  P1 · 列名发现 —— 在 agent 族表内定位「占成 / 退水 / 费率」列
--       参考线索：ag012 = 占成、ag003 = 退水（须由本查询证实，不得直接采信）
-- ══════════════════════════════════════════════════════════════════════════════
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND LOWER(TABLE_NAME) LIKE '%agent%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


-- ══════════════════════════════════════════════════════════════════════════════
--  P2 · AG-02 闭合证明 —— 嵌套链的「望远镜求和」是否成立
--       若嵌套成立：Σ(各级差分) + 末级 = bet23，即代理线合计占成 = bet23
--       n_telescope_ok 应 ≈ n；否则嵌套假设不成立
-- ══════════════════════════════════════════════════════════════════════════════
SELECT COUNT(*)                                                          AS n,
       SUM(CASE WHEN ABS( (b23-b24)+(b24-b25)+(b25-b26)+(b26-b27)+b27
                          - b23 ) < 0.000001 THEN 1 ELSE 0 END)          AS n_telescope_ok,
       SUM(CASE WHEN b23 > 100 OR b27 < 0 THEN 1 ELSE 0 END)             AS n_out_of_range,
       MIN(b23) AS min_b23, MAX(b23) AS max_b23,
       MIN(b27) AS min_b27, MAX(b27) AS max_b27,
       AVG(b23) AS avg_b23, AVG(b27) AS avg_b27,
       AVG(b23 - b27)                                                    AS avg_span_lv1_lv5
FROM (
  SELECT COALESCE(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,6)),0) AS b23,
         COALESCE(CAST(NULLIF(TRIM(bet24),'') AS DECIMAL(20,6)),0) AS b24,
         COALESCE(CAST(NULLIF(TRIM(bet25),'') AS DECIMAL(20,6)),0) AS b25,
         COALESCE(CAST(NULLIF(TRIM(bet26),'') AS DECIMAL(20,6)),0) AS b26,
         COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,6)),0) AS b27
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
    AND bet02 = '101' AND category = '1'
) t;


-- ══════════════════════════════════════════════════════════════════════════════
--  P3 · 106 种组合全枚举 —— 配置表长什么样，一次看全
--       同时带出每种组合的注额与输赢，判断是否与代理线一一对应
-- ══════════════════════════════════════════════════════════════════════════════
SELECT TRIM(bet23) AS lv1, TRIM(bet24) AS lv2, TRIM(bet25) AS lv3,
       TRIM(bet26) AS lv4, TRIM(bet27) AS lv5,
       COUNT(*)                                                          AS n_bets,
       COUNT(DISTINCT CAST(NULLIF(TRIM(bet05),'') AS BIGINT))            AS n_members,
       COUNT(DISTINCT CAST(NULLIF(TRIM(bet18),'') AS BIGINT))            AS n_lv1_agents,
       COUNT(DISTINCT CAST(NULLIF(TRIM(bet22),'') AS BIGINT))            AS n_lv5_agents,
       ROUND(SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
               / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0)),2) AS stake,
       ROUND(SUM(CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))
               / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0)),2) AS valid_bet,
       ROUND(SUM(-CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4))
               / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0)),2) AS platform_profit,
       ROUND(SUM(CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4))
               / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0)),2) AS rebate_amt
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1'
GROUP BY TRIM(bet23), TRIM(bet24), TRIM(bet25), TRIM(bet26), TRIM(bet27)
ORDER BY n_bets DESC;


-- ══════════════════════════════════════════════════════════════════════════════
--  P4 · 代理层级与占成的配对 —— bet18~bet22（五级代理ID）↔ bet23~bet27（五级占成）
--       若某级代理为空而对应占成非空（或反之），则配对假设不成立
-- ══════════════════════════════════════════════════════════════════════════════
SELECT COUNT(*)                                                          AS n,
       SUM(CASE WHEN NULLIF(TRIM(bet18),'') IS NULL THEN 1 ELSE 0 END)   AS null_lv1_agent,
       SUM(CASE WHEN NULLIF(TRIM(bet19),'') IS NULL THEN 1 ELSE 0 END)   AS null_lv2_agent,
       SUM(CASE WHEN NULLIF(TRIM(bet20),'') IS NULL THEN 1 ELSE 0 END)   AS null_lv3_agent,
       SUM(CASE WHEN NULLIF(TRIM(bet21),'') IS NULL THEN 1 ELSE 0 END)   AS null_lv4_agent,
       SUM(CASE WHEN NULLIF(TRIM(bet22),'') IS NULL THEN 1 ELSE 0 END)   AS null_lv5_agent,
       SUM(CASE WHEN NULLIF(TRIM(bet22),'') IS NULL
                 AND COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,6)),0) > 0
                THEN 1 ELSE 0 END)                                       AS lv5_agent_null_but_pct_gt0,
       SUM(CASE WHEN NULLIF(TRIM(bet22),'') IS NOT NULL
                 AND COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,6)),0) = 0
                THEN 1 ELSE 0 END)                                       AS lv5_agent_ok_but_pct_zero,
       COUNT(DISTINCT CAST(NULLIF(TRIM(bet18),'') AS BIGINT))            AS n_distinct_lv1
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1';


-- ══════════════════════════════════════════════════════════════════════════════
--  P5 · AG-03 结算基数判决 —— 以 agent 配置表的实际占成率反查
--       ⚠ 请先跑 P1 拿到真实列名，再把 ag012 / ag003 / ag001 替换为实际列名
--       若 agent 表的占成率与 bet23 一致 ⇒ bet23 确为占成
--       若一致的是 100 - bet23 ⇒ bet23 是【公司自留】而非代理占成
-- ══════════════════════════════════════════════════════════════════════════════
SELECT a.ag012                                                           AS agent_cfg_pct,
       COUNT(*)                                                          AS n_bets,
       AVG(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)))              AS avg_bet23,
       AVG(100 - CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)))        AS avg_100_minus_bet23,
       AVG(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)))              AS avg_bet27
FROM ods_mariadb_2b.ods_a168_bet02 b
LEFT JOIN ods_mariadb_2b.ods_a168_agent a
       ON CAST(NULLIF(TRIM(a.ag001),'') AS BIGINT)
        = CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101' AND b.category = '1'
GROUP BY a.ag012
ORDER BY n_bets DESC;


-- ══════════════════════════════════════════════════════════════════════════════
--  RB-01 · 退水结算标准 —— bet15（配置率）× 基数 = bet16（实际金额）？
--          逐一试四种基数，看哪一种的命中率最高
-- ══════════════════════════════════════════════════════════════════════════════
SELECT COUNT(*)                                                          AS n,
       SUM(CASE WHEN rb > 0 THEN 1 ELSE 0 END)                           AS n_rebate_gt0,
       SUM(CASE WHEN pct > 0 THEN 1 ELSE 0 END)                          AS n_pct_gt0,
       SUM(CASE WHEN ABS(rb - vb  * pct/100.0) < 0.01 THEN 1 ELSE 0 END) AS hit_validbet,
       SUM(CASE WHEN ABS(rb - stk * pct/100.0) < 0.01 THEN 1 ELSE 0 END) AS hit_stake,
       SUM(CASE WHEN ABS(rb - vb  * pct/1000.0) < 0.01 THEN 1 ELSE 0 END)AS hit_validbet_permille,
       SUM(CASE WHEN ABS(rb - vb  * pct) < 0.01 THEN 1 ELSE 0 END)       AS hit_validbet_raw,
       AVG(pct) AS avg_pct, MAX(pct) AS max_pct,
       AVG(CASE WHEN rb > 0 THEN rb / NULLIF(vb,0) * 100 END)            AS implied_pct_on_valid
FROM (
  SELECT CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4))    AS rb,
         CAST(NULLIF(TRIM(bet15),'') AS DECIMAL(20,6))    AS pct,
         CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) AS vb,
         CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))    AS stk
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
    AND bet02 = '101' AND category = '1'
) t;


-- ══════════════════════════════════════════════════════════════════════════════
--  VB-01 · validbet 归零 7.597% 的成因 —— 按 23 种玩法拆解
--          若归零集中在少数玩法（和局/对子等）⇒ 游戏规则，非对冲
--          若均匀分布于所有玩法 ⇒ 与结果相关（推平/对冲）
-- ══════════════════════════════════════════════════════════════════════════════
SELECT TRIM(bet09)                                                       AS product_code,
       COUNT(*)                                                          AS n_bets,
       SUM(CASE WHEN CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) = 0
                 AND CAST(NULLIF(TRIM(bet13),'')    AS DECIMAL(20,4)) > 0
                THEN 1 ELSE 0 END)                                       AS n_zero_valid,
       ROUND(100.0 * SUM(CASE WHEN CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) = 0
                               AND CAST(NULLIF(TRIM(bet13),'')    AS DECIMAL(20,4)) > 0
                              THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 3) AS pct_zero_valid,
       ROUND(AVG(CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))
               / NULLIF(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)),0)), 4) AS avg_vb_ratio,
       SUM(CASE WHEN TRIM(commission) = '1' THEN 1 ELSE 0 END)           AS n_freecomm,
       ROUND(SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
               / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0)),2) AS stake
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1'
GROUP BY TRIM(bet09)
ORDER BY n_bets DESC;


-- ══════════════════════════════════════════════════════════════════════════════
--  VB-02 · 归零是否与「输赢结果」相关 —— 判定推平 vs 对冲
--          若归零几乎全部落在 bet17 = 0（和局推平）⇒ 游戏规则
-- ══════════════════════════════════════════════════════════════════════════════
SELECT CASE WHEN CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) = 0
            THEN 'zero_valid' ELSE 'has_valid' END                       AS grp,
       COUNT(*)                                                          AS n,
       SUM(CASE WHEN CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)) = 0
                THEN 1 ELSE 0 END)                                       AS n_pnl_zero,
       SUM(CASE WHEN CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)) > 0
                THEN 1 ELSE 0 END)                                       AS n_pnl_pos,
       SUM(CASE WHEN CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)) < 0
                THEN 1 ELSE 0 END)                                       AS n_pnl_neg,
       SUM(CASE WHEN CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) > 0
                THEN 1 ELSE 0 END)                                       AS n_rebate_gt0
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1'
GROUP BY CASE WHEN CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) = 0
              THEN 'zero_valid' ELSE 'has_valid' END;


-- ══════════════════════════════════════════════════════════════════════════════
--  SETTLE-01 · 结算恒等式 H16 复核 —— bet17 = bet14 - bet13 + bet16 ?
--              这是全套经济账本的地基，须 100% 闭合
-- ══════════════════════════════════════════════════════════════════════════════
SELECT COUNT(*)                                                          AS n,
       SUM(CASE WHEN ABS(net - (payout - stk + rb)) < 0.01
                THEN 1 ELSE 0 END)                                       AS n_identity_ok,
       SUM(CASE WHEN ABS(net - (payout - stk))      < 0.01
                THEN 1 ELSE 0 END)                                       AS n_identity_no_rebate,
       ROUND(SUM(net),2) AS sum_net, ROUND(SUM(payout),2) AS sum_payout,
       ROUND(SUM(stk),2) AS sum_stake, ROUND(SUM(rb),2)   AS sum_rebate
FROM (
  SELECT CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)) AS net,
         CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4)) AS payout,
         CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)) AS stk,
         CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) AS rb
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
    AND bet02 = '101' AND category = '1'
) t;


-- ══════════════════════════════════════════════════════════════════════════════
--  RECON-01 · 平台自报表对账 —— 用 a168 自己的日报验证我们的汇总口径
--             ⚠ 列名请依 P1 结果替换；此处以常见命名占位
-- ══════════════════════════════════════════════════════════════════════════════
SELECT r.dt                                                              AS report_dt,
       COUNT(*)                                                          AS n_report_rows,
       ROUND(SUM(CAST(NULLIF(TRIM(r.bet_amount),'')   AS DECIMAL(20,4))),2) AS report_stake,
       ROUND(SUM(CAST(NULLIF(TRIM(r.valid_amount),'') AS DECIMAL(20,4))),2) AS report_valid,
       ROUND(SUM(CAST(NULLIF(TRIM(r.win_amount),'')   AS DECIMAL(20,4))),2) AS report_pnl
FROM ods_mariadb_2b.ods_a168_dailyreport_member r
WHERE r.dt >= '2026-03-21' AND r.dt < '2026-08-07'
GROUP BY r.dt
ORDER BY r.dt;
