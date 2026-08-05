#!/usr/bin/env Rscript
# 注意：运行此脚本前，请在 R 中安装 sparklyr, dplyr, DBI, reticulate 包
# install.packages(c("sparklyr", "dplyr", "DBI", "reticulate"))

allowed_modes <- c("smoke", "s3", "starrocks", "all")
required_starrocks_keys <- c(
  "starrocks.fe.http.url",
  "starrocks.fe.jdbc.url",
  "starrocks.table.identifier",
  "starrocks.user",
  "starrocks.password"
)

# ------------- 参数解析（与原文件保持兼容） -------------
parse_args <- function(values) {
  args <- list(mode = "smoke", s3_uri = NULL, starrocks_properties = NULL)
  seen <- character()
  index <- 1L
  
  while (index <= length(values)) {
    option <- values[[index]]
    if (!(option %in% c("--mode", "--s3-uri", "--starrocks-properties"))) {
      stop(sprintf("Unknown option: %s", option), call. = FALSE)
    }
    if (option %in% seen) {
      stop(sprintf("Duplicate option: %s", option), call. = FALSE)
    }
    if (index == length(values) || !nzchar(values[[index + 1L]])) {
      stop(sprintf("Option requires a value: %s", option), call. = FALSE)
    }
    
    value <- values[[index + 1L]]
    if (option == "--mode") {
      if (!(value %in% allowed_modes)) {
        stop("--mode must be smoke, s3, starrocks, or all", call. = FALSE)
      }
      args$mode <- value
    } else if (option == "--s3-uri") {
      args$s3_uri <- value
    } else {
      args$starrocks_properties <- value
    }
    
    seen <- c(seen, option)
    index <- index + 2L
  }
  
  if (args$mode %in% c("s3", "all") && is.null(args$s3_uri)) {
    stop("--s3-uri is required for the selected mode", call. = FALSE)
  }
  if (args$mode %in% c("starrocks", "all") && is.null(args$starrocks_properties)) {
    stop("--starrocks-properties is required for the selected mode", call. = FALSE)
  }
  args
}

# ------------- 属性文件读取（与原文件保持兼容） -------------
read_properties <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  properties <- character()
  for (raw_line in lines) {
    line <- trimws(raw_line)
    if (!nzchar(line) || startsWith(line, "#")) { next }
    separator <- regexpr("=", raw_line, fixed = TRUE)
    if (separator == -1L) {
      stop("StarRocks property line must contain '='", call. = FALSE)
    }
    key <- trimws(substr(raw_line, 1L, separator - 1L))
    value <- substr(raw_line, separator + 1L, nchar(raw_line))
    if (!nzchar(key)) {
      stop("StarRocks property key must not be empty", call. = FALSE)
    }
    if (key %in% names(properties)) {
      stop(sprintf("Duplicate StarRocks property key: %s", key), call. = FALSE)
    }
    properties[[key]] <- value
  }
  unexpected <- setdiff(names(properties), required_starrocks_keys)
  if (length(unexpected) > 0L) {
    stop(sprintf("Unexpected StarRocks property keys: %s", paste(unexpected, collapse = ", ")), call. = FALSE)
  }
  missing <- setdiff(required_starrocks_keys, names(properties))
  if (length(missing) > 0L) {
    stop(sprintf("Missing StarRocks property keys: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  properties[required_starrocks_keys]
}

# ------------- 数据检查（使用 sparklyr 重写） -------------
inspect_frame <- function(label, frame) {
  cat(sprintf("Inspecting %s frame\n", label))
  # 打印 Schema
  cat("Schema:\n")
  print(sdf_schema(frame))
  # 打印行数
  cat(sprintf("row_count=%d\n", sdf_nrow(frame)))
  # 打印数据前 10 行
  print(head(frame, n = 10L))
}

# ------------- 执行核心逻辑（使用 sparklyr 替换 SparkR） -------------
run_smoke <- function(sc) {
  # 使用 copy_to 将本地的 data.frame 转换为 Spark DataFrame
  frame <- sdf_copy_to(sc, data.frame(id = 0:7, bucket = (0:7) %% 2), overwrite = TRUE)
  # 重分区
  frame <- sdf_repartition(frame, 2L)
  inspect_frame("smoke", frame)
  
  # 注册临时视图
  sdf_register(frame, "sparkr_demo_smoke")
  
  # 使用 dplyr 语法进行 SQL 聚合，或者使用 DBI 包的 SQL 查询
  library(dplyr)
  grouped_result <- tbl(sc, "sparkr_demo_smoke") %>%
    group_by(bucket) %>%
    summarise(row_count = n()) %>%
    arrange(bucket)
  
  cat(sprintf("language=R spark=%s r_home=%s partitions=%d\n",
              spark_version(sc), R.home(), sdf_num_partitions(frame)))
  print(grouped_result)
}

run_s3 <- function(sc, uri) {
  # sparklyr 读取 parquet 的直接方式
  frame <- spark_read_parquet(sc, path = uri, memory = FALSE)
  inspect_frame("s3", frame)
  
  # ================= 演示 "pysparklyr" (R调用Python) =================
  library(reticulate)
  # 在 R 中导入 Python 的 numpy 包作为演示
  np <- import("numpy")
  
  # 将 Spark 中取出的 5 行数据传给 Python 的 pandas 做简单的统计
  local_r_df <- collect(head(frame, 5L))
  local_py_df <- r_to_py(local_r_df)
  
  # 使用 Python pandas 进行 describe() 操作并打印
  cat("=== Python Pandas Describe Output ===\n")
  py_run_string("import pandas as pd")
  py$r_py_df <- local_py_df # 将 R 变量传给 Python
  py_run_string("print(pd.DataFrame(r_py_df).describe())")
  # ====================================================================
}

run_starrocks <- function(sc, path) {
  properties <- read_properties(path)
  
  # 因为 sparklyr 核心不直接提供 "starrocks" source，我们使用高级 API 调用底层 Spark 上下文
  # 构造 Spark 的 options 参数
  options_list <- list()
  for (key in required_starrocks_keys) {
    options_list[[key]] <- properties[[key]]
  }
  
  # 使用 sparklyr 的 invoke 方法，直接调用底层的 Spark 会话
  frame <- sc %>%
    spark_session() %>%
    invoke("read") %>%
    invoke("format", "starrocks") %>%
    invoke("options", options_list) %>%
    invoke("load")
  
  inspect_frame("starrocks", frame)
}

# ------------- 主函数入口 -------------
main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))
  
  # 加载依赖库
  suppressPackageStartupMessages(library(sparklyr))
  suppressPackageStartupMessages(library(dplyr))
  
  # 这里假设您的 R 执行环境可以使用 Hadoop/Yarn 配置
  # 如果需要增加配置（如队列、内存等），可以在这里通过 config 添加
  config <- spark_config()
  config$spark.sql.shuffle.partitions <- "64" 
  
  # 建立与 Yarn 集群的 Spark 连接
  sc <- spark_connect(master = "yarn", app_name = "sparkr-livy-demo", config = config)
  
  # 确保退出时断开连接
  on.exit(spark_disconnect(sc), add = TRUE)
  
  if (args$mode %in% c("smoke", "all")) {
    run_smoke(sc)
  }
  if (args$mode %in% c("s3", "all")) {
    run_s3(sc, args$s3_uri)
  }
  if (args$mode %in% c("starrocks", "all")) {
    run_starrocks(sc, args$starrocks_properties)
  }
}

main()
