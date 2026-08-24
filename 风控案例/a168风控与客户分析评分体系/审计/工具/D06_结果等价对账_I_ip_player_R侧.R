## ═════════════════════════════════════════════════════════════════════════════
## ★ D 层 · 结果等价对账 · R 侧 · I_ip_player.csv ★
## ═════════════════════════════════════════════════════════════════════════════
## 立于 2026-08-24 · 应 REDTEAM 裁定：静态 PASS ≠ 数据实测 PASS。
##
## 【四级等价 · 本脚本只负责 C 与 D 两级】
##   A 内层查询逐字一致 ......... 已 PASS（机检：总包行 1589~1654 前 65 行逐字全等）
##   B 分批排序规则确定 ......... 已 PASS（OVER 内追 bet_ip、member_id 破并列）
##   C rn 阶梯完整覆盖 .......... 本脚本第二节实测
##   D 合批结果与原版等价 ....... 本脚本第三节实测
##   ★ 未过 D，一律不得书「结果一致」。
##
## 【rn 生命周期闸（正式闸 · 次序不可颠倒）】
##   SQL → CSV（暂保 rn）→ 批间四验 → 合批 → 全量对账 → 确认无缺口无重叠
##       → 删 rn → 最终交付
##   ⚠ rn 一删，遗漏与重叠即再无从查起。**删 rn 之前，batch-integrity 必须 PASS。**
## ═════════════════════════════════════════════════════════════════════════════

library(data.table)

## ── 参数（唯一须手改之处）──────────────────────────────────────────────────
DIR      <- "数据库/_batch_I_ip_player"   # 七批 CSV 所在目录
T_TRUE   <- 696403L                        # 实测值（2026-08-24，6.528 秒）
B        <- 100000L                        # 每批上限
KEY      <- c("bet_ip", "member_id")       # 本件之业务粒度键（＝其 GROUP BY 键）
DEC4     <- c("stake_ip","game_pnl_ip","rebate_ip","net_pnl_ip",
              "net_pnl_all","game_pnl_all")
DEC8     <- c("ip_order_share")
## 原版侧库内指纹（跑 D06_..._SQL侧.sql 之 ① 后，把读数抄进来）
## ★ 已实测（2026-08-24，12.412 秒）——九项皆自 ① 段读回，非估计
FP_SQL <- list(
  n_rows          = 696403,
  n_keys          = 696403,
  sum_n_orders_ip = 107574958,
  sum_n_rounds_ip = 76663794,
  sum_stake_ip    = 11650752680.8869,
  sum_game_pnl_ip = -132501638.0735,
  sum_rebate_ip   = 7596759.9155,
  sum_net_pnl_ip  = -124904878.1447,
  fp_sum          = -142789586420
)
KEY_MIN <- "1.0.138.117|148756829"     # ① 段读回，供边界自验
KEY_MAX <- "99.95.229.190|51576226"

## ★ 哈希校准（跑 SQL 侧 ①b，把六个 h_signed 抄进来；未抄则 fp_sum 自动 SKIPPED）
HASH_PROBE <- c(
  ""                              = NA_real_,
  "a"                             = NA_real_,
  "abc"                           = NA_real_,
  "0"                             = NA_real_,
  "Hello, world!"                 = NA_real_,
  "1.0.138.117\u001f148756829"    = NA_real_
)

fail <- function(...) stop("【D 层 FAIL】", ..., call. = FALSE)
ok   <- function(...) cat("  ✅ ", ..., "\n", sep = "")

## ── 一、读入七批（编码自适应：Superset 导出多为 GBK/GB18030）─────────────────
read_batch <- function(f) {
  for (enc in c("UTF-8", "GB18030")) {
    x <- try(fread(f, encoding = enc, colClasses = "character"), silent = TRUE)
    if (!inherits(x, "try-error") && nrow(x) > 0L) return(x)
  }
  fail("无法读入：", f)
}
files <- sort(list.files(DIR, pattern = "\\.csv$", full.names = TRUE))
cat("── 一、读入 ──\n  档数：", length(files), "\n", sep = "")
if (length(files) != ceiling(T_TRUE / B))
  fail("档数 ", length(files), " ≠ 应有批数 ", ceiling(T_TRUE / B))
bl <- lapply(files, read_batch)

## ── 二、批间四验（C 级 · 逐批，任一不符即停）──────────────────────────────
cat("── 二、批间四验（C 级）──\n")
for (k in seq_along(bl)) {
  d <- bl[[k]]
  if (!"rn" %in% names(d)) fail("第 ", k, " 批无 rn 列 —— 是否误删？删 rn 须在 D 级之后")
  rn <- as.numeric(d$rn)
  n_rows <- nrow(d); n_uniq <- uniqueN(rn)
  exp_min <- (k - 1L) * B + 1L
  exp_n   <- if (k < length(bl)) B else T_TRUE - (length(bl) - 1L) * B
  if (n_rows != n_uniq)        fail("第 ", k, " 批：批内重复 ", n_rows - n_uniq, " 行")
  if (min(rn) != exp_min)      fail("第 ", k, " 批：rn_min = ", min(rn), "，应为 ", exp_min,
                                    " —— 与上批未接合（常见于只推下界而上界未动）")
  if (max(rn) != min(rn) + n_rows - 1) fail("第 ", k, " 批：批内有缺口")
  if (n_rows != exp_n)         fail("第 ", k, " 批：行数 ", n_rows, "，应为 ", exp_n)
  ok("第 ", k, " 批：n=", n_rows, " rn∈[", min(rn), ",", max(rn), "] 四验通过")
}

## ── 三、合批与全量完整性（C 级收口）───────────────────────────────────────
cat("── 三、合批完整性 ──\n")
all <- rbindlist(bl, use.names = TRUE)
rn  <- as.numeric(all$rn)
if (nrow(all) != T_TRUE)            fail("合批行数 ", nrow(all), " ≠ T_true ", T_TRUE)
if (uniqueN(rn) != T_TRUE)          fail("rn 重号 ", nrow(all) - uniqueN(rn), " 个")
if (min(rn) != 1 || max(rn) != T_TRUE) fail("rn 区间 [", min(rn), ",", max(rn), "] ≠ [1,", T_TRUE, "]")
gap <- setdiff(seq_len(T_TRUE), rn)
if (length(gap)) fail("rn 缺号 ", length(gap), " 个，首五：", paste(head(gap, 5), collapse = ","))
if (uniqueN(all[, ..KEY]) != T_TRUE) fail("业务键不唯一 —— 与 GROUP BY 语义相悖，须回查")
ok("合批：", nrow(all), " 行；rn 恰为 1..", T_TRUE, "，无缺号无重号；业务键唯一")
cat("  ★ C 级 PASS —— 阶梯完整覆盖已由数实证，非由结构推得\n")

## ── 四、D 级 · 与原版库内指纹对账 ─────────────────────────────────────────
cat("── 四、结果等价对账（D 级）──\n")
## ── 校验器先自校：哈希实现是否两侧同一 ────────────────────────────────────
## ★ ① 段实测 fp_sum 为负（均值 ≈ 0），足证 murmur_hash3_32 于本库返回
##   **有符号 32 位整数**；而 R 之 strtoi(hex,16) 得**无符号**值。
##   不换算即比对，必误报 FAIL。此为本方 v1 之缺陷，已修，留证于此。
to_signed32 <- function(u) ifelse(u >= 2147483648, u - 4294967296, u)
mm32 <- function(s) {
  if (!requireNamespace("digest", quietly = TRUE)) return(rep(NA_real_, length(s)))
  vapply(s, function(z) to_signed32(as.numeric(
           strtoi(digest::digest(z, algo = "murmur32", serialize = FALSE), 16L))),
         numeric(1L), USE.NAMES = FALSE)
}
HASH_OK <- FALSE
if (!anyNA(HASH_PROBE)) {
  probe_r <- mm32(names(HASH_PROBE))
  HASH_OK <- !anyNA(probe_r) && all(probe_r == as.numeric(HASH_PROBE))
  cat("  哈希校准：", if (HASH_OK) "两侧同一算法同一种子 → fp_sum 可用"
      else "两侧不一致 → fp_sum 降级 SKIPPED，改以其余八项裁定", "\n", sep = "")
  if (!HASH_OK) {
    print(data.table(probe = names(HASH_PROBE),
                     SQL侧 = as.numeric(HASH_PROBE), R侧 = probe_r))
  }
} else {
  cat("  哈希校准：HASH_PROBE 未填 → fp_sum 降级 SKIPPED（须跑 SQL 侧 ①b 抄入）\n")
}

## ── 边界自验（不依赖哈希，先跑）────────────────────────────────────────────
kk <- do.call(paste, c(as.list(all[, ..KEY]), sep = "|"))
if (min(kk) != KEY_MIN) fail("key_min = ", min(kk), "，应为 ", KEY_MIN)
if (max(kk) != KEY_MAX) fail("key_max = ", max(kk), "，应为 ", KEY_MAX)
ok("键之上下界与原版一致：[", KEY_MIN, " , ", KEY_MAX, "]")

num <- function(x) as.numeric(x)
rowtext <- function(d) {
  cols <- setdiff(names(d), "rn")
  parts <- lapply(cols, function(c) {
    v <- d[[c]]
    if (c %in% DEC4) formatC(round(num(v), 4), format = "f", digits = 4)
    else if (c %in% DEC8) formatC(round(num(v), 8), format = "f", digits = 8)
    else ifelse(is.na(v), "\\N", as.character(v))
  })
  do.call(paste, c(parts, sep = "\u001f"))
}
FP_R <- list(
  n_rows          = nrow(all),
  n_keys          = uniqueN(all[, ..KEY]),
  sum_n_orders_ip = sum(num(all$n_orders_ip)),
  sum_n_rounds_ip = sum(num(all$n_rounds_ip)),
  sum_stake_ip    = round(sum(round(num(all$stake_ip),    4)), 4),
  sum_game_pnl_ip = round(sum(round(num(all$game_pnl_ip), 4)), 4),
  sum_rebate_ip   = round(sum(round(num(all$rebate_ip),   4)), 4),
  sum_net_pnl_ip  = round(sum(round(num(all$net_pnl_ip),  4)), 4),
  fp_sum          = if (HASH_OK) sum(mm32(rowtext(all))) else NA_real_
)
cmp <- data.table(项 = names(FP_SQL),
                  原版侧 = unlist(FP_SQL), 分批侧 = unlist(FP_R))
## 容差：计数类须精确相等；金额类容 1e-4（ROUND 已定精度，容差只防浮点尾数）
tol <- c(n_rows = 0, n_keys = 0, sum_n_orders_ip = 0, sum_n_rounds_ip = 0,
         sum_stake_ip = 1e-4, sum_game_pnl_ip = 1e-4, sum_rebate_ip = 1e-4,
         sum_net_pnl_ip = 1e-4, fp_sum = 0)
cmp[, 差 := 分批侧 - 原版侧]
cmp[, 判 := fifelse(is.na(分批侧), "SKIPPED",
             fifelse(abs(差) <= tol[项], "PASS", "FAIL"))]
print(cmp)
if (any(cmp$判 == "FAIL"))
  fail("指纹不符 —— 须跑 SQL 侧 ② 一次导全，与合批档做真正的双向反连以定位差异行")
n_skip <- sum(cmp$判 == "SKIPPED")
if (n_skip == 0L) {
  cat("  ★ D 级 PASS —— 九项全同：行数、键数、六项列级合计、顺序无关之行指纹\n")
  cat("  ★ 可书：RESULT_EQUIVALENCE = TESTED_PASS\n")
} else {
  cat("  ★ D 级 PARTIAL —— 八项全同，fp_sum 因哈希未校准而 SKIPPED\n")
  cat("  ★ 只可书：RESULT_EQUIVALENCE = TESTED_PASS_WITHOUT_ROW_FINGERPRINT\n")
  cat("    八项能证行数、键数、六项合计相同；不能排除「两行之值互换」此类保合计之差异。\n")
  cat("    欲收此口，须跑 SQL 侧 ①b 抄入 HASH_PROBE 后重跑本脚本。\n")
}
cat("  ⚠ 已知限：哈希碰撞概率非零，故 fp_sum 不单独作证，须与前八项同时吻合方立。\n")

## ── 五、rn 之删除（唯有至此方可执行）──────────────────────────────────────
cat("── 五、删 rn 并落最终交付档 ──\n")
final <- copy(all)[, rn := NULL]
setcolorder(final, setdiff(names(all), "rn"))
fwrite(final, file.path(dirname(DIR), "I_ip_player.csv"), bom = TRUE)
ok("已落档：I_ip_player.csv —— ", nrow(final), " 行 × ", ncol(final), " 列（rn 已去）")
cat("  ⚠ 七批原档（含 rn）请加 _superseded 归档，禁删 —— 其 rn 是本次完整性之唯一物证。\n")
## ═════════════════════════════════════════════════════════════════════════════
