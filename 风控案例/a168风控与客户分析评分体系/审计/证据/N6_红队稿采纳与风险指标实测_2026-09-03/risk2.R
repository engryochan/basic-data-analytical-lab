suppressPackageStartupMessages(library(data.table))
setwd("C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系")
p <- fread("数据表/P12a_platform_daily.csv", select=c("dt","ggr_sum","validbet_sum","n_members","n_orders"), showProgress=FALSE)
setorder(p, dt); d <- p[!is.na(ggr_sum)]
x <- d$ggr_sum
cat(sprintf("日数 %d  Σ毛利 %s  Σ洗码 %s\n", nrow(d), format(sum(x),big.mark=","), format(sum(d$validbet_sum),big.mark=",")))
sharpe <- mean(x)/sd(x); dsd <- sqrt(mean(pmin(x,0)^2)); sortino <- mean(x)/dsd
cum <- cumsum(x); dd <- cum - cummax(cum); mdd <- min(dd)
cat(sprintf("日毛利：均 %.0f  sd %.0f  下行偏差 %.0f\n", mean(x), sd(x), dsd))
cat(sprintf("Sharpe(日) %.4f  年化 %.2f\nSortino(日,MAR=0) %.4f\n", sharpe, sharpe*sqrt(139), sortino))
cat(sprintf("最大回撤 %.0f（占累计 %.4f%%）谷底第 %d 日\n", mdd, 100*mdd/sum(x), which.min(dd)))
cat(sprintf("负毛利日 %d (%.2f%%)  最差单日 %.0f  最佳单日 %.0f\n", sum(x<0), 100*mean(x<0), min(x), max(x)))
h <- x/d$validbet_sum
cat(sprintf("hold 日率：均 %.4f%%  sd %.4f pp  最差 %.4f%%  最佳 %.4f%%  负日 %d\n",100*mean(h),100*sd(h),100*min(h),100*max(h),sum(h<0)))
cat(sprintf("hold Sharpe %.4f  Sortino %.4f\n", mean(h)/sd(h), mean(h)/sqrt(mean(pmin(h,0)^2))))
r <- frollapply(h, 30, sd)
cat(sprintf("30 日滚动 hold sd：中位 %.4f pp  最大 %.4f pp\n", 100*median(r,na.rm=TRUE), 100*max(r,na.rm=TRUE)))
## 桌台级：以 T_table_span / S_second_dist 无日序；改用 P12a 仅平台。荷官/桌台日序须 #133 方有。
