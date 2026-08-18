/* ═══════════════════════════════════════════════════════════════════════
   Probe-01 · bet16 ↔ bet41 关系实证（StarRocks 方言修正版 v2）
   ▸ 导出：需要 —— B/C/D 三段各存一档
   ▸ 修正缘由：v1 三段报「Unable to parse SQL」，根因为 quantileExact(p)(x)
     系 ClickHouse 双调用语法，StarRocks 无此函数。改用 PERCENTILE_APPROX(x, p)。
     另 v1 段 A 未加窗口与产品过滤，扫全表 205,874,217 行（含非百家乐、含窗口外），
     本版一律补齐 dt 窗口与 bet02='101'，与全项目口径对齐。
   ▸ 判读纪律：只观察、不修复；不预设 bet41 = validbet × 退水率；
     恒等式采双假设并列检验，禁止先写死其一。
   ═══════════════════════════════════════════════════════════════════════ */

-- ── B · 差额与比例分布（限本项目窗口与产品）──────────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01B_diff_ratio.csv」
SELECT COUNT(*)                                                        AS n,
       MIN(b16 - b41)                                                  AS diff_min,
       PERCENTILE_APPROX(b16 - b41, 0.50)                              AS diff_p50,
       PERCENTILE_APPROX(b16 - b41, 0.90)                              AS diff_p90,
       PERCENTILE_APPROX(b16 - b41, 0.99)                              AS diff_p99,
       MAX(b16 - b41)                                                  AS diff_max,
       MIN(b41 / NULLIF(b16, 0))                                       AS ratio_min,
       PERCENTILE_APPROX(b41 / NULLIF(b16, 0), 0.01)                   AS ratio_p01,
       PERCENTILE_APPROX(b41 / NULLIF(b16, 0), 0.50)                   AS ratio_p50,
       PERCENTILE_APPROX(b41 / NULLIF(b16, 0), 0.99)                   AS ratio_p99,
       MAX(b41 / NULLIF(b16, 0))                                       AS ratio_max
FROM (
  SELECT CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE b16 IS NOT NULL AND b41 IS NOT NULL AND b16 <> 0;


-- ── C · 分叉点定位：月份 × 玩法 × 免佣 × 币别 ────────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01C_split_by_dim.csv」
-- ▸ 月份必留：本条查的不只是字段语义，更是【语义是否发生过版本切换】。
SELECT DATE_TRUNC('month', dt)                                          AS ym,
       TRIM(bet09)                                                      AS bet09,
       TRIM(commission)                                                 AS commission,
       TRIM(bet10)                                                      AS bet10,
       COUNT(*)                                                         AS n,
       SUM(CASE WHEN b16 =  b41 THEN 1 ELSE 0 END)                      AS equal_n,
       SUM(CASE WHEN b16 <> b41 THEN 1 ELSE 0 END)                      AS unequal_n,
       SUM(CASE WHEN b16 <> 0 THEN 1 ELSE 0 END)                        AS b16_nonzero_n,
       SUM(CASE WHEN b41 <> 0 THEN 1 ELSE 0 END)                        AS b41_nonzero_n,
       AVG(b16)                                                         AS avg_b16,
       AVG(b41)                                                         AS avg_b41,
       AVG(b16 - b41)                                                   AS avg_diff,
       PERCENTILE_APPROX(b16, 0.50)                                     AS p50_b16,
       PERCENTILE_APPROX(b41, 0.50)                                     AS p50_b41
FROM (
  SELECT dt, bet09, commission, bet10,
         CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE b16 IS NOT NULL AND b41 IS NOT NULL
GROUP BY DATE_TRUNC('month', dt), TRIM(bet09), TRIM(commission), TRIM(bet10)
ORDER BY ym, bet09, commission, bet10;


-- ── D · 与 validbet 之关系（不预设公式，只看分布）────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01D_vs_validbet.csv」
SELECT COUNT(*)                                                         AS n,
       SUM(CASE WHEN vb IS NOT NULL AND b41 IS NOT NULL THEN 1 ELSE 0 END)      AS comparable_n,
       SUM(CASE WHEN vb <> 0 AND b41 / vb BETWEEN 0 AND 1 THEN 1 ELSE 0 END)    AS plausible_n,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.01)                     AS r41_p01,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.50)                     AS r41_p50,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.90)                     AS r41_p90,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.99)                     AS r41_p99,
       PERCENTILE_APPROX(b16 / NULLIF(vb, 0), 0.50)                     AS r16_p50,
       PERCENTILE_APPROX(b16 / NULLIF(vb, 0), 0.99)                     AS r16_p99
FROM (
  SELECT CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) AS vb,
         CAST(NULLIF(TRIM(bet16),'')    AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'')    AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE vb IS NOT NULL AND b41 IS NOT NULL AND vb <> 0;


-- ── E · 恒等式双假设并列检验（H16 vs H41，谁能闭合由数据裁定）────────────
-- ▸ 导出：需要 —— 存为「数据库/P01E_identity_test.csv」
SELECT 'H16: bet17 = bet14 - bet13 + bet16'                             AS hypothesis,
       COUNT(*)                                                         AS n,
       SUM(CASE WHEN e16 = 0 THEN 1 ELSE 0 END)                         AS exact_match_n,
       SUM(CASE WHEN e16 = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)        AS exact_match_rate,
       PERCENTILE_APPROX(ABS(e16), 0.50)                                AS abs_err_p50,
       PERCENTILE_APPROX(ABS(e16), 0.95)                                AS abs_err_p95,
       PERCENTILE_APPROX(ABS(e16), 0.99)                                AS abs_err_p99,
       MAX(ABS(e16))                                                    AS abs_err_max
FROM (
  SELECT (CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)))
       - (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))
        - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        + CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)))                AS e16
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE e16 IS NOT NULL
UNION ALL
SELECT 'H41: bet17 = bet14 - bet13 + bet41'                             AS hypothesis,
       COUNT(*)                                                         AS n,
       SUM(CASE WHEN e41 = 0 THEN 1 ELSE 0 END)                         AS exact_match_n,
       SUM(CASE WHEN e41 = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)        AS exact_match_rate,
       PERCENTILE_APPROX(ABS(e41), 0.50)                                AS abs_err_p50,
       PERCENTILE_APPROX(ABS(e41), 0.95)                                AS abs_err_p95,
       PERCENTILE_APPROX(ABS(e41), 0.99)                                AS abs_err_p99,
       MAX(ABS(e41))                                                    AS abs_err_max
FROM (
  SELECT (CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)))
       - (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))
        - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        + CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)))                AS e41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE e41 IS NOT NULL
ORDER BY hypothesis;
