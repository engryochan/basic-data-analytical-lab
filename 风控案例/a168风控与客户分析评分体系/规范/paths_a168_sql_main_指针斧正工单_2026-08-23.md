# `配置/paths_a168.R` · `sql_main` 指针斧正工单

**优先级**：**最高** —— 高于 `审计/G4G5_注释纠错_diff_2026-08-23.md` 之产出。
理由（承 REDTEAM 裁示）：diff 文档只是**审计记录**；`sql_main` 错指则是**当前执行血统仍然错误** —— `registry_load()` 之 `sql_section` 栏所指章节**无法回溯原文**，登记册之证据链就此断在源头。

---

## 一、缺陷

已实测在册之警告：

```
【registry】未在 函数/a168_取数与核验_SQL总包_v10.sql 找到 SQL 总包
          ——登记册 sql_section 栏所指章节将无法回溯原文
```

**双错**：

| 维度 | 现况 | 应为 |
|:--|:--|:--|
| **路径** | `函数/`（Execution 命名空间） | **项目根** |
| **版本** | `v10` | **v11** |

依五命名空间（SC-15）：Delivery `数据库/`｜Execution `函数/`｜Specification `规范/`｜Configuration `配置/`｜Audit `审计/`，而 **SQL 总包居项目根**。`函数/` 只存 `.R` 与 `R03b_source.sql`。

---

## 二、补丁

`配置/paths_a168.R` 之 `REGISTRY_PATHS` 常量段（现于第 51–52 行邻近，落地前请以现文核对行号）：

```r
## ── 斧正前（路径与版本双错）────────────────────────────────────────────────
# sql_main = file.path("函数", "a168_取数与核验_SQL总包_v10.sql")

## ── 斧正后（2026-08-23）────────────────────────────────────────────────────
## 依五命名空间（SC-15）：SQL 总包居**项目根**，非 函数/。
## 函数/ 只存 .R 与 R03b_source.sql；此处曾错指 函数/ 且滞留 v10，
## 致 registry_load() 之 sql_section 回溯断链（实测警告在册）。
sql_main = file.path(PROJ_ROOT, "a168_取数与核验_SQL总包_v11.sql"),
```

若 `paths_a168.R` 尚无 `PROJ_ROOT` 常量，一并补：

```r
## 项目根：一切相对路径之锚。禁在他处另立同义常量（一处定义、余处引用）。
PROJ_ROOT <- normalizePath(".", winslash = "/", mustWork = TRUE)
```

---

## 三、验收序（顺序不可颠倒）

```r
## ① 槽位自检：八槽位＋四工具，全 TRUE 方续
p_verify()

## ② 载入登记册：YAML↔CSV 配对断言会自行把关；若不配对即 STOP
REG <- registry_load()

## ③ 回溯实证：sql_section 所指章节须能取到原文
##    以任一在册章节验之（例：T-03 之 sql_section）
sec <- REG$dict[type_id == "T-03", unique(sql_section)]
stopifnot("sql_section 须非空" = length(sec) > 0L && !is.na(sec[1]))

## ④ 血统实证：读到的须是项目根之 v11，不得是 函数/ 之 v10
sql_path <- REGISTRY_PATHS$sql_main
cat("实际读取：", sql_path, "\n")
stopifnot(
  "须居项目根，非 函数/" = !grepl("^函数/|/函数/", sql_path),
  "须为 v11，非 v10"     = grepl("v11", sql_path, fixed = TRUE),
  "档须在位"             = file.exists(sql_path))

## ⑤ 六元组核对：与在册登记逐项对上，缺一不可
d <- readBin(sql_path, "raw", file.info(sql_path)$size)
cat(sprintf("行(CRLF) %d | 字节 %d | MD5(原样) %s\n",
            sum(d == as.raw(10)), length(d),
            digest::digest(d, algo = "md5", serialize = FALSE)))
```

**判读**：④ 之三条断言任一 STOP，即证指针未真正生效——须回查是否另有硬编码路径绕过了常量（`make_export_params.R` 之第 40–41 行系默认参数，**是覆盖器唯一管不到的缺口**，须一并核）。

---

## 四、随迁并核（三处）

| 序 | 对象 | 须核 |
|--:|:--|:--|
| 1 | `函数/registry_loader.R` | 常量（约第 92 行）仍指 `数据库/…v1.3.0`；须改指 `规范/…v1.5.0`（点号体例） |
| 2 | `函数/glossary_engine.R` | 常量（约第 32 行）仍指 `数据库/`；须改指 `规范/` |
| 3 | `函数/make_export_params.R` | **无集中式常量**，路径写在第 40–41 行默认参数；须引入常量或显式传参 |

**`函数/R03b_cc_verifier.R` 保持不动** —— R03b 证据属 Delivery，覆盖器已明令不得搬迁。

---

## 五、完成后方可续办

1. ✅ 本工单（`sql_main` 指针）
2. → `审计/G4G5_注释纠错_diff_2026-08-23.md` 归位
3. → v12 施工时逐条吸收 D01–D07

**v10 只归档、不删除、不运行。**
