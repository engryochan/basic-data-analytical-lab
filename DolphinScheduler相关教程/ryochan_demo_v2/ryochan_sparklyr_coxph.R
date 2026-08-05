#!/usr/bin/env Rscript
# ryochan_sparklyr_coxph.R
# (renamed from the original ryochan_sparkklyr.R -- that filename had a
#  double "k" typo; library(sparklyr) inside the file was already spelled
#  correctly, only the filename was off)
#
# Driver-side CoxPH training on a stratified sample, full-population
# prediction via spark_apply(). This mirrors the 200k-sample /
# full-population-prediction pattern already established for the RSF
# pipeline, just with coxph() instead of randomForestSRC.
#
# v2 changes vs. the original ryochan_sparkklyr.R
# -----------------------------------------------------
# - The spark_apply() worker closure downloaded the model to a HARDCODED
#   path (/tmp/cox_model.rds) on every call. If a worker runs several
#   partitions concurrently (the normal case), two tasks could
#   `hdfs dfs -get -f` into the same path at once and one task could read
#   a half-overwritten file. Each call now downloads to its own
#   tempfile() and removes it afterwards.
# - sample_frac is now capped at 1 (min(1, 200000 / n)) so a source table
#   smaller than 200k rows doesn't produce a fraction > 1, which
#   sdf_sample() would reject.
# - Added refuse_protected_write_target(): wm_live_risk is a colleague's
#   reference schema. The one write in this file (sdf_copy_to at the
#   bottom) is guarded so it refuses to run if OUTPUT_TABLE_NAME is ever
#   pointed at a protected schema. Adjust RYOCHAN_PREDICTIONS_TABLE via
#   the environment (or the default below) to your own schema -- never
#   point it at wm_live_risk.
# - Source table name, model HDFS path, and output table name are now
#   environment-overridable instead of hardcoded placeholders.

library(sparklyr)
library(dplyr)
library(survival)

# ---- Write-target safety guard ----
# wm_live_risk (and anything else added here) is read-only reference
# data. This list is deliberately separate from any config file so it
# cannot be silently widened by a mis-set environment variable.
REFUSED_WRITE_SCHEMAS <- c("wm_live_risk")

refuse_protected_write_target <- function(identifier) {
  schema <- tolower(trimws(strsplit(identifier, ".", fixed = TRUE)[[1]][1]))
  if (schema %in% REFUSED_WRITE_SCHEMAS) {
    stop(sprintf(
      "Refusing to write to protected reference schema '%s' (identifier=%s). wm_live_risk is read-only reference data.",
      schema, identifier
    ), call. = FALSE)
  }
}

SOURCE_TABLE <- Sys.getenv("RYOCHAN_SOURCE_TABLE", "ods_bets")  # replace with your source table
MODEL_HDFS_PATH <- Sys.getenv("RYOCHAN_COX_MODEL_HDFS_PATH", "/user/ryochan/models/cox_model.rds")
OUTPUT_TABLE_NAME <- Sys.getenv("RYOCHAN_PREDICTIONS_TABLE", "ryochan_demo.cox_predictions")

# Fail fast, before spending any Spark time, if the output target is
# misconfigured.
refuse_protected_write_target(OUTPUT_TABLE_NAME)

sc <- spark_connect(
  master = Sys.getenv("SPARKLYR_MASTER", "yarn"),
  app_name = "sparklyr-coxph-demo"
)
on.exit(spark_disconnect(sc), add = TRUE)

ods_tbl <- tbl(sc, SOURCE_TABLE)

# 1) Stratified sample, trained on the driver.
n_rows <- ods_tbl %>% sdf_nrow()
sample_frac <- min(1, 200000 / n_rows)
rsf_sample <- ods_tbl %>%
  filter(!is.na(avg_bet) & !is.na(std_bet) & !is.na(win_rate)) %>%
  sdf_sample(fraction = sample_frac, replacement = FALSE) %>%
  collect()

cox_formula <- as.formula(
  "Surv(duration_days, event) ~ avg_bet + std_bet + win_rate + total_turnover + unique_games + unique_tables"
)
cox_model <- coxph(cox_formula, data = rsf_sample)

local_model_path <- tempfile(fileext = ".rds")
saveRDS(cox_model, file = local_model_path)
put_status <- system(sprintf("hdfs dfs -put -f %s %s", local_model_path, MODEL_HDFS_PATH))
if (put_status != 0) {
  stop(sprintf("hdfs dfs -put failed while publishing the model to %s", MODEL_HDFS_PATH), call. = FALSE)
}
file.remove(local_model_path)

# 2) Full-population prediction: spark_apply() reads the model on each
#    worker and predicts per partition.
predictions <- ods_tbl %>%
  select(id, duration_days, event, avg_bet, std_bet, win_rate, total_turnover, unique_games, unique_tables) %>%
  spark_apply(
    function(df, model_hdfs_path) {
      if (!requireNamespace("survival", quietly = TRUE)) {
        install.packages("survival", repos = "https://cloud.r-project.org")
      }
      library(survival)

      # Unique per-call local path: avoids two concurrent tasks on the
      # same worker racing on a shared hardcoded /tmp file.
      local_model <- tempfile(fileext = ".rds")
      get_status <- system(sprintf("hdfs dfs -get -f %s %s", model_hdfs_path, local_model))
      if (get_status != 0) {
        stop(sprintf("hdfs dfs -get failed for %s", model_hdfs_path))
      }
      cox_model <- readRDS(local_model)
      file.remove(local_model)

      df$pred_risk <- predict(cox_model, newdata = df, type = "lp")
      df[, c("id", "pred_risk")]
    },
    context = list(model_hdfs_path = MODEL_HDFS_PATH),
    packages = c("survival"),
    columns = c(id = "character", pred_risk = "double")
  )

# Guard re-checked immediately before the actual write, in case
# OUTPUT_TABLE_NAME was somehow mutated above.
refuse_protected_write_target(OUTPUT_TABLE_NAME)
sdf_copy_to(sc, predictions, name = OUTPUT_TABLE_NAME, overwrite = TRUE)
cat(sprintf("Wrote predictions to %s\n", OUTPUT_TABLE_NAME))
