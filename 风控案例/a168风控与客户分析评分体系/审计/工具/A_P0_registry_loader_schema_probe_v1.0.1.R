## ══════════════════════════════════════════════════════════════════════════
## A_P0_registry_loader_schema_probe.R  ·  v1.0.1
## ── registry_loader.R 之 YAML 契约判定探针（静态 ＋ 动态 ＋ 完整性三证）
## ══════════════════════════════════════════════════════════════════════════
## v1.0.0 → v1.0.1（PATCH · 缺陷修复，判据方向未变）
##   D-1 静态正则不辨方向，误报：`setdiff(need, names(d))` 系【子集读取】之惯用式
##       （问「必需的少了哪些」），而【全等校验】须写反向 `setdiff(names(d), need)`
##       （问「实有的多了哪些」）。v1.0.0 之 `setdiff\s*\(` 不辨方向，7 处全属误报。
##   D-2 类目键候选漏了实际键名 `typologies`，致【逐类注入】从未发生——
##       而 SC-15 拟增之主体恰在逐类那一块。今改为**自动侦测**：
##       取「其值为列表、且元素含 type_id」之顶层键，不再倚赖硬写候选。
##   D-3 v1.0.0 只看 loader 是否 STOP，未看**载入之内容是否完整**。
##       「不报错」与「没吞掉东西」是两件事：子集读取若把未知键连同其宿主条目
##       一并跳过，亦返回 LOADED_OK。今增第三证：注入前后之对象计数须一致。
## 性质：只读探针。**不改任何在册档**——动态段一律在 tempdir() 内操作。
## 置放：审计/工具/
## ⚠ 裁定恒挂在受检件之六元组上；换一份 loader，裁定即失效，须重跑。
## ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({ library(yaml); library(data.table) })

LOADER <- "函数/registry_loader.R"
YAML_C <- "规范/registry_risk_typology_v1.5.0.yaml"
CSV_C  <- "规范/registry_risk_typology_v1.5.0.csv"
for (p in c(LOADER, YAML_C)) if (!file.exists(p)) stop(sprintf(
  "○ 待表：%s 不在位。本探针不臆造——请先确认五命名空间之实际落盘位置。", p))

.six <- function(p) {
  d <- readBin(p, "raw", file.info(p)$size)
  sprintf("%s | 行 %d | 字节 %d | MD5 %s", basename(p),
          sum(d == as.raw(10)), length(d),
          digest::digest(d, algo = "md5", serialize = FALSE))
}
cat("═══ 受检件六元组（裁定之锚，须随结论一并登记）═══\n  ",
    .six(LOADER), "\n  ", .six(YAML_C), "\n")

## ── 血统核对：与在册登记比对（在册值请按实际登记册填入）─────────────────
.REG_LOADER_MD5  <- "c90f7547"          # 在册前八位；若不符即证 loader 已改而未登记
.REG_LOADER_LINE <- 447L
.cur <- readBin(LOADER, "raw", file.info(LOADER)$size)
.cur_md5 <- digest::digest(.cur, algo = "md5", serialize = FALSE)
.cur_line <- sum(.cur == as.raw(10))
if (!startsWith(.cur_md5, .REG_LOADER_MD5) || .cur_line != .REG_LOADER_LINE)
  cat(sprintf(paste0("  ⚠ S2 血统失锚：loader 在册登记为 %d 行／MD5 %s…，",
              "现档为 %d 行／MD5 %s…\n",
              "     → 该档已改而改动未经登记，须补 SC 条目；",
              "本次裁定只挂在现档之 MD5 上。\n"),
              .REG_LOADER_LINE, .REG_LOADER_MD5, .cur_line, substr(.cur_md5, 1, 8)))
cat("\n")

## ══════════════════════════════════════════════════════════════════════════
## 一 · 静态段：方向敏感之模式扫描（分诊，不足以定谳）
## ══════════════════════════════════════════════════════════════════════════
src  <- readLines(LOADER, warn = FALSE, encoding = "UTF-8")
code <- vapply(src, function(l) sub("#.*$", "", l), "")
code <- code[nzchar(trimws(code))]

pat <- list(
  ## ★ 方向敏感：need 在前 = 问「必需的少了哪些」= 子集语义
  `子集·setdiff(必需, 实有)` = "setdiff\\s*\\(\\s*(need|req|must|expect|required)[^,]*,\\s*(sort\\s*\\()?names",
  ## ★ 方向敏感：names 在前 = 问「实有的多了哪些」= 全等语义（拒未知键）
  `全等·setdiff(实有, 必需)` = "setdiff\\s*\\(\\s*(sort\\s*\\()?names\\s*\\(",
  `全等·identical(names)`    = "identical\\s*\\(\\s*(sort\\s*\\()?names",
  `全等·all\\.equal(names)`  = "all\\.equal\\s*\\(\\s*(sort\\s*\\()?names",
  `全等·expected_keys 白名单`= "expected_(keys|cols|fields)|EXPECTED_(KEYS|COLS)",
  `全等·未知键即停`          = "(未知|unknown|unexpected|多余|extra)[^\\n]*(stop|STOP|abort)",
  `子集·具名取键`            = "\\[\\[\\s*['\"]",
  `子集·%in% 存在性`         = "%in%\\s*names|names\\s*\\([^)]*\\)\\s*%in%",
  `子集·is.null 兜底`        = "is\\.null\\s*\\(",
  `子集·vapply 白名单遍历`   = "vapply|lapply"
)
hit <- rbindlist(lapply(names(pat), function(k) {
  i <- grep(pat[[k]], code, perl = TRUE)
  data.table(模式 = k, 命中 = length(i),
             首现 = if (length(i)) trimws(substr(code[i[1]], 1, 72)) else "—")
}))
cat("═══ 一 · 静态模式扫描（方向敏感）═══\n"); print(hit)
.e <- sum(hit[grepl("^全等", 模式), 命中]); .s <- sum(hit[grepl("^子集", 模式), 命中])
cat(sprintf("\n  静态倾向：全等 %d ／ 子集 %d → %s\n", .e, .s,
            if (.e > 0) "疑似【全等校验】，须动态坐实" else "疑似【子集读取】，须动态坐实"))
cat("  ⚠ SC-23：正则命中不等于语义成立。静态段只作分诊，一律以动态段为准。\n\n")

## ══════════════════════════════════════════════════════════════════════════
## 二 · 动态段：顶层 ＋ 逐类双注入（决定性）
## ══════════════════════════════════════════════════════════════════════════
tmp <- file.path(tempdir(), "probe_registry"); dir.create(tmp, showWarnings = FALSE)
y_tmp <- file.path(tmp, basename(YAML_C))
file.copy(YAML_C, y_tmp, overwrite = TRUE)
if (file.exists(CSV_C)) file.copy(CSV_C, file.path(tmp, basename(CSV_C)), overwrite = TRUE)
Y <- yaml::read_yaml(y_tmp)

## ── 注入 A：顶层 ───────────────────────────────────────────────────────────
Y[["economic_metric_gate"]] <- list(
  probe = TRUE, note = "SCHEMA PROBE ONLY — 探针注入，禁落盘至在册档")

## ── 注入 B：逐类（★ 自动侦测类目键，不再倚赖硬写候选 —— v1.0.1 之 D-2）────
.is_typo <- function(v) is.list(v) && length(v) > 0 &&
  all(vapply(v, function(e) is.list(e) && !is.null(e[["type_id"]]), logical(1)))
.tk <- names(Y)[vapply(Y, .is_typo, logical(1))]
if (length(.tk) != 1L) {
  cat(sprintf("  ⚠ 类目键侦测得 %d 个（%s）——逐类注入未执行，判读力不足。\n",
              length(.tk), paste(.tk, collapse = ", ")))
  .n_before <- NA_integer_
} else {
  .n_before <- length(Y[[.tk]])
  for (i in seq_along(Y[[.tk]]))            # 全类注入，非只首条
    Y[[.tk]][[i]][["economic_metrics"]] <- list(
      economic_subject = "member", grain = "uid × window",
      scale_metrics = list("stake_all"), outcome_metrics = list("member_roi"))
  cat(sprintf("  已于类目键 `%s` 之**全部 %d 条**注入 economic_metrics:\n",
              .tk, .n_before))
}
yaml::write_yaml(Y, y_tmp)

env <- new.env(parent = globalenv()); sys.source(LOADER, envir = env)
REGp <- NULL
res <- tryCatch({
  f <- get("registry_load", envir = env); a <- names(formals(f))
  if (any(grepl("yaml|path", a, ignore.case = TRUE))) {
    k <- a[grepl("yaml|path", a, ignore.case = TRUE)][1]
    REGp <<- do.call(f, setNames(list(y_tmp), k))
  } else {
    for (nm in ls(env)) if (is.character(get(nm, envir = env)) &&
        any(grepl("registry_risk_typology.*\\.yaml$", get(nm, envir = env))))
      assign(nm, y_tmp, envir = env)
    REGp <<- f()
  }
  "LOADED_OK"
}, error = function(e) paste0("STOPPED: ", conditionMessage(e)),
   warning = function(w) paste0("WARNED: ", conditionMessage(w)))

## ══════════════════════════════════════════════════════════════════════════
## 三 · 完整性段：不报错 ≠ 没吞掉（v1.0.1 之 D-3）
## ══════════════════════════════════════════════════════════════════════════
.n_after <- NA_integer_
if (identical(res, "LOADED_OK") && !is.null(REGp)) {
  .cand <- c("dict", "typologies", "types", "meta")
  for (nm in .cand) if (!is.null(REGp[[nm]])) {
    .n_after <- if (is.data.frame(REGp[[nm]]))
      length(unique(REGp[[nm]][["type_id"]])) else length(REGp[[nm]])
    cat(sprintf("  载入后自 `%s` 计得对象 %d 个\n", nm, .n_after)); break
  }
}
.intact <- if (is.na(.n_before) || is.na(.n_after)) NA else (.n_before == .n_after)

## ══════════════════════════════════════════════════════════════════════════
## 四 · 裁定
## ══════════════════════════════════════════════════════════════════════════
cat("\n═══ 四 · 裁定 ═══\n  loader 返回：", res, "\n")
if (!identical(res, "LOADED_OK")) {
  cat("  契约判定：  【全等校验】—— 注入未知键即拒\n",
      "  版级推论：  新增区块即 breaking → 须【先升 loader，后升登记册】，次序不可颠倒\n")
} else if (isTRUE(.intact)) {
  cat("  契约判定：  【子集读取 · CONFIRMED】—— 顶层与逐类双注入皆通过，且对象计数未变\n",
      sprintf("  完整性：    注入前 %d 个 ／ 载入后 %d 个 → 一致 ✅\n", .n_before, .n_after),
      "  版级推论：  economic_metrics: / economic_metric_gate: 属 additive schema\n",
      "              路径 v1.5.0 → v1.5.1（PATCH）→ v1.6.0（MINOR），**无须 v2.0.0**\n")
} else if (isFALSE(.intact)) {
  cat("  契约判定：  【静默丢弃】—— 未报错，惟对象计数已变，此比 STOP 更凶险\n",
      sprintf("  完整性：    注入前 %d 个 ／ 载入后 %d 个 → 不一致 ❌\n", .n_before, .n_after),
      "  版级推论：  不得判为 additive；须先查 loader 何以吞条目，再论版级\n")
} else {
  cat("  契约判定：  【子集读取 · PROVISIONAL】—— 未 STOP，惟完整性未能核实\n",
      "  版级推论：  **不得宣布 v1.6.0**，须补齐完整性核实后重判\n")
}
cat("\n  ⚠ 无论判定为何，皆不得跳级：v1.5.0 → v2.0.0 为纪律所禁。\n")
cat("  ⚠ 本探针未改任何在册档；探针副本置于：", tmp, "\n")
cat("  ⚠ 裁定须连同卷首六元组一并登记，否则 loader 一改即失锚。\n")
