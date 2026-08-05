-- ============================================================================
-- 验证：ods_a168_aggregate_transaction 能否补上真实盈亏字段
-- ============================================================================
-- 背景：本表在"数据字典审核报告.csv"里读取状态是"失败: 不能用零长度变量名"，
-- 从未被纳入报告第二章第八节的13项候选测试——它不是被证伪，是从没被测过。
--
-- 字段字典(glimpse.ods_a168_aggregate_transaction.csv)明确写着：
--   money  = "處理金額 (有正負值)"   ← 这正是bet41被证伪时缺的那个条件
--   mid    = "會員 mid"              ← 自带会员ID，理论上比wallet_dtl.user
--                                       (字符串，跟bet05桥接失败率99.34%)
--                                       更有希望桥接成功，因为mid是数值型
--
-- 本脚本只做验证，不产出任何分级或对外结论。三步都跑完、结果都符合预期，
-- 才建议正式纳入下面的《会员终身价值分级.sql》。
-- ============================================================================

-- 第一步｜基本体检：这张表实际有没有数据、正负值分布如何
SELECT
    COUNT(*)                                       AS 总行数,
    COUNT(DISTINCT mid)                            AS 去重会员数,
    MIN(dt)                                        AS 最早日期,
    MAX(dt)                                        AS 最晚日期,
    SUM(CASE WHEN money > 0 THEN 1 ELSE 0 END)     AS 正值笔数,
    SUM(CASE WHEN money < 0 THEN 1 ELSE 0 END)     AS 负值笔数,
    SUM(CASE WHEN money = 0 THEN 1 ELSE 0 END)     AS 零值笔数,
    MIN(money)                                     AS 最小值,
    MAX(money)                                     AS 最大值
FROM ods_mariadb_2b.ods_a168_aggregate_transaction
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24';
-- 判断标准：正值笔数、负值笔数必须都明显大于0——这是"是否为真盈亏字段"
-- 的第一道关卡，跟报告验证bet41时用的是同一套逻辑(bet41全零负数所以出局)。
-- 如果本查询直接报错或行数为0，说明"零长度变量名"这个读取问题在StarRocks
-- 在线库里同样存在，需要先请工程side排查该表的列定义，再谈是否能用。

-- 第二步｜按type拆开，确认"0:电子游戏结算"是否是money字段有意义的主体
SELECT
    `type`,
    COUNT(*)                                       AS 笔数,
    SUM(CASE WHEN money > 0 THEN 1 ELSE 0 END)     AS 正值笔数,
    SUM(CASE WHEN money < 0 THEN 1 ELSE 0 END)     AS 负值笔数,
    ROUND(AVG(money), 2)                           AS 平均金额
FROM ods_mariadb_2b.ods_a168_aggregate_transaction
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
GROUP BY `type`
ORDER BY 笔数 DESC;
-- 留意：如果正负值笔数集中在某个特定type(比如"0:电子游戏结算")而其它
-- type全是单一符号，说明这张表可能只覆盖电子游戏结算，不覆盖真人视讯桌台——
-- 那它能补的是"电子游戏这部分会员"的盈亏，团伙同桌/策略性投注那批真人视讯
-- 候选人如果不玩电子游戏，可能查不到对应记录，覆盖面需要另外核实。

-- 第三步｜桥接测试：mid 能不能对上 bet01.bet05（决定这条路走不走得通的关键）
-- 复用报告验证wallet_dtl↔bet05桥接率(0.66%)时的同一套计算方法
WITH mid去重 AS (
    SELECT DISTINCT mid AS uid
    FROM ods_mariadb_2b.ods_a168_aggregate_transaction
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
),
bet05去重 AS (
    SELECT DISTINCT bet05 AS uid
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
)
SELECT
    (SELECT COUNT(*) FROM mid去重)                                    AS aggregate_transaction会员数,
    (SELECT COUNT(*) FROM bet05去重)                                  AS bet01会员数,
    (SELECT COUNT(*) FROM mid去重 m JOIN bet05去重 b ON m.uid = b.uid) AS 可桥接会员数,
    ROUND(
        (SELECT COUNT(*) FROM mid去重 m JOIN bet05去重 b ON m.uid = b.uid) * 100.0
        / NULLIF((SELECT COUNT(*) FROM mid去重), 0), 2
    )                                                                  AS 桥接匹配率百分比
;
-- 参照物：wallet_dtl↔bet05的桥接匹配率是0.66%(报告2.8节实测证伪)。
-- 如果这里明显更高(哪怕只到30~50%)，就是实质性突破，值得正式立项；
-- 如果同样是个位数，说明又是一条死胡同——但排查成本只有这三条查询，很低。
