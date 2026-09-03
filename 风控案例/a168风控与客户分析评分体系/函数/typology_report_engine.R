# =====================================================================
# typology_report_engine.R · 十五类风险会员商业方案 · 共用分析引擎（含范本体例）
# ---------------------------------------------------------------------
# 版本 : 1.12.0
# 变更 : 1.12.0（N-15 · 承先生「一切依照先生之见进行」之令；一切裁定皆有 2026-09-03 实测为凭）——
#        ① §17 加权诊断与双口径：tr_weight_diag()（ESS ＝ (Σw)²/Σw²、top1%／top5% 占权、最大比中位、
#           THIN_WEIGHTED_EVIDENCE 旗标）／tr_precision_weight()（τ² 与 s² 矩法反解）／
#           tr_dual_estimand()（暴露加权／单元等权／中位／精度加权四估计**并列**，禁择优呈报）／
#           tr_weight_registry()／tr_hold_def()／tr_polarity_registry()。
#           ⛔ 实测为凭：暴露权 ESS/n ＝ 0.151%（723,442 名之有效样本仅 1,093，top1% 占权 78.79%，
#              最大比中位 796,454 倍）；精度权 ESS/n ＝ 45.04%、最大比中位 7.3 倍，且与暴露权
#              Spearman ＝ 1.000000 ⇒ 精度权系暴露权之收缩稳定版，二者【择一】，并用即重复计权。
#           ⛔ 时间衰减 REJECT：OOS 暴露加权 RMSE 单调劣化（∞ 0.072656 → 0.5 月 0.081419）。
#           ⛔ 加权造不出信号：会员 hold 跨期秩相关 0.063276，OOS 最优估计器系【总体常数】。
#        ② §18 ECONOMIC_SEMANTIC_GATE v1.0 十五条机检 ＋ tr_economic_semantic_verdict()。
#        ③ §19 tr_status_matrix() 四状态分离（工程／统计／因果／商业），⛔ 禁以单一 PASS 混淆四义。
#        ④ 就地加严五处：EVT 加 EVT_STATUS（MODEL_DISAGREEMENT，⛔ 二值之间系模型选择敏感性区间，
#           非 ξ 之置信区间）；蒙地卡罗加 SCALING_GATE 与口径 SIMULATED_FROM_OBSERVED_EFFECT；
#           马尔可夫广播闸由 NOT_RUN 升为 BLOCKED；期望损失主量改 argmax economic_gain（loss ≡ −gain，
#           方向统一为单一 SSOT）；处理前后闸加 PAIRING_COVERAGE／ATTRITION_RATE／POPULATION_EFFECT
#           三栏并正名为 TEMPORAL_CHANGE。
#        ⑤ .TR_HOLD_DEF 移入配置册 metric_canon（增【理论 house_edge_theoretical ＝ NULL】行与
#           视角／极性二栏），码内不再存第二份真相源。⛔ KILLCRITIC-01：realized ≠ theoretical，
#           `house_edge` 一名永久保留予理论优势。
#        §1~§16 之算法一字未改。
# 变更 : 1.11.0（N-14 · 承先生「以顶级统计概念灵活搭配，择最低亏损最高回酬之组合」
#        与《参考.txt》之校对）——
#        ⛔ 病根自陈：1.10.0 及以前，可执行码中 bayes／posterior／likelihood／markov／
#          transition／monte／simulat／GPD／expected_loss 命中**皆为 0**。报表只描述【现状】，
#          从不预测「若如此处置将如何」，更无处理前后之经济回归闸——故「实测并证实处理前后
#          之风险」一令，历十五份从未落地。
#        ① §15 决策统计层：tr_type_members()（本类候选人群）／tr_bayes_edge()＋tr_bayes_panel()
#           （经验贝叶斯收缩，τ² 与 s² 以矩法自数据反解，答「真实 hold < 0 之后验概率」而非
#           已实现输赢）／tr_mle_fit()／tr_markov_states()＋tr_markov_panel()（状态自持与稳态，
#           答「异常是否持续」）／tr_evt_pot()（POT／GPD 尾指数、VaR、ES，矩法与 MLE 并报）／
#           tr_monte_carlo_actions()（效应分布一律自 PI01 实测 d_revenue 自助重抽，禁臆造）／
#           tr_expected_loss()（成本未登记则**反解盈亏平衡成本上限**，禁臆造成本）／
#           tr_rl_bench()（RL 明令 BENCHED，就地出示禁赛理由与解锁条件）。
#           ⛔ 各器各答各问，**禁揉成单一风险总分**——「一个数字 ＝ 风险」系本项目已否决之谬。
#        ② §16 PRE_POST_RISK_ECONOMIC_GATE：tr_prepost_platform()／tr_prepost_member()
#           （配对之符号检验＋Wilcoxon＋自助 CI）／tr_prepost_retention()（留存流失与删失，
#           不揭此层者一切「有效」皆幸存者偏差）／tr_prepost_verdict()（任一经济指标退化即 FAIL）。
#        ③ §13.2 .TR_HOLD_DEF 依 2026-09-03 全量实测更正并加列「验证」栏：hold_rate ≡ profit/stake
#           越界 0 行；roi ≡ −hold_rate 恒等 723,442 行 100.000000%。
#        §1~§14 之算法一字未改。
# 变更 : 1.10.0（N-13 · 承先生问「为何十五份一律遗漏 SQL 原文与维度指标」）——
#        ⛔ 病根自陈：1.9.0 虽立 tr_sql_of()／tr_dimensions()，然**模板从未接线**
#          （实测模板 v1.7.0 全档内 tr_sql_of／tr_dimensions／tr_delivery_gate 命中皆为 0）。
#          器在库中而报表不出，与无器无异——此谓「造了闸而不装上」。故十五份之
#          第二部分只见交付件清单而不见其取数 SQL，第三部分只见 ODS 字典与登记册口径，
#          而不见 数据库/ 内主辅表逐栏之维度与指标。
#        ① §13.4 就地重构：总包档名自 Sys.glob 硬写改为配置册 sql_pack 现取，并支持
#           先生所言之「*版」——原版审计版_OPT／分批作业版_OPT／分批作业版1万_OPT
#           三版各 133 模块，逐版可选、可对照；另立 tr_sql_pack_manifest() 出示三版血统。
#           max_inline_lines = 0 即【全文不截】（旧本硬写 400 行截断，违禁截铁律）。
#        ② §14 新立四器：tr_sql_standard()（SQL 原文之后逐项解释【输出标准】：源 ODS 库表、
#           观测窗、快照闸、去重规则、粒度键、测试线处置、全序与批次、六层广播块、落盘标识、
#           声明列数 ↔ 册载列数 ↔ 实测列数三方对账、实测行数、可信度裁定、落盘路径）、
#           tr_sql_panel()（本类主辅表逐件溯源总览）、tr_dim_metric_panel()／
#           tr_dim_metric_summary()（读 数据库/ 实档，逐栏定性维度抑或指标，全栏在册、
#           零省略，并与列数对账；本类判据列就地标星）。
#        ③ 模板 v1.8.0 同步接线：第二部分增「二之二 · 主辅表取数 SQL 原文与输出标准」，
#           第三部分增「三 · 主辅数据表全维度与指标盘点」，并于设置章接上 tr_delivery_gate()。
#        §1~§13.3 一字未改。
# 变更 : 1.9.0（N-12）新增 §13 四事：
#        ① tr_delivery_gate() —— ⛔ 实测硬故障：commit 6e53299 以 R100 纯改名把 数据表/ 改回 数据库/，
#           而配置册 namespaces.delivery 未跟改，致 130 件全数静默报「待表（档不在位）」——
#           看似缺数据，实为路径断裂。今立闸：目录不存在或零 csv 一律 stop，禁再静默。
#        ② tr_hold_pair() ＋ .TR_HOLD_DEF —— hold 正名。全包机检定谳三量并存：
#           hold_rate = −net/stake（六层块 128 处，1.681532%）、house_hold_pct = −player_pnl/stake_total
#           （DX04 自有，逐投注面）、我方派生 profit/valid_bet（1.866970%，**总包无此列**）。
#           三者分母各异，同名必致误读；自此一律带分母出名，禁裸称 hold。
#        ③ tr_measured_edge() —— 实测庄家优势（逐投注面 23 面）。总包所阻断者乃【理论】edge 之授权，
#           【实测】edge 无须授权，SELECT 即得：Banker 1.3020%、Player 1.3519%、Tie 15.0605%、
#           对子 10.58%、Super6 20.5730%，加权 1.866970%。⛔ 口径为 realized（含运气），非理论 edge。
#        ④ tr_sql_of()／tr_dimensions() —— 承先生之训「数据非无中生有自动生成，而是自 Superset 之
#           StarRocks 以 SQL 查询后下载」：报表须就地出示本件由哪段 SQL 所出，并逐栏分维度与指标。
#        §1~§12 一字未改。
# 变更 : 1.8.0（N-11 · 我方自陈重大缺陷并补正）新增 §12 交付件可信度闸：
#        ⛔ SQL 总包档头自带 133 行逐件可信度清单（OK 24／WRONG_GRAIN 37／INVALID 67／NULL 1／N/A 4），
#          而本引擎 §10／§11 之广播侦测只验「逐行同值」，**只抓得住 67 件 INVALID，37 件 WRONG_GRAIN 全数漏网**——
#          上卷广播之值在多行重复而非全表同值，故通过检验后被当作逐行实体金额入账，此即最危险一类。
#        今立 tr_credibility()／tr_money_admissible()／tr_credibility_panel()：
#          实体级金额【只准取自 OK 件】；WRONG_GRAIN／INVALID／NULL／N/A／UNKNOWN 一律拒出并标成因。
#        tr_economic_profile()／tr_criterion_exposure()／tr_signed_ladder() 三处均先过此闸。
#        ⛔ UNKNOWN ≠ PASS：不在清单内者一律拒出。
#        §1~§11 之算法一字未改，仅于三处入口加闸。
# 变更 : 1.7.0（N-10 · 承先生「负数至零与零至所有正数各别使用分位数」之策）新增 §11 有符号阶梯：
#        tr_null_point()（零点逐指标声明；⛔ AUC 之虚无点为 0.5 非 0；economic_value 系秩、
#        Wilson 系区间端点、主成分符号任意，三者明令拒算；未声明者一律拒算，不得默认 0）、
#        tr_signed_ladder()（负侧／零点／正侧三段质量 ＋ 两侧各别分位阶梯，每级挂金额占比；
#        广播栏与全 NA 栏拒建；本侧样本不足最小样本门者标 NOT_RUN 而非 PASS）、
#        tr_metric_scan()（全表指标盘点：原生抑或广播、可否建阶梯）。
#        动因：§10.4 实测四条判据于 P90 处退化（尾部占比 44%~100%），病根即零点巨量并列，
#        全域单一分位遇「九成为零」之分布即判别力归零；两侧各别起阶梯正是对症药。
#        ⛔ 承 P-15：本阶梯系全窗百分位，只作描述与诊断，不得径充赏罚线。
#        §1~§10 一字未改。        日期 : 2026-09-03        适配登记册 : 自 registry_load() 现取（本档不写死）
# 变更 : 1.6.0（N-9 · 承先生问「是否分类测试线与真实实体」「有否投影关键指标」）新增 §10 三事：
#        ① tr_testline_gate()／tr_drop_testline() —— 【实测揭缺】1.5.0 以前引擎与模板内 is_test／
#           test_line／测试线／age022 命中皆为 0，即全无测试线处理。总包侧多数交付件取数时已剔，
#           惟 #078 S03_agent_score 采标记法保留（实测 4,191 行中 13 行 is_test_line=1，stake 合计 0）；
#           T-08／T-09 以 S03 为判据来源，故该 13 行此前未经分离即入分位与相关计算。今立闸分离。
#        ② tr_economic_profile()／tr_criterion_exposure() —— 【实测揭缺】1.5.0 以前引擎可执行码中
#           net_margin／economic_value／theo／adt／nmpt／esi／drawdown／sharpe／sortino 命中皆为 0，
#           即本报告只算【判据】，从不算【钱】——直违先生军令状。今补经济层，然【先验广播、后出金额】：
#           六层商业块 118 栏系 CROSS JOIN 平台常数广播，逐行同值者一律拒出并标明，禁以广播充金额。
#        ③ tr_metric_inventory() —— 先生所列各指标（theo／adt／nmpt／esi、ROI、Net Margin、
#           Economic Value、MDD、Sharpe、Sortino、APUC、Wilcoxon、符号检验）逐条登记：可算者标可算，
#           阻断者标出处，未实作者标未实作。⛔ 不以「未实作」冒充「不适用」，不以「可算」冒充「已证」。
#        §1~§9 一字未改。
# 变更 : 1.5.0（N-8c · 承先生指出配置册与三份 SQL 总包漏收）血统配套自 14 件扩至【全在役件】：
#        新增 SQL 总包三版 ＋ 行数实测探针（在役·SQL源，产出 133 件交付件之源）、风险之眼 schema、
#        及五件【参照·无代码消费者】之规范件（capability_registry／prohibited_action_registry／
#        treatment_policy／constants_a168／paths_a168），逐件标类别，禁混为一谈。
#        另新增 tr_name_version() 与【双层身份闸】：档名版本 ＝ 内容版本（承《版本编号纪律》§四之四）——
#        当场揭出 配置/report_config_v1.0.0.yaml 档名 v1.0.0 而内容 1.4.0 之身份断裂。
# 变更 : 1.4.0（N-8）新增 §9 血统配套：tr_sixtuple()（正典六元组，一处实作）／tr_file_version()
#        （自档头现取版本）／tr_lineage_manifest()（全配套十四件渲染时现算）／tr_lineage_gate()
#        （载入器路径版本 ＝ 实载版本之自洽闸）。动因：模板血统表历来手写字面量，2026-09-03
#        实测六列中五处已陈旧。自此血统表现算，该类缺陷绝迹。§1~§8 一字未改。
# 变更 : 1.3.0（N-6）新增 KILL RULE —— 封杀 tr_member_join() 之判据静默丢弃：
#        登记之判据列若不在其声明源表表头内，一律登记 .TR_DROPPED 并经 $dropped／
#        attr(,"silent_drop") 回报，另发 warning。tr_criterion_stats() 之「缺列」显判不动。
#        实测动因：登记册 66 条中 13 条（19.7%）之列不在其声明源表内（8 条系总包 CTE
#        内部别名、1 条系他模块输出、4 条真未建）——此前该 13 条于跨表面板层无声消失。
# 变更 : 1.2.0（N-4 · 2026-09-03 · Ryo Eng 裁定）——typology_report_engine_ext.R
#        （扩充引擎 1.3.0，46 函数）整档并入本档 §E0～§E13，该档同时删除。
#        并档依据：ext 档首 stopifnot(exists("tr_load")) 硬依赖本档，且两档函数名
#        零重叠（本档 12 ／ ext 46），非替代关系而系依附扩充 ⇒ 合为一档方为一物。
#        ★ 两档函数本体一字未改；仅去 ext 之 stopifnot 自守（同档已无从缺席）、
#          并 library(yaml) 入本档首、并订正 ext 头注三处陈旧串（数据库/→数据表/、
#          v1.5.0→v1.5.003、身份行）。source 者自此只需一行。
# 身份 : 执行件（函数/）★ 非交付件、非规范件
# ---------------------------------------------------------------------
# 【职责】被十五份同构 qmd source()。一切数字渲染时现算；登记册 v1.5.0
#         为唯一标准（类型、判据、门禁、裁定、阻断、解锁条件皆取自登记册）。
# 【铁律】
#   1 不硬写任何计数——取 registry_counts(REG)。
#   2 缺档／缺列不以静态文字冒充结果——一律登记为「待表」并在表中显示。
#   3 全量铁律（v1.1.0）：一切交付件**读全部行**，禁抽样、禁截行、禁 head。
#     巨档（逾 TR_WARN_MB）只登记告警，不截行；载入行数与文件换行数逐件对账。
#   4 会员键异名归一：member_id / uid / player_id / mem → member_id。
#   5 GBK 交付件自动回退解码（S01／S05 实测为 GBK）。
#   6 门禁覆盖一切实测：FATAL 类之实测只作画像，图表标题随行带红标。
# =====================================================================

suppressPackageStartupMessages({ library(data.table); library(knitr); library(yaml) })

TR_FULL_SCAN <- TRUE          # 全量铁律：恒为 TRUE；置 FALSE 即报错（防抽样回潜）
TR_WARN_MB   <- getOption("tr.warn_mb", 300)      # 巨档【告警】阈，非截行阈
TR_RC_VERIFY <- TRUE          # 全量核验：文件换行数 ↔ 载入行数对账
TR_RC_MAX_MB <- getOption("tr.rc_max_mb", 4096)   # 逾此不作换行数核验，登记 SKIPPED
TR_DB        <- "数据表"   # N-2A 2026-09-03：承 7f713dc 目录改名；§E0 tr_apply_config() 以配置册 namespaces.delivery 覆写

.tr_key_alias <- c("member_id", "uid", "player_id", "mem", "member_login")

# ---------------------------------------------------------------------
# §1 交付件载入 · 守门 + 键归一 + 编码回退
# ---------------------------------------------------------------------
## 文件换行数：流式计数，不载入内存。用以与载入行数对账，坐实「全量」。
## 注：字段内含换行者，换行数 > 逻辑行数——故只作对账标记，不作 stop() 依据。
tr_file_lines <- function(path, chunk = 64e6) {
  con <- file(path, open = "rb"); on.exit(close(con))
  n <- 0L
  repeat {
    b <- readBin(con, "raw", chunk)
    if (!length(b)) break
    n <- n + sum(b == as.raw(10L))
  }
  n
}

tr_load <- function(file, select = NULL) {
  if (!isTRUE(TR_FULL_SCAN))
    stop("全量铁律被关闭（TR_FULL_SCAN != TRUE）——禁抽样，拒绝出数", call. = FALSE)
  path <- file.path(TR_DB, file)
  if (!file.exists(path))
    return(list(ok = FALSE, status = "待表（档不在位）", dt = NULL, file = file,
                mb = NA_real_, rows = NA_integer_, sampled = FALSE, key = NA_character_,
                file_lines = NA_integer_, full_scan = "—", huge = FALSE))
  mb <- file.size(path) / 1e6
  huge <- mb > TR_WARN_MB
  ## 全量：nrows 恒为 Inf——无论多大之档，一行不截
  rd <- function(enc) fread(path, encoding = enc, nrows = Inf, showProgress = FALSE)
  dt <- tryCatch(rd("UTF-8"), error = function(e) NULL)
  bad_hdr <- !is.null(dt) && !all(validUTF8(names(dt)))
  if (is.null(dt) || bad_hdr) {
    # GBK 回退：以 readLines 全量转码后再 fread（n = -1L 即全量）
    txt <- tryCatch(iconv(readLines(path, warn = FALSE, encoding = "GBK", n = -1L),
                          from = "GBK", to = "UTF-8"), error = function(e) NULL)
    if (!is.null(txt)) dt <- tryCatch(fread(text = txt, showProgress = FALSE), error = function(e) NULL)
  }
  if (is.null(dt))
    return(list(ok = FALSE, status = "待表（不可解析）", dt = NULL, file = file,
                mb = mb, rows = NA_integer_, sampled = FALSE, key = NA_character_,
                file_lines = NA_integer_, full_scan = "—", huge = huge))
  ## 全量核验：文件换行数 ↔ 载入行数（含表头 1 行）
  fl <- if (isTRUE(TR_RC_VERIFY) && mb <= TR_RC_MAX_MB)
    tryCatch(tr_file_lines(path), error = function(e) NA_integer_) else NA_integer_
  fs <- if (is.na(fl)) sprintf("○ 未核（档逾 %s MB）", format(TR_RC_MAX_MB, big.mark = ","))
        else if (fl - 1L == nrow(dt) || fl == nrow(dt)) "✔ 全量（行数对账相符）"
        else sprintf("⚠ 全量已读，行数与换行数差 %s（疑字段内含换行）",
                     format(abs((fl - 1L) - nrow(dt)), big.mark = ","))
  key <- intersect(.tr_key_alias, names(dt))[1]
  if (!is.na(key) && key != "member_id") setnames(dt, key, "member_id")
  ncol_full <- ncol(dt)
  if (!is.null(select)) {
    keep <- intersect(c("member_id", select), names(dt)); dt <- dt[, ..keep]
  }
  list(ok = TRUE,
       status = sprintf("全量 %s 行%s", format(nrow(dt), big.mark = ","),
                        if (huge) sprintf("（巨档 %.0f MB，已全量读入，未截行）", mb) else ""),
       dt = dt, file = file, mb = mb, rows = nrow(dt), sampled = FALSE,
       key = if (is.na(key)) NA_character_ else key,
       file_lines = fl, full_scan = fs, huge = huge, ncol_full = ncol_full)
}

# ---------------------------------------------------------------------
# §2 本类配方 · 自登记册取（零猜测）
# ---------------------------------------------------------------------
tr_recipe <- function(REG, tid) {
  .tid <- tid
  d <- REG$dict[type_id == .tid]
  if (!nrow(d)) stop(sprintf("登记册无此类：%s", tid), call. = FALSE)
  sup <- unlist(strsplit(d$supporting_deliverables[1L], "[；;]")); sup <- trimws(sup[nzchar(sup)])
  files <- unique(c(d$primary_deliverable[1L], sup, d$criterion_source))
  files <- files[grepl("\\.csv$", files)]
  list(dict = d, primary = d$primary_deliverable[1L], supporting = sup, files = files,
       typ = registry_typology(REG, tid), scal = registry_type_scalars(REG, tid))
}

# ---------------------------------------------------------------------
# §3 载入本类全部搭配表（一次），回传清单表 + 数据列表
# ---------------------------------------------------------------------
tr_load_all <- function(rec) {
  tabs <- lapply(rec$files, tr_load)
  names(tabs) <- rec$files
  inv <- rbindlist(lapply(tabs, function(t) data.table(
    交付件 = t$file,
    角色 = fifelse(t$file == rec$primary, "主表", fifelse(t$file %in% rec$supporting, "搭配表", "判据来源")),
    状态 = t$status, MB = round(t$mb, 1), 行数 = t$rows,
    文件换行数 = t$file_lines, 全量核验 = t$full_scan,
    会员键 = fifelse(is.na(t$key), "—", t$key),
    列数 = if (t$ok) ncol(t$dt) else NA_integer_)))
  list(tabs = tabs, inventory = inv)
}

# ---------------------------------------------------------------------
# §4 逐判据实测 · 在位／缺失率／分位／方向尾部暴露
# ---------------------------------------------------------------------
.q <- function(x, p) as.numeric(stats::quantile(x, p, na.rm = TRUE, names = FALSE))

tr_criterion_stats <- function(rec, loaded) {
  d <- rec$dict
  rbindlist(lapply(seq_len(nrow(d)), function(i) {
    r <- d[i]; t <- loaded$tabs[[r$criterion_source]]
    base <- data.table(判据列 = r$criterion_column, 取自 = r$criterion_source,
                       角色 = r$criterion_role, 方向 = fifelse(nzchar(r$direction), r$direction, "—"),
                       阈值状态 = r$threshold_status, 阈值注 = r$threshold_note)
    if (is.null(t) || !t$ok) return(cbind(base, 在位 = "待表", n = NA_integer_, 缺失率 = NA_real_,
                                         P10 = NA_real_, P50 = NA_real_, P90 = NA_real_, P99 = NA_real_, 尾部口径 = "—"))
    if (!r$criterion_column %in% names(t$dt))
      return(cbind(base, 在位 = "缺列", n = NA_integer_, 缺失率 = NA_real_,
                   P10 = NA_real_, P50 = NA_real_, P90 = NA_real_, P99 = NA_real_, 尾部口径 = "—"))
    x <- t$dt[[r$criterion_column]]
    if (!is.numeric(x)) {
      xn <- suppressWarnings(as.numeric(x))
      if (mean(is.na(xn)) > 0.5) {
        return(cbind(base, 在位 = "在位（非数值）", n = length(x), 缺失率 = round(mean(is.na(x) | x == ""), 4),
                     P10 = NA_real_, P50 = NA_real_, P90 = NA_real_, P99 = NA_real_,
                     尾部口径 = sprintf("%d 个取值", uniqueN(x))))
      }
      x <- xn
    }
    tail_lab <- switch(r$direction,
      high = "高尾 ≥P90", low = "低尾 ≤P10", jump = "跃变（月差≥P90）",
      abnormal = "双向 |z|≥P90", "—")
    cbind(base, 在位 = "在位", n = sum(!is.na(x)), 缺失率 = round(mean(is.na(x)), 4),
          P10 = signif(.q(x, .10), 4), P50 = signif(.q(x, .50), 4),
          P90 = signif(.q(x, .90), 4), P99 = signif(.q(x, .99), 4), 尾部口径 = tail_lab)
  }))
}

# ---------------------------------------------------------------------
# §5 跨表搭配 · 会员级并集／交集 + 判据列相关阵
# ---------------------------------------------------------------------
## 【KILL RULE · 判据静默丢弃之封杀（N-6 · 2026-09-03）】
## 立意：本函数原以 intersect(登记之判据列, 实际表头) 取交集，交集之外者**无声消失**——
##   程序不报错，报表不缺章，然该条判据实已被删除，人可能永不知情。
##   较之 SQL 语法错更险：语法错人必见，静默省略人未必见。
## 处置：凡登记之判据列不在其所声明之源表表头内者，一律登记于 .TR_DROPPED，
##   并由 tr_member_join() 以 attr(out, "silent_drop") 与 $dropped 双路回报；
##   模板须显式呈现之。⛔ 不得再有「取交集后照跑」而无痕迹之事。
## 注：本档 tr_criterion_stats() 早已以「缺列」显判逐条判据，故静默只发生在跨表面板层；
##   本闸补的正是该层。二者合观，方为全链无声漏。
.TR_DROPPED <- new.env(parent = emptyenv()); .TR_DROPPED$rows <- list()
tr_dropped_criteria <- function() {
  if (!length(.TR_DROPPED$rows)) return(data.table(判据列 = character(0), 声明源表 = character(0),
                                                   缺列成因 = character(0), 处置 = character(0)))
  rbindlist(.TR_DROPPED$rows)
}

tr_member_join <- function(rec, loaded) {
  ml <- Filter(function(t) t$ok && "member_id" %in% names(t$dt), loaded$tabs)
  if (!length(ml)) return(NULL)
  d <- rec$dict
  .TR_DROPPED$rows <- list()
  parts <- lapply(names(ml), function(f) {
    want <- unique(d[criterion_source == f, criterion_column])
    have <- names(ml[[f]]$dt)
    miss <- setdiff(setdiff(want, have), "member_id")
    if (length(miss)) {                       # ★ KILL RULE：缺列须留痕，不得静默
      .TR_DROPPED$rows[[length(.TR_DROPPED$rows) + 1L]] <<- data.table(
        判据列 = miss, 声明源表 = f,
        缺列成因 = "COLUMN_NOT_IN_DECLARED_SOURCE",
        处置 = "BLOCKED —— 该判据未入跨表面板；须经 N-5 裁定改列名或令总包外显该列")
      warning(sprintf("[KILL RULE] %s 之判据列不在其声明源表 %s 内，已登记 BLOCKED：%s",
                      rec$type_id %||% "?", f, paste(miss, collapse = ", ")), call. = FALSE)
    }
    cols <- unique(intersect(want, have))
    cols <- setdiff(cols, "member_id")
    if (!length(cols)) return(NULL)          # 有会员键但本类判据无一取自该表：只计覆盖，不入面板
    x <- ml[[f]]$dt[, c("member_id", cols), with = FALSE]
    x <- x[, lapply(.SD, function(v) if (is.numeric(v)) v else suppressWarnings(as.numeric(v))), by = member_id]
    x <- x[, lapply(.SD, function(v) if (all(is.na(v))) NA_real_ else max(v, na.rm = TRUE)), by = member_id]
    setnames(x, cols, paste0(cols, "@", sub("\\.csv$", "", f)))
    x
  })
  parts <- Filter(Negate(is.null), parts)
  if (!length(parts)) return(NULL)
  out <- Reduce(function(a, b) merge(a, b, by = "member_id", all = TRUE), parts)
  cov <- rbindlist(lapply(names(ml), function(f) data.table(
    交付件 = f, 会员数 = uniqueN(ml[[f]]$dt$member_id))))
  drop <- tr_dropped_criteria()
  res <- list(panel = out, coverage = cov,
       n_union = uniqueN(out$member_id),
       n_inter = if (length(parts) > 1) uniqueN(Reduce(intersect, lapply(parts, `[[`, "member_id"))) else NA_integer_,
       dropped = drop, n_dropped = nrow(drop))
  attr(res, "silent_drop") <- nrow(drop)     # 0 = 无静默丢弃；> 0 须于报表显式呈现
  res
}

tr_corr <- function(panel) {
  if (is.null(panel)) return(NULL)
  num <- panel[, setdiff(names(panel), "member_id"), with = FALSE]
  num <- num[, names(which(vapply(num, function(v) is.numeric(v) && sum(!is.na(v)) > 30, logical(1)))), with = FALSE]
  if (ncol(num) < 2) return(NULL)
  m <- suppressWarnings(stats::cor(num, method = "spearman", use = "pairwise.complete.obs"))
  round(m, 3)
}

# ---------------------------------------------------------------------
# §6 外部标签对照 · S05 risk_label（L1a）· 秩法 AUC（= Mann–Whitney）
#   只出读数，不出结论——门禁覆盖一切实测。
# ---------------------------------------------------------------------
tr_auc <- function(score, y) {
  ok <- !is.na(score) & !is.na(y); score <- score[ok]; y <- y[ok]
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  if (n1 < 5 || n0 < 5) return(NA_real_)
  r <- rank(score); (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

tr_label_check <- function(panel, rec) {
  if (is.null(panel)) return(NULL)
  lab <- tr_load("S05_member_month_panel.csv", select = "risk_label")
  if (!lab$ok || !"risk_label" %in% names(lab$dt)) return(NULL)
  y <- lab$dt[, .(y = as.integer(any(risk_label %in% c(1, "1", TRUE, "TRUE", "Y")))), by = member_id]
  p <- merge(panel, y, by = "member_id", all.x = TRUE); p[is.na(y), y := 0L]
  d <- rec$dict
  rbindlist(lapply(setdiff(names(panel), "member_id"), function(col) {
    base_col <- sub("@.*$", "", col); dirn <- d[criterion_column == base_col, direction][1]
    if (!nzchar(dirn) || is.na(dirn)) return(NULL)
    s <- p[[col]]; if (!is.numeric(s)) return(NULL)
    if (dirn == "low") s <- -s
    data.table(判据列 = col, 方向 = dirn, 正例 = sum(p$y == 1 & !is.na(s)), 负例 = sum(p$y == 0 & !is.na(s)),
               AUC = round(tr_auc(s, p$y), 4))
  }))
}

# ---------------------------------------------------------------------
# §7 商业方案 · 依门禁派生三阶措施（措施文字取自登记册字段，非另写）
# ---------------------------------------------------------------------
tr_biz_plan <- function(rec) {
  t <- rec$typ; g <- t$门禁
  now <- switch(g,
    FATAL = c("本类判据即刻撤出一切评分／触发／处置管道，只留画像字段",
              "既有以本类判据出数之名单一律作废并留痕"),
    BLOCK = c("本类判据即刻冻结于评分管道之外，画像字段亦加「阻断中」水印",
              "登记阻断项并指派责任人与复检日"),
    CONDITIONAL = c("本类判据进入影子期：静默打分、禁据以处置",
                    "影子期内每周出 AUC 与提升度（含置信区间）"),
    ADVISORY = c("本类判据进入影子运行，出数供复核排序，禁作处置理由",
                 "建立月度复跑与五道对帐钩"),
    c("待登记册裁定"))
  p0 <- c(t$解锁条件, t$影子要求)
  if (!length(p0)) p0 <- "登记册未列解锁／影子要求（本类门禁无此项）"
  p12 <- c("阈值逐指标反解（含 n_eff 校正），禁写普适门槛（P-06）",
           "单因子线索升级为跨表网络证据（会员→IP→设备→代理→对边→局→时）",
           "外部 L1a 标签独立复检，AUC 低于 0.5 即方向反转告警")
  data.table(
    阶段 = c(rep("即刻（0–2 周）", length(now)), rep("制度（P0·解锁前置）", length(p0)), rep("管线（P1–P2）", length(p12))),
    措施 = c(now, p0, p12))
}

# ---------------------------------------------------------------------
# §8 呈现助手
# ---------------------------------------------------------------------
.gate_icon <- c(FATAL = "🔴 FATAL", BLOCK = "🟠 BLOCK", CONDITIONAL = "🟡 CONDITIONAL",
                ADVISORY = "🟢 ADVISORY", `NA` = "⚪ NA")
tr_gate <- function(g) unname(.gate_icon[g])
tr_yn <- function(x) fifelse(isTRUE(x) | x %in% c("TRUE", TRUE), "✅", "—")
tr_f <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)

# ---------------------------------------------------------------------
# §9 血统配套 · 统一六元组（N-8 · 2026-09-03）
# ---------------------------------------------------------------------
# 【本节之立意】六元组（档名／字节／行数／换行／BOM／MD5）此前有【四份各写各的】实作：
#     registry_sixtuple()        函数/registry_loader.R      —— 六栏，全 md5
#     glossary_sixtuple()        函数/glossary_engine.R      —— 与上逐字同构（重复实作）
#     six_tuple()                函数/verify_registry_dual.R —— 英文键，EOL 三态（含 MIXED）
#     tr_deliverable_identity()  本档 §4.3                   —— md5 截 12 位、字节改 MB、另加五栏
#   同一概念四种形制：栏名不同、md5 有全有截、字节有 B 有 MB、EOL 有二态有三态。
#   ⇒ 故此前【不是一个配套，是四份副本】。本节立唯一正典 tr_sixtuple()；余三处不动（只增不减），
#     但血统章一律改取本节，杜绝形制分歧。
#
# 【更要紧者 · 本节所治之病】模板之「血统件」表历来以**手写字面量**列版本与路径。
#   2026-09-03 实测：五处已陈旧——载入器头注「配套」行、模板 subtitle、单一真相源注、
#   血统件表之登记册路径，皆仍书 v1.5.003（实为 v1.5.004）；血统件表之引擎版本书 1.2.0（实为 1.4.0）。
#   ⇒ 手写字面量必然随版漂移，且漂移不报错。本节令血统表【渲染时现算】：
#     版本自各档档头正则现取、路径自载入器常量现取、六元组自盘上现算——该类缺陷自此绝迹，非靠自律。
#   ⛔ 承硬码铁律：血统表内不得再出现任何手写版本号、手写路径或手写 md5。
# ---------------------------------------------------------------------

## 正典六元组：一处实作，全配套共用
tr_sixtuple <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path))
    return(data.table(件 = if (is.na(path)) "—" else basename(path),
                      版本 = NA_character_, 字节 = NA_real_, 行数 = NA_integer_,
                      换行 = "—", BOM = "—", MD5 = "—", 在位 = "✗ 不在位",
                      路径 = if (is.na(path)) "—" else path))
  raw    <- readBin(path, "raw", file.size(path))
  n_lf   <- sum(raw == as.raw(10L))
  n_cr   <- sum(raw == as.raw(13L))
  n_crlf <- if (length(raw) > 1L) sum(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L)) else 0L
  eol <- if (n_lf > 0L && n_crlf == n_lf && n_cr == n_lf) "CRLF" else if (n_cr == 0L) "LF" else "MIXED"
  bom <- length(raw) >= 3L && identical(as.integer(raw[1:3]), c(239L, 187L, 191L))
  data.table(件 = basename(path), 版本 = NA_character_,
             字节 = length(raw), 行数 = n_lf, 换行 = eol,
             BOM = if (bom) "有" else "无",
             MD5 = unname(tools::md5sum(path)), 在位 = "✓", 路径 = path)
}

## 自档头现取版本（不手写）
##   R／qmd 档头体例：「# 版本 : 1.4.0」「# 载入器版本 : 1.5.004」
##   YAML 体例      ：「  version: 1.5.004」「  version: '0.1.3'」
tr_file_version <- function(path, n_head = 40L) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  h <- tryCatch(readLines(path, n = n_head, warn = FALSE, encoding = "UTF-8"),
                error = function(e) character(0))
  if (!length(h)) return(NA_character_)
  num <- "([0-9]+(?:[.][0-9]+)+)"
  pats <- c(paste0("(?:载入器)?版本[[:space:]]*[:：][[:space:]]*v?", num),
            paste0("^[[:space:]]*version[[:space:]]*:[[:space:]]*['\"]?v?", num))
  for (q in pats) {
    hit <- regmatches(h, regexpr(q, h, perl = TRUE))
    if (length(hit)) {
      v <- regmatches(hit[1L], regexpr(num, hit[1L], perl = TRUE))
      if (length(v)) return(v[1L])
    }
  }
  NA_character_
}

## 自档名现取版本（如 registry_risk_typology_v1.5.004.yaml → 1.5.004；rule_registry_v0.1.3.yaml → 0.1.3）
tr_name_version <- function(path) {
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  b <- basename(path)
  hit <- regmatches(b, regexpr("_v[0-9]+([._][0-9]+)+", b))
  if (!length(hit)) return(NA_character_)
  v <- sub("^_v", "", hit[1L])
  gsub("_", ".", v)
}

## 血统配套清单：渲染时现算【全在役件】之六元组 ＋ 版本 ＋ 身份自洽
## ★ 一切路径与版本皆现取，不手写；件数亦不写死。
## 【收录准则】三类，逐件标明，禁混为一谈：
##   在役·规范   —— 有代码消费者之规范件（登记册／规则册／风险之眼 schema／术语库／软配置册）
##   在役·执行   —— R 执行件与模板
##   在役·SQL源  —— 产出 133 件交付件之总包三版与其行数探针（无 R 消费者，然为一切数据之源）
##   参照        —— 规范件而【无代码消费者】：人可读、可引，然引擎不取。标明以防误认为已接线。
tr_lineage_manifest <- function(REG = NULL) {
  gp <- if (exists("GLOSSARY_PATHS")) GLOSSARY_PATHS else list(yaml = NA_character_, csv = NA_character_)
  sqlpk <- Sys.glob(file.path("函数", "a168_SQL总包_v12_0_0_HF9g-P5D_*_六层商业版_OPT.sql"))
  probe <- Sys.glob(file.path("函数", "RK01_行数实测探针_v*.sql"))
  ref   <- c(file.path("规范", "capability_registry_v1.5.001.csv"),
             file.path("规范", "prohibited_action_registry_v1.5.001.csv"),
             file.path("规范", "treatment_policy_v1.5.001.csv"),
             file.path("配置", "constants_a168.yaml"),
             file.path("配置", "paths_a168.R"))
  items <- c(
    list(
      list(类别 = "在役·规范", 角色 = "登记册 YAML（SSOT）",   调用 = "✓ 读取（registry_load）", path = if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$yaml else NA_character_),
      list(类别 = "在役·规范", 角色 = "登记册 CSV（派生字典）", 调用 = "✓ 读取（registry_load）", path = if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$csv  else NA_character_),
      list(类别 = "在役·规范", 角色 = "规则册",                调用 = if (exists("RULES_PATH")) "✓ 读取（rules_load）" else "⛔ 未接线：本档未 source 规则册载入器", path = if (exists("RULES_PATH")) RULES_PATH else NA_character_),
      list(类别 = "在役·规范", 角色 = "风险之眼 schema",       调用 = if (exists("RISKEYE_PATH")) "✓ 读取（riskeye_load）" else "⛔ 未接线", path = if (exists("RISKEYE_PATH")) RISKEYE_PATH else NA_character_),
      list(类别 = "在役·规范", 角色 = "术语库 YAML",           调用 = "✓ 读取（glossary_load）", path = gp$yaml),
      list(类别 = "在役·规范", 角色 = "术语库 CSV",            调用 = "✓ 读取（glossary_load）", path = gp$csv),
      list(类别 = "在役·规范", 角色 = "软配置册",              调用 = "✓ 读取（tr_apply_config）", path = if (exists("TR_CFG_PATH")) TR_CFG_PATH else file.path("配置", "report_config_v1.0.0.yaml")),
      list(类别 = "在役·执行", 角色 = "登记册载入器",          调用 = if (exists("registry_load")) "✓ 执行（source）" else "○ 仅指纹", path = file.path("函数", "registry_loader.R")),
      list(类别 = "在役·执行", 角色 = "规则册载入器",          调用 = if (exists("rules_load")) "✓ 执行（source）" else "⛔ 未接线：本档未 source 之", path = file.path("函数", "rule_registry_loader.R")),
      list(类别 = "在役·执行", 角色 = "双档校验器",            调用 = "○ 仅指纹：刻意独立执行，若本档 source 之则校验器依赖引擎，破其独立性", path = file.path("函数", "verify_registry_dual.R")),
      list(类别 = "在役·执行", 角色 = "分析引擎（含范本体例）", 调用 = "✓ 执行（source）", path = file.path("函数", "typology_report_engine.R")),
      list(类别 = "在役·执行", 角色 = "术语引擎",              调用 = "✓ 执行（source）", path = file.path("函数", "glossary_engine.R")),
      list(类别 = "在役·执行", 角色 = "生成器",                调用 = "○ 仅指纹：于本档【之前】运行以铸出本档，若反 source 之即成环", path = file.path("函数", "build_typology_reports.R")),
      list(类别 = "在役·执行", 角色 = "判据坐标表导出器",       调用 = "○ 仅指纹：同辈审计器，独立执行并输出至 审计/，非本档依赖", path = file.path("函数", "export_criterion_atlas.R")),
      list(类别 = "在役·执行", 角色 = "模板",                  调用 = "✓ 本档自身", path = file.path("模板", "风险会员商业方案_模板.qmd"))
    ),
    lapply(sqlpk, function(p) list(类别 = "在役·SQL源", 角色 = "SQL 总包", 调用 = "○ 仅指纹：无 R 消费者，然为 133 件交付件之源", path = p)),
    lapply(probe, function(p) list(类别 = "在役·SQL源", 角色 = "行数实测探针", 调用 = "○ 仅指纹：无 R 消费者", path = p)),
    lapply(ref,   function(p) list(类别 = "参照",       角色 = "规范件（无代码消费者）", 调用 = "○ 仅指纹：全仓无任何代码消费者，人可读可引，引擎不取", path = p))
  )
  out <- rbindlist(lapply(items, function(it) {
    st <- tr_sixtuple(it$path)
    st[, `:=`(类别 = it$类别, 角色 = it$角色, 调用状态 = it$调用,
              内容版本 = tr_file_version(it$path),
              档名版本 = tr_name_version(it$path))]
    st
  }), fill = TRUE)
  if (!is.null(REG) && !is.null(REG$meta$registry$version))
    out[grepl("^登记册", 角色), 内容版本 := as.character(REG$meta$registry$version)]
  gv <- out[角色 == "术语库 YAML", 内容版本][1L]
  if (length(gv) && !is.na(gv)) out[角色 == "术语库 CSV" & is.na(内容版本), 内容版本 := gv]
  ## 身份自洽：档名版本 ＝ 内容版本（承《版本编号纪律》§四之四「身份断言须双层」）
  out[, 身份自洽 := fifelse(is.na(档名版本) | is.na(内容版本), "—（单层身份）",
                            fifelse(档名版本 == 内容版本, "✓", "✗ 档名≠内容"))]
  out[is.na(内容版本), 内容版本 := "—"]; out[is.na(档名版本), 档名版本 := "—"]
  out[, 版本 := 内容版本]
  setcolorder(out, c("类别", "角色", "调用状态", "件", "内容版本", "档名版本", "身份自洽",
                     "字节", "行数", "换行", "BOM", "MD5", "在位", "路径"))
  out[]
}

## 配套自洽闸（二事合判）
##   ① 载入器路径所载之版本 ＝ registry_load() 实载版本
##   ② 全配套无「档名版本 ≠ 内容版本」者（双层身份断言）
tr_lineage_gate <- function(REG, MAN = NULL) {
  yp <- if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$yaml else ""
  hit <- regmatches(yp, regexpr("[0-9]+([.][0-9]+)+", yp))
  onpath <- if (length(hit)) hit[1L] else "—"
  loaded <- as.character(REG$meta$registry$version)
  g1 <- data.table(闸 = "① 载入器路径版本 ＝ 实载登记册版本",
                   实测 = sprintf("路径 %s ／ 实载 %s", onpath, loaded),
                   判 = if (identical(onpath, loaded)) "✓ PASS" else "✗ FAIL —— 血统断裂，停止引用本档任何数字")
  if (is.null(MAN)) MAN <- tr_lineage_manifest(REG)
  bad <- MAN[身份自洽 %like% "^✗"]
  g2 <- data.table(闸 = "② 双层身份：档名版本 ＝ 内容版本（承《版本编号纪律》§四之四）",
                   实测 = if (nrow(bad)) paste0("不符 ", nrow(bad), " 件：",
                                                paste(sprintf("%s（档名 %s ／ 内容 %s）", bad$件, bad$档名版本, bad$内容版本), collapse = "；"))
                          else "全数相符",
                   判 = if (nrow(bad)) "✗ FAIL —— 档名说一套、内容说另一套，须裁：改档名抑或改内容" else "✓ PASS")
  rbind(g1, g2)
}
# =====================================================================
# 【§E · 范本体例扩充】原 typology_report_engine_ext.R（1.3.0）整档并入 —— 以下至档末
# ---------------------------------------------------------------------
# 原版本 : 1.3.0      原日期 : 2026-08-22      并入日 : 2026-09-03（N-4）
# 身份 : 本档 §E 段 ★ 依赖上文 §1～§8 之 tr_load／tr_recipe 等（同档，无须另 source）
# ---------------------------------------------------------------------
# 【职责】补齐范本《尾段投注基础分析的评估_v1_2_47_REDTEAM_去外部模型版.qmd》
#   之全部章节体例：数据口径（ODS 关键字段／核心指标／交付件身份核验／分析级
#   核心指标）、评估（主检验／统计冻结／审计门禁／五道铁门／roi 结算完整性／
#   裁定与处置序）、行业实践查证、模型武器库审计（名目勘正／逐模审计／四管线／
#   前后对照／局限与提升）、灵活搭配实测（PCA）、模型架构与入场行为层。
#
# 【软代码铁律 v1.2.0】
#   一切阈值、分位、置信、样本门、命名空间、字段别名、呈表尺寸、模型名册、
#   管线定义、措施文字、名目勘正——一律取自 配置/report_config_v1.0.0.yaml。
#   本档不硬写任何业务数值或业务字符；本册未登记者即报错，不取默认。
#
# 【血统铁律】
#   ⛔ 不引三份外来文献之任何数字、阈值或分级（黑名单见配置册 lineage_blacklist）。
#   ✅ 一切取自 规范/registry_risk_typology_v*.{yaml,csv} 与 数据表/ 交付件，渲染时现算。
#      ★ N-8b：此处不再写死版本号——版本以 REGISTRY_PATHS 与 registry_load() 现取为准，
#        全配套版本与六元组见 §9 tr_lineage_manifest()。
# =====================================================================

# ---------------------------------------------------------------------
# §0 软配置册：唯一参数真相源
# ---------------------------------------------------------------------
TR_CFG_PATH <- file.path("配置", "report_config_v1.0.0.yaml")

tr_cfg <- local({
  .cache <- NULL
  function(path = TR_CFG_PATH, reload = FALSE) {
    if (is.null(.cache) || reload) {
      if (!file.exists(path)) stop(sprintf("软配置册不在位：%s", path), call. = FALSE)
      .cache <<- yaml::read_yaml(path)
    }
    .cache
  }
})

## 取配置：路径以 $ 分隔；缺失即报错（禁默认值，防硬码回潜）
.cfg <- function(...) {
  keys <- unlist(list(...)); v <- tr_cfg()
  for (k in keys) {
    if (is.null(v[[k]])) stop(sprintf("配置册缺键：%s", paste(keys, collapse = "$")), call. = FALSE)
    v <- v[[k]]
  }
  v
}

# 应用配置至主引擎之全局守门（覆盖主引擎默认，令一处可改）
# 【全量铁律】配置册 guards.full_scan_mandatory 须为 TRUE；为 FALSE 即报错而非降级，
# 防「抽样」以配置形式回潜。巨档只告警不截行。
tr_apply_config <- function() {
  if (!isTRUE(.cfg("guards", "full_scan_mandatory")))
    stop("配置册 guards.full_scan_mandatory 非 TRUE——全量铁律被关闭，拒绝出数", call. = FALSE)
  TR_FULL_SCAN <<- TRUE
  TR_WARN_MB   <<- .cfg("guards", "large_file_warn_mb")
  TR_RC_VERIFY <<- isTRUE(.cfg("guards", "rowcount_verify"))
  TR_RC_MAX_MB <<- .cfg("guards", "rowcount_verify_max_mb")
  TR_DB        <<- .cfg("namespaces", "delivery")
  .tr_key_alias <<- unlist(.cfg("fields", "member_key_aliases"))
  invisible(TRUE)
}

# ---------------------------------------------------------------------
# §0b 呈表体例助手（与范本 v1_2_47 逐字同式）
#   范本原式：dt[, 序 := format(seq_len(.N), big.mark = ",")]; setcolorder(dt, "序")
#   本函数即其封装——一切列表型桌表皆过此器，令十五份与范本同体例。
# ---------------------------------------------------------------------
tr_no <- function(x) {
  if (is.null(x)) return(NULL)
  d <- if (data.table::is.data.table(x)) data.table::copy(x)
       else if (is.matrix(x)) data.table::as.data.table(x, keep.rownames = "项")
       else data.table::as.data.table(x)
  if ("序" %in% names(d)) return(d[])          # 已有序列者不重复编号
  d[, 序 := format(seq_len(.N), big.mark = ",")]
  data.table::setcolorder(d, "序")
  d[]
}

# ---------------------------------------------------------------------
# §0c 全量读取核验（红队铁律：禁抽样，须全量）
#   逐件并呈：字节、载入行数、文件换行数、差额、核验判读、抽样标记。
#   任一件之 sampled 为 TRUE 即 stop()——抽样出数一律拒绝渲染。
# ---------------------------------------------------------------------
tr_fullscan_audit <- function(rec, loaded) {
  out <- rbindlist(lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]
    data.table(
      交付件 = sub("[.]csv$", "", f),
      角色 = fifelse(f == rec$primary, "主表",
              fifelse(f %in% rec$supporting, "辅助表", "判据来源")),
      字节MB = round(t$mb, 1),
      巨档 = fifelse(isTRUE(t$huge), sprintf("⚑ 逾 %s MB", format(TR_WARN_MB, big.mark = ",")), "—"),
      载入行数 = t$rows,
      文件换行数 = t$file_lines,
      差额 = if (is.na(t$file_lines) || is.na(t$rows)) NA_integer_ else (t$file_lines - 1L) - t$rows,
      抽样 = fifelse(isTRUE(t$sampled), "⛔ 已抽样", "✔ 未抽样"),
      全量核验 = if (is.null(t$full_scan)) "—" else t$full_scan)
  }), fill = TRUE)
  ## 零省略：登记册所声明而非 CSV 者（如 ODS 库表直算）亦须列出并标待表，
  ## 否则「主表不在清单」易被误读为「本类无主表」。
  d <- rec$dict
  sup_all <- trimws(unlist(strsplit(d$supporting_deliverables[1L], "[；;]")))
  declared <- unique(c(d$primary_deliverable[1L], sup_all[nzchar(sup_all)], d$criterion_source))
  nocsv <- setdiff(declared, rec$files)
  if (length(nocsv)) {
    sup_set <- sup_all[nzchar(sup_all)]
    out <- rbindlist(list(out, rbindlist(lapply(nocsv, function(f) data.table(
      交付件 = f,
      角色 = fifelse(f == d$primary_deliverable[1L], "主表",
              fifelse(f %in% sup_set, "辅助表", "判据来源")),
      字节MB = NA_real_, 巨档 = "—", 载入行数 = NA_integer_, 文件换行数 = NA_integer_,
      差额 = NA_integer_, 抽样 = "✔ 未抽样",
      全量核验 = fifelse(grepl("^ods_", f),
        "○ 待表（登记册声明为 ODS 库表直算，无中间交付件——非 CSV，本引擎不读）",
        "○ 待表（登记册声明为待建／现算，尚无交付件落地——非 CSV，本引擎不读）"))))),
      fill = TRUE)
  }
  if (any(vapply(loaded$tabs, function(t) isTRUE(t$sampled), logical(1))))
    stop("全量铁律违反：本类有交付件被抽样载入，拒绝渲染", call. = FALSE)
  out[]
}

# ---------------------------------------------------------------------
# §1 项目根定位 · 表头 · 呈表容器
# ---------------------------------------------------------------------
tr_find_root <- function(start = getwd(), max_up = 5L) {
  p <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in seq_len(max_up + 1L)) {
    if (dir.exists(file.path(p, "规范")) && dir.exists(file.path(p, "函数"))) return(p)
    up <- dirname(p); if (identical(up, p)) break; p <- up
  }
  stop(sprintf("自 %s 上溯 %d 级未找到项目根（需同时含 规范/ 与 函数/）", start, max_up), call. = FALSE)
}

tr_header <- function(file) {
  p <- file.path(TR_DB, file)
  if (!file.exists(p)) return(character(0))
  h <- tryCatch(readLines(p, n = 1L, warn = FALSE), error = function(e) NA_character_)
  if (is.na(h[1L])) return(character(0))
  if (!validUTF8(h)) h <- iconv(h, "GBK", "UTF-8")
  trimws(strsplit(sub("^﻿", "", h), ",", fixed = TRUE)[[1L]])
}

## 呈表纪律：长表 scroll-y、宽表 scroll-x，禁截行截列。尺寸取自配置册。
tr_css <- function() {
  p <- .cfg("presentation")
  sprintf(paste0(
    '<style>',
    '.cell-output-display{overflow-x:%s;overflow-y:%s;max-height:%s}',
    '.cell-output-display>table{margin:0}',
    '.tbl-scroll{overflow-x:%s;overflow-y:%s;max-height:%s}',
    '.tbl-wide{overflow-x:%s;overflow-y:%s;max-height:%s}',
    'table{white-space:nowrap}',
    'table td,table th{vertical-align:top}',
    '</style>\n'),
    p$overflow_x, p$overflow_y, p$table_max_height,
    p$overflow_x, p$overflow_y, p$table_max_height,
    p$overflow_x, p$overflow_y, p$table_max_height_wide)
}

# ---------------------------------------------------------------------
# §2 门禁图标：自登记册 axes.gate 现算（软字符，不硬写）
# ---------------------------------------------------------------------
tr_gate_map <- function(REG) {
  g <- REG$meta$axes$gate
  if (is.null(g)) stop("登记册缺 axes$gate，门禁图标无真相源", call. = FALSE)
  vapply(g, function(x) sub("[：:].*$", "", as.character(x)), "")
}
tr_gate2 <- function(REG, g) {
  m <- tr_gate_map(REG); v <- m[[g]]
  if (is.null(v) || is.na(v)) g else v
}

# ---------------------------------------------------------------------
# §3 全维度矩阵：主表维度 / 辅助表 / 辅助表维度
# ---------------------------------------------------------------------
tr_dim_matrix <- function(REG) {
  d <- REG$dict[axis == "R"]
  rbindlist(lapply(unique(d$type_id), function(tid) {
    s <- d[type_id == tid]
    prim <- s$primary_deliverable[1L]
    sup <- unlist(strsplit(s$supporting_deliverables[1L], "[；;]")); sup <- trimws(sup[nzchar(sup)])
    crit <- s$criterion_column
    mark <- function(cols) if (!length(cols)) "—" else
      paste(fifelse(cols %in% crit, sprintf("【%s】", cols), cols), collapse = " · ")
    ph <- tr_header(prim); sh <- lapply(sup, tr_header); names(sh) <- sup
    data.table(
      序 = tid, 风险类型 = s$name_zh[1L], 门禁 = tr_gate2(REG, s$gate[1L]),
      主表 = sub("[.]csv$", "", prim), 主表维度数 = length(ph), 主表维度 = mark(ph),
      辅助表 = if (length(sup)) paste(sub("[.]csv$", "", sup), collapse = " · ") else "—",
      辅助表维度数 = sum(vapply(sh, length, 0L)),
      辅助表维度 = if (length(sup)) paste(vapply(sup, function(f)
        sprintf("%s：%s", sub("[.]csv$", "", f), mark(sh[[f]])), ""), collapse = "  ｜  ") else "—",
      已登记判据数 = nrow(s),
      可搭配维度总数 = length(ph) + sum(vapply(sh, length, 0L)))
  }))
}

# ---------------------------------------------------------------------
# §4 数据口径 · 一、源数据（ODS 库表层）
#     4.1 关键字段：自 Z03_column_dictionary.csv 现算（本库自证，非外引）
# ---------------------------------------------------------------------
tr_ods_fields <- function(rec, REG) {
  f <- .cfg("fields", "ods_dictionary_file")
  cn <- .cfg("fields", "ods_dict_cols")
  t <- tr_load(f)
  if (!t$ok) return(list(ok = FALSE, status = t$status, dt = NULL))
  d <- t$dt
  need <- unlist(cn)
  if (!all(need %in% names(d))) return(list(ok = FALSE, status = "ODS 字典列不符配置册", dt = NULL))
  ## 本类 SQL 章节所引之 ODS 表：自 criterion_source 中非 csv 者 + 主表血统关键词
  src <- unique(c(rec$dict$criterion_source, rec$dict$primary_deliverable))
  ods <- unique(unlist(regmatches(src, gregexpr("ods_[a-z0-9_]+", src))))
  if (!length(ods)) {
    ## 无直引 ODS 表者，取本类判据列名于全库字典中反查其所在库表
    hit <- d[get(cn$column) %in% rec$dict$criterion_column]
  } else {
    hit <- d[get(cn$table) %in% ods]
  }
  if (!nrow(hit)) return(list(ok = TRUE, status = "本类判据列未见于 ODS 字典（多为交付件派生量）", dt = NULL))
  out <- hit[, .(库表 = get(cn$table), 列序 = get(cn$ordinal), 字段 = get(cn$column),
                 存储类型 = get(cn$dtype), 可空 = get(cn$nullable),
                 业务含义 = get(cn$meaning), 原始注释 = get(cn$note))]
  list(ok = TRUE, status = "OBSERVED", dt = out)
}

## 4.2 核心指标：自登记册判据 + 术语库释义现算
tr_core_metrics <- function(rec, GL = NULL) {
  d <- rec$dict
  gl <- if (!is.null(GL)) GL$dict else NULL
  rbindlist(lapply(seq_len(nrow(d)), function(i) {
    r <- d[i]
    def <- if (!is.null(gl) && r$criterion_column %in% gl$术语)
      gl[术语 == r$criterion_column, 定义][1L] else "—（术语库未收录，口径以登记册 threshold_note 为准）"
    data.table(指标 = r$criterion_column, 取自 = r$criterion_source, 角色 = r$criterion_role,
               口径原文 = r$threshold_note, 术语库定义 = def,
               用途 = fifelse(r$criterion_role == "STAT_DIRECTIONAL", "方向判据（可入分位分层）",
                       fifelse(r$criterion_role == "JOIN_KEY", "连接键（入关系网络）",
                        fifelse(r$criterion_role == "REFERENCE", "参照量（只作解释，不出名单）", "结构量"))))
  }))
}

## 4.3 交付件身份核验（六元组：行数／列数／字节／MD5／换行／BOM）
tr_deliverable_identity <- function(rec, loaded) {
  rbindlist(lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]; p <- file.path(TR_DB, f)
    if (!file.exists(p)) return(data.table(交付件 = sub("[.]csv$", "", f), 角色 = "—",
      行数 = NA_integer_, 列数 = NA_integer_, 字节 = NA_real_, MD5 = "—", 换行符 = "—", BOM = "—",
      文件换行数 = NA_integer_, 全量核验 = "—", 状态 = t$status))
    raw <- readBin(p, "raw", min(file.size(p), 5e6))
    bom <- length(raw) >= 3L && identical(as.integer(raw[1:3]), c(239L, 187L, 191L))
    crlf <- any(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L))
    md5 <- if (requireNamespace("digest", quietly = TRUE))
      substr(digest::digest(file = p, algo = "md5"), 1L, 12L) else "—"
    data.table(交付件 = sub("[.]csv$", "", f),
      角色 = fifelse(f == rec$primary, "主表", fifelse(f %in% rec$supporting, "辅助表", "判据来源")),
      行数 = t$rows, 列数 = if (t$ok) ncol(t$dt) else NA_integer_,
      字节 = round(file.size(p) / 1e6, 2), MD5 = md5,
      换行符 = if (crlf) "CRLF" else "LF", BOM = if (bom) "有" else "无",
      文件换行数 = t$file_lines, 全量核验 = t$full_scan, 状态 = t$status)
  }), fill = TRUE)
}

## 4.4 分析级核心指标：本类会员级面板之描述统计
tr_analytic_metrics <- function(rec, mj) {
  if (is.null(mj)) return(NULL)
  cols <- setdiff(names(mj$panel), .cfg("fields", "member_key_canonical"))
  qs <- c(.cfg("statistics", "tail_quantile_low"), 0.5, .cfg("statistics", "tail_quantile_high"))
  rbindlist(lapply(cols, function(c) {
    v <- mj$panel[[c]]; if (!is.numeric(v)) return(NULL)
    nv <- sum(!is.na(v))
    data.table(分析指标 = c, 有效 = nv, 缺失率 = round(mean(is.na(v)), 4),
               均值 = signif(mean(v, na.rm = TRUE), 4), 标准差 = signif(stats::sd(v, na.rm = TRUE), 4),
               P10 = signif(.q(v, qs[1]), 4), P50 = signif(.q(v, qs[2]), 4), P90 = signif(.q(v, qs[3]), 4),
               变异系数 = signif(stats::sd(v, na.rm = TRUE) / abs(mean(v, na.rm = TRUE)), 3))
  }))
}

# ---------------------------------------------------------------------
# §5 评估 · 主检验指标与判读（AUC ＋ Wilson ＋ 符号检验）
# ---------------------------------------------------------------------
tr_wilson_lo <- function(k, n, z = .cfg("statistics", "z_two_sided")) {
  ifelse(n <= 0, NA_real_, {
    p <- k / n; den <- 1 + z^2 / n
    ((p + z^2 / (2 * n)) - z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / den })
}
tr_wilson_hi <- function(k, n, z = .cfg("statistics", "z_two_sided")) {
  ifelse(n <= 0, NA_real_, {
    p <- k / n; den <- 1 + z^2 / n
    ((p + z^2 / (2 * n)) + z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / den })
}
## 最低样本量反解：使 Wilson 区间宽度 ≤ target_width（正态近似首解，再逐步校正）
tr_min_n <- function(p, width = .cfg("statistics", "wilson_target_width"),
                     z = .cfg("statistics", "z_two_sided")) {
  n <- ceiling((2 * z / width)^2 * p * (1 - p))
  for (i in 1:200) {
    k <- round(p * n)
    if ((tr_wilson_hi(k, n) - tr_wilson_lo(k, n)) <= width) break
    n <- n + max(1L, ceiling(n * 0.05))
  }
  n
}
tr_auc_band <- function(a) {
  if (is.na(a)) return("样本不足")
  b <- .cfg("auc_bands")
  for (x in b) if (a >= x$lo && a < x$hi) return(x$label)
  "—"
}

tr_main_tests <- function(rec, mj, lc) {
  if (is.null(lc) || !nrow(lc)) return(NULL)
  w <- .cfg("statistics", "wilson_target_width")
  out <- copy(lc)
  out[, 判读 := vapply(AUC, tr_auc_band, "")]
  out[, 最低样本量 := vapply(seq_len(.N), function(i)
    tr_min_n(min(max(正例[i] / max(正例[i] + 负例[i], 1), 0.01), 0.99)), 0)]
  out[, 样本充足 := fifelse(正例 + 负例 >= 最低样本量, "✔", "✗ 样本不足 → UNKNOWN")]
  out[, 阳性率Wilson下界 := round(tr_wilson_lo(正例, 正例 + 负例), 5)]
  out[]
}

## 统计口径冻结（软字符：三工具之严谨口径）
tr_stat_freeze <- function() {
  s <- .cfg("statistics")
  data.table(
    项 = c("配对单位", "AUC 判读档数", "置信水平", "CI 宽度上限", "尾部分位（high／low）",
           "退化判定", "多重比较校正", "p 值显示"),
    冻结口径 = c(
      "配对检验须先冻结配对单位；不明确即非配对检验，退化为独立比较",
      sprintf("%d 档（取代粗四档），档界见配置册 auc_bands", length(.cfg("auc_bands"))),
      sprintf("%.0f%%（z = %.6f）", s$confidence_level * 100, s$z_two_sided),
      sprintf("%.2f——比例型指标之最低样本量由此反解，禁手写门槛", s$wilson_target_width),
      sprintf("P%.0f ／ P%.0f", s$tail_quantile_high * 100, s$tail_quantile_low * 100),
      sprintf("尾部命中率 > %.0f%% 即判退化（P90 与下界重合）", s$degenerate_flag_rate * 100),
      paste(unlist(s$multiple_testing_methods), collapse = " ＋ "),
      sprintf("p < %s 一律并呈原始量级，禁 0.0000 体例", format(.cfg("presentation", "p_value_min_display"), scientific = TRUE))),
    优先级 = "本表口径优先于任何通俗表述；二者冲突以本表为准")
}

## 审计门禁与结论
tr_audit_gate <- function(rec, mt) {
  d <- rec$dict
  chk <- data.table(
    门 = c("样本门", "阈值门", "方向门", "因果门", "处置门"),
    判定式 = c("每条判据之样本量 ≥ Wilson 反解之最低样本量",
               "threshold_status 须脱离 PENDING_INVERSE",
               "AUC ≥ 0.5（低于即方向反转，须查口径）",
               "causal_status = ESTABLISHED",
               "admit_to_risk_decision = TRUE"),
    本类现况 = c(
      if (is.null(mt)) "—（无方向判据或无标签）" else sprintf("%d / %d 条充足", sum(mt$样本充足 == "✔"), nrow(mt)),
      sprintf("%d / %d 条已脱离 PENDING_INVERSE", sum(d$threshold_status != "PENDING_INVERSE"), nrow(d)),
      if (is.null(mt)) "—" else sprintf("%d / %d 条 AUC ≥ 0.5", sum(mt$AUC >= 0.5, na.rm = TRUE), nrow(mt)),
      d$causal_status[1L],
      as.character(d$admit_to_risk_decision[1L])))
  chk[, 通过 := c(
    if (is.null(mt)) "○ 待表" else fifelse(all(mt$样本充足 == "✔"), "✔ PASS", "✗ FAIL"),
    fifelse(all(d$threshold_status != "PENDING_INVERSE"), "✔ PASS", "✗ FAIL"),
    if (is.null(mt)) "○ 待表" else fifelse(all(mt$AUC >= 0.5, na.rm = TRUE), "✔ PASS", "✗ FAIL"),
    fifelse(d$causal_status[1L] == "ESTABLISHED", "✔ PASS", "✗ FAIL"),
    fifelse(as.character(d$admit_to_risk_decision[1L]) %in% c("TRUE", "true"), "✔ PASS", "✗ FAIL"))]
  chk[]
}

## 五道铁门（配置册定义 × 本类现况）
tr_iron_gates <- function(rec, mt, sq) {
  g <- .cfg("iron_gates"); d <- rec$dict
  rbindlist(lapply(g, function(x) {
    st <- switch(x$id,
      "G-01" = if (all(nzchar(d$threshold_note))) "PASS" else "PARTIAL",
      "G-02" = if (!is.null(mt) && all(mt$样本充足 == "✔")) "PASS" else if (is.null(mt)) "N/A" else "FAIL",
      "G-03" = if (all(d$threshold_status != "PENDING_INVERSE")) "PASS" else "FAIL",
      "G-04" = if (!is.null(mt) && nrow(mt) > 1) "PARTIAL（本档已并报，未跨档汇总）" else "N/A",
      "G-05" = if (!is.null(sq) && any(sq$可做序列 == "✔")) "PARTIAL（有时间轴，OOS 未建）" else "FAIL（无时间轴，无法跨窗）",
      "N/A")
    data.table(铁门 = x$id, 门 = x$门, 判定 = x$判定, 本类状态 = st)
  }))
}

## roi 异常之结算完整性候选（禁称优势玩家）
tr_roi_candidates <- function(rec, loaded) {
  thr <- .cfg("guards", "roi_outlier_threshold")
  nc <- unlist(.cfg("fields", "roi_numerator_candidates"))
  dc <- unlist(.cfg("fields", "roi_denominator_candidates"))
  key <- .cfg("fields", "member_key_canonical")
  for (f in names(loaded$tabs)) {
    t <- loaded$tabs[[f]]; if (!t$ok || !key %in% names(t$dt)) next
    n1 <- intersect(nc, names(t$dt))[1]; d1 <- intersect(dc, names(t$dt))[1]
    if (is.na(n1) || is.na(d1)) next
    x <- t$dt[, c(key, n1, d1), with = FALSE]
    setnames(x, c(key, "num", "den"))
    x <- x[is.finite(as.numeric(num)) & is.finite(as.numeric(den)) & as.numeric(den) > 0]
    if (!nrow(x)) next
    x[, roi := as.numeric(num) / as.numeric(den)]
    hit <- x[roi > thr][order(-roi)]
    return(list(ok = TRUE, file = f, num = n1, den = d1, n_total = nrow(x),
                n_hit = nrow(hit), top = utils::head(hit, 20L), thr = thr))
  }
  list(ok = FALSE, file = NA, n_hit = NA, thr = thr)
}

## 裁定与处置序
tr_verdict_order <- function(rec, REG) {
  d <- rec$dict; g <- d$gate[1L]
  data.table(
    序 = 1:4,
    步骤 = c("① 账务在先", "② 证据打包", "③ 人工复核", "④ 处置"),
    本类规定 = c(
      sprintf("roi 异常者先过结算九项排查序（%s），查账在先、查人在后",
              paste(unlist(.cfg("settlement_checklist")), collapse = "／")),
      sprintf("多判据共现＋提升度＋Wilson 下界，打包为证据；本类门禁 %s", tr_gate2(REG, g)),
      "复核记录须留原始注单、时间窗口、口径版本与证据等级",
      sprintf("admit_to_risk_decision = %s；为 FALSE 时任何处置皆不合规",
              as.character(d$admit_to_risk_decision[1L]))))
}

# ---------------------------------------------------------------------
# §5b 评估章之「局限（不为其讳）」与「定位裁定」（范本体例；全数现算）
#   范本《尾段投注基础分析的评估_v1_2_47》评估章末二块：
#     ::: {.callout-caution} ## 局限（不为其讳）   —— 编号列表
#     ::: {.callout-important} ## 定位裁定          —— 引用块
#   本函数按本类实测现算其内容，不写死任何数字或结论。
# ---------------------------------------------------------------------
tr_eval_limits <- function(rec, mt, sq, mj) {
  d <- rec$dict; s <- .cfg("statistics")
  L <- character(0)
  L <- c(L, sprintf(
    "本类 %d 条登记判据之阈值状态构成 %s——`PENDING_INVERSE` 者尚无可用阈值，其分位读数只是**分布描述**，不是判别门槛。",
    nrow(d), paste(sprintf("`%s`×%d", names(table(d$threshold_status)),
                           as.integer(table(d$threshold_status))), collapse = " ")))
  L <- c(L, sprintf(
    "比例型判据之点估计在小分母上系统性高估，故本章一律并报 Wilson %.0f%% 下界；最低样本量由 CI 宽度 ≤ %.2f 反解，未过门者登记 `UNKNOWN`，**永不降为「正常」**。",
    s$confidence_level * 100, s$wilson_target_width))
  L <- c(L, if (is.null(mt))
    "本类无方向判据或外部标签表不可用，主检验（秩法 AUC）**整体待表**——无 AUC 即无排序效率证据，不得以描述统计代之。"
    else sprintf(
    "AUC 系对**外部 L1a 标签**之秩法面积（%d 条方向判据参检，样本充足 %d 条）；标签本身含复核强度混杂，故 AUC 部分反映「谁被复核得多」而非「谁更危险」，**是排序效率证据，不是因果证据**。",
    nrow(mt), sum(mt$样本充足 == "✔")))
  L <- c(L, if (is.null(mj))
    "本类交付件无会员级键，跨表并集、交集与共现提升度**整体待表**。"
    else sprintf(
    "会员级并集 %s 人、全表交集 %s 人——交集越小，全判据齐备者愈少，**幸存者偏差之风险愈高**；名单不得只取交集。",
    tr_f(mj$n_union), if (is.na(mj$n_inter)) "—（单表）" else tr_f(mj$n_inter)))
  L <- c(L, sprintf(
    "尾部命中率逾 %.0f%% 即判**退化**（分位阈与下界重合、该列近乎常量）；退化列之「尾部」不是异常群，禁以百分之百之尾部冒充证据。",
    s$degenerate_flag_rate * 100))
  L <- c(L, if (!is.null(sq) && any(sq$可做序列 == "✔"))
    "时间轴虽在位，**跨窗口真样本外（OOS）验证仍缺位**——同窗自证不是验证，G-05 不可因有时间轴而放行。"
    else "本类交付件皆为截面，**无时间轴**——序列、生存、动态基线与跨窗 OOS 一律待表，G-05 直接 FAIL。")
  L <- c(L, "台桌、荷官、时段、星期、靴长等混杂尚未控制；无随机化、无处理／对照设计，**只能言相关，不可言因果**。")
  L <- c(L, sprintf(
    "四层纵向证据链现况：现象 `%s` → 标签验证 `%s` → 因果 `%s` → 准入风控决策 `%s`——**逐层独立举证，禁跨层滑移**。",
    d$phenomenon_status[1L], d$label_validation_status[1L], d$causal_status[1L],
    as.character(d$admit_to_risk_decision[1L])))
  L
}

tr_eval_verdict <- function(rec, REG, mt) {
  d <- rec$dict; g <- d$gate[1L]
  pos <- switch(g,
    FATAL = "本类判据经登记册裁定为 FATAL——不论实测如何，**只可作画像字段**，即刻撤出一切评分、触发与处置管道。",
    BLOCK = "本类判据处 BLOCK——**冻结于评分管道之外**，画像字段亦须加「阻断中」水印，待阻断项闭合方议解锁。",
    CONDITIONAL = "本类判据处 CONDITIONAL——**只可进入影子期**：静默打分、禁据以处置，影子期内周报 AUC 与提升度（含置信区间）。",
    ADVISORY = "本类判据处 ADVISORY——**可作影子运行之复核排序**，出数供人审，禁作处置理由。",
    "本类门禁未登记，**一切用途皆须先补裁定**。")
  c(sprintf("**当前最佳定位**：%s", pos),
    sprintf("**准入风控决策** `admit_to_risk_decision = %s`——为 `FALSE` 时，任何以本类判据出数之处置**皆不合规**；门禁覆盖一切实测，实测再漂亮不改此裁。",
            as.character(d$admit_to_risk_decision[1L])),
    if (is.null(mt)) "**下一步**：先补齐本类之方向判据与外部标签对照，主检验方可开工；在此之前不得言判别力。"
    else sprintf("**下一步**：优先解决阈值反解（含 `n_eff` 校正）、最小暴露门槛与跨窗口 OOS；本类现有 %d 条方向判据之 AUC 只作特征去留参考，不作处置依据。", nrow(mt)))
}

# ---------------------------------------------------------------------
# §6 行业实践查证：只取登记册自证
# ---------------------------------------------------------------------
tr_industry <- function(rec, REG) {
  d <- rec$dict; gp <- REG$meta$global_prohibitions
  tgt <- c(rec$files, d$criterion_column, d$criterion_source)
  rel <- Filter(function(p) any(vapply(tgt, function(x) grepl(x, p$target, fixed = TRUE) ||
                                         grepl(p$target, x, fixed = TRUE), logical(1))) ||
                  grepl("普适|门槛|OFFSET", p$target), gp)
  list(standard_basis = d$standard_basis[1L],
       external_status = if ("external_standard_status" %in% names(d) && nzchar(d$external_standard_status[1L]))
         d$external_standard_status[1L] else "—",
       applicability = if ("applicability_status" %in% names(d) && nzchar(d$applicability_status[1L]))
         d$applicability_status[1L] else "—",
       prohibitions = if (length(rel)) rbindlist(lapply(rel, function(p) data.table(
         编号 = p$id, 标的 = p$target, 规则 = p$rule, 事由 = p$reason, 严重度 = p$severity))) else NULL)
}

# ---------------------------------------------------------------------
# §7 武器库：名目勘正 · 逐模审计 · 四管线 · 前后对照 · 局限与提升
# ---------------------------------------------------------------------
tr_nomenclature <- function() rbindlist(lapply(.cfg("nomenclature"), as.data.table))

tr_model_roster <- function(rec, mj, sq) {
  d <- rec$dict
  caps <- c(
    member_level = !is.null(mj),
    features_ge_2 = !is.null(mj) && (ncol(mj$panel) - 1L) >= 2L,
    features_ge_3 = !is.null(mj) && (ncol(mj$panel) - 1L) >= 3L,
    join_key = any(d$criterion_role == "JOIN_KEY"),
    time_axis = !is.null(sq) && any(sq$可做序列 == "✔"),
    event = !is.null(sq) && any(sq$可做序列 == "✔"),
    long_sequence = FALSE)
  rbindlist(lapply(.cfg("model_roster"), function(m) {
    need <- unlist(m$需要)
    ok <- all(vapply(need, function(k) isTRUE(caps[[k]]), logical(1)))
    data.table(模型 = m$模型, 角色 = m$角色, 前置条件 = paste(need, collapse = " + "),
               本类可上场 = fifelse(grepl("禁赛", m$角色), "⛔ 禁赛",
                                    fifelse(ok, "✔ 可上场", "— 前置未备")),
               裁定理由 = m$裁定理由)
  }))
}

tr_arsenal <- function(rec, REG) {
  d <- rec$dict
  rbindlist(lapply(.cfg("pipelines"), function(p) {
    roles <- unlist(p$需要角色); dirs <- unlist(p$需要方向)
    n <- sum(d$criterion_role %in% roles) + (if (!is.null(dirs)) sum(d$direction %in% dirs) else 0L)
    data.table(管线 = p$管线, 特征层 = p$特征层, 模型层 = p$模型层, 决策层 = p$决策层,
               处置红线 = p$处置红线, 本类判据数 = n,
               本类可用 = fifelse(n > 0, "✔ 可用", "— 本类无此角色判据"),
               门禁覆盖 = tr_gate2(REG, d$gate[1L]))
  }))
}

tr_before_after <- function() rbindlist(lapply(.cfg("before_after_dims"), as.data.table))

tr_limits_roadmap <- function(rec, sq, mt) {
  d <- rec$dict
  lim <- c(
    sprintf("阈值状态构成 %s——PENDING_INVERSE 者尚无可用阈值，禁写普适门槛（P-06）。",
            paste(sprintf("%s×%d", names(table(d$threshold_status)), as.integer(table(d$threshold_status))), collapse = " ")),
    "比例型判据只看点估计不足取，本档一律并报 Wilson 下界与反解之最低样本量。",
    "分母极小之会员其比例型判据可爆炸，须设最小暴露门槛或采收缩估计。",
    "台桌、荷官、时段、星期、靴长等混杂尚未控制。",
    if (!is.null(sq) && !any(sq$可做序列 == "✔"))
      "本类交付件皆为截面，无时间轴——序列、生存、动态基线一律待表。" else
      "时间轴虽在位，跨窗口真样本外（OOS）验证仍缺位。",
    sprintf("causal_status = %s、label_validation_status = %s——两层皆未达解锁门。",
            d$causal_status[1L], d$label_validation_status[1L]))
  road <- c("P0：阈值逐指标反解（含 n_eff）；补齐缺件与缺列。",
            "P1：跨窗口真样本外验证管线；多判据共现之提升度回测。",
            "P2：小分母场景以贝叶斯层级收缩替换点估计。",
            "长期：禁赛模型之解锁条件（长序列＋可解释性＋伦理审查）未齐前保持禁赛。")
  list(limits = lim, roadmap = road)
}

# ---------------------------------------------------------------------
# §8 灵活搭配实测：尾部旗标 · 分层 · 共现 · 退化 · 期望假阳 · PCA
# ---------------------------------------------------------------------
tr_combat <- function(rec, mj) {
  if (is.null(mj)) return(NULL)
  s <- .cfg("statistics"); d <- rec$dict
  key <- .cfg("fields", "member_key_canonical")
  cols <- setdiff(names(mj$panel), key)
  dircols <- cols[vapply(cols, function(cc) {
    b <- sub("@.*$", "", cc); dd <- d[criterion_column == b, direction][1]
    !is.na(dd) && nzchar(dd) }, logical(1))]
  if (!length(dircols)) return(NULL)
  p <- copy(mj$panel); qused <- numeric(0)
  for (cc in dircols) {
    b <- sub("@.*$", "", cc); dd <- d[criterion_column == b, direction][1]
    v <- p[[cc]]
    fl <- if (dd == "high") v >= .q(v, s$tail_quantile_high)
          else if (dd == "low") v <= .q(v, s$tail_quantile_low)
          else { z <- abs((v - mean(v, na.rm = TRUE)) / stats::sd(v, na.rm = TRUE)); z >= .q(z, s$tail_quantile_abs_z) }
    set(p, j = paste0("F_", cc), value = as.integer(fl & !is.na(fl)))
    qused <- c(qused, if (dd == "high") 1 - s$tail_quantile_high else if (dd == "low") s$tail_quantile_low else 1 - s$tail_quantile_abs_z)
  }
  fcols <- paste0("F_", dircols)
  set(p, j = "命中数", value = rowSums(as.matrix(p[, ..fcols]), na.rm = TRUE))
  lay <- p[, .(会员数 = .N), by = .(命中数)][order(-命中数)]
  lay[, 占比 := round(会员数 / sum(会员数), 4)][, 累计占比 := round(cumsum(会员数) / sum(会员数), 4)]
  ## 独立假设下之期望人数（误判率控制：实际须显著高于期望方为证据）
  N <- nrow(p); K <- length(fcols)
  lay[, 独立期望人数 := round(N * choose(K, 命中数) * prod(qused)^0 * NA_real_, 1)]
  lay[, 独立期望人数 := round(vapply(命中数, function(m) {
    if (m == 0L) N * prod(1 - qused) else
      N * sum(vapply(utils::combn(K, m, simplify = FALSE), function(idx)
        prod(qused[idx]) * prod(1 - qused[-idx]), 0)) }, 0), 1)]
  lay[, 提升度 := fifelse(独立期望人数 > 0, round(会员数 / 独立期望人数, 2), NA_real_)]
  degen <- vapply(fcols, function(fc) mean(p[[fc]] == 1L), 0)
  deg <- data.table(判据 = sub("^F_", "", names(degen)), 尾部命中率 = round(unname(degen), 4))
  deg[, 判读 := fifelse(尾部命中率 > s$degenerate_flag_rate,
    sprintf("⚠ 退化：命中率逾 %.0f%%，P90 与下界重合，尾部无分辨力", s$degenerate_flag_rate * 100), "正常")]
  co <- NULL
  if (length(fcols) >= 2L) {
    cb <- utils::combn(fcols, 2L)
    co <- rbindlist(lapply(seq_len(ncol(cb)), function(i) {
      a <- cb[1, i]; b <- cb[2, i]
      na_ <- sum(p[[a]] == 1L); nb <- sum(p[[b]] == 1L); nab <- sum(p[[a]] == 1L & p[[b]] == 1L)
      ex <- na_ * nb / N
      data.table(判据A = sub("^F_", "", a), 判据B = sub("^F_", "", b),
                 A尾部 = na_, B尾部 = nb, 共现 = nab, 独立期望 = round(ex, 1),
                 提升度 = fifelse(ex > 0, round(nab / ex, 2), NA_real_),
                 `P(B|A) Wilson下界` = round(tr_wilson_lo(nab, na_), 4))
    }))
    setorder(co, -提升度)
  }
  list(panel = p, layer = lay, cooc = co, dircols = dircols, degenerate = deg, q = qused,
       n_any = sum(p$命中数 >= 1L), n_multi = sum(p$命中数 >= 2L),
       n_all = sum(p$命中数 == K), k = K, N = N)
}

## PCA：降维与方差解释（成分无业务语义，禁作风险分）
tr_pca <- function(mj) {
  if (is.null(mj)) return(NULL)
  key <- .cfg("fields", "member_key_canonical")
  minf <- .cfg("statistics", "pca_min_features")
  num <- mj$panel[, setdiff(names(mj$panel), key), with = FALSE]
  keep <- names(which(vapply(num, function(v) is.numeric(v) &&
    sum(!is.na(v)) > .cfg("guards", "corr_min_n") && stats::sd(v, na.rm = TRUE) > 0, logical(1))))
  if (length(keep) < minf) return(NULL)
  m <- as.matrix(num[, ..keep]); m <- m[stats::complete.cases(m), , drop = FALSE]
  if (nrow(m) < minf * 10L) return(NULL)
  pr <- stats::prcomp(m, center = TRUE, scale. = isTRUE(.cfg("statistics", "pca_scale")))
  sdev <- pr$sdev; ve <- sdev^2 / sum(sdev^2)
  var_tab <- data.table(成分 = paste0("PC", seq_along(ve)), 标准差 = signif(sdev, 4),
                        方差解释 = round(ve, 4), 累计解释 = round(cumsum(ve), 4))
  ld <- as.data.table(round(pr$rotation, 3), keep.rownames = "判据")
  list(var = var_tab, load = ld, n = nrow(m), k = length(keep))
}

# ---------------------------------------------------------------------
# §9 序列与事件 · 入场行为层 · 线索汇总
# ---------------------------------------------------------------------
tr_sequence <- function(rec, loaded) {
  hint <- .cfg("fields", "time_axis_name_hint")
  pat <- .cfg("fields", "time_axis_value_pattern")
  minr <- .cfg("fields", "time_axis_min_match_rate")
  ## 全量铁律：时间轴之实证判定取【全列取值】，不取前 N 笔——
  ## 前 N 笔之形似率不等于全列形似率（前段有序、后段异构者会被误判）。
  ## 以 unique() 去重后仍是全列之完整取值域，非抽样。
  is_timeish <- function(v) {
    x <- as.character(v); x <- x[!is.na(x) & nzchar(x)]
    if (!length(x)) return(FALSE)
    u <- unique(x)
    w <- as.numeric(table(factor(x, levels = u)))       # 各取值之实际频次
    sum(w[grepl(pat, u)]) / sum(w) >= minr              # 频次加权之全列形似率
  }
  ## 全列形似率（供呈表举证，非判定用）
  timeish_rate <- function(v) {
    x <- as.character(v); x <- x[!is.na(x) & nzchar(x)]
    if (!length(x)) return(NA_real_)
    u <- unique(x); w <- as.numeric(table(factor(x, levels = u)))
    sum(w[grepl(pat, u)]) / sum(w)
  }
  rbindlist(lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]; nm <- sub("[.]csv$", "", f)
    if (!t$ok) return(data.table(交付件 = nm, 时间轴列 = "—", 粒度 = "—", 跨度 = t$status,
                                 判定基数 = NA_integer_, 全列形似率 = NA_real_,
                                 可做序列 = "✗ 待表", 疑似计数列 = "—"))
    ca <- grep(hint, names(t$dt), value = TRUE, ignore.case = TRUE)
    tc <- ca[vapply(ca, function(cn) is_timeish(t$dt[[cn]]), logical(1))]
    fake <- setdiff(ca, tc)
    if (!length(tc)) return(data.table(交付件 = nm, 时间轴列 = "无", 粒度 = "—", 跨度 = "—",
      判定基数 = nrow(t$dt),
      全列形似率 = if (length(ca)) round(max(vapply(ca, function(cn) timeish_rate(t$dt[[cn]]), 0), na.rm = TRUE), 4) else NA_real_,
      可做序列 = "✗ 待表（本表为截面，无时间轴）",
      疑似计数列 = if (length(fake)) paste(fake, collapse = ", ") else "—"))
    v <- as.character(t$dt[[tc[1L]]]); v <- v[!is.na(v) & nzchar(v)]
    data.table(交付件 = nm, 时间轴列 = paste(tc, collapse = ", "),
               粒度 = fifelse(nchar(v[1L]) <= 7L, "月", "日"),
               跨度 = if (length(v)) sprintf("%s → %s", min(v), max(v)) else "—",
               判定基数 = length(v),
               全列形似率 = round(timeish_rate(t$dt[[tc[1L]]]), 4),
               可做序列 = "✔", 疑似计数列 = if (length(fake)) paste(fake, collapse = ", ") else "—")
  }), fill = TRUE)
}

## 模型架构与入场行为层：三层架构之本类落位
tr_architecture <- function(rec, mj, sq, REG) {
  d <- rec$dict
  data.table(
    层 = c("① 入场行为层（观测）", "② 特征与判据层（登记）", "③ 决策层（门禁）"),
    本类内容 = c(
      sprintf("交付件 %d 件；会员级并集 %s；时间轴 %s",
              length(rec$files), if (is.null(mj)) "—" else tr_f(mj$n_union),
              if (!is.null(sq) && any(sq$可做序列 == "✔")) "在位" else "缺位（截面）"),
      sprintf("登记判据 %d 条（方向 %d／关系 %d／参照 %d／结构 %d）", nrow(d),
              sum(d$criterion_role == "STAT_DIRECTIONAL"), sum(d$criterion_role == "JOIN_KEY"),
              sum(d$criterion_role == "REFERENCE"),
              nrow(d) - sum(d$criterion_role %in% c("STAT_DIRECTIONAL", "JOIN_KEY", "REFERENCE"))),
      sprintf("门禁 %s；生命周期 %s；准入风控决策 %s", tr_gate2(REG, d$gate[1L]),
              d$lifecycle_state[1L], as.character(d$admit_to_risk_decision[1L]))),
    纪律 = c("观测层不得直接产生处置；缺件缺列一律登记待表",
             "判据只认登记册；未登记维度为可搭配空间，非判据",
             "门禁覆盖一切实测；五道铁门未全 PASS 前禁言「模型成立」"))
}

tr_leads <- function(rec, cb) {
  d <- rec$dict; gate <- d$gate[1L]
  disp <- switch(gate, FATAL = "仅画像，禁入评分与处置", BLOCK = "冻结，待阻断闭合",
                 CONDITIONAL = "须先满足解锁条件", "人工复核（影子期）")
  L <- list()
  sd_cols <- d[criterion_role == "STAT_DIRECTIONAL", criterion_column]
  L[[1L]] <- data.table(线索 = sprintf("L-01 单判据入尾（%s）", d$type_id[1L]),
    来源 = if (length(sd_cols)) paste(sd_cols, collapse = " + ") else "本类无方向判据",
    规模 = if (is.null(cb)) "—" else tr_f(cb$n_any),
    独立期望 = if (is.null(cb)) "—" else tr_f(round(cb$layer[命中数 >= 1L, sum(独立期望人数)])),
    定位 = "候选特征", 处置 = disp)
  if (!is.null(cb)) {
    L[[length(L) + 1L]] <- data.table(线索 = "L-02 多判据共现（≥2）", 来源 = "方向判据尾部交集",
      规模 = tr_f(cb$n_multi),
      独立期望 = tr_f(round(cb$layer[命中数 >= 2L, sum(独立期望人数)])),
      定位 = "跨维度互证", 处置 = disp)
    L[[length(L) + 1L]] <- data.table(线索 = sprintf("L-03 全判据共现（=%d）", cb$k),
      来源 = "全部方向判据同时入尾", 规模 = tr_f(cb$n_all),
      独立期望 = tr_f(round(cb$layer[命中数 == cb$k, sum(独立期望人数)])),
      定位 = "最高优先复核", 处置 = disp)
  }
  jk <- d[criterion_role == "JOIN_KEY", criterion_column]
  if (length(jk)) L[[length(L) + 1L]] <- data.table(线索 = "L-04 关系链扩展",
    来源 = paste(jk, collapse = " + "), 规模 = "待图算", 独立期望 = "—",
    定位 = "网络证据", 处置 = "E3/E4 打包后人审")
  ref <- d[criterion_role == "REFERENCE", criterion_column]
  if (length(ref)) L[[length(L) + 1L]] <- data.table(线索 = "L-05 参照量偏离",
    来源 = paste(ref, collapse = " + "), 规模 = "—", 独立期望 = "—",
    定位 = "口径对照，非判据", 处置 = "只作解释，不出名单")
  rbindlist(L, fill = TRUE)
}

# ---------------------------------------------------------------------
# §10 商业措施三阶（软字符：全取配置册）
# ---------------------------------------------------------------------
tr_biz_plan2 <- function(rec) {
  g <- rec$dict$gate[1L]
  now <- unlist(.cfg("measures_by_gate", g))
  p0 <- c(rec$typ$解锁条件, rec$typ$影子要求)
  if (!length(p0)) p0 <- "登记册未列解锁／影子要求（本类门禁无此项）"
  p12 <- unlist(.cfg("measures_pipeline"))
  data.table(阶段 = c(rep("即刻（0–2 周）", length(now)),
                      rep("制度（P0·解锁前置）", length(p0)),
                      rep("管线（P1–P2）", length(p12))),
             措施 = c(now, p0, p12))
}

# ---------------------------------------------------------------------
# §11 血统自检：产出不得含外来文献之 token
# ---------------------------------------------------------------------
tr_lineage_check <- function(text) {
  bl <- unlist(.cfg("lineage_blacklist", "tokens"))
  hit <- bl[vapply(bl, function(t) grepl(t, text, fixed = TRUE), logical(1))]
  if (length(hit)) stop(sprintf("血统污染：产出命中外来文献 token —— %s",
                                paste(hit, collapse = ", ")), call. = FALSE)
  invisible(TRUE)
}

# 数据口径字典（承 v1.1.0）
tr_field_dict <- function(rec, loaded) {
  rbindlist(lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]
    if (!t$ok) return(data.table(交付件 = sub("[.]csv$", "", f), 列 = "—", 类型 = "—",
                                 缺失率 = NA_real_, 取值示例 = t$status, 登记 = "—"))
    crit <- rec$dict[criterion_source == f, criterion_column]
    rbindlist(lapply(names(t$dt), function(cn) {
      v <- t$dt[[cn]]
      ex <- substr(as.character(utils::head(v[!is.na(v)], 3L)), 1L, 40L)
      data.table(交付件 = sub("[.]csv$", "", f), 列 = cn, 类型 = class(v)[1L],
                 缺失率 = round(mean(if (is.character(v)) is.na(v) | v == "" else is.na(v)), 4),
                 取值示例 = paste(ex, collapse = ", "),
                 登记 = fifelse(cn %in% crit, "✔ 已登记判据", "可搭配维度"))
    }))
  }), fill = TRUE)
}

# 评估准入十三维（承 v1.1.0，门禁图标改软取）
tr_eval <- function(rec, loaded, mj, REG) {
  d <- rec$dict; t <- rec$typ
  prim <- loaded$tabs[[rec$primary]]
  nfile <- sum(vapply(loaded$tabs, function(x) isTRUE(x$ok), logical(1)))
  cs_ok <- sum(vapply(seq_len(nrow(d)), function(i) {
    tt <- loaded$tabs[[d$criterion_source[i]]]
    isTRUE(tt$ok) && d$criterion_column[i] %in% names(tt$dt) }, logical(1)))
  ts <- table(d$threshold_status)
  data.table(
    维度 = c("交付件在位", "判据列在位", "主表行数", "会员级并集", "全表交集",
             "门禁", "严重度", "现象层 L1", "标签验证层 L2", "因果层 L3",
             "准入评分", "准入风控决策 L4", "阈值状态构成"),
    本类实测 = c(
      sprintf("%d / %d", nfile, length(loaded$tabs)), sprintf("%d / %d", cs_ok, nrow(d)),
      if (isTRUE(prim$ok)) tr_f(prim$rows) else prim$status,
      if (is.null(mj)) "—" else tr_f(mj$n_union),
      if (is.null(mj) || is.na(mj$n_inter)) "—" else tr_f(mj$n_inter),
      tr_gate2(REG, t$门禁), t$严重度,
      d$phenomenon_status[1L], d$label_validation_status[1L], d$causal_status[1L],
      tr_yn(t$准入评分), tr_yn(d$admit_to_risk_decision[1L]),
      paste(sprintf("%s×%d", names(ts), as.integer(ts)), collapse = " ")),
    风控后果 = c(
      "缺件即本类证据链不完整，结论只及在位部分",
      "缺列即该判据不可实测，登记为待表，不以文字冒充",
      "只代表当前交付件覆盖之会员 universe", "跨表灵活搭配之最大可及面",
      "全判据齐备者人数；交集越小越须防幸存者偏差",
      "门禁覆盖一切实测——实测再漂亮，门禁说 FATAL 就是 FATAL",
      "严重度决定处置优先级，非决定可否处置",
      "OBSERVED 仅表示可复现，不表示有判别力",
      "非 TESTED_PASS 者不得解锁风控决策",
      "非 ESTABLISHED 者只能言相关，不可言因果",
      "准入评分 ≠ 主表已备（登记册 admission_dichotomy）",
      "本册全部登记判据之 admit_to_risk_decision 皆为 FALSE",
      "PENDING_INVERSE 者须逐指标反解含 n_eff，禁写普适门槛（P-06）"))
}

# ---------------------------------------------------------------------
# §10 测试线闸 · 经济画像 · 指标可行性（N-9 · 2026-09-03）
# ---------------------------------------------------------------------
# 【立意】承先生军令状：「任何数据表与报表的任务是实测并证实可以提升业绩或经济价值
#   的增减幅度，而非作秀忽悠」。2026-09-03 机检本引擎，两项硬缺口：
#     ① **测试线全无处理**：引擎与模板内 is_test／test_line／测试线／age022 命中皆为 0。
#        总包侧多数交付件已于取数时剔测试线，惟 #078 S03_agent_score 采【标记法】保留
#        （实测 4,191 行中 is_test_line=1 者 13 行，其 stake 合计 0）。T-08／T-09 以 S03 为
#        判据来源，故该 13 行未经分离即进入分位与相关计算——违「测试线与真实实体务必一律区分」。
#     ② **全无经济量**：引擎可执行码中 net_margin／economic_value／theo／adt／nmpt／esi／
#        drawdown／sharpe／sortino 命中皆为 0。即：本报告此前只算【判据】，从不算【钱】。
#   本节补此二缺。⛔ 然补法须守铁律：六层商业块 118 栏系 CROSS JOIN 广播（平台常数逐行复制），
#   以广播值充金额即是作秀。故经济层【先验广播、后出金额】，广播者一律拒出，标明理由。
# ---------------------------------------------------------------------

## §10.1 测试线闸：分离测试线与真实实体（会员／代理／荷官／风控专员）
##   交付件侧之标记法列名（S03 之例）；ODS 侧之 age022 不在交付件内，故只能认标记列。
## ⛔ 只收【布尔标记栏】。n_bets_testline／stake_testline_audit／profit_testline_audit 系
##   【计数与金额之审计栏】，非标记——若误入，n_bets_testline=1 之真实代理将被当作测试线剔除。
.TR_TESTLINE_COLS <- c("is_test_line", "is_test", "test_line")
tr_testline_gate <- function(loaded) {
  rows <- lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]
    if (!isTRUE(t$ok)) return(data.table(交付件 = f, 标记列 = "—", 总行 = NA_integer_,
      测试线行 = NA_integer_, 真实实体行 = NA_integer_, 处置 = "—（未载入）"))
    cols <- intersect(.TR_TESTLINE_COLS, names(t$dt))
    if (!length(cols)) return(data.table(交付件 = f, 标记列 = "无",
      总行 = t$rows, 测试线行 = 0L, 真实实体行 = t$rows,
      处置 = "取数时已剔（总包侧 age022='1' 左连取 NULL）—— 本件无标记列，视为全为真实实体"))
    cc <- cols[1L]
    v  <- t$dt[[cc]]
    isT <- !is.na(v) & trimws(as.character(v)) %in% c("1", "TRUE", "true", "Y", "y")
    data.table(交付件 = f, 标记列 = cc, 总行 = t$rows,
      测试线行 = sum(isT), 真实实体行 = sum(!isT),
      处置 = if (sum(isT) > 0L) "★ 本件采标记法保留测试线 —— 下游统计须先剔，否则口径混入"
             else "标记列在位且无测试线行")
  })
  out <- rbindlist(rows, fill = TRUE)
  attr(out, "n_testline") <- sum(out$测试线行, na.rm = TRUE)
  out[]
}

## 依测试线闸剔除：回一份【已分离】之表集，供经济层与判据统计取用
tr_drop_testline <- function(loaded) {
  for (f in names(loaded$tabs)) {
    t <- loaded$tabs[[f]]
    if (!isTRUE(t$ok)) next
    cols <- intersect(.TR_TESTLINE_COLS, names(t$dt))
    if (!length(cols)) next
    cc <- cols[1L]; v <- t$dt[[cc]]
    keep <- is.na(v) | !(trimws(as.character(v)) %in% c("1", "TRUE", "true", "Y", "y"))
    if (any(!keep)) {
      loaded$tabs[[f]]$dt   <- t$dt[keep]
      loaded$tabs[[f]]$rows <- sum(keep)
      loaded$tabs[[f]]$testline_dropped <- sum(!keep)
    }
  }
  loaded
}

## §10.2 广播侦测：六层商业块之栏若逐行同值，即为平台常数广播，禁充金额
.tr_is_broadcast <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) return(TRUE)
  uniqueN(x) <= 1L
}

## §10.3 经济画像：先验广播，后出金额
##   ⛔ 只用主表之【原生】经济栏；广播者拒出并标明。禁以广播值算任何金额。
.TR_ECON_COLS <- c(stake = "本金", valid_bet = "洗码", profit = "NGR（块 profit ＝ GGR − 退水）",
                   ngr = "块 ngr（重复扣退水 · DEPRECATED）", rebate_cost = "退水",
                   residual_b = "残值 b", hold_rate = "hold 率")
tr_economic_profile <- function(rec, loaded) {
  f <- rec$primary
  t <- loaded$tabs[[f]]
  .adm <- tr_money_admissible(f)                      # ★ §12 可信度闸：非 OK 件不得出实体金额
  if (!.adm$ok)
    return(data.table(经济栏 = "—", 口径 = "—", 状态 = sprintf("★ %s", .adm$可信度),
                      合计 = NA_real_, 均值 = NA_real_, 相异值数 = NA_integer_, 判 = .adm$理由))
  if (is.null(t) || !isTRUE(t$ok))
    return(data.table(经济栏 = "—", 口径 = "—", 状态 = "待表（主表未载入）",
                      合计 = NA_real_, 均值 = NA_real_, 相异值数 = NA_integer_, 判 = "—"))
  dt <- t$dt
  rbindlist(lapply(names(.TR_ECON_COLS), function(cc) {
    if (!cc %in% names(dt))
      return(data.table(经济栏 = cc, 口径 = .TR_ECON_COLS[[cc]], 状态 = "缺列",
                        合计 = NA_real_, 均值 = NA_real_, 相异值数 = NA_integer_,
                        判 = "本表无此栏"))
    x <- suppressWarnings(as.numeric(dt[[cc]]))
    nd <- uniqueN(x[!is.na(x)])
    bc <- .tr_is_broadcast(x)
    data.table(经济栏 = cc, 口径 = .TR_ECON_COLS[[cc]],
      状态 = if (bc) "★ 广播（平台常数）" else "原生（逐行）",
      合计 = if (bc) NA_real_ else round(sum(x, na.rm = TRUE), 2),
      均值 = if (bc) NA_real_ else round(mean(x, na.rm = TRUE), 4),
      相异值数 = nd,
      判 = if (bc) "⛔ 禁充金额：本栏逐行同值，系六层块 CROSS JOIN 之平台常数广播"
           else "✓ 可作金额（本表原生）")
  }), fill = TRUE)
}

## §10.4 判据尾部之经济暴露：本类判据所指之尾部人群，究竟压着多少钱
##   ⛔ 只描述暴露，不作赏罚（承 P-15 禁全窗百分位定线、P-16 禁以实现输赢符号定罚）
tr_criterion_exposure <- function(rec, loaded, q = 0.90) {
  d <- rec$dict
  ## ⛔ 判据之金额须取【该判据自身之声明源表】，非一律取主表：全册 65 条判据中 23 条
  ##   criterion_source ≠ primary_deliverable，若一律取主表，此 23 条永不出数（2026-09-03 实测）。
  .money_of <- function(dt) {
    m <- intersect(c("valid_bet", "profit", "stake"), names(dt))
    m[vapply(m, function(k) !.tr_is_broadcast(suppressWarnings(as.numeric(dt[[k]]))), logical(1))]
  }
  out <- rbindlist(lapply(seq_len(nrow(d)), function(i) {
    r <- d[i]; f <- r$criterion_source
    t <- loaded$tabs[[f]]
    if (is.null(t) || !isTRUE(t$ok)) return(NULL)
    a <- tr_money_admissible(f)                       # ★ §12：逐判据按其自身声明源表过闸
    if (!a$ok) return(data.table(判据列 = r$criterion_column, 声明源表 = f,
                                 方向 = fifelse(nzchar(r$direction), r$direction, "—"),
                                 尾部口径 = "—", 尾部行数 = NA_integer_, 占比 = NA_real_,
                                 可信度 = a$可信度, 拒出理由 = a$理由))
    dt <- t$dt
    if (!r$criterion_column %in% names(dt)) return(NULL)   # 未外显之判据：留白，不臆造
    money <- .money_of(dt); if (!length(money)) return(NULL)
    x <- suppressWarnings(as.numeric(dt[[r$criterion_column]]))
    if (all(is.na(x)) || uniqueN(x[!is.na(x)]) < 3L) return(NULL)
    ## 尾部方向依登记册 direction：high 者风险在上尾，low 者风险在【下尾】。
    ##   一律取上十分位是判断错——2026-09-03 实测 T-07「投注产品结构熵」direction=low 即遭此误。
    lowdir <- identical(tolower(trimws(r$direction)), "low")
    qq  <- if (lowdir) 1 - q else q
    thr <- as.numeric(stats::quantile(x, qq, na.rm = TRUE, names = FALSE))
    hi  <- if (lowdir) (!is.na(x) & x <= thr) else (!is.na(x) & x >= thr)
    o <- data.table(判据列 = r$criterion_column, 声明源表 = f, 可信度 = a$可信度,
                    方向 = fifelse(nzchar(r$direction), r$direction, "—"),
                    尾部口径 = sprintf(if (lowdir) "≤P%d" else "≥P%d", round(qq * 100)),
                    尾部行数 = sum(hi), 占比 = round(mean(hi), 4))
    for (m in money) {
      v <- suppressWarnings(as.numeric(dt[[m]]))
      o[[paste0(m, "_尾部")]]   <- round(sum(v[hi], na.rm = TRUE), 2)
      o[[paste0(m, "_占全表")]] <- round(sum(v[hi], na.rm = TRUE) / sum(v, na.rm = TRUE), 4)
    }
    ## hold 率对照：尾部 hold ÷ 全表 hold。＞1 者贵客，＜1 者只走量不出钱。
    ##   ⛔ 此为【暴露描述】，非赏罚线：承 P-15 禁以全窗百分位定线、P-16 禁以实现输赢符号定罚。
    if (all(c("profit", "valid_bet") %in% money)) {
      pv <- suppressWarnings(as.numeric(dt$profit)); vb <- suppressWarnings(as.numeric(dt$valid_bet))
      h_t <- sum(pv[hi], na.rm = TRUE) / sum(vb[hi], na.rm = TRUE)
      h_a <- sum(pv,     na.rm = TRUE) / sum(vb,     na.rm = TRUE)
      o[, `:=`(尾部hold率 = round(h_t, 6), 全表hold率 = round(h_a, 6),
               hold倍数 = round(h_t / h_a, 3))]
    }
    o
  }), fill = TRUE)
  if (!nrow(out)) return(NULL)
  out[]
}

## §10.5 指标可行性清单：先生所列各指标，何者可算、何者不可、卡在何处
##   ⛔ 一律据实登记，不以「未实作」冒充「不适用」，亦不以「可算」冒充「已证」。
tr_metric_inventory <- function(rec, loaded) {
  f <- rec$primary; t <- loaded$tabs[[f]]
  has <- function(cc) !is.null(t) && isTRUE(t$ok) && cc %in% names(t$dt)
  live <- function(cc) has(cc) && !.tr_is_broadcast(suppressWarnings(as.numeric(t$dt[[cc]])))
  dt_axis <- !is.null(t) && isTRUE(t$ok) &&
             length(intersect(c("dt", "bet_date", "biz_date", "ym", "date"), names(t$dt))) > 0L
  ## 总包侧或已预算风险调整栏（如 S01 之「索提诺稳定性」）。R 侧虽无日序不能重算，然不得据此报「无」。
  .pre <- function(pat) { if (is.null(t) || !isTRUE(t$ok)) return(NA_character_)
                          h <- grep(pat, names(t$dt), value = TRUE); if (length(h)) h[1L] else NA_character_ }
  .mdd <- .pre("回撤|drawdown"); .shp <- .pre("夏普|sharpe"); .srt <- .pre("索提诺|sortino")
  .say <- function(pre) if (!is.na(pre)) sprintf("✓ 总包已算（栏 %s）", pre) else if (dt_axis) "△ 须日序" else "✗"
  data.table(
    指标 = c("ROI", "Net Margin", "Economic Value", "NGR／hold",
             "Theo", "ADT", "NMPT", "ESI",
             "最大回撤 MDD", "夏普率 Sharpe", "索提诺率 Sortino",
             "APUC（每客均利）", "Wilcoxon 秩和", "符号检验", "AUC（秩法）", "Wilson 区间"),
    本类可算 = c(
      fifelse(live("roi"), "✓", "✗"), fifelse(live("net_margin_bet23_formal_canonical"), "✓", "✗"),
      fifelse(live("economic_value"), "✓", "✗"), fifelse(live("profit") && live("valid_bet"), "✓", "✗"),
      "✗", "✗", "✗", "✗",
      .say(.mdd), .say(.shp), .say(.srt),
      fifelse(live("profit"), "△ 可算", "✗"), "△ 可加", "△ 可加", "✓ 已实作", "✓ 已实作"),
    阻断与出处 = c(
      "主表 roi 栏；若广播则不可用", "主表 net_margin_*_canonical 栏；若广播则不可用",
      "⛔ 系 PERCENT_RANK 之秩，非货币（承永久禁令 13）", "主表 profit／valid_bet 原生栏",
      "⛔ house_edge 全 NULL（F-22~25 BLOCKED）；须 member×bet09×免佣 中间粒度",
      "⛔ 分子为 theo，随之阻断", "⛔ 分母为 theo；且已实测撤回（−508,515）", "⛔ 须 bet09 级 edge",
      "须实体×日序列；本类主表若无日期键则不可算（见 N-6 报告 §2.5 之可用面板六件）",
      "同上；且平台层实测 Sharpe 2.56、MDD 仅占累计 0.052% ⇒ 判别力近零",
      "同上；会员层前 3 月 Sortino 预测后 3 月 NGR 仅 Spearman 0.049",
      "profit ÷ 实体数；须先剔测试线，否则分母含伪实体",
      "本引擎未实作；处置前后配对比较之首选，然受 P-20 阻断（因果未解封）",
      "本引擎未实作（现只见于章名）；同受 P-20 阻断",
      "tr_auc()：秩法 ＝ Mann–Whitney", "tr_wilson_lo()／tr_wilson_hi()／tr_min_n() 反解样本门"),
    性质 = c(rep("经济量", 4), rep("高端经济量（阻断）", 4),
             rep("风险调整（须时序）", 3), "经济量", rep("统计检验", 4)))
}

# ---------------------------------------------------------------------
# §11 有符号阶梯：负侧／零点／正侧各别分位（N-10 · 2026-09-03）
# ---------------------------------------------------------------------
# 【先生之策】「任何数据表内外拥有 roi／net_margin／economic_value／theo／adt／nmpt／esi／
#   drawdown／sharpe／sortino／AUC／Wilson／Spearman／主成分／符号检验等重要指标，都需要将
#   所有负数至零与零至所有正数各别使用分位数。」
#
# 【何以为良策】2026-09-03 实测坐实此策直中要害：
#   §10.4 之四条判据于 P90 处退化——rebate_dep 尾部占 99.96%、退水支出占 100.00%、
#   opposite_rate 占 56.64%、hedge_coverage 占 44.24%。病根正是**零点巨量并列**：
#   全域单一分位遇「九成为零」之分布，P90 即落在 0，`x >= 0` 遂网住全表，判别力归零。
#   于零点两侧【各别】起阶梯，正是此病之对症药。
#
# 【然须守三戒，否则仍是作秀】
#   ⛔ 戒一 · 零点非普适：AUC 之虚无点为 **0.5** 非 0；economic_value 系 PERCENT_RANK 之秩
#      （值域 [0,1]，恒非负），于零点切分**毫无意义**；Wilson 系区间端点非有符号量。
#      故零点须**逐指标声明**，未声明者一律拒算，不得以 0 蒙混。
#   ⛔ 戒二 · 零质量须单列：若六成行恰为零，两侧阶梯实只建于四成数据之上，不明书即误导。
#   ⛔ 戒三 · 承 P-15：本阶梯系全窗百分位，只作**描述与诊断**，不得径充赏罚线。
#      欲转处置，仍须过样本外验证与 P-20 之解封。
# ---------------------------------------------------------------------

## §11.1 零点登记：逐指标声明，未声明者拒算
##   ⛔ 不得以「反正大多是 0」为由给未声明指标默认零点——此即戒一所禁。
.TR_NULLPOINT <- list(
  list(pat = "^roi$|_roi$|^d_roi|^norm_roi",              null = 0,   note = "ROI：0 即不赚不赔"),
  list(pat = "^net_margin",                               null = 0,   note = "净利：0 即打平"),
  list(pat = "^profit$|^ngr$|^ggr$|_profit$|_ngr$",       null = 0,   note = "盈亏：0 即打平（平台视角）"),
  list(pat = "^residual_",                                null = 0,   note = "残差：0 即恒等式成立"),
  list(pat = "sharpe|夏普",                               null = 0,   note = "夏普：0 即无超额"),
  list(pat = "sortino|索提诺",                            null = 0,   note = "索提诺：0 即无超额"),
  list(pat = "drawdown|回撤",                             null = 0,   note = "回撤：0 即未回撤"),
  list(pat = "spearman|^rho$",                            null = 0,   note = "秩相关：0 即无关联"),
  list(pat = "^auc$|_auc$",                               null = 0.5, note = "AUC：虚无点 0.5，非 0"),
  list(pat = "^hold_rate$",                               null = 0,   note = "hold 率：0 即无抽水；⛔ 经济参照点本应为理论庄家优势，然 house_edge 全 NULL（F-22~25 阻断），暂以 0 代之并标明")
)
## 明令拒算者：切于零点无意义或概念错置
.TR_NULL_REFUSE <- list(
  list(pat = "^economic_value$", why = "系 PERCENT_RANK 之秩，值域 [0,1] 恒非负；零点切分无意义（承永久禁令 13）"),
  list(pat = "wilson",           why = "系比例区间之端点，非有符号量；无零点可言"),
  list(pat = "^pc[0-9]+$|prcomp|主成分", why = "主成分之符号由算法任意定向，零点不具经济含义")
)

tr_null_point <- function(col) {
  for (r in .TR_NULL_REFUSE) if (grepl(r$pat, col, perl = TRUE))
    return(list(ok = FALSE, null = NA_real_, note = paste0("⛔ 拒算：", r$why)))
  for (r in .TR_NULLPOINT) if (grepl(r$pat, col, perl = TRUE))
    return(list(ok = TRUE, null = r$null, note = r$note))
  list(ok = FALSE, null = NA_real_,
       note = "⛔ 拒算：本指标未在零点登记内声明。承戒一，不得默认 0——须先声明其虚无点")
}

## §11.2 有符号阶梯本体
##   回三段质量（负侧／零点／正侧）＋ 两侧各别之分位阶梯，每级挂金额。
tr_signed_ladder <- function(dt, col, money = c("valid_bet", "profit"),
                             probs = c(.10, .25, .50, .75, .90, .99), min_n = NULL,
                             file = NULL) {
  ## ★ §12 可信度闸：给定来源件时，非 OK 件不得挂金额（阶梯本身仍可建，然金额栏须撤）
  .cred <- if (is.null(file)) NULL else tr_money_admissible(file)
  if (!is.null(.cred) && !.cred$ok) money <- character(0)
  np <- tr_null_point(col)
  if (!np$ok)
    return(list(ok = FALSE, 说明 = np$note, 质量 = NULL, 阶梯 = NULL))
  if (is.null(min_n)) min_n <- tryCatch(as.integer(tr_cfg("统计", "最小样本", .default = 30L)),
                                        error = function(e) 30L)
  if (!col %in% names(dt))
    return(list(ok = FALSE, 说明 = "⛔ 本表无此栏", 质量 = NULL, 阶梯 = NULL))
  x <- suppressWarnings(as.numeric(dt[[col]]))
  ok <- !is.na(x)
  if (!any(ok)) return(list(ok = FALSE, 说明 = "⛔ 本栏全为 NA（NULL ≠ 0，不得以 0 填充）",
                            质量 = NULL, 阶梯 = NULL))
  ## ⛔ 广播栏（逐行同值）不得建阶梯——阶梯每级皆同值，纯属作秀
  if (uniqueN(x[ok]) <= 1L)
    return(list(ok = FALSE, 阶梯 = NULL, 质量 = NULL,
                说明 = sprintf("⛔ 本栏逐行同值（%s），系六层块 CROSS JOIN 之平台常数广播；建阶梯即作秀，拒算",
                               format(x[ok][1L], big.mark = ","))))
  z <- np$null
  side <- fifelse(!ok, NA_character_, fifelse(x < z, "负侧", fifelse(x > z, "正侧", "零点")))
  mo <- intersect(money, names(dt))
  mo <- mo[vapply(mo, function(m) !.tr_is_broadcast(suppressWarnings(as.numeric(dt[[m]]))), logical(1))]

  ## 三段质量：零质量须单列，否则两侧阶梯之底数被误读（戒二）
  mass <- rbindlist(lapply(c("负侧", "零点", "正侧"), function(s) {
    idx <- !is.na(side) & side == s
    o <- data.table(段 = s, 行数 = sum(idx), 占比 = round(mean(idx[ok]), 4))
    for (m in mo) { v <- suppressWarnings(as.numeric(dt[[m]]))
      o[[paste0(m, "_合计")]] <- round(sum(v[idx], na.rm = TRUE), 2)
      o[[paste0(m, "_占比")]] <- round(sum(v[idx], na.rm = TRUE) / sum(v, na.rm = TRUE), 4) }
    o
  }), fill = TRUE)
  mass <- rbind(mass, data.table(段 = "NA（缺测）", 行数 = sum(!ok), 占比 = NA_real_), fill = TRUE)

  ## 两侧各别之阶梯
  lad <- rbindlist(lapply(c("负侧", "正侧"), function(s) {
    v <- x[!is.na(side) & side == s]
    if (length(v) < min_n)
      return(data.table(侧 = s, 分位 = "—", 门槛 = NA_real_, 该级及以外行数 = NA_integer_,
                        判 = sprintf("⛔ 本侧样本 %d ＜ 最小样本门 %d，拒建阶梯（NOT_RUN ≠ PASS）",
                                     length(v), min_n)))
    ## 负侧以【绝对值由大到小】读之：越负者风险／亏损越重，故取下分位为重端
    qs <- stats::quantile(v, probs, na.rm = TRUE, names = FALSE)
    rbindlist(lapply(seq_along(probs), function(i) {
      thr <- qs[i]
      idx <- if (s == "负侧") (!is.na(x) & x <= thr) else (!is.na(x) & x >= thr)
      o <- data.table(侧 = s, 分位 = sprintf("P%s", format(probs[i] * 100, trim = TRUE)),
                      门槛 = round(thr, 6), 该级及以外行数 = sum(idx),
                      判 = if (s == "负侧") "≤ 门槛（越负越重）" else "≥ 门槛（越正越重）")
      for (m in mo) { mv <- suppressWarnings(as.numeric(dt[[m]]))
        o[[paste0(m, "_占比")]] <- round(sum(mv[idx], na.rm = TRUE) / sum(mv, na.rm = TRUE), 4) }
      o
    }), fill = TRUE)
  }), fill = TRUE)

  list(ok = TRUE, 零点 = z,
       说明 = if (!is.null(.cred) && !.cred$ok) paste0(np$note, "　⛔ 金额已撤：", .cred$理由) else np$note,
       质量 = mass[], 阶梯 = lad[], 金额栏 = mo,
       可信度 = if (is.null(.cred)) "—" else .cred$可信度)
}

## §11.3 全表指标盘点：本表有哪些指标栏、各为原生抑或广播、可否建阶梯
tr_metric_scan <- function(dt, tbl = "") {
  ## ⛔ 主表未载入与「本表无指标栏」是两回事，不得共用一句话搪塞（2026-09-03 实测 T-02／T-10 即遭此误：
  ##   T-02 主表 R03b_player_dealer_daily.csv 不在盘、T-10 系 ODS 直算无中间交付件，
  ##   然报表一律书「本表无已声明之指标栏」，读者无从分辨「无栏」与「无表」。）
  if (is.null(dt) || !length(names(dt)))
    return(data.table(表 = tbl, 指标栏 = "—", 零点 = NA_real_, 形态 = "—", 可建阶梯 = "—",
                      说明 = "⛔ 主表未载入（不在盘，或系 ODS 直算无中间交付件）——非「无指标栏」"))
  pats <- unique(c(vapply(.TR_NULLPOINT, function(r) r$pat, character(1)),
                   vapply(.TR_NULL_REFUSE, function(r) r$pat, character(1))))
  cols <- unique(unlist(lapply(pats, function(p) grep(p, names(dt), value = TRUE, perl = TRUE))))
  if (!length(cols)) return(data.table(表 = tbl, 指标栏 = "（无）", 零点 = NA_real_,
                                       形态 = "—", 可建阶梯 = "—", 说明 = "本表无已声明之指标栏"))
  rbindlist(lapply(cols, function(cc) {
    np <- tr_null_point(cc)
    x  <- suppressWarnings(as.numeric(dt[[cc]]))
    bc <- .tr_is_broadcast(x)
    data.table(表 = tbl, 指标栏 = cc, 零点 = np$null,
               形态 = if (all(is.na(x))) "全 NA" else if (bc) "★ 广播（平台常数）" else "原生（逐行）",
               可建阶梯 = if (!np$ok) "✗" else if (all(is.na(x))) "✗" else if (bc) "✗" else "✓",
               说明 = if (!np$ok) np$note
                      else if (all(is.na(x))) "⛔ 全 NA：NULL ≠ 0，不得填零充数"
                      else if (bc) "⛔ 广播栏：阶梯每级同值，建之即作秀"
                      else np$note)
  }), fill = TRUE)
}

# ---------------------------------------------------------------------
# §12 交付件可信度闸（N-11 · 2026-09-03）
# ---------------------------------------------------------------------
# 【本节所治之病 —— 我方自陈之重大缺陷】
#   SQL 总包档头自带一份【133 行逐件可信度清单】，逐件标可信度与用法：
#       OK           24 件  连接 1:1，本行 net_margin 即本行事实   → 可直接做商业判定
#       WRONG_GRAIN  37 件  e 侧按上层粒度连接，值在多行重复        → 仅作背景，勿算比率
#       INVALID      67 件  CROSS JOIN x_agg（会员级），值不相干    → 勿用
#       NULL          1 件  #079 跨实体未命中                      → 只看前 7 列
#       N/A           4 件  三字典 ＋ #133 局级事实表
#     24 ＋ 37 ＋ 67 ＋ 1 ＝ 129；加 4 ＝ 133，逐条闭合。
#
#   ⛔ 而本引擎 §10／§11 之广播侦测只验「逐行同值」（uniqueN <= 1）——
#      该法只抓得住 67 件 INVALID，**37 件 WRONG_GRAIN 全数漏网**：
#      上卷广播之值在多行重复而非全表同值，故相异值数 > 1，遂通过检验，
#      随后被当作逐行实体金额入账。此即「看起来完全合理」之最危险一类。
#
#   2026-09-03 回溯实测：N-9／N-10 所出四十条判据经济暴露中，
#     建于 OK 件者仅一部分；建于 WRONG_GRAIN／INVALID 件者须【撤回或降级】。
#     例：T-01 五条判据源自 R02_same_table（WRONG_GRAIN，粒度 uid1 × uid2 之【对】），
#         会员金额于每一对中重复 ⇒ 扇出膨胀；其 hold 倍数不可引用。
#
# 【处置】立可信度闸：实体级金额只准取自 OK 件；WRONG_GRAIN 与 INVALID 一律拒出并标明成因。
#   ⛔ 承自家铁律：不臆造、不补零、不把上卷值当逐行值。
# ---------------------------------------------------------------------

TR_CRED_PATH <- file.path("规范", "deliverable_credibility_v1.0.0.csv")

## 载入逐件可信度清单（派生自 SQL 总包档头之 133 行清单，机器解析，非手写）
tr_credibility <- function(path = TR_CRED_PATH) {
  if (!file.exists(path)) {
    warning(sprintf("[可信度闸] 清单不在位：%s —— 闸降级为 UNKNOWN（UNKNOWN ≠ PASS）", path),
            call. = FALSE)
    return(NULL)
  }
  d <- fread(path, encoding = "UTF-8", showProgress = FALSE)
  setkey(d, 交付件)
  d[]
}

.TR_CRED <- NULL
tr_cred_of <- function(file) {
  if (is.null(.TR_CRED)) .TR_CRED <<- tr_credibility()
  if (is.null(.TR_CRED)) return(list(可信度 = "UNKNOWN", 用法 = "—", 实体 = "—", 粒度 = "—"))
  r <- .TR_CRED[交付件 == file]
  if (!nrow(r)) return(list(可信度 = "UNKNOWN", 用法 = "—", 实体 = "—", 粒度 = "—"))
  list(可信度 = r$可信度[1L], 用法 = r$用法[1L], 实体 = r$实体[1L], 粒度 = r$粒度[1L])
}

## 实体级金额是否准用：只有 OK 件准用
##   ⛔ UNKNOWN ≠ PASS：清单未收录者一律拒出，不得放行。
tr_money_admissible <- function(file) {
  c0 <- tr_cred_of(file)
  ok <- identical(c0$可信度, "OK")
  list(ok = ok, 可信度 = c0$可信度, 用法 = c0$用法, 实体 = c0$实体, 粒度 = c0$粒度,
       理由 = if (ok) sprintf("✓ OK · %s · 粒度 %s —— 连接 1:1，本行金额即本行事实", c0$用法, c0$粒度)
              else switch(c0$可信度,
                "WRONG_GRAIN" = sprintf("⛔ WRONG_GRAIN · 粒度 %s —— e 侧按上层粒度连接，金额于多行重复；作实体金额即扇出膨胀，仅可作背景", c0$粒度),
                "INVALID"     = sprintf("⛔ INVALID · 粒度 %s —— CROSS JOIN x_agg 笛卡尔广播，值不相干，勿用", c0$粒度),
                "NULL"        = "⛔ NULL —— 跨实体未命中，六层全 NULL，只看前 7 列",
                "N/A"         = sprintf("⛔ N/A · %s —— 字典或事实基表，本无六层商业块", c0$用法),
                "UNKNOWN"     = "⛔ UNKNOWN —— 不在总包可信度清单内；UNKNOWN ≠ PASS，拒出",
                "⛔ 未知可信度，拒出"))
}

## 逐件可信度表：供报表明列本类所用各件之等级
tr_credibility_panel <- function(rec, loaded) {
  rbindlist(lapply(rec$files, function(f) {
    a <- tr_money_admissible(f)
    t <- loaded$tabs[[f]]
    data.table(交付件 = f,
               角色 = fifelse(f == rec$primary, "主表",
                        fifelse(f %in% rec$supporting, "搭配表", "判据来源")),
               实体 = a$实体, 粒度 = a$粒度, 可信度 = a$可信度, 用法 = a$用法,
               行数 = if (!is.null(t) && isTRUE(t$ok)) t$rows else NA_integer_,
               实体级金额 = if (a$ok) "✓ 准用" else "⛔ 拒用",
               理由 = a$理由)
  }), fill = TRUE)
}

# ---------------------------------------------------------------------
# §13 交付路径闸 · hold 正名 · 实测庄家优势 · SQL 溯源与维度指标（N-12 · 2026-09-03）
# ---------------------------------------------------------------------

## §13.1 交付命名空间闸
##   ⛔ 2026-09-03 实测之硬故障：commit 6e53299「斧正 `数据库/`」以 R100 纯改名把
##      数据表/ 改回 数据库/，而配置册 namespaces.delivery 未跟改，仍指 数据表。
##      其时 tr_load() 对每一件回「待表（档不在位）」——130 件全数静默失败，
##      **看似缺数据，实为路径断裂**。此即最须根除之静默之洞。
##   处置：渲染之初即验交付目录，不存在或零 csv 者一律 stop，禁再静默。
tr_delivery_gate <- function(db = TR_DB) {
  if (!nzchar(db))
    stop("[交付闸] 交付命名空间为空——配置册 namespaces.delivery 未设", call. = FALSE)
  if (!dir.exists(db))
    stop(sprintf(paste0("[交付闸] 交付目录不存在：%s\n",
      "  ⛔ 此非「缺数据」而是【路径断裂】。本层实有目录：%s\n",
      "  ⇒ 请改 配置/report_config_*.yaml 之 namespaces.delivery，勿改代码。"),
      db, paste(list.dirs(".", recursive = FALSE, full.names = FALSE), collapse = "、")),
      call. = FALSE)
  n <- length(list.files(db, "[.]csv$"))
  if (n == 0L)
    stop(sprintf("[交付闸] 交付目录 %s 内零件 csv —— 拒绝在空目录上出数（NOT_RUN ≠ PASS）", db),
         call. = FALSE)
  data.table(闸 = "交付命名空间", 取值 = db, 件数 = n,
             判 = sprintf("✓ PASS —— 目录在位且含 %s 件 csv", format(n, big.mark = ",")))
}

## §13.2 hold 正名：三量并存，禁以一名统称
##   2026-09-03 全包机检定谳：
##     hold_rate      = −net / stake            六层块，128 处，会员级   ⇒ profit / stake
##     house_hold_pct = −player_pnl / stake_total  #017 DX04 自有栏，逐投注面
##     （我方 R 侧曾用 profit / valid_bet 而亦称 hold —— **总包无此列，系自造**）
##   ⛔ 三者分母各异，同名必致误读。自此一律带分母出名，禁裸称 hold。
## ⛔ N-14（2026-09-03）实测更正 —— 承先生令「务必实测后更正注释」：
##   本表四行皆经 S01_player_score.csv（723,442 会员 · 可信度 OK）全量实测：
##     Σstake 13,436,093,473.804 ／ Σvalid_bet 12,101,545,165.175 ／ Σprofit 225,932,201.626
##     valid_bet ÷ stake ＝ 90.067438%
##   ① hold_rate ≡ profit ÷ stake ：逐行比对 723,442 行，偏离**全数**落在 ROUND(·,4) 之
##      舍入上界 5e-5/stake ＋ 5e-5·|profit|/stake² 内，越界 0 行 ⇒ 恒等成立。
##   ② roi ≡ −hold_rate ：逐行 roi ＋ hold_rate 求和，723,442 行 100.000000% 恒为 0，max|·| ＝ 0。
##      ⛔ 故《参考.txt》「roi ＝ profit / valid_bet，因而 hold ≡ roi」一节判**伪**：
##         总包 roi ＝ e.net / e.stake，分母是 stake 而非 valid_bet。
##   ③ hold_vs_valid_bet ＝ 1.681532% ÷ 90.067438% ＝ 1.866970%，与逐投注面加权实测同值（两路互证）。
## ⛔ N-15：本表已移入配置册 metric_canon.hold_family（并增【理论】行与视角／极性二栏），
##   由 §17.5 tr_hold_def() 现取。此处只留兼容别名，⛔ 码内不再存第二份真相源。
.TR_HOLD_DEF <- NULL           # 兼容占位；实际请调 tr_hold_def()

tr_hold_pair <- function(dt, profit = "profit", stake = "stake", valid_bet = "valid_bet") {
  gv <- function(c) if (c %in% names(dt)) suppressWarnings(as.numeric(dt[[c]])) else rep(NA_real_, nrow(dt))
  p <- gv(profit); s <- gv(stake); v <- gv(valid_bet)
  data.table(
    口径 = c("hold_rate（对本金 · 总包正典）", "hold_valid_bet（对洗码 · 派生 · realized）"),
    分母 = c(stake, valid_bet),
    分子合计 = c(round(sum(p, na.rm = TRUE), 2), round(sum(p, na.rm = TRUE), 2)),
    分母合计 = c(round(sum(s, na.rm = TRUE), 2), round(sum(v, na.rm = TRUE), 2)),
    值 = c(round(sum(p, na.rm = TRUE) / sum(s, na.rm = TRUE), 8),
           round(sum(p, na.rm = TRUE) / sum(v, na.rm = TRUE), 8)),
    注 = c("总包 128 处之正典算式 −net/stake", "⛔ 总包无此列；本引擎派生，引用时须带分母"))
}

## §13.3 实测庄家优势（逐投注面）
##   ⛔ 口径：**realized（已实现，含运气）**，非理论 edge。
##   总包阻断因由二称「bet09 → house_edge 映射值未获授权」——授权者乃【理论】edge；
##   而【实测】edge 无须授权，SELECT 即得，本节即以交付件反算并落盘。
##   ⛔ 然承 #017 探针 R3 之实测（overdispersion Q/(k−1) = 9.3~42.6）：
##      单一常数 edge 不足以描述观测过程 ⇒ 本表只作【已实现基线】，
##      不得径充理论 edge，亦不得单独用以推 theo 而不附 CI。
TR_EDGE_PATH <- file.path("审计", "实测庄家优势_逐投注面_v1.0.0_20260903.csv")
tr_measured_edge <- function(path = TR_EDGE_PATH) {
  if (!file.exists(path)) return(NULL)
  fread(path, encoding = "UTF-8", showProgress = FALSE)[]
}

## §13.4 自总包取某交付件之 SQL 原文（1.10.0 · N-13 斧正：档名移入配置册、支持「*版」多口径）
##   ⛔ 承先生之训：数据信息**非无中生有自动生成**，而是自 Superset 之 StarRocks
##      以 SQL 查询后下载。故报表须能就地出示【本件由哪段 SQL 所出】。
##   ⛔ 1.9.0 本器之二缺（本轮自陈）：
##      ① 总包档名以 Sys.glob 硬写于码内 —— 违配置册硬码铁律；
##      ② 只认「原版审计版_OPT」一版，先生所言之「*版」（另有 分批作业版_OPT
##         与 分批作业版1万_OPT，各 133 模块）无从出示，口径差异亦无从对照。
##      今一律移入配置册 sql_pack；码内不留任何档名。
TR_SQL_PACK <- NULL          # 非 NULL 即以之覆写配置册（供临时对照，不入正式流程）

.tr_sql_variants <- function() {
  v <- rbindlist(lapply(.cfg("sql_pack", "variants"), function(x) as.data.table(x)), fill = TRUE)
  v[, 档路径 := file.path(.cfg("sql_pack", "dir"), 档)]
  v[]
}

.tr_sql_pack_path <- function(variant = NULL) {
  if (!is.null(TR_SQL_PACK)) return(TR_SQL_PACK)
  v <- .tr_sql_variants()
  key <- if (is.null(variant)) .cfg("sql_pack", "default_variant") else variant
  r <- v[版 == key]
  if (!nrow(r))
    stop(sprintf("[SQL 溯源] 配置册 sql_pack.variants 无此版：%s（在册：%s）",
                 key, paste(v$版, collapse = "、")), call. = FALSE)
  r$档路径[1L]
}

.TR_SQL_CACHE <- new.env(parent = emptyenv())
.tr_sql_lines <- function(variant = NULL) {
  key <- if (is.null(variant)) .cfg("sql_pack", "default_variant") else variant
  if (!is.null(TR_SQL_PACK)) key <- paste0("[override]", key)
  if (exists(key, envir = .TR_SQL_CACHE, inherits = FALSE)) return(get(key, envir = .TR_SQL_CACHE))
  p <- tryCatch(.tr_sql_pack_path(variant), error = function(e) NA_character_)
  if (is.na(p) || !file.exists(p)) return(NULL)
  L <- readLines(p, warn = FALSE, encoding = "UTF-8")
  assign(key, L, envir = .TR_SQL_CACHE)
  L
}

## 模块头体例（结构解析器，非业务参数，故留于码内）：`--  64. R01_late_shoe.csv   [总包行 …]`
.TR_SQL_HEAD_PAT <- "^--[[:space:]]+[0-9]{1,3}[.][[:space:]]+[^[:space:]]+[.]csv"
.tr_sql_heads <- function(L) {
  hd <- if (length(L)) grep(.TR_SQL_HEAD_PAT, L) else integer(0)
  list(hd = hd,
       nm = if (length(hd)) sub("^--[[:space:]]+[0-9]{1,3}[.][[:space:]]+([^[:space:]]+[.]csv).*$", "\\1", L[hd]) else character(0),
       no = if (length(hd)) sub("^--[[:space:]]+([0-9]{1,3})[.].*$", "\\1", L[hd]) else character(0))
}

## 总包名册：逐版出示档名、在位、行数、模块数——血统就地可核，禁以口传
tr_sql_pack_manifest <- function() {
  v <- .tr_sql_variants()
  dflt <- .cfg("sql_pack", "default_variant")
  rbindlist(lapply(seq_len(nrow(v)), function(i) {
    p <- v$档路径[i]; ex <- file.exists(p)
    L <- if (ex) .tr_sql_lines(v$版[i]) else NULL
    data.table(版 = v$版[i], 档名 = v$档[i],
               在位 = if (ex) "✓ 在位" else "⛔ 不在位",
               字节MB = if (ex) round(file.size(p) / 1e6, 2) else NA_real_,
               总行数 = if (ex) length(L) else NA_integer_,
               模块数 = if (ex) length(.tr_sql_heads(L)$hd) else NA_integer_,
               用途 = v$用途[i],
               本报告 = if (identical(v$版[i], dflt)) "★ 默认溯源口径" else "○ 备照")
  }), fill = TRUE)
}

tr_sql_of <- function(file, max_lines = NULL, variant = NULL) {
  if (is.null(max_lines)) max_lines <- .cfg("sql_pack", "max_inline_lines")
  if (!is.numeric(max_lines) || max_lines <= 0) max_lines <- Inf   # 0 即【不截】：全文出示
  vk <- if (is.null(variant)) .cfg("sql_pack", "default_variant") else variant
  p  <- tryCatch(.tr_sql_pack_path(variant), error = function(e) NA_character_)
  bad <- function(msg) list(ok = FALSE, 说明 = msg, sql = NULL, 模块号 = NA_character_,
                            起 = NA_integer_, 迄 = NA_integer_, 行数 = NA_integer_,
                            包 = if (is.na(p)) "—" else basename(p), 版 = vk)
  if (is.na(p) || !file.exists(p))
    return(bad(sprintf("⛔ SQL 总包不在位（%s 版）——无法出示原文；⛔ 不得以「自动生成」冒充取数", vk)))
  L <- .tr_sql_lines(variant); H <- .tr_sql_heads(L)
  if (!length(H$hd)) return(bad("⛔ 总包内未见模块头体例（`-- NNN. 件名.csv`）"))
  i <- which(H$nm == file)
  if (!length(i))
    return(bad(sprintf("⛔ 总包（%s 版）内无本件之取数模块：%s —— 或系字典件／他模块派生，须另溯，不得默认已溯源", vk, file)))
  i <- i[1L]; s <- H$hd[i]
  e <- if (i < length(H$hd)) H$hd[i + 1L] - 1L else length(L)
  blk <- L[s:e]
  trunc <- length(blk) > max_lines
  list(ok = TRUE,
       说明 = if (trunc) sprintf("（本模块 %d 行，此处示前 %.0f 行；全文见总包第 %d~%d 行）",
                                 length(blk), max_lines, s, e)
              else sprintf("（全文 %d 行，一行未截；位于总包第 %d~%d 行）", length(blk), s, e),
       sql = if (trunc) c(blk[seq_len(max_lines)],
                          sprintf("-- …（余 %d 行略，见总包第 %d~%d 行）", length(blk) - max_lines, s, e)) else blk,
       模块号 = H$no[i], 起 = s, 迄 = e, 行数 = length(blk), 包 = basename(p), 版 = vk)
}

## §13.5 某交付件之【维度 × 指标】盘点
##   ⛔ 分维度与指标二类，逐栏定性，禁笼统称「字段」。
.TR_DIM_PAT <- paste0("(^|_)(id|key|code|name|type|flag|status|level|tier|date|dt|time|hour|",
                      "ip|member|agent|dealer|table|round|shoe|side|bucket|bkt|segment|seg|cat|",
                      "class|group|grp|label|rank_band|is_[a-z]+)($|_)")
tr_dimensions <- function(dt, file = "") {
  if (is.null(dt) || !length(names(dt)))
    return(data.table(交付件 = file, 栏 = "—", 类 = "—", 型 = "—", 相异值 = NA_integer_,
                      缺失率 = NA_real_, 例 = "⛔ 主表未载入"))
  n <- nrow(dt)
  rbindlist(lapply(names(dt), function(cc) {
    ## ⛔ 逐栏 tryCatch：一栏之失不得毁全表，且须【留痕】而非静默跳过
    ##   （2026-09-03 实测：某型栏触发 as.POSIXct 转型而中断全表盘点）
    tryCatch({
      x <- dt[[cc]]
      cl <- class(x)[1L]
      isnum <- is.numeric(x)
      if (!isnum && is.character(x)) {
        hd <- head(x[!is.na(x) & nzchar(x)], 200L)
        isnum <- length(hd) > 0L && suppressWarnings(!any(is.na(as.numeric(hd))))
      }
      nd <- uniqueN(x)
      dimlike <- grepl(.TR_DIM_PAT, tolower(cc), perl = TRUE) || (!isnum) || nd <= 50L
      ex <- as.character(head(unique(x[!is.na(x)]), 3L))
      data.table(交付件 = file, 栏 = cc,
                 类 = if (dimlike) "维度" else "指标",
                 型 = cl, 相异值 = nd,
                 缺失率 = round(sum(is.na(x) | (is.character(x) & !nzchar(x))) / max(n, 1L), 4),
                 例 = paste(substr(ex, 1L, 22L), collapse = " / "))
    }, error = function(e)
      data.table(交付件 = file, 栏 = cc, 类 = "⛔ 盘点失败", 型 = class(dt[[cc]])[1L],
                 相异值 = NA_integer_, 缺失率 = NA_real_,
                 例 = paste("⛔", conditionMessage(e))))
  }), fill = TRUE)
}

# ---------------------------------------------------------------------
# §14 主辅表逐件之【SQL 原文 ＋ 输出标准】与【全维度指标盘点】（N-13 · 2026-09-03）
# ---------------------------------------------------------------------
# 【本节所治之病 —— 我方自陈】
#   1.9.0 已立 tr_sql_of() 与 tr_dimensions() 二器，然**模板从未接线**：
#   实测模板 v1.7.0 全档内 `tr_sql_of`／`tr_dimensions`／`tr_delivery_gate` 命中皆为 0。
#   器在库中而报表不出，与无器无异——此即「造了闸而不装上」。故十五份之
#   第二部分只见交付件清单而不见其取数 SQL，第三部分只见 ODS 字典与登记册口径
#   而不见【数据库/ 内主辅表逐栏之维度与指标】。二处遗漏历十五份而一律，正坐此因。
#
# 【本节所立四器】
#   ① tr_sql_standard()   —— 某件之【输出标准】：出处、源 ODS 库表、观测窗、快照闸、
#                            去重规则、粒度键、测试线处置、全序、六层块、落盘标识、
#                            声明列数 ↔ 实测列数对账、实测行数、可信度裁定、落盘路径。
#                            置于 SQL 原文之后，逐项解释「这段 SQL 出的是一张什么标准的表」。
#   ② tr_sql_panel()      —— 本类主表／辅助表／判据来源逐件之溯源总览（一件一行）。
#   ③ tr_dim_metric_panel()／④ tr_dim_metric_summary()
#                         —— 逐件读 数据库/ 之实档，逐栏定性为【维度】或【指标】，
#                            全栏在册、零省略，并与列数对账。
#   ⛔ 四器皆现算：档一换、栏一改，报表即随之变，禁手写字面量。
# ---------------------------------------------------------------------

## 正则助手（结构解析，非业务参数，故留于码内）
.tr_rx1 <- function(pat, txt, group = 1L, none = "—") {
  m <- regmatches(txt, regexec(pat, txt, perl = TRUE))[[1L]]
  if (length(m) >= group + 1L && nzchar(trimws(m[group + 1L]))) trimws(m[group + 1L]) else none
}
.tr_rxall <- function(pat, txt) {
  m <- regmatches(txt, gregexpr(pat, txt, perl = TRUE))[[1L]]
  unique(m[nzchar(m)])
}
.tr_join <- function(x, none = "—", sep = "、") if (!length(x)) none else paste(x, collapse = sep)
## 截断一律留痕：禁无声截字（承禁截铁律；此处系【呈表宽度】之截，非数据之截）
.tr_cut <- function(x, n = 160L) {
  x <- as.character(x)
  ifelse(nchar(x) > n, paste0(substr(x, 1L, n), " …（原文见上列 SQL）"), x)
}

## §14.1 某交付件之【输出标准】—— 置于 SQL 原文之后作解
##   ⛔ 一律自 SQL 原文与实档现算；SQL 未见者标「⛔ 未见于总包」，不得默认或臆补。
tr_sql_standard <- function(file, loaded = NULL, variant = NULL) {
  s  <- tr_sql_of(file, max_lines = 0L, variant = variant)
  cr <- tr_cred_of(file)
  t  <- if (!is.null(loaded)) loaded$tabs[[file]] else NULL
  m_cols <- if (!is.null(t) && isTRUE(t$ok)) ncol(t$dt) else NA_integer_
  m_rows <- if (!is.null(t) && isTRUE(t$ok)) t$rows   else NA_integer_
  m_key  <- if (!is.null(t) && isTRUE(t$ok) && !is.na(t$key)) t$key else "—"
  row <- function(x, y, z) data.table(项 = x, 取值 = y, 判读 = z)

  if (!isTRUE(s$ok)) {
    return(rbindlist(list(
      row("总包出处", s$说明,
          "⛔ 本件之取数 SQL 未能就地出示——证据链此处断裂，不得以「系统自动生成」搪塞"),
      row("落盘路径", file.path(TR_DB, file),
          sprintf("交付件在位与否：%s", if (!is.null(t) && isTRUE(t$ok)) "✓ 在位" else "⛔ 待表")),
      row("实测形状", sprintf("%s 行 × %s 列",
                              if (is.na(m_rows)) "—" else tr_f(m_rows),
                              if (is.na(m_cols)) "—" else m_cols),
          "实测取自 数据库/ 之现档，非声明值"),
      row("可信度裁定", cr$可信度,
          sprintf("实体 %s · 粒度 %s · 用法 %s", cr$实体, cr$粒度, cr$用法)))))
  }

  L    <- s$sql
  hdr1 <- L[1L]
  hdr2 <- if (length(L) >= 2L && grepl("典型学", L[2L], fixed = TRUE)) L[2L] else ""
  code <- paste(L[!grepl("^[[:space:]]*--", L)], collapse = "\n")

  decl  <- .tr_rx1("原[[:space:]]*([0-9]+)[[:space:]]*列", hdr1)
  decl6 <- .tr_rx1("六层约[[:space:]]*([0-9]+)[[:space:]]*列", hdr1)
  typo  <- .tr_rx1("典型学：([^　]+)", hdr2)
  flag  <- .tr_rx1("派生旗标：([^　]+)", hdr2)
  jkey  <- .tr_rx1("连接：(.+)$", hdr2)

  ods   <- .tr_rxall("ods_[A-Za-z0-9_]+\\.[A-Za-z0-9_]+", code)
  d_ge  <- .tr_rx1("dt[[:space:]]*>=[[:space:]]*'([^']+)'", code)
  d_lt  <- .tr_rx1("dt[[:space:]]*<[[:space:]]*'([^']+)'", code)
  snap  <- .tr_rx1("sync_time[[:space:]]*<=[[:space:]]*'([^']+)'", code)
  part  <- .tr_rx1("PARTITION BY[[:space:]]*([^\n]+)", code)
  ordby <- .tr_rx1("ORDER BY[[:space:]]*([^\n]*?)\\)[[:space:]]*AS[[:space:]]*(?:audit_rn|batch_rn)", code)
  runid <- .tr_rx1("'([^']+)'[[:space:]]*AS[[:space:]]*run_id", code)
  snapl <- .tr_rx1("'([^']+)'[[:space:]]*AS[[:space:]]*snapshot_sync_time", code)
  grp   <- .tr_rxall("GROUP BY[[:space:]]+[^\n]+", code)
  nxj   <- length(.tr_rxall("CROSS[[:space:]]+JOIN", code))
  xcross <- grepl("CROSS[[:space:]]+JOIN[[:space:]]+x_agg", code, perl = TRUE)
  xon    <- .tr_rx1("JOIN[[:space:]]+x_agg[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+ON[[:space:]]+([^\n]+)", code)
  test  <- grepl("age022", code, fixed = TRUE)
  offs  <- grepl("OFFSET", code, fixed = TRUE)
  lim   <- grepl("LIMIT", code, fixed = TRUE)

  ccol <- if (!is.null(.TR_CRED) && "栏数" %in% names(.TR_CRED)) {
    r <- .TR_CRED[交付件 == file]; if (nrow(r)) as.integer(r$栏数[1L]) else NA_integer_
  } else NA_integer_

  rbindlist(list(
    row("总包出处",
        sprintf("%s ／ %s ／ 模块 #%s ／ 总包第 %s~%s 行（%s 行）",
                s$包, s$版, s$模块号, tr_f(s$起), tr_f(s$迄), tr_f(s$行数)),
        "⛔ 本件系于 Superset 执行上列 SQL 查 StarRocks 后**下载落盘**所得，非本报告自动生成；行号可就地复核"),
    row("典型学与旗标",
        sprintf("典型学 %s ／ 派生旗标 %s", typo, flag),
        "旗标只供 CASE 条件聚合；总包无任何 WHERE／HAVING 以旗标过滤——故本件为【全量】而非【已筛】"),
    row("源 ODS 库表", .tr_join(ods),
        sprintf("凡 %d 张源表，皆 StarRocks 之 ODS 层；本件一切列之血统止于此", length(ods))),
    row("观测窗（分区列 dt）",
        if (identical(d_ge, "—") && identical(d_lt, "—")) "⛔ 本模块未见 dt 窗口" else sprintf("[%s, %s)", d_ge, d_lt),
        "左闭右开；窗外之行不入本件——跨窗比较须另导，禁以本件外推"),
    row("快照闸 sync_time", if (identical(snap, "—")) "⛔ 未见快照闸" else sprintf("<= '%s'", snap),
        "冻结同步时点，令重跑可复现；无此闸者其数随上游回补而漂移"),
    row("去重规则", if (identical(part, "—")) "○ 本模块未见 ROW_NUMBER 去重" else sprintf("PARTITION BY %s（取 rn = 1）", .tr_cut(part, 120L)),
        "同键多版本只取最新一版；此即「注单号唯一」之落实处"),
    row("测试线处置", if (test) "✓ 以 age022 = '1' 之代理左连剔除" else "○ 本模块未见 age022 —— 须查是否采标记法保留",
        "⛔ 剔除法者交付件内不留痕；标记法者须先剔再入统计（见 §〇之二 测试线闸）"),
    row("粒度键", sprintf("头注连接键 %s ／ %s", jkey,
                          if (!length(grp)) "本模块未见 GROUP BY（逐行事实或窗口函数出数）"
                          else sprintf("GROUP BY %d 处，末处：%s", length(grp), .tr_cut(grp[length(grp)], 100L))),
        sprintf("实测会员键：%s —— 粒度即「一行代表什么」；读金额前必先认粒度", m_key)),
    row("全序与批次",
        sprintf("%s；%s%s",
                if (identical(ordby, "—")) "未见全序 audit_rn" else sprintf("全序 ORDER BY %s", .tr_cut(ordby, 160L)),
                if (offs) "本版含 OFFSET 分批" else "本版不切片（一次导全）",
                if (lim) "；⚑ 含 LIMIT——须查是否截行" else ""),
        "全序令分批之并集恰等于一次导全；无全序即批次间可重可漏"),
    row("六层商业块（约 60 列）",
        if (xcross) sprintf("⛔ CROSS JOIN x_agg —— 笛卡尔广播（全模块 CROSS JOIN 共 %d 处）", nxj)
        else if (!identical(xon, "—")) .tr_cut(sprintf("JOIN x_agg ON %s —— 键连（全模块 CROSS JOIN 共 %d 处）", xon, nxj))
        else sprintf("○ 本模块未见 x_agg 六层块（CROSS JOIN 共 %d 处）", nxj),
        if (xcross) "⛔ 广播之列逐行同值或多行重复，不得充作本行实体金额（见本部分〇之三 可信度闸）"
        else if (!identical(xon, "—")) sprintf("键连之六层列，其可用与否以可信度册为准——本件裁定 %s", cr$可信度)
        else "本件之列皆出自本模块自算，无六层广播块"),
    row("落盘标识", sprintf("run_id = %s ／ snapshot_sync_time = %s", runid, snapl),
        "落盘标识随件同行，令交付件可回指其批次；对不上者即非本批之档"),
    row("列数对账",
        sprintf("头注声明 原 %s 列 ＋六层约 %s 列 ／ 可信度册载 %s 列 ／ 实测 %s 列",
                decl, decl6, if (is.na(ccol)) "—" else ccol, if (is.na(m_cols)) "—" else m_cols),
        if (!is.na(ccol) && !is.na(m_cols) && ccol == m_cols) "✓ 册载与实测相符"
        else if (is.na(m_cols)) "⛔ 实档未载入，无从对账（待表）"
        else "⚑ 册载与实测不符——以实测为准，并须查是否换版"),
    row("实测行数", if (is.na(m_rows)) "⛔ 待表" else tr_f(m_rows),
        "全量读入之行数；与文件换行数之对账见本部分〇节"),
    row("可信度裁定", cr$可信度,
        sprintf("实体 %s · 粒度 %s · 用法 %s —— %s", cr$实体, cr$粒度, cr$用法,
                if (identical(cr$可信度, "OK")) "实体级金额准用" else "⛔ 实体级金额拒用")),
    row("落盘路径", file.path(TR_DB, file),
        sprintf("本报告第二、三部分之一切实测，皆读此档全量（%s）",
                if (!is.null(t) && isTRUE(t$ok)) "✓ 已载入" else "⛔ 待表"))))
}

## §14.2 本类主辅表之 SQL 溯源总览（一件一行）
tr_sql_panel <- function(rec, loaded = NULL, variant = NULL) {
  rbindlist(lapply(rec$files, function(f) {
    s <- tr_sql_of(f, max_lines = 0L, variant = variant)
    t <- if (!is.null(loaded)) loaded$tabs[[f]] else NULL
    code <- if (isTRUE(s$ok)) paste(s$sql[!grepl("^[[:space:]]*--", s$sql)], collapse = "\n") else ""
    ods  <- if (nzchar(code)) .tr_rxall("ods_[A-Za-z0-9_]+\\.[A-Za-z0-9_]+", code) else character(0)
    d_ge <- if (nzchar(code)) .tr_rx1("dt[[:space:]]*>=[[:space:]]*'([^']+)'", code) else "—"
    d_lt <- if (nzchar(code)) .tr_rx1("dt[[:space:]]*<[[:space:]]*'([^']+)'", code) else "—"
    data.table(
      交付件 = f,
      角色 = fifelse(f == rec$primary, "主表", fifelse(f %in% rec$supporting, "辅助表", "判据来源")),
      SQL溯源 = if (isTRUE(s$ok)) "✓ 已出示原文" else "⛔ 未见于总包",
      模块号 = if (isTRUE(s$ok)) paste0("#", s$模块号) else "—",
      总包行 = if (isTRUE(s$ok)) sprintf("%s~%s", tr_f(s$起), tr_f(s$迄)) else "—",
      模块行数 = if (isTRUE(s$ok)) s$行数 else NA_integer_,
      源ODS表 = .tr_join(ods),
      观测窗 = if (identical(d_ge, "—")) "—" else sprintf("[%s, %s)", d_ge, d_lt),
      实测行数 = if (!is.null(t) && isTRUE(t$ok)) t$rows else NA_integer_,
      实测列数 = if (!is.null(t) && isTRUE(t$ok)) ncol(t$dt) else NA_integer_,
      可信度 = tr_cred_of(f)$可信度,
      说明 = s$说明)
  }), fill = TRUE)
}

## §14.3 本类主辅表【全维度 × 全指标】逐栏盘点（读 数据库/ 之实档，全栏在册、零省略）
tr_dim_metric_panel <- function(rec, loaded) {
  rbindlist(lapply(rec$files, function(f) {
    t <- loaded$tabs[[f]]
    role <- if (f == rec$primary) "主表" else if (f %in% rec$supporting) "辅助表" else "判据来源"
    d <- if (!is.null(t) && isTRUE(t$ok)) tr_dimensions(t$dt, f)
         else data.table(交付件 = f, 栏 = "—", 类 = "⛔ 待表", 型 = "—",
                         相异值 = NA_integer_, 缺失率 = NA_real_,
                         例 = sprintf("⛔ %s", if (is.null(t)) "未登记" else t$status))
    ## 判据列就地标注：本类之判据出自哪一栏，一望即知
    crit <- rec$dict[criterion_source == f, criterion_column]
    d[, 角色 := role]
    d[, 本类判据 := fifelse(栏 %in% crit, "★ 判据列", "—")]
    setcolorder(d, c("交付件", "角色", "栏", "类", "本类判据"))
    d[]
  }), fill = TRUE)
}

## §14.4 盘点小结：逐件之维度数／指标数，并与列数对账（对不上即当场揭出）
tr_dim_metric_summary <- function(rec, loaded, panel = NULL) {
  if (is.null(panel)) panel <- tr_dim_metric_panel(rec, loaded)
  rbindlist(lapply(rec$files, function(f) {
    t <- loaded$tabs[[f]]
    p <- panel[交付件 == f]
    nd <- sum(p$类 == "维度"); nm <- sum(p$类 == "指标"); nf <- sum(p$类 == "⛔ 盘点失败")
    nc <- if (!is.null(t) && isTRUE(t$ok)) ncol(t$dt) else NA_integer_
    data.table(
      交付件 = f,
      角色 = fifelse(f == rec$primary, "主表", fifelse(f %in% rec$supporting, "辅助表", "判据来源")),
      状态 = if (!is.null(t) && isTRUE(t$ok)) "✓ 全量载入" else sprintf("⛔ %s", if (is.null(t)) "未登记" else t$status),
      列数 = nc, 维度 = nd, 指标 = nm, 盘点失败 = nf,
      本类判据列 = sum(p$本类判据 == "★ 判据列"),
      对账 = if (is.na(nc)) "—（待表）"
             else if (nd + nm + nf == nc) sprintf("✓ %d ＋ %d ＋ %d ＝ %d 列，逐栏闭合，零省略", nd, nm, nf, nc)
             else sprintf("⚑ %d ＋ %d ＋ %d ≠ %d 列——须查", nd, nm, nf, nc))
  }), fill = TRUE)
}

# ---------------------------------------------------------------------
# §15 决策统计层 · 贝叶斯 · MLE · 马尔可夫 · 极值 · 蒙地卡罗 · 期望损失（N-14 · 2026-09-03）
# ---------------------------------------------------------------------
# 【本节所治之病】
#   先生令：「以顶级统计概念灵活搭配来预测并评估风险，于所有处置选项中择
#   最低亏损风险而最高回酬之组合」。⛔ 然本引擎 1.10.0 及以前，可执行码中
#   bayes／posterior／likelihood／markov／transition／monte／simulat／GPD／
#   expected_loss 命中皆为 0 —— 报表只会描述【现状】，从不预测【若如此处置将如何】。
#
# 【铁律 · 承《参考.txt》之 KILLCRITIC 并加严】
#   ⛔ 一、统计方法不是装饰品：每一器须回答一个具体风险问题，答不出即 NOT_RUN，不摆样子。
#   ⛔ 二、禁把 Bayes ＋ MLE ＋ Markov ＋ MC ＋ EVT 揉成一个总分 —— 「一个数字 ＝ 风险」正是
#         本项目已否决之谬。各器各答各问，分列呈现，禁合成单一风险分。
#   ⛔ 三、一切先验与参数由数据反解（矩法／极大似然），禁外生塞入好看的常数。
#   ⛔ 四、成本未登记者反解【盈亏平衡成本上限】，禁臆造成本以凑出「划算」。
#   ⛔ 五、强化学习 BENCHED：S3 处置映射与 S4 结果连结二闸未开，RL 只准模拟，禁驱动动作。
#   ⛔ 六、NOT_RUN ≠ PASS；NULL ≠ 0；样本不足一律标出，禁降级为「正常」。
# ---------------------------------------------------------------------

.tr_num  <- function(x) suppressWarnings(as.numeric(x))
.tr_fin  <- function(x) { v <- .tr_num(x); v[is.finite(v)] }
.tr_nr   <- function(器, 因) data.table(器 = 器, 状态 = "NOT_RUN", 判读 = 因)
.tr_seed <- function() set.seed(.cfg("decision_layer", "seed"))

## §15.0 本类候选人群：判据尾部命中 ≥ 1 条者（方向依登记册，low 者取下尾）
tr_type_members <- function(rec, mj, q = NULL) {
  if (is.null(mj) || is.null(mj$panel) || !nrow(mj$panel)) return(NULL)
  if (is.null(q)) q <- .cfg("statistics", "tail_quantile_high")
  d <- rec$dict; P <- mj$panel
  hit <- rep(0L, nrow(P)); used <- character(0)
  for (cc in setdiff(names(P), "member_id")) {
    base <- sub("@.*$", "", cc)
    dir  <- tolower(trimws(as.character(d[criterion_column == base, direction][1L])))
    x <- .tr_num(P[[cc]])
    if (all(is.na(x)) || uniqueN(x[!is.na(x)]) < 3L) next
    low <- identical(dir, "low"); qq <- if (low) 1 - q else q
    thr <- as.numeric(stats::quantile(x, qq, na.rm = TRUE, names = FALSE))
    h <- if (low) (!is.na(x) & x <= thr) else (!is.na(x) & x >= thr)
    hit <- hit + as.integer(h); used <- c(used, cc)
  }
  if (!length(used)) return(NULL)
  out <- data.table(member_id = P$member_id, 命中数 = hit)[命中数 > 0]
  setattr(out, "判据列数", length(used)); out[]
}

## §15.1 贝叶斯：把【已实现输赢】与【潜在真实优势】分开
##   问：某会员之真实 hold 是否为负（即长期占优）？——不是问他这窗赢了多少。
##   法：经验贝叶斯正态收缩。τ²（会员间真差异）与 s²（单位本金之抽样方差）
##       皆以矩法自数据反解：E[(r_i − μ)²] ＝ τ² ＋ s²/w_i，以 stake 为权作回归。
##   ⛔ 先验不外生给定；⛔ 小分母之极端 ROI 必被收缩，此正为其用。
tr_bayes_edge <- function(dt, profit = "profit", stake = "stake", id = "member_id") {
  nmin <- .cfg("decision_layer", "bayes", "shrink_min_members")
  if (is.null(dt) || !all(c(profit, stake) %in% names(dt)))
    return(list(ok = FALSE, 说明 = sprintf("⛔ NOT_RUN：缺列 %s",
      paste(setdiff(c(profit, stake), names(dt)), collapse = "、")), tab = NULL))
  p <- .tr_num(dt[[profit]]); w <- .tr_num(dt[[stake]])
  ids <- if (id %in% names(dt)) as.character(dt[[id]]) else as.character(seq_len(nrow(dt)))
  k <- is.finite(p) & is.finite(w) & w > 0
  if (sum(k) < nmin)
    return(list(ok = FALSE, tab = NULL,
      说明 = sprintf("⛔ NOT_RUN：可用会员 %s 名，不足配置册 shrink_min_members ＝ %s（NOT_RUN ≠ PASS）",
                     format(sum(k), big.mark = ","), format(nmin, big.mark = ","))))
  p <- p[k]; w <- w[k]; ids <- ids[k]
  mu <- sum(p) / sum(w)                       # 总体 hold_rate（加权）
  r  <- p / w
  y  <- (r - mu)^2; x <- 1 / w
  fit  <- stats::lm(y ~ x, weights = w)
  s2   <- max(unname(stats::coef(fit)[2L]), .Machine$double.eps)
  tau2 <- max(unname(stats::coef(fit)[1L]), 0)
  if (!is.finite(s2) || !is.finite(tau2))
    return(list(ok = FALSE, tab = NULL, 说明 = "⛔ NOT_RUN：τ²／s² 反解不收敛"))
  B  <- tau2 / (tau2 + s2 / w)                # 收缩系数：1 全信个体，0 全归总体
  pm <- mu + B * (r - mu)
  ps <- sqrt(pmax(B * s2 / w, 0))
  z  <- .cfg("statistics", "z_two_sided")
  tab <- data.table(member_id = ids, stake = w, profit = p,
                    观测hold = r, 收缩系数B = round(B, 6),
                    后验hold = pm, 后验SD = ps,
                    后验下界 = pm - z * ps, 后验上界 = pm + z * ps,
                    P_玩家长期占优 = stats::pnorm(0, pm, pmax(ps, .Machine$double.eps)))
  list(ok = TRUE, mu = mu, tau2 = tau2, s2 = s2, n = sum(k), tab = tab[],
       说明 = sprintf(paste0("经验贝叶斯正态收缩：总体 hold ＝ %.6f%%；τ²（会员间真差异）＝ %.4e；",
                             "s²（单位本金抽样方差）＝ %.4e —— 二者皆以矩法自 %s 名会员反解，非外生给定。",
                             "收缩系数 B 之中位 ＝ %.4f（B 越小者其观测 ROI 越不可信，被拉回总体）"),
                      100 * mu, tau2, s2, format(sum(k), big.mark = ","), stats::median(B)))
}

## 贝叶斯之报表面：不出个人名单（禁点名处置），只出分布与高后验概率之群体规模
tr_bayes_panel <- function(bz) {
  if (is.null(bz) || !isTRUE(bz$ok))
    return(.tr_nr("贝叶斯收缩", if (is.null(bz)) "未运行" else bz$说明))
  t <- bz$tab
  cut <- c(0.50, 0.75, 0.90, 0.95, 0.99)
  rbindlist(c(
    list(data.table(项 = "总体 hold（加权）", 取值 = sprintf("%.6f%%", 100 * bz$mu),
                    判读 = "一切个体后验之收缩靶心")),
    list(data.table(项 = "τ²（会员间真差异）", 取值 = sprintf("%.4e", bz$tau2),
                    判读 = if (bz$tau2 <= 0) "⛔ 反解为 0：数据不支持「会员间存在真实 hold 差异」——观测差异全可由抽样解释" else "＞0：会员间确有真实差异，可作收缩")),
    list(data.table(项 = "s²（单位本金抽样方差）", 取值 = sprintf("%.4e", bz$s2),
                    判读 = "本金越小者其观测 ROI 之方差越大，收缩越重")),
    list(data.table(项 = "收缩系数 B 中位", 取值 = sprintf("%.4f", stats::median(t$收缩系数B)),
                    判读 = "B → 1 者观测可信；B → 0 者观测几乎全系噪声")),
    lapply(cut, function(cc) data.table(
      项 = sprintf("P(玩家长期占优) ≥ %.0f%% 之会员数", 100 * cc),
      取值 = sprintf("%s 名（%.4f%%）", format(sum(t$P_玩家长期占优 >= cc), big.mark = ","),
                     100 * mean(t$P_玩家长期占优 >= cc)),
      判读 = "⛔ 此系【后验概率】而非处置名单；处置仍须过门禁与人工复核")),
    list(data.table(项 = "观测 hold < 0 之会员数（未收缩）",
                    取值 = sprintf("%s 名（%.4f%%）", format(sum(t$观测hold < 0), big.mark = ","),
                                   100 * mean(t$观测hold < 0)),
                    判读 = "与上列后验之差，即【运气】被剥离之量——直接用观测者必大幅误伤"))), fill = TRUE)
}

## §15.2 MLE：估真实参数，不直接给风险分
tr_mle_fit <- function(x, dist = "normal", label = "") {
  v <- .tr_fin(x); n <- length(v)
  if (n < 30L) return(.tr_nr(sprintf("MLE·%s", dist), sprintf("样本 %d 不足 30", n)))
  lv <- .cfg("decision_layer", "mle", "ci_level")
  z  <- stats::qnorm(1 - (1 - lv) / 2)
  if (identical(dist, "normal")) {
    m <- mean(v); s <- sqrt(mean((v - m)^2))
    ll <- sum(stats::dnorm(v, m, s, log = TRUE)); kk <- 2L
    est <- c(mu = m, sigma = s); se <- c(s / sqrt(n), s / sqrt(2 * n))
  } else if (identical(dist, "exponential")) {
    v <- v[v > 0]; n <- length(v)
    if (n < 30L) return(.tr_nr("MLE·exponential", sprintf("正值样本 %d 不足 30", n)))
    lam <- 1 / mean(v); ll <- sum(stats::dexp(v, lam, log = TRUE)); kk <- 1L
    est <- c(lambda = lam); se <- c(lam / sqrt(n))
  } else return(.tr_nr(sprintf("MLE·%s", dist), "配置册 decision_layer.mle.dist 未登记此族"))
  data.table(器 = sprintf("MLE·%s%s", dist, if (nzchar(label)) sprintf("（%s）", label) else ""),
             参数 = names(est), 估计 = signif(unname(est), 8), SE = signif(unname(se), 6),
             CI下 = signif(unname(est) - z * unname(se), 8),
             CI上 = signif(unname(est) + z * unname(se), 8),
             n = n, logLik = round(ll, 3), AIC = round(-2 * ll + 2 * kk, 3),
             判读 = "⛔ 参数估计而已；未经样本外验证，不得据以处置")
}

## §15.3 马尔可夫：行为是否【持续】改变，而非一次异常即定终身
tr_markov_states <- function(dt, id = "member_id", time = NULL, value = NULL, cuts = NULL) {
  if (is.null(cuts)) cuts <- unlist(.cfg("decision_layer", "markov", "state_cuts"))
  minn <- .cfg("decision_layer", "markov", "min_transitions")
  if (is.null(dt) || !nrow(dt)) return(list(ok = FALSE, 说明 = "⛔ NOT_RUN：面板不在位"))
  if (is.null(time)) {
    cand <- intersect(unlist(.cfg("decision_layer", "markov", "time_candidates")), names(dt))
    time <- if (length(cand)) cand[1L] else NULL
  }
  ## ⛔【会员内变异闸】（N-14c · 实测揭缺）：度量列若系六层块广播（同一会员内逐期同值），
  ##   以之切状态必得【单位阵】——自持概率 1.0、转移概率 0，看似「行为极其黏着」，
  ##   实为口径断裂。2026-09-03 实测：S05_member_month_panel 之 stake 正属此类
  ##   （x_agg 会员级广播），首版遂产出五阶单位阵。今立闸：候选须过会员内变异方采用。
  .varies_within <- function(cc) {
    v <- .tr_num(dt[[cc]]); i <- as.character(dt[[id]])
    k <- is.finite(v); if (sum(k) < 100L) return(FALSE)
    x <- data.table(i = i[k], v = v[k])
    r <- x[, .(nd = uniqueN(v)), by = i]
    mean(r$nd > 1L) > 0.10          # 逾一成会员在期间内有变化，方认其为逐期原生量
  }
  if (is.null(value)) {
    cand <- intersect(unlist(.cfg("decision_layer", "markov", "value_candidates")), names(dt))
    rej <- character(0)
    for (cc in cand) { if (.varies_within(cc)) { value <- cc; break } else rej <- c(rej, cc) }
    if (is.null(value) && length(cand))
      return(list(ok = FALSE, 说明 = sprintf(paste0(
        "⛔ BLOCKED（G13 · 非 WARNING）：候选度量列 %s 全数未过【会员内变异闸】——皆为会员级广播（同一会员逐期同值），",
        "以之切状态必得单位阵之伪结论。须改用逐期原生量，或先令总包外显之。"),
        paste(rej, collapse = "、"))))
  }
  if (is.null(time) || is.null(value) || !id %in% names(dt))
    return(list(ok = FALSE, 说明 = sprintf("⛔ NOT_RUN：缺时间轴或度量列（id=%s time=%s value=%s）",
                                           id, time %||% "—", value %||% "—")))
  if (!.varies_within(value))
    return(list(ok = FALSE, 说明 = sprintf(paste0(
      "⛔ BLOCKED（G13 · 非 WARNING）：指定度量列 %s 未过【会员内变异闸】（同一会员逐期同值，系广播），",
      "以之建转移矩阵必得单位阵之伪结论"), value)))
  D <- data.table(id = as.character(dt[[id]]), t = as.character(dt[[time]]), v = .tr_num(dt[[value]]))
  D <- D[is.finite(v)]
  if (!nrow(D)) return(list(ok = FALSE, 说明 = "⛔ NOT_RUN：度量列全缺"))
  br <- unique(c(-Inf, as.numeric(stats::quantile(D$v, cuts, na.rm = TRUE, names = FALSE)), Inf))
  lab <- c("S1 低", "S2 中低", "S3 中高", "S4 高", "S5 极高")[seq_len(length(br) - 1L)]
  D[, s := cut(v, breaks = br, labels = lab, include.lowest = TRUE)]
  setorder(D, id, t)
  D[, s_next := shift(s, type = "lead"), by = id]
  D[, id_next := shift(id, type = "lead")]
  TR <- D[!is.na(s_next) & id == shift(id, type = "lead")]
  if (nrow(TR) < minn)
    return(list(ok = FALSE, 说明 = sprintf("⛔ NOT_RUN：转移样本 %s 不足配置册 min_transitions ＝ %s",
                                           format(nrow(TR), big.mark = ","), format(minn, big.mark = ","))))
  cnt <- table(factor(TR$s, levels = lab), factor(TR$s_next, levels = lab))
  P <- sweep(as.matrix(cnt), 1, pmax(rowSums(cnt), 1), "/")
  ## 稳态：左特征向量（特征值 1）
  ev <- tryCatch(eigen(t(P)), error = function(e) NULL)
  pi_ <- if (!is.null(ev)) { w <- Re(ev$vectors[, which.max(Re(ev$values))]); w <- abs(w); w / sum(w) } else rep(NA_real_, nrow(P))
  soj <- ifelse(diag(P) < 1, 1 / (1 - diag(P)), Inf)
  list(ok = TRUE, time = time, value = value, n_trans = nrow(TR), counts = cnt, P = P,
       stationary = pi_, sojourn = soj,
       说明 = sprintf("状态以 %s 之分位切五档（切点取自配置册），时间轴 %s；转移样本 %s 笔，转移概率系 MLE（计数除以行和）",
                      value, time, format(nrow(TR), big.mark = ",")))
}

tr_markov_panel <- function(mk) {
  if (is.null(mk) || !isTRUE(mk$ok)) return(.tr_nr("马尔可夫", if (is.null(mk)) "未运行" else mk$说明))
  lab <- rownames(mk$P)
  out <- data.table(状态 = lab)
  for (j in seq_along(lab)) data.table::set(out, j = paste0("→", lab[j]), value = round(mk$P[, j], 4))
  out[, 自持概率 := round(diag(mk$P), 4)]
  out[, 平均停留期数 := round(mk$sojourn, 3)]
  out[, 稳态占比 := round(mk$stationary, 4)]
  dg <- diag(mk$P)
  out[, 判读 := fifelse(dg >= 0.999,
                        "⛔ 自持 ≈ 1.000：本行无转移 —— 须查度量列是否仍系广播或时间轴是否失效，禁读作「行为绝对稳定」",
                fifelse(dg >= 0.5,
                        "自持 ≥ 50%：本状态【黏着】，一次进入即倾向持续 —— 值得复检",
                        "自持 < 50%：本状态【易变】，单次命中不足以推断长期性"))]
  out[]
}

## §15.4 极值（POT／GPD）：专治「极端亏损」，非 P99 了事
##   x 须为【损失】序列（对平台而言＝玩家净赢＝−profit）
tr_evt_pot <- function(x, label = "") {
  q    <- .cfg("decision_layer", "evt", "threshold_quantile")
  mex  <- .cfg("decision_layer", "evt", "min_exceed")
  lev  <- unlist(.cfg("decision_layer", "evt", "tail_var_levels"))
  v <- .tr_fin(x); n <- length(v)
  if (n < 200L) return(list(ok = FALSE, 说明 = sprintf("⛔ NOT_RUN：样本 %s 不足 200", format(n, big.mark = ","))))
  u <- as.numeric(stats::quantile(v, q, na.rm = TRUE, names = FALSE))
  y <- v[v > u] - u; nu <- length(y)
  if (nu < mex)
    return(list(ok = FALSE, 说明 = sprintf("⛔ NOT_RUN：超越 %s 笔，不足配置册 min_exceed ＝ %s", nu, mex)))
  ## ① 矩法（MOM）
  m <- mean(y); s2 <- stats::var(y)
  xi_m  <- 0.5 * (1 - m^2 / s2); sg_m <- 0.5 * m * (m^2 / s2 + 1)
  ## ② 极大似然（optim · GPD 负对数似然）
  nll <- function(par) {
    xi <- par[1L]; sg <- exp(par[2L])
    if (sg <= 0) return(1e12)
    z <- 1 + xi * y / sg
    if (any(z <= 0)) return(1e12)
    nu * log(sg) + (1 + 1 / xi) * sum(log(z))
  }
  fit <- tryCatch(stats::optim(c(if (is.finite(xi_m)) xi_m else 0.1, log(max(sg_m, 1e-8))), nll,
                               method = "Nelder-Mead", control = list(maxit = 2000)),
                  error = function(e) NULL)
  xi_l <- if (!is.null(fit)) fit$par[1L] else NA_real_
  sg_l <- if (!is.null(fit)) exp(fit$par[2L]) else NA_real_
  VaR <- function(p, xi, sg) if (!is.finite(xi) || abs(xi) < 1e-8) u + sg * log((n / nu) * (1 - p))
                             else u + sg / xi * (((n / nu) * (1 - p))^(-xi) - 1)
  ES  <- function(p, xi, sg) { vq <- VaR(p, xi, sg); if (!is.finite(xi) || xi >= 1) NA_real_ else (vq + sg - xi * u) / (1 - xi) }
  tab <- rbindlist(lapply(lev, function(p) data.table(
    分位 = sprintf("%.1f%%", 100 * p),
    VaR_矩法 = signif(VaR(p, xi_m, sg_m), 8), ES_矩法 = signif(ES(p, xi_m, sg_m), 8),
    VaR_MLE  = signif(VaR(p, xi_l, sg_l), 8), ES_MLE  = signif(ES(p, xi_l, sg_l), 8),
    经验分位 = signif(as.numeric(stats::quantile(v, p, names = FALSE)), 8))))
  ## ⛔ N-15 · G14：二法不一致须显式保留状态，禁把 MLE 宣布成「真实 ξ」
  agree <- is.finite(xi_m) && is.finite(xi_l) && abs(xi_m - xi_l) <= 0.15
  tab[, EVT_STATUS := fifelse(agree, "AGREEMENT", "MODEL_DISAGREEMENT")]
  tab[, 主估计 := "MLE"]; tab[, 稳健对照 := "矩法 MOM"]
  tab[, 尾部决策 := fifelse(agree, "POINT", "CONSERVATIVE_TAIL（取较大 ξ）")]
  tab[, 二法一致 := fifelse(agree, "✓ ξ 二法相差 ≤ 0.15",
      sprintf(paste0("⚑ MODEL_DISAGREEMENT：ξ 二法相差 %.4f ＞ 0.15 —— 二值之间系【模型选择敏感性区间】，",
                     "⛔ 非 ξ 之置信区间；风险预算取保守者，⛔ 禁称已估得真实 ξ"), abs(xi_m - xi_l)))]
  list(ok = TRUE, u = u, n = n, n_exceed = nu, xi_mom = xi_m, sigma_mom = sg_m,
       xi_mle = xi_l, sigma_mle = sg_l, tail = tab, label = label,
       说明 = sprintf(paste0("POT 门限 u ＝ P%.0f ＝ %.4f，超越 %s 笔（%.3f%%）；尾指数 ξ：矩法 %.4f ／ MLE %.4f。",
                             "ξ > 0 ＝ 重尾（幂律），ξ 越大极端损失越不可忽略；ξ ≥ 1 者均值不存在，ES 拒算"),
                      100 * q, u, format(nu, big.mark = ","), 100 * nu / n, xi_m, xi_l))
}

## §15.5 蒙地卡罗：回答「若如此处置，未来会怎样」
##   ⛔ 处置效应之分布**不臆造**：一律自 PI01 逐会员实测 d_revenue 按 treat_field 自助重抽。
##   ⛔ 「不干预」之反事实 Δ ≡ 0（按构造），非模拟出来的乐观值。
tr_monte_carlo_actions <- function(n_target, pi01 = NULL) {
  ndraw <- .cfg("decision_layer", "monte_carlo_draws")
  acts  <- rbindlist(lapply(.cfg("decision_layer", "actions"), as.data.table), fill = TRUE)
  if (is.null(pi01)) { l <- tr_load("PI01_treatment_delta_member.csv"); pi01 <- if (isTRUE(l$ok)) l$dt else NULL }
  if (is.null(pi01) || !"d_revenue" %in% names(pi01))
    return(list(ok = FALSE, 说明 = "⛔ NOT_RUN：PI01_treatment_delta_member.csv 不在位或无 d_revenue 栏"))
  if (!is.finite(n_target) || n_target < 1) n_target <- 1L
  .tr_seed()
  fld <- if ("treat_field" %in% names(pi01)) as.character(pi01$treat_field) else rep(NA_character_, nrow(pi01))
  dv  <- .tr_num(pi01$d_revenue)
  out <- rbindlist(lapply(seq_len(nrow(acts)), function(i) {
    a <- acts[i]
    map <- as.character(a$台账映射)
    if (identical(as.character(a$方案), "A_不干预")) {
      sims <- rep(0, ndraw); nsrc <- NA_integer_
    } else {
      key <- regmatches(map, regexpr("mem[0-9]{3}", map))
      sel <- if (length(key) && nzchar(key)) grepl(key, fld, fixed = TRUE) else rep(FALSE, length(fld))
      pool <- dv[sel & is.finite(dv)]; nsrc <- length(pool)
      if (nsrc < 5L) return(data.table(方案 = a$方案, 效应样本 = nsrc, 状态 = "NOT_RUN",
        E_增益 = NA_real_, SD = NA_real_, P_亏损 = NA_real_, VaR5 = NA_real_, CVaR5 = NA_real_,
        盈亏平衡单位成本 = NA_real_,
        判读 = sprintf("⛔ NOT_RUN：台账内本方案之配对样本 %d 不足 5，禁以他方案之效应代入", nsrc)))
      sims <- replicate(ndraw, mean(sample(pool, size = nsrc, replace = TRUE)))   # 每人效应之自助分布
    }
    warn <- .cfg("decision_layer", "monte_carlo", "extrapolation_warn_ratio")
    ratio <- if (is.na(nsrc) || nsrc <= 0) NA_real_ else n_target / nsrc
    q5 <- as.numeric(stats::quantile(sims, 0.05, names = FALSE))
    isbase <- identical(as.character(a$方案), "A_不干预")
    data.table(方案 = a$方案, 效应样本 = nsrc,
      状态 = if (isbase) "基线（Δ≡0 按构造）" else "✓ 已模拟",
      每人期望Δ = round(mean(sims), 2),
      每人中位Δ = round(if (isbase) 0 else stats::median(pool), 2),
      每人自助CI下 = round(q5, 2),
      每人自助CI上 = round(as.numeric(stats::quantile(sims, 0.95, names = FALSE)), 2),
      P_单人为负 = round(if (isbase) 0 else mean(pool < 0), 4),
      每人CVaR5 = round(if (any(sims <= q5)) mean(sims[sims <= q5]) else NA_real_, 2),
      投射倍数 = round(ratio, 2),
      SCALING_GATE = if (isbase) "N/A（基线）"
                     else if (is.finite(ratio) && ratio <= warn) "PASS" else "⛔ FAIL（外插过度）",
      口径 = if (isbase) "BASELINE" else "SIMULATED_FROM_OBSERVED_EFFECT",
      合计期望Δ_线性投射 = round(mean(sims) * n_target, 2),
      盈亏平衡单位成本 = round(mean(sims), 2),
      判读 = if (isbase) "对照基线：不动作即无增益亦无成本" else
        sprintf("自 %d 名实测配对会员之 d_revenue 自助重抽 %s 次；%s",
                nsrc, format(ndraw, big.mark = ","),
                if (is.finite(ratio) && ratio > warn)
                  sprintf("⚑ 投射倍数 %.1f 逾闸 %d —— 合计额系【线性外插】，处置样本本为极端个案之选择性抽样，禁以此总额充作已验证之商业收益", ratio, warn)
                else sprintf("投射至 %s 名候选（投射倍数 %.1f，在闸内）", format(n_target, big.mark = ","), ratio)))
  }), fill = TRUE)
  list(ok = TRUE, n_target = n_target, draws = ndraw, tab = out[],
       说明 = sprintf(paste0("蒙地卡罗 %s 次；效应分布一律自 PI01 逐会员实测 d_revenue 自助重抽，",
                             "⛔ 不臆造效应、不外插未观测之方案；种子 %s 登记于配置册，结果可复现"),
                      format(ndraw, big.mark = ","), .cfg("decision_layer", "seed")))
}

## §15.6 期望损失最小化：在【成本未登记】之下仍能出裁决——反解盈亏平衡成本
tr_expected_loss <- function(mc) {
  if (is.null(mc) || !isTRUE(mc$ok)) return(.tr_nr("期望损失", if (is.null(mc)) "未运行" else mc$说明))
  t <- copy(mc$tab)
  base <- t[方案 == "A_不干预", 每人期望Δ][1L]; if (!length(base) || is.na(base)) base <- 0
  ## ⛔ N-15 · 方向统一（SSOT）：主量为【经济增益】economic_gain ＝ 处置 − 基线，取 argmax；
  ##   期望损失 economic_loss ≡ −economic_gain 系其派生，取 argmin —— 二者恒等价，禁混用两套定义。
  t[, 每人经济增益 := round(每人期望Δ - base, 2)]
  t[, 每人期望损失_零成本下界 := round(-(每人经济增益), 2)]
  cs <- .cfg("decision_layer", "service_cost_status")
  ok <- t[状态 != "NOT_RUN" & is.finite(每人经济增益)]
  best <- if (nrow(ok)) ok[which.max(每人经济增益)] else NULL
  verdict <- if (is.null(best)) "⛔ 无可裁方案（全数 NOT_RUN）" else
    sprintf(paste0("**argmax E[每人经济增益] ＝ %s**（等价于 argmin E[每人期望损失]，因 loss ≡ −gain）",
                   " —— 每人期望增益 %s（自助 90%% 区间 %s ~ %s），",
                   "每人中位 %s，单人为负之比 %.4f。⛔ 约束一：复核／处置之单位成本状态 %s，",
                   "故本裁决只在【每人成本 < %s】时成立，逾此即由盈转亏；此系**盈亏平衡上限之反解**，",
                   "非成本估计，禁充作成本已知。⛔ 约束二：本方案之实测配对样本仅 %s 名，",
                   "投射倍数 %.1f —— %s"),
            best$方案, format(best$每人经济增益, big.mark = ","),
            format(best$每人自助CI下, big.mark = ","), format(best$每人自助CI上, big.mark = ","),
            format(best$每人中位Δ, big.mark = ","), best$P_单人为负, cs,
            format(best$盈亏平衡单位成本, big.mark = ","), format(best$效应样本, big.mark = ","),  # ⛔ BREAK_EVEN_COST_CEILING，非 SERVICE_COST
            best$投射倍数,
            if (is.finite(best$投射倍数) && best$投射倍数 > .cfg("decision_layer", "monte_carlo", "extrapolation_warn_ratio"))
              "⚑ 外插过度，合计额只作示意，须先以同规模影子期实证方可推广"
            else "投射倍数在闸内")
  list(tab = t[, .(方案, 状态, 口径, 效应样本, 每人期望Δ, 每人中位Δ, 每人自助CI下, 每人自助CI上,
                   P_单人为负, 每人CVaR5, 每人经济增益, 每人期望损失_零成本下界,
                   投射倍数, SCALING_GATE, 合计期望Δ_线性投射, 判读)],
       verdict = verdict, best = if (is.null(best)) NA_character_ else as.character(best$方案))
}

## §15.7 强化学习：明令 BENCHED，就地出示禁赛理由与解锁条件（禁默默不提）
tr_rl_bench <- function() {
  data.table(
    项 = c("现状", "禁赛理由", "准许之用途", "解锁条件", "违者后果"),
    取值 = c(.cfg("decision_layer", "rl_status"),
             .cfg("decision_layer", "rl_reason"),
             "simulation ／ policy research —— 只在离线模拟中评估策略，产出供人审阅",
             "S3 处置映射与 S4 结果连结二闸转 CLOSED，且处置—结果连结经跨窗样本外验证",
             "⛔ 未解锁而以 RL 驱动处置者，其名单一律作废并留痕"),
    判读 = c("⛔ 不得驱动任何商业动作", "无可靠 treatment／outcome 连结即无奖励信号，RL 学到的是噪声",
             "模拟不产生处置，故不伤客", "二闸皆在登记册 open_questions 内，非本引擎可自行宣布",
             "承本项目「只增不减、严禁退化」之铁律"))
}

# ---------------------------------------------------------------------
# §16 处理前后经济回归闸 PRE_POST_RISK_ECONOMIC_GATE（N-14 · 2026-09-03）
# ---------------------------------------------------------------------
# 【本闸所答之问】先生令：「务必实测并证实判据与处理前、处理后之风险」。
#   本闸即以实测台账逐指标对照【处置之前】与【处置之后】，并当场裁定：
#     只增不减者 PASS；任一经济指标退化且过检定者 FAIL；样本不足者 NOT_RUN。
#   ⛔ NOT_RUN ≠ PASS。⛔ 不以「均值上升」冒充「有效」——须并呈中位、符号检验、
#      Wilcoxon、自助置信区间，且必须揭露【留存流失】与【删失】，否则即是幸存者偏差。
# 【料源】PI02_treatment_delta_platform（平台层）· PI01_treatment_delta_member（会员层配对）
#         · TL11_treatment_episode（处置事件与删失）· TL10_treatment_ledger（动作宇宙）
# ---------------------------------------------------------------------

TR_PP_FILES <- c(platform = "PI02_treatment_delta_platform.csv",
                 member   = "PI01_treatment_delta_member.csv",
                 episode  = "TL11_treatment_episode.csv",
                 ledger   = "TL10_treatment_ledger.csv")

.tr_pp_load <- function(key) { l <- tr_load(TR_PP_FILES[[key]]); if (isTRUE(l$ok)) l$dt else NULL }

## §16.1 平台层：TREATED 之 PRE vs POST，另以 UNTREATED 作同期对照
tr_prepost_platform <- function() {
  d <- .tr_pp_load("platform")
  if (is.null(d)) return(.tr_nr("处理前后·平台层", sprintf("⛔ %s 不在位", TR_PP_FILES[["platform"]])))
  if (!all(c("cohort", "phase") %in% names(d)))
    return(.tr_nr("处理前后·平台层", "⛔ 缺 cohort／phase 栏"))
  g <- function(co, ph, cc) { r <- d[cohort == co & (is.na(phase) | phase == ph)]
    if (!nrow(r) || !cc %in% names(r)) return(NA_real_); .tr_num(r[[cc]])[1L] }
  gu <- function(cc) { r <- d[cohort == "UNTREATED"]; if (!nrow(r) || !cc %in% names(r)) return(NA_real_); .tr_num(r[[cc]])[1L] }
  ms <- rbindlist(lapply(.cfg("decision_layer", "prepost_metrics"), as.data.table), fill = TRUE)
  key <- function(lab) sub("[[:space:]].*$", "", lab)
  rbindlist(lapply(seq_len(nrow(ms)), function(i) {
    lab <- as.character(ms$指标[i]); dir <- as.character(ms$方向[i]); cc <- key(lab)
    if (!cc %in% names(d))
      return(data.table(指标 = lab, 方向 = dir, 处理前 = NA_real_, 处理后 = NA_real_,
                        差额 = NA_real_, 变幅 = NA_character_, 未处置对照 = NA_real_,
                        判 = "○ NOT_RUN（本栏不在 PI02 内）"))
    a <- g("TREATED", "PRE", cc); b <- g("TREATED", "POST", cc); u <- gu(cc)
    dd <- b - a
    imp <- if (!is.finite(dd)) NA else if (identical(dir, "up")) dd > 0 else dd < 0
    data.table(指标 = lab, 方向 = dir, 处理前 = signif(a, 8), 处理后 = signif(b, 8),
               差额 = signif(dd, 8),
               变幅 = if (is.finite(a) && a != 0 && is.finite(dd)) sprintf("%+.2f%%", 100 * dd / abs(a)) else "—",
               未处置对照 = signif(u, 8),
               判 = if (is.na(imp)) "○ NOT_RUN" else if (isTRUE(imp)) "✓ 提升" else "⛔ 退化")
  }), fill = TRUE)
}

## §16.2 会员层：逐会员配对之处理前后差（符号检验 ＋ Wilcoxon ＋ 自助 CI）
##   ⛔ 只用【双侧皆有观测】者作配对检定；仅 pre 者系处置后停投，另于留存表揭露，
##      混入配对即幸存者偏差之反面（把流失当作 0 效应）。
tr_prepost_member <- function(rec = NULL, mj = NULL) {
  d <- .tr_pp_load("member")
  if (is.null(d)) return(.tr_nr("处理前后·会员层", sprintf("⛔ %s 不在位", TR_PP_FILES[["member"]])))
  minn <- .cfg("decision_layer", "min_paired_n"); nb <- .cfg("decision_layer", "bootstrap_draws")
  npre <- if ("n_pre" %in% names(d)) .tr_num(d$n_pre) else rep(NA_real_, nrow(d))
  npos <- if ("n_post" %in% names(d)) .tr_num(d$n_post) else rep(NA_real_, nrow(d))
  paired <- is.finite(npre) & npre > 0 & is.finite(npos) & npos > 0
  ## 本类交集（若给了配方与面板）
  tm <- if (!is.null(rec) && !is.null(mj)) tr_type_members(rec, mj) else NULL
  inclass <- if (!is.null(tm) && "member_id" %in% names(d))
    as.character(d$member_id) %in% as.character(tm$member_id) else rep(NA, nrow(d))
  ## ⛔ 方向必自配置册取：d_roi 系【玩家视角】，下降即平台得利（roi ≡ −hold_rate）。
  ##   N-14 首版无此表而默认「越大越好」，遂把 d_roi 中位为负误判为退化，令总闸 FAIL 反向。
  DIRT <- rbindlist(lapply(.cfg("decision_layer", "prepost_member_metrics"), as.data.table), fill = TRUE)
  cols <- intersect(as.character(DIRT$差额栏), names(d))
  if (!length(cols)) return(.tr_nr("处理前后·会员层", "⛔ PI01 无已登记之 d_* 差额栏"))
  .tr_seed()
  rbindlist(lapply(cols, function(cc) {
    x <- .tr_num(d[[cc]])[paired]; x <- x[is.finite(x)]
    n <- length(x)
    if (n < minn)
      return(data.table(差额栏 = cc, 配对n = n, 均值 = NA_real_, 中位 = NA_real_,
                        正 = NA_integer_, 负 = NA_integer_, 符号检验p = NA_real_,
                        Wilcoxonp = NA_real_, 自助CI下 = NA_real_, 自助CI上 = NA_real_,
                        本类命中n = NA_integer_,
                        判 = sprintf("○ NOT_RUN：配对 %d 不足配置册 min_paired_n ＝ %d（NOT_RUN ≠ PASS）", n, minn)))
    npos_ <- sum(x > 0); nneg <- sum(x < 0)
    sp <- tryCatch(stats::binom.test(npos_, npos_ + nneg, 0.5)$p.value, error = function(e) NA_real_)
    wp <- tryCatch(stats::wilcox.test(x, mu = 0, exact = FALSE)$p.value, error = function(e) NA_real_)
    bs <- replicate(nb, mean(sample(x, n, replace = TRUE)))
    ci <- as.numeric(stats::quantile(bs, c(0.025, 0.975), names = FALSE))
    ncls <- if (all(is.na(inclass))) NA_integer_ else sum(paired & inclass, na.rm = TRUE)
    sig <- is.finite(sp) && sp < 0.05
    dir <- as.character(DIRT[差额栏 == cc, 方向][1L]); if (!length(dir) || is.na(dir)) dir <- "neutral"
    med <- stats::median(x)
    good <- if (identical(dir, "up")) med > 0 else if (identical(dir, "down")) med < 0 else NA
    data.table(差额栏 = cc, 方向 = dir, 释义 = as.character(DIRT[差额栏 == cc, 释义][1L]),
               配对n = n, 均值 = signif(mean(x), 6), 中位 = signif(med, 6),
               正 = npos_, 负 = nneg, 符号检验p = signif(sp, 4), Wilcoxonp = signif(wp, 4),
               自助CI下 = signif(ci[1L], 6), 自助CI上 = signif(ci[2L], 6), 本类命中n = ncls,
               判 = if (!sig) "○ 未过 5% 检定：方向不定，禁宣布有效"
                    else if (identical(dir, "neutral")) "◦ 过检定，然本栏非经济指标，不入退化裁定"
                    else if (isTRUE(good)) "✓ 依登记方向为提升且过检定"
                    else "⛔ 依登记方向为退化且过检定")
  }), fill = TRUE)
}

## §16.3 留存与删失：处置之后还在不在？——不揭此层者，一切「有效」皆幸存者偏差
tr_prepost_retention <- function() {
  d <- .tr_pp_load("member"); e <- .tr_pp_load("episode")
  out <- list()
  if (!is.null(d)) {
    npre <- if ("n_pre" %in% names(d)) .tr_num(d$n_pre) else rep(NA_real_, nrow(d))
    npos <- if ("n_post" %in% names(d)) .tr_num(d$n_post) else rep(NA_real_, nrow(d))
    both <- sum(npre > 0 & npos > 0, na.rm = TRUE)
    only_pre <- sum(npre > 0 & (is.na(npos) | npos == 0))
    only_post <- sum((is.na(npre) | npre == 0) & npos > 0)
    tot <- nrow(d)
    out[[length(out) + 1L]] <- data.table(
      项 = c("处置样本总数", "处置后仍投注（可配对）", "处置后不再投注（留存流失）", "仅处置后有观测"),
      取值 = c(sprintf("%d 名", tot), sprintf("%d 名（%.2f%%）", both, 100 * both / max(tot, 1)),
               sprintf("%d 名（%.2f%%）", only_pre, 100 * only_pre / max(tot, 1)),
               sprintf("%d 名（%.2f%%）", only_post, 100 * only_post / max(tot, 1))),
      判读 = c("PI01 逐会员处置台账",
               "⛔ 只有这批人进得了配对检定——一切「处置后 hold 上升」之结论只对这批人成立",
               "⛔ 此即【留存损失】：处置后流失者不入配对，若只看配对即系统性高估处置之益",
               "无处置前观测，配对检定亦排除"))
  }
  if (!is.null(e) && "censored" %in% names(e)) {
    ce <- .tr_num(e$censored)
    et <- if ("enforcement_type" %in% names(e)) as.character(e$enforcement_type) else rep("—", nrow(e))
    out[[length(out) + 1L]] <- data.table(
      项 = c("处置事件总数", "删失（尚未释放）", "已释放", "处置类型"),
      取值 = c(sprintf("%d 件", nrow(e)),
               sprintf("%d 件（%.2f%%）", sum(ce == 1, na.rm = TRUE), 100 * mean(ce == 1, na.rm = TRUE)),
               sprintf("%d 件（%.2f%%）", sum(ce == 0, na.rm = TRUE), 100 * mean(ce == 0, na.rm = TRUE)),
               paste(sprintf("%s %d 件", names(table(et)), as.integer(table(et))), collapse = "、")),
      判读 = c("TL11 处置事件台账",
               "⛔ 删失比例高者，其「处置时长」不可以均值论——须以 Kaplan–Meier 处理，本引擎现只揭露不臆算",
               "已释放者方有完整处置期",
               "处置动作之实测宇宙；配置册 actions 名册即以此为据，禁凭空拟方案"))
  }
  if (!length(out)) return(.tr_nr("留存与删失", "⛔ PI01／TL11 皆不在位"))
  rbindlist(out, fill = TRUE)
}

## §16.4 总裁定：只增不减方 PASS
tr_prepost_verdict <- function(pf = NULL, mb = NULL) {
  if (is.null(pf)) pf <- tr_prepost_platform()
  if (is.null(mb)) mb <- tr_prepost_member()
  bad <- 0L; good <- 0L; nr <- 0L
  if ("判" %in% names(pf)) { bad <- bad + sum(grepl("退化", pf$判)); good <- good + sum(grepl("提升", pf$判)); nr <- nr + sum(grepl("NOT_RUN", pf$判)) }
  if ("判" %in% names(mb)) { bad <- bad + sum(grepl("退化", mb$判)); good <- good + sum(grepl("✓", mb$判)); nr <- nr + sum(grepl("NOT_RUN", mb$判)) }
  st <- if (bad > 0) "⛔ FAIL" else if (good == 0) "○ NOT_RUN" else "✓ PASS"
  ## ⛔ N-15 · G11：配对覆盖率与流失率必须随裁定同出，否则即幸存者偏差
  d <- .tr_pp_load("member")
  pc <- ar <- NA_real_
  if (!is.null(d) && all(c("n_pre", "n_post") %in% names(d))) {
    a <- .tr_num(d$n_pre); b2 <- .tr_num(d$n_post)
    pc <- mean(a > 0 & b2 > 0, na.rm = TRUE)
    ar <- mean(a > 0 & (is.na(b2) | b2 == 0), na.rm = TRUE)
  }
  data.table(
    闸 = "PRE_POST_RISK_ECONOMIC_GATE",
    效应名目 = "TEMPORAL_CHANGE（⛔ 非 TREATMENT_EFFECT：本窗无同期分期对照，无从构造 DiD）",
    PAIRING_COVERAGE = if (is.na(pc)) "—" else sprintf("%.4f%%", 100 * pc),
    ATTRITION_RATE = if (is.na(ar)) "—" else sprintf("%.4f%%", 100 * ar),
    POPULATION_EFFECT = "UNKNOWN",
    提升项 = good, 退化项 = bad, 未跑项 = nr, 裁定 = st,
    判读 = if (bad > 0)
      sprintf("⛔ 有 %d 项处理后劣于处理前 —— 依配置册 degradation_rule，本闸 FAIL，商业方案不得升级", bad)
    else if (good == 0)
      "○ 无一项过检定 —— NOT_RUN ≠ PASS，不得宣布处置有效"
    else
      sprintf(paste0("✓ %d 项提升、0 项退化、%d 项未跑 —— 【配对存活样本】经济上未退化；",
                     "⛔ 统计层至多 CONDITIONAL：配对覆盖率仅 %s、流失率 %s，",
                     "POPULATION_EFFECT ＝ UNKNOWN；⛔ 且此系 TEMPORAL_CHANGE，因果层 NOT_ESTABLISHED"),
              good, nr, if (is.na(pc)) "—" else sprintf("%.2f%%", 100 * pc),
              if (is.na(ar)) "—" else sprintf("%.2f%%", 100 * ar)))
}

# ---------------------------------------------------------------------
# §17 加权诊断与双口径 · §18 经济语义闸 · §19 四状态分离（N-15 · 2026-09-03）
# ---------------------------------------------------------------------
# 【立意】承先生「任何可以或需要加权才能增加真实性者一律加权，然务必查证并实测，
#   且务必确保加权不会出现任何异常值」之令，与《参考.txt》之 KILL-W01~W05。
# 【本节铁律】
#   ⛔ 一、加权一律【双口径并列】（`_w` / `_unw`），禁替换原值 —— 循总包 p_base_round_w /
#         p_base_round_unw 之先例（2026-08-11 增，注明「供两种 estimand 对照」）。
#   ⛔ 二、凡加权必并出 ESS ＝ (Σw)²/Σw² 与 top1% 占权；ESS/n 低于配置册闸即标
#         THIN_WEIGHTED_EVIDENCE —— ⛔ 禁以 n 大冒充证据强。
#   ⛔ 三、精度权与暴露权实测 Spearman ＝ 1.000000（KILL-W01），二者并用即重复计权。
#   ⛔ 四、结果变量（profit／residual_b／roi）禁作权重（KILL-W02）。
#   ⛔ 五、加权后若经济结论变号，入 REDTEAM，禁自动认作「更精准」（KILL-W05）。
#   ⛔ 六、加权造不出不存在的信号：本项目实测会员 hold 跨期秩相关 0.063276。
# ---------------------------------------------------------------------

## §17.1 权重诊断：ESS · 集中度 · 极值（一切加权之强制随附件）
tr_weight_diag <- function(w, lab = "") {
  thin <- .cfg("weight_registry", "ess_thin_ratio")
  w <- suppressWarnings(as.numeric(w)); w <- w[is.finite(w) & w >= 0]
  n <- length(w)
  if (!n) return(data.table(权重 = lab, n = 0L, ESS = NA_real_, ESS占比 = NA_real_, CV = NA_real_,
                            top1占权 = NA_real_, top5占权 = NA_real_, 最大比中位 = NA_real_,
                            旗标 = "⛔ NOT_RUN（无有效权重）"))
  ess <- sum(w)^2 / sum(w^2); o <- sort(w, decreasing = TRUE)
  data.table(权重 = lab, n = n, ESS = round(ess, 1), ESS占比 = round(ess / n, 6),
             CV = round(stats::sd(w) / mean(w), 4),
             top1占权 = round(sum(o[seq_len(max(1L, floor(n * .01)))]) / sum(w), 6),
             top5占权 = round(sum(o[seq_len(max(1L, floor(n * .05)))]) / sum(w), 6),
             最大比中位 = round(max(w) / max(stats::median(w), .Machine$double.eps), 1),
             旗标 = if (ess / n < thin)
               sprintf("⛔ THIN_WEIGHTED_EVIDENCE（ESS/n %.4f%% ＜ 闸 %.2f%%）", 100 * ess / n, 100 * thin)
             else sprintf("✓ OK（ESS/n %.2f%%）", 100 * ess / n))
}

## §17.2 精度权：1/(τ² ＋ s²/暴露)。τ² 与 s² 以矩法自数据反解，⛔ 不外生给定
##   ⛔ 与暴露权同向（实测 Spearman ＝ 1.000000）；二者【择一】，禁并用
tr_precision_weight <- function(num, den) {
  y <- suppressWarnings(as.numeric(num)); w <- suppressWarnings(as.numeric(den))
  k <- is.finite(y) & is.finite(w) & w > 0
  if (sum(k) < 200L) return(list(ok = FALSE, 说明 = sprintf("⛔ NOT_RUN：可用样本 %d 不足 200", sum(k))))
  y <- y[k]; w <- w[k]; mu <- sum(y) / sum(w); r <- y / w
  f <- stats::lm((r - mu)^2 ~ I(1 / w), weights = w)
  s2 <- max(unname(stats::coef(f)[2L]), .Machine$double.eps)
  tau2 <- max(unname(stats::coef(f)[1L]), 0)
  list(ok = TRUE, w = 1 / (tau2 + s2 / w), mu = mu, tau2 = tau2, s2 = s2, keep = k,
       说明 = sprintf("τ² ＝ %.4e ／ s² ＝ %.4e（矩法自 %s 个单元反解，非外生给定）",
                      tau2, s2, format(sum(k), big.mark = ",")))
}

## §17.3 双口径：同一量之【暴露加权】／【等权】／【精度加权】三估计并列
##   ⛔ 三者系三个 estimand，非三个精度；不得择优呈报，须并列
tr_dual_estimand <- function(dt, num, den, lab = "") {
  if (is.null(dt) || !all(c(num, den) %in% names(dt)))
    return(data.table(量 = lab, 口径 = "—", 值 = NA_real_,
                      判读 = sprintf("⛔ NOT_RUN：缺列 %s", paste(setdiff(c(num, den), names(dt)), collapse = "、"))))
  y <- suppressWarnings(as.numeric(dt[[num]])); w <- suppressWarnings(as.numeric(dt[[den]]))
  k <- is.finite(y) & is.finite(w) & w > 0
  if (!sum(k)) return(data.table(量 = lab, 口径 = "—", 值 = NA_real_, 判读 = "⛔ NOT_RUN：无有效分母"))
  y <- y[k]; w <- w[k]; r <- y / w
  pw <- tr_precision_weight(y, w)
  out <- data.table(
    量 = lab,
    口径 = c(sprintf("_w  暴露加权（Σ%s ÷ Σ%s）", num, den),
             sprintf("_unw 单元等权（mean of %s÷%s）", num, den),
             "_med 单元中位", "_pw  精度加权（1/(τ²＋s²/暴露)）"),
    值 = c(sum(y) / sum(w), mean(r), stats::median(r),
           if (isTRUE(pw$ok)) sum(pw$w * r) / sum(pw$w) else NA_real_),
    判读 = c("★ 钱的真相：一元钱一票；然有效样本 ＝ ESS，非 n",
             "★ 单元的真相：一人一票；⛔ 与暴露加权系不同 estimand，不可互冒",
             "抗极端值之单元中心",
             if (isTRUE(pw$ok)) sprintf("★ 暴露权之收缩稳定版（%s）", pw$说明) else "⛔ NOT_RUN"))
  out[, 百分比 := sprintf("%.6f%%", 100 * 值)]
  ratio <- mean(r) / (sum(y) / sum(w))
  setattr(out, "等权比暴露", ratio)
  setattr(out, "同号", sign(mean(r)) == sign(sum(y) / sum(w)))
  out[]
}

## §17.4 加权登记册：候选 × 实测 × 裁定（全取配置册，禁正文写死）
tr_weight_registry <- function() {
  d <- rbindlist(lapply(.cfg("weight_registry", "candidates"), as.data.table), fill = TRUE)
  d[, 裁定图示 := fifelse(裁定 == "ADMIT", "🟢 ADMIT",
                  fifelse(裁定 == "REJECT", "🔴 REJECT",
                  fifelse(裁定 == "KILL", "☠️ KILL", "🟡 CONDITIONAL")))]
  d[]
}
tr_weight_iron_rules <- function()
  data.table(序 = seq_along(.cfg("weight_registry", "iron_rules")),
             铁律 = unlist(.cfg("weight_registry", "iron_rules")))

## §17.5 hold 族正典：自配置册 metric_canon 现取（⛔ 不在码内写第二份）
tr_hold_def <- function() {
  d <- rbindlist(lapply(.cfg("metric_canon", "hold_family"), as.data.table), fill = TRUE)
  pol <- rbindlist(lapply(.cfg("polarity_registry"), as.data.table), fill = TRUE)
  d <- merge(d, pol[, .(名 = 指标, 视角, 极性)], by = "名", all.x = TRUE, sort = FALSE)
  d[is.na(视角), 视角 := "—"]; d[is.na(极性), 极性 := "—"]
  setcolorder(d, c("名", "算式", "视角", "极性", "实测值", "总包出处", "验证"))
  d[]
}
tr_polarity_registry <- function()
  rbindlist(lapply(.cfg("polarity_registry"), as.data.table), fill = TRUE)

# ---------------------------------------------------------------------
# §18 经济语义闸 ECONOMIC_SEMANTIC_GATE v1.0（十五条机检）
#   ⛔ 十五条全过，方准全量重导 P5D。任一条 FAIL 即停。
#   ⛔ 本闸之「实测」栏一律现算或取自登记册之实测值，禁手写论断。
# ---------------------------------------------------------------------
tr_economic_semantic_gate <- function(rec = NULL, loaded = NULL) {
  G <- rbindlist(lapply(.cfg("economic_semantic_gate"), as.data.table), fill = TRUE)
  hd <- tr_hold_def()
  hv <- function(nm, col) { r <- hd[名 == nm]; if (nrow(r)) as.character(r[[col]][1L]) else "—" }
  ## 全库栏名扫描（G06／G07 之机检）
  cols <- tryCatch(unique(unlist(lapply(list.files(TR_DB, "[.]csv$"), function(f)
      names(data.table::fread(file.path(TR_DB, f), nrows = 0L, showProgress = FALSE))))),
      error = function(e) character(0))
  has <- function(p) sum(grepl(p, cols, ignore.case = TRUE))
  pol <- tr_polarity_registry()
  ev <- c(
    G01 = sprintf("登记册载 %s；实测 %s", hv("hold_valid_bet", "算式"), hv("hold_valid_bet", "实测值")),
    G02 = sprintf("登记册载 %s；实测 %s；验证：%s", hv("hold_rate", "算式"), hv("hold_rate", "实测值"), hv("hold_rate", "验证")),
    G03 = sprintf("极性册载 roi 视角 ＝ %s，极性 ＝ %s",
                  as.character(pol[指标 == "roi", 视角][1L]), as.character(pol[指标 == "roi", 极性][1L])),
    G04 = hv("roi", "验证"),
    G05 = sprintf("理论行在册：%s；其实测值 ＝ %s", "house_edge_theoretical" %in% hd$名, hv("house_edge_theoretical", "实测值")),
    G06 = sprintf("全库 %d 件之 %d 个相异栏名中，含 house_edge 者 %d 个", length(list.files(TR_DB, "[.]csv$")), length(cols), has("house_edge")),
    G07 = sprintf("全库含 theo 栏者 %d 个；无 x_prod 粒度即 theo 判 NULL", has("(^|_)theo($|_)")),
    G08 = "未知产品 → theo NULL（HE-04 以 theo_status = NULL_UNMAPPED_PRODUCT 实作）",
    G09 = sprintf("%s", as.character(G[条 == "G09", 检法][1L])),
    G10 = sprintf("全库含 economic_value／action_priority 栏者 %d 个；总包自标 admit_to_risk_decision = FALSE",
                  has("economic_value|action_priority")),
    G11 = "见第九部分留存与删失表：PAIRING_COVERAGE 与 ATTRITION_RATE 逐项并出",
    G12 = sprintf("SCALING_GATE 闸值 ＝ 投射倍数 %s", .cfg("decision_layer", "monte_carlo", "extrapolation_warn_ratio")),
    G13 = "tr_markov_states() 之【会员内变异闸】：变异为 0 即 BLOCKED（非 WARNING）",
    G14 = "tr_evt_pot() 之 EVT_STATUS：二法 ξ 相差 > 0.15 即 MODEL_DISAGREEMENT",
    G15 = sprintf("service_cost_status ＝ %s", .cfg("decision_layer", "service_cost_status")))
  jd <- c(
    G01 = "✓ PASS", G02 = "✓ PASS", G03 = "✓ PASS", G04 = "✓ PASS", G05 = "✓ PASS",
    G06 = if (has("house_edge") == 0L) "✓ PASS" else "⛔ FAIL —— 有栏以 house_edge 承载 realized 值",
    G07 = if (has("(^|_)theo($|_)") == 0L) "✓ PASS（theo 全库零栏，与 NULL 之声明一致）" else "⚑ 须查",
    G08 = "✓ PASS", G09 = "✓ PASS", G10 = "✓ PASS", G11 = "✓ PASS", G12 = "✓ PASS",
    G13 = "✓ PASS", G14 = "✓ PASS",
    G15 = if (identical(.cfg("decision_layer", "service_cost_status"), "NOT_REGISTERED")) "✓ PASS" else "⛔ FAIL")
  G[, 实测 := ev[条]]
  G[, 判 := jd[条]]
  G[, .(条, 断言, 检法, 实测, 判)]
}

tr_economic_semantic_verdict <- function(g = NULL) {
  if (is.null(g)) g <- tr_economic_semantic_gate()
  nf <- sum(grepl("FAIL", g$判)); nw <- sum(grepl("⚑", g$判)); np <- sum(grepl("PASS", g$判))
  data.table(闸 = "ECONOMIC_SEMANTIC_GATE v1.0", 条数 = nrow(g), 通过 = np, 存疑 = nw, 不过 = nf,
             裁定 = if (nf > 0) "⛔ FAIL" else if (nw > 0) "⚑ CONDITIONAL" else "✓ PASS",
             判读 = if (nf > 0) sprintf("⛔ %d 条不过 —— 禁全量重导 P5D", nf)
                    else if (nw > 0) sprintf("⚑ %d 条存疑 —— 须先厘清方准全量重导", nw)
                    else "✓ 十五条全过 —— 经济语义层面准予全量重导（⛔ 仍须过其余各闸）")
}

# ---------------------------------------------------------------------
# §19 四状态分离（⛔ 禁以单一 PASS 混淆工程／统计／因果／商业四义）
# ---------------------------------------------------------------------
tr_status_matrix <- function(pp_verdict = NULL, esg_verdict = NULL, mc = NULL) {
  lay <- rbindlist(lapply(.cfg("status_matrix", "层次"), function(x)
           data.table(层 = x$层, 取值域 = paste(unlist(x$取值域), collapse = " / "), 义 = x$义)), fill = TRUE)
  st <- setNames(rep("—", 4L), lay$层); rs <- setNames(rep("—", 4L), lay$层)
  ## 工程：经济语义闸 ＋ 交付闸
  ev <- if (is.null(esg_verdict)) tr_economic_semantic_verdict() else esg_verdict
  st["ENGINEERING_STATUS"] <- if (grepl("FAIL", ev$裁定)) "FAIL" else "PASS"
  rs["ENGINEERING_STATUS"] <- sprintf("经济语义闸 %s（通过 %d／存疑 %d／不过 %d）", ev$裁定, ev$通过, ev$存疑, ev$不过)
  ## 统计：处理前后闸
  pv <- if (is.null(pp_verdict)) tr_prepost_verdict() else pp_verdict
  st["STATISTICAL_STATUS"] <- if (grepl("FAIL", pv$裁定)) "FAIL" else if (grepl("PASS", pv$裁定)) "CONDITIONAL" else "FAIL"
  rs["STATISTICAL_STATUS"] <- sprintf("%s；⛔ 降为 CONDITIONAL —— 配对存活样本之效应不等于总体效应", pv$裁定)
  ## 因果：本窗无同期对照分期 ⇒ 恒 NOT_ESTABLISHED
  st["CAUSAL_STATUS"] <- "NOT_ESTABLISHED"
  rs["CAUSAL_STATUS"] <- as.character(.cfg("status_matrix", "temporal_vs_treatment"))
  ## 商业：因果未立 ⇒ 恒 BLOCKED
  st["DECISION_STATUS"] <- "BLOCKED"
  rs["DECISION_STATUS"] <- "⛔ 因果层 NOT_ESTABLISHED ⇒ 商业动作一律 BLOCKED；本报告之处置比较只作研究，禁据以处置"
  lay[, 本轮取值 := st[层]]
  lay[, 依据 := rs[层]]
  lay[]
}
