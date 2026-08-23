-- ══════════════════════════════════════════════════════════════════════════
-- §VB-41c · 964 笔 bet41 = 0 ∧ validbet > 0 之逐笔画像  审计工具 v1.0.0
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由（问题已升级，不再是恒等检验）：
--   §VB-41b v1.0.2 实测已坐实：964 笔差异 **100% 属 bet41 = 0 ∧ validbet > 0**，
--   反向（bet41 > 0 ∧ validbet = 0）**一笔皆无**。
--   → 故问题已自「二列为何有 964 笔不同」升级为
--     **「为何 bet41 于 964 笔上完全未写入，而 validbet 已有值」**——
--     此非恒等检验，系**字段生成链追踪**。
--
-- ★ 六种候选成因（承裁示 · 逐一列明，禁提前择一）：
--     ① 字段未初始化          ② 某类注单本不参与 bet41
--     ③ 结算后方写入          ④ 某规则明确将 bet41 置零
--     ⑤ ETL 映射遗漏          ⑥ 新玩法字段尚未接入
--   ★ 本件之目标**不是证明系统 BUG**，而是把候选成因缩小至
--     可由上游字段定义验证之范围。**成因现为 UNKNOWN，禁跨级书 SYSTEM BUG。**
--
-- 【两层结构 · 第一层禁 GROUP BY】
--   §VB-41c-1  逐笔明细 964 行 —— **一笔一行，不聚合**
--   §VB-41c-2  五维集中度  —— 会员／时间／桌与荷官／注额／玩法
--   ★ 先有明细，后有聚合；聚合掉原始记录即无从追成因。
--
-- 【证据须拆两群（承锁二十六）】
--   A 群：主群 964 笔结构性差异
--   B 群：七笔上线测试型观察（Bear8／Lucky7TwoCard／SmallTiger／SuperTie4/5/8/9）
--   ★ 二者数学形态相同（n_rows=1、bet41=0、validbet=10），
--     惟**只得书「具有相同之字段表现模式」，禁书「确定同源」**。
--     本件以 grp 列标之，令二群自始分列，不待事后再拆。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41c-1 · 逐笔明细（★ 一笔一行 · 禁聚合 · 预期 964 行）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41c1_964_detail.csv」。
--   ★ 判读：行数须恰为 964；非此数即上游筛选条件与 §VB-41b 不一致。
--   ★ grp 列自始分 A／B 二群，免事后混判。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  CASE WHEN TRIM(bet09) IN ('Bear8', 'Lucky7TwoCard', 'SmallTiger',
                            'SuperTie4', 'SuperTie5', 'SuperTie8', 'SuperTie9')
       THEN 'B_上线测试型' ELSE 'A_主群' END                                AS grp,                    -- 条件取值：★ 证据分群，承锁二十六
  TRIM(bet01)                                                            AS bet01,                  -- 取列：注单唯一键
  TRIM(bet05)                                                            AS member_id,              -- 取列：会员编号
  dt                                                                     AS dt,                     -- 取列：分区日
  TRIM(bet08)                                                            AS bet_time,               -- 取列：投注时间
  TRIM(bet04)                                                            AS table_id,               -- 取列：桌号
  TRIM(bet03)                                                            AS shoe_id,                -- 取列：靴号
  TRIM(bet09)                                                            AS bet09,                  -- 取列：注型
  TRIM(commission)                                                       AS commission,             -- 取列：佣金标记
  TRIM(category)                                                         AS category,               -- 取列：注单类别
  TRIM(bet38)                                                            AS rebet_flag,             -- 取列：重对标记
  TRIM(bet18)                                                            AS agent_lv1,              -- 取列：一级代理——判是否测试线
  CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))                         AS stake_raw,              -- 取列：本金（原币）
  CAST(NULLIF(TRIM(bet11), '') AS DECIMAL(20,8))                         AS fx_rate,                -- 取列：汇率
  CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))                         AS payout_raw,             -- 取列：派彩（原币）
  CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,8))                         AS rebate_raw,             -- 取列：退水（原币）
  CAST(NULLIF(TRIM(bet17), '') AS DECIMAL(20,8))                         AS net_raw,                -- 取列：会员净额（原币）
  CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))                         AS bet41,                  -- 取列：★ 恒为 0
  CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))                      AS validbet,               -- 取列：★ 恒为正
  CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))
    - CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))                     AS diff_vb_minus_b41,      -- 取值表达式：★ 缺失额 ＝ validbet − bet41
  TRIM(updatetime)                                                       AS updatetime,             -- 取列：★ 更新时间——判是否结算后方写入（候选成因③）
  TRIM(sync_time)                                                        AS sync_time               -- 取列：★ 同步时间——判是否 ETL 环节所致（候选成因⑤）
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8)) = 0                                         -- 并列条件：★ bet41 恰为零
  AND CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) > 0                                         -- 并列条件：★ validbet 为正
ORDER BY grp, dt, bet_time, member_id, bet01;                                                       -- 排序：按群、日、时、会员、注单排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §VB-41c-2 · 五维集中度（★ 第二层聚合 · 明细已出方跑此条）
-- ▸ 导出：需要 —— 存为「审计/_vb/_VB_41c2_concentration.csv」。
--   ★ 判读：
--     top1_member_share 高 → 集中于少数会员，属**风控线索**
--     n_dates 逼近 139     → 散布全窗，属**系统性规则或漏记**
--     top_date_share 高    → 集中于少数日期，或与某次变更／上线同期
--   ★ 二群分列输出，禁合并——承锁二十六。
-- ──────────────────────────────────────────────────────────────────────────
WITH tgt AS (                                                                                       -- 公共表表达式：开启中间结果集 tgt——964 笔之目标集
  SELECT CASE WHEN TRIM(bet09) IN ('Bear8', 'Lucky7TwoCard', 'SmallTiger',
                                   'SuperTie4', 'SuperTie5', 'SuperTie8', 'SuperTie9')
              THEN 'B_上线测试型' ELSE 'A_主群' END                       AS grp,                    -- 条件取值：证据分群
         TRIM(bet05)                                                     AS mid,                    -- 取列：会员编号
         dt                                                              AS dt,                     -- 取列：分区日
         TRIM(bet04)                                                     AS tbl,                    -- 取列：桌号
         TRIM(bet09)                                                     AS g9,                     -- 取列：注型
         TRIM(commission)                                                AS comm,                   -- 取列：佣金标记
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))                  AS stake,                  -- 取列：本金
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))               AS vvb                     -- 取列：validbet
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
    AND CAST(NULLIF(TRIM(bet41), '')    AS DECIMAL(20,8)) = 0                                       -- 并列条件：bet41 恰为零
    AND CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) > 0                                       -- 并列条件：validbet 为正
),                                                                                                  -- 续行：收束上方的子查询或函数括号
by_mid AS (                                                                                         -- 公共表表达式：开启中间结果集 by_mid——逐会员计数
  SELECT grp, mid, COUNT(*) AS n, SUM(vvb) AS s                                                     -- 取列与汇总：会员、笔数、缺失额
  FROM tgt GROUP BY grp, mid                                                                        -- 分组：按群与会员汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号
by_dt AS (                                                                                          -- 公共表表达式：开启中间结果集 by_dt——逐日计数
  SELECT grp, dt, COUNT(*) AS n FROM tgt GROUP BY grp, dt                                           -- 取列与汇总：群、日、笔数
),                                                                                                  -- 续行：收束上方的子查询或函数括号
by_tbl AS (                                                                                         -- 公共表表达式：开启中间结果集 by_tbl——逐桌计数
  SELECT grp, tbl, COUNT(*) AS n FROM tgt GROUP BY grp, tbl                                         -- 取列与汇总：群、桌、笔数
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  t.grp                                                                  AS grp,                    -- 取列：证据群
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该群笔数
  COUNT(DISTINCT t.mid)                                                  AS n_members,              -- 计数表达式：★ A 维——涉及会员数
  ROUND((SELECT MAX(n) FROM by_mid m WHERE m.grp = t.grp) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS top1_member_share_pct,  -- 比率表达式：★★ 首位会员占比——集中度之判据
  (SELECT MAX(n) FROM by_mid m WHERE m.grp = t.grp)                      AS top1_member_n,          -- 标量子查询：首位会员之笔数
  ROUND((SELECT MAX(s) FROM by_mid m WHERE m.grp = t.grp), 2)            AS max_member_diff_sum,    -- 标量子查询：单一会员之最大缺失额
  COUNT(DISTINCT t.dt)                                                   AS n_dates,                -- 计数表达式：★ B 维——涉及天数（对照全窗 139）
  MIN(t.dt)                                                              AS min_date,               -- 聚合取值：首现日
  MAX(t.dt)                                                              AS max_date,               -- 聚合取值：末现日
  (SELECT MAX(n) FROM by_dt d WHERE d.grp = t.grp)                       AS top_date_n,             -- 标量子查询：单日最多笔数
  ROUND((SELECT MAX(n) FROM by_dt d WHERE d.grp = t.grp) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS top_date_share_pct,     -- 比率表达式：★ 首位日期占比
  COUNT(DISTINCT t.tbl)                                                  AS n_tables,               -- 计数表达式：★ C 维——涉及桌数
  ROUND((SELECT MAX(n) FROM by_tbl b WHERE b.grp = t.grp) * 100.0
        / NULLIF(COUNT(*), 0), 4)                                        AS top_table_share_pct,    -- 比率表达式：首位桌台占比
  COUNT(DISTINCT t.g9)                                                   AS n_bet09,                -- 计数表达式：★ E 维——涉及注型数
  COUNT(DISTINCT t.comm)                                                 AS n_commission,           -- 计数表达式：涉及佣金制数
  ROUND(SUM(t.stake), 2)                                                 AS sum_stake,              -- 汇总表达式：★ D 维——本金总额
  ROUND(SUM(t.vvb), 2)                                                   AS sum_validbet,           -- 汇总表达式：validbet 总额（＝ 缺失额，因 bet41 恒零）
  ROUND(MIN(t.stake), 2)                                                 AS min_stake,              -- 聚合取值：最小本金
  ROUND(MAX(t.stake), 2)                                                 AS max_stake,              -- 聚合取值：最大本金
  CASE                                                                                              -- 条件分支：起始分支——集中度裁定
    WHEN (SELECT MAX(n) FROM by_mid m WHERE m.grp = t.grp) * 1.0
         / NULLIF(COUNT(*), 0) >= 0.30
      THEN '★ 高度集中于少数会员 —— 属风控线索，须逐会员追'                                             -- 分支判定：会员集中
    WHEN COUNT(DISTINCT t.dt) * 1.0 / 139 >= 0.50
      THEN '◐ 散布全窗过半天数 —— 倾向系统性规则或持续漏记，非单次事件'                                   -- 分支判定：时间散布
    WHEN (SELECT MAX(n) FROM by_dt d WHERE d.grp = t.grp) * 1.0
         / NULLIF(COUNT(*), 0) >= 0.30
      THEN '◐ 集中于少数日期 —— 须核该期是否有变更、上线或重同步'                                        -- 分支判定：时间集中
    ELSE '◐ 无单一维度显著集中 —— 须并读五维方可判'                                                    -- 分支判定：无显著集中
  END                                                                    AS verdict_concentration   -- 条件分支：收束上方判词，产出「verdict_concentration」
FROM tgt t                                                                                          -- 取数来源：取自本条自建的中间结果集 tgt
GROUP BY t.grp                                                                                      -- 分组：按证据群汇总
ORDER BY t.grp;                                                                                     -- 排序：按群名排列；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之二条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁二十七 · 先明细，后聚合。
--   第一层须一笔一行，**禁先 GROUP BY**。聚合掉原始记录，即无从追成因——
--   updatetime／sync_time／bet01 一旦被聚合，候选成因③⑤即永远查不下去。
--
-- 锁二十八 · 成因须缩范围，非择一定谳。
--   本件之目标系把六种候选成因缩至可由上游字段定义验证之范围：
--     若集中于少数会员           → 排除⑤⑥，倾向②④
--     若散布全窗且跨多玩法       → 排除②，倾向①⑤
--     若集中于某数日             → 须核该期有无变更／上线／重同步
--     若 updatetime 皆晚于 bet08 → 倾向③
--   ★ **无论何种形态，成因仍判 UNKNOWN，直至上游字段定义确认。**
--     禁书「系统漏记」「SYSTEM BUG」——OBSERVED 与成因裁定之间隔着一层。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
