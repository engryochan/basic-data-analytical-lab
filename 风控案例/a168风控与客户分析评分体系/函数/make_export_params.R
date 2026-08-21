# =====================================================================
# make_export_params.R · R03b 导出参数半自动填写助手
# ---------------------------------------------------------------------
# 版本 : 1.0.0-restored   日期 : 2026-08-22
# 身份 : 辅助工具（配置件）；★ 非权威文件
# ---------------------------------------------------------------------
# 【复原声明 · 证据等级 INFERRED】
#   本档系 2026-08-22 自 2026-08-19 会话记录逐字取回之【复原件】，
#   非原始交付档之字节副本。会话记录可能对空白／换行作过归一，
#   故本档六元组未必与原件相同。
#   ⛔ 若日后寻回原件，须以原件为准，并比对六元组；
#      两者若异，以原件为权威，本复原件即作废。
#   本档状态承原件：EXECUTION_UNVERIFIED（迄今未曾运行）。
# ---------------------------------------------------------------------
# 【设计边界 · 最要紧的一条】
#   本器**只填能从 SQL 文本客观读出者**，其余一律留白 <<FILL>>。
#
#   ✅ 可自动：source_sql / query_hash / where_predicate / order_by / tables
#      —— 皆为 SQL 文本之客观属性，读取即得，无须推测。
#
#   ⛔ 不自动：page_mode / page_size / export_started_at / export_finished_at
#              / database / schema / total_count_query
#      —— 皆为【导出行为】之属性，不在 SQL 文本内。
#         脚本若代填，只能靠猜；猜出之值写进事实记录即为伪造留痕。
#         此即已确立之纪律：不得以规则或推测冒充事实。
#
#   本器**绝不**把 _audit_rules 之推荐值（如 K4）写入 order_by。
#   order_by 一律取自 SQL 实际之 ORDER BY 子句；抽不到即留白，不代填。
#
# 【用法】
#   1. 把您在 Superset 实际提交的那段 SQL 存为 函数/R03b_source.sql（UTF-8）
#   2. source("函数/make_export_params.R")
#   3. make_export_params()          # 生成 数据库/R03b_export_parameters.json
#   4. 用文本编辑器打开该 json，把剩余 <<FILL>> 逐项据实填写
#   5. source("函数/R03b_cc_verifier.R"); r03b_gate0()   # 自验
# =====================================================================

make_export_params <- function(
    sql_path      = file.path("函数", "R03b_source.sql"),
    template_path = file.path("数据库", "R03b_export_parameters_TEMPLATE.json"),
    out_path      = file.path("数据库", "R03b_export_parameters.json"),
    overwrite     = FALSE) {

  ## ---- 0 文件门 ----
  if (!file.exists(sql_path))
    stop(sprintf(paste0(
      "○ 待表：未找到 %s\n",
      "  请先把【您在 Superset 实际提交的那段 R03b 查询】整段复制，\n",
      "  存为该路径（编码 UTF-8）。\n",
      "  ⛔ 不可用 SQL 总包内的 §R03b 原文代替——除非您实际跑的就是它逐字未改；\n",
      "     若有任何改动（如加了 LIMIT、改了窗口），须存实际所跑者。\n",
      "  当前工作目录：%s"), sql_path, getwd()), call. = FALSE)

  if (!file.exists(template_path))
    stop(sprintf("○ 待表：未找到模板 %s（当前工作目录 %s）",
                 template_path, getwd()), call. = FALSE)

  if (file.exists(out_path) && !overwrite)
    stop(sprintf(paste0(
      "%s 已存在。\n",
      "  为免覆盖既有事实记录，本器默认不覆写。\n",
      "  若确认要重建，请传 overwrite = TRUE；\n",
      "  ⚠ 覆写前建议先另存备份——事实记录一经产生即为证据。"), out_path),
      call. = FALSE)

  for (p in c("jsonlite", "digest"))
    if (!requireNamespace(p, quietly = TRUE))
      stop(sprintf("未安装 %s 包。请先跑：install.packages(\"%s\")", p, p), call. = FALSE)

  ## ---- 1 读 SQL 原文（逐字，不做任何整形）----
  sql_raw <- paste(readLines(sql_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!nzchar(trimws(sql_raw)))
    stop(sprintf("%s 内容为空", sql_path), call. = FALSE)

  ## ---- 2 哈希：以文件内容原样计算 ----
  ##   ⚠ 与校验器同法：digest(source_sql, algo="sha256", serialize=FALSE)
  hash <- digest::digest(sql_raw, algo = "sha256", serialize = FALSE)

  ## ---- 3 客观抽取（抽不到即留白，绝不代猜）----
  .strip <- function(x) {                       # 剥注释，避免注释内文字被误抽
    x <- gsub("/\\*.*?\\*/", " ", x, perl = TRUE)
    paste(vapply(strsplit(x, "\n")[[1]],
                 function(l) sub("--.*$", "", l), character(1)), collapse = "\n")
  }
  code <- .strip(sql_raw)

  ## 3a · ORDER BY —— 取最外层（最后一个）ORDER BY 至分号或文末
  ord <- "<<FILL>>"
  m <- gregexpr("(?is)\\bORDER\\s+BY\\b", code, perl = TRUE)[[1]]
  if (m[1] != -1L) {
    st  <- m[length(m)]                          # 最后一个即最外层
    tail_txt <- substring(code, st)
    tail_txt <- sub("(?s);.*$", "", tail_txt, perl = TRUE)
    ord <- trimws(gsub("\\s+", " ", sub("(?i)^ORDER\\s+BY\\s*", "", tail_txt)))
    ord <- gsub("\\bp\\.", "", ord)              # 去表别名前缀，便于比对
    if (!nzchar(ord)) ord <- "<<FILL>>"
  }

  ## 3b · WHERE 之窗口谓词 —— 只抽 dt 相关，其余条件不臆断
  whr <- "<<FILL>>"
  wm <- regmatches(code, gregexpr(
    "(?i)[\\w.]*\\bdt\\b\\s*>=\\s*'[^']+'\\s*AND\\s*[\\w.]*\\bdt\\b\\s*<\\s*'[^']+'",
    code, perl = TRUE))[[1]]
  if (length(wm)) whr <- trimws(gsub("\\s+", " ", wm[1]))

  ## 3c · 表名 —— 自 FROM / JOIN 抽 schema.table
  tbl <- unique(unlist(regmatches(code, gregexpr(
    "(?i)(?<=\\bFROM\\s|\\bJOIN\\s)[a-zA-Z_][\\w]*\\.[a-zA-Z_][\\w]*",
    code, perl = TRUE))))
  if (!length(tbl)) tbl <- "<<FILL>>"

  ## 3d · schema —— 由表名前缀推得；若多于一个则留白，不擅择其一
  sch <- "<<FILL>>"
  if (!identical(tbl, "<<FILL>>")) {
    s <- unique(sub("\\..*$", "", tbl))
    if (length(s) == 1L) sch <- s
  }

  ## ---- 4 写入模板（只改可自动之位，其余原样保留）----
  tpl <- jsonlite::fromJSON(template_path, simplifyVector = FALSE)
  tpl$source_sql      <- sql_raw
  tpl$query_hash      <- hash
  tpl$where_predicate <- whr
  tpl$order_by        <- ord
  tpl$tables          <- as.list(tbl)
  tpl$schema          <- sch
  tpl$filled_at       <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  tpl$filled_by       <- "<<FILL>>"
  tpl$`_autofill_provenance` <- list(
    generator   = "make_export_params.R v1.0.0",
    sql_file    = sql_path,
    sql_bytes   = as.integer(file.size(sql_path)),
    sql_sha256  = hash,
    autofilled  = c("source_sql", "query_hash", "where_predicate",
                    "order_by", "tables", "schema")[
                      c(TRUE, TRUE, whr != "<<FILL>>", ord != "<<FILL>>",
                        !identical(tbl, "<<FILL>>"), sch != "<<FILL>>")],
    manual_required = "page_mode／page_size／export_started_at／export_finished_at／database／total_count_query／filled_by —— 皆属【导出行为】属性，不在 SQL 文本内，脚本不得代猜",
    note = "order_by 取自 SQL 实际 ORDER BY 子句；本器绝不写入 _audit_rules 之推荐值（K4）"
  )

  jsonlite::write_json(tpl, out_path, auto_unbox = TRUE, pretty = TRUE)

  ## ---- 5 回报：明列已填与待填 ----
  need <- c("source_sql","database","schema","tables","where_predicate","order_by",
            "page_mode","page_size","export_started_at","export_finished_at",
            "total_count_query","query_hash")
  still <- need[vapply(need, function(k)
    any(grepl("<<FILL>>", as.character(unlist(tpl[[k]])), fixed = TRUE)), logical(1))]

  cat(sprintf("已生成：%s\n", out_path))
  cat(sprintf("  SQL 文件 %s（%s 字节）\n  SHA-256 %s\n",
              sql_path, format(file.size(sql_path), big.mark = ","), hash))
  cat(sprintf("  自动填入 %d 项：%s\n", length(need) - length(still),
              paste(setdiff(need, still), collapse = "、")))
  if (length(still)) {
    cat(sprintf("  ⚠ 仍待人工填写 %d 项：%s\n", length(still),
                paste(still, collapse = "、")))
    cat("    ⛔ 这几项属【导出行为】而非 SQL 文本属性，本器不代猜——\n")
    cat("       猜出之值写进事实记录即为伪造留痕。请据实填写。\n")
    cat("    · 若确实无分页：page_mode 填「无分页·单次全量导出」，page_size 填「N/A」\n")
    cat("    · 若时间为估计：照填并于 _notes 注明「时间系估计，非日志读取」\n")
  } else {
    cat("  ✅ 十二字段皆已填。请续跑 r03b_gate0() 自验。\n")
  }
  if (identical(ord, "<<FILL>>"))
    cat("  ⚠ 未能自 SQL 抽出 ORDER BY —— 请确认所存者为实际提交之完整查询。\n")

  invisible(list(path = out_path, hash = hash, order_by = ord,
                 where_predicate = whr, still_missing = still))
}
