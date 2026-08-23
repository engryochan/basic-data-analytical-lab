-- ══════════════════════════════════════════════════════════════════════════
-- P-H0-8 · RG 孤例核验 ＋ 跨表语义扫描 ＋ 工单族翻案 v1.0.0（★ 零占位符）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · 状态 WORKING · 置放 审计/工具/ ★
-- ★ canonical = false · 不入 SQL 总包 · 结案前不得引用其结论 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 上游实测（P-H0-7 已跑，三条皆结案）：
--   §B-9   bet05 ⊆ member.mem001    723,557 / 723,557 = 100.0000%
--   §B-10  user ↔ member.mem002     463,405 / 463,478 =  99.9842%
--   §B-11  全链贯通                  329,714 / 723,557 =  45.5685%（≥ 30%）
--          → H1_FULL_COVERAGE = ESTABLISHED
--
-- ★ 措辞锁（承 REDTEAM 斧正，本件照录）：
--   §B-9 只证 BET_window ⊆ MEMBER，**不证 ALL_members ⊆ MEMBER**。
--   正式文书须写：「member.mem001 对本分析窗口内之注单会员达 100% 覆盖，
--   足以作本分析桥之权威编号侧」，**禁写「member 系会员全集」**。
--   §B-11 之 FULL_COVERAGE 意为「相对事先冻结之 ≥30% 门槛达 FULL 档」，
--   **非「钱包覆盖全部投注会员」**。
--
-- ★★ 本件另撤回一处**我方**判词（又一次未查列即下裁定）：
--   前判「alarmMessage／alertMessage 系系统告警与配置，非客服工单」——不成立。
--   实读其列：
--     alarmMessage  mid(會員)｜time｜type｜content(text)｜status｜is_send(發送 tg)
--     alertMessage  mid(會員)｜message(text)｜errorTime｜operator(操作者)｜
--                   status(0:未處理 1:已處理)
--   **两张皆带 mid，alertMessage 更具「会员＋消息＋处理人＋处理状态」四要素。**
--   → H-SRC-04 自 UNKNOWN 有翻案余地，本件 §T-1 验其体质。
--
-- ★★ 并因此坐实：RG 语义**只扫过 log_mem_change 一张表**。
--   未扫者：alarmMessage.content／alertMessage.message／alert_ip_setting.remarks／
--           member.mem028(備註)／wallet_dtl 之 detail、bet_detail、game_detail
--   承锁「未查之处不得下不存在裁定」→ RG 之 NOT_ESTABLISHED **尚未站稳**，
--   须俟本件 §R-2 跨表扫毕方可定谳。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §M-1 · member.mem002 空白核验（★ 承 REDTEAM：差一之因须由数据直证）
-- ▸ 导出：不需要 —— §M-1 核验读数，屏幕看结果。
--   ★ 缘由：§B-10 之 n_member_acct = 59,178,469，较 mem001 之 59,178,470 少一。
--     此只证 distinct 基数差一，**不足以解释为「有一名会员 mem002 为空」**。
--     可能之因有三：空串、纯空白、抑或两名会员共用同一 mem002。本条一并测。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'member · 全表'                                                        AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(mem001))                                           AS n_mem001,               -- 计数表达式：去重會員編號数
  COUNT(DISTINCT TRIM(mem002))                                           AS n_mem002_trimmed,       -- 计数表达式：去重帳號数（去空白后）
  COUNT(DISTINCT mem002)                                                 AS n_mem002_raw,           -- 计数表达式：★ 去重帳號数（未去空白）——与上者之差即空白之别
  SUM(CASE WHEN mem002 IS NULL THEN 1 ELSE 0 END)                        AS n_mem002_null,          -- 条件计数：因一：空值
  SUM(CASE WHEN mem002 IS NOT NULL AND TRIM(mem002) = '' THEN 1 ELSE 0 END) AS n_mem002_blank,      -- 条件计数：因二：空串或纯空白
  COUNT(*) - COUNT(DISTINCT TRIM(mem002))                                AS n_dup_or_blank_gap      -- 计算表达式：★ 因三：若非空非白，则系一账号对多会员
FROM ods_mariadb_2b.ods_a168_member;                                                                -- 取数来源：取自会员主表


-- ──────────────────────────────────────────────────────────────────────────
-- §R-1 · RG 孤例原文取出（★ rg_cooling_off = 1 之上下文核验）
-- ▸ 导出：需要 —— 存为「审计/_ph0/_PH0_8r1_rg_case.csv」（诊断留档，非交付件）。
--   ★ 缘由：P-H0-4 于 add 类得 rg_cooling_off = 1（1 / 107,839），系孤例。
--     「冷靜」二字或出自无关语境（人名、备注、系统语），n = 1 不支撑任何裁定。
--     须调原文看上下文，方能判 RG 升 INFERRED 抑或钉死 NOT_ESTABLISHED。
--   ★ 本条取原文全文，含 lmc09（原始 SQL）——留档时须留意其可能含敏感字段值。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  dt                                                                     AS dt_day,                 -- 取列：分区日
  TRIM(lmc04)                                                            AS category,               -- 取列：變更類別
  TRIM(lmc02)                                                            AS target_id,              -- 取列：被变更对象 ID
  TRIM(lmc06)                                                            AS operator_id,            -- 取列：操作者
  TRIM(lmc08)                                                            AS change_time,            -- 取列：異動時間
  TRIM(lmc10)                                                            AS operator_ip,            -- 取列：操作者 IP
  lmc05                                                                  AS content_full,           -- 取列：★ 內容全文——判语境之主据
  lmc09                                                                  AS sql_full                -- 取列：★ 原始 SQL 全文——判语境之佐证
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员变更日志表
WHERE CONCAT(COALESCE(lmc05, ''), COALESCE(lmc09, '')) LIKE '%冷靜%'                                 -- 过滤条件：繁体「冷靜」
   OR CONCAT(COALESCE(lmc05, ''), COALESCE(lmc09, '')) LIKE '%冷静%'                                 -- 并列条件：简体「冷静」
   OR CONCAT(COALESCE(lmc05, ''), COALESCE(lmc09, '')) LIKE '%cooling%'                             -- 并列条件：英文 cooling
ORDER BY dt, lmc08, lmc02                                                                           -- 排序：按分区日、異動時間、对象 ID 排列
LIMIT 50;                                                                                           -- 限行：孤例仅 1 条，取 50 行足以，免误取巨量


-- ──────────────────────────────────────────────────────────────────────────
-- §R-2 · RG 跨表语义扫描（★ 补齐前次只扫一表之缺口）
-- ▸ 导出：需要 —— 存为「审计/_ph0/_PH0_8r2_rg_crosstable.csv」（诊断留档）。
--   ★ 六处文本列一并扫，真 RG 组与商业管控组仍分列（承锁二：限红 ≠ 责任博彩）。
--   ★ 判读：
--     任一表之真 RG 组 > 0  → RG 升 INFERRED（仍须逐条核语境）
--     六表真 RG 组皆零      → RG 之 NOT_ESTABLISHED 方告站稳
--     **无论何者，皆不得写 ABSENT**——RG 系统可能根本不在本库。
-- ──────────────────────────────────────────────────────────────────────────
SELECT 'member.mem028(備註)'                                             AS src,                    -- 字面取值：受检文本源
       COUNT(*)                                                          AS n_rows,                 -- 计数表达式：总行数
       SUM(CASE WHEN mem028 LIKE '%自我排除%' OR mem028 LIKE '%冷靜%'
                  OR mem028 LIKE '%冷静%'     OR mem028 LIKE '%責任博彩%'
                  OR mem028 LIKE '%责任博彩%' THEN 1 ELSE 0 END)         AS n_rg_true,              -- 条件计数：★★ 真 RG 组
       SUM(CASE WHEN mem028 LIKE '%限額%' OR mem028 LIKE '%限额%'
                  OR mem028 LIKE '%凍結%' OR mem028 LIKE '%冻结%'
                  OR mem028 LIKE '%停用%' OR mem028 LIKE '%封鎖%'
                  OR mem028 LIKE '%封锁%' THEN 1 ELSE 0 END)             AS n_biz_control,          -- 条件计数：商业管控组（★ 非 RG）
       SUM(CASE WHEN mem028 IS NOT NULL AND TRIM(mem028) <> '' THEN 1 ELSE 0 END) AS n_nonblank     -- 条件计数：非空文本行数——判该列是否有料
FROM ods_mariadb_2b.ods_a168_member                                                                 -- 取数来源：取自会员主表
UNION ALL                                                                                           -- 纵向合并：接续下一文本源
SELECT 'alarmMessage.content',                                           COUNT(*),                  -- 字面取值与计数：告警消息内容
       SUM(CASE WHEN content LIKE '%自我排除%' OR content LIKE '%冷靜%'
                  OR content LIKE '%冷静%'     OR content LIKE '%責任博彩%'
                  OR content LIKE '%责任博彩%' THEN 1 ELSE 0 END),                                   -- 条件计数：真 RG 组
       SUM(CASE WHEN content LIKE '%限額%' OR content LIKE '%限额%'
                  OR content LIKE '%凍結%' OR content LIKE '%冻结%'
                  OR content LIKE '%停用%' OR content LIKE '%封鎖%'
                  OR content LIKE '%封锁%' THEN 1 ELSE 0 END),                                       -- 条件计数：商业管控组
       SUM(CASE WHEN content IS NOT NULL AND TRIM(content) <> '' THEN 1 ELSE 0 END)                 -- 条件计数：非空文本行数
FROM ods_mariadb_2b.ods_a168_alarmMessage                                                           -- 取数来源：取自告警消息表
UNION ALL                                                                                           -- 纵向合并：接续下一文本源
SELECT 'alertMessage.message',                                           COUNT(*),                  -- 字面取值与计数：警示消息正文
       SUM(CASE WHEN message LIKE '%自我排除%' OR message LIKE '%冷靜%'
                  OR message LIKE '%冷静%'     OR message LIKE '%責任博彩%'
                  OR message LIKE '%责任博彩%' THEN 1 ELSE 0 END),                                   -- 条件计数：真 RG 组
       SUM(CASE WHEN message LIKE '%限額%' OR message LIKE '%限额%'
                  OR message LIKE '%凍結%' OR message LIKE '%冻结%'
                  OR message LIKE '%停用%' OR message LIKE '%封鎖%'
                  OR message LIKE '%封锁%' THEN 1 ELSE 0 END),                                       -- 条件计数：商业管控组
       SUM(CASE WHEN message IS NOT NULL AND TRIM(message) <> '' THEN 1 ELSE 0 END)                 -- 条件计数：非空文本行数
FROM ods_mariadb_2b.ods_a168_alertMessage                                                           -- 取数来源：取自警示消息表
UNION ALL                                                                                           -- 纵向合并：接续下一文本源
SELECT 'alert_ip_setting.remarks',                                       COUNT(*),                  -- 字面取值与计数：IP 告警备注
       SUM(CASE WHEN remarks LIKE '%自我排除%' OR remarks LIKE '%冷靜%'
                  OR remarks LIKE '%冷静%'     OR remarks LIKE '%責任博彩%'
                  OR remarks LIKE '%责任博彩%' THEN 1 ELSE 0 END),                                   -- 条件计数：真 RG 组
       SUM(CASE WHEN remarks LIKE '%限額%' OR remarks LIKE '%限额%'
                  OR remarks LIKE '%凍結%' OR remarks LIKE '%冻结%'
                  OR remarks LIKE '%停用%' OR remarks LIKE '%封鎖%'
                  OR remarks LIKE '%封锁%' THEN 1 ELSE 0 END),                                       -- 条件计数：商业管控组
       SUM(CASE WHEN remarks IS NOT NULL AND TRIM(remarks) <> '' THEN 1 ELSE 0 END)                 -- 条件计数：非空文本行数
FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                                       -- 取数来源：取自 IP 告警设定表
UNION ALL                                                                                           -- 纵向合并：接续下一文本源
SELECT 'wallet_dtl.detail(窗内)',                                        COUNT(*),                  -- 字面取值与计数：钱包处理明细
       SUM(CASE WHEN detail LIKE '%自我排除%' OR detail LIKE '%冷靜%'
                  OR detail LIKE '%冷静%'     OR detail LIKE '%責任博彩%'
                  OR detail LIKE '%责任博彩%' THEN 1 ELSE 0 END),                                    -- 条件计数：真 RG 组
       SUM(CASE WHEN detail LIKE '%限額%' OR detail LIKE '%限额%'
                  OR detail LIKE '%凍結%' OR detail LIKE '%冻结%'
                  OR detail LIKE '%停用%' OR detail LIKE '%封鎖%'
                  OR detail LIKE '%封锁%' THEN 1 ELSE 0 END),                                        -- 条件计数：商业管控组
       SUM(CASE WHEN detail IS NOT NULL AND TRIM(detail) <> '' THEN 1 ELSE 0 END)                   -- 条件计数：非空文本行数
FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                             -- 取数来源：取自钱包明细表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限窗，免全表 1.146 亿行之扫描
ORDER BY n_rg_true DESC, src;                                                                       -- 排序：按真 RG 命中降序、源名升序排列


-- ──────────────────────────────────────────────────────────────────────────
-- §T-1 · 工单族体质验货（★ H-SRC-04 之翻案，承本件卷首之撤回）
-- ▸ 导出：不需要 —— §T-1 体质读数，屏幕看结果。
--   ★ 三问：有无会员级记录 ／ 窗内覆盖 ／ 处理状态是否成对（未處理／已處理）。
--   ★ 判读：
--     mid 覆盖注单会员达可用比率 且 status 有分布 → H-SRC-04 自 UNKNOWN 升 PARTIAL
--     行数极小或 mid 近乎全空                     → 仍 UNKNOWN，不得写 ABSENT
--   ★ alertMessage 具 operator 与「未處理／已處理」，最具工单相；alarmMessage
--     具 is_send（發送 tg），更近乎告警推送。二者性质或不同，须分列不合并。
-- ──────────────────────────────────────────────────────────────────────────
SELECT 'alarmMessage'                                                    AS tbl,                    -- 字面取值：受检表名
       COUNT(*)                                                          AS n_rows,                 -- 计数表达式：总行数
       COUNT(DISTINCT TRIM(mid))                                         AS n_mid,                  -- 计数表达式：★ 去重会员数
       MIN(dt)                                                           AS dt_min,                 -- 聚合取值：分区日下界
       MAX(dt)                                                           AS dt_max,                 -- 聚合取值：分区日上界
       SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win,       -- 条件计数：窗内行数
       COUNT(DISTINCT TRIM(type))                                        AS n_type,                 -- 计数表达式：★ 告警类型数——判其是否分门别类
       COUNT(DISTINCT TRIM(status))                                      AS n_status,               -- 计数表达式：状态取值数
       ROUND(AVG(LENGTH(COALESCE(content, ''))), 2)                      AS avg_len_text,           -- 聚合取值：正文平均长度——判其是否有实质内容
       ROUND(SUM(CASE WHEN TRIM(mid) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
             / NULLIF(COUNT(*), 0), 4)                                   AS pct_mid_numeric         -- 比率表达式：会员键纯数字率——决定能否连 bet05
FROM ods_mariadb_2b.ods_a168_alarmMessage                                                           -- 取数来源：取自告警消息表
UNION ALL                                                                                           -- 纵向合并：接续下一受检表
SELECT 'alertMessage',                                                   COUNT(*),                  -- 字面取值与计数：警示消息表
       COUNT(DISTINCT TRIM(mid)),                                                                   -- 计数表达式：去重会员数
       MIN(dt),                                                          MAX(dt),                   -- 聚合取值：分区日上下界
       SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END),                   -- 条件计数：窗内行数
       COUNT(DISTINCT TRIM(operator)),                                                              -- 计数表达式：★ 此处为操作者数（非类型）——本表无 type 列
       COUNT(DISTINCT TRIM(status)),                                                                -- 计数表达式：状态取值数
       ROUND(AVG(LENGTH(COALESCE(message, ''))), 2),                                                -- 聚合取值：正文平均长度
       ROUND(SUM(CASE WHEN TRIM(mid) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
             / NULLIF(COUNT(*), 0), 4)                                                              -- 比率表达式：会员键纯数字率
FROM ods_mariadb_2b.ods_a168_alertMessage                                                           -- 取数来源：取自警示消息表
ORDER BY tbl;                                                                                       -- 排序：按表名排列


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之五条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · **未查列即下裁定，两犯**（本件之核心自省）。
--   一犯：凭表名判 log_mem_change 无 mem016／mem017 → 实则在其文本内。
--   二犯：凭表名判 alarmMessage／alertMessage 系配置 → 实则皆带 mid 之会员级事件。
--   → 立规：凡对某表下「性质裁定」，须先读毕其**全列与 COLUMN_COMMENT**；
--     未读列而以表名断性质者，其裁定一律不成立。
--
-- 锁二 · 覆盖之措辞须连口径（承 REDTEAM 斧正）。
--   §B-9 只证 BET_window ⊆ MEMBER；禁写「member 系会员全集」。
--   §B-11 之 FULL_COVERAGE 意为「达事先冻结之 ≥30% 门槛」；
--   禁写「钱包覆盖全部投注会员」。
--
-- 锁三 · 差一之因须由数据直证（承 REDTEAM 斧正）。
--   59,178,470 − 59,178,469 = 1 只证 distinct 基数差一；
--   空值、空白、抑或一账号对多会员，三因未分，不得择一而述。§M-1 即此。
--
-- 锁四 · 限红 ≠ 责任博彩（续锁）。
--   真 RG 组：自我排除／冷靜期／責任博彩——会员自我保护
--   商业管控组：限額／凍結／停用／封鎖——平台限制会员
--   二者性质相反，永不合并计数。
--
-- 锁五 · 未查之处不得下不存在裁定。
--   RG 前仅扫 log_mem_change 一表，故其 NOT_ESTABLISHED 尚未站稳；
--   须俟 §R-2 六处文本扫毕方可定谳。**无论结果为何，皆不得写 ABSENT。**
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，**与 SQL 总包版号无涉**；
--   总包 canonical 仍 v11.0.1，下一合法编号仍只能 v11.0.2（读法甲）。
-- ══════════════════════════════════════════════════════════════════════════
