-- ══════════════════════════════════════════════════════════════════════════════
--  AGENT-01 · 五级代理经济台账（新模块 · 补 #078 S03_agent_score 之缺）
--  ---------------------------------------------------------------------------
--  为何新建而非改 #078：
--    #078 的 q 粒度写死为 v.bet20 AS lv3，只出【第三层】代理，455 行。
--    LV1/LV2/LV4/LV5 一层都没有。改它会改变既有 schema 与 audit_rn，
--    故另立一件，#078 原样保留作历史对照。
--  ---------------------------------------------------------------------------
--  已证事实（1.26 亿行实测）：
--    bet18=LV1 顶级 · bet19=LV2 · bet20=LV3 · bet21=LV4 · bet22=LV5 底级
--    bet23~bet27 与之一一对应，单调递减 99.9821%，仅 106 种组合 ⇒ 嵌套下行链
--    望远镜消项：Σ各级实得 = bet23  ⇒ 代理线合计占成率 = bet23
--    AG-03 = B：bet23 是【公司自留】比例，代理实得 =(100 − bet23)
--  ---------------------------------------------------------------------------
--  测试线处置（先生裁定：标记后分开计算）：
--    is_test_line = 1  该级代理本身在 age022='1' 名单内
--    line_has_test = 1 该注单的五级链中任一级为测试线
--    ★ 生产口径：line_has_test = 0 的行才计入 stake/profit/ngr/net_margin
--    ★ 审计口径：line_has_test = 1 单独成列，可核对被剔除了多少，不并入生产数
--    绝不把测试线并进真实代理与会员的任何指标
--  ---------------------------------------------------------------------------
--  清洗（与 HF5 x_bs 逐字同源）：
--    ① bet01 去重 rn=1（updatetime/sync_time/dt 降序取最新版）
--    ② 五级链测试线标记（不在此处剔除，改为标记后分列）
--  纪律：行注释 only · 无 OFFSET · ID 用 CAST(... AS BIGINT) · 除法 NULLIF 护零
--  窗口：dt >= '2026-03-21' AND dt < '2026-08-07' · bet02='101' · category='1'
-- ══════════════════════════════════════════════════════════════════════════════

WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT)                AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.bet05, b.bet11, b.bet13, b.bet16, b.bet17, b.validbet,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.bet23, b.bet24, b.bet25, b.bet26, b.bet27,
         b.dt, b.category, b.bet38,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
vd AS (
  SELECT r.*,
         CASE WHEN t1.aid IS NOT NULL THEN 1 ELSE 0 END                  AS lv1_is_test,
         CASE WHEN t2.aid IS NOT NULL THEN 1 ELSE 0 END                  AS lv2_is_test,
         CASE WHEN t3.aid IS NOT NULL THEN 1 ELSE 0 END                  AS lv3_is_test,
         CASE WHEN t4.aid IS NOT NULL THEN 1 ELSE 0 END                  AS lv4_is_test,
         CASE WHEN t5.aid IS NOT NULL THEN 1 ELSE 0 END                  AS lv5_is_test,
         CASE WHEN COALESCE(t1.aid,t2.aid,t3.aid,t4.aid,t5.aid) IS NOT NULL
              THEN 1 ELSE 0 END                                          AS line_has_test
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(r.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(r.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(r.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(r.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(r.bet22),'') AS BIGINT)
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
),
bs AS (
  SELECT CAST(NULLIF(TRIM(v.bet05),'') AS BIGINT)                        AS member_id,
         v.dt                                                            AS bet_date,
         v.line_has_test,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))             AS stake,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))             AS valid_bet,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))             AS rebate_cost,
         -CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))             AS profit,
         COALESCE(CAST(NULLIF(TRIM(v.bet23),'') AS DECIMAL(20,6)),0)     AS pct_lv1,
         COALESCE(CAST(NULLIF(TRIM(v.bet24),'') AS DECIMAL(20,6)),0)     AS pct_lv2,
         COALESCE(CAST(NULLIF(TRIM(v.bet25),'') AS DECIMAL(20,6)),0)     AS pct_lv3,
         COALESCE(CAST(NULLIF(TRIM(v.bet26),'') AS DECIMAL(20,6)),0)     AS pct_lv4,
         COALESCE(CAST(NULLIF(TRIM(v.bet27),'') AS DECIMAL(20,6)),0)     AS pct_lv5,
         CAST(NULLIF(TRIM(v.bet18),'') AS BIGINT) AS a1, v.lv1_is_test,
         CAST(NULLIF(TRIM(v.bet19),'') AS BIGINT) AS a2, v.lv2_is_test,
         CAST(NULLIF(TRIM(v.bet20),'') AS BIGINT) AS a3, v.lv3_is_test,
         CAST(NULLIF(TRIM(v.bet21),'') AS BIGINT) AS a4, v.lv4_is_test,
         CAST(NULLIF(TRIM(v.bet22),'') AS BIGINT) AS a5, v.lv5_is_test
  FROM vd v
),
lvl AS (
  SELECT 1 AS agent_level, a1 AS agent_id, a1 AS lv1_id, NULL AS parent_id, lv1_is_test AS is_test_line,
         (pct_lv1 - pct_lv2) / 100.0 AS own_share, line_has_test,
         member_id, bet_date, stake, valid_bet, rebate_cost, profit, pct_lv1
  FROM bs WHERE a1 IS NOT NULL
  UNION ALL
  SELECT 2, a2, a1, a1, lv2_is_test, (pct_lv2 - pct_lv3) / 100.0, line_has_test,
         member_id, bet_date, stake, valid_bet, rebate_cost, profit, pct_lv1
  FROM bs WHERE a2 IS NOT NULL
  UNION ALL
  SELECT 3, a3, a1, a2, lv3_is_test, (pct_lv3 - pct_lv4) / 100.0, line_has_test,
         member_id, bet_date, stake, valid_bet, rebate_cost, profit, pct_lv1
  FROM bs WHERE a3 IS NOT NULL
  UNION ALL
  SELECT 4, a4, a1, a3, lv4_is_test, (pct_lv4 - pct_lv5) / 100.0, line_has_test,
         member_id, bet_date, stake, valid_bet, rebate_cost, profit, pct_lv1
  FROM bs WHERE a4 IS NOT NULL
  UNION ALL
  SELECT 5, a5, a1, a4, lv5_is_test, pct_lv5 / 100.0, line_has_test,
         member_id, bet_date, stake, valid_bet, rebate_cost, profit, pct_lv1
  FROM bs WHERE a5 IS NOT NULL
)
SELECT agent_level,
       agent_id,
       MAX(lv1_id)                                                       AS top_agent_id,
       MAX(parent_id)                                                    AS parent_agent_id,
       MAX(is_test_line)                                                 AS is_test_line,

       COUNT(*)                                                          AS n_bets_all,
       SUM(CASE WHEN line_has_test = 0 THEN 1 ELSE 0 END)                AS n_bets_prod,
       SUM(CASE WHEN line_has_test = 1 THEN 1 ELSE 0 END)                AS n_bets_testline,
       COUNT(DISTINCT member_id)                                         AS n_members_all,
       COUNT(DISTINCT CASE WHEN line_has_test = 0 THEN member_id END)    AS n_members_prod,
       COUNT(DISTINCT bet_date)                                          AS active_days,
       MIN(bet_date)                                                     AS first_seen,
       MAX(bet_date)                                                     AS last_seen,

       ROUND(AVG(own_share) * 100, 6)                                    AS own_share_pct,
       ROUND(AVG(100 - pct_lv1), 6)                                      AS line_agent_pct,
       ROUND(AVG(pct_lv1), 6)                                            AS company_retain_pct,

       ROUND(SUM(CASE WHEN line_has_test = 0 THEN stake       ELSE 0 END), 4) AS stake,
       ROUND(SUM(CASE WHEN line_has_test = 0 THEN valid_bet   ELSE 0 END), 4) AS valid_bet,
       ROUND(SUM(CASE WHEN line_has_test = 0 THEN profit      ELSE 0 END), 4) AS profit,
       ROUND(SUM(CASE WHEN line_has_test = 0 THEN rebate_cost ELSE 0 END), 4) AS rebate_cost,
       ROUND(SUM(CASE WHEN line_has_test = 0
                      THEN profit * (100 - pct_lv1) / 100.0 ELSE 0 END), 4)   AS agent_cost_line,
       ROUND(SUM(CASE WHEN line_has_test = 0
                      THEN profit * own_share ELSE 0 END), 4)                 AS agent_cost_own,
       ROUND(SUM(CASE WHEN line_has_test = 0 THEN profit - rebate_cost ELSE 0 END), 4) AS ngr,
       ROUND(SUM(CASE WHEN line_has_test = 0
                      THEN profit - rebate_cost - profit * (100 - pct_lv1) / 100.0
                      ELSE 0 END), 4)                                          AS net_margin,
       ROUND(SUM(CASE WHEN line_has_test = 0 THEN profit - rebate_cost - profit * (100 - pct_lv1) / 100.0 ELSE 0 END)
           / NULLIF(SUM(CASE WHEN line_has_test = 0 THEN stake ELSE 0 END), 0), 8) AS net_margin_rate,
       ROUND(SUM(CASE WHEN line_has_test = 0 THEN profit ELSE 0 END)
           / NULLIF(SUM(CASE WHEN line_has_test = 0 THEN stake ELSE 0 END), 0), 8) AS hold_rate,

       ROUND(SUM(CASE WHEN line_has_test = 1 THEN stake  ELSE 0 END), 4)  AS stake_testline_audit,
       ROUND(SUM(CASE WHEN line_has_test = 1 THEN profit ELSE 0 END), 4)  AS profit_testline_audit,

       CASE WHEN MAX(is_test_line) = 1 THEN 'TEST_LINE'
            WHEN SUM(CASE WHEN line_has_test = 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_PROD_ROWS'
            ELSE 'PRODUCTION' END                                        AS agent_status
FROM lvl
GROUP BY agent_level, agent_id
ORDER BY agent_level, net_margin ASC;
