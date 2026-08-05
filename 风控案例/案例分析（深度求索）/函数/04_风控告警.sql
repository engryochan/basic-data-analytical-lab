-- ============================================================
-- 文件：04_风控告警.sql
-- 用途：实时风控告警 SQL（基于阈值触发）
-- 表：ods_a168_bet01 (实时数据)
-- 作者：OGDIL 实验室
-- 日期：2026-07-29
-- ============================================================

-- 1. 单笔大额告警（> 50,000）
SELECT 
    bet05 AS member_id,
    bet13 AS bet_amount,
    dt,
    eid AS dealer_id,
    bet31 AS table_id,
    '单笔大额' AS alert_type,
    CURRENT_TIMESTAMP AS alert_time
FROM ods_a168_bet01
WHERE bet30 = 'N'
  AND CAST(bet13 AS DECIMAL(16,4)) > 50000;

-- 2. 日累计投注异常（> 500,000）
SELECT 
    bet05 AS member_id,
    dt,
    SUM(CAST(bet13 AS DECIMAL(16,4))) AS daily_total,
    '日累计大额' AS alert_type
FROM ods_a168_bet01
WHERE bet30 = 'N'
GROUP BY bet05, dt
HAVING SUM(CAST(bet13 AS DECIMAL(16,4))) > 500000;

-- 3. 荷官低绩效告警（月度利润 < 10,000）
SELECT 
    eid AS dealer_id,
    SUM(CAST(bet13 AS DECIMAL(16,4)) * 0.05) AS monthly_profit,
    COUNT(DISTINCT bet05) AS unique_players,
    '荷官低效' AS alert_type
FROM ods_a168_bet01
WHERE bet30 = 'N'
  AND dt >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
GROUP BY eid
HAVING monthly_profit < 10000;

-- 4. 高同桌率会员对（> 30%）
SELECT 
    a.bet05 AS player_a,
    b.bet05 AS player_b,
    a.bet31 AS table_id,
    COUNT(*) AS same_table_count,
    '高同桌率' AS alert_type
FROM ods_a168_bet01 a
JOIN ods_a168_bet01 b ON a.bet31 = b.bet31 AND a.bet05 < b.bet05
WHERE a.bet30 = 'N' AND b.bet30 = 'N'
GROUP BY a.bet05, b.bet05, a.bet31
HAVING COUNT(*) > 10  -- 阈值可调整
   AND COUNT(*) / (SELECT COUNT(*) FROM ods_a168_bet01 WHERE bet05 IN (a.bet05, b.bet05) AND bet30 = 'N') > 0.3;

-- 5. 新注册会员短时间内大额投注
SELECT 
    m.member_id,
    m.reg_time,
    b.dt AS bet_time,
    CAST(b.bet13 AS DECIMAL(16,4)) AS bet_amount,
    TIMESTAMPDIFF(HOUR, m.reg_time, b.dt) AS hours_since_reg,
    '新客大额' AS alert_type
FROM ods_a168_member m
JOIN ods_a168_bet01 b ON m.member_id = b.bet05
WHERE b.bet30 = 'N'
  AND TIMESTAMPDIFF(HOUR, m.reg_time, b.dt) <= 1
  AND CAST(b.bet13 AS DECIMAL(16,4)) > 10000;
  