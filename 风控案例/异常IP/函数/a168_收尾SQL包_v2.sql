/* ============================================================================
   a168 真人荷官平台 — 风控与客户分层评分体系
   收尾 SQL 包 v2（5 条 + 1 条字段契约探针）
   目标库 : StarRocks / ods_mariadb_2b
   执行方式: Superset SQL Lab，【逐条单独提交】，禁止批量粘贴（僵尸查询风险）
   作者   : Ryo Eng · 世博量化® Scibrokes Trading®
   ----------------------------------------------------------------------------
   已确立铁律（本包全程遵守）
   ① 表名一律 ods_mariadb_2b. 全限定
   ② 字段全 varchar → 一律 CAST，且先 NULLIF(TRIM(x),'') 防空串/防 ''→0
   ③ bet01 与 bet02 自 bet14 起同名异义：
        bet01.bet14 = 退水%      (rebate rate)
        bet02.bet14 = 派彩        (payout)
        bet02.bet17 = 净盈亏      (net win/loss, 平台视角或会员视角需在 M8 确认符号)
      → 两表【绝不 UNION 同名列】，各自取数后按语义列名 alias 再关联
   ④ 每条 SQL 硬编码过滤： bet03 <> '0'（哨兵局） AND age022 <> '1'（测试线）
   ⑤ 分母 = 有下注行为会员数（≈132.9 万），动态 COUNT(DISTINCT) 得出，
      严禁使用 5849 万账户数
   金额口径: 有效投注 = bet13 / bet11 ; 净盈亏 = bet17 / bet11   (bet11 = 汇率)
   已证伪排除: aggregate_transaction / game_result / risklist —— 本包不出现
   ============================================================================ */


/* ============================================================================
   【字段契约】—— 全包唯一需要你修改的地方
   ----------------------------------------------------------------------------
   下列 8 个语义槽位需绑定到实际列号。先跑 SQL-0 确认，再全局替换一次即可。
   本文件中每处出现都用 /*M1*/ … /*M8*/ 标注，便于 Ctrl+F 批量替换。

     M1  会员ID       → b.bet04        ⚠️待确认
     M2  下注时间     → b.bet05        ⚠️待确认（varchar 'YYYY-MM-DD HH:MM:SS'）
     M3  结算时间     → b.bet06        ⚠️待确认（purge/embargo 用，缺失可回退 M2）
     M4  桌台ID       → b.bet07        ⚠️待确认
     M5  局号/靴号    → b.bet08        ⚠️待确认
     M6  荷官ID       → b.bet09        ⚠️待确认
     M7  游戏类型     → b.bet10        ⚠️待确认（百家乐/龙虎/轮盘…）
     M8  净盈亏符号   → 正=会员赢 / 正=平台赢   ⚠️待确认（SQL-0 第 3 段判定）

   已锁定（无需修改）:
     bet03 = 哨兵局标记 ('0' 需剔除)
     bet11 = 汇率
     bet13 = 投注额（原币）
     bet01.bet14 = 退水%
     bet02.bet14 = 派彩
     bet02.bet17 = 净盈亏（原币）
     age022 = 测试线标记 ('1' 需剔除)
   ============================================================================ */


/* ==========================================================================
   SQL-0 ｜ 字段契约探针（先跑这条，锁定 M1–M8，5 分钟内完成）
   -------------------------------------------------------------------------
   一次性回答三个问题：
     (a) 各槽位候选列的基数与形态 → 定 M1/M4/M5/M6/M7
     (b) 时间列的格式与跨度       → 定 M2/M3
     (c) 净盈亏符号方向           → 定 M8
   ========================================================================== */

-- 0-a 形态探针：抽 5 万行看基数（NDV）与样例，判断哪一列是会员/桌台/局号/荷官/游戏
WITH s AS (
  SELECT *
  FROM ods_mariadb_2b.bet02
  WHERE bet03 <> '0'
    AND COALESCE(age022,'') <> '1'
  LIMIT 50000
)
SELECT
    COUNT(*)                                   AS n_rows,
    NDV(bet04) AS ndv_bet04, NDV(bet05) AS ndv_bet05,
    NDV(bet06) AS ndv_bet06, NDV(bet07) AS ndv_bet07,
    NDV(bet08) AS ndv_bet08, NDV(bet09) AS ndv_bet09,
    NDV(bet10) AS ndv_bet10, NDV(bet12) AS ndv_bet12,
    MIN(bet05) AS min_bet05, MAX(bet05) AS max_bet05,
    MIN(bet06) AS min_bet06, MAX(bet06) AS max_bet06
FROM s;
/* 判读规则：
     会员ID  → NDV 极高（万级以上）且非时间格式
     桌台ID  → NDV 很低（几十~几百）
     局号    → NDV 高但与桌台组合唯一
     荷官ID  → NDV 低于桌台或同量级（百级）
     游戏类型→ NDV 个位数~十位数
     时间列  → MIN/MAX 呈 'YYYY-MM-DD HH:MM:SS' 且 max>min 跨度合理           */


-- 0-b 符号探针：确认 bet17 净盈亏是「会员视角」还是「平台视角」
SELECT
    SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0))      AS 有效投注_合计,
    SUM(CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4))
        / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0))      AS 净盈亏_合计,
    SUM(CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4))
        / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0))
      / NULLIF(SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0)),0)   AS 理论抽水率
FROM ods_mariadb_2b.bet02
WHERE bet03 <> '0'
  AND COALESCE(age022,'') <> '1'
  AND bet05 >= '2022-01-01' AND bet05 < '2022-02-01';   -- 单月抽样即可
/* 判读：百家乐庄家优势约 1.06%~1.24%（含和局与佣金结构）。
     理论抽水率 ≈ -0.010 ~ -0.015  → bet17 为【会员视角】(负=会员输)  → M8 = 会员视角
     理论抽水率 ≈ +0.010 ~ +0.015  → bet17 为【平台视角】(正=平台赢)  → M8 = 平台视角
   后续 SQL 统一按【会员视角】书写；若探针判定为平台视角，
   请把所有 net_pl 定义处的  ( bet17 / bet11 )  改为  -( bet17 / bet11 ) 。 */


-- 0-c 关联键探针：确认 bet01（退水%）与 bet02（注单）如何对齐
SELECT
    (SELECT COUNT(*) FROM ods_mariadb_2b.bet01 WHERE bet03 <> '0')  AS n_bet01,
    (SELECT COUNT(*) FROM ods_mariadb_2b.bet02 WHERE bet03 <> '0')  AS n_bet02,
    (SELECT NDV(bet01) FROM ods_mariadb_2b.bet01)                   AS ndv_bet01_pk,
    (SELECT NDV(bet01) FROM ods_mariadb_2b.bet02)                   AS ndv_bet02_pk;
/* 若两表 bet01 列 NDV ≈ 各自行数，则 bet01 列即注单主键，可 1:1 JOIN；
   若不等，则退化为「会员×日」粒度的退水率映射（SQL-1 中已给出退化分支）。 */


/* ==========================================================================
   SQL-1 ｜ 会员级建模宽表（客户分层评分 + RSF/XGBoost 特征底座）
   -------------------------------------------------------------------------
   粒度   : 1 行 = 1 会员（全窗口汇总）
   输出   : 34 列特征，直接喂 R 端 randomForestSRC / xgboost / RFM 分层
   设计依据: LRGG 三维（金额 / 频次 / 品类多样性）+ UKGC 净损滚动窗口 +
             Focal Research affordability 监测口径
   全部切点用 PERCENTILE_APPROX 动态生成，无任何硬编码阈值
   预估    : 全表扫描 ~1.8 亿行，建议先落 tmp 表再做分位数
   ========================================================================== */

WITH base AS (
    SELECT
        /*M1*/ b.bet04                                                      AS member_id,
        /*M4*/ b.bet07                                                      AS table_id,
        /*M5*/ b.bet08                                                      AS round_no,
        /*M6*/ b.bet09                                                      AS dealer_id,
        /*M7*/ b.bet10                                                      AS game_type,
        CAST(NULLIF(TRIM(/*M2*/ b.bet05),'') AS DATETIME)                   AS bet_ts,
        CAST(NULLIF(TRIM(/*M3*/ b.bet06),'') AS DATETIME)                   AS settle_ts,
        CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)     AS turnover,
        CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)     AS net_pl,
        CAST(NULLIF(TRIM(b.bet14),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)     AS payout
    FROM ods_mariadb_2b.bet02 b
    WHERE b.bet03 <> '0'                      -- 铁律④ 剔哨兵局
      AND COALESCE(b.age022,'') <> '1'        -- 铁律④ 剔测试线
      AND NULLIF(TRIM(b.bet13),'') IS NOT NULL
      AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
),

/* 局内相对时序：用同桌同局最早下注时刻为原点，导出「尾秒下注」特征 */
round_anchor AS (
    SELECT
        table_id, round_no,
        MIN(bet_ts)                                                          AS round_open_ts,
        MAX(bet_ts)                                                          AS round_close_ts,
        COUNT(DISTINCT member_id)                                            AS n_member_in_round
    FROM base
    GROUP BY table_id, round_no
),

enriched AS (
    SELECT
        b.*,
        r.round_open_ts,
        r.round_close_ts,
        r.n_member_in_round,
        TIMESTAMPDIFF(SECOND, r.round_open_ts, b.bet_ts)                     AS sec_from_open,
        TIMESTAMPDIFF(SECOND, b.bet_ts, r.round_close_ts)                    AS sec_to_close,
        HOUR(b.bet_ts)                                                       AS bet_hour,
        DATE(b.bet_ts)                                                       AS bet_date
    FROM base b
    JOIN round_anchor r
      ON b.table_id = r.table_id AND b.round_no = r.round_no
),

/* 退水率：优先 1:1 注单级；若 SQL-0c 判定不可 1:1，改走注释中的会员日均分支 */
rebate AS (
    SELECT
        /*M1*/ a.bet04                                                       AS member_id,
        AVG(CAST(NULLIF(TRIM(a.bet14),'') AS DECIMAL(10,6)))                 AS avg_rebate_rate
    FROM ods_mariadb_2b.bet01 a
    WHERE a.bet03 <> '0'
      AND COALESCE(a.age022,'') <> '1'
      AND NULLIF(TRIM(a.bet14),'') IS NOT NULL
    GROUP BY /*M1*/ a.bet04
),

agg AS (
    SELECT
        e.member_id,

        /* ---- A. 规模与生命周期 ---------------------------------------- */
        COUNT(*)                                                             AS n_bets,
        COUNT(DISTINCT e.bet_date)                                           AS n_active_days,
        MIN(e.bet_date)                                                      AS first_bet_date,
        MAX(e.bet_date)                                                      AS last_bet_date,
        DATEDIFF(MAX(e.bet_date), MIN(e.bet_date)) + 1                       AS tenure_days,
        COUNT(DISTINCT e.bet_date) * 1.0
            / NULLIF(DATEDIFF(MAX(e.bet_date), MIN(e.bet_date)) + 1, 0)      AS activity_density,

        /* ---- B. 金额口径（LRGG 支出维 / UKGC 净损维）------------------- */
        SUM(e.turnover)                                                      AS turnover_total,
        AVG(e.turnover)                                                      AS turnover_avg_bet,
        STDDEV_SAMP(e.turnover)                                              AS turnover_sd_bet,
        STDDEV_SAMP(e.turnover) / NULLIF(AVG(e.turnover),0)                  AS turnover_cv,
        MAX(e.turnover)                                                      AS turnover_max_bet,
        PERCENTILE_APPROX(e.turnover, 0.95)                                  AS turnover_p95_bet,
        SUM(e.turnover) / NULLIF(COUNT(DISTINCT e.bet_date),0)               AS turnover_per_active_day,
        SUM(e.net_pl)                                                        AS net_pl_total,
        SUM(CASE WHEN e.net_pl < 0 THEN -e.net_pl ELSE 0 END)                AS gross_loss,
        SUM(CASE WHEN e.net_pl > 0 THEN  e.net_pl ELSE 0 END)                AS gross_win,
        SUM(e.net_pl) / NULLIF(SUM(e.turnover),0)                            AS realised_hold_rate,

        /* ---- C. 频次与节律（LRGG 频次维）------------------------------ */
        COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT e.bet_date),0)                AS bets_per_active_day,
        SUM(CASE WHEN e.bet_hour BETWEEN 0 AND 5 THEN 1 ELSE 0 END) * 1.0
            / COUNT(*)                                                       AS night_bet_ratio,
        COUNT(DISTINCT DATE_FORMAT(e.bet_ts,'%Y-%u'))                        AS n_active_weeks,

        /* ---- D. 多样性（LRGG 品类维）--------------------------------- */
        COUNT(DISTINCT e.game_type)                                          AS n_game_types,
        COUNT(DISTINCT e.table_id)                                           AS n_tables,
        COUNT(DISTINCT e.dealer_id)                                          AS n_dealers,
        COUNT(DISTINCT e.round_no)                                           AS n_rounds,

        /* ---- E. 风控行为特征（三规则的连续版，供模型用而非阈值判定）---- */
        AVG(e.sec_from_open)                                                 AS avg_sec_from_open,
        PERCENTILE_APPROX(e.sec_from_open, 0.50)                             AS med_sec_from_open,
        SUM(CASE WHEN e.sec_to_close <= 2 THEN 1 ELSE 0 END) * 1.0
            / COUNT(*)                                                       AS tail2s_bet_ratio,
        SUM(CASE WHEN e.sec_to_close <= 1 THEN 1 ELSE 0 END) * 1.0
            / COUNT(*)                                                       AS tail1s_bet_ratio,
        AVG(e.n_member_in_round)                                             AS avg_round_crowding,
        SUM(CASE WHEN e.n_member_in_round >= 2 THEN 1 ELSE 0 END) * 1.0
            / COUNT(*)                                                       AS co_seated_ratio,
        MAX(e.n_member_in_round)                                             AS max_round_crowding,

        /* ---- F. 荷官集中度（HHI，越高越可疑）--------------------------- */
        SUM(POW(dealer_share, 2))                                            AS dealer_hhi
    FROM (
        SELECT e.*,
               COUNT(*) OVER (PARTITION BY e.member_id, e.dealer_id) * 1.0
               / COUNT(*) OVER (PARTITION BY e.member_id)                    AS dealer_share
        FROM enriched e
    ) e
    GROUP BY e.member_id
)

SELECT
    a.*,
    COALESCE(r.avg_rebate_rate, 0)                                           AS avg_rebate_rate,
    a.turnover_total * COALESCE(r.avg_rebate_rate, 0)                        AS rebate_cost_est,
    /* 返水后平台净收益 = -净盈亏(会员视角) - 返水成本 */
    (-a.net_pl_total) - a.turnover_total * COALESCE(r.avg_rebate_rate, 0)    AS platform_margin_net_of_rebate,
    /* 动态分层：全部切点由数据本身给出，无硬编码 */
    NTILE(10) OVER (ORDER BY a.turnover_total)                               AS decile_turnover,
    NTILE(10) OVER (ORDER BY a.gross_loss)                                   AS decile_gross_loss,
    NTILE(10) OVER (ORDER BY a.activity_density)                             AS decile_frequency
FROM agg a
LEFT JOIN rebate r ON a.member_id = r.member_id;

-- 建议：SQL Lab 中 "CREATE TABLE ods_mariadb_2b.tmp_member_wide_v2 AS <上述查询>"
-- 落表后再做 SQL-3/4/5，避免重复全表扫描。


/* ==========================================================================
   SQL-2 ｜ 会员 × 周 时序面板（purged walk-forward 切分底座）
   -------------------------------------------------------------------------
   粒度 : 1 行 = 1 会员 × 1 自然周
   关键 : 同时输出 t1（标签实现时刻），R 端 purge/embargo 必须依赖它
          —— 无 t1 就无法做 López de Prado 式净化，直接 k-fold 必然泄漏
   ========================================================================== */

WITH base AS (
    SELECT
        /*M1*/ b.bet04                                                       AS member_id,
        /*M6*/ b.bet09                                                       AS dealer_id,
        /*M7*/ b.bet10                                                       AS game_type,
        /*M4*/ b.bet07                                                       AS table_id,
        CAST(NULLIF(TRIM(/*M2*/ b.bet05),'') AS DATETIME)                    AS bet_ts,
        CAST(NULLIF(TRIM(/*M3*/ b.bet06),'') AS DATETIME)                    AS settle_ts,
        CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)      AS turnover,
        CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)      AS net_pl
    FROM ods_mariadb_2b.bet02 b
    WHERE b.bet03 <> '0'
      AND COALESCE(b.age022,'') <> '1'
      AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
),
wk AS (
    SELECT
        member_id,
        DATE_TRUNC('week', bet_ts)                                           AS week_start,
        COUNT(*)                                                             AS n_bets,
        COUNT(DISTINCT DATE(bet_ts))                                         AS n_days,
        SUM(turnover)                                                        AS turnover,
        SUM(net_pl)                                                          AS net_pl,
        SUM(CASE WHEN net_pl < 0 THEN -net_pl ELSE 0 END)                    AS gross_loss,
        AVG(turnover)                                                        AS avg_stake,
        MAX(turnover)                                                        AS max_stake,
        COUNT(DISTINCT game_type)                                            AS n_game_types,
        COUNT(DISTINCT table_id)                                             AS n_tables,
        COUNT(DISTINCT dealer_id)                                            AS n_dealers,
        /* t0 / t1 —— purge & embargo 的两根锚 */
        MIN(bet_ts)                                                          AS t0_first_bet,
        MAX(COALESCE(settle_ts, bet_ts))                                     AS t1_last_settle
    FROM base
    GROUP BY member_id, DATE_TRUNC('week', bet_ts)
)
SELECT
    w.*,
    /* 行为漂移：注意用显式 LAG 窗口，勿与 stats::lag 混淆（R 端同名冲突） */
    LAG(w.turnover)  OVER (PARTITION BY w.member_id ORDER BY w.week_start)   AS turnover_lag1,
    LAG(w.avg_stake) OVER (PARTITION BY w.member_id ORDER BY w.week_start)   AS avg_stake_lag1,
    w.turnover / NULLIF(LAG(w.turnover)
        OVER (PARTITION BY w.member_id ORDER BY w.week_start),0)             AS turnover_wow,
    w.avg_stake / NULLIF(LAG(w.avg_stake)
        OVER (PARTITION BY w.member_id ORDER BY w.week_start),0)             AS stake_escalation,
    /* 追损标记：上周净亏 且 本周投注放大 —— chasing losses 的可计算代理 */
    CASE WHEN LAG(w.net_pl) OVER (PARTITION BY w.member_id ORDER BY w.week_start) < 0
              AND w.turnover > LAG(w.turnover)
                   OVER (PARTITION BY w.member_id ORDER BY w.week_start)
         THEN 1 ELSE 0 END                                                   AS flag_chasing,
    /* 滚动 4 周净损（对标 UKGC 90 天 / 30 天滚动窗口逻辑） */
    SUM(w.gross_loss) OVER (PARTITION BY w.member_id ORDER BY w.week_start
                            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)        AS gross_loss_roll4w,
    ROW_NUMBER() OVER (PARTITION BY w.member_id ORDER BY w.week_start)       AS week_seq
FROM wk w;

-- ⚠️ 去重铁律提醒：若本条需分页导出，务必带 ORDER BY member_id, week_start，
--    否则 StarRocks 分页无序会再次制造 36% 级别重复（V1 已踩过）。


/* ==========================================================================
   SQL-3 ｜ 五规则命中位图 + 多标叠加名单
   -------------------------------------------------------------------------
   前置 : 三规则 / IP 稀有网段 / 脚本户 已跑通，请各自落成下列结构的临时表
          tmp_rule_xxx(member_id VARCHAR, rule_score DOUBLE)
          —— 若你已落成别名，改 FROM 即可，其余逻辑不动
   输出 : 会员级 5 位标记 + 命中数 + 分层，直接产出「双标/三标以上」高置信名单
   ========================================================================== */

WITH universe AS (
    /* 铁律⑤：分母 = 有下注行为会员，动态求出，不写死 1,329,000 */
    SELECT DISTINCT /*M1*/ bet04 AS member_id
    FROM ods_mariadb_2b.bet02
    WHERE bet03 <> '0' AND COALESCE(age022,'') <> '1'
),
r1 AS (SELECT member_id, rule_score FROM ods_mariadb_2b.tmp_rule_tailbet),   -- 后段/尾秒下注
r2 AS (SELECT member_id, rule_score FROM ods_mariadb_2b.tmp_rule_collusion), -- 同桌合谋
r3 AS (SELECT member_id, rule_score FROM ods_mariadb_2b.tmp_rule_dealer),    -- 荷官关联
r4 AS (SELECT member_id, rule_score FROM ods_mariadb_2b.tmp_rule_ip),        -- IP 稀有网段集群
r5 AS (SELECT member_id, rule_score FROM ods_mariadb_2b.tmp_rule_script),    -- 脚本户
flags AS (
    SELECT
        u.member_id,
        CASE WHEN r1.member_id IS NOT NULL THEN 1 ELSE 0 END                 AS f_tailbet,
        CASE WHEN r2.member_id IS NOT NULL THEN 1 ELSE 0 END                 AS f_collusion,
        CASE WHEN r3.member_id IS NOT NULL THEN 1 ELSE 0 END                 AS f_dealer,
        CASE WHEN r4.member_id IS NOT NULL THEN 1 ELSE 0 END                 AS f_ip,
        CASE WHEN r5.member_id IS NOT NULL THEN 1 ELSE 0 END                 AS f_script,
        COALESCE(r1.rule_score,0) AS s_tailbet,
        COALESCE(r2.rule_score,0) AS s_collusion,
        COALESCE(r3.rule_score,0) AS s_dealer,
        COALESCE(r4.rule_score,0) AS s_ip,
        COALESCE(r5.rule_score,0) AS s_script
    FROM universe u
    LEFT JOIN r1 ON u.member_id = r1.member_id
    LEFT JOIN r2 ON u.member_id = r2.member_id
    LEFT JOIN r3 ON u.member_id = r3.member_id
    LEFT JOIN r4 ON u.member_id = r4.member_id
    LEFT JOIN r5 ON u.member_id = r5.member_id
)
SELECT
    f.*,
    f.f_tailbet + f.f_collusion + f.f_dealer + f.f_ip + f.f_script           AS n_flags,
    /* 5 位二进制指纹，便于按组合模式聚类（如 '11000' = 尾秒+合谋） */
    CONCAT(CAST(f.f_tailbet AS STRING), CAST(f.f_collusion AS STRING),
           CAST(f.f_dealer  AS STRING), CAST(f.f_ip        AS STRING),
           CAST(f.f_script  AS STRING))                                      AS flag_bitmap,
    CASE
        WHEN f.f_tailbet + f.f_collusion + f.f_dealer + f.f_ip + f.f_script >= 3
             THEN 'T1_最高置信'
        WHEN f.f_tailbet + f.f_collusion + f.f_dealer + f.f_ip + f.f_script  = 2
             THEN 'T2_双标待核'
        WHEN f.f_tailbet + f.f_collusion + f.f_dealer + f.f_ip + f.f_script  = 1
             THEN 'T3_单标观察'
        ELSE 'T4_未命中'
    END                                                                      AS confidence_tier
FROM flags f
WHERE f.f_tailbet + f.f_collusion + f.f_dealer + f.f_ip + f.f_script > 0
ORDER BY n_flags DESC, s_collusion DESC;

-- 配套渗透率（务必用同一 universe 做分母，铁律⑤）
-- SELECT confidence_tier, COUNT(*) AS n,
--        COUNT(*) * 1.0 / (SELECT COUNT(*) FROM universe) AS penetration
-- FROM <上述结果> GROUP BY confidence_tier;


/* ==========================================================================
   SQL-4 ｜ 半监督锚点校准：dailyreport_member.risk × 规则命中
   -------------------------------------------------------------------------
   用途 : 平台现成风险标签作弱监督锚点，量化五规则的 Precision / Recall / Lift。
          这是把「规则体系」升级为「评分体系」的验收关口。
   注意 : risk 是平台自评标签，非金标准 —— 报告中须写明其为 noisy label，
          结论用 Lift 表述而非 Accuracy（类别极不平衡时 Accuracy 无意义）。
   ========================================================================== */

WITH universe AS (
    SELECT DISTINCT /*M1*/ bet04 AS member_id
    FROM ods_mariadb_2b.bet02
    WHERE bet03 <> '0' AND COALESCE(age022,'') <> '1'
),
anchor AS (
    /* 会员级取最严风险标签（一个会员多日多行 → 取 MAX） */
    SELECT
        d.memberid                                                           AS member_id,
        MAX(CAST(NULLIF(TRIM(d.risk),'') AS INT))                            AS risk_max,
        COUNT(*)                                                             AS n_report_days
    FROM ods_mariadb_2b.dailyreport_member d
    WHERE NULLIF(TRIM(d.risk),'') IS NOT NULL
    GROUP BY d.memberid
),
joined AS (
    SELECT
        u.member_id,
        COALESCE(a.risk_max, 0)                                              AS y_anchor,
        COALESCE(f.n_flags, 0)                                               AS n_flags,
        COALESCE(f.f_tailbet,0)   AS f_tailbet,
        COALESCE(f.f_collusion,0) AS f_collusion,
        COALESCE(f.f_dealer,0)    AS f_dealer,
        COALESCE(f.f_ip,0)        AS f_ip,
        COALESCE(f.f_script,0)    AS f_script
    FROM universe u
    LEFT JOIN anchor a               ON u.member_id = a.member_id
    LEFT JOIN ods_mariadb_2b.tmp_flag_bitmap f ON u.member_id = f.member_id  -- SQL-3 落表
),
base_rate AS (
    SELECT
        COUNT(*)                                                             AS n_universe,
        SUM(CASE WHEN y_anchor > 0 THEN 1 ELSE 0 END)                        AS n_positive,
        SUM(CASE WHEN y_anchor > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)       AS prevalence
    FROM joined
)
/* 逐规则混淆矩阵 + Lift（UNION ALL 逐条展开，便于直接出表） */
SELECT rule_name, tp, fp, fn, tn,
       tp * 1.0 / NULLIF(tp + fp, 0)                                         AS precision_,
       tp * 1.0 / NULLIF(tp + fn, 0)                                         AS recall_,
       2.0 * tp / NULLIF(2 * tp + fp + fn, 0)                                AS f1,
       (tp * 1.0 / NULLIF(tp + fp, 0)) / NULLIF(br.prevalence, 0)            AS lift,
       (tp + fp) * 1.0 / br.n_universe                                       AS flagged_rate,
       br.prevalence                                                          AS anchor_prevalence,
       br.n_universe                                                          AS denominator_check
FROM (
    SELECT '规则1_尾秒下注' AS rule_name,
           SUM(CASE WHEN f_tailbet=1 AND y_anchor>0  THEN 1 ELSE 0 END) AS tp,
           SUM(CASE WHEN f_tailbet=1 AND y_anchor=0  THEN 1 ELSE 0 END) AS fp,
           SUM(CASE WHEN f_tailbet=0 AND y_anchor>0  THEN 1 ELSE 0 END) AS fn,
           SUM(CASE WHEN f_tailbet=0 AND y_anchor=0  THEN 1 ELSE 0 END) AS tn
    FROM joined
    UNION ALL
    SELECT '规则2_同桌合谋',
           SUM(CASE WHEN f_collusion=1 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_collusion=1 AND y_anchor=0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_collusion=0 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_collusion=0 AND y_anchor=0 THEN 1 ELSE 0 END)
    FROM joined
    UNION ALL
    SELECT '规则3_荷官关联',
           SUM(CASE WHEN f_dealer=1 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_dealer=1 AND y_anchor=0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_dealer=0 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_dealer=0 AND y_anchor=0 THEN 1 ELSE 0 END)
    FROM joined
    UNION ALL
    SELECT '规则4_IP稀有网段',
           SUM(CASE WHEN f_ip=1 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_ip=1 AND y_anchor=0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_ip=0 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_ip=0 AND y_anchor=0 THEN 1 ELSE 0 END)
    FROM joined
    UNION ALL
    SELECT '规则5_脚本户',
           SUM(CASE WHEN f_script=1 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_script=1 AND y_anchor=0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_script=0 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN f_script=0 AND y_anchor=0 THEN 1 ELSE 0 END)
    FROM joined
    UNION ALL
    SELECT '叠加_≥2标',
           SUM(CASE WHEN n_flags>=2 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN n_flags>=2 AND y_anchor=0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN n_flags< 2 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN n_flags< 2 AND y_anchor=0 THEN 1 ELSE 0 END)
    FROM joined
    UNION ALL
    SELECT '叠加_≥3标',
           SUM(CASE WHEN n_flags>=3 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN n_flags>=3 AND y_anchor=0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN n_flags< 3 AND y_anchor>0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN n_flags< 3 AND y_anchor=0 THEN 1 ELSE 0 END)
    FROM joined
) m
CROSS JOIN base_rate br
ORDER BY lift DESC;


/* ==========================================================================
   SQL-5 ｜ 荷官 × 日 面板（贝叶斯分层模型输入）
   -------------------------------------------------------------------------
   用途 : 供 R 端 brms/JMbayes2 拟合 随机截距 + 随机斜率：
            net_pl_rate ~ 1 + turnover_z + (1 + turnover_z | dealer_id)
          荷官层级异常 = 随机截距后验显著偏离 0
   注意 : 必须输出 n_bets 作为权重列，否则低样本荷官会主导后验（V1 教训）
   ========================================================================== */

WITH base AS (
    SELECT
        /*M6*/ b.bet09                                                       AS dealer_id,
        /*M4*/ b.bet07                                                       AS table_id,
        /*M7*/ b.bet10                                                       AS game_type,
        /*M1*/ b.bet04                                                       AS member_id,
        DATE(CAST(NULLIF(TRIM(/*M2*/ b.bet05),'') AS DATETIME))              AS bet_date,
        CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)      AS turnover,
        CAST(NULLIF(TRIM(b.bet17),'') AS DECIMAL(20,4))
            / NULLIF(CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)),0)      AS net_pl
    FROM ods_mariadb_2b.bet02 b
    WHERE b.bet03 <> '0'
      AND COALESCE(b.age022,'') <> '1'
      AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0
      AND NULLIF(TRIM(/*M6*/ b.bet09),'') IS NOT NULL
),
panel AS (
    SELECT
        dealer_id,
        bet_date,
        game_type,
        COUNT(*)                                                             AS n_bets,
        COUNT(DISTINCT member_id)                                            AS n_members,
        COUNT(DISTINCT table_id)                                             AS n_tables,
        SUM(turnover)                                                        AS turnover,
        SUM(net_pl)                                                          AS net_pl,
        SUM(net_pl) / NULLIF(SUM(turnover),0)                                AS member_edge,   -- 会员视角胜率偏离
        AVG(turnover)                                                        AS avg_stake,
        STDDEV_SAMP(turnover)                                                AS sd_stake
    FROM base
    GROUP BY dealer_id, bet_date, game_type
),
glob AS (
    SELECT AVG(member_edge) AS mu_edge, STDDEV_SAMP(member_edge) AS sd_edge
    FROM panel WHERE n_bets >= 30      -- 低样本日不参与全局基准估计
)
SELECT
    p.dealer_id,
    p.bet_date,
    p.game_type,
    p.n_bets,
    p.n_members,
    p.n_tables,
    p.turnover,
    p.net_pl,
    p.member_edge,
    p.avg_stake,
    p.sd_stake,
    /* 标准化：R 端建模前的 z 化在这里先做一次，保证 SQL/R 两侧口径一致 */
    (p.member_edge - g.mu_edge) / NULLIF(g.sd_edge,0)                        AS member_edge_z,
    /* 二项精确检验的解析近似：荷官日胜负偏离的 Wald z（供快筛，非最终判据） */
    p.net_pl / NULLIF(p.turnover * SQRT(1.0 / NULLIF(p.n_bets,0)),0)         AS wald_z_approx,
    /* 分层建模所需的权重列 —— 切勿在 R 端省略 */
    p.n_bets                                                                 AS model_weight,
    ROW_NUMBER() OVER (PARTITION BY p.dealer_id ORDER BY p.bet_date)         AS day_seq,
    COUNT(*)     OVER (PARTITION BY p.dealer_id)                             AS dealer_n_days
FROM panel p
CROSS JOIN glob g
WHERE p.n_bets >= 10        -- 动态下限，避免 1~2 注单的荷官日制造伪异常
ORDER BY p.dealer_id, p.bet_date;


/* ============================================================================
   收尾检查清单（跑完 5 条后逐项打勾，再进 .qmd 终稿）
   ----------------------------------------------------------------------------
   [ ] SQL-0 已锁定 M1–M8，本文件内已全局替换，无残留 ⚠️
   [ ] SQL-1 落表行数 ≈ 132.9 万（与铁律⑤分母一致，误差 <1%）
   [ ] SQL-2 导出前带 ORDER BY，去重校验 COUNT(*) = COUNT(DISTINCT member_id||week_start)
   [ ] SQL-3 五张 tmp_rule_* 均已存在且 member_id 类型一致（varchar↔varchar）
   [ ] SQL-4 denominator_check 列 = SQL-1 行数（分母一致性自检）
   [ ] SQL-5 dealer_n_days 分布无长尾单日荷官（否则调高 n_bets 下限）
   [ ] 全部结果导出为 CSV 时确认 UTF-8 BOM，避免中文列名乱码（V1 已踩过）
   ============================================================================ */
