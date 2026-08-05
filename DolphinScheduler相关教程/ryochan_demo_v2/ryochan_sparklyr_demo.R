#!/usr/bin/env Rscript
# ryochan_sparklyr_demo.R
#
# Modes: smoke | s3 | starrocks | ml | all
#
# install.packages(c("sparklyr", "dplyr", "DBI", "reticulate", "sparkxgb"))
#
# v2 changes vs. the original ryochan_sparklyr_demo.R
# -----------------------------------------------------
# - This script now owns the connection method (shell vs livy) via the
#   SPARKLYR_CONNECT_METHOD / SPARKLYR_MASTER env vars, using sparklyr's
#   own built-in method="livy" support (sparklyr already implements the
#   Livy session protocol internally -- there is no need for an external
#   bash script to hand-build Livy batch JSON on its behalf). Default is
#   "shell", i.e. spark_connect(master="yarn") run directly on a host
#   that already has Spark client access -- this is the path sparklyr's
#   own documentation recommends over Livy whenever a direct edge-node
#   connection is available, which matches your current DolphinScheduler
#   architecture.
# - run_s3()'s R->Python bridge is now correctly documented as plain
#   reticulate. pysparklyr is a different thing: it is the backend
#   sparklyr needs only when spark_connect() itself uses
#   method="spark_connect" or method="databricks_connect" (Spark Connect
#   protocol). It is unrelated to calling Python libraries from an
#   already-connected sparklyr session, which reticulate does on its own.
# - Added an explicit `ml` mode (PCA -> KMeans -> XGBoost via sparkxgb)
#   for parity with the PySpark side.
# - Adaptive Query Execution (AQE) is on by default.
# - read_properties() defensively strips a trailing \r even though
#   readLines() should already normalise CRLF, because the properties
#   file has been seen shipped with CRLF line endings.
# - run_starrocks() stays read-only. wm_live_risk is a colleague's
#   reference schema; nothing in this file writes to StarRocks.

allowed_modes <- c("smoke", "s3", "starrocks", "ml", "all")
required_starrocks_keys <- c(
  "starrocks.fe.http.url",
  "starrocks.fe.jdbc.url",
  "starrocks.table.identifier",
  "starrocks.user",
  "starrocks.password"
)

# ------------- Argument parsing -------------
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
        stop("--mode must be smoke, s3, starrocks, ml, or all", call. = FALSE)
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

  if (args$mode %in% c("s3", "ml", "all") && is.null(args$s3_uri)) {
    stop("--s3-uri is required for the selected mode", call. = FALSE)
  }
  if (args$mode %in% c("starrocks", "all") && is.null(args$starrocks_properties)) {
    stop("--starrocks-properties is required for the selected mode", call. = FALSE)
  }
  args
}

# ------------- Properties file reading -------------
read_properties <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  properties <- character()
  for (raw_line in lines) {
    # Defensive strip of a trailing CR: readLines() is documented to
    # recognise CRLF, but the properties file this pipeline reads has
    # been observed with CRLF endings, so this costs nothing and removes
    # any doubt.
    raw_line <- sub("\r$", "", raw_line)
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

# ------------- Inspection helper -------------
inspect_frame <- function(label, frame) {
  cat(sprintf("Inspecting %s frame\n", label))
  cat("Schema:\n")
  print(sdf_schema(frame))
  cat(sprintf("row_count=%d\n", sdf_nrow(frame)))
  print(head(frame, n = 10L))
}

# ------------- Modes -------------
run_smoke <- function(sc) {
  frame <- sdf_copy_to(sc, data.frame(id = 0:7, bucket = (0:7) %% 2), overwrite = TRUE)
  frame <- sdf_repartition(frame, 2L)
  inspect_frame("smoke", frame)

  sdf_register(frame, "sparklyr_demo_smoke")

  library(dplyr)
  grouped_result <- tbl(sc, "sparklyr_demo_smoke") %>%
    group_by(bucket) %>%
    summarise(row_count = n()) %>%
    arrange(bucket)

  cat(sprintf("language=R spark=%s r_home=%s partitions=%d\n",
              spark_version(sc), R.home(), sdf_num_partitions(frame)))
  print(grouped_result)
}

run_s3 <- function(sc, uri) {
  # memory=TRUE caches the frame since inspect_frame() triggers several
  # actions (schema, count, head) against the same data.
  frame <- spark_read_parquet(sc, path = uri, memory = TRUE, name = "s3_demo_frame")
  inspect_frame("s3", frame)

  # ---- R -> Python bridge via reticulate ----
  # This is plain reticulate, not pysparklyr. pysparklyr only matters
  # when spark_connect() itself talks Spark Connect / Databricks
  # Connect; it plays no part in calling an arbitrary Python library
  # from a session that is already connected.
  library(reticulate)
  local_r_df <- collect(head(frame, 5L))
  local_py_df <- r_to_py(local_r_df)

  cat("=== Python Pandas Describe Output ===\n")
  py_run_string("import pandas as pd")
  py$r_py_df <- local_py_df
  py_run_string("print(pd.DataFrame(r_py_df).describe())")
}

run_starrocks <- function(sc, path) {
  # READ ONLY. wm_live_risk is a colleague's reference schema -- never
  # add a .write / invoke("save") path here.
  properties <- read_properties(path)

  options_list <- list()
  for (key in required_starrocks_keys) {
    options_list[[key]] <- properties[[key]]
  }

  # sparklyr has no native spark_read_starrocks() helper, so this calls
  # the underlying JVM DataFrameReader directly -- the standard sparklyr
  # pattern for a third-party format string with no dedicated R wrapper.
  frame <- sc %>%
    spark_session() %>%
    invoke("read") %>%
    invoke("format", "starrocks") %>%
    invoke("options", options_list) %>%
    invoke("load")

  inspect_frame("starrocks", frame)
}

run_machine_learning <- function(sc, uri) {
  # sparkxgb gives the R side parity with the PySpark side's XGBoost
  # usage. NEW in v2 -- smoke-test this specific function before relying
  # on it, and confirm the installed sparkxgb build matches your
  # cluster's Spark major version (it wraps xgboost4j-spark, which is
  # version-sensitive).
  library(sparkxgb)

  frame <- spark_read_parquet(sc, path = uri, memory = TRUE, name = "ml_demo_frame")
  feature_cols <- setdiff(colnames(frame), c("id", "label"))

  assembled <- ft_vector_assembler(frame, input_cols = feature_cols, output_col = "features_vec")
  pca_model <- ml_pca(assembled, k = 5, input_col = "features_vec", output_col = "pca_features")
  reduced <- ml_transform(pca_model, assembled) %>% sdf_persist()

  cat("=== PCA Explained Variance ===\n")
  print(pca_model$explained_variance)

  kmeans_model <- ml_kmeans(reduced, features_col = "pca_features", k = 3)
  clustered <- ml_transform(kmeans_model, reduced)
  cat("=== K-Means Cluster Centers ===\n")
  print(kmeans_model$centers)

  splits <- sdf_random_split(clustered, training = 0.8, testing = 0.2, seed = 42)
  xgb_model <- xgboost_classifier(
    splits$training,
    label ~ pca_features,
    max_depth = 6,
    num_round = 50,
    num_workers = 2
  )
  predictions <- ml_predict(xgb_model, splits$testing)
  accuracy <- ml_multiclass_classification_evaluator(
    predictions, label_col = "label", prediction_col = "prediction", metric_name = "accuracy"
  )
  cat("=== XGBoost Test Accuracy ===\n")
  print(accuracy)

  sdf_unpersist(reduced)
}

# ------------- Main -------------
main <- function() {
  args <- parse_args(commandArgs(trailingOnly = TRUE))

  suppressPackageStartupMessages(library(sparklyr))
  suppressPackageStartupMessages(library(dplyr))

  config <- spark_config()
  config$spark.sql.shuffle.partitions <- Sys.getenv("SPARKLYR_SHUFFLE_PARTITIONS", "64")
  config$spark.sql.adaptive.enabled <- "true"
  config$spark.sql.adaptive.coalescePartitions.enabled <- "true"

  # Extra jars (e.g. the StarRocks Spark connector, required for
  # run_starrocks()) are passed in as local paths already localised by
  # the submit script, comma separated.
  extra_jars <- Sys.getenv("SPARKLYR_EXTRA_JARS", "")
  if (nzchar(extra_jars)) {
    config[["sparklyr.shell.jars"]] <- strsplit(extra_jars, ",", fixed = TRUE)[[1]]
  }

  # Connection method lives here, not in the submit script: sparklyr
  # already implements both the direct-yarn ("shell") and Livy
  # connection protocols internally.
  connect_method <- Sys.getenv("SPARKLYR_CONNECT_METHOD", "shell")

  if (identical(connect_method, "livy")) {
    master <- Sys.getenv("SPARKLYR_MASTER", "")
    if (!nzchar(master)) {
      stop("SPARKLYR_MASTER (e.g. http://livy-host:8998) is required when SPARKLYR_CONNECT_METHOD=livy", call. = FALSE)
    }
    livy_user <- Sys.getenv("LIVY_USER", "")
    if (nzchar(livy_user)) {
      config <- livy_config(config, username = livy_user, password = Sys.getenv("LIVY_PASSWORD", ""))
    }
    sc <- spark_connect(master = master, method = "livy", app_name = "sparklyr-demo", config = config)
  } else {
    master <- Sys.getenv("SPARKLYR_MASTER", "yarn")
    sc <- spark_connect(master = master, app_name = "sparklyr-demo", config = config)
  }
  on.exit(spark_disconnect(sc), add = TRUE)

  if (args$mode %in% c("smoke", "all")) {
    run_smoke(sc)
  }
  if (args$mode %in% c("s3", "all")) {
    run_s3(sc, args$s3_uri)
  }
  if (args$mode %in% c("ml", "all")) {
    run_machine_learning(sc, args$s3_uri)
  }
  if (args$mode %in% c("starrocks", "all")) {
    run_starrocks(sc, args$starrocks_properties)
  }
}

main()
