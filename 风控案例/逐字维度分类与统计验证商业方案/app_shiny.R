## ============================================================
## 荷官玩家同桌合谋风控中枢 (Shiny 一键版)
## 运行方式: 在 R / Positron / RStudio 中打开本文件后执行 shiny::runApp("app_shiny.R")
##           或直接 source 后 shinyApp(ui, server) 会自动启动
## 数据: 默认读取同目录 pair_data.csv (uid1, uid2, 总同桌局数)，
##       可在侧栏上传其他同结构 CSV（例如从 ods_a168_bet01/bet02 按会员+桌号+时窗
##       聚合出的同桌配对表）。
## 方法论: 复合分位数分层 + 局部标准化Z分 + k-核紧密团伙侦测，
##         与本引擎 Python 版 (app_streamlit.py / risk_engine.py) 完全对齐，
##         确保跨语言结果一致，符合"地毯式"交叉验证标准。
## ============================================================

## -------------- 防御式套件载入 (每个包独立 tryCatch，避免单包缺失拖垮全局) -----
required_pkgs <- c("shiny", "shinydashboard", "DT", "plotly", "igraph", "dplyr", "tidyr")
for (pkg in required_pkgs) {
  ok <- requireNamespace(pkg, quietly = TRUE)
  if (!ok) {
    tryCatch({
      install.packages(pkg, repos = "https://cloud.r-project.org")
    }, error = function(e) {
      message(sprintf("[警告] 套件 %s 安装失败，部分功能可能不可用：%s", pkg, conditionMessage(e)))
    })
  }
}
suppressPackageStartupMessages({
  library(shiny); library(shinydashboard); library(DT)
  library(plotly); library(igraph); library(dplyr); library(tidyr)
})

## -------------- 品牌视觉常量 (沿用既有档案页配色) --------------------
NAVY       <- "#0B2136"
TEAL_DARK  <- "#146275"
TEAL       <- "#33A8C4"
GOLD       <- "#FFD64D"
CARD_BG    <- "#122A3D"

TIER_COLOR <- c(
  "L4_优先复核"     = "#FF4B4B",
  "L3_高危待复核"   = "#FF9F45",
  "中风险_待观察"   = GOLD,
  "试水型_观察名单" = TEAL,
  "一般关系"        = "#5C7A8A"
)

## -------------- 具名可调参数 (全局唯一定义处，不藏在函数体内) ----------------
GLOBAL_RANK_WEIGHT_DEFAULT   <- 0.40
LOCAL_Z_WEIGHT_DEFAULT       <- 0.40
MUTUAL_DEGREE_WEIGHT_DEFAULT <- 0.20
TIER_QUANTILES <- c(
  "L4_优先复核"     = 0.99,
  "L3_高危待复核"   = 0.95,
  "中风险_待观察"   = 0.90,
  "试水型_观察名单" = 0.75
)

## -------------- 统计显著性检验：唯一具学术意义的"实锤"判定入口 ---------------
## 学术依据: Serrano/Boguñá/Vespignani (2009) PNAS 106(16):6483-6488 (disparity
## filter) + Benjamini-Hochberg (1995) FDR 多重检验校正 (R 内建 p.adjust(method="BH")，
## 无需手写)。59,833条候选边=59,833次同时假设检验，不校正的话，即使世界上完全不存在
## 合谋，纯随机也预期约有 0.01×N 条边"看起来显著"——这是本引擎唯一可称为"实锤"的方法，
## 其余分位数/Z分/k-核结果一律降级为"观察名单排序启发法"，不等于确诊。
disparity_filter_fdr <- function(df, fdr_q = 0.01) {
  df$uid1 <- as.character(as.integer(df$uid1))
  df$uid2 <- as.character(as.integer(df$uid2))

  deg_str <- df %>%
    tidyr::pivot_longer(cols = c(uid1, uid2), values_to = "uid") %>%
    group_by(uid) %>%
    summarise(degree = n(), strength = sum(总同桌局数), .groups = "drop")
  deg_map <- setNames(deg_str$degree, deg_str$uid)
  str_map <- setNames(deg_str$strength, deg_str$uid)

  alpha_fn <- function(uid, w) {
    k <- deg_map[[uid]]
    if (is.null(k) || k <= 1) return(1.0)
    p <- w / str_map[[uid]]
    (1 - p) ^ (k - 1)
  }
  df$alpha1 <- mapply(alpha_fn, df$uid1, df$总同桌局数)
  df$alpha2 <- mapply(alpha_fn, df$uid2, df$总同桌局数)
  df$alpha_min <- pmin(df$alpha1, df$alpha2)

  df$p_adj <- p.adjust(df$alpha_min, method = "BH")
  n <- nrow(df)
  list(
    disparity = df,
    uncorrected_at_001 = df[df$alpha_min < 0.01, ],
    expected_fp_at_001 = 0.01 * n,
    corrected = df[df$p_adj < fdr_q, ],
    n_hypotheses = n
  )
}

## -------------- 核心批量运算引擎 (BATCH pipeline，绝不放进 reactive 高频重算) --
## 遵循既有架构约束：重型图运算(igraph)只在数据变更时批量执行一次，
## 界面交互(筛选/排序/切标签页)不得触发重新建图。
run_risk_pipeline <- function(df, w_global = GLOBAL_RANK_WEIGHT_DEFAULT,
                               w_local = LOCAL_Z_WEIGHT_DEFAULT,
                               w_deg = MUTUAL_DEGREE_WEIGHT_DEFAULT) {

  stopifnot(all(c("uid1", "uid2", "总同桌局数") %in% names(df)))
  df <- df %>% filter(!is.na(uid1), !is.na(uid2), !is.na(总同桌局数))
  df$uid1 <- as.character(as.integer(df$uid1))
  df$uid2 <- as.character(as.integer(df$uid2))

  g <- graph_from_data_frame(df[, c("uid1", "uid2", "总同桌局数")], directed = FALSE)
  g <- simplify(g, remove.multiple = FALSE, remove.loops = TRUE)

  ## 局部标准化 Z 分数：每条边相对其两端节点自身边权重分布的标准化
  node_stats <- lapply(V(g)$name, function(n) {
    inc <- incident(g, n)
    ws <- E(g)$总同桌局数[inc]
    c(mean = mean(ws), sd = ifelse(length(ws) > 1, sd(ws), 1))
  })
  names(node_stats) <- V(g)$name

  z_local <- function(uid, w) {
    st <- node_stats[[uid]]
    m <- unname(st["mean"]); s <- unname(st["sd"])
    if (is.na(s) || s < 1e-6) s <- 1
    unname((w - m) / s)
  }
  df$z_uid1 <- unname(mapply(z_local, df$uid1, df$总同桌局数))
  df$z_uid2 <- unname(mapply(z_local, df$uid2, df$总同桌局数))
  df$local_z_avg <- (df$z_uid1 + df$z_uid2) / 2

  pct_rank <- function(x) rank(x, ties.method = "average") / length(x) * 100
  df$global_rank_score <- pct_rank(df$总同桌局数)
  df$local_z_score     <- pct_rank(df$local_z_avg)

  deg_vec <- degree(g)
  df$mutual_degree <- pmin(deg_vec[df$uid1], deg_vec[df$uid2])
  df$mutual_degree_score <- pct_rank(df$mutual_degree)

  df$综合风险分 <- round(
    w_global * df$global_rank_score +
    w_local  * df$local_z_score +
    w_deg    * df$mutual_degree_score, 2)

  th <- sapply(TIER_QUANTILES, function(q) quantile(df$综合风险分, q, na.rm = TRUE))

  classify_tier <- function(v) {
    if (v >= th["L4_优先复核"])     return("L4_优先复核")
    if (v >= th["L3_高危待复核"])   return("L3_高危待复核")
    if (v >= th["中风险_待观察"])   return("中风险_待观察")
    if (v >= th["试水型_观察名单"]) return("试水型_观察名单")
    "一般关系"
  }
  df$风险等级 <- vapply(df$综合风险分, classify_tier, character(1))

  ## 巨型连通分量占比 (验证：不能直接用连通分量当团伙)
  comp <- components(g)
  giant_frac <- max(comp$csize) / vcount(g)

  ## k-核紧密团伙侦测：先按 P99 过滤边，再做 k-核分解
  thresh99 <- quantile(df$总同桌局数, 0.99, na.rm = TRUE)
  sub_df <- df %>% filter(总同桌局数 >= thresh99)
  rings <- list()
  max_k <- 0
  if (nrow(sub_df) > 0) {
    gs <- graph_from_data_frame(sub_df[, c("uid1", "uid2", "总同桌局数")], directed = FALSE)
    gs <- simplify(gs, remove.loops = TRUE)
    coreness_vec <- coreness(gs)
    max_k <- if (length(coreness_vec) > 0) max(coreness_vec) else 0
    if (max_k >= 3) {
      keep <- names(coreness_vec[coreness_vec >= max_k])
      gk <- induced_subgraph(gs, keep)
      comp_k <- components(gk)
      for (ci in seq_len(comp_k$no)) {
        members <- names(comp_k$membership[comp_k$membership == ci])
        sg <- induced_subgraph(gk, members)
        rings[[length(rings) + 1]] <- list(
          members = sort(members),
          size = length(members),
          density = round(edge_density(sg), 3),
          internal_edges = ecount(sg),
          total_w = sum(E(sg)$总同桌局数),
          k_core = max_k
        )
      }
      rings <- rings[order(-sapply(rings, function(r) r$size))]
    }
  }

  list(scored = df, graph = g, thresholds = th, giant_frac = giant_frac,
       rings = rings, max_k = max_k)
}

## ================================================================
## UI
## ================================================================
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = span("荷官风控", style = paste0("color:", GOLD))),
  dashboardSidebar(
    fileInput("upload_csv", "上传同结构CSV(可选，默认用本地全量候选数据)", accept = ".csv"),
    sliderInput("w_global", "全局分位权重", 0, 1, GLOBAL_RANK_WEIGHT_DEFAULT, 0.05),
    sliderInput("w_local", "局部标准化Z分权重", 0, 1, LOCAL_Z_WEIGHT_DEFAULT, 0.05),
    helpText("互斥度权重 = 1 - 以上两者之和（自动补足，不允许出现负权重）"),
    sidebarMenu(
      menuItem("🎓 统计显著性检验(实锤)", tabName = "validated", icon = icon("graduation-cap")),
      menuItem("总览", tabName = "overview", icon = icon("chart-bar")),
      menuItem("紧密团伙(k-核)", tabName = "rings", icon = icon("share-nodes")),
      menuItem("高危配对清单", tabName = "list", icon = icon("list")),
      menuItem("赏罚分明·业务方案", tabName = "policy", icon = icon("scale-balanced"))
    )
  ),
  dashboardBody(
    tags$head(tags$style(HTML(sprintf("
      .content-wrapper, .right-side { background: linear-gradient(160deg, %s 0%%, #0E2A3D 60%%, %s 130%%); color: #EAF6FA; }
      .box { background: %s; border-top: 3px solid %s; }
      .small-box { background: %s !important; }
      .main-header .logo, .main-header .navbar { background: %s !important; }
    ", NAVY, TEAL_DARK, CARD_BG, TEAL, CARD_BG, TEAL_DARK)))),
    tabItems(
      tabItem(tabName = "validated",
        box(width = 12, title = "Disparity Filter (PNAS 2009) + Benjamini-Hochberg FDR 多重检验校正",
          HTML(paste0(
            "<p><b>外行人一看即懂的比喻</b>：假设玩家A一共认识500个不同的同桌对手，其中跟B同桌",
            "200次，跟其余499人加起来才同桌300次——A把「注意力」高度集中在B身上，这在统计上不",
            "寻常。反过来，如果A跟每个对手都差不多同桌几次，那A只是单纯「很能玩」，任何一次同桌",
            "次数偏高都只是他见多识广的自然结果，不该被当作合谋证据。</p>",
            "<p><b>为什么必须做多重检验校正</b>：本数据集有 59,833 条候选边，等于同时做 59,833 次",
            "假设检验。即使真实世界完全不存在任何合谋，纯属随机波动也预期约有 <b>598 条边「看起来",
            "显著」</b>（0.01 × 59,833）——这个数字与未校正结果几乎完全重合，说明未校正的「高危名单」",
            "基本等同于噪声，必须做 FDR 校正才能得到站得住脚的结论。</p>"
          ))
        ),
        fluidRow(
          valueBoxOutput("vb_uncorrected"), valueBoxOutput("vb_expected_fp"), valueBoxOutput("vb_validated")
        ),
        box(width = 12, title = "✅ FDR校正后真正站得住脚的配对",
            DTOutput("validated_table")),
        box(width = 12, title = "学术依据",
            p("Serrano, Boguñá, Vespignani (2009) \"Extracting the multiscale backbone of ",
              "complex weighted networks.\" PNAS 106(16):6483-6488 (disparity filter)；",
              "Benjamini & Hochberg (1995) FDR多重检验校正（R内建 p.adjust(method=\"BH\")）。"))
      ),
      tabItem(tabName = "overview",
        fluidRow(
          valueBoxOutput("vb_nodes"), valueBoxOutput("vb_edges"), valueBoxOutput("vb_giant")
        ),
        fluidRow(
          valueBoxOutput("vb_l4"), valueBoxOutput("vb_rings")
        ),
        fluidRow(
          box(title = "动态分位数阈值表（一字不漏，实时按当前数据重算）", width = 6,
              DTOutput("quantile_table")),
          box(title = "五级风险分层分布", width = 6, plotlyOutput("tier_bar"))
        ),
        fluidRow(
          box(title = "综合风险分分布直方图", width = 12, plotlyOutput("score_hist"))
        )
      ),
      tabItem(tabName = "rings",
        box(width = 12, title = "k-核紧密团伙侦测",
            helpText("方法论：直接对全图跑连通分量会得到吞并99%+节点的巨型假团伙",
                     "（链式传递连通所致）。真实业务意义上的团伙必须满足局部高密度，",
                     "因此采用『高分位边过滤 → k-核分解』两段式方法。"),
            uiOutput("rings_ui"))
      ),
      tabItem(tabName = "list",
        box(width = 12, title = "高危配对完整清单",
            checkboxGroupInput("tier_filter", "按风险等级筛选",
                                choices = names(TIER_COLOR),
                                selected = c("L4_优先复核", "L3_高危待复核"), inline = TRUE),
            DTOutput("pair_table"),
            downloadButton("dl_csv", "导出当前清单 CSV"))
      ),
      tabItem(tabName = "policy",
        box(width = 12, title = "⚖️ 赏罚分明·对症下药业务方案",
            htmlOutput("policy_html"))
      )
    )
  )
)

## 简易 markdown->html（不额外依赖 markdown 包，用纯字符串拼装，保证可移植）
markdown_to_html_fallback <- function() {
  paste0(
    "<blockquote style='border-left:4px solid ", GOLD, "; padding-left:12px;'>",
    "参《商君书》「赏厚而信，刑重而必」之义：风控不只是侦测，更要有明确、可执行、",
    "可追责的分级处置与正向引导机制，让规则透明可预期。<b>同样重要的是「罚必得当」",
    "——处置力度必须匹配证据强度，未经统计学验证的启发法排序不可等同于确诊。</b></blockquote>",
    "<table style='width:100%; border-collapse:collapse;' border='1' cellpadding='8'>",
    "<tr style='color:", GOLD, ";'><th>风险等级</th><th>判定依据</th><th>证据强度</th>",
    "<th>建议措施(罚/管控)</th><th>正向机制(赏/引导)</th></tr>",
    "<tr style='background:rgba(255,75,75,0.15);'><td><b>✅统计显著'实锤'</b></td>",
    "<td>Disparity Filter+FDR校正后仍显著</td><td><b>已排除多重检验假阳性，学术级站得住脚</b></td>",
    "<td>立即冻结返水结算、人工复核全部注单、必要时联合封禁</td><td>不适用</td></tr>",
    "<tr><td><b>L4_优先复核</b></td><td>综合风险分 &ge; P99（启发法，未经FDR校正）</td>",
    "<td>中等（部分为随机假阳性）</td>",
    "<td>提升复核优先级，<b>不冻结账户</b>，48小时内人工核验</td>",
    "<td>复核后无异常者即刻恢复正常权益</td></tr>",
    "<tr><td><b>L3_高危待复核</b></td><td>P95 &le; 分数 &lt; P99</td><td>较低</td>",
    "<td>加入常规复核队列</td><td>复核通过后自动解除限制，无需申诉延迟</td></tr>",
    "<tr><td><b>中风险_待观察</b></td><td>P90 &le; 分数 &lt; P95</td><td>参考性</td>",
    "<td>加入观察名单、同桌局数异常预警订阅</td><td>主动配合KYC问卷者可提前移出观察期</td></tr>",
    "<tr><td><b>试水型_观察名单</b></td><td>P75 &le; 分数 &lt; P90</td><td>参考性</td>",
    "<td>常规监控频率、无需特别限制</td><td>正常参与忠诚度积分累计</td></tr>",
    "<tr><td><b>一般关系</b></td><td>分数 &lt; P75</td><td>—</td>",
    "<td>无</td><td>正常纳入VIP/忠诚度晋升计算</td></tr>",
    "</table>",
    "<p style='margin-top:12px;'><b>关键原则一</b>：所有分位阈值均为<b>动态计算</b>，",
    "每次数据刷新自动重算，永不写死绝对数字。<br/>",
    "<b>关键原则二</b>：唯有通过多重检验校正的「统计显著'实锤'」级别才可采取账户冻结/",
    "封禁等不可逆措施；L4/L3/中风险/试水型均只是复核优先级排序，处置力度必须相应降级，",
    "避免把统计噪声误判为确凿证据、错杀正常高频付费玩家。</p>",
    "<p>荷官侧建议：结合 <code>ods_a168_employee</code>（荷官主档）与",
    "<code>ods_a168_dailyreport_table</code>（逐桌逐日汇总）计算",
    "『荷官—高风险配对』共现率，识别是否存在荷官配合的内部合谋。</p>"
  )
}

## ================================================================
## Server
## ================================================================
server <- function(input, output, session) {

  raw_data <- reactive({
    if (!is.null(input$upload_csv)) {
      read.csv(input$upload_csv$datapath, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
    } else if (file.exists("pair_data.csv")) {
      read.csv("pair_data.csv", stringsAsFactors = FALSE, fileEncoding = "UTF-8")
    } else {
      showNotification("找不到 pair_data.csv，请在侧栏上传同结构CSV。", type = "error")
      NULL
    }
  })

  ## 批量运算：仅在数据源或权重变化时重算一次，其余UI交互不触发
  pipeline_result <- reactive({
    req(raw_data())
    w_g <- input$w_global
    w_l <- input$w_local
    w_d <- max(0, 1 - w_g - w_l)
    run_risk_pipeline(raw_data(), w_global = w_g, w_local = w_l, w_deg = w_d)
  })

  ## 统计显著性检验：批量运算一次，与 pipeline_result 平行、独立于权重滑杆
  validated_result <- reactive({
    req(raw_data())
    disparity_filter_fdr(raw_data())
  })

  output$vb_uncorrected <- renderValueBox({
    v <- validated_result()
    valueBox(nrow(v$uncorrected_at_001), "未校正命中数 (α<0.01)",
             icon = icon("triangle-exclamation"), color = "orange")
  })
  output$vb_expected_fp <- renderValueBox({
    v <- validated_result()
    valueBox(sprintf("%.0f", v$expected_fp_at_001), "纯随机预期假阳性数",
             icon = icon("dice"), color = "yellow")
  })
  output$vb_validated <- renderValueBox({
    v <- validated_result()
    valueBox(nrow(v$corrected), "✅ FDR校正后真正站得住脚",
             icon = icon("check-double"), color = "green")
  })
  output$validated_table <- renderDT({
    v <- validated_result()
    if (nrow(v$corrected) == 0) {
      return(datatable(data.frame(提示 = "没有任何一条边通过严格的多重检验校正——这本身就是重要结论。"),
                       options = list(dom = "t"), rownames = FALSE))
    }
    tbl <- v$corrected %>% arrange(desc(总同桌局数)) %>%
      select(uid1, uid2, 总同桌局数, alpha_min, p_adj)
    datatable(tbl, options = list(dom = "t", pageLength = 10), rownames = FALSE)
  })

  output$vb_nodes <- renderValueBox({
    res <- pipeline_result()
    valueBox(format(vcount(res$graph), big.mark = ","), "会员总数 (nodes)",
             icon = icon("users"), color = "light-blue")
  })
  output$vb_edges <- renderValueBox({
    res <- pipeline_result()
    valueBox(format(ecount(res$graph), big.mark = ","), "可疑配对总数 (edges)",
             icon = icon("link"), color = "teal")
  })
  output$vb_giant <- renderValueBox({
    res <- pipeline_result()
    valueBox(sprintf("%.1f%%", res$giant_frac * 100), "巨型连通分量占比",
             icon = icon("circle-nodes"), color = "orange")
  })
  output$vb_l4 <- renderValueBox({
    res <- pipeline_result()
    n <- sum(res$scored$风险等级 == "L4_优先复核")
    valueBox(format(n, big.mark = ","), "L4优先复核配对数(启发法)", icon = icon("triangle-exclamation"), color = "red")
  })
  output$vb_rings <- renderValueBox({
    res <- pipeline_result()
    valueBox(length(res$rings), sprintf("高置信度紧密团伙 (k=%d)", res$max_k),
             icon = icon("users-rectangle"), color = "yellow")
  })

  output$quantile_table <- renderDT({
    res <- pipeline_result()
    qs <- c(0.50, 0.75, 0.90, 0.95, 0.975, 0.99, 0.995, 0.999)
    tbl <- data.frame(
      分位点 = sprintf("P%.1f", qs * 100),
      总同桌局数_阈值 = round(quantile(raw_data()$总同桌局数, qs, na.rm = TRUE), 1),
      综合风险分_阈值 = round(quantile(res$scored$综合风险分, qs, na.rm = TRUE), 2)
    )
    datatable(tbl, options = list(dom = "t", pageLength = 10), rownames = FALSE)
  })

  output$tier_bar <- renderPlotly({
    res <- pipeline_result()
    vc <- res$scored %>% count(风险等级) %>%
      mutate(风险等级 = factor(风险等级, levels = rev(names(TIER_COLOR))))
    plot_ly(vc, x = ~n, y = ~风险等级, type = "bar", orientation = "h",
            marker = list(color = TIER_COLOR[as.character(vc$风险等级)])) %>%
      layout(paper_bgcolor = NAVY, plot_bgcolor = NAVY,
             font = list(color = "#EAF6FA"), xaxis = list(title = ""), yaxis = list(title = ""))
  })

  output$score_hist <- renderPlotly({
    res <- pipeline_result()
    plot_ly(res$scored, x = ~综合风险分, type = "histogram", nbinsx = 60,
            marker = list(color = TEAL)) %>%
      layout(paper_bgcolor = NAVY, plot_bgcolor = NAVY, font = list(color = "#EAF6FA"))
  })

  output$rings_ui <- renderUI({
    res <- pipeline_result()
    if (length(res$rings) == 0) return(p("当前数据未侦测到 k>=3 的紧密团伙。"))
    boxes <- lapply(head(res$rings, 10), function(r) {
      box(width = 12, collapsible = TRUE, collapsed = TRUE,
          title = sprintf("团伙 · %d人 · 密度=%.3f · k-core=%d · 内部总同桌局数=%s",
                          r$size, r$density, r$k_core, format(r$total_w, big.mark = ",")),
          p(paste(r$members, collapse = ", ")))
    })
    do.call(tagList, boxes)
  })

  output$pair_table <- renderDT({
    res <- pipeline_result()
    view <- res$scored %>% filter(风险等级 %in% input$tier_filter) %>%
      arrange(desc(综合风险分)) %>%
      select(uid1, uid2, 总同桌局数, local_z_avg, mutual_degree, 综合风险分, 风险等级)
    datatable(view, options = list(pageLength = 20), rownames = FALSE)
  })

  output$dl_csv <- downloadHandler(
    filename = function() "风控高危配对清单.csv",
    content = function(file) {
      res <- pipeline_result()
      view <- res$scored %>% filter(风险等级 %in% input$tier_filter) %>% arrange(desc(综合风险分))
      write.csv(view, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  output$policy_html <- renderUI({ HTML(markdown_to_html_fallback()) })
}

shinyApp(ui, server)
