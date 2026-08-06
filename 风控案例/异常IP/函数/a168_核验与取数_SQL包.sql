/* ============================================================================
   a168 风控与客户分层评分体系 · 核验与取数 SQL 包  v3
   ----------------------------------------------------------------------------
   目标库   : StarRocks  ods_mariadb_2b   【只读模式，无 DDL/DML 权限】
   执行环境 : Superset SQL Lab —— 每个 tab 只提交一条语句
   配套报告 : a168风控与客户分层评分体系_商业方案.qmd
   ----------------------------------------------------------------------------
   v3 相对 v2 的三处结构性修正
     1. 【只读】删除全部 CREATE TABLE —— 每条查询自足，BASE 块内联
     2. 【方言】StarRocks 不支持 EXISTS 带非等值谓词
        → 测试代理排除改为五次 LEFT JOIN + COALESCE(...) IS NULL（纯等值）
     3. 【实测】<MID> = bet05；白名单 unnest 未验证，暂从 BASE 移出为独立测试
   ----------------------------------------------------------------------------
   架构原则（只读模式下的正确分工）
     SQL 端  → 只产出【聚合结果】，行数控制在可导出范围
     R 端    → 承担 join、阈值网格、purged walk-forward、回测
     大中间表（玩家×IP 约数百万行）导出 CSV 后在 R/data.table 处理
   ----------------------------------------------------------------------------
   已确定参数
     '2026-03-21' / '2026-08-07'   分析窗（bet02 实测 139 天）
     '101'                          百家乐
     bet05                          dailyreport_member 的会员ID列
   ============================================================================ */


/* ############################################################################
   PART A · 剩余核验（A-03/05/10a/11/12/13 已完成）
   ############################################################################ */

/* --- A-04 铁律⑤分母（EXISTS → LEFT JOIN 重写）------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.bet05, b.bet11, b.bet38, b.category, b.bet08,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
)
SELECT
  COUNT(*)                AS n_valid_orders,
  COUNT(DISTINCT r.bet05) AS n_betting_members,
  COUNT(DISTINCT r.bet01) AS n_distinct_bet_id
FROM rk r
LEFT JOIN ta t1 ON t1.aid = r.bet18
LEFT JOIN ta t2 ON t2.aid = r.bet19
LEFT JOIN ta t3 ON t3.aid = r.bet20
LEFT JOIN ta t4 ON t4.aid = r.bet21
LEFT JOIN ta t5 ON t5.aid = r.bet22
WHERE r.rn = 1
  AND r.category = '1'
  AND UPPER(TRIM(r.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
  AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
  AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
  AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL;


/* --- A-08 测试代理线影响面（同上重写）--------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
tg AS (
  SELECT b.bet05 AS member_id,
         CASE WHEN COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
              THEN 0 ELSE 1 END AS is_test_line,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) AS stake
  FROM ods_mariadb_2b.ods_a168_bet02 b
  LEFT JOIN ta t1 ON t1.aid = b.bet18
  LEFT JOIN ta t2 ON t2.aid = b.bet19
  LEFT JOIN ta t3 ON t3.aid = b.bet20
  LEFT JOIN ta t4 ON t4.aid = b.bet21
  LEFT JOIN ta t5 ON t5.aid = b.bet22
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
)
SELECT is_test_line,
       COUNT(*)                  AS n_orders,
       COUNT(DISTINCT member_id) AS n_members,
       SUM(stake)                AS turnover
FROM tg
GROUP BY is_test_line;


/* --- A-10b dailyreport_member 双标签分布（risk 風險單 / orders 劃單）--- */
SELECT risk, orders,
       COUNT(*)              AS n_rows,
       COUNT(DISTINCT bet05) AS n_members,
       MIN(dt) AS dt_min, MAX(dt) AS dt_max
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101'
GROUP BY risk, orders
ORDER BY n_rows DESC;


/* --- A-06M 局级对账 · MASE 评估（已确认 gi005 为归一化口径）---------
   MASE = MAE / scale，scale = 同桌相邻局 gi_turnover 的平均绝对差分
   （Hyndman & Koehler 2006 的 naive one-step 基准）
   MASE << 1 → 对账误差远小于「用上一局预测本局」的朴素基准 → 口径一致
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet16, b.bet17,
         b.bet38, b.bet39, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
br AS (
  SELECT r.bet03 AS sh, r.bet04 AS rd, r.bet39 AS tb,
    SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS turnover,
    SUM(CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS rebate,
    SUM(CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS net_pnl
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
  GROUP BY r.bet03, r.bet04, r.bet39
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME)     AS t_open,
         CAST(NULLIF(TRIM(gi005),'') AS DECIMAL(20,4)) AS gi_turnover,
         CAST(NULLIF(TRIM(gi009),'') AS DECIMAL(20,4)) AS gi_rebate,
         CAST(NULLIF(TRIM(gi010),'') AS DECIMAL(20,4)) AS gi_net
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
j AS (
  SELECT g.tb, g.t_open,
         ABS(b.turnover - g.gi_turnover) AS ae_turnover,
         ABS(b.rebate   - g.gi_rebate)   AS ae_rebate,
         ABS(b.net_pnl  - g.gi_net)      AS ae_net,
         g.gi_turnover, g.gi_rebate, g.gi_net,
         LAG(g.gi_turnover) OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_turnover,
         LAG(g.gi_rebate)   OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_rebate,
         LAG(g.gi_net)      OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_net
  FROM br b
  JOIN gi g ON b.sh = g.sh AND b.rd = g.rd AND b.tb = g.tb
)
SELECT
  COUNT(*)                                            AS n_matched_round,
  AVG(ae_turnover)                                    AS mae_turnover,
  AVG(ae_rebate)                                      AS mae_rebate,
  AVG(ae_net)                                         AS mae_net,
  AVG(ABS(gi_turnover - lag_turnover))                AS scale_turnover,
  AVG(ABS(gi_rebate   - lag_rebate))                  AS scale_rebate,
  AVG(ABS(gi_net      - lag_net))                     AS scale_net,
  AVG(ae_turnover) / NULLIF(AVG(ABS(gi_turnover - lag_turnover)), 0) AS mase_turnover,
  AVG(ae_rebate)   / NULLIF(AVG(ABS(gi_rebate   - lag_rebate)),   0) AS mase_rebate,
  AVG(ae_net)      / NULLIF(AVG(ABS(gi_net      - lag_net)),      0) AS mase_net,
  SUM(CASE WHEN ae_turnover <= 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_exact_turnover,
  SUM(CASE WHEN ae_net      <= 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_exact_net
FROM j
WHERE lag_turnover IS NOT NULL;
/* 判读：
     mase_* < 0.05  → 对账误差不足朴素基准的 5%，口径完全一致
     mase_* ≈ 1     → 误差与局间自然波动同量级，口径存疑
     pct_exact_*    → 完全一致（容差 0.01）的局占比，直观补充指标         */


/* --- A-14 白名单展开可行性测试（unnest 是否支持）---------------------- */
SELECT COUNT(*) AS n_ip
FROM ods_mariadb_2b.ods_a168_white_list,
     unnest(split(white_list, ',')) AS t(ip_item)
WHERE NULLIF(TRIM(ip_item),'') IS NOT NULL;
/* 若报错，改试：
   SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_white_list
   LATERAL VIEW EXPLODE(SPLIT(white_list, ',')) t AS ip_item;
   两者皆不支持 → 白名单在 R 端展开，SQL 侧不做 IP 白名单过滤 */


/* ############################################################################
   BASE 块 · 每条下游查询的公共前缀（只读模式下必须内联）
   ----------------------------------------------------------------------------
   使用方法：复制下面 WITH ... base AS (...) 整段，粘到目标查询前面，
             然后接目标查询的 SELECT。本文件已为每条查询预先内联。
   ############################################################################

WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME) AS t_open,
         CAST(NULLIF(TRIM(gi006),'') AS DATETIME) AS t_rev
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
base AS (
  SELECT
    v.bet01 AS bet_id, v.bet05 AS member_id,
    CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
    v.bet39 AS table_id, v.bet40 AS room_id, v.eid AS dealer_id,
    v.commission AS comm, v.bet09 AS bet_side, v.ip AS bet_ip,
    v.bet20 AS lv3, v.bet22 AS lv5,
    CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
    CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,
    CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
    (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
     - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
    CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,
    CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl,
    TIMESTAMPDIFF(SECOND, g.t_open, CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME)) * 1.0
      / NULLIF(TIMESTAMPDIFF(SECOND, g.t_open, g.t_rev), 0) AS bet_progress
  FROM vd v
  JOIN gi g ON v.bet03 = g.sh AND v.bet04 = g.rd AND v.bet39 = g.tb
)

   ############################################################################ */


/* ############################################################################
   PART C · 异常 IP（需求 §4）—— 全部自足
   ############################################################################ */

/* --- C-02 玩家×IP 基础指标（导出后在 R 端做网格）---------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet01 AS bet_id, v.bet05 AS member_id, v.ip AS bet_ip,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet20 AS lv3,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl
  FROM vd v
),
pl AS (
  SELECT member_id,
         COUNT(DISTINCT bet_id)    AS n_orders_all,
         COUNT(DISTINCT round_key) AS n_rounds_all,
         SUM(net_pnl)              AS net_pnl_all,
         SUM(game_pnl)             AS game_pnl_all
  FROM bs GROUP BY member_id
)
SELECT
  b.bet_ip, b.member_id, MAX(b.lv3) AS lv3,
  COUNT(DISTINCT b.bet_id)    AS n_orders_ip,
  COUNT(DISTINCT b.round_key) AS n_rounds_ip,
  SUM(b.stake)    AS stake_ip,
  SUM(b.game_pnl) AS game_pnl_ip,
  SUM(b.rebate)   AS rebate_ip,
  SUM(b.net_pnl)  AS net_pnl_ip,
  MAX(p.n_orders_all) AS n_orders_all,
  MAX(p.n_rounds_all) AS n_rounds_all,
  MAX(p.net_pnl_all)  AS net_pnl_all,
  MAX(p.game_pnl_all) AS game_pnl_all,
  COUNT(DISTINCT b.bet_id) * 1.0 / NULLIF(MAX(p.n_orders_all), 0) AS ip_order_share
FROM bs b
JOIN pl p ON b.member_id = p.member_id
WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL
GROUP BY b.bet_ip, b.member_id
ORDER BY b.bet_ip, b.member_id;
/* 预估行数：数百万级。导出 CSV 后，C-03/C-04/C-05 全部在 R 端完成，
   避免只读模式下重复扫描 1.25 亿行。                                    */


/* --- C-01 公共网络 IP 识别（聚合到 IP，结果集小）---------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
)
SELECT
  v.ip AS bet_ip,
  COUNT(DISTINCT v.bet05) AS n_member,
  COUNT(DISTINCT v.bet20) AS n_lv3_chain,
  COUNT(DISTINCT v.bet05) * 1.0 / NULLIF(COUNT(DISTINCT v.bet20), 0) AS member_per_chain,
  COUNT(*) AS n_orders,
  SUM(CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))) AS stake,
  SUM((CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))) AS game_pnl,
  SUM(CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))) AS net_pnl
FROM vd v
WHERE NULLIF(TRIM(v.ip),'') IS NOT NULL
GROUP BY v.ip
HAVING COUNT(DISTINCT v.bet05) >= 20
ORDER BY member_per_chain DESC, n_member DESC;


/* --- C-08 /24 网段聚集 -------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
    AND NULLIF(TRIM(r.ip),'') IS NOT NULL
)
SELECT
  CONCAT(SPLIT_PART(v.ip,'.',1), '.', SPLIT_PART(v.ip,'.',2), '.',
         SPLIT_PART(v.ip,'.',3), '.0/24') AS subnet_24,
  COUNT(DISTINCT v.ip)    AS n_ip,
  COUNT(DISTINCT v.bet05) AS n_member,
  COUNT(DISTINCT v.bet20) AS n_lv3_chain,
  COUNT(*)                AS n_orders,
  SUM(CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))) AS stake,
  SUM((CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))) AS game_pnl,
  SUM(CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
      / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))) AS valid_bet
FROM vd v
GROUP BY 1
HAVING COUNT(DISTINCT v.bet05) >= 5
ORDER BY n_member DESC;


/* --- C-06 同 IP 对押率（限定 n_member>=2 的 IP，控制笛卡尔积）--------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
    AND NULLIF(TRIM(r.ip),'') IS NOT NULL
),
sd AS (
  SELECT CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.ip AS bet_ip, v.bet05 AS member_id,
         SUM(CASE WHEN UPPER(v.bet09) LIKE '%BANKER%'
             THEN CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
                  / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))
             ELSE 0 END) AS amt_b,
         SUM(CASE WHEN UPPER(v.bet09) LIKE '%PLAYER%'
             THEN CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
                  / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8))
             ELSE 0 END) AS amt_p
  FROM vd v
  GROUP BY CONCAT_WS('|', v.bet03, v.bet04, v.bet39), v.ip, v.bet05
),
multi AS (
  SELECT round_key, bet_ip
  FROM sd GROUP BY round_key, bet_ip HAVING COUNT(DISTINCT member_id) >= 2
),
sd2 AS (
  SELECT s.* FROM sd s JOIN multi m
    ON s.round_key = m.round_key AND s.bet_ip = m.bet_ip
),
pr AS (
  SELECT a.bet_ip AS bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         LEAST(a.amt_b, b.amt_p) + LEAST(a.amt_p, b.amt_b) AS matched,
         a.amt_b + a.amt_p + b.amt_b + b.amt_p             AS total
  FROM sd2 a
  JOIN sd2 b ON a.round_key = b.round_key AND a.bet_ip = b.bet_ip
            AND a.member_id < b.member_id
)
SELECT bet_ip, m_a, m_b,
       COUNT(*) AS n_same_round,
       SUM(CASE WHEN matched > 0 THEN 1 ELSE 0 END) AS n_opposite_round,
       SUM(CASE WHEN matched > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS opposite_rate,
       SUM(2 * matched) / NULLIF(SUM(total), 0) AS hedge_coverage
FROM pr
GROUP BY bet_ip, m_a, m_b
HAVING COUNT(*) >= 10
ORDER BY hedge_coverage DESC, n_same_round DESC;


/* ############################################################################
   PART D · 尾段下注（需求 §5）—— 全部自足，按桌台分层
   ############################################################################ */

/* --- D-00 bet_progress 实际分布（★ 必先跑：D-03 返回 0 的根因）--------
   实测：局跨度(开局→开奖)约 40 秒，下注跨度仅 11–13 秒
   → bet_progress 上限约 0.3，绝对阈值 0.90 不可达
   → 尾段阈值必须取「桌台内的高分位」，不可拍固定值
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME) AS t_open,
         CAST(NULLIF(TRIM(gi006),'') AS DATETIME) AS t_rev
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
bs AS (
  SELECT v.bet39 AS table_id,
         TIMESTAMPDIFF(SECOND, g.t_open,
           CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME)) AS sec_elapsed,
         TIMESTAMPDIFF(SECOND, g.t_open, g.t_rev)      AS round_span,
         TIMESTAMPDIFF(SECOND, g.t_open,
           CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME)) * 1.0
           / NULLIF(TIMESTAMPDIFF(SECOND, g.t_open, g.t_rev), 0) AS bet_progress
  FROM vd v
  JOIN gi g ON v.bet03 = g.sh AND v.bet04 = g.rd AND v.bet39 = g.tb
)
SELECT table_id,
       COUNT(*)                              AS n_orders,
       AVG(sec_elapsed)                      AS mean_sec_elapsed,
       AVG(round_span)                       AS mean_round_span,
       PERCENTILE_APPROX(bet_progress, 0.50) AS p50,
       PERCENTILE_APPROX(bet_progress, 0.75) AS p75,
       PERCENTILE_APPROX(bet_progress, 0.90) AS p90,
       PERCENTILE_APPROX(bet_progress, 0.95) AS p95,
       PERCENTILE_APPROX(bet_progress, 0.99) AS p99,
       MAX(bet_progress)                     AS max_progress
FROM bs
WHERE bet_progress BETWEEN 0 AND 1
GROUP BY table_id
HAVING COUNT(*) >= 1000
ORDER BY n_orders DESC;
/* 用 p90 / p95 作为该桌的尾段切点，代回 D-03 与 D-05。 */


/* --- D-01 下注进度分布（按桌台）--------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME) AS t_open,
         CAST(NULLIF(TRIM(gi006),'') AS DATETIME) AS t_rev
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
bs AS (
  SELECT v.bet39 AS table_id, v.bet05 AS member_id,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,
         TIMESTAMPDIFF(SECOND, g.t_open,
           CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME)) * 1.0
           / NULLIF(TIMESTAMPDIFF(SECOND, g.t_open, g.t_rev), 0) AS bet_progress
  FROM vd v
  JOIN gi g ON v.bet03 = g.sh AND v.bet04 = g.rd AND v.bet39 = g.tb
)
SELECT table_id,
       FLOOR(bet_progress * 20)  AS progress_bin_20,
       COUNT(*)                  AS n_orders,
       COUNT(DISTINCT member_id) AS n_players,
       COUNT(DISTINCT round_key) AS n_rounds,
       SUM(stake)     AS stake,
       SUM(valid_bet) AS valid_bet,
       SUM(game_pnl)  AS game_pnl,
       SUM(rebate)    AS rebate,
       SUM(game_pnl) / NULLIF(SUM(valid_bet), 0) AS roi
FROM bs
WHERE bet_progress BETWEEN 0 AND 1
GROUP BY table_id, FLOOR(bet_progress * 20)
ORDER BY table_id, progress_bin_20;


/* --- D-03Q 局内匹配检验 · 桌台分位版（替代固定 0.90，D-03 已废）------
   尾段 = bet_progress >= 该桌台的 P90（由 D-00 实证，绝对阈值不可用）
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME) AS t_open,
         CAST(NULLIF(TRIM(gi006),'') AS DATETIME) AS t_rev
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
bs AS (
  SELECT CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id, v.bet09 AS bet_side, v.bet05 AS member_id,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
         TIMESTAMPDIFF(SECOND, g.t_open,
           CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME)) * 1.0
           / NULLIF(TIMESTAMPDIFF(SECOND, g.t_open, g.t_rev), 0) AS bet_progress
  FROM vd v
  JOIN gi g ON v.bet03 = g.sh AND v.bet04 = g.rd AND v.bet39 = g.tb
),
thr AS (
  SELECT table_id, PERCENTILE_APPROX(bet_progress, 0.90) AS q90
  FROM bs WHERE bet_progress BETWEEN 0 AND 1
  GROUP BY table_id
),
fl AS (
  SELECT b.*, CASE WHEN b.bet_progress >= t.q90 THEN 1 ELSE 0 END AS is_tail
  FROM bs b JOIN thr t ON b.table_id = t.table_id
  WHERE b.bet_progress BETWEEN 0 AND 1
),
cell AS (
  SELECT round_key, bet_side,
    SUM(CASE WHEN is_tail = 1 THEN game_pnl  ELSE 0 END) AS pnl_tail,
    SUM(CASE WHEN is_tail = 1 THEN valid_bet ELSE 0 END) AS vb_tail,
    SUM(CASE WHEN is_tail = 0 THEN game_pnl  ELSE 0 END) AS pnl_norm,
    SUM(CASE WHEN is_tail = 0 THEN valid_bet ELSE 0 END) AS vb_norm,
    COUNT(DISTINCT CASE WHEN is_tail = 1 THEN member_id END) AS n_tail,
    COUNT(DISTINCT CASE WHEN is_tail = 0 THEN member_id END) AS n_norm
  FROM fl
  GROUP BY round_key, bet_side
)
SELECT COUNT(*) AS n_matched_cells,
       SUM(vb_tail) AS vb_tail_total,
       SUM(vb_norm) AS vb_norm_total,
       SUM(pnl_tail) / NULLIF(SUM(vb_tail), 0) AS roi_tail,
       SUM(pnl_norm) / NULLIF(SUM(vb_norm), 0) AS roi_norm,
       SUM(pnl_tail) / NULLIF(SUM(vb_tail), 0)
         - SUM(pnl_norm) / NULLIF(SUM(vb_norm), 0) AS roi_diff
FROM cell
WHERE n_tail > 0 AND n_norm > 0;
/* n_matched_cells 若仍为 0，说明桌内 bet_progress 分布过于集中，
   需改用「局内下注顺序位次」而非时间比例，见 D-03R。                */


/* --- D-03R 局内下注顺序版（bet_progress 分布退化时的备选）------------
   尾段 = 该玩家在本局的下注顺序位次处于末段（按顺序而非时间）
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet09 AS bet_side, v.bet05 AS member_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl
  FROM vd v
),
ord AS (
  SELECT b.*,
         PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,
         COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round
  FROM bs b
),
cell AS (
  SELECT round_key, bet_side,
    SUM(CASE WHEN pr_in_round >= 0.80 THEN game_pnl  ELSE 0 END) AS pnl_tail,
    SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END) AS vb_tail,
    SUM(CASE WHEN pr_in_round <  0.80 THEN game_pnl  ELSE 0 END) AS pnl_norm,
    SUM(CASE WHEN pr_in_round <  0.80 THEN valid_bet ELSE 0 END) AS vb_norm,
    COUNT(DISTINCT CASE WHEN pr_in_round >= 0.80 THEN member_id END) AS n_tail,
    COUNT(DISTINCT CASE WHEN pr_in_round <  0.80 THEN member_id END) AS n_norm
  FROM ord
  WHERE n_in_round >= 5
  GROUP BY round_key, bet_side
)
SELECT COUNT(*) AS n_matched_cells,
       SUM(vb_tail) AS vb_tail_total,
       SUM(vb_norm) AS vb_norm_total,
       SUM(pnl_tail) / NULLIF(SUM(vb_tail), 0) AS roi_tail,
       SUM(pnl_norm) / NULLIF(SUM(vb_norm), 0) AS roi_norm,
       SUM(pnl_tail) / NULLIF(SUM(vb_tail), 0)
         - SUM(pnl_norm) / NULLIF(SUM(vb_norm), 0) AS roi_diff
FROM cell
WHERE n_tail > 0 AND n_norm > 0;


/* --- D-03S 日级 roi_diff 序列（★ 显著性检验的输入，139 行）-----------
   聚合 ROI 没有标准误，无法判断 +0.000657 是信号还是噪声。
   本条按日输出两口径的 roi_diff，R 端做单样本 t 检验 + Bootstrap CI，
   并可直接用于 purged walk-forward 的时间外稳定性检验。
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet09 AS bet_side,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl
  FROM vd v
),
ord AS (
  SELECT b.*,
         PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,
         COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round
  FROM bs b
)
SELECT bet_date,
  COUNT(DISTINCT round_key) AS n_rounds,
  SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END) AS vb_tail,
  SUM(CASE WHEN pr_in_round <  0.80 THEN valid_bet ELSE 0 END) AS vb_norm,
  SUM(CASE WHEN pr_in_round >= 0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END), 0) AS roi_tail,
  SUM(CASE WHEN pr_in_round <  0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round <  0.80 THEN valid_bet ELSE 0 END), 0) AS roi_norm,
  SUM(CASE WHEN pr_in_round >= 0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END), 0)
    - SUM(CASE WHEN pr_in_round <  0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round <  0.80 THEN valid_bet ELSE 0 END), 0) AS roi_diff
FROM ord
WHERE n_in_round >= 5
GROUP BY bet_date
ORDER BY bet_date;
/* R 端：t.test(roi_diff)、boot::boot 求 BCa CI；
   若 CI 跨 0 → 报告写「未观察到统计显著的尾段优势」。          */


/* --- D-03X 分层一致性（按投注选项 × 是否免佣）------------------------
   两口径符号相反已说明结论不稳健；本条进一步查是否由某个选项主导。
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet09 AS bet_side, v.commission AS comm,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl
  FROM vd v
),
ord AS (
  SELECT b.*,
         PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,
         COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round
  FROM bs b
)
SELECT bet_side, comm,
  COUNT(*) AS n_orders,
  SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END) AS vb_tail,
  SUM(CASE WHEN pr_in_round >= 0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END), 0) AS roi_tail,
  SUM(CASE WHEN pr_in_round <  0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round <  0.80 THEN valid_bet ELSE 0 END), 0) AS roi_norm,
  SUM(CASE WHEN pr_in_round >= 0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round >= 0.80 THEN valid_bet ELSE 0 END), 0)
    - SUM(CASE WHEN pr_in_round <  0.80 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN pr_in_round <  0.80 THEN valid_bet ELSE 0 END), 0) AS roi_diff
FROM ord
WHERE n_in_round >= 5
GROUP BY bet_side, comm
HAVING COUNT(*) >= 10000
ORDER BY roi_diff DESC;


/* --- D-05 玩家×物理局明细（导出后 R 端算尾段十一项指标）-------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME) AS t_open,
         CAST(NULLIF(TRIM(gi006),'') AS DATETIME) AS t_rev
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
bs AS (
  SELECT v.bet05 AS member_id,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id, v.eid AS dealer_id, v.commission AS comm,
         v.ip AS bet_ip,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl,
         TIMESTAMPDIFF(SECOND, g.t_open,
           CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME)) * 1.0
           / NULLIF(TIMESTAMPDIFF(SECOND, g.t_open, g.t_rev), 0) AS bet_progress
  FROM vd v
  JOIN gi g ON v.bet03 = g.sh AND v.bet04 = g.rd AND v.bet39 = g.tb
)
SELECT member_id, round_key, table_id, dealer_id, comm,
       COUNT(*)          AS n_orders,
       MIN(t_bet)        AS first_bet_ts,
       MAX(t_bet)        AS last_bet_ts,
       MAX(bet_progress) AS max_progress,
       MAX(bet_ip)       AS bet_ip,
       SUM(stake)        AS stake,
       SUM(valid_bet)    AS valid_bet,
       SUM(game_pnl)     AS game_pnl,
       SUM(rebate)       AS rebate,
       SUM(net_pnl)      AS net_pnl,
       CASE WHEN SUM(game_pnl) > 0 THEN 1 ELSE 0 END AS is_win,
       CASE WHEN SUM(game_pnl) < 0 THEN 1 ELSE 0 END AS is_lose,
       CASE WHEN SUM(game_pnl) = 0 THEN 1 ELSE 0 END AS is_tie
FROM bs
GROUP BY member_id, round_key, table_id, dealer_id, comm
ORDER BY member_id, first_bet_ts;
/* ⚠️ 行数量级数千万，远超 10 万导出上限 —— 本条【不导出，仅供参考结构】。
   实际做法：把 D-05 作为 CTE 内嵌进 D-06 / D-07 / D-08，
   在 SQL 端直接聚合到 ≤10 万行的最终结果再导出。                        */


/* --- D-06 玩家尾段十一项指标（SQL 端完成，加过滤控制在 10 万行内）----
   过滤：n_rounds_all >= 30（低于此样本量的玩家 Wilson CI 宽度 > 0.15，
         阈值无区分意义，见需求 §2.2-5）
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl
  FROM vd v
),
ord AS (
  SELECT b.*, PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,
              COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round
  FROM bs b
),
prd AS (
  SELECT member_id, round_key, table_id,
         MAX(pr_in_round) AS max_pr,
         MAX(n_in_round)  AS n_in_round,
         SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
         CASE WHEN SUM(game_pnl) > 0 THEN 1 ELSE 0 END AS is_win,
         CASE WHEN SUM(game_pnl) < 0 THEN 1 ELSE 0 END AS is_lose
  FROM ord WHERE n_in_round >= 5
  GROUP BY member_id, round_key, table_id
),
fl AS (
  SELECT p.*, CASE WHEN p.max_pr >= 0.80 THEN 1 ELSE 0 END AS is_tail
  FROM prd p
)
SELECT member_id,
  COUNT(*)                      AS n_rounds_all,
  SUM(is_tail)                  AS n_rounds_tail,
  SUM(is_tail) * 1.0 / COUNT(*) AS tail_share,
  SUM(is_tail * is_win)  AS tail_win,
  SUM(is_tail * is_lose) AS tail_lose,
  SUM(is_tail * is_win) * 1.0
    / NULLIF(SUM(is_tail * is_win) + SUM(is_tail * is_lose), 0) AS tail_winrate,
  SUM((1 - is_tail) * is_win) * 1.0
    / NULLIF(SUM((1 - is_tail) * is_win) + SUM((1 - is_tail) * is_lose), 0) AS norm_winrate,
  SUM(is_tail * is_win) * 1.0
    / NULLIF(SUM(is_tail * is_win) + SUM(is_tail * is_lose), 0)
    - SUM((1 - is_tail) * is_win) * 1.0
    / NULLIF(SUM((1 - is_tail) * is_win) + SUM((1 - is_tail) * is_lose), 0) AS winrate_diff,
  SUM(is_tail * stake)     AS tail_stake,
  SUM(is_tail * valid_bet) AS tail_valid_bet,
  SUM(is_tail * game_pnl)  AS tail_game_pnl,
  SUM(is_tail * rebate)    AS tail_rebate,
  SUM(is_tail * net_pnl)   AS tail_net_pnl,
  SUM(is_tail * game_pnl) / NULLIF(SUM(is_tail * valid_bet), 0) AS tail_roi,
  SUM((1 - is_tail) * game_pnl) AS norm_game_pnl,
  SUM((1 - is_tail) * game_pnl)
    / NULLIF(SUM((1 - is_tail) * valid_bet), 0) AS norm_roi,
  SUM(CASE WHEN is_tail = 1 AND game_pnl > 0 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN game_pnl > 0 THEN game_pnl ELSE 0 END), 0) AS tail_profit_share
FROM fl
GROUP BY member_id
HAVING COUNT(*) >= 30
ORDER BY member_id;


/* ############################################################################
   PART G · 标签（L1a / L1b）
   ############################################################################ */

/* --- G-01 L1a 会员级弱标签（bet05 已确认）----------------------------- */
SELECT bet05 AS member_id,
       MAX(CAST(NULLIF(TRIM(risk),'')   AS INT)) AS risk_max,
       MAX(CAST(NULLIF(TRIM(orders),'') AS INT)) AS orders_max,
       SUM(CAST(NULLIF(TRIM(risk),'')   AS INT)) AS risk_days,
       COUNT(*) AS n_report_days,
       MIN(dt) AS first_dt, MAX(dt) AS last_dt
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101'
GROUP BY bet05
ORDER BY bet05;


/* --- G-02 L1b 桌台级标签 ---------------------------------------------- */
SELECT time AS report_date, bet39 AS table_id, bet02 AS game_cat,
       risk, orders, count AS n_bets,
       CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)) AS stake_raw,
       CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) AS validbet_raw
FROM ods_mariadb_2b.ods_a168_dailyreport_table
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
ORDER BY time, bet39;


/* ============================================================================
   只读模式下的执行策略
   ----------------------------------------------------------------------------
   已完成 : A-03 A-05 A-07 A-10a A-11 A-12 A-13
   待执行 : A-04 A-06 A-08 A-10b A-14
   主取数 : D-05（玩家×物理局明细，按周分批导出）
            C-02（玩家×IP，一次导出）
            G-01 G-02（标签）
   小结果 : C-01 C-08 D-01 D-03 —— 直接看数即可，无需导出
   ----------------------------------------------------------------------------
   R 端承接（因只读无法物化，全部下游计算移至 R）
     data.table::fread 读入 D-05 分批文件 → rbindlist
     按桌台 quantile(max_progress, 0.9) 定尾段阈值
     算尾段十一项指标 → 阈值网格 → Wilson CI
     C-02 → 三版本盈利口径（A/B/C）→ IP 阈值网格
     周面板 t0/t1 → embargo := ceiling(quantile(lag, .95)) → purged WF
   ----------------------------------------------------------------------------
   导出注意
     · 必带 ORDER BY，UTF-8 BOM
     · D-05 按 dt 分周切片，避免单次导出过大
   ============================================================================ */
