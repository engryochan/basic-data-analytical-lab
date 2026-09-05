-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- R03b ＃071 · 验收探针 M2 · 落盘水位实证（sr_superset 权限内）   v1.0.0   2026-09-05
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【承 探针 M 之三项发现】
--   ① StarRocks 版本 = 4.0.9-f647589（落盘机制齐备）。
--   ② `SHOW VARIABLES LIKE …` 在 SQL Lab 一律语法错 —— 报错说 Unexpected input 'LIMIT'，
--      而在下的语句里【并无 LIMIT】⇒ 系 **Superset 自动在尾部追加 LIMIT**，
--      而 StarRocks 之 SHOW 不收 LIMIT。此非 StarRocks 之错，亦非权限问题。
--      ⇒ 故本探针一律改用 SELECT 形式（SELECT 收 LIMIT，无碍）。
--   ③ SHOW PROC '/backends'、'/current_queries'、information_schema.be_metrics
--      皆报 Access denied（需 SYSTEM OPERATE，现役角色 sr_superset 无之）。
--      ⇒ 本探针不再触碰该类，改试权限较低之替代。
-- 【只读】全为 SELECT／SHOW，无写操作。SET 仅改【本会话】之行为，不改库中任何物。
-- 【用法】一次跑一条，自 N-1 至 N-6。某条若报错即跳过并回报——探针之职正是问清「有什么」。
-- ══════════════════════════════════════════════════════════════════════════════════════════════


-- ── N-1 · 落盘旋钮之有无与现值（取代失败之 SHOW VARIABLES）★ 核心 ─────────────
--   information_schema 之 variables 表系【真表】，收 LIMIT，且不需 SYSTEM OPERATE。
SELECT VARIABLE_NAME, VARIABLE_VALUE
FROM information_schema.session_variables
WHERE LOWER(VARIABLE_NAME) LIKE '%spill%'
   OR LOWER(VARIABLE_NAME) LIKE '%mem_limit%'
   OR LOWER(VARIABLE_NAME) LIKE '%pipeline_dop%'
   OR LOWER(VARIABLE_NAME) LIKE '%resource_group%'
ORDER BY VARIABLE_NAME;


-- ── N-2 · 备选：若 N-1 之表不在位，改逐个取 ────────────────────────────────
--   ⚑ 某个变量若不存在，本句会整条报错；届时请把报错里那个名字删掉再跑。
SELECT @@enable_spill              AS enable_spill,
       @@spill_mode                AS spill_mode,
       @@spill_mem_limit_threshold AS spill_threshold,
       @@query_mem_limit           AS query_mem_limit,
       @@pipeline_dop              AS pipeline_dop;


-- ── N-3 · ★★ 关键一问：会话级水位能否压过资源组之 100%？ ────────────────────
--   探针 M 已实测 default_wg.spill_mem_limit_threshold = 100%（＝撞顶才落盘＝实质永不落盘）。
--   本句以【SET_VAR 提示】把水位压到 0.9，看返回值是否确为 0.9。
--   ⛔ 何以用提示而不用 SET：Superset SQL Lab 每次执行未必复用同一连线，
--      SET 出去的会话变量下一句未必还在；SET_VAR 提示则【绑在这一句上】，必然生效。
SELECT /*+ SET_VAR(enable_spill = true,
                   spill_mode = 'auto',
                   spill_mem_limit_threshold = 0.9) */
       @@enable_spill              AS enable_spill,
       @@spill_mode                AS spill_mode,
       @@spill_mem_limit_threshold AS spill_threshold;
--   【判读】
--     三值返回 true / auto / 0.9  ⇒ ★ 会话级可压过资源组，先生自己即可解，无须劳动 DBA。
--     spill_threshold 仍回 1 或 100 ⇒ ⛔ 受资源组封顶，须请 DBA 调 default_wg。


-- ── N-4 · 自己的连线与查询（试较低权限之替代）──────────────────────────────
--   SHOW PROCESSLIST 通常只需看自己的连线，多半不需 SYSTEM OPERATE。
--   ⚑ 若此句亦被 Superset 追加 LIMIT 而语法错，则改用 N-5。
SHOW PROCESSLIST;


-- ── N-5 · 备选：以 information_schema 看自己的连线 ──────────────────────────
SELECT * FROM information_schema.processlist LIMIT 50;


-- ── N-6 · 现役角色与可切换之角色（判能否自行提权到别的资源组）────────────────
SELECT CURRENT_ROLE();
-- 备选： SHOW GRANTS;


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【N-3 若成立，则生产查询之写法如下 —— 无须任何人配合，先生自己即可施用】
--
--   把 ＃071 之最外层 SELECT 改成带提示的形式（只加提示，其余一字不动）：
--
--     SELECT /*+ SET_VAR(enable_spill = true,
--                        spill_mode = 'auto',
--                        spill_mem_limit_threshold = 0.9,
--                        pipeline_dop = 4) */
--            z.*,
--            CAST(FLOOR((z.audit_rn - 1) / 10000) + 1 AS INT) AS batch_id,
--            …其余逐字不动…
--
--   ⛔ 提示只改【执行方式】，不改任何列值与行序 ⇒ 输出必然不变。
--      纵然如此，仍建议先以第 100 批验一次逐字节（法同探针 A），方入生产。
-- ══════════════════════════════════════════════════════════════════════════════════════════════
