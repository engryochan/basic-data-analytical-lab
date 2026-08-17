-- eval = FALSE ｜ D-07 · 靴尾下注（相对靴位）会员画像
-- 相对 D-06 与原报告 SQL 的差异：① 补齐六道闸 ② 靴键含营业日与桌号
-- ③ 靴内进度取代绝对局号 ④ 两臂分别输出 ⑤ 剔和分母 ⑥ 口径锁列
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.dt, b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet18, b.bet19, b.bet20,
         b.bet21, b.bet22, b.bet38, b.bet39, b.category, b.validbet,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT CAST(NULLIF(TRIM(v.bet05),'') AS BIGINT) AS member_id,
         CONCAT_WS('|', v.dt, v.bet03, v.bet39)   AS shoe_key,
         v.bet39 AS table_id, v.bet09 AS play_code,
         CAST(NULLIF(TRIM(v.bet04),'') AS INT)    AS round_no,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl
  FROM vd v
),
sl AS (
  SELECT shoe_key, MAX(round_no) AS shoe_len
  FROM bs GROUP BY shoe_key HAVING MAX(round_no) BETWEEN 30 AND 90
),
sp AS (
  SELECT b.*, s.shoe_len,
         b.round_no * 1.0 / s.shoe_len AS shoe_pos,
         CASE WHEN b.round_no * 1.0 / s.shoe_len >= 0.80 THEN 1 ELSE 0 END AS is_late
  FROM bs b JOIN sl s ON s.shoe_key = b.shoe_key
),
fs AS (
  SELECT member_id, shoe_key, MIN(round_no) AS first_round,
         MAX(round_no) AS last_round, MAX(shoe_len) AS shoe_len
  FROM sp GROUP BY member_id, shoe_key
)
SELECT p.member_id,
  'shoe_pos>=0.80'                                  AS late_def,
  COUNT(*)                                          AS total_orders,
  SUM(p.is_late)                                    AS late_orders,
  SUM(1 - p.is_late)                                AS norm_orders,
  SUM(p.is_late) * 1.0 / COUNT(*)                   AS late_ratio_rel,
  SUM(CASE WHEN p.round_no >= 40 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_ratio_abs,
  COUNT(DISTINCT p.shoe_key)                        AS n_shoes,
  AVG(p.shoe_pos)                                   AS shoe_pos_mean,
  AVG(p.shoe_len)                                   AS shoe_len_mean,
  AVG(f.first_round * 1.0 / f.shoe_len)             AS first_pos_mean,
  AVG((f.last_round - f.first_round) * 1.0 / f.shoe_len) AS span_ratio,
  SUM(CASE WHEN p.is_late = 1 THEN p.stake ELSE 0 END)
    / NULLIF(SUM(p.is_late), 0)
  / NULLIF(SUM(CASE WHEN p.is_late = 0 THEN p.stake ELSE 0 END)
    / NULLIF(SUM(1 - p.is_late), 0), 0)              AS stake_ratio_late,
  STDDEV_SAMP(p.stake) / NULLIF(AVG(p.stake), 0)     AS stake_cv,
  MAX(p.stake) / NULLIF(SUM(p.stake), 0)             AS stake_max_share,
  SUM(CASE WHEN p.play_code NOT IN ('1','2') THEN 1 ELSE 0 END) * 1.0
    / COUNT(*)                                       AS side_bet_share,
  SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)    AS win_orders,
  SUM(CASE WHEN p.game_pnl < 0 THEN 1 ELSE 0 END)    AS lose_orders,
  SUM(CASE WHEN p.game_pnl = 0 THEN 1 ELSE 0 END)    AS tie_orders,
  SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
    / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate_ex_tie,
  SUM(CASE WHEN p.is_late = 1 THEN p.valid_bet ELSE 0 END) AS vb_late,
  SUM(CASE WHEN p.is_late = 0 THEN p.valid_bet ELSE 0 END) AS vb_norm,
  SUM(CASE WHEN p.is_late = 1 THEN p.game_pnl  ELSE 0 END) AS pl_late,
  SUM(CASE WHEN p.is_late = 0 THEN p.game_pnl  ELSE 0 END) AS pl_norm,
  SUM(CASE WHEN p.is_late = 1 THEN p.game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN p.is_late = 1 THEN p.valid_bet ELSE 0 END), 0) AS roi_late,
  SUM(CASE WHEN p.is_late = 0 THEN p.game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN p.is_late = 0 THEN p.valid_bet ELSE 0 END), 0) AS roi_norm,
  SUM(p.rebate)                                      AS rebate,
  SUM(p.net_pnl)                                     AS net_pnl,
  SUM(p.net_pnl - p.game_pnl - p.rebate)             AS resid_identity
FROM sp p
JOIN fs f ON f.member_id = p.member_id AND f.shoe_key = p.shoe_key
GROUP BY p.member_id
HAVING SUM(p.is_late) >= 400 AND SUM(1 - p.is_late) >= 400
ORDER BY CAST(p.member_id AS BIGINT);

