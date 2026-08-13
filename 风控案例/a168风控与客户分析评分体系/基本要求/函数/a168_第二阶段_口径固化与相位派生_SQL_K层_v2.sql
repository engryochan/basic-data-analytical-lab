-- ═══════════════════════════════════════════════════════════════════════════
--   a168 · 第二阶段 · L2 计算正确性与口径固化
--   编号族 §K-xx（Kernel 核心口径层）
--   避开既用之 C／S／R／T／D／E／V／P0／TL／DX／EV／BZ／EX／A／I／L／X／Z 各族
-- ───────────────────────────────────────────────────────────────────────────
--   作者：Ryo Eng
--   日期：2026-08-13
--   库  ：ods_mariadb_2b（StarRocks，经 Superset SQL Lab 只读访问）
--   前置：第一阶段 §Z 全库结构与哨兵值审计（v5）之十二份读数已就位
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ═══ 撰写纪律（三重加固，承实证教训）═══════════════════════════════════════
--   一、全档不用块注释，只用行注释。行注释必至行尾而止，无闭合符可被误配。
--   二、注释内不写分号（半角与全角皆禁），一律以顿号代之。
--       实证：全角分号经转码变半角，落入注释即被语句切分器截断，
--       曾致 §Z-09c 报 Unexpected input。
--   三、注释内不写星号。实证：星号紧邻斜杠曾使注释提前终止，总包卷一有 24 处。
--   四、每条语句自包含、零占位符，整段复制即可运行。
--   五、逐条提交、禁批量。跑前按 Esc 清选区，确保无高亮。
--   六、每条语句有且仅有一条导出声明。标不需要者不含文件名。
--   七、另出净版无注释档，专供贴入执行。留档用注释版，执行用净版。
--
-- ═══ 第一阶段已闭合之结论（本层据此建立，不再重议）═══════════════════════
--   结论一：dt 即 bet07 帳務日期，实测 131,058,975 分之 131,058,975 全等。
--           而 dt 与 DATE(bet08) 仅 61.4 相符，两者相差 38.6 个百分点。
--           故日、月、滚动窗口一律以 dt 切日，禁用 DATE(bet08)。
--   结论二：局键 bet03 加 bet04 加 bet39 健全。跨桌局键为零、bet03 跨桌数为零，
--           即 bet03 已决定桌号，bet39 于键中属冗余项，无害但可简化。
--           局键含哨兵值仅 102 行，占八千万分之一，塌缩未发生。
--   结论三：bet06 为开放下注时刻，非开牌。纪元哨兵为零，时序异常仅 3 笔。
--   结论四：下注窗口为桌台级常量。30 张桌跨六月零迁移、跨房零分歧。
--           短制式 7 张（桌 1,2,3,5,6,7,8），长制式 23 张。
--           惟窗口秒数本层一律自数据求得，不写死任何秒数。
--   结论五：eid 等于负一者占 15.24，计 19,982,734 笔。
--           成因待上游确认，本层先行分层，不先剔除。
--   结论六：validbet 为有效投注。bet41 于 bet02 为下注退水金額，
--           于 dailyreport_member 为有效投注，二者同名异义，切勿互换。
--
-- ═══ 常数集中登记（改一处即全层生效，禁散落）═════════════════════════════
--   常数名          取值             出现处数   语义
--   GAME_BACCARAT   '101'            见各条     bet02 游戏类别百家乐
--   CAT_NORMAL      '1'              见各条     category 一般注单，非小费
--   REBET_NO        'N'              见各条     bet38 非重对
--   TESTLINE        age022 = '1'     见各条     公司测试线代理，五级排除
--   WIN_QUANTILE    0.99             §K-04     求桌台窗口所取之分位数
--   DEF_LOCK        'K1_20260813'    §K-05 起  口径锁定列取值
--   改口径之作业纪律：先全文检索点数、改毕再检索确认旧值零残留、
--   并于变更记录写明改前改后之六元组。
--
-- ═══ 待确认事项（显式列示，未答不得下结论）═══════════════════════════════
--   待-K1  eid 等于负一之业务成因未明（字段未采集、该场景不适用、
--          ETL 故障、尚未发生，四者处置迥异）。
--          受影响 SQL：§K-09。
--          受影响输出：一切荷官维度之结论，含荷官评分与荷官作弊线。
--          在答复到位前，涉荷官之正式结论一律 S2 阻断。
--   待-K2  commission 有 -100、-1、-999 三种脏值，合计 17 笔。
--          受影响 SQL：§K-03 之免佣分层。量微，惟须定性后方可剔或留。
--   待-K3  逾制局占 0.37，即最末下注秒超出该桌窗口者。
--          受影响 SQL：§K-04、§K-05。须查其成因为时钟偏移抑或补单。
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-00 · 会话参数
--   每个 Superset 会话开跑前逐条单跑一次。任一行报错径行跳过，不影响正确性。
--   ▸ 导出：不需要 —— 会话参数设置，无结果集
-- ═══════════════════════════════════════════════════════════════════════════
SET SESSION query_timeout = 259200;
SET SESSION cbo_cte_reuse = true;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-01 · 有效订单漏斗核对
--   目的：固化去重与有效订单口径，并逐级量化折损，确立本层一切比率之分母。
--   口径：先去重、后过滤。同一 bet01 取 updatetime、sync_time、dt 三级降序之首行，
--         再对该最新版施加五项有效性条件。
--         反序执行会把最新版已失效而旧版仍有效者错误保留，本表可量化其差额。
--   判读：S1 阶段之折损即历史版本行数。S2 至 S6 各级折损率若异常之高，
--         须回查是否误伤，不得径行接受。
--   ▸ 导出：需要 —— 存为「数据库 目录 K01_valid_order_funnel.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH v AS (
  SELECT b.bet01, b.bet05, b.bet08, b.bet11, b.bet38, b.category, b.dt,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
latest AS (SELECT * FROM v WHERE rn = 1)
SELECT
    (SELECT COUNT(*) FROM v)                                        AS S0_原始行数,
    (SELECT COUNT(*) FROM latest)                                   AS S1_去重后订单数,
    (SELECT COUNT(*) FROM v) - (SELECT COUNT(*) FROM latest)        AS S1_历史版本行数,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1' THEN 1 ELSE 0 END) AS S2_叠加category,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
             THEN 1 ELSE 0 END)                                     AS S3_叠加非重对,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
             THEN 1 ELSE 0 END)                                     AS S4_叠加会员号为正,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
              AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0
             THEN 1 ELSE 0 END)                                     AS S5_叠加汇率为正,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
              AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0
              AND NULLIF(TRIM(bet08),'') IS NOT NULL
             THEN 1 ELSE 0 END)                                     AS S6_有效订单数,
    SUM(CASE WHEN CAST(NULLIF(TRIM(bet05),'') AS BIGINT) IS NULL
             THEN 1 ELSE 0 END)                                     AS 附_会员号非数值,
    MIN(dt)                                                         AS 附_dt最小,
    MAX(dt)                                                         AS 附_dt最大
FROM latest;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-02 · 测试线代理排除之影响量化
--   目的：总包以 age022 等于 1 之五级代理线排除公司测试线。本条量化其规模，
--         使该项排除由不可见变为可核对。
--   ▸ 导出：需要 —— 存为「数据库 目录 K02_testline_impact.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet05, b.bet08, b.bet11, b.bet13, b.bet38, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT r.*,
         COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) AS hit_testline
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
)
SELECT
    (SELECT COUNT(*) FROM ta)                                       AS 测试线代理数,
    COUNT(*)                                                        AS 有效订单数含测试线,
    SUM(CASE WHEN hit_testline IS NULL THEN 1 ELSE 0 END)           AS 有效订单数排除后,
    SUM(CASE WHEN hit_testline IS NOT NULL THEN 1 ELSE 0 END)       AS 测试线订单数,
    SUM(CASE WHEN hit_testline IS NOT NULL THEN 1 ELSE 0 END)
      * 1.0 / NULLIF(COUNT(*), 0)                                   AS 测试线订单占比,
    COUNT(DISTINCT CAST(bet05 AS VARCHAR))                          AS 会员数含测试线,
    COUNT(DISTINCT CASE WHEN hit_testline IS NULL
                        THEN CAST(bet05 AS VARCHAR) END)            AS 会员数排除后,
    SUM(CASE WHEN hit_testline IS NOT NULL
             THEN CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
                  / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))
             ELSE 0 END)                                            AS 测试线本金
FROM vd;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-03 · 金额四口径与恒等式核验
--   口径：本金等于 bet13 除以 bet11，洗码量等于 validbet 除以 bet11，
--         游戏输赢等于 bet14 减 bet13 再除以 bet11，
--         退水等于 bet16 除以 bet11，净输赢等于 bet17 除以 bet11。
--   恒等式并试三式，以定 bet41 下注退水金額是否入账：
--         式一  净输赢 减 游戏输赢 减 退水
--         式二  净输赢 减 游戏输赢 减 退水 减 下注退水
--         式三  净输赢 减 游戏输赢 减 下注退水
--   判读：三式之中残差绝对值最小者，即为真实之结算关系。
--         若式一即为零，则 bet41 不入账，需求文档四条算式完备。
--         若式二为零，则四条算式漏项，须补 bet41。
--         残差非零而三式皆不为零者，另有未知项，须回查上游。
--   ▸ 导出：需要 —— 存为「数据库 目录 K03_amount_identity.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.dt, b.bet05, b.bet08, b.bet11, b.bet13, b.bet14,
         b.bet16, b.bet17, b.bet41, b.validbet, b.commission,
         b.bet38, b.category, b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT
      dt,
      CAST(NULLIF(TRIM(commission),'') AS VARCHAR)                  AS comm_flag,
      CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS stake,
      CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS valid_bet,
      (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS game_pnl,
      CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS rebate,
      CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS bet_rebate,
      CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))             AS net_pnl
  FROM vd
)
SELECT
    dt                                                              AS 日期,
    COUNT(*)                                                        AS 有效订单数,
    SUM(stake)                                                      AS 本金,
    SUM(valid_bet)                                                  AS 洗码量,
    SUM(game_pnl)                                                   AS 游戏输赢,
    SUM(rebate)                                                     AS 退水,
    SUM(bet_rebate)                                                 AS 下注退水,
    SUM(net_pnl)                                                    AS 净输赢,
    SUM(net_pnl) - SUM(game_pnl) - SUM(rebate)                      AS 残差式一,
    SUM(net_pnl) - SUM(game_pnl) - SUM(rebate) - SUM(bet_rebate)    AS 残差式二,
    SUM(net_pnl) - SUM(game_pnl) - SUM(bet_rebate)                  AS 残差式三,
    SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)                       AS 游戏输赢率洗码量为分母,
    SUM(game_pnl) / NULLIF(SUM(stake), 0)                           AS 游戏输赢率本金为分母,
    SUM(CASE WHEN comm_flag = '1' THEN 1 ELSE 0 END)                AS 免佣订单数,
    SUM(CASE WHEN comm_flag NOT IN ('0','1') THEN 1 ELSE 0 END)     AS 佣金标脏值订单数
FROM bs
GROUP BY dt
ORDER BY dt;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-04 · 桌台窗口之分位数对照（v2 降级为对照，正解见 §K-04b）
--   v1 实测教训：以 P99 为窗口上界，在小样本桌上被逾制局拉高。
--     实证：§K-05 得七种窗口秒 13、25、28、29、30、31、32。
--     然而窗口 28 至 32 之各桌，封盘前一秒内之注单占比仅 0.04 至 0.13，
--     常规时段却占 85 至 99.5。若窗口果真为 28 至 32 秒，
--     则封盘前一秒内理应聚集大量注单，正如窗口 13 之桌占 18.96、
--     窗口 25 之桌占 8.68 那样。可见 28 至 32 系高估，真实窗口更短。
--     根因：P99 仍是人选之参数，非数据自身之断点。
--   故本条降为对照用，只出分位数供检视，不再据以定窗口。
--   窗口之正解改由 §K-04b 之众数法给出。
--   ▸ 导出：需要 —— 存为「数据库 目录 K04_table_window.csv」
-- ═══════════════════════════════════════════════════════════════════════════
--   §K-04b · 桌台窗口之众数解（本层窗口口径之正解）
--   方法：逐桌统计各局最末下注秒之频次，取频次最高者为该桌窗口上界。
--   何以众数优于分位数：分位数须人先选一个 p，而 p 本身即是硬编码。
--     众数由数据自身之峰值给出，无须人选，亦不受少数逾制局影响。
--   输出前三高频秒及其占比，使众数是否稳固一望即知。
--   判读：众数占比逾三成者窗口稳固。
--     若前三高频秒相邻且合计逾五成，可采其最大者。
--     若众数占比不足一成，则该桌窗口不清晰，须单独查明方可用于相位计算。
--   ▸ 导出：需要 —— 存为「数据库 目录 K04b_table_window_mode.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet06, b.bet08,
         b.bet11, b.bet38, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(r.bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME))                 AS d_sec
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
rmax AS (
  SELECT table_id, round_key, MAX(d_sec) AS max_d
  FROM vd WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, round_key
),
hist AS (
  SELECT table_id, max_d, COUNT(*) AS n_rounds
  FROM rmax GROUP BY table_id, max_d
),
tot AS (
  SELECT table_id, SUM(n_rounds) AS n_all FROM hist GROUP BY table_id
),
rk AS (
  SELECT h.table_id, h.max_d, h.n_rounds, t.n_all,
         h.n_rounds * 1.0 / t.n_all                                 AS share,
         ROW_NUMBER() OVER (PARTITION BY h.table_id
                            ORDER BY h.n_rounds DESC, h.max_d DESC) AS rnk
  FROM hist h JOIN tot t ON t.table_id = h.table_id
)
SELECT
    table_id                                                        AS 桌号,
    MAX(n_all)                                                      AS 局数,
    MAX(CASE WHEN rnk = 1 THEN max_d END)                           AS 窗口秒_众数解,
    MAX(CASE WHEN rnk = 1 THEN share END)                           AS 众数占比,
    MAX(CASE WHEN rnk = 2 THEN max_d END)                           AS 次高频秒,
    MAX(CASE WHEN rnk = 2 THEN share END)                           AS 次高频占比,
    MAX(CASE WHEN rnk = 3 THEN max_d END)                           AS 第三高频秒,
    MAX(CASE WHEN rnk = 3 THEN share END)                           AS 第三高频占比,
    SUM(CASE WHEN rnk <= 3 THEN share ELSE 0 END)                   AS 前三合计占比,
    CASE WHEN MAX(CASE WHEN rnk = 1 THEN share END) >= 0.30 THEN 'A_稳固'
         WHEN SUM(CASE WHEN rnk <= 3 THEN share ELSE 0 END) >= 0.50
              THEN 'B_可用_取前三之最大者'
         ELSE 'C_不清晰_须单独查明' END                              AS 稳健性判定
FROM rk
GROUP BY table_id
ORDER BY 窗口秒_众数解, 桌号;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-05 · 注单相位明细基表
--   目的：为需求文档第五章之尾秒分析铺底。派生两项相位指标。
--         距封盘秒数 等于 该桌窗口秒 减 距开局秒数
--         下注进度   等于 距开局秒数 除以 该桌窗口秒
--   窗口秒一律由 §K-04 之同一逻辑于本条内自数据求得，不引外部常数、不写死秒数。
--   口径锁定：本条输出常量列 def_lock，取值 K1_20260813。
--         凡窗口口径变更，必同步改该列取值。
--         报告侧将其登记为必需列，旧版 CSV 因缺列或值不符而当场报错，
--         静默语义漂移自此变为显式失败。承 late_def 之例。
--   注意：bet08 精度为秒，故同一秒内之先后不可分辨。
--         封盘前一秒实为一个整秒区间，非瞬时。
--   ▸ 导出：需要 —— 存为「数据库 目录 K05_bet_phase_dist.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet06, b.bet08,
         b.bet09, b.bet11, b.bet13, b.bet14, b.validbet, b.eid,
         b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.bet09 AS VARCHAR)                                      AS bet_side,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(r.bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME))                 AS d_sec,
      CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS valid_bet,
      (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS game_pnl
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
rmax AS (
  SELECT table_id, round_key, MAX(d_sec) AS max_d
  FROM vd WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, round_key
),
wh AS (
  SELECT table_id, max_d, COUNT(*) AS n_rounds
  FROM rmax GROUP BY table_id, max_d
),
tw AS (
  SELECT table_id, max_d AS win_sec FROM (
    SELECT table_id, max_d,
           ROW_NUMBER() OVER (PARTITION BY table_id
                              ORDER BY n_rounds DESC, max_d DESC) AS rnk
    FROM wh) x WHERE rnk = 1
),
ph AS (
  SELECT d.*, w.win_sec,
         w.win_sec - d.d_sec                                        AS sec_to_close,
         d.d_sec * 1.0 / NULLIF(w.win_sec, 0)                       AS bet_progress
  FROM vd d JOIN tw w ON w.table_id = d.table_id
  WHERE d.d_sec IS NOT NULL
)
SELECT
    'K1_20260813'                                                   AS def_lock,
    win_sec                                                         AS 桌台窗口秒,
    CASE WHEN d_sec < 0                THEN 'A_时序异常'
         WHEN sec_to_close < 0         THEN 'B_逾制'
         WHEN sec_to_close <= 1        THEN 'C_封盘前1秒内'
         WHEN sec_to_close <= 2        THEN 'D_封盘前1至2秒'
         WHEN sec_to_close <= 3        THEN 'E_封盘前2至3秒'
         WHEN sec_to_close <= 5        THEN 'F_封盘前3至5秒'
         ELSE                               'G_常规时段' END        AS 相位段,
    COUNT(*)                                                        AS 注单数,
    COUNT(DISTINCT member_id)                                       AS 会员数,
    COUNT(DISTINCT round_key)                                       AS 局数,
    COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY win_sec)      AS 段内注单占比,
    SUM(valid_bet)                                                  AS 洗码量,
    SUM(game_pnl)                                                   AS 游戏输赢,
    SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)                       AS 游戏输赢率,
    PERCENTILE_APPROX(CAST(bet_progress AS DOUBLE), 0.50)           AS 下注进度P50
FROM ph
GROUP BY win_sec,
    CASE WHEN d_sec < 0                THEN 'A_时序异常'
         WHEN sec_to_close < 0         THEN 'B_逾制'
         WHEN sec_to_close <= 1        THEN 'C_封盘前1秒内'
         WHEN sec_to_close <= 2        THEN 'D_封盘前1至2秒'
         WHEN sec_to_close <= 3        THEN 'E_封盘前2至3秒'
         WHEN sec_to_close <= 5        THEN 'F_封盘前3至5秒'
         ELSE                               'G_常规时段' END
ORDER BY 桌台窗口秒, 相位段;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-06 · 玩家物理局聚合与胜负和
--   口径：承需求文档第三章第四节。同一玩家同一物理局之多笔注单先聚合，
--         再以局游戏输赢之正负零判胜负和。和局不进入胜率分母。
--   何以必须先聚合：同一玩家同一局往往下多笔。按单笔判胜负者，
--         多笔下注者之胜率被系统性拉向五成，与单笔下注者不可比。
--   须记一事：此处之和局为该玩家该局净收支为零，非牌面和局。
--         牌面和局押庄闲退回本金者落入此格，
--         而同局对冲致收支抵销者亦落入此格，二者性质迥异。
--         对打型账户之局面恰会大量落入此格，故另出对冲疑似列以备辨识。
--   相位归属：该玩家局之相位取其局内最末一笔注单之距封盘秒数。
--         若取首笔或均值，则先常规下注而末秒加注之形态将被误归常规段。
--   ▸ 导出：需要 —— 存为「数据库 目录 K06_player_round.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet06, b.bet08,
         b.bet09, b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,
         b.validbet, b.eid, b.ip, b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.ip    AS VARCHAR)                                      AS bet_ip,
      CAST(r.bet09 AS VARCHAR)                                      AS bet_side,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(r.bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME))                 AS d_sec,
      CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS stake,
      CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS valid_bet,
      (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS game_pnl,
      CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS rebate,
      CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS net_pnl
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
rmax AS (
  SELECT table_id, round_key, MAX(d_sec) AS max_d
  FROM vd WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, round_key
),
wh AS (
  SELECT table_id, max_d, COUNT(*) AS n_rounds
  FROM rmax GROUP BY table_id, max_d
),
tw AS (
  SELECT table_id, max_d AS win_sec FROM (
    SELECT table_id, max_d,
           ROW_NUMBER() OVER (PARTITION BY table_id
                              ORDER BY n_rounds DESC, max_d DESC) AS rnk
    FROM wh) x WHERE rnk = 1
),
pr AS (
  SELECT
      d.member_id, d.round_key, d.table_id,
      MIN(d.acct_date)                                              AS acct_date,
      MAX(d.dealer_id)                                              AS dealer_id_any,
      COUNT(DISTINCT d.dealer_id)                                   AS n_dealer_in_row,
      MAX(d.bet_ip)                                                 AS bet_ip_any,
      COUNT(*)                                                      AS n_orders,
      COUNT(DISTINCT d.bet_side)                                    AS n_side,
      SUM(d.stake)                                                  AS stake,
      SUM(d.valid_bet)                                              AS valid_bet,
      SUM(d.game_pnl)                                               AS game_pnl,
      SUM(d.rebate)                                                 AS rebate,
      SUM(d.net_pnl)                                                AS net_pnl,
      MAX(d.d_sec)                                                  AS last_d_sec
  FROM vd d
  GROUP BY d.member_id, d.round_key, d.table_id
)
SELECT
    'K1_20260813'                                                   AS def_lock,
    p.member_id                                                     AS 会员ID,
    p.round_key                                                     AS 物理局键,
    p.table_id                                                      AS 桌号,
    p.acct_date                                                     AS 账务日期,
    p.dealer_id_any                                                 AS 荷官ID,
    CASE WHEN p.dealer_id_any = '-1' THEN 1 ELSE 0 END              AS 是否哨兵荷官,
    p.bet_ip_any                                                    AS 下注IP,
    p.n_orders                                                      AS 局内注单数,
    p.n_side                                                        AS 局内玩法数,
    CASE WHEN p.n_side >= 2 AND p.game_pnl = 0 THEN 1 ELSE 0 END    AS 疑似同局对冲,
    p.stake                                                         AS 本金,
    p.valid_bet                                                     AS 洗码量,
    p.game_pnl                                                      AS 局游戏输赢,
    p.rebate                                                        AS 局退水,
    p.net_pnl                                                       AS 局净输赢,
    CASE WHEN p.game_pnl > 0 THEN '胜局'
         WHEN p.game_pnl < 0 THEN '负局'
         ELSE '和局' END                                            AS 局结果,
    p.last_d_sec                                                    AS 局内最末距开局秒,
    w.win_sec                                                       AS 桌台窗口秒,
    w.win_sec - p.last_d_sec                                        AS 局内最末距封盘秒
FROM pr p
JOIN tw w ON w.table_id = p.table_id
ORDER BY p.member_id, p.round_key;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-07 · 粒度守恒验证
--   目的：每一次聚合皆须声明输入输出粒度，防扇出重复计数。
--         本条把注单层、玩家局层、局层三级之行数与去重键并列，一次核对。
--   判读：玩家局层行数须等于注单层之 会员乘局 去重数。
--         局层行数须等于注单层之局键去重数。
--         二者若不等，即有扇出，须立即停止并回查连接。
--   ▸ 导出：需要 —— 存为「数据库 目录 K07_grain_conservation.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet11, b.ip, b.eid,
         b.bet38, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet08,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.ip    AS VARCHAR)                                      AS bet_ip,
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
)
SELECT
    COUNT(*)                                                        AS L0_注单层行数,
    COUNT(DISTINCT CONCAT_WS('#', member_id, round_key))            AS L1_玩家局层应有行数,
    COUNT(DISTINCT round_key)                                       AS L2_局层应有行数,
    COUNT(DISTINCT member_id)                                       AS L3_会员层应有行数,
    COUNT(DISTINCT table_id)                                        AS 桌台数,
    COUNT(DISTINCT dealer_id)                                       AS 荷官数含哨兵,
    COUNT(DISTINCT CASE WHEN dealer_id <> '-1' THEN dealer_id END)  AS 荷官数排除哨兵,
    COUNT(DISTINCT bet_ip)                                          AS IP数,
    COUNT(*) * 1.0
      / NULLIF(COUNT(DISTINCT CONCAT_WS('#', member_id, round_key)), 0)
                                                                    AS 每玩家局平均注单数,
    COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT round_key), 0)           AS 每局平均注单数
FROM vd;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-08 · 哨兵荷官分层与影响量化
--   缘起：第一阶段实测 eid 等于负一者占 15.24，计 19,982,734 笔。
--   原则：装载即分层，其后各块一律取合格层。本条先量化两层之规模与表现差异，
--         不先剔除。剔除与否待 §Z-10 之业务成因确认后方可裁定。
--   何以不先剔除：若其成因为尚未发生一类，剔除将造成选择性偏差,
--         被剔除者非随机，而系统性偏向某一类局面。
--   ▸ 导出：需要 —— 存为「数据库 目录 K08_sentinel_dealer.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet08, b.bet11,
         b.bet13, b.bet14, b.validbet, b.eid, b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key,
      CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS valid_bet,
      (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
       - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))           AS game_pnl
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
)
SELECT
    'K1_20260813'                                                   AS def_lock,
    CASE WHEN dealer_id = '-1' THEN 'S_哨兵层' ELSE 'Q_合格层' END   AS 分层,
    COUNT(*)                                                        AS 注单数,
    COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()                          AS 注单占比,
    COUNT(DISTINCT member_id)                                       AS 会员数,
    COUNT(DISTINCT round_key)                                       AS 局数,
    COUNT(DISTINCT table_id)                                        AS 桌台数,
    COUNT(DISTINCT dealer_id)                                       AS 荷官数,
    COUNT(DISTINCT acct_date)                                       AS 账务日数,
    MIN(acct_date)                                                  AS 起始日,
    MAX(acct_date)                                                  AS 结束日,
    SUM(valid_bet)                                                  AS 洗码量,
    SUM(game_pnl)                                                   AS 游戏输赢,
    SUM(game_pnl) / NULLIF(SUM(valid_bet), 0)                       AS 游戏输赢率
FROM vd
GROUP BY CASE WHEN dealer_id = '-1' THEN 'S_哨兵层' ELSE 'Q_合格层' END
ORDER BY 分层;


-- ═══════════════════════════════════════════════════════════════════════════
--   §K-09 · 连接前基数预估
--   缘起：总包纪律第九条。凡两表连接键不含局键或会员键、仅靠桌号或日期
--         这类低基数键相连者，必先各自聚合再连接。
--         注单粒度乘局粒度之裸连接曾使 S-02 三小时跑不完，即万亿级配对。
--   本条列出各候选连接键之基数与预估配对量，供连接前判断。
--   判读：预估配对量超过十亿者，一律先聚合再连接，不得裸连。
--   ▸ 导出：需要 —— 存为「数据库 目录 K09_join_cardinality.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
v AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet08, b.bet11,
         b.eid, b.ip, b.bet38, b.category, b.dt,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.bet02 = '101'
),
vd AS (
  SELECT
      CAST(r.bet05 AS VARCHAR)                                      AS member_id,
      CAST(r.eid   AS VARCHAR)                                      AS dealer_id,
      CAST(r.ip    AS VARCHAR)                                      AS bet_ip,
      CAST(r.bet39 AS VARCHAR)                                      AS table_id,
      r.dt                                                          AS acct_date,
      CONCAT_WS('|', CAST(r.bet03 AS VARCHAR),
                     CAST(r.bet04 AS VARCHAR),
                     CAST(r.bet39 AS VARCHAR))                      AS round_key
  FROM v r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND CAST(r.category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(r.bet38 AS VARCHAR))) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
sz AS (
  SELECT round_key, COUNT(DISTINCT member_id) AS n_member
  FROM vd GROUP BY round_key
)
SELECT
    'round_key 局键'                                                AS 连接键,
    COUNT(DISTINCT round_key)                                       AS 基数,
    '高基数，可直接连接'                                              AS 建议
FROM vd
UNION ALL
SELECT 'member_id 会员键', COUNT(DISTINCT member_id), '高基数，可直接连接' FROM vd
UNION ALL
SELECT 'bet_ip IP键', COUNT(DISTINCT bet_ip), '高基数，可直接连接' FROM vd
UNION ALL
SELECT 'table_id 桌号', COUNT(DISTINCT table_id), '低基数，须先聚合再连接' FROM vd
UNION ALL
SELECT 'dealer_id 荷官', COUNT(DISTINCT dealer_id), '低基数，须先聚合再连接' FROM vd
UNION ALL
SELECT 'acct_date 账务日', COUNT(DISTINCT acct_date), '低基数，须先聚合再连接' FROM vd
UNION ALL
SELECT '同桌配对预估_局内两两组合',
       CAST(SUM(CAST(n_member AS BIGINT) * (CAST(n_member AS BIGINT) - 1) / 2) AS BIGINT),
       '此即同桌共现之实际配对量，超十亿者须设局规模上限'
FROM sz
ORDER BY 基数 DESC;


-- ═══════════════════════════════════════════════════════════════════════════
--   导出汇总，与语句一一对应
--     §K-00  不需要
--     §K-01  数据库 目录 K01_valid_order_funnel.csv
--     §K-02  数据库 目录 K02_testline_impact.csv
--     §K-03  数据库 目录 K03_amount_identity.csv
--     §K-04  数据库 目录 K04_table_window.csv
--     §K-05  数据库 目录 K05_bet_phase_dist.csv
--     §K-06  数据库 目录 K06_player_round.csv
--     §K-07  数据库 目录 K07_grain_conservation.csv
--     §K-08  数据库 目录 K08_sentinel_dealer.csv
--     §K-09  数据库 目录 K09_join_cardinality.csv
--   九个导出名与总包既有 66 个及 Z 族 11 个导出名皆零碰撞。
--
--   执行次序建议
--     §K-01 与 §K-07 先跑，代价小且立定粒度与分母。
--     §K-03 次之，恒等式三式一次分晓 bet41 是否入账。
--     §K-04 再次之，窗口秒一经求得，§K-05 与 §K-06 方能派生相位。
--     §K-06 为明细导出，量级约等于会员乘局，须先跑 COUNT 预检，
--       并以键集游标分页，按 会员ID 与 物理局键 升序，不得使用 OFFSET。
--
--   口径锁定
--     §K-05、§K-06、§K-08 三条各输出常量列 def_lock，取值 K1_20260813。
--     凡口径变更必同步改该列取值。报告侧将其登记为必需列，
--     旧版 CSV 因缺列或值不符而当场报错，静默语义漂移自此变为显式失败。
-- ═══════════════════════════════════════════════════════════════════════════
