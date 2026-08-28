-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ HF9g · G-05 验收闸 · 自足版（#018 DX05_product_panorama）· 一次扫描出全部判据 ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【为何不能只验「NULL 消失」】修复可能由「错 join」变成「有数据但业务错 join」，是更危险之假修复。
--   故本闸并验三支：① 同族性 ② 覆盖率与范围标注一致性 ③ 业务列非空之落点须与范围标注吻合。
-- 来源：a168_SQL总包_v12_0_0_HF9g_原版审计版_六层商业版.sql 之 #018 区块逐字内嵌，
--       仅去除最外层 SELECT w.* / ROW_NUMBER() / ORDER BY 三段（不影响任何聚合值）。
SELECT                                                                                              -- 取列：起始取列子句
  COUNT(*)                                                                        AS n_rows,        -- 计数表达式：本件总行数（HF9f 实测为 8）
  COUNT(DISTINCT w.product_code)                                                  AS n_product_code,-- 计数表达式：product_code 相异值数
  SUM(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' THEN 1 ELSE 0 END)        AS n_in_scope,    -- 聚合取值：范围内行数（应恰为 1，即 bet02='101'）
  SUM(CASE WHEN w.template_scope = 'OUT_OF_SCOPE_bet02_ne_101' THEN 1 ELSE 0 END) AS n_out_scope,   -- 聚合取值：范围外行数
  SUM(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' AND w.stake IS NOT NULL THEN 1 ELSE 0 END)  -- 聚合取值：起始 —— 范围内且六层已接上者
                                                                                  AS n_in_joined,   -- 聚合取值：★ 判据① 应等于 n_in_scope
  SUM(CASE WHEN w.template_scope = 'OUT_OF_SCOPE_bet02_ne_101' AND w.stake IS NOT NULL THEN 1 ELSE 0 END) -- 聚合取值：起始 —— 范围外却接上者
                                                                                  AS n_out_joined,  -- 聚合取值：★ 判据② 应恒为 0，否则跨域错接
  MAX(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' THEN w.product_code END)  AS in_scope_code, -- 聚合取值：★ 判据③ 范围内之 product_code，应为 '101'
  ROUND(MAX(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' THEN w.stake END), 2)                 -- 聚合取值：起始 —— 范围内之本金
                                                                                  AS in_scope_stake,-- 聚合取值：★ 判据④ 应等于 #075 全体 stake 13,436,093,473.80（同域同窗同锚）
  MAX(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' THEN w.pr_global_population_n END)          -- 聚合取值：起始 —— 血统：参照总体规模
                                                                                  AS in_scope_pop_n,-- 聚合取值：★ 判据⑤ 应等于 n_rows
  SUM(CASE WHEN w.stake IS NULL THEN 1 ELSE 0 END)                                AS n_six_null,    -- 聚合取值：六层为空之行数，应等于 n_out_scope（NULL 由设计而来，非缺陷）
  CASE WHEN SUM(CASE WHEN w.template_scope = 'OUT_OF_SCOPE_bet02_ne_101' AND w.stake IS NOT NULL THEN 1 ELSE 0 END) > 0  -- 条件分支：起始 —— 范围外接上即跨域错接
         THEN 'FAIL_CROSS_DOMAIN_JOIN'                                                              -- 分支取值：假修复，须回退
       WHEN SUM(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' AND w.stake IS NOT NULL THEN 1 ELSE 0 END)             -- 分支判定：范围内未接上
            <> SUM(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' THEN 1 ELSE 0 END)             -- 分支判定：续
         THEN 'FAIL_IN_SCOPE_NOT_JOINED'                                                            -- 分支取值：同族仍未接上，键仍错
       WHEN MAX(CASE WHEN w.template_scope = 'IN_SCOPE_bet02_101' THEN w.product_code END) <> '101' -- 分支判定：范围内之码非 101
         THEN 'FAIL_SCOPE_TAG_MISMATCH'                                                             -- 分支取值：范围标注与实值不符
       ELSE 'PASS_SAME_FAMILY_JOIN' END                                           AS verdict        -- 条件分支：收束判词
FROM (
  WITH
    x_ranked AS (
    SELECT b.bet01, b.bet02, b.bet03, b.bet04, b.bet05, b.bet09, b.bet11, b.bet13,   -- 直接取列：HF9g·G-05 增取 b.bet02（游戏类别），供 x_prodcat 派生
           b.bet15, b.bet16, b.bet17, b.bet18, b.bet19, b.bet20, b.bet21,
           b.bet22, b.bet23, b.bet24, b.bet25, b.bet26, b.bet27, b.bet38, b.bet39, b.category, b.commission,
           b.dt, b.eid, b.ip, b.validbet, b.updatetime, b.sync_time,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS x_rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
      AND b.bet02 = '101'
      AND b.sync_time <= '2026-08-27 09:00:00'
  ),
    x_testagent AS (
    SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
  ),
    x_bs0 AS (
    SELECT b.bet05 AS x_member, b.eid AS x_dealer, b.bet39 AS x_table, b.bet02 AS x_prodcat,   -- 直接取列：HF9g·G-05 派生 x_prodcat（bet02 游戏类别），与 q.product_code 同族
           b.bet03 AS x_shoe, b.ip AS x_ip, b.bet09 AS x_product, b.dt AS x_date,
           CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                      AS x_round,
           CONCAT_WS('|', b.bet39, b.bet03)                               AS x_tblshoe,
           CAST(NULLIF(TRIM(b.bet04),'') AS INT)                          AS x_rno,
           CASE WHEN b.dt >= '2026-07-08' THEN 1 ELSE 0 END               AS x_rec,
           CASE WHEN TRIM(b.commission)='1' THEN 1 ELSE 0 END             AS x_freecomm,
           CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))            AS x_stake,
           CAST(NULLIF(TRIM(b.validbet),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))            AS x_valid,
           CAST(NULLIF(TRIM(b.bet16),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))            AS x_rebate,
           CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))            AS x_net,
           CAST(NULLIF(TRIM(b.bet15),'') AS DECIMAL(20,6))                AS x_rbpct,
           COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)),0)   AS x_agpct,
          NULLIF(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,6)),0)     AS x_rate1,
          NULLIF(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,6)),0)     AS x_rate2,
          NULLIF(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,6)),0)     AS x_rate3,
          NULLIF(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,6)),0)     AS x_rate4,
          NULLIF(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,6)),0)     AS x_rate5,
          (CASE WHEN NULLIF(CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT),0) IS NOT NULL THEN 5
                WHEN NULLIF(CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT),0) IS NOT NULL THEN 4
                WHEN NULLIF(CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT),0) IS NOT NULL THEN 3
                WHEN NULLIF(CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT),0) IS NOT NULL THEN 2
                WHEN NULLIF(CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT),0) IS NOT NULL THEN 1
                ELSE 0 END)                                             AS x_chain_depth,
           CASE WHEN COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,
                              t4.agent_id,t5.agent_id) IS NOT NULL
                THEN 1 ELSE 0 END                                        AS f_testline
    FROM x_ranked b
    LEFT JOIN x_testagent t1 ON t1.agent_id = b.bet18
    LEFT JOIN x_testagent t2 ON t2.agent_id = b.bet19
    LEFT JOIN x_testagent t3 ON t3.agent_id = b.bet20
    LEFT JOIN x_testagent t4 ON t4.agent_id = b.bet21
    LEFT JOIN x_testagent t5 ON t5.agent_id = b.bet22
    WHERE b.x_rn = 1
      AND b.category='1' AND UPPER(TRIM(b.bet38))='N'
      AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
  ),
  x_mk AS (
    SELECT s.*,
           CASE WHEN s.f_testline = 0 THEN 1 ELSE 0 END                 AS is_clean
    FROM x_bs0 s
  ),
  x_agg AS (
    SELECT s.x_prodcat                                                       AS x_key,   -- 直接取列：HF9g·G-05 键由 s.x_product（bet09）改 s.x_prodcat（bet02），与 q.product_code 同族
           COUNT(*) AS n_bets, COUNT(DISTINCT s.x_round) AS n_rounds,
           COUNT(DISTINCT s.x_date) AS active_days, COUNT(DISTINCT s.x_tblshoe) AS active_shoes,
           COUNT(DISTINCT CONCAT_WS('|', s.x_date, s.x_table)) AS active_sessions,
           COUNT(DISTINCT s.x_table) AS n_tables, COUNT(DISTINCT s.x_dealer) AS n_dealers,
           COUNT(DISTINCT s.x_ip) AS n_ips, COUNT(DISTINCT s.x_product) AS n_products,
           MIN(s.x_date) AS first_seen_d, MAX(s.x_date) AS last_seen_d,
           SUM(s.x_stake) AS stake, SUM(s.x_valid) AS valid, SUM(s.x_rebate) AS rebate,
           SUM(s.x_net) AS net, SUM(-s.x_net *(100.0-s.x_agpct)/100.0) AS agent_cost,
           AVG(100.0-s.x_agpct)                   AS agent_pct,
           AVG(s.x_agpct)                         AS company_retain_pct,
           SUM(-s.x_net *s.x_agpct/100.0)         AS agent_cost_a_legacy,
           SUM(s.x_valid*s.x_agpct/100.0)         AS agent_cost_valid_base_legacy,
          AVG(COALESCE(s.x_rate1,100)) AS retain_pct_lv1, AVG(COALESCE(s.x_rate2,100)) AS retain_pct_lv2,
          AVG(COALESCE(s.x_rate3,100)) AS retain_pct_lv3, AVG(COALESCE(s.x_rate4,100)) AS retain_pct_lv4,
          AVG(COALESCE(s.x_rate5,100)) AS retain_pct_lv5, AVG(s.x_chain_depth) AS chain_depth_avg,
          AVG(COALESCE(100.0-s.x_rate1,0)) AS agent_pct_lv1, AVG(COALESCE(100.0-s.x_rate2,0)) AS agent_pct_lv2,
          AVG(COALESCE(100.0-s.x_rate3,0)) AS agent_pct_lv3, AVG(COALESCE(100.0-s.x_rate4,0)) AS agent_pct_lv4,
          AVG(COALESCE(100.0-s.x_rate5,0)) AS agent_pct_lv5,
          SUM(-s.x_net*COALESCE(100.0-s.x_rate1,0)/100.0)                        AS agent_cost_lv1,
          SUM(-s.x_net*COALESCE(100.0-s.x_rate2,0)/100.0)                        AS agent_cost_lv2,
          SUM(-s.x_net*COALESCE(100.0-s.x_rate3,0)/100.0)                        AS agent_cost_lv3,
          SUM(-s.x_net*COALESCE(100.0-s.x_rate4,0)/100.0)                        AS agent_cost_lv4,
          SUM(-s.x_net*COALESCE(100.0-s.x_rate5,0)/100.0)                        AS agent_cost_lv5,
          SUM(-s.x_net*(COALESCE(100.0-s.x_rate1,0)+COALESCE(100.0-s.x_rate2,0)
                       +COALESCE(100.0-s.x_rate3,0)+COALESCE(100.0-s.x_rate4,0)
                       +COALESCE(100.0-s.x_rate5,0))/100.0)                   AS agent_cost_chain_additive,
          SUM(-s.x_net*(1.0 - CAST(COALESCE(s.x_rate1,100) AS DOUBLE)/100.0
                            * CAST(COALESCE(s.x_rate2,100) AS DOUBLE)/100.0
                            * CAST(COALESCE(s.x_rate3,100) AS DOUBLE)/100.0
                            * CAST(COALESCE(s.x_rate4,100) AS DOUBLE)/100.0
                            * CAST(COALESCE(s.x_rate5,100) AS DOUBLE)/100.0))
                                                                       AS agent_cost_chain_nested,
           AVG(s.x_rbpct) AS rbpct, AVG(s.x_freecomm*1.0) AS freecomm_rate,
           PERCENTILE_APPROX(s.x_stake,0.25) AS p25, PERCENTILE_APPROX(s.x_stake,0.50) AS p50,
           PERCENTILE_APPROX(s.x_stake,0.75) AS p75, PERCENTILE_APPROX(s.x_stake,0.90) AS p90,
           PERCENTILE_APPROX(s.x_stake,0.95) AS p95, PERCENTILE_APPROX(s.x_stake,0.99) AS p99,
           PERCENTILE_APPROX(s.x_valid,0.50) AS p50_valid,
           PERCENTILE_APPROX(s.x_net,0.50)   AS p50_profit,
           SUM(CASE WHEN s.x_freecomm = 1 THEN s.x_stake ELSE 0 END) AS st_in,
           SUM(CASE WHEN s.x_freecomm = 1 THEN 1 ELSE 0 END)         AS nb_in,
           SUM(CASE WHEN s.x_freecomm = 1 THEN s.x_net ELSE 0 END)   AS net_in,
           SUM(CASE WHEN NOT (s.x_freecomm = 1) THEN s.x_stake ELSE 0 END) AS st_out,
           SUM(CASE WHEN NOT (s.x_freecomm = 1) THEN 1 ELSE 0 END)         AS nb_out,
           SUM(CASE WHEN NOT (s.x_freecomm = 1) THEN s.x_net ELSE 0 END)   AS net_out,
           SUM(CASE WHEN s.x_rec=1 THEN s.x_stake ELSE 0 END) AS st_rec,
           SUM(CASE WHEN s.x_rec=1 THEN 1 ELSE 0 END)         AS nb_rec
    FROM x_mk s
    WHERE s.is_clean = 1
      AND s.x_prodcat IS NOT NULL AND TRIM(CAST(s.x_prodcat AS STRING)) <> ''   -- 过滤条件：HF9g·G-05 同步改用 x_prodcat
    GROUP BY s.x_prodcat   -- 分组子句：HF9g·G-05 同步改用 x_prodcat
  ),
    q AS (
      WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§DX-05）
        SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§DX-05）
      ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§DX-05）
        SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
               b.bet05, b.bet11, b.bet13, b.bet14, b.bet16,                                               -- 续行：接续上一取列子句，续列 b.bet05, b.bet11, b.bet13, b.bet14, b.bet16，涉 bet05（会员号）、bet11（汇率）、bet13（下注金额）
               b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
               b.bet38, b.category, b.eid, b.validbet,                                                    -- 续行：接续上一取列子句，续列 b.bet38, b.category, b.eid, b.validbet，涉 bet38（重對）、eid（荷官工号）、validbet（有效投注（洗码量））
               ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
                 PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
                 ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
        FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
        WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
          AND b.sync_time <= '2026-08-27 09:00:00'
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§DX-05）
      o AS (                                                                                              -- 公共表表达式：开启中间结果集 o，其后各行为其定义体（§DX-05）
        SELECT r.bet02 AS product_code, r.bet05 AS member_id, r.eid AS dealer_id,                         -- 取列：起始取列子句，本行先取「dealer_id」，涉 bet02（游戏类别）、bet05（会员号）、eid（荷官工号）
               CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,                    -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
               COALESCE(CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                        CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                  -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS validbet,                 -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「validbet」
               (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl,                 -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
               CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS rebate                    -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
        FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
        LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
        LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
        LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
        LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
        LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
        WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（重對）
          AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
          AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
          AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
      )                                                                                                   -- 续行：收束上方的子查询或函数括号（§DX-05）
      SELECT product_code,                                                                                -- 取列：起始取列子句，本行先列 product_code
             CASE WHEN product_code = '101' THEN '百家乐（本报告口径）' ELSE '其他产品' END AS scope,                   -- 条件分支：产出「scope」
             COUNT(*)                                  AS n_orders,                                       -- 计数表达式：产出「n_orders」
             COUNT(DISTINCT member_id)                 AS n_member,                                       -- 计数表达式：统计去重个数，产出「n_member」
             COUNT(DISTINCT dealer_id)                 AS n_dealer,                                       -- 计数表达式：统计去重个数，产出「n_dealer」
             SUM(stake)                                AS stake_total,                                    -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_total」
             SUM(validbet)                             AS validbet_total,                                 -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet_total」
             SUM(game_pnl)                             AS player_pnl,                                     -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「player_pnl」
             -SUM(game_pnl)                            AS ggr,                                            -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「ggr」
             -SUM(game_pnl) / NULLIF(SUM(stake),0)     AS house_hold_pct,                                 -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「house_hold_pct」
             SUM(rebate)                               AS rebate_total,                                   -- 汇总表达式：取用 rebate（退水），产出「rebate_total」
             SUM(rebate) / NULLIF(SUM(validbet),0)     AS rebate_rate,                                    -- 汇总表达式：取用 validbet（有效投注（洗码量））、rebate（退水），产出「rebate_rate」
             COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()    AS order_share,                                    -- 计数表达式：全局窗口，用作占比之分母，产出「order_share」
             SUM(stake) / SUM(SUM(stake)) OVER ()      AS stake_share                                     -- 汇总表达式：全局窗口，用作占比之分母，产出「stake_share」
      FROM o                                                                                              -- 取数来源：取自本条自建的中间结果集 o
      GROUP BY product_code                                                                               -- 分组：按 product_code 汇总
    )
  SELECT q.*,
         -- 一·经济层
         ROUND(e.stake,4) AS stake, ROUND(e.valid,4) AS valid_bet,
         ROUND(-e.net,4) AS profit, e.n_bets, e.n_rounds,
         ROUND(e.net/NULLIF(e.stake,0),8) AS roi,
         ROUND(e.net_in/NULLIF(e.st_in,0),8) AS roi_freecomm,
         ROUND(e.net_out/NULLIF(e.st_out,0),8) AS roi_non_freecomm,
         ROUND((e.net-e.rebate)/NULLIF(e.stake,0),8) AS roi_ex_rebate,
         ROUND(e.net,4) AS roi_numerator, ROUND(e.stake,4) AS roi_denominator,
         CASE WHEN e.stake IS NULL THEN 'NULL_DENOM' WHEN e.stake<=0 THEN 'ZERO_DENOM'
              WHEN e.n_bets<30 THEN 'THIN_EXPOSURE' ELSE 'OK' END AS roi_denominator_status,
         ROUND(e.rebate,4) AS rebate_cost, ROUND(e.agent_cost,4)                           AS cost_complement_b,
       ROUND(e.agent_pct,4)                            AS pct_complement,
       ROUND(e.company_retain_pct,4)                   AS pct_top_bet23,
       'AG03-UNRESOLVED'                                     AS agent_formula_version,
      'ALL5_LEVELS_bet23_to_bet27'                    AS agent_level_scope,
      ROUND(e.agent_cost_lv1,4) AS agent_cost_lv1, ROUND(e.agent_cost_lv2,4) AS agent_cost_lv2,
      ROUND(e.agent_cost_lv3,4) AS agent_cost_lv3, ROUND(e.agent_cost_lv4,4) AS agent_cost_lv4,
      ROUND(e.agent_cost_lv5,4) AS agent_cost_lv5,
      ROUND(e.agent_pct_lv1,6) AS agent_pct_lv1, ROUND(e.agent_pct_lv2,6) AS agent_pct_lv2,
      ROUND(e.agent_pct_lv3,6) AS agent_pct_lv3, ROUND(e.agent_pct_lv4,6) AS agent_pct_lv4,
      ROUND(e.agent_pct_lv5,6) AS agent_pct_lv5,
      ROUND(e.retain_pct_lv1,6) AS retain_pct_lv1, ROUND(e.retain_pct_lv2,6) AS retain_pct_lv2,
      ROUND(e.retain_pct_lv3,6) AS retain_pct_lv3, ROUND(e.retain_pct_lv4,6) AS retain_pct_lv4,
      ROUND(e.retain_pct_lv5,6) AS retain_pct_lv5, ROUND(e.chain_depth_avg,4) AS chain_depth_avg,
      ROUND(e.agent_cost_chain_additive,4)            AS agent_cost_chain_additive,
      ROUND(e.agent_cost_chain_nested,4)              AS agent_cost_chain_nested,
      ROUND(-e.net-e.rebate-e.agent_cost_chain_additive,4) AS residual_chain_additive,
      ROUND(-e.net-e.rebate-e.agent_cost_chain_nested,4)   AS residual_chain_nested,
      'PENDING_AG03'                                  AS decision_status,
      'FALSE'                                         AS admit_to_risk_decision,
      'NOT_FOR_ENFORCEMENT'                           AS deliverable_class,
       ROUND(e.agent_cost_a_legacy,4)                  AS agent_cost_a_legacy,
       ROUND(e.agent_cost_valid_base_legacy,4)         AS agent_cost_valid_base_legacy,
         ROUND(-e.net-e.rebate,4)                        AS ngr,
       ROUND(-e.net-e.rebate-e.agent_cost,4)           AS residual_b,
       ROUND(-e.net-e.rebate-e.agent_cost_a_legacy,4)  AS residual_a,
         ROUND((-e.net-e.rebate)/NULLIF(e.stake,0),8)    AS ngr_rate,
       ROUND((-e.net-e.rebate-e.agent_cost)/NULLIF(e.stake,0),8)   AS residual_b_rate,
      -- 【HF9c · canonical accounting contract】
      --   以下 canonical 字段只增加明确 scope；不删除、不覆盖既有字段。
      --   formal_bet23_* 保持 HF9b 当前生产公式及其 NULL/0 语义；
      --   lv1~lv5 / additive / nested 则分别采用各自原始 e.* 成本字段，
      --   rate 一律从未舍入的 e.* 分子 / e.stake 计算，禁止由展示值反算。
      ROUND(e.agent_cost,4) AS agent_cost_bet23_formal_canonical,
      ROUND(-e.net-e.rebate-e.agent_cost,4) AS net_margin_bet23_formal_canonical,
      ROUND((-e.net-e.rebate-e.agent_cost)/NULLIF(e.stake,0),8) AS net_margin_bet23_formal_rate_canonical,
      ROUND(e.agent_cost_lv1,4) AS agent_cost_lv1_bet23_canonical,
      ROUND(e.agent_cost_lv2,4) AS agent_cost_lv2_bet24_canonical,
      ROUND(e.agent_cost_lv3,4) AS agent_cost_lv3_bet25_canonical,
      ROUND(e.agent_cost_lv4,4) AS agent_cost_lv4_bet26_canonical,
      ROUND(e.agent_cost_lv5,4) AS agent_cost_lv5_bet27_canonical,
      ROUND(-e.net-e.rebate-e.agent_cost_lv1,4) AS net_margin_lv1_bet23_canonical,
      ROUND((-e.net-e.rebate-e.agent_cost_lv1)/NULLIF(e.stake,0),8) AS net_margin_lv1_bet23_rate_canonical,
      ROUND(e.agent_cost_chain_additive,4) AS agent_cost_chain_additive_canonical,
      ROUND(e.agent_cost_chain_nested,4) AS agent_cost_chain_nested_canonical,
      ROUND(-e.net-e.rebate-e.agent_cost_chain_additive,4) AS net_margin_chain_additive_canonical,
      ROUND(-e.net-e.rebate-e.agent_cost_chain_nested,4) AS net_margin_chain_nested_canonical,
      ROUND((-e.net-e.rebate-e.agent_cost_chain_additive)/NULLIF(e.stake,0),8) AS net_margin_chain_additive_rate_canonical,
      ROUND((-e.net-e.rebate-e.agent_cost_chain_nested)/NULLIF(e.stake,0),8) AS net_margin_chain_nested_rate_canonical,
       ROUND((-e.net-e.rebate-e.agent_cost_a_legacy)/NULLIF(e.stake,0),8) AS residual_a_rate,
         -- 二·分布层
         ROUND(e.stake/NULLIF(e.n_bets,0),4) AS avg_stake_per_bet,
         ROUND(e.valid/NULLIF(e.n_rounds,0),4) AS avg_valid_bet_per_round,
         ROUND(-e.net/NULLIF(e.n_rounds,0),4) AS avg_profit_per_round,
         ROUND(-e.net/NULLIF(e.active_days,0),4) AS avg_profit_per_day,
         ROUND(-e.net/NULLIF(e.active_shoes,0),4) AS avg_profit_per_shoe,
         ROUND(e.stake/NULLIF(e.active_days,0),4) AS avg_stake_per_active_day,
         ROUND(e.n_rounds*1.0/NULLIF(e.active_days,0),4) AS avg_rounds_per_active_day,
         ROUND(e.st_in/NULLIF(e.nb_in,0),4) AS avg_stake_freecomm,
         ROUND(e.st_out/NULLIF(e.nb_out,0),4) AS avg_stake_non_freecomm,
         ROUND(e.p25,4) AS p25_stake, ROUND(e.p50,4) AS p50_stake, ROUND(e.p75,4) AS p75_stake,
         ROUND(e.p90,4) AS p90_stake, ROUND(e.p95,4) AS p95_stake, ROUND(e.p99,4) AS p99_stake,
         ROUND(e.p50_valid,4) AS p50_valid_bet, ROUND(e.p50_profit,4) AS p50_profit,
         ROUND(e.p95/NULLIF(e.p50,0),6) AS p95_over_p50,
         ROUND(e.p99/NULLIF(e.p50,0),6) AS p99_over_p50,
         ROUND((e.stake/NULLIF(e.n_bets,0))/NULLIF(e.p50,0),6) AS avg_over_p50,
         -- 三·关系层
         e.n_tables AS common_table_count, e.n_dealers AS common_dealer_count,
         e.n_ips AS common_ip_count, e.n_products AS common_product_count,
         ROUND(e.st_in/NULLIF(e.stake,0),8) AS share_freecomm,
         -- 四·rate 层
         ROUND(-e.net/NULLIF(e.stake,0),8) AS hold_rate,
         ROUND(-e.net_in/NULLIF(e.st_in,0),8) AS hold_rate_freecomm,
         ROUND(e.rebate/NULLIF(e.valid,0),8) AS rebate_rate_actual,
         ROUND(e.rbpct,6) AS rebate_pct_config,
         ROUND(e.valid/NULLIF(e.stake,0),6) AS turnover_multiple,
         ROUND(e.freecomm_rate,6) AS free_comm_rate,
         ROUND(e.net_in/NULLIF(e.st_in,0)-e.net_out/NULLIF(e.st_out,0),8) AS roi_delta_freecomm,
         -- 五·动态层
         e.first_seen_d AS first_seen, e.last_seen_d AS last_seen,
         e.active_days, e.active_shoes, e.active_sessions,
         DATEDIFF(e.last_seen_d, e.first_seen_d)+1 AS span_days,
         ROUND(e.active_days*1.0/NULLIF(DATEDIFF(e.last_seen_d,e.first_seen_d)+1,0),6) AS persistence,
         ROUND((e.st_in/NULLIF(e.nb_in,0))/NULLIF(e.st_out/NULLIF(e.nb_out,0),0),6) AS ramp_freecomm,
         ROUND((e.st_rec/NULLIF(e.nb_rec,0))/NULLIF(e.stake/NULLIF(e.n_bets,0),0),6) AS ramp_recent,
         ROUND((e.st_rec/NULLIF(e.stake,0))/0.30,6) AS stake_ramp,
         CASE WHEN CAST(q.`product_code` AS STRING) = '101' THEN 'IN_SCOPE_bet02_101' ELSE 'OUT_OF_SCOPE_bet02_ne_101' END AS template_scope,   -- 条件分支：HF9g·G-05 范围标注 —— 六层 x_agg 恒锁 bet02='101'，故非 101 之行其六层列为 NULL 属设计使然，非缺陷
         -- 六·决策层（HF9f · 详见档头【HF9f 变更说明】；本段两版逐字同一）
         NTILE(5) OVER (ORDER BY e.stake) AS vip_tier,                                                        -- 窗口取值：相对刻度 B 族，全体五等分；须连同下方血统五元组一并解读，禁作硬阈值判型
         PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)    AS economic_value,                    -- 窗口取值：HF9f·F-19 修正 —— HF9e 写作 -(-…) 双负号致方向颠倒（#075 实测 corr(economic_value, residual_b) = -1.0000）；今与 action_priority 排序键归一，值大即平台真净利高
         PERCENT_RANK() OVER (ORDER BY e.net/NULLIF(e.stake,0))         AS roi_pr_global,                     -- 窗口取值：HF9f·F-17 正名 —— 本列实为 ROI（玩家净回报率）之全体百分位，与「风险」无关；旧名 risk_value 见下一行
         PERCENT_RANK() OVER (ORDER BY e.net/NULLIF(e.stake,0))         AS risk_value,                        -- 窗口取值：兼容列，恒等于 roi_pr_global，仅为下游迁移窗保留；HF9g 起废弃，禁新引用
         PERCENT_RANK() OVER (ORDER BY e.stake)                         AS pr_stake,                          -- 窗口取值：兼容列，恒等于 pr_global，原名保留以免断链
         PERCENT_RANK() OVER (ORDER BY e.stake)                         AS pr_global,                         -- 窗口取值：HF9f·F-1 双轨之一 —— 全体口径百分位，参照总体即本件全部输出行
         CASE WHEN e.n_rounds >= 30                                                                           -- 条件分支：起始分支 —— 仅在合格子集内计算合格口径百分位
                THEN PERCENT_RANK() OVER (PARTITION BY CASE WHEN e.n_rounds >= 30 THEN 1 ELSE 0 END ORDER BY e.stake)  -- 分支取值：以合格与否分区，故本值即 n_rounds>=30 子集内之百分位
              ELSE NULL END                                             AS pr_qualified,                      -- 条件分支：收束上方分支 —— 不合格者留 NULL（NULL＝未测，非 0），产出「pr_qualified」
         'n_rounds>=30'                                                 AS pr_qualified_population,           -- 字面取值：血统 —— 合格子集之定义
         COUNT(*) OVER ()                                               AS pr_global_population_n,            -- 窗口取值：血统 —— 全体口径之参照总体规模，渲染时现算，禁写死
         SUM(CASE WHEN e.n_rounds >= 30 THEN 1 ELSE 0 END) OVER ()      AS pr_qualified_population_n,         -- 窗口取值：血统 —— 合格子集之参照总体规模，现算，禁写死
         'PERCENT_RANK_OVER_ORDER_BY_e_stake'                           AS pr_calculation_method,             -- 字面取值：血统 —— 算法标识
         'HF9f'                                                         AS pr_calculation_version,            -- 字面取值：血统 —— 算法版本
         CASE WHEN e.n_rounds IS NULL OR e.n_rounds < 30 THEN 'THIN_ROUNDS' ELSE 'OK' END AS evidence_flag,   -- 条件分支：HF9f·F-2a 证据旗标 —— THIN_ROUNDS 者禁入执行队列，仅入观察队列
         CASE WHEN e.n_rounds IS NULL       THEN NULL                                                         -- 条件分支：起始分支 —— 未测者留 NULL（自家铁律：NULL ≠ 0）
              WHEN e.n_rounds >= 31483      THEN 'L1_POWERED'                                                 -- 分支判定：MDE 反解第一档
              WHEN e.n_rounds >= 15409      THEN 'L2_CI_1P5'                                                  -- 分支判定：MDE 反解第二档
              WHEN e.n_rounds >=  8668      THEN 'L3_CI_2P0'                                                  -- 分支判定：MDE 反解第三档
              WHEN e.n_rounds >=  3852      THEN 'L4_CI_3P0'                                                  -- 分支判定：MDE 反解第四档
              ELSE 'L5_INSUFFICIENT' END                                AS evidence_rate,                     -- 条件分支：收束上方 —— HF9f·F-3 证据分档，承 HF9e 前议之 MDE 反解五档，须于 F-4 敏感性实验后复核
         ROUND(1.96 * 0.95 / SQRT(NULLIF(CAST(e.n_rounds AS DOUBLE),0)),8) AS hold_ci_halfwidth_approx,       -- 比率表达式：HF9f·F-3 逐行现算之 95% 半宽近似；常数 0.95 为登记值，本轮 #075 实测每局 ROI 隐含 σ 于最薄层为 0.9249，二者差异待 F-4 裁定
         CASE WHEN e.stake IS NULL OR e.stake<=0 OR e.n_bets<30 OR e.n_rounds IS NULL OR e.n_rounds<30 THEN 'Z 证据不足 · 不动作'  -- 条件分支：HF9f·F-2 双条件取严 —— HF9e 仅卡 e.n_bets<30，致 n_bets>=30 而 n_rounds<30 者绕过 Z（#075 实测 18,537 名，其中 8,145 名已入 A/D 待裁）；今两条件并列取严
              WHEN PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)<=0.10                          -- 分支判定：平台真净利之最低十分位
                THEN 'A 净亏最大十分位 · 优先复核'                                                             -- 分支取值：HF9f·F-20 正名 —— 本档 Σresidual_b 于 #075 实测 = -100,236,896，系平台净亏最大群，旧名「残值最低十分位 · 待裁」名实不符
              WHEN PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)>=0.80                          -- 分支判定：平台真净利之最高二十分位
                THEN 'D 净利最高二十分位 · 优先留存'                                                           -- 分支取值：HF9f·F-20 正名 —— 本档 Σresidual_b 于 #075 实测 = +281,733,190，系核心利润源；与 A 档方向相反，旧版同标「待裁」属名实不符
              ELSE 'E 常规' END                                          AS action_priority                   -- 条件分支：收束上方判词，产出「action_priority」
  FROM q
  LEFT JOIN x_agg e ON CAST(e.x_key AS STRING) = CAST(q.`product_code` AS STRING)
) w;
