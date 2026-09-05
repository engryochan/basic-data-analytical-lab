-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- R03b ＃071 排序键裁剪 · 验收探针 A · 5 键裁剪（结构不变）· 第 100 批   v1.0.0   2026-09-05
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【立意】在【输出逐字节不变】未经在库实证之前，不得动总包一字。本探针即为取证之用。
-- 【只读】SELECT only —— 无 CREATE／INSERT／UPDATE／DELETE／DROP，不改库中任何物。
-- 【同源】其 y 子查询系【自 a168_SQL总包_v12_0_0_HF9g-P5D_分批作业版1万_六层商业版_OPT.sql
--         ＃071 逐字复制】，一字未改；故本探针与生产查询同口径同血统。
-- 【本探针所改之处】仅一行 —— audit_rn 之 ORDER BY 由 26 键裁为 5 键。其余逐字不动。
--   原 26 键：ROW_NUMBER() OVER (ORDER BY y.`residual_b` ASC, y.`roi` DESC, y.`bet_date`, y.`uid`, y.`dealer_id`, y.`is_sentinel_deale …
--   今  5 键：ORDER BY y.`residual_b` ASC, y.`roi` DESC, y.`bet_date`, y.`uid`, y.`dealer_id`
-- 【验收法】本探针输出 audit_rn 990,001~1,000,000（即第 100 批）。
--   导出后与现档 数据库 HF9g-P5D_OPT/R03b_player_dealer_daily (一次一万行)/
--   R03b_player_dealer_daily_b100.csv（10,000 行 · 151 栏 · 15,614,711 B）
--   ⛔ 逐字节比对。**完全一致方可放行**，有一字之差即弃此案。
-- ══════════════════════════════════════════════════════════════════════════════════════════════

SELECT z.*,
       CAST(FLOOR((z.audit_rn - 1) / 10000) + 1 AS INT)          AS batch_id,
       'A168_HF9F_20260827_0900' AS run_id,
       '2026-08-27 09:00:00' AS snapshot_sync_time
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`residual_b` ASC, y.`roi` DESC, y.`bet_date`, y.`uid`, y.`dealer_id`) AS audit_rn
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
        WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§R03b）
          SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
                 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
                 b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet17, b.bet38, b.bet39，涉 bet13（下注金额）、bet14（派彩金额）、bet17（会员净输赢）
                 b.category, b.eid,                                                                         -- 续行：接续上一取列子句，续列 b.category, b.eid，涉 eid（荷官工号）
                 ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
                   PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
                   ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
          FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
          WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
            AND b.bet02 = '101'
      AND b.sync_time <= '2026-08-27 09:00:00' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
        ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
        base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R03b）
          SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,                                -- 取列：起始取列子句，本行先取「bet_date」，涉 bet05（会员号）、eid（荷官工号）、dt（营业日）
                 CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,               -- 取值表达式：哨兵标记——★ 由删除改为标注（事实层不删，分析层才筛）
                 r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
                 CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
                 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
                 CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
                 CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
                 CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw                                 -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
          FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
          WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'                                                     -- 过滤条件：限定 r.rn等于 1、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（重對）
            AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
            AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
            AND NULLIF(TRIM(r.eid),'') IS NOT NULL                                                          -- 并列条件：限定该值非空，涉 eid（荷官工号）
            AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'                                                   -- 并列条件：限定不匹配所给模式，涉 bet09（玩法）
        ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
        ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§R03b）
          SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, bet_side, round_key,                   -- 取列：起始取列子句，透传哨兵标记，涉 bet_date（营业日）、round_key（局键）
                 stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
                 (payout_raw - stake_raw) / fx AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
                 net_raw / fx                  AS net_pnl                                                   -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
          FROM base                                                                                         -- 取数来源：取自本条自建的中间结果集 base
        ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
        side_base AS (                                                                                      -- 公共表表达式：开启中间结果集 side_base，其后各行为其定义体（§R03b）
          SELECT bet_side,                                                                                  -- 取列：起始取列子句，本行先列 bet_side
                 SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
                   / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base                    -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「p_base」
          FROM ord WHERE is_sentinel_dealer = 0                                                             -- 取数来源：取自本条自建的中间结果集 ord——★ 基准只由**真实牌桌**估计
          GROUP BY bet_side                                                                                 -- 分组：按投注产品汇总
        ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
        ordb AS (             -- ★ 2026-08-11 增：注单层挂上各自产品的基准，供下方按注额加权
          SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet_date, o.round_key, o.bet_side,       -- 取列：起始取列子句，透传五键与哨兵标记
                 o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side                                         -- 续行：并取三项金额与该注自身产品的基准胜率，产出「p_side」
          FROM      ord o                                                                                   -- 取数来源：取自本条自建的中间结果集 ord
          LEFT JOIN side_base s ON s.bet_side = o.bet_side                                                  -- 左连接：取自本条自建的中间结果集 side_base，基准未定义者留空——不以 0.5 顶替
        ),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
        pr AS (   -- 局级去重：同一物理局折成一局，避免 Z-score 被 sqrt(k) 放大
          SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, round_key,                             -- 取列：起始取列子句，透传哨兵标记
                 SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,                   -- 汇总表达式：取用 stake（下注额（经汇率归一化））、net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「net_pnl」
                 COUNT(*) AS n_orders_in_round,                                                             -- 计数表达式：产出「n_orders_in_round」
                 SUM(stake * p_side)                                                                        -- 汇总表达式：注额加权基准起算——★ 斧正，旧法 MAX(bet_side) 取字母序最大而非主注
                   / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)                     -- 除法或乘法计算：除以有基准之注的注额合计
                               AS p_base_round_w,                                                             -- 续行：产出「p_base_round_w」——该局的**注额加权**基准；全注皆无基准则留空
                 AVG(p_side)   AS p_base_round_unw,                                                         -- 汇总表达式：同局各注基准的**等权**均值——★ 2026-08-11 增，供两种 estimand 对照
                 MAX(bet_side) AS main_side                                                                 -- 取最大值表达式：字母序最大注项，**仅备查、不参与计算**
          FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet_date, round_key                  -- 取数来源：取自本条自建的中间结果集 ordb（已挂基准）
        )                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03b）
        SELECT p.bet_date, p.member_id AS uid, p.dealer_id, p.is_sentinel_dealer,                           -- 取列：起始取列子句，本行先取「uid」与哨兵标记
               SUM(p.stake)                                        AS stake_amount,                         -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_amount」
               SUM(p.game_pnl)                                     AS profit_amount,                        -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「profit_amount」
               SUM(p.net_pnl)                                      AS net_pnl,                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
               SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
                 / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,                 -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「win_rate」
               SUM(p.n_orders_in_round)                            AS n_related_orders,                     -- 汇总表达式：产出「n_related_orders」
               COUNT(*)                                            AS n_rounds_eff,                         -- 计数表达式：取用 n_rounds_eff（有效局数），产出「n_rounds_eff」
               AVG(p.p_base_round_w)                                 AS p_base_mix_w,                           -- 汇总表达式：对各局的**注额加权**基准取均值——判定所用者
               AVG(p.p_base_round_unw)                             AS p_base_mix_unw,                       -- 汇总表达式：**等权**口径之对照量——★ 2026-08-11 与 §R03 对齐，二者背离即示资金集中于某产品
               (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 续行：汇总，取用 game_pnl（游戏净输赢）
                - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))           -- 加减计算：观测赢局数减期望赢局数 ＝ 超额，与 GGR 无涉
                 / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢）
                               * AVG(p.p_base_round_w)                                                -- 除法或乘法计算：求均值
                               * (1 - AVG(p.p_base_round_w))), 0)        AS z_score_w,                      -- 除法或乘法计算：产出「z_score_w」——**加权候选臂**
               (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 取值表达式：★ **对照臂**之分子——同式改用等权基准（Dixon & Coles 1996：先立无权重基线）
                - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_unw))               -- 续行：期望胜局按等权基准算
                 / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：除以伯努利标准差
                               * AVG(p.p_base_round_unw)                                                    -- 续行：等权基准
                               * (1 - AVG(p.p_base_round_unw))), 0)    AS z_score_unw,                      -- 续行：产出「z_score_unw」——加权之优势须由本臂对照证成
               (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 取值表达式：兼容别名之分子——与 z_score_w 逐字同式
                - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))                 -- 续行：期望胜局按加权基准算
                 / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：除以伯努利标准差
                               * AVG(p.p_base_round_w)                                                      -- 续行：加权基准
                               * (1 - AVG(p.p_base_round_w))), 0)        AS z_score,                        -- 续行：产出「z_score」——★ **兼容别名，恒等于 z_score_w**；既有报告与数据契约沿用此名
               AVG(p.p_base_round_w) - AVG(p.p_base_round_unw)          AS delta_p,                         -- 加减计算：比较层——两臂基准之差，产出「delta_p」
               CASE WHEN p.is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'                                    -- 取值表达式：统计资格判定起算——事实层不删，此处只标注资格
                    WHEN AVG(p.p_base_round_w) IS NULL THEN 'NO_BASE_RATE'                                    -- 续行：基准未定义
                    WHEN SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_DECISIVE_ROUND'      -- 续行：全为退还局，无胜负可判
                    ELSE 'ELIGIBLE' END                                 AS eligibility_status,               -- 续行：产出「eligibility_status」——日粒度不设局数下限，下限由分析层施加
               'R03b_20260811_FULL_v1'                              AS comparison_id,                       -- 取值表达式：比较批次号——与 §R03 同规格，两臂须同批次方可比
               'L1_ELIGIBILITY'                           AS filter_stage,                                  -- 取值表达式：过滤所处之层——★ L0 事实层不删行，此处只标注其在 L1 资格层的去留
               'v2026-08-11'                              AS filter_rule_version,                            -- 取值表达式：资格规则版本号——改规则须改版本号并记入变更日志，免「同名不同义」
               '2026-03-21..2026-08-06'                             AS cmp_time_window,                     -- 取值表达式：时间窗，产出「cmp_time_window」
               'baccarat_bet02_101_all_pairs_incl_sentinel'         AS cmp_population,                      -- 取值表达式：总体定义（含哨兵之全量对）
               'round_win = game_pnl > 0 (decisive only)'           AS cmp_label,                           -- 取值表达式：标签定义
               'COMPATIBILITY_ONLY_NOT_PRODUCTION'                  AS z_score_alias_status                 -- 取值表达式：★ 兼容别名状态——禁止作生产输入
        FROM pr p                                                                                           -- 取数来源：取自本条自建的中间结果集 pr
        -- （已废）旧版在此按 main_side 连 side_base 取基准，2026-08-11 改注单层注额加权                                          -- 注：连接已移至 ordb，本处不再取基准
        GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer                                 -- 分组：按营业日×会员×荷官×哨兵标记汇总
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
           -- 六·决策层（HF9g-P5D-b · D-14b 斧正 —— 本件属【行加权错粒度族】，六层相对刻度与决策标签一律 NULL）
           --   详见档头【变更日志 · 改动 C】。原六·决策层 29 行逐字留存于本段下方注释，可原样恢复。
           --   ★ 本件之 e.* 仍照常供经济层／分布层／关系层／rate 层／动态层使用，仅六层置 NULL。
           --   ★ audit_rn 不受影响：其 26 个排序键之首二者 residual_b / roi 出自经济层，本段未动。
           --   ★ 副效：本段 8 个无 PARTITION BY 之窗口算子随之消失，全局排序由 9 个降为 1 个。
           --   ⚠⚠ 待裁 · 阻断告警（本段三处字面值随模板逐字沿用，于本件**名实不符**）：
           --        pr_qualified_population   = 'GLOBAL_BASELINE_NO_ENTITY_RANKING'
           --        pr_calculation_method     = 'NOT_APPLICABLE_GLOBAL_BASELINE'
           --        action_priority           = 'X 全窗基线 · 不参与实体赏罚'
           --        本件属【行加权错粒度族】，**并非全窗基线族**；三值将随 CSV 落地，构成失实血统标签。
           --        改之则须引入 P4D/P5D 以外之常量，违「禁引包外」之令 ⇒ 故逐字沿用并在此立案。
           --        ★ 本项未裁定前，本件 CSV **不得进入任何对外交付或下游消费**，仅供跑通性验证。
           CAST(NULL AS INT)                                              AS vip_tier,                        -- 空值取值：全窗基线族无实体可分档，置 NULL（NULL＝不适用，非 0）
           CAST(NULL AS DOUBLE)                                           AS economic_value,                  -- 空值取值：同上，禁以常数百分位冒充经济价值
           CAST(NULL AS DOUBLE)                                           AS roi_pr_global,                   -- 空值取值：同上
           CAST(NULL AS DOUBLE)                                           AS risk_value,                      -- 空值取值：兼容列，同上
           CAST(NULL AS DOUBLE)                                           AS pr_stake,                        -- 空值取值：兼容列，同上
           CAST(NULL AS DOUBLE)                                           AS pr_global,                       -- 空值取值：同上
           CAST(NULL AS DOUBLE)                                           AS pr_qualified,                    -- 空值取值：同上
           'GLOBAL_BASELINE_NO_ENTITY_RANKING'                            AS pr_qualified_population,         -- 字面取值：血统 —— 明示本件为全窗基线族，无实体排序总体
           CAST(NULL AS BIGINT)                                           AS pr_global_population_n,          -- 空值取值：血统 —— 不适用
           CAST(NULL AS BIGINT)                                           AS pr_qualified_population_n,       -- 空值取值：血统 —— 不适用
           'NOT_APPLICABLE_GLOBAL_BASELINE'                               AS pr_calculation_method,           -- 字面取值：血统 —— 算法不适用
           'HF9g-P5'                                                      AS pr_calculation_version,          -- 字面取值：血统 —— 算法版本
           CAST(NULL AS STRING)                                           AS evidence_flag,                   -- 空值取值：证据旗标不适用于全窗基线
           CAST(NULL AS STRING)                                           AS evidence_rate,                   -- 空值取值：同上
           CAST(NULL AS DOUBLE)                                           AS hold_ci_halfwidth_approx,        -- 空值取值：同上
           'X 全窗基线 · 不参与实体赏罚'                                    AS action_priority                  -- 字面取值：★ D-14 斧正 —— 本族恒不入赏罚，取代原 100% 误标之「A」
           --  ┌── 以下 29 行为原六·决策层，逐字留档（D-14b 斧正前），可原样恢复 ──┐
           -- -- 六·决策层（HF9f · 详见档头【HF9f 变更说明】；本段两版逐字同一）
           -- NTILE(5) OVER (ORDER BY e.stake) AS vip_tier,                                                        -- 窗口取值：相对刻度 B 族，全体五等分；须连同下方血统五元组一并解读，禁作硬阈值判型
           -- PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)    AS economic_value,                    -- 窗口取值：HF9f·F-19 修正 —— HF9e 写作 -(-…) 双负号致方向颠倒（#075 实测 corr(economic_value, residual_b) = -1.0000）；今与 action_priority 排序键归一，值大即平台真净利高
           -- PERCENT_RANK() OVER (ORDER BY e.net/NULLIF(e.stake,0))         AS roi_pr_global,                     -- 窗口取值：HF9f·F-17 正名 —— 本列实为 ROI（玩家净回报率）之全体百分位，与「风险」无关；旧名 risk_value 见下一行
           -- PERCENT_RANK() OVER (ORDER BY e.net/NULLIF(e.stake,0))         AS risk_value,                        -- 窗口取值：兼容列，恒等于 roi_pr_global，仅为下游迁移窗保留；HF9g 起废弃，禁新引用
           -- PERCENT_RANK() OVER (ORDER BY e.stake)                         AS pr_stake,                          -- 窗口取值：兼容列，恒等于 pr_global，原名保留以免断链
           -- PERCENT_RANK() OVER (ORDER BY e.stake)                         AS pr_global,                         -- 窗口取值：HF9f·F-1 双轨之一 —— 全体口径百分位，参照总体即本件全部输出行
           -- CASE WHEN e.n_rounds >= 30                                                                           -- 条件分支：起始分支 —— 仅在合格子集内计算合格口径百分位
           -- THEN PERCENT_RANK() OVER (PARTITION BY CASE WHEN e.n_rounds >= 30 THEN 1 ELSE 0 END ORDER BY e.stake)  -- 分支取值：以合格与否分区，故本值即 n_rounds>=30 子集内之百分位
           -- ELSE NULL END                                             AS pr_qualified,                      -- 条件分支：收束上方分支 —— 不合格者留 NULL（NULL＝未测，非 0），产出「pr_qualified」
           -- 'n_rounds>=30'                                                 AS pr_qualified_population,           -- 字面取值：血统 —— 合格子集之定义
           -- COUNT(*) OVER ()                                               AS pr_global_population_n,            -- 窗口取值：血统 —— 全体口径之参照总体规模，渲染时现算，禁写死
           -- SUM(CASE WHEN e.n_rounds >= 30 THEN 1 ELSE 0 END) OVER ()      AS pr_qualified_population_n,         -- 窗口取值：血统 —— 合格子集之参照总体规模，现算，禁写死
           -- 'PERCENT_RANK_OVER_ORDER_BY_e_stake'                           AS pr_calculation_method,             -- 字面取值：血统 —— 算法标识
           -- 'HF9f'                                                         AS pr_calculation_version,            -- 字面取值：血统 —— 算法版本
           -- CASE WHEN e.n_rounds IS NULL OR e.n_rounds < 30 THEN 'THIN_ROUNDS' ELSE 'OK' END AS evidence_flag,   -- 条件分支：HF9f·F-2a 证据旗标 —— THIN_ROUNDS 者禁入执行队列，仅入观察队列
           -- CASE WHEN e.n_rounds IS NULL       THEN NULL                                                         -- 条件分支：起始分支 —— 未测者留 NULL（自家铁律：NULL ≠ 0）
           -- WHEN e.n_rounds >= 31483      THEN 'L1_POWERED'                                                 -- 分支判定：MDE 反解第一档
           -- WHEN e.n_rounds >= 15409      THEN 'L2_CI_1P5'                                                  -- 分支判定：MDE 反解第二档
           -- WHEN e.n_rounds >=  8668      THEN 'L3_CI_2P0'                                                  -- 分支判定：MDE 反解第三档
           -- WHEN e.n_rounds >=  3852      THEN 'L4_CI_3P0'                                                  -- 分支判定：MDE 反解第四档
           -- ELSE 'L5_INSUFFICIENT' END                                AS evidence_rate,                     -- 条件分支：收束上方 —— HF9f·F-3 证据分档，承 HF9e 前议之 MDE 反解五档，须于 F-4 敏感性实验后复核
           -- ROUND(1.96 * 0.95 / SQRT(NULLIF(CAST(e.n_rounds AS DOUBLE),0)),8) AS hold_ci_halfwidth_approx,       -- 比率表达式：HF9f·F-3 逐行现算之 95% 半宽近似；常数 0.95 为登记值，本轮 #075 实测每局 ROI 隐含 σ 于最薄层为 0.9249，二者差异待 F-4 裁定
           -- CASE WHEN e.stake IS NULL OR e.stake<=0 OR e.n_bets<30 OR e.n_rounds IS NULL OR e.n_rounds<30 THEN 'Z 证据不足 · 不动作'  -- 条件分支：HF9f·F-2 双条件取严 —— HF9e 仅卡 e.n_bets<30，致 n_bets>=30 而 n_rounds<30 者绕过 Z（#075 实测 18,537 名，其中 8,145 名已入 A/D 待裁）；今两条件并列取严
           -- WHEN PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)<=0.10                          -- 分支判定：平台真净利之最低十分位
           -- THEN 'A 净亏最大十分位 · 优先复核'                                                             -- 分支取值：HF9f·F-20 正名 —— 本档 Σresidual_b 于 #075 实测 = -100,236,896，系平台净亏最大群，旧名「残值最低十分位 · 待裁」名实不符
           -- WHEN PERCENT_RANK() OVER (ORDER BY -e.net-e.rebate-e.agent_cost)>=0.80                          -- 分支判定：平台真净利之最高二十分位
           -- THEN 'D 净利最高二十分位 · 优先留存'                                                           -- 分支取值：HF9f·F-20 正名 —— 本档 Σresidual_b 于 #075 实测 = +281,733,190，系核心利润源；与 A 档方向相反，旧版同标「待裁」属名实不符
           -- ELSE 'E 常规' END                                          AS action_priority                   -- 条件分支：收束上方判词，产出「action_priority」
           --  └────────────────────────────────────────────────────────────────┘
    FROM q
    LEFT JOIN x_agg e ON CAST(e.x_key AS STRING) = CAST(q.`uid` AS STRING)
  ) y
) z
WHERE z.audit_rn > 990000 AND z.audit_rn <= 1000000   -- ★ 第 100 批（与现档 b100 对应）
ORDER BY z.audit_rn;
