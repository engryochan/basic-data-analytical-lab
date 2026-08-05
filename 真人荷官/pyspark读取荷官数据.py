from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, stddev, abs, sum as spark_sum, window
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("GamingRiskDetection").getOrCreate()

# 读取小时级数据
hourly_df = spark.read.csv('dealer_profit_stat_hourly.csv', header=True, inferSchema=True)

# 按小时聚合
hourly_agg = hourly_df.groupBy("stat_date", "stat_hour").agg(
    spark_sum("profit").alias("hour_profit"),
    spark_sum("bet_count").alias("hour_bets")
)

# 滑动窗口（3小时）计算移动平均和标准差
window_spec = Window.orderBy("stat_date", "stat_hour").rowsBetween(-2, 0)
hourly_agg = hourly_agg.withColumn("avg_profit", avg("hour_profit").over(window_spec)) \
                       .withColumn("std_profit", stddev("hour_profit").over(window_spec))

# 标记异常（利润超过3倍标准差）
hourly_agg = hourly_agg.withColumn("is_anomaly", 
                                    abs(col("hour_profit") - col("avg_profit")) > 3 * col("std_profit"))

# 输出异常时段
hourly_agg.filter(col("is_anomaly") == True).select(
    "stat_date", "stat_hour", "hour_profit", "avg_profit", "std_profit"
).show(100, truncate=False)
