-- ═════════════════════════════════════════════════════════════════════════
-- a168 取数与核验 SQL 总包 · v10 斧正补丁（局部件 · 非第四权威文档 · 非全包）
-- 作者：Ryo Eng（黄联富）
-- 日期：2026-08-20
-- ─────────────────────────────────────────────────────────────────────────
-- 【范围声明 · 未见即未审】
--   本补丁仅承载本次会话 OBSERVED 的两段：§R01、§P11c，另附新增核验断言
--   §R01-chk1、§P11c-chk1。v9 全包其余段落本会话未提供，评级 UNKNOWN，
--   不在本补丁承诺范围——「其它函数逐一斧正」须待 v9 全文到场后逐段执行。
-- 【拼装指引】
--   以 v9 全包为底，整段替换 §R01 与 §P11c，追加两段 chk，其余维持 v9 原文；
--   拼装后另存「a168_取数与核验_SQL总包_v10.sql」，旧件改名加 _superseded，
--   并登记六元组（文件名＋行数＋字节数＋MD5＋行尾＋编码）。
-- 【v10 变更清单（Changelog · 过程叙事仅居此处）】
--   R01-F1（S2）：三处块注释（base 内 StarRocks 说明、shoe_len 命名警示、
--                文末阈值说明）改写为双横杠行注释；铁律：全包禁「斜杠星号」块注释。
--   R01-F2（S3）：stake_early_avg 与 stake_ramp 两行错贴之 GGR 注释重写为
--                与表达式相符的正文；注释与代码不符同属审计红线。
--   R01-F4（S4）：HAVING COUNT(*)>=100 补定性——工程阈值，非统计功效阈值。
--   P11c-F1（S3）：七闸行级守卫上移至 gated，双域共同继承；阿泽域自此为
--                全量洁净域的严格子集，ratio_pct 分子分母同净化标准。
--                ⚠ 数值将变：导出件须重跑，CSV 契约名不变、内容版本随 v10。
--   P11c-F2（S3）：rebate41_sum 列名暂保（下游契约），行内注明已锁结论
--                bet41≡validbet（洗码量，非返水），并由 §P11c-chk1 恒等式
--                断言裁决；断言若不通过，锁定结论与本件必有一处须修。
--   P11c-F3（S3）：补 SQL 原生口径锁列 late_def（阿泽域 rno>=40_absolute_v1，
--                全量域 na_full_domain），下游可自数据分辨口径。
--   P11c-F4（S4）：n_orders_pct、n_members_pct、stake_pct、validbet_pct、
--                ggr_pct 分母补齐 NULLIF 除零守卫，L2 清单全覆盖。
-- 【三条永久锁定语句照录】
--   一、证据等级不因重算自动升级。
--   二、统计显著 ≠ 因果有效 ≠ 风控正确 ≠ 经济价值。
--   三、任何「世界级标准」自身亦受红队审计——标准不豁免于标准。
-- ═════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- §R01 · 靴末段下注全量会员面板（v10 勘正版）
-- ▸ 导出：需要 —— 存为「数据库/R01_late_shoe.csv」（§R01 靴末段下注）。
-- ▸ 定性：全量合格会员面板（不做行为筛选），非命中名单、非风控名单；
--   靴末假设已四检验证伪（符号 p=0.7591、Wilcoxon p=0.8087、九档 hold%
--   零命中、外部标签 AUC=0.3828 方向反转），本面板身份＝活跃分层基线
--   ＋营收集中度底料＋证伪档案。
-- ─────────────────────────────────────────────────────────────────────────
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§R01）
  SELECT age001 AS agent_id                                                                         -- 取列：产出「agent_id」
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档（五级代理线归属来源）
  WHERE age022 = '1'                                  -- 铁律④b：公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
ranked AS (                                            -- 需求 §3.2：同单号保留最新版本
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet11, b.bet13,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet11, b.bet13，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet14, b.bet18, b.bet19, b.bet20, b.bet21,                                               -- 续行：接续上一取列子句，续列 b.bet14, b.bet18, b.bet19, b.bet20, b.bet21，涉 bet14（派彩金额）、bet18（一级代理线）、bet19（二级代理线）
         b.bet22, b.bet38, b.bet39, b.category,                                                     -- 续行：接续上一取列子句，续列 b.bet22, b.bet38, b.bet39, b.category，涉 bet22（五级代理线）、bet38（测试标识）、bet39（桌号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                 -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R01）
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id,                                                   -- 取列：起始取列子句，本行先取「member_id」，涉 bet05（会员号）、member_id（会员号）
         r.bet03 AS shoe_id, r.bet39 AS table_id,                                                   -- 取值表达式：取用 bet03（靴号）、bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「round_no」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  -- StarRocks 不支持 EXISTS + 多列 IN，测试线剔除改五路 LEFT JOIN（v10：原块注释改行注释，内容原样）
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1                                                                                    -- 过滤条件：限定 r.rn等于 1
    AND r.category = '1'                                                                            -- 并列条件：限定 r.category等于 '1'
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：限定 UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0                                                   -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet04),'') AS INT)大于 0，涉 bet04（局内序号）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
shoe_len AS (                                                                                       -- 公共表表达式：开启中间结果集 shoe_len，其后各行为其定义体（§R01）
  -- ★ 命名警示（v10：原块注释改行注释，内容原样）：本 CTE 名为 shoe_len（靴长）系历史沿用，
  --   其所算 max_round = MAX(round_no) 为『该靴该桌观测到的最大局号』，非 COUNT(round_no) 之局数；
  --   二者仅在局号自 1 起连续无缺口时相等。选 MAX 为刻意设计：对中间缺口免疫，
  --   COUNT 会因清洗剔单而使分母缩水。
  -- ★ B-01 斧正（2026-08-12）：定标基准逐靴现算，绝对局号不是固定靴位。
  --   缺陷一修正：定标基准不定，固定 50 不是固定位置。
  SELECT shoe_id, table_id, MAX(round_no) AS max_round                                              -- 取列：取最大局号（≠COUNT 局数），产出「max_round」
  FROM base GROUP BY shoe_id, table_id                                                              -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
enriched AS (                                                                                       -- 公共表表达式：开启中间结果集 enriched，其后各行为其定义体（§R01）
  SELECT b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round,                               -- 取列：起始取列子句，本行先列 b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round，涉 member_id（会员号）
         b.round_no * 1.0 / NULLIF(s.max_round,0)     AS shoe_pos,                                  -- 取值表达式：产出「shoe_pos」
         b.stake_raw / b.fx                           AS stake,                                     -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (b.payout_raw - b.stake_raw) / b.fx          AS game_pnl,                                  -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         CASE WHEN b.round_no * 1.0 / NULLIF(s.max_round,0) >= 0.80
              THEN 1 ELSE 0 END                        AS is_late   -- B-01 斧正：相对靴位                                    -- 条件分支：产出「is_late」
  FROM base b                                                                                       -- 取数来源：取自本条自建的中间结果集 base
  JOIN shoe_len s ON s.shoe_id = b.shoe_id AND s.table_id = b.table_id                              -- 连接：取自本条自建的中间结果集 shoe_len，连接键为 s.shoe_id = b.shoe_id AND s.table_id = b.table_id
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R01）
SELECT                                                                                              -- 主查询：面板逐会员汇总输出
  member_id                                                     AS uid,                             -- 取值表达式：取用 member_id（会员号）、uid（会员号），产出「uid」
  COUNT(*)                                                      AS n_orders_all,                    -- 计数表达式：产出「n_orders_all」
  SUM(is_late)                                                  AS n_orders_late,                   -- 汇总表达式：产出「n_orders_late」
  'shoe_pos>=0.80'                                              AS late_def,        -- 口径锁：definition_version = v2
  SUM(is_late) * 1.0 / COUNT(*)                                 AS late_share,                      -- 汇总表达式：计数，取用 late_share（晚注占比），产出「late_share」
  PERCENTILE_APPROX(CASE WHEN is_late=1 THEN shoe_pos END, 0.5) AS shoe_pos_p50,                    -- 取近似分位数表达式：产出「shoe_pos_p50」
  SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0)              AS stake_late_avg,  -- 汇总表达式：晚段均注——is_late=1 注单的注额均值（原币经汇率归一化），产出「stake_late_avg」
  SUM(CASE WHEN is_late=0 THEN stake END) / NULLIF(COUNT(*)-SUM(is_late),0)     AS stake_early_avg, -- 汇总表达式：早段均注——is_late=0 注单的注额均值；v10-F2 勘正：原错贴 GGR 取负注释，与表达式不符，已重写
  (SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0))                                -- 续行：分子＝晚段均注
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END)                                                -- 除法：分母＝早段均注
             / NULLIF(COUNT(*)-SUM(is_late),0), 0)                              AS stake_ramp,      -- 除法：晚/早段均注比（注额加速比，>1 即晚段加注）；v10-F2 勘正：原错贴 GGR 取负注释，已重写
  SUM(CASE WHEN is_late=1 THEN game_pnl END)                                                        -- 汇总表达式：取用 game_pnl（游戏净输赢）
    / NULLIF(SUM(CASE WHEN is_late=1 THEN stake END),0)                         AS roi_late,        -- 除法或乘法计算：汇总，取用 stake（下注额（经汇率归一化）），产出「roi_late」
  SUM(CASE WHEN is_late=0 THEN game_pnl END)                                                        -- 汇总表达式：取用 game_pnl（游戏净输赢）
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END),0)                         AS roi_early,       -- 除法或乘法计算：汇总，取用 stake（下注额（经汇率归一化）），产出「roi_early」
  SUM(CASE WHEN is_late=1 THEN stake END)                                       AS stake_late,      -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_late」
  SUM(CASE WHEN is_late=1 THEN game_pnl END)                                    AS game_pnl_late,   -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl_late」
  SUM(stake)                                                                    AS stake_all,       -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_all」
  SUM(game_pnl)                                                                 AS game_pnl_all     -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl_all」
FROM enriched                                                                                       -- 取数来源：取自本条自建的中间结果集 enriched
GROUP BY member_id                                                                                  -- 分组：按 member_id 汇总
HAVING COUNT(*) >= 100                                    -- 需求：洁净结算单累计满 100 局起；v10-F4 定性：100 为工程阈值（控行数、保对照组），非统计功效阈值——任何推断性使用须按 n_min = f(p0, α, h, ρ, deff) 反推另证
ORDER BY late_share DESC, n_orders_late DESC;                                                       -- 排序：按 late_share（降序）, n_orders_late（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- ⚠️ 注意（v10：原文末块注释改行注释，内容原样）：此处**故意不加** late_share >= 0.70 的 HAVING。
--    报告需要「命中组 vs 对照组」的 hold% 对照才能做经济裁定（@sec-r01 的 r01-decision），
--    只导命中组就没有对照组。阈值筛选一律放在 R 侧做，SQL 只负责给全量底料。
--    若行数过大，改为 HAVING COUNT(*) >= 300 提高活跃度门槛，而不是加 late_share 条件。


-- ─────────────────────────────────────────────────────────────────────────
-- §R01-chk1 · 靴长分布核验（新增，支撑绝对局号语义之实证；独立整句，单独执行）
-- ▸ 导出：可选 —— 存为「数据库/R01_chk1_max_round_dist.csv」
-- ▸ 用途：为「rno>=40 绝对口径」（P11c 历史丙版）与「shoe_pos>=0.80 相对口径」
--   （R01 现行 v2）提供靴长实证底数；bet04 取单不取键（三字段局键铁律照旧），
--   此处仅测分布，不作局键用途。
-- ─────────────────────────────────────────────────────────────────────────
WITH test_agents AS (                                                                               -- 公共表表达式：测试线代理名单（与 §R01 同源同构）
  SELECT age001 AS agent_id                                                                         -- 取列：产出「agent_id」
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：代理主档
  WHERE age022 = '1'                                                                                -- 铁律④b：公司测试线
),                                                                                                  -- 续行：收束子查询括号
ranked AS (                                                                                         -- 同单号保留最新版本（与 §R01 同构）
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet38, b.bet39, b.category,                 -- 取列：核验所需最小列集
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：五级代理线
         ROW_NUMBER() OVER (PARTITION BY b.bet01                                                    -- 行号窗口：按单号去重
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：最新版本置首
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：窗口与 §R01 完全一致
    AND b.bet02 = '101'                                                                             -- 并列条件：百家乐
),                                                                                                  -- 续行：收束子查询括号
base AS (                                                                                           -- 洁净行域（与 §R01 base 同闸）
  SELECT r.bet03 AS shoe_id, r.bet39 AS table_id,                                                   -- 取列：靴号、桌号
         CAST(NULLIF(TRIM(r.bet04),'') AS INT) AS round_no                                          -- 取值表达式：局内序号强类型化
  FROM ranked r                                                                                     -- 取数来源：中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：一级代理线
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：二级代理线
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：三级代理线
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：四级代理线
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：五级代理线
  WHERE r.rn = 1                                                                                    -- 过滤条件：仅最新版本
    AND r.category = '1'                                                                            -- 并列条件：已结算
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：非测试单
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：会员号守卫
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：汇率守卫
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0                                                   -- 并列条件：局号守卫
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：五级全联剔测试线
),                                                                                                  -- 续行：收束子查询括号
shoe_len AS (                                                                                       -- 逐靴逐桌最大局号（与 §R01 shoe_len 同构；MAX 非 COUNT，理由见 §R01 警示）
  SELECT shoe_id, table_id, MAX(round_no) AS max_round                                              -- 取列：产出「max_round」
  FROM base GROUP BY shoe_id, table_id                                                              -- 分组：按（靴号,桌号）
)                                                                                                   -- 续行：收束子查询括号
SELECT                                                                                              -- 主查询：靴长分布十项摘要
  COUNT(*)                                        AS n_shoes,                                       -- 计数表达式：靴桌组合总数
  MIN(max_round)                                  AS min_len,                                       -- 汇总表达式：最短观测靴长
  PERCENTILE_APPROX(max_round, 0.05)              AS p05_len,                                       -- 取近似分位数表达式：5% 分位
  PERCENTILE_APPROX(max_round, 0.25)              AS p25_len,                                       -- 取近似分位数表达式：25% 分位
  PERCENTILE_APPROX(max_round, 0.50)              AS p50_len,                                       -- 取近似分位数表达式：中位数
  PERCENTILE_APPROX(max_round, 0.75)              AS p75_len,                                       -- 取近似分位数表达式：75% 分位
  PERCENTILE_APPROX(max_round, 0.95)              AS p95_len,                                       -- 取近似分位数表达式：95% 分位
  MAX(max_round)                                  AS max_len,                                       -- 汇总表达式：最长观测靴长
  AVG(max_round * 1.0)                            AS mean_len,                                      -- 汇总表达式：均值
  SUM(CASE WHEN max_round < 40 THEN 1 ELSE 0 END) AS n_shoes_lt40                                   -- 汇总表达式：靴长不足 40 之靴数——此数>0 即证明绝对口径 rno>=40 会整靴漏判，佐证 B-01 相对靴位之必要
FROM shoe_len;                                                                                      -- 取数来源：中间结果集 shoe_len


-- ─────────────────────────────────────────────────────────────────────────
-- §P11c · 阿泽域与全量洁净两域十一项总帐（v10 勘正版）
-- ▸ 导出：需要 —— 存为「数据库/P11_阿泽尾段投注总帐.csv」（契约名，不英译）
-- ▸ 读法：各 *_pct 列即「阿泽（占比）」＝ 阿泽域 ÷ 全量洁净；代理五级为 distinct，不可加
-- ▸ v10-F1 语义变更告示：七闸行级守卫上移至 gated，双域共同继承，阿泽域
--   自此为全量洁净域之严格子集；丙版会员门槛逻辑（累计满 30 局起 ×
--   rno>=40 占比>=0.60）原样保留——变的是行卫生对齐，不是丙版定义本身。
--   历史丙版（闸门不对称版）数值以 v9 导出件存档为准，本版重跑后 CSV
--   内容版本随 v10，契约名不变。
-- ─────────────────────────────────────────────────────────────────────────
WITH test_agents AS (                                                                               -- 公共表表达式：测试线代理名单
    SELECT age001 AS agent_id                                                                       -- 取列：产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：代理主档
    WHERE age022 = '1'                                                                              -- 铁律④b：公司测试线
),                                                                                                  -- 续行：收束子查询括号
ranked AS (                                                                                         -- 同单号保留最新版本
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet08, b.bet11, b.bet13, b.bet14,                  -- 取列：总帐所需列集
           b.bet16, b.bet41, b.validbet,                                                            -- 续行：返水（bet16）、洗码相关（bet41、validbet）
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet38, b.category,                        -- 续行：五级代理线、测试标识、结算类别
           ROW_NUMBER() OVER (                                                                      -- 行号窗口表达式：按单号去重
             PARTITION BY b.bet01                                                                   -- 窗口分区：按 b.bet01 分组开窗
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：最新版本置首；导出必带排序
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- ★ 表名开关
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：窗口与 §R01 完全一致
),                                                                                                  -- 续行：收束子查询括号
gated AS (                                                                                          -- 洁净行域：v10-F1 七闸行级守卫上移至此，双域共同继承
    SELECT r.bet03, r.bet04, r.bet05, r.bet08, r.bet11, r.bet13, r.bet14,                           -- 取列：透传总帐所需列
           r.bet16, r.bet41, r.validbet,                                                            -- 续行：返水与洗码相关列
           r.bet18 AS a1, r.bet19 AS a2, r.bet20 AS a3, r.bet21 AS a4, r.bet22 AS a5                -- 取值表达式：五级代理线别名 a1..a5
    FROM ranked r                                                                                   -- 取数来源：中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左连接：一级代理线
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左连接：二级代理线
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左连接：三级代理线
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左连接：四级代理线
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左连接：五级代理线
    WHERE r.rn = 1                                                                                  -- 过滤条件：仅最新版本
      AND r.category = '1'                                                                          -- 并列条件：已结算
      AND UPPER(TRIM(r.bet38)) = 'N'                                                                -- 并列条件：非测试单
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                           -- 并列条件：五级全联剔测试线——
                   t4.agent_id, t5.agent_id) IS NULL                                                -- 续行：任一级命中即整单剔除
      AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                              -- 并列条件（v10-F1 上移）：会员号守卫
      AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                       -- 并列条件（v10-F1 上移）：汇率守卫
      AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0                                                 -- 并列条件（v10-F1 上移）：局号守卫
      AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                      -- 并列条件（v10-F1 上移）：下注时间非空守卫
),                                                                                                  -- 续行：收束子查询括号
rows_norm AS (                                                                                      -- 统一行级归一化：双域共用同一净化与汇率折算（v10-F1 核心）
    SELECT CAST(NULLIF(TRIM(bet05),'') AS BIGINT)                            AS pid,                -- 取值表达式：会员号强类型化，产出「pid」
           CAST(NULLIF(TRIM(bet04),'') AS INT)                               AS rno,                -- 取值表达式：局内序号强类型化，产出「rno」
           a1, a2, a3, a4, a5,                                                                      -- 取列：五级代理线透传
           CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：注额原币
             / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))                 AS stake,              -- 除法：经汇率归一化，产出「stake」；分母>0 已由 gated 守卫保证
           CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：洗码量原币（validbet ≡ bet02.bet41，已锁）
             / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))                 AS vb,                 -- 除法：经汇率归一化，产出「vb」
           (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))                                           -- 取值表达式：派彩原币
             - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))                                       -- 续行：减注额＝会员净输赢
             / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))                 AS pnl,                -- 除法：经汇率归一化，产出「pnl」
           COALESCE(CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)), 0)                               -- 取值表达式：真返水（bet16，恒等式已 100% 验证）
             / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))                 AS reb16,              -- 除法：经汇率归一化，产出「reb16」
           COALESCE(CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)), 0)                               -- 取值表达式：bet41——已锁结论 bet41≡validbet（洗码量，非返水）
             / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))                 AS reb41               -- 除法：产出「reb41」；列名暂保下游契约，语义见 v10-F2 告示与 §P11c-chk1 断言
    FROM gated                                                                                      -- 取数来源：中间结果集 gated
),                                                                                                  -- 续行：收束子查询括号
aze_members AS (                                                                                    -- 丙版会员门槛：定义原样保留（v10 不动丙版逻辑，仅行卫生对齐）
    SELECT pid                                                                                      -- 取列：会员号
    FROM rows_norm                                                                                  -- 取数来源：统一归一化行域
    GROUP BY pid                                                                                    -- 分组：按会员
    HAVING COUNT(*) >= 30                                                                           -- 门槛一：洁净注单累计满 30 局起（丙版工程阈值，非统计功效阈值）
       AND SUM(CASE WHEN rno >= 40 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.60                      -- 门槛二：绝对局号>=40 占比>=0.60（丙版历史口径；现行为 §R01 相对靴位 v2，见 late_def 锁列）
),                                                                                                  -- 续行：收束子查询括号
aze AS (                                                                                            -- 阿泽域汇总（丙版五闸＋会员门槛，行域已对齐七闸）
    SELECT '2_阿泽域（丙版会员门槛·行域七闸对齐v10）' AS scope_def,                                  -- 取值表达式：域定义标签
           'rno>=40_absolute_v1'                      AS late_def,                                  -- 口径锁（v10-F3 新增）：丙版绝对口径，SQL 原生
           COUNT(*)                                   AS n_orders,                                  -- 计数表达式：注单数
           COUNT(DISTINCT r.pid)                      AS n_members,                                 -- 计数表达式：会员数
           COUNT(DISTINCT r.a1)                       AS n_lv1,                                     -- 计数表达式：一级代理数（distinct，不可加）
           COUNT(DISTINCT r.a2)                       AS n_lv2,                                     -- 计数表达式：二级代理数
           COUNT(DISTINCT r.a3)                       AS n_lv3,                                     -- 计数表达式：三级代理数
           COUNT(DISTINCT r.a4)                       AS n_lv4,                                     -- 计数表达式：四级代理数
           COUNT(DISTINCT r.a5)                       AS n_lv5,                                     -- 计数表达式：五级代理数
           SUM(r.stake)                               AS stake_sum,                                 -- 汇总表达式：注额合计
           SUM(r.vb)                                  AS validbet_sum,                              -- 汇总表达式：洗码量合计
           -SUM(r.pnl)                                AS ggr_sum,                                   -- 汇总表达式：会员净输赢取负即平台毛利（GGR）——此注释归属此行，恰如其分
           SUM(r.reb16)                               AS rebate16_sum,                              -- 汇总表达式：真返水合计
           SUM(r.reb41)                               AS rebate41_sum                               -- 汇总表达式：bet41 合计（语义＝洗码量，见 v10-F2 告示）
    FROM rows_norm r                                                                                -- 取数来源：统一归一化行域
    JOIN aze_members m ON m.pid = r.pid                                                             -- 连接：仅保留达门槛会员
),                                                                                                  -- 续行：收束子查询括号
clean AS (                                                                                          -- 全量洁净域汇总（七闸）
    SELECT '1_全量洁净（七闸）'                       AS scope_def,                                  -- 取值表达式：域定义标签
           'na_full_domain'                           AS late_def,                                  -- 口径锁（v10-F3 新增）：全域无晚注口径，显式标注
           COUNT(*)                                   AS n_orders,                                  -- 计数表达式：注单数
           COUNT(DISTINCT pid)                        AS n_members,                                 -- 计数表达式：会员数
           COUNT(DISTINCT a1)                         AS n_lv1,                                     -- 计数表达式：一级代理数
           COUNT(DISTINCT a2)                         AS n_lv2,                                     -- 计数表达式：二级代理数
           COUNT(DISTINCT a3)                         AS n_lv3,                                     -- 计数表达式：三级代理数
           COUNT(DISTINCT a4)                         AS n_lv4,                                     -- 计数表达式：四级代理数
           COUNT(DISTINCT a5)                         AS n_lv5,                                     -- 计数表达式：五级代理数
           SUM(stake)                                 AS stake_sum,                                 -- 汇总表达式：注额合计
           SUM(vb)                                    AS validbet_sum,                              -- 汇总表达式：洗码量合计
           -SUM(pnl)                                  AS ggr_sum,                                   -- 汇总表达式：会员净输赢取负即平台毛利（GGR）
           SUM(reb16)                                 AS rebate16_sum,                              -- 汇总表达式：真返水合计
           SUM(reb41)                                 AS rebate41_sum                               -- 汇总表达式：bet41 合计（语义＝洗码量）
    FROM rows_norm                                                                                  -- 取数来源：统一归一化行域
),                                                                                                  -- 续行：收束子查询括号
both AS (                                                                                           -- 双域并列
    SELECT * FROM clean                                                                             -- 取数来源：全量洁净域
    UNION ALL                                                                                       -- 并集：不去重（两域标签互异）
    SELECT * FROM aze                                                                               -- 取数来源：阿泽域
)                                                                                                   -- 续行：收束子查询括号
SELECT                                                                                              -- 主查询：十一项总帐输出
    b.scope_def,                                                                                    -- 取列：域定义标签
    b.late_def,                                                                                     -- 取列：口径锁（v10-F3）
    b.n_orders,                                                                                     -- 取列：注单数
    ROUND(b.n_orders   * 100.0 / NULLIF(c.n_orders,   0), 4)      AS n_orders_pct,                  -- 除法：注单占比；v10-F4 补 NULLIF 守卫
    b.n_members,                                                                                    -- 取列：会员数
    ROUND(b.n_members  * 100.0 / NULLIF(c.n_members,  0), 4)      AS n_members_pct,                 -- 除法：会员占比；v10-F4 补 NULLIF 守卫
    b.n_lv1, b.n_lv2, b.n_lv3, b.n_lv4, b.n_lv5,                                                    -- 取列：五级代理 distinct 数（不可加）
    ROUND(b.stake_sum, 2)                                          AS stake_sum,                    -- 取值表达式：注额合计（两位小数）
    ROUND(b.stake_sum    * 100.0 / NULLIF(c.stake_sum,    0), 4)   AS stake_pct,                    -- 除法：注额占比；v10-F4 补 NULLIF 守卫
    ROUND(b.validbet_sum, 2)                                       AS validbet_sum,                 -- 取值表达式：洗码量合计
    ROUND(b.validbet_sum * 100.0 / NULLIF(c.validbet_sum, 0), 4)   AS validbet_pct,                 -- 除法：洗码量占比；v10-F4 补 NULLIF 守卫
    ROUND(b.ggr_sum, 2)                                            AS ggr_sum,                      -- 取值表达式：GGR 合计
    ROUND(b.ggr_sum      * 100.0 / NULLIF(c.ggr_sum,      0), 4)   AS ggr_pct,                      -- 除法：GGR 占比；v10-F4 补 NULLIF 守卫
    ROUND(b.rebate16_sum, 2)                                       AS rebate16_sum,                 -- 取值表达式：真返水合计
    ROUND(b.rebate16_sum * 100.0 / NULLIF(c.rebate16_sum, 0), 4)   AS rebate16_pct,                 -- 除法：返水占比（原有守卫保留）
    ROUND(b.rebate41_sum, 2)                                       AS rebate41_sum,                 -- 取值表达式：bet41 合计（语义＝洗码量，v10-F2）
    ROUND(b.ggr_sum - b.rebate16_sum, 2)                           AS ngr_by16,                     -- 取值表达式：NGR＝GGR−真返水（仅扣 bet16，与锁定结论一致）
    ROUND((b.ggr_sum - b.rebate16_sum) * 100.0                                                      -- 除法：NGR 占比分子
          / NULLIF(c.ggr_sum - c.rebate16_sum, 0), 4)              AS ngr_by16_pct                  -- 续行：NGR 占比（原有守卫保留）
FROM both b                                                                                         -- 取数来源：双域并列
CROSS JOIN clean c                                                                                  -- 交叉连接：全量洁净域为占比基准（单行，安全）
ORDER BY b.scope_def;                                                                               -- 排序：按域标签；导出必带排序


-- ─────────────────────────────────────────────────────────────────────────
-- §P11c-chk1 · bet41 ≡ validbet 恒等式断言（新增；独立整句，单独执行）
-- ▸ 导出：需要 —— 存为「数据库/P11c_chk1_bet41_validbet_identity.csv」
-- ▸ 裁决规则：n_mismatch = 0 ⇒ 恒等式成立，rebate41_sum 列名属误导性命名，
--   下一版应更名 validbet41_sum（契约变更须公告）；n_mismatch > 0 ⇒
--   「bet41≡validbet」锁定结论与本包必有一处须修，触发降级审议——
--   降级须有证，此断言即证。零行结果 ≠ 无异常，须显式记录行数。
-- ─────────────────────────────────────────────────────────────────────────
WITH ranked AS (                                                                                    -- 同单号保留最新版本（断言域＝窗口内百家乐全量，不加业务闸——恒等式应普适成立）
    SELECT b.bet01, b.bet41, b.validbet,                                                            -- 取列：断言所需最小列集
           ROW_NUMBER() OVER (PARTITION BY b.bet01                                                  -- 行号窗口：按单号去重
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：最新版本置首
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- ★ 表名开关
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：窗口与主件完全一致
),                                                                                                  -- 续行：收束子查询括号
pairs AS (                                                                                          -- 强类型化对照对
    SELECT CAST(NULLIF(TRIM(bet41),   '') AS DECIMAL(20,4)) AS v41,                                 -- 取值表达式：bet41 强类型化
           CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) AS vvb                                  -- 取值表达式：validbet 强类型化
    FROM ranked                                                                                     -- 取数来源：中间结果集 ranked
    WHERE rn = 1                                                                                    -- 过滤条件：仅最新版本
)                                                                                                   -- 续行：收束子查询括号
SELECT                                                                                              -- 主查询：恒等式五项裁决输出
    COUNT(*)                                                        AS n_rows,                      -- 计数表达式：断言域总行数（零行须显式告警）
    SUM(CASE WHEN v41 IS NULL AND vvb IS NULL THEN 1 ELSE 0 END)    AS n_both_null,                 -- 汇总表达式：双空行数（视为相等）
    SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL) THEN 1 ELSE 0 END) AS n_null_asym,                 -- 汇总表达式：单侧为空行数（视为不等）
    SUM(CASE WHEN v41 IS NOT NULL AND vvb IS NOT NULL                                               -- 汇总表达式：双非空且
              AND v41 <> vvb THEN 1 ELSE 0 END)                     AS n_value_diff,                -- 续行：数值不等行数
    SUM(CASE WHEN (v41 IS NULL) <> (vvb IS NULL)                                                    -- 汇总表达式：不匹配总数＝单侧空
              OR (v41 IS NOT NULL AND vvb IS NOT NULL AND v41 <> vvb)                               -- 续行：或数值不等
             THEN 1 ELSE 0 END)                                     AS n_mismatch                   -- 续行：产出「n_mismatch」——裁决主指标
FROM pairs;                                                                                         -- 取数来源：中间结果集 pairs
-- ═════════════════════════════════════════════════════════════════════════
-- 补丁终。拼装为全包 v10 后，请登记六元组并将 v9 改名 _superseded。
-- ═════════════════════════════════════════════════════════════════════════
