-- ══════════════════════════════════════════════════════════════════════════
-- P-H0-7 · 全表真桥定谳 v1.0.0（★ 零占位符，可直接运行）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · 状态 WORKING · 置放 审计/工具/ ★
-- ★ canonical = false · 不入 SQL 总包 · 结案前不得引用其结论 ★
-- ══════════════════════════════════════════════════════════════════════════
-- 上游实测（P-H0-6 已跑，本件承其结果并撤回三处前判）：
--   §B-4a  2026-06-15：47,523 行／47,523 mem001／rows_per_mem001 = 1
--          mem001 区间 151,499,470 ~ 151,547,025，跨度 47,555，密度 99.93%
--          → ★ 连续编号区间，非全量快照之形态
--   §B-4b  窗内 139 日，**每日 rows_per_key 精确 ≡ 1.0000**，无一例外
--          日均 45,595｜p50 45,381｜min 31,865｜max 92,762｜窗内合计 6,337,793
--          enable_N 呈**注册队列年龄效应**：03-21 为 24、05-31 为 257（异常峰）、
--          07-30 之后近乎全零——新注册者尚未及被停用
--          2026-05-19（已知注单侧全量重同步日）于 member 表**毫无异常**
--
-- ★★ 定谳：**member 系注册日分区，每会员仅一行，落于其注册日。**
--    三项互证：① 单日编号连续；② 各日集合互不重叠（全表 DISTINCT ≡ COUNT）；
--    ③ enable_N 之单调年龄梯度——逐日快照绝无此三性质。
--
-- ★ 因而须撤回三处（本件卷首照登，不删不覆盖）：
--   撤回一（我方）：§B-5／§B-6 之 0.2088% 作废。
--       `dt = '2026-06-15'` 取到的**非当日在册会员，乃当日新注册之 47,523 人**。
--       此非「时间错配」，乃**误用表之语义**——以一日新注册名单充作全量桥。
--   撤回二（我方）：「mem016／mem017 逐日差分即状态变更事件流」作废。
--       每会员仅一行，**无历史序列**；状态变更史仍只剩 log_mem_change（覆盖 0.0914%）。
--   撤回三（裁示）：「member 具逐日快照性质」不成立；
--       其处方「wallet.dt ↔ member.dt 时间对齐」方向相反——
--       正解是**根本不限日**：桥之正确基数为 59,178,470 对，非 47,523 对。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §B-9 · 前置自验：member 是否为会员之全集（★ 桥之前提，先证再用）
-- ▸ 导出：不需要 —— §B-9 前置自验读数，屏幕看结果。
--   ★ 缘由：若 member 非全量会员表，则纵然全表取桥，覆盖率仍受其自身残缺所限。
--     故先测：注单侧之 bet05，有多少能在 member 全表之 mem001 中寻见。
--   ★ 判读：
--     覆盖 ≥ 95% → member 系会员全集，可作桥之权威侧
--     覆盖偏低   → member 自身残缺，须先解其残缺，再论钱包桥
--   ★ 本条不限 member 之 dt——承定谳，限日即取到「某日新注册者」而非在册者。
-- ──────────────────────────────────────────────────────────────────────────
WITH m_uid AS (                                                                                     -- 公共表表达式：开启中间结果集 m_uid——会员主表之编号全集（★ 全表，不限日）
  SELECT DISTINCT CAST(NULLIF(TRIM(mem001), '') AS BIGINT)               AS uid                     -- 取列：會員編號，转整型
  FROM ods_mariadb_2b.ods_a168_member                                                               -- 取数来源：取自会员主表
  WHERE TRIM(mem001) REGEXP '^[0-9]+$'                                                              -- 过滤条件：只取纯数字者
    AND CAST(NULLIF(TRIM(mem001), '') AS BIGINT) > 0                                                -- 并列条件：排除零
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bet_uid AS (                                                                                        -- 公共表表达式：开启中间结果集 bet_uid——注单侧会员全集
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)                AS uid                     -- 取列：会员编号
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet05), '') AS BIGINT) > 0                                                 -- 并列条件：排除零与空
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'bet02.bet05 ⊆ member.mem001（全表）'                                  AS test,                   -- 字面取值：受检命题
  (SELECT COUNT(*) FROM bet_uid)                                         AS n_bet_uid,              -- 标量子查询：注单侧会员数
  (SELECT COUNT(*) FROM m_uid)                                           AS n_member_uid,           -- 标量子查询：★ 会员主表编号数——与 47,523 对照，看基数之别
  (SELECT COUNT(*) FROM bet_uid b JOIN m_uid m ON m.uid = b.uid)         AS n_matched,              -- 标量子查询：交集数
  ROUND((SELECT COUNT(*) FROM bet_uid b JOIN m_uid m ON m.uid = b.uid) * 100.0
        / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4)                  AS pct_bet_in_member,      -- 比率表达式：★★ 注单会员见于会员主表之比率
  CASE                                                                                              -- 条件分支：起始分支——前提裁定
    WHEN (SELECT COUNT(*) FROM m_uid) = 0                                THEN 'NON_DIAGNOSTIC（会员侧空集）'      -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM bet_uid b JOIN m_uid m ON m.uid = b.uid) * 1.0
         / NULLIF((SELECT COUNT(*) FROM bet_uid), 0) >= 0.95             THEN '✅ member 系会员全集，可作桥之权威侧' -- 分支判定：前提成立
    WHEN (SELECT COUNT(*) FROM bet_uid b JOIN m_uid m ON m.uid = b.uid) = 0 THEN '❌ 零交集——mem001 与 bet05 非同一编号体系' -- 分支判定：经验性零
    ELSE '⚠ member 自身残缺，须先解其残缺再论钱包桥'                                                 -- 分支判定：前提不足
  END                                                                    AS verdict_B9              -- 条件分支：收束上方判词，产出「verdict_B9」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ──────────────────────────────────────────────────────────────────────────
-- §B-10 · 全表真桥第一跳：wallet_dtl.user ↔ member.mem002（★ 不限日）
-- ▸ 导出：不需要 —— §B-10 全表第一跳，屏幕看结果。
--   ★ 与 §B-5 之唯一差异：member 侧**去掉 dt 限定**。
--     §B-5 得 2,113 / 463,478 = 0.4559%，系以 47,523 对之桥所得；
--     本条以 59,178,470 对之桥重测，二者之差即「误用表语义」之量。
--   ★ 判读同前：分母前置判定 ＋ 小分母守卫（桥侧 < 1000 即无判别力）。
-- ──────────────────────────────────────────────────────────────────────────
WITH w_acct AS (                                                                                    -- 公共表表达式：开启中间结果集 w_acct——钱包侧账号全集
  SELECT DISTINCT TRIM(`user`)                                           AS acct                    -- 取列：钱包侧账号
  FROM ods_mariadb_2b.ods_a168_wallet_dtl                                                           -- 取数来源：取自钱包明细表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND TRIM(`user`) <> ''                                                                          -- 并列条件：排除空账号
    AND TRIM(status) = '1'                                                                          -- 并列条件：★ 只取成功态，承 §W-1 之回滾污染锁
),                                                                                                  -- 续行：收束上方的子查询或函数括号
m_acct AS (                                                                                         -- 公共表表达式：开启中间结果集 m_acct——会员主表账号全集（★ 全表）
  SELECT DISTINCT TRIM(mem002)                                           AS acct                    -- 取列：會員帳號
  FROM ods_mariadb_2b.ods_a168_member                                                               -- 取数来源：取自会员主表
  WHERE TRIM(mem002) <> ''                                                                          -- 过滤条件：排除空账号
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'wallet_dtl.user ↔ member.mem002（全表桥）'                            AS hop,                    -- 字面取值：受检跳次
  (SELECT COUNT(*) FROM w_acct)                                          AS n_wallet_acct,          -- 标量子查询：钱包侧账号数
  (SELECT COUNT(*) FROM m_acct)                                          AS n_member_acct,          -- 标量子查询：★ 会员侧账号数——与 §B-5 之 47,523 对照
  (SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct)       AS n_matched,              -- 标量子查询：交集账号数
  ROUND((SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct) * 100.0
        / NULLIF((SELECT COUNT(*) FROM w_acct), 0), 4)                   AS pct_wallet_matched,     -- 比率表达式：★★ 钱包账号可映射之比率——与 0.4559% 对照
  CASE                                                                                              -- 条件分支：起始分支——分母前置判定 ＋ 小分母守卫
    WHEN (SELECT COUNT(*) FROM w_acct) = 0 OR (SELECT COUNT(*) FROM m_acct) = 0
      THEN 'NON_DIAGNOSTIC（某侧空集）'                                                              -- 分支判定：结构性零
    WHEN (SELECT COUNT(*) FROM m_acct) < 1000
      THEN 'NON_DIAGNOSTIC（桥侧基数过小，无判别力）'                                                -- 分支判定：小分母守卫
    WHEN (SELECT COUNT(*) FROM w_acct w JOIN m_acct m ON m.acct = w.acct) = 0
      THEN '❌ 两侧基数皆足而交集为零——账号体系确不通'                                               -- 分支判定：经验性零
    ELSE '✅ 全表桥第一跳通'                                                                        -- 分支判定：可用
  END                                                                    AS verdict_hop1            -- 条件分支：收束上方判词，产出「verdict_hop1」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ──────────────────────────────────────────────────────────────────────────
-- §B-11 · ★★ 全表全链定谳：wallet.user → mem002 → mem001 → bet05
-- ▸ 导出：不需要 —— §B-11 全链定谳，屏幕看结果。
--   ★ 本条为 H1 钱包层之**最终覆盖面裁定**。§B-6 之 0.2088% 已作废，以本条为准。
--   ★ 判读（三档，门槛不因结果而改，先立后测）：
--     pct_bet_covered ≥ 30%  → H1_FULL_COVERAGE = ESTABLISHED
--     0 < pct < 30%          → H1_CASE_EVIDENCE  = ESTABLISHED，FULL 未立
--     = 0 且两侧基数皆足      → H1 不可用
--   ★ 措辞锁：本条所得须整句连同口径引用——
--     「以 member **全表**（不限 dt）为会员桥、wallet 侧限窗且 status = 1、
--       注单侧限窗且 bet02 = 101 之口径下，钱包轨迹可达之注单会员为 X / 723,557」。
--     **禁写作「wallet_dtl 只能覆盖 X% 的投注会员」**——后者越过证据边界。
-- ──────────────────────────────────────────────────────────────────────────
WITH bridge AS (                                                                                    -- 公共表表达式：开启中间结果集 bridge——账号到编号之全表映射
  SELECT DISTINCT TRIM(mem002)                                           AS acct,                   -- 取列：會員帳號
         CAST(NULLIF(TRIM(mem001), '') AS BIGINT)                        AS uid                     -- 取列：會員編號，转整型
  FROM ods_mariadb_2b.ods_a168_member                                                               -- 取数来源：取自会员主表（★ 全表，不限 dt）
  WHERE TRIM(mem002) <> ''                                                                          -- 过滤条件：排除空账号
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
  'wallet.user → mem002 → mem001 → bet05（全表桥）'                      AS full_chain,             -- 字面取值：受检全链
  (SELECT COUNT(*) FROM w_acct)                                          AS n_wallet_acct,          -- 标量子查询：钱包侧账号数
  (SELECT COUNT(*) FROM bridge)                                          AS n_bridge_pair,          -- 标量子查询：★ 桥映射对数——与 §B-6 之 47,523 对照
  (SELECT COUNT(*) FROM bet_uid)                                         AS n_bet_uid,              -- 标量子查询：注单侧会员数
  (SELECT COUNT(DISTINCT acct) FROM chain)                               AS n_chain_acct,           -- 标量子查询：端到端贯通之账号数
  (SELECT COUNT(DISTINCT uid)  FROM chain)                               AS n_chain_uid,            -- 标量子查询：端到端贯通之会员数
  ROUND((SELECT COUNT(DISTINCT acct) FROM chain) * 100.0
        / NULLIF((SELECT COUNT(*) FROM w_acct), 0), 4)                   AS pct_wallet_reachable,   -- 比率表达式：钱包账号可达注单之比率
  ROUND((SELECT COUNT(DISTINCT uid) FROM chain) * 100.0
        / NULLIF((SELECT COUNT(*) FROM bet_uid), 0), 4)                  AS pct_bet_covered,        -- 比率表达式：★★ H1 钱包层之最终定谳
  CASE                                                                                              -- 条件分支：起始分支——全链裁定（门槛先立后测，不因结果而改）
    WHEN (SELECT COUNT(*) FROM w_acct) = 0 OR (SELECT COUNT(*) FROM bridge) < 1000
      THEN 'NON_DIAGNOSTIC（某侧空集或桥基数过小）'                                                  -- 分支判定：无判别力
    WHEN (SELECT COUNT(DISTINCT uid) FROM chain) = 0
      THEN '❌ 全链不通——H1 钱包层不可用'                                                            -- 分支判定：经验性零
    WHEN (SELECT COUNT(DISTINCT uid) FROM chain) * 1.0
         / NULLIF((SELECT COUNT(*) FROM bet_uid), 0) < 0.30
      THEN '⚠ H1_CASE_EVIDENCE 成立，H1_FULL_COVERAGE 未立'                                          -- 分支判定：低覆盖
    ELSE '✅ H1_FULL_COVERAGE 成立——钱包余额轨迹可入 H 轴'                                           -- 分支判定：可用
  END                                                                    AS verdict_chain           -- 条件分支：收束上方判词，产出「verdict_chain」
FROM (SELECT 1 AS one) d;                                                                           -- 取数来源：单行占位，令上方标量子查询各出一行


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之五条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁一 · **分区语义先于分区过滤**（★ 本件之核心教训）。
--   `WHERE dt = 'X'` 之所得，全凭该表 dt 之语义而定：
--     快照表 → 当日**在册**者
--     注册日分区 → 当日**新注册**者
--     事件表 → 当日**发生**者
--   三者迥异。未证 dt 语义即施 dt 过滤，所得之数纵然精确，亦无意义。
--   §B-5／§B-6 之 0.2088% 即此之实例——非「时间错配」，乃**误用表之语义**。
--
-- 锁二 · 分区语义之三重互证（本件所用之法，可复用）。
--   ① 单日主键区间连续且密度近 1 → 顺序发放，非在册集合
--   ② 各日集合互不重叠（全表 DISTINCT ≡ COUNT）→ 每实体仅一行
--   ③ 状态列呈单调**年龄梯度**（越早注册停用越多，最近注册近乎全零）
--   三者同时成立，方判「注册日分区」。缺一即须存疑。
--
-- 锁三 · 每实体仅一行 → **无历史序列**。
--   member 之 mem016／mem017 系当前值；逐日差分不可行。
--   状态变更史仍只剩 log_mem_change（编号体系通，惟窗内覆盖 0.0914%）。
--
-- 锁四 · mem024（mem_risk）全表单值 → **禁作 gold label／outcome／
--   分类目标／验证标签／规则输入**；违者判 S1 / INVALID LABEL。
--
-- 锁五 · 测试身份只在代理侧。
--   member.mem019 全空，**不得据以写「会员表没有测试会员」**；
--   只得写「mem019 于当前数据未提供有效测试标识」。
--   排除测试对象须自代理侧 age022 = '1'（在册 214 条）构造排除集再左连。
--
-- 工具态：WORKING · ARTIFACT CLASS = A2 · canonical = false
-- 版号：本件为审计工具自身之 v1.0.0，**与 SQL 总包版号无涉**；
--   总包 canonical 仍 v11.0.1，下一合法编号仍只能 v11.0.2（读法甲）。
-- ══════════════════════════════════════════════════════════════════════════
