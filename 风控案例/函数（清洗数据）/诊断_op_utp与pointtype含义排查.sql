SET query_timeout = 1800;

-- ---- 诊断18：op_utp的完整取值分布(之前样本大多是空白，看全量分布) ----
SELECT op_utp, COUNT(*) AS 出现次数
FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt = '2026-07-24'
GROUP BY op_utp
ORDER BY 出现次数 DESC
LIMIT 30;


-- ---- 诊断19：pointtype的完整取值分布 ----
SELECT pointtype, COUNT(*) AS 出现次数
FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt = '2026-07-24'
GROUP BY pointtype
ORDER BY 出现次数 DESC
LIMIT 30;


-- ---- 诊断20：129张表里有没有专门的字典/编码对照表(表名含dict/type/
-- config/字典这类字样) ----
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'ods_mariadb_2b'
  AND (LOWER(table_name) LIKE '%dict%'
    OR LOWER(table_name) LIKE '%type%'
    OR LOWER(table_name) LIKE '%config%'
    OR LOWER(table_name) LIKE '%code%'
    OR LOWER(table_name) LIKE '%point%')
ORDER BY table_name;
