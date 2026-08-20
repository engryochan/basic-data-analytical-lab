-- ═════════════════════════════════════════════════════════════════════════
-- a168 取数与核验 SQL 总包 · v10 斧正补丁【增补件】
-- 作者：Ryo Eng（雷欧）        日期：2026-08-20
-- ─────────────────────────────────────────────────────────────────────────
-- 【本增补件之由来】2026-08-20 两段断言回件裁决所生之两项待办：
--   ▸ §P11c-chk1 实测 n_mismatch = 960（n_rows = 124,731,833，匹配率 99.99923%，
--     n_both_null = n_null_asym = 0）——「bet41 ≡ validbet」由 100% 恒等
--     降为「99.99923% 一致，960 笔例外，成因 UNKNOWN」。降级须有证，chk1 即证。
--     本件 §P11c-chk2 取该 960 笔逐笔定性，为成因判明提供底料。
--   ▸ chk1 断言域 124,731,833 与 §P11c 全量洁净域 124,713,543 相差 18,290 笔，
--     即七闸合计仅剔除 0.014663%。考虑 214 条测试线代理在册，此剔除率偏低。
--     本件 §P11c-chk3 逐闸计数，澄清究系测试线本就注单稀少，抑或某闸未生效。
-- 【v2 勘误（2026-08-20，实测报错后斧正）】
--   StarRocks 报：Not support exists correlation subquery with Non-EQ predicate.
--   根因：v1 于 chk2 之 in_clean 与 chk3 之 g3_noagent 两处，以
--     NOT EXISTS (SELECT 1 FROM test_agents t WHERE t.agent_id IN (外层五列))
--   判定测试线。该式系「相关子查询 ＋ 非等值谓词」，StarRocks 方言不支持——
--   本项目铁律原已明载「禁 EXISTS ＋ 多列 IN」，v1 误以为「单列 IN 多个外层值」
--   不在禁列，实则同禁。斧正：两处一律改回五路 LEFT JOIN ＋ COALESCE(...) IS NULL，
--   与 §R01／§P11c 同法同源。判定语义逐字不变，仅换实现。
-- 【纪律】两段皆为独立整句，各自单独执行；行注释；无 OFFSET；字面值；
--   零行须显式记录——零行不是无异常。成因判明前，两项一律挂 UNKNOWN。
-- ═════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- §P11c-chk2 · bet41 ≠ validbet 之 960 笔逐笔定性（全量导出，不抽样）
-- ▸ 导出：需要 —— 存为「数据库/P11c_chk2_bet41_mismatch_rows.csv」
-- ▸ 读法：差值 d = bet41 − validbet。看四件事——
--   ① 符号：全正／全负／双向（全正指向「bet41 含额外计入」，全负反之，
--      双向则指向随机性差错或多机制并存）；
--   ② 量级：|d| 之分布与 d/validbet 相对幅度（微量指向舍入或精度，
--      整额指向业务机制）；
--   ③ 聚集：是否集中于特定 dt／桌号／币种／玩法／会员——聚集即有机制，
--      弥散即偏随机；
--   ④ 是否落在洁净域内（in_clean 列）——落在域外者不影响 §P11c 总帐读数。
-- ▸ 铁律：本件只出事实，不出成因。任何「舍入误差」「和局退注」之类说法，
--   在本件读数支持之前一律属推测，禁写入交付文档。
-- ─────────────────────────────────────────────────────────────────────────
WITH test_agents AS (                                                                               -- 公共表表达式：测试线代理名单（与 §R01／§P11c 同源同构）
    SELECT age001 AS agent_id                                                                       -- 取列：产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：代理主档
    WHERE age022 = '1'                                                                              -- 铁律④b：公司测试线
),                                                                                                  -- 续行：收束子查询括号
ranked AS (                                                                                         -- 同单号保留最新版本（断言域与 chk1 完全一致：仅窗口＋百家乐＋去重）
    SELECT b.bet01, b.bet02, b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                           -- 取列：定性所需列集（bet09 玩法用于机制聚集检查）
           b.bet11, b.bet13, b.bet14, b.bet16, b.bet41, b.validbet,                                 -- 续行：汇率、金额、返水、洗码两列
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet38, b.bet39,                           -- 续行：五级代理线、测试标识、桌号
           b.category, b.dt,                                                                        -- 续行：结算类别、营业日
           ROW_NUMBER() OVER (PARTITION BY b.bet01                                                  -- 行号窗口：按单号去重
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：最新版本置首；导出必带排序
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- ★ 表名开关
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：窗口与主件完全一致
),                                                                                                  -- 续行：收束子查询括号
latest AS (                                                                                         -- 仅最新版本行，并强类型化两列
    SELECT r.bet01, r.bet03, r.bet04, r.bet05, r.bet08, r.bet09, r.bet39, r.dt,                     -- 取列：定性维度
           r.category, r.bet38,                                                                     -- 续行：结算类别与测试标识（供 in_clean 判定）
           r.bet18, r.bet19, r.bet20, r.bet21, r.bet22,                                             -- 续行：五级代理线（供 in_clean 判定）
           CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))    AS fx,                                -- 取值表达式：汇率强类型化，产出「fx」
           CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))    AS stake_raw,                         -- 取值表达式：注额原币，产出「stake_raw」
           CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))    AS payout_raw,                        -- 取值表达式：派彩原币，产出「payout_raw」
           CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))    AS rebate_raw,                        -- 取值表达式：返水原币，产出「rebate_raw」
           CAST(NULLIF(TRIM(r.bet41),   '') AS DECIMAL(20,4)) AS v41,                               -- 取值表达式：bet41 强类型化，产出「v41」
           CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vvb,                               -- 取值表达式：validbet 强类型化，产出「vvb」
           CASE WHEN COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                -- 条件分支：五级任一命中测试线即为 1——
                              t4.agent_id, t5.agent_id) IS NULL                                     -- 续行：v2 斧正，以左连接加空值判定替代 EXISTS
                THEN 0 ELSE 1 END                              AS has_test_agent                    -- 续行：产出「has_test_agent」
    FROM ranked r                                                                                   -- 取数来源：中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左连接：一级代理线
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左连接：二级代理线
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左连接：三级代理线
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左连接：四级代理线
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左连接：五级代理线
    WHERE r.rn = 1                                                                                  -- 过滤条件：仅最新版本
),                                                                                                  -- 续行：收束子查询括号
mism AS (                                                                                           -- 不匹配行：与 chk1 之 n_mismatch 定义逐字一致（含 NULL 单侧态）
    SELECT l.*,                                                                                     -- 取列：透传全部定性维度
           l.v41 - l.vvb                                     AS d,                                  -- 取值表达式：差值 d = bet41 − validbet，产出「d」
           CASE WHEN l.vvb IS NULL OR l.vvb = 0 THEN NULL                                           -- 条件分支：分母为空或零则不计相对幅度
                ELSE (l.v41 - l.vvb) / l.vvb END             AS d_rel,                              -- 续行：相对幅度，产出「d_rel」
           CASE WHEN (l.v41 IS NULL) <> (l.vvb IS NULL) THEN 'NULL_ASYM'                            -- 条件分支：单侧为空
                WHEN l.v41 > l.vvb THEN 'POS'                                                       -- 续行：bet41 偏大
                WHEN l.v41 < l.vvb THEN 'NEG'                                                       -- 续行：bet41 偏小
                ELSE 'EQ' END                                AS diff_kind                           -- 续行：差异类型，产出「diff_kind」
    FROM latest l                                                                                   -- 取数来源：中间结果集 latest
    WHERE (l.v41 IS NULL) <> (l.vvb IS NULL)                                                        -- 过滤条件：单侧为空
       OR (l.v41 IS NOT NULL AND l.vvb IS NOT NULL AND l.v41 <> l.vvb)                              -- 或：双非空且值不等
)                                                                                                   -- 续行：收束子查询括号
SELECT                                                                                              -- 主查询：960 笔逐笔明细（全量，不抽样、不分页）
    m.bet01                                                  AS bet_id,                             -- 取值表达式：注单号，产出「bet_id」
    m.dt                                                     AS biz_date,                           -- 取值表达式：营业日，产出「biz_date」
    m.bet08                                                  AS bet_time,                           -- 取值表达式：下注时间，产出「bet_time」
    m.bet39                                                  AS table_id,                           -- 取值表达式：桌号，产出「table_id」
    m.bet03                                                  AS shoe_id,                            -- 取值表达式：靴号，产出「shoe_id」
    m.bet04                                                  AS round_no,                           -- 取值表达式：局内序号，产出「round_no」
    m.bet05                                                  AS member_id,                          -- 取值表达式：会员号，产出「member_id」
    m.bet09                                                  AS play_type,                          -- 取值表达式：玩法（庄／闲／和／对子等），产出「play_type」
    m.fx                                                     AS fx_rate,                            -- 取值表达式：汇率，产出「fx_rate」；币种代理量
    m.stake_raw                                              AS stake_raw,                          -- 取值表达式：注额原币
    m.payout_raw                                             AS payout_raw,                         -- 取值表达式：派彩原币
    m.rebate_raw                                             AS rebate_raw,                         -- 取值表达式：返水原币
    m.v41                                                    AS bet41_val,                          -- 取值表达式：bet41 值，产出「bet41_val」
    m.vvb                                                    AS validbet_val,                       -- 取值表达式：validbet 值，产出「validbet_val」
    m.d                                                      AS diff_abs,                           -- 取值表达式：差值，产出「diff_abs」
    m.d_rel                                                  AS diff_rel,                           -- 取值表达式：相对幅度，产出「diff_rel」
    m.diff_kind                                              AS diff_kind,                          -- 取值表达式：差异类型，产出「diff_kind」
    CASE WHEN m.category = '1'                                                                      -- 条件分支：是否落在 §P11c 全量洁净域内——
          AND UPPER(TRIM(m.bet38)) = 'N'                                                            -- 续行：已结算＋非测试单
          AND CAST(NULLIF(TRIM(m.bet05),'') AS BIGINT) > 0                                          -- 续行：会员号守卫
          AND m.fx > 0                                                                              -- 续行：汇率守卫
          AND CAST(NULLIF(TRIM(m.bet04),'') AS INT) > 0                                             -- 续行：局号守卫
          AND NULLIF(TRIM(m.bet08),'') IS NOT NULL                                                  -- 续行：下注时间守卫
          AND m.has_test_agent = 0                                                                  -- 续行：五级代理线皆非测试线（v2 斧正：改用左连接旗标，不用 EXISTS）
         THEN 1 ELSE 0 END                                   AS in_clean,                           -- 续行：产出「in_clean」；为 0 者不影响 §P11c 总帐读数
    'bet41_ne_validbet_v1'                                   AS chk_def                             -- 取值表达式：口径锁列（SQL 原生），产出「chk_def」
FROM mism m                                                                                         -- 取数来源：中间结果集 mism
ORDER BY m.dt, m.bet39, m.bet03, m.bet04, m.bet01;                                                  -- 排序：按日期、桌、靴、局、单号；导出必带排序，否则无稳定序


-- ─────────────────────────────────────────────────────────────────────────
-- §P11c-chk3 · 七闸分闸剔除量（澄清 18,290 笔之归属）
-- ▸ 导出：需要 —— 存为「数据库/P11c_chk3_gate_attrition.csv」
-- ▸ 读法：本件出两组数——
--   ① 单闸口径（gate_only_*）：仅该闸不通过之行数，各闸独立计、可重叠、不可加；
--   ② 累进口径（cum_after_*）：按 §P11c 实际闸序逐闸累加后之存活行数，可作漏斗读。
--   两组并出，方能分辨「某闸剔除少」究系其本就少，抑或被前闸抢先剔除。
-- ▸ 铁律：单闸列之和 ≠ 总剔除量（行可同时不通过多闸），禁作加总。
-- ─────────────────────────────────────────────────────────────────────────
WITH test_agents AS (                                                                               -- 公共表表达式：测试线代理名单
    SELECT age001 AS agent_id                                                                       -- 取列：产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：代理主档
    WHERE age022 = '1'                                                                              -- 铁律④b：公司测试线
),                                                                                                  -- 续行：收束子查询括号
ranked AS (                                                                                         -- 同单号保留最新版本
    SELECT b.bet01, b.bet04, b.bet05, b.bet08, b.bet11, b.bet38, b.category,                        -- 取列：分闸判定所需最小列集
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                             -- 续行：五级代理线
           ROW_NUMBER() OVER (PARTITION BY b.bet01                                                  -- 行号窗口：按单号去重
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：最新版本置首
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- ★ 表名开关
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：窗口与主件完全一致
),                                                                                                  -- 续行：收束子查询括号
flagged AS (                                                                                        -- 逐行打七面闸旗（1 = 通过该闸）
    SELECT r.bet01,                                                                                 -- 取列：注单号
           CASE WHEN r.category = '1' THEN 1 ELSE 0 END                              AS g1_settled, -- 条件分支：闸一·已结算，产出「g1_settled」
           CASE WHEN UPPER(TRIM(r.bet38)) = 'N' THEN 1 ELSE 0 END                    AS g2_nontest, -- 条件分支：闸二·非测试单，产出「g2_nontest」
           CASE WHEN COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                -- 条件分支：闸三·五级代理线无测试线——
                              t4.agent_id, t5.agent_id) IS NULL                                     -- 续行：v2 斧正，五路左连接加空值判定（StarRocks 不支持相关 EXISTS 配非等值谓词）
                THEN 1 ELSE 0 END                                                    AS g3_noagent, -- 续行：产出「g3_noagent」
           CASE WHEN CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0 THEN 1 ELSE 0 END  AS g4_member,  -- 条件分支：闸四·会员号守卫，产出「g4_member」
           CASE WHEN CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                            -- 条件分支：闸五·汇率守卫
                THEN 1 ELSE 0 END                                                    AS g5_fx,      -- 续行：产出「g5_fx」
           CASE WHEN CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0 THEN 1 ELSE 0 END     AS g6_round,   -- 条件分支：闸六·局号守卫，产出「g6_round」
           CASE WHEN NULLIF(TRIM(r.bet08),'') IS NOT NULL THEN 1 ELSE 0 END          AS g7_bettime  -- 条件分支：闸七·下注时间守卫，产出「g7_bettime」
    FROM ranked r                                                                                   -- 取数来源：中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左连接：一级代理线
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左连接：二级代理线
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左连接：三级代理线
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左连接：四级代理线
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左连接：五级代理线
    WHERE r.rn = 1                                                                                  -- 过滤条件：仅最新版本（闸零已在此施行）
)                                                                                                   -- 续行：收束子查询括号
SELECT                                                                                              -- 主查询：分闸漏斗一行出
    COUNT(*)                                                                    AS n_after_dedup,   -- 计数表达式：去重后基数（＝chk1 之 n_rows），产出「n_after_dedup」
    SUM(1 - g1_settled)                                                         AS only_g1_settled, -- 汇总表达式：单闸·未结算行数（可重叠、不可加）
    SUM(1 - g2_nontest)                                                         AS only_g2_nontest, -- 汇总表达式：单闸·测试单行数
    SUM(1 - g3_noagent)                                                         AS only_g3_noagent, -- 汇总表达式：单闸·测试线代理行数——214 代理之实际影响面即此数
    SUM(1 - g4_member)                                                          AS only_g4_member,  -- 汇总表达式：单闸·会员号非正行数
    SUM(1 - g5_fx)                                                              AS only_g5_fx,      -- 汇总表达式：单闸·汇率非正行数
    SUM(1 - g6_round)                                                           AS only_g6_round,   -- 汇总表达式：单闸·局号非正行数
    SUM(1 - g7_bettime)                                                         AS only_g7_bettime, -- 汇总表达式：单闸·下注时间为空行数
    SUM(g1_settled)                                                             AS cum_after_g1,    -- 汇总表达式：累进·过闸一后存活
    SUM(g1_settled * g2_nontest)                                                AS cum_after_g2,    -- 汇总表达式：累进·过闸二后存活
    SUM(g1_settled * g2_nontest * g3_noagent)                                   AS cum_after_g3,    -- 汇总表达式：累进·过闸三后存活
    SUM(g1_settled * g2_nontest * g3_noagent * g4_member)                       AS cum_after_g4,    -- 汇总表达式：累进·过闸四后存活
    SUM(g1_settled * g2_nontest * g3_noagent * g4_member * g5_fx)               AS cum_after_g5,    -- 汇总表达式：累进·过闸五后存活
    SUM(g1_settled * g2_nontest * g3_noagent * g4_member * g5_fx * g6_round)    AS cum_after_g6,    -- 汇总表达式：累进·过闸六后存活
    SUM(g1_settled * g2_nontest * g3_noagent * g4_member * g5_fx                                    -- 汇总表达式：累进·过闸七后存活——
        * g6_round * g7_bettime)                                                AS cum_after_g7,    -- 续行：此数须等于 §P11c 全量洁净域 n_orders，不等即有闸未对齐
    SUM(CASE WHEN g1_settled * g2_nontest * g3_noagent * g4_member                                  -- 汇总表达式：全闸不通过总数——
             * g5_fx * g6_round * g7_bettime = 0 THEN 1 ELSE 0 END)             AS n_dropped_total, -- 续行：此数须等于 n_after_dedup − cum_after_g7
    'gate_attrition_v1'                                                         AS chk_def          -- 取值表达式：口径锁列（SQL 原生），产出「chk_def」
FROM flagged;                                                                                       -- 取数来源：中间结果集 flagged
-- ═════════════════════════════════════════════════════════════════════════
-- 增补件终。两段结果回传后，方可对 960 笔与 18,290 笔各出裁定；
-- 在此之前，二者一律 UNKNOWN，禁以推测填补。
-- ═════════════════════════════════════════════════════════════════════════
