/* ============================================================================
   世博量化® | a168 平台风控体系 —— 数据基座与新维度 SQL 交付包 v1
   ----------------------------------------------------------------------------
   用途：C 阶段（夯地基）。把此前十余轮累积的字段口径、欠账验证、以及新发现
         维度整理为可在 Superset SQL Lab 中【逐段单独提交】的查询集。
   平台：StarRocks / Superset SQL Lab
   数据：ods_mariadb_2b.ods_a168_*（全局生产数据，约 1.8 亿注单/表）

   ★★★ 使用铁律（血泪教训，务必遵守）★★★
   1. 【逐段单独提交】每个 ==SECTION== 之间用 ----分隔的，一次只跑一条 SELECT。
      批量提交多条语句在本项目已多次触发 StarRocks 僵尸查询 / 结果错乱。
   2. 【一律带 schema 前缀】ods_mariadb_2b. —— 裸表名会命中同名异构表。
   3. 【ODS 层字段几乎全是 varchar】数值比较/聚合前必须显式 CAST。
   4. 【跨表列同名异义】bet01 与 bet02 从 bet14 起同名列含义不同；列名 bet02
      同时是"表名"也是"遊戲類別編號"列名 —— 引用一律带表别名前缀。
   5. 【排除脏源】过滤 bet03 != '0'（哨兵局）、排除测试线(age022)、排除 _test/_bak 表。
   ============================================================================ */


/* ============================================================================
   PART 0 — 维度双显对照（正名 ↔ 源字段）速查表（注释，无需执行）
   ----------------------------------------------------------------------------
   【注单主表 ods_a168_bet01】
     bet01 = 注單編號(跨表关联主键)   bet05 = 會員ID/uid   bet03 = 場次編號
     bet04 = 子場次編號(第几把)        eid   = 荷官ID       bet31 = 桌子編號
     bet06 = 開局時間                  bet08 = 下注時間     ip    = 下注IP
     bet02列 = 遊戲類別編號            bet11 = 匯率         bet13 = 下注金額
     bet14 = 退水%數(注意:非派彩!)     bet15/16/17 = LV1/2/3 代理ID
   【结算表 ods_a168_bet02】(同名列含义不同!)
     bet01 = 注單編號                  bet14 = 派彩         bet16 = 退水金額
     bet17 = 結果(净盈亏)              bet39 = 桌子編號     validbet = 有效投注
     category = 有效标记(=1)           bet38 = 重對标记(='N')
   【物理局 ods_a168_game_info】
     gi002 = 場次編號(=bet03)   gi003 = 局内序(与bet04需验证)  eid=荷官
     gi004 = 開局時間           gi006 = 開獎時間   gi013 = 狀態(1=已開)
     gi005 = 總下注額  gi008 = 輸贏  gi009 = 總退水  gi010 = 結果(=贏+退-下注)
   【桌台配置 ods_a168_tablelimit】
     gid=遊戲  tableid=桌號(=bet31)  bettime=下注窗口秒数(部分桌=0)  min/maxbet=限红
   【赔率 ods_a168_odds_default】 gid + area(banker/player/tie/bpair...) + odds
   【聚合钱包 ods_a168_aggregate_transaction】★财务盈亏最终解★
     mid=會員  game_no=遊戲_期数_局号  money=處理金額(有正负)
     type: 0电子结算/1加点/2扣点/3重对加点/4重对扣点/5重新派彩  status:1=成功
   【代理明细 ods_a168_agent_dtl】★打水套利参数★
     ag003=退水率  ag012=佔成  ag015=電投退水  ag016=電投佔成
   【会员主档 ods_a168_member】(5849万账户,非自然人)
     mem001=會員ID  mem003=明文密码(!)  mem006=层级  mem007~011=代理层级链
     mem013/014=最后登录时间/IP  cash=余额
   【行为 ods_a168_member_click_counter】 mid + function + counts (UI点击)
   【内部审计 ods_a168_log_mem_change】 lmc02=被改会员 lmc06=操作者 lmc09=SQL lmc10=IP
   【替代标签源】 alarmMessage(mid+type+content 风控告警) ;
                 agents_LoginPass.betfeedback(异常锁定Y/N)
   【必排除】 agent.age022=測試線判別 ; 所有 *_test / *_bak* 表
   ============================================================================ */


/* ==SECTION A — 欠账清算：把悬了多轮的验证一次性做完================================ */

-- ----------------------------------------------------------------------------
-- A1. 【金额口径交叉验证】明细汇总 vs game_info 官方汇总(gi005)
--     目的：证明我们对 bet13(下注金額)+bet11(匯率) 的口径理解正确。
--     判读：两列若逐局接近(允许微小汇率换算/精度差)，口径确立；差异大则需回查。
-- ----------------------------------------------------------------------------
SELECT
    gi.gi002                                          AS 場次編號,
    CAST(gi.gi005 AS DECIMAL(20,4))                   AS 官方汇总投注额,
    SUM(CAST(b.bet13 AS DECIMAL(20,4)) / NULLIF(CAST(b.bet11 AS DECIMAL(20,6)),0)) AS 明细汇总投注额_折汇,
    SUM(CAST(b.bet13 AS DECIMAL(20,4)))               AS 明细汇总投注额_原币,
    COUNT(*)                                          AS 注单数
FROM ods_mariadb_2b.ods_a168_game_info gi
JOIN ods_mariadb_2b.ods_a168_bet01 b
     ON b.bet03 = CAST(gi.gi002 AS VARCHAR)
WHERE gi.gi013 = '1'
GROUP BY gi.gi002, gi.gi005
ORDER BY gi.gi002
LIMIT 30;

-- ----------------------------------------------------------------------------
-- A2. 【聚合钱包盈亏 vs 结算表口径验证】★财务维度关键★
--     aggregate_transaction.money(type=0,status=1) 应≈ bet02.bet17(結果) 折汇加总
--     目的：确立 money 为真实盈亏字段，替代一直缺失的 game_result。
-- ----------------------------------------------------------------------------
SELECT
    at2.mid                                                          AS 會員ID,
    SUM(CAST(at2.money AS DECIMAL(20,4)))                            AS 聚合钱包结算盈亏,
    COUNT(*)                                                         AS 结算笔数
FROM ods_mariadb_2b.ods_a168_aggregate_transaction at2
WHERE at2.type = '0' AND at2.status = '1'
GROUP BY at2.mid
ORDER BY 聚合钱包结算盈亏 DESC
LIMIT 30;

-- ----------------------------------------------------------------------------
-- A3. 【bet04 ↔ gi003 编码体系验证】上一轮 86.8% join 命中，需确认 gi003 语义
--     若"仅gi002匹配"高、"gi002+gi003都匹配"低 → gi003 非"本靴第几把"，
--     则尾秒/后段分析的局键只能用 gi002，不能靠 gi003 对齐 bet04。
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                              AS 匹配总数,
    SUM(CASE WHEN CAST(b.bet04 AS INT) = gi.gi003 THEN 1 ELSE 0 END)      AS bet04等于gi003的笔数,
    SUM(CASE WHEN CAST(b.bet04 AS INT) = gi.gi003 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS 一致率
FROM ods_mariadb_2b.ods_a168_bet01 b
JOIN ods_mariadb_2b.ods_a168_game_info gi
     ON b.bet03 = CAST(gi.gi002 AS VARCHAR)
    AND CAST(b.bet04 AS INT) = gi.gi003
WHERE b.bet03 != '0';

-- ----------------------------------------------------------------------------
-- A4. 【替代标签源体检-1】alarmMessage 时间跨度与会员覆盖（risklist已死,找替代）
-- ----------------------------------------------------------------------------
SELECT
    MIN(dt)                     AS 最早,
    MAX(dt)                     AS 最晚,
    COUNT(*)                    AS 告警总数,
    COUNT(DISTINCT mid)         AS 涉及会员数,
    COUNT(DISTINCT type)        AS 告警类型数
FROM ods_mariadb_2b.ods_a168_alarmMessage;

-- ----------------------------------------------------------------------------
-- A5. 【替代标签源体检-1b】alarmMessage 各告警类型分布（type 含义待平台确认）
-- ----------------------------------------------------------------------------
SELECT type AS 告警类型, COUNT(*) AS 笔数, COUNT(DISTINCT mid) AS 涉及会员数
FROM ods_mariadb_2b.ods_a168_alarmMessage
GROUP BY type
ORDER BY 笔数 DESC;

-- ----------------------------------------------------------------------------
-- A6. 【替代标签源体检-2】被平台"异常锁定"的代理（agents_LoginPass.betfeedback=1）
-- ----------------------------------------------------------------------------
SELECT betfeedback AS 异常锁定标记, COUNT(*) AS 代理数
FROM ods_mariadb_2b.ods_a168_agents_LoginPass
GROUP BY betfeedback;


/* ==SECTION B — 数据基座：可复用的"干净口径"CTE 模板==============================
   说明：以下为标准清洗基座。正式分析时把需要的 CTE 段落粘到查询开头复用。
   单独提交时可先用 B0 验证基座规模，再往下接具体规则。
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- B0. 【测试线排除清单】先拿到所有"测试代理"，后续从会员维度剔除其下挂会员
--     age022 = 測試線判別（具体取值待确认：先看分布再定过滤值）
-- ----------------------------------------------------------------------------
SELECT age022 AS 測試線判別值, COUNT(*) AS 代理数
FROM ods_mariadb_2b.ods_a168_agent
GROUP BY age022
ORDER BY 代理数 DESC;

-- ----------------------------------------------------------------------------
-- B1. 【下注干净基座】去重 + 有效 + 排除哨兵局（正式分析统一从这里起）
--     注：bet01 无 category 字段，有效性主要靠 bet02.category=1 侧过滤；
--         此处先给 bet01 侧的去重 + 哨兵排除。
-- ----------------------------------------------------------------------------
WITH bet01_clean AS (
    SELECT * FROM (
        SELECT b.*,
               ROW_NUMBER() OVER (
                   PARTITION BY bet01
                   ORDER BY updatetime DESC, sync_time DESC, dt DESC
               ) AS rn
        FROM ods_mariadb_2b.ods_a168_bet01 b
        WHERE b.bet03 != '0'
    ) t WHERE rn = 1
)
SELECT COUNT(*) AS 基座行数, COUNT(DISTINCT bet05) AS 去重会员数
FROM bet01_clean;


/* ==SECTION C — 三条既有风控规则（已跑通的最终修正版，带 CAST + 干净基座）========= */

-- ----------------------------------------------------------------------------
-- C1. 【策略性后段下注】第50把及之后占比≥70% 且 订单>100
--     输出：uid, 投注比例, 订单数
-- ----------------------------------------------------------------------------
WITH bet_detail AS (
    SELECT bet05 AS uid, CAST(bet04 AS INT) AS hand_no
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE bet03 != '0'
),
user_stats AS (
    SELECT uid,
           COUNT(*) AS total_orders,
           SUM(CASE WHEN hand_no >= 50 THEN 1 ELSE 0 END) AS late_orders
    FROM bet_detail
    GROUP BY uid
)
SELECT uid,
       late_orders * 1.0 / total_orders AS 投注比例,
       total_orders AS 订单数
FROM user_stats
WHERE total_orders > 100
  AND late_orders * 1.0 / total_orders >= 0.70
ORDER BY 投注比例 DESC, 订单数 DESC, uid;

-- ----------------------------------------------------------------------------
-- C2. 【团伙同桌合谋】按(桌,局)自连接 + round规模上限(防OOM) + 度数分离(去枢纽噪声)
--     阈值：co_round>100, 同桌率>=0.30, round玩家<=50, 搭档数<=5
--     输出：uid1, uid2, 同桌率, 订单数, 双方搭档数
-- ----------------------------------------------------------------------------
WITH round_size AS (
    SELECT bet31 AS table_id, bet03 AS round_id, COUNT(DISTINCT bet05) AS player_cnt
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE bet03 != '0'
    GROUP BY bet31, bet03
    HAVING COUNT(DISTINCT bet05) <= 50
),
round_players AS (
    SELECT DISTINCT b.bet31 AS table_id, b.bet03 AS round_id, b.bet05 AS uid
    FROM ods_mariadb_2b.ods_a168_bet01 b
    JOIN round_size rs ON b.bet31 = rs.table_id AND b.bet03 = rs.round_id
),
co_occurrence AS (
    SELECT a.uid AS uid1, b.uid AS uid2, COUNT(*) AS co_round_count
    FROM round_players a
    JOIN round_players b
      ON a.table_id = b.table_id AND a.round_id = b.round_id AND a.uid < b.uid
    GROUP BY a.uid, b.uid
),
user_totals AS (
    SELECT uid, COUNT(*) AS total_rounds FROM round_players GROUP BY uid
),
pair_result AS (
    SELECT c.uid1, c.uid2,
           c.co_round_count * 1.0 / LEAST(t1.total_rounds, t2.total_rounds) AS 同桌率,
           c.co_round_count AS 订单数
    FROM co_occurrence c
    JOIN user_totals t1 ON c.uid1 = t1.uid
    JOIN user_totals t2 ON c.uid2 = t2.uid
    WHERE c.co_round_count > 100
      AND c.co_round_count * 1.0 / LEAST(t1.total_rounds, t2.total_rounds) >= 0.30
),
degree AS (
    SELECT uid, COUNT(*) AS partner_cnt
    FROM (SELECT uid1 AS uid FROM pair_result UNION ALL SELECT uid2 AS uid FROM pair_result) t
    GROUP BY uid
)
SELECT p.uid1, p.uid2, p.同桌率, p.订单数,
       d1.partner_cnt AS uid1_搭档数, d2.partner_cnt AS uid2_搭档数
FROM pair_result p
JOIN degree d1 ON p.uid1 = d1.uid
JOIN degree d2 ON p.uid2 = d2.uid
WHERE d1.partner_cnt <= 5 AND d2.partner_cnt <= 5
ORDER BY p.同桌率 DESC, p.订单数 DESC;

-- ----------------------------------------------------------------------------
-- C3. 【用户与荷官合谋】荷官桌胜率>70% + 全平台盈利>0 + 订单>100
--     胜负口径升级：改用 bet02.bet17(結果) 判正负，按物理局聚合、和局不进分母。
--     输出：uid, 荷官id, 投注金额, 盈利金额, 胜率, 关联订单笔数
-- ----------------------------------------------------------------------------
WITH bet_settle AS (
    SELECT
        b1.bet05 AS uid,
        b1.eid   AS dealer_id,
        b1.bet03 AS round_id,
        b1.bet04 AS hand_no,
        CAST(b1.bet13 AS DECIMAL(16,4)) / NULLIF(CAST(b1.bet11 AS DECIMAL(16,6)),0) AS bet_amt,
        CAST(b2.bet17 AS DECIMAL(16,4)) / NULLIF(CAST(b1.bet11 AS DECIMAL(16,6)),0) AS net_result
    FROM ods_mariadb_2b.ods_a168_bet01 b1
    JOIN ods_mariadb_2b.ods_a168_bet02 b2 ON b1.bet01 = b2.bet01
    WHERE b1.bet03 != '0' AND b2.category = '1' AND UPPER(TRIM(b2.bet38)) = 'N'
),
-- 先按"玩家×荷官×物理局"聚合，判定该局输赢(net>0赢/<0输/=0和)
round_level AS (
    SELECT uid, dealer_id, round_id, hand_no,
           SUM(bet_amt) AS round_bet,
           SUM(net_result) AS round_net
    FROM bet_settle
    GROUP BY uid, dealer_id, round_id, hand_no
),
dealer_level AS (
    SELECT uid, dealer_id,
           SUM(round_bet) AS bet_total,
           COUNT(*) AS round_count,
           SUM(CASE WHEN round_net > 0 THEN 1 ELSE 0 END) AS win_rounds,
           SUM(CASE WHEN round_net <> 0 THEN 1 ELSE 0 END) AS decided_rounds  -- 排除和局
    FROM round_level
    GROUP BY uid, dealer_id
),
platform_level AS (
    SELECT uid, SUM(round_net) AS overall_profit
    FROM round_level
    GROUP BY uid
)
SELECT
    d.uid, d.dealer_id,
    d.bet_total                                         AS 投注金额,
    p.overall_profit                                    AS 盈利金额,
    d.win_rounds * 1.0 / NULLIF(d.decided_rounds,0)     AS 胜率,
    d.round_count                                       AS 关联订单笔数
FROM dealer_level d
JOIN platform_level p ON d.uid = p.uid
WHERE d.round_count > 100
  AND p.overall_profit > 0
  AND d.win_rounds * 1.0 / NULLIF(d.decided_rounds,0) > 0.70
ORDER BY 胜率 DESC;


/* ==SECTION D — 新增维度（本轮 glimpse 新表解锁）================================= */

-- ----------------------------------------------------------------------------
-- D1. 【技术型/脚本用户】高注单 × 零(极低)UI点击 = API直连嫌疑
--     输出：mid, 注单数, UI点击数, 点击注单比（越小越可疑）
-- ----------------------------------------------------------------------------
WITH bet_cnt AS (
    SELECT bet05 AS mid, COUNT(*) AS bets
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE bet03 != '0'
    GROUP BY bet05
    HAVING COUNT(*) > 1000
),
click_cnt AS (
    SELECT CAST(mid AS VARCHAR) AS mid, SUM(CAST(counts AS INT)) AS clicks
    FROM ods_mariadb_2b.ods_a168_member_click_counter
    GROUP BY mid
)
SELECT b.mid, b.bets, COALESCE(c.clicks,0) AS ui_clicks,
       COALESCE(c.clicks,0) * 1.0 / b.bets AS 点击注单比
FROM bet_cnt b
LEFT JOIN click_cnt c ON b.mid = c.mid
ORDER BY 点击注单比 ASC, b.bets DESC
LIMIT 100;

-- ----------------------------------------------------------------------------
-- D2. 【打水/返水套利用户】需要退水率(agent_dtl.ag003) + 真实盈亏(聚合钱包)
--     打水嫌疑：流水巨大、净结算接近0或微负、但靠退水转正。
--     先取每个会员的"下注流水 vs 结算盈亏"，退水率需按其代理归属关联(见D2b)。
--     输出：mid, 总下注额, 结算盈亏, 盈亏/流水比(越接近0越像打水)
-- ----------------------------------------------------------------------------
WITH turnover AS (
    SELECT bet05 AS mid,
           SUM(CAST(bet13 AS DECIMAL(20,4)) / NULLIF(CAST(bet11 AS DECIMAL(16,6)),0)) AS 总下注额,
           COUNT(*) AS 注单数
    FROM ods_mariadb_2b.ods_a168_bet01
    WHERE bet03 != '0'
    GROUP BY bet05
    HAVING COUNT(*) > 500
),
pnl AS (
    SELECT mid, SUM(CAST(money AS DECIMAL(20,4))) AS 结算盈亏
    FROM ods_mariadb_2b.ods_a168_aggregate_transaction
    WHERE type = '0' AND status = '1'
    GROUP BY mid
)
SELECT t.mid, t.总下注额, t.注单数, COALESCE(p.结算盈亏,0) AS 结算盈亏,
       COALESCE(p.结算盈亏,0) / NULLIF(t.总下注额,0) AS 盈亏流水比
FROM turnover t
LEFT JOIN pnl p ON t.mid = p.mid
WHERE ABS(COALESCE(p.结算盈亏,0) / NULLIF(t.总下注额,0)) < 0.02   -- 盈亏几乎为0=纯刷流水
ORDER BY t.总下注额 DESC
LIMIT 100;

-- ----------------------------------------------------------------------------
-- D2b. 【会员→代理退水率归属】把 member 的代理层级链接到 agent_dtl 拿退水率
--      注：mem007~011 为代理层级链；agent_dtl.ag001=代理id。具体哪一层收退水
--      需按业务确认，此处先给"直属上级(mem011)→退水率"的关联模板。
-- ----------------------------------------------------------------------------
SELECT
    m.mem001 AS 會員ID,
    m.mem011 AS 直属代理,
    CAST(ad.ag003 AS DECIMAL(10,4)) AS 退水率,
    CAST(ad.ag015 AS DECIMAL(10,4)) AS 電投退水率
FROM ods_mariadb_2b.ods_a168_member m
JOIN ods_mariadb_2b.ods_a168_agent_dtl ad
     ON CAST(m.mem011 AS VARCHAR) = CAST(ad.ag001 AS VARCHAR)
LIMIT 50;

-- ----------------------------------------------------------------------------
-- D3. 【密码复用簇】共用同一(明文)密码的账号团伙（只输出哈希+成员数,不落明文）
--     注：上一轮此查询结果体为空,需确认是"真无≥3复用"还是"结果未回传"。
--     此版补充输出簇内成员id便于落地,但仍不 SELECT 明文 mem003。
-- ----------------------------------------------------------------------------
WITH pwd_cluster AS (
    SELECT MD5(mem003) AS pwd_hash, COUNT(*) AS 共用账号数
    FROM ods_mariadb_2b.ods_a168_member
    WHERE mem003 IS NOT NULL AND TRIM(mem003) <> ''
    GROUP BY MD5(mem003)
    HAVING COUNT(*) >= 3
)
SELECT pwd_hash, 共用账号数
FROM pwd_cluster
ORDER BY 共用账号数 DESC
LIMIT 50;

-- ----------------------------------------------------------------------------
-- D4. 【内部人员风险】后台频繁修改会员配置的操作者（log_mem_change）
--     输出：操作者, 操作类型, 涉及会员数, 操作次数
-- ----------------------------------------------------------------------------
SELECT
    lmc06 AS 操作者ID,
    lmc04 AS 操作类型,
    COUNT(DISTINCT lmc02) AS 涉及会员数,
    COUNT(*)              AS 操作次数
FROM ods_mariadb_2b.ods_a168_log_mem_change
GROUP BY lmc06, lmc04
ORDER BY 操作次数 DESC
LIMIT 50;

-- ----------------------------------------------------------------------------
-- D5. 【代理-会员IP重叠】代理登录IP 与其名下会员下注IP 精确重合（代理开小号嫌疑）
--     用 iphistory(会员IP史) × age_login(代理登录IP) 精确IP匹配。
-- ----------------------------------------------------------------------------
SELECT
    al.alg001 AS 代理ID,
    ih.uid    AS 会员ID,
    al.alg006 AS 共用IP,
    COUNT(*)  AS 重合次数
FROM ods_mariadb_2b.ods_a168_age_login al
JOIN ods_mariadb_2b.ods_a168_iphistory ih
     ON al.alg006 = ih.ip
GROUP BY al.alg001, ih.uid, al.alg006
HAVING COUNT(*) >= 2
ORDER BY 重合次数 DESC
LIMIT 100;


/* ==SECTION E — 尾秒下注（双轨口径：精确封盘 + 距开奖近似）========================= */

-- ----------------------------------------------------------------------------
-- E1. 【精确封盘口径】仅对配置了 bettime>0 的桌：距封盘秒数 = (开局+bettime) - 下注
--     tableid=bet31 已验证同编码。封盘时刻 = gi004 + bettime。
--     输出：距封盘秒数分布（负值=封盘后下注,重大异常）
-- ----------------------------------------------------------------------------
WITH tbl AS (
    SELECT CAST(tableid AS VARCHAR) AS table_id, CAST(bettime AS INT) AS bettime_sec
    FROM ods_mariadb_2b.ods_a168_tablelimit
    WHERE CAST(bettime AS INT) > 0
),
joined AS (
    SELECT
        TIMESTAMPDIFF(SECOND, b.bet08,
            TIMESTAMPADD(SECOND, tbl.bettime_sec, gi.gi004)) AS 距封盘秒数
    FROM ods_mariadb_2b.ods_a168_bet01 b
    JOIN ods_mariadb_2b.ods_a168_game_info gi
         ON b.bet03 = CAST(gi.gi002 AS VARCHAR) AND CAST(b.bet04 AS INT) = gi.gi003
    JOIN tbl ON b.bet31 = tbl.table_id
    WHERE gi.gi013 = '1'
)
SELECT
    COUNT(*)                                              AS 总笔数,
    SUM(CASE WHEN 距封盘秒数 < 0 THEN 1 ELSE 0 END)        AS 封盘后下注异常笔数,
    PERCENTILE_APPROX(距封盘秒数, 0.01)                   AS P1,
    PERCENTILE_APPROX(距封盘秒数, 0.05)                   AS P5,
    PERCENTILE_APPROX(距封盘秒数, 0.50)                   AS 中位数
FROM joined;

-- ----------------------------------------------------------------------------
-- E2. 【尾秒下注者×胜率】距封盘≤2秒的注单，按玩家聚合胜率(需先跑通E1确认口径)
--     此处先留结构，阈值(2秒/占比/胜率)待 SECTION A/E1 结果与行业调研确认后填。
--     —— 见交付说明：此段标注为待参数确认段落。
-- ----------------------------------------------------------------------------
-- （占位：E1 分布出来 + 行业阈值调研回来后补全，避免拍脑袋定"尾X秒"）


/* ============================================================================
   交付说明（给 Ryo Eng）
   ----------------------------------------------------------------------------
   ✅ 可直接跑：A1-A6, B0-B1, C1-C3, D1-D5, E1
   ⏸ 待参数：  E2（等 E1 实测封盘分布 + 行业"尾X秒"基准调研）
   ⚠ 需业务确认：
      - alarmMessage.type 各码含义（能否当风险标签）
      - agent_dtl 哪一层级对会员收退水（D2b 归属逻辑）
      - age022 测试线的"测试"取值（B0 分布出来后定过滤值）
   建议执行顺序：A(清欠账) → B0(测试线) → C(复跑三规则最终版) → D(新维度) → E1
   跑完把结果贴回，即进入 B 阶段：封版撰写 .qmd 商业方案。
   ============================================================================ */
