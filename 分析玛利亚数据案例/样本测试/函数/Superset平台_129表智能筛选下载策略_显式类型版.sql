-- ==============================================================================
-- Superset平台_129表智能筛选下载策略_显式类型版.sql
-- ==============================================================================
-- 【这次改了什么，为什么改】
-- 实测确认：ods_a168_bet01全部49个字段在StarRocks里都是varchar类型
-- (文本)，包括bet05/bet12/bet04/eid这些我们一直当数字用的字段——这是
-- ODS层原始整批灌入、没有做类型转换的缘故。
--
-- 之前的SQL直接写 bet04 >= 50、SUM(bet12) 这类操作，等于要求数据库
-- 引擎自动把文本"50"转成数字50再比较——这叫"隐式类型转换"，不同数据库
-- 引擎、不同版本，对隐式转换的支持程度不一致，很容易在这种场景下出
-- 各种报错或者算出错误结果(比如文本按字典序比较，"9" > "10"这种荒谬
-- 结果)。
--
-- 这次全部改成显式 CAST(字段 AS 类型)，不管数据库引擎认不认隐式转换，
-- 显式转换永远是最保险的写法。
-- ==============================================================================


-- ██████████████████████████████████████████████████████████████████████████
-- 查询0：确认候选名单规模——先跑这条，看输出是否正常，再往下走
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT CAST(bet05 AS BIGINT) AS uid                                  -- 显式把文本转成整数，不再依赖隐式转换
    FROM ods_a168_bet01
    GROUP BY CAST(bet05 AS BIGINT)
    HAVING COUNT(*) > 50
       AND (
            SUM(CAST(bet12 AS DOUBLE)) > 100000                          -- bet12是金额，转成DOUBLE(浮点数)而不是整数
            OR AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50
           )
),
候选_同桌异常 AS (
    SELECT DISTINCT CAST(a.bet05 AS BIGINT) AS uid
    FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b
      ON a.bet03 = b.bet03                                               -- bet03(局/靴id)本身不参与数值运算，
                                                                            -- 保持文本比较即可，两边类型一致就不会报错
     AND a.bet05 <> b.bet05                                              -- 同理，纯粹判断"是否相同文本"，不需要转数字
    GROUP BY a.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid FROM ods_a168_risklist
    -- 注：若risklist表实测也是varchar字段，且字段名不是bet05，
    -- 请先对risklist单独跑一次DESCRIBE确认，这里先按同样假设处理
),
候选_荷官关联 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid
    FROM ods_a168_bet01
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT
    (SELECT COUNT(*) FROM 候选_投注异常) AS 投注异常候选数,
    (SELECT COUNT(*) FROM 候选_同桌异常) AS 同桌异常候选数,
    (SELECT COUNT(*) FROM 候选_系统标记) AS 系统标记候选数,
    (SELECT COUNT(*) FROM 候选_荷官关联) AS 荷官关联候选数,
    (SELECT COUNT(*) FROM 候选_最终)     AS 最终去重候选总数;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询1：提取 bet01——候选名单同样显式转型，最后WHERE条件里两边类型要对齐
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT CAST(bet05 AS BIGINT) AS uid FROM ods_a168_bet01
    GROUP BY CAST(bet05 AS BIGINT)
    HAVING COUNT(*) > 50
       AND (SUM(CAST(bet12 AS DOUBLE)) > 100000
            OR AVG(CASE WHEN CAST(bet04 AS INT) >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT CAST(a.bet05 AS BIGINT) AS uid
    FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT CAST(bet05 AS BIGINT) AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_bet01
WHERE CAST(bet05 AS BIGINT) IN (SELECT uid FROM 候选_最终)                -- 左右两边都显式转成BIGINT再比较，
                                                                            -- 不留给数据库引擎自己猜类型
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询2~9：把查询1的候选CTE整段复制过来，只改最后SELECT ... FROM 那两行，
-- 并根据每张表的真实字段类型加上对应CAST——⚠️ 每张表建议先单独跑一次
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_schema='ods_mariadb_2b' AND table_name='目标表名';
-- 确认该表字段是否也全是varchar，不要直接假设跟bet01一样
-- ██████████████████████████████████████████████████████████████████████████

-- 示例：in_out_m（先确认iom003字段类型，若也是varchar，同样要CAST）
-- WHERE CAST(iom003 AS BIGINT) IN (SELECT uid FROM 候选_最终)


-- ==============================================================================
-- 【下一步请做的事，帮我精确定位报错】
-- 请把触发"Column 'bet05' cannot be resolved"这条报错的完整SQL语句复制
-- 给我——如果是本次显式CAST版本里的某一条还报同样的错，大概率不是类型
-- 问题，而是StarRocks这个版本对CTE(WITH子句)本身的支持有限制，需要换成
-- 子查询(subquery)写法而不是CTE，我会针对具体报错的那一条再单独改写，
-- 不再大范围重写整份文件。
-- ==============================================================================
