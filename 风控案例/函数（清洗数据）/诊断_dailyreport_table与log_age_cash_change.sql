SET query_timeout = 1800;

-- ---- 诊断10：dailyreport_table 完整字段清单(此前从未DESCRIBE过) ----
SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ods_mariadb_2b' AND table_name = 'ods_a168_dailyreport_table'
ORDER BY ordinal_position;


-- ---- 诊断11：log_age_cash_change 完整字段清单(此前从未DESCRIBE过) ----
SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ods_mariadb_2b' AND table_name = 'ods_a168_log_age_cash_change'
ORDER BY ordinal_position;


-- ---- 诊断12：抽10行dailyreport_table真实样本，看长什么样 ----
SELECT * FROM ods_mariadb_2b.ods_a168_dailyreport_table
WHERE dt = '2026-07-24'
LIMIT 10;


-- ---- 诊断13：抽10行log_age_cash_change真实样本 ----
SELECT * FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt = '2026-07-24'
LIMIT 10;
