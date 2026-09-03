# ---------------------------------------------------------------------
# §9 血统配套 · 统一六元组（N-8 · 2026-09-03）
# ---------------------------------------------------------------------
# 【本节之立意】六元组（档名／字节／行数／换行／BOM／MD5）此前有【四份各写各的】实作：
#     registry_sixtuple()        函数/registry_loader.R      —— 六栏，全 md5
#     glossary_sixtuple()        函数/glossary_engine.R      —— 与上逐字同构（重复实作）
#     six_tuple()                函数/verify_registry_dual.R —— 英文键，EOL 三态（含 MIXED）
#     tr_deliverable_identity()  本档 §4.3                   —— md5 截 12 位、字节改 MB、另加五栏
#   同一概念四种形制：栏名不同、md5 有全有截、字节有 B 有 MB、EOL 有二态有三态。
#   ⇒ 故此前【不是一个配套，是四份副本】。本节立唯一正典 tr_sixtuple()；余三处不动（只增不减），
#     但血统章一律改取本节，杜绝形制分歧。
#
# 【更要紧者 · 本节所治之病】模板之「血统件」表历来以**手写字面量**列版本与路径。
#   2026-09-03 实测：五处已陈旧——载入器头注「配套」行、模板 subtitle、单一真相源注、
#   血统件表之登记册路径，皆仍书 v1.5.003（实为 v1.5.004）；血统件表之引擎版本书 1.2.0（实为 1.4.0）。
#   ⇒ 手写字面量必然随版漂移，且漂移不报错。本节令血统表【渲染时现算】：
#     版本自各档档头正则现取、路径自载入器常量现取、六元组自盘上现算——该类缺陷自此绝迹，非靠自律。
#   ⛔ 承硬码铁律：血统表内不得再出现任何手写版本号、手写路径或手写 md5。
# ---------------------------------------------------------------------

## 正典六元组：一处实作，全配套共用
tr_sixtuple <- function(path) {
  if (is.na(path) || !nzchar(path) || !file.exists(path))
    return(data.table(件 = if (is.na(path)) "—" else basename(path),
                      版本 = NA_character_, 字节 = NA_real_, 行数 = NA_integer_,
                      换行 = "—", BOM = "—", MD5 = "—", 在位 = "✗ 不在位",
                      路径 = if (is.na(path)) "—" else path))
  raw    <- readBin(path, "raw", file.size(path))
  n_lf   <- sum(raw == as.raw(10L))
  n_cr   <- sum(raw == as.raw(13L))
  n_crlf <- if (length(raw) > 1L) sum(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L)) else 0L
  eol <- if (n_lf > 0L && n_crlf == n_lf && n_cr == n_lf) "CRLF" else if (n_cr == 0L) "LF" else "MIXED"
  bom <- length(raw) >= 3L && identical(as.integer(raw[1:3]), c(239L, 187L, 191L))
  data.table(件 = basename(path), 版本 = NA_character_,
             字节 = length(raw), 行数 = n_lf, 换行 = eol,
             BOM = if (bom) "有" else "无",
             MD5 = unname(tools::md5sum(path)), 在位 = "✓", 路径 = path)
}

## 自档头现取版本（不手写）
##   R／qmd 档头体例：「# 版本 : 1.4.0」「# 载入器版本 : 1.5.004」
##   YAML 体例      ：「  version: 1.5.004」「  version: '0.1.3'」
tr_file_version <- function(path, n_head = 40L) {
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  h <- tryCatch(readLines(path, n = n_head, warn = FALSE, encoding = "UTF-8"),
                error = function(e) character(0))
  if (!length(h)) return(NA_character_)
  num <- "([0-9]+(?:[.][0-9]+)+)"
  pats <- c(paste0("(?:载入器)?版本[[:space:]]*[:：][[:space:]]*v?", num),
            paste0("^[[:space:]]*version[[:space:]]*:[[:space:]]*['\"]?v?", num))
  for (q in pats) {
    hit <- regmatches(h, regexpr(q, h, perl = TRUE))
    if (length(hit)) {
      v <- regmatches(hit[1L], regexpr(num, hit[1L], perl = TRUE))
      if (length(v)) return(v[1L])
    }
  }
  NA_character_
}

## 血统配套清单：渲染时现算全配套十四件之六元组 ＋ 版本
## ★ 登记册与规则册之路径自载入器常量现取，不手写
tr_lineage_manifest <- function(REG = NULL) {
  gp <- if (exists("GLOSSARY_PATHS")) GLOSSARY_PATHS else list(yaml = NA_character_, csv = NA_character_)
  items <- list(
    list(角色 = "登记册 YAML（SSOT）",    path = if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$yaml else NA_character_),
    list(角色 = "登记册 CSV（派生字典）",  path = if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$csv  else NA_character_),
    list(角色 = "规则册",                 path = if (exists("RULES_PATH")) RULES_PATH else NA_character_),
    list(角色 = "术语库 YAML",            path = gp$yaml),
    list(角色 = "术语库 CSV",             path = gp$csv),
    list(角色 = "软配置册",               path = if (exists("TR_CFG_PATH")) TR_CFG_PATH else file.path("配置", "report_config_v1.0.0.yaml")),
    list(角色 = "登记册载入器",           path = file.path("函数", "registry_loader.R")),
    list(角色 = "规则册载入器",           path = file.path("函数", "rule_registry_loader.R")),
    list(角色 = "双档校验器",             path = file.path("函数", "verify_registry_dual.R")),
    list(角色 = "分析引擎（含范本体例）",  path = file.path("函数", "typology_report_engine.R")),
    list(角色 = "术语引擎",               path = file.path("函数", "glossary_engine.R")),
    list(角色 = "生成器",                 path = file.path("函数", "build_typology_reports.R")),
    list(角色 = "判据坐标表导出器",        path = file.path("函数", "export_criterion_atlas.R")),
    list(角色 = "模板",                   path = file.path("模板", "风险会员商业方案_模板.qmd"))
  )
  out <- rbindlist(lapply(items, function(it) {
    st <- tr_sixtuple(it$path)
    st[, 角色 := it$角色]
    st[, 版本 := tr_file_version(it$path)]
    st
  }), fill = TRUE)
  ## 登记册版本以 registry_load() 实载者为准（机器现取，压过档头正则）
  if (!is.null(REG) && !is.null(REG$meta$registry$version))
    out[grepl("^登记册", 角色), 版本 := as.character(REG$meta$registry$version)]
  out[is.na(版本), 版本 := "—"]
  setcolorder(out, c("角色", "件", "版本", "字节", "行数", "换行", "BOM", "MD5", "在位", "路径"))
  out[]
}

## 配套自洽闸：载入器路径所载之版本，须等于 registry_load() 实际载入者
##   ⛔ 二者不符即血统断裂——档名说一套、内容说另一套，本档任何数字皆不可引用。
tr_lineage_gate <- function(REG) {
  yp <- if (exists("REGISTRY_PATHS")) REGISTRY_PATHS$yaml else ""
  hit <- regmatches(yp, regexpr("[0-9]+([.][0-9]+)+", yp))
  onpath <- if (length(hit)) hit[1L] else "—"
  loaded <- as.character(REG$meta$registry$version)
  data.table(闸 = "血统自洽：载入器路径版本 ＝ 实载登记册版本",
             路径版本 = onpath, 实载版本 = loaded,
             判 = if (identical(onpath, loaded)) "✓ PASS" else "✗ FAIL —— 路径与实载不符，停止引用本档任何数字")
}
