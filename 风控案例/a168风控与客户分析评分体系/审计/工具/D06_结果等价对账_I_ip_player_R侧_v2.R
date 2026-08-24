## ═════════════════════════════════════════════════════════════════════════════
## ★ D 层 · 结果等价对账 · R 侧 · I_ip_player.csv · v2 ★
## ═════════════════════════════════════════════════════════════════════════════
## 立于 2026-08-24 · 应 REDTEAM 裁定：静态 PASS ≠ 数据实测 PASS。
##
## 【v2 之三处斧正（v1 有错，留证）】
##   W-O · v1 以 strtoi(hex,16) 取 murmur32，得**无符号**值；而 StarRocks 之
##         murmur_hash3_32 返回**有符号 32 位整数**（① 段实测 fp_sum 为负可证）。
##         两侧不换算即比对，必误报 FAIL。
##   W-P · 更根本者：fp_sum 之比对还须 CAST(ROUND(x,n) AS STRING) 之渲染逐字一致，
##         而该渲染因引擎而异、无从推定。2026-08-24 实测：以五种渲染变体复算，
##         无一命中 SQL 侧之 -142,789,586,420。**fp_sum 设计作废**，
##         改以整数交叉项（①c）——不经字串、不经哈希、不经浮点。
##   W-Q · v1 之 HASH_PROBE 用 c("" = NA, ...) 写法，R 不许零长变量名，当场语法错。
##         该向量已整体删除。
##
## 【四级等价】
##   A 内层查询逐字一致 ......... PASS（机检：总包行 1589~1654 前 65 行逐字全等）
##   B 分批排序规则确定 ......... PASS（OVER 内追 bet_ip、member_id 破并列）
##   C rn 阶梯完整覆盖 .......... 本脚本第二、三节实测
##   D 合批结果与原版等价 ....... 本脚本第四节实测
##   ★ 未过 D，一律不得书「结果一致」。
##
## 【rn 生命周期闸（次序不可颠倒）】
##   SQL → CSV（暂保 rn）→ 批间四验 → 合批 → 全量对账 → 无缺口无重叠
##       → 删 rn → 最终交付
##   ⚠ rn 一删，遗漏与重叠即再无从查起。删 rn 之前，batch-integrity 必须 PASS。
## ═════════════════════════════════════════════════════════════════════════════

library(data.table)

## ── 参数（唯一须手改之处）──────────────────────────────────────────────────
SRC    <- "数据库/_batch_I_ip_player"   # 七批 CSV 之目录，或七批合并后之单一 CSV，皆可
OUT    <- "数据库/I_ip_player.csv"      # 最终交付档（rn 已去）
T_TRUE <- 696403L                        # ① 段实测（2026-08-24，12.412 秒）
B      <- 100000L                        # 每批上限
KEY    <- c("bet_ip", "member_id")       # 业务粒度键（＝其 GROUP BY 键）

## 原版侧库内指纹 · ① 段实测八项（2026-08-24）
FP_SQL <- c(
  n_rows          = 696403,
  n_keys          = 696403,
  sum_n_orders_ip = 107574958,
  sum_n_rounds_ip = 76663794,
  sum_stake_ip    = 11650752680.8869,
  sum_game_pnl_ip = -132501638.0735,
  sum_rebate_ip   = 7596759.9155,
  sum_net_pnl_ip  = -124904878.1447
)
KEY_MIN <- "1.0.138.117|148756829"      # ① 段读回
KEY_MAX <- "99.95.229.190|51576226"

## 原版侧 ①c 交叉项（跑 SQL 侧 ①c 后抄入；留 NA 则该三项 SKIPPED）
XSUM_SQL <- c(
  x1_stake_x_orders    = NA_real_,
  x2_netpnl_x_rounds   = NA_real_,
  x3_share_x_ordersall = NA_real_
)
## 分批侧参照值（2026-08-24 已自七批合并档 696,403 行以精确整数算出）：
##   x1 =  235289238567809030
##   x2 =   -2557633517562424
##   x3 =   10757495877395650

fail <- function(...) stop("【D 层 FAIL】", ..., call. = FALSE)
ok   <- function(...) cat("  \u2705 ", ..., "\n", sep = "")

## ── 一、读入（兼收目录或单一合并档；编码自适应）──────────────────────────
read_any <- function(f) {
  for (enc in c("UTF-8", "GB18030")) {
    x <- try(fread(f, encoding = enc, colClasses = "character"), silent = TRUE)
    if (!inherits(x, "try-error") && nrow(x) > 0L) return(x)
  }
  fail("无法读入：", f)
}
cat("\u2500\u2500 \u4e00\u3001\u8bfb\u5165 \u2500\u2500\n")
if (dir.exists(SRC)) {
  files <- sort(list.files(SRC, pattern = "\\.csv$", full.names = TRUE))
  if (!length(files)) fail("目录内无 CSV：", SRC)
  bl <- lapply(files, read_any)
  cat("  来源：目录，档数 ", length(files), "\n", sep = "")
  MODE <- "batches"
} else {
  all1 <- read_any(SRC)
  bl <- list(all1)
  cat("  来源：单一合并档，行数 ", nrow(all1), "\n", sep = "")
  MODE <- "merged"
}

## ── 二、批间四验（C 级 · 仅当来源为分档目录时逐批验）────────────────────
cat("\u2500\u2500 \u4e8c\u3001\u6279\u95f4\u56db\u9a8c\uff08C \u7ea7\uff09\u2500\u2500\n")
if (MODE == "batches") {
  if (length(bl) != ceiling(T_TRUE / B))
    fail("档数 ", length(bl), " \u2260 应有批数 ", ceiling(T_TRUE / B))
  for (k in seq_along(bl)) {
    d <- bl[[k]]
    if (!"rn" %in% names(d)) fail("第 ", k, " 批无 rn 列 —— 是否误删？删 rn 须在 D 级之后")
    rn <- as.numeric(d$rn); n_rows <- nrow(d)
    exp_min <- (k - 1L) * B + 1L
    exp_n   <- if (k < length(bl)) B else T_TRUE - (length(bl) - 1L) * B
    if (n_rows != uniqueN(rn)) fail("第 ", k, " 批：批内重复 ", n_rows - uniqueN(rn), " 行")
    if (min(rn) != exp_min)    fail("第 ", k, " 批：rn_min = ", min(rn), "，应为 ", exp_min,
                                    " —— 与上批未接合（常见于只推下界而上界未动）")
    if (max(rn) != min(rn) + n_rows - 1) fail("第 ", k, " 批：批内有缺口")
    if (n_rows != exp_n)       fail("第 ", k, " 批：行数 ", n_rows, "，应为 ", exp_n)
    ok("第 ", k, " 批：n=", n_rows, " rn\u2208[", min(rn), ",", max(rn), "] 四验通过")
  }
} else {
  cat("  来源为合并档，逐批四验改由第三节以 rn 反推批边界代之\n")
}

## ── 三、合批完整性（C 级收口）───────────────────────────────────────────
cat("\u2500\u2500 \u4e09\u3001\u5408\u6279\u5b8c\u6574\u6027 \u2500\u2500\n")
all <- rbindlist(bl, use.names = TRUE)
if (!"rn" %in% names(all)) fail("无 rn 列 —— 完整性无从验起")
rn <- as.numeric(all$rn)
if (nrow(all) != T_TRUE)               fail("合批行数 ", nrow(all), " \u2260 T_true ", T_TRUE)
if (uniqueN(rn) != T_TRUE)             fail("rn 重号 ", nrow(all) - uniqueN(rn), " 个")
if (min(rn) != 1 || max(rn) != T_TRUE) fail("rn 区间 [", min(rn), ",", max(rn), "] \u2260 [1,", T_TRUE, "]")
gap <- setdiff(seq_len(T_TRUE), rn)
if (length(gap)) fail("rn 缺号 ", length(gap), " 个，首五：", paste(head(gap, 5), collapse = ","))
if (uniqueN(all[, ..KEY]) != T_TRUE) fail("业务键不唯一 —— 与 GROUP BY 语义相悖，须回查")
ok("rn 恰为 1..", T_TRUE, "，无缺号无重号；业务键唯一")
## 以 rn 反推七批边界（合并档亦可验）
for (k in seq_len(ceiling(T_TRUE / B))) {
  lo <- (k - 1L) * B + 1L; hi <- min(k * B, T_TRUE)
  c_k <- sum(rn >= lo & rn <= hi)
  if (c_k != hi - lo + 1L) fail("第 ", k, " 批区间 [", lo, ",", hi, "] 实有 ", c_k, " 行，应有 ", hi - lo + 1L)
}
ok("七批区间以 rn 反推，各批行数皆合")
cat("  \u2605 C 级 PASS —— 阶梯完整覆盖已由数实证，非由结构推得\n")

## ── 四、D 级 · 与原版对账 ───────────────────────────────────────────────
cat("\u2500\u2500 \u56db\u3001\u7ed3\u679c\u7b49\u4ef7\u5bf9\u8d26\uff08D \u7ea7\uff09\u2500\u2500\n")
kk <- do.call(paste, c(as.list(all[, ..KEY]), sep = "|"))
if (min(kk) != KEY_MIN) fail("key_min = ", min(kk), "，应为 ", KEY_MIN)
if (max(kk) != KEY_MAX) fail("key_max = ", max(kk), "，应为 ", KEY_MAX)
ok("键之上下界与原版一致")

num <- function(x) as.numeric(x)
r4  <- function(x) round(num(x), 4)
FP_R <- c(
  n_rows          = nrow(all),
  n_keys          = uniqueN(all[, ..KEY]),
  sum_n_orders_ip = sum(num(all$n_orders_ip)),
  sum_n_rounds_ip = sum(num(all$n_rounds_ip)),
  sum_stake_ip    = round(sum(r4(all$stake_ip)),    4),
  sum_game_pnl_ip = round(sum(r4(all$game_pnl_ip)), 4),
  sum_rebate_ip   = round(sum(r4(all$rebate_ip)),   4),
  sum_net_pnl_ip  = round(sum(r4(all$net_pnl_ip)),  4)
)
tol <- c(n_rows = 0, n_keys = 0, sum_n_orders_ip = 0, sum_n_rounds_ip = 0,
         sum_stake_ip = 1e-4, sum_game_pnl_ip = 1e-4, sum_rebate_ip = 1e-4,
         sum_net_pnl_ip = 1e-4)
cmp <- data.table(项 = names(FP_SQL), 原版侧 = FP_SQL, 分批侧 = FP_R[names(FP_SQL)])
cmp[, 差 := 分批侧 - 原版侧][, 判 := fifelse(abs(差) <= tol[项], "PASS", "FAIL")]
print(cmp)
if (any(cmp$判 == "FAIL"))
  fail("八项对账不符 —— 须跑 SQL 侧 \u2461 一次导全，与合批档做双向反连以定位差异行")
ok("八项全同：行数、键数、六项列级合计")

## ①c 交叉项（以精确整数算，不经浮点）
if (!requireNamespace("gmp", quietly = TRUE)) {
  cat("  \u26a0 未装 gmp 套件，交叉项改以 double 计（约 15~16 位有效数字，本件 18 位，恐失真）\n")
  bigsum <- function(v) sum(v)
  asI <- function(x, s) round(num(x) * s)
} else {
  bigsum <- function(v) sum(gmp::as.bigz(v))
  asI <- function(x, s) gmp::as.bigz(sprintf("%.0f", round(num(x) * s)))
}
X_R <- c(
  x1_stake_x_orders    = as.character(bigsum(asI(all$stake_ip, 1e4)        * asI(all$n_orders_ip, 1))),
  x2_netpnl_x_rounds   = as.character(bigsum(asI(all$net_pnl_ip, 1e4)      * asI(all$n_rounds_ip, 1))),
  x3_share_x_ordersall = as.character(bigsum(asI(all$ip_order_share, 1e8)  * asI(all$n_orders_all, 1)))
)
cat("  分批侧交叉项：\n"); print(X_R)
if (anyNA(XSUM_SQL)) {
  cat("  \u2605 D 级 PARTIAL —— 八项全同；交叉项三数 SKIPPED（XSUM_SQL 未填）\n")
  cat("    只可书：RESULT_EQUIVALENCE = TESTED_PASS_ON_EIGHT_METRICS\n")
  cat("    八项能证行数、键数、六项合计相同；不能排除「两行互换其值」此类保合计之差异。\n")
  cat("    欲收此口，请跑 SQL 侧 \u2460c，把三数抄入 XSUM_SQL 后重跑本脚本。\n")
} else {
  bad <- names(XSUM_SQL)[as.character(XSUM_SQL) != X_R[names(XSUM_SQL)]]
  if (length(bad)) fail("交叉项不符：", paste(bad, collapse = ", "))
  ok("交叉项三数全同")
  cat("  \u2605 D 级 PASS（8 + 3 = 11 项全同）\n")
  cat("    可书：RESULT_EQUIVALENCE = TESTED_PASS\n")
}

## ── 五、删 rn 并落最终交付档（唯有 D 级过关方可执行）──────────────────────
cat("\u2500\u2500 \u4e94\u3001\u5220 rn \u4e0e\u843d\u6863 \u2500\u2500\n")
final <- copy(all)[, rn := NULL]
fwrite(final, OUT, bom = TRUE)
ok("已落档：", OUT, " —— ", nrow(final), " 行 \u00d7 ", ncol(final), " 列（rn 已去）")
cat("  \u26a0 七批原档（含 rn）请加 _superseded 归档，禁删 —— 其 rn 是本次完整性之唯一物证。\n")
## ═════════════════════════════════════════════════════════════════════════════
