#!/usr/bin/env Rscript
# ══════════════════════════════════════════════════════════════════════════
# B-1 ／ B-2 · Registry SSOT 投影一致性 ＋ loader 六元组重锚  探针 v1.0.3
# ★ ARTIFACT CLASS = A2 DIAGNOSTIC_TOOL · canonical = false · 置 审计/工具/
# ══════════════════════════════════════════════════════════════════════════
# 【v1.0.1 → v1.0.2 · 三项斧正，皆我方缺陷】
#   SC-11（★ 崩溃 · R4-SEMANTIC-02 之自犯）：v1.0.1 于 L2 崩，报
#       错误于 `[[<-`(`*tmp*`, k, value = cc): 在1层没有这一索引
#     崩因：**我假设了 YAML 结构而未读它。**
#         我假设  typologies[i].criteria[j].criterion_column
#         实际是  typologies[i].criterion_columns[j].column
#     两处键名皆错，遂 col 取到 character(0)，yrows[[character(0)]] 报错。
#     ★ R4-SEMANTIC-02（未读结构即断言其性质）系本项目常设门禁，
#       我于别处反复以之检查数据，**写自己的代码时却没用**。
#     → v1.0.2 增 L0 结构探针：**先印实际结构，再据以遍历。**
#
#   SC-12（★ 又一假 PASS）：v1.0.1 之 L3 只三态（可比 0 ／ 全等 ／ 有不符）。
#     预跑显示实测将落「逐值全等」而报 ✅ 投影一致性成立——**又是假 PASS。**
#     实况是：277 值全等，惟 **criterion 层可比值为 0，全部取自 class 层**。
#     意即 CSV 之 66 行判据，其准入值皆自所属 typology 继承；
#     **YAML 之 criterion_columns 内根本没有准入字段。**
#     → 补第四态 VALUE_PROJECTION_CLASS_ONLY，并逐列报来源层计数。
#
#   SC-13（防崩）：所有遍历改防御式，错误转为 FAIL 行而非 stop()。
#     ★ 探针崩溃 = 无判读；宁可逐项报 FAIL，不可中途停止执行。
#
# 【v1.0.2 → v1.0.3 · 一项斧正 · ★ 假 FAIL】
#   SC-14（★ 假 FAIL · 危害在于「引导错误修复」）：
#     v1.0.2 之 L4 只搜 stopifnot|assertthat|assert_that，遂报「断言函数：❌ 无」。
#     **实况：loader 有 19 处 stop()，其中 5 处正是 YAML↔CSV 一致性断言：**
#         行 189  类型集合不一致——仅YAML有：… 仅CSV有：…
#         行 195  %s 之 gate 不一致：YAML=%s CSV=%s
#         行 198  %s 之 admit_to_scoring 不一致
#         行 201  %s 之判据列集合不一致
#         行 479  【registry·counts】YAML 声明 %s，CSV 现算 %s —— 双档分家，停止渲染
#     ★★ 假 FAIL 之害不在噪音，在于**引导错误修复**：
#       若照此 FAIL 去「补断言」，会在已有五处一致性 stop() 之上再叠一层，
#       **造成重复强制或语义冲突** —— 修复比原缺陷更危险。
#   ★ 立锁五十六：**断言之形式不止一种。**
#     stop() ／ stopifnot() ／ if(...) stop(...) ／ tryCatch(error=stop) 皆是强制。
#     判「有无断言」须看其**语义**（不符则中止），非看其**函数名**。
#   → v1.0.3 之 L4 改为**语义分类**，六态：
#       CONSISTENCY  一致性断言 ★ 此即 SSOT 之代码强制
#       VERSION      版本核验
#       EXISTENCE    存在性核验
#       MODE         运行模式核验
#       WRAP         错误包装（tryCatch 之转抛，非独立断言）
#       OTHER        未归类，须人查
#     判 PASS 之条件：**CONSISTENCY ≥ 1**，非「有无 stopifnot」。
#
# 【★★ 本版之核心发现（预跑所示，实测为准）】
#   criterion-level admission **不存在**——非投影损坏，系该层字段未建。
#   B-1 之实质遂由「二侧不一致」改判为「**判据级准入语义缺失**」。
#   一个类别之五条判据，若其中一条该准入、四条不该，**现有结构表达不了**。
#
# 【四层验证】
#   L0 STRUCTURE_PROBE   ★ 新增 —— 先印 YAML 实际结构
#   L1 NAME_ALIGNMENT    列名对齐
#   L2 KEY_ALIGNMENT     行键一一对应（type_id × column）
#   L3 VALUE_PROJECTION  逐值比对 ＋ **来源层计数**（criterion vs class）
#
# 【本件只读；不 source loader；不改任何在册档。】
# 用法：Rscript 审计/工具/B1B2_registry_SSOT探针_v1.0.3.R
# 退出码：0 = 全 PASS ／ 1 = 任一 FAIL
# ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  if (!requireNamespace("yaml",   quietly = TRUE)) stop("须先装 yaml 包")
  if (!requireNamespace("digest", quietly = TRUE)) stop("须先装 digest 包")
  library(yaml); library(digest)
})

P_YAML   <- "规范/registry_risk_typology_v1.5.0.yaml"
P_CSV    <- "规范/registry_risk_typology_v1.5.0.csv"
P_LOADER <- "函数/registry_loader.R"

ANCHOR <- list(
  yaml   = list(lines = 1560L, md5 = "f9eb7af3771cf5684dd9da8c01fe7e4a"),
  csv    = list(lines = NA_integer_, md5 = NA_character_),
  loader = list(lines =  447L, md5 = "c90f7547")
)

ADMIT_COLS <- c("admit_to_feature_scoring", "admit_to_risk_decision",
                "admit_to_scoring", "admit_to_profile", "ranking",
                "scoring", "trigger", "enforcement", "admit_to_control")

RESULT <- list(); FAILED <- FALSE
note <- function(gate, layer, item, got, pass) {
  RESULT[[length(RESULT) + 1L]] <<- list(gate = gate, layer = layer,
                                         item = item, got = got, pass = pass)
  if (!isTRUE(pass)) FAILED <<- TRUE
}
## ★ SC-13 · 防崩包装：任何一段出错皆转 FAIL，不中止全局
safe <- function(tag, expr, gate = "B1", layer = "--") {
  tryCatch(expr, error = function(e) {
    cat(sprintf("    ❌ 本段执行出错：%s\n", conditionMessage(e)))
    note(gate, layer, tag, paste0("执行出错：", conditionMessage(e)), FALSE)
    invisible(NULL)
  })
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

norm_val <- function(x) {
  s <- toupper(trimws(as.character(x)))
  s[s %in% c("TRUE",  "T", "1", "YES", "Y")] <- "TRUE"
  s[s %in% c("FALSE", "F", "0", "NO",  "N")] <- "FALSE"
  s[s %in% c("", "NA", "NULL", "NONE", "-")] <- NA_character_
  s
}

cat(strrep("=", 92), "\n")
cat("B-1 / B-2 · Registry SSOT 探针 v1.0.3（★ 结构先探 · 来源层计数 · 防崩）\n")
cat("工作目录：", getwd(), "\n")
cat(strrep("=", 92), "\n\n")

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
    cat("          ⚠ 在册无登记 —— 须补六元组（★ 含 BOM 状态）\n")
    note("B2", "L0", paste0(k, " 在册锚"), "从未登记", FALSE)
  } else if (startsWith(t$md5, a$md5)) {
    cat("          ✅ 与在册锚一致\n"); note("B2", "L0", paste0(k, " 血统"), "一致", TRUE)
  } else {
    cat(sprintf("          ❌ 失锚：在册 %s 行 / %s… ；现档 %s 行\n", a$lines, a$md5, t$lines))
    note("B2", "L0", paste0(k, " 血统"), sprintf("失锚 行差 %+d", t$lines - a$lines), FALSE)
  }
  cat("\n")
}

# ══════════════════════════════════════════════════════════════════════════
# 第二部 · 四层验证
# ══════════════════════════════════════════════════════════════════════════
cat("── 第二部 · 四层验证（L0 结构 → L1 名 → L2 键 → L3 值）──\n\n")

Y <- tryCatch(yaml::read_yaml(P_YAML), error = function(e) NULL)
D <- tryCatch(utils::read.csv(P_CSV, stringsAsFactors = FALSE, check.names = FALSE,
                              fileEncoding = "UTF-8-BOM"), error = function(e)
      tryCatch(utils::read.csv(P_CSV, stringsAsFactors = FALSE, check.names = FALSE,
                               fileEncoding = "UTF-8"), error = function(e2) NULL))

if (is.null(Y) || is.null(D)) {
  note("B1", "L0", "两侧可读", "至少一侧读取失败", FALSE)
} else {

  ## ── L0 · STRUCTURE_PROBE ★ 新增：先印实际结构，禁凭假设遍历 ────────
  cat("  【L0 · STRUCTURE_PROBE】★ 先读实际结构（v1.0.1 之崩因即在缺此层）\n")
  safe("L0 结构探针", {
    cat(sprintf("    YAML 顶层键 %d 个：%s …\n", length(names(Y)),
                paste(utils::head(names(Y), 8), collapse = ", ")))
    TY <- Y$typologies
    cat(sprintf("    typologies 类型 %s ／ 长度 %d\n", class(TY)[1], length(TY)))
    if (length(TY)) {
      t0 <- TY[[1]]
      cat(sprintf("    首元之键（%d 个）：%s\n", length(names(t0)),
                  paste(utils::head(names(t0), 10), collapse = ", ")))
      cri_key <- intersect(c("criterion_columns", "criteria", "criterions"), names(t0))
      cat(sprintf("    ★ 判据容器键 = %s\n",
                  if (length(cri_key)) cri_key[1] else "（未寻得）"))
      if (length(cri_key)) {
        c0 <- t0[[cri_key[1]]][[1]]
        cat(sprintf("    ★ 判据元素之键：%s\n", paste(names(c0), collapse = ", ")))
        col_key <- intersect(c("column", "criterion_column", "name"), names(c0))
        cat(sprintf("    ★ 判据列名键 = %s\n",
                    if (length(col_key)) col_key[1] else "（未寻得）"))
      }
    }
    cat(sprintf("    CSV %d 行（数据行）× %d 列  ★ 物理行另含表头，与六元组差 1\n",
                nrow(D), ncol(D)))
    note("B1", "L0", "STRUCTURE_PROBE", "结构已读", TRUE)
  }, layer = "L0")

  ## ── L1 · NAME_ALIGNMENT ─────────────────────────────────────────────
  cat("\n  【L1 · NAME_ALIGNMENT】列名对齐\n")
  present <- intersect(ADMIT_COLS, names(D))
  safe("L1", {
    yflat <- unlist(Y, use.names = TRUE)
    hit   <- vapply(present, function(cn) any(grepl(cn, names(yflat), fixed = TRUE)), logical(1))
    cat(sprintf("    受检准入列 %d ／ YAML 侧有同名键 %d\n", length(present), sum(hit)))
    orphan <- present[!hit]
    if (length(orphan)) {
      cat(sprintf("    ❌ 孤儿列 %d：%s\n", length(orphan), paste(orphan, collapse = ", ")))
      note("B1", "L1", "NAME_ALIGNMENT", sprintf("%d 孤儿列", length(orphan)), FALSE)
    } else {
      cat("    ✅ 无孤儿列（★ 只证列名对齐，**不证值可复原，亦不证其位于判据层**）\n")
      note("B1", "L1", "NAME_ALIGNMENT", "无孤儿列", TRUE)
    }
  }, layer = "L1")

  ## ── L2 · KEY_ALIGNMENT（★ 键名已据 L0 实测修正）────────────────────
  cat("\n  【L2 · KEY_ALIGNMENT】行键一一对应（type_id × column）\n")
  ykeys <- character(0); yrow_t <- list(); yrow_c <- list()
  safe("L2", {
    TY <- Y$typologies
    for (ti in seq_along(TY)) {
      tt  <- TY[[ti]]
      tid <- if (!is.null(tt$type_id)) as.character(tt$type_id)[1] else paste0("#", ti)
      cri_key <- intersect(c("criterion_columns", "criteria", "criterions"), names(tt))
      if (!length(cri_key)) next
      crs <- tt[[cri_key[1]]]
      for (ci in seq_along(crs)) {
        cc <- crs[[ci]]
        if (!is.list(cc)) next
        col_key <- intersect(c("column", "criterion_column", "name"), names(cc))
        if (!length(col_key)) next
        colv <- as.character(cc[[col_key[1]]])[1]
        if (is.na(colv) || !nzchar(colv)) next
        k <- paste0(tid, "||", colv)
        ykeys <- c(ykeys, k); yrow_t[[k]] <- tt; yrow_c[[k]] <- cc
      }
    }
    ckeys <- if (all(c("type_id", "criterion_column") %in% names(D)))
               paste0(trimws(D$type_id), "||", trimws(D$criterion_column)) else character(0)
    cat(sprintf("    YAML 行键 %d ／ CSV 行键 %d ／ 交集 %d\n",
                length(ykeys), length(ckeys), length(intersect(ckeys, ykeys))))
    only_c <- setdiff(ckeys, ykeys); only_y <- setdiff(ykeys, ckeys)
    if (length(only_c)) cat(sprintf("    ⚠ 仅 CSV 有 %d：%s\n", length(only_c),
                                    paste(utils::head(only_c, 5), collapse = " | ")))
    if (length(only_y)) cat(sprintf("    ❌ 仅 YAML 有 %d：%s\n", length(only_y),
                                    paste(utils::head(only_y, 5), collapse = " | ")))
    ## ★ 价值轴（axis = V）之行非 typology 判据，须另计而非判失配
    v_only <- if ("axis" %in% names(D))
                sum(trimws(D$axis) == "V" & ckeys %in% only_c) else 0L
    if (v_only > 0L)
      cat(sprintf("    ★ 其中 %d 行系价值轴（axis=V）—— 非 typology 判据，属结构性差异非遗漏\n", v_only))
    ok2 <- (length(only_c) - v_only) == 0L && length(only_y) == 0L
    cat(if (ok2) "    ✅ 行键对应（已扣价值轴）\n" else "    ❌ 行键不对应\n")
    note("B1", "L2", "KEY_ALIGNMENT",
         sprintf("仅CSV %d(含V轴 %d) ／ 仅YAML %d", length(only_c), v_only, length(only_y)), ok2)

    ## ── L3 · VALUE_PROJECTION ★ 四态 ＋ 来源层计数 ─────────────────
    cat("\n  【L3 · VALUE_PROJECTION】逐值比对 ＋ ★ 来源层计数\n")
    common <- intersect(ckeys, ykeys)
    if (!length(common)) {
      cat("    ❌ 无共同行键 —— 无从比对\n")
      note("B1", "L3", "VALUE_PROJECTION", "无共同行键", FALSE)
    } else {
      tot_cmp <- 0L; tot_mis <- 0L; tot_cri <- 0L; tot_cls <- 0L
      cat(sprintf("    %-28s %6s %6s %12s %10s\n", "列", "可比", "不符", "criterion层", "class层"))
      for (col in present) {
        cv <- norm_val(D[[col]][match(common, ckeys)])
        src <- character(length(common)); yv <- character(length(common))
        for (i in seq_along(common)) {
          k <- common[i]; cc <- yrow_c[[k]]; tt <- yrow_t[[k]]
          if (!is.null(cc[[col]]))      { src[i] <- "CRI"; yv[i] <- as.character(cc[[col]])[1] }
          else if (!is.null(tt[[col]])) { src[i] <- "CLS"; yv[i] <- as.character(tt[[col]])[1] }
          else                          { src[i] <- "NA";  yv[i] <- NA_character_ }
        }
        yv   <- norm_val(yv)
        both <- !is.na(cv) & !is.na(yv)
        n_cmp <- sum(both); n_mis <- sum(cv[both] != yv[both])
        n_cri <- sum(both & src == "CRI"); n_cls <- sum(both & src == "CLS")
        tot_cmp <- tot_cmp + n_cmp; tot_mis <- tot_mis + n_mis
        tot_cri <- tot_cri + n_cri; tot_cls <- tot_cls + n_cls
        cat(sprintf("    %-28s %6d %6d %12d %10d %s\n", col, n_cmp, n_mis, n_cri, n_cls,
                    if (n_cmp == 0L) "⚠ 无可比" else if (n_mis == 0L) "✅" else "❌"))
      }
      cat(sprintf("\n    合计：可比 %d ／ 不符 %d ／ criterion 层 %d ／ class 层 %d\n",
                  tot_cmp, tot_mis, tot_cri, tot_cls))
      ## ★★ 四态判词
      if (tot_cmp == 0L) {
        cat("    ❌ VALUE_PROJECTION_NONE —— 无任何值可比\n")
        note("B1", "L3", "VALUE_PROJECTION", "可比值为 0", FALSE)
      } else if (tot_mis > 0L) {
        cat(sprintf("    ❌ VALUE_PROJECTION_MISMATCH —— %d 处不符，双重真相已成实况\n", tot_mis))
        note("B1", "L3", "VALUE_PROJECTION", sprintf("%d/%d 不符", tot_mis, tot_cmp), FALSE)
      } else if (tot_cri == 0L) {
        cat("    ❌ VALUE_PROJECTION_CLASS_ONLY —— ★★ 逐值全等，惟 **全部取自 class 层**\n")
        cat("       意即：CSV 之判据级准入值皆自所属 typology 继承；\n")
        cat("       **YAML 之判据容器内根本没有准入字段** —— 此即 SC-25 之实况。\n")
        cat("       ★ 非「投影损坏」，系 **criterion-level admission 不存在**。\n")
        cat("       ★ 一类之五条判据，若一条该准入、四条不该，现有结构**表达不了**。\n")
        note("B1", "L3", "VALUE_PROJECTION",
             sprintf("CLASS_ONLY（%d 值全取自类别层）", tot_cls), FALSE)
      } else {
        cat(sprintf("    ✅ VALUE_PROJECTION_OK —— 逐值全等，criterion 层 %d 值\n", tot_cri))
        note("B1", "L3", "VALUE_PROJECTION", sprintf("%d 值全等", tot_cmp), TRUE)
      }
    }
  }, layer = "L2")
}

# ══════════════════════════════════════════════════════════════════════════
# 第三部 · loader 静态解析（不 source）
# ══════════════════════════════════════════════════════════════════════════
cat("\n── 第三部 · loader 断言语义分类（★ 只读原文，不执行）──\n\n")
if (file.exists(P_LOADER)) {
  src <- readLines(P_LOADER, warn = FALSE, encoding = "UTF-8")
  cat(sprintf("  行数 %d ／ 函数定义 %d 个\n", length(src),
              length(grep("^\\s*[A-Za-z._][A-Za-z0-9._]*\\s*(<-|=)\\s*function", src))))
  reads_csv  <- any(grepl("read\\.csv|read_csv|fread", src))
  reads_yaml <- any(grepl("read_yaml|yaml\\.load", src))
  cat(sprintf("  读 YAML：%s   读 CSV：%s\n\n", reads_yaml, reads_csv))

  ## ★ SC-14 · 断言语义分类（v1.0.2 只搜 stopifnot，遂生假 FAIL）
  ## 六态判别式：语义优先，函数名其次
  PAT <- list(
    CONSISTENCY = c("不一致", "分家", "集合不一致", "YAML=.*CSV=",
                    "YAML 声明.*CSV 现算", "双档", "互证"),
    VERSION     = c("version", "预期", "递增版本号", "\\.expect"),
    EXISTENCE   = c("未找到", "缺列", "不存在", "无此类型", "待表", "缺档"),
    MODE        = c("需 YAML 模式", "请安装", "模式"),
    WRAP        = c("conditionMessage", "call\\. = FALSE")
  )
  ## ★ 兼收四种断言形式，非只 stopifnot
  is_assert <- function(l) grepl("\\bstop\\(|\\bstopifnot\\(|assert_that\\(|assertthat::", l)
  idx <- which(is_assert(src) & !grepl("^\\s*#", src))
  cat(sprintf("  ★ 断言语句共 %d 处（含 stop／stopifnot／assert_that）\n\n", length(idx)))

  kinds <- character(0); rows <- list()
  for (n in idx) {
    ctx <- paste(src[max(1, n - 1):min(length(src), n + 2)], collapse = " ")
    k <- "OTHER"
    for (kk in names(PAT)) if (any(vapply(PAT[[kk]], function(p) grepl(p, ctx), logical(1)))) { k <- kk; break }
    kinds <- c(kinds, k)
    rows[[length(rows) + 1L]] <- list(line = n, kind = k, txt = trimws(src[n]))
  }
  tb <- table(factor(kinds, levels = c("CONSISTENCY","VERSION","EXISTENCE","MODE","WRAP","OTHER")))
  for (kk in names(tb)) cat(sprintf("    %-12s %3d 处\n", kk, tb[[kk]]))

  n_cons <- tb[["CONSISTENCY"]]
  cat(sprintf("\n  ★★ CONSISTENCY 断言 %d 处 —— 此即 SSOT 之代码强制\n", n_cons))
  if (n_cons > 0L) {
    for (r in rows) if (r$kind == "CONSISTENCY")
      cat(sprintf("    行 %4d | %s\n", r$line, substr(r$txt, 1, 92)))
  }
  if (tb[["OTHER"]] > 0L) {
    cat(sprintf("\n  ⚠ 未归类 %d 处，须人查：\n", tb[["OTHER"]]))
    for (r in rows) if (r$kind == "OTHER")
      cat(sprintf("    行 %4d | %s\n", r$line, substr(r$txt, 1, 92)))
  }

  ## ★ 判 PASS 之条件：CONSISTENCY ≥ 1，非「有无 stopifnot」
  if (!reads_csv || !reads_yaml) {
    cat("\n  ✅ 未同读二档 —— SSOT 于 loader 侧天然成立\n")
    note("B1", "L4", "loader SSOT 断言", "未同读二档", TRUE)
  } else if (n_cons > 0L) {
    cat(sprintf("\n  ✅ 二档皆读，惟有 %d 处一致性断言强制 —— SSOT 已由代码强制\n", n_cons))
    cat("  ★ 惟须记：断言覆盖之范围仍待逐条核实（哪些列受强制、哪些未受）。\n")
    note("B1", "L4", "loader SSOT 断言", sprintf("CONSISTENCY %d 处", n_cons), TRUE)
  } else {
    cat("\n  ❌ 二档皆读而无一致性断言 —— SSOT 未被代码强制\n")
    cat("  ★ 注释中之「SSOT」字样不算强制。**文字不是断言。**\n")
    note("B1", "L4", "loader SSOT 断言", "二者皆读 · 零一致性断言", FALSE)
  }
} else {
  note("B2", "L0", "loader 可读", "档不存在", FALSE)
}

# ══════════════════════════════════════════════════════════════════════════
cat("\n", strrep("=", 92), "\n", sep = "")
cat("验收汇总\n")
cat(strrep("=", 92), "\n")
for (r in RESULT)
  cat(sprintf("  %-4s %-4s %-26s %-38s %s\n", r$gate, r$layer, r$item, r$got,
              if (isTRUE(r$pass)) "PASS ✅" else "FAIL ❌"))
cat(strrep("=", 92), "\n")
cat(sprintf("总判：%s\n", if (FAILED) "❌ 有 FAIL —— B-1／B-2 维持 BLOCK"
                          else "✅ 全 PASS"))
cat(strrep("=", 92), "\n")

cat("\n判读六锁：\n")
cat("  锁五十 · 假 PASS 之危害甚于 FAIL —— FAIL 引人去查，假 PASS 令人停止查。\n")
cat("  锁五十一 · 四层不得跳级：L0 结构 → L1 名 → L2 键 → L3 值。\n")
cat("  锁五十二 · 文字不是断言 —— 注释中之「SSOT」不构成代码强制。\n")
cat("  锁五十四 · ★ 先读结构，再写遍历。\n")
cat("           v1.0.1 之崩，因我假设 criteria/criterion_column，\n")
cat("           实为 criterion_columns/column ——**R4-SEMANTIC-02 之自犯**。\n")
cat("  锁五十五 · ★ 逐值全等 ≠ 投影成立。\n")
cat("           若全部取自 class 层，则判据级准入语义**根本不存在**，\n")
cat("           非投影损坏，系该层字段未建。四态须分 CLASS_ONLY 一态。\n")
cat("  锁五十六 · ★ 断言之形式不止一种。\n")
cat("           stop() ／ stopifnot() ／ if(...)stop() ／ tryCatch(error=stop) 皆是强制。\n")
cat("           判「有无断言」须看其**语义**（不符则中止），非看其**函数名**。\n")
cat("           ★ v1.0.2 只搜 stopifnot，遂对 19 处 stop() 视而不见 —— 假 FAIL。\n")
cat("           假 FAIL 之害在于**引导错误修复**：照其去补断言，\n")
cat("           会在已有五处一致性 stop() 上再叠一层，造成重复强制或语义冲突。\n")

if (!interactive())
  quit(status = if (FAILED) 1L else 0L, save = "no")
