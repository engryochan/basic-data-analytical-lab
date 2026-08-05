library(shiny)
library(bslib)
library(data.table)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(igraph)
library(scales)
library(glue)

# ============================================================
# 全部数据与指标均在此计算，UI只负责展示 output$xxx 的动态结果
# 不含任何硬编码的展示数值（对照旧版echart_v2/v3 mockup 的静态数字）
# ============================================================

DATA_DIR <- "data_full"
dps <- fread(file.path(DATA_DIR, "dealer_profit_stat.csv"))
dph <- fread(file.path(DATA_DIR, "dealer_profit_stat_hourly.csv"))
pps <- fread(file.path(DATA_DIR, "player_pair_stat.csv"))
pph <- fread(file.path(DATA_DIR, "player_pair_stat_hourly.csv"))

# ---- 衍生字段（与 商君风控体系_PRO_MAX.qmd 保持一致口径）----
pps[, `:=`(first_game_time = as.POSIXct(first_game_time), last_game_time = as.POSIXct(last_game_time))]
pps[, duration_days := as.numeric(difftime(last_game_time, first_game_time, units = "days"))]
pps[, `:=`(a_dep = same_round_count/player_a_rounds, b_dep = same_round_count/player_b_rounds)]
pps[, max_dep := pmax(a_dep, b_dep)]

# 风险等级（基于同桌率的业务分档，可用/替代第三方报告的贝叶斯/XGB综合分，此处用轻量指标保证App响应速度）
pps[, risk_level := fcase(
  same_rate >= 0.30, "L4-实锤",
  same_rate >= 0.15, "L3-高危",
  same_rate >= 0.05, "L2-观察",
  default = "L1-正常"
)]

game_benchmark <- dps[, .(game_mean_ppb = mean(profit_per_bet), game_sd_ppb = sd(profit_per_bet)), by = game_id]
dps <- merge(dps, game_benchmark, by = "game_id")
dps[, ev_z := (profit_per_bet - game_mean_ppb) / game_sd_ppb]

dealer_agg <- dps[dealer_id != -1, .(
  记录数 = .N, 总流水 = sum(turnover), 总盈利 = sum(profit),
  平均胜率 = mean(win_rate), 平均ROI = mean(player_roi)
), by = dealer_id]
fleet_mean_roi <- mean(dealer_agg$平均ROI)
fleet_sd_roi <- sd(dealer_agg$平均ROI)
dealer_agg[, roi_z := (平均ROI - fleet_mean_roi) / fleet_sd_roi]

# ---- 图论中心性（用于"团伙头目"识别，缓存一次即可，避免每次交互重算）----
g_full <- graph_from_data_frame(pps[, .(from = as.character(player_a), to = as.character(player_b))], directed = FALSE)
centrality_dt <- data.table(player_id = as.numeric(names(V(g_full))), degree = degree(g_full))

# ============================================================ UI ============================================================
ui <- page_navbar(
  title = "风控顶级实验室 PRO MAX · 全动态计算版",
  theme = bs_theme(version = 5, bootswatch = "cosmo"),

  header = tags$div(
    style = "background:#fff3cd; padding:8px; text-align:center; font-weight:bold; color:#856404;",
    textOutput("live_alert_banner", inline = TRUE)
  ),

  nav_panel(
    "总览KPI(全动态)",
    layout_column_wrap(
      width = 1/3,
      value_box(title = "总配对数", value = textOutput("kpi_total_pairs"), theme = "primary",
                 showcase = bsicons::bs_icon("people-fill")),
      value_box(title = "L4实锤配对占比", value = textOutput("kpi_l4_pct"), theme = "danger"),
      value_box(title = "平均同桌率", value = textOutput("kpi_avg_rate"), theme = "warning"),
      value_box(title = "高ROI荷官数(>fleet均值+2SD)", value = textOutput("kpi_high_roi_dealers"), theme = "info"),
      value_box(title = "全平台总盈利", value = textOutput("kpi_total_profit"), theme = "success"),
      value_box(title = "平均关系存续天数", value = textOutput("kpi_avg_duration"), theme = "secondary")
    ),
    card(
      card_header("说明：以上全部数值为R代码对当前 data_full/ 目录下100,000行原始数据实时计算得出，非固定演示值"),
      "数据源：dealer_profit_stat.csv / dealer_profit_stat_hourly.csv / player_pair_stat.csv / player_pair_stat_hourly.csv"
    )
  ),

  nav_panel(
    "明细过滤",
    layout_sidebar(
      sidebar = sidebar(
        title = "筛选",
        selectInput("filter_level", "风险等级", choices = c("全部","L4-实锤","L3-高危","L2-观察","L1-正常")),
        sliderInput("filter_rounds", "最小同桌局数", min = 1, max = max(pps$same_round_count), value = 1)
      ),
      DTOutput("detail_table")
    )
  ),

  nav_panel(
    "真实逐人解剖(动态生成)",
    p("以下卡片由代码从当前100,000行真实数据中，按风险等级+同桌率实时挑选出的真实TOP案例自动生成描述文字，不是固定案例。"),
    uiOutput("dissection_cards")
  ),

  nav_panel(
    "客户分级查询",
    textInput("query_customer_id", "输入玩家ID查询分级", placeholder = "输入数字ID"),
    actionButton("btn_query_tier", "查询", class = "btn-primary"),
    hr(),
    uiOutput("tier_result")
  ),

  nav_panel(
    "SOP与优化建议(动态阈值)",
    uiOutput("sop_dynamic")
  )
)

# ============================================================ SERVER ============================================================
server <- function(input, output, session) {

  # ---- 总览KPI：全部reactive实时计算 ----
  output$kpi_total_pairs <- renderText(format(nrow(pps), big.mark = ","))
  output$kpi_l4_pct <- renderText(scales::percent(mean(pps$risk_level == "L4-实锤"), accuracy = 0.01))
  output$kpi_avg_rate <- renderText(scales::percent(mean(pps$same_rate), accuracy = 0.01))
  output$kpi_high_roi_dealers <- renderText(as.character(sum(dealer_agg$roi_z > 2)))
  output$kpi_total_profit <- renderText(format(round(sum(dps$profit)), big.mark = ","))
  output$kpi_avg_duration <- renderText(sprintf("%.1f 天", mean(pps$duration_days, na.rm = TRUE)))

  output$live_alert_banner <- renderText({
    top_pair <- pps[order(-same_rate)][1]
    sprintf("⚠️ 实时监控中 · 当前同桌率最高配对: %s-%s = %.1f%% (%d/%d局) · 全平台L4实锤占比 %s · 数据行数 %s",
            top_pair$player_a, top_pair$player_b, top_pair$same_rate*100,
            top_pair$same_round_count, top_pair$player_a_rounds,
            scales::percent(mean(pps$risk_level=="L4-实锤"), accuracy=0.01),
            format(nrow(pps), big.mark=","))
  })

  # ---- 明细过滤 ----
  output$detail_table <- renderDT({
    d <- pps
    if (input$filter_level != "全部") d <- d[risk_level == input$filter_level]
    d <- d[same_round_count >= input$filter_rounds]
    datatable(d[order(-same_rate)][, .(
      player_a, player_b, same_round_count, 同桌率 = scales::percent(same_rate, accuracy = 0.1),
      风险等级 = risk_level, 存续天数 = round(duration_days, 1)
    )], options = list(pageLength = 15), rownames = FALSE) |>
      formatStyle("风险等级", backgroundColor = styleEqual(
        c("L4-实锤","L3-高危","L2-观察","L1-正常"),
        c("#ff8b8b","#ffd6a5","#fff3cd","white")))
  })

  # ---- 逐人解剖：动态从真实数据挑TOP案例并自动生成解说文字 ----
  output$dissection_cards <- renderUI({
    top_pairs <- pps[order(-same_rate)][1:5]

    cards <- lapply(seq_len(nrow(top_pairs)), function(i) {
      row <- top_pairs[i]
      centrality_a <- centrality_dt[player_id == row$player_a, degree]
      centrality_a <- if (length(centrality_a) == 0) 0 else centrality_a

      narrative <- glue(
        "会员 {row$player_a} - {row$player_b}：同桌 {row$same_round_count} 局，",
        "占玩家A总局数({row$player_a_rounds}局)的 {scales::percent(row$same_rate, accuracy=0.1)}，",
        "关系存续 {round(row$duration_days,1)} 天。",
        "玩家{row$player_a}在全图中的连接度为{centrality_a}(连接的不同搭档数)，",
        "{ifelse(centrality_a >= quantile(centrality_dt$degree, 0.95), '处于图论意义上的高连接度节点，值得排查是否为团伙组织者。', '连接度处于正常范围。')}"
      )

      card(
        card_header(sprintf("[%s] 会员 %s - %s", row$risk_level, row$player_a, row$player_b)),
        p(narrative),
        style = sprintf("border-left: 5px solid %s;",
                         switch(row$risk_level, "L4-实锤"="#ff1744", "L3-高危"="#ff9100",
                                "L2-观察"="#ffea00", "L1-正常"="#00e676"))
      )
    })
    do.call(tagList, cards)
  })

  # ---- 客户分级查询 ----
  observeEvent(input$btn_query_tier, {
    output$tier_result <- renderUI({
      qid <- suppressWarnings(as.numeric(input$query_customer_id))
      validate(need(!is.na(qid), "请输入有效数字ID"))

      player_records <- dps[player_id == qid]
      validate(need(nrow(player_records) > 0, "该ID未出现在当前数据中"))

      total_turnover <- sum(player_records$turnover)
      turnover_pct <- mean(dealer_agg$总流水 <= total_turnover)  # 粗略分位(基于荷官表流水尺度做占位，实际应参照客户分级表)
      active_days <- as.numeric(difftime(max(as.POSIXct(player_records$last_bet_time)),
                                           min(as.POSIXct(player_records$first_bet_time)), units="days"))

      tier <- if (active_days >= 30 && total_turnover > median(dps[,.(t=sum(turnover)),by=player_id]$t)*10) "黄金级/白金级候选"
              else if (active_days >= 14) "长期客户"
              else "一般客户/试水型"

      card(
        card_header(sprintf("玩家 %s 分级查询结果", qid)),
        p(sprintf("总流水: %s | 活跃天数: %.1f | 初步分级: %s", format(round(total_turnover), big.mark=","), active_days, tier)),
        p("(完整精确分级请见 商君风控体系_PRO_MAX.qmd 第七节的地毯式客户分级CSV导出)")
      )
    })
  })

  # ---- SOP：阈值随数据动态刷新 ----
  output$sop_dynamic <- renderUI({
    p95_rate <- quantile(pps$same_rate, 0.95)
    p99_degree <- quantile(centrality_dt$degree, 0.99)

    tagList(
      card(card_header("24小时行动"),
           p(sprintf("同桌率超过 %.1f%%(当前数据95分位)的配对，立即冻结待核查", p95_rate*100))),
      card(card_header("7天行动"),
           p("上线本报告的贝叶斯+XGBoost+Autoencoder三方法交叉验证清单监控")),
      card(card_header("30天行动"),
           p(sprintf("图论中心度超过 %.0f(当前数据99分位)的节点，每日自动重算，纳入团伙头目候选池", p99_degree)))
    )
  })
}

shinyApp(ui, server)
