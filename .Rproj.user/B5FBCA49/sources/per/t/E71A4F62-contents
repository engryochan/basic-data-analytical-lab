#!/usr/bin/env python3
import argparse
import sys

from pyspark.sql import SparkSession, functions as F
# 新增导入：用于处理向量化和高级算法
from pyspark.ml.feature import VectorAssembler, PCA
from pyspark.ml.clustering import KMeans
from pyspark.ml.evaluation import MulticlassClassificationEvaluator
# 注意：使用 XGBoost 需要确保集群环境已安装 xgboost-spark 包 (pip install xgboost-spark)
from xgboost.spark import SparkXGBClassifier

REQUIRED_STARROCKS_KEYS = (
    "starrocks.fe.http.url",
    "starrocks.fe.jdbc.url",
    "starrocks.table.identifier",
    "starrocks.user",
    "starrocks.password",
)

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("smoke", "s3", "starrocks", "all"), default="smoke")
    parser.add_argument("--s3-uri")
    parser.add_argument("--starrocks-properties")
    args = parser.parse_args()
    if args.mode in ("s3", "all") and not args.s3_uri:
        parser.error("--s3-uri is required for s3/all")
    if args.mode in ("starrocks", "all") and not args.starrocks_properties:
        parser.error("--starrocks-properties is required for starrocks/all")
    return args

def read_properties(path):
    # ... (此函数保持原样，无需修改) ...
    properties = {}
    with open(path, "r", encoding="utf-8") as source:
        for line in source:
            line = line.rstrip("\r\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "=" not in line:
                raise ValueError("StarRocks property must contain '='")
            raw_key, value = line.split("=", 1)
            key = raw_key.strip()
            if not key:
                raise ValueError("StarRocks property key must not be empty")
            if key in properties:
                raise ValueError("Duplicate StarRocks property key: {}".format(key))
            properties[key] = value
    unexpected = [key for key in properties if key not in REQUIRED_STARROCKS_KEYS]
    if unexpected:
        raise ValueError("Unexpected StarRocks properties: {}".format(", ".join(unexpected)))
    missing = [key for key in REQUIRED_STARROCKS_KEYS if key not in properties]
    if missing:
        raise ValueError("Missing required StarRocks properties: {}".format(", ".join(missing)))
    return properties

def inspect_frame(label, frame):
    print(label)
    frame.printSchema()
    print(frame.count())
    frame.show(10, truncate=True)

def run_machine_learning(spark, s3_uri):
    """
    此函数替换了原本的 run_smoke，用于展示高级算法调用。
    我们假设 S3 上存的是 Parquet 格式的建模数据，包含特征列和 label 列。
    """
    # 1. 从 S3 读取数据
    df = spark.read.parquet(s3_uri)
    df.printSchema()
    
    # 2. 自动识别特征列 (假设除了 id, label 之外全是特征)
    feature_cols = [c for c in df.columns if c not in ['id', 'label']]
    
    # 3. 向量化特征 (Spark ML 算法的要求)
    assembler = VectorAssembler(inputCols=feature_cols, outputCol="features_vec")
    df_vec = assembler.transform(df)

    # 4. 主成分分析 (PCA) - 顶级降维尤物
    pca = PCA(k=5, inputCol="features_vec", outputCol="pca_features")
    pca_model = pca.fit(df_vec)
    df_pca = pca_model.transform(df_vec)
    print("=== PCA Model Explained Variance ===")
    print(pca_model.explainedVariance) # 打印降维后保留的方差比例

    # 5. K-Means 聚类 - 无监督学习尤物
    kmeans = KMeans(featuresCol="pca_features", k=3)
    kmeans_model = kmeans.fit(df_pca)
    df_cluster = kmeans_model.transform(df_pca)
    print("=== K-Means Cluster Centers ===")
    print(kmeans_model.clusterCenters())

    # 6. XGBoost 分类器 - 顶级监督学习尤物
    # 假设数据集中有一列 label 用于分类
    xgb = SparkXGBClassifier(
        features_col="pca_features",
        label_col="label",
        max_depth=6,
        n_estimators=50,
        num_workers=2  # XGBoost 在 Spark 上可并行训练
    )
    # 划分训练集和测试集
    train_data, test_data = df_cluster.randomSplit([0.8, 0.2], seed=42)
    
    # 训练模型
    xgb_model = xgb.fit(train_data)
    
    # 预测与评估
    predictions = xgb_model.transform(test_data)
    evaluator = MulticlassClassificationEvaluator(labelCol="label", predictionCol="prediction", metricName="accuracy")
    accuracy = evaluator.evaluate(predictions)
    print("=== XGBoost Test Accuracy ===")
    print(accuracy)

def run_smoke(spark):
    # 您的原始测试方法
    frame = spark.range(0, 8).withColumn("bucket", F.col("id") % 2).repartition(2)
    print({"language": "python", "spark_version": spark.version,
           "python": sys.executable, "partitions": frame.rdd.getNumPartitions()})
    frame.groupBy("bucket").count().orderBy("bucket").show(truncate=False)

def run_s3(spark, uri):
    inspect_frame("s3", spark.read.parquet(uri))

def run_starrocks(spark, path):
    properties = read_properties(path)
    reader = spark.read.format("starrocks")
    for key in REQUIRED_STARROCKS_KEYS:
        reader = reader.option(key, properties[key])
    inspect_frame("starrocks", reader.load())

def main():
    args = parse_args()
    spark = SparkSession.builder.appName("pyspark-livy-demo").getOrCreate()
    try:
        # ========= 这里重点修改了 =========
        if args.mode in ("smoke", "all"):
            # 原先：run_smoke(spark)
            # 现在：如果您想测试机器学习算法，使用 run_machine_learning 并传入 args.s3_uri
            if args.s3_uri:
                run_machine_learning(spark, args.s3_uri)
            else:
                run_smoke(spark) 
            # ===============================
            
        if args.mode in ("s3", "all"):
            run_s3(spark, args.s3_uri)
        if args.mode in ("starrocks", "all"):
            run_starrocks(spark, args.starrocks_properties)
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
    
