-- =====================================================================
-- a168 · P0 审计查询稿 v1.2.0
-- 身份 : 审计临时复核语句 ★ 非总包条目、非交付件
-- 日期 : 2026-08-22
-- 对应基线 : v10-REDTEAM 审计基线 v1.0.3
-- 受审本体 : a168_取数与核验_SQL总包_v10.sql
--            9,475 行 | 1,195,130 字节 | CRLF | MD5(file) 62985e9b2932bd7ab70fba7ee9c01cb8
-- 版本沿革 : v1.0.0（§A-P0-0～3，跑毕）→ v1.1.0（§A-P0-4／5，跑毕）→ v1.2.0（§A-P0-6）
--            v1.1.0 依版本纪律移除；其查询原文与读数已固化于基线 §13.7／§13.8。
-- =====================================================================
-- 【边界声明】
--   ① 不改 v10 一字；② 输出一律存「审计/证据/」，⛔ 严禁存「数据库/」；
--   ③ 不占在册序号（§75／§76 为总包预留）；④ 不修改任何既有 CSV；
--   ⑤ P14／P15 恒在 R 侧；⑥ 960 行 D≠0 与 commission 哨兵值继续暂缓。
-- ---------------------------------------------------------------------
-- 【本轮唯一命题】
--   2026-05-19 之全量 re-sync，究竟传播到哪些已交付 CSV，传播到什么程度。
-- ---------------------------------------------------------------------
-- 【审计对象之四层（不得只做 SQL 静态扫描）】
--   L1 SQL 逻辑层      —— 该件是否含 rn=1（已由 Gate Matrix v1 实测，非本稿职责）
--   L2 源数据层        —— 05-19 之 raw 与 canonical 差额（本稿 §A-P0-6a～6f 产出）
--   L3 已交付 CSV 层   —— 既有 CSV 之 05-19 记录（⛔ SQL 读不到，须由 R 侧比对器读）
--   L4 最终分析指标层  —— 该件粒度上之指标是否继承双计数（本稿产 canonical 基准供对照）
--   ★ 本稿只能覆盖 L2 与 L4 之基准侧；L3 由 `审计/工具/A_P0_06_csv_provenance.R` 承担。
--     二者合起方成完整判定。单跑本稿不足以出五态裁定。
-- ---------------------------------------------------------------------
-- 【已由结构分析先行收窄之范围（OBSERVED，2026-08-22 逐段实测 v10 原文）】
--   TL08（锚7671）／TL10（锚7745）／TL11（锚7834）／TL11c（锚8103）
--     其 bet02 之唯一用法为 `SELECT DISTINCT CAST(bet05 AS STRING)`（会员宇宙）
--     ＋ TL11 另有 `GROUP BY CAST(bet05 AS STRING)` 取 MAX(dt)／COUNT(*)。
--     → DISTINCT 与 MAX 对版本重复**结构性免疫**；唯 TL11 之 `n_bets_in_window`
--       系 COUNT(*)，**不免疫**。此为四件中唯一暴露点，须实证（§A-P0-6b）。
--   P0C04（锚6919）／P0C09（锚7121）：bet02 以 JOIN 会员集合后 `COUNT(*)`＋
--     `SUM(validbet)` 逐日聚合 → **计数与金额俱暴露**。
--   P0C05（锚6966）：无日粒度分组，暴露形态待实证。
--   ⚠ 以上系**结构推断（INFERRED）**，仅用于排定实证次序；
--     ⛔ 不得据此填矩阵——矩阵之 `?` 一律须由实测证据填。
-- ---------------------------------------------------------------------
-- 【口径纪律】沿用 DECIMAL(20,4) 与 CAST(NULLIF(TRIM(x),''))；窗口 dt 字面量；
--   金额原币混计，仅供 raw／canonical 臂间比较，⛔ 不得作业务解读。
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-6a · 2026-05-19 单日 · 注单层 raw vs canonical（COUNT ＋ VALUE ＋ RATIO 三合一）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_06a_day_baseline.csv」
-- ▸ 读法（三类污染一表尽出）：
--     COUNT_CONTAMINATION → n_rows／n_bets 之 ratio_new_over_old 应为 0.5（即 raw 为 canonical 之 2 倍）
--     VALUE_CONTAMINATION → stake／validbet／bet16／game_pnl 之 ratio 亦应为 0.5
--     RATIO_CONTAMINATION → roi／hold／win_rate 之 ratio 应为 1.0 —— **此即假阴性之形貌**：
--       分子分母同倍，比例纹丝不动。凡只查「是否翻倍」之审计，必然放过此类件。
--   ⚠ ratio 若非恰 0.5／1.0，须回查——本日既测每单恰两版，任何偏离皆属异常。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号铸型
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额（原币）
         CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,4))      AS b14,                       -- 取值：派彩金额（原币）
         CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序，三键承包内既锁之优先级
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：注单明细主表（表一）
  WHERE dt = '2026-05-19'                                                                   -- 过滤：唯一受污染之营业日
    AND bet02 = '101'                                                                       -- 过滤：百家乐产品闸
),
arms AS (
  SELECT 'RAW_未去重'   AS arm, bet01, member_id, b13, b14, b16, vb FROM src                -- 取列：raw 臂（既有 CSV 若无 rn=1 即此形）
  UNION ALL
  SELECT 'CANON_rn1',   bet01, member_id, b13, b14, b16, vb FROM src WHERE rn = 1           -- 取列：canonical 臂（正解）
)
SELECT arm                                                   AS arm,                       -- 取列：口径锁——缺此列即无从分辨行属何臂
       COUNT(*)                                              AS n_rows,                    -- 计数：注单行数            【COUNT】
       COUNT(DISTINCT bet01)                                 AS n_bet01,                   -- 计数：去重注单号          【COUNT】
       COUNT(DISTINCT member_id)                             AS n_members,                 -- 计数：会员数（预期两臂相同）【COUNT】
       ROUND(SUM(b13), 4)                                    AS sum_stake,                 -- 汇总：下注金额            【VALUE】
       ROUND(SUM(vb), 4)                                     AS sum_validbet,              -- 汇总：有效投注            【VALUE】
       ROUND(SUM(b16), 4)                                    AS sum_rebate16,              -- 汇总：退水金额            【VALUE】
       ROUND(SUM(b14 - b13), 4)                              AS sum_game_pnl,              -- 汇总：会员净输赢          【VALUE】
       ROUND(-SUM(b14 - b13), 4)                             AS sum_ggr,                   -- 汇总：取负即平台毛利      【VALUE】
       ROUND(SUM(b14 - b13) / NULLIF(SUM(b13), 0), 8)        AS roi_on_stake,              -- 除法：ROI（本金基数）     【RATIO】
       ROUND(-SUM(b14 - b13) / NULLIF(SUM(vb), 0), 8)        AS hold_on_validbet,          -- 除法：hold（洗码基数）    【RATIO】
       ROUND(SUM(CASE WHEN b14 > b13 THEN 1 ELSE 0 END) * 1.0
             / NULLIF(COUNT(*), 0), 8)                       AS win_rate_order,            -- 除法：订单胜率            【RATIO】
       ROUND(SUM(b16) / NULLIF(SUM(vb), 0), 8)               AS rebate_rate,               -- 除法：退水率              【RATIO】
       ROUND(SUM(b13) / NULLIF(COUNT(*), 0), 4)              AS avg_stake                  -- 除法：均注额（均值类）    【RATIO】
FROM arms                                                                                   -- 取数来源：中间结果集 arms
GROUP BY arm                                                                                -- 分组：按臂
ORDER BY arm;                                                                               -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-6b · 会员宇宙之免疫性实证（TL 族四件之决定性一条）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_06b_universe_immunity.csv」
-- ▸ 何以为决定性：TL08／TL10／TL11／TL11c 之 bet02 用法皆为
--   `SELECT DISTINCT bet05`（会员宇宙）；TL11 另取 MAX(dt) 与 COUNT(*)。
--   DISTINCT 与 MAX 对重复行天然免疫，COUNT(*) 则否。
--   本条同时实证三者，一表定四件之命运。
-- ▸ 判据：n_members_raw = n_members_canon 且 last_bet_date 全等 → DISTINCT／MAX 免疫成立；
--         n_bets_raw ≠ n_bets_canon → TL11 之 n_bets_in_window 确受污染。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         CAST(bet05 AS STRING)                               AS member_id,                 -- 取值：会员号取字符串（逐字沿用 TL 族写法，便于可比）
         dt                                                  AS dt,                        -- 取列：营业日
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：全窗（TL 族之窗，非仅 05-19）
    AND CAST(bet02 AS STRING) = '101'                                                       -- 过滤：百家乐（逐字沿用 TL 族写法）
),
raw_u AS (
  SELECT member_id                                           AS member_id,                 -- 取列：会员号
         MAX(dt)                                             AS last_bet_date,             -- 聚合：末次投注营业日（TL11 用）
         COUNT(*)                                            AS n_bets_in_window           -- 计数：窗内注单数（TL11 用；★ 不免疫）
  FROM src GROUP BY member_id                                                               -- 取数来源：src；分组：按会员
),
canon_u AS (
  SELECT member_id                                           AS member_id,                 -- 取列：会员号
         MAX(dt)                                             AS last_bet_date,             -- 聚合：末次投注营业日
         COUNT(*)                                            AS n_bets_in_window           -- 计数：窗内注单数
  FROM src WHERE rn = 1 GROUP BY member_id                                                  -- 取数来源：src；过滤：最新版本；分组：按会员
)
SELECT (SELECT COUNT(*) FROM raw_u)                          AS n_members_raw,             -- 计数：raw 侧会员宇宙大小
       (SELECT COUNT(*) FROM canon_u)                        AS n_members_canon,           -- 计数：canonical 侧会员宇宙大小
       (SELECT COUNT(*) FROM raw_u r JOIN canon_u c
          ON c.member_id = r.member_id)                      AS n_members_common,          -- 计数：两侧共有之会员数
       (SELECT COUNT(*) FROM raw_u r JOIN canon_u c
          ON c.member_id = r.member_id
         WHERE c.last_bet_date <> r.last_bet_date)           AS n_lastdate_differ,         -- 计数：末次日期相异之会员数（预期 0）
       (SELECT COUNT(*) FROM raw_u r JOIN canon_u c
          ON c.member_id = r.member_id
         WHERE c.n_bets_in_window <> r.n_bets_in_window)     AS n_nbets_differ,            -- 计数：注单数相异之会员数（预期 21,225）
       (SELECT SUM(r.n_bets_in_window) FROM raw_u r)         AS sum_nbets_raw,             -- 汇总：raw 侧注单数合计
       (SELECT SUM(c.n_bets_in_window) FROM canon_u c)       AS sum_nbets_canon;           -- 汇总：canonical 侧注单数合计


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-6c · 平台×日 canonical 基准（对应 §P12a；兼作 TIME_SERIES 之底料）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_06c_platform_daily_baseline.csv」
-- ▸ 读法：两臂逐日并置，R 侧可直接与既有 P12a_platform_daily.csv 对照。
--   05-19 之外各日两臂应逐项相等；若不等，即另有未知污染源，须回查。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT dt                                                  AS dt,                        -- 取列：营业日
         bet01                                               AS bet01,                     -- 取列：注单号
         CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额
         CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,4))      AS b14,                       -- 取值：派彩金额
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：全窗
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
arms AS (
  SELECT 'RAW_未去重' AS arm, dt, member_id, b13, b14, vb FROM src                          -- 取列：raw 臂
  UNION ALL
  SELECT 'CANON_rn1',  dt, member_id, b13, b14, vb FROM src WHERE rn = 1                    -- 取列：canonical 臂
)
SELECT arm                                                   AS arm,                       -- 取列：口径锁
       dt                                                    AS dt,                        -- 取列：营业日
       COUNT(*)                                              AS n_bets,                    -- 计数：当日注单数
       COUNT(DISTINCT member_id)                             AS n_members,                 -- 计数：当日活跃会员数
       ROUND(SUM(b13), 4)                                    AS stake,                     -- 汇总：当日下注金额
       ROUND(SUM(vb), 4)                                     AS validbet,                  -- 汇总：当日有效投注
       ROUND(-SUM(b14 - b13), 4)                             AS ggr,                       -- 汇总：当日平台毛利
       ROUND(-SUM(b14 - b13) / NULLIF(SUM(vb), 0), 8)        AS hold                       -- 除法：当日 hold（比例类）
FROM arms                                                                                   -- 取数来源：中间结果集 arms
GROUP BY arm, dt                                                                            -- 分组：臂 × 营业日
ORDER BY arm, dt;                                                                           -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-6d · 会员×日 canonical 基准（对应 §T02／§B01／§P12c；仅 05-19）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_06d_member_day_baseline.csv」
-- ▸ 仅取 05-19：会员×日全窗逾千万行，导出不经济；污染既已定位于单日，
--   基准只需该日即足。R 侧以 (member_id, 2026-05-19) 为键与既有 CSV 对照。
-- ▸ 逐员并置两臂之比值 r_n_bets：若恒为 0.5，则该员当日全数双计；
--   若介于 0.5~1，则该员部分注单双计——既测「每单恰两版」，故预期恒为 0.5。
--   任何非 0.5 之值皆须回查，是内部一致性之守门。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额
         CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,4))      AS b14,                       -- 取值：派彩金额
         CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt = '2026-05-19'                                                                   -- 过滤：受污染之营业日
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
raw_m AS (
  SELECT member_id, COUNT(*) AS n_bets, SUM(b13) AS stake,                                  -- 计数与汇总：raw 侧逐员
         SUM(vb) AS validbet, SUM(b16) AS rebate, SUM(b14 - b13) AS game_pnl
  FROM src GROUP BY member_id                                                               -- 取数来源：src；分组：按会员
),
canon_m AS (
  SELECT member_id, COUNT(*) AS n_bets, SUM(b13) AS stake,                                  -- 计数与汇总：canonical 侧逐员
         SUM(vb) AS validbet, SUM(b16) AS rebate, SUM(b14 - b13) AS game_pnl
  FROM src WHERE rn = 1 GROUP BY member_id                                                  -- 取数来源：src；过滤：最新版本
)
SELECT c.member_id                                           AS member_id,                 -- 取列：会员号
       DATE('2026-05-19')                                    AS bet_date,                  -- 取值：营业日常量（对照键之一）
       r.n_bets                                              AS n_bets_raw,                -- 取列：raw 注单数
       c.n_bets                                              AS n_bets_canon,              -- 取列：canonical 注单数
       ROUND(c.n_bets * 1.0 / NULLIF(r.n_bets, 0), 6)        AS r_n_bets,                  -- 除法：比值（预期恒 0.5）
       ROUND(r.stake, 4)    AS stake_raw,    ROUND(c.stake, 4)    AS stake_canon,           -- 取列：下注金额两臂
       ROUND(r.validbet, 4) AS validbet_raw, ROUND(c.validbet, 4) AS validbet_canon,        -- 取列：有效投注两臂
       ROUND(r.rebate, 4)   AS rebate_raw,   ROUND(c.rebate, 4)   AS rebate_canon,          -- 取列：退水两臂
       ROUND(r.game_pnl, 4) AS game_pnl_raw, ROUND(c.game_pnl, 4) AS game_pnl_canon,        -- 取列：净输赢两臂
       ROUND(c.game_pnl / NULLIF(c.stake, 0), 8)             AS roi_canon,                 -- 除法：canonical ROI
       ROUND(r.game_pnl / NULLIF(r.stake, 0), 8)             AS roi_raw                    -- 除法：raw ROI（预期与 canonical 相等——假阴性）
FROM canon_m c                                                                              -- 取数来源：canonical 侧
JOIN raw_m r ON r.member_id = c.member_id                                                   -- 内联结：按会员配对 raw 侧
ORDER BY c.member_id;                                                                       -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-6e · 玩家×荷官×日 canonical 基准（对应 §R03b；仅 05-19）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_06e_player_dealer_day_baseline.csv」
-- ▸ R03b 另有截断悬案（预期 18,139,550 行、实得 6,143,388 行、STOP CAUSE UNKNOWN）。
--   ⛔ 本条只判「05-19 是否双计」，**不涉截断**；二命题不得混谈，
--     亦不得以本条之结果解释截断，或以截断解释本条。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号
         TRIM(COALESCE(eid, ''))                             AS dealer_id,                 -- 取值：荷官工号
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额
         CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,4))      AS b14,                       -- 取值：派彩金额
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt = '2026-05-19'                                                                   -- 过滤：受污染之营业日
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
arms AS (
  SELECT 'RAW_未去重' AS arm, member_id, dealer_id, b13, b14 FROM src                       -- 取列：raw 臂
  UNION ALL
  SELECT 'CANON_rn1',  member_id, dealer_id, b13, b14 FROM src WHERE rn = 1                 -- 取列：canonical 臂
)
SELECT arm                                                   AS arm,                       -- 取列：口径锁
       COUNT(*)                                              AS n_bets,                    -- 计数：注单数
       COUNT(DISTINCT CONCAT(CAST(member_id AS STRING), '|', dealer_id))                    -- 计数：玩家×荷官配对数
                                                             AS n_pairs,                   --        （DISTINCT，预期两臂相同）
       COUNT(DISTINCT dealer_id)                             AS n_dealers,                 -- 计数：荷官数（预期两臂相同）
       ROUND(SUM(b13), 4)                                    AS stake,                     -- 汇总：下注金额
       ROUND(SUM(CASE WHEN b14 > b13 THEN 1 ELSE 0 END) * 1.0
             / NULLIF(COUNT(*), 0), 8)                       AS win_rate_order             -- 除法：订单胜率（比例类，预期两臂相同）
FROM arms                                                                                   -- 取数来源：中间结果集 arms
GROUP BY arm                                                                                -- 分组：按臂
ORDER BY arm;                                                                               -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-6f · P0C 族之暴露实证（P0C04／P0C05／P0C09 共用同一 bet02 聚合形态）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_06f_p0c_exposure.csv」
-- ▸ P0C 族之 bet02 用法：JOIN 标记会员集合后，逐（会员×日）取 COUNT(*) 与 SUM(validbet)。
--   本条以「05-19 是否落在标记会员之观察窗内」为准，输出该日之两臂对照。
-- ▸ ⚠ 本条不重建 P0C 之标记逻辑（其料源为 dailyreport_member，另有口径）；
--   只测「若标记会员于 05-19 有注单，其注单数与洗码量是否双计」。
--   标记侧是否亦受污染，属另一命题，本稿不答（dailyreport_member 未在本轮扫描范围）。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         CAST(bet05 AS STRING)                               AS mem,                       -- 取值：会员号取字符串（逐字沿用 P0C 族写法）
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt = '2026-05-19'                                                                   -- 过滤：受污染之营业日
    AND CAST(bet02 AS STRING) = '101'                                                       -- 过滤：百家乐（逐字沿用 P0C 族写法）
),
arms AS (
  SELECT 'RAW_未去重' AS arm, mem, vb FROM src                                              -- 取列：raw 臂
  UNION ALL
  SELECT 'CANON_rn1',  mem, vb FROM src WHERE rn = 1                                        -- 取列：canonical 臂
)
SELECT arm                                                   AS arm,                       -- 取列：口径锁
       COUNT(DISTINCT mem)                                   AS n_mem,                     -- 计数：当日有注单之会员数（预期两臂相同）
       COUNT(*)                                              AS 注单数,                    -- 计数：注单数（P0C 族列名，预期 raw 为 2 倍）
       ROUND(SUM(vb), 4)                                     AS 洗码量,                    -- 汇总：有效投注（P0C 族列名，预期 raw 为 2 倍）
       ROUND(SUM(vb) / NULLIF(COUNT(*), 0), 6)               AS 单注洗码均值,              -- 除法：均值类（预期两臂相同——假阴性）
       ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT mem), 0), 6) AS 人均注单数              -- 除法：人均（预期 raw 为 2 倍——非假阴性）
FROM arms                                                                                   -- 取数来源：中间结果集 arms
GROUP BY arm                                                                                -- 分组：按臂
ORDER BY arm;                                                                               -- 排序：稳定唯一序


-- =====================================================================
-- 【跑毕之后 · L3 层由 R 侧比对器承担】
--   本稿只产 canonical 基准（L2／L4）。判定五态须再跑：
--       审计/工具/A_P0_06_csv_provenance.R
--   其法：读 数据库/ 下十一件既有 CSV，取其 2026-05-19 之记录，
--         与本稿 canonical 基准比对，按下列出口落定：
--
--     A. CLEAN               SQL 与 CSV 皆无实际污染
--     B. SQL_DEFECT_ONLY     SQL 缺闸，但历史 CSV 实际未受影响 → 修 SQL、不必重生 CSV
--     C. CSV_CONTAMINATED    历史交付件确受污染（SQL 或已正确）→ 须重生 CSV
--     D. BOTH                SQL 缺闸且 CSV 已污染 → **v12-Q ＋ CSV 重生成之最高优先级**
--     E. PROVENANCE_UNKNOWN  无法证明历史 CSV 之生成血统 → ⛔ 禁猜，保持 UNKNOWN
--
--   ⛔ 内部一致性 Gate（写死）：
--     · SQL 已有 rn=1 而 CSV 之 05-19 仍呈 observed = 2 × canonical
--       → 判 **SQL SAFE / CSV CONTAMINATED**（即 C），⛔ 不得写成 SQL FAIL。
--     · SQL 无 rn=1 而 CSV 恰由另一已去重之上游生成
--       → ⛔ 不得仅凭缺闸即宣称 CSV 已污染，须实测。
--     · 该件之 CSV 若不存在或无 05-19 记录 → 判 E，禁以「大概没跑到那天」代之。
--
--   ⛔ 矩阵中一切 `?` 须由实测证据填，禁自 SQL 结构推断。
--      本稿开头之「结构分析先行收窄」仅用于排定次序，其等级为 INFERRED。
--
-- 【本轮不答之三事（须显式留白，勿以沉默充作已查）】
--   ① dailyreport_member 侧是否亦含版本重复（P0C 族之标记侧料源）
--   ② R03b 之 STOP CAUSE 截断（与本命题无关，不得互相解释）
--   ③ 960 行 D≠0 与 commission 六类哨兵值（依裁定暂缓）
-- =====================================================================
