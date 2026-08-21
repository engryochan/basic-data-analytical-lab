-- =====================================================================
-- a168 · P0 审计查询稿 v1.0.0
-- 身份 : 审计临时复核语句 ★ 非总包条目、非交付件
-- 日期 : 2026-08-22
-- 对应基线 : v10-REDTEAM 审计基线 v1.0.1
-- 受审本体 : a168_取数与核验_SQL总包_v10.sql
--            9,475 行 | 1,195,130 字节 | CRLF | MD5(file) 62985e9b2932bd7ab70fba7ee9c01cb8
-- =====================================================================
-- 【边界声明 · 三条，最要紧】
--   ① 本稿不修改 v10 之 §P01E／§P01C 一字。v10 永不斧正；本稿只产证据。
--   ② 本稿所有输出一律存入「审计/证据/」，⛔ 严禁存入「数据库/」——
--      后者为交付契约命名空间，混入即令集合身份 v10-93（6c14ab6f69a8）失真。
--   ③ 本稿不占在册序号。§75／§76 系总包新条之预留，审计稿另用 §A-P0-x 编号。
-- ---------------------------------------------------------------------
-- 【口径纪律 · 为求可比而刻意「不归化」】
--   本稿沿用 §P01E／§P01C 之 DECIMAL(20,4) 与 CAST(NULLIF(TRIM(x),'')) 写法，
--   逐字不改。⚠ 不得顺手升为 DECIMAL(20,8)——一改即引入第二个变因，
--   Δ 便无从归因于「版本去重」抑或「精度变更」。归化属 v12-Q，不属本稿。
--   窗口一律 dt >= '2026-03-21' AND dt < '2026-08-07'，与主窗口逐字相同。
--   金额列为原币混计（未经 bet11 换汇）：两臂同基准，仅供 OLD/NEW 之 Δ 比较，
--   ⛔ 不得作任何业务解读。
-- ---------------------------------------------------------------------
-- 【执行次序 · 不得倒序】
--   §A-P0-0  → 版本多重性普查（若窗口内无多版本，则 §A-P0-1 之 Δ 必为零，全案收敛）
--   §A-P0-0b → 版本排序键之可用性（ORDER BY 三键若有 NULL 或并列，rn=1 之「首版」即不唯一）
--   §A-P0-1  → P01E 双臂读数
--   §A-P0-2  → P01E Δ 对照
--   §A-P0-3  → P01C 双轨读数
-- ---------------------------------------------------------------------
-- 【预测之可证伪性】
--   基线曾登记「去重后匹配率只升不降」——此为【可证伪预测】，非结论。
--   ⛔ 不得预设 rn=1 后必然改善。数据裁定之，非吾人裁定之。
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-0 · 版本多重性普查（★ 最先跑；本案是否成立，此条即决）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_00_version_multiplicity.csv」
-- ▸ 读法：n_extra_versions = 0 时，窗口内每张注单只一版，
--         则 §A-P0-1 之 OLD 与 NEW 必逐项相同，P0 命题当场收敛为「无影响」。
--         n_extra_versions > 0 时，方须续跑其余各条。
-- ─────────────────────────────────────────────────────────────────────
SELECT COUNT(*)                                              AS n_rows,                    -- 计数：窗口内注单行数（含各版本）
       COUNT(DISTINCT bet01)                                 AS n_bet01,                   -- 计数：去重后之注单号个数
       COUNT(*) - COUNT(DISTINCT bet01)                      AS n_extra_versions,          -- 加减：多出之版本行数；为 0 即无多版本
       ROUND((COUNT(*) - COUNT(DISTINCT bet01)) * 100.0
             / NULLIF(COUNT(*), 0), 6)                       AS extra_version_pct          -- 除法：多版本行占比（百分点）
FROM ods_mariadb_2b.ods_a168_bet02                                                          -- 取数来源：注单明细主表（表一）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                              -- 过滤：主窗口，与 §P01E 逐字相同
  AND bet02 = '101';                                                                        -- 过滤：百家乐产品闸


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-0a · 每注单版本数之分布（承上；仅当 n_extra_versions > 0 才须跑）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_00a_version_hist.csv」
-- ▸ 读法：v_cnt 为某注单之版本数；n_bet01 为具该版本数之注单个数。
--         若 max(v_cnt) 甚大而集中于少数注单，则「改单频繁者被多计」之
--         非均匀加权即成立——此为比率失真之机制，非仅分母变大。
-- ─────────────────────────────────────────────────────────────────────
SELECT v_cnt                                                 AS v_cnt,                     -- 取列：该注单之版本数
       COUNT(*)                                              AS n_bet01,                   -- 计数：具此版本数之注单个数
       SUM(v_cnt)                                            AS n_rows_contributed         -- 汇总：此档共贡献之行数
FROM (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         COUNT(*)                                            AS v_cnt                      -- 计数：该注单之版本数
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
  GROUP BY bet01                                                                            -- 分组：按注单号
) t
GROUP BY v_cnt                                                                              -- 分组：按版本数分档
ORDER BY v_cnt;                                                                             -- 排序：版本数升序（稳定唯一序）


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-0b · 版本排序键之可用性（P0-B：不能只看到 rn=1 就判 PASS）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_00b_orderkey_health.csv」
-- ▸ 读法：三键为 §P11a／§B01／§R01 所锁之版本优先级
--         ORDER BY updatetime DESC, sync_time DESC, dt DESC。
--         若 updatetime 有 NULL 或同一 bet01 内三键全等（tie），
--         则 rn=1 所取之「首版」不唯一，去重结果将随执行计划漂移。
--         ⛔ 此情形下不得宣称「已去重」——须先定案 tie-break 规则。
-- ─────────────────────────────────────────────────────────────────────
SELECT COUNT(*)                                              AS n_multi_rows,              -- 计数：属多版本注单之行数
       SUM(CASE WHEN NULLIF(TRIM(updatetime), '') IS NULL
                THEN 1 ELSE 0 END)                           AS updatetime_null_n,         -- 汇总：updatetime 为空之行数
       SUM(CASE WHEN NULLIF(TRIM(sync_time), '') IS NULL
                THEN 1 ELSE 0 END)                           AS sync_time_null_n,          -- 汇总：sync_time 为空之行数
       COUNT(DISTINCT bet01)                                 AS n_multi_bet01,             -- 计数：多版本注单个数
       COUNT(DISTINCT CONCAT(bet01, '|', COALESCE(TRIM(updatetime), ''),
                             '|', COALESCE(TRIM(sync_time), ''),
                             '|', COALESCE(TRIM(dt), '')))   AS n_distinct_key,            -- 计数：四元键去重个数
       COUNT(*) - COUNT(DISTINCT CONCAT(bet01, '|', COALESCE(TRIM(updatetime), ''),
                             '|', COALESCE(TRIM(sync_time), ''),
                             '|', COALESCE(TRIM(dt), '')))   AS n_tie_rows                 -- 加减：并列行数；>0 即首版不唯一
FROM ods_mariadb_2b.ods_a168_bet02 b                                                        -- 取数来源：表一
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                          -- 过滤：主窗口
  AND b.bet02 = '101'                                                                       -- 过滤：百家乐
  AND b.bet01 IN (
        SELECT bet01                                                                        -- 取列：仅取多版本之注单号
        FROM ods_mariadb_2b.ods_a168_bet02                                                  -- 取数来源：表一
        WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                      -- 过滤：主窗口
          AND bet02 = '101'                                                                 -- 过滤：百家乐
        GROUP BY bet01                                                                      -- 分组：按注单号
        HAVING COUNT(*) > 1);                                                               -- 分组过滤：版本数逾一


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-1 · P01E 双臂读数（OLD 全版本 ／ NEW rn=1，同一会话同一快照）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_01_P01E_two_arms.csv」
-- ▸ 设计：两臂并置于单一查询，而非分两次跑——同快照可免「两次跑之间数据变动」
--         此一混淆源。run_def 为口径锁列，缺此列即无从分辨行属何臂。
-- ▸ 六项留存：n_rows／n_members／sum_bet16／sum_bet41／sum_validbet／identity_pass|fail
-- ▸ 双假设并列：H16（bet17 = bet14 - bet13 + bet16）与 H41（改用 bet41），
--         承 §P01E 之判读纪律——禁先写死其一。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号铸型；NULLIF/TRIM 前置，承 §P01E 写法
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额（原币）
         CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,4))      AS b14,                       -- 取值：派彩金额（原币）
         CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额（表一语义）
         CAST(NULLIF(TRIM(bet17), '') AS DECIMAL(20,4))      AS b17,                       -- 取值：净输赢（原币）
         CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,4))      AS b41,                       -- 取值：下注退水金额（表一语义，非表二之有效投注）
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注（表一列）
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序，三键承包内既锁之优先级
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
arms AS (
  SELECT 'OLD_全版本' AS run_def, 'H16' AS hypothesis, member_id, b16, b41, vb,             -- 取列：OLD 臂 × H16
         b17 - (b14 - b13 + b16)                             AS err                        -- 加减：H16 之残差
  FROM src                                                                                  -- 取数来源：中间结果集 src
  UNION ALL
  SELECT 'OLD_全版本', 'H41', member_id, b16, b41, vb,                                      -- 取列：OLD 臂 × H41
         b17 - (b14 - b13 + b41)                             AS err                        -- 加减：H41 之残差
  FROM src                                                                                  -- 取数来源：src
  UNION ALL
  SELECT 'NEW_rn1', 'H16', member_id, b16, b41, vb,                                         -- 取列：NEW 臂 × H16
         b17 - (b14 - b13 + b16)                             AS err                        -- 加减：H16 之残差
  FROM src WHERE rn = 1                                                                     -- 取数来源：src；过滤：仅取最新版本
  UNION ALL
  SELECT 'NEW_rn1', 'H41', member_id, b16, b41, vb,                                         -- 取列：NEW 臂 × H41
         b17 - (b14 - b13 + b41)                             AS err                        -- 加减：H41 之残差
  FROM src WHERE rn = 1                                                                     -- 取数来源：src；过滤：仅取最新版本
)
SELECT run_def                                               AS run_def,                   -- 取列：口径锁——OLD 全版本 / NEW rn=1
       hypothesis                                            AS hypothesis,                -- 取列：假设锁——H16 / H41
       COUNT(*)                                              AS n_rows,                    -- 计数：参与检验之行数
       COUNT(DISTINCT member_id)                             AS n_members,                 -- 计数：涉及之会员数（去重）
       ROUND(SUM(b16), 4)                                    AS sum_bet16,                 -- 汇总：bet16 合计（原币混计，仅供两臂比对）
       ROUND(SUM(b41), 4)                                    AS sum_bet41,                 -- 汇总：bet41 合计（同上）
       ROUND(SUM(vb), 4)                                     AS sum_validbet,              -- 汇总：validbet 合计（同上）
       SUM(CASE WHEN err = 0 THEN 1 ELSE 0 END)              AS identity_pass,             -- 汇总：残差为零之行数
       SUM(CASE WHEN err <> 0 THEN 1 ELSE 0 END)             AS identity_fail,             -- 汇总：残差非零之行数
       ROUND(SUM(CASE WHEN err = 0 THEN 1 ELSE 0 END) * 1.0
             / NULLIF(COUNT(*), 0), 8)                       AS exact_match_rate,          -- 除法：精确匹配率
       PERCENTILE_APPROX(ABS(err), 0.50)                     AS abs_err_p50,               -- 分位：残差绝对值中位
       PERCENTILE_APPROX(ABS(err), 0.95)                     AS abs_err_p95,               -- 分位：残差绝对值 P95
       PERCENTILE_APPROX(ABS(err), 0.99)                     AS abs_err_p99,               -- 分位：残差绝对值 P99
       MAX(ABS(err))                                         AS abs_err_max                -- 极值：残差绝对值最大
FROM arms                                                                                   -- 取数来源：中间结果集 arms
WHERE err IS NOT NULL                                                                       -- 过滤：残差可算者（承 §P01E 之 WHERE e IS NOT NULL）
GROUP BY run_def, hypothesis                                                                -- 分组：按臂 × 假设
ORDER BY hypothesis, run_def;                                                               -- 排序：稳定唯一序（两列即唯一）


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-2 · P01E Δ 对照（OLD 与 NEW 逐项作差；六项 + 匹配率）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_02_P01E_delta.csv」
-- ▸ 读法：delta_exact_match_rate > 0 即「去重后匹配率上升」，
--         = 0 为无变化，< 0 为下降。⛔ 三者皆为可能结果，不得预设。
--         若 §A-P0-0 之 n_extra_versions = 0，则本表全列 Δ 应恒为 0；
--         若不然，即为内部矛盾，须先查 §A-P0-0b 之 tie 与 NULL。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号铸型
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额
         CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,4))      AS b14,                       -- 取值：派彩金额
         CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额
         CAST(NULLIF(TRIM(bet17), '') AS DECIMAL(20,4))      AS b17,                       -- 取值：净输赢
         CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,4))      AS b41,                       -- 取值：下注退水金额
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
agg AS (
  SELECT 'H16' AS hypothesis,                                                               -- 取列：假设锁 H16
         COUNT(*)                                                                    AS n_old,          -- 计数：OLD 行数
         COUNT(DISTINCT member_id)                                                   AS m_old,          -- 计数：OLD 会员数
         SUM(b16)                                                                    AS s16_old,        -- 汇总：OLD bet16
         SUM(b41)                                                                    AS s41_old,        -- 汇总：OLD bet41
         SUM(vb)                                                                     AS svb_old,        -- 汇总：OLD validbet
         SUM(CASE WHEN b17 - (b14 - b13 + b16) = 0 THEN 1 ELSE 0 END)                AS p_old,          -- 汇总：OLD 通过数
         SUM(CASE WHEN rn = 1 THEN 1 ELSE 0 END)                                     AS n_new,          -- 汇总：NEW 行数
         COUNT(DISTINCT CASE WHEN rn = 1 THEN member_id END)                         AS m_new,          -- 计数：NEW 会员数
         SUM(CASE WHEN rn = 1 THEN b16 ELSE 0 END)                                   AS s16_new,        -- 汇总：NEW bet16
         SUM(CASE WHEN rn = 1 THEN b41 ELSE 0 END)                                   AS s41_new,        -- 汇总：NEW bet41
         SUM(CASE WHEN rn = 1 THEN vb ELSE 0 END)                                    AS svb_new,        -- 汇总：NEW validbet
         SUM(CASE WHEN rn = 1 AND b17 - (b14 - b13 + b16) = 0 THEN 1 ELSE 0 END)     AS p_new           -- 汇总：NEW 通过数
  FROM src                                                                                  -- 取数来源：src
  WHERE b17 - (b14 - b13 + b16) IS NOT NULL                                                 -- 过滤：H16 残差可算者
  UNION ALL
  SELECT 'H41' AS hypothesis,                                                               -- 取列：假设锁 H41
         COUNT(*), COUNT(DISTINCT member_id), SUM(b16), SUM(b41), SUM(vb),                  -- 汇总：OLD 五项
         SUM(CASE WHEN b17 - (b14 - b13 + b41) = 0 THEN 1 ELSE 0 END),                      -- 汇总：OLD 通过数
         SUM(CASE WHEN rn = 1 THEN 1 ELSE 0 END),                                           -- 汇总：NEW 行数
         COUNT(DISTINCT CASE WHEN rn = 1 THEN member_id END),                               -- 计数：NEW 会员数
         SUM(CASE WHEN rn = 1 THEN b16 ELSE 0 END),                                         -- 汇总：NEW bet16
         SUM(CASE WHEN rn = 1 THEN b41 ELSE 0 END),                                         -- 汇总：NEW bet41
         SUM(CASE WHEN rn = 1 THEN vb ELSE 0 END),                                          -- 汇总：NEW validbet
         SUM(CASE WHEN rn = 1 AND b17 - (b14 - b13 + b41) = 0 THEN 1 ELSE 0 END)            -- 汇总：NEW 通过数
  FROM src                                                                                  -- 取数来源：src
  WHERE b17 - (b14 - b13 + b41) IS NOT NULL                                                 -- 过滤：H41 残差可算者
)
SELECT hypothesis                                            AS hypothesis,                -- 取列：假设锁
       n_old, n_new, n_new - n_old                           AS delta_n_rows,              -- 加减：行数之 Δ
       m_old, m_new, m_new - m_old                           AS delta_n_members,           -- 加减：会员数之 Δ
       ROUND(s16_old, 4) AS sum_bet16_old, ROUND(s16_new, 4) AS sum_bet16_new,             -- 取列：bet16 两臂
       ROUND(s16_new - s16_old, 4)                           AS delta_sum_bet16,           -- 加减：bet16 之 Δ
       ROUND(s41_old, 4) AS sum_bet41_old, ROUND(s41_new, 4) AS sum_bet41_new,             -- 取列：bet41 两臂
       ROUND(s41_new - s41_old, 4)                           AS delta_sum_bet41,           -- 加减：bet41 之 Δ
       ROUND(svb_old, 4) AS sum_validbet_old, ROUND(svb_new, 4) AS sum_validbet_new,       -- 取列：validbet 两臂
       ROUND(svb_new - svb_old, 4)                           AS delta_sum_validbet,        -- 加减：validbet 之 Δ
       p_old AS identity_pass_old, n_old - p_old             AS identity_fail_old,         -- 取列/加减：OLD 通过与不通过
       p_new AS identity_pass_new, n_new - p_new             AS identity_fail_new,         -- 取列/加减：NEW 通过与不通过
       ROUND(p_old * 1.0 / NULLIF(n_old, 0), 8)              AS rate_old,                  -- 除法：OLD 匹配率
       ROUND(p_new * 1.0 / NULLIF(n_new, 0), 8)              AS rate_new,                  -- 除法：NEW 匹配率
       ROUND(p_new * 1.0 / NULLIF(n_new, 0)
           - p_old * 1.0 / NULLIF(n_old, 0), 8)              AS delta_exact_match_rate     -- 加减：匹配率之 Δ（正负零皆可能）
FROM agg                                                                                    -- 取数来源：中间结果集 agg
ORDER BY hypothesis;                                                                        -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-3 · P01C 双轨（轨 A 原始版本全体 ／ 轨 B rn=1）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_03_P01C_two_tracks.csv」
-- ▸ 何以双轨而非补闸：§P01C 之研究对象即【版本切换所造成之语义差异】。
--   径补 rn=1 将把被检现象一并删去——修复动作摧毁被检对象，是最不可犯之错。
-- ▸ 读法（判决树）：
--     轨 A 与轨 B 之 equal_n／avg_diff 逐月逐维一致 → 版本【不】改变语义 → 可议统一口径；
--     两轨相异                                     → 版本【确】改变语义 → 双轨模型须永久保留。
--   ⚠ 「相异」须按维分辨：若仅个别月份／玩法相异，即为语义切换之时点线索，
--     价值高于全局一致，切勿以「大体一致」一语带过。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT dt                                                  AS dt,                        -- 取列：营业日（分区列，与 bet07 实测一致）
         bet09                                               AS bet09,                     -- 取列：玩法
         commission                                          AS commission,                -- 取列：佣金模式标记
         bet10                                               AS bet10,                     -- 取列：币别
         CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额
         CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,4))      AS b41,                       -- 取值：下注退水金额
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
tracks AS (
  SELECT 'A_原始版本全体' AS track_def, dt, bet09, commission, bet10, b16, b41              -- 取列：轨 A（不去重）
  FROM src                                                                                  -- 取数来源：src
  UNION ALL
  SELECT 'B_rn1', dt, bet09, commission, bet10, b16, b41                                    -- 取列：轨 B（去重）
  FROM src WHERE rn = 1                                                                     -- 取数来源：src；过滤：仅最新版本
)
SELECT track_def                                             AS track_def,                 -- 取列：轨道锁——缺此列即无从分辨行属何轨
       DATE_TRUNC('month', dt)                               AS ym,                        -- 取值：月份（语义切换之时点轴，必留）
       TRIM(bet09)                                           AS bet09,                     -- 取值：玩法（去空白）
       TRIM(commission)                                      AS commission,                -- 取值：佣金模式
       TRIM(bet10)                                           AS bet10,                     -- 取值：币别
       COUNT(*)                                              AS n,                         -- 计数：本格行数
       SUM(CASE WHEN b16 =  b41 THEN 1 ELSE 0 END)           AS equal_n,                   -- 汇总：两值相等之行数
       SUM(CASE WHEN b16 <> b41 THEN 1 ELSE 0 END)           AS unequal_n,                 -- 汇总：两值相异之行数
       SUM(CASE WHEN b16 <> 0 THEN 1 ELSE 0 END)             AS b16_nonzero_n,             -- 汇总：bet16 非零行数
       SUM(CASE WHEN b41 <> 0 THEN 1 ELSE 0 END)             AS b41_nonzero_n,             -- 汇总：bet41 非零行数
       AVG(b16)                                              AS avg_b16,                   -- 均值：bet16
       AVG(b41)                                              AS avg_b41,                   -- 均值：bet41
       AVG(b16 - b41)                                        AS avg_diff,                  -- 均值：两值之差
       PERCENTILE_APPROX(b16, 0.50)                          AS p50_b16,                   -- 分位：bet16 中位
       PERCENTILE_APPROX(b41, 0.50)                          AS p50_b41                    -- 分位：bet41 中位
FROM tracks                                                                                 -- 取数来源：中间结果集 tracks
WHERE b16 IS NOT NULL AND b41 IS NOT NULL                                                   -- 过滤：两值皆可算者（承 §P01C）
GROUP BY track_def, DATE_TRUNC('month', dt), TRIM(bet09), TRIM(commission), TRIM(bet10)      -- 分组：轨 × 月 × 玩法 × 佣金 × 币别
ORDER BY track_def, ym, bet09, commission, bet10;                                           -- 排序：稳定唯一序（五列即唯一）


-- =====================================================================
-- 【跑毕之后 · 判决树】
--   §A-P0-2 之 Δ：
--     Δ ≈ 0（各项皆零）        → 该问题【低影响】；P01 之统计读数未受版本污染，
--                                「补 rn=1」属形式修正，不入 v12-Q 必修集。
--     Δ ≠ 0                    → 统计读数确受污染；纳入 v12-Q 候选，
--                                且原 §P01E 之比率读数一律降为 SUPERSEDED。
--   §A-P0-3 之双轨：
--     两轨一致                  → 版本不改变语义；可议统一口径。
--     两轨相异                  → 版本改变语义；双轨模型永久保留，禁补 rn=1。
--
--   ⛔ 无论结果如何，本稿不得回写 v10；一切修正另起 v12-Q。
--   ⛔ 结论落档时须带证据等级；「跑过了」不等于 OBSERVED，
--      须同时留存查询原文、六元组、执行时点与行数，方成审计证据。
--
-- 【尚未涵盖 · 待续之三件】
--   P01D（与 validbet 之关系）、P02C（键检验）、K01b_goldip（金标准 IP 种子）
--   —— 按同一原则逐件复核；其中 K01b_goldip 另有既有实测：查询返回零行，
--      故其 rn 缺口之影响或为空集，须先复验零行是否仍成立，再议补闸。
-- =====================================================================
