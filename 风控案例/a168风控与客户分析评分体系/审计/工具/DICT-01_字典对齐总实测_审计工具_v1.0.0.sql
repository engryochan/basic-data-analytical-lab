-- ══════════════════════════════════════════════════════════════════════════
-- §DICT-01 · 字典对齐总实测  审计工具 v1.0.0
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由（★ 承先生一语点破）：
--   「直接通过 SQL 代码实测不就可以解开许多悬案了吗？」
--   ——是。我这几轮一直在读注释、比字典、查记录，**那都是二手证据**。
--   数据库就在那里，跑一条 SQL 便是一手实测。
--   ★ 立锁五十九：**凡可实测者，禁以文档互证代之。**
--     注释、字典、记忆三者皆是二手；同名异义之字段尤然——
--     文档说甲、字典说乙，实测方能定丙。
--
-- 【本件之四条，各解一悬案】
--   §DICT-01a  bet41 × bet16 × validbet 三方比对   → 解 B-5 之字段语义冲突
--   §DICT-01b  bet04／bet39 之真身与基数            → 解我方工具之误用
--   §DICT-01c  bet28~32 与 bet23~27 之量纲          → 解 κ 量纲（canonical 行 5595 自陈未定）
--   §DICT-01d  bet08 − bet06 下注延迟               → 解 T-12 之 grain（单表可算）
--
-- 【canonical 已核，本件不改其一字】
--   六元组：1,321,464 字节 ／ MD5 03E774DE6F71D6213E493E765AFE5A93 ／ CRLF ／ 无 BOM
--   ★ canonical 行 263／268 之字段注释与 Z03 字典完全一致（bet04 局内第几把、bet39 桌号）；
--     130 处 bet39 中三处明确 AS table_id。**canonical 无误，误在我方 A2 工具。**
--   ★ canonical 行 272／278 早已双向标注 bet41 同名异义，且行 5588 明书
--     行 5591 之「bet41 = 有效投注」所指为 ods_a168_dailyreport_member，非 bet02。
--     **两侧各自成立，无内部矛盾。**
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §DICT-01a · bet41 × bet16 × validbet 三方比对（★ 本件最要紧一条）
-- ▸ 导出：需要 —— 存为「审计/_dict/_DICT_01a_bet41_tri.csv」。
--   ★ 悬案：Z03 字典载 bet02.bet41 =「下注退水金額」，而在册实测 bet41 ≡ validbet
--     于 99.999230%。退水金额应约为有效投注之 0.9%（见 bet28~32 之量级），
--     **绝不该相等**。故三者必居其一：
--       ① 字典措辞歧义（「下注[之]退水[计算基]金額」实指计算基数）
--       ② validbet 之声明有误
--       ③ ETL 灌错
--   ★ 判读：
--     r41_vb ≈ 1.0     → bet41 系有效投注之同义列（字典措辞歧义）
--     r41_vb ≈ 0.009   → bet41 真为退水金额，则在册「≡ validbet」之实测须重查
--     r16_vb ≈ 0.009   → bet16 方为退水金额（与 H16 恒等式相符）
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet41 × bet16 × validbet 三方比对（category=1 · 过基础闸）'              AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：母体行数
  ROUND(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 2)          AS sum_stake,              -- 汇总表达式：下注金额总额
  ROUND(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 2)       AS sum_validbet,           -- 汇总表达式：有效投注总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))), 2)          AS sum_bet41,              -- 汇总表达式：bet41 总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,8))), 2)          AS sum_bet16,              -- 汇总表达式：bet16（退水金额）总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 0), 8) AS r41_vb,          -- 比率表达式：★ bet41 ÷ validbet
  ROUND(SUM(CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 0), 8) AS r16_vb,          -- 比率表达式：★ bet16 ÷ validbet
  ROUND(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 0), 8) AS r_vb_stake,         -- 比率表达式：有效投注 ÷ 下注（在册 ≈0.9004）
  ROUND(AVG(CAST(NULLIF(TRIM(bet15), '') AS DECIMAL(20,8))), 6)          AS avg_bet15_pct,          -- 聚合表达式：会员退水%数之均值——与 r16_vb 对照
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) THEN 1 ELSE 0 END) AS n_41_eq_vb,  -- 条件计数：bet41 与 validbet 逐行相等者
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet16), '') AS DECIMAL(20,8)) THEN 1 ELSE 0 END) AS n_41_eq_16,     -- 条件计数：★ bet41 与 bet16 逐行相等者
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8))
                   = CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_41_eq_vb,           -- 比率表达式：相等率
  CASE                                                                                              -- 条件分支：起始分支——三方裁定
    WHEN ROUND(SUM(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8)))
               / NULLIF(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 0), 4) BETWEEN 0.99 AND 1.01
      THEN '★ bet41 ÷ validbet ≈ 1 —— bet41 系有效投注之同义列，字典「下注退水金額」措辞歧义'          -- 分支判定：同义列
    WHEN ROUND(SUM(CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8)))
               / NULLIF(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 0), 4) < 0.1
      THEN '★★ bet41 ÷ validbet 远小于 1 —— bet41 真为退水金额，在册「≡ validbet」须重查'              -- 分支判定：真退水
    ELSE '◐ 比值居中 —— 二者关系另有structure，须逐行分层复验'                                         -- 分支判定：居中
  END                                                                    AS verdict_bet41           -- 条件分支：收束上方判词，产出「verdict_bet41」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：限定一般注单（排除小费）
  AND UPPER(TRIM(bet38)) = 'N';                                                                     -- 并列条件：限定非重对


-- ──────────────────────────────────────────────────────────────────────────
-- §DICT-01b · bet03／bet04／bet39 之基数与真身（★ 解我方工具之误用）
-- ▸ 导出：需要 —— 存为「审计/_dict/_DICT_01b_roundkey_card.csv」。
--   ★ 缘由：我于 §VB-41c／41c-2 以 bet04 当 table_id，**误**。
--     canonical 行 263／268 与 Z03 字典皆载：bet04 = 局内第几把（子場次編號）、
--     bet39 = 桌号。本条以基数实测坐实之——桌数应为数十，局内把数应为数十且连续。
--   ★ 判读：
--     nd_bet39 ≈ 30 左右且 max 小     → bet39 系桌号（在册载 30 桌）
--     nd_bet04 与 max_bet04 皆数十    → bet04 系局内序号
--     nd_bet03 极大                   → bet03 系靴号
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet03／bet04／bet39 基数实测'                                          AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：母体行数
  COUNT(DISTINCT TRIM(bet03))                                            AS nd_bet03,               -- 计数表达式：靴号之相异数
  COUNT(DISTINCT TRIM(bet04))                                            AS nd_bet04,               -- 计数表达式：★ 局内第几把之相异数
  COUNT(DISTINCT TRIM(bet39))                                            AS nd_bet39,               -- 计数表达式：★ 桌号之相异数
  COUNT(DISTINCT TRIM(bet40))                                            AS nd_bet40,               -- 计数表达式：房间编号之相异数
  MIN(CAST(NULLIF(TRIM(bet04), '') AS BIGINT))                           AS min_bet04,              -- 聚合取值：局内序号之最小
  MAX(CAST(NULLIF(TRIM(bet04), '') AS BIGINT))                           AS max_bet04,              -- 聚合取值：★ 局内序号之最大——应为数十
  MIN(CAST(NULLIF(TRIM(bet39), '') AS BIGINT))                           AS min_bet39,              -- 聚合取值：桌号之最小
  MAX(CAST(NULLIF(TRIM(bet39), '') AS BIGINT))                           AS max_bet39,              -- 聚合取值：桌号之最大
  COUNT(DISTINCT CONCAT_WS('|', TRIM(bet03), TRIM(bet04), TRIM(bet39)))  AS nd_round_key,           -- 计数表达式：局键之相异数（canonical 之定义）
  COUNT(DISTINCT CONCAT_WS('|', TRIM(bet03), TRIM(bet39)))               AS nd_shoe_table,          -- 计数表达式：靴×桌之相异数
  ROUND(COUNT(*) * 1.0
        / NULLIF(COUNT(DISTINCT CONCAT_WS('|', TRIM(bet03), TRIM(bet04), TRIM(bet39))), 0), 4) AS avg_bets_per_round, -- 比率表达式：每局平均注数
  CASE                                                                                              -- 条件分支：起始分支——真身裁定
    WHEN COUNT(DISTINCT TRIM(bet39)) <= 100 AND MAX(CAST(NULLIF(TRIM(bet04), '') AS BIGINT)) <= 200
      THEN '★ bet39 基数小（桌号）· bet04 上限数十（局内序号）—— 与字典及 canonical 一致'                -- 分支判定：与字典一致
    ELSE '❌ 基数与字典所载不符 —— 须逐列复验'                                                        -- 分支判定：不符
  END                                                                    AS verdict_key             -- 条件分支：收束上方判词，产出「verdict_key」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1';                                                                         -- 并列条件：限定一般注单


-- ──────────────────────────────────────────────────────────────────────────
-- §DICT-01c · bet23~27（占成）与 bet28~32（退水）之量纲
-- ▸ 导出：需要 —— 存为「审计/_dict/_DICT_01c_dimension.csv」。
--   ★ 缘由：canonical 行 5595 自陈「量纲未定：bet23~bet32 是『金额』还是『比率』，
--     列注释没写」，并明书「量纲判错会让 κ 差几个数量级，δ* 与 γ* 全盘失真。
--     **这一步不可跳过。**」——此乃 canonical 自己留下之待办，至今未实测。
--   ★ 判读：
--     max ≤ 100 且 avg 在 0.0x~1.x  → 比率（百分点）
--     与 avg_validbet 同量级（成千上万） → 金额
--   ★ 我方本轮已实测 bet28~31 之取值为 0.0~1.05 —— 强烈指向「比率」，
--     惟当时只看 category=1 之 bet02，未含 bet23~27，且未与 validbet 同表对照。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet23~27 占成 · bet28~32 退水 · 量纲实测'                              AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：母体行数
  ROUND(AVG(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 4)       AS avg_validbet,           -- 聚合表达式：★ 有效投注之均值——量纲对照基准
  ROUND(MAX(CAST(NULLIF(TRIM(bet23), '') AS DECIMAL(20,8))), 6)          AS max_bet23,              -- 聚合取值：LV1 占成之最大
  ROUND(AVG(CAST(NULLIF(TRIM(bet23), '') AS DECIMAL(20,8))), 6)          AS avg_bet23,              -- 聚合表达式：LV1 占成之均值
  ROUND(MAX(CAST(NULLIF(TRIM(bet27), '') AS DECIMAL(20,8))), 6)          AS max_bet27,              -- 聚合取值：LV5 占成之最大
  ROUND(MAX(CAST(NULLIF(TRIM(bet28), '') AS DECIMAL(20,8))), 6)          AS max_bet28,              -- 聚合取值：LV1 退水之最大
  ROUND(AVG(CAST(NULLIF(TRIM(bet28), '') AS DECIMAL(20,8))), 6)          AS avg_bet28,              -- 聚合表达式：LV1 退水之均值
  ROUND(MAX(CAST(NULLIF(TRIM(bet32), '') AS DECIMAL(20,8))), 6)          AS max_bet32,              -- 聚合取值：LV5 退水之最大
  ROUND(MAX(CAST(NULLIF(TRIM(bet15), '') AS DECIMAL(20,8))), 6)          AS max_bet15,              -- 聚合取值：会员退水%数之最大——已知系比率
  ROUND(AVG(CAST(NULLIF(TRIM(bet23), '') AS DECIMAL(20,8))
          + CAST(NULLIF(TRIM(bet24), '') AS DECIMAL(20,8))
          + CAST(NULLIF(TRIM(bet25), '') AS DECIMAL(20,8))
          + CAST(NULLIF(TRIM(bet26), '') AS DECIMAL(20,8))
          + CAST(NULLIF(TRIM(bet27), '') AS DECIMAL(20,8))), 6)          AS avg_sum_comm,           -- 聚合表达式：★ 五级占成之和——若系比率，其和应 ≤ 100
  CASE                                                                                              -- 条件分支：起始分支——量纲裁定
    WHEN MAX(CAST(NULLIF(TRIM(bet23), '') AS DECIMAL(20,8))) <= 100
     AND MAX(CAST(NULLIF(TRIM(bet28), '') AS DECIMAL(20,8))) <= 100
      THEN '★ bet23~32 上限 ≤ 100 —— 判为**比率（百分点）**；κ 之算式须用 × validbet ÷ 100'          -- 分支判定：比率
    WHEN MAX(CAST(NULLIF(TRIM(bet23), '') AS DECIMAL(20,8)))
       > AVG(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))) / 100
      THEN '★ 与 validbet 同量级 —— 判为**金额**；κ 之算式须直接相加'                                  -- 分支判定：金额
    ELSE '◐ 量纲未定 —— 须逐列分层复验'                                                              -- 分支判定：未定
  END                                                                    AS verdict_dimension       -- 条件分支：收束上方判词，产出「verdict_dimension」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1';                                                                         -- 并列条件：限定一般注单


-- ──────────────────────────────────────────────────────────────────────────
-- §DICT-01d · 下注延迟 bet08 − bet06（★ 解 T-12 之 grain）
-- ▸ 导出：需要 —— 存为「审计/_dict/_DICT_01d_bet_latency.csv」。
--   ★ 缘由：Contract Skeleton 判 T-12（机器人）之 grain = UNKNOWN，因
--     「gi004 可得性未验」。而 Z03 字典揭出 **bet02 自己就有 bet06 = 開局時間**，
--     故 下注延迟 = bet08 − bet06，**同表可算，无须连 game_info**。
--   ★ 判读（按桌分层，承「禁全网一刀切」）：
--     p50 稳定于数秒         → 常态人工下注
--     p01 极小且方差极低      → 机器人之候选形态（★ 惟须再验，非定谳）
--     负值                   → 时序倒挂，须查 ETL
--   ★ 本条只出分布，**不判机器人**——判据须俟 registry 之 T-12 定谳。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(bet39)                                                            AS table_id,               -- 取列：★ 桌号（bet39，非 bet04）
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该桌注数
  COUNT(DISTINCT TRIM(bet05))                                            AS n_members,              -- 计数表达式：该桌会员数
  SUM(CASE WHEN NULLIF(TRIM(bet06), '') IS NULL THEN 1 ELSE 0 END)       AS n_b06_null,             -- 条件计数：★ 开局时间为空者——可得性之判
  SUM(CASE WHEN NULLIF(TRIM(bet08), '') IS NULL THEN 1 ELSE 0 END)       AS n_b08_null,             -- 条件计数：下注时间为空者
  SUM(CASE WHEN TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME)) < 0
           THEN 1 ELSE 0 END)                                            AS n_negative,             -- 条件计数：★ 延迟为负——时序倒挂
  ROUND(MIN(TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME))), 4) AS lat_min, -- 聚合取值：延迟之最小
  ROUND(AVG(TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME))), 4) AS lat_avg, -- 聚合表达式：延迟之均值
  ROUND(MAX(TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME))), 4) AS lat_max, -- 聚合取值：★ 延迟之最大——投注窗之上界
  ROUND(PERCENTILE_APPROX(
          TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME)), 0.01), 4) AS lat_p01, -- 分位表达式：延迟之 1% 分位
  ROUND(PERCENTILE_APPROX(
          TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME)), 0.50), 4) AS lat_p50, -- 分位表达式：延迟之中位
  ROUND(PERCENTILE_APPROX(
          TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME)), 0.99), 4) AS lat_p99, -- 分位表达式：延迟之 99% 分位
  ROUND(STDDEV_POP(
          TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME))), 4) AS lat_sd,   -- 聚合表达式：延迟之标准差
  CASE                                                                                              -- 条件分支：起始分支——可得性裁定
    WHEN SUM(CASE WHEN NULLIF(TRIM(bet06), '') IS NULL THEN 1 ELSE 0 END) > 0
      THEN '❌ 该桌有开局时间为空者 —— 延迟不可全算'                                                   -- 分支判定：有空值
    WHEN SUM(CASE WHEN TIMESTAMPDIFF(SECOND, CAST(bet06 AS DATETIME), CAST(bet08 AS DATETIME)) < 0
             THEN 1 ELSE 0 END) > 0
      THEN '★ 该桌有时序倒挂（bet08 < bet06）—— 须查 ETL，禁直接用'                                    -- 分支判定：倒挂
    ELSE '✅ 该桌延迟可算（★ 只出分布，不判机器人）'                                                    -- 分支判定：可算
  END                                                                    AS verdict_latency         -- 条件分支：收束上方判词，产出「verdict_latency」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：限定一般注单
  AND UPPER(TRIM(bet38)) = 'N'                                                                      -- 并列条件：限定非重对
GROUP BY TRIM(bet39)                                                                                -- 分组：按桌号汇总
ORDER BY n_rows DESC, table_id;                                                                     -- 排序：按注数降序；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之三条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁五十九 · ★ 凡可实测者，禁以文档互证代之。
--   注释、字典、记忆三者皆是**二手证据**；同名异义之字段尤然——
--   文档说甲、字典说乙，**实测方能定丙**。
--   ★ 我这几轮读注释、比字典、查记录，绕了一大圈；
--     数据库就在那里，跑一条 SQL 便是一手实测。
--
-- 锁六十 · canonical 自陈之待办，即是最高优先之实测项。
--   canonical 行 5595~5600 自书「量纲未定 …… 这一步不可跳过」，
--   而该探针已于 2026-08-09 被摘除（行 5605），至今未补跑。
--   ★ 凡 canonical 自己标「须跑而未跑」者，其优先级高于任何外部建议。
--
-- 锁六十一 · 本件只出分布与比值，**不出判据**。
--   §DICT-01d 之延迟分布不得径解为机器人；
--   §DICT-01c 之量纲一旦判定，κ 之算式须另案修订，非本件所能改。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（1,321,464 字节 / 03E774DE6F71D6213E493E765AFE5A93 /
--   CRLF / 无 BOM / 10,548 行），六元组本轮已核，本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
