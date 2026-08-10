## =====================================================================
## P0-a  Purged Walk-Forward 折生成器（修正版）
## 世博量化® Scibrokes Trading® · a168 风控评分项目
## 编码：UTF-8（Windows 侧若见乱码，请以 UTF-8 打开，勿用记事本另存）
## 依赖：base R only（不引入 data.table / dplyr，以免与主流水线冲突）
## =====================================================================
##
## 【本文件解决什么】
##   原 purged_wf_splits() 的过滤式为：
##       keep <- t1[tr] < te0 & !(t0[tr] > te1 & t0[tr] <= te1 + embargo_days)
##   在严格前向 walk-forward 下，第一式已保证 t1[tr] < te0，又因 t0 <= t1，
##   故 t0[tr] < te0 <= te1，第二式的 t0[tr] > te1 恒为假 —— 整个 embargo
##   子句不可达，为死代码。数值复刻已确证：全部折中该子句剔除样本数 = 0。
##
## 【定性须澄清，勿沿用旧措辞】
##   López de Prado 的 embargo 本为「后置」禁运（禁绝测试窗之后的训练样本），
##   在前向 WF 中本就恒空。故此缺陷不是「embargo 方向写反」，
##   而是「文档承诺的测试前空窗（gap）从未实现」。
##   本文件将二者拆为两个独立参数：gap_days（前置空窗）与 embargo_days（后置禁运）。
##
## =====================================================================

## ---------------------------------------------------------------------
## 一、修正版折生成器
## ---------------------------------------------------------------------
## 参数
##   t0, t1        : 观测的起止时点（Date 或 POSIXct）。点观测令 t0 == t1。
##   test_starts   : 各折测试窗起点向量。若为 NULL 则由 span_start/span_end 自动铺排。
##   test_len_days : 测试窗长度（日）
##   train_len_days: 训练窗长度（日）。mode = "anchored" 时忽略。
##   gap_days      : 【本次新增】测试窗之前的空窗日数。文档承诺 7 日。
##   embargo_days  : 测试窗之后的禁运日数。前向 WF 中通常无效，
##                   仅当 allow_future_train = TRUE 时才有实际作用。
##   mode          : "sliding"（定长滑窗，推荐）或 "anchored"（自起点扩张窗）
##   keep_train_len: TRUE 时整窗后移以保训练长度恒定；FALSE 时直接截短。
##                   默认 TRUE —— 否则加空窗会同时改变训练样本量，
##                   泄漏效应与样本量效应将混淆，双版本对比失去意义。
##   allow_future_train : 是否允许测试窗之后的样本进入训练（默认 FALSE）
##
## 返回
##   list，每元素为 list(fold, train_idx, test_idx, te0, te1, tr_lo, tr_hi)
purged_wf_splits2 <- function(t0, t1,
                              test_starts    = NULL,
                              test_len_days  = 14L,
                              train_len_days = 42L,
                              gap_days       = 7L,
                              embargo_days   = 0L,
                              step_days      = 7L,
                              mode           = c("sliding", "anchored"),
                              keep_train_len = TRUE,
                              allow_future_train = FALSE,
                              span_start = NULL, span_end = NULL,
                              verbose = TRUE) {

  mode <- match.arg(mode)
  stopifnot(length(t0) == length(t1))
  if (any(t0 > t1, na.rm = TRUE)) stop("存在 t0 > t1 的观测，请先清洗。")

  ## 日 -> 与 t0 同类型的时间增量。POSIXct 须换算为秒，否则 embargo 单位错为「秒」。
  D <- function(n) {
    if (inherits(t0, "POSIXct")) as.difftime(as.numeric(n) * 86400, units = "secs")
    else as.difftime(as.numeric(n), units = "days")
  }

  if (is.null(span_start)) span_start <- min(t0, na.rm = TRUE)
  if (is.null(span_end))   span_end   <- max(t1, na.rm = TRUE)

  ## 自动铺排测试窗起点：首折须让「训练窗 + 空窗」完整落在数据起点之后
  if (is.null(test_starts)) {
    lead <- if (mode == "anchored") train_len_days else train_len_days
    first_te0 <- span_start + D(lead + gap_days)
    test_starts <- seq(from = first_te0, to = span_end, by = D(step_days))
    test_starts <- test_starts[test_starts + D(test_len_days) <= span_end + D(1)]
  }

  out <- vector("list", length(test_starts))
  k <- 0L
  for (i in seq_along(test_starts)) {
    te0 <- test_starts[i]
    te1 <- te0 + D(test_len_days) - D(1)

    ## ---- 训练窗右界：测试窗起点前推 gap_days ----
    tr_hi <- te0 - D(gap_days)                       # 训练样本须严格早于此
    tr_lo <- if (mode == "anchored") span_start
             else if (keep_train_len) tr_hi - D(train_len_days)
             else max(span_start, te0 - D(train_len_days))

    ## ---- Purge：任何 t1 溢入 [tr_hi, te1] 的训练样本一律剔除 ----
    ## 这一式同时完成了 purge 与前置空窗，故不再另写 purge 分支。
    keep <- (t1 < tr_hi) & (t0 >= tr_lo)

    ## ---- 后置 embargo：仅在允许未来样本进训练时才有意义 ----
    if (isTRUE(allow_future_train)) {
      keep <- keep | ((t0 > te1 + D(embargo_days)))
    }

    tr_idx <- which(keep & !is.na(keep))
    te_idx <- which(t0 >= te0 & t0 <= te1)

    if (length(tr_idx) == 0L || length(te_idx) == 0L) next
    k <- k + 1L
    out[[k]] <- list(fold = k, train_idx = tr_idx, test_idx = te_idx,
                     te0 = te0, te1 = te1, tr_lo = tr_lo, tr_hi = tr_hi)
  }
  out <- out[seq_len(k)]

  if (isTRUE(verbose)) {
    cat(sprintf("折数 %d｜模式 %s｜训练 %dD｜前置空窗 %dD｜测试 %dD｜步进 %dD\n",
                k, mode, train_len_days, gap_days, test_len_days, step_days))
  }
  out
}


## ---------------------------------------------------------------------
## 二、折体检表（每折必须打印，不得凭源码判定折结构正确）
## ---------------------------------------------------------------------
wf_diagnose <- function(splits, t0, t1) {
  if (length(splits) == 0L) { message("空折集"); return(invisible(NULL)) }
  as_d <- function(x) as.numeric(difftime(x[[1]], x[[2]], units = "days"))
  df <- do.call(rbind, lapply(splits, function(s) {
    trn_hi <- max(t1[s$train_idx]); trn_lo <- min(t0[s$train_idx])
    data.frame(
      fold      = s$fold,
      train_lo  = as.character(as.Date(trn_lo)),
      train_hi  = as.character(as.Date(trn_hi)),
      n_train   = length(s$train_idx),
      train_len = round(as_d(list(trn_hi, trn_lo))) + 1,
      gap_actual= round(as_d(list(s$te0, trn_hi))) - 1,   # 实测空窗日数
      test_lo   = as.character(as.Date(s$te0)),
      test_hi   = as.character(as.Date(s$te1)),
      n_test    = length(s$test_idx),
      stringsAsFactors = FALSE)
  }))
  ## 三项硬检查
  chk <- c(
    "空窗恒 >= 设定值" = all(df$gap_actual >= 0),
    "训练长度恒定"     = (length(unique(df$train_len)) == 1L),
    "测试窗互不重叠之训练"= all(df$gap_actual >= 0))
  cat("\n---- 折体检 ----\n"); print(df, row.names = FALSE)
  cat("\n"); print(chk); cat("\n")
  invisible(df)
}


## ---------------------------------------------------------------------
## 三、死代码自证：证明旧式 embargo 子句在本折规格下剔除样本数为 0
##     （此函数存在的意义是让「已修复」这件事有凭据，而非口头声明）
## ---------------------------------------------------------------------
wf_selftest_dead_clause <- function(t0, t1, test_starts, test_len_days = 14L,
                                    embargo_days = 7L) {
  D <- function(n) if (inherits(t0, "POSIXct"))
    as.difftime(as.numeric(n) * 86400, units = "secs") else
      as.difftime(as.numeric(n), units = "days")
  killed <- 0L; gaps <- numeric(0)
  for (te0 in test_starts) {
    te0 <- if (inherits(t0, "Date")) as.Date(te0, origin = "1970-01-01") else te0
    te1 <- te0 + D(test_len_days) - D(1)
    c1  <- t1 < te0                                     # 旧第一式
    c2  <- !(t0 > te1 & t0 <= te1 + D(embargo_days))    # 旧第二式（embargo）
    killed <- killed + sum(c1 & !c2, na.rm = TRUE)
    if (any(c1)) gaps <- c(gaps, as.numeric(difftime(te0, max(t1[c1]), units = "days")) - 1)
  }
  cat(sprintf("旧式 embargo 子句累计剔除样本数 = %d  (为 0 即证死代码)\n", killed))
  cat(sprintf("旧折实测前置空窗：最小 %.0f 日、中位 %.0f 日\n",
              min(gaps), stats::median(gaps)))
  invisible(list(killed = killed, gaps = gaps))
}


## ---------------------------------------------------------------------
## 四、Phase 3 受累与否的一眼判定
##     加 7 日空窗后折数由 12 降为 11，首折测试起点后移一步进。
##     若 Phase 3 的十一折首折测试起于「数据起点 + 训练长 + 7 日」，
##     则空窗已在折生成层落实，Phase 3 不受本 bug 波及。
## ---------------------------------------------------------------------
wf_phase3_verdict <- function(phase3_first_test_start,
                              span_start = as.Date("2026-03-21"),
                              train_len_days = 42L, gap_days = 7L) {
  expect_with <- span_start + train_len_days + gap_days
  expect_without <- span_start + train_len_days
  s <- as.Date(phase3_first_test_start)
  verdict <- if (s == expect_with) "含空窗 —— Phase 3 不受本 bug 波及，结果可留用"
             else if (s == expect_without) "无空窗 —— Phase 3 受累，须与新折并跑"
             else "既不合含空窗亦不合无空窗，折生成器另有其式，须逐行核实"
  cat(sprintf("Phase 3 首折测试起点 = %s\n含空窗应为 %s｜无空窗应为 %s\n判定：%s\n",
              s, expect_with, expect_without, verdict))
  invisible(verdict)
}


## =====================================================================
## 用法（请在本机以真实 t0 / t1 跑一遍，勿以本注释代替实测）
## =====================================================================
if (identical(Sys.getenv("P0A_DEMO"), "1")) {
  set.seed(1)
  d  <- seq(as.Date("2026-03-21"), as.Date("2026-08-06"), by = "day")
  t0 <- rep(d, each = 50); t1 <- t0                      # 会员-日点观测

  ## 1) 自证旧式为死代码
  old_starts <- seq(as.Date("2026-03-21") + 42, by = 7, length.out = 12)
  wf_selftest_dead_clause(t0, t1, old_starts)

  ## 2) 新折 + 体检
  sp <- purged_wf_splits2(t0, t1, test_len_days = 14L, train_len_days = 42L,
                          gap_days = 7L, step_days = 7L, mode = "sliding")
  wf_diagnose(sp, t0, t1)

  ## 3) Phase 3 判定
  wf_phase3_verdict("2026-05-09")
}
