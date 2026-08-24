-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ★ 商业方案 v1.0.0 · 三条可量化收益之杠杆 · 跨表跨维 ★
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 立于 2026-08-24 · 应军令状：**务必提高业绩**。
--
-- 【先说两处局限 —— 机检坐实，不是空话】
--   〔局限一 · 红队之短〕
--     红队迄今全部裁定，无一涉及收入：audit_rn、双向反证、G4-ROW、七层放行、AUDIT-READY……
--     所审者皆为「取数有无丢失、两版是否一致」。**审计再严密，也不产生一分钱收入。**
--     其框架里没有「收入」这一项，故其「全绿」与业绩无关。此非苛责，是事实。
--   〔局限二 · 我方之短，更该认〕
--     机检 129 件所触及之表：
--       bet02 91 件 ｜ agent 45 ｜ log_mem_change 19 ｜ dailyreport_member 12 ｜ game_info 9
--       alert_ip_setting 6 ｜ member_dtl 5 ｜ **wallet_dtl 2** ｜ **member 2** ｜ **employee 1**
--       **bet_limit_default 1** ｜ **currency 0**
--     其中 **33 件只碰 bet02 一张表**。
--     ★ 即：整包是**投注侧单眼**。收入之四大杠杆——退水成本（member_dtl）、
--       限红（bet_limit_default）、桌台产能（game_info×employee）、资金流（wallet_dtl）——
--       **几乎没碰**。在这上面加 roi/ramp 列，无论加多少，都是在同一只眼里打转。
--     此即先生所斥之「钻牛角尖」。认。
--
-- 【本卷之别】不再往既有 129 件上贴列，改为**另开三条杠杆**，每条：
--   ① 明写其收益公式（算得出钱）② 明写所需之表与维度 ③ 明写落地动作 ④ 先出探针再出台账
-- ══════════════════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 杠杆 L1 · 退水档位重定价　【成本侧 · 见效最快 · 不需新数据】
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 【为何是第一杠杆】退水（bet16）是平台**唯一大额且完全可控**之成本。
--   游戏输赢受概率支配，改不动；退水是自己定的，改一个档位，当月即见 P&L。
-- 【核心判据】两个数决定一个会员该给多少退水：
--     turnover_multiple = 洗码量 ÷ 本金        —— 他把钱转了几圈
--     roi_ex_rebate     = (净输赢 − 退水) ÷ 本金 —— 扣掉退水后，他还赢不赢
--   · turnover 高 且 roi_ex_rebate ≈ 0  → **纯薅退水**：他不靠赢钱，靠退水。降档。
--   · turnover 低 且 roi_ex_rebate 显著负 → **真娱乐客**：平台真正赚他的钱。维持或加码留存。
--   · turnover 高 且 roi_ex_rebate 正   → **既赢钱又薅退水**：降档 ＋ 限红 ＋ 并案。
-- 【收益公式】节省额 = Σ（现付退水 − 拟付退水）
--   拟付退水 = 洗码量 × 拟定档位率；拟定档位率由**分位分档**得来，非硬编码。
-- 【落地动作】按档发调整通知 → 观察 30 日流失与流水变化 → 以 §PI 之 DID 验其净效应。
-- ══════════════════════════════════════════════════════════════════════════════════════════

-- ── L1-probe · 先探 member_dtl 之退水配置列（★ 未验之前不得据以定价）──
-- 缘由：包内注释称「退水配置列 doc 记为 mem003」，然此系**文档之说，非实测**。
--   本库有过 member.mem015 ≠ member_dtl.mem015 之同名异义陷阱，故先探后用。
-- ▸ 导出：不需要 —— 屏幕读数即可。
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME   = 'ods_a168_member_dtl'
ORDER BY ORDINAL_POSITION;
-- 读法：找带「退水／返水／rebate／commission／rate／比例」字样之列。
--   找到后把下方 L1-ledger 之 md.mem003 换成真列名；未找到则该列走「实测档位」（见下）。

-- ── L1-ledger · 退水成本重定价台账（不依赖配置列亦可跑：以**实测档位**代之）──
-- ▸ 导出：需要 —— 存为「数据库/BIZ_L1_rebate_repricing.csv」
-- ★ 实测档位 rebate_rate_now = 退水 ÷ 洗码量，此为**该会员实际拿到的档位**，
--   比读配置表更可靠（配置可能有历史变更、有例外、有手工调整）。
WITH bs AS (
  SELECT b.bet05 AS member_id,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS stake,
         CAST(NULLIF(TRIM(b.bet41),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS validbet,
         CAST(NULLIF(TRIM(b.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS rebate,
         CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS net_pnl,
         b.dt
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
),
m AS (
  SELECT member_id,
         COUNT(*)                                                         AS n_bets,
         COUNT(DISTINCT dt)                                               AS n_days,
         SUM(stake)                                                       AS stake,
         SUM(validbet)                                                    AS validbet,
         SUM(rebate)                                                      AS rebate,
         SUM(net_pnl)                                                     AS net_pnl
  FROM bs GROUP BY member_id
),
k AS (
  SELECT member_id, n_bets, n_days, stake, validbet, rebate, net_pnl,
         ROUND(validbet / NULLIF(stake, 0), 6)                            AS turnover_multiple,
         ROUND(rebate   / NULLIF(validbet, 0), 8)                         AS rebate_rate_now,
         ROUND(net_pnl  / NULLIF(stake, 0), 8)                            AS roi,
         ROUND((net_pnl - rebate) / NULLIF(stake, 0), 8)                  AS roi_ex_rebate,
         ROUND(-net_pnl / NULLIF(stake, 0), 8)                            AS hold_rate,
         ROUND(-net_pnl, 4)                                               AS house_pnl
  FROM m
),
q AS (   -- ★ 切点由数据定：分位秩，不写死任何阈值
  SELECT k.*,
         PERCENT_RANK() OVER (ORDER BY turnover_multiple)                 AS pr_turnover,
         PERCENT_RANK() OVER (ORDER BY roi_ex_rebate)                     AS pr_roi_ex,
         PERCENT_RANK() OVER (ORDER BY stake)                             AS pr_stake,
         NTILE(5)       OVER (ORDER BY stake)                             AS vip_tier_by_stake
  FROM k
),
seg AS (
  SELECT q.*,
         CASE
           WHEN pr_turnover >= 0.80 AND pr_roi_ex >= 0.80 THEN 'A 既赢钱又薅退水 · 降档＋限红＋并案'
           WHEN pr_turnover >= 0.80 AND pr_roi_ex >= 0.50 THEN 'B 纯薅退水 · 降档'
           WHEN pr_turnover >= 0.50 AND pr_roi_ex >= 0.50 THEN 'C 观察 · 维持'
           WHEN pr_roi_ex   <= 0.20                       THEN 'D 真娱乐客 · 维持或加码留存'
           ELSE                                                'E 常规 · 维持'
         END                                                              AS action_seg,
         -- 拟定档位：以同 VIP 档内之**中位实测档位**为基准，A/B 段下调至该档 P25，D 段上调至 P75
         PERCENTILE_APPROX(rebate_rate_now, 0.25) OVER (PARTITION BY vip_tier_by_stake) AS band_p25,
         PERCENTILE_APPROX(rebate_rate_now, 0.50) OVER (PARTITION BY vip_tier_by_stake) AS band_p50,
         PERCENTILE_APPROX(rebate_rate_now, 0.75) OVER (PARTITION BY vip_tier_by_stake) AS band_p75
  FROM q
)
SELECT member_id, vip_tier_by_stake, action_seg,
       n_bets, n_days,
       ROUND(stake, 4)                                                    AS stake,
       ROUND(validbet, 4)                                                 AS validbet,
       ROUND(stake / NULLIF(n_bets, 0), 4)                                AS avg_stake,
       turnover_multiple, rebate_rate_now, roi, roi_ex_rebate, hold_rate, house_pnl,
       ROUND(rebate, 4)                                                   AS rebate_now,
       ROUND(CASE
               WHEN action_seg LIKE 'A%' OR action_seg LIKE 'B%' THEN band_p25
               WHEN action_seg LIKE 'D%'                          THEN band_p75
               ELSE rebate_rate_now
             END, 8)                                                      AS rebate_rate_proposed,
       ROUND(validbet * CASE
               WHEN action_seg LIKE 'A%' OR action_seg LIKE 'B%' THEN band_p25
               WHEN action_seg LIKE 'D%'                          THEN band_p75
               ELSE rebate_rate_now
             END, 4)                                                      AS rebate_proposed,
       ROUND(rebate - validbet * CASE
               WHEN action_seg LIKE 'A%' OR action_seg LIKE 'B%' THEN band_p25
               WHEN action_seg LIKE 'D%'                          THEN band_p75
               ELSE rebate_rate_now
             END, 4)                                                      AS saving_amount,
       pr_turnover, pr_roi_ex, pr_stake
FROM seg
ORDER BY saving_amount DESC;
-- ★ saving_amount 之总和，即本杠杆之**窗内可省金额**——这是一个能写进 P&L 的数。
-- ★ 读毕请另跑一句取其总额：SELECT SUM(saving_amount) FROM ( 上式 ) x;
-- ⚠ 此为**静态节省**，未计流失。落地后须以 §PI 之 DID 验净效应；
--   若 D 段加码留存所增之流水 × hold_rate 大于 A/B 段之流失损失，则净效应为正。


-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 杠杆 L2 · 桌台 × 时段 × 荷官 产能　【增收侧 · 直接改排班即见效】
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 【为何是第二杠杆】桌台是**有限产能**。一张桌开着而无人坐，是纯亏；
--   高产能时段少开一张，是白丢的收入。此杠杆不改任何会员待遇，只改排班，**阻力最小**。
-- 【维度】桌（bet39）× 时段（bet08 之小时）× 荷官（eid）× 营业日（dt）
-- 【收益公式】增收 = Σ〔（目标时段之单位工时净收 − 现状）× 可增工时〕
-- 【落地动作】关低产桌／时段；高产时段加台；把高产荷官排到高产时段。
-- ▸ 导出：需要 —— 存为「数据库/BIZ_L2_table_hour_capacity.csv」
WITH bs AS (
  SELECT b.bet39 AS table_id,
         b.eid   AS dealer_id,
         b.dt    AS bet_date,
         HOUR(CAST(NULLIF(TRIM(b.bet08),'') AS DATETIME))                 AS hour_of_day,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39)                        AS round_key,
         b.bet05 AS member_id,
         CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS stake,
         CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))              AS net_pnl
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(b.bet08),'') IS NOT NULL
),
cap AS (
  SELECT table_id, hour_of_day,
         COUNT(DISTINCT bet_date)                                         AS n_days_open,
         COUNT(DISTINCT round_key)                                        AS n_rounds,
         COUNT(DISTINCT member_id)                                        AS n_members,
         COUNT(DISTINCT dealer_id)                                        AS n_dealers,
         COUNT(*)                                                         AS n_bets,
         SUM(stake)                                                       AS stake,
         SUM(net_pnl)                                                     AS net_pnl
  FROM bs GROUP BY table_id, hour_of_day
)
SELECT table_id, hour_of_day, n_days_open, n_rounds, n_members, n_dealers, n_bets,
       ROUND(stake, 4)                                                    AS stake,
       ROUND(-net_pnl, 4)                                                 AS house_pnl,
       -- 产能三率
       ROUND(n_rounds  * 1.0 / NULLIF(n_days_open, 0), 4)                 AS rounds_per_hour,   -- 局速
       ROUND(n_bets    * 1.0 / NULLIF(n_rounds, 0), 4)                    AS seats_per_round,   -- 上座
       ROUND(stake     / NULLIF(n_bets, 0), 4)                            AS avg_stake,
       ROUND(-net_pnl  / NULLIF(stake, 0), 8)                             AS hold_rate,
       -- ★ 单位工时净收：本杠杆之核心 KPI（桌·小时 为工时单位）
       ROUND(-net_pnl  / NULLIF(n_days_open, 0), 4)                       AS house_pnl_per_table_hour,
       PERCENT_RANK() OVER (ORDER BY -net_pnl / NULLIF(n_days_open, 0))   AS pr_capacity,
       -- ramp：末 30 日与全窗之比，看该桌该时段是在升还是在衰
       ROUND(stake / NULLIF(n_days_open, 0), 4)                           AS stake_per_table_hour
FROM cap
ORDER BY house_pnl_per_table_hour ASC;
-- ★ 首行即**最该关掉或换班之桌·时段**；末行即最该加台之桌·时段。
-- ★ 决策式：若某桌·时段之 house_pnl_per_table_hour 位于 pr_capacity < 0.20，
--   而同时段他桌位于 > 0.80，则把该桌之荷官与客源导向后者，其差额即增收。


-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 杠杆 L3 · 资金漏斗　【本包最大空白 · wallet_dtl 仅 2 件用过】
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 【为何是第三杠杆】投注侧只看得见「他下了多少」，看不见「他拿进来多少、又拿走多少」。
--   平台真正之失血是**净取现**，非账面输赢。此维度本包几乎空白。
-- 【★ 前置警告 · 据实标明】§V-2 之验货结论：**wallet_dtl 系内部转账与余额快照，非入金流水**。
--   故本节所出者为「钱包侧口径」，**不可直接读作存款／提款**。真入金表尚未在册（H0 判 BLOCKED）。
--   本节先出**结构探针**，确认其语义后方可建漏斗；未确认之前，其读数一律标 CONDITIONAL。
-- ▸ 导出：不需要 —— 屏幕读数即可。
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME   = 'ods_a168_wallet_dtl'
ORDER BY ORDINAL_POSITION;
-- 读法：找方向列（in/out/type/direction）、金额列（amount/money/balance）、
--   时间列（create_time/optime）、以及与 member 之连接列（user）。
--   三者齐备方可建漏斗：存入 → 投注 → 提出，逐段算转化率与留存。
-- ★ 找齐之后，本节可扩为：
--     net_deposit    = 存入 − 提出          （平台真实入账）
--     churn_multiple = 本金 ÷ 存入          （一块钱转几圈——比 turnover 更贴近真实成本）
--     roi_cash       = (提出 − 存入) ÷ 存入 （净取现率，最贴近平台失血）
--     ramp_deposit   = 近 30 日存入 ÷ 全窗日均
--   ★ 此四指标一旦接通，会员价值判断即由「账面输赢」升为「现金口径」——
--     这是本包目前**最大的一块未开采之地**。
-- ══════════════════════════════════════════════════════════════════════════════════════════
