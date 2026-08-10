-- =====================================================================
-- P0-c  L1a 标签时序泄漏审计 · 125 vs 251 口径结案
-- 世博量化® Scibrokes Trading® · a168 风控评分项目
-- 库：StarRocks  ods_mariadb_2b     界面：Superset SQL Lab（只读）
-- 窗口：2026-03-21 ~ dt < '2026-08-07'（139 营业日）  产品：bet02 = '101'
-- 编码：UTF-8。Superset 导出默认 GBK/GB18030，读取侧须依序容错。
-- =====================================================================
--
-- 【执行纪律】
--   ① 一次只提交一条语句。多语句合并提交曾引发僵尸查询，须 DBA 介入。
--   ② 所有字段为 varchar，凡参与比较与聚合者一律显式 CAST。
--   ③ 一律使用冻结字面量，禁用 CURRENT_DATE —— 回测须可复现。
--   ④ 每条语句有且仅有一条激活导出声明。
--
-- 【待确认标识符 —— 请先跑 §P0C-00，与实际不符者全局替换后再执行 §P0C-01 起】
--   T_DR   = ods_mariadb_2b.ods_a168_dailyreport_member
--   T_BET  = ods_mariadb_2b.ods_a168_bet02
--   DR_MEM = dailyreport_member 的会员标识列        ← 待确认
--   DR_DT  = dailyreport_member 的业务日期列（疑为 dt）← 待确认
--   BT_MEM = bet02 的会员标识列                      ← 待确认
--   本包 §P0C-01 起按上列猜测名书写；未经 §P0C-00 核实前，其结果不得引用。
--
-- =====================================================================


-- ---------------------------------------------------------------------
-- §P0C-00  结构探查：确认上列五个标识符的真名
-- ▸ 导出：不需要
-- ---------------------------------------------------------------------
SELECT  TABLE_NAME,
        ORDINAL_POSITION,
        COLUMN_NAME,
        DATA_TYPE,
        COLUMN_COMMENT
FROM    information_schema.columns
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'
  AND   TABLE_NAME IN ('ods_a168_dailyreport_member', 'ods_a168_bet02')
ORDER BY TABLE_NAME, ORDINAL_POSITION;


-- ---------------------------------------------------------------------
-- §P0C-01  125 vs 251 口径结案
--   假说：125 = 去重会员数；251 = 会员-日正例观测数。
--   本条一次性给出四个计数，若 125 与 251 各自对上，假说即成立，
--   两数并无矛盾，仅口径不同；须在方案中分别正名为
--   「正例会员数」与「正例会员-日观测数」。
-- ▸ 导出：需要 → P0C01_标签口径.csv
-- ---------------------------------------------------------------------
SELECT  COUNT(*)                                   AS 正例观测数_会员日,
        COUNT(DISTINCT CAST(dm_mem AS STRING))     AS 正例会员数_去重,
        COUNT(DISTINCT CAST(dt     AS STRING))     AS 覆盖日数,
        MIN(CAST(dt AS STRING))                    AS 首个正例日,
        MAX(CAST(dt AS STRING))                    AS 末个正例日
FROM    ods_mariadb_2b.ods_a168_dailyreport_member
WHERE   CAST(dt AS STRING) >= '2026-03-21'
  AND   CAST(dt AS STRING) <  '2026-08-07'
  AND   CAST(risk AS STRING) NOT IN ('0', '', 'N')
  AND   risk IS NOT NULL;


-- ---------------------------------------------------------------------
-- §P0C-02  正例的每会员标记次数分布
--   若绝大多数会员仅被标记 1 次，则「标记」是一次性事件而非持续状态，
--   Label B（未来窗确认结果）的构造须以首次标记日为锚，不可逐日重复计数。
-- ▸ 导出：需要 → P0C02_标记次数分布.csv
-- ---------------------------------------------------------------------
SELECT  标记次数,
        COUNT(*)                                   AS 会员数,
        SUM(COUNT(*)) OVER (ORDER BY 标记次数)      AS 累计会员数
FROM (
    SELECT  CAST(dm_mem AS STRING) AS mem,
            COUNT(DISTINCT CAST(dt AS STRING)) AS 标记次数
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   CAST(dt AS STRING) >= '2026-03-21'
      AND   CAST(dt AS STRING) <  '2026-08-07'
      AND   CAST(risk AS STRING) NOT IN ('0', '', 'N')
      AND   risk IS NOT NULL
    GROUP BY 1
) t
GROUP BY 标记次数
ORDER BY 标记次数;


-- ---------------------------------------------------------------------
-- §P0C-03  同日泄漏检验（本包核心）
--   对每个正例会员的首次标记日 D0，统计其在 D0 当日的投注活动量，
--   与其在 D0 前 30 日的日均投注量相比。
--   判读：若 D0 当日投注量显著高于历史日均（比值中位数明显 > 1），
--   则风控专员系「见当日异常而后标记」，
--   $X_{t} \to \mathrm{risk}_{t}$ 的监督学习即为同日泄漏，
--   模型学到的是「什么行为会招致打标」，而非「什么行为预示未来风险」。
-- ▸ 导出：需要 → P0C03_同日泄漏检验.csv
-- ---------------------------------------------------------------------
WITH d0 AS (
    SELECT  CAST(dm_mem AS STRING)      AS mem,
            MIN(CAST(dt AS STRING))     AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   CAST(dt AS STRING) >= '2026-03-21'
      AND   CAST(dt AS STRING) <  '2026-08-07'
      AND   CAST(risk AS STRING) NOT IN ('0', '', 'N')
      AND   risk IS NOT NULL
    GROUP BY 1
),
act AS (
    SELECT  CAST(b.bt_mem AS STRING)    AS mem,
            CAST(b.dt     AS STRING)    AS d,
            COUNT(*)                    AS 注单数,
            SUM(CAST(b.bet41 AS DOUBLE))AS 洗码量
    FROM    ods_mariadb_2b.ods_a168_bet02 b
    WHERE   CAST(b.dt AS STRING) >= '2026-03-21'
      AND   CAST(b.dt AS STRING) <  '2026-08-07'
      AND   CAST(b.bet02 AS STRING) = '101'
    GROUP BY 1, 2
)
SELECT  d0.mem,
        d0.mark_day,
        MAX(CASE WHEN act.d = d0.mark_day THEN act.注单数 ELSE 0 END)     AS 标记日_注单数,
        MAX(CASE WHEN act.d = d0.mark_day THEN act.洗码量 ELSE 0 END)     AS 标记日_洗码量,
        AVG(CASE WHEN act.d <  d0.mark_day THEN act.注单数 END)           AS 前30日均_注单数,
        AVG(CASE WHEN act.d <  d0.mark_day THEN act.洗码量 END)           AS 前30日均_洗码量,
        COUNT(DISTINCT CASE WHEN act.d < d0.mark_day THEN act.d END)      AS 前30日活跃日数
FROM        d0
LEFT JOIN   act
       ON   act.mem = d0.mem
      AND   act.d   >= CAST(DATE_SUB(CAST(d0.mark_day AS DATE), 30) AS STRING)
      AND   act.d   <= d0.mark_day
GROUP BY d0.mem, d0.mark_day
ORDER BY 标记日_洗码量 DESC;


-- ---------------------------------------------------------------------
-- §P0C-04  前视 / 后视：标记日相对该会员投注生命期的位置
--   若标记日普遍落在会员活跃期「末端」，说明标记多为事后追认，
--   则该标签不具前瞻性，只可作 Label A（处置标签），
--   绝不可直接充当 Label B 供预测建模。
-- ▸ 导出：需要 → P0C04_标记时点定位.csv
-- ---------------------------------------------------------------------
WITH d0 AS (
    SELECT  CAST(dm_mem AS STRING) AS mem, MIN(CAST(dt AS STRING)) AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   CAST(dt AS STRING) >= '2026-03-21'
      AND   CAST(dt AS STRING) <  '2026-08-07'
      AND   CAST(risk AS STRING) NOT IN ('0', '', 'N')
      AND   risk IS NOT NULL
    GROUP BY 1
),
life AS (
    SELECT  CAST(bt_mem AS STRING) AS mem,
            MIN(CAST(dt AS STRING)) AS 首投日,
            MAX(CAST(dt AS STRING)) AS 末投日,
            COUNT(DISTINCT CAST(dt AS STRING)) AS 活跃日数
    FROM    ods_mariadb_2b.ods_a168_bet02
    WHERE   CAST(dt AS STRING) >= '2026-03-21'
      AND   CAST(dt AS STRING) <  '2026-08-07'
      AND   CAST(bet02 AS STRING) = '101'
    GROUP BY 1
)
SELECT  d0.mem, d0.mark_day, life.首投日, life.末投日, life.活跃日数,
        DATEDIFF(CAST(d0.mark_day AS DATE), CAST(life.首投日 AS DATE)) AS 标记距首投_日,
        DATEDIFF(CAST(life.末投日 AS DATE), CAST(d0.mark_day AS DATE)) AS 末投距标记_日,
        CASE WHEN DATEDIFF(CAST(life.末投日 AS DATE), CAST(d0.mark_day AS DATE)) <= 0
             THEN '标记后再无投注（事后追认）'
             WHEN DATEDIFF(CAST(life.末投日 AS DATE), CAST(d0.mark_day AS DATE)) <= 14
             THEN '标记后 14 日内停投'
             ELSE '标记后仍持续投注' END AS 时点性质
FROM        d0
LEFT JOIN   life ON life.mem = d0.mem
ORDER BY 标记距首投_日;


-- ---------------------------------------------------------------------
-- §P0C-05  Label B 候选构造：以特征窗 [D-30, D] 预测结果窗 [D+1, D+14]
--   本条只产出「每会员每锚点日是否在未来 14 日内被标记」的样本骨架，
--   不含任何特征，特征侧仍走既有 B01 通路。
--   注意：仅当 §P0C-03 与 §P0C-04 显示标记具备前瞻性时，此表方可用于建模；
--   若审计判定为事后追认，则本表只能用于风控人员行为分析（Label A 用途）。
-- ▸ 导出：需要 → P0C05_LabelB骨架.csv
-- ---------------------------------------------------------------------
WITH mk AS (
    SELECT  DISTINCT CAST(dm_mem AS STRING) AS mem, CAST(dt AS STRING) AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   CAST(dt AS STRING) >= '2026-03-21'
      AND   CAST(dt AS STRING) <  '2026-08-07'
      AND   CAST(risk AS STRING) NOT IN ('0', '', 'N')
      AND   risk IS NOT NULL
),
anchor AS (
    SELECT  CAST(bt_mem AS STRING) AS mem, CAST(dt AS STRING) AS anchor_day
    FROM    ods_mariadb_2b.ods_a168_bet02
    WHERE   CAST(dt AS STRING) >= '2026-04-20'      -- 留足 30 日特征窗
      AND   CAST(dt AS STRING) <  '2026-07-24'      -- 留足 14 日结果窗
      AND   CAST(bet02 AS STRING) = '101'
    GROUP BY 1, 2
)
SELECT  a.mem,
        a.anchor_day,
        CAST(DATE_SUB(CAST(a.anchor_day AS DATE), 30) AS STRING) AS 特征窗起,
        a.anchor_day                                             AS 特征窗止,
        CAST(DATE_ADD(CAST(a.anchor_day AS DATE), 1)  AS STRING) AS 结果窗起,
        CAST(DATE_ADD(CAST(a.anchor_day AS DATE), 14) AS STRING) AS 结果窗止,
        MAX(CASE WHEN mk.mark_day >  a.anchor_day
                  AND mk.mark_day <= CAST(DATE_ADD(CAST(a.anchor_day AS DATE), 14) AS STRING)
                 THEN 1 ELSE 0 END)                              AS label_b_未来14日被标记,
        MAX(CASE WHEN mk.mark_day = a.anchor_day THEN 1 ELSE 0 END) AS label_a_当日被标记
FROM        anchor a
LEFT JOIN   mk ON mk.mem = a.mem
GROUP BY a.mem, a.anchor_day
HAVING  MAX(CASE WHEN mk.mark_day > a.anchor_day
                  AND mk.mark_day <= CAST(DATE_ADD(CAST(a.anchor_day AS DATE), 14) AS STRING)
                 THEN 1 ELSE 0 END) = 1
     OR MAX(CASE WHEN mk.mark_day = a.anchor_day THEN 1 ELSE 0 END) = 1
ORDER BY a.mem, a.anchor_day;
-- 说明：HAVING 只保留正例骨架以控制导出体量；负例由特征侧 B01 全量左连补齐，
--       切勿在本条内做全量笛卡尔展开。


-- =====================================================================
-- 【判读次序】
--   §P0C-00 → 确认标识符 → §P0C-01 结案 125/251 口径
--   → §P0C-03 + §P0C-04 判定标签前瞻性
--   → 前瞻性成立方启用 §P0C-05；不成立则将 risk 正名为 Label A，
--     并于 @sec-changelog 记录「监督建模标签缺位」，
--     不得以 Label A 训练结果充当预测能力凭据。
-- =====================================================================
