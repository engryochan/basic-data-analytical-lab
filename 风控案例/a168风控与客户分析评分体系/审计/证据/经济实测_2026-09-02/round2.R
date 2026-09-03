options(warn = 1, width = 230, scipen = 14)
proj <- "C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系"; setwd(proj)
suppressPackageStartupMessages(library(data.table))
SP <- Sys.getenv("SP")
sec <- function(t) cat("\n==================== ", t, " ====================\n", sep = "")
f <- function(x, d = 0) format(round(x, d), big.mark = ",", nsmall = d)
kv <- function(metric, value) data.table(metric = metric, value = as.numeric(value))
summ <- data.table(metric = character(), value = numeric())

## ---------- CC-01: is block `profit` net of rebate? ----------
sec("CC-01 semantic check: profit vs gross GGR")
s <- fread("数据表/S01_player_score.csv", select = c("member_id","stake","valid_bet","profit","rebate_cost","ngr","net_margin_bet23_formal_canonical","agent_cost_bet23_formal_canonical","agent_cost_lv1_bet23_canonical","agent_cost_lv2_bet24_canonical","agent_cost_lv3_bet25_canonical","agent_cost_lv4_bet26_canonical","agent_cost_lv5_bet27_canonical","n_rounds","n_bets","rebate_rate_actual","evidence_rate","vip_tier","游戏输赢贡献","流水贡献","退水支出","人工标记史","hold_rate"), encoding = "UTF-8", showProgress = FALSE)
cat("Σprofit", f(sum(s$profit)), " Σrebate_cost", f(sum(s$rebate_cost)), " Σprofit+rebate", f(sum(s$profit)+sum(s$rebate_cost)), " Σ游戏输赢贡献(M02)", f(sum(s$游戏输赢贡献, na.rm=TRUE)), " Σ退水支出", f(sum(s$退水支出, na.rm=TRUE)), "\n")
cat("row-wise: profit + rebate_cost == -游戏输赢贡献 ? mean abs diff =", mean(abs(s$profit + s$rebate_cost + s$游戏输赢贡献), na.rm=TRUE), " share |diff|<0.01:", mean(abs(s$profit + s$rebate_cost + s$游戏输赢贡献) < 0.01, na.rm=TRUE), "\n")
cat("row-wise: profit == -游戏输赢贡献 ? share |diff|<0.01:", mean(abs(s$profit + s$游戏输赢贡献) < 0.01, na.rm=TRUE), "\n")
t3 <- fread("数据表/T03_arbitrage.csv", select = c("member_id","validbet","game_pnl","net_pnl","rebate","stake","profit","rebate_cost","ngr","hedge_rate","n_rounds","n_bets"), encoding = "UTF-8", showProgress = FALSE)
cat("T03 own cols: net_pnl == game_pnl + rebate ? share |diff|<0.01:", mean(abs(t3$net_pnl - (t3$game_pnl + t3$rebate)) < 0.01), " ; block profit == -net_pnl ? share:", mean(abs(t3$profit + t3$net_pnl) < 0.01), " ; block profit == -game_pnl ? share:", mean(abs(t3$profit + t3$game_pnl) < 0.01), "\n")
dx <- fread("数据表/DX05_product_panorama.csv", select = c("product_code","scope","n_member","stake_total","validbet_total","player_pnl","ggr","house_hold_pct","rebate_total"), encoding = "UTF-8")
print(dx)
cat("DX05 product 101 ggr", f(dx[product_code==101, ggr]), " = S01 Σprofit + Σrebate ?", f(sum(s$profit)+sum(s$rebate_cost)), "\n")
gross <- sum(s$profit) + sum(s$rebate_cost); ngr <- sum(s$profit); reb <- sum(s$rebate_cost); stk <- sum(s$stake); vb <- sum(s$valid_bet)
ac <- c(formal = sum(s$agent_cost_bet23_formal_canonical, na.rm=TRUE), lv1 = sum(s$agent_cost_lv1_bet23_canonical, na.rm=TRUE), lv2 = sum(s$agent_cost_lv2_bet24_canonical, na.rm=TRUE), lv3 = sum(s$agent_cost_lv3_bet25_canonical, na.rm=TRUE), lv4 = sum(s$agent_cost_lv4_bet26_canonical, na.rm=TRUE), lv5 = sum(s$agent_cost_lv5_bet27_canonical, na.rm=TRUE))
cat("agent cost bases:", paste(names(ac), f(ac), collapse=" | "), " spread", f(max(ac)-min(ac)), "\n")
cat("GROSS basis: GGR", f(gross), " hold_gross/stake", round(100*gross/stk,4), " hold_gross/validbet", round(100*gross/vb,4), " | NGR", f(ngr), " ngr/stake", round(100*ngr/stk,4), " | net_margin_candidate(NGR-agent formal)", f(ngr-ac["formal"]), round(100*(ngr-ac["formal"])/stk,4), "\n")
summ <- rbind(summ, kv("gross_ggr", gross), kv("ngr_true", ngr), kv("rebate", reb), kv("stake", stk), kv("valid_bet", vb), kv("hold_gross_stake_pct", 100*gross/stk), kv("hold_gross_validbet_pct", 100*gross/vb), kv("ngr_rate_pct", 100*ngr/stk), kv("net_margin_candidate", ngr-ac["formal"]), kv("net_margin_candidate_pct", 100*(ngr-ac["formal"])/stk),
              kv("agent_cost_formal", ac["formal"]), kv("agent_cost_lv1", ac["lv1"]), kv("agent_cost_lv2", ac["lv2"]), kv("agent_cost_lv3", ac["lv3"]), kv("agent_cost_lv4", ac["lv4"]), kv("agent_cost_lv5", ac["lv5"]), kv("agent_cost_spread", max(ac)-min(ac)),
              kv("members_ngr_negative", sum(s$profit < 0)), kv("members_ngr_negative_sum", s[profit < 0, sum(profit)]), kv("members_gross_negative", sum(s$profit + s$rebate_cost < 0)))

## ---------- rebate bands on the corrected basis, with n_rounds CI ----------
sec("Rebate bands (corrected: GGR = profit + rebate_cost; NGR = profit)")
s[, rb_band := fcase(is.na(rebate_rate_actual) | rebate_rate_actual<=0, "0", rebate_rate_actual<0.005, "(0,0.5%)", rebate_rate_actual<0.010, "[0.5%,1%)", rebate_rate_actual<0.015, "[1%,1.5%)", default = ">=1.5%")]
rb <- s[, .(n=.N, stake=round(sum(stake)), valid_bet=round(sum(valid_bet)), ggr_gross=round(sum(profit+rebate_cost)), rebate=round(sum(rebate_cost)), ngr=round(sum(profit)), hold_gross_pct=round(100*sum(profit+rebate_cost)/sum(stake),3), ngr_rate_pct=round(100*sum(profit)/sum(stake),3), n_rounds=sum(n_rounds,na.rm=TRUE), ci_halfwidth_pp=round(100*1.96*0.95/sqrt(sum(n_rounds,na.rm=TRUE)),3), n_ngr_negative=sum(profit<0), L5_share=round(mean(evidence_rate=="L5_INSUFFICIENT"),3)), by=rb_band][order(rb_band)]
print(rb); fwrite(rb, file.path(SP, "S01_rebate_bands_v2.csv"), bom=TRUE)
r <- s[!is.na(rebate_rate_actual) & rebate_rate_actual > 0 & stake > 0]
summ <- rbind(summ, kv("rebate_members", nrow(r)), kv("rebate_members_ggr_gross", sum(r$profit+r$rebate_cost)), kv("rebate_members_ngr", sum(r$profit)), kv("rebate_members_rebate", sum(r$rebate_cost)), kv("rebate_members_stake", sum(r$stake)), kv("rebate_members_hold_gross_pct", 100*sum(r$profit+r$rebate_cost)/sum(r$stake)), kv("rebate_members_ngr_rate_pct", 100*sum(r$profit)/sum(r$stake)), kv("rebate_members_ngr_negative_n", sum(r$profit<0)), kv("rebate_members_ngr_negative_rebate", r[profit<0, sum(rebate_cost)]), kv("rebate_members_ngr_negative_ngr", r[profit<0, sum(profit)]), kv("rebate_members_n_rounds", sum(r$n_rounds,na.rm=TRUE)))
cat("rebate members:", nrow(r), " gross GGR", f(sum(r$profit+r$rebate_cost)), " NGR", f(sum(r$profit)), " rebate", f(sum(r$rebate_cost)), " hold_gross", round(100*sum(r$profit+r$rebate_cost)/sum(r$stake),3), " ngr_rate", round(100*sum(r$profit)/sum(r$stake),3), " NGR<0 members", sum(r$profit<0), " their rebate", f(r[profit<0, sum(rebate_cost)]), "\n")

## ---------- hold basis crosswalk ----------
sec("Hold basis crosswalk")
p12a <- fread("数据表/P12a_platform_daily.csv", select = c("dt","stake_sum","validbet_sum","ggr_sum","hold_pct"), encoding="UTF-8")
p4 <- fread("数据表/PI04_member_5d_profile.csv", select = c("member_id","sum_stake","sum_validbet","sum_revenue"), encoding="UTF-8", showProgress=FALSE)
cw <- data.table(source = c("S01 profit/stake (NGR 口径，块 hold_rate)", "S01 (profit+rebate)/stake (毛利 GGR，本金口径)", "S01 (profit+rebate)/valid_bet (毛利，洗码口径)", "PI04 Σsum_revenue/Σsum_stake", "PI04 Σsum_revenue/Σsum_validbet", "P12a Σggr_sum/Σstake_sum", "P12a Σggr_sum/Σvalidbet_sum", "DX05 product 101 house_hold_pct"),
                 numerator = c(ngr, gross, gross, sum(p4$sum_revenue), sum(p4$sum_revenue), sum(p12a$ggr_sum), sum(p12a$ggr_sum), dx[product_code==101, ggr]),
                 denominator = c(stk, stk, vb, sum(p4$sum_stake), sum(p4$sum_validbet), sum(p12a$stake_sum), sum(p12a$validbet_sum), dx[product_code==101, stake_total]))
cw[, hold_pct := round(100*numerator/denominator, 4)]; print(cw); fwrite(cw, file.path(SP, "hold_crosswalk.csv"), bom=TRUE)
summ <- rbind(summ, kv("other_products_stake", dx[product_code!=101, sum(stake_total)]), kv("other_products_ggr", dx[product_code!=101, sum(ggr)]), kv("other_products_members", dx[product_code!=101, sum(n_member)]))

## ---------- seed / label cohort economics ----------
sec("Seed / label cohort economics (S01.人工标记史, K01b, K01c)")
s[, marked := !is.na(人工标记史) & 人工标记史 > 0]
kb <- fread("数据表/K01b_seed_manual.csv", select = c("member_id","seed_src"), encoding="UTF-8"); kc <- fread("数据表/K01c_seed_dated.csv", encoding="UTF-8")
s[, in_k01b := member_id %in% kb$member_id]
seed <- rbind(s[, .(cohort = "人工标记史>0", n=.N, stake=round(sum(stake)), ggr_gross=round(sum(profit+rebate_cost)), ngr=round(sum(profit)), rebate=round(sum(rebate_cost)), hold_gross_pct=round(100*sum(profit+rebate_cost)/sum(stake),3), ngr_rate_pct=round(100*sum(profit)/sum(stake),3), n_rounds=sum(n_rounds,na.rm=TRUE), ci_pp=round(100*1.96*0.95/sqrt(sum(n_rounds,na.rm=TRUE)),3)), by=marked][order(-marked)][, .(cohort=paste0(cohort, "=", marked), n, stake, ggr_gross, ngr, rebate, hold_gross_pct, ngr_rate_pct, n_rounds, ci_pp)],
              s[, .(cohort = paste0("K01b_seed_manual 125 名在 S01=", in_k01b), n=.N, stake=round(sum(stake)), ggr_gross=round(sum(profit+rebate_cost)), ngr=round(sum(profit)), rebate=round(sum(rebate_cost)), hold_gross_pct=round(100*sum(profit+rebate_cost)/sum(stake),3), ngr_rate_pct=round(100*sum(profit)/sum(stake),3), n_rounds=sum(n_rounds,na.rm=TRUE), ci_pp=round(100*1.96*0.95/sqrt(sum(n_rounds,na.rm=TRUE)),3)), by=in_k01b][order(-in_k01b)][, .(cohort, n, stake, ggr_gross, ngr, rebate, hold_gross_pct, ngr_rate_pct, n_rounds, ci_pp)])
print(seed); fwrite(seed, file.path(SP, "seed_cohort_v2.csv"), bom=TRUE)
cat("K01b members:", uniqueN(kb$member_id), " found in S01:", sum(kb$member_id %in% s$member_id), " ; K01c rows:", nrow(kc), "\n")

## ---------- hedge bands with CI ----------
sec("Hedge bands (T03) with n_rounds CI, gross basis")
t3[, hb := fcase(is.na(hedge_rate)|hedge_rate==0, "0", hedge_rate<.05, "(0,5%)", hedge_rate<.2, "[5%,20%)", hedge_rate<.5, "[20%,50%)", default=">=50%")]
ht <- t3[, .(n=.N, stake=round(sum(stake)), ggr_gross=round(-sum(game_pnl)), rebate=round(sum(rebate)), ngr=round(-sum(net_pnl)), hold_gross_pct=round(-100*sum(game_pnl)/sum(stake),3), ngr_rate_pct=round(-100*sum(net_pnl)/sum(stake),3), n_rounds=sum(n_rounds,na.rm=TRUE), ci_pp=round(100*1.96*0.95/sqrt(sum(n_rounds,na.rm=TRUE)),3)), by=hb][order(hb)]
print(ht); fwrite(ht, file.path(SP, "T03_hedge_bands_v2.csv"), bom=TRUE)

## ---------- PI01 × typology cross-tab ----------
sec("PI01 treated members x typology markers")
p1 <- fread("数据表/PI01_treatment_delta_member.csv", encoding="UTF-8")
p1[, member_id := as.character(member_id)]; s[, member_id := as.character(member_id)]; t3[, member_id := as.character(member_id)]
x <- merge(p1[, .(member_id, treat_field, stake_pre, stake_post, d_revenue)], s[, .(member_id, marked, evidence_rate, stake_s01 = stake, ngr_s01 = profit)], by = "member_id", all.x = TRUE)
x <- merge(x, t3[, .(member_id, hedge_rate)], by = "member_id", all.x = TRUE)
ip <- fread("数据表/I_ip_player.csv", select = c("member_id","bet_ip"), encoding="UTF-8", showProgress=FALSE); ipa <- fread("数据表/I_ip_agg.csv", select = c("bet_ip","n_member_eff"), encoding="UTF-8")
ipm <- merge(ip, ipa, by = "bet_ip")[, .(max_n_member_eff = max(n_member_eff, na.rm=TRUE)), by = member_id][, member_id := as.character(member_id)]
x <- merge(x, ipm, by = "member_id", all.x = TRUE)
xt <- x[, .(n=.N, in_S01=sum(!is.na(stake_s01)), marked=sum(marked %in% TRUE), hedge_ge20=sum(hedge_rate >= 0.2, na.rm=TRUE), shared_ip_ge10=sum(max_n_member_eff >= 10, na.rm=TRUE), L5=sum(evidence_rate=="L5_INSUFFICIENT", na.rm=TRUE), L1_L4=sum(evidence_rate %in% c("L1_POWERED","L2_CI_1P5","L3_CI_2P0","L4_CI_3P0"), na.rm=TRUE), sum_d_revenue=round(sum(d_revenue,na.rm=TRUE))), by=treat_field]
print(xt); fwrite(xt, file.path(SP, "PI01_x_typology.csv"), bom=TRUE)
set.seed(20260819); b <- replicate(2000, sum(sample(p1$d_revenue, replace=TRUE))); cat("bootstrap 95% CI of Σd_revenue:", f(quantile(b, .025)), "…", f(quantile(b, .975)), "\n")
summ <- rbind(summ, kv("pi01_d_revenue_ci_lo", quantile(b,.025)), kv("pi01_d_revenue_ci_hi", quantile(b,.975)))
cat("n_post quantiles:", paste(quantile(p1$n_post, c(.1,.25,.5,.75,.9)), collapse=" | "), " d_post days:", paste(quantile(p1$d_post, c(.1,.25,.5,.75,.9)), collapse=" | "), "\n")

## ---------- treatment pre/post for ALL ledgered members via P12c_member_daily_pnl ----------
sec("Ledger-wide pre/post from P12c (member x day)")
hdr <- names(fread("数据表/P12c_member_daily_pnl.csv", nrows = 0))
own <- hdr[!grepl("_xagg$|^roi_|^avg_stake_|^share_|^hold_rate_|^roi_delta_|^ramp_", hdr)][1:12]; cat("P12c leading columns:", paste(own, collapse=", "), "\n")
uidc <- if ("uid" %in% hdr) "uid" else if ("member_id" %in% hdr) "member_id" else stop("no uid col")
dtc <- if ("dt" %in% hdr) "dt" else if ("bet_date" %in% hdr) "bet_date" else stop("no dt col")
stc <- grep("^day_stake$|^stake_day$|^stake$", hdr, value=TRUE)[1]; pnc <- grep("^day_pnl$|^day_game_pnl$|^game_pnl$|^net_pnl$|^day_net_pnl$", hdr, value=TRUE)[1]
cat("using:", uidc, dtc, stc, pnc, "\n")
pc <- fread("数据表/P12c_member_daily_pnl.csv", select = c(uidc, dtc, stc, pnc), encoding="UTF-8", showProgress=FALSE); setnames(pc, c("member_id","dt","stake","pnl")); pc[, member_id := as.character(member_id)]; pc[, dt := as.IDate(dt)]
cat("P12c rows", nrow(pc), " members", uniqueN(pc$member_id), " dt range", as.character(range(pc$dt)), " Σstake", f(sum(pc$stake,na.rm=TRUE)), " Σpnl", f(sum(pc$pnl,na.rm=TRUE)), "\n")
tl <- fread("数据表/TL10_treatment_ledger.csv", select = c("member_id","action_date","action_class","field_name","value_before","value_after","is_baccarat_member"), encoding="UTF-8"); tl[, member_id := as.character(member_id)]; tl[, action_date := as.IDate(action_date)]
ev <- unique(tl[, .(member_id, action_date, field_name, value_before, value_after)])
cat("TL10 events", nrow(ev), " members", uniqueN(ev$member_id), " in P12c:", uniqueN(ev[member_id %in% pc$member_id, member_id]), "\n")
pc2 <- pc[member_id %in% ev$member_id]
evm <- ev[member_id %in% pc2$member_id]
mg <- merge(evm, pc2, by = "member_id", allow.cartesian = TRUE)
mg[, phase := fifelse(dt < action_date, "pre", fifelse(dt > action_date, "post", "day0"))]
res <- mg[phase != "day0", .(n_days = .N, stake = sum(stake, na.rm=TRUE), ggr = -sum(pnl, na.rm=TRUE)), by = .(member_id, action_date, field_name, value_before, value_after, phase)]
res <- dcast(res, member_id + action_date + field_name + value_before + value_after ~ phase, value.var = c("n_days","stake","ggr"), fill = 0)
for (cc in c("n_days_pre","n_days_post","stake_pre","stake_post","ggr_pre","ggr_post")) if (!cc %in% names(res)) res[, (cc) := 0]
res[, field_grp := fifelse(grepl("^10[1-9]-mem015$", field_name), "10x-mem015（分产品限额）", field_name)]
agg <- res[, .(events=.N, members=uniqueN(member_id), with_pre=sum(n_days_pre>0), with_post=sum(n_days_post>0), with_both=sum(n_days_pre>0 & n_days_post>0), stake_pre=round(sum(stake_pre)), stake_post=round(sum(stake_post)), ggr_pre=round(sum(ggr_pre)), ggr_post=round(sum(ggr_post)), hold_pre_pct=round(100*sum(ggr_pre)/pmax(sum(stake_pre),1),3), hold_post_pct=round(100*sum(ggr_post)/pmax(sum(stake_post),1),3), d_ggr=round(sum(ggr_post)-sum(ggr_pre))), by=field_grp][order(-events)]
print(agg); fwrite(agg, file.path(SP, "ledger_prepost_by_field.csv"), bom=TRUE)
fwrite(res, file.path(SP, "ledger_prepost_events.csv"), bom=TRUE)
## TL14 by direction
t14 <- fread("数据表/TL14_limit_treatment.csv", select = c("member_id","action_date","direction","max_hi_before","max_hi_after"), encoding="UTF-8"); t14[, member_id := as.character(member_id)]; t14[, action_date := as.IDate(action_date)]
m14 <- merge(unique(t14[member_id %in% pc2$member_id, .(member_id, action_date, direction)]), pc2, by = "member_id", allow.cartesian = TRUE)
m14[, phase := fifelse(dt < action_date, "pre", fifelse(dt > action_date, "post", "day0"))]
r14 <- m14[phase != "day0", .(n_days = .N, stake = sum(stake, na.rm=TRUE), ggr = -sum(pnl, na.rm=TRUE)), by = .(member_id, action_date, direction, phase)]
r14 <- dcast(r14, member_id + action_date + direction ~ phase, value.var = c("n_days","stake","ggr"), fill = 0)
for (cc in c("n_days_pre","n_days_post","stake_pre","stake_post","ggr_pre","ggr_post")) if (!cc %in% names(r14)) r14[, (cc) := 0]
a14 <- r14[, .(events=.N, members=uniqueN(member_id), with_both=sum(n_days_pre>0 & n_days_post>0), stake_pre=round(sum(stake_pre)), stake_post=round(sum(stake_post)), ggr_pre=round(sum(ggr_pre)), ggr_post=round(sum(ggr_post)), hold_pre_pct=round(100*sum(ggr_pre)/pmax(sum(stake_pre),1),3), hold_post_pct=round(100*sum(ggr_post)/pmax(sum(stake_post),1),3), d_ggr=round(sum(ggr_post)-sum(ggr_pre))), by=direction][order(-events)]
cat("TL14 members in P12c:", uniqueN(t14[member_id %in% pc2$member_id, member_id]), "/", uniqueN(t14$member_id), "\n"); print(a14); fwrite(a14, file.path(SP, "tl14_prepost_by_direction.csv"), bom=TRUE)
summ <- rbind(summ, kv("tl10_members", uniqueN(ev$member_id)), kv("tl10_members_in_P12c", uniqueN(ev[member_id %in% pc$member_id, member_id])), kv("tl14_members_in_P12c", uniqueN(t14[member_id %in% pc2$member_id, member_id])))
rm(pc, pc2); gc(verbose=FALSE)

## ---------- unit reconciliation of own money columns (OWN_COLUMNS_ONLY tables) ----------
sec("Own-money-column unit reconciliation vs platform totals")
inv <- fread(file.path(SP, "table_econ_verdict.csv"), encoding="UTF-8")
freq <- fread(file.path(SP, "column_frequency.csv"), encoding="UTF-8"); block <- freq[n_tables >= 120, column]
MONEY <- "(^|_)(stake|valid_?bet|validbet|vb|amount|amt|payout|game_pnl|net_pnl|pnl|profit|ggr|ngr|revenue|rebate|commission|margin|residual|house_pnl|player_pnl|saving|cost)(_|$)|流水贡献|游戏输赢贡献|退水支出|在桌洗码量|桌面输赢|洗码量|输赢"
NOTM <- "^(n_|nd_|cnt_|num_|pct_|share_|ratio_)|(_rate|_share|_cv|_pct|_ratio|_entropy|_p[0-9]+_p[0-9]+|_p[0-9]+|_dep|_len|_seq|_status|_flag|_id|_date|_time)$|_cv_|multiple"
TYPO <- "^(roi_(non_)?[a-z_]+|avg_stake_(non_)?[a-z_]+|share_[a-z_]+|hold_rate_[a-z_]+|roi_delta_[a-z_]+|ramp_[a-z_]+|[a-z_]+_xagg)$"
out <- list()
for (fn in inv$table) {
  h <- names(fread(file.path("数据表", fn), nrows = 0, encoding="UTF-8"))
  own <- h[!(h %in% block) & !grepl(TYPO, h, ignore.case=TRUE)]
  mc <- own[grepl(MONEY, own, ignore.case=TRUE) & !grepl(NOTM, own, ignore.case=TRUE)]
  if (!length(mc)) next
  mb <- file.size(file.path("数据表", fn))/1e6
  d <- tryCatch(fread(file.path("数据表", fn), select = mc, encoding="UTF-8", showProgress=FALSE), error=function(e) NULL); if (is.null(d)) next
  for (c in mc) { v <- suppressWarnings(as.numeric(d[[c]])); if (all(is.na(v))) next
    sm <- sum(v, na.rm=TRUE); mx <- max(abs(v), na.rm=TRUE)
    out[[length(out)+1]] <- data.table(table=fn, column=c, rows=nrow(d), sum=sm, max_abs=mx, ratio_to_stake=sm/stk, ratio_to_gross_ggr=sm/gross,
      units_verdict = fifelse(abs(sm) > 3*stk, "EXCEEDS_PLATFORM_STAKE_3X", fifelse(grepl("stake|valid|vb|洗码|流水", c, ignore.case=TRUE) & abs(sm) <= 1.05*stk, "PLAUSIBLE", fifelse(grepl("pnl|profit|ggr|ngr|revenue|margin|residual|输赢", c, ignore.case=TRUE) & abs(sm) <= 1.5*gross, "PLAUSIBLE", fifelse(grepl("rebate|commission|退水|cost", c, ignore.case=TRUE) & abs(sm) <= 3*reb, "PLAUSIBLE", "CHECK")))))
  }
  rm(d)
}
rec <- rbindlist(out); fwrite(rec, file.path(SP, "own_money_reconciliation.csv"), bom=TRUE)
print(rec[units_verdict != "PLAUSIBLE"][order(table)], nrows = 200)
cat("tables with any EXCEEDS/CHECK:", uniqueN(rec[units_verdict != "PLAUSIBLE", table]), " of", uniqueN(rec$table), "\n")
fwrite(summ, file.path(SP, "round2_summary.csv"), bom=TRUE); print(summ, nrows=200)
sec("DONE")
