-- ══════════════════════════════════════════════════════════════════════════
-- §QSB-02b-2 · bet28～bet31 五闸检验  审计工具 v1.0.0
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由（★ 系我方选样偏差之补正，非为「找到」outcome 字段）：
--   §QSB-02a 实测得低基数（2~8 取值）字段八个：
--     bet23(8) bet28(6) bet29(8) bet30(7) bet31(8) bet38(2) category(2) commission(8)
--   而我于 §QSB-02b 只检了 bet23(8)、bet24(12)、bet40(12) 三者——
--   **其中 bet24／bet40 各 12 取值，反不在最优区间；而 bet28~31 四者在区间内却未检。**
--   ★ 故上轮之负面结论建立在**我自己选窄之集合**上。本件补正此偏差。
--
-- ★★ 措辞锁（承裁示）：bet28~31 现只得称 **「低基数未检字段」**，
--   **禁称「结算态候选字段」**——低基数系 screening signal，非 semantic evidence。
--   一个只有 0／1 之字段，同可为奖励标／注型标／手续费标／测试标／渠道标。
--
-- 【五闸 · 每字段皆须过】
--   闸① 互斥      一值不得同承多态 → 以 pct_pnl_zero／pos／neg 三率之纯度验
--   闸② 穷举      各取值须覆盖母体 → pct_of_field 各值之和须为 100，n_null 单列
--   闸③ bet09 稳定 同一状态值不得跨大量注型后失一致 → n_bet09
--   闸④ 经济方向   与 pnl／payout／stake 之关系 **只作支持证据，禁反推语义**
--   闸⑤ 时间稳定   n_dates／min_dt／max_dt —— 免某字段只是某时段之偶然编码
--
-- 【四态判词】
--   STATE_CANDIDATE   某态纯度 100%
--   WEAK_CANDIDATE    单态占比 ≥ 95% 而未达 100%（须查残余）
--   NON_STATE         三态混杂
--   UNRESOLVED        样本不足千笔，无判别力
--
-- ★★★ 最要紧之一条（承锁四十六）：
--   **五闸全过 ≠ outcome semantics 已证。**
--   纵某值现漂亮之三态互斥，亦只得入 STATE_CANDIDATE，其后仍须追问：
--     该值究竟代表 WIN／LOSS／PUSH？谁定义此编码？canonical 有无对应语义？
--   **禁由「value = 2 → pnl = 0 → payout = stake」径写「2 = PUSH」。**
--
-- 【承 §QSB-02c 之裁定（照录，本件不改其等级）】
--   economic_zero_refund_shape   STRONGLY_SUPPORTED   八族无一例外
--   generic_push_mechanism       REJECTED             极差 12,189 倍
--   family_specific_mechanism    PENDING_VALIDATION   ★ 非「三种机制已证」
--   outcome_semantics            PENDING
--
-- 【若四者仍全为 NON_STATE，可升之负面结论（★ 仍不得越级）】
--   可写：NO_OUTCOME_FIELD_FOUND_IN_TESTED_LOW_CARD_SET
--   禁写：ODS_HAS_NO_OUTCOME_STATE_FIELD
--   （bet25(17) bet26(24) bet10(25) 等中基数字段仍未检；未观察到 ≠ 不存在）
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-02b-2 · bet28／bet29／bet30／bet31 四字段 × 五闸
-- ▸ 导出：需要 —— 存为「审计/_qsb/_QSB_02b2_lowcard_five_gates.csv」。
--   ★ 判读次序：先看 verdict_state，再看纯度三率，最后并读 n_bet09 与 n_dates。
--   ★ 硬校验：各字段之 n_rows 合计须等于 125,649,147（category='1' 之母体）。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet28'                                                                  AS field_name,             -- 字面取值：受检字段名（★ 低基数未检字段）
  COALESCE(NULLIF(TRIM(bet28), ''), '(空)')                                AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：〔闸②〕该取值之行数
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 6)                     AS pct_of_field,           -- 比率表达式：〔闸②〕占该字段母体之比
  SUM(CASE WHEN NULLIF(TRIM(bet28), '') IS NULL THEN 1 ELSE 0 END)         AS n_null,                 -- 条件计数：〔闸②〕空值数
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：〔闸③〕涉及注型数
  COUNT(DISTINCT dt)                                                     AS n_dates,                -- 计数表达式：〔闸⑤〕涉及天数
  MIN(dt)                                                                AS min_dt,                 -- 聚合取值：〔闸⑤〕首现日
  MAX(dt)                                                                AS max_dt,                 -- 聚合取值：〔闸⑤〕末现日
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：〔闸④〕净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：〔闸④〕会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：〔闸④〕会员赢
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_zero,           -- 比率表达式：〔闸①〕零输赢纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_pos,            -- 比率表达式：〔闸①〕会员输纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_neg,            -- 比率表达式：〔闸①〕会员赢纯度
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_exact_refund, -- 条件计数：〔闸④〕原额退还
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_payout_zero, -- 条件计数：〔闸④〕派彩为零而本金为正
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 0), 6) AS payout_over_stake,  -- 比率表达式：〔闸④〕派彩本金比
  CASE                                                                                              -- 条件分支：起始分支——四态判词（★ 五闸全过 ≠ 语义已证）
    WHEN COUNT(*) < 1000
      THEN 'UNRESOLVED —— 样本不足千笔，无判别力'                                                    -- 分支判定：样本不足
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒零，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒零纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒正，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒正纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒负，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒负纯态
    WHEN GREATEST(
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
         ) * 100.0 / NULLIF(COUNT(*), 0) >= 95
      THEN 'WEAK_CANDIDATE —— 单态占比逾 95% 而未达 100%，须查残余'                                    -- 分支判定：近纯态
    ELSE 'NON_STATE —— 三态混杂，该值非结算态之判别'                                                  -- 分支判定：混杂
  END                                                                    AS verdict_state           -- 条件分支：收束上方判词，产出「verdict_state」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet28), ''), '(空)')                                                    -- 分组：按该字段取值汇总

UNION ALL                                                                                           -- 集合运算：并接下一受检字段之同构结果

SELECT                                                                                              -- 取列：起始取列子句
  'bet29'                                                                  AS field_name,             -- 字面取值：受检字段名（★ 低基数未检字段）
  COALESCE(NULLIF(TRIM(bet29), ''), '(空)')                                AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：〔闸②〕该取值之行数
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 6)                     AS pct_of_field,           -- 比率表达式：〔闸②〕占该字段母体之比
  SUM(CASE WHEN NULLIF(TRIM(bet29), '') IS NULL THEN 1 ELSE 0 END)         AS n_null,                 -- 条件计数：〔闸②〕空值数
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：〔闸③〕涉及注型数
  COUNT(DISTINCT dt)                                                     AS n_dates,                -- 计数表达式：〔闸⑤〕涉及天数
  MIN(dt)                                                                AS min_dt,                 -- 聚合取值：〔闸⑤〕首现日
  MAX(dt)                                                                AS max_dt,                 -- 聚合取值：〔闸⑤〕末现日
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：〔闸④〕净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：〔闸④〕会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：〔闸④〕会员赢
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_zero,           -- 比率表达式：〔闸①〕零输赢纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_pos,            -- 比率表达式：〔闸①〕会员输纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_neg,            -- 比率表达式：〔闸①〕会员赢纯度
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_exact_refund, -- 条件计数：〔闸④〕原额退还
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_payout_zero, -- 条件计数：〔闸④〕派彩为零而本金为正
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 0), 6) AS payout_over_stake,  -- 比率表达式：〔闸④〕派彩本金比
  CASE                                                                                              -- 条件分支：起始分支——四态判词（★ 五闸全过 ≠ 语义已证）
    WHEN COUNT(*) < 1000
      THEN 'UNRESOLVED —— 样本不足千笔，无判别力'                                                    -- 分支判定：样本不足
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒零，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒零纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒正，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒正纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒负，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒负纯态
    WHEN GREATEST(
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
         ) * 100.0 / NULLIF(COUNT(*), 0) >= 95
      THEN 'WEAK_CANDIDATE —— 单态占比逾 95% 而未达 100%，须查残余'                                    -- 分支判定：近纯态
    ELSE 'NON_STATE —— 三态混杂，该值非结算态之判别'                                                  -- 分支判定：混杂
  END                                                                    AS verdict_state           -- 条件分支：收束上方判词，产出「verdict_state」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet29), ''), '(空)')                                                    -- 分组：按该字段取值汇总

UNION ALL                                                                                           -- 集合运算：并接下一受检字段之同构结果

SELECT                                                                                              -- 取列：起始取列子句
  'bet30'                                                                  AS field_name,             -- 字面取值：受检字段名（★ 低基数未检字段）
  COALESCE(NULLIF(TRIM(bet30), ''), '(空)')                                AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：〔闸②〕该取值之行数
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 6)                     AS pct_of_field,           -- 比率表达式：〔闸②〕占该字段母体之比
  SUM(CASE WHEN NULLIF(TRIM(bet30), '') IS NULL THEN 1 ELSE 0 END)         AS n_null,                 -- 条件计数：〔闸②〕空值数
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：〔闸③〕涉及注型数
  COUNT(DISTINCT dt)                                                     AS n_dates,                -- 计数表达式：〔闸⑤〕涉及天数
  MIN(dt)                                                                AS min_dt,                 -- 聚合取值：〔闸⑤〕首现日
  MAX(dt)                                                                AS max_dt,                 -- 聚合取值：〔闸⑤〕末现日
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：〔闸④〕净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：〔闸④〕会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：〔闸④〕会员赢
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_zero,           -- 比率表达式：〔闸①〕零输赢纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_pos,            -- 比率表达式：〔闸①〕会员输纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_neg,            -- 比率表达式：〔闸①〕会员赢纯度
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_exact_refund, -- 条件计数：〔闸④〕原额退还
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_payout_zero, -- 条件计数：〔闸④〕派彩为零而本金为正
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 0), 6) AS payout_over_stake,  -- 比率表达式：〔闸④〕派彩本金比
  CASE                                                                                              -- 条件分支：起始分支——四态判词（★ 五闸全过 ≠ 语义已证）
    WHEN COUNT(*) < 1000
      THEN 'UNRESOLVED —— 样本不足千笔，无判别力'                                                    -- 分支判定：样本不足
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒零，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒零纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒正，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒正纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒负，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒负纯态
    WHEN GREATEST(
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
         ) * 100.0 / NULLIF(COUNT(*), 0) >= 95
      THEN 'WEAK_CANDIDATE —— 单态占比逾 95% 而未达 100%，须查残余'                                    -- 分支判定：近纯态
    ELSE 'NON_STATE —— 三态混杂，该值非结算态之判别'                                                  -- 分支判定：混杂
  END                                                                    AS verdict_state           -- 条件分支：收束上方判词，产出「verdict_state」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet30), ''), '(空)')                                                    -- 分组：按该字段取值汇总

UNION ALL                                                                                           -- 集合运算：并接下一受检字段之同构结果

SELECT                                                                                              -- 取列：起始取列子句
  'bet31'                                                                  AS field_name,             -- 字面取值：受检字段名（★ 低基数未检字段）
  COALESCE(NULLIF(TRIM(bet31), ''), '(空)')                                AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：〔闸②〕该取值之行数
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 6)                     AS pct_of_field,           -- 比率表达式：〔闸②〕占该字段母体之比
  SUM(CASE WHEN NULLIF(TRIM(bet31), '') IS NULL THEN 1 ELSE 0 END)         AS n_null,                 -- 条件计数：〔闸②〕空值数
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：〔闸③〕涉及注型数
  COUNT(DISTINCT dt)                                                     AS n_dates,                -- 计数表达式：〔闸⑤〕涉及天数
  MIN(dt)                                                                AS min_dt,                 -- 聚合取值：〔闸⑤〕首现日
  MAX(dt)                                                                AS max_dt,                 -- 聚合取值：〔闸⑤〕末现日
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：〔闸④〕净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：〔闸④〕会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：〔闸④〕会员赢
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_zero,           -- 比率表达式：〔闸①〕零输赢纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_pos,            -- 比率表达式：〔闸①〕会员输纯度
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_neg,            -- 比率表达式：〔闸①〕会员赢纯度
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_exact_refund, -- 条件计数：〔闸④〕原额退还
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_payout_zero, -- 条件计数：〔闸④〕派彩为零而本金为正
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)))
        / NULLIF(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 0), 6) AS payout_over_stake,  -- 比率表达式：〔闸④〕派彩本金比
  CASE                                                                                              -- 条件分支：起始分支——四态判词（★ 五闸全过 ≠ 语义已证）
    WHEN COUNT(*) < 1000
      THEN 'UNRESOLVED —— 样本不足千笔，无判别力'                                                    -- 分支判定：样本不足
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒零，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒零纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒正，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒正纯态
    WHEN COUNT(*) = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
      THEN 'STATE_CANDIDATE —— pnl 恒负，纯度 100%（★ 语义仍待证）'                                   -- 分支判定：恒负纯态
    WHEN GREATEST(
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END),
           SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END)
         ) * 100.0 / NULLIF(COUNT(*), 0) >= 95
      THEN 'WEAK_CANDIDATE —— 单态占比逾 95% 而未达 100%，须查残余'                                    -- 分支判定：近纯态
    ELSE 'NON_STATE —— 三态混杂，该值非结算态之判别'                                                  -- 分支判定：混杂
  END                                                                    AS verdict_state           -- 条件分支：收束上方判词，产出「verdict_state」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet31), ''), '(空)')                                                    -- 分组：按该字段取值汇总
ORDER BY field_name, n_rows DESC, field_value;                                                      -- 排序：按字段名与行数排列；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之二条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁四十八 · 低基数系 screening signal，非 semantic evidence。
--   取值少只是**必要条件**。bet28~31 现只得称「低基数未检字段」，
--   **禁称「结算态候选字段」**——后者已含语义预设。
--   ★ 一个只有 0／1 之字段，同可为：奖励标／注型标／手续费标／测试标／
--     渠道标／某投注类型标。须过五闸方得升为 STATE_CANDIDATE。
--
-- 锁四十九 · 受检集合须先自证其无选样偏差。
--   ★ 我于 §QSB-02b 选了 bet23／bet24／bet40，而 §QSB-02a 之最优区间（2~8）内
--     实有八个字段，我漏了 bet28~31 四个，却选入 bet24／bet40 两个区间外者。
--   → **负面结论之效力，以受检集合之完整性为上限。**
--     集合若系自选而窄，则「找不到」只证「我没找那儿」。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
