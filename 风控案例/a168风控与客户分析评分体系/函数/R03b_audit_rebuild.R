# ==============================================================================
# R03b · 审计工作区重建 · 一次跑完
# ------------------------------------------------------------------------------
# 用途：RStudio 工作区丢失后，重建全部已锁定量并续跑未完之刀。
# 纪律：
#   · 一切数字现算，不硬写既有结论
#   · 每段自带可证伪点，验证器失效即当场停（SC-002/007/016/017 之教训）
#   · 数值列不以字符串比对（SC-016）；不以 formatC 建 key（SC-017）
# ==============================================================================

suppressPackageStartupMessages(library(data.table))
op <- options(max.print = .Machine$integer.max, digits = 17)
on.exit(options(op), add = TRUE)

## ══ 〇 · 路径（请按实际改这一行）══════════════════════════════════════════
PATH     <- "C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/"
CSV_R03B <- paste0(PATH, "数据库/R03b_player_dealer_daily.csv")
DB62     <- paste0(PATH, "数据库/R03b_v3_offset_6100000_43388.csv")   # 实为 100,000 行
LAYER_B  <- paste0(PATH, "Layer_B_R03b_expected_daily.tsv")

for (f in c(CSV_R03B, DB62)) if (!file.exists(f)) stop("缺档：", f)
cat("══ 〇 路径就绪 ══\n\n")

## ══ 一 · 受审件六元组（存证，非判定）═════════════════════════════════════
fi <- file.info(CSV_R03B)
cat("══ 一 · 受审件六元组 ══\n")
cat(sprintf("  字节 %s ｜ MD5 %s ｜ mtime %s\n",
            format(fi$size, big.mark = ","), tools::md5sum(CSV_R03B),
            format(fi$mtime, "%Y-%m-%d %H:%M")))

## ══ 二 · 读入（全 24 列字符，免类型/精度污染）═════════════════════════════
cat("\n══ 二 · 读入 ══\n")
csv <- fread(CSV_R03B, colClasses = "character", showProgress = FALSE)
db  <- fread(DB62,     colClasses = "character", showProgress = FALSE)
cat(sprintf("  CSV %s 行 × %d 列 ｜ DB62 %s 行 × %d 列\n",
            format(nrow(csv), big.mark = ","), ncol(csv),
            format(nrow(db),  big.mark = ","), ncol(db)))
stopifnot(identical(names(csv), names(db)))          # 列名与列序须同

ANCHOR_ROWS <- 6143388L
if (nrow(csv) != ANCHOR_ROWS)
  stop("CSV 行数 ", nrow(csv), " ≠ 锚点 ", ANCHOR_ROWS, " —— 此件非受审对象，停")
cat("  ✅ 行数命中锚点 6,143,388\n")

num_cols <- c("stake_amount","profit_amount","net_pnl","win_rate",
              "n_related_orders","n_rounds_eff","p_base_mix_w","p_base_mix_unw",
              "z_score_w","z_score_unw","z_score","delta_p")
chr_cols <- setdiff(names(csv), num_cols)
stopifnot(length(num_cols) == 12L, length(chr_cols) == 12L)

## ══ 三 · 六 Gate（cursor-prefix test · CSV 侧）════════════════════════════
cat("\n══ 三 · 六 Gate ══\n")
K <- csv[, .(bet_date = as.Date(bet_date), uid = trimws(uid), dealer_id = trimws(dealer_id))]

c1 <- !is.unsorted(K$bet_date)
idx05 <- which(K$bet_date == as.Date("2026-05-06"))
c2 <- length(idx05) > 0L && identical(idx05, seq.int(min(idx05), nrow(K)))
d <- K[idx05]; n <- nrow(d)
lex_vio <- sum(d$uid[-1L] < d$uid[-n] | (d$uid[-1L] == d$uid[-n] & d$dealer_id[-1L] < d$dealer_id[-n]))
un <- suppressWarnings(as.numeric(d$uid)); dn <- suppressWarnings(as.numeric(d$dealer_id))
num_ok <- !anyNA(un) && !anyNA(dn)
num_vio <- if (num_ok) sum(un[-1L] < un[-n] | (un[-1L] == un[-n] & dn[-1L] < dn[-n])) else NA_integer_
c3 <- (lex_vio == 0L) || isTRUE(num_vio == 0L)
last <- K[.N]; X <- last$uid; Y <- last$dealer_id
c4 <- last$bet_date == as.Date("2026-05-06") &&
      identical(X, d[.N]$uid) && identical(Y, d[.N]$dealer_id)
c5 <- d[uid == X & dealer_id == Y, .N] == 1L
vlex <- d[uid > X | (uid == X & dealer_id > Y), .N]
c6 <- (lex_vio == 0L) && (vlex == 0L)
order_used <- if (lex_vio == 0L && vlex == 0L) "lexical" else NA_character_

cat(sprintf("  ① 日期物理单调      %s\n", if (c1) "PASS" else "FAIL"))
cat(sprintf("  ② 05-06 尾段连续    %s ｜ 第 %s ~ %s 行\n", if (c2) "PASS" else "FAIL",
            format(min(idx05), big.mark=","), format(max(idx05), big.mark=",")))
cat(sprintf("  ③ 日内候选序单调    %s ｜ lex_vio=%d ｜ num_vio=%s\n", if (c3) "PASS" else "FAIL",
            lex_vio, if (num_ok) as.character(num_vio) else "不可比"))
cat(sprintf("  ④ 全档末行=日末行   %s ｜ 切点 (2026-05-06, %s, %s)\n", if (c4) "PASS" else "FAIL", X, Y))
cat(sprintf("  ⑤ 切点三元组唯一    %s\n", if (c5) "PASS" else "FAIL"))
cat(sprintf("  ⑥ C ⊆ P            %s ｜ vio_lex=%d ｜ order_used=%s\n", if (c6) "PASS" else "FAIL",
            vlex, order_used))
cat(sprintf("  ⇒ 六 Gate %s\n", if (all(c1,c2,c3,c4,c5,c6)) "PASS" else "FAIL"))

## ══ 四 · D1~D4（末桶等效日，按维分列）═══════════════════════════════════
cat("\n══ 四 · D1~D4 ══\n")
EXP <- list(rows = 140556, member = 20916, dealer = 109, rounds = 729541)   # Layer B · 2026-05-06
d06 <- csv[bet_date == "2026-05-06"]
obs <- list(rows   = nrow(d06),
            member = uniqueN(d06$uid),
            dealer = uniqueN(trimws(d06$dealer_id)),
            rounds = sum(as.numeric(d06$n_rounds_eff)))
for (k in names(EXP))
  cat(sprintf("  %-7s CSV %12s ／ Expected %12s → D = %.6f → 末桶 %.4f 等效日\n", k,
              format(obs[[k]], big.mark=","), format(EXP[[k]], big.mark=","),
              obs[[k]]/EXP[[k]], 2 + obs[[k]]/EXP[[k]]))
cat("  ⚠️ 金额维 D5 = NOT COMPUTABLE（Layer B 无同口径 Expected 分母）\n")

## ══ 五 · 边界比对：CSV 档尾 43,388 ↔ DB62 前 43,388 ═══════════════════════
cat("\n══ 五 · 边界比对 ══\n")
A <- csv[6100001:6143388]; B <- db[1:43388]
bad_chr <- vapply(chr_cols, function(k) sum(A[[k]] != B[[k]]), integer(1))
rel <- function(a, b) max(abs(a-b)/pmax(1, abs(a), abs(b)), na.rm = TRUE)
bad_num <- vapply(num_cols, function(k) {
  a <- as.numeric(A[[k]]); b <- as.numeric(B[[k]])
  sum(is.na(a) != is.na(b) | (!is.na(a) & abs(a-b) > 1e-12*pmax(1,abs(a),abs(b))))
}, integer(1))
max_rel <- vapply(num_cols, function(k) rel(as.numeric(A[[k]]), as.numeric(B[[k]])), numeric(1))
cat(sprintf("  字符列不符合计 %d ／ 12 列 × 43,388 行\n", sum(bad_chr)))
cat(sprintf("  数值列超容差合计 %d ｜ 最大相对误差 %.3e\n", sum(bad_num), max(max_rel)))
cat(sprintf("  ⇒ CSV 档尾 = DB62 前 43,388 行（容差意义下）: %s\n",
            sum(bad_chr) == 0 && sum(bad_num) == 0))

## ══ 六 · 后 56,612 行之全局检索（改数值 join，不建字符串 key）══════════════
##   SC-017：formatC 建 key 在整数列与零值上失稳，自检仅 41,146/43,388。
##   今改：数值列 as.numeric 后交由 data.table 按 double 比对，不经字符串。
cat("\n══ 六 · 后 56,612 行全局检索 ══\n")
tonum <- function(DT) {
  out <- copy(DT)
  for (k in num_cols) set(out, j = k, value = as.numeric(out[[k]]))
  out
}
CN <- tonum(csv); DN <- tonum(db)
setkeyv(CN, names(CN))

hit_of <- function(rows) {
  q <- DN[rows]
  nrow(unique(CN[q, nomatch = 0L, on = names(CN)]))
}

## ★ 可证伪点：前 43,388 行已知全同，此处必须全命中；否则本节作废
head_hit <- hit_of(1:43388)
cat(sprintf("  【自检】前 43,388 行命中 = %s / 43,388  %s\n",
            format(head_hit, big.mark=","),
            if (head_hit == 43388L) "✅ 比对法有效" else "❌ 比对法失效，下方作废"))
if (head_hit != 43388L) {
  cat("  ⚠️ 自检未过，后段结果不予采信。停。\n")
} else {
  tail_hit <- hit_of(43389:100000)
  cat(sprintf("\n  【正题】后 56,612 行命中 = %s / 56,612\n", format(tail_hit, big.mark=",")))
  cat(sprintf("  ⇒ %s\n", if (tail_hit == 0L)
    "该批后 56,612 行未进入本 Artifact 任何位置 —— Artifact 缺失 56,612 行" else
    "存在命中 → 非单纯截断，须查重排／拼接"))
}

cat("\n══ 完 ══\n")
cat("措辞边界：以上只证 Artifact 缺失量，不证其因。\n")
cat("九种可能（浏览器中断／导出器截断／接收器只写部分／内存中断／合并截断／\n")
cat("人工中止／文件被覆盖／多轮拼接只留部分／临时档 rename 未完）皆未排除。\n")
