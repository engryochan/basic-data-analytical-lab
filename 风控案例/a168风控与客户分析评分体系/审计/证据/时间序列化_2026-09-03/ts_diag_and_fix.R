suppressMessages(library(data.table))
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
OUT <- "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/68213601-ea3b-40ee-91c5-9668c14b1274/scratchpad/ts"
t0 <- Sys.time()
sp <- function(a, b) suppressWarnings(cor(a, b, method = "spearman", use = "complete.obs"))
capture <- function(score, y, q = 0.10) { o <- order(-score); k <- ceiling(length(y) * q); sum(y[o[1:k]]) / sum(y) }
capture_pos <- function(score, y, q = 0.10) { o <- order(-score); k <- ceiling(length(y) * q); yp <- pmax(y, 0); sum(yp[o[1:k]]) / sum(yp) }
lg <- function(x) sign(x) * log1p(abs(x))

pa <- fread("数据表/P12a_platform_daily.csv", select = c("dt", "n_orders", "n_members", "stake_sum", "validbet_sum", "ggr_sum"))
pa[, dt := as.IDate(dt)]
## ── A. B01 面板完整性与符号诊断（对 P12a 平台日序列）───────────────────────
b <- fread("数据表/B01_bt_panel.csv", select = c("member_id", "bet_date", "stake", "game_pnl", "net_pnl", "rebate", "validbet", "n_rounds", "n_tables", "n_ip"), showProgress = FALSE)
b[, bet_date := as.IDate(bet_date)]
tot <- b[, .(n_rows = .N, n_members = uniqueN(member_id), stake = sum(stake), validbet = sum(validbet), game_pnl = sum(game_pnl), net_pnl = sum(net_pnl), rebate = sum(rebate), n_rounds = sum(n_rounds))]
print(tot)
bd <- b[, .(b01_stake = sum(stake), b01_validbet = sum(validbet), b01_game_pnl = sum(game_pnl), b01_members = uniqueN(member_id), b01_rows = .N), by = .(dt = bet_date)]
cmp <- merge(pa, bd, by = "dt", all.x = TRUE)
cmp[, `:=`(stake_ratio = b01_stake / stake_sum, member_ratio = b01_members / n_members, ggr_ratio_signed = b01_game_pnl / ggr_sum)]
fwrite(cmp, file.path(OUT, "B01_vs_P12a_daily_coverage.csv"))
cat("\nB01/P12a coverage by date (head/tail):\n"); print(head(cmp[, .(dt, stake_sum, b01_stake, stake_ratio, n_members, b01_members, member_ratio, ggr_sum, b01_game_pnl)], 5)); print(tail(cmp[, .(dt, stake_sum, b01_stake, stake_ratio, n_members, b01_members, member_ratio, ggr_sum, b01_game_pnl)], 5))
cat("\ncoverage summary: stake_ratio range", range(cmp$stake_ratio, na.rm = TRUE), " member_ratio range", range(cmp$member_ratio, na.rm = TRUE), "\n")
cat("sign check: sum(P12a ggr_sum)=", sum(pa$ggr_sum), " sum(B01 game_pnl)=", tot$game_pnl, " sum(B01 net_pnl)=", tot$net_pnl, " sum(B01 rebate)=", tot$rebate, "\n")
## 平台口径：ggr_sum 为正（庄家赢）。若 B01 game_pnl 总和为正且与 ggr_sum 同向，则 game_pnl 为平台视角。
sgn <- if (sign(tot$game_pnl) == sign(sum(pa$ggr_sum))) 1 else -1
cat("→ B01 game_pnl 平台视角符号系数 sgn =", sgn, "（1 = 已为平台视角；-1 = 会员视角须取负）\n")
## 会员级恒等式：net_pnl = game_pnl + rebate？ 或 net_pnl = game_pnl - rebate？
id1 <- b[, mean(abs(net_pnl - (game_pnl + rebate)) < 1e-6)]; id2 <- b[, mean(abs(net_pnl - (game_pnl - rebate)) < 1e-6)]
cat("identity net = game + rebate:", id1, " | net = game - rebate:", id2, "\n")
per_member_days <- b[, .N, by = member_id][, .(members = .N, mean_days = mean(N), median_days = as.numeric(median(N)), max_days = max(N))]
print(per_member_days)

## ── B. 会员×日 walk-forward（符号校正后）──────────────────────────────────
mk <- function(cut, H = 30) {
  cut <- as.IDate(cut)
  hist <- b[bet_date <= cut]; fut <- b[bet_date > cut & bet_date <= cut + H]
  f <- hist[, .(
    st7 = sum(stake[bet_date > cut - 7]), st14 = sum(stake[bet_date > cut - 14]), st30 = sum(stake[bet_date > cut - 30]),
    st60 = sum(stake[bet_date > cut - 60]), st90 = sum(stake[bet_date > cut - 90]), st_all = sum(stake),
    ggr30 = sgn * sum(game_pnl[bet_date > cut - 30]), ggr_all = sgn * sum(game_pnl), vb30 = sum(validbet[bet_date > cut - 30]),
    act7 = sum(bet_date > cut - 7), act30 = sum(bet_date > cut - 30), act_all = .N,
    recency = as.integer(cut - max(bet_date)), tenure = as.integer(cut - min(bet_date)),
    rounds30 = sum(n_rounds[bet_date > cut - 30]), tables_mean = mean(n_tables), ip_mean = mean(n_ip)
  ), by = member_id]
  f[, hold30 := ifelse(st30 > 0, ggr30 / st30, NA_real_)]
  y <- fut[, .(y_stake = sum(stake), y_ggr = sgn * sum(game_pnl), y_act = .N), by = member_id]
  d <- merge(f, y, by = "member_id", all.x = TRUE)
  for (v in c("y_stake", "y_ggr", "y_act")) set(d, which(is.na(d[[v]])), v, 0)
  d[, y_hold := ifelse(y_stake > 0, y_ggr / y_stake, NA_real_)]
  d[, cut := cut]; d
}
cuts <- c("2026-05-08", "2026-06-07", "2026-07-07")
D <- rbindlist(lapply(cuts, mk))
feat <- c("st7", "st14", "st30", "st60", "st90", "st_all", "ggr30", "ggr_all", "vb30", "act7", "act30", "act_all", "recency", "tenure", "rounds30", "tables_mean", "ip_mean")
rows <- list()
for (k in 2:length(cuts)) {
  tr <- D[cut == as.IDate(cuts[k - 1])]; te <- D[cut == as.IDate(cuts[k])]
  Xtr <- as.data.frame(lapply(tr[, ..feat], lg)); Xte <- as.data.frame(lapply(te[, ..feat], lg))
  for (tgt in c("y_stake", "y_ggr", "y_act")) {
    fit <- lm(lg(tr[[tgt]]) ~ ., data = Xtr)
    pred_lm <- suppressWarnings(as.numeric(predict(fit, newdata = Xte)))
    a <- te[[tgt]]
    for (m in c("lm_log_walkforward", "naive_last30_same_metric", "naive_last30_stake", "naive_last90_stake")) {
      s <- switch(m, lm_log_walkforward = pred_lm, naive_last30_same_metric = switch(tgt, y_stake = te$st30, y_ggr = te$ggr30, y_act = te$act30),
                  naive_last30_stake = te$st30, naive_last90_stake = te$st90)
      o <- order(-s); k10 <- ceiling(nrow(te) * 0.1)
      rows[[length(rows) + 1]] <- data.table(train_cut = cuts[k - 1], test_cut = cuts[k], target = tgt, model = m, n_test = nrow(te),
        spearman = sp(s, a), top10_capture = capture(s, a), top10_capture_pos = capture_pos(s, a), top1_capture_pos = capture_pos(s, a, 0.01),
        r2_log = if (m == "lm_log_walkforward") 1 - sum((lg(a) - s)^2) / sum((lg(a) - mean(lg(a)))^2) else NA_real_,
        sum_actual = sum(a), sum_actual_in_pred_top10 = sum(a[o[1:k10]]), share_zero_actual = mean(a == 0))
    }
  }
  te2 <- te[!is.na(y_hold) & !is.na(hold30)]; te3 <- te2[st30 >= quantile(st30, 0.9)]
  rows[[length(rows) + 1]] <- data.table(train_cut = cuts[k - 1], test_cut = cuts[k], target = "y_hold(rate)", model = "naive_hold30", n_test = nrow(te2), spearman = sp(te2$hold30, te2$y_hold),
    top10_capture = NA_real_, top10_capture_pos = NA_real_, top1_capture_pos = NA_real_, r2_log = NA_real_, sum_actual = NA_real_, sum_actual_in_pred_top10 = NA_real_, share_zero_actual = NA_real_)
  rows[[length(rows) + 1]] <- data.table(train_cut = cuts[k - 1], test_cut = cuts[k], target = "y_hold(rate)|top10pct_stake", model = "naive_hold30", n_test = nrow(te3), spearman = sp(te3$hold30, te3$y_hold),
    top10_capture = NA_real_, top10_capture_pos = NA_real_, top1_capture_pos = NA_real_, r2_log = NA_real_, sum_actual = NA_real_, sum_actual_in_pred_top10 = NA_real_, share_zero_actual = NA_real_)
}
R <- rbindlist(rows); fwrite(R, file.path(OUT, "member_walkforward_B01_v2.csv")); print(R[, .(test_cut, target, model, spearman = round(spearman, 3), top10_capture_pos = round(top10_capture_pos, 3), top1_capture_pos = round(top1_capture_pos, 3), r2_log = round(r2_log, 3), sum_actual, sum_actual_in_pred_top10)])
te <- D[cut == as.IDate(cuts[3])]
ret <- te[, .(n = .N, p_active_next30 = mean(y_act > 0), mean_next_stake = mean(y_stake), sum_next_stake = sum(y_stake), sum_next_ggr = sum(y_ggr)),
          by = .(recency_band = cut(recency, c(-1, 0, 3, 7, 14, 30, 60, 200)))][order(recency_band)]
ret[, share_next_stake := sum_next_stake / sum(sum_next_stake)]
fwrite(ret, file.path(OUT, "retention_by_recency_v2.csv")); print(ret)
## 30 日「须处置样本量」对照：预测 top-1%/top-10% 人数
cat("n members as-of 07-07:", nrow(te), " top1% =", ceiling(nrow(te) * .01), " top10% =", ceiling(nrow(te) * .1), "\n")
rm(b, D); gc()

## ── C. 全宇宙会员×月（P_player_month）：只用模块自有列 valid_bet / game_pnl ────
pm <- fread("数据表/P_player_month.csv", select = c("member_id", "ym", "n_rounds", "n_days", "valid_bet", "game_pnl", "rebate", "net_pnl", "stake"), showProgress = FALSE)
pm[, ym := substr(as.character(ym), 1, 7)]
chk <- pm[, .(n = .N, valid_bet = sum(valid_bet), game_pnl = sum(game_pnl), stake_col = sum(stake)), by = ym][order(ym)]
pa[, ym := substr(as.character(dt), 1, 7)]
chk <- merge(chk, pa[, .(p12a_stake = sum(stake_sum), p12a_validbet = sum(validbet_sum), p12a_ggr = sum(ggr_sum)), by = ym], by = "ym")
print(chk)   # 判 stake 列是否为六层块广播（与 p12a_stake 不符）而 valid_bet 为自有列
sgn_m <- if (sign(sum(chk$game_pnl)) == sign(sum(chk$p12a_ggr))) 1 else -1
cat("P_player_month game_pnl 符号系数 =", sgn_m, "\n")
mm <- c("2026-04", "2026-05", "2026-06", "2026-07")
outm <- list()
for (i in 1:(length(mm) - 1)) {
  a <- pm[ym == mm[i], .(member_id, v0 = valid_bet, g0 = sgn_m * game_pnl, d0 = n_days)]
  bb <- pm[ym == mm[i + 1], .(member_id, v1 = valid_bet, g1 = sgn_m * game_pnl)]
  m <- merge(a, bb, by = "member_id", all.x = TRUE); m[is.na(v1), `:=`(v1 = 0, g1 = 0)]
  mh <- m[v0 > 0 & v1 > 0]
  outm[[i]] <- data.table(from = mm[i], to = mm[i + 1], n = nrow(m), p_active_next = mean(m$v1 > 0),
    sp_validbet = sp(m$v0, m$v1), sp_ggr = sp(m$g0, m$g1), top10_validbet_capture = capture(m$v0, m$v1),
    top10_ggr_capture_pos_by_validbet = capture_pos(m$v0, m$g1), top10_ggr_capture_pos_by_g0 = capture_pos(m$g0, m$g1),
    top1_ggr_capture_pos_by_validbet = capture_pos(m$v0, m$g1, 0.01),
    hold_sp = sp(mh$g0 / mh$v0, mh$g1 / mh$v1), n_hold = nrow(mh),
    sum_g1 = sum(m$g1), sum_g1_in_top10_by_v0 = { o <- order(-m$v0); sum(m$g1[o[1:ceiling(nrow(m) * .1)]]) })
}
M <- rbindlist(outm); fwrite(M, file.path(OUT, "month_persistence_full_universe_v2.csv")); print(M)
cat("ALL DONE", format(Sys.time() - t0), "\n")
