setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
suppressPackageStartupMessages({library(data.table); library(yaml)})
source("函数/registry_loader.R"); source("函数/typology_report_engine.R"); tr_apply_config()
REG <- registry_load()
for (tid in c("T-08","T-15","T-13")) {
  rec <- tr_recipe(REG, tid); ld <- tr_load_all(rec)
  mj <- withCallingHandlers(tr_member_join(rec, ld), warning=function(w){cat("  WARN:",conditionMessage(w),"\n");invokeRestart("muffleWarning")})
  cat(sprintf("\n== %s ==  silent_drop = %s\n", tid, if(is.null(mj)) "NULL(无面板)" else attr(mj,"silent_drop")))
  if (!is.null(mj) && nrow(mj$dropped)) print(mj$dropped[, .(判据列, 声明源表, 缺列成因)])
}
