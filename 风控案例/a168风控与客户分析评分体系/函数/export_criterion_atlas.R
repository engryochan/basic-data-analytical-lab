# =====================================================================
# export_criterion_atlas.R · 判据坐标表 · 只读实测导出器
# ---------------------------------------------------------------------
# 版本 : 1.1.0        日期 : 2026-09-03        适配登记册 : 1.5.003
# 变更 : 1.1.0（N-6 · 承红队评审）① 四级链扩为五级，新增 L1b OUTPUT_EXPOSED —— 只认真实
#        CSV 表头，封住「总包算过即视为有」之漏；② 新增 silent_drop_detected 与 evidence_level
#        二栏；③ 首因 COLUMN_ABSENT_IN_SOURCE 正名 OUTPUT_NOT_EXPOSED。
# 身份 : 执行件（函数/）★ 只读；不写 规范/；不改 registry 一字
# ---------------------------------------------------------------------
# 【本件之问】registry 之 66 条判据，每一条「从哪张表哪一列取数、那张表在不在、
#   那一列在不在、能不能与主表对齐、对齐会不会扇出、够不够格进决策」——
#   此六问此前散在 CSV 之四栏与引擎之投影逻辑内，无一处汇总呈现。本件即该汇总。
#
# 【为何在 R 而不在 SQL 总包】（承 2026-09-03 裁定）
#   ① 其输入是 registry（规范/）与交付件表头（数据表/），非 ODS —— 与 SQL 总包不在同一数据面；
#   ② 66 条中 6 条之 criterion_source 非交付件（5 条「待建」「现算」+ 1 条 ODS 原表），SQL 无从表达「待建」；
#   ③ 其须随 registry 升版重出，而 SQL 总包升版代价远高。
#
# 【四级单向晋级链】前级不过，后级一律 NA（未评估），不得写 FALSE
#   L1 SOURCE_EXISTS → L1b OUTPUT_EXPOSED → L2 SOURCE_ALIGNED → L3 SOURCE_ADMISSIBLE → L4 CRITERION_ELIGIBLE
#   ★ L1b OUTPUT_EXPOSED（1.1.0 新增，承 2026-09-03 红队评审）：
#     「总包曾算过」≠「交付件有此列」。本闸只认 **真实 CSV 表头**（证据阶梯 LEVEL 1），
#     不认 CTE 内部别名（LEVEL 4）、不认注释推断（禁）。本轮实测正由此闸捕获 13 条。
#     证据阶梯：真实表头 L1 ＞ CREATE/SELECT 输出 L2 ＞ audit_rn 排序键 L3 ＞ CTE alias L4 ＞ 注释（禁）
#   ⛔ NA ≠ FALSE（承 NULL ≠ 0 铁律）：FALSE 表「查过了，不合格」；NA 表「前级未过，尚未查」。
#      若一律写 FALSE，四级链即退化为四个布尔，失其诊断力。
#   ⛔ criterion_eligible 程序一律不判 TRUE —— 该判定属 N-5 判据语义裁决之权，非本件之权。
#
# 【六式契约】（写入输出档头，非只留口诀）
#   Source ≠ Valid ； Valid ≠ Admissible ； Admissible ≠ Eligible ；
#   Eligible ≠ Optimal ； Optimal ≠ Authorized ； Authorized ≠ Executed
#   末式之实证：treatment_policy 十三类中六类零记录 —— 授权了，未必执行了。
#
# 【P-01 硬保护】禁读档清单自 registry 之 global_prohibitions 现取（非硬写）；
#   命中者不读、不 file.info、不列行数，一律判 source_status = PROHIBITED_P01。
#
# 【用法】
#   setwd("<项目根>"); source("函数/export_criterion_atlas.R")
#   atlas <- export_criterion_atlas()                    # 浅层：表头 + 行数（流式计数）
#   atlas <- export_criterion_atlas(deep_fanout = TRUE)  # 深层：另算对齐键扇出（须全量读，慢）
# =====================================================================
suppressPackageStartupMessages({ library(data.table) })

ATLAS_OUT_DIR   <- file.path("审计")
ATLAS_DB_DIR    <- file.path("数据表")
ATLAS_FANOUT_MB <- getOption("atlas.fanout_max_mb", 200)   # 深层扇出之单档上限，逾此登记 SKIPPED_TOO_LARGE

## 十枚候选对齐键（启发式；日后应由 registry 显式登记 source_key，届时删本函数）
.atlas_key_candidates <- c("member_id", "uid", "player_id", "mem", "member_login",
                           "dealer_id", "eid", "agent_id", "operator_id",
                           "round_key", "table_id", "shoe_key", "bet_ip", "ip")

## 三态闸：前级 TRUE 方评估本级；否则 NA（未评估）
.gate <- function(prev, ok) if (isTRUE(prev)) isTRUE(ok) else NA

## 流式换行计数（不载入内存；巨档亦可秒级）
.atlas_lines <- function(path, chunk = 64e6) {
  con <- file(path, open = "rb"); on.exit(close(con))
  n <- 0L
  repeat {
    b <- readBin(con, "raw", chunk)
    if (!length(b)) break
    n <- n + sum(b == as.raw(10L))
  }
  n
}

## 只读表头（不载入任何数据行）
.atlas_header <- function(path) {
  h <- tryCatch(names(data.table::fread(path, nrows = 0L, showProgress = FALSE)),
                error = function(e) tryCatch(
                  names(data.table::fread(path, nrows = 0L, encoding = "Latin-1", showProgress = FALSE)),
                  error = function(e2) NULL))
  h
}

## 自 registry 现取 P-01 禁读档清单（不硬写档名）
.atlas_forbidden <- function(REG) {
  y <- REG$meta
  out <- character(0)
  gp <- y$global_prohibitions
  if (!is.null(gp)) {
    items <- if (!is.null(gp$prohibitions)) gp$prohibitions else gp
    for (p in items) {
      tg <- p$target %||% ""
      hits <- regmatches(tg, gregexpr("[^\\s，,；;（）()]+\\.csv", tg))[[1L]]
      if (length(hits)) out <- c(out, hits)
    }
  }
  par <- y$prohibited_action_registry
  if (!is.null(par)) {
    items <- if (!is.null(par$prohibitions)) par$prohibitions else par
    for (p in items) {
      tg <- p$target %||% ""
      hits <- regmatches(tg, gregexpr("[^\\s，,；;（）()]+\\.csv", tg))[[1L]]
      if (length(hits)) out <- c(out, hits)
    }
  }
  unique(out)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

export_criterion_atlas <- function(deep_fanout = FALSE,
                                   out_dir = ATLAS_OUT_DIR,
                                   db_dir  = ATLAS_DB_DIR) {
  if (!exists("registry_load")) source(file.path("函数", "registry_loader.R"))
  REG <- registry_load()
  reg_ver <- as.character(REG$meta$registry$version)
  D <- copy(REG$dict)
  forbidden <- .atlas_forbidden(REG)
  cat(sprintf("P-01 禁读清单（自 registry 现取）：%s\n",
              if (length(forbidden)) paste(forbidden, collapse = " · ") else "（空）"))

  ## ── 表级缓存：每张出现过之表只探一次 ──────────────────────────────
  srcs <- unique(c(D$criterion_source, D$primary_deliverable))
  srcs <- srcs[!is.na(srcs) & nzchar(srcs)]
  cache <- list()
  for (f in srcs) {
    p <- file.path(db_dir, f)
    is_csv <- grepl("\\.csv$", f)
    e <- list(file = f, status = NA_character_, bytes = NA_real_, rows = NA_integer_,
              cols = NA_integer_, header = list(NULL), key = NA_character_)
    if (f %in% forbidden) {
      e$status <- "PROHIBITED_P01"                       # 不读、不 stat
    } else if (!is_csv) {
      e$status <- if (grepl("^待建", f)) "TO_BUILD"
                  else if (grepl("^现算", f)) "COMPUTED_INLINE_NO_ARTIFACT"
                  else "SOURCE_REFERENCE_ONLY_ODS"       # ods_* 原表，非交付件
    } else if (!file.exists(p)) {
      e$status <- "NOT_ON_DISK"
    } else {
      e$bytes  <- file.info(p)$size
      hdr      <- .atlas_header(p)
      e$header <- list(hdr)
      e$cols   <- if (is.null(hdr)) NA_integer_ else length(hdr)
      e$rows   <- tryCatch(max(.atlas_lines(p) - 1L, 0L), error = function(err) NA_integer_)
      e$key    <- if (is.null(hdr)) NA_character_ else {
        k <- .atlas_key_candidates[.atlas_key_candidates %in% hdr]
        if (length(k)) k[1L] else NA_character_
      }
      e$status <- if (is.null(hdr)) "HEADER_UNREADABLE" else "AVAILABLE"
    }
    cache[[f]] <- e
    cat(sprintf("  · %-46s %s\n", substr(f, 1, 46), e$status))
  }

  ## ── 逐条判据现算 ───────────────────────────────────────────────
  get <- function(f, k) if (is.null(cache[[f]])) NA else cache[[f]][[k]]
  A <- data.table(
    type_id            = D$type_id,
    name_zh            = D$name_zh,
    criterion_column   = D$criterion_column,
    criterion_source   = D$criterion_source,
    primary_deliverable= D$primary_deliverable,
    criterion_role     = D$criterion_role,
    threshold_status   = D$threshold_status,
    gate               = D$gate,
    severity           = D$severity,
    entity_type        = D$entity_type,
    window_scope       = D$window_scope,
    evidence_ladder    = D$evidence_ladder,
    economic_path_status = D$economic_path_status,
    admit_to_feature_scoring = D$admit_to_feature_scoring,
    admit_to_risk_decision   = D$admit_to_risk_decision,
    admit_to_reward_decision = D$admit_to_reward_decision
  )
  A[, source_status := vapply(criterion_source, function(f) as.character(get(f, "status")), character(1))]
  A[, source_bytes  := vapply(criterion_source, function(f) as.numeric(get(f, "bytes")),  numeric(1))]
  A[, source_rows   := vapply(criterion_source, function(f) as.numeric(get(f, "rows")),   numeric(1))]
  A[, source_cols   := vapply(criterion_source, function(f) as.numeric(get(f, "cols")),   numeric(1))]
  A[, source_key    := vapply(criterion_source, function(f) as.character(get(f, "key")),  character(1))]
  A[, primary_status := vapply(primary_deliverable, function(f) as.character(get(f, "status")), character(1))]
  A[, primary_key    := vapply(primary_deliverable, function(f) as.character(get(f, "key")),    character(1))]

  ## 列级存在性 —— 表在 ≠ 列在（2026-09-02 之 Column 'is_test' cannot be resolved 即此型）
  A[, source_column_exists := mapply(function(f, col) {
        h <- get(f, "header")
        if (!identical(as.character(get(f, "status")), "AVAILABLE")) return(NA)
        if (is.null(h) || is.null(h[[1L]])) return(NA)
        isTRUE(col %in% h[[1L]])
      }, criterion_source, criterion_column)]

  ## 四级单向晋级链
  A[, L1_source_exists := source_status == "AVAILABLE"]
  A[, L1b_output_exposed := mapply(function(prev, ok) .gate(prev, ok), L1_source_exists, source_column_exists)]
  A[, L2_source_aligned := mapply(function(prev, sk, pk, ss, ps) {
        .gate(prev, !is.na(sk) && !is.na(pk) && identical(sk, pk) &&
                    identical(ss, "AVAILABLE") && identical(ps, "AVAILABLE"))
      }, L1b_output_exposed, source_key, primary_key, source_status, primary_status)]
  ## 自源即主表者视为天然对齐
  A[criterion_source == primary_deliverable & L1b_output_exposed %in% TRUE,
    L2_source_aligned := TRUE]
  A[, L3_source_admissible := mapply(function(prev, ws) .gate(prev, !identical(ws, "FULL_WINDOW")),
                                     L2_source_aligned, window_scope)]
  A[, L4_criterion_eligible := NA]     # ⛔ 程序一律不判 TRUE：属 N-5 之权

  ## 单一首因（gate_reason）——看到 FALSE/NA 即知卡在哪一级
  A[, criterion_gate_reason := fifelse(
      source_status != "AVAILABLE", paste0("L1 ", source_status),
    fifelse(source_column_exists %in% FALSE, "L1b OUTPUT_NOT_EXPOSED",
    fifelse(L2_source_aligned %in% FALSE, "L2 KEY_MISMATCH_OR_PRIMARY_UNAVAILABLE",
    fifelse(L3_source_admissible %in% FALSE, "L3 TEMPORAL_NOT_ADMISSIBLE(FULL_WINDOW)",
            "L4 PENDING_N5_SEMANTIC_RULING"))))]

  ## 扇出（深层，选跑）：以 source_key 计每键最大／P99／均值重复数
  A[, `:=`(fanout_max = NA_real_, fanout_p99 = NA_real_, fanout_mean = NA_real_,
           fanout_rate_gt1 = NA_real_, fanout_status = "NOT_RUN")]
  if (isTRUE(deep_fanout)) {
    todo <- unique(A[source_status == "AVAILABLE" & !is.na(source_key), .(criterion_source, source_key)])
    for (i in seq_len(nrow(todo))) {
      f <- todo$criterion_source[i]; k <- todo$source_key[i]; p <- file.path(db_dir, f)
      mb <- (cache[[f]]$bytes %||% Inf) / 1024^2
      if (is.na(mb) || mb > ATLAS_FANOUT_MB) {
        A[criterion_source == f, fanout_status := sprintf("SKIPPED_TOO_LARGE(%.0fMB)", mb)]; next
      }
      dt <- tryCatch(fread(p, select = k, showProgress = FALSE), error = function(e) NULL)
      if (is.null(dt) || !nrow(dt)) { A[criterion_source == f, fanout_status := "READ_FAILED"]; next }
      cnt <- dt[, .N, by = k][["N"]]
      A[criterion_source == f, `:=`(
        fanout_max      = max(cnt),
        fanout_p99      = as.numeric(stats::quantile(cnt, 0.99, names = FALSE)),
        fanout_mean     = mean(cnt),
        fanout_rate_gt1 = mean(cnt > 1),
        fanout_status   = "MEASURED")]
    }
  }

  ## ── 缺列归类：CTE 内部别名 vs 从未建（2026-09-03 增补）──────────────
  ## 【立意】source_column_exists = FALSE 只说「交付件里没有」，答不了「为何没有」。
  ##   实测发现两种截然不同之成因，处置路径亦全然不同：
  ##     CTE_ALIAS_NOT_EXPORTED —— 总包有 `AS <列>`，然系 CTE 内部中间量，聚合后不出表。
  ##        凭据：该名不见于任何 audit_rn 排序键（总包自定之「输出列集」凭据）。
  ##        ⇒ 登记册误把【总包内部计算名】当【交付件输出列】。须改判据列名或令总包外显该列。
  ##     NEVER_BUILT —— 总包全档零次出现。⇒ 真未建（如 S03 三列，承 F-21 BLOCKED UNTIL DECISION_RULE）。
  sqlp <- Sys.glob(file.path("函数", "a168_SQL总包_v12_0_0_HF9g-P5D_原版审计版_六层商业版_OPT.sql"))
  A[, absence_class := NA_character_]
  if (length(sqlp) == 1L && any(A$source_column_exists %in% FALSE)) {
    raw  <- readLines(sqlp[1L], warn = FALSE, encoding = "UTF-8")
    code <- paste(sub("--.*$", "", raw), collapse = "
")   # 剥行注释后之可执行码
    full <- paste(raw, collapse = "
")                      # 全文（含注释）
    for (col in unique(A[source_column_exists %in% FALSE, criterion_column])) {
      ## 总包是否曾以该名产出（定值搜寻，避正则转义之脆性）
      as_hit  <- grepl(paste0("AS ", col), code, fixed = TRUE) ||
                 grepl(paste0("AS `", col, "`"), code, fixed = TRUE)
      ## 是否见于 audit_rn 排序键（反引号形式）⇒ 系【输出列】而非中间量
      key_hit <- grepl(paste0("`", col, "`"), full, fixed = TRUE)
      A[criterion_column == col & source_column_exists %in% FALSE,
        absence_class := if (key_hit) "OUTPUT_COL_BUT_STALE_EXPORT"
                         else if (as_hit) "CTE_ALIAS_NOT_EXPORTED"
                         else "NEVER_BUILT"]
    }
  }

  ## silent_drop 侦测：本条若入跨表面板，是否会被 intersect() 无声吞掉
  ## （承引擎 1.3.0 之 KILL RULE；此处为静态预判，引擎侧为运行时留痕，二者互证）
  A[, silent_drop_detected := source_column_exists %in% FALSE]
  A[, evidence_level := fifelse(source_status == "AVAILABLE",
        fifelse(source_column_exists %in% TRUE, "L1_REAL_CSV_HEADER",
        fifelse(absence_class %in% "CTE_ALIAS_NOT_EXPORTED", "L4_CTE_ALIAS_ONLY",
        fifelse(absence_class %in% "OUTPUT_COL_BUT_STALE_EXPORT", "L3_OTHER_MODULE_OUTPUT",
        fifelse(absence_class %in% "NEVER_BUILT", "L0_NOT_BUILT", "UNKNOWN")))), "L0_SOURCE_UNAVAILABLE")]

  ## 血统（防维表漂移）
  A[, `:=`(registry_version = reg_ver,
           sql_package      = "a168_SQL总包_v12_0_0_HF9g-P5D_*版_六层商业版_OPT（133 件）",
           atlas_version    = "1.0.0",
           atlas_generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))]
  setorder(A, type_id, criterion_column)

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  fn <- file.path(out_dir, sprintf("判据坐标表_registry_v%s_%s.csv", reg_ver, format(Sys.Date(), "%Y%m%d")))
  fwrite(A, fn, bom = TRUE)
  cat(sprintf("\n判据坐标表已出：%s（%d 行 × %d 栏）\n", fn, nrow(A), ncol(A)))
  cat("\n── criterion_gate_reason 分布 ──\n"); print(A[, .N, by = criterion_gate_reason][order(-N)])
  cat("\n── source_status 分布 ──\n");        print(A[, .N, by = source_status][order(-N)])
  cat("\n── 列级存在性 source_column_exists ──\n"); print(A[, .N, by = source_column_exists])
  cat("\n⛔ criterion_eligible 全为 NA —— 程序不判决策资格，该权属 N-5 判据语义裁决。\n")
  invisible(A)
}
