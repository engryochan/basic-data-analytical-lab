-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- ★ HF9f-B · 商业实验层增补件（theo / adt / nmpt / esi）· 草案 · 未获授权前禁止执行 ★
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【状态】BLOCKED —— 本档不并入 HF9f 两版正文，理由三条，缺一不可解：
--   ① 结构阻断：#075 之 x_agg 已把产品维折叠（仅存 common_product_count 与投注产品结构熵），
--      无 bet09 级 valid_bet 分解。theo 须新增「会员 × 产品 × 免佣标记」中间粒度 CTE（下方 x_prod），
--      此为取数层结构改动，须与 x_ranked → x_bs0 → x_mk → x_agg 四段管线一并重验。
--   ② 参数阻断：edge_map 之 house_edge 未获授权。且 #075 实测 free_comm_rate > 0 者 70,024 名（9.68%）、
--      = 1 者 20,629 名（2.85%），免佣桌庄注规则不同（6 点赢半赔），故映射表主键须为 (bet09, is_free_comm) 二元，
--      非 bet09 单键。下方 edge_map 之 edge 栏一律留 NULL，禁止以任何推测值填补。
--   ③ 范围阻断：四支新指标施加于四实体件（8 处）抑或全六层模板（256 处），未获裁示。
-- 【执行护栏】下方 GUARD 段令本档在 edge_map 未填之前恒回 0 行，杜绝误跑出数。
-- 【HF9f-B 修订 R1 · 2026-08-28】前一稿以裸标识符 e_active_days / e_residual_b / e_bar 作待接锚点，
--   StarRocks 于「分析期」即做列名解析（早于执行期），故护栏来不及生效，直接报
--   「Column 'e_active_days' cannot be resolved」——该错易被误读为档案损坏，实为占位未接。
--   R1 改以 CAST(NULL AS DOUBLE) 充当三处锚点：本档遂可完整通过语法与语义分析，
--   执行后由护栏 WHERE g.n_edge_filled > 0 收敛为 0 行，回「0 rows」即为「BLOCKED 如设计」，
--   与真实故障可明确区分。三处锚点已以「★ 锚点一/二/三」标出，落地时逐处替换。
-- 【禁令】esi 只测注种选择，严禁引向靴内位置。尾段投注假说已由四项独立检验证伪
--        （符号检验 p=0.7591 · Wilcoxon p=0.8087 · 九门槛 hold% 扫描零命中 · 外部 L1a AUC=0.3828 方向相反），
--        T-03 闸态 FATAL，不得以任何新指标为名复活。

-- ── 一、edge_map：bet09 × 免佣标记 → 庄家优势（待授权填值）──
WITH edge_map AS (                                                                                  -- 定义 CTE：起始 —— 产品优势映射表
  SELECT * FROM (                                                                                   -- 取数来源：起始内联常量表
    VALUES                                                                                          -- 内联常量：起始 —— 每行一个 (产品码, 免佣标记, 优势, 版本, 生效起, 生效迄)
      (CAST(NULL AS STRING), CAST(NULL AS INT), CAST(NULL AS DOUBLE),                                -- 占位行：bet09 / is_free_comm / house_edge 三栏一律 NULL，待授权后逐行填
       CAST(NULL AS STRING), CAST(NULL AS DATE), CAST(NULL AS DATE))                                 -- 占位行：version / effective_from / effective_to
  ) t(bet09, is_free_comm, house_edge, edge_version, effective_from, effective_to)                   -- 取数来源：收束内联常量表并具名六栏
),                                                                                                  -- 定义 CTE：收束 edge_map

-- ── 二、GUARD：edge_map 未填即令全链空转 ──
guard AS (                                                                                          -- 定义 CTE：起始 —— 执行护栏
  SELECT COUNT(*) AS n_edge_filled                                                                   -- 计数表达式：已填之映射行数
  FROM edge_map                                                                                      -- 取数来源：取自映射表
  WHERE bet09 IS NOT NULL AND house_edge IS NOT NULL                                                 -- 过滤条件：仅计两栏俱全者
),                                                                                                  -- 定义 CTE：收束 guard

-- ── 三、x_prod：会员 × 产品 × 免佣标记（新增之中间粒度，theo 之所出）──
-- ★ 占位：本 CTE 之上游须接 HF9f #075 之 x_mk（已去重、已过测试线、已限窗与产品之注单级明细）。
-- ★ 未接上游前，下方以空集占位；接入后 s 即为 x_mk 之别名。
x_prod AS (                                                                                         -- 定义 CTE：起始 —— 会员×产品×免佣 之洗码量
  SELECT                                                                                             -- 取列：起始取列子句
    s.x_member                                        AS x_member,                                   -- 直接取列：会员号
    s.x_product                                       AS bet09,                                      -- 直接取列：投注产品（bet09）
    CASE WHEN s.x_freecomm = 1 THEN 1 ELSE 0 END      AS is_free_comm,                               -- 条件分支：免佣标记，与 edge_map 之第二主键对齐
    SUM(s.x_valid)                                    AS valid_bet_prod,                             -- 聚合取值：该产品之洗码量
    SUM(s.x_stake)                                    AS stake_prod                                  -- 聚合取值：该产品之本金
  FROM (SELECT CAST(NULL AS STRING) AS x_member, CAST(NULL AS STRING) AS x_product,                   -- 取数来源：★ 占位空集 —— 落地时替换为 HF9f #075 之 x_mk
               CAST(NULL AS INT) AS x_freecomm, CAST(NULL AS DOUBLE) AS x_valid,                     -- 占位取值：续列
               CAST(NULL AS DOUBLE) AS x_stake WHERE 1 = 0) s                                        -- 占位取值：恒空，杜绝误跑
  GROUP BY s.x_member, s.x_product, CASE WHEN s.x_freecomm = 1 THEN 1 ELSE 0 END                     -- 分组子句：三键分组
),                                                                                                  -- 定义 CTE：收束 x_prod

-- ── 四、theo 折回会员级，并计覆盖率 ──
theo_agg AS (                                                                                       -- 定义 CTE：起始 —— 会员级理论赢
  SELECT                                                                                             -- 取列：起始取列子句
    p.x_member                                                                    AS x_member,       -- 直接取列：会员号
    SUM(CASE WHEN m.house_edge IS NOT NULL THEN p.valid_bet_prod * m.house_edge END) AS theo,        -- 聚合取值：Σ 洗码量 × 庄家优势；未映射者不计入分子
    SUM(CASE WHEN m.house_edge IS NULL     THEN p.valid_bet_prod ELSE 0 END)       AS valid_bet_unmapped, -- 聚合取值：未映射产品之洗码量
    SUM(p.valid_bet_prod)                                                          AS valid_bet_all  -- 聚合取值：全部洗码量
  FROM x_prod p                                                                                      -- 取数来源：取自会员×产品粒度
  LEFT JOIN edge_map m                                                                                -- 左连接：接映射表 —— 左连以保未映射者不被丢弃（铁律：标记而非丢弃）
    ON CAST(m.bet09 AS STRING) = CAST(p.bet09 AS STRING)                                              -- 连接条件：产品码，显式 CAST
   AND m.is_free_comm = p.is_free_comm                                                                -- 并列条件：免佣标记，二元主键之第二键
  GROUP BY p.x_member                                                                                 -- 分组子句：折回会员级
)                                                                                                    -- 定义 CTE：收束 theo_agg

-- ── 五、四支新指标（待并入六层决策模板之前的独立验算版）──
SELECT                                                                                              -- 取列：起始取列子句
  t.x_member                                                                       AS member_id,     -- 直接取列：会员号
  ROUND(t.theo, 8)                                                                 AS theo,          -- 数值取值：理论赢 ＝ Σ(洗码量 × 庄家优势)；业界 theo / ADT 之分子
  ROUND(1.0 - t.valid_bet_unmapped / NULLIF(t.valid_bet_all, 0), 8)                AS mapped_coverage_rate, -- 比率表达式：映射覆盖率；低覆盖者其 theo 不可信
  CASE WHEN t.valid_bet_unmapped > 0 THEN 'UNKNOWN_PRODUCT' ELSE 'OK' END          AS product_map_flag, -- 条件分支：未映射产品旗标；未映射之洗码量一律不以 1 或 0 顶替（铁律：NULL ≠ 0）
  ROUND(t.theo / NULLIF(CAST(NULL AS DOUBLE), 0), 8)                               AS adt,           -- 比率表达式：日均理论值 ADT ＝ theo / 活跃天数；★ 锚点一 —— 落地时以 e.active_days 替换 CAST(NULL AS DOUBLE)
  ROUND(CAST(NULL AS DOUBLE) / NULLIF(t.theo, 0), 8)                               AS nmpt,          -- 比率表达式：真净利实收率 ＝ residual_b / theo；★ 锚点二 —— 落地时以 e.residual_b 替换 CAST(NULL AS DOUBLE)；theo=0 者恒 NULL
  ROUND(t.theo / NULLIF(t.valid_bet_all * CAST(NULL AS DOUBLE), 0), 8)             AS esi,           -- 比率表达式：选注优势指数 ＝ theo / (洗码量 × 全体加权优势)；★ 锚点三 —— 落地时以实测反解之 e_bar 常数替换 CAST(NULL AS DOUBLE)
  'HF9f-B-DRAFT'                                                                   AS theo_calc_version -- 字面取值：本段版本标识，实验层专用
FROM theo_agg t                                                                                     -- 取数来源：取自会员级理论赢
CROSS JOIN guard g                                                                                  -- 交叉连接：接执行护栏
WHERE g.n_edge_filled > 0;                                                                          -- 过滤条件：★ 护栏 —— edge_map 未填即恒空，杜绝误跑出数

-- ── 六、落地前尚须先生裁示之三事 ──
--   ① bet09 × 免佣标记 之 house_edge 值来源：先生已有文档？抑或由风控／产品重新测算后签字入 registry？
--   ② 施加范围：四实体件（8 处）抑或全六层模板（256 处）？
--   ③ e_bar（全体加权优势）之口径：以全体洗码量加权，抑或以合格子集加权？前者受薄证据会员影响，后者与 pr_qualified 同口径。
