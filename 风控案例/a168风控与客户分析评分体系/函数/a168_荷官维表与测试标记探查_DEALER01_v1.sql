-- ══════════════════════════════════════════════════════════════════════════════
--  DEALER-01 · 荷官维表与「荷官测试线」标记探查（待集群恢复后再跑）
--  ---------------------------------------------------------------------------
--  查证起因：先生指令「会员测试线、荷官测试线、代理测试线持续标记着」。
--  包内现状实测：
--    代理测试线  ods_a168_agent.age022      已实装（五级链，174 处引用）
--    会员测试线  ods_a168_member.mem019     字段存在，实测全表单值 'N'，未实装
--    荷官测试线  ★ 包内【无任何荷官维表连接】
--                x_dealer = b.eid，直接取自 ods_a168_bet02，从不 JOIN 维表
--                ods_a168_employee 仅在字典件里被 COUNT(*)，未取任何字段
--  ⇒ 「荷官测试线」这个标记目前【没有数据来源】。本件即为找出它而设。
--  纪律：行注释 only · 无 OFFSET · 全部只读 · 先读结构再用结构（W-23 教训）
-- ══════════════════════════════════════════════════════════════════════════════


-- ── D1 · ods_a168_employee 的列结构（荷官主档？）──
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME   = 'ods_a168_employee'
ORDER BY ORDINAL_POSITION;


-- ── D2 · 全库还有哪些表可能承载荷官身份 ──
SELECT TABLE_NAME, TABLE_ROWS, TABLE_COMMENT
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (  LOWER(TABLE_NAME) LIKE '%employ%'
      OR LOWER(TABLE_NAME) LIKE '%dealer%'
      OR LOWER(TABLE_NAME) LIKE '%staff%'
      OR LOWER(TABLE_NAME) LIKE '%user%'
      OR LOWER(TABLE_NAME) LIKE '%eid%'
      OR LOWER(TABLE_NAME) LIKE '%table%'
      OR LOWER(TABLE_NAME) LIKE '%desk%')
ORDER BY TABLE_NAME;


-- ── D3 · employee 与 bet02.eid 的连接可行性（能否对上）──
--    先跑 D1 看清主键列名；若主键不是 eid，本条须按 D1 结果改列名后再跑
SELECT COUNT(*)                                                        AS n_employee_rows,
       COUNT(DISTINCT CAST(NULLIF(TRIM(eid),'') AS BIGINT))            AS n_employee_eid,
       (SELECT COUNT(DISTINCT CAST(NULLIF(TRIM(b.eid),'') AS BIGINT))
        FROM ods_mariadb_2b.ods_a168_bet02 b
        WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
          AND b.bet02 = '101' AND b.category = '1'
          AND UPPER(TRIM(b.bet38)) = 'N')                              AS n_bet_dealer
FROM ods_mariadb_2b.ods_a168_employee;
--    判读：n_bet_dealer 应约 299（S02 实测荷官数）
--          若 n_employee_eid 能覆盖之，则 employee 可作荷官维表
