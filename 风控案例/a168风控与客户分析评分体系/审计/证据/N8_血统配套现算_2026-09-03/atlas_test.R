setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
suppressPackageStartupMessages(library(data.table))
source("函数/export_criterion_atlas.R")
A <- export_criterion_atlas()
cat("\n== 血统栏（渲染时现取）==\n")
for (k in c("registry_version","registry_yaml_md5","registry_yaml_bytes","registry_yaml_lines",
            "registry_yaml_eol","registry_csv_md5","sql_package","sql_package_modules",
            "sql_package_md5","atlas_version","atlas_generated_at"))
  cat(sprintf("  %-22s %s\n", k, as.character(A[[k]][1])))
cat("\n栏数 ", ncol(A), " 行数 ", nrow(A), "\n")
