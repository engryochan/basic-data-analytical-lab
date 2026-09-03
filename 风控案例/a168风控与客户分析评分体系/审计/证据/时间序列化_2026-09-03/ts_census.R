suppressMessages(library(data.table))
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/数据表")
fs <- list.files(pattern="[.]csv$")
out <- list()
for (f in fs) {
  h <- tryCatch(names(fread(f, nrows=0)), error=function(e) NULL)
  if (is.null(h)) next
  dcols <- grep("^(dt|bet_date|date|day|stat_date|month|ym|bet_month|calendar_date|d)$|_date$|^dt_|_month$|^month_|^week", h, value=TRUE, ignore.case=TRUE)
  if (!length(dcols)) next
  sz <- file.size(f)
  idcols <- grep("^(member_id|uid|player_id|agent_id|bet01|bet02|table_id|dealer_id|product_code)$", h, value=TRUE)
  sel <- unique(c(dcols, idcols))
  d <- tryCatch(fread(f, select=sel, showProgress=FALSE), error=function(e) NULL)
  if (is.null(d)) next
  for (dc in dcols) {
    v <- as.character(d[[dc]])
    v <- v[!is.na(v) & v!=""]
    rng <- if (length(v)) paste(range(v), collapse=" .. ") else ""
    out[[length(out)+1]] <- data.table(file=f, bytes=sz, n_rows=nrow(d), date_col=dc, n_distinct_dates=uniqueN(v), date_range=rng,
      id_cols=paste(idcols, collapse="|"),
      n_members=if ("member_id" %in% idcols) uniqueN(d$member_id) else NA_integer_)
  }
}
res <- rbindlist(out)
setorder(res, -n_rows)
fwrite(res, "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/68213601-ea3b-40ee-91c5-9668c14b1274/scratchpad/ts_census.csv")
print(res[, .(file, n_rows, date_col, n_distinct_dates, date_range, n_members)], nrows=200)
