-- ══════════════════════════════════════════════════════════════════════════
-- §VB-00 · validbet 契约 · 零值五类指标  审计工具 v1.0.1（★ P1）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.0 → v1.0.1 · 一项斧正】
--   SC-9（零值只作一指标，分母单一）：v1.0.0 只报 n_vb_zero ＝ 9,551,241（7.60%），
--     以「全部记录」为唯一分母。**同一现象换分母即换量级**，单一比率会误导。
--   承裁示第二节，今立**五类平行分母**：
--     ┌────────────────────┬──────────────────┬─────────────────────┐
--     │ zero_record_rate   │ validbet=0 记录  │ 全部记录            │
--     │ zero_amount_rate   │ 其对应本金       │ 全部本金            │
--     │ zero_member_rate   │ 曾现零值之会员   │ 有效会员            │
--     │ zero_profit_rate   │ 其对应毛利       │ 全部毛利（绝对值）  │
--     │ zero_active_rate   │ 零值之活跃会员   │ ★ active_member     │
--     └────────────────────┴──────────────────┴─────────────────────┘
--   ★★ 末项锁死（裁示原文）：**不得以全会员作分母。**
--     active_member 之定义须先明书，否则该比率无从复现。本件采：
--       active_member ＝ 窗内有 ≥ 1 笔通过基础闸之注单者
--     （基础闸：rn=1 ∧ category='1' ∧ bet38='N' ∧ 非测试线 ∧ bet11>0 ∧ bet13>0）
--     ⚠ 此定义系本件所立，非上游既有口径——**须另案确认后方得入 registry**。
--
-- 【A／B 分层不得合并解释（承锁二十六 ＋ 裁示第三节）】
--   957 笔 A 群（validbet = stake_raw）与 7 笔 B 群（上线测试型）成因未必同。
--   ★ 总指标可有；**成因解释须保留 A／B 分层**。本件之零值群另出分层列。
--
-- 【承 §VB-41c 之 OBSERVED，禁越级】
--   ③ 结算后方写入 ／ ④ 某规则将 bet41 置零 —— 现为 SUPPORTED / TENDENCY，
--   **绝不得升为 CAUSE_CONFIRMED**。本件不触此二项之等级。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-00b · validbet 零值 · 五类平行分母（★ P1 核心）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_00b_zero_five_rates.csv」。
--   ★ 判读：五率之量级若相差悬殊，即证「零值集中于特定金额段或特定会员」；
--     若五率相近，则零值系均匀分布之结构性现象。**二者处置迥异。**
-- ──────────────────────────────────────────────────────────────────────────
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta——公司测试线代理
  SELECT DISTINCT age001 AS aid FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'               -- 取列与过滤：铁律④b——公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk——同注单号取最新版本
  SELECT b.bet05, b.bet09, b.bet13, b.bet14, b.bet11, b.validbet, b.bet41,                          -- 取列：会员、注型、本金、派彩、汇率、洗码、bet41
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category, b.bet38,                          -- 续行：五级代理、类别、重对标记
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)      AS rn                      -- 行号窗口表达式：三级排序取最新（§M0-6 已证唯一）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单主表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定分析窗
    AND CAST(b.bet02 AS STRING) = '101'                                                             -- 并列条件：限定百家乐
),                                                                                                  -- 续行：收束上方的子查询或函数括号
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base——过基础闸之母体
  SELECT TRIM(r.bet05)                                                   AS mid,                    -- 取列：会员编号
         TRIM(r.bet09)                                                   AS g9,                     -- 取列：注型
         CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS stake,                  -- 取值表达式：本金归一
         (CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8))
        - CAST(NULLIF(TRIM(r.bet14), '') AS DECIMAL(20,8)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)), 0) AS ggr,                    -- 取值表达式：毛利归一（本金减派彩）
         CAST(NULLIF(TRIM(r.validbet), '') AS DECIMAL(20,8))             AS vb,                     -- 取列：洗码量原值
         CAST(NULLIF(TRIM(r.bet41), '')    AS DECIMAL(20,8))             AS v41                     -- 取列：bet41 原值
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：一级代理是否测试线
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：二级代理是否测试线
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：三级代理是否测试线
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：四级代理是否测试线
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：五级代理是否测试线
  WHERE r.rn = 1                                                                                    -- 过滤条件：基础闸①——最新版本
    AND r.category = '1'                                                                            -- 并列条件：基础闸②——一般注单
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：基础闸③——非重对
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：基础闸④——非测试线
    AND CAST(NULLIF(TRIM(r.bet11), '') AS DECIMAL(20,8)) > 0                                        -- 并列条件：基础闸⑤——汇率为正
    AND CAST(NULLIF(TRIM(r.bet13), '') AS DECIMAL(20,8)) > 0                                        -- 并列条件：基础闸⑥——本金为正
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  'validbet 零值 · 五类平行分母（过基础闸之母体）'                          AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_base_rows,            -- 计数表达式：母体记录数
  COUNT(DISTINCT mid)                                                    AS n_active_member,        -- 计数表达式：★ active_member——本件所立之定义
  SUM(CASE WHEN vb = 0 THEN 1 ELSE 0 END)                                AS n_zero_rows,            -- 条件计数：零值记录数
  COUNT(DISTINCT CASE WHEN vb = 0 THEN mid END)                          AS n_zero_member,          -- 条件去重计数：曾现零值之会员数
  ROUND(SUM(CASE WHEN vb = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS zero_record_rate_pct,   -- 比率表达式：①记录率——分母＝全部记录
  ROUND(SUM(CASE WHEN vb = 0 THEN stake ELSE 0 END) * 100.0
        / NULLIF(SUM(stake), 0), 6)                                      AS zero_amount_rate_pct,   -- 比率表达式：②金额率——分母＝全部本金
  ROUND(COUNT(DISTINCT CASE WHEN vb = 0 THEN mid END) * 100.0
        / NULLIF(COUNT(DISTINCT mid), 0), 6)                             AS zero_member_rate_pct,   -- 比率表达式：③会员率——分母＝有效会员
  ROUND(SUM(CASE WHEN vb = 0 THEN ABS(ggr) ELSE 0 END) * 100.0
        / NULLIF(SUM(ABS(ggr)), 0), 6)                                   AS zero_profit_rate_pct,   -- 比率表达式：④毛利率——分母＝全部毛利绝对值
  ROUND(COUNT(DISTINCT CASE WHEN vb = 0 THEN mid END) * 100.0
        / NULLIF(COUNT(DISTINCT mid), 0), 6)                             AS zero_active_rate_pct,   -- 比率表达式：⑤★ 活跃会员率——分母＝active_member，禁用全会员
  ROUND(SUM(CASE WHEN vb = 0 THEN stake ELSE 0 END), 2)                  AS zero_stake_sum,         -- 条件汇总：零值群之本金总额
  ROUND(SUM(CASE WHEN vb = 0 THEN ggr   ELSE 0 END), 2)                  AS zero_ggr_sum,           -- 条件汇总：零值群之毛利总额
  ROUND(SUM(stake), 2)                                                   AS all_stake_sum,          -- 汇总表达式：母体本金总额
  ROUND(SUM(ggr), 2)                                                     AS all_ggr_sum,            -- 汇总表达式：母体毛利总额
  ROUND(-1 * SUM(CASE WHEN vb = 0 THEN ggr ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN vb = 0 THEN stake ELSE 0 END), 0), 6)     AS zero_mu0_pct,           -- 比率表达式：★ 零值群之 μ0——与母体 μ0 对照可判其性质
  ROUND(-1 * SUM(ggr) * 100.0 / NULLIF(SUM(stake), 0), 6)                AS base_mu0_pct,           -- 比率表达式：母体 μ0——基准
  SUM(CASE WHEN vb = 0 AND v41 = 0 THEN 1 ELSE 0 END)                    AS n_zero_both,            -- 条件计数：★ 二列皆零者——与 964 笔之交集判别
  CASE                                                                                              -- 条件分支：起始分支——五率一致性裁定
    WHEN ABS(SUM(CASE WHEN vb = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)
           - SUM(CASE WHEN vb = 0 THEN stake ELSE 0 END) * 100.0 / NULLIF(SUM(stake), 0)) > 5
      THEN '★ 记录率与金额率相差逾 5pp —— 零值集中于特定金额段，须按金额分层复验'                       -- 分支判定：金额偏斜
    WHEN ABS(SUM(CASE WHEN vb = 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)
           - COUNT(DISTINCT CASE WHEN vb = 0 THEN mid END) * 100.0 / NULLIF(COUNT(DISTINCT mid), 0)) > 20
      THEN '★ 记录率与会员率相差逾 20pp —— 零值集中于少数会员或普及于多数会员，须按会员分层复验'          -- 分支判定：会员偏斜
    ELSE '◐ 五率量级相近 —— 零值形似结构性均匀分布（★ 仍须按注型复验，未可径断）'                        -- 分支判定：形似均匀
  END                                                                    AS verdict_zero            -- 条件分支：收束上方判词，产出「verdict_zero」
FROM base;                                                                                          -- 取数来源：取自本条自建的中间结果集 base


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之三条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁三十一 · 同一现象，换分母即换量级——单一比率不足以承载判定。
--   validbet = 0 者 9,551,241 笔，以全部记录为分母得 7.60%；
--   若以金额、会员、毛利、活跃会员为分母，可得截然不同之数。
--   ★ 五率并出，禁只报其一。
--
-- 锁三十二 · active_member 之分母锁（裁示原文：**不得使用全会员作为分母**）。
--   ⚠ 本件所采之 active_member 定义（窗内有 ≥ 1 笔过基础闸之注单）系**本件所立**，
--     非上游既有口径。**须另案确认后方得入 registry**——
--     否则该比率虽可算，却不可与他处之「活跃会员」相较。
--
-- 锁三十三 · A／B 分层：总指标可有，成因解释须分层。
--   957 笔 A 群与 7 笔 B 群之成因未必同；
--   ★ 禁以 A 群之「validbet = stake_raw：957/957」外推至全部 964 笔。
--
-- ⚠ 承 §VB-41c：③ 结算后方写入 ／ ④ 某规则将 bet41 置零，
--   现为 SUPPORTED / TENDENCY，**绝不得升为 CAUSE_CONFIRMED**。本件不触其等级。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
