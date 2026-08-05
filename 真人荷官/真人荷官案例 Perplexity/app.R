# app.R
library(shiny)
library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)
library(plotly)

data_path <- file.path("C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/", "dealer_profit_stat_hourly.csv")

load_data <- function() {
  df <- read_csv(data_path, show_col_types = FALSE)
  
  time_cols <- c("first_bet_time", "last_bet_time", "created_time", "update_time")
  for (col in time_cols) {
    if (col %in% names(df)) {
      df[[col]] <- ymd_hms(df[[col]], quiet = TRUE)
    }
  }
  
  df
}

ui <- fluidPage(
  titlePanel("🔮 Dealer Profit Risk Dashboard (Shiny R 应用)"),
  
  sidebarLayout(
    sidebarPanel(
      h4("筛选条件"),
      uiOutput("dealer_filter"),
      uiOutput("game_filter"),
      uiOutput("risk_filter"),
      uiOutput("time_filter")
    ),
    mainPanel(
      fluidRow(
        column(3, h4("记录数"), textOutput("records_count")),
        column(3, h4("总下注次数"), textOutput("total_bet_count")),
        column(3, h4("总盈利"), textOutput("total_profit")),
        column(3, h4("平均玩家 ROI"), textOutput("avg_player_roi"))
      ),
      hr(),
      
      h3("📈 盈利与 ROI 时间序列"),
      fluidRow(
        column(6, plotlyOutput("profit_ts")),
        column(6, plotlyOutput("roi_ts"))
      ),
      
      hr(),
      h3("📊 盈利与 ROI 分布视图"),
      fluidRow(
        column(6, plotlyOutput("profit_hist")),
        column(6, plotlyOutput("roi_hist"))
      ),
      
      hr(),
      h3("⚠️ 风险等级分布"),
      plotlyOutput("risk_bar"),
      
      hr(),
      h3("👑 Top 风险玩家"),
      sliderInput("top_n", "显示前 N 名风险玩家", min = 10, max = 200, value = 50, step = 10),
      dataTableOutput("top_risk_table")
    )
  )
)

server <- function(input, output, session) {
  df <- load_data()
  
  output$dealer_filter <- renderUI({
    dealer_ids <- sort(unique(df$dealer_id))
    selectInput("dealer_selected", "荷官 ID", choices = dealer_ids,
                selected = dealer_ids, multiple = TRUE)
  })
  
  output$game_filter <- renderUI({
    game_ids <- sort(unique(df$game_id))
    selectInput("game_selected", "游戏 ID", choices = game_ids,
                selected = game_ids, multiple = TRUE)
  })
  
  output$risk_filter <- renderUI({
    if ("risk_level" %in% names(df)) {
      risk_levels <- sort(unique(df$risk_level))
      selectInput("risk_selected", "风险等级", choices = risk_levels,
                  selected = risk_levels, multiple = TRUE)
    } else {
      tagList(em("数据中缺少 risk_level 字段。"))
    }
  })
  
  output$time_filter <- renderUI({
    if ("last_bet_time" %in% names(df)) {
      min_time <- min(df$last_bet_time, na.rm = TRUE)
      max_time <- max(df$last_bet_time, na.rm = TRUE)
      dateRangeInput("time_range", "最近下注时间范围",
                     start = as.Date(min_time), end = as.Date(max_time))
    } else {
      tagList(em("数据中缺少 last_bet_time 字段。"))
    }
  })
  
  filtered_df <- reactive({
    req(input$dealer_selected, input$game_selected)
    
    df2 <- df %>%
      filter(dealer_id %in% input$dealer_selected,
             game_id %in% input$game_selected)
    
    if (!is.null(input$risk_selected) && "risk_level" %in% names(df)) {
      df2 <- df2 %>% filter(risk_level %in% input$risk_selected)
    }
    
    if (!is.null(input$time_range) && "last_bet_time" %in% names(df)) {
      start_date <- input$time_range[1]
      end_date <- input$time_range[2]
      df2 <- df2 %>%
        filter(as.Date(last_bet_time) >= start_date,
               as.Date(last_bet_time) <= end_date)
    }
    
    df2
  })
  
  output$records_count <- renderText({
    nrow(filtered_df())
  })
  
  output$total_bet_count <- renderText({
    sum(filtered_df()$bet_count, na.rm = TRUE)
  })
  
  output$total_profit <- renderText({
    sprintf("%.2f", sum(filtered_df()$profit, na.rm = TRUE))
  })
  
  output$avg_player_roi <- renderText({
    if ("player_roi" %in% names(df)) {
      sprintf("%.4f", mean(filtered_df()$player_roi, na.rm = TRUE))
    } else {
      "N/A"
    }
  })
  
  output$profit_ts <- renderPlotly({
    df_ts <- filtered_df()
    req("last_bet_time" %in% names(df_ts))
    
    df_ts <- df_ts %>%
      mutate(date = as.Date(last_bet_time)) %>%
      group_by(date) %>%
      summarise(
        total_profit = sum(profit, na.rm = TRUE),
        bet_count = sum(bet_count, na.rm = TRUE),
        .groups = "drop"
      )
    
    p <- ggplot(df_ts, aes(x = date, y = total_profit)) +
      geom_line(color = "steelblue") +
      labs(title = "每日总盈利", x = "日期", y = "总盈利")
    
    ggplotly(p)
  })
  
  output$roi_ts <- renderPlotly({
    df_ts <- filtered_df()
    req("last_bet_time" %in% names(df_ts), "player_roi" %in% names(df_ts))
    
    df_ts <- df_ts %>%
      mutate(date = as.Date(last_bet_time)) %>%
      group_by(date) %>%
      summarise(
        avg_player_roi = mean(player_roi, na.rm = TRUE),
        .groups = "drop"
      )
    
    p <- ggplot(df_ts, aes(x = date, y = avg_player_roi)) +
      geom_line(color = "darkgreen") +
      labs(title = "每日平均玩家 ROI", x = "日期", y = "平均 ROI")
    
    ggplotly(p)
  })
  
  output$profit_hist <- renderPlotly({
    df_f <- filtered_df()
    
    p <- ggplot(df_f, aes(x = profit)) +
      geom_histogram(bins = 50, fill = "steelblue", color = "white") +
      labs(title = "盈利分布直方图", x = "盈利", y = "频数")
    
    ggplotly(p)
  })
  
  output$roi_hist <- renderPlotly({
    df_f <- filtered_df()
    req("player_roi" %in% names(df_f))
    
    p <- ggplot(df_f, aes(x = player_roi)) +
      geom_histogram(bins = 50, fill = "darkgreen", color = "white") +
      labs(title = "玩家 ROI 分布直方图", x = "玩家 ROI", y = "频数")
    
    ggplotly(p)
  })
  
  output$risk_bar <- renderPlotly({
    df_f <- filtered_df()
    req("risk_level" %in% names(df_f))
    
    risk_df <- df_f %>%
      count(risk_level, name = "count")
    
    p <- ggplot(risk_df, aes(x = risk_level, y = count, fill = risk_level)) +
      geom_col() +
      labs(title = "风险等级记录数", x = "风险等级", y = "记录数") +
      theme(legend.position = "none")
    
    ggplotly(p)
  })
  
  output$top_risk_table <- renderDataTable({
    df_f <- filtered_df()
    
    if (!("risk_score" %in% names(df_f))) {
      return(df_f)
    }
    
    top_n <- input$top_n
    
    df_top <- df_f %>%
      arrange(desc(risk_score)) %>%
      head(top_n) %>%
      select(
        dealer_id,
        game_id,
        player_id,
        bet_count,
        valid_bet,
        turnover,
        profit,
        profit_per_bet,
        win_rate,
        player_roi,
        risk_score,
        risk_level,
        first_bet_time,
        last_bet_time
      )
    
    df_top
  })
}

shinyApp(ui = ui, server = server)
