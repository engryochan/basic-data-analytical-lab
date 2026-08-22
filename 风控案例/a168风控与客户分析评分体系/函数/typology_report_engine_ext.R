# =====================================================================
# typology_report_engine_ext.R · 十五类商业方案 · 八节体例扩充引擎
# ---------------------------------------------------------------------
# 版本 : 1.1.0        日期 : 2026-08-22        适配登记册 : 1.5.0
# 身份 : 执行件（函数/）★ typology_report_engine.R 之扩充，须先 source 主引擎
# ---------------------------------------------------------------------
# 【职责】补齐范本《尾段投注基础分析的评估_v1_2_47_REDTEAM_去外部模型版.qmd》
#         之八节体例：模型／数据口径／评估／行业实践查证／模型武器库审计与灵活
#         搭配／灵活搭配实测／序列与事件实测／风险会员线索汇总。
# 【血统铁律】
#   ⛔ 不引《玩家风险等级判定设计》《百家乐同桌对打风控分析报告》
#      《风控平台第一版权限设计》三份外来文献之任何数字、阈值或分级。
#      三份仅供人阅读参考，不入本套报告之血统。
#   ✅ 一切取自 规范/registry_risk_typology_v1.5.0 与 数据库/ 交付件，渲染时现算。
# =====================================================================

stopifnot("须先 source 函数/typology_report_engine.R" = exists("tr_load"))

# ---------------------------------------------------------------------
# §9 项目根定位：自 start 逐级上溯，命中同时含「规范/」与「函数/」者为根。
#     解模板于 模板/ 下预览时 root.dir="../.." 越界之败。
# ---------------------------------------------------------------------
tr_find_root <- function(start = getwd(), max_up = 5L) {
  p <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in seq_len(max_up + 1L)) {
    if (dir.exists(file.path(p, "规范")) && dir.exists(file.path(p, "函数"))) return(p)
    up <- dirname(p); if (identical(up, p)) break; p <- up
  }
  stop(sprintf("自 %s 上溯 %d 级未找到项目根（需同时含 规范/ 与 函数/）", start, max_up), call. = FALSE)
}

# ---------------------------------------------------------------------
# §10 只读表头（廉价）——供全维度清单用
# ---------------------------------------------------------------------
tr_header <- function(file) {
  p <- file.path(TR_DB, file)
  if (!file.exists(p)) return(character(0))
  h <- tryCatch(readLines(p, n = 1L, warn = FALSE), error = function(e) NA_character_)
  if (is.na(h[1L])) return(character(0))
  if (!validUTF8(h)) h <- iconv(h, "GBK", "UTF-8")
  h <- sub("^﻿", "", h)
  trimws(strsplit(h, ",", fixed = TRUE)[[1L]])
}

# ---------------------------------------------------------------------
# §11 全维度矩阵：主表维度 / 辅助表 / 辅助表维度（第一部分之扩列）
#     判据列以【】标出；其余为可灵活搭配之未登记维度，一律列出，零省略。
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
    ph <- tr_header(prim)
    sh <- lapply(sup, tr_header); names(sh) <- sup
    data.table(
      序 = tid, 风险类型 = s$name_zh[1L], 门禁 = tr_gate(s$gate[1L]),
      主表 = sub("\\.csv$", "", prim),
      主表维度数 = length(ph),
      主表维度 = mark(ph),
      辅助表 = if (length(sup)) paste(sub("\\.csv$", "", sup), collapse = " · ") else "—",
      辅助表维度数 = sum(vapply(sh, length, 0L)),
      辅助表维度 = if (length(sup)) paste(vapply(sup, function(f)
        sprintf("%s：%s", sub("\\.csv$", "", f), mark(sh[[f]])), ""), collapse = "  ｜  ") else "—",
      已登记判据数 = nrow(s),
      可搭配维度总数 = length(ph) + sum(vapply(sh, length, 0L)))
  }))
}

# ---------------------------------------------------------------------
# §12 数据口径：逐表逐列字典（类型／缺失率／取值示例／是否已登记为判据）
# ---------------------------------------------------------------------
tr_field_dict <- function(rec, loaded) {
  rbindlist(lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]
    if (!t$ok) return(data.table(交付件 = sub("\\.csv$", "", f), 列 = "—", 类型 = "—",
                                 缺失率 = NA_real_, 取值示例 = t$status, 登记 = "—"))
    crit <- rec$dict[criterion_source == f, criterion_column]
    rbindlist(lapply(names(t$dt), function(cn) {
      v <- t$dt[[cn]]
      ## as.character 而非 format()：format() 遇 "2026-08-12 10:03" 之类字符串会试解为
      ## POSIXlt 而抛「字符串的格式不足标准明确」（T-14 action_time 实测中招）。
      ex <- substr(as.character(utils::head(v[!is.na(v)], 3L)), 1L, 40L)
      data.table(交付件 = sub("\\.csv$", "", f), 列 = cn, 类型 = class(v)[1L],
                 ## 先判类型再比空串：POSIXct 列上 v == "" 会把 "" 强制解为时间而抛错
                 缺失率 = round(mean(if (is.character(v)) is.na(v) | v == "" else is.na(v)), 4),
                 取值示例 = paste(ex, collapse = ", "),
                 登记 = fifelse(cn %in% crit, "✔ 已登记判据", "可搭配维度"))
    }))
  }), fill = TRUE)
}

# ---------------------------------------------------------------------
# §13 评估：准入十三维（体例借范本「评估_准入」，内容按本类现算）
# ---------------------------------------------------------------------
tr_eval <- function(rec, loaded, mj) {
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
      sprintf("%d / %d", nfile, length(loaded$tabs)),
      sprintf("%d / %d", cs_ok, nrow(d)),
      if (isTRUE(prim$ok)) tr_f(prim$rows) else prim$status,
      if (is.null(mj)) "—" else tr_f(mj$n_union),
      if (is.null(mj) || is.na(mj$n_inter)) "—" else tr_f(mj$n_inter),
      tr_gate(t$门禁), t$严重度,
      d$phenomenon_status[1L], d$label_validation_status[1L], d$causal_status[1L],
      tr_yn(t$准入评分), tr_yn(d$admit_to_risk_decision[1L]),
      paste(sprintf("%s×%d", names(ts), as.integer(ts)), collapse = " ")),
    风控后果 = c(
      "缺件即本类证据链不完整，结论只及在位部分",
      "缺列即该判据不可实测，登记为待表，不以文字冒充",
      "只代表当前交付件覆盖之会员 universe",
      "跨表灵活搭配之最大可及面",
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
# §14 行业实践查证：只取登记册自证之 standard_basis 与相关全局禁令
#     ⛔ 不引任何外部参考文献
# ---------------------------------------------------------------------
tr_industry <- function(rec, REG) {
  d <- rec$dict
  gp <- REG$meta$global_prohibitions
  tgt <- c(rec$files, d$criterion_column, d$criterion_source)
  rel <- Filter(function(p) any(vapply(tgt, function(x) grepl(x, p$target, fixed = TRUE) ||
                                         grepl(p$target, x, fixed = TRUE), logical(1))) ||
                  grepl("普适|门槛|OFFSET|n>=30", p$target), gp)
  list(
    standard_basis = d$standard_basis[1L],
    external_status = if ("external_standard_status" %in% names(d) && nzchar(d$external_standard_status[1L]))
      d$external_standard_status[1L] else "—",
    applicability = if ("applicability_status" %in% names(d) && nzchar(d$applicability_status[1L]))
      d$applicability_status[1L] else "—",
    prohibitions = if (length(rel)) rbindlist(lapply(rel, function(p) data.table(
      编号 = p$id, 标的 = p$target, 规则 = p$rule, 事由 = p$reason, 严重度 = p$severity))) else NULL)
}

# ---------------------------------------------------------------------
# §15 武器库：依本类判据角色构成派生可用管线（现算，非静态文字）
# ---------------------------------------------------------------------
tr_arsenal <- function(rec) {
  d <- rec$dict
  n <- function(r) sum(d$criterion_role == r)
  njump <- sum(d$direction %in% c("jump", "abnormal"))
  gate <- rec$typ$门禁
  res <- data.table(
    管线 = c("① 关系与网络", "② 方向强度与分位分层", "③ 状态切换与监控带", "④ 恒等式与结算完整性"),
    特征层 = c("JOIN_KEY 列（IP／代理链／对边／时点键）",
               "STAT_DIRECTIONAL 列（high／low 尾部）",
               "STATE／FLAG／BUCKET 列 · jump／abnormal 方向",
               "IDENTITY 列（应恒为零之残差）"),
    模型层 = c("图算法（连通分量＋社群发现）→ 共线诊断",
               "分位分层 → Wilson 收缩 → 秩法 AUC（= Mann–Whitney）",
               "动态基线带 → 破带即启复检",
               "残差检定（应恒为 0）→ 结算九项排查序"),
    决策层 = c("E3/E4 证据打包 → 人工复核", "影子期静默打分，禁据以处置",
               "破带触发复检排程", "先修账，再谈风控结论"),
    处置红线 = c("禁自动封禁；网络证据亦须过门禁", "阈值未反解前禁处置",
                 "破带 ≠ 处罚，唯启复检", "禁以账务异常直接标记玩家"),
    本类判据数 = c(n("JOIN_KEY"), n("STAT_DIRECTIONAL"),
                   n("STATE") + n("FLAG") + n("BUCKET") + njump, n("IDENTITY")))
  res[, 本类可用 := fifelse(本类判据数 > 0, "✔ 可用", "— 本类无此角色判据")]
  res[, 门禁覆盖 := fifelse(gate == "FATAL", "🔴 FATAL：一律只出画像",
                            fifelse(gate == "BLOCK", "🟠 BLOCK：阻断未闭前不得上线",
                                    fifelse(gate == "CONDITIONAL", "🟡 须先满足解锁条件", "🟢 可入影子期")))]
  res[]
}

# ---------------------------------------------------------------------
# §16 灵活搭配实测：方向判据尾部旗标 → 命中数分层 + 两两共现提升度
#     Wilson 下界代点估计（禁裸比例）
# ---------------------------------------------------------------------
tr_wilson_lo <- function(k, n, z = 1.96) {
  ifelse(n <= 0, NA_real_, {
    p <- k / n; den <- 1 + z^2 / n
    ((p + z^2 / (2 * n)) - z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / den })
}

tr_combat <- function(rec, mj) {
  if (is.null(mj)) return(NULL)
  d <- rec$dict
  cols <- setdiff(names(mj$panel), "member_id")
  dircols <- cols[vapply(cols, function(cc) {
    b <- sub("@.*$", "", cc); dd <- d[criterion_column == b, direction][1]
    !is.na(dd) && nzchar(dd) }, logical(1))]
  if (!length(dircols)) return(NULL)
  p <- copy(mj$panel)
  for (cc in dircols) {
    b <- sub("@.*$", "", cc); dd <- d[criterion_column == b, direction][1]
    v <- p[[cc]]
    fl <- if (dd == "high") v >= .q(v, .90)
          else if (dd == "low") v <= .q(v, .10)
          else { z <- abs((v - mean(v, na.rm = TRUE)) / stats::sd(v, na.rm = TRUE)); z >= .q(z, .90) }
    set(p, j = paste0("F_", cc), value = as.integer(fl & !is.na(fl)))
  }
  fcols <- paste0("F_", dircols)
  set(p, j = "命中数", value = rowSums(as.matrix(p[, ..fcols]), na.rm = TRUE))
  ## 退化侦测：若某判据之尾部旗标命中率 > 50%，则 P90 与下界重合（该列近乎常量），
  ## 「尾部」已失去分辨意义，须标出，禁以百分之百之尾部冒充异常群。
  degen <- vapply(fcols, function(fc) mean(p[[fc]] == 1L), 0)
  lay <- p[, .(会员数 = .N), by = .(命中数)][order(-命中数)]
  lay[, 占比 := round(会员数 / sum(会员数), 4)][, 累计占比 := round(cumsum(会员数) / sum(会员数), 4)]
  co <- NULL
  if (length(fcols) >= 2L) {
    cb <- utils::combn(fcols, 2L)
    co <- rbindlist(lapply(seq_len(ncol(cb)), function(i) {
      a <- cb[1, i]; b <- cb[2, i]
      na_ <- sum(p[[a]] == 1L); nb <- sum(p[[b]] == 1L); nab <- sum(p[[a]] == 1L & p[[b]] == 1L)
      ex <- na_ * nb / nrow(p)
      data.table(判据A = sub("^F_", "", a), 判据B = sub("^F_", "", b),
                 A尾部 = na_, B尾部 = nb, 共现 = nab, 期望共现 = round(ex, 1),
                 提升度 = fifelse(ex > 0, round(nab / ex, 2), NA_real_),
                 `共现率|A之Wilson下界` = round(tr_wilson_lo(nab, na_), 4))
    }))
    setorder(co, -提升度)
  }
  deg <- data.table(判据 = sub("^F_", "", names(degen)), 尾部命中率 = round(unname(degen), 4))
  deg[, 判读 := fifelse(尾部命中率 > 0.5, "⚠ 退化：P90 与下界重合，该列近乎常量，尾部无分辨力", "正常")]
  list(panel = p, layer = lay, cooc = co, dircols = dircols, degenerate = deg,
       n_any = sum(p$命中数 >= 1L), n_multi = sum(p$命中数 >= 2L),
       n_all = sum(p$命中数 == length(fcols)), k = length(fcols))
}

# ---------------------------------------------------------------------
# §17 序列与事件实测：本类交付件是否具时间轴；无则登记待表（不冒充）
# ---------------------------------------------------------------------
tr_sequence <- function(rec, loaded) {
  ## 列名匹配只作候选；是否真为时间轴，以【取值形似日期】实证判定——
  ## n_days／tenure_months／active_days 皆含 day/month 字样而实为计数，不得误认。
  is_timeish <- function(v) {
    x <- as.character(v); x <- x[!is.na(x) & nzchar(x)]
    if (!length(x)) return(FALSE)
    x <- utils::head(x, 2000L)
    pat <- "^[0-9]{4}[-/][0-9]{1,2}([-/][0-9]{1,2})?|^[0-9]{6}$|^[0-9]{8}$"
    mean(grepl(pat, x)) >= 0.9
  }
  cand <- "date|dt|ym|month|time|day|_at$"
  rbindlist(lapply(names(loaded$tabs), function(f) {
    t <- loaded$tabs[[f]]
    nm <- sub("[.]csv$", "", f)
    if (!t$ok) return(data.table(交付件 = nm, 时间轴列 = "—", 粒度 = "—", 跨度 = t$status,
                                 可做序列 = "✗ 待表", 疑似计数列 = "—"))
    ca <- grep(cand, names(t$dt), value = TRUE, ignore.case = TRUE)
    tc <- ca[vapply(ca, function(cn) is_timeish(t$dt[[cn]]), logical(1))]
    fake <- setdiff(ca, tc)
    if (!length(tc)) return(data.table(交付件 = nm, 时间轴列 = "无", 粒度 = "—", 跨度 = "—",
      可做序列 = "✗ 待表（本表为截面，无时间轴）",
      疑似计数列 = if (length(fake)) paste(fake, collapse = ", ") else "—"))
    v <- as.character(t$dt[[tc[1L]]]); v <- v[!is.na(v) & nzchar(v)]
    data.table(交付件 = nm, 时间轴列 = paste(tc, collapse = ", "),
               粒度 = fifelse(any(nchar(utils::head(v, 1L)) <= 7L), "月", "日"),
               跨度 = if (length(v)) sprintf("%s → %s", min(v), max(v)) else "—",
               可做序列 = "✔",
               疑似计数列 = if (length(fake)) paste(fake, collapse = ", ") else "—")
  }), fill = TRUE)
}

# ---------------------------------------------------------------------
# §18 线索汇总：模型搭配 × 名单 × 处置（皆为复核候选，非处罚名单）
# ---------------------------------------------------------------------
tr_leads <- function(rec, cb) {
  d <- rec$dict; gate <- rec$typ$门禁
  disp <- if (gate == "FATAL") "仅画像，禁入评分与处置"
          else if (gate == "BLOCK") "冻结，待阻断闭合"
          else if (gate == "CONDITIONAL") "须先满足解锁条件"
          else "人工复核（影子期）"
  L <- list()
  sd_cols <- d[criterion_role == "STAT_DIRECTIONAL", criterion_column]
  L[[1L]] <- data.table(
    线索 = sprintf("L-01 单判据入尾（%s）", rec$typ$编号),
    来源 = if (length(sd_cols)) paste(sd_cols, collapse = " + ") else "本类无方向判据",
    规模 = if (is.null(cb)) "—" else tr_f(cb$n_any),
    定位 = "候选特征", 处置 = disp)
  if (!is.null(cb)) {
    L[[length(L) + 1L]] <- data.table(线索 = "L-02 多判据共现（≥2）", 来源 = "方向判据尾部交集",
      规模 = tr_f(cb$n_multi), 定位 = "跨维度互证", 处置 = disp)
    L[[length(L) + 1L]] <- data.table(线索 = sprintf("L-03 全判据共现（=%d）", cb$k),
      来源 = "全部方向判据同时入尾", 规模 = tr_f(cb$n_all), 定位 = "最高优先复核", 处置 = disp)
  }
  jk <- d[criterion_role == "JOIN_KEY", criterion_column]
  if (length(jk)) L[[length(L) + 1L]] <- data.table(线索 = "L-04 关系链扩展",
    来源 = paste(jk, collapse = " + "), 规模 = "待图算", 定位 = "网络证据", 处置 = "E3/E4 打包后人审")
  ref <- d[criterion_role == "REFERENCE", criterion_column]
  if (length(ref)) L[[length(L) + 1L]] <- data.table(线索 = "L-05 参照量偏离",
    来源 = paste(ref, collapse = " + "), 规模 = "—", 定位 = "口径对照，非判据", 处置 = "只作解释，不出名单")
  rbindlist(L, fill = TRUE)
}
