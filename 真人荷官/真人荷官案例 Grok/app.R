# ==================== app.R ====================
library(shiny)
library(shinydashboard)
library(data.table)
library(ggplot2)
library(plotly)
library(igraph)
library(DT)
library(lubridate)

# ====================== 数据加载 ======================
load_data <- function() {
  data_dir <- "C:/Users/PCCPPPCCC/Documents/GitHub/basic-data-analytical-lab/数据库/"
  
  list(
    pps = fread(file.path(data_dir, "sqllab_untitled_query_2_20260719T050927.csv")),
    pps_h = fread(file.path(data_dir, "sqllab_untitled_query_2_20260719T050833.csv")),
    dps = fread(file.path(data_dir, "sqllab_untitled_query_2_20260719T050933.csv")),
    dps_h = fread(file.path(data_dir, "sqllab_untitled_query_2_20260719T050902.csv"))
  )
}

data <- load_data()

# ====================== 风险模型 ======================
calculate_risk_scores <- function(dt) {
  dt[, risk_score := 
       same_round_count * 0.4 + 
       same_rate * 35 + 
       as.numeric(difftime(last_game_time, first_game_time, units = "days")) * 0.25]
  
  dt[, risk_level := fcase(
    risk_score >= 85, "极高风险",
    risk_score >= 70, "高风险",
    risk_score >= 50, "中风险",
    default = "低风险"
  )]
  dt
}

risk_data <- calculate_risk_scores(data$pps)

# ====================== UI ======================
ui <- dashboardPage(
  dashboardHeader(title = "真人荷官风控分析系统"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("概览", tabName = "overview", icon = icon("dashboard")),
      menuItem("网络分析", tabName = "network", icon = icon("project-diagram")),
      menuItem("风险评分", tabName = "scoring", icon = icon("chart-bar")),
      menuItem("时间趋势", tabName = "trend", icon = icon("clock"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "overview",
              fluidRow(
                valueBoxOutput("total_pairs", width = 3),
                valueBoxOutput("high_risk", width = 3),
                valueBoxOutput("avg_rate", width = 3),
                valueBoxOutput("max_same", width = 3)
              ),
              fluidRow(
                box(DTOutput("summary_table"), width = 12, title = "高风险玩家对")
              )
      ),
      tabItem(tabName = "network",
              box(plotlyOutput("network_plot", height = "600px"), width = 12, title = "玩家同桌关系网络")
      ),
      tabItem(tabName = "scoring",
              box(plotlyOutput("risk_dist"), width = 12))
    )
  )
)

# ====================== Server ======================
server <- function(input, output) {
  output$total_pairs <- renderValueBox({
    valueBox(nrow(risk_data), "总玩家对数", icon = icon("users"), color = "blue")
  })
  
  output$high_risk <- renderValueBox({
    valueBox(sum(risk_data$risk_score >= 70), "高风险对数", icon = icon("exclamation-triangle"), color = "red")
  })
  
  output$avg_rate <- renderValueBox({
    valueBox(round(mean(risk_data$same_rate, na.rm = TRUE), 4), "平均同桌率", icon = icon("percent"), color = "green")
  })
  
  output$max_same <- renderValueBox({
    valueBox(max(risk_data$same_round_count), "最高同桌局数", icon = icon("trophy"), color = "yellow")
  })
  
  output$summary_table <- renderDT({
    datatable(risk_data[order(-risk_score)][1:50], options = list(pageLength = 10))
  })
  
  output$network_plot <- renderPlotly({
    edges <- risk_data[risk_score >= 50, .(player_a, player_b, weight = same_round_count)]
    g <- graph_from_data_frame(edges, directed = FALSE)
    plot(g, vertex.size = 6, edge.width = E(g)$weight / 20, main = "高风险同桌网络")
  })
  
  output$risk_dist <- renderPlotly({
    ggplot(risk_data, aes(x = risk_score, fill = risk_level)) +
      geom_histogram(bins = 30) + theme_minimal() +
      labs(title = "风险分数分布")
  })
}

shinyApp(ui, server)