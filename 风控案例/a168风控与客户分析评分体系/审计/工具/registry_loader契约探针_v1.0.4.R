## ══════════════════════════════════════════════════════════════════════════
## registry_loader 契约探针 v1.0.4（PATCH · 缺陷修复，判定原则不变）
## ──────────────────────────────────────────────────────────────────────────
## ★★ 本版所修者，是**探针自己的缺陷**，非 loader 之缺陷 ★★
##
##   F-1 【根因】v1.0.2 之 .run() 内用 `out <<- ...` 赋值。
##       `<<-` 自**当前环境之父环境**起找，故跳过 .run 自己的 `out`，
##       在全局另建一个；.run 返回之 obj 恒为 NULL，
##       致 .after_ids(NULL) → character(0) → 三臂皆「0 个 type_id」。
##       → 改为单箭头 `out <- `（tryCatch 之 expr 本就在 .run 帧内求值）。
##       ⚠ v1.0.1 用同一句却生效，因彼时 REGp 定义在全局——同一写法，
##         两种结果，此正是 `<<-` 之凶险处。
##
##   F-2 【撤回之撤回】v1.0.3 曾撤回「dict = 16」，理由是「dict 非 data.frame」。
##       v1.0.3 自己的结构全照证否此说：dict 系 data.table 66 × 40 且含
##       type_id 列。故 v1.0.1 之 16 系 length(unique(dict$type_id))，**真实有效**，
##       其义为 **16 个登记对象（15 个 T ＋ 1 个 V）**，非 16 类 typology。
##       两读数皆对，指涉不同。此撤回须补 SC（自纠之自纠）。
##
##   F-3 【V 轴感知】dict$type_id 含 "V"，故完整性比对须分流：
##       T 形态（^T-\d{2}$）与 YAML typologies 比集合恒等；
##       非 T 者单列，且须恰为 registry_counts$value_axis_count 个。
##       v1.0.3 之递归漏掉 dict$type_id，正因 all(grepl("^T-\\d{2}$", .)) 遇 "V" 即假
##       ——此反为 V 存在之旁证。
##
##   F-4 【计数三方核对】YAML typologies ／ registry_counts 自报 ／ dict 实测，
##       三方须自洽；不自洽即登记册内部矛盾，须先销再论契约。
##
## 纪律：**不改任何在册档**；一切注入在 tempdir 之副本上进行。
## ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({ library(yaml); library(data.table); library(digest) })

LOADER <- "函数/registry_loader.R"
YAML_C <- "规范/registry_risk_typology_v1.5.0.yaml"
CSV_C  <- "规范/registry_risk_typology_v1.5.0.csv"
for (p in c(LOADER, YAML_C)) if (!file.exists(p)) stop(sprintf("○ 待表：%s 不在位。", p))

.six <- function(p) { d <- readBin(p, "raw", file.info(p)$size)
    list(name = basename(p), line = sum(d == as.raw(10)), byte = length(d),
         md5 = digest(d, algo = "md5", serialize = FALSE)) }
S_L <- .six(LOADER); S_Y <- .six(YAML_C)
cat("═══ 受检件六元组（裁定之锚）═══\n")
for (s in list(S_L, S_Y))
    cat(sprintf("   %s | 行 %d | 字节 %d | MD5 %s\n", s$name, s$line, s$byte, s$md5))
.S2 <- !startsWith(S_L$md5, "c90f7547") || S_L$line != 447L
if (.S2) cat("  ⚠ S2 血统失锚未销：在册 447 行／c90f7547…，现档 ",
             S_L$line, " 行／", substr(S_L$md5, 1, 8), "…\n", sep = "")
cat("\n")

Y <- yaml::read_yaml(YAML_C)
PAT_T <- "^T-\\d{2}$"

## ══════════════════════════════════════════════════════════════════════════
## 一 · F-4 · 计数三方核对（YAML ／ registry_counts ／ dict 实测）
## ══════════════════════════════════════════════════════════════════════════
IDS_T <- if (!is.null(Y$typologies))
    vapply(Y$typologies, function(t) as.character(t$type_id), character(1)) else character(0)
RC <- Y$registry_counts
cat("═══ 一 · 计数三方核对 ═══\n")
cat(sprintf("  ① YAML typologies 实数        ：%d（%s）\n",
            length(IDS_T), paste(range(IDS_T), collapse = " ~ ")))
cat(sprintf("  ② registry_counts 自报        ：risk_typology_count=%s ｜ value_axis_count=%s\n",
            RC$risk_typology_count %||% "—", RC$value_axis_count %||% "—"))
cat(sprintf("                                  total_criterion_rows=%s ｜ risk_criterion_count=%s\n",
            RC$total_criterion_rows %||% "—", RC$risk_criterion_count %||% "—"))
cat(sprintf("  ③ value_axis 顶层键在位        ：%s（axis_id = %s）\n",
            !is.null(Y$value_axis), Y$value_axis$axis_id %||% "—"))

## ══════════════════════════════════════════════════════════════════════════
## 二 · 三臂实验（A0 对照 ／ A1 顶层 ／ A2 逐类）
## ══════════════════════════════════════════════════════════════════════════
tmp <- file.path(tempdir(), "probe_registry_v104")
dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
if (file.exists(CSV_C)) file.copy(CSV_C, file.path(tmp, basename(CSV_C)), overwrite = TRUE)

.run <- function(Yobj, tag) {
    yp <- file.path(tmp, sprintf("%s__%s", tag, basename(YAML_C)))
    yaml::write_yaml(Yobj, yp)
    env <- new.env(parent = globalenv()); sys.source(LOADER, envir = env)
    out <- NULL
    st <- tryCatch({
        f <- get("registry_load", envir = env); a <- names(formals(f))
        if (any(grepl("yaml|path", a, ignore.case = TRUE))) {
            k <- a[grepl("yaml|path", a, ignore.case = TRUE)][1]
            out <- do.call(f, setNames(list(yp), k))      # ★ F-1：单箭头，本帧赋值
        } else {
            for (nm in ls(env)) {
                v <- tryCatch(get(nm, envir = env), error = function(e) NULL)
                if (is.character(v) && any(grepl("registry_risk_typology.*\\.yaml$", v)))
                    assign(nm, yp, envir = env)
            }
            out <- f()                                     # ★ F-1
        }
        "LOADED_OK"
    }, error   = function(e) paste0("STOPPED: ", conditionMessage(e)),
       warning = function(w) paste0("WARNED: ",  conditionMessage(w)))
    list(status = st, obj = out, path = yp)                # ★ obj 现在真有值
}

A0 <- .run(Y, "A0_control")
Y1 <- Y; Y1[["economic_metric_gate"]] <- list(probe = TRUE,
    note = "SCHEMA PROBE ONLY — 探针注入，禁落盘至在册档")
A1 <- .run(Y1, "A1_toplevel")
Y2 <- Y1
for (i in seq_along(Y2$typologies))
    Y2$typologies[[i]][["economic_metrics"]] <- list(
        economic_subject = "member", grain = "uid × window",
        scale_metrics = list("stake_all"), outcome_metrics = list("member_roi"))
A2 <- .run(Y2, "A2_perclass")

cat("\n═══ 二 · 三臂实验 ═══\n")
cat("  A0 对照（原样回写·零注入）   ：", A0$status, "\n")
cat("  A1 顶层 economic_metric_gate ：", A1$status, "\n")
cat(sprintf("  A2 逐类 economic_metrics（全 %d 条）：%s\n", length(IDS_T), A2$status))
cat(sprintf("  ★ obj 是否取到（F-1 修复之验证）：A0 %s ｜ A1 %s ｜ A2 %s\n",
            !is.null(A0$obj), !is.null(A1$obj), !is.null(A2$obj)))

## ══════════════════════════════════════════════════════════════════════════
## 三 · F-3 · V 轴感知之完整性比对
## ══════════════════════════════════════════════════════════════════════════
.ids_of <- function(R) {
    if (is.null(R) || is.null(R$dict)) return(character(0))
    unique(as.character(R$dict[["type_id"]]))
}
.chk <- function(R) {
    all_ids <- .ids_of(R)
    if (!length(all_ids)) return(list(v = NA, nT = 0L, nV = 0L, t = character(0), v_ids = character(0)))
    t_ids <- all_ids[grepl(PAT_T, all_ids)]
    v_ids <- setdiff(all_ids, t_ids)
    list(v = (length(t_ids) == length(IDS_T)) && setequal(t_ids, IDS_T),
         nT = length(t_ids), nV = length(v_ids), t = t_ids, v_ids = v_ids,
         nrow = if (!is.null(R$dict)) nrow(R$dict) else NA_integer_)
}
C0 <- .chk(A0$obj); C1 <- .chk(A1$obj); C2 <- .chk(A2$obj)

cat("\n═══ 三 · 完整性（T 集合恒等 ＋ V 单列 ＋ 判据行数）═══\n")
cat(sprintf("  基准（YAML typologies）：%d 个 T\n", length(IDS_T)))
for (nm in c("A0","A1","A2")) {
    C <- get(paste0("C", substr(nm, 2, 2)))
    cat(sprintf("  %s：dict 行数 %s ｜ T 个数 %d ｜ 集合恒等 %s ｜ 非 T 之 id：%s\n",
        nm, C$nrow %||% "—", C$nT,
        if (is.na(C$v)) "NA" else if (C$v) "✅" else "❌",
        if (C$nV) paste(C$v_ids, collapse = ", ") else "（无）"))
    if (isFALSE(C$v)) {
        cat("     少了：", paste(setdiff(IDS_T, C$t), collapse = ", "), "\n")
        cat("     多了：", paste(setdiff(C$t, IDS_T), collapse = ", "), "\n")
    }
}
## 三方自洽核对
.cons <- !is.na(C0$v) && isTRUE(C0$v) &&
         identical(as.integer(RC$risk_typology_count %||% -1L), length(IDS_T)) &&
         identical(as.integer(RC$value_axis_count %||% -1L),  as.integer(C0$nV)) &&
         identical(as.integer(RC$total_criterion_rows %||% -1L), as.integer(C0$nrow))
cat(sprintf("\n  三方自洽（YAML ／ registry_counts ／ dict 实测）：%s\n",
            if (.cons) "✅ 自洽" else "⚠ 不自洽——须先销登记册内部矛盾，再论契约"))

## ══════════════════════════════════════════════════════════════════════════
## 四 · D-3b 宿主完整性（三态；dict 系投影，未投影 ≠ 丢弃）
## ══════════════════════════════════════════════════════════════════════════
.host <- function(R) {
    if (is.null(R)) return("N/A")
    if (!is.null(R$dict) && "economic_metrics" %in% names(R$dict)) return("PRESERVED")
    ty <- R$meta$typologies
    if (!is.null(ty) && is.list(ty) && length(ty) &&
        any(vapply(ty, function(e) is.list(e) && !is.null(e[["economic_metrics"]]),
                   logical(1)))) return("PRESERVED")
    "NOT_PROJECTED"
}
H2 <- if (identical(A2$status, "LOADED_OK")) .host(A2$obj) else "N/A"
cat("\n═══ 四 · D-3b 宿主完整性 ═══\n  A2 之 economic_metrics：", H2, "\n")
cat(switch(H2,
  PRESERVED     = "  → 未知键被原样带出，loader 系透传型。\n",
  NOT_PROJECTED = "  → 未知键未进输出且未报错：子集读取之常态，非丢弃。定谳看第三节。\n",
  "  → 本臂未执行，不适用。\n"))

## ══════════════════════════════════════════════════════════════════════════
## 五 · 裁定
## ══════════════════════════════════════════════════════════════════════════
V <- if (!identical(A0$status, "LOADED_OK")) {
  "ARTIFACT"
} else if (!identical(A1$status, "LOADED_OK") || !identical(A2$status, "LOADED_OK")) {
  "STRICT"
} else if (isTRUE(C1$v) && isTRUE(C2$v) && .cons) {
  "CONFIRMED"
} else if (isFALSE(C1$v) || isFALSE(C2$v)) {
  "SILENT_DROP"
} else {
  "PROVISIONAL"
}

cat("\n═══ 五 · 裁定 ═══\n")
cat(switch(V,
 ARTIFACT    = "  【ARTIFACT】A0 零注入即 STOP —— 回写伪影，本法失效，不得据以裁 loader。\n",
 STRICT      = "  【全等校验 · STRICT】A0 过而注入臂 STOP —— 确系拒未知键。\n   须【先升 loader，后升登记册】，次序不可颠倒。\n",
 CONFIRMED   = paste0(
   "  【子集读取 · CONFIRMED】三臂皆 LOADED_OK，T 集合恒等，三方计数自洽。\n",
   "   版级推论：economic_metrics: / economic_metric_gate: 属 additive schema；\n",
   "   路径 v1.5.0 → v1.5.1（PATCH）→ v1.6.0（MINOR），**无须 v2.0.0**。\n"),
 SILENT_DROP = "  【静默丢弃】未报错惟 T 集合已变 —— 比 STOP 更凶险，须先查何以吞条目。\n",
 PROVISIONAL = "  【PROVISIONAL】决定性证据未齐，**不得宣布 v1.6.0**。\n"))

cat("\n═══ 六 · 结论措辞锁（引用须整句照录）═══\n")
cat(sprintf(paste0(
  "  「MD5 %s 所对应之现档 registry_loader.R（%d 行／%d 字节），\n",
  "    对 YAML MD5 %s（%d 行）之顶层与逐类双注入测试，裁定为 %s。」\n"),
  S_L$md5, S_L$line, S_L$byte, S_Y$md5, S_Y$line, V))
if (.S2) cat("  ⚠ 并录：该 loader 与在册登记（447 行／c90f7547…）不符，S2 失锚未销。\n")
cat("  ⚠ 禁写作「registry_loader 已证明是 additive schema」。\n")
cat("  ⚠ 并录计数：15 类风险 typology ＋ 1 条价值轴 V ＝ 16 个登记对象；\n",
    "     判据行 65 ＋ 1 ＝ 66。「15 类」与「16 对象」指涉不同，禁互代。\n")
cat("  ⚠ 本探针未改任何在册档；副本置于：", tmp, "\n")
