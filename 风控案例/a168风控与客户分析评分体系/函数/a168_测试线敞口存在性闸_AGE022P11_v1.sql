-- ══════════════════════════════════════════════════════════════════════════════
--  P11 · 静态清洗泄露敞口 · 存在性闸（AGE022-HIST 最后一关）
--  ---------------------------------------------------------------------------
--  为何还要跑：P9 用 COALESCE(t1..t5) 取【第一个非空】。若同一注单的
--    bet18 命中 VERIFIED、bet20 命中 UNVERIFIABLE，则该注单被记为 VERIFIED，
--    UNVERIFIABLE 被【遮蔽】。P9 的 UNVERIFIABLE=0 因此不是存在性证明。
--    （注：P9 并未把 UNVERIFIABLE 混入 NO_TESTLINE —— COALESCE 会正确返回
--      'UNVERIFIABLE'；真正的缺陷是【优先序遮蔽】，非【类别混同】。）
--  ---------------------------------------------------------------------------
--  本闸改为【逐代理存在性】：对那 10 名代理，逐个数其窗口内注单，
--    不经 COALESCE，不受遮蔽，且 0 行者亦须出现在结果中（LEFT JOIN 保底）。
--  ---------------------------------------------------------------------------
--  由 P8 已确立（OBSERVED）：10 名皆 CREATED_AFTER_BAK，故不在 2025-06-10 备份
--    54567  age005 2025-08-10      56957~56961  age005 2026-07-20（5 名）
--    55438  age005 2025-12-16      57105        age005 2026-08-07 20:50
--    55474  age005 2025-12-19
--    56402  age005 2026-05-08
--  ⇒ 57105 建号于 2026-08-07 20:50，晚于窗口终点，理论上窗口内不可能有注单
--  ⇒ 56957~56961 建号 2026-07-20，仅 2026-07-20 ~ 2026-08-06 十八天可下注
--  纪律：行注释 only · 无 OFFSET · CAST(... AS BIGINT) · 全部只读
-- ══════════════════════════════════════════════════════════════════════════════

WITH u AS (
  SELECT 54567 AS aid UNION ALL SELECT 55438 UNION ALL SELECT 55474
  UNION ALL SELECT 56402 UNION ALL SELECT 56957 UNION ALL SELECT 56958
  UNION ALL SELECT 56959 UNION ALL SELECT 56960 UNION ALL SELECT 56961
  UNION ALL SELECT 57105
),
rk AS (
  SELECT b.bet01, b.dt, b.bet11, b.bet13,
         CAST(NULLIF(TRIM(b.bet18),'') AS BIGINT) AS a1,
         CAST(NULLIF(TRIM(b.bet19),'') AS BIGINT) AS a2,
         CAST(NULLIF(TRIM(b.bet20),'') AS BIGINT) AS a3,
         CAST(NULLIF(TRIM(b.bet21),'') AS BIGINT) AS a4,
         CAST(NULLIF(TRIM(b.bet22),'') AS BIGINT) AS a5,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)    AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
),
hit AS (
  SELECT r.bet01, r.dt, r.bet11, r.bet13, u.aid, 1 AS lvl FROM rk r JOIN u ON u.aid = r.a1 WHERE r.rn = 1
  UNION ALL
  SELECT r.bet01, r.dt, r.bet11, r.bet13, u.aid, 2 FROM rk r JOIN u ON u.aid = r.a2 WHERE r.rn = 1
  UNION ALL
  SELECT r.bet01, r.dt, r.bet11, r.bet13, u.aid, 3 FROM rk r JOIN u ON u.aid = r.a3 WHERE r.rn = 1
  UNION ALL
  SELECT r.bet01, r.dt, r.bet11, r.bet13, u.aid, 4 FROM rk r JOIN u ON u.aid = r.a4 WHERE r.rn = 1
  UNION ALL
  SELECT r.bet01, r.dt, r.bet11, r.bet13, u.aid, 5 FROM rk r JOIN u ON u.aid = r.a5 WHERE r.rn = 1
)
SELECT u.aid                                                           AS agent_id,
       COUNT(DISTINCT h.bet01)                                         AS n_bets_distinct,
       COUNT(h.bet01)                                                  AS n_hits_all_levels,
       MIN(h.dt)                                                       AS first_dt,
       MAX(h.dt)                                                       AS last_dt,
       ROUND(COALESCE(SUM(DISTINCT 0), 0)
           + COALESCE(SUM(CAST(NULLIF(TRIM(h.bet13),'') AS DECIMAL(20,4))
             / NULLIF(CAST(NULLIF(TRIM(h.bet11),'') AS DECIMAL(20,8)),0)), 0), 4) AS stake_all_levels,
       CASE WHEN COUNT(h.bet01) = 0 THEN 'ZERO_EXPOSURE'
            ELSE 'HAS_EXPOSURE' END                                    AS verdict
FROM u
LEFT JOIN hit h ON h.aid = u.aid
GROUP BY u.aid
ORDER BY n_hits_all_levels DESC, u.aid;
