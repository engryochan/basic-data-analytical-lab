# ==============================================================================
# R03b · 步骤 0（前置）：取件与核验
# ------------------------------------------------------------------------------
# 目的：**定位**受审的那一份 R03b 导出件，并证明它就是渲染时所用者。
#
# ★★ 铁律：不得重导 ★★
#   该 CSV 是 2026-08-11 的导出物，是 GAP-S1-WINDOW-005 的**受审对象本身**。
#   重跑 §R03b 会得到 2026-08-14 的新件，47 日窗口、76,413 内部缺口、
#   H1a/H1b 之分立即全部湮灭。本脚本只读、只核，绝不生成任何 CSV。
# ==============================================================================

suppressPackageStartupMessages({library(data.table); library(tools)})
path <- 'C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系/'
SEARCH_ROOTS <- c(".", "数据库", "..", "~/Downloads", "~/Documents")
TARGET <- paste0(path, "数据库/R03b_player_dealer_daily.csv")
LAYER_B  <- paste0(path, "Layer_B_R03b_expected_daily.tsv")
OUT_TSV  <- paste0(path, "R03b_D1D2D3_daily.tsv")


## 渲染实测锚点（主方案 [qual-layer] 现算所得，2026-08-14 渲染）
ANCHOR_ROWS  <- 6143388L    # L0 事实层行数
ANCHOR_SENT  <- 308009L     # SQL 自述 SENTINEL_DEALER
ANCHOR_L1    <- 5683734L    # L1 合格层

# ── 一、找档 ──────────────────────────────────────────────────────────────
cat("【一、定位】\n")
hits <- unique(unlist(lapply(SEARCH_ROOTS, function(r) {
  r <- path.expand(r)
  if (!dir.exists(r)) return(character(0))
  list.files(r, pattern = paste0("^", TARGET, "$"),
             recursive = TRUE, full.names = TRUE)
})))
if (!length(hits)) stop(
  "未找到 ", TARGET, "。\n",
  "  ⚠️ 找不到时**不要重新导出** —— 重导会毁掉证据。\n",
  "  请先在文件系统全盘搜索该档名，或确认它是否曾被改名/归档。")
if (length(hits) > 1L) {
  cat("  ⚠️ 找到多份同名档，须先辨明哪一份是渲染所用：\n")
  for (h in hits) cat(sprintf("     %s  (%.1f MB, %s)\n", h,
    file.info(h)$size/1024^2, format(file.info(h)$mtime, "%Y-%m-%d %H:%M")))
}

# ── 二、逐份算六元组并与锚点对账 ─────────────────────────────────────────
cat("\n【二、六元组与锚点对账】\n")
ok_path <- NA_character_
for (h in hits) {
  fi  <- file.info(h)
  md5 <- as.character(md5sum(h))
  ## 行数：不载入内存，逐块数换行
  con <- file(h, "rb"); n <- 0L
  repeat { b <- readBin(con, "raw", 1e7); if (!length(b)) break
           n <- n + sum(b == as.raw(0x0a)) }
  close(con)
  hdr  <- names(fread(h, nrows = 0L, showProgress = FALSE))
  data_rows <- n - 1L   # 减表头；若末行无换行则实际再 +1，下方一并判

  cat(sprintf("\n  档   : %s\n", h))
  cat(sprintf("  字节 : %s\n", format(fi$size, big.mark = ",")))
  cat(sprintf("  MD5  : %s\n", md5))
  cat(sprintf("  列数 : %d  %s\n", length(hdr),
              if (length(hdr) == 24L) "✅ 与 SCHEMA 24 列相符" else "⚠️ 与渲染实测 24 列不符"))
  cat(sprintf("  数据行: %s ~ %s\n", format(data_rows, big.mark = ","),
              format(data_rows + 1L, big.mark = ",")))
  cat(sprintf("  锚点  : %s（渲染实测 L0）\n", format(ANCHOR_ROWS, big.mark = ",")))

  if (ANCHOR_ROWS %in% c(data_rows, data_rows + 1L)) {
    cat("  判定  : ✅ 行数命中锚点——此即渲染所用之件\n"); ok_path <- h
  } else {
    cat(sprintf("  判定  : ❌ 行数差 %s —— **此件非受审对象，不得用于本次审计**\n",
                format(data_rows - ANCHOR_ROWS, big.mark = ",")))
    cat("          若全部候选皆不命中，须停止并回报，切勿以新导出件顶替\n")
  }
  if ("comparison_id" %in% hdr) {
    cid <- unique(fread(h, select = "comparison_id", showProgress = FALSE)$comparison_id)
    cat(sprintf("  批次号: %s\n", paste(cid, collapse = " | ")))
    cat("          ⚠️ 此为**文件自述**，只证「自称某版本」，不证导出作业确于该日完成\n")
  }
}
if (is.na(ok_path)) stop("无一候选命中锚点，审计中止。")
cat(sprintf("\n  ★ 受审件已锁定：%s\n", ok_path))

# ── 三、Layer B 就位核验 ─────────────────────────────────────────────────
cat("\n【三、Layer B】\n")
if (!file.exists(LAYER_B)) {
  cat("  ❌ 未就位。请将 Superset 中 Layer B 的 139 行结果另存为：\n")
  cat("     ", LAYER_B, "（制表符分隔，UTF-8，含表头）\n")
} else {
  lb <- fread(LAYER_B, sep = "\t", showProgress = FALSE)
  s  <- sum(as.numeric(lb$expected_n_rows))
  cat(sprintf("  行数 : %d %s\n", nrow(lb), if (nrow(lb) == 139L) "✅" else "❌ 应为 139"))
  cat(sprintf("  全窗 expected 合计 : %s %s\n", format(s, big.mark = ","),
              if (s == 18139550) "✅ 与 SQL 总包段首自记 18,139,550 逐位相符" else "⚠️ 与 18,139,550 不符"))
  cat(sprintf("  IN_CSV %d 日 · MISSING %d 日\n",
              sum(lb$csv_status == "IN_CSV"), sum(lb$csv_status == "MISSING_FROM_CSV")))
}

cat("\n两件皆 ✅ 后，再跑 R03b_step1_daily_density_v2.R\n")
