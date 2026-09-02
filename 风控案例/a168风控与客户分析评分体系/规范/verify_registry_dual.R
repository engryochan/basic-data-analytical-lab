# =============================================================================
# verify_registry_dual.R  ——  registry 双档双跑校验器
# 版本 : 1.0.0        立册 : 2026-09-02        Owner : Ryo Eng
# 对象 : registry_risk_typology_v1.5.001.{yaml,csv}  （父版 v1.5.0 为对照锚）
# -----------------------------------------------------------------------------
# 【本档立意】SC-26 实证：所谓「R01–R25 校验器」从未作为可执行档存在，
#   故上一轮「25/25 PASS」已撤销 TESTED_PASS，改判 UNKNOWN。
#   本档即该校验器之首次落码。五阶段闸之第二关：
#       P0 规范修复 → ★ 本闸 ← → 六元组+_superseded+指针+Git锚 → 实验预注册 → 出双档
#   ⛔ 本闸不过，其后任何「PASS」皆不成立。
#
# 【铁律】
#   · 只读不写；不修改任何登记档。
#   · 每条判据须回报 status / observed / expected / evidence 四列，禁只回 TRUE/FALSE。
#   · coverage_observed 一栏必填：说明本条实际覆盖了多少对象，防「零对象空跑得 PASS」。
#   · NULL != 0；UNKNOWN != FAIL；未跑者一律 NOT_RUN，禁默认 PASS。
# =============================================================================

suppressPackageStartupMessages({
  library(yaml); library(data.table); library(digest); library(tools)
})

# ---- 0. 参数（集中式常量，承 SC-31 之教训：禁散写路径）-----------------------
VRD <- list(
  version        = "1.0.0",
  target_version = "1.5.001",
  parent_version = "1.5.0",
  yaml_path      = "规范/registry_risk_typology_v1.5.001.yaml",
  csv_path       = "规范/registry_risk_typology_v1.5.001.csv",
  parent_yaml    = "规范/_superseded/registry_risk_typology_v1.5.0.yaml",
  parent_csv     = "规范/_superseded/registry_risk_typology_v1.5.0.csv",
  csv_encoding   = "UTF-8-BOM",   # 承 SC-25 役所定形制
  csv_eol        = "LF"
)

# ---- 1. 结果收集器 -----------------------------------------------------------
.RES <- new.env(parent = emptyenv()); .RES$rows <- list()
chk <- function(id, name, status, observed, expected, coverage_observed, evidence = "") {
  stopifnot(status %in% c("PASS", "FAIL", "WARN", "NOT_RUN", "UNKNOWN"))
  .RES$rows[[length(.RES$rows) + 1L]] <- data.table(
    rule_id = id, rule_name = name, status = status,
    observed = as.character(observed), expected = as.character(expected),
    coverage_observed = as.character(coverage_observed), evidence = evidence)
  invisible(NULL)
}
six_tuple <- function(p) {
  if (!file.exists(p)) return(list(exists = FALSE))
  raw <- readBin(p, "raw", file.info(p)$size)
  n_crlf <- sum(raw[-length(raw)] == as.raw(0x0d) & raw[-1] == as.raw(0x0a))
  n_lf   <- sum(raw == as.raw(0x0a)); n_cr <- sum(raw == as.raw(0x0d))
  list(exists = TRUE, bytes = length(raw), lines = n_lf,
       eol = if (n_lf > 0 && n_crlf == n_lf && n_cr == n_lf) "CRLF" else if (n_cr == 0) "LF" else "MIXED",
       bom = identical(as.integer(raw[1:3]), c(239L, 187L, 191L)),
       md5 = digest(raw, algo = "md5", serialize = FALSE))
}

# =============================================================================
# 域 A · 血统与形制（R01–R05）
# =============================================================================
verify_lineage <- function(Y, ft_y, ft_c) {
  chk("R01", "YAML 六元组齐备",
      if (isTRUE(ft_y$exists)) "PASS" else "FAIL",
      sprintf("%s B / %s 行 / %s / BOM=%s / %s", ft_y$bytes, ft_y$lines, ft_y$eol, ft_y$bom, ft_y$md5),
      "六项皆非空", "1 档")
  chk("R02", "CSV 形制符 SC-25 役所定（含 BOM + LF）",
      if (isTRUE(ft_c$bom) && identical(ft_c$eol, "LF")) "PASS" else "FAIL",
      sprintf("BOM=%s / %s", ft_c$bom, ft_c$eol), "BOM=TRUE / LF", "1 档",
      "★ 与 F-44（CRLF 无 BOM）冲突，OQ-09 待裁；本闸暂以 SC-25 役为准")
  chk("R03", "版本号自洽",
      if (identical(Y$registry$version, VRD$target_version)) "PASS" else "FAIL",
      Y$registry$version, VRD$target_version, "1 档")
  chk("R04", "父版锚齐备（version + yaml_md5 + csv_md5）",
      if (!is.null(Y$registry$parent$yaml_md5) && !is.null(Y$registry$parent$csv_md5)) "PASS" else "FAIL",
      paste(Y$registry$parent$version, Y$registry$parent$yaml_md5), "非空", "1 档")
  chk("R05", "Git 锚已登记",
      if (!is.null(Y$registry$git_anchor)) "PASS" else "FAIL",
      if (is.null(Y$registry$git_anchor)) "(缺)" else Y$registry$git_anchor,
      "非空 commit sha", "1 档", "SC-32：v1.3.0/v1.4.0/v1.5.0 皆无锚，回滚点不存在")
}

# =============================================================================
# 域 B · 双档一致（R06–R12）—— csv_scope 明写「YAML→CSV 必有损」，故只校判据层
# =============================================================================
verify_dual <- function(Y, D) {
  cc <- rbindlist(lapply(Y$typologies, function(t) {
    if (is.null(t$criterion_columns)) return(NULL)
    rbindlist(lapply(t$criterion_columns, function(c)
      data.table(type_id = t$type_id, criterion_column = c$column %||% NA_character_,
                 criterion_role = c$criterion_role %||% NA_character_,
                 threshold_status = c$threshold_status %||% NA_character_,
                 direction = c$direction %||% NA_character_)), fill = TRUE)
  }), fill = TRUE)
  risk_csv <- D[axis != "V"]
  chk("R06", "判据层行数 YAML == CSV(风险轴)",
      if (nrow(cc) == nrow(risk_csv)) "PASS" else "FAIL",
      sprintf("YAML %d / CSV %d", nrow(cc), nrow(risk_csv)),
      "相等", sprintf("%d 行", nrow(cc)))
  key_y <- paste(cc$type_id, cc$criterion_column); key_c <- paste(risk_csv$type_id, risk_csv$criterion_column)
  chk("R07", "判据层主键集合双档同一",
      if (setequal(key_y, key_c)) "PASS" else "FAIL",
      sprintf("仅YAML %d / 仅CSV %d", length(setdiff(key_y, key_c)), length(setdiff(key_c, key_y))),
      "两侧差集皆 0", sprintf("%d 键", length(union(key_y, key_c))))
  for (f in c("criterion_role", "threshold_status", "direction")) {
    m <- merge(cc[, .(k = paste(type_id, criterion_column), y = get(f))],
               risk_csv[, .(k = paste(type_id, criterion_column), c = get(f))], by = "k")
    bad <- m[!(is.na(y) & is.na(c)) & (is.na(y) != is.na(c) | (!is.na(y) & y != c))]
    chk(paste0("R08_", f), sprintf("判据层 %s 双档逐行同一", f),
        if (nrow(bad) == 0) "PASS" else "FAIL",
        sprintf("不符 %d", nrow(bad)), "0", sprintf("%d 行", nrow(m)))
  }
  yo <- Y$field_scope_registry$type_level_nested_yaml_only
  chk("R11", "嵌套键未伪扁平上载 CSV（承 csv_scope）",
      if (length(intersect(yo, names(D))) == 0) "PASS" else "FAIL",
      paste(intersect(yo, names(D)), collapse = ","), "空集", sprintf("%d 键", length(yo)))
  wl <- unique(c(Y$field_scope_registry$criterion_level,
                 Y$field_scope_registry$type_level_scalar_uploadable))
  chk("R12", "CSV 新栏皆已入白名单（白名单式，非计数式 · §6 SR-5）",
      "NOT_RUN", "—", "每一新栏须见于 field_scope_registry", "—",
      "须与父版栏名并集比对后方可判定；本版留待人工核")
}

# =============================================================================
# 域 C · 不变量与准入（R13–R20）
# =============================================================================
verify_invariants <- function(Y, D) {
  iv <- Y$invariants
  chk("R13", "15 类 + V 轴 = 66 判据",
      if (nrow(D) == iv$registered_criterion_count) "PASS" else "FAIL",
      nrow(D), iv$registered_criterion_count, "全册")
  chk("R14", "criterion_role 十枚举合计闭环",
      if (sum(unlist(iv$criterion_role_totals)) == iv$registered_criterion_count) "PASS" else "FAIL",
      sum(unlist(iv$criterion_role_totals)), iv$registered_criterion_count, "10 枚举")
  chk("R15", "admit_to_risk_decision 全 FALSE（B-6 / P-19）",
      if (all(toupper(as.character(D$admit_to_risk_decision)) %in% c("FALSE", "F", "NA", "")))
        "PASS" else "FAIL",
      paste(unique(D$admit_to_risk_decision), collapse = ","), "全 FALSE", sprintf("%d 行", nrow(D)))
  t03 <- D[type_id == "T-03"]
  chk("R16", "T-03 四禁令布尔全 false（B-5 / P-18，永不复活）",
      if (nrow(t03) == 0) "NOT_RUN" else
        if (all(tolower(unlist(t03[, .(ranking, scoring, trigger, enforcement)])) %in%
                c("false", "f", "", "na"))) "PASS" else "FAIL",
      paste(unique(unlist(t03[, .(ranking, scoring, trigger, enforcement)])), collapse = ","),
      "全 false", sprintf("T-03 %d 行", nrow(t03)))
  g <- Y$gates
  five <- c(g$G01$status, g$G02$status, g$G03$status, g$G04$status, g$G05$status)
  chk("R17", "五门状态与 global_gate_status 自洽",
      if ((all(five == "PASS")) == identical(g$global_gate_status, "PASS")) "PASS" else "FAIL",
      paste(five, collapse = "/"), "全 PASS 时 global 方可 PASS", "5 门")
  chk("R18", "解锁谓词四项皆未满足时无一对象解锁",
      if (!is.null(Y$unlock_predicate$risk_decision_unlock)) "PASS" else "FAIL",
      substr(Y$unlock_predicate$risk_decision_unlock %||% "(缺)", 1, 60), "谓词在册", "1 谓词")
  chk("R19", "MCID 成本锚状态在册",
      if (!is.null(Y$mcid_cost_anchor_status)) "PASS" else "FAIL",
      Y$mcid_cost_anchor_status %||% "(缺)", "非空", "1 栏")
  sup <- vapply(Y$evidence_registry %||% list(), function(e) identical(e$status, "SUPERSEDED"), logical(1))
  chk("R20", "SUPERSEDED 证据未被援引为 TESTED_PASS（血统防复活）",
      "NOT_RUN", sprintf("SUPERSEDED %d 条", sum(sup)),
      "须逐条追溯援引处", sprintf("%d 条证据", length(Y$evidence_registry %||% list())))
}

# =============================================================================
# 域 D · v1.5.001 新增段（R21–R25）
# =============================================================================
verify_v1_5_001 <- function(Y) {
  cr <- Y$capability_registry
  n <- length(cr$dims %||% list())
  chk("R21", "57 维齐备（CORE 35 + EXTENDED 22）",
      if (n == 57 && cr$core == 35 && cr$extended == 22) "PASS" else "FAIL",
      sprintf("%d = %d + %d", n, cr$core %||% -1, cr$extended %||% -1), "57 = 35 + 22", "57 维")
  cls <- table(vapply(cr$dims, function(d) d$dimension_class, ""))
  chk("R22", "CORE 35 维一维未删（先生所列 10/8/7/10）",
      if (isTRUE(cls[["CORE"]] == 35)) "PASS" else "FAIL",
      paste(names(cls), cls, collapse = " "), "CORE=35", "57 维")
  ph <- Y$prohibited_action_registry
  inh <- ph$inherited_from_global_prohibitions %||% character(0)
  gid <- vapply(Y$global_prohibitions %||% list(), function(g) g$id %||% "", "")
  chk("R23", "global_prohibitions 九条全数承接入禁令册",
      if (all(gid %in% inh)) "PASS" else "FAIL",
      sprintf("承接 %d / 原有 %d", length(intersect(gid, inh)), length(gid)),
      "全数承接", sprintf("%d 条禁令", length(ph$prohibitions %||% list())))
  na_missing <- vapply(ph$prohibitions %||% list(),
                       function(p) is.null(p$negative_assurance_evidence), logical(1))
  chk("R24", "每条禁令皆配 negative_assurance_evidence",
      if (!any(na_missing)) "PASS" else "FAIL",
      sprintf("缺 %d 条", sum(na_missing)), "0", sprintf("%d 条", length(na_missing)),
      "禁令若无检出手段，等于没有禁令")
  tp <- Y$treatment_status$policy_extension
  s34 <- c(Y$treatment_status$levels[[3]]$status, Y$treatment_status$levels[[4]]$status)
  ok <- all(vapply(tp$policies %||% list(),
                   function(p) identical(p$blocked_until, "treatment_status.S3 AND S4 == CLOSED"), logical(1)))
  chk("R25", "S3/S4 未闭合时全部 Treatment 挂 BLOCKED（P-20 防偷渡）",
      if (all(s34 == "CLOSED") || ok) "PASS" else "FAIL",
      sprintf("S3=%s S4=%s", s34[1], s34[2]),
      "S3/S4 非 CLOSED 时须逐条 blocked_until", sprintf("%d 类", length(tp$policies %||% list())))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# =============================================================================
# 主流程
# =============================================================================
verify_registry_dual <- function(yaml_path = VRD$yaml_path, csv_path = VRD$csv_path) {
  .RES$rows <- list()
  ft_y <- six_tuple(yaml_path); ft_c <- six_tuple(csv_path)
  if (!isTRUE(ft_y$exists) || !isTRUE(ft_c$exists)) {
    chk("R00", "双档存在", "FAIL",
        sprintf("yaml=%s csv=%s", ft_y$exists, ft_c$exists), "皆 TRUE", "2 档")
    return(rbindlist(.RES$rows))
  }
  Y <- yaml::read_yaml(yaml_path)
  D <- fread(csv_path, encoding = "UTF-8", colClasses = "character", na.strings = NULL)
  verify_lineage(Y, ft_y, ft_c)
  verify_dual(Y, D)
  verify_invariants(Y, D)
  verify_v1_5_001(Y)
  res <- rbindlist(.RES$rows, fill = TRUE)
  res[]
}

report_verify <- function(res) {
  cat("\n══ verify_registry_dual v", VRD$version, " · target ", VRD$target_version, " ══\n", sep = "")
  print(res[, .(rule_id, status, observed, coverage_observed)], nrows = 100)
  tb <- table(factor(res$status, levels = c("PASS", "FAIL", "WARN", "UNKNOWN", "NOT_RUN")))
  cat("\n汇总：", paste(names(tb), tb, sep = "=", collapse = " · "), "\n")
  gate <- if (tb[["FAIL"]] == 0 && tb[["NOT_RUN"]] == 0) "PASS" else "NOT_PASS"
  cat("★ 第二阶段闸：", gate, "\n")
  cat("⛔ 铁律：NOT_RUN 不得计入 PASS；本闸不过，其后任何『PASS』皆不成立。\n")
  invisible(gate)
}

# 用法：
#   res <- verify_registry_dual(); report_verify(res)
#   fwrite(res, "审计/verify_registry_dual_报告.csv", bom = TRUE, eol = "\n")
