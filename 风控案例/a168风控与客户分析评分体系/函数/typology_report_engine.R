# =====================================================================
# typology_report_engine.R · 十五类风险会员商业方案 · 共用分析引擎
# ---------------------------------------------------------------------
# 版本 : 1.1.0        日期 : 2026-08-22        适配登记册 : 1.5.0
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

suppressPackageStartupMessages({ library(data.table); library(knitr) })

TR_FULL_SCAN <- TRUE          # 全量铁律：恒为 TRUE；置 FALSE 即报错（防抽样回潜）
TR_WARN_MB   <- getOption("tr.warn_mb", 300)      # 巨档【告警】阈，非截行阈
TR_RC_VERIFY <- TRUE          # 全量核验：文件换行数 ↔ 载入行数对账
TR_RC_MAX_MB <- getOption("tr.rc_max_mb", 4096)   # 逾此不作换行数核验，登记 SKIPPED
TR_DB        <- "数据表"   # N-2A 2026-09-03：承 7f713dc 目录改名；_ext.R 以配置册 namespaces.delivery 覆写

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
tr_member_join <- function(rec, loaded) {
  ml <- Filter(function(t) t$ok && "member_id" %in% names(t$dt), loaded$tabs)
  if (!length(ml)) return(NULL)
  d <- rec$dict
  parts <- lapply(names(ml), function(f) {
    cols <- unique(intersect(d[criterion_source == f, criterion_column], names(ml[[f]]$dt)))
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
  list(panel = out, coverage = cov,
       n_union = uniqueN(out$member_id),
       n_inter = if (length(parts) > 1) uniqueN(Reduce(intersect, lapply(parts, `[[`, "member_id"))) else NA_integer_)
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
