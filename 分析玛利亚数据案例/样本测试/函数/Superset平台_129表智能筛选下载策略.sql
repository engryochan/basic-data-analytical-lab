-- ==============================================================================
-- Superset平台_129表智能筛选下载策略.sql
-- ==============================================================================
-- 【核心设计原则——先讲清楚"为什么这样设计"，再看具体SQL】
--
-- 上一版数据包踩过的坑：member.csv按ID顺序LIMIT导出，抓到的是2017-2021年
-- 的老会员；bet01/in_out_m等表按时间倒序LIMIT导出，抓到的是2026年的活跃
-- 会员——两批人根本不是同一群人，交集不到1%。这不是字段名对不上的问题，
-- 是"每张表各自独立抓取，没有共同锚点"导致的系统性错位。
--
-- 这次的解法：分两步走，用同一批"高风险候选会员名单"当所有表的共同锚点。
--
--   第一步：先在Superset上对全量3-5亿行数据跑几条"聚合查询"（GROUP BY+
--           HAVING，不是逐行导出，聚合查询即使在5亿行规模下也是数据库
--           引擎最擅长的操作，不会像逐行导出那样受10万行限制），锁定出
--           一批"最高概率涉及舞弊"的候选会员ID清单——这份清单本身可能
--           只有几千到几万个ID，体积很小，全量下载没有压力。
--
--   第二步：拿这份候选名单，对每一张关键表执行 WHERE bet05 IN (候选名单)
--           这样的过滤条件去抽取数据——因为所有表都用同一份候选名单去抽，
--           抽出来的这批人在各表里天然就是同一群人，不会重演"表与表
--           对不上"的问题。每张表的行数只要不超过10万都可以一次性
--           下载，超过的话可以按时间分批（比如按月/按周），分批各自
--           不超过10万行地下载。
-- ==============================================================================


-- ██████████████████████████████████████████████████████████████████████████
-- 第一步：先锁定"高风险候选会员名单"——只做聚合查询，不导出明细行
-- ██████████████████████████████████████████████████████████████████████████

-- ---- 候选来源①：投注行为异常(策略性投注 + 高流水) ----
CREATE TABLE 候选名单_投注异常 AS
SELECT
    bet05 AS uid,
    COUNT(*) AS 订单数,                                          -- 总订单量，用来过滤掉订单太少、统计上不可靠的账号
    SUM(bet12) AS 总投注额,                                      -- 用真实的"投注额"字段(bet12)，不是bet13(那是有效投注)
    AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) AS 晚注比例  -- 呼应上一轮"策略性风控"需求的晚注比例指标
FROM ods_a168_bet01
GROUP BY bet05
HAVING COUNT(*) > 50                                            -- 订单数下限先放宽到50(而不是100)，
                                                                  -- 因为这一步是"广撒网"锁定候选，不是最终判定，
                                                                  -- 后续可以在候选名单里再做二次精筛
   AND (
        SUM(bet12) > 100000                                     -- 高投注额账号(潜在高价值/潜在洗流水)
        OR AVG(CASE WHEN bet04 >= 50 THEN 1.0 ELSE 0.0 END) >= 0.50  -- 或晚注比例偏高(潜在算牌)
       );

-- ---- 候选来源②：同桌率异常(潜在团伙) ----
-- 这一步复用上一轮已经验证过的自连接逻辑，但这里只取"人"，不取明细
CREATE TABLE 候选名单_同桌异常 AS
SELECT DISTINCT uid1 AS uid FROM (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 < b.bet05
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50                          -- 同样先放宽阈值做候选广撒网
) t
UNION
SELECT DISTINCT uid2 AS uid FROM (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_a168_bet01 a
    JOIN ods_a168_bet01 b ON a.bet03 = b.bet03 AND a.bet05 < b.bet05
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) > 50
) t;

-- ---- 候选来源③：系统自带的风险名单(已验证真实存在，非空表，9,958行) ----
-- 这张表本身就是业务方已经标记过的风险账号，理论上应该优先全量纳入候选
CREATE TABLE 候选名单_系统标记 AS
SELECT DISTINCT bet05 AS uid FROM ods_a168_risklist;
-- 注：ods_a168_risklist的会员字段实际列名请以贵司glimpse元数据表核实为准，
-- 这里用bet05占位，跟其余表保持字段命名一致的假设

-- ---- 候选来源④：荷官维度关联(用于第三部分"荷官作弊"分析的候选桌台/荷官) ----
CREATE TABLE 候选名单_荷官关联 AS
SELECT DISTINCT eid AS 荷官id, bet05 AS uid
FROM ods_a168_bet01
GROUP BY eid, bet05
HAVING COUNT(*) > 50;                                            -- 该荷官经手该会员订单数超过50才纳入候选

-- ---- 合并四路候选来源，去重成一份权威候选名单 ----
CREATE TABLE 候选名单_最终 AS
SELECT DISTINCT uid FROM (
    SELECT uid FROM 候选名单_投注异常
    UNION SELECT uid FROM 候选名单_同桌异常
    UNION SELECT uid FROM 候选名单_系统标记
    UNION SELECT uid FROM 候选名单_荷官关联
) t;

-- 建议：这份候选名单本身应该只有几千到几万行，体积很小，
-- 先 SELECT COUNT(*) FROM 候选名单_最终 看一眼实际有多少人，
-- 如果数量还是过大(比如超过5万)，可以在上面几段HAVING里适当收紧阈值。


-- ██████████████████████████████████████████████████████████████████████████
-- 第二步：用同一份候选名单，对各关键表做定向抽取——每张表天然覆盖同一批人
-- ██████████████████████████████████████████████████████████████████████████

-- 【优先级排序说明】下面按"这次分类审核+两轮实测验证过的重要程度"从高到
-- 低排列，如果精力有限，优先做前几张，后面的可以缓一缓再补。

-- 优先级1：bet01（真人桌台投注，核心分析对象，本报告一直围绕它展开）
SELECT * FROM ods_a168_bet01
WHERE bet05 IN (SELECT uid FROM 候选名单_最终)
LIMIT 100000;                                                     -- 若候选名单人数够多、单表超过10万行，
                                                                   -- 按 dt 字段分批下载，比如按月切片多次执行

-- 优先级2：bet02（电子游戏投注，与bet01同结构不同游戏品类）
SELECT * FROM ods_a168_bet02
WHERE bet05 IN (SELECT uid FROM 候选名单_最终)
LIMIT 100000;

-- 优先级3：in_out_m（存提款记录，流水倍数指标的数据来源）
SELECT * FROM ods_a168_in_out_m
WHERE iom003 IN (SELECT uid FROM 候选名单_最终)                   -- 注意这张表的会员字段叫iom003，不是bet05
LIMIT 100000;

-- 优先级4：wallet_dtl（钱包变动明细，116,363行规模，本轮新发现的重要资金表）
-- 注意：这张表的会员字段是字符串型的"user"（如"172wm282250164"），
-- 不是数值型bet05，目前还没有验证过的映射关系——建议先小批量导出
-- 观察user字段的编码规律，而不是直接假设能用IN条件对上候选名单
SELECT * FROM ods_a168_wallet_dtl
ORDER BY requestDate DESC
LIMIT 100000;                                                     -- 暂时按时间倒序取最新一批，
                                                                   -- 待user字段映射关系确认后再改成候选名单过滤

-- 优先级5：dailyreport_member（会员日报，含系统自带risk标签这个关键发现）
SELECT * FROM ods_a168_dailyreport_member
WHERE bet05 IN (SELECT uid FROM 候选名单_最终)
LIMIT 100000;

-- 优先级6：game_log（含IP/设备特征，网络环境安全维度的数据来源）
SELECT * FROM ods_a168_game_log
WHERE mid IN (SELECT uid FROM 候选名单_最终)
LIMIT 100000;

-- 优先级7：dailyreport_table（荷官/桌台维度日报，100,000行，本轮新发现，
-- 荷官分析的重要补充源——这张表的粒度是"桌台/荷官"不是"会员"，
-- 用荷官id过滤，不用会员候选名单过滤）
SELECT * FROM ods_a168_dailyreport_table
WHERE eid IN (SELECT DISTINCT 荷官id FROM 候选名单_荷官关联)
LIMIT 100000;

-- 优先级8：betchange_log（投注修改记录，用于识别投注篡改行为）
SELECT * FROM ods_a168_betchange_log
WHERE old_bet05 IN (SELECT uid FROM 候选名单_最终)
LIMIT 100000;

-- 优先级9：member（会员主档——⚠️ 这次务必用候选名单过滤，不要再用
-- "按ID/时间顺序LIMIT"这种独立导出方式，那正是上一轮"member表跟其余
-- 表对不上"这个问题的根源）
SELECT * FROM ods_a168_member
WHERE mem001 IN (SELECT uid FROM 候选名单_最终);
-- 注：候选名单人数通常远小于10万，这张表大概率不需要再加LIMIT，
-- 直接全量导出候选名单对应的会员档案即可


-- ██████████████████████████████████████████████████████████████████████████
-- 第三步：以下这几张小体量参考表，本身就在10万行以内，建议直接全量导出，
-- 不需要用候选名单过滤（过滤反而可能漏掉有价值的对照组信息）
-- ██████████████████████████████████████████████████████████████████████████
SELECT * FROM ods_a168_risklist;          -- 9,958行，系统真实风险名单，全量导出
SELECT * FROM ods_a168_white_list;        -- 6,768行，白名单，用于降低误判的对照组
SELECT * FROM ods_a168_ipblacklist;       -- 366行，IP黑名单
SELECT * FROM ods_a168_alert_ip_setting;  -- 17行，告警IP设置
SELECT * FROM ods_a168_agent;             -- 代理商账号体系，通常量级不大，全量导出


-- ██████████████████████████████████████████████████████████████████████████
-- 附：确认候选名单规模是否合理的检查SQL——下载前先跑一下心里有数
-- ██████████████████████████████████████████████████████████████████████████
SELECT
    (SELECT COUNT(*) FROM 候选名单_投注异常) AS 投注异常候选数,
    (SELECT COUNT(*) FROM 候选名单_同桌异常) AS 同桌异常候选数,
    (SELECT COUNT(*) FROM 候选名单_系统标记) AS 系统标记候选数,
    (SELECT COUNT(DISTINCT uid) FROM 候选名单_荷官关联) AS 荷官关联候选数,
    (SELECT COUNT(*) FROM 候选名单_最终) AS 最终去重候选总数;
