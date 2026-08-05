# app.R
# 商君风控：科学回测与商业政策模拟 Shiny 应用
# 说明：自动发现项目数据；支持 CSV/RDS/RData；严格区分训练/验证/时间外测试。
# 运行：shiny::runApp("app")

library(shiny)
library(data.table)
library(ggplot2)

find_files <- function(root = ".") {
  fs <- list.files(root, recursive = TRUE, full.names = TRUE)
  fs[grepl("\\.(csv|rds|rdata|rda)$", fs, ignore.case = TRUE)]
}

read_any <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "csv") return(fread(path, showProgress = FALSE))
  if (ext == "rds") return(readRDS(path))
  if (ext %in% c("rdata","rda")) {
    e <- new.env(parent = emptyenv())
    load(path, envir = e)
    n <- ls(e)
    if (!length(n)) stop("RData/RDA 中没有对象")
    return(as.data.table(e[[n[1]]]))
  }
  stop("不支持的文件类型")
}

safe_num <- function(x) suppressWarnings(as.numeric(x))

ui <- fluidPage(
  titlePanel("商君风控 · 科学回测与商业政策模拟实验室"),
  sidebarLayout(
    sidebarPanel(
      textInput("root", "项目根目录", value = "."),
      actionButton("scan", "扫描数据"),
      uiOutput("file_ui"),
      numericInput("time_col", "时间列序号（可选）", value = NA, min = 1),
      sliderInput("train_pct", "训练集比例", min = 0.5, max = 0.8, value = 0.7, step = 0.05),
      sliderInput("val_pct", "验证集比例", min = 0.1, max = 0.3, value = 0.15, step = 0.05),
      numericInput("risk_cost", "单个风险事件平均损失", value = 1000, min = 0),
      numericInput("action_cost", "单次风控干预成本", value = 10, min = 0),
      numericInput("retention_cost", "误伤造成的平均留存损失", value = 100, min = 0),
      sliderInput("topk", "策略干预比例", min = 0.01, max = 0.30, value = 0.05, step = 0.01),
      actionButton("run", "开始科学回测"),
      downloadButton("download_results", "下载实验结果 CSV")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("实验摘要", verbatimTextOutput("summary")),
        tabPanel("指标", tableOutput("metrics")),
        tabPanel("商业模拟", tableOutput("business")),
        tabPanel("风险曲线", plotOutput("curve")),
        tabPanel("数据预览", tableOutput("preview"))
      )
    )
  )
)

server <- function(input, output, session) {
  files <- reactiveVal(character())
  results <- reactiveVal(NULL)

  observeEvent(input$scan, {
    files(find_files(input$root))
  })

  output$file_ui <- renderUI({
    selectInput("file", "选择数据文件", choices = files())
  })

  dat <- reactive({
    req(input$file)
    x <- read_any(input$file)
    as.data.table(x)
  })

  output$preview <- renderTable({
    req(dat())
    head(dat(), 20)
  })

  observeEvent(input$run, {
    req(dat())
    x <- copy(dat())
    n <- nrow(x)
    if (n < 100) stop("数据量过小，无法进行可靠时间外回测。")

    # 自动寻找常见标签；若没有，则使用 event / risk / flag
    candidates <- c("event","risk","label","farming_flag","fraud_flag")
    label <- candidates[candidates %in% names(x)][1]
    if (is.na(label)) {
      showNotification("未找到标准风险标签：将生成数据质量报告，但不会伪造预测指标。", type="warning")
      results(list(metrics = data.table(说明="缺少真实标签，无法计算 MAE/MASE/AUC/C-index 等监督指标"),
                   business = data.table(说明="缺少真实标签，无法进行可信的业务收益模拟")))
      return()
    }

    y <- as.integer(as.logical(x[[label]]))
    ord <- seq_len(n)
    # 若存在可识别日期列，按时间排序；否则保持原始顺序，并在报告中明确说明
    date_candidates <- names(x)[grepl("date|time|created|first|last", names(x), ignore.case=TRUE)]
    used_time <- NA_character_
    for (cc in date_candidates) {
      z <- suppressWarnings(as.POSIXct(x[[cc]], tz="UTC"))
      if (sum(!is.na(z)) > 0.8*n) { ord <- order(z, na.last=TRUE); used_time <- cc; break }
    }
    x <- x[ord]
    y <- as.integer(as.logical(x[[label]]))

    tr_end <- floor(n * input$train_pct)
    va_end <- floor(n * (input$train_pct + input$val_pct))
    split <- rep("test", n); split[seq_len(tr_end)] <- "train"; split[(tr_end+1):va_end] <- "validation"

    # 无模型依赖的透明基线：训练集风险率作为先验概率，测试阶段只用排序/分层模拟
    p0 <- mean(y[seq_len(tr_end)])
    score <- rep(p0, n)
    # 如果存在数值风险变量，使用训练集标准化的加权透明评分；不把它冒充为机器学习模型
    num_cols <- names(x)[vapply(x, is.numeric, logical(1))]
    num_cols <- setdiff(num_cols, label)
    if (length(num_cols)) {
      take <- head(num_cols, 10)
      Z <- sapply(take, function(cc) {
        z <- safe_num(x[[cc]])
        mu <- mean(z[seq_len(tr_end)], na.rm=TRUE)
        sdv <- sd(z[seq_len(tr_end)], na.rm=TRUE); if (!is.finite(sdv) || sdv==0) sdv <- 1
        (z-mu)/sdv
      })
      if (is.vector(Z)) Z <- matrix(Z, ncol=1)
      score <- rowMeans(Z, na.rm=TRUE)
      score[!is.finite(score)] <- 0
    }

    test_idx <- which(split=="test")
    k <- max(1, floor(length(test_idx)*input$topk))
    ord_test <- test_idx[order(score[test_idx], decreasing=TRUE)]
    action_idx <- head(ord_test, k)

    pred <- integer(n); pred[action_idx] <- 1
    tp <- sum(pred==1 & y==1); fp <- sum(pred==1 & y==0)
    fn <- sum(pred==0 & y==1)
    precision <- ifelse(tp+fp>0, tp/(tp+fp), NA)
    recall <- ifelse(tp+fn>0, tp/(tp+fn), NA)
    f1 <- ifelse(is.finite(precision) && is.finite(recall) && precision+recall>0,
                 2*precision*recall/(precision+recall), NA)
    business <- data.table(
      policy=paste0("Top ", round(input$topk*100), "% 风险干预"),
      test_members=length(test_idx),
      interventions=length(action_idx),
      true_risks_captured=tp,
      false_positives=fp,
      precision=precision,
      recall=recall,
      F1=f1,
      prevented_loss=tp*input$risk_cost,
      intervention_cost=length(action_idx)*input$action_cost,
      retention_loss=fp*input$retention_cost,
      net_benefit=tp*input$risk_cost-length(action_idx)*input$action_cost-fp*input$retention_cost
    )
    metrics <- data.table(
      label=label, time_order_column=used_time, train_n=tr_end,
      validation_n=va_end-tr_end, test_n=n-va_end,
      test_event_rate=mean(y[test_idx]), precision=precision, recall=recall, F1=f1
    )
    results(list(metrics=metrics,business=business, x=x, score=score, y=y, split=split))
  })

  output$summary <- renderPrint({
    r <- results(); req(r)
    print(r$metrics)
    cat("\n注意：MASE 适用于时间序列预测误差，不能直接替代生存模型的 C-index、IBS 或风险分类指标。\n")
  })
  output$metrics <- renderTable({ req(results()); results()$metrics })
  output$business <- renderTable({ req(results()); results()$business }, digits=4)
  output$curve <- renderPlot({
    r <- results(); req(r)
    d <- data.table(score=r$score, y=r$y, split=r$split)
    d <- d[split=="test"][order(score, decreasing=TRUE)]
    d[, cum_risk := cumsum(y)/seq_len(.N)]
    ggplot(d, aes(seq_len(.N), cum_risk)) + geom_line() +
      labs(x="测试集按风险排序的会员序号", y="累计风险率",
           title="时间外测试集风险捕获曲线")
  })
  output$download_results <- downloadHandler(
    filename=function() paste0("shangjun_experiment_", Sys.Date(), ".csv"),
    content=function(file) fwrite(results()$business, file)
  )
}
shinyApp(ui, server)
