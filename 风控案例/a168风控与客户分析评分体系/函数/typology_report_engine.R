# =====================================================================
# typology_report_engine.R · 十五类风险会员商业方案 · 共用分析引擎（含范本体例）
# ---------------------------------------------------------------------
# 版本 : 1.6.0        日期 : 2026-09-03        适配登记册 : 自 registry_load() 现取（本档不写死）
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
      list(类别 = "在役·规范", 角色 = "登记册 YAML（SSOT）",   path = if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$yaml else NA_character_),
      list(类别 = "在役·规范", 角色 = "登记册 CSV（派生字典）", path = if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$csv  else NA_character_),
      list(类别 = "在役·规范", 角色 = "规则册",                path = if (exists("RULES_PATH")) RULES_PATH else NA_character_),
      list(类别 = "在役·规范", 角色 = "风险之眼 schema",       path = if (exists("RISKEYE_PATH")) RISKEYE_PATH else file.path("规范", "risk_eye_schema_v0.1.0.yaml")),
      list(类别 = "在役·规范", 角色 = "术语库 YAML",           path = gp$yaml),
      list(类别 = "在役·规范", 角色 = "术语库 CSV",            path = gp$csv),
      list(类别 = "在役·规范", 角色 = "软配置册",              path = if (exists("TR_CFG_PATH")) TR_CFG_PATH else file.path("配置", "report_config_v1.0.0.yaml")),
      list(类别 = "在役·执行", 角色 = "登记册载入器",          path = file.path("函数", "registry_loader.R")),
      list(类别 = "在役·执行", 角色 = "规则册载入器",          path = file.path("函数", "rule_registry_loader.R")),
      list(类别 = "在役·执行", 角色 = "双档校验器",            path = file.path("函数", "verify_registry_dual.R")),
      list(类别 = "在役·执行", 角色 = "分析引擎（含范本体例）", path = file.path("函数", "typology_report_engine.R")),
      list(类别 = "在役·执行", 角色 = "术语引擎",              path = file.path("函数", "glossary_engine.R")),
      list(类别 = "在役·执行", 角色 = "生成器",                path = file.path("函数", "build_typology_reports.R")),
      list(类别 = "在役·执行", 角色 = "判据坐标表导出器",       path = file.path("函数", "export_criterion_atlas.R")),
      list(类别 = "在役·执行", 角色 = "模板",                  path = file.path("模板", "风险会员商业方案_模板.qmd"))
    ),
    lapply(sqlpk, function(p) list(类别 = "在役·SQL源", 角色 = "SQL 总包", path = p)),
    lapply(probe, function(p) list(类别 = "在役·SQL源", 角色 = "行数实测探针", path = p)),
    lapply(ref,   function(p) list(类别 = "参照",       角色 = "规范件（无代码消费者）", path = p))
  )
  out <- rbindlist(lapply(items, function(it) {
    st <- tr_sixtuple(it$path)
    st[, `:=`(类别 = it$类别, 角色 = it$角色,
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
  setcolorder(out, c("类别", "角色", "件", "内容版本", "档名版本", "身份自洽",
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
    o <- data.table(判据列 = r$criterion_column, 声明源表 = f,
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
