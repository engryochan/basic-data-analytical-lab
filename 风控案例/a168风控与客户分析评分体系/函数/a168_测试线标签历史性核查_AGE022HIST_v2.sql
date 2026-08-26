-- ══════════════════════════════════════════════════════════════════════════════
--  AGE022-HIST v2 · 第二批（P6~P10）
--  ---------------------------------------------------------------------------
--  v1 撤回：L2/L4/L5 引用了 ods_a168_agent.updatetime —— 该列不存在（W-23）
--           L4 注释称「14 名 age022='1' 代理」—— 实测为 215 名（W-24）
--  ---------------------------------------------------------------------------
--  已由 P1~P5 确立（OBSERVED）：
--    · age022 注释＝「測試線判別」（数据库原文）
--    · ods_a168_agent 46,415 行 / 46,415 代理，每代理仅 1 行 ⇒ 非每日快照
--    · dt 值域 2026-05-19 ~ 2026-08-26，91 个不同值；2026-05-19 正是 bet02 全量重同步之日
--    · 当前 age022='1' 共 215 名 ＝ 205（备份中已为 1）＋ 10（备份中无记录）
--    · 43,240 名交集代理，0→1 与 1→0 翻转【各为 0】
--  ---------------------------------------------------------------------------
--  本批唯一目标：把「静态清洗的泄露敞口」由定性变成【可数的行数】
--    205 名在窗口开始前(2025-06-10)即为测试线 ⇒ 按今日标签剔除其历史注单，非泄露
--     10 名无法由备份验证              ⇒ 这 10 名的注单才是真正的敞口
--    ⇒ 敞口 = 这 10 名在窗口内的注单数 ÷ 全窗注单数
--  纪律：行注释 only · 无 OFFSET · ID 用 CAST(... AS BIGINT) · 全部只读
-- ══════════════════════════════════════════════════════════════════════════════


-- ── P6 · change_log 是否承载 age022 变更（不只搜字段名，须搜业务语义）──
SELECT TRIM(c.function)                                                AS func,
       COUNT(*)                                                        AS n_rows,
       MIN(c.optime)                                                   AS optime_min,
       MAX(c.optime)                                                   AS optime_max,
       SUM(CASE WHEN c.content LIKE '%age022%'  THEN 1 ELSE 0 END)     AS hit_age022,
       SUM(CASE WHEN c.content LIKE '%測試%'    THEN 1 ELSE 0 END)     AS hit_test_tw,
       SUM(CASE WHEN c.content LIKE '%测试%'    THEN 1 ELSE 0 END)     AS hit_test_cn,
       SUM(CASE WHEN c.content LIKE '%agent%'   THEN 1 ELSE 0 END)     AS hit_agent,
       SUM(CASE WHEN c.content LIKE '%代理%'    THEN 1 ELSE 0 END)     AS hit_agent_cn
FROM ods_mariadb_2b.ods_a168_change_log c
GROUP BY TRIM(c.function)
ORDER BY n_rows DESC;


-- ── P7 · agent_test 的 30 名是谁；与当前 age022='1' 的 215 名做集合审计 ──
SELECT CASE WHEN t.aid IS NOT NULL AND a.aid IS NOT NULL THEN '两表皆有'
            WHEN t.aid IS NOT NULL                       THEN '仅 agent_test 有'
            ELSE '仅 age022=1 有' END                                  AS 归属,
       COUNT(*)                                                        AS n_agents
FROM (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent_test
) t
FULL OUTER JOIN (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE TRIM(age022) = '1'
) a ON a.aid = t.aid
GROUP BY 1
ORDER BY n_agents DESC;


-- ── P8 · 215 名当前测试线代理的来源事实（不用 updatetime，改用实有列）──
--    重点看：10 名「备份缺记录」者的 age005（建号时间）是否晚于 2025-06-10
--            若晚 ⇒ 它们是新开的代理，备份缺记录属正常，非状态翻转
SELECT CAST(NULLIF(TRIM(a.age001),'') AS BIGINT)                       AS agent_id,
       TRIM(a.age022)                                                  AS age022,
       TRIM(a.identity)                                                AS identity_code,
       a.dt                                                            AS ods_dt,
       a.sync_time,
       TRIM(a.age005)                                                  AS age005_ts,
       TRIM(a.age012)                                                  AS age012_ts,
       CASE WHEN k.aid IS NULL THEN 'NOT_IN_BAK20250610' ELSE 'IN_BAK' END AS bak_status,
       CASE WHEN TRIM(a.age005) >= '2025-06-10' THEN 'CREATED_AFTER_BAK'
            WHEN TRIM(a.age005) <  '2025-06-10' THEN 'CREATED_BEFORE_BAK'
            ELSE 'AGE005_UNKNOWN' END                                  AS create_position,
       TRIM(a.age024)                                                  AS remark
FROM ods_mariadb_2b.ods_a168_agent a
LEFT JOIN ( SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
            FROM ods_mariadb_2b.ods_a168_agent_bak20250610 ) k
  ON k.aid = CAST(NULLIF(TRIM(a.age001),'') AS BIGINT)
WHERE TRIM(a.age022) = '1'
ORDER BY bak_status, agent_id;


-- ── P9 · ★判决层★ 泄露敞口的【行数量化】──
--    把窗口内每一张受测试线影响的注单，按「其测试线代理能否由备份验证」分类
--    VERIFIED_PRE_WINDOW  该代理在 2025-06-10 备份中已是测试线 ⇒ 剔除非泄露
--    UNVERIFIABLE         该代理不在备份中             ⇒ 这才是敞口
WITH ta AS (
  SELECT CAST(NULLIF(TRIM(a.age001),'') AS BIGINT)                     AS aid,
         CASE WHEN k.aid IS NOT NULL THEN 'VERIFIED_PRE_WINDOW'
              ELSE 'UNVERIFIABLE' END                                  AS verif
  FROM ods_mariadb_2b.ods_a168_agent a
  LEFT JOIN ( SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS aid
              FROM ods_mariadb_2b.ods_a168_agent_bak20250610
              WHERE TRIM(age022) = '1' ) k
    ON k.aid = CAST(NULLIF(TRIM(a.age001),'') AS BIGINT)
  WHERE TRIM(a.age022) = '1'
),
rk AS (
  SELECT b.bet01, b.bet11, b.bet13, b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC)    AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1' AND UPPER(TRIM(b.bet38)) = 'N'
)
SELECT COALESCE(t1.verif, t2.verif, t3.verif, t4.verif, t5.verif, 'NO_TESTLINE') AS testline_verification,
       COUNT(*)                                                        AS n_bets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 6)              AS pct_of_all_bets,
       ROUND(SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0)), 2) AS stake
FROM rk r
LEFT JOIN ta t1 ON t1.aid = CAST(NULLIF(TRIM(r.bet18),'') AS BIGINT)
LEFT JOIN ta t2 ON t2.aid = CAST(NULLIF(TRIM(r.bet19),'') AS BIGINT)
LEFT JOIN ta t3 ON t3.aid = CAST(NULLIF(TRIM(r.bet20),'') AS BIGINT)
LEFT JOIN ta t4 ON t4.aid = CAST(NULLIF(TRIM(r.bet21),'') AS BIGINT)
LEFT JOIN ta t5 ON t5.aid = CAST(NULLIF(TRIM(r.bet22),'') AS BIGINT)
WHERE r.rn = 1
GROUP BY 1
ORDER BY n_bets DESC;


-- ── P10 · dt 分区语义四方互证（R4-SEMANTIC-01）──
--    若 2026-05-19 一日独占绝大多数 ⇒ dt = 首次同步日（存量全部落在开播日）
--    其后逐日零星 ⇒ 新建代理按建号日落分区
--    对照 age005（建号时间戳）可交叉验证
SELECT a.dt,
       COUNT(*)                                                        AS n_agents,
       SUM(CASE WHEN TRIM(a.age022) = '1' THEN 1 ELSE 0 END)           AS n_testline,
       MIN(TRIM(a.age005))                                             AS age005_min,
       MAX(TRIM(a.age005))                                             AS age005_max,
       SUM(CASE WHEN SUBSTR(TRIM(a.age005),1,10) = CAST(a.dt AS STRING)
                THEN 1 ELSE 0 END)                                     AS n_dt_eq_age005
FROM ods_mariadb_2b.ods_a168_agent a
GROUP BY a.dt
ORDER BY n_agents DESC;
