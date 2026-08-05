library(shiny)
library(shinydashboard)
library(data.table)
library(ggplot2)
library(plotly)
library(igraph)
library(DT)
library(lubridate)

# 读取 - 请把4个csv和本文件放在同一个英文路径下，不要有中文空格
pair_stat <- fread("C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/player_pair_stat.csv", encoding="UTF-8")
dealer_stat <- fread("C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/dealer_profit_stat.csv", encoding="UTF-8")
pair_hourly <- fread("C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/player_pair_stat_hourly.csv", encoding="UTF-8")
dealer_hourly <- fread("C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/dealer_profit_stat_hourly.csv", encoding="UTF-8")
