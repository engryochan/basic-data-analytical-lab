-- ============================================================
-- ods_encyclopedia_structural_layer_a168.sql
--
-- 目标库：a168、a168_log（对应 StarRocks ods_a168_bet02 的上游 MySQL 源库）
-- 数据源：DolphinScheduler 源中心 datasource:2
--
-- 版本记录：
--   v1  首次对 a168/a168_log 跑结构层扫描，跑出 agent 表前 10 个字段
--       （age001~age010），发现 age007 是 MUL 索引但没被规则识别到。
--   v2  （本文件）key_candidate 补上 COLUMN_KEY = 'MUL' 分支，标记为
--       INDEXED_CANDIDATE——上一版遗漏了这个信号，130 张表里被索引过
--       的字段大概率不止 agent.age007 一个，这一版重跑才能把它们全部
--       捞出来。
--
-- 用法：作为单独一个 SQL 任务节点的全部内容运行；纯读
-- information_schema，不碰任何真实数据行，对生产库没有额外压力。
-- 结果建议去 DolphinScheduler 网页该 SQL 任务的"结果"标签页整页查看，
-- 不要只看任务日志——130 张表展开后大概率有几千行，日志预览只截前
-- 10 行。
-- ============================================================

SELECT
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    t.TABLE_ROWS,
    t.TABLE_COMMENT,
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.COLUMN_TYPE,
    c.IS_NULLABLE,
    c.COLUMN_KEY,
    c.COLUMN_DEFAULT,
    c.EXTRA,
    c.COLUMN_COMMENT,

    -- Evidence Level：本层上限 L2（字段有无注释）。真正落到 L3 需要
    -- Step 2 的逐表统计扫描去验证实际取值。
    CASE
        WHEN c.COLUMN_COMMENT IS NOT NULL AND TRIM(c.COLUMN_COMMENT) <> '' THEN 'L2'
        ELSE 'L1'
    END AS evidence_level,

    -- Key 候选：PRI/UNI 是确认的主键/唯一键；MUL 代表这个字段被单独建
    -- 了非唯一索引，通常意味着它是外键或者高频过滤/关联字段，值得
    -- 留意——v1 版本漏掉了这一条。
    CASE
        WHEN c.COLUMN_KEY IN ('PRI','UNI') THEN 'PK_UK_CONFIRMED'
        WHEN c.COLUMN_KEY = 'MUL' THEN 'INDEXED_CANDIDATE'
        WHEN LOWER(c.COLUMN_NAME) REGEXP '(^id$|_id$|^eid$|^uid$|_no$|_code$)' THEN 'FK_CANDIDATE'
    END AS key_candidate,

    -- 时间候选
    CASE
        WHEN c.DATA_TYPE IN ('datetime','date','timestamp') THEN 'TIME_CONFIRMED'
        WHEN LOWER(c.COLUMN_NAME) REGEXP '(time|date|^dt$|_dt$)' THEN 'TIME_CANDIDATE'
    END AS time_candidate,

    -- 度量候选（数值类型 + 名称关键字双重条件）
    CASE
        WHEN c.DATA_TYPE IN ('decimal','double','float','int','bigint','smallint','tinyint')
         AND LOWER(c.COLUMN_NAME) REGEXP '(amount|amt|bet|pay|win|loss|rebate|balance|stake|deposit|withdraw|fee|ggr|ngr|profit)'
        THEN 'MEASURE_CANDIDATE'
    END AS measure_candidate,

    -- 维度候选
    CASE
        WHEN c.DATA_TYPE IN ('varchar','char','text','enum')
          OR LOWER(c.COLUMN_NAME) REGEXP '(type|status|code|flag|category|room|level|lv[1-5]|game|currency|channel)'
        THEN 'DIMENSION_CANDIDATE'
    END AS dimension_candidate,

    -- 公式/衍生候选
    CASE
        WHEN LOWER(c.COLUMN_NAME) REGEXP '(rate|ratio|pct|percent|roi|ggr|ngr|cv$|score)'
        THEN 'FORMULA_CANDIDATE'
    END AS formula_candidate,

    'UNKNOWN' AS semantic_role,
    0 AS confidence

FROM information_schema.columns c
JOIN information_schema.tables  t
  ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
WHERE c.TABLE_SCHEMA IN ('a168', 'a168_log')
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION;
