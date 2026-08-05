-- 1. 整体统计
SELECT 
    COUNT(*) AS 总玩家对数,
    COUNT(DISTINCT player_a) AS 涉及玩家A数量,
    COUNT(DISTINCT player_b) AS 涉及玩家B数量,
    AVG(same_round_count) AS 平均同桌局数,
    MAX(same_round_count) AS 最高同桌局数,
    AVG(same_rate) AS 平均同桌率,
    COUNT(CASE WHEN same_rate >= 0.3 THEN 1 ELSE NULL END) AS 高同桌率对数
FROM wm_risk.player_pair_stat;

-- 2. 高风险同桌对 Top 50
SELECT 
    player_a,
    player_b,
    same_round_count AS 同桌局数,
    ROUND(same_rate * 100, 2) AS 同桌率_百分比,
    first_game_time AS 首次同桌,
    last_game_time AS 最近同桌,
    TIMESTAMPDIFF(DAY, first_game_time, last_game_time) AS 同桌跨度_天
FROM wm_risk.player_pair_stat
WHERE same_round_count >= 5
ORDER BY same_round_count DESC, same_rate DESC
LIMIT 50;

-- 3. 带风险分数的查询
SELECT 
    player_a,
    player_b,
    same_round_count,
    ROUND(same_rate * 100, 2) AS 同桌率_百分比,
    -- 风险分数
    CASE 
        WHEN same_round_count >= 30 THEN 100
        WHEN same_round_count >= 15 THEN 80
        WHEN same_round_count >= 8  THEN 60
        ELSE 30 
    END 
    + 
    CASE 
        WHEN same_rate >= 0.5 THEN 40
        WHEN same_rate >= 0.3 THEN 25
        ELSE 0 
    END AS risk_score
FROM wm_risk.player_pair_stat
WHERE same_round_count >= 5
ORDER BY risk_score DESC, same_round_count DESC
LIMIT 100;


