# ==============================================================================
# R03b · REDTEAM 审计工作区恢复版
# ==============================================================================
# 目的：
#   1. 完全脱离 RStudio workspace
#   2. 重新建立 CSV_R03B / DB62
#   3. 重现已锁定的 43,388 行边界证据
#   4. 使用向量化三键定位 + 24 列语义比较
#   5. 完成 DB62 后 56,612 行的全局检索
#
# 红线：
#   · 不使用字符串 hash 判断数值相等
#   · 不使用 formatC 建 canonical key
#   · 不使用逐 DB 行 × 24 列循环
#   · 自检失败立即 STOP
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

options(
  max.print = .Machine$integer.max,
  digits = 17
)

# ══════════════════════════════════════════════════════════════════════════════
# 〇 · 路径恢复
# ══════════════════════════════════════════════════════════════════════════════

PATH <- paste0(
  "C:/Users/PCCPPPCCC/Documents/GitHub/",
  "basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/"
)

CSV_R03B <- file.path(
  PATH,
  "数据库",
  "R03b_player_dealer_daily.csv"
)

DB62 <- file.path(
  PATH,
  "数据库",
  "R03b_v3_offset_6100000_43388.csv"
)

cat("══════════════════════════════════════════════════════\n")
cat("R03b REDTEAM · WORKSPACE RECOVERY\n")
cat("══════════════════════════════════════════════════════\n\n")

cat("CSV_R03B:\n", CSV_R03B, "\n\n")
cat("DB62:\n", DB62, "\n\n")

if (!file.exists(CSV_R03B)) {
  stop(
    "\nSTOP：找不到 CSV_R03B：\n",
    CSV_R03B,
    "\n\n请先确认该文件实际存在，不得用猜测路径继续。"
  )
}

if (!file.exists(DB62)) {
  stop(
    "\nSTOP：找不到 DB62：\n",
    DB62
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# 一 · 文件完整性重新取证
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 一 · 文件指纹 ════════\n")

fi_csv <- file.info(CSV_R03B)
fi_db  <- file.info(DB62)

cat(
  "CSV bytes =",
  format(fi_csv$size, big.mark = ","),
  "\n"
)

cat(
  "CSV mtime =",
  format(fi_csv$mtime, "%Y-%m-%d %H:%M:%S"),
  "\n"
)

cat(
  "CSV MD5   =",
  tools::md5sum(CSV_R03B),
  "\n\n"
)

cat(
  "DB62 bytes =",
  format(fi_db$size, big.mark = ","),
  "\n"
)

cat(
  "DB62 mtime =",
  format(fi_db$mtime, "%Y-%m-%d %H:%M:%S"),
  "\n"
)

cat(
  "DB62 MD5   =",
  tools::md5sum(DB62),
  "\n"
)

# ══════════════════════════════════════════════════════════════════════════════
# 二 · 读取
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 二 · 数据读取 ════════\n")

csv <- fread(
  CSV_R03B,
  colClasses = "character",
  showProgress = TRUE
)

db <- fread(
  DB62,
  colClasses = "character",
  showProgress = TRUE
)

cat(
  sprintf(
    "CSV = %s 行 × %d 列\n",
    format(nrow(csv), big.mark = ","),
    ncol(csv)
  )
)

cat(
  sprintf(
    "DB62 = %s 行 × %d 列\n",
    format(nrow(db), big.mark = ","),
    ncol(db)
  )
)

# 硬锚点
stopifnot(nrow(csv) == 6143388L)
stopifnot(nrow(db) == 100000L)
stopifnot(ncol(csv) == 24L)
stopifnot(ncol(db) == 24L)
stopifnot(identical(names(csv), names(db)))

cat("✅ 行数、列数、列名、列序全部通过\n")

# ══════════════════════════════════════════════════════════════════════════════
# 三 · 24 列分类
# ══════════════════════════════════════════════════════════════════════════════

num_cols <- c(
  "stake_amount",
  "profit_amount",
  "net_pnl",
  "win_rate",
  "n_related_orders",
  "n_rounds_eff",
  "p_base_mix_w",
  "p_base_mix_unw",
  "z_score_w",
  "z_score_unw",
  "z_score",
  "delta_p"
)

chr_cols <- setdiff(names(csv), num_cols)

stopifnot(length(num_cols) == 12L)
stopifnot(length(chr_cols) == 12L)

cat("\n数值列 = 12\n")
cat("字符列 = 12\n")

# ══════════════════════════════════════════════════════════════════════════════
# 四 · 重新证实 05-06 尾段结构
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 四 · 05-06 尾段 Gate ════════\n")

K <- csv[, .(
  bet_date  = trimws(bet_date),
  uid       = trimws(uid),
  dealer_id = trimws(dealer_id)
)]

K[, row_id := .I]

idx05 <- which(K$bet_date == "2026-05-06")

cat(
  "05-06 起始行 =",
  format(min(idx05), big.mark = ","),
  "\n"
)

cat(
  "05-06 结束行 =",
  format(max(idx05), big.mark = ","),
  "\n"
)

cat(
  "05-06 行数 =",
  format(length(idx05), big.mark = ","),
  "\n"
)

c1 <- !is.unsorted(as.IDate(K$bet_date))

c2 <- identical(
  idx05,
  seq.int(min(idx05), nrow(K))
)

d <- K[idx05]

lex_vio <- sum(
  d$uid[-1L] < d$uid[-nrow(d)] |
    (
      d$uid[-1L] == d$uid[-nrow(d)] &
        d$dealer_id[-1L] < d$dealer_id[-nrow(d)]
    )
)

c3 <- lex_vio == 0L

last <- K[.N]

c4 <-
  last$bet_date == "2026-05-06" &&
  last$uid == d[.N]$uid &&
  last$dealer_id == d[.N]$dealer_id

c5 <- d[
  uid == last$uid &
    dealer_id == last$dealer_id,
  .N
] == 1L

vlex <- d[
  uid > last$uid |
    (
      uid == last$uid &
        dealer_id > last$dealer_id
    ),
  .N
]

c6 <- lex_vio == 0L && vlex == 0L

cat("① 日期单调 =", c1, "\n")
cat("② 05-06 尾段连续 =", c2, "\n")
cat("③ 日内字典序 =", c3, " | violations =", lex_vio, "\n")
cat("④ 全档末行 =", c4, "\n")
cat("⑤ 切点唯一 =", c5, "\n")
cat("⑥ C ⊆ P =", c6, "\n")

cat(
  "\n六 Gate =",
  if (all(c1, c2, c3, c4, c5, c6))
    "PASS"
  else
    "FAIL",
  "\n"
)

# ══════════════════════════════════════════════════════════════════════════════
# 五 · 43,388 边界全列验证
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 五 · 43,388 边界验证 ════════\n")

A <- csv[6100001:6143388]
B <- db[1:43388]

# ---- 字符列
bad_chr <- vapply(
  chr_cols,
  function(k) {
    a <- A[[k]]
    b <- B[[k]]
    
    sum(
      xor(is.na(a), is.na(b)) |
        (!is.na(a) & a != b)
    )
  },
  integer(1)
)

# ---- 数值列
bad_num <- vapply(
  num_cols,
  function(k) {
    
    a <- suppressWarnings(as.numeric(A[[k]]))
    b <- suppressWarnings(as.numeric(B[[k]]))
    
    sum(
      xor(is.na(a), is.na(b)) |
        (
          !is.na(a) &
            abs(a - b) >
            1e-12 * pmax(1, abs(a), abs(b))
        )
    )
  },
  integer(1)
)

max_rel <- vapply(
  num_cols,
  function(k) {
    
    a <- suppressWarnings(as.numeric(A[[k]]))
    b <- suppressWarnings(as.numeric(B[[k]]))
    
    z <- abs(a - b) /
      pmax(1, abs(a), abs(b))
    
    if (all(is.na(z))) 0 else max(z, na.rm = TRUE)
  },
  numeric(1)
)

cat(
  "字符列不符总数 =",
  sum(bad_chr),
  "\n"
)

cat(
  "数值列超容差总数 =",
  sum(bad_num),
  "\n"
)

cat(
  "最大相对误差 =",
  sprintf("%.3e", max(max_rel)),
  "\n"
)

BOUNDARY_OK <-
  sum(bad_chr) == 0L &&
  sum(bad_num) == 0L

cat(
  "43,388 行全列语义一致 =",
  BOUNDARY_OK,
  "\n"
)

if (!BOUNDARY_OK) {
  stop(
    "STOP：43,388 边界复核失败，第六 Gate 不得继续。"
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# 六 · 向量化三键定位
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 六 · 全局检索 ════════\n")

KEY <- c(
  "bet_date",
  "uid",
  "dealer_id"
)

CSVK <- csv[, .(
  bet_date  = trimws(bet_date),
  uid       = trimws(uid),
  dealer_id = trimws(dealer_id)
)]

CSVK[, csv_row := .I]

DBK <- db[, .(
  bet_date  = trimws(bet_date),
  uid       = trimws(uid),
  dealer_id = trimws(dealer_id)
)]

DBK[, db_row := .I]

cat("建立三键候选关系……\n")

CAND <- DBK[
  CSVK,
  on = KEY,
  allow.cartesian = TRUE,
  nomatch = 0L,
  .(
    db_row,
    csv_row = i.csv_row
  )
]

cat(
  "候选对数 =",
  format(nrow(CAND), big.mark = ","),
  "\n"
)

# ══════════════════════════════════════════════════════════════════════════════
# 七 · 24 列向量化语义比较
# ══════════════════════════════════════════════════════════════════════════════

cat("开始 24 列向量比较……\n")

ok <- rep(TRUE, nrow(CAND))

# ---- 12 字符列
for (k in chr_cols) {
  
  a <- csv[[k]][CAND$csv_row]
  b <- db [[k]][CAND$db_row]
  
  same <- xor(is.na(a), is.na(b)) == FALSE &
    (is.na(a) | a == b)
  
  ok <- ok & same
}

# ---- 12 数值列
for (k in num_cols) {
  
  a <- suppressWarnings(
    as.numeric(csv[[k]][CAND$csv_row])
  )
  
  b <- suppressWarnings(
    as.numeric(db[[k]][CAND$db_row])
  )
  
  same <-
    xor(is.na(a), is.na(b)) == FALSE &
    (
      is.na(a) |
        abs(a - b) <=
        1e-12 * pmax(1, abs(a), abs(b))
    )
  
  ok <- ok & same
}

CAND[, matched := ok]

# ══════════════════════════════════════════════════════════════════════════════
# 八 · 每一 DB 行匹配统计
# ══════════════════════════════════════════════════════════════════════════════

M <- CAND[
  matched == TRUE,
  .(
    n_match = .N
  ),
  by = db_row
]

RES <- data.table(
  db_row = seq_len(nrow(db))
)

RES[M, on = "db_row"]

RES[
  is.na(n_match),
  n_match := 0L
]

# ══════════════════════════════════════════════════════════════════════════════
# 九 · 自检 Gate
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 九 · 验证器自检 ════════\n")

head_ok <- RES[
  db_row <= 43388L,
  sum(n_match >= 1L)
]

cat(
  "前 43,388 行 FOUND =",
  format(head_ok, big.mark = ","),
  "/ 43,388\n"
)

if (head_ok != 43388L) {
  
  cat(
    "\n❌ STOP\n",
    "验证器无法重现已经由第五节证实的 43,388 行。\n",
    "因此后 56,612 行结果全部作废。\n"
  )
  
  stop("SC-020：向量化全局验证器自检失败")
}

cat("✅ 验证器自检通过\n")

# ══════════════════════════════════════════════════════════════════════════════
# 十 · 正题：后 56,612 行
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 十 · 后 56,612 行全局检索 ════════\n")

TAIL <- RES[
  db_row >= 43389L
]

NOT_FOUND <- TAIL[
  n_match == 0L,
  .N
]

FOUND_UNIQUE <- TAIL[
  n_match == 1L,
  .N
]

FOUND_MULTIPLE <- TAIL[
  n_match > 1L,
  .N
]

cat(
  "NOT_FOUND      =",
  format(NOT_FOUND, big.mark = ","),
  "\n"
)

cat(
  "FOUND_UNIQUE   =",
  format(FOUND_UNIQUE, big.mark = ","),
  "\n"
)

cat(
  "FOUND_MULTIPLE =",
  format(FOUND_MULTIPLE, big.mark = ","),
  "\n"
)

# ══════════════════════════════════════════════════════════════════════════════
# 十一 · 最终判定
# ══════════════════════════════════════════════════════════════════════════════

cat("\n════════ 十一 · 判定 ════════\n")

if (
  NOT_FOUND == 56612L &&
  FOUND_UNIQUE == 0L &&
  FOUND_MULTIPLE == 0L
) {
  
  cat(
    "🟢 DB62 后 56,612 行在整个 CSV 中均未发现。\n"
  )
  
  cat(
    "🟢 Artifact 缺失量 = 56,612 行。\n"
  )
  
  cat(
    "🔒 但 STOP CAUSE 仍 UNKNOWN。\n"
  )
  
} else {
  
  cat(
    "🟠 后 56,612 行并非全部缺失。\n"
  )
  
  cat(
    "🟠 存在重排、重复、拼接或其他 Artifact 行为的可能。\n"
  )
}

cat("\n════════ END ════════\n")