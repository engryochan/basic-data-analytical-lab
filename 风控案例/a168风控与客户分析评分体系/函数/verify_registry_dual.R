# =============================================================================
# verify_registry_dual.R  ——  registry 双档双跑校验器
# 版本 : 1.3.0        立册 : 2026-09-02        Owner : Ryo Eng
# 变更 : 1.3.0（N-7 · 2026-09-03）target 1.5.003 → 1.5.004、parent 1.5.002 → 1.5.003。
#        R01–R25、R04b、R24b 之判定逻辑与文字一字未改。
# 变更 : 1.2.0（N-3 · 2026-09-03）target 1.5.002 → 1.5.003、parent 1.5.001 → 1.5.002；新增 rule_id "R04b" 一条——
#        父版身份自洽闸：YAML registry.parent.version 须等于 VRD$parent_version（v1.5.002 之 parent 曾指祖父 v1.5.0，
#        R04 只检非空故未捕）。R01–R25 与 R24b 之判定逻辑与文字一字未改（只增不减）。裁定：Ryo Eng 2026-09-03。
# 变更 : 1.1.0（N-2A · 2026-09-03）target 1.5.001 → 1.5.002、parent 1.5.0 → 1.5.001；
#        父版路径改指 规范/ 根（前版所指 规范/_superseded/…v1.5.0 于盘上不存在，致 R04 前置对照落空）。
#        R01–R25 与 R24b 之判定逻辑与文字一字未改。
# 变更 : 1.0.1（N-1B）新增 .r24b_core() 与 rule_id "R24b" 一条 —— 负向保证【有效性】闸；
#        另附 test_r24b() 三态自测 fixture。R01–R25 判定逻辑与文字一字未改（只增不减）。
# 对象 : registry_risk_typology_v1.5.004.{yaml,csv}  （父版 v1.5.003 为对照锚）
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
  version        = "1.3.0",
  target_version = "1.5.004",
  parent_version = "1.5.003",
  yaml_path      = "规范/registry_risk_typology_v1.5.004.yaml",
  csv_path       = "规范/registry_risk_typology_v1.5.004.csv",
  parent_yaml    = "规范/registry_risk_typology_v1.5.003.yaml",
  parent_csv     = "规范/registry_risk_typology_v1.5.003.csv",
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
  ## R04b（1.2.0 新增 · Ryo Eng 2026-09-03 裁定）：父版身份自洽——R04 只检 md5 非空，v1.5.002 之 parent 指祖父 v1.5.0 而未捕
  .pv <- if (is.null(Y$registry$parent$version)) "(缺)" else as.character(Y$registry$parent$version)
  chk("R04b", "父版身份自洽：YAML registry.parent.version 须等于校验器 VRD$parent_version",
      if (identical(.pv, VRD$parent_version)) "PASS" else "FAIL",
      .pv, VRD$parent_version, "1 档",
      "祖父锚冒充父锚即血统断裂：md5 非空 ≠ 指向正确；本闸与 R03（自身版本）成对，父子两端皆须对上校验器常量")
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
verify_v1_5_001 <- function(Y, D) {
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
  .r24b_core(Y, D)                     # ← N-1B 新增：负向保证有效性闸（详见档末 .r24b_core）

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
  verify_v1_5_001(Y, D)
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

# =============================================================================
# .r24b_core —— 负向保证之【有效性】闸（N-1B · 2026-09-02 新增）
# -----------------------------------------------------------------------------
# 【与 R24 之分工】R24 检 negative_assurance_evidence 之【存在性】（有无该栏）；
#   本闸检其【有效性】（该 evidence 所声明之机检，其被检集合是否非空）。二者不可互替。
# 【立意】本档头部已立铁律「coverage_observed 一栏必填，防『零对象空跑得 PASS』」，
#   然该铁律从未施于禁令册自身。实测：P-16（禁以实现输赢符号定罚，S1，由 G-07／
#   PI02／X_combo 三条独立实证支撑）其唯一检出手段为
#   「criterion_family 栏机检：OUTCOME_BASED 者 admit_to_risk_decision 恒 FALSE」，
#   而全册 criterion_family 无一 OUTCOME_BASED（51 STRUCTURAL + 15 REFERENCE_ONLY）
#   ⇒ 被检集合为空 ⇒ 该机检恒真而无内容 ⇒ 全项目最重之禁令，执行机制形同虚设。
# 【三态】PASS：凡有绑定者 coverage 皆 > 0
#         FAIL：至少一条绑定之 coverage == 0（即 VACUOUS_ASSURANCE）
#         NOT_RUN：有禁令声明「机检」却无绑定，或绑定所指之栏不存在 —— 无从判定
#         ⛔ NOT_RUN 不得计入 PASS（承本档头部铁律）。
# 【禁退化保证】本函数只新增 rule_id "R24b" 一行，R01–R25 之判据、状态与文字一字未改；
#   总判 gate 由 report_verify() 依 (FAIL == 0 && NOT_RUN == 0) 现算，故本闸结果
#   无从被总表吞没——此即 参考稿 §三所要求之「独立结果／独立失败状态／纳入总验收」。
# 【待迁】.nab 绑定表系过渡物。应于 N-5 判据语义裁决后，迁入 YAML 之
#   prohibited_action_registry[].negative_assurance_binding{column,value}，届时删除本表。
#   在迁入前，新增禁令若声明「机检」而未在此登记，本闸一律判 NOT_RUN，不默认放行。
# =============================================================================
.r24b_core <- function(Y, D) {
  .nab <- list(
    list(id = "P-15", col = "window_scope",     val = "FULL_WINDOW"),
    list(id = "P-16", col = "criterion_family", val = "OUTCOME_BASED"),
    list(id = "P-18", col = "ranking",          val = "FALSE")
  )
  ## 形制注记：YAML 之 prohibited_action_registry 系 dict（note／iron_rule／
  ## inherited_from_global_prohibitions／prohibitions 四键），禁令本体在 $prohibitions。
  ## 若日后改为裸 list，下式亦兼容。此形制已于 2026-09-02 对真实双档实测确认。
  par0 <- Y$prohibited_action_registry %||% list()
  par  <- if (!is.null(par0$prohibitions)) par0$prohibitions else par0
  if (!length(par)) {
    chk("R24b", "负向保证之有效性（防 VACUOUS_ASSURANCE）", "NOT_RUN",
        "禁令册为空或未载入", "禁令册非空", "0 条",
        "无禁令可检；NOT_RUN 不得计入 PASS")
    return(invisible(NULL))
  }
  ids  <- vapply(par, function(p) p$id %||% NA_character_, character(1))
  decl <- vapply(par, function(p) grepl("机检", p$negative_assurance_evidence %||% ""), logical(1))
  bnd  <- vapply(.nab, function(b) b$id, character(1))
  cols <- vapply(.nab, function(b) b$col, character(1))
  vals <- vapply(.nab, function(b) b$val, character(1))
  cov  <- vapply(seq_along(.nab), function(i) {
    if (!cols[i] %in% names(D)) return(NA_integer_)
    as.integer(sum(trimws(as.character(D[[cols[i]]])) == vals[i], na.rm = TRUE))
  }, integer(1))
  unbound    <- setdiff(ids[decl], bnd)      # 声明机检却未绑定
  vacuous    <- bnd[!is.na(cov) & cov == 0L] # 绑定成立但被检集合为空
  unresolved <- bnd[is.na(cov)]              # 绑定所指之栏不存在
  status <- if (length(unbound) || length(unresolved)) "NOT_RUN" else
            if (length(vacuous))                        "FAIL"    else "PASS"
  chk("R24b",
      "负向保证之有效性：声明机检者其被检集合须非空（防 VACUOUS_ASSURANCE）",
      status,
      sprintf("%s ｜ VACUOUS %d：%s ｜ 未绑定 %d：%s ｜ 栏缺 %d：%s",
              paste(sprintf("%s[%s=%s]cov=%s", bnd, cols, vals,
                            ifelse(is.na(cov), "列不存在", cov)), collapse = " · "),
              length(vacuous),    paste(vacuous,    collapse = ","),
              length(unbound),    paste(unbound,    collapse = ","),
              length(unresolved), paste(unresolved, collapse = ",")),
      "每条声明机检之禁令，其被检集合皆 > 0",
      sprintf("已绑定 %d 条 ／ 声明机检 %d 条 ／ 禁令总 %d 条",
              length(.nab), sum(decl), length(par)),
      "R24 检存在性，R24b 检有效性；禁令若只检空集，等于没有禁令")
  invisible(NULL)
}

# =============================================================================
# test_r24b —— R24b 三态自测 fixture（N-1B · 不入主流程，须单独调用）
# 用法：test_r24b()   回 TRUE 表示三态皆可复现，否则 stop()
# 立意：承 参考稿 §三——R24b 不得因自身实现错误而只见 PASS 一态。
#   本 fixture 以合成资料分别触发 FAIL／PASS／NOT_RUN，证明三态皆真可达。
# =============================================================================
test_r24b <- function() {
  mk <- function(fam_vals, extra = NULL) {
    D <- data.table(window_scope     = rep("FULL_WINDOW", length(fam_vals)),
                    criterion_family = fam_vals,
                    ranking          = rep("FALSE", length(fam_vals)))
    Y <- list(prohibited_action_registry = c(
      list(list(id = "P-15", negative_assurance_evidence = "window_scope 栏机检"),
           list(id = "P-16", negative_assurance_evidence = "criterion_family 栏机检"),
           list(id = "P-18", negative_assurance_evidence = "ranking 四栏机检")), extra))
    list(Y = Y, D = D)
  }
  keep <- .RES$rows; on.exit(.RES$rows <- keep, add = TRUE)
  .RES$rows <- list()
  f1 <- mk(c("STRUCTURAL", "REFERENCE_ONLY"))                        # ① 期 FAIL
  .r24b_core(f1$Y, f1$D)
  f2 <- mk(c("STRUCTURAL", "OUTCOME_BASED"))                         # ② 期 PASS
  .r24b_core(f2$Y, f2$D)
  f3 <- mk(c("STRUCTURAL", "OUTCOME_BASED"),                         # ③ 期 NOT_RUN
           list(list(id = "P-99", negative_assurance_evidence = "某新栏 栏机检")))
  .r24b_core(f3$Y, f3$D)
  got <- vapply(.RES$rows, function(r) r$status, character(1))
  exp <- c("FAIL", "PASS", "NOT_RUN")
  if (!identical(unname(got), exp))
    stop(sprintf("R24b 三态自测不符：期望 %s，实得 %s",
                 paste(exp, collapse = "/"), paste(got, collapse = "/")), call. = FALSE)
  cat("✓ R24b 三态自测通过：FAIL ／ PASS ／ NOT_RUN 皆可复现\n")
  invisible(TRUE)
}
