## ══════════════════════════════════════════════════════════════════════════
## A_P0_registry_loader_schema_probe.R
## ── registry_loader.R 之 YAML 契约判定探针（静态 ＋ 动态双证）
## ══════════════════════════════════════════════════════════════════════════
## 立件缘由（2026-08-23 · REDTEAM 裁示「下一刀只查一个前置事实」）：
##   registry_loader.R 对 registry_risk_typology_v1.5.0.yaml 之 schema，
##   究系【子集读取】（读己所需、忽略未知键）抑或【全等校验】（键集须逐字相同）？
##   此事实决定新增 economic_metrics: / economic_metric_gate: 二区块之版级：
##     子集读取 → additive → v1.5.1 → v1.6.0 即足，无须 MAJOR
##     全等校验 → breaking → 须【先升 loader、后升登记册】，版级另判
##   ★ 在本探针出结论之前，禁宣布 v1.6.0，禁开 P1 之 SQL 施工。
## 性质：只读探针。**不改任何在册档**——动态段一律在 tempdir() 内操作。
## 置放：审计/工具/
## ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({
  library(yaml); library(data.table)
})

## ── 0 · 定位（依五命名空间：Execution = 函数/、Specification = 规范/）──────
LOADER <- "函数/registry_loader.R"
YAML_C <- "规范/registry_risk_typology_v1.5.0.yaml"
CSV_C  <- "规范/registry_risk_typology_v1.5.0.csv"

for (p in c(LOADER, YAML_C)) {
  if (!file.exists(p)) stop(sprintf(
    "○ 待表：%s 不在位。本探针不臆造——请先确认五命名空间之实际落盘位置。", p))
}

## 六元组留痕（探针亦须可追溯）
.six <- function(p) {
  d <- readBin(p, "raw", file.info(p)$size)
  sprintf("%s | 行 %d | 字节 %d | MD5 %s",
          basename(p), sum(d == as.raw(10)), length(d),
          digest::digest(d, algo = "md5", serialize = FALSE))
}
cat("═══ 受检件六元组 ═══\n  ", .six(LOADER), "\n  ", .six(YAML_C), "\n\n")


## ══════════════════════════════════════════════════════════════════════════
## 一 · 静态段：源码模式扫描（快速分诊，不足以定谳）
## ══════════════════════════════════════════════════════════════════════════
src <- readLines(LOADER, warn = FALSE, encoding = "UTF-8")

## 剥注释后再扫，免把注释里的字样当代码（本项目已有 SC-24 之教训）
code <- vapply(src, function(l) sub("#.*$", "", l), "")
code <- code[nzchar(trimws(code))]

pat <- list(
  `全等校验·setdiff 双向`   = "setdiff\\s*\\(",
  `全等校验·identical(names` = "identical\\s*\\(\\s*(sort\\s*\\()?names",
  `全等校验·all\\.equal`     = "all\\.equal\\s*\\(",
  `全等校验·stopifnot 键集`  = "stopifnot[^\\n]*names",
  `全等校验·expected_keys`   = "expected_(keys|cols|fields)|EXPECTED_(KEYS|COLS)",
  `全等校验·未知键即停`      = "未知|unknown|unexpected|多余|extra",
  `子集读取·具名取键`        = "\\[\\[\\s*['\"]",
  `子集读取·%in% 存在性`     = "%in%\\s*names|names\\([^)]*\\)\\s*%in%",
  `子集读取·is.null 兜底`    = "is\\.null\\s*\\(",
  `子集读取·vapply 白名单`   = "vapply|lapply[^\\n]*keys"
)
hit <- rbindlist(lapply(names(pat), function(k) {
  i <- grep(pat[[k]], code, perl = TRUE)
  data.table(模式 = k, 命中行数 = length(i),
             首现 = if (length(i)) trimws(substr(code[i[1]], 1, 78)) else "—")
}))
cat("═══ 一 · 静态模式扫描 ═══\n"); print(hit)

.s_exact  <- sum(hit[grepl("^全等校验", 模式), 命中行数])
.s_subset <- sum(hit[grepl("^子集读取", 模式), 命中行数])
cat(sprintf("\n  静态倾向：全等特征 %d 处 ／ 子集特征 %d 处 → %s\n",
            .s_exact, .s_subset,
            if (.s_exact > 0) "疑似【全等校验】，须动态坐实"
            else "疑似【子集读取】，须动态坐实"))
cat("  ⚠ 静态扫描只作分诊：正则命中不等于语义成立（SC-23 之锁）。\n\n")


## ══════════════════════════════════════════════════════════════════════════
## 二 · 动态段：注入未知键，观其是否 STOP（决定性证据）
## ══════════════════════════════════════════════════════════════════════════
## 一律在 tempdir() 内操作；在册档一字不动。
tmp <- file.path(tempdir(), "probe_registry"); dir.create(tmp, showWarnings = FALSE)
y_tmp <- file.path(tmp, basename(YAML_C))
file.copy(YAML_C, y_tmp, overwrite = TRUE)
if (file.exists(CSV_C)) file.copy(CSV_C, file.path(tmp, basename(CSV_C)), overwrite = TRUE)

Y <- yaml::read_yaml(y_tmp)

## 注入两处未知键，恰为 v1.6.0 拟增之二者
Y[["economic_metric_gate"]] <- list(
  probe = TRUE, note = "SCHEMA PROBE ONLY — 探针注入，禁落盘至在册档")

.types_key <- intersect(c("types", "typology", "risk_types", "objects"), names(Y))
if (length(.types_key) == 1L && length(Y[[.types_key]])) {
  Y[[.types_key]][[1]][["economic_metrics"]] <- list(
    economic_subject = "member", grain = "uid × window",
    scale_metrics = list("stake_all"), outcome_metrics = list("member_roi"))
  cat(sprintf("  已于类目键 `%s` 之首条注入 economic_metrics:\n", .types_key))
} else {
  cat("  ⚠ 未能定位类目键（试过 types/typology/risk_types/objects）——\n",
      "    仅注入顶层 economic_metric_gate:，判读力略降，须人工复核类目键名。\n")
}
yaml::write_yaml(Y, y_tmp)

## 以探针副本重跑 loader。sys.source 免污染全局。
env <- new.env(parent = globalenv())
sys.source(LOADER, envir = env)

res <- tryCatch({
  ## 优先显式传参；若 loader 只认常量，则覆盖其常量后再调
  f <- get("registry_load", envir = env)
  a <- names(formals(f))
  if (any(grepl("yaml|path", a, ignore.case = TRUE))) {
    k <- a[grepl("yaml|path", a, ignore.case = TRUE)][1]
    do.call(f, setNames(list(y_tmp), k))
  } else {
    for (nm in ls(env)) if (is.character(get(nm, envir = env)) &&
        any(grepl("registry_risk_typology.*\\.yaml$", get(nm, envir = env))))
      assign(nm, y_tmp, envir = env)
    f()
  }
  "LOADED_OK"
}, error = function(e) paste0("STOPPED: ", conditionMessage(e)),
   warning = function(w) paste0("WARNED: ", conditionMessage(w)))


## ══════════════════════════════════════════════════════════════════════════
## 三 · 裁定
## ══════════════════════════════════════════════════════════════════════════
verdict <- if (identical(res, "LOADED_OK")) {
  "【子集读取】—— 注入未知键后仍正常载入"
} else if (grepl("^STOPPED", res)) {
  "【全等校验】—— 注入未知键即 STOP"
} else {
  "【子集读取·带警告】—— 未 STOP，惟有警告，须读警告文判其是否语义性拒绝"
}

cat("\n═══ 三 · 裁定 ═══\n")
cat("  loader 返回：", res, "\n")
cat("  契约判定：  ", verdict, "\n\n")

cat("  版级推论：\n")
if (identical(res, "LOADED_OK")) {
  cat("    → economic_metrics: / economic_metric_gate: 属 additive schema\n",
      "   → 路径 v1.5.0 → v1.5.1（PATCH，只登规格指针）→ v1.6.0（MINOR，新增区块）\n",
      "   → **无须 v2.0.0**\n")
} else {
  cat("    → 新增区块即 breaking change\n",
      "   → 须【先升 registry_loader.R，后升登记册】，次序不可颠倒\n",
      "   → loader 升版后重跑本探针，再判登记册之版级\n")
}
cat("\n  ⚠ 无论判定为何，皆不得跳级：v1.5.0 → v2.0.0 为纪律所禁。\n")
cat("  ⚠ 本探针未改任何在册档；探针副本置于：", tmp, "\n")
cat("  ⚠ 判定结论须连同上方六元组一并登记，否则日后 loader 一改即失锚。\n")
