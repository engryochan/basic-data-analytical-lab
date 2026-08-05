-- ============================================================
-- ods_encyclopedia_structural_layer_a168_v3.sql
--
-- v3 相对上一版的改动：
--   1.【核心修正】全部基于字段名关键字的正则，统一改成
--      (^|_)(关键字)($|_) 单词边界匹配。上一版只有 time_candidate 和
--      dimension_candidate 的 BEHAVIORAL_DIMENSION 两处做了边界限定，
--      其余全是裸子串匹配——裸子串在 age001 这种命名风格下问题不大，
--      但只要遇到有意义的英文列名就会假阳性，例如 "rate" 会命中
--      "operate"/"generate"，"table" 会命中 "adjustable"，"win" 会
--      命中 "twin_xxx"。
--   2. TABLE_TYPE 之前只取出来摆着没用，新增 is_base_table 标记
--      （VIEW 的 TABLE_ROWS 在 information_schema 里通常不可靠）。
--   3. evidence_level 原来有两档都叫 "L3"（有注释 / 有主键但无注释），
--      语义不同却撞号，改成 L1~L5 五档，每档唯一含义。
--
-- 已知残留风险（正则改不掉，靠人工复核）：
--   key_candidate/confidence_score 里的 "no" 关键字仍有歧义——
--   "member_no"(编号) 和 "no_deposit_bonus"(无存款红利) 都会命中，
--   语义相反。130 张表结果出来后，人工扫一眼命中 "no" 的字段，
--   剔掉明显不是编号类的即可。
-- ============================================================

SELECT
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    t.TABLE_TYPE,
    CASE WHEN t.TABLE_TYPE = 'BASE TABLE' THEN 1 ELSE 0 END AS is_base_table,
    t.TABLE_ROWS AS estimated_table_rows,
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

    /* =========================================================
       1. 证据等级（L1~L5，无重号）
       ========================================================= */
    CASE
        WHEN c.COLUMN_COMMENT IS NOT NULL
             AND TRIM(c.COLUMN_COMMENT) <> ''
             AND c.COLUMN_KEY IN ('PRI','UNI')
            THEN 'L5_KEY_DOCUMENTED'

        WHEN c.COLUMN_COMMENT IS NOT NULL
             AND TRIM(c.COLUMN_COMMENT) <> ''
            THEN 'L4_DOCUMENTED'

        WHEN c.COLUMN_KEY IN ('PRI','UNI')
            THEN 'L3_KEY_CONFIRMED'

        WHEN c.COLUMN_KEY = 'MUL'
            THEN 'L2_INDEXED'

        ELSE 'L1_NAME_TYPE_INFERENCE'
    END AS evidence_level,

    /* =========================================================
       2. Key 候选
       ========================================================= */
    CASE
        WHEN c.COLUMN_KEY = 'PRI'
            THEN 'PRIMARY_KEY_CONFIRMED'

        WHEN c.COLUMN_KEY = 'UNI'
            THEN 'UNIQUE_KEY_CONFIRMED'

        WHEN c.COLUMN_KEY = 'MUL'
            THEN 'INDEXED_CANDIDATE'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(id|uid|eid|no|code|uuid|guid)($|_)'
            THEN 'IDENTIFIER_CANDIDATE'

        ELSE NULL
    END AS key_candidate,

    /* =========================================================
       3. 时间维度
       ========================================================= */
    CASE
        WHEN LOWER(c.COLUMN_NAME) = 'dt'
            THEN 'BUSINESS_DATE_CANDIDATE'

        WHEN c.DATA_TYPE IN ('datetime','timestamp')
            THEN 'DATETIME_CONFIRMED'

        WHEN c.DATA_TYPE = 'date'
            THEN 'DATE_CONFIRMED'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(time|date|datetime|timestamp|created|updated|create|update)($|_)'
            THEN 'TIME_NAME_CANDIDATE'

        ELSE NULL
    END AS time_candidate,

    /* =========================================================
       4. 金额 / 数值指标
       ========================================================= */
    CASE
        WHEN c.DATA_TYPE IN ('decimal','double','float')
         AND LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(amount|amt|stake|bet|wager|turnover|win|loss|profit|rebate|commission|fee|balance|deposit|withdraw|ggr|ngr|payout)($|_)'
            THEN 'NUMERIC_MEASURE_HIGH'

        WHEN c.DATA_TYPE IN ('int','bigint','smallint','tinyint')
         AND LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(amount|amt|count|number|qty|quantity|balance|score|level|bet|win|loss)($|_)'
            THEN 'NUMERIC_MEASURE_MEDIUM'

        WHEN c.DATA_TYPE IN ('decimal','double','float')
            THEN 'NUMERIC_MEASURE_GENERIC'

        ELSE NULL
    END AS measure_candidate,

    /* =========================================================
       5. 维度
       ========================================================= */
    CASE
        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(type|status|state|flag|category|channel|mode|kind)($|_)'
            THEN 'BEHAVIORAL_DIMENSION'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(game|room|table|dealer|agent|member|player|user|currency|country|region)($|_)'
            THEN 'BUSINESS_DIMENSION'

        WHEN c.DATA_TYPE IN ('varchar','char','text','enum')
            THEN 'TEXT_DIMENSION'

        ELSE NULL
    END AS dimension_candidate,

    /* =========================================================
       6. 公式字段候选
       ========================================================= */
    CASE
        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(rate|ratio|pct|percent|percentage|roi|margin|ggr|ngr)($|_)'
            THEN 'RATE_RATIO_FORMULA_CANDIDATE'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(profit|loss|rebate|commission|payout)($|_)'
            THEN 'DERIVED_FINANCIAL_CANDIDATE'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(score|risk|rating|rank)($|_)'
            THEN 'MODEL_SCORE_CANDIDATE'

        ELSE NULL
    END AS formula_candidate,

    /* =========================================================
       7. 初步 semantic role
       ========================================================= */
    CASE
        WHEN c.COLUMN_KEY = 'PRI'
            THEN 'PRIMARY_IDENTIFIER'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(member|player|uid|user)($|_)'
            THEN 'PLAYER_IDENTIFIER'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(dealer|croupier|eid)($|_)'
            THEN 'DEALER_IDENTIFIER'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(agent|affiliate|lv[1-5])($|_)'
            THEN 'AGENT_HIERARCHY'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(game|game_type)($|_)'
            THEN 'GAME_DIMENSION'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(table|table_id)($|_)'
            THEN 'TABLE_DIMENSION'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(room|room_id)($|_)'
            THEN 'ROOM_DIMENSION'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(currency|fx|exchange|rate)($|_)'
            THEN 'CURRENCY_FX'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(bet|stake|wager|turnover)($|_)'
            THEN 'BETTING_MEASURE'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(win|payout|pay)($|_)'
            THEN 'PAYOUT_MEASURE'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(rebate|commission)($|_)'
            THEN 'REBATE_COMMISSION'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(deposit|withdraw)($|_)'
            THEN 'CASHFLOW_MEASURE'

        WHEN LOWER(c.COLUMN_NAME) REGEXP
             '(^|_)(time|date|dt)($|_)'
            THEN 'TIME_DIMENSION'

        WHEN c.DATA_TYPE IN ('varchar','char','text','enum')
            THEN 'TEXT_ATTRIBUTE'

        WHEN c.DATA_TYPE IN ('decimal','double','float','int','bigint','smallint','tinyint')
            THEN 'NUMERIC_ATTRIBUTE'

        ELSE 'UNKNOWN'
    END AS semantic_role,

    /* =========================================================
       8. 可解释置信度（相对打分，供排序用，不是百分比）
       ========================================================= */
    (
        CASE
            WHEN c.COLUMN_KEY = 'PRI' THEN 35
            WHEN c.COLUMN_KEY = 'UNI' THEN 30
            WHEN c.COLUMN_KEY = 'MUL' THEN 10
            ELSE 0
        END
        +
        CASE
            WHEN c.COLUMN_COMMENT IS NOT NULL AND TRIM(c.COLUMN_COMMENT) <> '' THEN 20
            ELSE 0
        END
        +
        CASE
            WHEN c.DATA_TYPE IN ('datetime','timestamp','date') THEN 15
            ELSE 0
        END
        +
        CASE
            WHEN LOWER(c.COLUMN_NAME) REGEXP '(^|_)(id|uid|eid|no|code|uuid|guid)($|_)' THEN 10
            ELSE 0
        END
        +
        CASE
            WHEN LOWER(c.COLUMN_NAME) REGEXP
                 '(^|_)(member|player|dealer|agent|game|table|room|currency|bet|stake|win|payout|deposit|withdraw)($|_)'
                THEN 10
            ELSE 0
        END
        +
        CASE
            WHEN c.DATA_TYPE IN ('decimal','double','float','int','bigint') THEN 5
            ELSE 0
        END
    ) AS confidence_score

FROM information_schema.columns c
JOIN information_schema.tables t
    ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
   AND t.TABLE_NAME = c.TABLE_NAME
WHERE c.TABLE_SCHEMA IN ('a168','a168_log')
ORDER BY
    c.TABLE_SCHEMA,
    c.TABLE_NAME,
    c.ORDINAL_POSITION;
