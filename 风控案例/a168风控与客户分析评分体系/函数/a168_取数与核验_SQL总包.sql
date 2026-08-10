/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  a168 风控与客户分层评分体系 · 商业方案                                      ║
   ║  取数与核验 SQL 总包（一册两卷 · 合并定稿）                                  ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  作者：Ryo（雷欧）                                                         ║
   ║  平台：a168 真人厅 · 数据源 StarRocks ods_mariadb_2b · 前端 Superset SQL Lab║
   ║  配套报告：a168风控与客户分层评分体系_商业方案_v3.qmd                         ║
   ║  本文件由「a168_核验与取数_SQL包.sql」与「a168_取数SQL包_v3增补.sql」         ║
   ║  合并而成，取代该二者；此后维护只认本文件一份。                               ║
   ╚═══════════════════════════════════════════════════════════════════════════╝

   ═══ 分析窗口（正名版，务必按此措辞对外）═══════════════════════════════════
     2026-03-21 ~ 2026-08-06 收盘，共 139 个完整营业日。
     SQL 谓词一律写作：dt >= '2026-03-21' AND dt < '2026-08-07'
     右端点为**开区间**——2026-08-07 当日不在窗口内。
     旧头部曾写「~ 2026-08-07」，字面易被读成含当日，已正名。
     改窗时须同时改动全包 53 处字面量，不得只改其一。

   ═══ 使用纪律（实测教训固化，逐条有血泪）═══════════════════════════════════
     ① 每条查询自包含、零占位符 —— 整段复制直接运行；
     ② StarRocks 方言：禁 LATERAL VIEW EXPLODE（改 UNNEST）、
        禁 EXISTS + 多列 IN（改五路 LEFT JOIN + COALESCE IS NULL）；
     ③ 逐条提交，禁批量 —— 批量会产生僵尸查询，拖垮集群；
     ④ 导出必带 ORDER BY —— 分页无稳定排序曾致 36.49% 重复行；
     ⑤ 导出上限 1,000 行时只承认排序头部结论，「未出现」类判断一律无效；
     ⑥ 超过 10 万行者先跑 COUNT 预检，按会员号区间切分，**不要用 OFFSET 翻页**；
     ⑦ 导出编码选 CSV(UTF-8)，全部存入报告同级「数据库/」目录，
        文件名一字不可错 —— 错名不报错，只让图表静默空白，是最坑的失败方式；
     ⑧ 每个 Superset 会话开跑前先逐条执行：
          SET SESSION query_timeout = 259200;   -- 与卷首先生设定一致（3 天）
          SET SESSION cbo_cte_reuse = true;   -- 报「变量不存在」则跳过
        第二条让被多次引用的 CTE 只计算一遍——本包 S-01（bs×4）、S-03（bs×3）、
        §R02 / §K01 等条依赖它；老版本无此开关时，列瘦身仍保证可接受耗时；
     ⑨ 连接前先估配对规模：凡两表连接键**不含局键或会员键**、仅靠桌号/日期
        这类低基数键相连的，必先各自聚合再连接——注单粒度×局粒度的裸连接
        曾使 S-02 三小时跑不完（万亿级配对），已以加权矩坍缩修复。

   ═══ 逐行注释体例（2026-08-10 增补 · 全篇一体）═══════════════════════════
     一、追加位置：一律置于该行**行尾**，起始列统一为第 100 列，以「-- 」引出；
         原有的整行注释与块注释一字未动，行尾原已带注释者不重复追加。
     二、格式定式：`-- 〈句法角色〉：〈业务用途〉`。冒号一律全角；
         句内不出现连续空白（原码中的对齐空格已归一），行末不留空白。
     三、句法角色取自固定词表共 37 种——取列、取数来源、过滤条件、分组、排序、
         左连接、连接键、条件分支、分支判定、窗口分区、公共表表达式、会话参数、
         分组后过滤、结果集合并、行数上限等；同一句法一律同一措辞，不作同义替换。
     四、业务用途以商务中文陈述，不用俚语、不用口语。字段与表名一律按卷首
         「字段正名速查」译出业务含义；阈值谓词译为中文，如
         `COUNT(DISTINCT round_key) >= 30` 注为「局键的去重个数不少于 30」。
     五、宁略勿错：无从确证者写「承接上一子句」（占 2.3%），绝不臆造业务含义。
         条目归属只认「▸ 导出」声明行为锚，块注释内的 § 引用不作锚——
         曾实测把 §C-08 的取数误标为 §PIT-01，已改正。
     六、**代码零改动**：注释追加后，剥离全部追加物所得之档与原件逐字节比对，
         MD5 同为 3b3bf93750b320fa0a082ef985c03b18。
     七、覆盖率：全档 3,144 行代码，注释覆盖 3,144 行，无一行遗漏。

   ═══ 注释书写铁律（本合并本已全数整改）═══════════════════════════════════
     块注释内**禁止出现连续星号紧邻斜杠**，亦禁止出现单个星号紧邻斜杠。
     两类已实证的踩雷：
       · 「(星号星号)数据库/xxx.csv(星号星号)」—— 卷一原有 24 处，已改为「数据库/xxx.csv」；
       · 「δ(星号)/γ(星号)」—— 卷二 §E02c 原有 1 处，注释在此提前终止，
         其后整段被当成 SQL 解析，与当初 E1-11 报 Unexpected input
         'R_rebate_dist' 属同一类失效。已改为「δ* 与 γ*」。
     今后新增注释一律遵此，希腊字母带星号的数学记号须用「与」「和」分隔。

   ═══ 已被取代的两条（正文保留供追溯，⛔ 请勿运行）═══════════════════════════
     ⛔ 卷一 C-06  → 改跑 卷二 §C06fix   （LIKE 判别失效，且争抢同一导出文件名）
     ⛔ 卷一 S-04a → 改跑 卷二 §S04p     （IP 明细 vs 实体级聚合，争抢同一文件名）
     两组各自同写一个 CSV，后跑者覆盖先跑者 —— 误跑将使对打对名单清空、
     风控员雷达退化为结构演示。各条正文上方已加醒目告示。

   ═══ 字段正名速查（以本包 SQL 实际用法为准）═══════════════════════════════
     bet03 靴号        bet04 局内第几把    bet05 会员号     bet08 下注时间
     bet09 玩法（英文玩法名：Banker / Player / Tie / BankerDragonBonus …）
     bet11 汇率（币种归一化除数：stake = bet13 / bet11）  ← 非赔率，词典须核正
     bet13 下注金额    bet14 派彩金额      bet15 会员退水%  bet16 退水
     bet17 净输赢      bet18~22 五级代理线  bet38 测试标识   bet39 桌号
     bet41 有效投注    eid 荷官工号
     bet23~27 LV1~5 占成   bet28~32 LV1~5 退水（量纲待 §E02c-0 探针判定）
     gi001~gi013 局信息（gi004 局开始 · gi006 开牌 · gi011 桌号）
     产品 = 供玩家投注的游戏种类（百家乐、龙虎等，见 §DX-05 产品全景）
     玩法 = 该产品下的投注方式（bet09 的 23 种取值，见 §DX-04）
     二者不可混用。

   ═══ 执行总索引 ═══════════════════════════════════════════════════════════
   【第〇批 · 时区与营业日守卫】新增，导任何日粒度表之前必跑，只看屏幕
     §TZ-01 会话与全局时区          §TZ-02 库时钟 vs UTC 偏移
     §TZ-03 注单表实际覆盖端点      §TZ-04 末三日逐小时量（截断检测）
     §TZ-04b 全窗逐小时分布（反推落库时区 —— 决定「日」的切点）
     §TZ-05 日结报表切日点核对      §PIT-01 修订滞后（快照有效性）

   【第一批 · 地基体检】卷一，只看屏幕，不导出
     00-0 通用取列工具    00-1 哨兵局断言（预期 0）    00-2 注单去重率（0.74%）
     00-3 铁律分母：窗口内下注会员数（721,190）        00-4 桌台数核对
     E1-03 三方 IP 重合度   E1-08 测试线规模（214）    V2 game_No 位数核验
     卷二 §00 COUNT 预检    §00b 辅助表列名核对        §00c 表行数复核
     §DX-01 bet09 玩法编码普查（★ 跑任何含对打的查询前必做）
     §DX-02 注释提前终止的成因存档                     §DX-03 通用取列定义

   【第二批 · 评分底料（必导，不导则雷达与回测全空）】
     S-01 → 数据库/S01_player_score.csv          玩家评分
     S-02 → 数据库/S02_dealer_score.csv          荷官评分
     S-03 → 数据库/S03_agent_score.csv           代理评分
     §S04p → 数据库/S04_analyst_score.csv        风控员评分（⛔ 勿用 S-04a）
     S-05 → 数据库/S05_member_month_panel.csv    净化滚动回测面板
     §B01 → 数据库/B01_bt_panel.csv              会员×日回测面板
     §B01-D → 数据库/B01_bt_panel_delta.csv      每日增量（影子期起）

   【第三批 · 异常 IP 与对打主线】
     A-01 → 数据库/A_anchor.csv                  L0 金标准 17 IP 锚点
     C-00 → 数据库/I_ip_player.csv               会员×IP 明细
     C-01 → 数据库/C01_ip_chain.csv              信用枢纽排序
     C-02 → 数据库/I_ip_agg.csv                  IP 汇总三版本口径
     §C06fix → 数据库/C06_hedge_pairs.csv        对打对名单（⛔ 勿用 C-06）
     C-08 → 数据库/C08_subnet_all.csv            /24 网段全量
     N1   → 数据库/C08_subnet_sparse.csv         稀疏段靶向
     V-01 → 数据库/V_ipmatch.csv                 三方 IP 明细对照

   【第四批 · 规则、经济学与特征】
     §R01 → 数据库/R01_late_shoe.csv             靴末段下注
     §R02 → 数据库/R02_same_table.csv            同桌对 Jaccard / Lift
     §R03 → 数据库/R03_player_dealer.csv         玩家×荷官（全窗聚合）
     §R03b → 数据库/R03b_player_dealer_daily.csv 玩家×荷官（日粒度，时序对照必需）
     §T02 → 数据库/T02_daily_roi.csv             会员×日 ROI
     §T03 → 数据库/T03_arbitrage.csv             打水型画像
     §E02c → 数据库/E02_segment_econ.csv         分群单位经济学（含占成 κ）
     §K01 → 数据库/K01_risk_feature_matrix.csv   扩样特征矩阵
     §K01b → 数据库/K01b_seed_manual.csv         种子名单
     §DX-04 → 数据库/DX04_bet09_profile.csv      玩法 × 会员子分类底料
     §DX-05 → 数据库/DX05_product_panorama.csv   产品全景覆盖度

   【第五批 · 存档与画像】
     A-06M → 数据库/V_recon.csv        D-05 → 数据库/S_second_dist.csv
     D-06  → 数据库/S_player_tail.csv  D-03S → 数据库/D03S_daily_roi_diff.csv
     E1-07 → 数据库/T_table_span.csv   E1-10 → 数据库/L_label_dist.csv
     E1-11 → 数据库/R_rebate_dist.csv  X-01  → 数据库/X_combo.csv
     P-01  → 数据库/P_player_month.csv B-01  → 数据库/B_online_base.csv

   ═══ 导出声明纪律（先生 2026-08-08 立 · 全包 75 条语句无一例外）═══════════
   ╔══════════════════════════════════════════════════════════════════════════╗
   ║  ★ 2026-08-09 精简与提速总则（本包自此只留可落实商业方案的最新版本）      ║
   ╠══════════════════════════════════════════════════════════════════════════╣
   ║  【一】旧版一律摘除，告示留存                                            ║
   ║    凡被取代、已跑完、纯模板、纯一次性诊断者，其 SQL 主体一律摘除，       ║
   ║    原处只留一行「⛔ 已摘除」告示并注明缘由与正版去处——                  ║
   ║    删主体是为杜绝误跑，留告示是为日后可追溯。共摘除 11 条：              ║
   ║      · §C-06 原版        → 正版 §C06fix（原版判庄闲用 '1'/'B'/'庄'，     ║
   ║                            与库内实际 Banker/Player 不符，实测零行）    ║
   ║      · S-04a            → 正版 §S04p（S-04a 出 IP 明细，雷达需实体级）  ║
   ║      · §E02 回退版      → 正版 §E02c（回退版占成恒 0，γ* 偏大）         ║
   ║      · §E02c-0 量纲探针 → 已内联进 §E02c 的自适应判据，无须人工先探     ║
   ║      · §00b 列名核对 ×4 → 列名已实测填实并写入各条注释                  ║
   ║      · §DX-01 bet09 普查→ 结论已校准入各条（等值匹配，不用 LIKE）       ║
   ║      · COUNT-05 一次性普查、COUNT-08b 翻页模板 → 无交付件产出           ║
   ║                                                                          ║
   ║  【二】提速总则（本包各条一律遵此，已逐条落实者见其条内注释）            ║
   ║    ① 分区裁剪优先：dt 谓词一律写在最内层 CTE，确保命中分区剪枝；        ║
   ║    ② 开窗去重只带必需列：ROW_NUMBER 去重的 CTE 一律显式列出下游用到的   ║
   ║       字段，绝不 SELECT b.*——四十余列 varchar(65533) 全过排序洗牌      ║
   ║       是本包最贵的一种写法（S-02 实测由此从三小时未毕降至可跑完）；     ║
   ║    ③ 聚合先于比较：MAX(GREATEST(五列)) 一律改写为 GREATEST(MAX(列)×5)， ║
   ║       等价而由「每行五元比较」降为「五次列聚合」；                      ║
   ║    ④ 矩坍缩替代多对多 JOIN：凡「注单粒度 × 局粒度」的配对，一律改以     ║
   ║       Σ权重、Σ加权值、Σ加权平方三矩等价求解（见 S-02 节奏稳定度）；     ║
   ║    ⑤ 字符串日期不绕道：SUBSTR(dt,1,7) 取月，不用                        ║
   ║       DATE_FORMAT(CAST(dt AS DATE),'%Y-%m')——dt 本即 'YYYY-MM-DD'；    ║
   ║    ⑥ 单值判据只扫三日：量纲、口径一类 schema 属性的判据，一律以三日窗   ║
   ║       取得后广播（CROSS JOIN 单行），不必扫全窗（见 §E02c probe）；     ║
   ║    ⑦ 中间投影层一律坍缩：纯做列改写的 CTE 并入其下游聚合，减少物化；    ║
   ║    ⑧ 分页一律 keyset，不用 OFFSET（曾因 OFFSET 致 36.49% 重复率）。     ║
   ║                                                                          ║
   ║  【三】固有成本，非提速空间（据实说明，不作虚言）                        ║
   ║    「同注单号取最新版本」的 ROW_NUMBER 去重，是需求 §3.2 的硬性口径，    ║
   ║    每条正版查询都须对全窗注单开窗一次。库为只读、不得建中间表，         ║
   ║    故此项开销无法在 SQL 层消除；如需进一步提速，只能在服务器侧          ║
   ║    （DolphinScheduler + Spark）落一张去重后的中间表，供各条复用。       ║
   ╚══════════════════════════════════════════════════════════════════════════╝

     每一条语句的 SQL 正文之前，都有一行以「▸ 导出：」开头的声明，二选一：
       · 「▸ 导出：需要 —— 存为「数据库/xxx.csv」」  → 交付件，报告会读取它
       · 「▸ 导出：不需要 —— …」                    → 屏幕/诊断/守卫/模板类
     配套三条：
       ① 一份文件名**只允许一条活跃语句**产出。已停用的查询必须**撤除**其导出
          声明——否则照头运行即覆盖正版输出（S-04a 覆盖 §S04p 的旧事即此）。
       ② 标注「不需要」的查询，注释内不得出现任何导出文件名；需指代某份交付件
          时只写查询编号。读者只会看见文件名与查询相邻，不会读完整段上下文。
       ③ 全包现状：需导出 40 条 · 无需导出 35 条 · 文件名写盘冲突 0。
   ═══════════════════════════════════════════════════════════════════════════

   【第六批 · 时间一致性与切分工具】
     §TG-01 注册时间穿越检测   §TG-03 关注 IP 登记时间越界   §TG-05 事实表越界自检
     §99 大表切分导出模板      COUNT-01/02/08a/08b/09 计数与分批
   ═══════════════════════════════════════════════════════════════════════════ */

/* 顺便提醒一句：max_execution_time 在 MariaDB 和 MySQL 5.7+ 中生效，但它只针对 
   SELECT 语句生效，对 INSERT/UPDATE/DELETE 等写操作无效。如果你的后续 CTE 查询超过 
   15 分钟，这个设置会主动杀掉该查询，防止拖垮数据库。  */
-- ▸ 导出：不需要 —— 会话参数设置，无结果集。每个 Superset 会话开跑前先执行一次。
SET SESSION query_timeout = 259200;                                                                 -- 会话参数：会话查询超时上限（秒）——本包多条为重查询，须先行放宽
-- SET max_execution_time = 259200000;   -- 259200秒 = 259200000毫秒

-- ★ 决定性的一条：允许大聚合/大连接溢写磁盘，而不是撞上限即崩。
--   StarRocks 3.x 支持；若报变量不存在则跳过，主改写本身已大幅降内存。
SET enable_spill = true;                                                                            -- 会话参数：允许落盘溢出——大表聚合内存不足时改走磁盘，免中途失败
SET spill_mode = 'auto';                                                                            -- 会话参数：溢出策略

-- ★★ 2026-08-09 提速追加（会话级，一次生效于本包全部语句；报变量不存在即跳过该行）
--   本包多条正版查询存在「同一 CTE 被下游引用三次以上」的形状
--   （S-01 的 bs、S-02 的 bd、S-03 的 bs、§R02 的 act 与 mr2）。
--   StarRocks 的 CTE 默认 inline 展开，被引用 N 次即重算 N 次。
--   逐条改写为临时聚合需实测验证等价性，风险高于收益；
--   改以**会话级 CTE 复用**收之：命中复用后，被多次引用的 CTE 只算一次，
--   语义完全不变，零改写风险。
SET cbo_cte_reuse = true;                                                                           -- 会话参数：公共表表达式复用开关——令被多次引用的 CTE 只算一遍
--   复用判定的代价阈值：值越小越倾向复用。默认 1.15，此处放宽以覆盖上述形状。
SET cbo_cte_reuse_rate = 1.0;                                                                       -- 会话参数：公共表表达式复用触发率
--   流水线执行引擎：多核并行，对本包的大聚合与开窗去重收益最直接。
SET enable_pipeline_engine = true;                                                                  -- 会话参数：流水线执行引擎开关
--   并行度：设为 0 表示由引擎按 BE 核数自适应（优于固定值）。
SET pipeline_dop = 0;                                                                               -- 会话参数：并行度；设 0 即由引擎按 BE 核数自适应，优于固定值
--   全局运行时过滤器：JOIN 探测端提前裁剪，对本包大量 LEFT JOIN 测试线代理有效。
SET enable_global_runtime_filter = true;                                                            -- 会话参数：全局运行时过滤器——连接探测端提前裁剪

/* ═══════════════════════════════════════════════════════════════════════════
   §TZ · 时区与营业日守卫（第〇批 · 新增）
   ---------------------------------------------------------------------------
   为什么必须先跑：本方案所有「日」粒度口径 —— 回测面板的 bet_date、
   走势图的 X 轴日期、会员出勤天数、日 ROI —— 都建立在「一天从几点算起」
   这个前提上。赌场的营业日常不以午夜切分（通宵客的注单会计入前一营业日），
   若误用自然日，跨日客户的行为会被人为劈成两天，评分与回测双双失真。
   本组六条只返回个位数到两位数行，**看屏幕即可，全部不必导出**。
   ═══════════════════════════════════════════════════════════════════════════ */

/* ── §TZ-01 · 会话与全局时区 ────────────────────────────────────────────────
   注意：不要用 SHOW VARIABLES —— Superset 会给查询自动追加 LIMIT，
   而 SHOW 语句不接受 LIMIT，会报「Unexpected input 'LIMIT'」。改用下式。 */
-- ▸ 导出：不需要 —— §TZ-01 屏幕核对（会话/全局时区）。
SELECT @@time_zone AS session_tz, @@global.time_zone AS global_tz;                                  -- 取列：产出「global_tz」

/* ── §TZ-02 · 库时钟 vs UTC，实测偏移（分钟）──────────────────────────────
   判读：offset_min = 0 → 会话时区为 UTC；= 480 → UTC+8。
   实测（2026-08-07）：offset_min = 0，库时钟即 UTC。 */
-- ▸ 导出：不需要 —— §TZ-02 屏幕核对（库时钟 vs UTC 偏移分钟）。
SELECT NOW() AS db_now, UTC_TIMESTAMP() AS utc_now,                                                 -- 取列：起始取列子句，本行先取「utc_now」
       TIMESTAMPDIFF(MINUTE, UTC_TIMESTAMP(), NOW()) AS offset_min;                                 -- 取值表达式：产出「offset_min」

/* ── §TZ-03 · 注单表实际覆盖端点 ─────────────────────────────────────────
   bet08 为下注时间，库中以字符串存放，须 CAST 后比较。 */
-- ▸ 导出：不需要 —— §TZ-03 屏幕核对（注单表实际覆盖端点）。
SELECT MIN(dt) AS dt_min, MAX(dt) AS dt_max,                                                        -- 取列：起始取列子句，本行先取「dt_max」，涉 dt（营业日）
       MIN(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS t_bet_min,                                  -- 取最小值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet_min」
       MAX(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS t_bet_max,                                  -- 取最大值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet_max」
       COUNT(*) AS n_rows                                                                           -- 计数表达式：产出「n_rows」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE bet02 = '101';                                                                                -- 过滤条件：限定 bet02等于 '101'，涉 bet02（游戏类别）

/* ── §TZ-04 · 末三日逐小时注单量（截断检测）───────────────────────────────
   判读：完整营业日应有 24 个小时槽且呈稳定日内曲线。
   若末日只出现前若干小时或尾部量级断崖，即为截断日，须排除出窗口。
   本包窗口右端点已为开区间 < '2026-08-07'，08-07 本就不在窗内；
   本条用于换窗时复核新右端点。 */
-- ▸ 导出：不需要 —— §TZ-04 屏幕核对（末三日逐小时量·截断检测）。
SELECT DATE(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS d,                                         -- 取列：起始取列子句，本行先取「d」，涉 bet08（下注时间）
       HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS h,                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「h」
       COUNT(*) AS n_orders                                                                         -- 计数表达式：产出「n_orders」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07' AND bet02 = '101'                                    -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
GROUP BY DATE(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)),                                            -- 分组：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
         HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME))                                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
ORDER BY d, h;                                                                                      -- 排序：按 d, h 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

/* ── §TZ-04b · 全窗逐小时分布（反推落库时区）★ 关键一条 ─────────────────
   会话时区为 UTC，不等于「数据以 UTC 落库」。用业务节律反推：
   真人厅高峰通常在当地 21:00~01:00。
     · 若峰值落在 UTC 13:00~17:00 → 对应 UTC+8 的 21:00~01:00
       → 落库为 UTC+8 墙钟，报告的「日」应按 UTC+8 自然日理解；
     · 若峰值落在 UTC 21:00~01:00 → 落库确为 UTC。
   结论须写入报告的数据说明章（属业务口径，非日志）。 */
-- ▸ 导出：不需要 —— §TZ-04b 屏幕核对（全窗逐小时分布·反推落库时区）。
SELECT HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS h_of_day,                                  -- 取列：起始取列子句，本行先取「h_of_day」，涉 bet08（下注时间）
       COUNT(*) AS n_orders,                                                                        -- 计数表达式：产出「n_orders」
       COUNT(DISTINCT bet05) AS n_member,                                                           -- 计数表达式：统计唯一会员数（铁律分母，全窗 721,190 人），产出「n_member」
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct                                                -- 计数表达式：全局窗口，用作占比之分母，产出「pct」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'                                    -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
GROUP BY HOUR(CAST(NULLIF(TRIM(bet08),'') AS DATETIME))                                             -- 分组：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
ORDER BY h_of_day;                                                                                  -- 排序：按 h_of_day 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

/* ── §TZ-05 · 日结报表切日点核对 ─────────────────────────────────────────
   原 T-05 用 report_date 报「Column cannot be resolved」——
   辅助表不用通用列名，日期列为分区列 dt（与 §00b 记录的教训同源）。
   判读：本条的日行数分布若与 §TZ-04 的自然日分布对不上，
   即说明日结按营业日切分，全案「日」粒度须统一改用营业日。 */
-- ▸ 导出：不需要 —— §TZ-05 屏幕核对（日结报表切日点）。
SELECT dt AS 日期, COUNT(*) AS 行数, COUNT(DISTINCT bet05) AS 会员数                                       -- 取列：统计唯一会员数（铁律分母，全窗 721,190 人），产出「会员数」
FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                     -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
WHERE dt >= '2026-08-01' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-01'、dt小于 '2026-08-07'，涉 dt（营业日）
GROUP BY dt                                                                                         -- 分组：按 dt 汇总
ORDER BY dt;                                                                                        -- 排序：按 dt 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ── §PIT-01 · 修订滞后分布（快照有效性守卫，第〇批）─────────────────────
   ▸ 导出：不需要 —— 屏幕看结果即可（4 行）
   ▸ 用途：回答「整窗静态快照的回测是否等于偷看未来修订」。
     updatetime 落后 bet08 的分布若 >7 天档占比可忽略，
     则 7 天禁运的 purged WF 用静态快照与逐日下载**信息集等价**。
   ▸ 实测（2026-08-08）：<1h 99.99359% · 1~24h 0.0049% ·
     1~7天 0.00063% · >7天 1,115 笔 0.00089% —— 裁定成立，
     已写入报告 @sec-pit 作回测有效性依据；总行数实测 125,654,711。 */
SELECT CASE                                                                                         -- 条件分支：开启分支判定，其后逐行列出条件与取值
         WHEN lag_h <  1  THEN '<1h'   WHEN lag_h < 24 THEN '1~24h'                                 -- 分支判定：承接上一子句，构成完整语句
         WHEN lag_h < 168 THEN '1~7天' ELSE '>7天（唯一需要担心的一档）' END AS 修订滞后,                            -- 分支判定：产出「修订滞后」
       COUNT(*) AS n, COUNT(*)*1.0/SUM(COUNT(*)) OVER() AS pct                                      -- 计数表达式：全局窗口，用作占比之分母，产出「pct」
FROM (SELECT TIMESTAMPDIFF(HOUR,                                                                    -- 取数来源：以内联子查询为来源，先在括号内算出中间结果，再供外层取用
               CAST(NULLIF(TRIM(bet08),'') AS DATETIME),                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
               CAST(NULLIF(TRIM(updatetime),'') AS DATETIME)) AS lag_h                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「lag_h」
      FROM ods_mariadb_2b.ods_a168_bet02                                                            -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
      WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101') t                             -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101') t，涉 bet02（游戏类别）、dt（营业日）
GROUP BY 1 ORDER BY MIN(lag_h);                                                                     -- 分组：按 1 ORDER BY MIN(lag_h) 汇总


/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  卷一 · 核验与全局底料                                                     ║
   ║  原「a168_核验与取数_SQL包.sql」全量正典（2026-08-06 定稿）收编            ║
   ║  SQL 逻辑一字未改；仅整改注释隐患 24 处，并为 C-06 / S-04a 加取代告示。     ║
   ╚═══════════════════════════════════════════════════════════════════════════╝ */

/* ═══════════════════════════════════════════════════════════════════════
   00-0 · 通用取列工具（遇到 "Column X cannot be resolved" 先跑这条）
   ▸ 导出：不需要 —— 屏幕看结果即可
   ▸ 用途：只读元数据，秒级返回，不扫任何数据行
   ▸ 用法：把表名换成报错的那张表即可；可一次查多张（IN 列表）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT TABLE_NAME AS 表名, ORDINAL_POSITION AS 序号, COLUMN_NAME AS 字段名,                                -- 取列：起始取列子句，本行先取「字段名」
       DATA_TYPE AS 类型, COLUMN_COMMENT AS 中文注释                                                      -- 取值表达式：产出「中文注释」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
  AND TABLE_NAME IN ('ods_a168_alert_ip_setting','ods_a168_member_dtl',                             -- 并列条件：限定落入所列取值，涉会员主档明细（注册与账户属性）
                     'ods_a168_white_list','ods_a168_employee')                                     -- 字面取值：取用员工主档（荷官工号与在职状态）
ORDER BY TABLE_NAME, ORDINAL_POSITION;                                                              -- 排序：按 TABLE_NAME, ORDINAL_POSITION 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* 说明：ODS 层字段名多为 mem003/age022 这类代号，中文注释栏是唯一线索。
   本 SQL 包中标 ⚠️ 的表，其列名均来自局部样本判读，正式使用前应先跑本条确认。 */

/* ═══════════════════════════════════════════════════════════════════════
   00-1 · 哨兵局断言（预期 0；非 0 须重评口径）
   E1 已证为 0，此为字面量复核版
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(*) AS n_sentinel FROM ods_mariadb_2b.ods_a168_bet02                                    -- 取列：计数，取用注单明细表（金额与行为口径的第一料源），产出「n_sentinel」
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101' AND bet03='0';                       -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'、bet03等于 '0'，涉 bet02（游戏类别）、bet03（靴号）、dt（营业日）


/* ═══════════════════════════════════════════════════════════════════════
   00-2 · 注单去重率（E1 实测 0.74%）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(*) AS n_raw, COUNT(DISTINCT bet01) AS n_dedup,                                         -- 取列：起始取列子句，本行先取「n_dedup」
       1 - COUNT(DISTINCT bet01)*1.0/COUNT(*) AS dup_rate                                           -- 取值表达式：统计去重个数，产出「dup_rate」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101';                                     -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）


/* ═══════════════════════════════════════════════════════════════════════
   00-3 · 铁律⑤分母：窗口内百家乐有效下注会员数（E1 实测 721,190）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT COUNT(DISTINCT member_id) AS n_member_denominator FROM bs;                                   -- 取列：统计去重个数，产出「n_member_denominator」


/* ═══════════════════════════════════════════════════════════════════════
   00-4 · N2 · 桌台数核对（本批 30 vs V2 报告 31 的闭合）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(DISTINCT bet39) AS n_tables FROM ods_mariadb_2b.ods_a168_bet02                         -- 取列：统计去重个数，产出「n_tables」
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101';                                     -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）


/* ═══════════════════════════════════════════════════════════════════════
   E1-03 · 三方 IP 重合度（裁定：game_log.ip 为网关，禁作下注 IP）
   E1 实测：1.32M vs 1,668，重合仅 2
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
WITH a AS (SELECT DISTINCT ip FROM ods_mariadb_2b.ods_a168_bet02                                    -- 公共表表达式：取用注单明细表（金额与行为口径的第一料源）
           WHERE dt>='2026-03-21' AND dt<'2026-08-07' AND bet02='101'                               -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
             AND NULLIF(TRIM(ip),'') IS NOT NULL),                                                  -- 并列条件：限定该值非空
     b AS (SELECT DISTINCT ip FROM ods_mariadb_2b.ods_a168_game_log                                 -- 取值表达式：取用局流水日志（局级过程记录）
           WHERE dt>='2026-03-21' AND dt<'2026-08-07'                                               -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
             AND NULLIF(TRIM(ip),'') IS NOT NULL)                                                   -- 并列条件：限定该值非空
SELECT (SELECT COUNT(*) FROM a) AS n_bet_ip,                                                        -- 取列：起始取列子句，本行先取「n_bet_ip」
       (SELECT COUNT(*) FROM b) AS n_log_ip,                                                        -- 续行：计数，产出「n_log_ip」
       (SELECT COUNT(*) FROM a JOIN b ON a.ip=b.ip) AS n_overlap;                                   -- 续行：计数，产出「n_overlap」


/* ═══════════════════════════════════════════════════════════════════════
   E1-07 · 局时长按桌分位（尾注阈值分层依据；桌内SD≈5s、桌间SD=18.2s）
   
   ▸ 导出：「数据库/T_table_span.csv」
   ▸ 用途：报告 fetch("T_table_span")：桌台局时长分层
   ═══════════════════════════════════════════════════════════════════════ */
SELECT gi011 AS table_id, COUNT(*) AS n_rounds,                                                     -- 取列：起始取列子句，本行先取「n_rounds」，涉 gi011（桌号）
       AVG(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004))  AS mean_sec,                               -- 求均值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「mean_sec」
       PERCENTILE_APPROX(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004),0.5) AS p50,                   -- 取近似分位数表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「p50」
       PERCENTILE_APPROX(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004),0.9) AS p90,                   -- 取近似分位数表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「p90」
       PERCENTILE_APPROX(UNIX_TIMESTAMP(gi006)-UNIX_TIMESTAMP(gi004),0.99) AS p99                   -- 取近似分位数表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「p99」
FROM ods_mariadb_2b.ods_a168_game_info                                                              -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
WHERE gi001='101' AND gi013='1' AND is_lock='N'                                                     -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'、is_lock等于 'N'，涉 gi001（局主键）
  AND gi004>='2026-03-21' AND gi004<'2026-08-07'                                                    -- 并列条件：限定 gi004不少于 '2026-03-21'、gi004小于 '2026-08-07'，涉 gi004（局开始时刻）
GROUP BY gi011 ORDER BY n_rounds DESC;                                                              -- 分组：按 gi011 ORDER BY n_rounds（降序）汇总


/* ═══════════════════════════════════════════════════════════════════════
   E1-08 · 测试线规模（E1 实测 214 代理，跨五级）
   
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT COUNT(*) AS n_test_agents FROM ods_mariadb_2b.ods_a168_agent WHERE age022='1';               -- 取列：计数，取用代理主档（五级代理线归属来源），产出「n_test_agents」


/* ═══════════════════════════════════════════════════════════════════════
   E1-10 · 風險單/劃單全局分布（标签可用性）
   
   ▸ 导出：「数据库/L_label_dist.csv」
   ▸ 用途：風險單/劃單标签分布，标签可用性存档
   ═══════════════════════════════════════════════════════════════════════ */
SELECT risk, orders, COUNT(*) AS n_rows,                                                            -- 取列：起始取列子句，本行先取「n_rows」
       COUNT(DISTINCT bet05) AS n_member,                                                           -- 计数表达式：统计唯一会员数（铁律分母，全窗 721,190 人），产出「n_member」
       MIN(dt) AS first_dt, MAX(dt) AS last_dt                                                      -- 取最小值表达式：取最大值，取用 dt（营业日），产出「last_dt」
FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                     -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
GROUP BY risk, orders ORDER BY n_rows DESC;                                                         -- 分组：按 risk, orders ORDER BY n_rows（降序）汇总


/* ═══════════════════════════════════════════════════════════════════════
   E1-11 · 会员退水配置分布（0.3/0.8/0.9% 档人群——洗码经济学输入）
   
   ▸ 导出：「数据库/R_rebate_dist.csv」
   ▸ 用途：退水档位人群分布，洗码经济学输入
   ═══════════════════════════════════════════════════════════════════════ */
/* ✅ mem003 已经 §DX-03 实测确认（2026-08-08）：COLUMN_COMMENT = 「退水」，
   源类型 decimal(16,2) —— 本条可直接运行，导出即为正版 R_rebate_dist.csv。
   同批确认的备用能力：mem016=電投退水、mem002=類別、mem012/mem014=可贏/可輸限額。 */

SELECT mem003 AS rebate_rate, COUNT(*) AS n_member,                                                 -- 取列：起始取列子句，本行先取「n_member」，涉 mem003（会员编号）、n_member（会员数）
       COUNT(*)*1.0/SUM(COUNT(*)) OVER() AS pct                                                     -- 计数表达式：全局窗口，用作占比之分母，产出「pct」
FROM ods_mariadb_2b.ods_a168_member_dtl                                                             -- 取数来源：取自会员主档明细（注册与账户属性）
GROUP BY mem003 ORDER BY n_member DESC;                                                             -- 分组：按 mem003 ORDER BY n_member（降序）汇总


/* ═══════════════════════════════════════════════════════════════════════
   A-06M · 局级对账 · MASE 评估（实测跑通原文收编）
   MASE<<1 → 去重与口径正确；已确认 gi005 为归一化口径
   ▸ 导出：「数据库/V_recon.csv」
   ▸ 用途：报告 fetch("V_recon")：局级对账 MASE
   ═══════════════════════════════════════════════════════════════════════ */
/* --- A-06M 局级对账 · MASE 评估（已确认 gi005 为归一化口径）---------
   MASE = MAE / scale，scale = 同桌相邻局 gi_turnover 的平均绝对差分
   （Hyndman & Koehler 2006 的 naive one-step 基准）
   MASE << 1 → 对账误差远小于「用上一局预测本局」的朴素基准 → 口径一致
   ------------------------------------------------------------------------- */
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体（交付件 V_recon.csv）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 V_recon.csv）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（交付件 V_recon.csv）
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet16, b.bet17,                    -- 取列：起始取列子句，本行先列 b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet16, b.bet17，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet38, b.bet39, b.category,                                                              -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category，涉 bet38（测试标识）、bet39（桌号）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 V_recon.csv）
br AS (                                                                                             -- 公共表表达式：开启中间结果集 br，其后各行为其定义体（交付件 V_recon.csv）
  SELECT r.bet03 AS sh, r.bet04 AS rd, r.bet39 AS tb,                                               -- 取列：起始取列子句，本行先取「tb」，涉 bet03（靴号）、bet04（局内序号）、bet39（桌号）
    SUM(CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))                                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS turnover,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「turnover」
    SUM(CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))                                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS rebate,                               -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
    SUM(CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4))                                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
        / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS net_pnl                               -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
  GROUP BY r.bet03, r.bet04, r.bet39                                                                -- 分组：按 r.bet03, r.bet04, r.bet39 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 V_recon.csv）
gi AS (                                                                                             -- 公共表表达式：开启中间结果集 gi，其后各行为其定义体（交付件 V_recon.csv）
  SELECT gi002 AS sh, gi003 AS rd, gi011 AS tb,                                                     -- 取列：起始取列子句，本行先取「tb」，涉 gi011（桌号）
         CAST(NULLIF(TRIM(gi004),'') AS DATETIME)     AS t_open,                                    -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_open」
         CAST(NULLIF(TRIM(gi005),'') AS DECIMAL(20,4)) AS gi_turnover,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「gi_turnover」
         CAST(NULLIF(TRIM(gi009),'') AS DECIMAL(20,4)) AS gi_rebate,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「gi_rebate」
         CAST(NULLIF(TRIM(gi010),'') AS DECIMAL(20,4)) AS gi_net                                    -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「gi_net」
  FROM ods_mariadb_2b.ods_a168_game_info                                                            -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND gi001 = '101'                                  -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、gi001等于 '101'，涉 dt（营业日）、gi001（局主键）
    AND gi013 = '1' AND is_lock = 'N'                                                               -- 并列条件：限定 gi013等于 '1'、is_lock等于 'N'
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 V_recon.csv）
j AS (                                                                                              -- 公共表表达式：开启中间结果集 j，其后各行为其定义体（交付件 V_recon.csv）
  SELECT g.tb, g.t_open,                                                                            -- 取列：起始取列子句，本行先列 g.tb, g.t_open
         ABS(b.turnover - g.gi_turnover) AS ae_turnover,                                            -- 取值表达式：取用 turnover（洗码量），产出「ae_turnover」
         ABS(b.rebate   - g.gi_rebate)   AS ae_rebate,                                              -- 取值表达式：取用 rebate（退水），产出「ae_rebate」
         ABS(b.net_pnl  - g.gi_net)      AS ae_net,                                                 -- 取值表达式：取用 net_pnl（会员净输赢），产出「ae_net」
         g.gi_turnover, g.gi_rebate, g.gi_net,                                                      -- 续行：接续上一取列子句，续列 g.gi_turnover, g.gi_rebate, g.gi_net
         LAG(g.gi_turnover) OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_turnover,             -- 取前一行表达式：产出「lag_turnover」
         LAG(g.gi_rebate)   OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_rebate,               -- 取前一行表达式：产出「lag_rebate」
         LAG(g.gi_net)      OVER (PARTITION BY g.tb ORDER BY g.t_open) AS lag_net                   -- 取前一行表达式：产出「lag_net」
  FROM br b                                                                                         -- 取数来源：取自本条自建的中间结果集 br
  JOIN gi g ON b.sh = g.sh AND b.rd = g.rd AND b.tb = g.tb                                          -- 连接：取自本条自建的中间结果集 gi，连接键为 b.sh = g.sh AND b.rd = g.rd AND b.tb = g.tb
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 V_recon.csv）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                            AS n_matched_round,                           -- 计数表达式：产出「n_matched_round」
  AVG(ae_turnover)                                    AS mae_turnover,                              -- 求均值表达式：产出「mae_turnover」
  AVG(ae_rebate)                                      AS mae_rebate,                                -- 求均值表达式：产出「mae_rebate」
  AVG(ae_net)                                         AS mae_net,                                   -- 求均值表达式：产出「mae_net」
  AVG(ABS(gi_turnover - lag_turnover))                AS scale_turnover,                            -- 求均值表达式：产出「scale_turnover」
  AVG(ABS(gi_rebate   - lag_rebate))                  AS scale_rebate,                              -- 求均值表达式：产出「scale_rebate」
  AVG(ABS(gi_net      - lag_net))                     AS scale_net,                                 -- 求均值表达式：产出「scale_net」
  AVG(ae_turnover) / NULLIF(AVG(ABS(gi_turnover - lag_turnover)), 0) AS mase_turnover,              -- 求均值表达式：产出「mase_turnover」
  AVG(ae_rebate)   / NULLIF(AVG(ABS(gi_rebate   - lag_rebate)),   0) AS mase_rebate,                -- 求均值表达式：产出「mase_rebate」
  AVG(ae_net)      / NULLIF(AVG(ABS(gi_net      - lag_net)),      0) AS mase_net,                   -- 求均值表达式：产出「mase_net」
  SUM(CASE WHEN ae_turnover <= 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_exact_turnover,      -- 汇总表达式：计数，产出「pct_exact_turnover」
  SUM(CASE WHEN ae_net      <= 0.01 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS pct_exact_net            -- 汇总表达式：计数，产出「pct_exact_net」
FROM j                                                                                              -- 取数来源：取自本条自建的中间结果集 j
WHERE lag_turnover IS NOT NULL;                                                                     -- 过滤条件：限定该值非空
/* 判读：
     mase_* < 0.05  → 对账误差不足朴素基准的 5%，口径完全一致
     mase_* ≈ 1     → 误差与局间自然波动同量级，口径存疑
     pct_exact_*    → 完全一致（容差 0.01）的局占比，直观补充指标         */


/* ═══════════════════════════════════════════════════════════════════════
   C-00 · 会员×IP 明细（评分与 §4.1 六项指标的底料）
   最小订单 30（Wilson 准则）控制导出量
   ▸ 导出：「数据库/I_ip_player.csv」
   ▸ 用途：报告 fetch("I_ip_player")：会员×IP 明细（§4.1 六项）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
pl AS (SELECT member_id, COUNT(*) AS n_orders_all,                                                  -- 取值表达式：计数，取用 member_id（会员号），产出「n_orders_all」
              COUNT(DISTINCT round_key) AS n_rounds_all,                                            -- 计数表达式：统计去重个数，产出「n_rounds_all」
              SUM(net_pnl) AS net_pnl_all, SUM(game_pnl) AS game_pnl_all                            -- 汇总表达式：取用 net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「game_pnl_all」
       FROM bs GROUP BY member_id)                                                                  -- 取数来源：取自本条自建的中间结果集 bs
SELECT b.bet_ip, b.member_id, MAX(b.lv3) AS lv3,                                                    -- 取列：起始取列子句，本行先取「lv3」，涉 bet_ip（下注 IP）、member_id（会员号）、lv3（三级代理线）
  COUNT(*) AS n_orders_ip, COUNT(DISTINCT b.round_key) AS n_rounds_ip,                              -- 计数表达式：统计去重个数，产出「n_rounds_ip」
  SUM(b.stake) AS stake_ip, SUM(b.game_pnl) AS game_pnl_ip,                                         -- 汇总表达式：取用 stake（下注额（经汇率归一化））、game_pnl（游戏净输赢），产出「game_pnl_ip」
  SUM(b.rebate) AS rebate_ip, SUM(b.net_pnl) AS net_pnl_ip,                                         -- 汇总表达式：取用 net_pnl（会员净输赢）、rebate（退水），产出「net_pnl_ip」
  MAX(pl.n_orders_all) AS n_orders_all, MAX(pl.n_rounds_all) AS n_rounds_all,                       -- 取最大值表达式：产出「n_rounds_all」
  MAX(pl.net_pnl_all) AS net_pnl_all, MAX(pl.game_pnl_all) AS game_pnl_all,                         -- 取最大值表达式：产出「game_pnl_all」
  COUNT(*)*1.0/NULLIF(MAX(pl.n_orders_all),0) AS ip_order_share                                     -- 计数表达式：取最大值，产出「ip_order_share」
FROM bs b JOIN pl ON pl.member_id=b.member_id                                                       -- 取数来源：取自本条自建的中间结果集 bs，连接键为 member_id（会员号）
WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL                                                         -- 过滤条件：限定该值非空，涉 bet_ip（下注 IP）
GROUP BY b.bet_ip, b.member_id                                                                      -- 分组：按 b.bet_ip, b.member_id 汇总
HAVING COUNT(*) >= 30                                                                               -- 分组后过滤：限定行数不少于 30
ORDER BY n_orders_ip DESC;                                                                          -- 排序：按 n_orders_ip（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   C-01 · 信用枢纽排序 · member_per_chain（AX-A5 量化，实测榜首 2,132 人单链）
   
   ▸ 导出：「数据库/C01_ip_chain.csv」
   ▸ 用途：信用枢纽排序，玩家/代理评分的 IP 结构罚项来源
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C01_ip_chain.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C01_ip_chain.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C01_ip_chain.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 C01_ip_chain.csv）
SELECT bet_ip,                                                                                      -- 取列：起始取列子句，本行先列 bet_ip，涉 bet_ip（下注 IP）
       COUNT(DISTINCT member_id) AS n_member,                                                       -- 计数表达式：统计去重个数，产出「n_member」
       COUNT(DISTINCT lv3)       AS n_lv3_chain,                                                    -- 计数表达式：统计去重个数，产出「n_lv3_chain」
       COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT lv3),0) AS member_per_chain,             -- 计数表达式：统计去重个数，产出「member_per_chain」
       COUNT(*) AS n_orders, SUM(stake) AS stake,                                                   -- 计数表达式：汇总，取用 stake（下注额（经汇率归一化）），产出「stake」
       SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl                                           -- 汇总表达式：取用 net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「net_pnl」
FROM bs                                                                                             -- 取数来源：取自本条自建的中间结果集 bs
WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL                                                           -- 过滤条件：限定该值非空，涉 bet_ip（下注 IP）
GROUP BY bet_ip                                                                                     -- 分组：按 bet_ip 汇总
HAVING COUNT(DISTINCT member_id) >= 20                                                              -- 分组后过滤：限定 member_id 的去重个数不少于 20，涉 member_id（会员号）
ORDER BY member_per_chain DESC;                                                                     -- 排序：按 member_per_chain（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ╔══════════════════════════════════════════════════════════════════════╗
   ║  ⛔ 本条已被取代 —— 请勿运行，请改跑 卷二 §C06fix                      ║
   ╠══════════════════════════════════════════════════════════════════════╣
   ║  取代原因：本条以 LIKE 判别庄闲，而 DX-01 全量普查证实 bet09 存的是    ║
   ║  英文玩法名（Banker / Player / Tie …），判别清单里的 ('1','B','庄')    ║
   ║  一个都对不上，故实测零命中；且 LIKE 会误纳 BankerDragonBonus 等边注。 ║
   ║  两条同写 「数据库/C06_hedge_pairs.csv」，后跑者覆盖先跑者——           ║
   ║  若误跑本条，对打对名单将被清空，荷官与代理的罚项维度随之全空。        ║
   ║  正文保留仅供追溯口径演进，不作运行用途。                              ║
   ╚══════════════════════════════════════════════════════════════════════╝ */

/* ═══════════════════════════════════════════════════════════════════════
   C-06 · 同IP对打对 · 对冲覆盖（实测 999 对完美对打、最长 1,185 把）
   本金匹配容差 10%；玩法编码若与库内不符，改 bet_side 判别清单即可
   ▸ 导出：⛔ 已摘除，本条不再产出任何交付件——正版请跑 §C06fix
   ▸ 用途：对打对名单，IP-S6/IP-S8 与荷官/代理罚项来源
   ═══════════════════════════════════════════════════════════════════════ */
-- C-06 校准版 · 由您 2026-08-07 上传的原文自动改写而成
-- 唯一改动：side CTE 的玩法判别（庄 2 处、闲 2 处）
--   bet_side IN ('1','B','庄','莊')  ->  TRIM(bet_side) = 'Banker'
--   bet_side IN ('2','P','闲','閒')  ->  TRIM(bet_side) = 'Player'
-- 依据：DX-01 全量普查，bet09 存英文玩法名 Banker 4682万 / Player 4422万
-- 其余一字未动。头部块注释已删除（避免 §DX-02 的注释塌缩问题）

--   ⛔ 【已于 2026-08-09 摘除 · §C-06 原版】原 SQL 74 行。缘由：已被 §C06fix 取代（原版 side CTE 用 '1'/'B'/'庄' 判庄闲，与库内实际取值 Banker/Player 不符，两次实测均返回零行）。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。

/* ═══════════════════════════════════════════════════════════════════════
   C-08 · /24 网段聚集 · 原版（按会员数降序；实测榜首为 CGNAT 饱和段）
   
   ▸ 导出：「数据库/C08_subnet_all.csv」
   ▸ 用途：/24 网段全量（含 CGNAT），白名单候选甄别
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_all.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_all.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_all.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_all.csv）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  CONCAT(SPLIT_PART(bet_ip,'.',1),'.',SPLIT_PART(bet_ip,'.',2),'.',                                 -- 取值表达式：取用 bet_ip（下注 IP）
         SPLIT_PART(bet_ip,'.',3),'.0/24') AS subnet_24,                                            -- 取值表达式：取用 bet_ip（下注 IP），产出「subnet_24」
  COUNT(DISTINCT bet_ip)    AS n_ip,                                                                -- 计数表达式：统计去重个数，产出「n_ip」
  COUNT(DISTINCT member_id) AS n_member,                                                            -- 计数表达式：统计去重个数，产出「n_member」
  COUNT(DISTINCT lv3)       AS n_lv3_chain,                                                         -- 计数表达式：统计去重个数，产出「n_lv3_chain」
  COUNT(*) AS n_orders, SUM(stake) AS stake,                                                        -- 计数表达式：汇总，取用 stake（下注额（经汇率归一化）），产出「stake」
  SUM(game_pnl) AS game_pnl, SUM(valid_bet) AS valid_bet                                            -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「valid_bet」
FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL                                                   -- 取数来源：取自本条自建的中间结果集 bs
GROUP BY 1                                                                                          -- 分组：按第 1 个取列汇总
HAVING COUNT(DISTINCT member_id) >= 5                                                               -- 分组后过滤：限定 member_id 的去重个数不少于 5，涉 member_id（会员号）
ORDER BY n_member DESC;                                                                             -- 排序：按 n_member（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   N1 · /24 网段 · 稀疏段靶向版（CGNAT 条件化：n_ip ≤ 30）
   信用枢纽层完整摊开：少门牌、多人头、单链密
   ▸ 导出：「数据库/C08_subnet_sparse.csv」
   ▸ 用途：稀疏段靶向榜，信用枢纽层
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_sparse.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_sparse.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_sparse.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 C08_subnet_sparse.csv）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  CONCAT(SPLIT_PART(bet_ip,'.',1),'.',SPLIT_PART(bet_ip,'.',2),'.',                                 -- 取值表达式：取用 bet_ip（下注 IP）
         SPLIT_PART(bet_ip,'.',3),'.0/24') AS subnet_24,                                            -- 取值表达式：取用 bet_ip（下注 IP），产出「subnet_24」
  COUNT(DISTINCT bet_ip)    AS n_ip,                                                                -- 计数表达式：统计去重个数，产出「n_ip」
  COUNT(DISTINCT member_id) AS n_member,                                                            -- 计数表达式：统计去重个数，产出「n_member」
  COUNT(DISTINCT lv3)       AS n_lv3_chain,                                                         -- 计数表达式：统计去重个数，产出「n_lv3_chain」
  COUNT(DISTINCT member_id)*1.0/NULLIF(COUNT(DISTINCT bet_ip),0) AS member_per_ip,                  -- 计数表达式：统计去重个数，产出「member_per_ip」
  COUNT(*) AS n_orders, SUM(valid_bet) AS valid_bet, SUM(game_pnl) AS game_pnl                      -- 计数表达式：汇总，取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「game_pnl」
FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL                                                   -- 取数来源：取自本条自建的中间结果集 bs
GROUP BY 1                                                                                          -- 分组：按第 1 个取列汇总
HAVING COUNT(DISTINCT member_id) >= 5 AND COUNT(DISTINCT bet_ip) <= 30                              -- 分组后过滤：限定 member_id 的去重个数不少于 5、bet_ip 的去重个数不多于 30，涉 bet_ip（下注 IP）、member_id（会员号）
ORDER BY n_member DESC;                                                                             -- 排序：按 n_member（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   N1b · 金标准活跃探针（2022 年标注 IP 在 2026 窗口是否仍活跃）
   返回 0 行 = 金标准段窗口内无活动 → 一票否决条款改按 17 个单 IP 复验
   ▸ 导出：不需要 —— 屏幕看结果即可（0 行即结论）
   ═══════════════════════════════════════════════════════════════════════ */
SELECT CONCAT(SPLIT_PART(ip,'.',1),'.',SPLIT_PART(ip,'.',2),'.',                                    -- 取列：起始取列子句，本行先列 CONCAT(SPLIT_PART(ip,'.',1),'.',SPLIT_PART(ip,'.',2),'.'
       SPLIT_PART(ip,'.',3),'.0/24') AS subnet_24,                                                  -- 取值表达式：产出「subnet_24」
       COUNT(DISTINCT ip) AS n_ip, COUNT(DISTINCT bet05) AS n_member,                               -- 计数表达式：统计唯一会员数（铁律分母，全窗 721,190 人），产出「n_member」
       COUNT(*) AS n_orders                                                                         -- 计数表达式：产出「n_orders」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101'                                      -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
  AND (ip LIKE '111.247.37.%' OR ip LIKE '103.123.134.%')                                           -- 并列条件：限定匹配所给模式
GROUP BY 1;                                                                                         -- 分组：按第 1 个取列汇总


/* ═══════════════════════════════════════════════════════════════════════
   D-05 · 桌台进度统计（30 桌分位；封盘代理口径证据）
   
   ▸ 导出：「数据库/S_second_dist.csv」
   ▸ 用途：报告 fetch("S_second_dist")：桌台进度分位
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_second_dist.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_second_dist.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_second_dist.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_second_dist.csv）
gi AS (SELECT gi011 AS table_id,                                                                    -- 取值表达式：取用 gi011（桌号），产出「table_id」
              CONCAT_WS('|', gi002, gi003, gi011) AS round_key,                                     -- 取值表达式：取用 gi011（桌号）、round_key（局键），产出「round_key」
              gi004 AS t_open, gi006 AS t_reveal                                                    -- 取值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「t_reveal」
       FROM ods_mariadb_2b.ods_a168_game_info                                                       -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
       WHERE gi001='101' AND gi013='1' AND is_lock='N'                                              -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'、is_lock等于 'N'，涉 gi001（局主键）
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),                                           -- 并列条件：限定 gi004不少于 '2026-03-21'，涉 gi004（局开始时刻）
pr AS (SELECT b.table_id, b.round_key,                                                              -- 取值表达式：取用 round_key（局键）
              (UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))*1.0                                -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
              /NULLIF(UNIX_TIMESTAMP(g.t_reveal)-UNIX_TIMESTAMP(g.t_open),0) AS progress            -- 除法或乘法计算：产出「progress」
       FROM bs b JOIN gi g ON g.round_key=b.round_key)                                              -- 取数来源：取自本条自建的中间结果集 bs，连接键为 round_key（局键）
SELECT table_id, COUNT(*) AS n_orders,                                                              -- 取列：起始取列子句，本行先取「n_orders」
       PERCENTILE_APPROX(progress,0.5)  AS p50,                                                     -- 取近似分位数表达式：产出「p50」
       PERCENTILE_APPROX(progress,0.75) AS p75,                                                     -- 取近似分位数表达式：产出「p75」
       PERCENTILE_APPROX(progress,0.9)  AS p90,                                                     -- 取近似分位数表达式：产出「p90」
       PERCENTILE_APPROX(progress,0.95) AS p95,                                                     -- 取近似分位数表达式：产出「p95」
       PERCENTILE_APPROX(progress,0.99) AS p99,                                                     -- 取近似分位数表达式：产出「p99」
       MAX(progress) AS max_progress                                                                -- 取最大值表达式：产出「max_progress」
FROM pr WHERE progress BETWEEN 0 AND 1.5                                                            -- 取数来源：取自本条自建的中间结果集 pr
GROUP BY table_id ORDER BY n_orders DESC;                                                           -- 分组：按 table_id ORDER BY n_orders（降序）汇总


/* ═══════════════════════════════════════════════════════════════════════
   D-03S · 日度尾段对照（139 行；五重检验的输入，裁定已闭合）
   
   ▸ 导出：「数据库/D03S_daily_roi_diff.csv」
   ▸ 用途：五重显著性检验输入（139 行）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 D03S_daily_roi_diff.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 D03S_daily_roi_diff.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 D03S_daily_roi_diff.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 D03S_daily_roi_diff.csv）
gi AS (SELECT CONCAT_WS('|', gi002, gi003, gi011) AS round_key,                                     -- 取值表达式：取用 gi011（桌号）、round_key（局键），产出「round_key」
              gi004 AS t_open, gi006 AS t_reveal                                                    -- 取值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「t_reveal」
       FROM ods_mariadb_2b.ods_a168_game_info                                                       -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
       WHERE gi001='101' AND gi013='1' AND is_lock='N'                                              -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'、is_lock等于 'N'，涉 gi001（局主键）
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),                                           -- 并列条件：限定 gi004不少于 '2026-03-21'，涉 gi004（局开始时刻）
pr AS (SELECT b.bet_date, b.round_key, b.valid_bet, b.game_pnl,                                     -- 取值表达式：取用 valid_bet（有效投注（洗码量））、round_key（局键）、game_pnl（游戏净输赢）
              (UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))*1.0                                -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
              /NULLIF(UNIX_TIMESTAMP(g.t_reveal)-UNIX_TIMESTAMP(g.t_open),0) AS progress            -- 除法或乘法计算：产出「progress」
       FROM bs b JOIN gi g ON g.round_key=b.round_key)                                              -- 取数来源：取自本条自建的中间结果集 bs，连接键为 round_key（局键）
SELECT bet_date, COUNT(DISTINCT round_key) AS n_rounds,                                             -- 取列：起始取列子句，本行先取「n_rounds」，涉 round_key（局键）、bet_date（营业日）
  SUM(CASE WHEN progress>=0.90 THEN valid_bet ELSE 0 END) AS vb_tail,                               -- 汇总表达式：取用 valid_bet（有效投注（洗码量）），产出「vb_tail」
  SUM(CASE WHEN progress< 0.90 THEN valid_bet ELSE 0 END) AS vb_norm,                               -- 汇总表达式：取用 valid_bet（有效投注（洗码量）），产出「vb_norm」
  SUM(CASE WHEN progress>=0.90 THEN game_pnl ELSE 0 END)                                            -- 汇总表达式：取用 game_pnl（游戏净输赢）
    /NULLIF(SUM(CASE WHEN progress>=0.90 THEN valid_bet ELSE 0 END),0) AS roi_tail,                 -- 除法或乘法计算：汇总，取用 valid_bet（有效投注（洗码量）），产出「roi_tail」
  SUM(CASE WHEN progress< 0.90 THEN game_pnl ELSE 0 END)                                            -- 汇总表达式：取用 game_pnl（游戏净输赢）
    /NULLIF(SUM(CASE WHEN progress< 0.90 THEN valid_bet ELSE 0 END),0) AS roi_norm,                 -- 除法或乘法计算：汇总，取用 valid_bet（有效投注（洗码量）），产出「roi_norm」
  SUM(CASE WHEN progress>=0.90 THEN game_pnl ELSE 0 END)                                            -- 汇总表达式：取用 game_pnl（游戏净输赢）
    /NULLIF(SUM(CASE WHEN progress>=0.90 THEN valid_bet ELSE 0 END),0)                              -- 除法或乘法计算：汇总，取用 valid_bet（有效投注（洗码量））
  - SUM(CASE WHEN progress< 0.90 THEN game_pnl ELSE 0 END)                                          -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR）
    /NULLIF(SUM(CASE WHEN progress< 0.90 THEN valid_bet ELSE 0 END),0) AS roi_diff                  -- 除法或乘法计算：汇总，取用 valid_bet（有效投注（洗码量）），产出「roi_diff」
FROM pr WHERE progress BETWEEN 0 AND 1.5                                                            -- 取数来源：取自本条自建的中间结果集 pr
GROUP BY bet_date ORDER BY bet_date;                                                                -- 分组：按 bet_date ORDER BY bet_date 汇总


/* ═══════════════════════════════════════════════════════════════════════
   D-06 · 玩家尾段十一项指标（实测跑通原文收编）
   个体层 winrate_diff>0 = 49.7% 白噪音，尾段裁定第三重复核
   ▸ 导出：「数据库/S_player_tail.csv」
   ▸ 用途：报告 fetch("S_player_tail")：玩家尾段十一项
   ═══════════════════════════════════════════════════════════════════════ */
/* --- D-06 玩家尾段十一项指标（SQL 端完成，加过滤控制在 10 万行内）----
   过滤：n_rounds_all >= 30（低于此样本量的玩家 Wilson CI 宽度 > 0.15，
         阈值无区分意义，见需求 §2.2-5）
   ------------------------------------------------------------------------- */
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet18,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet16, b.bet17, b.bet18，涉 bet13（下注金额）、bet14（派彩金额）、bet16（退水金额）
         b.bet19, b.bet20, b.bet21, b.bet22, b.bet38,                                               -- 续行：接续上一取列子句，续列 b.bet19, b.bet20, b.bet21, b.bet22, b.bet38，涉 bet19（二级代理线）、bet20（三级代理线）、bet21（四级代理线）
         b.bet39, b.category, b.validbet,                                                           -- 续行：接续上一取列子句，续列 b.bet39, b.category, b.validbet，涉 bet39（桌号）、validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT v.bet05 AS member_id,                                                                      -- 取列：起始取列子句，本行先取「member_id」，涉 bet05（会员号）、member_id（会员号）
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT b.*, PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,           -- 取列：整体承接上游结果集的全部字段，不再逐列列举
              COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round             -- 计数表达式：取用 round_key（局键），产出「n_in_round」
  FROM bs b                                                                                         -- 取数来源：取自本条自建的中间结果集 bs
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
prd AS (                                                                                            -- 公共表表达式：开启中间结果集 prd，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT member_id, round_key, table_id,                                                            -- 取列：起始取列子句，本行先列 member_id, round_key, table_id，涉 round_key（局键）、member_id（会员号）
         MAX(pr_in_round) AS max_pr,                                                                -- 取最大值表达式：产出「max_pr」
         MAX(n_in_round)  AS n_in_round,                                                            -- 取最大值表达式：产出「n_in_round」
         SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,                                          -- 汇总表达式：取用 stake（下注额（经汇率归一化））、valid_bet（有效投注（洗码量）），产出「valid_bet」
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,                 -- 汇总表达式：取用 net_pnl（会员净输赢）、game_pnl（游戏净输赢）、rebate（退水），产出「net_pnl」
         CASE WHEN SUM(game_pnl) > 0 THEN 1 ELSE 0 END AS is_win,                                   -- 条件分支：汇总，取用 game_pnl（游戏净输赢），产出「is_win」
         CASE WHEN SUM(game_pnl) < 0 THEN 1 ELSE 0 END AS is_lose                                   -- 条件分支：汇总，取用 game_pnl（游戏净输赢），产出「is_lose」
  FROM ord WHERE n_in_round >= 5                                                                    -- 取数来源：取自本条自建的中间结果集 ord
  GROUP BY member_id, round_key, table_id                                                           -- 分组：按 member_id, round_key, table_id 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
fl AS (                                                                                             -- 公共表表达式：开启中间结果集 fl，其后各行为其定义体（交付件 S_player_tail.csv）
  SELECT p.*, CASE WHEN p.max_pr >= 0.80 THEN 1 ELSE 0 END AS is_tail                               -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM prd p                                                                                        -- 取数来源：取自本条自建的中间结果集 prd
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 S_player_tail.csv）
SELECT member_id,                                                                                   -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
  COUNT(*)                      AS n_rounds_all,                                                    -- 计数表达式：产出「n_rounds_all」
  SUM(is_tail)                  AS n_rounds_tail,                                                   -- 汇总表达式：产出「n_rounds_tail」
  SUM(is_tail) * 1.0 / COUNT(*) AS tail_share,                                                      -- 汇总表达式：计数，产出「tail_share」
  SUM(is_tail * is_win)  AS tail_win,                                                               -- 汇总表达式：产出「tail_win」
  SUM(is_tail * is_lose) AS tail_lose,                                                              -- 汇总表达式：产出「tail_lose」
  SUM(is_tail * is_win) * 1.0                                                                       -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(SUM(is_tail * is_win) + SUM(is_tail * is_lose), 0) AS tail_winrate,                    -- 除法或乘法计算：汇总，产出「tail_winrate」
  SUM((1 - is_tail) * is_win) * 1.0                                                                 -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(SUM((1 - is_tail) * is_win) + SUM((1 - is_tail) * is_lose), 0) AS norm_winrate,        -- 除法或乘法计算：汇总，产出「norm_winrate」
  SUM(is_tail * is_win) * 1.0                                                                       -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(SUM(is_tail * is_win) + SUM(is_tail * is_lose), 0)                                     -- 除法或乘法计算：汇总
    - SUM((1 - is_tail) * is_win) * 1.0                                                             -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(SUM((1 - is_tail) * is_win) + SUM((1 - is_tail) * is_lose), 0) AS winrate_diff,        -- 除法或乘法计算：汇总，产出「winrate_diff」
  SUM(is_tail * stake)     AS tail_stake,                                                           -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「tail_stake」
  SUM(is_tail * valid_bet) AS tail_valid_bet,                                                       -- 汇总表达式：取用 valid_bet（有效投注（洗码量）），产出「tail_valid_bet」
  SUM(is_tail * game_pnl)  AS tail_game_pnl,                                                        -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「tail_game_pnl」
  SUM(is_tail * rebate)    AS tail_rebate,                                                          -- 汇总表达式：取用 rebate（退水），产出「tail_rebate」
  SUM(is_tail * net_pnl)   AS tail_net_pnl,                                                         -- 汇总表达式：取用 net_pnl（会员净输赢），产出「tail_net_pnl」
  SUM(is_tail * game_pnl) / NULLIF(SUM(is_tail * valid_bet), 0) AS tail_roi,                        -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「tail_roi」
  SUM((1 - is_tail) * game_pnl) AS norm_game_pnl,                                                   -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「norm_game_pnl」
  SUM((1 - is_tail) * game_pnl)                                                                     -- 汇总表达式：取用 game_pnl（游戏净输赢）
    / NULLIF(SUM((1 - is_tail) * valid_bet), 0) AS norm_roi,                                        -- 除法或乘法计算：汇总，取用 valid_bet（有效投注（洗码量）），产出「norm_roi」
  SUM(CASE WHEN is_tail = 1 AND game_pnl > 0 THEN game_pnl ELSE 0 END)                              -- 汇总表达式：取用 game_pnl（游戏净输赢）
    / NULLIF(SUM(CASE WHEN game_pnl > 0 THEN game_pnl ELSE 0 END), 0) AS tail_profit_share          -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「tail_profit_share」
FROM fl                                                                                             -- 取数来源：取自本条自建的中间结果集 fl
GROUP BY member_id                                                                                  -- 分组：按 member_id 汇总
HAVING COUNT(*) >= 30                                                                               -- 分组后过滤：限定行数不少于 30
ORDER BY member_id;                                                                                 -- 排序：按 member_id 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   S-01 · 玩家评分底料（全局聚合；对打指数/注册邻近在 Python 侧并入 C-06）
   导出为 数据库/S01_player_score.csv
   ▸ 导出：「数据库/S01_player_score.csv」
   ▸ 用途：★ 玩家评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
lab AS (SELECT bet05 AS member_id,                                                                  -- 取值表达式：取用 bet05（会员号）、member_id（会员号），产出「member_id」
               SUM(CASE WHEN risk='1' THEN 1 ELSE 0 END) AS n_risk_days,                            -- 汇总表达式：产出「n_risk_days」
               SUM(CASE WHEN orders='1' THEN 1 ELSE 0 END) AS n_order_days                          -- 汇总表达式：产出「n_order_days」
        FROM ods_mariadb_2b.ods_a168_dailyreport_member GROUP BY bet05),                            -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
/* ── 扩编维度① 投注产品结构熵 ─────────────────────────────────────
   香农熵：把该会员的投注额按 23 种投注产品拆开，看分散还是集中。
   熵高 = 庄闲和边注都押一点，是娱乐型客人的常态；
   熵低 = 火力集中在少数高赔率边注，是技术型画像的特征之一。
   赏罚方向为「赏」——熵高的客人对平台更安全。 */
psplit AS (                                                                                         -- 公共表表达式：开启中间结果集 psplit，其后各行为其定义体（交付件 S01_player_score.csv）
  SELECT member_id, bet_side,                                                                       -- 取列：起始取列子句，本行先列 member_id, bet_side，涉 member_id（会员号）
         SUM(stake) AS s_side,                                                                      -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「s_side」
         SUM(SUM(stake)) OVER (PARTITION BY member_id) AS s_all                                     -- 汇总表达式：取用 stake（下注额（经汇率归一化））、member_id（会员号），产出「s_all」
  FROM bs GROUP BY member_id, bet_side                                                              -- 取数来源：取自本条自建的中间结果集 bs
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
ent AS (                                                                                            -- 公共表表达式：开启中间结果集 ent，其后各行为其定义体（交付件 S01_player_score.csv）
  SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
         -SUM((s_side/s_all) * LN(s_side/s_all)) AS 投注产品结构熵                                         -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「投注产品结构熵」
  FROM psplit WHERE s_all > 0 AND s_side > 0                                                        -- 取数来源：取自本条自建的中间结果集 psplit
  GROUP BY member_id                                                                                -- 分组：按 member_id 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
/* ── 扩编维度② 索提诺稳定性（会员视角的下行风险调整收益）──────────
   先把注单压成「会员×日」的日 ROI，再算 日ROI均值 ÷ 下行标准差。
   只统计低于 0 那一侧的波动——赢钱时的波动不是风险。
   赏罚方向为「罚」：赢得稳的客人正是 T2 技术型风险用户，
   赢得多但忽输忽赢的反而是正常娱乐客。**不要把方向搞反。** */
dly AS (                                                                                            -- 公共表表达式：开启中间结果集 dly，其后各行为其定义体（交付件 S01_player_score.csv）
  SELECT member_id, bet_date,                                                                       -- 取列：起始取列子句，本行先列 member_id, bet_date，涉 member_id（会员号）、bet_date（营业日）
         SUM(game_pnl) AS pnl_d, SUM(stake) AS stake_d                                              -- 汇总表达式：取用 stake（下注额（经汇率归一化））、game_pnl（游戏净输赢），产出「stake_d」
  FROM bs GROUP BY member_id, bet_date                                                              -- 取数来源：取自本条自建的中间结果集 bs
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
srt AS (                                                                                            -- 公共表表达式：开启中间结果集 srt，其后各行为其定义体（交付件 S01_player_score.csv）
  SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
         AVG(pnl_d / NULLIF(stake_d,0))                                  AS mu_roi_d,               -- 求均值表达式：产出「mu_roi_d」
         SQRT(AVG(POW(LEAST(pnl_d / NULLIF(stake_d,0), 0), 2)))          AS dd_roi_d,               -- 取值表达式：求均值，产出「dd_roi_d」
         AVG(pnl_d / NULLIF(stake_d,0))                                                             -- 求均值表达式：承接上一子句，构成完整语句，属 交付件 S01_player_score.csv 之取数
           / NULLIF(SQRT(AVG(POW(LEAST(pnl_d / NULLIF(stake_d,0), 0), 2))), 0)                      -- 除法或乘法计算：求均值
                                                                          AS 索提诺稳定性                 -- 取值表达式：取用索提诺稳定性（玩家雷达罚侧维），产出「索提诺稳定性」
  FROM dly GROUP BY member_id                                                                       -- 取数来源：取自本条自建的中间结果集 dly
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
/* ── 扩编维度③ 生命周期阶段 ──────────────────────────────────────
   首末注单跨度 × 近期活跃衰减，取值越大代表越处于成熟稳定期。
   算法：活跃跨度天数 × (1 − 距窗口右端的静默天数 / 窗口总天数)，
   新客跨度短、流失前兆者静默久，两端都会被压低。窗口 139 天为字面量。
   赏罚方向为「赏」。 */
lc AS (                                                                                             -- 公共表表达式：开启中间结果集 lc，其后各行为其定义体（交付件 S01_player_score.csv）
  SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
         DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1 AS span_days,                                   -- 取值表达式：取最大值、取最小值，取用 bet_date（营业日），产出「span_days」
         DATEDIFF(DATE '2026-08-06', MAX(bet_date)) AS silent_days,                                 -- 取值表达式：取最大值，取用 bet_date（营业日），产出「silent_days」
         (DATEDIFF(MAX(bet_date), MIN(bet_date)) + 1)                                               -- 续行：取最大值、取最小值，取用 bet_date（营业日）
           * (1 - DATEDIFF(DATE '2026-08-06', MAX(bet_date)) / 139.0) AS 生命周期阶段                     -- 除法或乘法计算：取最大值，取用 bet_date（营业日）、生命周期阶段（玩家雷达赏侧维），产出「生命周期阶段」
  FROM bs GROUP BY member_id                                                                        -- 取数来源：取自本条自建的中间结果集 bs
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 S01_player_score.csv）
SELECT b.member_id,                                                                                 -- 取列：起始取列子句，本行先列 b.member_id，涉 member_id（会员号）
  SUM(b.valid_bet) AS 流水贡献,                                                                         -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、流水贡献（玩家雷达赏侧维），产出「流水贡献」
  -SUM(b.game_pnl) AS 游戏输赢贡献,          -- 会员输=平台赢，取负号
  COUNT(DISTINCT b.bet_date) AS 活跃稳定,                                                               -- 计数表达式：统计去重个数，产出「活跃稳定」
  SUM(b.rebate) AS 退水支出,                                                                            -- 汇总表达式：取用 rebate（退水）、退水支出（退水成本），产出「退水支出」
  COUNT(DISTINCT b.bet_ip) AS n_ip,                                                                 -- 计数表达式：统计去重个数，产出「n_ip」
  COUNT(DISTINCT b.lv3) AS n_chain,                                                                 -- 计数表达式：统计去重个数，产出「n_chain」
  COALESCE(MAX(l.n_risk_days),0)+COALESCE(MAX(l.n_order_days),0) AS 人工标记史,                          -- 取值表达式：取最大值，取用人工标记史（玩家雷达罚侧维），产出「人工标记史」
  -- ★ 扩编三列：报告的玩家雷达按列名取用，列名一字不可改
  MAX(e.投注产品结构熵)  AS 投注产品结构熵,                                                                       -- 取最大值表达式：取用投注产品结构熵（玩家雷达赏侧维），产出「投注产品结构熵」
  MAX(sr.索提诺稳定性)   AS 索提诺稳定性,                                                                       -- 取最大值表达式：取用索提诺稳定性（玩家雷达罚侧维），产出「索提诺稳定性」
  MAX(lcx.生命周期阶段)  AS 生命周期阶段                                                                        -- 取最大值表达式：取用生命周期阶段（玩家雷达赏侧维），产出「生命周期阶段」
FROM bs b                                                                                           -- 取数来源：取自本条自建的中间结果集 bs
LEFT JOIN lab l   ON l.member_id  = b.member_id                                                     -- 左连接：取自本条自建的中间结果集 lab，连接键为 member_id（会员号）
LEFT JOIN ent e   ON e.member_id  = b.member_id                                                     -- 左连接：取自本条自建的中间结果集 ent，连接键为 member_id（会员号）
LEFT JOIN srt sr  ON sr.member_id = b.member_id                                                     -- 左连接：取自本条自建的中间结果集 srt，连接键为 member_id（会员号）
LEFT JOIN lc  lcx ON lcx.member_id = b.member_id                                                    -- 左连接：取自本条自建的中间结果集 lc，连接键为 member_id（会员号）
GROUP BY b.member_id                                                                                -- 分组：按 b.member_id 汇总
HAVING COUNT(DISTINCT b.round_key) >= 30                                                            -- 分组后过滤：限定 b.round_key 的去重个数不少于 30，涉 round_key（局键）
ORDER BY 流水贡献 DESC;                                                                                 -- 排序：按流水贡献（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   S-02 · 荷官评分底料（提速改写版 · 输出与原版逐列一致）
   对打局占比/異常对关联在 Python 侧并 §C06fix 名单
   ▸ 导出：「数据库/S02_dealer_score.csv」
   ▸ 用途：★ 荷官评分雷达 + 综合分
   ▸ 提速原理（原版实测 3 小时未毕，根因为三处）：
     ① pace 原以 bs JOIN gi ON table_id——注单粒度×局粒度的多对多爆炸，
        单张热门桌即数万亿配对。现改为**加权矩坍缩**：样本标准差只依赖
        Σ权重、Σ加权时长、Σ加权时长²三个矩，桌级统计×荷官桌行数即可等价算出；
     ② bs 原被引用三次（pace/mrep/终查），整条 1.9 亿行去重流水线跑三遍。
        现一次坍缩为 bd（荷官×桌×会员×局），bs 全文只扫一遍；
     ③ 开窗去重原 SELECT b.*，四十余列 varchar(65533) 全过排序洗牌。
        现只携带下游必需的二十一列。
     输出逐列一致；节奏稳定度由矩公式计算，与原式差异在双精度舍入位
     （1e-12 量级），分位归一后不改变任何排名。
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt,                                                  -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt，涉 dt（营业日）
         b.category, b.bet38, b.bet05, b.bet11, b.bet08,                                            -- 续行：接续上一取列子句，续列 b.category, b.bet38, b.bet05, b.bet11, b.bet08，涉 bet05（会员号）、bet08（下注时间）、bet11（汇率）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet03, b.bet04, b.bet39, b.eid,                                                          -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet39, b.eid，涉 bet03（靴号）、bet04（局内序号）、bet39（桌号）
         b.validbet, b.bet13, b.bet14,                                                              -- 续行：接续上一取列子句，续列 b.validbet, b.bet13, b.bet14，涉 bet13（下注金额）、bet14（派彩金额）、validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单（谓词与原版一字不差）
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
bs AS (                  -- 金额正名（只保留本查询实际使用的量）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id,                                                  -- 取列：起始取列子句，本行先取「dealer_id」，涉 bet05（会员号）、eid（荷官工号）、member_id（会员号）
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl                            -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
  WHERE NULLIF(TRIM(v.eid),'') IS NOT NULL   -- 空荷官行本就不进任何输出组，前置过滤不改输出
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
bd AS (                  -- ★ 一次坍缩：荷官×桌×会员×局。bs 全文只被此处引用一次
  SELECT dealer_id, table_id, member_id, round_key,                                                 -- 取列：起始取列子句，本行先列 dealer_id, table_id, member_id, round_key，涉 round_key（局键）、member_id（会员号）、dealer_id（荷官工号）
         COUNT(*)       AS n_bet_rows,     -- 该组合的注单行数（pace 的权重）
         SUM(valid_bet) AS v_sum,                                                                   -- 汇总表达式：取用 valid_bet（有效投注（洗码量）），产出「v_sum」
         SUM(game_pnl)  AS g_sum                                                                    -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「g_sum」
  FROM bs                                                                                           -- 取数来源：取自本条自建的中间结果集 bs
  GROUP BY dealer_id, table_id, member_id, round_key                                                -- 分组：按 dealer_id, table_id, member_id, round_key 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
/* ── 扩编维度① 当值时长 ─────────────────────────────────────────
   以「在册局数」为分层基准。不做这一层分层，裸排名的榜首永远是
   上班天数最少的新人——他们样本少、波动大，任何比率指标都会虚高。
   赏罚方向为「赏」。 */
/* ── 扩编维度② 节奏稳定度：加权矩坍缩版 ─────────────────────────
   原式 = 对「荷官的每笔注单 × 同桌每一局的时长」求 STDDEV_SAMP。
   等价于：每桌局时长以该荷官在该桌的注单行数加权。
   样本标准差只需三个矩：N=Σw·n、S1=Σw·Σx、S2=Σw·Σx²，
   var = (S2 − S1²/N)/(N−1)。桌级统计仅数百行，荷官×桌仅数千行。
   节奏忽快忽慢是操作异常的先兆，也会影响玩家体验。赏罚方向为「赏」。 */
gi AS (                                                                                             -- 公共表表达式：开启中间结果集 gi，其后各行为其定义体（交付件 S02_dealer_score.csv）
  SELECT gi011 AS table_id,                                                                         -- 取列：起始取列子句，本行先取「table_id」，涉 gi011（桌号）
         UNIX_TIMESTAMP(gi006) - UNIX_TIMESTAMP(gi004) AS sec_round                                 -- 取值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「sec_round」
  FROM ods_mariadb_2b.ods_a168_game_info                                                            -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
  WHERE gi001 = '101' AND gi013 = '1'                                                               -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'，涉 gi001（局主键）
    AND gi004 >= '2026-03-21' AND gi004 < '2026-08-07'                                              -- 并列条件：限定 gi004不少于 '2026-03-21'、gi004小于 '2026-08-07'，涉 gi004（局开始时刻）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
git AS (                 -- 每桌三矩（COUNT/SUM 天然忽略 NULL，与 STDDEV_SAMP 同语义）
  SELECT table_id,                                                                                  -- 取列：起始取列子句，本行先列 table_id
         COUNT(sec_round)                                            AS n_g,                        -- 计数表达式：产出「n_g」
         SUM(CAST(sec_round AS DOUBLE))                              AS s1,                         -- 汇总表达式：产出「s1」
         SUM(CAST(sec_round AS DOUBLE) * CAST(sec_round AS DOUBLE))  AS s2                          -- 汇总表达式：产出「s2」
  FROM gi GROUP BY table_id                                                                         -- 取数来源：取自本条自建的中间结果集 gi
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
dtc AS (                 -- 荷官×桌的注单行数（加权权重）
  SELECT dealer_id, table_id, SUM(n_bet_rows) AS n_rows                                             -- 取列：汇总，取用 dealer_id（荷官工号），产出「n_rows」
  FROM bd GROUP BY dealer_id, table_id                                                              -- 取数来源：取自本条自建的中间结果集 bd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
pace AS (                                                                                           -- 公共表表达式：开启中间结果集 pace，其后各行为其定义体（交付件 S02_dealer_score.csv）
  SELECT d.dealer_id,                                                                               -- 取列：起始取列子句，本行先列 d.dealer_id，涉 dealer_id（荷官工号）
         CASE                                                                                       -- 条件分支：开启分支判定，其后逐行列出条件与取值（交付件 S02_dealer_score.csv）
           WHEN SUM(d.n_rows * g.n_g) >= 2 THEN                                                     -- 分支判定：汇总
             1.0 / (1.0 + COALESCE(SQRT(GREATEST(                                                   -- 取值表达式：承接上一子句，构成完整语句，属 交付件 S02_dealer_score.csv 之取数
               ( SUM(d.n_rows * g.s2)                                                               -- 续行：汇总
                 - SUM(d.n_rows * g.s1) * SUM(d.n_rows * g.s1)                                      -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR）
                   / SUM(d.n_rows * CAST(g.n_g AS DOUBLE)) )                                        -- 除法或乘法计算：汇总
               / (SUM(d.n_rows * CAST(g.n_g AS DOUBLE)) - 1), 0)), 0))                              -- 除法或乘法计算：汇总
           ELSE 1.0     -- 原版：样本≤1 时 STDDEV_SAMP=NULL → COALESCE 0 → 稳定度 1.0
         END AS 节奏稳定度                                                                               -- 分支收束：结束条件分支并收敛为单一取值
  FROM dtc d JOIN git g ON g.table_id = d.table_id                                                  -- 取数来源：取自本条自建的中间结果集 dtc，连接键为 g.table_id = d.table_id
  GROUP BY d.dealer_id                                                                              -- 分组：按 d.dealer_id 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
/* ── 扩编维度③ 特定玩家复现率：改从 bd 派生，语义不变 ────────────
   该荷官桌上「出现最频繁的那一位会员」占其总局数的比例。
   正常荷官服务的是流动客群，比例低；比例畸高说明有固定的人一直跟着他，
   这是玩家—荷官关联的第一道筛。赏罚方向为「罚」。 */
mrep AS (                                                                                           -- 公共表表达式：开启中间结果集 mrep，其后各行为其定义体（交付件 S02_dealer_score.csv）
  SELECT dealer_id, member_id, COUNT(DISTINCT round_key) AS n_r                                     -- 取列：统计去重个数，产出「n_r」
  FROM bd GROUP BY dealer_id, member_id                                                             -- 取数来源：取自本条自建的中间结果集 bd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
top1 AS (                                                                                           -- 公共表表达式：开启中间结果集 top1，其后各行为其定义体（交付件 S02_dealer_score.csv）
  SELECT dealer_id, MAX(n_r) AS max_member_rounds                                                   -- 取列：取最大值，取用 dealer_id（荷官工号），产出「max_member_rounds」
  FROM mrep GROUP BY dealer_id                                                                      -- 取数来源：取自本条自建的中间结果集 mrep
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 S02_dealer_score.csv）
SELECT b.dealer_id,                                                                                 -- 取列：起始取列子句，本行先列 b.dealer_id，涉 dealer_id（荷官工号）
  SUM(b.v_sum) AS 在桌洗码量,                                                                            -- 汇总表达式：取用在桌洗码量（荷官雷达赏侧维），产出「在桌洗码量」
  COUNT(DISTINCT b.member_id) AS 客群广度,                                                              -- 计数表达式：统计去重个数，产出「客群广度」
  COUNT(DISTINCT b.round_key) AS n_rounds,                                                          -- 计数表达式：统计去重个数，产出「n_rounds」
  COUNT(DISTINCT b.table_id) AS n_tables,                                                           -- 计数表达式：统计去重个数，产出「n_tables」
  SUM(b.g_sum) AS 桌面输赢,                                                                             -- 汇总表达式：产出「桌面输赢」
  -- ★ 扩编三列：报告的荷官雷达按列名取用，列名一字不可改
  COUNT(DISTINCT b.round_key) AS 当值时长,                                                              -- 计数表达式：统计去重个数，产出「当值时长」
  MAX(p.节奏稳定度) AS 节奏稳定度,                                                                            -- 取最大值表达式：取用节奏稳定度（荷官雷达赏侧维），产出「节奏稳定度」
  MAX(t.max_member_rounds) * 1.0                                                                    -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(COUNT(DISTINCT b.round_key), 0) AS 特定玩家复现率                                             -- 除法或乘法计算：统计去重个数，产出「特定玩家复现率」
FROM bd b                                                                                           -- 取数来源：取自本条自建的中间结果集 bd
LEFT JOIN pace p ON p.dealer_id = b.dealer_id                                                       -- 左连接：取自本条自建的中间结果集 pace，连接键为 dealer_id（荷官工号）
LEFT JOIN top1 t ON t.dealer_id = b.dealer_id                                                       -- 左连接：取自本条自建的中间结果集 top1，连接键为 dealer_id（荷官工号）
GROUP BY b.dealer_id ORDER BY 在桌洗码量 DESC;                                                           -- 分组：按 b.dealer_id ORDER BY 在桌洗码量（降序）汇总


/* ═══════════════════════════════════════════════════════════════════════
   S-03 · 代理（LV3 链）评分底料
   对打渗透率在 Python 侧并 C-06；导出 数据库/S03_agent_score.csv
   ▸ 导出：「数据库/S03_agent_score.csv」
   ▸ 用途：★ 代理评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
/* ── 扩编维度① 下线留存 ─────────────────────────────────────────
   把 139 天窗口一切两半（前 70 天 / 后 69 天），算「两段都活跃的会员
   占前段活跃会员的比例」。留存高说明这条线在做真实经营；
   留存趋零而流水不低，多半是一批号刷完就换。赏罚方向为「赏」。 */
half AS (                                                                                           -- 公共表表达式：开启中间结果集 half，其后各行为其定义体（交付件 S03_agent_score.csv）
  SELECT lv3, member_id,                                                                            -- 取列：起始取列子句，本行先列 lv3, member_id，涉 member_id（会员号）、lv3（三级代理线）
         MAX(CASE WHEN bet_date <  '2026-05-30' THEN 1 ELSE 0 END) AS in_h1,                        -- 取最大值表达式：取用 bet_date（营业日），产出「in_h1」
         MAX(CASE WHEN bet_date >= '2026-05-30' THEN 1 ELSE 0 END) AS in_h2                         -- 取最大值表达式：取用 bet_date（营业日），产出「in_h2」
  FROM bs WHERE NULLIF(TRIM(lv3),'') IS NOT NULL                                                    -- 取数来源：取自本条自建的中间结果集 bs
  GROUP BY lv3, member_id                                                                           -- 分组：按 lv3, member_id 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
ret AS (                                                                                            -- 公共表表达式：开启中间结果集 ret，其后各行为其定义体（交付件 S03_agent_score.csv）
  SELECT lv3,                                                                                       -- 取列：起始取列子句，本行先列 lv3，涉 lv3（三级代理线）
         SUM(CASE WHEN in_h1 = 1 AND in_h2 = 1 THEN 1 ELSE 0 END) * 1.0                             -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
           / NULLIF(SUM(in_h1), 0) AS 下线留存                                                          -- 除法或乘法计算：汇总，取用下线留存（代理雷达赏侧维），产出「下线留存」
  FROM half GROUP BY lv3                                                                            -- 取数来源：取自本条自建的中间结果集 half
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
/* ── 扩编维度② 新增会员质量 ─────────────────────────────────────
   只看「窗口内才首次下注」的会员，算其人均净贡献（平台口径，取负号）。
   这一维把「拉人头」与「拉客人」区分开：新增数量高但人均净贡献接近零
   甚至为负，说明拉来的是刷返水的号，不是客人。赏罚方向为「赏」。 */
newm AS (                                                                                           -- 公共表表达式：开启中间结果集 newm，其后各行为其定义体（交付件 S03_agent_score.csv）
  SELECT lv3, member_id,                                                                            -- 取列：起始取列子句，本行先列 lv3, member_id，涉 member_id（会员号）、lv3（三级代理线）
         MIN(bet_date) AS first_date,                                                               -- 取最小值表达式：取用 bet_date（营业日），产出「first_date」
         -SUM(net_pnl) AS 平台净得                                                                      -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「平台净得」
  FROM bs WHERE NULLIF(TRIM(lv3),'') IS NOT NULL                                                    -- 取数来源：取自本条自建的中间结果集 bs
  GROUP BY lv3, member_id                                                                           -- 分组：按 lv3, member_id 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
nq AS (                                                                                             -- 公共表表达式：开启中间结果集 nq，其后各行为其定义体（交付件 S03_agent_score.csv）
  SELECT lv3,                                                                                       -- 取列：起始取列子句，本行先列 lv3，涉 lv3（三级代理线）
         AVG(平台净得) AS 新增会员质量,                                                                       -- 求均值表达式：取用新增会员质量（代理雷达赏侧维），产出「新增会员质量」
         COUNT(*)      AS n_new_member                                                              -- 计数表达式：产出「n_new_member」
  FROM newm WHERE first_date >= '2026-04-20'   -- 窗口首 30 天之后才首注，视为新增
  GROUP BY lv3                                                                                      -- 分组：按 lv3 汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 S03_agent_score.csv）
SELECT b.lv3,                                                                                       -- 取列：起始取列子句，本行先列 b.lv3，涉 lv3（三级代理线）
  COUNT(DISTINCT b.member_id) AS 线下规模,                                                              -- 计数表达式：统计去重个数，产出「线下规模」
  SUM(b.valid_bet) AS 真实流水,                                                                         -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、真实流水（代理雷达赏侧维），产出「真实流水」
  SUM(b.rebate)    AS 退水支出,                                                                         -- 汇总表达式：取用 rebate（退水）、退水支出（退水成本），产出「退水支出」
  SUM(b.game_pnl)  AS 链下游戏输赢,                                                                       -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「链下游戏输赢」
  SUM(b.rebate)/NULLIF(-SUM(b.game_pnl),0) AS 退水消耗比,  -- >1 = 退水吃光赢利
  -- ★ 扩编两列：报告的代理雷达按列名取用，列名一字不可改
  MAX(r.下线留存)      AS 下线留存,                                                                         -- 取最大值表达式：取用下线留存（代理雷达赏侧维），产出「下线留存」
  MAX(n.新增会员质量)  AS 新增会员质量,                                                                         -- 取最大值表达式：取用新增会员质量（代理雷达赏侧维），产出「新增会员质量」
  MAX(n.n_new_member)  AS 新增会员数                                                                     -- 取最大值表达式：产出「新增会员数」
FROM bs b                                                                                           -- 取数来源：取自本条自建的中间结果集 bs
LEFT JOIN ret r ON r.lv3 = b.lv3                                                                    -- 左连接：取自本条自建的中间结果集 ret，连接键为 lv3（三级代理线）
LEFT JOIN nq  n ON n.lv3 = b.lv3                                                                    -- 左连接：取自本条自建的中间结果集 nq，连接键为 lv3（三级代理线）
WHERE NULLIF(TRIM(b.lv3),'') IS NOT NULL                                                            -- 过滤条件：限定该值非空，涉 lv3（三级代理线）
GROUP BY b.lv3 ORDER BY 真实流水 DESC;                                                                  -- 分组：按 b.lv3 ORDER BY 真实流水（降序）汇总


/* ╔══════════════════════════════════════════════════════════════════════╗
   ║  ⛔ S-04a 已被取代 —— 请勿导出，请改跑 卷二 §S04p                      ║
   ╠══════════════════════════════════════════════════════════════════════╣
   ║  取代原因：S-04a 输出的是 IP 明细（17 行，一行一个 IP），而风控员雷达  ║
   ║  需要的是「一行一位风控员」的实体级聚合。两条同写                      ║
   ║  「数据库/S04_analyst_score.csv」，后跑者覆盖先跑者——                  ║
   ║  若误跑本条，风控员雷达将拿不到实体级维度，退化为结构演示。            ║
   ║  S-04b（标注人产量汇总）仍可用，看屏幕即可，不必导出。                 ║
   ╚══════════════════════════════════════════════════════════════════════╝ */

/* ═══════════════════════════════════════════════════════════════════════
   S-04 · 风控员评分底料（金标准名单产出者）
   命中率/时效由 Python 侧对回 N1/N1b 结果计算；导出 数据库/S04_analyst_score.csv
   ▸ 导出：⛔ 已摘除，本条不再产出任何交付件——正版请跑 §S04p
   ▸ 用途：★ 风控员评分雷达 + 综合分
   ═══════════════════════════════════════════════════════════════════════ */
/* ✅ 字段已实测确认（2026-08-06 全表 17 行到手）：
--   ⛔ 【已于 2026-08-09 摘除 · S-04a 风控员 IP 明细】原 SQL 10 行。缘由：已被 §S04p 取代（S-04a 输出 IP 明细 17 行，风控员雷达需实体级聚合；误跑会覆盖正版输出）。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。

/* ── S-04b · 标注人产量汇总（可选，看一眼即可，无需导出）───────────
   实测结果：mao 6 / wmdn08 4 / Annie 3 / livegame 2 / wmdn10 1 / wmdn01 1 */
-- ▸ 导出：不需要 —— S-04b 屏幕汇总（标注人产量），看一眼即可。
SELECT creator AS 标注人, COUNT(*) AS 标注产量,                                                            -- 取列：起始取列子句，本行先取「标注产量」
       SUM(CASE WHEN NULLIF(TRIM(remarks),'') IS NULL THEN 1 ELSE 0 END) AS 理由空白数,                  -- 汇总表达式：产出「理由空白数」
       MIN(addtime) AS 首次标注, MAX(addtime) AS 末次标注                                                   -- 取最小值表达式：取最大值，产出「末次标注」
FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                                       -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
GROUP BY creator ORDER BY 标注产量 DESC;                                                                -- 分组：按 creator ORDER BY 标注产量（降序）汇总


/* ═══════════════════════════════════════════════════════════════════════
   S-05 · 会员×月评分面板（净化滚动回测的输入）
   导出 数据库/S05_member_month_panel.csv；risk_label 即 L1a 標籤
   ▸ 导出：「数据库/S05_member_month_panel.csv」
   ▸ 用途：★★ 净化滚动回测面板（模型竞技场唯一输入）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S05_member_month_panel.csv）
rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S05_member_month_panel.csv）
vd AS (                  -- 有效注单：非测试线、非重对、一般注单
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S05_member_month_panel.csv）
bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 S05_member_month_panel.csv）
lab AS (SELECT bet05 AS member_id, DATE_TRUNC('month', dt) AS ym,                                   -- 取值表达式：取用 bet05（会员号）、dt（营业日）、member_id（会员号），产出「ym」
               MAX(CASE WHEN risk='1' THEN 1 ELSE 0 END) AS risk_label                              -- 取最大值表达式：产出「risk_label」
        FROM ods_mariadb_2b.ods_a168_dailyreport_member                                             -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
        GROUP BY bet05, DATE_TRUNC('month', dt))                                                    -- 分组：按 bet05, DATE_TRUNC('month', dt)) 汇总
SELECT b.member_id, DATE_TRUNC('month', b.bet_date) AS bet_date,                                    -- 取列：起始取列子句，本行先取「bet_date」，涉 member_id（会员号）、bet_date（营业日）
  SUM(b.valid_bet) AS 流水贡献, -SUM(b.game_pnl) AS 游戏输赢贡献,                                             -- 汇总表达式：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「游戏输赢贡献」
  COUNT(DISTINCT b.bet_date) AS 活跃稳定, SUM(b.rebate) AS 退水支出,                                        -- 计数表达式：统计去重个数，产出「退水支出」
  COUNT(DISTINCT b.bet_ip) AS n_ip, COUNT(DISTINCT b.lv3) AS n_chain,                               -- 计数表达式：统计去重个数，产出「n_chain」
  MIN(b.round_key) AS round_key,                                                                    -- 取最小值表达式：取用 round_key（局键），产出「round_key」
  COALESCE(MAX(l.risk_label),0) AS risk_label                                                       -- 取值表达式：取最大值，产出「risk_label」
FROM bs b LEFT JOIN lab l                                                                           -- 取数来源：取自本条自建的中间结果集 bs
  ON l.member_id=b.member_id AND l.ym=DATE_TRUNC('month', b.bet_date)                               -- 连接键：限定 l.member_id等于 b.member_id，涉 member_id（会员号）、bet_date（营业日）
GROUP BY b.member_id, DATE_TRUNC('month', b.bet_date)                                               -- 分组：按 b.member_id, DATE_TRUNC('month', b.bet_date) 汇总
HAVING COUNT(*) >= 30                                                                               -- 分组后过滤：限定行数不少于 30
ORDER BY b.member_id, bet_date;                                                                     -- 排序：按 b.member_id, bet_date 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   V2 · game_No 位数核验 → ✅ 已跑（2026-08-06）
   实测 7/7/7/152,416 → 与 bet03(9位)不符，该表已关闭
   ▸ 导出：不需要 —— 已跑完，结论存档，无需重跑
   ═══════════════════════════════════════════════════════════════════════ */
--   ⛔ 【已于 2026-08-09 摘除 · COUNT-05 一次性普查】原 SQL 3 行。缘由：已跑完，结论存档，无需重跑。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。

/* ═══════════════════════════════════════════════════════════════════════
   C-02 · IP 汇总 · 三版本盈利口径（版本C 剔退水为主口径）
   报告 fetch("I_ip_agg") 缺口补齐；最小订单 30
   ▸ 导出：「数据库/I_ip_agg.csv」
   ▸ 用途：§4.2 三版本对照与阈值网格
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_agg.csv）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（交付件 I_ip_agg.csv）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_agg.csv）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（交付件 I_ip_agg.csv）
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_agg.csv）
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体（交付件 I_ip_agg.csv）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_agg.csv）
pl AS (SELECT member_id, COUNT(*) AS n_orders_all,                                                  -- 取值表达式：计数，取用 member_id（会员号），产出「n_orders_all」
              SUM(net_pnl) AS net_pnl_all, SUM(game_pnl) AS game_pnl_all                            -- 汇总表达式：取用 net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「game_pnl_all」
       FROM bs GROUP BY member_id),                                                                 -- 取数来源：取自本条自建的中间结果集 bs
ipm AS (SELECT b.bet_ip, b.member_id, COUNT(*) AS n_orders_ip,                                      -- 取值表达式：计数，取用 bet_ip（下注 IP）、member_id（会员号），产出「n_orders_ip」
               COUNT(DISTINCT b.round_key) AS n_rounds_ip,                                          -- 计数表达式：统计去重个数，产出「n_rounds_ip」
               SUM(b.stake) AS stake_ip, SUM(b.net_pnl) AS net_pnl_ip,                              -- 汇总表达式：取用 stake（下注额（经汇率归一化））、net_pnl（会员净输赢），产出「net_pnl_ip」
               SUM(b.game_pnl) AS game_pnl_ip,                                                      -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl_ip」
               MAX(p.net_pnl_all) AS net_pnl_all, MAX(p.game_pnl_all) AS game_pnl_all,              -- 取最大值表达式：产出「game_pnl_all」
               COUNT(*)*1.0/NULLIF(MAX(p.n_orders_all),0) AS ip_order_share                         -- 计数表达式：取最大值，产出「ip_order_share」
        FROM bs b JOIN pl p ON p.member_id=b.member_id                                              -- 取数来源：取自本条自建的中间结果集 bs，连接键为 member_id（会员号）
        WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL                                                 -- 过滤条件：限定该值非空，涉 bet_ip（下注 IP）
        GROUP BY b.bet_ip, b.member_id)                                                             -- 分组：按 b.bet_ip, b.member_id) 汇总
SELECT 'W1' AS window_id, bet_ip,                                                                   -- 取列：起始取列子句，本行先取「window_id」，涉 bet_ip（下注 IP）
  COUNT(*) AS n_member_raw,                                                                         -- 计数表达式：产出「n_member_raw」
  SUM(CASE WHEN n_orders_ip>=30 THEN 1 ELSE 0 END) AS n_member_eff,                                 -- 汇总表达式：产出「n_member_eff」
  SUM(CASE WHEN n_orders_ip>=30 AND net_pnl_all>0 THEN 1 ELSE 0 END) AS n_prof_A,                   -- 汇总表达式：产出「n_prof_A」
  SUM(CASE WHEN n_orders_ip>=30 AND net_pnl_ip >0 THEN 1 ELSE 0 END) AS n_prof_B,                   -- 汇总表达式：产出「n_prof_B」
  SUM(CASE WHEN n_orders_ip>=30 AND game_pnl_ip>0 THEN 1 ELSE 0 END) AS n_prof_C,                   -- 汇总表达式：产出「n_prof_C」
  SUM(n_orders_ip) AS n_orders, SUM(n_rounds_ip) AS n_rounds,                                       -- 汇总表达式：产出「n_rounds」
  SUM(stake_ip) AS stake, SUM(net_pnl_ip) AS net_pnl, SUM(game_pnl_ip) AS game_pnl,                 -- 汇总表达式：取用 stake（下注额（经汇率归一化））、net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「game_pnl」
  PERCENTILE_APPROX(ip_order_share,0.5) AS share_p50,                                               -- 取近似分位数表达式：产出「share_p50」
  PERCENTILE_APPROX(ip_order_share,0.9) AS share_p90                                                -- 取近似分位数表达式：产出「share_p90」
FROM ipm GROUP BY bet_ip                                                                            -- 取数来源：取自本条自建的中间结果集 ipm
HAVING SUM(CASE WHEN n_orders_ip>=30 THEN 1 ELSE 0 END) >= 5                                        -- 分组后过滤：限定 SUM(CASE WHEN n_orders_ip不少于 30 THEN 1 ELSE 0 END) >= 5
ORDER BY n_member_eff DESC;                                                                         -- 排序：按 n_member_eff（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

/* ═══════════════════════════════════════════════════════════════════════
   X-01 · 两规则组合矩阵（异常IP × 尾注；尾注侧仅作画像）
   报告 fetch("X_combo") 缺口补齐
   ▸ 导出：「数据库/X_combo.csv」
   ▸ 用途：§6 两规则重叠与增量分析
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 X_combo.csv）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（交付件 X_combo.csv）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 X_combo.csv）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（交付件 X_combo.csv）
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 X_combo.csv）
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体（交付件 X_combo.csv）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 X_combo.csv）
gi AS (SELECT CONCAT_WS('|', gi002, gi003, gi011) AS round_key,                                     -- 取值表达式：取用 gi011（桌号）、round_key（局键），产出「round_key」
              gi004 AS t_open, gi006 AS t_reveal                                                    -- 取值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「t_reveal」
       FROM ods_mariadb_2b.ods_a168_game_info                                                       -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
       WHERE gi001='101' AND gi013='1' AND is_lock='N'                                              -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'、is_lock等于 'N'，涉 gi001（局主键）
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),                                           -- 并列条件：限定 gi004不少于 '2026-03-21'，涉 gi004（局开始时刻）
pr AS (SELECT b.member_id, b.bet_ip, b.valid_bet, b.game_pnl,                                       -- 取值表达式：取用 valid_bet（有效投注（洗码量））、bet_ip（下注 IP）、game_pnl（游戏净输赢）
              (UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))*1.0                                -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
              /NULLIF(UNIX_TIMESTAMP(g.t_reveal)-UNIX_TIMESTAMP(g.t_open),0) AS progress            -- 除法或乘法计算：产出「progress」
       FROM bs b JOIN gi g ON g.round_key=b.round_key),                                             -- 取数来源：取自本条自建的中间结果集 bs，连接键为 round_key（局键）
ipn AS (SELECT bet_ip, COUNT(DISTINCT member_id) AS n_member_ip                                     -- 取值表达式：统计去重个数，产出「n_member_ip」
        FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL GROUP BY bet_ip),                         -- 取数来源：取自本条自建的中间结果集 bs
mk AS (SELECT p.member_id,                                                                          -- 取值表达式：取用 member_id（会员号）
         MAX(CASE WHEN i.n_member_ip >= 20 THEN 1 ELSE 0 END) AS flag_ip,                           -- 取最大值表达式：产出「flag_ip」
         SUM(CASE WHEN p.progress>=0.90 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS tail_share,              -- 汇总表达式：计数，产出「tail_share」
         SUM(p.valid_bet) AS valid_bet, SUM(p.game_pnl) AS game_pnl                                 -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「game_pnl」
       FROM pr p LEFT JOIN ipn i ON i.bet_ip=p.bet_ip                                               -- 取数来源：取自本条自建的中间结果集 pr，连接键为 bet_ip（下注 IP）
       WHERE p.progress BETWEEN 0 AND 1.5                                                           -- 过滤条件：限定落入闭区间
       GROUP BY p.member_id HAVING COUNT(*) >= 30)                                                  -- 分组：按 p.member_id HAVING COUNT(*) >= 30) 汇总
SELECT flag_ip,                                                                                     -- 取列：起始取列子句，本行先列 flag_ip
       CASE WHEN tail_share>=0.47 THEN 1 ELSE 0 END AS flag_tail_p90,                               -- 条件分支：产出「flag_tail_p90」
       COUNT(*) AS n_member, SUM(valid_bet) AS valid_bet,                                           -- 计数表达式：汇总，取用 valid_bet（有效投注（洗码量））、n_member（会员数），产出「valid_bet」
       SUM(game_pnl) AS game_pnl,                                                                   -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
       SUM(game_pnl)/NULLIF(SUM(valid_bet),0) AS roi                                                -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「roi」
FROM mk GROUP BY 1,2 ORDER BY 1 DESC,2 DESC;                                                        -- 取数来源：取自本条自建的中间结果集 mk

/* ═══════════════════════════════════════════════════════════════════════
   P-01 · 会员×月面板（跨月持续性；与 S-05 同源不同粒度）
   报告 fetch("P_player_month") 缺口补齐
   ▸ 导出：「数据库/P_player_month.csv」
   ▸ 用途：@sec-persist 跨月稳定性检验
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 P_player_month.csv）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（交付件 P_player_month.csv）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 P_player_month.csv）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（交付件 P_player_month.csv）
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 P_player_month.csv）
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体（交付件 P_player_month.csv）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号（交付件 P_player_month.csv）
SELECT member_id, DATE_TRUNC('month', bet_date) AS ym,                                              -- 取列：起始取列子句，本行先取「ym」，涉 member_id（会员号）、bet_date（营业日）
  COUNT(DISTINCT round_key) AS n_rounds, COUNT(DISTINCT bet_date) AS n_days,                        -- 计数表达式：统计去重个数，产出「n_days」
  SUM(valid_bet) AS valid_bet, SUM(game_pnl) AS game_pnl,                                           -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「game_pnl」
  SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,                                                   -- 汇总表达式：取用 net_pnl（会员净输赢）、rebate（退水），产出「net_pnl」
  SUM(game_pnl)/NULLIF(SUM(valid_bet),0) AS roi                                                     -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「roi」
FROM bs GROUP BY member_id, DATE_TRUNC('month', bet_date)                                           -- 取数来源：取自本条自建的中间结果集 bs
HAVING COUNT(DISTINCT round_key) >= 30                                                              -- 分组后过滤：限定 round_key 的去重个数不少于 30，涉 round_key（局键）
ORDER BY member_id, ym;                                                                             -- 排序：按 member_id, ym 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

/* ═══════════════════════════════════════════════════════════════════════
   B-01 · 在线人数基准（「第29秒」悖论的分母）
   报告 fetch("B_online_base") 缺口补齐
   ▸ 导出：「数据库/B_online_base.csv」
   ▸ 用途：§2.2-4 秒段集中度须除以在场人数基准
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 B_online_base.csv）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（交付件 B_online_base.csv）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 B_online_base.csv）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（交付件 B_online_base.csv）
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 B_online_base.csv）
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体（交付件 B_online_base.csv）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 B_online_base.csv）
gi AS (SELECT CONCAT_WS('|', gi002, gi003, gi011) AS round_key,                                     -- 取值表达式：取用 gi011（桌号）、round_key（局键），产出「round_key」
              gi004 AS t_open, gi006 AS t_reveal                                                    -- 取值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「t_reveal」
       FROM ods_mariadb_2b.ods_a168_game_info                                                       -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
       WHERE gi001='101' AND gi013='1' AND is_lock='N'                                              -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'、is_lock等于 'N'，涉 gi001（局主键）
         AND gi004>='2026-03-21' AND gi004<'2026-08-07'),                                           -- 并列条件：限定 gi004不少于 '2026-03-21'，涉 gi004（局开始时刻）
pr AS (SELECT b.table_id, b.round_key, b.member_id, b.valid_bet, b.game_pnl,                        -- 取值表达式：取用 valid_bet（有效投注（洗码量））、round_key（局键）、game_pnl（游戏净输赢）
              FLOOR((UNIX_TIMESTAMP(b.t_bet)-UNIX_TIMESTAMP(g.t_open))) AS sec_elapsed              -- 取值表达式：产出「sec_elapsed」
       FROM bs b JOIN gi g ON g.round_key=b.round_key)                                              -- 取数来源：取自本条自建的中间结果集 bs，连接键为 round_key（局键）
SELECT table_id, sec_elapsed,                                                                       -- 取列：起始取列子句，本行先列 table_id, sec_elapsed
       COUNT(*) AS n_orders, COUNT(DISTINCT member_id) AS n_player,                                 -- 计数表达式：统计去重个数，产出「n_player」
       COUNT(DISTINCT round_key) AS n_rounds,                                                       -- 计数表达式：统计去重个数，产出「n_rounds」
       SUM(valid_bet) AS valid_bet, SUM(game_pnl) AS game_pnl                                       -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「game_pnl」
FROM pr WHERE sec_elapsed BETWEEN 0 AND 120                                                         -- 取数来源：取自本条自建的中间结果集 pr
GROUP BY table_id, sec_elapsed ORDER BY table_id, sec_elapsed;                                      -- 分组：按 table_id, sec_elapsed ORDER BY table_id, sec_elapsed 汇总

/* ═══════════════════════════════════════════════════════════════════════
   A-01 · L0 金标准锚点（17 个人工确认 IP 的窗口内表现）
   报告 fetch("A_anchor") 缺口补齐；须先跑 N1b 确认活跃性
   ▸ 导出：「数据库/A_anchor.csv」
   ▸ 用途：一票否决检验：新阈值必须命中这些锚点
   ═══════════════════════════════════════════════════════════════════════ */
WITH gold AS (SELECT DISTINCT TRIM(ip) AS ip                                                        -- 公共表表达式：产出「ip」
              FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                         -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
              WHERE NULLIF(TRIM(ip),'') IS NOT NULL)                                                -- 过滤条件：限定该值非空
SELECT g.ip,                                                                                        -- 取列：起始取列子句，本行先列 g.ip
       COUNT(b.bet01) AS n_orders,                                                                  -- 计数表达式：产出「n_orders」
       COUNT(DISTINCT b.bet05) AS n_member,                                                         -- 计数表达式：统计去重个数，产出「n_member」
       MIN(b.dt) AS first_dt, MAX(b.dt) AS last_dt                                                  -- 取最小值表达式：取最大值，取用 dt（营业日），产出「last_dt」
FROM gold g                                                                                         -- 取数来源：取自本条自建的中间结果集 gold
LEFT JOIN ods_mariadb_2b.ods_a168_bet02 b                                                           -- 左连接：取自注单明细表（金额与行为口径的第一料源）
  ON TRIM(b.ip)=g.ip AND b.dt>='2026-03-21' AND b.dt<'2026-08-07' AND b.bet02='101'                 -- 连接键：限定 TRIM(b.ip)等于 g.ip、b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
GROUP BY g.ip ORDER BY n_orders DESC;                                                               -- 分组：按 g.ip ORDER BY n_orders（降序）汇总

/* ═══════════════════════════════════════════════════════════════════════
   V-01 · 三方 IP 明细对照（地理维度作废的存档证据）
   报告 fetch("V_ipmatch") 缺口补齐
   ▸ 导出：「数据库/V_ipmatch.csv」
   ▸ 用途：game_log.ip 为网关的逐条证据
   ═══════════════════════════════════════════════════════════════════════ */
WITH a AS (SELECT DISTINCT TRIM(ip) AS ip FROM ods_mariadb_2b.ods_a168_bet02                        -- 公共表表达式：取用注单明细表（金额与行为口径的第一料源），产出「ip」
           WHERE dt>='2026-03-21' AND dt<'2026-08-07' AND bet02='101'                               -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'、bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
             AND NULLIF(TRIM(ip),'') IS NOT NULL),                                                  -- 并列条件：限定该值非空
     b AS (SELECT TRIM(ip) AS ip, COUNT(DISTINCT mid) AS n_member_log,                              -- 取值表达式：统计去重个数，产出「n_member_log」
                  MAX(country_code) AS country, MAX(city) AS city                                   -- 取最大值表达式：产出「city」
           FROM ods_mariadb_2b.ods_a168_game_log                                                    -- 取数来源：取自局流水日志（局级过程记录）
           WHERE dt>='2026-03-21' AND dt<'2026-08-07'                                               -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
             AND NULLIF(TRIM(ip),'') IS NOT NULL                                                    -- 并列条件：限定该值非空
           GROUP BY TRIM(ip))                                                                       -- 分组：按 TRIM(ip)) 汇总
SELECT b.ip, b.n_member_log, b.country, b.city,                                                     -- 取列：起始取列子句，本行先列 b.ip, b.n_member_log, b.country, b.city
       CASE WHEN a.ip IS NULL THEN 0 ELSE 1 END AS in_bet_ip                                        -- 条件分支：产出「in_bet_ip」
FROM b LEFT JOIN a ON a.ip=b.ip                                                                     -- 取数来源：取自本条自建的中间结果集 b，连接键为 a.ip=b.ip
ORDER BY b.n_member_log DESC;                                                                       -- 排序：按 b.n_member_log（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ╔═══════════════════════════════════════════════════════════════════════╗
   ║  §08 · 分批下载工具组（先数行数，再决定要不要分批）                      ║
   ╚═══════════════════════════════════════════════════════════════════════╝
   为什么必须先数：Superset 单次导出有上限，超限会**静默截断**（只给你前
   N 行，不报错）。之前 277 批数据出现 36.49% 重复，根因就是分页时
   **没有稳定排序**——同一行被翻到两页里。本组工具解决这两件事。

   ★★ 分页铁律 ★★
   ① 排序键必须**唯一**。按「流水贡献」排序会有并列值，翻页时行会跳动、
      重复或漏掉。分批下载时**一律改用 member_id 排序**（唯一主键）。
   ② 优先用「游标翻页」（COUNT-08b）而非 OFFSET：
      OFFSET 100000 要求引擎先算完前 10 万行再丢掉，越翻越慢；
      游标翻页每次都走索引，第 1 批和第 50 批一样快。
   ③ 每批导出后核对行数，最后一批合并时用 member_id 去重复核。
*/

/* ═══════════════════════════════════════════════════════════════════════
   COUNT-01 · 五份评分底料的观测值总数（一次跑完，5 个数字全出）
   ▸ 导出：不需要 —— 屏幕看结果即可（返回 1 行 5 列）
   ▸ 用途：决定每份要不要分批、分几批
   ▸ 耗时：约 1–3 分钟（要扫全量注单）
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.dt AS bet_date,                                                          -- 取值表达式：取用 bet20（三级代理线）、dt（营业日）、bet_date（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号
/* ★ 提速改写：原版五个标量子查询各自引用 bs——若优化器未启用 CTE 复用，
   整条 1.9 亿行去重流水线会被执行五遍。现改为 GROUPING SETS 单扫：
   一遍扫描同时产出 会员级 / 会员×月级 / 全局级 三层聚合，
   再对这张小结果表做一次条件汇总。五个输出数字与原版逐一相同。 */
g AS (                                                                                              -- 公共表表达式：开启中间结果集 g，其后各行为其定义体
  SELECT GROUPING(member_id) AS g_m,                                                                -- 取列：起始取列子句，本行先取「g_m」，涉 member_id（会员号）
         GROUPING(ym)        AS g_ym,                                                               -- 取值表达式：产出「g_ym」
         member_id, ym,                                                                             -- 续行：接续上一取列子句，续列 member_id, ym，涉 member_id（会员号）
         COUNT(*)                        AS n_rows,                                                 -- 计数表达式：产出「n_rows」
         COUNT(DISTINCT round_key)       AS n_rounds,                                               -- 计数表达式：统计去重个数，产出「n_rounds」
         COUNT(DISTINCT CASE WHEN NULLIF(TRIM(dealer_id),'') IS NOT NULL                            -- 计数表达式：统计去重个数
                             THEN dealer_id END) AS n_dealer,                                       -- 分支取值：取用 dealer_id（荷官工号），产出「n_dealer」
         COUNT(DISTINCT CASE WHEN NULLIF(TRIM(lv3),'') IS NOT NULL                                  -- 计数表达式：统计去重个数
                             THEN lv3 END)       AS n_lv3,                                          -- 分支取值：取用 lv3（三级代理线），产出「n_lv3」
         COUNT(DISTINCT member_id)       AS n_member                                                -- 计数表达式：统计去重个数，产出「n_member」
  FROM (SELECT member_id, dealer_id, lv3, round_key,                                                -- 取数来源：以内联子查询为来源，先在括号内算出中间结果，再供外层取用
               DATE_TRUNC('month', bet_date) AS ym                                                  -- 取值表达式：取用 bet_date（营业日），产出「ym」
        FROM bs) t                                                                                  -- 取数来源：取自本条自建的中间结果集 bs
  GROUP BY GROUPING SETS ((member_id), (member_id, ym), ())                                         -- 分组：按 GROUPING SETS ((member_id), (member_id, ym), ()) 汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  /* S-01 玩家：满 30 局的会员数（会员级切片） */
  SUM(CASE WHEN g_m = 0 AND g_ym = 1 AND n_rounds >= 30 THEN 1 ELSE 0 END)                          -- 汇总表达式：承接上一子句，构成完整语句
                                                               AS n_S01_玩家,                         -- 取值表达式：产出「n_S01_玩家」
  /* S-02 荷官：有注单的荷官数（全局切片） */
  MAX(CASE WHEN g_m = 1 AND g_ym = 1 THEN n_dealer END)        AS n_S02_荷官,                         -- 取最大值表达式：产出「n_S02_荷官」
  /* S-03 代理：有注单的 LV3 代理线数（全局切片） */
  MAX(CASE WHEN g_m = 1 AND g_ym = 1 THEN n_lv3 END)           AS n_S03_代理,                         -- 取最大值表达式：产出「n_S03_代理」
  /* S-05 面板：会员×月 且行数≥30 的组合数（会员×月切片） */
  SUM(CASE WHEN g_m = 0 AND g_ym = 0 AND n_rows >= 30 THEN 1 ELSE 0 END)                            -- 汇总表达式：承接上一子句，构成完整语句
                                                               AS n_S05_会员月,                        -- 取值表达式：产出「n_S05_会员月」
  /* 参考：窗口内下注会员总数（全局切片，未过滤 30 局） */
  MAX(CASE WHEN g_m = 1 AND g_ym = 1 THEN n_member END)        AS n_会员总数                            -- 取最大值表达式：取用 n_member（会员数），产出「n_会员总数」
FROM g;                                                                                             -- 取数来源：取自本条自建的中间结果集 g

/* 判读：
     任何一个数 ≤ 100,000  → 该份直接一次导出，不必分批；
     100,000 < 数 ≤ 500,000 → 用 COUNT-08b 游标翻页，每批 10 万；
     > 500,000              → 先考虑收紧 HAVING 门槛（如 >=50 局），
                              样本量够用即可，不必全量落地。
   S-04（风控员）来自 alert_ip_setting，全表仅 17 条，永远不用分批。 */


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-02 · 单份精确计数模板（想单独数某一份时用）
   ▸ 导出：不需要
   ▸ 用法：把 §06 里对应查询的最终 SELECT 换成 COUNT(*) 包一层即可
   ═══════════════════════════════════════════════════════════════════════ */
-- 例：只数 S-01 玩家数
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.dt AS bet_date,                                                          -- 取值表达式：取用 bet20（三级代理线）、dt（营业日）、bet_date（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT COUNT(*) AS n_rows FROM (                                                                    -- 取列：计数，产出「n_rows」
  SELECT member_id FROM bs GROUP BY member_id                                                       -- 取列：取用 member_id（会员号）
  HAVING COUNT(DISTINCT round_key) >= 30                                                            -- 分组后过滤：限定 round_key 的去重个数不少于 30，涉 round_key（局键）
) t;                                                                                                -- 续行：承接上一子句，构成完整语句


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-08a · 分批方案 A：会员号区间切分（推荐 · 最稳）
   ▸ 用途：先看会员号怎么分布，再按号段切，每段约 10 万人
   ▸ 优点：每批条件互斥且完备，绝不会重复也不会漏
   ═══════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— COUNT-08a 屏幕结果（会员号切点），切点抄下来填回被分批的那条查询。
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体
  SELECT r.* FROM rk r                                                                              -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.dt AS bet_date,                                                          -- 取值表达式：取用 bet20（三级代理线）、dt（营业日）、bet_date（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.2) AS 切点_20pct,                                    -- 取近似分位数表达式：取用 member_id（会员号），产出「切点_20pct」
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.4) AS 切点_40pct,                                    -- 取近似分位数表达式：取用 member_id（会员号），产出「切点_40pct」
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.6) AS 切点_60pct,                                    -- 取近似分位数表达式：取用 member_id（会员号），产出「切点_60pct」
  PERCENTILE_APPROX(CAST(member_id AS BIGINT), 0.8) AS 切点_80pct,                                    -- 取近似分位数表达式：取用 member_id（会员号），产出「切点_80pct」
  MIN(CAST(member_id AS BIGINT)) AS 最小会员号,                                                          -- 取最小值表达式：取用 member_id（会员号），产出「最小会员号」
  MAX(CAST(member_id AS BIGINT)) AS 最大会员号                                                           -- 取最大值表达式：取用 member_id（会员号），产出「最大会员号」
FROM (SELECT member_id FROM bs GROUP BY member_id                                                   -- 取数来源：以内联子查询为来源，先在括号内算出中间结果，再供外层取用
      HAVING COUNT(DISTINCT round_key) >= 30) t;                                                    -- 分组后过滤：限定 round_key 的去重个数不少于 30) t，涉 round_key（局键）

/* 拿到 4 个切点后，把 S-01 查询的末尾改成（以第 1 批为例）：
     GROUP BY b.member_id
     HAVING COUNT(DISTINCT b.round_key) >= 30
        AND CAST(b.member_id AS BIGINT) < 【切点_20pct】
     ORDER BY CAST(b.member_id AS BIGINT);
   第 2 批：>= 切点_20pct AND < 切点_40pct，依此类推，共 5 批。
   文件名：S01_player_score_part1.csv … _part5.csv，最后本地合并。 */


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-08b · 分批方案 B：游标翻页（批次多时用，越翻不会越慢）
   ▸ 用途：每次取 10 万，记下本批最后一个会员号，下批从它之后继续
   ═══════════════════════════════════════════════════════════════════════ */
-- 第 1 批：把 0 保持不变
-- 第 2 批：把 0 换成第 1 批结果里最后一行的 member_id
-- 依此类推，直到某批返回不足 100,000 行 = 全部取完
-- ▸ 导出：不需要 —— COUNT-08b 游标翻页模板本身不产出交付件；分批产物一律沿用被分批查询的文件名。
--   ⛔ 【已于 2026-08-09 摘除 · COUNT-08b 游标翻页模板】原 SQL 53 行。缘由：模板本身不产出交付件；分批产物一律沿用被分批查询的文件名。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。


/* ═══════════════════════════════════════════════════════════════════════
   COUNT-09 · 分批合并后的自检（必做，10 秒）
   ▸ 用途：证明分批没有重复、没有漏
   ▸ 在本地（R/Python）跑，不是 SQL
   ═══════════════════════════════════════════════════════════════════════ */
-- R:
--   parts <- list.files("data", "^S01_player_score_part.*csv$", full.names=TRUE)
--   d <- dplyr::bind_rows(lapply(parts, readr::read_csv))
--   stopifnot(nrow(d) == 【COUNT-01 报出的 n_S01_玩家】)          # 没漏
--   stopifnot(!anyDuplicated(d$member_id))                        # 没重
--   readr::write_csv(d, "数据库/S01_player_score.csv")              # 合并落地
-- Python:
--   import glob, pandas as pd
--   d = pd.concat([pd.read_csv(p) for p in glob.glob("数据库/S01_player_score_part*.csv")])
--   assert len(d) == N_EXPECTED and d.member_id.is_unique
--   d.to_csv("数据库/S01_player_score.csv", index=False)

/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  卷二 · v3 增补（规则、经济学、特征矩阵、诊断与切分）                       ║
   ║  原「a168_取数SQL包_v3增补.sql」全量收编                                   ║
   ║  SQL 逻辑一字未改；仅修 §E02c 注释提前终止 1 处。                          ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  卷二与卷一的接续关系：                                                    ║
   ║   · §C06fix 取代 卷一 C-06 —— 对打对名单的唯一有效产出                     ║
   ║   · §S04p   取代 卷一 S-04a —— 风控员雷达的唯一有效产出                    ║
   ║   · §DX-01  是 §C06fix / §R02 / §R03 的前置条件，必先跑                    ║
   ║   · §E02c   取代 §E02 的 commission 恒置 0 版本（κ 已可实算）              ║
   ║   · §R03b   是 §R03 的日粒度版，时序对照图表的唯一输入                     ║
   ╚═══════════════════════════════════════════════════════════════════════════╝ */

/* ───────────────────────────────────────────────────────────────────────────
   §00 · COUNT 预检　一次出 5 个数字，决定要不要切分导出
   用途：任何一份导出前先看它多大。超过 10 万行就按 bet05 区间切分。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：不需要 —— COUNT-09 屏幕自检（分批合并后的行数与去重核对）。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                   AS n_rows_raw,                                         -- 计数表达式：产出「n_rows_raw」
  COUNT(DISTINCT bet01)                      AS n_bet_id,                                           -- 计数表达式：统计去重个数，产出「n_bet_id」
  COUNT(DISTINCT bet05)                      AS n_member,                                           -- 计数表达式：统计唯一会员数（铁律分母，全窗 721,190 人），产出「n_member」
  COUNT(DISTINCT CONCAT_WS('|',bet03,bet04,bet39)) AS n_round,                                      -- 计数表达式：统计去重个数，产出「n_round」
  COUNT(DISTINCT eid)                        AS n_dealer                                            -- 计数表达式：统计去重个数，产出「n_dealer」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND bet02 = '101'                                                                                 -- 并列条件：限定 bet02等于 '101'，涉 bet02（游戏类别）
  AND category = '1'                                                                                -- 并列条件：限定 category等于 '1'
  AND UPPER(TRIM(bet38)) = 'N';                                                                     -- 并列条件：限定 UPPER(TRIM(bet38))等于 'N'，涉 bet38（测试标识）


/* ───────────────────────────────────────────────────────────────────────────
   §00b · 辅助表字段名核对（★ 跑 §E02 / §K01b 之前必做，五秒钟）
   ---------------------------------------------------------------------------
   教训：K-01 首次运行报 `Column 'member_id' cannot be resolved.`，
   根因是 ods_a168_dailyreport_member / ods_a168_alert_ip_setting 的会员列与
   IP 列并不叫 member_id / ip —— 主表 bet02 用 betNN 代号，辅助表各有各的命名。
   本包因此把「一定跑得起来的部分」与「需要先核对列名的部分」彻底分开：
     · §E02 / §K01  —— 只碰 bet02 + agent，**保证跑通**
     · §K01b / §E02c —— 需要辅助表；★ 2026-08-07 列名已实测填实，可直接跑
   下面四条 DESC 各返回十几行，看一眼把真实列名抄下来即可。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：不需要 —— §00b 列名核对（dailyreport_member），屏幕看结果。
--   ⛔ 【已于 2026-08-09 摘除 · §00b 列名核对·dailyreport_member】原 SQL 1 行。缘由：列名已实测填实并写入 §K01b 注释，无须重跑。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
-- 找：会员标识列（可能叫 mem001 / memberid / username / uid）
--     風險單列（risk）、劃單列（orders）、日期列（dt / report_date）

-- ▸ 导出：不需要 —— §00b 列名核对（alert_ip_setting），屏幕看结果。
--   ⛔ 【已于 2026-08-09 摘除 · §00b 列名核对·alert_ip_setting】原 SQL 1 行。缘由：同上。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
-- 找：IP 列（可能叫 ip / alert_ip / ipaddress）、备注列（风控员判定原话）

-- ▸ 导出：不需要 —— §00b 列名核对（member_dtl），屏幕看结果。
--   ⛔ 【已于 2026-08-09 摘除 · §00b 列名核对·member_dtl】原 SQL 1 行。缘由：同上。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
-- 找：会员标识列（doc 记为 mem001）、退水配置列（doc 记为 mem003）

-- ▸ 导出：不需要 —— §00b 列名核对（employee），屏幕看结果。
--   ⛔ 【已于 2026-08-09 摘除 · §00b 列名核对·employee】原 SQL 1 行。缘由：同上。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
-- 找：工号列（与 bet02.eid 对应）、type 列（type=3 为荷官）


/* ───────────────────────────────────────────────────────────────────────────
   §DX · 两条实测教训的诊断查询（2026-08-07 新增：C-06 零结果 + E1-11 语法错）
   ═══════════════════════════════════════════════════════════════════════════
   §DX-01 · bet09 玩法编码到底长什么样 —— ★ 跑本包任何含 hedge 的查询之前必做
   ---------------------------------------------------------------------------
   背景：C-06「同IP对打对」实测 9.3 秒返回 零结果。该查询的判别是
         bet_side IN ('1','B','庄','莊') / ('2','P','闲','閒')。
         零结果的最可能解释不是「本平台没有对打」——@sec-e1-dist 曾记录
         999 对完美对打、最长 1,185 把——而是 bet09 的实际取值不在这份清单里。
   影响面：凡需区分庄/闲之处全部失效，且失效方式是「静默」的：
         判别不匹配 → is_b/is_p 恒为 0 → hedge_rate 恒为 0 → 阈值 P90 也是 0
         → 打水型闸门形同虚设，却不报任何错。这比报错危险得多。
   ★ 2026-08-07 已实测，结果如下（139 天全量 1.256 亿注单，23 种玩法）：
       Banker 4,682万(37.3%) / Player 4,422万(35.2%) / Tie 964万(7.7%)
       边注 20 种合计 2,496万(19.9%)：BPair PPair Super6 Lucky7 SuperLucky7
            PerfectPair BankerDragonBonus PlayerDragonBonus AnyPair Big
            BankerNatural PlayerNatural Small 等
       另有 7 种玩法（Lucky7TwoCard/SuperTie4,5,8,9/SmallTiger/Bear8）
            各仅 1 笔、均在 2026-07-20 —— 判为**上线试跑残留**，一切统计中剔除。
   结论：C-06 零结果的原因确认为**编码不匹配**，不是「平台无对打」。
   ★ 关键陷阱：不能用 LIKE '%BANK%'。它会把 BankerDragonBonus(20.7万笔)
     与 BankerNatural(6.2万笔) 算成庄——那是边注，与主线庄闲不构成对冲。
     本包三处判别已全部改为 **等值匹配 'Banker' / 'Player'**。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：不需要 —— §DX-01 诊断（bet09 实际取值普查），屏幕看结果。
--   ⛔ 【已于 2026-08-09 摘除 · §DX-01 bet09 取值普查】原 SQL 11 行。缘由：已实测结论：bet09 存英文玩法名（Banker/Player），各条已按等值匹配校准，无须重跑。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
/* 读法：按 n_orders 排序，前两名通常就是庄与闲（百家乐庄闲各占约四成）。
   把这两个真实取值填回三处判别（§T03 的 is_b/is_p、§B01 与 §K01 的
   is_self_hedge），以及 C-06 的 side CTE。
   本包已用「LIKE 字母码 OR IN 数字/中文码」的宽口径并集先兜一层；
   若真实取值仍在并集之外（例如 '101'/'102' 这类内部码），必须手动改。
   ★ C-06 修复方法：把它的 side CTE 里的
       bet_side IN ('1','B','庄','莊') → bet_side = 'Banker'
       bet_side IN ('2','P','闲','閒') → bet_side = 'Player'
     改完复跑，对打证据链即可复活。 */


/* ═══════════════════════════════════════════════════════════════════════════
   §DX-02 · 为什么 E1-11 报 Unexpected input 'R_rebate_dist'
   ---------------------------------------------------------------------------
   这是注释写法的问题，不是 SQL 本身的问题。原注释里有这么一行：

       导出：（两个星号）数据库/R_rebate_dist.csv（两个星号）

   块注释的终止符是「星号+斜杠」。上面这行里，两个星号与后面的斜杠之间
   只隔着 CJK 字符。当解析链路（Superset 前端预处理 / 剪贴板 / 编辑器编码）
   任何一环丢失或跳过非 ASCII 字符时，那段就塌缩成「星号+斜杠」，
   注释被提前终止，紧随其后的 R_rebate_dist 便成了语句的第一个 token
   —— 报错信息里那个 token 正是它，这也是本判断的依据。

   固化规则：SQL 注释里禁止出现「连续星号」紧邻「斜杠」的写法。
   本包已把所有 (星号星号)数据库/xxx.csv(星号星号) 统一改写为 「数据库/xxx.csv」。
   ═══════════════════════════════════════════════════════════════════════════
   §DX-03 · 取列定义的通用写法（比 DESC 好用：带列注释与顺序，一条顶三条）
   ▸ 导出：**不需要** —— 屏幕看结果、把列名填回 §E02b / §K01c 即可。
     若要留档，存为「数据库/V_columns_dict.csv」；
     ⛔ 绝不可存为 R_rebate_dist.csv —— 那是 E1-11（退水分布）的专属文件名，
     §DX-02 提到它只因**旧报错信息里的 token 恰是这个词**，与本条输出无关。
     错名不报错，只让报告的退水分布图拿到一张列定义表而静默失真。
   ▸ 实测（2026-08-08）：本条已跑通，68 列定义到手，关键确认已回填全包。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT                         -- 取列：承接上一子句，构成完整语句，属 §E02b 之取数
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 TABLE_SCHEMA等于 'ods_mariadb_2b'
  AND TABLE_NAME IN ('ods_a168_member_dtl',                                                         -- 并列条件：限定落入所列取值，涉会员主档明细（注册与账户属性）
                     'ods_a168_dailyreport_member',                                                 -- 字面取值：取用会员日结报表（日粒度业绩与风控标记）
                     'ods_a168_alert_ip_setting')                                                   -- 字面取值：取用风控 IP 名单配置表（人工标记史料源）
ORDER BY TABLE_NAME, ORDINAL_POSITION;                                                              -- 排序：按 TABLE_NAME, ORDINAL_POSITION 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* 拿到结果即可填回：§E02b 的退水配置列、§K01b 的会员列与 IP 列。
   COLUMN_COMMENT 里常写着中文列义，比靠列名猜可靠得多。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R01 · R01_late_shoe.csv
   策略性风控：靴内第 50 把及之后的下注占比 + 相对靴位 + 注额斜率 + 分段 ROI
   对应报告：@sec-r01
   输出列：uid, n_orders_all, n_orders_late, late_share, shoe_pos_p50,
           stake_late_avg, stake_early_avg, stake_ramp, roi_late, roi_early,
           stake_late, game_pnl_late, stake_all, game_pnl_all
   预期行数：数千 ~ 数万（HAVING 已收敛）
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R01_late_shoe.csv」（§R01 靴末段下注）。
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§R01）
  SELECT age001 AS agent_id                                                                         -- 取列：产出「agent_id」
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档（五级代理线归属来源）
  WHERE age022 = '1'                                  -- 铁律④b：公司测试线
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
ranked AS (                                            -- 需求 §3.2：同单号保留最新版本
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet11, b.bet13,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet11, b.bet13，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet14, b.bet18, b.bet19, b.bet20, b.bet21,                                               -- 续行：接续上一取列子句，续列 b.bet14, b.bet18, b.bet19, b.bet20, b.bet21，涉 bet14（派彩金额）、bet18（一级代理线）、bet19（二级代理线）
         b.bet22, b.bet38, b.bet39, b.category,                                                     -- 续行：接续上一取列子句，续列 b.bet22, b.bet38, b.bet39, b.category，涉 bet22（五级代理线）、bet38（测试标识）、bet39（桌号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                 -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R01）
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id,                                                   -- 取列：起始取列子句，本行先取「member_id」，涉 bet05（会员号）、member_id（会员号）
         r.bet03 AS shoe_id, r.bet39 AS table_id,                                                   -- 取值表达式：取用 bet03（靴号）、bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「round_no」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  /* StarRocks 不支持 EXISTS + 多列 IN，测试线剔除改五路 LEFT JOIN */
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1                                                                                    -- 过滤条件：限定 r.rn等于 1
    AND r.category = '1'                                                                            -- 并列条件：限定 r.category等于 '1'
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：限定 UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0                                                   -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet04),'') AS INT)大于 0，涉 bet04（局内序号）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
shoe_len AS (          -- 缺陷一修正：靴长不定，固定 50 不是固定位置
  SELECT shoe_id, table_id, MAX(round_no) AS max_round                                              -- 取列：取最大值，产出「max_round」
  FROM base GROUP BY shoe_id, table_id                                                              -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
enriched AS (                                                                                       -- 公共表表达式：开启中间结果集 enriched，其后各行为其定义体（§R01）
  SELECT b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round,                               -- 取列：起始取列子句，本行先列 b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round，涉 member_id（会员号）
         b.round_no * 1.0 / NULLIF(s.max_round,0)     AS shoe_pos,                                  -- 取值表达式：产出「shoe_pos」
         b.stake_raw / b.fx                           AS stake,                                     -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (b.payout_raw - b.stake_raw) / b.fx          AS game_pnl,                                  -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         CASE WHEN b.round_no >= 50 THEN 1 ELSE 0 END AS is_late                                    -- 条件分支：产出「is_late」
  FROM base b                                                                                       -- 取数来源：取自本条自建的中间结果集 base
  JOIN shoe_len s ON s.shoe_id = b.shoe_id AND s.table_id = b.table_id                              -- 连接：取自本条自建的中间结果集 shoe_len，连接键为 s.shoe_id = b.shoe_id AND s.table_id = b.table_id
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R01）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  member_id                                                     AS uid,                             -- 取值表达式：取用 member_id（会员号）、uid（会员号），产出「uid」
  COUNT(*)                                                      AS n_orders_all,                    -- 计数表达式：产出「n_orders_all」
  SUM(is_late)                                                  AS n_orders_late,                   -- 汇总表达式：产出「n_orders_late」
  SUM(is_late) * 1.0 / COUNT(*)                                 AS late_share,                      -- 汇总表达式：计数，取用 late_share（晚注占比），产出「late_share」
  PERCENTILE_APPROX(CASE WHEN is_late=1 THEN shoe_pos END, 0.5) AS shoe_pos_p50,                    -- 取近似分位数表达式：产出「shoe_pos_p50」
  SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0)              AS stake_late_avg,  -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_late_avg」
  SUM(CASE WHEN is_late=0 THEN stake END) / NULLIF(COUNT(*)-SUM(is_late),0)     AS stake_early_avg,  -- 汇总表达式：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「stake_early_avg」
  (SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0))                                -- 续行：汇总，取用 stake（下注额（经汇率归一化））
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END)                                                -- 除法或乘法计算：汇总，取用 stake（下注额（经汇率归一化））
             / NULLIF(COUNT(*)-SUM(is_late),0), 0)                              AS stake_ramp,      -- 除法或乘法计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「stake_ramp」
  SUM(CASE WHEN is_late=1 THEN game_pnl END)                                                        -- 汇总表达式：取用 game_pnl（游戏净输赢）
    / NULLIF(SUM(CASE WHEN is_late=1 THEN stake END),0)                         AS roi_late,        -- 除法或乘法计算：汇总，取用 stake（下注额（经汇率归一化）），产出「roi_late」
  SUM(CASE WHEN is_late=0 THEN game_pnl END)                                                        -- 汇总表达式：取用 game_pnl（游戏净输赢）
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END),0)                         AS roi_early,       -- 除法或乘法计算：汇总，取用 stake（下注额（经汇率归一化）），产出「roi_early」
  SUM(CASE WHEN is_late=1 THEN stake END)                                       AS stake_late,      -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_late」
  SUM(CASE WHEN is_late=1 THEN game_pnl END)                                    AS game_pnl_late,   -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl_late」
  SUM(stake)                                                                    AS stake_all,       -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_all」
  SUM(game_pnl)                                                                 AS game_pnl_all     -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl_all」
FROM enriched                                                                                       -- 取数来源：取自本条自建的中间结果集 enriched
GROUP BY member_id                                                                                  -- 分组：按 member_id 汇总
HAVING COUNT(*) >= 100                                    -- 需求：订单数据 > 100 笔
ORDER BY late_share DESC, n_orders_late DESC;                                                       -- 排序：按 late_share（降序）, n_orders_late（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ⚠️ 注意：此处**故意不加** late_share >= 0.70 的 HAVING。
   报告需要「命中组 vs 对照组」的 hold% 对照才能做经济裁定（@sec-r01 的 r01-decision），
   只导命中组就没有对照组。阈值筛选一律放在 R 侧做，SQL 只负责给全量底料。
   若行数过大，改为 HAVING COUNT(*) >= 300 提高活跃度门槛，而不是加 late_share 条件。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R02 · R02_same_table.csv
   团伙同桌：两阶段自连接（先压到会员×物理局并限候选池，再 join）
   对应报告：@sec-r02
   输出列：uid1, uid2, n_same_orders, rounds_1, rounds_2,
           same_rate, jaccard, lift, exp_same, n_tables, first_day, last_day
   ★ 绝不可对 bet02 原表直接自连接：1.9 亿 × 1.9 亿 必然打爆集群。

   ★★ 2026-08-09 降内存斧正（实测触发：BE 单节点用量 107 GB 撞上限而崩）
   ─────────────────────────────────────────────────────────────────────────
   根因不在数据量，在**两处配对的约束强弱悬殊**：
     · pair  的配对约束是 **同一物理局**（round_key），一局数十人，量级尚可控；
     · expct 的配对约束却是 **同一桌 × 同一日**（table_id + bet_date）——
       同桌同日的候选会员可达数千，配对数按其平方增长。
       全窗 27 桌 × 139 日 ≈ 3,753 个桌日，若每桌日 5,000 名候选会员，
       配对数即约 469 亿——比 pair 高出一个数量级，且**其中绝大多数对
       根本不会出现在 pair 里**（同桌同日不等于同局同坐），算了也是白算。

   斧正一（决定性）：**expct 只为 pair 中实际存在的对计算期望**。
     原式先算全组合再 LEFT JOIN 取用，今改为先得 pair、再以其为驱动表
     去 join td/tot。语义逐字不变（E[same] 的定义式未动），
     但配对数由「全组合」降为「pair 对数 × 其共同桌日数」，降幅达数量级。

   斧正二：pair 的 shuffle 倾斜防护。
     热门桌的热门局参与人数远高于均值，按 round_key shuffle 会把巨量配对
     压到单个 BE——本次 107 GB 正是这一形状。故新增 §R02-0 诊断先看分布；
     若确有超热局，按 §R02-1 的桌台分批跑（分批不改语义，只改执行批次）。

   斧正三：act 门槛由 100 提到 300。
     原注释已备此路。候选池是配对数的平方项底数，门槛提三倍，
     配对数约降一个数量级；而 §R02 的判据本就要求同桌 ≥100 笔，
     总局数不足 300 者几无可能构成稳定团伙对。
     ★ 若先生要保留 100 的口径，把下方 act 的 300 改回 100，
       并务必改走 §R02-1 分批模板。
   ─────────────────────────────────────────────────────────────────────────── */

-- ▸ 导出：不需要 —— §R02-0 倾斜诊断（先看每局参与人数分布），屏幕看结果。
--   ★ 跑 §R02 之前必做：若 p999 或 max 远高于中位数，即存在超热局，
--     须改走 §R02-1 分批模板，否则单 BE 必被压垮。
WITH mr0 AS (                                                                                       -- 公共表表达式：开启中间结果集 mr0，其后各行为其定义体（§R02-0）
  SELECT DISTINCT b.bet05 AS member_id,                                                             -- 取列：起始取列子句，本行先取「member_id」，涉 bet05（会员号）、member_id（会员号）
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key                                     -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-08-04' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-08-04'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
    AND UPPER(TRIM(b.bet38)) = 'N'                                                                  -- 并列条件：限定 UPPER(TRIM(b.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02-0）
per_round AS (                                                                                      -- 公共表表达式：开启中间结果集 per_round，其后各行为其定义体（§R02-0）
  SELECT round_key, COUNT(*) AS n_member FROM mr0 GROUP BY round_key                                -- 取列：计数，取用 round_key（局键）、n_member（会员数），产出「n_member」
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R02-0）
SELECT COUNT(*)                                    AS n_rounds,                                     -- 取列：起始取列子句，本行先取「n_rounds」
       AVG(n_member)                               AS avg_member_per_round,                         -- 求均值表达式：取用 n_member（会员数），产出「avg_member_per_round」
       PERCENTILE_APPROX(n_member, 0.50)           AS p50,                                          -- 取近似分位数表达式：取用 n_member（会员数），产出「p50」
       PERCENTILE_APPROX(n_member, 0.90)           AS p90,                                          -- 取近似分位数表达式：取用 n_member（会员数），产出「p90」
       PERCENTILE_APPROX(n_member, 0.999)          AS p999,                                         -- 取近似分位数表达式：取用 n_member（会员数），产出「p999」
       MAX(n_member)                               AS max_member,                                   -- 取最大值表达式：取用 n_member（会员数），产出「max_member」
       SUM(n_member * (n_member - 1) / 2)          AS pair_ops_3d                                   -- 汇总表达式：取用 n_member（会员数），产出「pair_ops_3d」
FROM per_round;                                                                                     -- 取数来源：取自本条自建的中间结果集 per_round
-- 读法：pair_ops_3d 是三日窗内 pair 阶段的配对次数；乘以 46 即全窗量级。
--       若该值逾百亿，即须分批；max_member 若为 p50 的十倍以上，即存在超热局。

-- ▸ 导出：需要 —— 存为「数据库/R02_same_table.csv」（§R02 同桌对 Jaccard / Lift）。
WITH mr AS (                          -- 阶段一：会员 × 物理局，去重后每人每局一行
  SELECT DISTINCT                                                                                   -- 取列：承接上一子句，构成完整语句，属 §R02 之取数
         b.bet05 AS member_id,                                                                      -- 取值表达式：取用 bet05（会员号）、member_id（会员号），产出「member_id」
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         b.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         b.dt    AS bet_date                                                                        -- 取值表达式：取用 dt（营业日）、bet_date（营业日），产出「bet_date」
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
    AND UPPER(TRIM(b.bet38)) = 'N'                                                                  -- 并列条件：限定 UPPER(TRIM(b.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02）
act AS (                              -- 候选池：局数不够就不可能凑到 100 局同桌
  --   ★ 门槛由 100 提至 300（降内存斧正三）：候选池是配对数的平方项底数，
  --     门槛提三倍，配对数约降一个数量级。判据本要求同桌 ≥100 笔，
  --     总局数不足 300 者几无可能构成稳定团伙对。要复原口径改回 100 即可，
  --     但须改走 §R02-1 分批模板。
  SELECT member_id, COUNT(*) AS n_rounds                                                            -- 取列：计数，取用 member_id（会员号），产出「n_rounds」
  FROM mr GROUP BY member_id HAVING COUNT(*) >= 300                                                 -- 取数来源：取自本条自建的中间结果集 mr
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02）
mr2 AS (                                                                                            -- 公共表表达式：开启中间结果集 mr2，其后各行为其定义体（§R02）
  SELECT m.* FROM mr m JOIN act a ON a.member_id = m.member_id                                      -- 取列：整体承接上游结果集的全部字段，不再逐列列举，取自本条自建的中间结果集 mr
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02）
pair AS (                             -- 阶段二：同局自连接（已压到候选池）
  SELECT x.member_id AS uid1, y.member_id AS uid2,                                                  -- 取列：起始取列子句，本行先取「uid2」，涉 member_id（会员号）
         COUNT(*)                    AS same_rounds,                                                -- 计数表达式：产出「same_rounds」
         COUNT(DISTINCT x.table_id)  AS n_tables,                                                   -- 计数表达式：统计去重个数，产出「n_tables」
         MIN(x.bet_date)             AS first_day,                                                  -- 取最小值表达式：取用 bet_date（营业日），产出「first_day」
         MAX(x.bet_date)             AS last_day                                                    -- 取最大值表达式：取用 bet_date（营业日），产出「last_day」
  FROM mr2 x                                                                                        -- 取数来源：取自本条自建的中间结果集 mr2
  JOIN mr2 y ON x.round_key = y.round_key AND x.member_id < y.member_id                             -- 连接：取自本条自建的中间结果集 mr2，连接键为 round_key（局键）、member_id（会员号）
  GROUP BY x.member_id, y.member_id                                                                 -- 分组：按 x.member_id, y.member_id 汇总
  HAVING COUNT(*) >= 100                           -- 需求：同桌订单数 > 100 笔
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02）
td AS (                               -- Lift 零假设的分子件：每人每桌每日局数
  SELECT table_id, bet_date, member_id, COUNT(*) AS n_md                                            -- 取列：计数，取用 member_id（会员号）、bet_date（营业日），产出「n_md」
  FROM mr2 GROUP BY table_id, bet_date, member_id                                                   -- 取数来源：取自本条自建的中间结果集 mr2
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02）
tot AS (                              -- Lift 零假设的分母件：每桌每日总局数
  SELECT table_id, bet_date, COUNT(DISTINCT round_key) AS n_td                                      -- 取列：统计去重个数，产出「n_td」
  FROM mr2 GROUP BY table_id, bet_date                                                              -- 取数来源：取自本条自建的中间结果集 mr2
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R02）
expct AS (                            -- E[same] = Σ n_a(t,d)·n_b(t,d) / N(t,d)
  --   ★ 降内存斧正一（决定性）：改以 pair 为**驱动表**，只为实际存在的对算期望。
  --     原式先算「同桌同日」的全组合再 LEFT JOIN 取用——同桌同日的候选会员
  --     可达数千，配对数按其平方增长，且绝大多数对根本不在 pair 里，算了白算。
  --     今由 pair 驱动，配对数降为「pair 对数 × 其共同桌日数」。
  --     期望值的定义式一字未动，输出逐值一致。
  SELECT p.uid1, p.uid2,                                                                            -- 取列：起始取列子句，本行先列 p.uid1, p.uid2
         SUM(a.n_md * b.n_md * 1.0 / NULLIF(t.n_td,0)) AS exp_same                                  -- 汇总表达式：产出「exp_same」
  FROM pair p                                                                                       -- 取数来源：取自本条自建的中间结果集 pair
  JOIN td a  ON a.member_id = p.uid1                                                                -- 连接：取自本条自建的中间结果集 td，连接键为 member_id（会员号）
  JOIN td b  ON b.member_id = p.uid2                                                                -- 连接：取自本条自建的中间结果集 td，连接键为 member_id（会员号）
            AND b.table_id  = a.table_id                                                            -- 并列条件：限定 b.table_id等于 a.table_id
            AND b.bet_date  = a.bet_date                                                            -- 并列条件：限定 b.bet_date等于 a.bet_date，涉 bet_date（营业日）
  JOIN tot t ON t.table_id  = a.table_id AND t.bet_date = a.bet_date                                -- 连接：取自本条自建的中间结果集 tot，连接键为 bet_date（营业日）
  GROUP BY p.uid1, p.uid2                                                                           -- 分组：按 p.uid1, p.uid2 汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R02）
SELECT p.uid1, p.uid2,                                                                              -- 取列：起始取列子句，本行先列 p.uid1, p.uid2
       p.same_rounds                                          AS n_same_orders,                     -- 取值表达式：产出「n_same_orders」
       a1.n_rounds                                            AS rounds_1,                          -- 取值表达式：产出「rounds_1」
       a2.n_rounds                                            AS rounds_2,                          -- 取值表达式：产出「rounds_2」
       p.same_rounds * 1.0                                                                          -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
         / NULLIF(LEAST(a1.n_rounds, a2.n_rounds),0)          AS same_rate,   -- 需求口径
       p.same_rounds * 1.0                                                                          -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
         / NULLIF(a1.n_rounds + a2.n_rounds - p.same_rounds,0) AS jaccard,    -- 对照口径
       p.same_rounds * 1.0 / NULLIF(e.exp_same, 0)            AS lift,        -- ★ 去巧合
       e.exp_same, p.n_tables, p.first_day, p.last_day                                              -- 续行：接续上一取列子句，续列 e.exp_same, p.n_tables, p.first_day, p.last_day
FROM pair p                                                                                         -- 取数来源：取自本条自建的中间结果集 pair
JOIN act a1 ON a1.member_id = p.uid1                                                                -- 连接：取自本条自建的中间结果集 act，连接键为 member_id（会员号）
JOIN act a2 ON a2.member_id = p.uid2                                                                -- 连接：取自本条自建的中间结果集 act，连接键为 member_id（会员号）
LEFT JOIN expct e ON e.uid1 = p.uid1 AND e.uid2 = p.uid2                                            -- 左连接：取自本条自建的中间结果集 expct，连接键为 e.uid1 = p.uid1 AND e.uid2 = p.uid2
ORDER BY lift DESC, same_rate DESC;                                                                 -- 排序：按 lift（降序）, same_rate（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ⚠️ 同上：**故意不加** same_rate >= 0.30 的 WHERE。阈值网格（@sec-r02 的 r02-grid）
   要扫 30%/40%/50%/70% × Lift 1/2/3/5 十六格，只导 30% 以上就扫不出下沿。
   若行数仍过大，把 act 的门槛再往上提，而不是加 same_rate 条件。 */

/* ═══════════════════════════════════════════════════════════════════════════
   §R02-1 · 分批模板（兜底之路 —— 三处斧正后仍撞内存上限时才用）
   ---------------------------------------------------------------------------
   分批不改语义，只改执行批次：**同桌配对本就不跨桌**，故按 table_id 切批，
   每批的结果彼此独立、无重叠、无遗漏，纵向合并即得全量。
   ★ 这是本条唯一安全的切分维度——**切勿按日期或会员号切**：
     按日切会把跨日的同桌对拆散、same_rounds 被人为分割；
     按会员号切会漏掉「一个在批内、一个在批外」的对。

   用法三步：
     ① 先跑下面的 §R02-1a 取桌台清单与各桌体量；
     ② 按体量把 27 张桌分成 3~5 批，每批总局数尽量相当；
     ③ 把 §R02 的 mr 里加一行 `AND b.bet39 IN ('桌1','桌2',...)`，逐批跑，
        每批另存为 R02_same_table_b1.csv / _b2.csv …，R 侧纵向合并。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §R02-1a 桌台体量清单（分批切点），屏幕看结果。
SELECT b.bet39 AS table_id,                                                                         -- 取列：起始取列子句，本行先取「table_id」，涉 bet39（桌号）
       COUNT(DISTINCT CONCAT_WS('|', b.bet03, b.bet04, b.bet39)) AS n_rounds,                       -- 计数表达式：统计去重个数，产出「n_rounds」
       COUNT(DISTINCT b.bet05)                                   AS n_member                        -- 计数表达式：统计去重个数，产出「n_member」
FROM ods_mariadb_2b.ods_a168_bet02 b                                                                -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE b.dt >= '2026-08-04' AND b.dt < '2026-08-07'                                                  -- 过滤条件：限定 b.dt不少于 '2026-08-04'、b.dt小于 '2026-08-07'，涉 dt（营业日）
  AND b.bet02 = '101' AND b.category = '1'                                                          -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
  AND UPPER(TRIM(b.bet38)) = 'N'                                                                    -- 并列条件：限定 UPPER(TRIM(b.bet38))等于 'N'，涉 bet38（测试标识）
  AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0                                                  -- 并列条件：限定 CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
GROUP BY b.bet39                                                                                    -- 分组：按 b.bet39 汇总
ORDER BY n_rounds DESC;                                                                             -- 排序：按 n_rounds（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：按 n_rounds 降序，用「贪心装箱」分批——最大的桌单独一批，
--       其余按体量凑成总量相当的几批。n_member 特别大的桌宜单独成批。


/* ───────────────────────────────────────────────────────────────────────────
   §R03 · R03_player_dealer.csv
   玩家×荷官关联异常：局级去重 + 玩法基准 Z-score + 对照胜率
   对应报告：@sec-r03
   ★ 已实现《荷官作弊风控阈值分析报告》自列的必补检查：
     用 bet03+bet04 统计关联有效局数，修正同局拆多单造成的 Z-score 放大。
   输出列：uid, dealer_id, stake_amount, profit_amount, net_pnl, win_rate,
           n_related_orders, n_rounds_eff, p_base_mix, z_score,
           net_pnl_all, game_pnl_all, stake_all, win_rate_all, win_rate_other
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R03_player_dealer.csv」（§R03 玩家×荷官·全窗聚合）。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§R03）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet17, b.bet38, b.bet39，涉 bet13（下注金额）、bet14（派彩金额）、bet17（会员净输赢）
         b.category, b.eid,                                                                         -- 续行：接续上一取列子句，续列 b.category, b.eid，涉 eid（荷官工号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R03）
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id, r.eid AS dealer_id,                               -- 取列：起始取列子句，本行先取「dealer_id」，涉 bet05（会员号）、eid（荷官工号）、member_id（会员号）
         r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw                                 -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1                                                                                    -- 过滤条件：限定 r.rn等于 1
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：限定 UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL                                                          -- 并列条件：限定该值非空，涉 eid（荷官工号）
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'      -- 阈值报告：排除小费单
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§R03）
  SELECT bet_id, member_id, dealer_id, bet_side, round_key,                                         -- 取列：起始取列子句，本行先列 bet_id, member_id, dealer_id, bet_side, round_key，涉 round_key（局键）、member_id（会员号）、dealer_id（荷官工号）
         stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (payout_raw - stake_raw) / fx AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         net_raw / fx                  AS net_pnl                                                   -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
  FROM base                                                                                         -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
side_base AS (      -- ★ 玩法基准胜率：Banker/Player/Tie/Big/Small 各算各的
  SELECT bet_side,                                                                                  -- 取列：起始取列子句，本行先列 bet_side
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base                    -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「p_base」
  FROM ord GROUP BY bet_side                                                                        -- 取数来源：取自本条自建的中间结果集 ord
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
pr AS (             -- ★ 局级去重：同局多单折成一局，Z-score 才不被 √k 倍放大
  SELECT member_id, dealer_id, round_key,                                                           -- 取列：起始取列子句，本行先列 member_id, dealer_id, round_key，涉 round_key（局键）、member_id（会员号）、dealer_id（荷官工号）
         SUM(stake)    AS stake,                                                                    -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(game_pnl) AS game_pnl,                                                                 -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(net_pnl)  AS net_pnl,                                                                  -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         COUNT(*)      AS n_orders_in_round,                                                        -- 计数表达式：产出「n_orders_in_round」
         MAX(bet_side) AS main_side                                                                 -- 取最大值表达式：产出「main_side」
  FROM ord GROUP BY member_id, dealer_id, round_key                                                 -- 取数来源：取自本条自建的中间结果集 ord
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
player_all AS (     -- 需求条件：用户整体盈利
  SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
         SUM(net_pnl)  AS net_pnl_all,                                                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl_all」
         SUM(game_pnl) AS game_pnl_all,                                                             -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl_all」
         SUM(stake)    AS stake_all,                                                                -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_all」
         SUM(CASE WHEN game_pnl >  0 THEN 1 ELSE 0 END) AS win_all,                                 -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「win_all」
         SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END) AS dec_all                                  -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「dec_all」
  FROM pr GROUP BY member_id                                                                        -- 取数来源：取自本条自建的中间结果集 pr
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
pd AS (                                                                                             -- 公共表表达式：开启中间结果集 pd，其后各行为其定义体（§R03）
  SELECT p.member_id, p.dealer_id,                                                                  -- 取列：起始取列子句，本行先列 p.member_id, p.dealer_id，涉 member_id（会员号）、dealer_id（荷官工号）
         COUNT(*)                                          AS n_rounds_eff,                         -- 计数表达式：取用 n_rounds_eff（有效局数），产出「n_rounds_eff」
         SUM(p.n_orders_in_round)                          AS n_orders,                             -- 汇总表达式：产出「n_orders」
         SUM(p.stake)                                      AS stake,                                -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(p.game_pnl)                                   AS game_pnl,                             -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(p.net_pnl)                                    AS net_pnl,                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         SUM(CASE WHEN p.game_pnl >  0 THEN 1 ELSE 0 END)  AS n_win,                                -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「n_win」
         SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)  AS n_dec,                                -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「n_dec」
         AVG(COALESCE(s.p_base, 0.5))                      AS p_base_mix                            -- 求均值表达式：产出「p_base_mix」
  FROM pr p                                                                                         -- 取数来源：取自本条自建的中间结果集 pr
  LEFT JOIN side_base s ON s.bet_side = p.main_side                                                 -- 左连接：取自本条自建的中间结果集 side_base，连接键为 s.bet_side = p.main_side
  GROUP BY p.member_id, p.dealer_id                                                                 -- 分组：按 p.member_id, p.dealer_id 汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  pd.member_id AS uid, pd.dealer_id,                                                                -- 取值表达式：取用 member_id（会员号）、uid（会员号）、dealer_id（荷官工号），产出「uid」
  pd.stake      AS stake_amount,      -- 需求「投注金额」
  pd.game_pnl   AS profit_amount,     -- 需求「盈利金额」（剔返水口径）
  pd.net_pnl,                                                                                       -- 续行：接续上一取列子句，续列 pd.net_pnl，涉 net_pnl（会员净输赢）
  pd.n_win * 1.0 / NULLIF(pd.n_dec, 0)              AS win_rate,          -- 需求「胜率」
  pd.n_orders  AS n_related_orders,                                       -- 需求「关联订单笔数」
  pd.n_rounds_eff, pd.p_base_mix,                                                                   -- 续行：接续上一取列子句，续列 pd.n_rounds_eff, pd.p_base_mix，涉 n_rounds_eff（有效局数）
  (pd.n_win - pd.n_dec * pd.p_base_mix)                                                             -- 续行：承接上一子句，构成完整语句，属 §R03 之取数
    / NULLIF(SQRT(pd.n_dec * pd.p_base_mix * (1 - pd.p_base_mix)), 0)  AS z_score,                  -- 除法或乘法计算：取用 z_score（标准化偏离度），产出「z_score」
  pa.net_pnl_all, pa.game_pnl_all, pa.stake_all,                                                    -- 续行：接续上一取列子句，续列 pa.net_pnl_all, pa.game_pnl_all, pa.stake_all
  pa.win_all * 1.0 / NULLIF(pa.dec_all, 0)          AS win_rate_all,                                -- 取值表达式：产出「win_rate_all」
  (pa.win_all - pd.n_win) * 1.0                                                                     -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(pa.dec_all - pd.n_dec, 0)              AS win_rate_other     -- ★ 对照检验
FROM pd                                                                                             -- 取数来源：取自本条自建的中间结果集 pd
JOIN player_all pa ON pa.member_id = pd.member_id                                                   -- 连接：取自本条自建的中间结果集 player_all，连接键为 member_id（会员号）
WHERE pd.n_rounds_eff >= 30                 -- 阈值报告口径：有效局数下限
ORDER BY z_score DESC, profit_amount DESC;                                                          -- 排序：按 z_score（降序）, profit_amount（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ⚠️ 此处保留 n_rounds_eff>=30（阈值报告已论证 30 以下噪声主导），
   但**不加** win_rate>0.70 / net_pnl_all>0：四条规则对照表（@sec-r03 的 r03-dual）
   需要在同一份底料上比较需求原口径与修正口径，加了就比不了。 */


/* ───────────────────────────────────────────────────────────────────────────
   §T02 · T02_daily_roi.csv
   会员 × 日 的投注与游戏输赢序列 —— 索提诺 / CAS 的唯一输入
   对应报告：@sec-t2
   输出列：member_id, bet_date, stake, game_pnl, n_rounds
   预期行数：大。**必须切分导出**（见文末切分模板），或先加活跃度门槛。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/T02_daily_roi.csv」（§T02 会员×日 ROI）。
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§T02）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T02）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§T02）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet11, b.bet13,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet11, b.bet13，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet14, b.bet18, b.bet19, b.bet20, b.bet21,                                               -- 续行：接续上一取列子句，续列 b.bet14, b.bet18, b.bet19, b.bet20, b.bet21，涉 bet14（派彩金额）、bet18（一级代理线）、bet19（二级代理线）
         b.bet22, b.bet38, b.bet39, b.category,                                                     -- 续行：接续上一取列子句，续列 b.bet22, b.bet38, b.bet39, b.category，涉 bet22（五级代理线）、bet38（测试标识）、bet39（桌号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T02）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§T02）
  SELECT r.bet05 AS member_id, r.dt AS bet_date,                                                    -- 取列：起始取列子句，本行先取「bet_date」，涉 bet05（会员号）、dt（营业日）、member_id（会员号）
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,                    -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl                  -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T02）
act AS (   -- 报告里索提诺要求「活跃日 ≥ 20」，少于 20 天的会员导出来也用不上
  SELECT member_id FROM ord                                                                         -- 取列：取用 member_id（会员号）
  GROUP BY member_id HAVING COUNT(DISTINCT bet_date) >= 20                                          -- 分组：统计去重个数
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§T02）
SELECT o.member_id, o.bet_date,                                                                     -- 取列：起始取列子句，本行先列 o.member_id, o.bet_date，涉 member_id（会员号）、bet_date（营业日）
       SUM(o.stake)                     AS stake,                                                   -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
       SUM(o.game_pnl)                  AS game_pnl,                                                -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
       COUNT(DISTINCT o.round_key)      AS n_rounds                                                 -- 计数表达式：统计去重个数，产出「n_rounds」
FROM ord o JOIN act a ON a.member_id = o.member_id                                                  -- 取数来源：取自本条自建的中间结果集 ord，连接键为 member_id（会员号）
GROUP BY o.member_id, o.bet_date                                                                    -- 分组：按 o.member_id, o.bet_date 汇总
ORDER BY o.member_id, o.bet_date;                                                                   -- 排序：按 o.member_id, o.bet_date 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ───────────────────────────────────────────────────────────────────────────
   §T03 · T03_arbitrage.csv
   打水型：游戏输赢趋零 × 账户仍在赚 × 对押率高
   对应报告：@sec-t3
   输出列：member_id, stake, validbet, game_pnl, net_pnl, rebate,
           hedge_rate, stake_cv, n_rounds, n_days
   ★ hedge_rate 口径说明：此处为**自对押率**（同一物理局内该会员同时押到
     庄侧与闲侧的局数占比），是单表可算的打水指纹。
     **跨会员对押**（一庄一闲两个号）不在本查询范围，由 §R02 / C-06 并入。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/T03_arbitrage.csv」（§T03 打水型画像）。
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§T03）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T03）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§T03）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet18,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet16, b.bet17, b.bet18，涉 bet13（下注金额）、bet14（派彩金额）、bet16（退水金额）
         b.bet19, b.bet20, b.bet21, b.bet22, b.bet38,                                               -- 续行：接续上一取列子句，续列 b.bet19, b.bet20, b.bet21, b.bet22, b.bet38，涉 bet19（二级代理线）、bet20（三级代理线）、bet21（四级代理线）
         b.bet39, b.category, b.validbet,                                                           -- 续行：接续上一取列子句，续列 b.bet39, b.category, b.validbet，涉 bet39（桌号）、validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T03）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§T03）
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet09 AS bet_side,                               -- 取列：起始取列子句，本行先取「bet_side」，涉 bet05（会员号）、bet09（玩法）、dt（营业日）
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「vb_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T03）
o2 AS (                                                                                             -- 公共表表达式：开启中间结果集 o2，其后各行为其定义体（§T03）
  SELECT member_id, bet_date, round_key,                                                            -- 取列：起始取列子句，本行先列 member_id, bet_date, round_key，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         COALESCE(vb_raw,stake_raw)/fx AS validbet,                                                 -- 取值表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
         (payout_raw - stake_raw)/fx   AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         rebate_raw / fx               AS rebate,                                                   -- 取值表达式：取用 rebate（退水），产出「rebate」
         net_raw / fx                  AS net_pnl,                                                  -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         /* ★ 2026-08-07 DX-01 实测校准：bet09 为英文玩法名。
            必须用等值匹配，不能用 LIKE '%BANK%' —— 后者会把
            BankerDragonBonus(20.7万) 与 BankerNatural(6.2万) 一并算成庄，
            而那是边注，与主线庄闲不构成对冲关系。 */
         CASE WHEN TRIM(bet_side) = 'Banker' THEN 1 ELSE 0 END AS is_b,                             -- 条件分支：产出「is_b」
         CASE WHEN TRIM(bet_side) = 'Player' THEN 1 ELSE 0 END AS is_p                              -- 条件分支：产出「is_p」
  FROM ord                                                                                          -- 取数来源：取自本条自建的中间结果集 ord
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§T03）
rk AS (      -- 局级：该会员本局是否同时押了庄与闲（自对押）
  SELECT member_id, bet_date, round_key,                                                            -- 取列：起始取列子句，本行先列 member_id, bet_date, round_key，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         SUM(stake) AS stake, SUM(validbet) AS validbet,                                            -- 汇总表达式：取用 stake（下注额（经汇率归一化））、validbet（有效投注（洗码量）），产出「validbet」
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,                 -- 汇总表达式：取用 net_pnl（会员净输赢）、game_pnl（游戏净输赢）、rebate（退水），产出「net_pnl」
         CASE WHEN MAX(is_b)=1 AND MAX(is_p)=1 THEN 1 ELSE 0 END AS is_self_hedge                   -- 条件分支：取最大值，产出「is_self_hedge」
  FROM o2 GROUP BY member_id, bet_date, round_key                                                   -- 取数来源：取自本条自建的中间结果集 o2
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§T03）
SELECT member_id,                                                                                   -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
       SUM(stake)                          AS stake,                                                -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
       SUM(validbet)                       AS validbet,                                             -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
       SUM(game_pnl)                       AS game_pnl,                                             -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
       SUM(net_pnl)                        AS net_pnl,                                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
       SUM(rebate)                         AS rebate,                                               -- 汇总表达式：取用 rebate（退水），产出「rebate」
       SUM(is_self_hedge) * 1.0 / COUNT(*) AS hedge_rate,     -- 自对押率
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0) AS stake_cv, -- 注额变异系数（打水者极低）
       COUNT(*)                            AS n_rounds,                                             -- 计数表达式：产出「n_rounds」
       COUNT(DISTINCT bet_date)            AS n_days                                                -- 计数表达式：统计去重个数，产出「n_days」
FROM rk                                                                                             -- 取数来源：取自本条自建的中间结果集 rk
GROUP BY member_id                                                                                  -- 分组：按 member_id 汇总
HAVING COUNT(*) >= 100                       -- 局数太少算不出稳定的比率
ORDER BY hedge_rate DESC, validbet DESC;                                                            -- 排序：按 hedge_rate（降序）, validbet（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ───────────────────────────────────────────────────────────────────────────
   §E02 · E02_segment_econ.csv
   分群单位经济学 —— 赏罚经济学引擎（@sec-econ）的唯一输入
   输出列：segment, n_member, validbet, ggr, rebate, commission, tenure_months
   口径：
     ggr        = -SUM(game_pnl)         庄家从该群赢到的钱（剔返水）
     rebate     =  SUM(rebate)           返水支出
     commission =  占成支出（**当前置 0**，见下方警告）
     tenure_months = 该群平均活跃月数（H 的经验代理，正式版应由 Cox/RSF 给出）
   分群：退水档位 × 洗码量四分位（均由数据算出，不写死档位）
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：不需要 —— 本条是**备用回退版**（占成恒置 0），正版请跑 §E02c。
--   §DX-03 已实测确认 bet23~27 = LV1~5 占成，§E02c 可直接运行，故常态下不必跑本条。
--   仅当 dailyreport 不可用、§E02c 跑不通时，才改存为「数据库/E02_segment_econ.csv」，
--   并须在报告中显式标注「占成恒 0，净贡献率系统性偏乐观、γ* 偏大」。
--   ⛔ 【已于 2026-08-09 摘除 · §E02 回退版（占成恒置 0）】原 SQL 65 行。缘由：已被 §E02c 量纲自适应版取代；占成恒 0 会令净贡献率系统性偏乐观、γ* 偏大。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
/* ⚠️⚠️ commission（代理占成）当前恒置 0 —— 这是本包唯一一个**已知不完整**的字段。
   bet02 里的 commission 是「佣金模式标记」（免佣桌/一般桌），不是占成金额。
   信用盘占成惯例 1–2.5%，若不补齐，@sec-econ 算出的净贡献率会**系统性偏乐观**，
   δ* 偏小、γ* 偏大（赏得过头）。
   补齐路径：从代理合同表取各 LV 层占成比例，按 bet18–bet22 沿链分摊到会员。
   在补齐之前，E02 的 γ*（赏项上限）一律视为**上界估计，不得直接下发**。 */


/* ───────────────────────────────────────────────────────────────────────────
   §B01 · B01_bt_panel.csv
   会员 × 日 回测面板 —— 策略滚动回测（@sec-strategy-bt）的输入
   输出列：member_id, bet_date, stake, game_pnl, net_pnl, rebate, validbet,
           n_rounds, n_tables, n_ip, late_share_d, hedge_rate_d, stake_cv_d
   ★ 本查询**不产出 risk_score**：风险分是被拟合的量，由 R 侧
     compose_risk_score() 在各折训练窗内算出。SQL 只给原始特征，
     在 SQL 里预先算好风险分再回测 = 用全样本定分数 = 信息泄漏。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/B01_bt_panel.csv」（§B01 会员×日回测面板）。
-- ⚠️ Superset 单次导出上限，必按 §99 模板分批，否则静默截断丢会员。
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§B01）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§B01）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§B01）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet18,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet16, b.bet17, b.bet18，涉 bet13（下注金额）、bet14（派彩金额）、bet16（退水金额）
         b.bet19, b.bet20, b.bet21, b.bet22, b.bet38,                                               -- 续行：接续上一取列子句，续列 b.bet19, b.bet20, b.bet21, b.bet22, b.bet38，涉 bet19（二级代理线）、bet20（三级代理线）、bet21（四级代理线）
         b.bet39, b.category, b.ip, b.validbet,                                                     -- 续行：接续上一取列子句，续列 b.bet39, b.category, b.ip, b.validbet，涉 bet39（桌号）、validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§B01）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§B01）
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id, r.ip AS bet_ip,               -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、bet39（桌号）、dt（营业日）
         r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「round_no」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「vb_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§B01）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（§B01）
  SELECT member_id, bet_date, round_key, MAX(table_id) AS table_id,                                 -- 取列：起始取列子句，本行先取「table_id」，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         MAX(bet_ip) AS bet_ip, MAX(round_no) AS round_no,                                          -- 取最大值表达式：取用 bet_ip（下注 IP），产出「round_no」
         SUM(stake_raw/fx)                     AS stake,                                            -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(COALESCE(vb_raw,stake_raw)/fx)    AS validbet,                                         -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
         SUM((payout_raw-stake_raw)/fx)        AS game_pnl,                                         -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(rebate_raw/fx)                    AS rebate,                                           -- 汇总表达式：取用 rebate（退水），产出「rebate」
         SUM(net_raw/fx)                       AS net_pnl,                                          -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1                       -- 条件分支：取最大值
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1                       -- 并列条件：限定 MAX(CASE WHEN TRIM(bet_side)等于 'Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END                AS is_self_hedge                                     -- 分支取值：产出「is_self_hedge」
  FROM ord GROUP BY member_id, bet_date, round_key                                                  -- 取数来源：取自本条自建的中间结果集 ord
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§B01）
SELECT member_id, bet_date,                                                                         -- 取列：起始取列子句，本行先列 member_id, bet_date，涉 member_id（会员号）、bet_date（营业日）
       SUM(stake)                                     AS stake,                                     -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
       SUM(game_pnl)                                  AS game_pnl,                                  -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
       SUM(net_pnl)                                   AS net_pnl,                                   -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
       SUM(rebate)                                    AS rebate,                                    -- 汇总表达式：取用 rebate（退水），产出「rebate」
       SUM(validbet)                                  AS validbet,                                  -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
       COUNT(*)                                       AS n_rounds,                                  -- 计数表达式：产出「n_rounds」
       COUNT(DISTINCT table_id)                       AS n_tables,                                  -- 计数表达式：统计去重个数，产出「n_tables」
       COUNT(DISTINCT bet_ip)                         AS n_ip,                                      -- 计数表达式：统计去重个数，产出「n_ip」
       SUM(CASE WHEN round_no >= 50 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_share_d,            -- 汇总表达式：计数，产出「late_share_d」
       SUM(is_self_hedge) * 1.0 / COUNT(*)            AS hedge_rate_d,                              -- 汇总表达式：计数，产出「hedge_rate_d」
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)      AS stake_cv_d                                 -- 取值表达式：求均值，取用 stake（下注额（经汇率归一化）），产出「stake_cv_d」
FROM rk                                                                                             -- 取数来源：取自本条自建的中间结果集 rk
GROUP BY member_id, bet_date                                                                        -- 分组：按 member_id, bet_date 汇总
ORDER BY bet_date, member_id;                                                                       -- 排序：按 bet_date, member_id 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════
   §B01-D · B01 面板每日增量（第六批 · 影子期起每日用；历史回测不需要）
   ▸ 导出：「数据库/B01_bt_panel_delta.csv」→ R 侧按 (member_id, bet_date)
     覆盖合并进本地面板（同键新行覆盖旧行，即完成迟到修订同步）
   ▸ 与 §B01 逐字同构，仅两处不同：窗口谓词（尾随 3 天）与行序（按合并键）
   ▸ 每天只改标注 ★★ 的一行：左端 = 今天减 3，右端 = 今天
   ▸ 实测（2026-08-07 当天跑三天增量）：3.183 秒；七项口径体检全过
     （net_pnl≡game_pnl+rebate 违例 0；stake_cv_d 空值⇔n_rounds=1 零例外）
   ▸ ⚠️ Superset 单次导出上限 1,000 行——体检够用，正式合并须按
     member_id 分批（§99 模板），否则**静默丢弃**后段会员
   ▸ §PIT-01 实测 >7 天修订仅 0.00089%，尾随 3 天足以吞掉迟到修订 */
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
),                                                                                                  -- 续行：收束上方的子查询或函数括号
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet18,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet16, b.bet17, b.bet18，涉 bet13（下注金额）、bet14（派彩金额）、bet16（退水金额）
         b.bet19, b.bet20, b.bet21, b.bet22, b.bet38,                                               -- 续行：接续上一取列子句，续列 b.bet19, b.bet20, b.bet21, b.bet22, b.bet38，涉 bet19（二级代理线）、bet20（三级代理线）、bet21（四级代理线）
         b.bet39, b.category, b.ip, b.validbet,                                                     -- 续行：接续上一取列子句，续列 b.bet39, b.category, b.ip, b.validbet，涉 bet39（桌号）、validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-08-04' AND b.dt < '2026-08-07'   -- ★★ 每日唯一要改的一行 ★★
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id, r.ip AS bet_ip,               -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、bet39（桌号）、dt（营业日）
         r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「round_no」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「vb_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体
  SELECT member_id, bet_date, round_key, MAX(table_id) AS table_id,                                 -- 取列：起始取列子句，本行先取「table_id」，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         MAX(bet_ip) AS bet_ip, MAX(round_no) AS round_no,                                          -- 取最大值表达式：取用 bet_ip（下注 IP），产出「round_no」
         SUM(stake_raw/fx)                     AS stake,                                            -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(COALESCE(vb_raw,stake_raw)/fx)    AS validbet,                                         -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
         SUM((payout_raw-stake_raw)/fx)        AS game_pnl,                                         -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(rebate_raw/fx)                    AS rebate,                                           -- 汇总表达式：取用 rebate（退水），产出「rebate」
         SUM(net_raw/fx)                       AS net_pnl,                                          -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         /* DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1                       -- 条件分支：取最大值
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1                       -- 并列条件：限定 MAX(CASE WHEN TRIM(bet_side)等于 'Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END                AS is_self_hedge                                     -- 分支取值：产出「is_self_hedge」
  FROM ord GROUP BY member_id, bet_date, round_key                                                  -- 取数来源：取自本条自建的中间结果集 ord
)                                                                                                   -- 续行：收束上方的子查询或函数括号
SELECT member_id, bet_date,                                                                         -- 取列：起始取列子句，本行先列 member_id, bet_date，涉 member_id（会员号）、bet_date（营业日）
       SUM(stake)                                     AS stake,                                     -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
       SUM(game_pnl)                                  AS game_pnl,                                  -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
       SUM(net_pnl)                                   AS net_pnl,                                   -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
       SUM(rebate)                                    AS rebate,                                    -- 汇总表达式：取用 rebate（退水），产出「rebate」
       SUM(validbet)                                  AS validbet,                                  -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
       COUNT(*)                                       AS n_rounds,                                  -- 计数表达式：产出「n_rounds」
       COUNT(DISTINCT table_id)                       AS n_tables,                                  -- 计数表达式：统计去重个数，产出「n_tables」
       COUNT(DISTINCT bet_ip)                         AS n_ip,                                      -- 计数表达式：统计去重个数，产出「n_ip」
       SUM(CASE WHEN round_no >= 50 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_share_d,            -- 汇总表达式：计数，产出「late_share_d」
       SUM(is_self_hedge) * 1.0 / COUNT(*)            AS hedge_rate_d,                              -- 汇总表达式：计数，产出「hedge_rate_d」
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)      AS stake_cv_d                                 -- 取值表达式：求均值，取用 stake（下注额（经汇率归一化）），产出「stake_cv_d」
FROM rk                                                                                             -- 取数来源：取自本条自建的中间结果集 rk
GROUP BY member_id, bet_date                                                                        -- 分组：按 member_id, bet_date 汇总
ORDER BY member_id, bet_date;                                                                       -- 排序：按 member_id, bet_date 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ───────────────────────────────────────────────────────────────────────────
   §K01 · K01_risk_feature_matrix.csv
   T4 扩样特征矩阵（@sec-t4）：会员级特征 + is_seed 种子标记
   ★ 种子必须**混合来源**（人工風險單 + R-01/R-02/R-03 + L0 金标准），
     否则 PU 模型学到的只是「某一条规则」，扩样等于把规则重跑一遍。
   ★ 特征侧**刻意排除**产生种子的那几个量（late_share / same_rate / z_score），
     否则就是自我循环。此处只给「行为结构」类特征。
   输出列：member_id, is_seed, n_rounds, n_days, n_tables, n_ip, n_dealer,
           side_entropy, stake_cv, stake_p90_p50, hedge_rate, rebate_dep,
           night_share, roi_game, validbet
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/K01_risk_feature_matrix.csv」（§K01 扩样特征矩阵）。
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§K01）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§K01）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§K01）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（测试标识）、bet39（桌号）、eid（荷官工号）
         b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101'                                                                             -- 并列条件：限定 b.bet02等于 '101'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§K01）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§K01）
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id,                               -- 取列：起始取列子句，本行先取「table_id」，涉 bet05（会员号）、bet39（桌号）、dt（营业日）
         r.ip AS bet_ip, r.eid AS dealer_id, r.bet09 AS bet_side,                                   -- 取值表达式：取用 bet09（玩法）、eid（荷官工号）、bet_ip（下注 IP），产出「bet_side」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         HOUR(CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME)) AS bet_hour,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「bet_hour」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「vb_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§K01）
side_mix AS (      -- 玩法熵：只押单一玩法（熵≈0）是打水/技术型的共同结构特征
  SELECT member_id, bet_side, COUNT(*) AS n_side                                                    -- 取列：计数，取用 member_id（会员号），产出「n_side」
  FROM ord GROUP BY member_id, bet_side                                                             -- 取数来源：取自本条自建的中间结果集 ord
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§K01）
side_ent AS (                                                                                       -- 公共表表达式：开启中间结果集 side_ent，其后各行为其定义体（§K01）
  SELECT s.member_id,                                                                               -- 取列：起始取列子句，本行先列 s.member_id，涉 member_id（会员号）
         -SUM((s.n_side*1.0/t.n_all) * LOG2(s.n_side*1.0/t.n_all)) AS side_entropy                  -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「side_entropy」
  FROM side_mix s                                                                                   -- 取数来源：取自本条自建的中间结果集 side_mix
  JOIN (SELECT member_id, SUM(n_side) AS n_all FROM side_mix GROUP BY member_id) t                  -- 连接：取自本条自建的中间结果集 side_mix
    ON t.member_id = s.member_id                                                                    -- 连接键：限定 t.member_id等于 s.member_id，涉 member_id（会员号）
  GROUP BY s.member_id                                                                              -- 分组：按 s.member_id 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§K01）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（§K01）
  SELECT member_id, bet_date, round_key,                                                            -- 取列：起始取列子句，本行先列 member_id, bet_date, round_key，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         MAX(table_id) AS table_id, MAX(bet_ip) AS bet_ip,                                          -- 取最大值表达式：取用 bet_ip（下注 IP），产出「bet_ip」
         MAX(dealer_id) AS dealer_id, MAX(bet_hour) AS bet_hour,                                    -- 取最大值表达式：取用 dealer_id（荷官工号），产出「bet_hour」
         SUM(stake_raw/fx) AS stake,                                                                -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(COALESCE(vb_raw,stake_raw)/fx) AS validbet,                                            -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
         SUM((payout_raw-stake_raw)/fx) AS game_pnl,                                                -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(rebate_raw/fx) AS rebate,                                                              -- 汇总表达式：取用 rebate（退水），产出「rebate」
         SUM(net_raw/fx)    AS net_pnl,                                                             -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1                       -- 条件分支：取最大值
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1                       -- 并列条件：限定 MAX(CASE WHEN TRIM(bet_side)等于 'Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END AS is_self_hedge                                                    -- 分支取值：产出「is_self_hedge」
  FROM ord GROUP BY member_id, bet_date, round_key                                                  -- 取数来源：取自本条自建的中间结果集 ord
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§K01）
feat AS (                                                                                           -- 公共表表达式：开启中间结果集 feat，其后各行为其定义体（§K01）
  SELECT member_id,                                                                                 -- 取列：起始取列子句，本行先列 member_id，涉 member_id（会员号）
         COUNT(*)                        AS n_rounds,                                               -- 计数表达式：产出「n_rounds」
         COUNT(DISTINCT bet_date)        AS n_days,                                                 -- 计数表达式：统计去重个数，产出「n_days」
         COUNT(DISTINCT table_id)        AS n_tables,                                               -- 计数表达式：统计去重个数，产出「n_tables」
         COUNT(DISTINCT bet_ip)          AS n_ip,                                                   -- 计数表达式：统计去重个数，产出「n_ip」
         COUNT(DISTINCT dealer_id)       AS n_dealer,                                               -- 计数表达式：统计去重个数，产出「n_dealer」
         STDDEV_SAMP(stake)/NULLIF(AVG(stake),0)              AS stake_cv,                          -- 取值表达式：求均值，取用 stake（下注额（经汇率归一化））、stake_cv（注额变异系数），产出「stake_cv」
         PERCENTILE_APPROX(stake,0.9)                                                               -- 取近似分位数表达式：取用 stake（下注额（经汇率归一化））
           / NULLIF(PERCENTILE_APPROX(stake,0.5),0)           AS stake_p90_p50,                     -- 除法或乘法计算：取近似分位数，取用 stake（下注额（经汇率归一化）），产出「stake_p90_p50」
         SUM(is_self_hedge)*1.0/COUNT(*)                      AS hedge_rate,                        -- 汇总表达式：计数，取用 hedge_rate（对打率），产出「hedge_rate」
         SUM(rebate)/NULLIF(ABS(SUM(net_pnl)),0)              AS rebate_dep,                        -- 汇总表达式：取用 net_pnl（会员净输赢）、rebate_dep（退水依赖度）、rebate（退水），产出「rebate_dep」
         SUM(CASE WHEN bet_hour BETWEEN 0 AND 6 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS night_share,     -- 汇总表达式：计数，取用 night_share（夜场占比），产出「night_share」
         SUM(game_pnl)/NULLIF(SUM(stake),0)                   AS roi_game,                          -- 汇总表达式：取用 stake（下注额（经汇率归一化））、game_pnl（游戏净输赢）、roi_game（游戏回报率），产出「roi_game」
         SUM(validbet)                                        AS validbet                           -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
  FROM rk GROUP BY member_id                                                                        -- 取数来源：取自本条自建的中间结果集 rk
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§K01）
SELECT f.member_id,                                                                                 -- 取列：起始取列子句，本行先列 f.member_id，涉 member_id（会员号）
       CAST(0 AS INT) AS is_seed,          -- ★ 占位列：种子一律在 Python 侧并入，见下方说明
       f.n_rounds, f.n_days, f.n_tables, f.n_ip, f.n_dealer,                                        -- 续行：接续上一取列子句，续列 f.n_rounds, f.n_days, f.n_tables, f.n_ip, f.n_dealer，涉 n_ip（IP 数）
       COALESCE(se.side_entropy, 0) AS side_entropy,                                                -- 取值表达式：取用 side_entropy（投注产品结构熵），产出「side_entropy」
       f.stake_cv, f.stake_p90_p50, f.hedge_rate, f.rebate_dep,                                     -- 续行：接续上一取列子句，续列 f.stake_cv, f.stake_p90_p50, f.hedge_rate, f.rebate_dep，涉 hedge_rate（对打率）、stake_cv（注额变异系数）、rebate_dep（退水依赖度）
       f.night_share, f.roi_game, f.validbet                                                        -- 续行：接续上一取列子句，续列 f.night_share, f.roi_game, f.validbet，涉 validbet（有效投注（洗码量））、night_share（夜场占比）、roi_game（游戏回报率）
FROM feat f                                                                                         -- 取数来源：取自本条自建的中间结果集 feat
LEFT JOIN side_ent se ON se.member_id = f.member_id                                                 -- 左连接：取自本条自建的中间结果集 side_ent，连接键为 member_id（会员号）
WHERE f.n_rounds >= 50                                                                              -- 过滤条件：限定 f.n_rounds不少于 50
ORDER BY f.validbet DESC;                                                                           -- 排序：按 f.validbet（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ═══ 为什么 is_seed 恒为 0 —— 这是刻意的，不是遗漏 ═══════════════════════════
   首版这里 join 了 dailyreport_member 与 alert_ip_setting，实跑报错：
     StarRocks: Column 'member_id' cannot be resolved.
   根因：主表 bet02 用 betNN 代号，辅助表各有各的命名，两张辅助表的会员列
   与 IP 列都不叫 member_id / ip。列名未核对就写 join，是本包唯一一次踩坑。

   斧正后的分工（也更符合「种子必须混合来源」这条原则）：
     · 本查询 = **纯特征矩阵**，只碰 bet02 + agent，保证任何时候都跑得通；
     · 五路种子全部在 Python 侧合并（@sec-t4 的 t4-cluster 块已实现）：
         ①人工風險單/劃單  ②L0 金标准 IP  ③R-01 闸三  ④R-02 Lift≥3  ⑤R-03 Z≥4
       其中 ③④⑤ 直接读 R01/R02/R03 三份 CSV；①② 走下方 §K01b。
   好处：任何一路种子缺位，T4 仍能用其余几路跑起来，不会因一张辅助表卡死全章。
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §K01b · 种子来源①② —— ★ 2026-08-07 列名已实测填实，可直接运行
   ---------------------------------------------------------------------------
   实测列定义（information_schema 确认）：
     ods_a168_dailyreport_member : bet05=會員編號  risk=風險單(1:是)  orders=劃單(1:是)
                                   dt=日分区  category=1一般/2小費  bet02=遊戲編號
     ods_a168_alert_ip_setting   : ip  creator  addtime  remarks(风控员判定原话)
   导出：「数据库/K01b_seed_manual.csv」（两条各跑一次，纵向合并成一份）
   ═══════════════════════════════════════════════════════════════════════════ */
-- ① 人工風險單 / 劃單（L1a 人工标签）
-- ▸ 导出：需要 —— 存为「数据库/K01b_seed_manual.csv」（§K01b 种子来源①·人工風險單/劃單）。
SELECT DISTINCT bet05 AS member_id, 'manual_risk' AS seed_src                                       -- 取列：取用 bet05（会员号）、member_id（会员号），产出「seed_src」
FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                     -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND bet02 = '101'                                                                                 -- 并列条件：限定 bet02等于 '101'，涉 bet02（游戏类别）
  AND (CAST(NULLIF(TRIM(risk),'')   AS INT) = 1                                                     -- 并列条件：限定 (CAST(NULLIF(TRIM(risk),'') AS INT)等于 1
    OR CAST(NULLIF(TRIM(orders),'') AS INT) = 1)                                                    -- 择一条件：限定 CAST(NULLIF(TRIM(orders),'') AS INT)等于 1)
  AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0                                                    -- 并列条件：限定 CAST(NULLIF(TRIM(bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
ORDER BY member_id;                                                                                 -- 排序：按 member_id 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 注意：risk/orders 在 ODS 里是 varchar 承载的 tinyint，必须 CAST 后比 1，
--       写成 risk > 0 会做字符串比较，'0' > 0 的语义在不同引擎下不一致。

-- ② L0 金标准关注 IP 下的会员（先单跑 alert 名单看它是否仍活跃）
-- ▸ 导出：不需要 —— §K01b 中间确认步骤（先看关注 IP 名单是否仍活跃），屏幕看结果。
SELECT id, ip, creator, addtime, remarks                                                            -- 取列：承接上一子句，构成完整语句，属 §K01b 之取数
FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                                       -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
ORDER BY addtime DESC;                                                                              -- 排序：按 addtime（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

-- ②b 关注 IP 命中的会员（上一条确认 IP 仍在本窗口出现后再跑）
-- ▸ 导出：需要 —— 存为「数据库/K01b_seed_goldip.csv」（§K01b 种子来源②b·金标准 IP 命中会员）。
SELECT DISTINCT b.bet05 AS member_id, 'gold_ip' AS seed_src                                         -- 取列：取用 bet05（会员号）、member_id（会员号），产出「seed_src」
FROM ods_mariadb_2b.ods_a168_bet02 b                                                                -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
JOIN ods_mariadb_2b.ods_a168_alert_ip_setting a ON TRIM(a.ip) = TRIM(b.ip)                          -- 连接：取自风控 IP 名单配置表（人工标记史料源），连接键为 TRIM(a.ip) = TRIM(b.ip)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                  -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
  AND b.bet02 = '101' AND b.category = '1'                                                          -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
  AND UPPER(TRIM(b.bet38)) = 'N'                                                                    -- 并列条件：限定 UPPER(TRIM(b.bet38))等于 'N'，涉 bet38（测试标识）
ORDER BY member_id;                                                                                 -- 排序：按 member_id 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）


/* ═══════════════════════════════════════════════════════════════════════════
   §E02c · 分群单位经济学（★ 占成版 —— 补齐上一轮标注的唯一不完整字段）
   ---------------------------------------------------------------------------
   上一轮 §E02 把 commission 恒置 0，并警告「会让净贡献率系统性偏乐观、
   γ* 偏大（赏得过头）」。DX-03 实测发现 ods_a168_dailyreport_member 里
   本来就有五级占成与五级退水：
       bet23~bet27 = LV1~LV5 占成      bet28~bet32 = LV1~LV5 退水
       bet41 = 有效投注   bet13 = 下注金額   bet14 = 派彩金額
       bet15 = 會員退水%數   bet11 = 匯率
   于是 κ（占成率）可以直接算出来，E02 的那个 0 就填实了。
   ---------------------------------------------------------------------------
   ⚠️ 量纲未定：bet23~bet32 是「金额」还是「比率」，列注释没写。
      先跑 §E02c-0 看量级——若与 bet41 同数量级则为金额，若恒在 0~1 则为比率。
      §DX-03 实测（2026-08-08）已确认**列义**：bet23~27 = LV1~5 占成、
      bet28~32 = LV1~5 退水、bet15 = 會員退水%數、bet41 = 有效投注，
      均 decimal(16,4)。列义已定，**量纲（比率还是金额）仍须本探针判定**。
      量纲判错会让 κ 差几个数量级，δ* 与 γ* 全盘失真。**这一步不可跳过。**
   导出：「数据库/E02_segment_econ.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
-- §E02c-0 · 量纲探针（先跑这条，30 秒，决定下面怎么算）
-- ▸ 导出：不需要 —— §E02c-0 量纲探针（判 bet23~27 是比率还是金额），屏幕看结果。
--   ⛔ 【已于 2026-08-09 摘除 · §E02c-0 量纲探针】原 SQL 12 行。缘由：已被 §E02c 内联的量纲自适应判据取代（probe → sc → k 系数），无须人工先探再改。
--      本包只保留可落实商业方案的最新版本；告示保留于此，以防日后误跑旧版。
-- 读法：max_lv1_comm ≤ 1 且 avg 在 0.0x 量级 → 比率；
--       与 avg_validbet 同量级（成千上万）→ 金额。下面按「金额」写，
--       若探针判为比率，把 §E02c 里 comm_amt 的算式改为
--         SUM((bet23+..+bet27) * bet41 / bet11)

-- §E02c · 分群单位经济学（占成已补齐 · 2026-08-09 量纲自适应 + 提速版）
-- ▸ 导出：需要 —— 存为「数据库/E02_segment_econ.csv」（§E02c 分群单位经济学·含占成 κ）。
-- ★ 本条为 §E02 的升级版，同名覆盖；两条都跑时以本条为最终版本。
--
-- ★★ 斧正缘由（实测触发）：R 侧实测 κ = 4.75% > m = 1.92%，且 609 个分层**全部**
--    占成高于该层 GGR。「全部」这一形状，正是把「百分比」当「金额」直接累加的典型
--    症状——若 bet23~27 存的是 LV1~5 佔成百分数（如 0.8 表 0.8%），五级相加再当金额
--    累计，量级必然离谱且方向一致。原版依赖人工先跑 §E02c-0 探针、再按判读手改算式，
--    易漏易错；今改为**量纲自适应**：由数据自身的量级判据在同一查询内选定口径，
--    并把判据与所选模式一并输出，使口径可审计、不可默认。
--
--    判据（reb / comm 各自独立判定，因两组字段未必同量纲）：
--      · max ≤ 1                          → 小数比率（0.008 = 0.8%）→ 乘洗码量
--      · max ≤ 100 且 max < 洗码量均值/50 → 百分数（0.8 = 0.8%）    → 乘洗码量 ÷ 100
--      · 其余                              → 金额（原样使用）
--    ★ 输出新增两列 comm_scale / reb_scale，报告与审计据此复核；
--      口径一旦被判为比率，κ 会回到合理量级，赏侧天花板 γ* 方可由过渡口径
--      m−ρ 回到 m−ρ−κ。若判为金额而 κ 仍 > m，则属真业务异常，赏侧继续冻结。
--
-- ★★ 提速原理（首版量纲自适应实测偏慢，根因为五处，逐一斧正）：
--    ① probe 原扫**全窗 139 日**取量纲判据——而量纲是 schema 属性，非时序量，
--       三日足以判定。今改扫 2026-08-04 ~ 08-07 三日窗，**扫描量降至约 1/46**，
--       且与主表同分区键，可命中分区裁剪；
--    ② `MAX(GREATEST(五列))` 每行做五元比较，改为 `GREATEST(MAX(列)×5)`——
--       数学上完全等价（最大值之最大值），但由「每行五次比较」降为「五次列聚合」；
--    ③ 原 d → d2 → mem 三层，d2 纯属投影中间层，徒增一次物化。
--       今将量纲 CASE **内联进 mem 的聚合式**，三层坍缩为两层；
--    ④ `COUNT(DISTINCT DATE_FORMAT(CAST(dt AS DATE),'%Y-%m'))` 每行做一次
--       CAST + DATE_FORMAT。dt 本即 'YYYY-MM-DD' 字符串，改用 `SUBSTR(dt,1,7)`，
--       两次函数调用降为一次子串截取；
--    ⑤ comm_scale / reb_scale 原在 mem 层对每个会员做字符串 MAX——而它们是**全窗单值**。
--       今改由最外层 CROSS JOIN probe 取一次，会员级聚合不再携带字符串列。
--    输出逐列一致，量纲判定结果不变。
WITH probe AS (            -- 量纲判据：三日窗即足（量纲是 schema 属性，非时序量）
  SELECT                                                                                            -- 续行：接续上一取列子句，续列 SELECT
    GREATEST(                                                                                       -- 取值表达式：承接上一子句，构成完整语句，属 §E02c 之取数
      COALESCE(MAX(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet24),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet25),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet26),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,4))),0)) AS max_comm,                  -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「max_comm」
    GREATEST(                                                                                       -- 取值表达式：承接上一子句，构成完整语句，属 §E02c 之取数
      COALESCE(MAX(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet29),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet30),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet31),'') AS DECIMAL(20,4))),0),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
      COALESCE(MAX(CAST(NULLIF(TRIM(bet32),'') AS DECIMAL(20,4))),0)) AS max_reb,                   -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「max_reb」
    AVG(CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)))                AS avg_vb                     -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「avg_vb」
  FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                   -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
  WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                    -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
    AND bet02 = '101' AND category = '1'                                                            -- 并列条件：限定 bet02等于 '101'、category等于 '1'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§E02c）
sc AS (                    -- 判据 → 口径与乘数，全窗单行，供下游广播
  SELECT                                                                                            -- 续行：接续上一取列子句，续列 SELECT
    CASE WHEN max_comm <= 1 THEN 'rate_decimal'                                                     -- 条件分支：承接上一子句，构成完整语句，属 §E02c 之取数
         WHEN max_comm <= 100 AND max_comm < avg_vb / 50.0 THEN 'rate_percent'                      -- 分支判定：承接上一子句，构成完整语句，属 §E02c 之取数
         ELSE 'amount' END                                   AS comm_scale,                         -- 兜底取值：产出「comm_scale」
    CASE WHEN max_reb  <= 1 THEN 'rate_decimal'                                                     -- 条件分支：承接上一子句，构成完整语句，属 §E02c 之取数
         WHEN max_reb  <= 100 AND max_reb  < avg_vb / 50.0 THEN 'rate_percent'                      -- 分支判定：承接上一子句，构成完整语句，属 §E02c 之取数
         ELSE 'amount' END                                   AS reb_scale,                          -- 兜底取值：产出「reb_scale」
    CASE WHEN max_comm <= 1 THEN 1.0                                                                -- 条件分支：承接上一子句，构成完整语句，属 §E02c 之取数
         WHEN max_comm <= 100 AND max_comm < avg_vb / 50.0 THEN 0.01                                -- 分支判定：承接上一子句，构成完整语句，属 §E02c 之取数
         ELSE 0.0 END                                        AS comm_k,  -- 乘洗码量的系数
    CASE WHEN max_reb  <= 1 THEN 1.0                                                                -- 条件分支：承接上一子句，构成完整语句，属 §E02c 之取数
         WHEN max_reb  <= 100 AND max_reb  < avg_vb / 50.0 THEN 0.01                                -- 分支判定：承接上一子句，构成完整语句，属 §E02c 之取数
         ELSE 0.0 END                                        AS reb_k                               -- 兜底取值：产出「reb_k」
  FROM probe                                                                                        -- 取数来源：取自本条自建的中间结果集 probe
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§E02c）
mem AS (                   -- ★ 一次扫描直出会员级；量纲 CASE 已内联为 k 系数乘法
  SELECT b.bet05 AS member_id,                                                                      -- 取列：起始取列子句，本行先取「member_id」，涉 bet05（会员号）、member_id（会员号）
         SUM(CAST(NULLIF(TRIM(b.bet41),'') AS DECIMAL(20,4))                                        -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)))          AS validbet,               -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「validbet」
         SUM((CAST(NULLIF(TRIM(b.bet14),'') AS DECIMAL(20,4))                                       -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
            - CAST(NULLIF(TRIM(b.bet13),'') AS DECIMAL(20,4)))                                      -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)))          AS game_pnl,               -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         SUM(( COALESCE(CAST(NULLIF(TRIM(b.bet28),'') AS DECIMAL(20,4)),0)                          -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet29),'') AS DECIMAL(20,4)),0)                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet30),'') AS DECIMAL(20,4)),0)                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet31),'') AS DECIMAL(20,4)),0)                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet32),'') AS DECIMAL(20,4)),0))                         -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             * (CASE WHEN s.reb_k > 0                                                               -- 除法或乘法计算：承接上一子句，构成完整语句，属 §E02c 之取数
                     THEN s.reb_k * CAST(NULLIF(TRIM(b.bet41),'') AS DECIMAL(20,4))                 -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                     ELSE 1.0 END)                                                                  -- 兜底取值：承接上一子句，构成完整语句，属 §E02c 之取数
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)))          AS rebate,                 -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
         SUM(( COALESCE(CAST(NULLIF(TRIM(b.bet23),'') AS DECIMAL(20,4)),0)                          -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet24),'') AS DECIMAL(20,4)),0)                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet25),'') AS DECIMAL(20,4)),0)                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet26),'') AS DECIMAL(20,4)),0)                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             + COALESCE(CAST(NULLIF(TRIM(b.bet27),'') AS DECIMAL(20,4)),0))                         -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
             * (CASE WHEN s.comm_k > 0                                                              -- 除法或乘法计算：承接上一子句，构成完整语句，属 §E02c 之取数
                     THEN s.comm_k * CAST(NULLIF(TRIM(b.bet41),'') AS DECIMAL(20,4))                -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                     ELSE 1.0 END)                                                                  -- 兜底取值：承接上一子句，构成完整语句，属 §E02c 之取数
             / CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)))          AS commission,             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「commission」
         COUNT(DISTINCT SUBSTR(b.dt, 1, 7))                              AS n_months,               -- 计数表达式：统计去重个数，产出「n_months」
         COUNT(DISTINCT b.dt)                                            AS n_days                  -- 计数表达式：统计去重个数，产出「n_days」
  FROM ods_mariadb_2b.ods_a168_dailyreport_member b                                                 -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
  CROSS JOIN sc s                                                                                   -- 交叉连接：取自本条自建的中间结果集 sc
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(b.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
  GROUP BY b.bet05                                                                                  -- 分组：按 b.bet05 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§E02c）
mem2 AS (                                                                                           -- 公共表表达式：开启中间结果集 mem2，其后各行为其定义体（§E02c）
  SELECT m.*,                                                                                       -- 取列：整体承接上游结果集的全部字段，不再逐列列举
         /* 分群：实测退水率三位小数分档 × 洗码量四分位，全部由数据算出 */
         ROUND(m.rebate / NULLIF(m.validbet,0), 3) AS rebate_rate_bkt,                              -- 取值表达式：取用 validbet（有效投注（洗码量））、rebate（退水），产出「rebate_rate_bkt」
         NTILE(4) OVER (ORDER BY m.validbet)       AS vb_q                                          -- 等分分箱表达式：取用 validbet（有效投注（洗码量）），产出「vb_q」
  FROM mem m WHERE m.validbet > 0                                                                   -- 取数来源：取自本条自建的中间结果集 mem
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§E02c）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  CONCAT('实测退水', CAST(m.rebate_rate_bkt AS STRING),                                                 -- 取值表达式：承接上一子句，构成完整语句，属 §E02c 之取数
         ' · 流水Q', CAST(m.vb_q AS STRING)) AS segment,                                              -- 字面取值：取用 segment（客户分层），产出「segment」
  COUNT(*)             AS n_member,                                                                 -- 计数表达式：取用 n_member（会员数），产出「n_member」
  SUM(m.validbet)      AS validbet,                                                                 -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
  -SUM(m.game_pnl)     AS ggr,           -- 庄家赢 = 玩家输
  SUM(m.rebate)        AS rebate,                                                                   -- 汇总表达式：取用 rebate（退水），产出「rebate」
  SUM(m.commission)    AS commission,    -- ★ 不再是 0；量纲由 comm_scale 标明
  MAX(s.comm_scale)    AS comm_scale,    -- ★ 全窗单值，由 sc 广播取得
  MAX(s.reb_scale)     AS reb_scale,                                                                -- 取最大值表达式：产出「reb_scale」
  AVG(m.n_months)      AS tenure_months                                                             -- 求均值表达式：产出「tenure_months」
FROM mem2 m CROSS JOIN sc s                                                                         -- 取数来源：取自本条自建的中间结果集 mem2
GROUP BY m.rebate_rate_bkt, m.vb_q                                                                  -- 分组：按 m.rebate_rate_bkt, m.vb_q 汇总
ORDER BY validbet DESC;                                                                             -- 排序：按 validbet（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ★ 交叉校验（务必做）：本表的 SUM(validbet) 应与 §E02 走 bet02 明细算出的
   洗码量大体一致。dailyreport 是日汇总表，bet02 是注单明细表，两者若差异
   超过 5%，说明 dailyreport 的口径含小費/其他游戏或未剔测试线——
   以 bet02 明细为准，把本表仅用于取 commission 一列并回贴。 */


/* ───────────────────────────────────────────────────────────────────────────
   §C06fix · C-06 同IP对打对（DX-01 校准版，替换原包 C-06）
   ---------------------------------------------------------------------------
   原版 side CTE 用 bet_side IN ('1','B','庄','莊') / ('2','P','闲','閒')，
   与库内实际取值 Banker / Player 完全不匹配 → 两次实测均返回零行。
   本版只改 side CTE 两行判别，其余一字未动。
   注释一律用行注释，不用块注释（见 §DX-02 写法禁令）。
   导出：「数据库/C06_hedge_pairs.csv」
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/C06_hedge_pairs.csv」（§C06fix 同 IP 对打对·正版）。
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体（§C06fix）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§C06fix）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（§C06fix）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet11, b.bet13, b.bet18, b.bet19, b.bet20,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet18, b.bet19, b.bet20，涉 bet11（汇率）、bet13（下注金额）、bet18（一级代理线）
         b.bet21, b.bet22, b.bet38, b.bet39, b.category,                                            -- 续行：接续上一取列子句，续列 b.bet21, b.bet22, b.bet38, b.bet39, b.category，涉 bet21（四级代理线）、bet22（五级代理线）、bet38（测试标识）
         b.eid, b.ip,                                                                               -- 续行：接续上一取列子句，续列 b.eid, b.ip，涉 eid（荷官工号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§C06fix）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（§C06fix）
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§C06fix）
bs AS (                                                                                             -- 公共表表达式：开启中间结果集 bs，其后各行为其定义体（§C06fix）
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake                               -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
  FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§C06fix）
side AS (                                                                                           -- 公共表表达式：开启中间结果集 side，其后各行为其定义体（§C06fix）
  -- 每人每把在该IP的净方向（庄=+ 闲=-，按本金）
  -- ★ DX-01 校准：等值匹配 Banker / Player。
  --   不可用 LIKE '%BANK%'：会误纳 BankerDragonBonus(20.7万笔)、
  --   BankerNatural(6.2万笔) 等边注，那与主线庄闲不构成对冲关系。
  SELECT bet_ip, round_key, member_id,                                                              -- 取列：起始取列子句，本行先列 bet_ip, round_key, member_id，涉 round_key（局键）、bet_ip（下注 IP）、member_id（会员号）
         SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake                                         -- 汇总表达式：取用 stake（下注额（经汇率归一化））
                  WHEN TRIM(bet_side) = 'Player' THEN -stake                                        -- 分支判定：取用 stake（下注额（经汇率归一化））
                  ELSE 0 END) AS dir_stake                                                          -- 兜底取值：产出「dir_stake」
  FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL                                                 -- 取数来源：取自本条自建的中间结果集 bs
  GROUP BY bet_ip, round_key, member_id                                                             -- 分组：按 bet_ip, round_key, member_id 汇总
  HAVING ABS(SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake                                     -- 分组后过滤：限定 ABS(SUM(CASE WHEN TRIM(bet_side)等于 'Banker' THEN stake，涉 stake（下注额（经汇率归一化））
                      WHEN TRIM(bet_side) = 'Player' THEN -stake                                    -- 分支判定：取用 stake（下注额（经汇率归一化））
                      ELSE 0 END)) > 0                                                              -- 兜底取值：承接上一子句，构成完整语句，属 §C06fix 之取数
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§C06fix）
pairs AS (                                                                                          -- 公共表表达式：开启中间结果集 pairs，其后各行为其定义体（§C06fix）
  SELECT a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,                                          -- 取列：起始取列子句，本行先取「m_b」，涉 bet_ip（下注 IP）、member_id（会员号）
         COUNT(*) AS n_same_round,                                                                  -- 计数表达式：产出「n_same_round」
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN 1 ELSE 0 END) AS n_opposite_round,          -- 汇总表达式：产出「n_opposite_round」
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0                                                  -- 汇总表达式：承接上一子句，构成完整语句，属 §C06fix 之取数
                   AND ABS(ABS(a.dir_stake)-ABS(b.dir_stake))                                       -- 并列条件：承接上一子句，构成完整语句，属 §C06fix 之取数
                       <= 0.1*GREATEST(ABS(a.dir_stake),ABS(b.dir_stake))                           -- 取值表达式：承接上一子句，构成完整语句，属 §C06fix 之取数
                  THEN 1 ELSE 0 END) AS n_hedged                                                    -- 分支取值：产出「n_hedged」
  FROM side a JOIN side b                                                                           -- 取数来源：取自本条自建的中间结果集 side
    ON a.bet_ip=b.bet_ip AND a.round_key=b.round_key                                                -- 连接键：限定 a.bet_ip等于 b.bet_ip、a.round_key等于 b.round_key，涉 round_key（局键）、bet_ip（下注 IP）
   AND a.member_id < b.member_id                                                                    -- 并列条件：限定 a.member_id小于 b.member_id，涉 member_id（会员号）
  GROUP BY a.bet_ip, a.member_id, b.member_id                                                       -- 分组：按 a.bet_ip, a.member_id, b.member_id 汇总
  HAVING COUNT(*) >= 30                                                                             -- 分组后过滤：限定行数不少于 30
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§C06fix）
SELECT bet_ip, m_a, m_b, n_same_round, n_opposite_round,                                            -- 取列：起始取列子句，本行先列 bet_ip, m_a, m_b, n_same_round, n_opposite_round，涉 bet_ip（下注 IP）
       n_opposite_round*1.0/n_same_round AS opposite_rate,                                          -- 取值表达式：取用 opposite_rate（反向比例），产出「opposite_rate」
       n_hedged*1.0/NULLIF(n_opposite_round,0) AS hedge_coverage                                    -- 取值表达式：产出「hedge_coverage」
FROM pairs                                                                                          -- 取数来源：取自本条自建的中间结果集 pairs
ORDER BY opposite_rate DESC, n_opposite_round DESC;                                                 -- 排序：按 opposite_rate（降序）, n_opposite_round（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 若本版仍返回零行，那才是真正的结论（同IP无对打）；
-- 但在此之前先跑下面这条一行探针确认判别已生效：
--   SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_bet02
--   WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet09 = 'Banker';
-- 该数应约为 4,682 万。若为 0，说明 bet09 有前后空格，把判别改成
--   UPPER(TRIM(bet_side)) = 'BANKER' / 'PLAYER'。


/* ───────────────────────────────────────────────────────────────────────────
   §99 · 大表切分导出模板（T02 / B01 / K01 用得上）
   ★ 绝对不要用 OFFSET 翻页 —— 277 批数据 36.49% 重复的根因就是分页无稳定排序。
   正确做法：按 bet05 的哈希或数值区间切成 N 份，每份独立跑、独立导。
   ─────────────────────────────────────────────────────────────────────────── */
-- 第 k 份（k = 0..9，共 10 份）：在最外层 SELECT 之前的 ord/rk CTE 里加这一行
--   AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) % 10 = 0     -- ← 改 0,1,2,...,9
-- 导出 10 份后在 R 侧 rbind 即可；因为切分键是会员号，各份之间天然不重叠。

-- 切分前先确认每份大小：
-- ▸ 导出：不需要 —— §99 切分前的分桶体量确认，屏幕看结果。
SELECT CAST(NULLIF(TRIM(bet05),'') AS BIGINT) % 10 AS bucket,                                       -- 取列：起始取列子句，本行先取「bucket」，涉 bet05（会员号）
       COUNT(*) AS n_rows, COUNT(DISTINCT bet05) AS n_member                                        -- 计数表达式：统计唯一会员数（铁律分母，全窗 721,190 人），产出「n_member」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND bet02 = '101' AND category = '1' AND UPPER(TRIM(bet38)) = 'N'                                 -- 并列条件：限定 bet02等于 '101'、category等于 '1'、UPPER(TRIM(bet38))等于 'N'，涉 bet02（游戏类别）、bet38（测试标识）
GROUP BY CAST(NULLIF(TRIM(bet05),'') AS BIGINT) % 10                                                -- 分组：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
ORDER BY bucket;                                                                                    -- 排序：按 bucket 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

/* ───────────────────────────────────────────────────────────────────────────
   §TG · 时间一致性守卫（截止日 2026-08-07）
   ---------------------------------------------------------------------------
   目的：事实表已按窗口截断，但**维度表通常是最新快照**。
   两者时点不一致会造成两类静默错误：
     ① 穿越 —— 会员注册时间晚于其首笔注单 → 「注册至今天数」为负 → 生命周期特征全错
     ② 口径漂移 —— 「该 IP 关联多少会员」算的是今天的关联，不是窗口内的关联
   凡检出晚于截止日的记录，一律先剔除并记数，再进入建模。
   ─────────────────────────────────────────────────────────────────────────── */

-- §TG-01 · 会员注册时间 vs 首笔注单时间（穿越检测）
-- ★★ 会员主表尚未提供。§DX-03 实测（2026-08-08）已证实：member_dtl 的
--    22 列中**没有注册时间列**（mem001~mem016 为退水/限额/代理链配置），
--    不可拿它顶替本占位——注册邻近度须等真正的会员主表（含注册时间）到位
-- SELECT m.★★会员列★★ AS member_id,
--        m.★★注册时间列★★ AS reg_time,
--        f.first_bet,
--        CASE WHEN CAST(m.★★注册时间列★★ AS DATE) > DATE '2026-08-07'
--               THEN '未来日期'
--             WHEN CAST(m.★★注册时间列★★ AS DATETIME) > f.first_bet
--               THEN '注册晚于首注单（穿越）'
--             ELSE 'OK' END AS verdict
-- FROM ods_mariadb_2b.★★会员主表★★ m
-- LEFT JOIN (SELECT bet05, MIN(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS first_bet
--            FROM ods_mariadb_2b.ods_a168_bet02
--            WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101'
--            GROUP BY bet05) f ON f.bet05 = m.★★会员列★★
-- ORDER BY verdict, member_id;

-- §TG-03 · 关注 IP 名单的登记时间是否越过截止日（可直接跑，列名已实测）
-- ▸ 导出：不需要 —— §TG-03 屏幕守卫（关注 IP 登记时间越界检测）。
SELECT id, ip, creator, addtime, remarks,                                                           -- 取列：起始取列子句，本行先列 id, ip, creator, addtime, remarks
       CASE WHEN CAST(SUBSTR(addtime,1,10) AS DATE) > DATE '2026-08-07'                             -- 条件分支：承接上一子句，构成完整语句，属 §TG-03 之取数
            THEN '🔴 未来日期，应从 L0 金标准剔除' ELSE '🟢 OK' END AS verdict                                    -- 分支取值：产出「verdict」
FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                                       -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
ORDER BY addtime DESC;                                                                              -- 排序：按 addtime（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

-- §TG-05 · 事实表自身的越界自检（应返回 0 行；非 0 即窗口过滤有漏）
-- ▸ 导出：不需要 —— §TG-05 屏幕守卫（事实表越界自检，应返回 0 行）。
SELECT COUNT(*) AS n_future_rows,                                                                   -- 取列：起始取列子句，本行先取「n_future_rows」
       MIN(dt) AS min_dt, MAX(dt) AS max_dt                                                         -- 取最小值表达式：取最大值，取用 dt（营业日），产出「max_dt」
FROM ods_mariadb_2b.ods_a168_bet02                                                                  -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
WHERE dt >= DATE '2026-08-07';                                                                      -- 过滤条件：限定 dt不少于 DATE '2026-08-07'，涉 dt（营业日）


/* ───────────────────────────────────────────────────────────────────────────
   §DX-04 · 玩法 × 会员 的子分类底料（@sec-subclass 的定量输入）
   输出：bet09 玩法 · 注单数 · 会员数 · 投注额 · 玩家盈亏 · 实测庄家 hold%
   用途：验证各玩法的实测庄家优势与理论值是否一致；偏离大的玩法优先查
   导出：「数据库/DX04_bet09_profile.csv」
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/DX04_bet09_profile.csv」（§DX-04 投注产品×会员子分类底料）。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§DX-04）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet05, b.bet09, b.bet11, b.bet13, b.bet14,                                               -- 续行：接续上一取列子句，续列 b.bet05, b.bet09, b.bet11, b.bet13, b.bet14，涉 bet05（会员号）、bet09（玩法）、bet11（汇率）
         b.bet38, b.category,                                                                       -- 续行：接续上一取列子句，续列 b.bet38, b.category，涉 bet38（测试标识）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§DX-04）
o AS (                                                                                              -- 公共表表达式：开启中间结果集 o，其后各行为其定义体（§DX-04）
  SELECT r.bet09 AS bet_side, r.bet05 AS member_id,                                                 -- 取列：起始取列子句，本行先取「member_id」，涉 bet05（会员号）、bet09（玩法）、member_id（会员号）
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,                    -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl                  -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§DX-04）
SELECT bet_side,                                                                                    -- 取列：起始取列子句，本行先列 bet_side
       COUNT(*)                                   AS n_orders,                                      -- 计数表达式：产出「n_orders」
       COUNT(DISTINCT member_id)                  AS n_member,                                      -- 计数表达式：统计去重个数，产出「n_member」
       SUM(stake)                                 AS stake_total,                                   -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_total」
       SUM(game_pnl)                              AS player_pnl,                                    -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「player_pnl」
       -SUM(game_pnl) / NULLIF(SUM(stake),0)      AS house_hold_pct,                                -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「house_hold_pct」
       SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                          -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
         / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END),0) AS win_rate_base,               -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「win_rate_base」
       AVG(stake)                                 AS avg_stake,                                     -- 求均值表达式：取用 stake（下注额（经汇率归一化）），产出「avg_stake」
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)  AS stake_cv                                       -- 取值表达式：求均值，取用 stake（下注额（经汇率归一化））、stake_cv（注额变异系数），产出「stake_cv」
FROM o                                                                                              -- 取数来源：取自本条自建的中间结果集 o
GROUP BY bet_side                                                                                   -- 分组：按 bet_side 汇总
ORDER BY n_orders DESC;                                                                             -- 排序：按 n_orders（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：house_hold_pct 应接近该玩法的理论庄家优势。
--   明显低于理论值的玩法 = 该玩法上有人在赢庄家 → 优先查；
--   win_rate_base 就是 R-03 的 Z-score 基准，务必按玩法取用，不可混算。

/* ───────────────────────────────────────────────────────────────────────────
   §DX-05 · 产品全景：本报告只覆盖了多大一块？
   ---------------------------------------------------------------------------
   全文所有 SQL 都带 bet02 = '101'（百家乐）。这是主动的产品口径选择，
   但必须知道它在全平台里占多少——否则漏损总量会被低估、净贡献率会被算偏
   （退水与占成按全产品结算，而分子只算了百家乐）。
   本查询给出各产品的注单量、投注额、玩家盈亏、庄家 hold%，一次看清占比。
   导出：「数据库/DX05_product_panorama.csv」
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/DX05_product_panorama.csv」（§DX-05 产品全景覆盖度）。
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents，其后各行为其定义体（§DX-05）
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                   -- 取列：取用代理主档（五级代理线归属来源），产出「agent_id」
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§DX-05）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§DX-05）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet05, b.bet11, b.bet13, b.bet14, b.bet16,                                               -- 续行：接续上一取列子句，续列 b.bet05, b.bet11, b.bet13, b.bet14, b.bet16，涉 bet05（会员号）、bet11（汇率）、bet13（下注金额）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet38, b.category, b.eid, b.validbet,                                                    -- 续行：接续上一取列子句，续列 b.bet38, b.category, b.eid, b.validbet，涉 bet38（测试标识）、eid（荷官工号）、validbet（有效投注（洗码量））
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§DX-05）
o AS (                                                                                              -- 公共表表达式：开启中间结果集 o，其后各行为其定义体（§DX-05）
  SELECT r.bet02 AS product_code, r.bet05 AS member_id, r.eid AS dealer_id,                         -- 取列：起始取列子句，本行先取「dealer_id」，涉 bet02（游戏类别）、bet05（会员号）、eid（荷官工号）
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,                    -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
         COALESCE(CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)),                               -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                  CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                  -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS validbet,                 -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「validbet」
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl,                 -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS rebate                    -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet18（一级代理线）
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet19（二级代理线）
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet20（三级代理线）
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet21（四级代理线）
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                                 -- 左连接：取自本条自建的中间结果集 test_agents，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL               -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§DX-05）
SELECT product_code,                                                                                -- 取列：起始取列子句，本行先列 product_code
       CASE WHEN product_code = '101' THEN '百家乐（本报告口径）' ELSE '其他产品' END AS scope,                   -- 条件分支：产出「scope」
       COUNT(*)                                  AS n_orders,                                       -- 计数表达式：产出「n_orders」
       COUNT(DISTINCT member_id)                 AS n_member,                                       -- 计数表达式：统计去重个数，产出「n_member」
       COUNT(DISTINCT dealer_id)                 AS n_dealer,                                       -- 计数表达式：统计去重个数，产出「n_dealer」
       SUM(stake)                                AS stake_total,                                    -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_total」
       SUM(validbet)                             AS validbet_total,                                 -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet_total」
       SUM(game_pnl)                             AS player_pnl,                                     -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「player_pnl」
       -SUM(game_pnl)                            AS ggr,                                            -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「ggr」
       -SUM(game_pnl) / NULLIF(SUM(stake),0)     AS house_hold_pct,                                 -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR），产出「house_hold_pct」
       SUM(rebate)                               AS rebate_total,                                   -- 汇总表达式：取用 rebate（退水），产出「rebate_total」
       SUM(rebate) / NULLIF(SUM(validbet),0)     AS rebate_rate,                                    -- 汇总表达式：取用 validbet（有效投注（洗码量））、rebate（退水），产出「rebate_rate」
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()    AS order_share,                                    -- 计数表达式：全局窗口，用作占比之分母，产出「order_share」
       SUM(stake) / SUM(SUM(stake)) OVER ()      AS stake_share                                     -- 汇总表达式：全局窗口，用作占比之分母，产出「stake_share」
FROM o                                                                                              -- 取数来源：取自本条自建的中间结果集 o
GROUP BY product_code                                                                               -- 分组：按 product_code 汇总
ORDER BY n_orders DESC;                                                                             -- 排序：按 n_orders（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* 读法（三个关键比值）：
   ① 百家乐的 order_share / stake_share —— 本报告覆盖面。低于 70% 则所有金额结论
      必须显式标注「百家乐口径」，不得当全平台数字引用。
   ② 各产品的 house_hold_pct —— 明显低于理论庄家优势者，说明该产品上有人在赢庄家，
      应优先把本方案的三条风控线移植过去。
   ③ 各产品的 rebate_rate —— 退水率显著高于百家乐的产品，是打水套利的下一个战场。
      @sec-econ 的 κ 与 ρ 必须按全产品重算，否则净贡献率系统性偏乐观。 */

/* ───────────────────────────────────────────────────────────────────────────
   §00c · 表行数复核（一次给全，供报告的「核心表点货单」现算行数）
   ---------------------------------------------------------------------------
   报告里的「行数量级」原本是早期测试期的静态记忆。跑这条导出后，
   点货单会自动改为「实测」并标注；不跑则显式标注「历史记录·未复核」。
   导出：「数据库/V_table_counts.csv」（两列：表名 / 行数）
   注：information_schema.tables 的 TABLE_ROWS 在 StarRocks 上是估算值，
       所以这里用 COUNT(*) 精确统计。表多时耗时以分钟计，属正常。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/V_table_counts.csv」（§00c 表行数复核；报告据此把点货单标为「实测」）。
SELECT 'ods_a168_bet02'              AS 表名, COUNT(*) AS 行数 FROM ods_mariadb_2b.ods_a168_bet02       -- 取列：计数，取用注单明细表（金额与行为口径的第一料源），产出「行数」
UNION ALL SELECT 'ods_a168_bet01',              COUNT(*) FROM ods_mariadb_2b.ods_a168_bet01         -- 结果集合并：计数，取用注单主表（仅供比对，不作主用）
UNION ALL SELECT 'ods_a168_game_info',          COUNT(*) FROM ods_mariadb_2b.ods_a168_game_info     -- 结果集合并：计数，取用局信息表（靴局、开牌与桌号的时序基准）
UNION ALL SELECT 'ods_a168_agent',              COUNT(*) FROM ods_mariadb_2b.ods_a168_agent         -- 结果集合并：计数，取用代理主档（五级代理线归属来源）
UNION ALL SELECT 'ods_a168_member_dtl',         COUNT(*) FROM ods_mariadb_2b.ods_a168_member_dtl    -- 结果集合并：计数，取用会员主档明细（注册与账户属性）
UNION ALL SELECT 'ods_a168_dailyreport_member', COUNT(*) FROM ods_mariadb_2b.ods_a168_dailyreport_member  -- 结果集合并：计数，取用会员日结报表（日粒度业绩与风控标记）
UNION ALL SELECT 'ods_a168_alert_ip_setting',   COUNT(*) FROM ods_mariadb_2b.ods_a168_alert_ip_setting  -- 结果集合并：计数，取用风控 IP 名单配置表（人工标记史料源）
UNION ALL SELECT 'ods_a168_employee',           COUNT(*) FROM ods_mariadb_2b.ods_a168_employee      -- 结果集合并：计数，取用员工主档（荷官工号与在职状态）
UNION ALL SELECT 'ods_a168_game_No',            COUNT(*) FROM ods_mariadb_2b.ods_a168_game_No       -- 结果集合并：计数，取用局号编码表（局键位数核验之用）
ORDER BY 行数 DESC;                                                                                   -- 排序：按行数（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* 若某张表名在本库不存在，删掉对应那一行 UNION 再跑；
   报告侧对缺失的表名会自动落回「历史记录·未复核」，不会报错。 */

/* ───────────────────────────────────────────────────────────────────────────
   §R03b · R03b_player_dealer_daily.csv —— R-03 的**日粒度**版本
   ---------------------------------------------------------------------------
   为什么要它：R-03 是全窗口聚合（一个玩家×荷官一行），没有日期维度，
   因此做不了「需求原规则 vs Z 轨」的时序对照。本查询与 §R03 口径**一字不动**
   （局级去重、玩法基准、排除 Tip），只把聚合键从
       GROUP BY member_id, dealer_id
   改为
       GROUP BY member_id, dealer_id, bet_date
   输出：bet_date, uid, dealer_id, stake_amount, profit_amount, win_rate,
         n_related_orders, n_rounds_eff, p_base_mix, z_score
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R03b_player_dealer_daily.csv」（§R03b 玩家×荷官·日粒度）。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§R03b）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet17, b.bet38, b.bet39，涉 bet13（下注金额）、bet14（派彩金额）、bet17（会员净输赢）
         b.category, b.eid,                                                                         -- 续行：接续上一取列子句，续列 b.category, b.eid，涉 eid（荷官工号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R03b）
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,                                -- 取列：起始取列子句，本行先取「bet_date」，涉 bet05（会员号）、eid（荷官工号）、dt（营业日）
         r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw                                 -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'                                                     -- 过滤条件：限定 r.rn等于 1、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL                                                          -- 并列条件：限定该值非空，涉 eid（荷官工号）
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'                                                   -- 并列条件：限定不匹配所给模式，涉 bet09（玩法）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§R03b）
  SELECT member_id, dealer_id, bet_date, bet_side, round_key,                                       -- 取列：起始取列子句，本行先列 member_id, dealer_id, bet_date, bet_side, round_key，涉 round_key（局键）、member_id（会员号）、dealer_id（荷官工号）
         stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (payout_raw - stake_raw) / fx AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         net_raw / fx                  AS net_pnl                                                   -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
  FROM base                                                                                         -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
side_base AS (                                                                                      -- 公共表表达式：开启中间结果集 side_base，其后各行为其定义体（§R03b）
  SELECT bet_side,                                                                                  -- 取列：起始取列子句，本行先列 bet_side
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base                    -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「p_base」
  FROM ord GROUP BY bet_side                                                                        -- 取数来源：取自本条自建的中间结果集 ord
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
pr AS (   -- 局级去重：同一物理局折成一局，避免 Z-score 被 sqrt(k) 放大
  SELECT member_id, dealer_id, bet_date, round_key,                                                 -- 取列：起始取列子句，本行先列 member_id, dealer_id, bet_date, round_key，涉 round_key（局键）、member_id（会员号）、dealer_id（荷官工号）
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,                   -- 汇总表达式：取用 stake（下注额（经汇率归一化））、net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「net_pnl」
         COUNT(*) AS n_orders_in_round, MAX(bet_side) AS main_side                                  -- 计数表达式：取最大值，产出「main_side」
  FROM ord GROUP BY member_id, dealer_id, bet_date, round_key                                       -- 取数来源：取自本条自建的中间结果集 ord
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03b）
SELECT p.bet_date, p.member_id AS uid, p.dealer_id,                                                 -- 取列：起始取列子句，本行先取「uid」，涉 member_id（会员号）、uid（会员号）、dealer_id（荷官工号）
       SUM(p.stake)                                        AS stake_amount,                         -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_amount」
       SUM(p.game_pnl)                                     AS profit_amount,                        -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「profit_amount」
       SUM(p.net_pnl)                                      AS net_pnl,                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
       SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
         / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,                 -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「win_rate」
       SUM(p.n_orders_in_round)                            AS n_related_orders,                     -- 汇总表达式：产出「n_related_orders」
       COUNT(*)                                            AS n_rounds_eff,                         -- 计数表达式：取用 n_rounds_eff（有效局数），产出「n_rounds_eff」
       AVG(COALESCE(s.p_base, 0.5))                        AS p_base_mix,                           -- 求均值表达式：产出「p_base_mix」
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 续行：汇总，取用 game_pnl（游戏净输赢）
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(COALESCE(s.p_base,0.5)))           -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR）
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢）
                       * AVG(COALESCE(s.p_base,0.5))                                                -- 除法或乘法计算：求均值
                       * (1 - AVG(COALESCE(s.p_base,0.5)))), 0)        AS z_score                   -- 除法或乘法计算：求均值，取用 z_score（标准化偏离度），产出「z_score」
FROM pr p                                                                                           -- 取数来源：取自本条自建的中间结果集 pr
LEFT JOIN side_base s ON s.bet_side = p.main_side                                                   -- 左连接：取自本条自建的中间结果集 side_base，连接键为 s.bet_side = p.main_side
GROUP BY p.bet_date, p.member_id, p.dealer_id                                                       -- 分组：按 p.bet_date, p.member_id, p.dealer_id 汇总
ORDER BY p.bet_date, z_score DESC;                                                                  -- 排序：按 p.bet_date, z_score（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ⚠️ 日粒度下单日有效局数天然偏少，Z-score 噪声比全窗口版大得多。
   本导出**只用于时序对照与趋势观察**，处置判定一律仍以 §R03 全窗口版为准。 */

/* ───────────────────────────────────────────────────────────────────────────
   §S04p · 风控员最小画像（S04_analyst_score.csv 的**部分实测**替代）
   ---------------------------------------------------------------------------
   现状：风控员的四个维度（标注产量/命中率/复核时效/误标率）全部依赖
   「风控处置日志」——本平台还没有这张表。库里能沾边的只有两处：
     · alert_ip_setting.creator —— 有登记人，但只有 17 条、且是 2022 年的
     · dailyreport.risk/orders  —— 只记了「会员被标了」，**没记是谁标的**
   所以本查询给的**不是绩效评分**，只是让那张雷达从「全合成」变成「部分实测」，
   并把缺口摆明。四个维度里它只能填「标注产量」一项，其余仍为待补。
   导出：「数据库/S04_analyst_score.csv」
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/S04_analyst_score.csv」（§S04p 风控专员最小画像·正版）。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COALESCE(NULLIF(TRIM(creator), ''), '未署名')      AS entity_id,                                     -- 取值表达式：产出「entity_id」
  -- ★ 下面三个列名与报告的风控专员雷达字典严格对应，一字不可改
  COUNT(*)                                            AS 标注产量,                                      -- 计数表达式：产出「标注产量」
  COUNT(DISTINCT TRIM(ip))                            AS 覆盖IP广度,                                    -- 计数表达式：统计去重个数，产出「覆盖IP广度」
  AVG(LENGTH(COALESCE(remarks, '')))                  AS 判定详尽度,                                     -- 求均值表达式：产出「判定详尽度」
  MIN(addtime)                                        AS 首次登记,                                      -- 取最小值表达式：产出「首次登记」
  MAX(addtime)                                        AS 最近登记                                       -- 取最大值表达式：产出「最近登记」
FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                                       -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
GROUP BY COALESCE(NULLIF(TRIM(creator), ''), '未署名')                                                 -- 分组：按 COALESCE(NULLIF(TRIM(creator), ''), '未署名') 汇总
ORDER BY 标注产量 DESC;                                                                                 -- 排序：按标注产量（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）

/* ═══════════════════════════════════════════════════════════════════════════
   §EX · 七项缺口探查（2026-08-09 新增，独立编号，不改动本包任何既有条目）
   ---------------------------------------------------------------------------
   立此一节的缘由：本方案的经济结论目前卡在七处料源缺口上，其中前四项直接
   决定「能否把情景假设换成本平台实测数」。本节只做**探查**，不做统计推断：
   目的是确认「表在不在、字段是什么形状、有没有货」，故一律用三日窗
   dt >= '2026-08-04' AND dt < '2026-08-07' 控扫描量。

   ★ 三条纪律：
     ① 配置类表（限红档位、占成配置、退水档位）多半**不带 dt 分区列**，
        对其加 dt 条件会直接报错。故本节先跑 §EX-00 由元数据判明哪些表有 dt，
        再决定是否施加窗口条件——切勿凭表名猜测。
     ② 每条单独提交，切勿多条一次贴入 Superset（曾引发僵尸查询）。
     ③ 探查结论回填本节注释后，方可据以新立正式取数条目。
   ═══════════════════════════════════════════════════════════════════════════ */

-- ▸ 导出：不需要 —— §EX-00 元数据总览（先看哪些表存在、有无 dt 分区列），屏幕看结果。
SELECT table_name,                                                                                  -- 取列：起始取列子句，本行先列 table_name
       COUNT(*)                                                   AS n_cols,                        -- 计数表达式：产出「n_cols」
       MAX(CASE WHEN column_name = 'dt' THEN 1 ELSE 0 END)        AS has_dt                         -- 取最大值表达式：取用 dt（营业日），产出「has_dt」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
ORDER BY table_name;                                                                                -- 排序：按 table_name 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：has_dt = 0 者为配置类表，后续查询**不得**加 dt 条件。

-- ▸ 导出：不需要 —— §EX-01 处置日志候选表定位（按字段名反查），屏幕看结果。
SELECT table_name,                                                                                  -- 取列：起始取列子句，本行先列 table_name
       GROUP_CONCAT(column_name) AS hit_cols,                                                       -- 分组拼接表达式：产出「hit_cols」
       COUNT(*)                  AS n_hit                                                           -- 计数表达式：产出「n_hit」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (column_name LIKE '%status%'  OR column_name LIKE '%state%'                                   -- 并列条件：限定匹配所给模式
    OR column_name LIKE '%action%'  OR column_name LIKE '%handle%'                                  -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%process%' OR column_name LIKE '%audit%'                                   -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%review%'  OR column_name LIKE '%operator%'                                -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%creator%' OR column_name LIKE '%remark%'                                  -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%reason%'  OR column_name LIKE '%result%')                                 -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
HAVING COUNT(*) >= 3                                                                                -- 分组后过滤：限定行数不少于 3
ORDER BY n_hit DESC;                                                                                -- 排序：按 n_hit（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：命中列数多且同时含「经办人 + 时间 + 结果」三类者，即处置日志的候选。
--       把表名抄下来，逐张跑 §EX-02 验货。

-- ▸ 导出：不需要 —— §EX-02 候选表验货模板（把 <TBL> 换成 §EX-01 的表名），屏幕看结果。
--   ★ 若该表 has_dt = 0，删去 WHERE 整行；有 dt 者保留三日窗。
SELECT COUNT(*) AS n_rows_3d                                                                        -- 取列：计数，产出「n_rows_3d」
FROM ods_mariadb_2b.<TBL>                                                                           -- 取数来源：取自数据集 ods_mariadb_2b
WHERE dt >= '2026-08-04' AND dt < '2026-08-07';                                                     -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
-- 读法：三日窗返回非零行即「有货」；返回 0 须再放宽到全窗确认是历史表还是空表。

-- ▸ 导出：不需要 —— §EX-03 申诉记录候选表定位，屏幕看结果。
SELECT table_name, GROUP_CONCAT(column_name) AS hit_cols, COUNT(*) AS n_hit                         -- 取列：计数、分组拼接，产出「n_hit」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (column_name LIKE '%appeal%'   OR column_name LIKE '%complain%'                               -- 并列条件：限定匹配所给模式
    OR column_name LIKE '%feedback%' OR column_name LIKE '%dispute%'                                -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%ticket%'   OR column_name LIKE '%message%'                                -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%notice%'   OR column_name LIKE '%reply%')                                 -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
ORDER BY n_hit DESC;                                                                                -- 排序：按 n_hit（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：申诉改判率＝误判率的天然实测；须同时具备「原判」与「改判结果」两列方可用。

-- ▸ 导出：不需要 —— §EX-04 荷官局速可算性复核（game_info 三日窗形状），屏幕看结果。
--   ★ 本包 §S-02 已在用 gi004（局开）与 gi006（局收）算每局秒数，
--     故局速的分母**本已具备**：局速 = 3600 ÷ 加权平均每局秒数。
--     本条只复核三日窗内该两列的非空率与取值合理性，为 §EX-05 作准备。
SELECT COUNT(*)                                                          AS n_rounds,               -- 取列：起始取列子句，本行先取「n_rounds」
       SUM(CASE WHEN gi004 IS NULL OR TRIM(gi004) = '' THEN 1 ELSE 0 END) AS n_null_open,           -- 汇总表达式：取用 gi004（局开始时刻），产出「n_null_open」
       SUM(CASE WHEN gi006 IS NULL OR TRIM(gi006) = '' THEN 1 ELSE 0 END) AS n_null_close,          -- 汇总表达式：取用 gi006（开牌时刻），产出「n_null_close」
       MIN(UNIX_TIMESTAMP(gi006) - UNIX_TIMESTAMP(gi004))                 AS min_sec,               -- 取最小值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「min_sec」
       AVG(UNIX_TIMESTAMP(gi006) - UNIX_TIMESTAMP(gi004))                 AS avg_sec,               -- 求均值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「avg_sec」
       MAX(UNIX_TIMESTAMP(gi006) - UNIX_TIMESTAMP(gi004))                 AS max_sec,               -- 取最大值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「max_sec」
       COUNT(DISTINCT gi011)                                              AS n_tables               -- 计数表达式：统计去重个数，产出「n_tables」
FROM ods_mariadb_2b.ods_a168_game_info                                                              -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
WHERE gi001 = '101' AND gi013 = '1'                                                                 -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'，涉 gi001（局主键）
  AND gi004 >= '2026-08-04' AND gi004 < '2026-08-07';                                               -- 并列条件：限定 gi004不少于 '2026-08-04'、gi004小于 '2026-08-07'，涉 gi004（局开始时刻）
-- 读法：avg_sec 落在数十秒量级即口径正确；min_sec 为负或 max_sec 畸大说明有跨日/脏值，
--       须在 §EX-05 加 BETWEEN 过滤。

-- ▸ 导出：需要 —— 存为「数据库/S02b_dealer_pace.csv」（§EX-05 荷官局速·与 S02 同键合并）。
--   ★ 本条**不改动 §S-02 一字**，只单出 dealer_id + 局速两列，R 侧按 dealer_id 并入。
--     权重与 §S-02 的 pace 完全同源（荷官×桌的注单行数），故两列口径一致。
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体（§EX-05）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-05）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（§EX-05）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt,                                                  -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt，涉 dt（营业日）
         b.category, b.bet38, b.bet05, b.bet11, b.bet08,                                            -- 续行：接续上一取列子句，续列 b.category, b.bet38, b.bet05, b.bet11, b.bet08，涉 bet05（会员号）、bet08（下注时间）、bet11（汇率）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         b.bet39, b.eid,                                                                            -- 续行：接续上一取列子句，续列 b.bet39, b.eid，涉 bet39（桌号）、eid（荷官工号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-05）
vd AS (                                                                                             -- 公共表表达式：开启中间结果集 vd，其后各行为其定义体（§EX-05）
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
  FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
  LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
  LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
  LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
  LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
  LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL                                                          -- 并列条件：限定该值非空，涉 eid（荷官工号）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-05）
dtc AS (                     -- 荷官×桌的注单行数（与 §S-02 的权重同源）
  SELECT eid AS dealer_id, bet39 AS table_id, COUNT(*) AS n_rows                                    -- 取列：计数，取用 bet39（桌号）、eid（荷官工号）、dealer_id（荷官工号），产出「n_rows」
  FROM vd GROUP BY eid, bet39                                                                       -- 取数来源：取自本条自建的中间结果集 vd
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-05）
gi AS (                      -- 每局秒数，脏值以 BETWEEN 剔除
  SELECT gi011 AS table_id,                                                                         -- 取列：起始取列子句，本行先取「table_id」，涉 gi011（桌号）
         UNIX_TIMESTAMP(gi006) - UNIX_TIMESTAMP(gi004) AS sec_round                                 -- 取值表达式：取用 gi004（局开始时刻）、gi006（开牌时刻），产出「sec_round」
  FROM ods_mariadb_2b.ods_a168_game_info                                                            -- 取数来源：取自局信息表（靴局、开牌与桌号的时序基准）
  WHERE gi001 = '101' AND gi013 = '1'                                                               -- 过滤条件：限定 gi001等于 '101'、gi013等于 '1'，涉 gi001（局主键）
    AND gi004 >= '2026-03-21' AND gi004 < '2026-08-07'                                              -- 并列条件：限定 gi004不少于 '2026-03-21'、gi004小于 '2026-08-07'，涉 gi004（局开始时刻）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-05）
git AS (                     -- 每桌两矩：局数与总秒数
  SELECT table_id,                                                                                  -- 取列：起始取列子句，本行先列 table_id
         COUNT(sec_round)               AS n_g,                                                     -- 计数表达式：产出「n_g」
         SUM(CAST(sec_round AS DOUBLE)) AS s1                                                       -- 汇总表达式：产出「s1」
  FROM gi                                                                                           -- 取数来源：取自本条自建的中间结果集 gi
  WHERE sec_round BETWEEN 5 AND 600                                                                 -- 过滤条件：限定落入闭区间
  GROUP BY table_id                                                                                 -- 分组：按 table_id 汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§EX-05）
SELECT d.dealer_id,                                                                                 -- 取列：起始取列子句，本行先列 d.dealer_id，涉 dealer_id（荷官工号）
       SUM(d.n_rows * g.s1) / NULLIF(SUM(d.n_rows * CAST(g.n_g AS DOUBLE)), 0)                      -- 汇总表达式：承接上一子句，构成完整语句，属 §EX-05 之取数
         AS 平均每局秒数,                                                                                 -- 取值表达式：产出「平均每局秒数」
       3600.0 * SUM(d.n_rows * CAST(g.n_g AS DOUBLE))                                               -- 取值表达式：汇总
         / NULLIF(SUM(d.n_rows * g.s1), 0)                        AS 局速                             -- 除法或乘法计算：汇总，产出「局速」
FROM dtc d JOIN git g ON g.table_id = d.table_id                                                    -- 取数来源：取自本条自建的中间结果集 dtc，连接键为 g.table_id = d.table_id
GROUP BY d.dealer_id                                                                                -- 分组：按 d.dealer_id 汇总
ORDER BY 局速 DESC;                                                                                   -- 排序：按局速（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：局速单位为「局/小时」，行业常识区间约 50~55 局/小时（真人百家乐）。
--       落在该区间即口径正确；显著偏离须回查 §EX-04 的脏值过滤边界。

-- ▸ 导出：不需要 —— §EX-06 占成配置来源定位（代理层级域），屏幕看结果。
SELECT table_name, GROUP_CONCAT(column_name) AS hit_cols, COUNT(*) AS n_hit                         -- 取列：计数、分组拼接，产出「n_hit」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (column_name LIKE '%comm%'  OR column_name LIKE '%share%'                                     -- 并列条件：限定匹配所给模式
    OR column_name LIKE '%rebate%' OR column_name LIKE '%ratio%'                                    -- 择一条件：限定匹配所给模式，涉 rebate（退水）
    OR column_name LIKE '%rate%'   OR column_name LIKE '%percent%')                                 -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
ORDER BY n_hit DESC;                                                                                -- 排序：按 n_hit（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：找出占成比率的**配置表**（多为 has_dt = 0 的静态表），
--       与 §E02c 的 dailyreport 结算口径交叉验证——两者若不一致，以配置表为准。

-- ▸ 导出：不需要 —— §EX-07 §E02c 交叉校验（本包 §E02c 注释所要求，一直未执行）。
--   ★ dailyreport 日汇总 vs bet02 注单明细的洗码量比对，差异 > 5% 即以 bet02 为准，
--     §E02c 仅取 commission 一列回贴。
SELECT 'dailyreport' AS src,                                                                        -- 取列：起始取列子句，本行先取「src」
       SUM(CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))                                            -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))) AS validbet                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「validbet」
FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                     -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND bet02 = '101' AND category = '1'                                                              -- 并列条件：限定 bet02等于 '101'、category等于 '1'，涉 bet02（游戏类别）
  AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0;                                            -- 并列条件：限定 CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
-- ★ 与下条 §EX-07b 的结果相除即得差异率；两条分开跑，切勿合并提交。

-- ▸ 导出：不需要 —— §EX-07b 交叉校验对照侧（bet02 明细口径），屏幕看结果。
WITH ta AS (                                                                                        -- 公共表表达式：开启中间结果集 ta，其后各行为其定义体（§EX-07b）
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-07b）
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（§EX-07b）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.category, b.bet38,                             -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.category, b.bet38，涉 bet38（测试标识）、dt（营业日）
         b.bet05, b.bet11, b.bet08, b.validbet,                                                     -- 续行：接续上一取列子句，续列 b.bet05, b.bet11, b.bet08, b.validbet，涉 bet05（会员号）、bet08（下注时间）、bet11（汇率）
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-08-04' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-08-04'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§EX-07b）
SELECT 'bet02_detail' AS src,                                                                       -- 取列：起始取列子句，本行先取「src」
       SUM(CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))                                       -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))) AS validbet                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「validbet」
FROM rk r                                                                                           -- 取数来源：取自本条自建的中间结果集 rk
LEFT JOIN ta t1 ON t1.aid = r.bet18                                                                 -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
LEFT JOIN ta t2 ON t2.aid = r.bet19                                                                 -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
LEFT JOIN ta t3 ON t3.aid = r.bet20                                                                 -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
LEFT JOIN ta t4 ON t4.aid = r.bet21                                                                 -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
LEFT JOIN ta t5 ON t5.aid = r.bet22                                                                 -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                  -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
  AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                  -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
  AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                           -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
  AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                          -- 并列条件：限定该值非空，涉 bet08（下注时间）
  AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL;                                     -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN

-- ▸ 导出：不需要 —— §EX-08 退水档位变更史定位（退水弹性的前置），屏幕看结果。
SELECT table_name, GROUP_CONCAT(column_name) AS hit_cols, COUNT(*) AS n_hit                         -- 取列：计数、分组拼接，产出「n_hit」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (column_name LIKE '%level%'  OR column_name LIKE '%grade%'                                    -- 并列条件：限定匹配所给模式
    OR column_name LIKE '%tier%'   OR column_name LIKE '%effect%'                                   -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%valid_from%' OR column_name LIKE '%begin%'                                -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%start%'  OR column_name LIKE '%change%')                                  -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
HAVING COUNT(*) >= 2                                                                                -- 分组后过滤：限定行数不少于 2
ORDER BY n_hit DESC;                                                                                -- 排序：按 n_hit（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：须同时具备「档位」与「生效时点」两类列，方能估流水弹性
--       （SavedRebate − LostGGR 的后半段）；只有当前档位而无变更史者不可用。

-- ▸ 导出：不需要 —— §EX-09 限红档位与营销活动定位，屏幕看结果。
SELECT table_name, GROUP_CONCAT(column_name) AS hit_cols, COUNT(*) AS n_hit                         -- 取列：计数、分组拼接，产出「n_hit」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (column_name LIKE '%limit%'    OR column_name LIKE '%max_bet%'                                -- 并列条件：限定匹配所给模式
    OR column_name LIKE '%min_bet%'  OR column_name LIKE '%promo%'                                  -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%activity%' OR column_name LIKE '%bonus%'                                  -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%gift%'     OR column_name LIKE '%coupon%')                                -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
ORDER BY n_hit DESC;                                                                                -- 排序：按 n_hit（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：限红档位 + 变更时点 = T2 技术型处置的执行记录（与处置日志互补）；
--       营销活动的发放对象与时点 = 赏侧 A/B 的准自然实验底料。

-- ▸ 导出：不需要 —— §EX-10 占成／退水口径直证探针（判「加不加」与「以何为基数」），屏幕看结果。
/* ═══════════════════════════════════════════════════════════════════════════
   §EX-10 · bet23~27（占成）与 bet28~32（退水）的口径直证
   ---------------------------------------------------------------------------
   立此一条的缘由（2026-08-09 实测触发）：
     §E02c 的量纲自适应已判定两组字段皆为**比率**（comm_scale=rate_percent、
     reb_scale=rate_decimal），判据可靠；然而结账反而更离谱——
     κ = 446.04%、ρ = 39.84%，占成为 GGR 的 233 倍、退水为 20.8 倍，
     平台每赚 1 元要付出 253 元，业务上不可能成立。

     由结果倒算原始字段，形状清晰：
       · bet28~32 五级之和 0.3984，**单级均值 7.97%**（惯例 0.3%~1.2%，同量级）
       · bet23~27 五级之和 446.0，**单级均值 89.2%**（总代理分走 GGR 的 70%~90%，恰在惯例内）
     **单级落在惯例区间、五级之和不落** —— 指向两组字段存的是「逐级的分成比例」，
     属**嵌套关系而非并列关系**，相加即重复计算。
     另有一处：占成的**基数应是 GGR**（代理从平台赢利中分成），而非洗码量。

     惟上述判读系由倒算得出，属**推断**而非**直证**。本条以三日窗、单表、无 join
     的探针一次坐实两件事：「加不加」与「以何为基数」。
     ★ 本条不改动 §E02c 一字；其结论回填后，方可据以改写 §E02c 的口径。

   ─── 判读规则（跑完照此对号入座）────────────────────────────────────────
   【一】加不加 —— 看 n_nonzero_comm / n_nonzero_reb 的分布
     · 绝大多数行 = 1        → **「所属层级配置」**：五级中只有该会员所属那一级有值，
                               取非零值即可（用 GREATEST 或 SUM 皆可，因其余为 0），
                               **现行相加式恰好正确**，问题只在基数；
     · 绝大多数行 ≥ 2 且递减 → **「逐级分成比例」**：嵌套关系，
                               **绝不可相加**，须取该会员实际所属层级的那一个值
                               （通常为 LV1，即 bet23 / bet28）；
     · 混合分布              → 须按会员的代理层级深度分别处理，
                               此时应改由 §EX-06 定位的占成**配置表**取值。

   【二】以何为基数 —— 看两组比值落在哪个区间
     · comm_over_ggr  接近 0.70~0.90  → 占成基数为 **GGR**（业界惯例）
     · comm_over_vb   接近 0.01~0.025 → 占成基数为 **洗码量**（信用盘占成 1%~2.5%）
     · reb_over_vb    接近 0.003~0.012→ 退水基数为 **洗码量**（惯例 0.3%~1.2%）
     两者不可能同时成立；哪一个落入惯例区间，即以其为基数。

   【三】交叉佐证 —— lv1_share
     bet23（LV1）占五级之和的比例。若接近 1，佐证「只有 LV1 有值」；
     若明显小于 1 且逐级递减，佐证「逐级分成」。
   ═══════════════════════════════════════════════════════════════════════════ */
WITH r AS (                                                                                         -- 公共表表达式：开启中间结果集 r，其后各行为其定义体（§EX-10）
  SELECT                                                                                            -- 续行：接续上一取列子句，续列 SELECT
    COALESCE(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,6)),0) AS c1,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c1」
    COALESCE(CAST(NULLIF(TRIM(bet24),'') AS DECIMAL(20,6)),0) AS c2,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c2」
    COALESCE(CAST(NULLIF(TRIM(bet25),'') AS DECIMAL(20,6)),0) AS c3,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c3」
    COALESCE(CAST(NULLIF(TRIM(bet26),'') AS DECIMAL(20,6)),0) AS c4,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c4」
    COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,6)),0) AS c5,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c5」
    COALESCE(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,6)),0) AS r1,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「r1」
    COALESCE(CAST(NULLIF(TRIM(bet29),'') AS DECIMAL(20,6)),0) AS r2,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「r2」
    COALESCE(CAST(NULLIF(TRIM(bet30),'') AS DECIMAL(20,6)),0) AS r3,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「r3」
    COALESCE(CAST(NULLIF(TRIM(bet31),'') AS DECIMAL(20,6)),0) AS r4,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「r4」
    COALESCE(CAST(NULLIF(TRIM(bet32),'') AS DECIMAL(20,6)),0) AS r5,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「r5」
    CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))             AS vb,                                -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「vb」
    (CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))                                                  -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
   - CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4)))           AS ggr_row                            -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「ggr_row」
  FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                   -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
  WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                    -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
    AND bet02 = '101' AND category = '1'                                                            -- 并列条件：限定 bet02等于 '101'、category等于 '1'，涉 bet02（游戏类别）
    AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0                                           -- 并列条件：限定 CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) > 0                                           -- 并列条件：限定 CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))大于 0，涉 bet41（有效投注（洗码量））
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§EX-10）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                          AS n_rows,                      -- 计数表达式：产出「n_rows」
  /* 【一】加不加：每行五级中有几个非零 */
  AVG(CASE WHEN c1>0 THEN 1 ELSE 0 END + CASE WHEN c2>0 THEN 1 ELSE 0 END                           -- 求均值表达式：承接上一子句，构成完整语句，属 §EX-10 之取数
    + CASE WHEN c3>0 THEN 1 ELSE 0 END + CASE WHEN c4>0 THEN 1 ELSE 0 END                           -- 加减计算：承接上一子句，构成完整语句，属 §EX-10 之取数
    + CASE WHEN c5>0 THEN 1 ELSE 0 END)                             AS n_nonzero_comm,              -- 加减计算：产出「n_nonzero_comm」
  AVG(CASE WHEN r1>0 THEN 1 ELSE 0 END + CASE WHEN r2>0 THEN 1 ELSE 0 END                           -- 求均值表达式：承接上一子句，构成完整语句，属 §EX-10 之取数
    + CASE WHEN r3>0 THEN 1 ELSE 0 END + CASE WHEN r4>0 THEN 1 ELSE 0 END                           -- 加减计算：承接上一子句，构成完整语句，属 §EX-10 之取数
    + CASE WHEN r5>0 THEN 1 ELSE 0 END)                             AS n_nonzero_reb,               -- 加减计算：产出「n_nonzero_reb」
  /* 【三】LV1 占五级之和的比例 */
  SUM(c1) / NULLIF(SUM(c1+c2+c3+c4+c5),0)                           AS lv1_share_comm,              -- 汇总表达式：产出「lv1_share_comm」
  SUM(r1) / NULLIF(SUM(r1+r2+r3+r4+r5),0)                           AS lv1_share_reb,               -- 汇总表达式：产出「lv1_share_reb」
  /* 逐级均值：看是否递减 */
  AVG(c1) AS avg_c1, AVG(c2) AS avg_c2, AVG(c3) AS avg_c3,                                          -- 求均值表达式：产出「avg_c3」
  AVG(c4) AS avg_c4, AVG(c5) AS avg_c5,                                                             -- 求均值表达式：产出「avg_c5」
  AVG(r1) AS avg_r1, AVG(r2) AS avg_r2, AVG(r3) AS avg_r3,                                          -- 求均值表达式：产出「avg_r3」
  AVG(r4) AS avg_r4, AVG(r5) AS avg_r5,                                                             -- 求均值表达式：产出「avg_r5」
  /* 【二】以何为基数：单级(LV1) 与 五级之和 各自对 GGR 与洗码量的比 */
  SUM(c1) / NULLIF(SUM(ggr_row),0)                                  AS lv1_comm_over_ggr,           -- 汇总表达式：产出「lv1_comm_over_ggr」
  SUM(c1) / NULLIF(SUM(vb),0)                                       AS lv1_comm_over_vb,            -- 汇总表达式：产出「lv1_comm_over_vb」
  SUM(c1+c2+c3+c4+c5) / NULLIF(SUM(ggr_row),0)                      AS sum_comm_over_ggr,           -- 汇总表达式：产出「sum_comm_over_ggr」
  SUM(c1+c2+c3+c4+c5) / NULLIF(SUM(vb),0)                           AS sum_comm_over_vb,            -- 汇总表达式：产出「sum_comm_over_vb」
  SUM(r1) / NULLIF(SUM(vb),0)                                       AS lv1_reb_over_vb,             -- 汇总表达式：产出「lv1_reb_over_vb」
  SUM(r1+r2+r3+r4+r5) / NULLIF(SUM(vb),0)                           AS sum_reb_over_vb,             -- 汇总表达式：产出「sum_reb_over_vb」
  /* 量纲佐证：五级最大值（判小数比率 / 百分数 / 金额） */
  MAX(GREATEST(c1,c2,c3,c4,c5))                                     AS max_comm_row,                -- 取最大值表达式：产出「max_comm_row」
  MAX(GREATEST(r1,r2,r3,r4,r5))                                     AS max_reb_row,                 -- 取最大值表达式：产出「max_reb_row」
  AVG(vb)                                                           AS avg_vb,                      -- 求均值表达式：产出「avg_vb」
  SUM(ggr_row) / NULLIF(SUM(vb),0)                                  AS m_hat                        -- 汇总表达式：产出「m_hat」
FROM r;                                                                                             -- 取数来源：取自本条自建的中间结果集 r
-- 读法速查（照上方【一】【二】【三】三条规则对号入座）：
--   n_nonzero_comm ≈ 1  → 只有所属层级有值，相加无害，问题只在基数；
--   n_nonzero_comm ≥ 2 且 avg_c1 > avg_c2 > … → 逐级分成，绝不可相加，取 c1；
--   lv1_comm_over_ggr 落 0.70~0.90 → 占成基数为 GGR；
--   lv1_reb_over_vb   落 0.003~0.012 → 退水基数为洗码量；
--   m_hat 应与本方案实测的 m = 1.92% 相近，若相去甚远说明 ggr_row 的
--     取向写反（本条以 bet13−bet14 计，即「投注额 − 派彩」＝庄家赢）。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-11 · 第二轮元数据反查（补 §EX-01/03/09 之漏）
   ---------------------------------------------------------------------------
   立此一条的缘由（自陈疏失）：前三轮反查所用的关键词集
   （status/action/handle/audit/review/operator/creator/appeal/limit/promo…）
   漏了「变更留痕」一族——operation / change / log / modify / adjust / trace /
   history / before / after / old / new。`ods_a168_betchange_log` 正因如此
   直到第五轮才偶然现身。本条以第二组关键词把可能漏网者一网打尽。
   ★ 本条只查元数据，不动任何业务数据。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §EX-11 第二轮反查（变更留痕一族关键词），屏幕看结果。
SELECT table_name,                                                                                  -- 取列：起始取列子句，本行先列 table_name
       GROUP_CONCAT(column_name) AS hit_cols,                                                       -- 分组拼接表达式：产出「hit_cols」
       COUNT(*)                  AS n_hit                                                           -- 计数表达式：产出「n_hit」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (column_name LIKE '%operation%' OR column_name LIKE '%operate%'                               -- 并列条件：限定匹配所给模式
    OR column_name LIKE '%change%'    OR column_name LIKE '%modify%'                                -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%adjust%'    OR column_name LIKE '%trace%'                                 -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%history%'   OR column_name LIKE '%before%'                                -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%after%'     OR column_name LIKE 'old\_%'                                  -- 择一条件：限定匹配所给模式
    OR column_name LIKE 'new\_%'      OR column_name LIKE '%_by'                                    -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%_user'      OR column_name LIKE '%admin%'                                 -- 择一条件：限定匹配所给模式
    OR column_name LIKE '%staff%'     OR column_name LIKE '%emp%')                                  -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
HAVING COUNT(*) >= 2                                                                                -- 分组后过滤：限定行数不少于 2
ORDER BY n_hit DESC;                                                                                -- 排序：按 n_hit（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：凡表名含 _log / _history 且同时具「操作人 + 操作时间 + 变更前后值」者，
--       即处置留痕的候选。★ 须辨明两类，切勿混淆：
--         · CDC 变更日志（source_db/source_table/sync_time 三件套齐全）
--           ——记的是「源库某行被改动」，属数据同步层，**不是风控处置记录**；
--         · 业务操作日志（含 operator/admin/staff 类人员列）
--           ——记的才是「谁对谁做了什么」，方可用于回收率与误判率实测。

-- ▸ 导出：不需要 —— §EX-11b 全表名扫描（凡表名含 log/history/record 者），屏幕看结果。
--   ★ 关键词反查依赖列名，若某表列名全不含关键词即会漏网；本条改由**表名**兜底。
SELECT table_name, COUNT(*) AS n_cols                                                               -- 取列：计数，产出「n_cols」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name LIKE 'ods_a168_%'                                                                  -- 并列条件：限定匹配所给模式
  AND (table_name LIKE '%log%'    OR table_name LIKE '%history%'                                    -- 并列条件：限定匹配所给模式
    OR table_name LIKE '%record%' OR table_name LIKE '%trace%'                                      -- 择一条件：限定匹配所给模式
    OR table_name LIKE '%audit%'  OR table_name LIKE '%oper%')                                      -- 择一条件：限定匹配所给模式
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
ORDER BY table_name;                                                                                -- 排序：按 table_name 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：把每张表逐一 DESCRIBE，按 §EX-11 的两类之辨归类。
--       列名与表名双路反查皆无所获者，方可判定「平台无该类记录」。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-12 · 占成基数直证（修正 §EX-10 判据【二】的量纲错误）
   ---------------------------------------------------------------------------
   ★ 自陈：§EX-10 的判据【二】写作 SUM(c1) / SUM(ggr_row)——**分子是百分比、
     分母是金额，量纲不通**，所得 0.052 / 0.00059 等数值无任何意义，不可据以判断。
     正确做法是先算「加权平均占成率」= Σ(占成率 × 基数) ÷ Σ基数，
     再看该率落在哪个业界惯例区间。本条即此修正。
   ★ 另一处自陈：§EX-10 的 m_hat 未除汇率 fx，故得 1.127% 而非实测 1.918%；
     本条一律先除 fx 再聚合，与 §E02c 口径对齐。

   ─── §EX-10 已定案者（不再重复检验）────────────────────────────────────
     · 占成 bet23~27：五级几近相等（均值 87~96）、非递减、max = 100
       → 系**各级代理各自的占成百分比配置**，作用于**不同的基数**，
         **绝不可相加**——相加得 446% 正是把五个不同基数上的比率硬加在一起。
     · 退水 bet28~32：非零率仅 3.4%、max = 1 → 小数比率，且绝大多数会员无配置。

   ─── 本条要判的两件事 ──────────────────────────────────────────────────
   【一】占成的基数是 GGR 还是洗码量？
         看 w_comm_over_ggr / w_comm_over_vb 哪一个落入惯例：
           · 对 GGR 落 0.70~0.90 → 基数为 GGR（总代理分走赢利的大部分）
           · 对洗码量落 0.01~0.025 → 基数为洗码量（信用盘占成惯例）
   【二】该取哪一级？
         输出各级的加权平均率与「有值会员占比」，
         若某一级覆盖率显著高于其余，即该级为实际结算级。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §EX-12 占成基数直证（量纲已修正），屏幕看结果。
WITH r AS (                                                                                         -- 公共表表达式：开启中间结果集 r，其后各行为其定义体（§EX-12）
  SELECT                                                                                            -- 续行：接续上一取列子句，续列 SELECT
    CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))                       AS fx,                      -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
    CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))                       AS vb_raw,                  -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「vb_raw」
    (CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))                                                  -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
   - CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4)))                     AS ggr_raw,                 -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「ggr_raw」
    COALESCE(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,6)),0)           AS c1,                      -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c1」
    COALESCE(CAST(NULLIF(TRIM(bet24),'') AS DECIMAL(20,6)),0)           AS c2,                      -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c2」
    COALESCE(CAST(NULLIF(TRIM(bet25),'') AS DECIMAL(20,6)),0)           AS c3,                      -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c3」
    COALESCE(CAST(NULLIF(TRIM(bet26),'') AS DECIMAL(20,6)),0)           AS c4,                      -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c4」
    COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,6)),0)           AS c5,                      -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「c5」
    COALESCE(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,6)),0)           AS r1                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「r1」
  FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                   -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
  WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                    -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
    AND bet02 = '101' AND category = '1'                                                            -- 并列条件：限定 bet02等于 '101'、category等于 '1'，涉 bet02（游戏类别）
    AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0                                           -- 并列条件：限定 CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) > 0                                           -- 并列条件：限定 CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))大于 0，涉 bet41（有效投注（洗码量））
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-12）
n AS (   -- 一律先除汇率，与 §E02c 口径对齐
  SELECT c1, c2, c3, c4, c5, r1,                                                                    -- 取列：起始取列子句，本行先列 c1, c2, c3, c4, c5, r1
         vb_raw  / fx AS vb,                                                                        -- 取值表达式：产出「vb」
         ggr_raw / fx AS ggr                                                                        -- 取值表达式：取用 ggr（平台毛利），产出「ggr」
  FROM r                                                                                            -- 取数来源：取自本条自建的中间结果集 r
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§EX-12）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                    AS n_rows,                            -- 计数表达式：产出「n_rows」
  SUM(ggr) / NULLIF(SUM(vb),0)                                AS m_hat,   -- 应≈1.92%
  /* 【一】加权平均占成率（÷100 因其为百分数）：分别以 GGR 与洗码量为基数 */
  SUM(c1/100.0 * ggr) / NULLIF(SUM(ggr),0)                    AS w_c1_over_ggr,                     -- 汇总表达式：取用 ggr（平台毛利），产出「w_c1_over_ggr」
  SUM(c1/100.0 * vb)  / NULLIF(SUM(vb),0)                     AS w_c1_over_vb,                      -- 汇总表达式：产出「w_c1_over_vb」
  SUM((c1+c2+c3+c4+c5)/100.0 * ggr) / NULLIF(SUM(ggr),0)      AS w_sum_over_ggr,                    -- 汇总表达式：取用 ggr（平台毛利），产出「w_sum_over_ggr」
  SUM((c1+c2+c3+c4+c5)/100.0 * vb)  / NULLIF(SUM(vb),0)       AS w_sum_over_vb,                     -- 汇总表达式：产出「w_sum_over_vb」
  /* 【二】各级的加权平均率与覆盖率（有值会员占比） */
  SUM(c1/100.0 * ggr) / NULLIF(SUM(ggr),0)                    AS w_lv1,                             -- 汇总表达式：取用 ggr（平台毛利），产出「w_lv1」
  SUM(c2/100.0 * ggr) / NULLIF(SUM(ggr),0)                    AS w_lv2,                             -- 汇总表达式：取用 ggr（平台毛利），产出「w_lv2」
  SUM(c3/100.0 * ggr) / NULLIF(SUM(ggr),0)                    AS w_lv3,                             -- 汇总表达式：取用 ggr（平台毛利），产出「w_lv3」
  SUM(c4/100.0 * ggr) / NULLIF(SUM(ggr),0)                    AS w_lv4,                             -- 汇总表达式：取用 ggr（平台毛利），产出「w_lv4」
  SUM(c5/100.0 * ggr) / NULLIF(SUM(ggr),0)                    AS w_lv5,                             -- 汇总表达式：取用 ggr（平台毛利），产出「w_lv5」
  AVG(CASE WHEN c1>0 THEN 1 ELSE 0 END)                       AS cov_lv1,                           -- 求均值表达式：产出「cov_lv1」
  AVG(CASE WHEN c2>0 THEN 1 ELSE 0 END)                       AS cov_lv2,                           -- 求均值表达式：产出「cov_lv2」
  AVG(CASE WHEN c3>0 THEN 1 ELSE 0 END)                       AS cov_lv3,                           -- 求均值表达式：产出「cov_lv3」
  AVG(CASE WHEN c4>0 THEN 1 ELSE 0 END)                       AS cov_lv4,                           -- 求均值表达式：产出「cov_lv4」
  AVG(CASE WHEN c5>0 THEN 1 ELSE 0 END)                       AS cov_lv5,                           -- 求均值表达式：产出「cov_lv5」
  /* 退水：非零者的加权平均率（以洗码量为基数），并报其覆盖率 */
  SUM(CASE WHEN r1>0 THEN r1 * vb ELSE 0 END)                                                       -- 汇总表达式：承接上一子句，构成完整语句，属 §EX-12 之取数
    / NULLIF(SUM(CASE WHEN r1>0 THEN vb ELSE 0 END),0)        AS w_reb_nonzero,                     -- 除法或乘法计算：汇总，产出「w_reb_nonzero」
  AVG(CASE WHEN r1>0 THEN 1 ELSE 0 END)                       AS cov_reb                            -- 求均值表达式：产出「cov_reb」
FROM n;                                                                                             -- 取数来源：取自本条自建的中间结果集 n
-- 读法：
--   m_hat 应≈1.92%（若仍偏离，说明 dailyreport 与 bet02 的盈亏口径本就不同）；
--   w_c1_over_ggr 落 0.70~0.90 → 占成基数为 GGR，且取 LV1；
--   w_c1_over_vb  落 0.01~0.025 → 占成基数为洗码量；
--   五级 w_lv1~w_lv5 若几近相等而覆盖率亦相近，说明五级是「配置镜像」而非实付，
--     此时占成金额**无法自 dailyreport 求得**，须另寻代理结算表，
--     或在报告中如实标注「占成不可得，γ* 永久锁在过渡口径 m−ρ」。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-13 · betchange_log 验货与风控素材评估
   ---------------------------------------------------------------------------
   DESCRIBE 已确认其列：log_id / operation_type / change_time /
   old_bet01·new_bet01 / old_bet05·new_bet05 / old_bet09·new_bet09 /
   old_ip·new_ip / is_send，另有 source_db / source_table / sync_time。
   ★ 判定：**这是数据同步层的 CDC 变更日志，不是风控处置日志**——
     无经办人、无处置类型语义、无金额、无结果，old/new 成对且带同步三件套。
     故「平台无风控处置记录」的定案**不须推翻**。
   ★ 惟其另有风控价值：注单落库后 **IP 被改**、**玩法被改**、**会员号被改**，
     本身即是可疑事件——这是前十三轮从未纳入的**全新风险素材**。
     本条先验货：三日窗内有多少行、各类变更各占多少、是否含跨会员改动。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §EX-13 betchange_log 三日窗验货，屏幕看结果。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                              AS n_rows_3d,               -- 计数表达式：产出「n_rows_3d」
  COUNT(DISTINCT operation_type)                                        AS n_op_type,               -- 计数表达式：统计去重个数，产出「n_op_type」
  SUM(CASE WHEN NULLIF(TRIM(old_ip),'') IS NOT NULL                                                 -- 汇总表达式：承接上一子句，构成完整语句，属 §EX-13 之取数
            AND NULLIF(TRIM(new_ip),'') IS NOT NULL                                                 -- 并列条件：限定该值非空
            AND TRIM(old_ip) <> TRIM(new_ip) THEN 1 ELSE 0 END)         AS n_ip_changed,            -- 并列条件：产出「n_ip_changed」
  SUM(CASE WHEN NULLIF(TRIM(old_bet05),'') IS NOT NULL                                              -- 汇总表达式：承接上一子句，构成完整语句，属 §EX-13 之取数
            AND NULLIF(TRIM(new_bet05),'') IS NOT NULL                                              -- 并列条件：限定该值非空
            AND TRIM(old_bet05) <> TRIM(new_bet05) THEN 1 ELSE 0 END)   AS n_member_changed,        -- 并列条件：产出「n_member_changed」
  SUM(CASE WHEN NULLIF(TRIM(old_bet09),'') IS NOT NULL                                              -- 汇总表达式：承接上一子句，构成完整语句，属 §EX-13 之取数
            AND NULLIF(TRIM(new_bet09),'') IS NOT NULL                                              -- 并列条件：限定该值非空
            AND TRIM(old_bet09) <> TRIM(new_bet09) THEN 1 ELSE 0 END)   AS n_play_changed,          -- 并列条件：产出「n_play_changed」
  MIN(change_time)                                                      AS t_min,                   -- 取最小值表达式：产出「t_min」
  MAX(change_time)                                                      AS t_max                    -- 取最大值表达式：产出「t_max」
FROM ods_mariadb_2b.ods_a168_betchange_log                                                          -- 取数来源：取自注单变更日志（改单与撤单核查）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07';                                                     -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
-- 读法：n_ip_changed / n_member_changed 若显著非零，即「注单落库后被人工改动」，
--       属高价值风控素材（改 IP 可掩盖同 IP 对打，改会员号可转移注单归属）；
--       若三项皆为零，则本表只是全量镜像同步，无风控价值，可就此结案。

-- ▸ 导出：不需要 —— §EX-13b operation_type 取值普查（判本表究竟记什么），屏幕看结果。
SELECT operation_type, COUNT(*) AS n                                                                -- 取列：计数，产出「n」
FROM ods_mariadb_2b.ods_a168_betchange_log                                                          -- 取数来源：取自注单变更日志（改单与撤单核查）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
GROUP BY operation_type                                                                             -- 分组：按 operation_type 汇总
ORDER BY n DESC;                                                                                    -- 排序：按 n（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：若取值为 INSERT/UPDATE/DELETE 一类，确系 CDC；
--       若为业务语义（如「改单」「撤单」「调整」），则属业务操作日志，价值大增。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-14 · 日志表族逐张验明（§EX-11b 表名扫描的后续）
   ---------------------------------------------------------------------------
   §EX-11b 以**表名**兜底扫描，一举扫出十六张日志族表——远多于三轮**列名**反查
   之所获。此举证明：列名反查会漏，表名扫描才是兜底之道（记此教训）。

   ★ 已结案者，不必再验：
     · ods_a168_betchange_log —— 三日窗 **0 行**、operation_type 无任何取值，
       **空表**，无风控价值，就此结案；
     · ods_a168_age_login / age_sub_login / control_login / emp_login /
       mem_login / opengame_log / realtimelog / log_realtimebet / game_log
       —— 皆属登录与实时流水，前期已验（game_log.ip 系网关 IP，
       与 bet02.ip 仅重叠 2 个），不再重复。

   ★ 本条要验的五张（按价值降序）：
     ① log_age_cash_change（19 列）—— **代理资金变动**。当前唯一可能记载
        「实际付给代理多少钱」者。§EX-12 已定案：占成金额无法自 dailyreport
        求得（bet23~27 系配置百分比，与金额基数无关）；§EX-06 已定案：
        代理占成配置表不存在。**本表是 γ* 解冻的最后一线希望**。
     ② log_mem_change（17 列）—— 会员变更。若含限红、状态、层级变更，
        即为处置留痕，可解回收率与误判率之困。
     ③ change_log（14 列）—— 通用变更日志，须辨明是 CDC 还是业务操作。
     ④ iphistory（12 列）—— IP 历史，与 §C-01 的 IP 链路互补，
        可补「IP 何时变、变了几次」这一维。
     ⑤ SMR_log（13 列）—— 用途未知，列名验明后再判。
     另附两张非日志族但含留痕字段者：
     ⑥ conversion —— 全库唯一带 employee1/employee2 及姓名者，或与专员绩效相关；
     ⑦ tablelimit —— 含 modifyname/modifydate，**全库唯一「谁在何时改了什么」的留痕**，
        虽为桌级而非会员级，仍是限红变更的唯一线索。

   ★ 执行方式：先跑 §EX-14a 一次取得七张表的全部列名（免逐张 DESCRIBE），
     再按 §EX-14b 模板逐张验货（有 dt 者用三日窗，无 dt 者去掉 WHERE）。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §EX-14a 七张候选表的列名一次取齐，屏幕看结果。
SELECT table_name,                                                                                  -- 取列：起始取列子句，本行先列 table_name
       COUNT(*)                  AS n_cols,                                                         -- 计数表达式：产出「n_cols」
       MAX(CASE WHEN column_name = 'dt' THEN 1 ELSE 0 END) AS has_dt,                               -- 取最大值表达式：取用 dt（营业日），产出「has_dt」
       GROUP_CONCAT(column_name) AS all_cols                                                        -- 分组拼接表达式：产出「all_cols」
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name IN ('ods_a168_log_age_cash_change',                                                -- 并列条件：限定落入所列取值，涉代理额度变动日志（占成探查曾用，主体非代理）
                     'ods_a168_log_mem_change',                                                     -- 字面取值：取用会员资料变动日志（批量注册嫌疑旁证）
                     'ods_a168_change_log',                                                         -- 字面取值：取用通用变更日志（修订滞后与快照有效性核验）
                     'ods_a168_iphistory',                                                          -- 字面取值：取用会员登录 IP 历史（IP 结构风险料源）
                     'ods_a168_SMR_log',                                                            -- 字面取值：取用可疑交易报告日志（合规留痕）
                     'ods_a168_conversion',                                                         -- 字面取值：取用币种换算表（金额归一化参照）
                     'ods_a168_tablelimit')                                                         -- 字面取值：取用桌台限红配置表（限红降档措施落点）
GROUP BY table_name                                                                                 -- 分组：按 table_name 汇总
ORDER BY n_cols DESC;                                                                               -- 排序：按 n_cols（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法（三类之辨，逐张对号入座）：
--   · 含 source_db / source_table / sync_time 三件套 → **CDC 变更日志**，
--     记「源库某行被改动」，非业务记录，价值有限；
--   · 含 operator / creator / admin / staff / employee / modifyname 类**人员列**
--     且含金额列 → **业务操作日志**，可用于回收率与误判率实测，价值最高；
--   · 只有 old_/new_ 成对而无人员列 → 变更快照，可用于「变了没有」，
--     但答不了「谁改的、为何改」。

-- ▸ 导出：不需要 —— §EX-14b 逐张验货模板（★ 本条不可直接执行，须先替换表名）。
--   用法：把 <TBL> 换成 §EX-14a 列出的实际表名；该表 has_dt = 0 者，删去 WHERE 整行。
--   ★ 前次 §EX-02 曾因未替换占位符而报语法错——此为模板类条目的固有性质，
--     故本条导出声明已显式标注「不可直接执行」，请先生代入后再跑。
-- SELECT COUNT(*) AS n_rows_3d
-- FROM ods_mariadb_2b.<TBL>
-- WHERE dt >= '2026-08-04' AND dt < '2026-08-07';

-- ▸ 导出：不需要 —— §EX-14c 七张表的三日窗行数一次点清（免逐张替换模板），屏幕看结果。
--   ★ 本条以 UNION ALL 一次问齐，省去七次替换；无 dt 分区者其分支会报错，
--     若整条跑不通，即按 §EX-14a 的 has_dt 结果删去无 dt 者的分支再跑。
SELECT 'log_age_cash_change' AS tbl, COUNT(*) AS n_rows_3d                                          -- 取列：计数，产出「n_rows_3d」
FROM ods_mariadb_2b.ods_a168_log_age_cash_change                                                    -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
UNION ALL                                                                                           -- 结果集合并：与上方结果集纵向合并，不去重（§EX-14c）
SELECT 'log_mem_change', COUNT(*)                                                                   -- 取列：计数
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员资料变动日志（批量注册嫌疑旁证）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
UNION ALL                                                                                           -- 结果集合并：与上方结果集纵向合并，不去重（§EX-14c）
SELECT 'change_log', COUNT(*)                                                                       -- 取列：计数
FROM ods_mariadb_2b.ods_a168_change_log                                                             -- 取数来源：取自通用变更日志（修订滞后与快照有效性核验）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
UNION ALL                                                                                           -- 结果集合并：与上方结果集纵向合并，不去重（§EX-14c）
SELECT 'iphistory', COUNT(*)                                                                        -- 取列：计数
FROM ods_mariadb_2b.ods_a168_iphistory                                                              -- 取数来源：取自会员登录 IP 历史（IP 结构风险料源）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
UNION ALL                                                                                           -- 结果集合并：与上方结果集纵向合并，不去重（§EX-14c）
SELECT 'SMR_log', COUNT(*)                                                                          -- 取列：计数
FROM ods_mariadb_2b.ods_a168_SMR_log                                                                -- 取数来源：取自可疑交易报告日志（合规留痕）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
UNION ALL                                                                                           -- 结果集合并：与上方结果集纵向合并，不去重（§EX-14c）
SELECT 'conversion', COUNT(*)                                                                       -- 取列：计数
FROM ods_mariadb_2b.ods_a168_conversion                                                             -- 取数来源：取自币种换算表（金额归一化参照）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
UNION ALL                                                                                           -- 结果集合并：与上方结果集纵向合并，不去重（§EX-14c）
SELECT 'tablelimit', COUNT(*)                                                                       -- 取列：计数
FROM ods_mariadb_2b.ods_a168_tablelimit                                                             -- 取数来源：取自桌台限红配置表（限红降档措施落点）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07';                                                     -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
-- 读法：三日窗为零者，须再以全窗确认是「历史表」还是「空表」——
--       betchange_log 即为空表之例（三日窗 0 行、operation_type 无取值）。
--       非零者按 §EX-14a 的三类之辨定性，再决定是否立正式取数条目。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-15 · 三张有货日志表的取值形态普查（本方案两大悬案的收官之查）
   ---------------------------------------------------------------------------
   §EX-14c 实测结果（三日窗）：
     · log_age_cash_change  314,653 行  ← 代理资金变动，日均 10.5 万笔
     · iphistory              6,520 行  ← IP 变更史
     · log_mem_change           199 行  ← 会员变更
     · change_log                71 行  ← **全库唯一的业务操作日志**
     · conversion / SMR_log / tablelimit  皆 **0 行**，空表，就此结案
       （tablelimit 虽有 minbet/maxbet/modifyname/modifydate 十全之列却是空表
        ——故限红变更确无记录，T2 技术型处置的效果仍无从回测）

   ★ change_log 的发现，须修正前几轮定案：
     其列为 id / function / content / lv / **operator** / **optime** / ip / utp，
     按 §EX-14a 的三类之辨，**明确属业务操作日志**（含人员列），非 CDC。
     故「平台无风控处置记录」应修正为「**记录有，但极稀少**」
     ——三日 71 行、日均 24 笔，说明后台人工操作确有留痕，
     但风控处置未成规模，与「只标记、未处置」的判断仍然吻合。

   ★ 本节三条，各解一案，皆三日窗、单表、无 join：
     §EX-15a 判 change_log 是否含风控处置语义 → 决定回收率与误判率能否实测
     §EX-15b 判 log_age_cash_change 能否析出占成金额 → **决定 γ* 的生死**
     §EX-15c 判 log_mem_change 是否含限红/状态/层级变更 → 补处置留痕
   ═══════════════════════════════════════════════════════════════════════════ */

-- ▸ 导出：不需要 —— §EX-15a change_log 的 function 取值普查（判有无风控处置语义），屏幕看结果。
SELECT function                              AS fn,                                                 -- 取列：起始取列子句，本行先取「fn」
       COUNT(*)                              AS n,                                                  -- 计数表达式：产出「n」
       COUNT(DISTINCT operator)              AS n_operator,                                         -- 计数表达式：统计去重个数，产出「n_operator」
       MIN(optime)                           AS t_min,                                              -- 取最小值表达式：产出「t_min」
       MAX(optime)                           AS t_max,                                              -- 取最大值表达式：产出「t_max」
       MIN(LENGTH(COALESCE(content,'')))     AS len_min,                                            -- 取最小值表达式：产出「len_min」
       AVG(LENGTH(COALESCE(content,'')))     AS len_avg,                                            -- 求均值表达式：产出「len_avg」
       MAX(LENGTH(COALESCE(content,'')))     AS len_max                                             -- 取最大值表达式：产出「len_max」
FROM ods_mariadb_2b.ods_a168_change_log                                                             -- 取数来源：取自通用变更日志（修订滞后与快照有效性核验）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
GROUP BY function                                                                                   -- 分组：按 function 汇总
ORDER BY n DESC;                                                                                    -- 排序：按 n（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：
--   · function 若含「限红／冻结／调整／风控／稽核」一类语义 → **处置留痕成立**，
--     可据以实测回收率（追回额 ÷ 标记不当得利）与误判率（复核改判占比）；
--   · 若全为「账号管理／参数配置／权限变更」一类 → 与风控无涉，本表另作他用；
--   · len_avg 若达数十字以上，说明 content 记的是操作详情而非代号，
--     可进一步以 §EX-15a2 取样细看。

-- ▸ 导出：不需要 —— §EX-15a2 change_log 内容取样（承上，看 content 究竟写什么），屏幕看结果。
--   ★ 只取二十行，纯为辨明语义；**切勿把 content 原文写入任何交付件**
--     （可能含个人资料），仅供判定用途后即弃。
SELECT function AS fn, lv, operator, optime,                                                        -- 取列：起始取列子句，本行先取「fn」
       SUBSTR(COALESCE(content,''), 1, 120) AS content_head                                         -- 取值表达式：产出「content_head」
FROM ods_mariadb_2b.ods_a168_change_log                                                             -- 取数来源：取自通用变更日志（修订滞后与快照有效性核验）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
ORDER BY optime DESC                                                                                -- 排序：按 optime（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
LIMIT 20;                                                                                           -- 行数上限：限定返回行数——导出上限内只承认排序头部结论
-- 读法：辨明 content 是「自由文本的操作说明」还是「字段变更的结构化记录」。
--   前者可人工复核、可作误判率的申诉替代；后者可自动解析、可作处置事件的断点。

-- ▸ 导出：不需要 —— §EX-15b log_age_cash_change 形态普查（判能否析出占成金额），屏幕看结果。
--   ★ 本条决定 γ* 的生死：§EX-12 已证占成金额无法自 dailyreport 求得
--     （bet23~27 系配置百分比，与金额基数无关）；§EX-06 已证占成配置表不存在。
--     本表是代理资金变动（age = agent），31.5 万行/三日，量级与「逐会员逐日结算占成」相符，
--     **是占成金额的最后一线希望**。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                        AS n_rows,                        -- 计数表达式：产出「n_rows」
  COUNT(DISTINCT op_utp)                                          AS n_op_utp,                      -- 计数表达式：统计去重个数，产出「n_op_utp」
  COUNT(DISTINCT pointtype)                                       AS n_pointtype,                   -- 计数表达式：统计去重个数，产出「n_pointtype」
  /* 逐列的非空率与判别：哪一列是金额（有正有负、跨度大），哪一列是代号 */
  COUNT(DISTINCT lacc01) AS d01, COUNT(DISTINCT lacc02) AS d02,                                     -- 计数表达式：统计去重个数，产出「d02」
  COUNT(DISTINCT lacc03) AS d03, COUNT(DISTINCT lacc04) AS d04,                                     -- 计数表达式：统计去重个数，产出「d04」
  COUNT(DISTINCT lacc05) AS d05, COUNT(DISTINCT lacc06) AS d06,                                     -- 计数表达式：统计去重个数，产出「d06」
  COUNT(DISTINCT lacc07) AS d07, COUNT(DISTINCT lacc08) AS d08,                                     -- 计数表达式：统计去重个数，产出「d08」
  COUNT(DISTINCT lacc09) AS d09, COUNT(DISTINCT lacc10) AS d10,                                     -- 计数表达式：统计去重个数，产出「d10」
  COUNT(DISTINCT lacc11) AS d11,                                                                    -- 计数表达式：统计去重个数，产出「d11」
  /* 数值化后的正负分布：金额列的特征是「有正有负」 */
  SUM(CASE WHEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)) < 0 THEN 1 ELSE 0 END) AS neg06,     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「neg06」
  SUM(CASE WHEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)) > 0 THEN 1 ELSE 0 END) AS pos06,     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「pos06」
  AVG(ABS(CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4))))        AS abs_avg06,                     -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「abs_avg06」
  SUM(CASE WHEN CAST(NULLIF(TRIM(lacc07),'') AS DECIMAL(20,4)) < 0 THEN 1 ELSE 0 END) AS neg07,     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「neg07」
  SUM(CASE WHEN CAST(NULLIF(TRIM(lacc07),'') AS DECIMAL(20,4)) > 0 THEN 1 ELSE 0 END) AS pos07,     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「pos07」
  AVG(ABS(CAST(NULLIF(TRIM(lacc07),'') AS DECIMAL(20,4))))        AS abs_avg07,                     -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「abs_avg07」
  SUM(CASE WHEN CAST(NULLIF(TRIM(lacc08),'') AS DECIMAL(20,4)) < 0 THEN 1 ELSE 0 END) AS neg08,     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「neg08」
  SUM(CASE WHEN CAST(NULLIF(TRIM(lacc08),'') AS DECIMAL(20,4)) > 0 THEN 1 ELSE 0 END) AS pos08,     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「pos08」
  AVG(ABS(CAST(NULLIF(TRIM(lacc08),'') AS DECIMAL(20,4))))        AS abs_avg08                      -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「abs_avg08」
FROM ods_mariadb_2b.ods_a168_log_age_cash_change                                                    -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07';                                                     -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
-- 读法：
--   · d0x 若接近行数 → 该列是流水号或时间戳；若为个位数 → 是类型代号；
--     若居中（数千至数万）→ 是金额或账号；
--   · negXX / posXX 皆显著非零 → 该列是**金额**（资金有进有出）；
--   · abs_avgXX 与本方案的日均占成量级（GGR × 约 0.9 ÷ 会员数）相近者，即占成列。
--   ★ 关键在 op_utp 与 pointtype：其取值若能区分「占成入账」与「充值／提现／调整」，
--     则占成金额可自本表按类型筛出——γ* 即可解冻。

-- ▸ 导出：不需要 —— §EX-15b2 op_utp × pointtype 取值交叉表（承上，判类型语义），屏幕看结果。
SELECT op_utp, pointtype, COUNT(*) AS n,                                                            -- 取列：起始取列子句，本行先取「n」
       AVG(ABS(CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)))) AS abs_avg06                        -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「abs_avg06」
FROM ods_mariadb_2b.ods_a168_log_age_cash_change                                                    -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
GROUP BY op_utp, pointtype                                                                          -- 分组：按 op_utp, pointtype 汇总
ORDER BY n DESC                                                                                     -- 排序：按 n（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
LIMIT 40;                                                                                           -- 行数上限：限定返回行数——导出上限内只承认排序头部结论
-- 读法：找出「笔数与会员×日量级相当、金额量级与 GGR×占成率相当」的那一组类型码，
--       即为占成结算。若无任何一组符合，则占成确不入本表，γ* 应判永久锁死。

-- ▸ 导出：不需要 —— §EX-15c log_mem_change 形态普查（判是否含限红/状态/层级变更），屏幕看结果。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                        AS n_rows,                        -- 计数表达式：产出「n_rows」
  COUNT(DISTINCT lmc01) AS d01, COUNT(DISTINCT lmc02) AS d02,                                       -- 计数表达式：统计去重个数，产出「d02」
  COUNT(DISTINCT lmc03) AS d03, COUNT(DISTINCT lmc04) AS d04,                                       -- 计数表达式：统计去重个数，产出「d04」
  COUNT(DISTINCT lmc05) AS d05, COUNT(DISTINCT lmc06) AS d06,                                       -- 计数表达式：统计去重个数，产出「d06」
  COUNT(DISTINCT lmc07) AS d07, COUNT(DISTINCT lmc08) AS d08,                                       -- 计数表达式：统计去重个数，产出「d08」
  COUNT(DISTINCT lmc09) AS d09, COUNT(DISTINCT lmc10) AS d10,                                       -- 计数表达式：统计去重个数，产出「d10」
  COUNT(DISTINCT lmc11) AS d11,                                                                     -- 计数表达式：统计去重个数，产出「d11」
  MIN(LENGTH(COALESCE(lmc03,''))) AS len_min03,                                                     -- 取最小值表达式：产出「len_min03」
  AVG(LENGTH(COALESCE(lmc03,''))) AS len_avg03,                                                     -- 求均值表达式：产出「len_avg03」
  MAX(LENGTH(COALESCE(lmc03,''))) AS len_max03,                                                     -- 取最大值表达式：产出「len_max03」
  MIN(LENGTH(COALESCE(lmc04,''))) AS len_min04,                                                     -- 取最小值表达式：产出「len_min04」
  AVG(LENGTH(COALESCE(lmc04,''))) AS len_avg04,                                                     -- 求均值表达式：产出「len_avg04」
  MAX(LENGTH(COALESCE(lmc04,''))) AS len_max04                                                      -- 取最大值表达式：产出「len_max04」
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员资料变动日志（批量注册嫌疑旁证）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07';                                                     -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
-- 读法：取值种数为个位数者是类型代号，须再取样看其字面；
--       长度均值达数十者是文本说明，可作变更详情。
--       本表仅 199 行/三日，纵有处置语义亦属零星，宜作佐证而非主料。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-16 · 收官三条（处置事件落地 · 占成末关 · 会员变更取样）
   ---------------------------------------------------------------------------
   §EX-15 实测带来两项决定性结果，先记明，再据以立条：

   ★★ 结果一：**「平台无风控处置记录」的定案正式推翻**。
      ods_a168_change_log 经 content 取样，证实为**业务操作日志**，
      三日 71 笔中含三类实打实的风控处置动作：
        · realtimebet（23 笔·5 名操作员）
          `Kick Out : livegame07 kick ID = 294099236_INF`
          —— **踢出玩家**，kick ID 即会员账号，**可与 bet02 关联**；
        · newrisk_manager（24 笔·1 名操作员）
          `UPDATE sn:159 gid:101 tableid:912 status: 0=>1`
          —— **风控管理器桌台开关**，gid:101 正是百家乐；
        · gameset（11 笔·2 名操作员）
          `UPDATE 114735231_2 gi007=…=>cancel gi012:6=>-1`
          —— **取消局**，涉及注单结算。
      另有 MemberGameWhiteList（IP 白名单增删）、receiptswitch（收单开关）。
      故应改述为：**处置记录有，形态明确，惟量极小**（三日 71 笔、全窗约 3,300 笔），
      与「只标记、未成规模处置」的判断仍然吻合。

   ★★ 结果二：**占成之案未结，是我问错了列**（自陈疏失）。
      §EX-15b 以 op_utp / pointtype 为类型码，实测 op_utp 仅 2 种、pointtype 仅 1 种，
      **皆无区分力**；真正的类型码在 **lacc02（4 种取值）**，我未纳入普查。
      lacc06 确是金额列（负 142,964 ＋ 正 171,689 ＝ 全部 314,653 行，有进有出），
      但日均金额 20.09 亿，为日均 GGR（516 万）的 389 倍
      —— 故其为**账户余额变动全量**（含充提转账），非单纯占成。
      须按 lacc02 × lacc04 分类后再判。
   ═══════════════════════════════════════════════════════════════════════════ */

-- ▸ 导出：不需要 —— §EX-16a log_age_cash_change 按真类型码分组（占成末关），屏幕看结果。
--   ★ 判据：找出「笔数与代理数×日相当、金额与 GGR×占成率相当」的那一类。
--     本方案实测：日均 GGR ≈ 516 万；若代理链分走约八成，日均占成应在 400 万上下。
--     某类若「笔数 × 均额 ≈ 400 万/日」，即为占成结算；
--     若无任何一类符合，则占成确不入本表，γ* 应判**永久锁死**。
SELECT lacc02, lacc04,                                                                              -- 取列：起始取列子句，本行先列 lacc02, lacc04
       COUNT(*)                                                          AS n,                      -- 计数表达式：产出「n」
       SUM(CASE WHEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)) > 0                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                THEN 1 ELSE 0 END)                                       AS n_pos,                  -- 分支取值：产出「n_pos」
       SUM(CASE WHEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)) < 0                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                THEN 1 ELSE 0 END)                                       AS n_neg,                  -- 分支取值：产出「n_neg」
       AVG(ABS(CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4))))          AS abs_avg,                -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「abs_avg」
       SUM(CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)))               AS sum_signed,             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「sum_signed」
       SUM(ABS(CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4))))          AS sum_abs,                -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「sum_abs」
       COUNT(DISTINCT lacc03)                                            AS d_lacc03,               -- 计数表达式：统计去重个数，产出「d_lacc03」
       COUNT(DISTINCT lacc05)                                            AS d_lacc05                -- 计数表达式：统计去重个数，产出「d_lacc05」
FROM ods_mariadb_2b.ods_a168_log_age_cash_change                                                    -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
GROUP BY lacc02, lacc04                                                                             -- 分组：按 lacc02, lacc04 汇总
ORDER BY n DESC;                                                                                    -- 排序：按 n（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：
--   · sum_abs ÷ 3 ≈ 400 万者，即占成结算的候选类；
--   · n_pos 与 n_neg 一面倒（几乎全正或全负）→ 是单向流水（入账或出账），
--     占成对代理而言应**几乎全为入账（正）**；
--   · d_lacc03 若与代理数量级相当（数百至数千），则 lacc03 是代理账号列。

-- ▸ 导出：需要 —— 存为「数据库/EV01_disposal_events.csv」（§EX-16b 真实处置事件表·全窗）。
/* ═══════════════════════════════════════════════════════════════════════════
   §EX-16b · 处置事件表 —— 本方案第一份**真实**的处置留痕
   ---------------------------------------------------------------------------
   ★ 何以要紧：本方案此前一切「处置」皆属拟议（名单、幅度、封顶），
     从未有过一笔真实发生的处置。本表把 change_log 中的三类动作逐笔解析出来，
     使以下四事**首次成为可能**：
       ① **DID 断点**——踢出／取消局的时点即处置事件的时间断点；
       ② **误判率实测**——被踢出者其后是否申诉、是否照常投注，可作误判的行为证据；
       ③ **回收率观察**——取消局（gi012=>-1）直接对应注单作废，是最硬的「追回」；
       ④ **名单对账**——**平台过去踢出的那些人，本方案的名单圈住了几个？**
          这是金标准之外的**第二套独立验证**，比任何统计推断都硬。
   ★ 解析口径（依 §EX-15a2 实测的 content 字面）：
     · Kick Out : livegame07 kick ID = 294099236_INF
         → 取 ' = ' 之后为会员账号；' : ' 与 ' kick' 之间为桌台标识
     · UPDATE sn:159 gid:101 tableid:912 status: 0=>1
         → 取 tableid: 之后的数字为桌号；status 之后为前后值
     · UPDATE 114735231_2 gi007=…=>cancel gi012:6=>-1
         → 取 UPDATE 之后至第一个空格为局标识；含 'cancel' 即取消局
   ★ 全窗取，不设三日窗——处置事件本就稀少，须全量方有分析价值。
   ★ 隐私：content 原文**不入交付件**，只出解析后的结构化字段。
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  CAST(id AS STRING)                                                  AS event_id,                  -- 取值表达式：产出「event_id」
  optime                                                              AS event_time,                -- 取值表达式：产出「event_time」
  dt                                                                  AS event_date,                -- 取值表达式：取用 dt（营业日），产出「event_date」
  function                                                            AS fn,                        -- 取值表达式：产出「fn」
  CAST(operator AS STRING)                                            AS operator,                  -- 取值表达式：产出「operator」
  ip                                                                  AS operator_ip,               -- 取值表达式：产出「operator_ip」
  CASE                                                                                              -- 条件分支：开启分支判定，其后逐行列出条件与取值（§EX-16b）
    WHEN function = 'realtimebet'         AND content LIKE 'Kick Out%' THEN 'kick_out'              -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
    WHEN function = 'newrisk_manager'                                  THEN 'table_switch'          -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
    WHEN function = 'gameset'             AND content LIKE '%cancel%'  THEN 'round_cancel'          -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
    WHEN function = 'gameset'                                          THEN 'round_edit'            -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
    WHEN function = 'MemberGameWhiteList' AND content LIKE 'ADD%'      THEN 'whitelist_add'         -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
    WHEN function = 'MemberGameWhiteList'                              THEN 'whitelist_del'         -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
    ELSE 'other' END                                                  AS event_type,                -- 兜底取值：产出「event_type」
  /* 会员账号：仅 kick_out 有，取 ' = ' 之后 */
  CASE WHEN content LIKE 'Kick Out%' AND content LIKE '% = %'                                       -- 条件分支：承接上一子句，构成完整语句，属 §EX-16b 之取数
       THEN TRIM(SUBSTRING(content, INSTR(content, ' = ') + 3))                                     -- 分支取值：承接上一子句，构成完整语句，属 §EX-16b 之取数
       ELSE NULL END                                                  AS member_login,              -- 兜底取值：产出「member_login」
  /* 桌台：kick_out 取 ':' 与 ' kick' 之间；table_switch 取 'tableid:' 之后 */
  CASE                                                                                              -- 条件分支：开启分支判定，其后逐行列出条件与取值（§EX-16b）
    WHEN content LIKE 'Kick Out%' AND content LIKE '% kick %'                                       -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
      THEN TRIM(SUBSTRING(content, INSTR(content, ':') + 1,                                         -- 分支取值：承接上一子句，构成完整语句，属 §EX-16b 之取数
                          INSTR(content, ' kick ') - INSTR(content, ':') - 1))                      -- 取值表达式：承接上一子句，构成完整语句，属 §EX-16b 之取数
    WHEN content LIKE '%tableid:%'                                                                  -- 分支判定：承接上一子句，构成完整语句，属 §EX-16b 之取数
      THEN TRIM(SUBSTRING(content, INSTR(content, 'tableid:') + 8, 8))                              -- 分支取值：承接上一子句，构成完整语句，属 §EX-16b 之取数
    ELSE NULL END                                                     AS table_ref,                 -- 兜底取值：产出「table_ref」
  /* 局标识：round_cancel / round_edit 取 'UPDATE ' 之后至下一空格 */
  CASE WHEN function = 'gameset' AND content LIKE 'UPDATE %'                                        -- 条件分支：承接上一子句，构成完整语句，属 §EX-16b 之取数
       THEN TRIM(SUBSTRING(content, 8,                                                              -- 分支取值：承接上一子句，构成完整语句，属 §EX-16b 之取数
                 INSTR(SUBSTRING(content, 8), ' ') - 1))                                            -- 取值表达式：承接上一子句，构成完整语句，属 §EX-16b 之取数
       ELSE NULL END                                                  AS round_ref,                 -- 兜底取值：产出「round_ref」
  /* 白名单 IP */
  CASE WHEN content LIKE '%white_list:%'                                                            -- 条件分支：承接上一子句，构成完整语句，属 §EX-16b 之取数
       THEN TRIM(SUBSTRING(content, INSTR(content, 'white_list:') + 11))                            -- 分支取值：承接上一子句，构成完整语句，属 §EX-16b 之取数
       ELSE NULL END                                                  AS whitelist_ip,              -- 兜底取值：产出「whitelist_ip」
  CASE WHEN content LIKE '%cancel%' THEN 1 ELSE 0 END                 AS is_cancel,                 -- 条件分支：产出「is_cancel」
  LENGTH(COALESCE(content, ''))                                       AS content_len                -- 取值表达式：产出「content_len」
FROM ods_mariadb_2b.ods_a168_change_log                                                             -- 取数来源：取自通用变更日志（修订滞后与快照有效性核验）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND function IN ('realtimebet','newrisk_manager','gameset','MemberGameWhiteList')                 -- 并列条件：限定落入所列取值
ORDER BY optime;                                                                                    -- 排序：按 optime 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ★ R 侧用法（三步，按价值降序）：
     ① 名单对账：以 member_login 关联会员主档取 member_id，再与回测各折的
        罚池名单求交——**平台踢出的人，本方案圈住了几成？** 圈中率即第二套 Lift；
     ② 处置断点：以 event_time 为断点，比较该会员处置前后 14 日的洗码量与净赢，
        得「踢出的即时经济效果」——这是回收率的**首个实测样本**；
     ③ 取消局：round_ref 关联 bet02 的 bet03|bet04|bet39，取其注单金额，
        即「作废挽回额」，是最硬的追回口径。
   ★ 数量预期：三日 71 笔，全窗（139 日）约 3,300 笔，其中 kick_out 约千余笔。
     量小，故一切结论须配 Wilson 或 Jeffreys 区间，不得作点估计陈述。 */

-- ▸ 导出：不需要 —— §EX-16c log_mem_change 类型码取样（判会员变更的语义），屏幕看结果。
--   ★ lmc03 有 6 种取值且长度恒为 1 → 是类型代号；lmc04 有 3 种、长度 3~12 → 亦为代号或短标签。
--     本条取样看其字面，判是否含限红／状态／层级变更。
SELECT lmc03, lmc04, COUNT(*) AS n,                                                                 -- 取列：起始取列子句，本行先取「n」
       MIN(lmc09) AS t_min, MAX(lmc09) AS t_max,                                                    -- 取最小值表达式：取最大值，产出「t_max」
       SUBSTR(MAX(COALESCE(lmc05,'')), 1, 60) AS sample05,                                          -- 取值表达式：取最大值，产出「sample05」
       SUBSTR(MAX(COALESCE(lmc06,'')), 1, 60) AS sample06                                           -- 取值表达式：取最大值，产出「sample06」
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员资料变动日志（批量注册嫌疑旁证）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
GROUP BY lmc03, lmc04                                                                               -- 分组：按 lmc03, lmc04 汇总
ORDER BY n DESC;                                                                                    -- 排序：按 n（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：若某类型码对应的 sample 字面含「限红／額度／狀態／層級」一类，
--       即为处置留痕，可与 §EX-16b 的事件表合并；
--       若全为「密碼／暱稱／電話」一类，则属账户资料维护，与风控无涉。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-17 · 两大悬案的翻案之查（占成自算 · 处置留痕升格）
   ---------------------------------------------------------------------------
   §EX-16 实测带来一断一转，先记明：

   ★★ 断：**占成金额在本平台 ODS 层「读」不到**（三路俱绝，已定案）
      · §EX-12  dailyreport.bet23~27 是配置百分比，与金额基数无关
                （以 GGR 加权得 95.7%、以洗码量加权得 95.9%，两者几乎相等
                 ——同一组数换个基数几乎不变，即证其不依附任何金额）；
      · §EX-06  代理占成配置表不存在（命中者皆为提现费率、汇率、佣金模式标记）；
      · §EX-16a log_age_cash_change 十一类无一符合——主类（lacc02=7,lacc04=0）
                占 99.8% 行数，日均 19.26 亿，为目标（约 413 万）的 **467 倍**，
                正负比 1.2:1、涉 67,779 个账号，系**账户流水全量**
                （充值／提现／转账／上下分），非占成结算。

   ★★ 转：**但 §EX-16c 意外揭出 `ag012` —— 占成率的配置源头**
      log_mem_change 的 lmc05/lmc06 存**完整 SQL 原文**，实测可见：
        `UPDATE agent_dtl SET ag012 = '94.00' … WHERE ag001=56608 AND ag002=101`
        `UPDATE agent_dtl SET ag012 = '95.00' … WHERE ag001=56544 AND ag002=101`
        另见 95.50、96.00
      —— **与 bet23~27 实测的 96.07／96.03／95.71 量级完全吻合**。
      故 `agent_dtl.ag012` 是按「代理 × 游戏类别」分设的**正式占成率配置**，
      比 dailyreport 的逐日镜像更权威。
      **由此另辟一路：占成不再「读」，改为「算」**——
        占成金额 = Σ( 该代理线 GGR × 该线 ag012 )
      本节 §EX-17a 即验此路是否走得通。

   ★★ 另一转：**限红变更确有记录，前判须推翻**
      §EX-16c 实测 lmc11 摘要可见 `mem022: =>;101-mem015:350=>21;`
      —— mem015 由 350 改为 21，**正是限红降档的实证**。
      §EX-09 断言「限红档位与变更记录不存在」，系因 tablelimit 为空表而误判；
      真相是：限红变更不记在 tablelimit（桌级配置），而记在
      log_mem_change（会员级变更）。此判须更正。
      另见 `UPDATE member SET mem016='N' WHERE mem001 IN (…百余个会员号…)`
      —— **批量停用会员**，一次涉百余人，是全库规模最大的处置动作。
      故 §EX-17b 把 log_mem_change 升格为**第二份处置事件表**，
      其价值更甚于 EV01：含限额变更(mem015)、批量停用(mem016)、状态变更(mem017)，
      且**带前后值**，可直接算回收率。
   ═══════════════════════════════════════════════════════════════════════════ */

-- ▸ 导出：不需要 —— §EX-17a agent_dtl 验货（占成率配置源头，判占成能否自算），屏幕看结果。
--   ★ 本条决定 γ* 能否解冻：若 ag012 在 gid=101 上覆盖齐备，
--     则占成可由「线 GGR × ag012」自算，无须再求金额列。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                              AS n_rows,                  -- 计数表达式：产出「n_rows」
  COUNT(DISTINCT ag001)                                                 AS n_agent,                 -- 计数表达式：统计去重个数，产出「n_agent」
  COUNT(DISTINCT ag002)                                                 AS n_game,                  -- 计数表达式：统计去重个数，产出「n_game」
  SUM(CASE WHEN CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                           -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           THEN 1 ELSE 0 END)                                           AS n_bacc,                  -- 分支取值：产出「n_bacc」
  SUM(CASE WHEN CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                           -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
            AND CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) > 0                                   -- 并列条件：限定 CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4))大于 0，涉 ag012（代理留成率）
           THEN 1 ELSE 0 END)                                           AS n_bacc_has_rate,         -- 分支取值：产出「n_bacc_has_rate」
  MIN(CASE WHEN CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                           -- 取最小值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           THEN CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) END)      AS min_rate,                -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「min_rate」
  AVG(CASE WHEN CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                           -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           THEN CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) END)      AS avg_rate,                -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「avg_rate」
  MAX(CASE WHEN CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                           -- 取最大值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           THEN CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) END)      AS max_rate,                -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「max_rate」
  AVG(CASE WHEN CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                           -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           THEN CAST(NULLIF(TRIM(ag003),'') AS DECIMAL(10,4)) END)      AS avg_ag003                -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「avg_ag003」
FROM ods_mariadb_2b.ods_a168_agent_dtl;                                                             -- 取数来源：取自代理配置明细（退水率与代理留成率的真值所在）
-- 读法：
--   · n_bacc_has_rate ÷ n_agent 若接近 1 → 每个代理在百家乐上皆有占成率配置，
--     占成可自算：占成 = Σ(线 GGR × ag012/100)；
--   · avg_rate 若落 90~96 → 与 bet23~27 实测量级吻合，佐证同源；
--   · ag003 若恒为 0.00 → 该列非退水率，须另寻；若有分布，则可能是退水配置。
--   ★ 本表若无 dt 分区（配置表常无），上式已不带 dt 条件，可直接跑；
--     若报「Column 'dt' cannot be resolved」以外的分区错，再按 §EX-00 结果调整。

-- ▸ 导出：不需要 —— §EX-17a2 agent_dtl 占成率分布（承上，看档位形态），屏幕看结果。
SELECT CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) AS rate_bacc,                                  -- 取列：起始取列子句，本行先取「rate_bacc」，涉 ag012（代理留成率）
       COUNT(*)                                      AS n_agent,                                    -- 计数表达式：产出「n_agent」
       COUNT(DISTINCT ag001)                         AS d_agent                                     -- 计数表达式：统计去重个数，产出「d_agent」
FROM ods_mariadb_2b.ods_a168_agent_dtl                                                              -- 取数来源：取自代理配置明细（退水率与代理留成率的真值所在）
WHERE CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                                     -- 过滤条件：限定 CAST(NULLIF(TRIM(ag002),'') AS INT)等于 101
GROUP BY CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4))                                              -- 分组：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
ORDER BY n_agent DESC                                                                               -- 排序：按 n_agent（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
LIMIT 40;                                                                                           -- 行数上限：限定返回行数——导出上限内只承认排序头部结论
-- 读法：档位若集中于 94~96 数档 → 系「代理留成率」（代理拿走的比例）；
--       若集中于 4~6 数档 → 系「平台留成率」，二者互为补数，须辨明方向。
--   ★ 方向之辨至关紧要（2026-08-10 依先生指正更正措辞）：
--     · 若 ag012=95 记的是**代理的份额** → 代理拿 95%、**平台仅拿 5%** → κ = 0.95×m；
--     · 若 ag012=95 记的是**平台的份额** → 代理只拿 5%、**平台拿 95%** → κ = 0.05×m。
--     两者相差二十倍且正负异号，须实证定夺。
--   ★★ 【已定案】§EX-19b 层级单调性检验（14,112 对父子）实测：
--       上级 > 下级 61.64%、上级 = 下级 38.30%、**上级 < 下级仅 0.06%**
--       —— 非降序达 99.94%，即**严格的逐级不增**，正是「逐级抽成」之形。
--       故 **ag012 记的是「代理留成率」：上游先抽，下游只得其余**。
--       κ = ag012 × m ⇒ 以下级均值 86.53% 计，κ = 1.6596%，
--       γ* = m − ρ − κ = 1.918% − 0.349% − 1.660% = **−0.091%** ⇒ 赏侧须锁死。

-- ▸ 导出：需要 —— 存为「数据库/EV02_member_disposal.csv」（§EX-17b 会员级处置事件表·全窗）。
/* ═══════════════════════════════════════════════════════════════════════════
   §EX-17b · 会员级处置事件表 —— 比 EV01 更完整的处置留痕
   ---------------------------------------------------------------------------
   ★ 何以更要紧：EV01（change_log）记的是踢出、桌台开关、取消局，属**即时干预**；
     本表（log_mem_change）记的是**账户级处置**，且**带前后值**：
       · mem015 限额变更（实测 350=>21，即限红降档）
       · mem016 会员停用（实测一次批量停用百余人）
       · mem017 会员状态（changestatus 类）
       · mem020 其他开关（实测 Y=>N）
     带前后值意味着：**处置的力度可量化**（降了多少额度），
     而非仅知「做过处置」——这是回收率实测的必要条件。
   ★ 解析口径（依 §EX-16c 实测的 lmc11 摘要字面）：
       lmc11 形如 `mem022: =>;101-mem015:350=>21;` 或 `age016:Y=>N;` 或 `mem020 Y=>N;`
       故以 LIKE 判别字段名，以 '=>' 为前后值分隔。
   ★ 隐私纪律：lmc05/lmc06 存完整 SQL 原文（含账号、密码哈希、暱称），
     **一律不入交付件**；本表只出解析后的结构化字段与摘要 lmc11 的截断片段。
   ★ 全窗取，不设三日窗——处置事件稀少，须全量方有分析价值。
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  CAST(lmc01 AS STRING)                                               AS event_id,                  -- 取值表达式：产出「event_id」
  dt                                                                  AS event_date,                -- 取值表达式：取用 dt（营业日），产出「event_date」
  lmc09                                                               AS event_time,                -- 取值表达式：产出「event_time」
  lmc03                                                               AS type_code,                 -- 取值表达式：产出「type_code」
  lmc04                                                               AS action,                    -- 取值表达式：产出「action」
  CAST(lmc02 AS STRING)                                               AS operator,                  -- 取值表达式：产出「operator」
  /* 处置类别：依 lmc11 摘要中出现的字段名判别 */
  CASE                                                                                              -- 条件分支：开启分支判定，其后逐行列出条件与取值（§EX-17b）
    WHEN lmc11 LIKE '%mem015%' THEN 'limit_change'      -- 限额变更（限红降档）
    WHEN lmc11 LIKE '%mem016%' THEN 'member_disable'    -- 会员停用
    WHEN lmc11 LIKE '%mem017%' THEN 'member_status'     -- 会员状态
    WHEN lmc11 LIKE '%mem020%' THEN 'member_switch'     -- 会员开关
    WHEN lmc11 LIKE '%age015%' OR lmc11 LIKE '%age016%' THEN 'agent_disable'                        -- 分支判定：承接上一子句，构成完整语句，属 §EX-17b 之取数
    WHEN lmc11 LIKE '%ag012%'  THEN 'commission_change' -- 占成率变更
    WHEN lmc11 LIKE '%opengame%' THEN 'game_access'                                                 -- 分支判定：承接上一子句，构成完整语句，属 §EX-17b 之取数
    ELSE 'other' END                                                  AS event_type,                -- 兜底取值：产出「event_type」
  /* 前后值：以 '=>' 分隔，取其两侧各 24 字 */
  CASE WHEN lmc11 LIKE '%=>%'                                                                       -- 条件分支：承接上一子句，构成完整语句，属 §EX-17b 之取数
       THEN TRIM(SUBSTRING(lmc11,                                                                   -- 分支取值：承接上一子句，构成完整语句，属 §EX-17b 之取数
              GREATEST(INSTR(lmc11, ':') + 1, 1),                                                   -- 取值表达式：承接上一子句，构成完整语句，属 §EX-17b 之取数
              INSTR(lmc11, '=>') - GREATEST(INSTR(lmc11, ':') + 1, 1)))                             -- 取值表达式：承接上一子句，构成完整语句，属 §EX-17b 之取数
       ELSE NULL END                                                  AS val_before,                -- 兜底取值：产出「val_before」
  CASE WHEN lmc11 LIKE '%=>%'                                                                       -- 条件分支：承接上一子句，构成完整语句，属 §EX-17b 之取数
       THEN TRIM(SUBSTRING(lmc11, INSTR(lmc11, '=>') + 2, 24))                                      -- 分支取值：承接上一子句，构成完整语句，属 §EX-17b 之取数
       ELSE NULL END                                                  AS val_after,                 -- 兜底取值：产出「val_after」
  /* 摘要截断（供人工核样，不含 SQL 原文） */
  SUBSTR(COALESCE(lmc11, ''), 1, 120)                                 AS summary,                   -- 取值表达式：产出「summary」
  /* 批量标记：一次改动多个会员者，lmc05 中会出现 IN (…) */
  CASE WHEN lmc05 LIKE '%IN (%' OR lmc05 LIKE '%in (%' THEN 1 ELSE 0 END AS is_batch,               -- 条件分支：产出「is_batch」
  LENGTH(COALESCE(lmc05, ''))                                         AS stmt_len                   -- 取值表达式：产出「stmt_len」
FROM ods_mariadb_2b.ods_a168_log_mem_change                                                         -- 取数来源：取自会员资料变动日志（批量注册嫌疑旁证）
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-03-21'、dt小于 '2026-08-07'，涉 dt（营业日）
ORDER BY lmc09;                                                                                     -- 排序：按 lmc09 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ★ R 侧用法（三步）：
     ① 限红降档的经济效果：取 event_type='limit_change' 者，
        以 val_before/val_after 得降幅，比较该会员处置前后 14 日的洗码量与净赢
        —— 这是**回收率的第一个真实测量**；
     ② 停用与批量停用：event_type='member_disable' 且 is_batch=1 者，
        其涉及的会员须自 lmc05 另行解析（本表只出标记，不出原文）；
     ③ 名单对账：把上述会员与回测各折的罚池名单求交
        —— **平台实际处置的人，本方案圈住了几成？**
   ★ 量级预期：三日 199 笔，全窗（139 日）约 9,200 笔，
     其中会员级处置（限额/停用/状态）约占四成。
     仍属小样本，一切结论须配 Wilson 或 Jeffreys 区间。 */

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-18 · 占成方向对账 —— 占成之案的最后一关
   ---------------------------------------------------------------------------
   §EX-17a/17a2 实测已确证两事，先记明：

   ★ 同源确证：agent_dtl.ag012 在 gid=101 上，非零者 32,456 行（覆盖 71.1%），
     高档 89~100 占非零者 **76.5%**，众数 94／96／95
     —— 与 dailyreport 的 bet23~27 实测均值 96.07／96.03／95.71 **完全吻合**。
     故 bet23~27 即 ag012 的逐日镜像；其「与金额基数无关」正是理所当然。

   ★ 方向两案（2026-08-10 依先生指正更正措辞）：
       · 若 ag012=95 记的是**代理的份额** → 代理拿 95%、**平台仅拿 5%**
         → κ = 0.95×m = 1.8221% → γ* = m − ρ − κ = **−0.253%**（赏侧须锁死）
       · 若 ag012=95 记的是**平台的份额** → 代理只拿 5%、**平台拿 95%**
         → κ = 0.05×m = 0.0959% → γ* = **+1.473%**（赏侧宽裕）
     **一字之差，正负异号**。信用盘两种写法皆有，不可凭常识断，须以实证定夺。
   ★★ 【已定案·见 §EX-19b】层级单调性检验判为**代理留成率**（前一案），
       γ* 为负，**赏侧锁死**。本节 §EX-18b/18c 的对账已无须再跑
       （且 §EX-19c 实测 lacc03 无一能在代理主档找到，对账之路本已断绝）。

   ★ 另两处待解，一并纳入本条：
       · ag012 = 0 者占 28.9%（13,212 行）—— 是「无配置」还是「零占成」？
       · ag003 均值 0.347 —— 是否为退水率？若是，ρ 亦有着落，γ* 可完整算出。

   ─── 对账之法（本条的核心逻辑）────────────────────────────────────────
     取若干条 ag012 已知的代理线，两侧各算一数：
       左：该线线下会员在窗内的实际 GGR（自 dailyreport 按 lv3 归线聚合）
       右：该线代理账号在 log_age_cash_change 中的入账合计（正值部分）
     再看比值落在哪一侧：
       入账 ÷ 线GGR ≈ ag012/100（约 0.95）  → **代理拿 95%**，κ = 0.95×m
       入账 ÷ 线GGR ≈ 1 − ag012/100（约 0.05）→ **平台拿 95%**，κ = 0.05×m
   ★ 本条是 §EX 系列首次动用 JOIN；为控成本，只取入账最多的二十条线作样本，
     且两侧皆限三日窗。样本虽小，方向之辨只需量级，不需精度。
   ═══════════════════════════════════════════════════════════════════════════ */

-- ▸ 导出：不需要 —— §EX-18a ag012 = 0 之辨（无配置抑或零占成），屏幕看结果。
--   ★ 判据：若 ag012=0 的代理其线下确有投注（可在 I 侧找到会员），
--     则「零占成」成立（该线不分成）；若其线下几无会员，则属「无配置」的空壳线。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  CASE WHEN CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) > 0                                       -- 条件分支：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
       THEN 'has_rate' ELSE 'zero_rate' END                          AS grp,                        -- 分支取值：产出「grp」
  COUNT(*)                                                           AS n_rows,                     -- 计数表达式：产出「n_rows」
  COUNT(DISTINCT ag001)                                              AS n_agent,                    -- 计数表达式：统计去重个数，产出「n_agent」
  AVG(CAST(NULLIF(TRIM(ag003),'') AS DECIMAL(10,4)))                 AS avg_ag003,                  -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「avg_ag003」
  SUM(CASE WHEN CAST(NULLIF(TRIM(ag003),'') AS DECIMAL(10,4)) > 0                                   -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           THEN 1 ELSE 0 END)                                        AS n_ag003_pos,                -- 分支取值：产出「n_ag003_pos」
  MIN(CAST(NULLIF(TRIM(ag003),'') AS DECIMAL(10,4)))                 AS min_ag003,                  -- 取最小值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「min_ag003」
  MAX(CAST(NULLIF(TRIM(ag003),'') AS DECIMAL(10,4)))                 AS max_ag003                   -- 取最大值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「max_ag003」
FROM ods_mariadb_2b.ods_a168_agent_dtl                                                              -- 取数来源：取自代理配置明细（退水率与代理留成率的真值所在）
WHERE CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                                     -- 过滤条件：限定 CAST(NULLIF(TRIM(ag002),'') AS INT)等于 101
GROUP BY CASE WHEN CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) > 0                                -- 分组：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
              THEN 'has_rate' ELSE 'zero_rate' END;                                                 -- 分支取值：承接上一子句，构成完整语句，属 §EX-18a 之取数
-- 读法：
--   · ag003 若在 has_rate 组内呈 0.3~1.2 的分布 → 系**退水率**，ρ 有了着落；
--   · 若 ag003 恒为 0 或与 ag012 互补（如 ag012+ag003=100）→ 系分成的另一侧，
--     此时 ag012 与 ag003 的和即全额，方向可由此直接判定，不必再对账。

-- ▸ 导出：不需要 —— §EX-18b 代理线 GGR（对账左侧：线下会员实际赢利），屏幕看结果。
--   ★ 以 lv3 归线（与 §S-03 同键），三日窗，取 GGR 最大的二十条线。
SELECT bet20                                                         AS lv3,                        -- 取列：起始取列子句，本行先取「lv3」，涉 bet20（三级代理线）、lv3（三级代理线）
       COUNT(DISTINCT bet05)                                         AS n_member,                   -- 计数表达式：统计唯一会员数（铁律分母，全窗 721,190 人），产出「n_member」
       SUM((CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))                                           -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
          - CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4)))                                          -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)))          AS line_ggr,                   -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「line_ggr」
       SUM(CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4))                                            -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
           / CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)))          AS line_validbet               -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「line_validbet」
FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                     -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND bet02 = '101' AND category = '1'                                                              -- 并列条件：限定 bet02等于 '101'、category等于 '1'，涉 bet02（游戏类别）
  AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0                                             -- 并列条件：限定 CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
  AND NULLIF(TRIM(bet20),'') IS NOT NULL                                                            -- 并列条件：限定该值非空，涉 bet20（三级代理线）
GROUP BY bet20                                                                                      -- 分组：按 bet20 汇总
ORDER BY line_ggr DESC                                                                              -- 排序：按 line_ggr（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
LIMIT 20;                                                                                           -- 行数上限：限定返回行数——导出上限内只承认排序头部结论
-- 读法：把 lv3 与 line_ggr 两列抄下，与 §EX-18c 的入账按 lv3 对齐相除。
--   ★ 若 dailyreport 无 bet20 列（代理层级列名或不同），改用 §S-03 所用的归线列；
--     报错即说明列名有异，须先以 §EX-00 核对该表的代理层级列。

-- ▸ 导出：不需要 —— §EX-18c 代理入账（对账右侧：资金流水中的正向入账），屏幕看结果。
--   ★ 以 lacc03 为代理账号（§EX-16a 实测其取值 67,779 种，量级与代理数相当）。
--     只计正值（入账），三日窗，取入账最多的二十个账号。
SELECT lacc03                                                        AS agent_ref,                  -- 取列：起始取列子句，本行先取「agent_ref」
       COUNT(*)                                                      AS n_tx,                       -- 计数表达式：产出「n_tx」
       SUM(CASE WHEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)) > 0                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                THEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4))                                 -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                ELSE 0 END)                                          AS sum_in,                     -- 兜底取值：产出「sum_in」
       SUM(CASE WHEN CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)) < 0                             -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                THEN -CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4))                                -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                ELSE 0 END)                                          AS sum_out,                    -- 兜底取值：产出「sum_out」
       SUM(CAST(NULLIF(TRIM(lacc06),'') AS DECIMAL(20,4)))           AS sum_net                     -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「sum_net」
FROM ods_mariadb_2b.ods_a168_log_age_cash_change                                                    -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                      -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
  AND lacc02 = '7' AND lacc04 = '0'          -- 主类，占 99.8% 行数
GROUP BY lacc03                                                                                     -- 分组：按 lacc03 汇总
ORDER BY sum_in DESC                                                                                -- 排序：按 sum_in（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
LIMIT 20;                                                                                           -- 行数上限：限定返回行数——导出上限内只承认排序头部结论
-- 读法：与 §EX-18b 的 lv3 逐一对齐（若编号体系一致），算比值 sum_in ÷ line_ggr：
--   · 比值 ≈ 0.95（即 ag012/100）      → **代理拿 95%**，κ = 0.95×m，γ* ≈ +0.10%
--   · 比值 ≈ 0.05（即 1 − ag012/100）  → **平台拿 95%**，κ = 0.05×m，γ* ≈ +1.82%
--   · 比值远大于 1                      → sum_in 含充值转账，非纯占成，
--                                          须再按 lacc05（30 种）细分后重对
--   ★ 若两侧编号体系不通（lacc03 非 lv3 编号），则本路不通，
--     占成即判**不可得**，γ* 锁死在保守口径 m − ρ，赏侧不设金额层。

-- ▸ 导出：不需要 —— §EX-18d 编号体系连通性预检（先看两侧编号能否对上），屏幕看结果。
--   ★ 本条应**先于** §EX-18b/18c 跑：若编号体系不通，后两条即无须再跑。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  (SELECT COUNT(DISTINCT bet20)                                                                     -- 续行：统计去重个数
   FROM ods_mariadb_2b.ods_a168_dailyreport_member                                                  -- 取数来源：取自会员日结报表（日粒度业绩与风控标记）
   WHERE dt >= '2026-08-04' AND dt < '2026-08-07'                                                   -- 过滤条件：限定 dt不少于 '2026-08-04'、dt小于 '2026-08-07'，涉 dt（营业日）
     AND bet02 = '101' AND NULLIF(TRIM(bet20),'') IS NOT NULL)        AS d_lv3_in_report,           -- 并列条件：限定该值非空，涉 bet02（游戏类别）、bet20（三级代理线）
  (SELECT COUNT(DISTINCT lacc03)                                                                    -- 续行：统计去重个数
   FROM ods_mariadb_2b.ods_a168_log_age_cash_change                                                 -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
   WHERE dt >= '2026-08-04' AND dt < '2026-08-07')                    AS d_agent_in_cash,           -- 过滤条件：限定 dt不少于 '2026-08-04'，涉 dt（营业日）
  (SELECT COUNT(DISTINCT ag001)                                                                     -- 续行：统计去重个数
   FROM ods_mariadb_2b.ods_a168_agent_dtl                                                           -- 取数来源：取自代理配置明细（退水率与代理留成率的真值所在）
   WHERE CAST(NULLIF(TRIM(ag002),'') AS INT) = 101)                   AS d_agent_in_dtl,            -- 过滤条件：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「d_agent_in_dtl」
  (SELECT COUNT(DISTINCT age001)                                                                    -- 续行：统计去重个数
   FROM ods_mariadb_2b.ods_a168_agent)                                AS d_agent_master;            -- 取数来源：取自代理主档（五级代理线归属来源）
-- 读法：四个数若量级相当（皆数万），则编号体系很可能同源，可续跑 18b/18c；
--   若 d_lv3_in_report 仅数百而其余数万，说明 lv3 只是层级中的一级，
--   须改以 agent 主档的 age007~age010（上级链）把 lv3 映射到实际收款账号后再对。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-19 · 占成方向的旁证之法（对账不通后的替代路径）
   ---------------------------------------------------------------------------
   §EX-18 实测两获，先记明：

   ★ 获一：**ag003 确系退水率，ρ 首次有了实测来源**
     两组（有占成率/零占成率）的 ag003 均值几乎相同（0.3418 vs 0.3491），
     范围 0~1.5，**与 ag012 不互补**（若互补应为 100−ag012），
     且恰落在信用盘退水惯例 0.3~1.2% 之内。
     故 ag003 = 退水率，量纲为百分数（1.5 表 1.5%），ρ ≈ 0.349%。
     ——本方案原用 E02 旧版的 ρ ≈ 0，自此有据可依。

   ★ 获二：**编号落差显形，直接对账不可行**
       dailyreport.bet20（lv3）        294 种
       agent_dtl.ag001             44,417 种
       agent 主档 age001            46,284 种
       log_age_cash_change.lacc03  67,853 种
     lv3 仅 294 种而其余四万至六万，**相差两个数量级**
     ⇒ lv3 是层级中的一级（总代理／大股东级），**不是收款账号**；
       lacc03 的 67,853 甚至多于代理主档，其中或混有会员账号。
     故 §EX-18b/18c 的直接对账须搁置，改走本节旁证。

   ★★ 方向两案（2026-08-10 依先生指正更正措辞）：
       · 若 ag012=95 记的是**代理的份额** → 代理拿 95%、**平台仅拿 5%**
         → κ = 0.95×m = 1.8221% → γ* = m − ρ − κ = **−0.2532%** ⛔ 赏侧须锁死
       · 若 ag012=95 记的是**平台的份额** → 代理只拿 5%、**平台拿 95%**
         → κ = 0.05×m = 0.0959% → γ* = **+1.4730%** ✅ 赏侧宽裕
     两案**正负异号**，一边是赏侧永久关闭、一边是宽裕可发，此结不解不可落笔。

   ─── 旁证之法（本节核心逻辑）────────────────────────────────────────
     不必动用资金流水，只用 agent 主档的上级链与 agent_dtl 的配置率：
       · 若 ag012 记的是**代理留成率**，则同一条线内**上级的 ag012 应大于下级**
         （逐级抽成，上游先抽、下游只得其余，故自上而下递减或至少不增）；
       · 若记的是**平台留成率**，则各级面对的都是同一个平台，
         其值与层级深浅**无单调关系**（甚至下级更高，因下级议价力弱）。
     此查只需两张表，成本远低于对账。
   ═══════════════════════════════════════════════════════════════════════════ */

-- ▸ 导出：不需要 —— §EX-19a agent 主档层级结构验货（打通编号的钥匙），屏幕看结果。
--   ★ 先看主档有哪些层级列、各级代理数分布，方能判定上级链如何构成。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                            AS n_rows,                    -- 计数表达式：产出「n_rows」
  COUNT(DISTINCT age001)                                              AS d_age001,                  -- 计数表达式：统计去重个数，产出「d_age001」
  COUNT(DISTINCT age007)                                              AS d_age007,                  -- 计数表达式：统计去重个数，产出「d_age007」
  COUNT(DISTINCT age008)                                              AS d_age008,                  -- 计数表达式：统计去重个数，产出「d_age008」
  COUNT(DISTINCT age009)                                              AS d_age009,                  -- 计数表达式：统计去重个数，产出「d_age009」
  COUNT(DISTINCT age010)                                              AS d_age010,                  -- 计数表达式：统计去重个数，产出「d_age010」
  SUM(CASE WHEN NULLIF(TRIM(age007),'') IS NULL THEN 1 ELSE 0 END)    AS n_null007,                 -- 汇总表达式：产出「n_null007」
  SUM(CASE WHEN NULLIF(TRIM(age008),'') IS NULL THEN 1 ELSE 0 END)    AS n_null008,                 -- 汇总表达式：产出「n_null008」
  SUM(CASE WHEN NULLIF(TRIM(age009),'') IS NULL THEN 1 ELSE 0 END)    AS n_null009,                 -- 汇总表达式：产出「n_null009」
  SUM(CASE WHEN NULLIF(TRIM(age010),'') IS NULL THEN 1 ELSE 0 END)    AS n_null010                  -- 汇总表达式：产出「n_null010」
FROM ods_mariadb_2b.ods_a168_agent;                                                                 -- 取数来源：取自代理主档（五级代理线归属来源）
-- 读法：
--   · 若 d_age007 ≈ 294（与 lv3 同数）→ age007 即 lv3 所在的那一级，编号由此打通；
--   · 各级的 NULL 数逐级递增 → 上级链自浅至深，NULL 表示该级不存在（层级未满五级）；
--   · 若四列的 distinct 数皆为个位数或全 NULL，说明层级不记在 age007~010，
--     须改以 §EX-19a2 全列扫描另寻。

-- ▸ 导出：不需要 —— §EX-19a2 agent 主档全列名（若 19a 判为不在 age007~010 时用），屏幕看结果。
SELECT column_name, data_type                                                                       -- 取列：承接上一子句，构成完整语句，属 §EX-19a2 之取数
FROM information_schema.columns                                                                     -- 取数来源：取自元数据字典（列名与表结构核对之用）
WHERE table_schema = 'ods_mariadb_2b'                                                               -- 过滤条件：限定 table_schema等于 'ods_mariadb_2b'
  AND table_name = 'ods_a168_agent'                                                                 -- 并列条件：限定 table_name等于 'ods_a168_agent'，涉代理主档（五级代理线归属来源）
ORDER BY ordinal_position;                                                                          -- 排序：按 ordinal_position 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
-- 读法：找出层级／上级／父级一类的列（常见命名：parent、pid、upline、level、path），
--       以及与 bet18~22（LV1~LV5 代理 ID）可对齐的那一列。

-- ▸ 导出：不需要 —— §EX-19b 占成率的层级单调性检验（★ 方向判定的关键一条），屏幕看结果。
--   ★ 判据（本条的全部意义所在）：
--     · 上级 ag012 **系统性大于**下级（差值均值显著为正、上>下的比例远超五成）
--         → ag012 记的是**代理留成率**（逐级抽成，上游先抽）
--         → 代理拿 95%、平台仅拿 5% → κ = 0.95×m → γ* 为负，**赏侧锁死**；
--     · 无单调关系（差值均值近零、上>下的比例约五成）或下级反高
--         → ag012 记的是**平台留成率**（各级面对同一平台，与层级无关）
--         → 代理只拿 5%、平台拿 95% → κ = 0.05×m → γ* 转正，**赏侧可解冻**。
--   ★ 以 age007 为上级键作自连接；若 §EX-19a 判定上级列另有其名，把 age007 替换即可。
WITH d AS (            -- 百家乐占成率，一代理一行（同代理多行者取其最大，避免重复）
  SELECT ag001                                              AS agent_id,                            -- 取列：起始取列子句，本行先取「agent_id」
         MAX(CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4))) AS rate                                 -- 取最大值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rate」
  FROM ods_mariadb_2b.ods_a168_agent_dtl                                                            -- 取数来源：取自代理配置明细（退水率与代理留成率的真值所在）
  WHERE CAST(NULLIF(TRIM(ag002),'') AS INT) = 101                                                   -- 过滤条件：限定 CAST(NULLIF(TRIM(ag002),'') AS INT)等于 101
    AND CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4)) > 0                                           -- 并列条件：限定 CAST(NULLIF(TRIM(ag012),'') AS DECIMAL(10,4))大于 0，涉 ag012（代理留成率）
  GROUP BY ag001                                                                                    -- 分组：按 ag001 汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§EX-19b）
p AS (                 -- 上级链：子 → 父
  SELECT age001 AS child_id, age007 AS parent_id                                                    -- 取列：产出「parent_id」
  FROM ods_mariadb_2b.ods_a168_agent                                                                -- 取数来源：取自代理主档（五级代理线归属来源）
  WHERE NULLIF(TRIM(age007),'') IS NOT NULL                                                         -- 过滤条件：限定该值非空
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§EX-19b）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COUNT(*)                                                            AS n_pairs,                   -- 计数表达式：产出「n_pairs」
  AVG(dp.rate - dc.rate)                                              AS avg_parent_minus_child,    -- 求均值表达式：产出「avg_parent_minus_child」
  AVG(CASE WHEN dp.rate > dc.rate THEN 1.0 ELSE 0.0 END)              AS share_parent_gt_child,     -- 求均值表达式：产出「share_parent_gt_child」
  AVG(CASE WHEN dp.rate < dc.rate THEN 1.0 ELSE 0.0 END)              AS share_parent_lt_child,     -- 求均值表达式：产出「share_parent_lt_child」
  AVG(CASE WHEN dp.rate = dc.rate THEN 1.0 ELSE 0.0 END)              AS share_equal,               -- 求均值表达式：产出「share_equal」
  AVG(dc.rate)                                                        AS avg_child_rate,            -- 求均值表达式：产出「avg_child_rate」
  AVG(dp.rate)                                                        AS avg_parent_rate,           -- 求均值表达式：产出「avg_parent_rate」
  MIN(dp.rate - dc.rate)                                              AS min_diff,                  -- 取最小值表达式：产出「min_diff」
  MAX(dp.rate - dc.rate)                                              AS max_diff                   -- 取最大值表达式：产出「max_diff」
FROM p                                                                                              -- 取数来源：取自本条自建的中间结果集 p
JOIN d dc ON dc.agent_id = p.child_id                                                               -- 连接：取自本条自建的中间结果集 d，连接键为 dc.agent_id = p.child_id
JOIN d dp ON dp.agent_id = p.parent_id;                                                             -- 连接：取自本条自建的中间结果集 d，连接键为 dp.agent_id = p.parent_id;
-- 读法（照上方判据对号入座）：
--   share_parent_gt_child 若 ≥ 0.80 且 avg_parent_minus_child 显著为正
--     → **代理留成率**，γ* 为负，赏侧锁死；
--   share_parent_gt_child 若约 0.50 且 avg 近零
--     → **平台留成率**，γ* 转正，赏侧可解冻；
--   n_pairs 若过小（不足数百），样本不足以判，须放宽至全部游戏类别再跑。

-- ▸ 导出：不需要 —— §EX-19c lacc03 实体性质普查（判资金流水表以谁为主体），屏幕看结果。
--   ★ 承 §EX-18d：lacc03 有 67,853 种，多于代理主档的 46,284——其中或混有会员账号。
--     本条以「能否在代理主档找到」分组，判该表究竟记代理还是记会员。
SELECT CASE WHEN a.age001 IS NOT NULL THEN 'in_agent_master'                                        -- 取列：承接上一子句，构成完整语句，属 §EX-19c 之取数
            ELSE 'not_in_agent_master' END                            AS grp,                       -- 兜底取值：产出「grp」
       COUNT(*)                                                       AS n_tx,                      -- 计数表达式：产出「n_tx」
       COUNT(DISTINCT c.lacc03)                                       AS d_ref,                     -- 计数表达式：统计去重个数，产出「d_ref」
       AVG(ABS(CAST(NULLIF(TRIM(c.lacc06),'') AS DECIMAL(20,4))))     AS abs_avg,                   -- 求均值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「abs_avg」
       SUM(CASE WHEN CAST(NULLIF(TRIM(c.lacc06),'') AS DECIMAL(20,4)) > 0                           -- 汇总表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                THEN CAST(NULLIF(TRIM(c.lacc06),'') AS DECIMAL(20,4))                               -- 分支取值：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
                ELSE 0 END)                                           AS sum_in                     -- 兜底取值：产出「sum_in」
FROM ods_mariadb_2b.ods_a168_log_age_cash_change c                                                  -- 取数来源：取自代理额度变动日志（占成探查曾用，主体非代理）
LEFT JOIN ods_mariadb_2b.ods_a168_agent a                                                           -- 左连接：取自代理主档（五级代理线归属来源）
  ON TRIM(a.age001) = TRIM(c.lacc03)                                                                -- 连接键：限定 TRIM(a.age001)等于 TRIM(c.lacc03)
WHERE c.dt >= '2026-08-04' AND c.dt < '2026-08-07'                                                  -- 过滤条件：限定 c.dt不少于 '2026-08-04'、c.dt小于 '2026-08-07'，涉 dt（营业日）
  AND c.lacc02 = '7' AND c.lacc04 = '0'                                                             -- 并列条件：限定 c.lacc02等于 '7'、c.lacc04等于 '0'
GROUP BY CASE WHEN a.age001 IS NOT NULL THEN 'in_agent_master'                                      -- 分组：按 CASE WHEN a.age001 IS NOT NULL THEN 'in_agent_master' 汇总
              ELSE 'not_in_agent_master' END;                                                       -- 兜底取值：承接上一子句，构成完整语句，属 §EX-19c 之取数
-- 读法：
--   · in_agent_master 占多数 → 本表确以代理为主体，对账之路尚存，
--     可待编号打通后重启 §EX-18b/18c；
--   · not_in_agent_master 占多数 → 本表主体非代理（或为会员上下分流水），
--     对账之路即断，占成方向只能靠 §EX-19b 的旁证定夺。

/* ═══════════════════════════════════════════════════════════════════════════
   §EX-20 · 占成之案结案记录（2026-08-10）—— 本节不含查询，只作定案存照
   ---------------------------------------------------------------------------
   历经 §EX-06 / 10 / 12 / 15b / 16a / 17a / 18a / 18d / 19a / 19b / 19c
   十一条探查，占成、退水与 γ* 三案俱已结账。谨记其始末与定论，
   以免日后重启同一路径、重付同一代价。

   ─── 一、占成率 κ：**已定案，取代理留成率口径** ────────────────────────
   【料源】agent_dtl.ag012（按代理 × 游戏类别配置），dailyreport.bet23~27 系其逐日镜像。
   【量纲】百分数（94 表 94%）；另有 0.05~0.94 共 92 行疑为小数比率，占非零者 0.3%，
           采用时须比照 §E02c 作量纲判别。
   【覆盖】gid=101 共 45,668 行，ag012 > 0 者 32,456 行（71.1%）。
   【方向】**代理留成率**——§EX-19b 以 14,112 对父子作层级单调性检验：
             上级 > 下级 61.64%、上级 = 下级 38.30%、**上级 < 下级仅 0.06%**，
             非降序 99.94%，差值均值 +7.73 个百分点（下级均 86.53、上级均 94.26）
           —— 严格的逐级不增，正是「上游先抽、下游只得其余」之形。
   【取值】以**下级均值 86.53%** 为准（下级即直面会员那一级，其留成率乘 GGR
           方为代理链自会员处分走的总额）。
   【结论】κ = 0.8653 × m = 0.8653 × 1.918% = **1.6596%**

   ─── 二、退水率 ρ：**已定案** ──────────────────────────────────────────
   【料源】agent_dtl.ag003；§EX-18a 实测两组均值 0.3418 与 0.3491，范围 0~1.5，
           与 ag012 不互补，恰落信用盘惯例 0.3~1.2% 之内。
   【结论】ρ ≈ **0.349%**（未加权粗值）。
   ★ 采用前须按洗码量加权重算——大线与小线的退水率不同，等权平均会失真。

   ─── 三、赏侧天花板 γ*：**判为负，赏侧锁死** ──────────────────────────
     γ* = m − ρ − κ = 1.918% − 0.349% − 1.660% = **−0.091%**
   【释义】平台自会员处所得毛利（1.918%），扣去退水（0.349%）与代理占成（1.660%）后
           **已无余额**，尚差 0.091 个百分点。故赏侧**没有可发放的经济空间**——
           这不是「暂缓」，是**结构性的没有**。
   【落地】本方案自此：
             · 赏侧一律**不设金额层**，只保留过程性激励（授权、排序、绩效基线）；
             · 罚侧不受影响，照常执行（追缴、冻结结算、限红降档、授权降档）；
             · 报告中凡「赏预算」「γ* 天花板」「占成待核清」等表述，
               一律改为「**占成实测已定，γ* 为负，赏侧无金额空间**」。
   ★ 此结论若要推翻，只有两途：① 平台调降代理占成率；② 提高庄家毛利率 m。
     二者皆属商务决策，非数据分析所能及。

   ─── 四、已断绝的三条路（记明以免重走）────────────────────────────────
     · dailyreport.bet23~32 —— 系配置镜像，与金额基数无关（§EX-12）；
     · 代理占成配置表 —— 不存在，命中者皆为提现费率、汇率、佣金模式标记（§EX-06）；
     · log_age_cash_change —— **主体不是代理**：§EX-19c 实测 314,132 笔中
       lacc03 **无一** 能在 agent 主档找到，故其为会员上下分流水，
       与代理占成无涉；对账之路彻底断绝。

   ─── 五、尚未打通者（留待日后）──────────────────────────────────────
     lv3 编号仍未打通：dailyreport.bet20 仅 294 种，而 agent 主档的四级上级链
     age007~010 各有 692 / 1,664 / 4,220 / 7,912 种，无一为 294。
     故 lv3 另有出处。此事不影响 γ* 的定案（κ 已由 ag012 直接得出），
     但若日后要按线核算占成金额，仍须先解此结。
   ═══════════════════════════════════════════════════════════════════════════ */
