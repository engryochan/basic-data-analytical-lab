-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- R03b ＃071 · 验收探针 M · 内存自适应勘查   v1.0.0   2026-09-05
-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【所答之问】能否让查询【自动识别可用内存、用到九成才转落盘，而非撑爆】？
--   —— 答：StarRocks 内建【落盘（spill）】机制即此物；但旋钮名与默认值随版本而异，
--      在下无法连库，故须本探针先勘查先生这套版本【有哪些旋钮 · 现值几何 · 集群现况如何】。
-- 【只读】全为 SHOW ／ SELECT，无任何写操作，不改库中任何物。
-- 【用法】Superset SQL Lab 一次跑一条，自 M-1 至 M-8 依序。某条若报「不识别」即跳过并回报，
--   此乃版本差异，非错误 —— 探针之职正是把「有什么」问清楚。
-- 【已知之两重上限（自本轮报错信息实测，无须再查）】
--   BE 进程 mem_limit   = 107,092,346,019 B = 99.74 GiB
--   资源组 default_wg   =  96,383,111,417 B = 89.76 GiB  ← 查询之真天花板
--   二者之比 = 90.00%（管理者刻意划定之水位）
-- ══════════════════════════════════════════════════════════════════════════════════════════════


-- ── M-1 · 版本 ──────────────────────────────────────────────────────────────
--   旋钮名与默认值皆随版本而异，故先定版本。三式择一能跑者即可。
SELECT CURRENT_VERSION();
-- 备选一： SELECT @@version_comment;
-- 备选二： SHOW FRONTENDS;


-- ── M-2 · 落盘旋钮之【有无】与【现值】★ 本探针之核心 ───────────────────────
--   期望见到：enable_spill、spill_mode、spill_mem_limit_threshold 等。
--   ⛔ 若 spill_mem_limit_threshold 不在列，则本版不支持「按水位落盘」，须改用别策。
SHOW VARIABLES LIKE '%spill%';


-- ── M-3 · 内存预算类旋钮之现值 ──────────────────────────────────────────────
--   重点看 query_mem_limit（本查询在单 BE 上之预算，0 ＝ 不限）与 exec_mem_limit（旧名）。
--   水位落盘之触发点 ＝ spill_mem_limit_threshold × query_mem_limit；
--   若 query_mem_limit ＝ 0，则以进程／资源组限为基。
SHOW VARIABLES LIKE '%mem_limit%';


-- ── M-4 · 并行度与其他相关旋钮 ──────────────────────────────────────────────
SHOW VARIABLES LIKE '%pipeline_dop%';
-- 续查： SHOW VARIABLES LIKE '%exec_mem%';
-- 续查： SHOW VARIABLES LIKE '%query_timeout%';


-- ── M-5 · 集群现况：各 BE 之内存占用 ★ 「自动识别」之料源 ────────────────────
--   看 MemUsedPct ／ MemLimit ／ CpuCores。若某 BE 已逾九成，即知此刻不宜跑重查询。
SHOW PROC '/backends';
-- 备选： SHOW BACKENDS;


-- ── M-6 · 资源组之配置 ──────────────────────────────────────────────────────
--   核实 default_wg 之 mem_limit 究竟怎么定的（占比抑或绝对值），
--   并看先生这个账号是否可切到别的资源组。
SHOW RESOURCE GROUPS ALL;
-- 备选： SELECT * FROM information_schema.resource_groups;


-- ── M-7 · 当前并发查询 ★ 「残留」之真身 ─────────────────────────────────────
--   前次已言：清 cookies 杀不掉未结束之查询，此处方能看见。
--   若见自己之旧查询仍 Running，取其 QueryId 后以 KILL QUERY '<id>' 清之。
SHOW PROC '/current_queries';
-- 备选： SELECT * FROM information_schema.loads WHERE 1=0;   -- 仅测 information_schema 可用性


-- ── M-8 · information_schema 是否暴露 BE 内存（决定能否写「起飞前自检」单句）──
--   若下列任一可跑，则可写成【一条 SELECT 即给出 GO／NO-GO 裁决】之守门查询；
--   若皆不可跑，则只能以 M-5 之 SHOW 人工过目。
SELECT * FROM information_schema.be_metrics LIMIT 5;
-- 备选一： SELECT * FROM information_schema.be_configs LIMIT 5;
-- 备选二： SELECT * FROM information_schema.backends LIMIT 5;


-- ══════════════════════════════════════════════════════════════════════════════════════════════
-- 【回报后在下将据以定夺之三事】
--   ① 水位落盘可否成立 —— 视 M-2 是否有 spill_mem_limit_threshold。
--      若有，则设 enable_spill=true、spill_mode='auto'、spill_mem_limit_threshold=0.9，
--      即为先生所求之「用到九成才落盘，不撑爆」。
--      ⚑ 注意：'auto' 才是「用到水位再落盘」；'force' 是「一律落盘」，稳但慢。
--      在下前答建议 'force'，系求稳；今按先生「用到九成」之意，应改 'auto'。
--   ② query_mem_limit 该给多少 —— 视 M-3 现值与 M-5 集群余裕而定。
--   ③ 起飞前自检能否写成单句 —— 视 M-8。
-- ══════════════════════════════════════════════════════════════════════════════════════════════
