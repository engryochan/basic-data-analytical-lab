/* ============================================================================
   a168 风控与客户分层评分体系 · 核验与取数 SQL 包
   ----------------------------------------------------------------------------
   目标库   : StarRocks  ods_mariadb_2b
   执行环境 : Superset SQL Lab —— 【每个 tab 只提交一条语句】，禁止批量粘贴
   配套报告 : a168风控与客户分层评分体系_商业方案.qmd
   作者     : Ryo Eng · 世博量化® Scibrokes Trading®
   ----------------------------------------------------------------------------
   参数（每条 SQL 开头自行替换）
     :dt_from  分析窗起（含）      如 '2026-01-01'
     :dt_to    分析窗止（不含）    如 '2026-05-01'
     :game     游戏类别            固定 '101'（百家乐，需求 §3.1）
   ----------------------------------------------------------------------------
   口径铁律（全包强制）
     ① 表名 ods_mariadb_2b.ods_a168_*
     ② CAST(NULLIF(TRIM(x),'') AS ...) —— 仅 CAST 会把空串静默转 0
     ③ bet02 自带 bet15/bet16，本任务不 join bet01
     ④a bet02='101' 已蕴含 bet03<>'0'（保留为断言，见 A-13）
     ④b 测试线排除走 agent.age022='1'（bet02 无 age022）
     ⑤ 分母 = 有效订单口径下的 COUNT(DISTINCT bet05)，禁用 5849 万账户
     ⑥ 物理局键 = bet03 + bet04 + bet39（三段）
     ⑦ 分页导出必带 ORDER BY，否则 StarRocks 无序分页会制造重复行
   ============================================================================ */


/* ############################################################################
   PART A · E1 全局核验（12 条）
   —— 上载 CSV 上限 10 万行且为 LIMIT 抽样，仅可用于语义判读。
      以下全部为全量查询，结果覆盖报告中所有 E2 局部观察。
   ############################################################################ */


/* ---------------------------------------------------------------------------
   A-01 ｜ 标签表与主表的时间跨度  ★ 决定标签策略走甲/乙/丙哪条路
   --------------------------------------------------------------------------- */
SELECT 'bet02'                AS tbl, MIN(dt) AS dt_min, MAX(dt) AS dt_max,
       COUNT(DISTINCT dt) AS n_days, COUNT(*) AS n_rows
FROM ods_mariadb_2b.ods_a168_bet02
UNION ALL SELECT 'dailyreport_member', MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_dailyreport_member
UNION ALL SELECT 'dailyreport_table',  MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_dailyreport_table
UNION ALL SELECT 'risklist',           MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_risklist
UNION ALL SELECT 'alarmMessage',       MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_alarmMessage
UNION ALL SELECT 'alertMessage',       MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_alertMessage
UNION ALL SELECT 'mem_login',          MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_mem_login
UNION ALL SELECT 'game_info',          MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_game_info
UNION ALL SELECT 'game_log',           MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_game_log
UNION ALL SELECT 'iphistory',          MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_iphistory
UNION ALL SELECT 'betchange_log',      MIN(dt),MAX(dt),COUNT(DISTINCT dt),COUNT(*)
  FROM ods_mariadb_2b.ods_a168_betchange_log
ORDER BY tbl;
/* 判读：
     标签表 dt_max < '2026-01-01'  → 路径甲（窗口前移至标签覆盖区间）
     dailyreport_member 覆盖 2026  → 路径乙（坚守 2026）
     两者皆有历史与近期            → 路径丙（双窗并行，推荐）           */


/* ---------------------------------------------------------------------------
   A-02 ｜ member 最新快照：测试户与风险标签的真实分布
   --------------------------------------------------------------------------- */
SELECT mem019 AS is_test, mem024 AS mem_risk, mem016 AS enable_flag,
       COUNT(*) AS n_member
FROM (
  SELECT mem001, mem016, mem019, mem024,
         ROW_NUMBER() OVER (PARTITION BY mem001 ORDER BY dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_member
) x
WHERE rn = 1
GROUP BY mem019, mem024, mem016
ORDER BY n_member DESC;
/* 判读：10 万样本中三者全为单值，系按主键序抽样所致。
   本查询给出真实分布；若 mem024 全为 0，则 L2b 标签作废。      */


/* ---------------------------------------------------------------------------
   A-03 ｜ 三方 IP 重合度  ★ 决定 EVA 维度与地理归属是否可用
   --------------------------------------------------------------------------- */
WITH a AS (
  SELECT DISTINCT ip FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= :dt_from AND dt < :dt_to AND bet02 = :game
    AND NULLIF(TRIM(ip),'') IS NOT NULL
),
b AS (
  SELECT DISTINCT ip FROM ods_mariadb_2b.ods_a168_game_log
  WHERE dt >= :dt_from AND dt < :dt_to AND NULLIF(TRIM(ip),'') IS NOT NULL
),
c AS (
  SELECT DISTINCT mlg006 AS ip FROM ods_mariadb_2b.ods_a168_mem_login
  WHERE dt >= :dt_from AND dt < :dt_to AND NULLIF(TRIM(mlg006),'') IS NOT NULL
)
SELECT (SELECT COUNT(*) FROM a)                                  AS n_bet_ip,
       (SELECT COUNT(*) FROM b)                                  AS n_gamelog_ip,
       (SELECT COUNT(*) FROM c)                                  AS n_login_ip,
       (SELECT COUNT(*) FROM a JOIN b ON a.ip=b.ip)              AS ov_bet_gamelog,
       (SELECT COUNT(*) FROM a JOIN c ON a.ip=c.ip)              AS ov_bet_login,
       (SELECT COUNT(*) FROM b JOIN c ON b.ip=c.ip)              AS ov_gamelog_login;
/* 判读：ov_bet_gamelog / n_bet_ip < 0.10 → game_log 的地理信息无法映射到下注IP，
        IP-C4 跨地理跳变维度不可实现，须在报告中标为「未实现及原因」。   */


/* ---------------------------------------------------------------------------
   A-04 ｜ 铁律⑤分母：有效订单口径下的去重会员数
   --------------------------------------------------------------------------- */
WITH test_agents AS (
  SELECT DISTINCT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.bet05, b.bet11, b.bet38, b.category, b.bet08,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= :dt_from AND b.dt < :dt_to AND b.bet02 = :game
)
SELECT COUNT(*)                        AS n_valid_orders,
       COUNT(DISTINCT bet05)           AS n_betting_members,   -- ★ 铁律⑤分母
       COUNT(DISTINCT bet01)           AS n_distinct_bet_id
FROM ranked r
WHERE r.rn = 1
  AND r.category = '1'
  AND UPPER(TRIM(r.bet38)) = 'N'
  AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
  AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
  AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM test_agents t
                  WHERE t.agent_id IN (r.bet18,r.bet19,r.bet20,r.bet21,r.bet22));
/* 预期 n_betting_members 与 132.9 万同量级（误差 < 5%）。
   偏离过大 → 回查过滤条件或窗口设定。                              */


/* ---------------------------------------------------------------------------
   A-05 ｜ bet01 去重影响面（需求 §3.2 三级排序）
   --------------------------------------------------------------------------- */
SELECT COUNT(*)                                  AS n_raw,
       COUNT(DISTINCT bet01)                     AS n_distinct_bet01,
       COUNT(*) - COUNT(DISTINCT bet01)          AS n_dropped,
       1 - COUNT(DISTINCT bet01) * 1.0 / COUNT(*) AS dup_rate
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= :dt_from AND dt < :dt_to AND bet02 = :game;
/* dup_rate 若显著 > 0，说明存在改单/重推版本，去重不可省。 */


/* ---------------------------------------------------------------------------
   A-06 ｜ 局级独立对账：game_info vs bet02  ★ 验证去重与过滤逻辑是否正确
   --------------------------------------------------------------------------- */
WITH test_agents AS (
  SELECT DISTINCT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= :dt_from AND b.dt < :dt_to AND b.bet02 = :game
),
bet_round AS (
  SELECT r.bet03 AS shoe_id, r.bet04 AS round_no, r.bet39 AS table_id,
         SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)))  AS turnover,
         SUM(CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)))  AS rebate,
         SUM(CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
             / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)))  AS net_pnl
  FROM ranked r
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NOT EXISTS (SELECT 1 FROM test_agents t
                    WHERE t.agent_id IN (r.bet18,r.bet19,r.bet20,r.bet21,r.bet22))
  GROUP BY r.bet03, r.bet04, r.bet39
),
gi AS (
  SELECT gi002 AS shoe_id, gi003 AS round_no, gi011 AS table_id,
         CAST(NULLIF(TRIM(gi005),'') AS DECIMAL(20,4)) AS gi_turnover,
         CAST(NULLIF(TRIM(gi009),'') AS DECIMAL(20,4)) AS gi_rebate,
         CAST(NULLIF(TRIM(gi010),'') AS DECIMAL(20,4)) AS gi_net
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= :dt_from AND dt < :dt_to AND gi001 = :game
    AND gi013 = '1' AND is_lock = 'N'
)
SELECT COUNT(*)                                                    AS n_matched_round,
       AVG(ABS(b.turnover - g.gi_turnover))                        AS mae_turnover,
       AVG(ABS(b.rebate   - g.gi_rebate))                          AS mae_rebate,
       AVG(ABS(b.net_pnl  - g.gi_net))                             AS mae_net,
       SUM(CASE WHEN ABS(b.turnover - g.gi_turnover) > 0.01 THEN 1 ELSE 0 END) AS n_mis_turnover,
       SUM(CASE WHEN ABS(b.net_pnl  - g.gi_net)      > 0.01 THEN 1 ELSE 0 END) AS n_mis_net
FROM bet_round b
JOIN gi g ON b.shoe_id = g.shoe_id AND b.round_no = g.round_no
         AND b.table_id = g.table_id;
/* ⚠️ 注意：gi005/gi009/gi010 是否已归一（除汇率）未知。
   若 mae 极大且呈固定倍数，说明单位不同，需先确认再对账。
   n_matched_round 远小于 bet_round 行数 → join 键或过滤条件有误。   */


/* ---------------------------------------------------------------------------
   A-07 ｜ 开局→开奖时长的桌台异质性  ★ 决定尾段阈值是否必须分层
   --------------------------------------------------------------------------- */
WITH s AS (
  SELECT gi011 AS table_id,
         TIMESTAMPDIFF(SECOND,
           CAST(NULLIF(TRIM(gi004),'') AS DATETIME),
           CAST(NULLIF(TRIM(gi006),'') AS DATETIME)) AS span_sec
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= :dt_from AND dt < :dt_to AND gi001 = :game
    AND gi013 = '1' AND is_lock = 'N'
    AND NULLIF(TRIM(gi004),'') IS NOT NULL
    AND NULLIF(TRIM(gi006),'') IS NOT NULL
)
SELECT table_id,
       COUNT(*)                                AS n_round,
       AVG(span_sec)                           AS mean_sec,
       STDDEV_SAMP(span_sec)                   AS sd_sec,
       PERCENTILE_APPROX(span_sec, 0.05)       AS p05,
       PERCENTILE_APPROX(span_sec, 0.25)       AS p25,
       PERCENTILE_APPROX(span_sec, 0.50)       AS p50,
       PERCENTILE_APPROX(span_sec, 0.75)       AS p75,
       PERCENTILE_APPROX(span_sec, 0.95)       AS p95,
       SUM(CASE WHEN span_sec BETWEEN 29 AND 31 THEN 1 ELSE 0 END) * 1.0
         / COUNT(*)                            AS pct_30s
FROM s
WHERE span_sec > 0 AND span_sec < 600
GROUP BY table_id
HAVING COUNT(*) >= 200
ORDER BY n_round DESC;
/* 判读：
     桌内 sd_sec 小（如 ≤ 8）而桌间 p50 差异大 → **必须按桌分层**
     pct_30s 全局 < 0.9                        → 禁用「第 N 秒」绝对秒表述  */


/* ---------------------------------------------------------------------------
   A-08 ｜ 测试代理线的实际影响面（铁律④b）
   --------------------------------------------------------------------------- */
WITH test_agents AS (
  SELECT DISTINCT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
tagged AS (
  SELECT b.bet05 AS member_id,
         CASE WHEN EXISTS (SELECT 1 FROM test_agents t
              WHERE t.agent_id IN (b.bet18,b.bet19,b.bet20,b.bet21,b.bet22))
              THEN 1 ELSE 0 END AS is_test_line,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) AS stake
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= :dt_from AND b.dt < :dt_to AND b.bet02 = :game
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
)
SELECT is_test_line,
       COUNT(*)                   AS n_orders,
       COUNT(DISTINCT member_id)  AS n_members,
       SUM(stake)                 AS turnover
FROM tagged GROUP BY is_test_line;
/* 判读：is_test_line=1 的会员数与流水占比，即铁律④b 的实际排除量。 */


/* ---------------------------------------------------------------------------
   A-09 ｜ 待定语义表的列注释（SMR_log / game_No / iphistory / betchange_log）
   --------------------------------------------------------------------------- */
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME IN ('ods_a168_SMR_log','ods_a168_game_No','ods_a168_iphistory',
                     'ods_a168_betchange_log','ods_a168_odds_default',
                     'ods_a168_emp_login','ods_a168_ban_bet_area',
                     'ods_a168_tablelimit','ods_a168_dailyreport_member')
ORDER BY TABLE_NAME, ORDINAL_POSITION;


/* ---------------------------------------------------------------------------
   A-10 ｜ dailyreport_member 的 risk 分布（L1a 标签是否可用）
   --------------------------------------------------------------------------- */
SELECT risk,
       COUNT(*)                  AS n_rows,
       COUNT(DISTINCT memberid)  AS n_members,
       MIN(dt) AS dt_min, MAX(dt) AS dt_max
FROM ods_mariadb_2b.ods_a168_dailyreport_member
GROUP BY risk
ORDER BY n_rows DESC;
/* ⚠️ 列名 memberid 待 A-09 确认；若不同请替换。 */


/* ---------------------------------------------------------------------------
   A-11 ｜ member_dtl 最新快照的配置退水率分布（REB 维度标定）
   --------------------------------------------------------------------------- */
SELECT mem002 AS game_cat,
       CAST(NULLIF(TRIM(mem003),'') AS DECIMAL(10,4)) AS rebate_rate,
       COUNT(DISTINCT mem001) AS n_member
FROM (
  SELECT mem001, mem002, mem003,
         ROW_NUMBER() OVER (PARTITION BY mem001, mem002 ORDER BY dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_member_dtl
) x
WHERE rn = 1 AND mem002 = :game
GROUP BY mem002, CAST(NULLIF(TRIM(mem003),'') AS DECIMAL(10,4))
ORDER BY n_member DESC;


/* ---------------------------------------------------------------------------
   A-12 ｜ risklist 与 bet02 的可 join 性（注单级标签）
   --------------------------------------------------------------------------- */
SELECT r.op,
       COUNT(*)                                        AS n_risklist,
       COUNT(b.bet01)                                  AS n_joined,
       COUNT(b.bet01) * 1.0 / COUNT(*)                 AS join_rate,
       MIN(r.optime) AS op_min, MAX(r.optime) AS op_max
FROM ods_mariadb_2b.ods_a168_risklist r
LEFT JOIN (
  SELECT DISTINCT bet01 FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = :game
) b ON b.bet01 = r.bet01
GROUP BY r.op
ORDER BY n_risklist DESC;
/* 判读：join_rate 高 → risklist 是可用的注单级人工标签（路径甲的核心资产）。
        注意本查询不加 dt 过滤，目的是检验全时段可 join 性。          */


/* ---------------------------------------------------------------------------
   A-13 ｜ 铁律④a 断言：bet02='101' 是否蕴含 bet03<>'0'
   --------------------------------------------------------------------------- */
SELECT COUNT(*) AS n_sentinel_in_baccarat
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= :dt_from AND dt < :dt_to AND bet02 = :game AND bet03 = '0';
/* 预期 0。非 0 则铁律④a 不被蕴含，须显式保留该过滤条件。 */


/* ############################################################################
   PART B · 口径落地：基础宽表（供 PART C/D/E 复用）
   —— 建议先物化为临时表，避免每条查询重复全表扫描
   ############################################################################ */


/* ---------------------------------------------------------------------------
   B-01 ｜ 有效订单基础表  →  建议 CREATE TABLE tmp_base AS <本查询>
   --------------------------------------------------------------------------- */
WITH test_agents AS (
  SELECT DISTINCT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
wl_ip AS (
  /* white_list 是「按代理的 IP 白名单」：aid + 逗号分隔 IP，需展开 */
  SELECT DISTINCT TRIM(ip_item) AS ip
  FROM ods_mariadb_2b.ods_a168_white_list,
       unnest(split(white_list, ',')) AS t(ip_item)
  WHERE NULLIF(TRIM(ip_item),'') IS NOT NULL
  /* StarRocks 若不支持 unnest，改用：
     LATERAL VIEW EXPLODE(SPLIT(white_list, ',')) t AS ip_item              */
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= :dt_from AND b.dt < :dt_to AND b.bet02 = :game
),
valid AS (
  SELECT
    r.bet01                                              AS bet_id,
    r.bet05                                              AS member_id,
    CONCAT_WS('|', r.bet03, r.bet04, r.bet39)            AS round_key,
    r.bet03 AS shoe_id, r.bet04 AS round_no, r.bet39 AS table_id,
    r.bet40 AS room_id, r.eid AS dealer_id, r.commission,
    r.bet09 AS bet_side, r.ip AS bet_ip,
    r.bet18 AS lv1, r.bet19 AS lv2, r.bet20 AS lv3,
    r.bet21 AS lv4, r.bet22 AS lv5,
    CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME)           AS t_bet,
    CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))      AS fx,
    CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))      AS stake_raw,
    CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))      AS payout_raw,
    CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))      AS rebate_raw,
    CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))      AS net_raw,
    CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))   AS validbet_raw
  FROM ranked r
  WHERE r.rn = 1
    AND r.category = '1'                                 -- 需求 §3.2 一般单
    AND UPPER(TRIM(r.bet38)) = 'N'                       -- 需求 §3.2 非重对
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM test_agents t          -- 铁律④b
                    WHERE t.agent_id IN (r.bet18,r.bet19,r.bet20,r.bet21,r.bet22))
),
gi AS (
  SELECT gi002 AS shoe_id, gi003 AS round_no, gi011 AS table_id, eid AS gi_dealer,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME) AS t_open,
         CAST(NULLIF(TRIM(gi006),'') AS DATETIME) AS t_reveal,
         gi007 AS outcome
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= :dt_from AND dt < :dt_to AND gi001 = :game
    AND gi013 = '1' AND is_lock = 'N'                    -- ★ 仅已开局
)
SELECT v.bet_id, v.member_id, v.round_key, v.shoe_id, v.round_no, v.table_id,
       v.room_id, v.dealer_id, v.commission, v.bet_side, v.bet_ip,
       v.lv1, v.lv2, v.lv3, v.lv4, v.lv5,
       v.t_bet, g.t_open, g.t_reveal, g.outcome,
       v.stake_raw    / v.fx                       AS stake,        -- 投注金额
       v.validbet_raw / v.fx                       AS valid_bet,    -- 有效投注
       (v.payout_raw - v.stake_raw) / v.fx         AS game_pnl,     -- 游戏盈利（不含返水）
       v.rebate_raw   / v.fx                       AS rebate,       -- 返水
       v.net_raw      / v.fx                       AS net_pnl,      -- 净盈利（含返水）
       TIMESTAMPDIFF(SECOND, g.t_open, v.t_bet)    AS sec_elapsed,
       TIMESTAMPDIFF(SECOND, g.t_open, g.t_reveal) AS round_span,
       TIMESTAMPDIFF(SECOND, g.t_open, v.t_bet) * 1.0
         / NULLIF(TIMESTAMPDIFF(SECOND, g.t_open, g.t_reveal), 0) AS bet_progress
FROM valid v
JOIN gi g ON v.shoe_id = g.shoe_id AND v.round_no = g.round_no
         AND v.table_id = g.table_id
ORDER BY v.member_id, v.t_bet;   -- 铁律⑦：分页导出必带 ORDER BY


/* ---------------------------------------------------------------------------
   B-02 ｜ 玩家×物理局（需求 §3.4 胜率口径：和局不入分母）
   --------------------------------------------------------------------------- */
SELECT member_id, round_key, table_id, dealer_id, commission,
       COUNT(*)                     AS n_orders,
       MIN(t_bet)                   AS first_bet_ts,
       MAX(t_bet)                   AS last_bet_ts,
       MAX(bet_progress)            AS max_progress,   -- 该玩家该局最晚一注的进度
       SUM(stake)                   AS stake,
       SUM(valid_bet)               AS valid_bet,
       SUM(game_pnl)                AS game_pnl,
       SUM(rebate)                  AS rebate,
       SUM(net_pnl)                 AS net_pnl,
       CASE WHEN SUM(game_pnl) > 0 THEN 1 ELSE 0 END AS is_win,
       CASE WHEN SUM(game_pnl) < 0 THEN 1 ELSE 0 END AS is_lose,
       CASE WHEN SUM(game_pnl) = 0 THEN 1 ELSE 0 END AS is_tie
FROM tmp_base
GROUP BY member_id, round_key, table_id, dealer_id, commission
ORDER BY member_id, first_bet_ts;


/* ############################################################################
   PART C · 异常 IP（需求 §4）
   ############################################################################ */


/* ---------------------------------------------------------------------------
   C-01 ｜ 公共网络 IP 识别（需求 §3.2：列出影响后交业务确认）
   --------------------------------------------------------------------------- */
SELECT bet_ip,
       COUNT(DISTINCT member_id)                                   AS n_member,
       COUNT(DISTINCT lv3)                                         AS n_lv3_chain,
       COUNT(DISTINCT member_id) * 1.0
         / NULLIF(COUNT(DISTINCT lv3), 0)                          AS member_per_chain,
       COUNT(*)                                                    AS n_orders,
       SUM(stake)                                                  AS stake,
       SUM(game_pnl)                                               AS game_pnl,
       SUM(net_pnl)                                                AS net_pnl
FROM tmp_base
WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
GROUP BY bet_ip
HAVING COUNT(DISTINCT member_id) >= 20
ORDER BY member_per_chain DESC, n_member DESC;
/* member_per_chain 高  → 会员分散于多条代理链 → 更像公共出口
   member_per_chain ≈ 1 → 会员集中于同一代理链 → 更像团伙
   （这正是 alert_ip_setting 里「信用ISN底下同IP」判据的量化形式）   */


/* ---------------------------------------------------------------------------
   C-02 ｜ 玩家—IP 基础指标（需求 §4.1，六项 + 版本C所需游戏盈利）
   --------------------------------------------------------------------------- */
WITH pl AS (
  SELECT member_id,
         COUNT(DISTINCT bet_id)    AS n_orders_all,
         COUNT(DISTINCT round_key) AS n_rounds_all,
         SUM(net_pnl)              AS net_pnl_all,
         SUM(game_pnl)             AS game_pnl_all
  FROM tmp_base GROUP BY member_id
)
SELECT b.bet_ip, b.member_id,
       COUNT(DISTINCT b.bet_id)                                    AS n_orders_ip,
       COUNT(DISTINCT b.round_key)                                 AS n_rounds_ip,
       SUM(b.stake)                                                AS stake_ip,
       SUM(b.game_pnl)                                             AS game_pnl_ip,
       SUM(b.rebate)                                               AS rebate_ip,
       SUM(b.net_pnl)                                              AS net_pnl_ip,
       MAX(pl.n_orders_all)                                        AS n_orders_all,
       MAX(pl.n_rounds_all)                                        AS n_rounds_all,
       MAX(pl.net_pnl_all)                                         AS net_pnl_all,
       MAX(pl.game_pnl_all)                                        AS game_pnl_all,
       COUNT(DISTINCT b.bet_id) * 1.0
         / NULLIF(MAX(pl.n_orders_all), 0)                         AS ip_order_share
FROM tmp_base b
JOIN pl ON b.member_id = pl.member_id
WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL
GROUP BY b.bet_ip, b.member_id
ORDER BY b.bet_ip, b.member_id;


/* ---------------------------------------------------------------------------
   C-03 ｜ IP 汇总 + 三版本盈利口径（需求 §4.2 + 缺陷D5 补版本C）
          :min_orders 建议先跑 C-04 定值
   --------------------------------------------------------------------------- */
SELECT bet_ip,
       COUNT(DISTINCT member_id)                                             AS n_member_raw,
       SUM(CASE WHEN n_orders_ip >= :min_orders THEN 1 ELSE 0 END)           AS n_member_eff,
       SUM(CASE WHEN n_orders_ip >= :min_orders AND net_pnl_all  > 0 THEN 1 ELSE 0 END) AS n_prof_A,
       SUM(CASE WHEN n_orders_ip >= :min_orders AND net_pnl_ip   > 0 THEN 1 ELSE 0 END) AS n_prof_B,
       SUM(CASE WHEN n_orders_ip >= :min_orders AND game_pnl_ip  > 0 THEN 1 ELSE 0 END) AS n_prof_C,
       SUM(n_orders_ip) AS n_orders, SUM(n_rounds_ip) AS n_rounds,
       SUM(stake_ip) AS stake, SUM(game_pnl_ip) AS game_pnl,
       SUM(rebate_ip) AS rebate, SUM(net_pnl_ip) AS net_pnl,
       PERCENTILE_APPROX(ip_order_share, 0.5)                                AS share_p50,
       PERCENTILE_APPROX(ip_order_share, 0.9)                                AS share_p90
FROM tmp_ip_player
GROUP BY bet_ip
ORDER BY n_member_eff DESC;
/* 版本A 全平台净盈利 / 版本B 该IP下净盈利 / 版本C 该IP下游戏盈利（剔返水）
   B 独有而 C 不命中的 IP，即「返水制造的伪盈利」——缺陷D5 的直接证据。 */


/* ---------------------------------------------------------------------------
   C-04 ｜ 最小订单数敏感度（需求 §2.1-2）
   --------------------------------------------------------------------------- */
WITH thresholds AS (
  SELECT 1 AS m UNION ALL SELECT 5 UNION ALL SELECT 10 UNION ALL SELECT 20
  UNION ALL SELECT 30 UNION ALL SELECT 50 UNION ALL SELECT 100 UNION ALL SELECT 200
),
agg AS (
  SELECT t.m, p.bet_ip,
         COUNT(*)                                       AS n_eff,
         AVG(CASE WHEN p.game_pnl_ip > 0 THEN 1.0 ELSE 0.0 END) AS rate_C
  FROM tmp_ip_player p CROSS JOIN thresholds t
  WHERE p.n_orders_ip >= t.m
  GROUP BY t.m, p.bet_ip
)
SELECT m                                        AS min_orders,
       COUNT(*)                                 AS n_ip,
       SUM(CASE WHEN n_eff >= 5 THEN 1 ELSE 0 END) AS n_ip_eff5,
       AVG(rate_C)                              AS mean_rate_C,
       STDDEV_SAMP(rate_C)                      AS sd_rate_C,
       VARIANCE(rate_C)                         AS var_rate_C
FROM agg GROUP BY m ORDER BY m;
/* 判据：取 var_rate_C 开始平稳的最小订单数。低于该点时「盈利比例」
        主要由抽样噪声驱动，80%/90%/100% 门槛没有区分意义。      */


/* ---------------------------------------------------------------------------
   C-05 ｜ 关联玩家数分布定位（需求 §2.1-1：「20 个账户」在哪）
   --------------------------------------------------------------------------- */
WITH marks AS (
  SELECT 2 AS k UNION ALL SELECT 3 UNION ALL SELECT 5 UNION ALL SELECT 10
  UNION ALL SELECT 20 UNION ALL SELECT 30 UNION ALL SELECT 50 UNION ALL SELECT 100
),
tot AS (SELECT COUNT(*) AS n_ip FROM tmp_ip_agg)
SELECT m.k                                                       AS n_member_threshold,
       SUM(CASE WHEN a.n_member_eff >= m.k THEN 1 ELSE 0 END)     AS n_ip_at_or_above,
       SUM(CASE WHEN a.n_member_eff >= m.k THEN 1 ELSE 0 END) * 1.0
         / MAX(t.n_ip)                                            AS pct_at_or_above,
       1 - SUM(CASE WHEN a.n_member_eff >= m.k THEN 1 ELSE 0 END) * 1.0
         / MAX(t.n_ip)                                            AS ecdf_position
FROM marks m CROSS JOIN tmp_ip_agg a CROSS JOIN tot t
GROUP BY m.k ORDER BY m.k;


/* ---------------------------------------------------------------------------
   C-06 ｜ 同 IP 对押率（人工判据「多會員同IP、對押」的量化）
   --------------------------------------------------------------------------- */
WITH side AS (
  SELECT round_key, bet_ip, member_id,
         SUM(CASE WHEN UPPER(bet_side)='BANKER' THEN stake ELSE 0 END) AS amt_b,
         SUM(CASE WHEN UPPER(bet_side)='PLAYER' THEN stake ELSE 0 END) AS amt_p
  FROM tmp_base
  WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY round_key, bet_ip, member_id
),
pair AS (
  SELECT a.round_key, a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         LEAST(a.amt_b, b.amt_p) + LEAST(a.amt_p, b.amt_b)  AS matched,
         a.amt_b + a.amt_p + b.amt_b + b.amt_p              AS total
  FROM side a JOIN side b
    ON a.round_key = b.round_key AND a.bet_ip = b.bet_ip AND a.member_id < b.member_id
)
SELECT bet_ip, m_a, m_b,
       COUNT(*)                                     AS n_same_round,
       SUM(CASE WHEN matched > 0 THEN 1 ELSE 0 END) AS n_opposite_round,
       SUM(CASE WHEN matched > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS opposite_rate,
       SUM(2 * matched) / NULLIF(SUM(total), 0)     AS hedge_coverage
FROM pair
GROUP BY bet_ip, m_a, m_b
HAVING COUNT(*) >= 10
ORDER BY hedge_coverage DESC, n_same_round DESC;


/* ---------------------------------------------------------------------------
   C-07 ｜ 同 IP 投注选项一致率（人工判据「幾個相同玩法投注會員使用IP」）
   --------------------------------------------------------------------------- */
WITH prof AS (
  SELECT bet_ip, member_id, bet_side, SUM(stake) AS amt
  FROM tmp_base
  WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY bet_ip, member_id, bet_side
),
norm AS (
  SELECT p.*, SUM(amt) OVER (PARTITION BY bet_ip, member_id) AS amt_total
  FROM prof p
),
dotp AS (
  SELECT a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         SUM((a.amt/a.amt_total) * (b.amt/b.amt_total)) AS dot
  FROM norm a JOIN norm b
    ON a.bet_ip = b.bet_ip AND a.bet_side = b.bet_side AND a.member_id < b.member_id
  GROUP BY a.bet_ip, a.member_id, b.member_id
),
nrm AS (
  SELECT bet_ip, member_id, SQRT(SUM(POW(amt/amt_total, 2))) AS l2
  FROM norm GROUP BY bet_ip, member_id
)
SELECT d.bet_ip, d.m_a, d.m_b,
       d.dot / NULLIF(na.l2 * nb.l2, 0) AS cosine_similarity
FROM dotp d
JOIN nrm na ON na.bet_ip = d.bet_ip AND na.member_id = d.m_a
JOIN nrm nb ON nb.bet_ip = d.bet_ip AND nb.member_id = d.m_b
WHERE d.dot / NULLIF(na.l2 * nb.l2, 0) >= 0.8
ORDER BY cosine_similarity DESC;


/* ---------------------------------------------------------------------------
   C-08 ｜ /24 网段聚集（alert_ip_setting 已提供业务侧背书）
   --------------------------------------------------------------------------- */
SELECT CONCAT(SPLIT_PART(bet_ip,'.',1),'.',SPLIT_PART(bet_ip,'.',2),'.',
              SPLIT_PART(bet_ip,'.',3),'.0/24')                AS subnet_24,
       COUNT(DISTINCT bet_ip)                                  AS n_ip,
       COUNT(DISTINCT member_id)                               AS n_member,
       COUNT(DISTINCT lv3)                                     AS n_lv3_chain,
       COUNT(*)                                                AS n_orders,
       SUM(stake)                                              AS stake,
       SUM(game_pnl)                                           AS game_pnl,
       SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)               AS roi
FROM tmp_base
WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT member_id) >= 5
ORDER BY n_member DESC;


/* ---------------------------------------------------------------------------
   C-09 ｜ L0 金标准命中检验（17 个人工确认 IP，一票否决）
   --------------------------------------------------------------------------- */
SELECT a.ip, a.remarks, a.creator, a.addtime,
       COALESCE(s.n_member, 0)  AS n_member_now,
       COALESCE(s.n_orders, 0)  AS n_orders_now,
       COALESCE(s.game_pnl, 0)  AS game_pnl_now
FROM ods_mariadb_2b.ods_a168_alert_ip_setting a
LEFT JOIN (
  SELECT bet_ip, COUNT(DISTINCT member_id) n_member,
         COUNT(*) n_orders, SUM(game_pnl) game_pnl
  FROM tmp_base GROUP BY bet_ip
) s ON s.bet_ip = a.ip
ORDER BY n_member_now DESC;
/* 新阈值若连这 17 个中仍活跃者都命中不了 → 直接判不合格。
   注意：部分 IP 标注于 2022，当前窗口可能已无活动，属正常。   */


/* ############################################################################
   PART D · 尾段下注（需求 §5）
   —— 全部按桌台分层；禁用「第 N 秒」全局绝对秒表述（A-07 已证）
   ############################################################################ */


/* ---------------------------------------------------------------------------
   D-01 ｜ 下注进度分布（按桌台，需求 §5.2）
   --------------------------------------------------------------------------- */
SELECT table_id,
       FLOOR(bet_progress * 20) AS progress_bin_20,        -- 5% 一档
       COUNT(*)                                  AS n_orders,
       COUNT(DISTINCT member_id)                 AS n_players,
       COUNT(DISTINCT round_key)                 AS n_rounds,
       SUM(stake)                                AS stake,
       SUM(valid_bet)                            AS valid_bet,
       SUM(game_pnl)                             AS game_pnl,
       SUM(rebate)                               AS rebate,
       SUM(game_pnl) / NULLIF(SUM(valid_bet), 0) AS roi
FROM tmp_base
WHERE bet_progress BETWEEN 0 AND 1
GROUP BY table_id, FLOOR(bet_progress * 20)
ORDER BY table_id, progress_bin_20;


/* ---------------------------------------------------------------------------
   D-02 ｜ 按投注选项分层（需求 §5.2：Banker/Player/Tie/边注不可混合胜率）
   --------------------------------------------------------------------------- */
SELECT bet_side, commission,
       FLOOR(bet_progress * 10) AS progress_bin_10,
       COUNT(*)                                  AS n_orders,
       COUNT(DISTINCT member_id)                 AS n_players,
       SUM(stake)                                AS stake,
       SUM(game_pnl)                             AS game_pnl,
       SUM(game_pnl) / NULLIF(SUM(valid_bet), 0) AS roi
FROM tmp_base
WHERE bet_progress BETWEEN 0 AND 1
GROUP BY bet_side, commission, FLOOR(bet_progress * 10)
ORDER BY bet_side, commission, progress_bin_10;


/* ---------------------------------------------------------------------------
   D-03 ｜ 局内匹配检验（需求 §2.2-4 第 ④ 重，最接近因果的证据）
          :q = 尾段进度阈值，建议先跑 D-01 定值（如 0.9）
   --------------------------------------------------------------------------- */
WITH cell AS (
  SELECT round_key, bet_side,
    SUM(CASE WHEN bet_progress >= :q THEN game_pnl  ELSE 0 END) AS pnl_tail,
    SUM(CASE WHEN bet_progress >= :q THEN valid_bet ELSE 0 END) AS vb_tail,
    SUM(CASE WHEN bet_progress <  :q THEN game_pnl  ELSE 0 END) AS pnl_norm,
    SUM(CASE WHEN bet_progress <  :q THEN valid_bet ELSE 0 END) AS vb_norm,
    COUNT(DISTINCT CASE WHEN bet_progress >= :q THEN member_id END) AS n_tail,
    COUNT(DISTINCT CASE WHEN bet_progress <  :q THEN member_id END) AS n_norm
  FROM tmp_base
  WHERE bet_progress BETWEEN 0 AND 1
  GROUP BY round_key, bet_side
)
SELECT COUNT(*)                                       AS n_matched_cells,
       SUM(vb_tail)                                   AS vb_tail_total,
       SUM(vb_norm)                                   AS vb_norm_total,
       SUM(pnl_tail) / NULLIF(SUM(vb_tail), 0)        AS roi_tail,
       SUM(pnl_norm) / NULLIF(SUM(vb_norm), 0)        AS roi_norm,
       SUM(pnl_tail) / NULLIF(SUM(vb_tail), 0)
         - SUM(pnl_norm) / NULLIF(SUM(vb_norm), 0)    AS roi_diff
FROM cell
WHERE n_tail > 0 AND n_norm > 0;   -- 仅保留同局同选项两侧都有人的样本
/* ⚠️ 若 roi_diff 不显著，报告必须照实写「尾段下注在本数据下未观察到
      统计显著的优势」，即使这削弱项目叙事。这是方案能否站住的分水岭。 */


/* ---------------------------------------------------------------------------
   D-04 ｜ 在线人数基准率校正（需求 §2.2-4 第 ③ 重）
   --------------------------------------------------------------------------- */
WITH bet_min AS (
  SELECT table_id, DATE_TRUNC('minute', t_bet) AS ts_min,
         COUNT(DISTINCT member_id) AS n_betting,
         SUM(CASE WHEN bet_progress >= :q THEN 1 ELSE 0 END) AS n_tail_orders,
         COUNT(*) AS n_orders
  FROM tmp_base WHERE bet_progress BETWEEN 0 AND 1
  GROUP BY table_id, DATE_TRUNC('minute', t_bet)
),
online AS (
  SELECT t_number AS table_id, DATE_TRUNC('minute',
           CAST(NULLIF(TRIM(time),'') AS DATETIME)) AS ts_min,
         MAX(CAST(NULLIF(TRIM(people),'') AS INT))  AS n_online
  FROM ods_mariadb_2b.ods_a168_game_statistics
  WHERE dt >= :dt_from AND dt < :dt_to AND gid = :game
  GROUP BY t_number, DATE_TRUNC('minute', CAST(NULLIF(TRIM(time),'') AS DATETIME))
)
SELECT b.table_id, b.ts_min, b.n_betting, o.n_online,
       b.n_betting * 1.0 / NULLIF(o.n_online, 0)   AS bet_participation,
       b.n_tail_orders * 1.0 / NULLIF(b.n_orders, 0) AS tail_order_share
FROM bet_min b LEFT JOIN online o
  ON b.table_id = o.table_id AND b.ts_min = o.ts_min
ORDER BY b.table_id, b.ts_min;
/* 这才是基准率谬误的正确解法：分母用在线人数，而非订单占比。 */


/* ---------------------------------------------------------------------------
   D-05 ｜ 玩家尾段指标（需求 §5.3，十一项；进度阈值按桌台分层）
   --------------------------------------------------------------------------- */
WITH qt AS (   -- ★ 按桌台取进度阈值，而非全局
  SELECT table_id, PERCENTILE_APPROX(max_progress, :q) AS thr
  FROM tmp_player_round GROUP BY table_id
),
flg AS (
  SELECT p.*, CASE WHEN p.max_progress >= q.thr THEN 1 ELSE 0 END AS is_tail
  FROM tmp_player_round p JOIN qt q ON p.table_id = q.table_id
)
SELECT member_id,
  COUNT(*)                                                          AS n_rounds_all,
  SUM(is_tail)                                                      AS n_rounds_tail,
  SUM(is_tail) * 1.0 / COUNT(*)                                     AS tail_share,
  SUM(is_tail * is_win)  AS tail_win,
  SUM(is_tail * is_lose) AS tail_lose,
  SUM(is_tail * is_tie)  AS tail_tie,
  SUM(is_tail * is_win) * 1.0
    / NULLIF(SUM(is_tail*is_win) + SUM(is_tail*is_lose), 0)         AS tail_winrate,
  SUM((1-is_tail) * is_win) * 1.0
    / NULLIF(SUM((1-is_tail)*is_win) + SUM((1-is_tail)*is_lose), 0) AS norm_winrate,
  SUM(is_tail * is_win) * 1.0
    / NULLIF(SUM(is_tail*is_win) + SUM(is_tail*is_lose), 0)
    - SUM((1-is_tail) * is_win) * 1.0
    / NULLIF(SUM((1-is_tail)*is_win) + SUM((1-is_tail)*is_lose), 0) AS winrate_diff,
  SUM(is_tail * stake)     AS tail_stake,
  SUM(is_tail * valid_bet) AS tail_valid_bet,
  SUM(is_tail * game_pnl)  AS tail_game_pnl,
  SUM(is_tail * rebate)    AS tail_rebate,
  SUM(is_tail * net_pnl)   AS tail_net_pnl,
  SUM(is_tail * game_pnl) / NULLIF(SUM(is_tail * valid_bet), 0)     AS tail_roi,
  SUM((1-is_tail) * game_pnl)                                       AS norm_game_pnl,
  SUM((1-is_tail) * game_pnl)
    / NULLIF(SUM((1-is_tail) * valid_bet), 0)                       AS norm_roi,
  SUM(CASE WHEN is_tail=1 AND game_pnl>0 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN game_pnl>0 THEN game_pnl ELSE 0 END), 0) AS tail_profit_share
FROM flg
GROUP BY member_id
ORDER BY member_id;


/* ---------------------------------------------------------------------------
   D-06 ｜ 极端订单主导性诊断（需求 §5.4 末项）
   --------------------------------------------------------------------------- */
WITH pos AS (
  SELECT member_id, bet_id, game_pnl,
         ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY game_pnl DESC) AS rk,
         SUM(game_pnl) OVER (PARTITION BY member_id) AS total_pos
  FROM tmp_base WHERE game_pnl > 0
)
SELECT member_id,
       MAX(total_pos)                                                AS total_positive,
       SUM(CASE WHEN rk = 1 THEN game_pnl ELSE 0 END)
         / NULLIF(MAX(total_pos), 0)                                 AS top1_share,
       SUM(CASE WHEN rk <= 5 THEN game_pnl ELSE 0 END)
         / NULLIF(MAX(total_pos), 0)                                 AS top5_share,
       SUM(CASE WHEN rk <= 10 THEN game_pnl ELSE 0 END)
         / NULLIF(MAX(total_pos), 0)                                 AS top10_share,
       MAX(total_pos) - SUM(CASE WHEN rk = 1 THEN game_pnl ELSE 0 END) AS pos_excl_top1
FROM pos GROUP BY member_id
HAVING MAX(total_pos) > 0
ORDER BY top1_share DESC;
/* top1_share > 0.5 → 单笔主导，该玩家的阈值命中不可靠。 */


/* ############################################################################
   PART E · 组合分析（需求 §6）
   ############################################################################ */


/* ---------------------------------------------------------------------------
   E-01 ｜ 异常 IP × 尾段风险玩家 交集 + 同步时间差
   --------------------------------------------------------------------------- */
WITH tail_in_round AS (
  SELECT b.round_key, b.bet_ip, b.member_id,
         MIN(b.t_bet) AS t_first, MAX(b.bet_progress) AS prog
  FROM tmp_base b
  WHERE b.bet_progress >= :q AND NULLIF(TRIM(b.bet_ip),'') IS NOT NULL
    AND b.member_id IN (SELECT member_id FROM tmp_tail_candidates)
  GROUP BY b.round_key, b.bet_ip, b.member_id
),
pair AS (
  SELECT a.round_key, a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         ABS(TIMESTAMPDIFF(SECOND, a.t_first, b.t_first)) AS sec_gap
  FROM tail_in_round a JOIN tail_in_round b
    ON a.round_key = b.round_key AND a.bet_ip = b.bet_ip AND a.member_id < b.member_id
)
SELECT bet_ip,
       COUNT(DISTINCT round_key)                        AS n_common_tail_rounds,
       COUNT(*)                                         AS n_pair_events,
       COUNT(DISTINCT m_a) + COUNT(DISTINCT m_b)        AS n_member_involved,
       PERCENTILE_APPROX(sec_gap, 0.5)                  AS med_sec_gap,
       PERCENTILE_APPROX(sec_gap, 0.9)                  AS p90_sec_gap,
       SUM(CASE WHEN sec_gap <= 2 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_within_2s
FROM pair
GROUP BY bet_ip
ORDER BY n_common_tail_rounds DESC;
/* med_sec_gap < 2 秒 → 强协同证据，应单列最高优先级组合规则。 */


/* ############################################################################
   PART F · 面板与回测底座
   ############################################################################ */


/* ---------------------------------------------------------------------------
   F-01 ｜ 会员×月 面板（跨月稳定性，需求 §2.1-6 / §2.2-8）
   --------------------------------------------------------------------------- */
SELECT member_id,
       DATE_FORMAT(first_bet_ts, '%Y-%m')               AS ym,
       COUNT(*)                                         AS n_rounds,
       SUM(is_win)  AS n_win, SUM(is_lose) AS n_lose, SUM(is_tie) AS n_tie,
       SUM(is_win) * 1.0 / NULLIF(SUM(is_win)+SUM(is_lose), 0) AS winrate,
       SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,
       SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
       SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)        AS roi
FROM tmp_player_round
GROUP BY member_id, DATE_FORMAT(first_bet_ts, '%Y-%m')
ORDER BY member_id, ym;


/* ---------------------------------------------------------------------------
   F-02 ｜ 会员×周 面板（purged walk-forward 底座；t0/t1 为净化两根锚）
   --------------------------------------------------------------------------- */
SELECT member_id,
       DATE_TRUNC('week', first_bet_ts)                 AS week_start,
       COUNT(*)                                         AS n_rounds,
       SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,
       SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
       SUM(CASE WHEN net_pnl < 0 THEN -net_pnl ELSE 0 END) AS gross_loss,
       COUNT(DISTINCT table_id)  AS n_tables,
       COUNT(DISTINCT dealer_id) AS n_dealers,
       MIN(first_bet_ts)                                AS t0,   -- ★ 特征起点
       MAX(last_bet_ts)                                 AS t1    -- ★ 标签实现时刻
FROM tmp_player_round
GROUP BY member_id, DATE_TRUNC('week', first_bet_ts)
ORDER BY member_id, week_start;   -- 铁律⑦
/* t1 必须用业务时间，禁用 sync_time（ODS 同步滞后约两个月，会制造伪未来信息）。 */


/* ---------------------------------------------------------------------------
   F-03 ｜ 标签实现滞后分布（★ embargo 天数的经验依据，不照抄文献 21 天）
   --------------------------------------------------------------------------- */
SELECT COUNT(*)                                            AS n,
       AVG(TIMESTAMPDIFF(SECOND, t0, t1) / 86400.0)        AS mean_lag_days,
       PERCENTILE_APPROX(TIMESTAMPDIFF(SECOND,t0,t1)/86400.0, 0.50) AS p50,
       PERCENTILE_APPROX(TIMESTAMPDIFF(SECOND,t0,t1)/86400.0, 0.90) AS p90,
       PERCENTILE_APPROX(TIMESTAMPDIFF(SECOND,t0,t1)/86400.0, 0.95) AS p95,
       PERCENTILE_APPROX(TIMESTAMPDIFF(SECOND,t0,t1)/86400.0, 0.99) AS p99,
       MAX(TIMESTAMPDIFF(SECOND, t0, t1) / 86400.0)        AS max_lag_days
FROM tmp_weekly_panel;
/* embargo_days := CEIL(p95)。这是 purged walk-forward 唯一正当的取值方式。 */


/* ---------------------------------------------------------------------------
   F-04 ｜ 荷官×日 面板（贝叶斯分层输入；n_bets 为必需权重列）
   --------------------------------------------------------------------------- */
SELECT dealer_id, DATE(first_bet_ts) AS bet_date, table_id,
       COUNT(*)                                         AS n_rounds,
       COUNT(DISTINCT member_id)                        AS n_members,
       SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,
       SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,
       SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)        AS player_roi,
       SUM(is_win) * 1.0 / NULLIF(SUM(is_win)+SUM(is_lose), 0) AS player_winrate
FROM tmp_player_round
WHERE NULLIF(TRIM(dealer_id),'') IS NOT NULL AND dealer_id <> '-1'
GROUP BY dealer_id, DATE(first_bet_ts), table_id
HAVING COUNT(*) >= 10
ORDER BY dealer_id, bet_date;
/* eid = '-1' 占比约 34%（E2 观察），须在报告中声明荷官维度覆盖率局限。 */


/* ============================================================================
   执行顺序与物化建议
   ----------------------------------------------------------------------------
   Step 1  PART A 全部（12 条）—— 决定标签策略与分层方案，**必须先跑**
   Step 2  B-01 → CREATE TABLE tmp_base AS <B-01>
   Step 3  B-02 → CREATE TABLE tmp_player_round AS <B-02>
   Step 4  C-02 → CREATE TABLE tmp_ip_player AS <C-02>
           C-03 → CREATE TABLE tmp_ip_agg AS <C-03>
   Step 5  D-05 → CREATE TABLE tmp_player_tail AS <D-05>
           据此筛出 tmp_tail_candidates 供 E-01 使用
   Step 6  F-01/F-02/F-04 面板，F-03 定 embargo
   ----------------------------------------------------------------------------
   导出注意
     · 每条导出 CSV 必带 ORDER BY（铁律⑦），否则分页无序会制造重复行
     · 导出编码 UTF-8 BOM，避免中文列名乱码
     · 大表导出前先 CREATE TABLE 物化，勿在 Superset 直接跑复杂 CTE
   ============================================================================ */
