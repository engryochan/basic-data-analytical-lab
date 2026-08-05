-- ==============================================================================
-- 诊断_commission与category字段.sql
-- ==============================================================================
-- 目的：bet01里的commission(疑似返水/佣金)和category(疑似投注产品类别)这
-- 两个字段，此前从未实测过真实内容——在往下扩展"投注产品+盈亏+返水"这几
-- 个维度之前，必须先摸清楚这两个字段到底装的是什么，不能直接假设它们就
-- 是"返水"和"产品"，要用真实数据验证，跟这次会话一路的原则一致。
-- ==============================================================================

SET query_timeout = 1800;

-- ---- 诊断1：commission字段的真实取值分布(是不是返水金额，还是别的东西) ----
SELECT
    CAST(commission AS DOUBLE) AS commission值,
    COUNT(*) AS 出现次数
FROM ods_mariadb_2b.ods_a168_bet01
WHERE dt = '2026-07-24'                                    -- 先只看一天，摸底不用扫全量
GROUP BY CAST(commission AS DOUBLE)
ORDER BY 出现次数 DESC
LIMIT 30;


-- ---- 诊断2：category字段的真实取值有哪些(是不是对应产品类别) ----
SELECT
    category,
    gametype,
    COUNT(*) AS 出现次数,
    COUNT(DISTINCT bet02) AS 涉及桌台数
FROM ods_mariadb_2b.ods_a168_bet01
WHERE dt = '2026-07-24'
GROUP BY category, gametype
ORDER BY 出现次数 DESC
LIMIT 30;


-- ---- 诊断3：wallet_reporter(钱包汇总报表)的真实字段结构——这次会话
-- 分类扫描时发现过这张表(10万行)，但从未展开查过具体是什么内容，
-- 有可能是按会员/按天汇总的盈亏报表 ----
SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ods_mariadb_2b' AND table_name = 'ods_a168_wallet_reporter'
ORDER BY ordinal_position;


-- ---- 诊断4：dailyreport_member的完整字段清单——之前只用过risk/count/
-- orders这三个字段，很可能还有别的跟盈亏/产品相关的字段没被发现过 ----
SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ods_mariadb_2b' AND table_name = 'ods_a168_dailyreport_member'
ORDER BY ordinal_position;
