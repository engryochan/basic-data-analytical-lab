--  ╔═══════════════════════════════════════════════════════════════════════════╗
--    ║  a168 · 全库结构剖析与哨兵值审计 SQL                                        ║
--    ║  编号族：§Z-xx(Zero／零层)—— 避开总包既用之 C／S／R／T／D／E／K／V／       ║
--    ║          P0／TL／DX／EV／B01／A／I／L／X 各族，杜绝编号命名空间碰撞          ║
--    ╠═══════════════════════════════════════════════════════════════════════════╣
--    ║  作者：Ryo Eng  (雷欧)                                                      ║
--    ║  日期：2026-08-13                                                         ║
--    ║  库  ：ods_mariadb_2b(StarRocks，经 Superset SQL Lab 只读访问)           ║
--    ║  身份：诊断类 SQL，非正式交付物、正式交付物永久锁定为三份                     ║
--    ╚═══════════════════════════════════════════════════════════════════════════╝
--
--    ═══ 本文件之定位 ═══════════════════════════════════════════════════════════
--      Ryo Eng 令：`bet39` 与既往所列之十二项哨兵值「只是举例一部份」，
--      须核实、校对、审计所有数据表内容。
--      本文件据此设计：一律不预设候选清单，改由 INFORMATION_SCHEMA 自动生成
--      逐列普查语句，令哨兵值因其异常高频而自行现形。手拟清单必漏，此为通则。
--
--    ═══ 执行次序(不可倒序，铁律)═════════════════════════════════════════════
--      §Z-01 表清单        →  §Z-02 排除清单  →  §Z-03 字段字典
--        →  §Z-04 同名异义侦测  →  §Z-05 类型缺注侦测
--        →  §Z-06 生成逐列普查语句  →  §Z-07 执行普查(分批)
--        →  §Z-08 局键塌缩检验      →  §Z-09 时间字段口径核验
--        →  §Z-10 哨兵值定性(须问上游)→ §Z-11 影响量化 → §Z-12 锁定
--      结构剖析 → 列剖析 → 关系剖析 → 口径固化 → 取数下载 → 分析。
--      §Z-10 为唯一无法自数据闭合者，须携 §Z-07 之具体读数向上游查询业务成因。
--
--    ═══ 纪律(承 SQL 总包卷首，逐条适用)═══════════════════════════════════════
--      ① 每条查询自包含、零占位符，整段复制即可运行、
--      ② 逐条提交，禁批量 —— 批量产生僵尸查询，拖垮集群、
--      ③ 导出必带 ORDER BY —— 无稳定排序之分页曾致 36.49% 重复行、
--      ④ 导出上限 1,000 行时只承认排序头部结论，「未出现」类判断一律无效
--         (LIMIT 产生的是样本，不是全集)、
--      ⑤ 翻页一律取唯一键为序，不得使用 OFFSET、
--      ⑥ 每条语句有且仅有一条导出声明、标「不需要」者不含文件名、
--      ⑦ 注释内不写分号，块注释内不出现星号紧邻斜杠。
--
--    ═══ 导出命名规约(与 SQL 总包一致)═══════════════════════════════════════
--      一律存入「数据库/」目录，英文短名，前缀 Z 系列，与总包 66 个导出名零碰撞。
--      读取端沿用既定编码自适应读取器：UTF-8-sig → UTF-8 → GB18030 → GBK
--      → Big5 → Latin1、R 与 Python 两侧共用同一 DATA_DIR 常量。
--
--    ═══ 数据快照一致性(2026-08-13 立 · 实测教训)═══════════════════════════
--      各条若于不同时点执行，则行数必异，对账将生假差异。实证：
--        §Z-08／§Z-11(先跑) 注单行数 = 131,058,975
--        §Z-07／§Z-09b(后跑) 注单行数 = 131,103,433
--        差 44,458 行 —— 非任一条有误，而是两次执行之间数据仍在增长
--        (§Z-09 实测账务日最大已达 2026-08-13，超出总包窗口右端 2026-08-07)。
--      纪律：
--        一、每条查询导出时须记录执行时刻，与 CSV 并存、
--        二、凡跨条对账(如 §Z-07 之 bet04=0 与 §Z-08 之局键哨兵行数)，
--            须先确认两条取自同一快照，否则差异不可解读为缺陷、
--        三、正式结论所依之各条，应于同一批次内连续执行，中途不得跨日。
--
--    ═══ 已知待验事项(显式列示，未跑不得下结论)═══════════════════════════════
--      待-01  `bet07`(帳務日期)与 `dt`(分区日)、`DATE(bet08)` 三者关系未验。
--             受影响 SQL：§Z-09。
--             受影响产出：一切「日／月／滚动窗口」聚合之切日基准。
--             备注：总包现行一律以 `dt` 切日。若 §Z-09 证三者一致，则总包做法
--                   已然正确，无须改动、本项此前被误列为「斧正项」，现降为待验。
--      待-02  局键 `bet03 + bet04 + bet39` 之唯一性未验。
--             受影响 SQL：§Z-08。
--             受影响产出：同桌共现、对打配对、玩家局级胜负和之全部结论，
--                   含既有产物 `候选_同桌异常_最终版_已去重.csv`。
--      待-03  哨兵值之业务成因未知(字段未采集／不适用／ETL 故障／尚未发生)。
--             受影响 SQL：§Z-10 之后全部。
--             解除条件：向上游取得各异常取值之语义说明。
-- =========================================================================


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-00 · 会话参数(每个 Superset 会话开跑前逐条单跑一次)
--    ▸ 导出：不需要 —— 会话参数设置，无结果集
-- ═══════════════════════════════════════════════════════════════════════════
SET SESSION query_timeout = 259200;
SET SESSION cbo_cte_reuse = true;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-01 · 全库表清单与规模
--    用途：确立审计范围与分批次序。TABLE_ROWS 为估计值，仅用于排序，不作结论。
--    ▸ 导出：需要 —— 存为「数据库/Z01_table_inventory.csv」
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    TABLE_NAME                                                   AS 表名,
    TABLE_TYPE                                                   AS 表类型,
    TABLE_ROWS                                                   AS 估计行数,
    TABLE_COMMENT                                                AS 表注释,
    CASE
      WHEN LOWER(TABLE_NAME) LIKE '%_bak%'  THEN '备份'
      WHEN LOWER(TABLE_NAME) LIKE '%bak2%'  THEN '备份'
      WHEN LOWER(TABLE_NAME) LIKE '%_test%' THEN '测试'
      WHEN LOWER(TABLE_NAME) LIKE '%_tmp%'  THEN '临时'
      WHEN LOWER(TABLE_NAME) LIKE '%_old%'  THEN '旧版'
      WHEN LOWER(TABLE_NAME) LIKE '%_copy%' THEN '副本'
      WHEN LOWER(TABLE_NAME) LIKE '%_v1%'   THEN '疑似旧版'
      WHEN LOWER(TABLE_NAME) LIKE '%demo%'  THEN '疑似演示'
      ELSE '生产'
    END                                                          AS 疑似性质
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY 疑似性质, TABLE_NAME;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-02 · 排除清单(备份／测试／临时／副本表)
--    用途：此清单须写入全案「禁用表」名录。
--    ★ 2026-08-13 实测：全库 129 张表，命中 5 张——
--        ods_a168_wallet_reporter_copy(182,452 行·副本·本轮新发现)
--        ods_a168_agent_bak20250610(43,244 行·备份)
--        ods_a168_agent_dtl_test(57 行·测试)
--        ods_a168_agent_test(30 行·测试)
--        ods_a168_game_demoipsetting(16 行·演示·须业务确认)
--      其中副本表逾十八万行，量级不小，误用之害不容轻忽。
--    判读：凡列入者，一律不得进入任何分析、若某分析已引用之，须整体重跑。
--    ▸ 导出：需要 —— 存为「数据库/Z02_excluded_tables.csv」
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    TABLE_NAME                          AS 表名,
    TABLE_ROWS                          AS 估计行数,
    TABLE_COMMENT                       AS 表注释,
    CASE
      WHEN LOWER(TABLE_NAME) LIKE '%_bak%'  OR LOWER(TABLE_NAME) LIKE '%bak2%' THEN '备份表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_test%' THEN '测试表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_tmp%'  THEN '临时表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_old%'  THEN '旧版表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_copy%' THEN '副本表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%demo%'  THEN '演示表·须确认'
      ELSE '其他·须确认'
    END                                 AS 处置
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (   LOWER(TABLE_NAME) LIKE '%_bak%'  OR LOWER(TABLE_NAME) LIKE '%bak2%'
       OR LOWER(TABLE_NAME) LIKE '%_test%' OR LOWER(TABLE_NAME) LIKE '%_tmp%'
       OR LOWER(TABLE_NAME) LIKE '%_old%'  OR LOWER(TABLE_NAME) LIKE '%_copy%'
       OR LOWER(TABLE_NAME) LIKE '%demo%')
ORDER BY 处置, TABLE_NAME;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-03 · 全库字段字典(含 source_type 解析)
--    用途：本表即数据字典之基底，落盘存档后，作为一切字段引用之唯一依据。
--    要点：本库全部字段以 varchar 存储，真实类型仅存于 COLUMN_COMMENT 之
--          `source_type=` 前缀。凡涉数值或时间比较，须先查此表确定原始类型，
--          再行显式 CAST，不得凭字段名臆测。
--    ▸ 导出：需要 —— 存为「数据库/Z03_column_dictionary.csv」
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    TABLE_NAME                                                        AS 表名,
    ORDINAL_POSITION                                                  AS 列序,
    COLUMN_NAME                                                       AS 列名,
    DATA_TYPE                                                         AS 存储类型,
    IS_NULLABLE                                                       AS 可空,
    REGEXP_EXTRACT(COLUMN_COMMENT, 'source_type=([^;]+)', 1)          AS 原始类型,
    TRIM(REGEXP_REPLACE(COLUMN_COMMENT, 'source_type=[^;]+;', ''))    AS 业务含义,
    COLUMN_COMMENT                                                    AS 原始注释
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-04 · 同名异义自动侦测(★ 本文件最关键之一条)
--    用途：一次列出全库所有「同一列名、不同业务含义」之字段，
--          不必再靠人逐一撞见。已知六处(bet14、bet01/bet02 自 bet14 起整段错位、
--          bet31/bet32 与 bet39/bet40、member.mem015 与 member_dtl.mem015、
--          member.mem015 自身、game_log.region 注释为「國家」)应由本条全数覆盖，
--          且极可能另有未知者。
--    判读：释义数 ≥ 2 者即为同名异义、类型数 ≥ 2 者风险更高——不仅义异，且型异，
--          跨表复用同一段 SQL 必致静默错误。
--    ▸ 导出：需要 —— 存为「数据库/Z04_name_collision.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH d AS (
  SELECT
      COLUMN_NAME,
      TABLE_NAME,
      TRIM(REGEXP_REPLACE(COLUMN_COMMENT, 'source_type=[^;]+;', ''))  AS 含义,
      REGEXP_EXTRACT(COLUMN_COMMENT, 'source_type=([^;]+)', 1)        AS 类型
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
    AND COLUMN_COMMENT IS NOT NULL
    AND TRIM(COLUMN_COMMENT) <> ''
)
SELECT
    COLUMN_NAME                                  AS 列名,
    COUNT(DISTINCT 含义)                          AS 释义数,
    COUNT(DISTINCT 类型)                          AS 类型数,
    COUNT(DISTINCT TABLE_NAME)                   AS 出现表数,
    CASE WHEN COUNT(DISTINCT 类型) >= 2 THEN '🔴 义异且型异'
         ELSE '🟠 义异型同' END                   AS 风险,
    GROUP_CONCAT(DISTINCT CONCAT(TABLE_NAME, ' → ', 含义, ' [', 类型, ']')
                 SEPARATOR '  ||  ')             AS 明细
FROM d
GROUP BY COLUMN_NAME
HAVING COUNT(DISTINCT 含义) >= 2
ORDER BY 类型数 DESC, 释义数 DESC, 出现表数 DESC, COLUMN_NAME;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-05 · 类型缺注与注释缺失侦测
--    用途：凡 COLUMN_COMMENT 为空或无 source_type 前缀者，其真实类型无从判定，
--          一切 CAST 皆属臆测。此清单即「不得使用之字段」名录。
--    ▸ 导出：需要 —— 存为「数据库/Z05_missing_typehint.csv」
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    TABLE_NAME                        AS 表名,
    ORDINAL_POSITION                  AS 列序,
    COLUMN_NAME                       AS 列名,
    DATA_TYPE                         AS 存储类型,
    COLUMN_COMMENT                    AS 原始注释,
    CASE
      WHEN COLUMN_COMMENT IS NULL OR TRIM(COLUMN_COMMENT) = ''      THEN '🔴 无任何注释'
      WHEN COLUMN_COMMENT NOT LIKE '%source_type=%'                 THEN '🟠 缺原始类型'
      WHEN TRIM(REGEXP_REPLACE(COLUMN_COMMENT,'source_type=[^;]+;','')) = ''
                                                                    THEN '🟠 有类型无含义'
      ELSE '🟢 完整'
    END                               AS 状态
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (COLUMN_COMMENT IS NULL
       OR TRIM(COLUMN_COMMENT) = ''
       OR COLUMN_COMMENT NOT LIKE '%source_type=%'
       OR TRIM(REGEXP_REPLACE(COLUMN_COMMENT,'source_type=[^;]+;','')) = '')
ORDER BY 状态, TABLE_NAME, ORDINAL_POSITION;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-06 · 生成逐列高频值普查语句(★ 令哨兵值自行现形)
--    原理：真实业务取值在秒级或金额级上近乎连续，任一具体取值之占比极低、
--          哨兵值则表现为单点尖峰。故取每列高频前 20，异常者自现，
--          不预设 -1／0／unknown／1970-01-01 之类候选清单——
--          手拟必漏，且会遗漏 9999-12-31、1900-01-01、'N/A'、'null' 字符串、
--          -999、全角空格等未曾预料者。
--    用法：先跑本条生成 SQL，再逐条执行其输出(承纪律②，禁批量)。
--    分批：★ 2026-08-13 实测——生成 1,530 条查询，涉 125 张表。
--          若逐条提交，即 1,530 次执行，断不可一次全跑(承纪律③禁批量)。
--          建议次序：先跑 §Z-01 之最大八表(member_dtl 8.18 亿行、
--          log_age_cash_change 3.15 亿、bet01 1.99 亿、bet02 1.99 亿、
--          in_out_m 1.71 亿、wallet_dtl 1.08 亿、member 5,878 万、
--          mem_login 5,742 万)，其余按业务重要性顺延。
--          大表之逐列 GROUP BY 代价高，务必逐条观察耗时后再续。
--    ▸ 导出：需要 —— 存为「数据库/Z06_generated_probe_sql.csv」
-- ═══════════════════════════════════════════════════════════════════════════
SELECT
    c.TABLE_NAME                                          AS 表名,
    c.ORDINAL_POSITION                                    AS 列序,
    c.COLUMN_NAME                                         AS 列名,
    t.TABLE_ROWS                                          AS 估计行数,
    CONCAT(
      'SELECT ''', c.TABLE_NAME, ''' AS t, ''', c.COLUMN_NAME, ''' AS c, ',
      'CAST(', c.COLUMN_NAME, ' AS VARCHAR) AS v, COUNT(*) AS n, ',
      'COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct ',
      'FROM ods_mariadb_2b.', c.TABLE_NAME, ' ',
      'GROUP BY 3 ORDER BY n DESC LIMIT 20;'
    )                                                     AS 待执行SQL
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN INFORMATION_SCHEMA.TABLES t
       ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'
  AND c.COLUMN_NAME NOT IN ('__source_pk','source_db','source_table',
                            'ods_table_name','sync_time')
  AND NOT (   LOWER(c.TABLE_NAME) LIKE '%_bak%'  OR LOWER(c.TABLE_NAME) LIKE '%bak2%'
           OR LOWER(c.TABLE_NAME) LIKE '%_test%' OR LOWER(c.TABLE_NAME) LIKE '%_tmp%'
           OR LOWER(c.TABLE_NAME) LIKE '%_old%'  OR LOWER(c.TABLE_NAME) LIKE '%_copy%')
ORDER BY t.TABLE_ROWS DESC, c.TABLE_NAME, c.ORDINAL_POSITION;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-07 · 普查执行样例(以注单主表示范、其余各表由 §Z-06 生成)
--    ★ 2026-08-13 实测斧正(v1 → v2，两处)：
--      一、原十条 UNION 支路皆无 `WHERE bet02 = '101'`，扫的是整表(含全部游戏
--          类别)，得 199,151,240 行、而 §Z-08／§Z-11 限百家乐，得 131,058,975 行。
--          二者相差 6,809 万行，根本不可比。今补齐游戏范围谓词。
--          教训：同一份审计内，各条之样本范围须一致、范围不一致而并列判读，
--          必得错误结论——此正是 v1 实测中 bet03=0 有 120,811 笔、
--          而 §Z-08 只报 102 笔之所以然。
--      二、末尾排序原为 `ORDER BY 1,2,4 DESC`。因哨兵值系以高频尖峰现形，
--          已确认按 n 降序为正解，保留。
--
--    ★ 2026-08-13 v2 重跑实测(十列合计皆为 131,103,433 行，范围已对齐)：
--        eid = -1          19,982,734 笔 · 15.24%  ← 全档最大之哨兵值
--        commission = 0   120,944,877 笔 · 92.25%(一般，非哨兵)
--        commission = -100        8 笔 ／ -1  8 笔 ／ -999  1 笔  ← 三种脏值并存
--        bet04 = 0              102 笔 · 8e-7(与 §Z-08「局键含哨兵值 102 行」吻合)
--        gametype = 1     131,103,433 笔 · 100%(百家乐内无电投)
--      另记一事：v1 全表版中 bet03=0／bet39=0／eid=0／gametype=3 各恰为 120,811 笔，
--      四列同数即同一批行——该批为「電投網投模式」，无实体桌／靴／荷官。
--      今限百家乐后该批全数消失，可证电投批次不属百家乐，
--      其处置不在本项目范围内。
--
--    判读准则(三条，缺一不可)：
--      一、单点尖峰：某具体取值之占比较其邻近取值高出数个量级者，列为候选、
--      二、语义可疑：取值形如 -1／0／-999／'unknown'／'N/A'／'null'／
--          1970-01-01／0000-00-00／9999-12-31／1900-01-01 者，列为候选、
--      三、跨列共现：候选行在其余字段是否同步异常——若是，则为系统填充之空行、
--          若仅此一列异常，则更可能为 ETL 故障。二者成因不同，处置亦不同。
--    ▸ 导出：需要 —— 存为「数据库/Z07_probe_bet02.csv」
-- ═══════════════════════════════════════════════════════════════════════════
SELECT 'ods_a168_bet02' AS t, 'bet03' AS c, CAST(bet03 AS VARCHAR) AS v,
       COUNT(*) AS n, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet04', CAST(bet04 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet39', CAST(bet39 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'eid', CAST(eid AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'gametype', CAST(gametype AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'commission', CAST(commission AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'category', CAST(category AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet09', CAST(bet09 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet10', CAST(bet10 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet11', CAST(bet11 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 WHERE bet02 = '101' GROUP BY 3
ORDER BY 1, 2, 4 DESC;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-08 · 局键唯一性与塌缩检验(对应「待-02」·风险最高之一条)
--    何以要紧：局键为 bet03 + bet04 + bet39。若三者任一含哨兵值，
--          则所有此类注单将被拼成同一「局键」(如 -1|-1|-1)，
--          成千上万笔互不相干之注单被聚合为同一局。
--          其后果：该「局」参与会员数暴增，同桌共现于此局产生天量虚假配对、
--          玩家局级胜负判定亦全盘错乱。
--    须查者：既有产物 `候选_同桌异常_最终版_已去重.csv` 是否已受此污染。
--    附带核验：bet03 单列是否已全局唯一——若是，则 bet39 在键中为冗余项。
--    ▸ 导出：需要 —— 存为「数据库/Z08_roundkey_integrity.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH v AS (
  SELECT
      CAST(bet03 AS VARCHAR) AS k3,
      CAST(bet04 AS VARCHAR) AS k4,
      CAST(bet39 AS VARCHAR) AS k39,
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR)) AS round_key
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
per_key AS (
  SELECT round_key,
         COUNT(*)                  AS n_rows,
         COUNT(DISTINCT member_id) AS n_member,
         COUNT(DISTINCT k39)       AS n_table
  FROM v GROUP BY round_key
),
per_k3 AS (
  SELECT k3, COUNT(DISTINCT k39) AS n_table_per_k3,
             COUNT(DISTINCT k4)  AS n_k4_per_k3
  FROM v GROUP BY k3
)
SELECT
    (SELECT COUNT(*) FROM v)                                            AS 注单行数,
    (SELECT COUNT(*) FROM per_key)                                      AS 局键数,
    (SELECT MAX(n_rows)   FROM per_key)                                 AS 单局最大注单行数,
    (SELECT MAX(n_member) FROM per_key)                                 AS 单局最大会员数,
    (SELECT PERCENTILE_APPROX(CAST(n_member AS DOUBLE),0.999) FROM per_key)
                                                                        AS 单局会员数P999,
    (SELECT COUNT(*) FROM per_key WHERE n_table > 1)                    AS 跨桌局键数_应为0,
    (SELECT COUNT(*) FROM per_k3 WHERE n_table_per_k3 > 1)              AS bet03跨桌数,
    (SELECT COUNT(*) FROM per_k3)                                       AS bet03唯一值数,
    (SELECT SUM(CASE WHEN k3 IN ('-1','0','') OR k3 IS NULL
                       OR k4 IN ('-1','0','') OR k4 IS NULL
                       OR k39 IN ('-1','0','') OR k39 IS NULL
                     THEN 1 ELSE 0 END) FROM v)                         AS 局键含哨兵值行数;

--  配套：局键规模排行(若榜首出现 -1|-1|-1 之类且注单数远超其余，即坐实塌缩)
-- ▸ 承上条之诊断，本注释块不单独计为一条语句


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-09 · 时间字段口径核验(对应「待-01」)
--    何以要紧：本项目一切「日／月／滚动 30 日」聚合，皆须先确定切日基准。
--          候选有三：`dt`(StarRocks 分区日)、`bet07`(帳務日期)、
--          `DATE(bet08)`(下注日)。SQL 总包现行一律以 `dt` 切日。
--    ★ 2026-08-13 实测结论(已闭合，此后不必再议)：
--        dt 等于账务日     131,058,975 / 131,058,975 = 100.0%
--        dt 等于下注日      80,471,049 / 131,058,975 = 61.4%
--      结论一：`dt` 即 `bet07`(帳務日期)，总包一律以 dt 切日之做法正确，无须改动。
--      结论二：账务日与下注日有 38.6% 不一致——营业日不以午夜为界。
--              故凡以 `DATE(bet08)` 切日者，三成八以上行数错分。
--              此为硬结论：日／月／滚动窗口一律以 `dt` 为准，禁用 `DATE(bet08)`。
--      结论三：bet06 与 bet08 之纪元哨兵皆为 0，时序异常仅 3 笔、
--              下注距开局秒 P50 = 11、P99 = P999 = 25、最大 215、最小 −1。
--              故 bet06 确为「开放下注」时刻(非开牌)，且下注窗口上界约 25~30 秒。
--              封盘时刻或可由 `bet06 + 窗口长度` 推得——惟窗口是否恒定，
--              须另跑差值之完整分布(见 §Z-09b)方能定谳，不得据 P999 单点即下结论。
--    附带：bet06(開局時間)与 bet08 之差值分布，可一并回答三事——
--          bet06 究为「开放下注」抑或「开牌」、下注时长是否恒定、两者时区是否一致。
--          若差值集中于 0 至 30 秒，则 bet06 在下注之前且时长约 30 秒、
--          若集中于 28800 秒上下，则时区不一致，尾秒相位计算将整体错八小时。
--    ▸ 导出：需要 —— 存为「数据库/Z09_time_axis_recon.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH v AS (
  SELECT
      dt,
      CAST(NULLIF(TRIM(bet07),'') AS DATE)      AS d_acct,
      CAST(NULLIF(TRIM(bet06),'') AS DATETIME)  AS t_open,
      CAST(NULLIF(TRIM(bet08),'') AS DATETIME)  AS t_bet
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
)
SELECT
    COUNT(*)                                                        AS 行数,
    SUM(CASE WHEN dt = d_acct THEN 1 ELSE 0 END)                    AS dt等于账务日,
    SUM(CASE WHEN dt = DATE(t_bet) THEN 1 ELSE 0 END)               AS dt等于下注日,
    SUM(CASE WHEN d_acct = DATE(t_bet) THEN 1 ELSE 0 END)           AS 账务日等于下注日,
    SUM(CASE WHEN d_acct IS NULL THEN 1 ELSE 0 END)                 AS 账务日不可用,
    SUM(CASE WHEN t_open IS NULL THEN 1 ELSE 0 END)                 AS 开局时间不可用,
    SUM(CASE WHEN t_bet  IS NULL THEN 1 ELSE 0 END)                 AS 下注时间不可用,
    SUM(CASE WHEN t_bet <= '1971-01-01 00:00:00' THEN 1 ELSE 0 END) AS 下注时间纪元哨兵,
    SUM(CASE WHEN t_open <= '1971-01-01 00:00:00' THEN 1 ELSE 0 END) AS 开局时间纪元哨兵,
    MIN(d_acct)                                                     AS 账务日最小,
    MAX(d_acct)                                                     AS 账务日最大,
    SUM(CASE WHEN TIMESTAMPDIFF(SECOND, t_open, t_bet) <  0 THEN 1 ELSE 0 END)
                                                                    AS 下注早于开局_时序异常,
    MIN(TIMESTAMPDIFF(SECOND, t_open, t_bet))                       AS 下注距开局秒_最小,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.50)
                                                                    AS 下注距开局秒_P50,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.99)
                                                                    AS 下注距开局秒_P99,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.999)
                                                                    AS 下注距开局秒_P999,
    MAX(TIMESTAMPDIFF(SECOND, t_open, t_bet))                       AS 下注距开局秒_最大
FROM v;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-09b · 下注窗口长度之完整分布(★ 2026-08-13 新增 · 尾秒阻塞之钥)
--    缘起：§Z-09 实测得下注距开局秒 P50 = 11、P99 = P999 = 25、最大 215。
--          P99 与 P999 同为 25，形态上高度暗示下注窗口存在硬上界。
--          若窗口恒定，则 close_bet_time = bet06 + 窗口长度，
--          需求文档 §5 之尾秒分析即可开工，无须外求封盘时间表。
--    惟不得据 P999 单点即断——PERCENTILE_APPROX 系近似算法，
--    且极端尾部之近似误差最著。故本条改取逐秒直方图，一次看全。
--    ★ 2026-08-13 实测结论(读数已到，结论如下)：
--      窗口非恒定，存在两种制式并存——
--        局层「该局最末下注秒」呈双峰：
--          峰一 s=13(1,118,809 局 · 17.70%)，其后 s=14 骤降至 32,107(跌 97%)
--          峰二 s=24(1,361,120 局 · 21.53%)与 s=25(1,166,821 局 · 18.46%)，
--               其后 s=26 骤降至 617(跌 99.9%)
--        累计：s≤13 覆盖 36.35% 之局、s≤25 覆盖 99.63% 之局。
--      故：约三成六之局其下注窗口约 14 秒，约六成三之局约 26 秒。
--      `close_bet_time = bet06 + 30秒` 之设想不成立——单一固定位移必致误判。
--      惟窗口既呈清晰双峰而非长尾缓降，则其应为桌台或房间层之制度属性，
--      而非随机波动。若能证其为桌台级常量，则窗口可由桌台推得，
--      对个别下注者而言仍属外生，B-1 即可解封。此须 §Z-09c 交叉验证。
--      ⚠ 绝不可以「该局实测最末下注秒」当作封盘时刻——那将使每局最后一名
--        下注者自动被判为尾秒，所欲测者与所用之尺成了同一物(循环论证)。
--
--    判读(原准则，留档)：
--      · 若逐秒频次在某秒后骤降至近零，该秒即窗口上界，窗口恒定 → B-1 解封、
--      · 若频次呈长尾缓降而无明显断点，则窗口不恒定 → 仍须外求封盘表，
--        或退用需求 §5.1 所许之「下注后第几秒」，惟须另证其可比性、
--      · 每局最大差值之分布(下半段)另证窗口是否随局而异。
--    ▸ 导出：需要 —— 存为「数据库/Z09b_bet_window.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH v AS (
  SELECT
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR))                        AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(bet08),'') AS DATETIME))                   AS d_sec
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
hist AS (
  SELECT d_sec, COUNT(*) AS n_orders
  FROM v WHERE d_sec IS NOT NULL
  GROUP BY d_sec
),
rmax AS (
  SELECT round_key, MAX(d_sec) AS max_d
  FROM v WHERE d_sec IS NOT NULL
  GROUP BY round_key
),
rhist AS (
  SELECT max_d, COUNT(*) AS n_rounds
  FROM rmax GROUP BY max_d
)
SELECT '注单层·逐秒' AS 层, CAST(h.d_sec AS VARCHAR) AS 距开局秒,
       h.n_orders AS 计数,
       h.n_orders * 1.0 / SUM(h.n_orders) OVER ()               AS 占比,
       SUM(h.n_orders) OVER (ORDER BY h.d_sec)
         * 1.0 / SUM(h.n_orders) OVER ()                        AS 累计占比
FROM hist h
UNION ALL
SELECT '局层·该局最末下注秒', CAST(r.max_d AS VARCHAR),
       r.n_rounds,
       r.n_rounds * 1.0 / SUM(r.n_rounds) OVER (),
       SUM(r.n_rounds) OVER (ORDER BY r.max_d)
         * 1.0 / SUM(r.n_rounds) OVER ()
FROM rhist r
ORDER BY 1, CAST(距开局秒 AS INT);


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-09c · 下注窗口制式之桌台归属(★ B-1 解封之最后一步)
--    缘起：§Z-09b 实测得窗口呈双峰(约 14 秒与约 26 秒)，非单一常量。
--          若该二制式按桌台(bet39)或房间(bet40)划分且各桌恒定，
--          则窗口对个别下注者外生，封盘时刻可由「桌台 → 窗口」推得，尾秒可开工。
--          若同一桌台之内两制式混杂，则窗口随局而变，须另求封盘表。
--    方法：先按桌台算其各局「最末下注秒」之分布，再看每桌是否集中于单一制式。
--          判据用 P50 与 P95 之差、以及落入两制式之局数占比。
--    判读：
--      · 若绝大多数桌台之「制式纯度」逼近 1(即某一制式占该桌九成以上)，
--        则窗口为桌台级常量 → B-1 解封，close = bet06 + 该桌窗口、
--      · 若纯度普遍居中(如 0.5 上下)，则同桌混用两制式 → 窗口随局而变，
--        须另求封盘表，或退用需求 §5.1 所许之「下注后第几秒」并另证可比性、
--      · 另须查制式是否随时间迁移(同一桌前后期不同)，故并出按月之纯度。
--    ▸ 导出：需要 —— 存为「数据库/Z09c_window_by_table.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH v AS (
  SELECT
      CAST(bet39 AS VARCHAR)                                        AS table_id,
      CAST(bet40 AS VARCHAR)                                        AS room_id,
      dt,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR))                        AS round_key,
      TIMESTAMPDIFF(SECOND,
        CAST(NULLIF(TRIM(bet06),'') AS DATETIME),
        CAST(NULLIF(TRIM(bet08),'') AS DATETIME))                   AS d_sec
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
rmax AS (
  SELECT table_id, room_id, round_key,
         DATE_FORMAT(MIN(dt), '%Y-%m')        AS ym,
         MAX(d_sec)                           AS max_d
  FROM v
  WHERE d_sec IS NOT NULL AND d_sec >= 0
  GROUP BY table_id, room_id, round_key
),
cls AS (
  SELECT table_id, room_id, ym, round_key, max_d,
         CASE WHEN max_d <= 13 THEN '短制式约14秒'
              WHEN max_d <= 25 THEN '长制式约26秒'
              ELSE '逾制·异常'          END   AS regime
  FROM rmax
)
SELECT
    table_id                                                        AS 桌号,
    room_id                                                         AS 房间,
    ym                                                              AS 年月,
    COUNT(*)                                                        AS 局数,
    SUM(CASE WHEN regime = '短制式约14秒' THEN 1 ELSE 0 END)          AS 短制式局数,
    SUM(CASE WHEN regime = '长制式约26秒' THEN 1 ELSE 0 END)          AS 长制式局数,
    SUM(CASE WHEN regime = '逾制·异常'   THEN 1 ELSE 0 END)          AS 逾制局数,
    GREATEST(SUM(CASE WHEN regime = '短制式约14秒' THEN 1 ELSE 0 END),
             SUM(CASE WHEN regime = '长制式约26秒' THEN 1 ELSE 0 END))
      * 1.0 / NULLIF(COUNT(*), 0)                                   AS 制式纯度,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.50)                  AS 最末下注秒P50,
    PERCENTILE_APPROX(CAST(max_d AS DOUBLE), 0.95)                  AS 最末下注秒P95,
    MAX(max_d)                                                      AS 最末下注秒最大
FROM cls
GROUP BY table_id, room_id, ym
ORDER BY 制式纯度 ASC, 局数 DESC;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-10 · 哨兵值定性登记(须携 §Z-07 读数向上游查询后填写)
--    本条为表格模板，非查询。哨兵值之业务成因无法自数据闭合，
--    须逐项向上游确认后，方可决定处置。
--    登记字段(十二项，缺一不可)：
--      table / column / sentinel_value / row_count / pct / co_anomaly(跨列共现)
--      / semantic(业务成因)/ source(谁确认的)/ disposition(剔除／分离／保留)
--      / rationale / affected_output / decided_at
--    处置对照：
--      字段未采集         → 剔除，但须报告剔除量
--      该场景下不适用     → 分离，单独分析
--      ETL 故障           → 剔除，并向上游报缺陷
--      尚未发生(如未结算)→ 不可剔除，另立状态、剔除将造成选择性偏差
--    处置策略(分两派，按字段风险择用)：
--      局键三要素 bet03／bet04／bet39 → 装载层一律转 NULL 并剔除
--        (局键塌缩之害太重，不容任何遗漏渗入下游)
--      荷官／代理等维度字段          → 保留原值另设标志列
--        (成因未明，或有单独分析之价值)，并加锁定列使旧版产物在导入时强制报错
--    ▸ 导出：不需要 —— 登记模板，无结果集
-- ═══════════════════════════════════════════════════════════════════════════


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-11 · 哨兵值处置前后影响量化
--    用途：处置一经裁定，须以本条量化其影响，方可对外声明。
--    注意：「每局最大会员数」与「同桌共现配对数」两项对局键塌缩最敏感，
--          其前后差额即虚假配对之规模。
--    前提：本条须待 §Z-10 裁定后方可填入具体排除条件、当前先出「未处置」侧读数，
--          作为基线。
--    ▸ 导出：需要 —— 存为「数据库/Z11_sentinel_impact.csv」
-- ═══════════════════════════════════════════════════════════════════════════
WITH v AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CAST(ip    AS VARCHAR) AS ip_addr,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR)) AS round_key,
      CASE WHEN CAST(bet03 AS VARCHAR) IN ('-1','0','') OR bet03 IS NULL
                OR CAST(bet04 AS VARCHAR) IN ('-1','0','') OR bet04 IS NULL
                OR CAST(bet39 AS VARCHAR) IN ('-1','0','') OR bet39 IS NULL
           THEN 1 ELSE 0 END AS is_sentinel_key
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
a AS (
  SELECT COUNT(*) AS n_rows, COUNT(DISTINCT round_key) AS n_key,
         COUNT(DISTINCT member_id) AS n_member, COUNT(DISTINCT ip_addr) AS n_ip
  FROM v
),
b AS (
  SELECT COUNT(*) AS n_rows, COUNT(DISTINCT round_key) AS n_key,
         COUNT(DISTINCT member_id) AS n_member, COUNT(DISTINCT ip_addr) AS n_ip
  FROM v WHERE is_sentinel_key = 0
),
ma AS (SELECT MAX(c) AS m FROM (SELECT round_key, COUNT(DISTINCT member_id) AS c
                                FROM v GROUP BY round_key) x),
mb AS (SELECT MAX(c) AS m FROM (SELECT round_key, COUNT(DISTINCT member_id) AS c
                                FROM v WHERE is_sentinel_key = 0 GROUP BY round_key) y)
SELECT
    a.n_rows   AS 未处置_注单行数,  b.n_rows   AS 已处置_注单行数,
    a.n_key    AS 未处置_局键数,    b.n_key    AS 已处置_局键数,
    a.n_member AS 未处置_会员数,    b.n_member AS 已处置_会员数,
    a.n_ip     AS 未处置_IP数,      b.n_ip     AS 已处置_IP数,
    ma.m       AS 未处置_单局最大会员数,
    mb.m       AS 已处置_单局最大会员数,
    ma.m - mb.m                                       AS 单局最大会员数_差额,
    a.n_rows - b.n_rows                               AS 剔除行数,
    (a.n_rows - b.n_rows) * 1.0 / NULLIF(a.n_rows, 0) AS 剔除占比
FROM a CROSS JOIN b CROSS JOIN ma CROSS JOIN mb;


--  ═══════════════════════════════════════════════════════════════════════════
--    §Z-12 · 锁定(承既有 late_def 之例)
--    本条为纪律陈述，非查询。
--    哨兵值处置一经裁定，须于装载层落地，并加口径锁定列，
--    使不合口径之旧版产物在导入时强制报错，而非静默通过。
--    既有实例：`late_def` 锁定列——尾靴判据自 round_no >= 50 改为 shoe_pos >= 0.80 后，
--    新增该列，令旧版 CSV 在导入时报错。此设计优于纯标志列，
--    因其不依赖下游之自觉。
--    旧版产物一律重命名为 `_v1_superseded` 后缀存档，禁止直接删除。
--    ▸ 导出：不需要 —— 纪律陈述，无结果集
-- ═══════════════════════════════════════════════════════════════════════════


--  ═══════════════════════════════════════════════════════════════════════════
--    导出汇总(与语句一一对应)
--      §Z-00  不需要                §Z-07  数据库/Z07_probe_bet02.csv
--      §Z-01  数据库/Z01_table_inventory.csv    §Z-08  数据库/Z08_roundkey_integrity.csv
--      §Z-02  数据库/Z02_excluded_tables.csv    §Z-09  数据库/Z09_time_axis_recon.csv
--      §Z-03  数据库/Z03_column_dictionary.csv  §Z-10  不需要
--      §Z-04  数据库/Z04_name_collision.csv     §Z-11  数据库/Z11_sentinel_impact.csv
--      §Z-05  数据库/Z05_missing_typehint.csv   §Z-12  不需要
--      §Z-06  数据库/Z06_generated_probe_sql.csv
--    八个导出名与 SQL 总包既有 66 个导出名零碰撞(Z 族为本文件专用)。
--
--    优先次序：§Z-01、§Z-02、§Z-04 三条代价近乎为零，宜立即执行——
--    其读数将直接决定既有六处同名异义登记册是否完备，
--    以及总包与三份 .qmd 是否曾误用备份表。
--    §Z-08 与 §Z-09 次之：前者关乎既有同桌产物是否受污染，
--    后者关乎切日基准与尾秒相位能否成立。
-- ═══════════════════════════════════════════════════════════════════════════
