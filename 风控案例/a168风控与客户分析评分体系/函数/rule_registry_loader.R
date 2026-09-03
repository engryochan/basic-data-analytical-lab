# =====================================================================
# rule_registry_loader.R · 规则册载入器与对 v1.5.0 之一致性门闸
# ---------------------------------------------------------------------
# 版本 : 0.1.2        日期 : 2026-09-03        适配 : typology 1.5.002 / rules 0.1.1
# 变更 : N-2A —— 版本串 1.5.001 → 1.5.002；RULES_PATH 改指 rule_registry_v0.1.1.yaml
#        （该册仅 registry 头块 parent/version 递增，规则本体一字未改）。闸门 G1~G6 逻辑未动。
# 变更 : N-1A —— 四处版本串 1.5.0 → 1.5.001（L21~L24 区），闸门 G1~G4 逻辑一字未改。
# ---------------------------------------------------------------------
# 【门闸】任一不合即 stop()：
#   G1 rule.type_id 须在 v1.5.0（或显式 null 并标 NOT_DEFINED）
#   G2 rule.criterion_column 须在该 type 之判据列，或 null 且 threshold_status ∈ {NOT_DEFINED}
#   G3 指向 T-03 之 RULE/ACTION 层规则，threshold_status 必为 REJECTED_BY_REGISTRY（四禁令）
#   G4 指向 v1.5.0 BLOCKED 判据者，threshold_status 必为 REJECTED_BY_REGISTRY
#   G5 threshold_status == PROPOSED_BUSINESS 者 evidence_level ≤ E2（业务数字不得自升 E3+）
#   G6 SIGNAL/RULE/EVIDENCE 层每条须有 sample_gate（ACTION 层免）
# =====================================================================
suppressPackageStartupMessages({ library(data.table); library(yaml) })

RULES_PATH <- file.path("规范", "rule_registry_v0.1.1.yaml")
RISKEYE_PATH <- file.path("规范", "risk_eye_schema_v0.1.0.yaml")

rules_load <- function(REG, path = RULES_PATH) {
  y <- yaml::read_yaml(path)
  if (!identical(y$registry$parent, "registry_risk_typology_v1.5.002"))
    stop("规则册 parent 非 v1.5.002", call. = FALSE)
  if (!identical(as.character(REG$meta$registry$version), "1.5.002"))
    stop("载入之登记册非 v1.5.002", call. = FALSE)
  `%||%` <- function(a, b) if (is.null(a)) b else a
  rt <- rbindlist(lapply(y$rules, function(r) data.table(
    rule_id = r$rule_id, layer = r$layer, label_zh = r$label_zh,
    type_id = r$type_id %||% NA_character_, criterion_column = r$criterion_column %||% NA_character_,
    window = as.character(r$observation_window %||% NA), sample_gate = as.character(r$sample_gate %||% NA),
    threshold = paste(unlist(r$threshold %||% NA), collapse = "/"),
    threshold_status = r$threshold_status, evidence_level = r$evidence_level,
    trigger_source = paste(unlist(r$trigger_source), collapse = "|"),
    source_item = r$source_item, mapping_note = r$mapping_note %||% "")), fill = TRUE)

  dict <- REG$dict
  for (i in seq_len(nrow(rt))) {
    r <- rt[i]
    # G1
    if (!is.na(r$type_id) && !r$type_id %in% dict$type_id)
      stop(sprintf("[G1] %s 指向不存在之类型 %s", r$rule_id, r$type_id), call. = FALSE)
    if (is.na(r$type_id) && r$threshold_status != "NOT_DEFINED")
      stop(sprintf("[G1] %s 无 type_id 却非 NOT_DEFINED", r$rule_id), call. = FALSE)
    # G2
    if (!is.na(r$criterion_column)) {
      cols <- dict[type_id == r$type_id, criterion_column]
      if (!r$criterion_column %in% cols)
        stop(sprintf("[G2] %s：%s 非 %s 之判据列（合法：%s）", r$rule_id, r$criterion_column, r$type_id,
                     paste(cols, collapse = ",")), call. = FALSE)
      crow <- dict[type_id == r$type_id & criterion_column == r$criterion_column][1L]
      # G4
      if (crow$threshold_status == "BLOCKED" && r$threshold_status != "REJECTED_BY_REGISTRY")
        stop(sprintf("[G4] %s 指向 BLOCKED 判据 %s，须标 REJECTED_BY_REGISTRY", r$rule_id, r$criterion_column), call. = FALSE)
    } else if (!r$threshold_status %in% c("NOT_DEFINED"))
      stop(sprintf("[G2] %s 无判据列却非 NOT_DEFINED", r$rule_id), call. = FALSE)
    # G3
    if (!is.na(r$type_id) && r$layer %in% c("RULE", "ACTION")) {
      sc <- registry_type_scalars(REG, r$type_id)
      if (isTRUE(sc$trigger == "FALSE" || identical(sc$trigger, FALSE)) && r$threshold_status != "REJECTED_BY_REGISTRY")
        stop(sprintf("[G3] %s 指向 trigger=FALSE 之类型 %s（四禁令），须标 REJECTED_BY_REGISTRY", r$rule_id, r$type_id), call. = FALSE)
    }
    # G5
    if (r$threshold_status == "PROPOSED_BUSINESS" && r$evidence_level %in% c("E3", "E4"))
      stop(sprintf("[G5] %s 业务阈值不得自升 %s", r$rule_id, r$evidence_level), call. = FALSE)
    # G6
    if (r$layer != "ACTION" && (is.na(r$sample_gate) || !nzchar(r$sample_gate)))
      stop(sprintf("[G6] %s 缺 sample_gate", r$rule_id), call. = FALSE)
  }
  structure(list(rules = rt, meta = y, loaded_at = Sys.time()), class = "a168_rules")
}

rules_summary <- function(RL) {
  RL$rules[, .(条数 = .N), by = .(layer, threshold_status)][order(layer, threshold_status)]
}

riskeye_load <- function(path = RISKEYE_PATH) yaml::read_yaml(path)
