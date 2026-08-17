## =============================================================================
##  VALIDATOR PASSPORT
## =============================================================================
##  VALIDATOR-ID        V-R03B-BOUNDARY-002
##  VERSION             1.0.0
##  PURPOSE             重跑边界比对：主 CSV 行 6,100,001~6,143,388
##                      与 DB62 行 1~43,388 之逐列一致性
##                      —— 即《最硬之四句》第一句之复核
##
##  INPUT               主 CSV 路径、DB62 路径
##  OUTPUT              PASS / FAIL / INCONCLUSIVE ＋ 最大相对误差
##
##  NOT-CAPABLE-OF      本器【不能】回答：
##                        · CSV 为何终止于 6,143,388（STOP CAUSE）
##                        · 主 CSV 之内容来源属第 1 轮抑或第 11 轮
##                        · DB62 是 SCENE 抑或 METHOD ARTIFACT
##                        · 两档是否曾被替换
##                      本器仅能回答：两个指定行段，逐列数值/字符是否一致。
##
##  SC-LINKED-DEFECTS   ★ 本器为下列四条之【根治版】，其存在即为回归测试：
##
##    SC-016  以字符串精确匹配比对浮点列
##            → 根因：浮点列之字符串表示受格式化影响，非语义比对
##            → 根治：数值列一律转 numeric，以【相对误差】比对，禁字符串等号
##
##    SC-017  formatC canonical key 失效，机制 UNKNOWN
##            → 根因：以格式化字符串构造 join key，格式化本身即失效点
##            → 根治：【完全不构造 key】，改位置对应（positional）
##                    —— 因待验命题本就是位置对应，非集合匹配
##
##    SC-018  24 列 double 精确 join 不适用于容差型数据
##            → 根因：以 == 比对浮点
##            → 根治：容差比对，容差值预注册（A3），不得看过数据再定
##
##    SC-020  RES[M, on=] 非 UPDATE JOIN，n_match 未回填
##            → 根因：data.table join 语义误用，计数器静默为空
##            → 根治：不用 join；所有计数以 sum(logical) 直算，且加总和校验
##
##  STOP-ANCHOR         A1（相对误差为纯算术，不依赖 parser）
##                      A3（容差阈值预注册于 §PRE-REG，看数据前写死）
##
##  EVIDENCE-DEPENDENCY 文件系统 → fread(data.table) → character 读入
##                                → as.numeric 转型 → 算术比对
##                      ⚠ 与「以 readr 读入后比对」共模：同为 R 之数值转型
##                      ⚠ 与「Python/pandas 读入后比对」非共模：不同 parser
##                      → 若需 pairwise 独立，另跑 Python 版交叉
##
##  CERTIFICATION       UNCERTIFIED —— NC 全过后方可标 CERTIFIED
## =============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

## =============================================================================
## §PRE-REG · 预注册（A3 锚）—— 以下阈值在【看到数据之前】写死
## =============================================================================
PREREG <- list(
  run_id            = format(Sys.time(), "BOUNDARY-%Y%m%d_%H%M%S"),
  csv_start_row     = 6100001L,          # 主 CSV 之起始数据行（1-based，不含表头）
  csv_end_row       = 6143388L,
  db62_start_row    = 1L,
  db62_end_row      = 43388L,
  expected_n        = 43388L,
  expected_ncol     = 24L,
  rel_tol           = 1e-12,             # 数值列相对误差容差
  ## 预注册判定规则：以下三条在看数据前定死，禁 optional stopping
  rule_pass         = "字符列不符 = 0  且  数值列超容差 = 0",
  rule_fail         = "任一列不符 > 0",
  rule_inconclusive = "行数/列数不符，或转型产生非预期 NA",
  ## 预登记之历史读数（v3 §甲，🟠 转述，非本轮实测）
  hist_max_rel_err  = 5.061e-15,
  hist_char_mismatch= 0L,
  hist_num_over_tol = 0L
)

cat("================================================================\n")
cat(" V-R03B-BOUNDARY-002  v1.0.0\n")
cat(" RUN-ID :", PREREG$run_id, "\n")
cat(" 时间   :", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"), "\n")
cat("================================================================\n\n")
cat("===== §PRE-REG 预注册判据（A3 锚，看数据前已写死）=====\n")
str(PREREG, give.attr = FALSE)
cat("\n")

## =============================================================================
## §CORE · 核心比对器
##   设计要点：
##     ① 两侧【一律以 character 读入】—— 避开 parser 转型分歧
##     ② 字符列：直接 identical 比对
##     ③ 数值列：两侧各自 as.numeric，以相对误差比对
##     ④ 全程【无 join、无 key、无 formatC】—— 位置对应
##     ⑤ 所有计数以 sum(logical) 直算，并附总和校验
## =============================================================================
compare_positional <- function(A, B, rel_tol, num_cols = NULL) {

  stopifnot(is.data.table(A), is.data.table(B))

  ## 结构闸
  if (nrow(A) != nrow(B))  return(list(status = "INCONCLUSIVE", reason = sprintf("行数不等：A=%d B=%d", nrow(A), nrow(B))))
  if (ncol(A) != ncol(B))  return(list(status = "INCONCLUSIVE", reason = sprintf("列数不等：A=%d B=%d", ncol(A), ncol(B))))
  if (!identical(names(A), names(B)))
    return(list(status = "INCONCLUSIVE", reason = "列名不等（含顺序）"))

  n   <- nrow(A)
  nms <- names(A)

  ## 自动判定数值列：两侧皆可无警告转 numeric 者
  if (is.null(num_cols)) {
    num_cols <- vapply(nms, function(cn) {
      a <- suppressWarnings(as.numeric(A[[cn]]))
      b <- suppressWarnings(as.numeric(B[[cn]]))
      ## 仅当【非 NA 的原值】转型后仍非 NA，才算数值列
      okA <- !any(is.na(a) & !is.na(A[[cn]]) & trimws(A[[cn]]) != "")
      okB <- !any(is.na(b) & !is.na(B[[cn]]) & trimws(B[[cn]]) != "")
      okA && okB
    }, logical(1))
    num_cols <- nms[num_cols]
  }
  chr_cols <- setdiff(nms, num_cols)

  res <- data.table(col = nms, type = NA_character_,
                    mismatch = NA_integer_, max_rel_err = NA_real_)

  ## ---- 字符列：identical，禁任何格式化 ----
  for (cn in chr_cols) {
    a <- A[[cn]]; b <- B[[cn]]
    ## NA 与 "" 分别处理，避免静默视为相等
    bad <- !( (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b) )
    res[col == cn, `:=`(type = "character", mismatch = sum(bad), max_rel_err = NA_real_)]
  }

  ## ---- 数值列：相对误差，SC-016/018 之根治 ----
  for (cn in num_cols) {
    a <- suppressWarnings(as.numeric(A[[cn]]))
    b <- suppressWarnings(as.numeric(B[[cn]]))
    both_na <- is.na(a) & is.na(b)
    one_na  <- xor(is.na(a), is.na(b))
    denom   <- pmax(abs(a), abs(b))
    rel     <- ifelse(denom == 0, 0, abs(a - b) / denom)
    rel[both_na] <- 0
    rel[one_na]  <- Inf                       # 一侧 NA 一侧有值 → 视为不符
    over <- !is.na(rel) & rel > rel_tol
    res[col == cn, `:=`(type = "numeric",
                        mismatch = sum(over),
                        max_rel_err = suppressWarnings(max(rel[is.finite(rel)], na.rm = TRUE)))]
  }

  ## ---- 总和校验（SC-020 之根治：计数器不得静默为空）----
  if (any(is.na(res$mismatch)))
    return(list(status = "INCONCLUSIVE", reason = "存在未计数之列 —— 计数器失效"))

  total_mismatch <- sum(res$mismatch)
  chr_mismatch   <- sum(res[type == "character", mismatch])
  num_mismatch   <- sum(res[type == "numeric",  mismatch])
  if (chr_mismatch + num_mismatch != total_mismatch)
    return(list(status = "INCONCLUSIVE", reason = "分项计数与总计不符 —— 计数器自相矛盾"))

  list(status        = if (total_mismatch == 0L) "PASS" else "FAIL",
       n_rows        = n,
       n_cols        = length(nms),
       n_chr_cols    = length(chr_cols),
       n_num_cols    = length(num_cols),
       chr_mismatch  = chr_mismatch,
       num_mismatch  = num_mismatch,
       max_rel_err   = suppressWarnings(max(res$max_rel_err, na.rm = TRUE)),
       detail        = res)
}

## =============================================================================
## §NC · 负控制 —— 不过即 stop()，本器无资格执行
## =============================================================================
run_controls <- function(rel_tol) {
  cat("===== NEGATIVE / POSITIVE CONTROL（本器自身之验证）=====\n")
  ok <- TRUE

  mk <- function() data.table(
    id  = c("001","002","003"),
    txt = c("甲","乙","丙"),
    val = c("1.0000000000","2.5","3.14159265358979"),
    amt = c("100.25","-3.5","0")
  )

  ## PC-01 自我比对须 PASS
  r <- compare_positional(mk(), mk(), rel_tol)
  p1 <- identical(r$status, "PASS") && r$chr_mismatch == 0 && r$num_mismatch == 0
  cat(sprintf("  PC-01 自我比对          期望 PASS        实得 %s        %s\n",
              r$status, ifelse(p1,"PASS","FAIL"))); ok <- ok && p1

  ## NC-01 字符列扰动须 FAIL —— 若不 FAIL，本器不能证明字符列一致
  B <- mk(); B$txt[2] <- "丁"
  r <- compare_positional(mk(), B, rel_tol)
  p2 <- identical(r$status, "FAIL") && r$chr_mismatch == 1L
  cat(sprintf("  NC-01 字符扰动          期望 FAIL(chr=1) 实得 %s(chr=%s) %s\n",
              r$status, r$chr_mismatch, ifelse(p2,"PASS","FAIL"))); ok <- ok && p2

  ## NC-02 数值列超容差扰动须 FAIL —— SC-016 之回归测试
  B <- mk(); B$val[3] <- "3.14159265358000"      # 相对误差 ~3e-13 > 1e-12? 见下
  r <- compare_positional(mk(), B, 1e-14)
  p3 <- identical(r$status, "FAIL") && r$num_mismatch >= 1L
  cat(sprintf("  NC-02 数值超容差        期望 FAIL(num≥1) 实得 %s(num=%s) %s\n",
              r$status, r$num_mismatch, ifelse(p3,"PASS","FAIL"))); ok <- ok && p3

  ## NC-03 数值列【容差内】扰动须 PASS —— 防过度敏感（假阳性）
  B <- mk(); B$val[1] <- "1.0000000000000001"
  r <- compare_positional(mk(), B, 1e-12)
  p4 <- identical(r$status, "PASS")
  cat(sprintf("  NC-03 容差内扰动        期望 PASS        实得 %s        %s\n",
              r$status, ifelse(p4,"PASS","FAIL"))); ok <- ok && p4

  ## NC-04 格式差异【不得】被判为不符 —— SC-016 之核心：1.0 vs 1.00 语义相同
  B <- mk(); B$val[2] <- "2.50"
  r <- compare_positional(mk(), B, rel_tol)
  p5 <- identical(r$status, "PASS")
  cat(sprintf("  NC-04 格式差异不算不符  期望 PASS        实得 %s        %s   ← SC-016 根治点\n",
              r$status, ifelse(p5,"PASS","FAIL"))); ok <- ok && p5

  ## NC-05 行数不等须 INCONCLUSIVE，不得静默截断
  r <- compare_positional(mk(), mk()[1:2], rel_tol)
  p6 <- identical(r$status, "INCONCLUSIVE")
  cat(sprintf("  NC-05 行数不等          期望 INCONCLUSIVE 实得 %s  %s\n",
              r$status, ifelse(p6,"PASS","FAIL"))); ok <- ok && p6

  ## NC-06 单侧 NA 须判不符，不得视为相等
  B <- mk(); B$amt[1] <- NA_character_
  r <- compare_positional(mk(), B, rel_tol)
  p7 <- identical(r$status, "FAIL")
  cat(sprintf("  NC-06 单侧NA            期望 FAIL        实得 %s        %s\n",
              r$status, ifelse(p7,"PASS","FAIL"))); ok <- ok && p7

  if (!ok) {
    cat("\n⛔ CONTROL 未过 —— 本验证器【无资格】执行。\n")
    cat("   依 EAV-QMS Gate-2：未通过正负控制之验证器不具备 GREEN 资格。\n")
    stop("VALIDATOR NOT QUALIFIED", call. = FALSE)
  }
  cat("\n✅ 七项控制全过 —— 本器具备执行资格。\n\n")
  invisible(TRUE)
}

## =============================================================================
## §MAIN
## =============================================================================
run_boundary <- function(path_main_csv, path_db62) {

  run_controls(PREREG$rel_tol)

  ## ---- 六元组前置登记（与 V-R03B-SIXTUPLE-001 对账）----
  cat("===== 档案身份登记 =====\n")
  for (p in c(path_main_csv, path_db62)) {
    if (!file.exists(p)) stop(sprintf("档案不存在：%s", p), call. = FALSE)
    fi <- file.info(p)
    cat(sprintf("  %s\n    字节 %s ｜ mtime %s\n",
                basename(p), format(fi$size, big.mark = ","),
                format(fi$mtime, "%Y-%m-%d %H:%M:%S")))
  }
  cat("  ⚠ MD5 请以 V-R03B-SIXTUPLE-001 另行取得（本器不重复实作哈希，避免共模）\n\n")

  ## ---- 读表头 ----
  hdr <- names(fread(path_main_csv, nrows = 0L))
  cat(sprintf("===== 表头：%d 列 =====\n", length(hdr)))
  if (length(hdr) != PREREG$expected_ncol)
    cat(sprintf("  ⚠ 列数 %d ≠ 预注册 %d —— 须先裁定口径\n", length(hdr), PREREG$expected_ncol))

  ## ---- 读主 CSV 指定行段（一律 character，避开 parser 转型）----
  skip_n <- PREREG$csv_start_row          # 表头 1 行 + 前 (start-1) 数据行
  n_read <- PREREG$csv_end_row - PREREG$csv_start_row + 1L
  cat(sprintf("\n===== 读主 CSV：skip=%d, nrows=%d =====\n", skip_n, n_read))
  A <- fread(path_main_csv, skip = skip_n, nrows = n_read,
             header = FALSE, col.names = hdr, colClasses = "character",
             showProgress = TRUE)

  ## ---- 读 DB62 指定行段 ----
  cat(sprintf("===== 读 DB62：rows %d~%d =====\n", PREREG$db62_start_row, PREREG$db62_end_row))
  B <- fread(path_db62, nrows = PREREG$db62_end_row,
             colClasses = "character", showProgress = TRUE)
  B <- B[PREREG$db62_start_row:PREREG$db62_end_row]

  cat(sprintf("\n实读：A = %s 行 × %d 列 ｜ B = %s 行 × %d 列\n",
              format(nrow(A), big.mark=","), ncol(A),
              format(nrow(B), big.mark=","), ncol(B)))

  ## ---- 比对 ----
  cat("\n===== 位置对应比对（无 join、无 key、无 formatC）=====\n")
  r <- compare_positional(A, B, PREREG$rel_tol)

  if (r$status == "INCONCLUSIVE") {
    cat(sprintf("\n⚪ INCONCLUSIVE：%s\n", r$reason))
    return(invisible(r))
  }

  print(r$detail)
  cat(sprintf("\n----------------------------------------------------------------\n"))
  cat(sprintf("  行数            %s\n", format(r$n_rows, big.mark=",")))
  cat(sprintf("  列数            %d（字符 %d ／ 数值 %d）\n", r$n_cols, r$n_chr_cols, r$n_num_cols))
  cat(sprintf("  字符列不符      %d\n", r$chr_mismatch))
  cat(sprintf("  数值列超容差    %d   （容差 %g，预注册）\n", r$num_mismatch, PREREG$rel_tol))
  cat(sprintf("  最大相对误差    %.6g\n", r$max_rel_err))
  cat(sprintf("  判定            %s\n", r$status))
  cat(sprintf("----------------------------------------------------------------\n"))

  ## ---- 与历史读数对账（回溯矩阵回填用）----
  cat("\n===== 与 v3 §甲 历史读数对账（SC-016/017/018/020 回溯）=====\n")
  cat(sprintf("  历史 最大相对误差  %.6g   本轮 %.6g   %s\n",
              PREREG$hist_max_rel_err, r$max_rel_err,
              ifelse(abs(r$max_rel_err - PREREG$hist_max_rel_err) /
                     max(PREREG$hist_max_rel_err, r$max_rel_err) < 0.5,
                     "同量级", "⚠ 不同量级 —— 须裁定")))
  cat(sprintf("  历史 字符列不符    %d       本轮 %d       %s\n",
              PREREG$hist_char_mismatch, r$chr_mismatch,
              ifelse(r$chr_mismatch == PREREG$hist_char_mismatch, "一致", "⚠ 不一致")))
  cat(sprintf("  历史 数值超容差    %d       本轮 %d       %s\n",
              PREREG$hist_num_over_tol, r$num_mismatch,
              ifelse(r$num_mismatch == PREREG$hist_num_over_tol, "一致", "⚠ 不一致")))

  cat("\n===== 回溯矩阵回填建议 =====\n")
  if (r$status == "PASS" && r$chr_mismatch == 0L && r$num_mismatch == 0L) {
    cat("  SC-016 / SC-018 → 重算读数与历史一致\n")
    cat("  处置：《最硬之四句》第一句维持 🟢\n")
    cat("        且证据底座升级 ——「一次可能坏掉的尺」→「换尺重量仍同」\n")
    cat("        须于册中补记本轮 RUN-ID：", PREREG$run_id, "\n")
  } else {
    cat("  ⚠ 重算读数与历史【不一致】\n")
    cat("  处置：《最硬之四句》第一句由 🟢 降 🟠\n")
    cat("        属【合法降级】—— 原判据被本轮证据证伪，入 SC 册\n")
  }

  cat("\n⚠ 本器【未】回答 SC-017（全局检索 NOT_FOUND 56,612）与 SC-020（n_match）。\n")
  cat("   该二者属【集合存在性】命题，与本器之【位置对应】命题不同，\n")
  cat("   须另立 V-R03B-LOOKUP-003，不得由本器结论外推（适用域纪律）。\n")

  invisible(r)
}

## =============================================================================
## 用法
## =============================================================================
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2L) {
    cat("\n用法：\n")
    cat("  Rscript V-R03B-BOUNDARY-002.R <主CSV路径> <DB62路径>\n\n")
    cat("或於 R/Positron 內：\n")
    cat("  source('V-R03B-BOUNDARY-002.R')\n")
    cat("  run_boundary('数据库/R03b_player_dealer_daily.csv',\n")
    cat("               '数据库/R03b_v3_offset_6100000_43388.csv')\n\n")
    cat("記憶體提示：本器只讀 43,388 行 × 24 列（約 40 MB），\n")
    cat("            不載入 2.2 GB 全檔，可於一般機器執行。\n\n")
  } else {
    run_boundary(args[1], args[2])
  }
}
