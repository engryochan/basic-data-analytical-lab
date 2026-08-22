# =====================================================================
# migrate_registry_v1_5_0.R · 登记册 v1.4.0 → v1.5.0 三向变换器
# ---------------------------------------------------------------------
# 版本 : 1.0.0        日期 : 2026-08-22
# 身份 : 执行件（函数/ 命名空间）★ 非交付件、非规范件
# ---------------------------------------------------------------------
# 【职责】只读 v1.4.0 双档，写出 v1.5.0 双档 + P0-0 双向差异表。
#         不写回 v1.4.0。v1.4.0 是回滚锚点（Git 提交 571eef4b）。
#
# 【三向变换】
#   变换一 判据层下沉 CSV -> YAML
#       criterion_role / threshold_status(四枚举) / threshold_note(原文)
#       / direction（非 STAT_DIRECTIONAL 一律清空）
#       连接键 = (type_id, column)
#   变换二 标量上载 YAML -> CSV
#       8 条叶标量，32 列 -> 40 列
#       T-03 四禁令 : ranking scoring trigger enforcement
#       T-10 内控四 : admit_to_control identity_formula
#                     external_standard_status applicability_status
#   变换三 schema 立册
#       枚举册 / direction_rule / 四组状态枚举 / unlock_predicate 补
#       causal_status / field_scope_registry / csv_scope / registry_counts
#
# 【零猜测铁律】
#   一切计数现算，无一硬写。YAML 变换采【文本外科】而非 parse-reserialize
#   —— 后者会重排全册中文之引号与折行，违「原文一字不删」。
#   yaml::yaml.load 仅用于校验与取值，不用于产出。
#
# 【形制铁律】
#   YAML = UTF-8 无 BOM + LF        CSV = UTF-8 含 BOM + LF
#   写出后自算并比对，形制不符即 stop()
#
# 【自拒条件】任一触发即不出档（见 §6）
#   SR-1 连接键不全对齐         SR-2 threshold_note 与原文不等
#   SR-3 非 STAT_DIRECTIONAL 残留 direction
#   SR-4 三枚举值域越界         SR-5 嵌套键被写入 CSV（白名单式）
#   SR-6 产出与 v1.4.0 自证 invariants 不符
#   SR-7 产出 YAML 不可解析／回读不符   SR-8 键名静默丢失（SC-36）
#
# 【用法】setwd("<a168 项目根>") ; source("函数/migrate_registry_v1_5_0.R")
#         migrate_v1_5_0()                # 干跑，只校验不写档
#         migrate_v1_5_0(write = TRUE)    # 校验通过后写出
# =====================================================================

stopifnot(requireNamespace("yaml", quietly = TRUE))

# ---------------------------------------------------------------------
# §0 常量 · 路径与形制
# ---------------------------------------------------------------------

MIG <- list(
  src_yaml = file.path("规范", "registry_risk_typology_v1_4_0.yaml"),
  src_csv  = file.path("规范", "registry_risk_typology_v1_4_0.csv"),
  # SC-29：点号版本号，非下划线
  out_yaml = file.path("规范", "registry_risk_typology_v1.5.0.yaml"),
  out_csv  = file.path("规范", "registry_risk_typology_v1.5.0.csv"),
  out_diff = file.path("审计", "证据", "P0-0_双向差异表.csv"),
  from_ver = "1.4.0",
  to_ver   = "1.5.0",
  issued   = format(Sys.Date(), "%Y-%m-%d")
)

# 【SR-5 白名单】判据层字段之唯一合法全集。
#   下沉后 criterion_columns 每项恰有此 7 键，多一键少一键皆自拒。
CRIT_FIELDS <- c("column", "source", "criterion_role",
                 "direction", "threshold", "threshold_status", "threshold_note")

# 【SR-5 白名单】可上载入 CSV 之叶标量，按名单判，不按计数判。
#   前版规格作「7 个嵌套键」之计数式自拒 —— 该计数已实测为 8
#   （漏计 T-05 labelled_samples），且计数式本身不可执行。今改名单式。
SCALAR_UPLOAD <- c("ranking", "scoring", "trigger", "enforcement",
                   "admit_to_control", "identity_formula",
                   "external_standard_status", "applicability_status")

# 【SR-5 黑名单】型层嵌套键，一律不得入 CSV。实测 8 个，非 7 个。
NESTED_FORBIDDEN <- c("criterion_columns", "unblock_conditions",
                      "shadow_requirements", "observed_facts",
                      "forbidden_sources", "falsification_evidence",
                      "rejected_variants", "labelled_samples")

# 四组状态枚举之声明词表（闭词表）。
#   observed 须为 declared 之子集；declared 而未 observed 者为解锁靶标，
#   非填充 —— 如 causal_status.ESTABLISHED 正是新 unlock_predicate 之所指。
STATUS_ENUMS <- list(
  phenomenon_status       = c("OBSERVED", "INFERRED", "UNKNOWN"),
  label_validation_status = c("NOT_TESTED", "TESTED_PASS", "TESTED_FAIL",
                              "REFUTED", "BLOCKED", "NOT_APPLICABLE"),
  causal_status           = c("NOT_ESTABLISHED", "ESTABLISHED",
                              "REFUTED", "NOT_APPLICABLE"),
  lifecycle_state         = c("SHADOW_MODEL", "PROFILE_CANDIDATE",
                              "FATAL_PROFILE_ONLY", "INTERNAL_CONTROL")
)

CRITERION_ROLE_ENUM   <- c("STAT_DIRECTIONAL", "REFERENCE", "JOIN_KEY",
                           "PROFILE_ONLY", "BUCKET", "FILTER", "FLAG",
                           "RANK", "STATE", "IDENTITY")
THRESHOLD_STATUS_ENUM <- c("PENDING_INVERSE", "NO_THRESHOLD_BY_DESIGN",
                           "BLOCKED", "NOT_APPLICABLE")
DIRECTION_ENUM        <- c("high", "low", "jump", "abnormal")

.say  <- function(...) cat(sprintf(...), "\n", sep = "")
.halt <- function(code, ...) stop(sprintf("[%s] %s", code, sprintf(...)), call. = FALSE)

# 连接键构造器：U+0001 为分隔符，不可能出现于 type_id 或列名之中。
.jkey <- function(type_id, column) paste(type_id, column, sep = intToUtf8(1L))

# --- SC-36 形制补丁：静默丢键 -----------------------------------------
# R 之 yaml 解析器将「以 null/Null/NULL/~ 起头、后接非 ASCII」之【未加引号】
# 键名解析为 null，致键名整个丢失，值尚在而键已亡，按名取用得 NULL 且不报错。
# 实测中招：T-05.labelled_samples.lock_checks 之「NULL与重复」。
# 加引号即愈——纯序列化修补，零语义变更。
.quote_lossy_keys <- function(lines) {
  pat <- "^([[:space:]]*)((?:null|Null|NULL|~)[^:\"']*):([[:space:]].*|)$"
  hit <- grep(pat, lines)
  if (length(hit))
    lines[hit] <- sub(pat, "\\1\"\\2\":\\3", lines[hit])
  attr(lines, "quoted") <- length(hit)
  lines
}

# 遍历解析结果，找出名字为 NA 或空之键（即已丢失者）。
.scan_lost_keys <- function(x, path = "REG") {
  out <- character(0)
  if (is.list(x)) {
    nm <- names(x)
    if (!is.null(nm)) {
      bad <- which(is.na(nm) | !nzchar(nm))
      if (length(bad)) out <- c(out, sprintf("%s[[%d]]", path, bad))
    }
    for (i in seq_along(x))
      out <- c(out, .scan_lost_keys(x[[i]],
        sprintf("%s$%s", path, if (is.null(nm) || is.na(nm[i])) i else nm[i])))
  }
  out
}

# ---------------------------------------------------------------------
# §1 读入 · 只读，形制感知
# ---------------------------------------------------------------------

read_text_utf8 <- function(path) {
  if (!file.exists(path)) .halt("IO-01", "档不在位：%s", path)
  raw <- readBin(path, "raw", file.size(path))
  has_bom <- length(raw) >= 3L &&
    identical(as.integer(raw[1:3]), c(239L, 187L, 191L))   # 0xEF 0xBB 0xBF
  if (has_bom) raw <- raw[-(1:3)]
  txt <- rawToChar(raw); Encoding(txt) <- "UTF-8"
  list(text = txt, bom = has_bom,
       crlf = grepl("\r\n", txt, fixed = TRUE),
       lines = strsplit(txt, "\n", fixed = TRUE)[[1L]])
}

read_registry_csv <- function(path) {
  f <- read_text_utf8(path)
  if (!f$bom) .halt("FM-01", "CSV 应含 BOM，实测无：%s", path)
  if (f$crlf) .halt("FM-02", "CSV 应为 LF，实测含 CRLF：%s", path)
  utils::read.csv(text = f$text, stringsAsFactors = FALSE,
                  colClasses = "character", check.names = FALSE,
                  na.strings = character(0))
}

# ---------------------------------------------------------------------
# §2 勘定 · 连接键对齐
# ---------------------------------------------------------------------

# 自 YAML 文本抽出 criterion_columns 之 (type_id, column) 序列及其行界。
scan_yaml_criteria <- function(lines) {
  ty_start <- grep("^typologies:", lines)
  if (length(ty_start) != 1L) .halt("YS-01", "typologies 顶层键非唯一")
  top <- grep("^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:", lines)
  ty_end <- min(c(top[top > ty_start], length(lines) + 1L)) - 1L

  out <- list(); cur_type <- NA_character_; in_crit <- FALSE
  i <- ty_start + 1L
  while (i <= ty_end) {
    l <- lines[i]
    if (grepl("^- type_id:", l)) {
      cur_type <- trimws(sub("^- type_id:", "", l)); in_crit <- FALSE
    } else if (grepl("^  criterion_columns:[[:space:]]*$", l)) {
      in_crit <- TRUE
    } else if (in_crit && grepl("^  - column:", l)) {
      col <- trimws(sub("^  - column:", "", l))
      j <- i + 1L
      while (j <= ty_end && grepl("^    [a-z_]+:", lines[j])) j <- j + 1L
      body <- lines[(i + 1L):(j - 1L)]
      kv <- stats::setNames(
        as.list(trimws(sub("^    [a-z_]+:", "", body))),
        sub("^    ([a-z_]+):.*$", "\\1", body))
      out[[length(out) + 1L]] <- list(type_id = cur_type, column = col,
                                      from = i, to = j - 1L, kv = kv)
      i <- j - 1L
    } else if (in_crit && grepl("^  [a-z_]+:", l)) {
      in_crit <- FALSE
    }
    i <- i + 1L
  }
  out
}

# ---------------------------------------------------------------------
# §3 变换一 · 判据层下沉（文本外科）
# ---------------------------------------------------------------------

emit_crit_item <- function(rec) {
  # 以 CSV 之权威值重铸一条 criterion_columns 项，字段顺序固定为 CRIT_FIELDS。
  # threshold_note 直取 YAML 原 threshold_status 之原文，一字不删。
  f <- function(k, v) sprintf("    %s: %s", k, v)
  c(sprintf("  - column: %s", rec$column),
    f("source",           rec$source),
    f("criterion_role",   rec$criterion_role),
    f("direction",        if (nzchar(rec$direction)) rec$direction else "''"),
    f("threshold",        if (nzchar(rec$threshold)) rec$threshold else "null"),
    f("threshold_status", rec$threshold_status),
    f("threshold_note",   rec$threshold_note))
}

# ---------------------------------------------------------------------
# §4/§5 辅助
# ---------------------------------------------------------------------

build_registry_counts <- function(csvdf) {
  # 一律现算。任何数字不得硬写。
  is_r <- csvdf$axis == "R"
  list(
    total_criterion_rows    = nrow(csvdf),
    risk_typology_count     = length(unique(csvdf$type_id[is_r])),
    value_axis_count        = length(unique(csvdf$type_id[!is_r])),
    risk_criterion_count    = sum(is_r),
    stat_directional_rows   = sum(csvdf$criterion_role == "STAT_DIRECTIONAL"),
    direction_enum_size     = length(setdiff(unique(csvdf$direction), "")),
    criterion_role_totals   = as.list(table(csvdf$criterion_role)),
    threshold_status_totals = as.list(table(csvdf$threshold_status))
  )
}

yaml_block <- function(key, obj) {
  # 以 yaml 包序列化新增段（新段无既有中文原文，序列化无损）。
  body <- yaml::as.yaml(stats::setNames(list(obj), key), indent = 2, line.sep = "\n")
  strsplit(sub("\n$", "", body), "\n", fixed = TRUE)[[1L]]
}

# ---------------------------------------------------------------------
# §6 自拒闸
# ---------------------------------------------------------------------

self_reject <- function(csvdf, ycrit, counts, new_csv_cols) {

  ## SR-1 连接键全对齐
  key_c <- .jkey(csvdf$type_id, csvdf$criterion_column)
  if (anyDuplicated(key_c))
    .halt("SR-1", "CSV 连接键 (type_id, column) 有重：%s",
          paste(key_c[duplicated(key_c)], collapse = ", "))
  key_y <- vapply(ycrit, function(x) .jkey(x$type_id, x$column),
                  character(1))
  only_y <- setdiff(key_y, key_c)
  only_c <- setdiff(key_c, key_y)
  only_c <- only_c[!startsWith(only_c, .jkey("V", ""))]   # V 轴判据合法地只在 CSV 侧
  if (length(only_y) || length(only_c))
    .halt("SR-1", "连接键不对齐：YAML 独有 %d 条，CSV 独有 %d 条",
          length(only_y), length(only_c))

  ## SR-2 threshold_note 与 YAML 原文逐行全等
  idx  <- match(key_y, key_c)
  orig <- vapply(ycrit, function(x) {
    v <- x$kv[["threshold_status"]]; if (is.null(v)) "" else v }, character(1))
  note <- csvdf$threshold_note[idx]
  bad  <- which(orig != note)
  if (length(bad))
    .halt("SR-2", "threshold_note 与原文不等 %d 行，首例：%s | 原=%s | 今=%s",
          length(bad), key_y[bad[1L]], orig[bad[1L]], note[bad[1L]])

  ## SR-3 direction 与 role 正交
  resid <- which(csvdf$criterion_role != "STAT_DIRECTIONAL" & nzchar(csvdf$direction))
  if (length(resid))
    .halt("SR-3", "非 STAT_DIRECTIONAL 残留 direction 共 %d 行", length(resid))
  miss <- which(csvdf$criterion_role == "STAT_DIRECTIONAL" & !nzchar(csvdf$direction))
  if (length(miss))
    .halt("SR-3", "STAT_DIRECTIONAL 缺 direction 共 %d 行", length(miss))

  ## SR-4 三枚举值域闭合 + 交叉断言
  if (!setequal(unique(csvdf$threshold_status), THRESHOLD_STATUS_ENUM))
    .halt("SR-4", "threshold_status 值域越界：%s",
          paste(sort(unique(csvdf$threshold_status)), collapse = ", "))
  if (!setequal(unique(csvdf$criterion_role), CRITERION_ROLE_ENUM))
    .halt("SR-4", "criterion_role 值域越界")
  if (!setequal(setdiff(unique(csvdf$direction), ""), DIRECTION_ENUM))
    .halt("SR-4", "direction 值域越界")
  sd_rows <- csvdf[csvdf$criterion_role == "STAT_DIRECTIONAL", ]
  if (!setequal(unique(sd_rows$threshold_status), c("PENDING_INVERSE", "BLOCKED")))
    .halt("SR-4", "方向判据之 threshold_status 超出 {PENDING_INVERSE, BLOCKED}")
  if (nrow(sd_rows) != counts$stat_directional_rows)
    .halt("SR-4", "stat_directional_rows 自相矛盾")

  ## SR-5 白名单式 —— 嵌套键不得入 CSV；上载列须恰为白名单
  leak <- intersect(new_csv_cols, NESTED_FORBIDDEN)
  if (length(leak))
    .halt("SR-5", "嵌套键被写入 CSV：%s", paste(leak, collapse = ", "))
  if (!all(SCALAR_UPLOAD %in% new_csv_cols))
    .halt("SR-5", "上载白名单不齐，缺：%s",
          paste(setdiff(SCALAR_UPLOAD, new_csv_cols), collapse = ", "))
  invisible(TRUE)
}

check_invariants <- function(counts, yml) {
  inv <- yml$invariants
  if (is.null(inv)) .halt("SR-6", "v1.4.0 缺 invariants 段，无法自证")
  cmp <- list(
    risk_typology_count        = counts$risk_typology_count,
    risk_criterion_count       = counts$risk_criterion_count,
    value_axis_count           = counts$value_axis_count,
    registered_criterion_count = counts$total_criterion_rows,
    stat_directional_count     = counts$stat_directional_rows
  )
  for (k in names(cmp)) {
    if (!is.null(inv[[k]]) && as.integer(inv[[k]]) != as.integer(cmp[[k]]))
      .halt("SR-6", "invariants.%s 声明 %s，现算 %s", k, inv[[k]], cmp[[k]])
  }
  for (rl in names(inv$criterion_role_totals)) {
    d <- as.integer(inv$criterion_role_totals[[rl]])
    o <- as.integer(counts$criterion_role_totals[[rl]])
    if (is.na(o) || d != o)
      .halt("SR-6", "criterion_role_totals.%s 声明 %s，现算 %s", rl, d, o)
  }
  .say("  OK SR-6 与 v1.4.0 invariants 自证全合（%d 项）",
       length(cmp) + length(inv$criterion_role_totals))
  invisible(TRUE)
}

# ---------------------------------------------------------------------
# §7 写出 · 形制强制
# ---------------------------------------------------------------------

write_text <- function(path, text, bom) {
  if (grepl("\r", text, fixed = TRUE))
    .halt("FM-03", "拟写出之文本含 CR：%s", path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  if (bom) writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)
  writeBin(charToRaw(enc2utf8(text)), con)
  invisible(path)
}

verify_form <- function(path, want_bom) {
  f <- read_text_utf8(path)
  if (f$bom != want_bom) .halt("FM-04", "%s BOM 期 %s 实 %s", basename(path), want_bom, f$bom)
  if (f$crlf)            .halt("FM-05", "%s 含 CRLF，应为 LF", basename(path))
  .say("  OK %-44s BOM=%-5s LF纯净  %8d bytes",
       basename(path), want_bom, file.size(path))
  invisible(TRUE)
}

csv_to_text <- function(df) {
  esc <- function(v) {
    v <- ifelse(is.na(v), "", as.character(v))
    need <- grepl('[",\n]', v)
    ifelse(need, paste0('"', gsub('"', '""', v, fixed = TRUE), '"'), v)
  }
  hdr <- paste(esc(names(df)), collapse = ",")
  bod <- vapply(seq_len(nrow(df)),
                function(i) paste(esc(unlist(df[i, ], use.names = FALSE)), collapse = ","),
                character(1))
  paste0(paste(c(hdr, bod), collapse = "\n"), "\n")
}

# =====================================================================
# 主程
# =====================================================================

migrate_v1_5_0 <- function(write = FALSE) {

  .say("\n%s", strrep("=", 72))
  .say("migrate_registry_v1_5_0 · %s -> %s  [%s]",
       MIG$from_ver, MIG$to_ver, if (write) "写出" else "干跑")
  .say("%s", strrep("=", 72))

  ## ---- §1 读入 ----
  .say("\n【§1 读入】")
  fy <- read_text_utf8(MIG$src_yaml)
  if (fy$bom)  .halt("FM-06", "YAML 不得含 BOM")
  if (fy$crlf) .halt("FM-07", "YAML 应为 LF")
  csvdf <- read_registry_csv(MIG$src_csv)
  yml   <- yaml::yaml.load(fy$text)
  .say("  YAML %d 行 · %d 顶层键", length(fy$lines), length(yml))
  .say("  CSV  %d 行 x %d 列", nrow(csvdf), ncol(csvdf))

  ## ---- §2 勘定 ----
  .say("\n【§2 勘定 · 连接键】")
  ycrit <- scan_yaml_criteria(fy$lines)
  .say("  YAML criterion_columns 项 %d · CSV 行 %d · V 轴 %d",
       length(ycrit), nrow(csvdf), sum(csvdf$axis != "R"))

  ## ---- §4 变换二 · 标量上载 ----
  .say("\n【§4 变换二 · 标量上载 YAML -> CSV】")
  tys <- yml$typologies
  names(tys) <- vapply(tys, function(t) t$type_id, character(1))
  for (k in SCALAR_UPLOAD) {
    src <- vapply(names(tys), function(tid) {
      v <- tys[[tid]][[k]]
      if (is.null(v)) "" else if (is.logical(v)) toupper(as.character(v)) else as.character(v)
    }, character(1))
    if (!any(nzchar(src))) .halt("SR-5", "白名单键 %s 在 YAML 中全空", k)
    val <- unname(src[match(csvdf$type_id, names(src))])
    val[is.na(val)] <- ""
    csvdf[[k]] <- val
    owners <- unique(csvdf$type_id[nzchar(val)])
    .say("  + %-26s 存于 %s（%d 行）", k, paste(owners, collapse = ","), sum(nzchar(val)))
  }
  .say("  列数 32 -> %d", ncol(csvdf))

  ## ---- 现算计数 ----
  counts <- build_registry_counts(csvdf)
  .say("\n【现算计数 · 无一硬写】")
  .say("  total_criterion_rows  = %d", counts$total_criterion_rows)
  .say("  risk_typology_count   = %d   <- 前版规格误作 14", counts$risk_typology_count)
  .say("  risk_criterion_count  = %d", counts$risk_criterion_count)
  .say("  stat_directional_rows = %d", counts$stat_directional_rows)
  .say("  direction_enum_size   = %d", counts$direction_enum_size)

  ## ---- §6 自拒闸 ----
  .say("\n【§6 自拒闸】")
  self_reject(csvdf, ycrit, counts, names(csvdf))
  .say("  OK SR-1 连接键 %d 条全对齐", length(ycrit))
  .say("  OK SR-2 threshold_note 与原文逐行全等")
  .say("  OK SR-3 非 STAT_DIRECTIONAL 残留 direction = 0")
  .say("  OK SR-4 三枚举值域闭合")
  .say("  OK SR-5 白名单 %d 键全到；黑名单 %d 嵌套键零泄漏",
       length(SCALAR_UPLOAD), length(NESTED_FORBIDDEN))
  check_invariants(counts, yml)

  ## ---- 四组状态枚举 coverage ----
  .say("\n【四组状态枚举 · declared 包含 observed】")
  cov <- lapply(names(STATUS_ENUMS), function(k) {
    obs <- sort(unique(csvdf[[k]])); dec <- STATUS_ENUMS[[k]]
    over <- setdiff(obs, dec)
    if (length(over)) .halt("SR-4", "%s 越界：%s", k, paste(over, collapse = ", "))
    gap <- setdiff(dec, obs)
    .say("  %-25s declared %d · observed %d · 待解锁 %s", k,
         length(dec), length(obs), if (length(gap)) paste(gap, collapse = ",") else "无")
    list(field = k, declared = dec, observed = obs, declared_not_observed = gap)
  })
  names(cov) <- names(STATUS_ENUMS)

  if (!write) {
    .say("\n%s", strrep("-", 72))
    .say("干跑完毕：七道自拒闸全通，未写任何档。")
    .say("写出请执：migrate_v1_5_0(write = TRUE)")
    return(invisible(list(csv = csvdf, counts = counts, coverage = cov)))
  }

  ## ---- §3 变换一 · 判据层下沉（文本外科） ----
  .say("\n【§3 变换一 · 判据层下沉 CSV -> YAML】")
  key_c <- .jkey(csvdf$type_id, csvdf$criterion_column)
  lines <- fy$lines
  n_split <- 0L
  for (rec in rev(ycrit)) {                       # 自后向前，行号不失效
    r <- csvdf[match(.jkey(rec$type_id, rec$column), key_c), ]
    if (!identical(rec$kv[["direction"]], r$direction)) n_split <- n_split + 1L
    blk <- emit_crit_item(list(column = rec$column, source = r$criterion_source,
                               criterion_role = r$criterion_role,
                               direction = r$direction, threshold = r$threshold,
                               threshold_status = r$threshold_status,
                               threshold_note = r$threshold_note))
    lines <- append(lines[-(rec$from:rec$to)], blk, after = rec$from - 1L)
  }
  .say("  OK %d 条判据重铸为 %d 字段制（role 自 direction 分离 %d 条）",
       length(ycrit), length(CRIT_FIELDS), n_split)

  ## V 轴判据同步下沉入 value_axis
  vrow <- csvdf[csvdf$axis != "R", ][1L, ]
  va <- grep("^value_axis:", lines)[1L]
  vc <- grep("^  criterion_column:", lines); vc <- vc[vc > va][1L]
  lines <- append(lines, c(
    sprintf("  criterion_role: %s", vrow$criterion_role),
    "  direction: ''",
    sprintf("  threshold_status: %s", vrow$threshold_status),
    sprintf("  threshold_note: %s", vrow$threshold_note)), after = vc)
  .say("  OK V 轴判据（%s）同步下沉入 value_axis", vrow$criterion_column)

  ## ---- §5 变换三 · schema 立册 ----
  .say("\n【§5 变换三 · schema 立册】")

  vl <- grep("^  version: ", lines)[1L];  lines[vl] <- sprintf("  version: %s", MIG$to_ver)
  il <- grep("^  issued: ",  lines)[1L];  lines[il] <- sprintf("  issued: '%s'", MIG$issued)

  # unlock_predicate 补 causal_status（L3 因果层）
  up <- grep("^  risk_decision_unlock:", lines)[1L]
  ue <- up; while (ue + 1L <= length(lines) && grepl("^    ", lines[ue + 1L])) ue <- ue + 1L
  lines <- append(lines[-(up:ue)], c(
    "  risk_decision_unlock: (gates.G01=='PASS') AND (gates.G02=='PASS') AND (gates.G03=='PASS')",
    "    AND (gates.G04=='PASS') AND (gates.G05=='PASS')",
    "    AND (type.label_validation_status=='TESTED_PASS')",
    "    AND (type.causal_status=='ESTABLISHED')",
    "    AND (mcid_cost_anchor_status=='ESTABLISHED')"), after = up - 1L)
  rl <- grep("^  - 五门任一非 PASS", lines)[1L]
  if (!is.na(rl)) lines <- append(lines, paste0(
    "  - L3 因果层不得跳过：causal_status 非 ESTABLISHED 时 ",
    "admit_to_risk_decision 不得解锁（v1.5.0 新增，补 L3）"), after = rl)

  newsec <- c(
    yaml_block("criterion_role_enum",   as.list(CRITERION_ROLE_ENUM)),
    yaml_block("threshold_status_enum", as.list(THRESHOLD_STATUS_ENUM)),
    yaml_block("direction_enum",        as.list(DIRECTION_ENUM)),
    yaml_block("direction_rule", list(
      rule = paste0("direction 仅于 criterion_role == 'STAT_DIRECTIONAL' 时取值；",
                    "其余一律为空字符串。v1.4.0 之前 YAML 将 role 混入 direction",
                    "（ref/filter/join/profile_only 等），v1.5.0 二者正交分离。"),
      enforced_by = "migrate_registry_v1_5_0.R §6 SR-3",
      applies_to  = "typologies[].criterion_columns[] 与 value_axis")),
    yaml_block("status_enums", lapply(cov, function(x) list(
      declared              = as.list(x$declared),
      observed              = as.list(x$observed),
      declared_not_observed = as.list(x$declared_not_observed),
      note = "declared 为闭词表；declared 减 observed 为解锁靶标，非填充。"))),
    yaml_block("field_scope_registry", list(
      note = paste0("schema contract：只描述字段域，不承载值。",
                    "本册非第三份登记册，SSOT 仍为 YAML 单一。"),
      criterion_level              = as.list(CRIT_FIELDS),
      type_level_scalar_uploadable = as.list(SCALAR_UPLOAD),
      type_level_nested_yaml_only  = as.list(NESTED_FORBIDDEN),
      enforcement = "白名单式，非计数式（§6 SR-5）")),
    yaml_block("csv_scope", list(
      statement = paste0("CSV 为 YAML 之扁平投影，非独立 SSOT。",
                         "每行 = 一条登记判据（type_id x criterion_column）。"),
      columns         = ncol(csvdf),
      rows            = nrow(csvdf),
      excludes        = as.list(NESTED_FORBIDDEN),
      excludes_reason = "嵌套结构不可无损扁平，扁平即失真",
      round_trip      = "CSV -> YAML 可复原判据层；YAML -> CSV 必有损")),
    yaml_block("registry_counts", counts))
  lines <- c(lines, "", newsec)
  .say("  + criterion_role_enum(%d) threshold_status_enum(%d) direction_enum(%d)",
       length(CRITERION_ROLE_ENUM), length(THRESHOLD_STATUS_ENUM), length(DIRECTION_ENUM))
  .say("  + direction_rule · status_enums(4) · field_scope_registry · csv_scope · registry_counts")
  .say("  ~ unlock_predicate 补 causal_status（L3 因果层）")

  ## ---- §7 写出 ----
  .say("\n【§7 写出与形制自检】")
  lines <- .quote_lossy_keys(lines)
  .say("  ~ SC-36 丢键补丁：加引号之键 %d 处", attr(lines, "quoted"))
  ytxt <- sub("\n+$", "\n", paste0(paste(lines, collapse = "\n"), "\n"))
  if (inherits(try(yaml::yaml.load(ytxt), silent = TRUE), "try-error"))
    .halt("SR-7", "产出 YAML 不可解析，拒写")
  write_text(MIG$out_yaml, ytxt, bom = FALSE)
  write_text(MIG$out_csv,  csv_to_text(csvdf), bom = TRUE)
  verify_form(MIG$out_yaml, FALSE)
  verify_form(MIG$out_csv,  TRUE)

  ## 回读复核
  back <- yaml::yaml.load(read_text_utf8(MIG$out_yaml)$text)
  nb <- sum(vapply(back$typologies, function(t) length(t$criterion_columns), integer(1)))
  if (nb != length(ycrit)) .halt("SR-7", "回读判据数 %d 不等于 %d", nb, length(ycrit))
  if (as.integer(back$registry_counts$risk_typology_count) != counts$risk_typology_count)
    .halt("SR-7", "回读 registry_counts 不符")
  bad_field <- Filter(Negate(is.null), lapply(back$typologies, function(t)
    if (!all(vapply(t$criterion_columns,
                    function(cc) setequal(names(cc), CRIT_FIELDS), logical(1))))
      t$type_id))
  if (length(bad_field))
    .halt("SR-7", "回读判据字段集不合 CRIT_FIELDS：%s", paste(bad_field, collapse = ","))
  .say("  OK 回读复核：%d 条判据 · 7 字段制齐整 · registry_counts 一致", nb)

  ## SR-8 零丢键（SC-36）
  lost <- .scan_lost_keys(back)
  if (length(lost))
    .halt("SR-8", "产出 YAML 有 %d 处键名静默丢失：%s",
          length(lost), paste(utils::head(lost, 5), collapse = ", "))
  .say("  OK SR-8 零丢键：全册键名解析后无一为 NA 或空")

  ## ---- §8 P0-0 双向差异表 ----
  .say("\n【§8 P0-0 双向差异表】")
  d1 <- do.call(rbind, lapply(ycrit, function(rec) {
    r <- csvdf[match(.jkey(rec$type_id, rec$column), key_c), ]
    od <- rec$kv[["direction"]]; if (is.null(od)) od <- ""
    data.frame(scope = "criterion",
               key   = paste(rec$type_id, rec$column, sep = "/"),
               field = "direction",
               v1_4_0 = od,
               v1_5_0 = if (nzchar(r$direction)) r$direction else "(empty)",
               v1_5_0_role = r$criterion_role,
               change = if (identical(od, r$direction)) "UNCHANGED" else "ROLE_SPLIT_OUT",
               stringsAsFactors = FALSE)
  }))
  d2 <- do.call(rbind, lapply(SCALAR_UPLOAD, function(k) {
    o <- unique(csvdf$type_id[nzchar(csvdf[[k]])])
    data.frame(scope = "type_scalar", key = paste(o, collapse = ","), field = k,
               v1_4_0 = "YAML_ONLY", v1_5_0 = "CSV+YAML", v1_5_0_role = "(n/a)",
               change = "UPLOADED_TO_CSV", stringsAsFactors = FALSE)
  }))
  diff <- rbind(d1, d2)
  write_text(MIG$out_diff, csv_to_text(diff), bom = TRUE)
  verify_form(MIG$out_diff, TRUE)
  tc <- table(diff$change)
  .say("  变更分布：%s", paste(sprintf("%s=%d", names(tc), as.integer(tc)), collapse = " · "))

  .say("\n%s", strrep("=", 72))
  .say("v1.5.0 出档完毕。v1.4.0 未被触碰（锚点完好）。")
  .say("%s\n", strrep("=", 72))
  invisible(list(csv = csvdf, counts = counts, diff = diff))
}
