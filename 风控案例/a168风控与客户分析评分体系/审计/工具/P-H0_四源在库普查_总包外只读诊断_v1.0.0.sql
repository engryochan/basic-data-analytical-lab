-- ══════════════════════════════════════════════════════════════════════════
-- P-H0 · H 轴证据源可得性与字段血统普查 v1.0.0
-- ★ 总包外只读诊断（尚未入 a168_取数与核验_SQL总包 v11.0.1）★
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由：REDTEAM 2026-08-23 裁示「准予开工，先 P-H0，再 P1」。
--   H 轴尚未建立却拟令 M 轴承担安全门禁，此风险高于暂时算不出 NGR。
-- 本件只答一问：**当前库中究竟有没有足够证据建立 H 轴？**
--   不设计 H 指标，不产出 H score，不写任何判据。
--
-- 五源（第五源不得假定存在，须实查）：
--   H-SRC-01 支付（入金／出金／失败／拒付／人工审核）
--   H-SRC-02 会话（登录／登出／在线／心跳／设备）
--   H-SRC-03 会员状态变更（限额／停用／关闭／复开／风险状态）
--   H-SRC-04 客服工单（投诉／争议／求助）
--   H-SRC-05 自我排除／冷静期／责任博彩
--
-- ★★ 第一铁律：NO_TRACE ≠ NO_EVENT ★★
--   「在本检索范围内未发现」不等于「该事件不存在」。
--   故本件之每一行输出皆带**检索范围**（库、模式、关键词、时刻），
--   使日后换关键词翻案时，能分辨是「新证据」抑或「旧范围太窄」。
--
-- 六态（裁示所定，本件逐表标注）：
--   OBSERVED ／ SCHEMA_ONLY ／ PARTIAL ／ NOT_RECOVERABLE ／ UNKNOWN ／ NO_TRACE
--   ⚠ 本件只能产出至 SCHEMA_ONLY 一级（表与列之存在性）；
--     OBSERVED 须待 P-H0-3 逐表验货（有无实际记录）方可升级。
--
-- 五层（层层不可跳，承裁示第三节）：
--   Database → Table → Column → Record → Temporal coverage
--   源存在 ≠ 字段存在 ≠ 事件存在 ≠ 事件完整 ≠ 事件可用于 H 轴
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   只读 information_schema 与目标表，无 DDL、无写入。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §P-H0-1 · 全库表名扫描与五源分类（第一层：Table）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_1_table_inventory.csv」（诊断留档，非交付件）。
--   ★ 判读：本条只证「表名是否命中关键词」，**不证该表有数据**。
--     命中者进 §P-H0-2 查列；零命中者标 NO_TRACE 并记明本条之检索范围。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  t.TABLE_SCHEMA                                                    AS db_name,                     -- 取列：库名，涉检索范围之锚
  t.TABLE_NAME                                                      AS table_name,                  -- 取列：表名
  CASE                                                                                              -- 条件分支：起始分支——五源归类，一表可命中多源，此处取首命中
    WHEN LOWER(t.TABLE_NAME) REGEXP 'self_exclu|selfexclu|cooling|cooldown|cool_off|respons|rg_|_rg' -- 分支判定：责任博彩族关键词
      THEN 'H-SRC-05 自我排除／冷静期／责任博彩'                                                     -- 分支判定：第五源优先判，免被状态族吞并
    WHEN LOWER(t.TABLE_NAME) REGEXP 'pay|deposit|withdraw|cashier|recharge|transact|fund|remit|order_pay' -- 分支判定：支付族关键词
      THEN 'H-SRC-01 支付'                                                                          -- 分支判定：归支付源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'session|login|logout|online|heartbeat|device|token|visit'       -- 分支判定：会话族关键词
      THEN 'H-SRC-02 会话'                                                                          -- 分支判定：归会话源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'mem_change|member_log|status|state|limit|suspend|close|reopen|freeze|restrict|level|vip' -- 分支判定：状态变更族
      THEN 'H-SRC-03 会员状态变更'                                                                  -- 分支判定：归状态源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'ticket|case|complain|dispute|service|support|feedback|chat|msg|message' -- 分支判定：工单族
      THEN 'H-SRC-04 客服工单'                                                                      -- 分支判定：归工单源
    ELSE '（未命中五源）'                                                                           -- 分支判定：余者不归类，仍照登以备日后扩关键词
  END                                                               AS h_src,                       -- 条件分支：收束上方判词，产出「h_src」
  t.TABLE_TYPE                                                      AS table_type,                  -- 取列：表类型（BASE TABLE／VIEW），视图不可作证据源
  'ods_mariadb_2b'                                                  AS scope_db,                    -- 字面取值：检索范围之库——NO_TRACE 之锚，缺此即无从翻案
  '表名正则五族（见本条 CASE）'                                     AS scope_pattern,               -- 字面取值：检索范围之模式
  NOW()                                                             AS scope_scanned_at             -- 取值表达式：检索时刻，六态判读之时间锚
FROM information_schema.tables t                                                                    -- 取数来源：取自元数据字典（表清单）
WHERE t.TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
ORDER BY h_src, t.TABLE_NAME;                                                                       -- 排序：按 h_src, TABLE_NAME 排列；导出必带排序，否则分页无稳定序


-- ──────────────────────────────────────────────────────────────────────────
-- §P-H0-2 · 全库列名扫描（第二层：Column · 不倚赖表名，防「表名不像但列名对」之漏）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_2_column_inventory.csv」（诊断留档）。
--   ★ 本条独立于 §P-H0-1：表名未命中而列名命中者，正是最易漏之一类。
--     二条须并读，取并集方为候选源全集。
--   ★ COLUMN_COMMENT 常载中文列义，比靠列名猜可靠得多（承 §DX-03 之实测教训）。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  c.TABLE_NAME                                                      AS table_name,                  -- 取列：表名
  c.ORDINAL_POSITION                                                AS col_pos,                     -- 取列：列序，供还原表结构
  c.COLUMN_NAME                                                     AS column_name,                 -- 取列：列名
  c.DATA_TYPE                                                       AS data_type,                   -- 取列：数据类型，判可否转型与聚合
  c.COLUMN_COMMENT                                                  AS column_comment,              -- 取列：列注释，中文列义之来源
  CASE                                                                                              -- 条件分支：起始分支——列义归族
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'self_exclu|cooling|cooldown|respons'                          -- 分支判定：责任博彩族
      OR c.COLUMN_COMMENT REGEXP '自我排除|冷静期|责任博彩|自我限制'                                 -- 并列条件：中文列义命中
      THEN '★ RG 责任博彩'                                                                          -- 分支判定：H 轴最高价值之列
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'deposit|withdraw|pay|amount|recharge|fail|reject|refund|chargeback' -- 分支判定：支付族
      OR c.COLUMN_COMMENT REGEXP '充值|入金|存款|提现|出金|支付|退款|拒付|失败'                      -- 并列条件：中文列义命中
      THEN '支付'                                                                                   -- 分支判定：归支付
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'login|logout|session|online|duration|heartbeat|device|ua|agent' -- 分支判定：会话族
      OR c.COLUMN_COMMENT REGEXP '登录|登出|会话|在线|时长|设备'                                     -- 并列条件：中文列义命中
      THEN '会话'                                                                                   -- 分支判定：归会话
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'before|after|old_|new_|from_|to_|prev|status|state|reason|operator' -- 分支判定：状态变更族（前后态为其指纹）
      OR c.COLUMN_COMMENT REGEXP '变更前|变更后|原值|新值|状态|原因|操作人'                          -- 并列条件：中文列义命中
      THEN '状态变更'                                                                               -- 分支判定：归状态
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'ticket|complain|dispute|content|remark|note|reply'             -- 分支判定：工单族
      OR c.COLUMN_COMMENT REGEXP '工单|投诉|争议|内容|备注|回复'                                     -- 并列条件：中文列义命中
      THEN '工单'                                                                                   -- 分支判定：归工单
    WHEN LOWER(c.COLUMN_NAME) REGEXP '^(uid|member_id|user_id|mem[0-9]+|bet05|username|account)$'    -- 分支判定：会员键族——UID 可连接性之前提
      THEN '★ UID 候选键'                                                                           -- 分支判定：无此列则该源不可与注单表对齐
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'time|date|dt$|_at$|created|updated'                            -- 分支判定：时间列族——时间覆盖之前提
      THEN '★ 时间候选列'                                                                           -- 分支判定：无此列则无从判时间覆盖
    ELSE '（未命中）'                                                                               -- 分支判定：余者照登
  END                                                               AS col_family,                  -- 条件分支：收束上方判词，产出「col_family」
  'ods_mariadb_2b'                                                  AS scope_db,                    -- 字面取值：检索范围之库
  '列名正则 ＋ COLUMN_COMMENT 中文正则（见本条 CASE）'              AS scope_pattern,               -- 字面取值：检索范围之模式
  NOW()                                                             AS scope_scanned_at             -- 取值表达式：检索时刻
FROM information_schema.columns c                                                                   -- 取数来源：取自元数据字典（列清单）
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
  AND (                                                                                             -- 并列条件：起始括号——只留命中者，全库列过多
        LOWER(c.COLUMN_NAME) REGEXP 'self_exclu|cooling|cooldown|respons|deposit|withdraw|pay|recharge|fail|reject|refund|chargeback|login|logout|session|online|duration|heartbeat|device|before|after|old_|new_|prev|status|state|reason|operator|ticket|complain|dispute|uid|member_id|user_id|username|account' -- 并列条件：列名族
     OR c.COLUMN_COMMENT REGEXP '自我排除|冷静期|责任博彩|充值|入金|存款|提现|出金|支付|退款|拒付|失败|登录|登出|会话|在线|时长|设备|变更前|变更后|状态|原因|操作人|工单|投诉|争议' -- 并列条件：中文列义族
      )                                                                                             -- 续行：收束上方括号
ORDER BY col_family, c.TABLE_NAME, c.ORDINAL_POSITION;                                              -- 排序：按 col_family, TABLE_NAME, ORDINAL_POSITION 排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §P-H0-3 · 逐表验货模板（第三层：Record · ★ 本条不可直接执行，须先替换表名）
-- ▸ 导出：不需要 —— §P-H0-3 逐表验货，屏幕看结果；候选表逐张跑一遍。
--   ★ 本条判「SCHEMA_ONLY → OBSERVED」之升级：有表有列，未必有记录。
--   ★ 三问：有无记录 ／ 覆盖哪段时间 ／ 能否与注单表以 uid 对齐。
--   把 <TBL>、<UID_COL>、<TIME_COL> 三处替换后执行；三者取自 §P-H0-2 之输出。
-- ──────────────────────────────────────────────────────────────────────────
-- SELECT
--   '<TBL>'                                                        AS table_name,
--   COUNT(*)                                                       AS n_rows_total,
--   COUNT(DISTINCT <UID_COL>)                                      AS n_uid_distinct,
--   MIN(<TIME_COL>)                                                AS t_min,
--   MAX(<TIME_COL>)                                                AS t_max,
--   SUM(CASE WHEN <TIME_COL> >= '2026-03-21'
--             AND <TIME_COL> <  '2026-08-07' THEN 1 ELSE 0 END)    AS n_rows_in_window,
--   ROUND(SUM(CASE WHEN <TIME_COL> >= '2026-03-21'
--                   AND <TIME_COL> <  '2026-08-07' THEN 1 ELSE 0 END) * 100.0
--         / NULLIF(COUNT(*), 0), 4)                                AS pct_in_window,
--   CASE
--     WHEN COUNT(*) = 0                                            THEN 'SCHEMA_ONLY（有表无记录）'
--     WHEN MAX(<TIME_COL>) <  '2026-03-21'
--       OR MIN(<TIME_COL>) >= '2026-08-07'                         THEN 'NOT_RECOVERABLE（窗外，须换窗）'
--     WHEN SUM(CASE WHEN <TIME_COL> >= '2026-03-21'
--                    AND <TIME_COL> <  '2026-08-07' THEN 1 ELSE 0 END) * 1.0
--          / NULLIF(COUNT(*), 0) < 0.5                             THEN 'PARTIAL（窗内覆盖不足半）'
--     ELSE 'OBSERVED（窗内有记录，待 §P-H0-4 验 UID 对齐）'
--   END                                                            AS verdict_L3
-- FROM ods_mariadb_2b.<TBL>          -- ★ 取消注释后须自行补分号（纪律⑪：注释内不写分号）


-- ──────────────────────────────────────────────────────────────────────────
-- §P-H0-4 · UID 可连接性模板（第四层：与注单表对齐 · ★ 须替换表名）
-- ▸ 导出：不需要 —— §P-H0-4 UID 对齐率，屏幕看结果。
--   ★ 判读：对齐率过低即证该源之会员键与 bet05 非同一体系（承 §EX-18d 之教训——
--     wallet_dtl.user 为字符串而 bet05 为数值，曾致匹配率仅 0.66%）。
--     对齐率低者，纵有记录亦不可用于 H 轴，须先解编号体系。
-- ──────────────────────────────────────────────────────────────────────────
-- WITH bet_uid AS (
--   SELECT DISTINCT CAST(NULLIF(TRIM(bet05),'') AS BIGINT)         AS uid
--   FROM ods_mariadb_2b.ods_a168_bet02
--   WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
--     AND bet02 = '101'
--     AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
-- ),
-- src_uid AS (
--   SELECT DISTINCT CAST(NULLIF(TRIM(<UID_COL>),'') AS BIGINT)     AS uid
--   FROM ods_mariadb_2b.<TBL>
--   WHERE <UID_COL> IS NOT NULL
-- )
-- SELECT
--   '<TBL>'                                                        AS table_name,
--   (SELECT COUNT(*) FROM src_uid)                                 AS n_uid_src,
--   (SELECT COUNT(*) FROM bet_uid)                                 AS n_uid_bet,
--   COUNT(*)                                                       AS n_uid_matched,
--   ROUND(COUNT(*) * 100.0
--         / NULLIF((SELECT COUNT(*) FROM src_uid), 0), 4)          AS pct_src_matched,
--   ROUND(COUNT(*) * 100.0
--         / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4)          AS pct_bet_covered,
--   CASE
--     WHEN COUNT(*) = 0                                            THEN '❌ 编号体系不通，须先解'
--     WHEN COUNT(*) * 1.0
--          / NULLIF((SELECT COUNT(*) FROM src_uid), 0) < 0.50      THEN '⚠ 对齐率不足半，判 PARTIAL'
--     ELSE '✅ 可对齐'
--   END                                                            AS verdict_L4
-- FROM src_uid s
-- JOIN bet_uid b ON b.uid = s.uid    -- ★ 取消注释后须自行补分号（纪律⑪：注释内不写分号）


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（六态 ＋ H-Availability Gate）
-- ══════════════════════════════════════════════════════════════════════════
-- 六态（逐表判，缺一不可）：
--   OBSERVED         有表、有列、有记录、窗内覆盖足、UID 可对齐
--   SCHEMA_ONLY      有表有列，无记录或无从证明有记录
--   PARTIAL          仅部分时间／会员／事件覆盖
--   NOT_RECOVERABLE  经可复核范围检查，本窗结构上不含该期间（须换窗，非补列）
--   UNKNOWN          当前证据不足以判（须再查，非结论）
--   NO_TRACE         在**本件所载检索范围内**未发现记录
--
-- ★★ NO_TRACE ≠ NO_EVENT ★★
--   「未发现」只对**本次检索范围**成立。范围已随每行输出（scope_db／
--   scope_pattern／scope_scanned_at），日后换关键词若有新发现，
--   须能分辨是「新证据」抑或「旧范围太窄」——此即记录范围之全部用意。
--
-- H-Availability Gate（承裁示第九节，四态）：
--   H_READY       核心 H 事件具 UID ＋ 时间 ＋ 事件类型 ＋ 足够覆盖 ＋ 可追溯
--   H_PARTIAL     部分事件可靠，只得建部分 H 指标
--   H_PROXY_ONLY  仅有夜间投注、连输、注额爬升等**行为代理**
--   H_BLOCKED     关键源完全缺失
--
-- ★ 命名锁：若实况为 H_PROXY_ONLY，该量只得称
--     **Behavioral Risk Proxy**，**禁称 Harm Score**。
--   系统中不得出现「H_SCORE = 42」旁书「安全门禁已启用」而实际只有
--   bet06／bet08／stake／loss_streak／night_ratio 之情形。
--
-- ★ 无论落于何态，M（营销资格）在 H 轴立册前一律**默认不发放**；
--   且 M 只得由 H 轴计算，**禁引 V 轴**——否则逻辑即成
--   「高价值 ＋ 高伤害 → 因为他值钱，所以更要推给他」。
-- ══════════════════════════════════════════════════════════════════════════
