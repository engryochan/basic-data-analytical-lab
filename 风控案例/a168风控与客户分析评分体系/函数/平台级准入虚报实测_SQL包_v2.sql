-- ═══════════════════════════════════════════════════════════════════════════
-- 平台级准入虚报实测 SQL 包 v2 增补（2026-08-19）
-- 目的：实测既有红队漏洞（历史编第二十八章 R01-V01/V02，另 V01 之判据误判）
--       与能力缺口（晚段/早段 ROI、下注额斜率、全体 P&L）。
-- 纪律：同 v1——行注释、禁 OFFSET、CAST BIGINT、窗口用 dt、只读、逐条独立导出。
-- 共同底集：rn=1 ∧ category='1' ∧ bet38='N' ∧ 数值守门 ∧ 非测试线（= P02 非测试线）。
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- P04 · 判据误判矩阵（V01 之现行判据版）：bet04>=40（绝对局号） × 相对靴位>=0.80
-- 口径锁：shoe_len_def = 'MAX(round_no) 观测口径'——非真实靴长（V01 限界照登），
--         故本矩阵测的是「绝对判据 相对 观测相对判据」之互判差，真实靴长待权威表。
-- 读法：2_绝对是相对否 与 3_绝对否相对是 两桶即两判据互判之误判量
--       （行数 · 会员数 · 本金 · 盈亏 及占比）。
-- 导出：存为「数据库/P04_判据误判矩阵.csv」
-- ─────────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'
),
ranked AS (
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
           b.bet38, b.bet39, b.category,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
      AND b.bet02 = '101'
),
clean AS (
    SELECT r.bet03 AS shoe_id, r.bet39 AS table_id,
           CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)          AS pid,
           CAST(NULLIF(TRIM(r.bet04),'') AS INT)             AS rno,
           CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))   AS fx,
           CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))   AS stake_raw,
           CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))   AS payout_raw
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
    WHERE r.rn = 1
      AND r.category = '1'
      AND UPPER(TRIM(COALESCE(r.bet38,''))) = 'N'
      AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
      AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
      AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
      AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
shoe_len AS (
    SELECT shoe_id, table_id, MAX(rno) AS max_round
    FROM clean
    GROUP BY shoe_id, table_id
),
cells AS (
    SELECT CASE
             WHEN c.rno >= 40
              AND c.rno * 1.0 / NULLIF(s.max_round, 0) >= 0.80 THEN '1_绝对是相对是'
             WHEN c.rno >= 40                                   THEN '2_绝对是相对否'
             WHEN c.rno * 1.0 / NULLIF(s.max_round, 0) >= 0.80 THEN '3_绝对否相对是'
             ELSE                                                    '4_绝对否相对否'
           END AS cell,
           c.pid, c.stake_raw / c.fx AS stake,
           (c.payout_raw - c.stake_raw) / c.fx AS pnl
    FROM clean c
    JOIN shoe_len s ON s.shoe_id = c.shoe_id AND s.table_id = c.table_id
),
agg AS (
    SELECT cell,
           COUNT(*)              AS n_rows,
           COUNT(DISTINCT pid)   AS n_members,
           SUM(stake)            AS stake_sum,
           SUM(pnl)              AS pnl_sum
    FROM cells
    GROUP BY cell
)
SELECT
    'abs=bet04>=40 vs rel=rno/MAX(round_no)>=0.80'        AS matrix_def,   -- 口径锁
    'MAX(round_no) 观测口径（非真实靴长，V01 限界）'       AS shoe_len_def, -- 口径锁
    cell,
    n_rows,
    ROUND(n_rows * 100.0 / SUM(n_rows) OVER (), 4)        AS rows_pct,
    n_members,
    ROUND(stake_sum, 2)                                   AS stake_sum,
    ROUND(stake_sum * 100.0
          / NULLIF(SUM(stake_sum) OVER (), 0), 4)         AS stake_pct,
    ROUND(pnl_sum, 2)                                     AS pnl_sum,
    ROUND(pnl_sum * 100.0
          / NULLIF(SUM(pnl_sum) OVER (), 0), 4)           AS pnl_pct       -- 盈亏可负，占比仅供参照
FROM agg
ORDER BY cell;


-- ─────────────────────────────────────────────────────────────────────────────
-- P05 · 会员级晚早段扩展（补四项能力缺口：晚段 ROI · 早段 ROI · 下注额斜率 · 全体 P&L）
-- 判据锁：late_def = 'bet04>=40'（与甲版双档同一，不引入相对靴位以免口径混杂）。
-- 阈值：仅施 HAVING >= 30 控档量；late_ratio 不筛（留对照组，筛选在 R 侧）。
-- 导出：存为「数据库/P05_会员级晚早段扩展.csv」
-- ─────────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'
),
ranked AS (
    SELECT b.bet01, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
           b.bet38, b.category, b.validbet,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
      AND b.bet02 = '101'
),
clean AS (
    SELECT CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)          AS pid,
           CAST(NULLIF(TRIM(r.bet04),'') AS INT)             AS rno,
           CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))   AS fx,
           CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))   AS stake_raw,
           CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))   AS payout_raw,
           CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
    WHERE r.rn = 1
      AND r.category = '1'
      AND UPPER(TRIM(COALESCE(r.bet38,''))) = 'N'
      AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
      AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
      AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
      AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
)
SELECT
    'bet04>=40' AS late_def,                              -- 口径锁
    'M2A+ext'   AS intake_ver,                            -- 准入版本锁（M2A 底集之扩展）
    pid         AS player_id,
    COUNT(*)                                              AS total_orders,
    SUM(CASE WHEN rno >= 40 THEN 1 ELSE 0 END)            AS late_orders,
    ROUND(SUM(CASE WHEN rno >= 40 THEN 1 ELSE 0 END) * 1.0
          / COUNT(*), 4)                                  AS late_ratio,
    ROUND(SUM(CASE WHEN rno >= 40 THEN stake_raw / fx END), 2)         AS stake_late,
    ROUND(SUM(CASE WHEN rno <  40 THEN stake_raw / fx END), 2)         AS stake_early,
    ROUND(SUM(CASE WHEN rno >= 40 THEN (payout_raw - stake_raw) / fx END), 2)
                                                          AS pnl_late,
    ROUND(SUM(CASE WHEN rno <  40 THEN (payout_raw - stake_raw) / fx END), 2)
                                                          AS pnl_early,
    ROUND(SUM(CASE WHEN rno >= 40 THEN (payout_raw - stake_raw) / fx END)
          / NULLIF(SUM(CASE WHEN rno >= 40 THEN stake_raw / fx END), 0), 4)
                                                          AS roi_late,     -- 晚段 ROI
    ROUND(SUM(CASE WHEN rno <  40 THEN (payout_raw - stake_raw) / fx END)
          / NULLIF(SUM(CASE WHEN rno <  40 THEN stake_raw / fx END), 0), 4)
                                                          AS roi_early,    -- 早段 ROI
    ROUND((SUM(CASE WHEN rno >= 40 THEN stake_raw / fx END)
           / NULLIF(SUM(CASE WHEN rno >= 40 THEN 1 ELSE 0 END), 0))
          / NULLIF(SUM(CASE WHEN rno < 40 THEN stake_raw / fx END)
                   / NULLIF(SUM(CASE WHEN rno < 40 THEN 1 ELSE 0 END), 0), 0), 4)
                                                          AS stake_ramp,   -- 下注额斜率
    ROUND(SUM(stake_raw / fx), 2)                         AS stake_all,
    ROUND(SUM(vb_raw / fx), 2)                            AS valid_bet,
    ROUND(SUM((payout_raw - stake_raw) / fx), 2)          AS pnl_all       -- 全体 P&L
FROM clean
GROUP BY pid
HAVING COUNT(*) >= 30
ORDER BY player_id;


-- ─────────────────────────────────────────────────────────────────────────────
-- P06 · 观测靴长剖面（V01 之分母可信度）：MAX(round_no) 分布与可疑靴之体量
-- 读法：可疑靴（观测靴长 < 30 或 > 70）内之注单行数、本金、会员数及占比，
--       即相对判据分母不可信部分之体量上限。
-- 导出：存为「数据库/P06_观测靴长剖面.csv」
-- ─────────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'
),
ranked AS (
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13,
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
           b.bet38, b.bet39, b.category,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
      AND b.bet02 = '101'
),
clean AS (
    SELECT r.bet03 AS shoe_id, r.bet39 AS table_id,
           CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)          AS pid,
           CAST(NULLIF(TRIM(r.bet04),'') AS INT)             AS rno,
           CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
             / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)), 0) AS stake
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
    WHERE r.rn = 1
      AND r.category = '1'
      AND UPPER(TRIM(COALESCE(r.bet38,''))) = 'N'
      AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
      AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
      AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
      AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
shoe_len AS (
    SELECT shoe_id, table_id, MAX(rno) AS max_round
    FROM clean
    GROUP BY shoe_id, table_id
),
tagged AS (
    SELECT c.pid, c.stake,
           CASE
             WHEN s.max_round < 30                       THEN '1_可疑短靴(<30)'
             WHEN s.max_round > 70                       THEN '3_可疑长靴(>70)'
             ELSE                                             '2_常态靴(30~70)'
           END AS shoe_band,
           s.max_round
    FROM clean c
    JOIN shoe_len s ON s.shoe_id = c.shoe_id AND s.table_id = c.table_id
)
SELECT
    'MAX(round_no) 观测口径'                              AS shoe_len_def,  -- 口径锁
    shoe_band,
    COUNT(DISTINCT max_round)                             AS n_len_values,
    MIN(max_round)                                        AS len_min,
    MAX(max_round)                                        AS len_max,
    COUNT(*)                                              AS n_rows,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 4)    AS rows_pct,
    COUNT(DISTINCT pid)                                   AS n_members,
    ROUND(SUM(stake), 2)                                  AS stake_sum,
    ROUND(SUM(stake) * 100.0
          / NULLIF(SUM(SUM(stake)) OVER (), 0), 4)        AS stake_pct
FROM tagged
GROUP BY shoe_band
ORDER BY shoe_band;


-- ─────────────────────────────────────────────────────────────────────────────
-- P07 · 数据血统对帐（V02）：两个表名是否同一物理数据
-- 用法：两条各自执行；若第二条（无库名）在 SQL Lab 报「表不存在」，
--       即证初版模型一之 FROM ods_a168_bet02 依赖默认库解析——本身即血统风险，照登。
-- 导出：两条各存为「数据库/P07a_血统_全限定名.csv」「数据库/P07b_血统_裸表名.csv」
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    'ods_mariadb_2b.ods_a168_bet02'                       AS lineage_src,   -- 口径锁
    COUNT(*)                                              AS n_rows,
    COUNT(DISTINCT bet01)                                 AS n_bet01,
    SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))    AS stake_raw_sum  -- 原币未归一，仅作指纹
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101';

SELECT
    'ods_a168_bet02（裸表名，依默认库解析）'               AS lineage_src,   -- 口径锁
    COUNT(*)                                              AS n_rows,
    COUNT(DISTINCT bet01)                                 AS n_bet01,
    SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))    AS stake_raw_sum  -- 原币未归一，仅作指纹
FROM ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101';
