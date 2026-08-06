/* ╔═══════════════════════════════════════════════════════════════════════╗
   ║  a168_核验与取数_SQL包.sql · 全量正典（2026-08-06 定稿）                 ║
   ║  配套报告：a168风控与客户分层评分体系_商业方案.qmd（两文件铁律）          ║
   ╚═══════════════════════════════════════════════════════════════════════╝
   使用纪律（实测 9 连报错后固化，逐条血泪）：
   ① 每条查询自包含、零占位符——复制整段直接在 Superset SQL Lab 运行；
   ② StarRocks 方言：禁 LATERAL VIEW EXPLODE（用 UNNEST）、
      禁 EXISTS+多列 IN（用五路 LEFT JOIN + COALESCE IS NULL）；
   ③ 逐条提交，禁批量（僵尸查询风险）；导出加 ORDER BY（防分页重复）；
   ④ 导出上限 1,000 行：只承认排序头部结论，「未出现」类判断一律无效；
   ⑤ 全局窗口 2026-03-21 ~ 2026-08-07（139 营业日），改窗改字面量。
   ╔══ 导出总览（★ = 报告渲染必需；文件名错则报告静默空转）══════════╗
   ║ 必导 23 份，全部落在报告同级 数据库/ 目录，UTF-8 BOM，导出前带 ORDER BY ║
   ║  ★ S01_player_score.csv    ← S-01   玩家评分雷达                    ║
   ║  ★ S02_dealer_score.csv    ← S-02   荷官评分雷达                    ║
   ║  ★ S03_agent_score.csv     ← S-03   代理评分雷达                    ║
   ║  ★ S04_analyst_score.csv   ← S-04   风控员评分雷达                  ║
   ║  ★★ S05_member_month_panel.csv ← S-05 净化滚动回测面板（竞技场输入）║
   ║  ★ V_recon.csv             ← A-06M  局级对账 MASE                   ║
   ║  ★ I_ip_player.csv         ← C-00   会员×IP 明细                    ║
   ║  ★ S_player_tail.csv       ← D-06   玩家尾段十一项                  ║
   ║  ★ S_second_dist.csv       ← D-05   桌台进度分位                    ║
   ║  ★ T_table_span.csv        ← E1-07  桌台局时长                      ║
   ║    C01_ip_chain.csv        ← C-01   信用枢纽排序                    ║
   ║    C06_hedge_pairs.csv     ← C-06   对打对名单                      ║
   ║    C08_subnet_all.csv      ← C-08   网段全量                        ║
   ║    C08_subnet_sparse.csv   ← N1     稀疏段靶向                      ║
   ║    D03S_daily_roi_diff.csv ← D-03S  日度尾段对照                    ║
   ║    L_label_dist.csv        ← E1-10  标签分布                        ║
   ║    R_rebate_dist.csv       ← E1-11  退水档位分布                    ║
   ║  ★ I_ip_agg.csv            ← C-02   IP汇总三版本口径                ║
   ║  ★ X_combo.csv             ← X-01   两规则组合矩阵                  ║
   ║  ★ P_player_month.csv      ← P-01   会员×月面板（跨月持续）         ║
   ║  ★ B_online_base.csv       ← B-01   在线人数基准（29秒分母）        ║
   ║  ★ A_anchor.csv            ← A-01   L0金标准17IP锚点                ║
   ║  ★ V_ipmatch.csv           ← V-01   三方IP明细对照                  ║
   ║ 其余 8 条（00-1~00-4/E1-03/E1-08/N1b/V2）只看屏幕结果，不必导出。   ║
   ║ ▶ 导出前先跑 §08 的 COUNT-01 数行数，超 10 万用 COUNT-08a/b 分批。  ║
   ║ ▶ 导出编码务必 UTF-8：表头是中文，存成 ANSI/GBK 会让 Python 报      ║
   ║   'invalid start byte'。若已存成 GBK 也无妨——报告已内建编码自适应。 ║
   ╚══════════════════════════════════════════════════════════════════╝
   行业正名速查：bet03靴号 bet04第几把 bet05会员 bet09玩法 bet11汇率
   bet13本金 validbet洗码量 bet14派彩 bet16退水 bet17净输赢
   bet18–22五级代理线 bet39桌号 eid荷官  ——详见报告第〇章。 */

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
   
   ▸ 导出：**数据库/T_table_span.csv**
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
   
   ▸ 导出：**数据库/L_label_dist.csv**
   ▸ 用途：風險單/劃單标签分布，标签可用性存档
   ═══════════════════════════════════════════════════════════════════════ */
SELECT risk, orders, COUNT(*) AS n_rows,
       COUNT(DISTINCT bet05) AS n_member,
       MIN(dt) AS first_dt, MAX(dt) AS last_dt
FROM ods_mariadb_2b.ods_a168_dailyreport_member
GROUP BY risk, orders ORDER BY n_rows DESC;


/* ═══════════════════════════════════════════════════════════════════════
   E1-11 · 会员退水配置分布（0.3/0.8/0.9% 档人群——洗码经济学输入）
   
   ▸ 导出：**数据库/R_rebate_dist.csv**
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
   ▸ 导出：**数据库/V_recon.csv**
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
   ▸ 导出：**数据库/I_ip_player.csv**
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
   
   ▸ 导出：**数据库/C01_ip_chain.csv**
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


/* ═══════════════════════════════════════════════════════════════════════
   C-06 · 同IP对打对 · 对冲覆盖（实测 999 对完美对打、最长 1,185 把）
   本金匹配容差 10%；玩法编码若与库内不符，改 bet_side 判别清单即可
   ▸ 导出：**数据库/C06_hedge_pairs.csv**
   ▸ 用途：对打对名单，IP-S6/IP-S8 与荷官/代理罚项来源
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
side AS (   -- 每人每把在该IP的净方向（庄=+ 闲=−，按本金）
  SELECT bet_ip, round_key, member_id,
         SUM(CASE WHEN bet_side IN ('1','B','庄','莊') THEN stake
                  WHEN bet_side IN ('2','P','闲','閒') THEN -stake
                  ELSE 0 END) AS dir_stake
  FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY bet_ip, round_key, member_id
  HAVING ABS(SUM(CASE WHEN bet_side IN ('1','B','庄','莊') THEN stake
                      WHEN bet_side IN ('2','P','闲','閒') THEN -stake
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
   
   ▸ 导出：**数据库/C08_subnet_all.csv**
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
   ▸ 导出：**数据库/C08_subnet_sparse.csv**
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
   
   ▸ 导出：**数据库/S_second_dist.csv**
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
   
   ▸ 导出：**数据库/D03S_daily_roi_diff.csv**
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
   ▸ 导出：**数据库/S_player_tail.csv**
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
   ▸ 导出：**数据库/S01_player_score.csv**
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
        FROM ods_mariadb_2b.ods_a168_dailyreport_member GROUP BY bet05)
SELECT b.member_id,
  SUM(b.valid_bet) AS 流水贡献,
  -SUM(b.game_pnl) AS 游戏输赢贡献,          -- 会员输=平台赢，取负号
  COUNT(DISTINCT b.bet_date) AS 活跃稳定,
  SUM(b.rebate) AS 退水支出,
  COUNT(DISTINCT b.bet_ip) AS n_ip,
  COUNT(DISTINCT b.lv3) AS n_chain,
  COALESCE(MAX(l.n_risk_days),0)+COALESCE(MAX(l.n_order_days),0) AS 人工标记史
FROM bs b LEFT JOIN lab l ON l.member_id=b.member_id
GROUP BY b.member_id
HAVING COUNT(DISTINCT b.round_key) >= 30
ORDER BY 流水贡献 DESC;


/* ═══════════════════════════════════════════════════════════════════════
   S-02 · 荷官评分底料
   对打局占比/異常对关联在 Python 侧并 C-06 名单；导出 数据库/S02_dealer_score.csv
   ▸ 导出：**数据库/S02_dealer_score.csv**
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
)
SELECT dealer_id,
  SUM(valid_bet) AS 在桌洗码量,
  COUNT(DISTINCT member_id) AS 客群广度,
  COUNT(DISTINCT round_key) AS n_rounds,
  COUNT(DISTINCT table_id) AS n_tables,
  SUM(game_pnl) AS 桌面输赢
FROM bs WHERE NULLIF(TRIM(dealer_id),'') IS NOT NULL
GROUP BY dealer_id ORDER BY 在桌洗码量 DESC;


/* ═══════════════════════════════════════════════════════════════════════
   S-03 · 代理（LV3 链）评分底料
   对打渗透率在 Python 侧并 C-06；导出 数据库/S03_agent_score.csv
   ▸ 导出：**数据库/S03_agent_score.csv**
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
)
SELECT lv3,
  COUNT(DISTINCT member_id) AS 线下规模,
  SUM(valid_bet) AS 真实流水,
  SUM(rebate)    AS 退水支出,
  SUM(game_pnl)  AS 链下游戏输赢,
  SUM(rebate)/NULLIF(-SUM(game_pnl),0) AS 退水消耗比   -- >1 = 退水吃光赢利
FROM bs WHERE NULLIF(TRIM(lv3),'') IS NOT NULL
GROUP BY lv3 ORDER BY 真实流水 DESC;


/* ═══════════════════════════════════════════════════════════════════════
   S-04 · 风控员评分底料（金标准名单产出者）
   命中率/时效由 Python 侧对回 N1/N1b 结果计算；导出 数据库/S04_analyst_score.csv
   ▸ 导出：**数据库/S04_analyst_score.csv**
   ▸ 用途：★ 风控员评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
/* ✅ 字段已实测确认（2026-08-06 全表 17 行到手）：
     ip=IP地址  creator=标注人  addtime=标注时间  remarks=备注(判定理由)
   注意：全表仅 17 行，直接 SELECT * 导出即可，聚合反而丢失 IP 与备注原文。 */

/* ── S-04a · 全表导出（推荐，17 行一次到位）─────────────────────────
   ▸ 导出：**数据库/S04_analyst_score.csv**                              */
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
   ▸ 导出：**数据库/S05_member_month_panel.csv**
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
   ▸ 导出：**数据库/I_ip_agg.csv**
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
   ▸ 导出：**数据库/X_combo.csv**
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
   ▸ 导出：**数据库/P_player_month.csv**
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
   ▸ 导出：**数据库/B_online_base.csv**
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
   ▸ 导出：**数据库/A_anchor.csv**
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
   ▸ 导出：**数据库/V_ipmatch.csv**
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
