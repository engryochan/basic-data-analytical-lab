## N-3 实跑验证：真实载入器 → v1.5.003；规则册 v0.1.2；校验器 1.2.0（R04b）；负向证明：对 v1.5.002 双档跑 R04b 必 FAIL
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
options(warn = 1); suppressPackageStartupMessages({ library(data.table); library(yaml) })
OUT <- "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/6d7b4b2b-b9df-4cd3-89ff-967edac8a3ee/scratchpad"
acc <- list(); step <- function(name, expr) { r <- tryCatch({ force(expr); "PASS" }, error = function(e) paste0("FAIL: ", conditionMessage(e))); acc[[length(acc)+1]] <<- data.table(step = name, status = r); cat(sprintf("[%s] %s\n", r, name)); invisible(r) }
step("source registry_loader.R (1.5.003)", source("函数/registry_loader.R"))
step("registry_load() → v1.5.003", { REG <<- registry_load() })
cat("  version =", as.character(REG$meta$registry$version), "| parent =", as.character(REG$meta$registry$parent$version), "| dict", nrow(REG$dict), "x", ncol(REG$dict), "\n")
step("registry_counts(REG)", { CNT <<- registry_counts(REG); print(unlist(CNT)) })
step("source rule_registry_loader.R (0.1.3)", source("函数/rule_registry_loader.R"))
step("rules_load(REG) → rule_registry_v0.1.2", { RUL <<- rules_load(REG); cat("  rules =", nrow(RUL), "\n") })
step("source verify_registry_dual.R (1.2.0)", source("函数/verify_registry_dual.R"))
step("verify_registry_dual() 双跑 → v1.5.003", { VR <<- verify_registry_dual() })
tb <- table(VR$status); print(tb); print(VR[rule_id %in% c("R03","R04","R04b","R05") | status != "PASS", .(rule_id, status, observed = substr(observed, 1, 60), expected = substr(expected, 1, 30))])
gate <- report_verify(VR)
fwrite(VR, file.path(OUT, "verify_dual_result_1_5_003.csv"), bom = TRUE)
step("test_r24b() 三态自测", test_r24b())
## 负向证明：以 v1.5.002 双档跑同一校验器 —— R03（自身版本）与 R04b（父版身份）皆须 FAIL
step("负向证明：R04b 对 v1.5.002 判 FAIL", {
  VN <- verify_registry_dual(yaml_path = "规范/registry_risk_typology_v1.5.002.yaml", csv_path = "规范/registry_risk_typology_v1.5.002.csv")
  r <- VN[rule_id == "R04b"]; print(VN[rule_id %in% c("R03", "R04", "R04b"), .(rule_id, status, observed = substr(observed,1,40), expected)])
  if (!identical(r$status, "FAIL")) stop("R04b 对 v1.5.002 未判 FAIL，闸无效")
  if (!identical(r$observed, "1.5.0")) stop("R04b observed 非 1.5.0")
})
## 配置册 / 引擎
CFG <- yaml::read_yaml("配置/report_config_v1.0.0.yaml"); cat("CFG version/parent:", CFG$config$version, CFG$config$parent, "\n")
step("source typology_report_engine.R + ext", { source("函数/typology_report_engine.R"); source("函数/typology_report_engine_ext.R"); tr_apply_config() })
res <- rbindlist(acc); res[, gate_second_stage := gate]
fwrite(res, file.path(OUT, "N3_验收.csv"), bom = TRUE)
cat("\n== N-3 验收 ==\n"); print(res)
