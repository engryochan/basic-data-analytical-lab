## ══════════════════════════════════════════════════════════════════════════
## registry_loader 契约探针 v1.0.3（PATCH · 观测型修复，判定原则不变）
## ──────────────────────────────────────────────────────────────────────────
## 承 REDTEAM 2026-08-23 裁示第五节：「下一刀不是继续猜 .after_ids()，
##   而是先把 REGp 的真实结构完整照出来。」本版即此——**只观测，不猜测**。
##
## 本版三项（皆为观测，不改判定原则）：
##   E-1  REGp 结构全照：逐顶层对象之 class／length／dim／names
##   E-2  canonical ID 集合**递归搜寻**：遍历整个返回对象，找出一切
##        「形如 T-\\d+ 之字符向量」所在之路径，不再倚赖四个硬写槽位
##   E-3  读出 YAML 之 registry_counts／axes／value_axis，与 typologies 交叉核对
##        —— 以证据裁定「15 类 typology ＋ 1 条价值轴 ＝ 16 个登记对象」
##
## ★ 本版另撤回一个读数（须补 SC）：
##   v1.0.1 曾打印「载入后自 dict 计得对象 16 个」。其代码在 dict 非
##   data.frame 时走 `length(REGp[[nm]])` 一支——**该 16 是某列表之长度，
##   从来不是 16 个 type_id**。不存在「16 类 typology」之证据，该读数作废。
##
## 纪律：**不改任何在册档**；本版连注入都不做（纯观测），故连 tempdir 都只读。
## ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({ library(yaml); library(data.table); library(digest) })

LOADER <- "函数/registry_loader.R"
YAML_C <- "规范/registry_risk_typology_v1.5.0.yaml"
CSV_C  <- "规范/registry_risk_typology_v1.5.0.csv"
for (p in c(LOADER, YAML_C)) if (!file.exists(p)) stop(sprintf(
    "○ 待表：%s 不在位。本探针不臆造。", p))

.six <- function(p) { d <- readBin(p, "raw", file.info(p)$size)
    list(name = basename(p), line = sum(d == as.raw(10)), byte = length(d),
         md5 = digest(d, algo = "md5", serialize = FALSE)) }
S_L <- .six(LOADER); S_Y <- .six(YAML_C)
cat("═══ 受检件六元组 ═══\n")
for (s in list(S_L, S_Y))
    cat(sprintf("   %s | 行 %d | 字节 %d | MD5 %s\n", s$name, s$line, s$byte, s$md5))
if (!startsWith(S_L$md5, "c90f7547") || S_L$line != 447L)
    cat("  ⚠ S2 血统失锚未销：在册 447 行／c90f7547…，现档",
        S_L$line, "行／", substr(S_L$md5, 1, 8), "…\n")
cat("\n")

## ══════════════════════════════════════════════════════════════════════════
## 一 · E-3 · YAML 侧计数交叉核对（15 类 typology ＋ 1 价值轴 ＝ 16 对象？）
## ══════════════════════════════════════════════════════════════════════════
Y <- yaml::read_yaml(YAML_C)
cat("═══ 一 · YAML 侧计数（15／16 之辨）═══\n")

.ids_y <- if (!is.null(Y$typologies))
    vapply(Y$typologies, function(t) as.character(t$type_id), character(1)) else character(0)
cat(sprintf("  typologies 条数：%d\n", length(.ids_y)))
cat("  type_id 全列：", paste(.ids_y, collapse = ", "), "\n")
cat(sprintf("  重复：%s\n", if (anyDuplicated(.ids_y))
      paste(unique(.ids_y[duplicated(.ids_y)]), collapse = ", ") else "无"))

cat("\n  value_axis 是否独立顶层键：", !is.null(Y$value_axis), "\n")
if (!is.null(Y$value_axis)) {
    va <- Y$value_axis
    cat("    其键：", paste(names(va), collapse = ", "), "\n")
    for (k in c("axis_id", "id", "name_zh", "criterion_columns"))
        if (!is.null(va[[k]])) cat(sprintf("    %s = %s\n", k,
            paste(as.character(unlist(va[[k]])), collapse = ", ")))
}

cat("\n  registry_counts（登记册自报之计数，为裁定之权威）：\n")
if (!is.null(Y$registry_counts)) str(Y$registry_counts, max.level = 2, give.attr = FALSE) else cat("    ○ 待表：无 registry_counts 键\n")

cat("\n  axes（轴之定义，判「四主体」属哪一轴）：\n")
if (!is.null(Y$axes)) str(Y$axes, max.level = 3, give.attr = FALSE) else cat("    ○ 待表：无 axes 键\n")

## 逐类主体一览：answering「代理／荷官／风控专员落在哪几类」
cat("\n  逐类主体一览（type_id ｜ name_zh ｜ category ｜ 主交付件）：\n")
if (length(.ids_y)) {
    tb <- rbindlist(lapply(Y$typologies, function(t) data.table(
        type_id = as.character(t$type_id) %||% NA_character_,
        name_zh = as.character(t$name_zh %||% NA_character_),
        category = as.character(t$category %||% NA_character_),
        deliverable = paste(as.character(unlist(t$primary_deliverable %||% NA)), collapse = "; ")
    )), fill = TRUE)
    print(tb)
}
cat("\n")

## ══════════════════════════════════════════════════════════════════════════
## 二 · 载入（零注入，纯观测）
## ══════════════════════════════════════════════════════════════════════════
env <- new.env(parent = globalenv()); sys.source(LOADER, envir = env)
REG <- NULL
st <- tryCatch({ REG <<- get("registry_load", envir = env)(); "LOADED_OK" },
    error = function(e) paste0("STOPPED: ", conditionMessage(e)),
    warning = function(w) paste0("WARNED: ", conditionMessage(w)))
cat("═══ 二 · 载入（在册原档，零注入）═══\n  registry_load()：", st, "\n\n")

## ══════════════════════════════════════════════════════════════════════════
## 三 · E-1 · REGp 结构全照
## ══════════════════════════════════════════════════════════════════════════
cat("═══ 三 · 返回对象结构全照 ═══\n")
if (is.null(REG)) cat("  ○ 待表：registry_load() 未返回对象\n") else {
  cat("  顶层 class：", paste(class(REG), collapse = "/"),
      " ｜ length：", length(REG), "\n")
  cat("  顶层 names：", paste(names(REG), collapse = ", "), "\n\n")
  info <- rbindlist(lapply(names(REG), function(nm) {
      x <- REG[[nm]]
      data.table(对象 = nm, class = paste(class(x), collapse = "/"),
        length = length(x),
        dim = if (!is.null(dim(x))) paste(dim(x), collapse = " × ") else "—",
        含type_id列 = if (is.data.frame(x)) ("type_id" %in% names(x)) else NA,
        前几个名 = paste(utils::head(names(x), 8), collapse = ", "))
  }), fill = TRUE)
  print(info)
}

## ══════════════════════════════════════════════════════════════════════════
## 四 · E-2 · canonical ID 集合递归搜寻（★ 不倚赖硬写槽位）
## ══════════════════════════════════════════════════════════════════════════
cat("\n═══ 四 · type_id 递归搜寻（遍历整个返回对象）═══\n")
.PAT <- "^T-\\d{2}$"                      # canonical 形态；不匹配者不认
.found <- list()
.walk <- function(x, path, depth = 0L) {
  if (depth > 8L) return(invisible(NULL))
  ## ① 字符向量本身即形如 T-\d{2}
  if (is.character(x) && length(x) && all(grepl(.PAT, x))) {
    .found[[length(.found) + 1L]] <<- list(path = path, ids = unique(x), n = length(x))
    return(invisible(NULL))
  }
  ## ② data.frame：逐列查
  if (is.data.frame(x)) {
    for (cn in names(x)) {
      v <- as.character(x[[cn]])
      if (length(v) && all(grepl(.PAT, v)))
        .found[[length(.found) + 1L]] <<- list(
          path = paste0(path, "$", cn), ids = unique(v), n = length(v))
    }
    return(invisible(NULL))
  }
  ## ③ 列表：递归
  if (is.list(x) && length(x)) {
    nms <- names(x); if (is.null(nms)) nms <- paste0("[[", seq_along(x), "]]")
    for (i in seq_along(x)) .walk(x[[i]],
      paste0(path, if (grepl("^\\[\\[", nms[i])) nms[i] else paste0("$", nms[i])), depth + 1L)
  }
  invisible(NULL)
}
if (!is.null(REG)) .walk(REG, "REG")

if (!length(.found)) {
  cat("  ⛔ 全对象递归未寻得任何形如 T-dd 之集合。\n",
      "     判读：**此只证探针未在返回对象中找到 canonical 集合**，\n",
      "     不证 loader 丢弃了 15 类。须人工目视 str(REG, max.level = 2)。\n")
} else {
  res <- rbindlist(lapply(.found, function(f) data.table(
    路径 = f$path, 个数 = f$n, 去重后 = length(f$ids),
    与YAML集合恒等 = setequal(f$ids, .ids_y) && length(f$ids) == length(.ids_y),
    样本 = paste(utils::head(f$ids, 5), collapse = ", "))), fill = TRUE)
  print(res)
  hit <- res[与YAML集合恒等 == TRUE]
  cat("\n  与 YAML 之 typologies 集合恒等者：",
      if (nrow(hit)) paste(hit$路径, collapse = ", ") else "（无）", "\n")
  if (nrow(hit)) cat("  → 此即 canonical 输出槽位；v1.0.4 之 .after_ids() 应直取此路径。\n")
}

## ══════════════════════════════════════════════════════════════════════════
## 五 · 结论（观测型，不出契约裁定）
## ══════════════════════════════════════════════════════════════════════════
cat("\n═══ 五 · 结论 ═══\n")
cat("  本版为**观测型**，不产出契约裁定。契约裁定仍停在 v1.0.2 之 PROVISIONAL。\n")
cat(sprintf("  15／16 之辨：typologies %d 条；value_axis 独立顶层键 %s。\n",
            length(.ids_y), !is.null(Y$value_axis)))
cat("    → 若二者皆确，则「15 类风险 typology ＋ 1 条价值轴 ＝ 16 个登记对象」，\n",
    "      「15 类」与「16 对象」指涉不同，禁互代。\n")
cat("  ⚠ 撤回：v1.0.1 之「dict = 16」系 length() 于非 data.frame 之误读，\n",
    "     从来不是 16 个 type_id。不存在「16 类 typology」之证据，须补 SC。\n")
cat("  ⚠ 措辞锁续用：结论恒挂 loader MD5", substr(S_L$md5, 1, 8),
    "…；S2 未销，不得追溯覆盖至 c90f7547…。\n")
