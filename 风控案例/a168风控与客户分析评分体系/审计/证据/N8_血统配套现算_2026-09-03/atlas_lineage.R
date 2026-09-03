## ---------------------------------------------------------------------
## §L 本件之血统（N-8b · 2026-09-03）—— 承 N-8 之铁律：版本与件数一律现取，不手写
## ---------------------------------------------------------------------
## 【本节所治之病】1.1.0 之四处硬写，皆与 N-8 所扫除者同类：
##   ① 档头「适配登记册 : 1.5.003」——登记册已至 1.5.004，此串随版漂移且不报错；
##   ② atlas_version 写死 "1.0.0"，而档头自称 1.1.0 —— **自相矛盾，且已随输出落盘**；
##   ③ sql_package 写死「…P5D_*版…（133 件）」——件数若变即成谎；
##   ④ 无登记册六元组 —— 一份判据坐标表拿在手上，无从自证系哪一版登记册所出。
## 【处置】版本自本档档头现取；件数自总包实数；另出登记册与总包之六元组入每一行。
ATLAS_SELF <- file.path("函数", "export_criterion_atlas.R")

## 自本档档头现取版本（单一真相源即上方「# 版本 : x.y.z」一行）
.atlas_self_version <- function(path = ATLAS_SELF) {
  if (!file.exists(path)) return(NA_character_)
  h <- tryCatch(readLines(path, n = 12L, warn = FALSE, encoding = "UTF-8"),
                error = function(e) character(0))
  hit <- regmatches(h, regexpr("版本[[:space:]]*[:：][[:space:]]*v?[0-9]+([.][0-9]+)+", h, perl = TRUE))
  if (!length(hit)) return(NA_character_)
  v <- regmatches(hit[1L], regexpr("[0-9]+([.][0-9]+)+", hit[1L]))
  if (length(v)) v[1L] else NA_character_
}

## 六元组（与引擎 §9 之 tr_sixtuple 同法；本档不 source 引擎，故就地实作，形制刻意一致）
.atlas_sixtuple <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path))
    return(list(bytes = NA_real_, lines = NA_integer_, eol = "—", bom = "—", md5 = "—"))
  raw    <- readBin(path, "raw", file.size(path))
  n_lf   <- sum(raw == as.raw(10L)); n_cr <- sum(raw == as.raw(13L))
  n_crlf <- if (length(raw) > 1L) sum(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L)) else 0L
  list(bytes = length(raw), lines = n_lf,
       eol = if (n_lf > 0L && n_crlf == n_lf && n_cr == n_lf) "CRLF" else if (n_cr == 0L) "LF" else "MIXED",
       bom = if (length(raw) >= 3L && identical(as.integer(raw[1:3]), c(239L, 187L, 191L))) "有" else "无",
       md5 = unname(tools::md5sum(path)))
}

## 总包身份：档名与件数皆自盘上现取，不手写
.atlas_sql_package <- function() {
  cands <- Sys.glob(file.path("函数", "a168_SQL总包_v12_0_0_HF9g-P5D_原版审计版_六层商业版_OPT.sql"))
  if (!length(cands)) return(list(path = NA_character_, name = "—", n_modules = NA_integer_))
  p <- cands[1L]
  n <- tryCatch({
    ln <- readLines(p, warn = FALSE, encoding = "UTF-8")
    sum(grepl("^--[[:space:]]+[0-9]{1,3}[.][[:space:]]+[^[:space:]]+[.]csv", ln))
  }, error = function(e) NA_integer_)
  list(path = p, name = basename(p), n_modules = n)
}
