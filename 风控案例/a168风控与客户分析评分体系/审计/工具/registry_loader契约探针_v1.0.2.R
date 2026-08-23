## ══════════════════════════════════════════════════════════════════════════
## registry_loader 契约探针 v1.0.2（PATCH · 判据实现修正，判定原则不变）
## ──────────────────────────────────────────────────────────────────────────
## 承 REDTEAM 2026-08-23 裁示：v1.0.1 之 PROVISIONAL 裁定正确，不改判；
##   失败点在探针 D-2 之 namespace 识别过宽，非 loader 已被证明有问题。
##
## 本版三项斧正（裁示所列）：
##   D-2a  canonical namespace 锚定 —— 但**不硬写键名**（见下 R4-1）
##   D-3a  完整性由「数量恒等」升为「数量恒等 ＋ type_id 集合恒等」
##   D-3b  注入宿主完整性 —— **三态判读**，非二态（见下 R4-3）
##
## 本版另加两项（R4 补强，裁示未及）：
##   R4-1  锚定改自 loader 源码反解，取其实际读取之键，而非「名字像不像」
##   R4-2  新增**对照臂 A0**（原样回写、零注入）——隔离 yaml::write_yaml 之
##         往返伪影。无此臂则 STOP 无从分辨「拒未知键」抑或「被回写绊倒」。
##   R4-3  D-3b 三态：PRESERVED ／ NOT_PROJECTED（设计使然）／ LOST（真丢弃）。
##         dict 是投影，子集读取型 loader 本就不投影未知键；以二态判之必产假 FAIL。
##         丢弃与否之**唯一定谳**是 D-3a 之集合恒等。
##
## 纪律：本探针**不改任何在册档**，一切实验在 tempdir 之副本上进行。
## ══════════════════════════════════════════════════════════════════════════

suppressPackageStartupMessages({ library(yaml); library(data.table); library(digest) })

LOADER <- "函数/registry_loader.R"
YAML_C <- "规范/registry_risk_typology_v1.5.0.yaml"
CSV_C  <- "规范/registry_risk_typology_v1.5.0.csv"
for (p in c(LOADER, YAML_C)) if (!file.exists(p)) stop(sprintf(
    "○ 待表：%s 不在位。本探针不臆造——请先确认五命名空间之实际落盘位置。", p))

.six <- function(p) {
    d <- readBin(p, "raw", file.info(p)$size)
    list(name = basename(p), line = sum(d == as.raw(10)), byte = length(d),
         md5 = digest(d, algo = "md5", serialize = FALSE))
}
.fmt <- function(s) sprintf("%s | 行 %d | 字节 %d | MD5 %s", s$name, s$line, s$byte, s$md5)

S_LOADER <- .six(LOADER); S_YAML <- .six(YAML_C)
cat("═══ 受检件六元组（裁定之锚，须随结论一并登记）═══\n  ",
    .fmt(S_LOADER), "\n  ", .fmt(S_YAML), "\n")

## ── 血统核对 ───────────────────────────────────────────────────────────────
.REG_LOADER_MD5  <- "c90f7547"; .REG_LOADER_LINE <- 447L
.S2 <- !startsWith(S_LOADER$md5, .REG_LOADER_MD5) || S_LOADER$line != .REG_LOADER_LINE
if (.S2) cat(sprintf(paste0(
    "  ⚠ S2 血统失锚：loader 在册登记为 %d 行／MD5 %s…，现档为 %d 行／MD5 %s…\n",
    "     → 该档已改而改动未经登记，须补 SC 条目；本次裁定只挂在现档之 MD5 上。\n"),
    .REG_LOADER_LINE, .REG_LOADER_MD5, S_LOADER$line, substr(S_LOADER$md5, 1, 8)))
cat("\n")

## ══════════════════════════════════════════════════════════════════════════
## 一 · 静态段：方向敏感之模式扫描（分诊，不足以定谳）
## ══════════════════════════════════════════════════════════════════════════
src  <- readLines(LOADER, warn = FALSE, encoding = "UTF-8")
code <- vapply(src, function(l) sub("#.*$", "", l), "")
code <- code[nzchar(trimws(code))]

pat <- list(
    `子集·setdiff(必需, 实有)` = "setdiff\\s*\\(\\s*(need|req|must|expect|required)[^,]*,\\s*(sort\\s*\\()?names",
    `全等·setdiff(实有, 必需)` = "setdiff\\s*\\(\\s*(sort\\s*\\()?names\\s*\\(",
    `全等·identical(names)`    = "identical\\s*\\(\\s*(sort\\s*\\()?names",
    `全等·all.equal(names)`    = "all\\.equal\\s*\\(\\s*(sort\\s*\\()?names",
    `全等·expected_keys 白名单`= "expected_(keys|cols|fields)|EXPECTED_(KEYS|COLS)",
    `全等·未知键即停`          = "(未知|unknown|unexpected|多余|extra)[^\\n]*(stop|STOP|abort)",
    `子集·具名取键`            = "\\[\\[\\s*['\"]",
    `子集·%in% 存在性`         = "%in%\\s*names|names\\s*\\([^)]*\\)\\s*%in%",
    `子集·is.null 兜底`        = "is\\.null\\s*\\(",
    `子集·vapply 白名单遍历`   = "vapply|lapply")
hit <- rbindlist(lapply(names(pat), function(k) {
    i <- grep(pat[[k]], code, perl = TRUE)
    data.table(模式 = k, 命中 = length(i),
               首现 = if (length(i)) trimws(substr(code[i[1]], 1, 72)) else "—") }))
cat("═══ 一 · 静态模式扫描（方向敏感）═══\n"); print(hit)
.e <- sum(hit[grepl("^全等", 模式), 命中]); .s <- sum(hit[grepl("^子集", 模式), 命中])
cat(sprintf("\n  静态倾向：全等 %d ／ 子集 %d → %s\n", .e, .s,
            if (.e > 0) "疑似【全等校验】，须动态坐实" else "疑似【子集读取】，须动态坐实"))
cat("  ⚠ SC-23：正则命中不等于语义成立。静态段只作分诊，一律以动态段为准。\n\n")

## ══════════════════════════════════════════════════════════════════════════
## 二 · D-2a · canonical namespace 锚定（★ 自 loader 源码反解，不硬写键名）
## ══════════════════════════════════════════════════════════════════════════
## 裁示已指明「不要因为名字看起来正确就硬编码」。故此处不问「哪个键长得像
## typologies」，而问「**loader 实际去读哪个键**」——以其源码为证据。
Y <- yaml::read_yaml(YAML_C)

.ln <- code[grepl("type_id", code, fixed = TRUE)]
.k1 <- unlist(regmatches(.ln, gregexpr("(?<=\\$)[A-Za-z_][A-Za-z0-9_.]*", .ln, perl = TRUE)))
.k2 <- unlist(regmatches(.ln, gregexpr('(?<=\\[\\[")[^"]+(?="\\]\\])',     .ln, perl = TRUE)))
.k3 <- unlist(regmatches(.ln, gregexpr("(?<=\\[\\[')[^']+(?='\\]\\])",     .ln, perl = TRUE)))
.derived <- unique(c(.k1, .k2, .k3))
ANCHOR <- intersect(.derived, names(Y))

cat("═══ 二 · D-2a canonical namespace 锚定 ═══\n")
cat("  YAML 顶层键：", paste(names(Y), collapse = ", "), "\n")
cat("  自 loader 含 type_id 之行反解得键：", paste(.derived, collapse = ", "), "\n")
cat("  与 YAML 顶层取交集 →", if (length(ANCHOR)) paste(ANCHOR, collapse = ", ") else "（空）", "\n")

.ok_anchor <- FALSE
if (length(ANCHOR) != 1L) {
    cat(sprintf("  ⛔ 锚定失败：得 %d 个候选。探针拒绝猜测，逐类实验不执行。\n", length(ANCHOR)))
} else {
    TY <- Y[[ANCHOR]]
    .c1 <- is.list(TY) && length(TY) > 0
    .c2 <- .c1 && all(vapply(TY, is.list, logical(1)))
    .c3 <- .c2 && all(vapply(TY, function(e) !is.null(e[["type_id"]]) &&
                                 is.character(e[["type_id"]]) &&
                                 nzchar(e[["type_id"]]), logical(1)))
    .ids0 <- if (.c3) vapply(TY, function(e) e[["type_id"]], character(1)) else character(0)
    .c4 <- .c3 && !anyDuplicated(.ids0)
    cat(sprintf("  结构四验：非空列表 %s ｜逐项为列表 %s ｜逐项有 type_id %s ｜type_id 唯一 %s\n",
                .c1, .c2, .c3, .c4))
    .ok_anchor <- .c4
    if (!.ok_anchor) cat("  ⛔ 结构验证未过，逐类实验不执行。\n")
}
if (!.ok_anchor) { IDS_BEFORE <- character(0) } else {
    IDS_BEFORE <- .ids0
    cat(sprintf("  ✅ 锚定成功：`%s`，%d 个 type_id：%s\n",
                ANCHOR, length(IDS_BEFORE), paste(IDS_BEFORE, collapse = ", ")))
}
cat("  ⚠ 探针定位规则 ≠ 生产契约规则：本节所得只供本探针实验之用，\n",
    "    不得据以在生产 loader 内硬写任何键名。\n\n")

## ══════════════════════════════════════════════════════════════════════════
## 三 · 三臂实验（★ A0 为对照臂：隔离 yaml::write_yaml 之往返伪影）
## ══════════════════════════════════════════════════════════════════════════
tmp <- file.path(tempdir(), "probe_registry_v102")
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
            out <<- do.call(f, setNames(list(yp), k))
        } else {
            for (nm in ls(env)) {
                v <- tryCatch(get(nm, envir = env), error = function(e) NULL)
                if (is.character(v) && any(grepl("registry_risk_typology.*\\.yaml$", v)))
                    assign(nm, yp, envir = env)
            }
            out <<- f()
        }
        "LOADED_OK"
    }, error   = function(e) paste0("STOPPED: ", conditionMessage(e)),
       warning = function(w) paste0("WARNED: ",  conditionMessage(w)))
    list(status = st, obj = out, path = yp)
}

.after_ids <- function(R) {
    if (is.null(R)) return(character(0))
    for (nm in c("dict", "typologies", "types", "meta")) {
        x <- R[[nm]]; if (is.null(x)) next
        if (is.data.frame(x) && "type_id" %in% names(x)) return(as.character(x[["type_id"]]))
        if (is.list(x) && length(x) && all(vapply(x, function(e) is.list(e) &&
                                                      !is.null(e[["type_id"]]), logical(1))))
            return(vapply(x, function(e) as.character(e[["type_id"]]), character(1)))
    }
    character(0)
}

## ── A0 · 对照臂：原样回写、零注入 ─────────────────────────────────────────
A0 <- .run(Y, "A0_control")
cat("═══ 三 · 三臂实验 ═══\n")
cat("  A0 对照（原样回写·零注入）：", A0$status, "\n")

## ── A1 · 顶层注入未知键 ───────────────────────────────────────────────────
Y1 <- Y
Y1[["economic_metric_gate"]] <- list(probe = TRUE,
    note = "SCHEMA PROBE ONLY — 探针注入，禁落盘至在册档")
A1 <- .run(Y1, "A1_toplevel")
cat("  A1 顶层注入 economic_metric_gate：", A1$status, "\n")

## ── A2 · 逐类注入未知键（全类，非只首条）─────────────────────────────────
A2 <- list(status = "SKIPPED（锚定未成）", obj = NULL)
if (.ok_anchor) {
    Y2 <- Y1
    for (i in seq_along(Y2[[ANCHOR]]))
        Y2[[ANCHOR]][[i]][["economic_metrics"]] <- list(
            economic_subject = "member", grain = "uid × window",
            scale_metrics = list("stake_all"), outcome_metrics = list("member_roi"))
    A2 <- .run(Y2, "A2_perclass")
    cat(sprintf("  A2 逐类注入 economic_metrics（全 %d 条）：%s\n",
                length(IDS_BEFORE), A2$status))
} else cat("  A2 逐类注入：SKIPPED（锚定未成，探针拒绝猜测）\n")

## ══════════════════════════════════════════════════════════════════════════
## 四 · D-3a 完整性：数量恒等 ＋ type_id 集合恒等
## ══════════════════════════════════════════════════════════════════════════
.integrity <- function(R, before) {
    a <- .after_ids(R)
    if (!length(before) || !length(a)) return(list(v = NA, n_a = length(a), a = a))
    list(v = (length(before) == length(a)) && setequal(before, a) &&
             !anyDuplicated(a), n_a = length(a), a = a)
}
I0 <- .integrity(A0$obj, IDS_BEFORE)
I1 <- .integrity(A1$obj, IDS_BEFORE)
I2 <- .integrity(A2$obj, IDS_BEFORE)

cat("\n═══ 四 · D-3a 完整性（数量 ＋ 集合）═══\n")
cat(sprintf("  注入前 type_id：%d 个\n", length(IDS_BEFORE)))
for (nm in c("A0", "A1", "A2")) {
    I <- get(paste0("I", substr(nm, 2, 2)))
    cat(sprintf("  %s 载入后：%d 个 ｜集合恒等 %s\n", nm, I$n_a,
                if (is.na(I$v)) "NA（无从核实）" else if (I$v) "✅" else "❌"))
    if (isFALSE(I$v) && length(IDS_BEFORE)) {
        cat("     少了：", paste(setdiff(IDS_BEFORE, I$a), collapse = ", "), "\n")
        cat("     多了：", paste(setdiff(I$a, IDS_BEFORE), collapse = ", "), "\n")
        cat("     重复：", paste(unique(I$a[duplicated(I$a)]), collapse = ", "), "\n")
    }
}

## ══════════════════════════════════════════════════════════════════════════
## 五 · D-3b 宿主完整性（★ 三态判读，非二态）
## ══════════════════════════════════════════════════════════════════════════
## ⚠ dict 是**投影**。子集读取型 loader 本就不把未知嵌套键投进输出——
##   「economic_metrics 不在 dict 里」**不是丢弃之证据**，是投影之常态。
##   丢弃与否之唯一定谳在 D-3a 之集合恒等，非本节。
.host <- function(R) {
    if (is.null(R)) return("N/A")
    found <- FALSE
    for (nm in names(R)) {
        x <- R[[nm]]
        if (is.data.frame(x) && "economic_metrics" %in% names(x)) { found <- TRUE; break }
        if (is.list(x) && !is.data.frame(x) && length(x) &&
            any(vapply(x, function(e) is.list(e) && !is.null(e[["economic_metrics"]]),
                       logical(1)))) { found <- TRUE; break }
    }
    if (found) "PRESERVED" else "NOT_PROJECTED"
}
H2 <- if (identical(A2$status, "LOADED_OK")) .host(A2$obj) else "N/A"
cat("\n═══ 五 · D-3b 宿主完整性（三态）═══\n")
cat("  A2 之 economic_metrics 在 loader 输出中：", H2, "\n")
cat(switch(H2,
  PRESERVED     = "  → 未知键被原样带出：loader 系透传型，additive 无疑。\n",
  NOT_PROJECTED = paste0("  → 未知键未进输出，**且未报错**：此为「子集读取」之正常表现，\n",
                         "     非丢弃。判丢弃与否请看 D-3a。\n"),
  "  → 本臂未执行或未载入，本节不适用。\n"))

## ══════════════════════════════════════════════════════════════════════════
## 六 · 裁定（五态）
## ══════════════════════════════════════════════════════════════════════════
cat("\n═══ 六 · 裁定 ═══\n")
V <- if (!identical(A0$status, "LOADED_OK")) {
        "ARTIFACT"
     } else if (!.ok_anchor || identical(A2$status, "SKIPPED（锚定未成）")) {
        "PROVISIONAL"
     } else if (!identical(A1$status, "LOADED_OK") || !identical(A2$status, "LOADED_OK")) {
        "STRICT"
     } else if (isTRUE(I1$v) && isTRUE(I2$v)) {
        "CONFIRMED"
     } else if (isFALSE(I1$v) || isFALSE(I2$v)) {
        "SILENT_DROP"
     } else "PROVISIONAL"

cat(switch(V,
 ARTIFACT = paste0(
   "  【本法失效 · ARTIFACT】对照臂 A0 零注入即 STOP —— 故障出在 yaml::write_yaml\n",
   "   之往返伪影，非 loader 拒未知键。**不得据本轮裁 loader 契约**；\n",
   "   须改以「不经回写之注入法」（如直接构造 YAML 文本追加）重做。\n"),
 STRICT = paste0(
   "  【全等校验 · STRICT】A0 通过而注入臂 STOP —— 确系拒未知键。\n",
   "   版级推论：新增区块即 breaking → 须【先升 loader，后升登记册】，次序不可颠倒。\n"),
 CONFIRMED = paste0(
   "  【子集读取 · CONFIRMED】三臂皆 LOADED_OK，且 type_id 集合恒等。\n",
   "   版级推论：economic_metrics: / economic_metric_gate: 属 additive schema，\n",
   "   路径 v1.5.0 → v1.5.1（PATCH）→ v1.6.0（MINOR），**无须 v2.0.0**。\n"),
 SILENT_DROP = paste0(
   "  【静默丢弃 · SILENT_DROP】未报错，惟 type_id 集合已变 —— 此比 STOP 更凶险。\n",
   "   不得判为 additive；须先查 loader 何以吞条目，再论版级。\n"),
 PROVISIONAL = paste0(
   "  【PROVISIONAL】决定性测试未完整执行（锚定未成或完整性无从核实）。\n",
   "   **不得宣布 v1.6.0**，须补齐后重判。\n")))

cat("\n  ⚠ 无论判定为何，皆不得跳级：v1.5.0 → v2.0.0 为纪律所禁。\n")
cat("  ⚠ 本探针未改任何在册档；探针副本置于：", tmp, "\n")

## ── 措辞锁：结论不得脱离其锚被引用 ────────────────────────────────────────
cat("\n═══ 七 · 结论措辞锁（引用时须整句照录）═══\n")
cat(sprintf(paste0(
  "  「MD5 %s 所对应之现档 registry_loader.R（%d 行／%d 字节），\n",
  "    对 YAML MD5 %s（%d 行）之%s测试，裁定为 %s。」\n"),
  S_LOADER$md5, S_LOADER$line, S_LOADER$byte, S_YAML$md5, S_YAML$line,
  if (.ok_anchor) "顶层与逐类双注入" else "顶层注入（逐类未执行）", V))
if (.S2) cat("  ⚠ 且须并录：该 loader 与在册登记（447 行／c90f7547…）不符，S2 失锚未销。\n")
cat("  ⚠ 禁写作「registry_loader 已证明是 additive schema」——\n",
    "    「某一 MD5 之现档通过某一测试」与「该档已被证明」是两个命题。\n")
