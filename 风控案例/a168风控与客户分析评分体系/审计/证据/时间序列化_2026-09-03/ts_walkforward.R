suppressMessages(library(data.table))
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
OUT <- "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/68213601-ea3b-40ee-91c5-9668c14b1274/scratchpad/ts"
dir.create(OUT, showWarnings = FALSE)
t0 <- Sys.time()
sp <- function(a, b) suppressWarnings(cor(a, b, method = "spearman", use = "complete.obs"))
capture <- function(score, y, q = 0.10) { o <- order(-score); k <- ceiling(length(y) * q); sum(y[o[1:k]]) / sum(y) }
capture_pos <- function(score, y, q = 0.10) { o <- order(-score); k <- ceiling(length(y) * q); yp <- pmax(y, 0); sum(yp[o[1:k]]) / sum(yp) }
lg <- function(x) sign(x) * log1p(abs(x))

## ── 1. 平台日序列（P12a）：滚动原点一步预测，留出最后 30 日 ─────────────
pa <- fread("数据表/P12a_platform_daily.csv", select = c("dt", "n_orders", "n_members", "stake_sum", "validbet_sum", "ggr_sum", "hold_pct"))
pa[, dt := as.IDate(dt)]; setorder(pa, dt)
n <- nrow(pa); H <- 30; te <- (n - H + 1):n
one_step <- function(y, k) sapply(te, function(i) mean(y[(i - k):(i - 1)]))
res_pa <- list()
for (v in c("stake_sum", "ggr_sum", "n_members", "hold_pct")) {
  y <- pa[[v]]
  X <- embed(y, 8); Xtr <- X[1:(n - H - 7), ]
  fit <- lm(Xtr[, 1] ~ Xtr[, -1])
  preds <- list(
    naive_last        = y[te - 1],
    ma7               = one_step(y, 7),
    ma28              = one_step(y, 28),
    same_weekday_last = y[te - 7],
    ar7_refit_train   = sapply(te, function(i) sum(c(1, y[(i - 1):(i - 7)]) * coef(fit))),
    train_mean        = rep(mean(y[1:(n - H)]), H))
  a <- y[te]
  for (m in names(preds)) {
    p <- preds[[m]]
    res_pa[[length(res_pa) + 1]] <- data.table(series = v, model = m, n_test = H,
      mape_pct = mean(abs(p - a) / abs(a)) * 100, wape_pct = sum(abs(p - a)) / sum(abs(a)) * 100,
      sum_actual = sum(a), sum_pred = sum(p), bias_pct = (sum(p) - sum(a)) / sum(a) * 100)
  }
}
res_pa <- rbindlist(res_pa)
fwrite(res_pa, file.path(OUT, "platform_daily_walkforward.csv"))
cat("platform done", format(Sys.time() - t0), "\n"); print(res_pa[order(series, wape_pct)])

## 30 日合计之预测（月度经营口径）：以前 30 日合计直接外推 vs 前 60 日日均×30
agg <- data.table(series = c("stake_sum", "ggr_sum"))
agg[, actual_last30 := sapply(series, function(v) sum(pa[[v]][te]))]
agg[, pred_prev30   := sapply(series, function(v) sum(pa[[v]][(n - 2 * H + 1):(n - H)]))]
agg[, pred_prev60_mean := sapply(series, function(v) mean(pa[[v]][(n - 3 * H + 1):(n - H)]) * H)]
agg[, err_prev30_pct := (pred_prev30 - actual_last30) / actual_last30 * 100]
agg[, err_prev60_pct := (pred_prev60_mean - actual_last30) / actual_last30 * 100]
fwrite(agg, file.path(OUT, "platform_30d_aggregate_forecast.csv")); print(agg)

## ── 2. 会员×日面板（B01）：as-of 截点特征 → 后 30 日目标 ────────────────
b <- fread("数据表/B01_bt_panel.csv", select = c("member_id", "bet_date", "stake", "game_pnl", "net_pnl", "rebate", "validbet", "n_rounds", "n_tables", "n_ip"), showProgress = FALSE)
b[, bet_date := as.IDate(bet_date)]
cat("B01 loaded", nrow(b), "rows", uniqueN(b$member_id), "members", format(Sys.time() - t0), "\n")
mk <- function(cut, H = 30) {
  cut <- as.IDate(cut)
  hist <- b[bet_date <= cut]; fut <- b[bet_date > cut & bet_date <= cut + H]
  f <- hist[, .(
    st7 = sum(stake[bet_date > cut - 7]), st14 = sum(stake[bet_date > cut - 14]), st30 = sum(stake[bet_date > cut - 30]),
    st60 = sum(stake[bet_date > cut - 60]), st90 = sum(stake[bet_date > cut - 90]), st_all = sum(stake),
    ggr30 = -sum(game_pnl[bet_date > cut - 30]), ngr30 = -sum(net_pnl[bet_date > cut - 30]),
    ggr_all = -sum(game_pnl), ngr_all = -sum(net_pnl), vb30 = sum(validbet[bet_date > cut - 30]),
    act7 = sum(bet_date > cut - 7), act30 = sum(bet_date > cut - 30), act_all = .N,
    recency = as.integer(cut - max(bet_date)), tenure = as.integer(cut - min(bet_date)),
    rounds30 = sum(n_rounds[bet_date > cut - 30]), tables_mean = mean(n_tables), ip_mean = mean(n_ip)
  ), by = member_id]
  f[, hold30 := ifelse(st30 > 0, ggr30 / st30, NA_real_)]
  y <- fut[, .(y_stake = sum(stake), y_ggr = -sum(game_pnl), y_ngr = -sum(net_pnl), y_act = .N, y_vb = sum(validbet)), by = member_id]
  d <- merge(f, y, by = "member_id", all.x = TRUE)
  for (v in c("y_stake", "y_ggr", "y_ngr", "y_act", "y_vb")) set(d, which(is.na(d[[v]])), v, 0)
  d[, y_hold := ifelse(y_stake > 0, y_ggr / y_stake, NA_real_)]
  d[, cut := cut]
  d
}
cuts <- c("2026-06-07", "2026-07-07")
D <- rbindlist(lapply(cuts, mk))
cat("features built", nrow(D), format(Sys.time() - t0), "\n")
fwrite(D[, .(n_members_asof = .N, n_active_next30 = sum(y_act > 0)), by = cut], file.path(OUT, "member_panel_sizes.csv"))
tr <- D[cut == as.IDate(cuts[1])]; te <- D[cut == as.IDate(cuts[2])]
feat <- c("st7", "st14", "st30", "st60", "st90", "st_all", "ggr30", "ngr30", "ggr_all", "vb30", "act7", "act30", "act_all", "recency", "tenure", "rounds30", "tables_mean", "ip_mean")
Xtr <- as.data.frame(lapply(tr[, ..feat], lg)); Xte <- as.data.frame(lapply(te[, ..feat], lg))
rows <- list()
for (tgt in c("y_stake", "y_ggr", "y_ngr", "y_vb", "y_act")) {
  ytr <- lg(tr[[tgt]]); fit <- lm(ytr ~ ., data = Xtr)
  pred_lm <- as.numeric(predict(fit, newdata = Xte))
  base <- switch(tgt, y_stake = te$st30, y_vb = te$vb30, y_ggr = te$ggr30, y_ngr = te$ngr30, y_act = te$act30)
  a <- te[[tgt]]
  for (m in c("lm_log_walkforward", "naive_last30_same_metric", "naive_last30_stake", "naive_st90")) {
    s <- switch(m, lm_log_walkforward = pred_lm, naive_last30_same_metric = base, naive_last30_stake = te$st30, naive_st90 = te$st90)
    o <- order(-s); k <- ceiling(nrow(te) * 0.1)
    rows[[length(rows) + 1]] <- data.table(target = tgt, model = m, n_test = nrow(te),
      spearman = sp(s, a), top10_capture = capture(s, a), top10_capture_pos = capture_pos(s, a), top1_capture_pos = capture_pos(s, a, 0.01),
      r2_log = if (m == "lm_log_walkforward") 1 - sum((lg(a) - s)^2) / sum((lg(a) - mean(lg(a)))^2) else NA_real_,
      sum_actual = sum(a), sum_actual_in_pred_top10 = sum(a[o[1:k]]), share_zero_actual = mean(a == 0))
  }
}
te2 <- te[!is.na(y_hold) & !is.na(hold30)]
rows[[length(rows) + 1]] <- data.table(target = "y_hold(rate)", model = "naive_hold30", n_test = nrow(te2), spearman = sp(te2$hold30, te2$y_hold),
  top10_capture = NA_real_, top10_capture_pos = NA_real_, top1_capture_pos = NA_real_, r2_log = NA_real_, sum_actual = NA_real_, sum_actual_in_pred_top10 = NA_real_, share_zero_actual = NA_real_)
te3 <- te2[st30 >= quantile(st30, 0.9)]
rows[[length(rows) + 1]] <- data.table(target = "y_hold(rate)|top10pct_stake", model = "naive_hold30", n_test = nrow(te3), spearman = sp(te3$hold30, te3$y_hold),
  top10_capture = NA_real_, top10_capture_pos = NA_real_, top1_capture_pos = NA_real_, r2_log = NA_real_, sum_actual = NA_real_, sum_actual_in_pred_top10 = NA_real_, share_zero_actual = NA_real_)
R <- rbindlist(rows); fwrite(R, file.path(OUT, "member_walkforward_B01.csv")); print(R)
ret <- te[, .(n = .N, p_active_next30 = mean(y_act > 0), mean_next_stake = mean(y_stake), sum_next_ggr = sum(y_ggr)),
          by = .(recency_band = cut(recency, c(-1, 0, 3, 7, 14, 30, 60, 200)))][order(recency_band)]
fwrite(ret, file.path(OUT, "retention_by_recency.csv")); print(ret)

## ── 3. 全宇宙会员×月（P_player_month）：月度持续性 ─────────────────────
pm <- fread("数据表/P_player_month.csv", select = c("member_id", "ym", "n_rounds", "n_days", "valid_bet", "game_pnl", "rebate", "net_pnl", "stake"), showProgress = FALSE)
pm[, ym := substr(as.character(ym), 1, 7)]
cat("P_player_month loaded", nrow(pm), uniqueN(pm$member_id), format(Sys.time() - t0), "\n")
print(pm[, .(n = .N, stake = sum(stake), ggr = -sum(game_pnl)), by = ym][order(ym)])
mm <- c("2026-04", "2026-05", "2026-06", "2026-07")
outm <- list()
for (i in 1:(length(mm) - 1)) {
  a <- pm[ym == mm[i], .(member_id, s0 = stake, g0 = -game_pnl, v0 = valid_bet)]
  bb <- pm[ym == mm[i + 1], .(member_id, s1 = stake, g1 = -game_pnl)]
  m <- merge(a, bb, by = "member_id", all.x = TRUE); m[is.na(s1), `:=`(s1 = 0, g1 = 0)]
  mh <- m[s0 > 0 & s1 > 0]
  outm[[i]] <- data.table(from = mm[i], to = mm[i + 1], n = nrow(m), p_active_next = mean(m$s1 > 0),
    sp_stake = sp(m$s0, m$s1), sp_ggr = sp(m$g0, m$g1), top10_stake_capture = capture(m$s0, m$s1),
    top10_ggr_capture_pos_by_stake = capture_pos(m$s0, m$g1), top10_ggr_capture_pos_by_g0 = capture_pos(m$g0, m$g1),
    hold_sp = sp(mh$g0 / mh$s0, mh$g1 / mh$s1), n_hold = nrow(mh))
}
M <- rbindlist(outm); fwrite(M, file.path(OUT, "month_persistence_full_universe.csv")); print(M)
cat("ALL DONE", format(Sys.time() - t0), "\n")
