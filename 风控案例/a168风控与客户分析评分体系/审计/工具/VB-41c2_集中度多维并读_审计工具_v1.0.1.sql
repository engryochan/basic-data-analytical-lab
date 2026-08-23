-- ══════════════════════════════════════════════════════════════════════════
-- §VB-41c-2 · 964 笔集中度 · 多维并读  审计工具 v1.0.1（★ P0.5 · 判词升级）
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 【v1.0.0 → v1.0.1 · 一项斧正 ＋ 一项自禁】
--   SC-8（判词表达不足）：v1.0.0 以单一硬门槛（≥ 30%）二分「集中／不集中」。
--     实测 top1_member_share ＝ 29.1536%、top_date_share ＝ 29.9896%，
--     二者分别差 0.85 与 0.01 个百分点未过，遂判「无单一维度显著集中」——
--     **两个维度同时逼近极高集中之信息，被硬切丢失。**
--   ★★ 自禁（承裁示 · 我上轮之倾向须先自纠）：
--     我上轮书「门槛设计有缺陷」，实即欲将 30% 下调以令本批数据「显著」。
--     **此系典型 post-hoc threshold fitting：先看数据 → 再调门槛 → 再令其显著。**
--     审计链上不允许。故本版：
--       · **阈值 30% 原样冻结，一分不动**
--       · 只改**表达结构**：连续指标 ＋ 近门槛态 ＋ 多维联合
--     具体阈值之修订须另案冻结，且须先于取数、不得在见数之后。
--
-- 【三层表达（承裁示第一节）】
--   第一层 · 连续指标恒出，禁只出 PASS/FAIL：
--            top1_member_share ／ top_date_share ／ top_table_share ／
--            top_bet09_share ／ top_stake_share
--   第二层 · 近门槛态：距门槛 ≤ 1 个百分点者标 NEAR，禁写「无显著集中」
--   第三层 · 多维联合：n_dims_high ／ n_dims_near，四态判词
--
-- 【四态判词】
--   NO_CONCENTRATION_SIGNAL          无高、无近
--   SINGLE_DIMENSION_SIGNAL          恰一维为高
--   MULTI_DIMENSION_SIGNAL           二维以上为高
--   MULTI_DIMENSION_NEAR_THRESHOLD   二维以上为近（含高）—— ★ 本版所补之缺口
--
-- 【A／B 分群不得合并解释（承锁二十六 ＋ 裁示第三节）】
--   A 群 957 笔主群 ／ B 群 7 笔上线测试型。总指标可有，**成因解释须分层**。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41c-2 · 五维集中度 · 多维并读（阈值 30% 冻结不动）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41c2_concentration_v2.csv」。
-- ──────────────────────────────────────────────────────────────────────────
WITH tgt AS (                                                                                       -- 公共表表达式：开启中间结果集 tgt——964 笔之目标集
  SELECT CASE WHEN TRIM(bet09) IN ('Bear8', 'Lucky7TwoCard', 'SmallTiger',
                                   'SuperTie4', 'SuperTie5', 'SuperTie8', 'SuperTie9')
              THEN 'B_上线测试型' ELSE 'A_主群' END                       AS grp,                    -- 条件取值：证据分群，禁合并解释
         TRIM(bet05)                                                     AS mid,                    -- 取列：会员编号
         dt                                                              AS dt,                     -- 取列：分区日
         TRIM(bet04)                                                     AS tbl,                    -- 取列：桌号
         TRIM(bet09)                                                     AS g9,                     -- 取列：注型
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))                  AS stake                   -- 取列：本金
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8)) = 0                                       -- 并列条件：bet41 恰为零
    AND CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) > 0                                       -- 并列条件：validbet 为正
),                                                                                                  -- 续行：收束上方的子查询或函数括号
tot AS (                                                                                            -- 公共表表达式：开启中间结果集 tot——各群之总量
  SELECT grp, COUNT(*) AS n, SUM(stake) AS s FROM tgt GROUP BY grp                                  -- 取列与汇总：群、笔数、本金总额
),                                                                                                  -- 续行：收束上方的子查询或函数括号
mx AS (                                                                                             -- 公共表表达式：开启中间结果集 mx——五维之首位占量
  SELECT t.grp                                                           AS grp,                    -- 取列：证据群
         (SELECT MAX(c) FROM (SELECT grp AS g2, mid, COUNT(*) AS c FROM tgt GROUP BY grp, mid) x
           WHERE x.g2 = t.grp)                                           AS top_member_n,           -- 标量子查询：首位会员之笔数
         (SELECT MAX(c) FROM (SELECT grp AS g2, dt, COUNT(*) AS c FROM tgt GROUP BY grp, dt) x
           WHERE x.g2 = t.grp)                                           AS top_date_n,             -- 标量子查询：首位日期之笔数
         (SELECT MAX(c) FROM (SELECT grp AS g2, tbl, COUNT(*) AS c FROM tgt GROUP BY grp, tbl) x
           WHERE x.g2 = t.grp)                                           AS top_table_n,            -- 标量子查询：首位桌台之笔数
         (SELECT MAX(c) FROM (SELECT grp AS g2, g9, COUNT(*) AS c FROM tgt GROUP BY grp, g9) x
           WHERE x.g2 = t.grp)                                           AS top_bet09_n,            -- 标量子查询：首位注型之笔数
         (SELECT MAX(c) FROM (SELECT grp AS g2, mid, SUM(stake) AS c FROM tgt GROUP BY grp, mid) x
           WHERE x.g2 = t.grp)                                           AS top_stake_amt           -- 标量子查询：★ 单一会员之最大本金和——金额维
  FROM (SELECT DISTINCT grp FROM tgt) t                                                             -- 取数来源：各群一行
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  o.grp                                                                  AS grp,                    -- 取列：证据群
  o.n                                                                    AS n_rows,                 -- 取列：该群笔数
  (SELECT COUNT(DISTINCT mid) FROM tgt z WHERE z.grp = o.grp)            AS n_members,              -- 标量子查询：涉及会员数
  (SELECT COUNT(DISTINCT dt)  FROM tgt z WHERE z.grp = o.grp)            AS n_dates,                -- 标量子查询：涉及天数
  (SELECT COUNT(DISTINCT tbl) FROM tgt z WHERE z.grp = o.grp)            AS n_tables,               -- 标量子查询：涉及桌数
  (SELECT COUNT(DISTINCT g9)  FROM tgt z WHERE z.grp = o.grp)            AS n_bet09,                -- 标量子查询：涉及注型数
  ROUND(m.top_member_n * 100.0 / NULLIF(o.n, 0), 4)                      AS top1_member_share_pct,  -- 比率表达式：〔一层〕首位会员占比
  ROUND(m.top_date_n   * 100.0 / NULLIF(o.n, 0), 4)                      AS top_date_share_pct,     -- 比率表达式：〔一层〕首位日期占比
  ROUND(m.top_table_n  * 100.0 / NULLIF(o.n, 0), 4)                      AS top_table_share_pct,    -- 比率表达式：〔一层〕首位桌台占比
  ROUND(m.top_bet09_n  * 100.0 / NULLIF(o.n, 0), 4)                      AS top_bet09_share_pct,    -- 比率表达式：〔一层〕首位注型占比
  ROUND(m.top_stake_amt * 100.0 / NULLIF(o.s, 0), 4)                     AS top_stake_share_pct,    -- 比率表达式：〔一层〕★ 首位会员之本金占比——金额维
  CASE WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 30 THEN 'HIGH'
       WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 29 THEN 'NEAR' ELSE 'NORMAL' END AS st_member, -- 条件分支：〔二层〕会员维之三态
  CASE WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 30 THEN 'HIGH'
       WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 29 THEN 'NEAR' ELSE 'NORMAL' END AS st_date,   -- 条件分支：〔二层〕日期维之三态
  CASE WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 'HIGH'
       WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 29 THEN 'NEAR' ELSE 'NORMAL' END AS st_table,  -- 条件分支：〔二层〕桌台维之三态
  CASE WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 'HIGH'
       WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 29 THEN 'NEAR' ELSE 'NORMAL' END AS st_bet09,  -- 条件分支：〔二层〕注型维之三态
  CASE WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 30 THEN 'HIGH'
       WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 29 THEN 'NEAR' ELSE 'NORMAL' END AS st_stake,  -- 条件分支：〔二层〕金额维之三态
  (CASE WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
 + CASE WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
 + CASE WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
 + CASE WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
 + CASE WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 30 THEN 1 ELSE 0 END) AS n_dims_high,      -- 计算表达式：〔三层〕★ 高集中之维数
  (CASE WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
 + CASE WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
 + CASE WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
 + CASE WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
 + CASE WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 29 THEN 1 ELSE 0 END) AS n_dims_near_or_high, -- 计算表达式：〔三层〕★ 高或近之维数
  CASE                                                                                              -- 条件分支：〔三层〕起始分支——四态联合判词
    WHEN (CASE WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 30 THEN 1 ELSE 0 END) >= 2
      THEN 'MULTI_DIMENSION_SIGNAL'                                                                 -- 分支判定：二维以上为高
    WHEN (CASE WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
        + CASE WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
        + CASE WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
        + CASE WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 29 THEN 1 ELSE 0 END
        + CASE WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 29 THEN 1 ELSE 0 END) >= 2
      THEN 'MULTI_DIMENSION_NEAR_THRESHOLD'                                                         -- 分支判定：★ 二维以上为近——本版所补之缺口
    WHEN (CASE WHEN m.top_member_n  * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_date_n    * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_table_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_bet09_n   * 100.0 / NULLIF(o.n, 0) >= 30 THEN 1 ELSE 0 END
        + CASE WHEN m.top_stake_amt * 100.0 / NULLIF(o.s, 0) >= 30 THEN 1 ELSE 0 END) = 1
      THEN 'SINGLE_DIMENSION_SIGNAL'                                                                -- 分支判定：恰一维为高
    ELSE 'NO_CONCENTRATION_SIGNAL'                                                                  -- 分支判定：无高无近
  END                                                                    AS verdict_concentration,  -- 条件分支：收束上方判词，产出「verdict_concentration」
  ROUND(o.s, 2)                                                          AS sum_stake               -- 取列：该群本金总额
FROM tot o                                                                                          -- 取数来源：取自本条自建的中间结果集 tot
JOIN mx m ON m.grp = o.grp                                                                          -- 连接：按证据群接首位占量
ORDER BY o.grp;                                                                                     -- 排序：按群名排列；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之二条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁二十九 · 禁 post-hoc threshold fitting（★ 我方自禁）。
--   我上轮书「门槛设计有缺陷」，实即欲将 30% 下调以令本批数据显著。
--   **先看数据 → 再调门槛 → 再令其显著**，审计链上不允许。
--   ★ 故本版**阈值一分不动**，只改表达结构。
--     阈值之修订须另案冻结，且须**先于取数**——见数之后再定阈值，即是拟合。
--   ⚠ NEAR 之带宽（1 个百分点）亦系表达参数，非业务阈值；
--     其取 1pp 而非 2pp／5pp，同须另案冻结。本版书明此点，不掩饰其任意性。
--
-- 锁三十 · 连续指标恒出，禁只出 PASS／FAIL。
--   二元判词会把 29.15% 与 3% 归为同一态，信息损失不可逆。
--   ★ 五维原始占比恒列于输出，令读者得自判——**判词是辅助，非替代**。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
