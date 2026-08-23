-- ══════════════════════════════════════════════════════════════════════════
-- P-H0-4 · RG 拆词 ＋ 钱包余额轨迹 ＋ 桥接探查 v1.0.0（★ 零占位符，可直接运行）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · 状态 WORKING · 置放 审计/工具/ ★
-- ★ canonical = false · 不入 SQL 总包 · 结案前不得引用其结论 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 上游实测（P-H0-3 已跑，本件承其结果）：
--   payment_order    0 行                        → DEPOSIT_PRIMARY = BLOCKED/EMPTY
--   wallet_dtl       114,604,112 行／506,896 user／窗内 102,923,215
--                    cash 非空 100%｜user 纯数字仅 1.8026%
--                    type：加點 35,439,986／扣點 79,163,720／取餘額 0
--                    status：成功 113,399,761／失敗 10,447／回滾 1,192,795
--   mem_login        57,614,693 行 ＝ 57,614,693 member → rows_per_member = 1
--                    ★ 状态快照，非事件流；sid 25,895,924；窗内仅 3,717,980
--   log_mem_change   edit 499,607／add 107,839／changestatus 79,572
--                    ★ 窗内合计仅 8,707（约 1.3%），表跨 2017-07-25 至 2026-08-22
--
-- ★ 本件修两处**探针自身**之缺陷（非数据之缺陷）：
--   R4-1 V-5 判词未先判分母：n_uid_pay = 0 时交集必零，系结构性零，
--        不得判「编号体系不通」。→ 本件 §L-2 之判词已加分母前置判定。
--   R4-2 §V-4 之 RG 正则过粗：将「自我排除／冷靜期／責任博彩」（真 RG）与
--        「限額／凍結／停用／封鎖」（商业管控处置）混为一条。
--        限红是商业限额，**不是责任博彩**。535 条命中不足以判 RG = INFERRED。
--        → 本件 §V-4b 逐词拆解，两组分列，不再合并计数。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §V-4b · RG 语义逐词拆解（★ 真 RG 与商业管控须分列，禁合并计数）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_4b_rg_keyword.csv」（诊断留档，非交付件）。
--   ★ 判读铁律：
--     真 RG 组（自我排除／冷靜期／責任博彩）命中 > 0  → RG 可升 INFERRED
--     仅商业管控组命中                              → RG 仍 NOT_ESTABLISHED
--     两组皆零                                     → RG 仍 NOT_ESTABLISHED
--   ★ 无论何者，**皆不得写 ABSENT／NO_TRACE**：RG 系统可能根本不在本库。
--   ★ 简繁并列：本库注释为繁体（見「異動時間」「處理金錢」），故繁体在前。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  COALESCE(NULLIF(TRIM(lmc04), ''), '（空）')                            AS lmc04_category,         -- 取值表达式：變更類別
  COUNT(*)                                                               AS n_events,               -- 计数表达式：该类事件总数
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%自我排除%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%self_exclu%'
           THEN 1 ELSE 0 END)                                            AS rg_self_exclusion,      -- 条件计数：★★ 真 RG——自我排除
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%冷靜%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%冷静%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%cooling%'
           THEN 1 ELSE 0 END)                                            AS rg_cooling_off,         -- 条件计数：★★ 真 RG——冷静期
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%責任博彩%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%责任博彩%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%responsible%'
           THEN 1 ELSE 0 END)                                            AS rg_responsible,         -- 条件计数：★★ 真 RG——责任博彩
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%限額%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%限额%'
           THEN 1 ELSE 0 END)                                            AS biz_limit,              -- 条件计数：商业管控——限额（★ 非 RG）
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%凍結%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%冻结%'
           THEN 1 ELSE 0 END)                                            AS biz_freeze,             -- 条件计数：商业管控——冻结
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%停用%'
           THEN 1 ELSE 0 END)                                            AS biz_disable,            -- 条件计数：商业管控——停用
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%封鎖%'
            OR CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%封锁%'
           THEN 1 ELSE 0 END)                                            AS biz_block,              -- 条件计数：商业管控——封锁
  SUM(CASE WHEN CONCAT(COALESCE(lmc05,''), COALESCE(lmc09,'')) LIKE '%排除%'
           THEN 1 ELSE 0 END)                                            AS amb_exclude_any,        -- 条件计数：★ 歧义词——「排除」单独出现，须人工判其上下文
  SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win             -- 条件计数：窗内事件数
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员变更日志表
GROUP BY COALESCE(NULLIF(TRIM(lmc04), ''), '（空）')                                                 -- 分组：按變更類別汇总
ORDER BY n_events DESC, lmc04_category;                                                             -- 排序：按事件数降序、類別升序排列


-- ──────────────────────────────────────────────────────────────────────────
-- §V-4c · log_mem_change 窗内会员覆盖率（★ 8,707 事件覆盖多少注单会员）
-- ▸ 导出：不需要 —— §V-4c 覆盖率读数，屏幕看结果。
--   ★ 判读：窗内事件仅约 1.3%，若其涉及会员数相对 723,557 名注单会员极小，
--     则 log_mem_change 纵有留痕，对 H 轴之**覆盖面**仍不足，只得作个案证据。
--   ★ 承 R4-1 之教训：本条先报两侧基数，再报交集，不以零交集直接下体系裁定。
-- ──────────────────────────────────────────────────────────────────────────
WITH lmc_uid AS (                                                                                   -- 公共表表达式：开启中间结果集 lmc_uid——变更日志侧之目标会员
  SELECT DISTINCT CAST(NULLIF(TRIM(lmc02), '') AS BIGINT)                AS uid                     -- 取列：被变更对象 ID（lmc02 = ID）
  FROM ods_mariadb_2b.ods_a168_log_mem_change                                                       -- 取数来源：取自会员变更日志表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND TRIM(lmc02) REGEXP '^[0-9]+$'                                                               -- 并列条件：只取纯数字者
    AND CAST(NULLIF(TRIM(lmc02), '') AS BIGINT) > 0                                                 -- 并列条件：排除零
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bet_uid AS (                                                                                        -- 公共表表达式：开启中间结果集 bet_uid——注单侧会员全集
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)                AS uid                     -- 取列：会员编号
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet05), '') AS BIGINT) > 0                                                 -- 并列条件：排除零与空
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'log_mem_change.lmc02 ↔ bet02.bet05'                                   AS pair,                   -- 字面取值：受检对齐对
  (SELECT COUNT(*) FROM lmc_uid)                                         AS n_uid_lmc,              -- 标量子查询：★ 分母一——变更侧会员数
  (SELECT COUNT(*) FROM bet_uid)                                         AS n_uid_bet,              -- 标量子查询：★ 分母二——注单侧会员数
  (SELECT COUNT(*) FROM lmc_uid l JOIN bet_uid b ON b.uid = l.uid)       AS n_matched,              -- 标量子查询：交集会员数
  ROUND((SELECT COUNT(*) FROM lmc_uid l JOIN bet_uid b ON b.uid = l.uid) * 100.0
        / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4)                  AS pct_bet_covered,        -- 比率表达式：★ 注单会员被变更日志覆盖之比率
  CASE                                                                                              -- 条件分支：起始分支——★ R4-1 之修复：分母前置判定
    WHEN (SELECT COUNT(*) FROM lmc_uid) = 0                              THEN 'NON_DIAGNOSTIC（变更侧空集，不得下体系裁定）' -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM bet_uid) = 0                              THEN 'NON_DIAGNOSTIC（注单侧空集）'               -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM lmc_uid l JOIN bet_uid b ON b.uid = l.uid) = 0 THEN '❌ 两侧皆非空而交集为零——此方为编号体系不通之证据' -- 分支判定：经验性零
    ELSE '✅ 可对齐（覆盖面另判）'                                                                   -- 分支判定：可用
  END                                                                    AS verdict_L4              -- 条件分支：收束上方判词，产出「verdict_L4」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ──────────────────────────────────────────────────────────────────────────
-- §W-1 · wallet_dtl 余额轨迹结构验证（承裁示第七节之八问）
-- ▸ 导出：不需要 —— §W-1 结构读数，屏幕看结果。
--   ★ 100% 非空 ≠ 100% 可重建时序。本条答：
--     ① 同一 user 有无多时间点 → rows_per_user
--     ② 时间列可用与否        → requestDate／responseDate 非空率
--     ③ 可否排序              → 时间列格式合规率
--     ④⑤ cash 与 money 之关系  → 加點／扣點两态下之 cash 均值
--     ⑥ 失败与回滚如何处置    → status 分层之 cash 非空率
--     ⑦ 有无重复              → 单 user 单秒多行之比率
--   ★ 限窗执行，免全表 1.146 亿行之扫描代价。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'wallet_dtl · 窗内'                                                    AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：窗内行数
  COUNT(DISTINCT TRIM(`user`))                                           AS n_user,                 -- 计数表达式：窗内去重账号数
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT TRIM(`user`)), 0), 2)     AS rows_per_user,          -- 比率表达式：★ ① 人均行数——远大于 1 方可谈时序
  ROUND(SUM(CASE WHEN TRIM(requestDate)  <> '' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_reqdate_notnull,    -- 比率表达式：② 我方請求時間非空率
  ROUND(SUM(CASE WHEN TRIM(responseDate) <> '' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_rspdate_notnull,    -- 比率表达式：② 對方回應時間非空率
  ROUND(SUM(CASE WHEN TRIM(requestDate) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} ' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_reqdate_wellform,   -- 比率表达式：★ ③ 时间格式合规率——决定可否排序
  ROUND(AVG(CASE WHEN TRIM(type) = '1' THEN CAST(NULLIF(TRIM(cash), '') AS DOUBLE) END), 4) AS avg_cash_on_credit, -- 聚合取值：④ 加點行之 cash 均值
  ROUND(AVG(CASE WHEN TRIM(type) = '2' THEN CAST(NULLIF(TRIM(cash), '') AS DOUBLE) END), 4) AS avg_cash_on_debit,  -- 聚合取值：④ 扣點行之 cash 均值
  ROUND(AVG(CASE WHEN TRIM(type) = '1' THEN CAST(NULLIF(TRIM(money), '') AS DOUBLE) END), 4) AS avg_money_credit,  -- 聚合取值：⑤ 加點行之處理金額均值
  ROUND(AVG(CASE WHEN TRIM(type) = '2' THEN CAST(NULLIF(TRIM(money), '') AS DOUBLE) END), 4) AS avg_money_debit,   -- 聚合取值：⑤ 扣點行之處理金額均值
  ROUND(SUM(CASE WHEN TRIM(status) = '1' AND TRIM(cash) <> '' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN TRIM(status) = '1' THEN 1 ELSE 0 END), 0), 4) AS pct_cash_when_ok,   -- 比率表达式：⑥ 成功态之 cash 非空率
  ROUND(SUM(CASE WHEN TRIM(status) = '3' AND TRIM(cash) <> '' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN TRIM(status) = '3' THEN 1 ELSE 0 END), 0), 4) AS pct_cash_when_rollback, -- 比率表达式：⑥ ★ 回滾态之 cash 非空率——回滾行若入序列即污染轨迹
  SUM(CASE WHEN TRIM(status) = '3' THEN 1 ELSE 0 END)                    AS n_rollback_in_win       -- 条件计数：⑦ 窗内回滾行数
FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                             -- 取数来源：取自钱包明细表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07';                                                     -- 过滤条件：限定分析窗，免全表扫描


-- ──────────────────────────────────────────────────────────────────────────
-- §W-2 · 单日单账号之余额点数分布（★ 决定余额轨迹之时间分辨率）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_4w2_balance_points.csv」（诊断留档）。
--   ★ 判读：每人每日余额点数若中位仅 1~2，则日内轨迹不可建，只得做日频；
--     若中位数十，则 ΔCash 与 Drawdown 皆可逐笔算。
--   ★ 取单日切片（2026-06-15），免全窗聚合之代价；该日为窗中段，非端点。
-- ──────────────────────────────────────────────────────────────────────────
WITH per_user AS (                                                                                  -- 公共表表达式：开启中间结果集 per_user——单日逐账号之点数
  SELECT TRIM(`user`)                                                    AS u,                      -- 取列：账号
         COUNT(*)                                                        AS n_pts,                  -- 计数表达式：该账号当日行数
         SUM(CASE WHEN TRIM(status) = '1' THEN 1 ELSE 0 END)             AS n_pts_ok                -- 条件计数：其中成功态行数
  FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                           -- 取数来源：取自钱包明细表
  WHERE dt = '2026-06-15'                                                                           -- 过滤条件：限定单日切片（窗中段）
  GROUP BY TRIM(`user`)                                                                             -- 分组：按账号汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  '2026-06-15'                                                           AS dt_slice,               -- 字面取值：切片日
  COUNT(*)                                                               AS n_user_active,          -- 计数表达式：当日活跃账号数
  SUM(n_pts)                                                             AS n_pts_total,            -- 聚合取值：当日总行数
  ROUND(AVG(n_pts), 2)                                                   AS pts_avg,                -- 聚合取值：人均点数
  MIN(n_pts)                                                             AS pts_min,                -- 聚合取值：点数下界
  PERCENTILE_APPROX(n_pts, 0.50)                                         AS pts_p50,                -- 聚合取值：★ 点数中位——决定日内轨迹可否建
  PERCENTILE_APPROX(n_pts, 0.90)                                         AS pts_p90,                -- 聚合取值：点数九十分位
  PERCENTILE_APPROX(n_pts, 0.99)                                         AS pts_p99,                -- 聚合取值：点数九九分位
  MAX(n_pts)                                                             AS pts_max,                -- 聚合取值：点数上界
  ROUND(AVG(n_pts_ok), 2)                                                AS pts_ok_avg,             -- 聚合取值：人均成功态点数
  SUM(CASE WHEN n_pts = 1 THEN 1 ELSE 0 END)                             AS n_user_single_pt,       -- 条件计数：★ 当日仅一个点之账号数——其轨迹不可建
  ROUND(SUM(CASE WHEN n_pts = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_single_pt           -- 比率表达式：单点账号占比
FROM per_user;                                                                                      -- 取数来源：取自本条自建的中间结果集 per_user


-- ──────────────────────────────────────────────────────────────────────────
-- §L-1 · member 主表列清单（★ 寻 wallet_dtl.user → 会员编号之桥）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_4L1_member_columns.csv」（诊断留档）。
--   ★ 缘由：wallet_dtl.user 纯数字仅 1.8026%，系账号字符串，不可直连 bet05。
--     裁示所示之桥「wallet_id → payment_order.mid」因 payment_order 空表而断。
--     故须另寻：member 主表若同时具「账号」与「会员编号」两列，即为桥。
--   ★ 本条只列 member 之全列与注释，**不作任何语义断言**；
--     哪一列是账号、哪一列是编号，须读 COLUMN_COMMENT 后于下一刀实测对齐。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  c.TABLE_NAME                                                           AS table_name,             -- 取列：表名
  c.ORDINAL_POSITION                                                     AS col_pos,                -- 取列：列序
  c.COLUMN_NAME                                                          AS column_name,            -- 取列：列名
  c.DATA_TYPE                                                            AS data_type,              -- 取列：数据类型
  c.COLUMN_COMMENT                                                       AS column_comment          -- 取列：列注释——编码列唯一可读之语义线索
FROM information_schema.columns c                                                                   -- 取数来源：取自元数据字典（列清单）
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
  AND c.TABLE_NAME IN ('ods_a168_member', 'ods_a168_member_dtl', 'ods_a168_member_url')             -- 并列条件：限定三张会员主表
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;                                                          -- 排序：按表名、列序排列；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之五条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · 结构性零 ≠ 经验性零（R4-1）。
--   分母为零时之零交集，只证「一侧无数据」，不证「编号体系不通」。
--   凡对齐类判词，须先判两侧基数，再判交集。§V-4c 已内建此前置判定。
--
-- 锁二 · 限红 ≠ 责任博彩（R4-2）。
--   「限額／凍結／停用／封鎖」系**平台商业管控处置**；
--   「自我排除／冷靜期／責任博彩」方为**会员自我保护**。
--   仅商业管控组命中者，RG 仍 NOT_ESTABLISHED，不得升 INFERRED。
--
-- 锁三 · 内部钱包 ≠ 外部入金（承 P-H0-3）。
--   wallet_dtl 之 type 1加點／2扣點 系内部转账；payment_order 空表；
--   故 deposit／failed_deposit／withdrawal 于本库**不可直接观测**。
--   凡以 wallet_dtl 充作「充值／提款记录」者，判 S1。
--
-- 锁四 · 非空 ≠ 可重建。
--   cash 非空 100% 只证「每行都有余额值」；能否成序列，取决于
--   人均点数、时间列合规率、回滾行之处置。三者皆过方可谈 ΔCash 与 Drawdown。
--
-- 锁五 · 覆盖面独立于存在性。
--   log_mem_change 有 687,018 条历史留痕，惟窗内仅约 8,707（1.3%）。
--   「表中有记录」与「窗内覆盖足够会员」是两个命题；后者由 §V-4c 定。
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，**与 SQL 总包版号无涉**；
--   总包 canonical 仍 v11.0.1，下一合法编号仍只能 v11.0.2（读法甲）。
-- ══════════════════════════════════════════════════════════════════════════
