# ==============================================================================
# starrocks_bulk_export.R
# 批量导出 StarRocks 某个 schema 下所有表，打包成一个zip
#
# 使用前准备（在自己电脑上做，不要把密码写进这份脚本或提交进Git）：
#   1. 在 ~/.Renviron 里加一行（注意不要有多余空格）：
#        WMDATUM_PWD=你的真实密码
#      保存后重启R session让环境变量生效
#   2. 确认主机名对应的端口——StarRocks MySQL协议查询端口默认是9030，
#      如果 ss.wmdatum.xyz 走的是反向代理/自定义端口，请找运维确认，
#      下面 PORT 先填9030占位，不对请自行改
# ==============================================================================

library(DBI)
library(RMariaDB)   # StarRocks兼容MySQL协议，用RMariaDB驱动连接
library(data.table)

HOST   <- "ss.wmdatum.xyz"
PORT   <- 9030                       # ← 请核实实际端口，不一定是这个
USER   <- "ryochan"
PWD    <- Sys.getenv("WMDATUM_PWD")  # 从环境变量读取，不写死在脚本里
SCHEMA <- "ods_mariadb_2b"
DBNAME <- "StarRocks-readonly"       # 若这是catalog名而非database名，连接时可能需要调整

if (PWD == "") {
  stop("环境变量 WMDATUM_PWD 未设置，请先在 ~/.Renviron 里配置好密码再运行")
}

con <- dbConnect(
  RMariaDB::MariaDB(),
  host = HOST, port = PORT, user = USER, password = PWD,
  dbname = SCHEMA
)

# ------------------------------------------------------------------
# 第一步：查该schema下所有表名（用information_schema，不手动列清单，
#         避免漏表或表名打错）
# ------------------------------------------------------------------
table_list <- dbGetQuery(con, sprintf(
  "SELECT table_name FROM information_schema.tables WHERE table_schema = '%s'", SCHEMA
))$table_name

cat(sprintf("在 %s 下发现 %d 张表:\n", SCHEMA, length(table_list)))
print(table_list)

# ------------------------------------------------------------------
# 第二步：检查会话是否有默认查询行数上限（StarRocks常见的
#         sql_select_limit变量），"允许的最大观测量"很可能就是指这个——
#         先查出来打印，不要盲目假设是多少
# ------------------------------------------------------------------
select_limit <- tryCatch({
  dbGetQuery(con, "SHOW VARIABLES LIKE 'sql_select_limit'")
}, error = function(e) NULL)
print(select_limit)
# 如果显示的不是一个很大的数（比如默认值可能是无限制或很大的正整数），
# 建议在导出前先在会话里执行：
#   dbExecute(con, "SET sql_select_limit = 9223372036854775807")
# 确保导出时不会被会话级限制悄悄截断（这跟我们之前反复强调的
# "候选表被排序截断"问题是同一类坑，务必先查清楚再导，不要导完了
# 才发现每张表都被默默截了断）

# ------------------------------------------------------------------
# 第三步：逐表导出为CSV，落在一个临时目录
# ------------------------------------------------------------------
export_dir <- file.path(getwd(), "starrocks_export_ods_mariadb_2b")
dir.create(export_dir, showWarnings = FALSE, recursive = TRUE)

export_log <- data.table(表名 = character(), 行数 = integer(), 状态 = character())

for (tbl in table_list) {
  result <- tryCatch({
    df <- dbGetQuery(con, sprintf("SELECT * FROM `%s`", tbl))
    fwrite(df, file.path(export_dir, paste0(tbl, ".csv")))
    list(rows = nrow(df), status = "成功")
  }, error = function(e) {
    message(sprintf("[导出失败] %s: %s", tbl, conditionMessage(e)))
    list(rows = NA_integer_, status = paste("失败:", conditionMessage(e)))
  })
  export_log <- rbind(export_log, data.table(表名 = tbl, 行数 = result$rows, 状态 = result$status))
}

print(export_log)
fwrite(export_log, file.path(export_dir, "_导出日志.csv"))

dbDisconnect(con)

# ------------------------------------------------------------------
# 第四步：打包成一个zip
# ------------------------------------------------------------------
zip_path <- file.path(getwd(), paste0("ods_mariadb_2b_导出_", format(Sys.Date(), "%Y%m%d"), ".zip"))
zip::zip(zip_path, files = list.files(export_dir, full.names = TRUE), mode = "cherry-pick")
cat(sprintf("打包完成: %s\n", zip_path))
