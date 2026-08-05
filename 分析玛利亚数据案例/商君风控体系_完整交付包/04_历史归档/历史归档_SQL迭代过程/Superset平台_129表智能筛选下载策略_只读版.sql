-- ==============================================================================
-- Superset平台_129表智能筛选下载策略_只读版.sql
-- ==============================================================================
-- 【为什么上一版会报错，这次怎么改】
-- 上一版用了 CREATE TABLE 候选名单_xxx AS SELECT ... 这种写法——
-- CREATE TABLE 属于DDL(数据定义语言)，Superset的SQL Lab出于安全考虑，
-- 默认给大多数数据库连线设成"只读"模式，不允许DDL/DML(增删改)操作，
-- 只允许SELECT查询。这不是权限不够或者账号问题，是企业级BI平台的
-- 标准安全策略——不让分析师能在查询界面里意外改写生产库的数据结构。
--
-- 解法：把"候选名单"从"建一张实体表"改成"用WITH子句(CTE, Common Table
-- Expression)包在同一条SELECT语句里"——CTE只是给一段子查询起个临时
-- 名字，方便在同一条语句里复用，执行完就自动释放，不会在数据库里留下
-- 任何新表，本质上还是一条SELECT语句，不会撞上DDL/DML限制。
--
-- 唯一的代价：CTE的"候选名单"部分是查询级别的临时结果，没法跨语句复用，
-- 所以下面每一条"提取数据"的SELECT语句，都要把候选名单的CTE重新写一遍
-- (直接复制粘贴即可)。每条语句都是完整独立、可以单独在Superset SQL Lab
-- 里粘贴执行的。
-- ==============================================================================


-- ██████████████████████████████████████████████████████████████████████████
-- 查询0：先确认候选名单规模合不合理，跑这条看眼数字，别一上来就下载
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    -- 来源①：投注行为异常——订单数够多(>50，先放宽阈值广撒网)，
    -- 且要么总投注额很高、要么"第50把及以后才下注"的比例偏高(潜在算牌)
    SELECT bet05 AS uid
    FROM ods_a168_bet01
    GROUP BY bet05
    HAVING COUNT(*) > 50
       AND (
            SUM(bet12) > 100000                                          -- bet12是真实投注额字段，不是bet13(那是有效投注)
            OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50
           )
),
候选_同桌异常 AS (
    -- 来源②：同桌率异常——同一局(bet03)里，两个不同会员反复同时出现，
    -- 超过50局就先纳入候选(最终判定阈值留到本地精筛时再收紧)
    SELECT DISTINCT a.bet05 AS uid
    FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05                        -- 同一局、不同会员
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS (
    -- 来源③：系统自带的风险名单，已验证真实存在(9,958行)，全部纳入候选
    SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist
),
候选_荷官关联 AS (
    -- 来源④：跟同一个荷官高频往来的会员，用于后续"荷官作弊"分析的候选池
    SELECT DISTINCT bet05 AS uid
    FROM ods_a168_bet01
    GROUP BY eid, bet05
    HAVING COUNT(*) > 50
),
候选_最终 AS (
    -- 四路来源合并去重，这就是后面所有提取查询要复用的"共同锚点"
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
-- 【怎么用这条结果】如果"最终去重候选总数"超过5万，建议把上面几段HAVING
-- 里的阈值适当收紧(比如50改成100)，重新跑一遍这条查询，直到候选总数落在
-- 一个下载/后续分析都轻松可控的规模(比如几千到2万人)再往下走。


-- ██████████████████████████████████████████████████████████████████████████
-- 查询1：提取 bet01（真人桌台投注，核心分析对象）——独立完整、可单独执行
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_bet01
WHERE bet05 IN (SELECT uid FROM 候选_最终)
LIMIT 100000;                                                             -- 若候选名单人数够多、这张表超过10万行，
                                                                            -- 加一句 AND dt BETWEEN '起始日期' AND '结束日期'
                                                                            -- 按月/按周分批多次下载


-- ██████████████████████████████████████████████████████████████████████████
-- 查询2：提取 bet02（电子游戏投注）——复制查询1的候选CTE，只改最后的表名
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_bet02
WHERE bet05 IN (SELECT uid FROM 候选_最终)
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询3：提取 in_out_m（存提款记录）——注意会员字段叫iom003，不是bet05
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_in_out_m
WHERE iom003 IN (SELECT uid FROM 候选_最终)
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询4：提取 dailyreport_member（会员日报，含系统自带risk标签）
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_dailyreport_member
WHERE bet05 IN (SELECT uid FROM 候选_最终)
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询5：提取 game_log（IP/设备特征，网络环境安全维度）——字段叫mid
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_game_log
WHERE mid IN (SELECT uid FROM 候选_最终)
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询6：提取 betchange_log（投注修改记录）——字段叫old_bet05
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_betchange_log
WHERE old_bet05 IN (SELECT uid FROM 候选_最终)
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询7：提取 member（会员主档）——⚠️ 这次务必用候选名单过滤，
-- 不要再用"按ID/时间顺序LIMIT"独立导出，那是上一版对不上号的根源
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_投注异常 AS (
    SELECT bet05 AS uid FROM ods_a168_bet01 GROUP BY bet05
    HAVING COUNT(*) > 50 AND (SUM(bet12) > 100000 OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50)
),
候选_同桌异常 AS (
    SELECT DISTINCT a.bet05 AS uid FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 <> b.bet05
    GROUP BY a.bet05, b.bet05 HAVING COUNT(DISTINCT a.bet03) > 50
),
候选_系统标记 AS ( SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist ),
候选_荷官关联 AS (
    SELECT DISTINCT bet05 AS uid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
),
候选_最终 AS (
    SELECT uid FROM 候选_投注异常
    UNION SELECT uid FROM 候选_同桌异常
    UNION SELECT uid FROM 候选_系统标记
    UNION SELECT uid FROM 候选_荷官关联
)
SELECT * FROM ods_a168_member
WHERE mem001 IN (SELECT uid FROM 候选_最终);
-- 候选名单人数通常远小于10万，这张表大概率不需要再加LIMIT


-- ██████████████████████████████████████████████████████████████████████████
-- 查询8：荷官维度日报 dailyreport_table——这张表粒度是"荷官/桌台"不是
-- "会员"，过滤条件改用荷官id，不用会员候选名单
-- ██████████████████████████████████████████████████████████████████████████
WITH 候选_荷官 AS (
    SELECT DISTINCT eid FROM ods_a168_bet01 GROUP BY eid, bet05 HAVING COUNT(*) > 50
)
SELECT * FROM ods_a168_dailyreport_table
WHERE eid IN (SELECT eid FROM 候选_荷官)
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询9：wallet_dtl（钱包变动明细，116,363行，本轮新发现的重要资金表）
-- ⚠️ 这张表会员字段是字符串"user"，跟数值型bet05还没验证映射关系，
-- 暂时不能用候选名单过滤，先按时间倒序取最新一批做初步观察
-- ██████████████████████████████████████████████████████████████████████████
SELECT * FROM ods_a168_wallet_dtl
ORDER BY requestDate DESC
LIMIT 100000;


-- ██████████████████████████████████████████████████████████████████████████
-- 查询10~14：小体量参考表，全量导出，不用候选名单过滤(过滤反而会漏掉
-- 宝贵的对照组信息，比如白名单本该是"正常人"样本，不该被高风险逻辑筛掉)
-- ██████████████████████████████████████████████████████████████████████████
SELECT * FROM ods_a168_risklist;          -- 9,958行，系统真实风险名单
SELECT * FROM ods_a168_white_list;        -- 6,768行，白名单，降低误判用的对照组
SELECT * FROM ods_a168_ipblacklist;       -- 366行，IP黑名单
SELECT * FROM ods_a168_alert_ip_setting;  -- 17行，告警IP设置
SELECT * FROM ods_a168_agent;             -- 代理商账号体系


-- ==============================================================================
-- 【如果贵司的Superset账号确实需要DDL权限(比如后续想真的建中间表用来
-- 加速重复查询)，正规做法是联系数据库管理员，申请单独开一个"分析专用
-- schema"的建表权限，而不是绕开只读限制——这条限制本身是好的安全设计，
-- 不建议想办法规避，上面这套CTE写法已经能在完全不需要额外权限的情况下
-- 达到同样的效果。】
-- ==============================================================================
