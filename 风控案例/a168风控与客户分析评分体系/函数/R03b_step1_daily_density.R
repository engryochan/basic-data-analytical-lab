# ==============================================================================
# R03b · 步骤 1：CSV 逐日计数 → 与 Layer B 逐日 join → D1 / D2 / D3
# ------------------------------------------------------------------------------
# 纪律（本轮 RED TEAM 已锁定，脚本内不得违反）：
#   ① Expected 一律取自**全窗** Layer B，绝不在此按日重切 ranked
#      —— 理由见 SC-001：ROW_NUMBER(PARTITION BY bet01) 去重键不含 dt，
#         逐日切片与全窗切片非同一 estimand。
#   ② 本脚本只产出**形态**，不下 H1a / H1b 之判。
#      「05-06 ≈ 140,556 或 ≈ 64,143」是筛选指纹，不是判定阈值。
#   ③ 三个时间锚点必须记录（GAP-S2-BASE-009B）：
#      observed_as_of（CSV 导出时点）/ expected_as_of（Layer B 跑批时点）
#      / baseline_as_of（本脚本运行时点）。
#      缺锚点时 D1=0.9877 只能读作「相对 08-14 重建之 Expected，08-11 CSV 低 1.23%」，
#      不得读作「导出漏了 1.23%」。
#   ④ 身份键 dealer_id 一律以字符读入（DR-LOAD-002），不得数值化。
#   ⑤ 全表打印，不截断 —— 所见即样本，截断即隐证。
# ==============================================================================

suppressPackageStartupMessages(library(data.table))

## ── 路径：请按实际位置改这两行 ────────────────────────────────────────────
path <- 'C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/'
CSV_R03B <- paste0(path, "数据库/R03b_player_dealer_daily.csv")
LAYER_B  <- paste0(path, "Layer_B___R03b_应产量_D1D2D3_的正当分母_.txt")
OUT_TSV  <- paste0(path, "R03b_D1D2D3_daily.tsv")

stopifnot(file.exists(CSV_R03B), file.exists(LAYER_B))

# ── 一、读 CSV：只取三列 + 可选的批次号 ───────────────────────────────────
hdr  <- names(fread(CSV_R03B, nrows = 0L, showProgress = FALSE))
want <- intersect(c("bet_date", "uid", "dealer_id", "comparison_id"), hdr)
miss <- setdiff(c("bet_date", "uid", "dealer_id"), hdr)
if (length(miss)) stop("CSV 缺必需列：", paste(miss, collapse = ", "))

csv <- fread(CSV_R03B, select = want, showProgress = FALSE,
             colClasses = c(dealer_id = "character"))   # ★ 身份键保字符串原貌
csv[, bet_date  := as.Date(bet_date)]
csv[, dealer_id := trimws(dealer_id)]

# ── 二、三个时间锚点 ──────────────────────────────────────────────────────
observed_as_of <- if ("comparison_id" %in% names(csv))
  paste(unique(csv$comparison_id), collapse = " | ") else
  paste0("（CSV 无 comparison_id 列；退用文件时间 ",
         format(file.info(CSV_R03B)$mtime, "%Y-%m-%d %H:%M"), "）")
expected_as_of <- format(file.info(LAYER_B)$mtime, "%Y-%m-%d %H:%M")
baseline_as_of <- format(Sys.time(), "%Y-%m-%d %H:%M")

# ── 三、CSV 逐日实测 ──────────────────────────────────────────────────────
obs <- csv[, .(csv_rows   = .N,
               csv_member = uniqueN(uid),
               csv_dealer = uniqueN(dealer_id)), by = bet_date][order(bet_date)]

# ── 四、读 Layer B（制表符分隔，跳过查询正文，只取日期行）─────────────────
lb <- fread(LAYER_B, sep = "\t", header = FALSE, fill = TRUE,
            skip = 0L, showProgress = FALSE, colClasses = "character")
lb <- lb[grepl("^2026-\\d{2}-\\d{2}$", V1)]
if (!nrow(lb)) stop("Layer B 未解析出任何日期行，请检查该档是否为制表符分隔")
setnames(lb, 1:6, c("bet_date", "expected_rows", "expected_member",
                    "expected_dealer", "expected_rounds", "csv_status"))
lb[, bet_date := as.Date(bet_date)]
for (j in c("expected_rows","expected_member","expected_dealer","expected_rounds"))
  set(lb, j = j, value = as.numeric(lb[[j]]))
cat(sprintf("Layer B 解析：%d 行（IN_CSV %d · MISSING %d）\n", nrow(lb),
            sum(lb$csv_status == "IN_CSV"), sum(lb$csv_status == "MISSING_FROM_CSV")))

# ── 五、逐日 join，算 D1/D2/D3 ────────────────────────────────────────────
D <- merge(lb, obs, by = "bet_date", all.x = TRUE)[order(bet_date)]
D[, `:=`(D1 = csv_rows   / expected_rows,
         D2 = csv_member / expected_member,
         D3 = csv_dealer / expected_dealer)]

# ── 六、日历完整性：区间内有无缺日（判「连续前缀」抑或「中间有洞」）────────
cov  <- D[!is.na(csv_rows)]
holes <- if (nrow(cov)) setdiff(seq(min(cov$bet_date), max(cov$bet_date), by = "day"),
                                cov$bet_date) else integer(0)
cat("\n【日历完整性】\n")
cat(sprintf("  CSV 覆盖区间：%s ~ %s（%d 日）\n",
            min(cov$bet_date), max(cov$bet_date), nrow(cov)))
cat(sprintf("  区间内缺日：%s\n", if (length(holes))
  paste(as.Date(holes, origin = "1970-01-01"), collapse = ", ") else "无"))
cat(sprintf("  锁定分析窗 139 日中未覆盖：%d 日\n", sum(is.na(D$csv_rows))))

# ── 七、全表输出，一行不省 ────────────────────────────────────────────────
cat("\n【逐日 D1/D2/D3 · 全表 ", nrow(D), " 行，未截断】\n", sep = "")
prt <- D[, .(bet_date, csv_status,
             expected_rows, csv_rows, D1 = round(D1, 4),
             expected_member, csv_member, D2 = round(D2, 4),
             expected_dealer, csv_dealer, D3 = round(D3, 4))]
print(prt, nrows = Inf, class = FALSE)

# ── 八、缺口形态描述（只描述，不定性）────────────────────────────────────
gap_tot  <- cov[, sum(expected_rows - csv_rows)]
gap_last <- cov[.N, expected_rows - csv_rows]
cat("\n【47 日内部缺口之形态】\n")
cat(sprintf("  合计缺口          = %s 行（D1 合计 = %.6f）\n",
            format(gap_tot, big.mark = ","), cov[, sum(csv_rows)/sum(expected_rows)]))
cat(sprintf("  末日（%s）缺口   = %s 行，占合计 %.2f%%\n",
            cov[.N, bet_date], format(gap_last, big.mark = ","),
            100 * gap_last / max(gap_tot, 1)))
cat(sprintf("  非末日各日缺口：中位 %s ｜ 最大 %s ｜ 为负之日 %d\n",
            format(round(median(cov[-.N, expected_rows - csv_rows])), big.mark = ","),
            format(max(cov[-.N, expected_rows - csv_rows]), big.mark = ","),
            sum(cov[-.N, expected_rows - csv_rows] < 0)))
cat("  ⚠️ 缺口为负者示 CSV 多于 Expected —— 属基准时点漂移（BASE-009B），非导出缺失\n")
cat("  ⚠️ 本节只述形态。H1a / H1b 之判由 RED TEAM 作，脚本不代判\n")

# ── 九、三锚点与落盘 ──────────────────────────────────────────────────────
cat("\n【时间锚点 · GAP-S2-BASE-009B】\n")
cat("  observed_as_of（CSV 批次）:", observed_as_of, "\n")
cat("  expected_as_of（Layer B）  :", expected_as_of, "\n")
cat("  baseline_as_of（本次运行）:", baseline_as_of, "\n")
cat("  ⚠️ 三者不同期时，D 值 = 导出完整率 + ODS 时点漂移，二者未分离\n")

fwrite(D, OUT_TSV, sep = "\t")
cat("\n已落盘：", normalizePath(OUT_TSV), "（139 行，可直接回传）\n", sep = "")
