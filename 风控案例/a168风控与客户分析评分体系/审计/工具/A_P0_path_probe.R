# =====================================================================
# A_P0_path_probe.R · 四支 R 工具之路径体检器
# ---------------------------------------------------------------------
# 版本 : 1.0.0        日期 : 2026-08-22
# 身份 : 审计工装 ★ 只读不改
# ---------------------------------------------------------------------
# 【为何需要本器】
#   登记册与术语库已自「数据库/」迁入「审计/登记/」，
#   而四支 R 工具之路径系写死在脚本内。改之前须先【看清】：
#     · 各函数之真实形参名（⛔ 不得猜——猜错即 "参数没有用" 之报错）
#     · 各脚本内写死之「数据库/」出现在哪几行
#     · 是否已有集中式路径常量（如 REGISTRY_PATHS）可一处改毕
#
# 【本器不做】不改任何脚本、不写任何档、不猜任何参数名。
#
# 【用法】
#   setwd("<a168 项目根>")
#   source("审计/工具/A_P0_path_probe.R")
#   p_probe()          # 静态扫描：不 source 被检脚本，纯读文本
#   p_sig()            # 动态签名：须先 source 四支脚本方可用
# =====================================================================

P_SCRIPTS <- c("registry_loader.R", "glossary_engine.R",
               "R03b_cc_verifier.R", "make_export_params.R")
P_DIRS    <- c("\u51fd\u6570", file.path("\u5ba1\u8ba1", "\u5de5\u5177"))   # 函数/ 、审计/工具/

## ---- 一、双处存放侦测（同档双处 = 身份撞车，必须择一） ---------------
p_dup <- function() {
  cat("\n\u3010\u4e00\u3011\u53cc\u5904\u5b58\u653e\u4fa6\u6d4b\n")
  hit <- FALSE
  for (s in P_SCRIPTS) {
    ps <- file.path(P_DIRS, s); ex <- file.exists(ps)
    if (sum(ex) > 1L) {
      hit <- TRUE
      md5 <- vapply(ps[ex], function(p) digest::digest(file = p, algo = "md5"), character(1))
      same <- length(unique(md5)) == 1L
      cat(sprintf("  \u26a0 %s \u5b58\u4e8e %d \u5904\uff1a%s\n", s, sum(ex), paste(ps[ex], collapse = " \u3001 ")))
      cat(sprintf("     MD5 %s\uff1a%s\n",
                  if (same) "\u76f8\u540c" else "\u4e0d\u540c\uff08\u5df2\u6f02\u79fb\uff01\uff09",
                  paste(substr(md5, 1, 12), collapse = " / ")))
    } else if (sum(ex) == 1L) {
      cat(sprintf("  \u2713 %s \u5355\u4e00\u5b58\u653e\uff1a%s\n", s, ps[ex]))
    } else {
      cat(sprintf("  \u2717 %s \u672a\u627e\u5230\n", s))
    }
  }
  if (hit) cat("\n  \u26d4 \u540c\u6863\u53cc\u5904\u5373\u8eab\u4efd\u649e\u8f66\uff1a\u4e24\u4efd\u4eca\u65e5\u76f8\u540c\uff0c\u660e\u65e5\u5fc5\u6f02\u3002\u987b\u62e9\u4e00\u800c\u5220\u5176\u4f59\u3002\n")
  invisible(hit)
}

## ---- 二、写死路径扫描（只读文本，不 source） -------------------------
p_probe <- function() {
  if (!requireNamespace("digest", quietly = TRUE))
    stop("\u672a\u5b89\u88c5 digest\uff1ainstall.packages(\"digest\")", call. = FALSE)
  p_dup()
  cat("\n\u3010\u4e8c\u3011\u5199\u6b7b\u4e4b\u300c\u6570\u636e\u5e93\u300d\u8def\u5f84\u4e0e\u8def\u5f84\u5e38\u91cf\n")
  for (d in P_DIRS) for (s in P_SCRIPTS) {
    p <- file.path(d, s); if (!file.exists(p)) next
    ln <- readLines(p, warn = FALSE, encoding = "UTF-8")
    idx <- grep("\u6570\u636e\u5e93", ln)                       # 「数据库」
    con <- grep("PATHS\\s*<-|_DIR\\s*<-|_PATH\\s*<-", ln)      # 集中式常量
    fun <- grep("^\\s*\\w+\\s*<-\\s*function\\s*\\(", ln)      # 函数定义行
    cat(sprintf("\n  \u2500\u2500 %s\n", p))
    cat(sprintf("     \u300c\u6570\u636e\u5e93\u300d\u51fa\u73b0 %d \u884c%s\n", length(idx),
                if (length(idx)) paste0("\uff1a", paste(head(idx, 12), collapse = ", "),
                                        if (length(idx) > 12) " \u2026" else "") else ""))
    if (length(con))
      cat(sprintf("     \u2713 \u96c6\u4e2d\u5f0f\u8def\u5f84\u5e38\u91cf\uff08\u4e00\u5904\u6539\u6bd5\uff09\uff1a\u884c %s\n",
                  paste(head(con, 6), collapse = ", ")))
    else
      cat("     \u26a0 \u672a\u89c1\u96c6\u4e2d\u5f0f\u8def\u5f84\u5e38\u91cf\uff0c\u8def\u5f84\u6216\u6563\u5728\u5404\u51fd\u6570\u9ed8\u8ba4\u53c2\u6570\n")
    if (length(idx)) {
      cat("     \u53d6\u524d\u516b\u884c\u539f\u6587\uff1a\n")
      for (i in head(idx, 8)) cat(sprintf("       %5d | %s\n", i, trimws(ln[i])))
    }
    if (length(fun)) {
      cat("     \u51fd\u6570\u5b9a\u4e49\u884c\uff08\u5f62\u53c2\u540d\u4ee5\u6b64\u4e3a\u51c6\uff0c\u7981\u731c\uff09\uff1a\n")
      for (i in head(fun, 10)) cat(sprintf("       %5d | %s\n", i, trimws(ln[i])))
    }
  }
  cat("\n\u3010\u4e09\u3011\u4e0b\u4e00\u6b65\n")
  cat("  \u2460 \u82e5\u6709\u96c6\u4e2d\u5f0f\u5e38\u91cf \u2192 \u53ea\u6539\u90a3\u4e00\u5904\uff08\u5b83\u6b63\u662f\u4e3a\u6539\u5e03\u5c40\u800c\u8bbe\uff09\n")
  cat("  \u2461 \u82e5\u65e0 \u2192 \u4ee5\u4e0a\u5217\u51fd\u6570\u5b9a\u4e49\u884c\u4e4b\u771f\u5b9e\u5f62\u53c2\u540d\u4f20\u53c2\n")
  cat("  \u2462 \u628a\u672c\u8f93\u51fa\u56de\u4f20\uff0c\u5373\u53ef\u636e\u5b9e\u51fa\u6539\u6cd5\uff08\u4e0d\u731c\u53c2\u6570\u540d\uff09\n")
  invisible(TRUE)
}

## ---- 三、动态签名（须先 source 被检脚本） ----------------------------
p_sig <- function() {
  cat("\n\u3010\u56db\u3011\u51fd\u6570\u7b7e\u540d\uff08\u9700\u5df2 source\uff09\n")
  fns <- c("registry_load", "glossary_load", "r03b_gate0", "make_export_params")
  for (f in fns) {
    if (exists(f)) {
      cat(sprintf("  %s\n", f)); print(args(get(f)))
    } else {
      cat(sprintf("  %s \u2717 \u672a\u5b9a\u4e49\uff08\u8bf7\u5148 source \u5bf9\u5e94\u811a\u672c\uff09\n", f))
    }
  }
  for (v in c("REGISTRY_PATHS", "GLOSSARY_PATHS", "P06_DATA_DIR")) {
    if (exists(v)) { cat(sprintf("\n  \u5e38\u91cf %s\uff1a\n", v)); print(get(v)) }
  }
  invisible(TRUE)
}
