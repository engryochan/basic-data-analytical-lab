library(sparklyr)
library(dplyr)

sc <- spark_connect(master = "yarn")  # 或 spark_connect(master="local")
# 假设 ods_tbl 已经在 Spark 中（或用 spark_read_* 导入）
ods_tbl <- tbl(sc, "ods_bets")  # 替换为你的表名

# 1) 在 driver 上抽样训练（小样本）
sample_frac <- 200000 / ods_tbl %>% sdf_nrow()  # 目标训练量/总量（近似）
rsf_sample <- ods_tbl %>%
  filter(!is.na(avg_bet) & !is.na(std_bet) & !is.na(win_rate)) %>%
  sdf_sample(fraction = sample_frac, replacement = FALSE) %>%
  collect()

# 训练 CoxPH（在 driver 上）
library(survival)
cox_formula <- as.formula("Surv(duration_days, event) ~ avg_bet + std_bet + win_rate + total_turnover + unique_games + unique_tables")
cox_model <- coxph(cox_formula, data = rsf_sample)

# 保存模型到 HDFS（或共享文件系统）
model_path <- "/user/you/models/cox_model.rds"
saveRDS(cox_model, file = "/tmp/cox_model.rds")
system(sprintf("hdfs dfs -put -f /tmp/cox_model.rds %s", model_path))

# 2) 在 Spark 上分区预测：spark_apply 在每个 partition 上读取模型并做预测
# 注意：需要在 worker 上安装 survival 包；spark_apply 的 packages 参数会尝试分发
predictions <- ods_tbl %>%
  select(id, duration_days, event, avg_bet, std_bet, win_rate, total_turnover, unique_games, unique_tables) %>%
  spark_apply(
    function(df) {
      # 在 worker 上运行：先安装/加载 survival（若已安装可直接加载）
      if (!requireNamespace("survival", quietly = TRUE)) {
        install.packages("survival", repos = "https://cloud.r-project.org")
      }
      library(survival)
      
      # 读取模型（假设 HDFS 已挂载或可通过 system 调用 hdfs dfs -get）
      local_model <- "/tmp/cox_model.rds"
      # 如果 worker 无法直接访问 HDFS 路径，可先用 hdfs dfs -get
      system(sprintf("hdfs dfs -get -f %s %s", "/user/you/models/cox_model.rds", local_model))
      cox_model <- readRDS(local_model)
      
      # 预测：predict.coxph 返回线性预测值（风险分数）
      df$pred_risk <- predict(cox_model, newdata = df, type = "lp")
      # 返回需要写回 Spark 的列
      df[, c("id", "pred_risk")]
    },
    packages = c("survival"),
    columns = c(id = "character", pred_risk = "double")
  )

# 保存预测结果到 Hive / Parquet
sdf_copy_to(sc, predictions, name = "predictions_table", overwrite = TRUE)
