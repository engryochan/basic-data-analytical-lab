/* ═══════════════════════════════════════════════════════════════════════
   §Z-20 · R03b 重导前置锁证 · Gate-0（Export Parameters）
   ▸ 导出：需要 —— 存为「数据库/R03b_count_check.csv」（本段第二条）
   ▸ 纪律：本 Gate 在**导出之前**执行。目标不是拿到 CSV，
     而是先确立「应当得到多少行、依何键排序、边界在何处」。
   ▸ ⛔ 本包不预设任何期望行数。旧记载之 6,143,388 与 18,139,550
     皆属 historical observation，**不得作为本轮期望值**；
     本轮之 DB row_count 由 Gate-0 之 §A 现算产生，自成 OBSERVED。
   ▸ 排序键契约：ORDER BY 须构成**全序**（唯一且无并列），否则分页无稳定边界。
     R03b 之候选全序键为 (bet_date, member_id, dealer_id)——须由 §B 实测其唯一性，
     不得假定。若非唯一，须补入 tie-breaker 直至唯一。
   ═══════════════════════════════════════════════════════════════════════ */

-- ── A · 总量与边界（DB 侧唯一真相，导出前先取）───────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/R03b_count_check.csv」
SELECT COUNT(*)                                                    AS db_row_count,
       COUNT(DISTINCT CONCAT_WS('|', bet_date, member_id, dealer_id))
                                                                   AS db_distinct_key,
       COUNT(DISTINCT member_id)                                   AS db_member,
       COUNT(DISTINCT dealer_id)                                   AS db_dealer,
       COUNT(DISTINCT bet_date)                                    AS db_date,
       MIN(bet_date)                                               AS date_min,
       MAX(bet_date)                                               AS date_max,
       MIN(member_id)                                              AS member_min,
       MAX(member_id)                                              AS member_max,
       MIN(dealer_id)                                              AS dealer_min,
       MAX(dealer_id)                                              AS dealer_max
FROM (
  -- ⚠ 此处须原样嵌入 §R03b 之完整 SELECT 主体（自 WITH 起至 GROUP BY 止，
  --    去掉其末端 ORDER BY 与任何 LIMIT）。占位不得留空即跑。
  -- ○ 待表：§R03b 主体
  SELECT NULL AS bet_date, NULL AS member_id, NULL AS dealer_id
) r;


-- ── B · 排序键全序性检定（决定能否分页）────────────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/R03b_keyorder_check.csv」
-- ▸ 判读契约：n_rows 必须恒等于 n_key。若 n_rows > n_key，
--   则该键组合**存在并列**，分页边界不可靠，须补 tie-breaker 后重检。
SELECT COUNT(*)                                                    AS n_rows,
       COUNT(DISTINCT CONCAT_WS('|', bet_date, member_id, dealer_id))
                                                                   AS n_key_3col,
       COUNT(*) - COUNT(DISTINCT CONCAT_WS('|', bet_date, member_id, dealer_id))
                                                                   AS ties_3col,
       CASE WHEN COUNT(*) = COUNT(DISTINCT CONCAT_WS('|', bet_date, member_id, dealer_id))
            THEN '全序成立·可分页' ELSE '存在并列·须补 tie-breaker' END
                                                                   AS verdict
FROM (
  -- ○ 待表：§R03b 主体（同上）
  SELECT NULL AS bet_date, NULL AS member_id, NULL AS dealer_id
) r;


-- ── C · 分页清单预生成（键集游标，禁 OFFSET）──────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/R03b_page_manifest.csv」
-- ▸ 每页起止键先行算定并落盘，导出时按此清单逐页取，
--   使「页与页之间无重叠、无缺口」可事后逐页复核。
-- ▸ PAGE_SIZE 由执行者按集群实况设定；本包不写死。
SELECT page_no                                                     AS page_no,
       MIN(sort_key)                                               AS start_key,
       MAX(sort_key)                                               AS end_key,
       COUNT(*)                                                    AS n_rows_expected
FROM (
  SELECT CONCAT_WS('|', bet_date, member_id, dealer_id)            AS sort_key,
         CAST(FLOOR((ROW_NUMBER() OVER (ORDER BY bet_date, member_id, dealer_id) - 1)
                    / 500000) AS INT)                              AS page_no
  FROM (
    -- ○ 待表：§R03b 主体（同上）
    SELECT NULL AS bet_date, NULL AS member_id, NULL AS dealer_id
  ) r
) p
GROUP BY page_no
ORDER BY page_no;
