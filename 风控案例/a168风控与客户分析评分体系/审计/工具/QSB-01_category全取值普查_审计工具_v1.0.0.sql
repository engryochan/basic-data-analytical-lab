-- ══════════════════════════════════════════════════════════════════════════
-- §QSB-01 · category 全取值普查  审计工具 v1.0.0
-- ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
-- ══════════════════════════════════════════════════════════════════════════
-- 立件缘由：
--   canonical 全包 54 处以 category = '1' 为准入，惟**其余取值代表什么，从未普查**。
--   若 category = '2' 恰系「已取消」，则 QSB 之取消单一项自解；
--   **若不是，则取消单现仍混在 category = '1' 内**——
--   届时不止 win_rate 须改，**现有 54 处准入条件皆须复核**。
--
-- ★ 承裁示之分野（较我原提之「快慢」为硬）：
--     category 系**事实边界问题**  ／  push 系**定义选择问题**
--   事实边界未钉死而先选 push 契约，即把设计建在可能错误之 qualifying universe 上。
--   故本件先行，push 暂不裁。
--
-- ★ 探针纪律（承裁示）：**不得只跑 GROUP BY category**。
--   那只答「有哪些值」，不答「这些值是什么意思」。
--   故本件三条并出：取值画像 ／ 互斥穷举 ／ category='1' 内之污染探查。
--
-- 【已揭之动因 · win_rate 四套两式】
--   §R-03 行4531  n_win / n_dec              push EXCLUDE
--   §DX-04 行5938 SUM(pnl>0)/SUM(pnl<>0)     push EXCLUDE
--   §R03b 行6145  同上                        push EXCLUDE
--   §P11  行9431  win_orders / total_orders  push INCLUDE  ★ 且分母是否含基础闸未明
--   二式差约 4.76 pp（以和局率 9.5% 计）；canonical 行4081 明书须三态，四处无一是三态。
--
-- 纪律：行注释 only；注释内不写分号；无 OFFSET；导出必带确定性排序；
--   ODS 全列 varchar，比较前一律 TRIM＋NULLIF＋CAST；除零一律 NULLIF。
-- ══════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-01a · category 全取值画像（★ 答「这些值是什么意思」）
-- ▸ 导出：需要 —— 存为「审计/_qsb/_QSB_01a_category_census.csv」。
--   ★ 判读线索（皆为形态，非定谳）：
--     pnl 恒零 ∧ stake > 0            → 取消／退还之候选
--     validbet 恒零 ∧ pnl 非零        → 不计洗码之特殊单
--     bet14 恒零 ∧ bet13 > 0          → 单向扣款（同 Tip_1_ 之形态）
--     n_dates 极少 ∧ n_rows 极少      → 测试或异常
--     pnl 三态齐备                    → 常态结算单之候选
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  COALESCE(NULLIF(TRIM(category), ''), '(空值或空串)')                    AS category_value,         -- 条件取值：★ 空与空串合并另列，不与有值混
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该取值之行数
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 8)                     AS pct_of_total,           -- 比率表达式：占全母体之比
  COUNT(DISTINCT TRIM(bet05))                                            AS n_members,              -- 计数表达式：涉及会员数
  COUNT(DISTINCT dt)                                                     AS n_dates,                -- 计数表达式：涉及天数（对照全窗 139）
  MIN(dt)                                                                AS min_dt,                 -- 聚合取值：首现日
  MAX(dt)                                                                AS max_dt,                 -- 聚合取值：末现日
  COUNT(DISTINCT TRIM(bet09))                                            AS n_bet09,                -- 计数表达式：涉及注型数
  SUM(CASE WHEN NULLIF(TRIM(bet14), '') IS NULL THEN 1 ELSE 0 END)       AS n_b14_null,             -- 条件计数：★ 派彩为空——未结算之候选
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_b14_zero, -- 条件计数：派彩为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_b14_pos,  -- 条件计数：派彩为正
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero, -- 条件计数：★ 净输赢为零——push／取消之候选
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_pnl_house_win, -- 条件计数：庄家赢（会员输）
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) AS n_pnl_player_win, -- 条件计数：会员赢
  SUM(CASE WHEN CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_vb_zero, -- 条件计数：洗码为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet41), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END)   AS n_b41_zero, -- 条件计数：bet41 为零
  ROUND(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 2)          AS stake_sum,              -- 汇总表达式：本金总额
  ROUND(SUM(CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))), 2)          AS payout_sum,             -- 汇总表达式：派彩总额
  ROUND(SUM(CAST(NULLIF(TRIM(validbet), '') AS DECIMAL(20,8))), 2)       AS validbet_sum,           -- 汇总表达式：洗码总额
  COUNT(DISTINCT TRIM(bet38))                                            AS n_rebet_flag,           -- 计数表达式：重对标记之取值数
  COUNT(DISTINCT TRIM(commission))                                       AS n_commission,           -- 计数表达式：佣金标记之取值数
  CASE                                                                                              -- 条件分支：起始分支——形态线索（★ 非定谳）
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 净输赢恒零 —— 取消／退还之候选（须上游确认）'                                            -- 分支判定：pnl 恒零
    WHEN SUM(CASE WHEN NULLIF(TRIM(bet14), '') IS NULL THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 派彩恒空 —— 未结算之候选（须上游确认）'                                                 -- 分支判定：派彩恒空
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) = COUNT(*)
      THEN '★ 派彩恒零 —— 单向扣款之候选（同 Tip_1_ 形态）'                                           -- 分支判定：派彩恒零
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) > 0
     AND SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) < 0 THEN 1 ELSE 0 END) > 0
      THEN '◐ 输赢两向俱备 —— 常态结算单之候选'                                                       -- 分支判定：两向俱备
    ELSE '◐ 形态未归类 —— 须逐项人查'                                                                -- 分支判定：未归类
  END                                                                    AS shape_hint              -- 条件分支：收束上方判词，产出「shape_hint」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
GROUP BY COALESCE(NULLIF(TRIM(category), ''), '(空值或空串)')                                        -- 分组：按 category 取值汇总
ORDER BY n_rows DESC, category_value;                                                               -- 排序：按行数降序；导出必带排序


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-01b · 互斥穷举核验（★ Σ category_n 须等于母体 n_rows）
-- ▸ 导出：不需要 —— 屏幕看结果。
--   ★ 判读：
--     n_sum = n_total ∧ n_unclassified = 0  → 穷举成立，无遗漏
--     n_null_category > 0                   → ★ 空值 category 须单列报告，禁并入任一有值组
-- ──────────────────────────────────────────────────────────────────────────
WITH src AS (                                                                                       -- 公共表表达式：开启中间结果集 src——母体逐行
  SELECT TRIM(category)                                                  AS c,                      -- 取列：注单类别（去空白）
         category                                                        AS c_raw                   -- 取列：注单类别原值
  FROM ods_mariadb_2b.ods_a168_bet02                                                                -- 取数来源：取自注单主表
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定分析窗
    AND CAST(bet02 AS STRING) = '101'                                                               -- 并列条件：限定百家乐
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 取列：起始取列子句
  COUNT(*)                                                               AS n_total,                -- 计数表达式：母体总行数（应为 125,654,711）
  COUNT(DISTINCT COALESCE(c, '(NULL)'))                                  AS n_distinct_category,    -- 计数表达式：★ category 之相异取值数
  SUM(CASE WHEN c_raw IS NULL THEN 1 ELSE 0 END)                         AS n_null_category,        -- 条件计数：★ 原值为 NULL 者，须单列
  SUM(CASE WHEN c_raw IS NOT NULL AND TRIM(c_raw) = '' THEN 1 ELSE 0 END) AS n_blank_category,      -- 条件计数：★ 原值为空串者
  SUM(CASE WHEN c = '1' THEN 1 ELSE 0 END)                               AS n_cat_1,                -- 条件计数：category='1' 之行数
  SUM(CASE WHEN c <> '1' AND c IS NOT NULL AND c <> '' THEN 1 ELSE 0 END) AS n_cat_other,           -- 条件计数：★ 其余有值者
  ROUND(SUM(CASE WHEN c = '1' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 8)                                        AS pct_cat_1,              -- 比率表达式：category='1' 之占比
  COUNT(*) - SUM(CASE WHEN c = '1' THEN 1 ELSE 0 END)
           - SUM(CASE WHEN c <> '1' AND c IS NOT NULL AND c <> '' THEN 1 ELSE 0 END)
           - SUM(CASE WHEN c_raw IS NULL THEN 1 ELSE 0 END)
           - SUM(CASE WHEN c_raw IS NOT NULL AND TRIM(c_raw) = '' THEN 1 ELSE 0 END) AS n_unclassified, -- 计算表达式：★★ 穷举锁——须为 0
  CASE                                                                                              -- 条件分支：起始分支——穷举裁定
    WHEN COUNT(*) - SUM(CASE WHEN c = '1' THEN 1 ELSE 0 END)
                  - SUM(CASE WHEN c <> '1' AND c IS NOT NULL AND c <> '' THEN 1 ELSE 0 END)
                  - SUM(CASE WHEN c_raw IS NULL THEN 1 ELSE 0 END)
                  - SUM(CASE WHEN c_raw IS NOT NULL AND TRIM(c_raw) = '' THEN 1 ELSE 0 END) <> 0
      THEN '❌ 穷举不成立 —— 有行未归任一类，分类逻辑有缺口'                                            -- 分支判定：穷举破裂
    WHEN SUM(CASE WHEN c_raw IS NULL THEN 1 ELSE 0 END) > 0
      THEN '★ 存在 NULL category —— 须单列报告，禁并入任一有值组'                                      -- 分支判定：有空值
    ELSE '✅ 穷举成立 ∧ 无空值'                                                                      -- 分支判定：穷举成立
  END                                                                    AS verdict_exhaustive      -- 条件分支：收束上方判词，产出「verdict_exhaustive」
FROM src;                                                                                           -- 取数来源：取自本条自建的中间结果集 src


-- ──────────────────────────────────────────────────────────────────────────
-- §QSB-01c · ★★ category='1' 内之污染探查（本件最要紧之一条）
-- ▸ 导出：需要 —— 存为「审计/_qsb/_QSB_01c_cat1_contamination.csv」。
--   ★ 缘由：canonical 54 处以 category='1' 为准入。
--     **若取消／未结算之单混在其内，则 54 处准入条件皆须复核。**
--   ★ 判读：
--     n_pnl_zero_stake_pos 高  → 疑有 push 或取消单混入（二者形态相同，须再拆）
--     n_b14_null > 0           → ★★ 疑有未结算单混入 —— QSB lineage break
--     n_b13_zero > 0           → 本金为零而列一般单，语义可疑
-- ──────────────────────────────────────────────────────────────────────────
SELECT                                                                                              -- 取列：起始取列子句
  TRIM(bet09)                                                            AS bet09_value,            -- 取列：注型——按注型拆，免整体掩盖局部
  COUNT(*)                                                               AS n_rows,                 -- 计数表达式：该注型于 cat=1 内之行数
  SUM(CASE WHEN NULLIF(TRIM(bet14), '') IS NULL THEN 1 ELSE 0 END)       AS n_b14_null,             -- 条件计数：★★ 派彩为空——未结算之疑
  SUM(CASE WHEN NULLIF(TRIM(bet13), '') IS NULL THEN 1 ELSE 0 END)       AS n_b13_null,             -- 条件计数：本金为空
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_b13_zero, -- 条件计数：本金为零
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0
             AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
               - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) AS n_pnl_zero_stake_pos, -- 条件计数：★ 本金为正而净输赢为零——push／取消同形
  SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
             = CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8))
            AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0 THEN 1 ELSE 0 END) AS n_exact_refund, -- 条件计数：★ 派彩恰等本金——原额退还之形态
  ROUND(SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0
                   AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                     - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 6)                                        AS pct_pnl_zero,           -- 比率表达式：★ 净输赢为零之占比——即 push 率之上界
  ROUND(SUM(CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))), 2)          AS stake_sum,              -- 汇总表达式：本金总额
  CASE                                                                                              -- 条件分支：起始分支——污染裁定
    WHEN SUM(CASE WHEN NULLIF(TRIM(bet14), '') IS NULL THEN 1 ELSE 0 END) > 0
      THEN '❌❌ QSB LINEAGE BREAK —— category=1 内有派彩为空者，疑未结算单混入，54 处准入须复核'        -- 分支判定：未结算混入
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) > 0
      THEN '★ 有本金为零者列为一般单 —— 语义可疑，须查'                                                -- 分支判定：本金为零
    WHEN SUM(CASE WHEN CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8)) > 0
                    AND CAST(NULLIF(TRIM(bet13), '') AS DECIMAL(20,8))
                      - CAST(NULLIF(TRIM(bet14), '') AS DECIMAL(20,8)) = 0 THEN 1 ELSE 0 END) > 0
      THEN '◐ 有净输赢为零者 —— 系 push 抑或取消单，二者同形，须再拆（★ 本件答不了）'                     -- 分支判定：有零输赢
    ELSE '✅ 本注型内无上述三疑'                                                                      -- 分支判定：无疑
  END                                                                    AS verdict_contamination   -- 条件分支：收束上方判词，产出「verdict_contamination」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单主表
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定分析窗
  AND CAST(bet02 AS STRING) = '101'                                                                 -- 并列条件：限定百家乐
  AND TRIM(category) = '1'                                                                          -- 并列条件：★ 只看 category='1' 之内部
GROUP BY TRIM(bet09)                                                                                -- 分组：按注型汇总
ORDER BY n_b14_null DESC, n_pnl_zero_stake_pos DESC, n_rows DESC;                                    -- 排序：可疑者置顶；导出必带排序


-- ══════════════════════════════════════════════════════════════════════════
-- 判读总纲（本件之三条锁）
-- ══════════════════════════════════════════════════════════════════════════
-- 锁四十三 · 事实边界先于定义选择。
--   category 系事实边界（值有哪些、各是什么），push 系定义选择（三契约择一）。
--   ★ 事实边界未钉死而先选 push 契约，即把设计建在可能错误之 qualifying universe 上。
--   → 故本件先行；push 三候选（WR-A／WR-B／WR-C）**只登记，不选边**。
--
-- 锁四十四 · GROUP BY 只答「有哪些值」，不答「是什么意思」。
--   须并出形态：pnl 三态、payout 空零正、validbet 零、时间跨度、会员数、注型数。
--   ★ 形态只作**线索**，语义仍须上游确认——**禁以形态定谳**。
--
-- 锁四十五 · push 与取消单**同形不同源**。
--   二者皆现「本金为正 ∧ 净输赢为零」，§QSB-01c 之 n_pnl_zero_stake_pos 兼含二者。
--   ★ **本件答不了二者之别**——须另取判别字段。故该列只作**上界**，
--     即「push 率 ≤ pct_pnl_zero」，非「push 率 ＝ pct_pnl_zero」。
--
-- ★ 若 §QSB-01c 现 n_b14_null > 0，即触发 **QSB LINEAGE BREAK**：
--   不止 win_rate 须改，**canonical 现有 54 处 category='1' 准入条件皆须复核**。
--
-- 工具态：WORKING · A2 · canonical = false
-- 总包 canonical 仍 v11.0.3（REL-0005 / C1 / IMMUTABLE），本件不触其一字。
-- ══════════════════════════════════════════════════════════════════════════
