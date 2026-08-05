## ============================================================
## 荷官玩家风控 —— 00. 全局 ODS 数据字典解析与下载脚本
## 用途: 本脚本必须在您本机 Positron/RStudio 环境执行（需要真实互联网权限）。
##
## 【重要说明 / 关键限制披露】
## 在 Claude 的沙盒环境中，web_fetch 工具对该字典 CSV 的抓取存在硬性截断上限
## （无论设置多大的 token 上限，均在同一处 "ods_a168_game_type" 附近截断），
## 因此 Claude 只验证到了约60张表（RedPacketSetup ... game_type，按字母序）
## 的一字不漏字段清单，无法看到该 ODS 字典的全部内容（推测还有更多以
## h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z 开头的表，以及可能存在的其他
## TABLE_SCHEMA）。这不是偷懒，而是工具的真实技术边界：Claude 没有办法在
## 沙盒里用 wget/curl 下载（网络已禁用），只能通过 web_fetch 取得网页文本，
## 而网页文本又有长度上限。此脚本就是为了在您本机把"全局"两个字做实。
##
## 本脚本会：
##   1) 用 R 原生 download.file()/httr 在您本机完整下载字典 CSV（无截断问题）
##   2) 解析全部 TABLE_SCHEMA / TABLE_NAME / COLUMN_NAME / COLUMN_COMMENT
##   3) 按"顶级博彩公司风控视角"用程序化规则(而非人工肉眼列举)将全部表分类到
##      维度域，保证一字不漏覆盖字典里的每一张表、每一个字段
##   4) 针对荷官/桌台/会员/风控关键表，尝试下载对应的实际数据文件
##      （URL 命名规律请见下方 TODO：由于 Claude 未能在字典之外发现任何一个
##      真实数据文件的URL，此处需要您确认实际数据表的存放路径/文件名规律，
##      或直接在 GitHub 网页上打开该 repo 该 branch 下的资料夹确认）
## ============================================================

pkgs <- c("httr", "readr", "dplyr", "stringr", "purrr", "tidyr")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) {
    tryCatch(install.packages(p, repos = "https://cloud.r-project.org"),
             error = function(e) message(sprintf("[警告] %s 安装失败: %s", p, conditionMessage(e))))
  }
}
suppressPackageStartupMessages({
  library(httr); library(readr); library(dplyr); library(stringr); library(purrr); library(tidyr)
})

## -------------------------------------------------------------
## 1) 完整下载字典（您本机执行，无 token/长度截断问题）
## -------------------------------------------------------------
DICT_URL <- paste0(
  "https://media.githubusercontent.com/media/engryochan/",
  "basic-data-analytical-lab/refs/heads/",
  "%E4%B8%96%E5%8D%9A%E9%87%8F%E5%8C%96%E7%A0%94%E7%A9%B6%E9%99%A2/",
  "%E9%A3%8E%E6%8E%A7%E6%A1%88%E4%BE%8B/%E5%AD%97%E5%85%B8/",
  "00_ODS_GLOBAL_DATA_DICTIONARY.csv"
)

local_dict_path <- "00_ODS_GLOBAL_DATA_DICTIONARY.csv"
resp <- GET(DICT_URL, write_disk(local_dict_path, overwrite = TRUE), progress())
stop_for_status(resp)
message(sprintf("字典已完整下载至本机: %s (%.1f KB)",
                normalizePath(local_dict_path), file.info(local_dict_path)$size / 1024))

dict <- read_csv(local_dict_path, locale = locale(encoding = "UTF-8"), show_col_types = FALSE)
message(sprintf("字典解析完成：共 %d 张表 (TABLE_NAME distinct)，%d 行字段定义。",
                n_distinct(dict$TABLE_NAME), nrow(dict)))
message("若此表数远大于Claude沙盒中验证到的约60张，即证实了上述截断限制推断。")

## -------------------------------------------------------------
## 2) 程序化维度分类 —— "顶级博彩公司"式全维度归类，规则驱动、一字不漏
##    （用正则/关键词规则做分类，而非人工列举，保证覆盖字典里的每一张表）
## -------------------------------------------------------------
classify_domain <- function(table_name, comments) {
  tn <- str_to_lower(table_name)
  cm <- str_c(comments, collapse = " ")
  dplyr::case_when(
    str_detect(tn, "bet0?1|bet0?2|^ods_a168_bet$|betchange") ~ "01_投注与注单域(Bet & Wager)",
    str_detect(tn, "game_info|game_result|game_no|game_statistics|game_type|game_tip|game_transfer") ~ "02_对局与结果域(Game Round & Result)",
    str_detect(tn, "dailyreport") ~ "03_日汇总报表域(Daily Aggregated Report)",
    str_detect(tn, "employee|emp_login|control(_login)?") ~ "04_员工与荷官域(Employee/Dealer)",
    str_detect(tn, "agent") ~ "05_代理层级域(Agent Hierarchy)",
    str_detect(tn, "categor") ~ "06_会员分级与限额域(Member Tier & Limits)",
    str_detect(tn, "redpacket") ~ "07_营销活动_红包域(Promotion-RedPacket)",
    str_detect(tn, "aggregate_") ~ "08_三方钱包聚合结算域(Aggregator Wallet)",
    str_detect(tn, "alarm|alert|change_log|betchange_log") ~ "09_异常与稽核日志域(Alert & Audit Log)",
    str_detect(tn, "currency|conversion|ctl_rto") ~ "10_货币与码房转换域(Currency/Chip Conversion)",
    str_detect(tn, "^ods_a168_age_") ~ "11_代理登入日志域(Agent Login Log)",
    str_detect(tn, "game_log") ~ "12_客户端会话与地理位置域(Session/Geo Log)",
    str_detect(tn, "apiurl|callwebapi|api") ~ "13_系统API配置域(System API Config)",
    str_detect(tn, "ban_bet_area|bet_limit") ~ "14_限红与限注规则域(Bet Limit Rule)",
    TRUE ~ "99_其他系统配置域(Other System Config)"
  )
}

table_summary <- dict %>%
  group_by(TABLE_SCHEMA, TABLE_NAME) %>%
  summarise(
    字段数 = n(),
    关键字段样例 = paste(head(COLUMN_NAME, 6), collapse = ", "),
    备注摘要 = paste(head(na.omit(COLUMN_COMMENT[COLUMN_COMMENT != ""]), 3), collapse = " | "),
    .groups = "drop"
  ) %>%
  mutate(维度域 = classify_domain(TABLE_NAME, 备注摘要)) %>%
  arrange(维度域, TABLE_NAME)

write_csv(table_summary, "01_全表维度分类清单.csv")
message(sprintf("已生成全表维度分类清单 -> 01_全表维度分类清单.csv (%d 张表)", nrow(table_summary)))
print(table_summary %>% count(维度域, sort = TRUE))

## -------------------------------------------------------------
## 3) 荷官/桌台/会员/风控 核心风控相关表 —— 抽出供后续合并分析
## -------------------------------------------------------------
core_risk_tables <- c(
  "ods_a168_bet01", "ods_a168_bet02", "ods_a168_bet",
  "ods_a168_game_info", "ods_a168_game_statistics",
  "ods_a168_employee", "ods_a168_category", "ods_a168_categoryLevel",
  "ods_a168_dailyreport_table", "ods_a168_dailyreport_member",
  "ods_a168_dailyreport2", "ods_a168_betchange_log"
)
core_fields <- dict %>% filter(TABLE_NAME %in% core_risk_tables) %>%
  select(TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT)
write_csv(core_fields, "02_风控核心表字段一字不漏清单.csv")
message("已生成核心风控表逐字段清单 -> 02_风控核心表字段一字不漏清单.csv")

## -------------------------------------------------------------
## 4) 实际数据表下载 —— 需要您确认路径规律 (TODO)
## -------------------------------------------------------------
## Claude 在其沙盒中，只被您提供了字典CSV这一个URL；根据工具的URL使用限制
## （不允许把已知URL的路径片段自行编造替换后去抓取未曾出现过的新URL），
## Claude 无法凭空构造出 ods_a168_bet01 等实际数据文件的下载路径。
##
## 建议您用以下两种方式之一，把真实路径补进下面的 vector，本脚本即可批量下载：
##   方式A: 打开 https://github.com/engryochan/basic-data-analytical-lab
##          切到分支 "/风控案例"，进入对应资料夹查看真实档名
##   方式B: 若数据表与字典同目录，很可能遵循近似档名规律，例如：
##          .../风控案例/数据/ods_a168_bet01.csv (供您核对是否属实)
##
## data_table_urls <- c(
##   "ods_a168_bet01" = "<请替换为您确认后的真实URL>",
##   "ods_a168_bet02" = "<请替换为您确认后的真实URL>",
##   "ods_a168_game_info" = "<请替换为您确认后的真实URL>",
##   "ods_a168_game_statistics" = "<请替换为您确认后的真实URL>",
##   "ods_a168_employee" = "<请替换为您确认后的真实URL>",
##   "ods_a168_dailyreport_table" = "<请替换为您确认后的真实URL>"
## )
##
## for (nm in names(data_table_urls)) {
##   dest <- sprintf("raw_%s.csv", nm)
##   tryCatch({
##     GET(data_table_urls[[nm]], write_disk(dest, overwrite = TRUE))
##     message(sprintf("下载完成: %s -> %s", nm, dest))
##   }, error = function(e) message(sprintf("[失败] %s: %s", nm, conditionMessage(e))))
## }

## -------------------------------------------------------------
## 5) 与本地已有全量候选同桌数据合并（此文件是唯一已确认的全量数据）
## -------------------------------------------------------------
pair_path <- "pair_data.csv"
if (file.exists(pair_path)) {
  pairs <- read_csv(pair_path, show_col_types = FALSE)
  message(sprintf("本地全量候选同桌数据: %d 行 (uid1,uid2,总同桌局数)，可直接喂给 app_shiny.R", nrow(pairs)))
} else {
  message("未在当前目录找到 pair_data.csv，请先从项目文件复制。")
}

message("\n脚本执行完毕。若要把 ods_a168_bet01/bet02/game_info/game_statistics 等表\n",
        "真正并入风控引擎（而不只是同桌配对候选表），下一步是在第4节补上真实URL后重跑，\n",
        "再于 risk_engine.py / app_shiny.R 中加入『荷官eid × 桌号bet31/bet39 × 会员mid』\n",
        "维度的合并逻辑，把荷官侧、金额侧字段也纳入综合风险分。")
