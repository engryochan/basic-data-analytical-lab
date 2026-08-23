-- ══════════════════════════════════════════════════════════════════════════
-- P-H0-5 · 桥接验证 ＋ member 快照性质 v1.0.0（★ 零占位符，可直接运行）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · 状态 WORKING · 置放 审计/工具/ ★
-- ★ canonical = false · 不入 SQL 总包 · 结案前不得引用其结论 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 上游实测（P-H0-3／P-H0-4 已跑，本件承其结果）：
--   RG 拆词        535 条全为 biz_disable（商业停用）；真 RG 三词合计 1 条孤例
--                  → RG = NOT_ESTABLISHED（★ 禁写 ABSENT）
--   log_mem_change lmc02 ↔ bet05 编号体系**通**（661 交集），惟覆盖仅 0.0914%
--                  → 只得作个案证据，不可作全体判据
--   wallet_dtl     窗内 1.029 亿行／464,533 账号／人均 221.56 行
--                  requestDate 非空与格式合规皆 100% → ★ 可排序
--                  ★★ 回滾行 cash 亦 100% 非空，窗内 1,046,940 条
--                     → 建轨迹**必须 status = 1 过滤**，否则虚假跳变污染 ΔCash
--   单日切片        pts_p50 = 15 → ★ 日内轨迹可建；单点账号占 9.75%
--   member_url     同具 mid（會員編號）与 account（會員帳號）→ ★★★ 桥之候选
--   member         mem016 = enable、mem017 = canbet **系 member 之列**
--                  （log_mem_change 文本提及者，系其修改 member 之 SQL）
--
-- ★ 本件答唯一剩余之阻断：**wallet_dtl.user 能否连到 bet05**。
--   连不上，则 1.029 亿行钱包数据与会员、注单皆无从对齐，H1 层形同虚设。
--   承 §EX-18d 之血账（wallet_dtl.user 直连 bet05 仅 0.66%），本件逐跳实测，
--   **不以任何一跳之成立推定全链成立**。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §B-1 · member_url 桥表体质（★ 一 mid 一 account 抑或多对多）
-- ▸ 导出：不需要 —— §B-1 桥表体质读数，屏幕看结果。
--   ★ 判读：桥表须近乎一一对应方可作映射；若一 account 对多 mid，
--     则映射有歧义，须先定去重规则（取最新？取唯一？），否则连接即放大行数。
--   ★ 本表无窗内窗外之别（系配置性映射表），故全表读。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'member_url'                                                           AS tbl,                    -- 字面取值：受检表名
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT TRIM(mid))                                              AS n_mid,                  -- 计数表达式：去重會員編號数
  COUNT(DISTINCT TRIM(account))                                          AS n_account,              -- 计数表达式：去重會員帳號数
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT TRIM(account)), 0), 4)    AS rows_per_account,       -- 比率表达式：★ 逼近 1 即一一对应，大于 1 即须去重
  ROUND(COUNT(DISTINCT TRIM(mid)) * 1.0
        / NULLIF(COUNT(DISTINCT TRIM(account)), 0), 4)                   AS mid_per_account,        -- 比率表达式：★ 大于 1 即一账号对多编号，映射有歧义
  ROUND(SUM(CASE WHEN TRIM(mid) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_mid_numeric,        -- 比率表达式：编号纯数字率——决定能否 CAST 后连 bet05
  ROUND(SUM(CASE WHEN TRIM(account) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_account_numeric,    -- 比率表达式：账号纯数字率——与 wallet_dtl.user 之 1.8026% 对照
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：分区日下界
  MAX(dt)                                                                AS dt_max                  -- 聚合取值：分区日上界
FROM ods_mariadb_2b.ods_a168_member_url;                                                            -- 取数来源：取自会员网址映射表


-- ──────────────────────────────────────────────────────────────────────────
-- §B-2 · 第一跳：wallet_dtl.user ↔ member_url.account（★ 决定性一跳）
-- ▸ 导出：不需要 —— §B-2 第一跳对齐率，屏幕看结果。
--   ★ 判读（承 R4-1 之锁，分母前置判定）：
--     两侧任一为空集            → NON_DIAGNOSTIC，不得下体系裁定
--     两侧皆非空而交集为零      → 此方为「账号体系不通」之证据
--     交集非零                  → 报覆盖率，覆盖面另判
--   ★ 若本跳不通，则 wallet_dtl 之 1.029 亿行无从连会员，H1 层即告失守。
-- ──────────────────────────────────────────────────────────────────────────
WITH w_user AS (                                                                                    -- 公共表表达式：开启中间结果集 w_user——钱包侧账号全集
  SELECT DISTINCT TRIM(`user`)                                           AS acct                    -- 取列：钱包侧账号字符串
  FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                           -- 取数来源：取自钱包明细表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND TRIM(`user`) <> ''                                                                          -- 并列条件：排除空账号
),                                                                                                  -- 续行：收束上方的子查询或函数括号
m_acct AS (                                                                                         -- 公共表表达式：开启中间结果集 m_acct——桥表侧账号全集
  SELECT DISTINCT TRIM(account)                                          AS acct                    -- 取列：桥表侧账号字符串
  FROM ods_mariadb_2b.ods_a168_member_url                                                           -- 取数来源：取自会员网址映射表
  WHERE TRIM(account) <> ''                                                                         -- 过滤条件：排除空账号
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'wallet_dtl.user ↔ member_url.account'                                 AS hop,                    -- 字面取值：受检跳次
  (SELECT COUNT(*) FROM w_user)                                          AS n_wallet_acct,          -- 标量子查询：分母一——钱包侧账号数
  (SELECT COUNT(*) FROM m_acct)                                          AS n_bridge_acct,          -- 标量子查询：分母二——桥表侧账号数
  (SELECT COUNT(*) FROM w_user w JOIN m_acct m ON m.acct = w.acct)       AS n_matched,              -- 标量子查询：交集账号数
  ROUND((SELECT COUNT(*) FROM w_user w JOIN m_acct m ON m.acct = w.acct) * 100.0
        / NULLIF((SELECT COUNT(*) FROM w_user), 0), 4)                   AS pct_wallet_matched,     -- 比率表达式：★ 钱包账号可映射之比率
  CASE                                                                                              -- 条件分支：起始分支——分母前置判定
    WHEN (SELECT COUNT(*) FROM w_user) = 0                               THEN 'NON_DIAGNOSTIC（钱包侧空集）'          -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM m_acct) = 0                               THEN 'NON_DIAGNOSTIC（桥表侧空集）'          -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM w_user w JOIN m_acct m ON m.acct = w.acct) = 0
      THEN '❌ 两侧皆非空而交集为零——账号体系不通'                                                    -- 分支判定：经验性零
    ELSE '✅ 第一跳通（覆盖面另判）'                                                                 -- 分支判定：可用
  END                                                                    AS verdict_hop1            -- 条件分支：收束上方判词，产出「verdict_hop1」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ──────────────────────────────────────────────────────────────────────────
-- §B-3 · 全链三跳：wallet_dtl.user → account → mid → bet05
-- ▸ 导出：不需要 —— §B-3 全链贯通率，屏幕看结果。
--   ★ 铁律：**不以任何一跳之成立推定全链成立**。本条直接测端到端。
--     全链贯通率方为 H1 层可用与否之定谳；单跳通而全链不通者，仍属不可用。
-- ──────────────────────────────────────────────────────────────────────────
WITH bridge AS (                                                                                    -- 公共表表达式：开启中间结果集 bridge——账号到编号之映射
  SELECT DISTINCT TRIM(account)                                          AS acct,                   -- 取列：會員帳號
         CAST(NULLIF(TRIM(mid), '') AS BIGINT)                           AS uid                     -- 取列：會員編號，转整型
  FROM ods_mariadb_2b.ods_a168_member_url                                                           -- 取数来源：取自会员网址映射表
  WHERE TRIM(account) <> ''                                                                         -- 过滤条件：排除空账号
    AND TRIM(mid) REGEXP '^[0-9]+$'                                                                 -- 并列条件：编号须纯数字
    AND CAST(NULLIF(TRIM(mid), '') AS BIGINT) > 0                                                   -- 并列条件：排除零
),                                                                                                  -- 续行：收束上方的子查询或函数括号
w_user AS (                                                                                         -- 公共表表达式：开启中间结果集 w_user——钱包侧账号全集
  SELECT DISTINCT TRIM(`user`)                                           AS acct                    -- 取列：钱包侧账号
  FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                           -- 取数来源：取自钱包明细表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND TRIM(`user`) <> ''                                                                          -- 并列条件：排除空账号
    AND TRIM(status) = '1'                                                                          -- 并列条件：★ 只取成功态，承 §W-1 之回滾污染锁
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bet_uid AS (                                                                                        -- 公共表表达式：开启中间结果集 bet_uid——注单侧会员全集
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)                AS uid                     -- 取列：会员编号
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet05), '') AS BIGINT) > 0                                                 -- 并列条件：排除零与空
),                                                                                                  -- 续行：收束上方的子查询或函数括号
chain AS (                                                                                          -- 公共表表达式：开启中间结果集 chain——端到端贯通之账号
  SELECT DISTINCT w.acct                                                 AS acct,                   -- 取列：贯通之账号
         g.uid                                                           AS uid                     -- 取列：其对应之会员编号
  FROM w_user w                                                                                     -- 取数来源：取自本条自建的中间结果集 w_user
  JOIN bridge  g ON g.acct = w.acct                                                                 -- 连接：第一跳，账号对账号
  JOIN bet_uid b ON b.uid  = g.uid                                                                  -- 连接：第二跳，编号对编号
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'wallet.user → account → mid → bet05'                                  AS full_chain,             -- 字面取值：受检全链
  (SELECT COUNT(*) FROM w_user)                                          AS n_wallet_acct,          -- 标量子查询：钱包侧账号数（成功态）
  (SELECT COUNT(*) FROM bridge)                                          AS n_bridge_pair,          -- 标量子查询：桥表映射对数
  (SELECT COUNT(*) FROM bet_uid)                                         AS n_bet_uid,              -- 标量子查询：注单侧会员数
  (SELECT COUNT(DISTINCT acct) FROM chain)                               AS n_chain_acct,           -- 标量子查询：★ 端到端贯通之账号数
  (SELECT COUNT(DISTINCT uid)  FROM chain)                               AS n_chain_uid,            -- 标量子查询：★ 端到端贯通之会员数
  ROUND((SELECT COUNT(DISTINCT acct) FROM chain) * 100.0
        / NULLIF((SELECT COUNT(*) FROM w_user), 0), 4)                   AS pct_wallet_reachable,   -- 比率表达式：★ 钱包账号可达注单之比率
  ROUND((SELECT COUNT(DISTINCT uid) FROM chain) * 100.0
        / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4)                  AS pct_bet_covered,        -- 比率表达式：★★ 注单会员有钱包轨迹之比率——H1 层之覆盖面定谳
  CASE                                                                                              -- 条件分支：起始分支——全链裁定
    WHEN (SELECT COUNT(*) FROM w_user) = 0 OR (SELECT COUNT(*) FROM bridge) = 0
      THEN 'NON_DIAGNOSTIC（某侧空集）'                                                              -- 分支判定：结构性零
    WHEN (SELECT COUNT(DISTINCT uid) FROM chain) = 0
      THEN '❌ 全链不通——H1 钱包层不可用'                                                            -- 分支判定：经验性零
    WHEN (SELECT COUNT(DISTINCT uid) FROM chain) * 1.0
         / NULLIF((SELECT COUNT(*) FROM bet_uid), 0) < 0.30
      THEN '⚠ 全链通惟覆盖不足三成——H1 只得作个案证据'                                               -- 分支判定：低覆盖
    ELSE '✅ 全链通且覆盖可用——H1 钱包层成立'                                                        -- 分支判定：可用
  END                                                                    AS verdict_chain           -- 条件分支：收束上方判词，产出「verdict_chain」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ──────────────────────────────────────────────────────────────────────────
-- §B-4 · member 表之快照性质（★ 逐日快照抑或单份现况）
-- ▸ 导出：不需要 —— §B-4 快照性质读数，屏幕看结果。
--   ★ 缘由：member 具 cash 現金／money 己出碼額度／lockmoney 鎖定金額，
--     且具 mem016 enable／mem017 canbet／mem024 mem_risk。
--     若其为**逐日快照**（每日一份全量），则：
--       ① member.cash 逐日即成第二条余额轨迹（日频，与 wallet_dtl 之笔频互证）
--       ② mem016／mem017 之逐日比对即得**状态变更事件流**，
--          远胜 log_mem_change 之 0.0914% 覆盖
--     若其为单份现况，则以上皆不可得，只能作截面。
--   ★ 判读：rows_per_dt ≈ n_member_total → 逐日全量快照
--            n_dt = 1                    → 单份现况
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'member'                                                               AS tbl,                    -- 字面取值：受检表名
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：总行数
  COUNT(DISTINCT dt)                                                     AS n_dt,                   -- 计数表达式：★ 分区日数——为 1 即单份现况
  COUNT(DISTINCT TRIM(mem001))                                           AS n_member,               -- 计数表达式：去重会员数
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT dt), 0), 2)               AS rows_per_dt,            -- 比率表达式：★ 逼近会员数即逐日全量快照
  MIN(dt)                                                                AS dt_min,                 -- 聚合取值：分区日下界
  MAX(dt)                                                                AS dt_max,                 -- 聚合取值：分区日上界
  SUM(CASE WHEN dt >= '2026-03-21' AND dt < '2026-08-07' THEN 1 ELSE 0 END) AS n_in_win,            -- 条件计数：窗内行数
  SUM(CASE WHEN TRIM(mem016) = 'N' THEN 1 ELSE 0 END)                    AS n_enable_N,             -- 条件计数：★ enable = N 之行数（停用）
  SUM(CASE WHEN TRIM(mem017) = 'N' THEN 1 ELSE 0 END)                    AS n_canbet_N,             -- 条件计数：★ canbet = N 之行数（禁投注）
  SUM(CASE WHEN TRIM(mem019) = 'Y' THEN 1 ELSE 0 END)                    AS n_is_test_Y,            -- 条件计数：测试帐号数——须自分析中剔除
  COUNT(DISTINCT TRIM(mem024))                                           AS n_distinct_mem_risk,    -- 计数表达式：★ mem_risk 之取值数——平台自有风险标记，label 候选
  ROUND(SUM(CASE WHEN TRIM(mem002) REGEXP '^[0-9]+$' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS pct_mem002_numeric      -- 比率表达式：mem002（疑为帳號，宽度 48 同 member_url.account）之纯数字率
FROM ods_mariadb_2b.ods_a168_member;                                                                -- 取数来源：取自会员主表


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之四条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · 单跳通 ≠ 全链通。
--   §B-2 之第一跳纵然贯通，仍不得推定 §B-3 之全链成立。
--   H1 钱包层可用与否，唯以 §B-3 之 pct_bet_covered 为定谳。
--
-- 锁二 · 建轨迹必须 status = 1 过滤（承 §W-1 实测）。
--   回滾行之 cash 亦 100% 非空，窗内 1,046,940 条；混入即制造虚假跳变，
--   ΔCash 与 Drawdown 全错。本件 §B-3 之 w_user 已内建此过滤。
--
-- 锁三 · 桥表歧义须先解再用。
--   若 §B-1 之 mid_per_account > 1，即一账号对多编号，映射有歧义；
--   须先定去重规则（取最新／取唯一／全弃），否则连接即放大行数、虚增覆盖。
--
-- 锁四 · RG 之零命中判词从严（承 §V-4b 实测）。
--   535 条全为 biz_disable（商业停用），真 RG 三词合计 1 条孤例且未经上下文核实。
--   → RG = NOT_ESTABLISHED；**禁写 ABSENT／NO_TRACE**。
--   商业停用属平台管控处置，**不得充作责任博彩证据**——二者性质相反：
--   前者是平台限制会员，后者是会员保护自己。
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，**与 SQL 总包版号无涉**；
--   总包 canonical 仍 v11.0.1，下一合法编号仍只能 v11.0.2（读法甲）。
-- ══════════════════════════════════════════════════════════════════════════
