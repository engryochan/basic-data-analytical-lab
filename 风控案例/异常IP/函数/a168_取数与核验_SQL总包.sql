/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  a168 风控与客户分层评分体系 · 商业方案                                    ║
   ║  取数与核验 SQL 总包（一册两卷 · 合并定稿）                                 ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  作者：®γσ ξηg（Ryo Eng）· 世博量化® Scibrokes Trading®                    ║
   ║  平台：a168 真人厅 · 数据源 StarRocks ods_mariadb_2b · 前端 Superset SQL Lab║
   ║  配套报告：a168风控与客户分层评分体系_商业方案_v3.qmd                       ║
   ║  本文件由「a168_核验与取数_SQL包.sql」与「a168_取数SQL包_v3增补.sql」        ║
   ║  合并而成，取代该二者；此后维护只认本文件一份。                             ║
   ╚═══════════════════════════════════════════════════════════════════════════╝

   ═══ 分析窗口（正名版，务必按此措辞对外）═══════════════════════════════════
     2026-03-21 ~ 2026-08-06 收盘，共 139 个完整营业日。
     SQL 谓词一律写作：dt >= '2026-03-21' AND dt < '2026-08-07'
     右端点为**开区间**——2026-08-07 当日不在窗口内。
     旧头部曾写「~ 2026-08-07」，字面易被读成含当日，已正名。
     改窗时须同时改动全包 53 处字面量，不得只改其一。

   ═══ 使用纪律（实测教训固化，逐条有血泪）═══════════════════════════════════
     ① 每条查询自包含、零占位符 —— 整段复制直接运行；
     ② StarRocks 方言：禁 LATERAL VIEW EXPLODE（改 UNNEST）、
        禁 EXISTS + 多列 IN（改五路 LEFT JOIN + COALESCE IS NULL）；
     ③ 逐条提交，禁批量 —— 批量会产生僵尸查询，拖垮集群；
     ④ 导出必带 ORDER BY —— 分页无稳定排序曾致 36.49% 重复行；
     ⑤ 导出上限 1,000 行时只承认排序头部结论，「未出现」类判断一律无效；
     ⑥ 超过 10 万行者先跑 COUNT 预检，按会员号区间切分，**不要用 OFFSET 翻页**；
     ⑦ 导出编码选 CSV(UTF-8)，全部存入报告同级「数据库/」目录，
        文件名一字不可错 —— 错名不报错，只让图表静默空白，是最坑的失败方式。

   ═══ 注释书写铁律（本合并本已全数整改）═══════════════════════════════════
     块注释内**禁止出现连续星号紧邻斜杠**，亦禁止出现单个星号紧邻斜杠。
     两类已实证的踩雷：
       · 「(星号星号)数据库/xxx.csv(星号星号)」—— 卷一原有 24 处，已改为「数据库/xxx.csv」；
       · 「δ(星号)/γ(星号)」—— 卷二 §E02c 原有 1 处，注释在此提前终止，
         其后整段被当成 SQL 解析，与当初 E1-11 报 Unexpected input
         'R_rebate_dist' 属同一类失效。已改为「δ* 与 γ*」。
     今后新增注释一律遵此，希腊字母带星号的数学记号须用「与」「和」分隔。

   ═══ 已被取代的两条（正文保留供追溯，⛔ 请勿运行）═══════════════════════════
     ⛔ 卷一 C-06  → 改跑 卷二 §C06fix   （LIKE 判别失效，且争抢同一导出文件名）
     ⛔ 卷一 S-04a → 改跑 卷二 §S04p     （IP 明细 vs 实体级聚合，争抢同一文件名）
     两组各自同写一个 CSV，后跑者覆盖先跑者 —— 误跑将使对打对名单清空、
     风控员雷达退化为结构演示。各条正文上方已加醒目告示。

   ═══ 字段正名速查（以本包 SQL 实际用法为准）═══════════════════════════════
     bet03 靴号        bet04 局内第几把    bet05 会员号     bet08 下注时间
     bet09 玩法（英文玩法名：Banker / Player / Tie / BankerDragonBonus …）
     bet11 汇率（币种归一化除数：stake = bet13 / bet11）  ← 非赔率，词典须核正
     bet13 下注金额    bet14 派彩金额      bet15 会员退水%  bet16 退水
     bet17 净输赢      bet18~22 五级代理线  bet38 测试标识   bet39 桌号
     bet41 有效投注    eid 荷官工号
     bet23~27 LV1~5 占成   bet28~32 LV1~5 退水（量纲待 §E02c-0 探针判定）
     gi001~gi013 局信息（gi004 局开始 · gi006 开牌 · gi011 桌号）
     产品 = 供玩家投注的游戏种类（百家乐、龙虎等，见 §DX-05 产品全景）
     玩法 = 该产品下的投注方式（bet09 的 23 种取值，见 §DX-04）
     二者不可混用。

   ═══ 执行总索引 ═══════════════════════════════════════════════════════════
   【第〇批 · 时区与营业日守卫】新增，导任何日粒度表之前必跑，只看屏幕
     §TZ-01 会话与全局时区          §TZ-02 库时钟 vs UTC 偏移
     §TZ-03 注单表实际覆盖端点      §TZ-04 末三日逐小时量（截断检测）
     §TZ-04b 全窗逐小时分布（反推落库时区 —— 决定「日」的切点）
     §TZ-05 日结报表切日点核对

   【第一批 · 地基体检】卷一，只看屏幕，不导出
     00-0 通用取列工具    00-1 哨兵局断言（预期 0）    00-2 注单去重率（0.74%）
     00-3 铁律分母：窗口内下注会员数（721,190）        00-4 桌台数核对
     E1-03 三方 IP 重合度   E1-08 测试线规模（214）    V2 game_No 位数核验
     卷二 §00 COUNT 预检    §00b 辅助表列名核对        §00c 表行数复核
     §DX-01 bet09 玩法编码普查（★ 跑任何含对打的查询前必做）
     §DX-02 注释提前终止的成因存档                     §DX-03 通用取列定义

   【第二批 · 评分底料（必导，不导则雷达与回测全空）】
     S-01 → 数据库/S01_player_score.csv          玩家评分
     S-02 → 数据库/S02_dealer_score.csv          荷官评分
     S-03 → 数据库/S03_agent_score.csv           代理评分
     §S04p → 数据库/S04_analyst_score.csv        风控员评分（⛔ 勿用 S-04a）
     S-05 → 数据库/S05_member_month_panel.csv    净化滚动回测面板
     §B01 → 数据库/B01_bt_panel.csv              会员×日回测面板

   【第三批 · 异常 IP 与对打主线】
     A-01 → 数据库/A_anchor.csv                  L0 金标准 17 IP 锚点
     C-00 → 数据库/I_ip_player.csv               会员×IP 明细
     C-01 → 数据库/C01_ip_chain.csv              信用枢纽排序
     C-02 → 数据库/I_ip_agg.csv                  IP 汇总三版本口径
     §C06fix → 数据库/C06_hedge_pairs.csv        对打对名单（⛔ 勿用 C-06）
     C-08 → 数据库/C08_subnet_all.csv            /24 网段全量
     N1   → 数据库/C08_subnet_sparse.csv         稀疏段靶向
     V-01 → 数据库/V_ipmatch.csv                 三方 IP 明细对照

   【第四批 · 规则、经济学与特征】
     §R01 → 数据库/R01_late_shoe.csv             靴末段下注
     §R02 → 数据库/R02_same_table.csv            同桌对 Jaccard / Lift
     §R03 → 数据库/R03_player_dealer.csv         玩家×荷官（全窗聚合）
     §R03b → 数据库/R03b_player_dealer_daily.csv 玩家×荷官（日粒度，时序对照必需）
     §T02 → 数据库/T02_daily_roi.csv             会员×日 ROI
     §T03 → 数据库/T03_arbitrage.csv             打水型画像
     §E02c → 数据库/E02_segment_econ.csv         分群单位经济学（含占成 κ）
     §K01 → 数据库/K01_risk_feature_matrix.csv   扩样特征矩阵
     §K01b → 数据库/K01b_seed_manual.csv         种子名单
     §DX-04 → 数据库/DX04_bet09_profile.csv      玩法 × 会员子分类底料
     §DX-05 → 数据库/DX05_product_panorama.csv   产品全景覆盖度

   【第五批 · 存档与画像】
     A-06M → 数据库/V_recon.csv        D-05 → 数据库/S_second_dist.csv
     D-06  → 数据库/S_player_tail.csv  D-03S → 数据库/D03S_daily_roi_diff.csv
     E1-07 → 数据库/T_table_span.csv   E1-10 → 数据库/L_label_dist.csv
     E1-11 → 数据库/R_rebate_dist.csv  X-01  → 数据库/X_combo.csv
     P-01  → 数据库/P_player_month.csv B-01  → 数据库/B_online_base.csv

   【第六批 · 时间一致性与切分工具】
     §TG-01 注册时间穿越检测   §TG-03 关注 IP 登记时间越界   §TG-05 事实表越界自检
     §99 大表切分导出模板      COUNT-01/02/08a/08b/09 计数与分批
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §TZ · 时区与营业日守卫（第〇批 · 新增）
   ---------------------------------------------------------------------------
   为什么必须先跑：本方案所有「日」粒度口径 —— 回测面板的 bet_date、
   走势图的 X 轴日期、会员出勤天数、日 ROI —— 都建立在「一天从几点算起」
   这个前提上。赌场的营业日常不以午夜切分（通宵客的注单会计入前一营业日），
   若误用自然日，跨日客户的行为会被人为劈成两天，评分与回测双双失真。
   本组六条只返回个位数到两位数行，**看屏幕即可，全部不必导出**。
   ═══════════════════════════════════════════════════════════════════════════ */

/* ── §TZ-01 · 会话与全局时区 ────────────────────────────────────────────────
   注意：不要用 SHOW VARIABLES —— Superset 会给查询自动追加 LIMIT，
   而 SHOW 语句不接受 LIMIT，会报「Unexpected input 'LIMIT'」。改用下式。 */
SELECT @@time_zone AS session_tz, @@global.time_zone AS global_tz;

/* ── §TZ-02 · 库时钟 vs UTC，实测偏移（分钟）──────────────────────────────
   判读：offset_min = 0 → 会话时区为 UTC；= 480 → UTC+8。
   实测（2026-08-07）：offset_min = 0，库时钟即 UTC。 */
SELECT NOW() AS db_now, UTC_TIMESTAMP() AS utc_now,
       TIMESTAMPDIFF(MINUTE, UTC_TIMESTAMP(), NOW()) AS offset_min;

/* ── §TZ-03 · 注单表实际覆盖端点 ─────────────────────────────────────────
   bet08 为下注时间，库中以字符串存放，须 CAST 后比较。 */
SELECT MIN(dt) AS dt_min, MAX(dt) AS dt_max,
       MIN(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS t_bet_min,
       MAX(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS t_bet_max,
       COUNT(*) AS n_rows
FROM ods_mariadb_2b.ods_a168_bet02
WHERE bet02 = '101';

/* ── §TZ-04 · 末三日逐小时注单量（截断检测）───────────────────────────────
   判读：完整营业日应有 24 个小时槽且呈稳定日内曲线。
   若末日只出现前若干小时或尾部量级断崖，即为截断日，须排除出窗口。
   本包窗口右端点已为开区间 < '2026-08-07'，08-07 本就不在窗内；
   本条用于换窗时复核新右端点。 */
SELECT DATE(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS d,
       HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS h,
       COUNT(*) AS n_orders
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-08-04' AND dt < '2026-08-07' AND bet02 = '101'
GROUP BY DATE(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)),
         HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME))
ORDER BY d, h;

/* ── §TZ-04b · 全窗逐小时分布（反推落库时区）★ 关键一条 ─────────────────
   会话时区为 UTC，不等于「数据以 UTC 落库」。用业务节律反推：
   真人厅高峰通常在当地 21:00~01:00。
     · 若峰值落在 UTC 13:00~17:00 → 对应 UTC+8 的 21:00~01:00
       → 落库为 UTC+8 墙钟，报告的「日」应按 UTC+8 自然日理解；
     · 若峰值落在 UTC 21:00~01:00 → 落库确为 UTC。
   结论须写入报告的数据说明章（属业务口径，非日志）。 */
SELECT HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS h_of_day,
       COUNT(*) AS n_orders,
       COUNT(DISTINCT bet05) AS n_member,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
GROUP BY HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME))
ORDER BY h_of_day;

/* ── §TZ-05 · 日结报表切日点核对 ─────────────────────────────────────────
   原 T-05 用 report_date 报「Column cannot be resolved」——
   辅助表不用通用列名，日期列为分区列 dt（与 §00b 记录的教训同源）。
   判读：本条的日行数分布若与 §TZ-04 的自然日分布对不上，
   即说明日结按营业日切分，全案「日」粒度须统一改用营业日。 */
SELECT dt AS 日期, COUNT(*) AS 行数, COUNT(DISTINCT bet05) AS 会员数
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-08-01' AND dt < '2026-08-07'
GROUP BY dt
ORDER BY dt;


/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  卷一 · 核验与全局底料                                                     ║
   ║  原「a168_核验与取数_SQL包.sql」全量正典（2026-08-06 定稿）收编            ║
   ║  SQL 逻辑一字未改；仅整改注释隐患 24 处，并为 C-06 / S-04a 加取代告示。     ║
   ╚═══════════════════════════════════════════════════════════════════════════╝ */

/* ═══════════════════════════════════════════════════════════════════════
   00-0 · 通用取列工具（遇到 "Column X cannot be resolved" 先跑这条）
   ▸ 导出：不需要 —— 屏幕看结果即可
   ▸ 用途：只读元数据，秒级返回，不扫任何数据行
   ▸ 用法：把表名换成报错的那张表即可；可一次查多张（IN 列表）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT TABLE_NAME AS 表名, ORDINAL_POSITION AS 序号, COLUMN_NAME AS 字段名,
       DATA_TYPE AS 类型, COLUMN_COMMENT AS 中文注释
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME IN ('ods_a168_alert_ip_setting','ods_a168_member_dtl',
                     'ods_a168_white_list','ods_a168_employee')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
/* 说明：ODS 层字段名多为 mem003/age022 这类代号，中文注释栏是唯一线索。
   本 SQL 包中标 ⚠️ 的表，其列名均来自局部样本判读，正式使用前应先跑本条确认。 */

/* ═══════════════════════════════════════════════════════════════════════
   00-1 · 哨兵局断言（预期 0；非 0 须重评口径）
   E1 已证为 0，此为字面量复核版
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(*) AS n_sentinel FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101' AND bet03='0';


/* ═══════════════════════════════════════════════════════════════════════
   00-2 · 注单去重率（E1 实测 0.74%）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(*) AS n_raw, COUNT(DISTINCT bet01) AS n_dedup,
       1 - COUNT(DISTINCT bet01)*1.0/COUNT(*) AS dup_rate
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101';


/* ═══════════════════════════════════════════════════════════════════════
   00-3 · 铁律⑤分母：窗口内百家乐有效下注会员数（E1 实测 721,190）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
)
SELECT COUNT(DISTINCT member_id) AS n_member_denominator FROM bs;


/* ═══════════════════════════════════════════════════════════════════════
   00-4 · N2 · 桌台数核对（本批 30 vs V2 报告 31 的闭合）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(DISTINCT bet39) AS n_tables FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101';


/* ═══════════════════════════════════════════════════════════════════════
   E1-03 · 三方 IP 重合度（裁定：game_log.ip 为网关，禁作下注 IP）
   E1 实测：1.32M vs 1,668，重合仅 2
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
WITH a AS (SELECT DISTINCT ip FROM ods_mariadb_2b.ods_a168_bet02
           WHERE dt>='2026-03-21' AND dt<'2026-08-07' AND bet02='101'
             AND NULLIF(TRIM(ip),'') IS NOT NULL),
     b AS (SELECT DISTINCT ip FROM ods_mariadb_2b.ods_a168_game_log
           WHERE dt>='2026-03-21' AND dt<'2026-08-07'
             AND NULLIF(TRIM(ip),'') IS NOT NULL)
SELECT (SELECT COUNT(*) FROM a) AS n_bet_ip,
       (SELECT COUNT(*) FROM b) AS n_log_ip,
       (SELECT COUNT(*) FROM a JOIN b ON a.ip=b.ip) AS n_overlap;


/* ═══════════════════════════════════════════════════════════════════════
   E1-07 · 局时长按桌分位（尾注阈值分层依据；桌内SD≈5s、桌间SD=18.2s）
   
   ▸ 导出：「数据库/T_table_span.csv」
   ▸ 用途：报告 fetch("T_table_span")：桌台局时长分层
   ═══════════════════════════════════════════════════════════════════════ */
SELECT gi011 AS table_id, COUNT(*) AS n_rounds,
       AVG(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004))  AS mean_sec,
       PERCENTILE_APPROX(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004),0.5) AS p50,
       PERCENTILE_APPROX(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004),0.9) AS p90,
       PERCENTILE_APPROX(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004),0.99) AS p99
FROM ods_mariadb_2b.ods_a168_game_info
WHERE gi001='101' AND gi013='1' AND is_lock='N'
  AND gi004>='2026-03-21' AND gi004<'2026-08-07'
GROUP BY gi011 ORDER BY n_rounds DESC;


/* ═══════════════════════════════════════════════════════════════════════
   E1-08 · 测试线规模（E1 实测 214 代理，跨五级）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(*) AS n_test_agents FROM ods_mariadb_2b.ods_a168_agent WHERE age022='1';


/* ═══════════════════════════════════════════════════════════════════════
   E1-10 · 風險單/劃單全局分布（标签可用性）
   
   ▸ 导出：「数据库/L_label_dist.csv」
   ▸ 用途：風險單/劃單标签分布，标签可用性存档
   ═══════════════════════════════════════════════════════════════════════ */
SELECT risk, orders, COUNT(*) AS n_rows,
       COUNT(DISTINCT bet05) AS n_member,
       MIN(dt) AS first_dt, MAX(dt) AS last_dt
FROM ods_mariadb_2b.ods_a168_dailyreport_member
GROUP BY risk, orders ORDER BY n_rows DESC;


/* ═══════════════════════════════════════════════════════════════════════
   E1-11 · 会员退水配置分布（0.3/0.8/0.9% 档人群——洗码经济学输入）
   
   ▸ 导出：「数据库/R_rebate_dist.csv」
   ▸ 用途：退水档位人群分布，洗码经济学输入
   ═══════════════════════════════════════════════════════════════════════ */
/* ⚠️ mem003 列名源自 E2 局部样本判读，未经 E1 实测确认。
   若报 Column cannot be resolved，先跑下面这条取列定义： */
-- SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
-- FROM information_schema.columns
-- WHERE TABLE_SCHEMA='ods_mariadb_2b' AND TABLE_NAME='ods_a168_member_dtl'
-- ORDER BY ORDINAL_POSITION;

SELECT mem003 AS rebate_rate, COUNT(*) AS n_member,
       COUNT(*)*1.0/SUM(COUNT(*)) OVER() AS pct
FROM ods_mariadb_2b.ods_a168_member_dtl
GROUP BY mem003 ORDER BY n_member DESC;


/* ═══════════════════════════════════════════════════════════════════════
   A-06M · 局级对账 · MASE 评估（实测跑通原文收编）
   MASE<<1 → 去重与口径正确；已确认 gi005 为归一化口径
   ▸ 导出：「数据库/V_recon.csv」
   ▸ 用途：报告 fetch("V_recon")：局级对账 MASE
   ═══════════════════════════════════════════════════════════════════════ */
/* --- A-06M 局级对账 · MASE 评估（已确认 gi005 为归一化口径）---------
   MASE = MAE / scale，scale = 同桌相邻局 gi_turnover 的平均绝对差分
   （Hyndman & Koehler 2006 的 naive one-step 基准）
   MASE << 1 → 对账误差远小于「用上一局预测本局」的朴素基准 → 口径一致
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet16, b.bet17,
         b.bet38, b.bet39, b.category,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
br AS (
  SELECT r.bet03 AS sh, r.bet04 AS rd, r.bet39 AS tb,
    SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS turnover,
    SUM(CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS rebate,
    SUM(CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS net_pnl
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
  GROUP BY r.bet03, r.bet04, r.bet39
),
gi AS (
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME)     AS t_open,
         CAST(NULLIF(TRIM(gi005),'') AS DECIMAL(20,4)) AS gi_turnover,
         CAST(NULLIF(TRIM(gi009),'') AS DECIMAL(20,4)) AS gi_rebate,
         CAST(NULLIF(TRIM(gi010),'') AS DECIMAL(20,4)) AS gi_net
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'
    AND gi013 = '1' AND is_lock = 'N'
),
j AS (
  SELECT g.tb, g.t_open,
         ABS(b.turnover - g.gi_turnover) AS ae_turnover,
         ABS(b.rebate   - g.gi_rebate)   AS ae_rebate,
         ABS(b.net_pnl  - g.gi_net)      AS ae_net,
         g.gi_turnover, g.gi_rebate, g.gi_net,
         LAG(g.gi_turnover) OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_turnover,
         LAG(g.gi_rebate)   OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_rebate,
         LAG(g.gi_net)      OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_net
  FROM br b
  JOIN gi g ON b.sh = g.sh AND b.rd = g.rd AND b.tb = g.tb
)
SELECT
  COUNT(*)                                            AS n_matched_round,
  AVG(ae_turnover)                                    AS mae_turnover,
  AVG(ae_rebate)                                      AS mae_rebate,
  AVG(ae_net)                                         AS mae_net,
  AVG(ABS(gi_turnover - lag_turnover))                AS scale_turnover,
  AVG(ABS(gi_rebate   - lag_rebate))                  AS scale_rebate,
  AVG(ABS(gi_net      - lag_net))                     AS scale_net,
  AVG(ae_turnover) / NULLIF(AVG(ABS(gi_turnover - lag_turnover)), 0) AS mase_turnover,
  AVG(ae_rebate)   / NULLIF(AVG(ABS(gi_rebate   - lag_rebate)),   0) AS mase_rebate,
  AVG(ae_net)      / NULLIF(AVG(ABS(gi_net      - lag_net)),      0) AS mase_net,
  SUM(CASE WHEN ae_turnover <= 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_exact_turnover,
  SUM(CASE WHEN ae_net      <= 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_exact_net
FROM j
WHERE lag_turnover IS NOT NULL;
/* 判读：
     mase_* < 0.05  → 对账误差不足朴素基准的 5%，口径完全一致
     mase_* ≈ 1     → 误差与局间自然波动同量级，口径存疑
     pct_exact_*    → 完全一致（容差 0.01）的局占比，直观补充指标         */


/* ═══════════════════════════════════════════════════════════════════════
   C-00 · 会员×IP 明细（评分与 §4.1 六项指标的底料）
   最小订单 30（Wilson 准则）控制导出量
   ▸ 导出：「数据库/I_ip_player.csv」
   ▸ 用途：报告 fetch("I_ip_player")：会员×IP 明细（§4.1 六项）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
pl AS (SELECT member_id, COUNT(*) AS n_orders_all,
              COUNT(DISTINCT round_key) AS n_rounds_all,
              SUM(net_pnl) AS net_pnl_all, SUM(game_pnl) AS game_pnl_all
       FROM bs GROUP BY member_id)
SELECT b.bet_ip, b.member_id, MAX(b.lv3) AS lv3,
  COUNT(*) AS n_orders_ip, COUNT(DISTINCT b.round_key) AS n_rounds_ip,
  SUM(b.stake) AS stake_ip, SUM(b.game_pnl) AS game_pnl_ip,
  SUM(b.rebate) AS rebate_ip, SUM(b.net_pnl) AS net_pnl_ip,
  MAX(pl.n_orders_all) AS n_orders_all, MAX(pl.n_rounds_all) AS n_rounds_all,
  MAX(pl.net_pnl_all) AS net_pnl_all, MAX(pl.game_pnl_all) AS game_pnl_all,
  COUNT(*)*1.0/NULLIF(MAX(pl.n_orders_all),0) AS ip_order_share
FROM bs b JOIN pl ON pl.member_id=b.member_id
WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL
GROUP BY b.bet_ip, b.member_id
HAVING COUNT(*) >= 30
ORDER BY n_orders_ip DESC;


/* ═══════════════════════════════════════════════════════════════════════
   C-01 · 信用枢纽排序 · member_per_chain（AX-A5 量化，实测榜首 2,132 人单链）
   
   ▸ 导出：「数据库/C01_ip_chain.csv」
   ▸ 用途：信用枢纽排序，玩家/代理评分的 IP 结构罚项来源
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
)
SELECT bet_ip,
       COUNT(DISTINCT member_id) AS n_member,
       COUNT(DISTINCT lv3)       AS n_lv3_chain,
       COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv3),0) AS member_per_chain,
       COUNT(*) AS n_orders, SUM(stake) AS stake,
       SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl
FROM bs
WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
GROUP BY bet_ip
HAVING COUNT(DISTINCT member_id) >= 20
ORDER BY member_per_chain DESC;


/* ╔══════════════════════════════════════════════════════════════════════╗
   ║  ⛔ 本条已被取代 —— 请勿运行，请改跑 卷二 §C06fix                      ║
   ╠══════════════════════════════════════════════════════════════════════╣
   ║  取代原因：本条以 LIKE 判别庄闲，而 DX-01 全量普查证实 bet09 存的是    ║
   ║  英文玩法名（Banker / Player / Tie …），判别清单里的 ('1','B','庄')    ║
   ║  一个都对不上，故实测零命中；且 LIKE 会误纳 BankerDragonBonus 等边注。 ║
   ║  两条同写 「数据库/C06_hedge_pairs.csv」，后跑者覆盖先跑者——           ║
   ║  若误跑本条，对打对名单将被清空，荷官与代理的罚项维度随之全空。        ║
   ║  正文保留仅供追溯口径演进，不作运行用途。                              ║
   ╚══════════════════════════════════════════════════════════════════════╝ */

/* ═══════════════════════════════════════════════════════════════════════
   C-06 · 同IP对打对 · 对冲覆盖（实测 999 对完美对打、最长 1,185 把）
   本金匹配容差 10%；玩法编码若与库内不符，改 bet_side 判别清单即可
   ▸ 导出：「数据库/C06_hedge_pairs.csv」
   ▸ 用途：对打对名单，IP-S6/IP-S8 与荷官/代理罚项来源
   ═══════════════════════════════════════════════════════════════════════ */
-- C-06 校准版 · 由您 2026-08-07 上传的原文自动改写而成
-- 唯一改动：side CTE 的玩法判别（庄 2 处、闲 2 处）
--   bet_side IN ('1','B','庄','莊')  ->  TRIM(bet_side) = 'Banker'
--   bet_side IN ('2','P','闲','閒')  ->  TRIM(bet_side) = 'Player'
-- 依据：DX-01 全量普查，bet09 存英文玩法名 Banker 4682万 / Player 4422万
-- 其余一字未动。头部块注释已删除（避免 §DX-02 的注释塌缩问题）

WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
side AS (   -- 每人每把在该IP的净方向（庄=+ 闲=−，按本金）
  SELECT bet_ip, round_key, member_id,
         SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                  WHEN TRIM(bet_side) = 'Player' THEN -stake
                  ELSE 0 END) AS dir_stake
  FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY bet_ip, round_key, member_id
  HAVING ABS(SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                      WHEN TRIM(bet_side) = 'Player' THEN -stake
                      ELSE 0 END)) > 0
),
pairs AS (
  SELECT a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         COUNT(*) AS n_same_round,
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN 1 ELSE 0 END) AS n_opposite_round,
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0
                   AND ABS(ABS(a.dir_stake)-ABS(b.dir_stake))
                       <= 0.1*GREATEST(ABS(a.dir_stake),ABS(b.dir_stake))
                  THEN 1 ELSE 0 END) AS n_hedged
  FROM side a JOIN side b
    ON a.bet_ip=b.bet_ip AND a.round_key=b.round_key
   AND a.member_id < b.member_id
  GROUP BY a.bet_ip, a.member_id, b.member_id
  HAVING COUNT(*) >= 30
)
SELECT bet_ip, m_a, m_b, n_same_round, n_opposite_round,
       n_opposite_round*1.0/n_same_round AS opposite_rate,
       n_hedged*1.0/NULLIF(n_opposite_round,0) AS hedge_coverage
FROM pairs
ORDER BY opposite_rate DESC, n_opposite_round DESC;

/* ═══════════════════════════════════════════════════════════════════════
   C-08 · /24 网段聚集 · 原版（按会员数降序；实测榜首为 CGNAT 饱和段）
   
   ▸ 导出：「数据库/C08_subnet_all.csv」
   ▸ 用途：/24 网段全量（含 CGNAT），白名单候选甄别
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
)
SELECT
  CONCAT(SPLIT_PART(bet_ip,'.',1),'.',SPLIT_PART(bet_ip,'.',2),'.',
         SPLIT_PART(bet_ip,'.',3),'.0/24') AS subnet_24,
  COUNT(DISTINCT bet_ip)    AS n_ip,
  COUNT(DISTINCT member_id) AS n_member,
  COUNT(DISTINCT lv3)       AS n_lv3_chain,
  COUNT(*) AS n_orders, SUM(stake) AS stake,
  SUM(game_pnl) AS game_pnl, SUM(valid_bet) AS valid_bet
FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT member_id) >= 5
ORDER BY n_member DESC;


/* ═══════════════════════════════════════════════════════════════════════
   N1 · /24 网段 · 稀疏段靶向版（CGNAT 条件化：n_ip ≤ 30）
   信用枢纽层完整摊开：少门牌、多人头、单链密
   ▸ 导出：「数据库/C08_subnet_sparse.csv」
   ▸ 用途：稀疏段靶向榜，信用枢纽层
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
)
SELECT
  CONCAT(SPLIT_PART(bet_ip,'.',1),'.',SPLIT_PART(bet_ip,'.',2),'.',
         SPLIT_PART(bet_ip,'.',3),'.0/24') AS subnet_24,
  COUNT(DISTINCT bet_ip)    AS n_ip,
  COUNT(DISTINCT member_id) AS n_member,
  COUNT(DISTINCT lv3)       AS n_lv3_chain,
  COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT bet_ip),0) AS member_per_ip,
  COUNT(*) AS n_orders, SUM(valid_bet) AS valid_bet, SUM(game_pnl) AS game_pnl
FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT member_id) >= 5 AND COUNT(DISTINCT bet_ip) <= 30
ORDER BY n_member DESC;


/* ═══════════════════════════════════════════════════════════════════════
   N1b · 金标准活跃探针（2022 年标注 IP 在 2026 窗口是否仍活跃）
   返回 0 行 = 金标准段窗口内无活动 → 一票否决条款改按 17 个单 IP 复验
   ▸ 导出：不需要 —— 屏幕看结果即可（0 行即结论）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT CONCAT(SPLIT_PART(ip,'.',1),'.',SPLIT_PART(ip,'.',2),'.',
       SPLIT_PART(ip,'.',3),'.0/24') AS subnet_24,
       COUNT(DISTINCT ip) AS n_ip, COUNT(DISTINCT bet05) AS n_member,
       COUNT(*) AS n_orders
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101'
  AND (ip LIKE '111.247.37.%' OR ip LIKE '103.123.134.%')
GROUP BY 1;


/* ═══════════════════════════════════════════════════════════════════════
   D-05 · 桌台进度统计（30 桌分位；封盘代理口径证据）
   
   ▸ 导出：「数据库/S_second_dist.csv」
   ▸ 用途：报告 fetch("S_second_dist")：桌台进度分位
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
gi AS (SELECT gi011 AS table_id,
              CONCAT_WS('|', gi002, gi003, gi011) AS round_key,
              gi004 AS t_open, gi006 AS t_reveal
       FROM ods_mariadb_2b.ods_a168_game_info
       WHERE gi001='101' AND gi013='1' AND is_lock='N'
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),
pr AS (SELECT b.table_id, b.round_key,
              (UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))*1.0
              /NULLIF(UNIX_TIMESTAMP(g.t_reveal)-UNIX_TIMESTAMP(g.t_open),0) AS progress
       FROM bs b JOIN gi g ON g.round_key=b.round_key)
SELECT table_id, COUNT(*) AS n_orders,
       PERCENTILE_APPROX(progress,0.5)  AS p50,
       PERCENTILE_APPROX(progress,0.75) AS p75,
       PERCENTILE_APPROX(progress,0.9)  AS p90,
       PERCENTILE_APPROX(progress,0.95) AS p95,
       PERCENTILE_APPROX(progress,0.99) AS p99,
       MAX(progress) AS max_progress
FROM pr WHERE progress BETWEEN 0 AND 1.5
GROUP BY table_id ORDER BY n_orders DESC;


/* ═══════════════════════════════════════════════════════════════════════
   D-03S · 日度尾段对照（139 行；五重检验的输入，裁定已闭合）
   
   ▸ 导出：「数据库/D03S_daily_roi_diff.csv」
   ▸ 用途：五重显著性检验输入（139 行）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
gi AS (SELECT CONCAT_WS('|', gi002, gi003, gi011) AS round_key,
              gi004 AS t_open, gi006 AS t_reveal
       FROM ods_mariadb_2b.ods_a168_game_info
       WHERE gi001='101' AND gi013='1' AND is_lock='N'
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),
pr AS (SELECT b.bet_date, b.round_key, b.valid_bet, b.game_pnl,
              (UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))*1.0
              /NULLIF(UNIX_TIMESTAMP(g.t_reveal)-UNIX_TIMESTAMP(g.t_open),0) AS progress
       FROM bs b JOIN gi g ON g.round_key=b.round_key)
SELECT bet_date, COUNT(DISTINCT round_key) AS n_rounds,
  SUM(CASE WHEN progress>=0.90 THEN valid_bet ELSE 0 END) AS vb_tail,
  SUM(CASE WHEN progress< 0.90 THEN valid_bet ELSE 0 END) AS vb_norm,
  SUM(CASE WHEN progress>=0.90 THEN game_pnl ELSE 0 END)
    /NULLIF(SUM(CASE WHEN progress>=0.90 THEN valid_bet ELSE 0 END),0) AS roi_tail,
  SUM(CASE WHEN progress< 0.90 THEN game_pnl ELSE 0 END)
    /NULLIF(SUM(CASE WHEN progress< 0.90 THEN valid_bet ELSE 0 END),0) AS roi_norm,
  SUM(CASE WHEN progress>=0.90 THEN game_pnl ELSE 0 END)
    /NULLIF(SUM(CASE WHEN progress>=0.90 THEN valid_bet ELSE 0 END),0)
  - SUM(CASE WHEN progress< 0.90 THEN game_pnl ELSE 0 END)
    /NULLIF(SUM(CASE WHEN progress< 0.90 THEN valid_bet ELSE 0 END),0) AS roi_diff
FROM pr WHERE progress BETWEEN 0 AND 1.5
GROUP BY bet_date ORDER BY bet_date;


/* ═══════════════════════════════════════════════════════════════════════
   D-06 · 玩家尾段十一项指标（实测跑通原文收编）
   个体层 winrate_diff>0 = 49.7% 白噪音，尾段裁定第三重复核
   ▸ 导出：「数据库/S_player_tail.csv」
   ▸ 用途：报告 fetch("S_player_tail")：玩家尾段十一项
   ═══════════════════════════════════════════════════════════════════════ */
/* --- D-06 玩家尾段十一项指标（SQL 端完成，加过滤控制在 10 万行内）----
   过滤：n_rounds_all >= 30（低于此样本量的玩家 Wilson CI 宽度 > 0.15，
         阈值无区分意义，见需求 §2.2-5）
   ------------------------------------------------------------------------- */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
ord AS (
  SELECT b.*, PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,
              COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round
  FROM bs b
),
prd AS (
  SELECT member_id, round_key, table_id,
         MAX(pr_in_round) AS max_pr,
         MAX(n_in_round)  AS n_in_round,
         SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
         CASE WHEN SUM(game_pnl) > 0 THEN 1 ELSE 0 END AS is_win,
         CASE WHEN SUM(game_pnl) < 0 THEN 1 ELSE 0 END AS is_lose
  FROM ord WHERE n_in_round >= 5
  GROUP BY member_id, round_key, table_id
),
fl AS (
  SELECT p.*, CASE WHEN p.max_pr >= 0.80 THEN 1 ELSE 0 END AS is_tail
  FROM prd p
)
SELECT member_id,
  COUNT(*)                      AS n_rounds_all,
  SUM(is_tail)                  AS n_rounds_tail,
  SUM(is_tail) * 1.0 / COUNT(*) AS tail_share,
  SUM(is_tail * is_win)  AS tail_win,
  SUM(is_tail * is_lose) AS tail_lose,
  SUM(is_tail * is_win) * 1.0
    / NULLIF(SUM(is_tail * is_win) + SUM(is_tail * is_lose), 0) AS tail_winrate,
  SUM((1 - is_tail) * is_win) * 1.0
    / NULLIF(SUM((1 - is_tail) * is_win) + SUM((1 - is_tail) * is_lose), 0) AS norm_winrate,
  SUM(is_tail * is_win) * 1.0
    / NULLIF(SUM(is_tail * is_win) + SUM(is_tail * is_lose), 0)
    - SUM((1 - is_tail) * is_win) * 1.0
    / NULLIF(SUM((1 - is_tail) * is_win) + SUM((1 - is_tail) * is_lose), 0) AS winrate_diff,
  SUM(is_tail * stake)     AS tail_stake,
  SUM(is_tail * valid_bet) AS tail_valid_bet,
  SUM(is_tail * game_pnl)  AS tail_game_pnl,
  SUM(is_tail * rebate)    AS tail_rebate,
  SUM(is_tail * net_pnl)   AS tail_net_pnl,
  SUM(is_tail * game_pnl) / NULLIF(SUM(is_tail * valid_bet), 0) AS tail_roi,
  SUM((1 - is_tail) * game_pnl) AS norm_game_pnl,
  SUM((1 - is_tail) * game_pnl)
    / NULLIF(SUM((1 - is_tail) * valid_bet), 0) AS norm_roi,
  SUM(CASE WHEN is_tail = 1 AND game_pnl > 0 THEN game_pnl ELSE 0 END)
    / NULLIF(SUM(CASE WHEN game_pnl > 0 THEN game_pnl ELSE 0 END), 0) AS tail_profit_share
FROM fl
GROUP BY member_id
HAVING COUNT(*) >= 30
ORDER BY member_id;


/* ═══════════════════════════════════════════════════════════════════════
   S-01 · 玩家评分底料（全局聚合；对打指数/注册邻近在 Python 侧并入 C-06）
   导出为 数据库/S01_player_score.csv
   ▸ 导出：「数据库/S01_player_score.csv」
   ▸ 用途：★ 玩家评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
lab AS (SELECT bet05 AS member_id,
               SUM(CASE WHEN risk='1' THEN 1 ELSE 0 END) AS n_risk_days,
               SUM(CASE WHEN orders='1' THEN 1 ELSE 0 END) AS n_order_days
        FROM ods_mariadb_2b.ods_a168_dailyreport_member GROUP BY bet05),
/* ── 扩编维度① 投注产品结构熵 ─────────────────────────────────────
   香农熵：把该会员的投注额按 23 种投注产品拆开，看分散还是集中。
   熵高 = 庄闲和边注都押一点，是娱乐型客人的常态；
   熵低 = 火力集中在少数高赔率边注，是技术型画像的特征之一。
   赏罚方向为「赏」——熵高的客人对平台更安全。 */
psplit AS (
  SELECT member_id, bet_side,
         SUM(stake) AS s_side,
         SUM(SUM(stake)) OVER (PARTITION BY member_id) AS s_all
  FROM bs GROUP BY member_id, bet_side
),
ent AS (
  SELECT member_id,
         -SUM((s_side/s_all) * LN(s_side/s_all)) AS 投注产品结构熵
  FROM psplit WHERE s_all > 0 AND s_side > 0
  GROUP BY member_id
),
/* ── 扩编维度② 索提诺稳定性（会员视角的下行风险调整收益）──────────
   先把注单压成「会员×日」的日 ROI，再算 日ROI均值 ÷ 下行标准差。
   只统计低于 0 那一侧的波动——赢钱时的波动不是风险。
   赏罚方向为「罚」：赢得稳的客人正是 T2 技术型风险用户，
   赢得多但忽输忽赢的反而是正常娱乐客。**不要把方向搞反。** */
dly AS (
  SELECT member_id, bet_date,
         SUM(game_pnl) AS pnl_d, SUM(stake) AS stake_d
  FROM bs GROUP BY member_id, bet_date
),
srt AS (
  SELECT member_id,
         AVG(pnl_d / NULLIF(stake_d,0))                                  AS mu_roi_d,
         SQRT(AVG(POW(LEAST(pnl_d / NULLIF(stake_d,0), 0), 2)))          AS dd_roi_d,
         AVG(pnl_d / NULLIF(stake_d,0))
           / NULLIF(SQRT(AVG(POW(LEAST(pnl_d / NULLIF(stake_d,0), 0), 2))), 0)
                                                                          AS 索提诺稳定性
  FROM dly GROUP BY member_id
),
/* ── 扩编维度③ 生命周期阶段 ──────────────────────────────────────
   首末注单跨度 × 近期活跃衰减，取值越大代表越处于成熟稳定期。
   算法：活跃跨度天数 × (1 − 距窗口右端的静默天数 / 窗口总天数)，
   新客跨度短、流失前兆者静默久，两端都会被压低。窗口 139 天为字面量。
   赏罚方向为「赏」。 */
lc AS (
  SELECT member_id,
         DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1 AS span_days,
         DATEDIFF(DATE '2026-08-06', MAX(bet_date)) AS silent_days,
         (DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1)
           * (1 - DATEDIFF(DATE '2026-08-06', MAX(bet_date)) / 139.0) AS 生命周期阶段
  FROM bs GROUP BY member_id
)
SELECT b.member_id,
  SUM(b.valid_bet) AS 流水贡献,
  -SUM(b.game_pnl) AS 游戏输赢贡献,          -- 会员输=平台赢，取负号
  COUNT(DISTINCT b.bet_date) AS 活跃稳定,
  SUM(b.rebate) AS 退水支出,
  COUNT(DISTINCT b.bet_ip) AS n_ip,
  COUNT(DISTINCT b.lv3) AS n_chain,
  COALESCE(MAX(l.n_risk_days),0)+COALESCE(MAX(l.n_order_days),0) AS 人工标记史,
  -- ★ 扩编三列：报告的玩家雷达按列名取用，列名一字不可改
  MAX(e.投注产品结构熵)  AS 投注产品结构熵,
  MAX(sr.索提诺稳定性)   AS 索提诺稳定性,
  MAX(lcx.生命周期阶段)  AS 生命周期阶段
FROM bs b
LEFT JOIN lab l   ON l.member_id  = b.member_id
LEFT JOIN ent e   ON e.member_id  = b.member_id
LEFT JOIN srt sr  ON sr.member_id = b.member_id
LEFT JOIN lc  lcx ON lcx.member_id = b.member_id
GROUP BY b.member_id
HAVING COUNT(DISTINCT b.round_key) >= 30
ORDER BY 流水贡献 DESC;


/* ═══════════════════════════════════════════════════════════════════════
   S-02 · 荷官评分底料
   对打局占比/異常对关联在 Python 侧并 C-06 名单；导出 数据库/S02_dealer_score.csv
   ▸ 导出：「数据库/S02_dealer_score.csv」
   ▸ 用途：★ 荷官评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
/* ── 扩编维度① 当值时长 ─────────────────────────────────────────
   以「在册局数」为分层基准。不做这一层分层，裸排名的榜首永远是
   上班天数最少的新人——他们样本少、波动大，任何比率指标都会虚高。
   赏罚方向为「赏」。 */
/* ── 扩编维度② 节奏稳定度 ───────────────────────────────────────
   每局时长（开局 gi004 → 开牌 gi006）的离散度，取 1/(1+标准差秒数)。
   节奏忽快忽慢是操作异常的先兆，也会影响玩家体验。赏罚方向为「赏」。 */
gi AS (
  SELECT gi011 AS table_id, gi003 AS shoe_no,
         UNIX_TIMESTAMP(gi006) - UNIX_TIMESTAMP(gi004) AS sec_round
  FROM ods_mariadb_2b.ods_a168_game_info
  WHERE gi001 = '101' AND gi013 = '1'
    AND gi004 >= '2026-03-21' AND gi004 < '2026-08-07'
),
pace AS (
  SELECT b.dealer_id,
         1.0 / (1.0 + COALESCE(STDDEV_SAMP(g.sec_round), 0)) AS 节奏稳定度
  FROM bs b JOIN gi g ON g.table_id = b.table_id
  GROUP BY b.dealer_id
),
/* ── 扩编维度③ 特定玩家复现率 ───────────────────────────────────
   该荷官桌上「出现最频繁的那一位会员」占其总局数的比例。
   正常荷官服务的是流动客群，比例低；比例畸高说明有固定的人一直跟着他，
   这是玩家—荷官关联的第一道筛。赏罚方向为「罚」。 */
mrep AS (
  SELECT dealer_id, member_id, COUNT(DISTINCT round_key) AS n_r
  FROM bs GROUP BY dealer_id, member_id
),
top1 AS (
  SELECT dealer_id, MAX(n_r) AS max_member_rounds
  FROM mrep GROUP BY dealer_id
)
SELECT b.dealer_id,
  SUM(b.valid_bet) AS 在桌洗码量,
  COUNT(DISTINCT b.member_id) AS 客群广度,
  COUNT(DISTINCT b.round_key) AS n_rounds,
  COUNT(DISTINCT b.table_id) AS n_tables,
  SUM(b.game_pnl) AS 桌面输赢,
  -- ★ 扩编三列：报告的荷官雷达按列名取用，列名一字不可改
  COUNT(DISTINCT b.round_key) AS 当值时长,
  MAX(p.节奏稳定度) AS 节奏稳定度,
  MAX(t.max_member_rounds) * 1.0
    / NULLIF(COUNT(DISTINCT b.round_key), 0) AS 特定玩家复现率
FROM bs b
LEFT JOIN pace p ON p.dealer_id = b.dealer_id
LEFT JOIN top1 t ON t.dealer_id = b.dealer_id
WHERE NULLIF(TRIM(b.dealer_id),'') IS NOT NULL
GROUP BY b.dealer_id ORDER BY 在桌洗码量 DESC;


/* ═══════════════════════════════════════════════════════════════════════
   S-03 · 代理（LV3 链）评分底料
   对打渗透率在 Python 侧并 C-06；导出 数据库/S03_agent_score.csv
   ▸ 导出：「数据库/S03_agent_score.csv」
   ▸ 用途：★ 代理评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
/* ── 扩编维度① 下线留存 ─────────────────────────────────────────
   把 139 天窗口一切两半（前 70 天 / 后 69 天），算「两段都活跃的会员
   占前段活跃会员的比例」。留存高说明这条线在做真实经营；
   留存趋零而流水不低，多半是一批号刷完就换。赏罚方向为「赏」。 */
half AS (
  SELECT lv3, member_id,
         MAX(CASE WHEN bet_date <  '2026-05-30' THEN 1 ELSE 0 END) AS in_h1,
         MAX(CASE WHEN bet_date >= '2026-05-30' THEN 1 ELSE 0 END) AS in_h2
  FROM bs WHERE NULLIF(TRIM(lv3),'') IS NOT NULL
  GROUP BY lv3, member_id
),
ret AS (
  SELECT lv3,
         SUM(CASE WHEN in_h1 = 1 AND in_h2 = 1 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(in_h1), 0) AS 下线留存
  FROM half GROUP BY lv3
),
/* ── 扩编维度② 新增会员质量 ─────────────────────────────────────
   只看「窗口内才首次下注」的会员，算其人均净贡献（平台口径，取负号）。
   这一维把「拉人头」与「拉客人」区分开：新增数量高但人均净贡献接近零
   甚至为负，说明拉来的是刷返水的号，不是客人。赏罚方向为「赏」。 */
newm AS (
  SELECT lv3, member_id,
         MIN(bet_date) AS first_date,
         -SUM(net_pnl) AS 平台净得
  FROM bs WHERE NULLIF(TRIM(lv3),'') IS NOT NULL
  GROUP BY lv3, member_id
),
nq AS (
  SELECT lv3,
         AVG(平台净得) AS 新增会员质量,
         COUNT(*)      AS n_new_member
  FROM newm WHERE first_date >= '2026-04-20'   -- 窗口首 30 天之后才首注，视为新增
  GROUP BY lv3
)
SELECT b.lv3,
  COUNT(DISTINCT b.member_id) AS 线下规模,
  SUM(b.valid_bet) AS 真实流水,
  SUM(b.rebate)    AS 退水支出,
  SUM(b.game_pnl)  AS 链下游戏输赢,
  SUM(b.rebate)/NULLIF(-SUM(b.game_pnl),0) AS 退水消耗比,  -- >1 = 退水吃光赢利
  -- ★ 扩编两列：报告的代理雷达按列名取用，列名一字不可改
  MAX(r.下线留存)      AS 下线留存,
  MAX(n.新增会员质量)  AS 新增会员质量,
  MAX(n.n_new_member)  AS 新增会员数
FROM bs b
LEFT JOIN ret r ON r.lv3 = b.lv3
LEFT JOIN nq  n ON n.lv3 = b.lv3
WHERE NULLIF(TRIM(b.lv3),'') IS NOT NULL
GROUP BY b.lv3 ORDER BY 真实流水 DESC;


/* ╔══════════════════════════════════════════════════════════════════════╗
   ║  ⛔ S-04a 已被取代 —— 请勿导出，请改跑 卷二 §S04p                      ║
   ╠══════════════════════════════════════════════════════════════════════╣
   ║  取代原因：S-04a 输出的是 IP 明细（17 行，一行一个 IP），而风控员雷达  ║
   ║  需要的是「一行一位风控员」的实体级聚合。两条同写                      ║
   ║  「数据库/S04_analyst_score.csv」，后跑者覆盖先跑者——                  ║
   ║  若误跑本条，风控员雷达将拿不到实体级维度，退化为结构演示。            ║
   ║  S-04b（标注人产量汇总）仍可用，看屏幕即可，不必导出。                 ║
   ╚══════════════════════════════════════════════════════════════════════╝ */

/* ═══════════════════════════════════════════════════════════════════════
   S-04 · 风控员评分底料（金标准名单产出者）
   命中率/时效由 Python 侧对回 N1/N1b 结果计算；导出 数据库/S04_analyst_score.csv
   ▸ 导出：「数据库/S04_analyst_score.csv」
   ▸ 用途：★ 风控员评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
/* ✅ 字段已实测确认（2026-08-06 全表 17 行到手）：
     ip=IP地址  creator=标注人  addtime=标注时间  remarks=备注(判定理由)
   注意：全表仅 17 行，直接 SELECT * 导出即可，聚合反而丢失 IP 与备注原文。 */

/* ── S-04a · 全表导出（推荐，17 行一次到位）─────────────────────────
   ▸ 导出：「数据库/S04_analyst_score.csv」                              */
SELECT id, ip, creator AS 标注人, addtime AS 标注时间, remarks AS 判定理由,
       CONCAT(SPLIT_PART(ip,'.',1),'.',SPLIT_PART(ip,'.',2),'.',
              SPLIT_PART(ip,'.',3),'.0/24') AS subnet_24
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
ORDER BY addtime;

/* ── S-04b · 标注人产量汇总（可选，看一眼即可，无需导出）───────────
   实测结果：mao 6 / wmdn08 4 / Annie 3 / livegame 2 / wmdn10 1 / wmdn01 1 */
SELECT creator AS 标注人, COUNT(*) AS 标注产量,
       SUM(CASE WHEN NULLIF(TRIM(remarks),'') IS NULL THEN 1 ELSE 0 END) AS 理由空白数,
       MIN(addtime) AS 首次标注, MAX(addtime) AS 末次标注
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
GROUP BY creator ORDER BY 标注产量 DESC;


/* ═══════════════════════════════════════════════════════════════════════
   S-05 · 会员×月评分面板（净化滚动回测的输入）
   导出 数据库/S05_member_month_panel.csv；risk_label 即 L1a 標籤
   ▸ 导出：「数据库/S05_member_month_panel.csv」
   ▸ 用途：★★ 净化滚动回测面板（模型竞技场唯一输入）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
lab AS (SELECT bet05 AS member_id, DATE_TRUNC('month', dt) AS ym,
               MAX(CASE WHEN risk='1' THEN 1 ELSE 0 END) AS risk_label
        FROM ods_mariadb_2b.ods_a168_dailyreport_member
        GROUP BY bet05, DATE_TRUNC('month', dt))
SELECT b.member_id, DATE_TRUNC('month', b.bet_date) AS bet_date,
  SUM(b.valid_bet) AS 流水贡献, -SUM(b.game_pnl) AS 游戏输赢贡献,
  COUNT(DISTINCT b.bet_date) AS 活跃稳定, SUM(b.rebate) AS 退水支出,
  COUNT(DISTINCT b.bet_ip) AS n_ip, COUNT(DISTINCT b.lv3) AS n_chain,
  MIN(b.round_key) AS round_key,
  COALESCE(MAX(l.risk_label),0) AS risk_label
FROM bs b LEFT JOIN lab l
  ON l.member_id=b.member_id AND l.ym=DATE_TRUNC('month', b.bet_date)
GROUP BY b.member_id, DATE_TRUNC('month', b.bet_date)
HAVING COUNT(*) >= 30
ORDER BY b.member_id, bet_date;


/* ═══════════════════════════════════════════════════════════════════════
   V2 · game_No 位数核验 → ✅ 已跑（2026-08-06）
   实测 7/7/7/152,416 → 与 bet03(9位)不符，该表已关闭
   ▸ 导出：不需要 —— 已跑完，结论存档，无需重跑
   ═══════════════════════════════════════════════════════════════════════ */
SELECT MIN(LENGTH(gameNo)) AS min_len, MAX(LENGTH(gameNo)) AS max_len,
       COUNT(DISTINCT gid) AS n_gid, COUNT(*) AS n
FROM ods_mariadb_2b.ods_a168_game_No;

/* ═══════════════════════════════════════════════════════════════════════
   C-02 · IP 汇总 · 三版本盈利口径（版本C 剔退水为主口径）
   报告 fetch("I_ip_agg") 缺口补齐；最小订单 30
   ▸ 导出：「数据库/I_ip_agg.csv」
   ▸ 用途：§4.2 三版本对照与阈值网格
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
pl AS (SELECT member_id, COUNT(*) AS n_orders_all,
              SUM(net_pnl) AS net_pnl_all, SUM(game_pnl) AS game_pnl_all
       FROM bs GROUP BY member_id),
ipm AS (SELECT b.bet_ip, b.member_id, COUNT(*) AS n_orders_ip,
               COUNT(DISTINCT b.round_key) AS n_rounds_ip,
               SUM(b.stake) AS stake_ip, SUM(b.net_pnl) AS net_pnl_ip,
               SUM(b.game_pnl) AS game_pnl_ip,
               MAX(p.net_pnl_all) AS net_pnl_all, MAX(p.game_pnl_all) AS game_pnl_all,
               COUNT(*)*1.0/NULLIF(MAX(p.n_orders_all),0) AS ip_order_share
        FROM bs b JOIN pl p ON p.member_id=b.member_id
        WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL
        GROUP BY b.bet_ip, b.member_id)
SELECT 'W1' AS window_id, bet_ip,
  COUNT(*) AS n_member_raw,
  SUM(CASE WHEN n_orders_ip>=30 THEN 1 ELSE 0 END) AS n_member_eff,
  SUM(CASE WHEN n_orders_ip>=30 AND net_pnl_all>0 THEN 1 ELSE 0 END) AS n_prof_A,
  SUM(CASE WHEN n_orders_ip>=30 AND net_pnl_ip >0 THEN 1 ELSE 0 END) AS n_prof_B,
  SUM(CASE WHEN n_orders_ip>=30 AND game_pnl_ip>0 THEN 1 ELSE 0 END) AS n_prof_C,
  SUM(n_orders_ip) AS n_orders, SUM(n_rounds_ip) AS n_rounds,
  SUM(stake_ip) AS stake, SUM(net_pnl_ip) AS net_pnl, SUM(game_pnl_ip) AS game_pnl,
  PERCENTILE_APPROX(ip_order_share,0.5) AS share_p50,
  PERCENTILE_APPROX(ip_order_share,0.9) AS share_p90
FROM ipm GROUP BY bet_ip
HAVING SUM(CASE WHEN n_orders_ip>=30 THEN 1 ELSE 0 END) >= 5
ORDER BY n_member_eff DESC;

/* ═══════════════════════════════════════════════════════════════════════
   X-01 · 两规则组合矩阵（异常IP × 尾注；尾注侧仅作画像）
   报告 fetch("X_combo") 缺口补齐
   ▸ 导出：「数据库/X_combo.csv」
   ▸ 用途：§6 两规则重叠与增量分析
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
gi AS (SELECT CONCAT_WS('|', gi002, gi003, gi011) AS round_key,
              gi004 AS t_open, gi006 AS t_reveal
       FROM ods_mariadb_2b.ods_a168_game_info
       WHERE gi001='101' AND gi013='1' AND is_lock='N'
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),
pr AS (SELECT b.member_id, b.bet_ip, b.valid_bet, b.game_pnl,
              (UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))*1.0
              /NULLIF(UNIX_TIMESTAMP(g.t_reveal)-UNIX_TIMESTAMP(g.t_open),0) AS progress
       FROM bs b JOIN gi g ON g.round_key=b.round_key),
ipn AS (SELECT bet_ip, COUNT(DISTINCT member_id) AS n_member_ip
        FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL GROUP BY bet_ip),
mk AS (SELECT p.member_id,
         MAX(CASE WHEN i.n_member_ip >= 20 THEN 1 ELSE 0 END) AS flag_ip,
         SUM(CASE WHEN p.progress>=0.90 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS tail_share,
         SUM(p.valid_bet) AS valid_bet, SUM(p.game_pnl) AS game_pnl
       FROM pr p LEFT JOIN ipn i ON i.bet_ip=p.bet_ip
       WHERE p.progress BETWEEN 0 AND 1.5
       GROUP BY p.member_id HAVING COUNT(*) >= 30)
SELECT flag_ip,
       CASE WHEN tail_share>=0.47 THEN 1 ELSE 0 END AS flag_tail_p90,
       COUNT(*) AS n_member, SUM(valid_bet) AS valid_bet,
       SUM(game_pnl) AS game_pnl,
       SUM(game_pnl)/NULLIF(SUM(valid_bet),0) AS roi
FROM mk GROUP BY 1,2 ORDER BY 1 DESC,2 DESC;

/* ═══════════════════════════════════════════════════════════════════════
   P-01 · 会员×月面板（跨月持续性；与 S-05 同源不同粒度）
   报告 fetch("P_player_month") 缺口补齐
   ▸ 导出：「数据库/P_player_month.csv」
   ▸ 用途：@sec-persist 跨月稳定性检验
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
)
SELECT member_id, DATE_TRUNC('month', bet_date) AS ym,
  COUNT(DISTINCT round_key) AS n_rounds, COUNT(DISTINCT bet_date) AS n_days,
  SUM(valid_bet) AS valid_bet, SUM(game_pnl) AS game_pnl,
  SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
  SUM(game_pnl)/NULLIF(SUM(valid_bet),0) AS roi
FROM bs GROUP BY member_id, DATE_TRUNC('month', bet_date)
HAVING COUNT(DISTINCT round_key) >= 30
ORDER BY member_id, ym;

/* ═══════════════════════════════════════════════════════════════════════
   B-01 · 在线人数基准（「第29秒」悖论的分母）
   报告 fetch("B_online_base") 缺口补齐
   ▸ 导出：「数据库/B_online_base.csv」
   ▸ 用途：§2.2-4 秒段集中度须除以在场人数基准
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
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
gi AS (SELECT CONCAT_WS('|', gi002, gi003, gi011) AS round_key,
              gi004 AS t_open, gi006 AS t_reveal
       FROM ods_mariadb_2b.ods_a168_game_info
       WHERE gi001='101' AND gi013='1' AND is_lock='N'
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),
pr AS (SELECT b.table_id, b.round_key, b.member_id, b.valid_bet, b.game_pnl,
              FLOOR((UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))) AS sec_elapsed
       FROM bs b JOIN gi g ON g.round_key=b.round_key)
SELECT table_id, sec_elapsed,
       COUNT(*) AS n_orders, COUNT(DISTINCT member_id) AS n_player,
       COUNT(DISTINCT round_key) AS n_rounds,
       SUM(valid_bet) AS valid_bet, SUM(game_pnl) AS game_pnl
FROM pr WHERE sec_elapsed BETWEEN 0 AND 120
GROUP BY table_id, sec_elapsed ORDER BY table_id, sec_elapsed;

/* ═══════════════════════════════════════════════════════════════════════
   A-01 · L0 金标准锚点（17 个人工确认 IP 的窗口内表现）
   报告 fetch("A_anchor") 缺口补齐；须先跑 N1b 确认活跃性
   ▸ 导出：「数据库/A_anchor.csv」
   ▸ 用途：一票否决检验：新阈值必须命中这些锚点
   ═══════════════════════════════════════════════════════════════════════ */
WITH gold AS (SELECT DISTINCT TRIM(ip) AS ip
              FROM ods_mariadb_2b.ods_a168_alert_ip_setting
              WHERE NULLIF(TRIM(ip),'') IS NOT NULL)
SELECT g.ip,
       COUNT(b.bet01) AS n_orders,
       COUNT(DISTINCT b.bet05) AS n_member,
       MIN(b.dt) AS first_dt, MAX(b.dt) AS last_dt
FROM gold g
LEFT JOIN ods_mariadb_2b.ods_a168_bet02 b
  ON TRIM(b.ip)=g.ip AND b.dt>='2026-03-21' AND b.dt<'2026-08-07' AND b.bet02='101'
GROUP BY g.ip ORDER BY n_orders DESC;

/* ═══════════════════════════════════════════════════════════════════════
   V-01 · 三方 IP 明细对照（地理维度作废的存档证据）
   报告 fetch("V_ipmatch") 缺口补齐
   ▸ 导出：「数据库/V_ipmatch.csv」
   ▸ 用途：game_log.ip 为网关的逐条证据
   ═══════════════════════════════════════════════════════════════════════ */
WITH a AS (SELECT DISTINCT TRIM(ip) AS ip FROM ods_mariadb_2b.ods_a168_bet02
           WHERE dt>='2026-03-21' AND dt<'2026-08-07' AND bet02='101'
             AND NULLIF(TRIM(ip),'') IS NOT NULL),
     b AS (SELECT TRIM(ip) AS ip, COUNT(DISTINCT mid) AS n_member_log,
                  MAX(country_code) AS country, MAX(city) AS city
           FROM ods_mariadb_2b.ods_a168_game_log
           WHERE dt>='2026-03-21' AND dt<'2026-08-07'
             AND NULLIF(TRIM(ip),'') IS NOT NULL
           GROUP BY TRIM(ip))
SELECT b.ip, b.n_member_log, b.country, b.city,
       CASE WHEN a.ip IS NULL THEN 0 ELSE 1 END AS in_bet_ip
FROM b LEFT JOIN a ON a.ip=b.ip
ORDER BY b.n_member_log DESC;


/* ╔═══════════════════════════════════════════════════════════════════════╗
   ║  §08 · 分批下载工具组（先数行数，再决定要不要分批）                      ║
   ╚═══════════════════════════════════════════════════════════════════════╝
   为什么必须先数：Superset 单次导出有上限，超限会**静默截断**（只给你前
   N 行，不报错）。之前 277 批数据出现 36.49% 重复，根因就是分页时
   **没有稳定排序**——同一行被翻到两页里。本组工具解决这两件事。

   ★★ 分页铁律 ★★
   ① 排序键必须**唯一**。按「流水贡献」排序会有并列值，翻页时行会跳动、
      重复或漏掉。分批下载时**一律改用 member_id 排序**（唯一主键）。
   ② 优先用「游标翻页」（COUNT-08b）而非 OFFSET：
      OFFSET 100000 要求引擎先算完前 10 万行再丢掉，越翻越慢；
      游标翻页每次都走索引，第 1 批和第 50 批一样快。
   ③ 每批导出后核对行数，最后一批合并时用 member_id 去重复核。
*/

/* ═══════════════════════════════════════════════════════════════════════
   COUNT-01 · 五份评分底料的观测值总数（一次跑完，5 个数字全出）
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行 5 列）
   ▸ 用途：决定每份要不要分批、分几批
   ▸ 耗时：约 1–3 分钟（要扫全量注单）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet
  FROM vd v
),
lab AS (SELECT bet05 AS member_id FROM ods_mariadb_2b.ods_a168_dailyreport_member
        GROUP BY bet05)
SELECT
  /* S-01 玩家：满 30 局的会员数 */
  (SELECT COUNT(*) FROM (SELECT member_id FROM bs GROUP BY member_id
     HAVING COUNT(DISTINCT round_key) >= 30) x)                AS n_S01_玩家,
  /* S-02 荷官：有注单的荷官数 */
  (SELECT COUNT(DISTINCT dealer_id) FROM bs
     WHERE NULLIF(TRIM(dealer_id),'') IS NOT NULL)             AS n_S02_荷官,
  /* S-03 代理：有注单的 LV3 代理线数 */
  (SELECT COUNT(DISTINCT lv3) FROM bs
     WHERE NULLIF(TRIM(lv3),'') IS NOT NULL)                   AS n_S03_代理,
  /* S-05 面板：会员×月 组合数 */
  (SELECT COUNT(*) FROM (SELECT member_id, DATE_TRUNC('month', bet_date) ym
     FROM bs GROUP BY member_id, DATE_TRUNC('month', bet_date)
     HAVING COUNT(*) >= 30) y)                                 AS n_S05_会员月,
  /* 参考：窗口内下注会员总数（未过滤 30 局） */
  (SELECT COUNT(DISTINCT member_id) FROM bs)                   AS n_会员总数;

/* 判读：
     任何一个数 ≤ 100,000  → 该份直接一次导出，不必分批；
     100,000 < 数 ≤ 500,000 → 用 COUNT-08b 游标翻页，每批 10 万；
     > 500,000              → 先考虑收紧 HAVING 门槛（如 >=50 局），
                              样本量够用即可，不必全量落地。
   S-04（风控员）来自 alert_ip_setting，全表仅 17 条，永远不用分批。 */


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-02 · 单份精确计数模板（想单独数某一份时用）
   ▸ 导出：不需要
   ▸ 用法：把 §06 里对应查询的最终 SELECT 换成 COUNT(*) 包一层即可
   ═══════════════════════════════════════════════════════════════════════ */
-- 例：只数 S-01 玩家数
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet
  FROM vd v
)
SELECT COUNT(*) AS n_rows FROM (
  SELECT member_id FROM bs GROUP BY member_id
  HAVING COUNT(DISTINCT round_key) >= 30
) t;


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-08a · 分批方案 A：会员号区间切分（推荐 · 最稳）
   ▸ 用途：先看会员号怎么分布，再按号段切，每段约 10 万人
   ▸ 优点：每批条件互斥且完备，绝不会重复也不会漏
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet
  FROM vd v
)
SELECT
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.2) AS 切点_20pct,
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.4) AS 切点_40pct,
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.6) AS 切点_60pct,
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.8) AS 切点_80pct,
  MIN(CAST(member_id AS BIGINT)) AS 最小会员号,
  MAX(CAST(member_id AS BIGINT)) AS 最大会员号
FROM (SELECT member_id FROM bs GROUP BY member_id
      HAVING COUNT(DISTINCT round_key) >= 30) t;

/* 拿到 4 个切点后，把 S-01 查询的末尾改成（以第 1 批为例）：
     GROUP BY b.member_id
     HAVING COUNT(DISTINCT b.round_key) >= 30
        AND CAST(b.member_id AS BIGINT) < 【切点_20pct】
     ORDER BY CAST(b.member_id AS BIGINT);
   第 2 批：>= 切点_20pct AND < 切点_40pct，依此类推，共 5 批。
   文件名：S01_player_score_part1.csv … _part5.csv，最后本地合并。 */


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-08b · 分批方案 B：游标翻页（批次多时用，越翻不会越慢）
   ▸ 用途：每次取 10 万，记下本批最后一个会员号，下批从它之后继续
   ═══════════════════════════════════════════════════════════════════════ */
-- 第 1 批：把 0 保持不变
-- 第 2 批：把 0 换成第 1 批结果里最后一行的 member_id
-- 依此类推，直到某批返回不足 100,000 行 = 全部取完
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.* FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet
  FROM vd v
),
lab AS (SELECT bet05 AS member_id,
               SUM(CASE WHEN risk='1' THEN 1 ELSE 0 END) AS n_risk_days,
               SUM(CASE WHEN orders='1' THEN 1 ELSE 0 END) AS n_order_days
        FROM ods_mariadb_2b.ods_a168_dailyreport_member GROUP BY bet05)
SELECT b.member_id,
  SUM(b.valid_bet) AS 流水贡献,
  COUNT(DISTINCT b.bet_date) AS 活跃稳定,
  COUNT(DISTINCT b.bet_ip) AS n_ip,
  COUNT(DISTINCT b.lv3) AS n_chain,
  COALESCE(MAX(l.n_risk_days),0)+COALESCE(MAX(l.n_order_days),0) AS 人工标记史
FROM bs b LEFT JOIN lab l ON l.member_id = b.member_id
WHERE CAST(b.member_id AS BIGINT) > 0        -- ★ 上一批最后一个会员号，第1批填 0
GROUP BY b.member_id
HAVING COUNT(DISTINCT b.round_key) >= 30
ORDER BY CAST(b.member_id AS BIGINT)          -- ★ 唯一键排序，杜绝跨页重复
LIMIT 100000;


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-09 · 分批合并后的自检（必做，10 秒）
   ▸ 用途：证明分批没有重复、没有漏
   ▸ 在本地（R/Python）跑，不是 SQL
   ═══════════════════════════════════════════════════════════════════════ */
-- R:
--   parts <- list.files("data", "^S01_player_score_part.*csv$", full.names=TRUE)
--   d <- dplyr::bind_rows(lapply(parts, readr::read_csv))
--   stopifnot(nrow(d) == 【COUNT-01 报出的 n_S01_玩家】)          # 没漏
--   stopifnot(!anyDuplicated(d$member_id))                        # 没重
--   readr::write_csv(d, "数据库/S01_player_score.csv")              # 合并落地
-- Python:
--   import glob, pandas as pd
--   d = pd.concat([pd.read_csv(p) for p in glob.glob("数据库/S01_player_score_part*.csv")])
--   assert len(d) == N_EXPECTED and d.member_id.is_unique
--   d.to_csv("数据库/S01_player_score.csv", index=False)

/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  卷二 · v3 增补（规则、经济学、特征矩阵、诊断与切分）                       ║
   ║  原「a168_取数SQL包_v3增补.sql」全量收编                                   ║
   ║  SQL 逻辑一字未改；仅修 §E02c 注释提前终止 1 处。                          ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  卷二与卷一的接续关系：                                                    ║
   ║   · §C06fix 取代 卷一 C-06 —— 对打对名单的唯一有效产出                     ║
   ║   · §S04p   取代 卷一 S-04a —— 风控员雷达的唯一有效产出                    ║
   ║   · §DX-01  是 §C06fix / §R02 / §R03 的前置条件，必先跑                    ║
   ║   · §E02c   取代 §E02 的 commission 恒置 0 版本（κ 已可实算）              ║
   ║   · §R03b   是 §R03 的日粒度版，时序对照图表的唯一输入                     ║
   ╚═══════════════════════════════════════════════════════════════════════════╝ */

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
   §00b · 辅助表字段名核对（★ 跑 §E02 / §K01b 之前必做，五秒钟）
   ---------------------------------------------------------------------------
   教训：K-01 首次运行报 `Column 'member_id' cannot be resolved.`，
   根因是 ods_a168_dailyreport_member / ods_a168_alert_ip_setting 的会员列与
   IP 列并不叫 member_id / ip —— 主表 bet02 用 betNN 代号，辅助表各有各的命名。
   本包因此把「一定跑得起来的部分」与「需要先核对列名的部分」彻底分开：
     · §E02 / §K01  —— 只碰 bet02 + agent，**保证跑通**
     · §K01b / §E02c —— 需要辅助表；★ 2026-08-07 列名已实测填实，可直接跑
   下面四条 DESC 各返回十几行，看一眼把真实列名抄下来即可。
   ─────────────────────────────────────────────────────────────────────────── */
DESC ods_mariadb_2b.ods_a168_dailyreport_member;
-- 找：会员标识列（可能叫 mem001 / memberid / username / uid）
--     風險單列（risk）、劃單列（orders）、日期列（dt / report_date）

DESC ods_mariadb_2b.ods_a168_alert_ip_setting;
-- 找：IP 列（可能叫 ip / alert_ip / ipaddress）、备注列（风控员判定原话）

DESC ods_mariadb_2b.ods_a168_member_dtl;
-- 找：会员标识列（doc 记为 mem001）、退水配置列（doc 记为 mem003）

DESC ods_mariadb_2b.ods_a168_employee;
-- 找：工号列（与 bet02.eid 对应）、type 列（type=3 为荷官）


/* ───────────────────────────────────────────────────────────────────────────
   §DX · 两条实测教训的诊断查询（2026-08-07 新增：C-06 零结果 + E1-11 语法错）
   ═══════════════════════════════════════════════════════════════════════════
   §DX-01 · bet09 玩法编码到底长什么样 —— ★ 跑本包任何含 hedge 的查询之前必做
   ---------------------------------------------------------------------------
   背景：C-06「同IP对打对」实测 9.3 秒返回 零结果。该查询的判别是
         bet_side IN ('1','B','庄','莊') / ('2','P','闲','閒')。
         零结果的最可能解释不是「本平台没有对打」——@sec-e1-dist 曾记录
         999 对完美对打、最长 1,185 把——而是 bet09 的实际取值不在这份清单里。
   影响面：凡需区分庄/闲之处全部失效，且失效方式是「静默」的：
         判别不匹配 → is_b/is_p 恒为 0 → hedge_rate 恒为 0 → 阈值 P90 也是 0
         → 打水型闸门形同虚设，却不报任何错。这比报错危险得多。
   ★ 2026-08-07 已实测，结果如下（139 天全量 1.256 亿注单，23 种玩法）：
       Banker 4,682万(37.3%) / Player 4,422万(35.2%) / Tie 964万(7.7%)
       边注 20 种合计 2,496万(19.9%)：BPair PPair Super6 Lucky7 SuperLucky7
            PerfectPair BankerDragonBonus PlayerDragonBonus AnyPair Big
            BankerNatural PlayerNatural Small 等
       另有 7 种玩法（Lucky7TwoCard/SuperTie4,5,8,9/SmallTiger/Bear8）
            各仅 1 笔、均在 2026-07-20 —— 判为**上线试跑残留**，一切统计中剔除。
   结论：C-06 零结果的原因确认为**编码不匹配**，不是「平台无对打」。
   ★ 关键陷阱：不能用 LIKE '%BANK%'。它会把 BankerDragonBonus(20.7万笔)
     与 BankerNatural(6.2万笔) 算成庄——那是边注，与主线庄闲不构成对冲。
     本包三处判别已全部改为 **等值匹配 'Banker' / 'Player'**。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT bet09 AS bet_side_raw,
       COUNT(*)                                            AS n_orders,
       COUNT(DISTINCT bet05)                               AS n_member,
       SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))  AS stake_raw_sum,
       MIN(dt) AS first_day, MAX(dt) AS last_day
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1'
  AND UPPER(TRIM(bet38)) = 'N'
GROUP BY bet09
ORDER BY n_orders DESC;
/* 读法：按 n_orders 排序，前两名通常就是庄与闲（百家乐庄闲各占约四成）。
   把这两个真实取值填回三处判别（§T03 的 is_b/is_p、§B01 与 §K01 的
   is_self_hedge），以及 C-06 的 side CTE。
   本包已用「LIKE 字母码 OR IN 数字/中文码」的宽口径并集先兜一层；
   若真实取值仍在并集之外（例如 '101'/'102' 这类内部码），必须手动改。
   ★ C-06 修复方法：把它的 side CTE 里的
       bet_side IN ('1','B','庄','莊') → bet_side = 'Banker'
       bet_side IN ('2','P','闲','閒') → bet_side = 'Player'
     改完复跑，对打证据链即可复活。 */


/* ═══════════════════════════════════════════════════════════════════════════
   §DX-02 · 为什么 E1-11 报 Unexpected input 'R_rebate_dist'
   ---------------------------------------------------------------------------
   这是注释写法的问题，不是 SQL 本身的问题。原注释里有这么一行：

       导出：（两个星号）数据库/R_rebate_dist.csv（两个星号）

   块注释的终止符是「星号+斜杠」。上面这行里，两个星号与后面的斜杠之间
   只隔着 CJK 字符。当解析链路（Superset 前端预处理 / 剪贴板 / 编辑器编码）
   任何一环丢失或跳过非 ASCII 字符时，那段就塌缩成「星号+斜杠」，
   注释被提前终止，紧随其后的 R_rebate_dist 便成了语句的第一个 token
   —— 报错信息里那个 token 正是它，这也是本判断的依据。

   固化规则：SQL 注释里禁止出现「连续星号」紧邻「斜杠」的写法。
   本包已把所有 (星号星号)数据库/xxx.csv(星号星号) 统一改写为 「数据库/xxx.csv」。
   ═══════════════════════════════════════════════════════════════════════════
   §DX-03 · 取列定义的通用写法（比 DESC 好用：带列注释与顺序，一条顶三条）
   ─────────────────────────────────────────────────────────────────────────── */
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME IN ('ods_a168_member_dtl',
                     'ods_a168_dailyreport_member',
                     'ods_a168_alert_ip_setting')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
/* 拿到结果即可填回：§E02b 的退水配置列、§K01b 的会员列与 IP 列。
   COLUMN_COMMENT 里常写着中文列义，比靠列名猜可靠得多。 */


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
         /* ★ 2026-08-07 DX-01 实测校准：bet09 为英文玩法名。
            必须用等值匹配，不能用 LIKE '%BANK%' —— 后者会把
            BankerDragonBonus(20.7万) 与 BankerNatural(6.2万) 一并算成庄，
            而那是边注，与主线庄闲不构成对冲关系。 */
         CASE WHEN TRIM(bet_side) = 'Banker' THEN 1 ELSE 0 END AS is_b,
         CASE WHEN TRIM(bet_side) = 'Player' THEN 1 ELSE 0 END AS is_p
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
  /* ★ 自足版：退水档位用「实测退水率」= rebate 除以 validbet 分档，
     不 join member_dtl —— 该表的会员列名尚未核对（见 §00b），
     且实测口径本来就比配置口径更贴近真实成本。
     若已核对好列名、想用配置档位，改跑下方 §E02b。 */
  SELECT m.*,
         ROUND(m.rebate / NULLIF(m.validbet,0), 3) AS rebate_rate_bkt,
         NTILE(4) OVER (ORDER BY m.validbet) AS vb_q
  FROM mem m
  WHERE m.validbet > 0
)
SELECT
  CONCAT('实测退水', CAST(rebate_rate_bkt AS STRING),
         ' · 流水Q', CAST(vb_q AS STRING))   AS segment,
  COUNT(*)                                   AS n_member,
  SUM(validbet)                              AS validbet,
  -SUM(game_pnl)                             AS ggr,          -- 庄家赢 = 玩家输
  SUM(rebate)                                AS rebate,
  0                                          AS commission,   -- ⚠️ 见下方警告
  AVG(n_months)                              AS tenure_months
FROM mem2
GROUP BY rebate_rate_bkt, vb_q
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
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1
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
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1
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
)
SELECT f.member_id,
       CAST(0 AS INT) AS is_seed,          -- ★ 占位列：种子一律在 Python 侧并入，见下方说明
       f.n_rounds, f.n_days, f.n_tables, f.n_ip, f.n_dealer,
       COALESCE(se.side_entropy, 0) AS side_entropy,
       f.stake_cv, f.stake_p90_p50, f.hedge_rate, f.rebate_dep,
       f.night_share, f.roi_game, f.validbet
FROM feat f
LEFT JOIN side_ent se ON se.member_id = f.member_id
WHERE f.n_rounds >= 50
ORDER BY f.validbet DESC;
/* ═══ 为什么 is_seed 恒为 0 —— 这是刻意的，不是遗漏 ═══════════════════════════
   首版这里 join 了 dailyreport_member 与 alert_ip_setting，实跑报错：
     StarRocks: Column 'member_id' cannot be resolved.
   根因：主表 bet02 用 betNN 代号，辅助表各有各的命名，两张辅助表的会员列
   与 IP 列都不叫 member_id / ip。列名未核对就写 join，是本包唯一一次踩坑。

   斧正后的分工（也更符合「种子必须混合来源」这条原则）：
     · 本查询 = **纯特征矩阵**，只碰 bet02 + agent，保证任何时候都跑得通；
     · 五路种子全部在 Python 侧合并（@sec-t4 的 t4-cluster 块已实现）：
         ①人工風險單/劃單  ②L0 金标准 IP  ③R-01 闸三  ④R-02 Lift≥3  ⑤R-03 Z≥4
       其中 ③④⑤ 直接读 R01/R02/R03 三份 CSV；①② 走下方 §K01b。
   好处：任何一路种子缺位，T4 仍能用其余几路跑起来，不会因一张辅助表卡死全章。
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §K01b · 种子来源①② —— ★ 2026-08-07 列名已实测填实，可直接运行
   ---------------------------------------------------------------------------
   实测列定义（information_schema 确认）：
     ods_a168_dailyreport_member : bet05=會員編號  risk=風險單(1:是)  orders=劃單(1:是)
                                   dt=日分区  category=1一般/2小費  bet02=遊戲編號
     ods_a168_alert_ip_setting   : ip  creator  addtime  remarks(风控员判定原话)
   导出：「数据库/K01b_seed_manual.csv」（两条各跑一次，纵向合并成一份）
   ═══════════════════════════════════════════════════════════════════════════ */
-- ① 人工風險單 / 劃單（L1a 人工标签）
SELECT DISTINCT bet05 AS member_id, 'manual_risk' AS seed_src
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101'
  AND (CAST(NULLIF(TRIM(risk),'')   AS INT) = 1
    OR CAST(NULLIF(TRIM(orders),'') AS INT) = 1)
  AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
ORDER BY member_id;
-- 注意：risk/orders 在 ODS 里是 varchar 承载的 tinyint，必须 CAST 后比 1，
--       写成 risk > 0 会做字符串比较，'0' > 0 的语义在不同引擎下不一致。

-- ② L0 金标准关注 IP 下的会员（先单跑 alert 名单看它是否仍活跃）
SELECT id, ip, creator, addtime, remarks
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
ORDER BY addtime DESC;

-- ②b 关注 IP 命中的会员（上一条确认 IP 仍在本窗口出现后再跑）
SELECT DISTINCT b.bet05 AS member_id, 'gold_ip' AS seed_src
FROM ods_mariadb_2b.ods_a168_bet02 b
JOIN ods_mariadb_2b.ods_a168_alert_ip_setting a ON TRIM(a.ip) = TRIM(b.ip)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101' AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
ORDER BY member_id;


/* ═══════════════════════════════════════════════════════════════════════════
   §E02c · 分群单位经济学（★ 占成版 —— 补齐上一轮标注的唯一不完整字段）
   ---------------------------------------------------------------------------
   上一轮 §E02 把 commission 恒置 0，并警告「会让净贡献率系统性偏乐观、
   γ* 偏大（赏得过头）」。DX-03 实测发现 ods_a168_dailyreport_member 里
   本来就有五级占成与五级退水：
       bet23~bet27 = LV1~LV5 占成      bet28~bet32 = LV1~LV5 退水
       bet41 = 有效投注   bet13 = 下注金額   bet14 = 派彩金額
       bet15 = 會員退水%數   bet11 = 匯率
   于是 κ（占成率）可以直接算出来，E02 的那个 0 就填实了。
   ---------------------------------------------------------------------------
   ⚠️ 量纲未定：bet23~bet32 是「金额」还是「比率」，列注释没写。
      先跑 §E02c-0 看量级——若与 bet41 同数量级则为金额，若恒在 0~1 则为比率。
      量纲判错会让 κ 差几个数量级，δ* 与 γ* 全盘失真。**这一步不可跳过。**
   导出：「数据库/E02_segment_econ.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
-- §E02c-0 · 量纲探针（先跑这条，30 秒，决定下面怎么算）
SELECT
  COUNT(*)                                                            AS n_rows,
  AVG(CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)))                  AS avg_validbet,
  AVG(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))                  AS avg_stake,
  AVG(CAST(NULLIF(TRIM(bet15),'') AS DECIMAL(20,4)))                  AS avg_rebate_pct,
  AVG(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4)))                  AS avg_lv1_comm,
  MAX(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4)))                  AS max_lv1_comm,
  AVG(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4)))                  AS avg_lv1_reb,
  MAX(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4)))                  AS max_lv1_reb
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1';
-- 读法：max_lv1_comm ≤ 1 且 avg 在 0.0x 量级 → 比率；
--       与 avg_validbet 同量级（成千上万）→ 金额。下面按「金额」写，
--       若探针判为比率，把 §E02c 里 comm_amt 的算式改为
--         SUM((bet23+..+bet27) * bet41 / bet11)

-- §E02c · 分群单位经济学（占成已补齐）
WITH d AS (
  SELECT bet05 AS member_id, dt,
         CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS vb_raw,
         CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         COALESCE(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet29),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet30),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet31),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet32),'') AS DECIMAL(20,4)),0) AS reb_raw,
         COALESCE(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet24),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet25),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet26),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,4)),0) AS comm_raw
  FROM ods_mariadb_2b.ods_a168_dailyreport_member
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
    AND bet02 = '101' AND category = '1'
    AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0
),
mem AS (
  SELECT member_id,
         SUM(vb_raw / fx)                        AS validbet,
         SUM((payout_raw - stake_raw) / fx)      AS game_pnl,
         SUM(reb_raw  / fx)                      AS rebate,
         SUM(comm_raw / fx)                      AS commission,
         COUNT(DISTINCT DATE_FORMAT(CAST(dt AS DATE),'%Y-%m')) AS n_months,
         COUNT(DISTINCT dt)                      AS n_days
  FROM d GROUP BY member_id
),
mem2 AS (
  SELECT m.*,
         /* 分群：实测退水率三位小数分档 × 洗码量四分位，全部由数据算出 */
         ROUND(m.rebate / NULLIF(m.validbet,0), 3) AS rebate_rate_bkt,
         NTILE(4) OVER (ORDER BY m.validbet)       AS vb_q
  FROM mem m WHERE m.validbet > 0
)
SELECT
  CONCAT('实测退水', CAST(rebate_rate_bkt AS STRING),
         ' · 流水Q', CAST(vb_q AS STRING)) AS segment,
  COUNT(*)             AS n_member,
  SUM(validbet)        AS validbet,
  -SUM(game_pnl)       AS ggr,           -- 庄家赢 = 玩家输
  SUM(rebate)          AS rebate,
  SUM(commission)      AS commission,    -- ★ 不再是 0
  AVG(n_months)        AS tenure_months
FROM mem2
GROUP BY rebate_rate_bkt, vb_q
ORDER BY validbet DESC;
/* ★ 交叉校验（务必做）：本表的 SUM(validbet) 应与 §E02 走 bet02 明细算出的
   洗码量大体一致。dailyreport 是日汇总表，bet02 是注单明细表，两者若差异
   超过 5%，说明 dailyreport 的口径含小費/其他游戏或未剔测试线——
   以 bet02 明细为准，把本表仅用于取 commission 一列并回贴。 */


/* ───────────────────────────────────────────────────────────────────────────
   §C06fix · C-06 同IP对打对（DX-01 校准版，替换原包 C-06）
   ---------------------------------------------------------------------------
   原版 side CTE 用 bet_side IN ('1','B','庄','莊') / ('2','P','闲','閒')，
   与库内实际取值 Banker / Player 完全不匹配 → 两次实测均返回零行。
   本版只改 side CTE 两行判别，其余一字未动。
   注释一律用行注释，不用块注释（见 §DX-02 写法禁令）。
   导出：「数据库/C06_hedge_pairs.csv」
   ─────────────────────────────────────────────────────────────────────────── */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
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
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake
  FROM vd v
),
side AS (
  -- 每人每把在该IP的净方向（庄=+ 闲=-，按本金）
  -- ★ DX-01 校准：等值匹配 Banker / Player。
  --   不可用 LIKE '%BANK%'：会误纳 BankerDragonBonus(20.7万笔)、
  --   BankerNatural(6.2万笔) 等边注，那与主线庄闲不构成对冲关系。
  SELECT bet_ip, round_key, member_id,
         SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                  WHEN TRIM(bet_side) = 'Player' THEN -stake
                  ELSE 0 END) AS dir_stake
  FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY bet_ip, round_key, member_id
  HAVING ABS(SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                      WHEN TRIM(bet_side) = 'Player' THEN -stake
                      ELSE 0 END)) > 0
),
pairs AS (
  SELECT a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         COUNT(*) AS n_same_round,
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN 1 ELSE 0 END) AS n_opposite_round,
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0
                   AND ABS(ABS(a.dir_stake)-ABS(b.dir_stake))
                       <= 0.1*GREATEST(ABS(a.dir_stake),ABS(b.dir_stake))
                  THEN 1 ELSE 0 END) AS n_hedged
  FROM side a JOIN side b
    ON a.bet_ip=b.bet_ip AND a.round_key=b.round_key
   AND a.member_id < b.member_id
  GROUP BY a.bet_ip, a.member_id, b.member_id
  HAVING COUNT(*) >= 30
)
SELECT bet_ip, m_a, m_b, n_same_round, n_opposite_round,
       n_opposite_round*1.0/n_same_round AS opposite_rate,
       n_hedged*1.0/NULLIF(n_opposite_round,0) AS hedge_coverage
FROM pairs
ORDER BY opposite_rate DESC, n_opposite_round DESC;
-- 若本版仍返回零行，那才是真正的结论（同IP无对打）；
-- 但在此之前先跑下面这条一行探针确认判别已生效：
--   SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_bet02
--   WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet09 = 'Banker';
-- 该数应约为 4,682 万。若为 0，说明 bet09 有前后空格，把判别改成
--   UPPER(TRIM(bet_side)) = 'BANKER' / 'PLAYER'。


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

/* ───────────────────────────────────────────────────────────────────────────
   §TG · 时间一致性守卫（截止日 2026-08-07）
   ---------------------------------------------------------------------------
   目的：事实表已按窗口截断，但**维度表通常是最新快照**。
   两者时点不一致会造成两类静默错误：
     ① 穿越 —— 会员注册时间晚于其首笔注单 → 「注册至今天数」为负 → 生命周期特征全错
     ② 口径漂移 —— 「该 IP 关联多少会员」算的是今天的关联，不是窗口内的关联
   凡检出晚于截止日的记录，一律先剔除并记数，再进入建模。
   ─────────────────────────────────────────────────────────────────────────── */

-- §TG-01 · 会员注册时间 vs 首笔注单时间（穿越检测）
-- ★★ 会员主表尚未提供，先跑 §DX-03 拿到列名后把 ★★ 替换掉
-- SELECT m.★★会员列★★ AS member_id,
--        m.★★注册时间列★★ AS reg_time,
--        f.first_bet,
--        CASE WHEN CAST(m.★★注册时间列★★ AS DATE) > DATE '2026-08-07'
--               THEN '未来日期'
--             WHEN CAST(m.★★注册时间列★★ AS DATETIME) > f.first_bet
--               THEN '注册晚于首注单（穿越）'
--             ELSE 'OK' END AS verdict
-- FROM ods_mariadb_2b.★★会员主表★★ m
-- LEFT JOIN (SELECT bet05, MIN(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS first_bet
--            FROM ods_mariadb_2b.ods_a168_bet02
--            WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101'
--            GROUP BY bet05) f ON f.bet05 = m.★★会员列★★
-- ORDER BY verdict, member_id;

-- §TG-03 · 关注 IP 名单的登记时间是否越过截止日（可直接跑，列名已实测）
SELECT id, ip, creator, addtime, remarks,
       CASE WHEN CAST(SUBSTR(addtime,1,10) AS DATE) > DATE '2026-08-07'
            THEN '🔴 未来日期，应从 L0 金标准剔除' ELSE '🟢 OK' END AS verdict
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
ORDER BY addtime DESC;

-- §TG-05 · 事实表自身的越界自检（应返回 0 行；非 0 即窗口过滤有漏）
SELECT COUNT(*) AS n_future_rows,
       MIN(dt) AS min_dt, MAX(dt) AS max_dt
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= DATE '2026-08-07';


/* ───────────────────────────────────────────────────────────────────────────
   §DX-04 · 玩法 × 会员 的子分类底料（@sec-subclass 的定量输入）
   输出：bet09 玩法 · 注单数 · 会员数 · 投注额 · 玩家盈亏 · 实测庄家 hold%
   用途：验证各玩法的实测庄家优势与理论值是否一致；偏离大的玩法优先查
   导出：「数据库/DX04_bet09_profile.csv」
   ─────────────────────────────────────────────────────────────────────────── */
WITH ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
o AS (
  SELECT r.bet09 AS bet_side, r.bet05 AS member_id,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl
  FROM ranked r
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
)
SELECT bet_side,
       COUNT(*)                                   AS n_orders,
       COUNT(DISTINCT member_id)                  AS n_member,
       SUM(stake)                                 AS stake_total,
       SUM(game_pnl)                              AS player_pnl,
       -SUM(game_pnl) / NULLIF(SUM(stake),0)      AS house_hold_pct,
       SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
         / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END),0) AS win_rate_base,
       AVG(stake)                                 AS avg_stake,
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)  AS stake_cv
FROM o
GROUP BY bet_side
ORDER BY n_orders DESC;
-- 读法：house_hold_pct 应接近该玩法的理论庄家优势。
--   明显低于理论值的玩法 = 该玩法上有人在赢庄家 → 优先查；
--   win_rate_base 就是 R-03 的 Z-score 基准，务必按玩法取用，不可混算。

/* ───────────────────────────────────────────────────────────────────────────
   §DX-05 · 产品全景：本报告只覆盖了多大一块？
   ---------------------------------------------------------------------------
   全文所有 SQL 都带 bet02 = '101'（百家乐）。这是主动的产品口径选择，
   但必须知道它在全平台里占多少——否则漏损总量会被低估、净贡献率会被算偏
   （退水与占成按全产品结算，而分子只算了百家乐）。
   本查询给出各产品的注单量、投注额、玩家盈亏、庄家 hold%，一次看清占比。
   导出：「数据库/DX05_product_panorama.csv」
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
),
o AS (
  SELECT r.bet02 AS product_code, r.bet05 AS member_id, r.eid AS dealer_id,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         COALESCE(CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)),
                  CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS validbet,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS rebate
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
)
SELECT product_code,
       CASE WHEN product_code = '101' THEN '百家乐（本报告口径）' ELSE '其他产品' END AS scope,
       COUNT(*)                                  AS n_orders,
       COUNT(DISTINCT member_id)                 AS n_member,
       COUNT(DISTINCT dealer_id)                 AS n_dealer,
       SUM(stake)                                AS stake_total,
       SUM(validbet)                             AS validbet_total,
       SUM(game_pnl)                             AS player_pnl,
       -SUM(game_pnl)                            AS ggr,
       -SUM(game_pnl) / NULLIF(SUM(stake),0)     AS house_hold_pct,
       SUM(rebate)                               AS rebate_total,
       SUM(rebate) / NULLIF(SUM(validbet),0)     AS rebate_rate,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()    AS order_share,
       SUM(stake) / SUM(SUM(stake)) OVER ()      AS stake_share
FROM o
GROUP BY product_code
ORDER BY n_orders DESC;
/* 读法（三个关键比值）：
   ① 百家乐的 order_share / stake_share —— 本报告覆盖面。低于 70% 则所有金额结论
      必须显式标注「百家乐口径」，不得当全平台数字引用。
   ② 各产品的 house_hold_pct —— 明显低于理论庄家优势者，说明该产品上有人在赢庄家，
      应优先把本方案的三条风控线移植过去。
   ③ 各产品的 rebate_rate —— 退水率显著高于百家乐的产品，是打水套利的下一个战场。
      @sec-econ 的 κ 与 ρ 必须按全产品重算，否则净贡献率系统性偏乐观。 */

/* ───────────────────────────────────────────────────────────────────────────
   §00c · 表行数复核（一次给全，供报告的「核心表点货单」现算行数）
   ---------------------------------------------------------------------------
   报告里的「行数量级」原本是早期测试期的静态记忆。跑这条导出后，
   点货单会自动改为「实测」并标注；不跑则显式标注「历史记录·未复核」。
   导出：「数据库/V_table_counts.csv」（两列：表名 / 行数）
   注：information_schema.tables 的 TABLE_ROWS 在 StarRocks 上是估算值，
       所以这里用 COUNT(*) 精确统计。表多时耗时以分钟计，属正常。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT 'ods_a168_bet02'              AS 表名, COUNT(*) AS 行数 FROM ods_mariadb_2b.ods_a168_bet02
UNION ALL SELECT 'ods_a168_bet01',              COUNT(*) FROM ods_mariadb_2b.ods_a168_bet01
UNION ALL SELECT 'ods_a168_game_info',          COUNT(*) FROM ods_mariadb_2b.ods_a168_game_info
UNION ALL SELECT 'ods_a168_agent',              COUNT(*) FROM ods_mariadb_2b.ods_a168_agent
UNION ALL SELECT 'ods_a168_member_dtl',         COUNT(*) FROM ods_mariadb_2b.ods_a168_member_dtl
UNION ALL SELECT 'ods_a168_dailyreport_member', COUNT(*) FROM ods_mariadb_2b.ods_a168_dailyreport_member
UNION ALL SELECT 'ods_a168_alert_ip_setting',   COUNT(*) FROM ods_mariadb_2b.ods_a168_alert_ip_setting
UNION ALL SELECT 'ods_a168_employee',           COUNT(*) FROM ods_mariadb_2b.ods_a168_employee
UNION ALL SELECT 'ods_a168_game_No',            COUNT(*) FROM ods_mariadb_2b.ods_a168_game_No
ORDER BY 行数 DESC;
/* 若某张表名在本库不存在，删掉对应那一行 UNION 再跑；
   报告侧对缺失的表名会自动落回「历史记录·未复核」，不会报错。 */

/* ───────────────────────────────────────────────────────────────────────────
   §R03b · R03b_player_dealer_daily.csv —— R-03 的**日粒度**版本
   ---------------------------------------------------------------------------
   为什么要它：R-03 是全窗口聚合（一个玩家×荷官一行），没有日期维度，
   因此做不了「需求原规则 vs Z 轨」的时序对照。本查询与 §R03 口径**一字不动**
   （局级去重、玩法基准、排除 Tip），只把聚合键从
       GROUP BY member_id, dealer_id
   改为
       GROUP BY member_id, dealer_id, bet_date
   输出：bet_date, uid, dealer_id, stake_amount, profit_amount, win_rate,
         n_related_orders, n_rounds_eff, p_base_mix, z_score
   ─────────────────────────────────────────────────────────────────────────── */
WITH ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'
),
ord AS (
  SELECT member_id, dealer_id, bet_date, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord GROUP BY bet_side
),
pr AS (   -- 局级去重：同一物理局折成一局，避免 Z-score 被 sqrt(k) 放大
  SELECT member_id, dealer_id, bet_date, round_key,
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,
         COUNT(*) AS n_orders_in_round, MAX(bet_side) AS main_side
  FROM ord GROUP BY member_id, dealer_id, bet_date, round_key
)
SELECT p.bet_date, p.member_id AS uid, p.dealer_id,
       SUM(p.stake)                                        AS stake_amount,
       SUM(p.game_pnl)                                     AS profit_amount,
       SUM(p.net_pnl)                                      AS net_pnl,
       SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
         / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,
       SUM(p.n_orders_in_round)                            AS n_related_orders,
       COUNT(*)                                            AS n_rounds_eff,
       AVG(COALESCE(s.p_base, 0.5))                        AS p_base_mix,
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(COALESCE(s.p_base,0.5)))
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                       * AVG(COALESCE(s.p_base,0.5))
                       * (1 - AVG(COALESCE(s.p_base,0.5)))), 0)        AS z_score
FROM pr p
LEFT JOIN side_base s ON s.bet_side = p.main_side
GROUP BY p.bet_date, p.member_id, p.dealer_id
ORDER BY p.bet_date, z_score DESC;
/* ⚠️ 日粒度下单日有效局数天然偏少，Z-score 噪声比全窗口版大得多。
   本导出**只用于时序对照与趋势观察**，处置判定一律仍以 §R03 全窗口版为准。 */

/* ───────────────────────────────────────────────────────────────────────────
   §S04p · 风控员最小画像（S04_analyst_score.csv 的**部分实测**替代）
   ---------------------------------------------------------------------------
   现状：风控员的四个维度（标注产量/命中率/复核时效/误标率）全部依赖
   「风控处置日志」——本平台还没有这张表。库里能沾边的只有两处：
     · alert_ip_setting.creator —— 有登记人，但只有 17 条、且是 2022 年的
     · dailyreport.risk/orders  —— 只记了「会员被标了」，**没记是谁标的**
   所以本查询给的**不是绩效评分**，只是让那张雷达从「全合成」变成「部分实测」，
   并把缺口摆明。四个维度里它只能填「标注产量」一项，其余仍为待补。
   导出：「数据库/S04_analyst_score.csv」
   ─────────────────────────────────────────────────────────────────────────── */
SELECT
  COALESCE(NULLIF(TRIM(creator), ''), '未署名')      AS entity_id,
  -- ★ 下面三个列名与报告的风控专员雷达字典严格对应，一字不可改
  COUNT(*)                                            AS 标注产量,
  COUNT(DISTINCT TRIM(ip))                            AS 覆盖IP广度,
  AVG(LENGTH(COALESCE(remarks, '')))                  AS 判定详尽度,
  MIN(addtime)                                        AS 首次登记,
  MAX(addtime)                                        AS 最近登记
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
GROUP BY COALESCE(NULLIF(TRIM(creator), ''), '未署名')
ORDER BY 标注产量 DESC;
/* ⚠️ 三条使用限制，务必随表一起交付：
   1. 样本仅 17 条量级，**不足以做绩效排名**，只可作画像展示；
   2. 「命中率 / 复核时效 / 误标率」三维仍缺，雷达上会显示为空维；
   3. 登记时间多在 2022 年，与本报告 139 天窗口无重叠——
      任何跨期比较都不成立。先跑 §TG-03 确认时间范围再决定是否使用。 */
