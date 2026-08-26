-- ══════════════════════════════════════════════════════════════════════════════
--  MEMTEST-01 · 会员级测试标记（mem019 = is_test）常设监测闸
--  ---------------------------------------------------------------------------
--  为何独立成件、不并入 HF7 的 x_bs：
--    ① 实测 ods_a168_member 全表 59,298,245 行，TRIM(mem019) 只出现一个值 'N'
--       无 'Y'、无 NULL、无空串 ⇒ mem019 目前是【单值字段】，与 mem024 同类
--       ⇒ 并入 x_bs 后 f_test_member 恒为 0，对 is_clean 无任何影响
--    ② 并入需对 5,930 万行会员表做 129 次 JOIN，OOM 风险远高于其审计收益
--       （#002 B01 才刚因内存问题连崩三次）
--  ---------------------------------------------------------------------------
--  ★ 但「今天恒为 N」不等于「永远为 N」。本件即为此设：
--    每次快照跑一次；一旦 P1 出现 'Y'，立即把 f_test_member 并入 HF 的 x_bs。
--  ---------------------------------------------------------------------------
--  ⚠ 注意 ods_a168_member 是【注册日分区表】（P-H0 已证）：
--    COUNT(*) 是行数不是会员数，须 COUNT(DISTINCT mem001)。
--    此前 59,298,245 ÷ 723,557 = 82 倍，正是同一陷阱。
--  纪律：行注释 only · 无 OFFSET · CAST(... AS BIGINT) · 全部只读
-- ══════════════════════════════════════════════════════════════════════════════


-- ── P1 · mem019 值域普查（会员数，非行数）──
SELECT TRIM(m.mem019)                                                  AS is_test_val,
       COUNT(*)                                                        AS n_rows,
       COUNT(DISTINCT CAST(NULLIF(TRIM(m.mem001),'') AS BIGINT))       AS n_members,
       COUNT(DISTINCT m.dt)                                            AS n_dt
FROM ods_mariadb_2b.ods_a168_member m
GROUP BY TRIM(m.mem019)
ORDER BY n_rows DESC;


-- ── P2 · 会员主键确认：mem001 是否唯一（一会员是否多行）──
SELECT n_rows_per_member, COUNT(*) AS n_members
FROM ( SELECT CAST(NULLIF(TRIM(mem001),'') AS BIGINT) AS mid,
              COUNT(*) AS n_rows_per_member
       FROM ods_mariadb_2b.ods_a168_member
       GROUP BY 1 ) t
GROUP BY n_rows_per_member
ORDER BY n_rows_per_member;


-- ── P3 · ★阳性闸★ 窗内注单 × 会员测试标记的实际暴露 ──
--    判读：is_test_val = 'Y' 的 n_bets 若为 0（或该组不出现）⇒ 零暴露
--          出现 Y 且 n_bets > 0 ⇒ 立即把 f_test_member 并入 x_bs
WITH mm AS (
  SELECT CAST(NULLIF(TRIM(mem001),'') AS BIGINT)                       AS mid,
         MAX(TRIM(mem019))                                             AS is_test_val
  FROM ods_mariadb_2b.ods_a168_member
  GROUP BY CAST(NULLIF(TRIM(mem001),'') AS BIGINT)
),
rk AS (
  SELECT b.bet01, b.bet05, b.bet11, b.bet13,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)    AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
)
SELECT COALESCE(mm.is_test_val, '(会员表无此人)')                       AS is_test_val,
       COUNT(*)                                                        AS n_bets,
       COUNT(DISTINCT CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT))        AS n_members,
       ROUND(SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0)), 2) AS stake,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 6)              AS pct_of_all_bets
FROM rk r
LEFT JOIN mm ON mm.mid = CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)
WHERE r.rn = 1
GROUP BY COALESCE(mm.is_test_val, '(会员表无此人)')
ORDER BY n_bets DESC;
