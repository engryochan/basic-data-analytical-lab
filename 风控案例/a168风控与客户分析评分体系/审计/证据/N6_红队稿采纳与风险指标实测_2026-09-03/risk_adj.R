## 风险调整指标可行性实测：MDD / Sortino / Sharpe 于平台日序列与会员月面板
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
suppressPackageStartupMessages(library(data.table))
OUT <- "C:/Users/engry/AppData/Local/Temp/claude/C--Users-engry-Documents-GitHub-basic-data-analytical-lab/6d7b4b2b-b9df-4cd3-89ff-967edac8a3ee/scratchpad"

## ---- 0. S01 之「索提诺稳定性」究竟是什么 ----
s <- fread("数据表/S01_player_score.csv", select = c("member_id","索提诺稳定性","活跃稳定","valid_bet","profit","n_rounds","active_days"), showProgress = FALSE)
cat("== S01 索提诺稳定性 ==\n"); print(summary(s$`索提诺稳定性`))
cat("非 NA:", sum(!is.na(s$`索提诺稳定性`)), "/", nrow(s), " 唯一值:", length(unique(s$`索提诺稳定性`)), "\n")
cat("与 profit 之 Spearman:", round(cor(s$`索提诺稳定性`, s$profit, method="spearman", use="complete.obs"),4), "\n")
cat("与 valid_bet 之 Spearman:", round(cor(s$`索提诺稳定性`, s$valid_bet, method="spearman", use="complete.obs"),4), "\n\n")

## ---- 1. 平台日序列（P12a，139 日）----
p <- fread("数据表/P12a_platform_daily.csv", showProgress = FALSE)
cat("== P12a 栏 ==\n"); print(names(p)[1:min(20,ncol(p))])
dc <- grep("date|dt|日", names(p), value = TRUE, ignore.case = TRUE)[1]
gc_ <- grep("game_pnl|ggr|profit|输赢", names(p), value = TRUE, ignore.case = TRUE)
vc <- grep("valid|洗码", names(p), value = TRUE, ignore.case = TRUE)
cat("日期栏:", dc, "| 毛利候选:", paste(head(gc_,5),collapse=","), "| 洗码候选:", paste(head(vc,3),collapse=","), "\n")
print(head(p[, .SD, .SDcols = intersect(c(dc, head(gc_,3), head(vc,2)), names(p))], 3))

## 取平台每日毛利（会员视角取负）
gcol <- if ("game_pnl" %in% names(p)) "game_pnl" else gc_[1]
vcol <- if ("valid_bet" %in% names(p)) "valid_bet" else vc[1]
d <- p[, .(dt = get(dc), ggr = -as.numeric(get(gcol)), vbet = as.numeric(get(vcol)))]
setorder(d, dt); d <- d[!is.na(ggr)]
cat("\n日数:", nrow(d), " Σ毛利:", format(sum(d$ggr), big.mark=","), " Σ洗码:", format(sum(d$vbet), big.mark=","), "\n")

.mdd <- function(x) { cum <- cumsum(x); pk <- cummax(cum); dd <- cum - pk; list(mdd = min(dd), mdd_pct_of_total = min(dd)/sum(x), trough = which.min(dd)) }
.sharpe  <- function(x) mean(x)/sd(x)
.sortino <- function(x, mar = 0) { dn <- pmin(x - mar, 0); dd <- sqrt(mean(dn^2)); (mean(x) - mar)/dd }
m <- .mdd(d$ggr)
cat(sprintf("\n== 平台日毛利（n=%d）==\n均值 %.0f ／日  标准差 %.0f  下行偏差 %.0f\nSharpe(日) %.4f   年化(×√139) %.3f\nSortino(日,MAR=0) %.4f\n最大回撤 %.0f（占累计 %.2f%%）谷底第 %d 日\n负毛利日 %d (%.1f%%)  最差单日 %.0f  最佳单日 %.0f\n",
  nrow(d), mean(d$ggr), sd(d$ggr), sqrt(mean(pmin(d$ggr,0)^2)),
  .sharpe(d$ggr), .sharpe(d$ggr)*sqrt(139), .sortino(d$ggr),
  m$mdd, 100*m$mdd_pct_of_total, m$trough,
  sum(d$ggr<0), 100*mean(d$ggr<0), min(d$ggr), max(d$ggr)))
## hold 率序列
d[, hold := ggr/vbet]
cat(sprintf("hold 日率：均 %.4f%%  sd %.4f pp  最差 %.4f%%  最佳 %.4f%%  负日 %d\n",
  100*mean(d$hold), 100*sd(d$hold), 100*min(d$hold), 100*max(d$hold), sum(d$hold<0)))
fwrite(d, file.path(OUT,"platform_daily_risk.csv"), bom=TRUE)

## ---- 2. 会员月面板：月际持续性（Sortino 是否可用于实体排序）----
mm <- fread("数据表/P_player_month.csv", select=c("member_id","ym","valid_bet","game_pnl","rebate","n_days"), showProgress=FALSE)
mm[, ngr := -game_pnl - rebate]; mm[, ym := as.character(ym)]
ms <- sort(unique(mm$ym))
## 每会员之月度 NGR 序列 → Sortino / MDD（须 ≥3 月方可算）
w <- dcast(mm, member_id ~ ym, value.var="ngr", fill=0)
mat <- as.matrix(w[, -1]); rownames(mat) <- w$member_id
act <- dcast(mm, member_id ~ ym, value.var="valid_bet", fill=0)
nmon <- rowSums(as.matrix(act[,-1])>0)
cat(sprintf("\n== 会员月面板 ==\n会员 %d ｜ 月 %d ｜ 活跃≥3 月者 %d (%.1f%%) ｜ ≥5 月者 %d (%.2f%%)\n",
  nrow(w), ncol(mat), sum(nmon>=3), 100*mean(nmon>=3), sum(nmon>=5), 100*mean(nmon>=5)))
sel <- which(nmon>=5)
if (length(sel)>50) {
  sub <- mat[sel,,drop=FALSE]
  sor <- apply(sub,1,function(x){dn<-pmin(x,0); dd<-sqrt(mean(dn^2)); if(dd==0) NA else mean(x)/dd})
  mddv<- apply(sub,1,function(x){cum<-cumsum(x); min(cum-cummax(cum))})
  tot <- rowSums(sub)
  cat(sprintf("≥5 月者 n=%d：Sortino 中位 %.3f ｜ 与总 NGR 之 Spearman %.4f ｜ MDD 中位 %.0f\n",
    length(sel), median(sor,na.rm=TRUE), cor(sor,tot,method="spearman",use="complete.obs"), median(mddv)))
  ## 前后折验证：前三月 Sortino 能否预测后三月 NGR
  h1 <- sub[,1:3,drop=FALSE]; h2 <- sub[,4:ncol(sub),drop=FALSE]
  s1 <- apply(h1,1,function(x){dn<-pmin(x,0); dd<-sqrt(mean(dn^2)); if(dd==0) NA else mean(x)/dd})
  n2 <- rowSums(h2)
  ok <- !is.na(s1)
  cat(sprintf("前 3 月 Sortino → 后 %d 月 NGR：Spearman %.4f（n=%d）\n", ncol(h2), cor(s1[ok],n2[ok],method="spearman"), sum(ok)))
  v1 <- rowSums(as.matrix(act[sel,2:4]));
  cat(sprintf("对照：前 3 月洗码 → 后 %d 月 NGR：Spearman %.4f\n", ncol(h2), cor(v1,n2,method="spearman")))
}
cat("\ndone\n")
