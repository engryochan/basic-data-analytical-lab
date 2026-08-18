/* ═══════════════════════════════════════════════════════════════════════
   Probe-02 · ods_a168_log_mem_change 处置事件来源 · Step-01 补跑（v2）
   ▸ 首跑已得：lmc04 仅三类 —— edit 499,494 / add 107,796 / changestatus 79,493
              合计 686,783，与 COUNT(*) 相符；
              lmc02 去重 168,227 ≪ 686,783 → lmc02 非日志主键，系实体 ID；
              lmc03 去重 7 → 层级码（样本中 7=会员、1~5=代理级）。
   ▸ 首跑缺口：LIMIT 1000 配 ORDER BY lmc04 只取到字典序最前之 'add'，
              **风控处置最可能所在之 changestatus 一条样本都没看到**。
              本版改为逐类别定额取样，杜绝此偏。
   ▸ 纪律：只观察、不翻译、不分类、不命名 treatment。
           OBSERVED 原文 ≠ 业务解释 ≠ treatment，三层不得跨级。
   ═══════════════════════════════════════════════════════════════════════ */

-- ── A · 逐类别定额取样（每类各取最早 200 与最新 200，可复现，非随机）──────
-- ▸ 导出：需要 —— 存为「数据库/P02A_lmc_samples.csv」
WITH r AS (
  SELECT lmc04, lmc05, lmc02, lmc03, lmc06, lmc07, lmc08, lmc10,
         ROW_NUMBER() OVER (PARTITION BY lmc04 ORDER BY lmc08 ASC,  lmc02 ASC) AS rn_old,
         ROW_NUMBER() OVER (PARTITION BY lmc04 ORDER BY lmc08 DESC, lmc02 DESC) AS rn_new
  FROM ods_mariadb_2b.ods_a168_log_mem_change
)
SELECT lmc04 AS 类别, '最早' AS 取样端, lmc08 AS 異動時間, lmc02 AS 实体ID, lmc03 AS 层级,
       lmc06 AS 操作者, lmc07 AS 操作者LV, lmc10 AS 操作IP, lmc05 AS 内容原文
FROM r WHERE rn_old <= 200
UNION ALL
SELECT lmc04, '最新', lmc08, lmc02, lmc03, lmc06, lmc07, lmc10, lmc05
FROM r WHERE rn_new <= 200
ORDER BY 类别, 取样端, 異動時間;


-- ── B · changestatus 专项：内容原文枚举（处置最可能所在）────────────────
-- ▸ 导出：需要 —— 存为「数据库/P02B_changestatus_patterns.csv」
-- ▸ 只做「原文前缀归并」以见其形，不做语义分类。
SELECT SUBSTRING(TRIM(lmc05), 1, 40)                                    AS 内容前40字,
       COUNT(*)                                                         AS n,
       COUNT(DISTINCT lmc02)                                            AS 涉实体数,
       MIN(lmc08)                                                       AS 最早,
       MAX(lmc08)                                                       AS 最晚,
       SUM(CASE WHEN lmc03 = '7' THEN 1 ELSE 0 END)                     AS 其中层级7数
FROM ods_mariadb_2b.ods_a168_log_mem_change
WHERE lmc04 = 'changestatus'
GROUP BY SUBSTRING(TRIM(lmc05), 1, 40)
ORDER BY n DESC;


-- ── C · lmc02 接线键验证（S1 前置：接错键则 treatment 全错）──────────────
-- ▸ 导出：需要 —— 存为「数据库/P02C_key_check.csv」
-- ▸ 三问：① lmc03 与 lmc02 是否一一对应实体类型？
--         ② lmc02=0 之脏值有多少？③ 层级7 之 lmc02 能否命中注单表会员号？
SELECT l.lmc03                                                          AS 层级,
       COUNT(*)                                                         AS 日志行数,
       COUNT(DISTINCT l.lmc02)                                          AS 去重实体数,
       SUM(CASE WHEN TRIM(l.lmc02) = '0' THEN 1 ELSE 0 END)             AS 实体ID为0之脏行,
       SUM(CASE WHEN m.member_id IS NOT NULL THEN 1 ELSE 0 END)         AS 命中注单会员数,
       COUNT(DISTINCT CASE WHEN m.member_id IS NOT NULL
                           THEN l.lmc02 END)                            AS 命中去重实体数,
       MIN(l.lmc08)                                                     AS 最早,
       MAX(l.lmc08)                                                     AS 最晚
FROM ods_mariadb_2b.ods_a168_log_mem_change l
LEFT JOIN (
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05),'') AS BIGINT) AS member_id
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) m ON m.member_id = CAST(NULLIF(TRIM(l.lmc02),'') AS BIGINT)
GROUP BY l.lmc03
ORDER BY l.lmc03;


-- ── D · 窗口内事件量（决定 treatment 是否有足够样本）────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P02D_events_in_window.csv」
SELECT lmc04                                                            AS 类别,
       lmc03                                                            AS 层级,
       COUNT(*)                                                         AS 窗口内行数,
       COUNT(DISTINCT lmc02)                                            AS 涉实体数
FROM ods_mariadb_2b.ods_a168_log_mem_change
WHERE CAST(NULLIF(TRIM(lmc08),'') AS DATETIME) >= '2026-03-21 00:00:00'
  AND CAST(NULLIF(TRIM(lmc08),'') AS DATETIME) <  '2026-08-07 00:00:00'
GROUP BY lmc04, lmc03
ORDER BY 类别, 层级;
