-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- SQL 总包 · 回灌包（BACK-PORT PACKAGE）· v11.0.5-draft / REL-0006-candidate / C2-candidate
-- 内容：§D00 口径注册表 · §D01 冲突裁定登记 · §R01 · §P13 · §P14
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【必读一：本包不是总包，是回灌包】
--   本包**未见总包正档**。撰稿侧手上只有总包之一个片段（§P13 会员入场行为层），
--   故无法在总包正档上原地合并。本包系可拼入之**回灌单元**：三节各为独立可跑语句，
--   拼入位置与替换范围见 §D01 之「回灌指令」。**拼入前总包为唯一权威。**
--
-- 【必读二：版本号有三个，须先裁定】
--   ① v11.0.3 / REL-0005 / C1 —— 记录在案之总包权威版（纯代码 MD5
--      ce768c35b8d7aeb5ac28079166a8c422，IMMUTABLE GOLDEN BASELINE）。
--   ② v11.0.4 —— 片段所属版（由文件名 shoe_len_from_sqlv11.0.4 推得，非档内自述）。
--   ③ v1.0.4  —— 工单所称之版号。
--   三者不可同时为真。本包暂署 v11.0.5-draft 并候裁定；**署名不等于认定**。
--   本包新增输出列且改动共用闸门 ⇒ schema_diff ≠ ∅ ⇒ Contract ID 须 C1 → C2，
--   Release ID 须 REL-0005 → REL-0006，并重算纯代码 MD5 与六元组（七步法）。
--
-- 【必读三：三节共用一套口径层，逐字同文】
--   TIER-A（共用口径层，三节同文）：d_params · d_agents_raw · test_agents · ranked ·
--     raw · gated_struct · win · shoe · shoe1
--   TIER-B（会员共用层，§R01 与 §P13 同文）：gated_member · enriched · mem_shoe
--   TIER-D（诊断共用层，三节同文）：d_agent · d_dedup · d_type · d_key · d_scope · diag
--   三层以 ▽▽▽ 起 / △△△ 止 标记包夹，供 G-0 闸逐字比对。**改一处须三处同改。**
--   代价：§P14 亦携其不用之若干列（fx／stake_raw／payout_raw）。换来的是三节同母体、
--   可互相对账，且「同一维度／同一指标两处不同定义」在结构上不可能发生。
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- §D00 · 口径注册表（CANONICAL DEFINITION REGISTER）
--   凡下列维度／指标，全包只此一处定义；他处一律引用，禁重定义、禁改名、禁改义。
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【维度】
--   table_id      = TRIM(bet39)                              粒度键·桌      定义处 TIER-A.raw
--   shoe_id       = TRIM(bet03)                              粒度键·靴      定义处 TIER-A.raw
--   shoe_key      = (table_id, shoe_id) **双键**             权威靴键        定义处 TIER-A.shoe
--   round_no      = CAST(NULLIF(TRIM(bet04),'') AS INT)      粒度键·局      定义处 TIER-A.raw
--   member_id     = CAST(NULLIF(TRIM(bet05),'') AS BIGINT)   粒度键·会员    定义处 TIER-A.raw
--   bet_id        = bet01                                    粒度键·注单    定义处 TIER-A.raw
--   dt            = 营业日（分区列）                          粒度键·日      定义处 ods_a168_bet02
--
-- 【bet04 语义裁定】bet04 ＝ **局号**（靴内第几局），非「局内序号」。
--   依据：靴数 123,357 ÷ 30 桌 ÷ 139 日 ≈ 29.6 靴/桌/日，乘均 max_round 49.78
--   得 ≈ 1,473 局/桌/日 ⇒ ≈ 58.7 秒/局，落于百家乐单局 50–70 秒之带内。
--   若为「局内序号」则此三重物理量级无从成立。故裁定为局号，并令三处表述统一。
--   ★ 判级 OBSERVED（物理量级自洽），非 DDL 证据；DDL 到手后须复核。
--
-- 【指标·结构层】（定义处 TIER-A.shoe，粒度 table×shoe）
--   shoe_len_obs      = MAX(round_no)          判级 OBSERVED·代理  ★禁注册为真靴长
--   first_round_obs   = MIN(round_no)          判级 OBSERVED
--   n_rounds_obs      = COUNT(DISTINCT round_no) 判级 OBSERVED     ★一切计数类分母之正解
--   n_bets_ts         = COUNT(*)               判级 OBSERVED       粒度后缀 ts ＝ table×shoe
--   n_dt_shoe         = COUNT(DISTINCT dt)     判级 OBSERVED       ≥3 ⇒ 靴号重用
--   is_edge           = 触窗口首末日           判级 OBSERVED
--
-- 【指标·会员层】（定义处 TIER-B，粒度 uid×shoe 或 uid）
--   shoe_pos          = round_no ÷ shoe_len_obs   判级 OBSERVED·代理（分母系代理）
--   stake             = bet13 ÷ bet11             判级 OBSERVED   本金口径，非洗码
--   game_pnl          = (bet14 − bet13) ÷ bet11   判级 OBSERVED   不含退水
--   is_late           = shoe_pos >= d_params.late_q 判级 CONTRACT
--   first_r / last_r  = MIN/MAX(round_no) per uid×shoe 判级 OBSERVED
--   n_bets_ms         = COUNT(*) per uid×shoe     判级 OBSERVED   粒度后缀 ms ＝ uid×shoe
--   n_rounds_ms       = COUNT(DISTINCT round_no) per uid×shoe 判级 OBSERVED
--
-- 【参数】（定义处 TIER-A.d_params，全包唯一）
--   late_q         = 0.80  相对靴位判据阈值（late_def 字面之数值真身）
--   min_orders     = 100   会员域活跃度门槛（注单数）
--   conf_min_shoes = 10    分位类指标之置信靴数下限——★只作旗标，不作筛（候裁定）
--
-- 【命名律】
--   ① 凡代理量，名末缀 _obs，判级必带「·代理」。
--   ② 凡同名异粒度者，缀粒度后缀：_ts（table×shoe）／_ms（uid×shoe）／_uid／_table。
--   ③ 凡因构造而耦合之相关，判级 STRUCTURAL_CORRELATION，禁作行为关联读。
--   ④ 凡两变量皆原始量之相关，判级 OBSERVED_ASSOCIATION —— **相关不等于因果**，
--      禁述作「靴长影响下注量」之类因果句。
--   ⑤ 凡绝对局号量，判级 ABSOLUTE_POSITION，**跨桌不可比**（桌族切牌规程各异）。
--   ⑥ **透传**（同一定义自上层原样搬入下层，以 MIN/MAX 取组内单值）不视为重定义，
--      但注释须标明「透传」，且不得改名——改名即制造第二个名字指同一物。
--   ⑦ 会员级共用量（n_orders_all／n_shoes_uid／覆盖率／偏移／边界占比等）只在
--      TIER-B.mem_agg 定义一次，§R01 与 §P13 一律引用，禁各自另算。

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- §D01 · 冲突裁定登记（CONFLICT RULING REGISTER）＋ 回灌指令
--   本节逐条登记「同一维度／同一指标两处不同定义」之冲突及其裁定。
--   凡未在此登记者，视为无冲突；日后发现即补登，禁静默改口径。
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 冲突 01 · shoe_len 之粒度
--   现状：§P13 以 GROUP BY bet03 单键算 MAX(round_no)；§P14 以 (bet39,bet03) 双键算。
--   裁定：统一为**双键**（TIER-A.shoe）。§P13 改为消费之，不再自行定义。
--   依据：升级建议 §二／§二十四；且历史 OBSERVED 事实（pct_cross_table = 0）明载
--         不外推、换窗须重验，故须改为**每批自证**而非沿用结论。自证列见 d_key。
--
-- 冲突 02 · shoe_len 之母体
--   现状：撰稿侧 v1.2.55 之 §R01 于经济闸后建 shoe_truth，§P14 于键闸后建 shoe。
--         同名 shoe_len_obs 遂有两个母体——**两个定义**。
--   裁定：结构真相层**只建于结构键闸之后**（gated_struct），经济闸（member_id／fx）
--         下移至 gated_member，仅会员级两节用之。结构真相禁被经济闸收窄。
--   影响：§R01 之 shoe_len_obs 将不小于旧值（母体变宽），故 shoe_pos 与 late_share
--         可能微变。此系斧正而非漂移，须在回灌说明中显式登记。
--
-- 冲突 03 · n_bets 同名异粒度
--   现状：§P13 之 per_shoe.n_bets 系 uid×shoe；§P14 之 shoe.n_bets 系 table×shoe。
--   裁定：一律缀粒度后缀 —— n_bets_ms（uid×shoe）／n_bets_ts（table×shoe）。禁裸名。
--
-- 冲突 04 · n_shoes 同名异母体
--   现状：§P13 之 n_shoes 系会员所历靴数；§P14 之 n_shoes 系桌之靴数。
--   裁定：n_shoes_uid（会员所历）／n_shoes_table（桌之靴数）。禁裸名。
--
-- 冲突 05 · n_orders 与 n_orders_all
--   现状：§P13 出 n_orders；§R01 出 n_orders_all。二者同义（会员注单总数）。
--   裁定：以 n_orders_all 为**规范名**；§P13 改出 n_orders_all，n_orders 记为弃用别名。
--
-- 冲突 06 · bet04 之语义表述
--   现状：数据口径表作「局号」；§P13 行注释作「局内序号」；别名作 round_no。三处不一。
--   裁定：统一为「局号」（依据见 §D00 之 bet04 语义裁定）。§P13 之行注释系笔误，已改。
--
-- 冲突 07 · entry_pos／exit_pos 之判级与命名
--   现状：§P13 出 entry_pos_p50，读作「会员在靴之百分之几进场」。
--   裁定：分母系代理量，故比值亦为代理。更名 entry_pos_obs_*／exit_pos_obs_*，
--         判级 OBSERVED·代理。禁以 entry_position 之名入 Registry。（升级建议 §五）
--
-- 冲突 08 · bet_density 之分母
--   现状：§P13 之 n_bets ÷ (last_r − first_r + 1) 混三事：下注频率、局号缺失、跨度。
--   裁定：二式并出 —— bet_density_nominal_*（旧式，留作血统对照）与
--         bet_density_obs_*（分母改 n_rounds_ms，即该会员于该靴实际有注之局数）。
--         （升级建议 §六）
--
-- 冲突 09 · 分位只取 P50
--   现状：§P13 只出 P50，无从区分「稳定早入型」与「极端跳跃型」。
--   裁定：入场／退出／密度三者皆出 P25／P50／P75。（升级建议 §七）
--
-- 冲突 10 · entry_round_avg 之可比性
--   现状：系绝对局号，而 §P14 实测桌族均靴长自 47.72 至 56.39，四套切牌规程并存。
--   裁定：保留但判级 ABSOLUTE_POSITION，标注**跨桌不可比**。（升级建议 §八）
--
-- 冲突 11 · 活跃度门槛之双写
--   现状：§P13 之 HAVING SUM(n_bets) >= 100 与 §R01 之 HAVING COUNT(*) >= 100
--         各写一次字面，且基数表述不同。
--   裁定：统一取 d_params.min_orders，两节改于外层 WHERE 施之。
--
-- 冲突 12 · 门槛只管注单不管靴数
--   现状：1 靴 × 500 注与 20 靴 × 5 注同样过 100 注门槛，统计可靠性天差地别。
--   裁定：出 n_shoes_uid 与 bets_per_shoe_uid，并出旗标 conf_shoes_ok
--         （n_shoes_uid >= d_params.conf_min_shoes）。★只作旗标不作筛 —— 改筛即改母体，
--         须先裁定。（升级建议 §九）
--
-- 冲突 13 · 测试线名单之扇出
--   现状：三节皆 SELECT age001（未去重），一对多联结即静默放大 COUNT(*)。
--   裁定：test_agents 一律 DISTINCT；并出 duplicate_agent_id_count 以曝源头重复
--         —— DISTINCT 只治症不治因。（升级建议 §十五）
--
-- 冲突 14 · bet01 唯一性之表述
--   现状：注释以「同单号去重主键」表述，近乎断言其为业务主键。
--   裁定：判级 **BET01_UNIQUENESS = OBSERVED**，非 TRUE_PRIMARY_KEY。出四量：
--         n_rows_ranked／n_bet01／n_rows_dedup／dedup_integrity_ratio。（升级建议 §十六）
--
-- 冲突 15 · ROW_NUMBER 之并列不确定性
--   现状：ORDER BY updatetime, sync_time, dt 三键全同者，rn 取哪一行不定 ⇒ 重跑可漂移。
--   裁定：并出 RANK() 之 rk，以 dedup_tie_count／dedup_tie_rate 量其规模，列为红闸。
--         ★未加第四决胜键 —— 因是否存在 ingest_id／version_id 之类稳定列尚未核实，
--         **禁凭想象造列**。待 DDL 到手再定。（升级建议 §十七）
--
-- 冲突 16 · CAST 静默变 NULL
--   现状：CAST(NULLIF(TRIM(bet04),'') AS INT) 遇 'abc'／'1e2' 等静默变 NULL 而不报错。
--   裁定：透传 round_raw 原样字面，出五量分类：n_round_empty／n_round_non_numeric／
--         n_round_fractional／n_round_le_zero／n_round_valid。（升级建议 §十八）
--
-- 冲突 19 · n_bets_ts 同名异粒度（撰稿侧自查所得，非升级建议）
--   现状：TIER-A.shoe 之 n_bets_ts 系 table×shoe；§P14.tbl 曾以同名出桌级 SUM。
--   裁定：桌级改名 n_bets_table／n_bets_table_distinct，遵 §D00 命名律②。
--   来源：以「同名异定义扫描器」逐 AS 别名归组比对定义文本所得（127 别名、70 处多现、
--         15 处文本不一），此为其中唯一之真冲突，余皆透传或纯空白差异。
--
-- 冲突 20 · 会员级共用量两处各算（撰稿侧自查所得）
--   现状：撰稿侧 v1.2.55 之 §R01.mem_qual 与本包 §P13.mem_entry 各自算 n_shoes_uid、
--         round_coverage_p50、start_offset_avg、edge_shoe_share、max_n_dt_shoe、
--         bets_per_shoe_uid ——表达式虽同，然定义处有二，即二真相源之雏形。
--   裁定：整体收归 TIER-B.mem_agg 一处；两节改为引用。n_orders_all 亦由此处出
--         （旧式注单层 COUNT(*) 与新式 SUM(n_bets_ms) 恒等——同一母体之分组求和），
--         C1 列名不变、值不变，惟定义处收归唯一。此条须在回灌说明中登记。
--
-- 冲突 17 · 相关系数之构造与判级
--   现状：corr(max_round, n_bets ÷ max_round) 之分母即解释变量本身（比率型伪相关）。
--   裁定：三式并出。corr_len_dens_struct 判级 STRUCTURAL_CORRELATION（降为诊断，
--         禁作主指标）；corr_len_bets 与 corr_len_rounds 判级 OBSERVED_ASSOCIATION
--         —— **亦禁述作因果**。（升级建议 §十三）
--
-- 冲突 18 · 诊断分层
--   现状：过滤与诊断同层，被剔者凭空消失，n_null 只能永报零 —— 自证清白。
--   裁定：raw（业务闸）→ gated_struct（键闸）→ gated_member（会员／金额闸）三层，
--         诊断分母取 raw。（升级建议 §十四）
--
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 【回灌指令】按此拼入总包，逐条核对后方可宣告 REL-0006
--   R1. 以本包 §R01 全文**整节替换**总包 §R01 全文。
--   R2. 以本包 §P13 全文**整节替换**总包 §P13 全文。
--   R3. 于总包新增 §P14 一节（原名 §P13 桌级探针者一律改称 §P14，禁一号双占）。
--   R4. 三节之 TIER-A／TIER-B／TIER-D 须逐字同文；拼入后跑 G-0 闸机检。
--   R5. 总包他节若另有 test_agents／ranked／shoe_len 之副本，须一并归化至 TIER-A，
--       或于 §D01 补登「例外与理由」。**未归化亦未登记者视为冲突未清。**
--   R6. 导出件名：R01_late_shoe.csv ／ P13_personal_entry.csv ／ P14_table_shoe_truth.csv。
--       ★P11 前缀被两份总帐双占之旧案未清，本包不涉，另案裁定。
--   R7. 申报 REL-0006 / C2，重算纯代码 MD5（七步法）与六元组，旧版改名 _superseded。
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- §R01 · R01_late_shoe.csv · 雷欧（尾段投注模型）· 会员级尾段行为与分段 ROI
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 粒度：uid × 1（过 d_params.min_orders 门槛者）
-- 判据锁：相对靴位 shoe_pos >= d_params.late_q（0.80）。late_def 字面保血统，late_q 供双录核对。
-- 契约保全：C1 原 15 列（uid…game_pnl_all）逐字不改名、不改义、不改序；新增列一律后置。
-- 与旧版之实质差异（须在回灌说明中登记，非漂移而系斧正）：
--   ① shoe_len_obs 之母体由「经济闸后」改为「结构键闸后」（见 §D01 冲突 02），
--      故 shoe_pos 与 late_share 可能微变；
--   ② test_agents 加 DISTINCT，若主档确有重复则 n_orders_all 将由虚增回落至真值。
-- ▸ 导出：需要 —— 存为「数据库/R01_late_shoe.csv」。

WITH
-- ▽▽▽▽▽ 共用口径层 TIER-A 起（三节逐字同文；改一处须三处同改，G-0 闸机检）▽▽▽▽▽
d_params AS (                                                                                   -- 公共表表达式：★参数单点声明层——全包一切阈值只此一处，禁他处再写字面
  SELECT 0.80  AS late_q,                                                                       -- 取值表达式：相对靴位判据阈值，产出「late_q」（口径锁之数值真身）
         100   AS min_orders,                                                                   -- 取值表达式：会员域活跃度门槛（注单数），产出「min_orders」
         10    AS conf_min_shoes                                                                -- 取值表达式：★分位类指标之置信靴数下限（只作旗标不作筛，候裁定）
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_agents_raw AS (                                                                               -- 公共表表达式：代理主档测试线**未去重**原样——供重复诊断，禁直接联结
  SELECT age001 AS agent_id                                                                     -- 取列：产出「agent_id」（原样，可能重复）
  FROM ods_mariadb_2b.ods_a168_agent                                                            -- 取数来源：代理主档
  WHERE age022 = '1'                                                                            -- 过滤条件：测试线旗标（铁律④b）
),                                                                                              -- 续行：收束上方的子查询或函数括号
test_agents AS (                                                                                -- 公共表表达式：★去重后之测试线名单——防扇出，唯一可用于联结者
  SELECT DISTINCT agent_id FROM d_agents_raw                                                    -- 取列：★DISTINCT——主档若重复，五路左连接会把一注扇成多行且 SQL 不报错
),                                                                                              -- 续行：收束上方的子查询或函数括号
ranked AS (                                                                                     -- 公共表表达式：同注单号取最新版本 ＋ 并列诊断（rk）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                     -- 取列：涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,                                  -- 续行：涉 bet03（靴号）、bet04（局号）、bet05（会员号）、bet11（汇率）、bet13、bet14
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                           -- 续行：五级代理线
         b.bet38, b.bet39, b.category,                                                          -- 续行：涉 bet38（测试标识）、bet39（桌号）、category（注单类别）
         ROW_NUMBER() OVER (                                                                    -- 行号窗口表达式：取每注单号之一行
           PARTITION BY b.bet01                                                                 -- 窗口分区：按注单号（★此键之唯一性系 OBSERVED，非 DDL 证据，见 d_dedup）
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn,                      -- 排序：三级降序；★三键全同者 rn 之取舍不定，故并出 rk 以量其规模
         RANK() OVER (                                                                          -- 排名窗口表达式：★并列检测——同分者同 rk
           PARTITION BY b.bet01                                                                 -- 窗口分区：同上分区，同上排序，方可与 rn 对照
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rk                       -- 排序：同上；rk = 1 之行数 > 1 即版本并列，重跑可漂移
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                          -- 取数来源：注单明细表（★表名开关）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                            -- 过滤条件：限定全局窗（半开区间；两端之靴被切尾，故下设 is_edge）
    AND b.bet02 = '101'                                                                         -- 并列条件：限定百家乐
),                                                                                              -- 续行：收束上方的子查询或函数括号
raw AS (                                                                                        -- 公共表表达式：★第一闸——只施**业务闸**，不施键闸；系一切诊断之分母
  SELECT r.bet01 AS bet_id, r.dt,                                                               -- 取列：产出「bet_id」并透传营业日
         TRIM(r.bet39) AS table_id,                                                             -- 取值表达式：★TRIM 防键分裂——不去空白则 '112' 与 ' 112' 裂为两桌
         TRIM(r.bet03) AS shoe_id,                                                              -- 取值表达式：★TRIM 防键分裂
         TRIM(r.bet04) AS round_raw,                                                            -- 取值表达式：★局号之**原样字面**——供类型异常分类（非数字／小数／科学记数）
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                           -- 取值表达式：去空白、空串归 NULL、显式转型，产出「round_no」（局号）
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,                          -- 取值表达式：同上转型规则，产出「member_id」（会员号）
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                 -- 取值表达式：同上转型规则，产出「fx」（汇率）
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                          -- 取值表达式：同上转型规则，产出「stake_raw」（原币下注额）
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw                          -- 取值表达式：同上转型规则，产出「payout_raw」（原币派彩额）
  FROM ranked r                                                                                 -- 取数来源：中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                             -- 左连接：一级线对测试名单（StarRocks 不支持 EXISTS 配多列 IN，故用五路左连接）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                             -- 左连接：二级线对测试名单
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                             -- 左连接：三级线对测试名单
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                             -- 左连接：四级线对测试名单
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                             -- 左连接：五级线对测试名单
  WHERE r.rn = 1                                                                                -- 过滤条件：只留一行（版本链去重）
    AND r.category = '1'                                                                        -- 并列条件：一般注单准入
    AND UPPER(TRIM(r.bet38)) = 'N'                                                              -- 并列条件：排除测试单
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL           -- 并列条件：五级任一命中测试线即剔
),                                                                                              -- 续行：收束上方的子查询或函数括号
gated_struct AS (                                                                               -- 公共表表达式：★第二闸——**结构键闸**。结构真相之母体，禁以经济闸收窄
  SELECT * FROM raw                                                                             -- 取列：承 raw 全列
  WHERE table_id <> '' AND shoe_id <> '' AND round_no > 0                                       -- 过滤条件：★三键闸——空键聚成幻影桌／幻影靴；非正局号亦剔
),                                                                                              -- 续行：收束上方的子查询或函数括号
win AS (                                                                                        -- 公共表表达式：窗界现取层——边界日由数据自证，不写死日期字面
  SELECT MIN(dt) AS dt_first, MAX(dt) AS dt_last FROM gated_struct                              -- 聚合表达式：产出「dt_first」「dt_last」（实见首末营业日，可能窄于名义窗）
),                                                                                              -- 续行：收束上方的子查询或函数括号
shoe AS (                                                                                       -- 公共表表达式：★结构真相层——(table_id, shoe_id) 双键为**全包唯一**之权威靴键
  SELECT g.table_id, g.shoe_id,                                                                 -- 取列：双键
         MAX(g.round_no)            AS shoe_len_obs,                                            -- 计数表达式：★观测靴长代理＝最大局号，**非局数**；真靴长待权威表 P0。全包唯一定义处
         MIN(g.round_no)            AS first_round_obs,                                         -- 聚合表达式：实见首局号（起始偏移 ＝ 其减一）
         COUNT(DISTINCT g.round_no) AS n_rounds_obs,                                            -- 计数表达式：★观测局数＝实见局号种数；一切**计数类**分母之正解
         COUNT(*)                   AS n_bets_ts,                                               -- 计数表达式：靴内注单行数（桌×靴粒度，故后缀 ts，禁与会员×靴之 n_bets_ms 同名）
         COUNT(DISTINCT g.bet_id)   AS n_bets_ts_distinct,                                      -- 计数表达式：靴内去重注单数
         COUNT(DISTINCT g.dt)       AS n_dt_shoe,                                               -- 计数表达式：★横跨营业日数——跨零点续接最多 2 日，≥3 必为靴号重用
         MAX(CASE WHEN g.dt = w.dt_first OR g.dt = w.dt_last                                    -- 条件分支：★边界靴旗标
                  THEN 1 ELSE 0 END) AS is_edge                                                 -- 续行：产出「is_edge」（1 ＝ 触窗界，其 shoe_len_obs 系下偏值）
  FROM gated_struct g CROSS JOIN win w                                                          -- 取数来源：结构闸后之母体叉乘窗界一行
  GROUP BY g.table_id, g.shoe_id                                                                -- 分组：按双键靴
),                                                                                              -- 续行：收束上方的子查询或函数括号
shoe1 AS (                                                                                      -- 公共表表达式：单键靴之同批对照——供靴键等价在带自证
  SELECT shoe_id, COUNT(DISTINCT table_id) AS n_tab_per_shoe                                    -- 计数表达式：每靴号所涉桌数；>1 即跨桌
  FROM gated_struct GROUP BY shoe_id                                                            -- 分组：按单键靴号
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- △△△△△ 共用口径层 TIER-A 止 △△△△△
,
-- ▽▽▽▽▽ 会员共用层 TIER-B 起（§R01 与 §P13 逐字同文；G-0 闸机检）▽▽▽▽▽
gated_member AS (                                                                               -- 公共表表达式：★第三闸——**会员／金额闸**。仅会员级两节用之，禁上溯收窄结构真相
  SELECT * FROM gated_struct                                                                    -- 取列：承结构闸后之母体
  WHERE member_id > 0 AND fx > 0                                                                -- 过滤条件：★会员号须正、汇率须正（分母非零）。二闸并施系为令 §R01 与 §P13 同母体
),                                                                                              -- 续行：收束上方的子查询或函数括号
enriched AS (                                                                                   -- 公共表表达式：注单级挂结构真相并派生位置与金额（会员两节共用）
  SELECT m.bet_id, m.member_id, m.table_id, m.shoe_id, m.round_no,                              -- 取列：注单级键与局号
         s.shoe_len_obs, s.first_round_obs, s.n_rounds_obs,                                     -- 续行：透传结构真相层三量
         s.n_dt_shoe, s.is_edge,                                                                -- 续行：透传结构真相层二旗标
         m.round_no * 1.0 / NULLIF(s.shoe_len_obs,0)  AS shoe_pos,                              -- 取值表达式：★相对靴位＝局号 ÷ 观测靴长（逐靴自归一化）。全包唯一定义处
         m.stake_raw / m.fx                           AS stake,                                 -- 取值表达式：本金口径＝原币下注额 ÷ 汇率。全包唯一定义处
         (m.payout_raw - m.stake_raw) / m.fx          AS game_pnl,                              -- 取值表达式：会员净盈亏（不含退水）。全包唯一定义处
         CASE WHEN m.round_no * 1.0 / NULLIF(s.shoe_len_obs,0) >= p.late_q                      -- 条件分支：★晚段判据取 d_params.late_q，禁写死字面
              THEN 1 ELSE 0 END                       AS is_late                                -- 续行：产出「is_late」（1 ＝ 该注落于靴末 (1−late_q) 之局位区间）
  FROM gated_member m                                                                           -- 取数来源：会员闸后之母体
  JOIN shoe s ON s.table_id = m.table_id AND s.shoe_id = m.shoe_id                              -- 内连接：★以**双键**挂结构真相层——单键挂靴即靴号重用之污染入口
  CROSS JOIN d_params p                                                                         -- 叉乘：参数层一行
),                                                                                              -- 续行：收束上方的子查询或函数括号
mem_shoe AS (                                                                                   -- 公共表表达式：会员×靴 中间粒度——观测质量须在此粒度算，方不被注单数加权
  SELECT member_id, table_id, shoe_id,                                                          -- 取列：会员×双键靴
         MIN(shoe_len_obs)    AS shoe_len_obs,                                                  -- 聚合表达式：靴属性透传（组内单值，取 MIN 只为合法聚合）
         MIN(n_rounds_obs)    AS n_rounds_obs,                                                  -- 续行：靴属性透传
         MIN(first_round_obs) AS first_round_obs,                                               -- 续行：靴属性透传
         MIN(is_edge)         AS is_edge,                                                       -- 续行：靴属性透传
         MIN(n_dt_shoe)       AS n_dt_shoe,                                                     -- 续行：靴属性透传
         MIN(round_no)        AS first_r,                                                       -- 聚合表达式：★该会员于该靴之入场局号，产出「first_r」
         MAX(round_no)        AS last_r,                                                        -- 聚合表达式：★该会员于该靴之末注局号，产出「last_r」
         COUNT(*)             AS n_bets_ms,                                                     -- 计数表达式：★会员×靴粒度之注单数（后缀 ms，禁与桌×靴之 n_bets_ts 同名）
         COUNT(DISTINCT bet_id)   AS n_bets_ms_distinct,                                        -- 计数表达式：会员×靴之去重注单数
         COUNT(DISTINCT round_no) AS n_rounds_ms                                                -- 计数表达式：★该会员于该靴实际下注之局数——覆盖率修正密度之分母
  FROM enriched GROUP BY member_id, table_id, shoe_id                                           -- 分组：会员×靴
),                                                                                              -- 续行：收束上方的子查询或函数括号
mem_agg AS (                                                                                    -- 公共表表达式：★会员级共用量之**唯一定义处**——§R01 与 §P13 一律引用，禁各自另算
  SELECT member_id,                                                                             -- 取列：会员号为主键
         SUM(n_bets_ms)                                  AS n_orders_all,                       -- 汇总表达式：★规范名 n_orders_all（旧名 n_orders 弃用）；恒等于注单层 COUNT(*)
         SUM(n_bets_ms_distinct)                         AS n_orders_all_distinct,              -- 汇总表达式：去重后注单数
         SUM(n_bets_ms) * 1.0                                                                   -- 除法计算：会员级去重比之分子
           / NULLIF(SUM(n_bets_ms_distinct),0)           AS dedup_ratio_member,                 -- 续行：★理想恒为 1；>1 即联结扇出未清
         COUNT(*)                                        AS n_shoes_uid,                        -- 计数表达式：所历双键靴数（粒度后缀 uid，禁裸名 n_shoes）
         SUM(n_bets_ms) * 1.0 / COUNT(*)                 AS bets_per_shoe_uid,                  -- 除法计算：每靴注单数——与 n_shoes_uid 同为样本可靠性之轴
         PERCENTILE_APPROX(n_rounds_obs * 1.0                                                   -- 取近似分位数表达式：观测覆盖率之中位——行为指标之可信度护栏
           / NULLIF(shoe_len_obs,0), 0.5)                AS round_coverage_p50,                 -- 续行：＝观测局数 ÷ 观测靴长；1.00 谓局号自 1 起连续无缺口
         PERCENTILE_APPROX(n_rounds_obs * 1.0                                                   -- 取近似分位数表达式：内段覆盖率之中位——剔起始偏移后之纯中段完整度
           / NULLIF(shoe_len_obs - first_round_obs + 1,0), 0.5)                                 -- 续行：分母＝实见局号跨距
                                                         AS interior_coverage_p50,              -- 续行：产出「interior_coverage_p50」
         AVG(first_round_obs - 1)                        AS start_offset_avg,                   -- 聚合表达式：起始偏移均值
         SUM(is_edge) * 1.0 / COUNT(*)                   AS edge_shoe_share,                    -- 汇总表达式：★触窗界之靴占比，其 shoe_len_obs 下偏故相对靴位上偏
         MAX(n_dt_shoe)                                  AS max_n_dt_shoe                       -- 聚合表达式：★所历靴之最大跨日数；≥3 即样本含靴号重用
  FROM mem_shoe GROUP BY member_id                                                              -- 分组：按会员（以会员×靴为行，故不被注单数加权）
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- △△△△△ 会员共用层 TIER-B 止 △△△△△
,
mem_bet AS (                                                                                    -- 公共表表达式：会员级 注单层聚合——C1 原 15 列悉出于此（§R01）
  SELECT member_id,                                                                             -- 取列：会员号为主键
         SUM(is_late)                                    AS n_orders_late,                      -- 汇总表达式：产出「n_orders_late」
         SUM(is_late) * 1.0 / COUNT(*)                   AS late_share,                         -- 汇总表达式：晚段注单占比（零偏好基准下期望 ≈ 1 − late_q）
         PERCENTILE_APPROX(CASE WHEN is_late=1 THEN shoe_pos END, 0.5)                          -- 取近似分位数表达式：★近似算法，小样本误差未量化，消费须配置信闸
                                                         AS shoe_pos_p50,                       -- 续行：产出「shoe_pos_p50」
         SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0)                       -- 汇总表达式：晚段平均注额
                                                         AS stake_late_avg,                     -- 续行：产出「stake_late_avg」
         SUM(CASE WHEN is_late=0 THEN stake END) / NULLIF(COUNT(*)-SUM(is_late),0)              -- 汇总表达式：早段平均注额
                                                         AS stake_early_avg,                    -- 续行：产出「stake_early_avg」
         (SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0))                     -- 汇总表达式：注额斜率之分子（晚段均注）
           / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END)                                     -- 除法计算：注额斜率之分母（早段均注）
                    / NULLIF(COUNT(*)-SUM(is_late),0), 0) AS stake_ramp,                        -- 续行：产出「stake_ramp」（>1 即靴末加注）
         SUM(CASE WHEN is_late=1 THEN game_pnl END)                                             -- 汇总表达式：晚段净盈亏
           / NULLIF(SUM(CASE WHEN is_late=1 THEN stake END),0) AS roi_late,                     -- 除法计算：★分母系分段本金，跨支比大小前须先同分母
         SUM(CASE WHEN is_late=0 THEN game_pnl END)                                             -- 汇总表达式：早段净盈亏
           / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END),0) AS roi_early,                    -- 除法计算：同上
         SUM(CASE WHEN is_late=1 THEN stake END)          AS stake_late,                        -- 汇总表达式：产出「stake_late」
         SUM(CASE WHEN is_late=1 THEN game_pnl END)       AS game_pnl_late,                     -- 汇总表达式：产出「game_pnl_late」
         SUM(stake)                                      AS stake_all,                          -- 汇总表达式：产出「stake_all」
         SUM(game_pnl)                                   AS game_pnl_all                        -- 汇总表达式：产出「game_pnl_all」（正即会员赢；平台 GGR 系其取负）
  FROM enriched GROUP BY member_id                                                              -- 分组：按会员
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- ▽▽▽▽▽ 诊断共用层 TIER-D 起（三节逐字同文；随行标量之来源）▽▽▽▽▽
d_agent AS (                                                                                    -- 公共表表达式：诊断·代理主档重复（治好数据不等于治好源头）
  SELECT (SELECT COUNT(*) FROM d_agents_raw)          AS n_test_agent_raw,                      -- 计数表达式：主档测试线原样行数
         (SELECT COUNT(*) FROM test_agents)           AS n_test_agent_distinct,                 -- 计数表达式：去重后名单行数
         (SELECT COUNT(*) FROM d_agents_raw)                                                    -- 减法计算：重复行数之分子
           - (SELECT COUNT(*) FROM test_agents)       AS duplicate_agent_id_count               -- 续行：★>0 即主档有重复，须另开上游工单（DISTINCT 只治症不治因）
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_dedup AS (                                                                                    -- 公共表表达式：诊断·去重完整与版本并列（升级建议 §十六／§十七）
  SELECT (SELECT COUNT(*) FROM ranked WHERE rn = 1)   AS n_rows_dedup,                          -- 计数表达式：去重后行数
         (SELECT COUNT(DISTINCT bet01) FROM ranked)   AS n_bet01,                               -- 计数表达式：注单号基数
         (SELECT COUNT(*) FROM ranked)                AS n_rows_ranked,                         -- 计数表达式：去重前行数
         (SELECT COUNT(*) FROM (                                                                -- 计数表达式：★版本并列之注单号数——
            SELECT bet01 FROM ranked WHERE rk = 1                                               -- 续行：rk = 1 者系并列首位之全部行
            GROUP BY bet01 HAVING COUNT(*) > 1) z)    AS dedup_tie_count                        -- 续行：同一注单号有二行以上并列首位 ⇒ rn 之取舍不定，重跑可漂移
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_type AS (                                                                                     -- 公共表表达式：诊断·局号类型异常分类（升级建议 §十八）
  SELECT COUNT(*)                                                     AS n_rows_raw,            -- 计数表达式：业务闸后、键闸前之行数（诊断之分母）
         COUNT(DISTINCT bet_id)                                       AS n_bets_distinct_raw,   -- 计数表达式：同上去重
         SUM(CASE WHEN table_id = '' THEN 1 ELSE 0 END)                AS n_null_table,         -- 汇总表达式：桌键空缺行数
         SUM(CASE WHEN shoe_id  = '' THEN 1 ELSE 0 END)                AS n_null_shoe,          -- 汇总表达式：靴键空缺行数
         SUM(CASE WHEN round_raw = '' THEN 1 ELSE 0 END)               AS n_round_empty,        -- 汇总表达式：局号空串行数
         SUM(CASE WHEN round_raw <> '' AND round_no IS NULL                                     -- 汇总表达式：★非空却转型失败者——即非数字字面
                  THEN 1 ELSE 0 END)                                  AS n_round_non_numeric,   -- 续行：CAST 于此静默变 NULL 而不报错，故非此列不可见
         SUM(CASE WHEN round_raw LIKE '%.%' THEN 1 ELSE 0 END)         AS n_round_fractional,   -- 汇总表达式：★含小数点者——CAST 可能截断而非失败，须单独计
         SUM(CASE WHEN round_no IS NOT NULL AND round_no <= 0                                   -- 汇总表达式：非正局号行数
                  THEN 1 ELSE 0 END)                                  AS n_round_le_zero,       -- 续行：产出「n_round_le_zero」
         SUM(CASE WHEN round_no > 0 THEN 1 ELSE 0 END)                 AS n_round_valid,        -- 汇总表达式：有效局号行数
         SUM(CASE WHEN member_id IS NULL OR member_id <= 0                                      -- 汇总表达式：会员号无效行数
                  THEN 1 ELSE 0 END)                                  AS n_member_invalid,      -- 续行：产出「n_member_invalid」
         SUM(CASE WHEN fx IS NULL OR fx <= 0 THEN 1 ELSE 0 END)        AS n_fx_invalid          -- 汇总表达式：汇率无效行数
  FROM raw                                                                                      -- 取数来源：★分母取未施键闸之 raw——若在同层顺手剔掉，被剔者即凭空消失，诊断永报零
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_key AS (                                                                                      -- 公共表表达式：诊断·靴键等价在带自证（升级建议 §四／§五）
  SELECT (SELECT COUNT(*) FROM shoe)                  AS n_shoes_2key,                          -- 计数表达式：双键靴数
         (SELECT COUNT(*) FROM shoe1)                 AS n_shoes_1key,                          -- 计数表达式：单键靴数
         (SELECT COUNT(*) FROM shoe)                                                            -- 减法计算：靴键等价之判据分子
           - (SELECT COUNT(*) FROM shoe1)             AS shoe_key_delta,                        -- 续行：★== 0 方可认单键与双键同粒度；换窗须重验，不外推
         (SELECT MAX(n_tab_per_shoe) FROM shoe1)      AS max_tables_per_shoe,                   -- 聚合表达式：★== 1 方可认无跨桌合并
         (SELECT SUM(CASE WHEN n_tab_per_shoe > 1 THEN 1 ELSE 0 END) * 1.0                      -- 除法计算：跨桌靴占比之分子
            / NULLIF(COUNT(*),0) FROM shoe1)          AS pct_cross_table,                       -- 续行：★== 0 方可认无跨桌合并
         (SELECT SUM(CASE WHEN n_dt_shoe >= 3 THEN 1 ELSE 0 END) FROM shoe)                     -- 汇总表达式：★跨 ≥3 营业日之靴数——靴号重用之直接计数
                                                      AS n_shoes_dt_ge3                         -- 续行：跨零点续接最多 2 日，故 ≥3 者必为重用；此闸补现有两项碰撞检验之盲区
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_scope AS (                                                                                    -- 公共表表达式：诊断·反截断三量与母体规模（升级建议 §十八）
  SELECT (SELECT COUNT(DISTINCT table_id) FROM gated_struct) AS n_tables_total,                 -- 计数表达式：★反截断——总桌数随行到达
         (SELECT COUNT(*) FROM shoe)                         AS n_shoes_total,                  -- 计数表达式：★反截断——总靴数（可与总包 §R01-0b 全域不变量对账）
         (SELECT COUNT(*) FROM gated_struct)                 AS n_bets_total,                   -- 计数表达式：★反截断——结构闸后总注单行数
         (SELECT COUNT(DISTINCT member_id) FROM gated_member) AS n_members_clean                -- 计数表达式：会员闸后之会员基数（全量洁净域）
),                                                                                              -- 续行：收束上方的子查询或函数括号
diag AS (                                                                                       -- 公共表表达式：诊断标量合并为一行，供 CROSS JOIN 随行（前端截断只截行不截列）
  SELECT ag.*, dd.*, ty.*, ky.*, sc.*, w2.*,                                                    -- 取列：六组标量
         dd.n_rows_dedup * 1.0 / NULLIF(dd.n_bet01,0)  AS dedup_integrity_ratio,                -- 除法计算：★去重完整率——恒为 1.000000；>1 即扇出或版本链假设不成立
         dd.dedup_tie_count * 1.0 / NULLIF(dd.n_bet01,0) AS dedup_tie_rate                      -- 除法计算：★版本并列率——>0 即重跑可漂移（判级 OBSERVED，非 DDL 证据）
  FROM d_agent ag CROSS JOIN d_dedup dd CROSS JOIN d_type ty                                    -- 取数来源：诊断各组叉乘
       CROSS JOIN d_key ky CROSS JOIN d_scope sc CROSS JOIN win w2                              -- 续行：叉乘续
)                                                                                               -- 续行：收束上方的子查询或函数括号
-- △△△△△ 诊断共用层 TIER-D 止 △△△△△
SELECT                                                                                          -- 取列：C1 契约 15 列在前，新增列一律后置
  m.member_id                        AS uid,                                                    -- C1·产出「uid」
  a.n_orders_all,                                                                               -- C1·★取自 TIER-B.mem_agg（唯一定义处）；恒等于旧式注单层 COUNT(*)
  m.n_orders_late,                                                                              -- C1
  'shoe_pos>=0.80'                   AS late_def,                                               -- C1·★口径锁字面保持原样以护血统
  m.late_share,                                                                                 -- C1
  m.shoe_pos_p50,                                                                               -- C1
  m.stake_late_avg,                                                                             -- C1
  m.stake_early_avg,                                                                            -- C1
  m.stake_ramp,                                                                                 -- C1
  m.roi_late,                                                                                   -- C1
  m.roi_early,                                                                                  -- C1
  m.stake_late,                                                                                 -- C1
  m.game_pnl_late,                                                                              -- C1
  m.stake_all,                                                                                  -- C1
  m.game_pnl_all,                                                                               -- C1（以上 15 列即 C1 契约，逐字未改）
  p.late_q,                                                                                     -- 新增·参数——口径锁之数值真身，供与 late_def 字面双录核对
  a.n_shoes_uid,                                                                                -- 新增·D 层——所历靴数（置信度之样本量）｜取自 mem_agg
  a.bets_per_shoe_uid,                                                                          -- 新增·D 层——每靴注单数｜取自 mem_agg
  CASE WHEN a.n_shoes_uid >= p.conf_min_shoes THEN 1 ELSE 0 END                                 -- 条件分支：★置信旗标——只作标记不作筛，改筛即改母体
                                     AS conf_shoes_ok,                                          -- 续行：产出「conf_shoes_ok」
  a.n_orders_all_distinct,                                                                      -- 新增·D 层——去重后注单数｜取自 mem_agg
  a.dedup_ratio_member,                                                                         -- 新增·D 层——会员级去重比（理想恒为 1）｜取自 mem_agg
  a.round_coverage_p50,                                                                         -- 新增·D 层——观测覆盖率中位（含起始偏移）｜取自 mem_agg
  a.interior_coverage_p50,                                                                      -- 新增·D 层——内段覆盖率中位（纯中段）｜取自 mem_agg
  a.start_offset_avg,                                                                           -- 新增·D 层——起始偏移均值｜取自 mem_agg
  a.edge_shoe_share,                                                                            -- 新增·D 层——边界靴占比｜取自 mem_agg
  a.max_n_dt_shoe,                                                                              -- 新增·D 层——所历靴之最大跨日数｜取自 mem_agg
  d.n_test_agent_raw,                                                                           -- 诊断·代理主档原样行数
  d.n_test_agent_distinct,                                                                      -- 诊断·去重后名单行数
  d.duplicate_agent_id_count,                                                                   -- 诊断·★>0 即主档重复，DISTINCT 只治症不治因
  d.n_rows_ranked,                                                                              -- 诊断·去重前行数
  d.n_rows_dedup,                                                                               -- 诊断·去重后行数
  d.n_bet01,                                                                                    -- 诊断·注单号基数
  d.dedup_integrity_ratio,                                                                      -- 诊断·★恒为 1.000000
  d.dedup_tie_count,                                                                            -- 诊断·★版本并列之注单号数；>0 即重跑可漂移
  d.dedup_tie_rate,                                                                             -- 诊断·版本并列率
  d.n_rows_raw,                                                                                 -- 诊断·业务闸后、键闸前行数（NULL 诊断之分母）
  d.n_bets_distinct_raw,                                                                        -- 诊断·同上去重
  d.n_null_table,                                                                               -- 诊断·桌键空缺
  d.n_null_shoe,                                                                                -- 诊断·靴键空缺
  d.n_round_empty,                                                                              -- 诊断·局号空串
  d.n_round_non_numeric,                                                                        -- 诊断·★局号非数字（CAST 静默变 NULL）
  d.n_round_fractional,                                                                         -- 诊断·★局号含小数点（CAST 可能截断）
  d.n_round_le_zero,                                                                            -- 诊断·局号非正
  d.n_round_valid,                                                                              -- 诊断·局号有效
  d.n_member_invalid,                                                                           -- 诊断·会员号无效
  d.n_fx_invalid,                                                                               -- 诊断·汇率无效
  d.n_shoes_2key,                                                                               -- 诊断·双键靴数
  d.n_shoes_1key,                                                                               -- 诊断·单键靴数
  d.shoe_key_delta,                                                                             -- 诊断·★靴键等价判据，== 0 方可用单键
  d.max_tables_per_shoe,                                                                        -- 诊断·★== 1 方可认无跨桌合并
  d.pct_cross_table,                                                                            -- 诊断·★== 0 方可认无跨桌合并
  d.n_shoes_dt_ge3,                                                                             -- 诊断·★跨 ≥3 日之靴数（靴号重用）
  d.n_tables_total,                                                                             -- 诊断·反截断·总桌数
  d.n_shoes_total,                                                                              -- 诊断·反截断·总靴数
  d.n_bets_total,                                                                               -- 诊断·反截断·总注单行数
  d.n_members_clean,                                                                            -- 诊断·全量洁净域会员数
  d.dt_first,                                                                                   -- 诊断·实见首营业日
  d.dt_last                                                                                     -- 诊断·实见末营业日
FROM mem_bet m                                                                                  -- 取数来源：会员级注单层聚合（只出金额与晚段之量）
JOIN mem_agg a ON a.member_id = m.member_id                                                     -- 内连接：★挂 TIER-B.mem_agg——会员级共用量之唯一定义处
CROSS JOIN d_params p                                                                           -- 叉乘：参数层一行
CROSS JOIN diag     d                                                                           -- 叉乘：诊断标量一行
WHERE a.n_orders_all >= p.min_orders                                                            -- 过滤条件：★活跃度门槛取自 d_params（旧为 HAVING 字面 100）
ORDER BY m.late_share DESC, m.n_orders_late DESC, m.member_id                                   -- 排序：★末加 member_id 作决胜键令导出为全序；禁 OFFSET 分页
;

-- 【故意不加之筛选｜原注保留】此处故意不加 late_share >= 0.70 之门槛。报告需要
--   「命中组 vs 对照组」之 hold% 对照方能作经济裁定，只导命中组即无对照组。
--   阈值筛选一律放在 R 侧；若行数过大，改提 d_params.min_orders，而**不是**加 late_share 条件。

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- §P13 · P13_personal_entry.csv · 会员入场行为层（消费已验证之 shoe grain）
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 粒度：uid × 1（过 d_params.min_orders 门槛者）
-- 定位：**行为观测层**。本节不再自行定义 shoe truth，一律消费 TIER-A.shoe 之双键靴。
-- 与旧版之实质差异（须在回灌说明中登记）：
--   ① 靴键由单键 bet03 改双键 (bet39,bet03)（§D01 冲突 01），且每批以 d_key 自证；
--   ② entry_pos／exit_pos 更名 *_obs 并判级 OBSERVED·代理（§D01 冲突 07）；
--   ③ bet_density 二式并出（§D01 冲突 08）；三量皆出 P25/P50/P75（§D01 冲突 09）；
--   ④ n_orders 更名 n_orders_all（§D01 冲突 05）；门槛改取 d_params（冲突 11）；
--   ⑤ 增覆盖率护栏与置信旗标（冲突 12）；bet04 行注释「局内序号」笔误已改（冲突 06）。
-- ▸ 导出：需要 —— 存为「数据库/P13_personal_entry.csv」。

WITH
-- ▽▽▽▽▽ 共用口径层 TIER-A 起（三节逐字同文；改一处须三处同改，G-0 闸机检）▽▽▽▽▽
d_params AS (                                                                                   -- 公共表表达式：★参数单点声明层——全包一切阈值只此一处，禁他处再写字面
  SELECT 0.80  AS late_q,                                                                       -- 取值表达式：相对靴位判据阈值，产出「late_q」（口径锁之数值真身）
         100   AS min_orders,                                                                   -- 取值表达式：会员域活跃度门槛（注单数），产出「min_orders」
         10    AS conf_min_shoes                                                                -- 取值表达式：★分位类指标之置信靴数下限（只作旗标不作筛，候裁定）
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_agents_raw AS (                                                                               -- 公共表表达式：代理主档测试线**未去重**原样——供重复诊断，禁直接联结
  SELECT age001 AS agent_id                                                                     -- 取列：产出「agent_id」（原样，可能重复）
  FROM ods_mariadb_2b.ods_a168_agent                                                            -- 取数来源：代理主档
  WHERE age022 = '1'                                                                            -- 过滤条件：测试线旗标（铁律④b）
),                                                                                              -- 续行：收束上方的子查询或函数括号
test_agents AS (                                                                                -- 公共表表达式：★去重后之测试线名单——防扇出，唯一可用于联结者
  SELECT DISTINCT agent_id FROM d_agents_raw                                                    -- 取列：★DISTINCT——主档若重复，五路左连接会把一注扇成多行且 SQL 不报错
),                                                                                              -- 续行：收束上方的子查询或函数括号
ranked AS (                                                                                     -- 公共表表达式：同注单号取最新版本 ＋ 并列诊断（rk）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                     -- 取列：涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,                                  -- 续行：涉 bet03（靴号）、bet04（局号）、bet05（会员号）、bet11（汇率）、bet13、bet14
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                           -- 续行：五级代理线
         b.bet38, b.bet39, b.category,                                                          -- 续行：涉 bet38（测试标识）、bet39（桌号）、category（注单类别）
         ROW_NUMBER() OVER (                                                                    -- 行号窗口表达式：取每注单号之一行
           PARTITION BY b.bet01                                                                 -- 窗口分区：按注单号（★此键之唯一性系 OBSERVED，非 DDL 证据，见 d_dedup）
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn,                      -- 排序：三级降序；★三键全同者 rn 之取舍不定，故并出 rk 以量其规模
         RANK() OVER (                                                                          -- 排名窗口表达式：★并列检测——同分者同 rk
           PARTITION BY b.bet01                                                                 -- 窗口分区：同上分区，同上排序，方可与 rn 对照
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rk                       -- 排序：同上；rk = 1 之行数 > 1 即版本并列，重跑可漂移
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                          -- 取数来源：注单明细表（★表名开关）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                            -- 过滤条件：限定全局窗（半开区间；两端之靴被切尾，故下设 is_edge）
    AND b.bet02 = '101'                                                                         -- 并列条件：限定百家乐
),                                                                                              -- 续行：收束上方的子查询或函数括号
raw AS (                                                                                        -- 公共表表达式：★第一闸——只施**业务闸**，不施键闸；系一切诊断之分母
  SELECT r.bet01 AS bet_id, r.dt,                                                               -- 取列：产出「bet_id」并透传营业日
         TRIM(r.bet39) AS table_id,                                                             -- 取值表达式：★TRIM 防键分裂——不去空白则 '112' 与 ' 112' 裂为两桌
         TRIM(r.bet03) AS shoe_id,                                                              -- 取值表达式：★TRIM 防键分裂
         TRIM(r.bet04) AS round_raw,                                                            -- 取值表达式：★局号之**原样字面**——供类型异常分类（非数字／小数／科学记数）
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                           -- 取值表达式：去空白、空串归 NULL、显式转型，产出「round_no」（局号）
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,                          -- 取值表达式：同上转型规则，产出「member_id」（会员号）
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                 -- 取值表达式：同上转型规则，产出「fx」（汇率）
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                          -- 取值表达式：同上转型规则，产出「stake_raw」（原币下注额）
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw                          -- 取值表达式：同上转型规则，产出「payout_raw」（原币派彩额）
  FROM ranked r                                                                                 -- 取数来源：中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                             -- 左连接：一级线对测试名单（StarRocks 不支持 EXISTS 配多列 IN，故用五路左连接）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                             -- 左连接：二级线对测试名单
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                             -- 左连接：三级线对测试名单
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                             -- 左连接：四级线对测试名单
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                             -- 左连接：五级线对测试名单
  WHERE r.rn = 1                                                                                -- 过滤条件：只留一行（版本链去重）
    AND r.category = '1'                                                                        -- 并列条件：一般注单准入
    AND UPPER(TRIM(r.bet38)) = 'N'                                                              -- 并列条件：排除测试单
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL           -- 并列条件：五级任一命中测试线即剔
),                                                                                              -- 续行：收束上方的子查询或函数括号
gated_struct AS (                                                                               -- 公共表表达式：★第二闸——**结构键闸**。结构真相之母体，禁以经济闸收窄
  SELECT * FROM raw                                                                             -- 取列：承 raw 全列
  WHERE table_id <> '' AND shoe_id <> '' AND round_no > 0                                       -- 过滤条件：★三键闸——空键聚成幻影桌／幻影靴；非正局号亦剔
),                                                                                              -- 续行：收束上方的子查询或函数括号
win AS (                                                                                        -- 公共表表达式：窗界现取层——边界日由数据自证，不写死日期字面
  SELECT MIN(dt) AS dt_first, MAX(dt) AS dt_last FROM gated_struct                              -- 聚合表达式：产出「dt_first」「dt_last」（实见首末营业日，可能窄于名义窗）
),                                                                                              -- 续行：收束上方的子查询或函数括号
shoe AS (                                                                                       -- 公共表表达式：★结构真相层——(table_id, shoe_id) 双键为**全包唯一**之权威靴键
  SELECT g.table_id, g.shoe_id,                                                                 -- 取列：双键
         MAX(g.round_no)            AS shoe_len_obs,                                            -- 计数表达式：★观测靴长代理＝最大局号，**非局数**；真靴长待权威表 P0。全包唯一定义处
         MIN(g.round_no)            AS first_round_obs,                                         -- 聚合表达式：实见首局号（起始偏移 ＝ 其减一）
         COUNT(DISTINCT g.round_no) AS n_rounds_obs,                                            -- 计数表达式：★观测局数＝实见局号种数；一切**计数类**分母之正解
         COUNT(*)                   AS n_bets_ts,                                               -- 计数表达式：靴内注单行数（桌×靴粒度，故后缀 ts，禁与会员×靴之 n_bets_ms 同名）
         COUNT(DISTINCT g.bet_id)   AS n_bets_ts_distinct,                                      -- 计数表达式：靴内去重注单数
         COUNT(DISTINCT g.dt)       AS n_dt_shoe,                                               -- 计数表达式：★横跨营业日数——跨零点续接最多 2 日，≥3 必为靴号重用
         MAX(CASE WHEN g.dt = w.dt_first OR g.dt = w.dt_last                                    -- 条件分支：★边界靴旗标
                  THEN 1 ELSE 0 END) AS is_edge                                                 -- 续行：产出「is_edge」（1 ＝ 触窗界，其 shoe_len_obs 系下偏值）
  FROM gated_struct g CROSS JOIN win w                                                          -- 取数来源：结构闸后之母体叉乘窗界一行
  GROUP BY g.table_id, g.shoe_id                                                                -- 分组：按双键靴
),                                                                                              -- 续行：收束上方的子查询或函数括号
shoe1 AS (                                                                                      -- 公共表表达式：单键靴之同批对照——供靴键等价在带自证
  SELECT shoe_id, COUNT(DISTINCT table_id) AS n_tab_per_shoe                                    -- 计数表达式：每靴号所涉桌数；>1 即跨桌
  FROM gated_struct GROUP BY shoe_id                                                            -- 分组：按单键靴号
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- △△△△△ 共用口径层 TIER-A 止 △△△△△
,
-- ▽▽▽▽▽ 会员共用层 TIER-B 起（§R01 与 §P13 逐字同文；G-0 闸机检）▽▽▽▽▽
gated_member AS (                                                                               -- 公共表表达式：★第三闸——**会员／金额闸**。仅会员级两节用之，禁上溯收窄结构真相
  SELECT * FROM gated_struct                                                                    -- 取列：承结构闸后之母体
  WHERE member_id > 0 AND fx > 0                                                                -- 过滤条件：★会员号须正、汇率须正（分母非零）。二闸并施系为令 §R01 与 §P13 同母体
),                                                                                              -- 续行：收束上方的子查询或函数括号
enriched AS (                                                                                   -- 公共表表达式：注单级挂结构真相并派生位置与金额（会员两节共用）
  SELECT m.bet_id, m.member_id, m.table_id, m.shoe_id, m.round_no,                              -- 取列：注单级键与局号
         s.shoe_len_obs, s.first_round_obs, s.n_rounds_obs,                                     -- 续行：透传结构真相层三量
         s.n_dt_shoe, s.is_edge,                                                                -- 续行：透传结构真相层二旗标
         m.round_no * 1.0 / NULLIF(s.shoe_len_obs,0)  AS shoe_pos,                              -- 取值表达式：★相对靴位＝局号 ÷ 观测靴长（逐靴自归一化）。全包唯一定义处
         m.stake_raw / m.fx                           AS stake,                                 -- 取值表达式：本金口径＝原币下注额 ÷ 汇率。全包唯一定义处
         (m.payout_raw - m.stake_raw) / m.fx          AS game_pnl,                              -- 取值表达式：会员净盈亏（不含退水）。全包唯一定义处
         CASE WHEN m.round_no * 1.0 / NULLIF(s.shoe_len_obs,0) >= p.late_q                      -- 条件分支：★晚段判据取 d_params.late_q，禁写死字面
              THEN 1 ELSE 0 END                       AS is_late                                -- 续行：产出「is_late」（1 ＝ 该注落于靴末 (1−late_q) 之局位区间）
  FROM gated_member m                                                                           -- 取数来源：会员闸后之母体
  JOIN shoe s ON s.table_id = m.table_id AND s.shoe_id = m.shoe_id                              -- 内连接：★以**双键**挂结构真相层——单键挂靴即靴号重用之污染入口
  CROSS JOIN d_params p                                                                         -- 叉乘：参数层一行
),                                                                                              -- 续行：收束上方的子查询或函数括号
mem_shoe AS (                                                                                   -- 公共表表达式：会员×靴 中间粒度——观测质量须在此粒度算，方不被注单数加权
  SELECT member_id, table_id, shoe_id,                                                          -- 取列：会员×双键靴
         MIN(shoe_len_obs)    AS shoe_len_obs,                                                  -- 聚合表达式：靴属性透传（组内单值，取 MIN 只为合法聚合）
         MIN(n_rounds_obs)    AS n_rounds_obs,                                                  -- 续行：靴属性透传
         MIN(first_round_obs) AS first_round_obs,                                               -- 续行：靴属性透传
         MIN(is_edge)         AS is_edge,                                                       -- 续行：靴属性透传
         MIN(n_dt_shoe)       AS n_dt_shoe,                                                     -- 续行：靴属性透传
         MIN(round_no)        AS first_r,                                                       -- 聚合表达式：★该会员于该靴之入场局号，产出「first_r」
         MAX(round_no)        AS last_r,                                                        -- 聚合表达式：★该会员于该靴之末注局号，产出「last_r」
         COUNT(*)             AS n_bets_ms,                                                     -- 计数表达式：★会员×靴粒度之注单数（后缀 ms，禁与桌×靴之 n_bets_ts 同名）
         COUNT(DISTINCT bet_id)   AS n_bets_ms_distinct,                                        -- 计数表达式：会员×靴之去重注单数
         COUNT(DISTINCT round_no) AS n_rounds_ms                                                -- 计数表达式：★该会员于该靴实际下注之局数——覆盖率修正密度之分母
  FROM enriched GROUP BY member_id, table_id, shoe_id                                           -- 分组：会员×靴
),                                                                                              -- 续行：收束上方的子查询或函数括号
mem_agg AS (                                                                                    -- 公共表表达式：★会员级共用量之**唯一定义处**——§R01 与 §P13 一律引用，禁各自另算
  SELECT member_id,                                                                             -- 取列：会员号为主键
         SUM(n_bets_ms)                                  AS n_orders_all,                       -- 汇总表达式：★规范名 n_orders_all（旧名 n_orders 弃用）；恒等于注单层 COUNT(*)
         SUM(n_bets_ms_distinct)                         AS n_orders_all_distinct,              -- 汇总表达式：去重后注单数
         SUM(n_bets_ms) * 1.0                                                                   -- 除法计算：会员级去重比之分子
           / NULLIF(SUM(n_bets_ms_distinct),0)           AS dedup_ratio_member,                 -- 续行：★理想恒为 1；>1 即联结扇出未清
         COUNT(*)                                        AS n_shoes_uid,                        -- 计数表达式：所历双键靴数（粒度后缀 uid，禁裸名 n_shoes）
         SUM(n_bets_ms) * 1.0 / COUNT(*)                 AS bets_per_shoe_uid,                  -- 除法计算：每靴注单数——与 n_shoes_uid 同为样本可靠性之轴
         PERCENTILE_APPROX(n_rounds_obs * 1.0                                                   -- 取近似分位数表达式：观测覆盖率之中位——行为指标之可信度护栏
           / NULLIF(shoe_len_obs,0), 0.5)                AS round_coverage_p50,                 -- 续行：＝观测局数 ÷ 观测靴长；1.00 谓局号自 1 起连续无缺口
         PERCENTILE_APPROX(n_rounds_obs * 1.0                                                   -- 取近似分位数表达式：内段覆盖率之中位——剔起始偏移后之纯中段完整度
           / NULLIF(shoe_len_obs - first_round_obs + 1,0), 0.5)                                 -- 续行：分母＝实见局号跨距
                                                         AS interior_coverage_p50,              -- 续行：产出「interior_coverage_p50」
         AVG(first_round_obs - 1)                        AS start_offset_avg,                   -- 聚合表达式：起始偏移均值
         SUM(is_edge) * 1.0 / COUNT(*)                   AS edge_shoe_share,                    -- 汇总表达式：★触窗界之靴占比，其 shoe_len_obs 下偏故相对靴位上偏
         MAX(n_dt_shoe)                                  AS max_n_dt_shoe                       -- 聚合表达式：★所历靴之最大跨日数；≥3 即样本含靴号重用
  FROM mem_shoe GROUP BY member_id                                                              -- 分组：按会员（以会员×靴为行，故不被注单数加权）
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- △△△△△ 会员共用层 TIER-B 止 △△△△△
,
mem_entry AS (                                                                                  -- 公共表表达式：会员级 入场／退出／密度（自会员×靴层聚合，故不被注单数加权）
  SELECT member_id,                                                                             -- 取列：会员号为主键。★共用量（n_orders_all／n_shoes_uid／覆盖率等）一律不在此重算
         PERCENTILE_APPROX(first_r * 1.0                                                        -- 取近似分位数表达式：★入场相对靴位——分母系代理量，故比值亦为代理
           / NULLIF(shoe_len_obs,0), 0.25)                  AS entry_pos_obs_p25,               -- 续行：P25，产出「entry_pos_obs_p25」
         PERCENTILE_APPROX(first_r * 1.0                                                        -- 取近似分位数表达式：入场相对靴位
           / NULLIF(shoe_len_obs,0), 0.50)                  AS entry_pos_obs_p50,               -- 续行：P50
         PERCENTILE_APPROX(first_r * 1.0                                                        -- 取近似分位数表达式：入场相对靴位
           / NULLIF(shoe_len_obs,0), 0.75)                  AS entry_pos_obs_p75,               -- 续行：P75——与 P25 并出方能分「稳定早入型」与「极端跳跃型」
         PERCENTILE_APPROX(last_r * 1.0                                                         -- 取近似分位数表达式：退出相对靴位
           / NULLIF(shoe_len_obs,0), 0.25)                  AS exit_pos_obs_p25,                -- 续行：P25
         PERCENTILE_APPROX(last_r * 1.0                                                         -- 取近似分位数表达式：退出相对靴位
           / NULLIF(shoe_len_obs,0), 0.50)                  AS exit_pos_obs_p50,                -- 续行：P50
         PERCENTILE_APPROX(last_r * 1.0                                                         -- 取近似分位数表达式：退出相对靴位
           / NULLIF(shoe_len_obs,0), 0.75)                  AS exit_pos_obs_p75,                -- 续行：P75
         PERCENTILE_APPROX(n_bets_ms * 1.0                                                      -- 取近似分位数表达式：★名义密度——分母系首末跨度，混三事故留作血统对照
           / NULLIF(last_r - first_r + 1,0), 0.25)          AS bet_density_nominal_p25,         -- 续行：P25
         PERCENTILE_APPROX(n_bets_ms * 1.0                                                      -- 取近似分位数表达式：名义密度
           / NULLIF(last_r - first_r + 1,0), 0.50)          AS bet_density_nominal_p50,         -- 续行：P50
         PERCENTILE_APPROX(n_bets_ms * 1.0                                                      -- 取近似分位数表达式：名义密度
           / NULLIF(last_r - first_r + 1,0), 0.75)          AS bet_density_nominal_p75,         -- 续行：P75
         PERCENTILE_APPROX(n_bets_ms * 1.0                                                      -- 取近似分位数表达式：★观测密度——分母改该会员于该靴实际有注之局数
           / NULLIF(n_rounds_ms,0), 0.25)                   AS bet_density_obs_p25,             -- 续行：P25；此式不把「局号缺失」记成「下注稀疏」
         PERCENTILE_APPROX(n_bets_ms * 1.0                                                      -- 取近似分位数表达式：观测密度
           / NULLIF(n_rounds_ms,0), 0.50)                   AS bet_density_obs_p50,             -- 续行：P50
         PERCENTILE_APPROX(n_bets_ms * 1.0                                                      -- 取近似分位数表达式：观测密度
           / NULLIF(n_rounds_ms,0), 0.75)                   AS bet_density_obs_p75,             -- 续行：P75
         AVG(first_r)                                       AS entry_round_avg,                 -- 聚合表达式：★绝对入场局均值——判级 ABSOLUTE_POSITION，**跨桌不可比**
         AVG(last_r - first_r + 1)                          AS span_rounds_avg                  -- 聚合表达式：停留跨度均值（局数）
  FROM mem_shoe GROUP BY member_id                                                              -- 分组：按会员
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- ▽▽▽▽▽ 诊断共用层 TIER-D 起（三节逐字同文；随行标量之来源）▽▽▽▽▽
d_agent AS (                                                                                    -- 公共表表达式：诊断·代理主档重复（治好数据不等于治好源头）
  SELECT (SELECT COUNT(*) FROM d_agents_raw)          AS n_test_agent_raw,                      -- 计数表达式：主档测试线原样行数
         (SELECT COUNT(*) FROM test_agents)           AS n_test_agent_distinct,                 -- 计数表达式：去重后名单行数
         (SELECT COUNT(*) FROM d_agents_raw)                                                    -- 减法计算：重复行数之分子
           - (SELECT COUNT(*) FROM test_agents)       AS duplicate_agent_id_count               -- 续行：★>0 即主档有重复，须另开上游工单（DISTINCT 只治症不治因）
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_dedup AS (                                                                                    -- 公共表表达式：诊断·去重完整与版本并列（升级建议 §十六／§十七）
  SELECT (SELECT COUNT(*) FROM ranked WHERE rn = 1)   AS n_rows_dedup,                          -- 计数表达式：去重后行数
         (SELECT COUNT(DISTINCT bet01) FROM ranked)   AS n_bet01,                               -- 计数表达式：注单号基数
         (SELECT COUNT(*) FROM ranked)                AS n_rows_ranked,                         -- 计数表达式：去重前行数
         (SELECT COUNT(*) FROM (                                                                -- 计数表达式：★版本并列之注单号数——
            SELECT bet01 FROM ranked WHERE rk = 1                                               -- 续行：rk = 1 者系并列首位之全部行
            GROUP BY bet01 HAVING COUNT(*) > 1) z)    AS dedup_tie_count                        -- 续行：同一注单号有二行以上并列首位 ⇒ rn 之取舍不定，重跑可漂移
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_type AS (                                                                                     -- 公共表表达式：诊断·局号类型异常分类（升级建议 §十八）
  SELECT COUNT(*)                                                     AS n_rows_raw,            -- 计数表达式：业务闸后、键闸前之行数（诊断之分母）
         COUNT(DISTINCT bet_id)                                       AS n_bets_distinct_raw,   -- 计数表达式：同上去重
         SUM(CASE WHEN table_id = '' THEN 1 ELSE 0 END)                AS n_null_table,         -- 汇总表达式：桌键空缺行数
         SUM(CASE WHEN shoe_id  = '' THEN 1 ELSE 0 END)                AS n_null_shoe,          -- 汇总表达式：靴键空缺行数
         SUM(CASE WHEN round_raw = '' THEN 1 ELSE 0 END)               AS n_round_empty,        -- 汇总表达式：局号空串行数
         SUM(CASE WHEN round_raw <> '' AND round_no IS NULL                                     -- 汇总表达式：★非空却转型失败者——即非数字字面
                  THEN 1 ELSE 0 END)                                  AS n_round_non_numeric,   -- 续行：CAST 于此静默变 NULL 而不报错，故非此列不可见
         SUM(CASE WHEN round_raw LIKE '%.%' THEN 1 ELSE 0 END)         AS n_round_fractional,   -- 汇总表达式：★含小数点者——CAST 可能截断而非失败，须单独计
         SUM(CASE WHEN round_no IS NOT NULL AND round_no <= 0                                   -- 汇总表达式：非正局号行数
                  THEN 1 ELSE 0 END)                                  AS n_round_le_zero,       -- 续行：产出「n_round_le_zero」
         SUM(CASE WHEN round_no > 0 THEN 1 ELSE 0 END)                 AS n_round_valid,        -- 汇总表达式：有效局号行数
         SUM(CASE WHEN member_id IS NULL OR member_id <= 0                                      -- 汇总表达式：会员号无效行数
                  THEN 1 ELSE 0 END)                                  AS n_member_invalid,      -- 续行：产出「n_member_invalid」
         SUM(CASE WHEN fx IS NULL OR fx <= 0 THEN 1 ELSE 0 END)        AS n_fx_invalid          -- 汇总表达式：汇率无效行数
  FROM raw                                                                                      -- 取数来源：★分母取未施键闸之 raw——若在同层顺手剔掉，被剔者即凭空消失，诊断永报零
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_key AS (                                                                                      -- 公共表表达式：诊断·靴键等价在带自证（升级建议 §四／§五）
  SELECT (SELECT COUNT(*) FROM shoe)                  AS n_shoes_2key,                          -- 计数表达式：双键靴数
         (SELECT COUNT(*) FROM shoe1)                 AS n_shoes_1key,                          -- 计数表达式：单键靴数
         (SELECT COUNT(*) FROM shoe)                                                            -- 减法计算：靴键等价之判据分子
           - (SELECT COUNT(*) FROM shoe1)             AS shoe_key_delta,                        -- 续行：★== 0 方可认单键与双键同粒度；换窗须重验，不外推
         (SELECT MAX(n_tab_per_shoe) FROM shoe1)      AS max_tables_per_shoe,                   -- 聚合表达式：★== 1 方可认无跨桌合并
         (SELECT SUM(CASE WHEN n_tab_per_shoe > 1 THEN 1 ELSE 0 END) * 1.0                      -- 除法计算：跨桌靴占比之分子
            / NULLIF(COUNT(*),0) FROM shoe1)          AS pct_cross_table,                       -- 续行：★== 0 方可认无跨桌合并
         (SELECT SUM(CASE WHEN n_dt_shoe >= 3 THEN 1 ELSE 0 END) FROM shoe)                     -- 汇总表达式：★跨 ≥3 营业日之靴数——靴号重用之直接计数
                                                      AS n_shoes_dt_ge3                         -- 续行：跨零点续接最多 2 日，故 ≥3 者必为重用；此闸补现有两项碰撞检验之盲区
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_scope AS (                                                                                    -- 公共表表达式：诊断·反截断三量与母体规模（升级建议 §十八）
  SELECT (SELECT COUNT(DISTINCT table_id) FROM gated_struct) AS n_tables_total,                 -- 计数表达式：★反截断——总桌数随行到达
         (SELECT COUNT(*) FROM shoe)                         AS n_shoes_total,                  -- 计数表达式：★反截断——总靴数（可与总包 §R01-0b 全域不变量对账）
         (SELECT COUNT(*) FROM gated_struct)                 AS n_bets_total,                   -- 计数表达式：★反截断——结构闸后总注单行数
         (SELECT COUNT(DISTINCT member_id) FROM gated_member) AS n_members_clean                -- 计数表达式：会员闸后之会员基数（全量洁净域）
),                                                                                              -- 续行：收束上方的子查询或函数括号
diag AS (                                                                                       -- 公共表表达式：诊断标量合并为一行，供 CROSS JOIN 随行（前端截断只截行不截列）
  SELECT ag.*, dd.*, ty.*, ky.*, sc.*, w2.*,                                                    -- 取列：六组标量
         dd.n_rows_dedup * 1.0 / NULLIF(dd.n_bet01,0)  AS dedup_integrity_ratio,                -- 除法计算：★去重完整率——恒为 1.000000；>1 即扇出或版本链假设不成立
         dd.dedup_tie_count * 1.0 / NULLIF(dd.n_bet01,0) AS dedup_tie_rate                      -- 除法计算：★版本并列率——>0 即重跑可漂移（判级 OBSERVED，非 DDL 证据）
  FROM d_agent ag CROSS JOIN d_dedup dd CROSS JOIN d_type ty                                    -- 取数来源：诊断各组叉乘
       CROSS JOIN d_key ky CROSS JOIN d_scope sc CROSS JOIN win w2                              -- 续行：叉乘续
)                                                                                               -- 续行：收束上方的子查询或函数括号
-- △△△△△ 诊断共用层 TIER-D 止 △△△△△
SELECT                                                                                          -- 取列：行为层在前，护栏与诊断后置
  e.member_id                        AS uid,                                                    -- 取值表达式：产出「uid」
  a.n_shoes_uid,                                                                                -- B 行为层·所历靴数｜取自 TIER-B.mem_agg（唯一定义处）
  a.n_orders_all,                                                                               -- B 行为层·注单总数（规范名）｜取自 mem_agg
  a.n_orders_all_distinct,                                                                      -- B 行为层·去重后注单数｜取自 mem_agg
  a.dedup_ratio_member,                                                                         -- B 行为层·会员级去重比（理想恒为 1）｜取自 mem_agg
  a.bets_per_shoe_uid,                                                                          -- B 行为层·每靴注单数｜取自 mem_agg
  CASE WHEN a.n_shoes_uid >= p.conf_min_shoes THEN 1 ELSE 0 END                                 -- 条件分支：★置信旗标——只作标记不作筛
                                     AS conf_shoes_ok,                                          -- 续行：产出「conf_shoes_ok」
  e.entry_pos_obs_p25,                                                                          -- A 入场·判级 OBSERVED·代理
  e.entry_pos_obs_p50,                                                                          -- A 入场·判级 OBSERVED·代理
  e.entry_pos_obs_p75,                                                                          -- A 入场·判级 OBSERVED·代理
  e.exit_pos_obs_p25,                                                                           -- A 退出·判级 OBSERVED·代理
  e.exit_pos_obs_p50,                                                                           -- A 退出·判级 OBSERVED·代理
  e.exit_pos_obs_p75,                                                                           -- A 退出·判级 OBSERVED·代理
  e.bet_density_nominal_p25,                                                                    -- C 密度·旧式（血统对照）
  e.bet_density_nominal_p50,                                                                    -- C 密度·旧式（血统对照）
  e.bet_density_nominal_p75,                                                                    -- C 密度·旧式（血统对照）
  e.bet_density_obs_p25,                                                                        -- C 密度·★正解（分母为实际有注之局数）
  e.bet_density_obs_p50,                                                                        -- C 密度·★正解
  e.bet_density_obs_p75,                                                                        -- C 密度·★正解
  e.span_rounds_avg,                                                                            -- C 持续·停留跨度均值
  e.entry_round_avg,                                                                            -- ★判级 ABSOLUTE_POSITION——跨桌不可比，禁与相对位混读
  a.round_coverage_p50,                                                                         -- D 护栏·观测覆盖率中位｜取自 mem_agg
  a.interior_coverage_p50,                                                                      -- D 护栏·内段覆盖率中位｜取自 mem_agg
  a.start_offset_avg,                                                                           -- D 护栏·起始偏移均值｜取自 mem_agg
  a.edge_shoe_share,                                                                            -- D 护栏·边界靴占比｜取自 mem_agg
  a.max_n_dt_shoe,                                                                              -- D 护栏·所历靴之最大跨日数｜取自 mem_agg
  d.n_test_agent_raw,                                                                           -- 诊断·代理主档原样行数
  d.n_test_agent_distinct,                                                                      -- 诊断·去重后名单行数
  d.duplicate_agent_id_count,                                                                   -- 诊断·★>0 即主档重复，DISTINCT 只治症不治因
  d.n_rows_ranked,                                                                              -- 诊断·去重前行数
  d.n_rows_dedup,                                                                               -- 诊断·去重后行数
  d.n_bet01,                                                                                    -- 诊断·注单号基数
  d.dedup_integrity_ratio,                                                                      -- 诊断·★恒为 1.000000
  d.dedup_tie_count,                                                                            -- 诊断·★版本并列之注单号数；>0 即重跑可漂移
  d.dedup_tie_rate,                                                                             -- 诊断·版本并列率
  d.n_rows_raw,                                                                                 -- 诊断·业务闸后、键闸前行数（NULL 诊断之分母）
  d.n_bets_distinct_raw,                                                                        -- 诊断·同上去重
  d.n_null_table,                                                                               -- 诊断·桌键空缺
  d.n_null_shoe,                                                                                -- 诊断·靴键空缺
  d.n_round_empty,                                                                              -- 诊断·局号空串
  d.n_round_non_numeric,                                                                        -- 诊断·★局号非数字（CAST 静默变 NULL）
  d.n_round_fractional,                                                                         -- 诊断·★局号含小数点（CAST 可能截断）
  d.n_round_le_zero,                                                                            -- 诊断·局号非正
  d.n_round_valid,                                                                              -- 诊断·局号有效
  d.n_member_invalid,                                                                           -- 诊断·会员号无效
  d.n_fx_invalid,                                                                               -- 诊断·汇率无效
  d.n_shoes_2key,                                                                               -- 诊断·双键靴数
  d.n_shoes_1key,                                                                               -- 诊断·单键靴数
  d.shoe_key_delta,                                                                             -- 诊断·★靴键等价判据，== 0 方可用单键
  d.max_tables_per_shoe,                                                                        -- 诊断·★== 1 方可认无跨桌合并
  d.pct_cross_table,                                                                            -- 诊断·★== 0 方可认无跨桌合并
  d.n_shoes_dt_ge3,                                                                             -- 诊断·★跨 ≥3 日之靴数（靴号重用）
  d.n_tables_total,                                                                             -- 诊断·反截断·总桌数
  d.n_shoes_total,                                                                              -- 诊断·反截断·总靴数
  d.n_bets_total,                                                                               -- 诊断·反截断·总注单行数
  d.n_members_clean,                                                                            -- 诊断·全量洁净域会员数
  d.dt_first,                                                                                   -- 诊断·实见首营业日
  d.dt_last                                                                                     -- 诊断·实见末营业日
FROM mem_entry e                                                                                -- 取数来源：会员级行为层（只出入场／退出／密度／跨度）
JOIN mem_agg a ON a.member_id = e.member_id                                                     -- 内连接：★挂 TIER-B.mem_agg——会员级共用量之唯一定义处
CROSS JOIN d_params p                                                                           -- 叉乘：参数层一行
CROSS JOIN diag     d                                                                           -- 叉乘：诊断标量一行
WHERE a.n_orders_all >= p.min_orders                                                            -- 过滤条件：★门槛取自 d_params（旧为 HAVING 字面 100）
ORDER BY e.member_id                                                                            -- 排序：keyset 稳定序（会员号唯一，故已是全序）；禁 OFFSET 分页
;

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- §P14 · P14_table_shoe_truth.csv · 桌级结构真相与观测质量探针
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
-- 粒度：table_id × 1
-- 定位：**数据质量与结构事实层**。本节不出业务结论，只出结构事实、靴键等价自证、
--   与完整性诊断。行为层归 §P13，经济层归 §R01／§P11。一件一职，禁跨件挪用。
-- 改号：原名 §P13（桌级探针）与总包 §P13（会员入场行为层）一号双占，故改 §P14。
-- ▸ 导出：需要 —— 存为「数据库/P14_table_shoe_truth.csv」。

WITH
-- ▽▽▽▽▽ 共用口径层 TIER-A 起（三节逐字同文；改一处须三处同改，G-0 闸机检）▽▽▽▽▽
d_params AS (                                                                                   -- 公共表表达式：★参数单点声明层——全包一切阈值只此一处，禁他处再写字面
  SELECT 0.80  AS late_q,                                                                       -- 取值表达式：相对靴位判据阈值，产出「late_q」（口径锁之数值真身）
         100   AS min_orders,                                                                   -- 取值表达式：会员域活跃度门槛（注单数），产出「min_orders」
         10    AS conf_min_shoes                                                                -- 取值表达式：★分位类指标之置信靴数下限（只作旗标不作筛，候裁定）
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_agents_raw AS (                                                                               -- 公共表表达式：代理主档测试线**未去重**原样——供重复诊断，禁直接联结
  SELECT age001 AS agent_id                                                                     -- 取列：产出「agent_id」（原样，可能重复）
  FROM ods_mariadb_2b.ods_a168_agent                                                            -- 取数来源：代理主档
  WHERE age022 = '1'                                                                            -- 过滤条件：测试线旗标（铁律④b）
),                                                                                              -- 续行：收束上方的子查询或函数括号
test_agents AS (                                                                                -- 公共表表达式：★去重后之测试线名单——防扇出，唯一可用于联结者
  SELECT DISTINCT agent_id FROM d_agents_raw                                                    -- 取列：★DISTINCT——主档若重复，五路左连接会把一注扇成多行且 SQL 不报错
),                                                                                              -- 续行：收束上方的子查询或函数括号
ranked AS (                                                                                     -- 公共表表达式：同注单号取最新版本 ＋ 并列诊断（rk）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                     -- 取列：涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,                                  -- 续行：涉 bet03（靴号）、bet04（局号）、bet05（会员号）、bet11（汇率）、bet13、bet14
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                           -- 续行：五级代理线
         b.bet38, b.bet39, b.category,                                                          -- 续行：涉 bet38（测试标识）、bet39（桌号）、category（注单类别）
         ROW_NUMBER() OVER (                                                                    -- 行号窗口表达式：取每注单号之一行
           PARTITION BY b.bet01                                                                 -- 窗口分区：按注单号（★此键之唯一性系 OBSERVED，非 DDL 证据，见 d_dedup）
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn,                      -- 排序：三级降序；★三键全同者 rn 之取舍不定，故并出 rk 以量其规模
         RANK() OVER (                                                                          -- 排名窗口表达式：★并列检测——同分者同 rk
           PARTITION BY b.bet01                                                                 -- 窗口分区：同上分区，同上排序，方可与 rn 对照
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rk                       -- 排序：同上；rk = 1 之行数 > 1 即版本并列，重跑可漂移
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                          -- 取数来源：注单明细表（★表名开关）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                            -- 过滤条件：限定全局窗（半开区间；两端之靴被切尾，故下设 is_edge）
    AND b.bet02 = '101'                                                                         -- 并列条件：限定百家乐
),                                                                                              -- 续行：收束上方的子查询或函数括号
raw AS (                                                                                        -- 公共表表达式：★第一闸——只施**业务闸**，不施键闸；系一切诊断之分母
  SELECT r.bet01 AS bet_id, r.dt,                                                               -- 取列：产出「bet_id」并透传营业日
         TRIM(r.bet39) AS table_id,                                                             -- 取值表达式：★TRIM 防键分裂——不去空白则 '112' 与 ' 112' 裂为两桌
         TRIM(r.bet03) AS shoe_id,                                                              -- 取值表达式：★TRIM 防键分裂
         TRIM(r.bet04) AS round_raw,                                                            -- 取值表达式：★局号之**原样字面**——供类型异常分类（非数字／小数／科学记数）
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                           -- 取值表达式：去空白、空串归 NULL、显式转型，产出「round_no」（局号）
         CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,                          -- 取值表达式：同上转型规则，产出「member_id」（会员号）
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                 -- 取值表达式：同上转型规则，产出「fx」（汇率）
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                          -- 取值表达式：同上转型规则，产出「stake_raw」（原币下注额）
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw                          -- 取值表达式：同上转型规则，产出「payout_raw」（原币派彩额）
  FROM ranked r                                                                                 -- 取数来源：中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                             -- 左连接：一级线对测试名单（StarRocks 不支持 EXISTS 配多列 IN，故用五路左连接）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                             -- 左连接：二级线对测试名单
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                             -- 左连接：三级线对测试名单
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                             -- 左连接：四级线对测试名单
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                             -- 左连接：五级线对测试名单
  WHERE r.rn = 1                                                                                -- 过滤条件：只留一行（版本链去重）
    AND r.category = '1'                                                                        -- 并列条件：一般注单准入
    AND UPPER(TRIM(r.bet38)) = 'N'                                                              -- 并列条件：排除测试单
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL           -- 并列条件：五级任一命中测试线即剔
),                                                                                              -- 续行：收束上方的子查询或函数括号
gated_struct AS (                                                                               -- 公共表表达式：★第二闸——**结构键闸**。结构真相之母体，禁以经济闸收窄
  SELECT * FROM raw                                                                             -- 取列：承 raw 全列
  WHERE table_id <> '' AND shoe_id <> '' AND round_no > 0                                       -- 过滤条件：★三键闸——空键聚成幻影桌／幻影靴；非正局号亦剔
),                                                                                              -- 续行：收束上方的子查询或函数括号
win AS (                                                                                        -- 公共表表达式：窗界现取层——边界日由数据自证，不写死日期字面
  SELECT MIN(dt) AS dt_first, MAX(dt) AS dt_last FROM gated_struct                              -- 聚合表达式：产出「dt_first」「dt_last」（实见首末营业日，可能窄于名义窗）
),                                                                                              -- 续行：收束上方的子查询或函数括号
shoe AS (                                                                                       -- 公共表表达式：★结构真相层——(table_id, shoe_id) 双键为**全包唯一**之权威靴键
  SELECT g.table_id, g.shoe_id,                                                                 -- 取列：双键
         MAX(g.round_no)            AS shoe_len_obs,                                            -- 计数表达式：★观测靴长代理＝最大局号，**非局数**；真靴长待权威表 P0。全包唯一定义处
         MIN(g.round_no)            AS first_round_obs,                                         -- 聚合表达式：实见首局号（起始偏移 ＝ 其减一）
         COUNT(DISTINCT g.round_no) AS n_rounds_obs,                                            -- 计数表达式：★观测局数＝实见局号种数；一切**计数类**分母之正解
         COUNT(*)                   AS n_bets_ts,                                               -- 计数表达式：靴内注单行数（桌×靴粒度，故后缀 ts，禁与会员×靴之 n_bets_ms 同名）
         COUNT(DISTINCT g.bet_id)   AS n_bets_ts_distinct,                                      -- 计数表达式：靴内去重注单数
         COUNT(DISTINCT g.dt)       AS n_dt_shoe,                                               -- 计数表达式：★横跨营业日数——跨零点续接最多 2 日，≥3 必为靴号重用
         MAX(CASE WHEN g.dt = w.dt_first OR g.dt = w.dt_last                                    -- 条件分支：★边界靴旗标
                  THEN 1 ELSE 0 END) AS is_edge                                                 -- 续行：产出「is_edge」（1 ＝ 触窗界，其 shoe_len_obs 系下偏值）
  FROM gated_struct g CROSS JOIN win w                                                          -- 取数来源：结构闸后之母体叉乘窗界一行
  GROUP BY g.table_id, g.shoe_id                                                                -- 分组：按双键靴
),                                                                                              -- 续行：收束上方的子查询或函数括号
shoe1 AS (                                                                                      -- 公共表表达式：单键靴之同批对照——供靴键等价在带自证
  SELECT shoe_id, COUNT(DISTINCT table_id) AS n_tab_per_shoe                                    -- 计数表达式：每靴号所涉桌数；>1 即跨桌
  FROM gated_struct GROUP BY shoe_id                                                            -- 分组：按单键靴号
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- △△△△△ 共用口径层 TIER-A 止 △△△△△
,
tbl AS (                                                                                        -- 公共表表达式：桌级聚合——本节主体输出（§P14）
  SELECT table_id,                                                                              -- 取列：桌号为主键
         COUNT(*)                        AS n_shoes_table,                                      -- 计数表达式：该桌靴数（粒度后缀 table，禁裸名 n_shoes）
         SUM(n_bets_ts)                  AS n_bets_table,                                       -- 汇总表达式：★该桌注单行数。粒度后缀 table——禁与靴级 n_bets_ts 同名（同名异粒度）
         SUM(n_bets_ts_distinct)         AS n_bets_table_distinct,                              -- 汇总表达式：该桌去重注单数（同上后缀律）
         AVG(shoe_len_obs)               AS avg_shoe_len_obs,                                   -- 聚合表达式：★观测靴长均值（判级 OBSERVED·代理）
         PERCENTILE_APPROX(shoe_len_obs, 0.50) AS p50_shoe_len_obs,                             -- 取近似分位数表达式：靴长中位——桌族聚类之键
         PERCENTILE_APPROX(shoe_len_obs, 0.75) AS p75_shoe_len_obs,                             -- 取近似分位数表达式：靴长上四分位
         PERCENTILE_APPROX(shoe_len_obs, 0.90) AS p90_shoe_len_obs,                             -- 取近似分位数表达式：靴长第 90 百分位
         PERCENTILE_APPROX(shoe_len_obs, 0.99) AS p99_shoe_len_obs,                             -- 取近似分位数表达式：★小 n 桌之 P99 不可靠，消费须配 n_shoes_table 闸
         MIN(shoe_len_obs)               AS min_shoe_len_obs,                                   -- 聚合表达式：该桌最短靴（截断靴之线索）
         MAX(shoe_len_obs)               AS ceiling_observed,                                   -- 聚合表达式：★观测上限——与 P99 之比显著逾一即靴号重用或跨日合并嫌疑
         AVG(n_rounds_obs)               AS avg_n_rounds_obs,                                   -- 聚合表达式：观测局数均值
         SUM(n_rounds_obs)               AS sum_n_rounds_obs,                                   -- 汇总表达式：观测局数合计（正解密度之分母）
         SUM(shoe_len_obs)               AS sum_shoe_len_obs,                                   -- 汇总表达式：靴长合计（旧式密度之分母，血统对照）
         SUM(n_bets_ts) * 1.0 / NULLIF(SUM(shoe_len_obs),0)                                     -- 除法计算：★旧式密度——以最大局号充局数，留作与历史数字对照
                                         AS bets_per_maxround,                                  -- 续行：产出「bets_per_maxround」
         SUM(n_bets_ts) * 1.0 / NULLIF(SUM(n_rounds_obs),0)                                     -- 除法计算：★正解密度——分母为观测局数
                                         AS bets_per_obsround,                                  -- 续行：产出「bets_per_obsround」
         SUM(n_bets_ts) * 1.0 / NULLIF(COUNT(*),0)                                              -- 除法计算：★去耦密度——分母为靴数，与靴长作相关时无比率伪相关之患
                                         AS bets_per_shoe_table,                                -- 续行：产出「bets_per_shoe_table」
         SUM(n_rounds_obs) * 1.0 / NULLIF(SUM(shoe_len_obs),0)                                  -- 除法计算：★观测覆盖率（含起始偏移）
                                         AS round_coverage,                                     -- 续行：产出「round_coverage」（1.00 谓局号自 1 起连续无缺口）
         SUM(n_rounds_obs) * 1.0                                                                -- 除法计算：★内段覆盖率之分子
           / NULLIF(SUM(shoe_len_obs - first_round_obs + 1),0)                                  -- 续行：分母＝实见局号跨距合计
                                         AS interior_coverage,                                  -- 续行：产出「interior_coverage」（纯中段完整度）
         AVG(first_round_obs - 1)        AS avg_start_offset,                                   -- 聚合表达式：★起始偏移均值——由覆盖率中拆出独立成列
         AVG(shoe_len_obs - n_rounds_obs) AS avg_gap_total,                                     -- 聚合表达式：总缺口均值（含起始偏移，血统对照）
         AVG(shoe_len_obs - first_round_obs + 1 - n_rounds_obs)                                 -- 聚合表达式：★中段缺口均值——剔起始偏移之纯内段缺口
                                         AS avg_gap_interior,                                   -- 续行：产出「avg_gap_interior」
         SUM(CASE WHEN n_rounds_obs = 1 THEN 1 ELSE 0 END) AS n_shoes_1round,                   -- 汇总表达式：单局靴数（跨日边界／换荷官／开收台之截断）
         SUM(is_edge)                    AS n_shoes_edge,                                       -- 汇总表达式：触窗界之靴数
         SUM(is_edge) * 1.0 / NULLIF(COUNT(*),0) AS pct_shoes_edge,                             -- 除法计算：触窗界之靴占比
         MAX(n_dt_shoe)                  AS max_n_dt_shoe_table,                                -- 聚合表达式：★该桌之最大跨日数；≥3 即该桌存在靴号重用
         SUM(CASE WHEN n_dt_shoe >= 3 THEN 1 ELSE 0 END) AS n_shoes_dt_ge3_table,               -- 汇总表达式：★跨 ≥3 日之靴数（桌级）
         MAX(CASE WHEN n_dt_shoe = 1 THEN shoe_len_obs END) AS max_shoe_len_1dt,                -- 条件分支：★单日内最长靴——R 侧与该桌 P99 比对即判「单日超长靴」
         (AVG(shoe_len_obs * (n_bets_ts * 1.0 / NULLIF(shoe_len_obs,0)))                        -- 除法计算：结构性相关之协方差分子（旧式，Y 之分母即 X）
            - AVG(shoe_len_obs) * AVG(n_bets_ts * 1.0 / NULLIF(shoe_len_obs,0)))                -- 续行：减去均值之积
           / NULLIF(STDDEV_POP(shoe_len_obs)                                                    -- 除法计算：除以两总体标准差之积（与 AVG 同族矩）
                    * STDDEV_POP(n_bets_ts * 1.0 / NULLIF(shoe_len_obs,0)), 0)                  -- 续行：★判级 STRUCTURAL_CORRELATION——降为诊断，禁作主指标
                                         AS corr_len_dens_struct,                               -- 续行：产出「corr_len_dens_struct」
         (AVG(shoe_len_obs * n_bets_ts) - AVG(shoe_len_obs) * AVG(n_bets_ts))                   -- 除法计算：★去耦相关之协方差分子——两变量皆原始量
           / NULLIF(STDDEV_POP(shoe_len_obs) * STDDEV_POP(n_bets_ts), 0)                        -- 续行：★判级 OBSERVED_ASSOCIATION——相关不等于因果，禁述作「靴长影响下注量」
                                         AS corr_len_bets,                                      -- 续行：产出「corr_len_bets」（主用之桌内相关）
         (AVG(shoe_len_obs * n_rounds_obs)                                                      -- 除法计算：长度与覆盖度之相关，协方差分子
            - AVG(shoe_len_obs) * AVG(n_rounds_obs))                                            -- 续行：减去均值之积
           / NULLIF(STDDEV_POP(shoe_len_obs) * STDDEV_POP(n_rounds_obs), 0)                     -- 续行：★判级 OBSERVED_ASSOCIATION
                                         AS corr_len_rounds                                     -- 续行：产出「corr_len_rounds」
  FROM shoe                                                                                     -- 取数来源：结构真相层（TIER-A.shoe）
  GROUP BY table_id                                                                             -- 分组：按桌
),                                                                                              -- 续行：收束上方的子查询或函数括号
-- ▽▽▽▽▽ 诊断共用层 TIER-D 起（三节逐字同文；随行标量之来源）▽▽▽▽▽
d_agent AS (                                                                                    -- 公共表表达式：诊断·代理主档重复（治好数据不等于治好源头）
  SELECT (SELECT COUNT(*) FROM d_agents_raw)          AS n_test_agent_raw,                      -- 计数表达式：主档测试线原样行数
         (SELECT COUNT(*) FROM test_agents)           AS n_test_agent_distinct,                 -- 计数表达式：去重后名单行数
         (SELECT COUNT(*) FROM d_agents_raw)                                                    -- 减法计算：重复行数之分子
           - (SELECT COUNT(*) FROM test_agents)       AS duplicate_agent_id_count               -- 续行：★>0 即主档有重复，须另开上游工单（DISTINCT 只治症不治因）
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_dedup AS (                                                                                    -- 公共表表达式：诊断·去重完整与版本并列（升级建议 §十六／§十七）
  SELECT (SELECT COUNT(*) FROM ranked WHERE rn = 1)   AS n_rows_dedup,                          -- 计数表达式：去重后行数
         (SELECT COUNT(DISTINCT bet01) FROM ranked)   AS n_bet01,                               -- 计数表达式：注单号基数
         (SELECT COUNT(*) FROM ranked)                AS n_rows_ranked,                         -- 计数表达式：去重前行数
         (SELECT COUNT(*) FROM (                                                                -- 计数表达式：★版本并列之注单号数——
            SELECT bet01 FROM ranked WHERE rk = 1                                               -- 续行：rk = 1 者系并列首位之全部行
            GROUP BY bet01 HAVING COUNT(*) > 1) z)    AS dedup_tie_count                        -- 续行：同一注单号有二行以上并列首位 ⇒ rn 之取舍不定，重跑可漂移
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_type AS (                                                                                     -- 公共表表达式：诊断·局号类型异常分类（升级建议 §十八）
  SELECT COUNT(*)                                                     AS n_rows_raw,            -- 计数表达式：业务闸后、键闸前之行数（诊断之分母）
         COUNT(DISTINCT bet_id)                                       AS n_bets_distinct_raw,   -- 计数表达式：同上去重
         SUM(CASE WHEN table_id = '' THEN 1 ELSE 0 END)                AS n_null_table,         -- 汇总表达式：桌键空缺行数
         SUM(CASE WHEN shoe_id  = '' THEN 1 ELSE 0 END)                AS n_null_shoe,          -- 汇总表达式：靴键空缺行数
         SUM(CASE WHEN round_raw = '' THEN 1 ELSE 0 END)               AS n_round_empty,        -- 汇总表达式：局号空串行数
         SUM(CASE WHEN round_raw <> '' AND round_no IS NULL                                     -- 汇总表达式：★非空却转型失败者——即非数字字面
                  THEN 1 ELSE 0 END)                                  AS n_round_non_numeric,   -- 续行：CAST 于此静默变 NULL 而不报错，故非此列不可见
         SUM(CASE WHEN round_raw LIKE '%.%' THEN 1 ELSE 0 END)         AS n_round_fractional,   -- 汇总表达式：★含小数点者——CAST 可能截断而非失败，须单独计
         SUM(CASE WHEN round_no IS NOT NULL AND round_no <= 0                                   -- 汇总表达式：非正局号行数
                  THEN 1 ELSE 0 END)                                  AS n_round_le_zero,       -- 续行：产出「n_round_le_zero」
         SUM(CASE WHEN round_no > 0 THEN 1 ELSE 0 END)                 AS n_round_valid,        -- 汇总表达式：有效局号行数
         SUM(CASE WHEN member_id IS NULL OR member_id <= 0                                      -- 汇总表达式：会员号无效行数
                  THEN 1 ELSE 0 END)                                  AS n_member_invalid,      -- 续行：产出「n_member_invalid」
         SUM(CASE WHEN fx IS NULL OR fx <= 0 THEN 1 ELSE 0 END)        AS n_fx_invalid          -- 汇总表达式：汇率无效行数
  FROM raw                                                                                      -- 取数来源：★分母取未施键闸之 raw——若在同层顺手剔掉，被剔者即凭空消失，诊断永报零
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_key AS (                                                                                      -- 公共表表达式：诊断·靴键等价在带自证（升级建议 §四／§五）
  SELECT (SELECT COUNT(*) FROM shoe)                  AS n_shoes_2key,                          -- 计数表达式：双键靴数
         (SELECT COUNT(*) FROM shoe1)                 AS n_shoes_1key,                          -- 计数表达式：单键靴数
         (SELECT COUNT(*) FROM shoe)                                                            -- 减法计算：靴键等价之判据分子
           - (SELECT COUNT(*) FROM shoe1)             AS shoe_key_delta,                        -- 续行：★== 0 方可认单键与双键同粒度；换窗须重验，不外推
         (SELECT MAX(n_tab_per_shoe) FROM shoe1)      AS max_tables_per_shoe,                   -- 聚合表达式：★== 1 方可认无跨桌合并
         (SELECT SUM(CASE WHEN n_tab_per_shoe > 1 THEN 1 ELSE 0 END) * 1.0                      -- 除法计算：跨桌靴占比之分子
            / NULLIF(COUNT(*),0) FROM shoe1)          AS pct_cross_table,                       -- 续行：★== 0 方可认无跨桌合并
         (SELECT SUM(CASE WHEN n_dt_shoe >= 3 THEN 1 ELSE 0 END) FROM shoe)                     -- 汇总表达式：★跨 ≥3 营业日之靴数——靴号重用之直接计数
                                                      AS n_shoes_dt_ge3                         -- 续行：跨零点续接最多 2 日，故 ≥3 者必为重用；此闸补现有两项碰撞检验之盲区
),                                                                                              -- 续行：收束上方的子查询或函数括号
d_scope AS (                                                                                    -- 公共表表达式：诊断·反截断三量与母体规模（升级建议 §十八）
  SELECT (SELECT COUNT(DISTINCT table_id) FROM gated_struct) AS n_tables_total,                 -- 计数表达式：★反截断——总桌数随行到达
         (SELECT COUNT(*) FROM shoe)                         AS n_shoes_total,                  -- 计数表达式：★反截断——总靴数（可与总包 §R01-0b 全域不变量对账）
         (SELECT COUNT(*) FROM gated_struct)                 AS n_bets_total,                   -- 计数表达式：★反截断——结构闸后总注单行数
         (SELECT COUNT(DISTINCT member_id) FROM gated_member) AS n_members_clean                -- 计数表达式：会员闸后之会员基数（全量洁净域）
),                                                                                              -- 续行：收束上方的子查询或函数括号
diag AS (                                                                                       -- 公共表表达式：诊断标量合并为一行，供 CROSS JOIN 随行（前端截断只截行不截列）
  SELECT ag.*, dd.*, ty.*, ky.*, sc.*, w2.*,                                                    -- 取列：六组标量
         dd.n_rows_dedup * 1.0 / NULLIF(dd.n_bet01,0)  AS dedup_integrity_ratio,                -- 除法计算：★去重完整率——恒为 1.000000；>1 即扇出或版本链假设不成立
         dd.dedup_tie_count * 1.0 / NULLIF(dd.n_bet01,0) AS dedup_tie_rate                      -- 除法计算：★版本并列率——>0 即重跑可漂移（判级 OBSERVED，非 DDL 证据）
  FROM d_agent ag CROSS JOIN d_dedup dd CROSS JOIN d_type ty                                    -- 取数来源：诊断各组叉乘
       CROSS JOIN d_key ky CROSS JOIN d_scope sc CROSS JOIN win w2                              -- 续行：叉乘续
)                                                                                               -- 续行：收束上方的子查询或函数括号
-- △△△△△ 诊断共用层 TIER-D 止 △△△△△
SELECT t.*,                                                                                     -- 取列：桌级主体
  d.n_test_agent_raw,                                                                           -- 诊断·代理主档原样行数
  d.n_test_agent_distinct,                                                                      -- 诊断·去重后名单行数
  d.duplicate_agent_id_count,                                                                   -- 诊断·★>0 即主档重复，DISTINCT 只治症不治因
  d.n_rows_ranked,                                                                              -- 诊断·去重前行数
  d.n_rows_dedup,                                                                               -- 诊断·去重后行数
  d.n_bet01,                                                                                    -- 诊断·注单号基数
  d.dedup_integrity_ratio,                                                                      -- 诊断·★恒为 1.000000
  d.dedup_tie_count,                                                                            -- 诊断·★版本并列之注单号数；>0 即重跑可漂移
  d.dedup_tie_rate,                                                                             -- 诊断·版本并列率
  d.n_rows_raw,                                                                                 -- 诊断·业务闸后、键闸前行数（NULL 诊断之分母）
  d.n_bets_distinct_raw,                                                                        -- 诊断·同上去重
  d.n_null_table,                                                                               -- 诊断·桌键空缺
  d.n_null_shoe,                                                                                -- 诊断·靴键空缺
  d.n_round_empty,                                                                              -- 诊断·局号空串
  d.n_round_non_numeric,                                                                        -- 诊断·★局号非数字（CAST 静默变 NULL）
  d.n_round_fractional,                                                                         -- 诊断·★局号含小数点（CAST 可能截断）
  d.n_round_le_zero,                                                                            -- 诊断·局号非正
  d.n_round_valid,                                                                              -- 诊断·局号有效
  d.n_member_invalid,                                                                           -- 诊断·会员号无效
  d.n_fx_invalid,                                                                               -- 诊断·汇率无效
  d.n_shoes_2key,                                                                               -- 诊断·双键靴数
  d.n_shoes_1key,                                                                               -- 诊断·单键靴数
  d.shoe_key_delta,                                                                             -- 诊断·★靴键等价判据，== 0 方可用单键
  d.max_tables_per_shoe,                                                                        -- 诊断·★== 1 方可认无跨桌合并
  d.pct_cross_table,                                                                            -- 诊断·★== 0 方可认无跨桌合并
  d.n_shoes_dt_ge3,                                                                             -- 诊断·★跨 ≥3 日之靴数（靴号重用）
  d.n_tables_total,                                                                             -- 诊断·反截断·总桌数
  d.n_shoes_total,                                                                              -- 诊断·反截断·总靴数
  d.n_bets_total,                                                                               -- 诊断·反截断·总注单行数
  d.n_members_clean,                                                                            -- 诊断·全量洁净域会员数
  d.dt_first,                                                                                   -- 诊断·实见首营业日
  d.dt_last                                                                                     -- 诊断·实见末营业日
FROM tbl t CROSS JOIN diag d                                                                    -- 取数来源：桌级聚合叉乘诊断一行（每行皆携，前端截断亦不失）
ORDER BY CAST(t.table_id AS BIGINT), t.table_id                                                 -- 排序：★先数值序再字面序——纯字面序会把 '1','112','2','31' 排乱；非数字桌号落末尾
;

-- 【天花板｜本节解决不了什么】
--   shoe_len_obs ＝ MAX(round_no) 恒为观测代理，非真靴长。真靴长须副数与切牌位入册
--   （权威表 P0）方可定。故一切渗透率／牌深推算皆 INFERRED，禁升 OBSERVED。
--   「分母低估假说」由此拆二：H_rel（跨桌幅度不同）可由本节桌间比较检验；
--   H_abs（全域同向低估）**本节盲视**——跨桌比较对同向偏移天然无感，须待权威表 P0。
--   靴号重用之两条通道亦只堵一条：n_dt_shoe ≥ 3 可判「同桌隔日重号」；
--   「物理靴换而靴号未递增且局号接续编号」一条，只能以 max_shoe_len_1dt 取线索，
--   确证仍待权威表 P0。
