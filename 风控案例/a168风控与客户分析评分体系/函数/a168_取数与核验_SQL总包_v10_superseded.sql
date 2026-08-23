/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  a168 风控与客户分层评分体系 · 商业方案                                      ║
   ║  取数与核验 SQL 总包（一册两卷 · 合并定稿）                                  ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  作者：Ryo Eng                                                            ║
   ║  平台：a168 真人厅 · 数据源 StarRocks ods_mariadb_2b · 前端 Superset SQL Lab║
   ║  配套报告：a168风控与客户分层评分体系_商业方案_v3.qmd（评估线：尾段投注基础分析的评估_v1_2_13.qmd）                         ║
   ║  本文件由「a168_核验与取数_SQL包.sql」与「a168_取数SQL包_v3增补.sql」         ║
   ║  合并而成，取代该二者；此后维护只认本文件一份。                               ║
   ╚═══════════════════════════════════════════════════════════════════════════╝

   ═══ 版本身份六元组（2026-08-13 立 · 铁律 T3·L7·S3）═══════════════════════
     版本身份须以六元组共同锚定，缺一即不足以定身份：
       文件名 + 行数 + 字节数 + MD5 + 换行符 + 编码
     本文件换行制式为 CRLF，编码 UTF-8（无 BOM）。
     故同一份文件存在三个互不相通的 MD5，取用时务必声明取的是哪一个：
       · 原样（CRLF）      —— 传输与归档以此为准
       · LF 归一后         —— 跨平台比对以此为准
       · 剥离行尾注释后    —— 注释体例第六条所载者，仅用于验证注释零改动
     实证教训（2026-08-13）：某审计方以 LF 归一后之 MD5 与本包原样 MD5 相较，
     径判「版本身份 BLOCK」。实则两组读数皆正确，字节差恰等于行数
     （每行一个回车符），差异纯由换行归一造成。
     判读次序：见 MD5 不符，第一步先比对字节差是否恰等于行数；若是，
     即为换行制式差异，不得径判为版本冲突或造假。

   ═══ 分析窗口（正名版，务必按此措辞对外）═══════════════════════════════════
     2026-03-21 ~ 2026-08-06 收盘，共 139 个完整营业日。
     SQL 谓词一律写作：dt >= '2026-03-21' AND dt < '2026-08-07'
     右端点为**开区间**——2026-08-07 当日不在窗口内。
     旧头部曾写「~ 2026-08-07」，字面易被读成含当日，已正名。
     改窗时须同时全量替换两枚窗口字面量（v5 实测：'2026-03-21' 共 179 处／'2026-08-07' 共 248 处），不得只改其一；
     旧记「53 处」系并入前口径，已失真，今以现算取代。

   ═══ 血统关系登记（2026-08-13 立 · 一族四档）════════════════════════════
     本包为「取数层」，居一族四档之料源位。改本包即改全族之数字，故列明：

       档                                          角色        与本包之关系
       a168风控与客户分层评分体系_商业方案.qmd       主方案(父)   §17.2 维度字典之权威出处
       a168风控评分_精要商业报告.qmd                 精要版(子)   以 must= 挂本包之表头契约锁
       a168_取数与核验_SQL总包_v10.sql              本包(料源)   一切数字之唯一出处
       a168_能力值口径解读_SQL转R.qmd                对照本(校验) 逐条对照本包与主方案之口径差

     同步纪律三条：
       ① 交付件**表头**即契约：增删改任何输出列，须同步下游三档之 must= 清单；
       ② 口径锁列（late_def 之属）只可增不可删——删之即令下游锁失效；
       ③ 任一档改动，须于变更记录记明改前改后之六元组，并核对其余三档是否受累。

   ═══ 常数集中登记（2026-08-13 立 · 铁律 T3·L2·S3）═════════════════════════
     顶尖工程标准要求常数集中于单一处、余处一律引用。本包因 Superset 不支持
     占位符（纪律①「零占位符」）而无法参数化，故改以登记表代替，
     使「改一处漏一处」由不可察变为可核对：

       常数名          取值                出现处数   语义
       WIN_START       '2026-03-21'        89         窗口左端（闭区间）
       WIN_END         '2026-08-07'        89         窗口右端（开区间）
       GAME_BACCARAT   '101'               64         bet02 游戏类别：百家乐
       CAT_NORMAL      '1'                 49         category：一般注单
       REBET_NO        'N'                 81         bet38：非重对
       TESTLINE        age022 = '1'        —          公司测试线代理（214 条）
       LATE_DEF        shoe_pos >= 0.80    —          靴末段判据（2026-08-12 斧正）
       ⚠ 2026-08-18 v4：新增 §Z-14 零值诊断（SQL 主体首次改动，详见文末 §Z-16）。
   ⚠ 2026-08-18 注释斧正（代码零改动）：shoe_len 三处定义之代码口径本已一致
         （皆 MAX(round_no) GROUP BY shoe_id, table_id），但注释与 CTE 名历来称其为
         「靴长／该靴长度」，与所算之『最大局号』语义不符，易致下游以 COUNT 重实现。
         本轮统一三处定义行为同一命名警示横幅，并改正靴号取列与 ordx 之注释。
         另存差异登记：§R01 之 shoe_len 取自 base（含 bet04>0 过滤），
         §B01／§B01-D 取自 ord（无该过滤）；§B01-D 窗口为 3 日增量，
         其 max_round 会被窗口截断——跨窗靴之 shoe_pos 将被系统性放大，详见文末登记。

     改窗／改口径之作业纪律：
       一、先以全文检索点数，实得处数须与上表相符；不符即先查本登记表；
       二、改毕后再检索一次，确认旧值零残留；
       三、同步更新本表处数，并于变更记录写明改前改后之六元组。
     ⚠ 上表处数系 2026-08-13 全文检索实测所得，非静态记忆；
       任何改动后须重新点数，不得沿用旧数。

   ═══ §Z-13 全包净化审计结论（2026-08-13 实测 · 154 条查询逐条核实）═══════
     方法：全文剥注释 → 裸分号切分 → 逐条 12 项守卫探测 → 分级裁定。
     铁律：任何聚合与推算之前，输入须已剔净六项——测试线、旧版本、非一般注单、
           重对注单、空串/不可转型值、荷官哨兵。唯一豁免：哨兵占比统计本身。

       查询语句总数        154 条        豁免·元数据            20 条
       ⚠ 2026-08-17 实测斧正：本区计数为旧版遗留。v3 实测——以分号结尾语句 37 条、
         含 CSV 导出声明行 75 条、唯一交付件 69 个、「不需要」声明 89 条。
         全包 64／66／72／75／79／154 诸数同源失同步，一律以本注为准。
       产出交付件者         79 条        豁免·一览/哨兵占比      14 条
       ✅ 四闸齐备          31 条        旁路·未触注单主表       65 条
       ⛔ 交付件缺闸        14 条  ← 见下；须先补闸再取数
       ⛔ 屏幕核验缺闸       6 条  ← 次级，不阻断

     ⛔ 交付件缺闸 14 条（P0 者标 ★）：
       ★ 行4982 §R03b   R03b_player_dealer_daily.csv   缺剔测试线
       ★ 行3341 §R03    R03_player_dealer.csv          缺剔测试线
       ★ 行3523 §R03chk R03chk_settlement_form.csv     缺剔测试线
       ★ 行3584 §R03inv R03inv_pair_census.csv         缺剔测试线
       ★ 行3132 §R02    R02_same_table.csv             缺剔测试线、**版本去重**
       ★ 行6587 §P0C-04 P0C04_同日泄漏检验.csv           四闸全缺
       ★ 行6627 §P0C-05 P0C05_标记时点定位.csv           四闸全缺
       ★ 行6665 §P0C-06 P0C06_LabelB骨架.csv            四闸全缺
       ★ 行6789 §P0C-09 P0C09_安慰剂检验.csv             四闸全缺
         行4810 §DX-04  DX04_bet09_profile.csv         缺剔测试线
         行2555 §A-01   A_anchor.csv                   四闸全缺
         行2573 §V-01   V_ipmatch.csv                  四闸全缺
         行7519 §TL-11  TL11_treatment_episode.csv     缺剔测试线、一般注单、非重对
         行3922 §TL-14  TL14_limit_treatment.csv       四闸全缺

     三处须点名之后果（非精度问题，逐条不同量级）：
       一、§R03 家族四条全缺剔测试线——R03b 系荷官八维之**唯一底表**，
           「客群广度」「对打局占比」「異常对关联」三维直接受污。
           且此污染**不随占比线性衰减**：测试线只要碰过某荷官一次，
           其 uniqueN(uid) 即 +1——占比再小，也是整数级偏移。
       二、§R02 连版本去重都无——same_rounds 与 rounds_i 同时虚增，
           而 Jaccard 分子分母虚增比例不同，Lift 系统性偏移且**方向不定**。
           此非精度问题，是排序可能翻转。
       三、§P0C 家族四条皆因果推断类——测试线行为分布与真人不同，
           混入即令处置组与对照组之**可比性假设失效**。
           产出者非「偏了的估计」，是「没有意义的估计」，不得进经济裁定。

     全文字符扫描：U+FFFD 替换符 **0 行**（全文无乱码）；U+00A0／U+200B／
       U+FEFF／TAB 皆 0 行；U+3000 全角空格 1 行；全角标点混入代码区 13 行
       （首现 898、3736、4791、4897、7788…）。判读三条：落注释区者无碍；
       落**字符串字面量**内者必清（同 §C-06 判庄闲实测零行之根因）；
       落标识符或运算符位者必致语法错，跑即报错，不会静默。

     处置：补闸最小 diff、影响量化探针与四条验收断言，见随附
       「Z15_前置净化层_标准前奏与补闸包.sql」。纪律：**先量后改，不量不改**。

   ═══ 使用纪律（实测教训固化，逐条有血泪）═══════════════════════════════════
     ① 每条查询自包含、零占位符 —— 整段复制直接运行；
     ② StarRocks 方言：禁 LATERAL VIEW EXPLODE（改 UNNEST）、
        禁 EXISTS + 多列 IN（改五路 LEFT JOIN + COALESCE IS NULL）；
     ③ 逐条提交，禁批量 —— 批量会产生僵尸查询，拖垮集群；
     ④ 导出必带 ORDER BY —— 分页无稳定排序曾致 36.49% 重复行；
     ⑤ 导出上限 1,000 行时只承认排序头部结论，「未出现」类判断一律无效；
     ⑥ 超过 10 万行者先跑 COUNT 预检，按会员号区间切分，**不要用 OFFSET 翻页**；
        ★ 2026-08-11 补：翻页一律取**唯一键**为序（如 §R03 的 member_id+dealer_id），
          不得以 z_score 一类**有并列值**的量为序——实测 517,528 行中 z_score 并列
          103,510 组、连次级键都分不开者 452 行，OFFSET 翻页必致重漏；
          且含全局 CTE 之段落，切点须在最外层（见 §99 之界）。
     ⑦ 导出编码选 CSV(UTF-8)，全部存入报告同级「数据库/」目录，
        文件名一字不可错 —— 错名不报错，只让图表静默空白，是最坑的失败方式；
     ⑧ 每个 Superset 会话开跑前先逐条执行：
          SET SESSION query_timeout = 259200;   -- 与卷首先生设定一致（3 天）
          SET SESSION cbo_cte_reuse = true;   -- 报「变量不存在」则跳过
        第二条让被多次引用的 CTE 只计算一遍——本包 S-01（bs×4）、S-03（bs×3）、
        §R02 / §K01 等条依赖它；老版本无此开关时，列瘦身仍保证可接受耗时；
     ⑩ **一行一跑，跑前清选区**：Superset 有选中即只跑选中段。三次实测失败中有两次
        皆因执行的是残片而非全文（报错首个词位于句中，如 'enable_spill'）。
        跑前按 Esc 或空白处单击，确保无高亮；SET 一类短语句一律逐行单跑。
     ⑪ **注释内不写分号**：语句切分器遇行注释里的分号可能切出残片。
        本包已把 §00 会话参数段内唯一一处注释内分号移除。
     ⑫ **全量导出前先带 LIMIT 试跑一次**：如 §R03 全量 806 万行，先加 LIMIT 100000
        约 18 秒即知链路与语法俱通，赔得起；确认无碍再去掉 LIMIT 跑全量。
        若中途遇 Connection refused，先跑 SELECT 1 验服务，再查 Query History
        有无残留 running 之僵尸查询（本包纪律③早戒：僵尸查询会拖垮集群）。
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
         ⚠ 2026-08-17 实测：3,144 系旧版行数，v3 实测 7,965 行（未计本轮注释）。
           覆盖关系不变，惟行数随版本增长，勿写死具体数，请以 wc -l 现算。

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

   ═══ 字段正名速查（★ 2026-08-13 斧正：逐条标明所属表）══════════════════════
     ⚠ 本表原将四张表之字段混列一处，致 bet41 一项被外部审计误判为「误标」。
       同一代号在不同表中语义不同，跨表援用同一段 SQL 必致静默错误。
       故此后每条皆冠所属表；未标明所属表者，不得引用。

     【表一 · ods_a168_bet02 —— 注单明细（本包主表）】
     bet03 靴号        bet04 局内第几把    bet05 会员号     bet08 下注时间
     bet06 开局时间    bet07 帳務日期      bet10 币别
     bet09 玩法（英文玩法名：Banker / Player / Tie / BankerDragonBonus …）
     bet11 汇率（币种归一化除数：stake = bet13 / bet11）  ← 非赔率，词典须核正
     bet13 下注金额    bet14 派彩金额      bet15 会员退水%  bet16 退水金额
     bet17 净输赢      bet18~22 五级代理线  bet39 桌号       bet40 房间编号
     bet38 重對（enum Y/N；本包取 N）。旧记「测试标识」有误——测试线系由
           age022='1' 之五路 LEFT JOIN 排除，与 bet38 无涉；本包基准 CTE 之
           注释「非测试线、非重对、一般注单」原已写对，误者仅此速查表一行。
     bet41 下注退水金额（⚠ 与表二之 bet41 同名异义，切勿互换）
     validbet 有效投注   eid 荷官工号   gametype 1网投/2电投/3-4混合
     commission 0一般/1免佣   category 1一般/2小费
     bet23~27 LV1~5 占成   bet28~32 LV1~5 退水（量纲待 §E02c-0 探针判定）

     【表二 · ods_a168_dailyreport_member —— 会员日报】
     bet41 有效投注（⚠ 与表一之 bet41 同名异义；§E02c 之 κ 由此列算出，
           见第 3950 行 DX-03 实测记录。本包五处 bet41 代码用法皆取自本表，
           无一处取自表一——2026-08-13 逐块回查 FROM 子句确认）

     【表三 · ods_a168_game_info —— 局信息】
     gi001~gi013（gi004 局开始 · gi006 开牌 · gi011 桌号）

     【表四 · ods_a168_bet01 —— 未结算注单（⚠ 自 bet14 起与表一整段错位）】
     bet14 退水％數（表一为「派彩」）    bet15~19 LV1~5 ID
     bet17 LV3ID（表一为「净输赢」——此为最凶险之一处）
     bet31 桌子编号（表一为 LV4 退水%）  bet32 房间编号（表一为 LV5 退水%）
     ★ 需求文档 §3.3 之四条金额算式（bet13/bet14/bet16/bet17）只对表一成立；
       若误施于表一以外之表，数值照算、SQL 照跑，而结果全错且无任何报警。
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

   【第六批 · 评估线归宗（P11 尾段两域族 v6 并入 ＋ P12 序列与事件族 v5 并入）】
     §P11a → 数据库/P11_阿泽尾段投注模型会员名单.csv  （契约名不英译）
     §P11b → 数据库/P11_雷欧尾段投注模型会员名单.csv  （契约名；＝§R01 输出之复制副本，v8 去重为指引）
     §P11c → 数据库/P11_阿泽尾段投注总帐.csv          （契约名不英译）
     §P11d → 数据库/P11_雷欧尾段投注总帐.csv          （契约名不英译）
     ⚠ 编号辨义：P12x 系评估档（尾段投注基础分析的评估）待表清单之编号，
       与卷一「P-01」（连字符式，会员月度面板）无涉，勿混。
     §P12b-pre → 只看屏幕（content 段式 20 行目检，先于 §P12b）
     §P12a → 数据库/P12a_platform_daily.csv     dt×1 行 139 行；Regime/监控带口粮
     §P12b → 数据库/P12b_member_events.csv       uid×1；生存分析（标记时点/流失/右删失）
     §P12c → 数据库/P12c_member_daily_pnl.csv     uid×dt（n>=100 域）；MDD/Sortino 指纹
              ⚠ 与 §R03b 同族互为对帐，非替代（§R03b 缺剔测试线且截断 UNKNOWN）
     §P12d → 数据库/R01_late_shoe_w2.csv      全量 SQL 在册（v8 补齐：自 §R01 程序化派生仅改窗）
     §P13  → 数据库/P13_personal_entry.csv    个人入场行为层（v7 并入；外部拟号 §R02 因撞名改此）

   ═══ 导出声明纪律（先生 2026-08-08 立 · 全包 75 条语句无一例外）═══════════
    ⚠ 2026-08-17：原文「75 条」与卷首「154 条」互斥，皆旧版遗留；
      纪律本身不因计数失同步而失效，条数以现算为准。
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
       ③ 全包现状（2026-08-12 逐行实测；计数口径＝行首以 -- 起首的导出标记行）：
          产出交付件的语句 72 条（新式 50 条 + 卷一旧式块注释 22 条；v5 并入 §P12a/§P12b/§P12c 三条，v6 并入 §P11a~d 四条；§P12b-pre 只看屏幕不计；v8：§P12d 升为全量语句、§P11b 降为复制指引，条数相抵），
          标注为无须导出的 72 条，文件名写盘冲突 0，唯一交付件文件名 64 个。
           ⚠ 2026-08-17 实测斧正：64／72／64 三数皆旧版遗留。v3 实测——
             含 CSV 导出声明行 75 条、「不需要」声明 89 条、唯一交付件文件名 69 个。
             两式并扫方法本身正确，仅计数须随版本现算，勿再写死。
          旧头部所记「40 / 35 / 全包 75」系卷一并入前之口径，已失真，今据实更正。
       ④ 声明体例两式并存：新式行首带需要／不需要二选一字样，旧式只在块注释内给出
          文件名而无该字样。例检脚本若只扫新式会漏计卷一 22 条，务必两式并扫。
       ⑤ 口径锁（2026-08-12 立）：§R01／§B01／§B01-D 三条各输出常量列 late_def。
          凡靴末段判据变更，必同步改该列取值；报告侧将其登记为必需列，
          旧版 CSV 因缺列而当场报错——静默语义漂移自此变为显式失败。
   ═══════════════════════════════════════════════════════════════════════════

   【第六批 · 时间一致性与切分工具】
     §TG-01 注册时间穿越检测   §TG-03 关注 IP 登记时间越界   §TG-05 事实表越界自检
     §99 大表切分导出模板      COUNT-01/02/08a/08b/09 计数与分批
   ═══════════════════════════════════════════════════════════════════════════ */

/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  §Z 前置章 · 全库结构剖析与哨兵值审计                                       ║
   ║  2026-08-13 并入 · 原为独立档 a168_全库结构与哨兵值审计_SQL_v1.sql           ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  并入缘由：正式交付物永久锁定为三份（主方案 .qmd／精要 .qmd／本 SQL 总包）。 ║
   ║  另立一份 SQL 即成第四份，违「恰为三份」之律，故并入而不并列。               ║
   ╚═══════════════════════════════════════════════════════════════════════════╝

   ═══ 本章何以置于 §00 之前 ═════════════════════════════════════════════════
     取数次序为铁律，不可倒：
       结构剖析 → 列剖析 → 关系剖析 → 口径固化 → 取数下载 → 分析
     置于 §00 之前，则本文件之物理顺序即等于执行顺序，无从倒序。

   ═══ 与本包既有语句之关系（2026-08-13 逐条核实，非推想）══════════════════
     本包原已有九处 information_schema 语句，散在五个章节：
       §00-2（字段清单）§00b（辅助表列名核对·已摘除）§00c（表行数）
       §DX-01（bet09 取值普查）§DX-03（取列定义通用写法）
       §BZ-00／§BZ-01（经营指标与流水字段搜寻）
       §EX-00／§EX-01／§EX-08（元数据总览与关键词搜表）§TZ-01~05（时区五条）
     本章之真正增量仅四类，余者为归拢：
       ① 备份／测试表排除（§Z-02）—— 本包原无表级排除
       ② 同名异义自动侦测（§Z-04）—— 本包原无；bet41 遭外部误判之根因即在此
       ③ 逐列哨兵值普查（§Z-06／§Z-07）—— 本包原仅 §DX-01 查 bet09 一列
       ④ 局键塌缩检验（§Z-08）—— 本包 §R02-0 有每局人数分布，无哨兵键塌缩
     §Z-03 沿用 §DX-03 之导出名 V_columns_dict.csv，二者择一执行，
     不得并行产出两份字段字典。
     §Z-09 承 §TZ-03，不重出 dt／bet08 端点，只留 bet07 三方对账
     与 bet06 减 bet08 之差值分布。

   ═══ 编号族与导出命名 ═════════════════════════════════════════════════════
     编号族取 §Z-xx（Zero／零层），避开本包既用之 C／S／R／T／D／E／K／V／
     P0／TL／DX／EV／BZ／EX／A／I／L／X 各族。
     导出名前缀 Z，与本包既有 66 个导出名实测零碰撞。
      ⚠ 2026-08-17 实测：v3 唯一交付件 69 个（原文 66 系旧版），零碰撞结论不变。
   ═══════════════════════════════════════════════════════════════════════ */



/* ═══════════════════════════════════════════════════════════════════════════
   §Z-00 · 会话参数（每个 Superset 会话开跑前逐条单跑一次）
   ▸ 导出：不需要 —— 会话参数设置，无结果集
   ═══════════════════════════════════════════════════════════════════════════ */
SET SESSION query_timeout = 259200;
SET SESSION cbo_cte_reuse = true;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-01 · 全库表清单与规模
   用途：确立审计范围与分批次序。TABLE_ROWS 为估计值，仅用于排序，不作结论。
   ▸ 导出：需要 —— 存为「数据库/Z01_table_inventory.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT
    TABLE_NAME                                                   AS 表名,
    TABLE_TYPE                                                   AS 表类型,
    TABLE_ROWS                                                   AS 估计行数,
    TABLE_COMMENT                                                AS 表注释,
    CASE
      WHEN LOWER(TABLE_NAME) LIKE '%_bak%'  THEN '备份'
      WHEN LOWER(TABLE_NAME) LIKE '%bak2%'  THEN '备份'
      WHEN LOWER(TABLE_NAME) LIKE '%_test%' THEN '测试'
      WHEN LOWER(TABLE_NAME) LIKE '%_tmp%'  THEN '临时'
      WHEN LOWER(TABLE_NAME) LIKE '%_old%'  THEN '旧版'
      WHEN LOWER(TABLE_NAME) LIKE '%_copy%' THEN '副本'
      WHEN LOWER(TABLE_NAME) LIKE '%_v1%'   THEN '疑似旧版'
      WHEN LOWER(TABLE_NAME) LIKE '%demo%'  THEN '疑似演示'
      ELSE '生产'
    END                                                          AS 疑似性质
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY 疑似性质, TABLE_NAME;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-02 · 排除清单（备份／测试／临时／副本表）
   用途：此清单须写入全案「禁用表」名录。已知实例：ods_a168_agent_bak20250610、
         ods_a168_agent_test、ods_a168_game_demoipsetting。
   判读：凡列入者，一律不得进入任何分析；若某分析已引用之，须整体重跑。
   ▸ 导出：需要 —— 存为「数据库/Z02_excluded_tables.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT
    TABLE_NAME                          AS 表名,
    TABLE_ROWS                          AS 估计行数,
    TABLE_COMMENT                       AS 表注释,
    CASE
      WHEN LOWER(TABLE_NAME) LIKE '%_bak%'  OR LOWER(TABLE_NAME) LIKE '%bak2%' THEN '备份表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_test%' THEN '测试表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_tmp%'  THEN '临时表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_old%'  THEN '旧版表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%_copy%' THEN '副本表·禁用'
      WHEN LOWER(TABLE_NAME) LIKE '%demo%'  THEN '演示表·须确认'
      ELSE '其他·须确认'
    END                                 AS 处置
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (   LOWER(TABLE_NAME) LIKE '%_bak%'  OR LOWER(TABLE_NAME) LIKE '%bak2%'
       OR LOWER(TABLE_NAME) LIKE '%_test%' OR LOWER(TABLE_NAME) LIKE '%_tmp%'
       OR LOWER(TABLE_NAME) LIKE '%_old%'  OR LOWER(TABLE_NAME) LIKE '%_copy%'
       OR LOWER(TABLE_NAME) LIKE '%demo%')
ORDER BY 处置, TABLE_NAME;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-03 · 全库字段字典（含 source_type 解析）
   用途：本表即数据字典之基底，落盘存档后，作为一切字段引用之**唯一依据**。
   要点：本库全部字段以 varchar 存储，真实类型仅存于 COLUMN_COMMENT 之
         `source_type=` 前缀。凡涉数值或时间比较，须先查此表确定原始类型，
         再行显式 CAST，**不得凭字段名臆测**。
   ▸ 导出：需要 —— 存为「数据库/Z03_column_dictionary.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT
    TABLE_NAME                                                        AS 表名,
    ORDINAL_POSITION                                                  AS 列序,
    COLUMN_NAME                                                       AS 列名,
    DATA_TYPE                                                         AS 存储类型,
    IS_NULLABLE                                                       AS 可空,
    REGEXP_EXTRACT(COLUMN_COMMENT, 'source_type=([^;]+)', 1)          AS 原始类型,
    TRIM(REGEXP_REPLACE(COLUMN_COMMENT, 'source_type=[^;]+;', ''))    AS 业务含义,
    COLUMN_COMMENT                                                    AS 原始注释
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-04 · 同名异义自动侦测（★ 本文件最关键之一条）
   用途：一次列出全库所有「同一列名、不同业务含义」之字段，
         不必再靠人逐一撞见。已知六处（bet14、bet01/bet02 自 bet14 起整段错位、
         bet31/bet32 与 bet39/bet40、member.mem015 与 member_dtl.mem015、
         member.mem015 自身、game_log.region 注释为「國家」）应由本条全数覆盖，
         且极可能另有未知者。
   判读：释义数 ≥ 2 者即为同名异义；类型数 ≥ 2 者风险更高——不仅义异，且型异，
         跨表复用同一段 SQL 必致静默错误。
   ▸ 导出：需要 —— 存为「数据库/Z04_name_collision.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
WITH d AS (
  SELECT
      COLUMN_NAME,
      TABLE_NAME,
      TRIM(REGEXP_REPLACE(COLUMN_COMMENT, 'source_type=[^;]+;', ''))  AS 含义,
      REGEXP_EXTRACT(COLUMN_COMMENT, 'source_type=([^;]+)', 1)        AS 类型
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
    AND COLUMN_COMMENT IS NOT NULL
    AND TRIM(COLUMN_COMMENT) <> ''
)
SELECT
    COLUMN_NAME                                  AS 列名,
    COUNT(DISTINCT 含义)                          AS 释义数,
    COUNT(DISTINCT 类型)                          AS 类型数,
    COUNT(DISTINCT TABLE_NAME)                   AS 出现表数,
    CASE WHEN COUNT(DISTINCT 类型) >= 2 THEN '🔴 义异且型异'
         ELSE '🟠 义异型同' END                   AS 风险,
    GROUP_CONCAT(DISTINCT CONCAT(TABLE_NAME, ' → ', 含义, ' [', 类型, ']')
                 SEPARATOR '  ||  ')             AS 明细
FROM d
GROUP BY COLUMN_NAME
HAVING COUNT(DISTINCT 含义) >= 2
ORDER BY 类型数 DESC, 释义数 DESC, 出现表数 DESC, COLUMN_NAME;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-05 · 类型缺注与注释缺失侦测
   用途：凡 COLUMN_COMMENT 为空或无 source_type 前缀者，其真实类型无从判定，
         一切 CAST 皆属臆测。此清单即「不得使用之字段」名录。
   ▸ 导出：需要 —— 存为「数据库/Z05_missing_typehint.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT
    TABLE_NAME                        AS 表名,
    ORDINAL_POSITION                  AS 列序,
    COLUMN_NAME                       AS 列名,
    DATA_TYPE                         AS 存储类型,
    COLUMN_COMMENT                    AS 原始注释,
    CASE
      WHEN COLUMN_COMMENT IS NULL OR TRIM(COLUMN_COMMENT) = ''      THEN '🔴 无任何注释'
      WHEN COLUMN_COMMENT NOT LIKE '%source_type=%'                 THEN '🟠 缺原始类型'
      WHEN TRIM(REGEXP_REPLACE(COLUMN_COMMENT,'source_type=[^;]+;','')) = ''
                                                                    THEN '🟠 有类型无含义'
      ELSE '🟢 完整'
    END                               AS 状态
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND (COLUMN_COMMENT IS NULL
       OR TRIM(COLUMN_COMMENT) = ''
       OR COLUMN_COMMENT NOT LIKE '%source_type=%'
       OR TRIM(REGEXP_REPLACE(COLUMN_COMMENT,'source_type=[^;]+;','')) = '')
ORDER BY 状态, TABLE_NAME, ORDINAL_POSITION;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-06 · 生成逐列高频值普查语句（★ 令哨兵值自行现形）
   原理：真实业务取值在秒级或金额级上近乎连续，任一具体取值之占比极低；
         哨兵值则表现为单点尖峰。故取每列高频前 20，异常者自现，
         **不预设 -1／0／unknown／1970-01-01 之类候选清单**——
         手拟必漏，且会遗漏 9999-12-31、1900-01-01、'N/A'、'null' 字符串、
         -999、全角空格等未曾预料者。
   用法：先跑本条**生成** SQL，再逐条执行其输出（承纪律②，禁批量）。
   分批：若表数逾百，先依 §Z-01 之估计行数与业务重要性排序，分批执行。
   ▸ 导出：需要 —— 存为「数据库/Z06_generated_probe_sql.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT
    c.TABLE_NAME                                          AS 表名,
    c.ORDINAL_POSITION                                    AS 列序,
    c.COLUMN_NAME                                         AS 列名,
    t.TABLE_ROWS                                          AS 估计行数,
    CONCAT(
      'SELECT ''', c.TABLE_NAME, ''' AS t, ''', c.COLUMN_NAME, ''' AS c, ',
      'CAST(', c.COLUMN_NAME, ' AS VARCHAR) AS v, COUNT(*) AS n, ',
      'COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct ',
      'FROM ods_mariadb_2b.', c.TABLE_NAME, ' ',
      'GROUP BY 3 ORDER BY n DESC LIMIT 20;'
    )                                                     AS 待执行SQL
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN INFORMATION_SCHEMA.TABLES t
       ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
WHERE c.TABLE_SCHEMA = 'ods_mariadb_2b'
  AND c.COLUMN_NAME NOT IN ('__source_pk','source_db','source_table',
                            'ods_table_name','sync_time')
  AND NOT (   LOWER(c.TABLE_NAME) LIKE '%_bak%'  OR LOWER(c.TABLE_NAME) LIKE '%bak2%'
           OR LOWER(c.TABLE_NAME) LIKE '%_test%' OR LOWER(c.TABLE_NAME) LIKE '%_tmp%'
           OR LOWER(c.TABLE_NAME) LIKE '%_old%'  OR LOWER(c.TABLE_NAME) LIKE '%_copy%')
ORDER BY t.TABLE_ROWS DESC, c.TABLE_NAME, c.ORDINAL_POSITION;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-07 · 普查执行样例（以注单主表示范；其余各表由 §Z-06 生成）
   判读准则（三条，缺一不可）：
     一、单点尖峰：某具体取值之占比较其邻近取值高出数个量级者，列为候选；
     二、语义可疑：取值形如 -1／0／-999／'unknown'／'N/A'／'null'／
         1970-01-01／0000-00-00／9999-12-31／1900-01-01 者，列为候选；
     三、跨列共现：候选行在其余字段是否同步异常——若是，则为系统填充之空行；
         若仅此一列异常，则更可能为 ETL 故障。二者成因不同，处置亦不同。
   ▸ 导出：需要 —— 存为「数据库/Z07_probe_bet02.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
SELECT 'ods_a168_bet02' AS t, 'bet03' AS c, CAST(bet03 AS VARCHAR) AS v,
       COUNT(*) AS n, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS pct
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet04', CAST(bet04 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet39', CAST(bet39 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'eid', CAST(eid AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'gametype', CAST(gametype AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'commission', CAST(commission AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'category', CAST(category AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet09', CAST(bet09 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet10', CAST(bet10 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
UNION ALL
SELECT 'ods_a168_bet02', 'bet11', CAST(bet11 AS VARCHAR),
       COUNT(*), COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()
FROM ods_mariadb_2b.ods_a168_bet02 GROUP BY 3
ORDER BY 1, 2, 4 DESC;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-08 · 局键唯一性与塌缩检验（对应「待-02」·风险最高之一条）
   何以要紧：局键为 bet03 + bet04 + bet39。若三者任一含哨兵值，
         则所有此类注单将被拼成同一「局键」（如 -1|-1|-1），
         **成千上万笔互不相干之注单被聚合为同一局**。
         其后果：该「局」参与会员数暴增，同桌共现于此局产生天量虚假配对；
         玩家局级胜负判定亦全盘错乱。
   须查者：既有产物 `候选_同桌异常_最终版_已去重.csv` 是否已受此污染。
   附带核验：bet03 单列是否已全局唯一——若是，则 bet39 在键中为冗余项。
   ▸ 导出：需要 —— 存为「数据库/Z08_roundkey_integrity.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
WITH v AS (
  SELECT
      CAST(bet03 AS VARCHAR) AS k3,
      CAST(bet04 AS VARCHAR) AS k4,
      CAST(bet39 AS VARCHAR) AS k39,
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR)) AS round_key
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
per_key AS (
  SELECT round_key,
         COUNT(*)                  AS n_rows,
         COUNT(DISTINCT member_id) AS n_member,
         COUNT(DISTINCT k39)       AS n_table
  FROM v GROUP BY round_key
),
per_k3 AS (
  SELECT k3, COUNT(DISTINCT k39) AS n_table_per_k3,
             COUNT(DISTINCT k4)  AS n_k4_per_k3
  FROM v GROUP BY k3
)
SELECT
    (SELECT COUNT(*) FROM v)                                            AS 注单行数,
    (SELECT COUNT(*) FROM per_key)                                      AS 局键数,
    (SELECT MAX(n_rows)   FROM per_key)                                 AS 单局最大注单行数,
    (SELECT MAX(n_member) FROM per_key)                                 AS 单局最大会员数,
    (SELECT PERCENTILE_APPROX(CAST(n_member AS DOUBLE),0.999) FROM per_key)
                                                                        AS 单局会员数P999,
    (SELECT COUNT(*) FROM per_key WHERE n_table > 1)                    AS 跨桌局键数_应为0,
    (SELECT COUNT(*) FROM per_k3 WHERE n_table_per_k3 > 1)              AS bet03跨桌数,
    (SELECT COUNT(*) FROM per_k3)                                       AS bet03唯一值数,
    (SELECT SUM(CASE WHEN k3 IN ('-1','0','') OR k3 IS NULL
                       OR k4 IN ('-1','0','') OR k4 IS NULL
                       OR k39 IN ('-1','0','') OR k39 IS NULL
                     THEN 1 ELSE 0 END) FROM v)                         AS 局键含哨兵值行数;

/* 配套：局键规模排行（若榜首出现 -1|-1|-1 之类且注单数远超其余，即坐实塌缩）
   ▸ 承上条之诊断，本注释块不单独计为一条语句 */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-09 · 时间字段口径核验（对应「待-01」）
   何以要紧：本项目一切「日／月／滚动 30 日」聚合，皆须先确定切日基准。
         候选有三：`dt`（StarRocks 分区日）、`bet07`（帳務日期）、
         `DATE(bet08)`（下注日）。SQL 总包现行一律以 `dt` 切日。
   判读准则：
     · 三数若同为行数，则三者一致，议题消解，**总包现行做法正确，不必改动**；
     · 若 dt = bet07 恒成立而两者皆异于下注日，则 dt 已承载账务日语义，仍不必改；
     · 唯有当 bet07 与 dt 分歧显著时，方须讨论切日基准之更换。
   附带：bet06（開局時間）与 bet08 之差值分布，可一并回答三事——
         bet06 究为「开放下注」抑或「开牌」、下注时长是否恒定、两者时区是否一致。
         若差值集中于 0 至 30 秒，则 bet06 在下注之前且时长约 30 秒；
         若集中于 28800 秒上下，则时区不一致，尾秒相位计算将整体错八小时。
   ▸ 导出：需要 —— 存为「数据库/Z09_time_axis_recon.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
WITH v AS (
  SELECT
      dt,
      CAST(NULLIF(TRIM(bet07),'') AS DATE)      AS d_acct,
      CAST(NULLIF(TRIM(bet06),'') AS DATETIME)  AS t_open,
      CAST(NULLIF(TRIM(bet08),'') AS DATETIME)  AS t_bet
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
)
SELECT
    COUNT(*)                                                        AS 行数,
    SUM(CASE WHEN dt = d_acct THEN 1 ELSE 0 END)                    AS dt等于账务日,
    SUM(CASE WHEN dt = DATE(t_bet) THEN 1 ELSE 0 END)               AS dt等于下注日,
    SUM(CASE WHEN d_acct = DATE(t_bet) THEN 1 ELSE 0 END)           AS 账务日等于下注日,
    SUM(CASE WHEN d_acct IS NULL THEN 1 ELSE 0 END)                 AS 账务日不可用,
    SUM(CASE WHEN t_open IS NULL THEN 1 ELSE 0 END)                 AS 开局时间不可用,
    SUM(CASE WHEN t_bet  IS NULL THEN 1 ELSE 0 END)                 AS 下注时间不可用,
    SUM(CASE WHEN t_bet <= '1971-01-01 00:00:00' THEN 1 ELSE 0 END) AS 下注时间纪元哨兵,
    SUM(CASE WHEN t_open <= '1971-01-01 00:00:00' THEN 1 ELSE 0 END) AS 开局时间纪元哨兵,
    MIN(d_acct)                                                     AS 账务日最小,
    MAX(d_acct)                                                     AS 账务日最大,
    SUM(CASE WHEN TIMESTAMPDIFF(SECOND, t_open, t_bet) <  0 THEN 1 ELSE 0 END)
                                                                    AS 下注早于开局_时序异常,
    MIN(TIMESTAMPDIFF(SECOND, t_open, t_bet))                       AS 下注距开局秒_最小,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.50)
                                                                    AS 下注距开局秒_P50,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.99)
                                                                    AS 下注距开局秒_P99,
    PERCENTILE_APPROX(CAST(TIMESTAMPDIFF(SECOND, t_open, t_bet) AS DOUBLE), 0.999)
                                                                    AS 下注距开局秒_P999,
    MAX(TIMESTAMPDIFF(SECOND, t_open, t_bet))                       AS 下注距开局秒_最大
FROM v;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-10 · 哨兵值定性登记（须携 §Z-07 读数向上游查询后填写）
   本条为**表格模板**，非查询。哨兵值之业务成因无法自数据闭合，
   须逐项向上游确认后，方可决定处置。
   登记字段（十二项，缺一不可）：
     table / column / sentinel_value / row_count / pct / co_anomaly（跨列共现）
     / semantic（业务成因）/ source（谁确认的）/ disposition（剔除／分离／保留）
     / rationale / affected_output / decided_at
   处置对照：
     字段未采集         → 剔除，但须报告剔除量
     该场景下不适用     → 分离，单独分析
     ETL 故障           → 剔除，并向上游报缺陷
     尚未发生（如未结算）→ **不可剔除**，另立状态；剔除将造成选择性偏差
   处置策略（分两派，按字段风险择用）：
     局键三要素 bet03／bet04／bet39 → 装载层一律转 NULL 并剔除
       （局键塌缩之害太重，不容任何遗漏渗入下游）
     荷官／代理等维度字段          → 保留原值另设标志列
       （成因未明，或有单独分析之价值），并加锁定列使旧版产物在导入时强制报错
   ▸ 导出：不需要 —— 登记模板，无结果集
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-11 · 哨兵值处置前后影响量化
   用途：处置一经裁定，须以本条量化其影响，方可对外声明。
   注意：「每局最大会员数」与「同桌共现配对数」两项对局键塌缩最敏感，
         其前后差额即虚假配对之规模。
   前提：本条须待 §Z-10 裁定后方可填入具体排除条件；当前先出「未处置」侧读数，
         作为基线。
   ▸ 导出：需要 —— 存为「数据库/Z11_sentinel_impact.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
WITH v AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CAST(ip    AS VARCHAR) AS ip_addr,
      CONCAT_WS('|', CAST(bet03 AS VARCHAR),
                     CAST(bet04 AS VARCHAR),
                     CAST(bet39 AS VARCHAR)) AS round_key,
      CASE WHEN CAST(bet03 AS VARCHAR) IN ('-1','0','') OR bet03 IS NULL
                OR CAST(bet04 AS VARCHAR) IN ('-1','0','') OR bet04 IS NULL
                OR CAST(bet39 AS VARCHAR) IN ('-1','0','') OR bet39 IS NULL
           THEN 1 ELSE 0 END AS is_sentinel_key
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE bet02 = '101'
),
a AS (
  SELECT COUNT(*) AS n_rows, COUNT(DISTINCT round_key) AS n_key,
         COUNT(DISTINCT member_id) AS n_member, COUNT(DISTINCT ip_addr) AS n_ip
  FROM v
),
b AS (
  SELECT COUNT(*) AS n_rows, COUNT(DISTINCT round_key) AS n_key,
         COUNT(DISTINCT member_id) AS n_member, COUNT(DISTINCT ip_addr) AS n_ip
  FROM v WHERE is_sentinel_key = 0
),
ma AS (SELECT MAX(c) AS m FROM (SELECT round_key, COUNT(DISTINCT member_id) AS c
                                FROM v GROUP BY round_key) x),
mb AS (SELECT MAX(c) AS m FROM (SELECT round_key, COUNT(DISTINCT member_id) AS c
                                FROM v WHERE is_sentinel_key = 0 GROUP BY round_key) y)
SELECT
    a.n_rows   AS 未处置_注单行数,  b.n_rows   AS 已处置_注单行数,
    a.n_key    AS 未处置_局键数,    b.n_key    AS 已处置_局键数,
    a.n_member AS 未处置_会员数,    b.n_member AS 已处置_会员数,
    a.n_ip     AS 未处置_IP数,      b.n_ip     AS 已处置_IP数,
    ma.m       AS 未处置_单局最大会员数,
    mb.m       AS 已处置_单局最大会员数,
    ma.m - mb.m                                       AS 单局最大会员数_差额,
    a.n_rows - b.n_rows                               AS 剔除行数,
    (a.n_rows - b.n_rows) * 1.0 / NULLIF(a.n_rows, 0) AS 剔除占比
FROM a CROSS JOIN b CROSS JOIN ma CROSS JOIN mb;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-12 · 锁定（承既有 late_def 之例）
   本条为纪律陈述，非查询。
   哨兵值处置一经裁定，须于装载层落地，并加**口径锁定列**，
   使不合口径之旧版产物在导入时**强制报错，而非静默通过**。
   既有实例：`late_def` 锁定列——尾靴判据自 round_no >= 50 改为 shoe_pos >= 0.80 后，
   新增该列，令旧版 CSV 在导入时报错。此设计优于纯标志列，
   因其不依赖下游之自觉。
   旧版产物一律重命名为 `_v1_superseded` 后缀存档，**禁止直接删除**。
   ▸ 导出：不需要 —— 纪律陈述，无结果集
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════
   §Z-14 · 零值会员-月性质诊断（NULL 抹平 vs 真实零／自对押）
   ▸ 导出：需要 —— 存为「数据库/Z14_zero_month_diagnosis.csv」（§Z-14 零值诊断）

   ▸ 【本条修订 · 2026-08-18】首跑实测已裁定，并暴露本条自身两处缺陷（已斧正）：
       【已裁定】源库 validbet **零 NULL**（首跑实测 n_vb_null=0／393 行，
                 §Z-12 硬编码版独立复核 n_validbet_dbnull=0／361 行，两版互证）。
                 故：S05 之 0.00E+00 全为真实零，中转层未抹平任何 NULL；
                 「NULL 抹平」假说否定，「S05 信息损毁」登记撤销。
       【缺陷一】首版以 ABS(sum_game_pnl) < 0.005 判「输赢为零」——该阈值系手写普适门槛，
                 违反本包铁律（最小样本量／阈值须逐指标反解，禁写普适数）。
                 实测 135 行假阳性：其 |sum_game_pnl| 皆落于 (0, 0.005)，无一为真零。
                 斧正：改为 **精确等于零**，不设容差。金额列为 DECIMAL(20,4)，
                 精确比较无浮点风险；若日后改用浮点型，须按币种最小刻度反解容差。
       【缺陷二】首版承 §S-05 之 n_orders>=30 月度门槛，致 **23 个洗码为零之会员-月漏检**
                 （§Z-12 无门槛口径实测：洗码为零者共 166 行，首版只见 142 行）。
                 斧正：**取消订单数门槛**——本条为全量诊断，非评分底料，
                 不应继承评分管道之准入门槛；门槛属 §S-05 之口径，不属本条。
   ▸ 用途：★★ 判定「会员×月 洗码量或游戏输赢恰为零」之成因，二择一：
             ① 源字段 validbet／金额列原为 NULL（数据缺陷，波及 F-02 之 §S-05 归属）
             ② 同局对押庄闲所致之真实零（T-05 自对押／打水之风险信号）

   ▸ 立项依据（2026-08-18 R4 审计）：
       · §R01 原始导出实证 Superset 保留 NULL 为空字段（7,200 处），
         而 S05_member_month_panel.csv 全档零空字段、143 行洗码为 0.00E+00
         —— 该档经电子表格中转，NULL 与 0 在文件层已不可分辨。
       · 三项反向检验（两类零值几乎不重合 1/278,729、洗码=0 者退水恒为 0 无矛盾、
         画像短促小额单日）转而支持②。本条回源头作最终判定。

   ▸ 判读契约（首跑已执行完毕，此处存录以备复算；本版为口径修正后之重取）：
       · n_vb_null > 0 且占比高            → 支持①NULL 抹平    【首跑实测：否定】
       · n_vb_null = 0 且 n_hedge_eq 高     → 支持②自对押真实零  【首跑实测：成立】
       · 两者皆低                           → 第三机制，判 UNKNOWN 另查
                                              【首跑实测：244 行系缺陷一之假阳性，已结案】

   ▸ 与既有条目之关系（血统，禁止同名异义）：
       · §S-05  会员×月面板 —— 本条复用其口径（同窗口、同六项清洗、同月粒度），
                 但**不读其 CSV**：目标集于库内现算，杜绝「以待检文件筛待检对象」之循环。
       · §T03   自对押/打水 —— 其 is_self_hedge 为**会员×日×局**级布尔、hedge_rate 为
                 会员级比率；本条另出 n_hedge_rounds / n_hedge_eq，为**会员×月**级计数，
                 粒度不同故另立名，绝不复用 is_self_hedge／hedge_rate 二名。
       · §C06fix 跨账户对打 —— 其 opposite_rate 为**双会员**口径；本条为**单会员自对押**，
                 二者实体数不同，禁止互代。
       · §F-02  洗码量实现分叉 —— 本条为其唯一可实证之判据来源。
       · §Z-12  为「锁定」章（不导出），本条另取 §Z-14；§Z-13 为净化审计结论；
                 §Z-15 已为「前置净化层」预留，故取 Z-14 无碰撞。

   ▸ 铁律遵循：目标集软编码现算（无硬编码会员号清单）；无 OFFSET（无分页）；
             无块注释于语句内；ID 一律显式 CAST；以 dt 分区切日（非 DATE(bet08)）；
             五级代理线全 LEFT JOIN；同单号取最新版本；导出必带 ORDER BY；
             **零容差精确比较**（DECIMAL 精确型，不写任何手工容差数）；
             **不继承 §S-05 之 n_orders>=30 门槛**（诊断条不承评分条之准入）。
   ═══════════════════════════════════════════════════════════════════════ */
WITH ta AS (
  SELECT DISTINCT CAST(NULLIF(TRIM(age001),'') AS BIGINT) AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet38, b.bet39,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.validbet, b.commission, b.category, b.dt,
         ROW_NUMBER() OVER (PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)            AS member_id,
         DATE_TRUNC('month', r.dt)                           AS bet_month,
         r.dt                                                AS dt,
         r.bet39                                             AS table_id,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39)           AS round_key,
         TRIM(r.bet09)                                       AS bet_side,
         TRIM(r.commission)                                  AS commission,
         r.validbet                                          AS vb_txt,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))  AS vb_raw,
         CAST(NULLIF(TRIM(r.bet13),'')    AS DECIMAL(20,4))  AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'')    AS DECIMAL(20,4))  AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'')    AS DECIMAL(20,4))  AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet11),'')    AS DECIMAL(20,8))  AS fx
  FROM ranked r
  LEFT JOIN ta t1 ON t1.agent_id = CAST(NULLIF(TRIM(r.bet18),'') AS BIGINT)
  LEFT JOIN ta t2 ON t2.agent_id = CAST(NULLIF(TRIM(r.bet19),'') AS BIGINT)
  LEFT JOIN ta t3 ON t3.agent_id = CAST(NULLIF(TRIM(r.bet20),'') AS BIGINT)
  LEFT JOIN ta t4 ON t4.agent_id = CAST(NULLIF(TRIM(r.bet21),'') AS BIGINT)
  LEFT JOIN ta t5 ON t5.agent_id = CAST(NULLIF(TRIM(r.bet22),'') AS BIGINT)
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
rnd AS (
  SELECT member_id, bet_month, round_key,
         MAX(CASE WHEN bet_side = 'Banker' THEN 1 ELSE 0 END) AS has_b,
         MAX(CASE WHEN bet_side = 'Player' THEN 1 ELSE 0 END) AS has_p,
         SUM(CASE WHEN bet_side = 'Banker' THEN stake_raw/fx ELSE 0 END) AS stk_b,
         SUM(CASE WHEN bet_side = 'Player' THEN stake_raw/fx ELSE 0 END) AS stk_p,
         SUM((payout_raw - stake_raw)/fx)                                AS pnl_rnd
  FROM base
  GROUP BY member_id, bet_month, round_key
),
mm AS (
  SELECT member_id, bet_month,
         COUNT(*)                                                          AS n_orders,
         COUNT(DISTINCT round_key)                                         AS n_rounds_month,
         COUNT(DISTINCT dt)                                                AS n_days_month,
         COUNT(DISTINCT table_id)                                          AS n_tables_month,
         SUM(CASE WHEN vb_txt IS NULL THEN 1 ELSE 0 END)                   AS n_vb_null,
         SUM(CASE WHEN vb_txt IS NOT NULL AND TRIM(vb_txt) = '' THEN 1 ELSE 0 END)
                                                                           AS n_vb_blank,
         SUM(CASE WHEN vb_raw = 0 THEN 1 ELSE 0 END)                       AS n_vb_true_zero,
         SUM(CASE WHEN vb_raw > 0 THEN 1 ELSE 0 END)                       AS n_vb_positive,
         SUM(vb_raw / fx)                                                  AS sum_valid_bet,
         SUM(stake_raw / fx)                                               AS sum_stake,
         SUM((payout_raw - stake_raw) / fx)                                AS sum_game_pnl,
         SUM(rebate_raw / fx)                                              AS sum_rebate,
         SUM(CASE WHEN commission = '1' THEN 1 ELSE 0 END)                 AS n_order_nocomm
  FROM base
  GROUP BY member_id, bet_month
),
hg AS (
  SELECT member_id, bet_month,
         SUM(CASE WHEN has_b = 1 AND has_p = 1 THEN 1 ELSE 0 END)          AS n_hedge_rounds,
         SUM(CASE WHEN has_b = 1 AND has_p = 1 AND stk_b = stk_p
                  THEN 1 ELSE 0 END)                                       AS n_hedge_eq,
         SUM(CASE WHEN pnl_rnd = 0 THEN 1 ELSE 0 END)                       AS n_zero_pnl_rounds
  FROM rnd
  GROUP BY member_id, bet_month
)
SELECT m.member_id                                                         AS member_id,
       m.bet_month                                                         AS bet_month,
       CASE WHEN COALESCE(m.sum_valid_bet,0) = 0 AND COALESCE(m.sum_game_pnl,0) = 0
                 THEN '洗码与输赢皆为零'
            WHEN COALESCE(m.sum_valid_bet,0) = 0 THEN '洗码贡献为零'
            ELSE '游戏输赢为零' END                                          AS zero_kind,
       CASE WHEN m.sum_valid_bet IS NULL THEN 'NULL' ELSE '有值' END        AS vb_sum_state,
       m.n_orders, m.n_rounds_month, m.n_days_month, m.n_tables_month,
       m.n_vb_null, m.n_vb_blank, m.n_vb_true_zero, m.n_vb_positive,
       m.n_vb_null * 1.0 / NULLIF(m.n_orders,0)                            AS vb_null_share,
       m.sum_valid_bet, m.sum_stake, m.sum_game_pnl, m.sum_rebate,
       m.n_order_nocomm,
       h.n_hedge_rounds, h.n_hedge_eq, h.n_zero_pnl_rounds,
       h.n_hedge_eq * 1.0 / NULLIF(m.n_rounds_month,0)                     AS hedge_eq_share,
       CASE WHEN COALESCE(m.n_vb_null,0) + COALESCE(m.n_vb_blank,0) > 0 THEN '支持①NULL抹平'
            WHEN COALESCE(h.n_hedge_eq,0) > 0                              THEN '支持②自对押真实零'
            ELSE '两者皆低·判UNKNOWN' END                                    AS verdict_hint
FROM mm m
JOIN hg h ON h.member_id = m.member_id AND h.bet_month = m.bet_month
WHERE COALESCE(m.sum_valid_bet,0) = 0
   OR m.sum_valid_bet IS NULL
   OR m.sum_game_pnl = 0
   OR m.sum_game_pnl IS NULL
ORDER BY verdict_hint, m.member_id, m.bet_month;


/* ═══════════════════════════════════════════════════════════════════════════
   导出汇总（与语句一一对应）
     §Z-00  不需要                §Z-07  数据库/Z07_probe_bet02.csv
     §Z-01  数据库/Z01_table_inventory.csv    §Z-08  数据库/Z08_roundkey_integrity.csv
     §Z-02  数据库/Z02_excluded_tables.csv    §Z-09  数据库/Z09_time_axis_recon.csv
     §Z-03  数据库/Z03_column_dictionary.csv  §Z-10  不需要
     §Z-04  数据库/Z04_name_collision.csv     §Z-11  数据库/Z11_sentinel_impact.csv
     §Z-05  数据库/Z05_missing_typehint.csv   §Z-12  不需要
     §Z-06  数据库/Z06_generated_probe_sql.csv   §Z-13  不需要
     §Z-14  数据库/Z14_zero_month_diagnosis.csv   §Z-17  不需要（纪律陈述）
     §Z-18  数据库/P01A_crosstab.csv · P01B_diff_ratio.csv · P01C_split_by_dim.csv
            · P01D_vs_validbet.csv · P01E_identity_test.csv
     §Z-19  数据库/P02A_lmc_samples.csv · P02B_changestatus_patterns.csv
            · P02C_key_check.csv · P02D_events_in_window.csv
   ⚠ 2026-08-18 v4 实测斧正：原文「八个导出名／既有 66 个」系旧版计数。
     v4 实测——Z 族导出名 9 个（Z-01…Z-09 之 8 个 ＋ 新增 §Z-14）；
     全包唯一交付件 75 个（v3 为 74，本轮 §Z-14 新增 1）。
     ★ 原「69 个」之来源已查明：系纯 ASCII 文件名正则扫描所致——
       该模式静默漏计六个中文命名交付件（P0C02_标签口径.csv、P0C03_标记次数分布.csv、
       P0C04_同日泄漏检验.csv、P0C05_标记时点定位.csv、P0C06_LabelB骨架.csv、
       P0C09_安慰剂检验.csv），且未剔占位符 xxx.csv；68＋6＝74（真值），68＋1＝69（旧数）。
       凡扫描本包文件名之脚本，一律须用 Unicode 安全模式。

   优先次序：§Z-01、§Z-02、§Z-04 三条代价近乎为零，宜立即执行——
   其读数将直接决定既有六处同名异义登记册是否完备，
   以及总包与三份 .qmd 是否曾误用备份表。
   §Z-08 与 §Z-09 次之：前者关乎既有同桌产物是否受污染，
   后者关乎切日基准与尾秒相位能否成立。
   ═══════════════════════════════════════════════════════════════════════════ */



/* 顺便提醒一句：max_execution_time 在 MariaDB 和 MySQL 5.7+ 中生效，但它只针对 
   SELECT 语句生效，对 INSERT/UPDATE/DELETE 等写操作无效。如果你的后续 CTE 查询超过 
   15 分钟，这个设置会主动杀掉该查询，防止拖垮数据库。  */
-- ▸ 导出：不需要 —— 会话参数设置，无结果集。每个 Superset 会话开跑前先执行一次。
--
-- ★★★ 2026-08-11 立·会话参数的执行纪律（三次实测失败之教训固化）★★★
--   【一】本段每一行 SET 皆是**独立语句**，务请**一行一跑**，跑完看返回 OK 再跑下一行。
--        切勿整段一次提交——Superset 的语句切分遇行注释内的分号（本段下方
--        「-- SET max_execution_time = 259200000」原即含一个，已移除）可能切出残片。
--   【二】跑之前先按一次 Esc、或在编辑器空白处单击，**确保没有任何高亮选区**。
--        Superset 的规则是「有选中就只跑选中的那一段」——一次误触拖选即跑出半句。
--        实测教训：先生曾两度收到形如
--            Unexpected input 'enable_spill'   ／  Unexpected input 'R03b_player_dealer_daily'
--        的语法错，其共同特征是**送出去的第一个词位于一句话的中间**，
--        即执行的并非编辑器所见之全文，而是一个残片。**病不在 SQL，在选区。**
--   【三】本段**全部可跳过**，不影响任何查询之正确性——它们只管提速与防崩：
--          · query_timeout        默认超时够长即不必改
--          · enable_spill/spill_mode  只在内存不足时起作用
--          · cbo_cte_reuse        对 S-01／S-03／§R02 收益大，**对 §R03 收益有限**
--                                 （§R03 的 CTE 链单向，未被多次引用）
--        故若此段任一行报错，**径行跳过即可**，不必纠缠。
--   【四】辨错之法：若报「Unknown system variable」→ 本版不支持该变量，跳过；
--        若报「syntax error / Unexpected input」→ **是选区或切分之误，不是变量之误**，
--        请重按【一】【二】两条再跑。欲先验其有无，可单跑：
--            SHOW VARIABLES LIKE 'enable_spill'      （跑时自行补分号）
--   【五】新会话须重跑本段（会话级参数不跨会话），惟第【三】条同样适用。
--
SET SESSION query_timeout = 259200;                                                                 -- 会话参数：会话查询超时上限（秒）——本包多条为重查询，须先行放宽
-- SET max_execution_time = 259200000    -- 259200秒 = 259200000毫秒（★ 行内分号已移除：
--                                        --   语句切分器遇注释内的分号可能切出残片，见上方纪律【一】）

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
   D-06 · 玩家尾段十八列指标（实测跑通原文收编）
   个体层 winrate_diff>0 = 49.7% 白噪音，尾段裁定第三重复核
   ▸ 导出：「数据库/S_player_tail.csv」
   ▸ 用途：报告 fetch("S_player_tail")：玩家尾段十八列
   ═══════════════════════════════════════════════════════════════════════ */
/* --- D-06 玩家尾段十八列指标（SQL 端完成，加过滤控制在 10 万行内）----
    ⚠ 2026-08-17 实测斧正：原作「十一项」，实测输出 18 列（1 主键 + 17 指标），
      已核 S_player_tail.csv 为 159,603 行 × 18 列。全段三处一并改正。
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
                                                                                                    -- ⚠ 局键完整性（2026-08-17 实测 · Z08_roundkey_integrity.csv）：曾疑本键缺日期
                                                                                                    --   成分致跨日塌缩（S1 候选）。今实测结案：跨桌局键 0、bet03 跨桌 0、
                                                                                                    --   注单/局键 = 20.73 注/局（塌缩则应达数千）、含哨兵值 103 行（7.8e-7）。
                                                                                                    --   →【塌缩未发生，S1 候选解除】。附：bet03 已单独决定桌号，bet39 于本键属冗余。
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
                                                                                                    -- ⚠ 阈值溯源（2026-08-17）：【基准】0.80（现行代码），业务启发式非统计推导。
                                                                                                    --   【建议默认】暂无——本阈值当前不具可优化性：① 尾段假说已证伪（p=0.5847，
                                                                                                    --   个体层 winrate_diff>0 仅 49.7%），无有效目标函数，网格搜索即在噪音上过拟合；
                                                                                                    --   ② PERCENT_RANK 离散，曝光率随 n_in_round 在 20.0%~33.3% 振荡，目标函数不连续；
                                                                                                    --   ③ 与 L6 闸 n_in_round>=5 强耦合（n=5 时退化为「严格最后一注」），不可分别调参。
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
                                                                                                    -- ⚠ 阈值溯源（2026-08-17 实测 · S_player_tail.csv）：
                                                                                                    --   【基准】30（现行代码）—— 实测 Wilson 95% 宽度 0.3369，为目标 0.15 的 2.25 倍。
                                                                                                    --   原注「低于此样本量宽度 > 0.15」字面为真但具误导：30 并未使宽度达标，
                                                                                                    --   它是工程折中而非统计闸门。
                                                                                                    --   【建议默认】171 —— 宽度 0.1482 首次达标，业务代价极小：会员 159,603→57,676
                                                                                                    --   （留存 36.1%），但洗码量仅损失 6.09%（留存 93.91%），流失者皆低活跃会员。
                                                                                                    --   各档实测：50→0.2671｜100→0.1923｜171→0.1482。代码改动须裁定，现以基准运行。
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
    AND TRIM(v.eid) NOT IN ('-1', '0')       -- 哨兵荷官号一并剔除：-1／0 非真实荷官，不得入评分（2026-08-11 增）
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
                                                                                                    -- ⚠ 同名异义警示（2026-08-17）：本处 tail_share 用 progress（物理时间进度）口径，
                                                                                                    --   与 §D-06 用 max_pr（局内注单时序分位）口径的同名字段【不可比、不可互换】；
                                                                                                    --   两者分母亦异：本处为注单数，D-06 为玩家-局数。建议日后正名区分。
         SUM(p.valid_bet) AS valid_bet, SUM(p.game_pnl) AS game_pnl                                 -- 汇总表达式：取用 valid_bet（有效投注（洗码量））、game_pnl（游戏净输赢），产出「game_pnl」
       FROM pr p LEFT JOIN ipn i ON i.bet_ip=p.bet_ip                                               -- 取数来源：取自本条自建的中间结果集 pr，连接键为 bet_ip（下注 IP）
       WHERE p.progress BETWEEN 0 AND 1.5                                                           -- 过滤条件：限定落入闭区间
       GROUP BY p.member_id HAVING COUNT(*) >= 30)                                                  -- 分组：按 p.member_id HAVING COUNT(*) >= 30) 汇总
SELECT flag_ip,                                                                                     -- 取列：起始取列子句，本行先列 flag_ip
       CASE WHEN tail_share>=0.47 THEN 1 ELSE 0 END AS flag_tail_p90,                               -- 条件分支：产出「flag_tail_p90」
                                                                                                    -- ⚠ 阈值溯源（2026-08-17 实测）：0.47 为硬编码，别名虽称 p90，但实测
                                                                                                    --   tail_share 的 P90 = 0.4156（S_player_tail.csv 159,603 行），偏差 -11.6%。
                                                                                                    --   按 0.47 切命中 10,763 人（6.74%）；按真 P90 切 15,961 人（10.00%）。
                                                                                                    --   【基准】0.47（现行代码）｜【建议默认】改为渲染时实算 P90，勿写死。
                                                                                                    --   另：tail_share>0.6 命中 3,590 人（2.25%），而实测分布【单峰右偏、无双峰】，
                                                                                                    --   0.6 不对应任何自然分界，作为「极度偏好压哨」判据无统计依据，建议撤销。
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
   策略性风控：靴内相对靴位 ≥ 0.80（≈ 靴末 20% 之局位，等价外部报告「第 40 局」）的下注占比
              + 相对靴位 + 注额斜率 + 分段 ROI
   ★★ 2026-08-12 B-01 斧正：判据由绝对局号 round_no>=50 改为相对靴位 shoe_pos>=0.80 ★★
     依据：外部实测靴长分布（均值 49.86 局、P50=50、P75=52、P90=54、P99=58）。
     第 50 把的相对靴位为 100.3%（以均值计），故 round_no>=50 实为「靴的最后一局
     及长于中位数的那半数靴」——约半数牌靴无末段可言，late_share 被系统性压低。
     新判据固定的是**局位区间**（每靴末 20% 的局），不是下注占比；late_share 仍由
     实际下注行为决定，均匀下注之零偏好基准下期望约 20%，实际可为 0%~100%。
   ★ 新增 late_def 口径锁列：旧版 CSV 因缺此列而在报告侧读入时当场报错，
     使「新文字配旧数字」的静默语义漂移变成显式失败。
   对应报告：@sec-r01
   输出列：late_def(口径锁), uid, n_orders_all, n_orders_late, late_share, shoe_pos_p50,
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
shoe_len AS (          /* ★ 命名警示：本 CTE 名为 shoe_len（靴长）系历史沿用，其所算 max_round = MAX(round_no) 为『该靴该桌观测到的最大局号』，非 COUNT(round_no) 之局数；二者仅在局号自1起连续无缺口时相等。选 MAX 为刻意设计：对中间缺口免疫，COUNT 会因清洗剔单而使分母缩水。★ B-01 斧正（2026-08-12）：定标基准逐靴现算，绝对局号不是固定靴位 */   -- 缺陷一修正：定标基准不定，固定 50 不是固定位置
  SELECT shoe_id, table_id, MAX(round_no) AS max_round                                              -- 取列：取最大局号（≠COUNT 局数），产出「max_round」
  FROM base GROUP BY shoe_id, table_id                                                              -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
enriched AS (                                                                                       -- 公共表表达式：开启中间结果集 enriched，其后各行为其定义体（§R01）
  SELECT b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round,                               -- 取列：起始取列子句，本行先列 b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round，涉 member_id（会员号）
         b.round_no * 1.0 / NULLIF(s.max_round,0)     AS shoe_pos,                                  -- 取值表达式：产出「shoe_pos」
         b.stake_raw / b.fx                           AS stake,                                     -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (b.payout_raw - b.stake_raw) / b.fx          AS game_pnl,                                  -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         CASE WHEN b.round_no * 1.0 / NULLIF(s.max_round,0) >= 0.80
              THEN 1 ELSE 0 END                        AS is_late   -- B-01 斧正：相对靴位                                    -- 条件分支：产出「is_late」
  FROM base b                                                                                       -- 取数来源：取自本条自建的中间结果集 base
  JOIN shoe_len s ON s.shoe_id = b.shoe_id AND s.table_id = b.table_id                              -- 连接：取自本条自建的中间结果集 shoe_len，连接键为 s.shoe_id = b.shoe_id AND s.table_id = b.table_id
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R01）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  member_id                                                     AS uid,                             -- 取值表达式：取用 member_id（会员号）、uid（会员号），产出「uid」
  COUNT(*)                                                      AS n_orders_all,                    -- 计数表达式：产出「n_orders_all」
  SUM(is_late)                                                  AS n_orders_late,                   -- 汇总表达式：产出「n_orders_late」
  'shoe_pos>=0.80'                                              AS late_def,        -- 口径锁：definition_version = v2
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
   ★★ 2026-08-11 提速·四处结构改写（先生实测：第三批逾一分钟未出）★★
     【病根】StarRocks 之 CTE 默认 inline 展开，**被引用 N 次即重算 N 次**。改前实测：
        · `ord` 被 side_base 与 ordb 各引用一次 → ord 子树算 2 遍
        · `pr` 被 player_all 与 pd 各引用一次 → pr 子树算 2 遍
        ⇒ 最贵的 `ranked`（全窗约 1.26 亿注单开窗去重）**共算 2 × 2 = 4 遍**。
     【改一·投影瘦身】`ranked` 原投影 17 列，其中 updatetime／sync_time／dt 只用于
        OVER 内排序、bet02／category 只用于 WHERE——**五者皆无须进入投影**（窗口排序
        直接取自源表）。今去之，开窗须物化的宽度减五列。
     【改二·局键不造字符串】原以 CONCAT_WS 把 bet03+bet04+bet39 拼成 round_key，
        1.26 亿行即造 1.26 亿个字符串，其后又以该长串为分组键（串哈希昂贵）。
        今**三列原样透传、原生分组**，等价而省去造串与串哈希两笔。
     【改三·会员合计改开窗】删 `player_all`，在 pd 之上加一层 `pdw`，
        以 `SUM(...) OVER (PARTITION BY member_id)` 求五项合计。
        **等价性可证**：pd 是 pr 按「会员×荷官×哨兵」的分组，player_all 是 pr 按
        「会员」的分组；对 pd 再按会员求和，与直接对 pr 按会员求和**逐值相等**
        （分组求和的结合律）。原为 INNER JOIN 且每行 pd 必有其会员，**行数亦不变**。
        **pr 自此只被引用一次。**
     【改四·一处曾试而回退，记其始末】曾把 side_base 并入 ordb，改以窗口
        `SUM(...) OVER (PARTITION BY bet_side)` 就地算基准，本意令 ord 由二引降一引。
        **惟随即察觉此举引入更坏的数据倾斜**：按 bet_side 开窗须把 1.25 亿行按 23 个值
        重分布，而 Banker 一支即占 4,648 万行（37%），单节点必成瓶颈。
        **故已回退为原式**——side_base 独立聚合（**结果仅 23 行**，连接时引擎广播，无倾斜）。
     【必跑】**`SET cbo_cte_reuse = true;` 一行本段须跑**（此前列为可略，今提为必跑）：
        改三已令 pr 只被引用一次，惟 ord 仍被 side_base 与 ordb 各引用一次；
        无此开关则 ord 子树算两遍，`ranked` 亦随之算两遍。
        跑法见 §00 会话参数段纪律【一】【二】：**单独一行跑，跑前清选区**。
        若报「Unknown system variable」（本版不支持），请回报本方，
        另以「冻结基准为字面量」之法处之（须先跑一条仅 23 行的基准查询）。
     【改后】开关命中时 `ranked` **由 4 遍降为 1 遍**；未命中则为 2 遍，仍较改前减半。
     【★ 2026-08-11 定案·L0 与 L1 分工（因 Superset 只读模式每次至多下载十万行）】
        · 事实层 L0 的举证**移交 §R03-inv**（`R03inv_pair_census.csv`，约 30 行，一次导完）：
          各资格档 × 各稀疏分层的边数、会员数、荷官数、局数合计——
          「平台究竟有多少玩家×荷官关系、其中 n=1 者几何」由该件回答。
        · 本件回归 **L1 合格层**：末尾加四条资格谓词（非哨兵、基准非空、有决胜局、
          有效局数 ≥ 30），即 `eligibility_status = 'ELIGIBLE'` 之展开式。
          **预期 517,528 行 → 十万一批共 6 批**，而非 L0 全量的 81 批。
        · **此为工程约束下的明白取舍，非悄悄回退**：L0「不删行」所要防的是
          「稀疏性被藏起来」，而稀疏性已由 §R03-inv 全量点清，举证责任并未落空。
          日后若导出上限放宽，去掉那四条谓词即恢复 L0 全量，一字不必另改。
     【分批下载之法（六批，游标翻页，禁用 OFFSET）】
        第 1 批：末尾加  LIMIT 100000
        第 k+1 批：取上批**末行**的 (member_id, dealer_id) 记作 (M, D)，
                  在 ORDER BY 之前把 WHERE 尾部加一条：
                    AND ( CAST(pdw.member_id AS BIGINT) > M
                       OR ( CAST(pdw.member_id AS BIGINT) = M
                            AND CAST(pdw.dealer_id AS BIGINT) > D ) )
                  并保留 LIMIT 100000。
        ⚠ 每批仍须把整条链算一遍（ORDER BY 施于最终聚合结果，LIMIT 只省传输）——
          **故批数越少越好，这正是回归 L1 的第二个理由**：6 遍而非 81 遍。
     【⚠ 分批无益，反是负优化】终查询的 `ORDER BY` 施于**最终聚合结果**，
        故引擎须把整条链算完（约 1.26 亿注单 → 806 万行）方能挑出头 N 行——
        **`LIMIT` 只省传输，不省计算**。第 1 批与全量同价，81 批即 81 倍代价。
        **故本件一律一次导全，不得分批。**
     【须先生自验】改写不得改数。跑毕请核三事，任一不符即回报本方，不得放行：
        ① 总行数仍应为 8,061,974；
        ② `eligibility_status = 'ELIGIBLE'` 仍应恰为 517,528 行；
        ③ `SENTINEL_DEALER` 仍应为 243,025 行。
   ★ 2026-08-11 立·三层数据契约（L0 事实 → L1 资格 → L2 模型）：
     · 本导出为 **L0 事实层**：**不为统计而删行**。哨兵荷官（eid = -1／0）由「剔除」
       改为「标注」（`is_sentinel_dealer`）；有效局数下限亦由 WHERE 过滤改为
       `eligibility_status` 标注。理由：预先删行会把**稀疏性本身**藏起来，
       令「平台究竟有多少玩家×荷官关系」这一问永远答不出，且生成选择偏差。
     · **L1 资格层**由报告侧（R/Python）按 `eligibility_status = 'ELIGIBLE'` 筛，
       规则显式、可追踪、可复现，且 `eligibility_min_n` 与 `eligibility_rule` 随行落档。
     · **L2 模型层**方作 Z 分数、FDR、阈值与评分。任何一行自 L0→L1→L2 消失，须解释得通。
     ⚠ 体量警示：去掉 n>=30 之后本件行数将大幅膨胀。**务必先跑 §R03-inv 量其规模**，
       依其结果再决定是全量导出，抑或临时施加下限并在报告中明记该下限。
   ★ 2026-08-11 增·对照臂（Dixon & Coles 1996 之法，先生旧作同源）：
     加权基准之优势不得凭断言，须由**无权重基线**对照证成。故并出
     `p_base_mix_unw` 与 `z_score_unw` 作**基线臂**——非诊断附属，而是判定加权是否为
     升级的**唯一标尺**。主估计量仍取加权（`p_base_mix_w` / `z_score`），
     惟其「主」之地位待对照跑毕方为定论；**不得因增设基线臂而把主估计量偷换为等权**。
   ★ 2026-08-11 增·估计量元数据（外部审计第七条：不得再有 magic number）：
     · 估计量：p_base 为**极大似然估计**，$\hat p = x / n$，其中 x = 该投注产品赢的决胜局数、
       n = 该产品决胜局数（game_pnl <> 0；退还局不入分母，见报告结算形态节）。
     · 先验／平滑：**无**。不作 Laplace（α=1）亦不作 Jeffreys（α=0.5）平滑——
       主线产品 n 逾千万，平滑影响小于 1e-7，徒增不可审计的自由度。
     · 零处理：n = 0 者 p_base 为**空**（NULL），并沿 ordb→pr→pd 一路传播，
       其 p_base_mix_w 与 z_score 亦为空。★ 旧版写 COALESCE(s.p_base, 0.5)，
       **以 0.5 顶替缺失基准**——此 0.5 既非先验亦非连续性校正，只是一个凭空的常数，
       对真实胜率或仅 2% 的边注而言荒谬。今删。实测七种产品各只 1 局且该局即退还，
       决胜局为零，正属此类（皆无法通过 n_rounds_eff >= 30 之闸，故旧版实际未致误判）。
     · 局级基准：p_base_round_w 为该局各注 p_side 的**注额加权平均**，权重为各注注额；
       无基准之注不入分子亦不入分母（非以 0 计），全注皆无基准则该局基准为空。
     · 连续性校正：**未施**。判定门槛 n_rounds_eff >= 30，正态近似之误差远小于
       基准本身的不确定性；若日后放宽有效局数门槛，须重估此项。
   ★ 2026-08-11 增·哨兵剔除：eid 取 -1／0 者非真实荷官（转播位／系统位），
     曾凭样本量优势窜居 Z 榜前列，属铁证级假阳性——自源头逐出检验总体。
     同一过滤同步进 S-02／§R03b／§EX-05 三处荷官键查询（§DX-05 无荷官键，未动）；
     四件涉荷官导出**均须重导**；报告 R 侧另有防御性剔除，旧档在重导前仍可安全使用
     （多重比较校正见报告 @sec-r03-fdr）。
   输出列：uid, dealer_id, stake_amount, profit_amount, net_pnl, win_rate,
           n_related_orders, n_rounds_eff, p_base_mix_w, z_score,
           net_pnl_all, game_pnl_all, stake_all, win_rate_all, win_rate_other
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R03_player_dealer.csv」（§R03 玩家×荷官·全窗聚合）。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§R03）
  SELECT b.bet01,                                                                                   -- 取列：起始取列子句——★ 2026-08-11 提速：只投影下游真正用到的列
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）、bet09（玩法）、bet11（汇率）
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,                                               -- 续行：涉 bet13（下注金额）、bet14（派彩金额）、bet17（会员净输赢）、bet38（测试标识）、bet39（桌号）
         b.eid,                                                                                     -- 续行：涉 eid（荷官工号）——★ 已去 updatetime／sync_time／dt／bet02／category 五列（说明见段首提速注记）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R03）
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id, r.eid AS dealer_id,                               -- 取列：起始取列子句，本行先取「dealer_id」，涉 bet05（会员号）、eid（荷官工号）、member_id（会员号）
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,               -- 取值表达式：哨兵标记——★ 2026-08-11 改：由**删除**改为**标注**（事实层不删，分析层才筛）
         r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
         r.bet03, r.bet04, r.bet39,                                                                 -- 续行：★ 提速：局键三列**原样透传**，不再 CONCAT_WS 造字符串（1.25 亿行少造 1.25 亿个串）
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
  SELECT bet_id, member_id, dealer_id, is_sentinel_dealer, bet_side, bet03, bet04, bet39,           -- 取列：起始取列子句，局键改三列透传，涉 bet03（靴号）、bet04（局内序号）、bet39（桌号）
         stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (payout_raw - stake_raw) / fx AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         net_raw / fx                  AS net_pnl                                                   -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
  FROM base                                                                                         -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
side_base AS (      -- ★ 玩法基准胜率：各投注产品各算各的（仅 23 行，连接时广播，无倾斜）
  SELECT bet_side,                                                                                  -- 取列：起始取列子句，本行先列 bet_side
         SUM(CASE WHEN game_pnl >  0 THEN 1 ELSE 0 END) * 1.0                                       -- 取值表达式：该产品赢局数；乘 1.0 以避整数除法截断
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base                    -- 除法或乘法计算：除以决胜局数——退还局不入分母，产出「p_base」
  FROM ord WHERE is_sentinel_dealer = 0                                                             -- 取数来源：取自本条自建的中间结果集 ord——基准只由真实牌桌估计
  GROUP BY bet_side                                                                                 -- 分组：按投注产品汇总——结果仅 23 行
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
ordb AS (             -- 注单层挂上各自产品的基准，供下方按注额加权
  SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet03, o.bet04, o.bet39, o.bet_side,     -- 取列：起始取列子句，局键三列透传
         o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side                                         -- 续行：并取三项金额与该注自身产品的基准胜率，产出「p_side」
  FROM      ord o                                                                                   -- 取数来源：取自本条自建的中间结果集 ord
  LEFT JOIN side_base s ON s.bet_side = o.bet_side                                                  -- 左连接：取自本条自建的中间结果集 side_base（23 行，广播）——基准未定义者留空，不以 0.5 顶替
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
pr AS (             -- ★ 局级去重：同局多单折成一局，Z-score 才不被 √k 倍放大
  SELECT member_id, dealer_id, is_sentinel_dealer, bet03, bet04, bet39,                             -- 取列：起始取列子句，局键改**三列原生分组**——较 CONCAT 字符串分组显著更省
         SUM(stake)    AS stake,                                                                    -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(game_pnl) AS game_pnl,                                                                 -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(net_pnl)  AS net_pnl,                                                                  -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         COUNT(*)      AS n_orders_in_round,                                                        -- 计数表达式：产出「n_orders_in_round」
         SUM(stake * p_side)                                                                        -- 汇总表达式：注额加权基准起算——★ 2026-08-11 斧正，旧法 MAX(bet_side) 取字母序最大而非主注
           / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)                     -- 除法或乘法计算：除以有基准之注的注额合计，权重口径与分子对齐
                       AS p_base_round_w,                                                             -- 续行：产出「p_base_round_w」——该局的**注额加权**基准；全注皆无基准则留空
         AVG(p_side)   AS p_base_round_unw,                                                         -- 汇总表达式：同局各注基准的**等权**均值——★ 2026-08-11 增，供两种 estimand 对照
         MAX(bet_side) AS main_side                                                                 -- 取最大值表达式：字母序最大注项，**仅备查、不参与计算**（旧版据此取基准，已废）
  FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet03, bet04, bet39                  -- 取数来源：取自本条自建的中间结果集 ordb；★ 三列原生分组，等价于原 round_key 分组
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
pd AS (                                                                                             -- 公共表表达式：开启中间结果集 pd，其后各行为其定义体（§R03）
  SELECT p.member_id, p.dealer_id, p.is_sentinel_dealer,                                            -- 取列：起始取列子句，透传哨兵标记，涉 member_id（会员号）、dealer_id（荷官工号）
         COUNT(*)                                          AS n_rounds_eff,                         -- 计数表达式：取用 n_rounds_eff（有效局数），产出「n_rounds_eff」
         SUM(p.n_orders_in_round)                          AS n_orders,                             -- 汇总表达式：产出「n_orders」
         SUM(p.stake)                                      AS stake,                                -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(p.game_pnl)                                   AS game_pnl,                             -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(p.net_pnl)                                    AS net_pnl,                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         SUM(CASE WHEN p.game_pnl >  0 THEN 1 ELSE 0 END)  AS n_win,                                -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「n_win」
         SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)  AS n_dec,                                -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「n_dec」
         AVG(p.p_base_round_w)                               AS p_base_mix_w,                           -- 汇总表达式：对各局的注额加权基准取均值——★ 斧正：旧法以 0.5 顶替未定义基准，今删兜底
         AVG(p.p_base_round_unw)                           AS p_base_mix_unw                        -- 汇总表达式：等权口径之对照量——★ 二者背离即示该会员的资金集中于某一产品
  FROM pr p                                                                                         -- 取数来源：取自本条自建的中间结果集 pr
  -- （已废）旧版在此按 main_side 连 side_base 取基准，2026-08-11 改为注单层注额加权                                       -- 注：连接已移至 ordb，本处不再取基准
  GROUP BY p.member_id, p.dealer_id, p.is_sentinel_dealer                                           -- 分组：按会员×荷官×哨兵标记汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03）
pdw AS (             -- ★ 2026-08-11 提速：会员合计改由 pd 开窗求得，原 player_all 已删
  SELECT p.*,                                                                                       -- 取列：整体承接上游结果集的全部字段，不再逐列列举
         SUM(p.net_pnl)  OVER (PARTITION BY p.member_id) AS net_pnl_all,                            -- 取值表达式：按会员开窗求净输赢合计——★ 与原 player_all 逐值等价（pd 为 pr 之细分组）
         SUM(p.game_pnl) OVER (PARTITION BY p.member_id) AS game_pnl_all,                           -- 取值表达式：按会员开窗求游戏净输赢合计
         SUM(p.stake)    OVER (PARTITION BY p.member_id) AS stake_all,                              -- 取值表达式：按会员开窗求下注额合计
         SUM(p.n_win)    OVER (PARTITION BY p.member_id) AS win_all,                                -- 取值表达式：按会员开窗求赢局合计
         SUM(p.n_dec)    OVER (PARTITION BY p.member_id) AS dec_all                                 -- 取值表达式：按会员开窗求决胜局合计
  FROM pd p                                                                                         -- 取数来源：取自本条自建的中间结果集 pd——★ pr 自此只被引用一次，免 inline 重算
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  pdw.member_id AS uid, pdw.dealer_id, pdw.is_sentinel_dealer,                                         -- 取列：起始取列子句，本行先取「uid」与哨兵标记，涉 member_id（会员号）、dealer_id（荷官工号）
  pdw.stake      AS stake_amount,      -- 需求「投注金额」
  pdw.game_pnl   AS profit_amount,     -- 需求「盈利金额」（剔返水口径）
  pdw.net_pnl,                                                                                       -- 续行：接续上一取列子句，续列 pd.net_pnl，涉 net_pnl（会员净输赢）
  pdw.n_win * 1.0 / NULLIF(pdw.n_dec, 0)              AS win_rate,          -- 需求「胜率」
  pdw.n_orders  AS n_related_orders,                                       -- 需求「关联订单笔数」
  pdw.n_rounds_eff, pdw.p_base_mix_w, pdw.p_base_mix_unw,                                                -- 续行：并出两种口径的基准——注额加权（判定所用）与等权（对照），涉 n_rounds_eff（有效局数）
  pdw.stake      AS total_bet_amount,                                                                -- 取值表达式：该会员×荷官的总注额——★ 暴露量，供判读加权口径是否被少数巨注支配
  pdw.n_orders   AS n_bets,                                                                          -- 取值表达式：注单数——★ 与 n_rounds_eff 并列，可见同局多注之程度
  (pdw.n_win - pdw.n_dec * pdw.p_base_mix_w)                                                             -- 取值表达式：Z 分数之分子——观测胜局减期望胜局（**注额加权基准**，主估计量）
    / NULLIF(SQRT(pdw.n_dec * pdw.p_base_mix_w * (1 - pdw.p_base_mix_w)), 0)  AS z_score_w,            -- 除法或乘法计算：除以伯努利标准差，产出「z_score_w」——**加权候选臂**，分母 n_dec 为决胜局
  (pdw.n_win - pdw.n_dec * pdw.p_base_mix_unw)                                                         -- 取值表达式：★ 2026-08-11 增·**对照臂**——同式改用等权基准（Dixon & Coles 1996 之法：
    / NULLIF(SQRT(pdw.n_dec * pdw.p_base_mix_unw * (1 - pdw.p_base_mix_unw)), 0) AS z_score_unw,       -- 续行：先立无权重基线，加权之优势方能由对照证成），产出「z_score_unw」
  (pdw.n_win - pdw.n_dec * pdw.p_base_mix_w)                                                           -- 取值表达式：兼容别名之分子——与 z_score_w 逐字同式
    / NULLIF(SQRT(pdw.n_dec * pdw.p_base_mix_w * (1 - pdw.p_base_mix_w)), 0)  AS z_score,              -- 除法或乘法计算：产出「z_score」——★ **兼容别名，恒等于 z_score_w**；既有报告与数据契约沿用此名
  pdw.p_base_mix_w - pdw.p_base_mix_unw                AS delta_p,                                    -- 加减计算：比较层——两臂基准之差，产出「delta_p」；正即加权把基准抬高
  (pdw.n_win - pdw.n_dec * pdw.p_base_mix_w)                                                           -- 取值表达式：比较层之 Z 差起算——加权臂
    / NULLIF(SQRT(pdw.n_dec * pdw.p_base_mix_w * (1 - pdw.p_base_mix_w)), 0)                           -- 续行：加权臂 Z
  - (pdw.n_win - pdw.n_dec * pdw.p_base_mix_unw)                                                       -- 续行：减基线臂
    / NULLIF(SQRT(pdw.n_dec * pdw.p_base_mix_unw * (1 - pdw.p_base_mix_unw)), 0) AS delta_z,           -- 续行：产出「delta_z」——★ 判据是 Δ，不是加权臂本身之大小
  pdw.net_pnl_all, pdw.game_pnl_all, pdw.stake_all,                                                    -- 续行：接续上一取列子句，续列 pa.net_pnl_all, pa.game_pnl_all, pa.stake_all
  pdw.win_all * 1.0 / NULLIF(pdw.dec_all, 0)          AS win_rate_all,                                -- 取值表达式：产出「win_rate_all」
  (pdw.win_all - pdw.n_win) * 1.0                                                                     -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断
    / NULLIF(pdw.dec_all - pdw.n_dec, 0)              AS win_rate_other,     -- ★ 对照检验
  CASE WHEN pdw.is_sentinel_dealer = 1        THEN 'SENTINEL_DEALER'                                 -- 取值表达式：统计资格判定起算——★ 2026-08-11 立：**事实层不删，此处只标注资格**
       WHEN pdw.p_base_mix_w IS NULL            THEN 'NO_BASE_RATE'                                    -- 续行：基准未定义（该会员所押产品皆无决胜局）
       WHEN pdw.n_dec = 0                     THEN 'NO_DECISIVE_ROUND'                               -- 续行：全为退还局，无胜负可判
       WHEN pdw.n_rounds_eff < 30             THEN 'INSUFFICIENT_N'                                  -- 续行：有效局数低于阈值报告所立的 30 局下限
       ELSE 'ELIGIBLE' END                   AS eligibility_status,                                 -- 续行：产出「eligibility_status」——分析层据此筛选，规则显式可追踪
  30                                         AS eligibility_min_n,                                  -- 取值表达式：本次所用的最小有效局数——显式化，改阈只改此处并记入变更日志
  'n_rounds_eff >= 30 且基准非空且非哨兵'      AS eligibility_rule,                                           -- 取值表达式：资格规则之明文，随行落档，免日后追问「当时筛的是什么」
  'L1_ELIGIBILITY'                           AS filter_stage,                                       -- 取值表达式：过滤所处之层——★ L0 事实层不删行，此处只标注其在 L1 资格层的去留
  'v2026-08-11'                              AS filter_rule_version,                                 -- 取值表达式：资格规则版本号——改规则须改版本号并记入变更日志，免「同名不同义」
  'R03_20260811_FULL_v1'                     AS comparison_id,                                      -- 取值表达式：比较批次号——★ 两臂须同批次方可比；口径见下五列，随行落档
  '2026-03-21..2026-08-06'                   AS cmp_time_window,                                    -- 取值表达式：时间窗，产出「cmp_time_window」——两臂必同
  'baccarat_bet02_101_all_pairs_incl_sentinel' AS cmp_population,                                   -- 取值表达式：总体定义（含哨兵之全量对），产出「cmp_population」——两臂必同
  'round_win = game_pnl > 0 (decisive only)' AS cmp_label,                                          -- 取值表达式：标签定义，产出「cmp_label」——两臂必同
  'COMPATIBILITY_ONLY_NOT_PRODUCTION'        AS z_score_alias_status                                -- 取值表达式：★ `z_score` 系兼容别名之状态标记——**禁止作任何模型／排序／阈值／能力值／处置之输入**
FROM pdw                                                                                             -- 取数来源：取自本条自建的中间结果集 pdw（已含会员合计，无须再连 player_all）
-- （已删）旧版在此连 player_all 取会员合计；2026-08-11 改由 pdw 开窗求得，pr 遂只算一遍
WHERE   pdw.is_sentinel_dealer = 0                                                                  -- 过滤条件：★ 2026-08-11 立·L1 合格层——非哨兵荷官
  AND   pdw.p_base_mix_w IS NOT NULL                                                                -- 并列条件：基准已定义（该会员所押产品至少一项有决胜局）
  AND   pdw.n_dec > 0                                                                               -- 并列条件：至少有一局分出胜负（全为退还局者无从判定）
  AND   pdw.n_rounds_eff >= 30                                                                      -- 并列条件：有效局数不少于 30——四者合起来即 eligibility_status = 'ELIGIBLE'
ORDER BY pdw.member_id, pdw.dealer_id;                                                              -- 排序：按**唯一键**升序，可作游标翻页之键；分页铁律①：排序键须唯一
/* ★★ 分页与提速（2026-08-11 立，因先生实测第五批由 18 秒跳至 5 分钟未出）★★
   ── 病因两条，其一慢、其二错 ──
   ① 慢：OFFSET 深翻页。引擎须先排出 OFFSET+LIMIT 那么多行再丢掉前面的，
      堆随偏移增大，逾门槛即由 Top-N 退化为全量排序＋落盘溢写——耗时**跳变**而非渐增。
   ② 错：旧版 ORDER BY z_score DESC, profit_amount DESC **排序键不唯一**——
      实测 517,528 行中 z_score 并列 103,510 组，连次级键都分不开者 452 行。
      以 OFFSET 翻页取之，这 452 行可能重复、可能漏掉，与当年 36.49% 重复率同一病根。
   ── 今改 ORDER BY 为 (member_id, dealer_id)：实测该组合**零重复**，可作游标键。
      屏读若需按 Z 排序，在 Superset 或报告侧排即可，**不必在导出时排**。
   ── 分批下载：一律游标翻页，**禁用 OFFSET** ────────────────────────────────
   第 1 批：在最外层 SELECT 之后加
       LIMIT 100000
   第 k+1 批：取上一批**末行**的 (member_id, dealer_id)，记作 (M, D)，加
       WHERE (CAST(pd.member_id AS BIGINT), CAST(pd.dealer_id AS BIGINT)) > (M, D)
       ORDER BY pd.member_id, pd.dealer_id
       LIMIT 100000
     若引擎不支持行值比较，等价写法：
       WHERE CAST(pd.member_id AS BIGINT) > M
          OR ( CAST(pd.member_id AS BIGINT) = M
               AND CAST(pd.dealer_id AS BIGINT) > D )
   ⚠ 该 WHERE 须加在**最外层**（对 pd 而非对 ranked/base）——
     §99 的哈希切分模板把切点放在上游，那对 T02／B01／K01 安全，
     **对 §R03 不安全**：本段有全局 CTE side_base（各投注产品基准胜率），
     上游切片会令每片各估一套基准，十片十个基准，z_score 彼此不可比。
   ── 预期规模与耗时（§R03-inv 实测为据）────────────────────────────────────
     L0 全量 8,061,974 行 ÷ 每批 10 万 = **81 批**；
     若取 n>=2 则 6,031,067 行 = 61 批；若仍取 n>=30 则 517,528 行 = 6 批。
     游标翻页每批同价：单批 18 秒 → 约 24 分钟；60 秒 → 约 1.4 小时；180 秒 → 约 4 小时。
     （18 秒极可能是缓存命中价；本段须对 1.247 亿注单开窗去重，冷启单批更可能 60~180 秒。）
   ── 自验：ELIGIBLE 应恰 517,528 行、SENTINEL_DEALER 应 243,025 行，对不上即回查。
   ═══════════════════════════════════════════════════════════════════════════ */                                                          -- 排序：按 z_score（降序）, profit_amount（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
/* ⚠️ 此处保留 n_rounds_eff>=30（阈值报告已论证 30 以下噪声主导），
   但**不加** win_rate>0.70 / net_pnl_all>0：四条规则对照表（@sec-r03 的 r03-dual）
   需要在同一份底料上比较需求原口径与修正口径，加了就比不了。 */



/* ───────────────────────────────────────────────────────────────────────────
   §R03-chk · 结算形态实测：庄闲是否 Draw No Bet、各投注产品的两套基准各是多少
   对应报告：@sec-settle
   缘起：报告的 Z 分数分母写作「决胜局」（game_pnl <> 0），而此前正文把含和局的
   无条件概率 45.86% 称作 Z 分数基准——两者不同基。本探针以数据一举定谳。
   ⚠ 转义纪律：'TIP\_1\_%' 的反斜杠为**单层**——LIKE 语义下 \_ 方为字面下划线，
     写成 \\_ 则表示字面反斜杠，该条排除将**静默失效**（本方 2026-08-11 曾一犯，
     系脚本写入时多转义一层所致，已根治）。凡程序化写入 SQL，此处务必复验。
   判读（一句话）：Banker 的 push_rate 若约 9.5%、p_base_dnb 若约 50.7%，
   则 Draw No Bet 坐实，现行分母无误；若 push_rate 近 0，则本平台和局按输结算，
   那是另一桩更大的事——全篇基准须重议，且须先改 SQL 再改报告。
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R03chk_settlement_form.csv」（§R03-chk 结算形态·逐产品两套基准）。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked——口径与 §R03 逐字一致，便于对照（§R03-chk）
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet09,                                      -- 取列：起始取列子句，涉 bet03（靴号）、bet04（局内序号）、bet39（桌号）、bet05（会员号）、bet09（玩法）
         b.bet11, b.bet13, b.bet14, b.bet38, b.eid,                                                 -- 续行：接续上一取列子句，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）、bet38（测试标识）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每注最终态，免修订滞后造成重复
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：取最新一版，产出「rn」
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定百家乐产品大类，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03-chk）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base——有效注单，与 §R03 同口径（§R03-chk）
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.bet09 AS bet_side,                             -- 取列：起始取列子句，涉 bet05（会员号）、eid（荷官工号）、bet09（玩法）
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：三键拼物理局键，产出「round_key」
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))                                           -- 取值表达式：派彩额起算，涉 bet14（派彩金额）
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                        -- 续行：减投注额得游戏净输赢，涉 bet13（下注金额）
          / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS game_pnl                             -- 续行：折汇率归一，产出「game_pnl」——恰为 0 即退还局
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1                                                                                    -- 过滤条件：限定 r.rn等于 1，只取每注最终态
    AND UPPER(TRIM(r.bet38)) = 'N'                                                                  -- 并列条件：剔除测试注单，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：剔除无效会员号，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：汇率须为正，涉 bet11（汇率）
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'                                                 -- 并列条件：排除小费单，涉 bet09（玩法）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03-chk）
pr AS (                                                                                             -- 公共表表达式：开启中间结果集 pr——同局拆单先折叠，与 §R03 同法（§R03-chk）
  SELECT member_id, dealer_id, bet_side, round_key,                                                 -- 取列：起始取列子句，本行先列四键
         SUM(game_pnl) AS game_pnl                                                                  -- 聚合：局内合计游戏净输赢，产出「game_pnl」
  FROM base GROUP BY member_id, dealer_id, bet_side, round_key                                      -- 分组：按会员×荷官×玩法×物理局汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03-chk）
SELECT  UPPER(TRIM(bet_side))                          AS bet_side,                                 -- 取列：起始取列子句，本行先取「bet_side」——逐投注产品分列
        COUNT(*)                                       AS n_rounds,                                 -- 聚合：该产品的总局数，产出「n_rounds」
        SUM(CASE WHEN game_pnl = 0 THEN 1 ELSE 0 END)  AS n_push,                                   -- 聚合：退还局数（game_pnl 恰为 0），产出「n_push」——DNB 的直接证据
        SUM(CASE WHEN game_pnl = 0 THEN 1 ELSE 0 END) * 1.0                                         -- 除法或乘法计算：退还局占比起算
          / NULLIF(COUNT(*), 0)                        AS push_rate,                                -- 续行：除以总局数，产出「push_rate」——庄闲应约 9.5%，押和与边注应近 0
        SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                         -- 除法或乘法计算：决胜局基准起算
          / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base_dnb,                -- 续行：分母取决胜局，产出「p_base_dnb」——报告 Z 分数所用之基，庄应约 50.7%
        SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                         -- 除法或乘法计算：无条件基准起算
          / NULLIF(COUNT(*), 0)                        AS p_base_incl                               -- 续行：分母取全部局，产出「p_base_incl」——庄家优势所用之基，庄应约 45.9%
FROM    pr                                                                                          -- 取数来源：取自本条自建的中间结果集 pr
GROUP BY UPPER(TRIM(bet_side))                                                                      -- 分组：按投注产品汇总——23 种各出一行
ORDER BY n_rounds DESC;                                                                             -- 排序：按局数降序，主线三门居前



/* ═══════════════════════════════════════════════════════════════════════════
   §R03-inv · 玩家×荷官关系的体量与稀疏度盘点：全量导出前先量其规模
   ---------------------------------------------------------------------------
   缘起：§R03 依三层契约改为 L0 事实层（不为统计而删行），去掉 n>=30 之后行数将膨胀。
   导出之前须先知其规模；且此表本身即回答一个此前答不出的问题——
   **平台究竟有多少玩家×荷官关系？其中多少够格进统计？**
   旧版直接 WHERE n>=30 导出，把 n=0/1/2 的长尾整个藏起来，
   而稀疏性恰是本项目最重要的红队证据之一（见报告关系特征三层一节）。
   读法：ELIGIBLE 一行即新版 §R03 的可分析行数；各行之和即 L0 全量行数。
   若全量过大（逾千万），可临时施加下限，但**须在报告中明记该下限与其影响**。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：需要 —— 存为「数据库/R03inv_pair_census.csv」（§R03-inv 玩家×荷官关系普查·L0 全量）。
-- ★ 2026-08-11 由「屏显」改为「导出件」：Superset 只读模式每次至多下载十万行，
--   §R03 的 L0 全量（806 万行）须 81 次下载、且每次须把整条链全算一遍，工程上不可行。
--   而 L0「不删行」所要防的，是**稀疏性被藏起来**——本表恰以约三十行把它全量点清
--   （各资格档 × 各稀疏分层的边数、会员数、荷官数、局数合计）。
--   **故 L0 的举证责任自此由本表承担**，§R03 回归 L1 合格层导出。二者分工写死于此，
--   日后任何人问「平台究竟有多少玩家×荷官关系、其中 n=1 者几何」，答案在本件而非 §R03。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked——口径与 §R03 一字不差（§R03-inv）
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet09, b.bet11,                             -- 取列：起始取列子句，涉 bet03（靴号）、bet04（局内序号）、bet39（桌号）、bet05（会员号）
         b.bet13, b.bet14, b.bet38, b.eid,                                                          -- 续行：接续上一取列子句，涉 bet13（下注金额）、bet14（派彩金额）、bet38（测试标识）
         ROW_NUMBER() OVER (PARTITION BY b.bet01                                                    -- 行号窗口表达式：按注单号开窗取最终态
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：取最新一版，产出「rn」
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定百家乐产品大类，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03-inv）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base——有效注单，哨兵**标注不删**（§R03-inv）
  SELECT r.bet05 AS member_id, r.eid AS dealer_id,                                                  -- 取列：起始取列子句，涉 bet05（会员号）、eid（荷官工号）
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,               -- 取值表达式：哨兵标记，产出「is_sentinel_dealer」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：三键拼物理局键，产出「round_key」
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))                                           -- 取值表达式：派彩额起算，涉 bet14（派彩金额）
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))                                        -- 续行：减投注额得游戏净输赢，涉 bet13（下注金额）
          / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS game_pnl                             -- 续行：折汇率归一，产出「game_pnl」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'                                                     -- 过滤条件：只取每注最终态且非测试单，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：剔除无效会员号，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：汇率须为正，涉 bet11（汇率）
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL                                                          -- 并列条件：荷官号非空——空号无从归属，不构成关系
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\\_1\\_%'                                                 -- 并列条件：排除小费单，涉 bet09（玩法）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03-inv）
pr AS (                                                                                             -- 公共表表达式：开启中间结果集 pr——同局多注折成一局（§R03-inv）
  SELECT member_id, dealer_id, is_sentinel_dealer, round_key,                                       -- 取列：起始取列子句，本行先列四键
         SUM(game_pnl) AS game_pnl                                                                  -- 聚合：局内合计游戏净输赢，产出「game_pnl」
  FROM base GROUP BY member_id, dealer_id, is_sentinel_dealer, round_key                            -- 分组：按会员×荷官×哨兵标记×物理局汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03-inv）
pd AS (                                                                                             -- 公共表表达式：开启中间结果集 pd——玩家×荷官关系级（§R03-inv）
  SELECT member_id, dealer_id, is_sentinel_dealer,                                                  -- 取列：起始取列子句，本行先列三键
         COUNT(*)                                          AS n_rounds_eff,                         -- 计数表达式：有效局数，产出「n_rounds_eff」
         SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END)    AS n_dec                                 -- 聚合：决胜局数（退还局不入），产出「n_dec」
  FROM pr GROUP BY member_id, dealer_id, is_sentinel_dealer                                         -- 分组：按会员×荷官×哨兵标记汇总
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03-inv）
SELECT  CASE WHEN is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'                                     -- 取值表达式：资格分档起算——与 §R03 的 eligibility_status 逐字同口径
             WHEN n_dec = 0              THEN 'NO_DECISIVE_ROUND'                                   -- 续行：全为退还局
             WHEN n_rounds_eff < 30      THEN 'INSUFFICIENT_N'                                      -- 续行：局数不足 30
             ELSE 'ELIGIBLE' END                           AS eligibility_status,                   -- 续行：产出「eligibility_status」
        CASE WHEN n_rounds_eff = 1 THEN '01_n=1'                                                    -- 取值表达式：稀疏分层起算——长尾的形状此前被 WHERE 藏起，今逐层点清
             WHEN n_rounds_eff <= 2  THEN '02_n=2'                                                  -- 续行：n 等于 2
             WHEN n_rounds_eff <= 5  THEN '03_n=3~5'                                                -- 续行：n 介于 3 至 5
             WHEN n_rounds_eff <= 10 THEN '04_n=6~10'                                               -- 续行：n 介于 6 至 10
             WHEN n_rounds_eff <= 29 THEN '05_n=11~29'                                              -- 续行：n 介于 11 至 29
             WHEN n_rounds_eff <= 100 THEN '06_n=30~100'                                            -- 续行：n 介于 30 至 100
             ELSE '07_n>100' END                           AS n_bucket,                             -- 续行：产出「n_bucket」
        COUNT(*)                                          AS n_pairs,                               -- 计数表达式：该格的玩家×荷官关系数，产出「n_pairs」
        COUNT(DISTINCT member_id)                         AS n_members,                             -- 计数表达式：涉及会员数（去重），产出「n_members」
        COUNT(DISTINCT dealer_id)                         AS n_dealers,                             -- 计数表达式：涉及荷官数（去重），产出「n_dealers」
        SUM(n_rounds_eff)                                 AS n_rounds_total                         -- 聚合：该格的有效局合计，产出「n_rounds_total」
FROM    pd                                                                                          -- 取数来源：取自本条自建的中间结果集 pd
GROUP BY 1, 2                                                                                       -- 分组：按资格分档与稀疏分层汇总
ORDER BY 1, 2;                                                                                      -- 排序：按资格与分层升序——长尾形状一目了然



/* ═══════════════════════════════════════════════════════════════════════════
   §RC-00 · 关系普查·计数层：平台究竟存在多少条「实体×实体」的边
   对应报告：@sec-relation-census
   ---------------------------------------------------------------------------
   缘起：「跨产品、跨实体、跨局、跨设备、跨 IP 一个不遗漏地算全关系」——
   **发现层**当为之，**入模层**不可为之（论证见报告 @sec-relation-layer）。
   而发现层的第一步不是把边全导出来（那是数千万至上亿行），
   是先**数一数每类边有多少条、其稀疏形状如何**。本查询即此，输出仅数十行。
   ⚠ 一条须先说破的事实：**关系普查在最细粒度上会退化为注单表本身**——
   「玩家×荷官×产品×桌×IP×局×日」的一行，就是一张注单。故普查的设计问题
   不是「要不要全」，而是**要物化哪几个边缘投影**。本表逐一给出各投影的边数，
   使这一取舍有据可依，而非拍脑袋。
   读法：n_edges 即该类边的**可观测**条数（非笛卡尔上界）；
   n_edges_ge30 为够格进统计者。两者之比即该层的「统计可用率」——
   比值越低，说明该层越稀疏、越不宜直接入模。
   ⚠ 设备一轴**本表未含**：库内有无设备字段尚未核实（见 §TL-12），
   **不得在字段未证之前把它写进普查规格**。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §RC-00 关系普查计数层，屏幕看结果。
WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked——口径与 §R03 一致（§RC-00）
  SELECT b.bet01, b.bet03, b.bet04, b.bet39, b.bet05, b.bet09, b.bet11,                             -- 取列：起始取列子句，涉 bet03（靴号）、bet04（局内序号）、bet39（桌号）、bet05（会员号）、bet09（玩法）
         b.bet13, b.bet38, b.eid, b.ip, b.bet18, b.bet19, b.bet20,                                  -- 续行：接续上一取列子句，涉 bet38（测试标识）、eid（荷官工号）、ip（下注 IP）、bet18~20（代理线）
         ROW_NUMBER() OVER (PARTITION BY b.bet01                                                    -- 行号窗口表达式：按注单号开窗取最终态
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：取最新一版，产出「rn」
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定百家乐产品大类，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§RC-00）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base——有效注单，哨兵标注不删（§RC-00）
  SELECT r.bet05 AS player_id, r.eid AS dealer_id, r.bet09 AS product_id,                           -- 取列：起始取列子句，三轴，涉 bet05（会员号）、eid（荷官工号）、bet09（玩法）
         r.bet39 AS table_id, r.ip AS ip_id, r.bet18 AS agent_lv1,                                  -- 续行：另三轴，涉 bet39（桌号）、ip（下注 IP）、bet18（一级代理线）
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key                                     -- 取值表达式：三键拼物理局键，产出「round_key」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'                                                     -- 过滤条件：只取每注最终态且非测试单，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：剔除无效会员号，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：汇率须为正，涉 bet11（汇率）
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\\_1\\_%'                                                 -- 并列条件：排除小费单，涉 bet09（玩法）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§RC-00）
SELECT '玩家×荷官' AS edge_type,                                                                        -- 取值表达式：边类型，产出「edge_type」
       COUNT(*)                                  AS n_edges,                                        -- 计数表达式：可观测边数（非笛卡尔上界），产出「n_edges」
       SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END)  AS n_edges_ge30,                                   -- 聚合：够格进统计之边数，产出「n_edges_ge30」
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END)    AS n_edges_n1,                                     -- 聚合：只出现一次之边——稀疏长尾之头，产出「n_edges_n1」
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END)   AS n_edges_le5,                                    -- 聚合：n≤5 之边，产出「n_edges_le5」——P(n≤5) 之分子
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END)  AS n_edges_le10,                                   -- 聚合：n≤10 之边，产出「n_edges_le10」
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END)  AS n_edges_lt30,                                   -- 聚合：n<30 之边，产出「n_edges_lt30」——与 n_edges_ge30 互补，二者之和即 n_edges
       SUM(n)                                    AS n_bets_total                                    -- 聚合：该层注单合计，产出「n_bets_total」
FROM ( SELECT player_id, dealer_id, COUNT(*) AS n FROM base                                         -- 取数来源：玩家×荷官投影
       GROUP BY player_id, dealer_id ) t1                                                           -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT '玩家×产品', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                                 -- 取值表达式：边类型与三项计数
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT player_id, product_id, COUNT(*) AS n FROM base                                        -- 取数来源：玩家×产品投影
       GROUP BY player_id, product_id ) t2                                                          -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT '玩家×桌', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                                  -- 取值表达式：边类型与三项计数
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT player_id, table_id, COUNT(*) AS n FROM base                                          -- 取数来源：玩家×桌投影
       GROUP BY player_id, table_id ) t3                                                            -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT '玩家×IP', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                                 -- 取值表达式：边类型与三项计数
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT player_id, ip_id, COUNT(*) AS n FROM base                                             -- 取数来源：玩家×IP 投影
       GROUP BY player_id, ip_id ) t4                                                               -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT '荷官×产品', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                                 -- 取值表达式：边类型与三项计数
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT dealer_id, product_id, COUNT(*) AS n FROM base                                        -- 取数来源：荷官×产品投影
       GROUP BY dealer_id, product_id ) t5                                                          -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT '荷官×桌', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                                  -- 取值表达式：边类型与三项计数
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT dealer_id, table_id, COUNT(*) AS n FROM base                                          -- 取数来源：荷官×桌投影
       GROUP BY dealer_id, table_id ) t6                                                            -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT 'IP×代理线', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                                -- 取值表达式：边类型与三项计数
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT ip_id, agent_lv1, COUNT(*) AS n FROM base                                             -- 取数来源：IP×一级代理线投影——跨代理共用 IP 是团伙的强结构证据
       GROUP BY ip_id, agent_lv1 ) t7                                                               -- 分组：按二轴汇总得边
UNION ALL                                                                                           -- 集合运算：纵向拼接下一类边
SELECT '玩家×荷官×产品（三元）', COUNT(*), SUM(CASE WHEN n >= 30 THEN 1 ELSE 0 END),                          -- 取值表达式：三元投影——用以实测「每细分一层，格内样本塌陷多少」
       SUM(CASE WHEN n = 1 THEN 1 ELSE 0 END),                                                      -- 续行：续列长尾数（n=1）
       SUM(CASE WHEN n <= 5 THEN 1 ELSE 0 END),                                                     -- 续行：续列 n≤5
       SUM(CASE WHEN n <= 10 THEN 1 ELSE 0 END),                                                    -- 续行：续列 n≤10
       SUM(CASE WHEN n <= 29 THEN 1 ELSE 0 END), SUM(n)                                             -- 续行：续列 n<30 与注单合计
FROM ( SELECT player_id, dealer_id, product_id, COUNT(*) AS n FROM base                             -- 取数来源：玩家×荷官×产品投影
       GROUP BY player_id, dealer_id, product_id ) t8                                               -- 分组：按三轴汇总得边
ORDER BY n_edges DESC;                                                                              -- 排序：按边数降序——体量与稀疏形状一目了然



/* ═══════════════════════════════════════════════════════════════════════════
   §BZ-00 · 经营指标可得性普查：营业额／注册／充值／访问，究竟哪几项库内真有
   对应报告：@sec-capability-forecast
   ---------------------------------------------------------------------------
   缘起：先生令「营业额、新浏览、注册会员数、新或持续充值、盈利之增减，
   一律须由各实体各领域能力值预测出来」。而预测的前提是**标的须可观测**——
   库内没有的东西，任何模型都预测不出，宣称能预测即是空言。
   本查询逐一扫描候选承载表的列义，判定五项标的各自的可得性。
   已知线索（由 §00 表清单得）：
     · ods_a168_dailyreport_member   会员日报——最可能承载充值／提款／输赢日汇总
     · ods_a168_log_age_cash_change  代理资金变动日志——可能承载上下分／充提
     · ods_a168_conversion           转换记录——待查其义
     · ods_a168_member_dtl           会员主档明细（§TG-01 已证其 22 列**无注册时间**）
     · ods_a168_tablelimit           ★ 桌台限额表——极可能即 §TL-13 所寻的限额字典
   ⚠ 「新浏览」一项：库内**并无任何网站分析／会话／页面浏览表**，
     故其可得性预判为「⛔ 不可得」。本查询若亦查无，即以此定案，
     报告须明写「该指标不在数据资产之内」，**不得以活跃会员数顶替**——
     二者不是一回事（顶替即是偷换标的）。
   读法：凡 COLUMN_COMMENT 译出为充值／提款／注册时间／上下分者，即为可用承载列；
   译不出者须回查其取值分布再定，**不得凭列名猜义**（bet41／bet14 之鉴在前）。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §BZ-00 经营指标可得性普查，屏幕看结果。
SELECT  TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT                        -- 取列：起始取列子句，逐列列出表名、序位、列名、类型与列义
FROM    information_schema.columns                                                                  -- 取数来源：取自库内元数据字典（列级）
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定本项目所用库
  AND ( TABLE_NAME IN ('ods_a168_dailyreport_member',                                               -- 并列条件：候选承载表起算——会员日报
                       'ods_a168_log_age_cash_change',                                              -- 续行：代理资金变动日志
                       'ods_a168_conversion',                                                       -- 续行：转换记录
                       'ods_a168_member_dtl',                                                       -- 续行：会员主档明细
                       'ods_a168_tablelimit')                                                       -- 续行：桌台限额表——★ 兼答 §TL-13 之问
     OR LOWER(COLUMN_NAME) LIKE '%deposit%'                                                         -- 并列条件：列名候选起算——充值
     OR LOWER(COLUMN_NAME) LIKE '%withdraw%'                                                        -- 续行：提款
     OR LOWER(COLUMN_NAME) LIKE '%recharge%'                                                        -- 续行：充值别名
     OR LOWER(COLUMN_NAME) LIKE '%regist%'                                                          -- 续行：注册
     OR LOWER(COLUMN_NAME) LIKE '%signup%'                                                          -- 续行：注册别名
     OR LOWER(COLUMN_NAME) LIKE '%visit%'                                                           -- 续行：访问——预判查无，查无即定案
     OR LOWER(COLUMN_NAME) LIKE '%session%'                                                         -- 续行：会话
     OR LOWER(COLUMN_NAME) LIKE '%pageview%'                                                        -- 续行：页面浏览
     OR COLUMN_COMMENT LIKE '%充值%'                                                                  -- 并列条件：中文列义候选起算——充值
     OR COLUMN_COMMENT LIKE '%存款%'                                                                  -- 续行：存款
     OR COLUMN_COMMENT LIKE '%提款%'                                                                  -- 续行：提款
     OR COLUMN_COMMENT LIKE '%上分%'                                                                  -- 续行：上分
     OR COLUMN_COMMENT LIKE '%下分%'                                                                  -- 续行：下分
     OR COLUMN_COMMENT LIKE '%注册%'                                                                  -- 续行：注册
     OR COLUMN_COMMENT LIKE '%開戶%'                                                                  -- 续行：繁体开户
     OR COLUMN_COMMENT LIKE '%开户%'                                                                  -- 续行：简体开户
     OR COLUMN_COMMENT LIKE '%訪問%'                                                                  -- 续行：繁体访问
     OR COLUMN_COMMENT LIKE '%登入%'                                                                  -- 续行：登入——退而求其次的活跃代理量，惟不得顶替「新浏览」
     OR COLUMN_COMMENT LIKE '%限額%'                                                                  -- 续行：繁体限额——兼答限额字典之问
     OR LOWER(COLUMN_NAME) LIKE '%bonus%'                                                           -- 并列条件：红利／彩金——★ NGR 之构件，查其有无以定 NGR 可算与否
     OR LOWER(COLUMN_NAME) LIKE '%promo%'                                                           -- 续行：活动／推广成本
     OR LOWER(COLUMN_NAME) LIKE '%coupon%'                                                          -- 续行：优惠券
     OR COLUMN_COMMENT LIKE '%紅利%'                                                                  -- 续行：繁体红利
     OR COLUMN_COMMENT LIKE '%红利%'                                                                  -- 续行：简体红利
     OR COLUMN_COMMENT LIKE '%優惠%'                                                                  -- 续行：繁体优惠
     OR COLUMN_COMMENT LIKE '%优惠%'                                                                  -- 续行：简体优惠
     OR COLUMN_COMMENT LIKE '%活動%'                                                                  -- 续行：繁体活动
     OR COLUMN_COMMENT LIKE '%活动%'                                                                  -- 续行：简体活动——以上七项决定 NGR 能否全口径计算
     OR COLUMN_COMMENT LIKE '%限额%' )                                                                -- 续行：简体限额——并收束整个候选条件组
ORDER BY TABLE_NAME, ORDINAL_POSITION;                                                              -- 排序：按表名与列序位升序——逐表可读



/* ═══════════════════════════════════════════════════════════════════════════
   §TL-13b · 限额字典最后一里：组 ID 究竟对应多少钱，孰紧孰松
   对应报告：@sec-probe-findings
   ---------------------------------------------------------------------------
   §TL-13 已查得四张承载表，其中最关键的一项是**解开了一个新的同名异义**：
     · ods_a168_member.mem015      = login_error（§TL-09 已证）
     · ods_a168_member_dtl.mem015  = **新版限額**（varchar(300)）★ 同代号异表异义
   而变更日志里的 `101-mem015`，其取值形态（逗号分隔整数串）与 member_dtl 的
   「新版限額」完全吻合——**故 101-mem015 极可能是按产品分设的限红，而非 login_error**。
   ⚠ 但「极可能」不是「已证」。六层判据（物理列→字典→旧值/新值→业务含义→处置动作→
   处置节）目前只走到第二层。本查询走第三、四层：看限额组 ID 的取值与其金额映射，
   **能比大小，方能判孰紧孰松**；判不出方向，限红就进不了处置总体。
   读法：① bet_limit_default 的 set01~set14 若为金额档位，则组 ID 可排序；
         ② 与 §TL-10 中出现过的组 ID（如 3、4、21、350）比对，须能对上；
         ③ member_dtl.mem015 的实际取值形态须与 101-mem015 同形，方证同源。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §TL-13b 限额组取值形态，屏幕看结果。
SELECT  'bet_limit_default' AS src, id AS grp_id, gtype,                                            -- 取列：起始取列子句，产出「src」「grp_id」——限额组定义表之主键与游戏类别
        set01, set02, set03, set04, set05, set06, set07,                                            -- 续行：接续上一取列子句，续列七档设定值——若为金额则可排序
        status, sort                                                                                -- 续行：续列启用状态与排序
FROM    ods_mariadb_2b.ods_a168_bet_limit_default                                                   -- 取数来源：取自限额组定义表（§TL-13 查得）
WHERE   dt = ( SELECT MAX(dt) FROM ods_mariadb_2b.ods_a168_bet_limit_default )                      -- 过滤条件：只取最新一版快照，免同一组多版重复
ORDER BY CAST(NULLIF(TRIM(gtype),'') AS INT), CAST(NULLIF(TRIM(id),'') AS INT)                      -- 排序：按游戏类别与组号升序——档位阶梯一目了然
LIMIT 200;                                                                                          -- 限行：仅看形态，不求全量


/* ═══════════════════════════════════════════════════════════════════════════
   §BZ-01 · 红利与充值流水搜寻：配置表已见，流水表未见
   对应报告：@sec-probe-findings
   ---------------------------------------------------------------------------
   §BZ-00 实测所得可归纳为一句：**见到的全是「配置」，没见到「流水」**——
     · ods_a168_RedPacketSetup     红包活动**设置**（活動獎金是否需打碼、活動規則）
     · ods_a168_category / categoryLevel  存提款**限额**与手续费率
     · ods_a168_urllist.register   一个 int(1) **开关**，非注册时间
   配置回答「规则是什么」，流水回答「实际发了多少钱、谁在何时充了多少」——
   **NGR₃ 能否升为全口径，系于后者而非前者**。本查询专找流水型承载表。
   读法：凡表名含 record／detail／log／order／history 且列义译出为金额与时间者，
   即为流水候选；找到则须再验其与 bet05（会员号）之可关联性。
   ⚠ 找不到亦是结论：则 NGR₃ 三扣口径的命名纪律**永久生效**，
     并写入局限章，不得以活动设置表反推发放额（那是拿规则冒充事实）。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §BZ-01 红利与充值流水搜寻，屏幕看结果。
SELECT  TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT                        -- 取列：起始取列子句，逐列列出表名、序位、列名、类型与列义
FROM    information_schema.columns                                                                  -- 取数来源：取自库内元数据字典（列级）
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定本项目所用库
  AND ( LOWER(TABLE_NAME) LIKE '%redpacket%'                                                        -- 并列条件：表名候选起算——红包（设置表已见，此处找其流水）
     OR LOWER(TABLE_NAME) LIKE '%bonus%'                                                            -- 续行：红利
     OR LOWER(TABLE_NAME) LIKE '%promo%'                                                            -- 续行：活动
     OR LOWER(TABLE_NAME) LIKE '%reward%'                                                           -- 续行：奖励
     OR LOWER(TABLE_NAME) LIKE '%cash%'                                                             -- 续行：资金（log_age_cash_change 即属此类）
     OR LOWER(TABLE_NAME) LIKE '%wallet%'                                                           -- 续行：钱包
     OR LOWER(TABLE_NAME) LIKE '%fund%'                                                             -- 续行：资金变动
     OR LOWER(TABLE_NAME) LIKE '%trans%'                                                            -- 续行：交易
     OR LOWER(TABLE_NAME) LIKE '%order%'                                                            -- 续行：订单
     OR LOWER(TABLE_NAME) LIKE '%payment%'                                                          -- 续行：支付
     OR LOWER(TABLE_NAME) LIKE '%recharge%'                                                         -- 续行：充值
     OR LOWER(TABLE_NAME) LIKE '%deposit%'                                                          -- 续行：存款
     OR LOWER(TABLE_NAME) LIKE '%withdraw%'                                                         -- 续行：提款
     OR LOWER(TABLE_NAME) LIKE '%dailyreport%' )                                                    -- 续行：日报——并收束整个候选条件组
ORDER BY TABLE_NAME, ORDINAL_POSITION;                                                              -- 排序：按表名与列序位升序——逐表可读



/* ═══════════════════════════════════════════════════════════════════════════
   §TL-14 · 限红处置事件：`101-mem015` 的方向判定与处置节起点
   对应报告：@sec-limit-treatment
   ---------------------------------------------------------------------------
   §TL-13b 已把六层判据全数打通：
     ① 物理列：ods_a168_member_dtl.mem015 = 新版限額（★ 与 member.mem015 = login_error
        异表同名，务必分清）；
     ② 数据字典：ods_a168_bet_limit_default，gtype = '101'（百家乐）下有 81 个限额组；
     ③ 旧值/新值：§TL-10 中出现过的组 ID（1、2、3、4、5、6、7、21、350…）**全部在字典内**；
     ④ 业务含义：set01 形如「下限,上限」，可比大小；
     ⑤ 处置动作：`101-mem015` 之值是**允许选用的限额组清单**（逗号分隔），
        故方向取该清单的**最高上限**之变化——降即收紧、升即放宽、平即持平。
        实测四例皆判得出：350→21（5 万→2 万，收紧）、3,21→3,4（2 万→1 万，收紧）、
        「124,59,1,200,2,3,4,162,21,22,184」→「124,59,1」（3 万→1 千，**大幅收紧**）、
        59,22→59,30（3 万→5 万，放宽）。
     ⑥ 处置节：本查询即其事件层，节的折叠沿 §TL-11 同法。
   ⚠ 一处**尚未判明**的歧义，已显式标记而非默认：
     每个 gtype 恰有一个 set01 = '0,0' 的组（百家乐为组 610，其 sort 排在最前）。
     `category` 表的列义写「0 為不限制」，而其 sort 位次又像是**最低档／停用**。
     二者含义相反：若为「不限制」，则含 0 组者应判**最松**；若为「停用」，则应判**最紧**。
     本查询取**停用**解（合于 sort 位次），但另出 `has_zero_group` 一列标记，
     **凡该列为 1 者，其方向判定须人工复核**，不得径入处置总体。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：需要 —— 存为「数据库/TL14_limit_treatment.csv」（§TL-14 限红处置事件·含方向判定）。
WITH dict AS (                                                                                      -- 公共表表达式：开启中间结果集 dict——百家乐限额组字典（§TL-14）
    SELECT  CAST(id AS STRING)                            AS grp_id,                                -- 取值表达式：取用组号并转字符，产出「grp_id」——与变更日志内的字面值同型方能连上
            CAST(NULLIF(TRIM(SPLIT_PART(set01, ',', 1)),'') AS DECIMAL(20,2)) AS lo,                -- 取值表达式：set01 逗号前段为下限，产出「lo」
            CAST(NULLIF(TRIM(SPLIT_PART(set01, ',', 2)),'') AS DECIMAL(20,2)) AS hi                 -- 取值表达式：set01 逗号后段为上限，产出「hi」——方向判定之凭据
    FROM    ods_mariadb_2b.ods_a168_bet_limit_default                                               -- 取数来源：取自限额组定义表（§TL-13 查得）
    WHERE   gtype = '101'                                                                           -- 过滤条件：限定百家乐，与本方案 bet02 = '101' 同口径
      AND   dt = ( SELECT MAX(dt) FROM ods_mariadb_2b.ods_a168_bet_limit_default )                  -- 并列条件：只取最新一版快照，免同组多版重复
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-14）
ev AS (                                                                                             -- 公共表表达式：开启中间结果集 ev——变更日志原始事件，口径与 §TL-11 一致（§TL-14）
    SELECT  CAST(lmc02 AS STRING)                         AS member_id,                             -- 取值表达式：取用 lmc02（被改会员号），产出「member_id」
            SUBSTR(CAST(lmc08 AS STRING), 1, 10)          AS action_date,                           -- 取值表达式：取用 lmc08（操作时间）之日期段，产出「action_date」
            CAST(lmc08 AS STRING)                         AS action_time,                           -- 取值表达式：取用 lmc08（操作时间），产出「action_time」
            CAST(lmc06 AS STRING)                         AS operator_id,                           -- 取值表达式：取用 lmc06（操作人账号），产出「operator_id」
            CAST(lmc07 AS STRING)                         AS operator_lv,                           -- 取值表达式：取用 lmc07（操作人层级），产出「operator_lv」
            CAST(lmc05 AS STRING)                         AS content                                -- 取值表达式：取用 lmc05（变更内容串），产出「content」
    FROM    ods_mariadb_2b.ods_a168_log_mem_change                                                  -- 取数来源：取自会员变更日志表
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
      AND   CAST(lmc04 AS STRING) IN ('edit', 'changestatus')                                       -- 并列条件：只留配置修改与状态变更两类
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-14）
seg AS (                                                                                            -- 公共表表达式：开启中间结果集 seg——把多段 content 逐段拆开（§TL-14）
    SELECT  e.member_id, e.action_date, e.action_time, e.operator_id, e.operator_lv,                -- 取列：起始取列子句，透传五要素
            TRIM(s.piece)                                 AS piece                                  -- 取值表达式：逐段去空白，产出「piece」
    FROM ev e, unnest(split(e.content, ';')) AS s(piece)                                            -- 行展开：以 unnest(split(…)) 把分号分隔的多段逐段成行
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-14）
lim AS (                                                                                            -- 公共表表达式：开启中间结果集 lim——只留百家乐限额变更段（§TL-14）
    SELECT  member_id, action_date, action_time, operator_id, operator_lv,                          -- 取列：起始取列子句，透传五要素
            TRIM(SPLIT_PART(SPLIT_PART(piece, ':', 2), '=>', 1)) AS grp_before,                     -- 取值表达式：箭头前段为旧组清单，产出「grp_before」
            TRIM(SPLIT_PART(piece, '=>', 2))              AS grp_after,                             -- 取值表达式：箭头后段为新组清单，产出「grp_after」
            CONCAT_WS('#', member_id, action_time)        AS ev_key                                 -- 取值表达式：会员×时刻拼事件键，产出「ev_key」——供两侧展开后回接
    FROM    seg                                                                                     -- 取数来源：取自本条自建的中间结果集 seg
    WHERE   piece LIKE '101-mem015:%'                                                               -- 过滤条件：只认百家乐的新版限額段——★ 不得与 member.mem015（login_error）相混
      AND   piece LIKE '%=>%'                                                                       -- 并列条件：须含箭头方为有效变更段
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-14）
bfr AS (                                                                                            -- 公共表表达式：开启中间结果集 bfr——旧组清单逐组展开后取最高上限（§TL-14）
    SELECT  l.ev_key,                                                                               -- 取列：起始取列子句，本行先取事件键
            MAX(d.hi)                                     AS max_hi_before,                         -- 聚合：旧清单之最高上限，产出「max_hi_before」
            SUM(CASE WHEN d.hi = 0 THEN 1 ELSE 0 END)     AS zero_before,                           -- 聚合：旧清单含「0,0」组之个数，产出「zero_before」——歧义标记之料
            COUNT(d.grp_id)                               AS n_grp_before                           -- 计数表达式：旧清单中能连上字典的组数，产出「n_grp_before」
    FROM        lim l                                                                               -- 取数来源：取自本条自建的中间结果集 lim
    CROSS JOIN  unnest(split(l.grp_before, ',')) AS g(grp)                                          -- 行展开：把逗号分隔的组清单逐组成行
    LEFT JOIN   dict d ON d.grp_id = TRIM(g.grp)                                                    -- 左连接：取自本条自建的中间结果集 dict，连接键为组号——连不上者留空，不以 0 顶替
    GROUP BY l.ev_key                                                                               -- 分组：按事件键汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-14）
aft AS (                                                                                            -- 公共表表达式：开启中间结果集 aft——新组清单同法（§TL-14）
    SELECT  l.ev_key,                                                                               -- 取列：起始取列子句，本行先取事件键
            MAX(d.hi)                                     AS max_hi_after,                          -- 聚合：新清单之最高上限，产出「max_hi_after」
            SUM(CASE WHEN d.hi = 0 THEN 1 ELSE 0 END)     AS zero_after,                            -- 聚合：新清单含「0,0」组之个数，产出「zero_after」
            COUNT(d.grp_id)                               AS n_grp_after                            -- 计数表达式：新清单中能连上字典的组数，产出「n_grp_after」
    FROM        lim l                                                                               -- 取数来源：取自本条自建的中间结果集 lim
    CROSS JOIN  unnest(split(l.grp_after, ',')) AS g(grp)                                           -- 行展开：把逗号分隔的组清单逐组成行
    LEFT JOIN   dict d ON d.grp_id = TRIM(g.grp)                                                    -- 左连接：取自本条自建的中间结果集 dict，连接键为组号
    GROUP BY l.ev_key                                                                               -- 分组：按事件键汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-14）
bl AS (                                                                                             -- 公共表表达式：开启中间结果集 bl——本方案口径的百家乐投注会员名单（§TL-14）
    SELECT  DISTINCT CAST(bet05 AS STRING)                AS member_id                              -- 取值表达式：取用 bet05（会员号）去重，产出「member_id」
    FROM    ods_mariadb_2b.ods_a168_bet02                                                           -- 取数来源：取自注单明细表
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
      AND   CAST(bet02 AS STRING) = '101'                                                           -- 并列条件：限定百家乐产品大类，涉 bet02（游戏类别）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§TL-14）
SELECT  l.member_id,                                                                                -- 取列：起始取列子句，本行先取「member_id」
        l.action_date, l.action_time,                                                               -- 取值表达式：事件之日与时刻
        l.operator_id, l.operator_lv,                                                               -- 取值表达式：操作人与其层级——审计轨迹之「谁」
        l.grp_before, l.grp_after,                                                                  -- 取值表达式：新旧限额组清单原文，留档以备复核
        b.max_hi_before, f.max_hi_after,                                                            -- 取值表达式：新旧清单之最高上限——方向判定之两端
        b.n_grp_before, f.n_grp_after,                                                              -- 取值表达式：两侧能连上字典的组数——连不上者即字典外之组，须查
        CASE WHEN b.max_hi_before IS NULL OR f.max_hi_after IS NULL                                 -- 取值表达式：方向判定起算——任一端无从取上限即判不明
             THEN 'UNKNOWN_NO_DICT'                                                                 -- 续行：组号不在字典内，方向不明
             WHEN f.max_hi_after < b.max_hi_before THEN 'TIGHTEN'                                   -- 续行：上限调低即收紧——**限红处置**
             WHEN f.max_hi_after > b.max_hi_before THEN 'RELEASE'                                   -- 续行：上限调高即放宽
             ELSE 'FLAT' END                              AS direction,                             -- 续行：持平——清单变而上限未变，不入处置节，产出「direction」
        CASE WHEN COALESCE(b.zero_before,0) + COALESCE(f.zero_after,0) > 0                          -- 取值表达式：歧义标记起算——含「0,0」组者
             THEN 1 ELSE 0 END                            AS has_zero_group,                        -- 续行：产出「has_zero_group」——★ 为 1 者方向判定须人工复核，不得径入处置总体
        CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END  AS is_baccarat_member,                    -- 取值表达式：是否本方案口径的百家乐会员
        'v2026-08-11'                                     AS filter_rule_version                    -- 取值表达式：规则版本号——改判定规则须改版本并记入变更日志
FROM        lim l                                                                                   -- 取数来源：取自本条自建的中间结果集 lim
LEFT JOIN   bfr b  ON b.ev_key = l.ev_key                                                           -- 左连接：取自本条自建的中间结果集 bfr，连接键为事件键
LEFT JOIN   aft f  ON f.ev_key = l.ev_key                                                           -- 左连接：取自本条自建的中间结果集 aft，连接键为事件键
LEFT JOIN   bl     ON bl.member_id = l.member_id                                                    -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
ORDER BY l.member_id, l.action_time;                                                                -- 排序：按会员与时刻升序——逐人可读其限额调整史；导出必带排序

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
         r.bet03 AS shoe_id,                                                                        -- 靴号（B-01 斧正新增，供 shoe_len 求 max_round＝最大局号，非局数）
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
shoe_len AS (   /* ★ 命名警示：本 CTE 名为 shoe_len（靴长）系历史沿用，其所算 max_round = MAX(round_no) 为『该靴该桌观测到的最大局号』，非 COUNT(round_no) 之局数；二者仅在局号自1起连续无缺口时相等。选 MAX 为刻意设计：对中间缺口免疫，COUNT 会因清洗剔单而使分母缩水。★ B-01 斧正（2026-08-12）：定标基准逐靴现算，绝对局号不是固定靴位 */
  SELECT shoe_id, table_id, MAX(round_no) AS max_round
  FROM ord GROUP BY shoe_id, table_id
),
ordx AS (       /* 把该靴之 max_round（最大局号）带回逐注单行，供相对靴位判定 */
  SELECT o.*, s.max_round
  FROM ord o
  JOIN shoe_len s ON s.shoe_id = o.shoe_id AND s.table_id = o.table_id
),
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体（§B01）
  SELECT member_id, bet_date, round_key, MAX(table_id) AS table_id,                                 -- 取列：起始取列子句，本行先取「table_id」，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         MAX(bet_ip) AS bet_ip, MAX(round_no) AS round_no,                                          -- 取最大值表达式：取用 bet_ip（下注 IP），产出「round_no」
         MAX(round_no) * 1.0 / NULLIF(MAX(max_round),0) AS shoe_pos,                       -- 该局的相对靴位（B-01 斧正新增）
         SUM(stake_raw/fx)                     AS stake,                                            -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(COALESCE(vb_raw,stake_raw)/fx)    AS validbet,                                         -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
         SUM((payout_raw-stake_raw)/fx)        AS game_pnl,                                         -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(rebate_raw/fx)                    AS rebate,                                           -- 汇总表达式：取用 rebate（退水），产出「rebate」
         SUM(net_raw/fx)                       AS net_pnl,                                          -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1                       -- 条件分支：取最大值
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1                       -- 并列条件：限定 MAX(CASE WHEN TRIM(bet_side)等于 'Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END                AS is_self_hedge                                     -- 分支取值：产出「is_self_hedge」
  FROM ordx GROUP BY member_id, bet_date, round_key                                                  -- 取数来源：取自本条自建的中间结果集 ord
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
       'shoe_pos>=0.80'                               AS late_def,                                  -- 口径锁：definition_version = v2（旧版 CSV 缺此列即报错）
       SUM(CASE WHEN shoe_pos >= 0.80 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_share_d,  -- 靴末段占比（B-01 斧正：相对靴位 ≥0.80；原为 round_no>=50）
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
         r.bet03 AS shoe_id,                                                                        -- 靴号（B-01 斧正新增，供 shoe_len 求 max_round＝最大局号，非局数）
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
shoe_len AS (   /* ★ 命名警示：本 CTE 名为 shoe_len（靴长）系历史沿用，其所算 max_round = MAX(round_no) 为『该靴该桌观测到的最大局号』，非 COUNT(round_no) 之局数；二者仅在局号自1起连续无缺口时相等。选 MAX 为刻意设计：对中间缺口免疫，COUNT 会因清洗剔单而使分母缩水。★ B-01 斧正（2026-08-12）：定标基准逐靴现算，绝对局号不是固定靴位 */
  SELECT shoe_id, table_id, MAX(round_no) AS max_round
  FROM ord GROUP BY shoe_id, table_id
),
ordx AS (       /* 把该靴之 max_round（最大局号）带回逐注单行，供相对靴位判定 */
  SELECT o.*, s.max_round
  FROM ord o
  JOIN shoe_len s ON s.shoe_id = o.shoe_id AND s.table_id = o.table_id
),
rk AS (                                                                                             -- 公共表表达式：开启中间结果集 rk，其后各行为其定义体
  SELECT member_id, bet_date, round_key, MAX(table_id) AS table_id,                                 -- 取列：起始取列子句，本行先取「table_id」，涉 round_key（局键）、member_id（会员号）、bet_date（营业日）
         MAX(bet_ip) AS bet_ip, MAX(round_no) AS round_no,                                          -- 取最大值表达式：取用 bet_ip（下注 IP），产出「round_no」
         MAX(round_no) * 1.0 / NULLIF(MAX(max_round),0) AS shoe_pos,                       -- 该局的相对靴位（B-01 斧正新增）
         SUM(stake_raw/fx)                     AS stake,                                            -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         SUM(COALESCE(vb_raw,stake_raw)/fx)    AS validbet,                                         -- 汇总表达式：取用 validbet（有效投注（洗码量）），产出「validbet」
         SUM((payout_raw-stake_raw)/fx)        AS game_pnl,                                         -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「game_pnl」
         SUM(rebate_raw/fx)                    AS rebate,                                           -- 汇总表达式：取用 rebate（退水），产出「rebate」
         SUM(net_raw/fx)                       AS net_pnl,                                          -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
         /* DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1                       -- 条件分支：取最大值
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1                       -- 并列条件：限定 MAX(CASE WHEN TRIM(bet_side)等于 'Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END                AS is_self_hedge                                     -- 分支取值：产出「is_self_hedge」
  FROM ordx GROUP BY member_id, bet_date, round_key                                                  -- 取数来源：取自本条自建的中间结果集 ord
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
       'shoe_pos>=0.80'                               AS late_def,                                  -- 口径锁：definition_version = v2（旧版 CSV 缺此列即报错）
       SUM(CASE WHEN shoe_pos >= 0.80 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_share_d,  -- 靴末段占比（B-01 斧正：相对靴位 ≥0.80；原为 round_no>=50）
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
--   WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet09 = 'Banker'   （跑时自行补分号）
-- 该数应约为 4,682 万。若为 0，说明 bet09 有前后空格，把判别改成
--   UPPER(TRIM(bet_side)) = 'BANKER' / 'PLAYER'。


/* ───────────────────────────────────────────────────────────────────────────
   §99 · 大表切分导出模板（T02 / B01 / K01 用得上）
   ★ 绝对不要用 OFFSET 翻页 —— 277 批数据 36.49% 重复的根因就是分页无稳定排序。
   正确做法：按 bet05 的哈希或数值区间切成 N 份，每份独立跑、独立导。
   ─────────────────────────────────────────────────────────────────────────── */
-- ⚠★ 2026-08-11 补一条界：**本模板并非对每一段都安全**。
--   凡该段含**全局 CTE**（如 §R03／§R03b 的 side_base 各投注产品基准胜率）者，
--   在上游 CTE 切片会令每片各估一套基准——十片十个基准，其 Z 分数彼此不可比。
--   此类段落的切点**必须放在最外层**（对最终 SELECT 的键取模或用游标翻页），
--   代价是每片仍须全量计算一次。安全适用者：T02／B01／K01 等纯会员级聚合。
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
-- ORDER BY verdict, member_id     （跑时自行补分号）

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
         n_related_orders, n_rounds_eff, p_base_mix_w, z_score
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R03b_player_dealer_daily.csv」（§R03b 玩家×荷官·日粒度）。
-- ★★★ 2026-08-11 警示·本件在十万行上限下不可直接导出 ★★★
--   旧版实测 18,139,550 行 → 十万一批需 **182 次**下载，且每次须把整条链全算一遍，
--   工程上不可行。**导出之前须先定粒度**，三条可选（本方不擅代先生决，故并列于此）：
--     甲、加资格过滤（同 §R03 之四条谓词，另加日粒度下限如 n_rounds_eff >= 5）——
--         最省，惟日粒度本就稀疏，过滤后能否支撑时序对照须先以计数查验；
--     乙、缩窗口（如只取末 30 个营业日）——行数约降至五分之一，惟时序对照随之缩短；
--     丙、按营业日切片逐日导（139 片）——片数虽多而每片小，且 dt 是分区键，
--         切片可下推至扫描层，**每片只扫该日数据**，故总代价不翻倍（与 §R03 之情形不同）。
--   ★ 本方倾向丙：其为唯一「切片不翻倍」者，因 dt 恰是 StarRocks 的分区键。
--     惟须注意：side_base（各产品基准）若随片重算，则各片基准不同、z 分数不可比——
--     **故按日切片时，切点须置于最外层 WHERE，不得下推至 ranked**。
-- ★★ 2026-08-11 斧正·排序键与分页（与 §R03 同治）★★
--   本件为全包**行数之最**（旧版实测 1,814 万行），最须分批下载，故此病在此处最烈。
--   ① 旧版 `ORDER BY p.bet_date, z_score DESC` **排序键不唯一**——同日内 z_score
--      大量并列，OFFSET 翻页必致重复或漏行（与当年 36.49% 重复率同一病根）。
--   ② 今改 `ORDER BY p.bet_date, p.member_id, p.dealer_id`——三键即本件之主键，
--      天然唯一（pd 层即按此三键分组），可作游标键。
--   ③ 分批一律**游标翻页，禁用 OFFSET**：
--        第 1 批：末尾加  LIMIT 100000
--        第 k+1 批：取上批末行三键 (T, M, D)，在 ORDER BY 之前加
--          WHERE (p.bet_date, CAST(p.member_id AS BIGINT), CAST(p.dealer_id AS BIGINT))
--                > (T, M, D)
--        引擎若不支持行值比较，改写为三段 OR 的等价式（见 §R03 段末模板）。
--   ④ 亦**不得**照 §99 在上游 CTE 取模切片——本段同样有全局 CTE `side_base`，
--      上游切片会令每片自成基准，各片 z 分数不可比。切点只能在最外层。
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
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,               -- 取值表达式：哨兵标记——★ 由删除改为标注（事实层不删，分析层才筛）
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
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, bet_side, round_key,                   -- 取列：起始取列子句，透传哨兵标记，涉 bet_date（营业日）、round_key（局键）
         stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (payout_raw - stake_raw) / fx AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         net_raw / fx                  AS net_pnl                                                   -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
  FROM base                                                                                         -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
side_base AS (                                                                                      -- 公共表表达式：开启中间结果集 side_base，其后各行为其定义体（§R03b）
  SELECT bet_side,                                                                                  -- 取列：起始取列子句，本行先列 bet_side
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base                    -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「p_base」
  FROM ord WHERE is_sentinel_dealer = 0                                                             -- 取数来源：取自本条自建的中间结果集 ord——★ 基准只由**真实牌桌**估计
  GROUP BY bet_side                                                                                 -- 分组：按投注产品汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
ordb AS (             -- ★ 2026-08-11 增：注单层挂上各自产品的基准，供下方按注额加权
  SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet_date, o.round_key, o.bet_side,       -- 取列：起始取列子句，透传五键与哨兵标记
         o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side                                         -- 续行：并取三项金额与该注自身产品的基准胜率，产出「p_side」
  FROM      ord o                                                                                   -- 取数来源：取自本条自建的中间结果集 ord
  LEFT JOIN side_base s ON s.bet_side = o.bet_side                                                  -- 左连接：取自本条自建的中间结果集 side_base，基准未定义者留空——不以 0.5 顶替
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
pr AS (   -- 局级去重：同一物理局折成一局，避免 Z-score 被 sqrt(k) 放大
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, round_key,                             -- 取列：起始取列子句，透传哨兵标记
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,                   -- 汇总表达式：取用 stake（下注额（经汇率归一化））、net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「net_pnl」
         COUNT(*) AS n_orders_in_round,                                                             -- 计数表达式：产出「n_orders_in_round」
         SUM(stake * p_side)                                                                        -- 汇总表达式：注额加权基准起算——★ 斧正，旧法 MAX(bet_side) 取字母序最大而非主注
           / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)                     -- 除法或乘法计算：除以有基准之注的注额合计
                       AS p_base_round_w,                                                             -- 续行：产出「p_base_round_w」——该局的**注额加权**基准；全注皆无基准则留空
         AVG(p_side)   AS p_base_round_unw,                                                         -- 汇总表达式：同局各注基准的**等权**均值——★ 2026-08-11 增，供两种 estimand 对照
         MAX(bet_side) AS main_side                                                                 -- 取最大值表达式：字母序最大注项，**仅备查、不参与计算**
  FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet_date, round_key                  -- 取数来源：取自本条自建的中间结果集 ordb（已挂基准）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03b）
SELECT p.bet_date, p.member_id AS uid, p.dealer_id, p.is_sentinel_dealer,                           -- 取列：起始取列子句，本行先取「uid」与哨兵标记
       SUM(p.stake)                                        AS stake_amount,                         -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_amount」
       SUM(p.game_pnl)                                     AS profit_amount,                        -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「profit_amount」
       SUM(p.net_pnl)                                      AS net_pnl,                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
       SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
         / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,                 -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「win_rate」
       SUM(p.n_orders_in_round)                            AS n_related_orders,                     -- 汇总表达式：产出「n_related_orders」
       COUNT(*)                                            AS n_rounds_eff,                         -- 计数表达式：取用 n_rounds_eff（有效局数），产出「n_rounds_eff」
       AVG(p.p_base_round_w)                                 AS p_base_mix_w,                           -- 汇总表达式：对各局的**注额加权**基准取均值——判定所用者
       AVG(p.p_base_round_unw)                             AS p_base_mix_unw,                       -- 汇总表达式：**等权**口径之对照量——★ 2026-08-11 与 §R03 对齐，二者背离即示资金集中于某产品
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 续行：汇总，取用 game_pnl（游戏净输赢）
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))           -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR）
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢）
                       * AVG(p.p_base_round_w)                                                -- 除法或乘法计算：求均值
                       * (1 - AVG(p.p_base_round_w))), 0)        AS z_score_w,                      -- 除法或乘法计算：产出「z_score_w」——**加权候选臂**
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 取值表达式：★ **对照臂**之分子——同式改用等权基准（Dixon & Coles 1996：先立无权重基线）
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_unw))               -- 续行：期望胜局按等权基准算
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：除以伯努利标准差
                       * AVG(p.p_base_round_unw)                                                    -- 续行：等权基准
                       * (1 - AVG(p.p_base_round_unw))), 0)    AS z_score_unw,                      -- 续行：产出「z_score_unw」——加权之优势须由本臂对照证成
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 取值表达式：兼容别名之分子——与 z_score_w 逐字同式
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))                 -- 续行：期望胜局按加权基准算
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：除以伯努利标准差
                       * AVG(p.p_base_round_w)                                                      -- 续行：加权基准
                       * (1 - AVG(p.p_base_round_w))), 0)        AS z_score,                        -- 续行：产出「z_score」——★ **兼容别名，恒等于 z_score_w**；既有报告与数据契约沿用此名
       AVG(p.p_base_round_w) - AVG(p.p_base_round_unw)          AS delta_p,                         -- 加减计算：比较层——两臂基准之差，产出「delta_p」
       CASE WHEN p.is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'                                    -- 取值表达式：统计资格判定起算——事实层不删，此处只标注资格
            WHEN AVG(p.p_base_round_w) IS NULL THEN 'NO_BASE_RATE'                                    -- 续行：基准未定义
            WHEN SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_DECISIVE_ROUND'      -- 续行：全为退还局，无胜负可判
            ELSE 'ELIGIBLE' END                                 AS eligibility_status,               -- 续行：产出「eligibility_status」——日粒度不设局数下限，下限由分析层施加
       'R03b_20260811_FULL_v1'                              AS comparison_id,                       -- 取值表达式：比较批次号——与 §R03 同规格，两臂须同批次方可比
       'L1_ELIGIBILITY'                           AS filter_stage,                                  -- 取值表达式：过滤所处之层——★ L0 事实层不删行，此处只标注其在 L1 资格层的去留
       'v2026-08-11'                              AS filter_rule_version,                            -- 取值表达式：资格规则版本号——改规则须改版本号并记入变更日志，免「同名不同义」
       '2026-03-21..2026-08-06'                             AS cmp_time_window,                     -- 取值表达式：时间窗，产出「cmp_time_window」
       'baccarat_bet02_101_all_pairs_incl_sentinel'         AS cmp_population,                      -- 取值表达式：总体定义（含哨兵之全量对）
       'round_win = game_pnl > 0 (decisive only)'           AS cmp_label,                           -- 取值表达式：标签定义
       'COMPATIBILITY_ONLY_NOT_PRODUCTION'                  AS z_score_alias_status                 -- 取值表达式：★ 兼容别名状态——禁止作生产输入
FROM pr p                                                                                           -- 取数来源：取自本条自建的中间结果集 pr
-- （已废）旧版在此按 main_side 连 side_base 取基准，2026-08-11 改注单层注额加权                                          -- 注：连接已移至 ordb，本处不再取基准
GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer                                 -- 分组：按营业日×会员×荷官×哨兵标记汇总
ORDER BY p.bet_date, p.member_id, p.dealer_id;                                                      -- 排序：★ 2026-08-11 改——按**唯一键**（日×会员×荷官）升序；分页铁律①：排序键须唯一
/* ★★ 分页（2026-08-11 立，与 §R03 同一纪律）★★
   旧版 ORDER BY p.bet_date, z_score DESC 之次级键 z_score **不唯一**，
   分批下载会重、会漏。今改 (bet_date, member_id, dealer_id) —— 三者合成唯一。
   游标翻页：取上批末行 (BD, M, D)，加
       WHERE (p.bet_date, CAST(p.member_id AS BIGINT), CAST(p.dealer_id AS BIGINT)) > (BD, M, D)
   ⚠ 切点同须在**最外层**：本段亦有全局 CTE side_base，上游切片会令基准失真。
   ⚠ 本段为日粒度，行数远大于 §R03（旧版即 1,814 万行），分批数须按实际先跑 COUNT 预检。
   ═══════════════════════════════════════════════════════════════════════════ */                                                                  -- 排序：按 p.bet_date, z_score（降序）排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
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
   并把缺口摆明。
   ★ 2026-08-14 两处增补（皆为 S1 斧正，详见列内注释）：
     ① 增列 `理由空白数`——「理由空白率」之真口径分子，根治报表侧代理口径之名实不符；
     ② 增补 `WHERE addtime < '2026-08-07'`——杜绝未来信息（实测已见一条 2026-08-09）。
   ★ 本条现产出六列：entity_id / 标注产量 / 覆盖IP广度 / 判定详尽度 / 理由空白数 /
     首次登记 / 最近登记。报表侧另就地派生三维：
     登记跨度 = 最近登记 − 首次登记（小数日）；
     标注停滞度 = (全体最近登记日 − 该员最近登记日) ÷ 登记跨度，截断 [0,1]；
     理由空白率 = 理由空白数 ÷ 标注产量。
   ★ 使用限制（须随交付件一并交付）：样本仅六人量级，分位归一只有六档，
     综合分是序号而非连续量；且登记时间多在 2022 年，与本方案 139 天窗口无重叠。
     在「风控处置日志」建成之前，本实体雷达只宜作结构演示，不宜进入绩效场合。
   导出：「数据库/S04_analyst_score.csv」
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/S04_analyst_score.csv」（§S04p 风控专员最小画像·正版）。
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  COALESCE(NULLIF(TRIM(creator), ''), '未署名')      AS entity_id,                                     -- 取值表达式：产出「entity_id」
  -- ★ 下面三个列名与报告的风控专员雷达字典严格对应，一字不可改
  COUNT(*)                                            AS 标注产量,                                      -- 计数表达式：产出「标注产量」
  COUNT(DISTINCT TRIM(ip))                            AS 覆盖IP广度,                                    -- 计数表达式：统计去重个数，产出「覆盖IP广度」
  AVG(LENGTH(COALESCE(remarks, '')))                  AS 判定详尽度,                                     -- 求均值表达式：产出「判定详尽度」
  -- ★ 2026-08-14 增列（S1 斧正 · 同名异义之根治）：
  --   「理由空白率」此前在报表侧以代理口径推算（1 − 判定详尽度 ÷ 全体中位详尽度），
  --   该式量的是**理由字数的相对长短**，而非**有没有写理由**——
  --   一名写五百字套话者判为 0，一名写二十字要害者判近 1，名实不符。
  --   今补出真口径之分子。表达式逐字取自 §S-04b（本包第 2,229 行），同表同源，
  --   不新增扫描、不新增连接。报表侧「理由空白率 = 理由空白数 ÷ 标注产量」。
  SUM(CASE WHEN NULLIF(TRIM(remarks),'') IS NULL
           THEN 1 ELSE 0 END)                         AS 理由空白数,                                     -- 汇总表达式：产出「理由空白数」（理由空白率之分子）
  MIN(addtime)                                        AS 首次登记,                                      -- 取最小值表达式：产出「首次登记」
  MAX(addtime)                                        AS 最近登记                                       -- 取最大值表达式：产出「最近登记」
FROM ods_mariadb_2b.ods_a168_alert_ip_setting                                                       -- 取数来源：取自风控 IP 名单配置表（人工标记史料源）
-- ★ 2026-08-14 增补窗口上界（S1 斧正 · 时间一致性）：
--   实测查出 creator = livegame 之最近登记为 2026-08-09 20:48:43，
--   晚于本方案分析窗口截止日 2026-08-07——属未来信息。
--   凡该维参与与窗内结果之对照判定者，未加此界即构成时间一致性违规。
--   注：alert_ip_setting 为配置类表、无 dt 分区列（见 §EX-00 判据），
--   故此处以 addtime 施界，不写 dt。
WHERE addtime < '2026-08-07'                                                                        -- 过滤条件：限定 addtime 小于窗口截止日，杜绝未来信息
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
    AND TRIM(r.eid) NOT IN ('-1', '0')                                                              -- 并列条件：剔除哨兵荷官号——-1／0 非真实荷官，入检即污染榜单与多重比较总体（2026-08-11 增）
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
-- WHERE dt >= '2026-08-04' AND dt < '2026-08-07'   （跑时自行补分号）

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

/* ═══════════════════════════════════════════════════════════════════════════
   §P0C · L1a 标签时序审计与 125／251 口径结案（2026-08-10 立）
   ---------------------------------------------------------------------------
   缘起：`dailyreport_member.risk` 一直被当作监督学习的正例标签使用。
   但该字段记的是「风控专员当日是否标了这一笔」，若专员系见当日异常而后标记，
   则以当日特征预测当日 risk 即属**同日泄漏**——模型学到的是
   「何种行为招致打标」，而非「何种行为预示未来风险」。此二者判然有别。

   本节六条查明三事：① risk 的取值与业务日口径；② 125 与 251 两数各属何口径；
   ③ 标记究竟是前瞻性判断还是事后追认。据此把该字段正名为三层：
     · 标签甲 处置标签   —— 当日专员是否标记，供风控人员行为分析与流程稽核；
     · 标签乙 确认结果   —— 未来 7／14／30 日内是否经复核确认，方可供预测建模；
     · 标签丙 经济结果   —— 处置后的增量净收，须待处置日志到位方能构造。

   ─── 结构探查已定的五处标识符（§P0C-00 实测，2026-08-10）───────────────
     会员列：两表同为 `bet05`（會員編號）
     分区列：两表同为 `dt`，类型 **DATE**，故一律不作 CAST
     产品列：两表同为 `bet02`（遊戲編號／遊戲類別編號），百家乐取 '101'
     风险列：`dailyreport_member.risk`，varchar 承载 tinyint(1)，1 表示風險單
     业务日：`dailyreport_member.time`（source_type=date），与 dt 是否同日见 §P0C-01
   ⚠ **`bet41` 两表异义，跨表取洗码量必复核**：
       `dailyreport_member.bet41` = 有效投注（即洗码量）；
       `bet02.bet41`              = 下注退水金額。   ← ⛔ 原文，2026-08-18 实测证伪，见下
       故 `bet02` 侧洗码量一律取 **`validbet`**，误用 bet41 会把退水当流水。 ← ⛔ 原文，同上

   ═══ 2026-08-18 斧正（原文一字不删，仅加挂裁定）═══════════════════════
     ⛔ 上述两行**已被实测证伪**，标记 `ODS_DICTIONARY_DEFECT`：
        缺陷不在本包，在 ODS 层字典本身——`ods_a168_bet02.bet41` 之原始中文注释
        写作「下注退水金額」，与数据实况不符；ODS 字典本身即审计对象，故原文保留。
     ✅ 实测正名（Probe-01，两条独立证据）：
        · P01D：`bet41 / validbet` 之 p01＝p50＝p90＝p99 ＝ **1.000000**
                （n＝116,103,500，窗口内百家乐）→ **`bet02.bet41` ≡ `validbet`**
        · P01E：恒等式 `bet17 = bet14 − bet13 + bet16` 于 **125,654,711 / 125,654,711**
                行**精确成立（100.00000%，误差 max ＝ 0）**；
                同式换 `bet41` 仅 7.602% 匹配、误差 P99 ＝ 20,000、max ＝ 1e8。
     🔒 由是锁定（今后不得再互换）：
        `bet02.bet41` = 有效投注／洗码量（≡ validbet）
        `bet02.bet16` = 退水金额
        `rebate_rate` = bet16 ÷ bet41
        ⚠ `bet41 ≠ 退水金额`；`bet16 ≠ 洗码量`
     📌 `bet16` 非零率实测 4–5%（逐月 3.85%→5.38%），**非数据错误、非字段错配**，
        系享退水注单本就少数；此前据 `bet16` 所得之 T-08／NGR／契约档位诸结论
        **不受影响，无须重算**。

   ─── 本节两条执行纪律（皆由实测报错反推所立）─────────────────────────
     ⑨ **末分号之后不得再写任何注释**——Superset 会将其判为第二条空语句，
        整条查询报 Unable to parse SQL（§P0C-05 原稿实测触发）。
     ⑩ **注释内不得出现美元符或反斜杠**——含 LaTeX 数学式的注释会令前端
        解析器中断（§P0C-03 原稿实测触发）。
   ═══════════════════════════════════════════════════════════════════════════ */

-- §P0C-00 · 结构探查（已执行，保留备查）
-- ▸ 导出：不需要 —— §P0C-00 结构探查，屏幕看结果，结论已录于上方块注释。
SELECT  TABLE_NAME,
        ORDINAL_POSITION,
        COLUMN_NAME,
        DATA_TYPE,
        COLUMN_COMMENT
FROM    information_schema.columns
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'
  AND   TABLE_NAME IN ('ods_a168_dailyreport_member', 'ods_a168_bet02')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- §P0C-01 · risk 取值分布，兼查分区日 dt 与业务日 time 是否同日
-- ▸ 导出：不需要 —— §P0C-01 取值与轴向探针，屏幕看结果。
-- 读法：① risk 若只见 0 与 1 两值，则 §P0C-02 起以 '1' 为正例即无遗漏；
--       ② dt 与 time 若大面积不等，则本节及全包一切以 dt 为时间轴的
--          时序判断均须改以 time 为轴，届时须整节重写，不可只改此一条。
SELECT  CAST(risk AS STRING)                                     AS risk_取值,
        COUNT(*)                                                 AS 行数,
        COUNT(DISTINCT CAST(bet05 AS STRING))                    AS 会员数,
        SUM(CASE WHEN dt =  CAST(time AS DATE) THEN 1 ELSE 0 END) AS dt等于time_行数,
        SUM(CASE WHEN dt <> CAST(time AS DATE) THEN 1 ELSE 0 END) AS dt不等time_行数
FROM    ods_mariadb_2b.ods_a168_dailyreport_member
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
GROUP BY 1
ORDER BY 行数 DESC;

-- §P0C-02 · 125 与 251 口径结案（百家乐／非百家乐／全产品三行并陈）
-- ▸ 导出：需要 —— 存为「数据库/P0C02_标签口径.csv」（§P0C-02 标签口径三行对照）。
-- 读法：假说甲——125 为去重会员数、251 为会员-日观测数，二者口径不同而非矛盾；
--       假说乙——其一为全产品口径、其一为百家乐口径。三行一出即可定夺。
--       定夺后须在两份报告中分别正名，不得再以「125 个正样本」一语混指两者。
SELECT  '百家乐(101)'                                 AS 产品口径,
        COUNT(*)                                      AS 正例观测数_会员日,
        COUNT(DISTINCT CAST(bet05 AS STRING))         AS 正例会员数_去重,
        COUNT(DISTINCT dt)                            AS 覆盖日数,
        MIN(dt)                                       AS 首个正例日,
        MAX(dt)                                       AS 末个正例日
FROM    ods_mariadb_2b.ods_a168_dailyreport_member
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
  AND   CAST(risk AS STRING) = '1'
  AND   CAST(bet02 AS STRING) = '101'
UNION ALL
SELECT  '非百家乐',
        COUNT(*),
        COUNT(DISTINCT CAST(bet05 AS STRING)),
        COUNT(DISTINCT dt),
        MIN(dt),
        MAX(dt)
FROM    ods_mariadb_2b.ods_a168_dailyreport_member
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
  AND   CAST(risk AS STRING) = '1'
  AND   CAST(bet02 AS STRING) <> '101'
UNION ALL
SELECT  '全产品合计',
        COUNT(*),
        COUNT(DISTINCT CAST(bet05 AS STRING)),
        COUNT(DISTINCT dt),
        MIN(dt),
        MAX(dt)
FROM    ods_mariadb_2b.ods_a168_dailyreport_member
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
  AND   CAST(risk AS STRING) = '1';

-- §P0C-03 · 每会员标记次数分布
-- ▸ 导出：需要 —— 存为「数据库/P0C03_标记次数分布.csv」（§P0C-03 标记次数分布）。
-- 读法：若绝大多数会员仅被标记一次，则标记为一次性事件而非持续状态，
--       标签乙的构造须以**首次标记日**为锚，不可逐日重复计数。
SELECT  标记次数,
        COUNT(*)                                      AS 会员数,
        SUM(COUNT(*)) OVER (ORDER BY 标记次数)         AS 累计会员数
FROM (
    SELECT  CAST(bet05 AS STRING)                     AS mem,
            COUNT(DISTINCT dt)                        AS 标记次数
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(risk AS STRING) = '1'
      AND   CAST(bet02 AS STRING) = '101'
    GROUP BY 1
) t
GROUP BY 标记次数
ORDER BY 标记次数;

-- §P0C-04 · 同日泄漏检验（本节核心）
-- ▸ 导出：需要 —— 存为「数据库/P0C04_同日泄漏检验.csv」（§P0C-04 同日泄漏检验）。
-- 读法：标记日活动量若显著高于其前 30 日的日均，即专员系见当日异常而后标记；
--       此时以当日特征预测当日 risk 属同日泄漏。
-- ★ 分析纪律（2026-08-10 复验所立）：本条产出**不可用符号检验判读**——
--   符号检验丢弃幅度、检验力不足，曾据此误判为「未证实」。
--   须先分三层（可比较 / 标记日零投注 / 前 30 日无活跃），
--   再对可比较层的**对数比**作 Wilcoxon 符号秩，并配自助区间；
--   分母偏误另由 §P0C-09 的安慰剂对照排除。
--       洗码量取 `validbet`；`bet02.bet41` 实测 ≡ validbet（2026-08-18 P01D 正名，原注释「退水金额」已证伪）。
WITH d0 AS (
    SELECT  CAST(bet05 AS STRING)                     AS mem,
            MIN(dt)                                   AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(risk AS STRING) = '1'
      AND   CAST(bet02 AS STRING) = '101'
    GROUP BY 1
),
act AS (
    SELECT  CAST(b.bet05 AS STRING)                   AS mem,
            b.dt                                      AS d,
            COUNT(*)                                  AS 注单数,
            SUM(CAST(b.validbet AS DOUBLE))           AS 洗码量
    FROM    ods_mariadb_2b.ods_a168_bet02 b
    JOIN    d0 ON d0.mem = CAST(b.bet05 AS STRING)
    WHERE   b.dt >= '2026-03-21'
      AND   b.dt <  '2026-08-07'
      AND   CAST(b.bet02 AS STRING) = '101'
    GROUP BY 1, 2
)
SELECT  d0.mem,
        d0.mark_day,
        MAX(CASE WHEN act.d =  d0.mark_day THEN act.注单数 ELSE 0 END) AS 标记日_注单数,
        MAX(CASE WHEN act.d =  d0.mark_day THEN act.洗码量 ELSE 0 END) AS 标记日_洗码量,
        AVG(CASE WHEN act.d <  d0.mark_day THEN act.注单数 END)        AS 前30日均_注单数,
        AVG(CASE WHEN act.d <  d0.mark_day THEN act.洗码量 END)        AS 前30日均_洗码量,
        COUNT(DISTINCT CASE WHEN act.d < d0.mark_day THEN act.d END)   AS 前30日活跃日数
FROM        d0
LEFT JOIN   act
       ON   act.mem = d0.mem
      AND   act.d  >= DATE_SUB(d0.mark_day, INTERVAL 30 DAY)
      AND   act.d  <= d0.mark_day
GROUP BY d0.mem, d0.mark_day
ORDER BY 标记日_洗码量 DESC;

-- §P0C-05 · 标记时点相对会员投注生命期的定位
-- ▸ 导出：需要 —— 存为「数据库/P0C05_标记时点定位.csv」（§P0C-05 标记时点定位）。
-- 读法：标记日若普遍落在活跃期末端，说明多属事后追认，该字段不具前瞻性。
SELECT  d0.mem,
        d0.mark_day,
        life.首投日,
        life.末投日,
        life.活跃日数,
        DATEDIFF(d0.mark_day, life.首投日)             AS 标记距首投_日,
        DATEDIFF(life.末投日, d0.mark_day)             AS 末投距标记_日,
        CASE WHEN DATEDIFF(life.末投日, d0.mark_day) <= 0  THEN '标记后再无投注'
             WHEN DATEDIFF(life.末投日, d0.mark_day) <= 14 THEN '标记后14日内停投'
             ELSE '标记后仍持续投注' END               AS 时点性质
FROM (
    SELECT  CAST(bet05 AS STRING)                     AS mem,
            MIN(dt)                                   AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(risk AS STRING) = '1'
      AND   CAST(bet02 AS STRING) = '101'
    GROUP BY 1
) d0
LEFT JOIN (
    SELECT  CAST(bet05 AS STRING)                     AS mem,
            MIN(dt)                                   AS 首投日,
            MAX(dt)                                   AS 末投日,
            COUNT(DISTINCT dt)                        AS 活跃日数
    FROM    ods_mariadb_2b.ods_a168_bet02
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(bet02 AS STRING) = '101'
    GROUP BY 1
) life ON life.mem = d0.mem
ORDER BY 标记距首投_日;

-- §P0C-06 · 标签乙骨架：特征窗为锚点前 30 日，结果窗为锚点后 1 至 14 日
-- ▸ 导出：需要 —— 存为「数据库/P0C06_LabelB骨架.csv」（§P0C-06 标签乙骨架·正例侧）。
-- 前置：仅当 §P0C-04 与 §P0C-05 判定标记具前瞻性时，本表方可供建模；
--       若判为事后追认，本表只作风控人员行为分析之用。
-- 体量：锚点已限于正例会员，负例由特征侧 §B01 全量左连补齐，本条不作笛卡尔展开。
WITH mk AS (
    SELECT  DISTINCT CAST(bet05 AS STRING)            AS mem,
            dt                                        AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(risk AS STRING) = '1'
      AND   CAST(bet02 AS STRING) = '101'
),
anchor AS (
    SELECT  CAST(b.bet05 AS STRING)                   AS mem,
            b.dt                                      AS anchor_day
    FROM    ods_mariadb_2b.ods_a168_bet02 b
    JOIN    (SELECT DISTINCT mem FROM mk) pos ON pos.mem = CAST(b.bet05 AS STRING)
    WHERE   b.dt >= '2026-04-20'
      AND   b.dt <  '2026-07-24'
      AND   CAST(b.bet02 AS STRING) = '101'
    GROUP BY 1, 2
)
SELECT  a.mem,
        a.anchor_day,
        DATE_SUB(a.anchor_day, INTERVAL 30 DAY)       AS 特征窗起,
        a.anchor_day                                  AS 特征窗止,
        DATE_ADD(a.anchor_day, INTERVAL 1  DAY)       AS 结果窗起,
        DATE_ADD(a.anchor_day, INTERVAL 14 DAY)       AS 结果窗止,
        MAX(CASE WHEN mk.mark_day >  a.anchor_day
                  AND mk.mark_day <= DATE_ADD(a.anchor_day, INTERVAL 14 DAY)
                 THEN 1 ELSE 0 END)                   AS label_b_未来14日被标记,
        MAX(CASE WHEN mk.mark_day =  a.anchor_day
                 THEN 1 ELSE 0 END)                   AS label_a_当日被标记
FROM        anchor a
LEFT JOIN   mk ON mk.mem = a.mem
GROUP BY a.mem, a.anchor_day
ORDER BY a.mem, a.anchor_day;

-- §P0C-07 · 会员-月粒度计数（坐实 251 之口径）
-- ▸ 导出：不需要 —— §P0C-07 粒度对照，屏幕看结果。
-- 读法：若「正例会员-月」得 251，则 125／251／1,344 三数确为同一批人在
--       会员、会员-月、会员-日三种粒度下的计数，粒度对照即告闭合。
SELECT  COUNT(DISTINCT CONCAT(CAST(bet05 AS STRING), '|',
                              DATE_FORMAT(dt, '%Y-%m')))  AS 正例会员月数,
        COUNT(DISTINCT CAST(bet05 AS STRING))             AS 正例会员数,
        COUNT(*)                                          AS 正例会员日数
FROM    ods_mariadb_2b.ods_a168_dailyreport_member
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
  AND   CAST(risk AS STRING) = '1'
  AND   CAST(bet02 AS STRING) = '101';

/* ═══════════════════════════════════════════════════════════════════════════
   §P0C-08 · 标签时序之案结案记录（2026-08-10）—— 本节不含查询，只作定案存照
   ---------------------------------------------------------------------------
   §P0C-01 至 §P0C-06 六条已跑毕，六条定论如下。谨记其始末，以免重启同一路径。

   ─── 一、粒度对照：三数同源 ────────────────────────────────────────────
     125 名去重会员 ＝ 约 252 个会员-月观测 ＝ 1,344 个会员-日观测。
     此后引用一律标明粒度，不得再以「125 个正样本」混指三者。
     ⚠ **未闭合其一**：§P0C-07 直接计数得会员-月 **252**，而 S05 面板所载正例为 **251**，
       相差其一。可能系 S05 的窗口端点、产品筛选或正例定义与本条不同。
       所待：S05 面板的构造 SQL 与其正例定义。在厘清之前，
       **对外一律引用会员粒度的 125**，会员-月标注「约 252（与 S05 之 251 差一，待厘清）」。

   ─── 二、risk 只存在于百家乐 ───────────────────────────────────────────
     §P0C-02 实测：百家乐 1,344 行 / 125 人；**非百家乐 0 行 / 0 人**。
     故此前所疑「两数分歧源于产品口径」**证伪**——产品口径不构成任何差异。

   ─── 三、同日标签泄漏：**证据成立**（2026-08-10 复验后改判）──────────────
     ★ 本条曾判「未证实」，经复验推翻，两处错因记明以免重蹈：
       其一，原用**符号检验**——只看方向、丢弃幅度，检验力不足；
       其二，把 **20 名标记日零投注者**混入分母——其比值恒为 0，压低符号计数，
             而该 20 人本属另一层，不应与可比较者同池。
     改以计幅度之法、并先分层，得：
       【层一 · 可比较者 n = 101】（标记日有投注且前 30 日有活跃）
         注单数比 中位 **1.78**，自助 95% 区间 [1.45, 1.98]，
                 Wilcoxon 符号秩 z = 2.768、双尾 **p = 0.0056**；
         洗码量比 中位 **1.79**，自助 95% 区间 [1.33, 2.03]，
                 Wilcoxon 符号秩 z = 2.402、双尾 **p = 0.0163**；
         两项经 Bonferroni 校正（α' = 0.025）**俱显著**，区间皆不含 1。
       【层二 · 标记日零投注者 n = 20（16.0%）】其标记**不可能**由当日投注触发，
         另有来源（累积证据、名单比对、外部举报等），标签由此呈**异质**。
       【层三 · 前 30 日无活跃者 n = 4】不可比较。
     ─── 三之二、安慰剂已坐实（§P0C-09 跑毕，2026-08-10）────────────────
       经验零假设（同批会员的**非标记活跃日**按同式计比）：
         注单数比 中位 **0.70**（自助 95% 区间 [0.67, 0.73]）；
         洗码量比 中位 **0.53**（区间 [0.50, 0.56]）。
       皆显著低于 1，与「投注日额右偏、单日对均值之比的中位本在 1 以下」之推断吻合；
       与标记日（1.78 / 1.79）两组区间**毫无交叠**。
       改以**人内配对**（各人以其自身安慰剂中位为基准）重估：
         注单数 倍数中位 **2.37**（区间 [1.53, 2.91]），Wilcoxon z=4.066、p=4.8e-05，正向 72/100；
         洗码量 倍数中位 **2.51**（区间 [2.00, 3.24]），Wilcoxon z=4.351、p=1.4e-05，正向 73/100。
       两项经 Bonferroni 后仍显著、区间皆不含 1。**同日泄漏坐实**，
       且真实效应**大于**以 1 为零假设所得之初估——naive 比法系统性低估了效应。
     【操作结论】`X_t → risk_t` 一律**不得**用于宣称预测能力——
       模型学到的至少有一部分是「何种行为招致打标」。须改走标签乙（§P0C-06）。

   ─── 四、标记不是事后追认，是早期标记 ──────────────────────────────────
     距首投中位 **11 日**，落生命期 **25.4%** 处（四分位 3.0%–66.9%）；
     标记后 **72.8%** 仍持续投注、中位再投 **65 日**，仅 **7.2%** 再无投注。
     故具备前瞻性使用的时间结构，「只能作处置标签」之强判不成立。

   ─── 五、标记是持续状态，不是一次性事件 ────────────────────────────────
     仅 41/125（32.8%）只被标一次，中位 **3 次**，最多一人 **66 次**。
     故标签乙锚点**不可只取首次标记日**，须逐锚点滚动判定——§P0C-06 即按此构造。
     ★ 本条更正 §P0C-03 原读法中「须以首次标记日为锚」一语。

   ─── 六、监督建模的真障碍：特征稀薄与基率极低，非泄漏 ──────────────────
     标记日前 30 日活跃日数**中位仅 4 日**（四分位 2–11，4 人为 0）；
     正例会员基率 **125 / 721,190 ＝ 0.0173%**；
     §P0C-06 骨架 3,833 锚点-日中，「当日未标、未来 14 日内被标」者 **1,338 个**，
     覆盖 **95 名**会员——此即标签乙实际可用的全部正样本。
     定案：该字段**可作标签乙之锚**，但**不以其训练判别模型**，
     改作规则时间稳定性的一票否决检验（见主方案 @sec-label-p0c）。
   ═══════════════════════════════════════════════════════════════════════════ */

-- §P0C-09 · 同日泄漏的安慰剂检验（分母偏误排除）
-- ▸ 导出：需要 —— 存为「数据库/P0C09_安慰剂检验.csv」（§P0C-09 非标记日的同比对照）。
-- 立此条之由：§P0C-04 以「标记日 ÷ 前 30 日活跃日均值」为比，其零假设的中位比
--   未必为 1——投注日额右偏，任一单日与其均值之比，中位本就应低于 1。
--   偏度方向意味着该偏误压低而非抬高比值，故 §P0C-04 所测的 1.78 倍方向稳健；
--   但方向稳健不等于幅度可信，须以安慰剂坐实。
-- 做法：对同一批正例会员，取其**每一个非标记的活跃日**，按同式计比，
--   所得中位即为该比的经验零假设值。判读：
--     · 安慰剂中位显著低于 1.78 → §P0C-04 的效应为真，同日泄漏成立；
--     · 安慰剂中位亦近 1.78     → 该效应系分母构造所致，§P0C-04 之判须撤回。
WITH mk AS (
    SELECT  DISTINCT CAST(bet05 AS STRING)            AS mem,
            dt                                        AS mark_day
    FROM    ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(risk AS STRING) = '1'
      AND   CAST(bet02 AS STRING) = '101'
),
act AS (
    SELECT  CAST(b.bet05 AS STRING)                   AS mem,
            b.dt                                      AS d,
            COUNT(*)                                  AS 注单数,
            SUM(CAST(b.validbet AS DOUBLE))           AS 洗码量
    FROM    ods_mariadb_2b.ods_a168_bet02 b
    JOIN    (SELECT DISTINCT mem FROM mk) pos ON pos.mem = CAST(b.bet05 AS STRING)
    WHERE   b.dt >= '2026-03-21'
      AND   b.dt <  '2026-08-07'
      AND   CAST(b.bet02 AS STRING) = '101'
    GROUP BY 1, 2
)
SELECT  a.mem,
        a.d                                           AS 参照日,
        a.注单数                                       AS 参照日_注单数,
        a.洗码量                                       AS 参照日_洗码量,
        AVG(p.注单数)                                  AS 前30日均_注单数,
        AVG(p.洗码量)                                  AS 前30日均_洗码量,
        COUNT(DISTINCT p.d)                           AS 前30日活跃日数
FROM        act a
LEFT JOIN   act p
       ON   p.mem = a.mem
      AND   p.d  >= DATE_SUB(a.d, INTERVAL 30 DAY)
      AND   p.d  <  a.d
LEFT JOIN   mk ON mk.mem = a.mem AND mk.mark_day = a.d
WHERE   mk.mem IS NULL
GROUP BY a.mem, a.d, a.注单数, a.洗码量
HAVING  COUNT(DISTINCT p.d) > 0
ORDER BY a.mem, a.d;

/* ═══════════════════════════════════════════════════════════════════════════
   §C06d · 对打对（带时点）—— 使折内金标准可算
   ---------------------------------------------------------------------------
   缘起：§C06fix 的产出**无任何时点列**（bet_ip, m_a, m_b, n_same_round,
   n_opposite_round, opposite_rate, hedge_coverage 共七列）。两份报告的金标准
   TRUTH ＝ 全窗完全反向对打成员 ∪ 人工风险单，其成员资格由**全窗**证据判定，
   却在净化滚动回测的**每一折训练标签**中直接使用。若某会员的完全反向行为
   发生在该折的测试窗内，其 y=1 仍进入训练——未来信息遂经由**标签**入模。
   此非特征侧泄漏（特征确实只取训练窗），而是**标签侧泄漏**，两者须分别审。

   本条与 §C06fix **同式同过滤**，只多产出三列时点，供构造折内金标准：
     first_opposite_dt  该对首次出现完全反向的营业日
     last_opposite_dt   该对最末一次
     n_opposite_days    出现完全反向的营业日数
   有此三列，折内金标准即可定义为
     TRUTH_tr(f) ＝ { m : first_opposite_dt(m) < 该折训练窗末日 } ∪ 人工风险单
   并可算出「仅由测试窗证据而入选者」占比——该数即标签侧泄漏的直接度量。

   ★ 人工风险单侧（K01b / SEED）亦须同样处置：其登记时点已在 §K01b 产出，
     折内金标准应只纳入登记日早于训练窗末日者。
   ═══════════════════════════════════════════════════════════════════════════ */

-- §C06d · 同 IP 对打对（带首末时点）
-- ▸ 导出：需要 —— 存为「数据库/C06d_hedge_pairs_dated.csv」（§C06d 对打对·带时点）。
-- ⚠ 门槛不一，取用前必先对齐（2026-08-10 实测查获，此为本条初版之误）：
--   §C06fix 的 HAVING 为 COUNT(*) >= 30（不设反向比例门槛）；
--   本条初版误设为 COUNT(*) >= 20 AND opposite_rate >= 0.9，故两表**不可逐行对齐**。
--   实测差额：本条全量 1,574 对，其中 n_same_round >= 30 且完全反向者 1,096 对，
--   仅因 20 <= n < 30 而多出者 339 对。今已将门槛改回 COUNT(*) >= 30 与 §C06fix 一致。
--   ★ 已导出的旧版 C06d（20 门槛）仍可用，但**下游必须再加 n_same_round >= 30 过滤**方与
--     §C06fix 同口径；重跑本条后即无须此步。
-- 读法：与 §C06fix 逐行可比（同 bet_ip + m_a + m_b 即同一对），多出三列时点。
--       凡 first_opposite_dt 落在某折测试窗内者，该对成员在该折**不得**计入训练标签。
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,
         b.bet11, b.bet13, b.bet18, b.bet19, b.bet20,
         b.bet21, b.bet22, b.bet38, b.bet39, b.category,
         b.eid, b.ip,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.ip AS bet_ip, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake
  FROM vd v
),
side AS (
  SELECT bet_ip, round_key, member_id, MIN(bet_date) AS round_date,
         SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                  WHEN TRIM(bet_side) = 'Player' THEN -stake
                  ELSE 0 END) AS dir_stake
  FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY bet_ip, round_key, member_id
  HAVING ABS(SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                      WHEN TRIM(bet_side) = 'Player' THEN -stake
                      ELSE 0 END)) > 0
)
SELECT  a.bet_ip,
        a.member_id                                   AS m_a,
        b.member_id                                   AS m_b,
        COUNT(*)                                      AS n_same_round,
        SUM(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN 1 ELSE 0 END) AS n_opposite_round,
        SUM(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN 1 ELSE 0 END)
          * 1.0 / COUNT(*)                            AS opposite_rate,
        MIN(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN a.round_date END) AS first_opposite_dt,
        MAX(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN a.round_date END) AS last_opposite_dt,
        COUNT(DISTINCT CASE WHEN a.dir_stake*b.dir_stake < 0 THEN a.round_date END)
                                                      AS n_opposite_days
FROM        side a
JOIN        side b
       ON   a.bet_ip = b.bet_ip
      AND   a.round_key = b.round_key
      AND   a.member_id < b.member_id
GROUP BY a.bet_ip, a.member_id, b.member_id
HAVING  COUNT(*) >= 30
ORDER BY opposite_rate DESC, n_opposite_round DESC;

/* ═══════════════════════════════════════════════════════════════════════════
   §TL · 准处置台账重建：能否由配置变更史还原「做过什么」（2026-08-10 立）
   ---------------------------------------------------------------------------
   缘起：泄漏矩阵⑬⑭⑮三环受阻于「平台无处置日志」。此判成立于 §EX-01——
   彼时所查的是**有没有一张名为处置日志的表**。今复核 `ods_a168_member_dtl` 结构，
   发现另一条可能的路：该表带**日分区列 dt**，且其列含风控处置的全部落点——

     mem003 退水 · mem016 電投退水      ← 降返水
     mem009 / mem010 最大押分 · mem015 新版限額  ← 限红
     mem012 最大可贏金額 · mem014 最大可輸金額   ← 可赢可输上限
     mem013 可贏可輸起算時間點                   ← 带时间戳的起算点

   **若该表为逐日快照，则同一会员的配置在 dt 轴上的跳变，即是一次处置事件。**
   处置日志不存在，不等于处置事实不可还原——**配置变更史是处置的影子**。

   ★ 但此路成立与否，须先证伪三个前提，缺一即断：
     ① 该表确为**逐日快照**（每个 dt 皆有全量会员行），而非只存最新一版；
     ② 配置值**确有跳变**（若全窗恒定，则窗口内无任何处置发生，此路无货）；
     ③ 跳变**可定日**（跳变日即处置日，误差不超过一日）。
   §TL-01 至 §TL-03 依次查此三事。三者皆过，方可进 §TL-03 抽取事件表。

   ⚠ 纵使三者皆过，所得仍是**准处置台账**而非处置台账：
     它记得「配置何时变了」，记不得「为何而变、由谁决定、是否属实验组」。
     故它能把证据等级从 E4 缺位推到 **E4 部分达成**，
     但 **E5（随机对照）仍缺**——配置变更是业务自行发生的，非随机分配，
     只能作**准实验**（如断点回归、双重差分），不能充随机对照。此界须守住。
   ═══════════════════════════════════════════════════════════════════════════ */

-- §TL-00 · 全库表清单与列义扫描：找出所有可能承载处置痕迹的表
-- ▸ 导出：需要 —— 存为「数据库/TL00_table_inventory.csv」（§TL-00 全库表与列义清单）。
-- 读法：COLUMN_COMMENT 里带「限額/限紅/退水/凍結/停用/狀態/審核/處理/備註/操作」等字样者，
--       皆为处置痕迹的候选；带「時間/日期/addtime/updatetime」者，为其定日的依据。
--       两类同时出现于一表，即该表有可能重建为准处置台账。
SELECT  c.TABLE_NAME,
        COUNT(*)                                                   AS 列数,
        SUM(CASE WHEN c.DATA_TYPE IN ('date','datetime') THEN 1 ELSE 0 END) AS 时间列数,
        SUM(CASE WHEN c.COLUMN_COMMENT LIKE '%限額%'
                   OR c.COLUMN_COMMENT LIKE '%限红%'
                   OR c.COLUMN_COMMENT LIKE '%限紅%'
                   OR c.COLUMN_COMMENT LIKE '%退水%'
                   OR c.COLUMN_COMMENT LIKE '%凍結%'
                   OR c.COLUMN_COMMENT LIKE '%冻结%'
                   OR c.COLUMN_COMMENT LIKE '%停用%'
                   OR c.COLUMN_COMMENT LIKE '%狀態%'
                   OR c.COLUMN_COMMENT LIKE '%状态%'
                   OR c.COLUMN_COMMENT LIKE '%審核%'
                   OR c.COLUMN_COMMENT LIKE '%审核%'
                   OR c.COLUMN_COMMENT LIKE '%處理%'
                   OR c.COLUMN_COMMENT LIKE '%处理%'
                   OR c.COLUMN_COMMENT LIKE '%操作%'
                   OR c.COLUMN_COMMENT LIKE '%備註%'
                   OR c.COLUMN_COMMENT LIKE '%备注%'
                 THEN 1 ELSE 0 END)                                AS 处置类列数,
        SUM(CASE WHEN c.COLUMN_COMMENT LIKE '%時間%'
                   OR c.COLUMN_COMMENT LIKE '%时间%'
                   OR c.COLUMN_COMMENT LIKE '%日期%'
                   OR c.COLUMN_NAME   LIKE '%time%'
                   OR c.COLUMN_NAME   LIKE '%date%'
                 THEN 1 ELSE 0 END)                                AS 定日类列数
FROM    information_schema.columns c
WHERE   c.TABLE_SCHEMA = 'ods_mariadb_2b'
  AND   c.TABLE_NAME LIKE 'ods_a168_%'
GROUP BY c.TABLE_NAME
HAVING  SUM(CASE WHEN c.COLUMN_COMMENT LIKE '%限額%'
                   OR c.COLUMN_COMMENT LIKE '%限红%'
                   OR c.COLUMN_COMMENT LIKE '%限紅%'
                   OR c.COLUMN_COMMENT LIKE '%退水%'
                   OR c.COLUMN_COMMENT LIKE '%凍結%'
                   OR c.COLUMN_COMMENT LIKE '%冻结%'
                   OR c.COLUMN_COMMENT LIKE '%停用%'
                   OR c.COLUMN_COMMENT LIKE '%狀態%'
                   OR c.COLUMN_COMMENT LIKE '%状态%'
                   OR c.COLUMN_COMMENT LIKE '%審核%'
                   OR c.COLUMN_COMMENT LIKE '%审核%'
                   OR c.COLUMN_COMMENT LIKE '%處理%'
                   OR c.COLUMN_COMMENT LIKE '%处理%'
                   OR c.COLUMN_COMMENT LIKE '%操作%'
                   OR c.COLUMN_COMMENT LIKE '%備註%'
                   OR c.COLUMN_COMMENT LIKE '%备注%'
                 THEN 1 ELSE 0 END) > 0
ORDER BY 处置类列数 DESC, 定日类列数 DESC, c.TABLE_NAME;

-- §TL-01 · member_dtl 是否逐日快照（前提①）
-- ▸ 导出：不需要 —— §TL-01 快照粒度探针，屏幕看结果。
-- 读法：① 若「日均会员行数」在各 dt 上大致相等且与在册会员数同量级 → 逐日快照，前提①成立；
--       ② 若只有寥寥几个 dt 有行 → 非逐日快照，本路即断，须改由源库取变更流水；
--       ③ 「每会员每日行数」若 > 1，说明按类别（mem002）分行，抽取变更时须先固定类别。
SELECT  dt,
        COUNT(*)                                          AS 行数,
        COUNT(DISTINCT CAST(mem001 AS STRING))            AS 会员数,
        COUNT(*) * 1.0 / COUNT(DISTINCT CAST(mem001 AS STRING)) AS 每会员行数,
        COUNT(DISTINCT CAST(mem002 AS STRING))            AS 类别数
FROM    ods_mariadb_2b.ods_a168_member_dtl
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
GROUP BY dt
ORDER BY dt;

-- §TL-02 · 配置值是否有跳变（前提②③）
-- ▸ 导出：需要 —— 存为「数据库/TL02_config_change.csv」（§TL-02 配置变更计数）。
-- 读法：逐会员统计各配置列在窗口内的**不同取值个数**；> 1 即该会员发生过配置变更。
--       变更会员数若为 0 → 窗口内无任何处置发生，准处置台账无货，此路虽通而空；
--       若为数千 → 处置确在发生，只是从未被记成日志，§TL-04 即可抽出事件表。
SELECT  变更列,
        SUM(CASE WHEN 取值数 > 1 THEN 1 ELSE 0 END)        AS 发生变更的会员数,
        COUNT(*)                                          AS 在册会员数,
        SUM(CASE WHEN 取值数 > 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS 变更率
FROM (
    SELECT  '退水 mem003' AS 变更列, CAST(mem001 AS STRING) AS mem,
            COUNT(DISTINCT CAST(mem003 AS STRING)) AS 取值数
    FROM ods_mariadb_2b.ods_a168_member_dtl
    WHERE dt >= '2026-03-21' AND dt < '2026-08-07' GROUP BY 1, 2
    UNION ALL
    SELECT  '最大押分 mem009', CAST(mem001 AS STRING),
            COUNT(DISTINCT CAST(mem009 AS STRING))
    FROM ods_mariadb_2b.ods_a168_member_dtl
    WHERE dt >= '2026-03-21' AND dt < '2026-08-07' GROUP BY 1, 2
    UNION ALL
    SELECT  '新版限額 mem015', CAST(mem001 AS STRING),
            COUNT(DISTINCT CAST(mem015 AS STRING))
    FROM ods_mariadb_2b.ods_a168_member_dtl
    WHERE dt >= '2026-03-21' AND dt < '2026-08-07' GROUP BY 1, 2
    UNION ALL
    SELECT  '最大可贏 mem012', CAST(mem001 AS STRING),
            COUNT(DISTINCT CAST(mem012 AS STRING))
    FROM ods_mariadb_2b.ods_a168_member_dtl
    WHERE dt >= '2026-03-21' AND dt < '2026-08-07' GROUP BY 1, 2
    UNION ALL
    SELECT  '可贏可輸起算 mem013', CAST(mem001 AS STRING),
            COUNT(DISTINCT CAST(mem013 AS STRING))
    FROM ods_mariadb_2b.ods_a168_member_dtl
    WHERE dt >= '2026-03-21' AND dt < '2026-08-07' GROUP BY 1, 2
) t
GROUP BY 变更列
ORDER BY 发生变更的会员数 DESC;

-- §TL-03 · 变更事件抽取：准处置台账（前提①②③皆过后方跑）
-- ▸ 导出：需要 —— 存为「数据库/TL03_pseudo_treatment.csv」（§TL-03 准处置台账·配置变更事件）。
-- 读法：每行一次配置跳变——谁、哪一日、哪一项、由何值变为何值、方向（收紧/放宽）。
--       此即 E4 所缺的处置账之影子：它记得做过什么、何时做的，
--       但记不得为何而做、由谁决定、是否属实验组，故只可作准实验，不可充随机对照。
WITH snap AS (
    SELECT  CAST(mem001 AS STRING)                        AS member_id,
            dt,
            CAST(NULLIF(TRIM(mem003), '') AS DOUBLE)      AS rebate,
            CAST(NULLIF(TRIM(mem009), '') AS DOUBLE)      AS maxbet,
            CAST(NULLIF(TRIM(mem012), '') AS DOUBLE)      AS maxwin,
            CAST(NULLIF(TRIM(mem014), '') AS DOUBLE)      AS maxloss
    FROM    ods_mariadb_2b.ods_a168_member_dtl
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(mem002 AS STRING) = '1'
),
lagged AS (
    SELECT  member_id, dt, rebate, maxbet, maxwin, maxloss,
            LAG(rebate)  OVER (PARTITION BY member_id ORDER BY dt) AS rebate_prev,
            LAG(maxbet)  OVER (PARTITION BY member_id ORDER BY dt) AS maxbet_prev,
            LAG(maxwin)  OVER (PARTITION BY member_id ORDER BY dt) AS maxwin_prev,
            LAG(maxloss) OVER (PARTITION BY member_id ORDER BY dt) AS maxloss_prev
    FROM    snap
)
SELECT  member_id,
        dt                                                AS change_date,
        CASE WHEN rebate <> rebate_prev THEN '退水'
             WHEN maxbet <> maxbet_prev THEN '最大押分'
             WHEN maxwin <> maxwin_prev THEN '最大可贏'
             ELSE '最大可輸' END                           AS action_type,
        CASE WHEN rebate <> rebate_prev THEN rebate_prev
             WHEN maxbet <> maxbet_prev THEN maxbet_prev
             WHEN maxwin <> maxwin_prev THEN maxwin_prev
             ELSE maxloss_prev END                         AS value_before,
        CASE WHEN rebate <> rebate_prev THEN rebate
             WHEN maxbet <> maxbet_prev THEN maxbet
             WHEN maxwin <> maxwin_prev THEN maxwin
             ELSE maxloss END                              AS value_after,
        CASE WHEN rebate <> rebate_prev THEN
                  CASE WHEN rebate < rebate_prev THEN '收紧' ELSE '放宽' END
             WHEN maxbet <> maxbet_prev THEN
                  CASE WHEN maxbet < maxbet_prev THEN '收紧' ELSE '放宽' END
             WHEN maxwin <> maxwin_prev THEN
                  CASE WHEN maxwin < maxwin_prev THEN '收紧' ELSE '放宽' END
             ELSE CASE WHEN maxloss < maxloss_prev THEN '收紧' ELSE '放宽' END
        END                                                AS direction
FROM    lagged
WHERE   rebate_prev IS NOT NULL
  AND   (rebate  <> rebate_prev
     OR  maxbet  <> maxbet_prev
     OR  maxwin  <> maxwin_prev
     OR  maxloss <> maxloss_prev)
ORDER BY member_id, change_date;

-- §K01c · 人工关注 IP 名单的登记时点（闭合泄漏矩阵第⑧环）
-- ▸ 导出：需要 —— 存为「数据库/K01c_seed_dated.csv」（§K01c 人工单登记时点）。
-- 读法：`addtime` 即登记时间，`creator` 为登记人。折内金标准的人工单侧须以此过滤——
--       只纳入登记日早于该折训练窗末日者，与对打侧的 first_opposite_dt 同理。
SELECT  CAST(id AS STRING)                                AS seed_id,
        TRIM(ip)                                          AS seed_ip,
        TRIM(creator)                                     AS creator,
        CAST(addtime AS STRING)                           AS addtime,
        SUBSTR(CAST(addtime AS STRING), 1, 10)            AS add_date,
        TRIM(remarks)                                     AS remarks
FROM    ods_mariadb_2b.ods_a168_alert_ip_setting
ORDER BY addtime;

/* ═══════════════════════════════════════════════════════════════════════════
   §TL 续 · 实测三结论与随之而来的四条查明（2026-08-10）
   ---------------------------------------------------------------------------
   【结论一】前提①成立，惟有一道时间断崖。
     §TL-01 实测：窗口内每一日皆有行，日均约 44,000 会员、每会员约 13.9 行
     （按 mem002 分 22 类），确为**逐日快照**。
     ⚠ 但自 **2026-07-19 起行数断崖**：由 72 万骤降至 8,409，其后每日仅数十至数百行。
       即该表实际只覆盖到 **2026-07-18**。准处置台账的可观察期因此止于该日，
       其后十九日（07-19 ~ 08-06）**无处置可观察**，非「无处置发生」。二者不可混为一谈。
     ⚠ 另有两处尖峰疑为重同步：2026-05-21（104,609 会员）与 2026-07-18（71,769 会员），
       其每会员行数降至 10.5，与常日的 13.9 不符，抽取事件时须先剔除或单独处置。

   【结论二】前提②成立，且 §TL-03 的零结果系其自身缺陷，非「确无处置」。
     §TL-02 实测（全表 5,702,058 会员为分母）：
       新版限額 mem015 变更率 **99.11%**（5,651,502 人）
       退水     mem003 变更率 **1.24%**（70,923 人）
       最大可贏 mem012 变更率 0.11%（6,312 人）
       可贏可輸起算 mem013 0.055%（3,124 人）
       最大押分 mem009 **1 人**
     而 §TL-03 返回零行——两者**直接矛盾**，故 §TL-03 有缺陷。已查得三处：
       ⓐ 其 `WHERE CAST(mem002 AS STRING) = '1'` 未经核实即写死；mem002 有 22 类，
         '1' 未必存在、亦未必是主类；
       ⓑ 其 `WHERE rebate_prev IS NOT NULL` 令 mem003 为空者整批落空，
         且 SQL 三值逻辑下 `a <> b` 遇 NULL 返回 NULL 而非 TRUE，比较自然不成立；
       ⓒ 其未纳入 **mem015**——而这恰是变更率最高的一列。
     §TL-03b 为其斧正版。

   【结论三】mem015 的 99.11% 变更率**高得可疑，不可直接采信为处置**。
     一个平台九成九的会员在同窗口内改过限额，不合经营常理。
     该列为 varchar(300)「新版限額」，极可能是**序列化的限额表**，
     其字面随重算或排序而变，而非限额本身变动。§TL-05 先探其取值形态，
     形态未明之前，**mem015 一律不得计入处置事件**。

   【结论四】另有两张表，名字就叫变更日志——此前从未查过。
     §TL-00 扫描列出 `ods_a168_log_mem_change`（会员变更日志，17 列 / 2 处置类列）
     与 `ods_a168_change_log`（14 列 / **5 处置类列**，为全库处置类列第十）。
     **若其中任一记的是会员配置的变更流水，则准处置台账无须由快照推断，可直接取用。**
     §TL-04 先看结构，§TL-06 再看内容。此路若通，胜过快照差分远矣。
   ═══════════════════════════════════════════════════════════════════════════ */

-- §TL-04 · 三张日志表的结构（先看骨，再看肉）
-- ▸ 导出：需要 —— 存为「数据库/TL04_log_schema.csv」（§TL-04 三张日志表结构）。
-- 读法：找三类列——**主体列**（会员或代理编号）、**时点列**（操作时间）、
--       **内容列**（改了什么、由何值变为何值、操作人）。三者俱全即为可用的处置流水。
SELECT  TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM    information_schema.columns
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'
  AND   TABLE_NAME IN ('ods_a168_log_mem_change',
                       'ods_a168_change_log',
                       'ods_a168_log_age_cash_change')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- §TL-05 · mem002 取值分布与 mem015 取值形态（解结论三之疑）
-- ▸ 导出：不需要 —— §TL-05 形态探针，屏幕看结果。
-- 读法：① mem002 各取值的会员数与占比，判定哪一类才是主类（§TL-03 写死 '1' 之误由此正）；
--       ② mem015 的样例取值与长度分布——若为长串序列化文本，即证其变更率之高
--          源于字面重排而非限额变动，该列遂不可作处置信号。
SELECT  CAST(mem002 AS STRING)                            AS 类别,
        COUNT(*)                                          AS 行数,
        COUNT(DISTINCT CAST(mem001 AS STRING))            AS 会员数,
        AVG(LENGTH(CAST(mem015 AS STRING)))               AS mem015_平均长度,
        MAX(LENGTH(CAST(mem015 AS STRING)))               AS mem015_最长,
        COUNT(DISTINCT CAST(mem015 AS STRING))            AS mem015_不同取值数,
        MAX(CAST(mem015 AS STRING))                       AS mem015_样例,
        COUNT(DISTINCT CAST(mem003 AS STRING))            AS mem003_不同取值数
FROM    ods_mariadb_2b.ods_a168_member_dtl
WHERE   dt >= '2026-03-21'
  AND   dt <= '2026-07-18'
GROUP BY 1
ORDER BY 会员数 DESC;

-- §TL-03b · 变更事件抽取（斧正版：去写死类别 · NULL 安全 · 限于可观察期）
-- ▸ 导出：需要 —— 存为「数据库/TL03b_pseudo_treatment.csv」（§TL-03b 准处置台账·斧正版）。
-- 三处斧正：ⓐ 不再写死 mem002='1'，改按会员×类别分区，各类别各自比对；
--           ⓑ NULL 安全——以 COALESCE 转哨兵值再比，杜绝三值逻辑下的静默漏判；
--           ⓒ 窗口收至 2026-07-18，即该表的实际覆盖末日（§TL-01 实测断崖）。
--           另：mem015 形态未明，本条**不纳入**，待 §TL-05 判定后再议。
-- 读法：每行一次配置跳变——谁、哪一类、哪一日、哪一项、由何值变为何值、收紧抑或放宽。
WITH snap AS (
    SELECT  CAST(mem001 AS STRING)                        AS member_id,
            CAST(mem002 AS STRING)                        AS cate,
            dt,
            COALESCE(CAST(NULLIF(TRIM(mem003), '') AS DOUBLE), -999999) AS rebate,
            COALESCE(CAST(NULLIF(TRIM(mem009), '') AS DOUBLE), -999999) AS maxbet,
            COALESCE(CAST(NULLIF(TRIM(mem012), '') AS DOUBLE), -999999) AS maxwin,
            COALESCE(CAST(NULLIF(TRIM(mem014), '') AS DOUBLE), -999999) AS maxloss
    FROM    ods_mariadb_2b.ods_a168_member_dtl
    WHERE   dt >= '2026-03-21'
      AND   dt <= '2026-07-18'
      AND   dt NOT IN ('2026-05-21', '2026-07-18')
),
lagged AS (
    SELECT  member_id, cate, dt, rebate, maxbet, maxwin, maxloss,
            LAG(rebate)  OVER (PARTITION BY member_id, cate ORDER BY dt) AS rebate_p,
            LAG(maxbet)  OVER (PARTITION BY member_id, cate ORDER BY dt) AS maxbet_p,
            LAG(maxwin)  OVER (PARTITION BY member_id, cate ORDER BY dt) AS maxwin_p,
            LAG(maxloss) OVER (PARTITION BY member_id, cate ORDER BY dt) AS maxloss_p,
            LAG(dt)      OVER (PARTITION BY member_id, cate ORDER BY dt) AS dt_p
    FROM    snap
)
SELECT  member_id,
        cate,
        dt_p                                              AS prev_date,
        dt                                                AS change_date,
        CASE WHEN rebate  <> rebate_p  THEN '退水'
             WHEN maxbet  <> maxbet_p  THEN '最大押分'
             WHEN maxwin  <> maxwin_p  THEN '最大可贏'
             ELSE '最大可輸' END                           AS action_type,
        CASE WHEN rebate  <> rebate_p  THEN rebate_p
             WHEN maxbet  <> maxbet_p  THEN maxbet_p
             WHEN maxwin  <> maxwin_p  THEN maxwin_p
             ELSE maxloss_p END                            AS value_before,
        CASE WHEN rebate  <> rebate_p  THEN rebate
             WHEN maxbet  <> maxbet_p  THEN maxbet
             WHEN maxwin  <> maxwin_p  THEN maxwin
             ELSE maxloss END                              AS value_after,
        CASE WHEN rebate  <> rebate_p  THEN CASE WHEN rebate  < rebate_p  THEN '收紧' ELSE '放宽' END
             WHEN maxbet  <> maxbet_p  THEN CASE WHEN maxbet  < maxbet_p  THEN '收紧' ELSE '放宽' END
             WHEN maxwin  <> maxwin_p  THEN CASE WHEN maxwin  < maxwin_p  THEN '收紧' ELSE '放宽' END
             ELSE CASE WHEN maxloss < maxloss_p THEN '收紧' ELSE '放宽' END
        END                                                AS direction
FROM    lagged
WHERE   dt_p IS NOT NULL
  AND  (rebate  <> rebate_p
     OR maxbet  <> maxbet_p
     OR maxwin  <> maxwin_p
     OR maxloss <> maxloss_p)
ORDER BY member_id, cate, change_date;

-- §TL-06 · 会员变更日志的内容探查（结论四之肉）
-- ▸ 导出：需要 —— 存为「数据库/TL06_log_mem_change.csv」（§TL-06 会员变更日志抽样与计数）。
-- 前置：须先跑 §TL-04 确认列名；本条按「表名即语义」的常见形制先写，列名不符即依 §TL-04 改写。
-- 读法：若该表逐行记「谁、何时、改了哪一项、由何值变为何值、操作人」，
--       则准处置台账无须由快照差分推断，可**直接取用**——此路胜过 §TL-03b 远矣。
SELECT  dt,
        COUNT(*)                                          AS 行数
FROM    ods_mariadb_2b.ods_a168_log_mem_change
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
GROUP BY dt
ORDER BY dt;

/* ═══════════════════════════════════════════════════════════════════════════
   §TL-07 · 处置台账正主：`log_mem_change` 结构证实（2026-08-10 实测）
   ---------------------------------------------------------------------------
   §TL-04 一跑，胜负立判。`ods_a168_log_mem_change` 的列如下——

     lmc02 ID          会员编号            ← 对谁
     lmc04 類別        enum('add','edit','changestatus')  ← 做了哪一类
     lmc05 內容        varchar(1000)       ← 改了什么
     lmc06 操作者 · lmc07 操作者LV         ← 谁决定的
     lmc08 異動時間    datetime            ← 何时
     lmc09 SQL         varchar(1000)       ← **实际执行的语句**，由何值改为何值尽在其中
     lmc10 IP · lmc11 操作者 utp           ← 从何处操作

   **这正是处置台账所要的六问：对谁、何时、做了什么、由何值到何值、谁决定、从何处。**
   E4 所缺者，本不在库外，而在此表——只是从未有人查过它。
   §TL-06 实测其窗口内每日皆有行（日均数十条），量级合乎人工操作日志之常。

   ⚠ 惟仍须守住一界：该表记的是**运营操作**，非**随机分配**。
     它能把 E4 由缺位推到达成，⑬环由受阻转为可证；
     但 **E5 随机对照依旧缺**——操作是业务因人而异地决定的，
     受处置者与未受处置者之间必有选择效应，只能作准实验，不可充随机对照。

   ─── 附：快照差分之路已实测为「通而近空」，就此收束 ────────────────────
     §TL-03b 全窗仅抽出 **148 个变更事件**，且**全为「最大可贏」放宽**——
     既非风控收紧，量级亦与 §TL-02 所示的 70,923 人退水变更相差五百倍。
     二者矛盾的解释是：§TL-02 数的是**字符串层面的不同取值数**
     （'0.00' 与 '0.0000' 即算两个），而 §TL-03b 数的是**数值层面的真变更**。
     故 §TL-02 的 99.11% 与 1.24% 皆系**字面形态差异所致的假阳性**，
     mem015 的高变更率由此亦得解释。
     **结论：快照差分不可作准处置台账，此路收束；改走 §TL-07 的操作日志。**
   ═══════════════════════════════════════════════════════════════════════════ */

-- §TL-07 · 处置日志的类别分布与内容形态
-- ▸ 导出：需要 —— 存为「数据库/TL07_mem_change_shape.csv」（§TL-07 处置日志类别与形态）。
-- 读法：① lmc04 三类（add / edit / changestatus）的条数与涉及会员数——
--          `changestatus` 最可能是状态类处置（停用、冻结），`edit` 为配置修改；
--       ② lmc05 内容与 lmc09 SQL 的平均长度与样例，判定能否从中解析出
--          「改了哪一列、由何值到何值」；能解析即可直接落为处置事件表。
SELECT  CAST(lmc04 AS STRING)                             AS 类别,
        COUNT(*)                                          AS 条数,
        COUNT(DISTINCT CAST(lmc02 AS STRING))             AS 涉及会员数,
        COUNT(DISTINCT CAST(lmc06 AS STRING))             AS 操作者数,
        MIN(CAST(lmc08 AS STRING))                        AS 最早异动,
        MAX(CAST(lmc08 AS STRING))                        AS 最晚异动,
        AVG(LENGTH(CAST(lmc05 AS STRING)))                AS 内容平均长度,
        MAX(CAST(lmc05 AS STRING))                        AS 内容样例,
        AVG(LENGTH(CAST(lmc09 AS STRING)))                AS SQL平均长度,
        MAX(CAST(lmc09 AS STRING))                        AS SQL样例
FROM    ods_mariadb_2b.ods_a168_log_mem_change
WHERE   dt >= '2026-03-21'
  AND   dt <  '2026-08-07'
GROUP BY 1
ORDER BY 条数 DESC;

-- §TL-08 · 处置事件表：能否与百家乐投注会员对上
-- ▸ 导出：需要 —— 存为「数据库/TL08_treatment_events.csv」（§TL-08 处置事件·与投注会员交集）。
-- 读法：本条把处置日志逐条落为事件行，并标出该会员是否为窗口内的百家乐投注会员。
--       ① 若交集甚小，则处置多施于非百家乐会员，本方案的因果链仍难闭合；
--       ② 若交集可观，则「处置组」已然成形，可与未处置者作准实验对照（须先做倾向得分匹配）。
--       ③ `是否在名单` 一列留待名单就位后回填，本条先不连接，以免把两件事绑死。
WITH ev AS (
    SELECT  CAST(lmc02 AS STRING)                         AS member_id,
            CAST(lmc04 AS STRING)                         AS action_class,
            SUBSTR(CAST(lmc08 AS STRING), 1, 10)          AS action_date,
            CAST(lmc08 AS STRING)                         AS action_time,
            CAST(lmc06 AS STRING)                         AS operator_id,
            CAST(lmc07 AS STRING)                         AS operator_lv,
            CAST(lmc05 AS STRING)                         AS content,
            CAST(lmc09 AS STRING)                         AS raw_sql
    FROM    ods_mariadb_2b.ods_a168_log_mem_change
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
),
bl AS (
    SELECT  DISTINCT CAST(bet05 AS STRING)                AS member_id
    FROM    ods_mariadb_2b.ods_a168_bet02
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(bet02 AS STRING) = '101'
)
SELECT  ev.member_id,
        ev.action_date,
        ev.action_time,
        ev.action_class,
        ev.operator_id,
        ev.operator_lv,
        ev.content,
        ev.raw_sql,
        CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END  AS is_baccarat_member
FROM        ev
LEFT JOIN   bl ON bl.member_id = ev.member_id
ORDER BY ev.action_time, ev.member_id;

/* ═══════════════════════════════════════════════════════════════════════════
   §TL-09 / §TL-10 · 处置台账落地：最后一里是列义翻译（2026-08-10 实测）
   ---------------------------------------------------------------------------
   §TL-07 / §TL-08 已跑毕，三项实测坐实处置台账可用：

     【量】8,707 条事件、2,948 名会员；其中**百家乐投注会员 661 名、事件 3,155 条**。
     【时】逐月 200 / 625 / 668 / 798 / 732 / 132，**覆盖全窗且无断崖**——
           与 member_dtl 快照止于 2026-07-18 迥异，日志按事件记，不受快照覆盖所限。
     【形】`content` 完全结构化：`mem015:1=>0;mem017:N=>Y;`——
           **列名、旧值、新值三者俱在**，正则即可解析；`lmc09` 另存原始 UPDATE 语句可交叉核对。

   三类事件的分布亦合乎常理：
     `edit`         4,784 条（其中百家乐 2,623）——配置修改，处置的主体
     `changestatus` 2,151 条（其中百家乐   532）——状态变更，最像风控停用类处置
     `add`          1,772 条（**百家乐 0**）——新增账户，与会员处置无涉，应予剔除

   ⚠ 最后一里：`content` 里的 `memNNN` 是 **`member` 表的列**，不是 `member_dtl` 的列
     （由 `lmc09` 的 `UPDATE member SET mem016 = N WHERE mem001 = …` 可证）。
     两表列名同形而异义，若照 `member_dtl` 的列义去读，必然全盘误判——
     此与 `bet41` 同名异义同类，且更隐蔽。故 §TL-09 先取 `member` 的列义字典，
     译出 mem015 / mem013 / mem012 / mem017 / mem014 / mem003 / mem022 / mem016
     八列究竟为何物，方可判定哪些跳变属**风控处置**、哪些只是日常运营。
     **列义未译之前，处置事件表不得投入使用。**
   ═══════════════════════════════════════════════════════════════════════════ */

-- §TL-09 · member 表列义字典（译出处置日志所改的八列）
-- ▸ 导出：需要 —— 存为「数据库/TL09_member_schema.csv」（§TL-09 member 表列义）。
-- 读法：只看 COLUMN_COMMENT。八列中凡译出为限额、退水、状态、停用、权限者，即属处置；
--       译为昵称、语言、渠道者，即属日常运营，须自处置事件表剔除。
SELECT  ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM    information_schema.columns
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'
  AND   TABLE_NAME   = 'ods_a168_member'
ORDER BY ORDINAL_POSITION;

-- §TL-10 · 处置事件规范表：一次跳变一行（列义译定后方可投用）
-- ▸ 导出：需要 —— 存为「数据库/TL10_treatment_ledger.csv」（§TL-10 处置台账·规范事件表）。
-- 做法：content 形如「列:旧值=>新值」后接分隔符，可含多段，以 SPLIT 逐段拆开再逐段解析。
--       剔除 add 类（实测百家乐会员零命中，属新增账户而非处置）。
-- 读法：每行一次跳变——对谁、何时、哪一列、由何值到何值、谁操作、其层级、是否百家乐会员。
--       此表即 E4 所要的处置账；惟仍非随机分配，只可作准实验，不可充随机对照。
WITH ev AS (
    SELECT  CAST(lmc02 AS STRING)                         AS member_id,
            CAST(lmc04 AS STRING)                         AS action_class,
            SUBSTR(CAST(lmc08 AS STRING), 1, 10)          AS action_date,
            CAST(lmc08 AS STRING)                         AS action_time,
            CAST(lmc06 AS STRING)                         AS operator_id,
            CAST(lmc07 AS STRING)                         AS operator_lv,
            CAST(lmc05 AS STRING)                         AS content
    FROM    ods_mariadb_2b.ods_a168_log_mem_change
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(lmc04 AS STRING) IN ('edit', 'changestatus')
),
seg AS (
    SELECT  e.member_id, e.action_class, e.action_date, e.action_time,
            e.operator_id, e.operator_lv,
            TRIM(s.piece)                                 AS piece
    FROM    ev e, unnest(split(e.content, ';')) AS s(piece)
),
parsed AS (
    SELECT  member_id, action_class, action_date, action_time,
            operator_id, operator_lv, piece,
            TRIM(SPLIT_PART(piece, ':', 1))               AS field_name,
            TRIM(SPLIT_PART(SPLIT_PART(piece, ':', 2), '=>', 1)) AS value_before,
            TRIM(SPLIT_PART(SPLIT_PART(piece, ':', 2), '=>', 2)) AS value_after
    FROM    seg
    WHERE   piece LIKE '%=>%'
      AND   piece LIKE '%:%'
),
guarded AS (
    -- 护栏：另有一类 edit 内容形如「skyname=>…, Gateway_url=>https://…」，
    -- 其 URL 里的冒号会骗过上面的两个 LIKE，解析出一整串垃圾作列名。
    -- 故加数道限制——列名须短、须无空格、须不含箭头与斜杠；实测所见列名皆形如 memNNN 或 tip。
    SELECT  *
    FROM    parsed
    WHERE   LENGTH(field_name) BETWEEN 2 AND 12
      AND   field_name NOT LIKE '% %'
      AND   field_name NOT LIKE '%=>%'
      AND   field_name NOT LIKE '%/%'
      AND   value_after NOT LIKE '%//%'
),
bl AS (
    SELECT  DISTINCT CAST(bet05 AS STRING)                AS member_id
    FROM    ods_mariadb_2b.ods_a168_bet02
    WHERE   dt >= '2026-03-21'
      AND   dt <  '2026-08-07'
      AND   CAST(bet02 AS STRING) = '101'
)
SELECT  p.member_id,
        p.action_date,
        p.action_time,
        p.action_class,
        p.field_name,
        p.value_before,
        p.value_after,
        p.operator_id,
        p.operator_lv,
        CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END  AS is_baccarat_member
FROM        guarded p
LEFT JOIN   bl ON bl.member_id = p.member_id
ORDER BY p.action_time, p.member_id, p.field_name;


/* ═══════════════════════════════════════════════════════════════════════════
   §TL-11 · 处置节折叠：收紧→解除配对成节（episode），准实验的分析单元
   ---------------------------------------------------------------------------
   缘起：§TL-10 以「一次跳变一行」为粒度——收紧与解除各二百余条**不构成
   数百个独立处置**。准实验的分析单元是「会员 × 处置节」：同一会员同一字段上的
   「收紧 → 其后首个解除」折叠为一节，时长即节内天数；解除缺席者右删失于窗末。
   此为报告 @sec-quasi-design 设计细则其一的 SQL 侧落地，与 @sec-quasi-run
   第①步的 R 侧口径对齐（T0 取首次收紧、t_end 取其后首个解除）。
   口径三则：
     ① 只认两枚已译定的处置字段：mem017（canbet 下注权限）、mem016（enable 账户
        启停）；mem015（login_error 计数）等日常运营列一概不入（列义见 §TL-09）。
     ② 方向按 value_after 判：N／0 为收紧（TIGHTEN），Y／1 为解除（RELEASE），
        其余记 OTHER 且不入节——宁缺毋滥，不为不明取值编造方向。
     ③ 去重键 member × field × action_time × 前后值：同刻重复写入只计一次。
   读法：每行一节——谁、何字段、何时收紧、由谁操作、何时解除（或右删失）、
   持续几日、是其第几节。主分析取 episode_seq = 1（首次处置设计），
   再处置节只入敏感性分析。连续两次收紧共享其后首个解除，属同一逻辑节之延续。
   此表同时是治理章审计轨迹的节级视图：operator 列即「谁做的」，
   所缺的「谁批准的」须待 DDL 增列（见报告 @sec-governance）。
   ═══════════════════════════════════════════════════════════════════════════ */
-- §TL-11 · 处置节折叠表（准实验分析单元；审计轨迹之节级视图）
-- ▸ 导出：需要 —— 存为「数据库/TL11_treatment_episode.csv」（§TL-11 处置节·收紧→解除配对）。
-- ★ 2026-08-11 补正六列（外部审计第十条）：is_baccarat_member（本方案口径）、
--   enforcement_type（处置类别）、business_field（业务列名）、censor_reason（删失成因）、
--   parse_status / parse_sep（解析状态与所用分隔符）——后二者堵住静默丢弃之漏。
-- ★ 解析容错：实测 changestatus 有两种写法——「mem016:N=>Y」（冒号）与「mem020 Y=>N」（空格），二者皆以分隔符收束。
--   旧版只认冒号，空格式 815 条被静默丢弃（所幸皆为 mem020 且皆非百家乐会员）。
--   今两式并收，并以 parse_sep 记明每行所用者，使丢弃永不再静默。
WITH ev AS (                                                                                        -- 公共表表达式：开启中间结果集 ev——变更日志原始事件，口径与 §TL-10 一致（§TL-11）
    SELECT  CAST(lmc02 AS STRING)                         AS member_id,                             -- 取值表达式：取用 lmc02（被改会员号），产出「member_id」
            SUBSTR(CAST(lmc08 AS STRING), 1, 10)          AS action_date,                           -- 取值表达式：取用 lmc08（操作时间）之日期段，产出「action_date」
            CAST(lmc08 AS STRING)                         AS action_time,                           -- 取值表达式：取用 lmc08（操作时间），产出「action_time」
            CAST(lmc06 AS STRING)                         AS operator_id,                           -- 取值表达式：取用 lmc06（操作人账号），产出「operator_id」——审计轨迹之「谁」
            CAST(lmc07 AS STRING)                         AS operator_lv,                           -- 取值表达式：取用 lmc07（操作人层级），产出「operator_lv」
            CAST(lmc05 AS STRING)                         AS content                                -- 取值表达式：取用 lmc05（变更内容串），产出「content」
    FROM    ods_mariadb_2b.ods_a168_log_mem_change                                                  -- 取数来源：取自会员变更日志表（处置痕迹的正主）
    WHERE   dt >= '2026-03-21'                                                                      -- 过滤条件：限定 dt不少于 '2026-03-21'，涉 dt（营业日）——E1 全局窗起点
      AND   dt <  '2026-08-07'                                                                      -- 并列条件：限定 dt小于 '2026-08-07'——E1 全局窗终点（冻结字面量）
      AND   CAST(lmc04 AS STRING) IN ('edit', 'changestatus')                                       -- 并列条件：只留配置修改与状态变更；add 系新增账户与处置无涉
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
seg AS (                                                                                            -- 公共表表达式：开启中间结果集 seg——把多段 content 逐段拆开（§TL-11）
    SELECT  e.member_id, e.action_date, e.action_time,                                              -- 取列：起始取列子句，本行先列 member_id, action_date, action_time
            e.operator_id, e.operator_lv,                                                           -- 续行：接续上一取列子句，续列 operator_id, operator_lv
            TRIM(s.piece)                                 AS piece                                  -- 取值表达式：逐段去空白，产出「piece」
    FROM ev e, unnest(split(e.content, ';')) AS s(piece)                                            -- 行展开：以 unnest(split(…)) 把分号分隔的多段变更逐段成行（StarRocks 已验语法）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
norm AS (                                                                                           -- 公共表表达式：开启中间结果集 norm——两式并收：冒号式与空格式统一为「列|旧|新」（§TL-11）
    SELECT  member_id, action_date, action_time, operator_id, operator_lv, piece,                   -- 取列：起始取列子句，透传六要素与原始片段
            CASE WHEN piece LIKE '%:%' THEN 'COLON' ELSE 'SPACE' END AS parse_sep,                  -- 取值表达式：记明所用分隔符，产出「parse_sep」——★ 使丢弃永不静默
            CASE WHEN piece LIKE '%:%'                                                              -- 取值表达式：列名解析起算——冒号式取冒号前段
                 THEN TRIM(SPLIT_PART(piece, ':', 1))                                               -- 续行：冒号式列名
                 ELSE TRIM(SPLIT_PART(piece, ' ', 1)) END      AS field_name,                       -- 续行：空格式取首个空格前段（如「mem020 Y=>N」），产出「field_name」
            CASE WHEN piece LIKE '%:%'                                                              -- 取值表达式：旧值解析起算
                 THEN TRIM(SPLIT_PART(SPLIT_PART(piece, ':', 2), '=>', 1))                          -- 续行：冒号式旧值
                 ELSE TRIM(SPLIT_PART(SPLIT_PART(piece, ' ', 2), '=>', 1)) END AS value_before,     -- 续行：空格式旧值，产出「value_before」
            TRIM(SPLIT_PART(piece, '=>', 2))              AS value_after                            -- 取值表达式：新值一律取箭头后段（两式同形），产出「value_after」
    FROM    seg                                                                                     -- 取数来源：取自本条自建的中间结果集 seg
    WHERE   piece LIKE '%=>%'                                                                       -- 过滤条件：须含箭头方为有效变更段——两式共有的唯一必要标志
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
enf AS (                                                                                            -- 公共表表达式：开启中间结果集 enf——只留已译定的处置字段并判方向与类别（§TL-11）
    SELECT  member_id, field_name, action_date, action_time,                                        -- 取列：起始取列子句，透传节要素之前四
            value_before, value_after, operator_id, operator_lv, parse_sep,                         -- 续行：接续上一取列子句，续列前后值、操作人与分隔符
            CASE WHEN field_name = 'mem017' THEN 'CANBET_下注权限'                                      -- 取值表达式：处置类别起算——mem017 系下注权限（§TL-09 列义）
                 WHEN field_name = 'mem016' THEN 'ENABLE_账户启停'                                      -- 续行：mem016 系账户启停
                 ELSE 'OTHER' END                     AS enforcement_type,                          -- 续行：产出「enforcement_type」——外部审计所要的处置类别列
            CASE WHEN field_name = 'mem017' THEN 'canbet'                                           -- 取值表达式：业务列名起算——代号译为业务名，免下游再查字典
                 WHEN field_name = 'mem016' THEN 'enable'                                           -- 续行：mem016 之业务名
                 ELSE 'unknown' END                   AS business_field,                            -- 续行：产出「business_field」
            CASE WHEN TRIM(value_after) IN ('N', '0') THEN 'TIGHTEN'                                -- 取值表达式：新值为 N／0 判收紧——禁投或停用
                 WHEN TRIM(value_after) IN ('Y', '1') THEN 'RELEASE'                                -- 续行：新值为 Y／1 判解除
                 ELSE 'OTHER' END                     AS direction,                                 -- 续行：其余取值不明记 OTHER，不入节（宁缺毋滥），产出「direction」
            'OK'                                     AS parse_status                                -- 取值表达式：解析状态，产出「parse_status」——本 CTE 所留者皆已解析成功
    FROM    norm                                                                                    -- 取数来源：取自本条自建的中间结果集 norm
    WHERE   field_name IN ('mem016', 'mem017')                                                      -- 过滤条件：只认已译定的处置字段——mem015 已证为 login_error，非处置，一律不入
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
dedup AS (                                                                                          -- 公共表表达式：开启中间结果集 dedup——同刻重复写入只计一次（去重键四元组）
    SELECT  *,                                                                                      -- 取列：整体承接上游结果集的全部字段，不再逐列列举
            ROW_NUMBER() OVER (PARTITION BY member_id, field_name, action_time,                     -- 行号窗口表达式：按去重键 member×field×时刻×前后值 分组编号
                               value_before, value_after ORDER BY operator_id) AS rn                -- 续行：键内任取其一（按操作人序），产出「rn」
    FROM    enf                                                                                     -- 取数来源：取自本条自建的中间结果集 enf
    WHERE   direction <> 'OTHER'                                                                    -- 过滤条件：方向不明者不入节
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
tight AS (                                                                                          -- 公共表表达式：开启中间结果集 tight——全部收紧事件，每行是一节的起点（§TL-11）
    SELECT * FROM dedup WHERE rn = 1 AND direction = 'TIGHTEN'                                      -- 取数来源：去重后的收紧事件
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
rel AS (                                                                                            -- 公共表表达式：开启中间结果集 rel——全部解除事件，用以为每节寻其后首个解除（§TL-11）
    SELECT * FROM dedup WHERE rn = 1 AND direction = 'RELEASE'                                      -- 取数来源：去重后的解除事件
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
bl AS (                                                                                             -- 公共表表达式：开启中间结果集 bl——本方案口径的百家乐投注会员名单（§TL-11 补列所需）
    SELECT  DISTINCT CAST(bet05 AS STRING)                AS member_id                              -- 取值表达式：取用 bet05（会员号）去重，产出「member_id」
    FROM    ods_mariadb_2b.ods_a168_bet02                                                           -- 取数来源：取自注单明细表
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
      AND   CAST(bet02 AS STRING) = '101'                                                           -- 并列条件：限定百家乐产品大类，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
la AS (                                                                                             -- 公共表表达式：开启中间结果集 la——每会员窗内最末一次**投注**，供删失成因分类（§TL-11）
    SELECT  CAST(bet05 AS STRING)                         AS member_id,                             -- 取值表达式：取用 bet05（会员号），产出「member_id」
            MAX(dt)                                       AS last_bet_date,                         -- 聚合：该会员窗内最末一次投注之营业日，产出「last_bet_date」
            COUNT(*)                                      AS n_bets_in_window                       -- 计数表达式：窗内注单数，产出「n_bets_in_window」——覆盖率证据，供删失分类追溯
    FROM    ods_mariadb_2b.ods_a168_bet02                                                           -- 取数来源：取自注单明细表——★ 2026-08-11 斧正：旧版以「最末一次出现于变更日志」为凭
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗——而变更日志之缺席只说明未再改配置，不说明人已不在
    GROUP BY CAST(bet05 AS STRING)                                                                  -- 分组：按会员汇总——投注活动方是「仍在观察」的正当凭据
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
lc AS (                                                                                             -- 公共表表达式：开启中间结果集 lc——每会员末次配置变更时刻（§TL-11）
    SELECT  member_id, MAX(action_time)                   AS last_config_time                       -- 聚合：末次出现于变更日志之时刻，产出「last_config_time」
    FROM    norm GROUP BY member_id                                                                 -- 取数来源：取自本条自建的中间结果集 norm——★ 此量仅作证据留档，**不再用作删失判据**
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11）
ep AS (                                                                                             -- 公共表表达式：开启中间结果集 ep——为每次收紧配其后首个解除（§TL-11）
    SELECT  t.member_id, t.field_name, t.business_field, t.enforcement_type,                        -- 取列：起始取列子句，节起点要素与两枚新增类别列
            t.action_date, t.action_time, t.value_before, t.value_after,                            -- 续行：接续上一取列子句，续列时点与前后值
            t.operator_id, t.operator_lv, t.parse_sep, t.parse_status,                              -- 续行：续列操作人、层级与解析两列
            MIN(r.action_time)                            AS release_time                           -- 聚合：其后（同人同字段）首个解除时刻，无则空，产出「release_time」
    FROM        tight t                                                                             -- 取数来源：取自本条自建的中间结果集 tight
    LEFT JOIN   rel   r                                                                             -- 左连接：取自本条自建的中间结果集 rel——解除可缺席（右删失），故用左连接
           ON   r.member_id  = t.member_id                                                          -- 连接键：同一会员
          AND   r.field_name = t.field_name                                                         -- 并列键：同一处置字段——canbet 之节不由 enable 之解除关闭
          AND   r.action_time > t.action_time                                                       -- 并列键：解除须晚于收紧——只认其后者
    GROUP BY t.member_id, t.field_name, t.business_field, t.enforcement_type,                       -- 分组：按节起点全键汇总，使 MIN 取到「首个」解除
             t.action_date, t.action_time, t.value_before, t.value_after,                           -- 续行：分组键补齐
             t.operator_id, t.operator_lv, t.parse_sep, t.parse_status                              -- 续行：分组键补齐
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§TL-11）
SELECT  p.member_id,                                                                                -- 取列：起始取列子句，本行先取「member_id」——节属谁
        p.field_name,                                                                               -- 取值表达式：处置字段代号
        p.business_field,                                                                           -- 取值表达式：业务列名（canbet／enable）——★ 补列，免下游再查字典
        p.enforcement_type,                                                                         -- 取值表达式：处置类别——★ 补列，区分下注权限与账户启停
        CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END  AS is_baccarat_member,                    -- 取值表达式：是否本方案口径的百家乐会员——★ 补列，准实验总体由此界定
        CONCAT_WS('#', p.member_id, p.field_name, p.action_time) AS episode_id,                     -- 取值表达式：三键拼节号，产出「episode_id」——审计轨迹与准实验共用的主键
        p.action_date                                 AS start_date,                                -- 取值表达式：节起日，产出「start_date」
        p.action_time                                 AS start_time,                                -- 取值表达式：节起时刻，产出「start_time」
        p.value_before,                                                                             -- 取值表达式：收紧前取值——留痕以备申诉复核
        p.value_after,                                                                              -- 取值表达式：收紧后取值
        p.operator_id                                 AS start_operator,                            -- 取值表达式：收紧操作人，产出「start_operator」——审计轨迹之「谁」
        p.operator_lv                                 AS start_operator_lv,                         -- 取值表达式：操作人层级，产出「start_operator_lv」
        p.parse_sep,                                                                                -- 取值表达式：本行所用分隔符（COLON／SPACE）——★ 补列，两式并收之凭据
        p.parse_status,                                                                             -- 取值表达式：解析状态——★ 补列，恒为 OK；丢弃者见 §TL-11b 对账
        COALESCE(SUBSTR(p.release_time, 1, 10), '2026-08-07') AS release_date,                      -- 取值表达式：解除日；缺席者以窗末顶替（配合下行 censored 判读），产出「release_date」
        CASE WHEN p.release_time IS NULL THEN 1 ELSE 0 END    AS censored,                          -- 取值表达式：右删失标志——1 谓至窗末仍收紧，产出「censored」
        la.last_bet_date,                                                                           -- 取值表达式：末次投注营业日——★ 删失分类之原始证据，供逐节追溯
        la.n_bets_in_window,                                                                        -- 取值表达式：窗内注单数——★ 覆盖率证据
        lc.last_config_time,                                                                        -- 取值表达式：末次配置变更时刻——★ 第二重证据（旧判据留档，已不作分类依据）
        DATEDIFF(DATE '2026-08-06', CAST(la.last_bet_date AS DATE)) AS days_since_last_bet,         -- 取值表达式：末次投注距窗末天数——★ **连续原始量**，供 3D／7D／14D 敏感性，免回访原表
        7                                             AS censor_cutoff_days,                        -- 取值表达式：本次分类所用的运营切点（日）——★ 显式化：7 日是**工程约定**，非统计真理
        CASE WHEN p.release_time IS NOT NULL THEN 'NOT_CENSORED'                                    -- 取值表达式：删失成因分类起算——★ KM 无偏性之前提
             WHEN la.last_bet_date IS NULL THEN 'NO_BET_ACTIVITY'                                   -- 续行：窗内全无投注 → 无从判其去留（先判此项，免 NULL 落入比较而误分）
             WHEN DATEDIFF(DATE '2026-08-06', CAST(la.last_bet_date AS DATE)) <= 7                  -- 续行：末次投注距窗末不逾切点 → 人尚在、处置尚在
                  THEN 'WINDOW_END'                                                                 -- 续行：属真窗口右删失
             ELSE 'INACTIVE_BEFORE_END' END                    AS censor_reason,                    -- 续行：投注早止 → 疑为流失或账户终止型**假删失**，产出「censor_reason」
        DATEDIFF(CAST(COALESCE(SUBSTR(p.release_time, 1, 10), '2026-08-07') AS DATE),               -- 取值表达式：节时长起算——解除日（或窗末）
                 CAST(p.action_date AS DATE))         AS duration_days,                             -- 续行：减节起日得持续天数，产出「duration_days」——生存分析之时间轴
        ROW_NUMBER() OVER (PARTITION BY p.member_id                                                 -- 行号窗口表达式：按会员为其节编序
                           ORDER BY p.action_time)    AS episode_seq                                -- 续行：产出「episode_seq」——主分析取 1（首次处置设计），其余入敏感性
FROM        ep p                                                                                    -- 取数来源：取自本条自建的中间结果集 ep
LEFT JOIN   bl ON bl.member_id = p.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）——标注百家乐口径
LEFT JOIN   la ON la.member_id = p.member_id                                                        -- 左连接：取自本条自建的中间结果集 la（末次投注日），连接键为 member_id（会员号）
LEFT JOIN   lc ON lc.member_id = p.member_id                                                        -- 左连接：取自本条自建的中间结果集 lc（末次配置变更），连接键为 member_id（会员号）
ORDER BY p.member_id, p.action_time;                                                                -- 排序：按会员与节起时刻升序——逐人可读其处置史；导出必带排序，分页方有稳定序


/* ═══════════════════════════════════════════════════════════════════════════
   §TL-11b · 解析对账：进了几条、出了几条、丢了几条、为何而丢
   ---------------------------------------------------------------------------
   缘起：旧版 §TL-11 只认冒号式「mem016:N=>Y;」，而实测另有空格式「mem020 Y=>N;」
   共 815 条，被 LIKE '%:%' **静默丢弃**（所幸皆为 mem020 且皆非百家乐会员）。
   静默是最坏的失败方式。本查询把每一条原始片段的去向逐类点清，
   使「丢了多少、因何而丢」永远看得见。
   读法：DROPPED_* 各类之和 + KEPT 应等于 TOTAL_PIECES。凡 DROPPED_NO_ARROW 之外
   出现大额其他类别，即须回头查解析规则，不得默认。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §TL-11b 解析对账，屏幕看结果。
WITH ev AS (                                                                                        -- 公共表表达式：开启中间结果集 ev——与 §TL-11 同源同窗（§TL-11b）
    SELECT  CAST(lmc05 AS STRING) AS content, CAST(lmc04 AS STRING) AS action_class                 -- 取值表达式：取用 lmc05（变更内容）与 lmc04（事件类别）
    FROM    ods_mariadb_2b.ods_a168_log_mem_change                                                  -- 取数来源：取自会员变更日志表
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
      AND   CAST(lmc04 AS STRING) IN ('edit', 'changestatus')                                       -- 并列条件：只留配置修改与状态变更两类
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11b）
seg AS (                                                                                            -- 公共表表达式：开启中间结果集 seg——逐段拆开（§TL-11b）
    SELECT  TRIM(s.piece) AS piece FROM ev e, unnest(split(e.content, ';')) AS s(piece)             -- 行展开：以 unnest(split(…)) 把分号分隔的多段逐段成行
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11b）
cls AS (                                                                                            -- 公共表表达式：开启中间结果集 cls——为每一片段判其去向（§TL-11b）
    SELECT  piece,                                                                                  -- 取列：起始取列子句，本行先取「piece」
            CASE WHEN piece = '' THEN 'DROPPED_EMPTY'                                               -- 取值表达式：**解析**状态分类起算（第一层）——空片段
                 WHEN piece NOT LIKE '%=>%' THEN 'DROPPED_NO_ARROW'                                 -- 续行：无箭头者非变更段，正当丢弃
                 WHEN piece LIKE '%//%' THEN 'DROPPED_URL_LIKE'                                     -- 续行：含双斜杠者疑为网址，正当丢弃（沿 §TL-10 护栏）
                 WHEN piece LIKE 'mem016%' OR piece LIKE 'mem017%' THEN 'KEPT_ENFORCEMENT'          -- 续行：两枚已译定的处置字段——本方案所取者
                 WHEN piece LIKE '%:%' THEN 'PARSED_COLON_OTHERFIELD'                               -- 续行：冒号式但非处置字段——解析得出，按业务分类排除
                 ELSE 'PARSED_SPACE_OTHERFIELD' END              AS parse_status,                   -- 续行：空格式且非处置字段——★ 旧版在此静默丢弃，今已收编，产出「parse_status」
            CASE WHEN piece LIKE 'mem016%' OR piece LIKE 'mem017%'                                  -- 取值表达式：**语义**状态分类起算（第二层，外部审计第二条）
                 THEN 'CONFIRMED_BY_DICTIONARY'                                                     -- 续行：§TL-09 列义字典已译定（enable／canbet），语义确认
                 WHEN piece LIKE 'mem015%' THEN 'CONFIRMED_NOT_ENFORCEMENT'                         -- 续行：已译定为 login_error，确认**非**处置，封案
                 WHEN piece LIKE '%=>%' THEN 'UNKNOWN_PENDING_DICTIONARY'                           -- 续行：解析得出而列义未证——如 mem020、101-mem015
                 ELSE 'NOT_APPLICABLE' END                       AS semantic_status,                -- 续行：非变更段，无语义可言，产出「semantic_status」
            CASE WHEN piece LIKE 'mem016%' OR piece LIKE 'mem017%' THEN 'ENFORCEMENT'               -- 取值表达式：**处置**状态分类起算（第三层）
                 WHEN piece LIKE 'mem015%' THEN 'NOT_ENFORCEMENT'                                   -- 续行：运营追踪事件，明确排除
                 WHEN piece LIKE '%=>%' THEN 'PENDING'                                              -- 续行：语义未证者一律待定——**解析成功 ≠ 业务语义确认**，不得径入处置总体
                 ELSE 'NOT_APPLICABLE' END                       AS enforcement_status              -- 续行：产出「enforcement_status」
    FROM    seg                                                                                     -- 取数来源：取自本条自建的中间结果集 seg
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§TL-11b）
SELECT  parse_status, semantic_status, enforcement_status,                                          -- 取列：起始取列子句，三状态并列——解析成功、语义确认、处置认定，三者彻底分离
        COUNT(*)                                      AS n_pieces,                                  -- 计数表达式：该类片段条数，产出「n_pieces」
        COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()        AS share,                                     -- 除法或乘法计算：占全部片段之比，产出「share」
        MIN(piece)                                    AS sample_min,                                -- 取最小值表达式：字母序最小之样例，产出「sample_min」——供人工目检
        MAX(piece)                                    AS sample_max                                 -- 取最大值表达式：字母序最大之样例，产出「sample_max」
FROM    cls                                                                                         -- 取数来源：取自本条自建的中间结果集 cls
GROUP BY parse_status, semantic_status, enforcement_status                                          -- 分组：按三状态组合汇总——每格皆须有明确取值
ORDER BY n_pieces DESC;                                                                             -- 排序：按条数降序——大宗去向居前


/* ═══════════════════════════════════════════════════════════════════════════
   §TL-12 · 设备维度发现：库内究竟有无设备标识字段
   ---------------------------------------------------------------------------
   缘起：本方案的关系维覆盖产品、实体、局、IP、代理，**独缺设备**，且从未查证
   库内有无此字段。设备共用的基数远小于 IP、指向性远强于 IP——本方案的地理维度
   正因 IP 被电信基础设施稀释而作废（见报告 @sec-ip-e1），设备或可补此缺。
   ⚠ 纪律：**找到字段 ≠ 立即纳入模型**。须先过基数、覆盖率、稳定性、
   跨网络判别力四道体检（见报告 @sec-device），方按 L2 层准入判据定夺。
   读法：先看 COLUMN_NAME 与 COLUMN_COMMENT 是否真指设备；同名而异义者甚多
   （如 type、client 可能指业务类型而非客户端），一律回查列义与取值分布再定。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §TL-12 设备字段发现，屏幕看结果。
SELECT  TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT                        -- 取列：起始取列子句，逐列列出表名、序位、列名、类型与列义
FROM    information_schema.columns                                                                  -- 取数来源：取自库内元数据字典（列级）
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定本项目所用库
  AND ( LOWER(COLUMN_NAME) LIKE '%device%'                                                          -- 并列条件：英文候选起算——device 类
     OR LOWER(COLUMN_NAME) LIKE '%fingerprint%'                                                     -- 续行：指纹类
     OR LOWER(COLUMN_NAME) LIKE '%imei%'                                                            -- 续行：手机设备串号
     OR LOWER(COLUMN_NAME) LIKE '%idfa%'                                                            -- 续行：iOS 广告标识
     OR LOWER(COLUMN_NAME) LIKE '%android%'                                                         -- 续行：Android 标识
     OR LOWER(COLUMN_NAME) LIKE '%hardware%'                                                        -- 续行：硬件标识
     OR LOWER(COLUMN_NAME) LIKE '%terminal%'                                                        -- 续行：终端标识
     OR LOWER(COLUMN_NAME) LIKE '%browser%'                                                         -- 续行：浏览器标识
     OR LOWER(COLUMN_NAME) LIKE '%client%'                                                          -- 续行：客户端标识（⚠ 或指业务侧客户，须回查列义）
     OR LOWER(COLUMN_NAME) LIKE '%user_agent%'                                                      -- 续行：UA 全称
     OR LOWER(COLUMN_NAME) LIKE '%useragent%'                                                       -- 续行：UA 连写
     OR LOWER(COLUMN_NAME) = 'ua'                                                                   -- 续行：UA 简称——须精确匹配，免误中含 ua 二字之列名
     OR LOWER(COLUMN_NAME) LIKE '%app_version%'                                                     -- 续行：应用版本
     OR LOWER(COLUMN_NAME) LIKE '%os_%'                                                             -- 续行：操作系统类
     OR COLUMN_COMMENT LIKE '%设备%'                                                                  -- 续行：中文候选起算——设备
     OR COLUMN_COMMENT LIKE '%终端%'                                                                  -- 续行：终端
     OR COLUMN_COMMENT LIKE '%客户端%'                                                                 -- 续行：客户端
     OR COLUMN_COMMENT LIKE '%浏览器%'                                                                 -- 续行：浏览器
     OR COLUMN_COMMENT LIKE '%指纹%'                                                                  -- 续行：指纹
     OR COLUMN_COMMENT LIKE '%机器码%'                                                                 -- 续行：机器码
     OR COLUMN_COMMENT LIKE '%型号%' )                                                                -- 续行：设备型号——并收束整个候选条件组
ORDER BY TABLE_NAME, ORDINAL_POSITION;                                                              -- 排序：按表名与列序位升序——逐表可读


/* ═══════════════════════════════════════════════════════════════════════════
   §TL-13 · 限额组字典搜寻：`101-mem015` 究竟是不是限红
   ---------------------------------------------------------------------------
   缘起：§TL-10 实测有一类字段形如 `101-mem015`（取值为逗号分隔整数串，
   如 `101-mem015:3,21=>3,4`），百家乐口径 310 条 · 241 名会员，形似产品级限额组 ID。
   若属限红，这是眼下最能改善准实验功效之一笔。
   ⚠ 但 §TL-09 已证 `mem015` = login_error。若因名称相同即读作限额，
   等于刚拆掉一个同名异义、转手又装回一个（与 bet41、bet14 同类之坑）。
   故须先找到**限额组字典表**（组 ID → 限额金额／层级），六层判据打通方可采信：
     物理列 → 数据字典 → 旧值/新值 → 业务含义 → 处置动作 → 处置节
   在此之前，此类一律标注 PENDING_BUSINESS_DICTIONARY，既不入处置组、
   也不当作「无处置」。
   读法：找出候选表后，须验证 §TL-10 中出现过的组 ID（如 3、4、21、350）
   确在该表主键内，且其限额金额可比大小——能比大小，方能判孰紧孰松。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §TL-13 限额组字典搜寻，屏幕看结果。
SELECT  TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT                        -- 取列：起始取列子句，逐列列出表名、序位、列名、类型与列义
FROM    information_schema.columns                                                                  -- 取数来源：取自库内元数据字典（列级）
WHERE   TABLE_SCHEMA = 'ods_mariadb_2b'                                                             -- 过滤条件：限定本项目所用库
  AND ( LOWER(TABLE_NAME) LIKE '%limit%'                                                            -- 并列条件：表名候选起算——limit 类
     OR LOWER(TABLE_NAME) LIKE '%bet_level%'                                                        -- 续行：投注层级类
     OR LOWER(TABLE_NAME) LIKE '%betlimit%'                                                         -- 续行：投注限额连写
     OR LOWER(TABLE_NAME) LIKE '%odds_limit%'                                                       -- 续行：赔率限额类
     OR LOWER(TABLE_NAME) LIKE '%group%'                                                            -- 续行：分组类（限额组多以 group 命名）
     OR COLUMN_COMMENT LIKE '%限額%'                                                                  -- 续行：列义候选起算——繁体限额
     OR COLUMN_COMMENT LIKE '%限额%'                                                                  -- 续行：简体限额
     OR COLUMN_COMMENT LIKE '%限紅%'                                                                  -- 续行：繁体限红
     OR COLUMN_COMMENT LIKE '%限红%'                                                                  -- 续行：简体限红
     OR COLUMN_COMMENT LIKE '%注額上限%'                                                                -- 续行：注额上限
     OR COLUMN_COMMENT LIKE '%最高投注%'                                                                -- 续行：最高投注
     OR COLUMN_COMMENT LIKE '%最低投注%' )                                                              -- 续行：最低投注——并收束整个候选条件组
ORDER BY TABLE_NAME, ORDINAL_POSITION;                                                              -- 排序：按表名与列序位升序——逐表可读


/* ═══════════════════════════════════════════════════════════════════════════
   §TL-11c · 最终处置总体对账表：Raw → Event → Episode → Member 四级逐级核对
   ---------------------------------------------------------------------------
   缘起：同一批处置在不同口径下数出不同的数（原始片段／解析事件／处置节／唯一会员），
   四者并不矛盾，却极易被混作同一个「样本量」。外部审计（2026-08-11 二次红队第一条）
   要求此表**由 SQL 自动生成，不得手工填写**——本条即此。
   读法：逐级递减须解释得通。凡上下两级之差无法由本表的定义栏说明者，即有解析或口径缺陷。
   ⚠ 此表是**处置总体冻结**（Treatment Population Freeze）的前置凭据：
     四级对得上、且 semantic_status 与 censor_reason 皆无 UNKNOWN 之遗漏，方可冻结。
     冻结之前，PSM 与事件研究一律不得开跑。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：需要 —— 存为「数据库/TL11c_population_reconcile.csv」（§TL-11c 处置总体四级对账）。
WITH ev AS (                                                                                        -- 公共表表达式：开启中间结果集 ev——与 §TL-11 同源同窗（§TL-11c）
    SELECT  CAST(lmc02 AS STRING) AS member_id, CAST(lmc05 AS STRING) AS content                    -- 取值表达式：取用 lmc02（被改会员号）与 lmc05（变更内容串）
    FROM    ods_mariadb_2b.ods_a168_log_mem_change                                                  -- 取数来源：取自会员变更日志表
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
      AND   CAST(lmc04 AS STRING) IN ('edit', 'changestatus')                                       -- 并列条件：只留配置修改与状态变更两类
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11c）
pieces AS (                                                                                         -- 公共表表达式：开启中间结果集 pieces——第一级：原始片段（§TL-11c）
    SELECT  e.member_id, TRIM(s.piece) AS piece                                                     -- 取值表达式：逐段去空白，产出「piece」
    FROM ev e, unnest(split(e.content, ';')) AS s(piece)                                            -- 行展开：以 unnest(split(…)) 把分号分隔的多段逐段成行
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11c）
enf AS (                                                                                            -- 公共表表达式：开启中间结果集 enf——第二级：已确认处置的解析事件（§TL-11c）
    SELECT  member_id, piece,                                                                       -- 取列：起始取列子句，本行先列 member_id, piece
            CASE WHEN TRIM(SPLIT_PART(piece, '=>', 2)) IN ('N','0') THEN 'TIGHTEN'                  -- 取值表达式：方向判定起算——新值 N／0 为收紧
                 WHEN TRIM(SPLIT_PART(piece, '=>', 2)) IN ('Y','1') THEN 'RELEASE'                  -- 续行：新值 Y／1 为解除
                 ELSE 'OTHER' END                          AS direction                             -- 续行：产出「direction」
    FROM    pieces                                                                                  -- 取数来源：取自本条自建的中间结果集 pieces
    WHERE   piece LIKE '%=>%'                                                                       -- 过滤条件：须含箭头方为有效变更段
      AND ( piece LIKE 'mem016%' OR piece LIKE 'mem017%' )                                          -- 并列条件：只认语义已确认的两枚处置字段（mem015 已证非处置，封案）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§TL-11c）
bl AS (                                                                                             -- 公共表表达式：开启中间结果集 bl——本方案口径的百家乐投注会员名单（§TL-11c）
    SELECT  DISTINCT CAST(bet05 AS STRING) AS member_id                                             -- 取值表达式：取用 bet05（会员号）去重，产出「member_id」
    FROM    ods_mariadb_2b.ods_a168_bet02                                                           -- 取数来源：取自注单明细表
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定 E1 全局窗，涉 dt（营业日）
      AND   CAST(bet02 AS STRING) = '101'                                                           -- 并列条件：限定百家乐产品大类，涉 bet02（游戏类别）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§TL-11c）
SELECT  1 AS lvl, '① 原始片段（raw mutation pieces）' AS level_name,                                      -- 取值表达式：第一级序号与名称，产出「lvl」「level_name」
        COUNT(*) AS n_all,                                                                          -- 计数表达式：全体计数，产出「n_all」
        SUM(CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END) AS n_baccarat,                        -- 聚合：其中百家乐会员之计数，产出「n_baccarat」
        COUNT(DISTINCT p.member_id) AS n_member_all,                                                -- 计数表达式：涉及会员数（去重），产出「n_member_all」
        COUNT(DISTINCT CASE WHEN bl.member_id IS NOT NULL THEN p.member_id END) AS n_member_bac,    -- 计数表达式：其中百家乐会员数，产出「n_member_bac」
        '变更日志 content 按分号拆开后的每一段' AS definition                                                     -- 取值表达式：本级定义，产出「definition」——逐级递减须由定义解释得通
FROM        pieces p                                                                                -- 取数来源：取自本条自建的中间结果集 pieces
LEFT JOIN   bl ON bl.member_id = p.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
UNION ALL                                                                                           -- 集合运算：纵向拼接下一级
SELECT  2, '② 处置事件（enforcement events）',                                                            -- 取值表达式：第二级序号与名称
        COUNT(*),                                                                                   -- 计数表达式：全体计数
        SUM(CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END),                                      -- 聚合：其中百家乐会员之计数
        COUNT(DISTINCT e.member_id),                                                                -- 计数表达式：涉及会员数（去重）
        COUNT(DISTINCT CASE WHEN bl.member_id IS NOT NULL THEN e.member_id END),                    -- 计数表达式：其中百家乐会员数
        '解析成功且语义经字典确认为处置者（mem016／mem017），含收紧与解除两向'                                                  -- 取值表达式：本级定义
FROM        enf e                                                                                   -- 取数来源：取自本条自建的中间结果集 enf
LEFT JOIN   bl ON bl.member_id = e.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
UNION ALL                                                                                           -- 集合运算：纵向拼接下一级
SELECT  3, '③ 收紧事件（episode starts）',                                                                -- 取值表达式：第三级序号与名称
        COUNT(*),                                                                                   -- 计数表达式：全体计数
        SUM(CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END),                                      -- 聚合：其中百家乐会员之计数
        COUNT(DISTINCT e.member_id),                                                                -- 计数表达式：涉及会员数（去重）
        COUNT(DISTINCT CASE WHEN bl.member_id IS NOT NULL THEN e.member_id END),                    -- 计数表达式：其中百家乐会员数——★ 此即处置节口径的唯一处置会员数
        '处置事件中方向为收紧者；每一条起一个处置节，故其数即处置节数'                                                            -- 取值表达式：本级定义
FROM        enf e                                                                                   -- 取数来源：取自本条自建的中间结果集 enf
LEFT JOIN   bl ON bl.member_id = e.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
WHERE   e.direction = 'TIGHTEN'                                                                     -- 过滤条件：只留收紧方向
UNION ALL                                                                                           -- 集合运算：纵向拼接下一级
SELECT  4, '④ 解除事件（episode ends）',                                                                  -- 取值表达式：第四级序号与名称
        COUNT(*),                                                                                   -- 计数表达式：全体计数
        SUM(CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END),                                      -- 聚合：其中百家乐会员之计数
        COUNT(DISTINCT e.member_id),                                                                -- 计数表达式：涉及会员数（去重）
        COUNT(DISTINCT CASE WHEN bl.member_id IS NOT NULL THEN e.member_id END),                    -- 计数表达式：其中百家乐会员数
        '处置事件中方向为解除者；未必与收紧一一对应，故删失由此而生'                                                             -- 取值表达式：本级定义
FROM        enf e                                                                                   -- 取数来源：取自本条自建的中间结果集 enf
LEFT JOIN   bl ON bl.member_id = e.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
WHERE   e.direction = 'RELEASE'                                                                     -- 过滤条件：只留解除方向
UNION ALL                                                                                           -- 集合运算：纵向拼接下一级
SELECT  5, '⑤ 左截断：只见解除而未见收紧之会员',                                                                    -- 取值表达式：第五级——★ 2026-08-11 增，解释 ④ 多于 ③ 之差
        0, 0,                                                                                       -- 计数表达式：本级只计会员，条数置零以免与事件级混淆
        COUNT(DISTINCT r.member_id),                                                                -- 计数表达式：全体——其收紧发生于窗口之前，本窗只见尾巴
        COUNT(DISTINCT CASE WHEN bl.member_id IS NOT NULL THEN r.member_id END),                    -- 计数表达式：其中百家乐会员数
        '窗内有解除而无收紧者：处置起于观察窗之前（左截断），无 T0 故不入处置节，亦不入 KM'                                              -- 取值表达式：本级定义——**须明写，否则 ④ 与 ③ 之差无从解释**
FROM        ( SELECT DISTINCT member_id FROM enf WHERE direction = 'RELEASE' ) r                    -- 取数来源：解除方会员集合
LEFT JOIN   ( SELECT DISTINCT member_id FROM enf WHERE direction = 'TIGHTEN' ) t                    -- 左连接：收紧方会员集合
       ON   t.member_id = r.member_id                                                               -- 连接键：同一会员
LEFT JOIN   bl ON bl.member_id = r.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
WHERE   t.member_id IS NULL                                                                         -- 过滤条件：只留在收紧集合中查无此人者——即左截断
UNION ALL                                                                                           -- 集合运算：纵向拼接下一级
SELECT  6, '⑥ 语义待定：解析成功而列义未经字典确认',                                                                  -- 取值表达式：第六级——★ 2026-08-11 增，与 §TL-11b 的 semantic_status 对齐
        COUNT(*),                                                                                   -- 计数表达式：全体计数
        SUM(CASE WHEN bl.member_id IS NULL THEN 0 ELSE 1 END),                                      -- 聚合：其中百家乐会员之计数
        COUNT(DISTINCT q.member_id),                                                                -- 计数表达式：涉及会员数（去重）
        COUNT(DISTINCT CASE WHEN bl.member_id IS NOT NULL THEN q.member_id END),                    -- 计数表达式：其中百家乐会员数
        '含箭头而非 mem015／mem016／mem017 者，如 mem020 与 101-mem015——PENDING，不入处置总体'                        -- 取值表达式：本级定义
FROM        pieces q                                                                                -- 取数来源：取自本条自建的中间结果集 pieces
LEFT JOIN   bl ON bl.member_id = q.member_id                                                        -- 左连接：取自本条自建的中间结果集 bl，连接键为 member_id（会员号）
WHERE   q.piece LIKE '%=>%'                                                                         -- 过滤条件：须为有效变更段
  AND   q.piece NOT LIKE 'mem015%'                                                                  -- 并列条件：mem015 已封案（login_error），另计
  AND   q.piece NOT LIKE 'mem016%'                                                                  -- 并列条件：mem016 已确认为处置，另计
  AND   q.piece NOT LIKE 'mem017%'                                                                  -- 并列条件：mem017 已确认为处置，另计
ORDER BY lvl;                                                                                       -- 排序：按级序升序——逐级递减一目了然


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-17 · 字段语义锁定与数据质量门（2026-08-18 立，承 Probe-01／Probe-02）
   本条为纪律陈述，非查询。
   ▸ 导出：不需要 —— 纪律陈述，无结果集

   ─── 一、退水／洗码字段语义锁定（PROVEN · LOCKED）─────────────────────────
     证据一 P01E 恒等式双假设并列检验（窗口内百家乐 n = 125,654,711）：
       H16  bet17 = bet14 − bet13 + bet16 → 精确匹配 125,654,711／125,654,711
                                            ＝ 100.00000%，误差 P50/P95/P99/max 皆 0
       H41  bet17 = bet14 − bet13 + bet41 → 精确匹配   9,552,205／125,654,711
                                            ＝ 7.602%，误差 P50 50、P99 20,000、max 1e8
     证据二 P01D（n = 116,103,500）：bet41 ÷ validbet 之 p01＝p50＝p90＝p99 ＝ 1.000000
     证据三 P01B（n = 5,844,799，限 bet16≠0）：bet41 ÷ bet16 之
            min＝p01＝100、p50＝125、p99＝max＝333.33
            倒数即 1.00%／0.80%／0.30% —— 与既有登记之退水配置三档吻合

     ─ 窗口口径四格表（2026-08-18 补录，由 P01C 逐月合计反推；A 段实测另出 P01A）─
       ⚠ 口径警示：以下为**窗口内百家乐**（dt ∈ [2026-03-21, 2026-08-07)、bet02='101'）
         之读数，n = 125,654,711。首跑 A 段曾扫全表 205,874,217 行（含非百家乐、
         含窗口外），两者**不可混用**；本包一律以窗口口径为准。
         对照：bet16 非零率 窗口 4.65% vs 全表 4.32%；
               bet41 非零率 窗口 92.40% vs 全表 93.99%；
               相等率       窗口 7.60% vs 全表 6.01%。
       窗口读数： n_rows 125,654,711 ｜ bet16 非零 5,844,799（4.65%）
                  bet41 非零 116,102,506（92.40%）｜ bet41 零值 9,552,205
                  equal_n 9,552,205 ｜ unequal_n 116,102,506 ｜ 二者之和 = n_rows ✅
       契约判读一（equal_n ≡ bet41 零值数）：9,552,205 ≡ 9,552,205 ✅ 成立
         → 「相等 ⟺ 两者皆零」于窗口内亦成立，与全表口径同向。
       契约判读二（b16>0 且 b41=0 应为 0）：**须俟 P01A 实测方可判**，此处不可由合计反推。

     ─ 跨段一致性四问（四段独立算出，互为交叉验证）───────────────────────
       ① P01C 合计 n 125,654,711 ≡ P01E 之 n 125,654,711 ✅
       ② P01C 之 equal_n 9,552,205 ≡ P01E-H41 精确匹配数 9,552,205 ✅
          机理：bet41 = 0 时 H41 退化为 H16，故 H41 恰于该子集成立——
          两段各自独立计算而得同一数，属强互证，非巧合。
       ③ P01C 之 bet16 非零 5,844,799 ≡ P01B 之 n 5,844,799 ✅（P01B 限 bet16≠0）
       ④ P01E-H16 精确匹配 125,654,711 ≡ n 125,654,711 ✅（100.00000%）

     🔒 LOCK（今后一切退水率／NGR／返水覆盖率／会员退水资格计算一律遵此）：
        有效投注／洗码量 = ods_a168_bet02.bet41 ≡ validbet
        退水金额         = ods_a168_bet02.bet16
        退水率           = bet16 ÷ bet41
        ⚠ bet41 ≠ 退水金额 ； bet16 ≠ 洗码量 —— 二者今后不得互换。
     🟢 RESTORE：§E02c 以 bet02.bet41 作有效投注之用法**成立**，无须斧正。
     🟥 CORRECT：§P0C 原注释「bet02.bet41 = 下注退水金額」已证伪，
                 标 ODS_DICTIONARY_DEFECT，原文保留不删（ODS 字典本身即审计对象）。

   ─── 二、bet16 覆盖率之月度变化（OBSERVED · 禁作因果解释）───────────────
     P01C 实测逐月 bet16 非零率：
       2026-03 3.85% ｜ 04 4.03% ｜ 05 4.41% ｜ 06 5.38% ｜ 07 5.10% ｜ 08 4.73%
     同期 bet41 非零率恒定 92.34%～92.46%，相等率恒定 7.54%～7.66%。
     ✅ 可写：bet16 非零率存在明显月度变化，而同期 bet41 非零率基本稳定，
              故目前更支持「退水覆盖率／享退水会员结构发生变化」。
     ⛔ 不可写：「享退水会员占比增长」——除非另有会员资格字段或合同配置之直接证据。
              此属 OBSERVED → CAUSAL STORY 之偷渡，本包明令禁止。
     🟡 另观察（OBSERVED，暂不升格）：退水覆盖率于边注玩法显著较高——
        BankerNatural 9.17%、BankerDragonBonus 8.99%、Small 8.86%、
        Super6 6.54%、Lucky7 6.39%；主注庄闲较低。成因未验。

   ─── 三、DQ-COMMISSION 数据质量门（REGISTER · 强制）─────────────────────
     字典载 commission ∈ {0 一般, 1 免佣}。P01C 实测另见六个域外取值：
       −999(1 行) ｜ −100(8) ｜ −1(8) ｜ 2(8) ｜ 100(3) ｜ 999(3) —— 合计 31 行。
     🔒 定义：commission ∈ {0,1} → VALID ； commission ∉ {0,1} → ANOMALY
     🔒 纪律：**不得删除该 31 行**（清洗即抹去异常证据）。
              凡按 commission 分层之分析，一律须报告四数：
                n_total ｜ n_valid ｜ n_anomaly ｜ anomaly_rate
              未报此四数者，不得宣称结果覆盖完整数据。

   ─── 四、TREATMENT DEFINITION STATUS（承 Probe-02，四级分立）───────────
     ⚠ 本表为**防偷渡设施**：下游任何文档不得因某一级 CLOSED 而推断上级已解。
       S1 · ENTITY JOIN      lmc02 → member_id ； lmc03 = 7 为会员    STATUS = CLOSED
       S2 · EVENT SEMANTICS  lmc05 文本 → 字段级变更                  STATUS = PARTIALLY CLOSED
       S3 · TREATMENT MAPPING 风控字段 → treatment 类别               STATUS = OPEN
       S4 · OUTCOME LINKAGE  treatment → 后续投注行为                 STATUS = OPEN
     ⛔ **「lmc02 接线键已解」≠「treatment 已解」。**
        S3／S4 未闭前，禁入 HMM、禁入处置效应估计、禁入任何因果分析。

   ─── 五、Probe-02 已证事实（PROVEN）与未决项 ───────────────────────────
     PROVEN：
       · lmc04 仅三类：edit 499,494 ｜ add 107,796 ｜ changestatus 79,493（合 686,783）
       · lmc02 为实体 ID 而非日志主键（去重 168,227 ≪ 686,783）；lmc03=7 为会员
       · **mem016／mem017 存于 lmc05 之变更内容文本，非本表之列**
         （本表列为 lmc01～lmc11）。此前记载「台账覆盖 mem016／mem017」
         语义成立，惟未说明其为文本而非列，属**表述不精确**，此处补正。
       · mem015 为三态限額值（2=>0 18,865 ｜ 0=>1 12,877 ｜ 1=>0 9,893），非布尔开关
       · changestatus 49 种前缀可全归并为九组字段组合：
         mem015+mem017 41,601 ｜ mem016 12,797 ｜ age016 10,773 ｜ age015 7,506 ｜
         mem020 6,592 ｜ mem017 单发 179 ｜ cash+mem015+mem017 34 ｜ chkLock 9 ｜ mem015 1
     OBSERVED：
       · 窗口内（2026-03-21～08-07）会员级 changestatus 1,490 行／294 会员；
         edit 3,398 行／1,084 会员；add 0 行
       · lmc02 脏值：层级5 有 14,679 行 lmc02=0（15.0%）；层级7 有 7,935 行（1.5%）
       · 日志会员 118,265 名中，窗口内有百家乐注单者仅 990 名
     STRONGLY SUPPORTED：
       · **edit 类别亦含风控处置**（样本见 mem012:999999 最大可贏金額、
         mem014:999999 最大可輸金額、101-mem015:21=>4 分桌限額调整）。
       🔒 由是立 Step-02 第一原则：
          **lmc04 是日志操作类型，不是 treatment taxonomy。**
          treatment 须按**字段**定义（mem012／mem014／mem015／mem016／mem017…），
          不得按 lmc04 类别定义。

   ─── 六、两项挂账（不得因数量小而当噪音）──────────────────────────────
     【LEGACY-532】旧记载「532 次风控处置事件、188 名百家乐成员」
        LEGACY CLAIM      532 events ／ 188 members
        CURRENT PROBE     1,490 changestatus rows ／ 294 members（窗口内层级7）
        STATUS            CONFLICTING COUNTS
        legacy definition = UNKNOWN ； current extraction definition = OBSERVED
        reconciliation    = OPEN
        ⛔ 厘清之前，正文引用「532 ／ 188」一律不得继续作为事实使用。
        ⚠ 此属典型**分母／筛选口径漂移**，不得凭数字大小判断孰对。
     【ANOM-mem020】mem020 之 6,592 次变更
        事实：100% Y=>N ｜ 0% N=>Y ｜ **仅涉 1 个实体**
        裁定：ANOMALY / INVESTIGATION REQUIRED
        ⛔ 目前不得写作「系统 Bug」「脚本产物」「某真实风控策略」——三者皆属 HYPOTHESIS。
   ═══════════════════════════════════════════════════════════════════════════ */

/* ═══════════════════════════════════════════════════════════════════════
   §Z-18 · bet16 ↔ bet41 关系实证（原 Probe-01；2026-08-18 已跑毕，🔒 CLOSED）
   ▸ 裁定结论已固化于 §Z-17 之一；本条存档以备复算，结论不得再由本条重新开启。
   ▸ 导出：需要 —— A/B/C/D/E 五段各存一档（P01A／P01B／P01C／P01D／P01E）
   ▸ 修正缘由：v1 三段报「Unable to parse SQL」，根因为 quantileExact(p)(x)
     系 ClickHouse 双调用语法，StarRocks 无此函数。改用 PERCENTILE_APPROX(x, p)。
     另 v1 段 A 未加窗口与产品过滤，扫全表 205,874,217 行（含非百家乐、含窗口外），
     本版一律补齐 dt 窗口与 bet02='101'，与全项目口径对齐。
   ▸ 判读纪律：只观察、不修复；不预设 bet41 = validbet × 退水率；
     恒等式采双假设并列检验，禁止先写死其一。
   ═══════════════════════════════════════════════════════════════════════ */

-- ── A · 基础交叉计数（四格表）★ 2026-08-18 补录 ─────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01A_crosstab.csv」
-- ▸ 补录缘由：首跑之 A 段**未加窗口与产品过滤**，扫全表 205,874,217 行
--   （含非百家乐、含 2026-08-07 之后），其读数与本包窗口口径不可比，
--   故 §Z-17 未引用之，亦不得事后塞回冒充窗口结果。本段补齐过滤重取。
-- ▸ 首跑（全表口径）读数存录以备对照，**不得作为窗口结论使用**：
--     n_rows 205,874,217 ｜ bet16 非零 8,883,777（4.32%）｜ bet41 非零 193,493,997（93.99%）
--     equal 12,380,220 ｜ unequal 193,493,997
--     四格：两者皆零 12,380,220 ｜ b16=0&b41>0 184,610,220 ｜ 皆非零 8,883,777 ｜ b16>0&b41=0 0
-- ▸ 判读契约（先写死）：
--     · equal_n 应恒等于 both_zero_n → 若成立，则「相等 ⟺ 两者皆零」于窗口内亦成立；
--     · b16pos_b41zero_n 应为 0 → 若非 0，则「bet16 为 bet41 之派生」之说立即动摇；
--     · 四格之和须等于 n_rows，且与 §Z-18 之 C 段逐月合计一致。
SELECT COUNT(*)                                                          AS n_rows,
       SUM(CASE WHEN b16 IS NULL THEN 1 ELSE 0 END)                      AS bet16_null,
       SUM(CASE WHEN b16 =  0    THEN 1 ELSE 0 END)                      AS bet16_zero,
       SUM(CASE WHEN b16 <> 0    THEN 1 ELSE 0 END)                      AS bet16_nonzero,
       SUM(CASE WHEN b41 IS NULL THEN 1 ELSE 0 END)                      AS bet41_null,
       SUM(CASE WHEN b41 =  0    THEN 1 ELSE 0 END)                      AS bet41_zero,
       SUM(CASE WHEN b41 <> 0    THEN 1 ELSE 0 END)                      AS bet41_nonzero,
       SUM(CASE WHEN b16 IS NOT NULL AND b41 IS NOT NULL AND b16 =  b41
                THEN 1 ELSE 0 END)                                       AS equal_n,
       SUM(CASE WHEN b16 IS NOT NULL AND b41 IS NOT NULL AND b16 <> b41
                THEN 1 ELSE 0 END)                                       AS unequal_n,
       SUM(CASE WHEN b16 = 0 AND b41 = 0 THEN 1 ELSE 0 END)              AS both_zero_n,
       SUM(CASE WHEN b16 = 0 AND b41 <> 0 THEN 1 ELSE 0 END)             AS b16zero_b41pos_n,
       SUM(CASE WHEN b16 <> 0 AND b41 <> 0 THEN 1 ELSE 0 END)            AS both_pos_n,
       SUM(CASE WHEN b16 <> 0 AND b41 = 0 THEN 1 ELSE 0 END)             AS b16pos_b41zero_n
FROM (
  SELECT CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t;

-- ── B · 差额与比例分布（限本项目窗口与产品）──────────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01B_diff_ratio.csv」
SELECT COUNT(*)                                                        AS n,
       MIN(b16 - b41)                                                  AS diff_min,
       PERCENTILE_APPROX(b16 - b41, 0.50)                              AS diff_p50,
       PERCENTILE_APPROX(b16 - b41, 0.90)                              AS diff_p90,
       PERCENTILE_APPROX(b16 - b41, 0.99)                              AS diff_p99,
       MAX(b16 - b41)                                                  AS diff_max,
       MIN(b41 / NULLIF(b16, 0))                                       AS ratio_min,
       PERCENTILE_APPROX(b41 / NULLIF(b16, 0), 0.01)                   AS ratio_p01,
       PERCENTILE_APPROX(b41 / NULLIF(b16, 0), 0.50)                   AS ratio_p50,
       PERCENTILE_APPROX(b41 / NULLIF(b16, 0), 0.99)                   AS ratio_p99,
       MAX(b41 / NULLIF(b16, 0))                                       AS ratio_max
FROM (
  SELECT CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE b16 IS NOT NULL AND b41 IS NOT NULL AND b16 <> 0;


-- ── C · 分叉点定位：月份 × 玩法 × 免佣 × 币别 ────────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01C_split_by_dim.csv」
-- ▸ 月份必留：本条查的不只是字段语义，更是【语义是否发生过版本切换】。
SELECT DATE_TRUNC('month', dt)                                          AS ym,
       TRIM(bet09)                                                      AS bet09,
       TRIM(commission)                                                 AS commission,
       TRIM(bet10)                                                      AS bet10,
       COUNT(*)                                                         AS n,
       SUM(CASE WHEN b16 =  b41 THEN 1 ELSE 0 END)                      AS equal_n,
       SUM(CASE WHEN b16 <> b41 THEN 1 ELSE 0 END)                      AS unequal_n,
       SUM(CASE WHEN b16 <> 0 THEN 1 ELSE 0 END)                        AS b16_nonzero_n,
       SUM(CASE WHEN b41 <> 0 THEN 1 ELSE 0 END)                        AS b41_nonzero_n,
       AVG(b16)                                                         AS avg_b16,
       AVG(b41)                                                         AS avg_b41,
       AVG(b16 - b41)                                                   AS avg_diff,
       PERCENTILE_APPROX(b16, 0.50)                                     AS p50_b16,
       PERCENTILE_APPROX(b41, 0.50)                                     AS p50_b41
FROM (
  SELECT dt, bet09, commission, bet10,
         CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE b16 IS NOT NULL AND b41 IS NOT NULL
GROUP BY DATE_TRUNC('month', dt), TRIM(bet09), TRIM(commission), TRIM(bet10)
ORDER BY ym, bet09, commission, bet10;


-- ── D · 与 validbet 之关系（不预设公式，只看分布）────────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P01D_vs_validbet.csv」
SELECT COUNT(*)                                                         AS n,
       SUM(CASE WHEN vb IS NOT NULL AND b41 IS NOT NULL THEN 1 ELSE 0 END)      AS comparable_n,
       SUM(CASE WHEN vb <> 0 AND b41 / vb BETWEEN 0 AND 1 THEN 1 ELSE 0 END)    AS plausible_n,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.01)                     AS r41_p01,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.50)                     AS r41_p50,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.90)                     AS r41_p90,
       PERCENTILE_APPROX(b41 / NULLIF(vb, 0), 0.99)                     AS r41_p99,
       PERCENTILE_APPROX(b16 / NULLIF(vb, 0), 0.50)                     AS r16_p50,
       PERCENTILE_APPROX(b16 / NULLIF(vb, 0), 0.99)                     AS r16_p99
FROM (
  SELECT CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4)) AS vb,
         CAST(NULLIF(TRIM(bet16),'')    AS DECIMAL(20,4)) AS b16,
         CAST(NULLIF(TRIM(bet41),'')    AS DECIMAL(20,4)) AS b41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE vb IS NOT NULL AND b41 IS NOT NULL AND vb <> 0;


-- ── E · 恒等式双假设并列检验（H16 vs H41，谁能闭合由数据裁定）────────────
-- ▸ 导出：需要 —— 存为「数据库/P01E_identity_test.csv」
SELECT 'H16: bet17 = bet14 - bet13 + bet16'                             AS hypothesis,
       COUNT(*)                                                         AS n,
       SUM(CASE WHEN e16 = 0 THEN 1 ELSE 0 END)                         AS exact_match_n,
       SUM(CASE WHEN e16 = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)        AS exact_match_rate,
       PERCENTILE_APPROX(ABS(e16), 0.50)                                AS abs_err_p50,
       PERCENTILE_APPROX(ABS(e16), 0.95)                                AS abs_err_p95,
       PERCENTILE_APPROX(ABS(e16), 0.99)                                AS abs_err_p99,
       MAX(ABS(e16))                                                    AS abs_err_max
FROM (
  SELECT (CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)))
       - (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))
        - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        + CAST(NULLIF(TRIM(bet16),'') AS DECIMAL(20,4)))                AS e16
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE e16 IS NOT NULL
UNION ALL
SELECT 'H41: bet17 = bet14 - bet13 + bet41'                             AS hypothesis,
       COUNT(*)                                                         AS n,
       SUM(CASE WHEN e41 = 0 THEN 1 ELSE 0 END)                         AS exact_match_n,
       SUM(CASE WHEN e41 = 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*)        AS exact_match_rate,
       PERCENTILE_APPROX(ABS(e41), 0.50)                                AS abs_err_p50,
       PERCENTILE_APPROX(ABS(e41), 0.95)                                AS abs_err_p95,
       PERCENTILE_APPROX(ABS(e41), 0.99)                                AS abs_err_p99,
       MAX(ABS(e41))                                                    AS abs_err_max
FROM (
  SELECT (CAST(NULLIF(TRIM(bet17),'') AS DECIMAL(20,4)))
       - (CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4))
        - CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4))
        + CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)))                AS e41
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) t
WHERE e41 IS NOT NULL
ORDER BY hypothesis;


/* ═══════════════════════════════════════════════════════════════════════
   §Z-19 · 处置事件来源 · Step-01（原 Probe-02；2026-08-18 已跑毕）
   ▸ 状态：S1 接线键 🔒 CLOSED ； **Probe-02 总命题 ⏳ OPEN**
   ▸ ⛔ 防偷渡：下游任何文档不得因 S1 已闭而书作「Probe-02 已验证」或
        「treatment 已定义」。四级状态以 §Z-17 之四为准，本条不得单独引用。
   ▸ 首跑已得：lmc04 仅三类 —— edit 499,494 / add 107,796 / changestatus 79,493
              合计 686,783，与 COUNT(*) 相符；
              lmc02 去重 168,227 ≪ 686,783 → lmc02 非日志主键，系实体 ID；
              lmc03 去重 7 → 层级码（样本中 7=会员、1~5=代理级）。
   ▸ 首跑缺口：LIMIT 1000 配 ORDER BY lmc04 只取到字典序最前之 'add'，
              **风控处置最可能所在之 changestatus 一条样本都没看到**。
              本版改为逐类别定额取样，杜绝此偏。
   ▸ 纪律：只观察、不翻译、不分类、不命名 treatment。
           OBSERVED 原文 ≠ 业务解释 ≠ treatment，三层不得跨级。
   ═══════════════════════════════════════════════════════════════════════ */

-- ── A · 逐类别定额取样（每类各取最早 200 与最新 200，可复现，非随机）──────
-- ▸ 导出：需要 —— 存为「数据库/P02A_lmc_samples.csv」
WITH r AS (
  SELECT lmc04, lmc05, lmc02, lmc03, lmc06, lmc07, lmc08, lmc10,
         ROW_NUMBER() OVER (PARTITION BY lmc04 ORDER BY lmc08 ASC,  lmc02 ASC) AS rn_old,
         ROW_NUMBER() OVER (PARTITION BY lmc04 ORDER BY lmc08 DESC, lmc02 DESC) AS rn_new
  FROM ods_mariadb_2b.ods_a168_log_mem_change
)
SELECT lmc04 AS 类别, '最早' AS 取样端, lmc08 AS 異動時間, lmc02 AS 实体ID, lmc03 AS 层级,
       lmc06 AS 操作者, lmc07 AS 操作者LV, lmc10 AS 操作IP, lmc05 AS 内容原文
FROM r WHERE rn_old <= 200
UNION ALL
SELECT lmc04, '最新', lmc08, lmc02, lmc03, lmc06, lmc07, lmc10, lmc05
FROM r WHERE rn_new <= 200
ORDER BY 类别, 取样端, 異動時間;


-- ── B · changestatus 专项：内容原文枚举（处置最可能所在）────────────────
-- ▸ 导出：需要 —— 存为「数据库/P02B_changestatus_patterns.csv」
-- ▸ 只做「原文前缀归并」以见其形，不做语义分类。
SELECT SUBSTRING(TRIM(lmc05), 1, 40)                                    AS 内容前40字,
       COUNT(*)                                                         AS n,
       COUNT(DISTINCT lmc02)                                            AS 涉实体数,
       MIN(lmc08)                                                       AS 最早,
       MAX(lmc08)                                                       AS 最晚,
       SUM(CASE WHEN lmc03 = '7' THEN 1 ELSE 0 END)                     AS 其中层级7数
FROM ods_mariadb_2b.ods_a168_log_mem_change
WHERE lmc04 = 'changestatus'
GROUP BY SUBSTRING(TRIM(lmc05), 1, 40)
ORDER BY n DESC;


-- ── C · lmc02 接线键验证（S1 前置：接错键则 treatment 全错）──────────────
-- ▸ 导出：需要 —— 存为「数据库/P02C_key_check.csv」
-- ▸ 三问：① lmc03 与 lmc02 是否一一对应实体类型？
--         ② lmc02=0 之脏值有多少？③ 层级7 之 lmc02 能否命中注单表会员号？
SELECT l.lmc03                                                          AS 层级,
       COUNT(*)                                                         AS 日志行数,
       COUNT(DISTINCT l.lmc02)                                          AS 去重实体数,
       SUM(CASE WHEN TRIM(l.lmc02) = '0' THEN 1 ELSE 0 END)             AS 实体ID为0之脏行,
       SUM(CASE WHEN m.member_id IS NOT NULL THEN 1 ELSE 0 END)         AS 命中注单会员数,
       COUNT(DISTINCT CASE WHEN m.member_id IS NOT NULL
                           THEN l.lmc02 END)                            AS 命中去重实体数,
       MIN(l.lmc08)                                                     AS 最早,
       MAX(l.lmc08)                                                     AS 最晚
FROM ods_mariadb_2b.ods_a168_log_mem_change l
LEFT JOIN (
  SELECT DISTINCT CAST(NULLIF(TRIM(bet05),'') AS BIGINT) AS member_id
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
) m ON m.member_id = CAST(NULLIF(TRIM(l.lmc02),'') AS BIGINT)
GROUP BY l.lmc03
ORDER BY l.lmc03;


-- ── D · 窗口内事件量（决定 treatment 是否有足够样本）────────────────────
-- ▸ 导出：需要 —— 存为「数据库/P02D_events_in_window.csv」
SELECT lmc04                                                            AS 类别,
       lmc03                                                            AS 层级,
       COUNT(*)                                                         AS 窗口内行数,
       COUNT(DISTINCT lmc02)                                            AS 涉实体数
FROM ods_mariadb_2b.ods_a168_log_mem_change
WHERE CAST(NULLIF(TRIM(lmc08),'') AS DATETIME) >= '2026-03-21 00:00:00'
  AND CAST(NULLIF(TRIM(lmc08),'') AS DATETIME) <  '2026-08-07 00:00:00'
GROUP BY lmc04, lmc03
ORDER BY 类别, 层级;

/* ═══════════════════════════════════════════════════════════════════════
   §P11 · 尾段两域交付件族（评估线四件 · 2026-08-20 v6 归宗）

   ▸ 血统：原文寄居于评估档《尾段投注基础分析的评估》（其 v1.2.13 现载
     eval=FALSE 之文档态展示），今逐字归宗本包——本包自此为其唯一权威出处，
     评估档内同文降为「引用展示」。
   ▸ 导出文件名铁律：四件 CSV 已被评估档载入器以下列中文名硬约（.pp 路径
     契约），且用户端既有实档在身——故**文件名保持原样不英译**，改名即断
     载入契约、失六元组对帐锚。P12 族因尚未执行，方可英名（见 §P12）。
   ▸ 口径：CTE test_agents/ranked/base 逐字沿用 §R01；雷欧域＝base 上
     HAVING n>=100；阿泽域＝bet04>=40 ∧ late_ratio>=0.60 ∧ n>=30（对照用，
     DEPRECATED，禁作生产风控）。
   ═══════════════════════════════════════════════════════════════════════ */

-- ─────────────────────────────────────────────────────────────────────────
-- §P11a · 阿泽（洗码口径）会员名单
-- ▸ 导出：需要 —— 存为「数据库/P11_阿泽尾段投注模型会员名单.csv」（契约名，不英译）
-- ─────────────────────────────────────────────────────────────────────────
-- eval = FALSE
-- 阿泽（模型）：原码保持不变，仅加五闸
--   ① 最新注单版本（ROW_NUMBER 三级排序取 rn=1）
--   ② 排测试代理（五级 LEFT JOIN，age022='1'）
--   ③ category='1'
--   ④ UPPER(TRIM(bet38))='N'
--   ⑤ 窗口 2026-03-21 ~ 2026-08-06（原码已有，原样保留）
-- 未加者（不在所列五项之内，故不动）：bet05>0、bet11>0、bet04>0 数值守门
-- 聚合式、门槛 >=30、内筛 >=0.60、输出九列、ORDER BY 皆与原码逐字相同
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'
),
ranked AS (
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
           b.bet38, b.category, b.validbet,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.bet02 = '101'
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
),
gated AS (
    SELECT r.bet03, r.bet04, r.bet05, r.bet11, r.bet13, r.bet14, r.validbet
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
    WHERE r.rn = 1
      AND r.category = '1'
      AND UPPER(TRIM(r.bet38)) = 'N'
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,
                   t4.agent_id, t5.agent_id) IS NULL
),
player_stat AS (
    SELECT
        CAST(bet05 AS BIGINT) AS player_id,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN CAST(bet04 AS INT) >= 40 THEN 1 ELSE 0 END) AS late_orders,
        SUM(CASE WHEN CAST(bet14 AS DECIMAL(20,4))
                    > CAST(bet13 AS DECIMAL(20,4)) THEN 1 ELSE 0 END) AS win_orders,
        SUM((CAST(bet14 AS DECIMAL(20,4)) - CAST(bet13 AS DECIMAL(20,4)))
            / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)) AS profit,
        SUM(CAST(validbet AS DECIMAL(20,4))
            / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)) AS valid_bet
    FROM gated
    WHERE bet03 IS NOT NULL
      AND bet04 IS NOT NULL
      AND bet05 IS NOT NULL
    GROUP BY CAST(bet05 AS BIGINT)
)
SELECT player_id, total_orders, late_orders,
       ROUND(late_orders * 1.0 / total_orders, 4) AS late_ratio,
       win_orders,
       ROUND(win_orders * 1.0 / total_orders, 4) AS win_rate,
       ROUND(valid_bet, 2) AS valid_bet,
       ROUND(profit, 2)    AS profit,
       ROUND(profit / NULLIF(valid_bet, 0), 4) AS roi
FROM player_stat
WHERE total_orders >= 30
  AND late_orders * 1.0 / total_orders >= 0.60
ORDER BY roi DESC, profit DESC;

-- ─────────────────────────────────────────────────────────────────────────
-- §P11b · 雷欧（本金口径）会员名单（＝§R01 名单之同构，加行为扩展列）
-- ▸ 导出：需要 —— 存为「数据库/P11_雷欧尾段投注模型会员名单.csv」（契约名，不英译）
-- ─────────────────────────────────────────────────────────────────────────
-- ⚠ 去重指引（v8 勘正）：本件与卷二 §R01 系**同一语句**（v7 曾整段复制，
--   逐行比对差异为零，双名同体）。权威唯 §R01 一处——请执行 §R01，导出
--   「数据库/R01_late_shoe.csv」后**复制一份**另存契约名
--   「数据库/P11_雷欧尾段投注模型会员名单.csv」；两名同 MD5 即对帐锚。
--   本处不再承载 SQL，防同语句双处漂移。
-- ─────────────────────────────────────────────────────────────────────────
-- §P11c · 阿泽域与全量洁净两域十一项总帐
-- ▸ 导出：需要 —— 存为「数据库/P11_阿泽尾段投注总帐.csv」（契约名，不英译）
-- ─────────────────────────────────────────────────────────────────────────
-- eval = FALSE
-- P11 · 阿泽域（阿泽·洗码口径，曾用名模型一丙版）与全量洁净两域十一项总帐
-- ▸ 导出：需要 —— 存为「数据库/P11_阿泽尾段投注总帐.csv」
-- 读法：ratio_pct 列即「阿泽（占比）」＝ 阿泽域 ÷ 全量洁净；代理五级为 distinct，不可加
WITH test_agents AS (
    SELECT age001 AS agent_id
    FROM ods_mariadb_2b.ods_a168_agent
    WHERE age022 = '1'
),
ranked AS (
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet08, b.bet11, b.bet13, b.bet14,
           b.bet16, b.bet41, b.validbet,
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet38, b.category,
           ROW_NUMBER() OVER (
             PARTITION BY b.bet01
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
    FROM ods_mariadb_2b.ods_a168_bet02 b
    WHERE b.bet02 = '101'
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
),
gated AS (
    SELECT r.bet03, r.bet04, r.bet05, r.bet11, r.bet13, r.bet14,
           r.bet16, r.bet41, r.bet08, r.validbet,
           r.bet18 AS a1, r.bet19 AS a2, r.bet20 AS a3, r.bet21 AS a4, r.bet22 AS a5
    FROM ranked r
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
    WHERE r.rn = 1
      AND r.category = '1'
      AND UPPER(TRIM(r.bet38)) = 'N'
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,
                   t4.agent_id, t5.agent_id) IS NULL
),
aze_rows AS (
    SELECT CAST(bet05 AS BIGINT) AS pid,
           CAST(bet04 AS INT)    AS rno,
           a1, a2, a3, a4, a5,
           CAST(bet13 AS DECIMAL(20,4))
             / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)                     AS stake,
           CAST(validbet AS DECIMAL(20,4))
             / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)                     AS vb,
           (CAST(bet14 AS DECIMAL(20,4)) - CAST(bet13 AS DECIMAL(20,4)))
             / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)                     AS pnl,
           COALESCE(CAST(bet16 AS DECIMAL(20,4)), 0)
             / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)                     AS reb16,
           COALESCE(CAST(bet41 AS DECIMAL(20,4)), 0)
             / NULLIF(CAST(bet11 AS DECIMAL(20,4)), 0)                     AS reb41
    FROM gated
    WHERE bet03 IS NOT NULL
      AND bet04 IS NOT NULL
      AND bet05 IS NOT NULL
),
aze_members AS (
    SELECT pid
    FROM aze_rows
    GROUP BY pid
    HAVING COUNT(*) >= 30
       AND SUM(CASE WHEN rno >= 40 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.60
),
aze AS (
    SELECT '2_阿泽域（丙版五闸＋会员门槛）' AS scope_def,
           COUNT(*)                                   AS n_orders,
           COUNT(DISTINCT r.pid)                      AS n_members,
           COUNT(DISTINCT r.a1)                       AS n_lv1,
           COUNT(DISTINCT r.a2)                       AS n_lv2,
           COUNT(DISTINCT r.a3)                       AS n_lv3,
           COUNT(DISTINCT r.a4)                       AS n_lv4,
           COUNT(DISTINCT r.a5)                       AS n_lv5,
           SUM(r.stake)                               AS stake_sum,
           SUM(r.vb)                                  AS validbet_sum,
           -SUM(r.pnl)                                AS ggr_sum,
           SUM(r.reb16)                               AS rebate16_sum,
           SUM(r.reb41)                               AS rebate41_sum
    FROM aze_rows r
    JOIN aze_members m ON m.pid = r.pid
),
clean_rows AS (
    SELECT CAST(bet05 AS BIGINT) AS pid,
           a1, a2, a3, a4, a5,
           CAST(bet13 AS DECIMAL(20,4))
             / CAST(bet11 AS DECIMAL(20,8))                                AS stake,
           CAST(validbet AS DECIMAL(20,4))
             / CAST(bet11 AS DECIMAL(20,8))                                AS vb,
           (CAST(bet14 AS DECIMAL(20,4)) - CAST(bet13 AS DECIMAL(20,4)))
             / CAST(bet11 AS DECIMAL(20,8))                                AS pnl,
           COALESCE(CAST(bet16 AS DECIMAL(20,4)), 0)
             / CAST(bet11 AS DECIMAL(20,8))                                AS reb16,
           COALESCE(CAST(bet41 AS DECIMAL(20,4)), 0)
             / CAST(bet11 AS DECIMAL(20,8))                                AS reb41
    FROM gated
    WHERE CAST(NULLIF(TRIM(bet05), '') AS BIGINT) > 0
      AND CAST(NULLIF(TRIM(bet11), '') AS DECIMAL(20,8)) > 0
      AND CAST(NULLIF(TRIM(bet04), '') AS INT) > 0
      AND NULLIF(TRIM(bet08), '') IS NOT NULL
),
clean AS (
    SELECT '1_全量洁净（七闸）' AS scope_def,
           COUNT(*)                                   AS n_orders,
           COUNT(DISTINCT pid)                        AS n_members,
           COUNT(DISTINCT a1)                         AS n_lv1,
           COUNT(DISTINCT a2)                         AS n_lv2,
           COUNT(DISTINCT a3)                         AS n_lv3,
           COUNT(DISTINCT a4)                         AS n_lv4,
           COUNT(DISTINCT a5)                         AS n_lv5,
           SUM(stake)                                 AS stake_sum,
           SUM(vb)                                    AS validbet_sum,
           -SUM(pnl)                                  AS ggr_sum,
           SUM(reb16)                                 AS rebate16_sum,
           SUM(reb41)                                 AS rebate41_sum
    FROM clean_rows
),
both AS (
    SELECT * FROM clean
    UNION ALL
    SELECT * FROM aze
)
SELECT
    b.scope_def,
    b.n_orders,
    ROUND(b.n_orders   * 100.0 / c.n_orders,   4)                  AS n_orders_pct,
    b.n_members,
    ROUND(b.n_members  * 100.0 / c.n_members,  4)                  AS n_members_pct,
    b.n_lv1, b.n_lv2, b.n_lv3, b.n_lv4, b.n_lv5,
    ROUND(b.stake_sum, 2)                                          AS stake_sum,
    ROUND(b.stake_sum    * 100.0 / c.stake_sum, 4)                 AS stake_pct,
    ROUND(b.validbet_sum, 2)                                       AS validbet_sum,
    ROUND(b.validbet_sum * 100.0 / c.validbet_sum, 4)              AS validbet_pct,
    ROUND(b.ggr_sum, 2)                                            AS ggr_sum,
    ROUND(b.ggr_sum      * 100.0 / c.ggr_sum, 4)                   AS ggr_pct,
    ROUND(b.rebate16_sum, 2)                                       AS rebate16_sum,
    ROUND(b.rebate16_sum * 100.0 / NULLIF(c.rebate16_sum, 0), 4)   AS rebate16_pct,
    ROUND(b.rebate41_sum, 2)                                       AS rebate41_sum,
    ROUND(b.ggr_sum - b.rebate16_sum, 2)                           AS ngr_by16,
    ROUND((b.ggr_sum - b.rebate16_sum) * 100.0
          / NULLIF(c.ggr_sum - c.rebate16_sum, 0), 4)              AS ngr_by16_pct
FROM both b
CROSS JOIN clean c
ORDER BY b.scope_def;

-- ─────────────────────────────────────────────────────────────────────────
-- §P11d · 雷欧域（§R01 原准入）与全量洁净两域十一项总帐
-- ▸ 导出：需要 —— 存为「数据库/P11_雷欧尾段投注总帐.csv」（契约名，不英译）
-- ─────────────────────────────────────────────────────────────────────────
-- eval = FALSE

-- P11 · 雷欧域（§R01 原准入）与全量洁净两域十一项总帐
-- ▸ 导出：需要 —— 存为「数据库/P11_雷欧尾段投注总帐.csv」
-- 口径：CTE test_agents/ranked/base 逐字沿用 §R01 原文；雷欧域＝base 上 HAVING n>=100 之会员注单
--       全量洁净＝同一 base 全量（§R01 六闸，未施 bet08，实测其筛除量为零）
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
ranked AS (
  SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,
         b.bet16, b.bet41, b.validbet,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.bet38, b.bet39, b.category,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)        AS member_id,
         r.bet18 AS a1, r.bet19 AS a2, r.bet20 AS a3,
         r.bet21 AS a4, r.bet22 AS a5,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))            AS stake,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))            AS vb,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))            AS game_pnl,
         COALESCE(CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)), 0)
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))            AS reb16,
         COALESCE(CAST(NULLIF(TRIM(r.bet41),'') AS DECIMAL(20,4)), 0)
           / CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))            AS reb41
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
ryo_members AS (
  SELECT member_id
  FROM base
  GROUP BY member_id
  HAVING COUNT(*) >= 100
),
ryo AS (
  SELECT '2_雷欧域（§R01 原准入 ∧ n>=100）' AS scope_def,
         COUNT(*)                     AS n_orders,
         COUNT(DISTINCT b.member_id)  AS n_members,
         COUNT(DISTINCT b.a1) AS n_lv1, COUNT(DISTINCT b.a2) AS n_lv2,
         COUNT(DISTINCT b.a3) AS n_lv3, COUNT(DISTINCT b.a4) AS n_lv4,
         COUNT(DISTINCT b.a5) AS n_lv5,
         SUM(b.stake) AS stake_sum, SUM(b.vb) AS validbet_sum,
         -SUM(b.game_pnl) AS ggr_sum,
         SUM(b.reb16) AS rebate16_sum, SUM(b.reb41) AS rebate41_sum
  FROM base b
  JOIN ryo_members m ON m.member_id = b.member_id
),
clean AS (
  SELECT '1_全量洁净（§R01 六闸）' AS scope_def,
         COUNT(*)                   AS n_orders,
         COUNT(DISTINCT member_id)  AS n_members,
         COUNT(DISTINCT a1) AS n_lv1, COUNT(DISTINCT a2) AS n_lv2,
         COUNT(DISTINCT a3) AS n_lv3, COUNT(DISTINCT a4) AS n_lv4,
         COUNT(DISTINCT a5) AS n_lv5,
         SUM(stake) AS stake_sum, SUM(vb) AS validbet_sum,
         -SUM(game_pnl) AS ggr_sum,
         SUM(reb16) AS rebate16_sum, SUM(reb41) AS rebate41_sum
  FROM base
),
both AS (
  SELECT * FROM clean
  UNION ALL
  SELECT * FROM ryo
)
SELECT
  b.scope_def,
  b.n_orders,
  ROUND(b.n_orders     * 100.0 / c.n_orders,     4)                AS n_orders_pct,
  b.n_members,
  ROUND(b.n_members    * 100.0 / c.n_members,    4)                AS n_members_pct,
  b.n_lv1, b.n_lv2, b.n_lv3, b.n_lv4, b.n_lv5,
  ROUND(b.stake_sum, 2)                                            AS stake_sum,
  ROUND(b.stake_sum    * 100.0 / c.stake_sum,    4)                AS stake_pct,
  ROUND(b.validbet_sum, 2)                                         AS validbet_sum,
  ROUND(b.validbet_sum * 100.0 / c.validbet_sum, 4)                AS validbet_pct,
  ROUND(b.ggr_sum, 2)                                              AS ggr_sum,
  ROUND(b.ggr_sum      * 100.0 / c.ggr_sum,      4)                AS ggr_pct,
  ROUND(b.rebate16_sum, 2)                                         AS rebate16_sum,
  ROUND(b.rebate16_sum * 100.0 / NULLIF(c.rebate16_sum, 0), 4)     AS rebate16_pct,
  ROUND(b.rebate41_sum, 2)                                         AS rebate41_sum,
  ROUND(b.ggr_sum - b.rebate16_sum, 2)                             AS ngr_by16,
  ROUND((b.ggr_sum - b.rebate16_sum) * 100.0
        / NULLIF(c.ggr_sum - c.rebate16_sum, 0), 4)                AS ngr_by16_pct
FROM both b
CROSS JOIN clean c
ORDER BY b.scope_def;

/* ═══════════════════════════════════════════════════════════════════════
   §P12 · 序列与事件族（评估线待表清单四件 · 2026-08-20 v5 并入）

   ▸ 血统：评估档《尾段投注基础分析的评估_v1_2_13.qmd》待表清单所指四件；
     独立包「P12_序列与事件_SQL包_v1.sql」经审计后作废归宗——其 §P12b 曾以
     臆测列（mem_field/mem001）书写，今依本包 §TL-14 实证 schema（lmc02/
     lmc04/lmc05/lmc08）重写，此为归宗时之唯一实质修改，余三件仅体例换装。
   ▸ 七闸：test_agents/ranked/gated 逐字沿用评估档 P11 口径（三级排序去重、
     category='1'、bet38='N'、五级测试线剔除、键非空），与 §R01 同源。
   ▸ 用途：解锁 HMM/Regime（§P12a）、生存分析（§P12b）、MDD/Sortino/Sharpe
     （§P12c）、门禁 P0 真样本外资格（§P12d）。
   ═══════════════════════════════════════════════════════════════════════ */

/* ─────────────────────────────────────────────────────────────────────────
   §P12b-pre · content 段式目检（先于 §P12b 执行）
   ▸ 导出：不需要 —— 只看屏幕（目检 20 行；若需留档可另存「数据库/_P12b-pre.csv」，非交付件）
   ▸ 何以先行：mem016（enable）/mem017（canbet）于 lmc05 变更串中之段式
     UNKNOWN——§TL-14 既证限额段式为「101-mem015:旧=>新」，状态段式未证；
     先取 20 行目检，确认 LIKE 谓词后方跑 §P12b 全量。
   ───────────────────────────────────────────────────────────────────────── */
SELECT  CAST(lmc02 AS STRING)                AS member_id,                                          -- 取值表达式：取用 lmc02（被改会员号），产出「member_id」
        CAST(lmc04 AS STRING)                AS action,                                             -- 取值表达式：取用 lmc04（动作类别），产出「action」
        CAST(lmc05 AS STRING)                AS content,                                            -- 取值表达式：取用 lmc05（变更内容串），产出「content」——目检对象
        CAST(lmc08 AS STRING)                AS action_time                                         -- 取值表达式：取用 lmc08（操作时间），产出「action_time」
FROM    ods_mariadb_2b.ods_a168_log_mem_change                                                      -- 取数来源：取自会员变更日志表（与 §TL-14 同源）
WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                    -- 过滤条件：限定全局窗，涉 dt（营业日）
  AND   ( CAST(lmc05 AS STRING) LIKE '%mem016%'                                                     -- 并列条件：粗筛含 mem016（enable）之变更串
       OR CAST(lmc05 AS STRING) LIKE '%mem017%' )                                                   -- 并列条件：或含 mem017（canbet）之变更串
LIMIT 20;                                                                                           -- 行数上限：只看屏幕 20 行，目检段式后再定 §P12b 谓词

/* ─────────────────────────────────────────────────────────────────────────
   §P12a · 平台日度序列
   ▸ 导出：需要 —— 存为「数据库/P12a_platform_daily.csv」
   ▸ 粒度：dt × 1 行；139 行预期。用途：HMM/Regime 动态基线、监控带上游。
   ▸ 同族辨义：§D-03S 产出日度晚早段 ROI 差（五重检验输入），本件产出
     日度量能/结构/hold——同族不同构，并存互补，勿以一代一。
   ───────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents——公司测试线代理（§P12a）
    SELECT age001 AS agent_id                                                                       -- 取值表达式：取用 age001（代理号），产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：取自代理主档（五级代理线归属来源）
    WHERE age022 = '1'                                                                              -- 过滤条件：限定 age022 等于 '1'——测试线旗标（既证 214 条）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12a）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked——同注单号取最新版本（§P12a）
    SELECT b.bet01, b.bet03, b.bet04, b.bet05, b.bet11, b.bet13, b.bet14,                           -- 取列：起始取列子句，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                             -- 续行：接续取列，涉 bet18~22（五级代理线，缺一即孤儿率 78.17%）
           b.bet38, b.category, b.validbet, b.dt,                                                   -- 续行：接续取列，涉 bet38（测试标识）、validbet（洗码量）、dt（营业日）
           ROW_NUMBER() OVER (                                                                      -- 行号窗口表达式：以行号窗口去重，免出重复行
             PARTITION BY b.bet01                                                                   -- 窗口分区：按 b.bet01（注单号）分组开窗
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：三级排序取最新版本；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：限定百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：限定全局窗，右端开区间（2026-08-07 不含当日）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12a）
gated AS (                                                                                          -- 公共表表达式：开启中间结果集 gated——七闸清洗后洁净底集（§P12a）
    SELECT r.dt, r.bet03, r.bet04, r.bet05, r.bet11, r.bet13, r.bet14, r.validbet                   -- 取列：透传日度聚合所需八列
    FROM ranked r                                                                                   -- 取数来源：取自本条自建的中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左联结：一级代理线对测试名单
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左联结：二级代理线对测试名单
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左联结：三级代理线对测试名单
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左联结：四级代理线对测试名单
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左联结：五级代理线对测试名单（五级全联，单级孤儿率 78.17% 之教训）
    WHERE r.rn = 1                                                                                  -- 过滤条件：只留每注单最新版本
      AND r.category = '1'                                                                          -- 并列条件：一般单准入
      AND UPPER(TRIM(r.bet38)) = 'N'                                                                -- 并列条件：排重对单
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                           -- 并列条件：五级任一命中测试线即剔——
                   t4.agent_id, t5.agent_id) IS NULL                                                -- 续行：COALESCE 五级归并判空（§R03 家族缺此闸之勘误在案）
      AND r.bet03 IS NOT NULL AND r.bet04 IS NOT NULL AND r.bet05 IS NOT NULL                       -- 并列条件：三键非空（靴号/局号/会员号）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12a）
shoe_len AS (                                                                                       -- 公共表表达式：开启中间结果集 shoe_len——观测靴长（§P12a）
    SELECT bet03, MAX(CAST(bet04 AS INT)) AS max_round                                              -- 计数表达式：每靴最大局号为观测靴长（真靴长权威表 P0 未解前之既定代理）
    FROM gated                                                                                      -- 取数来源：取自本条自建的中间结果集 gated
    GROUP BY bet03                                                                                  -- 分组：按靴号汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12a）
day_flag AS (                                                                                       -- 公共表表达式：开启中间结果集 day_flag——逐单折原币并打晚段旗（§P12a）
    SELECT g.dt,                                                                                    -- 取列：透传营业日
           CAST(g.bet05 AS BIGINT) AS uid,                                                          -- 取值表达式：会员号铸型 BIGINT（varchar 全库之铁律）
           (CAST(g.bet14 AS DECIMAL(20,4)) - CAST(g.bet13 AS DECIMAL(20,4)))                        -- 取值表达式：派彩减本金为会员净盈亏——
             / NULLIF(CAST(g.bet11 AS DECIMAL(20,4)), 0) AS pnl,                                    -- 续行：除以 bet11（汇率）归原币，NULLIF 防除零，产出「pnl」
           CAST(g.bet13 AS DECIMAL(20,4))                                                           -- 取值表达式：bet13（下注金额）——
             / NULLIF(CAST(g.bet11 AS DECIMAL(20,4)), 0) AS stake,                                  -- 续行：归原币，产出「stake」
           CAST(g.validbet AS DECIMAL(20,4))                                                        -- 取值表达式：validbet（洗码量）——
             / NULLIF(CAST(g.bet11 AS DECIMAL(20,4)), 0) AS vb,                                     -- 续行：归原币，产出「vb」
           CASE WHEN CAST(g.bet04 AS INT) * 1.0                                                     -- 条件表达式：局号除观测靴长——
                     / NULLIF(s.max_round, 0) >= 0.80                                               -- 续行：相对靴位不小于 0.80 即晚段（与 §R01 口径锁全同）
                THEN 1 ELSE 0 END AS is_late                                                        -- 续行：产出「is_late」晚段旗
    FROM gated g                                                                                    -- 取数来源：取自本条自建的中间结果集 gated
    JOIN shoe_len s ON s.bet03 = g.bet03                                                            -- 内联结：逐单挂靴长
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§P12a）
SELECT dt,                                                                                          -- 取列：营业日为主键（139 行预期）
       COUNT(*)                                        AS n_orders,                                 -- 计数表达式：当日注单数，产出「n_orders」
       COUNT(DISTINCT uid)                             AS n_members,                                -- 计数表达式：当日活跃会员数，产出「n_members」
       ROUND(SUM(stake), 4)                            AS stake_sum,                                -- 聚合表达式：当日本金合计，产出「stake_sum」
       ROUND(SUM(vb), 4)                               AS validbet_sum,                             -- 聚合表达式：当日洗码合计，产出「validbet_sum」
       ROUND(-SUM(pnl), 4)                             AS ggr_sum,                                  -- 聚合表达式：会员净盈亏取负即平台 GGR，产出「ggr_sum」
       ROUND(SUM(CASE WHEN is_late = 1 THEN stake ELSE 0 END)                                       -- 聚合表达式：晚段本金——
             / NULLIF(SUM(stake), 0), 6)               AS late_stake_share,                         -- 续行：除全日本金，产出「late_stake_share」（结构维）
       ROUND(AVG(CASE WHEN is_late = 1 THEN stake END)                                              -- 聚合表达式：晚段均注——
             / NULLIF(AVG(CASE WHEN is_late = 0 THEN stake END), 0), 6)                             -- 续行：除早段均注，NULLIF 防除零——
                                                       AS stake_ramp_day,                          -- 续行：产出「stake_ramp_day」（行业监控「靴末模式突变」之日度量化）
       ROUND(-SUM(pnl) / NULLIF(SUM(stake), 0) * 100, 6) AS hold_pct                                -- 聚合表达式：GGR 除本金乘百，产出「hold_pct」（本金口径）
FROM day_flag                                                                                       -- 取数来源：取自本条自建的中间结果集 day_flag
GROUP BY dt                                                                                         -- 分组：按 dt 汇总
ORDER BY dt;                                                                                        -- 排序：按营业日升序；导出必带排序

/* ─────────────────────────────────────────────────────────────────────────
   §P12b · 会员事件表
   ▸ 导出：需要 —— 存为「数据库/P12b_member_events.csv」
   ▸ 粒度：uid × 1 行（洁净底集全体会员）。用途：Cox/KM 生存分析——
     标记时点与流失双问；右删失以窗口末界计（last_dt >= '2026-08-01' 即删失）。
   ▸ 勘误在案：独立包 v1 曾以臆测列 mem_field/mem001 书写 first_mark——
     本包 §TL-11/§TL-14 实证 schema 为 lmc02（被改会员号）/lmc04（动作）/
     lmc05（变更内容串）/lmc08（操作时间），今依实证重写；
     mem016/mem017 段式之 LIKE 谓词以 §P12b-pre 目检为准，目检不符即改。
   ───────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents——公司测试线代理（§P12b）
    SELECT age001 AS agent_id                                                                       -- 取值表达式：取用 age001（代理号），产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：取自代理主档
    WHERE age022 = '1'                                                                              -- 过滤条件：测试线旗标
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12b）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked——同注单号取最新版本（§P12b）
    SELECT b.bet01, b.bet05, b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                           -- 取列：起始取列子句，涉 bet05（会员号）、bet18~22（五级代理线）
           b.bet38, b.category, b.dt,                                                               -- 续行：接续取列，涉 bet38（测试标识）、dt（营业日）
           ROW_NUMBER() OVER (                                                                      -- 行号窗口表达式：以行号窗口去重
             PARTITION BY b.bet01                                                                   -- 窗口分区：按注单号分组开窗
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：三级排序取最新版本
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- 取数来源：取自注单明细表
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：限定百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：限定全局窗
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12b）
gated AS (                                                                                          -- 公共表表达式：开启中间结果集 gated——七闸清洗（§P12b）
    SELECT r.dt, CAST(r.bet05 AS BIGINT) AS uid                                                     -- 取值表达式：会员号铸型 BIGINT，产出「uid」
    FROM ranked r                                                                                   -- 取数来源：取自本条自建的中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左联结：一级代理线对测试名单
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左联结：二级代理线对测试名单
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左联结：三级代理线对测试名单
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左联结：四级代理线对测试名单
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左联结：五级代理线对测试名单
    WHERE r.rn = 1                                                                                  -- 过滤条件：只留最新版本
      AND r.category = '1'                                                                          -- 并列条件：一般单准入
      AND UPPER(TRIM(r.bet38)) = 'N'                                                                -- 并列条件：排重对单
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                           -- 并列条件：五级任一命中测试线即剔——
                   t4.agent_id, t5.agent_id) IS NULL                                                -- 续行：COALESCE 五级归并判空
      AND r.bet05 IS NOT NULL                                                                       -- 并列条件：会员键非空
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12b）
member_span AS (                                                                                    -- 公共表表达式：开启中间结果集 member_span——会员活动跨度（§P12b）
    SELECT uid,                                                                                     -- 取列：会员号为主键
           MIN(dt)              AS first_dt,                                                        -- 聚合表达式：首注日，产出「first_dt」
           MAX(dt)              AS last_dt,                                                         -- 聚合表达式：末注日，产出「last_dt」
           COUNT(DISTINCT dt)   AS active_days,                                                     -- 计数表达式：活跃天数，产出「active_days」
           COUNT(*)             AS n_orders                                                         -- 计数表达式：注单数，产出「n_orders」
    FROM gated                                                                                      -- 取数来源：取自本条自建的中间结果集 gated
    GROUP BY uid                                                                                    -- 分组：按会员汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12b）
first_mark AS (                                                                                     -- 公共表表达式：开启中间结果集 first_mark——首次限制事件（§P12b）
    SELECT  CAST(lmc02 AS BIGINT)                        AS uid,                                    -- 取值表达式：lmc02（被改会员号）铸型 BIGINT，产出「uid」——实证 schema，非臆测列
            MIN(SUBSTR(CAST(lmc08 AS STRING), 1, 10))    AS mark_dt                                 -- 聚合表达式：lmc08（操作时间）取日期段之最小值，产出「mark_dt」——首次事件即标记日
    FROM    ods_mariadb_2b.ods_a168_log_mem_change                                                  -- 取数来源：取自会员变更日志表（与 §TL-14 同源同法）
    WHERE   dt >= '2026-03-21' AND dt < '2026-08-07'                                                -- 过滤条件：限定全局窗
      AND   CAST(lmc04 AS STRING) IN ('edit', 'changestatus')                                       -- 并列条件：只留配置修改与状态变更两类（§TL-14 同款）
      AND   ( CAST(lmc05 AS STRING) LIKE '%mem016%'                                                 -- 并列条件：变更串含 mem016（enable 停启）——
           OR CAST(lmc05 AS STRING) LIKE '%mem017%' )                                               -- 并列条件：或含 mem017（canbet 禁投）；段式以 §P12b-pre 目检为准
    GROUP BY CAST(lmc02 AS BIGINT)                                                                  -- 分组：按会员取首次
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§P12b）
SELECT m.uid, m.first_dt, m.last_dt, m.active_days,                                                 -- 取列：会员四要素透传
       DATEDIFF(m.last_dt, m.first_dt) + 1             AS span_days,                                -- 取值表达式：首末跨天数含两端，产出「span_days」
       m.n_orders,                                                                                  -- 取列：注单数透传
       f.mark_dt,                                                                                   -- 取列：标记日（无处置记录者为空，不入处理组）
       CASE WHEN m.last_dt >= '2026-08-01' THEN 1 ELSE 0 END AS censor_flag                         -- 条件表达式：窗口末仍活跃即右删失，产出「censor_flag」
FROM member_span m                                                                                  -- 取数来源：取自本条自建的中间结果集 member_span
LEFT JOIN first_mark f ON f.uid = m.uid                                                             -- 左联结：挂首次标记（多数会员为空属常态）
ORDER BY m.uid;                                                                                     -- 排序：按会员号升序；导出必带排序

/* ─────────────────────────────────────────────────────────────────────────
   §P12c · 会员逐日盈亏
   ▸ 导出：需要 —— 存为「数据库/P12c_member_daily_pnl.csv」
   ▸ 粒度：uid × dt；仅雷欧域（n>=100，约 92,412 人）以控体量。
   ▸ 用途：MDD（累计盈亏峰谷）、Sortino/Sharpe（逐日波动）、追损/打水指纹。
   ▸ ⚠ 与 §R03b（玩家×荷官×日）同族互为对帐，非替代——§R03b 缺剔测试线
     （本包勘误在案）且 2026-08-12 导出截断止因 UNKNOWN；本件独立重跑，
     两件回传后须于 uid×dt 汇总层对帐归零方可同录。
   ▸ 体量预警：行数≈Σ会员活跃日，预估千万级；分批一律 keyset 游标——
     WHERE (uid > 上批末uid) OR (uid = 上批末uid AND dt > 上批末dt)，禁 OFFSET。
   ───────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (                                                                               -- 公共表表达式：开启中间结果集 test_agents——公司测试线代理（§P12c）
    SELECT age001 AS agent_id                                                                       -- 取值表达式：取用 age001（代理号），产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：取自代理主档
    WHERE age022 = '1'                                                                              -- 过滤条件：测试线旗标
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12c）
ranked AS (                                                                                         -- 公共表表达式：开启中间结果集 ranked——同注单号取最新版本（§P12c）
    SELECT b.bet01, b.bet05, b.bet11, b.bet13, b.bet14,                                             -- 取列：起始取列子句，涉 bet05（会员号）、bet11（汇率）、bet13/14（本金/派彩）
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                             -- 续行：接续取列，涉五级代理线
           b.bet38, b.category, b.validbet, b.dt,                                                   -- 续行：接续取列，涉测试标识、洗码量、营业日
           ROW_NUMBER() OVER (                                                                      -- 行号窗口表达式：以行号窗口去重
             PARTITION BY b.bet01                                                                   -- 窗口分区：按注单号分组开窗
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：三级排序取最新版本
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- 取数来源：取自注单明细表
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：限定百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：限定全局窗
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12c）
gated AS (                                                                                          -- 公共表表达式：开启中间结果集 gated——七闸清洗并折原币（§P12c）
    SELECT r.dt, CAST(r.bet05 AS BIGINT) AS uid,                                                    -- 取值表达式：会员号铸型 BIGINT，产出「uid」
           (CAST(r.bet14 AS DECIMAL(20,4)) - CAST(r.bet13 AS DECIMAL(20,4)))                        -- 取值表达式：派彩减本金——
             / NULLIF(CAST(r.bet11 AS DECIMAL(20,4)), 0) AS pnl,                                    -- 续行：归原币，产出「pnl」
           CAST(r.bet13 AS DECIMAL(20,4))                                                           -- 取值表达式：bet13（下注金额）——
             / NULLIF(CAST(r.bet11 AS DECIMAL(20,4)), 0) AS stake,                                  -- 续行：归原币，产出「stake」
           CAST(r.validbet AS DECIMAL(20,4))                                                        -- 取值表达式：validbet（洗码量）——
             / NULLIF(CAST(r.bet11 AS DECIMAL(20,4)), 0) AS vb                                      -- 续行：归原币，产出「vb」
    FROM ranked r                                                                                   -- 取数来源：取自本条自建的中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左联结：一级代理线对测试名单
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左联结：二级代理线对测试名单
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左联结：三级代理线对测试名单
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左联结：四级代理线对测试名单
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左联结：五级代理线对测试名单
    WHERE r.rn = 1                                                                                  -- 过滤条件：只留最新版本
      AND r.category = '1'                                                                          -- 并列条件：一般单准入
      AND UPPER(TRIM(r.bet38)) = 'N'                                                                -- 并列条件：排重对单
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                           -- 并列条件：五级任一命中测试线即剔——
                   t4.agent_id, t5.agent_id) IS NULL                                                -- 续行：COALESCE 五级归并判空（§R03b 缺此闸，故两件不可互代）
      AND r.bet05 IS NOT NULL                                                                       -- 并列条件：会员键非空
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P12c）
hf AS (                                                                                             -- 公共表表达式：开启中间结果集 hf——雷欧域会员宇宙（§P12c）
    SELECT uid                                                                                      -- 取列：会员号
    FROM gated                                                                                      -- 取数来源：取自本条自建的中间结果集 gated
    GROUP BY uid                                                                                    -- 分组：按会员汇总
    HAVING COUNT(*) >= 100                                                                          -- 分组过滤：与 §R01 名单同门槛（n>=100），防口径漂移
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§P12c）
SELECT g.uid, g.dt,                                                                                 -- 取列：会员×营业日双主键
       COUNT(*)               AS day_orders,                                                        -- 计数表达式：当日注单数，产出「day_orders」
       ROUND(SUM(g.stake), 4) AS day_stake,                                                         -- 聚合表达式：当日本金，产出「day_stake」
       ROUND(SUM(g.vb), 4)    AS day_vb,                                                            -- 聚合表达式：当日洗码，产出「day_vb」
       ROUND(SUM(g.pnl), 4)   AS day_pnl                                                            -- 聚合表达式：当日净盈亏（会员视角），产出「day_pnl」
FROM gated g                                                                                        -- 取数来源：取自本条自建的中间结果集 gated
JOIN hf ON hf.uid = g.uid                                                                           -- 内联结：限定雷欧域会员
GROUP BY g.uid, g.dt                                                                                -- 分组：按会员×日汇总
ORDER BY g.uid, g.dt;                                                                               -- 排序：keyset 游标之稳定序；导出必带排序

/* ─────────────────────────────────────────────────────────────────────────
   §P12d · 新窗口雷欧名单——全量 SQL（v8 派生）
   ▸ 导出：需要 —— 存为「数据库/R01_late_shoe_w2.csv」
   ───────────────────────────────────────────────────────────────────────── */

-- ▸ 派生声明（v8）：本语句由卷二 §R01 **程序化派生**——除下述外与 §R01
--   逐字节相同：窗口字面量 1 行改为 dt >= '2026-08-07' AND dt < '2026-08-20'，
--   头注两行改名 w2。W2 窗＝2026-08-07 ~ 2026-08-19 收盘（共 13 个完整营业日），
--   与主窗右开端点 2026-08-07 **无缝紧接、无一日之隙**。窗短则 n>=100 命中必少——
--   系窗口数学非异常；此窗字面量**不在**全局改窗替换清单之内。
/* ───────────────────────────────────────────────────────────────────────────
   §P12d · R01_late_shoe_w2.csv（新窗口 W2）
   策略性风控：靴内相对靴位 ≥ 0.80（≈ 靴末 20% 之局位，等价外部报告「第 40 局」）的下注占比
              + 相对靴位 + 注额斜率 + 分段 ROI
   ★★ 2026-08-12 B-01 斧正：判据由绝对局号 round_no>=50 改为相对靴位 shoe_pos>=0.80 ★★
     依据：外部实测靴长分布（均值 49.86 局、P50=50、P75=52、P90=54、P99=58）。
     第 50 把的相对靴位为 100.3%（以均值计），故 round_no>=50 实为「靴的最后一局
     及长于中位数的那半数靴」——约半数牌靴无末段可言，late_share 被系统性压低。
     新判据固定的是**局位区间**（每靴末 20% 的局），不是下注占比；late_share 仍由
     实际下注行为决定，均匀下注之零偏好基准下期望约 20%，实际可为 0%~100%。
   ★ 新增 late_def 口径锁列：旧版 CSV 因缺此列而在报告侧读入时当场报错，
     使「新文字配旧数字」的静默语义漂移变成显式失败。
   对应报告：@sec-r01
   输出列：late_def(口径锁), uid, n_orders_all, n_orders_late, late_share, shoe_pos_p50,
           stake_late_avg, stake_early_avg, stake_ramp, roi_late, roi_early,
           stake_late, game_pnl_late, stake_all, game_pnl_all
   预期行数：数千 ~ 数万（HAVING 已收敛）
   ─────────────────────────────────────────────────────────────────────────── */
-- ▸ 导出：需要 —— 存为「数据库/R01_late_shoe_w2.csv」（§R01 靴末段下注）。
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
  WHERE b.dt >= '2026-08-07' AND b.dt < '2026-08-20'                                                -- 过滤条件：限定 b.dt不少于 '2026-08-07'、b.dt小于 '2026-08-20'，涉 dt（营业日）——W2 紧接主窗右开端点
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
shoe_len AS (          /* ★ 命名警示：本 CTE 名为 shoe_len（靴长）系历史沿用，其所算 max_round = MAX(round_no) 为『该靴该桌观测到的最大局号』，非 COUNT(round_no) 之局数；二者仅在局号自1起连续无缺口时相等。选 MAX 为刻意设计：对中间缺口免疫，COUNT 会因清洗剔单而使分母缩水。★ B-01 斧正（2026-08-12）：定标基准逐靴现算，绝对局号不是固定靴位 */   -- 缺陷一修正：定标基准不定，固定 50 不是固定位置
  SELECT shoe_id, table_id, MAX(round_no) AS max_round                                              -- 取列：取最大局号（≠COUNT 局数），产出「max_round」
  FROM base GROUP BY shoe_id, table_id                                                              -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R01）
enriched AS (                                                                                       -- 公共表表达式：开启中间结果集 enriched，其后各行为其定义体（§R01）
  SELECT b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round,                               -- 取列：起始取列子句，本行先列 b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round，涉 member_id（会员号）
         b.round_no * 1.0 / NULLIF(s.max_round,0)     AS shoe_pos,                                  -- 取值表达式：产出「shoe_pos」
         b.stake_raw / b.fx                           AS stake,                                     -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (b.payout_raw - b.stake_raw) / b.fx          AS game_pnl,                                  -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         CASE WHEN b.round_no * 1.0 / NULLIF(s.max_round,0) >= 0.80
              THEN 1 ELSE 0 END                        AS is_late   -- B-01 斧正：相对靴位                                    -- 条件分支：产出「is_late」
  FROM base b                                                                                       -- 取数来源：取自本条自建的中间结果集 base
  JOIN shoe_len s ON s.shoe_id = b.shoe_id AND s.table_id = b.table_id                              -- 连接：取自本条自建的中间结果集 shoe_len，连接键为 s.shoe_id = b.shoe_id AND s.table_id = b.table_id
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R01）
SELECT                                                                                              -- 续行：接续上一取列子句，续列 SELECT
  member_id                                                     AS uid,                             -- 取值表达式：取用 member_id（会员号）、uid（会员号），产出「uid」
  COUNT(*)                                                      AS n_orders_all,                    -- 计数表达式：产出「n_orders_all」
  SUM(is_late)                                                  AS n_orders_late,                   -- 汇总表达式：产出「n_orders_late」
  'shoe_pos>=0.80'                                              AS late_def,        -- 口径锁：definition_version = v2
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



/* ═══════════════════════════════════════════════════════════════════════
   §P13 · Personal Entry / Span / Ramp（个人入场行为层 · 2026-08-20 v7 并入）
   ▸ 血统：外部 REDTEAM 建议编号「§R02」，与本包 §R02_same_table 撞名，
     依评估线序改号 §P13；阿泽与 §R01 一字不改，三模型并行不混编。
   ▸ 铁律随契约：NO BET ≠ OBSERVING（注单表见不得 Bet=0 之因）；
     机会分母（实际有机会下注之局数）未建，判级 UNKNOWN 照登。
   ═══════════════════════════════════════════════════════════════════════ */

-- ─────────────────────────────────────────────────────────────────────────
-- §P13 · 会员入场行为层
-- ▸ 导出：需要 —— 存为「数据库/P13_personal_entry.csv」
-- 粒度：uid × 1（雷欧域 n>=100 同门槛）；逐靴层先算六量再聚合
-- ─────────────────────────────────────────────────────────────────────────
WITH test_agents AS (                                                                               -- 公共表表达式：公司测试线代理（§P13）
    SELECT age001 AS agent_id                                                                       -- 取值表达式：取用 age001（代理号），产出「agent_id」
    FROM ods_mariadb_2b.ods_a168_agent                                                              -- 取数来源：取自代理主档
    WHERE age022 = '1'                                                                              -- 过滤条件：测试线旗标
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P13）
ranked AS (                                                                                         -- 公共表表达式：同注单号取最新版本（§P13）
    SELECT b.bet01, b.bet03, b.bet04, b.bet05,                                                      -- 取列：涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
           b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                             -- 续行：五级代理线
           b.bet38, b.category, b.dt,                                                               -- 续行：测试标识、类别、营业日
           ROW_NUMBER() OVER (                                                                      -- 行号窗口表达式：去重
             PARTITION BY b.bet01                                                                   -- 窗口分区：按注单号
             ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                         -- 排序：三级排序取最新版本
    FROM ods_mariadb_2b.ods_a168_bet02 b                                                            -- 取数来源：注单明细表
    WHERE b.bet02 = '101'                                                                           -- 过滤条件：限定百家乐
      AND b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                              -- 并列条件：限定全局窗
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P13）
gated AS (                                                                                          -- 公共表表达式：七闸清洗（§P13）
    SELECT r.bet03, CAST(r.bet04 AS INT) AS round_no, CAST(r.bet05 AS BIGINT) AS uid                -- 取值表达式：铸型产出「round_no」「uid」
    FROM ranked r                                                                                   -- 取数来源：中间结果集 ranked
    LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18                                               -- 左联结：一级线对测试名单
    LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19                                               -- 左联结：二级线对测试名单
    LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20                                               -- 左联结：三级线对测试名单
    LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21                                               -- 左联结：四级线对测试名单
    LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22                                               -- 左联结：五级线对测试名单
    WHERE r.rn = 1                                                                                  -- 过滤条件：只留最新版本
      AND r.category = '1'                                                                          -- 并列条件：一般单准入
      AND UPPER(TRIM(r.bet38)) = 'N'                                                                -- 并列条件：排重对单
      AND COALESCE(t1.agent_id, t2.agent_id, t3.agent_id,                                           -- 并列条件：五级任一命中即剔——
                   t4.agent_id, t5.agent_id) IS NULL                                                -- 续行：COALESCE 五级归并判空
      AND r.bet03 IS NOT NULL AND r.bet04 IS NOT NULL AND r.bet05 IS NOT NULL                       -- 并列条件：三键非空
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P13）
shoe_len AS (                                                                                       -- 公共表表达式：观测靴长（§P13）
    SELECT bet03, MAX(round_no) AS max_round                                                        -- 计数表达式：每靴最大局号（真靴长权威表 P0 未解前之代理）
    FROM gated                                                                                      -- 取数来源：中间结果集 gated
    GROUP BY bet03                                                                                  -- 分组：按靴号
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§P13）
per_shoe AS (                                                                                       -- 公共表表达式：逐靴六量（§P13）
    SELECT g.uid, g.bet03,                                                                          -- 取列：会员×靴双键
           MIN(g.round_no)                     AS first_r,                                          -- 聚合表达式：个人入场局，产出「first_r」
           MAX(g.round_no)                     AS last_r,                                           -- 聚合表达式：个人末注局，产出「last_r」
           COUNT(*)                            AS n_bets,                                           -- 计数表达式：靴内注数，产出「n_bets」
           MAX(s.max_round)                    AS max_round                                         -- 聚合表达式：该靴观测靴长透传
    FROM gated g                                                                                    -- 取数来源：中间结果集 gated
    JOIN shoe_len s ON s.bet03 = g.bet03                                                            -- 内联结：逐靴挂靴长
    GROUP BY g.uid, g.bet03                                                                         -- 分组：会员×靴
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§P13）
SELECT uid,                                                                                         -- 取列：会员号为主键
       COUNT(*)                                            AS n_shoes,                              -- 计数表达式：观测靴数，产出「n_shoes」
       SUM(n_bets)                                         AS n_orders,                             -- 聚合表达式：注单合计，产出「n_orders」
       ROUND(PERCENTILE_APPROX(first_r * 1.0                                                        -- 取近似分位数表达式：入场相对靴位——
             / NULLIF(max_round, 0), 0.5), 4)              AS entry_pos_p50,                        -- 续行：中位，产出「entry_pos_p50」
       ROUND(PERCENTILE_APPROX(last_r * 1.0                                                         -- 取近似分位数表达式：退出相对靴位——
             / NULLIF(max_round, 0), 0.5), 4)              AS exit_pos_p50,                         -- 续行：中位，产出「exit_pos_p50」
       ROUND(PERCENTILE_APPROX(n_bets * 1.0                                                         -- 取近似分位数表达式：个人跨度内下注密度——
             / NULLIF(last_r - first_r + 1, 0), 0.5), 4)   AS bet_density_p50,                      -- 续行：中位，产出「bet_density_p50」
       ROUND(AVG(first_r), 2)                              AS entry_round_avg                       -- 聚合表达式：绝对入场局均值（供与阿泽轴交叉），产出「entry_round_avg」
FROM per_shoe                                                                                       -- 取数来源：中间结果集 per_shoe
GROUP BY uid                                                                                        -- 分组：按会员
HAVING SUM(n_bets) >= 100                                                                           -- 分组过滤：雷欧域同门槛（n>=100），防口径漂移
ORDER BY uid;                                                                                       -- 排序：keyset 稳定序；导出必带排序

/* ═══════════════════════════════════════════════════════════════════════════
   §Z-16 · 变更记录

   §Z-16 · 变更记录（v9 → v10，2026-08-20）
     ① 导出声明口径统一（用户令）：评估线并入各节（§P11a~d、§P12a~d、
        §P13、§P12b-pre）之导出措辞，一律归一为卷二既有体例——
        「▸ 导出：需要 —— 存为「数据库/xxx.csv」」／「▸ 导出：不需要 ——
        只看屏幕」；小节标题内嵌「（存为…）」样式废止，改独立导出行。
        §P12b-pre 补注：留档可另存「数据库/_P12b-pre.csv」，非交付件。
     ② SQL 逻辑零改动；v9 加 _superseded 归档；六元组重登。

   §Z-16 · 变更记录（v8 → v9，2026-08-20）
     ① W2 窗口斧正（用户令：日期务必与主方案窗一致衔接）：主窗为
        2026-03-21 ~ 2026-08-06 收盘（谓词右开 dt < '2026-08-07'）——
        v8 之 W2 自 2026-08-08 起，致 2026-08-07 一日两窗皆不覆盖之隙；
        今改 dt >= '2026-08-07' AND dt < '2026-08-20'（W2 ＝ 2026-08-07 ~
        2026-08-19 收盘，共 13 个完整营业日），与主窗无缝紧接。
     ② 派生声明与行尾注释随改；v8 变更记录原文不改（历史照登）。
     ③ v8 加 _superseded 归档；六元组重登。

   §Z-16 · 变更记录（v7 → v8，2026-08-20）
     ① 顺序审计发现并勘正：§P11b 曾整段复制 §R01（逐行比对差异为零，
        同语句双名双处）——去重为指引（权威唯 §R01；契约名以导出后复制
        实现，双名同 MD5 为对帐锚）。同语句禁双处，防漂移。
     ② §P12d 由改窗指引升为**全量 SQL 在册**：自 §R01 程序化派生，
        除窗口字面量 1 行（'2026-08-08'~'2026-08-20'）与头注两行改名外
        逐字节相同；该窗字面量不入全局改窗替换清单。
     ③ 语句计数維持 72（P11b −1、P12d +1 相抵）；窗口字面量计数现算更新
        （P11b 去重致各 −1）。
     ④ v7 加 _superseded 归档；六元组重登。

   §Z-16 · 变更记录（v6 → v7，2026-08-20）
     ① 并入 §P13 · Personal Entry / Span / Ramp（个人入场行为层）——外部
        REDTEAM 拟号「§R02」与本包 §R02_same_table 撞名，改号 §P13；
        阿泽与 §R01 SQL 一字不改，三模型（绝对/相对/个人）并行不混编。
     ② 铁律随契约入册：NO BET ≠ OBSERVING；机会分母 UNKNOWN 照登。
     ③ 语句计数 71 → 72（新式 50）；窗口字面量计数现算更新。
     ④ v6 加 _superseded 归档；六元组重登（CRLF/LF 双 MD5）。

   §Z-16 · 变更记录（v5 → v6，2026-08-20）
     ① 并入评估线 §P11 族四件（阿泽/雷欧 名单×2 ＋ 总帐×2）——原文逐字
        取自评估档 v1.2.13 之 eval=FALSE 展示块，本包自此为唯一权威出处，
        评估档内同文降为引用展示（其载入契约 .pp 路径不动）。
     ② 文件名双轨铁律：P11 四件 CSV 系评估档载入器之契约名且实档在身，
        **保持中文名不英译**；P12 三件尚未执行，改英名——
        P12a_platform_daily.csv / P12b_member_events.csv /
        P12c_member_daily_pnl.csv（§P12d 之 R01_late_shoe_w2.csv 本即英名）。
        评估档待表清单随发 v1.2.14 同步改名，两端对齐。
     ③ 语句计数 67 → 71（新式 45 → 49）；窗口字面量计数现算更新。
     ④ v5 加 _superseded 归档；六元组重登（CRLF 原样与 LF 归一双 MD5）。

   §Z-16 · 变更记录（v4 → v5，2026-08-20）
     ① 并入评估线 §P12 族四件（§P12b-pre 预检、§P12a 平台日度序列、
        §P12b 会员事件表、§P12c 会员逐日盈亏、§P12d 改窗指引）——
        独立包「P12_序列与事件_SQL包_v1.sql」作废归宗，加 _superseded 后缀。
     ② §P12b 实质修改在案：独立包曾以臆测列 mem_field/mem001 书写
        first_mark，今依本包 §TL-11/§TL-14 实证 schema（lmc02/lmc04/
        lmc05/lmc08）重写；mem016/mem017 段式 LIKE 谓词以 §P12b-pre
        目检为准。余三件仅体例换装（行尾注释补齐），逻辑零改。
     ③ 头部修正三处：血统登记表「本包」行 v3 → v5（v4 升版时失更，今补）；
        「53 处窗口字面量」死数改现算措辞（v5 实测见头部）；语句计数
        64 → 67 条（新式 42 → 45）。
     ④ 编号辨义入目录：评估线 P12x 与卷一 P-01（连字符式）无涉。
     ⑤ 行尾制式：本版落盘 CRLF（归档铁律），LF 归一 MD5 另行登记。
   ---------------------------------------------------------------------------
   ═══ v4 修订身份登记（DOCUMENT_FAMILY = v4；文件名不变，以 MD5 为物证身份）═══
     v4-original   MD5 = 2aac44a2c738559d317042b0023f2b16
                   行(LF) 8,210 · 字节 1,066,790 · LF · UTF-8(无BOM)
     v4-revised    MD5 = 见随附「v4_revision_identity.txt」
                   ⚠ 自指规避：文件内不得写入自身 MD5——写入即改变内容、
                     使该值当场失效。故本档只载 REVISION 内容界定，
                     六元组另存于随附清单，二者以「文件名＋REVISION」对应。
     REVISION：
       · Probe-01 并入（存为 §Z-18，🔒 CLOSED）
       · Probe-02 并入（存为 §Z-19，S1 CLOSED／总命题 ⏳ OPEN）
       · §P0C bet41 语义斧正（原文保留，标 ODS_DICTIONARY_DEFECT）
       · commission 异常值门 DQ-COMMISSION 立册（31 行，禁删）
       · bet16／bet41 语义锁定（§Z-17 之一）
       · bet16 月度覆盖率登记为 OBSERVED（禁作因果解释）
       · S1 实体接线闭合（lmc02 → member_id，lmc03=7）
       · LEGACY-532 计数冲突登记（旧 532／188 vs 实测 1,490／294）
       · ANOM-mem020 异常登记（6,592 次单向变更，仅涉 1 实体）
       · treatment mapping 维持 OPEN（S3／S4 未闭）
       · §Z-18 A 段补录（P01A_crosstab.csv）＋ 窗口口径四格表与跨段一致性四问
         写入 §Z-17（v4-revised-2）
     supersedes            ： v4-original
     does_not_supersede    ： 原始证据、探针输出、既往审计结果（一律保留）
     ⚠ 「v4」自此为**方案版本族**，具体物证身份以 MD5 为准；
        日后若有 v4-revised-2，须在此续登，不得覆盖上列任一条。

   ─── 原 v3 → v4 记录（原文保留）───────────────────────────────────────
   §Z-16 · 变更记录（v3 → v4）
   ---------------------------------------------------------------------------
   2026-08-18  v4  §Z-14 零值诊断入包（SQL 主体首次改动）。
     改前六元组（v3 · 2026-08-18 实测）：
       行数(LF) 8,009 · 字节 1,051,850
       MD5 b9f956ad395798ce7a81d36b2cb835b5 · LF · UTF-8(无BOM)
     本轮改动：
       ① 新增 **§Z-14 · 零值会员-月性质诊断**（查询 + 导出，位于 §Z-12 之后）。
          ★ 这是自 v3 立版以来 **SQL 主体的首次实质改动**——v3 之 §Z-16 曾载
            「补闸落地后须另立 v4」，本轮以 §Z-14 触发升版，
            **谨此如实声明：14 条交付件缺闸仍未补，v4 不含补闸内容。**
          ★ 亦如实声明：§Z-14 首跑已执行（结果见 Z14_zero_month_diagnosis.csv），
            但本包所载为**口径斧正后之修正版**，与首跑结果口径不同，须重跑取数。
       ② 导出汇总补 §Z-14 行；并斧正「八个导出名／66 个／69 个」诸旧计数——
          实测唯一交付件 v3 为 74、v4 为 75；旧数 69 之根因（ASCII 正则漏计
          六个中文命名交付件）已查明并写入导出汇总章。
       ③ 头部 shoe_len 注释斧正（2026-08-18 早前已并入 v3，本轮不重复）。
     实测裁定（由 §Z-14 首跑与 §Z-12 独立复核双版互证，交集 258 行四项数值零差）：
       · 源库 validbet **零 NULL**（n_vb_null=0／393 行、n_validbet_dbnull=0／361 行）；
       · 故 S05 面板之 0.00E+00 全为真实零，电子表格中转**未抹平任何 NULL**，
         此前「S05 信息损毁」之登记予以**撤销**；
       · F-02（valid_bet 实现分叉）源码差异属事实，惟本窗口内 NULL 率为零，
         两种实现产出相同，**当前影响为零**；该等价性依赖数据实况而非设计保证，
         换窗口／币种／产品须以 §Z-14 之 n_vb_null 列重验；
       · 「洗码合计为零」者 166 会员-月／133 名会员，等额自对押局 100% 非零、
         洗码正数单 100% 为零、退水合计恰为 0——机制坐实：
         平台规则对等额对押之注不计洗码。该集已另存为 T-05 打水标注样本。
     ⚠ 本轮**只增一条查询与相关注释，既有任何一条查询之行为与产出皆未改变**。
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-16 · 变更记录（v2斧正版 → v3）
   ---------------------------------------------------------------------------
   2026-08-13  v3  一族四档血统同步。
     改前六元组（v2斧正版）：
       行数 7,849 · 字节(原样) 1,042,121 · 字节(LF归一) 1,034,272
       MD5(原样)   30d9db43d5e641538c1e9eeb00527e2b
       MD5(LF归一) ed7a6b1b5c338b79e2ac9e8b9bf0e3b9
       CRLF · UTF-8(无BOM) · 字节差 7,849 = 行数 ✅
     本轮改动（**只增注释与登记，SQL 主体一字未动**）：
       ① 头部新增「血统关系登记」——一族四档角色与三条同步纪律；
       ② 头部新增「§Z-13 全包净化审计结论」——154 条逐条核实读数、
          14 条交付件缺闸清单、三处后果、全文字符扫描；
       ③ 文末新增本变更记录（§Z-16）。
     ⚠ 因只增注释，**任何一条查询之行为与产出皆未改变**；
       14 条缺闸仍待按「Z15_前置净化层_标准前奏与补闸包.sql」处置。
       补闸落地后须另立 v4，届时 SQL 主体方有改动。
     改后六元组（v3 · 2026-08-13 实测）：
       行数 7,932 · 字节(原样) 1,048,666 · 字节(LF归一) 1,040,734
       MD5(原样)   7e58679d110c53d9d1f807d4512250e6
       MD5(LF归一) 1e1e4294c067763343eb47c908c37afc
       CRLF · UTF-8(无BOM) · 字节差 7,932 = 行数 ✅
       ⚠ 上列六元组系写入本行**之前**之实测；写入本行后文件再变，
         故取用时以随附 Z13 审计脚本当场重算者为准。
   ═══════════════════════════════════════════════════════════════════════════ */
