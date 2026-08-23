#!/usr/bin/env Rscript
# ══════════════════════════════════════════════════════════════════════════
# B-1 ／ B-2 · Registry SSOT 投影一致性 ＋ loader 六元组重锚  探针 v1.0.0
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
# ══════════════════════════════════════════════════════════════════════════
# 立件缘由：
#   B-1  Z2-03b 已立「YAML 为唯一真相源，CSV 系只读投影」，惟**未以代码强制**。
#        未强制前，据 CSV 准入列所作之判定一律判 S2 BLOCK。
#        → 本件出 projection-consistency 之机器证明，解 B-1。
#   B-2  registry_loader.R 在册登记 447 行 ／ MD5 c90f7547… ；
#        现档实测 499 行 ／ MD5 c99c01071c3b344bc72b1ca56b6c2f34 ——**差 52 行**。
#        → 本件出六元组重锚 ＋ 差异定性，解 B-2。
#
# ★ 本件只读，不改任何在册档；不 source loader（免其副作用），只静态解析。
#
# 用法：
#   Rscript 审计/工具/B1B2_registry_SSOT探针_v1.0.0.R
#   或于 R 内：source("审计/工具/B1B2_registry_SSOT探针_v1.0.0.R")
#
# 退出码：0 = 两项皆 PASS ／ 1 = 任一 FAIL
# ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  if (!requireNamespace("yaml",  quietly = TRUE)) stop("须先装 yaml 包")
  if (!requireNamespace("digest", quietly = TRUE)) stop("须先装 digest 包")
  library(yaml); library(digest)
})

# ── 路径（如与实际不符，改此三行即可）─────────────────────────────────
P_YAML   <- "规范/registry_risk_typology_v1.5.0.yaml"
P_CSV    <- "规范/registry_risk_typology_v1.5.0.csv"
P_LOADER <- "函数/registry_loader.R"

# ── 在册锚（改前登记，用于比对）──────────────────────────────────────
ANCHOR <- list(
  yaml   = list(lines = 1560L, bytes = 57938L, md5 = "f9eb7af3771cf5684dd9da8c01fe7e4a"),
  csv    = list(lines = NA_integer_, bytes = NA_integer_, md5 = NA_character_),   # ★ 从未登记
  loader = list(lines =  447L, bytes = NA_integer_,  md5 = "c90f7547")            # ★ 在册（前缀）
)

RESULT <- list(); FAILED <- FALSE
note <- function(gate, item, got, pass) {
  RESULT[[length(RESULT) + 1L]] <<- list(gate = gate, item = item, got = got, pass = pass)
  if (!isTRUE(pass)) FAILED <<- TRUE
}

six_tuple <- function(path) {
  if (!file.exists(path)) return(NULL)
  raw  <- readBin(path, "raw", file.info(path)$size)
  txt  <- rawToChar(raw); Encoding(txt) <- "UTF-8"
  crlf <- length(gregexpr("\r\n", txt, fixed = TRUE)[[1]])
  crlf <- if (identical(as.integer(gregexpr("\r\n", txt, fixed = TRUE)[[1]][1]), -1L)) 0L else crlf
  lf   <- length(gregexpr("\n", txt, fixed = TRUE)[[1]]) - crlf
  list(file = basename(path), lines = lf + crlf, bytes = length(raw),
       md5 = digest(raw, algo = "md5", serialize = FALSE),
       md5_lf = digest(charToRaw(gsub("\r\n", "\n", txt, fixed = TRUE)),
                       algo = "md5", serialize = FALSE),
       eol = if (crlf > 0L && lf == 0L) "CRLF" else if (crlf == 0L) "LF" else "MIXED",
       bom = identical(as.integer(raw[1:3]), c(239L, 187L, 191L)))
}

cat(strrep("=", 84), "\n")
cat("B-1 / B-2 · Registry SSOT 探针 v1.0.0\n")
cat("工作目录：", getwd(), "\n")
cat(strrep("=", 84), "\n\n")

# ══════════════════════════════════════════════════════════════════════════
# 第一部 · 六元组重锚（B-2 之主件）
# ══════════════════════════════════════════════════════════════════════════
cat("── 第一部 · 六元组重锚 ──\n\n")
tup <- lapply(c(yaml = P_YAML, csv = P_CSV, loader = P_LOADER), six_tuple)

for (k in names(tup)) {
  t <- tup[[k]]
  if (is.null(t)) { note("B2", paste0(k, " 档存在"), "档不存在", FALSE); next }
  cat(sprintf("  %-7s %s\n", k, t$file))
  cat(sprintf("          行 %-7s 字节 %-9s %s  BOM=%s\n",
              format(t$lines, big.mark = ","), format(t$bytes, big.mark = ","), t$eol, t$bom))
  cat(sprintf("          MD5(原样) %s\n", t$md5))
  cat(sprintf("          MD5(LF)   %s\n", t$md5_lf))
  a <- ANCHOR[[k]]
  if (is.na(a$md5)) {
    cat("          ⚠ 在册无登记 —— ★ 未登记之投影，无从证其系单向派生（B-1 之一部）\n")
    note("B2", paste0(k, " 在册锚"), "从未登记，须补", FALSE)
  } else if (startsWith(t$md5, a$md5) || identical(t$md5, a$md5)) {
    cat("          ✅ 与在册锚一致\n"); note("B2", paste0(k, " 血统"), "一致", TRUE)
  } else {
    cat(sprintf("          ❌ 失锚：在册 %s 行 / MD5 %s… ；现档 %s 行 / MD5 %s\n",
                a$lines, a$md5, t$lines, t$md5))
    cat(sprintf("          ★ 行差 %+d —— 须补 SC 重锚，禁静默沿用\n", t$lines - a$lines))
    note("B2", paste0(k, " 血统"), sprintf("失锚 行差 %+d", t$lines - a$lines), FALSE)
  }
  cat("\n")
}

# ══════════════════════════════════════════════════════════════════════════
# 第二部 · 投影一致性（B-1 之主件）
# ══════════════════════════════════════════════════════════════════════════
cat("── 第二部 · YAML → CSV 投影一致性 ──\n\n")

Y <- tryCatch(yaml::read_yaml(P_YAML), error = function(e) NULL)
D <- tryCatch(utils::read.csv(P_CSV, stringsAsFactors = FALSE, check.names = FALSE,
                              fileEncoding = "UTF-8"), error = function(e) NULL)

if (is.null(Y) || is.null(D)) {
  note("B1", "两侧可读", "至少一侧读取失败", FALSE)
} else {
  # ① 对象数一致？
  yk <- if (!is.null(Y$risk_typologies)) names(Y$risk_typologies) else
        if (!is.null(Y$typologies))      names(Y$typologies)      else character(0)
  cat(sprintf("  YAML 顶层键：%s\n", paste(utils::head(names(Y), 12), collapse = ", ")))
  cat(sprintf("  CSV  维度：%d 行 × %d 列\n", nrow(D), ncol(D)))
  cat(sprintf("  CSV  列名：%s\n\n", paste(utils::head(names(D), 14), collapse = ", ")))

  # ② ★ 核心检验：CSV 是否含 YAML 所无之准入列（双重真相之实证）
  csv_only_admit <- grep("^(admit_|ranking|scoring|trigger|enforcement)",
                         names(D), value = TRUE)
  cat(sprintf("  CSV 侧之准入／状态列（%d 个）：\n    %s\n\n",
              length(csv_only_admit), paste(csv_only_admit, collapse = ", ")))

  # ③ 逐类反查：该列之值能否自 YAML 复原
  cat("  ★ 逐列反查（CSV 之值能否自 YAML 复原）——此即 SSOT 之判据：\n")
  if (length(csv_only_admit) == 0L) {
    cat("    CSV 无准入列 → 双重真相之风险不成立\n")
    note("B1", "CSV 准入列", "无", TRUE)
  } else {
    yflat <- unlist(Y, use.names = TRUE)
    hit <- vapply(csv_only_admit, function(cn) any(grepl(cn, names(yflat), fixed = TRUE)),
                  logical(1))
    for (i in seq_along(csv_only_admit)) {
      cat(sprintf("    %-34s %s\n", csv_only_admit[i],
                  if (hit[i]) "✅ YAML 侧有同名键" else "❌ YAML 侧无同名键 —— CSV 独有"))
    }
    orphan <- csv_only_admit[!hit]
    cat("\n")
    if (length(orphan) == 0L) {
      cat("  ✅ CSV 之准入列皆可自 YAML 复原 —— 单向派生成立\n")
      note("B1", "投影一致性", "全部可复原", TRUE)
    } else {
      cat(sprintf("  ❌ %d 个 CSV 列于 YAML 侧无对应键：%s\n",
                  length(orphan), paste(orphan, collapse = ", ")))
      cat("  ★ 此即 Z2-03 所判之 OBSERVED 双重真相 —— 二侧词汇集合互异，\n")
      cat("    且皆可被机器读取。在 loader 侧断言强制之前，\n")
      cat("    **任何据 CSV 准入列所作之判定，一律判 S2 BLOCK**。\n")
      note("B1", "投影一致性", sprintf("%d 个孤儿列", length(orphan)), FALSE)
    }
  }
}

# ══════════════════════════════════════════════════════════════════════════
# 第三部 · loader 静态解析（不 source，免副作用）
# ══════════════════════════════════════════════════════════════════════════
cat("\n── 第三部 · loader 静态解析（★ 只读原文，不执行）──\n\n")
if (file.exists(P_LOADER)) {
  src <- readLines(P_LOADER, warn = FALSE, encoding = "UTF-8")
  cat(sprintf("  行数 %d\n", length(src)))
  fn <- grep("^\\s*[A-Za-z._][A-Za-z0-9._]*\\s*(<-|=)\\s*function", src, value = TRUE)
  cat(sprintf("  函数定义 %d 个：\n", length(fn)))
  for (f in utils::head(fn, 20)) cat(sprintf("    %s\n", trimws(substr(f, 1, 76))))
  reads_csv  <- any(grepl("read\\.csv|read_csv|fread", src))
  reads_yaml <- any(grepl("read_yaml|yaml\\.load", src))
  cat(sprintf("\n  读 YAML：%s    读 CSV：%s\n", reads_yaml, reads_csv))
  if (reads_csv && reads_yaml) {
    cat("  ⚠ **二者皆读** —— 若无「YAML 优先、冲突以 YAML 为准」之显式断言，\n")
    cat("    则 SSOT 未被代码强制，B-1 不得判 PASS。\n")
    has_assert <- any(grepl("stopifnot|assert|identical.*yaml|SSOT", src, ignore.case = TRUE))
    cat(sprintf("  一致性断言之痕迹：%s\n", if (has_assert) "有（须逐条核实其语义）" else "❌ 无"))
    note("B1", "loader 侧 SSOT 断言", if (has_assert) "有痕迹，须核实" else "无", has_assert)
  } else if (reads_yaml && !reads_csv) {
    cat("  ✅ 只读 YAML，不读 CSV —— SSOT 于 loader 侧天然成立\n")
    note("B1", "loader 侧 SSOT 断言", "只读 YAML", TRUE)
  } else {
    cat("  ⚠ 读取形态待核实\n")
    note("B1", "loader 侧 SSOT 断言", "形态待核实", FALSE)
  }
} else {
  note("B2", "loader 可读", "档不存在", FALSE)
}

# ══════════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 84), "\n", sep = "")
cat("验收汇总\n")
cat(strrep("=", 84), "\n")
for (r in RESULT)
  cat(sprintf("  %-4s %-34s %-28s %s\n", r$gate, r$item, r$got,
              if (isTRUE(r$pass)) "PASS ✅" else "FAIL ❌"))
cat(strrep("=", 84), "\n")
cat(sprintf("总判：%s\n", if (FAILED) "❌ 有 FAIL —— B-1／B-2 维持 BLOCK"
                          else "✅ 全 PASS —— B-1／B-2 可转 PASS"))
cat(strrep("=", 84), "\n")

# ── 三条锁 ────────────────────────────────────────────────────────────
cat("\n判读三锁：\n")
cat("  锁一 · 未登记之投影，无从证其系单向派生。\n")
cat("         CSV 从未登记六元组 —— 此本身即 B-1 之一部，非独立小事。\n")
cat("  锁二 · 「二者皆读」≠「SSOT 成立」。\n")
cat("         loader 若同读 YAML 与 CSV 而无显式优先断言，SSOT 仍未被强制。\n")
cat("  锁三 · 本件只静态解析，不 source loader。\n")
cat("         source 会触发其副作用（读档、建全局对象），污染探针自身之判读。\n")

if (!interactive() && length(commandArgs(trailingOnly = TRUE)) >= 0L)
  quit(status = if (FAILED) 1L else 0L, save = "no")
