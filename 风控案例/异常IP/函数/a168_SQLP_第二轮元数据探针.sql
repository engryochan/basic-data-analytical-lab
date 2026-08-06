/* ============================================================================
   a168 ｜ SQL-P 第二轮元数据探针
   已确认：两段式寻址成立，表名前缀 ods_a168_
           ods_mariadb_2b.ods_a168_bet01  (190,406,429)
           ods_mariadb_2b.ods_a168_bet02  (190,212,574)
           ods_mariadb_2b.ods_a168_member ( 58,498,874) ← 铁律⑤的 5849 万账户
   本轮目标：① 全表清单 ② 核心表列定义 ③ 风控层 wm_risk/wm_live_risk 用途判定
   执行：Superset SQL Lab，逐条提交
   ============================================================================ */


/* --------------------------------------------------------------------------
   P1 ｜ ods_mariadb_2b 全表清单（含小表，规则结果表可能藏在这里）
   -------------------------------------------------------------------------- */
SELECT TABLE_NAME, TABLE_ROWS, TABLE_TYPE
FROM information_schema.tables
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY TABLE_ROWS DESC;
/* ★ 整表导出。重点找：
     dailyreport_member 的真实名（预期 ods_a168_dailyreport_member）
     lacc06 的真实名
     五张 tmp_rule_* 是否已落库                                      */


/* --------------------------------------------------------------------------
   P2 ｜ 核心八表列定义（本轮最重要，直接决定 cfg$col 七个槽位）
   -------------------------------------------------------------------------- */
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME,
       DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME IN (
      'ods_a168_bet01',
      'ods_a168_bet02',
      'ods_a168_member',
      'ods_a168_member_dtl',
      'ods_a168_log_age_cash_change',
      'ods_a168_in_out_m',
      'ods_a168_wallet_dtl',
      'ods_a168_mem_login')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
/* ★ 整表导出。若 COLUMN_COMMENT 有中文，M1–M7 当场落定。 */


/* --------------------------------------------------------------------------
   P3 ｜ 风控层用途判定（wm_risk / wm_live_risk）
   —— player_pair_stat_hourly 若含 player_a / player_b，即现成共现边表
   -------------------------------------------------------------------------- */
SELECT TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME,
       DATA_TYPE, COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA IN ('wm_risk', 'wm_live_risk')
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
/* ★ 整表导出。这一层若可用，同桌合谋规则可从"重算"降级为"直读"，
   算力与工期都大幅节省。                                            */


/* --------------------------------------------------------------------------
   P4 ｜ 锚点与资金表定位（dailyreport / risk / lacc）
   -------------------------------------------------------------------------- */
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS
FROM information_schema.tables
WHERE LOWER(TABLE_NAME) LIKE '%dailyreport%'
   OR LOWER(TABLE_NAME) LIKE '%risklist%'
   OR LOWER(TABLE_NAME) LIKE '%lacc%'
   OR LOWER(TABLE_NAME) LIKE '%rule%'
   OR LOWER(TABLE_NAME) LIKE '%tmp_%'
ORDER BY TABLE_SCHEMA, TABLE_NAME;


/* --------------------------------------------------------------------------
   P5 ｜ 建表语句：确认分区列（决定所有查询能否分区裁剪）
   -------------------------------------------------------------------------- */
SHOW CREATE TABLE ods_mariadb_2b.ods_a168_bet02;
-- SHOW CREATE TABLE ods_mariadb_2b.ods_a168_bet01;
-- SHOW CREATE TABLE ods_mariadb_2b.ods_a168_member_dtl;
/* ★ 输出文本上载。PARTITION BY 用的那一列即 M2（下注时间）；
   1.9 亿行不做分区裁剪必然超时。                                    */


/* --------------------------------------------------------------------------
   P6 ｜ 形态探针（表名已确认，这条现在可以跑了）
   -------------------------------------------------------------------------- */
WITH s AS (
  SELECT * FROM ods_mariadb_2b.ods_a168_bet02 LIMIT 50000
)
SELECT COUNT(*) AS n_rows,
       NDV(bet04) AS ndv_bet04, NDV(bet05) AS ndv_bet05,
       NDV(bet06) AS ndv_bet06, NDV(bet07) AS ndv_bet07,
       NDV(bet08) AS ndv_bet08, NDV(bet09) AS ndv_bet09,
       NDV(bet10) AS ndv_bet10, NDV(bet12) AS ndv_bet12,
       MIN(bet05) AS min_bet05, MAX(bet05) AS max_bet05,
       MIN(bet06) AS min_bet06, MAX(bet06) AS max_bet06
FROM s;
/* 注意：这里刻意不加 WHERE，因为列名尚未确认，
   过滤条件写错会掩盖真实形态。先看形态，再谈过滤。 */


/* --------------------------------------------------------------------------
   P7 ｜ 脱敏样本（PII 请自行遮蔽后再上载）
   -------------------------------------------------------------------------- */
SELECT * FROM ods_mariadb_2b.ods_a168_bet02 LIMIT 20;
-- SELECT * FROM ods_mariadb_2b.ods_a168_bet01 LIMIT 20;
-- SELECT * FROM wm_risk.player_pair_stat_hourly LIMIT 20;
-- SELECT * FROM ods_mariadb_2b.ods_a168_log_age_cash_change LIMIT 20;
