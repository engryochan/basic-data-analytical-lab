## 赏赐面经济包络实测（只读；自有栏；按敞口分档；不据实现输赢符号分档——P-15/P-16 恪守）
## 输出：scratchpad/reward_envelope_S01.csv · reward_envelope_month.csv · reward_envelope_summary.txt
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
suppressPackageStartupMessages(library(data.table))
OUT <- "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/6d7b4b2b-b9df-4cd3-89ff-967edac8a3ee/scratchpad"
t0 <- Sys.time()
## ---- S01 逐员（723,442 行）：只取 ASCII 命名之自有栏 ----
s <- fread("数据表/S01_player_score.csv",
           select = c("member_id","valid_bet","profit","rebate_cost","n_rounds","active_days",
                      "evidence_rate","vip_tier","hold_rate","free_comm_rate","rebate_rate_actual"),
           showProgress = FALSE)
cat("S01 rows:", nrow(s), " read in", round(difftime(Sys.time(), t0, units="secs")), "s\n")
s <- s[!is.na(valid_bet)]
## 敞口十分位（valid_bet，降序：D1 = 顶 10%）
s[, dec := 11L - ceiling(frank(valid_bet, ties.method = "first") / .N * 10)]
s[dec < 1L, dec := 1L]
tot_vb <- sum(s$valid_bet, na.rm = TRUE); tot_ngr <- sum(s$profit, na.rm = TRUE); tot_rb <- sum(s$rebate_cost, na.rm = TRUE)
e1 <- s[, .(n = .N,
            valid_bet = sum(valid_bet, na.rm = TRUE), vb_share = sum(valid_bet, na.rm = TRUE) / tot_vb,
            ngr = sum(profit, na.rm = TRUE), ngr_share = sum(profit, na.rm = TRUE) / tot_ngr,
            ngr_rate = sum(profit, na.rm = TRUE) / sum(valid_bet, na.rm = TRUE),
            rebate = sum(rebate_cost, na.rm = TRUE), rebate_share = sum(rebate_cost, na.rm = TRUE) / tot_rb,
            n_rebate_recv = sum(rebate_cost > 0, na.rm = TRUE),
            active_days_mean = mean(active_days, na.rm = TRUE),
            n_rounds_p50 = as.numeric(median(as.numeric(n_rounds), na.rm = TRUE)),
            L5_share = mean(evidence_rate == "L5_INSUFFICIENT", na.rm = TRUE),
            ngr_neg_share = mean(profit < 0, na.rm = TRUE)), by = dec][order(dec)]
fwrite(e1, file.path(OUT, "reward_envelope_S01.csv"), bom = TRUE)
print(e1[, .(dec, n, vb_share = round(vb_share,4), ngr_share = round(ngr_share,4), ngr_rate = round(ngr_rate,5),
             rebate_share = round(rebate_share,4), n_rebate_recv, active_days_mean = round(active_days_mean,1), L5_share = round(L5_share,3))])
## 顶 1% / 顶 0.1%
s[, pr := frank(-valid_bet, ties.method = "first") / .N]
top <- rbindlist(lapply(c(0.001, 0.01, 0.05, 0.10, 0.20), function(p) s[pr <= p, .(top = p, n = .N,
        vb_share = sum(valid_bet)/tot_vb, ngr_share = sum(profit)/tot_ngr, ngr_rate = sum(profit)/sum(valid_bet),
        rebate_share = sum(rebate_cost)/tot_rb)]))
print(top)
## ---- P_player_month：月际留存（上月敞口分档 → 下月活跃率、洗码份额、正 NGR 份额）----
t1 <- Sys.time()
m <- fread("数据表/P_player_month.csv", select = c("member_id","ym","valid_bet","game_pnl","rebate"), showProgress = FALSE)
cat("P_player_month rows:", nrow(m), " read in", round(difftime(Sys.time(), t1, units="secs")), "s\n")
m[, ym := as.character(ym)]
months <- sort(unique(m$ym)); cat("months:", paste(months, collapse=","), "\n")
m[, ngr := -game_pnl - rebate]   # 会员视角 game_pnl 取负 = 毛利；减退水 = NGR（CC-01）
res <- list()
for (i in seq_len(length(months) - 1L)) {
  a <- m[ym == months[i] & valid_bet > 0]; b <- m[ym == months[i+1]]
  a[, dec := 11L - ceiling(frank(valid_bet, ties.method = "first") / .N * 10)]; a[dec < 1L, dec := 1L]
  j <- merge(a[, .(member_id, dec, vb_prev = valid_bet)], b[, .(member_id, vb_next = valid_bet, ngr_next = ngr)], by = "member_id", all.x = TRUE)
  j[is.na(vb_next), `:=`(vb_next = 0, ngr_next = 0)]
  tot_next_vb <- sum(b$valid_bet, na.rm = TRUE); tot_next_pos <- sum(pmax(b$ngr, 0), na.rm = TRUE)
  r <- j[, .(from = months[i], to = months[i+1], n = .N,
             active_next = mean(vb_next > 0),
             next_vb_share_of_platform = sum(vb_next) / tot_next_vb,
             next_pos_ngr_share = sum(pmax(ngr_next, 0)) / tot_next_pos,
             next_ngr = sum(ngr_next),
             vb_retention_ratio = sum(vb_next) / sum(vb_prev)), by = dec][order(dec)]
  res[[i]] <- r
}
mm <- rbindlist(res)
fwrite(mm, file.path(OUT, "reward_envelope_month.csv"), bom = TRUE)
agg <- mm[, .(active_next = mean(active_next), next_vb_share = mean(next_vb_share_of_platform),
              next_pos_ngr_share = mean(next_pos_ngr_share), vb_retention = mean(vb_retention_ratio), folds = .N), by = dec][order(dec)]
print(agg)
## 平台合计核对（与 13.1 平台账对账）
cat(sprintf("S01: Σvalid_bet=%.2f ΣNGR(profit)=%.2f Σrebate=%.2f n=%d\n", tot_vb, tot_ngr, tot_rb, nrow(s)))
cat(sprintf("P_player_month: Σvalid_bet=%.2f ΣGGR=%.2f Σrebate=%.2f\n", sum(m$valid_bet,na.rm=TRUE), sum(-m$game_pnl,na.rm=TRUE), sum(m$rebate,na.rm=TRUE)))
cat("total elapsed", round(difftime(Sys.time(), t0, units="mins"),1), "min\n")
