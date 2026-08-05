-- ============================================================
-- 全局字典查询：栏位清单 + 正名(自动识别版) + 数据分类 + 分类可信度
--
-- 【本次升级说明，先说结论】数据分类**没有**改成纯内容识别——已用真实
-- 数据验证过，内容关键词在表级别分类这件事上会比表名规则更差：
--   - "彩池域"关键词(彩池|jackpot)在真实注释里命中0行，内容识别完全抓瞎
--   - "货币码房域"关键词命中16张不同表(含bet01/bet02)，因为"匯率"这种
--     字段是很多表都有的辅助属性，不是"这张表专门管货币"的信号
--   - "钱包处理域"/"营销活动域"同样出现跨域误判
-- 根本原因：正名是给单一栏位分类(这个栏位讲的是什么)，内容识别天然合适；
-- 数据分类是给整张表归类(这张表主要做什么用)，很多域的关键词只是
-- "顺带出现的相关字眼"，出现≠这张表属于这个域，两者不是同一类问题。
--
-- 真正做的升级：保留表名规则当主要判断依据(它在这里反而更可靠)，
-- 但加一层真正自动、且已验证有效的内容交叉验证——用上一版"正名"里
-- 已验证过的7个核心概念(player_id/dealer_id/bet_amount/win_amount/
-- table_id/game_type/start_time)，反过来核对"01_投注注单域"这个表名
-- 判定准不准。已实测：bet01/bet02命中6-7个概念，可信度高；
-- bet_No/orderslist/betchange_log/risklist这几张表名像投注表、
-- 内容概念命中数却是0，值得标出来提醒人工复核，而不是照单全收。
-- ============================================================

WITH conflict_check AS (
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'ods_mariadb_2b'
      AND column_name NOT IN (
          '__source_pk','dt','source_db','source_table','ods_table_name','sync_time',
          'id','status','type','name','time','remark','code','currency','sn',
          'operator','url','money','addtime','lastmodifytime','ip','category','gid','mid'
      )
    GROUP BY column_name
    HAVING COUNT(DISTINCT column_comment) > 1
),
concept_match AS (
    SELECT
        table_schema, table_name, column_name, column_comment,
        (column_comment REGEXP '[0-9][ ]*[:：].*[0-9][ ]*[:：]') AS 疑似枚举列表,
        CASE
            WHEN column_comment REGEXP '會員編號|会员编号|玩家編號|玩家编号|會員[ ]*mid|会员[ ]*mid' THEN 'player_id'
            WHEN column_comment REGEXP '荷官' THEN 'dealer_id'
            WHEN column_comment REGEXP '下注金額|投注金額|下注金额|投注金额' THEN 'bet_amount'
            WHEN column_comment REGEXP '派彩' THEN 'win_amount'
            WHEN column_comment REGEXP '桌子編號|桌台編號|桌子编号|桌台编号' THEN 'table_id'
            WHEN column_comment REGEXP '遊戲類別編號|游戏类别编号|遊戲類型編號' THEN 'game_type'
            WHEN column_comment REGEXP '下注時間|開局時間|下注时间|开局时间' THEN 'start_time'
            ELSE NULL
        END AS 标准概念
    FROM information_schema.columns
    WHERE table_schema = 'ods_mariadb_2b'
),
-- 每张表命中了几个"不重复"的核心概念(不是命中几行，是命中几种概念)，
-- 排除枚举列表误判——这是可信度的核心依据
table_concept_count AS (
    SELECT table_schema, table_name, COUNT(DISTINCT 标准概念) AS 概念命中数
    FROM concept_match
    WHERE 标准概念 IS NOT NULL AND NOT 疑似枚举列表
    GROUP BY table_schema, table_name
),
table_classified AS (
    SELECT DISTINCT
        table_schema, table_name,
        CASE
            WHEN LOWER(table_name) REGEXP 'bet0?1$|bet0?2$|^ods_a168_bet$|betchange|bet_partner|bet_no|orderslist|risklist' THEN '01_投注注单域'
            WHEN LOWER(table_name) REGEXP 'game_info|game_result|game_no$|game_statistics|game_type|game_tip|game_transfer|shuffle' THEN '02_对局结果域'
            WHEN LOWER(table_name) REGEXP 'dailyreport' THEN '03_日汇总报表域'
            WHEN LOWER(table_name) REGEXP 'employee|emp_login|control(_login)?' THEN '04_员工荷官域'
            WHEN LOWER(table_name) REGEXP '^ods_a168_agent(_test|_sub|_elec|_bak|_partner)?$|agent_dtl|agents_loginpass|agent_permissionrole|subagent' THEN '05_代理层级域'
            WHEN LOWER(table_name) REGEXP 'categor' THEN '06_会员分级域'
            WHEN LOWER(table_name) REGEXP 'redpacket' THEN '07_营销活动域'
            WHEN LOWER(table_name) REGEXP 'aggregate_' THEN '08_三方钱包聚合域'
            WHEN LOWER(table_name) REGEXP 'alarm|alert|change_log' THEN '09_异常稽核日志域'
            WHEN LOWER(table_name) REGEXP 'currency|conversion|ctl_rto|odds' THEN '10_货币码房域'
            WHEN LOWER(table_name) REGEXP 'age_login|age_sub_login' THEN '11_代理登入日志域'
            WHEN LOWER(table_name) REGEXP 'game_log|game_demoip' THEN '12_会话地理位置域'
            WHEN LOWER(table_name) REGEXP 'apiurl|callwebapi|keyserver|realtimelog|stream|symbol' THEN '13_系统API配置域'
            WHEN LOWER(table_name) REGEXP 'ban_bet_area|bet_limit|tablelimit' THEN '14_限红限注规则域'
            WHEN LOWER(table_name) REGEXP '^ods_a168_member' THEN '15_会员主档域'
            WHEN LOWER(table_name) REGEXP 'payment_' THEN '16_支付渠道配置域'
            WHEN LOWER(table_name) REGEXP 'partner_' THEN '17_第三方游戏对接域'
            WHEN LOWER(table_name) REGEXP 'wallet_' THEN '18_钱包处理域'
            WHEN LOWER(table_name) REGEXP 'permission|roles|white_list|ipblacklist|iphistory|alert_ip' THEN '19_权限与IP安控域'
            WHEN LOWER(table_name) REGEXP 'jackpot' THEN '20_彩池域'
            WHEN LOWER(table_name) REGEXP 'sms|wechat|urllist|passiplist|tip$|close_tip' THEN '21_通知与站点域'
            WHEN LOWER(table_name) REGEXP 'log_realtimebet|smr_log' THEN '22_实时下注日志域'
            ELSE '99_其他系统配置域'
        END AS 数据分类
    FROM information_schema.columns
    WHERE table_schema = 'ods_mariadb_2b'
)
SELECT
    c.table_schema,
    c.table_name,
    c.ordinal_position,
    c.column_name,
    c.data_type,
    c.column_type,
    c.is_nullable,
    c.column_key,
    c.extra,
    c.column_comment,

    -- ---------- 正名(自动识别版，见上一版) ----------
    CASE
        WHEN m.标准概念 IS NOT NULL AND NOT m.疑似枚举列表 AND cc.column_name IS NOT NULL THEN
            CONCAT('✅', m.标准概念, '候选(源:',
                   TRIM(REGEXP_REPLACE(COALESCE(c.column_comment,''), '^source_type=[^;]*;\\s*', '')),
                   ')⚠️同名异义:此字段名在其他表另有含义，勿跨表套用')
        WHEN m.标准概念 IS NOT NULL AND NOT m.疑似枚举列表 THEN
            CONCAT('✅', m.标准概念, '候选(源:',
                   TRIM(REGEXP_REPLACE(COALESCE(c.column_comment,''), '^source_type=[^;]*;\\s*', '')), ')')
        WHEN cc.column_name IS NOT NULL THEN
            CONCAT('⚠️[', c.table_name, '专属]',
                   TRIM(REGEXP_REPLACE(COALESCE(c.column_comment,''), '^source_type=[^;]*;\\s*', '')))
        ELSE NULLIF(TRIM(REGEXP_REPLACE(COALESCE(c.column_comment,''), '^source_type=[^;]*;\\s*', '')), '')
    END AS 正名,

    -- ---------- 数据分类：表名规则判定(主要依据，已验证在此比内容识别可靠) ----------
    tcl.数据分类,

    -- ---------- 分类可信度(真正自动、已验证)：用7个核心概念反过来验证
    -- "01_投注注单域"这个表名判定准不准。概念命中数越高越可信；
    -- 表名判定为投注域、但概念命中数=0的，标"⚠️待复核"提醒人工看一眼——
    -- 已实测bet01/bet02命中6-7个(高可信)，bet_No/orderslist/
    -- betchange_log/risklist/以及已确认空表的ods_a168_bet命中0个(待复核)。
    CASE
        WHEN tcl.数据分类 = '01_投注注单域' THEN
            CASE
                WHEN COALESCE(tcc.概念命中数, 0) >= 3 THEN CONCAT('✅高可信(命中', COALESCE(tcc.概念命中数,0), '个核心概念)')
                WHEN COALESCE(tcc.概念命中数, 0) >= 1 THEN CONCAT('中等可信(命中', COALESCE(tcc.概念命中数,0), '个核心概念)')
                ELSE '⚠️待复核(表名像投注表，但0个核心概念命中，建议人工确认)'
            END
        ELSE '（分类可信度目前仅对01_投注注单域做内容交叉验证，其余域见上方说明，暂沿用表名规则）'
    END AS 分类可信度

FROM information_schema.columns c
LEFT JOIN conflict_check cc ON cc.column_name = c.column_name
LEFT JOIN concept_match  m  ON m.table_schema = c.table_schema
                            AND m.table_name = c.table_name
                            AND m.column_name = c.column_name
LEFT JOIN table_classified tcl ON tcl.table_schema = c.table_schema AND tcl.table_name = c.table_name
LEFT JOIN table_concept_count tcc ON tcc.table_schema = c.table_schema AND tcc.table_name = c.table_name
WHERE c.table_schema = 'ods_mariadb_2b'
ORDER BY tcl.数据分类, c.table_schema, c.table_name, c.ordinal_position;
