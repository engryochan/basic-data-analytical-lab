-- ═══════════════════════════════════════════════════════════════════════════
-- 平台级准入虚报实测 SQL 包 v1（2026-08-19）
-- 目的：查证整个平台（百家乐 bet02='101'、窗口 2026-03-21 ~ 2026-08-07）之
--       整体 / 测试线 / 非测试线剖面，量化四项准入缺失（同单号去重、一般单、
--       重对单、测试线）在 总投注额 · 总会员数 · 总盈亏 上的虚报与误判数目。
-- 纪律：行注释（禁块注释）；ID 比较一律 CAST BIGINT；窗口一律 dt 分区字段
--       （禁 DATE(bet08)）；禁 OFFSET；只读；每条独立执行、独立导出。
-- 口径锁：gate_order = '数值守门>去重>一般单>重对单>测试线'（瀑布归因随次序而变，
--         次序即口径，随行输出）；金额三项皆除 bet11 归一原币。
-- 定位：工作查证包，不入三档权威。占比列仅为 Superset 现场目验之便，
--       报告侧仍须由原始和数现算复核（铁律第九条）。
-- 提示：若需全平台全玩法口径，删去各条中 bet02='101' 一行即可（口径锁随之改写）。
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- P00 · 测试线代理普查（锚定基数）
-- 预期锚：既有锁定结论为窗口内测试代理 214 条、第 215 条建于窗口收束之后；
--         本条现算总数以对帐，不合即先查代理表再谈虚报。
-- 导出：存为「数据库/P00_测试代理普查.csv」
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    'age022=1'                                        AS test_def,        -- 口径锁
    COUNT(*)                                          AS n_agents_all,    -- 代理总数
    SUM(CASE WHEN age022 = '1' THEN 1 ELSE 0 END)     AS n_agents_test    -- 测试代理数
FROM ods_mariadb_2b.ods_a168_agent;


-- ─────────────────────────────────────────────────────────────────────────────
-- P01 · 四项准入之瀑布分桶（行数 · 会员数 · 本金 · 洗码 · 盈亏）
-- 每一注单行按「首个不过之闸」归入唯一一桶：
--   1_数值守门   会员号/局号/汇率不可铸或 <=0（此桶金额列或不可算，以可铸子集计）
--   2_重复版本   同 bet01 非最新版本（ROW_NUMBER 三级排序 rn > 1）
--   3_非一般单   category <> '1'（小费单等）
--   4_重对单     UPPER(TRIM(bet38)) <> 'N'
--   5_测试线     五级代理任一命中 age022='1'
--   0_通过       全闸通过（= M2A 准入之全平台底集，未施行为阈值）
-- 行数与金额跨桶互斥可加；会员数跨桶可重叠不可加（会员级判定见 P03）。
-- 虚报读法：桶 1~5 之和 = 初版口径相对洁净口径之全部虚报；占比列以窗口总量为分母。
-- 导出：存为「数据库/P01_准入消融瀑布.csv」
-- ─────────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'                                -- 铁律④b：公司测试线
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
flagged AS (
    SELECT r.*,
           CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)         AS pid,
           CAST(NULLIF(TRIM(r.bet04),'') AS INT)            AS rno,
           CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))  AS fx,
           CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))  AS stake_raw,
           CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))  AS payout_raw,
           CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw,
           CASE WHEN t1.agent_id IS NOT NULL OR t2.agent_id IS NOT NULL
                  OR t3.agent_id IS NOT NULL OR t4.agent_id IS NOT NULL
                  OR t5.agent_id IS NOT NULL THEN 1 ELSE 0 END AS is_test
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18   -- StarRocks 无 EXISTS 多列 IN
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
),
staged AS (
    SELECT f.*,
           CASE
             WHEN f.pid IS NULL OR f.pid <= 0
               OR f.rno IS NULL OR f.rno <= 0
               OR f.fx  IS NULL OR f.fx  <= 0            THEN '1_数值守门'
             WHEN f.rn > 1                               THEN '2_重复版本'
             WHEN f.category <> '1' OR f.category IS NULL THEN '3_非一般单'
             WHEN UPPER(TRIM(COALESCE(f.bet38,''))) <> 'N' THEN '4_重对单'
             WHEN f.is_test = 1                          THEN '5_测试线'
             ELSE '0_通过'
           END AS gate_stage
    FROM flagged f
),
agg AS (
    SELECT gate_stage,
           COUNT(*)                                        AS n_rows,       -- 注单行数（可加）
           COUNT(DISTINCT pid)                             AS n_members,    -- 会员数（不可加）
           SUM(stake_raw / NULLIF(fx, 0))                  AS stake_sum,    -- 总本金（归一）
           SUM(vb_raw    / NULLIF(fx, 0))                  AS validbet_sum, -- 总洗码（归一）
           SUM((payout_raw - stake_raw) / NULLIF(fx, 0))   AS pnl_sum       -- 总盈亏（归一）
    FROM staged
    GROUP BY gate_stage
)
SELECT
    '数值守门>去重>一般单>重对单>测试线'                  AS gate_order,   -- 口径锁
    gate_stage,
    n_rows,
    ROUND(n_rows * 100.0 / SUM(n_rows) OVER (), 4)         AS rows_pct,     -- 占窗口总行数
    n_members,
    ROUND(stake_sum, 2)                                    AS stake_sum,
    ROUND(stake_sum * 100.0
          / NULLIF(SUM(stake_sum) OVER (), 0), 4)          AS stake_pct,    -- 占窗口总本金
    ROUND(validbet_sum, 2)                                 AS validbet_sum,
    ROUND(validbet_sum * 100.0
          / NULLIF(SUM(validbet_sum) OVER (), 0), 4)       AS validbet_pct,
    ROUND(pnl_sum, 2)                                      AS pnl_sum,
    ROUND(pnl_sum * 100.0
          / NULLIF(SUM(pnl_sum) OVER (), 0), 4)            AS pnl_pct       -- 盈亏可负，占比仅供参照
FROM agg
ORDER BY gate_stage;


-- ─────────────────────────────────────────────────────────────────────────────
-- P02 · 整体 / 测试线 / 非测试线 三剖面对比（于洁净底集之上）
-- 底集：同单号最新版本 ∧ 一般单 ∧ 非重对单 ∧ 数值守门通过（即 P01 之 0_通过 ∪ 5_测试线）
--       ——如此测试线之虚报贡献得以在「其余口径皆洁净」之下单独呈现。
-- 导出：存为「数据库/P02_测试线三剖面.csv」
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
           CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))   AS fx,
           CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))   AS stake_raw,
           CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))   AS payout_raw,
           CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw,
           CASE WHEN t1.agent_id IS NOT NULL OR t2.agent_id IS NOT NULL
                  OR t3.agent_id IS NOT NULL OR t4.agent_id IS NOT NULL
                  OR t5.agent_id IS NOT NULL
                THEN '测试线' ELSE '非测试线' END             AS seg
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
),
seg_agg AS (
    SELECT seg,
           COUNT(*)                                      AS n_rows,
           COUNT(DISTINCT pid)                           AS n_members,
           SUM(stake_raw / fx)                           AS stake_sum,
           SUM(vb_raw    / fx)                           AS validbet_sum,
           SUM((payout_raw - stake_raw) / fx)            AS pnl_sum
    FROM clean
    GROUP BY seg
    UNION ALL
    SELECT '整体',
           COUNT(*), COUNT(DISTINCT pid),
           SUM(stake_raw / fx), SUM(vb_raw / fx),
           SUM((payout_raw - stake_raw) / fx)
    FROM clean
)
SELECT
    'rn=1 ∧ category=1 ∧ bet38=N ∧ 数值守门'              AS base_def,     -- 口径锁
    seg,
    n_rows,
    n_members,
    ROUND(stake_sum, 2)                                   AS stake_sum,
    ROUND(validbet_sum, 2)                                AS validbet_sum,
    ROUND(pnl_sum, 2)                                     AS pnl_sum,
    ROUND(n_rows * 100.0
          / MAX(CASE WHEN seg = '整体' THEN n_rows END) OVER (), 4)  AS rows_pct,
    ROUND(stake_sum * 100.0
          / NULLIF(MAX(CASE WHEN seg = '整体' THEN stake_sum END) OVER (), 0), 4)
                                                          AS stake_pct,
    ROUND(pnl_sum * 100.0
          / NULLIF(MAX(CASE WHEN seg = '整体' THEN pnl_sum END) OVER (), 0), 4)
                                                          AS pnl_pct        -- 盈亏可负，占比仅供参照
FROM seg_agg
ORDER BY CASE seg WHEN '整体' THEN 0 WHEN '非测试线' THEN 1 ELSE 2 END;


-- ─────────────────────────────────────────────────────────────────────────────
-- P03 · 会员级误判剖面（会员数之虚报与污染，逐员唯一归类后可加）
-- 定义（互斥五类，於窗口 + bet02='101' 全体出现过之会员上）：
--   幽灵会员_数值守门   仅存在于数值守门不过之行（pid 可铸而行不过守门）
--   幽灵会员_纯重复     其全部行皆 rn>1 不可能（rn=1 必存），故此类实为：
--                        洁净后零留存·因非一般单/重对单   全部 rn=1 行皆 3/4 桶
--   幽灵会员_纯测试线   洁净后仅剩测试线行（= 测试会员，须整员剔除）
--   指标污染会员        洁净底集内留存，但其行数因 2/3/4/5 桶行而曾被虚增
--   洁净无损会员        洁净底集内留存，且各桶均无其行
-- 会员级虚报会员数 = 前三类之和；误判风险 = 指标污染会员（留存但指标曾失真）。
-- 导出：存为「数据库/P03_会员级误判剖面.csv」
-- ─────────────────────────────────────────────────────────────────────────────
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'
),
ranked AS (
    SELECT b.bet01, b.bet04, b.bet05, b.bet11,
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
           b.bet38, b.category,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
      AND b.bet02 = '101'
),
staged AS (
    SELECT CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) AS pid,
           CASE
             WHEN CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) IS NULL
               OR CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) <= 0
               OR CAST(NULLIF(TRIM(r.bet04),'') AS INT) IS NULL
               OR CAST(NULLIF(TRIM(r.bet04),'') AS INT) <= 0
               OR CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) IS NULL
               OR CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) <= 0
                                                          THEN 1
             WHEN r.rn > 1                                THEN 2
             WHEN r.category <> '1' OR r.category IS NULL THEN 3
             WHEN UPPER(TRIM(COALESCE(r.bet38,''))) <> 'N' THEN 4
             WHEN t1.agent_id IS NOT NULL OR t2.agent_id IS NOT NULL
               OR t3.agent_id IS NOT NULL OR t4.agent_id IS NOT NULL
               OR t5.agent_id IS NOT NULL                 THEN 5
             ELSE 0
           END AS st
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
),
per_member AS (
    SELECT pid,
           SUM(CASE WHEN st = 0 THEN 1 ELSE 0 END) AS n_clean,
           SUM(CASE WHEN st = 1 THEN 1 ELSE 0 END) AS n_g1,
           SUM(CASE WHEN st = 2 THEN 1 ELSE 0 END) AS n_g2,
           SUM(CASE WHEN st = 3 THEN 1 ELSE 0 END) AS n_g3,
           SUM(CASE WHEN st = 4 THEN 1 ELSE 0 END) AS n_g4,
           SUM(CASE WHEN st = 5 THEN 1 ELSE 0 END) AS n_g5
    FROM staged
    WHERE pid IS NOT NULL AND pid > 0                 -- pid 不可铸之行无从归员，另见 P01 桶 1 行数
    GROUP BY pid
),
classed AS (
    SELECT CASE
             WHEN n_clean > 0 AND n_g2 + n_g3 + n_g4 + n_g5 = 0
                                                    THEN '5_洁净无损会员'
             WHEN n_clean > 0                       THEN '4_指标污染会员'
             WHEN n_g5 > 0 AND n_g3 + n_g4 = 0      THEN '3_幽灵会员_纯测试线'
             WHEN n_g3 + n_g4 > 0                   THEN '2_幽灵会员_非一般单或重对单'
             ELSE '1_幽灵会员_数值守门'
           END AS member_class,
           pid
    FROM per_member
)
SELECT
    '洁净=rn1∧cat1∧bet38N∧守门∧非测试'                  AS class_def,      -- 口径锁
    member_class,
    COUNT(*)                                             AS n_members,      -- 互斥可加
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 4)   AS members_pct     -- 占窗口全体会员
FROM classed
GROUP BY member_class
ORDER BY member_class;
