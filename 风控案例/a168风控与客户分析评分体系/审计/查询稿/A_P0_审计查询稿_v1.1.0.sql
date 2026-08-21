-- =====================================================================
-- a168 · P0 审计查询稿 v1.1.0
-- 身份 : 审计临时复核语句 ★ 非总包条目、非交付件
-- 日期 : 2026-08-22
-- 对应基线 : v10-REDTEAM 审计基线 v1.0.2
-- 受审本体 : a168_取数与核验_SQL总包_v10.sql
--            9,475 行 | 1,195,130 字节 | CRLF | MD5(file) 62985e9b2932bd7ab70fba7ee9c01cb8
-- 版本沿革 : v1.0.0（§A-P0-0/0a/0b/1/2/3，已跑毕）→ v1.1.0（并入 §A-P0-4／§A-P0-5）
--            v1.0.0 依版本纪律移除；其五条已跑毕之查询原文存于本稿附录（未改一字）。
-- =====================================================================
-- 【边界声明 · 三条，最要紧】
--   ① 本稿不修改 v10 一字。v10 永不斧正；本稿只产证据。
--   ② 所有输出存入「审计/证据/」，⛔ 严禁存入「数据库/」——
--      后者为交付契约命名空间，混入即令集合身份 v10-93（6c14ab6f69a8）失真。
--   ③ 本稿不占在册序号。§75／§76 系总包新条之预留，审计稿另用 §A-P0-x 编号。
-- ---------------------------------------------------------------------
-- 【本轮所承之 P0 既有读数（OBSERVED，2026-08-22 已跑毕）】
--   n_rows 125,654,711 ｜ n_bet01 124,731,833 ｜ n_extra_versions 922,878（0.734456%）
--   版本直方图：v_cnt=1 → 123,808,955 单 ； v_cnt=2 → 922,878 单 ； 无 3 版以上
--   排序键健康：updatetime_null 0 ｜ sync_time_null 0 ｜ n_tie_rows 0 → 首版唯一确定
--   H16 两臂皆 100%、残差恒零、Δ=0 ； H41 匹配率 +0.00002260（相对 +0.0297%）
--   n_members 两臂皆 723,557，Δ=0
--   922,878 行重复 **100% 集中于 2026-05**（该月去重率 3.2352%，余五月皆 0）
--   sum_bet41 / sum_bet16 = 33,630.6 倍 ； sum_bet41 / sum_validbet = 0.999996287
-- ---------------------------------------------------------------------
-- 【本轮两条主线】
--   §A-P0-4 · 五月事件定性 —— 922,878 个第二版本究竟是「重传」抑或「业务版本」
--   §A-P0-5 · bet41 语义定性（原 §P01D 提前）—— 表一 bet41 究竟近 validbet 抑或近 bet16
--   ⛔ 二者未定性之前，不得裁定「哪些 SQL 必须补 rn=1」，亦不得开 v12-Q。
-- ---------------------------------------------------------------------
-- 【口径纪律】
--   沿用 DECIMAL(20,4) 与 CAST(NULLIF(TRIM(x),'')) 写法，与 §P01x 逐字可比。
--   ⚠ 不得顺手升 DECIMAL(20,8)——一改即引入第二变因，Δ 无从归因。归化属 v12-Q。
--   窗口一律 dt >= '2026-03-21' AND dt < '2026-08-07'。
--   金额为原币混计（未经 bet11 换汇）：仅供臂间比较，⛔ 不得作业务解读。
-- =====================================================================


-- ═════════════════════════════════════════════════════════════════════
-- 主线一 · §A-P0-4 · 2026-05 版本事件定性
-- ═════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-4a · 逐日版本重复分布（全窗 139 日，非仅五月）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_04a_daily_dup.csv」
-- ▸ 何以全窗而非仅五月：须证「其余五月确为零」，而非「未查」。
--   零值本身是证据——它把「常态改单」这一解释直接排除。
-- ▸ 读法：extra_rate 若在五月内亦呈单日阶跃（某数日极高、余日为零），
--   则指向一次性作业（re-sync／补传）；若五月全月均匀抬升，则指向该月
--   之系统性行为变更。两者含义迥异，不可混谈。
-- ─────────────────────────────────────────────────────────────────────
SELECT dt                                                    AS dt,                        -- 取列：营业日（分区列，与 bet07 实测一致）
       COUNT(*)                                              AS n_rows,                    -- 计数：当日注单行数（含各版本）
       COUNT(DISTINCT bet01)                                 AS n_bet01,                   -- 计数：当日去重注单号
       COUNT(*) - COUNT(DISTINCT bet01)                      AS n_extra_versions,          -- 加减：当日多余版本行数
       ROUND((COUNT(*) - COUNT(DISTINCT bet01)) * 100.0
             / NULLIF(COUNT(*), 0), 6)                       AS extra_rate_pct             -- 除法：当日重复占比（百分点）
FROM ods_mariadb_2b.ods_a168_bet02                                                          -- 取数来源：注单明细主表（表一）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                              -- 过滤：主窗口
  AND bet02 = '101'                                                                         -- 过滤：百家乐产品闸
GROUP BY dt                                                                                 -- 分组：按营业日
ORDER BY dt;                                                                                -- 排序：日期升序（稳定唯一序）


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-4b · 首版 vs 次版 之字段差异分类（★ 本主线之决胜条）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_04b_dup_taxonomy.csv」
-- ▸ 分类优先级（自严至宽，先匹配者胜；不得改序）：
--     DUP_KEY_CHANGE     身份键异（bet05 会员／bet03 靴／bet04 局／bet39 桌／eid 荷官／bet10 币）
--                        —— 最凶：同一 bet01 指向不同实体，即注单号不唯一，
--                           此时 rn=1 之「去重」实为「丢弃另一笔业务」，绝不可为
--     DUP_AMOUNT_CHANGE  金额异（bet13/14/16/17/41/validbet 任一）→ 真实业务版本
--     DUP_STATUS_CHANGE  状态异（bet38 重對／category 一般或小费）→ 真实业务版本
--     DUP_TIME_ONLY      业务字段全同，仅 updatetime/sync_time/dt 异 → 重传之特征
--     DUP_EXACT          连时间键亦全同 → 纯粹重复行（既测 n_tie_rows=0，预期为 0）
-- ▸ 判决：DUP_TIME_ONLY ＋ DUP_EXACT 占绝对多数 → 重传／re-sync → 去重合法；
--         DUP_AMOUNT_CHANGE ／ DUP_STATUS_CHANGE 占多数 → 真实业务版本 → 去重是取最新，非删重复；
--         DUP_KEY_CHANGE 只要 > 0 → ⛔ 立即停，rn=1 之整套前提须重议。
-- ─────────────────────────────────────────────────────────────────────
WITH ranked AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         dt                                                  AS dt,                        -- 取列：营业日
         TRIM(COALESCE(updatetime, ''))                      AS updatetime,                -- 取值：更新时间（去空白）
         TRIM(COALESCE(sync_time, ''))                       AS sync_time,                 -- 取值：同步时间（去空白）
         TRIM(COALESCE(bet05, ''))                           AS bet05,                     -- 取值：会员号
         TRIM(COALESCE(bet03, ''))                           AS bet03,                     -- 取值：靴号
         TRIM(COALESCE(bet04, ''))                           AS bet04,                     -- 取值：局内第几把
         TRIM(COALESCE(bet39, ''))                           AS bet39,                     -- 取值：桌号
         TRIM(COALESCE(eid, ''))                             AS eid,                       -- 取值：荷官工号
         TRIM(COALESCE(bet10, ''))                           AS bet10,                     -- 取值：币别
         TRIM(COALESCE(bet08, ''))                           AS bet08,                     -- 取值：下注时间
         TRIM(COALESCE(bet09, ''))                           AS bet09,                     -- 取值：玩法
         TRIM(COALESCE(bet13, ''))                           AS bet13,                     -- 取值：下注金额（字符串比对，免转型误差）
         TRIM(COALESCE(bet14, ''))                           AS bet14,                     -- 取值：派彩金额
         TRIM(COALESCE(bet16, ''))                           AS bet16,                     -- 取值：退水金额
         TRIM(COALESCE(bet17, ''))                           AS bet17,                     -- 取值：净输赢
         TRIM(COALESCE(bet41, ''))                           AS bet41,                     -- 取值：表一 bet41（语义待 §A-P0-5 定性）
         TRIM(COALESCE(validbet, ''))                        AS validbet,                  -- 取值：有效投注
         TRIM(COALESCE(bet38, ''))                           AS bet38,                     -- 取值：重對标识
         TRIM(COALESCE(category, ''))                        AS category,                  -- 取值：一般或小费
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序，三键承包内既锁之优先级
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
v1 AS (SELECT * FROM ranked WHERE rn = 1),                                                  -- 取数来源：ranked；过滤：首版
v2 AS (SELECT * FROM ranked WHERE rn = 2),                                                  -- 取数来源：ranked；过滤：次版（既测无 3 版以上）
pair AS (
  SELECT a.dt                                                AS dt_v1,                     -- 取列：首版营业日
         b.dt                                                AS dt_v2,                     -- 取列：次版营业日
         CASE
           WHEN a.bet05 <> b.bet05 OR a.bet03 <> b.bet03 OR a.bet04 <> b.bet04
             OR a.bet39 <> b.bet39 OR a.eid   <> b.eid   OR a.bet10 <> b.bet10
             OR a.bet08 <> b.bet08 OR a.bet09 <> b.bet09
             THEN 'DUP_KEY_CHANGE'                                                          -- 分支：身份键异——最凶
           WHEN a.bet13 <> b.bet13 OR a.bet14 <> b.bet14 OR a.bet16 <> b.bet16
             OR a.bet17 <> b.bet17 OR a.bet41 <> b.bet41 OR a.validbet <> b.validbet
             THEN 'DUP_AMOUNT_CHANGE'                                                       -- 分支：金额异——真实业务版本
           WHEN a.bet38 <> b.bet38 OR a.category <> b.category
             THEN 'DUP_STATUS_CHANGE'                                                       -- 分支：状态异——真实业务版本
           WHEN a.updatetime <> b.updatetime OR a.sync_time <> b.sync_time OR a.dt <> b.dt
             THEN 'DUP_TIME_ONLY'                                                           -- 分支：仅时间异——重传之特征
           ELSE 'DUP_EXACT'                                                                 -- 分支：全同——纯粹重复行
         END                                                 AS dup_class,                 -- 取值：重复分类（优先级自严至宽）
         CASE WHEN a.dt = b.dt THEN 'SAME_DT' ELSE 'CROSS_DT' END AS dt_relation,           -- 取值：两版是否同一营业日
         a.bet13 <> b.bet13                                  AS chg_bet13,                 -- 布尔：下注金额是否变
         a.bet14 <> b.bet14                                  AS chg_bet14,                 -- 布尔：派彩是否变
         a.bet16 <> b.bet16                                  AS chg_bet16,                 -- 布尔：退水是否变
         a.bet17 <> b.bet17                                  AS chg_bet17,                 -- 布尔：净输赢是否变
         a.bet41 <> b.bet41                                  AS chg_bet41,                 -- 布尔：bet41 是否变
         a.validbet <> b.validbet                            AS chg_validbet               -- 布尔：validbet 是否变
  FROM v1 a                                                                                 -- 取数来源：首版集合
  JOIN v2 b ON b.bet01 = a.bet01                                                            -- 内联结：按注单号配对次版
)
SELECT dup_class                                             AS dup_class,                 -- 取列：重复分类
       dt_relation                                           AS dt_relation,               -- 取列：跨日与否
       COUNT(*)                                              AS n_pairs,                   -- 计数：配对数（＝多余版本数）
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 6)    AS pct_of_all_dup,            -- 开窗除法：占全部重复之比
       SUM(CASE WHEN chg_bet13    THEN 1 ELSE 0 END)         AS chg_bet13_n,               -- 汇总：下注金额变动数
       SUM(CASE WHEN chg_bet14    THEN 1 ELSE 0 END)         AS chg_bet14_n,               -- 汇总：派彩变动数
       SUM(CASE WHEN chg_bet16    THEN 1 ELSE 0 END)         AS chg_bet16_n,               -- 汇总：退水变动数
       SUM(CASE WHEN chg_bet17    THEN 1 ELSE 0 END)         AS chg_bet17_n,               -- 汇总：净输赢变动数
       SUM(CASE WHEN chg_bet41    THEN 1 ELSE 0 END)         AS chg_bet41_n,               -- 汇总：bet41 变动数
       SUM(CASE WHEN chg_validbet THEN 1 ELSE 0 END)         AS chg_validbet_n             -- 汇总：validbet 变动数
FROM pair                                                                                   -- 取数来源：中间结果集 pair
GROUP BY dup_class, dt_relation                                                             -- 分组：分类 × 跨日与否
ORDER BY dup_class, dt_relation;                                                            -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-4c · 两版之时滞与落库时点分布
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_04c_dup_latency.csv」
-- ▸ 读法：lag_sec 若高度集中于某一窄区间（如皆数百秒内），指向单次批量作业；
--   若散布甚广（数小时至数日），则指向陆续发生之业务改单。
--   updatetime 之小时分布若集中于凌晨维护窗，亦为 re-sync 之旁证。
--   ⚠ 旁证不等于定性——须与 §A-P0-4b 之分类合看，单独不足以定案。
-- ─────────────────────────────────────────────────────────────────────
WITH ranked AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         CAST(NULLIF(TRIM(updatetime), '') AS DATETIME)      AS ut,                        -- 取值：更新时间转型
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
lag AS (
  SELECT a.ut                                                AS ut_v1,                     -- 取列：首版更新时间
         b.ut                                                AS ut_v2,                     -- 取列：次版更新时间
         TIMESTAMPDIFF(SECOND, b.ut, a.ut)                   AS lag_sec                    -- 时差：首版减次版之秒数
  FROM (SELECT bet01, ut FROM ranked WHERE rn = 1) a                                        -- 取数来源：首版
  JOIN (SELECT bet01, ut FROM ranked WHERE rn = 2) b ON b.bet01 = a.bet01                   -- 内联结：配对次版
)
SELECT DATE(ut_v1)                                           AS d_v1,                      -- 取值：首版日期
       HOUR(ut_v1)                                           AS h_v1,                      -- 取值：首版小时
       COUNT(*)                                              AS n_pairs,                   -- 计数：本格配对数
       MIN(lag_sec)                                          AS lag_min,                   -- 极值：时滞最小
       PERCENTILE_APPROX(lag_sec, 0.50)                      AS lag_p50,                   -- 分位：时滞中位
       PERCENTILE_APPROX(lag_sec, 0.95)                      AS lag_p95,                   -- 分位：时滞 P95
       MAX(lag_sec)                                          AS lag_max,                   -- 极值：时滞最大
       SUM(CASE WHEN lag_sec <= 60    THEN 1 ELSE 0 END)     AS le_60s_n,                  -- 汇总：一分钟内
       SUM(CASE WHEN lag_sec <= 3600  THEN 1 ELSE 0 END)     AS le_1h_n,                   -- 汇总：一小时内
       SUM(CASE WHEN lag_sec >  86400 THEN 1 ELSE 0 END)     AS gt_1d_n                    -- 汇总：逾一日
FROM lag                                                                                    -- 取数来源：中间结果集 lag
WHERE ut_v1 IS NOT NULL AND ut_v2 IS NOT NULL                                               -- 过滤：两版时间皆可转型者
GROUP BY DATE(ut_v1), HOUR(ut_v1)                                                           -- 分组：日 × 小时
ORDER BY d_v1, h_v1;                                                                        -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-4d · 重复之实体集中度（荷官 × 桌台 × 玩法 × 币别）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_04d_dup_entity.csv」
-- ▸ 读法：dup_rate 若在各实体间大致均等，指向全库层面之作业（重传）；
--   若集中于少数桌台或荷官，则指向局部业务事件，须另行追查。
-- ▸ ⚠ 本条以荷官/桌台/玩法/币别为轴而不含会员——会员逾七十万，
--   逐会员输出体量过巨；会员维之集中度另由 §A-P0-4e 之直方图给出。
-- ─────────────────────────────────────────────────────────────────────
WITH ranked AS (
  SELECT bet01                                               AS bet01,                     -- 取列：注单号
         TRIM(COALESCE(eid, ''))                             AS eid,                       -- 取值：荷官工号
         TRIM(COALESCE(bet39, ''))                           AS bet39,                     -- 取值：桌号
         TRIM(COALESCE(bet09, ''))                           AS bet09,                     -- 取值：玩法
         TRIM(COALESCE(bet10, ''))                           AS bet10,                     -- 取值：币别
         COUNT(*) OVER (PARTITION BY bet01)                  AS v_cnt                      -- 开窗：该注单之版本数
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
)
SELECT eid                                                   AS eid,                       -- 取列：荷官工号
       bet39                                                 AS bet39,                     -- 取列：桌号
       bet09                                                 AS bet09,                     -- 取列：玩法
       bet10                                                 AS bet10,                     -- 取列：币别
       COUNT(*)                                              AS n_rows,                    -- 计数：本格行数
       COUNT(DISTINCT bet01)                                 AS n_bet01,                   -- 计数：本格去重注单数
       COUNT(*) - COUNT(DISTINCT bet01)                      AS n_extra,                   -- 加减：本格多余版本数
       ROUND((COUNT(*) - COUNT(DISTINCT bet01)) * 100.0
             / NULLIF(COUNT(*), 0), 6)                       AS dup_rate_pct               -- 除法：本格重复率
FROM ranked                                                                                 -- 取数来源：中间结果集 ranked
GROUP BY eid, bet39, bet09, bet10                                                           -- 分组：荷官 × 桌 × 玩法 × 币别
ORDER BY eid, bet39, bet09, bet10;                                                          -- 排序：稳定唯一序（四列即唯一）


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-4e · 会员维之重复集中度直方图
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_04e_dup_member_hist.csv」
-- ▸ 读法：若重复散布于数十万会员且每人仅一两笔，则与个别会员行为无涉；
--   若集中于少数会员，则须并入风控视角另行追查（此时非纯数据质量问题）。
-- ─────────────────────────────────────────────────────────────────────
SELECT dup_per_member                                        AS dup_per_member,            -- 取列：该会员之重复笔数
       COUNT(*)                                              AS n_members,                 -- 计数：具此重复笔数之会员数
       SUM(dup_per_member)                                   AS n_dup_contributed          -- 汇总：此档共贡献之重复笔数
FROM (
  SELECT CAST(NULLIF(TRIM(bet05), '') AS BIGINT)             AS member_id,                 -- 取值：会员号铸型
         COUNT(*) - COUNT(DISTINCT bet01)                    AS dup_per_member             -- 加减：该会员之多余版本数
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
  GROUP BY CAST(NULLIF(TRIM(bet05), '') AS BIGINT)                                          -- 分组：按会员
) t
WHERE dup_per_member > 0                                                                    -- 过滤：只看有重复者
GROUP BY dup_per_member                                                                     -- 分组：按重复笔数分档
ORDER BY dup_per_member;                                                                    -- 排序：稳定唯一序


-- ═════════════════════════════════════════════════════════════════════
-- 主线二 · §A-P0-5 · 表一 bet41 语义定性（原 §P01D，提前）
-- ═════════════════════════════════════════════════════════════════════
-- 【何以提前】v10 行 210 载「表一 bet41 下注退水金额」，
--   而实测 sum_bet41 / sum_bet16 = 33,630.6 倍、sum_bet41 / sum_validbet = 0.999996287。
--   量级与登记不符，行 210 已降 CONDITIONAL。此条定其语义。
-- 【判读纪律】⛔ 不预设 bet41 = validbet，亦不预设 bet41 = validbet × 退水率。
--   三假设并列，由分布裁定；且 R≈1 与 D=0 须分开看——
--   R≈1 只说「比值近一」，D=0 才说「逐行恒等」。前者可由大数掩盖后者之不成立。
-- 【血统隔离】表一 bet41 与表二 bet41 之关系不由本条裁定；
--   本条只测表一之内部关系。跨表比对另需接线键，属待续。
-- ─────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-5a · bet41 vs validbet vs bet16 之总貌（双臂并置）
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_05a_bet41_overview.csv」
-- ▸ 双臂之由：既知重复集中五月，须验语义结论不因去重而变。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额
         CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,4))      AS b41,                       -- 取值：表一 bet41
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,4))      AS b13,                       -- 取值：下注金额（第三参照）
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
),
arms AS (
  SELECT 'OLD_全版本' AS run_def, b16, b41, vb, b13 FROM src                                -- 取列：OLD 臂
  UNION ALL
  SELECT 'NEW_rn1',    b16, b41, vb, b13 FROM src WHERE rn = 1                              -- 取列：NEW 臂
)
SELECT run_def                                               AS run_def,                   -- 取列：口径锁
       COUNT(*)                                              AS n_rows,                    -- 计数：行数
       SUM(CASE WHEN b41 IS NOT NULL AND vb IS NOT NULL
                THEN 1 ELSE 0 END)                           AS comparable_n,              -- 汇总：两值皆可比之行数
       SUM(CASE WHEN b41 = vb  THEN 1 ELSE 0 END)            AS d_eq_zero_n,               -- 汇总：D=0（逐行恒等）之行数
       SUM(CASE WHEN b41 > vb  THEN 1 ELSE 0 END)            AS d_gt_zero_n,               -- 汇总：D>0 之行数
       SUM(CASE WHEN b41 < vb  THEN 1 ELSE 0 END)            AS d_lt_zero_n,               -- 汇总：D<0 之行数
       SUM(CASE WHEN vb <> 0 AND ABS(b41 / vb - 1) < 0.000001
                THEN 1 ELSE 0 END)                           AS r_near_one_n,              -- 汇总：R≈1 之行数（容差百万分之一）
       SUM(CASE WHEN b41 = b16 THEN 1 ELSE 0 END)            AS b41_eq_b16_n,              -- 汇总：bet41 = bet16 之行数（对照假设）
       SUM(CASE WHEN b41 = b13 THEN 1 ELSE 0 END)            AS b41_eq_b13_n,              -- 汇总：bet41 = bet13 之行数（对照假设）
       ROUND(SUM(b41), 4)                                    AS sum_b41,                   -- 汇总：bet41 合计
       ROUND(SUM(vb), 4)                                     AS sum_vb,                    -- 汇总：validbet 合计
       ROUND(SUM(b16), 4)                                    AS sum_b16,                   -- 汇总：bet16 合计
       ROUND(SUM(b13), 4)                                    AS sum_b13,                   -- 汇总：bet13 合计
       PERCENTILE_APPROX(b41 - vb, 0.01)                     AS d_p01,                     -- 分位：D 之 P01
       PERCENTILE_APPROX(b41 - vb, 0.50)                     AS d_p50,                     -- 分位：D 之中位
       PERCENTILE_APPROX(b41 - vb, 0.99)                     AS d_p99,                     -- 分位：D 之 P99
       MAX(ABS(b41 - vb))                                    AS d_abs_max,                 -- 极值：D 绝对值最大
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.01)          AS r_p01,                     -- 分位：R 之 P01
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.05)          AS r_p05,                     -- 分位：R 之 P05
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.25)          AS r_p25,                     -- 分位：R 之 P25
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.50)          AS r_p50,                     -- 分位：R 之中位
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.75)          AS r_p75,                     -- 分位：R 之 P75
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.95)          AS r_p95,                     -- 分位：R 之 P95
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.99)          AS r_p99,                     -- 分位：R 之 P99
       PERCENTILE_APPROX(b16 / NULLIF(vb, 0), 0.50)          AS r16_p50                    -- 分位：bet16/validbet 中位（退水率之量级参照）
FROM arms                                                                                   -- 取数来源：中间结果集 arms
GROUP BY run_def                                                                            -- 分组：按臂
ORDER BY run_def;                                                                           -- 排序：稳定唯一序


-- ─────────────────────────────────────────────────────────────────────
-- §A-P0-5b · bet41 与 validbet 之差 D 按 月 × 玩法 × 免佣 × 币别
-- ▸ 导出：需要 —— 存为「审计/证据/A_P0_05b_bet41_by_dim.csv」
-- ▸ 口径：仅取 rn=1（承 §A-P0-3 已证「版本不改变语义」；若 §A-P0-4b 推翻之，本条须重跑双臂）
-- ▸ 读法：若 D=0 之占比在各月各维皆近 100%，则表一 bet41 即 validbet 之副本，
--   行 210 之登记须斧正；若某维系统性偏离，则二者为不同量，登记或另有他解。
-- ─────────────────────────────────────────────────────────────────────
WITH src AS (
  SELECT dt                                                  AS dt,                        -- 取列：营业日
         TRIM(bet09)                                         AS bet09,                     -- 取值：玩法
         TRIM(commission)                                    AS commission,                -- 取值：佣金模式
         TRIM(bet10)                                         AS bet10,                     -- 取值：币别
         CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,4))      AS b16,                       -- 取值：退水金额
         CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,4))      AS b41,                       -- 取值：表一 bet41
         CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,4))   AS vb,                        -- 取值：有效投注
         ROW_NUMBER() OVER (
           PARTITION BY bet01
           ORDER BY updatetime DESC, sync_time DESC, dt DESC) AS rn                        -- 开窗：版本序
  FROM ods_mariadb_2b.ods_a168_bet02                                                        -- 取数来源：表一
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                            -- 过滤：主窗口
    AND bet02 = '101'                                                                       -- 过滤：百家乐
)
SELECT DATE_TRUNC('month', dt)                               AS ym,                        -- 取值：月份（语义切换之时点轴）
       bet09                                                 AS bet09,                     -- 取列：玩法
       commission                                            AS commission,                -- 取列：佣金模式
       bet10                                                 AS bet10,                     -- 取列：币别
       COUNT(*)                                              AS n,                         -- 计数：本格行数
       SUM(CASE WHEN b41 = vb THEN 1 ELSE 0 END)             AS d_eq_zero_n,               -- 汇总：D=0 行数
       ROUND(SUM(CASE WHEN b41 = vb THEN 1 ELSE 0 END) * 100.0
             / NULLIF(COUNT(*), 0), 6)                       AS d_eq_zero_pct,             -- 除法：D=0 占比
       SUM(CASE WHEN b41 <> vb THEN 1 ELSE 0 END)            AS d_ne_zero_n,               -- 汇总：D≠0 行数
       AVG(b41 - vb)                                         AS avg_d,                     -- 均值：D
       MAX(ABS(b41 - vb))                                    AS max_abs_d,                 -- 极值：D 绝对值最大
       AVG(b41)                                              AS avg_b41,                   -- 均值：bet41
       AVG(vb)                                               AS avg_vb,                    -- 均值：validbet
       AVG(b16)                                              AS avg_b16,                   -- 均值：bet16
       PERCENTILE_APPROX(b16 / NULLIF(vb, 0), 0.50)          AS rebate_rate_p50            -- 分位：退水率中位（bet16 ÷ validbet）
FROM src                                                                                    -- 取数来源：中间结果集 src
WHERE rn = 1                                                                                -- 过滤：仅最新版本
  AND b41 IS NOT NULL AND vb IS NOT NULL                                                    -- 过滤：两值皆可算者
GROUP BY DATE_TRUNC('month', dt), bet09, commission, bet10                                  -- 分组：月 × 玩法 × 佣金 × 币别
ORDER BY ym, bet09, commission, bet10;                                                      -- 排序：稳定唯一序（四列即唯一）


-- =====================================================================
-- 【跑毕之后 · 判决树】
--
--   §A-P0-4b 之 dup_class：
--     DUP_KEY_CHANGE > 0                → ⛔ 立即停。同一 bet01 指向不同实体，
--                                          注单号不唯一，rn=1 之整套前提须重议。
--     TIME_ONLY + EXACT 占绝对多数       → 重传／re-sync → 五月 3.2352% 属数据质量污染 →
--                                          时序类交付件应去重；rn=1 归 Data Quality Gate。
--     AMOUNT/STATUS_CHANGE 占多数        → 真实业务版本 → 去重之义为「取最新」而非「删重复」；
--                                          此时 5 月膨胀反映真实改单，删之即失真。
--
--   §A-P0-5a 之 D 与 R：
--     d_eq_zero_n / comparable_n ≈ 1     → 表一 bet41 即 validbet 之副本 →
--                                          行 210「下注退水金额」须斧正（归 v11-S 登记修订）。
--     r_near_one 高而 d_eq_zero 低       → 二者近似而不恒等 → 须再查其差之结构，
--                                          ⛔ 不得以「近似」一语定案。
--     b41_eq_b16_n 显著 > 0              → 部分行两者相等 → 或存在分段语义，须按维再拆。
--
--   ⛔ 无论结果如何，本稿不得回写 v10；一切修正另起 v11-S（登记）／v12-Q（工程）。
--   ⛔ 「跑过了」不等于 OBSERVED：须同时留存查询原文、六元组、执行时点与行数。
--
-- 【尚未涵盖 · 待续】
--   P02C（键检验）、K01b_goldip（金标准 IP 种子；既有实测为零行，须先复验零行是否仍成立）
--   表一 bet41 与表二 bet41 之跨表比对（须先定接线键，属另案）
-- =====================================================================
