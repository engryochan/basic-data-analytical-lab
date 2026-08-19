# =====================================================================
# R03b_cc_verifier.R · R03b 重导四层 Gate 核验器
# ---------------------------------------------------------------------
# 版本 : 1.3.0        日期 : 2026-08-18
#        1.3.0 ★ 性质斧正：事实记录（ACTUAL_EXECUTION）与审计规则
#              （RECOMMENDED_RUN_ORDER）严格分立。where_predicate 由「锁值」
#              改为「与 §A/§D 实测比对」；order_by 由「锁 K4 否则 STOP」改为
#              「只登记不阻断，不符则告警并随文携带后果」——纵审计判为应取 K4，
#              亦不得改写历史实际值。
#        1.2.0 Gate-0 补四道契约零：模板占位 <<FILL>> 检出、query_hash 以
#              source_sql 重算比对、where_predicate 与 order_by 逐字锁值、
#              导出时序合理性。配套模板 R03b_export_parameters_TEMPLATE.json。
#        1.1.0 斧正：业务键 member_id → uid；改以 K4 四键为主键集；
#              Gate-0 输入档改指 v2 三档（_v2 后缀）。
# 身份 : 核验工具（配置件），从属于 SQL 总包 §Z-20；★ 非权威文件
# ---------------------------------------------------------------------
# 【设计铁律】
#   ① **不预设任何行数**。旧记载 6,143,388 与 18,139,550 皆为
#      historical observation，本器一律不作期望值，只作事后对照登记。
#      本轮之期望行数唯一来源为 Gate-0 §A 现算之 db_row_count。
#   ② 任一 Gate 不过即 STOP，不得跳级；STOP 时抛错而非警告。
#   ③ 每一判定皆现算，判读契约先写死于函数内，禁止事后调参。
#
# 【输入】按 §Z-20 之约定，须备齐六档：
#   数据库/R03b_export_parameters.json   Gate-0 导出参数原始留痕
#   数据库/R03b_count_check.csv          Gate-0 §A  DB 侧总量与边界
#   数据库/R03b_keyorder_check.csv       Gate-0 §B  排序键全序性
#   数据库/R03b_page_manifest.csv        Gate-0 §C  分页清单
#   数据库/R03b_player_dealer_daily.csv  本轮重导之主档（Run A）
#   数据库/R03b_player_dealer_daily_runB.csv  复现用第二次导出（Run B）
#
# 【用法】
#   source("函数/R03b_cc_verifier.R")
#   res <- r03b_verify_all()          # 逐 Gate 执行，任一不过即 stop()
#   r03b_report(res)                  # kable 呈报
# =====================================================================

suppressPackageStartupMessages(library(data.table))
.cc_stage <- function(tag, expr) tryCatch(expr, error = function(e)
  stop(sprintf("【R03b·%s】%s", tag, conditionMessage(e)), call. = FALSE))

.cc_stop <- function(gate, reason, detail = "") {
  stop(sprintf("🔴 STOP · %s 未过：%s%s\n  依 §Z-20 STOP 条件，不得跳级续行，本项判 UNKNOWN。",
               gate, reason, if (nzchar(detail)) paste0("\n  ", detail) else ""),
       call. = FALSE)
}

R03B_PATHS <- list(
  params   = file.path("数据库", "R03b_export_parameters.json"),  ## 由模板填实后改此名
  count    = file.path("数据库", "R03b_count_check_v2.csv"),
  keyorder = file.path("数据库", "R03b_keyorder_check_v2.csv"),
  tiewin   = file.path("数据库", "R03b_tie_and_window_v2.csv"),
  manifest = file.path("数据库", "R03b_page_manifest.csv"),
  runA     = file.path("数据库", "R03b_player_dealer_daily.csv"),
  runB     = file.path("数据库", "R03b_player_dealer_daily_runB.csv")
)

## 业务唯一键：与 §Z-20 §B 所检定者必须一致
##   ⚠ v1.1.0 斧正：§R03b 主体输出为 `p.member_id AS uid`，
##     CSV 侧业务键为 uid 而非 member_id；v1.0.0 写 member_id 者取不到列。
##   ⚠ 双键并存（承 Gate-0 v2 §B）：
##     K3 = 现行 ORDER BY 三键；K4 = 实际 GROUP BY 四键（多 is_sentinel_dealer）。
##     本器以 K4 为准（若 §B 判 K4 唯一），K3 另作对照。
R03B_KEY_K3 <- c("bet_date", "uid", "dealer_id")
R03B_KEY_K4 <- c("bet_date", "uid", "dealer_id", "is_sentinel_dealer")
R03B_KEY    <- R03B_KEY_K4   ## 主键集；Gate-1／2 一律以此为业务唯一键

.cc_sixtuple <- function(path) {
  raw  <- readBin(path, "raw", n = file.size(path))
  crlf <- if (length(raw) > 1L)
            any(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L)) else FALSE
  data.table(文件名 = basename(path), 行数按LF计 = sum(raw == as.raw(10L)),
             字节数 = length(raw), MD5 = unname(tools::md5sum(path)),
             换行符 = if (crlf) "CRLF" else "LF",
             BOM = if (length(raw) >= 3L &&
                       identical(raw[1:3], as.raw(c(0xEF,0xBB,0xBF)))) "有" else "无")
}

# ---------------------------------------------------------------------
# Gate-0 · Export Parameters（导出参数必须为原始留痕，非人工转述）
# ---------------------------------------------------------------------
r03b_gate0 <- function(P = R03B_PATHS) {
  .cc_stage("Gate-0", {
    absent <- unlist(P)[!file.exists(unlist(P))]
    if (length(absent))
      .cc_stop("Gate-0", "输入档缺失",
               sprintf("当前工作目录 %s 之下未找到：%s", getwd(),
                       paste(basename(absent), collapse = "、")))

    if (!requireNamespace("jsonlite", quietly = TRUE))
      .cc_stop("Gate-0", "未安装 jsonlite，无法读取导出参数原始留痕")
    prm <- jsonlite::fromJSON(P$params)

    need <- c("source_sql", "database", "schema", "tables", "where_predicate",
              "order_by", "page_mode", "page_size", "export_started_at",
              "export_finished_at", "total_count_query", "query_hash")
    miss <- setdiff(need, names(prm))
    if (length(miss))
      .cc_stop("Gate-0", "导出参数缺字段", paste(miss, collapse = "、"))

    ## ★ 契约零：模板占位未填即判 MISSING
    ##   本项目已实证「可运行的占位」会静默产出假读数（v1 三档 VOID），
    ##   故此处不容许 <<FILL>> 蒙混过关。
    unfilled <- need[vapply(need, function(k)
      any(grepl("<<FILL>>", as.character(prm[[k]]), fixed = TRUE)), logical(1))]
    if (length(unfilled))
      .cc_stop("Gate-0", "导出参数仍留模板占位 <<FILL>>",
               sprintf("未填字段：%s —— 模板不填即不通过", paste(unfilled, collapse = "、")))

    ## ★ 契约零之二：query_hash 须以 source_sql 重算比对，杜绝手工编造
    if (requireNamespace("digest", quietly = TRUE)) {
      calc <- digest::digest(prm$source_sql, algo = "sha256", serialize = FALSE)
      if (!identical(tolower(gsub("^sha256:", "", tolower(prm$query_hash))), calc))
        .cc_stop("Gate-0", "query_hash 与 source_sql 之实算摘要不符",
                 sprintf("档载 %s ／ 实算 sha256 %s —— 参数留痕与所跑 SQL 不是同一份",
                         prm$query_hash, calc))
    } else {
      message("【R03b·Gate-0】未装 digest，query_hash 未重算比对；",
              "本次 Gate-0 之参数留痕仅达『字段齐备』级，未达『内容可信』级。")
    }

    ## ★ 契约零之三：where_predicate 与 §A/§D 实测窗口【比对】
    ##   ⚠ 性质分立（v1.2.0 斧正）：本档为事实记录，其 where_predicate 须原样照录
    ##     本次实际提交之谓词；此处不是「锁值」，是拿事实与实测边界比对。
    ##     不一致即 STOP —— 由比对判定，非由预填保证。
    .norm <- function(x) gsub("\\s+", " ", trimws(tolower(paste(x, collapse = " "))))
    exp_where <- if (!is.null(prm$`_audit_rules`$EXPECTED_WHERE_PREDICATE))
                   prm$`_audit_rules`$EXPECTED_WHERE_PREDICATE
                 else "dt >= '2026-03-21' AND dt < '2026-08-07'"
    if (!identical(.norm(prm$where_predicate), .norm(exp_where)))
      .cc_stop("Gate-0", "实际执行之 where_predicate 与 §A/§D 实测窗口不符",
               sprintf("实际执行「%s」；§A/§D 实测对照「%s」——两者不符即本次导出与本轮 Gate-0 之读数不同源，STOP",
                       paste(prm$where_predicate, collapse = " "), exp_where))

    ## ★ 契约零之五：order_by 只记录、不锁值；与推荐序不符则告警，不 STOP
    ##   ⛔ 纵审计判为应取 K4，亦不得改写历史实际值——事实记录不可为迁就规则而伪造。
    rec_ord <- if (!is.null(prm$`_audit_rules`$RECOMMENDED_RUN_ORDER))
                 prm$`_audit_rules`$RECOMMENDED_RUN_ORDER
               else "bet_date, uid, dealer_id, is_sentinel_dealer"
    ord_match <- identical(.norm(prm$order_by), .norm(rec_ord))
    if (!ord_match)
      message(sprintf(paste0(
        "【R03b·Gate-0】实际执行之 order_by 为「%s」，与推荐序「%s」不符。\n",
        "  ⚠ 本项【只登记不阻断】：事实记录须原样照录，不得为迁就审计规则而改写。\n",
        "  ⚠ 惟其后果须随文携带：K3 三键之 duplicate=0 系当前数据之偶然属性，\n",
        "     非结构性全序保证；据此排序之分页，其边界稳定性仅能由 CC-03 事后证明，\n",
        "     不可事前假定。下一次 Run A/B 应改用 K4（RISK-K3-fragile）。"),
        paste(prm$order_by, collapse = " "), rec_ord))

    ## ★ 契约零之四：导出时序须合理
    ts <- suppressWarnings(c(as.POSIXct(prm$export_started_at, tz = "UTC"),
                             as.POSIXct(prm$export_finished_at, tz = "UTC")))
    if (any(is.na(ts)))
      .cc_stop("Gate-0", "导出时间戳无法解析", "须为 ISO-8601 含时区偏移")
    if (ts[2] < ts[1])
      .cc_stop("Gate-0", "export_finished_at 早于 export_started_at")

    ## 契约一：ORDER BY 必须存在且非空
    if (!nzchar(trimws(paste(prm$order_by, collapse = ""))))
      .cc_stop("Gate-0", "ORDER BY 为空——分页无稳定边界，禁止导出")

    ## 契约二：禁 OFFSET 分页（本项目已实证 36.49% 重复率）
    if (grepl("offset", tolower(paste(prm$page_mode, collapse = " "))))
      .cc_stop("Gate-0", "page_mode 含 OFFSET",
               "本项目已实证 OFFSET 分页致 36.49% 重复行，一律改键集游标")

    ## 契约三：排序键须与 R03B_KEY 一致（否则边界核验对不上）
    ob <- tolower(gsub("[^a-z_,]", "", tolower(paste(prm$order_by, collapse = ","))))
    ## 最低要求：至少涵盖 K3 三键；K4 之取舍由上方契约零之五登记，不在此阻断
    if (!all(vapply(R03B_KEY_K3, function(k) grepl(k, ob, fixed = TRUE), logical(1))))
      .cc_stop("Gate-0", "ORDER BY 未涵盖业务唯一键（K3 三键为最低要求）",
               sprintf("须含 %s；实得 %s", paste(R03B_KEY, collapse = "、"),
                       paste(prm$order_by, collapse = ", ")))

    ## 契约四：排序键须经 §Z-20 §B 检定为全序
    ko <- fread(P$keyorder, encoding = "UTF-8")
    need_ko <- c("n_rows", "duplicate_K3_n", "duplicate_K4_n")
    if (length(setdiff(need_ko, names(ko))))
      .cc_stop("Gate-0", "keyorder_check_v2 缺列",
               paste(setdiff(need_ko, names(ko)), collapse = "、"))
    ## 判读契约（与 Gate-0 v2 §B 同文，不得两处不一致）
    if (ko$duplicate_K4_n[1L] != 0L)
      .cc_stop("Gate-0", "K4 亦有并列——属粒度／主体定义问题，非分页问题",
               sprintf("K4 并列 %s；须另启粒度调查，禁入 §C",
                       format(ko$duplicate_K4_n[1L], big.mark = ",")))
    if (ko$duplicate_K3_n[1L] != 0L)
      message(sprintf(
        "【R03b·Gate-0】K3 非全序（并列 %s），K4 唯一。\n  裁定：现行 ORDER BY 未覆盖 GROUP BY 全部区分键，存在分页边界不稳定风险；\n  ⛔ 不得称之为「R03b 有重复」。本器已改以 K4 四键为业务唯一键。",
        format(ko$duplicate_K3_n[1L], big.mark = ",")))

    cnt <- fread(P$count, encoding = "UTF-8")
    list(params = prm, keyorder = ko, count = cnt,
         db_row_count = as.numeric(cnt$db_row_count[1L]),
         gate = "Gate-0 PASS")
  })
}

# ---------------------------------------------------------------------
# Gate-1 · CC-02 边界完整性（先不跑任何分析）
# ---------------------------------------------------------------------
r03b_gate1 <- function(g0, P = R03B_PATHS) {
  .cc_stage("Gate-1 CC-02", {
    a <- fread(P$runA, encoding = "UTF-8")
    miss <- setdiff(R03B_KEY, names(a))
    if (length(miss)) .cc_stop("CC-02", "主档缺业务键列", paste(miss, collapse = "、"))

    n_csv <- nrow(a)
    n_db  <- g0$db_row_count
    if (!isTRUE(n_csv == n_db))
      .cc_stop("CC-02", "CSV 行数 ≠ DB 行数",
               sprintf("CSV %s ／ DB %s ／ 差 %s（%.4f%%）——依 §Z-20，此处 STOP，不得进入 CC-03",
                       format(n_csv, big.mark = ","), format(n_db, big.mark = ","),
                       format(n_csv - n_db, big.mark = ","), (n_csv - n_db) / n_db * 100))

    a[, .cc_key := do.call(paste, c(.SD, sep = "|")), .SDcols = R03B_KEY]
    n_key <- uniqueN(a$.cc_key)
    if (n_key != n_csv)
      .cc_stop("CC-02", "主档业务键不唯一",
               sprintf("行 %s ／ 唯一键 %s ／ 重复 %s",
                       format(n_csv, big.mark = ","), format(n_key, big.mark = ","),
                       format(n_csv - n_key, big.mark = ",")))

    cnt <- g0$count
    bd  <- data.table(
      项 = c("行数", "唯一业务键", "会员数", "荷官数", "日期数",
             "首行键", "末行键", "日期下界", "日期上界"),
      CSV侧 = c(format(n_csv, big.mark = ","), format(n_key, big.mark = ","),
                format(uniqueN(a$member_id), big.mark = ","),
                format(uniqueN(a$dealer_id), big.mark = ","),
                format(uniqueN(a$bet_date), big.mark = ","),
                a$.cc_key[1L], a$.cc_key[n_csv],
                as.character(min(a$bet_date)), as.character(max(a$bet_date))),
      DB侧 = c(format(n_db, big.mark = ","), format(as.numeric(cnt$db_distinct_key[1L]), big.mark = ","),
               format(as.numeric(cnt$db_member[1L]), big.mark = ","),
               format(as.numeric(cnt$db_dealer[1L]), big.mark = ","),
               format(as.numeric(cnt$db_date[1L]), big.mark = ","),
               "—", "—", as.character(cnt$date_min[1L]), as.character(cnt$date_max[1L])))
    bd[, 一致 := fifelse(DB侧 == "—", "—", fifelse(CSV侧 == DB侧, "✅", "❌"))]
    if (any(bd$一致 == "❌"))
      .cc_stop("CC-02", "边界项与 DB 不一致",
               paste(bd[一致 == "❌", 项], collapse = "、"))

    list(runA = a, boundary = bd, n_csv = n_csv, gate = "Gate-1 CC-02 PASS")
  })
}

# ---------------------------------------------------------------------
# Gate-2 · CC-03 分页／游标稳定性（本轮最重之一刀）
# ---------------------------------------------------------------------
r03b_gate2 <- function(g1, P = R03B_PATHS) {
  .cc_stage("Gate-2 CC-03", {
    a <- g1$runA
    b <- fread(P$runB, encoding = "UTF-8")
    b[, .cc_key := do.call(paste, c(.SD, sep = "|")), .SDcols = R03B_KEY]

    ## ① 行数一致
    if (nrow(a) != nrow(b))
      .cc_stop("CC-03", "两次导出行数不一致",
               sprintf("Run A %s ／ Run B %s", format(nrow(a), big.mark = ","),
                       format(nrow(b), big.mark = ",")))
    ## ② 键集合一致（双向差集皆须为 0）
    ab <- length(setdiff(a$.cc_key, b$.cc_key))
    ba <- length(setdiff(b$.cc_key, a$.cc_key))
    if (ab != 0L || ba != 0L)
      .cc_stop("CC-03", "两次导出键集合不一致",
               sprintf("A\\B = %s ／ B\\A = %s", format(ab, big.mark = ","),
                       format(ba, big.mark = ",")))
    ## ③ 重复键
    dupA <- nrow(a) - uniqueN(a$.cc_key); dupB <- nrow(b) - uniqueN(b$.cc_key)
    if (dupA != 0L || dupB != 0L)
      .cc_stop("CC-03", "存在重复键",
               sprintf("Run A 重复 %s ／ Run B 重复 %s", dupA, dupB))
    ## ④ 顺序稳定：主档须按业务键单调不减
    ord <- a[, do.call(order, .SD), .SDcols = R03B_KEY]
    if (!identical(ord, seq_len(nrow(a))))
      .cc_stop("CC-03", "主档未按业务键有序落盘",
               "分页边界无从核验；须以显式 ORDER BY 重导")

    ## ⑤ 页边界：无重叠、无缺口
    mf <- fread(P$manifest, encoding = "UTF-8")
    setorder(mf, page_no)
    pg <- data.table(page_no = mf$page_no, start_key = mf$start_key,
                     end_key = mf$end_key, n_rows_expected = mf$n_rows_expected)
    pg[, 下页起键 := shift(start_key, type = "lead")]
    pg[, 边界 := fifelse(is.na(下页起键), "末页",
                  fifelse(end_key < 下页起键, "✅ 无重叠",
                   fifelse(end_key == 下页起键, "❌ 重叠(端点相同)", "❌ 逆序/重叠")))]
    if (any(grepl("❌", pg$边界)))
      .cc_stop("CC-03", "分页边界重叠或逆序",
               sprintf("首现于 page_no = %s", pg[grepl("❌", 边界), page_no][1L]))
    if (sum(as.numeric(mf$n_rows_expected)) != nrow(a))
      .cc_stop("CC-03", "分页清单合计 ≠ 主档行数",
               sprintf("清单合计 %s ／ 主档 %s",
                       format(sum(as.numeric(mf$n_rows_expected)), big.mark = ","),
                       format(nrow(a), big.mark = ",")))

    list(pages = pg, n_pages = nrow(mf), gate = "Gate-2 CC-03 PASS")
  })
}

# ---------------------------------------------------------------------
# Gate-3 · 边界证据重建（唯有 CC-02／CC-03 全过方可执行）
# ---------------------------------------------------------------------
r03b_gate3 <- function(g0, g1, g2) {
  .cc_stage("Gate-3", {
    a <- g1$runA; cnt <- g0$count
    cov <- data.table(
      维度 = c("行数", "会员覆盖", "荷官覆盖", "日期覆盖", "唯一业务键"),
      CSV = c(nrow(a), uniqueN(a$member_id), uniqueN(a$dealer_id),
              uniqueN(a$bet_date), uniqueN(a$.cc_key)),
      DB  = as.numeric(c(cnt$db_row_count[1L], cnt$db_member[1L], cnt$db_dealer[1L],
                         cnt$db_date[1L], cnt$db_distinct_key[1L])))
    cov[, 覆盖率 := sprintf("%.6f%%", CSV / DB * 100)]
    cov[, 重复率 := c(sprintf("%.6f%%", (nrow(a) - uniqueN(a$.cc_key)) / nrow(a) * 100),
                      "—", "—", "—", "—")]
    ## 历史观测仅作对照登记，不参与判定
    hist <- data.table(
      项 = c("历史观测·截断档行数", "历史观测·当时预期行数", "本轮 DB 现算行数"),
      值 = c("6,143,388", "18,139,550", format(nrow(a), big.mark = ",")),
      性质 = c("historical observation（不作期望值）",
               "historical observation（不作期望值）",
               "OBSERVED（本轮自成证据链）"))
    list(coverage = cov, historical = hist, gate = "Gate-3 PASS")
  })
}

# ---------------------------------------------------------------------
# 单入口
# ---------------------------------------------------------------------
r03b_verify_all <- function(P = R03B_PATHS) {
  g0 <- r03b_gate0(P)
  g1 <- r03b_gate1(g0, P)
  g2 <- r03b_gate2(g1, P)
  g3 <- r03b_gate3(g0, g1, g2)
  structure(list(gate0 = g0, gate1 = g1, gate2 = g2, gate3 = g3,
                 identity = rbindlist(lapply(unlist(P)[file.exists(unlist(P))],
                                             .cc_sixtuple)),
                 verified_at = Sys.time()),
            class = "r03b_cc")
}

r03b_report <- function(res) {
  cat(sprintf("R03b 重导核验 · 全 Gate 通过 · %s\n",
              format(res$verified_at, "%Y-%m-%d %H:%M:%S")))
  list(六元组 = res$identity, CC02边界 = res$gate1$boundary,
       CC03分页 = res$gate2$pages, Gate3覆盖 = res$gate3$coverage,
       历史对照 = res$gate3$historical)
}

print.r03b_cc <- function(x, ...) {
  cat("R03b CC 核验结果：Gate-0/1/2/3 全过\n")
  cat(sprintf("  主档行数 %s · 分页 %s 页\n",
              format(x$gate1$n_csv, big.mark = ","), x$gate2$n_pages))
  cat("  ⚠ T-02 荷官串谋之解封，尚须 §R03b 补全后另行裁定，本器只证导出完整性。\n")
  invisible(x)
}
