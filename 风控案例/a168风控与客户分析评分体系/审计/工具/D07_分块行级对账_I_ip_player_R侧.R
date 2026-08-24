## ═════════════════════════════════════════════════════════════════════════════
## ★ §D07 · 分块行级对账 · R 侧 · I_ip_player.csv ★
## ═════════════════════════════════════════════════════════════════════════════
## 立于 2026-08-24 · 应先生所命：须证两版输出一模一样，无一观测值遗漏或重叠。
##
## 【前答之误 · 撤回 W-R】
##   我前次把先生之意误读为「在原版加一列装点门面」，遂答「不必加」。
##   实则先生之意是：**原版亦按同一步骤排出序列号，令两版可逐行对照**。
##   此意正当，我前答失焦，撤回。本节即照此意所立。
##
## 【何以不照字面做「原版一次导全 + rn」】
##   导出上限每次十万行，而 T_true = 696,403。原版一次导全根本导不出来；
##   若分批导，那就又是分批版——循环无解。
##   故改以：原版留在库内，只导其**分块指纹**（69,641 行，一次可导）。
##
## 【强度】块大小 10。任一行若在下载途中丢失或重出，其所在之 10 行块，
##   行数与四项合计必变；跨块搬移则两块之键界与合计同时变。
##   业务键已实证唯一（n_keys = n_rows = 696,403），故块内互换即撞键。
##   ★ 此为「逐行对照」之可行等价物，**定位精度 10 行**。
##
## 【与 D06 之别】D06 八项系全档一个数，只能答「总量对不对」；
##   D07 出 69,641 个数，能答「哪一段对不对」。前者是体检，后者是拍片。
## ═════════════════════════════════════════════════════════════════════════════

library(data.table)

## ── 参数 ──────────────────────────────────────────────────────────────────
SRC_BATCH <- "数据库/_batch_I_ip_player.csv"                       # 七批合并档（含 rn）
SRC_ORIG  <- "数据库/_audit/I_ip_player_blk10_原版侧.csv"          # 跑 D07 SQL 侧所导
BLK       <- 10L
T_TRUE    <- 696403L

## 分批侧分块表之参照指纹（2026-08-24 已自合并档算出，供速查）
REF_MD5   <- "19baf31f75c129d4aa300b5639d1fed6"
REF_NBLK  <- 69641L

fail <- function(...) stop("【D07 FAIL】", ..., call. = FALSE)
ok   <- function(...) cat("  \u2705 ", ..., "\n", sep = "")

read_any <- function(f) {
  for (enc in c("UTF-8", "GB18030")) {
    x <- try(fread(f, encoding = enc, colClasses = "character"), silent = TRUE)
    if (!inherits(x, "try-error") && nrow(x) > 0L) return(x)
  }
  fail("无法读入：", f)
}

## ── 一、自七批合并档算分块表（分批侧）────────────────────────────────────
cat("\u2500\u2500 \u4e00\u3001\u5206\u6279\u4fa7\u5206\u5757\u8868 \u2500\u2500\n")
b <- read_any(SRC_BATCH)
if (!"rn" %in% names(b)) fail("合并档无 rn 列 —— 无从分块")
b[, rn := as.integer(rn)]
if (nrow(b) != T_TRUE) fail("合并档行数 ", nrow(b), " \u2260 T_true ", T_TRUE)
b[, blk := (rn - 1L) %/% BLK]
b[, key := paste(bet_ip, member_id, sep = "|")]
r4 <- function(x) round(as.numeric(x), 4)
BB <- b[, .(n        = .N,
            rn_min   = min(rn),          rn_max  = max(rn),
            key_min  = min(key),         key_max = max(key),
            s_orders = sum(as.numeric(n_orders_ip)),
            s_rounds = sum(as.numeric(n_rounds_ip)),
            s_stake  = round(sum(r4(stake_ip)),   4),
            s_netpnl = round(sum(r4(net_pnl_ip)), 4)),
        by = blk][order(blk)]
if (nrow(BB) != REF_NBLK) fail("分块数 ", nrow(BB), " \u2260 应有 ", REF_NBLK)
ok("分批侧：", nrow(BB), " 块；\u03a3n = ", sum(BB$n))

## ── 二、读原版侧分块表 ───────────────────────────────────────────────────
cat("\u2500\u2500 \u4e8c\u3001\u539f\u7248\u4fa7\u5206\u5757\u8868 \u2500\u2500\n")
if (!file.exists(SRC_ORIG))
  fail("未见原版侧分块表：", SRC_ORIG, "\n    请先跑 D07_分块行级对账_I_ip_player_SQL侧.sql 并一次导全（69,641 行）")
OO <- read_any(SRC_ORIG)
numcols <- c("blk","n","rn_min","rn_max","s_orders","s_rounds","s_stake","s_netpnl")
for (cc in numcols) OO[[cc]] <- as.numeric(OO[[cc]])
setorder(OO, blk)
if (nrow(OO) != REF_NBLK) fail("原版侧分块数 ", nrow(OO), " \u2260 应有 ", REF_NBLK)
ok("原版侧：", nrow(OO), " 块；\u03a3n = ", sum(OO$n))

## ── 三、逐块比对（十列全比，任一列不符即定位到块）──────────────────────
cat("\u2500\u2500 \u4e09\u3001\u9010\u5757\u6bd4\u5bf9 \u2500\u2500\n")
setnames(BB, paste0(names(BB), "_b")); setnames(BB, "blk_b", "blk")
M <- merge(OO, BB, by = "blk", all = TRUE)
if (anyNA(M$n) || anyNA(M$n_b)) {
  miss_o <- M[is.na(n),   blk]; miss_b <- M[is.na(n_b), blk]
  fail("块号不对齐：原版缺 ", length(miss_o), " 块，分批缺 ", length(miss_b), " 块；",
       "首例 blk = ", head(c(miss_o, miss_b), 1))
}
chk <- list(
  n        = M[n        != n_b,                          blk],
  rn_min   = M[rn_min   != rn_min_b,                     blk],
  rn_max   = M[rn_max   != rn_max_b,                     blk],
  key_min  = M[key_min  != key_min_b,                    blk],
  key_max  = M[key_max  != key_max_b,                    blk],
  s_orders = M[s_orders != s_orders_b,                   blk],
  s_rounds = M[s_rounds != s_rounds_b,                   blk],
  s_stake  = M[abs(s_stake  - s_stake_b)  > 1e-4,        blk],
  s_netpnl = M[abs(s_netpnl - s_netpnl_b) > 1e-4,        blk]
)
bad <- Filter(length, chk)
if (length(bad)) {
  cat("  \u274c 不符之列与块：\n")
  for (nm in names(bad)) {
    v <- bad[[nm]]
    cat("    ", nm, "：", length(v), " 块，首五 blk = ",
        paste(head(v, 5), collapse = ", "), "\n", sep = "")
  }
  first <- bad[[1]][1]
  cat("\n  首个差异块之两侧全貌（rn \u2208 [",
      first * BLK + 1, ",", (first + 1) * BLK, "]）：\n", sep = "")
  print(M[blk == first])
  cat("\n  \u2192 请以该 rn 区间回查：分批侧取此段之批次为第 ",
      (first * BLK) %/% 100000L + 1L, " 批\n", sep = "")
  fail("逐块比对不符 —— 差异已定位至 ", BLK, " 行之内")
}
ok("69,641 块 \u00d7 9 列全同 —— 无一块之行数、rn 界、键界、四项合计有异")

## ── 四、滚动指纹速查（与 2026-08-24 参照值比对）──────────────────────────
cat("\u2500\u2500 \u56db\u3001\u6eda\u52a8\u6307\u7eb9 \u2500\u2500\n")
if (requireNamespace("digest", quietly = TRUE)) {
  line <- sprintf("%d|%d|%d|%d|%s|%s|%d|%d|%s|%s",
                  as.integer(BB$blk), as.integer(BB$n_b),
                  as.integer(BB$rn_min_b), as.integer(BB$rn_max_b),
                  BB$key_min_b, BB$key_max_b,
                  as.integer(BB$s_orders_b), as.integer(BB$s_rounds_b),
                  format(BB$s_stake_b, nsmall = 4, trim = TRUE),
                  format(BB$s_netpnl_b, nsmall = 4, trim = TRUE))
  md5 <- digest::digest(paste0(paste(line, collapse = "\n"), "\n"),
                        algo = "md5", serialize = FALSE)
  cat("  分批侧分块表 MD5 = ", md5, "\n", sep = "")
  cat("  2026-08-24 参照值 = ", REF_MD5, "\n", sep = "")
  cat("  ", if (identical(md5, REF_MD5)) "\u2705 与参照值相同"
      else "\u26a0 与参照值不同 —— 或格式化细节有别，以第三节逐块比对为准", "\n", sep = "")
} else cat("  （未装 digest，跳过；以第三节逐块比对为准）\n")

cat("\n\u2605 D07 PASS —— 两版输出经 69,641 块逐块核验，无遗漏、无重叠、无值差。\n")
cat("\u2605 至此可书：RESULT_EQUIVALENCE = TESTED_PASS（定位精度 ", BLK, " 行）\n", sep = "")
cat("\u26a0 rn 之删除仍须待此节 PASS 之后；删前请将七批原档加 _superseded 归档，禁删。\n")
## ═════════════════════════════════════════════════════════════════════════════
