-- ══════════════════════════════════════════════════════════════════════════
-- P-H0 · H 轴证据源可得性与字段血统普查 v1.0.1
-- ★ 审计工具（ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL）· 状态 WORKING ★
-- ★ 置放 审计/工具/ · 不入 canonical SQL 总包 · 不进入正式分析 ★
-- ══════════════════════════════════════════════════════════════════════════
-- v1.0.0 → v1.0.1（PATCH · 缺陷修复，判定原则不变）
--   ★★ 本版所修者，是**探针自己的缺陷**；v1.0.0 之结果系统性不完整，
--      **不得据以判 H_BLOCKED** —— 那正是「NO_TRACE ≠ NO_EVENT」所防之事。
--
--   D-1 【结构性恒零】v1.0.0 之 CASE 有「时间候选列」与 mem[0-9]+／bet05 形态，
--       而 WHERE 过滤子句无此二族 —— 列在分类前即被滤掉。
--       实测：时间候选列 0 条（恒零，非无数据）、UID 候选键仅 7 条（皆英文名）。
--       → 本版令 WHERE 与 CASE **同族同源**，且时间族独立成条件。
--
--   D-2 【编码式列名盲区，最要命】本库列名系 betNN／memNNN／ageNNN／lmcNN
--       编码体系。ods_a168_log_mem_change（H-SRC-03 核心候选）在表名扫描命中，
--       却在列扫描**零列命中** —— 其列为 lmc02／lmc04／lmc05／lmc08，无一英文词。
--       → 本版改策略：**候选表全列输出，关键词只作标记、不作过滤**。
--         COLUMN_COMMENT 之中文列义是编码列唯一可读线索，须全数照登。
--
--   D-3 【表名族缺漏】wallet 未入支付族，致 ods_a168_wallet_dtl（资金流水主表）
--       被归「未命中五源」；log_／history／journal／balance／flow 族亦未单列。
--       → 本版补齐，并新增 H-SRC-06 日志族（变更留痕之通称）。
--
--   D-4 【假阳性未标】v1.0.0 之 RG 唯一命中为 wallet_dtl.responseDate
--       「對方回應時間」—— 系 respons 撞上 responseDate。
--       → 本版加负向排除，并对疑似假阳性单列标注，不静默丢弃。
--
--   D-5 【配置表与事务表未辨】payment_bank／method／platform／setting／type
--       皆配置表，无会员级事件。→ 本版加「表性质判别」：
--       同时具备 UID 型 ＋ 时间型 ＋ 金额型三列者方为事务表候选。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   只读 information_schema，无 DDL、无写入、不改任何在册档。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §P-H0-1b · 全库表名扫描 · 六源分类 ＋ 表性质判别（第一、二层合并）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_1b_table_inventory.csv」（诊断留档，非交付件）。
--   ★ 判读三处：
--     ① h_src —— 六源归类；「未命中」者仍照登，以备扩关键词后翻查。
--     ② table_nature —— 事务表候选 ／ 配置表 ／ 无从判；
--        配置表纵在支付族亦无会员级事件，不可作 H 轴证据源。
--     ③ has_uid／has_time／has_amount —— 三者俱备方入 §P-H0-3 验货。
-- ──────────────────────────────────────────────────────────────────────────
WITH col_flag AS (                                                                                  -- 公共表表达式：开启中间结果集 col_flag——逐表之三类列存在性
  SELECT c.TABLE_NAME                                                            AS table_name,     -- 取列：表名
         MAX(CASE WHEN LOWER(c.COLUMN_NAME) REGEXP                                                  -- 条件分支：UID 型列——含编码式（bet05／memNNN／ageNNN）
                    '^(uid|member_id|user_id|username|account|mem[0-9]{2,3}|bet05|age[0-9]{3}|lmc[0-9]{2})$'
                   OR c.COLUMN_COMMENT REGEXP '會員|会员|帳號|账号|用戶|用户'                        -- 并列条件：中文列义命中会员键
                   THEN 1 ELSE 0 END)                                            AS has_uid,        -- 条件分支：产出「has_uid」
         MAX(CASE WHEN LOWER(c.DATA_TYPE) REGEXP 'date|time'                                        -- 条件分支：时间型列——先认类型，再认名
                   OR LOWER(c.COLUMN_NAME) REGEXP 'time|date|_at$|_dt$|^dt$|created|updated'        -- 并列条件：列名命中时间族
                   OR c.COLUMN_COMMENT REGEXP '時間|时间|日期'                                       -- 并列条件：中文列义命中
                   THEN 1 ELSE 0 END)                                            AS has_time,       -- 条件分支：产出「has_time」
         MAX(CASE WHEN LOWER(c.DATA_TYPE) REGEXP 'decimal|double|float'                             -- 条件分支：金额型列——先认类型
                   OR LOWER(c.COLUMN_NAME) REGEXP 'amount|money|balance|sum|fee|cash'               -- 并列条件：列名命中金额族
                   OR c.COLUMN_COMMENT REGEXP '金額|金额|餘額|余额|款'                               -- 并列条件：中文列义命中
                   THEN 1 ELSE 0 END)                                            AS has_amount,     -- 条件分支：产出「has_amount」
         COUNT(*)                                                                AS n_cols          -- 计数表达式：列数，配置表通常列少
  FROM information_schema.columns c                                                                 -- 取数来源：取自元数据字典（列清单）
  WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'                                                           -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
  GROUP BY c.TABLE_NAME                                                                             -- 分组：按表名汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  t.TABLE_NAME                                                                   AS table_name,     -- 取列：表名
  CASE                                                                                              -- 条件分支：起始分支——六源归类，责任博彩优先判以免被状态族吞并
    WHEN LOWER(t.TABLE_NAME) REGEXP 'self_?exclu|cooling|cool_?off|cooldown|responsible|_rg$|^rg_'   -- 分支判定：责任博彩族（★ 已排除 response 之误撞）
      THEN 'H-SRC-05 自我排除／冷静期／责任博彩'                                                     -- 分支判定：H 轴最高价值之源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'wallet|pay|deposit|withdraw|cashier|recharge|transact|transation|fund|remit|balance|cash|order' -- 分支判定：支付族（★ v1.0.1 补 wallet／balance／cash）
      THEN 'H-SRC-01 支付／资金'                                                                    -- 分支判定：归支付源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'session|login|logout|online|heartbeat|device|token|visit'       -- 分支判定：会话族
      THEN 'H-SRC-02 会话／登录'                                                                    -- 分支判定：归会话源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'mem_change|member_log|suspend|close|reopen|freeze|restrict|limit|level|vip|status' -- 分支判定：会员状态族
      THEN 'H-SRC-03 会员状态变更'                                                                  -- 分支判定：归状态源
    WHEN LOWER(t.TABLE_NAME) REGEXP 'ticket|case|complain|dispute|service|support|feedback|chat|message|msg|alarm|alert' -- 分支判定：工单／消息族
      THEN 'H-SRC-04 客服工单／消息'                                                                -- 分支判定：归工单源（★ 告警与工单须于 §P-H0-3 再辨）
    WHEN LOWER(t.TABLE_NAME) REGEXP '^ods_a168_(log_|change_log)|_log$|history|journal|record|trace' -- 分支判定：日志族（★ v1.0.1 新增，变更留痕之通称）
      THEN 'H-SRC-06 日志／变更留痕'                                                                -- 分支判定：归日志源
    ELSE '（未命中六源）'                                                                           -- 分支判定：余者照登，以备扩关键词后翻查
  END                                                                            AS h_src,         -- 条件分支：收束上方判词，产出「h_src」
  f.has_uid,                                                                                        -- 取列：是否具会员键
  f.has_time,                                                                                       -- 取列：是否具时间列
  f.has_amount,                                                                                     -- 取列：是否具金额列
  f.n_cols,                                                                                         -- 取列：列数
  CASE                                                                                              -- 条件分支：起始分支——表性质判别（D-5）
    WHEN f.has_uid = 1 AND f.has_time = 1 AND f.has_amount = 1 THEN '★ 事务表候选（三列俱备）'      -- 分支判定：可作 H 轴资金证据源之候选
    WHEN f.has_uid = 1 AND f.has_time = 1                      THEN '事件表候选（无金额）'          -- 分支判定：可作行为事件源
    WHEN f.has_uid = 0 AND f.has_time = 0                      THEN '配置表（无会员键无时间）'      -- 分支判定：无会员级事件，不可作证据源
    ELSE '无从判（须逐表验货）'                                                                     -- 分支判定：余者待 §P-H0-3
  END                                                                            AS table_nature,  -- 条件分支：收束上方判词，产出「table_nature」
  'ods_mariadb_2b'                                                               AS scope_db,      -- 字面取值：检索范围之库——NO_TRACE 之锚
  'v1.0.1 六族表名正则 ＋ 三列性质判别（含编码式列名 betNN／memNNN／ageNNN／lmcNN）' AS scope_pattern, -- 字面取值：检索范围之模式
  NOW()                                                                          AS scope_scanned_at -- 取值表达式：检索时刻，六态判读之时间锚
FROM information_schema.tables t                                                                    -- 取数来源：取自元数据字典（表清单）
LEFT JOIN col_flag f ON f.table_name = t.TABLE_NAME                                                 -- 左连接：取自本条自建的中间结果集 col_flag，连接键为 table_name
WHERE t.TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
ORDER BY h_src, table_nature, t.TABLE_NAME;                                                         -- 排序：按 h_src, table_nature, TABLE_NAME 排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §P-H0-2b · 候选表全列输出（★ 破编码式列名盲区 —— D-2 之修复）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_2b_column_inventory.csv」（诊断留档）。
--   ★ 与 v1.0.0 之根本差异：**关键词只作标记，不作过滤**。
--     凡表名命中六源者，其**全部列**照登；编码列（lmc04 之属）之语义
--     只能自 COLUMN_COMMENT 中文列义读出，一经关键词过滤即全数消失。
--   ★ 实证教训：v1.0.0 中 ods_a168_log_mem_change 零列命中，
--     只因其列名为 lmc02／lmc04／lmc05／lmc08，无一英文词。
-- ──────────────────────────────────────────────────────────────────────────
WITH cand AS (                                                                                      -- 公共表表达式：开启中间结果集 cand——六源命中之候选表
  SELECT t.TABLE_NAME                                                            AS table_name      -- 取列：表名
  FROM information_schema.tables t                                                                  -- 取数来源：取自元数据字典（表清单）
  WHERE t.TABLE_SCHEMA = 'ods_mariadb_2b'                                                           -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
    AND LOWER(t.TABLE_NAME) REGEXP                                                                  -- 并列条件：六族任一命中即入候选
      'self_?exclu|cooling|cool_?off|cooldown|responsible|_rg$|^rg_|wallet|pay|deposit|withdraw|cashier|recharge|transact|transation|fund|remit|balance|cash|order|session|login|logout|online|heartbeat|device|token|visit|mem_change|member_log|suspend|close|reopen|freeze|restrict|limit|level|vip|status|ticket|case|complain|dispute|service|support|feedback|chat|message|msg|alarm|alert|^ods_a168_(log_|change_log)|_log$|history|journal|record|trace'
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  c.TABLE_NAME                                                                   AS table_name,     -- 取列：表名
  c.ORDINAL_POSITION                                                             AS col_pos,        -- 取列：列序，供还原表结构
  c.COLUMN_NAME                                                                  AS column_name,    -- 取列：列名
  c.DATA_TYPE                                                                    AS data_type,      -- 取列：数据类型
  c.COLUMN_COMMENT                                                               AS column_comment, -- 取列：列注释——编码列唯一可读之语义线索
  CASE WHEN LOWER(c.COLUMN_NAME) REGEXP '^(bet|mem|age|lmc|emp|acc|lacc)[0-9]{2,3}$'                -- 分支判定：编码式列名
       THEN '★ 编码式列名（语义须读 COLUMN_COMMENT）' ELSE '普通列名' END          AS name_style,    -- 条件分支：产出「name_style」
  CASE                                                                                              -- 条件分支：起始分支——列义归族（★ 只作标记，不参与过滤）
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'self_?exclu|cooling|cool_?off|cooldown'                       -- 分支判定：责任博彩族（★ 已去 respons，免撞 responseDate）
      OR c.COLUMN_COMMENT REGEXP '自我排除|冷靜期|冷静期|責任博彩|责任博彩|自我限制'                  -- 并列条件：中文列义命中
      THEN '★★ RG 责任博彩'                                                                        -- 分支判定：H 轴最高价值之列
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'deposit|withdraw|recharge|refund|chargeback|reject|fail'       -- 分支判定：支付事件族
      OR c.COLUMN_COMMENT REGEXP '充值|入金|存款|提現|提现|出金|退款|拒付|失敗|失败'                  -- 并列条件：中文列义命中
      THEN '支付事件'                                                                               -- 分支判定：归支付事件
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'amount|money|balance|fee|cash'                                -- 分支判定：金额族
      OR c.COLUMN_COMMENT REGEXP '金額|金额|餘額|余额'                                               -- 并列条件：中文列义命中
      THEN '金额'                                                                                   -- 分支判定：归金额
    WHEN LOWER(c.COLUMN_NAME) REGEXP 'login|logout|session|online|duration|heartbeat'                -- 分支判定：会话族
      OR c.COLUMN_COMMENT REGEXP '登入|登录|登出|會話|会话|在線|在线|時長|时长'                       -- 并列条件：中文列义命中
      THEN '会话'                                                                                   -- 分支判定：归会话
    WHEN LOWER(c.COLUMN_NAME) REGEXP '^(old|new|before|after|prev|from|to)_|_(old|new|before|after)$' -- 分支判定：前后态族——变更留痕之指纹
      OR c.COLUMN_COMMENT REGEXP '變更前|变更前|變更後|变更后|原值|新值'                              -- 并列条件：中文列义命中
      THEN '★ 前后态（变更留痕指纹）'                                                               -- 分支判定：H-SRC-03/06 之核心
    WHEN LOWER(c.COLUMN_NAME) REGEXP '^(uid|member_id|user_id|username|account|mem[0-9]{2,3}|bet05|age[0-9]{3}|lmc[0-9]{2})$' -- 分支判定：会员键族（含编码式）
      OR c.COLUMN_COMMENT REGEXP '會員|会员|帳號|账号'                                               -- 并列条件：中文列义命中
      THEN '★ UID 候选键'                                                                           -- 分支判定：UID 可连接性之前提
    WHEN LOWER(c.DATA_TYPE) REGEXP 'date|time'                                                      -- 分支判定：时间型——先认类型，最可靠
      OR LOWER(c.COLUMN_NAME) REGEXP 'time|date|_at$|_dt$|^dt$|created|updated'                     -- 并列条件：列名命中
      OR c.COLUMN_COMMENT REGEXP '時間|时间|日期'                                                    -- 并列条件：中文列义命中
      THEN '★ 时间候选列'                                                                           -- 分支判定：时间覆盖之前提（★ D-1 之修复：本族已入输出）
    ELSE '（未标记）'                                                                               -- 分支判定：余者照登，不丢弃
  END                                                                            AS col_family,    -- 条件分支：收束上方判词，产出「col_family」
  CASE WHEN LOWER(c.COLUMN_NAME) REGEXP 'response|respond'                                          -- 分支判定：疑似假阳性——response 曾撞 responsible
       THEN '⚠ 疑似假阳性（response 非 responsible）' ELSE '—' END                AS fp_flag,       -- 条件分支：产出「fp_flag」，不静默丢弃
  'ods_mariadb_2b'                                                               AS scope_db,      -- 字面取值：检索范围之库
  'v1.0.1 候选表全列输出（关键词只作标记不作过滤）'                              AS scope_pattern, -- 字面取值：检索范围之模式
  NOW()                                                                          AS scope_scanned_at -- 取值表达式：检索时刻
FROM information_schema.columns c                                                                   -- 取数来源：取自元数据字典（列清单）
JOIN cand k ON k.table_name = c.TABLE_NAME                                                          -- 连接：取自本条自建的中间结果集 cand，连接键为 table_name
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;                                                          -- 排序：按 TABLE_NAME, ORDINAL_POSITION 排列；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（承 v1.0.0，另加三条本版之锁）
-- ══════════════════════════════════════════════════════════════════════════
-- ★ 锁一 · v1.0.0 之结果作废，不得据以判 H_BLOCKED。
--   其时间列恒零、UID 仅 7 条、log_mem_change 零列命中、wallet_dtl 未归支付，
--   皆系**探针检索范围过窄**所致，非库中无此物。
--   此即「NO_TRACE ≠ NO_EVENT」之实证：范围窄，则「未发现」毫无信息量。
--
-- ★ 锁二 · 配置表纵在支付族亦不可作 H 轴证据源。
--   payment_bank／method／platform／setting／type 皆无会员键与时间列，
--   属配置；真事务候选须 has_uid ＝ has_time ＝ has_amount ＝ 1。
--
-- ★ 锁三 · 「登录」与「会话」不可互代（承裁示第五节）。
--   login_count ＝ 10 推不出 session_count ＝ 10；
--   last_login − first_login 推不出 online_duration。
--   仅有 login 而无 logout／duration 者，一律判 LOGIN_PROXY_ONLY，
--   其量只得称 Behavioral Risk Proxy，**禁称 Harm Score**。
--
-- 六态：OBSERVED ／ SCHEMA_ONLY ／ PARTIAL ／ NOT_RECOVERABLE ／ UNKNOWN ／ NO_TRACE
-- H-Gate：H_READY ／ H_PARTIAL ／ H_PROXY_ONLY ／ H_BLOCKED
-- 工具态：WORKING（本件）· ARTIFACT CLASS ＝ A2 DIAGNOSTIC_TOOL · canonical ＝ false
-- ══════════════════════════════════════════════════════════════════════════
