-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE_house_edge_SELECT_only_探针  ·  v1.0.0  ·  2026-09-03  ·  Ryo（雷欧）
-- ───────────────────────────────────────────────────────────────────────────────────────────────
-- 【身份】执行件（函数/）· 探针 · ⛔ 非交付件、非规范件
-- 【立意】承先生令：「在没有 CREATE、APPEND、DELETE 的权限之下，只需要通过 SELECT 后实测
--         甚至计算出 house_edge 即可」。本档即以【纯 SELECT】五闸实测已实现庄家优势，
--         全档零 CREATE／零 INSERT／零 UPDATE／零 DELETE／零 DROP／零 TRUNCATE，
--         只读 ods_mariadb_2b.ods_a168_bet02 与 ods_mariadb_2b.ods_a168_agent 两表。
-- 【口径】realized（已实现，含运气）· ⛔ **非理论 edge**。
--         理论 edge 之授权未下，且 #017 探针 R3 实测 overdispersion Q/(k−1) = 9.3~42.6，
--         已 KILL single-constant-edge 架构 —— 故纵获授权，(bet09 × 免佣) 之【单一常数】亦不成立。
--         本档只出【已实现】，绝不冒充理论值，亦不据以反推 theo 而不附区间。
-- 【与总包之关系】过滤器与折算逐条对齐 a168_SQL总包_v12_0_0_HF9g-P5D_*版_六层商业版_OPT：
--         去重 rn = 1（PARTITION BY bet01，取 updatetime／sync_time／dt 最新一版）
--         bet02 = '101'（百家乐）· category = '1'（一般注单）· UPPER(TRIM(bet38)) = 'N'（非测试单）
--         bet11 > 0（汇率）· dt ∈ [窗起, 窗迄)· sync_time <= 快照 · 五级代理 age022 = '1' 左连剔测试线
-- 【金额折算】stake = bet13/bet11 · valid_bet = validbet/bet11 · net = bet17/bet11（玩家视角）
--            profit（平台毛赢）= −net · rebate = bet16/bet11
-- 【已实测基线（2026-09-03，供本探针回归对账）】
--         全平台 Σstake 13,436,093,473.804 · Σvalid_bet 12,101,545,165.175 · Σprofit 225,932,201.626
--         profit/stake = 1.681532 % · profit/valid_bet = 1.866970 % · valid_bet/stake = 90.067438 %
--         逐面例（vs valid_bet）：Banker 1.301961 % · Player 1.351856 % · Tie 15.060458 % · Super6 20.573010 %
-- 【用法】Superset ／ StarRocks 内逐闸单跑；参数只在 d_params 一处改，全档禁他处再写字面。
--         ⛔ 闸序不可颠倒：HE-01 → HE-02 → HE-03 三闸皆过，方准跑 HE-04 之 theo。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════


-- ═══ HE-00 · 共用口径层（三闸逐字同文；改一处须处处同改）════════════════════════════════════
--     说明：StarRocks 不支持跨语句临时视图之免权限落盘，故各闸各自内联本层，禁抽出建表。
--     以下 WITH 块即「共用口径层」，逐闸复制粘贴，不得改动其内任何谓词。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-01 · 产品码宇宙与逐面已实现 edge
--   问：数据库实际存在多少种 bet09？各面之已实现庄家优势为何？证据够不够？
--   ⛔ 出数即须并呈 n_orders 与置信半宽；n 小者一律标「无证据」，禁入任何加权。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
WITH d_params AS (
  SELECT '2026-03-21'          AS win_lo          -- 观测窗起（左闭）
       , '2026-08-07'          AS win_hi          -- 观测窗迄（右开）
       , '2026-08-27 09:00:00' AS snap            -- 快照闸：冻结同步时点，令重跑可复现
       , 30                    AS min_orders_evid -- 证据门：注单数低于此即标「无证据」
),
x_ranked AS (                                     -- 同注单号多版本，只取最新一版（与总包同式）
  SELECT b.bet01, b.bet05, b.bet09, b.bet11, b.bet13, b.bet16, b.bet17, b.bet38, b.bet39,
         b.category, b.commission, b.validbet, b.dt,
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
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.valid_bet), 0), 8)           AS edge_vs_valid_bet  -- ★ 对洗码
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.stake), 0), 8)               AS edge_vs_stake      -- ★ 对本金
     , ROUND(SUM(b.valid_bet) / NULLIF(SUM(b.stake), 0), 8)            AS valid_over_stake
     -- 置信半宽（粗略 CLT，以单注赔付率之样本标准差近似；只作证据强度旗标，非严格 CI）
     , ROUND(1.959964 * STDDEV_SAMP(b.profit / NULLIF(b.valid_bet, 0))
             / SQRT(COUNT(*)), 8)                                      AS ci95_halfwidth_crude
     , CASE WHEN COUNT(*) >= (SELECT min_orders_evid FROM d_params)
            THEN 'OK' ELSE 'NO_EVIDENCE' END                           AS evidence_flag
     , 'realized（已实现，含运气）· 非理论 edge'                         AS caliber
FROM x_base b
GROUP BY b.bet_side
ORDER BY valid_bet DESC;
--   ⇒ 回归对账：本闸 SUM 后之全体 profit/valid_bet 应 ≈ 1.866970 %，profit/stake ≈ 1.681532 %。
--   ⇒ evidence_flag = 'NO_EVIDENCE' 之面一律不得进入 HE-04 之 theo 加权。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-02 · 产品 × 免佣模式（× 桌）：bet09 一元是否足以定 edge？
--   ⛔ 本闸系《参考.txt》所指「免佣桌不可与一般桌共用一个 edge」之实测化；
--      2026-09-03 以 DX04_bet09_profile 先测得：主力面 Banker 免佣/一般之比 1.036、Player 0.907，
--      而 PPair 1.429、PerfectPair 1.741、BankerDragonBonus 1.264 ——
--      ⛔ 故《参考.txt》所称「方向差异达约 1.90 倍」于本窗**不成立**（实测最大 1.741），
--         然「免佣确使 edge 变动、静态映射会系统性误算」之**结论方向成立**。本闸即为定谳。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- （d_params / x_ranked / x_testagent / x_base 同 HE-01，此处从略——请整段复制 HE-01 之 WITH 块）
SELECT b.bet_side
     , b.is_freecomm
     , COUNT(*)                                                        AS n_orders
     , ROUND(SUM(b.valid_bet), 4)                                      AS valid_bet
     , ROUND(SUM(b.profit) / NULLIF(SUM(b.valid_bet), 0), 8)           AS edge_vs_valid_bet
     , ROUND(1.959964 * STDDEV_SAMP(b.profit / NULLIF(b.valid_bet, 0))
             / SQRT(COUNT(*)), 8)                                      AS ci95_halfwidth_crude
FROM x_base b
GROUP BY b.bet_side, b.is_freecomm
ORDER BY b.bet_side, b.is_freecomm;
--   ⇒ 判读：同一 bet_side 之二行，若其 edge 差额 > 两侧 CI 半宽之和，即证 bet09 一元【不足】定 edge，
--     映射表主键须为 (bet09, is_freecomm) 二元。⛔ 然纵为二元，亦只是分层常数——
--     #017 R3 之 overdispersion 9.3~42.6 已否决【单一常数】架构，故仍须带区间或分布，禁静态单值。
--   ⇒ 若欲再验桌级异质，把 GROUP BY 改为 (bet_side, is_freecomm, table_id) 即可；本探针不预设结论。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-03 · 覆盖率闸：未映射产品之量有多大？
--   ⛔ 未知产品**不得吞掉**，须出 valid_bet_unmapped 与 mapped_coverage_rate 两数。
--   ⛔ 未知产品 → theo = NULL，禁 fallback = 1（NULL ≠ 0）。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- （WITH 块同 HE-01）
SELECT COUNT(*)                                                                       AS n_orders_all
     , ROUND(SUM(b.valid_bet), 4)                                                     AS valid_bet_all
     , SUM(CASE WHEN e.bet_side IS NULL THEN 1 ELSE 0 END)                            AS n_orders_unmapped
     , ROUND(SUM(CASE WHEN e.bet_side IS NULL THEN b.valid_bet ELSE 0 END), 4)        AS valid_bet_unmapped
     , ROUND(1 - SUM(CASE WHEN e.bet_side IS NULL THEN b.valid_bet ELSE 0 END)
                 / NULLIF(SUM(b.valid_bet), 0), 8)                                    AS mapped_coverage_rate
FROM x_base b
LEFT JOIN (
  -- 已过证据门之产品面（即 HE-01 中 evidence_flag = 'OK' 者）
  SELECT bet_side
  FROM x_base
  GROUP BY bet_side
  HAVING COUNT(*) >= (SELECT min_orders_evid FROM d_params)
) e ON e.bet_side = b.bet_side;
--   ⇒ 验收：mapped_coverage_rate 须 ≥ 0.999；不足者须先查产品字典，禁带病进 HE-04。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-04 · 会员级 theo（已实现口径）：theo_realized = Σ(valid_bet × edge_realized)
--   ⛔ 前三闸皆过方准跑本闸。
--   ⛔ 本 theo 系【已实现】口径之期望值代理，**非理论 theo**：其 edge 来自同窗同批之已实现值，
--      故对本窗而言近乎恒等式（Σ 会员 theo ≈ Σ profit），只可作【分摊】与【结构】之用，
--      ⛔ 绝不可用以宣称「该会员理论上应输多少」，亦不可外推至他窗。
--   ⛔ 真正之理论 theo 须待：① 理论 edge 授权；② x_prod（会员 × 产品）粒度 CTE；
--      ③ 承 #017 R3，edge 须带分布或分层而非单一常数。三者未齐前，本闸只出已实现口径。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- （WITH 块同 HE-01，另接以下二层）
, x_edge AS (                                        -- 逐面已实现 edge（只取过证据门者）
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
--   ⇒ 下游：theo → ADT → NMPT → ESI 之顺序合法，然此三者在【已实现】口径下只作结构分摊，
--     ⛔ 未获理论 edge 授权前，禁以之出赏罚线、禁以之定客户等级。


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- HE-05 · 免佣 vs 一般之差异检定（两比例 z 检定，SELECT 内现算）
--   ⛔ 只出统计量与 p 之判读界，不出结论文字；结论由人裁。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
-- （WITH 块同 HE-01）
, x_fc AS (
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
-- 【自证 · 零写操作】本档全文不含 CREATE / INSERT / UPDATE / DELETE / DROP / TRUNCATE / ALTER /
--   MERGE / REPLACE / LOAD / EXPORT 任一关键字之执行用法（除本行与注释之陈述外）。
--   验证法：对本档做大小写不敏感之关键字扫描，命中数须恰等于注释内之陈述次数。
-- ═══════════════════════════════════════════════════════════════════════════════════════════════
