-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- R03b ＃071 · 验收探针 M3 · 落盘开关之施用法   v1.0.0   2026-09-05
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【承 探针 M2 之实测 —— 答案已浮出，比先前所判简单得多】
--   N-1／N-2 实测本会话之现值：
--       enable_spill                = false   ★★ 落盘【根本没开】—— 此即撑爆之直接成因
--       spill_mode                  = auto    ← 已是「用到水位才落盘」，无须改
--       spill_mem_limit_threshold   = 0.8     ← 水位【本来就已是 80%】，无须调
--       query_mem_limit             = 0       ← 不限（以进程／资源组限为基）
--       pipeline_dop                = 0       ← 自动（上限 max_pipeline_dop = 64）
--       disable_spill_to_local_disk = false   ← 可落本地盘
--       spill_storage_volume        = (空)    ← 未指定远端卷，故落本地盘
--   ⇒ 结论：**模式与水位早就设对了，只差把 enable_spill 打开。**
--   ⚑ 在下前答曾判「症结在资源组之 spill_mem_limit_threshold = 100%」——须斧正：
--      会话既然 enable_spill = false，则无论水位设几，落盘都不会发生。
--      资源组那个 100% 是【次要】，须待落盘开启后方知其是否封顶。
--
-- 【本探针所治之病 —— 在下自己的错】
--   探针 M2 之 N-3 报 `Unexpected input '='`，系在下把 SET_VAR 提示写成【跨三行】所致。
--   本探针以【单行】写法逐级试之，并试各种字面值，以定何者可用。
-- 【只读】全为 SELECT。SET 仅改本会话行为，不改库中任何物。
-- 【用法】一次跑一条，自 P-1 至 P-7；某条报错即跳过并回报其报错原文。
-- ══════════════════════════════════════════════════════════════════════════════════════════════


-- ── P-1 · 单行 · 单变量 · 无空格 ★ 最可能成者，先试此 ─────────────────────────
SELECT /*+ SET_VAR(enable_spill=true) */ @@enable_spill AS enable_spill;


-- ── P-2 · 单行 · 单变量 · 有空格（判空格是否为祸）──────────────────────────────
SELECT /*+ SET_VAR(enable_spill = true) */ @@enable_spill AS enable_spill;


-- ── P-3 · 单行 · 单变量 · 值写 1（判 true 字面是否为祸）───────────────────────
SELECT /*+ SET_VAR(enable_spill=1) */ @@enable_spill AS enable_spill;


-- ── P-4 · 单行 · 多变量（P-1~P-3 有一成者，方试此）★ 生产所需之形 ─────────────
SELECT /*+ SET_VAR(enable_spill=true,spill_mode='auto',spill_mem_limit_threshold=0.8) */ @@enable_spill AS enable_spill, @@spill_mode AS spill_mode, @@spill_mem_limit_threshold AS spill_threshold;


-- ── P-5 · 会话式：SET 与查询【同一次执行】内先后二句 ────────────────────────────
--   若 Superset 允许一次执行多句，此法亦可；且比提示更易读。
SET enable_spill = true; SELECT @@enable_spill AS enable_spill;


-- ── P-6 · 会话式：SET 单独一次执行，再另跑一次读取（判会话是否跨执行留存）────────
--   ⚑ 须【分两次执行】：先跑本行，再跑 P-7。
SET enable_spill = true;


-- ── P-7 · 承 P-6：另一次执行读之。若仍回 0，即证 SQL Lab 每次执行换连线，
--   ⇒ 则 SET 法不可用于生产，必须用 SET_VAR 提示。
SELECT @@enable_spill AS enable_spill;


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【判读与后续】
--   ① P-1~P-4 有任一返回 enable_spill = 1／true ⇒ ★ 提示法可用，生产查询即照 P-4 之形加提示。
--   ② P-1~P-4 全败而 P-5 成 ⇒ 用「SET; SELECT」同执行之形。
--   ③ P-7 若回 1 ⇒ 会话跨执行留存，SET 单跑一次即可，其后各批皆受用。
--   ④ 全败 ⇒ 会话侧无路，须请 DBA 把 default_wg 之 spill_mem_limit_threshold 由 100% 调至 80~90%
--      （同集群之 default_mv_wg 已是 80%，有现成先例可援）。
--
-- 【⛔ 落盘开启后仍须留意之一事 —— 在下无权查证，先生宜心中有数】
--   spill_storage_volume 为空且 disable_spill_to_local_disk = false ⇒ 落盘写【BE 本地磁盘】。
--   若 BE 本地盘余量不足，落盘本身会失败。查 BE 磁盘需 SYSTEM OPERATE（sr_superset 无此权），
--   故在下无从实测。若开启落盘后改报「磁盘」类错误，即是此故，届时须请部门看 BE 盘。
--
-- 【生产查询之最终形（俟 P-1~P-4 定谳后取其可用者）】
--   SELECT /*+ SET_VAR(enable_spill=true,spill_mode='auto',spill_mem_limit_threshold=0.8) */
--          z.*, CAST(FLOOR((z.audit_rn - 1) / 10000) + 1 AS INT) AS batch_id, …其余逐字不动…
--   ⛔ 提示只改【执行方式】，不改任何列值与行序 ⇒ 输出必然不变；
--      纵然如此，仍须先以第 100 批验一次逐字节（法同探针 A，MD5 应仍为
--      e1503f6e29f189f9676fd0f7a7ee580f），方入生产。
-- ══════════════════════════════════════════════════════════════════════════════════════════════
