## =====================================================================
## P0-b  空窗泄漏幅度量化 harness（双版本并跑）
## 世博量化® Scibrokes Trading® · a168 风控评分项目
## 编码：UTF-8
## 前置：source("P0a_purged_wf_fix.R")
## =====================================================================
##
## 【为何不是「全量重跑」】
##   红队主张一旦折有缺陷则全部指标推倒重来。此法丢失了一项可白得的证据：
##   同一折规格下「零空窗」与「7 日空窗」并跑，两者之差即为泄漏幅度的
##   实测估计。此差值本身可写入商业方案，作为稳健性凭据。
##   故本 harness 不做重跑，做对照。
##
## 【指标口径 —— 沿用四并列，勿退回单一 MASE】
##   RelMAE : MAE_model / MAE_naive        对内比模用
##   WAPE   : Σ|e| / Σ|y|                  对外首选，量纲可解
##   Bias   : mean(pred - actual)          有符号，防系统性偏移被无符号指标掩盖
##   TopK   : Top-K 命中均值 / 全样本均值    尾部辨识力
##   （MASE 于本标的可算率仅 9.8%，已降为 Tier B 补充，不作主数字）
## =====================================================================


## ---------------------------------------------------------------------
## 一、四并列指标
## ---------------------------------------------------------------------
wf_metrics <- function(actual, pred, naive, k_frac = c(0.001, 0.01, 0.05)) {
  ok <- is.finite(actual) & is.finite(pred)
  a <- actual[ok]; p <- pred[ok]; nv <- naive[ok]
  e  <- p - a
  mae_m <- mean(abs(e)); mae_n <- mean(abs(nv - a))
  res <- list(
    n      = length(a),
    RelMAE = if (mae_n > 0) mae_m / mae_n else NA_real_,
    WAPE   = if (sum(abs(a)) > 0) sum(abs(e)) / sum(abs(a)) else NA_real_,
    Bias   = mean(e),
    MAE    = mae_m)
  base <- mean(a)
  for (kf in k_frac) {
    kk <- max(1L, floor(length(a) * kf))
    top <- order(p, decreasing = TRUE)[seq_len(kk)]
    res[[sprintf("TopK_%.1f%%", kf * 100)]] <-
      if (base != 0) mean(a[top]) / base else NA_real_
  }
  as.data.frame(res, check.names = FALSE)
}


## ---------------------------------------------------------------------
## 二、单版本逐折跑
##   fit_predict : function(train_idx, test_idx, data) -> numeric 预测向量
##                 （长度须等于 length(test_idx)）
##   naive_fn    : function(train_idx, test_idx, data) -> numeric 基线预测
##                 默认取训练窗均值；亦可传「上一期实测」构成 naive-1
## ---------------------------------------------------------------------
run_wf <- function(data, y, splits, fit_predict, naive_fn = NULL, tag = "") {
  if (is.null(naive_fn))
    naive_fn <- function(tr, te, d) rep(mean(y[tr], na.rm = TRUE), length(te))
  rows <- lapply(splits, function(s) {
    p  <- fit_predict(s$train_idx, s$test_idx, data)
    nv <- naive_fn (s$train_idx, s$test_idx, data)
    m  <- wf_metrics(y[s$test_idx], p, nv)
    cbind(version = tag, fold = s$fold,
          test_lo = as.character(as.Date(s$te0)), m,
          stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}


## ---------------------------------------------------------------------
## 三、双版本并跑 + 配对差 + 分块自助置信区间
##   分块自助（block bootstrap）而非 iid 重采样 —— 折在时间上相邻，
##   iid 重采样会低估方差。块长默认 2 折。
## ---------------------------------------------------------------------
block_boot_ci <- function(x, B = 2000L, block = 2L, conf = 0.90, seed = 20260810) {
  x <- x[is.finite(x)]; n <- length(x)
  if (n < 2L) return(c(lo = NA_real_, mid = NA_real_, hi = NA_real_))
  set.seed(seed)
  nb <- ceiling(n / block)
  st <- vapply(seq_len(B), function(b) {
    idx <- unlist(lapply(sample.int(n - block + 1L, nb, replace = TRUE),
                         function(s) s:(s + block - 1L)))
    mean(x[idx[seq_len(n)]])
  }, numeric(1))
  a <- (1 - conf) / 2
  c(lo = unname(stats::quantile(st, a)), mid = mean(x),
    hi = unname(stats::quantile(st, 1 - a)))
}

run_dual_wf <- function(data, y, splits_nogap, splits_gap, fit_predict,
                        naive_fn = NULL,
                        metrics = c("RelMAE", "WAPE", "Bias", "TopK_0.1%")) {
  A <- run_wf(data, y, splits_nogap, fit_predict, naive_fn, tag = "零空窗")
  B <- run_wf(data, y, splits_gap,   fit_predict, naive_fn, tag = "7日空窗")

  ## 折数不同则按测试起点对齐，只比较共有折 —— 否则差值混入折集差异
  key <- intersect(A$test_lo, B$test_lo)
  if (length(key) < 3L)
    warning("共有折不足 3 个，配对差不具解释力；请检查两折集的测试起点铺排。")
  a <- A[match(key, A$test_lo), , drop = FALSE]
  b <- B[match(key, B$test_lo), , drop = FALSE]

  summ <- do.call(rbind, lapply(metrics, function(m) {
    if (!m %in% names(a)) return(NULL)
    d  <- a[[m]] - b[[m]]                 # 正值 = 零空窗「看起来更好」= 泄漏虚高
    ci <- block_boot_ci(d)
    data.frame(指标 = m,
               零空窗 = mean(a[[m]], na.rm = TRUE),
               `7日空窗` = mean(b[[m]], na.rm = TRUE),
               配对差 = unname(ci["mid"]),
               `差_下界90` = unname(ci["lo"]),
               `差_上界90` = unname(ci["hi"]),
               `折数` = length(key),
               check.names = FALSE, stringsAsFactors = FALSE)
  }))

  cat("\n---- 泄漏幅度实测（配对差；区间为分块自助 90%）----\n")
  print(summ, row.names = FALSE)
  cat("\n判读：配对差的 90% 区间若跨 0，则本折规格下未检出可辨识的泄漏，\n",
      "      原有回测数字可留用并注明；若不跨 0 且方向为「零空窗更优」，\n",
      "      则原数字系虚高，须以 7 日空窗版本为准。\n", sep = "")

  invisible(list(per_fold = rbind(A, B), summary = summ, common_folds = key))
}


## =====================================================================
## 用法骨架 —— fit_predict 请直接挂接现有模型（GBDT + 全局 smearing）
## =====================================================================
if (identical(Sys.getenv("P0B_DEMO"), "1")) {
  source("P0a_purged_wf_fix.R")
  ## data 须含 t0/t1（Date）与标的 y
  ## sp0 <- purged_wf_splits2(t0, t1, gap_days = 0L, ...)
  ## sp7 <- purged_wf_splits2(t0, t1, gap_days = 7L, ...)
  ## fp  <- function(tr, te, d) { fit <- your_gbdt(d[tr, ]); predict(fit, d[te, ]) * smear }
  ## res <- run_dual_wf(data, y, sp0, sp7, fp)
  message("请挂接真实模型后运行；本骨架不作示例数据推断。")
}
