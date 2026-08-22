# =====================================================================
# build_typology_reports.R · 十五类风险会员商业方案 · 生成器
# ---------------------------------------------------------------------
# 版本 : 1.3.0        日期 : 2026-08-22        适配登记册 : 1.5.0
# 身份 : 执行件（函数/）
# ---------------------------------------------------------------------
# 【职责】自 模板/风险会员商业方案_模板.qmd 为登记册 v1.5.0 之每一 axis=R 类型
#         各铸一份 qmd 至 分析/风险会员商业方案/，并写渲染脚本。
#         类型集合自登记册现算——登记册增类，本器重跑即多一份；禁手写清单。
# 【同步铁律】十五份只差 {{TYPE_ID}}/{{TITLE}}/{{DATE}} 三个占位；模板改一处，
#         重跑本器即十五份同步。任何单份手改视为漂移，下次重跑即被覆盖。
# 【用法】setwd("<项目根>"); source("函数/build_typology_reports.R"); build_typology_reports()
# =====================================================================
suppressPackageStartupMessages(library(data.table))

build_typology_reports <- function(out_dir = file.path("分析", "风险会员商业方案"),
                                   template = file.path("模板", "风险会员商业方案_模板.qmd"),
                                   version = "v1.3.0", date = format(Sys.Date(), "%Y-%m-%d")) {
  source("函数/registry_loader.R")
  REG <- registry_load()
  tpl <- readChar(template, file.size(template), useBytes = TRUE); Encoding(tpl) <- "UTF-8"
  if (grepl("\r", tpl, fixed = TRUE)) stop("模板含 CR，须为 LF")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  types <- unique(REG$dict[axis == "R", .(type_id, name_zh)])
  setorder(types, type_id)
  safe <- function(x) gsub("[/\\\\:*?\"<>|（）()·—]+", "_", x)
  files <- character(0)
  for (i in seq_len(nrow(types))) {
    tid <- types$type_id[i]; nm <- types$name_zh[i]
    fn <- sprintf("%s_%s_商业方案_%s.qmd", tid, safe(nm), version)
    body <- tpl
    body <- gsub("{{TYPE_ID}}", tid, body, fixed = TRUE)
    body <- gsub("{{TITLE}}", sprintf("%s · %s · 风险会员判据商业方案", tid, nm), body, fixed = TRUE)
    body <- gsub("{{DATE}}", date, body, fixed = TRUE)
    ## 只认真占位符（大写字母+下划线包于双花括号）；模板内用于回退判断之字面量 "{{" 不误伤
    if (grepl("[{][{][A-Z_]+[}][}]", body)) stop("模板残留未替换占位符：",
         paste(unique(regmatches(body, gregexpr("[{][{][A-Z_]+[}][}]", body))[[1L]]), collapse = ", "))
    con <- file(file.path(out_dir, fn), open = "wb"); writeBin(charToRaw(enc2utf8(body)), con); close(con)
    files <- c(files, fn)
    cat(sprintf("  + %s\n", fn))
  }
  ## 渲染脚本（GBK 控制台兼容：只用 ASCII 命令，文件名经 Quarto 以 UTF-8 处理）
  bat <- c("@echo off", "chcp 65001 >nul", "cd /d \"%~dp0\"",
           "set \"QUARTO=\"",
           "where quarto >nul 2>nul && set \"QUARTO=quarto\"",
           "if not defined QUARTO if exist \"C:\\Program Files\\RStudio\\resources\\app\\bin\\quarto\\bin\\quarto.exe\" set \"QUARTO=C:\\Program Files\\RStudio\\resources\\app\\bin\\quarto\\bin\\quarto.exe\"",
           "if not defined QUARTO ( echo [ERR] quarto not found & pause & exit /b 1 )",
           sprintf("\"%%QUARTO%%\" render \"%s\" --to html || echo [FAIL] %s", files, files),
           "echo DONE", "pause")
  con <- file(file.path(out_dir, "渲染_十五类.bat"), open = "wb")
  writeBin(charToRaw(enc2utf8(paste0(paste(bat, collapse = "\r\n"), "\r\n"))), con); close(con)
  ## 清单（供审计对账：生成数 = 登记册 axis=R 类型数）
  idx <- data.table(type_id = types$type_id, name_zh = types$name_zh, file = files,
                    registry_version = REG$meta$registry$version, generated = date)
  fwrite(idx, file.path(out_dir, "_清单.csv"), bom = TRUE)
  cat(sprintf("\n生成 %d 份（登记册 axis=R 类型数 = %d）→ %s\n", length(files), nrow(types), out_dir))
  invisible(idx)
}
