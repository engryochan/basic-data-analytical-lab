-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ HF9f · 落盘前回归闸 · 自足版（#075 S01_player_score）· 一次扫描出全部判据 ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 与《HF9f_回归闸_schema驱动.sql》之别：该档留占位须人工粘贴，本档已内嵌 #075 完整查询，可直接执行。
-- 算力：等同跑一次 #075 出数（一次全扫），不额外重算；只回 1 行。
-- 来源：a168_SQL总包_v12_0_0_HF9f_原版审计版_六层商业版.sql 之 #075 区块（行 25839 ~ 26229）逐字内嵌，
--       仅去除最外层 SELECT w.* / ROW_NUMBER() / ORDER BY 三段（该三段不影响任何聚合值）。
-- 判据：① 合格子集人数 ② 台账锚 ③ Z 档反演 ④ 血统自洽 ⑤ 新列非空 —— 五项全 PASS 方准落盘。
-- 【2026-08-28 实跑回执 · #075 · PASS】耗时 17.011 秒，一行结果，九项预测逐位命中：
--   n_total 723442 · n_qualified 161156 · sum_stake_q 13149241210.83 · n_z 562286 · n_a 34990 ·
--   n_d 69269 · n_thin 562286 · pr_pop_global 723442 · pr_pop_qual 161156 · bad_pr_qual 0 · verdict PASS
--   corr_ev_resid +0.110068（HF9e 同式实测 −0.110085，符号已由负转正 ⇒ F-19 生效）
SELECT                                                                                              -- 取列：起始取列子句
  COUNT(*)                                                                        AS n_total,       -- 计数表达式：全件行数（期望 723,442）
  SUM(CASE WHEN w.n_rounds >= 30 THEN 1 ELSE 0 END)                               AS n_qualified,   -- 聚合取值：合格子集人数（期望 161,156 ＝ HF9d 行数）
  ROUND(SUM(CASE WHEN w.n_rounds >= 30 THEN w.stake ELSE 0 END), 2)                AS sum_stake_q,   -- 聚合取值：合格子集本金合计（期望 13,149,241,210.83）
  SUM(CASE WHEN w.action_priority LIKE 'Z%' THEN 1 ELSE 0 END)                    AS n_z,           -- 聚合取值：Z 档人数（期望 562,286 ＝ HF9e 543,749 ＋ 盲区 18,537）
  SUM(CASE WHEN w.action_priority LIKE 'A%' THEN 1 ELSE 0 END)                    AS n_a,           -- 聚合取值：A 档人数（期望 34,990 ＝ HF9e 37,728 − 盲区 A 2,738）
  SUM(CASE WHEN w.action_priority LIKE 'D%' THEN 1 ELSE 0 END)                    AS n_d,           -- 聚合取值：D 档人数（期望 69,269 ＝ HF9e 74,676 − 盲区 D 5,407）
  SUM(CASE WHEN w.evidence_flag = 'THIN_ROUNDS' THEN 1 ELSE 0 END)                AS n_thin,        -- 聚合取值：薄证据人数（期望 562,286，与 n_z 同）
  MAX(w.pr_global_population_n)                                                   AS pr_pop_global, -- 聚合取值：血统 —— 全体参照总体规模（须等于 n_total）
  MAX(w.pr_qualified_population_n)                                                AS pr_pop_qual,   -- 聚合取值：血统 —— 合格参照总体规模（须等于 n_qualified）
  SUM(CASE WHEN w.pr_qualified IS NULL AND w.n_rounds >= 30 THEN 1 ELSE 0 END)    AS bad_pr_qual,   -- 聚合取值：合格者却无合格百分位之行数（须为 0）
  ROUND(MIN(CASE WHEN w.n_rounds >= 30 THEN w.economic_value END), 6)              AS ev_min_q,      -- 聚合取值：F-19 方向校验用
  ROUND(CORR(w.economic_value, w.residual_b), 6)                                   AS corr_ev_resid, -- 相关表达式：F-19 方向校验 —— ★ 注记斧正 R1：CORR() 为皮尔逊而非斯皮尔曼。economic_value 系百分位秩，residual_b 系厚尾原值，两者皮尔逊相关不趋近 ±1。HF9e 原档实测皮尔逊 = −0.110085、斯皮尔曼 = −1.000000；HF9f 期望值为其镜像 ＝ ＋0.1101（实测回报 +0.110068，差 1.7e-5，系 PERCENT_RANK 并列值反序所致）。判据取【符号由负转正】，非取数值趋近 1。本栏未纳入 verdict 之 PASS 条件，仅供人工判读。
  CASE WHEN SUM(CASE WHEN w.n_rounds >= 30 THEN 1 ELSE 0 END) = 161156             -- 条件分支：起始分支 —— 判据①
        AND ROUND(SUM(CASE WHEN w.n_rounds >= 30 THEN w.stake ELSE 0 END), 2) = 13149241210.83      -- 并列条件：判据②
        AND SUM(CASE WHEN w.action_priority LIKE 'Z%' THEN 1 ELSE 0 END) = 562286                    -- 并列条件：判据③
        AND MAX(w.pr_global_population_n) = COUNT(*)                                                 -- 并列条件：判据④之一 血统自洽
        AND MAX(w.pr_qualified_population_n) = SUM(CASE WHEN w.n_rounds >= 30 THEN 1 ELSE 0 END)     -- 并列条件：判据④之二 血统自洽
        AND SUM(CASE WHEN w.pr_qualified IS NULL AND w.n_rounds >= 30 THEN 1 ELSE 0 END) = 0         -- 并列条件：判据⑤ 新列非空
       THEN 'PASS' ELSE 'FAIL' END                                                AS verdict        -- 条件分支：收束判词，产出「verdict」
FROM (
  WITH
    x_ranked AS (
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet09, b.bet11, b.bet13,
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
    SELECT b.bet05 AS x_member, b.eid AS x_dealer, b.bet39 AS x_table,
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
    SELECT s.x_member                                                        AS x_key,
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
           SUM(CASE WHEN s.x_rec = 1 THEN s.x_stake ELSE 0 END) AS st_in,
           SUM(CASE WHEN s.x_rec = 1 THEN 1 ELSE 0 END)         AS nb_in,
           SUM(CASE WHEN s.x_rec = 1 THEN s.x_net ELSE 0 END)   AS net_in,
           SUM(CASE WHEN NOT (s.x_rec = 1) THEN s.x_stake ELSE 0 END) AS st_out,
           SUM(CASE WHEN NOT (s.x_rec = 1) THEN 1 ELSE 0 END)         AS nb_out,
           SUM(CASE WHEN NOT (s.x_rec = 1) THEN s.x_net ELSE 0 END)   AS net_out,
           SUM(CASE WHEN s.x_rec=1 THEN s.x_stake ELSE 0 END) AS st_rec,
           SUM(CASE WHEN s.x_rec=1 THEN 1 ELSE 0 END)         AS nb_rec
    FROM x_mk s
    WHERE s.is_clean = 1
      AND s.x_member IS NOT NULL AND TRIM(CAST(s.x_member AS STRING)) <> ''
    GROUP BY s.x_member
  ),
    q AS (
      WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
        SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
        FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
        SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
               b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
               b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
               b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
               b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（重對）、bet39（桌号）、eid（荷官工号）
               b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
               ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
                 PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
                 ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
        FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
        WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
      AND b.sync_time <= '2026-08-27 09:00:00'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      vd AS (                  -- 有效注单：非测试线、非重对、一般注单
        SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
        FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
        LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
        LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
        LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
        LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
        LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
        WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（重對）
          AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
          AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
          AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
          AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
        SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
               v.bet18 AS lv1, v.bet19 AS lv2, v.bet20 AS lv3, v.bet21 AS lv4, v.bet22 AS lv5, CONCAT_WS('|', COALESCE(CAST(NULLIF(CAST(NULLIF(TRIM(v.bet18),'') AS BIGINT),0) AS STRING),'-'), COALESCE(CAST(NULLIF(CAST(NULLIF(TRIM(v.bet19),'') AS BIGINT),0) AS STRING),'-'), COALESCE(CAST(NULLIF(CAST(NULLIF(TRIM(v.bet20),'') AS BIGINT),0) AS STRING),'-'), COALESCE(CAST(NULLIF(CAST(NULLIF(TRIM(v.bet21),'') AS BIGINT),0) AS STRING),'-'), COALESCE(CAST(NULLIF(CAST(NULLIF(TRIM(v.bet22),'') AS BIGINT),0) AS STRING),'-')) AS chain_key, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
               CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
               v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
               CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
               CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
               CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
               (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
               CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
               CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                 / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
        FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      lab AS (SELECT bet05 AS member_id,                                                                  -- 取值表达式：取用 bet05（会员号）、member_id（会员号），产出「member_id」
                     SUM(CASE WHEN risk='1' THEN 1 ELSE 0 END) AS n_risk_days,                            -- 汇总表达式：产出「n_risk_days」
                     SUM(CASE WHEN orders='1' THEN 1 ELSE 0 END) AS n_order_days                          -- 汇总表达式：产出「n_order_days」
              FROM ods_mariadb_2b.ods_a168_dailyreport_member GROUP BY bet05),                            -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
      /* ── 扩编维度① 投注产品结构熵 ─────────────────────────────────────
         香农熵：把该会员的投注额按 23 种投注产品拆开，看分散还是集中。
         熵高 = 庄闲和边注都押一点，是娱乐型客人的常态；
         熵低 = 火力集中在少数高赔率边注，是技术型画像的特征之一。
         赏罚方向为「赏」——熵高的客人对平台更安全。 */
      psplit AS (                                                                                         -- 公共表表达式：开启中间结果集 psplit，其后各行为其定义体（交付件 S01_player_score.csv）
        SELECT member_id, bet_side,                                                                       -- 取列：起始取列子句，本行先列 member_id, bet_side，涉 member_id（会员号）
               SUM(stake) AS s_side,                                                                      -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「s_side」
               SUM(SUM(stake)) OVER (PARTITION BY member_id) AS s_all                                     -- 汇总表达式：取用 stake（下注额（经汇率归一化））、member_id（会员号），产出「s_all」
        FROM bs GROUP BY member_id, bet_side                                                              -- 取数来源：取自本条自建的中间结果集 bs
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      ent AS (                                                                                            -- 公共表表达式：开启中间结果集 ent，其后各行为其定义体（交付件 S01_player_score.csv）
        SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
               -SUM((s_side/s_all) * LN(s_side/s_all)) AS 投注产品结构熵                                         -- 加减计算：香农熵定义式之前置负号，与 GGR 无涉，产出「投注产品结构熵」
        FROM psplit WHERE s_all > 0 AND s_side > 0                                                        -- 取数来源：取自本条自建的中间结果集 psplit
        GROUP BY member_id                                                                                -- 分组：按 member_id 汇总
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      /* ── 扩编维度② 索提诺稳定性（会员视角的下行风险调整收益）──────────
         先把注单压成「会员×日」的日 ROI，再算 日ROI均值 ÷ 下行标准差。
         只统计低于 0 那一侧的波动——赢钱时的波动不是风险。
         赏罚方向为「罚」：赢得稳的客人正是 T2 技术型风险用户，
         赢得多但忽输忽赢的反而是正常娱乐客。**不要把方向搞反。** */
      dly AS (                                                                                            -- 公共表表达式：开启中间结果集 dly，其后各行为其定义体（交付件 S01_player_score.csv）
        SELECT member_id, bet_date,                                                                       -- 取列：起始取列子句，本行先列 member_id, bet_date，涉 member_id（会员号）、bet_date（营业日）
               SUM(game_pnl) AS pnl_d, SUM(stake) AS stake_d                                              -- 汇总表达式：取用 stake（下注额（经汇率归一化））、game_pnl（游戏净输赢），产出「stake_d」
        FROM bs GROUP BY member_id, bet_date                                                              -- 取数来源：取自本条自建的中间结果集 bs
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      srt AS (                                                                                            -- 公共表表达式：开启中间结果集 srt，其后各行为其定义体（交付件 S01_player_score.csv）
        SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
               AVG(pnl_d / NULLIF(stake_d,0))                                  AS mu_roi_d,               -- 求均值表达式：产出「mu_roi_d」
               SQRT(AVG(POW(LEAST(pnl_d / NULLIF(stake_d,0), 0), 2)))          AS dd_roi_d,               -- 取值表达式：求均值，产出「dd_roi_d」
               AVG(pnl_d / NULLIF(stake_d,0))                                                             -- 求均值表达式：承接上一子句，构成完整语句，属 交付件 S01_player_score.csv 之取数
                 / NULLIF(SQRT(AVG(POW(LEAST(pnl_d / NULLIF(stake_d,0), 0), 2))), 0)                      -- 除法或乘法计算：求均值
                                                                                AS 索提诺稳定性                 -- 取值表达式：取用索提诺稳定性（玩家雷达罚侧维），产出「索提诺稳定性」
        FROM dly GROUP BY member_id                                                                       -- 取数来源：取自本条自建的中间结果集 dly
      ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      /* ── 扩编维度③ 生命周期阶段 ──────────────────────────────────────
         首末注单跨度 × 近期活跃衰减，取值越大代表越处于成熟稳定期。
         算法：活跃跨度天数 × (1 − 距窗口右端的静默天数 / 窗口总天数)，
         新客跨度短、流失前兆者静默久，两端都会被压低。窗口 139 天为字面量。
         赏罚方向为「赏」。 */
      lc AS (                                                                                             -- 公共表表达式：开启中间结果集 lc，其后各行为其定义体（交付件 S01_player_score.csv）
        SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
               DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1 AS span_days,                                   -- 取值表达式：取最大值、取最小值，取用 bet_date（营业日），产出「span_days」
               DATEDIFF(DATE '2026-08-06', MAX(bet_date)) AS silent_days,                                 -- 取值表达式：取最大值，取用 bet_date（营业日），产出「silent_days」
               (DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1)                                               -- 续行：取最大值、取最小值，取用 bet_date（营业日）
                 * (1 - DATEDIFF(DATE '2026-08-06', MAX(bet_date)) / 139.0) AS 生命周期阶段                     -- 除法或乘法计算：取最大值，取用 bet_date（营业日）、生命周期阶段（玩家雷达赏侧维），产出「生命周期阶段」
        FROM bs GROUP BY member_id                                                                        -- 取数来源：取自本条自建的中间结果集 bs
      )                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
      SELECT b.member_id,                                                                                 -- 取列：起始取列子句，本行先列 b.member_id，涉 member_id（会员号）
        SUM(b.valid_bet) AS 流水贡献,                                                                         -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、流水贡献（玩家雷达赏侧维），产出「流水贡献」
        -SUM(b.game_pnl) AS 游戏输赢贡献,          -- 会员输=平台赢，取负号
        COUNT(DISTINCT b.bet_date) AS 活跃稳定,                                                               -- 计数表达式：统计去重个数，产出「活跃稳定」
        SUM(b.rebate) AS 退水支出,                                                                            -- 汇总表达式：取用 rebate（退水）、退水支出（退水成本），产出「退水支出」
        COUNT(DISTINCT b.bet_ip) AS n_ip,                                                                 -- 计数表达式：统计去重个数，产出「n_ip」
        COUNT(DISTINCT b.lv3) AS n_chain,                                                                 -- 计数表达式：统计去重个数，产出「n_chain」
        MAX(b.lv1) AS lv1_id, MAX(b.lv2) AS lv2_id, MAX(b.lv3) AS lv3_id,
        MAX(b.lv4) AS lv4_id, MAX(b.lv5) AS lv5_id, MAX(b.chain_key) AS chain_key,
        COUNT(DISTINCT b.chain_key) AS n_chain_key,
        CASE WHEN COUNT(DISTINCT b.chain_key)>1 THEN 1 ELSE 0 END AS f_upline_changed,
        COALESCE(MAX(l.n_risk_days),0)+COALESCE(MAX(l.n_order_days),0) AS 人工标记史,                          -- 取值表达式：取最大值，取用人工标记史（玩家雷达罚侧维），产出「人工标记史」
        -- ★ 扩编三列：报告的玩家雷达按列名取用，列名一字不可改
        MAX(e.投注产品结构熵)  AS 投注产品结构熵,                                                                       -- 取最大值表达式：取用投注产品结构熵（玩家雷达赏侧维），产出「投注产品结构熵」
        MAX(sr.索提诺稳定性)   AS 索提诺稳定性,                                                                       -- 取最大值表达式：取用索提诺稳定性（玩家雷达罚侧维），产出「索提诺稳定性」
        MAX(lcx.生命周期阶段)  AS 生命周期阶段                                                                        -- 取最大值表达式：取用生命周期阶段（玩家雷达赏侧维），产出「生命周期阶段」
      FROM bs b                                                                                           -- 取数来源：取自本条自建的中间结果集 bs
      LEFT JOIN lab l   ON l.member_id  = b.member_id                                                     -- 左连接：取自本条自建的中间结果集 lab，连接键为 member_id（会员号）
      LEFT JOIN ent e   ON e.member_id  = b.member_id                                                     -- 左连接：取自本条自建的中间结果集 ent，连接键为 member_id（会员号）
      LEFT JOIN srt sr  ON sr.member_id = b.member_id                                                     -- 左连接：取自本条自建的中间结果集 srt，连接键为 member_id（会员号）
      LEFT JOIN lc  lcx ON lcx.member_id = b.member_id                                                    -- 左连接：取自本条自建的中间结果集 lc，连接键为 member_id（会员号）
      GROUP BY b.member_id                                                                                -- 分组：按 b.member_id 汇总
--    ★★ HF9e · 宇宙门解除（Ryo Eng 裁定 2026-08-27）★★
--      原句：HAVING COUNT(DISTINCT b.round_key) >= 30            ← 本行已删除
--      语义查证：round_key = CONCAT_WS('|', bet03, bet04, bet39) = 靴号|局号|桌号，即一靴中的一手牌。
--        v1.5 PK1 已 PROVEN：不跨日、不跨桌、不跨靴，max_days_per_rk = 1，全宇宙 6,048,562 个唯一局键。
--        故原门槛之义为：该会员在 139 天窗口内【下注过的不同局】至少 30 局（非注单数，非 100 注）。
--        实测佐证：解除前 CSV 的 n_rounds 最小值 = 30、n_bets 最小值 = 30，且 n_bets >= n_rounds 恒成立。
--      解除理由（三条，皆实测）：
--        ① 静默丢弃：挡掉 562,286 名会员（77.72%）· 4,456,604 笔（3.573%）· 约 4.87 亿注额，
--           与铁律「标记而非丢弃」直接冲突；#078 对测试线即用标记不丢弃，本件应同法。
--        ② 死分支：门槛使 n_bets 恒 >= 30，决策层 'Z 证据不足 · 不动作' 永不触发（CSV 实测印证）。
--           原设计意图本就是【留下并标 Z】，是 HAVING 抢先删掉，二者重复且冲突。
--           ★ 删除本行后，Z 分支【自动复活】，无须改动决策层一字。
--        ③ 和型指标无抽样误差：stake / profit / n_bets 是精确计数，被挡者的钱一分不该少算。
--      解除后须知：本件行数由 161,156 → 723,442（4.49×），分批由 2 批 → 8 批；
--        八项台账锚全部作废重建；率型指标（roi / hold_rate）对低局数会员为噪声，
--        证据分层列（evidence_rate / hold_ci_halfwidth_approx / pr_qualified）待批准后于下一版补入。
    )
  SELECT q.*,
         -- 一·经济层
         ROUND(e.stake,4) AS stake, ROUND(e.valid,4) AS valid_bet,
         ROUND(-e.net,4) AS profit, e.n_bets, e.n_rounds,
         ROUND(e.net/NULLIF(e.stake,0),8) AS roi,
         ROUND(e.net_in/NULLIF(e.st_in,0),8) AS roi_recent,
         ROUND(e.net_out/NULLIF(e.st_out,0),8) AS roi_non_recent,
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
         ROUND(e.st_in/NULLIF(e.nb_in,0),4) AS avg_stake_recent,
         ROUND(e.st_out/NULLIF(e.nb_out,0),4) AS avg_stake_non_recent,
         ROUND(e.p25,4) AS p25_stake, ROUND(e.p50,4) AS p50_stake, ROUND(e.p75,4) AS p75_stake,
         ROUND(e.p90,4) AS p90_stake, ROUND(e.p95,4) AS p95_stake, ROUND(e.p99,4) AS p99_stake,
         ROUND(e.p50_valid,4) AS p50_valid_bet, ROUND(e.p50_profit,4) AS p50_profit,
         ROUND(e.p95/NULLIF(e.p50,0),6) AS p95_over_p50,
         ROUND(e.p99/NULLIF(e.p50,0),6) AS p99_over_p50,
         ROUND((e.stake/NULLIF(e.n_bets,0))/NULLIF(e.p50,0),6) AS avg_over_p50,
         -- 三·关系层
         e.n_tables AS common_table_count, e.n_dealers AS common_dealer_count,
         e.n_ips AS common_ip_count, e.n_products AS common_product_count,
         ROUND(e.st_in/NULLIF(e.stake,0),8) AS share_recent,
         -- 四·rate 层
         ROUND(-e.net/NULLIF(e.stake,0),8) AS hold_rate,
         ROUND(-e.net_in/NULLIF(e.st_in,0),8) AS hold_rate_recent,
         ROUND(e.rebate/NULLIF(e.valid,0),8) AS rebate_rate_actual,
         ROUND(e.rbpct,6) AS rebate_pct_config,
         ROUND(e.valid/NULLIF(e.stake,0),6) AS turnover_multiple,
         ROUND(e.freecomm_rate,6) AS free_comm_rate,
         ROUND(e.net_in/NULLIF(e.st_in,0)-e.net_out/NULLIF(e.st_out,0),8) AS roi_delta_recent,
         -- 五·动态层
         e.first_seen_d AS first_seen, e.last_seen_d AS last_seen,
         e.active_days, e.active_shoes, e.active_sessions,
         DATEDIFF(e.last_seen_d, e.first_seen_d)+1 AS span_days,
         ROUND(e.active_days*1.0/NULLIF(DATEDIFF(e.last_seen_d,e.first_seen_d)+1,0),6) AS persistence,
         ROUND((e.st_in/NULLIF(e.nb_in,0))/NULLIF(e.st_out/NULLIF(e.nb_out,0),0),6) AS ramp_recent_vs_prior,
         ROUND((e.st_rec/NULLIF(e.nb_rec,0))/NULLIF(e.stake/NULLIF(e.n_bets,0),0),6) AS ramp_recent_vs_all,
         ROUND((e.st_rec/NULLIF(e.stake,0))/0.30,6) AS stake_ramp,
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
  LEFT JOIN x_agg e ON CAST(e.x_key AS STRING) = CAST(q.`member_id` AS STRING)
) w;
