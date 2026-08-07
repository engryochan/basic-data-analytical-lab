/* ═══════════════════════════════════════════════════════════════════════════
   a168 风控与客户分层评分体系 · 商业方案 v3　取数 SQL 包（增补）
   ---------------------------------------------------------------------------
   作者：®γσ ξηg（Ryo Eng）· 世博量化® Scibrokes Trading®
   适用：StarRocks（ods_mariadb_2b），Superset SQL Lab
   窗口：2026-03-21 ~ 2026-08-07（139 营业日，E1 全局窗口，字面量已写死）
   ---------------------------------------------------------------------------
   ★ 三条硬规矩（与 @sec-runbook 一致，违反必出事）
     1. 一次一条 —— SQL Lab 一个 tab 只贴一条语句，跑完再贴下一条。
        批量提交会产生僵尸查询，拖垮集群。
     2. 导出前先数行数 —— 见 §00 COUNT 预检。超过 10 万行的按会员号区间切分，
        **不要用 OFFSET 翻页**：277 批数据出现过 36.49% 重复，根因就是分页没有稳定排序。
     3. 导出编码选 CSV(UTF-8)，文件名一个字都不能错，全部存到报告同目录 `数据库/`。
   ---------------------------------------------------------------------------
   ★ 表名开关（ODS ↔ ADS）
     本包默认 ODS 层：ods_mariadb_2b.ods_a168_bet02（字段名保持 betNN 原样）。
     若贵司走 ADS 层 ads_a168_bet02，**先跑 DESC 核对列名**（ADS 常把
     bet13→stake、bet14→payout、bet16→rebate），再只改每条 SQL 里
     `FROM ods_mariadb_2b.ods_a168_bet02` 这一行 + 在 ranked CTE 里加别名映射。
     不要在几十处逐个改。
   ---------------------------------------------------------------------------
   清单
     §00  COUNT 预检（导出前必跑，5 条，返回个位数行）
     §R01 R01_late_shoe.csv            靴末段下注 + 注额斜率 + 末段ROI
     §R02 R02_same_table.csv           同桌对：同桌率 / Jaccard / 提升度 Lift
     §R03 R03_player_dealer.csv        玩家×荷官：局级胜率 / 玩法基准 Z / 对照胜率
     §T02 T02_daily_roi.csv            会员×日 ROI 序列（索提诺 / CAS 输入）
     §T03 T03_arbitrage.csv            打水型：游戏输赢比 / 自对押率 / 返水依赖
     §E02 E02_segment_econ.csv         分群单位经济学（m / ρ / κ / V / H）
     §B01 B01_bt_panel.csv             会员×日回测面板（策略滚动回测输入）
     §K01 K01_risk_feature_matrix.csv  T4 扩样特征矩阵（含 is_seed 种子列）
   ═══════════════════════════════════════════════════════════════════════════ */


/* ───────────────────────────────────────────────────────────────────────────
   §00 · COUNT 预检　一次出 5 个数字，决定要不要切分导出
   用途：任何一份导出前先看它多大。超过 10 万行就按 bet05 区间切分。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT
  COUNT(*)                                   AS n_rows_raw,
  COUNT(DISTINCT bet01)                      AS n_bet_id,
  COUNT(DISTINCT bet05)                      AS n_member,
  COUNT(DISTINCT CONCAT_WS('|',bet03,bet04,bet39)) AS n_round,
  COUNT(DISTINCT eid)                        AS n_dealer
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101'
  AND category = '1'
  AND UPPER(TRIM(bet38)) = 'N';


/* ───────────────────────────────────────────────────────────────────────────
   §R01 · R01_late_shoe.csv
   策略性风控：靴内第 50 把及之后的下注占比 + 相对靴位 + 注额斜率 + 分段 ROI
   对应报告：@sec-r01
   输出列：uid, n_orders_all, n_orders_late, late_share, shoe_pos_p50,
           stake_late_avg, stake_early_avg, stake_ramp, roi_late, roi_early,
           stake_late, game_pnl_late, stake_all, game_pnl_all
   预期行数：数千 ~ 数万（HAVING 已收敛）
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'                                  -- 铁律④b：公司测试线
),
ranked AS (                                            -- 需求 §3.2：同单号保留最新版本
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b                 -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id,
         r.bet03 AS shoe_id, r.bet39 AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw
  FROM ranked r
  /* StarRocks 不支持 EXISTS + 多列 IN，测试线剔除改五路 LEFT JOIN */
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
shoe_len AS (          -- 缺陷一修正：靴长不定，固定 50 不是固定位置
  SELECT shoe_id, table_id, MAX(round_no) AS max_round
  FROM base GROUP BY shoe_id, table_id
),
enriched AS (
  SELECT b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round,
         b.round_no * 1.0 / NULLIF(s.max_round,0)     AS shoe_pos,
         b.stake_raw / b.fx                           AS stake,
         (b.payout_raw - b.stake_raw) / b.fx          AS game_pnl,
         CASE WHEN b.round_no >= 50 THEN 1 ELSE 0 END AS is_late
  FROM base b
  JOIN shoe_len s ON s.shoe_id = b.shoe_id AND s.table_id = b.table_id
)
SELECT
  member_id                                                     AS uid,
  COUNT(*)                                                      AS n_orders_all,
  SUM(is_late)                                                  AS n_orders_late,
  SUM(is_late) * 1.0 / COUNT(*)                                 AS late_share,
  PERCENTILE_APPROX(CASE WHEN is_late=1 THEN shoe_pos END, 0.5) AS shoe_pos_p50,
  SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0)              AS stake_late_avg,
  SUM(CASE WHEN is_late=0 THEN stake END) / NULLIF(COUNT(*)-SUM(is_late),0)     AS stake_early_avg,
  (SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0))
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END)
             / NULLIF(COUNT(*)-SUM(is_late),0), 0)                              AS stake_ramp,
  SUM(CASE WHEN is_late=1 THEN game_pnl END)
    / NULLIF(SUM(CASE WHEN is_late=1 THEN stake END),0)                         AS roi_late,
  SUM(CASE WHEN is_late=0 THEN game_pnl END)
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END),0)                         AS roi_early,
  SUM(CASE WHEN is_late=1 THEN stake END)                                       AS stake_late,
  SUM(CASE WHEN is_late=1 THEN game_pnl END)                                    AS game_pnl_late,
  SUM(stake)                                                                    AS stake_all,
  SUM(game_pnl)                                                                 AS game_pnl_all
FROM enriched
GROUP BY member_id
HAVING COUNT(*) >= 100                                    -- 需求：订单数据 > 100 笔
ORDER BY late_share DESC, n_orders_late DESC;
/* ⚠️ 注意：此处**故意不加** late_share >= 0.70 的 HAVING。
   报告需要「命中组 vs 对照组」的 hold% 对照才能做经济裁定（@sec-r01 的 r01-decision），
   只导命中组就没有对照组。阈值筛选一律放在 R 侧做，SQL 只负责给全量底料。
   若行数过大，改为 HAVING COUNT(*) >= 300 提高活跃度门槛，而不是加 late_share 条件。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R02 · R02_same_table.csv
   团伙同桌：两阶段自连接（先压到会员×物理局并限候选池，再 join）
   对应报告：@sec-r02
   输出列：uid1, uid2, n_same_orders, rounds_1, rounds_2,
           same_rate, jaccard, lift, exp_same, n_tables, first_day, last_day
   ★ 绝不可对 bet02 原表直接自连接：1.9 亿 × 1.9 亿 必然打爆集群。
   ─────────────────────────────────────────────────────────────────────────── */
WITH mr AS (                          -- 阶段一：会员 × 物理局，去重后每人每局一行
  SELECT DISTINCT
         b.bet05 AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key,
         b.bet39 AS table_id,
         b.dt    AS bet_date
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
),
act AS (                              -- 候选池：局数不够就不可能凑到 100 局同桌
  SELECT member_id, COUNT(*) AS n_rounds
  FROM mr GROUP BY member_id HAVING COUNT(*) >= 100
),
mr2 AS (
  SELECT m.* FROM mr m JOIN act a ON a.member_id = m.member_id
),
pair AS (                             -- 阶段二：同局自连接（已压到候选池）
  SELECT x.member_id AS uid1, y.member_id AS uid2,
         COUNT(*)                    AS same_rounds,
         COUNT(DISTINCT x.table_id)  AS n_tables,
         MIN(x.bet_date)             AS first_day,
         MAX(x.bet_date)             AS last_day
  FROM mr2 x
  JOIN mr2 y ON x.round_key = y.round_key AND x.member_id < y.member_id
  GROUP BY x.member_id, y.member_id
  HAVING COUNT(*) >= 100                           -- 需求：同桌订单数 > 100 笔
),
td AS (                               -- Lift 零假设的分子件：每人每桌每日局数
  SELECT table_id, bet_date, member_id, COUNT(*) AS n_md
  FROM mr2 GROUP BY table_id, bet_date, member_id
),
tot AS (                              -- Lift 零假设的分母件：每桌每日总局数
  SELECT table_id, bet_date, COUNT(DISTINCT round_key) AS n_td
  FROM mr2 GROUP BY table_id, bet_date
),
expct AS (                            -- E[same] = Σ n_a(t,d)·n_b(t,d) / N(t,d)
  SELECT a.member_id AS uid1, b.member_id AS uid2,
         SUM(a.n_md * b.n_md * 1.0 / NULLIF(t.n_td,0)) AS exp_same
  FROM td a
  JOIN td b  ON a.table_id = b.table_id AND a.bet_date = b.bet_date
            AND a.member_id < b.member_id
  JOIN tot t ON t.table_id = a.table_id AND t.bet_date = a.bet_date
  GROUP BY a.member_id, b.member_id
)
SELECT p.uid1, p.uid2,
       p.same_rounds                                          AS n_same_orders,
       a1.n_rounds                                            AS rounds_1,
       a2.n_rounds                                            AS rounds_2,
       p.same_rounds * 1.0
         / NULLIF(LEAST(a1.n_rounds, a2.n_rounds),0)          AS same_rate,   -- 需求口径
       p.same_rounds * 1.0
         / NULLIF(a1.n_rounds + a2.n_rounds - p.same_rounds,0) AS jaccard,    -- 对照口径
       p.same_rounds * 1.0 / NULLIF(e.exp_same, 0)            AS lift,        -- ★ 去巧合
       e.exp_same, p.n_tables, p.first_day, p.last_day
FROM pair p
JOIN act a1 ON a1.member_id = p.uid1
JOIN act a2 ON a2.member_id = p.uid2
LEFT JOIN expct e ON e.uid1 = p.uid1 AND e.uid2 = p.uid2
ORDER BY lift DESC, same_rate DESC;
/* ⚠️ 同上：**故意不加** same_rate >= 0.30 的 WHERE。阈值网格（@sec-r02 的 r02-grid）
   要扫 30%/40%/50%/70% × Lift 1/2/3/5 十六格，只导 30% 以上就扫不出下沿。
   若行数仍过大，把 act 的门槛从 100 提到 300，而不是加 same_rate 条件。
   跑不动时按桌台切分：在 mr 的 WHERE 加 AND b.bet39 IN ('T01','T02',...) 分批跑。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R03 · R03_player_dealer.csv
   玩家×荷官关联异常：局级去重 + 玩法基准 Z-score + 对照胜率
   对应报告：@sec-r03
   ★ 已实现《荷官作弊风控阈值分析报告》自列的必补检查：
     用 bet03+bet04 统计关联有效局数，修正同局拆多单造成的 Z-score 放大。
   输出列：uid, dealer_id, stake_amount, profit_amount, net_pnl, win_rate,
           n_related_orders, n_rounds_eff, p_base_mix, z_score,
           net_pnl_all, game_pnl_all, stake_all, win_rate_all, win_rate_other
   ─────────────────────────────────────────────────────────────────────────── */
WITH ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id, r.eid AS dealer_id,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'      -- 阈值报告：排除小费单
),
ord AS (
  SELECT bet_id, member_id, dealer_id, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (      -- ★ 玩法基准胜率：Banker/Player/Tie/Big/Small 各算各的
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord GROUP BY bet_side
),
pr AS (             -- ★ 局级去重：同局多单折成一局，Z-score 才不被 √k 倍放大
  SELECT member_id, dealer_id, round_key,
         SUM(stake)    AS stake,
         SUM(game_pnl) AS game_pnl,
         SUM(net_pnl)  AS net_pnl,
         COUNT(*)      AS n_orders_in_round,
         MAX(bet_side) AS main_side
  FROM ord GROUP BY member_id, dealer_id, round_key
),
player_all AS (     -- 需求条件：用户整体盈利
  SELECT member_id,
         SUM(net_pnl)  AS net_pnl_all,
         SUM(game_pnl) AS game_pnl_all,
         SUM(stake)    AS stake_all,
         SUM(CASE WHEN game_pnl >  0 THEN 1 ELSE 0 END) AS win_all,
         SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END) AS dec_all
  FROM pr GROUP BY member_id
),
pd AS (
  SELECT p.member_id, p.dealer_id,
         COUNT(*)                                          AS n_rounds_eff,
         SUM(p.n_orders_in_round)                          AS n_orders,
         SUM(p.stake)                                      AS stake,
         SUM(p.game_pnl)                                   AS game_pnl,
         SUM(p.net_pnl)                                    AS net_pnl,
         SUM(CASE WHEN p.game_pnl >  0 THEN 1 ELSE 0 END)  AS n_win,
         SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)  AS n_dec,
         AVG(COALESCE(s.p_base, 0.5))                      AS p_base_mix
  FROM pr p
  LEFT JOIN side_base s ON s.bet_side = p.main_side
  GROUP BY p.member_id, p.dealer_id
)
SELECT
  pd.member_id AS uid, pd.dealer_id,
  pd.stake      AS stake_amount,      -- 需求「投注金额」
  pd.game_pnl   AS profit_amount,     -- 需求「盈利金额」（剔返水口径）
  pd.net_pnl,
  pd.n_win * 1.0 / NULLIF(pd.n_dec, 0)              AS win_rate,          -- 需求「胜率」
  pd.n_orders  AS n_related_orders,                                       -- 需求「关联订单笔数」
  pd.n_rounds_eff, pd.p_base_mix,
  (pd.n_win - pd.n_dec * pd.p_base_mix)
    / NULLIF(SQRT(pd.n_dec * pd.p_base_mix * (1 - pd.p_base_mix)), 0)  AS z_score,
  pa.net_pnl_all, pa.game_pnl_all, pa.stake_all,
  pa.win_all * 1.0 / NULLIF(pa.dec_all, 0)          AS win_rate_all,
  (pa.win_all - pd.n_win) * 1.0
    / NULLIF(pa.dec_all - pd.n_dec, 0)              AS win_rate_other     -- ★ 对照检验
FROM pd
JOIN player_all pa ON pa.member_id = pd.member_id
WHERE pd.n_rounds_eff >= 30                 -- 阈值报告口径：有效局数下限
ORDER BY z_score DESC, profit_amount DESC;
/* ⚠️ 此处保留 n_rounds_eff>=30（阈值报告已论证 30 以下噪声主导），
   但**不加** win_rate>0.70 / net_pnl_all>0：四条规则对照表（@sec-r03 的 r03-dual）
   需要在同一份底料上比较需求原口径与修正口径，加了就比不了。 */


/* ───────────────────────────────────────────────────────────────────────────
   §T02 · T02_daily_roi.csv
   会员 × 日 的投注与游戏输赢序列 —— 索提诺 / CAS 的唯一输入
   对应报告：@sec-t2
   输出列：member_id, bet_date, stake, game_pnl, n_rounds
   预期行数：大。**必须切分导出**（见文末切分模板），或先加活跃度门槛。
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
act AS (   -- 报告里索提诺要求「活跃日 ≥ 20」，少于 20 天的会员导出来也用不上
  SELECT member_id FROM ord
  GROUP BY member_id HAVING COUNT(DISTINCT bet_date) >= 20
)
SELECT o.member_id, o.bet_date,
       SUM(o.stake)                     AS stake,
       SUM(o.game_pnl)                  AS game_pnl,
       COUNT(DISTINCT o.round_key)      AS n_rounds
FROM ord o JOIN act a ON a.member_id = o.member_id
GROUP BY o.member_id, o.bet_date
ORDER BY o.member_id, o.bet_date;


/* ───────────────────────────────────────────────────────────────────────────
   §T03 · T03_arbitrage.csv
   打水型：游戏输赢趋零 × 账户仍在赚 × 对押率高
   对应报告：@sec-t3
   输出列：member_id, stake, validbet, game_pnl, net_pnl, rebate,
           hedge_rate, stake_cv, n_rounds, n_days
   ★ hedge_rate 口径说明：此处为**自对押率**（同一物理局内该会员同时押到
     庄侧与闲侧的局数占比），是单表可算的打水指纹。
     **跨会员对押**（一庄一闲两个号）不在本查询范围，由 §R02 / C-06 并入。
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
o2 AS (
  SELECT member_id, bet_date, round_key,
         stake_raw / fx                AS stake,
         COALESCE(vb_raw,stake_raw)/fx AS validbet,
         (payout_raw - stake_raw)/fx   AS game_pnl,
         rebate_raw / fx               AS rebate,
         net_raw / fx                  AS net_pnl,
         CASE WHEN UPPER(TRIM(bet_side)) LIKE '%BANK%' THEN 1 ELSE 0 END AS is_b,
         CASE WHEN UPPER(TRIM(bet_side)) LIKE '%PLAY%' THEN 1 ELSE 0 END AS is_p
  FROM ord
),
rk AS (      -- 局级：该会员本局是否同时押了庄与闲（自对押）
  SELECT member_id, bet_date, round_key,
         SUM(stake) AS stake, SUM(validbet) AS validbet,
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
         CASE WHEN MAX(is_b)=1 AND MAX(is_p)=1 THEN 1 ELSE 0 END AS is_self_hedge
  FROM o2 GROUP BY member_id, bet_date, round_key
)
SELECT member_id,
       SUM(stake)                          AS stake,
       SUM(validbet)                       AS validbet,
       SUM(game_pnl)                       AS game_pnl,
       SUM(net_pnl)                        AS net_pnl,
       SUM(rebate)                         AS rebate,
       SUM(is_self_hedge) * 1.0 / COUNT(*) AS hedge_rate,     -- 自对押率
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0) AS stake_cv, -- 注额变异系数（打水者极低）
       COUNT(*)                            AS n_rounds,
       COUNT(DISTINCT bet_date)            AS n_days
FROM rk
GROUP BY member_id
HAVING COUNT(*) >= 100                       -- 局数太少算不出稳定的比率
ORDER BY hedge_rate DESC, validbet DESC;


/* ───────────────────────────────────────────────────────────────────────────
   §E02 · E02_segment_econ.csv
   分群单位经济学 —— 赏罚经济学引擎（@sec-econ）的唯一输入
   输出列：segment, n_member, validbet, ggr, rebate, commission, tenure_months
   口径：
     ggr        = -SUM(game_pnl)         庄家从该群赢到的钱（剔返水）
     rebate     =  SUM(rebate)           返水支出
     commission =  占成支出（**当前置 0**，见下方警告）
     tenure_months = 该群平均活跃月数（H 的经验代理，正式版应由 Cox/RSF 给出）
   分群：退水档位 × 洗码量四分位（均由数据算出，不写死档位）
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
mem AS (
  SELECT member_id,
         SUM(COALESCE(vb_raw,stake_raw)/fx)                       AS validbet,
         SUM((payout_raw - stake_raw)/fx)                         AS game_pnl,
         SUM(rebate_raw/fx)                                       AS rebate,
         COUNT(DISTINCT DATE_FORMAT(CAST(bet_date AS DATE),'%Y-%m'))            AS n_months,
         COUNT(DISTINCT bet_date)                                 AS n_days
  FROM ord GROUP BY member_id
),
mem2 AS (
  SELECT m.*,
         COALESCE(CAST(NULLIF(TRIM(d.mem003),'') AS DECIMAL(10,6)), 0) AS rebate_cfg,
         NTILE(4) OVER (ORDER BY m.validbet) AS vb_q
  FROM mem m
  LEFT JOIN ods_mariadb_2b.ods_a168_member_dtl d ON d.mem001 = m.member_id
  WHERE m.validbet > 0
)
SELECT
  CONCAT('退水', CAST(ROUND(rebate_cfg,4) AS STRING),
         ' · 流水Q', CAST(vb_q AS STRING))   AS segment,
  COUNT(*)                                   AS n_member,
  SUM(validbet)                              AS validbet,
  -SUM(game_pnl)                             AS ggr,          -- 庄家赢 = 玩家输
  SUM(rebate)                                AS rebate,
  0                                          AS commission,   -- ⚠️ 见下方警告
  AVG(n_months)                              AS tenure_months
FROM mem2
GROUP BY rebate_cfg, vb_q
ORDER BY validbet DESC;
/* ⚠️⚠️ commission（代理占成）当前恒置 0 —— 这是本包唯一一个**已知不完整**的字段。
   bet02 里的 commission 是「佣金模式标记」（免佣桌/一般桌），不是占成金额。
   信用盘占成惯例 1–2.5%，若不补齐，@sec-econ 算出的净贡献率会**系统性偏乐观**，
   δ* 偏小、γ* 偏大（赏得过头）。
   补齐路径：从代理合同表取各 LV 层占成比例，按 bet18–bet22 沿链分摊到会员。
   在补齐之前，E02 的 γ*（赏项上限）一律视为**上界估计，不得直接下发**。 */


/* ───────────────────────────────────────────────────────────────────────────
   §B01 · B01_bt_panel.csv
   会员 × 日 回测面板 —— 策略滚动回测（@sec-strategy-bt）的输入
   输出列：member_id, bet_date, stake, game_pnl, net_pnl, rebate, validbet,
           n_rounds, n_tables, n_ip, late_share_d, hedge_rate_d, stake_cv_d
   ★ 本查询**不产出 risk_score**：风险分是被拟合的量，由 R 侧
     compose_risk_score() 在各折训练窗内算出。SQL 只给原始特征，
     在 SQL 里预先算好风险分再回测 = 用全样本定分数 = 信息泄漏。
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id, r.ip AS bet_ip,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
rk AS (
  SELECT member_id, bet_date, round_key, MAX(table_id) AS table_id,
         MAX(bet_ip) AS bet_ip, MAX(round_no) AS round_no,
         SUM(stake_raw/fx)                     AS stake,
         SUM(COALESCE(vb_raw,stake_raw)/fx)    AS validbet,
         SUM((payout_raw-stake_raw)/fx)        AS game_pnl,
         SUM(rebate_raw/fx)                    AS rebate,
         SUM(net_raw/fx)                       AS net_pnl,
         CASE WHEN MAX(CASE WHEN UPPER(TRIM(bet_side)) LIKE '%BANK%' THEN 1 ELSE 0 END)=1
               AND MAX(CASE WHEN UPPER(TRIM(bet_side)) LIKE '%PLAY%' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END                AS is_self_hedge
  FROM ord GROUP BY member_id, bet_date, round_key
)
SELECT member_id, bet_date,
       SUM(stake)                                     AS stake,
       SUM(game_pnl)                                  AS game_pnl,
       SUM(net_pnl)                                   AS net_pnl,
       SUM(rebate)                                    AS rebate,
       SUM(validbet)                                  AS validbet,
       COUNT(*)                                       AS n_rounds,
       COUNT(DISTINCT table_id)                       AS n_tables,
       COUNT(DISTINCT bet_ip)                         AS n_ip,
       SUM(CASE WHEN round_no >= 50 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_share_d,
       SUM(is_self_hedge) * 1.0 / COUNT(*)            AS hedge_rate_d,
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)      AS stake_cv_d
FROM rk
GROUP BY member_id, bet_date
ORDER BY bet_date, member_id;


/* ───────────────────────────────────────────────────────────────────────────
   §K01 · K01_risk_feature_matrix.csv
   T4 扩样特征矩阵（@sec-t4）：会员级特征 + is_seed 种子标记
   ★ 种子必须**混合来源**（人工風險單 + R-01/R-02/R-03 + L0 金标准），
     否则 PU 模型学到的只是「某一条规则」，扩样等于把规则重跑一遍。
   ★ 特征侧**刻意排除**产生种子的那几个量（late_share / same_rate / z_score），
     否则就是自我循环。此处只给「行为结构」类特征。
   输出列：member_id, is_seed, n_rounds, n_days, n_tables, n_ip, n_dealer,
           side_entropy, stake_cv, stake_p90_p50, hedge_rate, rebate_dep,
           night_share, roi_game, validbet
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id,
         r.ip AS bet_ip, r.eid AS dealer_id, r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         HOUR(CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME)) AS bet_hour,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
side_mix AS (      -- 玩法熵：只押单一玩法（熵≈0）是打水/技术型的共同结构特征
  SELECT member_id, bet_side, COUNT(*) AS n_side
  FROM ord GROUP BY member_id, bet_side
),
side_ent AS (
  SELECT s.member_id,
         -SUM((s.n_side*1.0/t.n_all) * LOG2(s.n_side*1.0/t.n_all)) AS side_entropy
  FROM side_mix s
  JOIN (SELECT member_id, SUM(n_side) AS n_all FROM side_mix GROUP BY member_id) t
    ON t.member_id = s.member_id
  GROUP BY s.member_id
),
rk AS (
  SELECT member_id, bet_date, round_key,
         MAX(table_id) AS table_id, MAX(bet_ip) AS bet_ip,
         MAX(dealer_id) AS dealer_id, MAX(bet_hour) AS bet_hour,
         SUM(stake_raw/fx) AS stake,
         SUM(COALESCE(vb_raw,stake_raw)/fx) AS validbet,
         SUM((payout_raw-stake_raw)/fx) AS game_pnl,
         SUM(rebate_raw/fx) AS rebate,
         SUM(net_raw/fx)    AS net_pnl,
         CASE WHEN MAX(CASE WHEN UPPER(TRIM(bet_side)) LIKE '%BANK%' THEN 1 ELSE 0 END)=1
               AND MAX(CASE WHEN UPPER(TRIM(bet_side)) LIKE '%PLAY%' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END AS is_self_hedge
  FROM ord GROUP BY member_id, bet_date, round_key
),
feat AS (
  SELECT member_id,
         COUNT(*)                        AS n_rounds,
         COUNT(DISTINCT bet_date)        AS n_days,
         COUNT(DISTINCT table_id)        AS n_tables,
         COUNT(DISTINCT bet_ip)          AS n_ip,
         COUNT(DISTINCT dealer_id)       AS n_dealer,
         STDDEV_SAMP(stake)/NULLIF(AVG(stake),0)              AS stake_cv,
         PERCENTILE_APPROX(stake,0.9)
           / NULLIF(PERCENTILE_APPROX(stake,0.5),0)           AS stake_p90_p50,
         SUM(is_self_hedge)*1.0/COUNT(*)                      AS hedge_rate,
         SUM(rebate)/NULLIF(ABS(SUM(net_pnl)),0)              AS rebate_dep,
         SUM(CASE WHEN bet_hour BETWEEN 0 AND 6 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS night_share,
         SUM(game_pnl)/NULLIF(SUM(stake),0)                   AS roi_game,
         SUM(validbet)                                        AS validbet
  FROM rk GROUP BY member_id
),
seed_manual AS (   -- 种子来源①：人工風險單 / 劃單（L1a，唯一时间窗重叠的人工标签）
  SELECT DISTINCT member_id
  FROM ods_mariadb_2b.ods_a168_dailyreport_member
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
    AND (COALESCE(risk,0) > 0 OR COALESCE(orders,0) > 0)
),
seed_alert AS (    -- 种子来源②：L0 金标准 17 个关注 IP 下的会员
  SELECT DISTINCT o.member_id
  FROM ord o
  JOIN ods_mariadb_2b.ods_a168_alert_ip_setting a ON TRIM(a.ip) = TRIM(o.bet_ip)
)
SELECT f.member_id,
       CASE WHEN sm.member_id IS NOT NULL OR sa.member_id IS NOT NULL
            THEN 1 ELSE 0 END AS is_seed,
       f.n_rounds, f.n_days, f.n_tables, f.n_ip, f.n_dealer,
       COALESCE(se.side_entropy, 0) AS side_entropy,
       f.stake_cv, f.stake_p90_p50, f.hedge_rate, f.rebate_dep,
       f.night_share, f.roi_game, f.validbet
FROM feat f
LEFT JOIN side_ent   se ON se.member_id = f.member_id
LEFT JOIN seed_manual sm ON sm.member_id = f.member_id
LEFT JOIN seed_alert  sa ON sa.member_id = f.member_id
WHERE f.n_rounds >= 50
ORDER BY is_seed DESC, f.validbet DESC;
/* ★ 种子来源③④⑤（R-01 闸三 / R-02 Lift≥3 / R-03 Z≥4）在 R 侧并入：
   读 R01/R02/R03 三份 CSV，把命中会员的 is_seed 置 1 后再喂给 T4。
   本 SQL 只给出单表可得的两路种子（人工標記 + 金标准 IP），
   这样即使三份规则 CSV 尚未导出，T4 也能先跑起来。 */


/* ───────────────────────────────────────────────────────────────────────────
   §99 · 大表切分导出模板（T02 / B01 / K01 用得上）
   ★ 绝对不要用 OFFSET 翻页 —— 277 批数据 36.49% 重复的根因就是分页无稳定排序。
   正确做法：按 bet05 的哈希或数值区间切成 N 份，每份独立跑、独立导。
   ─────────────────────────────────────────────────────────────────────────── */
-- 第 k 份（k = 0..9，共 10 份）：在最外层 SELECT 之前的 ord/rk CTE 里加这一行
--   AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) % 10 = 0     -- ← 改 0,1,2,...,9
-- 导出 10 份后在 R 侧 rbind 即可；因为切分键是会员号，各份之间天然不重叠。

-- 切分前先确认每份大小：
SELECT CAST(NULLIF(TRIM(bet05),'') AS BIGINT) % 10 AS bucket,
       COUNT(*) AS n_rows, COUNT(DISTINCT bet05) AS n_member
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1' AND UPPER(TRIM(bet38)) = 'N'
GROUP BY CAST(NULLIF(TRIM(bet05),'') AS BIGINT) % 10
ORDER BY bucket;
