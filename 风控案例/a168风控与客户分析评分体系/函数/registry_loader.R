# =====================================================================
# registry_loader.R · a168 风险类型登记册载入器与门闸
# ---------------------------------------------------------------------
# 载入器版本 : 1.5.002      适配登记册 : 1.5.002      日期 : 2026-09-03
# 变更     : N-2A（2026-09-03）——三处实质改动：
#            ① 路径指向 v1.5.002 双档（CSV 与 v1.5.001 逐字节相同 md5 deedd982…；
#               YAML 系加法升级：父版仅第 3/18 行版本号改、第 4 行新增 git_anchor，
#               余 3,940 行逐位存续，另追加十节；红队四支 + 完整性批评已过）；
#            ② .expect 递增 1.5.001 → 1.5.002；
#            ③ db_dir 由「数据库」改「数据表」——承 commit 7f713dc 之目录改名，
#               原名致 P-01 禁读档存在性检查与引擎交付件路径落空（T-01 金丝雀十件「待表」之根因）。
# 变更     : N-1A（2026-09-02）——仅三处实质改动：
#            ① 路径 L105/L106 指向 v1.5.001 双档；② .expect 递增 1.5.0 → 1.5.001；③ 本头注记。
#            登记册 40→56 栏系加法；R01 之 need 为白名单式缺列检查，不受新增栏影响。
#            R03 类型集合／gate／admit_to_scoring／判据列集合，及 registry_counts
#            七项计数，合计十四条断言已于 patch 前逐条机器预演，全数通过。
#            身份名 1.5.001 为唯一权威（承 SC-29：盘上唯点号）；YAML 另立
#            version_semver=1.5.1 仅供 SemVer 工具链解析，本载入器不取用。
# 配套     : 规范/registry_risk_typology_v1.5.002.yaml（单一真相源，UTF-8 无 BOM/LF）
#            规范/registry_risk_typology_v1.5.002.csv （派生字典，UTF-8-BOM/LF）
# 变更     : 1.5.0 适配登记册 1.5.0（G-1 三向变换之产物）——
#            ① 路径常量改指 规范/（五命名空间归化；数据库/ 只放交付件 CSV）；
#            ② .expect 递增至 1.5.0；
#            ③ 判据层新增 criterion_role／threshold_note 两列，registry_typology()
#               之判据维度表随之扩列；direction 仅 STAT_DIRECTIONAL 有值；
#            ④ 新增 registry_counts(REG)：读 YAML registry_counts 段并与 CSV 现算
#               互证，不符即 stop（禁止任何 qmd 硬写 15／65／66／42）；
#            ⑤ 新增 registry_type_scalars(REG, type_id)：取 T-03 四禁令／T-10 内控四键
#               等上载标量（v1.5.0 起双档可见）。
#            1.4.1 审计斧正两项（本档注释层，逻辑一字未动）——
#            ① L1 绝对路径去写死：原 path 常量硬编码单机盘符，换机／换用户／CI
#               即断，且与「工作目录 = qmd 所在目录」设计自相矛盾；改为相对路径
#               优先、绝对路径仅作兜底（REGISTRY_ROOT，缺省 ""）。
#            ② L2 注释与代码不符：头部布局树与配套栏仍书 v1.1.0，而常量与
#               .expect 已是 v1.3.0；且 1.3.0／1.4.0 两版无任何变更记载。
#               本次补记如下，并将布局树内版本号改为占位符，杜绝再度分家。
#            1.4.0 适配登记册 1.3.0：判据维度扩至 66 条、阻断项 11 项、
#            待建特征 4 条、治理悬案 4 项；.expect 同步递增至 1.3.0；
#            sql_main 改指 SQL 总包 v10（★ 该件落地前，R00b 软核验将持续告警，
#            登记册 sql_section 栏所指章节暂不可回溯，证据链处「不可溯源」降级态）。
#            1.3.0 登记册内容版本（数据件侧递增，本档随之适配）。
#            1.2.0 补齐四个缺失函数——registry_typology()（单类完整配方）、
#            registry_combo()（跨类搭配，交集／并集）、registry_which()（列反查类型）、
#            registry_count_deliverables()（自 SQL 总包现算唯一交付件数，
#            杜绝把该数写死于任何 qmd——总包自述 69 已实测为旧数，真值 74）。
#            1.1.1 落定项目目录布局（本档移入 函数/），registry_load() 改带
#            默认路径，缺档报错回显完整布局树；新增 SQL 总包在位软核验。
#            1.1.0 登记册由 10 类扩至 15 类（新增 T-11 多账户共享设备／
#            T-12 机器人脚本／T-13 夜间异常／T-14 限红试探／T-15 静默复活），
#            阻断项由 5 项扩至 10 项；候选桶清空；修正 admitted_columns 参数遮蔽。
# ---------------------------------------------------------------------
# 【项目目录布局】（工作目录 = qmd 所在目录）
#
#   工作目录/
#   ├─ a168风控某报告.qmd                        ← 报告（本档服务对象）
#   ├─ a168风控与客户分层评分体系_商业方案.qmd      ← 权威主件之一
#   ├─ a168风控评分_精要商业报告.qmd               ← 权威主件之二
#   ├─ 函数/
#   │  ├─ registry_loader.R                     ← 本档
#   │  └─ a168_取数与核验_SQL总包_v<当前版>.sql    ← 权威主件之三（版本以 REGISTRY_PATHS 为准）
#   └─ 数据库/
#      ├─ registry_risk_typology_v<当前版>.yaml   ← 版本以 REGISTRY_PATHS 为准
#      ├─ registry_risk_typology_v<当前版>.csv    ← 切忌在此另写版本号（必分家）
#      ├─ R01_late_shoe.csv
#      └─ S05_member_month_panel.csv
# 身份     : 数据资产（配置件），从属于 SQL 总包与商业方案；
#            ★ 不构成第四份权威文件（三文件铁律）
# ---------------------------------------------------------------------
# 【在 qmd 中如何用】数据入口块内：
#
#   source("函数/registry_loader.R")
#   REG <- registry_load()          # 默认路径已按上述布局设定，通常无须传参
#   registry_gate(REG, used = c("opposite_rate", "hedge_rate", "stake_all"))
#   # ↑ 若其中任一列不属 admit_to_scoring=TRUE 之类型，渲染即 stop()
#
#   knitr::kable(registry_table(REG))          # 登记册总表
#   knitr::kable(registry_matrix(REG))         # V×R 评分矩阵
#   cols <- registry_admitted_columns(REG)     # 取回准入特征列名
#
#   registry_typology(REG, "T-04")             # 单类完整配方（主表＋搭配＋判据＋解锁条件）
#   registry_combo(REG, c("T-04","T-05","T-08"), mode = "admitted")   # 跨类搭配
#   registry_which(REG, "late_share")          # 列反查：属哪类、可否入算
#   registry_count_deliverables()              # 自 SQL 总包现算唯一交付件数
#
# 【设计要点】
#   ① YAML 为真相源，CSV 为派生件；载入即交叉比对，不一致立即 stop()——
#      杜绝「两份文件各说各话」这一本项目已两次实证的漂移模式。
#   ② 门闸是反向的：不是「提醒你该用什么」，而是「用了不该用的就渲染不出来」。
#   ③ 全函数以 .rstage() 包裹，报错自带坐标，便于渲染失败自定位。
#   ④ 无网络依赖；yaml 包缺失时降级为纯 CSV 模式并显式告警。
# =====================================================================

suppressPackageStartupMessages({
  library(data.table)
})
## ---------------------------------------------------------------------
## 【路径根】（1.4.1 斧正 L1）
## 缺省为空串 ""，即一切路径相对于 getwd()（＝qmd 所在目录），换机可移植。
## 仅当工作目录不便切换时，才在**外部**以 options() 指定绝对根，例如：
##   options(registry.root = "C:/.../a168风控与客户分析评分体系/")
## 本档不写死任何单机盘符——写死即令 getwd() 报错回显失去指向意义。
## ---------------------------------------------------------------------
REGISTRY_ROOT <- getOption("registry.root", "")
.rp <- function(...) {
  p <- file.path(...)
  if (nzchar(REGISTRY_ROOT)) file.path(REGISTRY_ROOT, p) else p
}

.rstage <- function(tag, expr) tryCatch(expr, error = function(e)
  stop(sprintf("【registry·%s】%s", tag, conditionMessage(e)), call. = FALSE))

## ---------------------------------------------------------------------
## 项目目录常量（工作目录 = qmd 所在目录；改布局只须改此处）
## ---------------------------------------------------------------------
REGISTRY_PATHS <- list(
  fn_dir   = .rp("函数"),
  db_dir   = .rp("数据表"),
  spec_dir = .rp("规范"),
  yaml     = .rp("规范", "registry_risk_typology_v1.5.002.yaml"),
  csv      = .rp("规范", "registry_risk_typology_v1.5.002.csv"),
  sql_main = .rp("a168_取数与核验_SQL总包_v10.sql")   # 08acdbc5 起驻项目根（冻结件）
)

.layout_tree <- function() paste(
  "  工作目录/",
  "  ├─ <本报告>.qmd",
  "  ├─ 函数/",
  "  │  ├─ registry_loader.R",
  sprintf("  │  └─ %s", basename(REGISTRY_PATHS$sql_main)),
  "  └─ 数据表/",
  sprintf("     ├─ %s", basename(REGISTRY_PATHS$yaml)),
  sprintf("     ├─ %s", basename(REGISTRY_PATHS$csv)),
  "     ├─ R01_late_shoe.csv",
  "     └─ S05_member_month_panel.csv",
  sep = "\n")

# ---------------------------------------------------------------------
# 六元组身份核验（与两份 CSV 交付件同法同源）
# ---------------------------------------------------------------------
registry_sixtuple <- function(path) {
  raw  <- readBin(path, "raw", n = file.size(path))
  lf   <- sum(raw == as.raw(10L))
  crlf <- if (length(raw) > 1L)
            any(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L)) else FALSE
  bom  <- length(raw) >= 3L && identical(raw[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))
  data.table(文件名 = basename(path), 总行数按LF计 = lf, 字节数 = length(raw),
             MD5 = unname(tools::md5sum(path)),
             换行符 = if (crlf) "CRLF" else "LF",
             BOM = if (bom) "有" else "无")
}

# ---------------------------------------------------------------------
# 主载入
# ---------------------------------------------------------------------
registry_load <- function(yaml_path = REGISTRY_PATHS$yaml,
                          csv_path  = REGISTRY_PATHS$csv) {

  .rstage("R00 文件门", {
    absent <- c(yaml_path, csv_path)[!file.exists(c(yaml_path, csv_path))]
    if (length(absent))
      stop(sprintf(paste0("○ 待表：当前工作目录\n  %s\n之下未找到：%s\n",
                          "预期布局如下（不以静态文字冒充结果，铁律第九条）：\n%s"),
                   getwd(), paste(absent, collapse = "、"), .layout_tree()))
  })

  ## SQL 总包在位软核验：登记册通篇以 §章节 索引其代码原文，缺档则溯源链断裂。
  ## 不阻断载入（报告可能只做画像不溯源），但须显式告警。
  .rstage("R00b SQL总包在位", {
    if (!file.exists(REGISTRY_PATHS$sql_main))
      warning(sprintf(paste0("【registry】未在 %s 找到 SQL 总包——",
                             "登记册 sql_section 栏所指章节将无法回溯原文，",
                             "证据链降级为不可溯源。"), REGISTRY_PATHS$sql_main))
  })

  ## CSV 派生字典（UTF-8-BOM，fread 自动剥离）
  dict <- .rstage("R01 CSV载入", {
    d <- fread(csv_path, encoding = "UTF-8")
    need <- c("axis","type_id","name_zh","criterion_column","criterion_source",
              "criterion_role","threshold_status","threshold_note",
              "evidence_tier","gate","severity","admit_to_scoring","admit_to_profile")
    miss <- setdiff(need, names(d))
    if (length(miss)) stop(sprintf("CSV 缺列：%s", paste(miss, collapse = "、")))
    d[, admit_to_scoring := toupper(trimws(admit_to_scoring)) == "TRUE"]
    d[, admit_to_profile := toupper(trimws(admit_to_profile)) == "TRUE"]
    d[]
  })

  ## YAML 真相源（可选依赖；缺失则降级并告警）
  ymeta <- NULL; mode <- "CSV-ONLY"
  if (requireNamespace("yaml", quietly = TRUE)) {
    ymeta <- .rstage("R02 YAML载入", yaml::read_yaml(yaml_path))
    mode  <- "YAML+CSV"
  } else {
    warning("【registry】未安装 yaml 包，降级为纯 CSV 模式；",
            "交叉一致性断言未执行，本次载入不具完整治理效力。")
  }

  ## 交叉比对：YAML 与 CSV 不得各说各话
  if (!is.null(ymeta)) .rstage("R03 YAML↔CSV 交叉比对", {
    y_ids <- vapply(ymeta$typologies, function(t) t$type_id, character(1))
    c_ids <- sort(unique(dict[axis == "R", type_id]))
    if (!setequal(y_ids, c_ids))
      stop(sprintf("类型集合不一致——仅YAML有：%s；仅CSV有：%s",
                   paste(setdiff(y_ids, c_ids), collapse = "、"),
                   paste(setdiff(c_ids, y_ids), collapse = "、")))
    for (t in ymeta$typologies) {
      sub <- dict[type_id == t$type_id]
      if (unique(sub$gate) != t$gate)
        stop(sprintf("%s 之 gate 不一致：YAML=%s CSV=%s",
                     t$type_id, t$gate, unique(sub$gate)))
      if (unique(sub$admit_to_scoring) != isTRUE(t$admit_to_scoring))
        stop(sprintf("%s 之 admit_to_scoring 不一致", t$type_id))
      y_cols <- vapply(t$criterion_columns, function(c) c$column, character(1))
      if (!setequal(y_cols, sub$criterion_column))
        stop(sprintf("%s 之判据列集合不一致", t$type_id))
    }
    ## 版本号亦须同源（登记册与载入器同进同退，杜绝版本身份碰撞）
    .expect <- "1.5.002"
    if (!identical(as.character(ymeta$registry$version), .expect))
      stop(sprintf("YAML registry.version=%s，载入器预期 %s —— 请同步递增版本号后重跑",
                   ymeta$registry$version, .expect))
  })

  ## 全局禁令自检：禁读档若存在于工作目录，立即示警
  if (!is.null(ymeta)) .rstage("R04 全局禁令自检", {
    for (p in ymeta$global_prohibitions) {
      if (grepl("\\.csv$", p$target) && file.exists(file.path(REGISTRY_PATHS$db_dir, p$target)))
        warning(sprintf("【registry·%s】禁读档存在于 数据库/ 目录：%s —— %s",
                        p$id, p$target, p$reason))
    }
  })

  ## 阻断项引用完整性：类型所引阻断项须存在于台账
  if (!is.null(ymeta)) .rstage("R05 阻断项引用完整性", {
    allb <- vapply(ymeta$blockers, function(b) b$id, character(1))
    for (t in ymeta$typologies) {
      bad <- setdiff(unlist(t$blockers), allb)
      if (length(bad))
        stop(sprintf("%s 引用了台账中不存在的阻断项：%s",
                     t$type_id, paste(bad, collapse = "、")))
    }
  })

  structure(list(
    dict     = dict,
    meta     = ymeta,
    mode     = mode,
    identity = rbind(registry_sixtuple(yaml_path), registry_sixtuple(csv_path)),
    loaded_at = Sys.time()
  ), class = "a168_registry")
}

# ---------------------------------------------------------------------
# 准入特征列名（评分管道唯一合法取材范围）
# ---------------------------------------------------------------------
registry_admitted_columns <- function(REG, which_axis = c("both","R","V")) {
  ## 注：参数名刻意不叫 axis——data.table 在 i 表达式中列名优先，
  ##     若参数与列同名则 d[axis == axis] 恒为真，筛选形同虚设（v1.1.0 已修正）
  which_axis <- match.arg(which_axis)
  d <- REG$dict[admit_to_scoring == TRUE]
  if (which_axis != "both") d <- d[axis == which_axis]
  unique(d$criterion_column)
}

registry_profile_columns <- function(REG) {
  unique(REG$dict[admit_to_profile == TRUE, criterion_column])
}

# ---------------------------------------------------------------------
# ★ 门闸：评分管道引用未准入特征者，渲染直接失败
# ---------------------------------------------------------------------
registry_gate <- function(REG, used, purpose = c("scoring","profile")) {
  purpose <- match.arg(purpose)
  ok <- if (purpose == "scoring") registry_admitted_columns(REG)
        else union(registry_admitted_columns(REG), registry_profile_columns(REG))
  bad <- setdiff(used, ok)
  if (length(bad)) {
    det <- REG$dict[criterion_column %in% bad,
                    .(criterion_column, type_id, name_zh, gate, severity,
                      blockers, verdict = substr(verdict, 1, 60))]
    det <- unique(det, by = "criterion_column")
    msg <- if (nrow(det))
      paste(sprintf("  · %s（%s %s）门禁=%s 严重度=%s 阻断=%s\n    裁定：%s…",
                    det$criterion_column, det$type_id, det$name_zh,
                    det$gate, det$severity,
                    ifelse(nzchar(det$blockers), det$blockers, "无"), det$verdict),
            collapse = "\n")
    else paste("  ·", paste(bad, collapse = "、"), "（未登记于本册）")
    stop(sprintf(
      "【registry·门闸拦截】以下特征未获 %s 准入，禁止入算：\n%s\n合法取材范围见 registry_admitted_columns()。",
      purpose, msg), call. = FALSE)
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------
# ★ v1.2.0 新增：灵活搭配四函数
# ---------------------------------------------------------------------

## 单类完整配方：主表＋搭配表＋全部判据维度＋裁定＋解锁条件
registry_typology <- function(REG, type_id) {
  .tid <- type_id                      # v1.5.0 斧正：`..` 前缀仅容于 j，置于 i 即报错
  d <- REG$dict[type_id == .tid]
  if (!nrow(d)) stop(sprintf("登记册中无此类型：%s（现有：%s）", type_id,
                             paste(sort(unique(REG$dict$type_id)), collapse = "、")),
                     call. = FALSE)
  meta <- if (!is.null(REG$meta))
    Filter(function(x) identical(x$type_id, type_id), REG$meta$typologies)[[1]] else NULL
  out <- list(
    编号 = type_id, 名称 = d$name_zh[1L], 类别 = d$category[1L], 坐标 = d$tls[1L],
    主表 = d$primary_deliverable[1L],
    搭配表 = { s <- unlist(strsplit(d$supporting_deliverables[1L], "；")); s[nzchar(s)] },
    判据维度 = d[, .(判据列 = criterion_column, 取自 = criterion_source,
                     角色 = criterion_role, 方向 = direction,
                     阈值状态 = threshold_status, 阈值注 = threshold_note)],
    证据 = d$evidence_tier[1L], 门禁 = d$gate[1L], 严重度 = d$severity[1L],
    准入评分 = d$admit_to_scoring[1L], 准入画像 = d$admit_to_profile[1L],
    阻断 = { b <- unlist(strsplit(d$blockers[1L], "；")); b[nzchar(b)] },
    裁定 = d$verdict[1L], 标准依据 = d$standard_basis[1L],
    解锁条件 = if (!is.null(meta)) unlist(meta$unblock_conditions) else NULL,
    影子要求 = if (!is.null(meta)) unlist(meta$shadow_requirements) else NULL,
    禁用来源 = if (!is.null(meta)) unlist(meta$forbidden_sources) else NULL)
  class(out) <- "a168_typology"
  out
}

print.a168_typology <- function(x, ...) {
  cat(sprintf("【%s %s】%s · %s\n", x$编号, x$名称, x$类别, x$坐标))
  cat(sprintf("  主表：%s\n  搭配：%s\n", x$主表,
              if (length(x$搭配表)) paste(x$搭配表, collapse = "、") else "—"))
  cat(sprintf("  证据=%s 门禁=%s 严重度=%s 准入评分=%s 准入画像=%s\n",
              x$证据, x$门禁, x$严重度,
              ifelse(x$准入评分, "是", "否"), ifelse(x$准入画像, "是", "否")))
  if (length(x$阻断)) cat(sprintf("  阻断：%s\n", paste(x$阻断, collapse = "、")))
  cat(sprintf("  判据 %d 条：%s\n", nrow(x$判据维度),
              paste(x$判据维度$判据列, collapse = " ＋ ")))
  cat(sprintf("  裁定：%s\n", x$裁定))
  if (length(x$解锁条件))
    cat("  解锁条件：\n", paste0("    · ", x$解锁条件, collapse = "\n"), "\n", sep = "")
  if (length(x$影子要求))
    cat("  影子要求：\n", paste0("    · ", x$影子要求, collapse = "\n"), "\n", sep = "")
  invisible(x)
}

## 跨类搭配：把若干类型的判据维度合成一张可用/不可用一目了然的配方表
##   mode = "union"     并集（默认，画像用）
##   mode = "intersect" 交集（只取各类共用之交付件，用于找可一次取数的组合）
##   mode = "admitted"  仅保留准入评分之判据（评分管道用）
registry_combo <- function(REG, type_ids, mode = c("union","intersect","admitted")) {
  mode <- match.arg(mode)
  bad <- setdiff(type_ids, unique(REG$dict$type_id))
  if (length(bad)) stop(sprintf("登记册中无此类型：%s", paste(bad, collapse = "、")),
                        call. = FALSE)
  d <- REG$dict[type_id %chin% type_ids]
  if (mode == "admitted") d <- d[admit_to_scoring == TRUE]
  if (mode == "intersect") {
    common <- Reduce(intersect, split(d$primary_deliverable, d$type_id))
    d <- d[primary_deliverable %chin% common]
  }
  out <- d[, .(类型 = paste(unique(type_id), collapse = "／"),
               名称 = paste(unique(name_zh), collapse = "／"),
               取自 = paste(unique(criterion_source), collapse = "／"),
               方向 = paste(unique(direction), collapse = "／"),
               门禁 = paste(unique(gate), collapse = "／"),
               可入评分 = fifelse(any(admit_to_scoring), "✅", "—")),
           by = .(判据列 = criterion_column)]
  setorder(out, 类型, 判据列)
  attr(out, "mode") <- mode
  attr(out, "gate_summary") <- unique(d[, .(type_id, name_zh, gate, severity,
                                            admit_to_scoring)])
  out[]
}

## 列反查：某判据列属于哪几类、当前是否可用
registry_which <- function(REG, column) {
  d <- REG$dict[criterion_column %chin% column]
  if (!nrow(d)) return(data.table(判据列 = column, 结论 = "未登记于本册"))
  unique(d[, .(判据列 = criterion_column, 类型 = type_id, 名称 = name_zh,
               门禁 = gate, 严重度 = severity,
               可入评分 = fifelse(admit_to_scoring, "✅", "—"),
               可入画像 = fifelse(admit_to_profile, "✅", "—"),
               裁定 = verdict)])
}

## 自 SQL 总包现算唯一交付件数（铁律第九条：此数不得写死于任何 qmd）
##   口径同 SQL 总包自述：两式并扫「导出声明行」，一行一件；剔除占位符。
registry_count_deliverables <- function(sql_path = REGISTRY_PATHS$sql_main,
                                        drop_placeholder = TRUE) {
  if (!file.exists(sql_path))
    stop(sprintf("○ 待表：未找到 SQL 总包 %s，交付件数不得以静态文字冒充（铁律第九条）。",
                 sql_path), call. = FALSE)
  ln <- readLines(sql_path, warn = FALSE, encoding = "UTF-8")
  hit <- grep("数据库/", ln, fixed = TRUE, value = TRUE)
  hit <- trimws(hit)
  hit <- hit[grepl("导出", hit) &
             (startsWith(hit, "--") | startsWith(hit, "▸") |
              startsWith(hit, "*")  | grepl("▸", hit, fixed = TRUE))]
  ## ★ 必须用 Unicode 安全模式：本包有 6 个中文命名交付件（P0C02…P0C09 族）。
  ##   纯 ASCII 正则 [A-Za-z0-9_.-]+ 会静默漏掉它们——SQL 总包自述之「69」即此病，
  ##   68（ASCII 实际）+ 6（中文名）= 74（真值），另 69 内还混入占位符 xxx.csv。
  nm <- unlist(regmatches(hit, gregexpr("(?<=数据库/)[^\\s\u300c\u300d\uff08\uff09,;\uff1a]+\\.csv",
                                        hit, perl = TRUE)))
  ph <- grepl("xxx", nm, ignore.case = TRUE)
  ascii_nm <- unlist(regmatches(hit, gregexpr("(?<=数据库/)[A-Za-z0-9_.\\-]+\\.csv",
                                              hit, perl = TRUE)))
  cn_only  <- setdiff(unique(nm), unique(ascii_nm))
  list(声明行数 = length(hit),
       唯一交付件 = length(unique(nm)),
       占位符 = unique(nm[ph]),
       实际交付件 = length(unique(nm[if (drop_placeholder) !ph else TRUE])),
       ASCII口径唯一名 = length(unique(ascii_nm)),
       中文命名者 = sort(cn_only),
       清单 = sort(unique(nm[if (drop_placeholder) !ph else TRUE])))
}

# ---------------------------------------------------------------------
# 呈表助手（呈表纪律：kable/gt；副题现算总行列数）
# ---------------------------------------------------------------------
registry_table <- function(REG, admitted_only = FALSE) {
  d <- copy(REG$dict)
  if (admitted_only) d <- d[admit_to_scoring == TRUE]
  out <- d[, .(判据数 = .N,
               判据列 = paste(criterion_column, collapse = "、")),
           by = .(轴 = axis, 类型 = type_id, 名称 = name_zh, 类别 = category,
                  坐标 = tls, 主交付件 = primary_deliverable,
                  证据 = evidence_tier, 门禁 = gate, 严重度 = severity,
                  准入评分 = fifelse(admit_to_scoring, "✅", "—"),
                  准入画像 = fifelse(admit_to_profile, "✅", "—"),
                  阻断 = blockers)]
  setorder(out, 轴, 类型)
  out[]
}

registry_matrix <- function(REG) {
  if (is.null(REG$meta)) stop("V×R 矩阵需 YAML 模式（请安装 yaml 包）")
  cells <- rbindlist(lapply(REG$meta$scoring_matrix$cells, as.data.table))
  dcast(cells, value ~ risk, value.var = "action")
}

registry_blockers <- function(REG) {
  if (is.null(REG$meta)) stop("阻断项台账需 YAML 模式")
  rbindlist(lapply(REG$meta$blockers, function(b) data.table(
    编号 = b$id, 影响类型 = paste(b$affects, collapse = "、"),
    标题 = b$title, 详情 = b$detail, 严重度 = b$severity, 状态 = b$status)))
}

# 待建特征清单：criterion_source 以「待建」起首者，即尚未存在于任何交付件之列
registry_pending_features <- function(REG) {
  d <- REG$dict[grepl("^待建", criterion_source)]
  unique(d[, .(类型 = type_id, 名称 = name_zh, 待建特征 = criterion_column,
               拟建来源 = criterion_source, 阻断 = blockers)])
}

registry_open_questions <- function(REG) {
  if (is.null(REG$meta)) stop("悬案台账需 YAML 模式")
  rbindlist(lapply(REG$meta$open_questions, function(q) data.table(
    编号 = q$id, 问题 = q$question, 影响 = q$impact,
    严重度 = q$severity, 状态 = q$status)))
}

print.a168_registry <- function(x, ...) {
  cat(sprintf("a168 风险类型登记册 · 模式=%s · 载入于 %s\n", x$mode,
              format(x$loaded_at, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("  类型 %d 个（准入评分 %d 个）· 判据列 %d 条\n",
              uniqueN(x$dict[axis == "R", type_id]),
              uniqueN(x$dict[admit_to_scoring == TRUE & axis == "R", type_id]),
              nrow(x$dict)))
  cat("  准入特征：", paste(registry_admitted_columns(x), collapse = "、"), "\n")
  g <- x$dict[axis == "R", .(n = uniqueN(type_id)), by = gate]
  cat("  门禁分布：", paste(sprintf("%s=%d", g$gate, g$n), collapse = " · "), "\n")
  pend <- registry_pending_features(x)
  if (nrow(pend)) cat(sprintf("  待建特征 %d 条（见 registry_pending_features()）\n", nrow(pend)))
  invisible(x)
}

# ---------------------------------------------------------------------
# v1.5.0 新增 · registry_counts：YAML 声明 ↔ CSV 现算互证
#   任何 qmd 禁止硬写 15／65／66／42，一律取本函数回传值。
# ---------------------------------------------------------------------
registry_counts <- function(REG) {
  d <- REG$dict
  obs <- list(
    total_criterion_rows  = nrow(d),
    risk_typology_count   = uniqueN(d[axis == "R", type_id]),
    value_axis_count      = uniqueN(d[axis != "R", type_id]),
    risk_criterion_count  = nrow(d[axis == "R"]),
    stat_directional_rows = nrow(d[criterion_role == "STAT_DIRECTIONAL"]),
    direction_enum_size   = uniqueN(d[nzchar(direction), direction]))
  if (!is.null(REG$meta$registry_counts)) {
    dec <- REG$meta$registry_counts
    for (k in names(obs)) {
      if (!is.null(dec[[k]]) && as.integer(dec[[k]]) != as.integer(obs[[k]]))
        stop(sprintf("【registry·counts】%s：YAML 声明 %s，CSV 现算 %s —— 双档分家，停止渲染",
                     k, dec[[k]], obs[[k]]), call. = FALSE)
    }
  }
  obs
}

# ---------------------------------------------------------------------
# v1.5.0 新增 · registry_type_scalars：型层上载标量（T-03 四禁令／T-10 内控四键）
# ---------------------------------------------------------------------
registry_type_scalars <- function(REG, type_id) {
  keys <- c("ranking","scoring","trigger","enforcement","admit_to_control",
            "identity_formula","external_standard_status","applicability_status")
  keys <- intersect(keys, names(REG$dict))
  .tid <- type_id
  d <- REG$dict[type_id == .tid][1L]
  out <- lapply(keys, function(k) d[[k]])
  names(out) <- keys
  Filter(function(v) !is.na(v) && nzchar(v), out)
}

