-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE_house_edge_SELECT_only_探针  ·  v1.1.0  ·  2026-09-03  ·  Ryo（雷欧）
-- ───────────────────────────────────────────────────────────────────────────────────────────────
-- 【身份】执行件（函数/）· 探针 · ⛔ 非交付件、非规范件 · ⛔ 未纳入 SQL 总包（理由见档尾【纳入裁定】）
-- 【v1.0.0 → v1.1.0 之斧正 —— 皆由 2026-09-03 Superset 实测回执定谳，非推测】
--   ⛔ 缺陷一（已修）：HE-02／HE-03 引用 x_base 而无 WITH 块
--        实测回执：starrocks error: Unknown table 'ods_mariadb_2b.x_base'
--   ⛔ 缺陷二（已修）：HE-04／HE-05 以逗号开头，非自足语句
--        实测回执：Unable to parse SQL ... near ',' at line 11:1 ／ line 6:1
--   ⇒ 今每闸各带**完整 WITH 块**，逐闸皆可单独整段贴入 SQL Lab 执行，不再「此处从略」。
--   ⛔ 另有一误诊须自陈：v1.0.0 交付时所见之 `400 Bad Request: The CSRF tokens do not match`
--      系 **Superset 前端会话／令牌失效**（HTTP 层），SQL 从未抵达 StarRocks，非 SQL 错误。
--      刷新重登后 HE-01 即以 9.000 秒跑通。⛔ 此类前端错误不得当作 SQL 错误去「修 SQL」。
-- 【体例说明】d_params 参数层 ＋ `FROM tbl b, d_params p` 逗号连接 ＋ CASE 内标量子查询
--   三者皆经 HE-01 实测在本 StarRocks 上**可执行**，故保留不改。
--   ⛔ 惟总包全档 d_params 出现 0 次、逗号连接 0 处、该类标量子查询 0 处——
--      故本体例仅适用于【探针】；若日后纳入总包，须先改写为总包体例（字面参数 ＋ 显式连接）。
-- 【口径 · 承 KILLCRITIC-01 正名】
--   ⛔ 本档所出者一律为 **realized（已实现，含运气）**，其正名为 `hold_valid_bet` / `edge_realized`。
--   ⛔ `house_edge` 一名**永久保留予【理论】优势**，不得用于任何 profit/valid_bet 之比值。
--      理论 edge 现状：NULL（授权未下；且 #017 探针 R3 实测 overdispersion Q/(k−1) = 9.3~42.6，
--      单一常数 edge 架构已被 KILL，纵获授权亦不得以静态单值映射）。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- 【HE-01 实测回归基线 · 2026-09-03 · 9.000 秒 · 23 面】——重跑须与此对账，不符即须查
--   Σn_orders 124,713,543 ｜ Σstake 13,436,093,473.3334 ｜ Σvalid_bet 12,101,545,164.6446
--   Σprofit 225,932,201.2126
--   hold_valid_bet（profit/valid_bet） = 1.86696986 %      ← 与 S01 会员级 1.866970 % 相符
--   hold_rate     （profit/stake）     = 1.68153192 %      ← 与 S01 会员级 1.681532 % 相符
--   valid_bet/stake                    = 90.06743804 %      ← 与 S01 90.067438 % 相符
--   ⇒ 三路互证闭合：SQL 探针 ↔ 审计/实测庄家优势_逐投注面 ↔ S01_player_score（723,442 会员）。
--   ⇒ 与审计件之逐面对账：金额三项最大绝对差 ≤ 0.0050（分币级舍入）；
--      注单数差 −11,737（−0.009410%），差额行金额合计为 0 ⇒ 系零额注单之计数口径差，非口径断裂。
--   ⇒ 逐面证据：16 面 OK ／ 7 面 NO_EVIDENCE（n = 1，皆 10 元零盈亏，一律禁入任何加权）。
--   ⇒ 洗码折扣只落在 6 面（valid_over_stake < 1）：Banker 0.89588406、Player 0.89817489、
--      BankerDragonBonus 0.98199111、PlayerDragonBonus 0.98239240、BankerNatural 0.98334541、
--      PlayerNatural 0.97884579；此 6 面占全体洗码 96.0560 %。其余 17 面 valid_over_stake = 1。
--      ⇒ 故「对本金」与「对洗码」两分母之 9.93 个百分点落差，几乎全由 Banker／Player 二面所致。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-01 · 产品码宇宙与逐面已实现 edge（hold_valid_bet）           【自足 · 可单独执行】
--   问：数据库实际存在多少种 bet09？各面之【已实现】庄家优势为何？证据够不够？
--   ⛔ 出数即须并呈 n_orders 与置信半宽；n 小者一律标「无证据」，禁入任何加权。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet15, b.bet16, b.bet17, b.bet23,
         b.bet38, b.bet39, b.category, b.commission, b.validbet, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
                            ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn
  FROM ods_mariadb_2b.ods_a168_bet02 b, d_params p
  WHERE b.dt >= p.win_lo AND b.dt < p.win_hi
    AND b.bet02 = '101'
    AND b.sync_time <= p.snap
),
x_testagent AS (                                  -- 测试线代理（age022 = '1'）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
x_base AS (                                       -- 清洗后之注单面（已剔测试线）
  SELECT r.bet09                                                              AS bet_side
       , CASE WHEN TRIM(r.commission) = '1' THEN 1 ELSE 0 END                 AS is_freecomm
       , r.bet39                                                              AS table_id
       , r.bet05                                                              AS member_id
       , CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS stake
       , CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS valid_bet
       , -CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS profit   -- ★ 平台视角
       , CAST(NULLIF(TRIM(r.bet15),'') AS DECIMAL(20,6))                      AS rebate_pct
       , COALESCE(CAST(NULLIF(TRIM(r.bet23),'') AS DECIMAL(20,6)), 0)         AS company_pct
  FROM x_ranked r
  LEFT JOIN x_testagent t1 ON t1.agent_id = r.bet18
  LEFT JOIN x_testagent t2 ON t2.agent_id = r.bet19
  LEFT JOIN x_testagent t3 ON t3.agent_id = r.bet20
  LEFT JOIN x_testagent t4 ON t4.agent_id = r.bet21
  LEFT JOIN x_testagent t5 ON t5.agent_id = r.bet22
  WHERE r.x_rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id, t4.agent_id, t5.agent_id) IS NULL
)
SELECT b.bet_side
     , COUNT(*)                                                        AS n_orders
     , COUNT(DISTINCT b.member_id)                                     AS n_member
     , ROUND(SUM(b.stake), 4)                                          AS stake
     , ROUND(SUM(b.valid_bet), 4)                                      AS valid_bet
     , ROUND(SUM(b.profit), 4)                                         AS profit
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.valid_bet), 0), 8)           AS hold_valid_bet   -- ★ 对洗码（已实现）
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.stake), 0), 8)               AS hold_rate        -- ★ 对本金（已实现）
     , ROUND(SUM(b.valid_bet) / NULLIF(SUM(b.stake), 0), 8)            AS valid_over_stake
     -- 置信半宽（粗略 CLT，以单注赔付率之样本标准差近似；只作证据强度旗标，非严格 CI）
     , ROUND(1.959964 * STDDEV_SAMP(b.profit / NULLIF(b.valid_bet, 0))
             / SQRT(COUNT(*)), 8)                                      AS ci95_halfwidth_crude
     -- 暴露权之有效样本量 ESS = (Σw)² / Σw²，w = valid_bet；ESS ≪ n 即证「加权后信息已压缩到极少数注单」
     , ROUND(POW(SUM(b.valid_bet), 2) / NULLIF(SUM(b.valid_bet * b.valid_bet), 0), 1) AS ess_valid_bet
     , ROUND(POW(SUM(b.valid_bet), 2) / NULLIF(SUM(b.valid_bet * b.valid_bet), 0)
             / NULLIF(COUNT(*), 0), 8)                                 AS ess_ratio
     , CASE WHEN COUNT(*) >= (SELECT min_orders_evid FROM d_params)
            THEN 'OK' ELSE 'NO_EVIDENCE' END                           AS evidence_flag
     , CASE WHEN POW(SUM(b.valid_bet), 2) / NULLIF(SUM(b.valid_bet * b.valid_bet), 0)
                 / NULLIF(COUNT(*), 0) < 0.01
            THEN 'THIN_WEIGHTED_EVIDENCE' ELSE 'OK' END                AS weight_evidence_flag
     , 'realized（已实现，含运气）· ⛔ 非理论 house_edge'                AS caliber
FROM x_base b
GROUP BY b.bet_side
ORDER BY valid_bet DESC;
--   ⇒ 回归对账：全体 hold_valid_bet 应 ≈ 1.86696986 %，hold_rate ≈ 1.68153192 %（见档头基线）。
--   ⇒ evidence_flag = 'NO_EVIDENCE' 之面一律不得进入 HE-04 之 theo 加权。
--   ⇒ weight_evidence_flag = 'THIN_WEIGHTED_EVIDENCE'（ESS/n < 1%）者，其加权估计之实际信息量
--      远低于注单数所示，⛔ 禁以 n 大冒充证据强。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-02 · 产品 × 免佣模式：bet09 一元是否足以定 edge？             【自足 · 可单独执行】
--   ⛔ v1.0.0 实测回执：Unknown table 'ods_mariadb_2b.x_base' —— 因缺 WITH 块，今已自足。
--   本闸系「免佣桌不可与一般桌共用一个 edge」之实测化。
--   前测（DX04_bet09_profile）：Banker 免佣/一般之比 1.036、Player 0.907、PPair 1.429、
--   PerfectPair 1.741、BankerDragonBonus 1.264 ⇒ 外部所称「约 1.90 倍」于本窗**不成立**
--   （实测最大 1.741），然「免佣确使 edge 变动」之**结论方向成立**。本闸即为定谳。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet15, b.bet16, b.bet17, b.bet23,
         b.bet38, b.bet39, b.category, b.commission, b.validbet, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
                            ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn
  FROM ods_mariadb_2b.ods_a168_bet02 b, d_params p
  WHERE b.dt >= p.win_lo AND b.dt < p.win_hi
    AND b.bet02 = '101'
    AND b.sync_time <= p.snap
),
x_testagent AS (                                  -- 测试线代理（age022 = '1'）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
x_base AS (                                       -- 清洗后之注单面（已剔测试线）
  SELECT r.bet09                                                              AS bet_side
       , CASE WHEN TRIM(r.commission) = '1' THEN 1 ELSE 0 END                 AS is_freecomm
       , r.bet39                                                              AS table_id
       , r.bet05                                                              AS member_id
       , CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS stake
       , CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS valid_bet
       , -CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS profit   -- ★ 平台视角
       , CAST(NULLIF(TRIM(r.bet15),'') AS DECIMAL(20,6))                      AS rebate_pct
       , COALESCE(CAST(NULLIF(TRIM(r.bet23),'') AS DECIMAL(20,6)), 0)         AS company_pct
  FROM x_ranked r
  LEFT JOIN x_testagent t1 ON t1.agent_id = r.bet18
  LEFT JOIN x_testagent t2 ON t2.agent_id = r.bet19
  LEFT JOIN x_testagent t3 ON t3.agent_id = r.bet20
  LEFT JOIN x_testagent t4 ON t4.agent_id = r.bet21
  LEFT JOIN x_testagent t5 ON t5.agent_id = r.bet22
  WHERE r.x_rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id, t4.agent_id, t5.agent_id) IS NULL
)
SELECT b.bet_side
     , b.is_freecomm
     , COUNT(*)                                                        AS n_orders
     , ROUND(SUM(b.stake), 4)                                          AS stake
     , ROUND(SUM(b.valid_bet), 4)                                      AS valid_bet
     , ROUND(SUM(b.valid_bet) / NULLIF(SUM(b.stake), 0), 8)            AS valid_over_stake
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.valid_bet), 0), 8)           AS hold_valid_bet
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.stake), 0), 8)               AS hold_rate
     , ROUND(1.959964 * STDDEV_SAMP(b.profit / NULLIF(b.valid_bet, 0))
             / SQRT(COUNT(*)), 8)                                      AS ci95_halfwidth_crude
FROM x_base b
GROUP BY b.bet_side, b.is_freecomm
ORDER BY b.bet_side, b.is_freecomm;
--   ⇒ 判读：同一 bet_side 之二行，若 |edge 差额| > 两侧 CI 半宽之和，即证 bet09 一元【不足】定 edge，
--     映射表主键须为 (bet09, is_freecomm) 二元。⛔ 然纵为二元亦只是分层常数——
--     #017 R3 之 overdispersion 9.3~42.6 已否决【单一常数】架构，仍须带区间或分布，禁静态单值。
--   ⇒ 欲再验桌级异质，把 GROUP BY 改为 (bet_side, is_freecomm, table_id) 即可；本探针不预设结论。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-03 · 覆盖率闸：未过证据门之产品占多少量？                     【自足 · 可单独执行】
--   ⛔ v1.0.0 实测回执：Unknown table 'ods_mariadb_2b.x_base' —— 因缺 WITH 块，今已自足。
--   ⛔ 未知／无证据产品**不得吞掉**，须出 valid_bet_unmapped 与 mapped_coverage_rate 两数。
--   ⛔ 未知产品 → theo = NULL，禁 fallback = 1（NULL ≠ 0）。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet15, b.bet16, b.bet17, b.bet23,
         b.bet38, b.bet39, b.category, b.commission, b.validbet, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
                            ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn
  FROM ods_mariadb_2b.ods_a168_bet02 b, d_params p
  WHERE b.dt >= p.win_lo AND b.dt < p.win_hi
    AND b.bet02 = '101'
    AND b.sync_time <= p.snap
),
x_testagent AS (                                  -- 测试线代理（age022 = '1'）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
x_base AS (                                       -- 清洗后之注单面（已剔测试线）
  SELECT r.bet09                                                              AS bet_side
       , CASE WHEN TRIM(r.commission) = '1' THEN 1 ELSE 0 END                 AS is_freecomm
       , r.bet39                                                              AS table_id
       , r.bet05                                                              AS member_id
       , CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS stake
       , CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS valid_bet
       , -CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS profit   -- ★ 平台视角
       , CAST(NULLIF(TRIM(r.bet15),'') AS DECIMAL(20,6))                      AS rebate_pct
       , COALESCE(CAST(NULLIF(TRIM(r.bet23),'') AS DECIMAL(20,6)), 0)         AS company_pct
  FROM x_ranked r
  LEFT JOIN x_testagent t1 ON t1.agent_id = r.bet18
  LEFT JOIN x_testagent t2 ON t2.agent_id = r.bet19
  LEFT JOIN x_testagent t3 ON t3.agent_id = r.bet20
  LEFT JOIN x_testagent t4 ON t4.agent_id = r.bet21
  LEFT JOIN x_testagent t5 ON t5.agent_id = r.bet22
  WHERE r.x_rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id, t4.agent_id, t5.agent_id) IS NULL
)
SELECT COUNT(*)                                                                       AS n_orders_all
     , ROUND(SUM(b.valid_bet), 4)                                                     AS valid_bet_all
     , SUM(CASE WHEN e.bet_side IS NULL THEN 1 ELSE 0 END)                            AS n_orders_unmapped
     , ROUND(SUM(CASE WHEN e.bet_side IS NULL THEN b.valid_bet ELSE 0 END), 4)        AS valid_bet_unmapped
     , ROUND(1 - SUM(CASE WHEN e.bet_side IS NULL THEN b.valid_bet ELSE 0 END)
                 / NULLIF(SUM(b.valid_bet), 0), 8)                                    AS mapped_coverage_rate
FROM x_base b
LEFT JOIN (
  SELECT bet_side FROM x_base GROUP BY bet_side
  HAVING COUNT(*) >= (SELECT min_orders_evid FROM d_params)
) e ON e.bet_side = b.bet_side;
--   ⇒ 验收：mapped_coverage_rate 须 ≥ 0.999；不足者须先查产品字典，禁带病进 HE-04。
--   ⇒ 2026-09-03 预期：7 面无证据，各 1 注 10 元 ⇒ 未映射洗码 70 元，覆盖率 ≈ 0.9999999942。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-04 · 会员级 theo（已实现口径）：theo_realized = Σ(valid_bet × edge_realized)  【自足】
--   ⛔ v1.0.0 实测回执：Unable to parse SQL ... near ',' —— 因以逗号开头，今已自足。
--   ⛔ 前三闸皆过方准跑本闸。
--   ⛔ 本 theo 系【已实现】口径之期望值代理，**非理论 theo**：其 edge 取自同窗同批之已实现值，
--      故对本窗近乎恒等式（Σ 会员 theo ≈ Σ profit），只可作【分摊】与【结构】之用，
--      ⛔ 绝不可用以宣称「该会员理论上应输多少」，亦不可外推至他窗。
--   ⛔ 真正之理论 theo 须待：① 理论 edge 授权；② x_prod（会员 × 产品）粒度；
--      ③ 承 #017 R3，edge 须带分布或分层而非单一常数。三者未齐前，本闸只出已实现口径。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet15, b.bet16, b.bet17, b.bet23,
         b.bet38, b.bet39, b.category, b.commission, b.validbet, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
                            ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn
  FROM ods_mariadb_2b.ods_a168_bet02 b, d_params p
  WHERE b.dt >= p.win_lo AND b.dt < p.win_hi
    AND b.bet02 = '101'
    AND b.sync_time <= p.snap
),
x_testagent AS (                                  -- 测试线代理（age022 = '1'）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
x_base AS (                                       -- 清洗后之注单面（已剔测试线）
  SELECT r.bet09                                                              AS bet_side
       , CASE WHEN TRIM(r.commission) = '1' THEN 1 ELSE 0 END                 AS is_freecomm
       , r.bet39                                                              AS table_id
       , r.bet05                                                              AS member_id
       , CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS stake
       , CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS valid_bet
       , -CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS profit   -- ★ 平台视角
       , CAST(NULLIF(TRIM(r.bet15),'') AS DECIMAL(20,6))                      AS rebate_pct
       , COALESCE(CAST(NULLIF(TRIM(r.bet23),'') AS DECIMAL(20,6)), 0)         AS company_pct
  FROM x_ranked r
  LEFT JOIN x_testagent t1 ON t1.agent_id = r.bet18
  LEFT JOIN x_testagent t2 ON t2.agent_id = r.bet19
  LEFT JOIN x_testagent t3 ON t3.agent_id = r.bet20
  LEFT JOIN x_testagent t4 ON t4.agent_id = r.bet21
  LEFT JOIN x_testagent t5 ON t5.agent_id = r.bet22
  WHERE r.x_rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id, t4.agent_id, t5.agent_id) IS NULL
),
x_edge AS (                                          -- 逐面已实现 edge（只取过证据门者）
  SELECT bet_side
       , SUM(profit) / NULLIF(SUM(valid_bet), 0) AS edge_realized
       , COUNT(*)                                AS n_orders
  FROM x_base
  GROUP BY bet_side
  HAVING COUNT(*) >= (SELECT min_orders_evid FROM d_params)
),
x_mp AS (                                            -- 会员 × 产品之洗码分解（theo 之必需粒度）
  SELECT member_id, bet_side, SUM(valid_bet) AS valid_bet, SUM(profit) AS profit
  FROM x_base
  GROUP BY member_id, bet_side
)
SELECT m.member_id
     , ROUND(SUM(m.valid_bet), 4)                                              AS valid_bet_all
     , ROUND(SUM(CASE WHEN e.bet_side IS NULL THEN m.valid_bet ELSE 0 END), 4) AS valid_bet_unmapped
     , CASE WHEN SUM(CASE WHEN e.bet_side IS NULL THEN 1 ELSE 0 END) > 0
            THEN NULL                                                          -- ⛔ 有未映射面 ⇒ theo 判 NULL
            ELSE ROUND(SUM(m.valid_bet * e.edge_realized), 4) END              AS theo_realized
     , ROUND(SUM(m.profit), 4)                                                 AS profit_actual
     , CASE WHEN SUM(CASE WHEN e.bet_side IS NULL THEN 1 ELSE 0 END) > 0
            THEN 'NULL_UNMAPPED_PRODUCT'
            ELSE 'OK_REALIZED_CALIBER' END                                     AS theo_status
FROM x_mp m
LEFT JOIN x_edge e ON e.bet_side = m.bet_side
GROUP BY m.member_id
ORDER BY valid_bet_all DESC;
--   ⇒ 下游：theo → ADT → NMPT → ESI 之顺序合法，然在【已实现】口径下只作结构分摊，
--     ⛔ 未获理论 edge 授权前，禁以之出赏罚线、禁以之定客户等级。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-05 · 免佣 vs 一般之差异检定（两样本 z 检定，SELECT 内现算）    【自足 · 可单独执行】
--   ⛔ v1.0.0 实测回执：Unable to parse SQL ... near ',' —— 因以逗号开头，今已自足。
--   ⛔ 只出统计量与判读界，不出结论文字；结论由人裁。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet15, b.bet16, b.bet17, b.bet23,
         b.bet38, b.bet39, b.category, b.commission, b.validbet, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
                            ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn
  FROM ods_mariadb_2b.ods_a168_bet02 b, d_params p
  WHERE b.dt >= p.win_lo AND b.dt < p.win_hi
    AND b.bet02 = '101'
    AND b.sync_time <= p.snap
),
x_testagent AS (                                  -- 测试线代理（age022 = '1'）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
x_base AS (                                       -- 清洗后之注单面（已剔测试线）
  SELECT r.bet09                                                              AS bet_side
       , CASE WHEN TRIM(r.commission) = '1' THEN 1 ELSE 0 END                 AS is_freecomm
       , r.bet39                                                              AS table_id
       , r.bet05                                                              AS member_id
       , CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS stake
       , CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS valid_bet
       , -CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS profit   -- ★ 平台视角
       , CAST(NULLIF(TRIM(r.bet15),'') AS DECIMAL(20,6))                      AS rebate_pct
       , COALESCE(CAST(NULLIF(TRIM(r.bet23),'') AS DECIMAL(20,6)), 0)         AS company_pct
  FROM x_ranked r
  LEFT JOIN x_testagent t1 ON t1.agent_id = r.bet18
  LEFT JOIN x_testagent t2 ON t2.agent_id = r.bet19
  LEFT JOIN x_testagent t3 ON t3.agent_id = r.bet20
  LEFT JOIN x_testagent t4 ON t4.agent_id = r.bet21
  LEFT JOIN x_testagent t5 ON t5.agent_id = r.bet22
  WHERE r.x_rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id, t4.agent_id, t5.agent_id) IS NULL
),
x_fc AS (
  SELECT bet_side, is_freecomm
       , COUNT(*)                                          AS n
       , SUM(profit) / NULLIF(SUM(valid_bet), 0)           AS edge
       , STDDEV_SAMP(profit / NULLIF(valid_bet, 0))        AS sd
  FROM x_base GROUP BY bet_side, is_freecomm
)
SELECT a.bet_side
     , a.n AS n_freecomm,  ROUND(a.edge, 8) AS edge_freecomm
     , b.n AS n_normal,    ROUND(b.edge, 8) AS edge_normal
     , ROUND(a.edge - b.edge, 8)                                              AS edge_diff
     , ROUND(a.edge / NULLIF(b.edge, 0), 6)                                   AS edge_ratio
     , ROUND((a.edge - b.edge)
             / NULLIF(SQRT(a.sd*a.sd/NULLIF(a.n,0) + b.sd*b.sd/NULLIF(b.n,0)), 0), 4) AS z_stat
     , CASE WHEN ABS((a.edge - b.edge)
             / NULLIF(SQRT(a.sd*a.sd/NULLIF(a.n,0) + b.sd*b.sd/NULLIF(b.n,0)), 0)) >= 1.959964
            THEN 'DIFFERENT_AT_5PCT' ELSE 'NOT_DISTINGUISHED' END             AS verdict_5pct
FROM x_fc a
JOIN x_fc b ON b.bet_side = a.bet_side AND a.is_freecomm = 1 AND b.is_freecomm = 0
ORDER BY a.n + b.n DESC;
--   ⇒ 凡 verdict_5pct = 'DIFFERENT_AT_5PCT' 之面，其 edge 映射表主键**必须**含 is_freecomm。
--   ⇒ ⛔ 本闸只判「是否可区分」，不判「差多少倍可接受」——后者属商业裁定，不属统计。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-06 · 【新增】加权口径闸：等权均值 vs 暴露加权，究竟差多少？   【自足 · 可单独执行】
--   立意：总包六层块内 AVG(x_agpct)／AVG(x_rate1..5)／AVG(x_rbpct)／AVG(x_freecomm) 各 194 处，
--         皆系**逐注等权**均值；而金额口径（hold 等）一律 Σ/Σ 之**暴露加权**。二者不同口径。
--   ⛔ 本闸只**度量差异**，不改总包、不主张替换。差异小者即无须加权；差异大者方入加权候选。
--   ⛔ 承 KILL-W01：暴露权与精度权高度同向（R 侧实测 Spearman = 1.000000），二者并用即重复计权。
--   ⛔ 承 KILL-W02：结果变量（profit／residual_b）禁作权重，故本闸之权一律取 valid_bet／stake。
--   并出 ESS 与集中度：ESS = (Σw)²/Σw²；ESS/n < 1% 即 THIN_WEIGHTED_EVIDENCE。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet15, b.bet16, b.bet17, b.bet23,
         b.bet38, b.bet39, b.category, b.commission, b.validbet, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
                            ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn
  FROM ods_mariadb_2b.ods_a168_bet02 b, d_params p
  WHERE b.dt >= p.win_lo AND b.dt < p.win_hi
    AND b.bet02 = '101'
    AND b.sync_time <= p.snap
),
x_testagent AS (                                  -- 测试线代理（age022 = '1'）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
x_base AS (                                       -- 清洗后之注单面（已剔测试线）
  SELECT r.bet09                                                              AS bet_side
       , CASE WHEN TRIM(r.commission) = '1' THEN 1 ELSE 0 END                 AS is_freecomm
       , r.bet39                                                              AS table_id
       , r.bet05                                                              AS member_id
       , CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS stake
       , CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS valid_bet
       , -CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))                  AS profit   -- ★ 平台视角
       , CAST(NULLIF(TRIM(r.bet15),'') AS DECIMAL(20,6))                      AS rebate_pct
       , COALESCE(CAST(NULLIF(TRIM(r.bet23),'') AS DECIMAL(20,6)), 0)         AS company_pct
  FROM x_ranked r
  LEFT JOIN x_testagent t1 ON t1.agent_id = r.bet18
  LEFT JOIN x_testagent t2 ON t2.agent_id = r.bet19
  LEFT JOIN x_testagent t3 ON t3.agent_id = r.bet20
  LEFT JOIN x_testagent t4 ON t4.agent_id = r.bet21
  LEFT JOIN x_testagent t5 ON t5.agent_id = r.bet22
  WHERE r.x_rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id, t4.agent_id, t5.agent_id) IS NULL
)
SELECT b.bet_side
     , COUNT(*)                                                                AS n_orders
     , ROUND(SUM(b.valid_bet), 4)                                              AS valid_bet
     -- ① 公司自留比例（bet23）：等权 vs 暴露加权
     , ROUND(AVG(b.company_pct), 6)                                            AS company_pct_unw
     , ROUND(SUM(b.company_pct * b.valid_bet) / NULLIF(SUM(b.valid_bet), 0), 6) AS company_pct_w
     , ROUND(SUM(b.company_pct * b.valid_bet) / NULLIF(SUM(b.valid_bet), 0)
             - AVG(b.company_pct), 6)                                          AS company_pct_gap
     -- ② 退水比例（bet15）：等权 vs 暴露加权
     , ROUND(AVG(b.rebate_pct), 6)                                             AS rebate_pct_unw
     , ROUND(SUM(b.rebate_pct * b.valid_bet) / NULLIF(SUM(b.valid_bet), 0), 6) AS rebate_pct_w
     , ROUND(SUM(b.rebate_pct * b.valid_bet) / NULLIF(SUM(b.valid_bet), 0)
             - AVG(b.rebate_pct), 6)                                           AS rebate_pct_gap
     -- ③ 免佣比例：等权（占注单数）vs 暴露加权（占洗码）
     , ROUND(AVG(b.is_freecomm * 1.0), 6)                                      AS freecomm_unw
     , ROUND(SUM(b.is_freecomm * b.valid_bet) / NULLIF(SUM(b.valid_bet), 0), 6) AS freecomm_w
     , ROUND(SUM(b.is_freecomm * b.valid_bet) / NULLIF(SUM(b.valid_bet), 0)
             - AVG(b.is_freecomm * 1.0), 6)                                    AS freecomm_gap
     -- ④ 权重诊断：有效样本量与集中度
     , ROUND(POW(SUM(b.valid_bet), 2) / NULLIF(SUM(b.valid_bet * b.valid_bet), 0), 1) AS ess_valid_bet
     , ROUND(POW(SUM(b.valid_bet), 2) / NULLIF(SUM(b.valid_bet * b.valid_bet), 0)
             / NULLIF(COUNT(*), 0), 8)                                         AS ess_ratio
     , ROUND(MAX(b.valid_bet), 4)                                              AS w_max
     , ROUND(AVG(b.valid_bet), 4)                                              AS w_mean
     , ROUND(MAX(b.valid_bet) / NULLIF(AVG(b.valid_bet), 0), 2)                AS w_max_over_mean
     , CASE WHEN POW(SUM(b.valid_bet), 2) / NULLIF(SUM(b.valid_bet * b.valid_bet), 0)
                 / NULLIF(COUNT(*), 0) < 0.01
            THEN 'THIN_WEIGHTED_EVIDENCE' ELSE 'OK' END                        AS weight_evidence_flag
FROM x_base b
GROUP BY b.bet_side
ORDER BY valid_bet DESC;
--   ⇒ 判读一：*_gap 之绝对值即「等权与暴露加权之口径差」。差近 0 者，加权无收益，一律不加。
--   ⇒ 判读二：ess_ratio 极小者，纵然加权更贴近「钱的真相」，其有效样本亦极少 ——
--      ⛔ 须并报 ESS，禁以 n_orders 冒充证据强度。
--   ⇒ 判读三：本闸只度量，不裁决；是否加权须再过 R 侧之 OOS 对照（加权前后 RMSE／秩稳定性）。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- 【纳入 SQL 总包之裁定 —— 2026-09-03】⛔ 暂不纳入。三条可核理由：
--   ① 总包 133 模块**每一件对应一个落盘 csv**，引擎 tr_sql_of() 之溯源即以「模块 ↔ 交付件」为键；
--      本档系诊断探针，无交付件可挂，塞入即破坏该一一对应。
--   ② 总包模块头体例为 `-- NNN. 件名.csv [总包行 A~B · 原 N 列 ＋六层约 60 列]` ＋ `-- ▸ 导出：…`；
--      本档无 csv 名可填。
--   ③ 承「先验血统、后验册」：v1.0.0 五闸中四闸从未成功执行；v1.1.0 修毕后须先逐闸跑通并对账，
--      方可议纳入。
--   ⇒ 若日后确须常态化，建议以**新增交付件** `#134 HE01_bet_side_edge.csv` 之形式纳入（只增不减），
--      并同时把体例改写为总包式（字面参数、显式连接、audit_rn 全序、run_id／snapshot_sync_time）。
-- ───────────────────────────────────────────────────────────────────────────────────────────────
-- 【自证 · 零写操作】本档全文不含 CREATE / INSERT / UPDATE / DELETE / DROP / TRUNCATE / ALTER /
--   MERGE / REPLACE / LOAD / EXPORT 任一关键字之执行用法（除本行与注释之陈述外）。
--   验证法：对本档做大小写不敏感之关键字扫描，命中数须恰等于注释内之陈述次数。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
