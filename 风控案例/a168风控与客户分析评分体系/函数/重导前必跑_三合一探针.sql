-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ 重导前必跑 · 秒级 · 三合一探针（S1 扇出风险 ＋ 零成本提速前置 ＋ 类型确认）· 只读 ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【为何必须先跑】HF9g-P1 之 #075 的 x_bs0 只【标记】测试线（f_testline），并【不剔除】该等行：
--     LEFT JOIN x_testagent t1..t5 ON t?.agent_id = b.bet18..bet22
--     CASE WHEN COALESCE(t1..t5.agent_id) IS NOT NULL THEN 1 ELSE 0 END AS f_testline
--     WHERE b.x_rn = 1 AND b.category='1' AND UPPER(TRIM(b.bet38))='N' AND 汇率>0      ← 无 IS NULL 剔除
--   而 x_testagent 之定义【无 DISTINCT】：SELECT age001 AS agent_id FROM ods_a168_agent WHERE age022='1'
--   同源同谓词之另一写法 ta 却【有 DISTINCT】：SELECT DISTINCT age001 AS aid FROM …WHERE age022='1'
--   全包实测：无 DISTINCT 者 134 处、被 LEFT JOIN 640 次；有 DISTINCT 者 24 处、被 LEFT JOIN 130 次。
--   ⇒ 若 age001 在 age022='1' 子集内【不唯一】，则五路 LEFT JOIN 会令注单行【扇出】，
--     且因本处不剔除、只标记，扇出行【存活至 x_mk → x_agg】，令 n_bets / stake / valid_bet 等全线虚增。
--   ⇒ 此为 S1 级正确性风险。重导前必须证死，不得以「以往跑得出来」代替证明。
-- 【本探针只读、不建表、不写数、不改任何档；三段各回一行】

-- ── 段一：age001 在测试线子集内是否唯一（决定有无扇出）──
SELECT                                                                                              -- 取列：起始取列子句
  'PROBE-1 测试线代理唯一性' AS probe_id,                                                             -- 字面取值：探针编号
  COUNT(*)                                        AS n_rows_testline,                               -- 计数表达式：age022='1' 之总行数
  COUNT(DISTINCT a.age001)                        AS n_distinct_age001,                             -- 计数表达式：其相异 age001 个数
  COUNT(*) - COUNT(DISTINCT a.age001)             AS n_surplus,                                     -- 数值取值：★ 差值 —— 非零即存在重复，扇出风险成立
  SUM(CASE WHEN a.age001 IS NULL OR TRIM(CAST(a.age001 AS STRING)) = '' THEN 1 ELSE 0 END)          -- 聚合取值：起始 —— 空值计数
                                                  AS n_null_age001,                                 -- 聚合取值：空 age001 行数（空值不参与等值连接，但须知其量）
  CASE WHEN COUNT(*) = COUNT(DISTINCT a.age001) THEN 'PASS_NO_FANOUT_RISK'                          -- 条件分支：起始分支 —— 唯一即无扇出
       ELSE 'FAIL_FANOUT_RISK_CONFIRMED' END      AS verdict                                        -- 条件分支：收束判词
FROM ods_mariadb_2b.ods_a168_agent a                                                                -- 取数来源：代理主档
WHERE a.age022 = '1';                                                                               -- 过滤条件：测试线标记，与 x_testagent 逐字同一

-- ── 段二：若段一 FAIL，量化窗内实际被扇出之注单行数（PASS 时本段回 0）──
WITH dup AS (                                                                                       -- 定义 CTE：起始 —— 重复之测试线代理号及其重数
  SELECT a.age001 AS agent_id, COUNT(*) AS c                                                        -- 取列：代理号与其行数
  FROM ods_mariadb_2b.ods_a168_agent a                                                              -- 取数来源：代理主档
  WHERE a.age022 = '1'                                                                              -- 过滤条件：测试线
  GROUP BY a.age001                                                                                 -- 分组子句：按代理号
  HAVING COUNT(*) > 1                                                                               -- 分组后过滤：只留重复者
),                                                                                                  -- 定义 CTE：收束 dup
win AS (                                                                                            -- 定义 CTE：起始 —— 窗内去重后之注单，与 #075 之 x_ranked 同谓词
  SELECT b.bet01, b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                      -- 直接取列：主键与五级代理线
         ROW_NUMBER() OVER (PARTITION BY b.bet01                                                    -- 行号窗口表达式：以行号窗口取每组头部，免出重复行
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS x_rn                         -- 排序键：取最新一版
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：注单事实表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：分析窗
    AND b.bet02 = '101'                                                                             -- 过滤条件：百家乐域
    AND b.sync_time <= '2026-08-27 09:00:00'                                                        -- 过滤条件：快照水位
)                                                                                                    -- 定义 CTE：收束 win
SELECT                                                                                              -- 取列：起始取列子句
  'PROBE-2 窗内扇出量化' AS probe_id,                                                                 -- 字面取值：探针编号
  COUNT(*)                                        AS n_bets_dedup,                                  -- 计数表达式：去重后注单行数（应为 #075 之 x_bs0 输入量）
  SUM(COALESCE(d1.c,1) * COALESCE(d2.c,1) * COALESCE(d3.c,1)                                        -- 聚合取值：起始 —— 五路连接之乘积即该行扇出后之行数
      * COALESCE(d4.c,1) * COALESCE(d5.c,1))      AS n_rows_after_fanout,                           -- 聚合取值：扇出后总行数；等于上者即无扇出
  SUM(COALESCE(d1.c,1) * COALESCE(d2.c,1) * COALESCE(d3.c,1)                                        -- 聚合取值：起始 —— 差额
      * COALESCE(d4.c,1) * COALESCE(d5.c,1)) - COUNT(*) AS n_extra_rows,                            -- 聚合取值：★ 虚增行数；非零即证聚合被污染
  CASE WHEN SUM(COALESCE(d1.c,1) * COALESCE(d2.c,1) * COALESCE(d3.c,1)                              -- 条件分支：起始分支
                * COALESCE(d4.c,1) * COALESCE(d5.c,1)) = COUNT(*)                                   -- 分支判定：无虚增
       THEN 'PASS_NO_ACTUAL_FANOUT' ELSE 'FAIL_AGGREGATES_INFLATED' END AS verdict                   -- 条件分支：收束判词
FROM win w                                                                                          -- 取数来源：窗内去重注单
LEFT JOIN dup d1 ON d1.agent_id = w.bet18                                                           -- 左连接：一级代理线是否命中重复测试线代理
LEFT JOIN dup d2 ON d2.agent_id = w.bet19                                                           -- 左连接：二级
LEFT JOIN dup d3 ON d3.agent_id = w.bet20                                                           -- 左连接：三级
LEFT JOIN dup d4 ON d4.agent_id = w.bet21                                                           -- 左连接：四级
LEFT JOIN dup d5 ON d5.agent_id = w.bet22                                                           -- 左连接：五级
WHERE w.x_rn = 1;                                                                                   -- 过滤条件：仅取每注单最新一版

-- ── 段三：连接键之实际型别（决定 CAST 是否为恒等、可否安全省去）──
SELECT                                                                                              -- 取列：起始取列子句
  'PROBE-3 连接键型别' AS probe_id,                                                                   -- 字面取值：探针编号
  c.TABLE_NAME                                    AS table_name,                                    -- 直接取列：表名
  c.COLUMN_NAME                                   AS column_name,                                   -- 直接取列：列名
  c.DATA_TYPE                                     AS data_type,                                     -- 直接取列：型别
  c.CHARACTER_MAXIMUM_LENGTH                      AS max_len                                        -- 直接取列：字符长度
FROM information_schema.columns c                                                                   -- 取数来源：信息架构
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：本库
  AND ((c.TABLE_NAME = 'ods_a168_bet02' AND c.COLUMN_NAME IN ('bet05','bet18','bet19','bet20','bet21','bet22','bet02'))  -- 并列条件：注单侧连接键
    OR (c.TABLE_NAME = 'ods_a168_agent' AND c.COLUMN_NAME IN ('age001','age022')))                  -- 并列条件：代理侧连接键
ORDER BY c.TABLE_NAME, c.COLUMN_NAME;                                                               -- 排序子句：便于比对

-- ── §四、判读 ──
--   段一 PASS_NO_FANOUT_RISK ＋ 段二 PASS_NO_ACTUAL_FANOUT ⇒ 现有聚合未被污染，可放心重导；
--     且此时给 x_testagent 补 DISTINCT 属【输出逐位不变】之纯提速（缩小 640 处 hash join 之探测侧）。
--   段一 FAIL 或 段二 FAIL ⇒ 【立即停止重导】。历次交付件之 n_bets / stake / valid_bet 全线虚增，
--     须先补 DISTINCT，再全量重跑，并将既往台账锚标记为受污染、重新登记。
--   段三：若 bet05/bet18..22/age001 皆为 varchar，则 CAST(x AS STRING) 为恒等运算，
--     可议是否省去以利运行时过滤下推；若型别不一，则 CAST 必须保留（自家铁律）。
