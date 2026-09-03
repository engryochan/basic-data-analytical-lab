# -*- coding: utf-8 -*-
"""N-4 合档：typology_report_engine_ext.R 并入 typology_report_engine.R（1.2.0），删 ext；
模板 1.4.2、生成器 1.3.2 同步。一切文件 LF；每处替换断言恰一次；函数本体一字未改。"""
import os, sys, hashlib
sys.stdout.reconfigure(encoding="utf-8")
P = r"C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系"
def rd(rel):
    b = open(os.path.join(P, rel), "rb").read(); assert b"\r\n" not in b, rel + " 非 LF"
    return b.decode("utf-8")
def wr(rel, s):
    b = s.encode("utf-8"); assert b"\r\n" not in b
    open(os.path.join(P, rel), "wb").write(b)
    print(f"{rel} | bytes {len(b)} | lines {b.count(chr(10).encode())} | md5 {hashlib.md5(b).hexdigest()}")
def sub(s, old, new, tag):
    assert s.count(old) == 1, f"{tag}: 出现 {s.count(old)} 次（须恰 1）"
    return s.replace(old, new)

base = rd("函数/typology_report_engine.R")
ext  = rd("函数/typology_report_engine_ext.R")
bl, el = base.split("\n"), ext.split("\n")
n_base_fn = sum(1 for l in bl if l and l[0].isalpha() and " <- function" in l)
n_ext_fn  = sum(1 for l in el if l and (l[0].isalpha() or l[0] == ".") and " <- function" in l)

# ── 1. 主引擎头注 1.1.0 → 1.2.0 ──
base = sub(base,
"# typology_report_engine.R · 十五类风险会员商业方案 · 共用分析引擎\n"
"# ---------------------------------------------------------------------\n"
"# 版本 : 1.1.0        日期 : 2026-08-22        适配登记册 : 1.5.0\n"
"# 身份 : 执行件（函数/）★ 非交付件、非规范件\n",
"# typology_report_engine.R · 十五类风险会员商业方案 · 共用分析引擎（含范本体例）\n"
"# ---------------------------------------------------------------------\n"
"# 版本 : 1.2.0        日期 : 2026-09-03        适配登记册 : 1.5.003\n"
"# 变更 : 1.2.0（N-4 · 2026-09-03 · Ryo Eng 裁定）——typology_report_engine_ext.R\n"
"#        （扩充引擎 1.3.0，46 函数）整档并入本档 §E0～§E13，该档同时删除。\n"
"#        并档依据：ext 档首 stopifnot(exists(\"tr_load\")) 硬依赖本档，且两档函数名\n"
"#        零重叠（本档 12 ／ ext 46），非替代关系而系依附扩充 ⇒ 合为一档方为一物。\n"
"#        ★ 两档函数本体一字未改；仅去 ext 之 stopifnot 自守（同档已无从缺席）、\n"
"#          并 library(yaml) 入本档首、并订正 ext 头注三处陈旧串（数据库/→数据表/、\n"
"#          v1.5.0→v1.5.003、身份行）。source 者自此只需一行。\n"
"# 身份 : 执行件（函数/）★ 非交付件、非规范件\n", "主引擎头注")
base = sub(base,
"suppressPackageStartupMessages({ library(data.table); library(knitr) })",
"suppressPackageStartupMessages({ library(data.table); library(knitr); library(yaml) })", "library 行")
base = sub(base,
'TR_DB        <- "数据表"   # N-2A 2026-09-03：承 7f713dc 目录改名；_ext.R 以配置册 namespaces.delivery 覆写',
'TR_DB        <- "数据表"   # N-2A 2026-09-03：承 7f713dc 目录改名；§E0 tr_apply_config() 以配置册 namespaces.delivery 覆写',
"TR_DB 注")

# ── 2. ext 头注（L1–21）转为内嵌节头，订正三处陈旧串；去 stopifnot 与 library(yaml)（L22–25）──
assert el[22].startswith("stopifnot(") and el[23].startswith("suppressPackageStartupMessages(library(yaml))"), "ext L23/L24 非预期"
assert el[25].startswith("# ----"), "ext L26 非预期"
hdr = "\n".join(el[:21])
hdr = sub(hdr, "# typology_report_engine_ext.R · 十五类商业方案 · 范本体例扩充引擎",
               "# 【§E · 范本体例扩充】原 typology_report_engine_ext.R（1.3.0）整档并入 —— 以下至档末", "ext 标题")
hdr = sub(hdr, "# 版本 : 1.3.0        日期 : 2026-08-22        适配登记册 : 1.5.0",
               "# 原版本 : 1.3.0      原日期 : 2026-08-22      并入日 : 2026-09-03（N-4）", "ext 版本行")
hdr = sub(hdr, "# 身份 : 执行件（函数/）★ 须先 source 函数/typology_report_engine.R",
               "# 身份 : 本档 §E 段 ★ 依赖上文 §1～§8 之 tr_load／tr_recipe 等（同档，无须另 source）", "ext 身份行")
hdr = sub(hdr, "#   ✅ 一切取自 规范/registry_risk_typology_v1.5.0 与 数据库/ 交付件，渲染时现算。",
               "#   ✅ 一切取自 规范/registry_risk_typology_v1.5.003 与 数据表/ 交付件，渲染时现算。", "ext 血统行")
merged = base.rstrip("\n") + "\n\n" + hdr + "\n\n" + "\n".join(el[25:])
assert "stopifnot(\"须先 source" not in merged and "library(yaml))" not in merged
wr("函数/typology_report_engine.R", merged)
os.remove(os.path.join(P, "函数/typology_report_engine_ext.R"))
print(f"ext 已删；函数计数 主 {n_base_fn} ＋ 扩充 {n_ext_fn}")

# ── 3. 模板 1.4.1 → 1.4.2 ──
t = rd("模板/风险会员商业方案_模板.qmd")
t = sub(t, 'subtitle: "十五类风险会员判据商业方案 · {{TYPE_ID}} · 登记册 v1.5.002 同源现算"',
           'subtitle: "十五类风险会员判据商业方案 · {{TYPE_ID}} · 登记册 v1.5.003 同源现算"', "副标题")
t = sub(t, "## 【单一真相源】规范/registry_risk_typology_v1.5.002.{yaml,csv}",
           "## 【单一真相源】规范/registry_risk_typology_v1.5.003.{yaml,csv}", "真相源注")
t = sub(t, 'source("函数/typology_report_engine.R"); source("函数/typology_report_engine_ext.R")',
           'source("函数/typology_report_engine.R")   # N-4：扩充引擎已并入本档，一行即全', "source 行")
t = sub(t,
'  件 = c("登记册", "软配置册", "术语库", "主引擎", "扩充引擎", "生成器", "模板"),\n'
'  版本 = c(reg_ver, CFG$config$version, "v1.0.0", "1.1.0", "1.3.0", "1.3.1", "1.4.1"),\n'
'  路径 = c("规范/registry_risk_typology_v1.5.002.{yaml,csv}", "配置/report_config_v1.0.0.yaml",\n'
'           "规范/glossary_a168_v1.0.0.{yaml,csv}", "函数/typology_report_engine.R",\n'
'           "函数/typology_report_engine_ext.R", "函数/build_typology_reports.R",\n'
'           "模板/风险会员商业方案_模板.qmd"))),',
'  件 = c("登记册", "软配置册", "术语库", "分析引擎（含范本体例）", "生成器", "模板"),\n'
'  版本 = c(reg_ver, CFG$config$version, "v1.0.0", "1.2.0", "1.3.2", "1.4.2"),\n'
'  路径 = c("规范/registry_risk_typology_v1.5.003.{yaml,csv}", "配置/report_config_v1.0.0.yaml",\n'
'           "规范/glossary_a168_v1.0.0.{yaml,csv}", "函数/typology_report_engine.R",\n'
'           "函数/build_typology_reports.R",\n'
'           "模板/风险会员商业方案_模板.qmd"))),', "血统件表")
t = sub(t,
"→ **v1.5.002**（加法升级 · 锚 `7f713dc` · 父版 3,943 行仅版本号两行改、追加经济实测十节 · CSV 与父版逐字节相同 · 双跑 23 PASS/0 FAIL/3 NOT_RUN）",
"→ v1.5.002（加法升级 · 锚 `7f713dc` · 追加经济实测十节 · CSV 与父版逐字节相同）"
"→ **v1.5.003**（头块补正 · 锚 `24b8d8d` · 父版 10,677 行只改 12 行：parent 由祖父 v1.5.0 改指真正父版、version_note、revision_note · 校验器增 R04b · 双跑 24 PASS/0 FAIL/3 NOT_RUN）", "血统链")
t = sub(t, "## v1.4.1（{{DATE}}）· N-2B 血统层升版：指向 registry v1.5.002 · 命名空间 数据表",
"""## v1.4.2（{{DATE}}）· N-4 双引擎合档 ＋ 血统指向 registry v1.5.003

::: {.callout-note}
## 本版只改血统与消费方式，不改语义

**① 双引擎合档**（Ryo Eng 裁定）：`函数/typology_report_engine_ext.R`（扩充引擎 1.3.0，46 函数）整档并入
`函数/typology_report_engine.R`（1.2.0），该档同时删除。依据：ext 档首 `stopifnot(exists("tr_load"))` 硬依赖主引擎，
且两档函数名零重叠（主 12 ／ 扩充 46）——非替代关系而系依附扩充，故合为一档方为一物。
**两档函数本体一字未改**；本模板之 `source()` 由两行并为一行，血统件表由七件并为六件。

**② 血统层升版**：四处指针自 `v1.5.002` 改指 `v1.5.003`（副标题、单一真相源注记、血统件路径表、血统链）。
`v1.5.003` 系头块补正版——父版 10,677 行只改 12 行（`registry.parent` 由祖父 `v1.5.0` 改指真正父版 `v1.5.002`
并回填实读 md5、`version_note`、`revision_note` 追加两条目），判据层 66 行与十五 typology 块逐字节未改，
CSV 与父版逐字节相同。校验器同步增 **R04b**（`registry.parent.version` 须等于校验器 `parent_version`），
双跑 24 PASS ／ 0 FAIL ／ 3 NOT_RUN（R12／R20／R24b 为既有未竟项，第二阶段闸仍 NOT_PASS）。

判据渲染逻辑、章体、表格、统计口径、软配置消费方式一字未改——语义 diff 恒为零。
:::

## v1.4.1（2026-09-03）· N-2B 血统层升版：指向 registry v1.5.002 · 命名空间 数据表""", "变更记录")
assert t.count("{{DATE}}") == 2, f"{{DATE}} 占位 {t.count('{{DATE}}')} 次（金丝雀契约须恰 2）"
wr("模板/风险会员商业方案_模板.qmd", t)

# ── 4. 生成器 1.3.1 → 1.3.2 ──
g = rd("函数/build_typology_reports.R")
g = sub(g,
"# 版本 : 1.3.1        日期 : 2026-09-03        适配登记册 : 1.5.002（登记册版本自 registry_load() 现取，本器不写死）\n",
"# 版本 : 1.3.2        日期 : 2026-09-03        适配登记册 : 1.5.003（登记册版本自 registry_load() 现取，本器不写死）\n"
"# 变更 : 1.3.2（N-4）version 默认 v1.4.1 → v1.4.2（模板 v1.4.2：双引擎合档 ＋ 指向 registry v1.5.003）。铸件逻辑一字未改。\n", "生成器头注")
g = sub(g, 'version = "v1.4.1", date = format(Sys.Date(), "%Y-%m-%d"),',
           'version = "v1.4.2", date = format(Sys.Date(), "%Y-%m-%d"),', "生成器默认版号")
wr("函数/build_typology_reports.R", g)
print("N-4 合档完成")
