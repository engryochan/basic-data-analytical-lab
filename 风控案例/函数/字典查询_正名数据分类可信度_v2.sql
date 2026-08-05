-- ============================================================
-- 全局字典查询：栏位清单 + 正名(自动识别版) + 数据分类 + 分类可信度
--
-- 【本次升级】正名自动识别新增2个概念，均已用真实字典核实过零跨域污染：
--   - cash_change_amount(異動金額)：仅命中log_age_cash_change.lacc06一处，
--     对应`商君风控体系之数据篇.qmd`第二章第八节验证过的"会员净现金流"
--     信号来源字段(该字段本身是中性的"异动金额"，正负号与"是否为真实
--     博彩盈亏"需结合会员层级求和才能判断，此处只负责标注这是哪个概念)
--   - system_risk_flag(風險單)：命中dailyreport2/dailyreport_member/
--     dailyreport_table共3张表，跟既有的"系统标记类"指标(risk标记)对应
--
-- 【表级可信度，诚实说明未扩大的原因】曾测试用player_id概念反查"15_会员
-- 主档域"，结果ods_a168_member本表player_id概念命中数=0——"會員編號"这
-- 类说法是"别的表引用会员ID时"才会这样标注，会员表自己的主键字段通常
-- 不会自称"會員編號"。用这个概念做可信度检查，反而会把最正确的那张表
-- 打成低可信，比不检查还误导人，已实测证实此路不通，故不纳入。
-- "風險單"概念虽干净(3张dailyreport表都命中、无矛盾案例)，但也因此测不出
-- 任何新的区分力(没有同名却命中0的反例可对比)，不算有效的可信度升级，
-- 故表级可信度维持只做"01_投注注单域"——目前唯一测出真实跨域区分力的域。
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
            WHEN column_comment REGEXP '異動金額|异动金额' THEN 'cash_change_amount'
            WHEN column_comment REGEXP '風險單|风险单' THEN 'system_risk_flag'
            ELSE NULL
        END AS 标准概念
    FROM information_schema.columns
    WHERE table_schema = 'ods_mariadb_2b'
),
table_concept_count AS (
    SELECT table_schema, table_name, COUNT(DISTINCT 标准概念) AS 概念命中数
    FROM concept_match
    WHERE 标准概念 IS NOT NULL AND NOT 疑似枚举列表
      -- 可信度只看qmd 1.5节global_data实际在用的7个核心投注概念，
      -- 不把新加的cash_change_amount/system_risk_flag算进"01_投注注单域"
      -- 的可信度分数里(它们是财务/系统标记类概念，跟投注域是不同维度)
      AND 标准概念 IN ('player_id','dealer_id','bet_amount','win_amount','table_id','game_type','start_time')
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
            WHEN LOWER(table_name) REGEXP 'log_age_cash_change' THEN '18_钱包处理域'  -- 新增：已验证的财务异动表，原22条规则漏收，此表本该归钱包处理域
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

    -- ---------- 正名(自动识别版，9个核心概念) ----------
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

    -- ---------- 数据分类：表名规则(主要依据) ----------
    tcl.数据分类,

    -- ---------- 分类可信度：仅"01_投注注单域"有真正验证过的跨域区分力，
    -- 其余域(含15_会员主档域，已测证实player_id概念在此不适用)维持
    -- 表名规则、不打可信度标签，避免制造虚假的"看起来更自动"的假象 ----------
    CASE
        WHEN tcl.数据分类 = '01_投注注单域' THEN
            CASE
                WHEN COALESCE(tcc.概念命中数, 0) >= 3 THEN CONCAT('✅高可信(命中', COALESCE(tcc.概念命中数,0), '个核心概念)')
                WHEN COALESCE(tcc.概念命中数, 0) >= 1 THEN CONCAT('中等可信(命中', COALESCE(tcc.概念命中数,0), '个核心概念)')
                ELSE '⚠️待复核(表名像投注表，但0个核心概念命中，建议人工确认)'
            END
        ELSE '（可信度目前仅对01_投注注单域做内容交叉验证，已实测15_会员主档域此法不适用，其余域暂沿用表名规则）'
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
