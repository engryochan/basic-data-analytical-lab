SET query_timeout = 1800;

-- ---- 诊断4：抽10笔在两表都出现的真实交易，把bet01和bet02的全部字段
-- 并排对比——重点看bet02有没有bet01不存在的字段、或者同名字段数值
-- 不一样(暗示bet02记录的是"结算后"的状态，bet01是"下注时"的状态) ----
WITH 共同交易 AS (
    SELECT DISTINCT a.bet01 AS 交易id
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet02 b ON a.bet01 = b.bet01
    WHERE a.dt = '2026-07-24'
    LIMIT 10
)
SELECT
    a.bet01 AS 交易id,
    a.bet05 AS bet01_会员, b.bet05 AS bet02_会员,
    a.bet12 AS bet01_投注额, b.bet12 AS bet02_投注额,
    a.bet13 AS bet01_有效投注, b.bet13 AS bet02_有效投注,
    a.bet11 AS bet01_赔率, b.bet11 AS bet02_赔率,
    a.bet09 AS bet01_投注选项, b.bet09 AS bet02_投注选项,
    a.bet30 AS bet01_bet30, b.bet30 AS bet02_bet30,
    a.eid AS bet01_荷官, b.eid AS bet02_荷官,
    a.serid AS bet01_serid, b.serid AS bet02_serid,
    a.updatetime AS bet01_更新时间, b.updatetime AS bet02_更新时间
FROM ods_mariadb_2b.ods_a168_bet01 a
JOIN ods_mariadb_2b.ods_a168_bet02 b ON a.bet01 = b.bet01
WHERE a.bet01 IN (SELECT 交易id FROM 共同交易);


-- ---- 诊断5：bet02完整字段清单——之前只草草看过bet02一行样本(electronic
-- game那次)，没有像bet01那样做过完整DESCRIBE，这次正式补上 ----
SELECT column_name, data_type, ordinal_position
FROM information_schema.columns
WHERE table_schema = 'ods_mariadb_2b' AND table_name = 'ods_a168_bet02'
ORDER BY ordinal_position;
