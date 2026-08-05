# ============================================================
# 一键运行闪霓应用 - 真人风控鲜明版
# 自动安装依赖、加载数据、启动 Shiny
# ============================================================

# ---- 自动安装缺失包 ----
packages <- c("shiny", "shinydashboard", "DT", "plotly", "data.table")
to_install <- packages[!packages %in% installed.packages()[, "Package"]]
if (length(to_install)) install.packages(to_install)

library(shiny)
library(shinydashboard)
library(DT)
library(plotly)
library(data.table)

# ---- 数据加载函数（兼容真实/模拟） ----
load_or_mock <- function() {
  # 真实数据路径（可修改）
  base_path <- "C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库"
  pair_file <- file.path(base_path, "player_pair_stat.csv")
  dealer_file <- file.path(base_path, "dealer_profit_stat.csv")
  pair_hourly_file <- file.path(base_path, "player_pair_stat_hourly.csv")
  dealer_hourly_file <- file.path(base_path, "dealer_profit_stat_hourly.csv")
  
  if (file.exists(pair_file) && file.exists(dealer_file)) {
    message("✅ 加载真实 CSV 数据...")
    pair_stat <- fread(pair_file, encoding = "UTF-8", fill = TRUE)
    dealer_stat <- fread(dealer_file, encoding = "UTF-8", fill = TRUE)
    pair_hourly <- fread(pair_hourly_file, encoding = "UTF-8", fill = TRUE)
    dealer_hourly <- fread(dealer_hourly_file, encoding = "UTF-8", fill = TRUE)
  } else {
    message("⚠️ 未找到真实 CSV，使用模拟数据...")
    set.seed(273467)
    # 模拟 player_pair_stat
    pair_stat <- data.table(
      player_a = rep(273467, 100),
      player_b = c(3163098, 68520182, sample(1000000:99999999, 98, replace = FALSE)),
      same_round_count = c(85, 3, sample(1:40, 98, replace = TRUE)),
      player_a_rounds = c(191, 8, sample(20:200, 98, replace = TRUE)),
      player_b_rounds = c(4329, 8, sample(20:200, 98, replace = TRUE)),
      same_rate = c(0.445, 0.375, runif(98, 0.05, 0.35)),
      first_game_time = as.POSIXct("2026-05-22 00:00:00") + runif(100, 0, 60*60*24*30),
      last_game_time = as.POSIXct("2026-06-22 00:00:00") + runif(100, 0, 60*60*24*20)
    )
    # 模拟 dealer_stat
    dealer_stat <- data.table(
      player_id = c(21426027, 30694457, sample(1000000:99999999, 98, replace = FALSE)),
      dealer_id = rep(-1, 100),
      profit = c(274800, 150000, rnorm(98, 50000, 80000)),
      win_rate = c(0.625, 1.0, runif(98, 0.45, 0.7)),
      player_roi = c(1.317, 0.958, runif(98, -0.1, 0.6)),
      bet_count = sample(20:300, 100, replace = TRUE)
    )
    # 模拟小时表（24小时）
    pair_hourly <- data.table(
      stat_date = as.Date("2026-05-15"),
      stat_hour = 0:23,
      same_round_count = c(rep(5,5), 23, rep(8,17), 5)
    )
    dealer_hourly <- data.table(
      stat_date = as.Date("2026-05-15"),
      stat_hour = 0:23,
      profit = c(rnorm(22, 10000, 50000), -620, 274800),
      player_roi = runif(24, -0.2, 0.5)
    )
  }
  
  # ---- 统一派生字段（确保所有必需列存在） ----
  # player_pair_stat 派生
  if (!"total_round_a" %in% names(pair_stat)) {
    if ("player_a_rounds" %in% names(pair_stat)) {
      pair_stat[, total_round_a := player_a_rounds]
    } else if ("player_a_rounds" %in% names(pair_stat)) {
      pair_stat[, total_round_a := player_a_rounds]
    } else {
      pair_stat[, total_round_a := same_round_count + sample(10:100, .N, replace = TRUE)]
    }
  }
  # 计算 days_active (首次到最近天数)
  if (!"days_active" %in% names(pair_stat)) {
    if ("first_game_time" %in% names(pair_stat) && "last_game_time" %in% names(pair_stat)) {
      pair_stat[, days_active := as.numeric(difftime(last_game_time, first_game_time, units = "days"))]
    } else {
      pair_stat[, days_active := runif(.N, 1, 60)]
    }
  }
  # 计算 recency_days (距今天数)
  if (!"recency_days" %in% names(pair_stat)) {
    if ("last_game_time" %in% names(pair_stat)) {
      pair_stat[, recency_days := as.numeric(difftime(Sys.time(), last_game_time, units = "days"))]
    } else {
      pair_stat[, recency_days := sample(1:60, .N, replace = TRUE)]
    }
  }
  
  # 风险等级与评分
  pair_stat[, risk_tier := fifelse(same_rate >= 0.30, "L4-实锤",
                                   fifelse(same_rate >= 0.15, "L3-高危",
                                           fifelse(same_rate >= 0.05, "L2-可疑", "L1-正常")))]
  # 计算 risk_score_v2（处理 scale 可能返回矩阵）
  rate_sd <- sd(pair_stat$same_rate, na.rm = TRUE)
  if (is.na(rate_sd) || rate_sd == 0) rate_sd <- 0.1
  pair_stat[, risk_score_v2 := 0.5 * (same_rate - mean(same_rate, na.rm = TRUE)) / rate_sd +
              0.3 * log1p(same_round_count) / max(log1p(same_round_count), na.rm = TRUE) +
              0.2 * exp(-recency_days / 7)]
  pair_stat[, risk_score_v2 := round(as.numeric(risk_score_v2), 3)]
  setorder(pair_stat, -risk_score_v2)
  
  # dealer_stat 确保有 player_roi
  if (!"player_roi" %in% names(dealer_stat)) {
    dealer_stat[, player_roi := profit / bet_count]  # 简单估计
  }
  
  # 最优基准
  opt_rate <- 0.02
  opt_roi <- -0.035
  list(pair = pair_stat, dealer = dealer_stat,
       ph = pair_hourly, dh = dealer_hourly,
       opt_rate = opt_rate, opt_roi = opt_roi)
}

# ---- 加载数据 ----
data_list <- load_or_mock()
pair_stat <- data_list$pair
dealer_stat <- data_list$dealer
pair_hourly <- data_list$ph
dealer_hourly <- data_list$dh
OPT_RATE <- data_list$opt_rate
OPT_ROI <- data_list$opt_roi

# 自适应日期范围
if ("first_game_time" %in% names(pair_stat)) {
  min_date <- min(pair_stat$first_game_time, na.rm = TRUE)
  max_date <- max(pair_stat$last_game_time, na.rm = TRUE)
} else {
  min_date <- Sys.Date() - 30
  max_date <- Sys.Date()
}

# ---- UI ----
ui <- dashboardPage(
  dashboardHeader(title = "真人风控 - 鲜明版 PRO", titleWidth = 250),
  dashboardSidebar(
    width = 250,
    selectInput("tier_filter", "风险等级筛选",
                choices = c("全部", "L4-实锤", "L3-高危", "L2-可疑", "L1-正常"),
                selected = "全部"),
    sliderInput("rate_filter", "同桌率阈值", min = 0, max = 0.5,
                value = 0.05, step = 0.01),
    sliderInput("ma_window", "均线MA窗口", min = 3, max = 30,
                value = 7, step = 1),
    selectInput("granularity", "时计/日计",
                choices = c("时计 Hourly", "日计 Daily"),
                selected = "时计 Hourly"),
    dateRangeInput("date_range", "日期范围",
                   start = min_date, end = max_date),
    hr(),
    helpText("背景 #0B1220, 指标纯白+霓虹边框, 对比度>15:1")
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML("
        body, .content-wrapper { background-color: #0B1220 !important; color: #F8FAFC; }
        .vivid-kpi { background: #FFFFFF !important; border-radius: 12px; padding: 14px; margin-bottom: 12px; border-left: 8px solid #FF1744; box-shadow: 0 4px 15px rgba(0,0,0,0.4); color: #0F172A !important; }
        .vivid-kpi h3 { color: #0F172A !important; font-weight: 900; font-size: 28px; margin: 0; }
        .vivid-kpi p { color: #334155 !important; font-weight: 700; font-size: 14px; margin: 0; }
        .vivid-kpi.l4 { border-left-color: #FF1744 !important; background: #FFF0F3 !important; }
        .vivid-kpi.l3 { border-left-color: #FF9100 !important; background: #FFF7ED !important; }
        .vivid-kpi.l2 { border-left-color: #FFEA00 !important; background: #FFFEF0 !important; }
        .vivid-kpi.l1 { border-left-color: #00E676 !important; background: #F0FFF4 !important; }
        .vivid-kpi.dealer { border-left-color: #7C4DFF !important; background: #F5F0FF !important; }
        .vivid-kpi.profit { border-left-color: #00B0FF !important; background: #F0F9FF !important; }
        .alert-blink { animation: blinker 1s linear infinite; background: #FF1744 !important; color: #FFFFFF !important; font-weight: 900; padding: 12px; border-radius: 8px; font-size: 16px; text-align: center; border: 3px solid #FFFFFF; }
        @keyframes blinker { 50% { opacity: 0.3; } }
        .dataTables_wrapper { color: #0F172A; }
        .box { background: #FFFFFF !important; border-top: 4px solid #00B0FF !important; }
        .box-header { color: #0F172A !important; font-weight: 800; }
        .box-body { color: #0F172A !important; }
        .explain-card { background: #FFFFFF; border: 2px solid #E2E8F0; border-radius: 10px; padding: 16px; margin-bottom: 12px; color: #0F172A; }
        .explain-card .label { display: inline-block; padding: 3px 10px; border-radius: 20px; font-weight: 900; color: white; margin-right: 8px; }
        .label-l4 { background: #FF1744; } .label-l3 { background: #FF9100; } .label-bad { background: #7C4DFF; }
        .gap-bad { color: #FF1744; font-weight: 900; } .gap-good { color: #00C853; font-weight: 900; }
      "))
    ),
    tabsetPanel(
      tabPanel("总览+闪烁警讯",
               fluidRow(column(12, uiOutput("blink_alert"))),
               fluidRow(
                 column(3, uiOutput("kpi_total")),
                 column(3, uiOutput("kpi_l4")),
                 column(3, uiOutput("kpi_avg_rate")),
                 column(3, uiOutput("kpi_high_roi"))
               ),
               fluidRow(
                 box(width = 6, title = "同桌率分布 - 高对比直方图",
                     solidHeader = TRUE, plotlyOutput("hist_plot")),
                 box(width = 6, title = "散点象限 - 气泡越大越危险",
                     solidHeader = TRUE, plotlyOutput("scatter_plot"))
               )
      ),
      tabPanel("明细+过滤",
               fluidRow(
                 box(width = 12, title = "玩家对子明细 - 支持列头筛选",
                     DTOutput("pair_table"), solidHeader = TRUE)
               ),
               fluidRow(
                 box(width = 12, title = "Dealer/玩家盈亏 - 高ROI警戒",
                     DTOutput("dealer_table"), solidHeader = TRUE)
               )
      ),
      tabPanel("金融均线+新闻",
               fluidRow(
                 box(width = 8, title = "同桌局数时序 + MA均线 + Bollinger",
                     plotlyOutput("ts_plot"), solidHeader = TRUE),
                 box(width = 4, title = "重点新闻警讯流",
                     uiOutput("news_ticker"), solidHeader = TRUE)
               ),
               fluidRow(
                 box(width = 12, title = "ROI时序 - 30%放水红线",
                     plotlyOutput("roi_ts"), solidHeader = TRUE)
               )
      ),
      tabPanel("📑 真实逐人深度解剖",
               fluidRow(
                 column(12,
                        h2("真实数据逐人逐荷官逐产品解剖报告", style="color:#FFFFFF; font-weight:900;"),
                        p("基于你4个csv真值：100对全是273467-X，Dealer 35% ROI>30%，凌晨05时作案窗口。以下用大白话讲每个ID的问题。", style="color:#CBD5E1;")
                 )
               ),
               fluidRow(column(12, uiOutput("deep_cards"))),
               hr(),
               fluidRow(
                 box(width = 4, title = "不足之处 P0/P1", status = "danger",
                     solidHeader = TRUE, uiOutput("weakness_box")),
                 box(width = 4, title = "风控+推荐+优化", status = "warning",
                     solidHeader = TRUE, uiOutput("risk_box")),
                 box(width = 4, title = "解决方案与措施 SOP", status = "success",
                     solidHeader = TRUE, uiOutput("solution_box"))
               )
      )
    )
  )
)

# ---- Server ----
server <- function(input, output, session) {
  
  # 过滤数据（使用引用，不复制）
  filtered_pair <- reactive({
    dt <- pair_stat
    if (input$tier_filter != "全部") dt <- dt[risk_tier == input$tier_filter]
    dt <- dt[same_rate >= input$rate_filter]
    dt
  })
  
  # KPI 卡片
  output$kpi_total <- renderUI({
    div(class = "vivid-kpi l2",
        h3(nrow(pair_stat)),
        p("总对子数 - 全是 273467 切片 | 最优均值应分散>1000玩家"))
  })
  output$kpi_l4 <- renderUI({
    l4n <- nrow(pair_stat[risk_tier == "L4-实锤"])
    div(class = "vivid-kpi l4",
        h3(paste0(l4n, " 对 (", round(l4n / nrow(pair_stat) * 100, 1), "%)")),
        p(paste0("L4实锤 >=30% - 最高", round(max(pair_stat$same_rate) * 100, 1), "% 正常应<2%")))
  })
  output$kpi_avg_rate <- renderUI({
    div(class = "vivid-kpi l3",
        h3(paste0(round(mean(pair_stat$same_rate) * 100, 2), "%")),
        p(paste0("平均同桌率 - 最优均值", OPT_RATE * 100, "%, 差距", round(mean(pair_stat$same_rate) / OPT_RATE, 1), "倍")))
  })
  output$kpi_high_roi <- renderUI({
    cnt <- nrow(dealer_stat[player_roi > 0.3])
    div(class = "vivid-kpi dealer",
        h3(paste0(cnt, " 个 (", round(cnt / nrow(dealer_stat) * 100, 1), "%)")),
        p(paste0("高ROI>30% - 最优均值 ", OPT_ROI * 100, "%, 实际均值 ", round(mean(dealer_stat$player_roi) * 100, 1), "%")))
  })
  
  output$blink_alert <- renderUI({
    top <- pair_stat[1]
    div(class = "alert-blink",
        paste0("🚨 实时闪烁警讯: Top1 实锤 ", top$player_a, "-", top$player_b,
               " 同桌率 ", round(top$same_rate * 100, 1), "% | ", top$same_round_count,
               "局同桌 | 差距最优均值 ", round(top$same_rate / OPT_RATE, 1), "倍 | 立即冻结"))
  })
  
  output$hist_plot <- renderPlotly({
    plot_ly(filtered_pair(), x = ~same_rate, type = "histogram",
            marker = list(color = "#FF1744", line = list(color = "#FFFFFF", width = 1))) %>%
      layout(plot_bgcolor = "#FFFFFF", paper_bgcolor = "#FFFFFF",
             font = list(color = "#0F172A", size = 14),
             shapes = list(list(type = "line", x0 = 0.15, x1 = 0.15,
                                y0 = 0, y1 = 1, yref = "paper",
                                line = list(color = "#FF9100", width = 3, dash = "dash"))),
             annotations = list(list(x = 0.15, y = 0.9, yref = "paper",
                                     text = "风控线15%", font = list(color = "#FF9100", size = 14))))
  })
  
  output$scatter_plot <- renderPlotly({
    dt <- filtered_pair()
    plot_ly(dt, x = ~same_round_count, y = ~same_rate,
            size = ~risk_score_v2, color = ~risk_tier,
            colors = c("L4-实锤" = "#FF1744", "L3-高危" = "#FF9100",
                       "L2-可疑" = "#FFEA00", "L1-正常" = "#00E676"),
            text = ~paste("ID:", player_b, "<br>同桌率:", round(same_rate * 100, 1),
                          "%<br>差距:", round(same_rate / 0.02, 1), "倍"),
            type = "scatter", mode = "markers") %>%
      layout(plot_bgcolor = "#FFFFFF", paper_bgcolor = "#FFFFFF",
             font = list(color = "#0F172A"))
  })
  
  output$pair_table <- renderDT({
    datatable(filtered_pair(), filter = "top",
              options = list(pageLength = 10, scrollX = TRUE),
              caption = "列头可直接筛选 - 鲜明色高对比") %>%
      formatStyle("risk_tier",
                  backgroundColor = styleEqual(
                    c("L4-实锤", "L3-高危", "L2-可疑", "L1-正常"),
                    c("#FFCDD2", "#FFE0B2", "#FFF9C4", "#C8E6C9")))
  })
  
  output$dealer_table <- renderDT({
    datatable(dealer_stat, filter = "top", options = list(pageLength = 10)) %>%
      formatStyle("player_roi",
                  backgroundColor = styleInterval(0.3, c("#FFFFFF", "#FFCDD2")))
  })
  
  output$ts_plot <- renderPlotly({
    dt <- copy(pair_hourly)
    dt[, ma := frollmean(same_round_count, n = input$ma_window, fill = NA)]
    plot_ly(dt, x = ~stat_hour) %>%
      add_bars(y = ~same_round_count, name = "同桌局数",
               marker = list(color = "#00B0FF")) %>%
      add_lines(y = ~ma, name = paste0("MA", input$ma_window),
                line = list(color = "#FF1744", width = 3, dash = "dash")) %>%
      layout(plot_bgcolor = "#FFFFFF", paper_bgcolor = "#FFFFFF")
  })
  
  output$roi_ts <- renderPlotly({
    plot_ly(dealer_hourly, x = ~stat_hour, y = ~player_roi,
            type = "scatter", mode = "lines+markers",
            line = list(color = "#7C4DFF")) %>%
      layout(shapes = list(list(type = "line", y0 = 0.3, y1 = 0.3,
                                x0 = 0, x1 = 23,
                                line = list(color = "#FF1744", width = 3))),
             plot_bgcolor = "#FFFFFF", paper_bgcolor = "#FFFFFF")
  })
  
  output$news_ticker <- renderUI({
    tags$ul(
      tags$li("[L4-实锤] 2026-05-15 05时 同桌23局 凌晨作案窗口"),
      tags$li(paste0("[高ROI] 玩家 ", dealer_stat[which.max(player_roi)]$player_id,
                     " ROI ", round(max(dealer_stat$player_roi) * 100, 1),
                     "% 超最优 ", round((max(dealer_stat$player_roi) - OPT_ROI) * 100, 1), "pp")),
      tags$li("[缺陷] dealer_id=-1 100% 归因失效 P0"),
      tags$li("[养号] 68520182 存活0.003天 秒建秒打")
    )
  })
  
  output$deep_cards <- renderUI({
    top5 <- head(pair_stat, 5)
    top_dealer <- head(dealer_stat[order(-player_roi)], 5)
    
    cards <- lapply(1:nrow(top5), function(i) {
      r <- top5[i]
      gap <- round(r$same_rate / OPT_RATE, 1)
      div(class = "explain-card",
          span(class = "label label-l4", r$risk_tier),
          strong(paste0(" 会员/玩家 ", r$player_a, " - ", r$player_b)),
          br(),
          p(HTML(paste0(
            "<b>时间点：</b> 存活 ", round(r$days_active, 2), " 天, 近", r$recency_days, "天活跃<br>",
            "<b>盈亏/同桌率：</b> 同桌 ", r$same_round_count, "/", r$total_round_a,
            " = ", round(r$same_rate * 100, 1), "%<br>",
            "<b>最优平均值：</b> 散客同桌率最优均值 ", OPT_RATE * 100, "%<br>",
            "<b>差距：</b> <span class='gap-bad'>", gap, "倍 (", round((r$same_rate - OPT_RATE) * 100, 1), "pp)</span><br>",
            "<b>外行解说：</b> 正常玩家像在机场随机碰到同事，概率", OPT_RATE * 100, "%。这个玩家每", round(1 / r$same_rate, 1), "局就碰到一次，相当于每天都坐同一班飞机，绝对不正常。属于",
            if (gap > 15) "【团伙实锤】" else if (gap > 7) "【高度可疑】" else "【养号观察】", "<br>",
            "<b>产品：</b> 真人荷官桌，凌晨05时高频，疑似刷流水或筹码输送"
          )))
      )
    })
    
    dealer_cards <- lapply(1:nrow(top_dealer), function(i) {
      r <- top_dealer[i]
      gap_roi <- round((r$player_roi - OPT_ROI) * 100, 1)
      div(class = "explain-card",
          span(class = "label label-bad", "高ROI"),
          strong(paste0(" 真人荷官/玩家 ", r$player_id, " | Dealer ", r$dealer_id)),
          br(),
          p(HTML(paste0(
            "<b>盈亏率：</b> ROI ", round(r$player_roi * 100, 1), "% , 胜率 ",
            round(r$win_rate * 100, 1), "%, 盈利 ", round(r$profit, 0), "<br>",
            "<b>最优平均值：</b> 正常玩家ROI最优均值 ", OPT_ROI * 100, "% (庄家优势-2%~-5%)<br>",
            "<b>差距：</b> <span class='gap-bad'>+", gap_roi, "pp，高出",
            round(r$player_roi / 0.3, 1), "倍放水线</span><br>",
            "<b>外行解说：</b> 赌场正常要抽水，玩家长期应该小亏。这个玩家每投100块赚",
            round(r$player_roi * 100, 0), "块，相当于ATM机在吐钱。ID 30694457胜率100%绝对是假账号或荷官配合。<br>",
            "<b>时间点：</b> 05时profit 274800 单点倾倒，符合洗钱特征"
          )))
      )
    })
    
    do.call(tagList, c(cards, dealer_cards))
  })
  
  output$weakness_box <- renderUI({
    HTML("
      <div style='color:#0F172A'>
      <b>P0 缺陷：</b>dealer_id=-1 100% 归因失效，无法定位哪个荷官放水<br>
      <b>P0 数据：</b>100对全是273467切片，无正常对照组，模型会过拟合<br>
      <b>P1 养号：</b>68520182 存活0.003天=4分钟，秒建秒打<br>
      <b>P1 时间：</b>凌晨05时集中作案，风控值班空档<br>
      <b>P1 盈利：</b>平均ROI 27.8% vs 最优-3.5% = 放水 31.3pp
      </div>
    ")
  })
  
  output$risk_box <- renderUI({
    HTML("
      <div style='color:#0F172A'>
      <b>风控：</b><br>
      - 同桌率>15% 自动冻结+人脸复核<br>
      - ROI>30% 自动限额1000<br>
      - dealer_id=-1 拒绝结算<br>
      - 05时段加强审核<br><br>
      <b>推荐：</b><br>
      - 273467 及4个L4实锤立即进黑名单<br>
      - 21个L3高危进灰名单观察<br><br>
      <b>优化：</b><br>
      - risk_score_v2 写回数仓建实时看板<br>
      - 增加设备指纹+IP聚类
      </div>
    ")
  })
  
  output$solution_box <- renderUI({
    HTML("
      <div style='color:#0F172A'>
      <b>立即执行(24h)：</b><br>
      1. 冻结Top1 273467-3163098 85局<br>
      2. 补齐dealer_id归因<br>
      3. Superset建Alert risk_score_v2>2<br><br>
      <b>短期(7天)：</b><br>
      1. 上线MA7+ROI 30%双红线<br>
      2. 凌晨05时人工复核<br>
      3. 养号规则存活<1天+同桌>30%拦截<br><br>
      <b>长期(30天)：</b><br>
      1. 图论社群发现星型网络<br>
      2. 引入最优平均值差距自动解说<br>
      3. 每周生成外行版报告给运营
      </div>
    ")
  })
}

# ---- 启动应用 ----
shinyApp(ui, server)
