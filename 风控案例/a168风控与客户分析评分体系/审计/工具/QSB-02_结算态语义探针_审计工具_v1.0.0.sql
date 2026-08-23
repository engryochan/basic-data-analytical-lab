-- ══════════════════════════════════════════════════════════════════════════
-- §QSB-02 · Outcome State ／ Settlement Semantics 探针  v1.0.0
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由（承裁示第七节 · 且系我方自纠）：
--   ★★ 我上轮书「它是原额退还，即 push 之标准形态」——**从 P&L 反推结算态**。
--     裁示所诫者正是此事：**真正之 outcome state 须来自结果语义字段，
--     非自 P&L 反推。** payout = stake 只是**经济结果**，非**结算状态**。
--   ★ 且实测本身即反证：pct_pnl_zero 三族相差万倍——
--       Banker／Player          9.48%
--       DragonBonus／Natural    1.8%
--       Tie／对子族             0.0008%
--     若 push 机制同一，率不该如此。**故形态成立，机制未成立。**
--
-- 【锁四十五 · 修订版（原判撤销）】
--   本数据集中，pnl = 0 ∧ stake > 0 之记录全部呈原额退还形态
--   （23 注型逐行 n_pnl_zero_stake_pos ≡ n_exact_refund）；
--   其 push 身份**已获强支持**，惟 push **触发机制须按 bet09 家族继续验证**。
--   ★ economic_zero ≠ outcome_push 之一般逻辑（锁四十二）继续有效。
--
-- 【本件之唯一目标】
--   自 ODS 找出能可靠区分 WIN／LOSS／PUSH／CANCEL／VOID／UNSETTLED 之**原始字段**。
--   ★ 找得到 → push 由事实字段定义，非任意设计
--   ★ 找不到 → 方回到 WR-A／WR-B／WR-C 作定义选择
--
-- 【现况 · canonical 已注字段仅 13 个，未注 22 个】
--   已注：bet02 bet03 bet05 bet09 bet11 bet13 bet14 bet15 bet17 bet27 bet32 bet38 bet41
--   ★ 未注：bet01 bet04 bet06 bet07 bet08 bet10 bet16 bet18~bet26 bet28~bet31 bet39 bet40
--   → 结算态字段极可能藏于未注之 22 个中。本件逐一普查其取值形态。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-02a · 低基数字段普查（★ 结算态字段之必要条件：取值少）
-- ▸ 导出：需要 —— 存为「审计/_qsb/_QSB_02a_lowcard_fields.csv」。
--   ★ 判读：结算态字段之取值数应在 2~8 之间（WIN／LOSS／PUSH／CANCEL／VOID／…）。
--     取值数 = 1        → 单值字段，无判别力（如 mem024 之殷鉴）
--     取值数 2~8        → ★ 结算态之候选
--     取值数 > 100      → 系连续量或标识符，非状态
--   ★ 本条只跑一次，答「哪些字段可能是状态字段」。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet02 表之低基数字段普查（限窗 · 限百家乐）'                              AS scope,                  -- 字面取值：受检范围
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：母体行数
  COUNT(DISTINCT TRIM(bet04))                                            AS nd_bet04,               -- 计数表达式：局号／桌号之候选
  COUNT(DISTINCT TRIM(bet06))                                            AS nd_bet06,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet07))                                            AS nd_bet07,               -- 计数表达式：账务日（在册 dt = bet07 100%）
  COUNT(DISTINCT TRIM(bet10))                                            AS nd_bet10,               -- 计数表达式：★ 未注字段——币别之候选
  COUNT(DISTINCT TRIM(bet23))                                            AS nd_bet23,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet24))                                            AS nd_bet24,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet25))                                            AS nd_bet25,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet26))                                            AS nd_bet26,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet28))                                            AS nd_bet28,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet29))                                            AS nd_bet29,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet30))                                            AS nd_bet30,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet31))                                            AS nd_bet31,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet40))                                            AS nd_bet40,               -- 计数表达式：★ 未注字段
  COUNT(DISTINCT TRIM(bet38))                                            AS nd_bet38,               -- 计数表达式：重对标记（已知 'N'）
  COUNT(DISTINCT TRIM(category))                                         AS nd_category,            -- 计数表达式：注单类别（已证仅 1／2）
  COUNT(DISTINCT TRIM(commission))                                       AS nd_commission           -- 计数表达式：佣金标记（已证 8 值）
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101';                                                                -- 并列条件：限定百家乐


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-02b · 候选状态字段 × 经济形态交叉（★ 本件之核心）
-- ▸ 导出：需要 —— 存为「审计/_qsb/_QSB_02b_state_cross.csv」。
--   ★ 缘由：低基数只是**必要条件**。真正之结算态字段，其取值须与经济形态**对齐**：
--       某取值 → pnl 恒零 ∧ payout ＝ stake        → PUSH 之候选
--       某取值 → pnl 恒正（会员输）                 → LOSS 之候选
--       某取值 → pnl 恒负（会员赢）                 → WIN 之候选
--       某取值 → payout 恒零                       → CANCEL／VOID 之候选
--   ★★ 若无任一字段能如此对齐，即证 ODS 无结算态字段，
--       则 push 只得由定义选择（WR-A／B／C），非事实字段所定。
--   ★ 本条只跑 bet23／bet24／bet40 三个候选（若 §QSB-02a 显示他者低基数，另跑）。
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  'bet23'                                                                AS field_name,             -- 字面取值：受检字段名
  COALESCE(NULLIF(TRIM(bet23), ''), '(空)')                              AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该取值之行数
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：会员赢
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)   AS n_payout_zero, -- 条件计数：派彩为零
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：涉及注型数
  CASE                                                                                              -- 条件分支：起始分支——对齐度裁定
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒零 —— PUSH 之强候选'                                                     -- 分支判定：恒零
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒正 —— LOSS 之强候选'                                                     -- 分支判定：恒正
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒负 —— WIN 之强候选'                                                      -- 分支判定：恒负
    ELSE '◐ 三态混杂 —— 该取值非结算态之判别'                                                          -- 分支判定：混杂
  END                                                                    AS verdict_align           -- 条件分支：收束上方判词，产出「verdict_align」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet23), ''), '(空)')                                                  -- 分组：按 bet23 取值汇总

UNION ALL                                                                                           -- 集合运算：并接下一候选字段之同构结果

SELECT                                                                                              -- 取列：起始取列子句
  'bet24'                                                                AS field_name,             -- 字面取值：受检字段名
  COALESCE(NULLIF(TRIM(bet24), ''), '(空)')                              AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该取值之行数
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：会员赢
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)   AS n_payout_zero, -- 条件计数：派彩为零
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：涉及注型数
  CASE                                                                                              -- 条件分支：起始分支——对齐度裁定
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒零 —— PUSH 之强候选'                                                     -- 分支判定：恒零
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒正 —— LOSS 之强候选'                                                     -- 分支判定：恒正
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒负 —— WIN 之强候选'                                                      -- 分支判定：恒负
    ELSE '◐ 三态混杂 —— 该取值非结算态之判别'                                                          -- 分支判定：混杂
  END                                                                    AS verdict_align           -- 条件分支：收束上方判词，产出「verdict_align」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet24), ''), '(空)')                                                  -- 分组：按 bet24 取值汇总

UNION ALL                                                                                           -- 集合运算：并接下一候选字段之同构结果

SELECT                                                                                              -- 取列：起始取列子句
  'bet40'                                                                AS field_name,             -- 字面取值：受检字段名
  COALESCE(NULLIF(TRIM(bet40), ''), '(空)')                              AS field_value,            -- 条件取值：字段取值，空另列
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该取值之行数
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：净输赢为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_pos,  -- 条件计数：会员输
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_neg,  -- 条件计数：会员赢
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)   AS n_payout_zero, -- 条件计数：派彩为零
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：涉及注型数
  CASE                                                                                              -- 条件分支：起始分支——对齐度裁定
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒零 —— PUSH 之强候选'                                                     -- 分支判定：恒零
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒正 —— LOSS 之强候选'                                                     -- 分支判定：恒正
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 该取值下 pnl 恒负 —— WIN 之强候选'                                                      -- 分支判定：恒负
    ELSE '◐ 三态混杂 —— 该取值非结算态之判别'                                                          -- 分支判定：混杂
  END                                                                    AS verdict_align           -- 条件分支：收束上方判词，产出「verdict_align」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY COALESCE(NULLIF(TRIM(bet40), ''), '(空)')                                                  -- 分组：按 bet40 取值汇总
ORDER BY field_name, n_rows DESC, field_value;                                                      -- 排序：按字段名与行数排列；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-02c · push 机制之分族验证（★ 承裁示：禁以庄闲之 9.48% 外推）
-- ▸ 导出：需要 —— 存为「审计/_qsb/_QSB_02c_push_by_family.csv」。
--   ★ 实测已见三族相差万倍：庄闲 9.48% ／ Dragon-Natural 1.8% ／ Tie-对子 0.0008%。
--     若 push 机制同一，率不该如此。故须逐族确认其触发条件。
--   ★ 判读：
--     该族 pct_pnl_zero 近该族之理论 push 概率  → 机制与理论相符
--     远高于理论                               → 另有他因（如取消、调账）
--     远低于理论                               → 该族之 push 或不以退还实现
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  CASE                                                                                              -- 条件分支：起始分支——注型分族
    WHEN TRIM(bet09) IN ('Banker', 'Player')                        THEN 'F1_庄闲主注'               -- 分支判定：主注族
    WHEN TRIM(bet09) = 'Tie'                                        THEN 'F2_和局'                   -- 分支判定：和局
    WHEN TRIM(bet09) IN ('BPair', 'PPair', 'AnyPair', 'PerfectPair') THEN 'F3_对子族'                 -- 分支判定：对子族
    WHEN TRIM(bet09) IN ('BankerNatural', 'PlayerNatural')          THEN 'F4_例牌族'                  -- 分支判定：例牌族
    WHEN TRIM(bet09) IN ('BankerDragonBonus', 'PlayerDragonBonus')  THEN 'F5_龙宝族'                  -- 分支判定：龙宝族
    WHEN TRIM(bet09) IN ('Super6', 'Lucky7', 'SuperLucky7')         THEN 'F6_幸运族'                  -- 分支判定：幸运族
    WHEN TRIM(bet09) IN ('Big', 'Small')                            THEN 'F7_大小'                    -- 分支判定：大小
    ELSE 'F8_其他与新上线'                                                                            -- 分支判定：其余
  END                                                                    AS bet09_family,           -- 条件分支：收束上方分族，产出「bet09_family」
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09_in_family,      -- 计数表达式：族内注型数
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：族内行数
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：净输赢为零
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_zero,           -- 比率表达式：★ 该族之零输赢率
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_exact_refund, -- 条件计数：★ 原额退还
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_payout_zero_stake_pos, -- 条件计数：★ 派彩为零而本金为正——全输
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_player_win,         -- 比率表达式：会员赢之占比
  ROUND(-1 * SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))) * 100.0
        / NULLIF(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 0), 6) AS mu0_pct,            -- 比率表达式：★ 该族之 μ0——与 push 率并读
  CASE                                                                                              -- 条件分支：起始分支——机制线索
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)
       = SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                    = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
                   AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END)
      THEN '★ 零输赢者 100% 系原额退还 —— 形态一致（★ 惟机制仍须上游确认）'                              -- 分支判定：形态一致
    ELSE '❌ 零输赢者非全为原额退还 —— 该族另有他因，须逐笔查'                                            -- 分支判定：形态不一
  END                                                                    AS verdict_family          -- 条件分支：收束上方判词，产出「verdict_family」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：只看 QSB 候选宇宙
GROUP BY CASE                                                                                       -- 分组：按上方同一分族表达式汇总
    WHEN TRIM(bet09) IN ('Banker', 'Player')                        THEN 'F1_庄闲主注'
    WHEN TRIM(bet09) = 'Tie'                                        THEN 'F2_和局'
    WHEN TRIM(bet09) IN ('BPair', 'PPair', 'AnyPair', 'PerfectPair') THEN 'F3_对子族'
    WHEN TRIM(bet09) IN ('BankerNatural', 'PlayerNatural')          THEN 'F4_例牌族'
    WHEN TRIM(bet09) IN ('BankerDragonBonus', 'PlayerDragonBonus')  THEN 'F5_龙宝族'
    WHEN TRIM(bet09) IN ('Super6', 'Lucky7', 'SuperLucky7')         THEN 'F6_幸运族'
    WHEN TRIM(bet09) IN ('Big', 'Small')                            THEN 'F7_大小'
    ELSE 'F8_其他与新上线'
  END                                                                                               -- 续行：收束上方分组表达式
ORDER BY n_rows DESC, bet09_family;                                                                 -- 排序：按行数降序；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之三条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁四十五（修订版 · 原判撤销）
--   本数据集中，pnl = 0 ∧ stake > 0 之记录全部呈原额退还形态；
--   其 push 身份**已获强支持**，惟 **push 触发机制须按 bet09 家族继续验证**。
--   ★ 禁以 Banker／Player 之 9.48% 外推全部注型——实测三族相差万倍。
--
-- 锁四十六 · 结算态须来自结果语义字段，禁自 P&L 反推。
--   payout = stake 只是**经济结果**，非**结算状态**。
--   ★ 我上轮书「它是原额退还，即 push 之标准形态」即犯此错——
--     由经济形态径推结算语义，跳过了「该字段说它是什么」这一层。
--   → 找得到状态字段 → push 由事实定义；找不到 → 方回定义选择。
--
-- 锁四十七 · 低基数只是必要条件，非充分条件。
--   取值少之字段未必是状态字段（如币别、桌型皆低基数）。
--   ★ 须再验其取值与经济形态**是否对齐**：某取值下 pnl 恒零／恒正／恒负。
--     不对齐者，纵然只有两三个取值，亦非结算态之判别。
--
-- ★ 本件若三条皆未寻得对齐之字段，则正式登记：
--   **ODS 之 bet02 表无结算态字段** → push 只得由定义选择（WR-C 三态规范）。
--   此系**负面结论，同样有价值**——它把「事实定义」与「设计选择」之界划清。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
