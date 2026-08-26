-- ══════════════════════════════════════════════════════════════════════════════
--  CHAIN-01 · 多链 LV5 代理的身份识别（待 BE 节点恢复后再跑）
--  ---------------------------------------------------------------------------
--  已实测（OBSERVED）：
--    n_parents = 1  → 2,459 名 LV5 代理
--    n_parents = 2  →     7 名
--    n_parents = 60 →     1 名   ★ 身份与注单量【尚未查证】
--  ---------------------------------------------------------------------------
--  ⚠ 前一轮 SELECT 只输出 (n_parents, n_agents) 两列，未含 agent_id 与 n_bets。
--    因此「该代理是 lv5 = 0」「其注单 638,864 笔」等说法【无数据支持】，
--    本件即为查证此事而设。在结果出来之前，不得对该代理作任何身份解释。
--  纪律：行注释 only · 无 OFFSET · CAST(... AS BIGINT) · 全部只读
-- ══════════════════════════════════════════════════════════════════════════════

WITH rk AS (
  SELECT b.bet01, b.bet11, b.bet13, b.dt,
         CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT)                      AS lv5,
         CONCAT_WS('|', COALESCE(NULLIF(TRIM(b.bet18),''),'-'),
                        COALESCE(NULLIF(TRIM(b.bet19),''),'-'),
                        COALESCE(NULLIF(TRIM(b.bet20),''),'-'),
                        COALESCE(NULLIF(TRIM(b.bet21),''),'-'))        AS parent_chain,
         CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)                      AS member_id,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)    AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
    AND NULLIF(TRIM(b.bet22),'') IS NOT NULL
)
SELECT r.lv5                                                           AS lv5_agent_id,
       COUNT(DISTINCT r.parent_chain)                                  AS n_parent_chains,
       COUNT(*)                                                        AS n_bets,
       COUNT(DISTINCT r.member_id)                                     AS n_members,
       MIN(r.dt)                                                       AS first_dt,
       MAX(r.dt)                                                       AS last_dt,
       ROUND(SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0)), 2) AS stake,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 6)              AS pct_of_all_bets
FROM rk r
WHERE r.rn = 1
GROUP BY r.lv5
HAVING COUNT(DISTINCT r.parent_chain) > 1
ORDER BY n_parent_chains DESC, n_bets DESC;
