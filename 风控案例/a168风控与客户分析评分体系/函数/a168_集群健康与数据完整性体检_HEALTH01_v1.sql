-- ══════════════════════════════════════════════════════════════════════════════
--  HEALTH-01 · 集群健康 ＋ 数据完整性体检（每次重导前必跑）
--  ---------------------------------------------------------------------------
--  背景：2026-08-26 BE 172.31.94.175(10265) 与 172.31.89.70(10266) 相继
--        alive:false / inBlacklist:true。节点降级期间的查询结果不可全信，
--        故须在重导前用【已知答案】自证集群返回完整数据。
--  用法：H1~H3 看节点状态；H4~H6 是【已知答案对账】，数字对上才准重导。
--  纪律：行注释 only · 无 OFFSET · 全部只读
-- ══════════════════════════════════════════════════════════════════════════════


-- ── H1 · 各 BE 节点存活与磁盘（Alive 须全为 true）──
SHOW BACKENDS;


-- ── H1b · ★黑名单本身★ 谁在黑名单里、还剩多久 ──
--    2026-08-26 实测：BE:10266 曾出现 alive:TRUE 而 inBlacklist:true
--    ⇒ 节点已自行复活，只是黑名单尚未同步清除 ⇒ 黑名单【不是永久的】
SHOW BACKEND BLACKLIST;
--    若某 BE 已 alive:true 却仍在名单内，可手动移出（须管理员权限）：
--      DELETE BACKEND BLACKLIST "10265";
--      DELETE BACKEND BLACKLIST "10266";
--    该语法为 StarRocks 3.3+ 提供；若报语法错，说明版本较低，
--    只能等 FE 自动重试（由 FE 参数 black_host_history_sec 控制），或请运维处理。


-- ── H2 · FE 节点状态 ──
SHOW FRONTENDS;


-- ── H3 · 副本健康：有无不健康 / 缺副本的 tablet ──
SHOW PROC '/statistic';


-- ── H4 · ★已知答案① 全窗原始行数，必须 = 125,654,711 ──
SELECT COUNT(*)                                                        AS n_raw,
       COUNT(DISTINCT bet01)                                           AS n_distinct_bet01,
       COUNT(*) - COUNT(DISTINCT bet01)                                AS n_dup_rows
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101';
--    期望：125,654,711 · 124,731,833 · 922,878
--    任一不符 ⇒ 集群返回不完整，禁止重导


-- ── H5 · ★已知答案② 清洗后行数与四类哨兵，必须逐位相符 ──
SELECT COUNT(*)                                                        AS n_win,
       SUM(CASE WHEN category <> '1'                THEN 1 ELSE 0 END) AS n_category_ne1,
       SUM(CASE WHEN UPPER(TRIM(bet38)) <> 'N'      THEN 1 ELSE 0 END) AS n_void,
       COUNT(DISTINCT CAST(NULLIF(TRIM(bet05),'') AS BIGINT))          AS n_member
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101';
--    期望：125,654,711 · 5,564 · 1,014 · 723,557


-- ── H6 · ★已知答案③ 代理与会员维表基数 ──
SELECT (SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_agent)            AS n_agent_rows,
       (SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_agent
         WHERE TRIM(age022) = '1')                                     AS n_testline,
       (SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_agent_bak20250610) AS n_agent_bak;
--    期望：46,415 · 215 · 43,244
