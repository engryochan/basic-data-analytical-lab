library(shiny)
library(bslib)
library(data.table)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(igraph)
library(ggraph)
library(scales)
library(forecast)
library(lubridate)

# ---------------- 数据加载 ----------------
DATA_DIR <- "data_full"  # 已修正：改用10万行全量数据
dps <- fread(file.path(DATA_DIR, "dealer_profit_stat.csv"))
dph <- fread(file.path(DATA_DIR, "dealer_profit_stat_hourly.csv"))
pps <- fread(file.path(DATA_DIR, "player_pair_stat.csv"))
pph <- fread(file.path(DATA_DIR, "player_pair_stat_hourly.csv"))

# 衍生字段
pps[, `:=`(
  first_game_time = as.POSIXct(first_game_time),
  last_game_time  = as.POSIXct(last_game_time)
)]
pps[, `:=`(
  a_dependency = same_round_count / player_a_rounds,
  b_dependency = same_round_count / player_b_rounds
)]
pps[, max_dependency := pmax(a_dependency, b_dependency)]
pps[, duration_days   := as.numeric(difftime(last_game_time, first_game_time, units = "days"))]
pps[, days_since_last := as.numeric(difftime(Sys.time(), last_game_time, units = "days"))]

minmax <- function(x) (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE) + 1e-9)
pps[, risk_score := (
  0.35 * minmax(same_rate) +
  0.30 * minmax(max_dependency) +
  0.20 * minmax(same_round_count) +
  0.15 * minmax(duration_days)
) * 100]

# ---- 扩展指标：6档风险等级 / 同桌率分档 / 密度 / 不对称率 ----
pps[, risk_level_6 := cut(
  risk_score, breaks = c(-Inf, 15, 30, 50, 70, 85, Inf),
  labels = c("正常", "低风险", "中风险", "中高风险", "高风险", "极高风险"), right = TRUE
)]
pps[, same_rate_bin := cut(
  same_rate, breaks = c(-Inf, 0.01, 0.05, 0.15, 0.30, 0.50, Inf),
  labels = c("极低(<1%)", "低(1-5%)", "中(5-15%)", "较高(15-30%)", "高(30-50%)", "极高(≥50%)"), right = FALSE
)]
pps[, same_density := fifelse(duration_days > 0, same_round_count / duration_days, same_round_count)]
pps[, activity_asymmetry := pmin(player_a_rounds, player_b_rounds) / pmax(player_a_rounds, player_b_rounds)]

g_full <- graph_from_data_frame(pps[, .(from = as.character(player_a), to = as.character(player_b))], directed = FALSE)
degree_dt <- data.table(player = names(degree(g_full)), degree = as.integer(degree(g_full)))

# ---------------- UI ----------------
ui <- page_navbar(
  title = "风控四表交互分析平台",
  theme = bs_theme(version = 5, bootswatch = "cosmo"),

  nav_panel(
    "总览 KPI",
    layout_column_wrap(
      width = 1/4,
      value_box(title = "候选配对总数", value = textOutput("kpi_total"), theme = "primary"),
      value_box(title = "高风险配对(>80分)", value = textOutput("kpi_high"), theme = "danger"),
      value_box(title = "近7天仍活跃", value = textOutput("kpi_recent"), theme = "warning"),
      value_box(title = "持续超30天", value = textOutput("kpi_long"), theme = "info")
    ),
    card(
      card_header("dealer_profit_stat 数据质量告警"),
      textOutput("dq_alert")
    )
  ),

  nav_panel(
    "玩家同桌关系分析",
    layout_sidebar(
      sidebar = sidebar(
        title = "筛选条件",
        sliderInput("risk_range", "风险分范围", min = 0, max = 100, value = c(0, 100)),
        sliderInput("min_rounds", "最小同桌局数", min = 1, max = max(pps$same_round_count), value = 1),
        sliderInput("min_rate", "最小同桌率", min = 0, max = 1, value = 0, step = 0.01),
        hr(),
        downloadButton("download_filtered", "导出当前筛选结果 CSV")
      ),
      navset_card_tab(
        nav_panel("分布图",
          plotlyOutput("dist_same_rate"),
          plotlyOutput("scatter_risk")
        ),
        nav_panel("排行榜",
          DTOutput("risk_table")
        ),
        nav_panel("关系网络图",
          sliderInput("network_threshold", "网络图风险分阈值(仅显示≥此值的边)",
                      min = 0, max = 100, value = 90),
          plotOutput("network_plot", height = "600px")
        ),
        nav_panel("扩展风控画像",
          layout_column_wrap(
            width = 1/2,
            plotOutput("risk_level_bar"),
            plotOutput("rate_pie")
          ),
          layout_column_wrap(
            width = 1/2,
            plotOutput("cross_heatmap"),
            plotOutput("degree_dist")
          ),
          layout_column_wrap(
            width = 1/3,
            plotOutput("duration_dist"),
            plotOutput("density_dist"),
            plotOutput("asymmetry_dist")
          )
        ),
        nav_panel("预测走势(交互式)",
          card(
            card_header("月度新增可疑配对：历史趋势 + 未来预测"),
            sliderInput("forecast_horizon", "预测未来期数(月)", min = 1, max = 6, value = 3),
            plotlyOutput("forecast_plot", height = "450px"),
            helpText("阴影区域为95%置信区间；样本时间跨度不足4个月时会跳过建模，仅展示历史柱状图。")
          )
        )
      )
    )
  ),

  nav_panel(
    "会员/荷官查询",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("按玩家ID查询（地毯式：覆盖全部289位焦点玩家与44,433位搭档）"),
        textInput("query_player_id", "输入玩家ID", placeholder = "例如 273467"),
        actionButton("btn_query_player", "查询", class = "btn-primary"),
        hr(),
        DTOutput("player_query_result")
      ),
      card(
        card_header("按荷官ID查询（地毯式：覆盖全部142位真实荷官）"),
        textInput("query_dealer_id", "输入荷官ID", placeholder = "例如 1144"),
        actionButton("btn_query_dealer", "查询", class = "btn-primary"),
        hr(),
        DTOutput("dealer_query_result")
      )
    )
  ),

  nav_panel(
    "荷官盈利分析",
    layout_sidebar(
      sidebar = sidebar(
        title = "筛选条件",
        checkboxInput("exclude_sentinel", "排除 dealer_id = -1 哨兵值", value = TRUE)
      ),
      navset_card_tab(
        nav_panel("荷官汇总排行", DTOutput("dealer_table")),
        nav_panel("ROI分布图", plotlyOutput("dealer_roi_plot"))
      )
    )
  ),

  nav_panel(
    "小时时序模式",
    plotlyOutput("hourly_pattern_plot"),
    plotlyOutput("hourly_dealer_plot")
  )
)

# ---------------- Server ----------------
server <- function(input, output, session) {

  filtered_pps <- reactive({
    pps[risk_score >= input$risk_range[1] & risk_score <= input$risk_range[2] &
        same_round_count >= input$min_rounds &
        same_rate >= input$min_rate]
  })

  output$kpi_total  <- renderText(nrow(pps))
  output$kpi_high    <- renderText(sum(pps$risk_score > 80))
  output$kpi_recent  <- renderText(sum(pps$days_since_last <= 7))
  output$kpi_long    <- renderText(sum(pps$duration_days >= 30))

  output$dq_alert <- renderText({
    pct_sentinel <- mean(dps$dealer_id == -1) * 100
    pct_hourly_sentinel <- mean(dph$dealer_id == -1) * 100
    sprintf(
      "候选表 dealer_id=-1 占比: %.1f%% (基线/快照表占比仅 %.1f%%) — 疑似候选表导出未按 risk_score 排序，建议核实 SQL 排序逻辑后重新拉取。",
      pct_sentinel, pct_hourly_sentinel
    )
  })

  output$dist_same_rate <- renderPlotly({
    p <- ggplot(filtered_pps(), aes(same_rate)) +
      geom_histogram(bins = 25, fill = "steelblue", color = "white") +
      labs(title = "同桌率分布(当前筛选)", x = "same_rate", y = "频数") +
      theme_minimal()
    ggplotly(p)
  })

  output$scatter_risk <- renderPlotly({
    p <- ggplot(filtered_pps(), aes(same_round_count, same_rate, color = risk_score,
                                      text = paste0("A:", player_a, " B:", player_b))) +
      geom_point(alpha = 0.7) +
      scale_color_gradient(low = "gold", high = "red3") +
      labs(title = "同桌局数 vs 同桌率", x = "same_round_count", y = "same_rate") +
      theme_minimal()
    ggplotly(p, tooltip = "text")
  })

  output$risk_table <- renderDT({
    tbl <- filtered_pps()[order(-risk_score), .(
      player_a, player_b, same_round_count, same_rate = round(same_rate, 4),
      max_dependency = round(max_dependency, 4), duration_days = round(duration_days, 1),
      days_since_last = round(days_since_last, 1), risk_score = round(risk_score, 1)
    )]
    datatable(tbl, options = list(pageLength = 15), rownames = FALSE) |>
      formatStyle("risk_score", backgroundColor = styleInterval(c(50, 80), c("white", "#ffe6a3", "#ff8b8b")))
  })

  output$network_plot <- renderPlot({
    edges <- pps[risk_score >= input$network_threshold,
                 .(from = as.character(player_a), to = as.character(player_b), weight = risk_score)]
    validate(need(nrow(edges) > 0, "当前阈值下无符合条件的边，请调低阈值"))
    validate(need(nrow(edges) <= 500,
      sprintf("当前阈值下有%d条边，超过500条安全渲染上限，请调高阈值滑块以减少边数", nrow(edges))))

    g <- graph_from_data_frame(edges, directed = FALSE)
    V(g)$degree <- degree(g)
    comp <- components(g)
    V(g)$component <- comp$membership

    ggraph(g, layout = "fr") +
      geom_edge_link(aes(width = weight), alpha = 0.4, color = "grey50") +
      geom_node_point(aes(size = degree, color = factor(component))) +
      geom_node_text(aes(label = name), repel = TRUE, size = 3) +
      guides(color = "none") +
      labs(title = paste0("连通分量数: ", comp$no, " | 节点数: ", vcount(g))) +
      theme_void()
  })

  output$download_filtered <- downloadHandler(
    filename = function() paste0("filtered_player_pair_", Sys.Date(), ".csv"),
    content = function(file) fwrite(filtered_pps(), file)
  )

  # ---- 会员/荷官查询（地毯式覆盖，任何ID都能查） ----
  observeEvent(input$btn_query_player, {
    output$player_query_result <- renderDT({
      qid <- suppressWarnings(as.numeric(input$query_player_id))
      validate(need(!is.na(qid), "请输入有效的数字玩家ID"))

      result <- pps[player_a == qid | player_b == qid]
      validate(need(nrow(result) > 0,
        sprintf("玩家ID %s 未出现在当前 %d 条配对记录中(既不是player_a也不是player_b)，可能该玩家近期无同桌风控记录", qid, nrow(pps))))

      datatable(result[order(-risk_score), .(
        player_a, player_b, same_round_count, same_rate = round(same_rate, 4),
        risk_score = round(risk_score, 1), first_game_time, last_game_time
      )], options = list(pageLength = 10), rownames = FALSE) |>
        formatStyle("risk_score", backgroundColor = styleInterval(c(50, 80), c("white", "#ffe6a3", "#ff8b8b")))
    })
  })

  observeEvent(input$btn_query_dealer, {
    output$dealer_query_result <- renderDT({
      qid <- suppressWarnings(as.numeric(input$query_dealer_id))
      validate(need(!is.na(qid), "请输入有效的数字荷官ID"))

      result <- dph[dealer_id == qid]
      validate(need(nrow(result) > 0,
        sprintf("荷官ID %s 未出现在当前 %d 条记录中", qid, nrow(dph))))

      datatable(result[, .(
        stat_date, stat_hour, player_id, game_id, bet_count,
        turnover = round(turnover,0), profit = round(profit,0), win_rate = round(win_rate,3)
      )][order(-abs(profit))], options = list(pageLength = 10), rownames = FALSE) |>
        formatStyle("profit", background = styleColorBar(range(result$profit), "#ffb3b3"))
    })
  })

  # ---- 扩展风控画像 ----
  output$risk_level_bar <- renderPlot({
    ggplot(pps[!is.na(risk_level_6)], aes(risk_level_6, fill = risk_level_6)) +
      geom_bar() +
      geom_text(stat = "count", aes(label = after_stat(count)), vjust = -0.4) +
      scale_fill_manual(values = c("正常"="#2ecc71","低风险"="#3498db","中风险"="#f39c12",
                                     "中高风险"="#e67e22","高风险"="#9b59b6","极高风险"="#e74c3c")) +
      guides(fill = "none") +
      labs(title = "6档风险等级分布", x = NULL, y = "记录数") +
      theme_minimal()
  })

  output$rate_pie <- renderPlot({
    rate_bin_summary <- pps[!is.na(same_rate_bin), .N, by = same_rate_bin]
    ggplot(rate_bin_summary, aes(x = "", y = N, fill = same_rate_bin)) +
      geom_col(width = 1, color = "white") +
      coord_polar("y") +
      geom_text(aes(label = paste0(round(N/sum(N)*100,1), "%")),
                position = position_stack(vjust = 0.5), size = 3.2) +
      theme_void() +
      labs(title = "同桌率分档占比", fill = "分档")
  })

  output$cross_heatmap <- renderPlot({
    cross_tab <- pps[!is.na(risk_level_6) & !is.na(same_rate_bin), .N, by = .(risk_level_6, same_rate_bin)]
    ggplot(cross_tab, aes(same_rate_bin, risk_level_6, fill = N)) +
      geom_tile(color = "white") +
      geom_text(aes(label = N), size = 3) +
      scale_fill_gradient(low = "#fff5eb", high = "#d73027") +
      labs(title = "风险等级 × 同桌率分档", x = "同桌率分档", y = "风险等级") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 30, hjust = 1))
  })

  output$degree_dist <- renderPlot({
    ggplot(degree_dt, aes(degree)) +
      geom_histogram(binwidth = 1, fill = "#16a085", color = "white") +
      geom_vline(xintercept = mean(degree_dt$degree), linetype = "dashed", color = "red") +
      labs(title = "玩家关系网络度分布", x = "关系对数(度)", y = "玩家数") +
      theme_minimal()
  })

  output$duration_dist <- renderPlot({
    ggplot(pps, aes(duration_days)) +
      geom_histogram(bins = 25, fill = "mediumpurple", color = "white") +
      geom_vline(xintercept = mean(pps$duration_days), linetype = "dashed", color = "red") +
      labs(title = "持续时间分布", x = "持续天数", y = "频数") +
      theme_minimal()
  })

  output$density_dist <- renderPlot({
    ggplot(pps, aes(same_density)) +
      geom_histogram(bins = 25, fill = "darkorange", color = "white") +
      geom_vline(xintercept = mean(pps$same_density), linetype = "dashed", color = "red") +
      labs(title = "同桌密度分布(局/天)", x = "同桌密度", y = "频数") +
      theme_minimal()
  })

  output$asymmetry_dist <- renderPlot({
    ggplot(pps, aes(activity_asymmetry)) +
      geom_histogram(bins = 25, fill = "chocolate", color = "white") +
      geom_vline(xintercept = mean(pps$activity_asymmetry), linetype = "dashed", color = "red") +
      labs(title = "活跃度不对称分布(min/max)", x = "活跃度比率", y = "频数") +
      theme_minimal()
  })

  # ---- 交互式预测走势 ----
  output$forecast_plot <- renderPlotly({
    monthly_new <- pps[, .(count = .N), by = .(month = floor_date(first_game_time, "month"))][order(month)]

    if (nrow(monthly_new) >= 4) {
      ts_data <- ts(monthly_new$count, frequency = 12,
                    start = c(year(min(monthly_new$month)), month(min(monthly_new$month))))
      fit <- auto.arima(ts_data)
      fc  <- forecast(fit, h = input$forecast_horizon, level = 95)

      future_months <- seq(max(monthly_new$month) %m+% months(1), by = "month", length.out = input$forecast_horizon)
      forecast_dt <- data.table(
        month = future_months, count = as.numeric(fc$mean),
        lower = as.numeric(fc$lower[,1]), upper = as.numeric(fc$upper[,1]), type = "预测"
      )
      history_dt <- monthly_new[, .(month, count, lower = count, upper = count, type = "历史")]
      plot_dt <- rbind(history_dt, forecast_dt)

      p <- ggplot(plot_dt, aes(month, count, color = type)) +
        geom_ribbon(data = forecast_dt, aes(x = month, ymin = lower, ymax = upper),
                    fill = "orange", alpha = 0.2, inherit.aes = FALSE) +
        geom_line(linewidth = 1) +
        geom_point(size = 2) +
        scale_color_manual(values = c("历史" = "steelblue", "预测" = "firebrick")) +
        labs(title = "新增可疑配对趋势与预测", x = "月份", y = "新增配对数", color = NULL) +
        theme_minimal()
      ggplotly(p)
    } else {
      p <- ggplot(monthly_new, aes(month, count)) +
        geom_col(fill = "slateblue") +
        labs(title = "样本时间跨度不足4个月，暂不建模预测", x = "月份", y = "新增配对数") +
        theme_minimal()
      ggplotly(p)
    }
  })

  # ---- 荷官分析 ----
  dealer_data <- reactive({
    d <- dph
    if (input$exclude_sentinel) d <- d[dealer_id != -1]
    d[, .(
      总投注笔数 = sum(bet_count), 总流水 = sum(turnover), 总盈利 = sum(profit),
      平均胜率 = mean(win_rate), 平均玩家ROI = mean(player_roi), 涉及玩家数 = uniqueN(player_id)
    ), by = dealer_id][order(-总盈利)]
  })

  output$dealer_table <- renderDT({
    dd <- dealer_data()
    datatable(dd, options = list(pageLength = 15), rownames = FALSE) |>
      formatRound(columns = c("总流水", "总盈利", "平均胜率", "平均玩家ROI"), digits = 2) |>
      formatStyle("总盈利", background = styleColorBar(dd$总盈利, "#ffb3b3"))
  })

  output$dealer_roi_plot <- renderPlotly({
    dd <- dealer_data()
    p <- ggplot(dd, aes(x = reorder(factor(dealer_id), 平均玩家ROI), y = 平均玩家ROI, fill = 平均玩家ROI > 0)) +
      geom_col() +
      scale_fill_manual(values = c("TRUE" = "firebrick", "FALSE" = "steelblue"), guide = "none") +
      coord_flip() +
      labs(title = "各荷官对应玩家平均ROI", x = "dealer_id", y = "平均玩家ROI") +
      theme_minimal()
    ggplotly(p)
  })

  # ---- 时序模式 ----
  output$hourly_pattern_plot <- renderPlotly({
    hp <- pph[, .(新增配对数 = .N, 平均同桌局数 = mean(same_round_count)), by = stat_hour][order(stat_hour)]
    p <- ggplot(hp, aes(stat_hour, 新增配对数)) +
      geom_col(fill = "slateblue") +
      labs(title = "分小时新增同桌配对数量", x = "小时(0-23)", y = "记录数") +
      theme_minimal()
    ggplotly(p)
  })

  output$hourly_dealer_plot <- renderPlotly({
    hp2 <- dph[, .(小时盈利总额 = sum(profit)), by = stat_hour][order(stat_hour)]
    p <- ggplot(hp2, aes(stat_hour, 小时盈利总额)) +
      geom_line(color = "darkorange", linewidth = 1) +
      geom_point(color = "darkorange", size = 2) +
      labs(title = "分小时荷官盈利总额趋势", x = "小时(0-23)", y = "盈利总额") +
      theme_minimal()
    ggplotly(p)
  })
}

shinyApp(ui, server)
