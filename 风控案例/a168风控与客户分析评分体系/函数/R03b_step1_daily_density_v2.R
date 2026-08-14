# ==============================================================================
# R03b · 步骤 1 v2：CSV 逐日计数 → 与全窗 Layer B join → D1 / D2 / D3
# ------------------------------------------------------------------------------
# v2 变更（本轮 RED TEAM 裁示）：
#   ① 缺口三分：shortfall_rows / surplus_rows / net_delta —— 正负漂移不得抵销
#   ② observed_as_of 三列并存：comparison_id / observed_as_of / observed_as_of_source
#      「自述时间」不得升级为「运行时间证据」
#   ③ 判形四分（A/B/C/D）只列形态，不下判
#
# 既有纪律（不得违反）：
#   · Expected 一律取全窗 Layer B，绝不按日重切 ranked（见 SC-001 永久作废）
#   · dealer_id 保字符串原貌（DR-LOAD-002）
#   · 全表打印不截断；三时间锚点必录（GAP-S2-BASE-009B）
#   · 本脚本不代判 H1a / H1b
# ==============================================================================

suppressPackageStartupMessages(library(data.table))

## ── 路径：请按实际位置改这两行 ────────────────────────────────────────────
path <- 'C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/'
CSV_R03B <- paste0(path, "数据库/R03b_player_dealer_daily.csv")
LAYER_B  <- paste0(path, "Layer_B_R03b_expected_daily.tsv")
OUT_TSV  <- paste0(path, "R03b_D1D2D3_daily.tsv")
stopifnot(file.exists(CSV_R03B), file.exists(LAYER_B))

# ── 一、读 CSV（只三列 + 可选批次号）─────────────────────────────────────
hdr  <- names(fread(CSV_R03B, nrows = 0L, showProgress = FALSE))
miss <- setdiff(c("bet_date","uid","dealer_id"), hdr)
if (length(miss)) stop("CSV 缺必需列：", paste(miss, collapse = ", "))
want <- intersect(c("bet_date","uid","dealer_id","comparison_id"), hdr)
csv  <- fread(CSV_R03B, select = want, showProgress = FALSE,
              colClasses = c(dealer_id = "character"))
csv[, bet_date := as.Date(bet_date)][, dealer_id := trimws(dealer_id)]

# ── 二、三时间锚点（自述与运行分列）──────────────────────────────────────
has_cid <- "comparison_id" %in% names(csv)
comparison_id        <- if (has_cid) paste(unique(csv$comparison_id), collapse = " | ") else NA_character_
observed_as_of       <- if (has_cid) comparison_id else
                        format(file.info(CSV_R03B)$mtime, "%Y-%m-%d %H:%M")
observed_as_of_source <- if (has_cid) "CSV.comparison_id（文件自述）" else "file.mtime（退路，弱于自述）"
expected_as_of <- format(file.info(LAYER_B)$mtime, "%Y-%m-%d %H:%M")
baseline_as_of <- format(Sys.time(), "%Y-%m-%d %H:%M")

# ── 三、CSV 逐日实测 ─────────────────────────────────────────────────────
obs <- csv[, .(csv_rows = .N, csv_member = uniqueN(uid),
               csv_dealer = uniqueN(dealer_id)), by = bet_date][order(bet_date)]

# ── 四、读全窗 Layer B ───────────────────────────────────────────────────
lb <- fread(LAYER_B, sep = "\t", showProgress = FALSE)
lb[, bet_date := as.Date(bet_date)]
for (j in grep("^expected_", names(lb), value = TRUE))
  set(lb, j = j, value = as.numeric(lb[[j]]))
if (nrow(lb) != 139L) warning("Layer B 非 139 行，实为 ", nrow(lb))

# ── 五、join，算 D 与缺口三分 ────────────────────────────────────────────
D <- merge(lb, obs, by = "bet_date", all.x = TRUE)[order(bet_date)]
D[, `:=`(D1 = csv_rows/expected_n_rows,
         D2 = csv_member/expected_n_member,
         D3 = csv_dealer/expected_n_dealer,
         net_delta      = csv_rows - expected_n_rows,
         shortfall_rows = pmax(expected_n_rows - csv_rows, 0),
         surplus_rows   = pmax(csv_rows - expected_n_rows, 0))]

# ── 六、日历完整性（先于密度，独立成判）─────────────────────────────────
cov   <- D[!is.na(csv_rows)]
holes <- if (nrow(cov)) setdiff(seq(min(cov$bet_date), max(cov$bet_date), by="day"),
                                cov$bet_date) else integer(0)
cat("【一、日历完整性】\n")
cat(sprintf("  CSV 覆盖：%s ~ %s（%d 日）｜139 日窗中未覆盖 %d 日\n",
            min(cov$bet_date), max(cov$bet_date), nrow(cov), sum(is.na(D$csv_rows))))
cat(sprintf("  区间内缺日：%s\n", if (length(holes))
  paste(as.Date(holes, origin="1970-01-01"), collapse=", ") else "无"))
if (length(holes)) cat("  ⚠️ 形态 C：区间内有洞 → H1a 与 H1b **双双作废**，须进第三分支\n")

# ── 七、全表，一行不省 ───────────────────────────────────────────────────
cat("\n【二、逐日矩阵 · 全 ", nrow(D), " 行，未截断】\n", sep="")
print(D[, .(bet_date, csv_status,
            expected_n_rows, csv_rows, D1 = round(D1,4),
            expected_n_member, csv_member, D2 = round(D2,4),
            expected_n_dealer, csv_dealer, D3 = round(D3,4),
            net_delta, shortfall_rows, surplus_rows)],
      nrows = Inf, class = FALSE)

# ── 八、形态描述（只述不判）─────────────────────────────────────────────
sf <- cov[, sum(shortfall_rows)]; sp <- cov[, sum(surplus_rows)]
cat("\n【三、47 日内部缺口形态】\n")
cat(sprintf("  shortfall 合计 %s ｜ surplus 合计 %s ｜ net %s\n",
            format(sf, big.mark=","), format(sp, big.mark=","),
            format(cov[, sum(net_delta)], big.mark=",")))
cat(sprintf("  D1 合计（Σcsv/Σexp）= %.6f  ← 只作参考，序列形状才是判据\n",
            cov[, sum(csv_rows)/sum(expected_n_rows)]))
cat(sprintf("  末日 %s：shortfall %s，占 shortfall 合计 %.2f%%\n",
            cov[.N, bet_date], format(cov[.N, shortfall_rows], big.mark=","),
            100*cov[.N, shortfall_rows]/max(sf,1)))
cat(sprintf("  非末日 D1：中位 %.4f ｜ 最小 %.4f ｜ 最大 %.4f\n",
            median(cov[-.N, D1]), min(cov[-.N, D1]), max(cov[-.N, D1])))
cat(sprintf("  surplus 之日数 %d（CSV 多于 Expected）\n", sum(cov$surplus_rows > 0)))
cat("  形态对照（供 RED TEAM 裁，脚本不代判）：\n")
cat("    A 前 46 日 D1≈1 且末日 D1≪1  → H1a 强支持\n")
cat("    B 47 日 D1 齐平低于 1        → 迟到数据/Expected(t) 漂移不可排除，H1b 未获直证\n")
cat("    C 区间内有洞                 → H1a/H1b 双双作废\n")
cat("    D 出现 surplus               → 归 BASE-009B 时点漂移，不得记为 export shortfall\n")

# ── 九、锚点与落盘 ───────────────────────────────────────────────────────
cat("\n【四、时间锚点 · GAP-S2-BASE-009B】\n")
cat("  comparison_id         :", comparison_id, "\n")
cat("  observed_as_of        :", observed_as_of, "\n")
cat("  observed_as_of_source :", observed_as_of_source, "\n")
cat("  expected_as_of        :", expected_as_of, "\n")
cat("  baseline_as_of        :", baseline_as_of, "\n")
cat("  ⚠️ comparison_id 只证「文件自述为某版本」，不证导出作业确于该日完成——\n")
cat("     后者属 Export Parameters / 作业日志层，不在本脚本证据范围内\n")

fwrite(D, OUT_TSV, sep = "\t")
cat("\n已落盘：", normalizePath(OUT_TSV), "（139 行，可回传）\n", sep="")
