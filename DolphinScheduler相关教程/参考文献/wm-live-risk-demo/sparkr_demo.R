allowed_modes <- c("smoke", "s3", "starrocks", "all")
required_starrocks_keys <- c(
  "starrocks.fe.http.url",
  "starrocks.fe.jdbc.url",
  "starrocks.table.identifier",
  "starrocks.user",
  "starrocks.password"
)

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

read_properties <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  properties <- character()

  for (raw_line in lines) {
    line <- trimws(raw_line)
    if (!nzchar(line) || startsWith(line, "#")) {
      next
    }

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
    stop(
      sprintf("Unexpected StarRocks property keys: %s", paste(unexpected, collapse = ", ")),
      call. = FALSE
    )
  }
  missing <- setdiff(required_starrocks_keys, names(properties))
  if (length(missing) > 0L) {
    stop(
      sprintf("Missing StarRocks property keys: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }

  properties[required_starrocks_keys]
}

inspect_frame <- function(label, frame) {
  cat(sprintf("Inspecting %s frame\n", label))
  printSchema(frame)
  cat(sprintf("row_count=%d\n", count(frame)))
  showDF(frame, numRows = 10L, truncate = 80L)
}

run_smoke <- function() {
  frame <- createDataFrame(data.frame(id = 0:7, bucket = (0:7) %% 2))
  frame <- repartition(frame, 2L)
  inspect_frame("smoke", frame)
  createOrReplaceTempView(frame, "sparkr_demo_smoke")
  cat(sprintf("language=R spark=%s r_home=%s partitions=%d\n",
              sparkR.version(), R.home(), getNumPartitions(frame)))
  showDF(sql("SELECT bucket, COUNT(*) AS row_count FROM sparkr_demo_smoke GROUP BY bucket ORDER BY bucket"),
         numRows = 10L, truncate = 80L)
}

run_s3 <- function(uri) {
  args <- list(s3_uri = uri)
  inspect_frame("s3", read.df(args$s3_uri, source = "parquet"))
}

run_starrocks <- function(path) {
  properties <- read_properties(path)
  options <- c(list(path = NULL, source = "starrocks"),
               as.list(properties[required_starrocks_keys]))
  inspect_frame("starrocks", do.call(read.df, options))
}

main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))

  suppressPackageStartupMessages(library(SparkR))
  sparkR.session(appName = "sparkr-livy-demo")
  on.exit(sparkR.session.stop(), add = TRUE)

  if (args$mode %in% c("smoke", "all")) {
    run_smoke()
  }
  if (args$mode %in% c("s3", "all")) {
    run_s3(args$s3_uri)
  }
  if (args$mode %in% c("starrocks", "all")) {
    run_starrocks(args$starrocks_properties)
  }
}

main()
