# app.R
source("global.R")

ui <- dashboardPage(
  dashboardHeader(title = "🎯 风控监控仪表板"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("概览", tabName = "overview", icon = icon("dashboard")),
      menuItem("玩家关系网络", tabName = "network", icon = icon("sitemap")),
      menuItem("荷官获利异常", tabName = "dealer", icon = icon("dollar-sign")),
      menuItem("风险评分", tabName = "risk", icon = icon("exclamation-triangle")),
      menuItem("时间趋势", tabName = "trend", icon = icon("chart-line"))
    ),
    hr(),
    dateRangeInput("date_range", "日期范围",
                   start = min(pair_stat$first_game_time, na.rm = TRUE),
                   end = max(pair_stat$last_game_time, na.rm = TRUE)),
    sliderInput("risk_threshold", "风险阈值（同桌率）",
                min = 0, max = 1, value = 0.3, step = 0.05)
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "overview",
              fluidRow(
                valueBoxOutput("total_pairs"),
                valueBoxOutput("total_dealer"),
                valueBoxOutput("avg_same_rate")
              ),
              fluidRow(
                box(title = "同桌率分布", plotOutput("rate_dist"), width = 6),
                box(title = "盈利分布", plotOutput("profit_dist"), width = 6)
              )
      ),
      tabItem(tabName = "network",
              fluidRow(
                box(title = "玩家关系网络（强关联）", 
                    forceNetworkOutput("network_plot", height = "600px"), width = 12)
              )
      ),
      tabItem(tabName = "dealer",
              fluidRow(
                box(title = "荷官盈利散点图", plotOutput("dealer_scatter"), width = 12)
              ),
              fluidRow(
                box(title = "异常荷官列表", DTOutput("anomaly_table"), width = 12)
              )
      ),
      tabItem(tabName = "risk",
              fluidRow(
                box(title = "高风险玩家对", DTOutput("risk_table"), width = 12)
              )
      ),
      tabItem(tabName = "trend",
              fluidRow(
                box(title = "每日新增同桌关系", plotOutput("trend_pairs"), width = 12)
              )
      )
    )
  )
)

server <- function(input, output, session) {
  
  filtered_pair <- reactive({
    req(input$date_range)
    pair_stat[first_game_time >= input$date_range[1] & 
                last_game_time <= input$date_range[2]]
  })
  
  filtered_dealer <- reactive({
    req(input$date_range)
    dealer_stat[first_bet_time >= input$date_range[1] & 
                  last_bet_time <= input$date_range[2]]
  })
  
  # ---------- 概览 ValueBoxes（使用 scales 安全格式化）----------
  output$total_pairs <- renderValueBox({
    n <- if (nrow(filtered_pair()) == 0) 0 else nrow(filtered_pair())
    valueBox(value = comma(n), 
             subtitle = "玩家对总数", 
             icon = icon("users"), color = "blue")
  })
  
  output$total_dealer <- renderValueBox({
    n <- if (nrow(filtered_dealer()) == 0) 0 else nrow(filtered_dealer())
    valueBox(value = comma(n), 
             subtitle = "荷官-玩家记录数", 
             icon = icon("hand-holding-usd"), color = "green")
  })
  
  output$avg_same_rate <- renderValueBox({
    df <- filtered_pair()
    avg <- if (nrow(df) == 0) 0 else round(mean(df$same_rate, na.rm = TRUE), 3)
    valueBox(value = comma(avg, digits = 3), 
             subtitle = "平均同桌率", 
             icon = icon("percent"), color = "yellow")
  })
  
  # ---------- 分布图 ----------
  output$rate_dist <- renderPlot({
    df <- filtered_pair()
    if (nrow(df) == 0) { plot.new(); text(0.5,0.5,"无数据", cex=1.5); return() }
    ggplot(df, aes(x = same_rate)) +
      geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
      labs(x = "同桌率", y = "频数") + theme_minimal()
  })
  
  output$profit_dist <- renderPlot({
    df <- filtered_dealer()
    df <- df[is.finite(profit_per_bet)]
    if (nrow(df) == 0) { plot.new(); text(0.5,0.5,"无数据", cex=1.5); return() }
    ggplot(df, aes(x = profit_per_bet)) +
      geom_histogram(bins = 30, fill = "darkgreen", alpha = 0.7) +
      labs(x = "每注盈利", y = "频数") + theme_minimal()
  })
  
  # ---------- 网络图 ----------
  output$network_plot <- renderForceNetwork({
    strong <- filtered_pair()[same_round_count > input$risk_threshold * 50, .(player_a, player_b, weight = same_round_count)]
    if (nrow(strong) < 2) {
      return(forceNetwork(Links = data.frame(source=0,target=1,value=1), 
                          Nodes = data.frame(name=c("无数据","")),
                          Source="source", Target="target", Value="value", NodeID="name"))
    }
    nodes <- data.frame(name = as.character(unique(c(strong$player_a, strong$player_b))))
    nodes$id <- 0:(nrow(nodes)-1)
    links <- data.frame(
      source = match(strong$player_a, nodes$name) - 1L,
      target = match(strong$player_b, nodes$name) - 1L,
      value = as.numeric(strong$weight)
    )
    forceNetwork(Links = links, Nodes = nodes,
                 Source = "source", Target = "target",
                 Value = "value", NodeID = "name",
                 fontSize = 10, zoom = TRUE,
                 opacity = 0.8, 
                 linkWidth = JS("function(d) { return Math.sqrt(d.value); }"))
  })
  
  # ---------- 荷官散点图 ----------
  output$dealer_scatter <- renderPlot({
    df <- filtered_dealer()
    if (nrow(df) == 0) { plot.new(); text(0.5,0.5,"无数据", cex=1.5); return() }
    ggplot(df, aes(x = bet_count, y = profit, color = win_rate)) +
      geom_point(alpha = 0.6) +
      scale_color_gradient(low = "red", high = "green") +
      labs(x = "下注次数", y = "盈利", color = "胜率") + theme_minimal()
  })
  
  # ---------- 异常荷官表格（强制转为 data.frame）----------
  output$anomaly_table <- renderDT({
    df <- filtered_dealer()
    if (nrow(df) == 0) return(datatable(data.frame(消息="无数据")))
    df <- as.data.frame(df)
    df$z_profit <- scale(df$profit_per_bet, center = TRUE, scale = TRUE)[,1]
    anomaly <- df[abs(df$z_profit) > 3, c("dealer_id","player_id","bet_count","profit_per_bet","z_profit")]
    if (nrow(anomaly) == 0) {
      return(datatable(data.frame(消息="未发现异常组合")))
    }
    datatable(anomaly, options = list(pageLength = 10), 
              caption = "异常荷官-玩家组合（|Z|>3）")
  })
  
  # ---------- 风险评分表 ----------
  output$risk_table <- renderDT({
    df <- filtered_pair()
    if (nrow(df) == 0) return(datatable(data.frame(消息="无数据")))
    max_round <- max(df$same_round_count, na.rm = TRUE)
    if (max_round == 0) max_round <- 1  # 防止除以零
    df[, risk_score := (same_rate * 0.5) + 
         (same_round_count / max_round * 0.3) +
         (player_a_rounds / (player_a_rounds + player_b_rounds) * 0.2)]
    high_risk <- as.data.frame(df[order(-risk_score)][1:50, .(player_a, player_b, same_round_count, same_rate, risk_score)])
    if (nrow(high_risk) == 0) {
      return(datatable(data.frame(消息="无高风险组合")))
    }
    datatable(high_risk, options = list(pageLength = 20), 
              caption = "Top 50 高风险玩家对")
  })
  
  # ---------- 趋势图 ----------
  output$trend_pairs <- renderPlot({
    df <- pair_hourly[, .(count = .N), by = .(date = as.Date(stat_date))]
    if (nrow(df) == 0) { plot.new(); text(0.5,0.5,"无数据", cex=1.5); return() }
    ggplot(df, aes(x = date, y = count)) +
      geom_line(color = "darkorange") +
      geom_smooth(method = "loess", se = FALSE, color = "blue") +
      labs(x = "日期", y = "新增同桌关系数") + theme_minimal()
  })
}

shinyApp(ui = ui, server = server)