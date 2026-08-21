# =====================================================================
# paths_a168.R · 五命名空间路径覆盖器
# ---------------------------------------------------------------------
# 版本 : 1.1.0        日期 : 2026-08-22
# 身份 : 配置件 ★ 非交付件、非总包条目
# ---------------------------------------------------------------------
# 【设计要旨 · 零改脚本】
#   四支既有 R 工具之路径写死于「数据库/」。本器**不改它们一字**，
#   改以运行时覆盖其【集中式路径常量】——R 之默认参数系惰性求值，
#   于调用时方自全局环境取值，故 source() 之后重设常量即生效。
#
#   ⛔ 不改脚本之由（承既定版本纪律）：
#     「不要为了整理目录而直接修改 v10 或既有工具。」
#     路径常量指向旧命名空间一事，登记为【工程债务】，待 v12-Q 归化规格处理。
#     在那之前，本器是唯一合规的重定向手段。
#
# 【五命名空间】
#   数据库/ = Delivery（仅 93 件契约 CSV）
#   函数/   = Execution（R／SQL 辅助执行件）
#   规范/   = Specification（术语库、风险类型登记册）
#   配置/   = Configuration（导出参数模板与实档）
#   审计/   = Audit（基线／查询稿／证据／工具／登记／矩阵）
#
# 【用法】
#   setwd("<a168 项目根>")
#   source("配置/paths_a168.R")
#   p_apply()                 # 先 source 四支工具，再跑本行；印出改前改后对照
#   REG <- registry_load()    # 此后一律空参调用，默认已指向新命名空间
#   GL  <- glossary_load()
#   r03b_gate0()
#
# 【v1.1.0 斧正】v1.0.0 漏覆盖 REGISTRY_PATHS$sql_main，致 registry_load()
#   报「未在 函数/ 找到 SQL 总包 —— 证据链降级为不可溯源」。今补：
#   sql_main 改为【自动定位】——于候选位置逐一探测，取首个在位者，
#   并印出实际所取之路径；⛔ 全数不在位时不代猜，留原值并示警。
#
# 【自检】p_verify() 印出三域八槽位之在位情况，缺档即列出，绝不静默
#   A·Registry(yaml/csv) B·Glossary(yaml/csv) C·R03b(template/params/source)
#   D·SQL 总包(sql_main)
# =====================================================================

A168_NS <- list(
  delivery = "\u6570\u636e\u5e93",                       # 数据库/
  exec     = "\u51fd\u6570",                             # 函数/
  spec     = "\u89c4\u8303",                             # 规范/
  config   = "\u914d\u7f6e",                             # 配置/
  audit    = "\u5ba1\u8ba1"                              # 审计/
)

A168_FILES <- list(
  registry_yaml = file.path(A168_NS$spec,   "registry_risk_typology_v1.3.0.yaml"),
  registry_csv  = file.path(A168_NS$spec,   "registry_risk_typology_v1.3.0.csv"),
  glossary_yaml = file.path(A168_NS$spec,   "glossary_a168_v1.0.0.yaml"),
  glossary_csv  = file.path(A168_NS$spec,   "glossary_a168_v1.0.0.csv"),
  r03b_template = file.path(A168_NS$config, "R03b_export_parameters_TEMPLATE.json"),
  r03b_params   = file.path(A168_NS$config, "R03b_export_parameters.json"),
  r03b_source   = file.path(A168_NS$exec,   "R03b_source.sql"),
  sql_main      = NA_character_          # 由 p_resolve_sql() 实测定位，不预设
)

## ---- SQL 总包自动定位（探测而非假定） -------------------------------
A168_SQL_CANDIDATES <- c(
  "a168_\u53d6\u6570\u4e0e\u6838\u9a8c_SQL\u603b\u5305_v10.sql",                       # 项目根
  file.path(A168_NS$exec,   "a168_\u53d6\u6570\u4e0e\u6838\u9a8c_SQL\u603b\u5305_v10.sql"),  # 函数/
  file.path(A168_NS$config, "a168_\u53d6\u6570\u4e0e\u6838\u9a8c_SQL\u603b\u5305_v10.sql")   # 配置/
)

p_resolve_sql <- function(verbose = TRUE) {
  hit <- A168_SQL_CANDIDATES[file.exists(A168_SQL_CANDIDATES)]
  if (verbose) {
    cat("\n\u3010SQL \u603b\u5305\u5b9a\u4f4d\u3011\n")
    for (c0 in A168_SQL_CANDIDATES)
      cat(sprintf("  %s %s\n", if (file.exists(c0)) "\u2713" else "\u2717", c0))
  }
  if (!length(hit)) {
    if (verbose) cat("  \u26a0 \u5019\u9009\u4f4d\u7f6e\u5747\u4e0d\u5728\u4f4d\u2014\u2014\u4e0d\u4ee3\u731c\uff0c\u7559\u539f\u503c\u3002\n")
    return(NA_character_)
  }
  if (length(hit) > 1L && verbose)
    cat("  \u26d4 \u591a\u5904\u5728\u4f4d\uff08\u8eab\u4efd\u649e\u8f66\uff09\uff0c\u53d6\u9996\u4e2a\uff1b\u987b\u62e9\u4e00\u800c\u5f52\u6863\u5176\u4f59\u3002\n")
  hit[1]
}

## ---- 覆盖（惰性求值之故，改常量即改默认参数；不动脚本一字） ----------
p_apply <- function(verbose = TRUE) {
  done <- character(0); skip <- character(0)

  if (exists("REGISTRY_PATHS", envir = globalenv())) {
    rp <- get("REGISTRY_PATHS", envir = globalenv())
    if (verbose) cat("\u3010registry\u3011\u6539\u524d yaml =", rp$yaml, "\n")
    rp$yaml <- A168_FILES$registry_yaml
    if (!is.null(rp$csv)) rp$csv <- A168_FILES$registry_csv
    assign("REGISTRY_PATHS", rp, envir = globalenv())
    if (verbose) cat("\u3010registry\u3011\u6539\u540e yaml =", rp$yaml, "\n")
    done <- c(done, "REGISTRY_PATHS")
  } else skip <- c(skip, "REGISTRY_PATHS\uff08\u672a source registry_loader.R\uff09")

  if (exists("GLOSSARY_PATHS", envir = globalenv())) {
    gp <- get("GLOSSARY_PATHS", envir = globalenv())
    if (verbose) cat("\u3010glossary\u3011\u6539\u524d yaml =", gp$yaml, "\n")
    gp$yaml <- A168_FILES$glossary_yaml
    if (!is.null(gp$csv)) gp$csv <- A168_FILES$glossary_csv
    assign("GLOSSARY_PATHS", gp, envir = globalenv())
    if (verbose) cat("\u3010glossary\u3011\u6539\u540e yaml =", gp$yaml, "\n")
    done <- c(done, "GLOSSARY_PATHS")
  } else skip <- c(skip, "GLOSSARY_PATHS\uff08\u672a source glossary_engine.R\uff09")

  if (exists("R03B_PATHS", envir = globalenv())) {
    bp <- get("R03B_PATHS", envir = globalenv())
    if (verbose) cat("\u3010r03b\u3011\u6539\u524d params =", bp$params, "\n")
    bp$params <- A168_FILES$r03b_params
    assign("R03B_PATHS", bp, envir = globalenv())
    if (verbose) cat("\u3010r03b\u3011\u6539\u540e params =", bp$params, "\n")
    cat("  \u2139 R03B_PATHS \u4e4b\u5176\u4f59\u9879\uff08count\uff0fkeyorder\uff0fmanifest\uff0f\u4e3b\u6863\uff09\u4ecd\u6307\u5411 \u6570\u636e\u5e93\uff0f\u2014\u2014\n",
        "    \u5b83\u4eec\u786e\u5c5e\u4ea4\u4ed8\u4ef6\u4e0e\u6838\u9a8c\u5bfc\u51fa\u6863\uff0c\u672c\u5c5e Delivery\uff0c\u4e0d\u5f97\u642c\u8fc1\u3002\n")
    done <- c(done, "R03B_PATHS")
  } else skip <- c(skip, "R03B_PATHS\uff08\u672a source R03b_cc_verifier.R\uff09")

  ## sql_main：先实测定位，再覆盖（v1.1.0 新增）
  sqlm <- p_resolve_sql(verbose = verbose)
  A168_FILES$sql_main <<- sqlm
  if (!is.na(sqlm) && exists("REGISTRY_PATHS", envir = globalenv())) {
    rp2 <- get("REGISTRY_PATHS", envir = globalenv())
    if (verbose) cat("\u3010registry\u3011\u6539\u524d sql_main =", rp2$sql_main, "\n")
    rp2$sql_main <- sqlm
    assign("REGISTRY_PATHS", rp2, envir = globalenv())
    if (verbose) cat("\u3010registry\u3011\u6539\u540e sql_main =", rp2$sql_main, "\n")
    done <- c(done, "REGISTRY_PATHS$sql_main")
  } else if (is.na(sqlm)) {
    skip <- c(skip, "REGISTRY_PATHS$sql_main\uff08\u603b\u5305\u672a\u5b9a\u4f4d\uff09")
  }

  cat("\n\u5df2\u8986\u76d6\uff1a", if (length(done)) paste(done, collapse = "\u3001") else "\u65e0", "\n")
  if (length(skip)) cat("\u672a\u8986\u76d6\uff1a", paste(skip, collapse = "\u3001"), "\n")
  cat("\n\u26a0 make_export_params.R \u65e0\u96c6\u4e2d\u5f0f\u5e38\u91cf\uff0c\u987b\u663e\u5f0f\u4f20\u53c2\uff1a\n")
  cat('  make_export_params(\n',
      '    sql_path      = "', A168_FILES$r03b_source,   '",\n',
      '    template_path = "', A168_FILES$r03b_template, '",\n',
      '    out_path      = "', A168_FILES$r03b_params,   '")\n', sep = "")
  invisible(list(done = done, skip = skip))
}

## ---- 自检：四组路径在位与否，缺档即列，绝不静默 ----------------------
p_verify <- function() {
  f <- A168_FILES
  if (is.na(f$sql_main)) f$sql_main <- p_resolve_sql(verbose = FALSE)
  f$sql_main <- if (is.na(f$sql_main)) "<\u672a\u5b9a\u4f4d>" else f$sql_main
  dom <- c(registry_yaml="A\u00b7Registry", registry_csv="A\u00b7Registry",
           glossary_yaml="B\u00b7Glossary", glossary_csv="B\u00b7Glossary",
           r03b_template="C\u00b7R03b", r03b_params="C\u00b7R03b", r03b_source="C\u00b7R03b",
           sql_main="D\u00b7SQL\u603b\u5305")
  z <- data.frame(domain = unname(dom[names(f)]), key = names(f),
                  path = unlist(f), exists = file.exists(unlist(f)),
                  stringsAsFactors = FALSE)
  cat("\n\u3010\u4e09\u57df\u516b\u69fd\u4f4d\u00b7\u8def\u5f84\u5728\u4f4d\u81ea\u68c0\u3011\n"); print(z, row.names = FALSE)
  miss <- z$path[!z$exists]
  if (length(miss)) {
    cat("\n\u26a0 \u7f3a\u6863 ", length(miss), " \u4ef6\uff1a\n", sep = "")
    for (m in miss) cat("   \u2717 ", m, "\n", sep = "")
    cat("   \u2192 \u8bf7\u786e\u8ba4\u5df2\u81ea \u5ba1\u8ba1/\u767b\u8bb0/ \u642c\u81f3 \u89c4\u8303/ \u4e0e \u914d\u7f6e/\uff0c\n",
        "     \u4e14 .yaml \u4e4b\u540c\u540d .csv \u642d\u6863\u4e00\u5e76\u642c\u8fc1\u3002\n", sep = "")
  } else cat("\n\u2713 \u56db\u7ec4\u8def\u5f84\u5168\u6570\u5728\u4f4d\u3002\n")
  invisible(z)
}
