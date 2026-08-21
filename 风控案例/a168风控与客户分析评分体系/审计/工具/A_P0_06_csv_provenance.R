# =====================================================================
# A_P0_06_csv_provenance.R · §A-P0-6 之 L3 层比对器
# ---------------------------------------------------------------------
# 版本 : 1.1.0        日期 : 2026-08-22
# 身份 : 审计工装 ★ 非交付件、非总包条目
# 对应基线 : v10-REDTEAM 审计基线 v1.0.3
# 对应查询稿 : 审计/查询稿/A_P0_审计查询稿_v1.2.0.sql
# ---------------------------------------------------------------------
# 【职责边界 · 只做一件事】
#   读「数据库/」下既有十一件 CSV 之 2026-05-19 记录，
#   与「审计/证据/」下之 canonical 基准比对，出五态裁定。
#
#   ✅ 本器做：读档、比对、判态、留痕
#   ⛔ 本器不做：修改任何 CSV、修改任何 SQL、猜测缺失血统、
#                以 SQL 结构推断 CSV 状态
#
# 【v1.1.0 斧正 · SC-12】
#   v1.0.0 之 p06_fingerprint() 以 readBin() 整档读入再算 MD5，
#   遇 8.2 GB 级交付件当场 "cannot allocate vector"。
#   根因：审计工具不得假设被审对象装得进内存——本项目交付件恰以巨档著称
#   （R03b 预期 1,813 万行）。今改为：MD5 由 digest(file=) 串流计算，
#   换行符只嗅探首 64 KB，字节数取自 file.size() 不读档；
#   读表亦改为 fread(select=) 只取所需两列。全程内存占用与档案大小脱钩。
#
# 【最要紧之一条】
#   SQL PASS ≠ CSV PASS。本器只看 CSV 实测值，不看该件 SQL 有无 rn=1。
#   SQL 侧之 rn 状态由 Gate Matrix v1 另行提供，仅作为报表并列列，
#   **不参与判态**。判态之唯一依据是 observed vs canonical 之比值。
#
# 【五态出口】
#   A CLEAN              SQL 与 CSV 皆无实际污染
#   B SQL_DEFECT_ONLY    SQL 缺闸，但 CSV 实测未受影响 → 修 SQL、不重生 CSV
#   C CSV_CONTAMINATED   CSV 确受污染（SQL 或已正确）→ 须重生 CSV
#   D BOTH               SQL 缺闸且 CSV 已污染 → v12-Q ＋ 重生成之最高优先级
#   E PROVENANCE_UNKNOWN 无法证明 CSV 之生成血统 → ⛔ 禁猜，保持 UNKNOWN
#
# 【用法】
#   setwd("<a168 项目根>")            # 含 数据库/、审计/ 之那一层
#   source("审计/工具/A_P0_06_csv_provenance.R")
#   p06_sizes()                       # 先看档案体量（巨档预警）
#   res <- p06_run()
#   p06_table(res)                    # 污染传播矩阵
#   p06_blockers(res)                 # 仅列 C／D／E
# =====================================================================

P06_DAY        <- "2026-05-19"
P06_DATA_DIR   <- "\u6570\u636e\u5e93"          # 数据库/
P06_EVID_DIR   <- file.path("\u5ba1\u8ba1", "\u8bc1\u636e")   # 审计/证据/
P06_TOL        <- 1e-6                          # 比值判等容差

## ---- 十一件登记册 --------------------------------------------------
##  sql_rn1 : 该件 SQL 是否含 rn=1（取自 Gate Matrix v1 之【事实层】）
##            ⚠ 仅作报表列，**不参与判态**
##  date_col / count_col : 该件 CSV 中之日期列与计数列（用于取 05-19 之观测值）
##            为 NA 者表示该件粒度不含日维——此时判据改用「会员宇宙」或直接判 E
P06_REG <- data.frame(
  key       = c("P0C04","P0C05","P0C09","TL08","TL10","TL11","TL11c",
                "R03b","T02","B01","P12a"),
  file      = c("P0C04_\u540c\u65e5\u6cc4\u6f0f\u68c0\u9a8c.csv",
                "P0C05_\u6807\u8bb0\u65f6\u70b9\u5b9a\u4f4d.csv",
                "P0C09_\u5b89\u6170\u5242\u68c0\u9a8c.csv",
                "TL08_treatment_events.csv",
                "TL10_treatment_ledger.csv",
                "TL11_treatment_episode.csv",
                "TL11c_population_reconcile.csv",
                "R03b_player_dealer_daily.csv",
                "T02_daily_roi.csv",
                "B01_bt_panel.csv",
                "P12a_platform_daily.csv"),
  sql_rn1   = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                TRUE,  TRUE,  TRUE,  TRUE),
  date_col  = c(NA, NA, NA, NA, NA, NA, NA,
                "bet_date", "bet_date", "bet_date", "dt"),
  count_col = c(NA, NA, NA, NA, NA, NA, "n_bets_in_window",
                "n_rounds", "n_rounds", "n_rounds", "n_bets"),
  stringsAsFactors = FALSE
)

## ---- 编码自适应读档（★ 只取所需列，内存与档案大小脱钩） --------------
##   cols = NULL 时只读表头（nrows = 0），用于探列名；
##   cols 给定时以 fread(select=) 只载该几列——巨档亦不撑爆。
p06_read <- function(path, cols = NULL) {
  encs <- c("UTF-8", "unknown")
  for (e in encs) {
    x <- try(suppressWarnings(
      if (is.null(cols))
        data.table::fread(path, nrows = 0L, encoding = e, showProgress = FALSE)
      else
        data.table::fread(path, select = cols, encoding = e, showProgress = FALSE)
    ), silent = TRUE)
    if (!inherits(x, "try-error")) { attr(x, "p06_enc") <- e; return(x) }
  }
  NULL
}

## ---- 探列名（只读表头，零成本） --------------------------------------
p06_cols <- function(path) {
  h <- p06_read(path, cols = NULL)
  if (is.null(h)) NULL else names(h)
}

## ---- 六元组指纹（串流版；★ 不得整档读入内存） ------------------------
p06_fingerprint <- function(path, md5 = TRUE) {
  if (!file.exists(path)) return(NULL)
  sz  <- file.size(path)
  ## 换行符：只嗅探首 64 KB，不读全档
  con  <- file(path, "rb"); on.exit(close(con), add = TRUE)
  head <- readBin(con, "raw", n = min(sz, 65536L))
  eol  <- if (length(head) > 1L &&
              any(head[-length(head)] == as.raw(13) & head[-1L] == as.raw(10)))
            "CRLF" else "LF"
  ## MD5：digest(file=) 串流计算，内存占用与档案大小无关
  m <- if (isTRUE(md5))
         tryCatch(digest::digest(file = path, algo = "md5"),
                  error = function(e) NA_character_)
       else NA_character_
  list(bytes = sz, md5 = m, eol = eol,
       mtime = format(file.mtime(path), "%Y-%m-%dT%H:%M:%S"))
}

## ---- 档案体量预览（跑 p06_run 前宜先看一眼） -------------------------
p06_sizes <- function() {
  z <- data.frame(key = P06_REG$key, file = P06_REG$file,
                  exists = file.exists(file.path(P06_DATA_DIR, P06_REG$file)),
                  stringsAsFactors = FALSE)
  z$MB <- ifelse(z$exists,
                 round(file.size(file.path(P06_DATA_DIR, P06_REG$file)) / 1024^2, 1),
                 NA_real_)
  z <- z[order(-ifelse(is.na(z$MB), -1, z$MB)), ]
  cat("\n\u6863\u6848\u4f53\u91cf\uff08MB\uff09\uff1a\n")
  print(z[, c("key", "exists", "MB")], row.names = FALSE)
  cat("\n\u2139 MD5 \u4e3a\u4e32\u6d41\u8ba1\u7b97\uff0c\u5de8\u6863\u4ea6\u4e0d\u5360\u5185\u5b58\uff0c\u4f46\u8017\u65f6\u8f83\u957f\uff1b",
      "\u5982\u9700\u5148\u5feb\u8dd1\u4e00\u8f6e\uff0c\u4f20 p06_run(md5 = FALSE)\u3002\n")
  invisible(z)
}

## ---- 判态（唯一依据：observed vs canonical） --------------------------
p06_verdict <- function(sql_rn1, ratio) {
  if (is.na(ratio))              return("E_PROVENANCE_UNKNOWN")
  contaminated <- abs(ratio - 2) < 1e-3        # observed ≈ 2 × canonical
  clean        <- abs(ratio - 1) < 1e-3
  if (!contaminated && !clean)   return("E_PROVENANCE_UNKNOWN")  # 既非 1 亦非 2 → 禁猜
  if (clean  &&  sql_rn1)        return("A_CLEAN")
  if (clean  && !sql_rn1)        return("B_SQL_DEFECT_ONLY")
  if (contaminated &&  sql_rn1)  return("C_CSV_CONTAMINATED")    # ⛔ 不得写成 SQL FAIL
  "D_BOTH"
}

p06_run <- function(day = P06_DAY, md5 = TRUE) {
  for (p in c("data.table", "digest"))
    if (!requireNamespace(p, quietly = TRUE))
      stop(sprintf("\u672a\u5b89\u88c5 %s\uff1ainstall.packages(\"%s\")", p, p), call. = FALSE)

  base_f <- file.path(P06_EVID_DIR, "A_P0_06c_platform_daily_baseline.csv")
  if (!file.exists(base_f))
    stop(sprintf(paste0(
      "\u25cb \u5f85\u8868\uff1a\u672a\u627e\u5230 canonical \u57fa\u51c6 %s\n",
      "  \u8bf7\u5148\u8dd1 \u5ba1\u8ba1/\u67e5\u8be2\u7a3f/A_P0_\u5ba1\u8ba1\u67e5\u8be2\u7a3f_v1.2.0.sql \u4e4b \u00a7A-P0-6c\u3002\n",
      "  \u5f53\u524d\u5de5\u4f5c\u76ee\u5f55\uff1a%s"), base_f, getwd()), call. = FALSE)

  base <- p06_read(base_f, cols = c("arm","dt","n_bets","n_members","stake","validbet","ggr","hold"))
  cn   <- base[base$arm == "CANON_rn1" & as.character(base$dt) == day, ]
  rw   <- base[base$arm == "RAW_\u672a\u53bb\u91cd"  & as.character(base$dt) == day, ]
  if (nrow(cn) != 1L || nrow(rw) != 1L)
    stop("canonical \u57fa\u51c6\u4e4b ", day, " \u884c\u6570\u5f02\u5e38\uff08\u5e94\u5404 1 \u884c\uff09\uff0c\u62d2\u7edd\u7ee7\u7eed", call. = FALSE)

  canon_n <- as.numeric(cn$n_bets)             # 该日 canonical 注单数
  raw_n   <- as.numeric(rw$n_bets)             # 该日 raw 注单数
  message(sprintf("canonical %s\uff1an_bets = %s\uff1braw = %s\uff08\u6bd4 %.4f\uff09",
                  day, format(canon_n, big.mark=","), format(raw_n, big.mark=","),
                  raw_n / canon_n))

  out <- lapply(seq_len(nrow(P06_REG)), function(i) {
    r  <- P06_REG[i, ]
    fp <- file.path(P06_DATA_DIR, r$file)
    fg <- p06_fingerprint(fp, md5 = md5)

    ## 档不存在 → E，禁以「大概没跑到那天」代之
    if (is.null(fg))
      return(data.frame(key=r$key, sql_rn1=r$sql_rn1, csv_exists=FALSE,
                        observed=NA_real_, canonical=NA_real_, ratio=NA_real_,
                        verdict="E_PROVENANCE_UNKNOWN",
                        note="CSV \u4e0d\u5b58\u5728", md5=NA_character_,
                        mtime=NA_character_, stringsAsFactors=FALSE))

    ## 该件粒度不含日维（TL 族之会员级、P0C 族之事件级）→ 无从以日读数判态 → E
    if (is.na(r$date_col) || is.na(r$count_col))
      return(data.frame(key=r$key, sql_rn1=r$sql_rn1, csv_exists=TRUE,
                        observed=NA_real_, canonical=NA_real_, ratio=NA_real_,
                        verdict="E_PROVENANCE_UNKNOWN",
                        note="\u7c92\u5ea6\u4e0d\u542b\u65e5\u7ef4\uff1b\u9700\u53e6\u4ee5 \u00a7A-P0-6b/6f \u4e4b\u5b87\u5b99\u4e0e\u66b4\u9732\u57fa\u51c6\u624b\u5de5\u5b9a\u8c33",
                        md5=fg$md5, mtime=fg$mtime, stringsAsFactors=FALSE))

    nms <- p06_cols(fp)
    if (is.null(nms) || !all(c(r$date_col, r$count_col) %in% nms))
      return(data.frame(key=r$key, sql_rn1=r$sql_rn1, csv_exists=TRUE,
                        observed=NA_real_, canonical=NA_real_, ratio=NA_real_,
                        verdict="E_PROVENANCE_UNKNOWN",
                        note="\u8bfb\u6863\u5931\u8d25\u6216\u7f3a\u5217", md5=fg$md5,
                        mtime=fg$mtime, stringsAsFactors=FALSE))
    d <- p06_read(fp, cols = c(r$date_col, r$count_col))
    if (is.null(d))
      return(data.frame(key=r$key, sql_rn1=r$sql_rn1, csv_exists=TRUE,
                        observed=NA_real_, canonical=NA_real_, ratio=NA_real_,
                        verdict="E_PROVENANCE_UNKNOWN",
                        note="\u8bfb\u6863\u5931\u8d25\u6216\u7f3a\u5217", md5=fg$md5,
                        mtime=fg$mtime, stringsAsFactors=FALSE))

    sel <- as.character(d[[r$date_col]]) == day
    if (!any(sel, na.rm = TRUE))
      return(data.frame(key=r$key, sql_rn1=r$sql_rn1, csv_exists=TRUE,
                        observed=NA_real_, canonical=canon_n, ratio=NA_real_,
                        verdict="E_PROVENANCE_UNKNOWN",
                        note=paste0("CSV \u5185\u65e0 ", day, " \u4e4b\u8bb0\u5f55"),
                        md5=fg$md5, mtime=fg$mtime, stringsAsFactors=FALSE))

    obs <- sum(as.numeric(d[[r$count_col]][sel]), na.rm = TRUE)
    rat <- obs / canon_n
    data.frame(key=r$key, sql_rn1=r$sql_rn1, csv_exists=TRUE,
               observed=obs, canonical=canon_n, ratio=rat,
               verdict=p06_verdict(r$sql_rn1, rat),
               note="", md5=fg$md5, mtime=fg$mtime, stringsAsFactors=FALSE)
  })

  res <- do.call(rbind, out)
  attr(res, "day")       <- day
  attr(res, "canon_n")   <- canon_n
  attr(res, "run_at")    <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  res
}

p06_table <- function(res) {
  cat(sprintf("\n\u6c61\u67d3\u4f20\u64ad\u77e9\u9635 \u00b7 %s \u00b7 canonical n_bets = %s\n",
              attr(res, "day"), format(attr(res, "canon_n"), big.mark = ",")))
  cat("\u26a0 sql_rn1 \u4ec5\u4f5c\u62a5\u8868\u5217\uff0c\u4e0d\u53c2\u4e0e\u5224\u6001\uff1b\u5224\u6001\u552f\u4f9d observed / canonical\n\n")
  print(res[, c("key","sql_rn1","observed","ratio","verdict","note")], row.names = FALSE)
  cat("\n\u5404\u6001\u8ba1\u6570\uff1a\n"); print(table(res$verdict))
  invisible(res)
}

p06_blockers <- function(res) {
  b <- res[grepl("^(C|D|E)_", res$verdict), ]
  if (!nrow(b)) { cat("\u65e0 C\uff0fD\uff0fE \u4ef6\u3002\n"); return(invisible(b)) }
  cat("\n\u963b\u65ad\u53f0\u8d26\uff08C \u9700\u91cd\u751f CSV\uff1bD \u6700\u9ad8\u4f18\u5148\uff1bE \u7981\u731c\uff09\uff1a\n")
  print(b[, c("key","sql_rn1","observed","ratio","verdict","note","md5")], row.names = FALSE)
  invisible(b)
}
