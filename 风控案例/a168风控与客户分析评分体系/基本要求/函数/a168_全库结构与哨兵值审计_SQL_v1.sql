/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  a168 · 全库结构剖析与哨兵值审计 SQL                                        ║
   ║  编号族：§Z-xx（Zero／零层）—— 避开总包既用之 C／S／R／T／D／E／K／V／       ║
   ║          P0／TL／DX／EV／B01／A／I／L／X 各族，杜绝编号命名空间碰撞          ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  作者：Ryo Eng                                                            ║
   ║  日期：2026-08-13                                                         ║
   ║  库  ：ods_mariadb_2b（StarRocks，经 Superset SQL Lab 只读访问）           ║
   ║  身份：诊断类 SQL，非正式交付物；正式交付物永久锁定为三份                     ║
   ╚═══════════════════════════════════════════════════════════════════════════╝

   ═══ 本文件之定位 ═══════════════════════════════════════════════════════════
     Ryo Eng 令：`bet39` 与既往所列之十二项哨兵值「只是举例一部份」，
     须核实、校对、审计**所有**数据表内容。
     本文件据此设计：**一律不预设候选清单**，改由 INFORMATION_SCHEMA 自动生成
     逐列普查语句，令哨兵值因其异常高频而自行现形。手拟清单必漏，此为通则。

   ═══ 执行次序（不可倒序，铁律）═════════════════════════════════════════════
     §Z-01 表清单        →  §Z-02 排除清单  →  §Z-03 字段字典
       →  §Z-04 同名异义侦测  →  §Z-05 类型缺注侦测
       →  §Z-06 生成逐列普查语句  →  §Z-07 执行普查（分批）
       →  §Z-08 局键塌缩检验      →  §Z-09 时间字段口径核验
       →  §Z-10 哨兵值定性（须问上游）→ §Z-11 影响量化 → §Z-12 锁定
     结构剖析 → 列剖析 → 关系剖析 → 口径固化 → 取数下载 → 分析。
     §Z-10 为唯一无法自数据闭合者，须携 §Z-07 之具体读数向上游查询业务成因。

   ═══ 纪律（承 SQL 总包卷首，逐条适用）═══════════════════════════════════════
     ① 每条查询自包含、零占位符，整段复制即可运行；
     ② 逐条提交，禁批量 —— 批量产生僵尸查询，拖垮集群；
     ③ 导出必带 ORDER BY —— 无稳定排序之分页曾致 36.49% 重复行；
     ④ 导出上限 1,000 行时只承认排序头部结论，「未出现」类判断一律无效
        （LIMIT 产生的是样本，不是全集）；
     ⑤ 翻页一律取唯一键为序，**不得使用 OFFSET**；
     ⑥ 每条语句有且仅有一条导出声明；标「不需要」者不含文件名；
     ⑦ 注释内不写分号，块注释内不出现星号紧邻斜杠。

   ═══ 导出命名规约（与 SQL 总包一致）═══════════════════════════════════════
     一律存入「数据库/」目录，英文短名，前缀 Z 系列，与总包 66 个导出名零碰撞。
     读取端沿用既定编码自适应读取器：UTF-8-sig → UTF-8 → GB18030 → GBK
     → Big5 → Latin1；R 与 Python 两侧共用同一 DATA_DIR 常量。

   ═══ 已知待验事项（显式列示，未跑不得下结论）═══════════════════════════════
     待-01  `bet07`（帳務日期）与 `dt`（分区日）、`DATE(bet08)` 三者关系未验。
            受影响 SQL：§Z-09。
            受影响产出：一切「日／月／滚动窗口」聚合之切日基准。
            备注：总包现行一律以 `dt` 切日。若 §Z-09 证三者一致，则总包做法
                  已然正确，无须改动；本项此前被误列为「斧正项」，现降为待验。
     待-02  局键 `bet03 + bet04 + bet39` 之唯一性未验。
            受影响 SQL：§Z-08。
            受影响产出：同桌共现、对打配对、玩家局级胜负和之全部结论，
                  含既有产物 `候选_同桌异常_最终版_已去重.csv`。
     待-03  哨兵值之业务成因未知（字段未采集／不适用／ETL 故障／尚未发生）。
            受影响 SQL：§Z-10 之后全部。
            解除条件：向上游取得各异常取值之语义说明。
   ========================================================================= */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-00 · 会话参数（每个 Superset 会话开跑前逐条单跑一次）
   ▸ 导出：不需要 —— 会话参数设置，无结果集
   ═══════════════════════════════════════════════════════════════════════════ */
SET SESSION query_timeout = 259200;
SET SESSION cbo_cte_reuse = true;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-01 · 全库表清单与规模
   用途：确立审计范围与分批次序。TABLE_ROWS 为估计值，仅用于排序，不作结论。
   ▸ 导出：需要 —— 存为「数据库/Z01_table_inventory.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-02 · 排除清单（备份／测试／临时／副本表）
   用途：此清单须写入全案「禁用表」名录。已知实例：ods_a168_agent_bak20250610、
         ods_a168_agent_test、ods_a168_game_demoipsetting。
   判读：凡列入者，一律不得进入任何分析；若某分析已引用之，须整体重跑。
   ▸ 导出：需要 —— 存为「数据库/Z02_excluded_tables.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-03 · 全库字段字典（含 source_type 解析）
   用途：本表即数据字典之基底，落盘存档后，作为一切字段引用之**唯一依据**。
   要点：本库全部字段以 varchar 存储，真实类型仅存于 COLUMN_COMMENT 之
         `source_type=` 前缀。凡涉数值或时间比较，须先查此表确定原始类型，
         再行显式 CAST，**不得凭字段名臆测**。
   ▸ 导出：需要 —— 存为「数据库/Z03_column_dictionary.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-04 · 同名异义自动侦测（★ 本文件最关键之一条）
   用途：一次列出全库所有「同一列名、不同业务含义」之字段，
         不必再靠人逐一撞见。已知六处（bet14、bet01/bet02 自 bet14 起整段错位、
         bet31/bet32 与 bet39/bet40、member.mem015 与 member_dtl.mem015、
         member.mem015 自身、game_log.region 注释为「國家」）应由本条全数覆盖，
         且极可能另有未知者。
   判读：释义数 ≥ 2 者即为同名异义；类型数 ≥ 2 者风险更高——不仅义异，且型异，
         跨表复用同一段 SQL 必致静默错误。
   ▸ 导出：需要 —— 存为「数据库/Z04_name_collision.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-05 · 类型缺注与注释缺失侦测
   用途：凡 COLUMN_COMMENT 为空或无 source_type 前缀者，其真实类型无从判定，
         一切 CAST 皆属臆测。此清单即「不得使用之字段」名录。
   ▸ 导出：需要 —— 存为「数据库/Z05_missing_typehint.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-06 · 生成逐列高频值普查语句（★ 令哨兵值自行现形）
   原理：真实业务取值在秒级或金额级上近乎连续，任一具体取值之占比极低；
         哨兵值则表现为单点尖峰。故取每列高频前 20，异常者自现，
         **不预设 -1／0／unknown／1970-01-01 之类候选清单**——
         手拟必漏，且会遗漏 9999-12-31、1900-01-01、'N/A'、'null' 字符串、
         -999、全角空格等未曾预料者。
   用法：先跑本条**生成** SQL，再逐条执行其输出（承纪律②，禁批量）。
   分批：若表数逾百，先依 §Z-01 之估计行数与业务重要性排序，分批执行。
   ▸ 导出：需要 —— 存为「数据库/Z06_generated_probe_sql.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-07 · 普查执行样例（以注单主表示范；其余各表由 §Z-06 生成）
   判读准则（三条，缺一不可）：
     一、单点尖峰：某具体取值之占比较其邻近取值高出数个量级者，列为候选；
     二、语义可疑：取值形如 -1／0／-999／'unknown'／'N/A'／'null'／
         1970-01-01／0000-00-00／9999-12-31／1900-01-01 者，列为候选；
     三、跨列共现：候选行在其余字段是否同步异常——若是，则为系统填充之空行；
         若仅此一列异常，则更可能为 ETL 故障。二者成因不同，处置亦不同。
   ▸ 导出：需要 —— 存为「数据库/Z07_probe_bet02.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT 'ods_a168_bet02' AS t, 'bet03' AS c, CAST(bet03 AS VARCHAR) AS v,
       COUNT(*) AS n, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet04', CAST(bet04 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet39', CAST(bet39 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'eid', CAST(eid AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'gametype', CAST(gametype AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'commission', CAST(commission AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'category', CAST(category AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet09', CAST(bet09 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet10', CAST(bet10 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet11', CAST(bet11 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
ORDER BY 1, 2, 4 DESC;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-08 · 局键唯一性与塌缩检验（对应「待-02」·风险最高之一条）
   何以要紧：局键为 bet03 + bet04 + bet39。若三者任一含哨兵值，
         则所有此类注单将被拼成同一「局键」（如 -1|-1|-1），
         **成千上万笔互不相干之注单被聚合为同一局**。
         其后果：该「局」参与会员数暴增，同桌共现于此局产生天量虚假配对；
         玩家局级胜负判定亦全盘错乱。
   须查者：既有产物 `候选_同桌异常_最终版_已去重.csv` 是否已受此污染。
   附带核验：bet03 单列是否已全局唯一——若是，则 bet39 在键中为冗余项。
   ▸ 导出：需要 —— 存为「数据库/Z08_roundkey_integrity.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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

/* 配套：局键规模排行（若榜首出现 -1|-1|-1 之类且注单数远超其余，即坐实塌缩）
   ▸ 承上条之诊断，本注释块不单独计为一条语句 */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-09 · 时间字段口径核验（对应「待-01」）
   何以要紧：本项目一切「日／月／滚动 30 日」聚合，皆须先确定切日基准。
         候选有三：`dt`（StarRocks 分区日）、`bet07`（帳務日期）、
         `DATE(bet08)`（下注日）。SQL 总包现行一律以 `dt` 切日。
   判读准则：
     · 三数若同为行数，则三者一致，议题消解，**总包现行做法正确，不必改动**；
     · 若 dt = bet07 恒成立而两者皆异于下注日，则 dt 已承载账务日语义，仍不必改；
     · 唯有当 bet07 与 dt 分歧显著时，方须讨论切日基准之更换。
   附带：bet06（開局時間）与 bet08 之差值分布，可一并回答三事——
         bet06 究为「开放下注」抑或「开牌」、下注时长是否恒定、两者时区是否一致。
         若差值集中于 0 至 30 秒，则 bet06 在下注之前且时长约 30 秒；
         若集中于 28800 秒上下，则时区不一致，尾秒相位计算将整体错八小时。
   ▸ 导出：需要 —— 存为「数据库/Z09_time_axis_recon.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-10 · 哨兵值定性登记（须携 §Z-07 读数向上游查询后填写）
   本条为**表格模板**，非查询。哨兵值之业务成因无法自数据闭合，
   须逐项向上游确认后，方可决定处置。
   登记字段（十二项，缺一不可）：
     table / column / sentinel_value / row_count / pct / co_anomaly（跨列共现）
     / semantic（业务成因）/ source（谁确认的）/ disposition（剔除／分离／保留）
     / rationale / affected_output / decided_at
   处置对照：
     字段未采集         → 剔除，但须报告剔除量
     该场景下不适用     → 分离，单独分析
     ETL 故障           → 剔除，并向上游报缺陷
     尚未发生（如未结算）→ **不可剔除**，另立状态；剔除将造成选择性偏差
   处置策略（分两派，按字段风险择用）：
     局键三要素 bet03／bet04／bet39 → 装载层一律转 NULL 并剔除
       （局键塌缩之害太重，不容任何遗漏渗入下游）
     荷官／代理等维度字段          → 保留原值另设标志列
       （成因未明，或有单独分析之价值），并加锁定列使旧版产物在导入时强制报错
   ▸ 导出：不需要 —— 登记模板，无结果集
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-11 · 哨兵值处置前后影响量化
   用途：处置一经裁定，须以本条量化其影响，方可对外声明。
   注意：「每局最大会员数」与「同桌共现配对数」两项对局键塌缩最敏感，
         其前后差额即虚假配对之规模。
   前提：本条须待 §Z-10 裁定后方可填入具体排除条件；当前先出「未处置」侧读数，
         作为基线。
   ▸ 导出：需要 —— 存为「数据库/Z11_sentinel_impact.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
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


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-12 · 锁定（承既有 late_def 之例）
   本条为纪律陈述，非查询。
   哨兵值处置一经裁定，须于装载层落地，并加**口径锁定列**，
   使不合口径之旧版产物在导入时**强制报错，而非静默通过**。
   既有实例：`late_def` 锁定列——尾靴判据自 round_no >= 50 改为 shoe_pos >= 0.80 后，
   新增该列，令旧版 CSV 在导入时报错。此设计优于纯标志列，
   因其不依赖下游之自觉。
   旧版产物一律重命名为 `_v1_superseded` 后缀存档，**禁止直接删除**。
   ▸ 导出：不需要 —— 纪律陈述，无结果集
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   导出汇总（与语句一一对应）
     §Z-00  不需要                §Z-07  数据库/Z07_probe_bet02.csv
     §Z-01  数据库/Z01_table_inventory.csv    §Z-08  数据库/Z08_roundkey_integrity.csv
     §Z-02  数据库/Z02_excluded_tables.csv    §Z-09  数据库/Z09_time_axis_recon.csv
     §Z-03  数据库/Z03_column_dictionary.csv  §Z-10  不需要
     §Z-04  数据库/Z04_name_collision.csv     §Z-11  数据库/Z11_sentinel_impact.csv
     §Z-05  数据库/Z05_missing_typehint.csv   §Z-12  不需要
     §Z-06  数据库/Z06_generated_probe_sql.csv
   八个导出名与 SQL 总包既有 66 个导出名**零碰撞**（Z 族为本文件专用）。

   优先次序：§Z-01、§Z-02、§Z-04 三条代价近乎为零，宜立即执行——
   其读数将直接决定既有六处同名异义登记册是否完备，
   以及总包与三份 .qmd 是否曾误用备份表。
   §Z-08 与 §Z-09 次之：前者关乎既有同桌产物是否受污染，
   后者关乎切日基准与尾秒相位能否成立。
   ═══════════════════════════════════════════════════════════════════════════ */
