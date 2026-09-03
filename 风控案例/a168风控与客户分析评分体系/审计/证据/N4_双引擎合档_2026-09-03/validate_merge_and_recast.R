## N-4 验收：合档后函数全数在位 → 重铸十五件 v1.4.2
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
options(warn = 1); suppressPackageStartupMessages(library(data.table))
OUT <- "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/6d7b4b2b-b9df-4cd3-89ff-967edac8a3ee/scratchpad"
expected <- readLines("C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/6d7b4b2b-b9df-4cd3-89ff-967edac8a3ee/scratchpad/fn_all.txt", warn = FALSE)
if (!length(expected)) expected <- readLines("/tmp/fn_all.txt", warn = FALSE)
expected <- trimws(expected); expected <- expected[nzchar(expected)]
cat("期望函数数：", length(expected), "\n")

e <- new.env()
source("函数/registry_loader.R", local = e)
source("函数/glossary_engine.R", local = e)
source("函数/typology_report_engine.R", local = e)
got <- ls(e, all.names = TRUE)
miss <- setdiff(expected, got)
notfn <- expected[expected %in% got][!vapply(expected[expected %in% got], function(n) is.function(get(n, envir = e)), logical(1))]
cat("缺失：", length(miss), if (length(miss)) paste(miss, collapse = ", ") else "（无）", "\n")
cat("非函数：", length(notfn), "\n")
cat("TR_CFG_PATH 在位：", exists("TR_CFG_PATH", envir = e), " tr_cfg 在位：", exists("tr_cfg", envir = e), "\n")
stopifnot(length(miss) == 0, length(notfn) == 0, exists("TR_CFG_PATH", envir = e), exists("tr_cfg", envir = e))

## 一行 source 即全（模板之新消费方式）实证
source("函数/typology_report_engine.R")
tr_apply_config()
cat("tr_apply_config() 后：TR_DB =", TR_DB, " TR_FULL_SCAN =", TR_FULL_SCAN, " TR_WARN_MB =", TR_WARN_MB, "\n")
stopifnot(isTRUE(TR_FULL_SCAN), identical(TR_DB, "数据表"))

## 重铸十五件 v1.4.2
source("函数/build_typology_reports.R")
IDX <- build_typology_reports(
  render_ids = c("T-01", "T-03"),
  blocked_reason = "N-5 判据语义裁决未毕（OUTCOME_BASED=0 / win_rate_all 误标）· 已铸未渲")
print(IDX[, .(type_id, filename, template_version, registry_version, gate, severity, instantiation_state)])
fwrite(IDX, file.path(OUT, "N4_清单.csv"), bom = TRUE)
cat("\n合档后函数总数（引擎档内）：", length(intersect(expected, ls(e, all.names = TRUE))), "／", length(expected), "\n")
