-- =================================================================
-- ⚡ 頂級量化風控工作台：StarRocks 完全體風控特徵提純與風險分數融合腳本 ⚡
-- =================================================================

-- 【模組一：全盤整體統計徹查】
SELECT 
    COUNT(*) AS 总玩家对数,
    COUNT(DISTINCT player_a) AS 涉及玩家A数量,
    COUNT(DISTINCT player_b) AS 涉及玩家B数量,
    AVG(same_round_count) AS 平均同桌局数,
    MAX(same_round_count) AS 最高同桌局数,
    AVG(same_rate) AS 平均同桌率,
    COUNT(CASE WHEN same_rate >= 0.3 THEN 1 END) AS 高同桌率对数
FROM wm_risk.player_pair_stat;


-- 【模組二：融合最高產能 risk_score 的 Top 50 終極絕殺清單】
SELECT 
    player_a,
    player_b,
    same_round_count AS 同桌局数,
    ROUND(same_rate * 100, 2) AS 同桌率_百分比,
    first_game_time AS 首次同桌,
    last_game_time AS 最近同桌,
    -- 💥【核心修正一】StarRocks 正統時間差函數為 DATEDIFF
    DATEDIFF(last_game_time, first_game_time) AS 同桌跨度_天,
    
    -- 💥【核心修正二】將孤兒 CASE WHEN 完美縫合嵌入主 SELECT 流中，提純為 risk_score 因子
    (CASE 
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
    END) AS risk_score

FROM wm_risk.player_pair_stat
WHERE same_round_count >= 5
-- 🚀 釋放極速分析產能：直接依據最新重構的風險分數由高到低降序排列
ORDER BY risk_score DESC, same_round_count DESC
LIMIT 50;
