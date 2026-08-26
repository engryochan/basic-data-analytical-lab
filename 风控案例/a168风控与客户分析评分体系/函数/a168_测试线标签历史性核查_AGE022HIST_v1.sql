-- ══════════════════════════════════════════════════════════════════════════════
--  AGE022-HIST · 测试线标记是否具备历史有效期（本轮唯一阻断闸）
--  ---------------------------------------------------------------------------
--  为何必须先答：HF6 的清洗用 age022='1' 剔除测试线。若 age022 只是【今日状态】，
--    则对 2026-03-21 的历史数据套用今日标签 = 用未来解释过去。
--  判读：
--    L1 若 ods_a168_agent 有 effective_from/to 或状态变更时间列 → 可重建历史，OK
--    L2 若只有 updatetime 一列 → 只能证明「最后一次改动的时间」，不能重建轨迹
--    L3 若 log 表有 age022 变更记录 → 可重建
--    L4 若三者皆无 → age022 = LABEL_AS_OF_TODAY，历史 snapshot 禁作预测特征
--  纪律：行注释 only · 无 OFFSET · 全部为读，不改任何数据
-- ══════════════════════════════════════════════════════════════════════════════


-- ── L1 · ods_a168_agent 有哪些时间/状态列 ──
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME   = 'ods_a168_agent'
ORDER BY ORDINAL_POSITION;


-- ── L2 · age022 的取值分布，与该行最后改动时间的关系 ──
--    若 age022='1' 的行其 updatetime 全部集中在近期 ⇒ 标记是近期才打的 ⇒ 历史不成立
SELECT TRIM(age022)                                                    AS age022_val,
       COUNT(*)                                                        AS n_agents,
       MIN(updatetime)                                                 AS ut_min,
       MAX(updatetime)                                                 AS ut_max,
       SUM(CASE WHEN updatetime <  '2026-03-21' THEN 1 ELSE 0 END)     AS n_ut_before_window,
       SUM(CASE WHEN updatetime >= '2026-03-21'
                 AND updatetime <  '2026-08-07' THEN 1 ELSE 0 END)     AS n_ut_in_window,
       SUM(CASE WHEN updatetime >= '2026-08-07' THEN 1 ELSE 0 END)     AS n_ut_after_window
FROM ods_mariadb_2b.ods_a168_agent
GROUP BY TRIM(age022)
ORDER BY n_agents DESC;


-- ── L3 · 全库是否存在 agent 变更日志表 ──
SELECT TABLE_NAME, TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (  LOWER(TABLE_NAME) LIKE '%agent%'
      OR LOWER(TABLE_NAME) LIKE '%log%'
      OR LOWER(TABLE_NAME) LIKE '%hist%'
      OR LOWER(TABLE_NAME) LIKE '%chang%'
      OR LOWER(TABLE_NAME) LIKE '%audit%')
ORDER BY TABLE_NAME;


-- ── L4 · 那 14 名 age022='1' 代理，其 updatetime 逐个看 ──
--    若 updatetime 晚于窗口起点 ⇒ 该代理在窗口早期【不是】测试线 ⇒ 剔除即为泄露
SELECT CAST(NULLIF(TRIM(age001),'') AS BIGINT)                         AS agent_id,
       TRIM(age022)                                                    AS age022,
       updatetime,
       CASE WHEN updatetime <  '2026-03-21' THEN 'BEFORE_WINDOW'
            WHEN updatetime <  '2026-08-07' THEN 'INSIDE_WINDOW'
            ELSE 'AFTER_WINDOW' END                                    AS ut_position
FROM ods_mariadb_2b.ods_a168_agent
WHERE TRIM(age022) = '1'
ORDER BY updatetime;


-- ── L5 · 那 12 名 NO_PROD_ROWS 孤儿代理，是否也在 agent 表内且未被标记 ──
SELECT CAST(NULLIF(TRIM(age001),'') AS BIGINT)                         AS agent_id,
       TRIM(age022)                                                    AS age022,
       updatetime
FROM ods_mariadb_2b.ods_a168_agent
WHERE CAST(NULLIF(TRIM(age001),'') AS BIGINT) IN
      (4967,20958,28768,4968,20959,28769,4969,20960,28770,4970,28771,51526)
ORDER BY agent_id;
