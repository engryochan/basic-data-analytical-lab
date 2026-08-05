SET query_timeout = 1800;

-- ---- 诊断16(修正版)：换成真实活跃会员(105410288，来自双重命中名单，
-- 已验证是正常活跃玩家，非异常测试账号)，重新验证lacc03能否查到
-- 具体资金变动记录 ----
SELECT dt, lacc03, lacc06, lacc07, lacc09, lacc10, lacc11
FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt = '2026-07-24' AND lacc03 = '105410288'
ORDER BY lacc07
LIMIT 20;


-- ---- 诊断17：如果上面还是查不到，扩大到全部126天范围，再用另外
-- 三个双重命中名单里的会员做交叉测试，一次测4个人，看命中率 ----
SELECT lacc03, COUNT(*) AS 记录笔数,
       SUM(CASE WHEN CAST(lacc06 AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS 负数次数,
       SUM(CASE WHEN CAST(lacc06 AS DOUBLE) > 0 THEN 1 ELSE 0 END) AS 正数次数,
       SUM(CAST(lacc06 AS DOUBLE)) AS 净变动合计
FROM ods_mariadb_2b.ods_a168_log_age_cash_change
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
  AND lacc03 IN ('105410288', '142282770', '110487696', '125106826')
GROUP BY lacc03;
