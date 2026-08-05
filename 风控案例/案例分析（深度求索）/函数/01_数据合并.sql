-- ============================================================
-- 文件：01_数据合并.sql
-- 用途：全局 ODS → DWD → DWS → ADS 合并脚本
-- 基于表：ods_a168_bet01 (投注主表)
-- 作者：OGDIL 实验室
-- 日期：2026-07-29
-- ============================================================

-- 注意：本脚本假设您已具备 SELECT 权限，但无 DDL/DML 权限，
-- 因此使用 CREATE TABLE 仅为示意，实际可改为 SELECT INTO 或物化视图
-- 若无法创建表，可直接将 SELECT 结果用于后续分析。

-- 1. DWD 层：清洗投注明细（排除取消单，转换金额类型）
DROP TABLE IF EXISTS dwd_bet_clean;
CREATE TABLE dwd_bet_clean AS
SELECT 
    bet01 AS bet_id,
    bet05 AS member_id,
    eid AS dealer_id,
    gameId,
    bet31 AS table_id,                -- 桌子编号
    CAST(bet13 AS DECIMAL(16,4)) AS bet_amount,
    bet30 AS is_cancel,
    CAST(bet14 AS DECIMAL(16,4)) AS rebate_rate,
    dt,
    -- 附加字段
    betwalletid,
    gametype,
    commission,
    category,
    serid,
    ip,
    partnerBetId,
    updatetime
FROM ods_a168_bet01
WHERE bet30 = 'N';   -- 仅有效注单

-- 2. DWS 层：按会员、荷官、日期等维度轻度聚合
-- 2.1 会员日汇总
DROP TABLE IF EXISTS dws_member_daily;
CREATE TABLE dws_member_daily AS
SELECT 
    dt,
    bet05 AS member_id,
    COUNT(*) AS bet_count,
    SUM(CAST(bet13 AS DECIMAL(16,4))) AS total_bet,
    SUM(CAST(bet13 AS DECIMAL(16,4)) * 0.05) AS profit,
    AVG(CAST(bet13 AS DECIMAL(16,4))) AS avg_bet,
    COUNT(DISTINCT eid) AS distinct_dealers,
    COUNT(DISTINCT gameId) AS distinct_games,
    COUNT(DISTINCT bet31) AS distinct_tables
FROM ods_a168_bet01
WHERE bet30 = 'N'
GROUP BY dt, bet05;

-- 2.2 荷官日汇总
DROP TABLE IF EXISTS dws_dealer_daily;
CREATE TABLE dws_dealer_daily AS
SELECT 
    dt,
    eid AS dealer_id,
    COUNT(*) AS bet_count,
    COUNT(DISTINCT bet05) AS unique_players,
    SUM(CAST(bet13 AS DECIMAL(16,4))) AS total_bet,
    SUM(CAST(bet13 AS DECIMAL(16,4)) * 0.05) AS profit
FROM ods_a168_bet01
WHERE bet30 = 'N'
GROUP BY dt, eid;

-- 2.3 会员对同桌率汇总（用于团伙识别）
DROP TABLE IF EXISTS dws_pair_table;
CREATE TABLE dws_pair_table AS
SELECT 
    a.bet05 AS player_a,
    b.bet05 AS player_b,
    a.bet31 AS table_id,
    COUNT(*) AS same_table_count,
    MIN(a.dt) AS first_meet,
    MAX(a.dt) AS last_meet,
    AVG(CAST(a.bet13 AS DECIMAL(16,4))) AS avg_bet_a,
    AVG(CAST(b.bet13 AS DECIMAL(16,4))) AS avg_bet_b
FROM ods_a168_bet01 a
JOIN ods_a168_bet01 b ON a.bet31 = b.bet31 AND a.bet05 < b.bet05
WHERE a.bet30 = 'N' AND b.bet30 = 'N'
GROUP BY a.bet05, b.bet05, a.bet31;

-- 3. ADS 层：面向业务宽表（供看板直接使用）
-- 3.1 会员全景宽表（含风险标签）
DROP TABLE IF EXISTS ads_member_profile;
CREATE TABLE ads_member_profile AS
SELECT 
    m.member_id,
    m.reg_time,
    m.status,
    COALESCE(d.total_bet, 0) AS total_bet,
    COALESCE(d.profit, 0) AS total_profit,
    COALESCE(d.bet_count, 0) AS total_bet_count,
    COALESCE(d.avg_bet, 0) AS avg_bet,
    COALESCE(d.distinct_dealers, 0) AS distinct_dealers,
    COALESCE(d.distinct_games, 0) AS distinct_games,
    -- 可扩展添加投注模式标签、风险等级等
    CASE 
        WHEN COALESCE(d.profit, 0) > 5000000 THEN '钻石'
        WHEN COALESCE(d.profit, 0) > 500000 THEN '黄金'
        WHEN COALESCE(d.profit, 0) > 10000 THEN '白银'
        ELSE '青铜'
    END AS vip_level,
    -- 异常标记：单笔大额
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM ods_a168_bet01 b 
            WHERE b.bet05 = m.member_id 
              AND CAST(b.bet13 AS DECIMAL(16,4)) > 50000
              AND b.bet30 = 'N'
        ) THEN 1 ELSE 0
    END AS flag_high_single_bet
FROM ods_a168_member m
LEFT JOIN (
    SELECT 
        bet05 AS member_id,
        SUM(CAST(bet13 AS DECIMAL(16,4))) AS total_bet,
        SUM(CAST(bet13 AS DECIMAL(16,4)) * 0.05) AS profit,
        COUNT(*) AS bet_count,
        AVG(CAST(bet13 AS DECIMAL(16,4))) AS avg_bet,
        COUNT(DISTINCT eid) AS distinct_dealers,
        COUNT(DISTINCT gameId) AS distinct_games
    FROM ods_a168_bet01
    WHERE bet30 = 'N'
    GROUP BY bet05
) d ON m.member_id = d.member_id;

-- 3.2 荷官绩效宽表
DROP TABLE IF EXISTS ads_dealer_profile;
CREATE TABLE ads_dealer_profile AS
SELECT 
    d.dealer_id,
    COALESCE(e.name, '') AS dealer_name,
    COALESCE(e.status, '') AS status,
    COALESCE(agg.total_bet, 0) AS total_bet,
    COALESCE(agg.profit, 0) AS total_profit,
    COALESCE(agg.unique_players, 0) AS unique_players,
    COALESCE(agg.bet_count, 0) AS bet_count,
    CASE 
        WHEN COALESCE(agg.profit, 0) > 10000000 THEN 'S'
        WHEN COALESCE(agg.profit, 0) > 1000000 THEN 'A'
        WHEN COALESCE(agg.profit, 0) > 100000 THEN 'B'
        WHEN COALESCE(agg.profit, 0) > 10000 THEN 'C'
        ELSE 'D'
    END AS performance_grade
FROM ods_a168_employee e
RIGHT JOIN (
    SELECT 
        eid AS dealer_id,
        SUM(CAST(bet13 AS DECIMAL(16,4))) AS total_bet,
        SUM(CAST(bet13 AS DECIMAL(16,4)) * 0.05) AS profit,
        COUNT(DISTINCT bet05) AS unique_players,
        COUNT(*) AS bet_count
    FROM ods_a168_bet01
    WHERE bet30 = 'N'
    GROUP BY eid
) agg ON e.id = agg.dealer_id;
