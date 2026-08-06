## =============================================================================
## a168 ｜ SQL 生成器 v2  sql_pack_generator.R
## -----------------------------------------------------------------------------
## 本版基于 information_schema 实测元数据重写，字段映射已全部落实，无占位符。
##
## 相对 v1 的五处实质修正：
##   1. 表名前缀 ods_a168_，两段式寻址
##   2. age022 不存在于 bet02 → 测试线过滤改走 member.mem019 (is_test)
##   3. 金额口径纠正：validbet=有效投注、bet16=返水金额（现成列）、
##      bet17=已含返水的口袋净变动 → 禁止再乘退水率二次扣减
##   4. 分区列 = dt（非 bet08）→ 所有查询强制 dt 裁剪
##   5. 接入 wm_live_risk 既有风控层（共现边表 / 案件 / 人工复核标签）
##
## 作者：Ryo Eng · 世博量化® Scibrokes Trading®
## =============================================================================

if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(glue, fs, purrr, readr)


## =============================================================================
## 1. 配置对象
## =============================================================================
cfg <- list(

  ## ---- 寻址（已确认：两段式，无 catalog）----
  db_ods  = "ods_mariadb_2b",
  db_risk = "wm_live_risk",     # 完整版反套利系统（优先）
  db_risk_legacy = "wm_risk",   # 旧版，字段较少，仅作对照

  ## ---- 时间窗（抽样显示数据落在 2026 年；先跑 P8.6 校正）----
  dt_from = "2026-01-01",
  dt_to   = "2026-05-01",

  ## ---- 口径开关 ----
  ## bet17 = 口袋净变动，玩家视角，已含返水 → 无需翻转符号
  net_pl_sign  = 1,
  ## 后段下注阈值：wm 既有系统用「子场次 >= 40」，此处保持对齐以便可比
  late_subround = 40,

  out_dir = "sql"
)


## =============================================================================
## 2. 字段字典（实测，供查阅；生成器内部直接引用）
## =============================================================================
## ods_a168_bet02（注单主表，190,212,574 行）
##   dt      日分区列 ★所有查询必须裁剪
##   bet01   注單編號        bet02  遊戲類別編號
##   bet03   場次編號(主局)  bet04  子場次編號 ★后段下注判据
##   bet05   會員編號 ★M1    bet06  開局時間
##   bet07   帳務日期        bet08  下注時間 ★M2
##   bet09   下注內容(选项)  bet10  幣別
##   bet11   匯率            bet12/12a 起始點數/籌碼
##   bet13   下注金額(流水)  bet14  派彩
##   bet15   退水％數        bet16  退水金額 ★现成列
##   bet17   結果(口袋净变动,已含返水) ★
##   bet18-22 LV1-LV5 ID ★代理层级   bet23-27 LV佔成
##   bet28-32 LV退水%        bet33-37 LV結果
##   bet38   重對            bet39  桌子編號 ★M4
##   bet40   房間編號        bet41  下注退水金額
##   validbet 有效投注 ★     gametype 1網投/2電投/3/4
##   commission 0一般/1免傭  category 1一般/2小費
##   eid     荷官 ★M6        serid  服務編號
##   ip      下注IP ★
##
## ods_a168_bet01（退水%表）：bet14=退水％數，bet31=桌子編號，bet32=房間編號
##   注意 bet01 表的 bet17 是 LV3ID，不是结果 —— 铁律③的由来
##
## ods_a168_member（会员，日快照）
##   mem001 会员ID   mem016 enable   mem017 canbet
##   mem019 is_test ★测试线过滤     mem020 be_traded
##   mem024 mem_risk ★旧锚点        currency/cash/type
##   follow1 注關會員 ★社交关系     follow2 關注荷官 ★
## =============================================================================


## =============================================================================
## 3. 工具函数
## =============================================================================

fq  <- function(db, tbl) paste0(db, ".", tbl)
ods <- function(cfg, t) fq(cfg$db_ods,  paste0("ods_a168_", t))
rsk <- function(cfg, t) fq(cfg$db_risk, t)

## 数值安全转换（铁律②：全 varchar，防空串静默转 0）
num <- function(col, scale = "DECIMAL(20,4)")
  glue("CAST(NULLIF(TRIM({col}),'') AS {scale})")

## 金额归一（除汇率）；分母 <= 0 一律置 NULL，与 wm 的「正数 bet11」口径一致
amt <- function(col, alias = "b")
  glue("{num(paste0(alias,'.',col))} / NULLIF(CASE WHEN ",
       "{num(paste0(alias,'.bet11'),'DECIMAL(20,8)')} > 0 THEN ",
       "{num(paste0(alias,'.bet11'),'DECIMAL(20,8)')} ELSE NULL END, 0)")

ts <- function(col) glue("CAST(NULLIF(TRIM({col}),'') AS DATETIME)")

## 通用 WHERE：dt 分区裁剪 + 剔哨兵局
## 注意：测试线过滤不在此处（bet02 无 age022），改由 JOIN member 排除
where_core <- function(cfg, a = "b") glue(
  "{a}.dt >= '{cfg$dt_from}' AND {a}.dt < '{cfg$dt_to}'\n",
  "      AND NULLIF(TRIM({a}.bet03),'') IS NOT NULL\n",
  "      AND {a}.bet03 <> '0'"
)

## 最新会员快照（member 是日快照，直接 COUNT(DISTINCT) 会重复计数）
member_latest_cte <- function(cfg) glue("
member_latest AS (
    SELECT mem001 AS member_id, mem019 AS is_test, mem016 AS enable_flag,
           mem017 AS canbet, mem024 AS mem_risk, currency, type AS acct_type
    FROM (
        SELECT m.*, ROW_NUMBER() OVER (PARTITION BY m.mem001 ORDER BY m.dt DESC) AS rn
        FROM {ods(cfg,'member')} m
        WHERE m.dt < '{cfg$dt_to}'
    ) x WHERE rn = 1
)")

RESERVED <- c("glob","rank","range","percent","precision","values","groups",
              "current","order","default","case","like","limit","using","interval")


## =============================================================================
## 4. SQL 模板
## =============================================================================

## ---- P8 前置体检：快照粒度与过滤器有效性 ------------------------------------
sql_P8_sanity <- function(cfg) glue("
/* P8 前置体检 —— Superset 中【一次只提交一段】 */

-- 8.1 member 是否为日快照？（决定是否必须取最新 dt 切片）
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT dt) AS n_dt,
       COUNT(DISTINCT mem001) AS n_member
FROM {ods(cfg,'member')};

-- 8.2 member_dtl 同上（818M 行需确认）
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT dt) AS n_dt,
       COUNT(DISTINCT mem001) AS n_member
FROM {ods(cfg,'member_dtl')};

-- 8.3 测试会员规模（替代已失效的 age022 过滤）
SELECT mem019 AS is_test, COUNT(DISTINCT mem001) AS n_member
FROM {ods(cfg,'member')} GROUP BY mem019;

-- 8.4 哨兵局占比（确认 bet03='0' 的真实含义）
SELECT CASE WHEN bet03 = '0' THEN 'sentinel_0' ELSE 'normal' END AS kind,
       COUNT(*) AS n
FROM {ods(cfg,'bet02')}
WHERE dt >= '{cfg$dt_from}' AND dt < '{cfg$dt_to}'
GROUP BY 1;

-- 8.5 结算对账：bet17 是否 = (bet14-bet13) + bet16
SELECT COUNT(*) AS n,
       SUM({amt('bet17')})                                        AS total_net,
       SUM({amt('bet14')} - {amt('bet13')})                       AS game_pnl,
       SUM({amt('bet16')})                                        AS rebate,
       SUM({amt('bet17')}) - SUM({amt('bet14')} - {amt('bet13')})
         - SUM({amt('bet16')})                                    AS recon_delta
FROM {ods(cfg,'bet02')} b
WHERE {where_core(cfg)};

-- 8.6 数据实际时间跨度（据此校正 cfg$dt_from / dt_to）
SELECT MIN(dt) AS dt_min, MAX(dt) AS dt_max, COUNT(DISTINCT dt) AS n_days
FROM {ods(cfg,'bet02')};

-- 8.7 分母核验（铁律⑤：有下注会员数，预期 ≈ 132.9 万）
SELECT COUNT(DISTINCT bet05) AS n_betting_members
FROM {ods(cfg,'bet02')} b
WHERE {where_core(cfg)};
")


## ---- SQL-1 会员级建模宽表 ----------------------------------------------------
sql_1_member_wide <- function(cfg) glue("
/* SQL-1 会员级建模宽表（口径已按 wm metric_contract 纠正）
   有效投注 = validbet/bet11 ；流水 = bet13/bet11
   纯盈亏  = (bet14-bet13)/bet11（不含返水）
   返水    = bet16/bet11（现成列，不再用退水率估算）
   口袋净  = bet17/bet11（已含返水）→ 平台净贡献 = -口袋净，勿再扣返水 */
WITH {member_latest_cte(cfg)},
base AS (
    SELECT b.bet05                            AS member_id,
           b.bet39                            AS table_id,
           b.bet40                            AS room_id,
           b.bet03                            AS round_id,
           {num('b.bet04','INT')}             AS sub_round_id,
           b.eid                              AS dealer_id,
           b.bet02                            AS game_category,
           b.gametype                         AS game_mode,
           b.commission                       AS commission,
           b.bet09                            AS bet_side,
           b.ip                               AS bet_ip,
           b.bet18 AS lv1_id, b.bet19 AS lv2_id, b.bet20 AS lv3_id,
           {ts('b.bet08')}                    AS bet_ts,
           {ts('b.bet06')}                    AS round_open_ts,
           {amt('bet13')}                     AS turnover,
           {amt('validbet')}                  AS valid_bet,
           ({amt('bet14')} - {amt('bet13')})  AS game_pnl,
           {amt('bet16')}                     AS rebate,
           {amt('bet17')}                     AS pocket_net
    FROM {ods(cfg,'bet02')} b
    JOIN member_latest ml ON b.bet05 = ml.member_id
    WHERE {where_core(cfg)}
      AND COALESCE(ml.is_test,'N') <> 'Y'          -- 替代失效的 age022 过滤
),
round_anchor AS (
    SELECT table_id, round_id,
           MIN(bet_ts)               AS r_open,
           MAX(bet_ts)               AS r_close,
           MAX(sub_round_id)         AS r_max_sub,
           COUNT(DISTINCT member_id) AS n_member_in_round
    FROM base GROUP BY table_id, round_id
),
enriched AS (
    SELECT b.*, r.r_open, r.r_close, r.r_max_sub, r.n_member_in_round,
           TIMESTAMPDIFF(SECOND, r.r_open, b.bet_ts)  AS sec_from_open,
           TIMESTAMPDIFF(SECOND, b.bet_ts, r.r_close) AS sec_to_close,
           HOUR(b.bet_ts) AS bet_hour, DATE(b.bet_ts) AS bet_date
    FROM base b
    JOIN round_anchor r ON b.table_id = r.table_id AND b.round_id = r.round_id
),
shr AS (
    SELECT e.*,
           COUNT(*) OVER (PARTITION BY e.member_id, e.dealer_id) * 1.0
             / COUNT(*) OVER (PARTITION BY e.member_id) AS dealer_share,
           COUNT(*) OVER (PARTITION BY e.member_id, e.bet_ip) * 1.0
             / COUNT(*) OVER (PARTITION BY e.member_id) AS ip_share
    FROM enriched e
)
SELECT member_id,
       /* A 规模与生命周期 */
       COUNT(*)                                              AS n_bets,
       COUNT(DISTINCT bet_date)                              AS n_active_days,
       MIN(bet_date) AS first_bet_date, MAX(bet_date) AS last_bet_date,
       DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1            AS tenure_days,
       COUNT(DISTINCT bet_date) * 1.0
         / NULLIF(DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1, 0) AS activity_density,
       /* B 金额（五个口径分列，不混用）*/
       SUM(turnover)                                         AS turnover_total,
       SUM(valid_bet)                                        AS valid_bet_total,
       SUM(game_pnl)                                         AS game_pnl_total,
       SUM(rebate)                                           AS rebate_total,
       SUM(pocket_net)                                       AS pocket_net_total,
       -SUM(pocket_net)                                      AS platform_margin,
       SUM(game_pnl) / NULLIF(SUM(valid_bet),0)              AS player_roi,
       SUM(rebate)   / NULLIF(SUM(turnover),0)               AS eff_rebate_rate,
       AVG(turnover) AS avg_stake, STDDEV_SAMP(turnover) AS sd_stake,
       STDDEV_SAMP(turnover) / NULLIF(AVG(turnover),0)       AS stake_cv,
       MAX(turnover) AS max_stake,
       PERCENTILE_APPROX(turnover, 0.95)                     AS p95_stake,
       SUM(CASE WHEN pocket_net < 0 THEN -pocket_net ELSE 0 END) AS gross_loss,
       SUM(CASE WHEN pocket_net > 0 THEN  pocket_net ELSE 0 END) AS gross_win,
       /* C 频次与节律 */
       COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT bet_date),0)   AS bets_per_day,
       SUM(CASE WHEN bet_hour BETWEEN 0 AND 5 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS night_ratio,
       /* D 多样性 */
       COUNT(DISTINCT game_category) AS n_game_cats,
       COUNT(DISTINCT game_mode)     AS n_game_modes,
       COUNT(DISTINCT table_id)      AS n_tables,
       COUNT(DISTINCT room_id)       AS n_rooms,
       COUNT(DISTINCT dealer_id)     AS n_dealers,
       COUNT(DISTINCT round_id)      AS n_rounds,
       COUNT(DISTINCT bet_ip)        AS n_ips,
       COUNT(DISTINCT bet_side)      AS n_bet_sides,
       /* E 风控行为（连续版；阈值判定留给模型，不在此处切）*/
       AVG(sub_round_id)                                     AS avg_sub_round,
       PERCENTILE_APPROX(sub_round_id, 0.50)                 AS med_sub_round,
       SUM(CASE WHEN sub_round_id >= {cfg$late_subround} THEN 1 ELSE 0 END)*1.0
         / COUNT(*)                                          AS late_bet_ratio,
       SUM(CASE WHEN sec_to_close <= 2 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS tail2s_ratio,
       AVG(n_member_in_round)                                AS avg_crowding,
       SUM(CASE WHEN n_member_in_round >= 2 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS co_seated_ratio,
       MAX(n_member_in_round)                                AS max_crowding,
       /* F 集中度 HHI */
       SUM(POW(dealer_share,2))                              AS dealer_hhi,
       SUM(POW(ip_share,2))                                  AS ip_hhi,
       /* G 代理层级（合谋的组织维度）*/
       MAX(lv1_id) AS lv1_id, MAX(lv2_id) AS lv2_id, MAX(lv3_id) AS lv3_id
FROM shr
GROUP BY member_id;
")


## ---- SQL-2 会员×周 面板 ------------------------------------------------------
sql_2_weekly <- function(cfg) glue("
/* SQL-2 会员×周 面板（purged WF 底座；t0/t1 为净化两根锚）*/
WITH {member_latest_cte(cfg)},
base AS (
    SELECT b.bet05 AS member_id, b.eid AS dealer_id, b.bet39 AS table_id,
           b.bet02 AS game_category,
           {ts('b.bet08')} AS bet_ts,
           {ts('b.updatetime')} AS settle_ts,
           {amt('bet13')} AS turnover, {amt('validbet')} AS valid_bet,
           ({amt('bet14')} - {amt('bet13')}) AS game_pnl,
           {amt('bet16')} AS rebate, {amt('bet17')} AS pocket_net
    FROM {ods(cfg,'bet02')} b
    JOIN member_latest ml ON b.bet05 = ml.member_id
    WHERE {where_core(cfg)} AND COALESCE(ml.is_test,'N') <> 'Y'
),
wk AS (
    SELECT member_id, DATE_TRUNC('week', bet_ts) AS week_start,
           COUNT(*) AS n_bets, COUNT(DISTINCT DATE(bet_ts)) AS n_days,
           SUM(turnover) AS turnover, SUM(valid_bet) AS valid_bet,
           SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate,
           SUM(pocket_net) AS pocket_net,
           SUM(CASE WHEN pocket_net < 0 THEN -pocket_net ELSE 0 END) AS gross_loss,
           AVG(turnover) AS avg_stake, MAX(turnover) AS max_stake,
           COUNT(DISTINCT game_category) AS n_game_cats,
           COUNT(DISTINCT table_id) AS n_tables,
           COUNT(DISTINCT dealer_id) AS n_dealers,
           MIN(bet_ts) AS t0_first_bet,
           MAX(COALESCE(settle_ts, bet_ts)) AS t1_last_settle
    FROM base GROUP BY member_id, DATE_TRUNC('week', bet_ts)
)
SELECT w.*,
       LAG(w.turnover)  OVER (PARTITION BY w.member_id ORDER BY w.week_start) AS turnover_lag1,
       LAG(w.avg_stake) OVER (PARTITION BY w.member_id ORDER BY w.week_start) AS avg_stake_lag1,
       w.turnover  / NULLIF(LAG(w.turnover)  OVER (PARTITION BY w.member_id ORDER BY w.week_start),0) AS turnover_wow,
       w.avg_stake / NULLIF(LAG(w.avg_stake) OVER (PARTITION BY w.member_id ORDER BY w.week_start),0) AS stake_escalation,
       CASE WHEN LAG(w.pocket_net) OVER (PARTITION BY w.member_id ORDER BY w.week_start) < 0
                 AND w.turnover > LAG(w.turnover) OVER (PARTITION BY w.member_id ORDER BY w.week_start)
            THEN 1 ELSE 0 END AS flag_chasing,
       SUM(w.gross_loss) OVER (PARTITION BY w.member_id ORDER BY w.week_start
                               ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS gross_loss_roll4w,
       ROW_NUMBER() OVER (PARTITION BY w.member_id ORDER BY w.week_start) AS week_seq
FROM wk w
ORDER BY w.member_id, w.week_start;
")


## ---- SQL-3 直读 wm_live_risk 既有规则层（取代自行重算）-----------------------
sql_3_risk_layer <- function(cfg) glue("
/* SQL-3 直读既有风控层 —— 三规则不必从 1.9 亿注单重算 */

-- 3.1 后段下注（对应「规则1」）
SELECT player_id AS member_id, late_order_count, total_order_count,
       late_order_rate, first_bet_time, last_bet_time, as_of_time
FROM {rsk(cfg,'business_risk_late_bet_snapshot')};

-- 3.2 同桌配对（对应「规则2」；同时即社区检测的边表）
SELECT player_a, player_b, same_round_count, same_rate,
       opposite_round_count, opposite_rate,
       player_a_round_count, player_b_round_count,
       first_game_time, last_game_time
FROM {rsk(cfg,'business_risk_same_table_pair_snapshot')};

-- 3.3 玩家×荷官（对应「规则3」）
SELECT player_id AS member_id, dealer_id, bet_amount, game_pnl, rebate_amount,
       net_profit_amount, player_overall_net_profit,
       win_count, lose_count, push_count, win_rate,
       order_count, round_count, first_bet_time, last_bet_time
FROM {rsk(cfg,'business_risk_player_dealer_snapshot')};

-- 3.4 荷官侧统计（含现成 roi_zscore / risk_score，可作对照基线）
SELECT dealer_id, game_id, player_id, bet_count, valid_bet, turnover,
       profit, rebate, total_net_earnings, reconciliation_delta,
       win_rate, player_roi, roi_zscore, risk_score, risk_level
FROM {rsk(cfg,'dealer_profit_stat')};

-- 3.5 自动化群组（同步下注团伙；member_ids 为 JSON 数组）
SELECT stat_date, stat_hour, group_key, round_key, table_id, dealer_id,
       bet_side, amount_bucket, member_count, member_ids,
       synchronization_span_millis, first_bet_time, last_bet_time
FROM {rsk(cfg,'baccarat_automation_group_round_hourly')}
WHERE stat_date >= '{cfg$dt_from}' AND stat_date < '{cfg$dt_to}';

-- 3.6 玩家自对冲（庄闲双押；洗码套利的直接签名）
SELECT stat_date, player_id, table_id, dealer_id,
       banker_amount, player_amount, tie_amount, side_amount,
       self_hedge, self_hedge_coverage, ips
FROM {rsk(cfg,'baccarat_player_round_hourly')}
WHERE stat_date >= '{cfg$dt_from}' AND stat_date < '{cfg$dt_to}'
  AND self_hedge = 1;
")


## ---- SQL-4 监督锚点（三层标签）----------------------------------------------
sql_4_anchor <- function(cfg) glue("
/* SQL-4 监督锚点 —— 三层标签，质量由高到低，报告中须分层报告

   L1 金标准 : baccarat_risk_review_metrics_daily.review_label
               CONFIRMED_ARBITRAGE / ENHANCED_DUE_DILIGENCE
               / NORMAL_BEHAVIOR / INSUFFICIENT_EVIDENCE
   L2 模型分 : player_risk_assessment_hourly.risk_score（既有模型输出，非独立标签）
   L3 弱标签 : ods_a168_dailyreport_member.risk（平台自评，noisy）
*/

-- 4.1 L1 人工复核标签（★ 真正的监督信号）
SELECT review_date, model_version, signal_family, review_label,
       commission, game_type, volume_band, activity_band, cohort_level,
       reviewed_case_count, available, reason_code
FROM {rsk(cfg,'baccarat_risk_review_metrics_daily')}
WHERE review_date >= '{cfg$dt_from}' AND review_date < '{cfg$dt_to}';

-- 4.2 案件级明细（可回溯到 member_ids，与 L1 关联）
SELECT case_date, case_id, case_type, signal_family, primary_player_id,
       risk_score, behavior_points, relationship_points,
       economic_points, persistence_points,
       current_level, peak_level, case_status, recommended_action,
       signal_codes, member_ids, threshold_snapshot_id, model_version,
       valid_bet, game_pnl, rebate, total_net_earnings, reconciliation_delta,
       shadow_only, admitted_to_review, as_of_time
FROM {rsk(cfg,'baccarat_risk_case_hourly')}
WHERE case_date >= '{cfg$dt_from}' AND case_date < '{cfg$dt_to}';

-- 4.3 L2 既有模型评分（★ baseline：我们的模型必须证明超越它）
SELECT assessment_date, player_id AS member_id, risk_score, risk_level,
       recommended_action, data_status, model_version,
       behavior_points, relationship_points, economic_points, persistence_points,
       active_case_count, peak_level, as_of_time
FROM {rsk(cfg,'player_risk_assessment_hourly')}
WHERE assessment_date >= '{cfg$dt_from}' AND assessment_date < '{cfg$dt_to}';

-- 4.4 L3 弱标签（旧锚点，保留作对照）
SELECT memberid AS member_id,
       MAX({num('risk','INT')}) AS risk_max,
       COUNT(*) AS n_report_days
FROM {ods(cfg,'dailyreport_member')}
WHERE dt >= '{cfg$dt_from}' AND dt < '{cfg$dt_to}'
  AND NULLIF(TRIM(risk),'') IS NOT NULL
GROUP BY memberid;

-- 4.5 既有阈值快照（★ L1 外部锚不必凭空造，平台已有一套校准体系）
SELECT baseline_date, threshold_snapshot_id, model_version,
       metric_contract, baseline_contract, cohort_level,
       commission, game_mode, volume_band, activity_band,
       anchor_start, anchor_end, complete_anchor_count,
       observation_count, distinct_player_count, confidence
FROM {rsk(cfg,'baccarat_risk_threshold_snapshot_daily')};

-- 4.6 阈值取值明细（百分位值 vs 绝对门槛双轨）
SELECT baseline_date, threshold_snapshot_id, metric_name, metric_direction,
       moderate_percentile_value, strong_percentile_value,
       moderate_value, strong_value,
       absolute_moderate_floor, absolute_strong_floor,
       moderate_sample_safe, strong_sample_safe
FROM {rsk(cfg,'baccarat_risk_threshold_value_daily')};
")


## ---- SQL-5 荷官×日 面板（CTE 名 gstat，规避保留字 GLOB）---------------------
sql_5_dealer <- function(cfg) glue("
/* SQL-5 荷官×日 面板（brms 随机截距+随机斜率输入）*/
WITH {member_latest_cte(cfg)},
base AS (
    SELECT b.eid AS dealer_id, b.bet39 AS table_id, b.bet02 AS game_category,
           b.bet05 AS member_id, DATE({ts('b.bet08')}) AS bet_date,
           {amt('bet13')} AS turnover, {amt('validbet')} AS valid_bet,
           ({amt('bet14')} - {amt('bet13')}) AS game_pnl,
           {amt('bet17')} AS pocket_net
    FROM {ods(cfg,'bet02')} b
    JOIN member_latest ml ON b.bet05 = ml.member_id
    WHERE {where_core(cfg)}
      AND COALESCE(ml.is_test,'N') <> 'Y'
      AND NULLIF(TRIM(b.eid),'') IS NOT NULL
),
panel AS (
    SELECT dealer_id, bet_date, game_category,
           COUNT(*) AS n_bets,
           COUNT(DISTINCT member_id) AS n_members,
           COUNT(DISTINCT table_id)  AS n_tables,
           SUM(turnover) AS turnover, SUM(valid_bet) AS valid_bet,
           SUM(game_pnl) AS game_pnl, SUM(pocket_net) AS pocket_net,
           SUM(game_pnl) / NULLIF(SUM(valid_bet),0) AS player_roi,
           AVG(turnover) AS avg_stake, STDDEV_SAMP(turnover) AS sd_stake
    FROM base GROUP BY dealer_id, bet_date, game_category
),
gstat AS (
    SELECT AVG(player_roi) AS mu_roi, STDDEV_SAMP(player_roi) AS sd_roi
    FROM panel WHERE n_bets >= 30
)
SELECT p.dealer_id, p.bet_date, p.game_category,
       p.n_bets, p.n_members, p.n_tables,
       p.turnover, p.valid_bet, p.game_pnl, p.pocket_net,
       p.player_roi, p.avg_stake, p.sd_stake,
       (p.player_roi - g.mu_roi) / NULLIF(g.sd_roi,0) AS player_roi_z,
       p.n_bets AS model_weight,
       ROW_NUMBER() OVER (PARTITION BY p.dealer_id ORDER BY p.bet_date) AS day_seq,
       COUNT(*)     OVER (PARTITION BY p.dealer_id) AS dealer_n_days
FROM panel p CROSS JOIN gstat g
WHERE p.n_bets >= 10
ORDER BY p.dealer_id, p.bet_date;
")


## ---- SQL-6 资金侧：affordability（此前判定为缺口，现已可实现）---------------
sql_6_affordability <- function(cfg) glue("
/* SQL-6 会员×日 资金流（对标 UKGC 滚动净存款口径）
   ods_a168_in_out_m: iom002=time, iom003=member, iom004=money,
                      iom005=op_code, iom010=subtotal */

-- 6.0 op_code 语义探针（必须先跑，否则存取方向会搞反）
SELECT iom005 AS op_code, COUNT(*) AS n,
       SUM({num('iom004')}) AS sum_money,
       AVG({num('iom004')}) AS avg_money,
       MIN({num('iom004')}) AS min_money,
       MAX({num('iom004')}) AS max_money
FROM {ods(cfg,'in_out_m')}
WHERE dt >= '{cfg$dt_from}' AND dt < '{cfg$dt_to}'
GROUP BY iom005 ORDER BY n DESC;

-- 6.1 会员×日 净存款（op_code 方向确认后启用）
SELECT iom003 AS member_id,
       DATE({ts('iom002')}) AS flow_date,
       SUM(CASE WHEN {num('iom004')} > 0 THEN {num('iom004')} ELSE 0 END)  AS deposit_amt,
       SUM(CASE WHEN {num('iom004')} < 0 THEN -{num('iom004')} ELSE 0 END) AS withdraw_amt,
       SUM({num('iom004')}) AS net_deposit,
       COUNT(*) AS n_txn
FROM {ods(cfg,'in_out_m')}
WHERE dt >= '{cfg$dt_from}' AND dt < '{cfg$dt_to}'
GROUP BY iom003, DATE({ts('iom002')})
ORDER BY member_id, flow_date;
")


## ---- SQL-7 登录/IP 层（脚本户与设备共享）------------------------------------
sql_7_login <- function(cfg) glue("
/* SQL-7 登录与 IP（mlg001=mem_id, mlg003=sid, mlg004=this_login, mlg006=ip）*/
SELECT mlg001 AS member_id,
       COUNT(*)               AS n_login,
       COUNT(DISTINCT mlg006) AS n_ip,
       COUNT(DISTINCT mlg003) AS n_session,
       MIN({ts('mlg004')})    AS first_login,
       MAX({ts('mlg004')})    AS last_login
FROM {ods(cfg,'mem_login')}
WHERE dt >= '{cfg$dt_from}' AND dt < '{cfg$dt_to}'
GROUP BY mlg001;

-- 7.1 共享 IP 边表（多开/代打的直接证据）
SELECT mlg006 AS ip,
       COUNT(DISTINCT mlg001) AS n_member,
       COUNT(*)               AS n_login
FROM {ods(cfg,'mem_login')}
WHERE dt >= '{cfg$dt_from}' AND dt < '{cfg$dt_to}'
  AND NULLIF(TRIM(mlg006),'') IS NOT NULL
GROUP BY mlg006
HAVING COUNT(DISTINCT mlg001) > 1
ORDER BY n_member DESC;
")


## =============================================================================
## 5. 一键生成
## =============================================================================
build_sql_pack <- function(cfg) {
  fs::dir_create(cfg$out_dir)
  pack <- list(
    "P8_sanity.sql"          = sql_P8_sanity(cfg),
    "SQL1_member_wide.sql"   = sql_1_member_wide(cfg),
    "SQL2_weekly_panel.sql"  = sql_2_weekly(cfg),
    "SQL3_risk_layer.sql"    = sql_3_risk_layer(cfg),
    "SQL4_anchor.sql"        = sql_4_anchor(cfg),
    "SQL5_dealer_panel.sql"  = sql_5_dealer(cfg),
    "SQL6_affordability.sql" = sql_6_affordability(cfg),
    "SQL7_login_ip.sql"      = sql_7_login(cfg)
  )
  purrr::iwalk(pack, function(txt, nm) {
    readr::write_file(txt, fs::path(cfg$out_dir, nm))
    message("\u2714 ", fs::path(cfg$out_dir, nm))
  })
  invisible(pack)
}

## 用法：
##   source("sql_pack_generator.R")
##   build_sql_pack(cfg)          # 先跑 sql/P8_sanity.sql 的 8.6 校正时间窗
##
## ⚠️ Superset 每个 tab 一次只提交一条语句；多条分号语句会触发内部错误。
