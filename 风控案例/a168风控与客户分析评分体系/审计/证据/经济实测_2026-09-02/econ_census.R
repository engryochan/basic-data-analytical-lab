options(warn = 1, width = 200)
proj <- "C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系"; setwd(proj)
suppressPackageStartupMessages(library(data.table))
SP <- Sys.getenv("SP")
freq <- fread(file.path(SP, "column_frequency.csv"), encoding = "UTF-8")
block <- freq[n_tables >= 120, column]
key_cols <- c("stake","valid_bet","profit","rebate_cost","ngr","net_margin_bet23_formal_canonical","net_margin_chain_nested_canonical",
              "residual_a","residual_b","hold_rate","roi","roi_ex_rebate","economic_value","risk_value","action_priority","decision_status",
              "vip_tier","pr_qualified","evidence_rate","hold_ci_halfwidth_approx","n_bets","n_rounds","active_days","agent_cost_bet23_formal_canonical")
files <- sort(list.files("数据表", pattern = "[.]csv$"))
out <- list(); t_all <- Sys.time()
for (f in files) {
  p <- file.path("数据表", f); mb <- file.size(p)/1e6
  hdr <- names(fread(p, nrows = 0, encoding = "UTF-8"))
  own <- setdiff(hdr, block)
  sel <- intersect(c(key_cols, "member_id","uid","agent_id","dealer_id","ip","bet_ip","dt","bet_date"), hdr)
  t0 <- Sys.time()
  dt <- tryCatch(fread(p, select = sel, encoding = "UTF-8", showProgress = FALSE), error = function(e) { cat("ERR", f, conditionMessage(e), "\n"); NULL })
  if (is.null(dt)) next
  n <- nrow(dt)
  for (c in intersect(key_cols, sel)) {
    v <- dt[[c]]; ne <- sum(!is.na(v) & !(is.character(v) & v == ""))
    nd <- uniqueN(v[!is.na(v)])
    num <- suppressWarnings(as.numeric(v))
    out[[length(out)+1]] <- data.table(table = f, mb = round(mb,1), rows = n, ncol = length(hdr), n_own = length(own), column = c,
      nonempty = ne, fill_rate = round(ne/max(n,1),4), n_distinct = nd,
      status = if (ne == 0) "EMPTY" else if (nd == 1 && n > 1) "CONSTANT_BROADCAST" else if (nd < n * 0.5 && n > 20) "LOW_CARDINALITY" else "PER_ROW",
      vmin = if (all(is.na(num))) NA_real_ else min(num, na.rm = TRUE), vmax = if (all(is.na(num))) NA_real_ else max(num, na.rm = TRUE),
      vmed = if (all(is.na(num))) NA_real_ else median(num, na.rm = TRUE))
  }
  cat(sprintf("%-42s %8.1f MB %9d rows %4d cols own=%3d  %s\n", f, mb, n, length(hdr), length(own), format(round(Sys.time()-t0,1))))
  rm(dt); gc(verbose = FALSE)
}
res <- rbindlist(out)
fwrite(res, file.path(SP, "econ_block_census.csv"), bom = TRUE)
cat("\nTOTAL elapsed:", format(Sys.time()-t_all), "\n")
cat("\n== status census by column ==\n"); print(dcast(res[, .N, by = .(column, status)], column ~ status, value.var = "N", fill = 0))
cat("\n== per-table verdict (economic_value & residual_b & ngr) ==\n")
print(dcast(res[column %in% c("economic_value","residual_b","ngr","hold_rate","stake")], table ~ column, value.var = "status"), nrows = 200)
