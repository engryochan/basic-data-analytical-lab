-- ══════════════════════════════════════════════════════════════════════════
-- P-H0-3 · 五张高优先候选表逐表验货 v1.0.0（★ 零占位符，可直接运行）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · 状态 WORKING · 置放 审计/工具/ ★
-- ★ canonical = false · 不入 SQL 总包 · 结案前不得引用其结论 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 上游：P-H0 v1.0.1 之 _PH0_1b（129 表）与 _PH0_2b（41 表／667 列）
-- 本件答第三层「Record」与第四层「Temporal / UID」两问：
--   有表有列 ≠ 有记录；有记录 ≠ 窗内有记录；窗内有记录 ≠ 能与注单表对齐。
--
-- ★ 五张候选之定位（据 _PH0_2b 之 COLUMN_COMMENT 实读，非臆断）：
--   §V-1 payment_order          第三方支付入金订单 —— H-SRC-01 **主表**
--        mid 數值會員鍵｜orderTime 訂單時間｜amount/real_amount/fee 金額
--        status 含失败态（2 加點失敗／-1 線上支付失敗）→ failed_deposit 可算
--   §V-2 wallet_dtl             钱包加扣点 —— **非入金**，系内部转账
--        type 0取餘額/1加點/2扣點｜cash 當前金額（★ 余额快照，高价值）
--        user varchar(30) 账号字符串 —— 承 §EX-18d 之教训，对齐须经账号映射
--   §V-3 mem_login              登录 —— mlg003 sid／mlg008 on_line 皆在
--        ★ 决定性一问：行数 vs 会员数 → 事件流 抑或 状态快照
--   §V-4 log_mem_change         会员变更留痕 —— **后台操作日志**
--        lmc04 類別 enum(add/edit/changestatus)｜lmc05 內容｜lmc09 SQL
--        ★ 内容为自由文本＋原始 SQL，非结构化 before/after，须解析方得语义
--   §V-5 aggregate_transaction  聚合商转账 —— 亦内部转账，非外部资金流入
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- 窗口：2026-03-21 ≤ dt < 2026-08-07（与注单窗同，便于对齐）
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §V-1 · payment_order 验货（H-SRC-01 主表 · 入金 ＋ 失败入金）
-- ▸ 导出：不需要 —— §V-1 验货读数，屏幕看结果。
--   ★ 三问：有无记录 ／ 窗内覆盖 ／ 失败态占比（failed_deposit 之可得性）。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'payment_order'                                                        AS tbl,                    -- 字面取值：受检表名
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(mid))                                              AS n_mid,                  -- 计数表达式：去重会员数
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：分区日下界
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：分区日上界
  SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win,            -- 条件计数：窗内行数
  ROUND(SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_in_win,             -- 比率表达式：窗内占比，分母零则 NULL
  SUM(CASE WHEN TRIM(status) = '1'  THEN 1 ELSE 0 END)                   AS n_status_success,       -- 条件计数：1 支付&加點成功
  SUM(CASE WHEN TRIM(status) = '0'  THEN 1 ELSE 0 END)                   AS n_status_pending,       -- 条件计数：0 未處理
  SUM(CASE WHEN TRIM(status) = '2'  THEN 1 ELSE 0 END)                   AS n_status_addfail,       -- 条件计数：2 支付成功但加點失敗
  SUM(CASE WHEN TRIM(status) = '-1' THEN 1 ELSE 0 END)                   AS n_status_payfail,       -- 条件计数：-1 線上支付失敗 ★ failed_deposit 之核心
  SUM(CASE WHEN TRIM(status) NOT IN ('0','1','2','-1') THEN 1 ELSE 0 END) AS n_status_other,        -- 条件计数：其余态（999 訂單… 等）
  ROUND(SUM(CASE WHEN TRIM(status) IN ('2','-1') THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_failed,             -- 比率表达式：失败态占比
  COUNT(DISTINCT TRIM(currency))                                         AS n_currency,             -- 计数表达式：币别数，判是否须换算
  SUM(CASE WHEN TRIM(wallet_id) IS NOT NULL AND TRIM(wallet_id) <> '' THEN 1 ELSE 0 END) AS n_has_wallet_id -- 条件计数：可连 wallet_dtl 之行数
FROM ods_mariadb_2b.ods_a168_payment_order;                                                         -- 取数来源：取自支付订单表


-- ──────────────────────────────────────────────────────────────────────────
-- §V-2 · wallet_dtl 验货（★ 内部转账 ＋ 余额快照，非入金）
-- ▸ 导出：不需要 —— §V-2 验货读数，屏幕看结果。
--   ★ 判读：type 分布若以 1加點/2扣點 为主，即坐实其为内部转账，
--     不可充作 deposit 证据；而 cash 當前金額 之非空率决定余额轨迹可否重建。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'wallet_dtl'                                                           AS tbl,                    -- 字面取值：受检表名
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(`user`))                                           AS n_user,                 -- 计数表达式：去重账号数（★ 字符串账号，非数值 mid）
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：分区日下界
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：分区日上界
  SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win,            -- 条件计数：窗内行数
  SUM(CASE WHEN TRIM(type) = '0' THEN 1 ELSE 0 END)                      AS n_type_query,           -- 条件计数：0 取餘額（查询，非资金变动）
  SUM(CASE WHEN TRIM(type) = '1' THEN 1 ELSE 0 END)                      AS n_type_credit,          -- 条件计数：1 加點
  SUM(CASE WHEN TRIM(type) = '2' THEN 1 ELSE 0 END)                      AS n_type_debit,           -- 条件计数：2 扣點
  SUM(CASE WHEN TRIM(status) = '1' THEN 1 ELSE 0 END)                    AS n_ok,                   -- 条件计数：1 成功
  SUM(CASE WHEN TRIM(status) = '2' THEN 1 ELSE 0 END)                    AS n_fail,                 -- 条件计数：2 失敗
  SUM(CASE WHEN TRIM(status) = '3' THEN 1 ELSE 0 END)                    AS n_rollback,             -- 条件计数：3 回滾
  ROUND(SUM(CASE WHEN TRIM(cash) IS NOT NULL AND TRIM(cash) <> '' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_cash_notnull,       -- 比率表达式：★ 余额快照非空率——决定余额轨迹可否重建
  ROUND(SUM(CASE WHEN TRIM(`user`) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_user_numeric        -- 比率表达式：★ 账号是否纯数字——承 §EX-18d，决定能否直连 bet05
FROM ods_mariadb_2b.ods_a168_wallet_dtl;                                                            -- 取数来源：取自钱包明细表


-- ──────────────────────────────────────────────────────────────────────────
-- §V-3 · mem_login 验货（★ 决定性一问：事件流 抑或 状态快照）
-- ▸ 导出：不需要 —— §V-3 验货读数，屏幕看结果。
--   ★ 判读铁律：
--     n_rows ≈ n_member  → **状态快照表**（每会员一行）→ 登录频次不可算，判 H_PROXY 之下
--     n_rows ≫ n_member  → **登录事件流** → 登录频次与间隔可算，判 LOGIN_PROXY_ONLY
--   ★ 无论何者，皆**不得**称 SESSION_AVAILABLE 或 ONLINE_DURATION_AVAILABLE：
--     本表有 sid 与 on_line，惟无 logout_time 与 duration
--     login_count = 10 推不出 session_count = 10
--     last_login − this_login 推不出 online_duration
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'mem_login'                                                            AS tbl,                    -- 字面取值：受检表名
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(mlg001))                                           AS n_member,               -- 计数表达式：去重会员数（mlg001 = mem_id）
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT TRIM(mlg001)), 0), 4)     AS rows_per_member,        -- 比率表达式：★ 逼近 1 即状态快照，远大于 1 即事件流
  COUNT(DISTINCT TRIM(mlg003))                                           AS n_sid,                  -- 计数表达式：去重 session id 数
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：分区日下界
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：分区日上界
  SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win,            -- 条件计数：窗内行数
  MIN(NULLIF(TRIM(mlg004), ''))                                          AS this_login_min,         -- 聚合取值：本次登录时间下界
  MAX(NULLIF(TRIM(mlg004), ''))                                          AS this_login_max,         -- 聚合取值：本次登录时间上界
  SUM(CASE WHEN TRIM(mlg008) = '1' THEN 1 ELSE 0 END)                    AS n_online_flag,          -- 条件计数：on_line = 1 之行数
  ROUND(SUM(CASE WHEN TRIM(mlg001) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_memid_numeric       -- 比率表达式：会员键是否纯数字——决定能否直连 bet05
FROM ods_mariadb_2b.ods_a168_mem_login;                                                             -- 取数来源：取自会员登录表


-- ──────────────────────────────────────────────────────────────────────────
-- §V-4 · log_mem_change 验货（H-SRC-03 · 后台操作日志 · 内容为自由文本）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_3_lmc_category.csv」（诊断留档，非交付件）。
--   ★ 本条按 lmc04 類別（add／edit／changestatus）分组，看三类之量与时间跨度。
--   ★ 关键在 changestatus 一类：会员启停、可投注与否之变更皆在其中；
--     惟其具体语义藏于 lmc05 內容 与 lmc09 SQL 之**文本**，非结构化列，
--     故本条只答「有多少、覆盖何时、涉及多少会员」，**不答「改了什么」**。
--   ★ 承既有认知：mem016（启用）／mem017（可投注）**不是本表之列**，
--     只可能出现于 lmc05／lmc09 之文本内；此前若曾以其为列，属血统误记，须补 SC。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  COALESCE(NULLIF(TRIM(lmc04), ''), '（空）')                            AS lmc04_category,         -- 取值表达式：變更類別，空值归一为「（空）」
  COUNT(*)                                                               AS n_events,               -- 计数表达式：事件数
  COUNT(DISTINCT TRIM(lmc02))                                            AS n_target_id,            -- 计数表达式：去重被改对象 ID（lmc02 = ID）
  COUNT(DISTINCT TRIM(lmc06))                                            AS n_operator,             -- 计数表达式：去重操作者数（lmc06 = 操作者）
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：分区日下界
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：分区日上界
  SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win,            -- 条件计数：窗内事件数
  ROUND(AVG(LENGTH(COALESCE(lmc05, ''))), 2)                             AS avg_len_content,        -- 聚合取值：內容平均长度，判文本解析之工作量
  ROUND(AVG(LENGTH(COALESCE(lmc09, ''))), 2)                             AS avg_len_sql,            -- 聚合取值：SQL 平均长度
  SUM(CASE WHEN lmc05 REGEXP 'mem016|mem017' THEN 1 ELSE 0 END)          AS n_content_hit_mem01617, -- 条件计数：★ 內容文本命中 mem016/mem017 之行数
  SUM(CASE WHEN lmc09 REGEXP 'mem016|mem017' THEN 1 ELSE 0 END)          AS n_sql_hit_mem01617,     -- 条件计数：★ SQL 文本命中 mem016/mem017 之行数
  SUM(CASE WHEN CONCAT(COALESCE(lmc05, ''), COALESCE(lmc09, ''))
                REGEXP '自我|排除|冷靜|冷静|責任|责任|限額|限额|凍結|冻结|停用|封鎖|封锁'
           THEN 1 ELSE 0 END)                                            AS n_hit_rg_semantics      -- 条件计数：★★ 文本内是否含责任博彩语义——RG 之最后一线希望
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员变更日志表
GROUP BY COALESCE(NULLIF(TRIM(lmc04), ''), '（空）')                                                 -- 分组：按變更類別汇总
ORDER BY n_events DESC, lmc04_category;                                                             -- 排序：按事件数降序、類別升序排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §V-5 · payment_order 之 mid 与注单 bet05 对齐率（第四层 · UID 可连接性）
-- ▸ 导出：不需要 —— §V-5 对齐率读数，屏幕看结果。
--   ★ 承 §EX-18d 之血账：wallet_dtl.user 为字符串而 bet05 为数值，曾致匹配率仅 0.66%。
--     故 payment_order.mid 是否与 bet05 同一编号体系，须实测，不得假定。
--   ★ 判读：对齐率过低即证二者非同一体系，纵有记录亦不可用于 H 轴，须先解编号。
-- ──────────────────────────────────────────────────────────────────────────
WITH bet_uid AS (                                                                                   -- 公共表表达式：开启中间结果集 bet_uid——注单侧会员全集
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)                AS uid                     -- 取列：会员编号，去空白后转整型
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet05), '') AS BIGINT) > 0                                                 -- 并列条件：排除零与空会员编号
),                                                                                                  -- 续行：收束上方的子查询或函数括号
pay_uid AS (                                                                                        -- 公共表表达式：开启中间结果集 pay_uid——支付侧会员全集
  SELECT DISTINCT CAST(NULLIF(TRIM(mid), '') AS BIGINT)                  AS uid                     -- 取列：支付侧会员编号
  FROM ods_mariadb_2b.ods_a168_payment_order                                                        -- 取数来源：取自支付订单表
  WHERE TRIM(mid) REGEXP '^[0-9]+$'                                                                 -- 过滤条件：只取纯数字者，非数字即非同体系
    AND CAST(NULLIF(TRIM(mid), '') AS BIGINT) > 0                                                   -- 并列条件：排除零
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'payment_order.mid ↔ bet02.bet05'                                      AS pair,                   -- 字面取值：受检对齐对
  (SELECT COUNT(*) FROM pay_uid)                                         AS n_uid_pay,              -- 标量子查询：支付侧会员数
  (SELECT COUNT(*) FROM bet_uid)                                         AS n_uid_bet,              -- 标量子查询：注单侧会员数
  COUNT(*)                                                               AS n_matched,              -- 计数表达式：交集会员数
  ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM pay_uid), 0), 4) AS pct_pay_matched,        -- 比率表达式：支付侧被覆盖比率
  ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4) AS pct_bet_covered,        -- 比率表达式：★ 注单会员中有支付记录者之比率
  CASE                                                                                              -- 条件分支：起始分支——对齐性裁定
    WHEN COUNT(*) = 0                                                    THEN '❌ 编号体系不通，须先解'  -- 分支判定：零交集
    WHEN COUNT(*) * 1.0 / NULLIF((SELECT COUNT(*) FROM pay_uid), 0) < 0.50 THEN '⚠ 对齐不足半，判 PARTIAL' -- 分支判定：低对齐
    ELSE '✅ 可对齐'                                                                                 -- 分支判定：可用
  END                                                                    AS verdict_L4              -- 条件分支：收束上方判词，产出「verdict_L4」
FROM pay_uid p                                                                                      -- 取数来源：取自本条自建的中间结果集 pay_uid
JOIN bet_uid b ON b.uid = p.uid;                                                                    -- 连接：取自本条自建的中间结果集 bet_uid，连接键为 uid


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之四条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · 内部转账 ≠ 外部入金。
--   wallet_dtl（type 1加點/2扣點）与 aggregate_transaction 皆内部转账；
--   真正的外部资金流入在 payment_order。二者混用即口径错。
--   wallet_dtl 之价值在 cash 當前金額（余额快照），非在 money。
--
-- 锁二 · 登录 ≠ 会话（承裁示第七节）。
--   本库 mem_login 有 sid 与 on_line，惟无 logout_time 与 duration。
--   最高只得判 LOGIN_PROXY_ONLY；若 rows_per_member ≈ 1 则连事件流都不是，
--   仅为状态快照，登录频次亦不可算。
--
-- 锁三 · 有留痕 ≠ 有语义。
--   log_mem_change 之变更内容为自由文本＋原始 SQL，非结构化 before/after。
--   §V-4 只答「有多少、覆盖何时、涉及多少会员」，**不答「改了什么」**；
--   语义须待文本解析专项，且解析结果之证据等级不得高于 INFERRED。
--
-- 锁四 · 零命中之判词从严。
--   RG 于 667 列全扫零命中 → NOT_ESTABLISHED，**禁写 ABSENT／NO_TRACE**；
--   客服工单四张皆系统告警与配置 → UNKNOWN。
--   二者皆可能根本不在本库（另有 CRM／RG 系统），**未查之处不得下不存在裁定**。
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，**与 SQL 总包版号无涉**；
--   总包 canonical 仍为 v11.0.1，下一合法编号仍只能是 v11.0.2。
-- ══════════════════════════════════════════════════════════════════════════
