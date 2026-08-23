#!/usr/bin/env Rscript
# ══════════════════════════════════════════════════════════════════════════
# B-1 ／ B-2 · Registry SSOT 投影一致性 ＋ loader 六元组重锚  探针 v1.0.1
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
# ══════════════════════════════════════════════════════════════════════════
# 【v1.0.0 → v1.0.1 · 一项斧正，系我方最严重之一犯】
#   SC-10（★ 假 PASS）：v1.0.0 之第二部报「✅ CSV 之准入列皆可自 YAML 复原
#     —— 单向派生成立」。**该判词过强，且系伪证。**
#     其实际所为仅：
#         hit <- any(grepl(cn, names(yflat), fixed = TRUE))
#     —— **只查「YAML 侧有无同名键」，未查任何一个值是否相等。**
#     CSV 之 admit_to_risk_decision 若为 TRUE 而 YAML 同键为 FALSE，
#     v1.0.0 照样报 ✅。
#   ★★ 立锁五十：**假 PASS 之危害甚于 FAIL。**
#     FAIL 引人去查；假 PASS 令人**停止查**。
#     故凡判词曰「一致／成立／可复原」者，须逐值比对，禁以名称对齐代之。
#   → v1.0.0 之 B1 投影一致性 PASS **正式撤回**，改判 NAME_ALIGNMENT_ONLY。
#
# 【v1.0.1 之三层验证（层层递进，禁跳级）】
#   L1 NAME_ALIGNMENT    列名是否对齐            （v1.0.0 只到此层）
#   L2 KEY_ALIGNMENT     行键是否可一一对应      （type_id × criterion_column）
#   L3 VALUE_PROJECTION  ★ 逐值是否相等          （本版之核心）
#   ★ L1 PASS 而 L2／L3 FAIL 者，仍判 BLOCK。
#
# 【本件只读，不改任何在册档；不 source loader（免其副作用），只静态解析。】
#
# 用法：
#   Rscript 审计/工具/B1B2_registry_SSOT探针_v1.0.1.R
# 退出码：0 = 三层皆 PASS ／ 1 = 任一 FAIL
# ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  if (!requireNamespace("yaml",   quietly = TRUE)) stop("须先装 yaml 包")
  if (!requireNamespace("digest", quietly = TRUE)) stop("须先装 digest 包")
  library(yaml); library(digest)
})

## ── 路径（如与实际不符，改此三行）────────────────────────────────────
P_YAML   <- "规范/registry_risk_typology_v1.5.0.yaml"
P_CSV    <- "规范/registry_risk_typology_v1.5.0.csv"
P_LOADER <- "函数/registry_loader.R"

## ── 在册锚 ────────────────────────────────────────────────────────────
ANCHOR <- list(
  yaml   = list(lines = 1560L, md5 = "f9eb7af3771cf5684dd9da8c01fe7e4a"),
  csv    = list(lines = NA_integer_, md5 = NA_character_),   # ★ 从未登记
  loader = list(lines =  447L, md5 = "c90f7547")             # ★ 前缀
)

## ── 九个准入／状态列（v1.0.0 实测所得）───────────────────────────────
ADMIT_COLS <- c("admit_to_feature_scoring", "admit_to_risk_decision",
                "admit_to_scoring", "admit_to_profile", "ranking",
                "scoring", "trigger", "enforcement", "admit_to_control")

RESULT <- list(); FAILED <- FALSE
note <- function(gate, layer, item, got, pass) {
  RESULT[[length(RESULT) + 1L]] <<- list(gate = gate, layer = layer,
                                         item = item, got = got, pass = pass)
  if (!isTRUE(pass)) FAILED <<- TRUE
}

six_tuple <- function(path) {
  if (!file.exists(path)) return(NULL)
  raw  <- readBin(path, "raw", file.info(path)$size)
  txt  <- rawToChar(raw); Encoding(txt) <- "UTF-8"
  crlf <- if (identical(as.integer(gregexpr("\r\n", txt, fixed = TRUE)[[1]][1]), -1L)) 0L
          else length(gregexpr("\r\n", txt, fixed = TRUE)[[1]])
  lf   <- length(gregexpr("\n", txt, fixed = TRUE)[[1]]) - crlf
  list(file = basename(path), lines = lf + crlf, bytes = length(raw),
       md5 = digest(raw, algo = "md5", serialize = FALSE),
       eol = if (crlf > 0L && lf == 0L) "CRLF" else if (crlf == 0L) "LF" else "MIXED",
       bom = identical(as.integer(raw[1:3]), c(239L, 187L, 191L)))
}

## ★ 规范化：TRUE/true/T/1/YES → "TRUE"；FALSE/false/F/0/NO → "FALSE"；空 → NA
norm_val <- function(x) {
  s <- toupper(trimws(as.character(x)))
  s[s %in% c("TRUE",  "T", "1", "YES", "Y")] <- "TRUE"
  s[s %in% c("FALSE", "F", "0", "NO",  "N")] <- "FALSE"
  s[s %in% c("", "NA", "NULL", "NONE", "-")] <- NA_character_
  s
}

cat(strrep("=", 88), "\n")
cat("B-1 / B-2 · Registry SSOT 探针 v1.0.1（★ 验值不验名）\n")
cat("工作目录：", getwd(), "\n")
cat(strrep("=", 88), "\n\n")

# ══════════════════════════════════════════════════════════════════════════
# 第一部 · 六元组重锚（B-2）
# ══════════════════════════════════════════════════════════════════════════
cat("── 第一部 · 六元组重锚 ──\n\n")
tup <- lapply(c(yaml = P_YAML, csv = P_CSV, loader = P_LOADER), six_tuple)
for (k in names(tup)) {
  t <- tup[[k]]
  if (is.null(t)) { note("B2", "L0", paste0(k, " 档存在"), "档不存在", FALSE); next }
  cat(sprintf("  %-7s %s\n", k, t$file))
  cat(sprintf("          行 %-7s 字节 %-9s %-5s BOM=%s\n",
              format(t$lines, big.mark = ","), format(t$bytes, big.mark = ","), t$eol, t$bom))
  cat(sprintf("          MD5 %s\n", t$md5))
  a <- ANCHOR[[k]]
  if (is.na(a$md5)) {
    cat("          ⚠ 在册无登记 —— 须补六元组（★ 含 BOM 状态，免日后字节比对生静默差异）\n")
    note("B2", "L0", paste0(k, " 在册锚"), "从未登记", FALSE)
  } else if (startsWith(t$md5, a$md5)) {
    cat("          ✅ 与在册锚一致\n"); note("B2", "L0", paste0(k, " 血统"), "一致", TRUE)
  } else {
    cat(sprintf("          ❌ 失锚：在册 %s 行 / %s… ；现档 %s 行 / %s\n",
                a$lines, a$md5, t$lines, t$md5))
    note("B2", "L0", paste0(k, " 血统"),
         sprintf("失锚 行差 %+d", t$lines - a$lines), FALSE)
  }
  cat("\n")
}

# ══════════════════════════════════════════════════════════════════════════
# 第二部 · 三层投影验证（B-1 · 本版之核心）
# ══════════════════════════════════════════════════════════════════════════
cat("── 第二部 · 三层投影验证（L1 名 → L2 键 → L3 值）──\n\n")

Y <- tryCatch(yaml::read_yaml(P_YAML), error = function(e) NULL)
D <- tryCatch(utils::read.csv(P_CSV, stringsAsFactors = FALSE, check.names = FALSE,
                              fileEncoding = "UTF-8-BOM"), error = function(e)
      tryCatch(utils::read.csv(P_CSV, stringsAsFactors = FALSE, check.names = FALSE,
                               fileEncoding = "UTF-8"), error = function(e2) NULL))

if (is.null(Y) || is.null(D)) {
  note("B1", "L0", "两侧可读", "至少一侧读取失败", FALSE)
} else {
  cat(sprintf("  CSV %d 行（数据行）× %d 列   ★ 物理行数另含表头，与六元组之行数差 1\n\n",
              nrow(D), ncol(D)))

  ## ── L1 · NAME_ALIGNMENT ────────────────────────────────────────────
  cat("  【L1 · NAME_ALIGNMENT】列名对齐\n")
  yflat  <- unlist(Y, use.names = TRUE)
  present <- intersect(ADMIT_COLS, names(D))
  hit_name <- vapply(present, function(cn)
                any(grepl(cn, names(yflat), fixed = TRUE)), logical(1))
  cat(sprintf("    受检准入列 %d ／ YAML 侧有同名键 %d\n", length(present), sum(hit_name)))
  orphan <- present[!hit_name]
  if (length(orphan)) {
    cat(sprintf("    ❌ 孤儿列 %d：%s\n", length(orphan), paste(orphan, collapse = ", ")))
    note("B1", "L1", "NAME_ALIGNMENT", sprintf("%d 孤儿列", length(orphan)), FALSE)
  } else {
    cat("    ✅ 无孤儿列（★ 此层只证列名对齐，**不证值可复原**）\n")
    note("B1", "L1", "NAME_ALIGNMENT", "无孤儿列", TRUE)
  }

  ## ── L2 · KEY_ALIGNMENT ─────────────────────────────────────────────
  cat("\n  【L2 · KEY_ALIGNMENT】行键一一对应\n")
  TY <- if (!is.null(Y$typologies)) Y$typologies else NULL
  if (is.null(TY)) {
    cat("    ❌ YAML 无 typologies 节点 —— 无从建行键\n")
    note("B1", "L2", "KEY_ALIGNMENT", "YAML 无 typologies", FALSE)
  } else {
    ## YAML 侧：逐 typology × 逐 criterion 展平为行键
    ykeys <- character(0); yrows <- list()
    for (ti in seq_along(TY)) {
      tt <- TY[[ti]]
      tid <- if (!is.null(tt$type_id)) tt$type_id else names(TY)[ti]
      crs <- if (!is.null(tt$criteria)) tt$criteria else list(tt)
      for (ci in seq_along(crs)) {
        cc <- crs[[ci]]
        col <- if (!is.null(cc$criterion_column)) cc$criterion_column else
               if (!is.null(names(crs))) names(crs)[ci] else as.character(ci)
        k <- paste0(tid, "||", col)
        ykeys <- c(ykeys, k); yrows[[k]] <- cc
      }
    }
    ckeys <- if (all(c("type_id", "criterion_column") %in% names(D)))
               paste0(trimws(D$type_id), "||", trimws(D$criterion_column)) else character(0)
    cat(sprintf("    YAML 行键 %d ／ CSV 行键 %d\n", length(ykeys), length(ckeys)))
    only_c <- setdiff(ckeys, ykeys); only_y <- setdiff(ykeys, ckeys)
    cat(sprintf("    仅 CSV 有 %d ／ 仅 YAML 有 %d ／ 交集 %d\n",
                length(only_c), length(only_y), length(intersect(ckeys, ykeys))))
    if (length(only_c)) cat(sprintf("    ❌ CSV 独有前 5：%s\n",
                                    paste(utils::head(only_c, 5), collapse = " | ")))
    if (length(only_y)) cat(sprintf("    ❌ YAML 独有前 5：%s\n",
                                    paste(utils::head(only_y, 5), collapse = " | ")))
    ok2 <- length(only_c) == 0L && length(only_y) == 0L
    cat(if (ok2) "    ✅ 行键一一对应\n" else "    ❌ 行键不对应 —— L3 无从逐值比对\n")
    note("B1", "L2", "KEY_ALIGNMENT",
         sprintf("仅CSV %d ／ 仅YAML %d", length(only_c), length(only_y)), ok2)

    ## ── L3 · VALUE_PROJECTION ★ 本版之核心 ──────────────────────────
    cat("\n  【L3 · VALUE_PROJECTION】★ 逐值比对（v1.0.0 从未做过此层）\n")
    common <- intersect(ckeys, ykeys)
    if (!length(common)) {
      cat("    ❌ 无共同行键 —— 无从比对\n")
      note("B1", "L3", "VALUE_PROJECTION", "无共同行键", FALSE)
    } else {
      tot_cmp <- 0L; tot_mis <- 0L; detail <- list()
      for (col in present) {
        cv <- norm_val(D[[col]][match(common, ckeys)])
        yv <- norm_val(vapply(common, function(k) {
                r <- yrows[[k]]
                v <- if (!is.null(r[[col]])) r[[col]] else NA
                if (length(v) != 1L) NA_character_ else as.character(v)
              }, character(1)))
        both <- !is.na(cv) & !is.na(yv)
        n_cmp <- sum(both); n_mis <- sum(cv[both] != yv[both])
        n_yna <- sum(is.na(yv) & !is.na(cv))
        tot_cmp <- tot_cmp + n_cmp; tot_mis <- tot_mis + n_mis
        detail[[col]] <- c(cmp = n_cmp, mis = n_mis, yna = n_yna)
        cat(sprintf("    %-28s 可比 %3d  不符 %3d  YAML侧缺值 %3d  %s\n",
                    col, n_cmp, n_mis, n_yna,
                    if (n_cmp == 0L) "⚠ 无可比之值" else if (n_mis == 0L) "✅" else "❌"))
      }
      cat(sprintf("\n    合计：可比 %d ／ 不符 %d\n", tot_cmp, tot_mis))
      if (tot_cmp == 0L) {
        cat("    ❌ **无任何值可比** —— YAML 侧于 criterion 层未存准入值，\n")
        cat("       故 CSV 之准入列**无从自 YAML 复原**。此即 SC-25 之实况。\n")
        note("B1", "L3", "VALUE_PROJECTION", "可比值为 0", FALSE)
      } else if (tot_mis == 0L) {
        cat("    ✅ 逐值全等 —— 投影一致性成立\n")
        note("B1", "L3", "VALUE_PROJECTION", sprintf("%d 值全等", tot_cmp), TRUE)
      } else {
        cat(sprintf("    ❌ %d 处值不符 —— 双重真相已成实况\n", tot_mis))
        note("B1", "L3", "VALUE_PROJECTION", sprintf("%d/%d 不符", tot_mis, tot_cmp), FALSE)
      }
    }
  }
}

# ══════════════════════════════════════════════════════════════════════════
# 第三部 · loader 静态解析（不 source）
# ══════════════════════════════════════════════════════════════════════════
cat("\n── 第三部 · loader 静态解析（★ 只读原文，不执行）──\n\n")
if (file.exists(P_LOADER)) {
  src <- readLines(P_LOADER, warn = FALSE, encoding = "UTF-8")
  cat(sprintf("  行数 %d ／ 函数定义 %d 个\n", length(src),
              length(grep("^\\s*[A-Za-z._][A-Za-z0-9._]*\\s*(<-|=)\\s*function", src))))
  reads_csv  <- any(grepl("read\\.csv|read_csv|fread", src))
  reads_yaml <- any(grepl("read_yaml|yaml\\.load", src))
  has_assert <- any(grepl("stopifnot|assertthat|assert_that", src))
  ## ★ 只认真正之断言函数，不认「SSOT」字样——文字非强制
  cat(sprintf("  读 YAML：%s   读 CSV：%s   断言函数：%s\n",
              reads_yaml, reads_csv, if (has_assert) "有" else "❌ 无"))
  if (reads_csv && reads_yaml && !has_assert) {
    cat("  ❌ 二者皆读而无断言 —— SSOT 未被代码强制\n")
    cat("  ★ 注：'SSOT' 字样出现于注释不算强制。**文字不是断言。**\n")
    note("B1", "L4", "loader SSOT 断言", "二者皆读 · 零断言", FALSE)
  } else if (reads_yaml && !reads_csv) {
    cat("  ✅ 只读 YAML —— SSOT 于 loader 侧天然成立\n")
    note("B1", "L4", "loader SSOT 断言", "只读 YAML", TRUE)
  } else if (has_assert) {
    cat("  ⚠ 有断言函数 —— 须逐条核实其确系一致性断言，非他用\n")
    note("B1", "L4", "loader SSOT 断言", "有断言，待核实", FALSE)
  } else {
    note("B1", "L4", "loader SSOT 断言", "形态待核实", FALSE)
  }
} else {
  note("B2", "L0", "loader 可读", "档不存在", FALSE)
}

# ══════════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 88), "\n", sep = "")
cat("验收汇总\n")
cat(strrep("=", 88), "\n")
for (r in RESULT)
  cat(sprintf("  %-4s %-4s %-30s %-30s %s\n", r$gate, r$layer, r$item, r$got,
              if (isTRUE(r$pass)) "PASS ✅" else "FAIL ❌"))
cat(strrep("=", 88), "\n")
cat(sprintf("总判：%s\n", if (FAILED) "❌ 有 FAIL —— B-1／B-2 维持 BLOCK"
                          else "✅ 三层皆 PASS —— B-1／B-2 可转 PASS"))
cat(strrep("=", 88), "\n")

cat("\n判读四锁：\n")
cat("  锁五十 · **假 PASS 之危害甚于 FAIL。**\n")
cat("           FAIL 引人去查；假 PASS 令人**停止查**。\n")
cat("           v1.0.0 之「单向派生成立」即假 PASS —— 只验名而报值可复原。\n")
cat("  锁五十一 · 三层不得跳级：L1 名 → L2 键 → L3 值。\n")
cat("           L1 PASS 而 L2／L3 未验者，**只得书 NAME_ALIGNMENT_ONLY**。\n")
cat("  锁五十二 · 文字不是断言。\n")
cat("           注释中之「SSOT」「唯一真相源」字样，不构成代码强制。\n")
cat("           只认 stopifnot／assertthat 之属。\n")
cat("  锁五十三 · 「可比值为 0」是最危险之结果，非中性。\n")
cat("           它意味 CSV 之准入列**根本无从自 YAML 复原**——\n")
cat("           二侧各自为政而无人察觉，正是 SC-25 之实况。\n")

if (!interactive())
  quit(status = if (FAILED) 1L else 0L, save = "no")
