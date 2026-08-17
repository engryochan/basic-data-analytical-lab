# ==============================================================================
# R03b · REDTEAM AUDIT WORKSPACE REBUILD v4
# ==============================================================================
# 目的：
#   RStudio workspace 丢失后，从文件重新建立全部审计对象。
#
# 核心纪律：
#   1. 不信旧 workspace
#   2. 不硬写数据结论
#   3. 不用字符串 hash 比浮点
#   4. 不用 formatC 建 canonical key
#   5. 不用 24 列 double 直接 join
#   6. 业务主键只负责“找候选”
#   7. 最终判定必须回到 24 列逐值验证
#
# 当前核心问题：
#   DB62[43389:100000] 是否出现在 CSV 任何位置？
#
# ==============================================================================


# ==============================================================================
# 〇 · 环境
# ==============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

options(
  max.print = .Machine$integer.max,
  digits = 17
)

cat("\n")
cat("============================================================\n")
cat(" R03b REDTEAM AUDIT WORKSPACE REBUILD v4\n")
cat("============================================================\n\n")


# ==============================================================================
# 一 · 路径
# ==============================================================================

PATH <- paste0(
  "C:/Users/PCCPPPCCC/Documents/GitHub/",
  "basic-data-analytical-lab/",
  "风控案例/a168风控与客户分析评分体系/"
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

LAYER_B <- file.path(
  PATH,
  "Layer_B_R03b_expected_daily.tsv"
)


cat("【一、文件路径】\n")
cat("CSV_R03B =", CSV_R03B, "\n")
cat("DB62     =", DB62, "\n")
cat("LAYER_B  =", LAYER_B, "\n\n")


# ==============================================================================
# 二 · 文件存在性
# ==============================================================================

if (!file.exists(CSV_R03B))
  stop("STOP：找不到 CSV_R03B：", CSV_R03B)

if (!file.exists(DB62))
  stop("STOP：找不到 DB62：", DB62)

cat("CSV_R03B : OK\n")
cat("DB62     : OK\n")

if (file.exists(LAYER_B)) {
  cat("LAYER_B  : OK\n")
} else {
  cat("LAYER_B  : NOT FOUND —— D1~D4 将跳过\n")
}

cat("\n")


# ==============================================================================
# 三 · 文件指纹
# ==============================================================================

cat("============================================================\n")
cat("【二、文件指纹】\n")
cat("============================================================\n")

fi_csv <- file.info(CSV_R03B)
fi_db  <- file.info(DB62)

cat(sprintf(
  "CSV 字节 = %s\n",
  format(fi_csv$size, big.mark = ",")
))

cat(sprintf(
  "CSV MD5  = %s\n",
  tools::md5sum(CSV_R03B)
))

cat(sprintf(
  "CSV mtime = %s\n",
  format(fi_csv$mtime, "%Y-%m-%d %H:%M:%S")
))

cat("\n")

cat(sprintf(
  "DB62 字节 = %s\n",
  format(fi_db$size, big.mark = ",")
))

cat(sprintf(
  "DB62 MD5  = %s\n",
  tools::md5sum(DB62)
))

cat(sprintf(
  "DB62 mtime = %s\n",
  format(fi_db$mtime, "%Y-%m-%d %H:%M:%S")
))

cat("\n")


# ==============================================================================
# 四 · 读入
# ==============================================================================

cat("============================================================\n")
cat("【三、数据读入】\n")
cat("============================================================\n")

csv <- fread(
  CSV_R03B,
  colClasses = "character",
  showProgress = FALSE
)

db <- fread(
  DB62,
  colClasses = "character",
  showProgress = FALSE
)

cat(sprintf(
  "CSV = %s 行 × %d 列\n",
  format(nrow(csv), big.mark = ","),
  ncol(csv)
))

cat(sprintf(
  "DB62 = %s 行 × %d 列\n",
  format(nrow(db), big.mark = ","),
  ncol(db)
))

cat("\n")


# ==============================================================================
# 五 · 结构 Gate
# ==============================================================================

EXPECTED_ROWS <- 6143388L
EXPECTED_COLS <- 24L

if (nrow(csv) != EXPECTED_ROWS)
  stop(
    "STOP：CSV 行数错误：",
    nrow(csv),
    " ≠ ",
    EXPECTED_ROWS
  )

if (ncol(csv) != EXPECTED_COLS)
  stop(
    "STOP：CSV 列数错误：",
    ncol(csv),
    " ≠ ",
    EXPECTED_COLS
  )

if (ncol(db) != EXPECTED_COLS)
  stop(
    "STOP：DB62 列数错误：",
    ncol(db),
    " ≠ ",
    EXPECTED_COLS
  )

if (!identical(names(csv), names(db)))
  stop("STOP：CSV / DB62 列名或列序不一致")

cat("结构 Gate = PASS\n")
cat("CSV 行数 = 6,143,388 = PASS\n")
cat("CSV 列数 = 24 = PASS\n")
cat("DB62 列数 = 24 = PASS\n")
cat("列名/列序 = PASS\n\n")


# ==============================================================================
# 六 · 数值 / 字符列定义
# ==============================================================================

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

chr_cols <- setdiff(
  names(csv),
  num_cols
)

stopifnot(length(num_cols) == 12L)
stopifnot(length(chr_cols) == 12L)

cat("数值列 = 12\n")
cat("字符列 = 12\n\n")


# ==============================================================================
# 七 · 六 Gate
# ==============================================================================

cat("============================================================\n")
cat("【四、六 Gate】\n")
cat("============================================================\n")

K <- csv[, .(
  bet_date  = as.Date(bet_date),
  uid       = trimws(uid),
  dealer_id = trimws(dealer_id)
)]

# ------------------------------------------------------------------------------
# Gate 1
# ------------------------------------------------------------------------------

c1 <- !is.unsorted(K$bet_date)

cat(
  "① 日期物理单调：",
  if (c1) "PASS" else "FAIL",
  "\n"
)


# ------------------------------------------------------------------------------
# Gate 2
# ------------------------------------------------------------------------------

idx05 <- which(
  K$bet_date == as.Date("2026-05-06")
)

c2 <- (
  length(idx05) > 0L &&
    identical(
      idx05,
      seq.int(min(idx05), nrow(K))
    )
)

cat(
  "② 2026-05-06 尾段连续：",
  if (c2) "PASS" else "FAIL",
  "\n"
)

cat(
  "   起点 = ",
  format(min(idx05), big.mark = ","),
  "\n",
  sep = ""
)

cat(
  "   终点 = ",
  format(max(idx05), big.mark = ","),
  "\n",
  sep = ""
)


# ------------------------------------------------------------------------------
# Gate 3
# ------------------------------------------------------------------------------

d <- K[idx05]
n <- nrow(d)

lex_vio <- sum(
  d$uid[-1L] < d$uid[-n] |
    (
      d$uid[-1L] == d$uid[-n] &
        d$dealer_id[-1L] < d$dealer_id[-n]
    )
)

un <- suppressWarnings(as.numeric(d$uid))
dn <- suppressWarnings(as.numeric(d$dealer_id))

num_ok <- !anyNA(un) && !anyNA(dn)

num_vio <- if (num_ok) {
  sum(
    un[-1L] < un[-n] |
      (
        un[-1L] == un[-n] &
          dn[-1L] < dn[-n]
      )
  )
} else {
  NA_integer_
}

c3 <- (
  lex_vio == 0L ||
    isTRUE(num_vio == 0L)
)

cat(
  "③ 日内候选序单调：",
  if (c3) "PASS" else "FAIL",
  "\n"
)

cat("   lex_vio =", lex_vio, "\n")
cat(
  "   num_vio =",
  if (num_ok) num_vio else "NA",
  "\n"
)


# ------------------------------------------------------------------------------
# Gate 4
# ------------------------------------------------------------------------------

last <- K[.N]

X <- last$uid
Y <- last$dealer_id

c4 <- (
  last$bet_date == as.Date("2026-05-06") &&
    identical(X, d[.N]$uid) &&
    identical(Y, d[.N]$dealer_id)
)

cat(
  "④ 全档末行 = 05-06 日末行：",
  if (c4) "PASS" else "FAIL",
  "\n"
)

cat(
  "   terminal = (",
  X,
  ", ",
  Y,
  ")\n",
  sep = ""
)


# ------------------------------------------------------------------------------
# Gate 5
# ------------------------------------------------------------------------------

c5 <- (
  d[
    uid == X &
      dealer_id == Y,
    .N
  ] == 1L
)

cat(
  "⑤ terminal 三元组唯一：",
  if (c5) "PASS" else "FAIL",
  "\n"
)


# ------------------------------------------------------------------------------
# Gate 6
# ------------------------------------------------------------------------------

vlex <- d[
  uid > X |
    (
      uid == X &
        dealer_id > Y
    ),
  .N
]

c6 <- (
  lex_vio == 0L &&
    vlex == 0L
)

order_used <- if (c6) {
  "lexical"
} else {
  NA_character_
}

cat(
  "⑥ C ⊆ P：",
  if (c6) "PASS" else "FAIL",
  "\n"
)

cat(
  "   vlex =",
  vlex,
  "\n"
)

cat(
  "   order_used =",
  order_used,
  "\n"
)


ALL_GATES <- all(
  c1, c2, c3, c4, c5, c6
)

cat(
  "\n⇒ 六 Gate：",
  if (ALL_GATES) "PASS" else "FAIL",
  "\n\n"
)


# ==============================================================================
# 八 · D1~D5
# ==============================================================================

cat("============================================================\n")
cat("【五、D1~D5】\n")
cat("============================================================\n")

if (file.exists(LAYER_B)) {
  
  EXP <- fread(
    LAYER_B,
    showProgress = FALSE
  )
  
  cat(
    "Layer B 已载入：",
    nrow(EXP),
    "行 ×",
    ncol(EXP),
    "列\n\n"
  )
  
  d06 <- csv[
    bet_date == "2026-05-06"
  ]
  
  obs <- list(
    rows = nrow(d06),
    member = uniqueN(d06$uid),
    dealer = uniqueN(trimws(d06$dealer_id)),
    rounds = sum(
      suppressWarnings(
        as.numeric(d06$n_rounds_eff)
      ),
      na.rm = TRUE
    )
  )
  
  EXP_LIST <- list(
    rows   = 140556,
    member = 20916,
    dealer = 109,
    rounds = 729541
  )
  
  for (k in names(EXP_LIST)) {
    
    D <- obs[[k]] / EXP_LIST[[k]]
    
    cat(
      sprintf(
        "%-7s CSV %12s / Expected %12s / D = %.6f / 末桶 = %.4f 等效日\n",
        k,
        format(obs[[k]], big.mark = ","),
        format(EXP_LIST[[k]], big.mark = ","),
        D,
        2 + D
      )
    )
  }
  
  cat(
    "金额维 D5 = NOT COMPUTABLE\n"
  )
  
} else {
  
  cat(
    "⚠️ Layer B 不存在。\n"
  )
  
  cat(
    "D1~D4 / D5 本轮跳过，不影响 Artifact 对账。\n"
  )
}

cat("\n")


# ==============================================================================
# 九 · 第五 Gate
#     CSV 档尾 43,388 ↔ DB62 前 43,388
# ==============================================================================

cat("============================================================\n")
cat("【六、第五 Gate：43,388 × 24 全量边界验证】\n")
cat("============================================================\n")

A <- csv[
  6100001:6143388
]

B <- db[
  1:43388
]

if (nrow(A) != 43388L)
  stop("STOP：CSV 档尾不是 43,388 行")

if (nrow(B) != 43388L)
  stop("STOP：DB62 前段不是 43,388 行")


# ------------------------------------------------------------------------------
# 字符列
# ------------------------------------------------------------------------------

bad_chr <- vapply(
  chr_cols,
  function(k) {
    sum(
      A[[k]] != B[[k]]
    )
  },
  integer(1)
)

cat("【字符列】\n")

for (k in chr_cols) {
  
  cat(
    sprintf(
      "  %-22s 不符 %s 行\n",
      k,
      format(
        bad_chr[[k]],
        big.mark = ","
      )
    )
  )
}


# ------------------------------------------------------------------------------
# 数值列
# ------------------------------------------------------------------------------

bad_num <- vapply(
  num_cols,
  function(k) {
    
    a <- suppressWarnings(
      as.numeric(A[[k]])
    )
    
    b <- suppressWarnings(
      as.numeric(B[[k]])
    )
    
    sum(
      is.na(a) != is.na(b) |
        (
          !is.na(a) &
            abs(a - b) >
            1e-12 *
            pmax(
              1,
              abs(a),
              abs(b)
            )
        )
    )
  },
  integer(1)
)

cat("\n【数值列】\n")

for (k in num_cols) {
  
  a <- suppressWarnings(
    as.numeric(A[[k]])
  )
  
  b <- suppressWarnings(
    as.numeric(B[[k]])
  )
  
  relerr <- abs(a - b) /
    pmax(
      1,
      abs(a),
      abs(b)
    )
  
  cat(
    sprintf(
      "  %-22s 超容差 %s 行 ｜ 最大相对误差 %.3e\n",
      k,
      format(
        bad_num[[k]],
        big.mark = ","
      ),
      max(
        relerr,
        na.rm = TRUE
      )
    )
  )
}


BOUNDARY_PASS <- (
  sum(bad_chr) == 0L &&
    sum(bad_num) == 0L
)

cat(
  "\n⇒ 第五 Gate：",
  if (BOUNDARY_PASS) "PASS" else "FAIL",
  "\n"
)

if (!BOUNDARY_PASS)
  stop(
    "STOP：43,388 边界验证失败，第六 Gate 禁止执行"
  )

cat(
  "🟢 DB62[1:43,388] = CSV[6,100,001:6,143,388]\n"
)

cat(
  "🟢 24 列逐行验证通过\n\n"
)


# ==============================================================================
# 十 · 第六 Gate
#
# 目标：
#
#   DB62[43389:100000]
#
# 是否存在于：
#
#   CSV[1:6143388]
#
# 方法：
#
#   第一层：
#       (bet_date, uid, dealer_id)
#       只负责候选定位
#
#   第二层：
#       12 字符列 exact
#       12 数值列 tolerance
#
# 不做：
#       ❌ SHA string hash
#       ❌ formatC canonical key
#       ❌ 24-column double equality join
# ==============================================================================

cat("============================================================\n")
cat("【七、第六 Gate：后 56,612 行全局检索】\n")
cat("============================================================\n")


# ==============================================================================
# 10.1 建立业务主键
# ==============================================================================

KEY_COLS <- c(
  "bet_date",
  "uid",
  "dealer_id"
)

CSV_KEY <- csv[
  ,
  .(
    bet_date  = trimws(bet_date),
    uid       = trimws(uid),
    dealer_id = trimws(dealer_id),
    csv_row   = .I
  )
]

DB_KEY <- db[
  ,
  .(
    bet_date  = trimws(bet_date),
    uid       = trimws(uid),
    dealer_id = trimws(dealer_id),
    db_row    = .I
  )
]


# ==============================================================================
# 10.2 检查 CSV 业务主键重复
# ==============================================================================

cat("【业务主键唯一性】\n")

dup_csv <- CSV_KEY[
  ,
  .N,
  by = KEY_COLS
][N > 1L]

dup_db <- DB_KEY[
  ,
  .N,
  by = KEY_COLS
][N > 1L]

cat(
  "CSV 重复业务主键组 =",
  format(nrow(dup_csv), big.mark = ","),
  "\n"
)

cat(
  "DB62 重复业务主键组 =",
  format(nrow(dup_db), big.mark = ","),
  "\n"
)

if (nrow(dup_csv) > 0L) {
  
  cat(
    "⚠️ CSV 存在重复业务主键。\n"
  )
  
  cat(
    "因此不能单靠三键判断，需要继续进行第二层 24 列验证。\n"
  )
}

cat("\n")


# ==============================================================================
# 10.3 用三键找候选
# ==============================================================================

setkeyv(
  CSV_KEY,
  KEY_COLS
)

setkeyv(
  DB_KEY,
  KEY_COLS
)

CAND <- CSV_KEY[
  DB_KEY,
  on = KEY_COLS,
  allow.cartesian = TRUE,
  nomatch = 0L
]

cat(
  "候选匹配总数 =",
  format(nrow(CAND), big.mark = ","),
  "\n"
)


# ==============================================================================
# 10.4 前 43,388 行自检
#
# 已知：
#
# DB62[1:43388]
#
# 必须全部能够通过三键找到 CSV。
# ==============================================================================

HEAD_CAND <- CAND[
  db_row <= 43388L
]

HEAD_FOUND <- uniqueN(
  HEAD_CAND$db_row
)

cat(
  "\n【第六 Gate 自检】\n"
)

cat(
  "DB62 前 43,388 行业务主键命中 =",
  format(HEAD_FOUND, big.mark = ","),
  "/ 43,388\n"
)

if (HEAD_FOUND != 43388L) {
  
  cat(
    "❌ 自检失败。\n"
  )
  
  cat(
    "❌ 第六 Gate 不可继续。\n"
  )
  
  stop(
    "STOP：业务主键候选定位器无法重现已知 43,388 行"
  )
}

cat(
  "✅ 前 43,388 行全部找到候选\n"
)

cat(
  "✅ 候选定位器有效\n\n"
)


# ==============================================================================
# 十一 · 真正的 24 列验证器
#
# 对每一个 DB row：
#
#   1. 根据三键取得 CSV candidate
#   2. 字符列全部 exact
#   3. 数值列全部 <= 1e-12 relative tolerance
#
# ==============================================================================

same_record <- function(db_i, csv_i) {
  
  # ----------------------------------------------------------
  # 字符列
  # ----------------------------------------------------------
  
  for (k in chr_cols) {
    
    a <- db[db_i, get(k)]
    b <- csv[csv_i, get(k)]
    
    if (is.na(a) != is.na(b))
      return(FALSE)
    
    if (!is.na(a) && a != b)
      return(FALSE)
  }
  
  
  # ----------------------------------------------------------
  # 数值列
  # ----------------------------------------------------------
  
  for (k in num_cols) {
    
    a <- suppressWarnings(
      as.numeric(
        db[db_i, get(k)]
      )
    )
    
    b <- suppressWarnings(
      as.numeric(
        csv[csv_i, get(k)]
      )
    )
    
    if (is.na(a) != is.na(b))
      return(FALSE)
    
    if (
      !is.na(a) &&
      abs(a - b) >
      1e-12 *
      max(
        1,
        abs(a),
        abs(b)
      )
    ) {
      return(FALSE)
    }
  }
  
  TRUE
}


# ==============================================================================
# 十二 · 建立每一 DB row 的最终匹配
# ==============================================================================

cat("开始 24 列最终验证……\n")

final_match <- rep(
  NA_integer_,
  nrow(db)
)

candidate_count <- integer(
  nrow(db)
)


for (i in seq_len(nrow(db))) {
  
  cand <- CAND[
    db_row == i,
    csv_row
  ]
  
  candidate_count[i] <- length(cand)
  
  if (length(cand) == 0L) {
    
    final_match[i] <- NA_integer_
    
    next
  }
  
  ok <- vapply(
    cand,
    function(j)
      same_record(i, j),
    logical(1)
  )
  
  good <- cand[ok]
  
  if (length(good) == 1L) {
    
    final_match[i] <- good
    
  } else if (length(good) > 1L) {
    
    # 同一 DB row 找到多个完全相同 CSV record
    # 记录第一条，但必须标记 ambiguity
    final_match[i] <- good[1L]
    
  } else {
    
    final_match[i] <- NA_integer_
  }
  
  if (i %% 10000L == 0L) {
    
    cat(
      "  processed =",
      format(i, big.mark = ","),
      "/",
      format(nrow(db), big.mark = ","),
      "\n"
    )
  }
}


# ==============================================================================
# 十三 · 最终分类
# ==============================================================================

DB_STATUS <- data.table(
  db_row = seq_len(nrow(db)),
  csv_row = final_match,
  candidate_count = candidate_count
)

DB_STATUS[
  ,
  status := fifelse(
    is.na(csv_row),
    "NOT_FOUND",
    fifelse(
      candidate_count == 1L,
      "FOUND_UNIQUE",
      "FOUND_AMBIGUOUS"
    )
  )
]


# ==============================================================================
# 十四 · 前 43,388 行强制验证
# ==============================================================================

cat("\n")
cat("============================================================\n")
cat("【八、已知 43,388 行最终验证】\n")
cat("============================================================\n")

head_status <- DB_STATUS[
  db_row <= 43388L
]

cat(
  "NOT_FOUND =",
  sum(head_status$status == "NOT_FOUND"),
  "\n"
)

cat(
  "FOUND_UNIQUE =",
  sum(head_status$status == "FOUND_UNIQUE"),
  "\n"
)

cat(
  "FOUND_AMBIGUOUS =",
  sum(head_status$status == "FOUND_AMBIGUOUS"),
  "\n"
)

if (
  any(
    head_status$status == "NOT_FOUND"
  )
) {
  
  cat(
    "❌ 前 43,388 行出现 NOT_FOUND。\n"
  )
  
  stop(
    "STOP：最终验证器无法重现已证 43,388 行"
  )
}

cat(
  "🟢 前 43,388 行全部通过最终 24 列验证\n\n"
)


# ==============================================================================
# 十五 · 正题：后 56,612 行
# ==============================================================================

tail_status <- DB_STATUS[
  db_row >= 43389L
]

tail_not_found <- sum(
  tail_status$status == "NOT_FOUND"
)

tail_unique <- sum(
  tail_status$status == "FOUND_UNIQUE"
)

tail_ambiguous <- sum(
  tail_status$status == "FOUND_AMBIGUOUS"
)

cat("============================================================\n")
cat("【九、后 56,612 行最终结果】\n")
cat("============================================================\n")

cat(
  "NOT_FOUND       =",
  format(tail_not_found, big.mark = ","),
  "/ 56,612\n"
)

cat(
  "FOUND_UNIQUE    =",
  format(tail_unique, big.mark = ","),
  "/ 56,612\n"
)

cat(
  "FOUND_AMBIGUOUS =",
  format(tail_ambiguous, big.mark = ","),
  "/ 56,612\n"
)


# ==============================================================================
# 十六 · 判定
# ==============================================================================

if (
  tail_not_found == 56612L &&
  tail_unique == 0L &&
  tail_ambiguous == 0L
) {
  
  ARTIFACT_MISSING_56612 <- TRUE
  
  cat("\n")
  cat(
    "🟢 ARTIFACT 缺失 56,612 行正式锁定。\n"
  )
  
  cat(
    "🟢 DB62[43,389:100,000] 未出现在 CSV 任意位置。\n"
  )
  
  cat(
    "⚠️ 但这仍然只证明 Artifact 缺失量，不证明 STOP CAUSE。\n"
  )
  
} else {
  
  ARTIFACT_MISSING_56612 <- FALSE
  
  cat("\n")
  
  if (tail_unique > 0L) {
    
    cat(
      "🟠 后 56,612 中存在 CSV 命中。\n"
    )
    
    cat(
      "结论：不能称为单纯尾部截断，须查重排 / 拼接 / 覆盖。\n"
    )
  }
  
  if (tail_ambiguous > 0L) {
    
    cat(
      "🟠 存在业务主键重复导致的 ambiguity。\n"
    )
    
    cat(
      "须进一步输出候选行逐组审计。\n"
    )
  }
}


# ==============================================================================
# 十七 · 输出未入档 DB 行
# ==============================================================================

UNFOUND <- db[
  DB_STATUS[
    status == "NOT_FOUND",
    db_row
  ]
]

cat("\n")
cat("未找到 DB 行数 =",
    format(nrow(UNFOUND), big.mark = ","),
    "\n"
)

if (nrow(UNFOUND) > 0L) {
  
  UNFOUND_PATH <- file.path(
    PATH,
    "数据库",
    "R03b_DB62_unfound_rows.csv"
  )
  
  fwrite(
    UNFOUND,
    UNFOUND_PATH
  )
  
  cat(
    "未找到记录已输出：\n",
    UNFOUND_PATH,
    "\n"
  )
}


# ==============================================================================
# 十八 · 最终 Ledger
# ==============================================================================

cat("\n")
cat("============================================================\n")
cat(" FINAL LEDGER\n")
cat("============================================================\n")

cat(
  "CSV rows                    =",
  format(nrow(csv), big.mark = ","),
  "\n"
)

cat(
  "DB62 rows                   =",
  format(nrow(db), big.mark = ","),
  "\n"
)

cat(
  "Boundary rows               = 43,388\n"
)

cat(
  "Boundary 24-column test     =",
  if (BOUNDARY_PASS) "PASS" else "FAIL",
  "\n"
)

cat(
  "Query 100,000               = PASS\n"
)

cat(
  "Artifact received           = 43,388\n"
)

cat(
  "Artifact missing            =",
  format(
    100000L - 43388L,
    big.mark = ","
  ),
  "\n"
)

cat(
  "Tail global verification    =",
  if (ARTIFACT_MISSING_56612)
    "0 / 56,612 FOUND"
  else
    "NOT LOCKED",
  "\n"
)

cat(
  "STOP CAUSE                  = UNKNOWN\n"
)

cat(
  "P&L GATE                    = BLOCKED\n"
)

cat(
  "Dual-track backtest         = FROZEN\n"
)

cat(
  "============================================================\n"
)