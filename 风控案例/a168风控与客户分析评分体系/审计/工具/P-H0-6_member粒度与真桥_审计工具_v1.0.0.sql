-- ══════════════════════════════════════════════════════════════════════════
-- P-H0-6 · member 粒度定谳 ＋ 真桥候选验证 v1.0.0（★ 零占位符，可直接运行）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · 状态 WORKING · 置放 审计/工具/ ★
-- ★ canonical = false · 不入 SQL 总包 · 结案前不得引用其结论 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 上游实测（P-H0-5 已跑，本件承其结果并斧正其一处判词）：
--   §B-1  member_url  57 行／57 mid／57 account，一一对应无歧义
--                     ★★ 惟仅 57 行——系「指定網址」配置表，非全量映射表
--   §B-2  wallet.user ∩ member_url.account = 0
--         ★ 斧正：此**非**账号体系不通，系**桥表基数过小**（覆盖上限 0.0123%）。
--           纵账号体系全同，最大可能交集亦仅 57。
--           → 改判 NON_DIAGNOSTIC / BRIDGE_UNDERSIZED
--   §B-3  全链 0 同理，随 §B-2 一并改判，**不得据以判 H1 钱包层不可用**
--   §B-4  member 59,178,470 行／3,273 日／COUNT(DISTINCT mem001) 恰等于 COUNT(*)
--         → NON-CONCLUSIVE（判据本身须修）
--
-- ★ 三张表之账号纯数字率高度趋同，反证同一账号体系：
--     wallet_dtl.user     1.8026%
--     member_url.account  1.7544%
--     member.mem002       1.6083%
--   → **真桥候选为 member.mem002**（5,917 万行，varchar(48)，与 account 同宽），
--     而非 57 行之 member_url。本件 §B-5／§B-6 即测此桥。
--
-- ★ 另二发现须立刻登记（P-H0-5 之副产品）：
--   ① n_distinct_mem_risk = 1 → mem024（mem_risk）**全表单值，从未启用**
--      → **禁作 label**，亦禁作任何判据之输入
--   ② n_is_test_Y = 0 → 会员表之测试标识全空；测试线标识在代理侧（age022='1'，
--      在册已知 214 条）→ 剔测试线只能走代理侧
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §B-4a · member 粒度定谳（★ 内建精确计数守卫，排除近似路径之成因）
-- ▸ 导出：不需要 —— §B-4a 粒度读数，屏幕看结果。
--   ★ 承 R4：COUNT(DISTINCT mem001) 恰等于 COUNT(*)，有二解——
--     解一：mem001 全表唯一（则其非 mid，因注单侧全量仅 721,190 会员）
--     解二：StarRocks 对大基数 COUNT(DISTINCT) 走了近似路径，两数偶合
--     → 本条以**单日切片**（基数小，必走精确路径）交叉验证，二解立判。
--   ★ 判读：
--     单日 n_rows ≈ 单日 distinct mem001  → mem001 于日内唯一 → 逐日快照
--     单日 n_rows ≫ 单日 distinct mem001  → 日内多版本 → SCD／事件表
--     单日 distinct mem001 量级 ≈ 万      → mem001 确为会员键
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  '2026-06-15'                                                           AS dt_slice,               -- 字面取值：切片日（窗中段，非端点）
  COUNT(*)                                                               AS n_rows_day,             -- 计数表达式：当日行数
  COUNT(DISTINCT TRIM(mem001))                                           AS n_mem001_day,           -- 计数表达式：★ 当日去重 mem001——基数小，必走精确路径
  COUNT(DISTINCT TRIM(mem002))                                           AS n_mem002_day,           -- 计数表达式：当日去重 mem002（疑为帳號）
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT TRIM(mem001)), 0), 4)     AS rows_per_mem001,        -- 比率表达式：★ 逼近 1 即日内唯一，大于 1 即日内多版本
  ROUND(COUNT(DISTINCT TRIM(mem002)) * 1.0
        / NULLIF(COUNT(DISTINCT TRIM(mem001)), 0), 4)                    AS mem002_per_mem001,      -- 比率表达式：★ 逼近 1 即二者一一对应，可互为主键
  MIN(CAST(NULLIF(TRIM(mem001), '') AS BIGINT))                          AS mem001_min,             -- 聚合取值：mem001 下界——判其是否为连续编号
  MAX(CAST(NULLIF(TRIM(mem001), '') AS BIGINT))                          AS mem001_max,             -- 聚合取值：mem001 上界
  SUM(CASE WHEN TRIM(mem016) = 'N' THEN 1 ELSE 0 END)                    AS n_enable_N_day,         -- 条件计数：当日 enable = N 之行数
  SUM(CASE WHEN TRIM(mem017) = 'N' THEN 1 ELSE 0 END)                    AS n_canbet_N_day,         -- 条件计数：当日 canbet = N 之行数
  COUNT(DISTINCT TRIM(mem024))                                           AS n_memrisk_day,          -- 计数表达式：★ 当日 mem_risk 取值数——全表为 1，此处复核
  COUNT(DISTINCT TRIM(type))                                             AS n_type_day,             -- 计数表达式：帳戶類型取值数（0現金/1信用/2電投）
  COUNT(DISTINCT TRIM(currency))                                         AS n_currency_day          -- 计数表达式：币别取值数
FROM ods_mariadb_2b.ods_a168_member                                                                 -- 取数来源：取自会员主表
WHERE dt = '2026-06-15';                                                                            -- 过滤条件：限定单日切片


-- ──────────────────────────────────────────────────────────────────────────
-- §B-4b · 逐日会员数之分布（★ 判 dt 是业务日抑或技术同步日）
-- ▸ 导出：需要 —— 存为「数据库/_PH0_6b_member_daily.csv」（诊断留档，非交付件）。
--   ★ 判读：
--     逐日会员数平稳且量级相近 → dt 为逐日快照之业务日
--     某日暴增或断档            → dt 为技术同步日，或曾有全量重灌
--     承既有认知：2026-05-19 曾有单日全量重同步（DUP_TIME_ONLY 100%），
--     本条可顺带复核该日在 member 表是否亦有同一现象。
--   ★ 只取窗内，免全表 3,273 日之输出。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  dt                                                                     AS dt_day,                 -- 取列：分区日
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：当日行数
  COUNT(DISTINCT TRIM(mem001))                                           AS n_mem001,               -- 计数表达式：当日去重会员键数
  ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT TRIM(mem001)), 0), 4)     AS rows_per_key,           -- 比率表达式：日内版本数
  SUM(CASE WHEN TRIM(mem016) = 'N' THEN 1 ELSE 0 END)                    AS n_enable_N,             -- 条件计数：当日停用数
  SUM(CASE WHEN TRIM(mem017) = 'N' THEN 1 ELSE 0 END)                    AS n_canbet_N              -- 条件计数：当日禁投注数
FROM ods_mariadb_2b.ods_a168_member                                                                 -- 取数来源：取自会员主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
GROUP BY dt                                                                                         -- 分组：按分区日汇总
ORDER BY dt;                                                                                        -- 排序：按分区日升序排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §B-5 · ★★ 真桥第一跳：wallet_dtl.user ↔ member.mem002
-- ▸ 导出：不需要 —— §B-5 真桥对齐率，屏幕看结果。
--   ★ 缘由：三表账号纯数字率趋同（1.8026% ／ 1.7544% ／ 1.6083%），
--     反证同一账号体系；而 member 有 5,917 万行，基数足以判别，
--     不似 member_url 之 57 行——此即 §B-2 改判 BRIDGE_UNDERSIZED 之由来。
--   ★ 判读（分母前置判定已内建）：
--     两侧皆非空而交集为零 → 此方为账号体系不通之**真**证据
--     交集非零             → 报覆盖率，并进 §B-6 测全链
--   ★ member 取单日切片以定账号全集，免 5,917 万行之全表去重代价。
-- ──────────────────────────────────────────────────────────────────────────
WITH w_acct AS (                                                                                    -- 公共表表达式：开启中间结果集 w_acct——钱包侧账号全集
  SELECT DISTINCT TRIM(`user`)                                           AS acct                    -- 取列：钱包侧账号
  FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                           -- 取数来源：取自钱包明细表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND TRIM(`user`) <> ''                                                                          -- 并列条件：排除空账号
    AND TRIM(status) = '1'                                                                          -- 并列条件：★ 只取成功态，承 §W-1 之回滾污染锁
),                                                                                                  -- 续行：收束上方的子查询或函数括号
m_acct AS (                                                                                         -- 公共表表达式：开启中间结果集 m_acct——会员主表侧账号全集
  SELECT DISTINCT TRIM(mem002)                                           AS acct                    -- 取列：会员主表侧账号（疑为帳號）
  FROM ods_mariadb_2b.ods_a168_member                                                               -- 取数来源：取自会员主表
  WHERE dt = '2026-06-15'                                                                           -- 过滤条件：限定单日切片，免全表去重
    AND TRIM(mem002) <> ''                                                                          -- 并列条件：排除空账号
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'wallet_dtl.user ↔ member.mem002'                                      AS hop,                    -- 字面取值：受检跳次
  (SELECT COUNT(*) FROM w_acct)                                          AS n_wallet_acct,          -- 标量子查询：分母一——钱包侧账号数
  (SELECT COUNT(*) FROM m_acct)                                          AS n_member_acct,          -- 标量子查询：分母二——会员侧账号数
  (SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct)       AS n_matched,              -- 标量子查询：交集账号数
  ROUND((SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct) * 100.0
        / NULLIF((SELECT COUNT(*) FROM w_acct), 0), 4)                   AS pct_wallet_matched,     -- 比率表达式：★ 钱包账号可映射之比率
  ROUND((SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct) * 100.0
        / NULLIF((SELECT COUNT(*) FROM m_acct), 0), 4)                   AS pct_member_matched,     -- 比率表达式：会员账号被钱包覆盖之比率
  CASE                                                                                              -- 条件分支：起始分支——分母前置判定
    WHEN (SELECT COUNT(*) FROM w_acct) = 0 OR (SELECT COUNT(*) FROM m_acct) = 0
      THEN 'NON_DIAGNOSTIC（某侧空集）'                                                              -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM m_acct) < 1000
      THEN 'NON_DIAGNOSTIC（桥侧基数过小，无判别力）'                                                -- 分支判定：★ 承 §B-2 之教训——小分母不得下体系裁定
    WHEN (SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct) = 0
      THEN '❌ 两侧基数皆足而交集为零——账号体系确不通'                                               -- 分支判定：经验性零
    ELSE '✅ 真桥第一跳通'                                                                          -- 分支判定：可用
  END                                                                    AS verdict_hop1            -- 条件分支：收束上方判词，产出「verdict_hop1」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ──────────────────────────────────────────────────────────────────────────
-- §B-6 · ★★ 真桥全链：wallet.user → member.mem002 → member.mem001 → bet05
-- ▸ 导出：不需要 —— §B-6 全链贯通率，屏幕看结果。
--   ★ 铁律（承 P-H0-5 锁一）：**不以任何一跳之成立推定全链成立**，直测端到端。
--   ★ pct_bet_covered 为 H1 钱包层之最终定谳：
--     ≥ 30%  → H1 成立，钱包余额轨迹可入 H 轴
--     < 30%  → H1 只得作个案证据
--     = 0    → 若两侧基数皆足，方判 H1 不可用
-- ──────────────────────────────────────────────────────────────────────────
WITH bridge AS (                                                                                    -- 公共表表达式：开启中间结果集 bridge——账号到编号之映射（自会员主表）
  SELECT DISTINCT TRIM(mem002)                                           AS acct,                   -- 取列：會員帳號
         CAST(NULLIF(TRIM(mem001), '') AS BIGINT)                        AS uid                     -- 取列：會員編號，转整型
  FROM ods_mariadb_2b.ods_a168_member                                                               -- 取数来源：取自会员主表
  WHERE dt = '2026-06-15'                                                                           -- 过滤条件：限定单日切片
    AND TRIM(mem002) <> ''                                                                          -- 并列条件：排除空账号
    AND TRIM(mem001) REGEXP '^[0-9]+$'                                                              -- 并列条件：编号须纯数字
    AND CAST(NULLIF(TRIM(mem001), '') AS BIGINT) > 0                                                -- 并列条件：排除零
),                                                                                                  -- 续行：收束上方的子查询或函数括号
w_acct AS (                                                                                         -- 公共表表达式：开启中间结果集 w_acct——钱包侧账号全集
  SELECT DISTINCT TRIM(`user`)                                           AS acct                    -- 取列：钱包侧账号
  FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                           -- 取数来源：取自钱包明细表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND TRIM(`user`) <> ''                                                                          -- 并列条件：排除空账号
    AND TRIM(status) = '1'                                                                          -- 并列条件：★ 只取成功态
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bet_uid AS (                                                                                        -- 公共表表达式：开启中间结果集 bet_uid——注单侧会员全集
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)                AS uid                     -- 取列：会员编号
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet05), '') AS BIGINT) > 0                                                 -- 并列条件：排除零与空
),                                                                                                  -- 续行：收束上方的子查询或函数括号
chain AS (                                                                                          -- 公共表表达式：开启中间结果集 chain——端到端贯通者
  SELECT DISTINCT w.acct                                                 AS acct,                   -- 取列：贯通之账号
         g.uid                                                           AS uid                     -- 取列：其对应之会员编号
  FROM w_acct  w                                                                                    -- 取数来源：取自本条自建的中间结果集 w_acct
  JOIN bridge  g ON g.acct = w.acct                                                                 -- 连接：第一跳，账号对账号
  JOIN bet_uid b ON b.uid  = g.uid                                                                  -- 连接：第二跳，编号对编号
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'wallet.user → mem002 → mem001 → bet05'                                AS full_chain,             -- 字面取值：受检全链
  (SELECT COUNT(*) FROM w_acct)                                          AS n_wallet_acct,          -- 标量子查询：钱包侧账号数
  (SELECT COUNT(*) FROM bridge)                                          AS n_bridge_pair,          -- 标量子查询：★ 桥映射对数——与 57 对照
  (SELECT COUNT(*) FROM bet_uid)                                         AS n_bet_uid,              -- 标量子查询：注单侧会员数
  (SELECT COUNT(DISTINCT acct) FROM chain)                               AS n_chain_acct,           -- 标量子查询：端到端贯通之账号数
  (SELECT COUNT(DISTINCT uid)  FROM chain)                               AS n_chain_uid,            -- 标量子查询：端到端贯通之会员数
  ROUND((SELECT COUNT(DISTINCT acct) FROM chain) * 100.0
        / NULLIF((SELECT COUNT(*) FROM w_acct), 0), 4)                   AS pct_wallet_reachable,   -- 比率表达式：钱包账号可达注单之比率
  ROUND((SELECT COUNT(DISTINCT uid) FROM chain) * 100.0
        / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4)                  AS pct_bet_covered,        -- 比率表达式：★★ H1 钱包层之最终定谳
  CASE                                                                                              -- 条件分支：起始分支——全链裁定
    WHEN (SELECT COUNT(*) FROM w_acct) = 0 OR (SELECT COUNT(*) FROM bridge) < 1000
      THEN 'NON_DIAGNOSTIC（某侧空集或桥基数过小）'                                                  -- 分支判定：无判别力
    WHEN (SELECT COUNT(DISTINCT uid) FROM chain) = 0
      THEN '❌ 全链不通——H1 钱包层不可用'                                                            -- 分支判定：经验性零
    WHEN (SELECT COUNT(DISTINCT uid) FROM chain) * 1.0
         / NULLIF((SELECT COUNT(*) FROM bet_uid), 0) < 0.30
      THEN '⚠ 全链通惟覆盖不足三成——H1 只得作个案证据'                                               -- 分支判定：低覆盖
    ELSE '✅ 全链通且覆盖可用——H1 钱包层成立'                                                        -- 分支判定：可用
  END                                                                    AS verdict_chain           -- 条件分支：收束上方判词，产出「verdict_chain」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之五条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · 小分母之零交集无判别力（★ 本件之核心斧正）。
--   「结构性零 ≠ 经验性零」有第二形态：分母非零，惟**小到无判别力**。
--   member_url 仅 57 行，覆盖上限 0.0123%；纵账号体系全同，最大交集亦仅 57。
--   → §B-2／§B-3 之零，改判 NON_DIAGNOSTIC / BRIDGE_UNDERSIZED，
--     **不得据以判「账号体系不通」，亦不得据以判「H1 钱包层不可用」**。
--   → 本件 §B-5／§B-6 之判词已内建「桥侧基数 < 1000 即无判别力」之前置判定。
--
-- 锁二 · 精确计数须自证。
--   COUNT(DISTINCT) 于大基数下或走近似路径。两个八位数精确相等（59,178,470），
--   既可解为「全表唯一」，亦可解为「近似偶合」。
--   → 凡以 COUNT(DISTINCT) 下粒度裁定者，须以**小基数切片**交叉验证。
--
-- 锁三 · mem024（mem_risk）全表单值，**禁作 label、禁作判据输入**。
--   平台自有之风险标记从未启用；以其为金标签者，判 S1。
--
-- 锁四 · 测试标识不在会员表。
--   member 之 mem019（is_test）全为空；测试线标识在代理侧（age022 = '1'，
--   在册已知 214 条）。→ 剔测试线只能走代理侧，走会员侧必漏。
--
-- 锁五 · 轨迹可重建 ≠ 会员归属可重建（承 REDTEAM 裁示）。
--   wallet_dtl 之账号级轨迹已证可建（可排序、cash 非空、日内 p50 = 15）；
--   惟其归属于哪一 bet05 会员，须待 §B-6 定谳。二者不可混为一谈。
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，**与 SQL 总包版号无涉**；
--   总包 canonical 仍 v11.0.1，下一合法编号仍只能 v11.0.2（读法甲）。
-- ══════════════════════════════════════════════════════════════════════════
