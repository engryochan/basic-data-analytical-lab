# global.R
library(shiny)
library(shinydashboard)
library(data.table)
library(ggplot2)
library(DT)
library(networkD3)
library(scales)          # 用于安全格式化数字
library(dplyr)
library(tidyr)

# 设置选项，避免科学计数法
options(scipen = 999)
options(digits = 4)
options(shiny.sanitize.errors = TRUE)

# ---------- 数据加载函数 ----------
load_data <- function() {
  # 尝试读取 CSV 文件（如果存在）
  data_path <- "C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/"
  if (dir.exists(data_path) && 
      all(c("dealer_profit_stat.csv", "dealer_profit_stat_hourly.csv", "player_pair_stat.csv", "player_pair_stat_hourly.csv") %in% list.files(data_path))) {
    
    message("从 CSV 文件加载真实数据...")
    dealer_stat <- fread(file.path(data_path, "dealer_profit_stat.csv"))
    dealer_hourly <- fread(file.path(data_path, "dealer_profit_stat_hourly.csv"))
    pair_stat <- fread(file.path(data_path, "player_pair_stat.csv"))
    pair_hourly <- fread(file.path(data_path, "player_pair_stat_hourly.csv"))
    
    return(list(
      dealer_stat = dealer_stat,
      dealer_hourly = dealer_hourly,
      pair_stat = pair_stat,
      pair_hourly = pair_hourly
    ))
  } else {
    # 否则生成模拟数据
    message("未找到 CSV 文件，使用模拟数据...")
    set.seed(2026)
    
    # 玩家对汇总表（500 对）
    n_pairs <- 500
    player_ids <- sample(1:50000, n_pairs * 2, replace = TRUE)
    player_a <- player_ids[1:n_pairs]
    player_b <- player_ids[(n_pairs+1):(2*n_pairs)]
    for (i in 1:n_pairs) {
      if (player_a[i] > player_b[i]) {
        tmp <- player_a[i]; player_a[i] <- player_b[i]; player_b[i] <- tmp
      }
    }
    pair_stat <- data.table(
      player_a = player_a,
      player_b = player_b,
      same_round_count = rpois(n_pairs, lambda = 15) + 1,
      player_a_rounds = rpois(n_pairs, lambda = 50) + 10,
      player_b_rounds = rpois(n_pairs, lambda = 50) + 10,
      same_rate = runif(n_pairs, 0.01, 0.6),
      first_game_time = as.POSIXct("2026-05-01") + runif(n_pairs, 0, 60*60*24*30),
      last_game_time = as.POSIXct("2026-06-01") + runif(n_pairs, 0, 60*60*24*30)
    )
    pair_stat[, `:=`(created_time = Sys.time() - runif(.N, 0, 60*60*24*30),
                     update_time = Sys.time() - runif(.N, 0, 60*60*24*10))]
    
    # 荷官玩家汇总表（300 条）
    n_dealer <- 300
    dealer_stat <- data.table(
      dealer_id = sample(1:50, n_dealer, replace = TRUE),
      game_id = sample(101:105, n_dealer, replace = TRUE),
      player_id = sample(1:50000, n_dealer, replace = FALSE),
      bet_count = rpois(n_dealer, lambda = 100) + 1,
      valid_bet = round(runif(n_dealer, 100, 100000), 2),
      turnover = round(runif(n_dealer, 100, 120000), 2),
      profit = round(rnorm(n_dealer, mean = 0, sd = 5000), 2),
      win_count = rpois(n_dealer, lambda = 30),
      lose_count = rpois(n_dealer, lambda = 30),
      push_count = rpois(n_dealer, lambda = 5),
      win_rate = runif(n_dealer, 0.2, 0.8),
      player_roi = runif(n_dealer, -0.5, 0.8)
    )
    dealer_stat[, profit_per_bet := profit / bet_count]
    dealer_stat[, `:=`(first_bet_time = as.POSIXct("2026-05-01") + runif(.N, 0, 60*60*24*30),
                       last_bet_time = as.POSIXct("2026-06-01") + runif(.N, 0, 60*60*24*30),
                       created_time = Sys.time() - runif(.N, 0, 60*60*24*30),
                       update_time = Sys.time() - runif(.N, 0, 60*60*24*10))]
    
    # 荷官小时快照（模拟 6 天数据）
    hours <- seq(as.POSIXct("2026-05-15 00:00:00"), as.POSIXct("2026-05-20 23:00:00"), by = "hour")
    dealer_hourly <- rbindlist(lapply(hours, function(h) {
      nd <- sample(1:20, 1)
      dt <- data.table(
        stat_date = as.Date(h),
        stat_hour = as.integer(format(h, "%H")),
        dealer_id = sample(1:50, nd, replace = FALSE),
        game_id = sample(101:105, nd, replace = TRUE),
        player_id = sample(1:50000, nd, replace = FALSE),
        bet_count = rpois(nd, lambda = 10) + 1,
        valid_bet = round(runif(nd, 10, 5000), 2),
        turnover = round(runif(nd, 10, 6000), 2),
        profit = round(rnorm(nd, mean = 0, sd = 200), 2),
        round_count = rpois(nd, lambda = 5) + 1,
        win_count = rpois(nd, lambda = 3),
        lose_count = rpois(nd, lambda = 3),
        push_count = rpois(nd, lambda = 1),
        win_rate = runif(nd, 0.2, 0.8),
        player_roi = runif(nd, -0.5, 0.8)
      )
      dt[, profit_per_bet := profit / bet_count]
      dt[, `:=`(first_bet_time = h + runif(.N, 0, 3600),
                last_bet_time = h + runif(.N, 0, 3600),
                created_time = Sys.time(),
                update_time = Sys.time())]
      return(dt)
    }))
    
    # 玩家对小时快照
    pair_hourly <- rbindlist(lapply(hours, function(h) {
      np <- sample(1:30, 1)
      dt <- data.table(
        stat_date = as.Date(h),
        stat_hour = as.integer(format(h, "%H")),
        player_a = sample(1:50000, np, replace = FALSE),
        player_b = sample(1:50000, np, replace = FALSE),
        same_round_count = rpois(np, lambda = 5) + 1,
        first_game_time = h + runif(np, 0, 3600),
        last_game_time = h + runif(np, 0, 3600)
      )
      for (i in 1:np) {
        if (dt[i, player_a] > dt[i, player_b]) {
          tmp <- dt[i, player_a]; dt[i, player_a] <- dt[i, player_b]; dt[i, player_b] <- tmp
        }
      }
      dt[, `:=`(created_time = Sys.time(), update_time = Sys.time())]
      return(dt)
    }))
    
    return(list(
      dealer_stat = dealer_stat,
      dealer_hourly = dealer_hourly,
      pair_stat = pair_stat,
      pair_hourly = pair_hourly
    ))
  }
}

# 执行数据加载
data_list <- load_data()
dealer_stat <- data_list$dealer_stat
dealer_hourly <- data_list$dealer_hourly
pair_stat <- data_list$pair_stat
pair_hourly <- data_list$pair_hourly
