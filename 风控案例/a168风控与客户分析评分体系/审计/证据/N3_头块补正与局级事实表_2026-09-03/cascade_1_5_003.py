# -*- coding: utf-8 -*-
"""N-3 级联：载入器／规则册载入器／规则册 v0.1.2／校验器 1.2.0（增 R04b）／配置册 1.3.0 → 指向 registry v1.5.003。
每处替换须恰一次；文件皆 LF；只增不减（头注旧变更保留）。"""
import os, sys, hashlib, shutil
sys.stdout.reconfigure(encoding="utf-8")
P = r"C:/Users/engry/Documents/GitHub/basic-data-analytical-lab/风控案例/a168风控与客户分析评分体系"
def md5(b): return hashlib.md5(b).hexdigest()
def edit(rel, repl):
    p = os.path.join(P, rel); b = open(p, "rb").read(); assert b"\r\n" not in b, rel + " 非 LF"
    s = b.decode("utf-8")
    for old, new in repl:
        c = s.count(old); assert c == 1, f"{rel}: {c} 次：{old[:70]!r}"
        s = s.replace(old, new)
    b2 = s.encode("utf-8"); open(p, "wb").write(b2)
    print(f"{rel} | bytes {len(b)}->{len(b2)} | lines {b.count(b'\n')}->{b2.count(b'\n')} | md5 {md5(b2)}")

# ── 1. registry_loader.R ──
edit("函数/registry_loader.R", [
 ("# 载入器版本 : 1.5.002      适配登记册 : 1.5.002      日期 : 2026-09-03\n",
  "# 载入器版本 : 1.5.003      适配登记册 : 1.5.003      日期 : 2026-09-03\n"
  "# 变更     : N-3（2026-09-03）——两处实质改动：① 路径指向 v1.5.003 双档（头块补正版：parent 改指真正父版\n"
  "#            v1.5.002、version_note／revision_note 补正；判据层 66 行与 CSV 逐字节未改）；② .expect 1.5.002 → 1.5.003。\n"
  "#            R01～R03 门闸逻辑一字未改。裁定：Ryo Eng 2026-09-03。\n"),
 ("# 配套     : 规范/registry_risk_typology_v1.5.002.yaml（单一真相源，UTF-8 无 BOM/LF）\n"
  "#            规范/registry_risk_typology_v1.5.002.csv （派生字典，UTF-8-BOM/LF）\n",
  "# 配套     : 规范/registry_risk_typology_v1.5.003.yaml（单一真相源，UTF-8 无 BOM/LF）\n"
  "#            规范/registry_risk_typology_v1.5.003.csv （派生字典，UTF-8-BOM/LF）\n"),
 ('  yaml     = .rp("规范", "registry_risk_typology_v1.5.002.yaml"),\n  csv      = .rp("规范", "registry_risk_typology_v1.5.002.csv"),\n',
  '  yaml     = .rp("规范", "registry_risk_typology_v1.5.003.yaml"),\n  csv      = .rp("规范", "registry_risk_typology_v1.5.003.csv"),\n'),
 ('    .expect <- "1.5.002"\n', '    .expect <- "1.5.003"\n'),
])

# ── 2. 规则册 v0.1.2（复制 v0.1.1，仅头块递增）──
src = os.path.join(P, "规范/rule_registry_v0.1.1.yaml"); dst = os.path.join(P, "规范/rule_registry_v0.1.2.yaml")
shutil.copyfile(src, dst)
edit("规范/rule_registry_v0.1.2.yaml", [
 ("  version: 0.1.1\n  issued: '2026-09-03'\n  parent: registry_risk_typology_v1.5.002\n  parent_previous: registry_risk_typology_v1.5.0\n",
  "  version: 0.1.2\n  issued: '2026-09-03'\n  parent: registry_risk_typology_v1.5.003\n  parent_previous: registry_risk_typology_v1.5.002\n"
  "  changelog_0_1_2: N-3（2026-09-03）——仅 registry 头块递增：parent v1.5.002 → v1.5.003（头块补正版，判据层逐位未改）；\n"
  "    rules 本体一字未改。前版 rule_registry_v0.1.1.yaml 原地保留。\n"),
 ("  parent_rule: 本册只消费 v1.5.002；不得自创类型、不得改写 v1.5.002 之 threshold_status。\n",
  "  parent_rule: 本册只消费 v1.5.003；不得自创类型、不得改写 v1.5.003 之 threshold_status。\n"),
])

# ── 3. rule_registry_loader.R ──
edit("函数/rule_registry_loader.R", [
 ("# 版本 : 0.1.2        日期 : 2026-09-03        适配 : typology 1.5.002 / rules 0.1.1\n",
  "# 版本 : 0.1.3        日期 : 2026-09-03        适配 : typology 1.5.003 / rules 0.1.2\n"
  "# 变更 : N-3 —— 版本串 1.5.002 → 1.5.003；RULES_PATH 改指 rule_registry_v0.1.2.yaml（仅头块递增）。闸门 G1~G6 逻辑未动。\n"),
 ('RULES_PATH <- file.path("规范", "rule_registry_v0.1.1.yaml")\n', 'RULES_PATH <- file.path("规范", "rule_registry_v0.1.2.yaml")\n'),
 ('  if (!identical(y$registry$parent, "registry_risk_typology_v1.5.002"))\n    stop("规则册 parent 非 v1.5.002", call. = FALSE)\n'
  '  if (!identical(as.character(REG$meta$registry$version), "1.5.002"))\n    stop("载入之登记册非 v1.5.002", call. = FALSE)\n',
  '  if (!identical(y$registry$parent, "registry_risk_typology_v1.5.003"))\n    stop("规则册 parent 非 v1.5.003", call. = FALSE)\n'
  '  if (!identical(as.character(REG$meta$registry$version), "1.5.003"))\n    stop("载入之登记册非 v1.5.003", call. = FALSE)\n'),
])

# ── 4. verify_registry_dual.R 1.2.0：target/parent 递增 ＋ R04b ──
edit("函数/verify_registry_dual.R", [
 ("# 版本 : 1.1.0        立册 : 2026-09-02        Owner : Ryo Eng\n",
  "# 版本 : 1.2.0        立册 : 2026-09-02        Owner : Ryo Eng\n"
  "# 变更 : 1.2.0（N-3 · 2026-09-03）target 1.5.002 → 1.5.003、parent 1.5.001 → 1.5.002；新增 rule_id \"R04b\" 一条——\n"
  "#        父版身份自洽闸：YAML registry.parent.version 须等于 VRD$parent_version（v1.5.002 之 parent 曾指祖父 v1.5.0，\n"
  "#        R04 只检非空故未捕）。R01–R25 与 R24b 之判定逻辑与文字一字未改（只增不减）。裁定：Ryo Eng 2026-09-03。\n"),
 ("# 对象 : registry_risk_typology_v1.5.002.{yaml,csv}  （父版 v1.5.001 为对照锚）\n",
  "# 对象 : registry_risk_typology_v1.5.003.{yaml,csv}  （父版 v1.5.002 为对照锚）\n"),
 ('  version        = "1.1.0",\n  target_version = "1.5.002",\n  parent_version = "1.5.001",\n'
  '  yaml_path      = "规范/registry_risk_typology_v1.5.002.yaml",\n  csv_path       = "规范/registry_risk_typology_v1.5.002.csv",\n'
  '  parent_yaml    = "规范/registry_risk_typology_v1.5.001.yaml",\n  parent_csv     = "规范/registry_risk_typology_v1.5.001.csv",\n',
  '  version        = "1.2.0",\n  target_version = "1.5.003",\n  parent_version = "1.5.002",\n'
  '  yaml_path      = "规范/registry_risk_typology_v1.5.003.yaml",\n  csv_path       = "规范/registry_risk_typology_v1.5.003.csv",\n'
  '  parent_yaml    = "规范/registry_risk_typology_v1.5.002.yaml",\n  parent_csv     = "规范/registry_risk_typology_v1.5.002.csv",\n'),
 ('      paste(Y$registry$parent$version, Y$registry$parent$yaml_md5), "非空", "1 档")\n',
  '      paste(Y$registry$parent$version, Y$registry$parent$yaml_md5), "非空", "1 档")\n'
  '  ## R04b（1.2.0 新增 · Ryo Eng 2026-09-03 裁定）：父版身份自洽——R04 只检 md5 非空，v1.5.002 之 parent 指祖父 v1.5.0 而未捕\n'
  '  .pv <- if (is.null(Y$registry$parent$version)) "(缺)" else as.character(Y$registry$parent$version)\n'
  '  chk("R04b", "父版身份自洽：YAML registry.parent.version 须等于校验器 VRD$parent_version",\n'
  '      if (identical(.pv, VRD$parent_version)) "PASS" else "FAIL",\n'
  '      .pv, VRD$parent_version, "1 档",\n'
  '      "祖父锚冒充父锚即血统断裂：md5 非空 ≠ 指向正确；本闸与 R03（自身版本）成对，父子两端皆须对上校验器常量")\n'),
])

# ── 5. 配置册 1.3.0 ──
edit("配置/report_config_v1.0.0.yaml", [
 ("  version: 1.2.0\n  issued: '2026-09-03'\n  parent: registry_risk_typology_v1.5.002\n  changelog_1_2_0:",
  "  version: 1.3.0\n  issued: '2026-09-03'\n  parent: registry_risk_typology_v1.5.003\n"
  "  changelog_1_3_0: N-3（2026-09-03）——parent 改指 v1.5.003（头块补正版）。namespaces、阈值、分位、管线、名册一字未改。\n"
  "  changelog_1_2_0:"),
])
print("cascade done")
