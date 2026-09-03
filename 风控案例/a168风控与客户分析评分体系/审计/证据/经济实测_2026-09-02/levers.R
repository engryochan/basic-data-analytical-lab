options(warn = 1, width = 220, scipen = 12)
proj <- "C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系"; setwd(proj)
suppressPackageStartupMessages(library(data.table))
SP <- Sys.getenv("SP")
sec <- function(t) cat("\n==================== ", t, " ====================\n", sep = "")
f <- function(x, d = 0) format(round(x, d), big.mark = ",", nsmall = d)
kv <- function(metric, value) data.table(metric = metric, value = as.numeric(value))

sec("S01_player_score - member-level accounting (723,442)")
sel <- c("member_id","stake","valid_bet","profit","rebate_cost","ngr","residual_b","net_margin_bet23_formal_canonical","hold_rate","roi","roi_ex_rebate","n_bets","n_rounds","active_days","vip_tier","turnover_multiple","rebate_rate_actual","rebate_pct_config","evidence_rate","economic_value","action_priority","pr_qualified","hold_ci_halfwidth_approx","free_comm_rate")
t0 <- Sys.time(); s <- fread("数据表/S01_player_score.csv", select = sel, encoding = "UTF-8", showProgress = FALSE); cat("loaded", nrow(s), "rows in", format(Sys.time()-t0), "\n")
cat("Sum stake", f(sum(s$stake,na.rm=T)), " valid_bet", f(sum(s$valid_bet,na.rm=T)), " profit(GGR)", f(sum(s$profit,na.rm=T)), " rebate_cost", f(sum(s$rebate_cost,na.rm=T)), " ngr", f(sum(s$ngr,na.rm=T)), " net_margin(bet23)", f(sum(s$net_margin_bet23_formal_canonical,na.rm=T)), "\n")
cat("platform hold% =", round(100*sum(s$profit,na.rm=T)/sum(s$stake,na.rm=T),4), " ngr% =", round(100*sum(s$ngr,na.rm=T)/sum(s$stake,na.rm=T),4), " net_margin% =", round(100*sum(s$net_margin_bet23_formal_canonical,na.rm=T)/sum(s$stake,na.rm=T),4), "\n")
ap <- s[, .(n=.N, sum_net_margin=round(sum(net_margin_bet23_formal_canonical,na.rm=T)), sum_stake=round(sum(stake,na.rm=T)), sum_ngr=round(sum(ngr,na.rm=T))), by=action_priority][order(-n)]
print(ap); fwrite(ap, file.path(SP, "S01_action_priority.csv"), bom=TRUE)
er <- s[, .(n=.N, sum_stake=round(sum(stake,na.rm=T)), sum_ngr=round(sum(ngr,na.rm=T))), by=evidence_rate][order(evidence_rate)]
print(er); fwrite(er, file.path(SP, "S01_evidence_rate.csv"), bom=TRUE)
setorder(s, -ngr); n <- nrow(s)
top1 <- 100*s[1:ceiling(n*.01), sum(ngr,na.rm=T)]/sum(s$ngr,na.rm=T); top10 <- 100*s[1:ceiling(n*.10), sum(ngr,na.rm=T)]/sum(s$ngr,na.rm=T)
cat("NGR concentration: top1%", round(top1,2), "% ; top10%", round(top10,2), "% ; members with ngr<0:", sum(s$ngr<0,na.rm=T), " sum", f(s[ngr<0, sum(ngr)]), "\n")
s[, rb_band := fcase(is.na(rebate_rate_actual) | rebate_rate_actual<=0, "0", rebate_rate_actual<0.005, "(0,0.5%)", rebate_rate_actual<0.010, "[0.5%,1%)", rebate_rate_actual<0.015, "[1%,1.5%)", default = ">=1.5%")]
rb <- s[, .(n=.N, stake=round(sum(stake,na.rm=T)), valid_bet=round(sum(valid_bet,na.rm=T)), ggr=round(sum(profit,na.rm=T)), rebate=round(sum(rebate_cost,na.rm=T)), ngr=round(sum(ngr,na.rm=T)), hold_pct=round(100*sum(profit,na.rm=T)/sum(stake,na.rm=T),3), ngr_pct=round(100*sum(ngr,na.rm=T)/sum(stake,na.rm=T),3), n_ngr_neg=sum(ngr<0,na.rm=T)), by=rb_band][order(rb_band)]
cat("rebate_rate_actual bands:\n"); print(rb); fwrite(rb, file.path(SP, "S01_rebate_bands.csv"), bom=TRUE)

sec("L1 - rebate repricing lever, restricted to members actually receiving rebate (data-driven cut points)")
r <- s[!is.na(rebate_rate_actual) & rebate_rate_actual > 0 & stake > 0]
cat("rebate members:", nrow(r), " rebate", f(sum(r$rebate_cost)), " ggr", f(sum(r$profit)), " ngr", f(sum(r$ngr)), " pooled hold%", round(100*sum(r$profit)/sum(r$stake),3), " pooled ngr%", round(100*sum(r$ngr)/sum(r$stake),3), "\n")
r[, `:=`(pr_turnover = frank(turnover_multiple, ties.method="average")/.N, pr_roi_ex = frank(roi_ex_rebate, ties.method="average")/.N)]
r[, seg := fcase(pr_turnover>=.8 & pr_roi_ex>=.8, "A", pr_turnover>=.8 & pr_roi_ex>=.5, "B", pr_turnover>=.5 & pr_roi_ex>=.5, "C", pr_roi_ex<=.2, "D", default="E")]
r[, `:=`(band_p25 = quantile(rebate_rate_actual, .25), band_p50 = quantile(rebate_rate_actual,.5), band_p75 = quantile(rebate_rate_actual, .75)), by = vip_tier]
r[, rr_prop := fcase(seg %in% c("A","B"), band_p25, seg == "D", band_p75, default = rebate_rate_actual)]
r[, saving := rebate_cost - valid_bet * rr_prop]
r[, leak := pmax(rebate_cost - profit, 0)]   # rebate paid in excess of gross win on that member (NGR < 0 part attributable to rebate)
segtab <- r[, .(n=.N, stake=round(sum(stake)), valid_bet=round(sum(valid_bet)), ggr=round(sum(profit)), rebate_now=round(sum(rebate_cost)), rebate_proposed=round(sum(valid_bet*rr_prop)), saving=round(sum(saving)), ngr=round(sum(ngr)), hold_pct=round(100*sum(profit)/sum(stake),3), ngr_pct=round(100*sum(ngr)/sum(stake),3)), by=seg][order(seg)]
print(segtab); fwrite(segtab, file.path(SP, "L1_segments.csv"), bom=TRUE)
bands <- unique(r[, .(vip_tier, band_p25, band_p50, band_p75)])[order(vip_tier)]; print(bands); fwrite(bands, file.path(SP, "L1_bands_by_vip.csv"), bom=TRUE)
cat("L1 saving (A+B down to P25, D up to P75; static, before churn) =", f(sum(r$saving)), " of rebate", f(sum(r$rebate_cost)), "\n")
cat("rebate members with ngr<0:", sum(r$ngr<0), " their rebate", f(r[ngr<0, sum(rebate_cost)]), " their ngr", f(r[ngr<0, sum(ngr)]), " ; rebate-in-excess-of-win (leak, member-level positive part)", f(sum(r$leak)), " over", sum(r$leak>0), "members\n")
cat("rebate members by evidence_rate:\n"); print(r[, .(n=.N, rebate=round(sum(rebate_cost)), ngr=round(sum(ngr))), by=evidence_rate][order(evidence_rate)])

summ <- rbind(
  kv("platform_members", nrow(s)), kv("platform_stake", sum(s$stake,na.rm=T)), kv("platform_valid_bet", sum(s$valid_bet,na.rm=T)),
  kv("platform_ggr", sum(s$profit,na.rm=T)), kv("platform_rebate_cost", sum(s$rebate_cost,na.rm=T)), kv("platform_ngr", sum(s$ngr,na.rm=T)),
  kv("platform_net_margin_bet23", sum(s$net_margin_bet23_formal_canonical,na.rm=T)),
  kv("platform_hold_pct", 100*sum(s$profit,na.rm=T)/sum(s$stake,na.rm=T)), kv("platform_ngr_pct", 100*sum(s$ngr,na.rm=T)/sum(s$stake,na.rm=T)), kv("platform_net_margin_pct", 100*sum(s$net_margin_bet23_formal_canonical,na.rm=T)/sum(s$stake,na.rm=T)),
  kv("ngr_neg_members", sum(s$ngr<0,na.rm=T)), kv("ngr_neg_sum", s[ngr<0, sum(ngr,na.rm=T)]), kv("evidence_L5_members", sum(s$evidence_rate=="L5_INSUFFICIENT",na.rm=T)),
  kv("ngr_top1pct_share", top1), kv("ngr_top10pct_share", top10),
  kv("rebate_members", nrow(r)), kv("rebate_members_rebate", sum(r$rebate_cost)), kv("rebate_members_ggr", sum(r$profit)), kv("rebate_members_ngr", sum(r$ngr)), kv("rebate_members_stake", sum(r$stake)),
  kv("rebate_members_hold_pct", 100*sum(r$profit)/sum(r$stake)), kv("rebate_members_ngr_pct", 100*sum(r$ngr)/sum(r$stake)),
  kv("rebate_members_ngr_neg_n", sum(r$ngr<0)), kv("rebate_members_ngr_neg_rebate", r[ngr<0, sum(rebate_cost)]), kv("rebate_members_ngr_neg_ngr", r[ngr<0, sum(ngr)]),
  kv("rebate_leak_excess_of_win", sum(r$leak)), kv("rebate_leak_members", sum(r$leak>0)),
  kv("L1_saving_total", sum(r$saving)), kv("L1_saving_A", r[seg=="A", sum(saving)]), kv("L1_saving_B", r[seg=="B", sum(saving)]), kv("L1_cost_D", r[seg=="D", sum(saving)]),
  kv("L1_n_A", r[seg=="A", .N]), kv("L1_n_B", r[seg=="B", .N]), kv("L1_n_C", r[seg=="C", .N]), kv("L1_n_D", r[seg=="D", .N]), kv("L1_n_E", r[seg=="E", .N]),
  kv("L1_ngr_A", r[seg=="A", sum(ngr)]), kv("L1_ngr_B", r[seg=="B", sum(ngr)]), kv("L1_ngr_D", r[seg=="D", sum(ngr)]),
  kv("L1_rebate_A", r[seg=="A", sum(rebate_cost)]), kv("L1_rebate_B", r[seg=="B", sum(rebate_cost)]), kv("L1_rebate_D", r[seg=="D", sum(rebate_cost)]),
  kv("A_bucket_members", ap[action_priority %like% "^A", n]), kv("A_bucket_net_margin", ap[action_priority %like% "^A", sum_net_margin]), kv("A_bucket_stake", ap[action_priority %like% "^A", sum_stake]),
  kv("D_bucket_members", ap[action_priority %like% "^D", n]), kv("D_bucket_net_margin", ap[action_priority %like% "^D", sum_net_margin]), kv("D_bucket_stake", ap[action_priority %like% "^D", sum_stake]),
  kv("Z_bucket_members", ap[action_priority %like% "^Z", n]), kv("Z_bucket_net_margin", ap[action_priority %like% "^Z", sum_net_margin]))
rm(s, r); gc(verbose=FALSE)

sec("T03_arbitrage - hedge/rebate exposure (member-level, PRIMARY)")
t3 <- fread("数据表/T03_arbitrage.csv", select = c("member_id","validbet","game_pnl","net_pnl","rebate","hedge_rate","stake_cv","n_days","stake","profit","rebate_cost","ngr","roi_ex_rebate","turnover_multiple","n_bets","evidence_rate"), encoding="UTF-8", showProgress=FALSE)
cat("rows", nrow(t3), " hedge_rate>0:", sum(t3$hedge_rate>0,na.rm=T), "\n")
t3[, hb := fcase(is.na(hedge_rate)|hedge_rate==0, "0", hedge_rate<.05, "(0,5%)", hedge_rate<.2, "[5%,20%)", hedge_rate<.5, "[20%,50%)", default=">=50%")]
ht <- t3[, .(n=.N, stake=round(sum(stake,na.rm=T)), validbet=round(sum(validbet,na.rm=T)), rebate=round(sum(rebate,na.rm=T)), ggr=round(-sum(game_pnl,na.rm=T)), hold_pct=round(-100*sum(game_pnl,na.rm=T)/sum(stake,na.rm=T),3), ngr=round(sum(ngr,na.rm=T))), by=hb][order(hb)]
print(ht); fwrite(ht, file.path(SP, "T03_hedge_bands.csv"), bom=TRUE)
summ <- rbind(summ, kv("T03_members", nrow(t3)), kv("T03_hedge_pos_members", sum(t3$hedge_rate>0,na.rm=T)), kv("T03_hedge_ge20_members", sum(t3$hedge_rate>=.2,na.rm=T)), kv("T03_hedge_ge20_rebate", t3[hedge_rate>=.2, sum(rebate,na.rm=T)]), kv("T03_hedge_ge20_ggr", t3[hedge_rate>=.2, -sum(game_pnl,na.rm=T)]), kv("T03_hedge_ge20_stake", t3[hedge_rate>=.2, sum(stake,na.rm=T)]), kv("T03_hedge_ge20_ngr", t3[hedge_rate>=.2, sum(ngr,na.rm=T)]))
rm(t3); gc(verbose=FALSE)

sec("K01_risk_feature_matrix - is_seed cohort economics")
k1 <- fread("数据表/K01_risk_feature_matrix.csv", select = c("member_id","is_seed","n_days","hedge_rate","rebate_dep","night_share","roi_game","validbet","stake","profit","rebate_cost","ngr","net_margin_bet23_formal_canonical","hold_rate","n_bets","n_rounds","evidence_rate"), encoding="UTF-8", showProgress=FALSE)
kt <- k1[, .(n=.N, stake=round(sum(stake,na.rm=T)), profit=round(sum(profit,na.rm=T)), rebate=round(sum(rebate_cost,na.rm=T)), ngr=round(sum(ngr,na.rm=T)), net_margin=round(sum(net_margin_bet23_formal_canonical,na.rm=T)), hold_pct=round(100*sum(profit,na.rm=T)/sum(stake,na.rm=T),3), med_n_rounds=as.numeric(median(n_rounds,na.rm=T)), hedge_med=round(median(hedge_rate,na.rm=T),4)), by=is_seed]
print(kt); fwrite(kt, file.path(SP, "K01_seed_cohort.csv"), bom=TRUE)
for (i in seq_len(nrow(kt))) summ <- rbind(summ, kv(paste0("K01_seed", kt$is_seed[i], "_n"), kt$n[i]), kv(paste0("K01_seed", kt$is_seed[i], "_hold_pct"), kt$hold_pct[i]), kv(paste0("K01_seed", kt$is_seed[i], "_ngr"), kt$ngr[i]), kv(paste0("K01_seed", kt$is_seed[i], "_stake"), kt$stake[i]))
rm(k1); gc(verbose=FALSE)

sec("PI04_member_5d_profile - observability & hold")
p4 <- fread("数据表/PI04_member_5d_profile.csv", select = c("member_id","n_active_days","sum_stake","sum_revenue","hold_pct","verdict_observability","night_share_pct","share_revenue_pct"), encoding="UTF-8", showProgress=FALSE)
pt <- p4[, .(n=.N, stake=round(sum(sum_stake,na.rm=T)), revenue=round(sum(sum_revenue,na.rm=T)), hold_pct=round(100*sum(sum_revenue,na.rm=T)/sum(sum_stake,na.rm=T),3)), by=verdict_observability][order(-n)]
print(pt); fwrite(pt, file.path(SP, "PI04_observability.csv"), bom=TRUE)
fwrite(summ, file.path(SP, "levers_summary.csv"), bom = TRUE); print(summ, nrows = 200)
sec("DONE")
